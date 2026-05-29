<!--
C4 Submission Metadata
Title: [M-01] Inaccurate Position Value Estimation Allows Over-Withdrawal of Surplus
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L669-L686
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `_estimateTotalValue()` function in `UniV4StableYieldStrategy.sol` uses a hardcoded `liquidity * 2` formula to estimate position value. This simplistic calculation is fundamentally inaccurate for Uniswap V4 concentrated liquidity positions, as the actual token composition varies significantly based on the current price relative to the tick range.

### Vulnerability details

The vulnerable function at [UniV4StableYieldStrategy.sol#L669-L686](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L669-L686):

```solidity
function _estimateTotalValue() internal view returns (uint256 totalValue) {
    if (liquidityPosition == 0) return 0;

    // For stable pools with 1:1 assumption, liquidity roughly equals value
    // Convert from 18 decimals to deposit token decimals
    uint256 liquidityIn18 = uint256(liquidityPosition);

    // Each unit of liquidity corresponds to ~2x value (deposit + paired)
    // So liquidity * 2 gives approximate total value in 18 decimals
    uint256 estimatedValue = liquidityIn18 * 2;

    // Convert to deposit token decimals
    if (depositTokenDecimals >= 18) {
        return estimatedValue * (10 ** (depositTokenDecimals - 18));
    } else {
        return estimatedValue / (10 ** (18 - depositTokenDecimals));
    }
}
```

The `liquidity * 2` formula makes three incorrect assumptions:

1. **50/50 token split**: Only true at the exact center price of the tick range
2. **No impermanent loss**: Concentrated liquidity positions experience amplified impermanent loss
3. **Price within range**: Does not account for out-of-range scenarios

In Uniswap V3/V4 concentrated liquidity, liquidity is a virtual measure representing the depth of the position, not the actual token amounts. The retrievable token amounts depend on:
- Current sqrtPrice
- Lower and upper tick bounds
- The liquidity value itself

As price moves away from the center of the tick range, the position's token composition shifts. At the lower tick boundary, the position becomes 100% token1; at the upper boundary, 100% token0. The actual value calculation requires:

```
amount0 = liquidity * (sqrtPriceUpper - sqrtPriceCurrent) / (sqrtPriceCurrent * sqrtPriceUpper)
amount1 = liquidity * (sqrtPriceCurrent - sqrtPriceLower)
```

This inaccurate estimation propagates to critical functions:

**`totalBalanceOf()` at line 347:**
```solidity
function totalBalanceOf(address token, address account) external view override returns (uint256) {
    // ...
    uint256 totalValue = _estimateTotalValue();  // Uses inaccurate 2x multiplier
    return (totalValue * principal) / totalDeposited;
}
```

**`_withdrawFrom()` at line 469:**
```solidity
function _withdrawFrom(address token, address client, uint256 amount, address recipient) internal override {
    // ...
    uint256 totalBalance = this.totalBalanceOf(token, client);  // Inaccurate
    uint256 surplus = totalBalance > principal ? totalBalance - principal : 0;  // Overstated

    require(amount <= surplus, "...");  // Allows over-withdrawal
}
```

### Impact

The inaccurate position valuation has three concrete impacts:

1. **Surplus Over-Withdrawal**: When the estimated value exceeds actual value (common when price moves from center), users can withdraw more surplus than actually exists. The PoC demonstrates a 2.1% overestimate at 0.5% price movement and 5.3% at extreme movements.

2. **Protocol Value Leakage**: Users withdrawing inflated surplus amounts effectively extract value from other depositors' principal, as the position cannot support the claimed withdrawals.

3. **Incorrect Migration Calculations**: The `_emergencyWithdraw()` function also uses `_estimateTotalValue()`, causing migration loss calculations to be inaccurate.

For a stable pool with $1M in deposits, a 5% valuation error translates to $50,000 in potential over-withdrawal, distributed as losses across remaining depositors.

## Recommended mitigation steps

Replace the `liquidity * 2` estimation with accurate Uniswap V4 position valuation. Two approaches:

**Option 1: Query actual token amounts from the pool**

```solidity
function _estimateTotalValue() internal view returns (uint256 totalValue) {
    if (liquidityPosition == 0) return 0;

    // Get current sqrt price from pool
    (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

    // Calculate tick boundaries
    uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(tickLower);
    uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(tickUpper);

    // Calculate actual token amounts using Uniswap math
    (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
        sqrtPriceX96,
        sqrtPriceLower,
        sqrtPriceUpper,
        liquidityPosition
    );

    // Value in deposit token terms (accounting for price if needed)
    return _valueInDepositToken(amount0, amount1);
}
```

**Option 2: Simulate removal to get real amounts**

```solidity
function _estimateTotalValue() internal view returns (uint256 totalValue) {
    if (liquidityPosition == 0) return 0;

    // Use staticcall to simulate removeLiquidity without executing
    (uint256 depositOut, uint256 pairedOut) = _simulateRemoveLiquidity(liquidityPosition);

    // Convert paired token to deposit token value using oracle or pool price
    uint256 pairedValue = _convertToDepositToken(pairedOut);

    return depositOut + pairedValue;
}
```

Either approach ensures the position value reflects actual retrievable amounts rather than a static multiplier that diverges from reality as price moves.
