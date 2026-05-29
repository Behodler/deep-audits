<!--
C4 Submission Metadata
Title: [M-03] Sandwich attack on stake/withdraw enables MEV extraction through immediate emission rate updates
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L320-L354
PoC File: poc-M-03.t.sol
-->

## Finding description and impact

### Summary

The `stake()` and `withdraw()` functions in Phlimbo.sol immediately update the phUSD emission rate via `_updatePhUSDEmissionRate()` after modifying `totalStaked`. This creates a predictable MEV opportunity where attackers can front-run large deposits to capture disproportionate rewards.

### Vulnerability details

The vulnerable code pattern in [`Phlimbo.sol#L320-L354`](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L320-L354):

```solidity
function stake(uint256 amount, address recipient) external whenNotPaused {
    require(amount >= MINIMUM_STAKE, "Below minimum stake");

    if (recipient == address(0)) {
        recipient = msg.sender;
    }

    _updatePool();

    UserInfo storage user = userInfo[recipient];

    if (user.amount > 0) {
        _claimRewards(recipient);
    }

    IERC20(address(phUSD)).safeTransferFrom(msg.sender, address(this), amount);

    user.amount += amount;
    user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;
    user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

    // Update total staked
    totalStaked += amount;

    // VULNERABILITY: Emission rate updates immediately
    _updatePhUSDEmissionRate();

    emit Staked(recipient, amount);
}
```

The emission rate is calculated as:

```solidity
function _updatePhUSDEmissionRate() internal {
    if (totalStaked == 0) {
        phUSDPerSecond = 0;
        return;
    }
    phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;
}
```

The attack path is as follows:

1. MEV bot monitors mempool for large stake transactions
2. Bot front-runs with own stake, becoming a significant portion of total staked
3. Victim's large stake executes, increasing emission rate proportionally with new totalStaked
4. Bot accumulates rewards at disproportionately high share (pre-dilution ratio) while benefiting from increased emission rate
5. Bot back-runs to claim accumulated rewards and withdraw

The root cause is that when `totalStaked` increases, `phUSDPerSecond` increases proportionally. However, the pool update (`_updatePool()`) happens BEFORE the stake is added, so existing stakers already captured rewards at the old (higher per-share) rate. The attacker who front-runs captures the maximum share of the pool during the critical window before the victim's stake dilutes their position.

### Impact

MEV bots can extract significant value from users making large stakes. PoC results demonstrate:

- **Attacker effective APY**: 522,228 bps (5,222%) vs expected 800 bps (8%)
- The attacker captured rewards as 100% of the pool before victim's stake arrived
- The emission rate relationship is linear and predictable, enabling automated MEV extraction

This represents a ~65,000% return amplification over the expected APY. For a protocol targeting DeFi users, this vulnerability will discourage large deposits and erode user trust as sophisticated actors extract value from regular users.

The vulnerability is particularly severe because:
- Attack is completely risk-free for the attacker
- No capital is locked (can withdraw immediately after claiming)
- Attack can be automated with minimal effort
- Every large stake/withdraw is exploitabl e

### PoC

See standalone PoC at: `workspace/phoenix-phase-2-staging/test/poc-M-03.t.sol`

The PoC demonstrates three test cases:
- `test_M03_SandwichAttackOnStake`: Attacker earned 522,228 bps APY vs expected 800 bps
- `test_M03_EmissionRateManipulation`: Shows attacker captured rewards as 100% of pool before dilution
- `test_M03_RateIncreasesWithTotalStaked`: Confirms linear rate relationship enabling prediction

Run with:
```bash
forge test --match-test test_M03 -vvv
```

## Recommended mitigation steps

Implement a time-delayed or smoothed emission rate update mechanism to prevent immediate MEV extraction:

**Option 1: Time-weighted average (TWA) for emission rate changes**

```solidity
uint256 public emissionRateUpdateDelay = 1 hours;
uint256 public pendingPhUSDPerSecond;
uint256 public emissionRateUpdateTime;

function _updatePhUSDEmissionRate() internal {
    if (totalStaked == 0) {
        phUSDPerSecond = 0;
        pendingPhUSDPerSecond = 0;
        return;
    }

    // Apply any pending rate update that has matured
    if (pendingPhUSDPerSecond > 0 && block.timestamp >= emissionRateUpdateTime) {
        phUSDPerSecond = pendingPhUSDPerSecond;
        pendingPhUSDPerSecond = 0;
    }

    // Queue new rate update with delay
    uint256 newRate = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;
    if (newRate != phUSDPerSecond) {
        pendingPhUSDPerSecond = newRate;
        emissionRateUpdateTime = block.timestamp + emissionRateUpdateDelay;
    }
}
```

**Option 2: Per-block rate smoothing**

Calculate emission rate at the start of each block based on the previous block's `totalStaked`, preventing same-block sandwich attacks.

**Option 3: Commitment scheme**

Require users to commit to stake/withdraw in one transaction and execute in a subsequent block, breaking the atomic sandwich attack pattern.
