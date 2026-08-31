// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

/**
 * @title DominanceRun17Narrow
 * @notice Same counterexample search as DominanceRun17, made tractable.
 *
 *   Two changes vs the 2^96-vm.assume version (which TIMED OUT at 120s/assertion):
 *     1. Parameters are declared uint64 and widened to uint256 before the
 *        arithmetic.  Zero-extension puts the range bound in the TERM STRUCTURE
 *        rather than in a side constraint, which is what vm.assume could not do.
 *        Domain is therefore explicitly:  every quantity < 2^64.
 *     2. The composite theorem is decomposed into the three lemmas that chain to
 *        it, each with far fewer nonlinear products, plus the composite itself.
 *
 *   All floors are encoded MULTIPLICATIVELY (exact, division-free):
 *     floor(x*S/A) == q   <=>   q*A <= x*S  AND  x*S < (q+1)*A
 */
contract DominanceRun17Narrow is Test {
    // ---------------------------------------------------------------------
    // LEMMA 1a  --  convertToShares is monotone:  a <= V  =>  a*Sv <= V*Sv
    // ---------------------------------------------------------------------
    function check_L1a_mulMonotone(uint64 a_, uint64 V_, uint64 Sv_) public pure {
        uint256 a = a_;
        uint256 V = V_;
        uint256 Sv = Sv_;
        vm.assume(a <= V);
        assert(a * Sv <= V * Sv);
    }

    // ---------------------------------------------------------------------
    // LEMMA 1b  --  cancellation:  q*Av <= B*Av  AND  Av > 0  =>  q <= B
    // ---------------------------------------------------------------------
    function check_L1b_cancelPositiveFactor(uint64 q_, uint64 B_, uint64 Av_) public pure {
        uint256 q = q_;
        uint256 B = B_;
        uint256 Av = Av_;
        vm.assume(Av > 0);
        vm.assume(q * Av <= B * Av);
        assert(q <= B);
    }

    // ---------------------------------------------------------------------
    // LEMMA 1  --  THE SHARE-CAP STEP.
    //   cap binds (convertToShares(a) > balanceOf)  =>  a > convertToAssets(balanceOf)
    //   i.e. contrapositive: a <= V  =>  cap does NOT bind.
    //   ERC4626MarketYieldStrategy.sol:127-135 / ERC4626YieldStrategy.sol:126-138
    // ---------------------------------------------------------------------
    function check_L1_capBindsImpliesAmountExceedsPositionValue(
        uint64 a_,
        uint64 B_,
        uint64 Sv_,
        uint64 Av_,
        uint64 q_,
        uint64 V_
    ) public pure {
        uint256 a = a_;
        uint256 B = B_;
        uint256 Sv = Sv_;
        uint256 Av = Av_;
        uint256 q = q_;
        uint256 V = V_;

        vm.assume(Sv > 0);
        vm.assume(Av > 0);

        // q == floor(a*Sv/Av)   (vault.convertToShares, rounds DOWN)
        vm.assume(q * Av <= a * Sv);
        vm.assume(a * Sv < (q + 1) * Av);
        // V == floor(B*Av/Sv)   (vault.convertToAssets, rounds DOWN) == _positionValue()
        vm.assume(V * Sv <= B * Av);
        vm.assume(B * Av < (V + 1) * Sv);

        assert(!(q > B && a <= V));
    }

    // ---------------------------------------------------------------------
    // LEMMA 2  --  THE UNDERWATER STEP.
    //   NOT underwater  =>  positionValue >= totalDeposited
    //   underwater == totalBalanceOf(t,this) < principalOf(t,this)
    //   totalBalanceOf == floor(V*p/D)      AYieldStrategy.sol:536-550
    // ---------------------------------------------------------------------
    function check_L2_notUnderwaterImpliesValueCoversTotalDeposited(uint64 V_, uint64 p_, uint64 D_, uint64 tb_)
        public
        pure
    {
        uint256 V = V_;
        uint256 p = p_;
        uint256 D = D_;
        uint256 tb = tb_;

        vm.assume(p > 0);
        vm.assume(D > 0);
        // tb == floor(V*p/D)
        vm.assume(tb * D <= V * p);
        vm.assume(V * p < (tb + 1) * D);

        bool underwater = tb < p;
        assert(!(!underwater && V < D));
    }

    // ---------------------------------------------------------------------
    // T1  --  THE COMPOSITE THEOREM (the actual claim under test).
    //   No state exists where the share cap binds and _isUnderwater is FALSE.
    //   D is the GLOBAL totalDeposited across ALL clients, so the multi-client
    //   CODE-01 topology (p << D) is inside the domain, not excluded from it.
    // ---------------------------------------------------------------------
    function check_T1_capBindsImpliesUnderwater(
        uint64 a_,
        uint64 p_,
        uint64 D_,
        uint64 B_,
        uint64 Sv_,
        uint64 Av_,
        uint64 q_,
        uint64 V_,
        uint64 tb_
    ) public pure {
        uint256 a = a_;
        uint256 p = p_;
        uint256 D = D_;
        uint256 B = B_;
        uint256 Sv = Sv_;
        uint256 Av = Av_;
        uint256 q = q_;
        uint256 V = V_;
        uint256 tb = tb_;

        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        vm.assume(a <= p); // _withdrawInternal caps to principal (AYieldStrategy.sol:772-776)
        vm.assume(p <= D); // totalDeposited == sum(clientBalances) (AYieldStrategy.sol:48)

        vm.assume(q * Av <= a * Sv);
        vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av);
        vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p);
        vm.assume(V * p < (tb + 1) * D);

        assert(!(q > B && !(tb < p)));
    }

    // ---------------------------------------------------------------------
    // T2  --  NEGATIVE CONTROL: drop ONLY  p <= D.  MUST FAIL.
    // ---------------------------------------------------------------------
    function check_T2_negControl_dropPLeqD(
        uint64 a_,
        uint64 p_,
        uint64 D_,
        uint64 B_,
        uint64 Sv_,
        uint64 Av_,
        uint64 q_,
        uint64 V_,
        uint64 tb_
    ) public pure {
        uint256 a = a_;
        uint256 p = p_;
        uint256 D = D_;
        uint256 B = B_;
        uint256 Sv = Sv_;
        uint256 Av = Av_;
        uint256 q = q_;
        uint256 V = V_;
        uint256 tb = tb_;

        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        vm.assume(a <= p);
        // p <= D DELIBERATELY REMOVED

        vm.assume(q * Av <= a * Sv);
        vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av);
        vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p);
        vm.assume(V * p < (tb + 1) * D);

        assert(!(q > B && !(tb < p)));
    }

    // ---------------------------------------------------------------------
    // T3  --  NEGATIVE CONTROL: drop ONLY  a <= p.  MUST FAIL.
    // ---------------------------------------------------------------------
    function check_T3_negControl_dropALeqP(
        uint64 a_,
        uint64 p_,
        uint64 D_,
        uint64 B_,
        uint64 Sv_,
        uint64 Av_,
        uint64 q_,
        uint64 V_,
        uint64 tb_
    ) public pure {
        uint256 a = a_;
        uint256 p = p_;
        uint256 D = D_;
        uint256 B = B_;
        uint256 Sv = Sv_;
        uint256 Av = Av_;
        uint256 q = q_;
        uint256 V = V_;
        uint256 tb = tb_;

        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        // a <= p DELIBERATELY REMOVED
        vm.assume(p <= D);

        vm.assume(q * Av <= a * Sv);
        vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av);
        vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p);
        vm.assume(V * p < (tb + 1) * D);

        assert(!(q > B && !(tb < p)));
    }

    // ---------------------------------------------------------------------
    // T4  --  VACUITY TRIPWIRE.  Asserts the cap NEVER binds under T1's exact
    //         preconditions.  MUST FAIL (with a witness) or T1 is vacuous.
    // ---------------------------------------------------------------------
    function check_T4_tripwire_capCanActuallyBind(
        uint64 a_,
        uint64 p_,
        uint64 D_,
        uint64 B_,
        uint64 Sv_,
        uint64 Av_,
        uint64 q_,
        uint64 V_,
        uint64 tb_
    ) public pure {
        uint256 a = a_;
        uint256 p = p_;
        uint256 D = D_;
        uint256 B = B_;
        uint256 Sv = Sv_;
        uint256 Av = Av_;
        uint256 q = q_;
        uint256 V = V_;
        uint256 tb = tb_;

        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        vm.assume(a <= p);
        vm.assume(p <= D);

        vm.assume(q * Av <= a * Sv);
        vm.assume(a * Sv < (q + 1) * Av);
        vm.assume(V * Sv <= B * Av);
        vm.assume(B * Av < (V + 1) * Sv);
        vm.assume(tb * D <= V * p);
        vm.assume(V * p < (tb + 1) * D);

        assert(!(q > B));
    }

    // ---------------------------------------------------------------------
    // T5  --  ROUNDING SENSITIVITY: vault rounds convertToAssets UP.
    // ---------------------------------------------------------------------
    function check_T5_assetsRoundUp(
        uint64 a_,
        uint64 p_,
        uint64 D_,
        uint64 B_,
        uint64 Sv_,
        uint64 Av_,
        uint64 q_,
        uint64 V_,
        uint64 tb_
    ) public pure {
        uint256 a = a_;
        uint256 p = p_;
        uint256 D = D_;
        uint256 B = B_;
        uint256 Sv = Sv_;
        uint256 Av = Av_;
        uint256 q = q_;
        uint256 V = V_;
        uint256 tb = tb_;

        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        vm.assume(a <= p);
        vm.assume(p <= D);

        vm.assume(q * Av <= a * Sv);
        vm.assume(a * Sv < (q + 1) * Av);
        // V == ceil(B*Av/Sv)
        vm.assume(V * Sv >= B * Av);
        vm.assume(V == 0 || (V - 1) * Sv < B * Av);
        vm.assume(tb * D <= V * p);
        vm.assume(V * p < (tb + 1) * D);

        assert(!(q > B && !(tb < p)));
    }
}
