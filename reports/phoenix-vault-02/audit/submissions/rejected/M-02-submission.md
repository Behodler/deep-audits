<!--
C4 Submission Metadata
Title: [M-02] Withdrawal Gas Cost Scales with Total TVL Enabling Griefing Attacks
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/AutoPoolYieldStrategy.sol#L264-L286
PoC File: /home/justin/code/C4/solidity-audit/workspace/phoenix-vault/test/poc-M-02.t.sol
-->

## Finding description and impact

### Summary

The `withdraw()` function in `AutoPoolYieldStrategy.sol` unstakes ALL shares from mainRewarder regardless of the withdrawal amount, then re-stakes the remaining shares after redeeming only the portion needed. This causes withdrawal gas costs to scale linearly with total TVL rather than with the withdrawal amount, enabling griefing attacks where an attacker can inflate TVL to make other users' withdrawals prohibitively expensive.

### Vulnerability details

The vulnerable code pattern at [AutoPoolYieldStrategy.sol#L264-L286](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/AutoPoolYieldStrategy.sol#L264-L286):

```solidity
function withdraw(address token, uint256 amount, address recipient)
    external
    override
    onlyAuthorizedClient
    nonReentrant
    whenNotPaused
{
    // ... validation ...

    // Unstake ALL shares to ensure we have them available for withdrawal
    uint256 totalShares = mainRewarder.balanceOf(address(this));
    require(totalShares > 0, "AutoPoolYieldStrategy: no shares available");
    mainRewarder.withdraw(address(this), totalShares, false);  // @audit UNSTAKES 100%

    // CRITICAL: Use ERC4626 standard convertToShares instead of manual calculation
    uint256 sharesToRedeem = autoPoolVault.convertToShares(amount);  // @audit Only tiny fraction needed
    uint256 availableShares = autoPoolVault.balanceOf(address(this));
    if (sharesToRedeem > availableShares) {
        sharesToRedeem = availableShares;
    }
    uint256 tokensReceived = autoPoolVault.redeem(sharesToRedeem, recipient, address(this));

    // CRITICAL FIX: Re-stake ALL remaining vault shares (yield preservation)
    uint256 leftoverShares = autoPoolVault.balanceOf(address(this));
    if (leftoverShares > 0) {
        mainRewarder.stake(address(this), leftoverShares);  // @audit RESTAKES 99.99%
    }
    // ...
}
```

The same vulnerability pattern exists in `_withdrawFrom()` at lines 423-443.

For a withdrawal of 1 DOLA from a vault containing 1,000,000 DOLA:
1. `mainRewarder.withdraw()` unstakes all 1,000,000 shares
2. `autoPoolVault.redeem()` redeems only 1 share
3. `mainRewarder.stake()` re-stakes 999,999 shares

This results in processing approximately 2,000,000 share operations for a withdrawal that should only require processing 1 share.

### Impact

**Gas Griefing Attack Vector**: An attacker can deposit a large amount into the strategy, significantly increasing the TVL. This directly increases the gas cost for all other users' withdrawals, regardless of how small those withdrawals are.

**Economic Denial of Service**: As TVL grows (either organically or through malicious deposits), small withdrawals become increasingly uneconomical. Users attempting to withdraw small amounts may find the gas costs exceed the value being withdrawn.

**Quantified Waste**: The PoC demonstrates a waste ratio exceeding 2,000,000x - meaning the actual share operations performed are over two million times more than necessary for the withdrawal amount.

**Attack Scenario**:
1. Protocol has normal TVL of 100,000 DOLA from legitimate users
2. Attacker deposits 10,000,000 DOLA (can be borrowed via flash loan)
3. Victim attempts to withdraw 100 DOLA
4. Instead of processing ~100 shares, the withdrawal processes ~20,000,000 shares (unstake + restake)
5. Gas cost is 100,000x higher than necessary
6. Attacker can withdraw their deposit (paying inflated gas) or profit from MEV opportunities created by predictable high-gas transactions

## Recommended mitigation steps

Calculate and unstake only the proportional shares needed for the withdrawal rather than unstaking all shares:

```solidity
function withdraw(address token, uint256 amount, address recipient)
    external
    override
    onlyAuthorizedClient
    nonReentrant
    whenNotPaused
{
    require(token == address(underlyingToken), "AutoPoolYieldStrategy: only underlying token supported");
    require(amount > 0, "AutoPoolYieldStrategy: amount must be greater than zero");
    require(recipient != address(0), "AutoPoolYieldStrategy: recipient cannot be zero address");

    uint256 availablePrincipal = clientBalances[token][recipient];
    if (amount > availablePrincipal) {
        amount = availablePrincipal;
    }

    // Calculate proportional shares to unstake - NOT all shares
    uint256 totalShares = mainRewarder.balanceOf(address(this));
    require(totalShares > 0, "AutoPoolYieldStrategy: no shares available");

    // Only unstake the shares we need (with small buffer for rounding)
    uint256 sharesToUnstake = autoPoolVault.convertToShares(amount);
    // Add 1% buffer for rounding safety
    sharesToUnstake = (sharesToUnstake * 101) / 100;
    if (sharesToUnstake > totalShares) {
        sharesToUnstake = totalShares;
    }

    mainRewarder.withdraw(address(this), sharesToUnstake, false);

    uint256 sharesToRedeem = autoPoolVault.convertToShares(amount);
    uint256 availableShares = autoPoolVault.balanceOf(address(this));
    if (sharesToRedeem > availableShares) {
        sharesToRedeem = availableShares;
    }
    uint256 tokensReceived = autoPoolVault.redeem(sharesToRedeem, recipient, address(this));

    // Only re-stake excess shares from the buffer (if any)
    uint256 leftoverShares = autoPoolVault.balanceOf(address(this));
    if (leftoverShares > 0) {
        mainRewarder.stake(address(this), leftoverShares);
    }

    clientBalances[token][recipient] -= amount;
    totalDeposited[token] -= amount;

    emit Withdrawn(token, msg.sender, recipient, tokensReceived, sharesToRedeem);
}
```

This fix ensures gas costs scale with the withdrawal amount rather than total TVL, eliminating the griefing vector while maintaining the correct accounting behavior.
