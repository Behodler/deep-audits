// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PhlimboV3.sol";
import "../test/Mocks.sol";

/**
 * @notice Mirrors MigratorV2V3's REAL external surface with respect to PhlimboV3.
 *         MigratorV2V3 (src/MigratorV2V3.sol @ f279c62) exposes exactly:
 *           seedUsers, migrate, migrateOne, skipCurrent, claimUnclaimable,
 *           withdrawAll, userCount
 *         NONE of which call phlimboV3.claimUnclaimablePhUSD(). `claimUnclaimable`
 *         (:302) reads the migrator's OWN `unclaimable[token][msg.sender]` mapping,
 *         and `withdrawAll` (:318) sweeps balanceOf(address(this)).
 *         This stub reproduces that surface faithfully.
 */
contract MigratorStub {
    PhlimboV3 public phlimbo;
    MockRevertingMintFlax public phUSD;

    constructor(address _phlimbo, address _phUSD) {
        phlimbo = PhlimboV3(_phlimbo);
        phUSD = MockRevertingMintFlax(_phUSD);
    }

    function stakeFor(uint256 amount, address user) external {
        phUSD.approve(address(phlimbo), type(uint256).max);
        phlimbo.stake(amount, user);
    }

    function claimFor(address user) external {
        phlimbo.claim(user);
    }

    /// Mirrors MigratorV2V3.withdrawAll — a BALANCE sweep, the only recovery it has.
    function withdrawAll(address to) external returns (uint256 swept) {
        swept = phUSD.balanceOf(address(this));
        if (swept > 0) phUSD.transfer(to, swept);
    }
}

/// The same stub PLUS the one missing call-through. Positive control: proves the
/// value is reachable in principle, so the strand is an ABI-completeness gap.
contract MigratorStubWithPull is MigratorStub {
    constructor(address _p, address _f) MigratorStub(_p, _f) {}

    function pullBank() external {
        phlimbo.claimUnclaimablePhUSD();
    }
}

/**
 * @title EconScanRun11
 * @notice Tier-2 economic scan, phlimbo-ea run-11 (story-031 phUSD mint banking).
 */
contract EconScanRun11 is Test {
    PhlimboV3 public phlimbo;
    MockRevertingMintFlax public phUSD;
    MockStable public stable;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public rewardDonor = address(0x3);
    address public safe = address(0xBEEF);

    uint256 constant STAKE_AMOUNT = 1000 ether;
    uint256 constant DEPLETION_DURATION = 604800;

    function setUp() public {
        phUSD = new MockRevertingMintFlax();
        stable = new MockStable();
        phlimbo = new PhlimboV3(address(phUSD), address(stable), DEPLETION_DURATION);
        phUSD.setMinter(address(phlimbo), true);

        phUSD.mint(alice, 10000 ether);
        phUSD.mint(bob, 10000 ether);

        vm.prank(alice);
        phUSD.approve(address(phlimbo), type(uint256).max);
        vm.prank(bob);
        phUSD.approve(address(phlimbo), type(uint256).max);

        stable.mint(rewardDonor, 100000 ether);
        vm.prank(rewardDonor);
        stable.approve(address(phlimbo), type(uint256).max);

        // Non-zero APY. NOTE: this is NOT the shipped config (desiredAPYBps has no
        // ctor initializer => 0 by construction). Every phUSD-bank finding below is
        // gated behind exactly this line — the DEDUP-04 re-emit trigger.
        phlimbo.setDesiredAPY(500);
        phlimbo.setDesiredAPY(500);
    }

    // ================= ECON-001: migrator-delegated bank is stranded =================

    function test_ECON001_migratorBank_strandedOnChain() public {
        MigratorStub mig = new MigratorStub(address(phlimbo), address(phUSD));
        phlimbo.setMigrator(address(mig));
        // NOTE: migrator deliberately holds NO phUSD float, so any balance it ends
        // up with can only have come from the bank.
        assertEq(phUSD.balanceOf(address(mig)), 0, "migrator starts with zero phUSD");

        // Alice already holds a V3 position (the second-pass / normal-delegation case).
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.warp(block.timestamp + 100000);

        uint256 earned = phlimbo.pendingPhUSD(alice);
        assertGt(earned, 0, "alice accrued phUSD");

        // PhlimboV3 loses mint authority.
        phUSD.setMintReverts(true);

        // Migrator claims on Alice's behalf. beneficiary == msg.sender == migrator.
        mig.claimFor(alice);

        // Alice's value LEFT her account...
        assertEq(phlimbo.pendingPhUSD(alice), 0, "alice pending realigned to 0");
        assertEq(phlimbo.unclaimablePhUSDOf(alice), 0, "alice has NO bank entry");
        // ...and landed in the migrator's bank.
        assertEq(phlimbo.unclaimablePhUSDOf(address(mig)), earned, "banked to MIGRATOR");
        assertEq(phlimbo.totalUnclaimablePhUSD(), earned, "aggregate");

        // Mint authority restored — the bank is now honourable in principle.
        phUSD.setMintReverts(false);

        // Alice cannot pull it: the entry is keyed to the migrator.
        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        phlimbo.claimUnclaimablePhUSD();

        // The migrator's ONLY recovery (balance sweep) reaches NOTHING of it: the
        // phUSD was never minted, so there is no balance to sweep.
        uint256 swept = mig.withdrawAll(safe);
        assertEq(swept, 0, "balance sweep recovers nothing of the bank");

        // PhlimboV3's terminal ejector seat cannot reach it either.
        uint256 safeBefore = phUSD.balanceOf(safe);
        phlimbo.emergencyTransfer(safe);
        assertEq(
            phlimbo.unclaimablePhUSDOf(address(mig)), earned,
            "bank SURVIVES emergencyTransfer untouched (nothing to sweep)"
        );

        // The bank entry is permanently live but unreachable on-chain.
        assertEq(phlimbo.totalUnclaimablePhUSD(), earned, "liability permanently outstanding");
        safeBefore; // silence
    }

    /// Positive control: the identical scenario is fully recoverable if the migrator
    /// merely exposes a call-through. Proves ECON-001 is an ABI gap, not inevitable.
    function test_ECON001_positiveControl_callThroughRecovers() public {
        MigratorStubWithPull mig = new MigratorStubWithPull(address(phlimbo), address(phUSD));
        phlimbo.setMigrator(address(mig));
        phUSD.mint(address(mig), 10000 ether);

        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.warp(block.timestamp + 100000);
        uint256 earned = phlimbo.pendingPhUSD(alice);

        phUSD.setMintReverts(true);
        mig.claimFor(alice);
        assertEq(phlimbo.unclaimablePhUSDOf(address(mig)), earned, "banked to migrator");

        phUSD.setMintReverts(false);
        mig.pullBank(); // the one function MigratorV2V3 lacks
        assertEq(phUSD.balanceOf(address(mig)) - 10000 ether, earned, "recovered");
        assertEq(phlimbo.unclaimablePhUSDOf(address(mig)), 0, "bank cleared");
    }

    // ============ ECON-002: bank survives the terminal ejector seat ============

    function test_ECON002_bankMintsFreshSupplyAfterEmergencyTransfer() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.warp(block.timestamp + 100000);
        uint256 earned = phlimbo.pendingPhUSD(alice);

        phUSD.setMintReverts(true);
        vm.prank(alice);
        phlimbo.claim(alice); // banks
        assertEq(phlimbo.unclaimablePhUSDOf(alice), earned, "banked");
        phUSD.setMintReverts(false);

        // Owner pulls the terminal ejector seat: sweeps every balance, pauses.
        phlimbo.emergencyTransfer(safe);
        assertEq(phUSD.balanceOf(address(phlimbo)), 0, "contract drained");
        assertTrue(phlimbo.paused(), "paused by ejector seat");

        uint256 supplyBefore = phUSD.totalSupply();

        // The bank is STILL live: un-pause-gated, permissionless, and it MINTS
        // FRESH SUPPLY that the sweep never accounted for.
        vm.prank(alice);
        phlimbo.claimUnclaimablePhUSD();

        assertEq(phUSD.balanceOf(alice) , 10000 ether - STAKE_AMOUNT + earned, "alice minted post-sweep");
        assertEq(phUSD.totalSupply(), supplyBefore + earned, "FRESH supply minted after the ejector seat");
    }

    // ============ ECON-003: value conservation (banked + paid == earned) ============

    function test_ECON003_valueConservation_noDoublePay() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.warp(block.timestamp + 100000);

        uint256 earned1 = phlimbo.pendingPhUSD(alice);
        phUSD.setMintReverts(true);
        vm.prank(alice);
        phlimbo.claim(alice); // banks earned1

        // Accrue a second tranche and claim it successfully.
        vm.warp(block.timestamp + 100000);
        uint256 earned2 = phlimbo.pendingPhUSD(alice);
        phUSD.setMintReverts(false);

        uint256 balBefore = phUSD.balanceOf(alice);
        vm.prank(alice);
        phlimbo.claim(alice); // pays earned2 only — must NOT re-pay earned1
        assertEq(phUSD.balanceOf(alice) - balBefore, earned2, "paid exactly tranche 2");
        assertEq(phlimbo.unclaimablePhUSDOf(alice), earned1, "tranche 1 still banked, not double-paid");

        // Pull the bank: total received == earned1 + earned2, exactly once each.
        vm.prank(alice);
        phlimbo.claimUnclaimablePhUSD();
        assertEq(phUSD.balanceOf(alice) - balBefore, earned1 + earned2, "banked + paid == earned");
        assertEq(phlimbo.unclaimablePhUSDOf(alice), 0, "bank cleared");
        assertEq(phlimbo.totalUnclaimablePhUSD(), 0, "aggregate cleared");

        // Second pull is refused — no double-drain of the bank.
        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        phlimbo.claimUnclaimablePhUSD();
    }

    // ============ ECON-004: zero-APY dormancy (the DEDUP-04 premise) ============

    function test_ECON004_atShippedZeroAPY_bankIsUnreachable() public {
        // Fresh instance at the SHIPPED config: desiredAPYBps untouched => 0.
        MockRevertingMintFlax f = new MockRevertingMintFlax();
        MockStable s = new MockStable();
        PhlimboV3 p = new PhlimboV3(address(f), address(s), DEPLETION_DURATION);
        f.setMinter(address(p), true);
        assertEq(p.desiredAPYBps(), 0, "shipped default is zero APY (no ctor initializer)");

        f.mint(alice, 10000 ether);
        vm.startPrank(alice);
        f.approve(address(p), type(uint256).max);
        p.stake(STAKE_AMOUNT, alice);
        vm.stopPrank();

        vm.warp(block.timestamp + 3650 days); // ten years
        assertEq(p.pendingPhUSD(alice), 0, "zero APY => zero phUSD accrual, ever");

        // Mint authority lost — the leg still cannot be entered.
        f.setMintReverts(true);
        vm.prank(alice);
        p.claim(alice);
        assertEq(p.unclaimablePhUSDOf(alice), 0, "bank NEVER written at zero APY");
        assertEq(p.totalUnclaimablePhUSD(), 0, "story-031's leg is dead code at the shipped config");
    }

    // ============ ECON-005: third party cannot force another user's bank ============

    function test_ECON005_thirdPartyCannotForceVictimBank() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        vm.warp(block.timestamp + 100000);
        phUSD.setMintReverts(true);

        // Bob (no role) cannot reach Alice's claim path at all — so he cannot
        // gas-grief her mint into the bank via the 63/64 rule.
        vm.prank(bob);
        vm.expectRevert("Not authorized");
        phlimbo.claim(alice);

        vm.prank(bob);
        vm.expectRevert("Not authorized");
        phlimbo.withdraw(1 ether, alice);

        vm.prank(bob);
        vm.expectRevert("Not authorized");
        phlimbo.stake(1 ether, alice);
    }
}
