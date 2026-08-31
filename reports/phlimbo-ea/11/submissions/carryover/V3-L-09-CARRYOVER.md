# [CARRYOVER] V3-L-09 — MigratorV2V3 seedUsers owner footgun: fails loudly at the safest point (no state committed, no funds at risk)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/MigratorV2V3.sol#L114-L140` (`seedUsers`)
- **First seen:** phlimbo-ea-08  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/08/audit/submissions/qa-report.md](../../../08/audit/submissions/qa-report.md)
- **Fingerprint:** `df269619…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
