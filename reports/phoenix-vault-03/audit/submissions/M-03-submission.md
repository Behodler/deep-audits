<!--
C4 Submission Metadata
Title: [M-03] withdrawFrom() Balance Check Caps Surplus Extraction at Principal Amount
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L280-L299
PoC File: poc-M-03.t.sol
-->

## Finding description and impact

### Summary

`AYieldStrategy.withdrawFrom()` uses the deprecated `balanceOf()` function for its pre-condition guard, which returns only the client's deposited principal. This creates an artificial ceiling on surplus withdrawals: when accumulated yield exceeds the original principal (i.e., greater than 100% return), the excess surplus beyond the principal amount becomes permanently inaccessible through the `withdrawFrom` / `SurplusWithdrawer` path.

### Vulnerability details

The `withdrawFrom()` function in `AYieldStrategy.sol` validates the requested withdrawal amount at [line 292](https://github.com/Behodler/reflax-yield-vault/blob/main/src/AYieldStrategy.sol#L292):

```solidity
function withdrawFrom(address token, address client, uint256 amount, address recipient)
    external
    onlyAuthorizedWithdrawer
    nonReentrant
    whenNotPaused
{
    // ...
    // Check that client has sufficient balance
    uint256 clientBalance = this.balanceOf(token, client);  // @audit returns principalOf only
    require(clientBalance >= amount, "AYieldStrategy: insufficient client balance");

    _withdrawFrom(token, client, amount, recipient);
    // ...
}
```

The call to `this.balanceOf(token, client)` dispatches to `ERC4626YieldStrategy.balanceOf()` at [line 143](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L143):

```solidity
/// @dev DEPRECATED: Use principalOf() or totalBalanceOf() explicitly.
///      Kept for backward compatibility. Returns principal only.
function balanceOf(address token, address account) external view override returns (uint256) {
    return this.principalOf(token, account);
}
```

This function explicitly returns only the principal -- the amount originally deposited, excluding yield. The `balanceOf()` method is marked `DEPRECATED` in both the `IYieldStrategy` interface (line 30: *"This method's semantics are ambiguous"*) and the concrete implementation, yet `AYieldStrategy` relies on it for a critical access control check.

Meanwhile, the child `_withdrawFrom()` implementation in `ERC4626YieldStrategy` at [lines 368-396](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L368-L396) performs its own independent validation that correctly uses `totalBalanceOf`:

```solidity
function _withdrawFrom(address token, address client, uint256 amount, address recipient) internal override {
    uint256 principal = clientBalances[token][client];
    uint256 totalBalance = this.totalBalanceOf(token, client);
    uint256 surplus = totalBalance > principal ? totalBalance - principal : 0;

    require(amount <= surplus, "ERC4626YieldStrategy: amount exceeds available surplus...");
    // ... redeem shares
}
```

The two checks impose contradictory bounds on `amount`:

| Check | Constraint | Source |
|-------|-----------|--------|
| Parent (`AYieldStrategy`) | `amount <= principalOf(client)` | Deprecated `balanceOf()` |
| Child (`ERC4626YieldStrategy`) | `amount <= surplus` | Correct `totalBalanceOf() - principalOf()` |

The effective maximum withdrawal is `min(principal, surplus)`. When surplus exceeds principal, the parent's check becomes the binding constraint, and the amount `surplus - principal` is unreachable.

This directly affects the `SurplusWithdrawer` contract, which calls `withdrawFrom` as the sole mechanism for extracting accumulated yield:

```solidity
// SurplusWithdrawer.sol line 118
IYieldStrategy(yieldStrategy).withdrawFrom(token, client, withdrawAmount, recipient);
```

The `SurplusWithdrawer` correctly computes the available surplus via `SurplusTracker` and requests withdrawal of a percentage. But when the computed `withdrawAmount` exceeds the client's principal, the transaction reverts at the parent's guard before reaching the child's valid surplus check.

### Impact

Surplus yield beyond 100% of the deposited principal becomes permanently locked in the `withdrawFrom` path. The only recovery mechanism is `totalWithdrawal()`, which is a destructive operation that withdraws the entire position (principal and all yield), zeroes out the client's balance tracking, and sends funds to the contract owner for manual redistribution.

Concrete scenario from the PoC:

- A client deposits **1,000e18** tokens
- The vault generates **1,500e18** in yield (150% return)
- `totalBalanceOf` = 2,500e18, `principalOf` = 1,000e18, surplus = 1,500e18
- Attempting to withdraw **1,200e18** of surplus reverts with `"AYieldStrategy: insufficient client balance"`
- The maximum extractable surplus via `withdrawFrom` is **1,000e18** (the principal amount)
- **500e18** of legitimate surplus is inaccessible through the intended withdrawal path

For long-lived yield strategies or high-yield vaults, the inaccessible fraction grows over time. A strategy that has doubled in value (100% yield) can only extract half of its surplus through the standard path. A strategy at 300% yield can only extract one-third.

## Recommended mitigation steps

Replace the deprecated `balanceOf()` call in `AYieldStrategy.withdrawFrom()` with `totalBalanceOf()`, which correctly reflects the client's full position including yield:

```solidity
function withdrawFrom(address token, address client, uint256 amount, address recipient)
    external
    onlyAuthorizedWithdrawer
    nonReentrant
    whenNotPaused
{
    require(token != address(0), "AYieldStrategy: token cannot be zero address");
    require(client != address(0), "AYieldStrategy: client cannot be zero address");
    require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");
    require(amount > 0, "AYieldStrategy: amount must be greater than zero");

    // Use totalBalanceOf instead of deprecated balanceOf
    uint256 clientBalance = this.totalBalanceOf(token, client);
    require(clientBalance >= amount, "AYieldStrategy: insufficient client balance");

    _withdrawFrom(token, client, amount, recipient);

    emit WithdrawnFrom(token, client, msg.sender, amount, recipient);
}
```

Alternatively, the parent guard can be removed entirely since `_withdrawFrom()` in `ERC4626YieldStrategy` already enforces `amount <= surplus`, which is a stricter and more semantically correct constraint. However, retaining a guard in the base contract provides defense-in-depth for future concrete implementations that may not enforce their own bounds.

Additionally, consider removing or clearly gating all usage of the deprecated `balanceOf()` function to prevent similar semantic mismatches elsewhere in the codebase. The `_initiateWithdrawal()` function at line 383 also calls `this.balanceOf()` and may warrant the same correction depending on its intended semantics.
