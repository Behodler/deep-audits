# [CARRYOVER] L-02 — setRatio accepts ratio == MAX_RATIO, contradicting documented strict-less-than invariant

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** qa-bundled (still-open)
- **Location:** `src/V2/hooks/BalancerPoolerMintDebtHook.sol#L77-L82` (`setRatio`)
- **First seen:** yield-claim-nft-08  ·  **Still present as of:** yield-claim-nft-10
- **Original report:** [reports/yield-claim-nft-08/submissions/qa-report.md](../../../yield-claim-nft-08/submissions/qa-report.md)
- **Fingerprint:** `5425119c…`

This run's DD-02 (faithfulness/pattern view, Halmos SYMBOLIC-P2 reachable set proven bounded to [0,50]) reconciles to the same root cause; no duplicate is emitted. Not a regression — L-02 was never marked fixed.

See the original report for the full description, impact, attack path, PoC, and recommendation.
