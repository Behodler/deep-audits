# [CARRYOVER] V3-L-13 — batchClaim lacks the per-user try/catch containment and cursor skip the byte-identical migrator path HAS: a revert inside the loop pins flushCursor => permanent rotation DoS

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV3.sol#L460-L487` (`batchClaim`)
- **First seen:** phlimbo-ea-09  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/09/submissions/qa-report.md](../../../09/submissions/qa-report.md)
- **Fingerprint:** `9a99a21b…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
