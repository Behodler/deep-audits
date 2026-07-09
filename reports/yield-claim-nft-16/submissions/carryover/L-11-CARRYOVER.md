# [CARRYOVER] L-11 — MultiPooler.pool same-pool in-batch floor staleness reverts the atomic batch (self-inflicted DoS)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged away). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low (Law-3 operational footgun, in scope)
- **Status:** open (re-confirmed still-open at f46a5cb in run-16)
- **Location:** `src/MultiPooler.sol#L60-L67` (`pool`)
- **First seen:** yield-claim-nft-14  ·  **Still present as of:** yield-claim-nft-16
- **Original report:** [reports/yield-claim-nft-14/submissions/qa-report.md](../../yield-claim-nft-14/submissions/qa-report.md)
- **Fingerprint:** `531916f4…`
- **Run-16 note:** Exact match; STATIC-021 (BatchPooled-event-after-loop) folds in benign. Still open, Low, no escalation. Default one-pool-per-dispatcher deployment is unaffected.

See the original report for the full description, impact, attack path, and recommendation.
