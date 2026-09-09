# [CARRYOVER] L-11 — MultiPooler.pool same-pool in-batch floor staleness reverts the atomic batch (self-inflicted DoS) or degrades a floor-bounded LP add

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/MultiPooler.sol#L60-L67` (`pool`)
- **First seen:** yield-claim-nft-14  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft/14/submissions/qa-report.md](../../../14/submissions/qa-report.md)
- **Fingerprint:** `531916f4…`
- **Run-17 note:** Not re-scanned this run (MultiPooler outside the story-044 slice). Remains open; POL-only, keeper-avoidable, default one-pool-per-dispatcher deployment unaffected. lastSeenRun unchanged (yield-claim-nft-16).

See the original report for the full description, impact, attack path, PoC, and recommendation.
