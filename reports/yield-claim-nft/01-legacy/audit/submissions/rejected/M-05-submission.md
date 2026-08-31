<!--
C4 Submission Metadata
Title: [M-05] Price growth stagnation due to integer rounding at low prices
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/main/src/NFTMinter.sol#L139
PoC File: poc-M-05.t.sol
-->

## Finding description and impact

### Summary

The price growth formula in `NFTMinter.mint()` suffers from integer division truncation that causes the price to permanently stagnate when `price * growthBasisPoints < 10000`. This breaks the bonding curve mechanism, allowing unlimited minting at a fixed low price that was designed to escalate with demand.

### Vulnerability details

The vulnerable code is in `NFTMinter.sol` at line 139, within the `mint` function:

```solidity
// Grow price: newPrice = oldPrice + (oldPrice * growthBasisPoints / 10000)
config.price = price + (price * config.growthBasisPoints) / 10000;
```

In Solidity, integer division truncates toward zero. When the product `price * config.growthBasisPoints` is less than `10000`, the division yields zero and the price increment is discarded entirely. The price is set to `price + 0`, which is unchanged.

This is not a one-time rounding error -- it is a permanent condition. Because the price never increases, subsequent mints continue to evaluate the same expression with the same result, creating an infinite stagnation loop.

**Concrete examples:**

| `price` (wei) | `growthBps` | `price * growthBps` | `/ 10000` | Increment | Result |
|---|---|---|---|---|---|
| 50 | 100 (1%) | 5,000 | 0 | 0 | Stagnant forever |
| 99 | 100 (1%) | 9,900 | 0 | 0 | Stagnant forever |
| 100 | 100 (1%) | 10,000 | 1 | 1 | Grows correctly |
| 50 | 200 (2%) | 10,000 | 1 | 1 | Grows correctly |

The stagnation threshold is deterministic: any `price < ceil(10000 / growthBasisPoints)` will never grow.

**Attack path:**

1. Owner registers a dispatcher via `registerDispatcher()` with a small `initialPrice` and a reasonable `growthBasisPoints` value (e.g., 50 wei at 1%).
2. Users call `mint()` repeatedly. Each mint charges the same stagnant price.
3. The price bonding curve, intended to increase cost as demand grows, is completely bypassed.
4. All mints occur at the initial low price indefinitely, rather than following the escalating curve the protocol intended.

### Impact

The price growth mechanism is a core economic invariant of the NFT minting system. When it fails:

- **Broken bonding curve**: The escalating price model, which is the primary economic mechanism for demand-based pricing, produces a flat line instead of a curve. This fundamentally changes the economic properties of the system.
- **Unlimited cheap minting**: Users can mint an unlimited number of NFTs at the fixed initial price. For a system designed around scarcity via escalating costs, this removes the intended economic constraint.
- **Not purely admin misconfiguration**: While the owner sets `initialPrice`, the rounding behavior is a mathematical property of the formula that is not documented or guarded against. An owner setting a "small but nonzero" price has no indication that growth will silently fail. For 6-decimal tokens like USDC, 100 wei equals 0.0001 USDC -- a borderline realistic configuration where this issue manifests.

## Recommended mitigation steps

Add a minimum increment of 1 wei when the growth formula rounds to zero but growth is configured:

```solidity
// Grow price: newPrice = oldPrice + (oldPrice * growthBasisPoints / 10000)
uint256 increment = (price * config.growthBasisPoints) / 10000;
if (increment == 0 && config.growthBasisPoints > 0) {
    increment = 1;
}
config.price = price + increment;
```

Alternatively, enforce a minimum price floor during `registerDispatcher()` that guarantees the growth formula produces a nonzero increment:

```solidity
function registerDispatcher(address dispatcher, uint256 initialPrice, uint256 growthBasisPoints) external onlyOwner {
    if (growthBasisPoints > 0) {
        require(
            initialPrice * growthBasisPoints >= 10000,
            "NFTMinter: initialPrice too low for configured growth rate"
        );
    }
    // ... rest of registration
}
```

The first approach (minimum increment fallback) is preferred because it is self-healing and does not restrict the configuration space.
