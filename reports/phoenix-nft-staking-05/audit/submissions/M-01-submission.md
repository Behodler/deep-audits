<!--
C4 Submission Metadata
Title: [M-01] `_recomputeSchedule` re-inflates `rewardBudget` to full balance, double-counting already-committed accrual and DoSing late claimers
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L375
PoC File: workspace/phoenix-nft-staking/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

`_recomputeSchedule` unconditionally resets `rewardBudget = V` where `V = balance + mintDebt` ([`NFTStaker.sol#L365-L376`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L365-L376)). When it fires from `_syncBudget`, the preceding `_updatePool` call has just moved an amount `X = elapsed * rewardRate` from `rewardBudget` into `accRewardPerShare` — i.e. into committed user debt — without changing `balance`. The reset therefore re-inflates `rewardBudget` by exactly `X`, and the newly derived `windowEnd = now + V / R` promises a fresh full runway on top of debt the contract has already accrued. Over the next runway, cumulative emissions exceed the on-chain balance and late claimers revert in `_safePay` with `"NFTStaker: insufficient reward balance"`. Principal remains recoverable via `emergencyWithdraw`, but earned rewards are stranded until the owner tops up.

### Vulnerability details

#### Root cause

The recompute unconditionally overwrites `rewardBudget` with the total phUSD value `V` the contract *can* see, without subtracting the portion `_updatePool` has just committed to `accRewardPerShare`. From [`NFTStaker.sol#L340-L378`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L340-L378):

```solidity
function _recomputeSchedule() internal {
    ...
    uint256 V = rewardToken.balanceOf(address(this));
    if (address(dispatcherHook) != address(0)) {
        V += dispatcherHook.mintDebt();
    }

    uint256 F = T.mulDiv(targetAPY, APY_PRECISION);
    uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;
    uint256 runway = (newRate == 0) ? 0 : V / newRate;

    rewardRate = newRate;
    rewardBudget = V;                     // <-- bug: ignores pre-committed debt
    windowEnd = block.timestamp + runway; // <-- runway derived from inflated budget
    ...
}
```

The intent behind `V = balance + mintDebt` is a bootstrap-style recompute: at the *initial* recompute there is no committed debt, so `V` is the full available reward pool. But `_recomputeSchedule` also runs from every subsequent `_syncBudget`, where the preceding `_updatePool` has already spent part of that balance on accrual.

#### Mechanism

`_syncBudget` ([L272-L285](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L272-L285)) chains the two helpers:

```solidity
function _syncBudget() internal {
    _updatePool();                         // step 1: commits X to accRewardPerShare, rewardBudget -= X
    if (address(dispatcherHook) == address(0)) {
        _recomputeSchedule();              // step 2: rewardBudget = V (ignores X)
        return;
    }
    uint256 pre = rewardToken.balanceOf(address(this));
    dispatcherHook.pull();
    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
    _recomputeSchedule();
    ...
}
```

`_updatePool` ([L291-L306](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L291-L306)) advances the accumulator by `X = elapsed * rewardRate`, subtracting `X` from `rewardBudget` and crediting it to `accRewardPerShare`. `balance` is untouched at this point — the phUSD is still physically in the contract but is now earmarked for users via their `pendingReward` entitlement. The very next line of `_recomputeSchedule` reads `V = balance + mintDebt` and assigns `rewardBudget = V`, restoring the full pre-accrual value. The invariant `balance == rewardBudget + totalDebt` documented at [L340-L342 of the totalDebt NatSpec](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol) is broken at recompute by exactly `X`.

Worse, `windowEnd = now + V / R` derives a *new* runway from the inflated `V`. The contract now promises:

- `X` phUSD of already-committed accrual (in `accRewardPerShare`); plus
- `V / R * R = V` phUSD of future emissions over the new window.

Total committed emissions = `X + V`. Available balance = `X + (V - X) = V`. Shortfall = `X`.

Every recompute between an accrual and its claim compounds this: the `X` that `_updatePool` commits at that recompute is re-inflated again. Under the spec's "pull-on-interaction" model ([feature-spec item 5](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/CLAUDE.md)), every `stake` / `unstake` / `claim` / `topUp` / `setTargetAPY` / `pullAndRefresh` triggers a recompute, so the shortfall accumulates quickly under normal activity.

#### Trigger conditions

Any scenario where at least one recompute fires between a staker's accrual and that staker's claim. This is the default — the only way to avoid it is for a staker to be the *only* interaction after their own last settlement, which is not a property the contract enforces or documents. No privilege, no external manipulation, and no unusual configuration is required.

The `_safePay` guard at [L439-L445](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L439-L445) converts the over-commitment into a hard revert rather than silent forfeiture — which is the correct behaviour given the invariant break, but it means the earned-reward path DoSes once the shortfall lands.

### Impact

**C4 Medium — availability impact plus value leak with stated assumptions.**

- **Protocol invariant break.** The `totalDebt` NatSpec asserts `balance == rewardBudget + totalDebt` (plus floor-division dust). This finding demonstrates the invariant is broken by a non-dust amount at every recompute-after-accrual, and the break compounds across recomputes within a runway.
- **Claim-path DoS for late claimers.** Once committed debt exceeds balance, first claimers are paid in full and subsequent claimants hit `_safePay` and revert with `"NFTStaker: insufficient reward balance"`. Their earned rewards are stranded — not forfeited, but unreachable until the owner tops up enough to cover the gap.
- **Recovery requires privileged intervention.** The only on-chain unsticks are (a) owner `topUp` covering the cumulative shortfall, or (b) affected users calling `emergencyWithdraw`, which forfeits the very reward they were trying to claim. No user-facing path restores liquidity.
- **No direct theft.** Principal is always recoverable via `emergencyWithdraw` ([L452 onwards](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L452)) — hence Medium rather than High. The loss is to reward availability and to the protocol's solvency invariant, not to principal.

Magnitude scales with cumulative `elapsed * rewardRate` accrued between recomputes within a runway. The PoC demonstrates a ~246.58 ether shortfall after a single 30-day gap at a 30% APY schedule seeded with 3,000 ether — roughly 8% of the seeded budget, stranded after one recompute event.

Assumptions (per C4 Medium criteria): the pool sees at least one recompute-triggering interaction between an accrual event and a later claim on that accrual, and `pull()` / `topUp` inflow does not happen to exceed the accumulated shortfall. Both are the default operating regime.

### Proof of Concept

The runnable Foundry PoC lives at [`test/poc-M-01.t.sol`](../pocs/poc-M-01.t.sol) and runs against the real `NFTStaker` at commit `66af47d` — no re-implementation, no mock substitution for the SUT.

Setup:

- `N = 100` NFTs at `price = 100 ether`, `growthBasisPoints = 0` → `T = 10,000 ether`.
- `targetAPY = 30%` → `F = 3,000 ether/year`, `R ≈ 9.51e13 wei/s`.
- Seed budget = `3,000 ether` (exactly one year of runway at `R`).
- Alice stakes 10 NFT units; 30 days elapse; Bob stakes 10 NFT units.

Key test: `test_M01_BudgetReinflationCausesShortfall`.

Observed numbers (from PoC `console.log`):

| Moment | `rewardBudget` | `balance` | `accRewardPerShare · totalStaked / ACC_PRECISION` |
|---|---|---|---|
| After Alice stakes | 3,000 ether | 3,000 ether | 0 |
| After 30d, before Bob stakes | 3,000 ether (stale) | 3,000 ether | 0 (pending only) |
| After Bob stakes (bug fires) | 3,000 ether | 3,000 ether | ~246.58 ether committed |

After the new `windowEnd` elapses:

```
pendingReward(alice) + pendingReward(bob) ≈ 3,246.58 ether
contract balance                          =  3,000.00 ether
shortfall                                 ≈    246.58 ether
```

Asserted behaviours (all pass):

```solidity
// Bug: budget is reset to balance even though X has been committed.
assertEq(budgetAfterBob, balanceAfterBob, "BUG: budget reset to balance");
assertEq(budgetAfterBob, SEED_BUDGET,    "BUG: budget restored to seed despite X already committed");

// Insolvency: committed rewards > on-chain balance.
assertGt(pendingA + pendingB, contractBal, "committed rewards > balance (insolvency)");

// Alice claims first, drains the balance below Bob's entitlement.
vm.prank(alice); staker.claim();
assertEq(phUSD.balanceOf(alice), pendingA, "Alice paid in full");
assertLt(phUSD.balanceOf(address(staker)), pendingB, "Bob's earned reward exceeds remaining balance");

// Bob's claim reverts with the exact `_safePay` error.
vm.prank(bob);
vm.expectRevert(bytes("NFTStaker: insufficient reward balance"));
staker.claim();
```

The shortfall (~246.58 ether) matches `R * 30 days` to within the expected floor-division dust, confirming the magnitude is exactly the amount `_updatePool` committed to `accRewardPerShare` just before the re-inflation.

## Recommended mitigation steps

The fix is to subtract already-committed debt from `V` before assigning it to `rewardBudget`. The simplest correct computation is:

```diff
 function _recomputeSchedule() internal {
     ...
     uint256 V = rewardToken.balanceOf(address(this));
     if (address(dispatcherHook) != address(0)) {
         V += dispatcherHook.mintDebt();
     }
+    // Strip out the portion already committed to users via accRewardPerShare.
+    // `totalDebt()` = sum over users of `amount * accRewardPerShare / ACC_PRECISION - rewardDebt`
+    // which equals the committed-but-unclaimed accrual at this instant.
+    uint256 committed = totalDebt();
+    uint256 budget = V > committed ? V - committed : 0;

     uint256 F = T.mulDiv(targetAPY, APY_PRECISION);
     uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;
-    uint256 runway = (newRate == 0) ? 0 : V / newRate;
+    uint256 runway = (newRate == 0) ? 0 : budget / newRate;

     rewardRate = newRate;
-    rewardBudget = V;
+    rewardBudget = budget;
     windowEnd = block.timestamp + runway;

-    emit ScheduleRecomputed(T, V, newRate, windowEnd);
+    emit ScheduleRecomputed(T, budget, newRate, windowEnd);
 }
```

This restores the documented post-recompute invariant `balance == rewardBudget + totalDebt` (with `mintDebt` externally held) and derives `windowEnd` from the actually-spendable portion of the pool, not the total-ever portion.

### Why this preserves the existing design

- **Bootstrap recompute still works.** At the first recompute with no stakers or no prior accrual, `totalDebt() == 0`, so `budget == V` — identical to the current behaviour.
- **Top-up path stays dispatcher-independent.** `topUp` calls `_recomputeSchedule` directly without touching `_syncBudget`; the extra `totalDebt()` read is pure.
- **APY stability invariant.** `rewardRate` still equals `T * A / SECONDS_PER_YEAR`, unchanged. Only the runway derivation sees the correction.
- **Late-staker non-retroactivity.** Unaffected — `accRewardPerShare` is the mechanism enforcing that, and it isn't modified here.

### Alternative: preserve `rewardBudget` across recompute, only fold in new inflow

If introducing a `totalDebt()` read inside `_recomputeSchedule` is undesirable (e.g. gas concerns — though `totalDebt` is already an O(1) stored invariant at other call sites), the equivalent correction is to have `_recomputeSchedule` *preserve* the post-`_updatePool` `rewardBudget` and only add the *inflow delta*:

```solidity
// rough sketch: called from _syncBudget with the inflow it just pulled
function _recomputeSchedule(uint256 inflow) internal {
    ...
    uint256 newBudget = rewardBudget + inflow + /* initial-bootstrap handling */;
    ...
    rewardBudget = newBudget;
    windowEnd = block.timestamp + newBudget / newRate;
}
```

This requires threading `inflow` through from `_syncBudget` / `topUp` (and supplying a bootstrap value on the initial recompute where `rewardBudget == 0`), so it is a larger refactor. The diff above using `totalDebt()` is the smaller, more surgical correction and is the recommended fix.

### Not recommended: leaving `_safePay`'s revert as the sole safety net

The current `_safePay` revert correctly prevents silent forfeiture but does so at the cost of DoSing legitimate claimants until the owner intervenes. Given the invariant violation is deterministic under normal activity, the root cause must be fixed at the source in `_recomputeSchedule` rather than relied on to be absorbed downstream.
