# L-01: _emergencyWithdraw Does Not Update clientBalances or totalDeposited, Leaving Accounting Permanently Inconsistent

## Severity
**Low**

## Affected Contract
`<repo>/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` -- `_emergencyWithdraw()` (lines 301-323)

## Root Cause

The `_emergencyWithdraw()` function redeems vault shares and transfers the underlying tokens to the owner, but it never modifies `clientBalances` or `totalDeposited`. After an emergency withdrawal:

1. `clientBalances[token][client]` still reflects the original deposit amounts.
2. `totalDeposited[token]` still reflects the total deposits.
3. But the vault shares backing those balances have been partially or fully redeemed.

This means `totalBalanceOf()` will return inflated values (based on remaining shares which are now shared among fewer deposited amounts), and subsequent `withdraw()` calls may attempt to redeem shares that no longer exist (capped silently to available shares, resulting in users receiving less than expected).

## Impact

This is classified as Low because:
- Emergency withdrawal is an owner-only function for exceptional circumstances.
- The "emergency withdrawal missing re-stake logic" is already listed as a known issue, and this is closely related but distinct: the issue here is not about re-staking but about accounting state divergence.
- After an emergency withdrawal, the contract is likely to be paused or migrated anyway.

However, if the contract continues operating after a partial emergency withdrawal, the accounting corruption could cause:
- `totalBalanceOf()` to return incorrect values.
- Subsequent `withdraw()` calls to silently under-deliver tokens.
- Surplus calculations to be incorrect.

## Recommended Fix

Either:
1. Update accounting in `_emergencyWithdraw()` to reflect the shares removed, or
2. Pause the contract after emergency withdrawal (add `_pause()` at the end), or
3. Document that the contract must be paused/migrated after emergency withdrawal.

---

# L-02: balanceOf() Returns Principal in AYieldStrategy.withdrawFrom() But Is Used As a General Sufficiency Check

## Severity
**Low**

## Affected Contract
`<repo>/lib/reflax-yield-vault/src/AYieldStrategy.sol` -- `withdrawFrom()` (line 292)

## Root Cause

In `AYieldStrategy.withdrawFrom()` (line 292), `this.balanceOf(token, client)` is called to check if the client has sufficient balance. In `ERC4626YieldStrategy`, `balanceOf()` is explicitly documented as deprecated and returns `principalOf()` (principal only).

This creates a semantic mismatch: the base contract intends to check "does the client have enough balance to cover this withdrawal?", but the actual check is "is the principal >= withdrawal amount?". For surplus-only withdrawals (the only intended use of `withdrawFrom`), the surplus will typically be smaller than the principal, so this check usually passes. But as noted in M-04, when surplus exceeds principal, this check incorrectly blocks the withdrawal.

The `balanceOf()` function is explicitly marked as `DEPRECATED` in the interface and in ERC4626YieldStrategy, yet the base contract still relies on it for access control decisions.

## Impact

Low -- the issue manifests only in edge cases where accumulated yield exceeds 100% of principal (covered in M-04 at higher severity). The deprecation of `balanceOf()` while it's still used in access control is a code quality/maintenance concern.

## Recommended Fix

Replace `this.balanceOf(token, client)` with `this.totalBalanceOf(token, client)` in `AYieldStrategy.withdrawFrom()`, or remove the check entirely since the concrete `_withdrawFrom()` performs its own surplus-specific validation.

---

# L-03: ERC4626YieldStrategy Constructor Does Not Validate vault.asset() Matches underlyingToken

## Severity
**Low**

## Affected Contract
`<repo>/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` -- constructor (lines 79-88)

## Root Cause

The constructor accepts `_underlyingToken` and `_erc4626Vault` as separate parameters but never validates that `vault.asset() == _underlyingToken`. If these are misconfigured at deployment time, the strategy will approve the wrong token to the vault, and `vault.deposit()` calls will either revert or produce unexpected behavior.

## Impact

Low -- this is a deployment-time configuration error that would be caught immediately on the first deposit attempt. No funds can be lost because `vault.deposit()` would fail if the approved token doesn't match the vault's expected asset. However, a constructor validation would provide a clearer error message and fail-fast behavior.

## Recommended Fix

Add a constructor validation:

```solidity
constructor(address _owner, address _underlyingToken, address _erc4626Vault) AYieldStrategy(_owner) {
    // ... existing checks ...

    require(
        IERC4626(_erc4626Vault).asset() == _underlyingToken,
        "ERC4626YieldStrategy: underlying token must match vault asset"
    );

    // ... rest of constructor ...
}
```
