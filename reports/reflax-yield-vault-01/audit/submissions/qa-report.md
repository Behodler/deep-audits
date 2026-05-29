# QA Report for Phoenix Vault

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 2 |
| **Total** | **2** |

---

## Low Risk Findings

### [L-01] MainRewarder.stake() Return Value Not Checked

**Location**: [AutoDolaYieldStrategy.sol#L213](https://github.com/code-423n4/phoenix-vault/blob/main/src/concreteYieldStrategies/AutoDolaYieldStrategy.sol#L213)

**Description**: In the `deposit()` function, the call to `mainRewarder.stake()` does not verify success. The `IMainRewarder.stake()` interface defines the function as returning `void`, but the actual Tokemak MainRewarder implementation may silently fail without reverting under certain edge conditions. Additionally, there is no balance verification after the staking operation to confirm the shares were actually staked.

```solidity
// Line 213 in deposit()
mainRewarder.stake(address(this), sharesReceived);

// No verification that staking succeeded
// clientBalances updated regardless of actual staking status
clientBalances[token][recipient] += amount;
totalDeposited[token] += amount;
```

**Impact**: If staking fails silently (e.g., due to paused rewarder, staking cap reached, or other edge conditions), the protocol's internal accounting will assume the funds are staked and earning TOKE rewards when they are not. This results in:
1. Users not earning expected TOKE rewards
2. Potential accounting discrepancies between tracked balances and actual staked amounts
3. The autoDOLA shares remain in the contract but unstaked, missing yield opportunities

**Recommendation**: Add balance verification after the `stake()` call to ensure the staking operation succeeded.

```solidity
// After staking autoDOLA shares
uint256 stakedBefore = mainRewarder.balanceOf(address(this));
mainRewarder.stake(address(this), sharesReceived);
uint256 stakedAfter = mainRewarder.balanceOf(address(this));

require(
    stakedAfter == stakedBefore + sharesReceived,
    "AutoDolaYieldStrategy: staking failed"
);
```

---

### [L-02] SurplusWithdrawer Configuration Stores Unused Vault Address

**Location**: [SurplusWithdrawer.sol#L62-L74](https://github.com/code-423n4/phoenix-vault/blob/main/src/SurplusWithdrawer.sol#L62-L74) and [SurplusWithdrawer.sol#L91-L122](https://github.com/code-423n4/phoenix-vault/blob/main/src/SurplusWithdrawer.sol#L91-L122)

**Description**: The `SurplusWithdrawer` contract stores both `vault` and `yieldStrategy` addresses in its configuration, but only `yieldStrategy` is actually used in the `withdrawSurplusPercent()` function. The `vault` address is stored, validated for non-zero, and emitted in events, but never used in any calculation or external call.

```solidity
// State variables - vault is stored but unused
address public vault;           // <-- Stored but never used in calculations
address public yieldStrategy;   // <-- Actually used for all operations

// In configure():
vault = _vault;                 // <-- Set but never read
yieldStrategy = _yieldStrategy;

// In withdrawSurplusPercent():
require(vault != address(0), "...");  // <-- Only check, not used
// ... all actual operations use yieldStrategy, not vault

// The vault is only mentioned in the event
emit SurplusWithdrawn(vault, token, client, percentage, withdrawAmount, recipient);
```

**Impact**:
1. **Confusing code**: Developers or auditors may assume the vault address serves a purpose, leading to incorrect assumptions about the contract's behavior
2. **Misconfiguration risk**: An admin might provide the wrong vault address thinking it affects functionality, when it only appears in event logs
3. **Wasted gas**: Storage slot is allocated and written to unnecessarily
4. **Misleading events**: The `SurplusWithdrawn` event includes `vault` as a parameter, which may confuse off-chain systems or indexers about which contract was actually interacted with

**Recommendation**: Either remove the unused `vault` storage variable entirely, or use it consistently in the calculations. If the vault address is intended for event logging or future use only, document this clearly in NatSpec comments.

Option A - Remove unused variable:
```solidity
// Remove vault from state variables
// address public vault;  // DELETE

function configure(address _token, address _yieldStrategy, address _client) external onlyOwner {
    // Remove vault parameter and validation
    require(_token != address(0), "...");
    require(_yieldStrategy != address(0), "...");
    require(_client != address(0), "...");

    token = _token;
    yieldStrategy = _yieldStrategy;
    client = _client;

    emit ConfigurationUpdated(_token, _yieldStrategy, _client);
}
```

Option B - Document the purpose if intentionally unused:
```solidity
/// @notice The vault address (external ERC4626) - stored for event emission only
/// @dev Not used in calculations; all operations go through yieldStrategy adapter
address public vault;
```

---
