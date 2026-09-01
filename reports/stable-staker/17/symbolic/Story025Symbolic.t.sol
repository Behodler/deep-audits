// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

/**
 * Symbolic model of the story-025 additions to src/StableStakerV2.sol.
 *
 * The bodies below are transcribed VERBATIM from the contract; only the surrounding
 * storage reads/external calls are replaced by symbolic parameters. Every constant
 * matches the contract (EXIT_ROUNDING_ALLOWANCE = 2, EXIT_ROUNDING_ALLOWANCE_BPS = 1,
 * MAX_BPS = 10_000).
 */
contract ExitMath {
    uint256 public constant EXIT_ROUNDING_ALLOWANCE = 2;
    uint256 public constant EXIT_ROUNDING_ALLOWANCE_BPS = 1;
    uint256 private constant MAX_BPS = 10_000;

    /// @dev StableStakerV2.sol:587-589, verbatim, returning the require's predicate.
    function floorCheckPasses(uint256 netFloor, uint256 received) public pure returns (bool) {
        uint256 allowance = EXIT_ROUNDING_ALLOWANCE + (netFloor * EXIT_ROUNDING_ALLOWANCE_BPS) / MAX_BPS;
        uint256 floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0;
        return (received > 0 && received >= floorWithAllowance);
    }
}

contract Story025Symbolic is Test {
    ExitMath m;

    // Haircut is expressed in HUNDREDTHS of a basis point: f = 100 is exactly 1 bp,
    // f = 47 / f = 54 are the two fork-measured autopool haircuts, f = 500 is the 5 bp control.
    uint256 private constant HB = 1_000_000; // denominator for hundredths-of-a-bp

    function setUp() public {
        m = new ExitMath();
    }

    // ================= PROPERTY 1: no-brick on the exit floor =================
    // Wired DIRECT strategy => grossQuote == netQuote == netWanted, and (netWanted <= user.amount)
    // => gross == grossQuote => netFloor == netQuote * gross / grossQuote == netWanted.
    // So netFloor is the full symbolic quantity and the only remaining freedom is the
    // realised haircut. `received = netFloor - floor(netFloor * f / 1e6)` models a
    // proportional, round-down-in-protocol-favour delivery shortfall of f/100 bps.

    /// @notice P1a: at ANY haircut at or below 1.00 bp, :589 cannot revert.
    function check_noBrickAtOrBelow1bp(uint256 netFloor, uint256 f) public view {
        vm.assume(netFloor > 0);
        vm.assume(netFloor < 2 ** 128); // no uint256 overflow in netFloor * f; far above any token supply
        vm.assume(f <= 100); // <= 1.00 bp

        uint256 received = netFloor - (netFloor * f) / HB;
        assert(m.floorCheckPasses(netFloor, received));
    }

    /// @notice P1b: the crossing point. At 1.01 bp a reverting netFloor EXISTS.
    ///         Expected outcome: FAIL, i.e. Halmos hands back the witness.
    function check_crossing_101_hundredthsBp(uint256 netFloor) public view {
        vm.assume(netFloor > 0);
        vm.assume(netFloor < 2 ** 128);
        uint256 f = 101; // 1.01 bp
        uint256 received = netFloor - (netFloor * f) / HB;
        assert(m.floorCheckPasses(netFloor, received));
    }

    /// @notice P1c: 5 bp control - must FAIL (fork control says the check fires here).
    function check_control_5bp(uint256 netFloor) public view {
        vm.assume(netFloor > 0);
        vm.assume(netFloor < 2 ** 128);
        uint256 received = netFloor - (netFloor * 500) / HB;
        assert(m.floorCheckPasses(netFloor, received));
    }

    /// @notice P1d: the exact tolerance identity - the check passes iff the absolute
    ///         shortfall is within 2 + netFloor/10000. Establishes the crossing formula
    ///         f_crit(N) = 1 bp + 20000/N hundredths-of-a-bp.
    function check_toleranceIsExactly2PlusOneBp(uint256 netFloor, uint256 received) public view {
        vm.assume(netFloor > 0 && netFloor < 2 ** 128);
        vm.assume(received > 0 && received <= netFloor);
        uint256 shortfall = netFloor - received;
        bool within = shortfall <= 2 + netFloor / 10_000;
        assert(m.floorCheckPasses(netFloor, received) == within);
    }


    // --- P1a fallback: `f` CONCRETE, so only one symbolic-numerator division remains
    //     (netFloor * <const> / 1e6) alongside the constant-divisor netFloor/10000.
    function _noBrickAt(uint256 netFloor, uint256 f) internal view {
        vm.assume(netFloor > 0);
        vm.assume(netFloor < 2 ** 128);
        uint256 received = netFloor - (netFloor * f) / HB;
        assert(m.floorCheckPasses(netFloor, received));
    }

    function check_noBrick_at_0bp(uint256 netFloor) public view { _noBrickAt(netFloor, 0); }
    function check_noBrick_at_047bp(uint256 netFloor) public view { _noBrickAt(netFloor, 47); }
    function check_noBrick_at_054bp(uint256 netFloor) public view { _noBrickAt(netFloor, 54); }
    function check_noBrick_at_090bp(uint256 netFloor) public view { _noBrickAt(netFloor, 90); }
    function check_noBrick_at_100bp(uint256 netFloor) public view { _noBrickAt(netFloor, 100); }


    /// @notice P1a, exactly 1.00 bp, restated with the single constant divisor 10_000
    ///         (100/1e6 == 1/1e4 exactly), to keep it to one division.
    function check_noBrick_at_100bp_exact(uint256 netFloor) public view {
        vm.assume(netFloor > 0);
        vm.assume(netFloor < 2 ** 128);
        uint256 received = netFloor - netFloor / 10_000;
        assert(m.floorCheckPasses(netFloor, received));
    }

    function check_noBrick_at_099bp(uint256 netFloor) public view { _noBrickAt(netFloor, 99); }

    // ================= PROPERTY 2: emission conservation =================
    // :539-548 (owed / capped / netWanted / excessBase / carriedDust) plus :595-599
    // (annihilatable / excess). scale is CONCRETE per decimal case.

    function _conservation(uint256 owed, uint256 amount, uint256 received, uint256 scale) internal pure {
        uint256 principalAsAntimatter = amount * scale;
        uint256 capped = owed < principalAsAntimatter ? owed : principalAsAntimatter;
        uint256 netWanted = capped / scale;
        uint256 excessBase = owed - capped;
        vm.assume(netWanted > 0 || excessBase > 0); // :546
        uint256 carriedDust = capped - netWanted * scale; // :548

        uint256 netUsed = received < netWanted ? received : netWanted; // :590
        uint256 annihilatable = netUsed * scale; // :595
        uint256 excess = excessBase + (netWanted - netUsed) * scale; // :598

        // Nothing is created and nothing is destroyed: every unit of `owed` is either
        // annihilated, minted as excess, or carried as sub-unit dust.
        assert(annihilatable + excess + carriedDust == owed);
        // Dust is strictly sub-unit, so it can never hide a whole payable unit.
        assert(carriedDust < scale);
    }

    /// @notice P2a: 18-decimal pool (scale == 1).
    function check_emissionConservation_18dec(uint256 owed, uint256 amount, uint256 received) public pure {
        vm.assume(owed < 2 ** 200);
        vm.assume(amount < 2 ** 200);
        _conservation(owed, amount, received, 1);
    }

    /// @notice P2b: 6-decimal pool (scale == 1e12) - the case where dust is non-trivial.
    function check_emissionConservation_6dec(uint256 owed, uint256 amount, uint256 received) public pure {
        vm.assume(owed < 2 ** 200);
        vm.assume(amount < 2 ** 160); // amount * 1e12 cannot overflow
        _conservation(owed, amount, received, 1e12);
    }

    // ================= PROPERTY 3: the netWanted == 0 boundary =================

    /// @notice P3: after the :546 require, netWanted == 0 implies user.amount == 0.
    ///         Refutes any path where the :557 escape (`netWanted == 0 || grossQuote > 0`)
    ///         lets a zero-net exit proceed while principal is still staked.
    function check_zeroNetImpliesZeroPrincipal(uint256 owed, uint256 amount, uint256 scale) public pure {
        vm.assume(scale >= 1 && scale <= 1e18);
        vm.assume(amount < 2 ** 128);
        vm.assume(owed < 2 ** 200);
        unchecked {
            vm.assume(amount == 0 || (amount * scale) / scale == amount); // no overflow
        }
        uint256 principalAsAntimatter = amount * scale;
        uint256 capped = owed < principalAsAntimatter ? owed : principalAsAntimatter;
        uint256 netWanted = capped / scale;
        uint256 excessBase = owed - capped;
        vm.assume(netWanted > 0 || excessBase > 0); // :546

        if (netWanted == 0) {
            assert(amount == 0);
        }
    }

    /// @notice P3b: same, with scale concrete at 1e12 (6-decimal pools) - the fallback
    ///         if the symbolic-divisor form above is intractable.
    function check_zeroNetImpliesZeroPrincipal_6dec(uint256 owed, uint256 amount) public pure {
        vm.assume(amount < 2 ** 160);
        vm.assume(owed < 2 ** 200);
        uint256 principalAsAntimatter = amount * 1e12;
        uint256 capped = owed < principalAsAntimatter ? owed : principalAsAntimatter;
        uint256 netWanted = capped / 1e12;
        uint256 excessBase = owed - capped;
        vm.assume(netWanted > 0 || excessBase > 0);
        if (netWanted == 0) {
            assert(amount == 0);
        }
    }

    // --- P2b split: the two :543 branches proved separately, tighter bounds, one
    //     assertion per test, to cut the path/query product that timed out.

    /// @dev Branch A: reward outran principal (capped == principalAsAntimatter).
    function check_conserve_6dec_branchA(uint256 owed, uint256 amount, uint256 received) public pure {
        vm.assume(amount > 0 && amount < 2 ** 96);
        vm.assume(owed < 2 ** 160);
        uint256 P = amount * 1e12;
        vm.assume(owed >= P); // capped == P
        uint256 capped = P;
        uint256 netWanted = capped / 1e12; // == amount, exactly
        uint256 excessBase = owed - capped;
        uint256 carriedDust = capped - netWanted * 1e12;
        uint256 netUsed = received < netWanted ? received : netWanted;
        uint256 annihilatable = netUsed * 1e12;
        uint256 excess = excessBase + (netWanted - netUsed) * 1e12;
        assert(annihilatable + excess + carriedDust == owed);
    }

    /// @dev Branch B: principal covers the reward (capped == owed). This is the only
    ///      branch where carriedDust can be non-zero.
    function check_conserve_6dec_branchB(uint256 owed, uint256 amount, uint256 received) public pure {
        vm.assume(amount > 0 && amount < 2 ** 96);
        vm.assume(owed < 2 ** 160);
        uint256 P = amount * 1e12;
        vm.assume(owed < P); // capped == owed
        uint256 capped = owed;
        uint256 netWanted = capped / 1e12;
        vm.assume(netWanted > 0);
        uint256 carriedDust = capped - netWanted * 1e12;
        uint256 netUsed = received < netWanted ? received : netWanted;
        uint256 annihilatable = netUsed * 1e12;
        uint256 excess = (netWanted - netUsed) * 1e12; // excessBase == 0 here
        assert(annihilatable + excess + carriedDust == owed);
    }

    /// @dev The dust bound, isolated: the carry is always strictly sub-unit.
    function check_dustIsSubUnit_6dec(uint256 capped) public pure {
        vm.assume(capped < 2 ** 160);
        uint256 netWanted = capped / 1e12;
        assert(capped - netWanted * 1e12 < 1e12);
    }

    function check_dustIsSubUnit_6dec_b64(uint256 capped) public pure {
        vm.assume(capped < 2 ** 64);
        uint256 netWanted = capped / 1e12;
        assert(capped - netWanted * 1e12 < 1e12);
    }

    function check_dustIsSubUnit_6dec_b96(uint256 capped) public pure {
        vm.assume(capped < 2 ** 96);
        uint256 netWanted = capped / 1e12;
        assert(capped - netWanted * 1e12 < 1e12);
    }
}
