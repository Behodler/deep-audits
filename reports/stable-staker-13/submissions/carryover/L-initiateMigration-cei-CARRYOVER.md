# [CARRYOVER] L-initiateMigration-cei — initiateMigration writes state after the external strategy.withdraw call (reentrancy ordering; Aderyn HIGH / Slither Medium) — guard- and trust-mitigated

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Informational
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L387-L408` (`initiateMigration`)
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not touch StableStaker.initiateMigration; the CEI-ordering informational hygiene note (guard-/trust-mitigated) is unchanged.
- **Original report:** [reports/stable-staker-07/submissions/qa-report.md](../../../stable-staker-07/submissions/qa-report.md)
- **Fingerprint:** `796f775f…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
