<!--
C4 Submission Metadata
Title: [M-03] Permissionless pullAndRefresh enables window-stretching griefing that dilutes emission rate for existing stakers
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L210-L230
PoC File: workspace/nft-staking/test/poc-ES-01.t.sol
-->

## Finding description and impact

### Summary

`NFTStaker.pullAndRefresh()` is `external` with no access control and forwards unconditionally to `_syncBudget()`. On ANY non-zero inflow from the dispatcher hook — even 1 wei — `_syncBudget` unconditionally resets `windowEnd` to `block.timestamp + windowDuration` and recomputes `rewardRate = rewardBudget / windowDuration`. Because the `BalancerPoolerMintDebtHook` accrues mint-debt continuously, a non-zero inflow is available on essentially every block, so any unprivileged EOA can poke `pullAndRefresh()` whenever they like and force a schedule reset that dilutes the per-second emission rate for existing stakers.

### Vulnerability details

The vulnerable code pattern lives in [`NFTStaker.sol#L210-L230`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L210-L230):

```solidity
function pullAndRefresh() external {
    _syncBudget();
}

function _syncBudget() internal {
    _updatePool();
    if (address(dispatcherHook) == address(0)) return;
    uint256 pre = rewardToken.balanceOf(address(this));
    dispatcherHook.pull();
    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
    if (inflow == 0) return;
    rewardBudget += inflow;
    windowEnd = block.timestamp + windowDuration;            // unconditional reset
    rewardRate = rewardBudget / windowDuration;              // diluted each call
    emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
}
```

Two properties combine to create the griefing vector:

1. `pullAndRefresh()` has no authentication — any address may call it.
2. The window/rate reset fires on any non-zero inflow, with no threshold and no check that the inflow materially changes the budget. `dispatcherHook.pull()` routinely returns a tiny non-zero amount because mint-debt accrues block-by-block on the hook side.

As a result, an attacker can repeatedly trigger the reset branch and keep stretching the remaining budget over a fresh full `windowDuration`, permanently depressing `rewardRate`.

The same reset semantics are present in `topUp()` ([`NFTStaker.sol#L197-L206`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L197-L206)), so an owner making tiny top-ups has the same dilutive effect, but the permissionless surface in `pullAndRefresh` is the primary concern because the attack requires no privilege.

### Attack path

1. Protocol seeds a 540-day window with a budget of 540e18, giving an initial rate of ~1.1574e13 wei/sec.
2. Alice stakes. 450 days elapse on-schedule. Roughly 90e18 of budget remains with 90 days left at the original rate.
3. A random EOA (no stake, no privilege, no reward-token balance) calls `pullAndRefresh()`. The dispatcher hook yields a trivial inflow of even 1e12 wei (or less).
4. `_syncBudget` sets `windowEnd = now + 540 days` and `rewardRate = (90e18 + 1e12) / 46,656,000` ≈ 1.929e12 wei/sec — an ~83% reduction from the pre-poke rate.
5. Alice was on-track to earn ~90e18 over the final 90 days of the original schedule. After the poke she earns only ~15e18 in that same window; the rest is back-loaded into the stretched tail and can be captured by whoever is staked late.
6. The attacker can repeat the poke indefinitely; each call re-stretches the remaining budget over a fresh full window, holding the realized rate at a small fraction of the original.

### Impact

- Attacker-triggered, permanent dilution of the per-second emission rate paid to honest stakers. A single poke is sufficient to cut the realized rate by ~83% in the quantified scenario; repeated pokes keep it pinned at the diluted level.
- Value transfer away from on-schedule long-term stakers (who earn a fraction of the emissions they expected) toward JIT / late stakers who enter the stretched-back window.
- Griefing is free: the attacker needs no stake, no reward-token balance, and no privileged role. Cost is only gas for one transaction per poke.
- MEV flavour: the same primitive can be used to front-run a victim's `claim()` with `pullAndRefresh()` to shrink the rate before their claim settles, or to back-run schedule transitions.

This violates the contract's stated invariant (CLAUDE.md, "Window reset on inflow") that rewards should follow the intended per-second schedule; instead, any unprivileged third party can unilaterally rewrite that schedule.

### Proof of concept

A runnable Foundry PoC is provided in [`workspace/nft-staking/test/poc-ES-01.t.sol`](../../../../workspace/nft-staking/test/poc-ES-01.t.sol). Run with `cd workspace/nft-staking && forge test --match-path test/poc-ES-01.t.sol -vv`. Key assertions from the primary test `test_ES01_PermissionlessPokeDilutesRewardRateForExistingStakers`:

- After 450 days of a 540-day schedule with no on-schedule intervention, the rate is the original `540e18 / 540 days`.
- A non-privileged EOA (no stake, no reward token, not owner, not pauser) calls `pullAndRefresh()` with only 1e12 wei of pending mint-debt on the hook.
- `windowEnd` is asserted to have been reset to `now + 540 days`.
- `rewardRate` is asserted to drop by at least 8000 bps (≥80%) in a single call — the test measured ~83%.
- The denied / back-loaded emissions over the remaining 90 days of the original schedule are asserted to exceed 70e18.

A second test `test_ES01_RepeatedPokesKeepTheRateDiluted` demonstrates that five successive pokes with microscopic 1e6 wei inflows keep the realized rate below half of the pre-griefing value, confirming the attack is persistent rather than one-shot.

## Recommended mitigation steps

Combine (a) access control with (b) a reset policy that cannot decrease the rate or arbitrarily extend the window:

1. Restrict `pullAndRefresh()` to a trusted role (owner or a keeper) so unprivileged addresses cannot poke the schedule at will. This alone removes the permissionless griefing surface.
2. Change the window/rate update policy so a new inflow can never reduce the effective emission rate or silently stretch the schedule. Any of the following is sufficient:
   - Only reset the window when `inflow` exceeds a sensible threshold (e.g. ≥ 1% of current `rewardBudget`).
   - Instead of `windowEnd = block.timestamp + windowDuration`, extend by `inflow / rewardRate` seconds (clamped at `windowDuration`), leaving the existing rate intact.
   - Compute the new rate as `max(currentRate, (rewardBudget + inflow) / windowDuration)` and set `windowEnd = block.timestamp + (rewardBudget / newRate)`, so an inflow can only ever increase the rate, never decrease it.
3. Apply the same policy to `topUp()`, which today also unconditionally resets `windowEnd` and `rewardRate` on any non-zero amount.

Any of the above preserves the spec's "window reset on meaningful inflow" intent while removing the griefing / MEV incentive.
