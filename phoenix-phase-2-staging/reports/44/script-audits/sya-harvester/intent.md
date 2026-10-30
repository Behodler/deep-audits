# Intent — sya-harvester (story-122 Script A)

Source commit `669cbc1` (script introduced by `753796b [story-122] ...`). Forge target
`script/DeploySyaHarvesterMainnet.s.sol:DeploySyaHarvesterMainnet`; verifier `script/VerifySyaHarvester.s.sol`.

## Authoritative story
- `~/code/product-owner/stories/phStaging2/auto-complete/sya-antimatter-cutover/122-sya-antimatter-mainnet-catch-up.md`
  (state `auto-complete` = final; machine-approved, Review Status ISSUES_FOUND, triaged non-blocking).
- Route rules: vault-RM story-052
  `~/code/product-owner/stories/vault-RM/auto-complete/curve-adapter-m01/052-curve-amm-adapter-route-contiguity-m01.md`
  (NOT phStaging2 story-052, which is an unrelated pauser story — number collision only).
- Human's standing warning (story L18-19, verbatim requirement): check each Router NG route off-chain against the
  story-052 rules, then dry-run a swap in each direction on a fork asserting on balance change, before broadcasting.

## Stated purpose (story Script A + package.json `//sya-harvester` + NatSpec)
- [x] Deploy `SYAHarvester(OWNER, PoolManager 0x0000…4444c5dc75cB358380D2e3dE08A90, SYA 0x0cD3…21B6, Router NG 0x16C6…5353)` (pin `6b862aa`)
- [x] `setRoute(USDe)`: `[USDe, 0xF55B…0442, crvUSD, 0x4DEc…D69E, USDC, 0…]`, swapParams `[0,1,1,10,2]`,`[1,0,1,1,2]`, pools 0
- [x] `setRoute(DOLA)`: `[DOLA, 0xE571…884d, USDC, 0…]`, swapParams `[0,2,2,1,3]` (exchange_underlying), pools 0
- [x] USDC carries no route (reward token)
- [x] `setEthPool(PoolKey{ETH, USDC, 3000, 60, hooks 0})`
- [x] Read-back of routes/pool key
- [x] `StableStakerV2(0xA6d3…B58F).setClaimEnabled(true)` + `require(claimEnabled())`
- [x] Resumable: each step gated on chain state; progress in `server/deployments/progress.sya-harvester.1.json`
- [x] Broadcast tail: backup book → Ledger broadcast → FILL `SYAHarvester` → `:verify` → tax ledger
- [~] Story-122 checklist item "`stable-staker-v2-cutover:verify` still passes against current mainnet" — ticked but FALSE
  (Phase 6b OWNER DOLA residual 88138771830498 wei) — disclosed in story (Decision 3, Review issue 1). Re-found in run 44.

## Declared pre-conditions (script body, before any `vm.startBroadcast`, both modes)
1. `block.chainid == 1`
2. Book keys StableYieldAccumulator/USDC/Dola/USDe/StableStakerV2/NFTMinter non-zero; every input + Router NG + PoolManager + crvUSD has code
3. `SYA.rewardToken() == USDC`, `SYA.nftMinter() == book NFTMinter`, `StableStakerV2.owner() == OWNER`
4. Curve coin indices: USDe/crvUSD pool coins(0)=USDe, coins(1)=crvUSD; crvUSD/USDC pool coins(0)=USDC, coins(1)=crvUSD; DOLA/FRAXBP coins(0)=DOLA; FRAXBP coins(1)=USDC
5. Route coverage: every SYA strategy token ∈ {USDC, DOLA, USDe}
6. Off-chain story-052 payload check (`checkRoutePayload`) on both payloads (k=2 USDe, k=1 DOLA) and both reversed payloads:
   path[0]==tokenIn; k≥1; no non-zero entry after 2k; no zero token for i≤k; path[2k]==USDC; executed swap_type ∈ 1..8
   (≠0, ≠9); unexecuted rows and all pools zero
7. Bidirectional fork dry run per route (1,000 units, snapshot-reverted): receiver pulled exactly amountIn, no crvUSD
   left on receiver, forward USDC delta ≥ 970 USDC, reverse tokenIn delta ≥ 970 tokens (balance deltas, not return values)
8. Resume: progress-named harvester must have code (else abort) and pass `_checkImmutables`

## Declared post-conditions
- In-script: `_checkImmutables` after CREATE; `_checkConfigured` read-back (routes byte-equal to payloads, stored routes pass
  052 check with k=2/1, USDC unrouted, ETH pool exact); harvest smoke in snapshot (claimable>0, index-4 registered &
  enabled, caller ETH up, exactly one NFT burned, SYA claimable consumed, harvester holds no ETH/USDC/DOLA/USDe/crvUSD/NFT);
  `require(StableStakerV2.claimEnabled())`
- Verifier (`VerifySyaHarvester`): preflight again; harvester from book or progress (must agree when both set);
  owner/immutables; both routes contiguous & exact; USDC unrouted; ETH pool exact; `claimEnabled()==true`
- Patcher: FILL only zero/identical; requires progress `completed` + `claimEnabled:true`; key-set drift check (exit 3)
- Knock-on (story L117): `VerifyStableStakerV2Cutover` Phase 7 and `CutoverStableStakerV2Mainnet` Phase 7/8
  `_doneClaimStillDisabled()` = `!claimEnabled || ClaimUnblockState.recorded()` (progress `.claimEnabled==true` OR book `SYAHarvester` non-zero)
