<!--
C4 Submission Metadata
Title: [M-02] Residual phUSD delta silently dropped in _settleResidualDelta causes ClaimArbitrage DoS
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L335
PoC File: poc-M-02.t.sol
-->

## Finding description and impact

### Summary

`ClaimArbitrage._settleResidualDelta()` silently returns without settling when called with `phUSD` as the token and no `stableToUSDCPool[phUSD]` is configured. Because Uniswap V4's `PoolManager` enforces that all currency deltas must be zero when the `unlock` callback returns, any non-zero residual phUSD delta causes the entire `execute()` transaction to revert. This permanently prevents the atomic arbitrage from completing whenever the pump-then-unwind cycle leaves even 1 wei of residual phUSD debt.

### Root cause

The root cause is the unconditional `return` at [ClaimArbitrage.sol#L335](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L335), which exits the function without settling the negative delta and without reverting with a descriptive error:

```solidity
function _settleResidualDelta(address token) internal {
    int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token));
    if (d >= 0) return;

    PoolKey memory pool = stableToUSDCPool[token];
    if (Currency.unwrap(pool.currency0) == address(0) && Currency.unwrap(pool.currency1) == address(0)) {
        if (token == sUSDS) {
            pool = sUSDS_USDC_pool;  // sUSDS has a dedicated fallback
        } else {
            return;  // @audit BUG: silently returns without settling phUSD delta
        }
    }

    uint256 owed = uint256(-d);
    bool tokenIsToken0 = (Currency.unwrap(pool.currency0) == token);

    poolManager.swap(
        pool,
        SwapParams({
            zeroForOne: !tokenIsToken0,
            amountSpecified: int256(owed),
            sqrtPriceLimitX96: !tokenIsToken0
                ? type(uint160).min + 1
                : type(uint160).max - 1
        }),
        ""
    );
}
```

The function handles three cases when a negative delta exists:
1. **Token has a configured `stableToUSDCPool`** -- swaps to settle the delta (correct).
2. **Token is `sUSDS` with no configured pool** -- falls back to `sUSDS_USDC_pool` (correct).
3. **Token is anything else (including `phUSD`) with no configured pool** -- silently returns, leaving the delta unsettled (bug).

The inline comment on lines 333-334 acknowledges this gap: *"In practice, residual phUSD delta should be negligible after unwind."* However, this assumption is incorrect. The pump-then-unwind cycle in Steps 1 and 4 of `unlockCallback()` creates price impact asymmetry: selling X sUSDS to buy phUSD (pump) and then selling all acquired phUSD back (unwind) does not perfectly round-trip due to the constant-product AMM mechanics and fee accrual. The resulting residual delta, even if small in absolute terms, is non-zero.

### Vulnerability details

The `execute()` function triggers `poolManager.unlock()`, which calls `unlockCallback()`. Inside this callback, the 9-step atomic arbitrage proceeds as follows:

1. **Step 1 (line 145-154)**: Pump phUSD price by swapping sUSDS for phUSD in the `phUSD_sUSDS_pool`.
2. **Step 4 (line 177-187)**: Unwind by selling all acquired phUSD back for sUSDS in the same pool.
3. **Step 6 (line 224-241)**: Settle residual sUSDS delta via `sUSDS_USDC_pool` -- this works correctly because sUSDS has a dedicated fallback.
4. **Line 244**: Call `_settleResidualDelta(phUSD)` to settle any residual phUSD delta.

At line 244, if the pump/unwind left a negative phUSD delta (the contract owes phUSD back to the pool), `_settleResidualDelta` is expected to buy the missing phUSD. Instead, because `phUSD` is not `sUSDS` and `stableToUSDCPool[phUSD]` is not configured, the function returns silently at line 335. The negative delta persists.

When `unlockCallback()` returns to `PoolManager.unlock()`, the PoolManager's invariant check finds `currencyDelta(ClaimArbitrage, phUSD) != 0` and reverts the entire transaction.

The owner has no obvious reason to call `setStableToUSDCPool(phUSD, ...)` because phUSD is the protocol's own synthetic stablecoin, not an external stablecoin that needs a direct USDC conversion pool. The `stableToUSDCPool` mapping is conceptually for external stablecoins (USDT, DAI, etc.) received from `claim()`. This makes the misconfiguration a natural default state rather than an operator error.

### Impact

`ClaimArbitrage.execute()` reverts for every call where the pump/unwind cycle produces a non-zero residual phUSD delta. Given that constant-product AMM swaps with fees virtually always produce rounding residuals, this is the expected case rather than the exception.

The consequences are:
- **ClaimArbitrage is non-functional**: MEV bots cannot execute the atomic arbitrage, so no external actor can profitably trigger `claim()` on the `StableYieldAccumulator`.
- **Yield distribution is blocked**: Without `ClaimArbitrage`, pending yield strategy rewards are not converted and distributed through Phlimbo to Limbo stakers.
- **Silent failure masks the root cause**: The PoolManager reverts with a generic "currency delta is not zero" error. Because `_settleResidualDelta` returns silently rather than reverting with a descriptive error, diagnosing the root cause requires tracing through the delta accounting of every token -- a non-trivial debugging effort.

### Attack path

1. Owner deploys `ClaimArbitrage` without configuring `stableToUSDCPool[phUSD]` (reasonable default -- phUSD is not a standard external stablecoin).
2. MEV bot calls `execute()` with valid calibrated parameters.
3. Steps 1-4 execute: sUSDS is swapped for phUSD (pump), `claim()` captures discounted stablecoins, phUSD is sold back (unwind).
4. The unwind does not perfectly reverse the pump due to AMM price impact and fees, leaving a small negative phUSD delta (e.g., -100 wei).
5. `_settleResidualDelta(phUSD)` is called at line 244.
6. At line 328, `stableToUSDCPool[phUSD]` is unconfigured (both currencies are `address(0)`).
7. At line 330, `phUSD != sUSDS`, so the `else` branch executes.
8. At line 335, the function silently returns without settling the delta.
9. `PoolManager` detects the non-zero phUSD delta and reverts the entire transaction.
10. `execute()` is DoS'd for any scenario producing a residual phUSD delta.

## Recommended mitigation steps

Add a phUSD-specific fallback path that mirrors the existing sUSDS fallback. The `phUSD_sUSDS_pool` is already available as a contract storage variable and can be used to swap the residual phUSD delta through sUSDS as an intermediary, which is then settled via the `sUSDS_USDC_pool`:

```solidity
function _settleResidualDelta(address token) internal {
    int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token));
    if (d >= 0) return;

    PoolKey memory pool = stableToUSDCPool[token];
    if (Currency.unwrap(pool.currency0) == address(0) && Currency.unwrap(pool.currency1) == address(0)) {
        if (token == sUSDS) {
            pool = sUSDS_USDC_pool;
        } else if (token == phUSD) {
            // Settle phUSD via phUSD -> sUSDS -> USDC two-hop path
            uint256 owed = uint256(-d);
            bool phUSD_isToken0 = token0IsPhUSD;

            // Step 1: Buy phUSD with sUSDS via phUSD_sUSDS_pool
            poolManager.swap(
                phUSD_sUSDS_pool,
                SwapParams({
                    zeroForOne: !phUSD_isToken0,
                    amountSpecified: int256(owed),
                    sqrtPriceLimitX96: !phUSD_isToken0
                        ? type(uint160).min + 1
                        : type(uint160).max - 1
                }),
                ""
            );

            // Step 2: Settle the resulting sUSDS delta via sUSDS_USDC_pool
            _settleResidualDelta(sUSDS);
            return;
        } else {
            revert UnsettleableDelta(token);
        }
    }

    uint256 owed = uint256(-d);
    bool tokenIsToken0 = (Currency.unwrap(pool.currency0) == token);

    poolManager.swap(
        pool,
        SwapParams({
            zeroForOne: !tokenIsToken0,
            amountSpecified: int256(owed),
            sqrtPriceLimitX96: !tokenIsToken0
                ? type(uint160).min + 1
                : type(uint160).max - 1
        }),
        ""
    );
}
```

At minimum, the silent `return` at line 335 should be replaced with a descriptive revert so that the failure is immediately diagnosable:

```solidity
revert UnsettleableDelta(token);
```

This ensures that if the two-hop path is not implemented, the failure mode is explicit rather than masked by a generic PoolManager revert.
