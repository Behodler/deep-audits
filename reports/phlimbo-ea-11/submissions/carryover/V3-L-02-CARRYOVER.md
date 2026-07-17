# [CARRYOVER] V3-L-02 — PhlimboV3 _tryTransfer abi.decode reverts on short return-data, bricks batchClaim chunk (token-gated)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV3.sol#L816-L820` (`_tryTransfer/batchClaim`)
- **First seen:** phlimbo-ea-07  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea-07/audit/submissions/qa-report.md](../../../phlimbo-ea-07/audit/submissions/qa-report.md)
- **Fingerprint:** `c0e37955…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
