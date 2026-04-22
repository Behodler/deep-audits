# QA Report — Phoenix NFT Staking (`NFTStaker.sol`)

Commit: [`2e56588`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol)

## Summary

| Severity       | Count |
|----------------|-------|
| Low Risk       | 9     |
| Centralization | 1     |
| **Total**      | **10** |

### Low Risk

| ID   | Title |
|------|-------|
| L-01 | `pullAndRefresh()` is not `nonReentrant` and can be re-entered via a malicious or upgraded `dispatcherHook` |
| L-02 | `setWindowDuration` accrues under the OLD rate without first pulling fresh dispatcher mint-debt |
| L-03 | `emergencyWithdraw` does not settle accrual, silently redirecting the exiting user's pro-rata emissions to remaining stakers |
| L-04 | Reward-token accounting in `_syncBudget` and `topUp` is fragile against fee-on-transfer or rebasing reward tokens |
| L-05 | Reward-rate reset on every non-zero pull / top-up back-loads emissions and re-truncates residual dust on each reset |
| L-06 | `pendingReward()` over-reports available rewards by not accounting for the `_safePay` balance cap |
| L-07 | `emergencyWithdraw` leaves `balance - rewardBudget - totalDebt` invariant drift |
| L-08 | `totalBudget()` and `runwaySeconds()` are internally inconsistent and do not project pending accrual |
| L-09 | `Claimed` event is gated on `paid > 0` even though `rewardDebt` advances unconditionally — silent shortfalls are unobservable off-chain |

### Centralization

| ID   | Title |
|------|-------|
| C-01 | Unilateral owner control over `dispatcherHook`, `windowDuration`, `topUp`, `pauser`, and `stakedId` creates multiple high-leverage centralization points |

---

## Low Risk Findings

### [L-01] `pullAndRefresh()` is not `nonReentrant` and can be re-entered via a malicious or upgraded `dispatcherHook`

**Location**: [`NFTStaker.sol#L210-L230`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L210-L230)

**Description**: `pullAndRefresh()` is an external, permissionless entry point that calls `_syncBudget`, which in turn calls `dispatcherHook.pull()`. `_syncBudget` performs state mutations *after* the external call: it measures `inflow` from a balance delta and then updates `rewardBudget`, `windowEnd`, and `rewardRate`. Unlike `stake` / `unstake` / `claim`, `pullAndRefresh` carries no `nonReentrant` modifier. The `dispatcherHook` address is mutable via `setDispatcherHook` and documented as a sibling-controlled contract — not an immutable trusted primitive.

**Impact**: If the dispatcher hook is ever malicious, buggy, or upgraded, cross-function reentrancy via the unguarded `pullAndRefresh` can corrupt `rewardBudget`, `rewardRate`, or `windowEnd`. A nested call inside `pull()` captures its own `pre` after the outer frame's snapshot, causing the outer frame to double-count inflow into `rewardBudget`. User principal remains safe (user entry points are guarded), but emission schedules can be inflated or windows desynced.

**Recommendation**: Add `nonReentrant` to `pullAndRefresh`. Preferably refactor so `dispatcherHook.pull()` returns the exact amount credited, and use that return value rather than `balanceOf` deltas. Explicitly document whether `dispatcherHook` is trusted or untrusted.

---

### [L-02] `setWindowDuration` accrues under OLD rate without first pulling fresh dispatcher mint-debt

**Location**: [`NFTStaker.sol#L183-L195`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L183-L195)

**Description**: `setWindowDuration` calls `_updatePool` (settling accrual under the *old* rate) but does not call `_syncBudget`, so any outstanding mint-debt sitting at the dispatcher is not pulled in before the rate is recomputed. Consequently, the new `rewardRate = rewardBudget / newDuration` is computed against a budget that excludes pending dispatcher debt. A subsequent user action then pulls the mint-debt and triggers another reset — `windowEnd = now + newDuration, rewardRate = fullBudget / newDuration` — using the new short duration against the freshly-swept full budget, producing a very high rate.

**Impact**: Owner can inadvertently (or deliberately) schedule an emission spike: shorten the window while dispatcher debt is large, then any user action post-settlement spikes the rate to `fullBudget / newDuration`. Stakers present during that window drain a disproportionate tranche; latecomers get nothing until the next pull. Breaks the implicit invariant "changing duration computes rate against *current* budget."

**Recommendation**: Have `setWindowDuration` call `_syncBudget` (not just `_updatePool`) so the recomputation includes any pending dispatcher mint-debt. Additionally consider a maximum-rate sanity check (e.g. `rewardBudget / newDuration <= maxRate`) or a timelock on window changes. Consider gating `setWindowDuration` on `whenNotPaused`.

---

### [L-03] `emergencyWithdraw` does not settle accrual, redirecting the exiting user's pro-rata emissions to remaining stakers

**Location**: [`NFTStaker.sol#L339-L354`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L339-L354)

**Description**: `emergencyWithdraw` sets `user.amount = 0` and decrements `totalStaked`, but deliberately does not call `_updatePool()` / `_syncBudget()` per the spec. The consequence is that all accrual over `[lastRewardTime, block.timestamp]` is attributed to the new, smaller `totalStaked` on the next `_updatePool`. The exiting user's fair share of that interval is silently redistributed to whoever is still staked, because `accRewardPerShare` is incremented using the reduced denominator.

**Impact**: Exploitable by a staker who controls multiple accounts: account A stakes a large amount, account B stakes a small amount, attacker calls `emergencyWithdraw` on A just before a major `pull()`, and B then absorbs effectively the full elapsed-interval emission at the new denominator. Bounded by the reward accrued in the interval since the last `_updatePool` call, but because `emergencyWithdraw` is callable while paused, an attacker can coordinate exits at strategic moments.

**Recommendation**: Call `_updatePool()` (not `_syncBudget`, to preserve the spec's intent of isolating from a broken dispatcher) at the start of `emergencyWithdraw` to settle accrual under the existing denominator before it shrinks.

---

### [L-04] Reward-token accounting in `_syncBudget` and `topUp` is fragile against fee-on-transfer or rebasing reward tokens

**Location**: [`NFTStaker.sol#L197-L206`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L197-L206), [`NFTStaker.sol#L218-L230`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L218-L230)

**Description**: Two sites credit `rewardBudget` under the assumption that phUSD is a canonical 1-for-1 ERC20:

1. `_syncBudget` measures `inflow = rewardToken.balanceOf(this) - pre` rather than using the amount reported by `dispatcherHook.pull()`. For a fee-on-transfer or rebasing reward token, measured `inflow` diverges from the dispatcher's accounting: the hook may clear a larger mint-debt than NFTStaker credits.
2. `topUp` does the opposite — unconditionally credits the input `amount` to `rewardBudget` without measuring the actual balance delta. Under a fee-on-transfer token this over-counts `rewardBudget` vs. real balance.

**Impact**: `_syncBudget`: divergence between dispatcher-minted and staker-credited budget — under-credits budget and users under-earn, or (rebasing) over-credits and drains beyond debt. `topUp`: `rewardBudget` drifts above real balance and late claimants are silently capped by `_safePay`.

**Recommendation**: In `topUp`, measure the actual inflow via a balance snapshot before/after the `safeTransferFrom` and use the delta. In `_syncBudget`, either (a) have `dispatcherHook.pull()` return the exact amount credited, or (b) assert `inflow == hook.reportedMinted()` and revert on mismatch. If phUSD is guaranteed canonical, document that assumption explicitly in NatSpec.

---

### [L-05] Reward-rate reset on every non-zero pull / top-up back-loads emissions and re-truncates residual on each reset

**Location**: [`NFTStaker.sol#L183-L230`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L183-L230)

**Description**: Whenever `_syncBudget` sees non-zero inflow, or `topUp` runs, or `setWindowDuration` runs, the code sets `windowEnd = block.timestamp + windowDuration` and recomputes `rewardRate = rewardBudget / windowDuration`. The new rate is derived from the *new* `rewardBudget`, which still contains the untruncated residual from the old schedule. On each reset the residual is re-divided by the full `windowDuration`, which truncates again. Additionally, frequent resets mean inflow is amortized over a fresh full window rather than the remaining window, back-loading emissions asymptotically slower than `budget / windowDuration`.

**Impact**: Cumulative under-distribution of rewards to stakers across many pull/topUp cycles. The protocol retains the dust (consistent with the "round in favor of protocol" principle) but the compounded magnitude can reach `O(N * windowDuration)` wei over the life of the pool — larger than the 1-wei-per-accrual order-of-magnitude the `_safePay` comment implies.

**Recommendation**: Amortize inflow into the *remaining* window rather than resetting to a full new window: `remaining = windowEnd > now ? windowEnd - now : windowDuration; rewardRate = rewardBudget / remaining`. Alternatively, accrue via `rewardBudget * elapsed / windowDuration` directly and eliminate the intermediate `rewardRate`. Add an invariant test bounding the sum-of-claimed vs. sum-of-inflows gap.

---

### [L-06] `pendingReward()` over-reports available rewards by not accounting for the `_safePay` balance cap

**Location**: [`NFTStaker.sol#L360-L373`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L360-L373)

**Description**: `pendingReward(address)` returns the full theoretical entitlement `(user.amount * acc) / ACC_PRECISION - user.rewardDebt`, but the actual claimable amount is bounded by `min(entitlement, rewardToken.balanceOf(this))` because `_safePay` caps payout at the on-chain balance. When the pool is momentarily under-funded (between accrual and the next `pull()`), `pendingReward` reports a number the user cannot actually claim.

**Impact**: UI display drift, and — combined with the unconditional `rewardDebt` advancement in the claim paths — silent loss of the unpaid shortfall. Keepers and indexers issue claims that underpay without warning.

**Recommendation**: Either (a) clamp `pendingReward` to `rewardToken.balanceOf(address(this))` so the view matches what a claim will actually pay, or (b) fix the state-mutating path so the shortfall rolls over and the view is accurate as a forward-looking entitlement. Preferably both.

---

### [L-07] `emergencyWithdraw` produces drift in the `balance == rewardBudget + totalDebt` invariant

**Location**: [`NFTStaker.sol#L339-L354`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L339-L354)

**Description**: `emergencyWithdraw` correctly forfeits pending rewards and skips `_syncBudget` / `_updatePool`. However, by the time the user emergency-withdraws, prior `_updatePool` calls have already decremented `rewardBudget` to account for their accrued share. That share sits on the contract's balance but is no longer reflected in either `rewardBudget` or any user's `rewardDebt`, so the invariant documented on `totalDebt()` (`balance == rewardBudget + totalDebt`) drifts upward by the forfeited amount after every `emergencyWithdraw`.

**Impact**: Not exploitable but operators reconciling funds will see spurious "surplus" that does not correspond to real accounting. `totalDebt()` becomes misleading after any `emergencyWithdraw`.

**Recommendation**: On `emergencyWithdraw`, either (a) credit the forfeited pending back to `rewardBudget` so it is re-emitted in future windows (keeps the invariant clean and matches the protocol-favor rounding principle), or (b) explicitly document the invariant shift and expose a `forfeited` accumulator.

---

### [L-08] `totalBudget()` and `runwaySeconds()` are internally inconsistent and do not project pending accrual

**Location**: [`NFTStaker.sol#L402-L418`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L402-L418)

**Description**: `totalBudget()` returns `rewardToken.balanceOf(this) + dispatcherHook.mintDebt()`, while `runwaySeconds()` returns `(rewardBudget + dispatcherHook.mintDebt()) / rewardRate`. The two use different quantities for the on-hand portion: `balanceOf` includes already-earmarked `totalDebt`, while `rewardBudget` does not. The views cannot be reconciled without replicating `_updatePool` client-side. `runwaySeconds` also does not project pending accrual before dividing, so it is slightly optimistic right after long intervals without interaction.

**Impact**: View-only. Monitoring dashboards and UIs display inconsistent runway / budget figures.

**Recommendation**: Make the views internally consistent — have `totalBudget` return `rewardBudget + dispatcherHook.mintDebt()` (excluding earmarked debt) to match `runwaySeconds`, or return a struct `(freeBudget, earmarkedDebt, pendingHook)`. Update `runwaySeconds` to perform a `_updatePool`-style projection (as `pendingReward` does) for a current-instant runway. Document each view's semantics in NatSpec.

---

### [L-09] `Claimed` event gated on `paid > 0` while `rewardDebt` advances unconditionally — shortfalls are invisible off-chain

**Location**: [`NFTStaker.sol#L264-L267`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L264-L267), [`NFTStaker.sol#L290-L293`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L290-L293), [`NFTStaker.sol#L313-L317`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L313-L317)

**Description**: `stake`, `unstake`, and `claim` only emit `Claimed` when `_safePay`'s return value is non-zero. `rewardDebt` is nevertheless advanced to the full `(amount * acc) / PREC` in all three paths regardless of whether anything was paid. A user whose pending is fully capped by `_safePay` (`paid = 0`) has their entitlement zeroed silently with no on-chain event — off-chain indexers cannot detect the forfeiture.

Separately, `claim()` uses a local `paid`, while `stake()` / `unstake()` reassign the outer `pending` variable — the inconsistent naming masks the silent-forfeiture behavior and makes review harder.

**Impact**: Off-chain accounting cannot reconstruct user debt from event logs. Silent shortfalls go unnoticed.

**Recommendation**: Always emit an event with `(entitlement, paid)` — e.g., `ClaimAttempted(user, entitlement, paid)` — so indexers can track shortfalls even when `paid == 0`. Rename the `pending` reassignment to a distinct `paid` variable for clarity and consistency across the three paths.

---

## Centralization Risks

### [C-01] Unilateral owner control over `dispatcherHook`, `windowDuration`, `topUp`, `pauser`, and `stakedId` creates multiple high-leverage centralization points

**Location**: [`NFTStaker.sol#L153-L206`](https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L153-L206)

**Description**: The `onlyOwner` admin holds several powerful levers, none of which are time-locked or role-segregated:

1. **`setDispatcherHook`** — can repoint to an arbitrary `IBalancerPoolerMintDebtHook`. Since `_syncBudget` measures `inflow = balanceOf(this) - pre` and credits that to `rewardBudget`, a malicious replacement hook with mint rights can mint unlimited phUSD to this contract and credit it as emissions. Alternatively the owner can zero it to strand dispatcher mint-debt.
2. **`setWindowDuration`** — can choose any duration in `[MIN_WINDOW = 1 day, MAX_WINDOW = 10 years]`. Worst case is a 3650× rate change in one transaction: with `newDuration = MAX_WINDOW` and `oldWindowRemaining = 1 day`, that's a 99.97% rate reduction. Floor-division makes it sharper — if `rewardBudget < newDuration`, the new rate is zero and emissions halt entirely until re-top-up. Compounds with L-02.
3. **`topUp`** — writes an arbitrary `rewardBudget` and also resets `windowEnd` as a side effect (front-run vector).
4. **`setPauser`** — owner can change the pause authority, including to themselves, bypassing any intended role segregation.
5. **`setStakedId`** — gated on `totalStaked == 0`, but owner can pause-and-force-exit users via `emergencyWithdraw` (the only escape) to reach that state and migrate the pool non-consensually.

None of these actions are guarded by a timelock or emit a warning period; users have no "check-in" window to react before the change takes effect on the next block.

**Impact**: Owner-driven emission manipulation, fund redirection via hook replacement, emission halt, or forced pool reconfiguration — all in a single transaction with no user recourse.

**Recommendation**: Place `setDispatcherHook`, `setWindowDuration`, `setStakedId`, and `setPauser` behind a timelock (e.g., 48 hours). For `setWindowDuration`, additionally bound each call to a bounded multiplicative change (e.g., `newDuration <= 2 * currentDuration && newDuration >= currentDuration / 2`) with a cooldown, or require `newRate >= currentRate / 2`. For `topUp`, make the window reset opt-in (`topUp(amount, resetWindow)`) rather than automatic. Consider splitting roles: a `SCHEDULER_ROLE` for window / rate changes and a separate `CONFIGURATOR_ROLE` for hook / staked-id changes.
