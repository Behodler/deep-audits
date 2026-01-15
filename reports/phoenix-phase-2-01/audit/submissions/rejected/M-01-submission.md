<!--
C4 Submission Metadata
Title: [M-01] EMA manipulation via claim timing allows attackers to inflate or suppress reward distribution rate
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L288-L311
PoC File: workspace/phoenix-phase-2/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

The `collectReward()` function in Phlimbo.sol calculates an instant reward rate that is inversely proportional to the time elapsed since the last claim. This design flaw allows attackers to manipulate the `smoothedStablePerSecond` rate by controlling claim timing, enabling them to inflate their share of rewards or suppress rewards for other stakers.

### Vulnerability details

The vulnerable code in `collectReward()` at [Phlimbo.sol#L288-L311](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L288-L311):

```solidity
// Calculate time delta since last claim
uint256 deltaTime = block.timestamp - lastClaimTimestamp;

// Calculate instant rate with 1e18 precision
uint256 instantRate = (amount * PRECISION) / deltaTime;

// Update smoothed rate using EMA formula
if (smoothedStablePerSecond == 0) {
    smoothedStablePerSecond = instantRate;
} else {
    uint256 alphaWeight = (alpha * instantRate) / PRECISION;
    uint256 historyWeight = ((PRECISION - alpha) * smoothedStablePerSecond) / PRECISION;
    smoothedStablePerSecond = alphaWeight + historyWeight;
}
```

The `instantRate` calculation divides the claimed amount by `deltaTime`, creating an inverse relationship:
- **Small `deltaTime` (rapid claims)**: Produces artificially HIGH `instantRate`
- **Large `deltaTime` (delayed claims)**: Produces artificially LOW `instantRate`

Since `collectReward()` can be triggered by anyone calling `claim()` on the StableYieldAccumulator, an attacker can:

1. **Rate Inflation Attack**:
   - Stake in Phlimbo before other users
   - Wait for yield to accumulate in StableYieldAccumulator
   - Trigger claim with minimal time gap (1 second)
   - The inflated `smoothedStablePerSecond` distributes rewards faster to early stakers
   - Later stakers receive a smaller share of the reward pool

2. **Rate Suppression Attack**:
   - Intentionally delay triggering claims
   - Large `deltaTime` produces low `instantRate`
   - Rewards distributed more slowly than intended
   - Can be used to grief other stakers or game reward timing

3. **Compounding Manipulation**:
   - Multiple rapid claims compound the inflation effect
   - With alpha=10%, five consecutive 1-second claims can inflate the rate by 7x compared to normal timing

### Impact

An attacker can manipulate the reward distribution mechanism to capture a disproportionate share of staking rewards. The PoC demonstrates:

- **5x rate manipulation** between 1-second and 10-second claim gaps
- **7x rate inflation** through multiple rapid claims
- **Rate suppression** by delaying claims, reducing rewards for legitimate stakers

This directly impacts the economic fairness of the protocol. Attackers with knowledge of this vulnerability can systematically extract more value than honest participants, undermining the intended reward distribution mechanism.

### PoC Results

Three test cases demonstrate the vulnerability:

| Test | Result |
|------|--------|
| `test_M01_EMAManipulationViaInfrequentClaims` | 5x rate manipulation (1s vs 10s gap) |
| `test_M01_EMASuppression` | Rate suppressed by delayed claims |
| `test_M01_EMACompoundingEffect` | 7x rate inflation via multiple rapid claims |

The PoC is located at: `workspace/phoenix-phase-2/test/poc-M-01.t.sol`

## Recommended mitigation steps

Replace the time-dependent instant rate calculation with a fixed-window or time-weighted approach that cannot be manipulated by claim timing.

**Option 1: Fixed-Period Rate Calculation**

Use a minimum time window for rate calculations:

```solidity
uint256 constant MIN_RATE_PERIOD = 1 hours;

function collectReward(uint256 amount) external {
    // ... existing checks ...

    uint256 deltaTime = block.timestamp - lastClaimTimestamp;

    // Use minimum period to prevent manipulation
    uint256 effectiveDeltaTime = deltaTime < MIN_RATE_PERIOD ? MIN_RATE_PERIOD : deltaTime;

    uint256 instantRate = (amount * PRECISION) / effectiveDeltaTime;

    // ... rest of function ...
}
```

**Option 2: Time-Weighted Average Rate**

Track cumulative rewards and time to calculate a manipulation-resistant average:

```solidity
uint256 public cumulativeRewards;
uint256 public cumulativeTime;

function collectReward(uint256 amount) external {
    // ... existing checks ...

    cumulativeRewards += amount;
    cumulativeTime += block.timestamp - lastClaimTimestamp;

    // Rate based on all-time average, resistant to timing manipulation
    uint256 averageRate = (cumulativeRewards * PRECISION) / cumulativeTime;

    // Blend with current rate using EMA
    smoothedStablePerSecond = (alpha * averageRate + (PRECISION - alpha) * smoothedStablePerSecond) / PRECISION;

    // ... rest of function ...
}
```

**Option 3: Rate Bounds**

Implement upper and lower bounds on the instant rate to limit manipulation impact:

```solidity
uint256 public constant MAX_RATE_MULTIPLIER = 2e18; // 2x max deviation
uint256 public constant MIN_RATE_MULTIPLIER = 5e17; // 0.5x min deviation

function collectReward(uint256 amount) external {
    // ... calculate instantRate ...

    if (smoothedStablePerSecond > 0) {
        uint256 maxRate = (smoothedStablePerSecond * MAX_RATE_MULTIPLIER) / PRECISION;
        uint256 minRate = (smoothedStablePerSecond * MIN_RATE_MULTIPLIER) / PRECISION;

        instantRate = instantRate > maxRate ? maxRate : instantRate;
        instantRate = instantRate < minRate ? minRate : instantRate;
    }

    // ... update EMA with bounded rate ...
}
```

The recommended approach is Option 1 (minimum time window) as it is the simplest to implement and directly addresses the root cause while maintaining the intended EMA smoothing behavior.
