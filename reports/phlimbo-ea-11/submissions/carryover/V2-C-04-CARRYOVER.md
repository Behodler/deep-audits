# [CARRYOVER] V2-C-04 — Residual migrator custody: migrator role not auto-revoked post-migration and can call withdraw/claim on behalf of any user, routing principal+rewards to itself

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Centralization
- **Status:** open (still-open)
- **Location:** `src/PhlimboV2.sol#L232-L432` (`setMigrator/withdraw/claim`)
- **First seen:** phlimbo-ea-06  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea-06/audit/submissions/qa-report.md](../../../phlimbo-ea-06/audit/submissions/qa-report.md)
  - _Pointer resolved at run-11 by verified label match; no `reportPath` was recorded on this entry._
- **Fingerprint:** `539b66c0…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
