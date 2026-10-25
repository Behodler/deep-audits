// SPDX-License-Identifier: MIT
// AUDIT-AUTHORED (sya-harvester-01, M-01 / sh1m1 / 004d4547d9). Not part of the upstream suite.
pragma solidity 0.8.26;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SYAHarvester} from "../src/SYAHarvester.sol";
import {SYAHarvesterForkTest} from "./fork/SYAHarvester.fork.t.sol";
import {MainnetAddresses as A} from "./fork/MainnetAddresses.sol";
import {MainnetRoutes} from "./fork/MainnetRoutes.sol";

interface INFTMinterOwnable {
    function owner() external view returns (address);
    function setAuthorizedMinter(address minter, bool authorized) external;
    function mintFor(uint256 index, address recipient) external;
}

/// @title M-01 PoC: setRoute accepts a gapped Curve route; Router NG stops at the first empty pool slot,
///        so harvest() succeeds while the USDe leg's proceeds are stranded in the harvester as crvUSD.
/// @dev Vulnerable code: src/SYAHarvester.sol setRoute (route-end check: "last non-zero entry of path ==
///      rewardToken"), versus Curve Router NG `exchange`, which breaks out of its hop loop at the first
///      `route[i*2+1] == address(0)` and pays out `route[i*2]` (the intermediate token) to the receiver.
///      Inherits the project's own mainnet fork fixture (test/fork/SYAHarvester.fork.t.sol, PINNED_BLOCK
///      26261000, MainnetRoutes.configure, keeper with the claim NFT, 1h accrual warp).
///      Run: MAINNET_RPC_URL=<archive rpc> forge test --match-path test/poc-M-01-gap-route-strand.t.sol -vvv
contract M01PoCTest is SYAHarvesterForkTest {
    bytes32 internal constant TRANSFER_SIG = keccak256("Transfer(address,address,uint256)");

    /// @dev The mis-entered route: USDe -> [USDe/crvUSD pool] -> crvUSD -> <missing crvUSD/USDC pool> ... USDC.
    ///      USDC (the SYA reward token) is the last non-zero entry, so setRoute's validator accepts it.
    function _gapPath() internal pure returns (address[11] memory gap) {
        gap[0] = A.USDE;
        gap[1] = MainnetRoutes.POOL_USDE_CRVUSD;
        gap[2] = A.CRVUSD;
        // gap[3] = address(0): the second pool slot is empty (unset variable / typo)
        gap[10] = A.USDC;
    }

    function _setGapRoute() internal {
        MainnetRoutes.Route memory u = MainnetRoutes.usdeRoute();
        vm.prank(owner);
        harvester.setRoute(A.USDE, _gapPath(), u.swapParams, u.pools); // (1) does NOT revert
    }

    /// @dev Harvest with recorded logs; returns ETH paid to the keeper and the amounts Router NG transferred
    ///      to the harvester in USDC and crvUSD during this harvest.
    function _harvestRecorded()
        internal
        returns (uint256 ethOut, uint256 usdcFromRouter, uint256 crvUsdFromRouter, uint256 usdcTransfersFromRouter)
    {
        return _harvestRecorded(_none());
    }

    function _harvestRecorded(address[] memory exempt)
        internal
        returns (uint256 ethOut, uint256 usdcFromRouter, uint256 crvUsdFromRouter, uint256 usdcTransfersFromRouter)
    {
        vm.txGasPrice(0); // isolate the value effect from the gas-profitability gate
        vm.recordLogs();
        uint256 balBefore = keeper.balance;
        vm.prank(keeper, keeper);
        uint256 ret = harvester.harvest(exempt, A.NFT_INDEX, 0); // (2) succeeds (would revert otherwise)
        ethOut = keeper.balance - balBefore;
        assertEq(ret, ethOut, "harvest return == ETH received");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory l = logs[i];
            if (l.topics.length != 3 || l.topics[0] != TRANSFER_SIG) continue;
            if (address(uint160(uint256(l.topics[1]))) != A.CURVE_ROUTER_NG) continue;
            if (address(uint160(uint256(l.topics[2]))) != address(harvester)) continue;
            uint256 amt = abi.decode(l.data, (uint256));
            if (l.emitter == A.USDC) {
                usdcFromRouter += amt;
                usdcTransfersFromRouter++;
            } else if (l.emitter == A.CRVUSD) {
                crvUsdFromRouter += amt;
            }
        }
    }

    /// @notice Headline PoC: gapped route accepted, harvest succeeds, USDe leg delivers 0 USDC, crvUSD is
    ///         stranded and accumulates over repeated harvests, and the caller is paid less than the control.
    function test_M01_gapRoute_strandsCrvUsd_andUnderpaysCaller() public {
        uint256 yieldUsde = sya.getYield(A.YS_USDE);
        assertGt(yieldUsde, 0, "precondition: USDe strategy has yield to claim");

        // ---------------- CONTROL: correct contiguous route (as shipped by MainnetRoutes.configure)
        uint256 snap = vm.snapshotState();
        (uint256 ethControl, uint256 usdcControl, uint256 crvControl, uint256 nUsdcControl) = _harvestRecorded();
        assertEq(nUsdcControl, 2, "control: router pays USDC to harvester for BOTH legs (USDe + DOLA)");
        assertEq(crvControl, 0, "control: router never pays crvUSD to the harvester");
        assertEq(IERC20(A.CRVUSD).balanceOf(address(harvester)), 0, "control: 0 crvUSD left in harvester");
        assertEq(IERC20(A.USDE).balanceOf(address(harvester)), 0, "control: 0 USDe left in harvester");
        vm.revertToState(snap);

        // ---------------- EXPLOITED: owner mis-enters the USDe route with a gap; the validator accepts it
        _setGapRoute();
        (address[11] memory stored,,) = _storedRoute(A.USDE);
        assertEq(stored[3], address(0), "stored route has the empty middle pool slot");
        assertEq(stored[10], A.USDC, "stored route ends (last non-zero) at USDC");

        (uint256 ethGap, uint256 usdcGap, uint256 crvGap, uint256 nUsdcGap) = _harvestRecorded();

        // (3) the USDe leg delivered 0 USDC: only the DOLA leg's USDC transfer remains
        assertEq(nUsdcGap, 1, "gap: router pays USDC for the DOLA leg only, 0 USDC for the USDe leg");
        assertLt(usdcGap, usdcControl, "gap: less USDC delivered than control");
        assertGt(crvGap, 0, "gap: router paid the intermediate token (crvUSD) instead");

        // (4) the crvUSD is stranded in the harvester (not a strategy token, no sweep)
        uint256 stranded1 = IERC20(A.CRVUSD).balanceOf(address(harvester));
        assertEq(stranded1, crvGap, "gap: every crvUSD the router paid is still held by the harvester");
        assertGt(stranded1, 0, "gap: crvUSD stranded after harvest #1");
        assertEq(IERC20(A.USDE).balanceOf(address(harvester)), 0, "gap: USDe was sold (SYA paid for it)");

        // (5) the caller paid SYA for the USDe yield and was paid less ETH than the control
        assertLt(ethGap, ethControl, "gap: caller ETH out < control ETH out");
        uint256 lossWei = ethControl - ethGap;

        console2.log("USDe strategy yield claimed (1e18)      ", yieldUsde);
        console2.log("control ETH to caller (wei)             ", ethControl);
        console2.log("gap     ETH to caller (wei)             ", ethGap);
        console2.log("caller loss (wei)                       ", lossWei);
        console2.log("control USDC router->harvester (1e6)    ", usdcControl);
        console2.log("gap     USDC router->harvester (1e6)    ", usdcGap);
        console2.log("crvUSD stranded after harvest #1 (1e18) ", stranded1);

        // ---------------- second round: loss repeats and accumulates, harvest still succeeds
        vm.warp(block.timestamp + ACCRUAL_WARP);
        vm.roll(block.number + ACCRUAL_WARP / 12);
        _giveKeeperAnotherNft();
        assertGt(sya.getYield(A.YS_USDE), 0, "round 2: USDe strategy accrued new yield");
        // The USDC strategy is exempted in round 2 only because its Tokemak autoUSD withdrawal reads a
        // Chainlink crvUSD/USD feed that goes stale once the fork is warped further (InvalidDataReturned) --
        // a fork artifact documented in SYAHarvesterForkTest.ACCRUAL_WARP, unrelated to this finding. The
        // DOLA leg still covers the borrow, exactly the "other proceeds cover owed" precondition.
        (uint256 ethGap2,, uint256 crvGap2, uint256 nUsdcGap2) = _harvestRecorded(_one(A.YS_USDC));
        assertEq(nUsdcGap2, 1, "round 2: USDe leg again delivers 0 USDC");
        assertGt(crvGap2, 0, "round 2: router again pays crvUSD");
        uint256 stranded2 = IERC20(A.CRVUSD).balanceOf(address(harvester));
        assertEq(stranded2, stranded1 + crvGap2, "round 2: stranded crvUSD accumulates, nothing recovers it");
        assertGt(stranded2, stranded1, "round 2: stranded balance grew");
        console2.log("round-2 ETH to caller (wei)             ", ethGap2);
        console2.log("crvUSD stranded after harvest #2 (1e18) ", stranded2);
    }

    /// @notice Contrast: the correct contiguous route leaves zero crvUSD in the harvester (story-002 acceptance).
    function test_M01_control_contiguousRoute_leavesNoCrvUsd() public {
        (,, uint256 crv, uint256 nUsdc) = _harvestRecorded();
        assertEq(nUsdc, 2, "both legs delivered USDC");
        assertEq(crv, 0, "no crvUSD delivered to harvester");
        _assertHarvesterEmpty();
    }

    /// @notice The validator's actual contract: the gap route is accepted, while a route whose last non-zero
    ///         entry is the intermediate is rejected — i.e. the check guards the wrong end.
    function test_M01_validator_acceptsGap_rejectsHonestWrongEnd() public {
        MainnetRoutes.Route memory u = MainnetRoutes.usdeRoute();
        address[11] memory wrongEnd;
        wrongEnd[0] = A.USDE;
        wrongEnd[1] = MainnetRoutes.POOL_USDE_CRVUSD;
        wrongEnd[2] = A.CRVUSD; // executes identically to the gap route
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, A.USDC, A.CRVUSD));
        harvester.setRoute(A.USDE, wrongEnd, u.swapParams, u.pools);

        _setGapRoute(); // same executed route, padded with a trailing USDC -> accepted
        (address[11] memory stored,,) = _storedRoute(A.USDE);
        assertEq(stored[10], A.USDC);
    }

    /// @dev Round 2 needs a second claim NFT unit (round 1 burned the only one). Uses the fork fixture's
    ///      documented "method 2": the NFT minter's owner authorizes a minter, which calls mintFor.
    function _giveKeeperAnotherNft() internal {
        address nftOwner = INFTMinterOwnable(A.NFT_MINTER).owner();
        vm.prank(nftOwner);
        INFTMinterOwnable(A.NFT_MINTER).setAuthorizedMinter(address(this), true);
        INFTMinterOwnable(A.NFT_MINTER).mintFor(A.NFT_INDEX, keeper);
        assertEq(nft.balanceOf(keeper, A.NFT_INDEX), 1, "keeper holds a fresh claim NFT");
    }

    function _storedRoute(address token)
        internal
        view
        returns (address[11] memory path, uint256[5][5] memory swapParams, address[5] memory pools)
    {
        SYAHarvester.CurveRoute memory r = harvester.getRoute(token);
        return (r.path, r.swapParams, r.pools);
    }
}
