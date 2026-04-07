# M-01: _totalWithdraw Ignores Cached Timelock Amount, Undermining Two-Phase Withdrawal Protection

## Severity
**Medium**

## Affected Contracts
- `/home/justin/code/C4/solidity-audit/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` -- `_totalWithdraw()` (lines 332-356)
- `/home/justin/code/C4/solidity-audit/lib/reflax-yield-vault/src/AYieldStrategy.sol` -- `_initiateWithdrawal()` (lines 379-394) and `_executeWithdrawal()` (lines 403-417)

## Root Cause

The two-phase total withdrawal system is designed to provide community protection against rugpulls by:
1. **Phase 1**: Caching the balance and starting a 24-hour waiting period.
2. **Phase 2**: Executing the withdrawal using the cached amount.

However, `ERC4626YieldStrategy._totalWithdraw()` completely ignores the `amount` parameter passed from `_executeWithdrawal()` (line 414 in AYieldStrategy). Instead, it reads the live `clientBalances[token][client]` value (line 342). This means:

- If additional deposits are made for the client between Phase 1 and Phase 2, the Phase 2 execution will withdraw **more** than what was announced in Phase 1.
- The community monitoring the `WithdrawalInitiated` event sees one balance, but a different (larger) amount is actually withdrawn.

This undermines the stated purpose of the timelock: "Provides community protection against rugpulls while allowing legitimate fund migrations."

## Impact

1. The timelock's transparency guarantee is broken. The amount announced in the `WithdrawalInitiated` event does not match the amount actually withdrawn.
2. An owner (even if non-malicious) could accidentally withdraw more than intended if deposits arrive during the waiting period.
3. Community members monitoring for rugpulls cannot reliably determine what amount will be withdrawn.

Note: Since the owner is trusted per the contest rules, this is Medium severity -- it does not enable a direct theft by an untrusted party, but it breaks a security invariant (the timelock's purpose) that is explicitly designed to protect the community.

## Proof of Concept Outline

```
Setup:
- Client has 1000 tokens deposited (clientBalances = 1000)

Phase 1 (Initiate):
- Owner calls totalWithdrawal(token, client)
- _initiateWithdrawal reads this.balanceOf() = 1000 (principal)
- Event: WithdrawalInitiated(balance: 1000)
- state.balance = 1000

During 24-hour waiting period:
- Authorized client deposits 5000 more tokens for the same client
- clientBalances[token][client] is now 6000

Phase 2 (Execute):
- Owner calls totalWithdrawal(token, client) after 24 hours
- _executeWithdrawal passes state.balance (1000) as amount
- BUT _totalWithdraw reads clientStoredBalance = clientBalances[token][client] = 6000
- sharesToWithdraw = (totalShares * 6000) / totalDeposited
- All 6000 worth of shares are withdrawn, not just the announced 1000
```

## Recommended Fix

`_totalWithdraw` should use the `amount` parameter (the cached balance from Phase 1) to cap the withdrawal:

```solidity
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
    require(amount > 0, "ERC4626YieldStrategy: amount must be greater than zero");

    uint256 totalShares = vault.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

    uint256 clientStoredBalance = clientBalances[token][client];
    // Use the MINIMUM of cached amount and current balance
    uint256 effectiveAmount = amount < clientStoredBalance ? amount : clientStoredBalance;

    uint256 sharesToWithdraw = (totalShares * effectiveAmount) / totalDeposited[token];

    if (sharesToWithdraw > 0) {
        uint256 assetsReceived = vault.redeem(sharesToWithdraw, address(this), address(this));

        clientBalances[token][client] -= effectiveAmount;
        totalDeposited[token] -= effectiveAmount;

        underlyingToken.safeTransfer(owner(), assetsReceived);
    }
}
```

This ensures the withdrawal is capped to what was announced during Phase 1, preserving the timelock's transparency guarantee. The same issue exists in `AutoPoolYieldStrategy._totalWithdraw()` (line 368).
