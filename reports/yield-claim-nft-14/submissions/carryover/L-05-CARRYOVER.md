# [CARRYOVER] L-05 — No on-chain invariant couples BalancerPoolerV2.batchDonationSize and Hook.ratio (missing batchDonationSize + ratio <= 100 guardrail)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open carryover; out of run-14 changed-file scope)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L160-L164` (`setBatchDonationSize`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-14
- **Original report:** [reports/yield-claim-nft-10/submissions/qa-report.md](../../../yield-claim-nft-10/submissions/qa-report.md)
- **Fingerprint:** `e527a712…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
