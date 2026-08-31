# QA Report — phoenix-nft-staking

## Summary

| Severity       | Count |
|----------------|-------|
| Low Risk       | 6     |
| Centralization | 1     |
| **Total**      | **7** |

---

## Low Risk Findings

### [L-01] `setWindowDuration` does not recompute `rewardRate` or `windowEnd`, violating spec and creating a latent rate-spike on the next pull

**Context:** [`NFTStaker.sol#L145-L151`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L145-L151)

**Description:** `setWindowDuration(newDuration)` calls `_updatePool()` and then overwrites only the `windowDuration` storage variable. It does not touch `rewardRate` or `windowEnd`. Feature-spec item 6 in the submodule `CLAUDE.md` states that changing the duration "resets the remaining time to the new full duration and recomputes the per-second rate against the current balance." The implementation does neither: emissions continue under the pre-existing `rewardRate` and the pre-existing `windowEnd` until that original window expires.

Because `_applyAsymmetricWindow` enforces a monotonic-upward `rewardRate` (see L-02), the owner has no on-chain lever to *reduce* emissions. Once the rate is set, subsequent top-ups and hook pulls can only raise it, never lower it. The documented "slow down emissions by lengthening the window" governance control is absent from the implementation.

A secondary effect of this mismatch: after a shortening call, the ratio `rewardBudget / newDuration` can easily exceed the unchanged `rewardRate`. On the next nonzero `_syncBudget` pull, the candidate computation in `_applyAsymmetricWindow` crosses into the reset branch, causing `rewardRate` to jump upward and `windowEnd` to snap to `now + newDuration`. A mempool-aware observer who sees the `WindowDurationChanged` event can time a stake to capture the baked-in spike.

**Impact:** Owner loses the documented governance control to slow emissions. Stakers interacting close to a `setWindowDuration` event are exposed to a timing-dependent redistribution of rewards. No budget is lost — conservation still holds — but the per-second schedule diverges from the stated intent.

**Recommendation:** Implement the spec behavior inside `setWindowDuration`: atomically set `rewardRate = rewardBudget / newDuration` and `windowEnd = block.timestamp + newDuration` after `_updatePool()`. If the monotonic-upward invariant is intentionally preserved here, update the spec in `CLAUDE.md` to match the implementation and document that `setWindowDuration` affects only subsequent inflows.

---

### [L-02] Monotonic-upward rate invariant traps `rewardRate` at zero on bootstrap and above sustainable levels after over-refill

**Context:** [`NFTStaker.sol#L189-L200`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L189-L200)

**Description:** `_applyAsymmetricWindow` computes `candidate = rewardBudget / windowDuration` using integer division, and enforces that `rewardRate` may only increase within a live schedule. Two related failure modes arise from this shape.

Bootstrap-stuck-at-zero: with the default `DEFAULT_WINDOW = 540 days` (~46.6M seconds), any `rewardBudget < windowDuration` makes `candidate == 0`. On the first `topUp`, the `scheduleExpired` branch fires with `rewardRate = 0` and `windowEnd = now + 540 days`. Because the extend branch is guarded by `rewardRate > 0`, subsequent small top-ups accumulate `rewardBudget` but never unlock emissions until a single top-up is large enough to cross `candidate >= 1`.

Stuck-above-sustainable: if an owner miscalibrates a top-up against a short window, `rewardRate` can be set high enough that stakers drain `rewardBudget` before `windowEnd`. Emissions stop, but `rewardRate` remains nominally high. Because `topUp` only raises the rate, `setWindowDuration` doesn't mutate it (L-01), and there is no `resetRate` admin path, the owner has no on-chain way to lower the rate. Recovery requires either waiting until `windowEnd` or funding a large enough top-up against a newly-expired schedule to hit the reset branch again.

**Impact:** Operational rigidity at both ends of the rate curve. No direct fund loss — `rewardBudget` is preserved and accrual conservation holds — but stakers experience zero-emission phases the owner cannot correct on-chain. The harm is availability, not solvency.

**Recommendation:** Three changes close the gap: (1) relax the `rewardRate > 0` guard so that when `rewardRate == 0` and the schedule is still live, a nonzero inflow triggers a recomputation of `candidate` against the cumulative budget; (2) add an `onlyOwner resetSchedule()` (or a `forceReset` flag on `setWindowDuration`) that fires the reset branch unconditionally with bounded parameters; (3) enforce a bootstrap minimum `amount >= windowDuration` on the first `topUp`, or document the edge case.

---

### [L-03] Integer division in `_applyAsymmetricWindow` silently under-accounts small inflows and creates a soft MEV timing surface

**Context:** [`NFTStaker.sol#L189-L200`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L189-L200)

**Description:** Two divisions in `_applyAsymmetricWindow` are floored and lose precision. The extend branch uses `windowEnd += inflow / rewardRate`. When `inflow < rewardRate` — common for dispatcher-hook drizzle where each `pull()` realises a sub-rate quantity of mint-debt — the extension rounds to zero, but `rewardBudget` still grows. Budget accumulates without a corresponding window extension. Symmetrically, `candidate = rewardBudget / windowDuration` is floored, so any `rewardBudget` in the interval `[k * windowDuration, (k+1) * windowDuration)` yields the same `candidate = k`; fractional budget contributes to runway but not to the rate-reset comparison.

The accounting is conservative — conservation of the budget holds — but `windowEnd` becomes an unreliable forward indicator. Occasional `scheduleExpired` resets fire earlier than the budget-implied runway would suggest. When the saved-up budget eventually tips `candidate` past `rewardRate`, a rate jump fires at a time determined by the cadence of hook pulls rather than by a smooth schedule. A searcher monitoring on-chain state can stake just before a predicted crossover and capture the rate increase.

**Impact:** Budget is preserved but its translation to a per-second schedule drifts. Stakers present at a boundary-crossing pull benefit; stakers who exited just before do not. The magnitude per event is bounded by a fraction of the `newRate - oldRate` delta multiplied by the attacker's share — meaningful only for searchers with mempool infrastructure and pools fed by frequent small inflows.

**Recommendation:** Scale the extend branch at higher precision by accumulating a fractional-seconds ledger, e.g. `windowEndFractional += (inflow * ACC_PRECISION) / rewardRate`, and applying whole seconds when the accumulator crosses `ACC_PRECISION`. Alternatively, store `rewardRate` at `1e18` precision and divide at accrual time. At minimum, emit an event exposing leftover sub-second precision so integrators can reason about upcoming resets.

---

### [L-04] `pendingReward` does not simulate `dispatcherHook.pull()` inflow, understating realised rewards

**Context:** [`NFTStaker.sol#L323-L334`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L323-L334)

**Description:** `pendingReward(account)` computes pending rewards from the current on-chain `rewardRate`, `windowEnd`, `rewardBudget`, and `accRewardPerShare`, with an in-memory accrual extension up to `min(block.timestamp, windowEnd)`. Unlike `totalBudget()` — which peeks at `dispatcherHook.mintDebt()` — `pendingReward` ignores the pending hook inflow entirely. Any call site that invokes `stake`, `unstake`, or `claim` will trigger `_syncBudget`, which calls `dispatcherHook.pull()` and may cross the reset branch of `_applyAsymmetricWindow` (raising `rewardRate`). After such a crossing, the actual amount paid diverges upward from the most recent `pendingReward` quote.

The direction of the error is consistent — `pendingReward` only under-estimates, never over-estimates, so no user is tricked into claiming more than they've earned. However, a frontend or integrator relying on this as a single source of truth displays a figure that a subsequent interaction will contradict, and a counterparty offering to buy out a staking position at the quoted `pendingReward` captures the hidden upside.

**Impact:** Informational inconsistency between view and mutation paths. Magnitude is bounded by the user's share fraction of the pending `dispatcherHook.mintDebt()` at query time. No direct loss of funds inside the protocol, but OTC pricing of staking positions is systematically biased against sellers.

**Recommendation:** Mirror the pattern in `totalDebt()`/`totalBudget()`: peek at `dispatcherHook.mintDebt()`, apply `_applyAsymmetricWindow` logic in-memory to derive the post-pull `rewardRate` and `accRewardPerShare`, and return the post-simulation pending. Alternatively, add a `pendingRewardSimulated()` view alongside the simple one and document that `pendingReward` is pre-pull.

---

### [L-05] `setStakedId` can be blocked indefinitely by a single 1-unit staker

**Context:** [`NFTStaker.sol#L139-L143`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L139-L143)

**Description:** `setStakedId(newId)` reverts unless `totalStaked == 0`. The only user-side exit is `emergencyWithdraw`, which the staker must initiate. There is no owner-triggered forced-exit path, and the function does not require `paused() == true`. Two variants of the same blocker arise.

Unresponsive staker: a single holder with a 1-unit stake, lost keys, or inaction leaves `totalStaked > 0` and blocks the ID migration documented in feature-spec item 1 (NFT reissuance after a Balancer pool reconfiguration). Active griefer: an adversary watching the owner's `setStakedId` transaction in the mempool front-runs with `stake(1)`, causing the setter to revert. The griefer then unstakes for a negligible reward accrual cost, paying roughly two transaction fees per migration attempt, and repeats indefinitely.

Because `setStakedId` does not gate on the paused state, an unobservant operator can be caught without having first called `pause()` (which would make `stake` unavailable and prevent front-running).

**Impact:** Operational deadlock on NFT-ID migrations. No principal is at risk — `emergencyWithdraw` is always available and accrued rewards stay owed — but the documented migration flow cannot complete on-chain without coordinated social action. Severity is bounded by the attacker's willingness to sustain the griefing cost and by the owner's ability to call `pause()` out-of-band.

**Recommendation:** Require `paused() == true` inside `setStakedId`, which makes `stake()` unavailable to front-runners during a migration. Optionally add a two-step migration where the owner opens a migration window, stakers are expected to exit within it, and `setStakedId` only executes after the window closes. At minimum, document operationally that operators must pause before attempting `setStakedId`.

---

### [L-06] `dispatcherHook.pull()` revert DoSes `stake` / `unstake` / `claim`

**Context:** [`NFTStaker.sol#L203-L214`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L203-L214)

**Description:** `_syncBudget` is invoked at the top of `stake`, `unstake`, and `claim`. When `dispatcherHook` is nonzero, `_syncBudget` makes a raw external call — `dispatcherHook.pull();` — with no `try/catch`. Any revert inside the hook (transient pause, upgrade breakage, a caller-gate failure because `NFTStaker` is not wired as the hook's `recipient`, or a bug in the sibling yield-claim-nft module) propagates all the way up to the user-facing call and reverts it.

Users retain access to `emergencyWithdraw`, which deliberately skips `_syncBudget`/`_updatePool` and remains callable while paused — principal is never at risk. However, any user who cannot wait for owner intervention must forfeit their accrued rewards to recover principal. The DoS window is bounded by owner responsiveness: setting `dispatcherHook = address(0)` via `setDispatcherHook` restores `_syncBudget` to the early-return path and re-enables normal flow (though that path has its own interaction with C-01).

**Impact:** Temporary denial-of-service of the normal stake/unstake/claim paths whenever the hook is unhealthy. Users who cannot wait forfeit accrued rewards. Principal is preserved by the escape hatch. The vulnerability is an external-contract liveness coupling; exploitability requires the hook to be reverting, which is not attacker-controlled.

**Recommendation:** Wrap `dispatcherHook.pull()` in `try/catch`, degrading to a no-op on revert so the call continues under the existing budget:

```solidity
try dispatcherHook.pull() {
    // success path continues below
} catch {
    return;
}
```

This preserves the dispatcher-independence of the escape hatch while making the primary user paths hook-failure tolerant.

---

## Centralization Risks

### [C-01] `setDispatcherHook` does not drain the outgoing hook, stranding undrawn mint-debt on migration

**Context:** [`NFTStaker.sol#L134-L137`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/NFTStaker.sol#L134-L137)

**Description:** `setDispatcherHook(newHook)` emits the event and overwrites `dispatcherHook` with no prior call to the outgoing hook's `pull()`. Any accrued `mintDebt` on the old hook, which would have been claimed by this contract the next time `_syncBudget` ran, is not realised before the pointer changes. Once the storage slot is overwritten, the only path `NFTStaker` ever uses — `dispatcherHook.pull()` inside `_syncBudget` — routes to the new hook and does not see the old hook's ledger.

The header comment on `_syncBudget` states "Always settle accrual under the OLD rate before mutating anything." `setDispatcherHook` bypasses that discipline for the hook's own accrual: rate/accrual state is not being changed directly, but the funding source that the schedule assumes is being swapped out atomically.

**Impact:** Accrued mint-debt on the outgoing hook at the moment of swap is left stranded. Recovery requires out-of-band admin action on the old hook — for example, re-pointing it back to `NFTStaker` via governance on the sibling module, calling `pull()`, and then re-migrating. Magnitude depends on `mintDebt()` at migration time. No external attacker surface; the harm materialises only from an owner-initiated governance action performed without the correct ordering discipline.

**Recommendation:** Call `_syncBudget()` before overwriting `dispatcherHook`, so the old hook is drained under its own pointer:

```solidity
function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
    _syncBudget();
    emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
    dispatcherHook = newHook;
}
```

Alternatively, add a one-shot `pullFromHook(IBalancerPoolerMintDebtHook old) external onlyOwner` that accepts a past hook address and calls its `pull()` so stranded debt can be recovered after a missed-ordering migration.
