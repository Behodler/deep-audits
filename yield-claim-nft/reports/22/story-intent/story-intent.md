# Story intent: run yield-claim-nft-22 (267660b..0fd6bdf)

Only tag in range: [story-052] (commits 2e4a28c RED, 0fd6bdf GREEN).

## Story documents (read-only copies; originals in ~/code/product-owner/stories/)
- 052-unipooler-cutover-escrow.md — yield-claim-nft/**review**/yield-claim-nft-Balancexit/ (state: review, NOT complete; landed code with story still in review). Required Human Action #1: "audit the escrow ... must not be deployed to mainnet before the audit passes" — this run is that gate.
- 103-mainnet-unipooler-cutover-script-stage2.md — phStaging2/incomplete/phStaging2-Balancexit/ (consumer: rewires UniPoolerCutoverCore to the escrow; gated on 052 complete+audited).
- 050-delete-balancer-interfaces-post-winddown.md — yield-claim-nft/incomplete/yield-claim-nft-Balancexit/ (must NOT delete/modify src/migration/ or escrow tests).

## Purpose
One-shot custody contract so Balancexit cutover funds (BPT ~20.4k + owner's 202.30, exit proceeds ~19.1k sUSDS / ~21.9k phUSD, parked USDS) move contract-to-contract and never via any EOA (tax/accounting requirement). Only outflows: newPooler (UniPoolerV2) forward, or oldPooler (BalancerPoolerV2) on abort. No function takes a caller-chosen recipient.

## Acceptance criteria (052 Design + Checklist)
Access / surface
- Immutable non-zero `operator` gates every state-changing fn; no Ownable/transferOwnership/renounce.
- No receive/fallback; zero ETH to routers; only views besides exitAndSeed / wrapUsds / abort.
- File-local interfaces only (no import of src/interfaces/balancer/* or BalancerPoolerV2; grep proof clean). Location src/migration/.
- No existing src file modified.

Constructor
- Rejects zero addresses (args and values read from poolers: pair, router, sUSDS, phUSD, pool, primeToken).
- Reads pair/router/sUSDS/phUSD from newPooler; snapshots BPT=oldPooler.pool() (mutable via setPool) and USDS=oldPooler.primeToken().
- Requires oldPooler.sUSDS()==newPooler.sUSDS() and IERC4626(sUSDS).asset()==USDS.

exitAndSeed(mode, minAmountsOut, deadline) — onlyOperator, nonReentrant, atomic
1. Pair empty: if balances non-zero but reserves (0,0) -> skim(newPooler) (fixed recipient); then require reserves (0,0) AND balances (0,0). Synced donation = DoS only.
2. bptIn = BPT.balanceOf(this) > 0.
3. minAmountsOut.length==2, each >0; block.timestamp < deadline <= block.timestamp + 1 days.
4. forceApprove(v3Router, bptIn); removeLiquidityProportional or removeLiquidityRecovery per `mode` (never clock-derived); reset approval; require BPT balance 0.
5. Seed with WHOLE sUSDS/phUSD balances: forceApprove Router02 exact; addLiquidity(..., mins = desired, to=newPooler, deadline); require a==s && b==p, liquidity>0, newPooler LP += liquidity, reserves == seeded; reset approvals.
6. Post: escrow BPT/sUSDS/phUSD == 0; emit Seeded.

wrapUsds() — onlyOperator, nonReentrant: amt=USDS bal>0; forceApprove; sUSDS.deposit(amt, newPooler); reset; USDS bal==0; emit UsdsWrapped.

abort() — onlyOperator, nonReentrant: transfer entire BPT/sUSDS/phUSD/USDS to oldPooler only; emit Aborted (no-op allowed).

Tests: V3 exit-router mock faithful (router-allowance burn, pro-rata, min enforcement, paused vs recoveryMode flags); property that no token leaves escrow except to permitted per-token destinations; fork test (block 26_136_000) must fail-loud without RPC.

## Flagged for the auditor by the story itself
- On-chain share check absent: escrow enforces only non-zero minAmountsOut; live proportional floor computed off-chain by phStaging2 core (must be over COMBINED escrow BPT incl. owner's 202.30).
- Whole-balance seed: stray non-proportional donations shift seeded price (bounded by operator timing).
- Canonical-pair griefing (synced donation / first mint) — DoS only; abort returns funds.
- Operator key loss strands escrow funds (accepted design).
- No rescue for tokens outside the four (INFO).
- Seed price inherited from Balancer ratio (~18,656 sUSDS : 22,456 phUSD at fork block); human to confirm phUSD price.
- Router02 approval reset is unobservable (mutation survives) — defensive only.
- Repo-wide fmt/sizes failures pre-existing (PromotionUniV2_Eth 24,770 B > EIP-170) — checklist item left unticked.

## Cross-story obligations (103) relevant to faithfulness
- Escrow deployed after UniPoolerV2+pair (step 3), before withdrawBPT(escrow) (step 4); step 2 skim dropped; owner BPT transferred in; steps 5+6 -> exitAndSeed; parked USDS -> rescueERC20(usds, escrow) + wrapUsds; invariant: owner's BPT/sUSDS/phUSD/USDS never increase.
