<!--
C4 Submission Metadata
Title: [H-01] Spot price oracle manipulation bypasses targetPrice minimum in claim()
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L731-L733
PoC File: poc-H-01.t.sol
-->

## Finding description and impact

### Summary

`_getPhUSDPriceInUSDS()` reads the Uniswap V4 instantaneous spot price via `poolManager.getSlot0()` rather than a TWAP or external oracle. Because spot price is trivially manipulable within a single transaction, the `targetPrice` check in `claim()` provides zero effective protection against claims during phUSD depegs.

### Root cause

The root cause is at [StableYieldAccumulator.sol#L731-L733](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L731-L733):

```solidity
function _getPhUSDPriceInUSDS() internal view returns (uint256) {
    (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(pricePoolId);
    // ... calculates price from sqrtPriceX96 (instantaneous spot price)
```

`getSlot0()` returns the current tick/price of the pool, which reflects the most recent swap. This value can be moved arbitrarily within a single transaction by swapping a sufficient amount of tokens through the pool.

### Vulnerability details

The `claim()` function includes a price floor check intended to prevent yield claims when phUSD is trading below its target price ([StableYieldAccumulator.sol#L571-L578](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L571-L578)):

```solidity
// Price minimum check: only allow claim if phUSD spot price >= target price
if (address(poolManager) != address(0) && targetPrice > 0) {
    uint256 currentPrice = _getPhUSDPriceInUSDS();
    if (currentPrice < targetPrice) {
        revert phUSDPriceBelowTarget(phUSD, address(poolManager), uint256(PoolId.unwrap(pricePoolId)));
    }
}
```

The intent is sound: during a phUSD depeg, claims should be blocked to prevent claimers from acquiring yield at a discount that does not reflect the true cost. However, because `_getPhUSDPriceInUSDS()` reads the instantaneous `sqrtPriceX96` from `getSlot0()`, an attacker can atomically:

1. Swap sUSDS into the phUSD/sUSDS pool, pushing the phUSD spot price above `targetPrice`
2. Call `claim()`, which now passes the price check
3. Unwind the swap, restoring the pool price to its pre-manipulation level

All three steps execute within a single transaction, meaning the true market price of phUSD never needs to be above `targetPrice`. The attacker pays only swap fees on the round-trip, which are negligible compared to the discount earned on claimed yield.

The codebase itself contains `ClaimArbitrage.sol` ([lines 141-187](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L141-L187)), which implements exactly this pattern:

- **Step 1** (line 146): Pump phUSD price via swap with `pumpPriceLimit`
- **Step 3** (line 170): Call `sya.claim()` while price is pumped
- **Step 4** (line 179): Unwind the price pump

This contract is deployed as part of the protocol, confirming the attack vector is architecturally known to be feasible. The issue is that `ClaimArbitrage` is intended as a helper for legitimate MEV bots, but the same technique allows any attacker to bypass the `targetPrice` protection during genuine depegs when the check is meant to provide real protection.

### Impact

The `targetPrice` mechanism is the protocol's only defense against yield extraction during phUSD depegs. With this protection rendered ineffective:

- **During genuine phUSD depegs**, claimers can extract yield at the full discount rate even though phUSD is trading below its target. The claimer pays discounted USDC and receives full-value stablecoins from yield strategies, profiting from the spread plus the protocol discount.
- **Phlimbo stakers bear the loss** because the USDC payments they receive through Phlimbo are denominated at the discounted rate, while the actual value backing phUSD has decreased.
- **The severity scales with pending yield**: the more accumulated yield across strategies, the larger the extractable value during a depeg event.

This is not a hypothetical concern. Stablecoin depegs occur periodically (USDC in March 2023, UST in May 2022), and the `targetPrice` check exists specifically to handle these scenarios.

### Attack path

1. Wait for (or observe) a genuine phUSD depeg where the true market price drops below `targetPrice`
2. In a single transaction via a contract similar to `ClaimArbitrage`:
   - Swap sUSDS for phUSD in the phUSD/sUSDS pool to push the spot price above `targetPrice`
   - Call `claim()` on StableYieldAccumulator, which passes the manipulated price check
   - Receive discounted yield strategy tokens (USDT, USDS, etc.) in exchange for USDC at the discount rate
   - Unwind the price pump by swapping phUSD back to sUSDS
3. Convert received stablecoins to profit. The net cost is only the round-trip swap fees, while the gain is the full protocol discount applied to yield that should have been blocked from claiming.

## Recommended mitigation steps

Replace the instantaneous spot price read with a time-weighted average price (TWAP) oracle. Uniswap V4 supports observation-based TWAP through the Oracle hook pattern:

```solidity
function _getPhUSDPriceInUSDS() internal view returns (uint256) {
    // Use TWAP over a meaningful window (e.g., 30 minutes) instead of spot
    uint32 twapInterval = 1800; // 30 minutes
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = twapInterval;
    secondsAgos[1] = 0;

    // Query cumulative tick values from the oracle
    (int56[] memory tickCumulatives,) = oracle.observe(secondsAgos);

    // Calculate arithmetic mean tick
    int56 tickCumulativeDelta = tickCumulatives[1] - tickCumulatives[0];
    int24 arithmeticMeanTick = int24(tickCumulativeDelta / int56(int32(twapInterval)));

    // Convert tick to price
    uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(arithmeticMeanTick);
    // ... rest of price calculation
}
```

Alternatively, integrate an external oracle (e.g., Chainlink) for the phUSD/USD price feed, which is resistant to single-transaction manipulation.

If a TWAP-based approach is adopted, the observation window should be long enough that the cost of sustained price manipulation exceeds the profit from the discount (a 30-minute window is a reasonable starting point, but should be tuned based on pool liquidity depth).
