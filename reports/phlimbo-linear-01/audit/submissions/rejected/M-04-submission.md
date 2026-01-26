<!--
C4 Submission Metadata
Title: [M-04] Cumulative precision loss in rewardPerSecond recalculation
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L437
PoC File: workspace/phlimbo-linear/test/poc-M-04.t.sol
-->

## Finding description and impact

### Summary

The `_updatePool()` function in Phlimbo.sol recalculates `rewardPerSecond` on every call using integer division. Each division operation truncates the remainder, and over many operations these truncation errors accumulate, leaving reward tokens permanently stuck in the contract.

### Vulnerability details

The vulnerable code at [Phlimbo.sol#L437](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L437):

```solidity
rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
```

Integer division in Solidity truncates toward zero, discarding any remainder. While a single truncation may only lose a few wei, the problem compounds because:

1. Every stake, unstake, and reward collection triggers `_updatePool()`
2. Each call recalculates `rewardPerSecond` with a new truncation
3. The truncated amounts are never recovered or tracked
4. High-frequency operations dramatically accelerate dust accumulation

Consider a scenario with `depletionDuration = 604,800` (1 week in seconds):

- Any `rewardBalance` less than 604,800 wei results in `rewardPerSecond = 0`
- With `rewardBalance = 604,799 wei`, the calculation yields: `(604799 * 1e18) / 604800 = 999998...` which truncates
- After distribution, the remaining balance becomes undistributable

### Impact

**Guaranteed loss of rewards over time.** Testing demonstrates:

- After 1,000 stake/unstake cycles: approximately 100,615,332 wei stuck
- Any `rewardBalance < depletionDuration` becomes permanently undistributable
- `rewardPerSecond` effectively becomes 0 for small remaining balances
- Tokens remain locked in the contract with no mechanism for recovery or redistribution

The severity is Medium because:
- Loss is small per operation but guaranteed to occur
- Cumulative effect grows with protocol usage
- High-frequency operations (arbitrage bots, automated compounding) accelerate the issue
- Users collectively lose value to precision truncation over the protocol's lifetime
- No existing mechanism allows recovery of stuck dust

## Recommended mitigation steps

Several approaches can address this issue:

**Option 1: Track cumulative precision loss**

```solidity
uint256 public accumulatedDust;

function _updatePool() internal {
    // ... existing code ...

    uint256 newRewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
    uint256 truncationLoss = (rewardBalance * PRECISION) % depletionDuration;
    accumulatedDust += truncationLoss;

    // Add accumulated dust back when it exceeds threshold
    if (accumulatedDust >= depletionDuration) {
        newRewardPerSecond += accumulatedDust / depletionDuration;
        accumulatedDust = accumulatedDust % depletionDuration;
    }

    rewardPerSecond = newRewardPerSecond;
}
```

**Option 2: Implement minimum distribution threshold**

Only recalculate when the balance change exceeds a meaningful threshold, reducing the frequency of truncation operations.

**Option 3: Add admin dust recovery function**

```solidity
function sweepDust(address recipient) external onlyOwner {
    uint256 distributableBalance = (rewardPerSecond * depletionDuration) / PRECISION;
    uint256 dust = rewardBalance - distributableBalance;
    require(dust > 0, "No dust to sweep");

    rewardBalance -= dust;
    IERC20(rewardToken).transfer(recipient, dust);
}
```

**Option 4: Use higher precision fixed-point library**

Consider using a library like PRBMath or ABDK that provides higher precision arithmetic to minimize truncation effects.

The recommended approach is Option 1 combined with Option 3, providing both proactive dust accumulation handling and a fallback recovery mechanism.
