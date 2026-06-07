<!--
ID: ryv11m1
C4 Submission Metadata
Title: [M-01] `slippageToleranceBps` defaults to zero and accepts MAX_BPS (10000) — strategy is functionally broken at both boundary values
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L194-L213
PoC File: poc-M01-slippage-max-bps.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy` contains two distinct flaws in its slippage-tolerance accounting that render the strategy non-functional at opposing boundary values of `slippageToleranceBps`. Sub-case A: `setSlippageTolerance` accepts `_bps == MAX_BPS` (10 000), which causes every deposit to credit **zero principal** while permanently consuming the depositor's tokens. Sub-case B: `slippageToleranceBps` is never initialised in the constructor, leaving it at the Solidity default of zero, which forces every withdrawal to demand 100% of the ideal AMM output and revert on any real market discount.

### Vulnerability details

#### Sub-case A — `setSlippageTolerance` accepts MAX\_BPS, zeroing all principal credits

[`setSlippageTolerance` (L194–L199)](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L194-L199) uses a `<=` guard:

```solidity
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
    uint256 oldBps = slippageToleranceBps;
    slippageToleranceBps = _bps;
    emit SlippageToleranceSet(oldBps, _bps);
}
```

`MAX_BPS` is `10000`, so the call `setSlippageTolerance(10000)` passes the guard. Once `slippageToleranceBps == 10000`, [`_creditedPrincipal` (L212–L214)](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L212-L214) returns zero for every input:

```solidity
function _creditedPrincipal(uint256 amount) internal view returns (uint256) {
    return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
    // = amount * (10000 - 10000) / 10000 = 0
}
```

`_depositInternal` then uses this value for both `minOut` and the principal credit:

```solidity
creditedPrincipal = _creditedPrincipal(amount);        // == 0
uint256 minOut = vault.convertToShares(creditedPrincipal); // == 0 (accepts any swap output)
// ...
clientBalances[token][recipient] += creditedPrincipal;  // += 0
totalDeposited[token]            += creditedPrincipal;  // += 0
```

The swap executes (any non-zero output passes a `minOut` of zero), vault shares are credited to the strategy, and the `Deposited` event fires with the full nominal `amount`. The depositor's underlying tokens are gone, vault shares are held by the strategy, but `clientBalances[token][recipient]` is zero. The depositor can never withdraw — their recorded balance is zero regardless of how many shares the strategy holds.

Halmos formally proved the generalisation: for any `slippageBps > 0`, deposits with `amount < 10000 / (MAX_BPS - slippageBps)` also credit zero principal (integer truncation). At `slippageBps == MAX_BPS` every deposit is affected regardless of size.

#### Sub-case B — zero-default blocks all withdrawals before owner configures tolerance

`slippageToleranceBps` is a plain `uint256` storage variable with no initialisation in the constructor. Its value is zero from deployment. In `_withdrawInternal` (L357–L358):

```solidity
uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
// = idealUnderlying * (10000 - 0) / 10000 = idealUnderlying (100%)
```

`minOut` equals the full ideal underlying amount. Any Curve pool swap — which operates at a slight premium or discount to the theoretical price — will return an amount strictly less than the ideal. The AMM adapter enforces `amountOut >= minAmountOut` and reverts. Every withdrawal attempt fails until the owner explicitly calls `setSlippageTolerance` with a non-zero value. There is no constructor parameter that sets a safe default, no on-chain check that the tolerance is non-zero before executing a swap, and no documentation warning operators to configure this value before the first deposit.

### Impact

**Sub-case A** silently steals depositor principal. Tokens are transferred from the depositor, vault shares are acquired and held by the strategy, and `clientBalances` is never incremented. The `Deposited` event emits the full nominal amount, masking the zero-credit outcome. The depositor has no on-chain recourse — their recorded balance is zero, so `withdraw` and `withdrawAsOwner` will also produce zero output (the `availablePrincipal` cap in `_withdrawInternal` clamps `amount` to zero). The effect is permanent loss of all deposited funds while the strategy's share inventory grows without any corresponding principal liability.

**Sub-case B** makes the strategy structurally insolvent from block zero for any depositor who attempts a withdrawal before the owner configures slippage tolerance. Because `setSlippageTolerance` requires an explicit owner action that is not enforced or required by the constructor, a freshly deployed strategy that has accepted deposits is in a broken state by default. A real AMM discount as small as 1 basis point triggers the revert.

### Proof of Concept

PoC: `M-01-poc.t.sol` (2/2 tests pass — `test_poc_M01_maxBpsZeroesAllPrincipalCredit`, `test_poc_M01_zeroDefaultCausesWithdrawalRevert`).

## Recommended mitigation steps

**1. Disallow `MAX_BPS` in `setSlippageTolerance`**

Change the guard from `<=` to `<` and add a reasonable upper cap to prevent excessively wide tolerances that would expose depositors to front-running:

```solidity
uint256 public constant MAX_SLIPPAGE_BPS = 500; // 5% — adjust to protocol risk tolerance

function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps > 0, "ERC4626MarketYieldStrategy: slippage tolerance cannot be zero");
    require(_bps < MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance must be < MAX_BPS");
    require(_bps <= MAX_SLIPPAGE_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds cap");
    uint256 oldBps = slippageToleranceBps;
    slippageToleranceBps = _bps;
    emit SlippageToleranceSet(oldBps, _bps);
}
```

**2. Initialise `slippageToleranceBps` in the constructor**

Require the deployer to supply a non-zero tolerance so the strategy is never deployed in an insolvent state:

```solidity
constructor(
    address _owner,
    address _underlyingToken,
    address _erc4626Vault,
    address _ammAdapter,
    uint256 _initialSlippageBps   // e.g. 100 = 1%
) AYieldStrategy(_owner) {
    require(_initialSlippageBps > 0 && _initialSlippageBps < MAX_BPS,
        "ERC4626MarketYieldStrategy: invalid initial slippage tolerance");
    // ... existing address checks ...
    slippageToleranceBps = _initialSlippageBps;
}
```

**3. Defence-in-depth guard in `_depositInternal`**

Add a non-zero slippage check before crediting principal to ensure accounting is always consistent:

```solidity
require(slippageToleranceBps > 0, "ERC4626MarketYieldStrategy: slippage tolerance not configured");
creditedPrincipal = _creditedPrincipal(amount);
require(creditedPrincipal > 0, "ERC4626MarketYieldStrategy: zero principal credit");
```

This provides a loud failure mode if the invariant is somehow violated, rather than silently burning depositor funds.
