# Plan — Codify `setYieldStrategy` as an empty-pool-only operation

**Target repo:** `stable-staker` (audited as `lib/stable-staker`, **read-only** here — implement upstream)
**Audited commit:** `93b7ce6` (`[story-009]`)
**Primary file:** `src/StableStaker.sol`
**Author/decision:** owner (justin), 2026-06-09 — supersedes the per-path guard approach
**Kanban status:** ready to pick up (Phase 1). Phase 2 (remainders) is post-audit.

---

## 1. Decision

Gate `setYieldStrategy` on an **empty pool**:

```solidity
require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");
```

Strategy (un)wiring becomes a configuration-time operation that is only legal when the pool holds
**no staked principal**. Enabling, swapping, or clearing a strategy on a *live* pool is forbidden in
code; the supported way to change strategy on a pool with stakers is a full terminal migration that
drains the pool to empty and revives it (`initiateMigration → batchMigrate/userMigrate →
finalizeAndReset → setYieldStrategy`).

This is the **stronger of the two mitigations** the M-01 report itself offered (the other being
"reconcile `totalStaked -= (idleBalance - credited)`"). We choose the gate because it removes the
*precondition* for the whole bug family rather than patching each desync path one at a time.

---

## 2. Why — one invariant beats whack-a-mole

`setYieldStrategy` has produced four findings, all the same shape: **in-place principal movement
leaves `totalStaked` stale while every guard is blind to the desync.**

| Finding | Fingerprint | Path | Status today |
|---|---|---|---|
| M-01 (ss6m1) | `dab5a656` | first-adoption sweep over a non-empty idle pool discards `strategy.deposit`'s credited return | **submitted, live @ 93b7ce6** |
| M-02 | `678e6fa2` | swept realized pile back into a strategy during active migration | fixed (story-006; `poolState != Migrating`) |
| M-06 | `dbdc3ac9` | underwater in-place swap re-arms the withdraw block | ack; rate guard added (story-008) |
| M-07 (ss9m7) | `969722dc` | AMM **execution** slippage bypasses the story-008 **rate** guard | wont-fix (operational: "use migration") |

The reason guards keep failing: they compare quantities the strategy *can* see
(`_isUnderwater` = `totalBalanceOf < principalOf`, both on the strategy's own basis — `src/StableStaker.sol:740-741`)
and never the quantity that actually desyncs (`totalStaked` vs `strategy.principalOf`). A deposit/exit
haircut is booked as protocol surplus, so the strategy reads **at par** while the farm is overstated
— `_isUnderwater` is false, `withdraw` is not blocked, and the last withdrawer is silently shorted on
the healthy path (M-01), or the realized loss is FCFS-concentrated (M-06/M-07).

M-07 proved the rate/execution gap is **not guardable ex-ante**: a strategy can read solvent and still
return less than principal once unwound through an AMM. The only robust answer is to never move staked
principal through this function. M-07's accepted disposition already *says* this ("in-place
`setYieldStrategy` on an AMM/execution-priced strategy with staked users is prohibited — use a full
terminal migration") and `lib/stable-staker/CLAUDE.md` already advises "replace only while
`totalStaked == 0`." This change **codifies that operator discipline as a `require`.**

---

## 3. The change

### 3.1 Code edit

Insert the gate as the second statement of `setYieldStrategy` (`src/StableStaker.sol:219-220`), right
after the existing `poolState == Active` check:

```solidity
    function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
        require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
+       // Strategy (un)wiring is an EMPTY-POOL-only operation. Once a pool holds staked principal,
+       // moving that principal in place desyncs `totalStaked` from `strategy.principalOf` whenever
+       // the deposit/exit haircuts (market/AMM strategies). That is the shared root cause of
+       // ss6m1/M-01 (first-adoption sweep), M-06 (underwater swap) and M-07 (AMM-execution swap):
+       // no guard compares `totalStaked` against strategy principal, so the desync is silent.
+       // Principal may only move through the realize-once-and-socialize terminal-migration path.
+       // To change strategy on a live pool:
+       //   initiateMigration -> batchMigrate/userMigrate -> finalizeAndReset (pool now empty) -> setYieldStrategy
+       require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");

        IYieldStrategy old = yieldStrategy[token];
        ...
```

No other lines change. With `totalStaked == 0`:
- the old-strategy block (`L223-246`) still runs but `_routeExit` is skipped (`staked > 0` is false),
  so it only force-revokes the old allowance — harmless;
- the idle sweep (`L256-259`) sees at most donation dust, and with no staked principal there is **no
  user to short** even if dust is swept (the gap is pure protocol surplus).

### 3.2 Predicate choice — `totalStaked`, not `idleBalance`

Gate on `poolInfo[token].totalStaked`, **not** `IERC20(token).balanceOf(this) > 0`. A stray
token transfer / donation makes the contract's balance non-zero on an otherwise empty pool; gating on
balance would let anyone **permanently brick** `setYieldStrategy` for a token with a 1-wei donation.
`totalStaked` tracks credited user principal only and is donation-immune.

### 3.3 Permit / forbid truth table

| Scenario | `totalStaked` | Before | After |
|---|---|---|---|
| Wire strategy before anyone stakes | 0 | ✅ | ✅ |
| Re-wire after full migration + `finalizeAndReset` (revived empty pool) | 0 | ✅ | ✅ |
| Clear to idle (`address(0)`) on an empty pool | 0 | ✅ | ✅ |
| **First adoption over a non-empty idle pool** (M-01) | >0 | ✅ | ❌ revert |
| **In-place swap on a live pool** — underwater (M-06) | >0 | ❌ (rate guard) | ❌ revert |
| **In-place swap on a live pool** — AMM exec slippage (M-07) | >0 | ✅ (slips through) | ❌ revert |
| In-place swap on a live pool — at/above par | >0 | ✅ (tested!) | ❌ revert |

The last row is an intentional **capability removal** — see §4.

---

## 4. Behavioral change & operator runbook

This is **not** a transparent bug patch. It removes the ability to enable, swap, or clear a strategy
on any pool that currently has stakers — *including* the at-par / above-par in-place swaps that today
have passing tests (`test_setYieldStrategy_swap_atPar_succeeds`,
`test_setYieldStrategy_swap_abovePar_succeeds_yieldLeftBehind`). That removal is the point: those
"safe" swaps are only safe under rate accounting, and M-07 showed execution slippage defeats that.

**Supported replacement — change strategy on a live pool (already the documented revival runbook,
`src/StableStaker.sol:582-583`):**

1. `migrator.initiateMigration(token)` — settles & freezes emissions, snapshots `(R, P)`, realizes the
   whole position once, decouples the strategy, sets `poolState = Migrating`.
2. `batchMigrate` / `userMigrate` until every position has exited at the fixed `p_i·min(R,P)/P` credit
   (loss socialized pro-rata via the snapshot — *not* FCFS).
3. `finalizeAndReset(token)` — requires `stakerCount == 0 && totalStaked == 0`; clears the snapshot and
   flips `Migrating → Active`. Pool is now empty with `yieldStrategy == address(0)`.
4. `setYieldStrategy(token, freshStrategy)` — now passes the `totalStaked == 0` gate cleanly.

(The cross-contract `StableStakerMigrator` flow to a *new* staker is the other way to reach an empty
old pool.)

**Caveat to flag to operators:** step 3's revival does **not** reset `phusdPerSecond` or re-wire the
strategy (finding `ss9l1`). Wrap the reconfiguration in the pause/unpause runbook and explicitly set
both emission rate and strategy on the revived empty pool before unpausing. This is tightened in
Phase 2 (§7, R2).

---

## 5. Findings closed / subsumed

| Finding | Effect of the gate |
|---|---|
| **M-01 (ss6m1 / `dab5a656`)** | **Closed.** First-adoption over a non-empty idle pool now reverts; the discarded-credited sweep is unreachable with staked principal present. |
| **M-06 (`dbdc3ac9`)** | **Subsumed.** In-place swap on a live pool is impossible; the story-008 `!_isUnderwater(old)` guard becomes redundant-but-harmless (see R3). |
| **M-07 (ss9m7 / `969722dc`)** | **Subsumed → upgraded from wont-fix to enforced.** The operational "use migration not in-place swap" disposition is now a `require`, not operator trust. |
| **M-02 (`678e6fa2`)** | Unaffected / not regressed — the new gate (`Active` + empty) is strictly stronger than the existing `poolState != Migrating` guard. |
| **M-05 (`0dca43f3`)** | **NOT closed** — different function (`emergencyWithdraw`). Remainder (§7, R1). |

---

## 6. Phase 1 implementation tasks (kanban)

1. **Add the gate** — §3.1. One `require`, with the comment.
2. **Rework existing tests that wire a strategy on a non-empty pool.** Audit every call site:
   ```
   grep -rn "setYieldStrategy" test/
   ```
   - Tests that **stake then wire** expecting success → restructure to **wire then stake** (move the
     `setYieldStrategy` before the first `stake`). Candidates incl. `test/StableStaker.t.sol:305,332,371`,
     `test/Migration.t.sol:74,249,518`, `test/YieldStrategyIntegration.t.sol:108`.
   - Tests that encode the **removed in-place-swap capability** → **invert to expect revert** (or delete):
     `test_setYieldStrategy_swap_drainsOldAndReCustodiesIntoNew`,
     `test_setYieldStrategy_swap_atPar_succeeds`,
     `test_setYieldStrategy_swap_abovePar_succeeds_yieldLeftBehind`,
     `test_setYieldStrategy_swap_emptyOldStrategy_succeeds` (all in `YieldStrategyIntegration.t.sol`).
   - Tests that already wire on an empty/revived pool (e.g. `Migration.t.sol:567,648` post-`finalizeAndReset`)
     should stay green — confirm.
3. **New TDD tests** (per stable-staker Foundry conventions):
   - `test_setYieldStrategy_revertsOnNonEmptyPool_firstAdoption` — stake, then adopt a strategy → revert
     `"StableStaker: pool not empty"` (this is the ss6m1/M-01 regression test).
   - `test_setYieldStrategy_revertsOnNonEmptyPool_inPlaceSwap` — even at/above par.
   - `test_setYieldStrategy_succeeds_afterFinalizeAndReset` — full revival runbook end-to-end, then wire.
   - `test_setYieldStrategy_succeeds_withDonationDust_onEmptyPool` — donation dust does not brick the gate.
4. **Port/retire the PoCs.** The M-01 PoC (`workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol`)
   should now demonstrate the **revert** (the shortfall is unreachable). Same for the M-06/M-07 swap PoCs.
5. **Docs.** Update `lib/stable-staker/CLAUDE.md` "Yield strategies" section: change the soft "replace
   only while `totalStaked == 0`" guidance to a hard invariant ("`setYieldStrategy` reverts unless
   `totalStaked == 0`; change strategy on a live pool via the migration→finalizeAndReset runbook").
   *(`lib/` is read-only in the audit repo — this doc change ships in the upstream `stable-staker` repo.)*

---

## 7. Phase 2 — remainders to eliminate after audit

Once the gate lands and a regression `/full-audit stable-staker` confirms it closes M-01/M-06/M-07
with no new desync, sweep up what the gate does **not** touch:

- **R1 — `emergencyWithdraw` FCFS-at-par (M-05, `0dca43f3`, acknowledged Medium).** Different function;
  the gate is irrelevant to it. `emergencyWithdraw` over-redeems at the depressed price so early exiters
  are whole and late exiters absorb the shortfall. The intended fix (pay the caller the **pro-rata** rate,
  caller eats own haircut) was deferred pending `relinquishPrincipal`, which **has now landed** (story-007)
  and is consumed by the buffer/withdraw path — so this is **unblocked-but-unapplied**. Make
  `emergencyWithdraw` pro-rata using the now-available `relinquishPrincipal`.
- **R2 — `finalizeAndReset` revival footgun (`ss9l1`, Low/QA).** Now **load-bearing**: this gate makes the
  migration→`finalizeAndReset` runbook the *only* way to re-wire a live pool, so revival hygiene matters
  more. Harden `finalizeAndReset` to zero `phusdPerSecond` (or require an explicit re-config) and
  clear/re-assert the `yieldStrategy` binding on revival, so a revived pool never resumes on stale
  emission/strategy settings.
- **R3 — redundant guard + residual discarded-credited sweep (cleanup).** With the empty-pool gate, the
  story-008 `!_isUnderwater(old)` guard (`L230`) and the idle sweep's discarded `strategy.deposit`
  return (`L256-259`) are no longer load-bearing for user safety. Either leave them as defense-in-depth
  (document as subsumed) or simplify; if kept, capture the sweep's credited return for cleanliness so
  donation dust isn't silently re-booked as surplus.
- **R4 — `withdrawDisabled` over-report (F-02, `a56f8778`, QA).** Cosmetic view/spec drift; fold into the
  same QA pass.

After Phase 2, re-run the audit so the ledger reflects M-05 fixed and ss9l1 resolved.

---

## 8. Acceptance criteria

- [ ] `setYieldStrategy` reverts `"StableStaker: pool not empty"` whenever `totalStaked > 0` (first
      adoption, swap, or clear), and succeeds on an empty/revived pool.
- [ ] Full revival runbook (`initiateMigration → batchMigrate/userMigrate → finalizeAndReset →
      setYieldStrategy`) passes end-to-end in tests.
- [ ] M-01/M-06/M-07 PoCs now assert the revert; `forge test` green.
- [ ] `lib/stable-staker/CLAUDE.md` yield-strategy guidance updated to the hard invariant.
- [ ] Regression `/full-audit stable-staker` shows `dab5a656`, `dbdc3ac9`, `969722dc` closed with no new
      `setYieldStrategy` desync finding.
