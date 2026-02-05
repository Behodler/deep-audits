<!--
C4 Submission Metadata
Title: [M-02] collectReward Call Does Not Verify Token Transfer
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L456-L457
PoC File: M-02-poc.t.sol
-->

## Finding description and impact

### Summary

The `claim()` function in StableYieldAccumulator transfers payment tokens from the claimer to the contract, then calls `IPhlimbo(phlimbo).collectReward(actualPayment)` without verifying that Phlimbo actually pulled the tokens. If Phlimbo's `collectReward` implementation fails to transfer tokens (due to a bug, paused state, or insufficient allowance), the payment tokens become permanently stuck in the accumulator with no recovery mechanism.

### Vulnerability details

The vulnerable code at [StableYieldAccumulator.sol#L456-L457](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L456-L457):

```solidity
// Transfer reward tokens FROM claimer TO this contract, then have Phlimbo collect them
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
IPhlimbo(phlimbo).collectReward(actualPayment);
```

The issue is that after transferring tokens from the claimer to the accumulator, the contract assumes `collectReward()` will successfully pull those tokens to Phlimbo. However, if `collectReward()` completes without actually transferring tokens (possible scenarios include):

1. **Buggy Phlimbo implementation** - `collectReward` records the amount but fails to execute `transferFrom`
2. **Paused state** - Phlimbo is paused and silently skips the transfer
3. **Insufficient allowance** - The allowance from accumulator to Phlimbo was not set or was consumed

In any of these cases:
- The `claim()` transaction succeeds
- The claimer receives their yield tokens
- Payment tokens remain stuck in the accumulator
- Phlimbo receives nothing
- Stakers are left without rewards

### Impact

**Loss of Funds**: Payment tokens become permanently stuck in StableYieldAccumulator with no recovery mechanism. The PoC demonstrates 98 tokens stuck after a single claim (with 2% discount on 100 tokens of yield).

**Staker Reward Loss**: Phlimbo stakers receive no stable rewards despite yield being claimed from strategies. The protocol's core value proposition (distributing yield to stakers) fails silently.

**Compounding Problem**: Each subsequent claim adds more stuck tokens. The PoC shows 294 tokens stuck after just 3 claims. In production with real yield, this could accumulate to significant losses.

**No Recovery Path**: There is no admin function or mechanism to recover tokens stuck in the accumulator. Once stuck, they are permanently inaccessible.

## Recommended mitigation steps

Verify the token balance decreased after calling `collectReward()` to ensure Phlimbo actually pulled the tokens:

```solidity
// Transfer reward tokens FROM claimer TO this contract, then have Phlimbo collect them
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
IPhlimbo(phlimbo).collectReward(actualPayment);
uint256 balanceAfter = IERC20(rewardToken).balanceOf(address(this));

if (balanceBefore - balanceAfter < actualPayment) {
    revert PhlimboDidNotCollect();
}
```

This pattern ensures that if Phlimbo fails to pull the expected amount, the entire transaction reverts, protecting both the claimer (who keeps their payment tokens) and the protocol (which doesn't distribute yield without receiving payment).
