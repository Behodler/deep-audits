// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

/**
 * @title DominanceRun17Ladder
 * @notice Tractability ladder for the run-17 dominance claim.
 *         The uint64 version (DominanceRun17Narrow) TIMED OUT on every property,
 *         including the trivial monotonicity lemma -- so the bottleneck is
 *         bit-blasting the multiplications, not the property.  This file re-runs
 *         the SAME theorems at 8/16/32-bit widths to establish the largest domain
 *         over which Halmos can actually decide them, so the report can state a
 *         real bounded proof instead of a timeout.
 */
contract DominanceRun17Ladder is Test {

    // ---- 8-bit domain ----
    function check_L1_8(uint8 a_, uint8 B_, uint8 Sv_, uint8 Av_, uint8 q_, uint8 V_) public pure {
        uint256 a=a_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_; uint256 q=q_; uint256 V=V_;
        vm.assume(Sv > 0); vm.assume(Av > 0);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        assert(!(q > B && a <= V));
    }

    function check_L2_8(uint8 V_, uint8 p_, uint8 D_, uint8 tb_) public pure {
        uint256 V=V_; uint256 p=p_; uint256 D=D_; uint256 tb=tb_;
        vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(!(tb < p) && V < D));
    }

    function check_T1_8(uint8 a_, uint8 p_, uint8 D_, uint8 B_, uint8 Sv_, uint8 Av_, uint8 q_, uint8 V_, uint8 tb_) public pure {
        uint256 a=a_; uint256 p=p_; uint256 D=D_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_;
        uint256 q=q_; uint256 V=V_; uint256 tb=tb_;
        vm.assume(Sv > 0); vm.assume(Av > 0); vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(a <= p); vm.assume(p <= D);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(q > B && !(tb < p)));
    }

    function check_T4tripwire_8(uint8 a_, uint8 p_, uint8 D_, uint8 B_, uint8 Sv_, uint8 Av_, uint8 q_, uint8 V_, uint8 tb_) public pure {
        uint256 a=a_; uint256 p=p_; uint256 D=D_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_;
        uint256 q=q_; uint256 V=V_; uint256 tb=tb_;
        vm.assume(Sv > 0); vm.assume(Av > 0); vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(a <= p); vm.assume(p <= D);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(q > B));
    }

    // ---- 16-bit domain ----
    function check_L1_16(uint16 a_, uint16 B_, uint16 Sv_, uint16 Av_, uint16 q_, uint16 V_) public pure {
        uint256 a=a_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_; uint256 q=q_; uint256 V=V_;
        vm.assume(Sv > 0); vm.assume(Av > 0);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        assert(!(q > B && a <= V));
    }

    function check_L2_16(uint16 V_, uint16 p_, uint16 D_, uint16 tb_) public pure {
        uint256 V=V_; uint256 p=p_; uint256 D=D_; uint256 tb=tb_;
        vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(!(tb < p) && V < D));
    }

    function check_T1_16(uint16 a_, uint16 p_, uint16 D_, uint16 B_, uint16 Sv_, uint16 Av_, uint16 q_, uint16 V_, uint16 tb_) public pure {
        uint256 a=a_; uint256 p=p_; uint256 D=D_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_;
        uint256 q=q_; uint256 V=V_; uint256 tb=tb_;
        vm.assume(Sv > 0); vm.assume(Av > 0); vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(a <= p); vm.assume(p <= D);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(q > B && !(tb < p)));
    }

    function check_T4tripwire_16(uint16 a_, uint16 p_, uint16 D_, uint16 B_, uint16 Sv_, uint16 Av_, uint16 q_, uint16 V_, uint16 tb_) public pure {
        uint256 a=a_; uint256 p=p_; uint256 D=D_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_;
        uint256 q=q_; uint256 V=V_; uint256 tb=tb_;
        vm.assume(Sv > 0); vm.assume(Av > 0); vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(a <= p); vm.assume(p <= D);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(q > B));
    }

    // ---- 32-bit domain ----
    function check_L1_32(uint32 a_, uint32 B_, uint32 Sv_, uint32 Av_, uint32 q_, uint32 V_) public pure {
        uint256 a=a_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_; uint256 q=q_; uint256 V=V_;
        vm.assume(Sv > 0); vm.assume(Av > 0);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        assert(!(q > B && a <= V));
    }

    function check_L2_32(uint32 V_, uint32 p_, uint32 D_, uint32 tb_) public pure {
        uint256 V=V_; uint256 p=p_; uint256 D=D_; uint256 tb=tb_;
        vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(!(tb < p) && V < D));
    }

    function check_T1_32(uint32 a_, uint32 p_, uint32 D_, uint32 B_, uint32 Sv_, uint32 Av_, uint32 q_, uint32 V_, uint32 tb_) public pure {
        uint256 a=a_; uint256 p=p_; uint256 D=D_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_;
        uint256 q=q_; uint256 V=V_; uint256 tb=tb_;
        vm.assume(Sv > 0); vm.assume(Av > 0); vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(a <= p); vm.assume(p <= D);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(q > B && !(tb < p)));
    }

    function check_T4tripwire_32(uint32 a_, uint32 p_, uint32 D_, uint32 B_, uint32 Sv_, uint32 Av_, uint32 q_, uint32 V_, uint32 tb_) public pure {
        uint256 a=a_; uint256 p=p_; uint256 D=D_; uint256 B=B_; uint256 Sv=Sv_; uint256 Av=Av_;
        uint256 q=q_; uint256 V=V_; uint256 tb=tb_;
        vm.assume(Sv > 0); vm.assume(Av > 0); vm.assume(p > 0); vm.assume(D > 0);
        vm.assume(a <= p); vm.assume(p <= D);
        vm.assume(q * Av <= a * Sv); vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av); vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p); vm.assume(V * p < (tb + 1) * D);
        assert(!(q > B));
    }
}
