<!--
C4 Submission Metadata
Title: [M-02] AutoDolaYieldStrategy._totalWithdraw ignores cached amount parameter, defeating two-phase withdrawal security guarantees
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/AutoDolaYieldStrategy.sol#L356-L357
PoC File: poc-M-02.t.sol
-->

## Finding description and impact

### Summary

The `_totalWithdraw` function in `AutoDolaYieldStrategy.sol` ignores its `amount` parameter and reads from current storage state (`clientBalances[token][client]`) instead. This defeats the security guarantees of the two-phase withdrawal mechanism, allowing more or fewer funds to be withdrawn than announced during the initiation phase.

### Vulnerability details

The two-phase withdrawal system is designed to provide transparency and protection against rugpulls by:
1. **Phase 1 (Initiation)**: Caching the client's balance at initiation time
2. **24-hour waiting period**: Allowing the community to observe and react
3. **Phase 2 (Execution)**: Withdrawing only the cached amount

In `AYieldStrategy.sol`, the parent contract correctly implements this pattern:

```solidity
// Phase 1: Cache balance at initiation (line 346)
state.balance = balance;

// Phase 2: Pass cached amount to implementation (line 366, 374)
uint256 withdrawAmount = state.balance;
_totalWithdraw(token, client, withdrawAmount);
```

However, `AutoDolaYieldStrategy._totalWithdraw()` ignores the passed `amount` parameter entirely:

```solidity
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(dolaToken), "AutoDolaYieldStrategy: only DOLA token supported");
    require(amount > 0, "AutoDolaYieldStrategy: amount must be greater than zero");

    uint256 totalShares = mainRewarder.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

    uint256 clientStoredBalance = clientBalances[token][client];  // BUG: Uses current state
    uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];
```

The `amount` parameter (the cached balance from initiation) is validated but never used. Instead, line 356 reads `clientStoredBalance` directly from current storage state.

### Attack scenarios

**Scenario 1: Balance increase during waiting period (more withdrawn than announced)**

1. Client has 1000 DOLA deposited
2. Owner calls `totalWithdrawal()` - Phase 1 caches `state.balance = 1000`
3. Event emits: "Withdrawal initiated for 1000 DOLA"
4. During 24-hour waiting period, client deposits 500 more DOLA
5. `clientBalances[token][client]` now equals 1500
6. After waiting period, owner executes Phase 2
7. `_totalWithdraw` is called with `amount = 1000` (cached)
8. But function reads `clientStoredBalance = 1500` (current)
9. **Result**: 1500 DOLA withdrawn instead of announced 1000 (50% more)

**Scenario 2: Balance decrease during waiting period (less withdrawn than expected)**

1. Client has 1000 DOLA deposited
2. Owner calls `totalWithdrawal()` - Phase 1 caches `state.balance = 1000`
3. Event emits: "Withdrawal initiated for 1000 DOLA"
4. During waiting period, authorized withdrawer extracts 400 DOLA surplus via `withdrawFrom()`
5. `clientBalances[token][client]` now equals 600
6. After waiting period, owner executes Phase 2
7. `_totalWithdraw` is called with `amount = 1000` (cached)
8. But function reads `clientStoredBalance = 600` (current)
9. **Result**: Only 600 DOLA withdrawn instead of announced 1000 (40% less)

### Impact

The two-phase withdrawal mechanism exists specifically to protect against covert fund extraction by providing transparency. This bug defeats that protection:

1. **Transparency violation**: The amount announced in `WithdrawalInitiated` events does not match the actual amount withdrawn
2. **Rugpull vector**: A malicious or compromised owner could coordinate deposits during the waiting period to extract more than announced, reducing the effectiveness of community monitoring
3. **Accounting inconsistency**: The `WithdrawalExecuted` event (emitted by parent contract) will show the cached amount, creating discrepancy with actual funds transferred
4. **Protocol trust erosion**: Users relying on the two-phase mechanism for protection cannot accurately predict withdrawal amounts

The severity is Medium because:
- Requires owner action (trusted role) to initiate withdrawals
- Balance changes during waiting period require either client deposits or authorized withdrawer actions
- Does not result in direct theft but undermines documented security mechanism

## Recommended mitigation steps

Modify `_totalWithdraw` to use the passed `amount` parameter instead of reading from current storage:

```solidity
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(dolaToken), "AutoDolaYieldStrategy: only DOLA token supported");
    require(amount > 0, "AutoDolaYieldStrategy: amount must be greater than zero");

    uint256 totalShares = mainRewarder.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

    // Use the cached amount parameter, not current storage
    uint256 clientStoredBalance = clientBalances[token][client];
    require(clientStoredBalance >= amount, "AutoDolaYieldStrategy: insufficient balance");

    uint256 sharesToWithdraw = (totalShares * amount) / totalDeposited[token];

    if (sharesToWithdraw > 0) {
        // Unstake from MainRewarder
        uint256 stakedShares = mainRewarder.balanceOf(address(this));
        if (stakedShares > 0) {
            uint256 toUnstake = sharesToWithdraw > stakedShares ? stakedShares : sharesToWithdraw;
            mainRewarder.withdraw(address(this), toUnstake, false);
        }

        // Redeem from autoDOLA vault
        uint256 assetsReceived = autoDolaVault.redeem(sharesToWithdraw, address(this), address(this));

        // Update balances using the passed amount
        clientBalances[token][client] = clientStoredBalance - amount;
        totalDeposited[token] -= amount;

        // Transfer to owner
        dolaToken.safeTransfer(owner(), assetsReceived);
    }
}
```

Additionally, consider adding a check in `_initiateWithdrawal` to prevent balance modifications during the waiting period by locking the client's deposit/withdrawal capabilities.
