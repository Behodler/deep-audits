// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// ============================================================================
//  AUDIT-AUTHORED PROOF OF CONCEPT — NOT PROJECT COVERAGE
//  This file does not exist at any submodule commit (checked against 3a96fb7).
//  It was written by the audit to demonstrate finding M-07 and must never be
//  cited as evidence of the project's own test coverage.
// ============================================================================

import {Test} from "@forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlaxToken} from "@phUSD/FlaxToken.sol";
import {IFlax} from "@phUSD/IFlax.sol";
import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";
import {Antimatter} from "../../src/Antimatter.sol";
import {MockStable} from "../mocks/MockStable.sol";
import {MockYieldStrategy} from "../mocks/MockYieldStrategy.sol";

/// @title M-07 PoC: story-003's `minPhUSDOut` slippage floor is inert at or below the antimatter half
/// @dev Vulnerable code: src/Antimatter.sol#L259-L263
///
///      uint256 totalPhUSD = amount + mintedForStable;                                  // :259
///      if (totalPhUSD < minPhUSDOut) revert InsufficientPhUSDOut(minPhUSDOut, totalPhUSD);
///      _phUSD.mint(recipient, amount);                                                 // :263
///
///      `_phUSD.mint(recipient, amount)` is unconditional and `mintedForStable >= 0`, so
///      `totalPhUSD >= amount` holds for every reachable execution. The predicate
///      `totalPhUSD < minPhUSDOut` is therefore unsatisfiable for every `minPhUSDOut` in
///      [0, amount]: the whole of that range buys zero protection.
///
///      That range is exactly where a caller reasoning in the natural units of the trade
///      lands. "I paired 100 antimatter, I want at least 100 phUSD back for my stablecoin
///      half" states `minPhUSDOut = 100 ether == amount` — the top of the inert band.
///
///      Mirrors the project's own test_shortPhUSDMintClearingFloorSucceeds
///      (test/Annihilation.t.sol:319) with the floor lowered from 150 ether to `amount`.
contract M07PoCTest is Test {
    Antimatter internal antimatter;
    FlaxToken internal phUSD;
    PhusdStableMinter internal minter;
    MockYieldStrategy internal strategy;
    MockStable internal usdc; // 6 decimals

    address internal owner = address(0xA11CE);
    address internal user = address(0xB0B);

    // Same wiring as the project's AnnihilationTest.setUp().
    function setUp() public {
        phUSD = new FlaxToken();
        minter = new PhusdStableMinter(address(phUSD));
        strategy = new MockYieldStrategy();
        usdc = new MockStable("USD Coin", "USDC", 6);

        antimatter = new Antimatter(owner);

        phUSD.setMinter(address(minter), true);
        phUSD.setMinter(address(antimatter), true);

        minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);
        minter.approveYS(address(usdc), address(strategy));

        vm.startPrank(owner);
        antimatter.setPhUSD(IFlax(address(phUSD)));
        antimatter.setPhUSDMinter(minter);
        vm.stopPrank();
    }

    // Same helper as the project's AnnihilationTest._fund().
    function _fund(address who, uint256 antimatterAmount, MockStable stable, uint256 stableAmount) internal {
        vm.prank(owner);
        antimatter.mint(who, antimatterAmount);
        stable.mint(who, stableAmount);
        vm.prank(who);
        stable.approve(address(antimatter), type(uint256).max);
    }

    /// The finding. A floor stated at the antimatter half is inert: the caller settles short on
    /// the stablecoin half (40% below par) with no revert, and that half is irrecoverable.
    function test_M07_floorAtAmountBuysNoProtection() public {
        uint256 amount = 100 ether;
        uint256 stableAmount = 100e6;
        _fund(user, amount, usdc, stableAmount);

        // The rate moves against the caller between quote and landing: the stable half now
        // fetches 0.6 phUSD per unit instead of 1.0.
        minter.updateExchangeRate(address(usdc), 6e17);

        // The caller states the floor in the natural units of the trade: "at least as much
        // phUSD as the antimatter I paired". This is the top of the inert band.
        uint256 minPhUSDOut = amount;

        vm.prank(user);
        antimatter.annihilate(address(usdc), user, amount, minPhUSDOut); // (1) NO REVERT

        // (2) The stablecoin is gone from the caller and sitting in the yield strategy.
        //     PhusdStableMinter exposes no redeem, burn or withdraw — this is irreversible.
        assertEq(usdc.balanceOf(user), 0, "caller's stablecoin is gone");
        assertEq(usdc.balanceOf(address(antimatter)), 0, "nothing left on Antimatter");
        assertEq(usdc.balanceOf(address(strategy)), stableAmount, "deposited into the yield strategy");
        assertEq(
            strategy.principal(address(usdc), address(minter)),
            stableAmount,
            "principal booked to the minter, not the caller"
        );

        // (3) The caller receives 160e18, not the 200e18 the 2x value proposition implies.
        //     The stablecoin half fetched 60e18 where 100e18 was expected.
        uint256 received = phUSD.balanceOf(user);
        assertEq(received, 160 ether, "100 AM half + 60 for the stable half");
        assertEq(antimatter.balanceOf(user), 0, "antimatter burned");
        assertEq(phUSD.balanceOf(address(antimatter)), 0, "nothing trapped");

        // The stablecoin half fetched 60 phUSD against the 100 it was worth at par: a 40%
        // shortfall on the half the floor exists to protect, which is 20% of the 200 phUSD
        // par total. Settled under a floor that was supposed to stop exactly this.
        uint256 par = 200 ether;
        uint256 stableHalfReceived = received - amount; // 60 ether
        assertEq(stableHalfReceived, 60 ether, "stable half fetched 60, not 100");
        assertEq((100 ether - stableHalfReceived) * 100 / 100 ether, 40, "40% shortfall on the stable half");
        assertLt(received, par, "caller settled short");
        assertEq((par - received) * 100 / par, 20, "20% shortfall against the par total");

        // And the floor was satisfied only because the antimatter half alone already covers it.
        assertGe(amount, minPhUSDOut, "the unconditional half alone clears the stated floor");
    }

    /// (4) CONTROL. The guard is not dead code, and the harness does reach it: one wei above
    ///     the antimatter half is the first floor that can ever bind, and it reverts with the
    ///     exact InsufficientPhUSDOut(minPhUSDOut, received) data.
    ///
    ///     Note the error shape is (minPhUSDOut, received) — NOT the old
    ///     PhUSDAmountMismatch(expected, received).
    function test_M07_control_amountPlusOneDoesRevert() public {
        uint256 amount = 100 ether;
        _fund(user, amount, usdc, 100e6);

        // Zero rate, so the stable half mints nothing: received == amount exactly.
        minter.updateExchangeRate(address(usdc), 0);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Antimatter.InsufficientPhUSDOut.selector, amount + 1, amount));
        antimatter.annihilate(address(usdc), user, amount, amount + 1);

        // Fully rolled back.
        assertEq(antimatter.balanceOf(user), amount, "burn rolled back");
        assertEq(usdc.balanceOf(user), 100e6, "stable untouched");
        assertEq(phUSD.totalSupply(), 0, "nothing minted");
    }

    /// (5) The end point of the inert band. At R = 0 the caller surrenders the stablecoin
    ///     half entirely for nothing, and a floor of `amount` still does not fire — a 50%
    ///     loss taken under a stated floor.
    function test_M07_zeroRateFloorAtAmountStillSettles() public {
        uint256 amount = 100 ether;
        _fund(user, amount, usdc, 100e6);

        minter.updateExchangeRate(address(usdc), 0);

        vm.prank(user);
        antimatter.annihilate(address(usdc), user, amount, amount); // no revert

        assertEq(phUSD.balanceOf(user), amount, "only the antimatter half");
        assertEq(usdc.balanceOf(user), 0, "the stable half was taken for nothing");
        assertEq(usdc.balanceOf(address(strategy)), 100e6, "and deposited irreversibly");
    }

    /// The whole band, swept: no floor in [0, amount] can ever revert, at any exchange rate.
    function test_M07_wholeBandIsInert(uint256 minPhUSDOut, uint256 rate) public {
        uint256 amount = 100 ether;
        minPhUSDOut = bound(minPhUSDOut, 0, amount);
        rate = bound(rate, 0, 2e18);

        _fund(user, amount, usdc, 100e6);
        minter.updateExchangeRate(address(usdc), rate);

        vm.prank(user);
        antimatter.annihilate(address(usdc), user, amount, minPhUSDOut); // never reverts

        assertGe(phUSD.balanceOf(user), amount, "the unconditional half always clears the band");
    }
}
