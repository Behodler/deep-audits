# [CARRYOVER] V3-L-08 — MigratorV2V3 withdrawAll strands banked unclaimable claims with NO aggregate accounting (no totalUnclaimable): stale entries survive the sweep and a later claimant can take a subsequent user's backing (first-come reallocation)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/MigratorV2V3.sol#L237-L265` (`withdrawAll/claimUnclaimable`)
- **First seen:** phlimbo-ea-08  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/08/audit/submissions/qa-report.md](../../../08/audit/submissions/qa-report.md)
- **Fingerprint:** `faa2d9ba…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
