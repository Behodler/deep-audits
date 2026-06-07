<!--
ID: pe4m2
C4 Submission Metadata
Title: [L-06] Partial pauseWithdraw leaves reward debt anchored to the pre-withdraw stake, bricking claim/withdraw/stake for the account
Severity: Low
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L245-L261
PoC File: test/poc-2004-M-02-pausewithdraw-stale-debt-brick.t.sol
Ledger Mapping: M-01 (still-open carryover)
-->

> **Reclassified Medium→Low (phlimbo-ea-04, severity-auditor, user-approved). Detailed report retained; bundled in qa-report.md.**

## Finding description and impact

### Summary

`pauseWithdraw` is the only balance-mutating path in `PhlimboEA` that decrements `user.amount` and `totalStaked` **without** calling `_updatePool()` and **without** rebasing the user's reward debt (`phUSDDebt` / `stableDebt`). After a *partial* `pauseWithdraw`, the user's reward debt still encodes the larger pre-withdraw stake. On the next normal interaction the MasterChef-style accounting in `_claimRewards` computes `user.amount * accPerShare / PRECISION - debt`, where the minuend is now sized to the smaller post-withdraw stake while `debt` is still sized to the old, larger stake. The subtraction underflows, triggering a checked-arithmetic `Panic(0x11)` revert (Solidity 0.8.19) and bricking `claim()`, `withdraw()`, and `stake()` for that account, as well as the `pendingPhUSD` / `pendingStable` views.

### Root cause

`pauseWithdraw` ([Phlimbo.sol#L245-L261](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L245-L261)) mutates principal but never touches the reward-debt fields:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    // Update user balance
    user.amount -= amount;        // L251  principal shrinks...

    // Update total staked
    totalStaked -= amount;        // L254  ...but phUSDDebt / stableDebt are NOT rebased

    // Transfer phUSD to user
    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);

    emit EmergencyWithdrawal(msg.sender, amount);
}
```

Contrast this with every other principal-moving path (`stake` / `withdraw` / `claim`), which routes through `_claimRewards` and then re-anchors debt to the new `user.amount` (e.g. `user.stableDebt = (user.amount * accStablePerShare) / PRECISION` at [Phlimbo.sol#L380](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L380)). `pauseWithdraw` skips both steps.

### Vulnerability details

Once a partial `pauseWithdraw` has run, the next call into `_claimRewards` ([Phlimbo.sol#L432-L455](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L432-L455)) underflows:

```solidity
// L440 - phUSD: smaller amount, stale (larger) debt -> underflow
uint256 pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;
...
// L446 - stable: same pattern -> underflow
uint256 pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;
```

Because `userDetails.amount` was reduced while `phUSDDebt` / `stableDebt` were not, the term `(amount * accPerShare)/PRECISION` is strictly less than the recorded `debt`, so both subtractions revert with `Panic(0x11)`. The `amount == 0` early-return guard at [L435](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L435) only protects a *full* exit (amount drained to zero); a *partial* `pauseWithdraw` leaves a non-zero residual amount and walks straight into the underflow. The `_updatePool` early-return at [L390](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L390) does not help either — the accumulators have already advanced from prior reward accrual.

Attack/trigger path (self-inflicted, no external actor):

1. Contract is paused (a documented, expected operation). The user calls `pauseWithdraw(partial)`; `user.amount` and `totalStaked` decrease but `phUSDDebt` / `stableDebt` are left anchored to the pre-withdraw amount.
2. The debt now exceeds what the reduced stake can ever justify against the current accumulators.
3. After unpause, any `claim()`, `withdraw()`, or `stake()` calls `_claimRewards`, which computes `(smaller amount * accPerShare)/PRECISION - (larger debt)` and reverts with `Panic(0x11)` at L440/L446.
4. All normal exit paths revert. The pending-reward views also revert, so off-chain integrators and front-ends that read `pendingPhUSD` / `pendingStable` for that account break as well.

### Impact

Account-level availability / function impact:

- The account's accrued phUSD + stable rewards become **permanently unclaimable** through the normal interface.
- The account's **remaining staked principal is locked** against every normal exit path (`withdraw`, and even the re-stake path, all revert).
- The only recovery is to **re-pause the contract and call `pauseWithdraw` again** (which skips `_claimRewards` entirely and therefore does not underflow), draining the residual principal out the emergency path. This requires a live, valid pauser to re-pause; if no re-pause ever occurs, the principal is **stranded indefinitely**.

### Severity

There is no theft and no attacker profit. The trigger is `msg.sender`-only (`pauseWithdraw` acts on the caller's own `UserInfo`), so this is a self-inflicted denial of service of one's *own* account — an attacker cannot force it on a third party. **Final classification: Low** (downgraded from Medium per the severity-auditor, phlimbo-ea-04, user-approved). The downgrade rationale: the trigger is self-inflicted and multi-gated (requires a pause plus a *partial* `pauseWithdraw`), and the residual principal is recoverable via a further re-pause + `pauseWithdraw`; the permanent-strand corner (no re-pause ever occurs) is captured by C-01. The original Medium reasoning is retained below for completeness: a non-obvious defect on a documented operational path (partial emergency exit during a pause) locks the account's residual principal behind the emergency path and renders rewards permanently unclaimable, with recovery contingent on a privileged re-pause.

### Relationship to the documented known issue

The project's known issues state: *"pauseWithdraw does NOT claim rewards or update pool (emergency exit mechanism by design)."* That documented behavior covers reward **forfeiture** only — the deliberate decision not to pay out pending rewards during an emergency exit. It does **not** cover, and a competent non-malicious operator would not anticipate, this downstream **stale-debt brick**: that performing a *partial* emergency withdrawal silently corrupts the account's reward-debt accounting and locks the *remaining principal* behind the same emergency path. Forfeiting rewards on exit is intended; bricking the account's normal exit for the un-withdrawn balance is not. This is therefore in scope as a non-obvious operational hazard / availability bug, distinct from the documented forfeiture note.

This finding maps to ledger entry **M-01** (still-open carryover); this run supplies the verified PoC the prior ledger entry was missing. It was independently corroborated by the forge invariant suite (INV-01 violated, 5-step shrunk counterexample) and symbolic analysis (SYMBOLIC-001/002 FAIL, 100e18 canonical witness), and confirmed by the runnable PoC below.

## Proof of Concept

The PoC stakes 100e18, accrues both reward accumulators, claims once (which anchors the user's debt to the full 100e18 stake — the booby-trap), then does a partial `pauseWithdraw(60e18)` while paused. It asserts the reward debt is left stale, then proves that after unpause `claim()`, `withdraw()`, `stake()`, `pendingPhUSD()` and `pendingStable()` all revert with the exact `Panic(0x11)` (arithmetic underflow) selector, and finally that the residual 40e18 is recoverable only by re-pausing and calling `pauseWithdraw` again.

Test file: `test/poc-2004-M-02-pausewithdraw-stale-debt-brick.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Phlimbo.sol";
import "./Mocks.sol";

contract PoC2004_M02 is Test {
    PhlimboEA public phlimbo;
    MockFlax public phUSD;
    MockStable public rewardToken;

    address public alice  = address(0xA11CE);
    address public funder = address(0xF00D);
    address public pauser = address(0xBEEF);

    uint256 constant DEPLETION_DURATION = 7 days;
    uint256 constant STAKE_AMOUNT       = 100 ether; // canonical 100e18 witness
    uint256 constant REWARD_AMOUNT      = 1_000 ether;
    uint256 constant APY_BPS            = 500;       // 5% -> phUSDPerSecond > 0

    // Panic(uint256) selector with code 0x11 = arithmetic over/underflow.
    bytes internal PANIC_UNDERFLOW = abi.encodeWithSignature("Panic(uint256)", 0x11);

    function setUp() public {
        phUSD = new MockFlax();
        rewardToken = new MockStable();
        phlimbo = new PhlimboEA(address(phUSD), address(rewardToken), DEPLETION_DURATION);
        phUSD.setMinter(address(phlimbo), true);

        phUSD.mint(alice, STAKE_AMOUNT);
        rewardToken.mint(funder, REWARD_AMOUNT);

        vm.prank(alice);
        phUSD.approve(address(phlimbo), type(uint256).max);
        vm.prank(funder);
        rewardToken.approve(address(phlimbo), type(uint256).max);

        phlimbo.setPauser(pauser);

        // Two-step APY commit so phUSDPerSecond becomes > 0 once anyone stakes.
        phlimbo.setDesiredAPY(APY_BPS);
        vm.roll(block.number + 1);
        phlimbo.setDesiredAPY(APY_BPS);
    }

    function test_M02_pauseWithdrawStaleDebtBricksAccount() public {
        // 1. Alice stakes 100e18.
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, address(0));

        // 2. Funder supplies stable; warp so both accumulators grow.
        vm.prank(funder);
        phlimbo.collectReward(REWARD_AMOUNT);
        vm.warp(block.timestamp + 30 days);

        // 3. Alice claims: rebases her debt to the FULL 100e18 amount (the booby-trap).
        vm.prank(alice);
        phlimbo.claim();

        (uint256 amt1, uint256 phUSDDebt1, uint256 stableDebt1) = phlimbo.userInfo(alice);
        assertEq(amt1, STAKE_AMOUNT, "amount unchanged by claim");
        assertGt(phUSDDebt1, 0, "phUSDDebt rebased > 0");
        assertGt(stableDebt1, 0, "stableDebt rebased > 0");

        // 4. Pauser pauses (documented operation).
        vm.prank(pauser);
        phlimbo.pause();

        // 5. Alice partial pauseWithdraw 60e18 (40e18 remains). Debts NOT rebased -> stale.
        uint256 partialOut = 60 ether;
        vm.prank(alice);
        phlimbo.pauseWithdraw(partialOut);

        (uint256 amt2, uint256 phUSDDebt2, uint256 stableDebt2) = phlimbo.userInfo(alice);
        assertEq(amt2, STAKE_AMOUNT - partialOut, "amount dropped to 40e18");
        assertEq(phUSDDebt2, phUSDDebt1, "phUSDDebt is STALE (anchored to 100e18)");
        assertEq(stableDebt2, stableDebt1, "stableDebt is STALE (anchored to 100e18)");

        // Sanity: underflow precondition holds (minuend < stale debt).
        (, uint256 accPhUSD, uint256 accStable, , ) = phlimbo.getPoolInfo();
        assertLt((amt2 * accPhUSD) / 1e18,  phUSDDebt2,  "phUSD minuend < stale debt -> underflow guaranteed");
        assertLt((amt2 * accStable) / 1e18, stableDebt2, "stable minuend < stale debt -> underflow guaranteed");

        // 6. Unpause so normal paths are reachable again.
        vm.prank(pauser);
        phlimbo.unpause();

        // 7. Every normal exit path reverts with the EXACT underflow panic.
        vm.expectRevert(PANIC_UNDERFLOW);
        vm.prank(alice);
        phlimbo.claim();

        vm.expectRevert(PANIC_UNDERFLOW);
        vm.prank(alice);
        phlimbo.withdraw(1 ether);

        vm.expectRevert(PANIC_UNDERFLOW);
        vm.prank(alice);
        phlimbo.stake(1 ether, alice);

        // Off-chain pending views underflow too (breaks integrators).
        vm.expectRevert(PANIC_UNDERFLOW);
        phlimbo.pendingPhUSD(alice);
        vm.expectRevert(PANIC_UNDERFLOW);
        phlimbo.pendingStable(alice);

        // 8. Principal is recoverable ONLY by re-pausing and doing pauseWithdraw
        //    (which skips _claimRewards entirely).
        uint256 phUSDBefore = phUSD.balanceOf(alice);
        vm.prank(pauser);
        phlimbo.pause();
        vm.prank(alice);
        phlimbo.pauseWithdraw(amt2); // recover remaining 40e18

        uint256 recovered = phUSD.balanceOf(alice) - phUSDBefore;
        assertEq(recovered, amt2, "remaining principal recovered only via re-pause + pauseWithdraw");

        (uint256 amt3, , ) = phlimbo.userInfo(alice);
        assertEq(amt3, 0, "stake fully drained via the emergency path");
    }
}
```

Run command:

```bash
forge test --match-path test/poc-2004-M-02-pausewithdraw-stale-debt-brick.t.sol -vv
```

Result (all assertions pass; the test confirms `claim`, `withdraw`, `stake`, `pendingPhUSD`, and `pendingStable` each revert with the exact `Panic(0x11)` selector after a partial `pauseWithdraw`):

```
Ran 1 test for test/poc-2004-M-02-pausewithdraw-stale-debt-brick.t.sol:PoC2004_M02
[PASS] test_M02_pauseWithdrawStaleDebtBricksAccount() (gas: 356701)
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

## Recommended mitigation steps

Make `pauseWithdraw` keep the reward-debt accounting consistent with the new principal, exactly as the normal paths do. Two acceptable options:

**Option A (preferred) — settle and rebase inside `pauseWithdraw`.** Call `_updatePool()` and re-anchor the debt to the post-decrement `user.amount` before transferring out, so a later `_claimRewards` can never underflow. If the emergency-exit forfeiture behavior must be preserved, skip the payout but still rebase the debt to the reduced amount:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    _updatePool(); // accrue accumulators to `now`

    user.amount -= amount;
    totalStaked -= amount;

    // Re-anchor debt to the new (smaller) principal so post-unpause
    // _claimRewards cannot underflow. (Rewards are still forfeited:
    // we deliberately do not pay out here, matching the documented design.)
    user.phUSDDebt  = (user.amount * accPhUSDPerShare)  / PRECISION;
    user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);
    emit EmergencyWithdrawal(msg.sender, amount);
}
```

**Option B — forbid partial emergency exits.** Require `pauseWithdraw` to fully drain the account (`amount == user.amount`, or always withdraw `user.amount`). A full exit sets `user.amount = 0`, so the `amount == 0` early-return in `_claimRewards` ([L435](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L435)) is reached on any subsequent interaction and the underflow can never occur. This is simpler but removes the ability to partially exit during a pause.

Option A is recommended because it preserves partial emergency exits while eliminating the stale-debt corruption at its root.
