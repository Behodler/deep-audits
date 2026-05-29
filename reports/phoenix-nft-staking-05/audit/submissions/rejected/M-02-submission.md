<!--
C4 Submission Metadata
Title: [M-02] emergencyWithdraw decrements totalStaked without _updatePool, retroactively repricing the pre-withdraw window at the new smaller denominator
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L452-L461
PoC File: workspace/phoenix-nft-staking/test/poc-M-02.t.sol
-->

## Finding description and impact

### Summary

`NFTStaker.emergencyWithdraw` ([NFTStaker.sol#L452-L461](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L452-L461)) decrements `totalStaked` without first calling `_updatePool`. Because `lastRewardTime` and `accRewardPerShare` stay pinned at their pre-exit values, the next settlement settles the entire `[lastRewardTime, exitTime]` accrual slice at the new, smaller `totalStaked` denominator. The exiting user's forfeited pre-exit share is thereby silently redistributed pro-rata to the remaining stakers on top of their fair entitlement, instead of being retained by the protocol.

### Vulnerability details

#### Root cause

`emergencyWithdraw` is the standard masterchef escape hatch. Per the contract's own NatSpec ([L447-L451](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L447-L451)) and the authoritative spec in `phoenix-nft-staking/CLAUDE.md`, it intentionally "returns principal, forfeits pending reward, **skips `_syncBudget`/`_updatePool`**, and is callable while paused [...] so a broken dispatcher hook, NFT minter, or recompute path can never trap principal." That design property — avoiding any external hook call on the exit path — is in scope and must be preserved.

The implementation at [L452-L461](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L452-L461) is:

```solidity
function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = users[msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "NFTStaker: nothing to withdraw");
    user.amount = 0;
    user.rewardDebt = 0;
    totalStaked -= amount;
    stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
    emit EmergencyWithdrawn(msg.sender, amount);
}
```

The spec acknowledges the `_updatePool` skip. What it does not acknowledge is the accrual-repricing side effect of decrementing `totalStaked` **without first settling accrual at the pre-exit denominator**: the skip is only safe if `_updatePool` has just been called in the same block, and nothing in the code path enforces that.

#### Mechanism

On the next settlement (any `claim`, `stake`, `unstake`, `pullAndRefresh`, `setTargetAPY`, or even the `pendingReward` view), `_updatePool` at [L291-L306](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L291-L306) computes:

```solidity
uint256 end = block.timestamp < windowEnd ? block.timestamp : windowEnd;
uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;
uint256 reward = elapsed * rewardRate;
if (reward > rewardBudget) reward = rewardBudget;
if (reward > 0) {
    rewardBudget -= reward;
    accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;   // NEW denom
}
lastRewardTime = block.timestamp;
```

Because `lastRewardTime` was not advanced on the exit path, `elapsed` now spans the entire `[pre-exit-lastRewardTime, now]` range — including the portion during which the exiting user was still staked. The per-share credit is divided by the post-exit `totalStaked`, so the pre-exit slice is re-priced at the new, smaller denominator. The portion that the exiting user would have been entitled to (and forfeits) is not retained by the protocol — it is redistributed to survivors via the inflated `accRewardPerShare` increment.

`pendingReward` at [L467-L478](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L467-L478) performs the same projection, so the mispricing is visible immediately in the view, not just after settlement.

#### Attack path (no attacker required — this is value leakage)

1. Alice and Bob each stake 10 units at `t0`; `totalStaked = 20`, `lastRewardTime = t0`, `accRewardPerShare = 0`.
2. `+100s` elapse. Nothing is committed to storage yet, but each user has accrued `50*R` of pending reward at the pre-exit denominator (`R = rewardRate`).
3. Bob calls `emergencyWithdraw`. `totalStaked` drops from 20 to 10; `lastRewardTime` stays at `t0`; `accRewardPerShare` stays at 0. Bob forfeits his `50*R`. Under correct accounting, that `50*R` should remain with the protocol.
4. `+100s` more elapse (`now = t0 + 200`).
5. Alice calls `claim()`. `_syncBudget -> _updatePool` computes `elapsed = 200`, `reward = 200*R`, and credits `accRewardPerShare += 200*R * 1e18 / 10`. Alice's pending settles to `10 * (200*R * 1e18 / 10) / 1e18 = 200*R`.

Alice's fair entitlement is `50*R` (slice 1 at denom 20) `+ 100*R` (slice 2 at denom 10) `= 150*R`. She is paid `200*R` — the `50*R` over-allocation is exactly Bob's forfeited pre-exit share.

### Impact

**C4 Medium — value leak with stated assumptions.**

- **Over-emission to survivors.** The protocol pays out more `rewardRate * elapsed` than was actually due under the pre-exit stake distribution. Forfeited accrual that should have been retained by the protocol (staying in `rewardBudget` after the next recompute, or extending the runway) is instead consumed by surviving stakers on top of their fair share.
- **Not direct theft.** No external attacker, no unauthorised access — surviving stakers are not "stealing," they are receiving over-credited emissions that the protocol should have retained. This keeps the finding below High severity.
- **Assumptions are modest and match normal usage.** The leak materialises whenever a measurable accrual window has elapsed since the last `_updatePool` call (any `stake`/`unstake`/`claim`/`pullAndRefresh`/APY-change in the current block would reset it). In a pool with sparse activity — which is the common case once a schedule has been set and stakers are passive — the pre-exit window is routinely non-empty.
- **Foreseeable event path.** The contract's feature spec contemplates `emergencyWithdraw` as an anticipated path (`setStakedId` ID-migration, paused-dispatcher recovery, user panic). Each such exit over a non-trivial window leaks at the pre-exit rate × window × pro-rata-share of the exiter, so the leakage compounds across the deployment's lifetime.
- **Amplifies the M-01 solvency gap.** Over-emissions drain `rewardBudget` faster than the APY schedule assumes, so the runway (`V / R`) computed at the next `_recomputeSchedule` will already be slightly short of the contract's invariant. In combination with the `_safePay` revert introduced for M-01, sustained over-emission increases the likelihood of a hard revert on later claims when the balance runs below `totalDebt`.

Magnitude per event equals `user.amount * rewardRate * (block.timestamp - lastRewardTime) / totalStaked_pre`. In the PoC, with `rewardRate = R` derived from the 30% APY closed form, Alice's over-allocation is exactly `50*R` — Bob's forfeited half of a 100-second pre-exit slice. There is no direct theft, so the ceiling is Medium. It exceeds QA because the leak is non-dust, accumulates deterministically across exits, and the view (`pendingReward`) already reports the buggy number to integrators.

### Proof of Concept

The runnable PoC lives at [`test/poc-M-02.t.sol`](../pocs/poc-M-02.t.sol) and is validated against the in-scope `NFTStaker` at commit `66af47d`. Configuration: `N = 100` NFTs at `price = 100 ether` with `growthBasisPoints = 0` (so `T = price * N = 10_000 ether`), `targetAPY = 30%`, `SEED_BUDGET = 10_000 ether` via `topUp`. This pins the emission rate to the closed-form `R = (T * APY / 1e18) / SECONDS_PER_YEAR`.

Timeline:

1. Alice stakes 10; Bob stakes 10 at `t0`. After both stakes: `totalStaked = 20`, `lastRewardTime = t0`, `accRewardPerShare = 0`, `rewardRate = R`.
2. Warp `+100s`. Both views report `pendingReward = 50*R` (half of `100*R` at denom 20).
3. Bob calls `emergencyWithdraw`. `totalStaked -> 10`; `lastRewardTime` still `t0`; `accRewardPerShare` still `0`. The PoC asserts the buggy post-state directly.
4. Warp another `+100s` to `t0 + 200`.
5. Alice's `pendingReward` is `200*R` — the full 200-second window at denom 10, instead of the fair `150*R` (`50*R` at denom 20 + `100*R` at denom 10).
6. Alice calls `claim()` and actually receives `200*R` phUSD.

Concrete assertions from the PoC (all pass, confirming the bug):

```solidity
// Immediately after Bob's exit — view already doubles.
uint256 aliceImmediatelyAfterExit = staker.pendingReward(alice);
assertEq(
    aliceImmediatelyAfterExit,
    100 * R,
    "alice pending DOUBLED the instant Bob exited (retroactive repricing)"
);
```

```solidity
// After a further +100s, at settlement.
uint256 aliceBuggyPending = staker.pendingReward(alice);
uint256 aliceFairPending  = (100 * R) / 2 + 100 * R; // slice1@denom20 + slice2@denom10 = 150*R
uint256 overAllocation    = aliceBuggyPending - aliceFairPending;

assertEq(aliceBuggyPending, 200 * R,      "buggy pending = 200*R");
assertGt(aliceBuggyPending, aliceFairPending, "buggy > fair");
assertEq(overAllocation, 50 * R,          "over-allocation == bob's forfeited pre-exit share");
```

```solidity
// Not just a view artifact — claim() actually pays the buggy amount.
uint256 alicePhusdBefore = phUSD.balanceOf(alice);
vm.prank(alice);
staker.claim();
uint256 alicePaid = phUSD.balanceOf(alice) - alicePhusdBefore;

assertEq(alicePaid, 200 * R, "alice actually paid the buggy amount via claim()");
assertGt(alicePaid, aliceFairPending, "alice paid strictly more than the fair amount");
```

Exact numerical outcome logged by the PoC: Alice is paid `200*R` wei of phUSD at `t0 + 200`, exceeding her fair `150*R` entitlement by `50*R` — exactly Bob's forfeited pre-exit share.

## Recommended mitigation steps

Settle per-share accrual at the pre-exit denominator **before** decrementing `totalStaked`, without reintroducing any dispatcher-hook call. Specifically: invoke just `_updatePool()` (not the full `_syncBudget`) on entry to `emergencyWithdraw`. This closes out the `[lastRewardTime, now]` slice at the correct pre-exit `totalStaked`, after which decrementing `totalStaked` only affects future accrual.

```diff
 function emergencyWithdraw() external nonReentrant {
     UserInfo storage user = users[msg.sender];
     uint256 amount = user.amount;
     require(amount > 0, "NFTStaker: nothing to withdraw");
+    // Settle per-share accrual at the PRE-exit denominator. Uses only
+    // in-memory state and local accumulators; does NOT call
+    // _syncBudget / dispatcherHook.pull(), so a broken dispatcher hook
+    // or NFT minter still cannot trap principal. Without this, the
+    // caller's forfeited pre-exit share is silently redistributed to
+    // survivors on the next settlement.
+    _updatePool();
     user.amount = 0;
     user.rewardDebt = 0;
     totalStaked -= amount;
     stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
     emit EmergencyWithdrawn(msg.sender, amount);
 }
```

Notes on the fix and spec-level tradeoff:

- The spec's rationale for the skip is to keep `emergencyWithdraw` independent of the dispatcher hook, NFT minter, and recompute path, so that principal can always exit. `_updatePool` touches none of those — it reads only `block.timestamp`, `lastRewardTime`, `windowEnd`, `rewardRate`, `rewardBudget`, and `totalStaked`, all local storage. It performs no external call and cannot revert on hook liveness. The dispatcher-independence guarantee is therefore preserved.
- The wider `_syncBudget` path must **not** be reintroduced on this entrypoint: `_syncBudget` calls `dispatcherHook.pull()`, which is exactly the liveness-dependent external call the spec is protecting against. Keep the exit path limited to `_updatePool`.
- After settlement, the exiting user's forfeited pending is absorbed into `accRewardPerShare` at the pre-exit denominator (so it is already implicitly distributed to the pre-exit cohort, not retroactively re-priced to survivors), and the zeroing of `user.rewardDebt` prevents the exiter from ever claiming it. `totalStaked` is then decremented safely for future accrual.
- No new attacker surface: `_updatePool` is idempotent when called twice in the same block and already runs on every other user interaction.
- The alternative — stranding the forfeited amount back into `rewardBudget` explicitly, matching the prior-run mitigation for the stranding finding — is also acceptable but requires an explicit `rewardBudget += parked` step. The `_updatePool()` call above is strictly simpler and addresses the root cause (accrual not being settled at the pre-exit denominator); stranding-to-budget is a complementary concern and can be added on top without conflict.

### Test-suite regression guard

Add a regression test that mirrors the PoC's structure (two stakers, one `emergencyWithdraw` mid-window, assert `pendingReward(survivor) == fair`) and a same-block test where `_updatePool` was just called via another path (asserting the mitigation is a no-op in that case). Both should pass with the `_updatePool()` line in place and fail without it.
