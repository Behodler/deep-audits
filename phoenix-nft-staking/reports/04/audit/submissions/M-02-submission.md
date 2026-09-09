<!-- METADATA
Title: emergencyWithdraw permanently strands forfeited rewards
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L308-L317
Severity: Medium
-->

## Summary

`NFTStaker.emergencyWithdraw` ([NFTStaker.sol#L308-L317](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L308-L317)) returns a user's principal and zeroes their accounting slot, but never rewinds the portion of `accRewardPerShare` that was already funded on their behalf by earlier `_updatePool` calls. The phUSD backing that parked accrual remains in the contract balance, is absent from `rewardBudget`, and cannot be reached by remaining stakers or by the owner. Each emergency exit with non-zero pending permanently breaks the core accounting invariant `balance == rewardBudget + totalDebt`.

## Vulnerability Details

### Root cause

`emergencyWithdraw` is the masterchef-style escape hatch. Per the contract's own NatSpec ([L303-L307](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L303-L307)), it intentionally does **not** call `_syncBudget` / `_updatePool` so that a broken dispatcher hook can never trap principal. The implementation ([L308-L317](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L308-L317)) performs:

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

The forfeiture of the exiting user's pending reward is spec-blessed. The stranding that follows is not.

### Mechanism

The leak does not originate inside `emergencyWithdraw` itself; it is set up by `_updatePool` ([L219-L234](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L219-L234)) being fired on **other** users' interactions while the soon-to-exit user is still staked with non-zero weight:

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
        accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;
    }
    lastRewardTime = block.timestamp;
}
```

Each such call performs two balanced bookkeeping moves:

1. `rewardBudget` is decremented by `elapsed * rewardRate` (phUSD is now committed).
2. `accRewardPerShare` is credited proportionally to `totalStaked` (including the soon-to-exit user's weight).

At this point the exiting user has an entitlement equal to `user.amount * accRewardPerShare / ACC_PRECISION - user.rewardDebt`. The phUSD backing it is physically in the contract balance but is no longer counted inside `rewardBudget`.

When the user subsequently calls `emergencyWithdraw`, their `amount` and `rewardDebt` are zeroed without any reconciliation. Three things are therefore **not** performed:

- `rewardBudget` is not credited back with the parked portion.
- `accRewardPerShare` is not decremented — remaining stakers' `rewardDebt` was stamped at the older (lower) accumulator, so their pending equals only their own pro-rata share. They do not collect the exiting user's forfeited slice.
- No owner-rescue selector exists to sweep the delta.

The phUSD therefore sits in `rewardToken.balanceOf(address(this))` outside the accounting, permanently.

### Trigger conditions

The stranding materialises on any `emergencyWithdraw` where, at the moment of exit, `user.amount * accRewardPerShare / ACC_PRECISION > user.rewardDebt`. This is the normal case any time a `_syncBudget` / `_updatePool` has fired between the user's last settlement and their emergency call — i.e., any `stake`, `unstake`, `claim`, `pullAndRefresh`, `topUp`, or `setWindowDuration` executed by any party (including the owner) in the interim. The contract documents emergency exits as an anticipated event path (`setStakedId` ID-migration, paused-dispatcher recovery, user panic), so the compounding across multiple exits is a foreseeable steady-state outcome rather than an edge case.

## Impact

**C4 Medium — value leak with stated assumptions and external requirements.**

- **Invariant break.** The contract's own NatSpec on `totalDebt` ([L341-L345](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L341-L345)) explicitly states: *"Derived from the invariant `balance == rewardBudget + totalDebt` (plus bounded floor-division dust in protocol's favor)."* This submission demonstrates that any emergency exit with non-zero pending breaks that invariant by an unbounded amount (not dust), permanently, per event.
- **Value leak, not theft.** The stranded phUSD is neither reclaimable by the exiting user (forfeiture is intentional), nor redistributable to remaining stakers (they do not earn on it), nor recoverable by the owner (no rescue selector). It is dead weight that sits in the contract for the lifetime of the deployment.
- **Scales with staker weight × elapsed accrual.** The per-event loss equals `user.amount * (accRewardPerShare_current - accRewardPerShare_atLastSettlement) / ACC_PRECISION`. Over a long-lived pool with multiple foreseen emergency exits (the design contemplates at least ID migration and hook-failure recovery), the cumulative stranded amount compounds.
- **Observable off-chain.** Integrators relying on `totalDebt()` (which assumes the invariant) will overstate true user claims by the cumulative stranded amount, skewing any dashboards or downstream accounting.

The vulnerability does not enable theft, so the ceiling is Medium. It exceeds QA because the stranded amount is non-dust, accumulates deterministically, and there is no built-in recovery path.

## Proof of Concept

The PoC at [`test/poc-M-02.t.sol`](../pocs/poc-M-02.t.sol) reproduces the leak end-to-end against the in-scope `NFTStaker`. Setup: two stakers (Alice and Bob) each stake 10 units, `rewardRate = 1e12 wei/s`, window = 540 days, budget seeded via `topUp`.

Timeline:

1. Alice stakes 10; Bob stakes 10.
2. 100 seconds pass — nothing is committed to storage yet.
3. Bob calls `claim()`. `_syncBudget -> _updatePool` fires. `rewardBudget` is debited by `100 * RATE = 100e12`, `accRewardPerShare` is credited, Bob is paid his half (`50e12`). Alice's half (`50e12`) is now parked in `accRewardPerShare`.
4. Alice calls `emergencyWithdraw` without claiming first.
5. Window is warped past `windowEnd`; Bob claims and unstakes everything he is ever owed.

The PoC asserts the invariant break directly:

```solidity
// After Bob claims (step 3): invariant still holds.
assertEq(
    contractBalAfterBobClaim,
    budgetAfterBobClaim + debtPreExit,
    "pre-exit: balance == budget + debt (invariant holds)"
);
```

```solidity
// After Alice emergencyWithdraws: budget is NOT re-credited.
assertEq(staker.rewardBudget(), budgetAfterBobClaim, "budget NOT re-credited on exit");
```

```solidity
// After schedule drains and Bob exits: 50e12 phUSD is stranded.
assertGt(finalBalance, finalBudget, "BUG: balance > budget -> dead phUSD");
uint256 strandedPhusd = finalBalance - finalBudget;
assertApproxEqAbs(
    strandedPhusd,
    expectedBobPay,          // 50e12
    10,                      // floor-division dust tolerance
    "stranded phUSD equals Alice's forfeited share (+/- dust)"
);
```

The final step also proves there is no owner-side recovery path: an owner `topUp(1)` increments balance and `rewardBudget` symmetrically, leaving the stranded gap untouched.

```solidity
uint256 stillStranded = phUSD.balanceOf(address(staker)) - staker.rewardBudget();
assertEq(stillStranded, strandedPhusd, "stranded unchanged after topUp recovery attempt");
```

Exact numerical outcome logged by the PoC: `50,000,000,000,000` wei of phUSD (50e12, Alice's forfeited half of the 100-second slice) remain in the contract after the window fully depletes and every legitimate claim has been paid. No function exposed by the contract can move them.

## Recommended Mitigation

Preferred fix — rewind the exiting user's parked accrual back into `rewardBudget` before zeroing their slot. This preserves the escape-hatch property (no `_syncBudget` / `_updatePool` call, no dependence on dispatcher-hook liveness) while restoring the conservation invariant. Forfeited rewards are rolled into future emissions instead of being stranded.

```diff
 function emergencyWithdraw() external nonReentrant {
     UserInfo storage user = users[msg.sender];
     uint256 amount = user.amount;
     require(amount > 0, "NFTStaker: nothing to withdraw");
+    // Rewind the user's already-debited-but-unpaid accrual back into
+    // the reward budget so it rolls into future emissions instead of
+    // stranding. Uses only in-memory state -- does not call
+    // _updatePool, preserving the dispatcher-independent escape hatch.
+    uint256 parked = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
+    if (parked > 0) {
+        rewardBudget += parked;
+    }
     user.amount = 0;
     user.rewardDebt = 0;
     totalStaked -= amount;
     stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
     emit EmergencyWithdrawn(msg.sender, amount);
 }
```

Notes on the fix:

- `accRewardPerShare` is intentionally left untouched. Decrementing it would require dividing by the pre-exit `totalStaked` and would mutate other stakers' pending, inviting rounding drift. Re-budgeting the forfeited amount is cleaner: remaining stakers collect it through the normal schedule, and `_applyAsymmetricWindow` (next inflow) can realise it as an extended window or a rate raise.
- The computation uses only storage already loaded in `user`, so the additional gas cost is negligible (one multiplication, one division, one subtraction, one conditional add).
- The escape-hatch property is preserved: the fix touches only in-memory accumulators and `rewardBudget`. It never calls the dispatcher hook or `_updatePool`, so a broken hook still cannot trap principal.

Alternative (weaker) mitigation: add an owner-only `rescueDust()` that sweeps `balance - rewardBudget - liveTotalDebt`. This recovers stranded phUSD but widens the trust surface (owner can touch reward funds) and requires active operator intervention. Preferred only if changing `emergencyWithdraw` is deemed out of scope.

The remaining option — documenting the stranding as intentional — is not recommended: the `totalDebt` NatSpec (L341-L345) already asserts the invariant that this code path violates.
