# [CARRYOVER] L-unbounded-loop — Unbounded per-user external-call loop in batchMigrate + StableStakerMigrator.migrate (relocated from removed migrateOut/migrate)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L440-L445` (`batchMigrate`)
- **First seen:** stable-staker-01  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not touch StableStaker.batchMigrate / StableStakerMigrator.migrate; the unbounded per-user external-call loop is unchanged.
- **Original report:** [reports/stable-staker/01/submissions/qa-report.md](../../../01/submissions/qa-report.md)
- **Fingerprint:** `59eebbf8…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
