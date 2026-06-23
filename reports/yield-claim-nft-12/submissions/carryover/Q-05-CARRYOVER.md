# [CARRYOVER] Q-05 — nonReentrant is not the first modifier on pool() (defense-in-depth)

> **This is a carryover stub, not new analysis.** Reported in a prior run and **still open**
> (not fixed, not triaged). Carried over from prior run, unchanged at the flattened path
> introduced by story-039. Triage it with `/ledger yield-claim-nft`.

- **Severity:** QA
- **Status:** open (still-open)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L269` (`pool`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-12
- **Original report:** [reports/yield-claim-nft-10/submissions/qa-report.md](../../yield-claim-nft-10/submissions/qa-report.md)
- **Fingerprint:** `13fe448d…` — see ledger `13fe448d0eb09c383e7b6cbb92fcdb57425ecfa5a7802f2174458c46d566e243`

`nonReentrant` is not the first modifier on `pool()` / the hook-guarded entry (defense-in-depth ordering). Unchanged by story-039. See the original QA report for full description and recommendation.
