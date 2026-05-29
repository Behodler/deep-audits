<!--
C4 Submission Metadata
Title: [H-01] Partial `pauseWithdraw` leaves `rewardDebt` stale, permanently bricking `stake`/`withdraw`/`claim` via arithmetic underflow
Severity: High
Root Cause Link: lib/phlimbo-ea/src/PhlimboV2.sol:285
PoC File: reports/phlimbo-ea-02/audit/pocs/poc-H-01.t.sol
-->

## Finding description and impact

### Summary
`PhlimboV2.pauseWithdraw` reduces `user.amount` and `totalStaked` without updating the user's `phUSDDebt` / `stableDebt` and without calling `_updatePool`. After any partial pause-withdraw the reward-debt invariant is broken, and every subsequent `stake`, `withdraw`, `claim`, `pendingPhUSD`, and `pendingStable` call on that user reverts with a Solidity 0.8 arithmetic underflow, permanently stranding the user's remaining principal and accrued rewards.

### Vulnerability details

The reward-accounting invariant the contract relies on is:

```
user.<x>Debt == user.amount * acc<X>PerShare / PRECISION   (at the time the debt was last set)
```

Every other entry point (`stake`, `withdraw`, `claim`) honours this invariant by calling `_updatePool` and then resetting the debt fields. `pauseWithdraw` (lib/phlimbo-ea/src/PhlimboV2.sol:280-291) does not:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    user.amount   -= amount;   // L285  <-- amount shrinks
    totalStaked   -= amount;   // L286
    // user.phUSDDebt and user.stableDebt are NEVER updated.
    // _updatePool() is NEVER called.

    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);
    emit EmergencyWithdrawal(msg.sender, amount);
}
```

The debt fields were set at the previous interaction, when `user.amount` was larger. After the partial withdrawal, `user.amount` is smaller but `user.<x>Debt` still reflects the larger pre-withdrawal balance.

`_claimRewards` (PhlimboV2.sol:486-507) and the two pending-view functions (PhlimboV2.sol:526-545) all compute the pending reward as an unchecked-style subtraction under Solidity 0.8 checked arithmetic:

```solidity
// PhlimboV2.sol:493
uint256 pendingPhUSDAmount =
    (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;
```

After partial `pauseWithdraw`:

- `userDetails.amount * accPerShare / PRECISION` is now `remaining * acc_now`
- `userDetails.<x>Debt` is still `original * acc_at_last_interaction`

For any non-trivial `original / remaining` ratio, the left-hand side is smaller than the right-hand side and the subtraction underflows, triggering `Panic(0x11)` and reverting the entire transaction. Because `_claimRewards` is called by `stake`, `withdraw`, and `claim`, all three entry points are bricked. The `pendingPhUSD` / `pendingStable` views also revert, so even off-chain tooling cannot read the user's state.

The control case in the PoC confirms the root cause: a *full* `pauseWithdraw` (`amount == user.amount`) does not brick the user, because `_claimRewards` short-circuits when `user.amount == 0` before reaching the subtraction. The lockout is therefore specific to the *partial* path and is a distinct invariant violation, not a restatement of the documented "rewards forfeited on emergency exit" design.

### Impact

A user who performs a partial `pauseWithdraw` at any time when the accumulator has advanced is permanently unable to:

- `claim` their accrued phUSD and stable rewards,
- `withdraw` their remaining staked principal,
- `stake` additional phUSD into their position,
- have third-party contracts or front-ends read `pendingPhUSD` / `pendingStable` for them.

The remaining stake (and every unclaimed reward ever accrued by the user) is locked until the relevant accumulator grows enough to satisfy the stale debt — i.e. until `accPerShare` increases by roughly `original_amount / remaining_amount`. For a 1000:1 partial withdrawal that requires a 1000x growth of the accumulator, which under a linear depletion schedule is effectively unbounded and may never occur, particularly if the staking program is wound down.

Per the C4 audit-mode severity guide, *permanent freezing of user funds via a valid attack path without hypotheticals* is High. No malicious actor is required: the loss is a deterministic outcome of the user invoking the documented emergency-exit function. The pauser cannot rescue the position either — the only available rescue is a second pause + `pauseWithdraw` of the residual amount, which still permanently forfeits all rewards because `pauseWithdraw` skips `_claimRewards`.

#### Concrete sequence (deterministic)

1. Bob primes the pool, donor `collectReward(100e18)`, time advances 1 day.
2. Alice stakes `1000e18` phUSD; `_updatePool` runs first so `stableDebt = 1000e18 * acc_now / 1e18` is non-trivial.
3. Pauser calls `pause()`.
4. Alice calls `pauseWithdraw(999e18)`. `user.amount = 1e18`. `user.stableDebt` is unchanged.
5. Pauser calls `unpause()`.
6. Alice calls `claim(alice)` — reverts `Panic(0x11)`.
7. Alice calls `withdraw(1e18, alice)` — reverts `Panic(0x11)`.
8. Alice calls `stake(1e18, alice)` — reverts `Panic(0x11)`.
9. Anyone calls `pendingStable(alice)` / `pendingPhUSD(alice)` — reverts `Panic(0x11)`.

Alice's remaining `1e18` phUSD is permanently locked.

### Proof of Concept

A runnable Foundry PoC is provided at `reports/phlimbo-ea-02/audit/pocs/poc-H-01.t.sol` (workspace path: `workspace/phlimbo-ea/test/poc-H-01.t.sol`). Three tests, all passing:

- **`test_H01_partialPauseWithdraw_locksUser_claimUnderflows`** — primary PoC. Executes the sequence above and asserts that `claim`, `pendingStable`, `withdraw`, and `stake` each revert with `stdError.arithmeticError` (Panic(0x11)). Intermediate assertions confirm `user.amount` shrank from `1000e18` to `1e18` while `user.stableDebt` was unchanged by `pauseWithdraw`.
- **`test_H01_partialPauseWithdraw_pendingPhUSDViewUnderflows`** — auxiliary PoC for the phUSD-debt path: activates a non-zero phUSD APY via the two-step `setDesiredAPY(500)`, then shows that `pendingPhUSD(alice)` also reverts with arithmetic underflow after a partial pause-withdraw. Confirms both `phUSDDebt` and `stableDebt` are affected by the same invariant break.
- **`test_H01_control_fullPauseWithdraw_doesNotLockOut`** — control. A *full* `pauseWithdraw` does not brick `claim()` because `_claimRewards` short-circuits on `amount == 0`. This isolates the bug to the partial path and demonstrates it is a distinct invariant violation, not a restatement of the documented "rewards are forfeited on emergency exit" design.

Run with:

```
forge test --match-contract H01_PauseWithdrawDebtDesync_PoC -vv
```

## Recommended mitigation steps

Restore the debt invariant inside `pauseWithdraw` before mutating `user.amount`. The preferred fix is to pay (or accrue) outstanding rewards and reset the debt fields to the new principal:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    // 1. Bring the accumulators up to date.
    _updatePool();

    // 2. Settle the user's pending rewards against the *pre-withdrawal* amount.
    //    This preserves user value and clears the stale debt safely.
    _claimRewards(msg.sender, msg.sender);

    // 3. Mutate principal.
    user.amount -= amount;
    totalStaked -= amount;

    // 4. Recompute debt against the new principal so the invariant holds.
    user.phUSDDebt  = (user.amount * accPhUSDPerShare)  / PRECISION;
    user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);
    emit EmergencyWithdrawal(msg.sender, amount);
}
```

If the design intent is to strictly forbid reward payouts during an emergency exit, the minimum acceptable fix is to disallow partial pause-withdrawals and zero the debt fields together with `user.amount`:

```solidity
require(amount == user.amount, "pauseWithdraw must be full");
user.amount     = 0;
user.phUSDDebt  = 0;
user.stableDebt = 0;
totalStaked    -= amount;
```

Option (a) preserves user value and is consistent with how `stake` / `withdraw` / `claim` already handle the debt fields. Option (b) at minimum prevents the lockout but still forfeits accrued rewards. Either fix eliminates the underflow; the current behaviour — mutating `user.amount` while leaving `user.<x>Debt` stale — is unsafe under any code path that re-enters `_claimRewards` or reads the pending-view functions, and should not be retained.
