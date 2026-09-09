# Intent — deploy:ratchet-mainnet (DeployMainnetNudgeRatchet)

Target commit: `3c46ebc` (phoenix-phase-2-staging). Nested source pins verified:
`lib/yield-claim-nft @ 7b86dec` (story-038, AHEAD of run-11's b8322ee — contains the M-03/M-04 fixes),
`lib/nft-staking @ eee9d3a` (story-017 NFTStakerPriceScaled), `lib/flax-token-v2 @ f5300117`,
`lib/pauser @ 545928d`. Fork verification block: **25356592** (chainId 1).

## Stated purpose (from @notice + patcher header → story 069)
Promote story-068's local NudgeRatchet integration (DeployMocks Phase 3.7) to mainnet:
- [x] Deploy 5 contracts: RatchetBatchNFTMinter(=BatchNFTMinter), NudgeRatchet, NudgeRatchetMintDebtHook,
      RatchetNFTStaker(=NFTStakerPriceScaled), MintPageView.
- [x] Wire them: NudgeRatchet.minter→NFTMinterV2; NudgeRatchet.hook→hook; hook authorised as phUSD minter;
      RatchetNFTStaker.dispatcherHook→hook; hook.recipient→staker; batchMinter index/nudge config; targetAPY=0.45e18.
- [x] Register NudgeRatchet as dispatcher index 7 (index 6 = permanently-disabled bugged pooler).
- [x] Redeploy MintPageView (adds the index-7 "Ratchet"/USDC entry) and repoint ViewRouter "mint" page to it.
- [x] Off-chain: backup `mainnet-addresses.ts`, then patch 4 ratchet keys (collide-on-nonzero) + UPDATE MintPageView.

## Declared pre-conditions (in-script `require` gates — the ONLY pre-flight under `--skip-simulation`)
- `block.chainid == 1` ("Wrong chain ID").
- Config-safety gates: `RATCHET_INITIAL_PRICE>0`, `RATCHET_GROWTH_BPS>0`, `TARGET_APY>0`, `RATCHET_PRICE_SCALE>0`,
  `USDC/USDS/PHUSD != 0`, `OWNER_ADDRESS != 0`.
- NudgeRatchet ctor: `token_.decimals()==6` (USDC 6-dp guard); `batchMinter_ != 0`.
- Hook ctor: `dispatcher_ != 0`, `phUSD_ != 0`.
- Staker ctor: non-zero token/reward/minter; `priceScale != 0`.
- registerDispatcher gate: `nudgeRatchet != 0` AND **`nudgeRatchetHook != 0`** (hook MUST be wired before registration — M-04 guard).
- Implicit (live state): caller (pranked/Ledger owner) must own NFTMinterV2, ViewRouter, Pauser, phUSD —
  all four confirmed owned by `0xCad1…D0B6` at block 25356592.

## Declared post-conditions (asserts in `_verifyWiring`, read-only, both modes)
- `dispatcherToIndex(nudgeRatchet) == 7` (also asserted inline at step 8: "did not land at index 7").
- `MintPageView.nftMinter() == NFTMinterV2`.
- `ViewRouter.pages(keccak256("mint")) == mintPageView`.

## NOTE — docstring vs. body step numbering
The @notice header lists 18 steps where setHook is "step 7" and registerDispatcher "step 9"; the `run()`
body labels them differently (setHook=step 6, phUSD.setMinter=step 7, registerDispatcher=step 8). The
*ordering* is identical and correct (hook fully set on the ratchet, and phUSD minter authority granted,
BEFORE registerDispatcher). Only the comment numbering drifts — cosmetic, captured as L-02.
