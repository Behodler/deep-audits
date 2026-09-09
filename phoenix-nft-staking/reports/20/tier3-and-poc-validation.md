# Tier-3 & PoC Validation — phoenix-nft-staking run-20

**Project:** phoenix-nft-staking
**Submodule HEAD:** `0d1a0b2` ([story-022] Stage 6)
**Baseline:** `321d0a9` (run-19, story-020)
**Executed from:** `workspace/phoenix-nft-staking` (writable clone; `lib/` never touched)
**Validation mode:** MODE 1 — workspace PoCs importing the project's **real** contracts (`../src/...`).
Project imports are required and correct here; the forge-std-only standalone check does **not** apply.
**Date executed:** 2026-07-20

`forge build` at HEAD: **clean** (lint notes only, no errors).
This document records **execution results only**. No new findings were authored.

---

## Summary table

| # | Test file | Result | Tests | What it establishes | Proves the claim? |
|---|-----------|--------|-------|---------------------|-------------------|
| 1 | `PoC_BatchMinterCallbackAndAllowance.t.sol` | **PASS** | 2/2 | Live max-allowance + mid-loop ERC1155 receive hook behaviour | Yes — D-21 witnesses |
| 2 | `PoC_BatchMinterConfigDriftAndStaticcall.t.sol` | **PASS** | 3/3 | tuple-append tolerated, tuple-reorder fails **closed**, `balanceOf` snapshot is STATICCALL | Yes — these are **refutations**, D-21 |
| 3 | `PoC_Drift01_DepositForPaysMigrator.t.sol` | **PASS** | 4/4 | `_safePay` fork-drift: 82,191.78 phUSD paid to the **migrator**, not the user; permanently stranded on `NFTStakerMigrator` | Yes — D-14 realised defect |
| 4 | `PoC_DuplicateRewardWithDonations.t.sol` | **PASS** | 3/3 | duplicate-token list does **not** fail closed when the dispatcher donates; payment-token sweep by a non-qualifying caller | Yes — F-20-01 + ECON-001 |
| 5 | `PoC_EconMigrateReady.t.sol` | **PASS** | 10/10 | D-24 numbers reproduced exactly: **1000 bps**, **120%**, **1666 bps** | Yes (see per-test notes) |
| 6 | `PoC_EconRatchetSweepAndDuplicates.t.sol` | **PASS** | 6/6 | `count == 1` caller sweeps the whole ratchet pot; qualifying batcher **cannot** list the pot asset; ratchet mint is free | Yes — ECON-001 mainnet shape |
| 7 | `PoC_Local001_StakeGriefBlocksReset.t.sol` | **PASS** | 2/2 | permissionless stake blocks `finalizeAndReset`; pause remedy is complete | Yes (bounded — remedy exists) |
| 8 | `PoC_Local002_005_MigrationFootguns.t.sol` | **PASS** | 3/3 | broken hook wedges `finalizeAndReset` (recoverable); `setMigrator` mid-migration orphans parked stake | Yes — footguns, all recoverable |
| 9 | `PoC_DepletionRateDrift.t.sol` (prior run) | **PASS** | 3/3 | run-18 M-01 replay → **LIKELY-FIXED** on the `stake`/`claim` accrual path (active == passive to the wei); migration path NOT covered | Fix holds; see caveat |
| 10 | `InvariantBatchNudge.t.sol` | **4 FAIL / 3 PASS** | 7 | 4 invariants **BROKEN** — the failures are the finding | Yes — **non-vacuous**, census proven |
| 11 | `InvariantForkParity.t.sol` | **PASS** | 3/3 | copy #2 ↔ copy #4 observational parity holds | Non-vacuous, but **scope-limited** — see caveat |
| 12 | `InvariantMigrateReady.t.sol` | **PASS** | 7/7 | conservation / solvency / frozen-snapshot / finalize-reachability all hold | Non-vacuous, 128k calls/invariant |
| 13 | `MedusaNudge.sol` (Medusa harness) | **RUN — 1 FAILURE** | 26 pass / 1 fail | Independently reproduces **INV-SWEEP** in a **single call** | Yes — corroborates #10 |
| 14 | `poc-H-01.t.sol.bak` | **INCONCLUSIVE** | — | Compile bit-rot | No — never read as a fix |
| 15 | `poc-M-01.t.sol.bak` | **INCONCLUSIVE** | — | Compile bit-rot | No |
| 16 | `poc-MevFrontrunNudge.t.sol.bak` | **INCONCLUSIVE** | — | Compile bit-rot | No |
| 17 | `poc-NudgeDrain.t.sol.bak` | **INCONCLUSIVE** | — | Compile bit-rot | No |

Out of this task's brief (listed for completeness, **not executed here**): `SymbolicAccrual.t.sol`,
`SymbolicAccrualBounded.t.sol`, `SymbolicNudgePayout.t.sol`, `SymbolicScheduleMath.t.sol` (Halmos targets),
and the project's own 333-test suite (verified green at `0d1a0b2` during the D-06 sync).

---

## Per-test notes

### 1. `PoC_BatchMinterCallbackAndAllowance.t.sol` — PASS (2/2)
- `test_MaxAllowance_UnderfundedBatchEatsContractsOwnPaymentBalance` (gas 1,572,771)
- `test_ReceiveHookRunsMidLoop_WithLiveMaxAllowance` (gas 3,233,490)

Both pass against real `BatchNFTMinter`. These are the **witnesses behind D-21**: the mid-loop ERC1155
receive hook is genuinely attacker-reachable, and the live max allowance means an under-funded batch
consumes the contract's own payment-token balance. Note the D-21 nuance stands: the *guard holds* — the
finding attached to the hook is a **test-coverage gap** (project `MockERC1155.mint()` skips
`_checkOnERC1155Received`), not a reentrancy vulnerability.

### 2. `PoC_BatchMinterConfigDriftAndStaticcall.t.sol` — PASS (3/3)
- `test_ConfigsTupleAppend_IsTolerated`
- `test_ConfigsTupleReorder_FailsClosed`
- `test_SnapshotBalanceOfIsStaticcall` (gas 1,040,622,023 — the storage-writing `balanceOf` bricks the batch,
  which is the proof)

**These tests prove negatives.** They are the executable backing for the D-21 refutations: `configs` tuple
drift is **not** the phStaging YS-20 severity class (reorder fails closed), and the hostile-token surface at
the snapshot site is a STATICCALL and therefore cannot mutate state. Recording them as PASS means the
*refutations* are proven, not that a vulnerability is proven.

### 3. `PoC_Drift01_DepositForPaysMigrator.t.sol` — PASS (4/4) — **D-14 realised**
Measured numbers:

| test | pending owed | user received | routed to migrator | recoverable? |
|------|-------------|---------------|--------------------|--------------|
| `testA_DepositForPaysMigratorNotUser` | 82,191.780821…e18 | **0** | 82,191.780821…e18 | — |
| `testC_InPlaceMigrateInCapturesReward` | 8,219.178…e18 | **0** | 8,219.178…e18 | **yes** (`rescueERC20`) |
| `testD_CrossStakerMigrateStrandsRewardPermanently` | 82,191.78…e18 | net 82,191.78…e18 | 82,191.78…e18 | **NO — no rescue fn** |
| `testB_BatchMigratePaysUserCorrectly` | — | correct | — | control (path is clean) |

This is the strongest PoC in the run. It reproduces the `_safePay` → `_safePayTo` fork drift that story-021
fixed **only in the new copy**, and it demonstrates the asymmetric-recovery fact that drives severity:
`InPlaceNFTStakerMigrator` has `rescueERC20`; `NFTStakerMigrator` has **no rescue function**, so
`testD`'s phUSD is permanently stranded. `testB` is a genuine control — the `batchMigrate` path pays the
user correctly, so the defect is path-specific rather than a blanket claim.

### 4. `PoC_DuplicateRewardWithDonations.t.sol` — PASS (3/3)
- `test_DuplicateDoesNotFailClosedWhenDispatcherDonates` — the F-20-01 core: duplicate entries in the reward
  list are only safe if nobody donates; the pinned dispatcher donates on every mint, so they aren't.
- `test_ManyDuplicatesDrainOwnDonationsEntirely`
- `test_AnyoneSweepsPaymentTokenBalanceWithoutQualifying` (separate contract `PoC_PaymentTokenSweep`) — ECON-001.

Note the two are proven **separately**, which matters for the D-16 fix trap: the correct remedy is
`min(snapshot[i], balanceOf(this))` or dedupe, **not** a `balanceOf` re-read at payout.

### 5. `PoC_EconMigrateReady.t.sol` — PASS (10/10) — **D-24 numbers confirmed**
Every headline figure in D-24 reproduces exactly:

| test | measurement | D-24 claim | match |
|------|-------------|-----------|-------|
| `test_ECON_A_migrateInOrderingIsAValueTransfer` | alice 40.6849e18 vs bob 36.9863e18, delta 3.6986e18 = **1000 bps** | 1000 bps (price-scaled) | ✅ |
| `test_ECON_G_depletionMigrateInOrderingOverPaysSliceOne` | alice 48,977.29e18 vs bob 40,758.11e18 → **120%** | 120% (48.98 vs 40.76 scaled) | ✅ |
| `test_ECON_H_selfAdvanceBeatsOperatorBatchOrder` | alice 43.1506e18 vs bob 36.9863e18 → **1666 bps** | 1666 bps | ✅ |

Supporting tests, all PASS:
- `ECON_B` — timeout-hatch restake **livelocks** `finalizeAndReset`.
- `ECON_C` / `ECON_C2` — gas ceiling: 70,312 gas/user (`MigrateReady`), 55,565 gas/user (`Depletion`);
  **426 users per 30M block**. A concrete, non-hypothetical operational bound.
- `ECON_D` — `finalizeAndReset` **conserves budget**: rate 14,269,406,392,694 → 0, `windowEnd == now`,
  `committedDebt == 0`, balance == rewardBudget. A clean-behaviour confirmation.
- `ECON_E` — `finalizeAndReset` counts unpulled mint debt (balance 1e24, rewardBudget 1.5e24).
- `ECON_F` — `emergencyWithdraw` during `Migrating` causes **no** over-emission on this copy (a refutation —
  note this does **not** discharge the ledger M-02 disclosure obligation in D-15, which is about
  migrate-on-behalf, a different premise).
- `ECON_I` — mid-batch intermediate price **cannot** over-earn: the attack pins the rate *lower*
  (28,538,812,785,388 vs control 34,477,993,436,073) and the next recompute restores it; attacker earns
  36.99e18 vs control 44.68e18. Another proven refutation — the attacker loses money.

**Reading:** ECON_A/G/H prove a real value transfer between users. ECON_D/F/I prove that three adjacent
suspicions are false. That mix is what makes this suite credible rather than one-sided.

### 6. `PoC_EconRatchetSweepAndDuplicates.t.sol` — PASS (6/6)
`PoC_RatchetPrimeTokenSweep` (3/3):
- `test_CountOneCallerSweepsEntireRatchetPot` — the ECON-001 mechanic, at `count == 1`.
- `test_QualifyingBatcherCannotListThePotAsset` — **the crux of D-18**: the §4.1 guard blocks the *legitimate*
  claimer while leaving the sweep open. Proven, not asserted.
- `test_RatchetBatchMintIsFree` — the mint costs the attacker nothing.

`PoC_DuplicateMagnitudeMainnetShape` (3/3), at the observed mainnet shape:
- `test_LargeBatchRecapturesItsOwnDonation` — donation 776.40 USDC, **704.53 recaptured** by the batcher,
  only 71.87 left to seed the next claimant (≈90.7% self-recapture).
- `test_BackToBackSteadyState_DonateForwardNullified` — prior pot 77.64 USDC, paid out 155.28, **0 left behind**.
- `test_AtObservedShape_DuplicateStillFailsClosed` — at the *observed* mainnet shape the duplicate path does
  fail closed. This is the honest bound on F-20-01's magnitude and should not be dropped from the writeup.

### 7. `PoC_Local001_StakeGriefBlocksReset.t.sol` — PASS (2/2)
`testGrieferBlocksFinalizeAndReset` proves the grief; `testPauseRemedyIsComplete` proves the operator remedy
is **complete**, not partial. Both facts belong in the finding — the second is what caps severity.

### 8. `PoC_Local002_005_MigrationFootguns.t.sol` — PASS (3/3)
- `testBrokenHookWedgesFinalizeAndResetButIsRecoverable` — wedge is real, recovery exists.
- `testEmergencyWithdrawSurvivesBrokenHook` — the ejector seat works (principal never trapped).
- `testSetMigratorMidMigrationOrphansParkedStake` — the sharpest of the three: an owner action with a
  non-obvious consequence (Law-3 footgun, in scope).

### 9. `PoC_DepletionRateDrift.t.sol` — PASS (3/3) — **classified LIKELY-FIXED**
Prior-run PoC, replayed at `0d1a0b2` per `/recheck` semantics. It **compiles and runs**, and its
exploit assertion no longer reproduces:

```
passive total received : 1,199,999,999,999,999,974,608,000 wei
active  total received : 1,199,999,999,999,999,974,608,000 wei   <- identical
stranded in contract   : 25,392,000 wei (dust)
initial rewardRate == final rewardRate : 38,051,750,380,517,503
original windowEnd == final windowEnd  : 63,072,001
```

Active and passive stakers receive **byte-identical** totals; rate and window are unmoved. Plus
`test_M01_restartOnMint_preserved` and `test_M01_zeroInflowPullAndRefresh_isNoop` confirm the fix did not
break adjacent behaviour.

**Classification: LIKELY-FIXED** (not "fixed" — only a human applies that via `/ledger`).

> ⚠ **Caveat that must travel with this result (D-24).** This PoC covers the `stake`/`claim` accrual
> path; it imports only `NFTStakerDepletion` and never calls `migrateIn`/`depositFor`, so it does not
> exercise the migration path at all. The
> *same class* reproduces at 120% via the **`migrateIn` slice-ordering** path in `test_ECON_G` above.
> A green result here is **not** evidence the linear-depletion class is closed, and must not be used to
> argue against the possible-incomplete-fix framing in D-24. The two paths are independent.

### 10. `InvariantBatchNudge.t.sol` — 4 FAIL / 3 PASS — **the failures ARE the finding**

Broken invariants (each shrunk to a **1-call** counterexample):

| Invariant | Failure message |
|-----------|-----------------|
| `invariant_nudgeSolvency` | `paid=6000000 prePot=3000000 count=8 listLen=3` — paid **2×** the snapshot pot |
| `invariant_nudgeNoSelfFund` | `excess=21000000` — caller paid out of their own donation |
| `invariant_sweep` | `caller net gain=11263884099603271484375` — sweep returns more than unspent surplus |
| `invariant_fotFloor` | `delivered=95e18 declared floor=100e18` — FoT delivers below the declared `minReward` floor |

Passing companions, which are the ones that make the failures usable:
- `test_minimalCounterexample_nudgeSolvency` — prePot 3,000,000; delivered **6,000,000**; own donations 18,000,000.
- `test_minimalCounterexample_selfFund` — prePot 3,000,000; caller received 15,000,000; **self-funded excess 12,000,000**.

**VACUITY CHECK: NOT VACUOUS — and this is established by evidence, not by assumption.**
`test_coverageCensus` (PASS, gas 56,330,808) reports:

```
batchMint-ok            : 234      batchMint-reverted : 62
qualified               : 69       duplicateList      : 112
REWARD-ACTUALLY-MOVED   : 61       sweepObserved      : 26
fotListedWithFloor      : 11
```

234 successful `batchMint` calls, 69 of which **qualified** for a nudge, and **61 in which a reward token
actually moved**. The guarded state was genuinely reached: the invariants are not passing/failing on
untouched state. Do not be misled by `(runs: 0, calls: 0)` in the failing invariants' headers — that is
Foundry reporting a first-run failure; the per-selector tables (up to 161 `batchMint` + 153 `donate` calls
before shrinking) show the real work.

Note also the FoT result: `fotListedWithFloor: 11` means the FoT path was exercised 11 times and the floor
breach is real. Per **D-19** this stays **QA** — the executed result does not change that disposition,
because the value flow (caller chooses both token and recipient) still supports no cross-user extraction.

### 11. `InvariantForkParity.t.sol` — PASS (3/3) — non-vacuous but **scope-limited**
- `invariant_forkParity` — 256 runs, **128,000 calls, 0 reverts**
- `invariant_bothSolvent` — 256 runs, **128,000 calls, 0 reverts**

**VACUITY CHECK: NOT VACUOUS.** Census: `nonZeroAcc: 533`, `nonZeroStake: 409`,
`REWARD-ACTUALLY-PAID: 39`, plus stake 66 / unstake 24 / claim 110 / emergencyWithdraw 30 /
setTargetAPY 67 / setPrice 58 / topUp 58 / hookAccrue 66. Rewards genuinely moved; state was genuinely
non-trivial. Zero reverts across 128k calls in a handler this broad is worth a second look, but the census
counters confirm the calls landed rather than being silently discarded.

> ⚠ **Scope caveat — state plainly.** This harness compares **copy #2 (`NFTStakerPriceScaled`) against
> copy #4 (`NFTStakerPriceScaledMigrateReady`) only** (imports at lines 5–6). It does **not** include
> `NFTStakerDepletion`, and its handler exposes no migration surface (`claim`, `emergencyWithdraw`,
> `hookAccrue`, `setPrice`, `setTargetAPY`, `settleAll`, `stake`, `topUp`, `unstake`, `warp`). Therefore
> **it does not test the D-14 `_safePay`/`_safePayTo` drift at all** — that drift is between the new copy
> and `NFTStakerDepletion`, on the `depositFor`/`migrateIn` path. A green `invariant_forkParity` is
> **not** evidence that fork drift is absent; the drift is proven live by test #3 above. The D-05 4-way
> watch is only partially discharged by this harness.

### 12. `InvariantMigrateReady.t.sol` — PASS (7/7) — non-vacuous
All five invariants at 256 runs × 128,000 calls (41–51 reverts each, all on `batchMigrate`, i.e. the
fail-closed behaviour D-25 says to preserve):
`invariant_conservation`, `invariant_finalizeReachable`, `invariant_frozenSnapshot`,
`invariant_solvencyStrongOnlyWithoutMintDebt`, `invariant_solvencyWeak`.
Plus `test_finalizeReachability_griefedByPermissionlessStake` (PASS) and `test_coverageCensus` (PASS).

**VACUITY CHECK: NOT VACUOUS.** Census:

```
stake 59 | unstake 19 | claim 65 | warp 61 | emergencyWithdraw 14
initiateMigration 18 | batchMigrate 49 | userMigrate 10 | depositFor 22
finalizeAndReset 17 | rescueERC20 55 | topUp 66 | hookAccrue 64
STEPS-IN-MIGRATING 443 | stakeDuringMigrating 44
REWARD-ACTUALLY-PAID 15 | migrationExitsThatPaid 3 | totalPaidOut 452.37e18
```

**443 steps taken while in the `Migrating` state** and **452.37 phUSD actually paid out** — the migration
state machine was genuinely entered and exercised, and value genuinely moved. This is exactly the check the
project's "vacuous invariant harness" failure mode calls for, and it passes: this is **not** a `0 == 0` green.

The per-selector reverts are concentrated on `batchMigrate` (41–51 out of ~8,500 calls) — consistent with
D-25's position that the loop reverting is correct fail-closed behaviour, and that Aderyn's
"forgive on fail" suggestion should stay rejected.

### 13. `MedusaNudge.sol` — **RUN** (not skipped) — 26 pass / 1 fail
Medusa **is** available (`/home/justin/.local/bin/medusa`, v1.5.1) and `medusa.json` targets `MedusaNudge`.
Ran bounded: `medusa fuzz --test-limit 30000` (~40k calls, 1,969 branches, corpus 38, health 66%).

**Result: 26 tests passed, 1 failed.**
The failure is `Assertion Test: MedusaNudge.opBatchMint(uint8,uint64,uint8,bool)`, shrunk by three
independent workers to a **single call**. Trace evidence identifies it as `assert(!sweepBroken)`
(`MedusaNudge.sol:163`): the harness paid `cost` = 1,000e18, the recipient (`0xbEEF`) received **0** of every
reward token (so not the solvency branch), and the final step transferred the batcher's **entire**
20,000e18 payment-token balance back to the caller.

**This is an independent, differently-engined reproduction of INV-SWEEP / ECON-001** — Medusa found it in one
call from a cold corpus. Corroborates finding #10 and #6.

> **Methodological note worth carrying forward.** The four `property_*` functions
> (`property_nudgeSolvency`, `property_noSelfFund`, `property_sweep`, `property_notVacuous`) all report
> *passed*. That is an artefact, not a clean result: the `assert()` mirror at `MedusaNudge.sol:161-163`
> panics inside `opBatchMint`, which **reverts the very state writes** (`sweepBroken = true`) that the
> `property_*` views read. In assertion-testing mode the property mirrors are structurally unable to fire.
> **Do not report "property_sweep passed" as evidence of anything.** The assertion test is the live detector
> here; the vacuity tripwire `property_notVacuous` is unaffected (its counters increment on non-reverting
> calls) but is also therefore not independently confirming much.

### 14–17. The four parked `.bak` PoCs — **ALL INCONCLUSIVE**
Revived into `test/` and compiled; workspace restored to `.bak` afterwards (no residue left).

Two layers of bit-rot were found:

1. **Path rot (fixable, and I fixed it to reach the real question):** all four import
   `yield-claim-nft/V2/interfaces/…`, which no longer exists — the sibling's story-039 **flatten refactor**
   moved these to `yield-claim-nft/interfaces/…`. Rewriting the prefix resolves it.
2. **API rot (not fixable without authoring):** with paths corrected, **all four** fail identically:

```
Error (9582): Member "setNudgePaymentToken" not found or not visible
              after argument-dependent lookup in contract BatchNFTMinter.
  poc-H-01.t.sol:71 | poc-M-01.t.sol:233 | poc-MevFrontrunNudge.t.sol:212 | poc-NudgeDrain.t.sol:100
```

story-022 removed `nudgePaymentToken` / `setNudgePaymentToken` entirely — exactly as D-06 predicted and as
D-04 noted the two stale `designDecisions` entries assume.

**Per `/recheck` semantics and the explicit D-06 instruction: a PoC that no longer compiles is
INCONCLUSIVE — never evidence of a fix.** The H-01 / M-01 / MEV-front-run / nudge-drain lineage is
**unverified at `0d1a0b2`**, in either direction. Combined with **D-20** (both suppression premises behind
that lineage have measurably degraded) this is a live gap, not a closed one: the accepted suppressions
currently rest on reasoning whose executable witness no longer runs. Re-authoring these four against the
story-022 API is owed work — flagged, not performed here (out of this task's execute-and-record brief).

---

## Housekeeping

- Workspace left exactly as found: the four `.bak` files are intact and unmodified; the temporary revived
  `.t.sol` copies were deleted. No file under `lib/` was read-write opened or modified.
- Medusa wrote `workspace/phoenix-nft-staking/medusa-corpus/` (corpus + coverage report). Gitignored
  workspace, safe to delete.
- Full medusa campaign log retained at the session scratchpad (`medusa.log`) for the duration of the session.
