<!--
ID: pe4m3
C4 Submission Metadata
Title: [L-07] Permissionless collectReward and free non-staker claim() poke re-anchor the depletion window, forcing worst-case reward decay and a permanent tail stall
Severity: Low
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L270-L286
PoC File: test/poc-2004-M-03-permissionless-collectreward-grief.t.sol
Ledger: M-02 (still-open)
-->

> **Reclassified Medium→Low and folded into M-01 (phlimbo-ea-04, user-approved). Detailed report + PoC retained; bundled in qa-report.md; access-control/tail-stall angle cross-referenced from M-01.**

## Finding description and impact

### Severity (Low — downgraded from Medium, debatable)

**Final classification: Low** (downgraded from Medium per the severity-auditor, phlimbo-ea-04, user-approved; folded into M-01 as the access-control / tail-stall angle). The borderline reasoning is retained below for completeness — it was the basis for the downgrade: this shares M-01's root cause and the identical ~63.4% figure, the attacker payoff is zero, and the only independent impact is the dust tail-stall (~300 wei):

- **Shared root cause with M-01.** M-03 and M-01 ([`_updatePool` rate re-anchor, `Phlimbo.sol#L416`](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L416)) are the same underlying defect: `rewardPerSecond` is recomputed against the residual balance on every pool touch, so each touch re-anchors the depletion window to `now + depletionDuration`. M-03 lands on the *same* ~63.4% worst-case figure that M-01's organic case produces. It is **not** an independent loss of new value.
- **M-03's distinct contribution is the access-control angle.** M-01 frames this as decay arising from *legitimate* user activity. M-03 shows that an **external party holding zero stake, zero reward tokens, and zero approvals** can *deliberately* and *cheaply* drive the stream onto its worst-case curve, and can do so by the cheapest path available — a `claim()` call as a non-staker, which costs nothing but gas.
- **Marginal harm over a realistic baseline is smaller than the headline 37%.** The PoC baseline is the idealized `N = 1` case (a single `_updatePool` at the window end, delivering ~100%). In a live, multi-staker pool, ordinary activity (stakes, withdrawals, claims) *already* pokes `_updatePool` repeatedly, so the pool is already operating somewhere on the decay curve before any attacker shows up. The *incremental* damage a dedicated griefer adds on top of organic activity is therefore materially less than the 37% suppression the PoC measures against the pristine `N = 1` baseline. We do not claim a griefer subtracts 37% from a live pool.
- **The clean, independent contribution is the tail stall and the guarantee of reachability.** Two things M-03 establishes that are not captured by M-01's passive framing: (1) the worst-case curve is *always reachable on demand* by an unprivileged actor at gas-only cost, turning a passive inefficiency into an active, repeatable denial primitive; and (2) the **permanent tail stall** — below the `depletionDuration/12` reward-wei threshold, per-block pokes distribute `0` while `lastRewardTime` still advances, so the residual tail never distributes again.

The strongest *independent* impact is the availability degradation reachable by anyone (the C4 "protocol function/availability impacted" prong), with the tail stall as a clean but small adjunct. See the impact section for the honest scoping of how much value is actually at stake.

### Summary

`collectReward` is permissionless, and `claim()` can be called by an address that has never staked. Both run `_updatePool`, which recomputes `rewardPerSecond = rewardBalance * PRECISION / depletionDuration` whenever any reward is distributed. Each call re-anchors the linear-depletion window. An attacker who pokes the pool every block forces reward delivery onto the worst-case exponential-decay curve, suppressing stakers' realized reward velocity, and — once the residual balance falls below `depletionDuration/12` reward-wei — permanently strands the tail. The attacker spends **zero tokens** (gas only) and gains **zero** (pure value-denial / griefing).

### Root cause

The depletion rate is recomputed on every distribution rather than being anchored to a fixed window end:

```solidity
// _updatePool(), Phlimbo.sol#L409-L417
if (toDistribute > 0) {
    accStablePerShare += (toDistribute * PRECISION) / totalStaked;
    rewardBalance -= toDistribute;
    // Recalculate rate after balance decrease  <-- re-anchors the window every time
    rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
}
...
lastRewardTime = block.timestamp; // L425 — advances even when toDistribute == 0
```

Because the rate is re-derived from the *remaining* balance over a *full* `depletionDuration` on every distribution, distributing more frequently delivers less of the balance within any fixed horizon. With `N` evenly spaced pokes over one window, the fraction delivered is

```
delivered(N) = 1 - (1 - T/(N*D))^N      (decreasing in N; → 1 - 1/e ≈ 63.2% as N → ∞)
```

Two entry points let an unprivileged actor drive `N` arbitrarily high:

1. [`collectReward(uint256)` — `Phlimbo.sol#L270-L286`](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L270-L286): permissionless; `collectReward(1)` calls `_updatePool` and then a forced rate recompute.
2. [`claim()` — `Phlimbo.sol#L374-L381`](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L374-L381): callable by a **non-staker**. `_claimRewards` returns early because the caller's `amount == 0`, but `_updatePool` still runs first — so the re-anchor happens with **no tokens, no stake, and no approval**. This is the cheapest amplification vector.

The **tail stall** is a second consequence of the same code: when `rewardBalance * timeElapsed / depletionDuration` rounds down to `0` (i.e. `rewardBalance < depletionDuration / blockTime ≈ depletionDuration/12` reward-wei for per-block pokes), the `if (toDistribute > 0)` block is skipped entirely — but `lastRewardTime = block.timestamp` at L425 still advances. Each subsequent per-block poke again distributes `0`, so the residual tail is consumed in time but never in value, and never distributes again.

### Impact

Availability / value-delivery degradation of the reward stream, at gas-only cost to an unprivileged attacker with zero payoff:

- **Velocity suppression (overlaps M-01).** Stakers realize rewards substantially more slowly than the linear schedule implies. The PoC measures 63.4% of the idealized baseline within one window. Crucially, this value is **deferred, not destroyed** — the un-delivered balance remains in `rewardBalance` and continues depleting over subsequent (re-anchored) windows. Under continuous griefing, full delivery within any fixed horizon never occurs.
- **Permanent tail stall (independent of M-01).** A residual below ~`depletionDuration/12` reward-wei is permanently stranded under per-block poking and is recoverable only by the owner's `emergencyTransfer`. **Honest scoping:** in absolute terms this stranded tail is dust (for an 18-decimal token and `depletionDuration = 3600`, the threshold is ~300 wei = 3e-16 tokens). Its significance is the *permanence and the "never reaches zero" character*, not large value loss.
- **No theft, no principal at risk.** Attacker profit is exactly zero; staked phUSD is untouched. This is pure griefing / denial-of-service against reward delivery.

Net: a core protocol function (reward distribution velocity) can be degraded to its mathematical worst case on demand by anyone, and the dust tail can be permanently frozen. The headline value-at-risk is *deferred* reward delivery plus a *dust* permanent loss — which is why Low is a defensible alternative ranking.

### Proof of Concept

The PoC (`test/poc-2004-M-03-permissionless-collectreward-grief.t.sol`, validated against submodule HEAD `1b1a32c4`) stakes a single staker, funds one tranche `R = 100 ether`, then has a **non-staker** (`griefer`, holding zero tokens and giving no approvals) call `claim()` once every 36 seconds for the full 3600-second window (100 free pokes). It compares the staker's realized reward against an untouched-window baseline.

Run:

```bash
forge test --match-test test_M03_freeNonStakerPokeDegradesRewardVelocity -vv
```

Output:

```
[PASS] test_M03_freeNonStakerPokeDegradesRewardVelocity()
  R (funded tranche)             : 100000000000000000000   (100 ether)
  Baseline staker realized        : 99999999999999999000   (~100% of R)
  Grief    staker realized        : 63396765872676998000   (~63.4% of R)
  Grief / baseline (bps)          : 6339
  Griefer token cost (wei)        : 0
  Number of free pokes            : 100
```

Key test body:

```solidity
// Grief: identical funding, but a NON-staker pokes claim() every GRIEF_DT.
function _griefRealized() internal returns (uint256 realized, uint256 griefTokenCost) {
    _deployFresh();
    vm.prank(staker);   phlimbo.stake(STAKE_AMOUNT, staker);
    vm.prank(funder);   phlimbo.collectReward(REWARD_AMOUNT);

    uint256 griefBalBefore = rewardToken.balanceOf(griefer);
    assertEq(griefBalBefore, 0, "griefer starts with zero reward tokens");

    for (uint256 i = 0; i < NUM_POKES; ++i) {
        vm.warp(block.timestamp + GRIEF_DT);
        // FREE poke: non-staker claim() runs _updatePool re-anchor, no tokens move.
        vm.prank(griefer);
        phlimbo.claim();
    }

    vm.prank(staker);
    phlimbo.claim();
    realized = rewardToken.balanceOf(staker);
    griefTokenCost = griefBalBefore - rewardToken.balanceOf(griefer); // == 0
}
```

The test asserts the griefer's reward-token cost is exactly `0`, its phUSD balance is `0` (never staked), and the staker's realized reward is suppressed onto the ~63% worst-case band.

**Honest baseline caveat (important for reading the number):** the 100% baseline is the idealized `N = 1` case (one `_updatePool` at the window end). A live multi-staker pool is *already* poked by organic activity and therefore already sits below 100% before any attack. The PoC demonstrates that the worst-case curve and the zero-cost reachability are real; it does **not** assert that a griefer subtracts a full 37% from a realistically-active pool. The clean incremental harm is the *guaranteed reachability* of the worst case by an unprivileged actor and the *permanent dust-tail stall*.

## Recommended mitigation steps

The cleanest fix is at the shared root cause; the access-control hardening and the tail-stall fix are independent, defense-in-depth additions.

1. **Fix the re-anchor (also fixes M-01).** Stop recomputing `rewardPerSecond` from the residual balance on every distribution. Track an explicit window end (e.g. `rewardEndTime` set when a tranche is funded) and derive distribution against that fixed end, so poke frequency does not affect how much is delivered within the window. This makes the attack economically pointless because repeated pokes become idempotent with respect to delivery. PhlimboV2 already removes the depletion-rate recompute from `_updatePool` for exactly this reason; V1's exposure remains.

2. **Make `_updatePool` poke-frequency-irrelevant / gate the funding path.** If the rate model is retained, either:
   - require `collectReward` to be called only by authorized funders (the design intent is "rewards from the stable-yield-accumulator"), removing the cheap `collectReward(1)` poke; and/or
   - make `_updatePool` a no-op for callers that do not change `totalStaked` or fund the pool, so a non-staker `claim()` cannot re-anchor the window.

3. **Fix the tail stall directly.** Do not advance `lastRewardTime` when nothing is distributed — i.e. only set `lastRewardTime = block.timestamp` inside the `if (toDistribute > 0)` branch (or sweep any sub-threshold residual into the final distribution). This guarantees the elapsed time is not "consumed" without delivering value, so the dust tail eventually distributes instead of being permanently stranded.

Applying (1) alone resolves the bulk of both M-01 and M-03; adding (3) closes the permanent tail-stall edge case.
