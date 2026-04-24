// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTStaker} from "../src/NFTStaker.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBalancerPoolerMintDebtHook} from "yield-claim-nft/V2/interfaces/IBalancerPoolerMintDebtHook.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockBalancerPoolerMintDebtHook} from "./mocks/MockBalancerPoolerMintDebtHook.sol";

// ---------------------------------------------------------------------
// M-01 PoC (DEDUP-006): Budget stranded post-expiry when schedule
// expires with no dispatcher inflow.
// ---------------------------------------------------------------------
//
// ROOT CAUSE
//   `_syncBudget` (NFTStaker.sol L203-214) short-circuits on
//   `if (inflow == 0) return;` BEFORE reaching `_applyAsymmetricWindow`,
//   so the `scheduleExpired` reset branch (L191-195) never fires when
//   the dispatcher has nothing to hand over.
//
//   Once `block.timestamp >= windowEnd`, `_updatePool` clamps accrual to
//   `end = min(now, windowEnd)` (L225), so elapsed since `lastRewardTime`
//   becomes zero and NO new emissions accrue. Combined with
//   `currentRewardRate()` returning 0 post-expiry (L337), the leftover
//   `rewardBudget` is permanently non-emitting until an owner topUp.
//
// SCENARIO (matches attack_path in M-01.json)
//   1. Owner seeds the schedule: budget = 540d * rate.
//   2. Honest staker stakes some units.
//   3. Shortly before windowEnd, all stakers unstake. During the
//      zero-stake tail, `_updatePool` skips accrual (totalStaked == 0)
//      and just bumps `lastRewardTime`; rewardBudget is preserved
//      (correct -- no stakers means no emissions owed).
//   4. Block time advances past windowEnd. Dispatcher has nothing to
//      pull (steady-state mint debt == 0).
//   5. A new staker stakes. `_syncBudget` -> `_updatePool` (elapsed
//      clipped to 0 because end = windowEnd <= lastRewardTime) ->
//      `pull()` returns zero phUSD -> early return. The
//      `_applyAsymmetricWindow` reset branch is NEVER entered.
//   6. rewardBudget stays non-zero, windowEnd stays in the past,
//      currentRewardRate() returns 0, and any subsequent stake /
//      unstake / claim calls produce ZERO emissions.
//   7. The only on-chain recovery is an owner `topUp` with real phUSD.
//      Until then, the funds are stranded.
//
// ASSERTIONS
//   (a) rewardBudget > 0 after schedule expiry.
//   (b) windowEnd < block.timestamp (schedule has expired).
//   (c) currentRewardRate() == 0 (emissions clamped).
//   (d) Calling stake / unstake / claim does NOT reset the window and
//       does NOT make the stranded budget emit -- newStaker accrues 0.
//   (e) rewardBudget after many interactions is unchanged (still stranded).
//   (f) Sanity: an owner `topUp(1)` DOES recover the schedule, proving
//       only the privileged path can unstrand the funds.
// ---------------------------------------------------------------------

contract PoCM01_BudgetStrandedTest is Test {
    NFTStaker internal staker;
    MockERC1155 internal nft;
    MockERC20 internal phUSD;
    MockBalancerPoolerMintDebtHook internal hook;

    address internal owner = address(0xD1);
    address internal honestStaker = address(0xA11CE);
    address internal newStaker = address(0xB0B);

    uint256 internal constant ID = 1;

    // Size the schedule so rate = 1e12 wei/sec (tidy, avoids rounding noise)
    // with a 540-day window.
    uint256 internal constant WINDOW = 540 days;
    uint256 internal constant RATE = 1e12; // wei/sec
    uint256 internal constant TOPUP_AMOUNT = RATE * WINDOW;

    function setUp() public {
        nft = new MockERC1155();
        phUSD = new MockERC20("phUSD", "phUSD");
        staker = new NFTStaker(IERC1155(address(nft)), ID, IERC20(address(phUSD)), owner);
        hook = new MockBalancerPoolerMintDebtHook(phUSD, address(staker));
        vm.prank(owner);
        staker.setDispatcherHook(IBalancerPoolerMintDebtHook(address(hook)));

        // Fund stakers and approvals.
        nft.mint(honestStaker, ID, 1_000);
        nft.mint(newStaker, ID, 1_000);
        vm.prank(honestStaker);
        nft.setApprovalForAll(address(staker), true);
        vm.prank(newStaker);
        nft.setApprovalForAll(address(staker), true);

        // Owner funds the schedule via topUp.
        phUSD.mint(owner, TOPUP_AMOUNT * 10);
        vm.prank(owner);
        phUSD.approve(address(staker), type(uint256).max);
    }

    function test_BudgetStrandedAfterWindowExpires() public {
        // ------------------------------------------------------------
        // Step 1: owner topUp seeds the schedule.
        // ------------------------------------------------------------
        vm.prank(owner);
        staker.topUp(TOPUP_AMOUNT);

        uint256 seededBudget = staker.rewardBudget();
        uint256 seededRate = staker.rewardRate();
        uint256 seededEnd = staker.windowEnd();
        assertEq(seededBudget, TOPUP_AMOUNT, "budget seeded");
        assertEq(seededRate, RATE, "rate = budget / window");
        assertEq(seededEnd, block.timestamp + WINDOW, "windowEnd = now + W");

        console.log("=== M-01 PoC: Budget stranded post-expiry ===");
        console.log("seeded budget (wei):     ", seededBudget);
        console.log("seeded rate  (wei/s):    ", seededRate);
        console.log("seeded windowEnd:        ", seededEnd);

        // ------------------------------------------------------------
        // Step 2: honest staker stakes, accrues most of the window,
        //         then unstakes shortly before windowEnd. The 1-day
        //         tail is the source of the stranded budget.
        // ------------------------------------------------------------
        vm.prank(honestStaker);
        staker.stake(1_000);

        // Warp to windowEnd - 1 day.
        uint256 tailSeconds = 1 days;
        vm.warp(seededEnd - tailSeconds);

        vm.prank(honestStaker);
        staker.unstake(1_000); // claims accrued rewards along the way

        // At this point, rewardBudget should be roughly RATE * tailSeconds
        // (the 1-day slice never paid out because nobody was staked).
        uint256 budgetAfterUnstake = staker.rewardBudget();
        uint256 expectedLeftover = RATE * tailSeconds;

        console.log("--- after honest unstake near window tail ---");
        console.log("rewardBudget (leftover): ", budgetAfterUnstake);
        console.log("expected ~= RATE*tail:   ", expectedLeftover);

        // Leftover should be within a few wei of expected (floor div dust).
        assertApproxEqAbs(
            budgetAfterUnstake, expectedLeftover, RATE, "leftover budget approximately RATE * tail"
        );
        assertGt(budgetAfterUnstake, 0, "leftover budget is non-zero");

        // Dispatcher has no mint debt during the tail -- steady state.
        assertEq(hook.pendingMint(), 0, "dispatcher has no mint debt (steady state)");
        assertEq(hook.mintDebt(), 0, "mintDebt() confirms zero inflow available");

        // ------------------------------------------------------------
        // Step 3: warp past windowEnd. Schedule expires with leftover
        //         budget still sitting in the contract.
        // ------------------------------------------------------------
        vm.warp(seededEnd + 7 days); // well past expiry

        assertLt(staker.windowEnd(), block.timestamp, "windowEnd is in the past");
        assertEq(staker.currentRewardRate(), 0, "currentRewardRate clamps to 0 post-expiry");
        assertGt(staker.rewardBudget(), 0, "rewardBudget is still non-zero (stranded)");

        // ------------------------------------------------------------
        // Step 4: a new staker arrives. stake() triggers `_syncBudget`.
        //   * `_updatePool`: end = min(now, windowEnd) = windowEnd;
        //     elapsed = windowEnd - lastRewardTime = 0 (lastRewardTime
        //     was bumped to at least windowEnd-tail during step 2).
        //     Even if elapsed were positive, totalStaked==0 short-circuits.
        //   * `pull()`: dispatcher has 0 mint debt -> inflow == 0.
        //   * Early return on `if (inflow == 0) return;` -- the
        //     `_applyAsymmetricWindow(0)` reset path is NEVER reached.
        //
        // => The schedule stays expired, rewardBudget stays stranded.
        // ------------------------------------------------------------
        uint256 budgetBeforeNewStake = staker.rewardBudget();
        uint256 windowEndBeforeNewStake = staker.windowEnd();

        vm.prank(newStaker);
        staker.stake(1_000);

        uint256 budgetAfterNewStake = staker.rewardBudget();
        uint256 windowEndAfterNewStake = staker.windowEnd();

        console.log("--- after new staker stakes post-expiry ---");
        console.log("budget before new stake: ", budgetBeforeNewStake);
        console.log("budget after  new stake: ", budgetAfterNewStake);
        console.log("windowEnd before:        ", windowEndBeforeNewStake);
        console.log("windowEnd after:         ", windowEndAfterNewStake);
        console.log("block.timestamp:         ", block.timestamp);
        console.log("currentRewardRate():     ", staker.currentRewardRate());

        // The bug: schedule did NOT restart. windowEnd unchanged, budget
        // unchanged, rate clamp still returns 0.
        assertEq(
            windowEndAfterNewStake,
            windowEndBeforeNewStake,
            "BUG: windowEnd was not reset on stake despite expired schedule + non-zero budget"
        );
        assertLt(windowEndAfterNewStake, block.timestamp, "BUG: windowEnd still in the past");
        assertEq(
            budgetAfterNewStake,
            budgetBeforeNewStake,
            "BUG: rewardBudget unchanged -- no emissions resumed"
        );
        assertGt(budgetAfterNewStake, 0, "BUG: rewardBudget is still stranded (> 0)");
        assertEq(staker.currentRewardRate(), 0, "BUG: emissions are zero despite non-zero budget");

        // ------------------------------------------------------------
        // Step 5: time passes, many interactions happen -- the new
        //         staker gets NOTHING because emissions are frozen.
        // ------------------------------------------------------------
        vm.warp(block.timestamp + 30 days);

        // Pending reward view should return 0 despite 30 days elapsed.
        assertEq(staker.pendingReward(newStaker), 0, "BUG: no pending reward accrues post-expiry");

        // Exercise all user-path _syncBudget entry points; none can unstrand.
        vm.prank(newStaker);
        staker.claim();
        vm.prank(newStaker);
        staker.claim();

        // Owner-path pullAndRefresh also fails to reset (pull() gives 0 -> same early return).
        vm.prank(owner);
        staker.pullAndRefresh();

        // State after many interactions: still stranded.
        assertGt(staker.rewardBudget(), 0, "BUG: budget still stranded after many interactions");
        assertLt(staker.windowEnd(), block.timestamp, "BUG: windowEnd STILL in the past");
        assertEq(staker.currentRewardRate(), 0, "BUG: rate STILL zero");
        assertEq(
            phUSD.balanceOf(newStaker), 0, "BUG: new staker received zero phUSD despite 30 days of staking"
        );

        uint256 strandedAmount = staker.rewardBudget();
        console.log("--- stranded budget summary ---");
        console.log("stranded wei:            ", strandedAmount);
        console.log("stranded / RATE (sec):   ", strandedAmount / RATE);

        // ------------------------------------------------------------
        // Step 6: sanity -- prove that ONLY a privileged owner topUp
        //         can unstrand the funds. This is the recovery path
        //         documented in the finding ("Only an owner topUp
        //         (amount > 0, real tokens moved in) can reset the
        //         schedule.").
        // ------------------------------------------------------------
        vm.prank(owner);
        staker.topUp(1);

        assertGt(staker.windowEnd(), block.timestamp, "topUp(1) DID reset the schedule (recovery path)");
        assertGt(staker.currentRewardRate(), 0, "emissions resumed after privileged topUp");

        console.log("--- after owner topUp(1) recovery ---");
        console.log("windowEnd:               ", staker.windowEnd());
        console.log("rewardRate:              ", staker.rewardRate());
        console.log("");
        console.log("=== VULNERABILITY CONFIRMED: budget stranded until owner topUp ===");
    }
}
