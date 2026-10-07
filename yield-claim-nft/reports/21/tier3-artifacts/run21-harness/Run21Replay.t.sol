// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// run-21 deterministic replays of the shrunk tripwire counterexamples, from a FRESH core.
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Run21Core, Run21CoreReal} from "./Run21Core.sol";
import {Run21CoreM1, Run21CoreM2, Run21CoreM3, Run21CoreM4} from "./Run21MutantCores.sol";

contract Run21Replay is Test {
    function _pairSynced(Run21Core c) internal view returns (bool) {
        (uint112 r0, uint112 r1,) = c.pair().getReserves();
        address t0 = c.pair().token0();
        uint256 b0 = (t0 == address(c.sUsds())) ? c.sUsds().balanceOf(address(c.pair())) : c.phusd().balanceOf(address(c.pair()));
        uint256 b1 = (t0 == address(c.sUsds())) ? c.phusd().balanceOf(address(c.pair())) : c.sUsds().balanceOf(address(c.pair()));
        console2.log("r0", r0, "b0", b0);
        console2.log("r1", r1, "b1", b1);
        return r0 == b0 && r1 == b1;
    }

    function test_freshSeedIsSynced() public {
        Run21Core c = new Run21CoreReal(true, 1_000_000e18, 1_050_000e18);
        assertTrue(_pairSynced(c), "seed leaves pair unsynced");
    }

    // Each tripwire: the same fixed sequence must BREAK the mutant and HOLD on the real contract.

    function _seqDonatePool(Run21Core c, bool sSide, uint256 d, uint256 aSeed, bool exact) internal {
        c.act_donate(sSide, d);
        c.act_pool(aSeed, exact);
    }

    function test_tripwire_M1_noSync_phusdDonation() public {
        Run21Core m = new Run21CoreM1(true, 1_000_000e18, 1_050_000e18);
        Run21Core r = new Run21CoreReal(true, 1_000_000e18, 1_050_000e18);
        // 0.5% phUSD donation, then zap the pooler's whole 1000 sUSDS with loose floors
        _seqDonatePool(m, false, 5_250e18 - 1, 1_000e18 - 1e12, false);
        _seqDonatePool(r, false, 5_250e18 - 1, 1_000e18 - 1e12, false);
        console2.log("M1 inv1Why:", m.inv1Why());
        assertFalse(m.ok_inv1(), "M1 must break INV1");
        assertTrue(r.ok_inv1() && r.ok_inv2(), "real holds");
    }

    function test_tripwire_M1_noSync_exactFloorsRevert() public {
        Run21Core m = new Run21CoreM1(true, 1_000_000e18, 1_050_000e18);
        Run21Core r = new Run21CoreReal(true, 1_000_000e18, 1_050_000e18);
        _seqDonatePool(m, false, 5_250e18 - 1, 1_000e18 - 1e12, true);
        _seqDonatePool(r, false, 5_250e18 - 1, 1_000e18 - 1e12, true);
        console2.log("M1 inv2Why:", m.inv2Why());
        assertFalse(m.ok_inv2(), "M1 must break INV2");
        assertTrue(r.ok_inv1() && r.ok_inv2(), "real holds");
    }

    function test_tripwire_M2_quoteReserves_sUSDSDonation() public {
        Run21Core m = new Run21CoreM2(true, 1_000_000e18, 1_050_000e18);
        Run21Core r = new Run21CoreReal(true, 1_000_000e18, 1_050_000e18);
        _seqDonatePool(m, true, 5_000e18 - 1, 1_000e18 - 1e12, true);
        _seqDonatePool(r, true, 5_000e18 - 1, 1_000e18 - 1e12, true);
        console2.log("M2 inv2Why:", m.inv2Why());
        assertFalse(m.ok_inv2(), "M2 must break INV2");
        assertTrue(r.ok_inv1() && r.ok_inv2(), "real holds");
    }

    function test_tripwire_M3_noHookGuard() public {
        Run21Core m = new Run21CoreM3(true, 1_000_000e18, 1_050_000e18);
        Run21Core r = new Run21CoreReal(true, 1_000_000e18, 1_050_000e18);
        m.act_setHook(0);
        m.act_mintIndex4();
        r.act_setHook(0);
        r.act_mintIndex4();
        console2.log("M3 inv3Why:", m.inv3Why());
        assertFalse(m.ok_inv3(), "M3 must break INV3");
        assertTrue(r.ok_inv3(), "real holds");
        assertEq(r.nMintGuardReverts(), 1, "real: guard revert observed");
        // documented escape hatch (story-051): a FRESH DefaultDispatchHook is not the guarded one
        r.act_setHook(2);
        r.act_mintIndex4();
        assertEq(r.nMintOkFreshDefault(), 1, "fresh DefaultDispatchHook bypasses the guard (accepted by story-051)");
    }

    function test_tripwire_M4_openRescue() public {
        Run21Core m = new Run21CoreM4(true, 1_000_000e18, 1_050_000e18);
        Run21Core r = new Run21CoreReal(true, 1_000_000e18, 1_050_000e18);
        m.act_attacker(0, 1e18);
        r.act_attacker(0, 1e18);
        console2.log("M4 inv4Why:", m.inv4Why());
        assertFalse(m.ok_inv4(), "M4 must break INV4");
        assertTrue(r.ok_inv4(), "real holds");
        assertEq(r.nAttackerSuccess(), 0);
    }
}
