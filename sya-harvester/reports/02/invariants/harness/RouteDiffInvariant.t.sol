// SPDX-License-Identifier: MIT
// AUDIT-AUTHORED (sya-harvester-02 invariant-generator). Not part of the upstream suite.
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SYAHarvester} from "../../../src/SYAHarvester.sol";
import {
    RouteDiffSystem,
    RouteDiffSystemReal,
    RouteDiffSystemMutantNoGap,
    RouteDiffSystemMutantNoEnd,
    RouteProbe
} from "./RouteDiffSystem.sol";
import {RouterNGv11Model, CurvePoolModel} from "./RouterNGv11Model.sol";
import {InvToken} from "./InvDoubles.sol";

abstract contract RouteDiffBase is Test {
    RouteDiffSystem internal sys;

    function _target() internal {
        targetContract(address(sys));
        bytes4[] memory s = new bytes4[](9);
        s[0] = RouteDiffSystem.act_setRouteFuzz.selector;
        s[1] = RouteDiffSystem.act_setRouteFuzz.selector;
        s[2] = RouteDiffSystem.act_setRouteFuzz.selector;
        s[3] = RouteDiffSystem.act_harvest.selector;
        s[4] = RouteDiffSystem.act_harvest.selector;
        s[5] = RouteDiffSystem.act_setYield.selector;
        s[6] = RouteDiffSystem.act_donate.selector;
        s[7] = RouteDiffSystem.act_clearRoute.selector;
        s[8] = RouteDiffSystem.act_setRouteBadSwapType.selector;
        targetSelector(FuzzSelector({addr: address(sys), selectors: s}));
    }

    function invariant_delivery() public view { assertEq(sys.v(sys.V_DELIVERY()), 0, sys.lastNote()); }
    function invariant_noResidue() public view {
        assertEq(sys.v(sys.V_RESIDUE()), 0, sys.lastNote());
        assertTrue(sys.residueClean(), "harvester balance != donations");
    }
    function invariant_specConformance() public view { assertEq(sys.v(sys.V_SPEC()), 0, sys.lastNote()); }
    function invariant_swapTypeFailLoud() public view { assertEq(sys.v(sys.V_SWAPTYPE()), 0, sys.lastNote()); }
    function invariant_storedEqualsInput() public view { assertEq(sys.v(sys.V_STORED()), 0, sys.lastNote()); }
    function invariant_ethPayout() public view { assertEq(sys.v(sys.V_ETH()), 0, sys.lastNote()); }

    function afterInvariant() public view {
        console2.log("routesAccepted", sys.routesAccepted());
        console2.log("routesRejected", sys.routesRejected());
        for (uint256 k = 0; k < 6; k++) console2.log("acceptedByK", k, sys.acceptedByK(k));
        console2.log("probesDelivered", sys.probesDelivered());
        console2.log("probesReverted", sys.probesReverted());
        console2.log("harvestCalls", sys.harvestCalls());
        console2.log("harvestOk", sys.harvestOk());
        console2.log("harvestOkFuzzedRoute", sys.harvestOkFuzzedRoute());
        console2.log("swapTypeChecks", sys.swapTypeChecks());
        console2.log("swapTypeHarvestReverts", sys.swapTypeHarvestReverts());
    }
}

/// forge-config: default.invariant.fail-on-revert = false
contract RouteDiffInvariantReal is RouteDiffBase {
    function setUp() public {
        sys = new RouteDiffSystemReal();
        _target();
    }
}

/// Mutation-kill campaigns: these are EXPECTED to fail (anti-vacuity). Run explicitly with --match-contract.
/// forge-config: default.invariant.fail-on-revert = false
contract RouteDiffInvariantMutantNoEnd is RouteDiffBase {
    function setUp() public {
        sys = new RouteDiffSystemMutantNoEnd();
        _target();
    }
}

/// forge-config: default.invariant.fail-on-revert = false
contract RouteDiffInvariantMutantNoGap is RouteDiffBase {
    function setUp() public {
        sys = new RouteDiffSystemMutantNoGap();
        _target();
    }
}

contract RouteDiffTripwires is Test {
    RouteDiffSystemReal sys;

    function setUp() public {
        sys = new RouteDiffSystemReal();
        // setUp non-vacuity: seed routes stored with the intended shape
        SYAHarvester h = sys.harvester();
        assertTrue(h.getRoute(address(sys.tok(1))).configured, "T route stored");
        assertTrue(h.getRoute(address(sys.tok(2))).configured, "U route stored");
        assertEq(h.getRoute(address(sys.tok(2))).path[4], address(sys.tok(0)), "U route 2-hop to R");
    }

    function _walk(RouteDiffSystem s, uint256 seed, uint256 steps) internal {
        for (uint256 i = 0; i < steps; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            uint256 op = seed % 20;
            if (op < 7) s.act_setRouteFuzz(uint8(seed >> 8), seed >> 16, (seed >> 250) % 4 != 0);
            else if (op < 13) s.act_harvest(uint8(seed >> 8), seed >> 16);
            else if (op < 16) s.act_setYield(uint8(seed >> 8), seed >> 16, uint16(seed >> 120));
            else if (op < 18) s.act_donate(uint8(seed >> 8), seed >> 16, (seed >> 251) % 2 == 0);
            else if (op == 18) s.act_clearRoute(uint8(seed >> 8));
            else s.act_setRouteBadSwapType(uint8(seed >> 8), seed >> 16, uint8(seed >> 100));
        }
    }

    function _log(RouteDiffSystem s) internal view {
        console2.log("accepted", s.routesAccepted(), "rejected", s.routesRejected());
        for (uint256 k = 0; k < 6; k++) console2.log("  acceptedByK", k, s.acceptedByK(k));
        console2.log("probesDelivered", s.probesDelivered(), "probesReverted", s.probesReverted());
        console2.log("harvestCalls", s.harvestCalls(), "harvestOk", s.harvestOk());
        console2.log("harvestOkFuzzedRoute", s.harvestOkFuzzedRoute());
        console2.log("swapTypeChecks", s.swapTypeChecks(), "swapTypeHarvestReverts", s.swapTypeHarvestReverts());
        for (uint256 i = 0; i < s.NV(); i++) console2.log("  violation", i, s.v(i));
        console2.log("lastNote", s.lastNote());
    }

    /// Non-vacuity of the REAL campaign: accepted routes of every hop count, probes that DELIVER, harvests
    /// that succeed through fuzzed (non-seed) routes, swap_type checks that ran; and zero violations.
    function test_nonVacuity_randomWalk_real() public {
        _walk(sys, 0xD1FF, 4000);
        _log(sys);
        assertGe(sys.routesAccepted(), 200, "accepted routes");
        for (uint256 k = 1; k <= 5; k++) assertGt(sys.acceptedByK(k), 0, "accepted route for every k in 1..5");
        assertGe(sys.probesDelivered(), 50, "probes that deliver");
        assertGe(sys.harvestOk(), 50, "successful harvests");
        assertGe(sys.harvestOkFuzzedRoute(), 20, "successful harvests through fuzzed routes");
        assertGe(sys.swapTypeHarvestReverts(), 5, "swap_type>=9 harvest reverts observed");
        for (uint256 i = 0; i < sys.NV(); i++) assertEq(sys.v(i), 0, "violation on real harvester");
        assertTrue(sys.residueClean());
    }

    /// Mutation kill (end check deleted): the same walk MUST produce delivery + residue violations.
    function test_mutantKill_noEnd() public {
        RouteDiffSystem m = new RouteDiffSystemMutantNoEnd();
        _walk(m, 0xD1FF, 4000);
        _log(m);
        assertGt(m.v(m.V_SPEC()), 0, "P3 kills noEnd");
        assertGt(m.v(m.V_DELIVERY()), 0, "P1 kills noEnd");
        assertGt(m.v(m.V_RESIDUE()), 0, "P2 kills noEnd (strand in harvester)");
    }

    /// Mutation (gap check deleted): P3 kills it; P1/P2 stay clean -> the gap check is hygiene, not safety,
    /// because InvalidRouteEnd already pins the ROUTER-delivered token path[2k].
    function test_mutant_noGap_isSafetyEquivalent() public {
        RouteDiffSystem m = new RouteDiffSystemMutantNoGap();
        _walk(m, 0xD1FF, 4000);
        _log(m);
        assertGt(m.v(m.V_SPEC()), 0, "P3 kills noGap");
        assertEq(m.v(m.V_DELIVERY()), 0, "noGap: delivery still holds");
        assertEq(m.v(m.V_RESIDUE()), 0, "noGap: no residue");
    }

    /// Deterministic: noEnd mutant accepts [T, P1, crvUSD] and the harvest strands crvUSD.
    function test_tripwire_noEnd_strands() public {
        RouteDiffSystem m = new RouteDiffSystemMutantNoEnd();
        address[11] memory p;
        p[0] = address(m.tok(1));
        p[1] = address(m.pools(1));
        p[2] = address(m.tok(3));
        uint256[5][5] memory sp;
        sp[0] = [uint256(0), 1, 1, 10, 2];
        address[5] memory pl;
        SYAHarvester h = m.harvester();
        address t = address(m.tok(1));
        vm.prank(address(m));
        h.setRoute(t, p, sp, pl);
        m.strategies(0).set(51e18, 5000); // small T yield (delivered 25.5e18) so R strategy + U cover the borrow
        m.act_harvest(0, 0);
        assertEq(m.harvestOk(), 1, "harvest succeeds");
        assertGt(m.v(m.V_RESIDUE()), 0, "residue tripwire");
        assertGt(IERC20(address(m.tok(3))).balanceOf(address(m.harvester())), 0, "crvUSD stranded");
    }

    /// Deterministic P4 / CODE-02-001: swap_type 9 accepted, probe and harvest revert Error("Bad swap type").
    function test_swapType9_acceptedThenFailLoud() public {
        sys.act_setRouteBadSwapType(0, 0, 0); // T route, row 0 swap_type 9
        assertEq(sys.v(sys.V_SWAPTYPE()), 0, sys.lastNote());
        assertEq(sys.swapTypeHarvestReverts(), 1);
        SYAHarvester.CurveRoute memory r = sys.harvester().getRoute(address(sys.tok(1)));
        assertEq(r.swapParams[0][2], 9, "stored with swap_type 9");
        assertTrue(sys.residueClean(), "nothing stranded");
        sys.act_setRouteBadSwapType(1, 2, 1); // U route, row 1 swap_type ~2^256
        assertEq(sys.v(sys.V_SWAPTYPE()), 0, sys.lastNote());
        assertEq(sys.swapTypeHarvestReverts(), 2);
    }

    /// k = 0 over-acceptance (profile routeValidator_acceptedEqualsExecutableSet): [R, 0 x10] for the reward
    /// token is accepted, the router cannot execute it (probe reverts), and harvest never executes it.
    function test_k0RewardRoute_acceptedNeverExecuted() public {
        SYAHarvester h = sys.harvester();
        address R = address(sys.tok(0));
        address[11] memory p;
        p[0] = R;
        uint256[5][5] memory sp;
        address[5] memory pl;
        vm.prank(address(sys));
        h.setRoute(R, p, sp, pl);
        assertTrue(h.getRoute(R).configured, "k=0 reward route stored");
        RouteProbe pr = new RouteProbe();
        InvToken(R).mint(address(pr), 1e6);
        (bool ok,,) = pr.run(sys.router(), h.getRoute(R), 1e6);
        assertFalse(ok, "Router NG cannot execute a k=0 route");
        sys.act_harvest(0, 0);
        assertEq(sys.harvestOk(), 1, "harvest skips the reward token (route never executed)");
        assertTrue(sys.residueClean());
    }

    /// Router model fidelity pins (each against the transcribed Vyper semantics).
    function test_model_fidelity() public {
        RouterNGv11Model r = sys.router();
        RouteProbe pr = new RouteProbe();
        address T = address(sys.tok(1));
        address R = address(sys.tok(0));
        SYAHarvester.CurveRoute memory c;
        c.path[0] = T;
        c.path[1] = address(sys.pools(0));
        c.path[2] = R;
        c.swapParams[0] = [uint256(0), 1, 1, 10, 2];
        InvToken(T).mint(address(pr), 10e18);
        (bool ok,, uint256 out) = pr.run(r, c, 1e18);
        assertTrue(ok);
        assertEq(out, 1e6 * 9996 / 10000 - 1, "amount -= 1 on delivery");
        // first-empty-pool-slot break: trailing entries are IGNORED and path[2] delivered
        c.path[5] = address(sys.pools(2));
        c.path[6] = address(sys.tok(3));
        (ok,, out) = pr.run(r, c, 1e18);
        assertTrue(ok, "router ignores entries after the first empty pool slot");
        c.path[5] = address(0);
        c.path[6] = address(0);
        // swap_type 0 and 9 -> Bad swap type
        c.swapParams[0][2] = 9;
        bytes memory e;
        (ok, e,) = pr.run(r, c, 1e18);
        assertFalse(ok);
        assertEq(keccak256(e), keccak256(abi.encodeWithSignature("Error(string)", "Bad swap type")));
        c.swapParams[0][2] = 0;
        (ok, e,) = pr.run(r, c, 1e18);
        assertEq(keccak256(e), keccak256(abi.encodeWithSignature("Error(string)", "Bad swap type")));
        // declared output != pool output -> Received nothing
        c.swapParams[0][2] = 1;
        c.path[2] = address(sys.tok(3));
        (ok, e,) = pr.run(r, c, 1e18);
        assertEq(keccak256(e), keccak256(abi.encodeWithSignature("Error(string)", "Received nothing")));
        // router as pool: __default__ accepts -> Received nothing
        c.path[1] = address(r);
        c.path[2] = R;
        (ok, e,) = pr.run(r, c, 1e18);
        assertEq(keccak256(e), keccak256(abi.encodeWithSignature("Error(string)", "Received nothing")));
        // codeless pool -> revert
        c.path[1] = sys.JUNK();
        (ok,,) = pr.run(r, c, 1e18);
        assertFalse(ok);
        // swap_type 4 fall-through (pool_type 1, n_coins 9): no call, Received nothing
        c.path[1] = address(sys.pools(0));
        c.swapParams[0] = [uint256(0), 1, 4, 1, 9];
        (ok, e,) = pr.run(r, c, 1e18);
        assertEq(keccak256(e), keccak256(abi.encodeWithSignature("Error(string)", "Received nothing")));
    }
}
