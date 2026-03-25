<!--
C4 Submission Metadata
Title: [M-01] Missing slippage protection on mint price and BalancerPooler liquidity addition
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L177-L186
PoC File: workspace/yield-claim-nft/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

`NFTMinter.mint()` reads `config.price` at execution time without accepting a `maxPrice` parameter, and `BalancerPooler.dispatch()` defaults `minBptAmountOut` to zero when `extraData` is empty. Both patterns expose users to MEV sandwich attacks that extract value from every mint transaction.

### Vulnerability details

**NFTMinter price manipulation**

The `mint()` function reads the current price from storage and increases it after each mint by `growthBasisPoints`:

```solidity
// NFTMinter.sol#L154-L155
function mint(address token, uint256 index, address recipient) external returns (bool) {
    return _executeMint(token, index, recipient, "");
}

// NFTMinter.sol#L177-L186
uint256 price = config.price;

// Transfer tokens directly from user to dispatcher (balance-before/after for FOT safety)
uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);
IERC20(token).transferFrom(msg.sender, config.dispatcher, price);
uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

// Grow price: newPrice = oldPrice + (oldPrice * growthBasisPoints / 10000)
config.price = price + (price * config.growthBasisPoints) / 10000;
```

Because neither `mint()` overload accepts a `maxPrice` parameter, callers have no mechanism to specify the maximum price they are willing to pay. A front-runner observing a victim's `mint` transaction in the mempool can:

1. Submit their own `mint` transaction with higher gas priority.
2. The front-runner's mint executes first, increasing `config.price` by `growthBasisPoints`.
3. The victim's transaction executes at the inflated price.
4. With compounding growth, multiple front-run mints amplify the price increase exponentially.

For example, with `growthBasisPoints = 500` (5%):
- A single front-run mint increases the victim's cost by 5%.
- Five compounding front-run mints increase the victim's cost by approximately 27.6% (from an expected 110.25e18 to 140.71e18).

The victim has no way to reject the inflated price since there is no slippage check.

**BalancerPooler zero slippage default**

The `dispatch()` function in `BalancerPooler` defaults `minBptAmountOut` to zero when no `extraData` is provided:

```solidity
// BalancerPooler.sol#L47-L48
function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {
    uint256 minBptAmountOut = extraData.length > 0 ? abi.decode(extraData, (uint256)) : 0;
```

The simpler `mint(address, uint256, address)` overload always passes empty `extraData`:

```solidity
// NFTMinter.sol#L154-L155
function mint(address token, uint256 index, address recipient) external returns (bool) {
    return _executeMint(token, index, recipient, "");
}
```

This means every call through the 3-argument `mint()` overload results in a Balancer liquidity addition with zero slippage protection, making it fully sandwichable. MEV bots can manipulate pool reserves before and after the `dispatch` call to extract value from the single-sided liquidity addition.

### Impact

Users overpay for mints with no ability to set a maximum acceptable price. MEV bots can systematically front-run mint transactions across every mint call, extracting value proportional to `growthBasisPoints` per front-run. The compounding nature of the growth mechanism amplifies the extraction when multiple front-runs are stacked.

For `BalancerPooler`, every mint that uses the simpler 3-argument overload (which passes empty `extraData`) adds liquidity to Balancer with `minBptAmountOut = 0`. This is the well-known zero-slippage anti-pattern that allows sandwich attacks to extract arbitrarily large fractions of the deposited value.

## Recommended mitigation steps

**For NFTMinter**: Add a `maxPrice` parameter to `mint()` and enforce it before transferring tokens:

```solidity
function mint(address token, uint256 index, address recipient, uint256 maxPrice) external returns (bool) {
    // ... existing checks ...
    uint256 price = config.price;
    require(price <= maxPrice, "NFTMinter: price exceeds max");
    // ... rest of function ...
}
```

**For BalancerPooler**: Remove the zero default for `minBptAmountOut`. Either require callers to always specify a non-zero minimum, or compute a reasonable floor based on the deposited amount and current pool state:

```solidity
function dispatch(address caller, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {
    require(extraData.length > 0, "BalancerPooler: minBptAmountOut required");
    uint256 minBptAmountOut = abi.decode(extraData, (uint256));
    require(minBptAmountOut > 0, "BalancerPooler: zero slippage not allowed");
    // ...
}
```
