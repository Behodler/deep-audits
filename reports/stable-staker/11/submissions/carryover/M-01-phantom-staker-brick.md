# [CARRYOVER] M-01 — Zero-credit `depositFor` strands a phantom staker, permanently bricking `finalizeAndReset`

> **Carryover stub, not new analysis.** Reported in run-10; **propose-fixed THIS run (story-011)**,
> **awaiting human `/ledger` confirmation**. Reproduced for visibility. Triage with `/ledger stable-staker`.

- **Fingerprint:** `8d5ceff2`  ·  **ID:** `ss10m1`  ·  **Label:** M-01
- **Title:** Zero-credit `depositFor` strands a phantom (`amount == 0`) staker in `_stakers`, permanently bricking `finalizeAndReset` (destination pool wedged in Migrating forever)
- **Severity:** Medium
- **Status:** acknowledged (will-fix)
- **Proposed status:** **fixed @ `c3ec65b`** — **propose-fixed this run (story-011)**, awaiting human confirmation
- **Location:** `src/StableStaker.sol` — `depositFor` (creation) + `_exitPosition` / `finalizeAndReset` (detonation)
- **Original report:** [reports/stable-staker/10/submissions/M-01-phantom-staker-brick.md](../../../10/submissions/M-01-phantom-staker-brick.md)

## Why still open

A dust `depositFor` through a haircutting strategy booked `credited == 0` yet still fired `_stakers.add`,
inserting a zero-position phantom staker. story-009's `finalizeAndReset` asserts
`require(_stakers[token].length() == 0)` — a phantom can never be ejected, so `finalizeAndReset` reverted
on every call and the destination pool was permanently wedged in `PoolState.Migrating`.

**This run resolves it.** `[story-011]` (`c3ec65b`) added the missing `require(credited > 0)` guard at
`StableStaker.sol:632`, closing the zero-credit `depositFor` phantom-creation path; both `_stakers.add`
sites are now guarded. Recheck = **LIKELY-FIXED**; three independent agents confirm the fix is faithful,
complete, and safe. The original PoC (`test/PoC_DEDUP001_PhantomStakerBrick.t.sol`) now reverts at setup;
the proof-of-fix (`test/PoC_story011_DepositForZeroCreditReverts.t.sol`) passes. The authoritative status
is human-acknowledged (will-fix), so the fix is **proposed, not auto-flipped** — it stays a visible
carryover until a human confirms.

## Resolve

```
/ledger stable-staker fixed 8d5ceff2 --commit c3ec65b
```
