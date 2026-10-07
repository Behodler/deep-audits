// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// run-21 Foundry invariant suites over Run21Core. Real: A (sUSDS=token0, ~1:1.05, deep) and
// B (sUSDS=token1, skewed 10:1, shallow). Tripwires: MutM1..MutM4 (config A) - each must FAIL
// its targeted invariant, otherwise the real-suite pass is not evidence.

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Run21Core, Run21CoreReal} from "./Run21Core.sol";
import {Run21CoreM1, Run21CoreM2, Run21CoreM3, Run21CoreM4} from "./Run21MutantCores.sol";

abstract contract Run21InvBase is Test {
    Run21Core internal core;

    function _deploy() internal virtual returns (Run21Core);

    function setUp() public {
        core = _deploy();
        targetContract(address(core));
        bytes4[] memory s = new bytes4[](11);
        s[0] = Run21Core.act_pool.selector;
        s[1] = Run21Core.act_mintIndex4.selector;
        s[2] = Run21Core.act_setHook.selector;
        s[3] = Run21Core.act_ownerRescueLP.selector;
        s[4] = Run21Core.act_seedPooler.selector;
        s[5] = Run21Core.act_donate.selector;
        s[6] = Run21Core.act_swap.selector;
        s[7] = Run21Core.act_skim.selector;
        s[8] = Run21Core.act_sync.selector;
        s[9] = Run21Core.act_attacker.selector;
        s[10] = Run21Core.act_pool.selector; // weight the keeper zap x2
        targetSelector(FuzzSelector({addr: address(core), selectors: s}));
    }

    function invariant_INV1_L25_noStrand() public view {
        assertTrue(core.ok_inv1(), core.inv1Why());
    }

    /// @dev Diagnostic (stricter than INV1): the repo's own absolute wei bound, no 1e-12 term.
    function invariant_INV1b_repoAbsoluteDustBound() public view {
        assertEq(core.zapsAboveRepoAbsTol(), 0, core.firstAbsBreach());
    }

    function invariant_INV2_quoteExecuteConsistent() public view {
        assertTrue(core.ok_inv2(), core.inv2Why());
    }

    function invariant_INV3_L21_hookGuard() public view {
        assertTrue(core.ok_inv3(), core.inv3Why());
    }

    function invariant_INV4_lpNoLeak() public view {
        assertTrue(core.ok_inv4(), core.inv4Why());
    }

    /// @dev Non-vacuity gate, evaluated after EVERY run: each run must have executed at least one
    ///      successful (non-reverting) keeper pool(), one with exact quote floors, and one index-4 mint.
    function afterInvariant() public view {
        assertGt(core.nPoolOk(), 0, "VACUOUS: no successful pool() in this run");
        assertGt(core.nPoolExactOk(), 0, "VACUOUS: no exact-floor pool() in this run");
        assertGt(core.nMintCalls(), 0, "VACUOUS: no index-4 mint attempt in this run");
        console2.log("STATS poolCalls", core.nPoolCalls(), "poolOk", core.nPoolOk());
        console2.log("STATS poolExactOk", core.nPoolExactOk(), "poolAfterUnsynced", core.nPoolAfterUnsynced());
        console2.log("STATS poolSkipped", core.nPoolSkipped(), "mintCalls", core.nMintCalls());
        console2.log("STATS mintOk", core.nMintOk(), "mintGuardReverts", core.nMintGuardReverts());
        console2.log("STATS mintOkFreshDefault", core.nMintOkFreshDefault(), "hookToggles", core.nHookToggles());
        console2.log("STATS donations", core.nDonations(), "swaps", core.nSwaps());
        console2.log("STATS skims", core.nSkims(), "syncs", core.nSyncs());
        console2.log("STATS ownerRescues", core.nOwnerRescues(), "seedPooler", core.nSeedPooler());
        console2.log("STATS attackerAttempts", core.nAttackerAttempts(), "attackerSuccess", core.nAttackerSuccess());
        console2.log("STATS maxResidS", core.maxResidS(), "maxResidP", core.maxResidP());
        console2.log("STATS zapsAboveNaive2Wei", core.zapsAboveNaive2Wei(), "lpFloor", core.lpFloor());
        console2.log("STATS zapsAboveRepoAbsTol", core.zapsAboveRepoAbsTol());
        console2.log("STATS worstZap", core.worstZap());
    }
}

contract Run21InvRealA is Run21InvBase {
    function _deploy() internal override returns (Run21Core) {
        return new Run21CoreReal(true, 1_000_000e18, 1_050_000e18);
    }
}

contract Run21InvRealB is Run21InvBase {
    function _deploy() internal override returns (Run21Core) {
        return new Run21CoreReal(false, 20_000e18, 2_000e18);
    }
}

contract Run21MutM1NoSync is Run21InvBase {
    function _deploy() internal override returns (Run21Core) {
        return new Run21CoreM1(true, 1_000_000e18, 1_050_000e18);
    }
}

contract Run21MutM2QuoteReserves is Run21InvBase {
    function _deploy() internal override returns (Run21Core) {
        return new Run21CoreM2(true, 1_000_000e18, 1_050_000e18);
    }
}

contract Run21MutM3NoHookGuard is Run21InvBase {
    function _deploy() internal override returns (Run21Core) {
        return new Run21CoreM3(true, 1_000_000e18, 1_050_000e18);
    }
}

contract Run21MutM4OpenRescue is Run21InvBase {
    function _deploy() internal override returns (Run21Core) {
        return new Run21CoreM4(true, 1_000_000e18, 1_050_000e18);
    }
}
