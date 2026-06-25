<!--
ID: pns18m1
C4 Submission Metadata
Title: [M-01] Per-interaction full-window reset in `_recomputeSchedule` reintroduces linear-depletion rate-drift, starving active stakers and stranding the budget
Severity: Medium
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/24acff83434e9708cb13e208b8ea32464af5c1f8/src/NFTStakerDepletion.sol#L513-L534
PoC File: workspace/phoenix-nft-staking/test/PoC_DepletionRateDrift.t.sol
Faithfulness cross-reference: F-18-01 (breaks story-018)
-->

## Finding description and impact

### Summary

`NFTStakerDepletion` is the linear-depletion variant of the staker: rather than deriving the emission rate from a target APY, it spreads a fixed `rewardBudget` evenly across a fixed `depletionWindowMonths`. Story-018 promises the budget "drains linearly to dust over exactly `depletionWindowMonths`," and the `rewardRate` NatSpec (`src/NFTStakerDepletion.sol#L151`) explicitly claims the design "avoids phlimbo's V1 rate-drift bug."

Both promises are false. `_recomputeSchedule` re-derives the rate against the *remaining* budget and pushes `windowEnd` a *full fresh window* into the future on **every** interaction — including interactions whose actual reward inflow is zero. The realized emission curve therefore decays geometrically instead of draining linearly, the window never terminates while the pool sees activity, honest active stakers systematically under-earn, and a large fraction of the budget is stranded in-contract past the intended deadline.

### Vulnerability details

The defect is the unconditional full-window reset in `_recomputeSchedule` ([`src/NFTStakerDepletion.sol#L513-L534`](https://github.com/Behodler/phoenix-nft-staking/blob/24acff83434e9708cb13e208b8ea32464af5c1f8/src/NFTStakerDepletion.sol#L513-L534)):

```solidity
function _recomputeSchedule() internal {
    uint256 windowSeconds = depletionWindowMonths * SECONDS_PER_MONTH;
    uint256 V = rewardToken.balanceOf(address(this));
    if (address(dispatcherHook) != address(0)) {
        V += dispatcherHook.mintDebt();
    }
    uint256 budget = V > committedDebt ? V - committedDebt : 0;
    uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

    rewardRate = newRate;
    rewardBudget = budget;
    windowEnd = block.timestamp + windowSeconds;   // FRESH FULL WINDOW, measured from "now"
    lastRewardTime = block.timestamp;
    emit ScheduleRecomputed(windowSeconds, budget, newRate, windowEnd);
}
```

Two facts combine to make this a per-interaction rate-drift:

1. **`windowEnd` and `rewardRate` are reset on every interaction.** `_recomputeSchedule` is invoked unconditionally by `_syncBudget` ([`#L423-L436`](https://github.com/Behodler/phoenix-nft-staking/blob/24acff83434e9708cb13e208b8ea32464af5c1f8/src/NFTStakerDepletion.sol#L423-L436)), which sits at the head of `stake`, `unstake`, `claim`, `depositFor`, and `pullAndRefresh`. The `inflow > 0` check at `#L433` only gates the `Pulled` event — it does **not** gate the recompute. So even when the dispatcher hook is unset (or has nothing to pull), every interaction still recomputes the schedule from scratch.

2. **The rate is budget-derived, so re-deriving it shrinks it.** This is the key contrast with the parent `NFTStaker`, whose rate `R = S · targetAPY / SECONDS_PER_YEAR` is *budget-independent* — repeated recompute leaves it unchanged, which is exactly why the parent is safe under pull-on-interaction. Here, `rewardRate = rewardBudget / windowSeconds`. Each interaction settles the accrual earned so far at the *old* rate (correctly, via `_updatePool`), then re-spreads the now-smaller `remaining` budget over a brand-new full window starting at "now." Because the remaining budget is smaller each time and the window is reset to its full length, `rewardRate` ratchets down and `windowEnd` ratchets forward on every touch.

The result is exactly phlimbo's V1 rate-drift, reintroduced at the schedule level: emissions decay geometrically toward — but never reaching — depletion, and the deadline drifts indefinitely as long as the pool is active.

This breaks the contract's own stated design (story-018; Law 2), and is cross-referenced as **F-18-01** in the spec-conformance report.

### Impact

- **Honest active stakers systematically under-earn.** A staker who interacts frequently (the normal, encouraged behavior — claim regularly, stake/unstake) realizes a strictly smaller fraction of the budget than an identical passive staker who simply waits. Activity is penalized; laziness is rewarded.
- **The budget is never fully delivered within the intended window.** A large fraction is left stranded in-contract well past the promised `depletionWindowMonths` deadline, and the deadline keeps sliding outward with continued activity.
- **No special precondition and no attacker is required.** The drift triggers on every ordinary `stake` / `claim` / `unstake`; it is the default behavior of the contract under normal use.
- **Severity is Medium, not High.** This is a value-delivery / protocol-function leak, not a theft or insolvency: the `balance == rewardBudget + committedDebt` invariant holds throughout, nothing is over-paid, and the stranded shortfall stays inside the contract (owner-recoverable, not lost). The harm is that the protocol fails to deliver promised emissions on schedule and distributes them unfairly across stakers — protocol-function impaired with no direct asset loss.

## Recommended mitigation steps

The fix is to stop treating a zero-delta interaction as a reason to re-spread the budget. Only reset `windowEnd` and re-derive `rewardRate` on a **genuine budget change** — a `topUp`, a non-zero dispatcher-hook inflow, or a `setDepletionWindow` — and otherwise let the existing schedule run to its fixed deadline. This realizes the design doc's "a zero-inflow pull is a no-op" intent.

Concretely, gate the window/rate reset on an actual budget delta rather than recomputing on every call. One shape (illustrative, not prescriptive):

```solidity
function _recomputeSchedule() internal {
    // ... compute `budget` from V - committedDebt as today ...

    // No genuine budget change => let the existing schedule run to its
    // fixed deadline. Settle-old-accrual-at-old-rate ordering is unchanged
    // (callers still run _updatePool() before this).
    if (budget == rewardBudget && windowEnd != 0) {
        return;
    }

    uint256 windowSeconds = depletionWindowMonths * SECONDS_PER_MONTH;
    rewardRate    = (windowSeconds == 0) ? 0 : budget / windowSeconds;
    rewardBudget  = budget;
    windowEnd     = block.timestamp + windowSeconds;
    lastRewardTime = block.timestamp;
    emit ScheduleRecomputed(windowSeconds, budget, newRate, windowEnd);
}
```

Notes for the implementer:

- Preserve the existing ordering: callers must still settle accrued rewards at the *old* rate (`_updatePool()`) before the schedule may change, so a real budget change does not retroactively re-rate past accrual.
- The reset must remain unconditional for `setDepletionWindow` (the window length itself changed) and for a real top-up / non-zero hook inflow (the budget genuinely grew). The fix only suppresses the spurious reset when neither the budget nor the window has moved.
- Re-verify the `balance == rewardBudget + committedDebt` solvency invariant after the change; the suppression path leaves `rewardBudget` untouched, so the invariant is preserved by construction.

## Code location

- Root cause — full-window reset: [`src/NFTStakerDepletion.sol#L513-L534`](https://github.com/Behodler/phoenix-nft-staking/blob/24acff83434e9708cb13e208b8ea32464af5c1f8/src/NFTStakerDepletion.sol#L513-L534) (`rewardRate = budget / windowSeconds`, `windowEnd = block.timestamp + windowSeconds`).
- Unconditional invocation on every interaction: [`src/NFTStakerDepletion.sol#L423-L436`](https://github.com/Behodler/phoenix-nft-staking/blob/24acff83434e9708cb13e208b8ea32464af5c1f8/src/NFTStakerDepletion.sol#L423-L436) (`_syncBudget`; the `inflow > 0` check at L433 gates only the `Pulled` event, not the recompute).
- False NatSpec claim: [`src/NFTStakerDepletion.sol#L151`](https://github.com/Behodler/phoenix-nft-staking/blob/24acff83434e9708cb13e208b8ea32464af5c1f8/src/NFTStakerDepletion.sol#L151) ("avoids phlimbo's V1 rate-drift bug").

## Proof of Concept

A coded, passing Foundry PoC is provided at `workspace/phoenix-nft-staking/test/PoC_DepletionRateDrift.t.sol`.

Run:

```bash
cd workspace/phoenix-nft-staking
forge test --match-path test/PoC_DepletionRateDrift.t.sol -vv
```

**Setup.** A `NFTStakerDepletion` is funded with a `1,200,000e18` phUSD budget and a `12`-month depletion window. The dispatcher **hook is deliberately left unset**, so `dispatcherHook.pull()` is never reached and the actual reward inflow on every interaction is provably **zero**. This isolation is the crux of the proof: because no new value can enter the contract, any change in `rewardRate` / `windowEnd` across interactions can only come from `_recomputeSchedule` re-spreading the *existing* budget — the recompute is conclusively the sole cause of the drift, not inflow timing. Two stakers hold identical positions over the same horizon:

- **Passive staker** — stakes, waits, and claims once at the original `windowEnd`.
- **Active staker** — stakes and claims once per day for 365 days.

**Observed results.**

- Passive staker receives `≈ 1,199,999.99e18` phUSD — i.e. essentially the full budget, confirming the schedule pays out linearly when left untouched.
- Active staker receives `759,150.10e18` phUSD = **63.26% (6326 bps)** of the passive staker's take, despite an identical position over an identical horizon.
- `440,849.90e18` phUSD (≈ **36.7%** of the budget) is left stranded in the contract, undelivered past the intended deadline.
- `rewardRate` decays from `38,051,750,380,517,503` to `13,979,258,777,137,451` wei/s (~37% of its initial value) over the 365 interactions.
- `windowEnd` drifts from `63,072,001` to `94,608,001` — a full extra 365 days past the original deadline — and would keep climbing with continued activity.

**Invariant assertions.** The PoC asserts `balance == rewardBudget + committedDebt` on all 365 interactions (solvency holds throughout — no over-payment, no theft) and asserts `activeReceived + stranded == BUDGET` exactly (the missing rewards are deferred/stranded in-contract, not drained). These assertions are what establish the Medium ceiling: the bug is a value-delivery and fairness defect, not an insolvency or theft.
