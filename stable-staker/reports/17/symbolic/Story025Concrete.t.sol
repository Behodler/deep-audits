// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

/// Concrete fallback for the legs Halmos could not bit-blast (256-bit bvudiv by 1e12).
contract Story025Concrete is Test {
    uint256 constant SCALE = 1e12;

    function _dust(uint256 capped) internal pure returns (uint256) {
        return capped - (capped / SCALE) * SCALE;
    }

    /// Boundary snapshot: dust is strictly sub-unit at every structural edge.
    function test_dustBoundaries() public pure {
        uint256[13] memory xs = [
            uint256(0), 1, SCALE - 1, SCALE, SCALE + 1,
            2 * SCALE - 1, 1e18, 1e18 - 1, 1e18 + 1,
            type(uint128).max, type(uint192).max,
            type(uint256).max, type(uint256).max - 1
        ];
        for (uint256 i = 0; i < xs.length; i++) {
            assertLt(_dust(xs[i]), SCALE, "dust >= scale");
            assertEq(xs[i] / SCALE * SCALE + _dust(xs[i]), xs[i], "euclid");
        }
    }

    /// Broad fuzz over the same fact (256-bit, unbounded).
    function testFuzz_dustSubUnit(uint256 capped) public pure {
        assertLt(_dust(capped), SCALE);
        assertEq((capped / SCALE) * SCALE + _dust(capped), capped);
    }

    /// Full conservation over the real story-025 expression chain, unbounded fuzz.
    function testFuzz_conservation(uint256 owed, uint256 amount, uint256 received, bool sixDec) public pure {
        uint256 scale = sixDec ? 1e12 : 1;
        amount = bound(amount, 0, type(uint256).max / scale);
        uint256 P = amount * scale;
        uint256 capped = owed < P ? owed : P;
        uint256 netWanted = capped / scale;
        uint256 excessBase = owed - capped;
        vm.assume(netWanted > 0 || excessBase > 0);
        uint256 carriedDust = capped - netWanted * scale;
        uint256 netUsed = received < netWanted ? received : netWanted;
        uint256 annihilatable = netUsed * scale;
        uint256 excess = excessBase + (netWanted - netUsed) * scale;
        assertEq(annihilatable + excess + carriedDust, owed);
        assertLt(carriedDust, scale);
    }
}

contract Story025Crossing is Test {
    function passes(uint256 netFloor, uint256 received) public pure returns (bool) {
        uint256 allowance = 2 + (netFloor * 1) / 10_000;
        uint256 floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0;
        return (received > 0 && received >= floorWithAllowance);
    }

    function _recv(uint256 N, uint256 f) internal pure returns (uint256) {
        return N - (N * f) / 1_000_000;
    }

    /// Spot-reproduce the crossing witnesses derived offline.
    function test_crossingWitnesses() public pure {
        // 1.01 bp: 2009901 is the SMALLEST reverting netFloor; one below still passes.
        assertFalse(passes(2009901, _recv(2009901, 101)), "1.01bp min should fail");
        assertTrue(passes(2009900, _recv(2009900, 101)), "1.01bp min-1 should pass");
        // 5 bp control.
        assertFalse(passes(6000, _recv(6000, 500)), "5bp min should fail");
        assertTrue(passes(5999, _recv(5999, 500)), "5bp min-1 should pass");
        // 1.00 bp exactly: never reverts, even at extreme size.
        assertTrue(passes(2 ** 127, _recv(2 ** 127, 100)), "1.00bp huge should pass");
        assertTrue(passes(1e30, _recv(1e30, 100)), "1.00bp 1e30 should pass");
        // The two fork-measured autopool haircuts, at a realistic 1M-USDC exit.
        assertTrue(passes(1e12, _recv(1e12, 47)), "0.47bp should pass");
        assertTrue(passes(1e12, _recv(1e12, 54)), "0.54bp should pass");
    }
}
