# [CARRYOVER] L-06 — Single-sided sUSDS LP-add relies solely on off-chain keeper minBPT (MEV sandwich)

> **This is a carryover stub, not new analysis.** Reported in a prior run and **still open**
> (not fixed, not triaged). Carried over from prior run, unchanged at the flattened path
> introduced by story-039. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L269-L275` (`pool` / `unlockCallback`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-12
- **Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../../10/submissions/qa-report.md)
- **Fingerprint:** `342075df…` — see ledger `342075dfba3c8ec7c3bae1ae18c357591c5ea255bf649ee943c6c71f3ddd4c2e`

`pool()`/`unlockCallback` single-sided sUSDS LP-add relies solely on an off-chain keeper-supplied minBPT with no on-chain price reference (MEV sandwich exposure). Unchanged by story-039. See the original QA report for full description, impact, and recommendation.
