// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// run-35 AUDIT HARNESS (not sponsor code). Reuses the sponsor's story-092 fork-test harness.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {StableStakerV2} from "stable-staker/StableStakerV2.sol";
import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";
import {
    CutoverStableStakerV2MainnetForkTest,
    CutoverStableStakerV2MainnetHarness
} from "../CutoverStableStakerV2Mainnet.fork.t.sol";
import {ISourceDolaStrategy, IPausableLike} from "../../script/CutoverStableStakerV2Mainnet.s.sol";
import {InitiateDolaStrategyWithdrawalHarness} from "../InitiateDolaStrategyWithdrawal.fork.t.sol";

interface IStakerList {
    function stakerCount(address token) external view returns (uint256);
    function getStakersRange(address token, uint256 start, uint256 end) external view returns (address[] memory);
}

interface IStakerUser {
    function withdraw(address token, uint256 amount) external;
    function userInfo(address token, address user) external view returns (uint256, uint256);
}

contract CutoverAuditRun35 is CutoverStableStakerV2MainnetForkTest {
    uint256 constant FORK_BLOCK_35 = 25_990_689;
    address constant DOLA35 = 0x865377367054516e17014CcdED1e7d814EDC9ce4;
    address constant MINTER35 = 0x94855ACA13952D81507C92D3CdBb2e25D3bbE60C;
    address constant YS_DOLA35 = 0x1760E05356Ec1FBBA159C730781dCfB9920524e2;

    function _fork35() internal returns (bool) {
        string memory rpc = vm.envOr("RPC_MAINNET", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return false;
        }
        vm.createSelectFork(rpc, FORK_BLOCK_35);
        h = new CutoverStableStakerV2MainnetHarness();
        OWNER = h.OWNER();
        V1 = h.STABLE_STAKER_V1();
        PAUSER = h.PAUSER();
        _initiateMinterWithdrawal();
        _ageWithdrawal(6 hours + 60);
        return true;
    }

    /// OBS-35-04: session halts after Phase 6 (stakers migrated into a PAUSED V2) and the minter window lapses before
    /// Phase 6b executes. Every resume reverts in Phase 0 (the window gate runs before Phase 1..7), so V2 cannot be
    /// unpaused by the script; the only path is re-initiate + a fresh 6h wait. Migrated stakers cannot withdraw meanwhile.
    function test_R35_OBS04_windowLapseAfterPhase6_resumeBlocked_stakersFrozen() public {
        if (!_fork35()) return;
        _throughPhase6();
        StableStakerV2 v2 = h.v2();
        assertTrue(v2.paused(), "after Phase 6: V2 paused (Phase 7 unpauses it)");
        assertTrue(IPausableLike(V1).paused(), "after Phase 6: V1 paused");

        // Window lapses (halt outlives initiatedAt + 78h). Time moved by ageing initiatedAt, as the sponsor tests do.
        _ageWithdrawal(78 hours + 1);

        h.harnessResetTokens();
        vm.expectRevert(
            bytes(
                "Phase0: minter DOLA withdrawal window EXPIRED - run initiate-dola-ys-withdrawal:broadcast and wait (see dola-ys-withdrawal:status)"
            )
        );
        h.harnessPhase0(true);

        // A migrated V2 DOLA staker cannot withdraw while the cutover is stuck.
        address[] memory stakers = _v2DolaStakers(v2);
        assertGt(stakers.length, 0, "setup: V2 holds migrated DOLA stakers");
        (uint256 amt,) = IStakerUser(address(v2)).userInfo(DOLA35, stakers[0]);
        assertGt(amt, 0, "setup: staker has a V2 DOLA position");
        vm.prank(stakers[0]);
        vm.expectRevert();
        IStakerUser(address(v2)).withdraw(DOLA35, amt);

        // Remedy per runbook: re-initiate (allowed: lazily expired), then Phase 0 still refuses for 6h.
        InitiateDolaStrategyWithdrawalHarness init = new InitiateDolaStrategyWithdrawalHarness();
        init.run();
        (uint256 at,,) = ISourceDolaStrategy(YS_DOLA35).withdrawalStates(DOLA35, MINTER35);
        assertEq(at, block.timestamp, "re-initiated now");
        h.harnessResetTokens();
        vm.expectRevert();
        h.harnessPhase0(true);
        assertTrue(v2.paused(), "V2 still paused: stakers frozen for halt duration + >= 6h re-wait");
        console.log("R35|OBS04 re-initiated at / earliest resume:", at, at + 6 hours);
    }

    function _v2DolaStakers(StableStakerV2 v2) internal view returns (address[] memory out) {
        uint256 n = IStakerList(address(v2)).stakerCount(DOLA35);
        out = IStakerList(address(v2)).getStakersRange(DOLA35, 0, n);
    }
}
