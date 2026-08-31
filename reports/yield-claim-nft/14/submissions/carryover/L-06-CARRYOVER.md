# [CARRYOVER] L-06 — pool()/unlockCallback single-sided sUSDS LP-add relies solely on off-chain keeper minBPT with no on-chain price reference (MEV sandwich)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open carryover; out of run-14 changed-file scope)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L269-L275` (`pool`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-14
- **Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../../10/submissions/qa-report.md)
- **Fingerprint:** `342075df…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
