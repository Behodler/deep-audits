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
// M-02 PoC (ECON-002): emergencyWithdraw strands forfeited rewards
// as dead phUSD in the contract.
// ---------------------------------------------------------------------
//
// ROOT CAUSE
//   `emergencyWithdraw` (NFTStaker.sol L308-317) zeroes the caller's
//   stake and rewardDebt but does NOT rewind their share of
//   `accRewardPerShare`. That inflation was paid for earlier by
//   `_updatePool` (L219-234) which had already:
//     (a) debited `rewardBudget` by `elapsed * rewardRate`, and
//     (b) credited `accRewardPerShare += reward*1e18 / totalStaked`.
//   The exiting user's portion of that credit (their weight inside
//   `totalStaked` at the moment `_updatePool` ran) is therefore
//   orphaned after the exit: no remaining staker has a claim on it
//   (their rewardDebt was stamped at a lower `accRewardPerShare`, so
//   they only get credit for THEIR OWN share), yet the phUSD is still
//   in the contract balance — gone from `rewardBudget`, but
//   permanently un-payable.
//
// TRIGGER
//   `emergencyWithdraw` itself does NOT call `_updatePool`. For the
//   leak to materialise, `_updatePool` must have fired at least once
//   between the exiting user's last settlement and their emergency
//   call. In practice this happens on *any* other user's interaction
//   (stake / unstake / claim / pullAndRefresh), all of which go
//   through `_syncBudget -> _updatePool`. The scenario below uses
//   Bob's `claim()` to trigger the mid-window `_updatePool` while
//   Alice is still staked with a positive weight.
//
// SCENARIO
//   1. Alice stakes 10 units. Bob stakes 10 units. rewardRate > 0,
//      window active. accRewardPerShare = 0, rewardBudget = B.
//   2. 100 seconds pass. No state change yet (nothing accrued into
//      storage; `pendingReward` is a view projection only).
//   3. Bob calls `claim()`. `_syncBudget` -> `_updatePool` fires:
//      - reward  = 100 * rate  (assume exactly divisible)
//      - rewardBudget decreases by `reward`
//      - accRewardPerShare += reward * 1e18 / 20  (both staked)
//      Bob's share (10/20 = half) is paid to him. Alice's share
//      (10/20 = half) is now "parked" in accRewardPerShare, waiting
//      for her to collect via claim/unstake/stake.
//   4. Alice calls `emergencyWithdraw` WITHOUT calling claim first.
//      Her user.amount and user.rewardDebt are zeroed. Her principal
//      is returned. Her pending half-share of the 100s of emissions
//      is SILENTLY DELETED.
//   5. More time passes. All remaining stakers (just Bob) claim
//      everything they are ever owed, then unstake. Window expires.
//   6. Invariant check: rewardToken.balanceOf(staker) now contains
//      Alice's forfeited share as DEAD phUSD — larger than
//      rewardBudget + sum(pendingReward) + sum(in-flight accrual).
//      No function exists to recover it.
//
// ASSERTIONS
//   (a) After step 3, `rewardBudget` has decreased by `100 * rate`
//       and `accRewardPerShare > 0`.
//   (b) After step 4, the contract's phUSD balance is strictly
//       greater than `rewardBudget + totalDebt` by Alice's forfeited
//       half-share of the 100-second slice.
//   (c) After step 5 (everyone else drains to zero), the contract
//       still holds dead phUSD equal to Alice's forfeited share.
//   (d) No `pull()`, `topUp`, `setWindowDuration`, `claim`, `stake`,
//       or `unstake` call can recover those funds. The only path
//       would be an owner-rescue that doesn't exist.
// ---------------------------------------------------------------------

contract PoCM02_EmergencyWithdrawStrandsRewards is Test {
    NFTStaker internal staker;
    MockERC1155 internal nft;
    MockERC20 internal phUSD;
    MockBalancerPoolerMintDebtHook internal hook;

    address internal owner = address(0xD1);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant ID = 1;
    uint256 internal constant WINDOW = 540 days;
    // Rate chosen so that 100s * rate is a clean number and divides
    // evenly between two stakers (no floor-division dust obscuring
    // the real leak).
    uint256 internal constant RATE = 1e12; // wei/sec
    uint256 internal constant BUDGET = RATE * WINDOW;

    function setUp() public {
        nft = new MockERC1155();
        phUSD = new MockERC20("phUSD", "phUSD");
        staker = new NFTStaker(IERC1155(address(nft)), ID, IERC20(address(phUSD)), owner);

        hook = new MockBalancerPoolerMintDebtHook(phUSD, address(staker));
        vm.prank(owner);
        staker.setDispatcherHook(IBalancerPoolerMintDebtHook(address(hook)));

        // Fund alice and bob with NFTs + approvals.
        nft.mint(alice, ID, 1_000);
        nft.mint(bob, ID, 1_000);
        vm.prank(alice);
        nft.setApprovalForAll(address(staker), true);
        vm.prank(bob);
        nft.setApprovalForAll(address(staker), true);

        // Owner seeds the reward budget via topUp so rate = BUDGET/WINDOW = RATE.
        phUSD.mint(owner, BUDGET);
        vm.prank(owner);
        phUSD.approve(address(staker), BUDGET);
        vm.prank(owner);
        staker.topUp(BUDGET);

        assertEq(staker.rewardRate(), RATE, "rate setup");
        assertEq(staker.rewardBudget(), BUDGET, "budget setup");
    }

    function test_EmergencyWithdrawStrandsAccruedRewards() public {
        // ------------------------------------------------------------
        // Step 1: Alice and Bob stake equal amounts. No rewards
        //         accrued yet; accRewardPerShare == 0, rewardDebt == 0
        //         for both.
        // ------------------------------------------------------------
        vm.prank(alice);
        staker.stake(10);
        vm.prank(bob);
        staker.stake(10);

        assertEq(staker.totalStaked(), 20, "both staked");
        assertEq(staker.accRewardPerShare(), 0, "no accrual yet");

        uint256 budgetBefore = staker.rewardBudget();
        uint256 balanceBefore = phUSD.balanceOf(address(staker));
        uint256 aliceBalBefore = phUSD.balanceOf(alice);
        uint256 bobBalBefore = phUSD.balanceOf(bob);

        console.log("=== M-02 PoC: emergencyWithdraw strands rewards ===");
        console.log("");
        console.log("--- initial state after both stake ---");
        console.log("rewardBudget:                      ", budgetBefore);
        console.log("phUSD balance of contract:         ", balanceBefore);
        console.log("accRewardPerShare:                 ", staker.accRewardPerShare());

        // Sanity: conservation invariant holds pre-exploit:
        //   balance == rewardBudget + totalDebt (== 0 debt).
        assertEq(balanceBefore, budgetBefore, "pre: balance == budget, no debt");

        // ------------------------------------------------------------
        // Step 2: 100 seconds pass. No state change yet -- accrual is
        //         still only in the `pendingReward` view.
        // ------------------------------------------------------------
        uint256 elapsed = 100;
        vm.warp(block.timestamp + elapsed);

        uint256 alicePendingViewT1 = staker.pendingReward(alice);
        uint256 bobPendingViewT1 = staker.pendingReward(bob);

        // Each is owed half of `elapsed * RATE = 100e12`.
        assertEq(alicePendingViewT1, (elapsed * RATE) / 2, "alice view: half the slice");
        assertEq(bobPendingViewT1, (elapsed * RATE) / 2, "bob view: half the slice");

        console.log("");
        console.log("--- after 100s elapsed (pre-updatePool) ---");
        console.log("alice pendingReward (view):        ", alicePendingViewT1);
        console.log("bob   pendingReward (view):        ", bobPendingViewT1);

        // ------------------------------------------------------------
        // Step 3: Bob claims. `_updatePool` fires:
        //   - reward = 100 * RATE = 100e12
        //   - rewardBudget -= 100e12
        //   - accRewardPerShare += 100e12 * 1e18 / 20
        //   Bob is paid his half (50e12). Alice's half (50e12) sits
        //   "parked" inside accRewardPerShare, collectible only via a
        //   future claim/stake/unstake by Alice.
        // ------------------------------------------------------------
        vm.prank(bob);
        staker.claim();

        uint256 budgetAfterBobClaim = staker.rewardBudget();
        uint256 bobPaid = phUSD.balanceOf(bob) - bobBalBefore;
        uint256 contractBalAfterBobClaim = phUSD.balanceOf(address(staker));

        uint256 totalSliceAccrued = elapsed * RATE; // 100e12
        uint256 expectedBobPay = totalSliceAccrued / 2;

        // Budget dropped by the full 100-second slice.
        assertEq(budgetBefore - budgetAfterBobClaim, totalSliceAccrued, "budget debited by full slice");
        // Bob received exactly his half.
        assertEq(bobPaid, expectedBobPay, "bob got half the slice");
        assertGt(staker.accRewardPerShare(), 0, "acc per share now non-zero");

        // Alice's pending is still her half — baked into accRewardPerShare.
        uint256 alicePendingParked = staker.pendingReward(alice);
        assertEq(alicePendingParked, expectedBobPay, "alice's half is parked in accRewardPerShare");

        console.log("");
        console.log("--- after Bob claims (triggers _updatePool) ---");
        console.log("rewardBudget:                      ", budgetAfterBobClaim);
        console.log("bob was paid:                      ", bobPaid);
        console.log("alice pendingReward (parked):      ", alicePendingParked);
        console.log("contract phUSD balance:            ", contractBalAfterBobClaim);
        console.log("accRewardPerShare:                 ", staker.accRewardPerShare());

        // Invariant pre-exit: balance == rewardBudget + totalDebt.
        // totalDebt ~ alice's parked pending (bob just drained his).
        uint256 debtPreExit = staker.totalDebt();
        assertEq(
            contractBalAfterBobClaim,
            budgetAfterBobClaim + debtPreExit,
            "pre-exit: balance == budget + debt (invariant holds)"
        );
        assertEq(debtPreExit, alicePendingParked, "debt equals alice's parked pending");

        // ------------------------------------------------------------
        // Step 4: Alice calls emergencyWithdraw. `_updatePool` is
        //         deliberately NOT called. user.amount and
        //         user.rewardDebt are zeroed. Her 50e12 parked reward
        //         vanishes from `pendingReward(alice)` but is NOT
        //         rewound: neither rewardBudget is credited back nor
        //         is accRewardPerShare decremented.
        // ------------------------------------------------------------
        vm.prank(alice);
        staker.emergencyWithdraw();

        // Alice got zero phUSD (forfeiture is spec-blessed).
        assertEq(phUSD.balanceOf(alice), aliceBalBefore, "alice got 0 phUSD (spec-blessed forfeiture)");
        // Her tracked pending is zero (her weight is zero).
        assertEq(staker.pendingReward(alice), 0, "alice pending is 0 post-exit");

        // Budget is UNCHANGED — emergencyWithdraw skips _syncBudget.
        // That is the bug: the 50e12 that was debited from rewardBudget
        // to pay Alice's share was NEVER returned to rewardBudget.
        assertEq(staker.rewardBudget(), budgetAfterBobClaim, "budget NOT re-credited on exit");

        // totalStaked now only counts Bob.
        assertEq(staker.totalStaked(), 10, "only bob left");

        console.log("");
        console.log("--- after Alice emergencyWithdraw ---");
        console.log("alice phUSD received:              ", phUSD.balanceOf(alice) - aliceBalBefore);
        console.log("alice pending now:                 ", staker.pendingReward(alice));
        console.log("rewardBudget (unchanged):          ", staker.rewardBudget());
        console.log("contract phUSD balance:            ", phUSD.balanceOf(address(staker)));

        // ------------------------------------------------------------
        // Step 5: Let the schedule run out completely. Bob drains
        //         everything he will ever be owed. Then we measure
        //         the gap.
        //
        //         Key point: since Alice's exit, totalStaked = 10
        //         (Bob only). accRewardPerShare continues to advance
        //         under the full RATE / 10 per second. Bob therefore
        //         collects 100% of every remaining second. None of
        //         the 50e12 Alice forfeited is rebated to him.
        // ------------------------------------------------------------
        // Jump past windowEnd so the schedule depletes naturally.
        vm.warp(staker.windowEnd() + 1 days);

        vm.prank(bob);
        staker.claim();
        vm.prank(bob);
        staker.unstake(10);

        // At this point: no stakers, window expired, all legitimate
        // emissions paid out. The only thing left in the contract
        // should be zero — if the invariant held.
        uint256 finalBalance = phUSD.balanceOf(address(staker));
        uint256 finalBudget = staker.rewardBudget();

        console.log("");
        console.log("--- after schedule ends + Bob drains ---");
        console.log("rewardBudget:                      ", finalBudget);
        console.log("contract phUSD balance:            ", finalBalance);
        console.log("totalStaked:                       ", staker.totalStaked());
        console.log("alice forfeited (expected dead):   ", expectedBobPay);

        // ------------------------------------------------------------
        // INVARIANT BREAK: the contract still holds Alice's forfeited
        // 50e12 phUSD even though:
        //   (a) totalStaked == 0 (no one can claim any more),
        //   (b) windowEnd is in the past (no new emissions),
        //   (c) rewardBudget is effectively the rounding-dust tail.
        //
        // The gap `finalBalance - finalBudget` is strictly greater
        // than zero and equal (up to floor-div dust) to Alice's
        // forfeited half-share.
        // ------------------------------------------------------------
        assertEq(staker.totalStaked(), 0, "no stakers");
        assertGt(finalBalance, finalBudget, "BUG: balance > budget -> dead phUSD");

        uint256 strandedPhusd = finalBalance - finalBudget;
        // Within a few wei of the exact half-slice (floor-div dust from
        // accRewardPerShare rounding; the 50e12 number is exact because
        // RATE * 100 is evenly divisible by 20).
        assertApproxEqAbs(
            strandedPhusd,
            expectedBobPay,
            10,
            "stranded phUSD equals Alice's forfeited share (+/- dust)"
        );

        console.log("");
        console.log("--- stranded summary ---");
        console.log("dead phUSD in contract:            ", strandedPhusd);
        console.log("                                  (== alice's forfeited 50s slice)");

        // ------------------------------------------------------------
        // Step 6: prove that no call can recover the stranded phUSD.
        //         - Further claims revert (no stakers; totalStaked == 0
        //           means claim() can only set rewardDebt on a zero
        //           amount, no payout).
        //         - Owner topUp adds MORE phUSD but cannot withdraw.
        //         - setWindowDuration extends schedule but only over
        //           rewardBudget, which no longer contains the
        //           stranded portion.
        //         - There is no owner-rescue selector.
        // ------------------------------------------------------------
        // The stranded balance is not counted in rewardBudget, so an
        // owner topUp doesn't reclaim it -- it just piles more on top.
        uint256 balBeforeTopUp = phUSD.balanceOf(address(staker));
        phUSD.mint(owner, 1);
        vm.prank(owner);
        phUSD.approve(address(staker), 1);
        vm.prank(owner);
        staker.topUp(1);
        assertEq(
            phUSD.balanceOf(address(staker)),
            balBeforeTopUp + 1,
            "topUp adds to balance; stranded portion still there, still orphaned"
        );
        // rewardBudget went up by 1, not by the stranded amount -- the
        // stranding is invisible to the accounting.
        assertEq(staker.rewardBudget(), finalBudget + 1, "budget += topUp, not += strandedPhusd");

        // Contract balance minus rewardBudget is STILL the stranded
        // dust (topUp added 1 to both sides).
        uint256 stillStranded = phUSD.balanceOf(address(staker)) - staker.rewardBudget();
        assertEq(stillStranded, strandedPhusd, "stranded unchanged after topUp recovery attempt");

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("invariant broken:  balance == rewardBudget + totalDebt");
        console.log("gap (dead phUSD):  ", stillStranded);
        console.log("no recovery path exists (no owner rescue selector)");
    }
}
