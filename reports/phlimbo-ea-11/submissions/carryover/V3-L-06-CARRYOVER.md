# [CARRYOVER] V3-L-06 — PhlimboV3 abortFlush never calls _updatePool: story-024's freeze gate makes an aborted flush's promo window path-dependent on an unprivileged caller (~1 wei collectReward)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV3.sol#L495-L502` (`abortFlush/_updatePool`)
- **First seen:** phlimbo-ea-08  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea-08/audit/submissions/qa-report.md](../../../phlimbo-ea-08/audit/submissions/qa-report.md)
- **Fingerprint:** `4dd91d62…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
