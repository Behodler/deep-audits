<!-- METADATA
Title: Budget stranded post-expiry when schedule expires with no dispatcher inflow
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L203-L214
Severity: Medium
-->

## Summary

`_syncBudget` short-circuits on `if (inflow == 0) return;` before it ever reaches `_applyAsymmetricWindow`. When the schedule expires while the dispatcher hook has zero mint-debt to hand over (steady state), the post-expiry reset branch never fires, so any leftover `rewardBudget` is permanently stranded. Emissions halt until the owner manually calls `topUp`, contradicting the feature spec's explicit intent that "windows auto-restart on pull" and that emissions continue against the existing schedule.

## Vulnerability Details

Two cooperating code paths combine to strand legitimate emission budget:

### 1. `_syncBudget` exits before the reset branch when inflow is zero

[`NFTStaker.sol#L203-L214`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L203-L214):

```solidity
function _syncBudget() internal {
    _updatePool();
    if (address(dispatcherHook) == address(0)) return;
    uint256 pre = rewardToken.balanceOf(address(this));
    dispatcherHook.pull();
    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
    if (inflow == 0) return;              // <-- early exit
    rewardBudget += inflow;
    _applyAsymmetricWindow(inflow);        // <-- never reached in zero-inflow case
    emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
}
```

The reset branch lives inside `_applyAsymmetricWindow` at [L189-L200](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L189-L200):

```solidity
function _applyAsymmetricWindow(uint256 inflow) internal {
    uint256 candidate = windowDuration > 0 ? rewardBudget / windowDuration : 0;
    bool scheduleExpired = block.timestamp >= windowEnd;
    if (scheduleExpired || candidate > rewardRate) {
        // Bootstrap, post-expiry restart, or legitimate rate raise - full reset.
        rewardRate = candidate;
        windowEnd = block.timestamp + windowDuration;
    } else if (rewardRate > 0) {
        windowEnd += inflow / rewardRate;
    }
}
```

Because the `scheduleExpired` reset branch can only fire from within `_applyAsymmetricWindow`, and the only non-privileged entry point to that helper is `_syncBudget`, a post-expiry reset is impossible whenever `dispatcherHook.pull()` yields zero. Only the owner-only `topUp` (which calls `_applyAsymmetricWindow` directly at L168) can unstrand the funds.

### 2. `_updatePool` freezes emissions once `windowEnd` is in the past

[`NFTStaker.sol#L219-L234`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L219-L234):

```solidity
function _updatePool() internal {
    if (block.timestamp <= lastRewardTime) return;
    if (totalStaked == 0) {
        lastRewardTime = block.timestamp;
        return;
    }
    uint256 end = block.timestamp < windowEnd ? block.timestamp : windowEnd;
    uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;
    ...
}
```

`end` is clamped to `windowEnd`, so once `lastRewardTime >= windowEnd`, `elapsed` is always zero and no further emissions accrue. `currentRewardRate()` at L336-L339 also returns `0` once `block.timestamp >= windowEnd`.

### Attack path (no attacker required - this is value leakage)

1. Owner tops up `B = 540 days * rate`. `windowEnd = now + 540 days`.
2. All stakers unstake at `t = windowEnd - 1 day`. During the 1-day zero-stake tail, `_updatePool` skips accrual (`totalStaked == 0`) and just bumps `lastRewardTime`; `rewardBudget` is preserved - correctly, since no one was owed anything.
3. `block.timestamp` advances past `windowEnd`. The dispatcher hook has no mint-debt to pull (steady state).
4. A new staker arrives and calls `stake()`. `_syncBudget -> _updatePool` (elapsed clipped to 0) `-> dispatcherHook.pull()` returns zero `-> if (inflow == 0) return;`. `_applyAsymmetricWindow` is never entered.
5. The schedule stays expired, `rewardBudget` still holds ~1 day of rate, `currentRewardRate()` returns `0`, and every subsequent `stake` / `unstake` / `claim` produces zero emissions.

## Impact

Legitimate reward budget that the spec explicitly says should roll into the next 540-day schedule is instead silently locked in the contract. Concrete consequences:

- **Stakers lose expected emissions**: users who rejoin after a zero-stake gap receive `0` phUSD despite the contract holding a non-zero `rewardBudget` and having a configured `rewardRate`.
- **Protocol's advertised emission continuity is broken**: feature-spec item 5 states "emissions continue against the existing schedule" when `pull()` yields zero. In the expired-window case, emissions stop entirely.
- **Recovery requires privileged action**: only `topUp` (owner-only, requires transferring real phUSD) can reset the schedule. `pullAndRefresh` and all user-facing entrypoints hit the same zero-inflow early return.

Magnitude equals `rewardRate * (total zero-stake gap duration)` plus floor-division residuals. In the PoC, `rate = 1e12 wei/s` and a 1-day tail produces 86,400,000,000,000,000 wei (`1e12 * 86_400`) of stranded phUSD per cycle.

Assumptions (as flagged by C4 Medium criteria): a zero-stake tail occurs before `windowEnd`, and no owner `topUp` happens during the expired gap. No direct theft, but real phUSD is locked with no on-chain recovery path other than owner intervention.

## Proof of Concept

The runnable Foundry PoC lives at [`test/poc-M-01.t.sol`](../pocs/poc-M-01.t.sol) and is validated against the in-scope version of `NFTStaker.sol`. It seeds a 540-day schedule at `RATE = 1e12 wei/s`, has an honest staker unstake 1 day before `windowEnd`, warps 7 days past expiry, and then shows that a new staker's interactions cannot revive the schedule.

Key assertions (all pass, confirming the bug):

```solidity
// After the window has expired with no dispatcher inflow:
assertLt(staker.windowEnd(), block.timestamp, "windowEnd is in the past");
assertEq(staker.currentRewardRate(), 0, "currentRewardRate clamps to 0 post-expiry");
assertGt(staker.rewardBudget(), 0, "rewardBudget is still non-zero (stranded)");

// After a new staker calls stake() post-expiry:
assertEq(
    windowEndAfterNewStake, windowEndBeforeNewStake,
    "BUG: windowEnd was not reset on stake despite expired schedule + non-zero budget"
);
assertEq(
    budgetAfterNewStake, budgetBeforeNewStake,
    "BUG: rewardBudget unchanged -- no emissions resumed"
);

// After 30 more days and multiple claim() / pullAndRefresh() calls:
assertEq(
    phUSD.balanceOf(newStaker), 0,
    "BUG: new staker received zero phUSD despite 30 days of staking"
);

// Sanity: only the privileged topUp path can recover.
vm.prank(owner);
staker.topUp(1);
assertGt(staker.windowEnd(), block.timestamp, "topUp(1) DID reset the schedule (recovery path)");
```

The PoC also exercises `claim()` and `pullAndRefresh()` to confirm that every non-privileged entrypoint hits the same early return and cannot unstrand the funds.

## Recommended Mitigation

Move the post-expiry reset out from under the zero-inflow guard. The simplest surgical fix is to invoke `_applyAsymmetricWindow(0)` whenever the schedule has expired and `rewardBudget > 0`, regardless of inflow:

```diff
 function _syncBudget() internal {
     _updatePool();
     if (address(dispatcherHook) == address(0)) return;
     uint256 pre = rewardToken.balanceOf(address(this));
     dispatcherHook.pull();
     uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
-    if (inflow == 0) return;
-    rewardBudget += inflow;
-    _applyAsymmetricWindow(inflow);
-    emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
+    if (inflow == 0) {
+        // Still allow a post-expiry reset if there is leftover budget.
+        if (block.timestamp >= windowEnd && rewardBudget > 0) {
+            _applyAsymmetricWindow(0);
+            emit Pulled(0, rewardBudget, rewardRate, windowEnd);
+        }
+        return;
+    }
+    rewardBudget += inflow;
+    _applyAsymmetricWindow(inflow);
+    emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
 }
```

This preserves the existing invariants:

- `_applyAsymmetricWindow(0)` with `scheduleExpired == true` hits the reset branch and sets `rewardRate = rewardBudget / windowDuration`, `windowEnd = now + windowDuration` - exactly the documented "post-expiry restart" behaviour.
- The monotonic-upward `rewardRate` invariant is unaffected (the reset branch fires on `scheduleExpired || candidate > rewardRate`, both of which are already permitted rate changes).
- No new attacker surface: a zero-stake EOA calling `claim()` post-expiry just triggers the legitimate reset the spec already promises.

### Optional secondary hardening

The finding notes a related dust source: when `_updatePool` detects a zero-stake gap (`totalStaked == 0`, `elapsed > 0`), the window keeps ticking but no emissions accrue, leaving `rewardBudget / remainingWindow` out of proportion to the originally-set rate. Consider shortening `windowEnd` by `elapsed` at [L221-L224](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L221-L224) to keep the effective rate consistent across zero-stake gaps:

```solidity
if (totalStaked == 0) {
    uint256 gap = block.timestamp - lastRewardTime;
    if (block.timestamp < windowEnd) {
        windowEnd += gap;           // slide the window forward by the zero-stake gap
    }
    lastRewardTime = block.timestamp;
    return;
}
```

This is a behavioural change and should be weighed against the spec's current "zero-stake gap preserves budget" intent, but it eliminates the accumulation of stranded budget across multiple zero-stake periods within a single cycle.
