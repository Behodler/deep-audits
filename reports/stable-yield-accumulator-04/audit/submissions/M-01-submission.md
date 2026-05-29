<!--
C4 Submission Metadata
Title: [M-01] Residual phUSD delta in _settleResidualDelta() causes permanent DoS of ClaimArbitrage.execute()
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L349-L383
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `_settleResidualDelta()` function in `ClaimArbitrage.sol` silently returns without settling when called with phUSD, because phUSD has no configured `stableToUSDCPool` entry and is not `sUSDS`. This leaves a non-zero phUSD delta after the pump/unwind cycle, causing the Uniswap V4 PoolManager to revert the entire `execute()` transaction since all currency deltas must be zero when the `unlock` callback returns.

### Vulnerability details

After the pump (Step 1) buys phUSD and the unwind (Step 4) sells it back, AMM fee asymmetry or price limit partial fills commonly produce a small residual phUSD delta. At line 273, `_settleResidualDelta(phUSD)` is called to handle this residual:

```solidity
// Line 273
_settleResidualDelta(phUSD);
```

The function at [ClaimArbitrage.sol#L349-L383](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L349-L383):

```solidity
function _settleResidualDelta(address token) internal {
    int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token));
    if (d >= 0) return; // <-- positive residuals are silently dropped

    PoolKey memory pool = stableToUSDCPool[token];
    if (Currency.unwrap(pool.currency0) == address(0) && Currency.unwrap(pool.currency1) == address(0)) {
        if (token == sUSDS) {
            pool = sUSDS_USDC_pool; // sUSDS has a fallback
        } else {
            // phUSD hits this path and silently returns
            return; // <-- LINE 364: the root cause
        }
    }

    // ... settling logic never reached for phUSD
}
```

The function fails to settle the phUSD delta through two independent code paths:

1. **Positive residual (d >= 0)**: The guard at line 351 returns immediately. The pump receives X phUSD and the unwind sells X phUSD as exact-input, but a price limit hit causes partial fill, leaving a positive phUSD delta.

2. **Negative residual (d < 0)**: The function enters the settling logic but finds no configured `stableToUSDCPool[phUSD]` (both currencies are `address(0)`). Since `phUSD != sUSDS`, it hits the silent `return` at line 364.

In both cases, the unsettled phUSD delta causes PoolManager's zero-delta invariant check to revert the transaction with `CurrencyNotSettled()`.

### Attack path

1. Any user calls `ClaimArbitrage.execute()` with valid parameters
2. Step 1 (pump): swap sUSDS -> phUSD, producing `pumpDelta`
3. Step 4 (unwind): sell back the phUSD received from pump
4. Due to AMM fee asymmetry or price limit partial fill, a small residual phUSD delta remains (positive or negative)
5. Line 273: `_settleResidualDelta(phUSD)` is called
6. `stableToUSDCPool[phUSD]` has zero-address currencies (not configured -- phUSD is the protocol's synthetic token, not a standard stablecoin with a USDC conversion pool)
7. `phUSD != sUSDS`, so the function silently returns at line 364
8. PoolManager detects nonzero delta and reverts with `CurrencyNotSettled()`

### Impact

`ClaimArbitrage.execute()` is permanently DoSed whenever the pump/unwind cycle produces any phUSD residual. Since the pump buys phUSD with exact-input sUSDS and the unwind sells exact-input phUSD back through the same pool, tick rounding, fee asymmetry, and price limit partial fills are expected to produce small residuals under normal operating conditions. This blocks the entire yield distribution mechanism through ClaimArbitrage.

The silent `return` at line 364 further masks the root cause, making the revert appear to come from PoolManager's generic delta enforcement rather than the missing phUSD settlement logic.

## Recommended mitigation steps

Add explicit handling for phUSD in `_settleResidualDelta()`. There are several options:

### Option A: Configure a phUSD/USDC pool (minimal code change)

Register `stableToUSDCPool[phUSD]` during deployment or via the existing `setStableToUSDCPool()` admin function, pointing to a phUSD/USDC Uniswap V4 pool. This allows the existing swap logic in `_settleResidualDelta` to settle the residual by buying phUSD with USDC:

```solidity
// During initialization or via owner call:
arb.setStableToUSDCPool(phUSD, phUSD_USDC_poolKey);
```

### Option B: Add phUSD as a named fallback (code change)

Add phUSD handling alongside the existing sUSDS fallback in `_settleResidualDelta`:

```solidity
if (Currency.unwrap(pool.currency0) == address(0) && Currency.unwrap(pool.currency1) == address(0)) {
    if (token == sUSDS) {
        pool = sUSDS_USDC_pool;
    } else if (token == phUSD) {
        // Settle via the phUSD/sUSDS pool, then settle the resulting sUSDS delta
        pool = phUSD_sUSDS_pool;
    } else {
        return;
    }
}
```

### Option C: Handle positive deltas too

The function currently only handles `d < 0` (negative delta). For completeness, positive residual deltas should also be settled by taking the excess tokens from the PoolManager and depositing them back:

```solidity
function _settleResidualDelta(address token) internal {
    int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token));
    if (d == 0) return;

    if (d > 0) {
        // Positive delta: take the excess tokens from PM to zero the delta
        poolManager.take(Currency.wrap(token), address(this), uint256(d));
        _depositIntoPM(token, uint256(d));
        return;
    }

    // ... existing negative delta handling with phUSD fix ...
}
```

At minimum, the silent `return` at line 364 should be replaced with a descriptive revert so the failure mode is immediately diagnosable:

```solidity
revert("ClaimArbitrage: unsettled residual for unconfigured token");
```
