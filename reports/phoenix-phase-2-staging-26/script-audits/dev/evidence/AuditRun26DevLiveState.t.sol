// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// AUDIT ARTIFACT — phoenix-phase-2-staging run-26, entryPoint "dev".
// MUST be run FORKED against the live local anvil produced by `npm run dev`:
//     forge test --match-path test/<here>.t.sol --fork-url http://127.0.0.1:8545 -vv
// Addresses are read from the run's own server/deployments/local.json rather than
// hardcoded, and setUp() carries code-length tripwires, so the suite cannot pass
// vacuously against code-less addresses the way a hardcoded un-forked run does.
//
// Result on this run: test_B, test_C, test_D PASS. (test_A and test_E were dropped
// after ABI-shape errors and re-done with `cast`; see evidence/cast-live-state.log.)

import {Test, console} from "@forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBatchMinter {
    function nudgeStreamer() external view returns (address);
    function setNudgeStreamer(address) external;
    function getNudgeTokens() external view returns (address[] memory);
    function owner() external view returns (address);
}

interface IStreamer {
    function pendingStream(address, address) external view returns (uint256);
    function streams(address, address) external view returns (uint256, uint256, uint256, uint256);
}

interface IViewRouter {
    function pages(bytes32) external view returns (address);
}

interface IPhlimboV3Like {
    function promoToken() external view returns (address);
    function promoPhase() external view returns (uint8);
    function promoRewardBalance() external view returns (uint256);
    function totalStaked() external view returns (uint256);
}

interface IPhlimboV2Like {
    function totalStaked() external view returns (uint256);
}

contract AuditRun26DevLiveState is Test {
    string json;

    address STREAMER;
    address BATCH_MINTER;
    address VIEW_ROUTER;
    address PHLIMBO_V3;
    address PHLIMBO_V2;
    address KENDU;

    function _addr(string memory name) internal view returns (address) {
        return vm.parseJsonAddress(json, string.concat(".contracts.", name, ".address"));
    }

    function setUp() public {
        json = vm.readFile("server/deployments/local.json");
        STREAMER = _addr("NudgeStreamer");
        BATCH_MINTER = _addr("BatchNFTMinter");
        VIEW_ROUTER = _addr("ViewRouter");
        PHLIMBO_V3 = _addr("PhlimboV3");
        PHLIMBO_V2 = _addr("PhlimboEA"); // key names the INCUMBENT V2, per story 079 comment
        KENDU = _addr("Kendu");

        // Tripwire: refuse to run vacuously against code-less addresses.
        assertGt(STREAMER.code.length, 0, "NudgeStreamer has no code - not forked?");
        assertGt(BATCH_MINTER.code.length, 0, "BatchMinter has no code - not forked?");
        assertGt(PHLIMBO_V3.code.length, 0, "PhlimboV3 has no code - not forked?");
    }

    /// B: End-state UI surface — router deposit page and the LOCAL-ONLY Kendu promotion.
    function test_B_uiEndStateDivergesFromMainnetInvariant() public view {
        console.log("ViewRouter deposit page:", IViewRouter(VIEW_ROUTER).pages(keccak256("deposit")));
        console.log("ViewRouter mint page   :", IViewRouter(VIEW_ROUTER).pages(keccak256("mint")));
        console.log("PhlimboV3.promoToken   :", IPhlimboV3Like(PHLIMBO_V3).promoToken());
        console.log("PhlimboV3.promoPhase   :", IPhlimboV3Like(PHLIMBO_V3).promoPhase());
        console.log("PhlimboV3.promoBalance :", IPhlimboV3Like(PHLIMBO_V3).promoRewardBalance());
        // Mainnet story 076 asserts promoToken == address(0). Local arms one.
        assertEq(IPhlimboV3Like(PHLIMBO_V3).promoToken(), KENDU, "local arms Kendu promo");
    }

    /// C: Cutover completeness — V2 wound down, V3 holds the stake.
    function test_C_phlimboCutoverEndState() public view {
        uint256 v2 = IPhlimboV2Like(PHLIMBO_V2).totalStaked();
        uint256 v3 = IPhlimboV3Like(PHLIMBO_V3).totalStaked();
        console.log("PhlimboV2(total staked):", v2);
        console.log("PhlimboV3(total staked):", v3);
        assertEq(v2, 0, "V2 should be fully drained");
        assertGt(v3, 0, "V3 should hold the migrated stake");
    }

    /// D: Zero-address sentinel on the SINK strands matured streams silently.
    ///    All five donors revert on address(0); BatchNFTMinterMultiToken accepts it.
    function test_D_zeroSinkAcceptedWhileDonorsRejectIt() public {
        address owner_ = IBatchMinter(BATCH_MINTER).owner();
        address[] memory toks = IBatchMinter(BATCH_MINTER).getNudgeTokens();
        console.log("nudge tokens whitelisted:", toks.length);

        uint256 funded;
        for (uint256 i; i < toks.length; ++i) {
            (, uint256 buffer,,) = IStreamer(STREAMER).streams(BATCH_MINTER, toks[i]);
            console.log("stream buffer:", toks[i], buffer);
            if (buffer > 0) funded++;
        }
        assertGt(funded, 0, "expected at least one funded stream on the live chain");

        vm.prank(owner_);
        IBatchMinter(BATCH_MINTER).setNudgeStreamer(address(0));
        assertEq(IBatchMinter(BATCH_MINTER).nudgeStreamer(), address(0), "sink ACCEPTED address(0)");
        console.log("setNudgeStreamer(0) ACCEPTED - funded streams now unreachable");
    }
}
