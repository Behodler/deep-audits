<!--
C4 Submission Metadata
Title: [M-04] ClaimArbitrage internal swaps use no slippage protection, enabling sandwich attacks
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L206-L216
PoC File: poc-M-04.t.sol
-->

## Finding description and impact

### Summary

Three of the five swap operations inside `ClaimArbitrage.unlockCallback()` pass `type(uint160).min + 1` or `type(uint160).max - 1` as `sqrtPriceLimitX96`, accepting any price the pool offers. The remaining two swaps (pump and unwind) correctly use caller-supplied price limits via `ExecuteParams`. This inconsistency leaves the stablecoin-to-USDC conversion (Step 5), the sUSDS coverage swap (Step 6), and the USDC-to-WETH profit conversion (Step 7) vulnerable to sandwich attacks that extract value from the arbitrageur's profit margin.

### Root cause

The root cause is at [ClaimArbitrage.sol#L206-L216](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L206-L216) (Step 5, stable-to-USDC conversion) and [ClaimArbitrage.sol#L255-L265](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L255-L265) (Step 7, USDC-to-WETH conversion):

```solidity
// Step 5 (lines 206-216): stable -> USDC conversion
poolManager.swap(
    pool,
    SwapParams({
        zeroForOne: stableIsToken0,
        amountSpecified: -int256(bal),
        sqrtPriceLimitX96: stableIsToken0
            ? type(uint160).min + 1   // accepts ANY price
            : type(uint160).max - 1   // accepts ANY price
    }),
    ""
);
```

```solidity
// Step 7 (lines 255-265): USDC -> WETH profit conversion
poolManager.swap(
    USDC_WETH_pool,
    SwapParams({
        zeroForOne: usdcIsToken0,
        amountSpecified: -int256(uint256(usdcProfit)),
        sqrtPriceLimitX96: usdcIsToken0
            ? type(uint160).min + 1   // accepts ANY price
            : type(uint160).max - 1   // accepts ANY price
    }),
    ""
);
```

The `ExecuteParams` struct only exposes two price limit fields:

```solidity
struct ExecuteParams {
    uint256 pumpAmount;
    uint256 usdcNeeded;
    uint160 pumpPriceLimit;      // Used in Step 1 -- PROTECTED
    uint160 unwindPriceLimit;    // Used in Step 4 -- PROTECTED
    // No fields for Steps 5, 6, or 7
}
```

The developer clearly understood the need for slippage protection -- Steps 1 and 4 both accept caller-supplied price bounds -- but did not extend this pattern to the conversion swaps. Because no corresponding fields exist in `ExecuteParams`, callers have no mechanism to supply price limits for Steps 5, 6, or 7.

### Vulnerability details

In Uniswap V4, `sqrtPriceLimitX96` constrains how far the pool price can move during a swap. The Uniswap V4 `TickMath` defines the valid price range as:

- `MIN_SQRT_PRICE = 4295128739`
- `MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342`

The values used in ClaimArbitrage are:

- `type(uint160).min + 1 = 1` (below `MIN_SQRT_PRICE`)
- `type(uint160).max - 1 = 1461501637330902918203684832716283019655932542974` (above `MAX_SQRT_PRICE`)

Both values fall outside Uniswap's valid price range, meaning the swap will complete regardless of how far the price moves. This is functionally equivalent to having no slippage protection at all.

The protection inconsistency across all five swaps:

| Step | Operation | sqrtPriceLimitX96 | Protected? |
|------|-----------|-------------------|------------|
| 1 | sUSDS -> phUSD (pump) | `p.pumpPriceLimit` | Yes |
| 4 | phUSD -> sUSDS (unwind) | `p.unwindPriceLimit` | Yes |
| 5 | stable -> USDC (conversion) | `type(uint160).min + 1` | **No** |
| 6 | USDC -> sUSDS (coverage) | `type(uint160).min + 1` | **No** |
| 7 | USDC -> WETH (profit) | `type(uint160).min + 1` | **No** |

A sandwich attacker can exploit this by:

1. Monitoring the mempool for `ClaimArbitrage.execute()` transactions
2. **Front-running**: swapping heavily in the stable/USDC or USDC/WETH pool to push the price unfavorably
3. The victim's conversion swap executes at the manipulated price because `sqrtPriceLimitX96` imposes no constraint
4. **Back-running**: reversing the price manipulation to capture the spread

This is distinct from simple front-running (which the auditor has noted is acceptable and unavoidable). Front-running alone merely competes to execute the same opportunity first. A sandwich attack is a coordinated front-run *plus* back-run that manipulates the execution price of the victim's transaction to extract value -- a qualitatively different and preventable attack vector.

### Impact

The sandwich attack extracts value directly from the arbitrageur's profit margin. The `NoProfit` check at line 252 prevents total loss (the transaction reverts if USDC profit goes to zero), but the attacker can calibrate the sandwich to reduce the arbitrageur's profit while still leaving enough for the `NoProfit` check to pass.

Concrete consequences:

- **Reduced effective discount rate**: The protocol's discount mechanism incentivizes external actors to perform the claim conversion. If MEV bots consistently extract from these transactions, the effective discount drops below the intended rate, reducing participation incentives.
- **Arbitrageur deterrence**: Rational arbitrageurs will factor in sandwich risk when calculating expected profit. If the expected sandwich cost exceeds the discount, legitimate bots will stop calling `execute()`, reducing the protocol's ability to convert yield.
- **Value leakage**: All value extracted by sandwich attackers comes from the spread that would otherwise remain as the arbitrageur's reward. For large claim amounts, even a small percentage sandwich extraction can be significant (e.g., 1% on a 500k stablecoin conversion = 5,000 USD extracted).

### Attack path

1. An arbitrage bot submits a `ClaimArbitrage.execute()` transaction with profitable parameters
2. A sandwich attacker observes the pending transaction in the mempool
3. **Front-run**: The attacker swaps a large amount into the stable/USDC pool, pushing the stable-to-USDC exchange rate unfavorably
4. The bot's Step 5 swap executes at the manipulated rate -- `sqrtPriceLimitX96 = type(uint160).min + 1` accepts the degraded price without reverting
5. **Back-run**: The attacker reverses the price manipulation, capturing the spread created by the bot's swap restoring the price
6. The bot receives less USDC than expected from the conversion; the `NoProfit` check may still pass if the sandwich is calibrated to leave residual profit
7. The same attack applies independently to Step 7 (USDC-to-WETH), compounding the extraction across multiple unprotected swaps

## Recommended mitigation steps

Extend the `ExecuteParams` struct to include price limit fields for all swap operations, following the existing pattern used for `pumpPriceLimit` and `unwindPriceLimit`:

```solidity
struct ExecuteParams {
    uint256 pumpAmount;
    uint256 usdcNeeded;
    uint160 pumpPriceLimit;
    uint160 unwindPriceLimit;
    uint160 stableConversionPriceLimit;  // NEW: for Step 5 (stable -> USDC)
    uint160 sUSDSCoveragePriceLimit;     // NEW: for Step 6 (USDC -> sUSDS)
    uint160 profitConversionPriceLimit;  // NEW: for Step 7 (USDC -> WETH)
}
```

Then replace the hardcoded extremes with the caller-supplied limits:

```solidity
// Step 5: stable -> USDC
poolManager.swap(
    pool,
    SwapParams({
        zeroForOne: stableIsToken0,
        amountSpecified: -int256(bal),
        sqrtPriceLimitX96: p.stableConversionPriceLimit
    }),
    ""
);
```

```solidity
// Step 7: USDC -> WETH
poolManager.swap(
    USDC_WETH_pool,
    SwapParams({
        zeroForOne: usdcIsToken0,
        amountSpecified: -int256(uint256(usdcProfit)),
        sqrtPriceLimitX96: p.profitConversionPriceLimit
    }),
    ""
);
```

This allows callers to compute appropriate price bounds off-chain based on current pool state and acceptable slippage tolerance, consistent with how the pump and unwind swaps already operate.
