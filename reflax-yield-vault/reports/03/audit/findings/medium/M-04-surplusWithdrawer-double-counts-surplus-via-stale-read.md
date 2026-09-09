# M-04: SurplusWithdrawer and _withdrawFrom Perform Redundant Surplus Calculations With Potential for Inconsistency

## Severity
**Medium**

## Affected Contracts
- `<repo>/lib/reflax-yield-vault/src/SurplusWithdrawer.sol` -- `withdrawSurplusPercent()` (lines 90-123)
- `<repo>/lib/reflax-yield-vault/src/SurplusTracker.sol` -- `getSurplus()` (lines 36-57)
- `<repo>/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` -- `_withdrawFrom()` (lines 368-396)
- `<repo>/lib/reflax-yield-vault/src/AYieldStrategy.sol` -- `withdrawFrom()` (lines 280-299)

## Root Cause

The surplus withdrawal flow involves **three independent surplus/balance checks** across contracts, each reading vault state at a different point in time within the same transaction. While within a single transaction there's no block-level staleness, the checks use **different comparison semantics** that can conflict:

### Check 1 -- SurplusTracker.getSurplus() (called by SurplusWithdrawer, line 110)
```solidity
uint256 vaultBalance = IYieldStrategy(vault).totalBalanceOf(token, client);
return vaultBalance - clientInternalBalance;  // clientInternalBalance = principalOf()
```
This computes surplus as: `totalBalanceOf(client) - principalOf(client)`.

### Check 2 -- AYieldStrategy.withdrawFrom() (line 292-293)
```solidity
uint256 clientBalance = this.balanceOf(token, client);  // returns PRINCIPAL
require(clientBalance >= amount, "AYieldStrategy: insufficient client balance");
```
This checks: `principalOf(client) >= withdrawAmount`. This is a **principal check**, not a surplus check. For surplus withdrawals where `amount` is small (yield only), this will almost always pass. But the semantic mismatch means this guard provides no meaningful protection for the surplus use case.

### Check 3 -- ERC4626YieldStrategy._withdrawFrom() (lines 372-382)
```solidity
uint256 surplus = totalBalance > principal ? totalBalance - principal : 0;
require(amount <= surplus, ...);
```
This re-computes surplus and checks: `amount <= surplus`. This is the actual surplus guard.

### The Inconsistency Problem

The SurplusWithdrawer passes `yieldStrategy` as the first argument to `surplusTracker.getSurplus()` (line 110), while SurplusTracker calls `IYieldStrategy(vault).totalBalanceOf(token, client)` where it names the parameter `vault` (SurplusTracker line 48). The naming mismatch between SurplusWithdrawer's `yieldStrategy` variable and SurplusTracker's `vault` parameter is confusing but functionally correct -- both refer to the yield strategy contract.

However, the **real issue** is that the `AYieldStrategy.withdrawFrom()` base function's check at line 292 uses `this.balanceOf()` which returns **principal only**. This means the base contract validates `principal >= surplusAmount`. Since the surplus amount is always <= the surplus (which is always <= totalBalance), and totalBalance >= principal by definition, the check `principal >= surplusAmount` may fail when:

- `surplus > principal` (this would require totalBalance > 2 * principal, i.e., yield exceeding 100% of principal)
- In practice this is unlikely for normal yield rates but is possible for high-yield vaults over long periods

When this happens, the base contract's check at line 293 will **revert the transaction**, making it impossible to withdraw surplus that exceeds the principal amount, even though the surplus legitimately exists.

## Impact

1. For high-yield scenarios where accumulated surplus exceeds the original principal amount, the `withdrawFrom()` function will revert at the base contract level, making surplus extraction impossible through the normal flow.
2. This effectively locks yield in the contract when yield exceeds 100% of principal.
3. The locked yield can only be extracted via the two-phase `totalWithdrawal()` mechanism, which is a much heavier operation with a 24-hour timelock.

## Proof of Concept Outline

```
Setup:
- Client deposits 100 tokens (principal = 100)
- Vault generates 150 tokens of yield over time
- totalBalanceOf(client) = 250, surplus = 150

Attempt surplus withdrawal:
- SurplusWithdrawer.withdrawSurplusPercent(100, recipient)
- SurplusTracker.getSurplus() returns 150
- withdrawAmount = (150 * 100) / 100 = 150
- AYieldStrategy.withdrawFrom() checks: this.balanceOf(client) >= 150
  - this.balanceOf(client) = principalOf(client) = 100
  - 100 >= 150 is FALSE
  - REVERTS: "AYieldStrategy: insufficient client balance"

Result: Surplus of 150 is locked. Only 100 can be withdrawn per call
(and even that requires principal >= amount, which means withdrawing
surplus is capped to principal amount per transaction).
```

## Recommended Fix

The base contract's `withdrawFrom()` should use `totalBalanceOf()` instead of `balanceOf()` for the sufficiency check, since `withdrawFrom` is designed for surplus extraction:

```solidity
function withdrawFrom(address token, address client, uint256 amount, address recipient)
    external
    onlyAuthorizedWithdrawer
    nonReentrant
    whenNotPaused
{
    // ...existing require checks...

    // Check that client has sufficient TOTAL balance (not just principal)
    uint256 clientBalance = this.totalBalanceOf(token, client);
    require(clientBalance >= amount, "AYieldStrategy: insufficient client balance");

    _withdrawFrom(token, client, amount, recipient);

    emit WithdrawnFrom(token, client, msg.sender, amount, recipient);
}
```

Alternatively, remove the base-level balance check entirely and rely on the concrete `_withdrawFrom()` implementation's surplus check, which is more semantically correct.
