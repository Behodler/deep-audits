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
    function invariant_routeAdmission() public view { assertEq(sys.v(sys.V_ROUTE_ADMISSION()), 0, sys.lastViolationNote()); }

    /// Non-vacuity: harvests actually succeed in a campaign (logged by afterInvariant)
    function afterInvariant() public view {
        console2.log("harvestCalls", sys.harvestCalls());
        console2.log("harvestSuccesses", sys.harvestSuccesses());
        console2.log("harvestExpectedReverts", sys.harvestExpectedReverts());
        console2.log("routeAccepted", sys.routeAccepted());
        console2.log("routeRejected", sys.routeRejected());
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

    /// CODE-001 / M-01 (run-01): the gap route that stranded crvUSD at 62c19c8 is now REJECTED at 6b862aa
    /// (InvalidRouteGap), and nothing is stored. run-02 fix confirmation at the harness level.
    function test_fixConfirm_gapRouteRejected() public {
        sys.strategies(0).set(50e18, 10000);
        sys.act_setRoute(0, 2); // USDe shape 2: [USDe, pool, crvUSD, 0.., USDC@10]
        assertEq(sys.routeRejected(), 1, "gap route rejected");
        assertEq(sys.v(sys.V_ROUTE_ADMISSION()), 0, sys.lastViolationNote());
        assertTrue(sys.routeRegistrySound(), "registry still sound (seed route kept)");
        assertEq(sys.harvester().getRoute(address(sys.usde())).path[1], sys.POOL_USDE_USDC(), "seed route untouched");
        sys.act_setRoute(0, 3);
        sys.act_setRoute(1, 4);
        assertEq(sys.routeRejected(), 3, "all three divergent shapes rejected");
        sys.act_harvest(0, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 1);
        assertEq(sys.crvusd().balanceOf(address(sys.harvester())), 0, "nothing stranded");
        for (uint256 i = 0; i < sys.N_GHOSTS(); i++) assertEq(sys.v(i), 0);
    }

    /// Anti-vacuity for the stranding ghost at 6b862aa: inject the run-01 gap route DIRECTLY into the
    /// harvester's storage (bypassing the new validator, i.e. the 62c19c8 mutant state) and show the
    /// stranding + registry invariants still trip. Proves their PASS at 6b862aa is not 0 == 0.
    function test_tripwire_injectedGapRoute_tripsStranding() public {
        SYAHarvester h = sys.harvester();
        address usde = address(sys.usde());
        // routes mapping is slot 1 (slot 0 = Ownable._owner); CurveRoute = path[11] @+0, swapParams @+11, pools @+36, configured @+41
        bytes32 base = keccak256(abi.encode(usde, uint256(1)));
        assertEq(address(uint160(uint256(vm.load(address(h), base)))), usde, "slot layout check: path[0]");
        assertEq(address(uint160(uint256(vm.load(address(h), bytes32(uint256(base) + 1))))), sys.POOL_USDE_USDC(), "slot layout check: path[1]");
        vm.store(address(h), bytes32(uint256(base) + 1), bytes32(uint256(uint160(sys.POOL_USDE_CRV()))));
        vm.store(address(h), bytes32(uint256(base) + 2), bytes32(uint256(uint160(address(sys.crvusd())))));
        vm.store(address(h), bytes32(uint256(base) + 10), bytes32(uint256(uint160(address(sys.usdc())))));
        assertEq(h.getRoute(usde).path[10], address(sys.usdc()), "injection took");
        assertFalse(sys.routeRegistrySound(), "registry invariant must trip");
        sys.strategies(0).set(50e18, 10000);
        sys.act_harvest(0, 0, 0, true);
        assertEq(sys.harvestSuccesses(), 1, "harvest succeeds despite the gap (silent)");
        assertGt(sys.v(sys.V_STRANDED()), 0, "stranding invariant must trip");
        assertEq(sys.crvusd().balanceOf(address(h)), 50e18, "whole USDe sale stranded as crvUSD");
    }

    /// run-01: the upstream MockCurveRouter delivered USDC for the gap route (blind to CODE-001).
    /// run-02 (6b862aa, stories 006/007): the upstream mock now models Router NG's first-empty-slot break
    /// and BadSwapType. Pin the new behaviour: with a real swap_type the mock now delivers crvUSD (faithful)
    /// and with swap_type 0 it reverts BadSwapType(0), as Router NG does.
    function test_upstreamMockRouter_nowFaithfulToGap() public {
        MockCurveRouter mock = new MockCurveRouter();
        address usde = address(sys.usde());
        address usdc = address(sys.usdc());
        address crv = address(sys.crvusd());
        address[11] memory gap;
        gap[0] = usde;
        gap[1] = sys.POOL_USDE_CRV();
        gap[2] = crv;
        gap[10] = usdc;
        mock.setRate(usde, 1e6);
        deal(usdc, address(mock), 1e12);
        deal(crv, address(mock), 1e30);
        deal(usde, address(this), 100e18);
        IERC20(usde).approve(address(mock), 100e18);
        uint256[5][5] memory p;
        address[5] memory pools;
        vm.expectRevert(abi.encodeWithSignature("BadSwapType(uint256)", 0));
        mock.exchange(gap, p, 100e18, 0, pools, address(this));
        p[0] = [uint256(0), 1, 1, 1, 2];
        try mock.exchange(gap, p, 100e18, 0, pools, address(this)) {
            assertEq(IERC20(usdc).balanceOf(address(this)), 0, "mock no longer delivers USDC for a gap route");
        } catch (bytes memory e) {
            console2.logBytes(e); // mock reverts on the gap: also faithful-enough (not silent USDC delivery)
            assertEq(IERC20(usdc).balanceOf(address(this)), 0);
        }
        assertEq(sys.router().resolveOutput(gap), crv, "Router NG delivers crvUSD");
        // CODE-02-001 test-fidelity pin: the upstream mock only rejects swap_type 0; swap_type 9 (which
        // Router NG v1.1 rejects "Bad swap type") is EXECUTED by the mock, so the upstream suite cannot see
        // the fail-loud harvest revert. Covered here by RouteDiff P4 against RouterNGv11Model instead.
        address[11] memory direct;
        direct[0] = usde;
        direct[1] = sys.POOL_USDE_USDC();
        direct[2] = usdc;
        uint256[5][5] memory p9;
        p9[0] = [uint256(0), 1, 9, 1, 2];
        deal(usde, address(this), 10e18);
        IERC20(usde).approve(address(mock), 10e18);
        uint256 out = mock.exchange(direct, p9, 10e18, 0, pools, address(this));
        assertEq(out, 10e6, "upstream mock executes swap_type 9 (Router NG v1.1 would revert)");
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
        console2.log("routeAccepted", h.routeAccepted());
        assertGe(h.harvestSuccesses(), 100, "success path must be exercised (>=100 successful harvests)");
        assertGt(h.routeAccepted(), 50, "setRoute must actually store routes in the walk");
        for (uint256 i = 0; i <= h.V_NFT(); i++) assertEq(h.v(i), 0, "safety ghost");
        assertEq(h.v(h.V_ROUTE_ADMISSION()), 0, "route admission ghost");
    }
}
