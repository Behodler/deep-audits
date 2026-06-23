# [CARRYOVER] L-05 — No on-chain invariant couples batchDonationSize and Hook.ratio

> **This is a carryover stub, not new analysis.** Reported in a prior run and **still open**
> (not fixed, not triaged). Carried over from prior run, unchanged at the flattened path
> introduced by story-039. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L160-L164` (`setBatchDonationSize`)  ·  faithfulness tag F-02
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-12
- **Original report:** [reports/yield-claim-nft-10/submissions/qa-report.md](../../yield-claim-nft-10/submissions/qa-report.md)
- **Fingerprint:** `e527a712…` — see ledger `e527a712118b9cff5ccda89bd645f68078b0509711781369ef8a09785d954822`

No on-chain guardrail couples `BalancerPoolerV2.batchDonationSize` and `Hook.ratio` (missing `batchDonationSize + ratio <= 100` invariant). Unchanged by story-039. See the original QA report for full description, impact, and recommendation.
