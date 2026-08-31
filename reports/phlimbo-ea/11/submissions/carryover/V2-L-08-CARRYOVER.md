# [CARRYOVER] V2-L-08 — _updatePhUSDEmissionRate truncates phUSDPerSecond to zero at low totalStaked x low APY

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV2.sol#L512-L519` (`_updatePhUSDEmissionRate`)
- **First seen:** phlimbo-ea-06  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/06/audit/submissions/qa-report.md](../../../06/audit/submissions/qa-report.md)
  - _Pointer resolved at run-11 by verified label match; no `reportPath` was recorded on this entry._
- **Fingerprint:** `81e52abf…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
