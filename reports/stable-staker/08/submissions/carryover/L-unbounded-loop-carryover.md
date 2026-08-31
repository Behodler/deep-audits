# [CARRYOVER] Unbounded per-user external-call loop in batchMigrate + StableStakerMigrator.migrate

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L440-L445` (`batchMigrate`); also `src/StableStakerMigrator.sol:migrate` L76-80 (relocated from the removed `migrateOut`/`migrate` at stable-staker-07)
- **First seen:** stable-staker-01  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker/01/submissions/qa-report.md](../../../01/submissions/qa-report.md)
- **Fingerprint:** `59eebbf8`

This run (stable-staker-08, regression) did not touch this path; the finding is unchanged. Entry
identity and history (including the run-07 relocation) are preserved in the ledger. See the original
QA report for the full description, impact, and recommendation.
