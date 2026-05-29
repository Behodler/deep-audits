<!--
C4 Submission Metadata
Title: [M-02] ExactOut swaps completely bypass hook fee due to negative delta check
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/UniswapV4Hooks/AutoCompoundPositionHook.sol#L229-L256
PoC File: workspace/stable-yield-accumulator/test/poc-M-02-exactout-fee-bypass.t.sol
-->

## Finding description and impact

### Summary

The fee calculation logic in `_afterSwap` only charges fees when `taxableSigned > 0`. However, for exactOut swaps, the input delta is negative (representing tokens paid by the user), causing the condition to fail and resulting in zero fee collection on all exactOut swaps.

### Vulnerability details

The vulnerable code in [AutoCompoundPositionHook.sol#L229-L256](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/UniswapV4Hooks/AutoCompoundPositionHook.sol#L229-L256):

```solidity
function _afterSwap(
    address,
    PoolKey calldata key,
    SwapParams calldata params,
    BalanceDelta delta,
    bytes calldata
) internal override returns (bytes4, int128) {
    // ...

    if (taxBps != 0) {
        bool exactIn = (params.amountSpecified < 0);
        bool outputIsToken0 = !params.zeroForOne;
        Currency feeCurrency;
        int256 taxableSigned;

        if (exactIn) {
            feeCurrency = outputIsToken0 ? key.currency0 : key.currency1;
            taxableSigned = outputIsToken0 ? delta.amount0() : delta.amount1();  // Output is POSITIVE
        } else {
            bool inputIsToken0 = params.zeroForOne;
            feeCurrency = inputIsToken0 ? key.currency0 : key.currency1;
            taxableSigned = inputIsToken0 ? delta.amount0() : delta.amount1();  // @audit Input is NEGATIVE!
        }

        if (taxableSigned > 0) {  // @audit This check FAILS for exactOut swaps!
            uint256 taxable = uint256(taxableSigned);
            feeAmount = (taxable * taxBps) / 10_000;
            // ...
        }
    }
    // ...
}
```

The issue stems from how Uniswap V4 represents balance deltas:
- **ExactIn swap**: User specifies input amount. `amountSpecified < 0` (negative). The output delta is positive.
- **ExactOut swap**: User specifies output amount. `amountSpecified > 0` (positive). The input delta is negative.

For exactOut swaps:
1. `exactIn = false` (since `amountSpecified > 0`)
2. Code takes the branch for exactOut and selects the input token's delta
3. Input delta is NEGATIVE (user pays tokens to the pool)
4. `taxableSigned > 0` evaluates to FALSE
5. No fee is charged

### Impact

Complete bypass of the 0.05% hook fee on all exactOut swaps. Users or arbitrage bots aware of this bug can simply use exactOut swaps instead of exactIn swaps to avoid paying the hook fee entirely.

With significant trading volume, this represents substantial lost revenue:
- For $1M daily volume: Expected fee = $500/day, Actual = $0 if all exactOut
- Annual loss potential: $182,500 in fees that should have been collected

The fees were intended to be compounded into the hook's liquidity position to benefit protocol users. This bug means the auto-compound mechanism receives no funding from a significant portion of swap volume.

### Proof of Concept

The PoC file at `workspace/stable-yield-accumulator/test/poc-M-02-exactout-fee-bypass.t.sol` demonstrates:

```solidity
function test_M02_ExactOutSwapsBypassHookFees() public {
    // ExactIn swap: amountSpecified = -100 ether (negative = exactIn)
    SwapParams memory exactInParams = SwapParams({
        zeroForOne: true,
        amountSpecified: -100 ether,
        sqrtPriceLimitX96: 0
    });

    // Delta: user pays 100 token0 (negative), receives 99 token1 (positive)
    BalanceDelta exactInDelta = BalanceDeltaLibrary.toBalanceDelta(-100 ether, 99 ether);

    uint256 exactInFee = vulnerable.calculateFee(exactInParams, exactInDelta);
    // exactInFee = 0.00495 ether (correct - fee on output)

    // ExactOut swap: amountSpecified = +99 ether (positive = exactOut)
    SwapParams memory exactOutParams = SwapParams({
        zeroForOne: true,
        amountSpecified: 99 ether,
        sqrtPriceLimitX96: 0
    });

    // Delta: SAME deltas - user pays 100 token0, receives 99 token1
    BalanceDelta exactOutDelta = BalanceDeltaLibrary.toBalanceDelta(-100 ether, 99 ether);

    uint256 exactOutFee = vulnerable.calculateFee(exactOutParams, exactOutDelta);
    // exactOutFee = 0 (BUG - should charge fee on input!)

    assertGt(exactInFee, 0, "ExactIn should charge fee");
    assertEq(exactOutFee, 0, "ExactOut charges NO fee (bug!)");
}
```

The test confirms that for economically equivalent trades, exactIn charges the expected fee while exactOut charges nothing.

## Recommended mitigation steps

Use the absolute value of the taxable amount instead of checking if it's positive:

```solidity
if (taxBps != 0) {
    bool exactIn = (params.amountSpecified < 0);
    bool outputIsToken0 = !params.zeroForOne;
    Currency feeCurrency;
    int256 taxableSigned;

    if (exactIn) {
        feeCurrency = outputIsToken0 ? key.currency0 : key.currency1;
        taxableSigned = outputIsToken0 ? delta.amount0() : delta.amount1();
    } else {
        bool inputIsToken0 = params.zeroForOne;
        feeCurrency = inputIsToken0 ? key.currency0 : key.currency1;
        taxableSigned = inputIsToken0 ? delta.amount0() : delta.amount1();
    }

    // FIX: Use absolute value for fee calculation
    uint256 taxable;
    if (taxableSigned > 0) {
        taxable = uint256(taxableSigned);
    } else if (taxableSigned < 0) {
        taxable = uint256(-taxableSigned);  // Take absolute value for exactOut
    }

    if (taxable > 0) {
        feeAmount = (taxable * taxBps) / 10_000;
        if (feeAmount != 0) {
            poolManager.take(feeCurrency, address(this), feeAmount);
        }
    }
}
```
