# [CARRYOVER] ss9l1 — finalizeAndReset revives pool without resetting phusdPerSecond / re-wiring yieldStrategy (revival over-emission footgun)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L585-L596` (`finalizeAndReset`)
- **First seen:** stable-staker-09  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not touch finalizeAndReset; a revived pool still resumes on stale phusdPerSecond / yieldStrategy settings (revival over-emission footgun).
- **Original report:** [reports/stable-staker-09/submissions/qa-report.md](../../../stable-staker-09/submissions/qa-report.md)
- **Fingerprint:** `ss9l1-finalizeAndReset-revival-stale-emission-rate…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
