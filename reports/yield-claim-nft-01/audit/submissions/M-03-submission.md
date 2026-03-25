<!--
C4 Submission Metadata
Title: [M-03] Fee-on-transfer bonding curve price growth uses nominal price instead of actual value received
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L186
PoC File: workspace/yield-claim-nft/test/poc-M-03.t.sol
-->

## Finding description and impact

### Summary

In `NFTMinter._executeMint`, the bonding curve price growth formula on [line 186](https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L186) computes the next mint price using the nominal `price` variable rather than `actualReceived`. The project explicitly supports fee-on-transfer (FOT) tokens -- evidenced by the balance-before/after pattern on lines 180-182, `MockFOTToken.sol` in the test suite, and NatSpec comments referencing FOT-adjusted amounts -- yet the growth calculation ignores the FOT deduction entirely.

### Vulnerability details

The `_executeMint` function correctly measures the actual tokens received by the dispatcher using a balance-before/after pattern and passes `actualReceived` to the dispatcher. However, the price growth formula immediately above uses the nominal `price`:

```solidity
uint256 price = config.price;

// Transfer tokens directly from user to dispatcher (balance-before/after for FOT safety)
uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);
IERC20(token).transferFrom(msg.sender, config.dispatcher, price);
uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

// Grow price: newPrice = oldPrice + (oldPrice * growthBasisPoints / 10000)
config.price = price + (price * config.growthBasisPoints) / 10000; // @audit uses `price`, not `actualReceived`

// Invoke the dispatcher with actual received amount
ATokenDispatcher(config.dispatcher).dispatch(address(this), actualReceived, extraData);
```

The inconsistency is clear: the dispatcher receives the FOT-adjusted `actualReceived`, but the bonding curve advances as if the full nominal amount was collected. Each successive mint compounds this error because the inflated price becomes the base for the next growth calculation.

With a 5% FOT fee and 10% bonding curve growth rate:

- **Nominal growth per mint**: `newPrice = price * 1.10`
- **Fair growth per mint**: `newPrice = actualReceived * 1.10 = price * 0.95 * 1.10 = price * 1.045`

The effective growth rate with nominal-based calculation (10%) is nearly double what it should be when accounting for the FOT fee (4.5%), and this gap compounds with each mint.

### Impact

Later minters pay increasingly inflated prices relative to the actual value entering the protocol. The PoC demonstrates that after just 10 mints with a 5% FOT token:

- Cumulative nominal prices charged: ~1,593.7 tokens
- Total actually received by protocol: ~1,366.4 tokens (14.26% shortfall)
- Final bonding curve price: ~259.4 tokens (nominal-based)
- Fair price if growth used `actualReceived`: ~155.3 tokens
- Price inflation: 40.12% above fair value after only 10 mints

This divergence grows without bound as more mints occur. Users minting later in the curve pay prices that are materially disconnected from the protocol's actual token intake, effectively overpaying relative to the value the protocol holds.

### Note on C4 FOT exclusion scope

The standard C4 exclusion for fee-on-transfer token issues applies when FOT support is not part of the project's scope. Here, the project demonstrably intends to support FOT tokens:
1. `MockFOTToken.sol` exists in the test suite specifically for FOT testing
2. The balance-before/after pattern at lines 180-182 is the canonical FOT-safe transfer pattern
3. NatSpec comments reference "FOT-adjusted amount"
4. `actualReceived` is computed and passed to the dispatcher

The vulnerability is not that FOT tokens behave unexpectedly -- the project handles the transfer correctly. The bug is that the bonding curve growth formula fails to use the FOT-adjusted value it already computes.

## Recommended mitigation steps

Base the price growth calculation on `actualReceived` instead of the nominal `price`:

```diff
- config.price = price + (price * config.growthBasisPoints) / 10000;
+ config.price = actualReceived + (actualReceived * config.growthBasisPoints) / 10000;
```

This ensures the bonding curve reflects the actual value entering the protocol. The growth rate still applies the same percentage increase, but from the correct base amount.

Alternatively, if the protocol intends for the bonding curve to track nominal pricing regardless of FOT fees (treating the fee as an external cost borne by the minter), this should be explicitly documented and the `actualReceived` variable should not be used for growth at all by design choice -- but the current code pattern strongly suggests the intent was to be FOT-aware throughout.
