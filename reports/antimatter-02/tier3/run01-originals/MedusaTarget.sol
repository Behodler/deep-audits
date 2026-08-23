// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vm} from "@forge-std/Vm.sol";
import {FlaxToken} from "@phUSD/FlaxToken.sol";
import {IFlax} from "@phUSD/IFlax.sol";
import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";
import {Antimatter} from "../../../src/Antimatter.sol";
import {MockStable} from "../../mocks/MockStable.sol";
import {GuardedYieldStrategy} from "./AuditMocks.sol";
import {AntimatterHandler} from "./AntimatterHandler.sol";

/// @title Medusa assertion-mode target for the Antimatter Tier-3 campaign
/// @notice Medusa fuzzes the functions of the contract it deploys, so a Foundry
///         `targetContract(handler)` harness is invisible to it — pointing Medusa at the
///         Foundry test contract makes it fuzz `setUp()`/`excludeSenders()` and report a
///         meaningless all-green. This contract has a no-arg constructor, builds the exact
///         same system, forwards the six fuzzable state transitions to the SAME handler, and
///         re-states the invariants as `assert`s so Medusa's assertion mode can break them.
contract MedusaAntimatterTarget {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    Antimatter public antimatter;
    FlaxToken public phUSD;
    PhusdStableMinter public minter;
    GuardedYieldStrategy public strategy;
    MockStable public usdc;
    MockStable public dola;
    AntimatterHandler public handler;

    address public constant OWNER = address(0xA11CE);
    uint256 public constant CAP_PER_DAY = 10_000e18;

    address[3] public actors = [address(0xB0B), address(0xCA11), address(0xD00D)];

    constructor() {
        phUSD = new FlaxToken();
        minter = new PhusdStableMinter(address(phUSD));
        strategy = new GuardedYieldStrategy();
        usdc = new MockStable("USD Coin", "USDC", 6);
        dola = new MockStable("Dola", "DOLA", 18);
        antimatter = new Antimatter(OWNER);

        phUSD.setMinter(address(minter), true);
        phUSD.setMinter(address(antimatter), true);
        strategy.setClient(address(minter), true);

        minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);
        minter.approveYS(address(usdc), address(strategy));
        minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);
        minter.approveYS(address(dola), address(strategy));
        minter.setMaxMintPerDay(address(usdc), CAP_PER_DAY);
        minter.setMaxMintPerDay(address(dola), CAP_PER_DAY);

        vm.startPrank(OWNER);
        antimatter.setPhUSD(IFlax(address(phUSD)));
        antimatter.setPhUSDMinter(minter);
        vm.stopPrank();

        for (uint256 i = 0; i < actors.length; i++) {
            usdc.mint(actors[i], 1_000_000e6);
            dola.mint(actors[i], 1_000_000e18);
            vm.startPrank(actors[i]);
            usdc.approve(address(antimatter), type(uint256).max);
            dola.approve(address(antimatter), type(uint256).max);
            vm.stopPrank();
            vm.prank(OWNER);
            antimatter.mint(actors[i], 5_000e18);
        }

        handler = new AntimatterHandler(
            antimatter,
            phUSD,
            minter,
            actors,
            [address(usdc), address(dola)],
            [uint256(1e12), uint256(1)],
            CAP_PER_DAY,
            3 * 5_000e18
        );
    }

    // ------------------------------------------------------------- fuzz actions

    function mintAntimatter(uint256 a, uint256 b) external {
        handler.mintAntimatter(a, b);
    }

    function approveAntimatter(uint256 a, uint256 b, uint256 c) external {
        handler.approveAntimatter(a, b, c);
    }

    function transferAntimatter(uint256 a, uint256 b, uint256 c) external {
        handler.transferAntimatter(a, b, c);
    }

    function warp(uint256 a) external {
        handler.warp(a);
    }

    function annihilateSelf(uint256 a, uint256 b, uint256 c) external {
        handler.annihilateSelf(a, b, c);
    }

    function annihilateOnBehalf(uint256 a, uint256 b, uint256 c, uint256 d, uint256 e) external {
        handler.annihilateOnBehalf(a, b, c, d, e);
    }

    // --------------------------------------------------------------- invariants
    // Same statements as the Foundry harness, re-expressed as asserts.

    function check_01_noStableResidueOnAntimatter() external view {
        assert(usdc.balanceOf(address(antimatter)) == 0);
        assert(dola.balanceOf(address(antimatter)) == 0);
    }

    function check_02_noPhusdResidueOnAntimatter() external view {
        assert(phUSD.balanceOf(address(antimatter)) == 0);
    }

    function check_03_burnImpliesDelivery() external view {
        assert(handler.ghostPhusdDeliveredAntimatterLeg() == handler.ghostAMBurnedInAnnihilation());
    }

    function check_04_unbackedPhusdEqualsAntimatterBurned() external view {
        uint256 custody18 = strategy.totalPrincipal(address(usdc)) * 1e12 + strategy.totalPrincipal(address(dola));
        uint256 supply = phUSD.totalSupply();
        assert(supply >= custody18);
        assert(supply - custody18 == handler.ghostAMBurnedInAnnihilation());
    }

    function check_05_stableCustodyMatchesPulled() external view {
        uint256 custody18 = strategy.totalPrincipal(address(usdc)) * 1e12 + strategy.totalPrincipal(address(dola));
        assert(custody18 == handler.ghostStableInNormalised());
    }

    function check_06_noStableSpentBeyondCallerAllowance() external view {
        assert(handler.ghostStableSpentWithoutCallerAllowance() == 0);
    }

    function check_07_noValueRedirectedAwayFromOwner() external view {
        assert(handler.ghostPhusdRedirectedAwayFromOwner() == 0);
    }

    function check_08_supplyOnlyMovesViaMintAndAnnihilation() external view {
        assert(antimatter.totalSupply() == handler.ghostAMMinted() - handler.ghostAMBurnedInAnnihilation());
    }

    function check_09_dailyCapGovernsAllIssuance() external view {
        assert(handler.peakIssuedInWindow(address(usdc)) <= CAP_PER_DAY);
        assert(handler.peakIssuedInWindow(address(dola)) <= CAP_PER_DAY);
    }

    function check_10_minterCapChargedForFullIssuance() external view {
        assert(handler.peakChargedInWindow(address(usdc)) == handler.peakIssuedInWindow(address(usdc)));
    }

    // ----------------------------------------------------------------- tripwire

    /// @dev ABORT-ON-EMPTY. Medusa has no afterInvariant hook, so this is exposed as an
    ///      ordinary fuzz action: once the campaign has run any appreciable number of
    ///      sequences without a single successful annihilation, it trips. Reading a Medusa
    ///      "all passed" without this failing first would be reading a vacuous result.
    function vacuityTripwire() external view {
        if (handler.callsAnnihilateSelf() + handler.callsAnnihilateOnBehalf() >= 25) {
            assert(handler.totalAnnihilations() > 0);
        }
    }
}
