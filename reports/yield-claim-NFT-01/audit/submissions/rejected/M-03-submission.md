<!--
C4 Submission Metadata
Title: [M-03] BalancerPooler 1:1 phUSD minting assumes price parity with yield-bearing prime tokens
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/BalancerPooler.sol#L117-L125
PoC File: M-03-poc.t.sol
-->

## Finding description and impact

### Summary

`BalancerPooler._normalizeToPhUSD()` performs only a decimal conversion between the prime token and phUSD, minting phUSD at a strict 1:1 token-count ratio. When the prime token is yield-bearing (e.g., sUSDS, wstETH, sDAI) and therefore worth more than $1.00 per unit, every `dispatch()` call donates an asymmetrically valued pair to the Balancer pool. The resulting imbalance is immediately extractable by arbitrageurs, creating systematic value leakage proportional to the yield premium.

### Vulnerability details

The root cause is in [`_normalizeToPhUSD()`](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/BalancerPooler.sol#L117-L125):

```solidity
function _normalizeToPhUSD(uint256 primeAmount) internal view returns (uint256) {
    uint8 primeDecimals = IERC20Metadata(_primeToken).decimals();
    uint8 phUSDDecimals = IERC20Metadata(_phUSD).decimals();
    if (primeDecimals == phUSDDecimals) return primeAmount;
    if (primeDecimals < phUSDDecimals) {
        return primeAmount * 10 ** (phUSDDecimals - primeDecimals);
    }
    return primeAmount / 10 ** (primeDecimals - phUSDDecimals);
}
```

This function adjusts only for decimal differences between the two tokens. It does not query any oracle, price feed, or pool state to determine the actual market exchange rate.

The function is called in [`unlockCallback()`](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/BalancerPooler.sol#L85-L86) to determine how much phUSD to mint:

```solidity
uint256 phUSDAmount = _normalizeToPhUSD(actualPrimeInVault);
IMintable(_phUSD).mint(address(this), phUSDAmount);
```

The `Accumulator` contract's NatSpec explicitly names sUSDS as the intended prime token:

```solidity
/// @dev Used for tokens like sUSDS that are consumed by other dispatchers (e.g., BalancerPooler).
```

sUSDS is a yield-bearing savings token backed by USDS. Its value increases over time as yield accrues. At a 5% yield premium, 1 sUSDS is worth approximately $1.05 while 1 phUSD is pegged at $1.00.

When `dispatch()` is called with 100 sUSDS:

1. 100 sUSDS ($105 value) is transferred to the Balancer vault.
2. `_normalizeToPhUSD(100e18)` returns `100e18` -- a pure decimal identity, no price scaling.
3. 100 phUSD ($100 value) is minted and transferred to the vault.
4. The pool receives a donation of $105 on the prime side and $100 on the phUSD side.
5. This $5 asymmetry shifts the pool's internal price, creating an immediate arbitrage opportunity.

Arbitrageurs (including MEV bots) rebalance the pool by swapping phUSD for the excess prime tokens, extracting the value difference. The exact extractable amount depends on pool depth and swap fees, but the value leak is guaranteed and cumulative across every `dispatch()` invocation.

### Impact

**Systematic value leakage on every BalancerPooler dispatch.** The protocol permanently loses value proportional to the prime token's yield premium on each call:

- At a 5% yield premium: ~$5 of value imbalance per 100 tokens dispatched.
- Extractable by arbitrageurs immediately after each donation.
- Over 1,000 dispatches at 100 tokens each, the cumulative leak reaches $5,000.
- The leak scales linearly with both dispatch size and yield premium magnitude.

This is not a one-time loss but a persistent drain that occurs on every protocol operation that routes through `BalancerPooler`. As sUSDS accrues more yield over time, the premium (and therefore the leak) grows.

## Recommended mitigation steps

Replace the decimal-only normalization with a price-aware conversion. Two approaches:

**Option A: Query the Balancer pool's spot price ratio**

```solidity
function _normalizeToPhUSD(uint256 primeAmount) internal view returns (uint256) {
    // Get the current pool price of prime token in terms of phUSD
    uint256 primePerPhUSD = IBalancerPool(_pool).getSpotPrice(_primeToken, _phUSD);
    return (primeAmount * primePerPhUSD) / 1e18;
}
```

**Option B: Use an external oracle (e.g., Chainlink)**

```solidity
function _normalizeToPhUSD(uint256 primeAmount) internal view returns (uint256) {
    uint256 primePrice = IPriceOracle(oracle).getPrice(_primeToken);
    uint256 phUSDPrice = IPriceOracle(oracle).getPrice(_phUSD);
    uint8 primeDecimals = IERC20Metadata(_primeToken).decimals();
    uint8 phUSDDecimals = IERC20Metadata(_phUSD).decimals();

    // Scale for both price and decimals
    return (primeAmount * primePrice * 10 ** phUSDDecimals) / (phUSDPrice * 10 ** primeDecimals);
}
```

**Option C: Accept as a design tradeoff and document it.** If the protocol intentionally subsidizes pool liquidity and the yield premium is expected to remain small, document this as a known design decision and add a comment explaining that the 1:1 ratio is intentional despite the value asymmetry. This avoids oracle dependencies and complexity at the cost of a small, predictable value leak.
