// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "@forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlaxToken} from "@phUSD/FlaxToken.sol";
import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";
import {Antimatter} from "../../../src/Antimatter.sol";
import {MockStable} from "../../mocks/MockStable.sol";

/// @dev Stateful-fuzzing handler for the Antimatter Tier-3 invariant campaign.
///      Every ghost variable here is written ONLY from an observed, successful state
///      transition (the low-level call returned true), never from an assumption.
contract AntimatterHandler is Test {
    Antimatter public immutable antimatter;
    FlaxToken public immutable phUSD;
    PhusdStableMinter public immutable minter;

    address[3] public actors;
    address[2] public stables;
    uint256[2] public scales; // 10 ** (18 - decimals)
    uint256 public immutable capPerDay;

    // ---------------------------------------------------------------- ghosts

    // call distribution
    uint256 public callsMintAM;
    uint256 public callsApproveAM;
    uint256 public callsTransferAM;
    uint256 public callsWarp;
    uint256 public callsAnnihilateSelf;
    uint256 public callsAnnihilateOnBehalf;

    uint256 public okAnnihilateSelf;
    uint256 public okAnnihilateOnBehalf;
    uint256 public revertsAnnihilateSelf;
    uint256 public revertsAnnihilateOnBehalf;

    // accounting ghosts
    uint256 public ghostAMMinted; // antimatter minted via mint()
    uint256 public ghostAMBurnedInAnnihilation; // antimatter burned by a COMPLETED annihilation
    uint256 public ghostPhusdDeliveredAntimatterLeg; // == amount, minted by Antimatter itself
    uint256 public ghostPhusdDeliveredStableLeg; // measured delta forwarded to recipient
    uint256 public ghostStableInNormalised; // stable pulled, rescaled to 18dp

    // invariant-3 ghosts (allowance conservation)
    uint256 public ghostStableSpentWithoutCallerAllowance;
    uint256 public ghostPhusdRedirectedAwayFromOwner;
    address public lastVictim;
    address public lastAttacker;
    address public lastRedirectRecipient;
    uint256 public lastUnauthorisedStableAmount;

    // invariant-5 ghosts (mirror of the minter's own rolling window, per stable)
    mapping(address => uint256) public windowStart;
    mapping(address => uint256) public issuedInWindow; // BOTH legs
    mapping(address => uint256) public chargedToMinterCap; // stable leg only
    mapping(address => uint256) public peakIssuedInWindow;
    mapping(address => uint256) public peakChargedInWindow;

    constructor(
        Antimatter _antimatter,
        FlaxToken _phUSD,
        PhusdStableMinter _minter,
        address[3] memory _actors,
        address[2] memory _stables,
        uint256[2] memory _scales,
        uint256 _capPerDay,
        uint256 _preMinted
    ) {
        antimatter = _antimatter;
        phUSD = _phUSD;
        minter = _minter;
        actors = _actors;
        stables = _stables;
        scales = _scales;
        capPerDay = _capPerDay;
        // Antimatter minted during the test's setUp, folded in at construction so that no
        // fuzzer-callable function can ever move this ghost (an earlier revision exposed a
        // seedMinted() setter and the fuzzer promptly called it, breaking invariant 08 with
        // a harness artefact rather than a contract defect).
        ghostAMMinted = _preMinted;
    }

    // ---------------------------------------------------------------- helpers

    function _actor(uint256 seed) internal view returns (address) {
        return actors[bound(seed, 0, 2)];
    }

    function _stableIdx(uint256 seed) internal pure returns (uint256) {
        return bound(seed, 0, 1);
    }

    /// @dev Amounts are always representable in BOTH stables (multiples of 1e12) so that
    ///      AmountNotRepresentable is not the dominant revert reason and the fuzzer actually
    ///      reaches the settlement path.
    function _amount(uint256 raw, uint256 ceiling) internal pure returns (uint256) {
        if (ceiling < 1e12) return 0;
        uint256 a = bound(raw, 1e12, ceiling);
        a = (a / 1e12) * 1e12;
        return a;
    }

    function _noteWindow(address stable, uint256 issuedBothLegs, uint256 chargedStableLeg) internal {
        // Mirrors PhusdStableMinter.mint's rolling-window reset exactly.
        if (block.timestamp >= windowStart[stable] + 1 days) {
            windowStart[stable] = block.timestamp;
            issuedInWindow[stable] = 0;
            chargedToMinterCap[stable] = 0;
        }
        issuedInWindow[stable] += issuedBothLegs;
        chargedToMinterCap[stable] += chargedStableLeg;
        if (issuedInWindow[stable] > peakIssuedInWindow[stable]) {
            peakIssuedInWindow[stable] = issuedInWindow[stable];
        }
        if (chargedToMinterCap[stable] > peakChargedInWindow[stable]) {
            peakChargedInWindow[stable] = chargedToMinterCap[stable];
        }
    }

    // ---------------------------------------------------------------- actions

    function mintAntimatter(uint256 actorSeed, uint256 amountSeed) public {
        callsMintAM++;
        address to = _actor(actorSeed);
        uint256 amount = _amount(amountSeed, 5_000e18);
        if (amount == 0) return;
        vm.prank(antimatter.owner());
        antimatter.mint(to, amount);
        ghostAMMinted += amount;
    }

    function approveAntimatter(uint256 fromSeed, uint256 spenderSeed, uint256 amountSeed) public {
        callsApproveAM++;
        address from = _actor(fromSeed);
        address spender = _actor(spenderSeed);
        if (from == spender) return;
        uint256 amount = bound(amountSeed, 0, 10_000e18);
        vm.prank(from);
        antimatter.approve(spender, amount);
    }

    function transferAntimatter(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) public {
        callsTransferAM++;
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) return;
        uint256 bal = antimatter.balanceOf(from);
        if (bal == 0) return;
        uint256 amount = bound(amountSeed, 1, bal);
        vm.prank(from);
        antimatter.transfer(to, amount);
    }

    function warp(uint256 dtSeed) public {
        callsWarp++;
        vm.warp(block.timestamp + bound(dtSeed, 1 hours, 30 hours));
    }

    /// @dev The ordinary path: the holder annihilates their own position.
    function annihilateSelf(uint256 actorSeed, uint256 stableSeed, uint256 amountSeed) public {
        callsAnnihilateSelf++;
        address who = _actor(actorSeed);
        uint256 si = _stableIdx(stableSeed);
        address stable = stables[si];
        uint256 amount = _amount(amountSeed, antimatter.balanceOf(who));
        if (amount == 0) return;
        _doAnnihilate(who, who, who, stable, si, amount, false);
    }

    /// @dev The third-party path: `caller` spends an ANTIMATTER allowance granted by `from`,
    ///      and names an arbitrary `recipient`.
    function annihilateOnBehalf(
        uint256 callerSeed,
        uint256 fromSeed,
        uint256 recipientSeed,
        uint256 stableSeed,
        uint256 amountSeed
    ) public {
        callsAnnihilateOnBehalf++;
        address caller = _actor(callerSeed);
        address from = _actor(fromSeed);
        address recipient = _actor(recipientSeed);
        if (caller == from) return;

        uint256 si = _stableIdx(stableSeed);
        address stable = stables[si];

        uint256 ceiling = antimatter.balanceOf(from);
        uint256 allowanceAM = antimatter.allowance(from, caller);
        if (allowanceAM < ceiling) ceiling = allowanceAM;
        uint256 amount = _amount(amountSeed, ceiling);
        if (amount == 0) return;

        _doAnnihilate(caller, from, recipient, stable, si, amount, true);
    }

    // ---------------------------------------------------------------- core

    function _doAnnihilate(
        address caller,
        address from,
        address recipient,
        address stable,
        uint256 si,
        uint256 amount,
        bool onBehalf
    ) internal {
        uint256 stableAmount = amount / scales[si];

        // Pre-images, measured on chain.
        uint256 fromStableBefore = IERC20(stable).balanceOf(from);
        uint256 recipientPhusdBefore = phUSD.balanceOf(recipient);
        uint256 amSupplyBefore = antimatter.totalSupply();
        // How much of `from`'s stablecoin has `from` authorised THE CALLER to move?
        uint256 stableAllowanceToCaller = caller == from ? type(uint256).max : IERC20(stable).allowance(from, caller);

        vm.prank(caller);
        (bool ok,) = address(antimatter).call(
            abi.encodeCall(Antimatter.annihilateFrom, (stable, from, recipient, amount))
        );

        if (!ok) {
            if (onBehalf) revertsAnnihilateOnBehalf++;
            else revertsAnnihilateSelf++;
            return;
        }

        if (onBehalf) okAnnihilateOnBehalf++;
        else okAnnihilateSelf++;

        uint256 stableSpent = fromStableBefore - IERC20(stable).balanceOf(from);
        uint256 phusdGained = phUSD.balanceOf(recipient) - recipientPhusdBefore;
        uint256 amBurned = amSupplyBefore - antimatter.totalSupply();

        ghostAMBurnedInAnnihilation += amBurned;
        ghostStableInNormalised += stableSpent * scales[si];
        ghostPhusdDeliveredAntimatterLeg += amount;
        ghostPhusdDeliveredStableLeg += (phusdGained >= amount ? phusdGained - amount : 0);

        // Invariant-3 bookkeeping: did the caller move stablecoin it was never approved for?
        if (stableSpent > stableAllowanceToCaller) {
            ghostStableSpentWithoutCallerAllowance += stableSpent - stableAllowanceToCaller;
            lastVictim = from;
            lastAttacker = caller;
            lastRedirectRecipient = recipient;
            lastUnauthorisedStableAmount = stableAmount;
        }
        if (recipient != from) {
            ghostPhusdRedirectedAwayFromOwner += phusdGained;
        }

        _noteWindow(stable, phusdGained, phusdGained >= amount ? phusdGained - amount : 0);
    }

    // ---------------------------------------------------------------- reporting

    function totalAnnihilations() public view returns (uint256) {
        return okAnnihilateSelf + okAnnihilateOnBehalf;
    }

    function callSummary() public view {
        console.log("--- handler call distribution (this run) ---");
        console.log("mintAntimatter        :", callsMintAM);
        console.log("approveAntimatter     :", callsApproveAM);
        console.log("transferAntimatter    :", callsTransferAM);
        console.log("warp                  :", callsWarp);
        console.log("annihilateSelf calls  :", callsAnnihilateSelf);
        console.log("annihilateSelf ok     :", okAnnihilateSelf);
        console.log("annihilateSelf revert :", revertsAnnihilateSelf);
        console.log("onBehalf calls        :", callsAnnihilateOnBehalf);
        console.log("onBehalf ok           :", okAnnihilateOnBehalf);
        console.log("onBehalf revert       :", revertsAnnihilateOnBehalf);
        console.log("AM minted             :", ghostAMMinted);
        console.log("AM burned (annihil.)  :", ghostAMBurnedInAnnihilation);
        console.log("stable in (18dp)      :", ghostStableInNormalised);
        console.log("phUSD out AM leg      :", ghostPhusdDeliveredAntimatterLeg);
        console.log("phUSD out stable leg  :", ghostPhusdDeliveredStableLeg);
        console.log("unauthorised stable   :", ghostStableSpentWithoutCallerAllowance);
    }
}
