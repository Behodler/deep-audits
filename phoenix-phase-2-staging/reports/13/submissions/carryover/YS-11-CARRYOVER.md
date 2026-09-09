# [CARRYOVER] YS-11 (6b3c3b98) — Story-060 leaves migrator2 set on the live original staker after declaring migration COMPLETE

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-cleanup`
- **Location:** `lib/phoenix-phase-2-staging/script/PostMigrationCleanup.s.sol#L248-L296` (`run`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** story-061/062/063 cleanup changes add unpause/setPauser restoration but NO `setMigrator(0)` revocation step. Standing terminal-migration footgun on a now-active pool; root cause untouched.
- **Original report:** [reports/phoenix-phase-2-staging/12/findings/low/YS-11-standing-migrator-after-complete.json](../../../12/findings/low/YS-11-standing-migrator-after-complete.json)
- **Fingerprint:** `6b3c3b98`

See the original report for the full description, impact, attack path, and recommendation.
