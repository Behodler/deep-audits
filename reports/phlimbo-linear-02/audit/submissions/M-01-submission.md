<!--
C4 Submission Metadata
Title: [M-01] pauseWithdraw decreases totalStaked without calling _updatePool, redistributing the exiting user's elapsed-window rewards to remaining stakers
Severity: Medium
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L280-L291
PoC File: poc-M-01.t.sol
PoC Test: test_M01_pauseWithdrawCausesRewardWindfall
Relationship: Shares the `pauseWithdraw` function with H-01 but addresses a distinct root cause — M-01 is a global-accumulator ordering bug (missing `_updatePool()` before `totalStaked` is decremented), H-01 is a per-user debt invariant bug (missing `rewardDebt` settlement causing later arithmetic underflow). The two findings are independently exploitable, have non-overlapping fixes, and produce different victims (M-01 redistributes value across stakers; H-01 bricks the exiting user's account).
-->

## Finding description and impact

### Summary

`PhlimboV2.pauseWithdraw` decreases `totalStaked` without first invoking `_updatePool()`. Because `lastRewardTime` remains pinned to its pre-`pauseWithdraw` value while the share base shrinks, the next `_updatePool()` call distributes rewards accrued *during* the exiting user's staking window across a smaller `totalStaked`. The exiting user forfeits their pro-rata share of those rewards, and the remaining stakers receive a corresponding windfall.

This is not the documented "emergency exit forfeits rewards" behaviour. The protocol's known-issues list states that `pauseWithdraw` is "an emergency exit mechanism by design" that does not claim rewards — that rationale covers the user's own forfeiture. It does **not** cover the cross-staker redistribution, which over-distributes value from the protocol's linear-depletion schedule to the wrong parties.

### Vulnerability details

[`PhlimboV2.sol#L280-L291`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L280-L291):

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    user.amount -= amount;
    totalStaked -= amount;   // <-- decreases share base while lastRewardTime stays pinned

    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);

    emit EmergencyWithdrawal(msg.sender, amount);
}
```

`_updatePool()` is the function that advances `lastRewardTime` to `block.timestamp` and rolls the elapsed window's emissions into `accStablePerShare` (and the phUSD APY accumulator). It must run **before** any mutation of `totalStaked`, because `accStablePerShare` is computed as:

```
accStablePerShare += (toDistribute * PRECISION) / totalStaked
```

When `pauseWithdraw` runs, two pieces of state diverge:

1. `lastRewardTime` is left at its prior value (`T_prev`), so a future `_updatePool()` will treat the entire window `[T_prev, block.timestamp]` as the elapsed period — including the portion during which the now-departed staker was contributing to `totalStaked`.
2. `totalStaked` has already been decremented by the exiting user's `amount`.

The next time `_updatePool()` is invoked (via `claim`, `stake`, `withdraw`, `setStableRewardsPerSecond`, etc.), `(toDistribute * PRECISION) / totalStaked` is computed against the **reduced** denominator. This inflates `accStablePerShare` by exactly the ratio `original_totalStaked / reduced_totalStaked`. Every remaining staker's pending balance is therefore credited as if they had been the only stakers for the full window — including the pre-exit segment in which the departed staker was, by the protocol's own accounting, entitled to a share.

Crucially, nothing about the pause state suppresses the subsequent `_updatePool()`. `collectReward` is not pause-guarded, `claim`/`stake`/`withdraw` resume the moment the contract is unpaused, and any external call into `_updatePool()` after unpause will commit the inflated accumulator. The window's emissions therefore *are* paid out — just to the wrong addresses.

### Impact

Two-sided economic incorrectness for any pause window in which a partial exit occurs:

1. **Withdrawer-side forfeiture**: the user who calls `pauseWithdraw` silently forfeits their pro-rata share of stable rewards (and phUSD APY emissions) accrued from `lastRewardTime` up to `block.timestamp`. Their `rewardDebt` is never closed out against the pre-exit accumulator (this is also the root of H-01's underflow, but the forfeiture exists independently).
2. **Remaining-staker windfall**: the very emissions the withdrawer forfeited are credited to the remaining stakers via the inflated `accStablePerShare`. The protocol's `rewardBalance` is drained faster than the intended linear-depletion schedule, since real reward tokens are paid out to claimants holding inflated `pending` balances.

The PoC's two-scenario differential isolates this exactly:

- **Control** (Alice exits via the regular `withdraw()` path, which calls `_updatePool()` first): Bob receives `37.5e18` reward tokens — `12.5e18` for his half of the pre-exit window plus `25e18` as the sole staker for the post-exit window.
- **Buggy** (Alice exits via `pauseWithdraw`): Bob receives `50e18` reward tokens — the full window's emissions, including Alice's `12.5e18` fair share of the pre-exit window.

The delta is **12.5e18 reward tokens (~33% over-distribution)** on a 100-token deposit and a quarter-window pre-exit period. The delta scales linearly with stake size and pre-exit duration; for larger pools and longer pre-exit windows the absolute value loss grows proportionally.

This also applies to phUSD APY emissions, which use the same `_updatePool` plumbing: minted phUSD per share is computed against the post-`pauseWithdraw` `totalStaked`, so APY inflation accrues to remaining stakers at the expense of the documented schedule.

### Proof of Concept

See `poc-M-01.t.sol`, test `test_M01_pauseWithdrawCausesRewardWindfall`. The PoC is a strict dual-scenario differential:

- **Scenario A (Buggy)**: Alice exits via `pauseWithdraw` at T1 (no `_updatePool`); Bob claims at T2. Bob receives `~50e18` reward tokens.
- **Scenario B (Control)**: identical timing, but Alice exits via the regular `withdraw()` path at T1 (which calls `_updatePool()` and settles the `[T0, T1]` window against `totalStaked = 2S` before decrementing). Bob receives `~37.5e18` reward tokens.

The test asserts:

1. Control delivers the analytically-expected fair share (`emissionA / 2 + emissionB = 37.5e18`).
2. Buggy delivers the full window emission (`emissionA + emissionB = 50e18`).
3. The delta `bobBuggy - bobControl` equals **exactly Alice's forfeited share** of the pre-exit window (`emissionA / 2 = 12.5e18`), to within 1 gwei of PRECISION-rounding tolerance.
4. The buggy scenario over-distributes by more than 33% versus control — a material accounting error, not a rounding artifact.

The exact-equality assertion on the delta is the load-bearing claim: the value that Bob receives in excess is *not* "extra rewards from somewhere" — it is Alice's accounted-for fair share of `[T0, T1]`, silently re-credited to Bob by the deferred `_updatePool()` against the reduced share base.

### Relationship to H-01

Both findings touch `pauseWithdraw`, but the root causes, exploit paths, and remediations are independent:

| | M-01 (this finding) | H-01 |
|---|---|---|
| **Root cause** | Missing `_updatePool()` before `totalStaked` mutation | Missing `user.rewardDebt` settlement (per-user invariant break) |
| **Affected state** | Global accumulator (`accStablePerShare`, `lastRewardTime`) | Per-user (`userInfo[user].rewardDebt`) |
| **Victim** | Exiting user (forfeiture) + protocol (over-distribution to remaining stakers) | Exiting user (cannot subsequently `claim` — underflow revert) |
| **Symptom** | Silent value redistribution; transactions succeed | Hard revert on every subsequent `claim` |
| **Fix** | Call `_updatePool()` at top of `pauseWithdraw` | Update `user.rewardDebt` (or settle `pending`) on exit |

A reviewer applying only the M-01 fix (calling `_updatePool()` at the top of `pauseWithdraw`) eliminates the cross-staker windfall but leaves H-01's per-user underflow intact for any user who partially exits. A reviewer applying only the H-01 fix (settling `rewardDebt`) closes the underflow but still mis-allocates the elapsed window's emissions to the wrong parties. Both fixes are required, but they should be evaluated and merged independently.

## Recommended mitigation steps

Call `_updatePool()` at the top of `pauseWithdraw`, before any mutation of `totalStaked`:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    _updatePool();                 // <-- advance accumulator against the PRE-exit share base

    user.amount -= amount;
    totalStaked -= amount;

    // (See H-01 for the companion fix: settle user.rewardDebt against the
    //  newly-advanced accStablePerShare so the exiting user's pending is
    //  either paid out or explicitly forfeited via a debt reset rather
    //  than left in an inconsistent state.)

    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);

    emit EmergencyWithdrawal(msg.sender, amount);
}
```

This pins the accumulator advance to the share base that was present during the elapsed window. Combined with the H-01 fix (closing out `user.rewardDebt` against the post-update accumulator), both global and per-user reward accounting remain consistent through emergency exits.

If the design intent is genuinely to **forfeit** the elapsed-window rewards on emergency exit rather than pay them, the correct implementation is to advance `lastRewardTime = block.timestamp` without distributing — i.e. *skip* `accStablePerShare` accumulation for the forfeited portion. The current implementation does the worst-of-both: the window's emissions are computed and distributed, but to the wrong addresses. Whichever semantic the protocol intends, the current behaviour does not match it; the design rationale recorded in the known-issues list ("emergency exit forfeits rewards") is consistent with the *withdrawer* losing their share, not with the *remaining stakers* receiving an inflated credit.
