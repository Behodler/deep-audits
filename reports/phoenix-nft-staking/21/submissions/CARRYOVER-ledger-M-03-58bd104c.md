<!--
ID: 58bd104c (ledger fingerprint — this record mints NO new finding ID and NO run-21 M-nn label)
C4 Submission Metadata — STILL-OPEN LEDGER CARRYOVER (Medium), re-derived with executed evidence this run
Title: `depositFor`'s unconditional tail `_recomputeSchedule()` restarts the whole depletion window on every migration slice — Linear-Depletion rate-drift class
Record kind: CARRYOVER. NOT a new finding. NOT a regression. NOT labelled M-nn in this run's sequence.
Project: phoenix-nft-staking
Run: phoenix-nft-staking-21 @ c881a428c87ef4ef42ba07a71be5d49101c9006d
Ledger fingerprint: 58bd104c0069526d3f518c6365d4c8f1aaf2b4e167164b651ffc6219d34232ab
Ledger label: M-03   ·   Ledger status: open   ·   Severity at HEAD: medium — UNCHANGED
Classified as: CLASS-21-018 (originalId DEDUP-21-008)
Contract at HEAD: src/NFTStakerDepletion.sol (depositFor)
Evidence: poc-replay.md §4.6 (`test/PoC_DepletionRateDrift.t.sol` 3/3 PASS @ c881a42)
-->

**Severity: Medium — unchanged.** **Ledger label `M-03`. No new run-21 label is minted.**

> **⚠ Why this record exists.** This is an **open ledger Medium** re-derived this run with executed
> evidence, which previously appeared in `submissions/` only as a passing cross-reference.

> **⚠ Label-collision guard.** This is **ledger `M-03` = `58bd104c…`**. It is **not** run-21's `M-03`
> `b3243f42…` (`NFTStakerDepletion.sol:756` `_safePay(pending)` in the deployment template), and it is
> **not** ledger `M-04` `a0967cce…` (`InPlaceNFTStakerMigrator.migrateIn`). ⚠ A label correction was
> carried from dedup this run precisely because those two were previously transposed — **disambiguate by
> fingerprint, never by label** (run-20 R-3).

## Finding description and impact

### The defect (unchanged at HEAD)

1. `depositFor` ends with an **unconditional** `_recomputeSchedule()`.
2. The justifying comment claims parity with `stake` — **factually wrong**: `stake` in this variant does
   **not** tail-recompute.
3. Every migration slice therefore **restarts the whole depletion window**.
4. **Slice ordering, which the operator controls, becomes an inter-user value transfer.**

### Impact

Earlier migration slices split the pool-wide stream alone while later slices sit parked. Magnitude
measured on the ancestor of this line in prior runs: **1000 bps** on the price-scaled copy (run-18) and
**63.26 %** on the depletion copy (run-20 unstake-path ancestor). ⚠ Those are prior-run lab magnitudes
for the ancestor line, **not** a predicted mainnet loss for this entry.

### Evidence this run

`test/PoC_DepletionRateDrift.t.sol` — **3/3 PASS at `c881a42`** (poc-replay.md §4.6). Note this PoC is
now **tracked upstream**, adopted into the project's own suite from a prior audit run and counted inside
the 412-test green baseline. It re-executed clean after the story-023 constructor-argument repair, with
**no change in verdict**.

### Why it remains Medium

Inter-user value transfer with stated assumptions (a staggered, multi-slice migration) and stated
external requirements (operator-chosen slice ordering). **No external attacker is involved at any point.**
The remedy (`setTargetAPY(0)` for the duration of the migration window) is available but **must be
remembered** — which is what keeps this a live operational hazard rather than a closed one. Severity is
**unchanged from the ledger**, not re-rated.

## Recommended mitigation steps

### 1. Code

Make the tail `_recomputeSchedule()` conditional, or otherwise stop a migration slice from restarting the
depletion window, so slice ordering carries no value consequence. Correct the parity comment either way —
it is currently false about `stake`.

### 2. Operational, until then

`setTargetAPY(0)` for the duration of any staggered migration window, and record it as a required step in
the migration runbook rather than as tribal knowledge.

### 3. ⚠ UNPAID clone-drift watch — settle next run

`src/NFTStakerPriceScaledMigrateReady.sol` was **NOT re-read this run** for the tail-recompute line. The
clone-drift watch is **unpaid on that file** and must be settled next run. This is a recorded coverage
gap, not a clean result.

### 4. Ledger hygiene

- Matches the **open** entry `58bd104c…` (*"POSSIBLE INCOMPLETE FIX of ledger `M-01` `b58b172e…`"*).
  **Not filed as a regression:** run-20 already created the incomplete-fix representation as its own open
  entry, and filing a second would double-count one defect. `b58b172e…`'s `fixed` status and its
  **DO-NOT-AUTO-CLOSE** flag are preserved untouched.
- **DO NOT COLLAPSE** with ledger `M-08` `6d2d6284…` (`userMigrate` self-advance): different actor,
  different mechanism, **1000 vs 1666 bps**. The run-20 merge proposal was **rejected as R-1 and that
  rejection stands.**
- This entry also carries ledger `M-04` `a0967cce…`, `L-01` `ced20f2e…` and `L-02` `51e8255b…` forward.
