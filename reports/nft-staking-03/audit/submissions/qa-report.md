# QA Report - Phoenix NFT Staker

**Contract:** `lib/phoenix-nft-staking/src/NFTStaker.sol`
**Commit:** `960e20d`

This report bundles all Low severity and Centralization findings identified during audit of `NFTStaker.sol`. None of the issues herein rise to direct-theft or protocol-insolvency impact, but several affect accounting accuracy, user availability under degraded conditions, and owner-induced DoS surface area.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 6 |
| Centralization | 2 |
| **Total** | **8** |

---

## Low Risk Findings

### [L-01] Forfeited rewards from `emergencyWithdraw` stranded in contract

**Lines of code:** [NFTStaker.sol#L314-L323](lib/phoenix-nft-staking/src/NFTStaker.sol#L314-L323)

**Impact:** `emergencyWithdraw` zeros `user.amount` and returns principal but does not credit the user's forfeited pending rewards (`user.amount * accRewardPerShare / 1e18 - user.rewardDebt`) back to `rewardBudget`. The forfeited amount sits idle in the contract with no recovery path — no sweep function exists — causing `rewardToken.balanceOf(this) > rewardBudget + totalDebt` drift over time. The `totalDebt()` view also misreports as a consequence.

**Recommendation:** Add the forfeited pending back into `rewardBudget` (and re-derive `rewardRate` / `windowEnd`) within `emergencyWithdraw`, or expose an owner-only drift recovery function.

---

### [L-02] `_safePay` revert on unstake forces principal-retention hazard

**Lines of code:** [NFTStaker.sol#L264-L279](lib/phoenix-nft-staking/src/NFTStaker.sol#L264-L279), [NFTStaker.sol#L301-L307](lib/phoenix-nft-staking/src/NFTStaker.sol#L301-L307)

**Impact:** If the reward token balance is less than pending at unstake time, `_safePay` reverts the entire call, blocking principal withdrawal. Users must then fall back to `emergencyWithdraw`, forfeiting all accrued rewards. A transient reward-token shortfall is thus coupled to principal exit, penalizing users for conditions they cannot control.

**Recommendation:** Split the payout so principal always returns; pay rewards best-effort, or queue any residual shortfall as unclaimed dust for later top-up.

---

### [L-03] `emergencyWithdraw` skips `_updatePool`, over-attributes accrual to remaining stakers

**Lines of code:** [NFTStaker.sol#L314-L323](lib/phoenix-nft-staking/src/NFTStaker.sol#L314-L323)

**Impact:** `emergencyWithdraw` decrements `totalStaked` without calling `_updatePool` first. The next `_updatePool` call then computes `accRewardPerShare += reward * 1e18 / totalStaked` using the reduced denominator across the elapsed pre-exit window. Remaining stakers receive a larger share of that pre-exit accrual than they actually earned, and the exiter's forfeited rewards redistribute incorrectly.

**Recommendation:** Introduce a no-revert, on-chain-state-only `_updatePoolNoHook()` variant and invoke it before `totalStaked -= amount`, preserving the share history even when the dispatcher hook is broken (see C-02).

---

### [L-04] `setStakedId` griefable by 1-wei staker

**Lines of code:** [NFTStaker.sol#L153-L157](lib/phoenix-nft-staking/src/NFTStaker.sol#L153-L157)

**Impact:** `setStakedId` requires `totalStaked == 0`. Any staker holding a single unit of the staked asset can block an owner migration indefinitely. No force-unstake mechanism exists for the owner to unblock the path.

**Recommendation:** Add an owner-gated `forceEmergencyWithdraw(address staker)` callable while paused, or permit `setStakedId` while paused regardless of `totalStaked`.

---

### [L-05] `topUp` and `pullAndRefresh` lack `nonReentrant`

**Lines of code:** [NFTStaker.sol#L181-L190](lib/phoenix-nft-staking/src/NFTStaker.sol#L181-L190), [NFTStaker.sol#L195-L197](lib/phoenix-nft-staking/src/NFTStaker.sol#L195-L197)

**Impact:** Both owner-only entrypoints touch reward accounting and make external calls (`safeTransferFrom` / `dispatcherHook.pull`) without the reentrancy guard applied to user paths. Latent under the current trust model, but exposed if either the reward token or dispatcher contract is ever swapped to one with callback semantics.

**Recommendation:** Apply `nonReentrant` to both functions for defense-in-depth.

---

### [L-06] `rewardRate` floors to zero for small budgets

**Lines of code:** [NFTStaker.sol#L167](lib/phoenix-nft-staking/src/NFTStaker.sol#L167), [NFTStaker.sol#L188](lib/phoenix-nft-staking/src/NFTStaker.sol#L188), [NFTStaker.sol#L218](lib/phoenix-nft-staking/src/NFTStaker.sol#L218)

**Impact:** Integer division `rewardBudget / windowDuration` rounds to zero when `rewardBudget < windowDuration` seconds. Emissions silently halt and the dust budget is stranded until the next meaningful inflow recomputes the rate.

**Recommendation:** Document the minimum viable budget, or emit an event when `rewardRate` recomputes to zero while `rewardBudget > 0` so off-chain monitors can surface the condition.

---

## Centralization Risks

### [C-01] `setMinPullInterval` lacks upper bound, enables owner-induced user DoS

**Lines of code:** [NFTStaker.sol#L170-L173](lib/phoenix-nft-staking/src/NFTStaker.sol#L170-L173), [NFTStaker.sol#L210](lib/phoenix-nft-staking/src/NFTStaker.sol#L210)

**Impact:** The owner can set `minPullInterval` to a value near `type(uint256).max`. Once `lastPullAt > 0`, the expression `lastPullAt + minPullInterval` overflows in checked arithmetic, reverting every `_syncBudget(false)` call. All user entrypoints (`stake`, `unstake`, `claim`) brick until the owner resets the value via another setter call. Principal remains recoverable via `emergencyWithdraw`, but all accrued rewards are forfeited.

**Recommendation:** Cap `minPullInterval` at a reasonable maximum (e.g., `MAX_WINDOW`) inside the setter.

---

### [C-02] Broken `dispatcherHook.pull()` DoSes all user entrypoints

**Lines of code:** [NFTStaker.sol#L211-L213](lib/phoenix-nft-staking/src/NFTStaker.sol#L211-L213)

**Impact:** `_syncBudget` calls `dispatcherHook.pull()` unconditionally after the cooldown. The hook is an owner-controlled, mutable sibling contract with its own recipient configuration. If the hook reverts, is misconfigured, or is re-pointed to a non-compliant target, every user entrypoint that routes through `_syncBudget` reverts. Users are left with `emergencyWithdraw` as their only exit path, forfeiting rewards.

**Recommendation:** Wrap `dispatcherHook.pull()` in a `try/catch` on user paths so accrual via `_updatePool` continues even when the dispatcher is degraded.

---
