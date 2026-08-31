<!--
C4 Submission Metadata
Title: [M-01] emergencyWithdraw skips _updatePool, retroactively repricing the prior accrual window at the post-withdrawal denominator and over-paying surviving stakers
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L538-L561
PoC File: workspace/phoenix-nft-staking/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

`NFTStaker.emergencyWithdraw` decrements `totalStaked` without first calling `_updatePool`. Because `lastRewardTime` and `accRewardPerShare` are not advanced before the mutation, the next `_updatePool` invocation (triggered by any `stake` / `unstake` / `claim` / `pullAndRefresh`) settles the *entire* `[lastRewardTime, now]` window — which spans the period when the exiting user was still in the pool — at the *post-withdrawal* `totalStaked`. The exiting staker's pro-rata share over the pre-exit segment is silently redistributed to surviving stakers instead of being retained by the protocol budget, in direct contradiction of the inline comment on the function.

### Vulnerability details

The vulnerable function at [`NFTStaker.sol#L538-L561`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L538-L561):

```solidity
function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = users[msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "NFTStaker: nothing to withdraw");
    uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    user.amount = 0;
    user.rewardDebt = 0;
    totalStaked -= amount;          // <-- mutated WITHOUT a prior _updatePool
    if (pending > 0) {
        uint256 forfeit = pending > committedDebt ? committedDebt : pending;
        committedDebt -= forfeit;
        rewardBudget += forfeit;
    }
    stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
    emit EmergencyWithdrawn(msg.sender, amount);
}
```

`_updatePool` ([`NFTStaker.sol#L320-L336`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L320-L336)) advances `accRewardPerShare` using the current `totalStaked` as the denominator over the elapsed window:

```solidity
function _updatePool() internal {
    if (block.timestamp <= lastRewardTime) return;
    if (totalStaked == 0) { lastRewardTime = block.timestamp; return; }
    uint256 end = block.timestamp < windowEnd ? block.timestamp : windowEnd;
    uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;
    uint256 reward = elapsed * rewardRate;
    if (reward > rewardBudget) reward = rewardBudget;
    if (reward > 0) {
        rewardBudget -= reward;
        committedDebt += reward;
        accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;
    }
    lastRewardTime = block.timestamp;
}
```

When `emergencyWithdraw` shrinks `totalStaked` without first calling `_updatePool`, the next interaction reprices the *entire* elapsed window — including time the exiting user was contributing to the denominator — at the new, smaller `totalStaked`. The would-be forfeited slice is then silently baked into `accRewardPerShare` and paid to whoever is left.

The inline NatSpec on `emergencyWithdraw` ([`NFTStaker.sol#L532-L537`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L532-L537)) explicitly states the intended forfeit semantics:

> In-flight accrual since the last `_updatePool` is not yet reflected in `accRewardPerShare`, so it is not subtracted here — it stays in `rewardBudget` and is recycled into the next recompute, which is the correct behaviour.

The implementation does the opposite: the in-flight slice is repriced at a smaller denominator and shifted to surviving stakers rather than recycled into `rewardBudget` for the protocol.

#### Attack path

1. Alice and Bob each stake 10 units at `t = 0`. `totalStaked = 20`, `rewardRate = R` sized for the staked subset of 20 units.
2. Bob calls `emergencyWithdraw` at `t = 100`. `totalStaked` drops to 10, but `lastRewardTime` is still 0 and `accRewardPerShare` is still 0 because `_updatePool` was never called.
3. Alice calls `claim` at `t = 200`. `_updatePool` now computes `elapsed = 200`, `reward = 200 * R`, and divides by `totalStaked = 10` — the per-share delta over `[0, 100]` is **2x** what it should have been (the fair denominator was 20).
4. Alice's pending `= 10 * (200 * R * 1e18 / 10) / 1e18 = 200 * R`. The fair allocation is `50R` over `[0, 100]` (pool of 20) plus `100R` over `[100, 200]` (pool of 10) `= 150R`, with `50R` retained as Bob's forfeit.
5. The `50R` that should have stayed in the protocol budget is instead silently shifted to Alice. A coordinated griefer can amplify by stacking emergency exits before another staker's claim.

#### PoC numerical results

The PoC at `workspace/phoenix-nft-staking/test/poc-M-01.t.sol` (passing) deploys two independent fresh `NFTStaker` instances and runs both scenarios end-to-end against the real contract:

- **Scenario A (bug)**: Bob `emergencyWithdraw` at `t = 100`, Alice `claim` at `t = 200`. Alice receives `(T1 + T2) * R = 200 * R`.
- **Scenario B (counterfactual)**: owner triggers `pullAndRefresh()` at `t = 100` — settling `[0, 100]` at the correct denominator of 20 — *before* Bob's exit, then Alice claims at `t = 200`. Alice receives `T1*R/2 + T2*R = 150 * R`.

With `targetAPY = 30%`, `S = 100 NFTs * 100 ether = 10_000 ether`, the rate floors to `R = (S * A) / SECONDS_PER_YEAR ~= 9.51e13 wei/s`. The measured delta `aliceBug - aliceFair` matches the closed-form `T1 * R * BOB_STAKE / (ALICE_STAKE + BOB_STAKE) = 50 * R` to within a 4-wei flooring tolerance, and `assertGt(aliceBug, aliceFair)` confirms the bug-path payout strictly exceeds the fair payout by exactly Bob's pre-exit slice.

### Impact

Value leak: the exiting user's pro-rata share of the `[lastRewardTime, next-interaction]` window is silently redistributed to surviving stakers at the post-withdrawal denominator instead of being retained by the protocol budget. Net consequences:

- **Documented forfeit semantics violated.** The inline comment promises that the in-flight slice "stays in `rewardBudget` and is recycled" — the implementation does the opposite, baking it into `accRewardPerShare` for surviving stakers.
- **APY-as-floor commitment exceeded under stated assumptions.** Surviving stakers receive emissions strictly above `targetAPY` for the affected window, breaking the rate-sizing invariant the protocol advertises (`R = totalStaked * latestPrice * targetAPY / SECONDS_PER_YEAR`).
- **Runway depletion accelerated.** Over-emission relative to budget pulls future `_safePay` shortfalls forward — `_safePay` reverts on insufficient balance, so the trailing edge of stakers can be DoS'd from claiming what they have already accrued.
- **Cumulative drift at scale.** During a `setStakedId` migration or a dispatcher-hook outage where multiple stakers exercise the escape hatch in sequence, every `emergencyWithdraw` between settlements compounds the redistribution. A coordinated griefer can amplify by stacking emergency exits before a target's `claim` to harvest the entire forfeit pool at the survivor denominator.

No special privilege required — any staker can trigger the bug by exercising their own escape hatch, and the redistribution targets the surviving pool rather than the actor.

## Recommended mitigation steps

Settle accrual at the *old* `totalStaked` before the exit mutates the denominator. The minimal patch is a one-line `_updatePool()` call at the head of the function:

```solidity
function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = users[msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "NFTStaker: nothing to withdraw");

    // M-01 fix: settle [lastRewardTime, now] at the OLD totalStaked
    // BEFORE shrinking the denominator. Anchors the per-share split
    // for the pre-exit window at the fair denominator and matches the
    // documented forfeit semantics.
    _updatePool();

    uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    user.amount = 0;
    user.rewardDebt = 0;
    totalStaked -= amount;
    if (pending > 0) {
        uint256 forfeit = pending > committedDebt ? committedDebt : pending;
        committedDebt -= forfeit;
        rewardBudget += forfeit;
    }
    stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
    emit EmergencyWithdrawn(msg.sender, amount);
}
```

Notes on the fix:

- `_updatePool` does *not* call into `dispatcherHook` or `nftMinter`, so this preserves the function's principal-can-always-escape property — a broken hook or recompute path will not trap principal.
- After `_updatePool` runs, `pending` already reflects the exiting user's fair share of the pre-exit window, and the existing `forfeit` accounting (decrementing `committedDebt`, crediting `rewardBudget`) then correctly retains those rewards for the protocol as the inline comment promises.
- Consider adding a regression test that asserts equality between the emergency-exit path and the "settle-then-exit" counterfactual (the structure used by the PoC), so future refactors cannot silently re-introduce the redistribution.

An alternative — keeping `emergencyWithdraw` `_updatePool`-free and instead crediting the surplus to `rewardBudget` via `committedDebt`-style accounting at the next `_recomputeSchedule` — is also possible, but it materially complicates the solvency invariant `balance == rewardBudget + committedDebt` and is harder to audit. The single-line `_updatePool()` head call is the smaller and safer change.
