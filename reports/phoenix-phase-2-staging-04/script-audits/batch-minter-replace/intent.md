# Intent — batch-minter-replace (ReplaceBatchNFTMinter, Story 050)

REGRESSION re-audit. Baseline commit `ebc2808`, target HEAD `912a33d`. Fork-verified at block **25208568** (RPC_MAINNET, chainId 1). Closure delta = a single file: `script/ReplaceBatchNFTMinter.s.sol` (+72/-7), the two human-review fixes.

## Stated purpose (from `//` story comment + NatSpec)
One-shot owner-signed mainnet cutover that:
- [x] Re-deploys the fixed, minter-pinned `BatchNFTMinter(OWNER)`.
- [x] Repoints the new minter's two real funders:
  - [x] `SYA.setNudgeAddress(newMinter)` (the claim()-path nudge recipient).
  - [x] `BalancerPoolerV2.setBatchMinter(newMinter)` (the pooler batch-donation recipient).
- [x] **FIX B:** Restores `SYA.setNudgeSplit(30)` — the incident mitigation zeroed it, so the prior cutover repointed the pot but never re-enabled funding.
- [x] Seeds the new USDC nudge pot from the Balancer 50/50 phUSD/sUSDS BPT: proportional exit -> sUSDS + phUSD, swap sUSDS->waUSDC->USDC into the pot (via SeedSwapHelper), burn the phUSD leg.
- [x] **FIX A:** Computes non-zero per-leg `minAmountsOut` for the proportional exit (was `[0,0]` unbounded).
- [x] Neutralizes the old exploited contract (`setNudgePaymentToken(0)`, `setNudgeSize(0)`), guarded by `require(USDC.balanceOf(OLD)==0)`.

## Declared pre-conditions (`require` before funds move — `_guards()`)
- `newMinter.tokenMinter() != address(0)`
- `newMinter.dispatcherIndex() == 4`
- `newMinter.nudgePaymentToken() == USDC`
- `configs(4).dispatcher != address(0)` (index-4 dispatcher resolvable)
- `configs(4).dispatcher.primeToken() == USDS`
- `newMinter.nudgePaymentToken() != primeToken` (exploit guard: nudge token must differ from mint-payment token)
- **NEW (Fix A):** `EXIT_SLIPPAGE_BPS > 0 && < 10_000` (range guard, run() top)
- **NEW (Fix A):** `rawToks.length == 2` (pool shape guard)
- **NEW (Fix A):** `minAmountsOut[i] > 0` per leg (no-unbounded-exit guard)

## Declared post-conditions (`require`/assert after the mutation — `_repoint()`)
- `SYA.nudge() == newMinter`
- **NEW (Fix B):** `SYA.nudgeSplit() == 30`
- `POOLER.batchMinter() == newMinter`
- `_retireOld()`: `require(USDC.balanceOf(OLD) == 0)` (retire-guard)
- Inside SeedSwapHelper: `require(usdcReceived >= minUsdcOut)` (final USDC floor)

## NOT declared (gaps confirmed in this audit — see findings)
- No `require(block.chainid == 1)` guard (relies solely on `--rpc-url`).
- No script-level assertion tying the actual `usdcSeeded` to an expected pot delta (BMR-L-02 unaddressed).
- The `_retireOld` USDC==0 guard sits in the broadcast path and is grief-abortable by a 1-wei donation to OLD (BMR-L-01 unaddressed).
- No verification that `POOLER._minter` (dispatch authorization) is set — relied on as pre-existing state (confirmed already set on-chain; see knock-on analysis).
