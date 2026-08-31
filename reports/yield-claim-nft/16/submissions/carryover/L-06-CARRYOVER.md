# [CARRYOVER] L-06 — single-sided LP-add relies solely on off-chain keeper min floors, no on-chain price reference (MEV sandwich)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged away). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (re-confirmed still-open at f46a5cb in run-16)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L269-L275` (`pool`); Uniboost buy-and-pool instance at `src/dispatchers/Uniboost.sol` (`pool`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-16
- **Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../../10/submissions/qa-report.md)
- **Fingerprint:** `342075df…`
- **Run-16 note:** Uniboost buy-and-pool MEV-sandwich instance re-observed via cold scan; same off-chain-floor root-cause class (keeper-gated, bounded by minPairOut/minTargetOut/minLP). No new exploit path — stays Low, not re-escalated.

See the original report for the full description, impact, attack path, and recommendation.
