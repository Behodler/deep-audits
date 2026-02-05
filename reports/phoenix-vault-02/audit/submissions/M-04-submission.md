<!--
C4 Submission Metadata
Title: [M-04] Untracked Leftover Tokens After Liquidity Addition Causes Value Leakage
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L569-L587
PoC File: /home/justin/code/C4/solidity-audit/workspace/phoenix-vault/test/poc-M-04.t.sol
-->

## Finding description and impact

### Summary

The `_addLiquidity()` function in `UniV4StableYieldStrategy.sol` uses the minimum of normalized deposit and paired token amounts for balanced liquidity provision. When swap slippage creates an imbalance between the two token amounts, the excess tokens from the larger amount remain in the contract but are never tracked in `clientDeposits`, `totalDeposited`, or any other accounting variable.

### Vulnerability details

The vulnerable code pattern at [UniV4StableYieldStrategy.sol#L569-L587](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L569-L587):

```solidity
function _addLiquidity(uint256 depositAmount, uint256 pairedAmount) internal returns (uint128 liquidityAdded) {
    // Normalize to 18 decimals for liquidity calculation
    uint256 normalizedDeposit = _toStandardDecimals(depositAmount, depositTokenDecimals);
    uint256 normalizedPaired = _toStandardDecimals(pairedAmount, pairedTokenDecimals);

    // VULNERABILITY: Uses minimum of both for balanced liquidity
    // The excess from the larger amount is NOT tracked!
    uint256 liquidityAmount = normalizedDeposit < normalizedPaired ? normalizedDeposit : normalizedPaired;

    IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
        tickLower: tickLower,
        tickUpper: tickUpper,
        liquidityDelta: int256(liquidityAmount),
        salt: POSITION_SALT
    });

    poolManager.modifyLiquidity(poolKey, params, "");

    return uint128(liquidityAmount);
}
```

The `deposit()` function at lines 160-189 demonstrates the complete flow:

```solidity
function deposit(address token, uint256 amount, address recipient) external ... {
    // Transfer deposit token from client
    depositToken.safeTransferFrom(msg.sender, address(this), amount);

    // Swap ~50% to paired token
    uint256 halfAmount = amount / 2;
    uint256 remainingAmount = amount - halfAmount;

    // This swap may return LESS than halfAmount due to slippage
    uint256 pairedAmount = _swapWithSlippageCheck(depositToken, pairedToken, halfAmount);

    // VULNERABLE: _addLiquidity uses minimum, leaving excess untracked
    uint128 liquidityAdded = _addLiquidity(remainingAmount, pairedAmount);

    // Update state - only tracks original deposit, NOT accounting for leftovers
    liquidityPosition += liquidityAdded;
    totalDeposited += amount;
    clientDeposits[recipient] += amount;
}
```

The attack path is as follows:

1. User deposits 100 USDC
2. Strategy swaps 50 USDC for paired token (e.g., USDT)
3. Due to 1% swap slippage, user receives only 49.5 USDT
4. Remaining amounts: 50 USDC and 49.5 USDT
5. `_addLiquidity` normalizes and uses `min(50, 49.5) = 49.5` as the liquidity base
6. Only 49.5 USDC equivalent is used; 0.5 USDC remains orphaned in the contract
7. The orphaned 0.5 USDC is not tracked in any accounting variable

### Impact

This vulnerability causes persistent value leakage with the following consequences:

1. **Direct value loss per deposit**: With typical 1% slippage, approximately 0.5% of each deposit becomes orphaned. At 5% slippage, this rises to 2.5% per deposit.

2. **Cumulative accumulation**: Orphaned tokens accumulate over time. After 10 deposits of 100 USDC each at 1% slippage, approximately 5 USDC worth of tokens sit untracked in the contract.

3. **Accounting discrepancy**: Users' `clientDeposits` balances do not accurately reflect their actual LP position value. A user with 100 USDC recorded may only have 99.5 USDC worth of LP tokens.

4. **Migration and upgrade risk**: During contract migrations, orphaned tokens may be lost or inappropriately distributed since they belong to no tracked depositor.

5. **Unfair distribution**: If orphaned tokens are eventually recovered by an admin, there is no fair mechanism to return them to the users who originally contributed them.

The severity is Medium because:
- Value leakage is proportional to slippage and accumulates over time
- No direct theft vector exists, but funds become inaccessible to their rightful owners
- Protocol accounting becomes increasingly inaccurate with usage

## Recommended mitigation steps

Track leftover tokens and implement one of the following remediation strategies:

**Option 1: Use balanceOf to credit leftovers as deposit discount (Recommended)**

Use actual token balances rather than state variable tracking. Existing leftovers reduce the transfer amount for the next depositor, socializing slippage costs fairly across users:

```solidity
function deposit(address token, uint256 amount, address recipient) external ... {
    // Use existing deposit token balance as credit toward this deposit
    uint256 existingDepositBalance = depositToken.balanceOf(address(this));
    uint256 transferNeeded = existingDepositBalance >= amount
        ? 0
        : amount - existingDepositBalance;

    if (transferNeeded > 0) {
        depositToken.safeTransferFrom(msg.sender, address(this), transferNeeded);
    }

    // Swap ~50% to paired token
    uint256 halfAmount = amount / 2;
    uint256 remainingAmount = amount - halfAmount;

    _swapWithSlippageCheck(depositToken, pairedToken, halfAmount);

    // Use actual paired token balance (includes any previous leftovers)
    uint256 pairedAvailable = pairedToken.balanceOf(address(this));

    uint128 liquidityAdded = _addLiquidity(remainingAmount, pairedAvailable);

    // Update state - user credited for full requested amount
    liquidityPosition += liquidityAdded;
    totalDeposited += amount;
    clientDeposits[recipient] += amount;
}
```

This approach:
- Transfers only what's needed from the user (discount effect)
- Uses `balanceOf` for both tokens, avoiding state variable tracking drift
- Handles accidentally-sent tokens gracefully
- Socializes slippage costs fairly across depositors

**Option 2: Refund leftovers to depositor**

```solidity
function deposit(address token, uint256 amount, address recipient) external ... {
    // ... existing logic ...

    uint128 liquidityAdded = _addLiquidity(remainingAmount, pairedAmount);

    // Calculate and refund any leftovers
    uint256 depositLeftover = depositToken.balanceOf(address(this));
    if (depositLeftover > 0) {
        depositToken.safeTransfer(msg.sender, depositLeftover);
        amount -= depositLeftover; // Adjust recorded deposit
    }

    // Update state with actual deposited amount
    totalDeposited += amount;
    clientDeposits[recipient] += amount;
}
```

**Option 3: Include leftovers in value estimation**

Add a function to account for orphaned tokens when calculating total value:

```solidity
function getTotalValue() external view returns (uint256) {
    uint256 lpValue = _getLiquidityPositionValue();
    uint256 orphanedDeposit = depositToken.balanceOf(address(this));
    uint256 orphanedPaired = pairedToken.balanceOf(address(this));
    return lpValue + orphanedDeposit + _convertToDepositToken(orphanedPaired);
}
```

The recommended approach is **Option 1** as it maximizes capital efficiency by automatically deploying accumulated leftovers in subsequent deposits, while maintaining accurate accounting.
