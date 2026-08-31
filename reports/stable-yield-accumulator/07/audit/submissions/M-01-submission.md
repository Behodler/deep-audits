<!--
C4 Submission Metadata
Title: [M-01] Discount rate boundary allows 10000 (100%), enabling zero-payment yield extraction
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L330
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `setDiscountRate` function in `StableYieldAccumulator.sol` validates that the discount rate does not exceed 10000 basis points using a strict greater-than check (`rate > 10000`). This allows a discount rate of exactly 10000 (100%), which causes the claimer payment formula to evaluate to zero. An NFT holder can then extract all accumulated yield from every registered strategy without transferring any reward tokens to the protocol.

### Vulnerability details

The boundary validation in [`setDiscountRate`](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L329-L335) uses a strict inequality:

```solidity
function setDiscountRate(uint256 rate) external override onlyOwner {
    if (rate > 10000) revert ExceedsMaxDiscount(); // @audit allows rate == 10000

    uint256 oldRate = discountRate;
    discountRate = rate;
    emit DiscountRateSet(oldRate, rate);
}
```

When `discountRate` is set to 10000, the [payment calculation](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L456) in the claim flow produces a zero payment:

```solidity
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
// When discountRate == 10000:
// claimerPayment = totalNormalizedYield * (10000 - 10000) / 10000
// claimerPayment = totalNormalizedYield * 0 / 10000
// claimerPayment = 0
```

The subsequent `_denormalizeAmount` call on zero returns zero, meaning `actualPayment` is also zero. The `safeTransferFrom` succeeds (transferring zero tokens), and `Phlimbo.collectReward(0)` is called. The claimer receives all pending yield tokens from all strategies while Phlimbo stakers receive nothing.

The call sequence proceeds as follows:

1. Owner calls `setDiscountRate(10000)` -- succeeds because `10000 > 10000` is false
2. Claimer calls `claim()` with a valid NFT
3. Yield tokens are transferred from each strategy to the claimer
4. `claimerPayment` evaluates to zero
5. Zero reward tokens are transferred from claimer to the contract
6. Phlimbo receives zero reward tokens for distribution to stakers

### Impact

All accumulated yield across every registered strategy can be extracted without compensation. Phlimbo stakers, who are the intended beneficiaries of the reward token flow, receive nothing. This constitutes a direct value leak from the protocol.

The severity is Medium rather than High because the discount rate can only be set by the contract owner. However, this represents a dangerous configuration that the contract explicitly permits (the boundary check was designed to prevent invalid rates but fails at the edge case). A compromised owner key, a governance misconfiguration, or a misunderstanding of basis point semantics (believing 10000 means "maximum discount" rather than "free extraction") could trigger this condition. The contract should enforce its own invariant that claimers must always pay something.

## Recommended mitigation steps

Change the boundary check from strict greater-than to greater-than-or-equal:

```solidity
function setDiscountRate(uint256 rate) external override onlyOwner {
-   if (rate > 10000) revert ExceedsMaxDiscount();
+   if (rate >= 10000) revert ExceedsMaxDiscount();

    uint256 oldRate = discountRate;
    discountRate = rate;
    emit DiscountRateSet(oldRate, rate);
}
```

As a defense-in-depth measure, add a zero-payment guard in the claim function:

```solidity
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);
+ if (actualPayment == 0) revert ZeroAmount();
```

This second check protects against edge cases where rounding in `_denormalizeAmount` could also produce a zero payment at high discount rates with small yield amounts.
