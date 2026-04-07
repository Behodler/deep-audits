# M-03: _withdrawInternal Can Call vault.redeem() With Zero Shares, Causing Reverts on Compliant ERC4626 Vaults

## Severity
**Medium**

## Affected Contract
`/home/justin/code/C4/solidity-audit/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` -- `_withdrawInternal()` (lines 264-291)

## Root Cause

In `_withdrawInternal()`, the `require(amount > 0)` check at line 266 occurs **before** the principal cap at lines 270-273. When a caller passes `amount > 0` but the `balanceHolder` has zero principal (`clientBalances[token][balanceHolder] == 0`), the following sequence occurs:

1. Line 266: `require(amount > 0)` -- passes (amount is positive).
2. Line 270: `availablePrincipal = clientBalances[token][balanceHolder]` -- returns 0.
3. Line 271-272: `amount > 0` is true, so `amount = availablePrincipal = 0`.
4. Line 276: `sharesToRedeem = vault.convertToShares(0)` -- returns 0.
5. Line 283: `vault.redeem(0, recipient, address(this))` -- **reverts on many ERC4626 vaults**.

The ERC4626 standard (EIP-4626) does not mandate behavior for zero-amount redemptions. Many production vaults (including OpenZeppelin's ERC4626 implementation) will revert on `redeem(0, ...)` because they include `require(shares > 0)` or equivalent checks. This makes the function revert unexpectedly when called for a user with no balance.

This path is reachable through `withdraw()` (called by an authorized client for any recipient address) and through `withdrawAsOwner()`.

## Impact

1. An authorized client calling `withdraw(token, amount, recipientWithNoBalance)` will revert unexpectedly instead of succeeding as a no-op or returning gracefully.
2. If the upstream client contract (e.g., Behodler) does not handle this revert, it could block the client's own withdrawal flow for unrelated users.
3. The impact depends on the specific ERC4626 vault implementation. Some vaults silently return 0 assets; others revert.

## Proof of Concept Outline

```
Setup:
- Deploy ERC4626YieldStrategy with a vault that reverts on redeem(0)
- Authorize a client

Step 1:
- Client calls withdraw(token, 100e18, addressWithNoDeposits)
- require(amount > 0) passes (amount = 100e18)
- availablePrincipal = clientBalances[token][addressWithNoDeposits] = 0
- amount gets capped to 0
- sharesToRedeem = vault.convertToShares(0) = 0
- vault.redeem(0, ...) reverts

Expected: No-op or graceful handling
Actual: Unexpected revert
```

## Recommended Fix

Add an early return after the principal cap:

```solidity
function _withdrawInternal(address token, uint256 amount, address recipient, address balanceHolder) internal {
    require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
    require(amount > 0, "ERC4626YieldStrategy: amount must be greater than zero");
    require(recipient != address(0), "ERC4626YieldStrategy: recipient cannot be zero address");

    // Cap amount to available principal
    uint256 availablePrincipal = clientBalances[token][balanceHolder];
    if (amount > availablePrincipal) {
        amount = availablePrincipal;
    }

    // Early return if nothing to withdraw
    if (amount == 0) {
        return;
    }

    // ... rest of function
}
```

Similarly, add a zero-share guard before the `vault.redeem()` call:

```solidity
if (sharesToRedeem == 0) {
    return;
}
```
