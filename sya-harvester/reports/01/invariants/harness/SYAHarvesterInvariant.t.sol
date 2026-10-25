// SPDX-License-Identifier: MIT
// AUDIT-AUTHORED (sya-harvester-01 invariant-generator). Not part of the upstream suite.
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SYAHarvester} from "../../../src/SYAHarvester.sol";
import {ICurveRouterNG} from "../../../src/interfaces/ICurveRouterNG.sol";
import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";
import {MockCurveRouter} from "../../mocks/MockCurveRouter.sol";
import {HarvestSystem, HarvestSystemHonest, HarvestSystemAdversarial} from "./HarvestSystem.sol";

abstract contract InvariantBase is Test {
    HarvestSystem internal sys;

    function _target() internal {
        targetContract(address(sys));
        bytes4[] memory sels = new bytes4[](8);
        sels[0] = HarvestSystem.act_harvest.selector;
        sels[1] = HarvestSystem.act_harvest.selector; // weight harvest x3
        sels[2] = HarvestSystem.act_harvest.selector;
        sels[3] = HarvestSystem.act_setYield.selector;
        sels[4] = HarvestSystem.act_setRoute.selector;
        sels[5] = HarvestSystem.act_donate.selector;
        sels[6] = HarvestSystem.act_shockRate.selector;
        sels[7] = HarvestSystem.act_setNftMode.selector;
        targetSelector(FuzzSelector({addr: address(sys), selectors: sels}));
        bytes4[] memory more = new bytes4[](2);
        more[0] = HarvestSystem.act_setOverEstimate.selector;
        more[1] = HarvestSystem.act_clearRoute.selector;
        targetSelector(FuzzSelector({addr: address(sys), selectors: more}));
    }

    function invariant_stateless() public view { assertEq(sys.v(sys.V_STATELESS()), 0, sys.lastViolationNote()); }
    function invariant_noStranding() public view { assertEq(sys.v(sys.V_STRANDED()), 0, sys.lastViolationNote()); }
    function invariant_minEthOut() public view { assertEq(sys.v(sys.V_MIN_ETH_OUT()), 0, sys.lastViolationNote()); }
    function invariant_v4DeltasZero() public view { assertEq(sys.v(sys.V_V4_DELTAS()), 0, sys.lastViolationNote()); }
    function invariant_conservation() public view { assertEq(sys.v(sys.V_CONSERVATION()), 0, sys.lastViolationNote()); }
    function invariant_syaPaymentExact() public view { assertEq(sys.v(sys.V_SYA_PAYMENT()), 0, sys.lastViolationNote()); }
    function invariant_allowancesReset() public view {
        assertEq(sys.v(sys.V_ALLOWANCE()), 0, sys.lastViolationNote());
        assertTrue(sys.noResidualAllowances(), "residual allowance");
    }
    function invariant_nft() public view { assertEq(sys.v(sys.V_NFT()), 0, sys.lastViolationNote()); }
    function invariant_routeRegistrySound() public view { assertTrue(sys.routeRegistrySound(), "stored route diverges from Router NG"); }
    function invariant_liveness_dust() public view { assertEq(sys.v(sys.L_DUST_GRIEF()), 0, "dust-grief revert (CODE-002)"); }
    function invariant_liveness_overDelivery() public view { assertEq(sys.v(sys.L_OVER_DELIVERY()), 0, "over-delivery revert (CODE-005)"); }
    function invariant_liveness_other() public view { assertEq(sys.v(sys.L_OTHER()), 0, "unexplained revert"); }
    function invariant_liveness_naturalDust() public view { assertEq(sys.v(sys.L_DUST_NATURAL()), 0, "natural sub-dust yield revert (CODE-002 natural variant)"); }

    /// Non-vacuity: harvests actually succeed in a campaign (logged by afterInvariant)
    function afterInvariant() public view {
        console2.log("harvestCalls", sys.harvestCalls());
        console2.log("harvestSuccesses", sys.harvestSuccesses());
        console2.log("harvestExpectedReverts", sys.harvestExpectedReverts());
    }
}

/// forge-config: default.invariant.fail-on-revert = false
contract HarvesterInvariantHonest is InvariantBase {
    function setUp() public {
        sys = new HarvestSystemHonest();
        _target();
    }
}

/// forge-config: default.invariant.fail-on-revert = false
contract HarvesterInvariantAdversarial is InvariantBase {
    function setUp() public {
        sys = new HarvestSystemAdversarial();
        _target();
    }
}

/// @notice Tripwires: prove each focus invariant CAN fail (anti-vacuity), and that the upstream
///         permissive MockCurveRouter could not have caught CODE-001.
contract HarvesterInvariantTripwires is Test {
    HarvestSystemAdversarial sys;

    function setUp() public {
        sys = new HarvestSystemAdversarial();
    }

    function test_tripwire_seededHarvestSucceedsCleanly() public {
        sys.act_harvest(0, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 1, "seeded harvest must succeed");
        for (uint256 i = 0; i < sys.N_GHOSTS(); i++) assertEq(sys.v(i), 0);
        assertTrue(sys.routeRegistrySound());
    }

    /// CODE-001 under Router NG semantics: gap route accepted, harvest SUCCEEDS, crvUSD stranded
    function test_tripwire_gapRoute_tripsStatelessAndRegistry() public {
        sys.strategies(0).set(50e18, 10000); // small USDe yield: other proceeds cover the borrow (as on fork)
        sys.act_setRoute(0, 2); // USDe shape 2: [USDe, pool, crvUSD, 0.., USDC@10]
        assertFalse(sys.routeRegistrySound(), "registry invariant must trip");
        sys.act_harvest(0, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 1, "harvest succeeds despite the gap (silent)");
        assertGt(sys.v(sys.V_STRANDED()), 0, "stranding invariant must trip");
        uint256 stranded = sys.crvusd().balanceOf(address(sys.harvester()));
        console2.log("crvUSD stranded in harvester", stranded);
        assertEq(stranded, 50e18, "whole USDe sale stranded as crvUSD");
    }

    /// Same gap route against the UPSTREAM MockCurveRouter: nothing is stranded, so a harness built
    /// on it is blind to CODE-001 (CODE-007(2)).
    function test_tripwire_upstreamMockRouterIsBlindToGap() public {
        MockCurveRouter mock = new MockCurveRouter();
        address usde = address(sys.usde());
        address usdc = address(sys.usdc());
        address[11] memory gap;
        gap[0] = usde;
        gap[1] = sys.POOL_USDE_CRV();
        gap[2] = address(sys.crvusd());
        gap[10] = usdc;
        mock.setRate(usde, 1e6);
        deal(usdc, address(mock), 1e12);
        deal(usde, address(this), 100e18);
        IERC20(usde).approve(address(mock), 100e18);
        uint256[5][5] memory p;
        address[5] memory pools;
        mock.exchange(gap, p, 100e18, 0, pools, address(this));
        assertEq(IERC20(usdc).balanceOf(address(this)), 100e6, "mock delivers USDC (wrong)");
        assertEq(sys.router().resolveOutput(gap), address(sys.crvusd()), "Router NG delivers crvUSD");
    }

    /// CODE-002: 1-wei donation of a non-delivering, routed token bricks harvest (router dust revert)
    function test_tripwire_dustDonation_tripsLiveness() public {
        sys.strategies(1).set(0, 10000); // DOLA strategy delivers nothing
        sys.act_donate(1, 4); // amount%4==0 -> 1 wei DOLA
        sys.act_harvest(0, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 0);
        assertGt(sys.v(sys.L_DUST_GRIEF()), 0, "dust liveness invariant must trip");
    }

    /// CODE-002 (a): unrouted dust -> RouteNotConfigured
    function test_tripwire_unroutedDust_tripsLiveness() public {
        sys.strategies(1).set(0, 10000);
        sys.act_clearRoute(1); // DOLA route cleared (no DOLA yield, so clearing is harmless by itself)
        sys.act_harvest(0, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 1, "baseline without dust succeeds");
        sys.strategies(0).set(1000e18, 10000);
        sys.strategies(2).set(200e6, 10000);
        sys.act_donate(1, 4);
        sys.act_harvest(0, 0, 0, true);
        assertGt(sys.v(sys.L_DUST_GRIEF()), 0, "RouteNotConfigured on dust must trip liveness");
    }

    /// CODE-005: a strategy delivering > estimate * 1.01 reverts on SYA's allowance pull
    function test_tripwire_overDelivery_tripsLiveness() public {
        sys.strategies(1).set(500e18, 10200); // DOLA delivers 2% more than reported (estimate)
        // Full claim: the 1% buffer is computed on the AGGREGATE estimate, so DOLA's +2% (~+9 USDC)
        // hides inside USDe+USDC headroom (1545.3 borrowed vs 1539 paid) -> succeeds.
        sys.act_harvest(0, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 1, "aggregate buffer absorbs single-strategy over-delivery");
        sys.strategies(0).set(1000e18, 10000);
        sys.strategies(1).set(500e18, 10200);
        sys.strategies(2).set(200e6, 10000);
        // DOLA-only claim (USDe + USDC exempt, mask 0b101): borrow 454.5, SYA pulls 459 -> allowance revert
        sys.act_harvest(0, 5, 0, true);
        assertGt(sys.v(sys.L_OVER_DELIVERY()), 0, "over-delivery liveness invariant must trip");
    }

    /// Under-delivery (USDe-like 75%) is SAFE: every safety invariant holds
    function test_underDelivery_safe() public {
        sys.strategies(0).set(1000e18, 7500);
        sys.act_harvest(1, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 1);
        for (uint256 i = 0; i < sys.N_GHOSTS(); i++) assertEq(sys.v(i), 0);
    }

    /// Non-vacuity: a 3000-step pseudo-random walk over the HONEST action set must produce many
    /// successful harvests (so the success-path invariants are actually exercised), with zero
    /// safety violations.
    function test_nonVacuity_randomWalk_honest() public {
        HarvestSystemHonest h = new HarvestSystemHonest();
        uint256 seed = 0xC0FFEE;
        for (uint256 i = 0; i < 3000; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            uint256 op = seed % 10;
            if (op < 4) h.act_harvest(uint8(seed >> 8), uint8(seed >> 16), seed >> 24, (seed >> 200) % 4 != 0);
            else if (op < 7) h.act_setYield(uint8(seed >> 8), seed >> 16, uint16(seed >> 100));
            else if (op == 7) h.act_setRoute(uint8(seed >> 8), uint8(seed >> 16));
            else if (op == 8) h.act_setOverEstimate(uint16(seed >> 8));
            else if ((seed >> 8) % 2 == 0) h.act_setNftMode((seed >> 9) % 2 == 0);
            else h.act_shockRate(uint8(seed >> 8), uint16(seed >> 16));
        }
        console2.log("calls", h.harvestCalls());
        console2.log("successes", h.harvestSuccesses());
        console2.log("expectedReverts", h.harvestExpectedReverts());
        for (uint256 i = 0; i < h.N_GHOSTS(); i++) console2.log("ghost", i, h.v(i));
        assertGe(h.harvestSuccesses(), 100, "success path must be exercised (>=100 successful harvests)");
        for (uint256 i = 0; i <= h.V_NFT(); i++) assertEq(h.v(i), 0, "safety ghost");
    }
}
