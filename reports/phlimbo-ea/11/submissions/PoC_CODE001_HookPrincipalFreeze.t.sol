// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PhlimboV3.sol";
import "../src/PhlimboV2.sol";
import "../src/interfaces/IPhlimboHook.sol";
import "./Mocks.sol";

/*//////////////////////////////////////////////////////////////////////////////
                        PoC: CODE-001 (phlimbo-ea run-11)

  FINDING
    The optional IPhlimboHook is invoked with NO try/catch at the tail of all
    three principal-moving functions:
        src/PhlimboV3.sol:730   stake    -> hook.onDeposit
        src/PhlimboV3.sol:781   withdraw -> hook.onWithdraw   (AFTER the principal
                                            safeTransfer at :774)
        src/PhlimboV3.sol:813   claim    -> hook.onClaim
    A reverting hook unwinds the ENTIRE call, including withdraw's principal
    transfer, freezing every staker's phUSD principal pool-wide until the owner
    calls setHook(address(0)).

  WHY IT IS SURFACED IN THIS BASELINE WINDOW (two changes converge)
    story-031: banked the last reward leg (phUSD mint try/catch at :913), making
               the hook the SOLE remaining revert path that can freeze principal.
    story-030: DELETED pauseWithdraw -- the express reason this class was rated
               LOW on V2 (ledger V2-L-09: "pauseWithdraw is hook-exempt so a
               principal exit survives"). PhlimboV2.sol:280 still carries the
               NatSpec "Emergency exit mechanism ... Does NOT invoke any hook."
               V3 has no such function. test_CODE001_D_* proves the delta by
               running the identical scenario against both contracts.

  LAW-3 FRAMING (honest scope -- read before weighting severity)
    `hook` is address(0) at the shipped config and is opt-in, so this is INERT
    until setHook is called. This is a NON-OBVIOUS OWNER FOOTGUN, not an
    unprivileged exploit. The hooks below are deliberately modelled as things a
    competent, NON-MALICIOUS owner would plausibly attach (a points/analytics
    observer; a mirror-accounting hook), which break LATER for third-party
    reasons -- not as griefing contracts. No test here stages the owner as an
    attacker.

  SEVERITY CAP
    test_CODE001_E_* shows one cheap owner call (setHook(address(0))) fully
    restores withdrawals. Principal is FROZEN, never stolen -> Medium, not High.
//////////////////////////////////////////////////////////////////////////////*/

/// @notice A downstream dependency the hook reports into (points backend, indexer,
///         booster registry). Pausable/upgradable by ITS OWN operator -- not by the
///         Phlimbo owner. This models the time-shift: healthy at setHook time,
///         reverting later, with no Phlimbo-owner action at that moment.
contract PointsRegistry {
    error RegistryPaused();

    bool public paused;
    mapping(address => uint256) public points;

    function setPaused(bool v) external {
        paused = v;
    }

    function record(address user, uint256 amount) external {
        if (paused) revert RegistryPaused();
        points[user] += amount;
    }
}

/// @notice A plausible, non-malicious observer hook: forwards stake/withdraw/claim
///         to a points registry. Fire-and-forget by intent; load-bearing in fact.
contract PointsObserverHook is IPhlimboHook {
    PointsRegistry public immutable registry;

    constructor(PointsRegistry _registry) {
        registry = _registry;
    }

    function onDeposit(address, address user, uint256 amount) external {
        registry.record(user, amount);
    }

    function onWithdraw(address, address user, uint256 amount) external {
        registry.record(user, amount);
    }

    function onClaim(address, address user, uint256 phUSDAmount, uint256) external {
        registry.record(user, phUSDAmount);
    }
}

/// @notice A second plausible, non-malicious hook: mirrors staked balances into its
///         own accounting. Correct for every user who stakes AFTER it is attached.
///         Attaching it to a LIVE pool (the realistic case) leaves pre-existing
///         stakers with a zero mirror, so onWithdraw's `-=` underflows -> Panic 0x11.
///         The owner's knowing act is "attach an observer"; the freeze is emergent.
contract MirrorAccountingHook is IPhlimboHook {
    mapping(address => uint256) public mirrored;

    function onDeposit(address, address user, uint256 amount) external {
        mirrored[user] += amount;
    }

    function onWithdraw(address, address user, uint256 amount) external {
        mirrored[user] -= amount; // underflows for stakers who pre-date the hook
    }

    function onClaim(address, address, uint256, uint256) external {}
}

contract CODE001PoCTest is Test {
    PhlimboV3 public phlimbo;
    MockFlax public phUSD;
    MockStable public rewardToken;

    PointsRegistry public registry;
    PointsObserverHook public hook;

    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public rewardDonor = address(0x3);
    address public pauser = address(0x4);

    uint256 constant INITIAL_BALANCE = 10_000 ether;
    uint256 constant STAKE_AMOUNT = 1_000 ether;
    uint256 constant DEPLETION_DURATION = 604800;

    function setUp() public {
        phUSD = new MockFlax();
        rewardToken = new MockStable();

        phlimbo = new PhlimboV3(address(phUSD), address(rewardToken), DEPLETION_DURATION);
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

        registry = new PointsRegistry();
        hook = new PointsObserverHook(registry);
    }

    // ---------------------------------------------------------------------
    // helpers
    // ---------------------------------------------------------------------

    /// @dev Calls `phlimbo` as `caller` with raw calldata and returns the EXACT
    ///      revert returndata, so the PoC asserts the precise selector/payload
    ///      rather than merely "it reverted".
    function _rawCall(address caller, bytes memory data) internal returns (bool ok, bytes memory ret) {
        vm.prank(caller);
        (ok, ret) = address(phlimbo).call(data);
    }

    function _stakedOf(address u) internal view returns (uint256 amt) {
        (amt,,,) = phlimbo.userInfo(u);
    }

    // =====================================================================
    // A. Baseline -- staker stakes and could withdraw with NO hook set
    // =====================================================================

    function test_CODE001_A_baseline_noHook_stakeAndWithdrawWork() public {
        assertEq(address(phlimbo.hook()), address(0), "shipped config: hook is unset");

        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        assertEq(_stakedOf(alice), STAKE_AMOUNT, "alice staked");

        uint256 before = phUSD.balanceOf(alice);
        vm.prank(alice);
        phlimbo.withdraw(STAKE_AMOUNT, alice);

        assertEq(phUSD.balanceOf(alice) - before, STAKE_AMOUNT, "principal exits freely with no hook");
        assertEq(_stakedOf(alice), 0, "position closed");
    }

    // =====================================================================
    // B. Owner attaches a HEALTHY observer hook -- everything still works.
    //    This is the whole footgun: setHook looks completely benign at the
    //    moment the owner performs it. The hazard is time-shifted.
    // =====================================================================

    function test_CODE001_B_ownerAttachesHealthyHook_nothingLooksWrong() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);

        phlimbo.setHook(address(hook)); // owner's knowing act: "attach an observer"
        assertEq(address(phlimbo.hook()), address(hook), "hook attached");

        // Registry healthy -> stake / withdraw / claim all succeed. The owner's
        // post-setHook smoke test passes. Nothing signals a principal hazard.
        vm.prank(bob);
        phlimbo.stake(STAKE_AMOUNT, bob);

        vm.prank(bob);
        phlimbo.withdraw(STAKE_AMOUNT, bob);
        assertEq(_stakedOf(bob), 0, "withdraw works while the hook is healthy");

        assertGt(registry.points(bob), 0, "observer is recording, as intended");
    }

    // =====================================================================
    // C. THE FINDING. The registry pauses (third-party, no Phlimbo-owner action
    //    at that moment). withdraw() now reverts with the EXACT downstream error
    //    and alice's principal is inaccessible.
    // =====================================================================

    function test_CODE001_C_hookReverts_freezesPrincipal_exactError() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        phlimbo.setHook(address(hook));

        // --- time passes; the downstream registry's own operator pauses it ---
        vm.warp(block.timestamp + 30 days);
        registry.setPaused(true);

        uint256 aliceBefore = phUSD.balanceOf(alice);
        uint256 poolBefore = phUSD.balanceOf(address(phlimbo));

        // Capture the EXACT revert payload propagating out of withdraw().
        (bool ok, bytes memory ret) =
            _rawCall(alice, abi.encodeWithSelector(PhlimboV3.withdraw.selector, STAKE_AMOUNT, alice));

        assertFalse(ok, "withdraw reverted");
        assertEq(
            ret,
            abi.encodeWithSelector(PointsRegistry.RegistryPaused.selector),
            "EXACT revert: PointsRegistry.RegistryPaused() propagates unwrapped out of PhlimboV3.withdraw"
        );
        emit log_named_bytes("exact revert returndata from withdraw()", ret);
        emit log_named_bytes32("RegistryPaused selector", bytes32(PointsRegistry.RegistryPaused.selector));

        // Principal did not move. The safeTransfer at :774 executed and was then
        // unwound by the hook at :781.
        assertEq(phUSD.balanceOf(alice), aliceBefore, "alice received nothing");
        assertEq(phUSD.balanceOf(address(phlimbo)), poolBefore, "principal still trapped in the pool");
        assertEq(_stakedOf(alice), STAKE_AMOUNT, "position intact but inert -- FROZEN");
    }

    // =====================================================================
    // D. NO ESCAPE PATH. Enumerate every user-callable exit and prove each one
    //    either reverts or cannot move principal. Then run the IDENTICAL
    //    scenario on PhlimboV2 and show pauseWithdraw DOES rescue the staker --
    //    which is exactly what story-030 deleted.
    // =====================================================================

    function test_CODE001_D_noHookExemptExitExists_onV3() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);

        // Give alice real accrued rewards so `claim` has something to do.
        vm.prank(rewardDonor);
        phlimbo.collectReward(100 ether);
        vm.warp(block.timestamp + 1 days);
        assertGt(phlimbo.pendingStable(alice), 0, "alice has real pending rewards");

        phlimbo.setHook(address(hook));
        registry.setPaused(true);

        bytes memory expected = abi.encodeWithSelector(PointsRegistry.RegistryPaused.selector);
        bool ok;
        bytes memory ret;

        // 1. full withdraw -> hook at :781
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.withdraw.selector, STAKE_AMOUNT, alice));
        assertFalse(ok);
        assertEq(ret, expected, "full withdraw blocked by hook");

        // 2. partial withdraw -> same leg, no smaller-amount escape
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.withdraw.selector, STAKE_AMOUNT / 2, alice));
        assertFalse(ok);
        assertEq(ret, expected, "partial withdraw blocked by hook");

        // 3. claim -> hook at :813 (rewards also frozen)
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.claim.selector, alice));
        assertFalse(ok);
        assertEq(ret, expected, "claim blocked by hook");

        // 4. stake -> hook at :730 (cannot even top up)
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.stake.selector, STAKE_AMOUNT, alice));
        assertFalse(ok);
        assertEq(ret, expected, "stake blocked by hook");

        // 5. The hook-exempt reward pulls exist -- but they carry ONLY banked
        //    rewards, never principal. They are empty here and revert.
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.claimUnclaimableStable.selector));
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSignature("Error(string)", "Nothing to claim"), "no banked stable");

        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.claimUnclaimablePhUSD.selector));
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSignature("Error(string)", "Nothing to claim"), "no banked phUSD");

        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.claimUnclaimablePromo.selector, address(phUSD)));
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSignature("Error(string)", "Nothing to claim"), "no banked promo");

        // 6. batchClaim is permissionless but promo-only and phase-gated.
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.batchClaim.selector, uint256(10)));
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSignature("Error(string)", "Promo phase must be Flushing"), "batchClaim gated");

        // 7. V2's hook-exempt emergency exit does not exist on V3 at all:
        //    the selector is absent and there is no fallback.
        (ok,) = _rawCall(alice, abi.encodeWithSignature("pauseWithdraw(uint256)", STAKE_AMOUNT));
        assertFalse(ok, "pauseWithdraw(uint256) selector is GONE from PhlimboV3 (story-030)");
        (ok,) = _rawCall(alice, abi.encodeWithSignature("emergencyWithdraw(uint256)", STAKE_AMOUNT));
        assertFalse(ok, "no emergencyWithdraw on PhlimboV3 either");

        // 8. emergencyTransfer is onlyOwner and terminal -- not a user-side exit.
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.emergencyTransfer.selector, alice));
        assertFalse(ok);
        assertEq(
            ret,
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice),
            "emergencyTransfer is owner-only; the staker cannot compel it"
        );

        // 9. Pausing does not open an exit -- it closes the only one. On V2 pausing
        //    ENABLED the hook-exempt pauseWithdraw; on V3 it just adds a second gate.
        vm.prank(pauser);
        phlimbo.pause();
        (ok, ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.withdraw.selector, STAKE_AMOUNT, alice));
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSignature("EnforcedPause()"), "paused: withdraw gated even before the hook");

        // Net: principal is fully trapped, zero user recourse.
        assertEq(phUSD.balanceOf(alice), INITIAL_BALANCE - STAKE_AMOUNT, "alice never got principal back");
        assertEq(_stakedOf(alice), STAKE_AMOUNT, "principal FROZEN with no self-service path out");
    }

    /// @dev The counterfactual that makes the V2->V3 severity re-file honest:
    ///      identical hook, identical failure, but V2's hook-exempt pauseWithdraw
    ///      (PhlimboV2.sol:280 -- "Does NOT invoke any hook") rescues the staker.
    ///      This is precisely the mitigation ledger V2-L-09 cited for its LOW.
    function test_CODE001_D2_v2_pauseWithdraw_rescuesStaker_v3_hasNoEquivalent() public {
        PhlimboV2 v2 = new PhlimboV2(address(phUSD), address(rewardToken), DEPLETION_DURATION);
        phUSD.setMinter(address(v2), true);
        v2.setPauser(pauser);

        vm.prank(alice);
        phUSD.approve(address(v2), type(uint256).max);
        vm.prank(alice);
        v2.stake(STAKE_AMOUNT, alice);

        v2.setHook(address(hook));
        registry.setPaused(true);

        // Same brick on V2's normal path...
        vm.prank(alice);
        vm.expectRevert(PointsRegistry.RegistryPaused.selector);
        v2.withdraw(STAKE_AMOUNT, alice);

        // ...but V2's second, pauser-held remedy works: the pauser pauses, which
        // unlocks the hook-exempt pauseWithdraw for alice. NOT a unilateral escape.
        vm.prank(pauser);
        v2.pause();

        uint256 before = phUSD.balanceOf(alice);
        vm.prank(alice);
        v2.pauseWithdraw(STAKE_AMOUNT);

        // NOTE: this is NOT a unilateral user escape -- pauseWithdraw is `whenPaused`
        // and PhlimboV2.pause() is gated to the `pauser` role (PhlimboV2.sol:270), so a
        // privileged party had to act first here too. The V2->V3 delta is that V2 has a
        // SECOND, independently-held privileged remedy (the pauser can free principal
        // without the owner); V3 concentrates the sole remedy in the owner.
        assertEq(phUSD.balanceOf(alice) - before, STAKE_AMOUNT, "V2: pauser-held second remedy frees the staker");

        // V3 offers no counterpart -- the Low rationale of V2-L-09 is void on V3.
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        phlimbo.setHook(address(hook));
        vm.prank(pauser);
        phlimbo.pause();

        (bool ok,) = _rawCall(alice, abi.encodeWithSignature("pauseWithdraw(uint256)", STAKE_AMOUNT));
        assertFalse(ok, "V3: no hook-exempt exit exists at any pause state");
        assertEq(_stakedOf(alice), STAKE_AMOUNT, "V3: principal remains frozen");
    }

    // =====================================================================
    // E. RECOVERY -- caps severity at Medium. One cheap owner call restores
    //    withdrawals in full. Principal is frozen, never stolen.
    // =====================================================================

    function test_CODE001_E_setHookZero_fullyRestoresWithdrawals() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        phlimbo.setHook(address(hook));
        registry.setPaused(true);

        vm.prank(alice);
        vm.expectRevert(PointsRegistry.RegistryPaused.selector);
        phlimbo.withdraw(STAKE_AMOUNT, alice);

        // Owner notices and detaches the hook.
        phlimbo.setHook(address(0));

        uint256 before = phUSD.balanceOf(alice);
        vm.prank(alice);
        phlimbo.withdraw(STAKE_AMOUNT, alice);

        assertEq(phUSD.balanceOf(alice) - before, STAKE_AMOUNT, "principal fully recovered after setHook(0)");
        assertEq(_stakedOf(alice), 0, "position closed; no loss -- Medium, not High");
    }

    // =====================================================================
    // F. Second plausible non-malicious hook: mirror accounting attached to a
    //    LIVE pool. Same freeze, different root cause, EXACT Panic 0x11.
    //    Note the cruelty of this one: it works perfectly for every user who
    //    stakes after attach, so the owner's smoke test passes.
    // =====================================================================

    function test_CODE001_F_mirrorHookOnLivePool_panicUnderflow_freezesPrincipal() public {
        // alice stakes BEFORE the hook exists (the realistic live-pool case).
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);

        MirrorAccountingHook mirror = new MirrorAccountingHook();
        phlimbo.setHook(address(mirror));

        // bob stakes AFTER attach -> his mirror is correct -> he can exit.
        vm.prank(bob);
        phlimbo.stake(STAKE_AMOUNT, bob);
        vm.prank(bob);
        phlimbo.withdraw(STAKE_AMOUNT, bob);
        assertEq(_stakedOf(bob), 0, "post-attach staker exits fine -- owner's smoke test passes");

        // alice pre-dates the hook -> mirrored[alice] == 0 -> `-=` underflows.
        assertEq(mirror.mirrored(alice), 0, "pre-existing staker has an empty mirror");

        (bool ok, bytes memory ret) =
            _rawCall(alice, abi.encodeWithSelector(PhlimboV3.withdraw.selector, STAKE_AMOUNT, alice));

        assertFalse(ok, "withdraw reverted");
        assertEq(
            ret,
            abi.encodeWithSelector(bytes4(0x4e487b71), uint256(0x11)),
            "EXACT revert: Panic(0x11) arithmetic underflow propagates out of PhlimboV3.withdraw"
        );
        emit log_named_bytes("exact revert returndata from withdraw()", ret);

        assertEq(_stakedOf(alice), STAKE_AMOUNT, "alice's principal FROZEN by an observer's own bug");

        // And the same one-call recovery applies.
        phlimbo.setHook(address(0));
        vm.prank(alice);
        phlimbo.withdraw(STAKE_AMOUNT, alice);
        assertEq(_stakedOf(alice), 0, "recovered via setHook(0)");
    }

    // =====================================================================
    // G. Scope guard -- the finding is INERT at the shipped config. Recorded so
    //    the PoC cannot be read as claiming an unprivileged live exploit.
    // =====================================================================

    function test_CODE001_G_inertAtShippedConfig_requiresSetHook() public {
        assertEq(address(phlimbo.hook()), address(0), "no hook is set by default");

        registry.setPaused(true); // a broken hook exists in the world but is unattached

        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.prank(alice);
        phlimbo.withdraw(STAKE_AMOUNT, alice); // unaffected

        assertEq(_stakedOf(alice), 0, "with no hook attached the finding does not bite");

        // setHook is onlyOwner -- no unprivileged path arms this.
        (bool ok, bytes memory ret) = _rawCall(alice, abi.encodeWithSelector(PhlimboV3.setHook.selector, address(hook)));
        assertFalse(ok);
        assertEq(
            ret,
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice),
            "only the owner can arm this; it is a footgun, not an attack"
        );
    }
}
