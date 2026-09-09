// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "@forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlaxToken} from "@phUSD/FlaxToken.sol";
import {IFlax} from "@phUSD/IFlax.sol";
import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";
import {Antimatter} from "../../../src/Antimatter.sol";
import {MockStable} from "../../mocks/MockStable.sol";
import {GuardedYieldStrategy} from "./AuditMocks.sol";
import {AntimatterHandler} from "./AntimatterHandler.sol";

/// @title Tier-3 stateful-fuzzing harness for Antimatter
/// @notice Real FlaxToken, real PhusdStableMinter, real ERC20 stables, a guarded yield
///         strategy that reverts on unauthorised / short / zero deposits, and a LIVE
///         maxMintPerDay cap on the minter. Nothing in the dependency chain is a
///         never-failing stub, so no invariant here can pass vacuously.
contract AntimatterInvariantTest is Test {
    Antimatter internal antimatter;
    FlaxToken internal phUSD;
    PhusdStableMinter internal minter;
    GuardedYieldStrategy internal strategy;
    MockStable internal usdc; // 6 decimals
    MockStable internal dola; // 18 decimals
    AntimatterHandler internal handler;

    address internal owner = address(0xA11CE);
    address[3] internal actors = [address(0xB0B), address(0xCA11), address(0xD00D)];

    uint256 internal constant CAP_PER_DAY = 10_000e18;

    function setUp() public {
        vm.warp(1_700_000_000);

        phUSD = new FlaxToken();
        minter = new PhusdStableMinter(address(phUSD));
        strategy = new GuardedYieldStrategy();
        usdc = new MockStable("USD Coin", "USDC", 6);
        dola = new MockStable("Dola", "DOLA", 18);
        antimatter = new Antimatter(owner);

        phUSD.setMinter(address(minter), true);
        phUSD.setMinter(address(antimatter), true);

        // Guarded strategy: only the minter may deposit. An unauthorised deposit reverts.
        strategy.setClient(address(minter), true);

        minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);
        minter.approveYS(address(usdc), address(strategy));
        minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);
        minter.approveYS(address(dola), address(strategy));

        // LIVE daily cap: the minter genuinely enforces this and reverts past it.
        minter.setMaxMintPerDay(address(usdc), CAP_PER_DAY);
        minter.setMaxMintPerDay(address(dola), CAP_PER_DAY);

        vm.startPrank(owner);
        antimatter.setPhUSD(IFlax(address(phUSD)));
        antimatter.setPhUSDMinter(minter);
        vm.stopPrank();

        // Seed real guarded state: every actor holds stablecoin and has approved Antimatter
        // for it (which annihilateFrom requires), plus a starting antimatter balance.
        for (uint256 i = 0; i < actors.length; i++) {
            usdc.mint(actors[i], 1_000_000e6);
            dola.mint(actors[i], 1_000_000e18);
            vm.startPrank(actors[i]);
            usdc.approve(address(antimatter), type(uint256).max);
            dola.approve(address(antimatter), type(uint256).max);
            vm.stopPrank();
            vm.prank(owner);
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
            3 * 5_000e18 // antimatter minted to the actors above
        );

        // Explicit selector list: only these six state transitions are fuzzed.
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = AntimatterHandler.mintAntimatter.selector;
        selectors[1] = AntimatterHandler.approveAntimatter.selector;
        selectors[2] = AntimatterHandler.transferAntimatter.selector;
        selectors[3] = AntimatterHandler.warp.selector;
        selectors[4] = AntimatterHandler.annihilateSelf.selector;
        selectors[5] = AntimatterHandler.annihilateOnBehalf.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    // ================================================================ tripwire

    /// @dev ABORT-ON-EMPTY. Runs after every completed sequence. If the fuzzer never landed a
    ///      single successful annihilation, every invariant below would have been checked
    ///      against a state no annihilation ever touched — i.e. vacuous. Fail loudly instead.
    function afterInvariant() public view {
        handler.callSummary();
        require(
            handler.totalAnnihilations() > 0,
            "VACUITY TRIPWIRE: no annihilateFrom succeeded in this run - the harness proved nothing"
        );
        require(
            handler.callsAnnihilateOnBehalf() > 0,
            "VACUITY TRIPWIRE: third-party path never attempted"
        );
    }

    // ============================================================ invariant 1
    // SETTLE-WHOLE-OR-NOT-AT-ALL.
    // At every reachable state, Antimatter holds zero stablecoin and zero phUSD, and the
    // antimatter destroyed by completed annihilations exactly equals the antimatter leg of
    // phUSD delivered. There is no state with antimatter burned but phUSD undelivered, nor
    // with stablecoin stranded on the contract.

    function invariant_01_noStableResidueOnAntimatter() public view {
        assertEq(usdc.balanceOf(address(antimatter)), 0, "USDC stranded on Antimatter");
        assertEq(dola.balanceOf(address(antimatter)), 0, "DOLA stranded on Antimatter");
    }

    function invariant_02_noPhusdResidueOnAntimatter() public view {
        assertEq(phUSD.balanceOf(address(antimatter)), 0, "phUSD stranded on Antimatter");
    }

    function invariant_03_burnImpliesDelivery() public view {
        assertEq(
            handler.ghostPhusdDeliveredAntimatterLeg(),
            handler.ghostAMBurnedInAnnihilation(),
            "antimatter burned without an equal antimatter-leg phUSD delivery"
        );
    }

    // ============================================================ invariant 2
    // BACKING ACCOUNTING.
    // phUSD total supply minus the stablecoin actually in custody (normalised to 18dp, held
    // as strategy principal) equals the cumulative antimatter burned. This is not a safety
    // assertion - it QUANTIFIES the uncollateralised leg: every unit of antimatter burned
    // mints exactly one unit of phUSD against zero collateral.

    function invariant_04_unbackedPhusdEqualsAntimatterBurned() public view {
        uint256 custody18 = strategy.totalPrincipal(address(usdc)) * 1e12 + strategy.totalPrincipal(address(dola));
        uint256 supply = phUSD.totalSupply();
        assertGe(supply, custody18, "phUSD supply below stablecoin custody");
        assertEq(
            supply - custody18,
            handler.ghostAMBurnedInAnnihilation(),
            "unbacked phUSD != cumulative antimatter burned"
        );
    }

    function invariant_05_stableCustodyMatchesPulled() public view {
        uint256 custody18 = strategy.totalPrincipal(address(usdc)) * 1e12 + strategy.totalPrincipal(address(dola));
        assertEq(custody18, handler.ghostStableInNormalised(), "stable pulled != stable in strategy custody");
    }

    // ============================================================ invariant 3
    // ALLOWANCE CONSERVATION (EXPECTED TO FAIL - CODE-001 tripwire).
    // No caller may cause a decrease in an address's STABLECOIN balance larger than what that
    // address approved TO THAT CALLER. A harness that does not break here is broken.

    function invariant_06_noStableSpentBeyondCallerAllowance() public view {
        assertEq(
            handler.ghostStableSpentWithoutCallerAllowance(),
            0,
            "CODE-001: caller moved stablecoin it was never approved for"
        );
    }

    function invariant_07_noValueRedirectedAwayFromOwner() public view {
        assertEq(
            handler.ghostPhusdRedirectedAwayFromOwner(),
            0,
            "CODE-001: phUSD proceeds of a holder's assets delivered to a caller-chosen third party"
        );
    }

    // ============================================================ invariant 4
    // NO BURN OUTSIDE ANNIHILATION.
    // Antimatter total supply only ever decreases through a completed annihilation.

    function invariant_08_supplyOnlyMovesViaMintAndAnnihilation() public view {
        assertEq(
            antimatter.totalSupply(),
            handler.ghostAMMinted() - handler.ghostAMBurnedInAnnihilation(),
            "antimatter supply moved outside mint()/annihilateFrom()"
        );
    }

    // ============================================================ invariant 5
    // DAILY-CAP HONESTY (EXPECTED TO FAIL - CODE-003, 2x).
    // phUSD issued per stable inside any rolling 24h window must not exceed maxMintPerDay.
    // The window here mirrors PhusdStableMinter.mint's own reset logic exactly.

    function invariant_09_dailyCapGovernsAllIssuance() public view {
        assertLe(handler.peakIssuedInWindow(address(usdc)), CAP_PER_DAY, "USDC: phUSD issued in 24h exceeded cap");
        assertLe(handler.peakIssuedInWindow(address(dola)), CAP_PER_DAY, "DOLA: phUSD issued in 24h exceeded cap");
    }

    function invariant_10_minterCapChargedForFullIssuance() public view {
        assertEq(
            handler.peakChargedInWindow(address(usdc)),
            handler.peakIssuedInWindow(address(usdc)),
            "USDC: minter cap charged for less than the phUSD actually issued"
        );
    }

    // ============================================================ reachability
    // A DETERMINISTIC proof that the handler can reach annihilateFrom on both paths, so a
    // fuzz campaign that reports zero successes is a fuzzer problem, not a harness problem.

    function test_handlerReachability() public {
        handler.mintAntimatter(0, 1_000e18);
        handler.annihilateSelf(0, 0, 100e18);
        assertGt(handler.okAnnihilateSelf(), 0, "self-annihilation path unreachable");

        handler.approveAntimatter(0, 1, 1_000e18);
        handler.annihilateOnBehalf(1, 0, 2, 1, 100e18);
        assertGt(handler.okAnnihilateOnBehalf(), 0, "third-party annihilation path unreachable");

        handler.callSummary();
    }

    // ======================================================= deterministic counterexamples
    // The invariant runner's shrinker is unreliable for CUMULATIVE ghosts (it reports a
    // 1-call sequence that cannot reproduce from the post-setUp state). These are hand-built,
    // fully replayable minimisations of the two invariant classes that broke.

    /// @dev Counterexample for invariant_06 / invariant_07 (CODE-001).
    ///      Sequence: [approve(AM, attacker, 100e18)] -> [annihilateFrom(usdc, victim, attacker, 100e18)]
    function test_counterexample_allowanceConservation() public {
        address victim = actors[0];
        address attacker = actors[1];

        uint256 victimUsdcBefore = usdc.balanceOf(victim);
        assertEq(usdc.allowance(victim, attacker), 0, "precondition: no stable allowance to attacker");

        vm.prank(victim);
        antimatter.approve(attacker, 100e18); // ANTIMATTER allowance only

        vm.prank(attacker);
        antimatter.annihilateFrom(address(usdc), victim, attacker, 100e18);

        assertEq(victimUsdcBefore - usdc.balanceOf(victim), 100e6, "victim's USDC moved");
        assertEq(usdc.allowance(victim, attacker), 0, "attacker never held a USDC allowance");
        assertEq(phUSD.balanceOf(attacker), 200e18, "attacker keeps the full 2x proceeds");
        assertEq(phUSD.balanceOf(victim), 0, "victim receives nothing");
    }

    /// @dev Counterexample for invariant_09 / invariant_10 (CODE-003).
    ///      One annihilation of 6,000 issues 12,000 phUSD against a 10,000 daily cap,
    ///      because only the stable leg is charged to the cap.
    function test_counterexample_dailyCapDoubled() public {
        address who = actors[0];
        vm.prank(owner);
        antimatter.mint(who, 6_000e18);

        vm.prank(who);
        antimatter.annihilateFrom(address(dola), who, who, 6_000e18);

        (,,,, uint256 maxMintPerDay, uint256 mintedToday,) = minter.stablecoinConfigs(address(dola));
        assertEq(maxMintPerDay, CAP_PER_DAY, "cap is live");
        assertEq(mintedToday, 6_000e18, "minter charged only the stable leg");
        assertEq(phUSD.balanceOf(who), 12_000e18, "12,000 phUSD issued under a 10,000 cap");
        assertGt(phUSD.balanceOf(who), maxMintPerDay, "issuance exceeded the configured daily cap");
    }

    /// @dev The invariant runner reports only OUTER reverts, and the handler swallows the
    ///      inner annihilateFrom revert by design (so a bad draw does not abort the sequence).
    ///      This drives the SAME handler through a long deterministic pseudo-random walk purely
    ///      to measure how often the settlement path actually lands vs reverts.
    function test_handlerRevertProfile() public {
        uint256 seed = uint256(keccak256("antimatter-tier3"));
        for (uint256 i = 0; i < 3000; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            uint256 pick = seed % 6;
            uint256 a = uint256(keccak256(abi.encode(seed, "a")));
            uint256 b = uint256(keccak256(abi.encode(seed, "b")));
            uint256 c = uint256(keccak256(abi.encode(seed, "c")));
            if (pick == 0) handler.mintAntimatter(a, b);
            else if (pick == 1) handler.approveAntimatter(a, b, c);
            else if (pick == 2) handler.transferAntimatter(a, b, c);
            else if (pick == 3) handler.warp(a);
            else if (pick == 4) handler.annihilateSelf(a, b, c);
            else handler.annihilateOnBehalf(a, b, c, seed, seed >> 8);
        }
        handler.callSummary();
        assertGt(handler.totalAnnihilations(), 0, "no annihilation landed in 3000 calls");
    }
}
