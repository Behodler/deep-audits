# [CARRYOVER] V3-Q-04 — finalizePromotion (:511) has no nonReentrant, so OZ's contract-wide lock is never held across its external transfer at :521 -- REFUTED AS A VULNERABILITY; hardening note only

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** QA
- **Status:** open (still-open)
- **Location:** `src/PhlimboV3.sol#L511-L529` (`finalizePromotion`)
- **First seen:** phlimbo-ea-09  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/09/submissions/qa-report.md](../../../09/submissions/qa-report.md)
- **Fingerprint:** `81c3d77d…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
