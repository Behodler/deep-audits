# [CARRYOVER] L (`59eebbf8`) — Unbounded per-user external-call loop in `batchMigrate` + `StableStakerMigrator.migrate`

> **Carryover stub, not new analysis.** Reported in a prior run, still **open** at HEAD `ffa4947`.
> This run ([story-012] InPlaceMigrator, new contract) did **not** touch `batchMigrate`. Reproduced so
> it is not lost between runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `59eebbf8`
- **Severity:** Low · **Status:** open
- **Location:** `src/StableStaker.sol` — `batchMigrate` (L440-445); also `src/StableStakerMigrator.sol:migrate` (L76-80)
- **First seen:** stable-staker-01 · **Still present as of:** stable-staker-12
- **Original report:** [reports/stable-staker-01/submissions/qa-report.md](../../../stable-staker-01/submissions/qa-report.md)

**Cross-ref (run-12):** This is the *unbounded-gas* DoS (too many users per call). It is DISTINCT
from this run's new `ss12l1` (`bda951d9`), the *atomicity* DoS where one zero-credit user reverts the
whole `InPlaceMigrator.migrateIn` slice — different contract:function and root cause. Kept separate.

See the original report for full description, impact, and recommendation.
