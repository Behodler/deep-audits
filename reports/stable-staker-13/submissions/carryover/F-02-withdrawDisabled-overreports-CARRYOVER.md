# [CARRYOVER] F-02-withdrawDisabled-overreports — withdrawDisabled view over-reports: returns raw _isUnderwater after story-002 added the buffer path, so it reads true where a buffer-covered withdraw would succeed

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L594-L600` (`withdrawDisabled`)
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not touch withdrawDisabled / _isUnderwater; the view still over-reports disabled where a buffer-covered withdraw would succeed (faithfulness F-02).
- **Original report:** [reports/stable-staker-07/submissions/spec-conformance.md](../../../stable-staker-07/submissions/spec-conformance.md)
- **Fingerprint:** `a56f8778…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
