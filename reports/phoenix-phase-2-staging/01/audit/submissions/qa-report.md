# QA Report for Phoenix Phase 2

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 |
| Centralization Risk | 1 |
| **Total** | **5** |

---

## Low Risk Findings

### [L-01] pendingStable() View Function Inconsistency

**Severity**: Low

**Location**: [Phlimbo.sol#L528-L548](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L528-L548)

**Description**: The `pendingStable()` view function does not handle the case where `rewardToken == phUSD` in the same way as `_updatePool()` does. This leads to inconsistent values being returned to external callers and UI integrations.

**Impact**: UI and integrations show incorrect pending reward amounts when `rewardToken` equals `phUSD`. This causes user confusion but does not affect actual reward distribution.

**Recommendation**: Update `pendingStable()` to match the logic in `_updatePool()` for handling the `rewardToken == phUSD` case.

```solidity
function pendingStable(address _user) external view returns (uint256) {
    // Add handling for rewardToken == phUSD case to match _updatePool() logic
    if (rewardToken == phUSD) {
        // Handle phUSD reward token case
    }
    // ... rest of calculation
}
```

---

### [L-02] Decimal Handling Edge Cases

**Severity**: Low

**Location**: [StableYieldAccumulator.sol#L495-L500](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L495-L500)

**Description**: Tokens with more than 18 decimals are not validated at registration time. While uncommon, such tokens could cause unexpected behavior or overflow issues in decimal scaling calculations.

**Impact**: Configuration error potential. If a >18 decimal token is registered, calculations could overflow or produce incorrect results.

**Recommendation**: Add validation in token registration to reject tokens with decimals > 18, or implement proper handling for high-decimal tokens.

```solidity
function registerToken(address token) external onlyOwner {
    uint8 decimals = IERC20Metadata(token).decimals();
    require(decimals <= 18, "Token decimals must be <= 18");
    // ... rest of registration logic
}
```

---

### [L-03] First Depositor Attack (Mitigated)

**Severity**: Low

**Location**: [Phlimbo.sol#L79-L80](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol#L79-L80)

**Description**: The classic first depositor attack pattern exists where an attacker could donate tokens directly to the contract to manipulate share calculations. However, this is mitigated by the `MINIMUM_STAKE` constant of 1e15 (0.001 tokens), which makes the attack economically infeasible.

**Attack Path**:
1. Deposit minimum stake as first depositor
2. Donate large amount directly to contract
3. Wait for second depositor
4. Second depositor receives fewer shares than expected

**Impact**: Minimal due to mitigation. The `MINIMUM_STAKE` requirement makes the cost of attack significantly higher than potential gains.

**Recommendation**: The current `MINIMUM_STAKE` mitigation is effective. Consider documenting this protection in code comments for future maintainability.

```solidity
/// @notice Minimum stake required to prevent first depositor attacks
/// @dev Set to 1e15 (0.001 tokens) to make donation attacks economically infeasible
uint256 public constant MINIMUM_STAKE = 1e15;
```

---

### [L-04] Unbounded Loop in Strategy Iteration

**Severity**: Low

**Location**: [Pauser.sol#L64-L83](https://github.com/Behodler/pauser/blob/main/src/Pauser.sol#L64-L83)

**Description**: The `pauseAll()` function iterates over all registered pausable contracts without an upper bound. If too many contracts are registered, the function could exceed block gas limits and become uncallable.

**Impact**: Potential DoS in emergency situations. If the contract list grows too large, the pause functionality could fail when most needed.

**Recommendation**: Implement a maximum limit on pausable contracts, or add a batch pause function that accepts start/end indices for partial pausing.

```solidity
uint256 public constant MAX_PAUSABLE_CONTRACTS = 100;

function addPausable(address _contract) external onlyOwner {
    require(pausableContracts.length < MAX_PAUSABLE_CONTRACTS, "Max contracts reached");
    pausableContracts.push(_contract);
}

// Alternative: batch pause function
function pauseBatch(uint256 start, uint256 end) external onlyPauser {
    require(end <= pausableContracts.length, "Invalid range");
    for (uint256 i = start; i < end; i++) {
        IPausable(pausableContracts[i]).pause();
    }
}
```

---

## Centralization Risks

### [C-01] Owner/Admin Centralization Risks

**Severity**: Centralization Risk

**Location**: Multiple contracts
- [Phlimbo.sol](https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol)
- [StableYieldAccumulator.sol](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol)
- [Pauser.sol](https://github.com/Behodler/pauser/blob/main/src/Pauser.sol)

**Description**: Multiple centralization risks exist across the protocol:

1. `emergencyTransfer()` allows owner to drain all funds from contracts
2. Pauser address can be set to zero, disabling emergency pause functionality
3. Exchange rates are entirely owner-controlled without bounds or timelocks
4. No multi-sig or timelock requirements for critical admin functions

**Impact**: A compromised or malicious owner can:
- Drain all protocol funds via `emergencyTransfer()`
- Disable pause mechanisms by setting pauser to zero address
- Manipulate exchange rates to extract value
- Make instant changes without user opportunity to exit

**Attack Path**:
1. Compromise owner private key
2. Call `emergencyTransfer()` to drain funds
3. Or: Set unfavorable exchange rates and front-run user transactions

**Recommendation**:
1. Require multi-sig for `emergencyTransfer()` with timelock
2. Prevent setting pauser to zero address
3. Add bounds and timelock for exchange rate changes
4. Consider governance mechanism for critical parameter changes

```solidity
// Example: Prevent zero address pauser
function setPauser(address _pauser) external onlyOwner {
    require(_pauser != address(0), "Cannot set zero address");
    pauser = _pauser;
}

// Example: Add timelock for exchange rate
uint256 public constant RATE_CHANGE_DELAY = 48 hours;
mapping(bytes32 => uint256) public pendingRateChanges;

function proposeRateChange(uint256 newRate) external onlyOwner {
    bytes32 key = keccak256(abi.encode(newRate));
    pendingRateChanges[key] = block.timestamp + RATE_CHANGE_DELAY;
    emit RateChangeProposed(newRate, block.timestamp + RATE_CHANGE_DELAY);
}

function executeRateChange(uint256 newRate) external onlyOwner {
    bytes32 key = keccak256(abi.encode(newRate));
    require(pendingRateChanges[key] != 0, "Not proposed");
    require(block.timestamp >= pendingRateChanges[key], "Timelock not expired");
    exchangeRate = newRate;
    delete pendingRateChanges[key];
    emit RateChangeExecuted(newRate);
}
```

---
