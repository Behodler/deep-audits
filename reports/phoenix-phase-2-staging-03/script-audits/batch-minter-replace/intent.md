# Intent — batch-minter-replace (script/ReplaceBatchNFTMinter.s.sol:ReplaceBatchNFTMinter)

## Stated purpose (from story-050 header comment + NatSpec)
One-shot mainnet cutover (story 050 / incident §6): replace the old exploited BatchNFTMinter
with the fixed, minter-pinned redeploy, repoint its two real funders, seed the new USDC nudge
pot from the Balancer BPT, and neutralize the old contract.

- [ ] Deploy a fresh `BatchNFTMinter(OWNER)` (the fixed, minter-pinned contract).
- [ ] Configure new minter: `setTokenMinter(NFT_MINTER_V2)` → `setDispatcherIndex(4)` →
      `setNudgePaymentToken(USDC)` → `setNudgeSize(40)`.
- [ ] Repoint funder #1: `SYA.setNudgeAddress(newMinter)` (StableYieldAccumulator nudge pointer).
- [ ] Repoint funder #2: `BalancerPoolerV2.setBatchMinter(newMinter)` (index-4 pooler donation recipient).
- [ ] Seed the new nudge pot from BPT: withdraw a slice sized to ~`SEED_USDS_TARGET` of sUSDS
      value, proportional-exit BPT → sUSDS + phUSD, swap sUSDS → waUSDC → USDC into the new pot,
      burn the phUSD leg.
- [ ] Retire the old contract: zero its nudge config (`setNudgePaymentToken(0)`, `setNudgeSize(0)`).
- [ ] (broadcast only) Persist `progress.batch-minter-replace.1.json`; post-JS rewrites
      `mainnet-addresses.ts` BatchNFTMinter + NudgeBatchNFTMinter keys.

## Declared pre-conditions (require / implicit guards BEFORE funds move)
From `_guards()` (run after deploy/configure, before `_repoint`/`_seedFromBpt`):
- `newMinter.tokenMinter() != address(0)`            — "tokenMinter not set"
- `newMinter.dispatcherIndex() == 4`                 — "dispatcherIndex != 4"
- `newMinter.nudgePaymentToken() == USDC`            — "nudge token != USDC"
- `NFT_MINTER_V2.configs(4).dispatcher != address(0)`— "index-4 dispatcher missing"
- `dispatcher.primeToken() == USDS`                  — "index-4 primeToken != USDS" (drift guard)
- `newMinter.nudgePaymentToken() != primeToken`      — "nudge token == prime token" (exploit guard:
   nudge payout token must differ from the mint payment token, else batchMint reverts up-front)

From `_seedFromBpt()` (sizing guards before the BPT withdraw):
- `poolSusdsValue > 0`                               — "pool holds no sUSDS"
- `poolerBpt > 0`                                    — "pooler holds no BPT"
- `bptSlice >= minBptWei` (DEFAULT_MIN_BPT_WEI 40e18)— "BPT slice below floor"
- `bptSlice > 0`                                     — "BPT slice is zero"

From the in-script `SeedSwapHelper` (slippage floor, the ONLY one):
- `usdcReceived >= minUsdcOut` (DEFAULT_MIN_USDC_OUT 47_000_000) — reverts `UsdcSlippage`

From `_retireOld()` (BEFORE the old-contract neutralization writes):
- `IERC20(USDC).balanceOf(OLD_BATCH_MINTER) == 0`    — "old contract still holds USDC"

NOTE: `removeLiquidityProportional(LP_POOL, bptSlice, [0,0], ...)` is called with
`minAmountsOut = [0,0]` — **no per-leg slippage floor on the proportional exit itself.**

## Declared post-conditions (require / assert AFTER the broadcast actions)
From `_repoint()`:
- `SYA.nudge() == newMinter`                         — "SYA repoint failed"
- `BalancerPoolerV2.batchMinter() == newMinter`      — "pooler repoint failed"

Smoke/measurement (not enforced as require):
- `usdcOut = USDC.balanceOf(newMinter) - potBefore` is logged (the seed actually landed).
- `_postflight` logs the final pointers + pot balance (console-only; no assert).

## Conditions the script does NOT declare (gaps — see findings)
- No assert/restore of `SYA.nudgeSplit` (the PRIMARY funding lever the predecessor stop-gap zeroed).
- No floor on the proportional-exit legs (`minAmountsOut=[0,0]`); single downstream USDC floor only.
- No assert that the seeded `usdcOut > 0` or `>= minUsdcOut` at the script level (helper enforces it,
  but the script does not independently gate on the measured delta).
- No assert/handling for `mint(4)` end-to-end callability (pooler `_minter` authorization) — out of
  this script's writes, but the cutover's "the nudge works again" intent depends on it.
