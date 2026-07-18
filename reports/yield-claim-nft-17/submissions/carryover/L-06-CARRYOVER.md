# [CARRYOVER] L-06 — pool()/unlockCallback single-sided LP-add relies solely on off-chain keeper min floors with no on-chain price reference (MEV sandwich)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/dispatchers/BalancerPoolerV2.sol#L269-L275` (`pool / unlockCallback`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft-10/submissions/qa-report.md](../../yield-claim-nft-10/submissions/qa-report.md)
- **Fingerprint:** `342075df…`
- **Run-17 note:** CLASS RECURRED this run on the new PromotionUniV2_Eth ETH swap leg (swapExactETHForTokens floors + amountAMin=amountBMin=0 addLiquidity + block.timestamp deadline). Each ETH leg carries its own floor (minEthOut/minPromoOut) and post-call require(liquidity>=minLP) backstops the add; authorized-keeper gate = no unprivileged zero-floor trigger. More legs of the same class, NOT a new class => stays Low, NOT re-escalated. Same fingerprint reused (CANDIDATE-2), no new label. lastSeenRun bumped 16->17.

See the original report for the full description, impact, attack path, PoC, and recommendation.
