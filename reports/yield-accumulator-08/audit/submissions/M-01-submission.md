<!--
C4 Submission Metadata
Title: [M-01] Inverted Slippage Protection Allows Claimer to Overpay Without Protection
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L460
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `claim()` function in `StableYieldAccumulator.sol` implements an inverted slippage check. The `minRewardTokenSupplied` parameter enforces a **floor** on the claimer's payment amount (reverts when `actualPayment < minRewardTokenSupplied`), rather than a **ceiling**. This leaves claimers with no on-chain protection against overpayment when conditions change between their off-chain calculation and on-chain execution.

### Vulnerability details

The vulnerable code is located at [StableYieldAccumulator.sol#L456-L460](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L456-L460):

```solidity
// Calculate and collect claimer payment (apply discount)
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

// Slippage protection: revert if actual payment is below caller's minimum
if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();
```

The check `actualPayment < minRewardTokenSupplied` reverts only when the payment is **below** the supplied parameter. This means the parameter acts as a minimum payment guarantee (floor), not a maximum payment cap (ceiling). A claimer who supplies `minRewardTokenSupplied = X` is protected against paying **less** than `X`, but has zero protection against paying **more** than `X`.

The intended purpose of slippage protection in this context is to prevent the claimer from paying more reward tokens than they calculated off-chain. The claimer's workflow is:

1. Call `calculateClaimAmount()` off-chain to determine expected payment `X`
2. Submit `claim(nftId, X)` with `X` as the slippage parameter
3. Expect the transaction to revert if the actual payment exceeds `X`

However, because the check enforces `actualPayment >= minRewardTokenSupplied` rather than `actualPayment <= maxPayment`, step 3 never triggers a revert when the payment increases.

### Attack path

1. Claimer calls `calculateClaimAmount()` off-chain and determines the expected payment is 98e18 (with a 2% discount on 100e18 yield)
2. Claimer submits `claim(nftId, 98e18)` setting `minRewardTokenSupplied = 98e18`
3. Owner front-runs with `setDiscountRate(0)`, reducing the discount from 2% to 0%
4. The claimer's `claim()` executes with `actualPayment = 100e18`
5. The slippage check evaluates `100e18 < 98e18`, which is `false`, so no revert occurs
6. The claimer pays 100e18 instead of the expected 98e18 -- a 2e18 overpayment with no recourse

This scenario is not limited to malicious owner actions. Exchange rate updates, yield fluctuations between strategies, or even benign discount rate adjustments can all cause the actual payment to increase relative to the off-chain estimate.

### Impact

Claimers have no on-chain mechanism to bound their maximum payment. Any state change that increases the payment amount between the off-chain calculation and on-chain execution results in the claimer paying more reward tokens than intended. While the claimer receives proportionally more yield tokens, those yield tokens may not be worth the additional cost at prevailing market rates.

The severity is Medium because:
- The claimer's funds are not stolen, but they are spent in excess of their expectation
- The protocol's slippage protection feature exists but is functionally inverted, failing to serve its stated purpose
- The attack requires a state change (discount rate, exchange rate) between calculation and execution, which is a realistic but not guaranteed condition

## Recommended mitigation steps

Replace the floor check with a ceiling check, or add a separate `maxRewardTokenPayment` parameter. The simplest fix changes the existing parameter semantics:

```solidity
// Slippage protection: revert if actual payment EXCEEDS caller's maximum
if (actualPayment > maxRewardTokenPayment) revert ExcessivePayment();
```

If backward compatibility with the floor semantic is desired (e.g., for claimers who want to ensure minimum yield value), both bounds can be supported:

```solidity
function claim(
    uint256 nftIndex,
    uint256 minRewardTokenSupplied,
    uint256 maxRewardTokenPayment
) external override whenNotPaused nonReentrant {
    // ... existing logic ...

    // Floor: ensure enough yield to be worth claiming
    if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();
    // Ceiling: protect against overpayment
    if (actualPayment > maxRewardTokenPayment) revert ExcessivePayment();

    // ... continue with transfer ...
}
```

### Proof of Concept

The PoC is located at `workspace/stable-yield-accumulator/test/poc-M-01.t.sol`.

The primary test `test_M01_InvertedSlippageProtection` demonstrates the full attack path:

```solidity
function test_M01_InvertedSlippageProtection() public {
    // Step 1: Initial state - discount rate is 2% (200 basis points)
    accumulator.setDiscountRate(200);

    // Claimer queries expected payment off-chain
    uint256 expectedPayment = accumulator.calculateClaimAmount();
    assertEq(expectedPayment, 98e18, "Expected payment should be 98e18 with 2% discount");

    // Step 2: Claimer sets minRewardTokenSupplied = 98e18 as slippage protection
    uint256 slippageParam = expectedPayment;

    // Fund claimer and mint NFT
    rewardToken.mint(claimer, 200e18);
    vm.prank(claimer);
    rewardToken.approve(address(accumulator), type(uint256).max);
    mockNFTMinter.mintNFT(claimer, 1, 1);

    // Step 3: Owner front-runs by reducing discount to 0%
    accumulator.setDiscountRate(0);
    uint256 newExpectedPayment = accumulator.calculateClaimAmount();
    assertEq(newExpectedPayment, 100e18, "Payment should now be 100e18 with 0% discount");

    // Step 4: Claimer's claim() SUCCEEDS despite paying MORE than expected
    uint256 claimerBalanceBefore = rewardToken.balanceOf(claimer);
    vm.prank(claimer);
    accumulator.claim(1, slippageParam);

    uint256 claimerBalanceAfter = rewardToken.balanceOf(claimer);
    uint256 actualPaymentMade = claimerBalanceBefore - claimerBalanceAfter;

    // Step 5: Verify overpayment
    assertEq(actualPaymentMade, 100e18, "Claimer paid 100e18 (full amount, no discount)");
    assertEq(actualPaymentMade - expectedPayment, 2e18, "Claimer overpaid by 2e18");
    assertTrue(actualPaymentMade > expectedPayment, "Claimer paid MORE than expected");

    // The critical assertion: minRewardTokenSupplied did NOT protect against overpayment
    assertTrue(
        actualPaymentMade >= slippageParam,
        "BUG: minRewardTokenSupplied only enforces a FLOOR - passed because 100e18 >= 98e18"
    );
}
```

A supplementary test `test_M01_SlippageOnlyProtectsFloor` confirms the check only reverts when payment falls below the parameter, proving the floor-only behavior.
