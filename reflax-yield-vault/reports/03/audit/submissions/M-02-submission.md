<!--
C4 Submission Metadata
Title: [M-02] Fee-Charging ERC4626 Vaults Create Phantom Surplus That Drains Earlier Depositors
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L236-L253
PoC File: poc-M-02.t.sol
-->

## Finding description and impact

### Summary

`ERC4626YieldStrategy._depositInternal()` records `clientBalances[token][recipient] += amount` using the full pre-fee deposit amount, but the ERC4626 vault mints shares based on the post-fee effective amount. This principal/share mismatch causes `totalBalanceOf()` to systematically overstate later depositors' balances and understate earlier depositors' balances, enabling later depositors to siphon yield from earlier ones through the surplus withdrawal system.

### Vulnerability details

The contract's NatSpec explicitly claims universal ERC4626 compatibility:

> *This strategy is NOT designed for any specific token-vault combo. It works for any ERC4626-compliant vault (yBOLD, sBOLD, sUSDS, etc.) via constructor-only configuration.*

However, fee-on-deposit is a valid ERC4626 feature (the standard specifies `maxDeposit`, `previewDeposit`, and `deposit` precisely to accommodate vaults that charge entry fees). The vulnerability arises from two interacting design choices:

**1. Principal tracking ignores fees** ([ERC4626YieldStrategy.sol#L236-L253](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L236-L253)):

```solidity
function _depositInternal(address token, uint256 amount, address recipient, address depositor) internal {
    // ...
    underlyingToken.safeTransferFrom(depositor, address(this), amount);
    uint256 sharesReceived = vault.deposit(amount, address(this));
    require(sharesReceived > 0, "ERC4626YieldStrategy: no shares received");

    // @audit Records pre-fee amount as principal, but sharesReceived
    // reflects the post-fee effective deposit
    clientBalances[token][recipient] += amount;
    totalDeposited[token] += amount;
    // ...
}
```

When a vault charges a 5% fee, depositing 1000 tokens yields shares worth only 950. But `clientBalances` records 1000.

**2. Proportional accounting distributes by principal weight, not share ownership** ([ERC4626YieldStrategy.sol#L119-L133](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L119-L133)):

```solidity
function totalBalanceOf(address token, address account) external view override returns (uint256) {
    // ...
    uint256 totalShares = vault.balanceOf(address(this));
    uint256 totalValue = vault.convertToAssets(totalShares);

    // @audit Distributes totalValue proportionally by principal,
    // but principals are inflated relative to actual share value
    return (totalValue * principal) / totalDeposited[token];
}
```

Since every client's principal is recorded identically (the full input amount), `totalBalanceOf` distributes the vault's total asset value equally by principal weight. But clients who deposited later -- after the vault's share price increased from fees and/or yield -- received fewer shares per token. Their actual share of the vault is smaller than their principal weight implies.

**The surplus theft chain**: When yield accrues in the vault, `SurplusTracker.getSurplus()` computes surplus as `totalBalanceOf(client) - principalOf(client)`. Because `totalBalanceOf` overstates later depositors' values (by distributing total value by inflated principal weight rather than by actual shares), it creates phantom surplus for those clients. When `SurplusWithdrawer.withdrawSurplusPercent()` extracts this phantom surplus via `_withdrawFrom()`, it redeems shares from the shared pool -- shares that proportionally belong to earlier depositors. This directly transfers yield from earlier depositors to the surplus recipient.

### Impact

The impact was validated by the PoC (poc-M-02.t.sol) using a 5% fee-charging vault:

1. **Principal inflation**: A deposit of 1000e18 records 1000e18 as principal but only receives shares worth 950e18 in the vault. Every client's `principalOf()` overstates their actual position by the fee percentage.

2. **Yield theft across clients**: User1 deposits 1000e18, the vault generates 100e18 yield (User1's shares are now worth 1100e18), then User2 deposits 1000e18 (receiving shares worth only 950e18). After User2's deposit, `totalBalanceOf(User1)` drops from 1100e18 to approximately 1050e18 because User2's inflated principal dilutes User1's proportional claim. User2 has effectively stolen ~50e18 of User1's earned yield through the accounting distortion alone.

3. **Withdrawal losses**: When both users withdraw, User1 receives approximately 1000e18 despite having earned 100e18 in yield. User1's entire yield was redistributed to User2 through the proportional accounting mismatch.

4. **Surplus underreporting and hidden value**: With 200e18 of yield in the vault, the surplus system reports only ~100e18 surplus versus the fair surplus of ~228e18. Approximately 128e18 in value becomes hidden and unextractable through normal surplus withdrawal operations.

The severity is Medium because: the vulnerability requires the strategy to be deployed with a fee-charging ERC4626 vault (a supported but not guaranteed configuration), and the value at risk scales with the fee percentage and the timing difference between deposits. The contract's documentation explicitly claims this configuration is supported, making it a reasonable deployment scenario rather than a hypothetical edge case.

## Recommended mitigation steps

The most direct fix is to track principal as the effective post-fee value rather than the raw input amount. Replace the principal tracking in `_depositInternal()` with the vault's own accounting of what was actually deposited:

```solidity
function _depositInternal(address token, uint256 amount, address recipient, address depositor) internal {
    require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
    require(amount > 0, "ERC4626YieldStrategy: amount must be greater than zero");
    require(recipient != address(0), "ERC4626YieldStrategy: recipient cannot be zero address");

    underlyingToken.safeTransferFrom(depositor, address(this), amount);

    uint256 sharesReceived = vault.deposit(amount, address(this));
    require(sharesReceived > 0, "ERC4626YieldStrategy: no shares received");

    // Track the effective post-fee value, not the input amount
    uint256 effectiveValue = vault.convertToAssets(sharesReceived);
    clientBalances[token][recipient] += effectiveValue;
    totalDeposited[token] += effectiveValue;

    emit Deposited(token, depositor, recipient, amount, sharesReceived);
}
```

This ensures that `totalDeposited` reflects the actual value backing the shares, so the proportional calculation in `totalBalanceOf()` distributes vault value accurately across clients.

Alternative approaches:

- **Per-client share tracking**: Track `clientShares[token][recipient] += sharesReceived` instead of asset-denominated principal. This is the most robust solution and inherently handles fee-charging vaults, yield accrual timing, and all share-price variations correctly.

- **Exclude fee-charging vaults**: If the protocol does not intend to support fee-charging vaults, update the NatSpec to document this limitation and add a constructor-time validation (e.g., compare `vault.previewDeposit(1e18)` against `1e18` to detect entry fees).
