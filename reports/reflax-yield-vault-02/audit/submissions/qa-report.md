# QA Report for Phoenix Vault

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 |
| Centralization | 2 |
| **Total** | **6** |

---

## Low Risk Findings

### [L-01] `_withdrawFrom` Rounding Edge Cases May Report Zero Surplus

**Location**: [AutoDolaYieldStrategy.sol#L399-L406](https://github.com/code-423n4/reflax-yield-vault/blob/main/src/concreteYieldStrategies/AutoDolaYieldStrategy.sol#L399-L406)

**Description**: The surplus calculation in `_withdrawFrom()` computes available yield as `totalBalanceOf - principalOf`. Due to ERC4626 rounding behavior in `convertToAssets()`, this calculation may report zero surplus even when yield exists, particularly for small balances or when the share price has only marginally increased.

```solidity
// Get current balances
uint256 principal = clientBalances[token][client];
uint256 totalBalance = this.totalBalanceOf(token, client);

// Calculate available surplus (yield)
uint256 surplus = totalBalance > principal ? totalBalance - principal : 0;

// CRITICAL: withdrawFrom is ONLY for surplus extraction
require(amount <= surplus, "AutoDolaYieldStrategy: amount exceeds available surplus, use totalWithdrawal() for principal");
```

The `totalBalanceOf()` function uses `autoDolaVault.convertToAssets()` which rounds down per ERC4626 specification. When yield accumulation is small relative to the position size, rounding can cause `totalBalance` to equal or be less than `principal`, making the surplus appear as zero.

**Impact**: Minor denial of service for surplus withdrawal operations. The issue is self-correcting as more yield accrues and the rounding error becomes negligible relative to the actual surplus.

**Recommendation**: Add a small tolerance (e.g., 1 wei) in the surplus calculation to account for rounding errors, or document that minimum yield thresholds must be met before surplus can be withdrawn.

```solidity
// Allow 1 wei tolerance for ERC4626 rounding
uint256 surplus = totalBalance + 1 > principal ? totalBalance - principal : 0;
```

---

### [L-02] `clientDeposits` Mapping Not Cleared on Migration

**Location**: [AYieldStrategy.sol#L360-L377](https://github.com/code-423n4/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L360-L377)

**Description**: The `_executeWithdrawal()` function in the two-phase withdrawal process clears the withdrawal state and calls `_totalWithdraw()`, which in `AutoDolaYieldStrategy` resets `clientBalances[token][client]` to zero and decrements `totalDeposited`. However, if a migration pattern were to involve reusing the contract after `totalWithdrawal()`, stale `clientBalances` entries for other clients would remain.

In `AutoDolaYieldStrategy._totalWithdraw()`:
```solidity
// Update balances
clientBalances[token][client] = 0;
totalDeposited[token] -= clientStoredBalance;
```

Only the specific client's balance is cleared, not all client mappings.

**Impact**: Stale accounting data after migration could cause confusion if the contract is reused or if off-chain systems query historical balances. The `principalOf()` function would return outdated values for clients whose balances were not explicitly cleared.

**Recommendation**: Document that migration requires contract redeployment rather than contract reuse. Alternatively, add a `migrated` flag that causes `principalOf()` and `totalBalanceOf()` to return 0 for all accounts post-migration:

```solidity
bool public migrated;

function principalOf(address token, address account) external view override returns (uint256) {
    if (migrated) return 0;
    require(token == address(dolaToken), "AutoDolaYieldStrategy: only DOLA token supported");
    return clientBalances[token][account];
}
```

---

### [L-03] External Calls Before State Updates in `deposit()`

**Location**: [AutoDolaYieldStrategy.sol#L213-L217](https://github.com/code-423n4/reflax-yield-vault/blob/main/src/concreteYieldStrategies/AutoDolaYieldStrategy.sol#L213-L217)

**Description**: In the `deposit()` function, the external call to `mainRewarder.stake()` is made before updating the internal state variables `clientBalances` and `totalDeposited`:

```solidity
// Stake the autoDOLA shares in MainRewarder to earn TOKE rewards
mainRewarder.stake(address(this), sharesReceived);

// Update client balance and total deposited
clientBalances[token][recipient] += amount;
totalDeposited[token] += amount;
```

This violates the checks-effects-interactions pattern. If `mainRewarder` has callback capability (e.g., through ERC777 hooks or a malicious implementation), it could observe the contract in an inconsistent state where shares are staked but `clientBalances` has not yet been updated.

**Impact**: The `nonReentrant` modifier on `deposit()` prevents direct reentrancy exploitation. However, if `mainRewarder` calls back into a view function like `principalOf()` or `totalBalanceOf()`, it would see stale data. This could affect off-chain monitoring or integrations that rely on event-driven balance queries.

**Recommendation**: Follow the checks-effects-interactions pattern by updating state before making external calls:

```solidity
// Update client balance and total deposited BEFORE external call
clientBalances[token][recipient] += amount;
totalDeposited[token] += amount;

// Stake the autoDOLA shares in MainRewarder to earn TOKE rewards
mainRewarder.stake(address(this), sharesReceived);
```

---

### [L-04] Two-Phase Withdrawal Balance Caching May Orphan Yield

**Location**: [AYieldStrategy.sol#L333-L351](https://github.com/code-423n4/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L333-L351) and [AYieldStrategy.sol#L360-L377](https://github.com/code-423n4/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L360-L377)

**Description**: The two-phase withdrawal mechanism caches the client's balance at Phase 1 initiation and uses this cached value when executing Phase 2 (24-72 hours later):

Phase 1 - Balance cached:
```solidity
function _initiateWithdrawal(...) internal {
    // Get current balance
    uint256 balance = this.balanceOf(token, client);
    require(balance > 0, "AYieldStrategy: no balance to withdraw");

    // Initialize withdrawal state
    state.initiatedAt = currentTime;
    state.status = WithdrawalStatus.Initiated;
    state.balance = balance;  // <-- Balance cached here
    ...
}
```

Phase 2 - Cached balance used:
```solidity
function _executeWithdrawal(...) internal {
    uint256 withdrawAmount = state.balance;  // <-- Uses cached balance
    ...
    _totalWithdraw(token, client, withdrawAmount);
}
```

Any yield that accrues during the 24-hour waiting period between Phase 1 and Phase 2 is not included in the withdrawal amount. This yield becomes effectively orphaned in the contract.

**Impact**: Users performing total withdrawals will not receive yield accrued during the mandatory 24-hour waiting period. For large balances or high-yield periods, this could represent a meaningful amount of value left behind.

**Recommendation**: Consider one of the following approaches:

1. Re-read the balance at execution time and use the larger of cached or current balance:
```solidity
function _executeWithdrawal(...) internal {
    uint256 cachedAmount = state.balance;
    uint256 currentBalance = this.balanceOf(token, client);
    uint256 withdrawAmount = currentBalance > cachedAmount ? currentBalance : cachedAmount;
    ...
}
```

2. Document this behavior clearly so users understand yield accrued during the waiting period is forfeited.

3. Use a separate surplus withdrawal before initiating the total withdrawal to capture accrued yield.

---

## Centralization Risks

### [C-01] Owner Has Unrestricted Control Over Funds

**Location**: [AYieldStrategy.sol (all owner functions)](https://github.com/code-423n4/reflax-yield-vault/blob/main/src/AYieldStrategy.sol)

**Description**: The owner has complete control over the protocol through several privileged functions:

- `setClient()` - Add/remove authorized clients who can deposit/withdraw
- `setWithdrawer()` - Add/remove authorized withdrawers who can extract surplus
- `emergencyWithdraw()` - Withdraw any amount to owner address immediately
- `totalWithdrawal()` - Initiate fund migration (24-hour delay provides some protection)

While the two-phase withdrawal provides a 24-hour notice period for major fund movements, the `emergencyWithdraw()` function allows immediate extraction without any timelock.

**Impact**: Users must place complete trust in the owner. A compromised or malicious owner could:
- Remove all clients, preventing legitimate withdrawals
- Use `emergencyWithdraw()` to immediately drain funds
- Add malicious withdrawers who extract all surplus yield

**Recommendation**: Consider implementing a timelock for sensitive operations, particularly `emergencyWithdraw()`. A governance-controlled multisig for the owner role would also reduce single-point-of-failure risk.

---

### [C-02] Authorized Withdrawers Have Access to All Client Balances

**Location**: [AYieldStrategy.sol#L234-L253](https://github.com/code-423n4/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L234-L253)

**Description**: The `withdrawFrom()` function allows any authorized withdrawer to extract surplus from ANY client's balance without per-client restrictions:

```solidity
function withdrawFrom(
    address token,
    address client,
    uint256 amount,
    address recipient
) external onlyAuthorizedWithdrawer nonReentrant {
    // No check that withdrawer is authorized for THIS specific client
    ...
    _withdrawFrom(token, client, amount, recipient);
}
```

A single authorized withdrawer address has permission to withdraw surplus yield from all clients in the system.

**Impact**: A single compromised withdrawer key affects all users' surplus yield. While principal is protected (withdrawers cannot access principal), all accrued yield across the protocol becomes vulnerable if any withdrawer key is compromised.

**Recommendation**: Consider implementing per-client withdrawer authorization or requiring multisig approval for surplus withdrawals above a threshold:

```solidity
mapping(address => mapping(address => bool)) public clientWithdrawers;
// clientWithdrawers[client][withdrawer] = true/false

modifier onlyClientWithdrawer(address client) {
    require(
        clientWithdrawers[client][msg.sender] || authorizedWithdrawers[msg.sender],
        "Not authorized for this client"
    );
    _;
}
```

---
