# Script Audit Review — `migrate:saga2.2-migrate`

**Project:** phoenix-phase-2-staging
**Run:** phoenix-phase-2-staging-17
**Entry point:** `migrate:saga2.2-migrate` → `script/MigrateSaga2Migrate.s.sol:MigrateSaga2Migrate.run()`
**Submodule HEAD:** `3d5247488800ba3b1e9f158e71ec7f1be7e8258d`
**Saga position:** STEP 2.2 of "MIGRATE SAGA 2 — InPlaceMigrator route" (2.1 deploy/freeze → **2.2 migrate (this)** → 2.3 accumulator rewire)
**Fork verification:** mainnet fork, block `25322425` (ts `1781520779`), preview/prank only — never broadcast.

> **Scope.** This review covers ONLY entry point 2.2 (`migrate:saga2.2-migrate`) and the knock-on findings in its cluster. 2.1 (`migrate:saga2.1-deploy`, just audited and fixed) and 2.3 (`migrate:saga2.3-rewire` / SYA repoint) are referenced solely as upstream enabler / downstream acceptance context where strictly necessary; neither is re-audited here.

---

## Executive summary

`migrate:saga2.2-migrate` is the time-critical middle leg of the InPlaceMigrator migration: it tops up Phlimbo, skims surplus, pauses and terminally drains the live StableStaker, executes the in-flight minter `totalWithdrawal`, rewires both pools onto the V2 strategies, re-injects parked stakers at par, seeds the V2 minter, returns the skim as a set-aside buffer, and unpauses. On a correctly-provisioned happy path the script **does exactly what it intends** — all 11 stated purposes execute end-to-end on a mainnet fork, every one of the 12 observed state writes maps to a stated purpose, there are **zero unintended on-chain writes**, `mainnet-addresses.ts` is untouched, the JS chain is empty, and "No address change" holds. The audit's concern is entirely with the **irreversible ordering**: the script commits its terminal, unrecoverable operations (pause → terminal drain → rewire) *before* it validates the two preconditions on which success depends — that the `totalWithdrawal` window is still `Executable` (**M-01**), and that the migrator's surplus allotment is large enough to gross-up parked stakers to par (**M-02**, fork-verified as the default-path outcome because 2.1 hardcodes both allotments to `0`). Either gap strands the entire staked pool paused + terminally-migrating, with principal recoverable only via the 14-day `claimTimedOut` hatch. Severities were independently re-derived and held: the cluster ceiling is **Medium**, not High — there is **no theft path** (InPlaceMigrator invariant C) and **no permanent loss** (principal is fully recoverable); do not read either Medium as funds lost.

**Finding counts:** High 0 · Medium 2 · Low 2.

| Label | Severity | Root cause | Location |
|-------|----------|-----------|----------|
| [M-01](#m-01--missing-totalwithdrawal-window-assertion-medium) | Medium | `MissingWindowAssertion` | `MigrateSaga2Migrate.s.sol:_executeMinterWithdrawal` (L155–161) |
| [M-02](#m-02--migratein-bricks-on-an-under-sized-21-allotment-medium) | Medium | `AllotmentSufficiencyNotGuaranteed` | `InPlaceMigrator.sol:_reinjectWithTopup` (L262–294) |
| [L-01](#l-01--terminal-migration-strand-risk-low) | Low | `TerminalMigrationStrandRisk` | `MigrateSaga2Migrate.s.sol:run` (L84–144) |
| [L-02](#l-02--non-idempotent-script-low) | Low | `NonIdempotentScript` | `MigrateSaga2Migrate.s.sol:run` (L84–144) |

---

## Closure overview

```
                         migrate:saga2.2-migrate  (MigrateSaga2Migrate.run)
                                       |
   reads  saga2-deployments.json  <----+----> writes  NO off-chain state
   (.migrator/.ysDolaV2/.ysUsdcV2/      |             (mainnet-addresses.ts NOT touched;
    .minterV2 — produced by 2.1)        |              jsChain pre=[] post=[])
                                        |
   ====================  ON-CHAIN TARGETS (all mutations intended)  ====================
   PhlimboV2 0x6084..AeE0 ........... collectReward(60e6)               [step2]
   StableStaker 0xbce8..079A ........ setPauser/pause ... unpause/restore [step1,10]
                                      finalizeAndReset/setYieldStrategy   [step6 rewire]
   OLD DOLA YS 0x90ce..77F9 ......... setWithdrawer/skimSurplus           [step3]
                                      totalWithdrawal(DOLA, MINTER_V1)    [step5]
   OLD USDC YS 0x90af..2470 ......... setWithdrawer/skimSurplus           [step3]
                                      totalWithdrawal(USDC, MINTER_V1)    [step5]
   USDe MKT YS 0xaC2e..7f95 ......... setWithdrawer/skimSurplus -> STAKER [step3]
   InPlaceMigrator (2.1) ............ initiateMigration/migrateOut  [step4 TERMINAL]
                                      migrateIn(token,0,max)              [step6]
   PhusdStableMinter V2 (2.1) ....... noMintDeposit (seed recovered)      [step8]
   DOLA/USDC ERC20 .................. safeTransfer skim -> STAKER buffer  [step9]

   ----- ORDERING (the audit's central concern) -----
   [step1 pause][step2 skim][step3 ensure-withdrawer]   <- reversible
   [step4 initiateMigration + migrateOut]               <- TERMINAL (no resume)  <== irreversible point
   [step5 totalWithdrawal]   <- M-01 window not asserted here, AFTER terminal drain
   [step6 rewire + migrateIn] <- M-02 allotment exhaustion reverts here, AFTER terminal drain
   [step8 seed][step9 buffer][step10 unpause]
```

Source surface note: `MigrateSaga2Migrate.s.sol` imports only forge-std + OpenZeppelin and reaches every protocol contract through **inline interfaces** (`IStaker`, `IOldYS`, `IMigrator`, `IMinterV2`, `IPhlimbo`). This is an ABI-drift surface (selectors must match deployed bytecode, not just current lib source). The fork-preview cleared it: all read AND state-changing selectors execute against the deployed (pre-current-lib) bytecode without revert — the 2.1 M-01/M-02 ABI-mismatch lens is **CLEARED for 2.2**.

---

## Question 1 — Does it do what it intends?

**Yes, on a correctly-provisioned happy path.** The script's stated intent (script header, NatSpec, plan §5 Script 2) is an 11-step sequence; all 11 purposes execute end-to-end on the fork under scenario A (correctly-sized 1000e18 DOLA / 1000e6 USDC allotment), and every declared post-condition passes.

| # | Stated purpose | Step | Fork result |
|---|----------------|------|-------------|
| 1 | Top up Phlimbo reward pot with 60 USDC (`collectReward(60e6)`) | 2 | Executed; +60e6 USDC to PhlimboV2 |
| 2 | Skim surplus: OLD DOLA/USDC → owner (parked), USDe → staker (buffer) | 3 | DOLA 2.61e18 / USDC 6.36e6 → OWNER; USDe → STAKER |
| 3 | Pause the staker for the rewire (capture & restore real pauser) | 1,10 | Paused then unpaused; `pauser` restored to `0x7c5A8Eef…` |
| 4 | Drain the staker FIRST (`initiateMigration` + `migrateOut`) | 4 | `stakerCount==0`; principal parked in migrator (3 DOLA + 6 USDC stakers) |
| 5 | Execute minter `totalWithdrawal` phase-2 SECOND (minter absorbs haircut) | 5 | Recovered 13816e18 DOLA / 11934e6 USDC → OWNER; `principalOf(MINTER_V1)==0` |
| 6 | Rewire pools onto new strategies (`finalizeAndReset` + `setYieldStrategy`) | 6 | `yieldStrategy(DOLA)==ysDolaV2`, `(USDC)==ysUsdcV2` |
| 7 | Re-inject parked stakers at par (`migrateIn`, surplus-funded top-up) | 6 | V2 DOLA staker principal 1060e18 ≥ old 1033e18; `parkedUserCount==0` |
| 8 | Seed V2 minter with recovered funds (`noMintDeposit`, amount actually received) | 8 | V2 minter principal 13816e18 DOLA / 11933e6 USDC |
| 9 | Transfer skimmed DOLA/USDC surplus to staker as set-aside buffer (AFTER rewire) | 9 | Skim → STAKER idle balance |
| 10 | Unpause and restore original pauser | 10 | `!paused()`; `pauser()==realPauser` |
| 11 | No new contracts deployed → `mainnet-addresses.ts` NOT touched, no JS chain | — | Confirmed (see Question 2) |

**Hard-ordering invariant honoured.** Plan §3.2 requires staker `migrateOut` to precede the minter `totalWithdrawal` phase-2; the script honours this (steps 4 → 5), so the minter — not the parked stakers — absorbs any haircut.

**Pre-conditions.** All declared pre-conditions are satisfiable on live state **except** the absent `saga2-deployments.json` (`migrator()==0x0` live confirms 2.1 has not been broadcast). This is the expected `2.1-before-2.2` ordering dependency, not a 2.2 defect; the harness synthesizes the 2.1 wiring under `vm.prank(OWNER)` to exercise 2.2.

**Post-conditions.** All `_postAssert` checks pass under scenario A: both pools rewired to V2, `parkedUserCount==0`, `!paused()`, `pauser()==realPauser`, and `principalOf(MINTER_V1)==0` on both old strategies.

**Caveat — the happy path is conditional on two preconditions the script never enforces.** It is true *today* (block 25322425) that the `totalWithdrawal` windows are open and the (harness) allotment is sized correctly. The script does not *guarantee* either at live broadcast time — those gaps are M-01 and M-02 (Question 3). "Does what it intends" therefore holds for the implementation logic, but the script omits the go/no-go assertions that would make the intent self-protecting.

---

## Question 2 — Does it introduce unintended side effects?

**No.** The fork-preview executed 2.2's exact body (script lines 84–144) on the same fork after replaying the 2.1 wiring, prank/preview only. Result:

- **12 observed state writes, all mapped to a stated purpose** — see the closure overview and the per-purpose table above. Each write in `side-effects.json` carries `intended: true`.
- **ZERO unintended on-chain writes.** `side-effects.json.unintendedEffects` is empty.
- **`mainnet-addresses.ts` untouched.** 2.2 deploys no contracts; the script comment (line 33) and the entry-manifest both confirm no patcher runs in 2.2 (only 2.1 patches `mainnet-addresses.ts`).
- **Empty JS chain.** `jsChain.pre=[]`, `jsChain.post=[]`; 2.2 runs no node scripts in either variant and writes no off-chain state. Its only off-chain dependency is *reading* `saga2-deployments.json` produced by 2.1.
- **"No address change" held** — confirmed by `noAddressChangeConfirmed` (mainnet-addresses untouched, empty JS chain, no new deploys).
- **ABI write-path drift cleared.** `skimSurplus` / `totalWithdrawal` / `setWithdrawer` on the OLD strategies and `finalizeAndReset` / `setYieldStrategy` / `pause` / `unpause` / `setPauser` on the staker all execute (not revert) against the deployed pre-current-lib bytecode.

One observation belongs here as a *fork artifact, not a side effect*: under a `+72h` `vm.warp` window-expiry probe, the external autoDOLA/autoUSDC ERC4626 vaults return `InvalidDataReturned()`. This is stale external vault/oracle state under warp, not reachable on a non-warped live broadcast, and not a property of the script. It is the reason M-01's catastrophic branch could not be warp-PoC'd (stated honestly under M-01).

---

## Question 3 — Have other problems surfaced because of it?

The script's logic is faithful, but its **ordering** places terminal, unrecoverable operations ahead of the validation that determines whether they should run at all. Four findings surface from this structure. Two have a distinct, concretely-reachable precondition that drives availability/value impact (Mediums); two are the shared structural root cause and its idempotency corollary (Lows). All four pass the Three-Law surprise test as non-obvious operator footguns (Law 3, in scope), and **none has a theft path** — InPlaceMigrator invariant C forecloses any path that sends parked principal anywhere but its original owner, so the cluster ceiling is Medium.

> **Convergence note (anti-double-count).** M-01, M-02 and L-01 converge on the *same* worst-case — the live staker stranded paused + terminally-migrating, all principal parked behind the 14-day `claimTimedOut` hatch. To avoid triple-counting one shared outcome, only the two findings with a *distinct, concretely-reachable* trigger are rated Medium (M-01 window-lapse, M-02 under-sized allotment — the latter fork-verified). L-01 is the structural sequencing umbrella the two share and is rated Low; L-02 is the idempotency corollary.

---

### M-01 — Missing `totalWithdrawal` window assertion (Medium)

- **Root cause:** `MissingWindowAssertion`
- **Location:** [`script/MigrateSaga2Migrate.s.sol:_executeMinterWithdrawal`](../../findings/medium/M-01-missing-totalwithdrawal-window-assertion.json) (L155–161; preflight L191–210)
- **Record:** `reports/phoenix-phase-2-staging-17/findings/medium/M-01-missing-totalwithdrawal-window-assertion.json`
- **PoC:** missing-assertion path fork-confirmed PRESENT; catastrophic half-commit branch documented-only (see PoC strength below)
- **Faithfulness:** deviation — the script does not enforce its own documented time-critical-window intent (also routed to spec-conformance)

**Description.** The entire 2.2 leg is documented as time-critical: it "must run inside the `[init+24h, init+72h]` Executable window" of the in-flight `totalWithdrawal` on the OLD DOLA/USDC strategies (intent.md §4, script header). Yet the script **never asserts the window**. `_executeMinterWithdrawal` blindly calls `oldYS.totalWithdrawal(token, MINTER_V1)`. AYieldStrategy uses *lazy expiry* — the status only flips to `Expired` on the next call — so if the phase-1 window has lapsed, `totalWithdrawal` takes the `None`/`Expired` branch and **re-initiates a fresh phase-1 instead of executing, recovering 0**. `recovered==0` then makes `_seedV2` a no-op (early return), the minter's principal is **not** drained, and `_postAssert`'s `principalOf(token, MINTER_V1)==0` fails. The preflight only smoke-reads `principalOf(...) >= 0` (always true) — it does **not** check that the withdrawal status is `Executable`.

**Impact.** No direct theft (invariant C), so High is excluded. The drain at step 5 runs **after** the staker has been paused (step 1), skimmed (step 2), terminally migrated and drained (step 4, no resume path) and rewired (step 6). Under ordinary forge simulation a failed `_postAssert` aborts the whole broadcast atomically (no half-commit). But in a live-divergent run — preview/broadcast divergence across the window edge, or `--skip-simulation` — the staker has already drained at par into the migrator on the earlier successful txs, and the minter is left with a freshly **re-armed 24h phase-1** it must wait out, with ~13816 DOLA + ~11934 USDC stranded on the retired old strategy. The minimum-guaranteed harm (a wasted, irreversible terminal-migration session + stranded minter principal behind a re-armed window) is itself Medium-band availability harm and does not depend on the worst branch. This is the Medium "protocol function/availability impacted, value leak with stated assumptions and external requirements" band.

**PoC strength (stated honestly, no overstatement).** The missing-assertion code path is unambiguous and fork-confirmed PRESENT (preflight has no status check; the `recovers-0` re-initiate mechanism is dynamically demonstrated on the real deployed bytecode). The **catastrophic half-commit branch is documented-only / source-reasoned, not warp-PoC'd**: window-expiry could not be fork-demonstrated by `vm.warp` because the external autoDOLA/autoUSDC ERC4626 vault returns `InvalidDataReturned()` under `+72h` warp — a fork-warp artifact of stale external state, not a property of the script. Severity rests on the *minimum-guaranteed* outcome, so it is held at Medium rather than inflated to a plausibility-graded High on the strength of an un-warpable branch.

**Law 3.** Non-obvious footgun, in scope. The runbook *declares* the window mandatory but the script emits no status signal and the happy path works at the current block; a competent non-malicious owner would be surprised that an off-window broadcast silently re-initiates and strands principal. This is the script's missing assertion, not a visibly-wrong owner choice.

---

### M-02 — `migrateIn` bricks on an under-sized 2.1 allotment (Medium)

- **Root cause:** `AllotmentSufficiencyNotGuaranteed`
- **Location:** nested [`lib/stable-staker/src/InPlaceMigrator.sol:_reinjectWithTopup`](../../findings/medium/M-02-migratein-bricks-undersized-allotment.json) (L262–294; revert at L282)
- **Record:** `reports/phoenix-phase-2-staging-17/findings/medium/M-02-migratein-bricks-undersized-allotment.json`
- **PoC:** `workspace/phoenix-phase-2-staging/test/PoC_Saga22_M02_AllotmentBrick.t.sol` — **VALIDATED, passing**, fork block 25322425 (4 tests; 6/6 suite)
- **Cross-entry lineage:** operational re-exposure of stable-staker `ss12m1` / M-01 (fingerprint `970d7307328df6b8`, **FIXED**) on the saga2.2 `migrateIn` leg — cite lineage, do not re-report the contract-level finding

**Description.** Step 6 `migrateIn(token, 0, max)` re-credits each parked staker via `depositFor(amt)`, which credits only the strategy's haircut-reduced return. The ERC4626 redeem-then-deposit round-trip realizes a small migration slippage **even on solvent pools** (totalBalance > principal on the fork), so `credited < amt` for every staker and the surplus-funded gross-up top-up fires. The top-up is funded from the migrator's surplus (`balance - totalParked`) — exactly the `DOLA_ALLOTMENT` / `USDC_ALLOTMENT` transferred in by 2.1. If that surplus is insufficient, `_reinjectWithTopup` reverts `InPlaceMigrator: top-up surplus exhausted` (line 282) and the whole batch reverts. 2.1 hardcodes both allotments to `0` behind a `require(>0)` tripwire — but the tripwire only proves **non-zero, not sufficient**, and it lives in the *predecessor* script, so the operator setting it has no in-script signal of the per-staker shortfall 2.2 will actually need.

**Impact.** No theft — invariant C (source-verified, lines 244/320/337–339) guarantees parked principal can only return to its original owner, and `claimTimedOut` (lines 306–323) is a permissionless, self-only, principal-returning hatch any parked user can call unilaterally after the 14-day `migrationTimeout`. The lock is **total but TEMPORARY, attacker-free, and SELF-CURING**, so High is excluded. The brick lands at step 6 **after** pause (step 1), skim (step 2), the TERMINAL `initiateMigration`+`migrateOut` (step 4 — the pool can never resume healthy operation), and the rewire. The staker is left paused, terminally migrating, with **ALL** stakers' principal parked, recoverable only via `claimTimedOut` after 14 days (**principal-only, no further phUSD**). The realized leak is the forgone phUSD/yield and the time-value of the lockup — in-motion/unmatured yield, independently capping this at Medium.

> **Worst-case principal is FULLY RECOVERABLE (invariant C) — there is no theft and no permanent loss.** A reader must not mistake this Medium for funds lost.

**Fork verification.** At block 25322425: scenario B (zero allotment) and scenario C (1 wei) both revert `top-up surplus exhausted` at `migrateIn` step 6, *after* the terminal drain; scenario A (1000e18/1000e6) completes and clears parked stakers. The contrasting **pass** in the PoC uses ~10× the measured floor. Measured minimum allotment (scenario D): **~0.0149 DOLA** (`14898868155834087`, 3 stakers) / **~0.198 USDC** (`197719`, 6 stakers); 1 wei passes the 2.1 `require(>0)` tripwire but still bricks. Absolute cost is sub-dollar, but **because 2.1 hardcodes both allotments to `0`, the brick is the DEFAULT path absent a manual fix** — this is verified, not hypothetical, which makes it the single most important item to surface.

**Law 3.** Non-obvious footgun, in scope. An owner who sees the `require(>0)` tripwire PASS would reasonably believe the allotment is adequate; the tripwire signals "set" but silently fails to signal "sufficient", and the sizing lives in a different script with no in-script sufficiency check.

---

### L-01 — Terminal migration strand risk (Low)

- **Root cause:** `TerminalMigrationStrandRisk`
- **Location:** [`script/MigrateSaga2Migrate.s.sol:run`](../../findings/low/L-01-terminal-migration-strand-risk.json) (L84–144)
- **Record:** `reports/phoenix-phase-2-staging-17/findings/low/L-01-terminal-migration-strand-risk.json`

**Description.** The broadcast variant runs `--slow` (one tx at a time against the live chain) and `&&`-chains a separate preview as its only gate. Any tx that succeeds in simulation but reverts live due to state divergence (window edge, pool drift changing the `migrateIn` shortfall, MEV/front-run on the skim or external vault) lands **mid-sequence**. Because `initiateMigration` (step 4) is TERMINAL (no resume; stake/withdraw/emergencyWithdraw all blocked while active) and the staker is paused (step 1), a revert after step 4 leaves the live staker with **no clean recovery script** — only the break-glass siblings (`UnpauseStakerBreakGlass` / `ResumeStableStakerMigration`) and, for users, `claimTimedOut` after 14 days.

**Why Low, not Medium.** This is the structural sequencing root cause **shared** by M-01 and M-02 — irreversible pause/`initiateMigration` ordered ahead of the go/no-go checks. Its two concretely-reachable, impact-driving *instances* are already carried at Medium; rating the umbrella Medium as well would triple-count one shared worst-case. It is kept as a **distinct** Low (not merged away) because its recommendation — front-load all reversible ops / assert all go/no-go before the terminal point — is the generic fix that closes both Mediums at the structural level. A documented break-glass mitigation already exists in the cluster (its very existence confirms migrations here have stalled mid-flight before), which places the umbrella in the QA/Low band on its own merits.

---

### L-02 — Non-idempotent script (Low)

- **Root cause:** `NonIdempotentScript`
- **Location:** [`script/MigrateSaga2Migrate.s.sol:run`](../../findings/low/L-02-non-idempotent-script.json) (L84–144)
- **Record:** `reports/phoenix-phase-2-staging-17/findings/low/L-02-non-idempotent-script.json`
- **Cross-entry:** same root-cause CLASS as saga2.1 L-03 (`7dbab7885c0d9960`, wont-fix) but a **distinct** entry point / fingerprint via the entryPoint fold — correctly NOT suppressed as a 2.1 re-flag

**Description.** The script is a single linear sequence with **no step-completion checkpoints** (unlike the project's documented `progress.<chainId>.json` convention). If it reverts partway and is re-run: step 1 `pause()` on an already-paused staker reverts; step 4 `initiateMigration` on an already-active token reverts; step 6 `finalizeAndReset`/`setYieldStrategy` are empty-pool-only and revert once the pool is reset/rewired (`migrateOut`/`migrateIn` themselves ARE idempotent). There is **no clean re-entry point** — a re-run must be hand-edited to skip already-done steps, **under window time-pressure**, which raises the chance of a mistaken re-broadcast that compounds the L-01 strand.

**Why Low.** Pure state-handling / idempotency hazard with no direct fund-loss vector; the harm is recovery friction and an elevated chance of a re-broadcast mistake. It is worse here precisely because the operator is racing the `totalWithdrawal` window. Non-obvious footgun, in scope.

---

## Severity validation (second opinion)

All four classifications were **independently re-derived from C4 criteria and source-verified, and UPHELD unchanged** (severity-auditor, high overall confidence; zero adjustments). The key conclusions a reader must preserve:

- **The cluster ceiling is Medium, not High.** C4 High demands assets *stolen/lost/compromised* — permanent or attacker-realizable. Here there is **no theft path** (InPlaceMigrator invariant C, source-verified) and **no permanent loss**: every worst-case lock is total-but-temporary, attacker-free, and self-curing via the permissionless principal-returning `claimTimedOut` hatch. Totality, time-criticality, and terminal *pool* state are real aggravators that justify a confident headline Medium for M-02 — but terminality of the *migration* is not terminality of the *principal*. **Do not imply permanent loss.**
- **M-01 holds at Medium** despite the un-warpable catastrophic branch: the minimum-guaranteed harm is independently Medium-band and the missing assertion is source-unambiguous. The half-commit branch is honestly flagged as source-reasoned, not warped.
- **M-02 is the headline Medium** (fork-verified, default-path) and must carry its `14-day principal-only claimTimedOut recovery, no theft` nuance plainly.
- **L-01's demotion is correct anti-double-counting**, not a buried root cause — it is retained as a distinct Low carrying the generic structural fix.
- **All four survive Law 3** as non-obvious operator footguns; none collapses to an invalid trusted-owner/obvious-misconfig finding. KI[8] (external vault) and KI[9] (admin trust) are correctly NOT applied.

---

## Carryover from saga 2.1 that bears on 2.2

2.1 was just audited and fixed; the following are not re-reported here, but they are the upstream state 2.1 *leaves* that directly shapes 2.2's risk:

1. **The `DOLA_ALLOTMENT` / `USDC_ALLOTMENT` hardcoded-`0` tripwire is the upstream enabler of M-02.** 2.1 ships both allotments at `0` behind a `require(>0)` guard. That `require(>0)` proves the value is *set*, not *sufficient* — and it is the only guard the predecessor offers. Because the migrator's `migrateIn` top-up in 2.2 is funded *entirely* from that allotment, an allotment that clears the tripwire but is below the realized per-staker round-trip shortfall (~0.0149 DOLA / ~0.198 USDC at current pool sizes) bricks 2.2 after the terminal drain. The sufficiency decision lives in 2.1; the failure surfaces in 2.2.
2. **2.1's now-live M-03 set-aside buffer is 10%, not 25%.** 2.2's seed/buffer math (step 9 returns the skimmed DOLA/USDC surplus to the staker as the set-aside buffer) must assume the **10%** buffer that 2.1 actually established, not a 25% figure. 2.3's acceptance gate asserts `setAsideBufferSize==10`, confirming 10% is the live value the buffer math downstream of 2.2 must be reconciled against.

These are framed as "what 2.1 left that impacts 2.2," not as new 2.1 findings.

---

## Recommendations

Ordered by the structural fix they deliver. The first three each close a Medium; together they make the irreversible leg self-protecting.

1. **Add a `totalWithdrawal` window preflight assertion (closes M-01).** Before any irreversible step, read `oldYS.withdrawalStates(token, MINTER_V1)` and assert `status==Executable` AND `block.timestamp <= initiatedAt + TOTAL_DURATION` for **both** tokens in `_preflight` (before pause/drain), reverting with the exact `executableAt` / `expiresAt` so the operator aborts cheaply. Optionally assert `recovered > 0` immediately after each `_executeMinterWithdrawal` so a silent re-initiate fails loudly before the rewire rather than at `_postAssert`.

2. **Add an allotment-sufficiency preflight check (closes M-02).** Before any irreversible step, assert the migrator holds a surplus `>=` a conservative bound on the per-staker gross-up shortfall — measure the realized round-trip shortfall up front (e.g. `previewRedeem` / `convertToAssets` round-trip on the new strategy for each token's parked principal) so an under-sized allotment aborts *before* engaging terminal migration. At minimum, document in 2.1 the empirically-measured floor (~0.015 DOLA / ~0.2 USDC at current pool sizes, scaling with staker count and pool drift) so the allotment is sized with margin, not merely set to a token `>0` value that passes the tripwire.

3. **Front-load ALL go/no-go validation before the terminal point (closes L-01, and structurally subsumes 1 and 2).** Move every reversible operation and every go/no-go assertion (both-token window Executable, sufficient migrator allotment, owner authorizations) into `_preflight`, *before* step 1 pause and step 4 `initiateMigration`, so the only thing left after the irreversible point is deterministic bookkeeping. Document the break-glass recovery runbook (`UnpauseStakerBreakGlass` + re-run path) as the explicit fallback for any residual mid-broadcast strand.

4. **Add idempotent step guards / a resume map (closes L-02).** Guard each step with an idempotent precheck (`if (!paused) pause()`; `if (yieldStrategy(token)!=ysV2) {…}`; skip `initiateMigration` if already active) so a partial-failure re-run resumes cleanly, OR publish an explicit per-step resume map (in the project's `progress.<chainId>.json` style) so a partial failure has a known, window-safe re-entry procedure.
