# Code-Scanner Report — reflax-yield-vault (reflax-yield-vault)

- Project: reflax-yield-vault (maps to `lib/reflax-yield-vault`)
- Scan type: code (Tier 2 interaction-level manual reasoning over Tier 1 profiles)
- Scan timestamp: 2026-05-25
- In-scope files:
  - `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
  - `src/AMMAdapters/CurveAMMAdapter.sol`
  - `src/AMMAdapters/IAMMAdapter.sol`
  - `src/AMMAdapters/ICurveRouterNG.sol`
- Context read (OOS as root cause): `src/AYieldStrategy.sol`

Tier 1 artifacts (profiles, static-analysis, pattern-matches) were consumed first; verified
properties (checked arithmetic, INV-1 paired updates, single-contract reentrancy guards,
bidirectional route invariant) are trusted and not re-derived. Intended-design behaviors
(requested-amount principal decrement, bidirectional route invariant, trusted Curve Router,
standard-ERC20 assumption, permissionless adapter `swap`, owner emergency powers) are NOT
flagged as bugs.

Econ/oracle vectors (NAV-as-slippage-oracle PM-01, no-deadline PM-03, slippage misconfig
PM-02) are deferred to econ-scanner per scope split.

---

## Confirmed code-level findings

### CODE-001 — `_skimSurplusBatch` over-skims when `clients[]` contains duplicate (or overlapping) addresses, draining shares that back other clients' balances
- Type: accounting / state-consistency bug (loss of value)
- Severity estimate: **Medium** (impact: loss to other clients; likelihood tempered by trusted caller — see note)
- File: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:462-488` (loop `:468-478`, aggregate sell `:479-486`)
- Entrypoint: `AYieldStrategy.skimSurplusBatch` (`src/AYieldStrategy.sol:310-320`), `onlyAuthorizedWithdrawer`

Root cause:
The batch loop iterates the caller-supplied `clients[]` calldata array with **no
deduplication** and no "already seen" set:

```solidity
for (uint256 i = 0; i < clients.length; i++) {
    address client = clients[i];
    require(client != address(0), ...);
    uint256 principal = clientBalances[token][client];
    if (principal == 0) continue;
    uint256 total = (totalValue * principal) / td;          // == totalBalanceOf(client)
    uint256 surplus = total > principal ? total - principal : 0;
    if (surplus == 0) continue;
    totalShares += vault.convertToShares(surplus);          // accumulates per occurrence
    ...
}
if (totalShares == 0) return;
uint256 availableShares = vault.balanceOf(address(this));
if (totalShares > availableShares) totalShares = availableShares;   // only cap = TOTAL held shares
...
uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);
underlyingToken.safeTransfer(recipient, underlyingReceived);
// principal untouched
```

If the same client address appears `k` times in `clients[]`, that client's surplus shares
are added to `totalShares` `k` times. The only ceiling applied is `availableShares` (the
strategy's *entire* vault-share balance — which backs every client's principal **and**
surplus), not the true aggregate surplus. The single aggregate swap therefore sells more
shares than the legitimate total surplus, and the proceeds are sent to the
withdrawer-chosen `recipient`. Because `clientBalances` / `totalDeposited` are intentionally
left untouched (surplus-only semantics), the strategy ends up holding fewer shares than its
recorded `totalDeposited` principal requires.

Concrete trigger:
1. Clients A and B each have principal `P` and surplus `S` (so held shares back `2P + 2S` of NAV).
2. Authorized withdrawer calls `skimSurplusBatch(token, [A, A, B, B], recipient)`.
3. Loop accumulates `2*convertToShares(S_A) + 2*convertToShares(S_B)` worth of shares.
4. Provided that is `<= availableShares` (it is, since `2S << 2P+2S`), the cap does not bite;
   the strategy sells ~`2(S_A+S_B)` of surplus when only `S_A+S_B` exists.
5. The extra `~S_A+S_B` of underlying value comes out of the shares backing principal.
   Afterwards `vault.balanceOf(strategy)` no longer covers `totalDeposited`; the next
   client to withdraw hits the `sharesToSell > availableShares` cap in `_withdrawInternal`
   (`:316-318`) and receives **less underlying than their principal**, or `totalBalanceOf`
   under-reports the surviving clients' balances.

Impact:
Permanent loss of yield/principal backing for clients not at fault. Even a single duplicated
address (`[A, A]`) doubles A's skim and bleeds the shared pool. Because principal is never
decremented, the loss surfaces silently as a later under-collateralized withdrawal rather
than an immediate revert.

Note on severity / likelihood:
The caller is `onlyAuthorizedWithdrawer` (a trusted role), so this is not an arbitrary-attacker
path. However, it is an *accounting-correctness* defect that a benign, non-malicious operator
triggers by passing a list with an accidental duplicate (e.g. a buggy off-chain script that
unions two client groups), and the result is real loss to third parties. The single-client
`_skimSurplus` path is correctly bounded (`require(amount <= surplus)`); the batch path drops
that per-client invariant. Recommended fix: enforce uniqueness (sorted-strictly-increasing
input or an in-loop seen-set), or bound `totalShares` by an independently recomputed aggregate
surplus rather than by `availableShares`. Final HM-vs-QA call deferred to severity-classifier;
documented here as a genuine logic bug, not tool noise.

---

### CODE-002 — `_skimSurplusBatch` reverts the entire batch on a single zero-address entry (batch-griefing / robustness)
- Type: DoS / robustness (revert-in-loop)
- Severity estimate: **QA / Low**
- File: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:470`
- Corroborates Aderyn A3 / static S-A3.

Root cause:
`require(client != address(0), ...)` lives inside the per-client loop. A single zero entry
anywhere in `clients[]` reverts the whole batch (all prior gas wasted, no partial progress).
Other invalid-but-nonzero entries (`principal == 0`, `surplus == 0`) are handled gracefully
with `continue`, so the zero-address case is inconsistently strict.

Impact:
An authorized withdrawer assembling a large batch must pre-sanitize the array off-chain or
the call is unusable; combined with the unbounded length (LOCAL-001) this is a self-inflicted
availability footgun. Trusted caller → QA. Recommended: `continue` on zero address instead of
reverting, mirroring the `principal == 0` handling.

---

## Verified — NOT bugs (closed for downstream, do not re-flag)

These were probed at the interaction level and found correct or intended:

1. **Cross-function / AMM-boundary reentrancy (static S1/S2/S3).** Every value-moving
   entrypoint — `deposit`, `withdraw`, `depositAsOwner`, `withdrawAsOwner`, `skimSurplus`,
   `skimSurplusBatch`, `totalWithdrawal` — carries OZ `nonReentrant` (contract-wide
   `_status`), so re-entry into any *other* guarded function during a swap is blocked
   regardless of modifier ordering (the guard still wraps the external `ammAdapter.swap`).
   The only unguarded value path, `emergencyWithdraw`, merely `safeTransfer`s vault **shares**
   to the trusted `owner()` and mutates no internal accounting. Tokens are standard ERC20
   (no transfer hooks) and the Curve Router is trusted. No exploitable cross-contract
   reentrancy path. State-after-call ordering is cosmetic under the guard.

2. **Strict-equality guards `totalShares == 0 || totalDeposited == 0` (`:374`) and
   `surplus == 0` (`:475`).** These short-circuit on genuine empties only. Probed the
   requested-vs-received principal desync (focus #3/#6): `_withdrawInternal` decrements both
   `clientBalances` and `totalDeposited` by the same `amount` (INV-1 holds), so they cannot
   independently reach zero. `totalShares` (live `vault.balanceOf`) can fall faster than
   `totalDeposited` over many capped withdrawals, but `totalShares == 0` while
   `totalDeposited > 0` simply makes `_totalWithdraw` early-return (nothing to sell) — a
   safe no-op, not a branch that can be abused to extract value. No harmful skip found.

3. **`setRoute` uninitialized `lastToken` (`CurveAMMAdapter:74`).** The loop sets `lastToken`
   to the last non-zero `path` entry; `require(lastToken == tokenOut)` plus
   `require(path[0] == tokenIn)` (`:71`) and the non-zero `tokenIn`/`tokenOut` requires
   (`:69-70`) fully cover the partial-zero path: an all-zero-after-slot-0 path leaves
   `lastToken == path[0] == tokenIn`, which fails `lastToken == tokenOut` (distinct nonzero
   tokens). A trailing junk entry after `tokenOut` also makes `lastToken != tokenOut` and
   reverts. Intermediate-structure correctness is acknowledged admin responsibility. No bug.

4. **`swap` return-value trust (`:283`, `:328-331`, `CurveAMMAdapter:138`).** The strategy
   uses the router's returned `amountOut` for accounting and forwards it to the recipient
   with no balance-delta check. Under the in-scope standard-ERC20 + trusted-Curve-Router
   assumptions the router delivers output to `_receiver = msg.sender` and returns the true
   amount, so the returned value equals the delivered balance. With fee-on-transfer/weird
   tokens this would diverge — but those are explicitly out of scope. No in-scope bug; the
   *price* dimension (NAV-anchored `minOut`) is an econ-scanner concern (PM-01).

5. **Permissionless `CurveAMMAdapter.swap` (LOCAL-003).** Output goes to `msg.sender`,
   `forceApprove` resets the router allowance each call, and no funds or standing approvals
   persist between calls, so a third-party caller can only route their own tokens. No path
   for an external `swap` caller to capture strategy funds or approvals. Intended open
   utility. No bug.

6. **Requested-vs-received principal decrement & `_withdrawInternal` shares cap.** Intended
   (protocol-favoring). The cap at `:316-318` is to TOTAL held shares and `minOut` (`:321-322`)
   is computed on the post-cap `sharesToSell`, so the slippage floor stays consistent with what
   is actually sold. INV-1 preserved. Surfaced by Tier 1 as intended; confirmed no harmful
   desync beyond CODE-001's batch path.

---

## Summary

- 1 Medium-estimate code-level logic bug: **CODE-001** — `_skimSurplusBatch` lacks
  client-deduplication, so a duplicated/overlapping `clients[]` over-skims past the true
  aggregate surplus (capped only by total held shares), bleeding the share pool that backs
  other clients' principal; loss surfaces as later under-collateralized withdrawals. Trusted
  caller tempers likelihood; accidental-duplicate triggerability and third-party loss keep it
  a real correctness defect.
- 1 QA/Low: **CODE-002** — zero-address `require` inside the batch loop reverts the whole
  batch (inconsistent with the `continue`-on-empty handling of other invalid entries).
- All other Tier 1 / static / pattern candidates in the code domain were probed and found
  intended or mitigated (reentrancy guards, strict-equality guards, `setRoute` lastToken,
  swap return-value trust, permissionless adapter swap, requested-amount decrement).
- Oracle/slippage/MEV economic vectors (PM-01/02/03) are deferred to econ-scanner.
