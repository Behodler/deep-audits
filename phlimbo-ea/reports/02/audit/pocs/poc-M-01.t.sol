// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PhlimboV2.sol";
import "./Mocks.sol";

/**
 * @title M-01 PoC: pauseWithdraw decreases totalStaked without _updatePool
 * @notice Demonstrates that pauseWithdraw causes a cross-staker reward windfall
 *         for remaining stakers because lastRewardTime is pinned to the
 *         pre-pauseWithdraw value while totalStaked is reduced. The next
 *         _updatePool() advances the accumulator over the FULL elapsed
 *         window against the REDUCED share base, inflating per-share emissions.
 *
 * @dev Vulnerability Location: src/PhlimboV2.sol#L280-L291 (pauseWithdraw)
 *
 * VULNERABILITY SUMMARY:
 * pauseWithdraw mutates totalStaked (decrement) WITHOUT calling _updatePool()
 * first. Since lastRewardTime is not advanced and accStablePerShare is not
 * updated, the rewards accumulated from `lastRewardTime` up to `block.timestamp`
 * (the pre-pauseWithdraw window during which the exiting user was contributing
 * share weight) are later distributed across the post-decrement totalStaked.
 *
 * ATTACK PATH / SCENARIO:
 *  1. Two stakers (Alice, Bob) deposit equal amounts at T0. totalStaked = 2S.
 *  2. collectReward at T0 establishes rewardPerSecond.
 *  3. Time advances to T1. The fair pro-rata allocation for [T0, T1] is 50/50.
 *  4. Owner pauses; Alice calls pauseWithdraw(S). totalStaked drops to S, but
 *     lastRewardTime is still T0 and accStablePerShare is still 0.
 *  5. Owner unpauses; time advances to T2.
 *  6. Bob claims. _updatePool() advances accStablePerShare across [T0, T2] using
 *     the REDUCED totalStaked = S. Bob now receives the FULL emission for
 *     [T0, T2], including Alice's share of [T0, T1].
 *
 * EXPECTED ASSERTION:
 * Bob's claimed amount > the fair-share amount he would have received in a
 * control scenario where Alice withdraws via the regular `withdraw()` path
 * (which calls _updatePool() before decrementing totalStaked, correctly
 * settling the pre-exit window against the pre-decrement share base).
 */
contract PocM01Test is Test {
    PhlimboV2 public phlimbo;
    MockFlax public phUSD;
    MockStable public rewardToken;

    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public rewardDonor = address(0x3);
    address public pauser = address(0x4);

    uint256 constant INITIAL_BALANCE = 10_000 ether;
    uint256 constant STAKE_AMOUNT = 100 ether;
    uint256 constant DEPLETION_DURATION = 604_800; // 1 week
    uint256 constant REWARD_AMOUNT = 100 ether;

    // Window from T0 -> T1 (pre-pauseWithdraw) and T1 -> T2 (post-unpause).
    // Equal halves of DEPLETION_DURATION so the linear-depletion arithmetic
    // produces clean expectations for assertions.
    uint256 constant WINDOW_A = DEPLETION_DURATION / 4; // 1/4 of a week
    uint256 constant WINDOW_B = DEPLETION_DURATION / 4; // 1/4 of a week

    function _deployFreshContract() internal {
        phUSD = new MockFlax();
        rewardToken = new MockStable();

        phlimbo = new PhlimboV2(
            address(phUSD),
            address(rewardToken),
            DEPLETION_DURATION
        );

        phUSD.setMinter(address(phlimbo), true);

        phUSD.mint(alice, INITIAL_BALANCE);
        phUSD.mint(bob, INITIAL_BALANCE);
        rewardToken.mint(rewardDonor, INITIAL_BALANCE);

        vm.prank(alice);
        phUSD.approve(address(phlimbo), type(uint256).max);
        vm.prank(bob);
        phUSD.approve(address(phlimbo), type(uint256).max);
        vm.prank(rewardDonor);
        rewardToken.approve(address(phlimbo), type(uint256).max);

        phlimbo.setPauser(pauser);
    }

    /**
     * @notice Runs the buggy scenario: Alice exits via pauseWithdraw at T1
     *         (no _updatePool), then Bob claims at T2.
     * @return bobStableReceived The stable reward tokens Bob actually received.
     */
    function _runBuggyScenario() internal returns (uint256 bobStableReceived) {
        _deployFreshContract();

        // T0: both stake equal amounts
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.prank(bob);
        phlimbo.stake(STAKE_AMOUNT, bob);

        // T0: collect rewards (establishes rewardPerSecond)
        vm.prank(rewardDonor);
        phlimbo.collectReward(REWARD_AMOUNT);

        // T0 -> T1: rewards accrue while BOTH are staked.
        vm.warp(block.timestamp + WINDOW_A);

        // T1: pause and have Alice exit via pauseWithdraw.
        // NOTE: pauseWithdraw does NOT call _updatePool. lastRewardTime
        //       remains at T0; totalStaked drops from 2S to S.
        vm.prank(pauser);
        phlimbo.pause();
        vm.prank(alice);
        phlimbo.pauseWithdraw(STAKE_AMOUNT);

        // T1: unpause so Bob can claim.
        vm.prank(pauser);
        phlimbo.unpause();

        // T1 -> T2: more time elapses (further accruing rewards).
        vm.warp(block.timestamp + WINDOW_B);

        // T2: Bob claims.
        uint256 bobBefore = rewardToken.balanceOf(bob);
        vm.prank(bob);
        phlimbo.claim(bob);
        bobStableReceived = rewardToken.balanceOf(bob) - bobBefore;
    }

    /**
     * @notice Control scenario: identical timing, but Alice uses regular
     *         `withdraw()` at T1 instead of pauseWithdraw. `withdraw()` calls
     *         _updatePool() FIRST, correctly settling the pre-exit window
     *         against totalStaked = 2S before decrementing.
     * @return bobStableReceived The stable reward tokens Bob actually received.
     */
    function _runControlScenario() internal returns (uint256 bobStableReceived) {
        _deployFreshContract();

        // T0: both stake equal amounts
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.prank(bob);
        phlimbo.stake(STAKE_AMOUNT, bob);

        // T0: collect rewards
        vm.prank(rewardDonor);
        phlimbo.collectReward(REWARD_AMOUNT);

        // T0 -> T1
        vm.warp(block.timestamp + WINDOW_A);

        // T1: Alice withdraws via the regular path (which calls _updatePool
        // and settles the [T0, T1] window against totalStaked = 2S).
        // No pause needed.
        vm.prank(alice);
        phlimbo.withdraw(STAKE_AMOUNT, alice);

        // T1 -> T2
        vm.warp(block.timestamp + WINDOW_B);

        // T2: Bob claims.
        uint256 bobBefore = rewardToken.balanceOf(bob);
        vm.prank(bob);
        phlimbo.claim(bob);
        bobStableReceived = rewardToken.balanceOf(bob) - bobBefore;
    }

    /**
     * @notice Main PoC: shows Bob receives MORE rewards in the buggy scenario
     *         than in the control scenario, with the delta equal to Alice's
     *         forfeited fair share of the [T0, T1] window.
     */
    function test_M01_pauseWithdrawCausesRewardWindfall() public {
        // ============================================================
        // SCENARIO A: BUGGY (Alice exits via pauseWithdraw)
        // ============================================================
        uint256 bobBuggy = _runBuggyScenario();

        // ============================================================
        // SCENARIO B: CONTROL (Alice exits via regular withdraw)
        // ============================================================
        uint256 bobControl = _runControlScenario();

        // ============================================================
        // ANALYTICAL EXPECTATION
        // ============================================================
        // Per the linear-depletion model with rewardPerSecond fixed at
        // collectReward time:
        //   rewardPerSecond_scaled = REWARD_AMOUNT * PRECISION / DEPLETION_DURATION
        //
        // Over WINDOW_A (= DEPLETION_DURATION / 4) the pool emits:
        //   emissionA = REWARD_AMOUNT / 4
        // Over WINDOW_B (= DEPLETION_DURATION / 4) the pool emits:
        //   emissionB = REWARD_AMOUNT / 4
        //
        // CONTROL (fair):
        //   - WINDOW_A: Bob gets emissionA / 2 (split with Alice)
        //   - WINDOW_B: Bob gets emissionB (Bob solo)
        //   - bobControl = emissionA/2 + emissionB = 25/2 + 25 = 37.5 ether
        //
        // BUGGY (windfall):
        //   - Alice's pauseWithdraw does NOT advance lastRewardTime, so when
        //     Bob's claim triggers _updatePool, timeElapsed = WINDOW_A + WINDOW_B,
        //     and the accumulator advances against totalStaked = S (Bob alone).
        //   - bobBuggy = emissionA + emissionB = 50 ether
        //
        // DELTA = bobBuggy - bobControl
        //       = emissionA/2
        //       = REWARD_AMOUNT * WINDOW_A / DEPLETION_DURATION / 2
        //       = 100 ether * (DEPLETION_DURATION/4) / DEPLETION_DURATION / 2
        //       = 100 ether / 8
        //       = 12.5 ether
        //
        // This is EXACTLY Alice's forfeited fair share of WINDOW_A
        // (emissionA / 2), re-credited to Bob.
        uint256 emissionA = REWARD_AMOUNT / 4;
        uint256 emissionB = REWARD_AMOUNT / 4;
        uint256 expectedControl = emissionA / 2 + emissionB; // 37.5e18
        uint256 expectedBuggy = emissionA + emissionB;       // 50e18
        uint256 expectedDelta = emissionA / 2;               // 12.5e18 — Alice's stolen share

        emit log_named_uint("Bob received (control)         ", bobControl);
        emit log_named_uint("Bob received (buggy)           ", bobBuggy);
        emit log_named_uint("Windfall delta (bobBuggy - bobControl)", bobBuggy - bobControl);
        emit log_named_uint("Expected control               ", expectedControl);
        emit log_named_uint("Expected buggy                 ", expectedBuggy);
        emit log_named_uint("Expected delta (Alice's stolen share)", expectedDelta);

        // ============================================================
        // ASSERTIONS — strict, concrete
        // ============================================================

        // (1) Control: Bob received ~37.5 ether (his fair share)
        assertApproxEqAbs(
            bobControl,
            expectedControl,
            1e9, // 1 gwei tolerance for PRECISION rounding
            "Control: Bob should receive his fair share (37.5 ether)"
        );

        // (2) Buggy: Bob received ~50 ether (full window emission)
        assertApproxEqAbs(
            bobBuggy,
            expectedBuggy,
            1e9,
            "Buggy: Bob should receive the full window emission (50 ether)"
        );

        // (3) The windfall: buggy strictly exceeds control by Alice's stolen share
        assertGt(
            bobBuggy,
            bobControl,
            "Buggy scenario must over-distribute to Bob vs. control"
        );

        // (4) The exact size of the windfall equals Alice's forfeited share
        assertApproxEqAbs(
            bobBuggy - bobControl,
            expectedDelta,
            1e9,
            "Windfall delta must equal Alice's forfeited share of WINDOW_A (12.5 ether)"
        );

        // (5) Hard lower bound — buggy delivers at least 33% more than control
        //     (50/37.5 = 1.333...) — proves a MATERIAL over-distribution, not
        //     a rounding artifact.
        assertGt(
            bobBuggy * 100,
            bobControl * 133,
            "Buggy delivers >33% more than control - material over-distribution"
        );
    }
}
