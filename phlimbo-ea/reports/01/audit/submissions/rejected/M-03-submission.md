<!--
C4 Submission Metadata
Title: [M-03] Zero total staked state enables reward loss griefing
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L415-L418
PoC File: workspace/phlimbo-ea/test/poc-M-03.t.sol
-->

## Finding description and impact

### Summary

The `_updatePool()` function in Phlimbo.sol advances `lastRewardTime` when `totalStaked == 0` without distributing rewards. This causes rewards intended for zero-stake periods to become permanently undistributable, enabling griefing attacks where an attacker can intentionally create zero-stake states to waste protocol rewards.

### Vulnerability details

The vulnerable code at [Phlimbo.sol#L415-L418](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L415-L418):

```solidity
function _updatePool() internal {
    if (block.timestamp <= lastRewardTime) {
        return;
    }

    if (totalStaked == 0) {
        lastRewardTime = block.timestamp;  // @audit Time advances
        return;                             // @audit But no rewards distributed
    }

    // ... reward distribution logic only executes when totalStaked > 0
}
```

The linear depletion model calculates `rewardPerSecond` based on `rewardBalance / depletionDuration`. When `totalStaked == 0`:

1. `lastRewardTime` advances to the current timestamp
2. No rewards are distributed to `accStablePerShare`
3. When stakers return, rewards for the zero-stake period are effectively lost

The distribution window continues ticking, but the rewards that should have been distributed during zero-stake periods remain locked in the contract with no mechanism to recover them.

### Attack scenario

A malicious actor can grief the protocol by:

1. Being the sole staker (or coordinating with all stakers)
2. Withdrawing all stake to create `totalStaked == 0`
3. Waiting while rewards accumulate but cannot be distributed
4. Re-staking after significant time has passed
5. Repeating to maximize reward waste

### Impact

**Demonstrated through PoC testing:**

| Scenario | Rewards Distributed | Rewards Lost |
|----------|---------------------|--------------|
| Continuous staking (7 days) | 999/1000 tokens (99.9%) | ~1 token |
| With 3-day zero-staked gap | 510/1000 tokens (51%) | ~490 tokens |

**Griefing attack results:**
- Attacker can cause 49-61% of intended rewards to remain undistributed
- Rewards become permanently stuck in the contract
- Protocol economics disrupted as rewards fail to reach intended stakers
- No admin function exists to recover stranded rewards

The severity is Medium because:
- Direct fund theft is not possible (rewards remain in contract)
- Protocol functionality is impaired (reward distribution mechanism fails)
- Economic value is leaked (rewards cannot reach intended recipients)
- Attack is low-cost (only requires gas for stake/unstake transactions)

## Recommended mitigation steps

Several mitigation approaches are viable:

### Option 1: Pause time advancement when unstaked

Do not advance `lastRewardTime` when `totalStaked == 0`. This preserves the reward distribution period:

```solidity
function _updatePool() internal {
    if (block.timestamp <= lastRewardTime) {
        return;
    }

    if (totalStaked == 0) {
        // Don't advance lastRewardTime - pause distribution period
        return;
    }

    // ... existing distribution logic
}
```

### Option 2: Accumulate missed rewards

Track rewards that would have been distributed during zero-stake periods and distribute them at a higher rate when stakers return:

```solidity
uint256 public missedRewards;

function _updatePool() internal {
    if (block.timestamp <= lastRewardTime) {
        return;
    }

    uint256 timeElapsed = block.timestamp - lastRewardTime;
    uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

    if (totalStaked == 0) {
        // Accumulate instead of losing
        missedRewards += potentialReward > rewardBalance ? rewardBalance : potentialReward;
        lastRewardTime = block.timestamp;
        return;
    }

    // Include missed rewards in distribution
    uint256 toDistribute = potentialReward + missedRewards;
    toDistribute = toDistribute > rewardBalance ? rewardBalance : toDistribute;
    missedRewards = 0;

    // ... existing distribution logic
}
```

### Option 3: Protocol-owned minimum stake

Maintain a minimum protocol-owned stake that cannot be withdrawn, preventing `totalStaked` from ever reaching zero:

```solidity
uint256 public constant PROTOCOL_MINIMUM_STAKE = 1e18; // 1 token

function initialize(...) external {
    // Protocol stakes minimum amount on initialization
    stakingToken.transferFrom(msg.sender, address(this), PROTOCOL_MINIMUM_STAKE);
    totalStaked = PROTOCOL_MINIMUM_STAKE;
}
```

Option 1 is recommended as it is the simplest fix with no additional gas costs or state variables.
