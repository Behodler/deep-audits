<!--
C4 Submission Metadata
Title: [M-01] Front-running collectReward() allows disproportionate reward capture
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L290-L307
PoC File: workspace/phlimbo-linear/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

The `collectReward()` function in Phlimbo.sol is susceptible to front-running attacks. When the yield accumulator calls `collectReward(amount)` to deposit new rewards, an attacker can sandwich this transaction to capture a disproportionate share of rewards relative to their staking duration.

### Vulnerability details

The vulnerable code is located at [Phlimbo.sol#L290-L307](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L290-L307).

The attack sequence proceeds as follows:

1. Attacker monitors the mempool for pending `collectReward()` transactions from the yield accumulator
2. Attacker front-runs with a `stake()` call, becoming a significant portion of `totalStaked`
3. The `collectReward()` transaction executes, updating `rewardPerSecond` based on the new reward balance
4. The new `rewardPerSecond` calculation now includes the attacker's stake in the denominator
5. Attacker waits a minimal period, then claims rewards and withdraws
6. Attacker captures rewards disproportionate to their actual staking commitment

The root cause is that newly deposited stakes immediately qualify for the updated reward rate without any time-weighted consideration. The linear depletion model calculates `rewardPerSecond = rewardBalance / depletionDuration`, and this rate applies equally to all stakers regardless of when they entered.

### Impact

**Reward dilution for legitimate stakers**: Long-term participants who provide sustained liquidity receive fewer rewards than expected due to last-minute entrants capturing their share.

**Systematic MEV extraction**: Sophisticated actors can programmatically monitor for `collectReward()` calls and execute this attack on every reward distribution event, extracting value continuously from the protocol.

**Protocol incentive misalignment**: The linear depletion model intends to reward sustained participation. This vulnerability allows short-term opportunistic staking to capture rewards meant for committed participants, undermining the protocol's economic design.

**Quantified impact from PoC**:
- Alice stakes 1000 phUSD and maintains her position for 3 days (73 hours of active staking during reward period)
- Bob front-runs a 10,000 token `collectReward()` by staking 1000 phUSD
- Bob stakes for only 1 hour before claiming and withdrawing
- Result: Bob earns 29 tokens, Alice earns only 72 tokens
- Bob's staking efficiency is approximately 30x Alice's rate (29 tokens/hour vs ~1 token/hour)

## Recommended mitigation steps

Several mitigation approaches can address this vulnerability:

### Option 1: Time-weighted staking (Recommended)

Implement a minimum stake duration before rewards begin accruing. New stakes should not immediately qualify for the current reward rate.

```solidity
struct StakeInfo {
    uint256 amount;
    uint256 stakedAt;
    uint256 rewardEligibleAt;
}

uint256 public constant REWARD_DELAY = 1 hours;

function stake(uint256 amount) external {
    // ... existing logic ...
    stakeInfo[msg.sender].stakedAt = block.timestamp;
    stakeInfo[msg.sender].rewardEligibleAt = block.timestamp + REWARD_DELAY;
}

function _calculateRewards(address user) internal view returns (uint256) {
    if (block.timestamp < stakeInfo[user].rewardEligibleAt) {
        return 0;
    }
    // ... existing reward calculation using rewardEligibleAt as start time ...
}
```

### Option 2: Commitment period for new reward batches

When `collectReward()` is called, record a snapshot. Stakes that entered after the previous snapshot should not receive rewards from the new batch until the next collection event.

```solidity
uint256 public lastCollectionTimestamp;

function collectReward(uint256 amount) external {
    // ... existing logic ...
    lastCollectionTimestamp = block.timestamp;
}

function _calculateRewards(address user) internal view returns (uint256) {
    // Only count time after user's stake was established before last collection
    uint256 effectiveStart = max(stakeInfo[user].stakedAt, lastCollectionTimestamp);
    // ... calculate rewards from effectiveStart ...
}
```

### Option 3: Snapshot-based distribution

Implement a checkpoint system where reward eligibility is determined at discrete intervals rather than continuously. This is more gas-intensive but provides the strongest guarantees against front-running.

The recommended approach is Option 1 with a reasonable delay period (1-24 hours depending on expected reward collection frequency), as it provides effective protection with minimal complexity and gas overhead.
