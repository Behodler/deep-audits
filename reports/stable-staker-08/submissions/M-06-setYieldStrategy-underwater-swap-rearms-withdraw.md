<!--
ID: ss8m6
C4 Submission Metadata
Title: [M-06] setYieldStrategy underwater-swap silently lifts the underwater-withdraw block and FCFS-concentrates the realized loss on the last withdrawer
Severity: Medium (plausible) — Law-3 non-obvious owner footgun (operational hazard, in scope)
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L202-L238
PoC File: PoC_B_SetStrategyUnderwaterSwapFootgun.t.sol
Audited Commit: f85450b6d73a728f530a97854ecc882151695cd8
Fingerprint: dbdc3ac9b93afce47d5a3f7eb63c816ebf382402e564c24a012faff3b9999c28
-->

## Finding description and impact

### Summary

`setYieldStrategy` ([`StableStaker.sol#L202-L238`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L202-L238)) lets the owner swap a token's yield strategy. When the swap is performed while the **old** strategy is underwater (`totalBalanceOf < principalOf`), the function drains only the recoverable principal `R_old < totalStaked`, redeposits `R_old` into the new strategy, and **never rewrites `pool.totalStaked`**. The new strategy then reads at par, `_isUnderwater` returns `false`, and `withdrawDisabled(token)` silently flips **TRUE → FALSE**.

This erases the protective underwater-withdraw block — a documented design invariant (item #6 in `CLAUDE.md`, "Underwater withdraw block") whose stated purpose is that *a non-migrating user cannot be forced to realise a loss* — while a real `totalStaked − R_old` shortfall still exists. Withdrawals then proceed at par on a first-come-first-served basis: early exiters are paid in full, and the last withdrawer absorbs the entire shortfall.

### Vulnerability details

The swap logic at [`StableStaker.sol#L214-L217`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L214-L217) drains the old strategy with the underwater guard **OFF**:

```solidity
uint256 staked = poolInfo[token].totalStaked;
if (staked > 0) {
    _routeExit(token, staked, false); // guardUnderwater = false
}
```

With the guard off, `_routeExit` ([L691-L711](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L691-L711)) over-redeems an underwater strategy and recovers only `R_old = totalStaked × factor < totalStaked`. The recovered idle balance is then swept into the new strategy at [L231-L233](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L231-L233), and the `strategy.deposit(...)` return value is discarded:

```solidity
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    strategy.deposit(token, idleBalance, address(this)); // return discarded
}
```

Critically, `pool.totalStaked` is never rewritten anywhere in `setYieldStrategy`. After the swap:

- the new strategy custodies only `R_old` (it reads `principalOf == totalBalanceOf == R_old`, i.e. **at par**), but
- `pool.totalStaked` still claims the full pre-swap amount.

Because the new strategy is at par, `_isUnderwater` ([L666-L668](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L666-L668)) returns `false`, so `withdrawDisabled` ([L612-L617](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L612-L617)) returns `false`. The underwater block that had been protecting non-migrating stakers is lifted, and `withdraw` (guard ON via `_routeExit`) now passes at par against an under-funded pool.

The realized loss is then concentrated on the last withdrawer, not socialized:

1. Owner sets strategy YS1; Alice stakes 50e6, Bob stakes 50e6. `pool.totalStaked = 100e6`, `YS1.principalOf = 100e6`.
2. YS1 goes underwater (−10%): `YS1.totalBalanceOf = 90e6 < principalOf = 100e6`. `withdrawDisabled(token) == true`; a normal `withdraw` reverts `StableStaker: strategy underwater` — stakers are protected from realizing the loss.
3. Owner performs a routine swap to a healthy YS2. The drain recovers only `R_old = 90e6`, redeposits 90e6 into YS2, and leaves `pool.totalStaked` at `100e6`.
4. **Desync:** `YS2.principalOf == 90e6` (10e6 shortfall not migrated), `pool.totalStaked == 100e6` (10e6 phantom backing). YS2 is at par, so `_isUnderwater` is `false` and `withdrawDisabled` flips **TRUE → FALSE**.
5. **FCFS realization:** Alice (first out) withdraws 50e6 and is paid in full at par; `YS2.principalOf` drops to 40e6, `totalStaked` to 50e6 — still at par, still not blocked.
6. Bob (last out) requests his full 50e6 but YS2 only has 40e6 of principal left. The strategy caps the redeem to 40e6 while StableStaker still zeroes Bob's full 50e6 recorded position. Bob alone absorbs the entire 10e6 (20%) shortfall.

The project's own integration test already asserts the underlying desynced state. `test_setYieldStrategy_swap_fromUnderwaterVault_recoversWhatItCan_noRevert` (`test/YieldStrategyIntegration.t.sol:622-639`) asserts `strategy2.principalOf == 90e6` while `totalStaked == 100e6` after an underwater swap. This finding establishes that this state lifts the withdraw block and produces a concentrated, realized user loss.

### Impact

A routine owner strategy swap, performed while the old strategy is underwater, converts a **blocked, deferred, potentially-recoverable** underwater haircut (which would vanish entirely if the strategy healed back to par) into a **realized, FCFS-concentrated** principal loss borne by whoever exits last.

The harmed staker did not opt into a haircut: unlike `emergencyWithdraw` and `initiateMigration` (the documented escape hatches that intentionally accept the underwater haircut), an ordinary `withdraw` is supposed to be blocked while underwater precisely so the user is not forced to realize a loss. After the swap, that user can withdraw and unknowingly leave the shortfall to the next person; the last withdrawer is left short by `totalStaked − R_old` of recorded principal that the underwater guard had been protecting.

Total payout never exceeds realizable value, so there is no protocol theft and no value created from nothing — this is an inter-user loss redistribution, which places it at Medium rather than High. But it is a concrete, locked-in principal loss to a specific late-withdrawing staker that arises from a single, plausible, non-malicious owner action.

This is a **Law-3 non-obvious owner footgun**, in scope as an operational hazard. A competent, non-malicious owner swapping to a healthy strategy *in order to fix* an underwater position would be genuinely surprised that the swap itself unblocks par withdrawals against the still-existing shortfall and concentrates the loss on the slowest staker. It is not a malicious-owner vector, and it is not the documented operational requirement ("drain it first or replace only while `totalStaked == 0`") that warns about leaving funds in the old strategy — here the funds *are* drained, yet the accounting desync and the silent lifting of the withdraw block are not signposted anywhere.

### Severity justification

This maps to C4 Medium: it leaks value with stated assumptions and an external requirement (the strategy must be underwater **and** the owner must swap while it is underwater). There is no attacker and no theft, so it is not High; it produces a real, concrete user loss from a plausible, non-obvious owner action, so it is above Low/QA. It is structurally parallel to the project's own acknowledged Medium `0dca43f3` (`emergencyWithdraw` FCFS-at-par loss). Confirmed Medium by both the severity-classifier and the severity-auditor (high confidence).

## Recommended mitigation steps

### Code fix (preferred)

After an underwater drain in `setYieldStrategy`, reconcile `pool.totalStaked` with the amount actually recovered so the new strategy correctly reads underwater and the withdraw block stays armed until the position genuinely heals. Crediting the real `strategy.deposit` return value into `totalStaked` accomplishes the same source-of-truth reconciliation (`principalOf == totalStaked` at the source):

```solidity
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    uint256 credited = strategy.deposit(token, idleBalance, address(this));
    // Reconcile bookkeeping: if the drain under-recovered (old strategy was
    // underwater), the new strategy must read underwater too, not at par.
    if (credited < poolInfo[token].totalStaked) {
        poolInfo[token].totalStaked = credited;
    }
}
```

Equivalently, decrement `pool.totalStaked` by `totalStaked − R_old` immediately after the drain. Either way, `_isUnderwater` will continue to return `true` and `withdrawDisabled(token)` will stay `true` until the position genuinely heals, preserving the deferred-loss protection for non-migrating stakers.

Note that adjusting `totalStaked` also affects the MasterChef reward-accounting share base. The reconciliation should settle the pool (`_updatePool`) before mutating `totalStaked`, consistent with how `phUSDPerDay` already settles at the old rate before changing it, so emission accounting is not retroactively disturbed.

### Alternative code fix

Block the swap while the current strategy is underwater:

```solidity
require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");
```

This is simpler but more restrictive: it forces the owner to heal or fully drain the old strategy through another path before swapping, which may be undesirable as an operational escape hatch. The reconciliation fix above is preferred because it preserves the swap's best-effort drain semantics while keeping the protective block armed.

### Operational guidance (until fixed)

Never call `setYieldStrategy` while `withdrawDisabled(token) == true` (the current strategy is underwater). Drain and heal the old strategy first, or perform the swap only at par or while `totalStaked == 0`.
