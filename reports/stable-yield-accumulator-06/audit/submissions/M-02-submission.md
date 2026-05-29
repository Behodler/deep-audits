<!--
C4 Submission Metadata
Title: [M-02] Positive residual deltas in _settleResidualDelta() are taken from PoolManager but stranded in ClaimArbitrage instead of contributing to caller profit
Severity: Medium
Root Cause: src/ClaimArbitrage.sol#L372-L378
PoC File: workspace/stable-yield-accumulator/test/poc-M-02.t.sol
-->

## Finding description and impact

### Lines of Code

[ClaimArbitrage.sol#L368-L378](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L368-L378)

### Summary

In `_settleResidualDelta()`, when a token has a positive delta (credit owed by PoolManager to the contract), the function calls `poolManager.take()` to convert the credit into real ERC-20 tokens -- but those tokens remain stranded in the ClaimArbitrage contract. They are never deposited back into PoolManager and swapped into the reward token, so they do not contribute to the caller's profit in Step 7. The value systematically leaks from arbitrage callers into the contract, where it can only be recovered via the owner's `rescueToken()` function.

### Vulnerability details

The `_settleResidualDelta()` function is called in Steps 6b and 6c to zero out any residual deltas for phUSD and sUSDS after the pump/unwind cycle:

```solidity
function _settleResidualDelta(address token) internal {
    int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token));
    if (d == 0) return;

    if (d > 0) {
        // Positive delta: the contract has a credit in PoolManager.
        // take() converts the credit into real tokens, zeroing the delta.
        // The tokens remain in the contract and can be used in subsequent
        // operations or rescued via rescueToken().
        poolManager.take(Currency.wrap(token), address(this), uint256(d));
        return; // @audit tokens stranded here -- never converted to profit
    }

    // Negative delta handling continues below...
```

For **negative** deltas (debt owed by the contract to PoolManager), the function correctly swaps via the appropriate pool to purchase the owed tokens and zero the debt. This cost is reflected in the delta accounting and ultimately deducted from profit.

For **positive** deltas (credit owed by PoolManager to the contract), the function calls `take()` to withdraw real tokens, then immediately returns. The critical problem is that these tokens sit in the ClaimArbitrage contract as an ERC-20 balance but are not:

1. Deposited back into PoolManager (via `_depositIntoPM()`)
2. Swapped to the reward token to contribute to the net reward-token delta
3. Included in the Step 7 profit conversion to WETH

The tokens taken at line 377 bypass the entire profit pipeline (Steps 7-9) because `take()` zeroes the PoolManager delta for that token, meaning Step 7's `currencyDelta` query for the reward token never sees this value.

Positive residual deltas arise naturally from AMM mechanics. The pump (Step 1) sells sUSDS for phUSD, and the unwind (Step 4) sells the same amount of phUSD back. Due to price impact asymmetry and tick-level rounding in Uniswap V4 concentrated liquidity pools, the round-trip frequently produces a small net positive delta in sUSDS (the unwind returns slightly more sUSDS than the pump consumed) or a small positive phUSD residual. The Step 6 coverage swap (`if (sUSDSDelta < 0)`) only handles negative sUSDS deltas, leaving positive ones for `_settleResidualDelta()` to process.

### Impact

Each `execute()` call where the pump/unwind cycle produces a positive residual delta loses that value. While individual residuals may be small (fractions of a token per execution), the impact compounds:

- **Systematic value leakage**: Every execution with a favorable unwind leaks value. MEV bots executing hundreds of claims will lose a non-trivial cumulative amount.
- **Reduced economic incentive**: Lower profitability for arbitrage callers means fewer bots compete to call `execute()`, which slows yield distribution to Phlimbo and ultimately to stakers.
- **Owner dependency for recovery**: Stranded tokens require the owner to manually call `rescueToken()` -- a centralized recovery path that may not be exercised frequently or at all.
- **Asymmetric cost accounting**: Negative residuals (costs) are correctly deducted from profit, but positive residuals (gains) are not credited. This creates a one-directional bias against the caller.

## Recommended mitigation steps

When `_settleResidualDelta()` encounters a positive delta, the taken tokens should be deposited back into PoolManager and swapped to the reward token so they contribute to the profit pipeline in Step 7.

```solidity
function _settleResidualDelta(address token) internal {
    int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token));
    if (d == 0) return;

    if (d > 0) {
        // Positive delta: convert credit to real tokens, then deposit back
        // into PoolManager and swap to reward token for profit contribution.
        poolManager.take(Currency.wrap(token), address(this), uint256(d));

        // Deposit the taken tokens back into PM (creates positive delta for this token)
        _depositIntoPM(token, uint256(d));

        // Swap to reward token so the value feeds into Step 7's profit conversion
        address rewardToken_ = sya.rewardToken();
        if (token != rewardToken_) {
            PoolKey memory pool = stableToRewardTokenPool[token];
            if (Currency.unwrap(pool.currency0) == address(0)
                && Currency.unwrap(pool.currency1) == address(0))
            {
                // Fallback: use phUSD_sUSDS_pool or sUSDS_USDC_pool
                if (token == sUSDS) {
                    pool = sUSDS_USDC_pool;
                } else if (token == phUSD) {
                    pool = phUSD_sUSDS_pool;
                } else {
                    revert UnsettledResidualForUnconfiguredToken(token);
                }
            }
            bool tokenIsToken0 = (Currency.unwrap(pool.currency0) == token);
            poolManager.swap(
                pool,
                SwapParams({
                    zeroForOne: tokenIsToken0,
                    amountSpecified: -int256(uint256(d)), // exact input
                    sqrtPriceLimitX96: tokenIsToken0
                        ? type(uint160).min + 1
                        : type(uint160).max - 1
                }),
                ""
            );
        }
        // If token == rewardToken_, the deposit alone creates the correct
        // positive delta -- no swap needed (same logic as Step 5's skip).
        return;
    }

    // Negative delta handling unchanged...
```

Alternatively, a simpler approach: skip the `take()` entirely for positive deltas and instead directly swap the PoolManager credit to the reward token in a single swap, since Uniswap V4's delta accounting allows swapping credits without materializing them as real tokens first.
