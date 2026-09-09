# [CARRYOVER] ss12l4 (run-12 L-04) — Near-MIN_TIMEOUT multi-batch self-exit leaves a partially-refilled pool

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/InPlaceMigrator.sol` (`claimTimedOut`)
- **First seen:** stable-staker-12  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not enforce a timeout lower bound; a near-MIN_TIMEOUT multi-batch self-exit can still leave a partially-refilled pool.
- **Original report:** [reports/stable-staker/12/submissions/qa-report.md](../../../12/submissions/qa-report.md)
- **Fingerprint:** `a08c8eb0…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
