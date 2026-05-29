# QA Report (Regression Update) — reflax-yield-vault (reflax-yield-vault)

**Run:** `reflax-yield-vault-06` — **REGRESSION** scan
**Baseline:** `reflax-yield-vault-05` @ `7d11f66c9ac9b70a947f8a023872e424f4632ab9`
**This run:** `043ff2cb5ee9808961b50311fb5ecb742b63a6e9` (story-041 — skim path rewrite)
**Scope:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, `src/AMMAdapters/CurveAMMAdapter.sol`, `src/AMMAdapters/IAMMAdapter.sol`, `src/AMMAdapters/ICurveRouterNG.sol`

This is a regression QA update bundling all carried-forward Low-severity and Centralization findings against the new commit. **This run produced 0 new findings.** High/Medium findings are submitted separately; an automated SAST/gas baseline (4naly3er) is attached as an appendix.

### Regression context

- **M-01 — CONFIRMED FIXED this run** (not included below; referenced only). story-041 removed the caller-supplied `clients[]` list — the only skim entry point is now `skimSurplus(token, recipient)` iterating an owner-managed `EnumerableSet _authorizedClients`, so duplicates are structurally unconstructible — and added a loud aggregate-surplus ceiling at `ERC4626MarketYieldStrategy.sol#L434`. Fix-verification PoC passes 4/4 against `043ff2c`. See the run summary; M-01's over-skim primitive no longer exists.
- The Low / Centralization items below **carry forward from reflax-yield-vault-05**, reconciled against the current commit with the **story-041** updates noted inline (L-02 restated/narrowed; C-01 sub-points appended). M-02 (NAV-anchored `minOut` sandwich leak, with M-03 merged in) remains OPEN at Medium and is handled in the H/M track, not here.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 2 |
| Centralization | 1 |
| **Total** | **3** |

| ID | Title | This run |
|----|-------|----------|
| [L-01](#l-01-slippagetolerancebps-defaults-to-0-and-its-setter-has-no-sane-upper-bound) | `slippageToleranceBps` defaults to `0` and its setter has no sane upper bound | reconfirmed OPEN |
| [L-02](#l-02-skimsurplus-iterates-the-owner-grown-authorized-client-set-with-no-pagination) | `skimSurplus` iterates the owner-grown authorized-client set with no pagination | RESTATED (partial fix) |
| [C-01](#c-01-owner-and-authorized-withdrawer-power-bundle) | Owner and authorized-withdrawer power bundle | reconfirmed OPEN |

---

## Low Risk Findings

### [L-01] `slippageToleranceBps` defaults to `0` and its setter has no sane upper bound

**Status this run:** reconfirmed **OPEN** at `043ff2c`. Pre-existing; inherited unchanged by the new skim path. story-041 did not touch the slippage parameter or its setter (it reused the same `minOut = ideal * (MAX_BPS - slippageToleranceBps) / MAX_BPS` formula on the new aggregate-swap path, e.g. `ERC4626MarketYieldStrategy.sol#L436`).

**Location:**
- [`ERC4626MarketYieldStrategy.sol#L40`](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L40) (state variable, no initializer)
- [`ERC4626MarketYieldStrategy.sol#L190-L195`](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195) (`setSlippageTolerance`)

**Description:**

A missing-validation / uninitialized-state finding with two related parts.

**(a) No initializer / no nonzero default.** `slippageToleranceBps` is declared without an initial value and the constructor never sets it, so it defaults to `0`:

```solidity
uint256 public slippageToleranceBps;
```

Every swap-bearing path computes its floor as `minOut = ideal * (MAX_BPS - slippageToleranceBps) / MAX_BPS`. With `slippageToleranceBps == 0`, `minOut == ideal`, i.e. the swap is required to clear at exactly the NAV-derived ideal with zero tolerance. Under any non-zero pool spread or fee this floor is unattainable and the swap reverts. The strategy is therefore non-functional for deposits/withdrawals/skims until an owner calls `setSlippageTolerance`, and nothing in the contract signals this precondition.

**(b) Setter has no sane upper bound.** `setSlippageTolerance` only checks the value against the absolute maximum:

```solidity
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
    ...
}
```

`MAX_BPS == 10000` (100%). The only guard accepts the entire `[0, 10000]` range, including values that collapse `minOut` toward `0` and effectively disable slippage protection. This is reported strictly as a missing-validation defect — the contract lacks a tighter, protocol-appropriate ceiling and a nonzero floor. It is **not** a claim that an owner would maliciously set 100% (that would be an excluded reckless-admin scenario).

**Impact:** Availability-until-configured (the strategy reverts all swaps on a fresh deploy until the owner configures a tolerance), plus an overly permissive parameter band that removes the safety value the parameter is meant to provide. No funds are directly at risk.

**Recommendation:**
- Initialize `slippageToleranceBps` to a conservative non-zero default in the constructor (e.g. `50` = 0.5%), or require it as a constructor argument so the contract is never deployed in an unusable state.
- Constrain the setter with a meaningful upper bound rather than `MAX_BPS`, and reject `0`:

```solidity
uint256 public constant MAX_SLIPPAGE_BPS = 500; // 5%, choose per protocol policy

function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps > 0 && _bps <= MAX_SLIPPAGE_BPS, "slippage out of allowed range");
    uint256 oldBps = slippageToleranceBps;
    slippageToleranceBps = _bps;
    emit SlippageToleranceSet(oldBps, _bps);
}
```

---

### [L-02] `skimSurplus` iterates the owner-grown authorized-client set with no pagination

**Status this run:** **RESTATED / NARROWED** at `043ff2c`. The reflax-yield-vault-05 entry (titled around `_skimSurplusBatch`) bundled two sub-vectors; story-041 resolved one and transformed the other:

- **Sub-vector (1) — zero-address whole-batch revert: RESOLVED.** The caller no longer supplies the client list; the skim API is now `skimSurplus(token, recipient)` over the owner-managed set. `setClient` rejects the zero address so it can never enter the set, and the in-loop zero-address check at [`ERC4626MarketYieldStrategy.sol#L421`](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L421) is now unreachable defense-in-depth (the code comment at L410 acknowledges the `EnumerableSet` already guarantees distinctness). No further action on this sub-vector.
- **Sub-vector (2) — unbounded iteration: PERSISTS, transformed.** This is the live remainder of the finding and the scope of L-02 below.

**Location:** [`ERC4626MarketYieldStrategy.sol#L413-L441`](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L413-L441) (`_skimSurplus`); per-client loop with external `vault.convertToShares()` call at L427.

**Description:**

`_skimSurplus` now iterates the **full** owner-managed `_authorizedClients` `EnumerableSet` with no pagination — it is all-or-nothing per call:

```solidity
for (uint256 i = 0; i < clients.length; i++) {
    address client = clients[i];
    // (unreachable defense-in-depth, see sub-vector 1)
    require(client != address(0), "ERC4626MarketYieldStrategy: client cannot be zero address");
    uint256 principal = clientBalances[token][client];
    if (principal == 0) continue;
    uint256 total = ...; // per-client valuation
    uint256 surplus = total > principal ? total - principal : 0;
    if (surplus == 0) continue;
    // ... accumulate floored shares ...
}
```

The loop performs an external `vault.convertToShares()` call per non-trivial entry, so gas scales linearly with set membership. There is no length cap and no paginated/partial-skim entry point: once the authorized-client set grows large enough that the per-skim gas exceeds the block limit, the skim path bricks entirely (no partial progress is possible).

The growth vector is **owner-controlled**: an admin would have to authorize an extreme number of clients via `setClient` for the skim to become unexecutable. There is no third-party trigger and no asset loss — `clientBalances` (principal) is untouched and the skim only moves surplus — so this remains an **owner-bounded availability / gas note at Low**. The issue is the absence of a defensive bound or pagination on a loop whose length the protocol can grow over its lifetime.

*(Consolidation note: this run's static-analysis hits PATTERN-006 and SLITHER-005 (`calls-loop`, `require-revert-in-loop`, array-length-read-in-loop) map onto this entry — they were not raised as separate findings.)*

**Recommendation:**
- Add a paginated/partial skim entry point (e.g. `skimSurplusRange(token, recipient, start, count)`) or a bounded per-call cap, so a large authorized-client set never makes surplus unrecoverable in a single all-or-nothing call.
- Optionally remove the now-unreachable in-loop zero-address `require` at L421 (or downgrade it to an assert/comment) since `setClient` already excludes the zero address — it currently reads as dead defense-in-depth.

---

## Centralization Risks

### [C-01] Owner and authorized-withdrawer power bundle

**Status this run:** reconfirmed **OPEN** at `043ff2c`. story-041 did not change the centralization root cause and in fact **adds** owner power (see the story-041 sub-points appended below). Surfaced again this run via PATTERN-005 and Aderyn `centralization-risk` (consolidated, not a new finding).

**Location:** Multiple (acknowledged design):
- [`setRoute` (CurveAMMAdapter.sol#L68)](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/AMMAdapters/CurveAMMAdapter.sol#L68)
- [`setSlippageTolerance` (ERC4626MarketYieldStrategy.sol#L190)](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190)
- `depositAsOwner` / `withdrawAsOwner` (`ERC4626MarketYieldStrategy.sol#L242`, `#L254`)
- `emergencyWithdraw` and the two-phase total-withdrawal timelock (inherited from `AYieldStrategy`)
- **story-041 — owner-managed authorized-client set:** [`setClient` (ERC4626MarketYieldStrategy.sol)](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)
- **story-041 — single-recipient surplus skim:** [`skimSurplus` / `_skimSurplus` (ERC4626MarketYieldStrategy.sol#L413-L441)](https://github.com/Behodler/reflax-yield-vault/blob/043ff2cb5ee9808961b50311fb5ecb742b63a6e9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L413-L441)

**Description:**

The strategy concentrates several privileged powers in the owner and the authorized-withdrawer roles:

- **Routing:** the owner sets AMM routes via `setRoute`, fully determining the pool/path every swap clears through.
- **Slippage:** the owner sets `slippageToleranceBps` (see L-01), controlling the protective floor on all swaps.
- **Owner deposit/withdraw:** `depositAsOwner` / `withdrawAsOwner` let the owner move positions on behalf of the strategy.
- **Emergency exit:** an `emergencyWithdraw` path and a two-phase total-withdrawal flow (24h wait / 48h execute) inherited from `AYieldStrategy`.

**story-041 sub-points added this run:**

- **Owner-managed authorized-client `EnumerableSet` (`setClient`).** story-041 introduces an owner-curated membership set: `setClient(client, true/false)` is the sole gate on which clients are recognized for principal accounting and surplus skimming. Owner discretion now directly determines the set that `_skimSurplus` iterates (this is also the growth vector behind L-02). Adding/removing a client is an owner-only privileged action with no timelock or external check.
- **Skim sends 100% of aggregate surplus to a single withdrawer-chosen recipient.** The rewritten skim aggregates surplus across the whole authorized-client set and routes the **entire** amount to one `recipient` address supplied by the caller (`skimSurplus(token, recipient)`). The distribution destination is wholly at the trusted actor's discretion — there is no per-client pro-rata routing or recipient allow-list — so the withdrawer chooses where the aggregate surplus lands.

**Scope of the withdrawer power (verified):** the authorized withdrawer can redirect **yield/surplus only** — it can never redirect or extract client **principal**. `clientBalances` (per-client principal) is intentionally untouched by the skim path, and M-01's duplicate-driven over-skim primitive was fixed this run (aggregate-surplus ceiling at L434), so the surplus moved is arithmetically bounded by genuine aggregate surplus. The two-phase total-withdrawal timelock is sound and is not bypassable by the emergency path.

This is acknowledged, authorized design per the project's system assumptions (the owner is expected to be a trusted multisig acting in the protocol's and clients' interest) and the documented two-phase emergency-withdrawal design. It is reported here as a centralization note for completeness rather than as an exploitable defect; an owner-key compromise would widen routing/slippage/client-membership/skim-recipient/emergency control, but principal redirection remains outside these powers.

**Recommendation:**
- Hold the owner role in a multisig, and consider a timelock on `setRoute`, `setSlippageTolerance`, and `setClient` so route, slippage, and membership changes are observable before they take effect.
- For the skim, consider constraining the recipient (allow-list or per-client pro-rata distribution) rather than an arbitrary caller-chosen single address, so surplus routing is not solely at trusted-actor discretion.
- Emit events (with old/new values) on every privileged parameter change — including `setClient` add/remove and the skim recipient — to support off-chain monitoring.
- Document the trust model (owner = trusted multisig; withdrawer = yield-only; owner curates the authorized-client set) prominently for clients so the boundary between redirectable surplus and protected principal is explicit.

---

## Informational / QA-bucket items (this run's static analysis)

These were surfaced by Slither / Aderyn / Semgrep on the story-041 diff and consolidated by the deduplicator. None carries a demonstrated High/Medium exploit path; per C4 conventions they are recorded here as low-priority QA/informational rather than as individual submissions. Where they overlap the manual findings above (notably the in-loop `calls-loop`/`require-revert-in-loop` on `_skimSurplus`, which folds into L-02, and the `centralization-risk` heuristic, which folds into C-01), the manual findings are authoritative.

- **CEI ordering on `_withdrawInternal` / `_totalWithdraw`** — state writes (`clientBalances`, `totalDeposited`) occur after the external `ammAdapter.swap()` call. **Mitigated by the inherited `nonReentrant` guard** on every public entry path into these functions (Slither does not model the base-class lock, hence the `reentrancy-no-eth` flag). No re-entrancy primitive; informational CEI-hygiene note.
- **Reentrancy-events ordering on `CurveAMMAdapter.swap`** — the `Swapped` event is emitted after the external `router.exchange()` call. Event-ordering only; informational.
- **Shadowing-local constructor param `_owner`** — constructor parameter shadows `Ownable._owner` (also on `CurveAMMAdapter`). Style.
- **`nonReentrant` not the first modifier** — auth modifiers (`onlyAuthorizedClient` / `onlyOwner`) run before the reentrancy lock on `deposit` / `withdraw` / `depositAsOwner` / `withdrawAsOwner`. Best-practice ordering; low risk here since those auth modifiers make no external calls.
- **Missing `Ownable2Step`** — single-step ownership transfer; consider a 2-step pattern.
- **Floating pragma / `PUSH0`** — `pragma solidity ^0.8.13` is unpinned, and 0.8.20+ emits `PUSH0` (verify the target chain supports it).
- **Magic literals** — numeric literals in route setup (`CurveAMMAdapter`) and a large numeric literal in `ERC4626MarketYieldStrategy`; prefer named constants / underscore-separated literals.
- **Semgrep INFO style/gas hits** — custom-error-vs-`require` revert strings, prefix-increment (`++i`) over postfix, state-variable-read-in-loop, non-payable constructors. Gas/style only.

(Two Slither `uninitialized-local` hits on zero-init accumulators and an `unused-public-function` hit on the external `swap` entrypoint are confirmed false positives — no action.)

---

## Appendix — Automated analysis (4naly3er)

The automated C4-style SAST/gas report was produced by **4naly3er** over the four in-scope files at commit `043ff2cb5ee9808961b50311fb5ecb742b63a6e9` and is attached as [`4naly3er-report.md`](./4naly3er-report.md). It is the standard bot-report baseline; items there are largely gas/best-practice and informational, and the manual findings above are authoritative where they overlap.

**Tooling note (known bit-rot):** the project's foundry full-build is currently broken by bit-rot test files that still reference the removed `skimSurplusBatch` API (`forge build` fails). 4naly3er does not need a full build — it compiles only the in-scope files plus their resolved imports via solc stdin (solc 0.8.23, satisfying the `^0.8.13` pragma) — so it ran cleanly **without modifying the broken test files or `lib/`**. Imports were resolved with the repo's `@openzeppelin` remapping plus the `pauser/=lib/mutable/pauser/src/` remapping (added only to a throwaway copy of `remappings.txt` in the writable `workspace/`; `lib/` was never touched). The `[Link to code]` URLs in the appendix are missing a path separator after the commit hash — a cosmetic 4naly3er formatting quirk; the embedded commit hash `043ff2c` is correct.

Categories surfaced by 4naly3er (full per-instance line references in the attached report):

- **Gas Optimizations:** 15 categories (e.g. cache array length outside loop, custom errors vs revert strings, `unchecked` for-loop increments, `!= 0` vs `> 0`, `immutable` for constructor-set state).
- **Non-Critical:** 17 categories (e.g. magic numbers vs constants, events missing indexed fields / old+new values, consider disabling `renounceOwnership()`, style-guide ordering, functions > 50 lines).
- **Low:** 8 categories (e.g. 2-step ownership transfer / `Ownable2Step`, division-by-zero not prevented, possible rounding / loss of precision, `PUSH0` on non-mainnet chains under 0.8.20+, assembly-optimizer-bug solidity versions).
- **Medium:** 3 categories (fee-on-transfer accounting, centralization risk for trusted owners, `increase/decreaseAllowance` on USDT) — automated heuristics; superseded by the separately-submitted manual H/M findings and the acknowledged trust model in C-01.
