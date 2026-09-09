// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/StableStaker.sol";
import "../../src/InPlaceMigrator.sol";
import "../../src/interfaces/IStableStaker.sol";
import "flax-token/FlaxToken.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockYieldStrategy} from "../mocks/MockYieldStrategy.sol";
import "reflax-yield-vault/interfaces/IYieldStrategy.sol";

/// @title PoC ss12m1 (M-01) FIX confirmation — surplus-funded re-injection top-up restores par.
/// @author stable-staker run-13 Tier-3 regression (fp 970d7307), submodule HEAD d95f4a6 (story-013).
///
/// @notice WHAT THIS PROVES (positive direction of the fix)
/// --------------------------------------------------------------------------------------------
/// Replays the EXACT run-12 haircut scenario (single staker, par migrateOut, fresh 2%-haircutting
/// re-injection strategy, migrateIn) but PRE-FUNDS surplus into the InPlaceMigrator so the
/// story-013 `_reinjectWithTopup` gross-up can fire. The re-injected user's `userInfo.amount` is
/// now restored to PAR (full parked principal, within amt/1000), not the 2%-haircut amount the
/// run-12 PoC asserted. Closes ss12m1.
///
/// @notice PLUS — the ZERO-surplus fail-closed probe (ECON-13-001)
/// --------------------------------------------------------------------------------------------
/// A second test runs the identical scenario with NO surplus pre-funded and confirms migrateIn
/// reverts atomically ("InPlaceMigrator: top-up surplus exhausted") — the silent per-user loss is
/// replaced by an all-or-nothing revert, so no principal is ever lost without the operator noticing.
contract PoC_ss12m1_TopupFix is Test {
    FlaxToken internal phUSD;
    StableStaker internal staker;
    InPlaceMigrator internal migrator;
    MockERC20 internal usdc;

    address internal owner = address(this);
    address internal staker_user = address(0xA11CE);

    uint256 internal constant PER_DAY = 86_400 ether;
    uint256 internal constant TIMEOUT = 7 days;

    uint256 internal constant PRINCIPAL = 1_000e6; // 1,000.000000 USDC
    uint256 internal constant SLIPPAGE_BPS = 200; // 2.00% deposit haircut

    function setUp() public {
        phUSD = new FlaxToken();
        staker = new StableStaker(phUSD, owner);
        phUSD.setMinter(address(staker), true);

        usdc = new MockERC20("USD Coin", "USDC", 6);
        staker.addToken(address(usdc));
        staker.phUSDPerDay(address(usdc), PER_DAY);

        migrator = new InPlaceMigrator(IStableStaker(address(staker)), TIMEOUT, owner);
        staker.setMigrator(address(migrator));

        usdc.mint(staker_user, PRINCIPAL);
        vm.prank(staker_user);
        usdc.approve(address(staker), type(uint256).max);
    }

    function _userAmount(address user) internal view returns (uint256 amt) {
        (amt,) = staker.userInfo(address(usdc), user);
    }

    function _singleUser() internal view returns (address[] memory users) {
        users = new address[](1);
        users[0] = staker_user;
    }

    /// Drive the round trip up to (but not including) migrateIn, wiring the 2% haircut strategy.
    /// Returns the haircut strategy so callers can inspect it.
    function _toMigrateInBoundary() internal returns (MockYieldStrategy haircutStrategy) {
        vm.prank(staker_user);
        staker.stake(address(usdc), PRINCIPAL);

        migrator.initiateMigration(address(usdc));
        migrator.migrateOut(address(usdc), _singleUser());

        assertEq(migrator.parked(address(usdc), staker_user), PRINCIPAL, "parked == principal");
        assertEq(migrator.totalParked(address(usdc)), PRINCIPAL, "totalParked == principal");

        staker.finalizeAndReset(address(usdc));

        haircutStrategy = new MockYieldStrategy();
        haircutStrategy.setClient(address(staker), true);
        haircutStrategy.setDepositSlippageBps(SLIPPAGE_BPS);
        staker.setYieldStrategy(address(usdc), IYieldStrategy(address(haircutStrategy)));
    }

    // ================================================================================
    // POSITIVE: pre-fund surplus -> top-up fires -> user restored to PAR
    // ================================================================================
    function test_ss12m1_FIX_topupRestoresParWhenSurplusFunded() public {
        _toMigrateInBoundary();

        // Pre-fund surplus: transfer EXTRA staked-token to the migrator so
        // (balanceOf - totalParked) can cover the grossed-up top-up. The gross-up for a 2% haircut
        // is topup = shortfall*amt/credited = 20e6 * 1000e6 / 980e6 ~= 20.408163e6; fund 25e6 to be safe.
        uint256 surplusFunded = 25e6;
        usdc.mint(address(migrator), surplusFunded);

        uint256 migratorBalBefore = usdc.balanceOf(address(migrator));
        assertEq(
            migratorBalBefore,
            PRINCIPAL + surplusFunded,
            "migrator holds parked principal + pre-funded surplus"
        );

        // Re-inject.
        migrator.migrateIn(address(usdc), 0, migrator.parkedUserCount(address(usdc)));

        uint256 creditedFinal = _userAmount(staker_user);
        uint256 migratorBalAfter = usdc.balanceOf(address(migrator));
        uint256 surplusConsumed = migratorBalBefore - PRINCIPAL - migratorBalAfter; // surplus actually spent

        // What the FIRST (principal) deposit alone would have credited (the run-12 haircut number).
        uint256 creditedBeforeTopup = (PRINCIPAL * (10_000 - SLIPPAGE_BPS)) / 10_000; // 980.000000

        emit log_string("--- ss12m1 FIX confirmation: surplus-funded top-up restores par ---");
        emit log_named_uint("original principal           ", PRINCIPAL);
        emit log_named_uint("credited BEFORE top-up (1st) ", creditedBeforeTopup);
        emit log_named_uint("credited AFTER top-up (final)", creditedFinal);
        emit log_named_uint("surplus pre-funded           ", surplusFunded);
        emit log_named_uint("surplus consumed by top-up   ", surplusConsumed);
        emit log_named_uint("migrator surplus remaining   ", migratorBalAfter);

        // CORE FIX ASSERTION: user restored to PAR (within amt/1000 == 0.1%, the contract's guarantee).
        assertGe(creditedFinal, PRINCIPAL - PRINCIPAL / 1000, "FIX: par restored within 0.1%");
        // The gross-up lands on par to within a 1-wei integer-division residual (999999999 of 1000000000).
        assertApproxEqAbs(creditedFinal, PRINCIPAL, 1, "FIX: re-credited principal == par (within 1 wei)");
        // The fix is a strict improvement over the run-12 haircut number.
        assertGt(creditedFinal, creditedBeforeTopup, "FIX: final credit strictly exceeds the haircut amount");

        // Parked state fully cleared.
        assertEq(migrator.totalParked(address(usdc)), 0, "totalParked zeroed");
        assertEq(migrator.parked(address(usdc), staker_user), 0, "user parked zeroed");

        // Surplus was actually consumed by the gross-up (and is < the naive 20e6 shortfall? no — grossed up).
        assertGt(surplusConsumed, 0, "top-up consumed real surplus");
        // Gross-up consumes ~20.408163e6 (> the 20e6 raw shortfall because it survives its own 2% haircut).
        assertApproxEqAbs(surplusConsumed, 20_408_163, 5, "surplus consumed ~= grossed-up top-up");
    }

    // ================================================================================
    // FAIL-CLOSED (ECON-13-001): zero surplus -> migrateIn reverts atomically, no silent loss
    // ================================================================================
    function test_ss12m1_FIX_zeroSurplusRevertsAtomically() public {
        _toMigrateInBoundary();

        // NO surplus pre-funded. Migrator holds exactly the parked principal.
        assertEq(usdc.balanceOf(address(migrator)), PRINCIPAL, "migrator holds only parked principal");

        // Resolve the count BEFORE expectRevert so the very next external call is migrateIn itself.
        uint256 count = migrator.parkedUserCount(address(usdc));
        vm.expectRevert("InPlaceMigrator: top-up surplus exhausted");
        migrator.migrateIn(address(usdc), 0, count);

        // Atomic revert => state untouched: user still fully parked, recoverable via claimTimedOut.
        assertEq(migrator.parked(address(usdc), staker_user), PRINCIPAL, "parked intact after revert");
        assertEq(migrator.totalParked(address(usdc)), PRINCIPAL, "totalParked intact after revert");
        assertEq(_userAmount(staker_user), 0, "no partial credit booked in staker");
    }
}
