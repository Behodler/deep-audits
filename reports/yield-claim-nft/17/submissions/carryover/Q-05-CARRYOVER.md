# [CARRYOVER] Q-05 — nonReentrant is not the first modifier on pool()/the hook-guarded entry (defense-in-depth)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** QA
- **Status:** open (still-open)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L269` (`pool`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../../10/submissions/qa-report.md)
- **Fingerprint:** `13fe448d…`
- **Run-17 note:** CLASS RECURRED this run byte-identically on PromotionUniV2_Eth.pool (order: onlyAuthorizedPooler, whenNotPaused, nonReentrant; preceding modifiers only read state). De-dup-against-ledger (QA-d), stays visible in the QA bundle; not a suppression. Same fingerprint reused, no new label. lastSeenRun bumped 12->17.

See the original report for the full description, impact, attack path, PoC, and recommendation.
