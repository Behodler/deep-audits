# [CARRYOVER] V3-F-02 — FAITHFULNESS: PhlimboV3 'the flush must never brick' invariant undermined by unchecked abi.decode (story-022)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV3.sol#L812-L820` (`batchClaim/_tryTransfer`)
- **First seen:** phlimbo-ea-07  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/07/audit/submissions/spec-conformance.md](../../../07/audit/submissions/spec-conformance.md)
- **Fingerprint:** `6027f256…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
