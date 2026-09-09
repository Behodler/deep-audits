# [CARRYOVER] ss12l1 (run-12 L-01) — Poison/zero-credit user reverts the whole migrateIn slice (non-atomic per-user deposit loop)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/InPlaceMigrator.sol#L207-L224` (`migrateIn`)
- **First seen:** stable-staker-12  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013's single-file InPlaceMigrator top-up diff does not add per-user try/catch to the migrateIn loop; a zero-credit user still reverts the whole slice (principal recoverable via claimTimedOut).
- **Original report:** [reports/stable-staker/12/submissions/qa-report.md](../../../12/submissions/qa-report.md)
- **Fingerprint:** `bda951d9…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
