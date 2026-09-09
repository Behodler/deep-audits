# [CARRYOVER] ss12l2 (run-12 L-02) — Underwater-migration operator footgun: in-place flow silently realizes the faithful min(R,P)/P socialized haircut

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/InPlaceMigrator.sol` (`initiateMigration`)
- **First seen:** stable-staker-12  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not block or signal the in-place flow on an impaired strategy; the underwater-realization operator footgun is unchanged.
- **Original report:** [reports/stable-staker/12/submissions/qa-report.md](../../../12/submissions/qa-report.md)
- **Fingerprint:** `78667e83…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
