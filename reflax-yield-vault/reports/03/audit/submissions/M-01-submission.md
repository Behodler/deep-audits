<!--
C4 Submission Metadata
Title: [M-01] Two-Phase totalWithdrawal Includes Deposits Made During Waiting Period
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L332-L356
PoC File: poc-M-01.t.sol
-->

## Finding description and impact

### Summary

The two-phase `totalWithdrawal` mechanism in `AYieldStrategy` is designed to protect users by imposing a 24-hour waiting period before the owner can execute an emergency fund migration. However, the concrete implementation in `ERC4626YieldStrategy._totalWithdraw()` ignores the cached `amount` parameter from Phase 1 and instead reads live `clientBalances` at execution time. Any deposits made during the waiting period are silently swept into the Phase 2 withdrawal without timelock protection.

### Vulnerability details

The `totalWithdrawal` flow spans two contracts:

**Phase 1 -- `AYieldStrategy._initiateWithdrawal()`** ([AYieldStrategy.sol#L379-L394](https://github.com/Behodler/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L379-L394)):

```solidity
function _initiateWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)
    internal
{
    uint256 balance = this.balanceOf(token, client); // @audit caches current principal
    require(balance > 0, "AYieldStrategy: no balance to withdraw");

    state.initiatedAt = currentTime;
    state.status = WithdrawalStatus.Initiated;
    state.balance = balance; // @audit stored for Phase 2
    ...
}
```

**Phase 2 -- `AYieldStrategy._executeWithdrawal()`** ([AYieldStrategy.sol#L403-L417](https://github.com/Behodler/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L403-L417)):

```solidity
function _executeWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)
    internal
{
    uint256 withdrawAmount = state.balance; // @audit reads cached value (1000e18)

    state.status = WithdrawalStatus.None;
    state.initiatedAt = 0;
    state.balance = 0;

    _totalWithdraw(token, client, withdrawAmount); // @audit passes cached amount
    ...
}
```

**The bug -- `ERC4626YieldStrategy._totalWithdraw()`** ([ERC4626YieldStrategy.sol#L332-L356](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L332-L356)):

```solidity
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    // ...
    uint256 clientStoredBalance = clientBalances[token][client]; // @audit reads LIVE balance, ignores `amount`
    uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

    if (sharesToWithdraw > 0) {
        uint256 assetsReceived = vault.redeem(sharesToWithdraw, address(this), address(this));

        clientBalances[token][client] = 0;
        totalDeposited[token] -= clientStoredBalance;

        underlyingToken.safeTransfer(owner(), assetsReceived);
    }
}
```

The `amount` parameter -- which carries the cached Phase 1 balance -- is checked only in the `require(amount > 0)` guard. The actual share calculation on line 343 uses `clientStoredBalance`, which reflects the live `clientBalances[token][client]` mapping. This mapping is incremented by any `deposit()` calls made during the 24-hour waiting period.

The result is a disconnect between what was announced (the cached amount) and what is actually withdrawn (the full live balance). The waiting period, which exists specifically to give the community time to react to large withdrawal announcements, is rendered ineffective for any deposits made after Phase 1 initiation.

### Impact

The two-phase timelock is a core security mechanism described in the project documentation as providing "rugpull protection." This vulnerability undermines that guarantee in the following way:

1. The owner initiates `totalWithdrawal` with a client balance of 1000e18. The community sees this announcement and has 24 hours to react.
2. During the waiting period, the authorized client deposits an additional 2000e18. No new announcement is made. The cached `state.balance` remains 1000e18.
3. After 24 hours, Phase 2 executes and withdraws the full 3000e18 -- the additional 2000e18 had zero timelock protection.

The design decision documented in `registered-projects.json` states: *"Balance caching at totalWithdrawal initiation to prevent manipulation during waiting period."* This vulnerability directly contradicts that stated design intent because the caching is only performed in the abstract base class while the concrete implementation bypasses it entirely.

While this requires the owner to act (and the owner is already trusted to some degree), the entire purpose of the two-phase mechanism is to constrain what the owner can do unilaterally. Deposits made during the waiting period should either be excluded from the withdrawal or should trigger a new announcement with a fresh waiting period.

## Recommended mitigation steps

The most direct fix is to make `_totalWithdraw()` respect the cached `amount` parameter from Phase 1 rather than reading live state. This aligns with the documented design intent of balance caching at initiation time.

**Option A -- Use the cached amount (recommended):**

```solidity
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
    require(amount > 0, "ERC4626YieldStrategy: amount must be greater than zero");

    uint256 totalShares = vault.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

-   uint256 clientStoredBalance = clientBalances[token][client];
-   uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];
+   // Use the cached amount from Phase 1, capped to actual balance
+   uint256 clientStoredBalance = clientBalances[token][client];
+   uint256 withdrawAmount = amount < clientStoredBalance ? amount : clientStoredBalance;
+   uint256 sharesToWithdraw = (totalShares * withdrawAmount) / totalDeposited[token];

    if (sharesToWithdraw > 0) {
        uint256 assetsReceived = vault.redeem(sharesToWithdraw, address(this), address(this));

-       clientBalances[token][client] = 0;
-       totalDeposited[token] -= clientStoredBalance;
+       clientBalances[token][client] -= withdrawAmount;
+       totalDeposited[token] -= withdrawAmount;

        underlyingToken.safeTransfer(owner(), assetsReceived);
    }
}
```

**Option B -- Block deposits during active withdrawal:**

Add a check in `_depositInternal()` that reverts if the client has an active withdrawal state (`WithdrawalStatus.Initiated` or `WithdrawalStatus.Executable`). This prevents the balance from growing after Phase 1 initiation but may be overly restrictive for legitimate deposit activity.
