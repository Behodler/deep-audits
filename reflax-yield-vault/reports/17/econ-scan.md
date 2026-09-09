# Economic / Design-Intent Scan — reflax-yield-vault @ `cdd0743` (run 17)

- **Project**: reflax-yield-vault
- **Commit**: `cdd0743` `[story-050] GREEN: previewExitFor on IYieldStrategy, base default + market override`
- **Baseline**: `0110ce4` (story-049)
- **Scan type**: economic (Tier 2, protocol-wide)
- **Scan date**: 2026-08-31
- **Inputs consumed, not redone**: `contract-profiles.md`, `story-faithfulness.md`, `static-analysis.md`
- **PoC artifacts** (workspace, preserved):
  - `/home/justin/code/audits/workspace/reflax-yield-vault/test/poc-run17-econ-exit-preview.t.sol` — **3/3 PASS** (new this scan)
  - `/home/justin/code/audits/workspace/reflax-yield-vault/test/poc-run17-preview-exit.t.sol` — **7/7 PASS** (pre-existing from the code scan; one refutation test appended by this scan)

---

## Executive summary

Story-050 ships a **forward-declared pricing surface with no consumer**. The economically
interesting question is therefore not "what does it leak today" — it leaks nothing today — but
"what does it cause the moment its one intended consumer is wired". Six questions were priced.

The two results that matter:

1. **The current consumer is structurally immune, and this is provable, not lucky.**
   `StableStakerV2._routeExit`'s `_isUnderwater` guard is *strictly dominant* over the exact
   condition under which the reflax base default over-quotes (proof in §2.3). Every path on which
   `previewExitFor` could cause a silent under-delivery is already intercepted. This materially
   **lowers** the live severity of story-faithfulness `F-01-050`, and is stated here so the next
   reader does not price F-01 at its worst case.
2. **The exposure story-025 actually creates is not the one story-025 defends against.**
   Story-025's mandated safeguard — "measure the actual balance delta after `withdraw` and revert
   if the received amount is below what the annihilation needs" — is **structurally incapable of
   firing** on a below-par strategy, because `_routeExit`'s underwater branch returns the full
   requested `amount` from the shared idle buffer without ever touching the strategy. `received ==
   needed` by construction, the `StableStaker:` revert never fires, and the buffer is drawn in
   full. The story's own acceptance test ("assert the idle buffer is untouched … in the
   lying-preview scenario") passes against a full-credit mock and is unsatisfiable against a real
   below-par strategy. **This is the finding this scan exists to produce.** (ECON-17-02.)

One candidate Medium was **suppressed** by the minter-cushion memo, and one was **refuted**
outright by PoC. Both are documented rather than dropped (§5, §6).

**Nothing in this scan is proposed above Low today.** Two carry explicit, dated Medium escalation
triggers.

---

## 1. Who eats the shortfall? — the account that goes short is named

### 1.1 The reflax layer: the last-exiting client, in full, with no buffer and no pro-rata

`_withdrawInternal` debits the **requested** amount, and this is documented and intentional:

```solidity
// src/AYieldStrategy.sol:757-760 (NatSpec on _withdrawInternal)
//   SECURITY — protocol-favouring write-down: principal is decremented by the REQUESTED (capped)
//   `amount`, NOT by what the redeem/swap actually returned. Any shortfall stays as protocol-owned
//   yield. This rule must remain in the base.
```

```solidity
// src/AYieldStrategy.sol:781-783
clientBalances[token][balanceHolder] -= amount;
totalDeposited[token] -= amount;
```

The disposal it pairs with caps at the **global** share balance:

```solidity
// src/concreteYieldStrategies/ERC4626YieldStrategy.sol:126-138
function _disposeShares(uint256 amount, address recipient) internal override returns (uint256 sharesDisposed) {
    uint256 sharesToRedeem = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));   // GLOBAL — every client's backing
    if (sharesToRedeem > availableShares) {
        sharesToRedeem = availableShares;
    }
    vault.redeem(sharesToRedeem, recipient, address(this));
    sharesDisposed = sharesToRedeem;
}
```

Composed, these two produce a pure **first-come-first-served** exit queue. There is no buffer, no
haircut, and no pro-rata socialization anywhere at the reflax layer. The deficit is not spread —
it is **concentrated in its entirety on whoever exits last**.

Proven, `testE1_FirstComeFirstServedAcrossClients`
(`workspace/reflax-yield-vault/test/poc-run17-econ-exit-preview.t.sol`), two clients, 50% vault loss:

```
whole position value  : 1000000000000000000000
netGuaranteed clientA : 1000000000000000000000
netGuaranteed clientB : 1000000000000000000000
sum of the two floors : 2000000000000000000000     <-- 2x what the strategy can pay
clientA received      : 1000000000000000000000     <-- drains the ENTIRE global position
clientB received      : 0                          <-- receives nothing
```

and `strategy.principalOf(token, clientB) == 0` afterwards — B's principal is debited in full for a
zero delivery. `getTotalDeposited == 0` and `vault.balanceOf(strategy) == 0`: the books are square
and **no value is created**. This is redistribution of a pre-existing market loss, not a mint.

**Named account: `clientBalances[token][<last exiter>]`.** It absorbs 100% of the deficit.

Single-client case, `testE2_SingleClientQuoteIsFalseByTheFullDeficit` — the same arithmetic without
any second party: `netGuaranteed 1000e18`, `delivered 500e18`. This reproduces the story-faithfulness
F-01-050 probe against the real `ERC4626YieldStrategy` and is recorded here as independent
confirmation, not as a new finding.

### 1.2 The StableStaker layer: the shared idle buffer, then a revert

The consumer never lets that reach a staker on the ordinary path:

```solidity
// lib/stable-staker/src/StableStakerV2.sol:876-895
function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
    IYieldStrategy strategy = yieldStrategy[token];
    if (address(strategy) == address(0)) { return amount; }
    IERC20 t = IERC20(token);
    if (guardUnderwater && _isUnderwater(token, strategy)) {
        if (t.balanceOf(address(this)) >= amount) {
            emit BufferWithdrawn(token, msg.sender, amount);
            strategy.relinquishPrincipal(token, amount);
            return amount;
        }
        revert("StableStaker: strategy underwater");
    }
    uint256 balanceBefore = t.balanceOf(address(this));
    strategy.withdraw(token, amount, address(this));
    return t.balanceOf(address(this)) - balanceBefore;   // MEASURED delta — compliant consumer
}
```

So the live order of absorption is: **shared idle buffer → hard revert → (only on the two
`guardUnderwater == false` sites) the last-out staker.** Both of those sites are themselves
defended: `setYieldStrategy` carries `require(!_isUnderwater(token, old))` (`StableStakerV2.sol:268`)
and the migration path measures from the balance and socializes via the `(R,P)` snapshot.

**Suppression applied — externally-derived yield.** The idle buffer is funded by skimmed surplus
(Tokemak-style yield on protocol-owned capital) plus the story-047 set-aside buffer and donations.
Per the Phoenix rule that externally-derived yield over-payment is *opportunity cost, not loss*,
**buffer depletion is NOT filed as a value leak** anywhere in this report. It is filed only where it
produces an **availability** consequence (ECON-17-02), which is a different and legitimate harm.

---

## 2. The global-share-cap contention question

### 2.1 Can the sum of simultaneously-valid quotes exceed what the strategy can pay? — YES

`vault.balanceOf(strategy)` is global; `clientBalances[token][account]` is per-account. The base
default never reads the former:

```solidity
// src/AYieldStrategy.sol:571-583
function previewExitFor(address token, address account, uint256 netWanted)
    external view virtual override returns (uint256 grossToRequest, uint256 netGuaranteed)
{
    require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");
    uint256 availablePrincipal = clientBalances[token][account];
    grossToRequest = netWanted > availablePrincipal ? availablePrincipal : netWanted;
    netGuaranteed = grossToRequest;
}
```

With N clients each holding principal `p_i` against a position worth `V < Σp_i`, the N
simultaneously-valid floors sum to `Σp_i`, i.e. **N× over-issued against `V`** in the fully-impaired
limit. PoC'd at N=2 (§1.1): `Σ floors = 2 × position`.

The market override is *better but not immune* — it does read the global share balance in
`_exitFloor` (`ERC4626MarketYieldStrategy.sol:127-135`), but it reads it **per caller**, so two
clients are each floored against the *whole* balance. `testH5_TwoClientsQuotedTheSameShares`
(`poc-run17-preview-exit.t.sol`, PASS):

```
whole position value : 1000000000000000000000
netGuaranteed user1  : 980100000000000000000
netGuaranteed user2  : 980100000000000000000
sum of the two floors: 1960200000000000000000
user2 actually received: 20000000000000000000   <-- 2.0% of the 980.1 it was quoted
```

### 2.2 Is it first-come-first-served value transfer between clients, reachable without a malicious actor? — YES, and the topology is real

No attacker is required. The trigger is an **ordinary vault drawdown** (a Tokemak Autopool loss)
plus two clients exiting in the normal course. There is no manipulation, no flash loan, no
privileged call.

And the two-client topology is not hypothetical. The mainnet migration script wires **both**
`PhusdStableMinter` and `StableStaker` as clients of the **same** strategy instance:

```solidity
// lib/phoenix-phase-2-staging/script/MigrateStableStakerMainnet.s.sol:496 (_cutoverMinter, per newYs)
newYs.setClient(PHUSD_STABLE_MINTER, true);
// lib/phoenix-phase-2-staging/script/MigrateStableStakerMainnet.s.sol:595 (_wirePool, same newYs)
newYs.setClient(address(stableStaker), true); // client added ON the strategy (two-sided wiring)
```

`newYsDola` / `newYsUsdc` are `ERC4626YieldStrategy` — the **direct** strategy, the one whose base
default has neither the share cap nor a test for it, and the one wired to Tokemak `autoDOLA` /
`autoUSD` per run-16.

### 2.3 …and yet the live exposure is nil. The proof.

`_isUnderwater` is **strictly dominant** over the cap-binding condition, so the consumer's guard
fires on a strict superset of the dangerous states:

```solidity
// lib/stable-staker/src/StableStakerV2.sol:850-852
function _isUnderwater(address token, IYieldStrategy strategy) internal view returns (bool) {
    return strategy.totalBalanceOf(token, address(this)) < strategy.principalOf(token, address(this));
}
```

With `totalBalanceOf = V·p/D` (`AYieldStrategy.sol:549`) and `principalOf = p`:

- underwater ⟺ `V·p/D < p` ⟺ **`V < D`** (for `p > 0`) — a *global* predicate, identical for every
  client;
- the share cap binds ⟺ `convertToShares(amount) > balanceOf(strategy)` ⟺ **`amount > V`**;
- and `amount ≤ p ≤ D`, so `amount > V ⟹ D > V ⟹` underwater.

**cap-binds ⟹ underwater.** The converse fails (a small withdrawal from a mildly impaired position
is underwater without binding the cap), which makes the guard *conservative* — the safe direction.

**Consequence, stated plainly:** on the `withdraw()` path there is **no reachable state** in which
`previewExitFor`'s over-quote causes a silent under-delivery to StableStaker. It causes a buffer
draw or a revert. Story-faithfulness `F-01-050` is correct as a defect but its worst case is not
live in the current topology, and it should not be priced as though it were.

**Disposition — SUPPRESSED, minter-cushion memo.** The residual — StableStaker draining against the
minter's commingled backing shares — is precisely the commingled-share-cap socialization the
Phoenix rule declares **BY DESIGN**, on the premise that phUSD minters cannot redeem and therefore
constitute a cushion rather than a counterparty. That premise is verified live: `PhusdStableMinter`
has no strategy-withdraw path, so it can never be the first mover in the race. **No per-client cap
is recommended, and no user-vs-user finding is filed.**

**Suppression NOT applied to the dilution leg — V2 premise void.** The memo's *value* argument does
not survive StableStakerV2: V2 emits Antimatter, which redeems into **unbacked** phUSD, so the
minter's constituency does bear a real dilution rather than an opportunity cost. That leg is
**live**, but it belongs to the existing unbacked-phUSD channel (`yield-claim-nft` DEDUP-001,
`antimatter` run-01), not to a new reflax finding. **Routed, not dropped, and not re-filed here.**

### 2.4 Dedup disclosure — ledger `M-03`, and why this is not a silent re-file

Ledger `M-03` (fingerprint `3c8331040bba…`, status **`merged`** into `M-02`) reads:

> "Requested-not-received decrement socialises slippage, causing last-withdrawer shortfall"

with the merge rationale quoted verbatim:

> "No standalone loss primitive; amplifies M-02's slippage leak by concentrating the share-backing
> deficit onto the last withdrawer via the requested-not-received decrement. … Fingerprint retained
> so a future standalone recurrence can still be matched."

**Same shape, different primitive.** M-03 is filed on `ERC4626MarketYieldStrategy._withdrawInternal`
and its deficit source is **AMM slippage**, which M-02's accepted triage bounds at
`slippageToleranceBps × tradeSize` and which *reverts* on `minOut` beyond that. The §1.1 result is on
`ERC4626YieldStrategy` (a different contract), its deficit source is an **unbounded vault
drawdown**, and `vault.redeem` carries **no `minOut` at all** — there is no bound and no revert.
M-03's own note invites exactly this match ("a future standalone recurrence").

**Re-file basis:** I am **not** re-filing it. §1.1/§2.1 are recorded as *characterisation* supporting
ECON-17-02, and the standalone client-vs-client framing is suppressed in §2.3 by the minter-cushion
memo. M-03 should stay `merged`.

Ledger `M-01-run12` (realizable-solvency collapse, status **`false-positive`**) is **not
re-escalated**. Its subject is vault-rate-vs-AMM-rate divergence on the market strategy; §1–§2 are
about the vault position falling below booked principal, on the direct strategy, with no AMM in the
path at all. Distinct root cause; the hard-guard is honoured.

---

## 3. Cross-repo pricing — the load-bearing question

### 3.1 Verified state of the consumer

`previewExitFor` has **zero consumers** at every sibling top-level HEAD (profile §H-6, independently
re-confirmed: `lib/stable-staker` @ `fa06de5` contains no `previewExitFor` and no `autoAnnihilate`).
Nested `lib/mutable/**` copies were **not** read — stale by construction.

The intended consumer is `stable-staker` **story-025**, resolved unambiguously to
`~/code/product-owner/stories/stable-staker/incomplete/stable-staker-auto-annihilate/025-force-annihilation-on-claim.md`
— **state folder `incomplete`**, i.e. the code has not landed.

### 3.2 What story-025 already gets right (state it, so the finding is not overstated)

The story's Round-2 section is itself an audit-driven redesign and it already mandates the two
things one would recommend:

> "**Manipulated preview.** The preview reads AMM state and can be moved within a block. It is
> **ADVISORY ONLY**. The implementation **MUST** still measure the actual balance delta after
> `withdraw` and revert with an explicit `StableStaker:` string if the received amount is below what
> the annihilation needs. **A lying preview must produce a failed transaction, never a raided
> buffer.**"
> — story-025, *Front-running analysis*

> "- [ ] Tests — confirm the **idle buffer is untouched** across every case above: assert
> StableStaker's idle stable balance is unchanged by `autoAnnihilate` in the full-credit, haircut,
> whole-position and lying-preview scenarios"
> — story-025, *Round 2 Checklist*

So the naive "consumer trusts `netGuaranteed` and the buffer eats the difference" story is
**already defended in the spec**. Filing that would be a speculative Medium against code that plans
to prevent it. I do not file it.

### 3.3 The actual defect: the safeguard cannot fire in the case it was written for

`autoAnnihilate` sources its stable through `_routeExit(token, gross, true)` — `guardUnderwater ==
true`, exactly as `withdraw()` does (`StableStakerV2.sol:366`). On a below-par strategy the
underwater branch (quoted in §1.2) executes:

```solidity
if (t.balanceOf(address(this)) >= amount) {
    emit BufferWithdrawn(token, msg.sender, amount);
    strategy.relinquishPrincipal(token, amount);
    return amount;                       // <-- returns the FULL request, unconditionally
}
```

Three consequences compose into the finding:

1. **No tokens move from the strategy.** `relinquishPrincipal` is a pure write-down —
   `AYieldStrategy.sol:700-716`, "*Write down recorded principal ONLY — vault shares are deliberately
   untouched*". The entire `amount` is paid from StableStaker's own idle balance.
2. **`received == needed`, always.** The mandated check compares what the annihilation needs against
   `_routeExit`'s return, which on this branch is `amount` by construction. **The `StableStaker:`
   revert can never fire on a below-par strategy.** The safeguard written to stop a lying preview
   from raiding the buffer is inert precisely when the buffer is being raided — and it is inert for
   a reason unrelated to the preview, which is why neither the code scan nor the story scan priced it.
3. **The acceptance test is unsatisfiable.** "Assert StableStaker's idle stable balance is unchanged
   … in the lying-preview scenario" passes trivially against a full-credit mock (`_isUnderwater` is
   false, the branch is never taken) and **cannot** be made to pass against a real below-par
   strategy. A green checklist here is a false negative.

Note the preview's role: `previewExitFor` does not *cause* this — it makes it *routine*.
`autoAnnihilate` is designed to be called by every staker on every reward claim, so it converts a
rare operational buffer draw into the protocol's default reward path.

### 3.4 What the loss is, and who pays

- **Magnitude per call:** exactly the annihilated `net` — 100% of the withdrawal, not a haircut.
  Unlike the AMM-slippage leak (`M-02`, bounded at `slippageToleranceBps × tradeSize`), this is
  **unbounded by any tolerance**: it is bounded only by the idle balance.
- **Immediate payer:** the shared idle buffer. Under the externally-derived-yield rule this is
  **opportunity cost, not loss** — correctly **not filed as a value leak**.
- **Real harm, and it is availability:** the buffer is thin by construction. The mainnet wiring sets
  `setSetAsideBuffer(address(stableStaker), 10)` — **10 percent** of skim proceeds
  (`MigrateStableStakerMainnet.s.sol:597`) — against full staker principal. One large staker's
  whole-position `autoAnnihilate` empties it, after which `_routeExit` takes the
  `revert("StableStaker: strategy underwater")` leg and **every other staker's `withdraw()` is
  bricked** until the position recovers or the owner refunds. FCFS again, now on exit availability.
- **Second-order:** each buffer-path call also leaves reflax-side residual share value backing
  nothing (`relinquishPrincipal` writes down principal without redeeming), feeding ledger **QA-09**
  (orphaned value) and the **F-03** pay-out-then-relinquish invariant, whose Medium re-evaluation
  gate the ledger already says fires at the next stable-staker run.

### 3.5 The trigger that turns this from Low into Medium

Filed at **Low** today because story-025 is `incomplete` and C4 treats speculation on future code as
invalid. It becomes a **Medium** on the conjunction of all three of:

1. `stable-staker` bumps `lib/reflax-yield-vault` to a story-050 commit and lands `autoAnnihilate`
   (story-025 Round-2 Checklist item 1);
2. `autoAnnihilate` sources stable through `_routeExit(..., guardUnderwater = true)` — i.e. reuses
   `withdraw()`'s routing, which is what the story describes; **and**
3. the wired strategy can go below par — true for both the Tokemak-Autopool direct strategies and
   the USDe market strategy.

**Recommended correction to story-025 (cheap, and it belongs in the story, not in reflax):** the
mandated measurement must be taken across `strategy.withdraw` specifically, not across
`_routeExit`'s return value — or, simpler and stronger, `autoAnnihilate` must **refuse** the
underwater branch outright (`require(!_isUnderwater(token, strategy), "StableStaker: cannot annihilate
below par")`). Annihilation is a reward path, not an emergency exit; there is no reason for it to
consume the emergency buffer. Add one acceptance test: below-par strategy + non-empty buffer ⇒
`autoAnnihilate` reverts and the idle balance is byte-unchanged.

---

## 4. Suppression rules — applied and inapplicable, stated explicitly

| Rule | Disposition | Where |
|---|---|---|
| **Externally-derived yield = opportunity cost, never a value leak** | **APPLIED.** The StableStaker idle buffer is funded by skimmed Tokemak-style yield on protocol-owned capital + the story-047 set-aside. Buffer depletion is filed **only** for its availability consequence (§3.4), never as a value leak. | §1.2, §3.4 |
| **Minter-cushion / commingled share cap is BY DESIGN; never recommend a per-client cap** | **APPLIED.** The §2 multi-client contention resolves into exactly this pattern: `PhusdStableMinter` and `StableStaker` share one strategy's global share balance, and the minter has no withdraw path, so it is a cushion and not a racing counterparty. Candidate Medium **suppressed**; no per-client cap recommended; no user-vs-user finding filed. | §2.3 |
| **…BUT the minter-cushion premise is VOID for StableStaker V2** | **INAPPLICABLE — suppression withheld on one leg.** V2 emits Antimatter redeemable into **unbacked** phUSD, so the minter's constituency bears real dilution, not opportunity cost. That leg is **live**, and is **routed** to the existing unbacked-phUSD channel (`yield-claim-nft` DEDUP-001 / `antimatter` run-01) rather than re-filed here. V1 is unaffected. **Not silently dropped.** | §2.3 |
| **`M-01-run12` realizableSolvency collapse — do not re-escalate** | **HONOURED.** Distinct root cause (vault position below booked principal on the direct strategy, no AMM in path) vs. M-01-run12's vault-rate-vs-AMM-rate divergence. Not re-escalated, not cited as support. | §2.4 |
| **Law 3 — owner is trusted for KNOWING actions; non-obvious footguns are in scope** | **APPLIED** to §5. The `MAX_BPS` consequence passes the surprise test and is retained as a footgun — but folded into the existing ledger `L-01`, not filed fresh. | §5 |
| **C4 known-invalid: speculation on future code** | **APPLIED.** ECON-17-02 is capped at Low with a dated escalation trigger, matching the ledger's own `F-03` precedent for a forward-looking cross-protocol integration constraint. | §3.5 |

---

## 5. Owner footgun — `setSlippageTolerance(MAX_BPS)`, priced

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:89-94
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
    ...
}
```

`MAX_BPS` (10000) is an **accepted** value. At that setting:

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:107-109
function _creditedPrincipal(uint256 amount) internal view returns (uint256) {
    return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;   // -> 0
}
```
```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:213-223
creditedPrincipal = _creditedPrincipal(amount);          // 0
uint256 minOut = vault.convertToShares(creditedPrincipal); // 0 — the swap will accept anything
...
sharesReceived = ammAdapter.swap(address(underlyingToken), address(vault), amount, minOut);
```

`_depositInternal` has **no** `require(creditedPrincipal > 0)` — it books `clientBalances += 0` and
emits a `Deposited` event carrying the **nominal** `amount`. The depositor's entire deposit is
converted into unattributed protocol surplus, and the swap that acquired it accepted any output.

**Signal quality:** the only new indication story-050 adds is `previewExitFor` returning `(0, 0)`
— and `testH4_ZeroZeroIsFourDifferentStates` (`poc-run17-preview-exit.t.sol`, PASS) proves that same
`(0,0)` is returned identically for an unknown account, a zero `netWanted`, a drained account, **and**
a fully-funded account under `MAX_BPS`. The alarm is indistinguishable from three benign states.
Feeding the returned `grossToRequest == 0` back into `withdraw` then reverts
`"AYieldStrategy: amount must be greater than zero"`.

**Surprise test: PASSES** (a competent non-malicious owner would not expect a slippage *tolerance*
to zero out principal *crediting*). In scope as a footgun under Law 3.

**Dedup — folded, not re-filed.** Ledger **`L-01`** (fingerprint `6460e353…`, status **open**, Low),
*"slippageToleranceBps default-0 plus setter missing sane cap"*, already owns this root cause and its
`run08Note` already records the deposit-side crediting blast radius verbatim:

> "the deposit-side haircut magnitude is bounded ONLY by the still-missing `slippageToleranceBps`
> upper cap, so an owner setting a loose tolerance now haircuts depositors' credited principal as
> well as swap `minOut`."

Story-050 adds a **third** dependent surface to the same uncapped parameter. Recorded as an
**L-01 blast-radius extension** (`+ previewExitFor returns an alarm indistinguishable from three
benign states`), **not** as a new finding.

**Safe-config guidance (unchanged in substance, extended in scope):**
- Cap `setSlippageTolerance` well below `MAX_BPS` in the setter — `require(_bps <= 1000)` — and
  never deploy at the zero default.
- Pause deposits before temporarily raising tolerance to clear an operational withdrawal.
- Add `require(creditedPrincipal > 0)` in `_depositInternal` so a zero-credit deposit fails loudly
  rather than silently confiscating.
- Monitor `previewExitFor(token, <known-funded client>, 1)` as a liveness canary: a `(0,0)` from a
  client with non-zero `principalOf` is unambiguously the `MAX_BPS` state.

**Cross-repo watch note (stable-staker, not a reflax finding).** `StableStakerV2` guards the user
paths — `require(credited > 0, "StableStaker: nothing credited")` at `:333` (`stake`) and `:713`
(`depositFor`) — but the idle sweep in `setYieldStrategy` does **not**:

```solidity
// lib/stable-staker/src/StableStakerV2.sol:294-298
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    uint256 credited = strategy.deposit(token, idleBalance, address(this));
    emit ProtocolPrincipalSwept(token, address(strategy), idleBalance, credited);
}
```

At `MAX_BPS` this sweeps the **entire shared underwater-withdrawal buffer** into the new strategy for
zero booked principal. The empty-pool gate (`require(poolInfo[token].totalStaked == 0)`, `:258`)
means no staker is exposed at that instant — but the buffer is gone for everyone who stakes after.
Belongs to the next stable-staker run, not to this ledger.

---

## 6. Preview staleness as an economic surface — REFUTED

The NatSpec concedes the reads are within-block manipulable and fee-blind. Priced concretely, and
**there is no profitable manipulation**. Three independent reasons:

**(a) `grossToRequest` does not depend on any manipulable quantity.** On the market path
`grossToRequest = ceilDiv(netWanted × MAX_BPS, MAX_BPS − slippageToleranceBps)` capped by
`clientBalances` (`ERC4626MarketYieldStrategy.sol:167-172`) — a function of an owner-set constant and
storage only. On the direct path it is `min(netWanted, clientBalances[…])`. **Neither reads the vault
or the AMM.** Only `netGuaranteed` is manipulable at all.

**(b) The `_exitFloor` share round-trip is price-invariant.** `convertToAssets(convertToShares(x)) ≈ x`
independently of share price, so moving the ERC4626 price — the only cheap lever, via a donation —
does not move the quote. Proven, `testEconRefute_DonationDoesNotInflateTheQuote`
(`poc-run17-preview-exit.t.sol`, PASS):

```
net before donation: 500000000000000000000
net after  +1000pct: 499999999999999999999    (an 11x share-price donation)
net after  -50pct  : 499999999999999999999    (a 50% collapse, cap not binding)
```

A ~1-wei drift across an 11× price swing. And the direction is wrong for an attacker anyway: a
donation *raises* the position value, making the quote *more* honest.

The only lever that genuinely moves `netGuaranteed` is `vault.balanceOf(strategy)` via the cap — and
that is movable only by the strategy itself (`deposit` / `withdraw` / `skimSurplus` /
`emergencyWithdraw` / `totalWithdrawal`), all of which are `onlyAuthorizedClient` or `onlyOwner`.
There is no permissionless lever.

**(c) Even a successfully inflated quote converts to a revert, not a profit.** Under story-025 the
quote sizes `annihilatable`; an inflated quote means the strategy delivers less than needed, and the
story's mandated measurement reverts the transaction. The attacker pays a real ERC4626 donation
(unrecoverable, shared pro-rata with every other shareholder including the strategy) to buy a failed
transaction. Cost strictly exceeds gain in every direction.

**Verdict: REFUTED.** Not filed, not even as a Low. What *does* exist on this surface is a
**griefing/DoS**, not manipulation — `testH2_HealthyQuoteThenWithdrawReverts` (PASS) shows a full-health
quote (`netGuaranteed 900e18` against `principal 990e18`) immediately before a *guaranteed*
`withdraw` revert, because `_exitFloor` never reads the AMM (`IAMMAdapter` exposes no quote member at
all — `IAMMAdapter.sol`, single non-view `swap`). That belongs to the code scan's H-2 and is
economically an availability issue with **zero** extractable value: the attacker must move the Curve
pool past the tolerance and holds the position while doing it. Not escalated here.

**Fee-blindness — dedup disclosure, folded not re-filed.** `_exitFloor` and the base default are both
built on the fee-free `convertToAssets`, so both over-quote on a fee-charging vault. This is the
**same root cause** as ledger **`ECON-A`** (run-16 `L-16`, fingerprint `c50c08f9…`, status **open**,
Low) — *"ERC4626YieldStrategy credits principal via fee-blind convertToAssets, persistently
over-stating redeemable NAV"* — whose measured magnitude is recorded as:

> "mainnet fork (re-verified via cast): autoDOLA … 0.2107 bps over-statement; autoUSD … 1.0742 bps;
> FLAT across 1 unit -> 5M … Below protocol slippage tolerances -> honest Low."

Story-050 adds a **third and fourth call site** (`AYieldStrategy.previewExitFor`,
`ERC4626MarketYieldStrategy._exitFloor`) that inherit the same blindness. Because it is a new
function on a new surface it would mint a **fresh fingerprint that dedup will not catch** —
disclosed here explicitly. **Re-file basis: none. Do not open a new entry.** Record as an ECON-A
surface extension and carry ECON-A's `severityScaling` note forward unchanged: magnitude is bound to
the external vault's fee config, and a strategy wired to a non-trivial-exit-fee vault makes the same
code path a Medium. Note also that `_isUnderwater` is built on the *same* fee-blind `convertToAssets`
(via `totalBalanceOf`), so the §2.3 dominance proof holds for the *vault-loss* deficit but **not** for
the *exit-fee* deficit — an at-par fee-charging vault under-delivers with the guard reading false.
That residual is exactly ECON-A's measured 0.21–1.07 bps and stays Low.

---

## 7. Findings summary (ranked, machine-readable)

```json
{
  "project": "reflax-yield-vault",
  "scanTimestamp": "2026-08-31T00:00:00Z",
  "scanType": "economic",
  "commit": "cdd0743",
  "contractsScanned": 7,
  "findings": [
    {
      "id": "ECON-001",
      "label": "ECON-17-02",
      "type": "cross-protocol-mechanism-mismatch",
      "severity": "low",
      "proposedSeverity": "Low (Medium on the §3.5 trigger)",
      "contract": "src/AYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 571, "lineStart": 571, "lineEnd": 583,
      "crossReference": {
        "protocol": "stable-staker",
        "file": "src/StableStakerV2.sol",
        "function": "_routeExit",
        "lineStart": 876, "lineEnd": 895,
        "story": "story-025 (incomplete)"
      },
      "description": "Story-025's mandated 'measure the balance delta and revert if received < needed' safeguard is structurally incapable of firing on a below-par strategy: _routeExit's guardUnderwater branch returns the full requested amount from the shared idle buffer without touching the strategy, so received == needed by construction. The story's own 'idle buffer untouched in the lying-preview scenario' acceptance test passes against a full-credit mock and is unsatisfiable against a real below-par strategy.",
      "economicImpact": "Each autoAnnihilate against a below-par strategy draws 100% of the annihilated amount from the shared idle buffer — unbounded by slippageToleranceBps, unlike M-02's leak. Buffer depletion itself is opportunity cost (externally-derived yield rule, NOT a value leak); the real harm is availability: once the buffer is empty _routeExit reverts 'StableStaker: strategy underwater' and every other staker's withdraw() is bricked. Buffer is thinly funded (setSetAsideBuffer(stableStaker, 10) = 10 percent of skim proceeds).",
      "attackScenario": "No attacker. 1. Tokemak Autopool drawdown puts the strategy below par. 2. A large staker calls autoAnnihilate (the ONLY reward path once claim() is gated off). 3. _isUnderwater true -> buffer branch pays the full amount, relinquishPrincipal writes down principal without redeeming, safeguard sees received == needed and does not revert. 4. Buffer empty. 5. Every other staker's withdraw() reverts.",
      "profitability": "n/a — not an extraction; a first-come-first-served consumption of a shared availability resource.",
      "affectedParties": ["remaining StableStaker stakers (exit availability)", "protocol (orphaned reflax residual, ledger QA-09 / F-03)"],
      "confidence": "high (code-quoted derivation; consumer code not yet landed so no PoC possible)",
      "lawBasis": "Law 1 (availability/exploit surface) + Law 2 (story-025 safeguard does not deliver its stated guarantee)",
      "escalationTrigger": "stable-staker bumps lib/reflax-yield-vault to a story-050 commit AND lands autoAnnihilate sourcing via _routeExit(..., true) AND the wired strategy can go below par.",
      "recommendation": "Correct story-025, not reflax: take the measurement across strategy.withdraw specifically, or require(!_isUnderwater(token, strategy)) inside autoAnnihilate. Add an acceptance test: below-par strategy + non-empty buffer => autoAnnihilate reverts and idle balance is byte-unchanged.",
      "channel": "spec-conformance.md (cross-protocol integration, F-03 precedent) — NOT the QA bundle"
    },
    {
      "id": "ECON-002",
      "label": "ECON-17-01",
      "type": "over-issued-guarantee / share-cap contention",
      "severity": "low",
      "proposedSeverity": "Low (characterisation supporting ECON-17-02; the standalone client-vs-client leg is SUPPRESSED)",
      "contract": "src/AYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 571, "lineStart": 571, "lineEnd": 583,
      "description": "The base default quotes netGuaranteed from clientBalances alone and never reads the position, so N clients are each guaranteed their full principal against one global share balance; the sum of simultaneously-valid floors is N x over-issued when the position is impaired. _disposeShares caps at the GLOBAL vault.balanceOf(strategy) and _withdrawInternal debits the REQUESTED amount, so the deficit concentrates 100% on the last exiter with no buffer and no pro-rata.",
      "economicImpact": "Redistribution of a pre-existing market loss, not creation: books stay square (totalDeposited -> 0, shares -> 0). No value is minted.",
      "attackScenario": "No attacker required: an ordinary vault drawdown plus two clients exiting in the normal course.",
      "profitability": "n/a — no extraction primitive.",
      "affectedParties": ["last-exiting client"],
      "pocFiles": [
        "workspace/reflax-yield-vault/test/poc-run17-econ-exit-preview.t.sol (3/3 PASS)",
        "workspace/reflax-yield-vault/test/poc-run17-preview-exit.t.sol::testH5_TwoClientsQuotedTheSameShares (PASS)"
      ],
      "pocResult": "Direct strategy, 50% loss, 2 clients: floors sum to 2x the position; clientA takes 1000e18 (the whole position), clientB receives 0 and is debited 1000e18. Market strategy: clientB receives 20e18 against a 980.1e18 quote.",
      "suppression": "The live topology (MigrateStableStakerMainnet.s.sol:496 + :595 wire PhusdStableMinter AND StableStaker to the same strategy) is exactly the minter-cushion commingled-share-cap pattern declared BY DESIGN. Minter has no withdraw path -> cannot race. Candidate Medium SUPPRESSED; NO per-client cap recommended. The V2 phUSD-dilution leg is NOT suppressed (V2 emits Antimatter into unbacked phUSD) but is ROUTED to the existing unbacked-phUSD channel, not re-filed here.",
      "dedupDisclosure": "Same shape as ledger M-03 (3c8331040bba, status merged into M-02, 'Requested-not-received decrement socialises slippage, causing last-withdrawer shortfall'). DIFFERENT primitive: M-03 is on ERC4626MarketYieldStrategy with an AMM-slippage deficit bounded at slippageToleranceBps x tradeSize and a minOut revert; this is on ERC4626YieldStrategy with an unbounded vault drawdown and NO minOut at all. NOT re-filed — M-03 stays merged. M-01-run12 (realizableSolvency, false-positive) NOT re-escalated: distinct root cause.",
      "confidence": "high"
    },
    {
      "id": "ECON-003",
      "label": "L-01 blast-radius extension (fold, do not re-file)",
      "type": "owner-footgun",
      "severity": "low",
      "proposedSeverity": "fold into existing ledger L-01 (6460e353, open, Low)",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "setSlippageTolerance / _creditedPrincipal / previewExitFor",
      "line": 89, "lineStart": 89, "lineEnd": 94,
      "description": "setSlippageTolerance accepts MAX_BPS. At MAX_BPS _creditedPrincipal returns 0 and minOut is 0, so a deposit swaps at any rate and books ZERO principal (_depositInternal has no require(creditedPrincipal > 0)). Story-050 adds a third dependent surface: previewExitFor returns (0,0), which testH4 proves is indistinguishable from an unknown account, a zero netWanted, and a drained account.",
      "economicImpact": "A depositor's entire deposit is converted to unattributed protocol surplus with no booked claim; the only new alarm is ambiguous with three benign states.",
      "affectedParties": ["depositing client"],
      "lawBasis": "Law 3 — surprise test PASSES (a slippage TOLERANCE zeroing out principal CREDITING is non-obvious). In scope as a footgun.",
      "safeConfig": "require(_bps <= 1000) in the setter; never deploy at the zero default; pause deposits before raising tolerance; add require(creditedPrincipal > 0) in _depositInternal; monitor previewExitFor(token, fundedClient, 1) as a MAX_BPS canary.",
      "dedupDisclosure": "Root cause already owned by ledger L-01, whose run08Note already records the deposit-side crediting blast radius. RECORD AS EXTENSION, DO NOT OPEN A NEW ENTRY.",
      "crossRepoWatch": "StableStakerV2 guards stake/depositFor with require(credited > 0) at :333 and :713 but the setYieldStrategy idle sweep at :294-298 does NOT — at MAX_BPS it sweeps the entire shared buffer in for zero credit. Empty-pool gate at :258 limits instantaneous exposure. For the next stable-staker run.",
      "confidence": "high"
    },
    {
      "id": "ECON-004",
      "label": "ECON-A surface extension (fold, do not re-file)",
      "type": "fee-blind-nav",
      "severity": "low",
      "proposedSeverity": "fold into existing ledger ECON-A (c50c08f9, open, Low)",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "_exitFloor (and AYieldStrategy.previewExitFor)",
      "line": 127, "lineStart": 127, "lineEnd": 137,
      "description": "Both previews are built on the fee-free convertToAssets and therefore over-quote on a fee-charging vault — the same root cause as ECON-A/L-16, now on two new call sites. Because previewExitFor is a new function it would mint a FRESH fingerprint dedup cannot catch; disclosed rather than filed.",
      "economicImpact": "Measured at ECON-A: 0.2107 bps (autoDOLA) / 1.0742 bps (autoUSD) on the live autopools, flat across size. Below protocol slippage tolerances -> honest Low. Scales LINEARLY with the external vault's exit fee.",
      "dedupDisclosure": "Same root cause as ECON-A (run-16 L-16). Re-file basis: NONE. Carry ECON-A's severityScaling note forward.",
      "additionalNote": "StableStaker's _isUnderwater is built on the SAME fee-blind convertToAssets (via totalBalanceOf), so the §2.3 guard-dominance proof covers the vault-LOSS deficit but NOT the exit-FEE deficit. That residual is exactly ECON-A's measured magnitude.",
      "confidence": "high"
    },
    {
      "id": "ECON-005",
      "label": "REFUTATION — preview manipulation",
      "type": "refutation",
      "severity": "none",
      "proposedSeverity": "NOT A FINDING — refuted, recorded so it is not re-derived",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "_exitFloor",
      "description": "No profitable within-block manipulation of previewExitFor exists. (a) grossToRequest reads no manipulable quantity on either path. (b) convertToAssets(convertToShares(x)) is price-invariant — PoC: an 11x share-price donation moves netGuaranteed by ~1 wei, and the direction favours honesty. (c) The only real lever (vault.balanceOf(strategy)) is onlyAuthorizedClient/onlyOwner. (d) Even an inflated quote converts to a revert under story-025's mandated measurement, so the attacker buys a failed transaction with an unrecoverable donation.",
      "pocFiles": ["workspace/reflax-yield-vault/test/poc-run17-preview-exit.t.sol::testEconRefute_DonationDoesNotInflateTheQuote (PASS)"],
      "residual": "A griefing/DoS surface remains (code-scan H-2: full-health quote immediately before a guaranteed withdraw revert, because _exitFloor never reads the AMM and IAMMAdapter exposes no quote member). Zero extractable value. Not escalated.",
      "confidence": "high"
    }
  ],
  "suppressionsApplied": [
    "externally-derived-yield = opportunity cost (buffer depletion NOT filed as value leak)",
    "minter-cushion / commingled share cap BY DESIGN (candidate Medium suppressed; no per-client cap recommended)",
    "M-01-run12 realizableSolvency false-positive NOT re-escalated",
    "C4 speculation-on-future-code (ECON-17-02 capped at Low with a dated trigger)"
  ],
  "suppressionsWithheld": [
    "minter-cushion premise is VOID for StableStaker V2 (Antimatter -> unbacked phUSD): the dilution leg is LIVE and ROUTED to the unbacked-phUSD channel (yield-claim-nft DEDUP-001 / antimatter run-01), not dropped and not re-filed here"
  ]
}
```

## 8. Watch notes

- **WATCH-17-E1 — the story-025 trigger.** §3.5. Fires at the next stable-staker regression run.
  Coincides with the ledger's existing `F-03` Medium re-evaluation gate; handle both together.
- **WATCH-17-E2 — two-client direct strategies are the mainnet topology.**
  `MigrateStableStakerMainnet.s.sol:496` + `:595` wire `PhusdStableMinter` **and** `StableStaker` to
  the same `newYsDola`/`newYsUsdc`. Suppressed here by the minter-cushion memo **on the premise that
  the minter has no withdraw path**. If a future story gives `PhusdStableMinter` any strategy-exit
  path, that premise dies and §2 becomes a live Medium immediately. **Reopen trigger.**
- **WATCH-17-E3 — unguarded idle sweep.** `StableStakerV2.sol:294-298`. §5 cross-repo note.
