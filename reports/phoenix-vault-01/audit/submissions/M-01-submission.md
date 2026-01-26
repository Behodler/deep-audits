<!--
C4 Submission Metadata
Title: [M-01] Client Balance Tracking Corruption via Recipient Parameter Mismatch in withdraw()
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/AutoDolaYieldStrategy.sol#L247-L279
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `withdraw()` function in `AutoDolaYieldStrategy.sol` uses the `recipient` parameter instead of `msg.sender` to lookup and decrement client balances, allowing any authorized client to manipulate another client's balance tracking.

### Vulnerability details

The vulnerable code at [AutoDolaYieldStrategy.sol#L240-L283](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/AutoDolaYieldStrategy.sol#L240-L283):

```solidity
function withdraw(address token, uint256 amount, address recipient) external override onlyAuthorizedClient nonReentrant {
    require(token == address(dolaToken), "AutoDolaYieldStrategy: only DOLA token supported");
    require(amount > 0, "AutoDolaYieldStrategy: amount must be greater than zero");
    require(recipient != address(0), "AutoDolaYieldStrategy: recipient cannot be zero address");

    // Cap amount to available principal (prevents dust from blocking withdrawal)
    // This allows the final withdrawal to succeed even with minor rounding differences
    uint256 availablePrincipal = clientBalances[token][recipient];  // @audit Uses recipient, not msg.sender
    if (amount > availablePrincipal) {
        amount = availablePrincipal;
    }

    // ... redemption logic ...

    // SECURITY: Update principal tracking by REQUESTED amount, not RECEIVED amount
    // This ensures rounding always favors the protocol, preventing exploitation
    // Any difference (amount - dolaReceived) accumulates as protocol-owned yield
    clientBalances[token][recipient] -= amount;  // @audit Decrements recipient's balance, not msg.sender
    totalDeposited[token] -= amount;

    emit DolaWithdrawn(token, msg.sender, recipient, dolaReceived, sharesToRedeem);
}
```

The function is protected by `onlyAuthorizedClient`, which verifies that `msg.sender` is an authorized client. However, the balance lookup and decrement operations use `recipient` instead of `msg.sender`:

1. Line 247: `clientBalances[token][recipient]` - Reads the recipient's balance, not the caller's
2. Line 279: `clientBalances[token][recipient] -= amount` - Decrements the recipient's balance, not the caller's

This means any authorized client can specify another client's address as `recipient` and manipulate their balance tracking.

### Attack scenario

1. Client A deposits 1000 DOLA into the strategy
   - `clientBalances[DOLA][clientA] = 1000`

2. Client B (also an authorized client) calls `withdraw(DOLA, 1000, clientA)`
   - Function checks `clientBalances[DOLA][clientA]` which is 1000 (passes)
   - Shares are redeemed and DOLA is sent to `clientA` (the recipient)
   - `clientBalances[DOLA][clientA]` is decremented by 1000
   - Client A's balance tracking is now 0

3. Client A attempts to withdraw their legitimately deposited funds
   - `clientBalances[DOLA][clientA]` returns 0
   - Withdrawal is capped to 0, effectively locking Client A out

### Impact

This vulnerability has severe consequences:

1. **Balance manipulation**: Any authorized client can zero out another client's `clientBalances` entry without the victim's consent
2. **Accounting corruption**: The balance tracking becomes completely unreliable as it can be manipulated by any authorized party
3. **Fund lockout**: Victims cannot withdraw their legitimately deposited principal because their tracked balance shows 0
4. **Griefing vector**: Malicious or compromised authorized clients can disrupt the entire system's accounting

The severity is Medium because:
- While funds are not directly stolen (DOLA goes to the victim/recipient), the accounting corruption effectively locks users out
- Multiple authorized clients sharing the same strategy instance can interfere with each other
- The accounting corruption is permanent without admin intervention
- Note: This is DoS/griefing, not direct theft - the attacker gains nothing financially

## Recommended mitigation steps

The fix is straightforward: use `msg.sender` for balance lookups and decrements, while keeping `recipient` only for where the funds are actually sent.

```solidity
function withdraw(address token, uint256 amount, address recipient) external override onlyAuthorizedClient nonReentrant {
    require(token == address(dolaToken), "AutoDolaYieldStrategy: only DOLA token supported");
    require(amount > 0, "AutoDolaYieldStrategy: amount must be greater than zero");
    require(recipient != address(0), "AutoDolaYieldStrategy: recipient cannot be zero address");

    // Cap amount to available principal (prevents dust from blocking withdrawal)
    // FIX: Use msg.sender for balance lookup
    uint256 availablePrincipal = clientBalances[token][msg.sender];
    if (amount > availablePrincipal) {
        amount = availablePrincipal;
    }

    // ... redemption logic unchanged ...
    // recipient still receives the DOLA tokens

    // FIX: Decrement msg.sender's balance, not recipient
    clientBalances[token][msg.sender] -= amount;
    totalDeposited[token] -= amount;

    emit DolaWithdrawn(token, msg.sender, recipient, dolaReceived, sharesToRedeem);
}
```

This ensures that:
1. Only the caller's own balance is checked and decremented
2. The `recipient` parameter correctly controls where funds are sent
3. Each client can only affect their own accounting
