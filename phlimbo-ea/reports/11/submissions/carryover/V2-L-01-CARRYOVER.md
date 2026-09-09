# [CARRYOVER] V2-L-01 — pauseWithdraw stale-debt underflow brick (self-inflicted; principal recoverable via re-pause)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV2.sol#L280-L291` (`pauseWithdraw/_claimRewards`)
- **First seen:** phlimbo-ea-06  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/06/audit/submissions/qa-report.md](../../../06/audit/submissions/qa-report.md)
  - _Pointer resolved at run-11 by verified label match; no `reportPath` was recorded on this entry._
- **Fingerprint:** `9ef309e7…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
