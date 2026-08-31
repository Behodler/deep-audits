# [CARRYOVER] M-01 (ss-01) — Underwater-pool migration bricked by requested-vs-received accounting mismatch

> **Carryover stub, not new analysis.** Reported in run-01; status is acknowledged with a
> **propose-fixed @ `f5f6039`** (single-realization migration redesign) **awaiting human `/ledger`
> confirmation**. This run (`125f585..c3ec65b`, story-011 `depositFor` guard) did **not** touch the
> migration path and did **not** re-verify this proposal. Reproduced for visibility. Triage with
> `/ledger stable-staker`.

- **Fingerprint:** `3d61c955`
- **Title:** Underwater-pool migration is bricked by requested-vs-received accounting mismatch
- **Severity:** Medium
- **Status:** acknowledged ("I accept this and will work on a fix")
- **Proposed status:** **fixed @ `f5f6039`** (root cause `migrateOut` deleted; single-realization migration redesign), awaiting human confirmation
- **Location:** `src/StableStaker.sol` — `migrateOut` (L301-337, removed at HEAD)
- **Original report:** [reports/stable-staker/01/submissions/M-01-underwater-migration-bricked.md](../../../01/submissions/M-01-underwater-migration-bricked.md)

## Why still open

The old `migrateOut` requested-vs-received accounting mismatch bricked underwater-pool migration. The
finding has been **confirmed-absent / likely-fixed** since run-02: `migrateOut` was deleted and the new
single-realization migration design structurally avoids the mismatch, and the fingerprint has not
reappeared (no regression) on any subsequent scan. The owner accepted with a stated will-fix intent.
Because the authoritative status is human-acknowledged, the fix is **proposed, not auto-flipped**; it
remains a visible carryover until a human confirms. This run's scoped story-011 change is unrelated and
did not re-verify it.

## Resolve

```
/ledger stable-staker fixed 3d61c955 --commit f5f6039
```
