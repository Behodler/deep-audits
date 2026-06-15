# [CARRYOVER] INFO (`796f775f`) — `initiateMigration` writes state after the external `strategy.withdraw` call (CEI ordering)

> **Carryover stub, not new analysis.** Reported in a prior run, still **open** at HEAD `ffa4947`.
> This run ([story-012] InPlaceMigrator, new contract) did **not** touch `initiateMigration` on
> StableStaker. Reproduced so it is not lost between runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `796f775f`
- **Severity:** Informational (QA) · **Status:** open (guard- and trust-mitigated; no exploit demonstrated)
- **Location:** `src/StableStaker.sol` — `initiateMigration` (L387-408)
- **First seen:** stable-staker-07 · **Still present as of:** stable-staker-12
- **Original report:** [reports/stable-staker-07/submissions/qa-report.md](../../../stable-staker-07/submissions/qa-report.md)

See the original report for full description.
