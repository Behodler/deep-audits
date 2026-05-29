<!--
C4 Submission Metadata
Title: [M-01] Partial `_safePay` shortfall in `claim`/`stake`/`unstake` silently forfeits user rewards by advancing `rewardDebt` to the full accrual
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L313-L316
PoC File: workspace/phoenix-nft-staking/test/poc-CS-01.t.sol
-->

## Finding description and impact

### Summary
All three reward payout paths in `NFTStaker` (`claim`, `stake`, `unstake`) compute a user's `pending` entitlement, hand it to `_safePay`, and then unconditionally set `user.rewardDebt` to the full accrued amount `(user.amount * accRewardPerShare) / ACC_PRECISION`. Because `_safePay` silently caps the transfer at the contract's on-chain `rewardToken` balance, any shortfall between `pending` and the amount actually paid is permanently erased from the user's entitlement. A later top-up of the reward token does not restore the lost amount.

### Vulnerability details
The root cause lives in the bookkeeping that follows `_safePay`. For `claim` ([`NFTStaker.sol#L313-L316`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L313-L316)):

```solidity
if (pending > 0) {
    uint256 paid = _safePay(pending);
    user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;
    if (paid > 0) emit Claimed(msg.sender, paid);
}
```

`_safePay` ([L325-L332](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L325-L332)) applies a balance cap over the *entire* on-chain reward balance, not a bounded dust correction:

```solidity
function _safePay(uint256 amount) internal returns (uint256) {
    uint256 balance = rewardToken.balanceOf(address(this));
    uint256 paid = amount > balance ? balance : amount;
    if (paid > 0) {
        rewardToken.safeTransfer(msg.sender, paid);
    }
    return paid;
}
```

`rewardDebt` is then advanced as if the user had been paid in full. The identical pattern appears in `stake` ([L256-L280](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L256-L280)) and `unstake` ([L282-L305](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L282-L305)), where `user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION` is assigned regardless of whether the prior `_safePay` paid the full pending amount.

The NatSpec on `_safePay` frames the cap as a guard against 1-wei floor-division drift, but nothing in the implementation bounds the shortfall to dust. The cap triggers for any amount `balance < pending`. Realistic ways this happens in production:

1. **Multi-staker ordering.** Two stakers have accrued balances. The first claims and drains most of the on-chain balance; the second then claims before the next `dispatcherHook.pull()` has caught up. `_syncBudget` only settles accrual under the current rate - it does not guarantee `balance >= pending` for the caller.
2. **Hook pull timing.** `_syncBudget` calls `dispatcherHook.pull()`, but `pull()` may mint less than is currently accrued per `accRewardPerShare` due to schedule mismatches between the dispatcher and the staker's own window. The delta is silently absorbed by `_safePay`.
3. **Direct balance dips.** Any path that reduces `rewardToken.balanceOf(address(this))` below `pending` for a claim - including an emergency admin action, a buggy future hook, or a prior `_safePay` in the same block - triggers the cap.

Because `rewardDebt` jumps to the *full* accrual on every payout, the unpaid delta can never be recovered on a subsequent call: `pendingReward` returns zero, and later reward-token top-ups raise the budget for *future* accrual only. This also violates the `balance == rewardBudget + totalDebt` invariant in the protocol's favor (by zeroing debt the user was owed).

Additionally, `claim` only updates `user.rewardDebt` inside the `if (pending > 0)` branch while `stake`/`unstake` update it unconditionally - an inconsistency that should be reconciled at the same time as the primary fix.

### Impact
Users who transact while the contract's on-chain reward balance is below their accrued `pending` permanently forfeit the shortfall. The loss is not bounded to dust; it equals `pending - balance` at the moment of the call, which can be an arbitrary fraction of the user's earnings (the accompanying PoC demonstrates a 40% loss on a single claim). The shortfall is unrecoverable because `rewardDebt` has already advanced past it - a later `pull()` or `topUp` that restores the balance does not re-credit the user. This is a direct, deterministic loss of earned rewards under ordinary multi-staker operation, and qualifies as High severity under C4 criteria (assets lost via a valid attack path without extraordinary assumptions).

### Proof of concept
A runnable Foundry PoC asserting exact-wei loss lives at `workspace/phoenix-nft-staking/test/poc-CS-01.t.sol` and is reproduced in the separate PoC form field. Run with `forge test --match-contract CS01PoCTest -vv`. It exercises two paths:

- `test_CS01_PartialSafePayForfeitsShortfallPermanently` - Alice stakes 10 NFT units and accrues 10,000 phUSD; the contract balance is reduced to 6,000 phUSD; Alice calls `claim()` and receives 6,000; the contract is then topped back up to 1,000,000 phUSD; Alice calls `claim()` again and receives `0`. The forfeited shortfall is asserted at exactly 4,000 phUSD.
- `test_CS01_UnstakePathAlsoForfeitsShortfall` - identical scenario exercised through `unstake()`, confirming the root cause is shared across payout paths.

## Recommended mitigation steps

Revert when `_safePay` cannot pay `pending` in full, after `_syncBudget`/`dispatcherHook.pull()` has already pulled everything currently mintable from the dispatcher. All three payout paths already call `_syncBudget` before `_safePay`, so the effective threshold at the point of the check is `balance + mintable-from-pull`; if `pending` still exceeds that, the transaction should revert rather than pay partially:

```solidity
function _safePay(uint256 amount) internal returns (uint256) {
    uint256 balance = rewardToken.balanceOf(address(this));
    if (amount > balance) revert InsufficientRewardBalance();
    rewardToken.safeTransfer(msg.sender, amount);
    return amount;
}
```

The natural-looking alternative - keep the balance cap but only advance `rewardDebt` by the amount actually paid, so the unpaid portion rolls forward - preserves total entitlement on paper but turns every shortfall into a first-come-first-serve race on the remaining liquidity: the quickest claimant (or the one bidding the highest gas) drains what is available and every subsequent caller receives zero until the next top-up. It also requires additional state to handle the full-unstake case (where `user.amount == 0` after the decrement zeroes out any rolled-over debt unless tracked in a separate carry slot). Reverting surfaces the shortfall loudly to callers and monitoring, lets the protocol gate payouts on a restored budget, preserves the `balance == rewardBudget + totalDebt` invariant without a race, and needs no extra bookkeeping.

`emergencyWithdraw` remains the escape hatch for users who wish to exit without claiming when the reward budget is temporarily short. If persistent `pull()` schedule mismatch is a concern, a permissionless hook that forces a dispatcher top-up should be considered separately - that is a liveness fix, not a correctness fix.

Additionally, reconcile `claim` to unconditionally update `user.rewardDebt` (matching `stake`/`unstake`) to close the minor inconsistency in that function's control flow.

Add a unit test that simulates a shortfall scenario and asserts the payout path reverts rather than paying partially.
