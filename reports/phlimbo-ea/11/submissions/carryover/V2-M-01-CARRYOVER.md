# [CARRYOVER] V2-M-01 — MigratorV1V2 strict-equality balance precondition lets any third party brick the chunkable migration with 1 wei

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/MigratorV1V2.sol#L155-L239` (`settleDebt/migrateDeposits`)
- **First seen:** phlimbo-ea-06  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/06/audit/submissions/qa-report.md](../../../06/audit/submissions/qa-report.md)
  - _Pointer resolved at run-11 by verified label match; no `reportPath` was recorded on this entry._
- **Fingerprint:** `e11518b6…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
