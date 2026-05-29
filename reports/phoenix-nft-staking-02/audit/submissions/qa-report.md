# QA Report — NFTStaker (Phoenix nft-staking re-audit)

## Intro

This QA bundle covers the second-round audit of `NFTStaker.sol` in the Phoenix `nft-staking` submodule (pinned commit `5062553`). The contract is a masterchef-style single-ID ERC1155 staking pool that emits phUSD over a configurable depletion window and pulls additional budget from the `BalancerPoolerMintDebtHook` dispatcher. The findings below are residual hardening opportunities on top of the story-001 / story-002 / story-003 remediations delivered since the prior audit: minor accounting drifts, view-consistency issues, UX regressions introduced by the prior-audit fix, spec-vs-implementation divergences, and one centralization / setter-ordering defect. None rise to Medium individually; collectively they map out the remaining polish work.

## Summary

| Severity       | Count |
| -------------- | ----- |
| Low Risk       | 11    |
| Centralization | 1     |
| **Total**      | **12**|

## Table of Contents

| ID    | Title                                                                                                    |
| ----- | -------------------------------------------------------------------------------------------------------- |
| L-01  | `emergencyWithdraw` skips `_updatePool`, redistributing the exiting user's pending emission               |
| L-02  | `setWindowDuration` does not call `_syncBudget`, so pending mint-debt is excluded from the new rate       |
| L-03  | `ownerOrNotGriefed` modifier has three edge-case bypasses                                                 |
| L-04  | `_safePay` revert in `stake()`/`unstake()` blocks principal adjustments during transient shortfall        |
| L-05  | `pullAndRefresh` is not `nonReentrant`, exposing cross-frame budget double-counting                       |
| L-06  | Balance-sniffing accounting allows phUSD donations to inflate `totalDebt()` and leak into `_safePay`     |
| L-07  | `rewardRate` floor-divides to zero when `rewardBudget < windowDuration`, stranding dust                   |
| L-08  | `emergencyWithdraw` does not credit forfeited pending back to `rewardBudget`                              |
| L-09  | `pendingReward` view does not clamp against balance and does not project dispatcher `mintDebt`            |
| L-10  | `totalBudget()` and `runwaySeconds()` use inconsistent accounting bases                                   |
| L-11  | Zero-stake periods burn emission schedule against no stakers, stranding budget                            |
| C-01  | `setDispatcherHook` does not settle pending mint-debt from the old dispatcher before swapping            |

---

## Low Risk Findings

### [L-01] `emergencyWithdraw` skips `_updatePool`, redistributing the exiting user's pending emission to remaining stakers

**Summary.** `emergencyWithdraw` decrements `totalStaked` without first calling `_updatePool`. Any accrual over `[lastRewardTime, now]` is then divided by the already-reduced denominator when the next user action settles the pool, shifting the exiting user's pro-rata share onto remaining stakers.

**Vulnerability details.** [`NFTStaker.sol#L314-L323`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L314-L323):

```solidity
function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = users[msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "NFTStaker: nothing to withdraw");
    user.amount = 0;
    user.rewardDebt = 0;
    totalStaked -= amount;                          // <-- denominator shifted without settling
    stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
    emit EmergencyWithdrawn(msg.sender, amount);
}
```

The subsequent `_updatePool` call (from the next staker's interaction) computes `accRewardPerShare += (elapsed * rewardRate * ACC_PRECISION) / totalStaked_new`, inflating the per-share figure.

**Impact.** Low. Redistribution is bounded by `(exiting.amount / totalStaked_old) * rewardRate * (now - lastRewardTime)` and is only material when `lastRewardTime` is meaningfully stale (e.g. extended pause or idle pool). No value escapes the protocol; share split skews between stakers.

**Recommended mitigation.** Call `_updatePool()` at the top of `emergencyWithdraw`. Since `emergencyWithdraw` must remain safe against a broken dispatcher hook, call `_updatePool()` directly rather than `_syncBudget()`.

---

### [L-02] `setWindowDuration` does not call `_syncBudget`, so pending dispatcher mint-debt is excluded from the new rate

**Summary.** `setWindowDuration` recomputes `rewardRate` against the in-contract `rewardBudget` only, ignoring mint-debt still pending on the dispatcher hook. The announced rate and the post-sync effective rate diverge until the next user action.

**Vulnerability details.** [`NFTStaker.sol#L166-L175`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L166-L175):

```solidity
function setWindowDuration(uint256 newDuration) external onlyOwner {
    require(newDuration >= MIN_WINDOW && newDuration <= MAX_WINDOW, "NFTStaker: window out of bounds");
    _updatePool();                                 // <-- pulls no mint-debt
    emit WindowDurationChanged(windowDuration, newDuration);
    windowDuration = newDuration;
    windowEnd = block.timestamp + newDuration;
    rewardRate = newDuration == 0 ? 0 : rewardBudget / newDuration;
}
```

If large mint-debt is pending on the dispatcher, the very next `claim/stake/unstake` pulls it and re-derives `rewardRate` against the shortened window, producing a rate spike that a JIT staker can capture.

**Impact.** Low. Operator-ordering defect. No permissionless attack path; self-corrects on the next sync. Creates a small MEV surface and off-chain rate/UI mismatch.

**Recommended mitigation.** Replace the `_updatePool()` call with `_syncBudget()` so mint-debt folds into `rewardBudget` before the new rate is computed.

---

### [L-03] `ownerOrNotGriefed` modifier has three edge-case bypasses

**Summary.** The rate-reduction guard in `ownerOrNotGriefed` can be bypassed (i) at truncation boundaries where `rewardRate` rounds equal pre/post, (ii) when the window was already expired at entry, and (iii) when `rewardBudget < windowDuration` so the truncated rate is `0` and the post-condition vacuously passes.

**Vulnerability details.** [`NFTStaker.sol#L114-L121`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L114-L121):

```solidity
modifier ownerOrNotGriefed() {
    uint256 rPre = rewardRate;
    uint256 endPre = windowEnd;
    _;
    require(
        msg.sender == owner() || rewardRate >= rPre || endPre <= block.timestamp, "NFTStaker: reward rate reduced"
    );
}
```

Each instance allows a non-owner to call `topUp` / `pullAndRefresh`, extend `windowEnd` by `windowDuration`, and escape the rate-floor defence.

**Impact.** Low. Each bypass requires a narrow degenerate state (truncation coincidence, expired window with residual budget, dust-stranded budget). Effect is schedule-stretch per call, not value theft. The primary protocol-impact scenario is already mitigated by story-003; these are defensive-completeness edge cases.

**Recommended mitigation.** Compare against the pre-call schedule directly (e.g. require `windowEnd <= endPre || ...`) rather than rate-only, and/or reject the call entirely when the truncated rate would be zero.

---

### [L-04] `_safePay` revert in `stake()`/`unstake()` blocks principal adjustments during transient shortfall

**Summary.** Story-002 correctly makes `_safePay` revert on shortfall to prevent silent reward forfeiture. As a side effect, `stake()` and `unstake()` — which call `_safePay` on any non-zero pending — revert entirely during a transient shortfall window, preventing the user from touching their principal until the pool is replenished.

**Vulnerability details.** The pattern in [`stake()` at L246-L262`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L246-L262) and [`unstake()` at L264-L279`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L264-L279) settles pending via `_safePay` before mutating `user.amount`:

```solidity
if (user.amount > 0) {
    uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    if (pending > 0) {
        pending = _safePay(pending);               // reverts under shortfall
        if (pending > 0) emit Claimed(msg.sender, pending);
    }
}
```

If the contract's phUSD balance is temporarily below the user's pending (dispatcher lag or concurrent drain by another claimant), the whole call reverts and the user cannot add to or reduce their principal position until balance recovers.

**Impact.** Low. UX regression only. Pending reward is preserved in storage across the wait and remains claimable once balance recovers. `emergencyWithdraw` is available as an escape but forfeits pending; the story-002 revert is otherwise working as intended.

**Recommended mitigation.** Introduce a rollover / claim-deferral semantic: if `_safePay` would revert, cap the paid amount at the available balance and carry the shortfall forward by adjusting `user.rewardDebt` to keep the remainder owed. Alternatively, allow users to stake/unstake without settling pending (via a dedicated `stakeWithoutClaim` path).

---

### [L-05] `pullAndRefresh` remains non-`nonReentrant`, exposing cross-frame budget double-counting via a malicious/upgraded dispatcher

**Summary.** `pullAndRefresh` is permissionless and lacks `nonReentrant`. A compromised or maliciously-upgraded dispatcher can reenter during `dispatcherHook.pull()`, causing the balance-delta inflow measurement to double-count its own credit.

**Vulnerability details.** [`NFTStaker.sol#L200-L220`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L200-L220):

```solidity
function pullAndRefresh() external ownerOrNotGriefed {       // <-- no nonReentrant
    _syncBudget();
}
...
function _syncBudget() internal {
    _updatePool();
    if (address(dispatcherHook) == address(0)) return;
    uint256 pre = rewardToken.balanceOf(address(this));
    dispatcherHook.pull();                                    // <-- reentry vector
    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
    if (inflow == 0) return;
    rewardBudget += inflow;
    ...
}
```

A reentrant nested `pullAndRefresh` credits inflow to `rewardBudget`, after which the outer frame re-measures the balance delta including the nested credit.

**Impact.** Low (defence-in-depth). Exploit requires a compromised or adversarially-upgraded dispatcher, which is outside the trust model. The omission is nonetheless a concrete defensive-coding gap with a one-line fix.

**Recommended mitigation.** Add `nonReentrant` to `pullAndRefresh` (and consider adding it to `topUp` for symmetry with the user entrypoints).

---

### [L-06] Balance-sniffing accounting allows external phUSD donations to inflate `totalDebt()` and leak into `_safePay` buffer

**Summary.** `totalDebt()` and `_safePay` both read the contract balance directly. An external actor who sends phUSD directly to the contract inflates `totalDebt()` by the donation and silently underwrites future `_safePay` overages, with no folding path back into `rewardBudget`.

**Vulnerability details.** [`totalDebt()` at L352-L363`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L352-L363):

```solidity
uint256 balance = rewardToken.balanceOf(address(this));
return balance > budget ? balance - budget : 0;
```

And [`_safePay` at L301-L307`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L301-L307) checks the balance, not `rewardBudget`. A donation therefore (a) makes `totalDebt()` over-report, and (b) quietly funds any rounding shortfall in `_safePay`.

**Impact.** Low. No staker funds at risk — the donor voluntarily forfeits the funds, which sit stranded on-contract since there is no re-fold path. View-reporting drift and a silent buffer are the only effects.

**Recommended mitigation.** Fold unexpected balance deltas into `rewardBudget` on every `_syncBudget` invocation (e.g. credit `balanceOf(this) - (rewardBudget + totalDebt())` into `rewardBudget` once per sync), or expose an explicit `sweep()` function that moves any donation surplus into the budget.

---

### [L-07] `rewardRate = rewardBudget / windowDuration` floor-divides to zero when budget < windowDuration, stranding dust

**Summary.** Because `rewardRate` is not scaled by `ACC_PRECISION`, the integer division `rewardBudget / windowDuration` truncates any residue below one wei per second, and floors to zero entirely whenever `rewardBudget < windowDuration`.

**Vulnerability details.** Seen in three places — [`setWindowDuration` L174`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L174), [`topUp` L192`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L192), and [`_syncBudget` L218`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L218):

```solidity
rewardRate = rewardBudget / windowDuration;     // truncates sub-wei-per-second residue
```

At the default 540-day window (~4.67e7 seconds), per-reset dust is bounded at ~4.67e7 wei of phUSD (sub-nanocent). When `rewardBudget < windowDuration` the rate falls to zero and emissions stall until an owner top-up, which also enables the L-03 Instance C modifier bypass.

**Impact.** Low. Dust-stranding is explicitly QA/Low per C4 special-cases guidance; per-reset magnitude is economically irrelevant. The zero-rate corner case is a knock-on concern already covered by L-03.

**Recommended mitigation.** Scale `rewardRate` by `ACC_PRECISION` at storage and divide back out in the accrual computation, preserving sub-wei precision and eliminating the zero-rate edge case.

---

### [L-08] `emergencyWithdraw` does not credit forfeited pending back to `rewardBudget`, causing invariant drift

**Summary.** When a user calls `emergencyWithdraw` with non-zero pending, their pending reward is implicitly forfeited but `rewardBudget` is not re-credited. The invariant `balance == rewardBudget + totalDebt` drifts upward by the forfeited amount on each emergency exit.

**Vulnerability details.** [`NFTStaker.sol#L314-L323`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L314-L323): pending is recoverable as `(user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt` at entry, but the function zeros `user.amount`/`rewardDebt` without computing or re-crediting it. The forfeited phUSD stays on-contract but is not accounted anywhere — it becomes phantom debt.

**Impact.** Low. Pure accounting-invariant drift. No funds leave the contract; `totalDebt()` over-reports transiently until the next sync folds the residue back in. No staker is worse off at the individual level — only the reported budget/debt split is wrong.

**Recommended mitigation.** Before zeroing user state, compute `pending` and increment `rewardBudget` by that amount (or equivalently decrement `accRewardPerShare` by the forfeited share). Emit the forfeited amount in the `EmergencyWithdrawn` event for observability.

---

### [L-09] `pendingReward` view does not clamp against balance and does not project dispatcher `mintDebt`

**Summary.** `pendingReward(user)` returns a user's entitlement without (a) clamping to the actual claimable amount under story-002 `_safePay` revert semantics, and (b) projecting still-pending dispatcher mint-debt into `accRewardPerShare`. Frontends and keepers that read the view may issue `claim()` transactions that revert, or may under-display pending during accrual between syncs.

**Vulnerability details.** [`NFTStaker.sol#L329-L340`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L329-L340):

```solidity
function pendingReward(address account) external view returns (uint256) {
    UserInfo memory user = users[account];
    uint256 acc = accRewardPerShare;
    if (block.timestamp > lastRewardTime && totalStaked > 0) {
        uint256 end = block.timestamp < windowEnd ? block.timestamp : windowEnd;
        uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;
        uint256 reward = elapsed * rewardRate;
        if (reward > rewardBudget) reward = rewardBudget;
        acc += (reward * ACC_PRECISION) / totalStaked;
    }
    return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;   // no balance clamp, no mintDebt projection
}
```

**Impact.** Low. View-function inaccuracy; no on-chain value effect. Harm is wasted gas on revert-bound `claim()` calls and inaccurate UI during shortfall / pre-sync windows.

**Recommended mitigation.** Clamp the return value to `min(entitlement, rewardToken.balanceOf(address(this)))` to match `_safePay` semantics, and add a second view (`pendingRewardProjected`) that folds `dispatcherHook.mintDebt()` into the budget before accrual, so integrators can display both the immediately-claimable and post-sync figures.

---

### [L-10] `totalBudget()` and `runwaySeconds()` use inconsistent accounting bases

**Summary.** `totalBudget()` returns `balanceOf(this) + mintDebt`, which includes phUSD earmarked for earned-but-unclaimed reward. `runwaySeconds()` returns `(rewardBudget + mintDebt) / rewardRate`, which excludes earmarked debt. The two disagree by `totalDebt()`, breaking off-chain reconciliation.

**Vulnerability details.** [`totalBudget()` L367-L370`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L367-L370) and [`runwaySeconds()` L375-L379`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L375-L379):

```solidity
function totalBudget() external view returns (uint256) {
    uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();
    return rewardToken.balanceOf(address(this)) + pending;          // balance-based
}

function runwaySeconds() external view returns (uint256) {
    if (rewardRate == 0) return 0;
    uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();
    return (rewardBudget + pending) / rewardRate;                   // rewardBudget-based
}
```

**Impact.** Low. View-only inconsistency. No on-chain value effect. Monitoring dashboards cannot reconcile the two.

**Recommended mitigation.** Pick one accounting base (ideally `rewardBudget + mintDebt`, which is what governs emission) and apply it to both views, with NatSpec documenting which figure is reported. Update on-chain consumers accordingly.

---

### [L-11] Zero-stake periods burn emission schedule against no stakers, stranding budget when stake returns to zero mid-window

**Summary.** When `totalStaked == 0`, `_updatePool` advances `lastRewardTime` to `block.timestamp` without emitting, but `windowEnd` is never extended. A material zero-stake gap between funding and first stake therefore shortens the effective runway below the nominal `windowDuration`.

**Vulnerability details.** [`_updatePool` L225-L240`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L225-L240):

```solidity
function _updatePool() internal {
    if (block.timestamp <= lastRewardTime) return;
    if (totalStaked == 0) {
        lastRewardTime = block.timestamp;          // advance time, but windowEnd untouched
        return;
    }
    ...
}
```

If the pool is funded at `t0` with `windowEnd = t0 + windowDuration`, then a first staker arrives at `t0 + X`, the effective runway is `windowDuration - X`, not `windowDuration`.

**Impact.** Low. Spec-intent (`windowDuration` of staking time) vs implementation (wall-clock) divergence. Budget is not permanently stranded — the owner can re-anchor via `setWindowDuration`, and `pullAndRefresh` with non-zero inflow re-anchors too. No permissionless exploit.

**Recommended mitigation.** When `totalStaked == 0` in `_updatePool`, also extend `windowEnd` by the elapsed interval so wall-clock drift does not consume scheduled emission time. Alternatively, document the wall-clock semantics explicitly and gate funding on a non-zero `totalStaked`.

---

## Centralization Risks

### [C-01] `setDispatcherHook` does not settle pending mint-debt from the old dispatcher before swapping, stranding accrued debt

**Summary.** `setDispatcherHook` swaps the dispatcher pointer without first calling `_syncBudget()` / `pullAndRefresh()`. Any mint-debt accrued on the old dispatcher is orphaned from the staker's perspective until the owner manually re-points and pulls.

**Vulnerability details.** [`NFTStaker.sol#L155-L158`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L155-L158):

```solidity
function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
    emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
    dispatcherHook = newHook;                      // <-- swap with no preceding pull
}
```

Subsequent `_syncBudget` calls consult `newHook`, which has zero accrued debt.

**Impact.** Centralization. Only the owner can call `setDispatcherHook`; the defect manifests exclusively under incorrect owner ordering and is recoverable by the owner re-pointing to the old dispatcher and calling `pullAndRefresh`. Classic admin-footgun pattern with no permissionless trigger.

**Recommended mitigation.** Call `_syncBudget()` (or `pullAndRefresh()` equivalent logic) at the top of `setDispatcherHook` so any outstanding mint-debt on the old hook is pulled and folded into `rewardBudget` before the pointer is swapped. Add a NatSpec note warning against swapping to a hook whose `pull()` reverts.
