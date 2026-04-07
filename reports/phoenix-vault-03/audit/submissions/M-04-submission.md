<!--
C4 Submission Metadata
Title: [M-04] No Slippage Protection on Deposits and Withdrawals
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L236-L291
PoC File: N/A (design finding)
-->

## Finding description and impact

### Summary

`ERC4626YieldStrategy` performs deposits and withdrawals against an external ERC4626 vault without any slippage protection. The deposit path (`_depositInternal`) only verifies that `sharesReceived > 0`, a check satisfied even when the caller receives a single wei of shares. The withdrawal path (`_withdrawInternal`) discards the return value of `vault.redeem()` entirely, performing no verification on assets received. Because the external-facing `deposit()` and `withdraw()` functions accept no minimum-output parameters and return no values, authorized clients cannot implement their own slippage guards either.

### Vulnerability details

The deposit flow in `_depositInternal` at line 245-246:

```solidity
// Deposit into ERC4626 vault — shares come directly to this contract
uint256 sharesReceived = vault.deposit(amount, address(this));
require(sharesReceived > 0, "ERC4626YieldStrategy: no shares received");
```

The `sharesReceived > 0` check is the sole guard on deposit output. A deposit of 100,000 USDS that returns 1 wei of shares would pass this check. No `minSharesOut` parameter exists in the function signature, and the external `deposit()` function (line 174-182) passes through no such parameter:

```solidity
function deposit(address token, uint256 amount, address recipient)
    external
    override
    onlyAuthorizedClient
    nonReentrant
    whenNotPaused
{
    _depositInternal(token, amount, recipient, msg.sender);
}
```

The withdrawal flow in `_withdrawInternal` at line 283 is worse -- the return value of `vault.redeem()` is not captured at all:

```solidity
// Redeem shares for underlying tokens — sent directly to recipient
vault.redeem(sharesToRedeem, recipient, address(this));
```

The ERC4626 `redeem()` function returns `uint256 assets`, representing the actual amount of underlying tokens sent to the recipient. By ignoring this value, the strategy has no mechanism to verify that the recipient received an amount close to the requested withdrawal. No `minAssetsOut` parameter is available to callers.

The same pattern repeats in `_withdrawFrom` at line 390, which also calls `vault.redeem()` without checking the returned asset amount.

Critically, the `IYieldStrategy` interface defines both functions without slippage parameters:

```solidity
function deposit(address token, uint256 amount, address recipient) external;
function withdraw(address token, uint256 amount, address recipient) external;
```

This means the vulnerability is embedded at the interface level. Authorized clients interact exclusively through these functions and have no access to the vault directly, so they cannot implement slippage protection on their own. The architectural gap forces every interaction through an unprotected path.

### Impact

Every deposit and withdrawal executed through this strategy is exposed to sandwich attacks. An attacker who can manipulate the external ERC4626 vault's share price within a block can extract value from each operation. The contract's design goal is to serve as a generic adapter for "any ERC4626-compliant vault" (per the NatSpec), which includes vaults with shallow liquidity pools where price manipulation is cheapest.

The concrete attack flow for deposits:

1. Attacker observes a pending `deposit()` transaction in the mempool.
2. Attacker front-runs with a large deposit that inflates the share price.
3. The victim's deposit executes at the inflated price, receiving fewer shares than expected.
4. Attacker back-runs by withdrawing at the now-normalized price, capturing the difference.

For withdrawals, the attack is symmetric: the attacker deflates the share price before the victim's `redeem()` and restores it afterward.

The attack surface is bounded by the attacker's ability to manipulate the specific vault's share price within a single block and by the gas cost of the sandwich. For large operations (100,000+ tokens) against vaults with shallow liquidity, extraction of 0.1-5% per transaction is realistic. Over the lifetime of the strategy with repeated deposits and withdrawals, the cumulative loss to MEV could be substantial.

## Proof of concept

This is a design-level finding that demonstrates the absence of a required safety mechanism rather than a specific exploit path. A runnable PoC against a mock vault would not meaningfully demonstrate the issue, because the vulnerability depends on the behavior of an external, adversarially-manipulated ERC4626 vault in a live mempool environment.

The absence of slippage protection can be verified by tracing the code paths:

**Deposit path** -- no minimum shares parameter exists anywhere in the call chain:

1. Authorized client calls `deposit(token, amount, recipient)` (line 174). The function signature accepts no `minSharesOut`.
2. `_depositInternal` calls `vault.deposit(amount, address(this))` (line 245).
3. The only check is `require(sharesReceived > 0)` (line 246), which is trivially satisfied regardless of how unfavorable the exchange rate is.
4. The function returns `void` -- callers cannot inspect `sharesReceived` after the fact.

**Withdrawal path** -- no minimum assets parameter exists, and the return value is discarded:

1. Authorized client calls `withdraw(token, amount, recipient)` (line 193). The function signature accepts no `minAssetsOut`.
2. `_withdrawInternal` computes `sharesToRedeem` via `vault.convertToShares(amount)` (line 276).
3. `vault.redeem(sharesToRedeem, recipient, address(this))` is called at line 283. The return value (assets received) is not captured in a variable.
4. The principal accounting at lines 287-288 decrements by the *requested* amount, not the *received* amount, so neither accounting nor the recipient has any guarantee of adequate output.

**Surplus withdrawal path** -- identical pattern at line 390:

```solidity
vault.redeem(sharesToRedeem, recipient, address(this));
```

The return value is discarded. No minimum output check exists.

For comparison, industry-standard implementations such as [Yearn V3 TokenizedStrategy](https://github.com/yearn/tokenized-strategy/blob/master/src/TokenizedStrategy.sol) and OpenZeppelin's own ERC4626 usage patterns expose `minSharesOut` / `minAssetsOut` parameters and revert when the output falls below the caller's specified threshold.

## Recommended mitigation steps

Add slippage protection parameters to the interface and propagate them through all deposit and withdrawal paths.

For `IYieldStrategy`, extend the function signatures (or add overloaded variants to preserve backward compatibility):

```solidity
function deposit(address token, uint256 amount, address recipient, uint256 minSharesOut) external;
function withdraw(address token, uint256 amount, address recipient, uint256 minAssetsOut) external;
```

For the deposit path in `_depositInternal`, accept and enforce a minimum shares parameter:

```solidity
function _depositInternal(
    address token,
    uint256 amount,
    address recipient,
    address depositor,
    uint256 minSharesOut
) internal {
    // ... existing validation ...

    uint256 sharesReceived = vault.deposit(amount, address(this));
    require(sharesReceived >= minSharesOut, "ERC4626YieldStrategy: insufficient shares received");

    // ... existing accounting ...
}
```

For the withdrawal path in `_withdrawInternal`, capture and verify the return value:

```solidity
function _withdrawInternal(
    address token,
    uint256 amount,
    address recipient,
    address balanceHolder,
    uint256 minAssetsOut
) internal {
    // ... existing validation and share calculation ...

    uint256 assetsReceived = vault.redeem(sharesToRedeem, recipient, address(this));
    require(assetsReceived >= minAssetsOut, "ERC4626YieldStrategy: insufficient assets received");

    // ... existing accounting ...
}
```

Apply the same pattern to `_withdrawFrom`. If backward compatibility with existing callers is required, provide overloaded functions where the zero-parameter versions default `minSharesOut` / `minAssetsOut` to 0 (preserving current behavior) while encouraging migration to the protected variants.
