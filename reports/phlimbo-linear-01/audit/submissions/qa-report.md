# QA Report: Phlimbo Linear Staking Contract

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 |
| Centralization Risk | 1 |
| **Total** | **5** |

---

## Low Risk Findings

### [L-01] Rate manipulation via stake/unstake timing around reward distributions

**Location**: [Phlimbo.sol#L316-L349](https://github.com/code-423n4/phlimbo-ea/blob/main/src/Phlimbo.sol#L316-L349) (`stake()`), [Phlimbo.sol#L355-L390](https://github.com/code-423n4/phlimbo-ea/blob/main/src/Phlimbo.sol#L355-L390) (`withdraw()`)

**Description**: Attackers can time their stake and unstake operations around reward distribution events (calls to `collectReward()`) to gain a marginal advantage over passive stakers. By monitoring the mempool for `collectReward()` transactions, an attacker can front-run with a stake, receive a disproportionate share of the newly deposited rewards, and withdraw shortly after.

This is a general MEV behavior pattern common in DeFi staking systems. While it does not constitute a direct loss of funds, it creates unfairness for passive stakers who consistently provide liquidity.

**Recommendation**: Consider implementing a time-weighted staking mechanism or a minimum lock period for newly staked tokens to reduce the effectiveness of just-in-time liquidity attacks.

```solidity
// Example: Add minimum stake duration
mapping(address => uint256) public stakeTimestamp;

function stake(uint256 amount, address recipient) external whenNotPaused {
    // ... existing logic ...
    stakeTimestamp[recipient] = block.timestamp;
}

function withdraw(uint256 amount) external whenNotPaused {
    require(block.timestamp >= stakeTimestamp[msg.sender] + MIN_STAKE_DURATION, "Stake too recent");
    // ... existing logic ...
}
```

---

### [L-02] Sandwich attack vulnerability on claim and withdraw operations

**Location**: [Phlimbo.sol#L355-L390](https://github.com/code-423n4/phlimbo-ea/blob/main/src/Phlimbo.sol#L355-L390) (`withdraw()`), [Phlimbo.sol#L395-L402](https://github.com/code-423n4/phlimbo-ea/blob/main/src/Phlimbo.sol#L395-L402) (`claim()`)

**Description**: User `claim()` and `withdraw()` transactions can be sandwiched by MEV extractors. An attacker can:
1. Front-run with a large stake to dilute the victim's pending rewards
2. Allow the victim's transaction to execute
3. Back-run with a withdraw to exit with profit

This is a standard blockchain MEV issue not specific to this contract, but users should be aware that their reward claims may be subject to value extraction.

**Recommendation**: Users can mitigate this by using private mempools (e.g., Flashbots Protect) for their transactions. The protocol could also consider implementing commit-reveal schemes for large claims or adding slippage protection parameters.

---

### [L-03] Division precision risk with very short depletion durations

**Location**: [Phlimbo.sol#L198-L211](https://github.com/code-423n4/phlimbo-ea/blob/main/src/Phlimbo.sol#L198-L211)

**Description**: While `setDepletionDuration()` validates that `_duration > 0`, setting extremely short durations (e.g., 1 second) could lead to unintended behavior:
1. Very high reward rates that could cause rounding issues
2. Rapid depletion of the reward balance in a single block
3. Potential gas griefing if rate recalculation happens frequently

```solidity
function setDepletionDuration(uint256 _duration) external onlyOwner {
    require(_duration > 0, "Duration must be > 0");  // Allows 1 second
    // ...
    rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;  // Line 208
}
```

**Recommendation**: Add a minimum duration requirement (e.g., 1 day) to prevent operational issues:

```solidity
uint256 public constant MINIMUM_DEPLETION_DURATION = 1 days;

function setDepletionDuration(uint256 _duration) external onlyOwner {
    require(_duration >= MINIMUM_DEPLETION_DURATION, "Duration below minimum");
    // ... rest of function
}
```

---

### [L-04] Missing zero-amount check in claim() allows wasteful transactions

**Location**: [Phlimbo.sol#L395-L402](https://github.com/code-423n4/phlimbo-ea/blob/main/src/Phlimbo.sol#L395-L402)

**Description**: The `claim()` function does not verify that the caller has a non-zero stake before executing. Users with no staked balance can call `claim()`, which will:
1. Execute `_updatePool()` (state changes, gas consumption)
2. Execute `_claimRewards()` which returns early but still costs gas
3. Update debt values (zero * anything = zero, but still writes to storage)

```solidity
function claim() external whenNotPaused {
    _updatePool();
    _claimRewards(msg.sender);

    UserInfo storage user = userInfo[msg.sender];
    user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;  // Writes 0
    user.stableDebt = (user.amount * accStablePerShare) / PRECISION;  // Writes 0
}
```

While `_claimRewards()` has an early return for zero amounts, the storage writes on lines 400-401 still occur.

**Recommendation**: Add an early validation check:

```solidity
function claim() external whenNotPaused {
    require(userInfo[msg.sender].amount > 0, "No stake");
    _updatePool();
    _claimRewards(msg.sender);
    // ...
}
```

---

## Centralization Risk Findings

### [C-01] Owner can change depletion duration without timelock, enabling front-running

**Location**: [Phlimbo.sol#L198-L211](https://github.com/code-423n4/phlimbo-ea/blob/main/src/Phlimbo.sol#L198-L211)

**Description**: The `setDepletionDuration()` function allows the owner to instantly change the reward distribution rate without any timelock or advance notice. This creates two concerns:

1. **Information asymmetry**: The owner (or anyone monitoring the owner's wallet) can front-run the rate change by adjusting their stake position before the new rate takes effect.

2. **User trust**: Stakers have no guaranteed notice period before reward rates change, which could affect their yield expectations.

```solidity
function setDepletionDuration(uint256 _duration) external onlyOwner {
    require(_duration > 0, "Duration must be > 0");
    _updatePool();
    uint256 oldDuration = depletionDuration;
    depletionDuration = _duration;
    rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
    emit DepletionDurationUpdated(oldDuration, _duration);
}
```

**Impact**: While the owner is presumably trusted, this pattern allows privileged parties to gain an advantage over regular stakers. Users cannot react to rate changes before they take effect.

**Recommendation**: Implement a timelock mechanism for depletion duration changes, similar to the two-step APY setting pattern already used for `setDesiredAPY()`:

```solidity
uint256 public pendingDepletionDuration;
uint256 public depletionDurationChangeTime;
uint256 public constant DEPLETION_TIMELOCK = 24 hours;

function proposeDepletionDuration(uint256 _duration) external onlyOwner {
    require(_duration >= MINIMUM_DEPLETION_DURATION, "Duration below minimum");
    pendingDepletionDuration = _duration;
    depletionDurationChangeTime = block.timestamp + DEPLETION_TIMELOCK;
    emit DepletionDurationProposed(_duration, depletionDurationChangeTime);
}

function executeDepletionDurationChange() external onlyOwner {
    require(block.timestamp >= depletionDurationChangeTime, "Timelock active");
    require(pendingDepletionDuration > 0, "No pending change");
    _updatePool();
    uint256 oldDuration = depletionDuration;
    depletionDuration = pendingDepletionDuration;
    rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
    pendingDepletionDuration = 0;
    emit DepletionDurationUpdated(oldDuration, depletionDuration);
}
```

---
