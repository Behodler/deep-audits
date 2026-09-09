# [CARRYOVER] V3-L-10 — _tryTransfer treats a CODELESS address as a successful transfer (empty returndata == success): a payment that never happened is recorded as paid; present in BOTH hand-rolled copies

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV3.sol + src/MigratorV2V3.sol#L816-L820` (`_tryTransfer`)
- **First seen:** phlimbo-ea-08  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/08/audit/submissions/qa-report.md](../../../08/audit/submissions/qa-report.md)
- **Fingerprint:** `2150491c…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
