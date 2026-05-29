<!--
C4 Submission Metadata
Title: [M-03] Single-token threshold check prevents compounding when fees accumulate asymmetrically
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/UniswapV4Hooks/AutoCompoundPositionHook.sol#L289-L293
PoC File: workspace/stable-yield-accumulator/test/poc-M-03-threshold.t.sol
-->

## Finding description and impact

### Summary

The `_tryCompound()` function only checks ONE token's balance against the threshold, completely ignoring the other token's accumulated fees. When swap activity is directionally biased (e.g., consistently buying one token), fees accumulate asymmetrically, and the core auto-compound functionality fails despite significant fee accumulation.

### Vulnerability details

The vulnerable code in [AutoCompoundPositionHook.sol#L289-L293](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/UniswapV4Hooks/AutoCompoundPositionHook.sol#L289-L293):

```solidity
function _tryCompound() internal {
    // ...

    uint256 bal0 = _balanceOf(c0);
    uint256 bal1 = _balanceOf(c1);

    if (thresholdTokenIndex == 0) {
        if (bal0 < thresholdAmount) return;  // @audit Only checks token0, IGNORES token1!
    } else {
        if (bal1 < thresholdAmount) return;  // @audit Only checks token1, IGNORES token0!
    }

    // ... compounding logic ...
}
```

The problem:
1. Hook is configured with `thresholdTokenIndex = 0` and `thresholdAmount = 1000`
2. Market conditions cause most swaps to be in one direction (e.g., token0 -> token1)
3. Fees accumulate primarily in token1 (the output token for most swaps)
4. token0 balance remains low (100 units), token1 accumulates massively (50,000 units)
5. Every compound attempt fails because `bal0 (100) < thresholdAmount (1000)`
6. 50,000 token1 fees sit idle, never compounded

This is not an edge case - directional market bias is common in AMMs, especially during trending markets or when one token has higher demand.

### Impact

The core value proposition of the AutoCompoundPositionHook - automatically reinvesting collected fees - fails under realistic market conditions. The impact includes:

1. **Stuck fees**: Large amounts of one token accumulate without being compounded
2. **Lost yield**: Fees sitting idle generate no additional returns for liquidity providers
3. **Inefficient capital**: Protocol holds significant token balances that should be working as liquidity
4. **Permanent condition**: If market direction remains consistent, compounding may never trigger

The PoC demonstrates 50,000 tokens stuck waiting for a 900 token shortfall in the other token - a 55:1 ratio of stuck value to blocking shortfall.

### Proof of Concept

The PoC file at `workspace/stable-yield-accumulator/test/poc-M-03-threshold.t.sol` demonstrates:

```solidity
function test_M03_SingleTokenThresholdPreventsCompounding() public {
    // Setup: threshold = 1000 token0

    // Simulate directional swap fees
    hook.simulateSwapFees(100e18, 0);      // 100 token0 (below threshold)
    hook.simulateSwapFees(0, 50_000e18);   // 50,000 token1 (IGNORED!)

    (uint256 bal0, uint256 bal1) = hook.getBalances();
    // bal0 = 100, bal1 = 50,000

    // Check compounding status
    (bool blocked, string memory reason) = hook.isCompoundingBlocked();
    assertTrue(blocked, "Compounding should be blocked");
    // reason: "Token0 below threshold (token1 IGNORED despite balance)"

    // Attempt compound
    uint256 compoundCountBefore = hook.compoundCount();
    hook.poke();
    uint256 compoundCountAfter = hook.compoundCount();

    assertEq(compoundCountAfter, compoundCountBefore, "Compounding should NOT have occurred");

    // Result: 50,000 token1 stuck, blocked by 900 token0 shortfall
    uint256 valueWaiting = bal1;      // 50,000
    uint256 shortfall = 1000 - bal0;  // 900
    // Ratio: 55x value blocked by 1x shortfall
}
```

The test also includes `test_M03_ExtremeImbalanceCase()` showing 1,000,000 token1 blocked by a single-unit token0 shortfall.

## Recommended mitigation steps

Modify the threshold check to consider EITHER token exceeding the threshold, or check the combined USD value:

**Option 1: Check either token (simple fix)**
```solidity
// Compound if EITHER token exceeds threshold
if (bal0 < thresholdAmount && bal1 < thresholdAmount) return;
```

**Option 2: Check total value (more comprehensive)**
```solidity
// Convert both balances to a common denomination and check total
// Assumes tokens have similar value (reasonable for stablecoin pairs)
uint256 totalValue = bal0 + bal1;
if (totalValue < thresholdAmount * 2) return;  // Require threshold worth of total value
```

**Option 3: Separate thresholds for each token**
```solidity
uint256 public threshold0;
uint256 public threshold1;

// In _tryCompound:
if (bal0 < threshold0 && bal1 < threshold1) return;
```

Option 1 is the simplest and most backwards-compatible fix. It ensures that significant fee accumulation in either token triggers compounding, which aligns with the intended behavior of the auto-compound mechanism.
