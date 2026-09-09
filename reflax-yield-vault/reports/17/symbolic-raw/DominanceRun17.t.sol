// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

/**
 * @title DominanceRun17
 * @notice Counterexample search for the run-17 load-bearing claim:
 *
 *     "cap-binds  =>  _isUnderwater"
 *
 *   i.e. there is NO state in which the share-balance cap inside
 *   ERC4626{Market}YieldStrategy._disposeShares / _exitFloor binds while
 *   StableStakerV2._isUnderwater is FALSE.
 *
 *   Live definitions (top-level lib HEAD only):
 *     lib/stable-staker/src/StableStakerV2.sol:851-853
 *       _isUnderwater = strategy.totalBalanceOf(token,this) < strategy.principalOf(token,this)
 *     lib/reflax-yield-vault/src/AYieldStrategy.sol:536-550
 *       totalBalanceOf = (_positionValue() * clientBalances[t][acct]) / totalDeposited[t]
 *       (returns 0 when principal==0 or totalDeposited==0)
 *     lib/reflax-yield-vault/src/AYieldStrategy.sol:523-526   principalOf = clientBalances[t][acct]
 *     lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:78-80
 *       _positionValue = vault.convertToAssets(vault.balanceOf(this))
 *     ERC4626MarketYieldStrategy.sol:127-135  _exitFloor: cap sharesToSell at vault.balanceOf(this)
 *     ERC4626YieldStrategy.sol:126-138        _disposeShares: same cap
 *     AYieldStrategy.sol:772-782 _withdrawInternal caps `amount` to clientBalances BEFORE
 *       calling _disposeShares  ==>  a <= p
 *     AYieldStrategy.sol:48 invariant totalDeposited == sum(clientBalances)  ==>  p <= D
 *
 * BUDGET DISCIPLINE
 *   The literal encoding needs THREE symbolic 256-bit divisions
 *   (convertToShares, convertToAssets, the pro-rata in totalBalanceOf) which is
 *   intractable for Halmos. So every floor is encoded MULTIPLICATIVELY via its
 *   defining inequality  q*A <= a*S < (q+1)*A  -- exact, division-free, and
 *   strictly WEAKER than the real code (it admits every value the real code can
 *   produce and nothing is assumed about the rate beyond ERC4626 semantics).
 *   Sv/Av are the vault's effective share/asset multipliers, so this covers plain
 *   totalSupply/totalAssets, OpenZeppelin's virtual-share (S+1)/(A+1) offset, and
 *   any decimal-offset variant.
 *
 *   All quantities bounded to 2^96 so the products cannot overflow uint256.
 *   BOUNDED DOMAIN -- stated in every result.
 */
contract DominanceRun17 is Test {
    uint256 constant BOUND = 2 ** 96;

    // ---------------------------------------------------------------- helpers

    /// @dev q == floor(x * Sv / Av)   (ERC4626 convertToShares, rounds DOWN)
    function _assumeFloorShares(uint256 q, uint256 x, uint256 Sv, uint256 Av) internal pure {
        vm.assume(q * Av <= x * Sv);
        vm.assume(x * Sv < (q + 1) * Av);
    }

    /// @dev V == floor(s * Av / Sv)   (ERC4626 convertToAssets, rounds DOWN)
    function _assumeFloorAssets(uint256 V, uint256 s, uint256 Sv, uint256 Av) internal pure {
        vm.assume(V * Sv <= s * Av);
        vm.assume(s * Av < (V + 1) * Sv);
    }

    /// @dev tb == floor(V * p / D)    (AYieldStrategy.totalBalanceOf pro-rata)
    function _assumeFloorProRata(uint256 tb, uint256 V, uint256 p, uint256 D) internal pure {
        vm.assume(tb * D <= V * p);
        vm.assume(V * p < (tb + 1) * D);
    }

    function _bound(uint256 x) internal pure {
        vm.assume(x < BOUND);
    }

    // ==================================================================
    // T1 -- THE THEOREM.  cap binds  =>  underwater.
    // ==================================================================
    function check_capBindsImpliesUnderwater(
        uint256 a, // capped withdraw amount reaching _disposeShares/_exitFloor
        uint256 p, // clientBalances[token][StableStaker]
        uint256 D, // totalDeposited[token]   (ALL clients -- multi-client topology)
        uint256 B, // vault.balanceOf(strategy)  -- GLOBAL share balance
        uint256 Sv, // vault effective share multiplier
        uint256 Av, // vault effective asset multiplier
        uint256 q, // convertToShares(a)
        uint256 V, // convertToAssets(B) == _positionValue()
        uint256 tb // totalBalanceOf(token, StableStaker)
    ) public pure {
        _bound(a);
        _bound(p);
        _bound(D);
        _bound(B);
        _bound(Sv);
        _bound(Av);
        _bound(q);
        _bound(V);
        _bound(tb);

        vm.assume(Sv > 0);
        vm.assume(Av > 0);

        // live-code invariants
        vm.assume(p > 0); // p == 0 => nothing to withdraw (see T3)
        vm.assume(D > 0);
        vm.assume(a <= p); // _withdrawInternal caps to available principal
        vm.assume(p <= D); // AYieldStrategy.sol:48

        _assumeFloorShares(q, a, Sv, Av);
        _assumeFloorAssets(V, B, Sv, Av);
        _assumeFloorProRata(tb, V, p, D);

        bool capBinds = q > B;
        bool underwater = tb < p;

        // The counterexample being searched for: cap binds AND not underwater.
        assert(!(capBinds && !underwater));
    }

    // ==================================================================
    // T2 -- NEGATIVE CONTROL.  Drop ONLY the p <= D invariant.
    //       Must FAIL, otherwise T1 is proving something weaker than claimed
    //       and the accounting invariant is not the load-bearing assumption.
    // ==================================================================
    function check_negControl_dropPLeqD(
        uint256 a,
        uint256 p,
        uint256 D,
        uint256 B,
        uint256 Sv,
        uint256 Av,
        uint256 q,
        uint256 V,
        uint256 tb
    ) public pure {
        _bound(a);
        _bound(p);
        _bound(D);
        _bound(B);
        _bound(Sv);
        _bound(Av);
        _bound(q);
        _bound(V);
        _bound(tb);
        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        vm.assume(a <= p);
        // vm.assume(p <= D);   <-- DELIBERATELY REMOVED

        _assumeFloorShares(q, a, Sv, Av);
        _assumeFloorAssets(V, B, Sv, Av);
        _assumeFloorProRata(tb, V, p, D);

        assert(!(q > B && !(tb < p)));
    }

    // ==================================================================
    // T3 -- VACUITY TRIPWIRE.  Assert the guarded state is UNREACHABLE.
    //       This MUST FAIL with a concrete witness; a PASS here would mean
    //       T1 is vacuous (no state ever binds the cap) and proves nothing.
    // ==================================================================
    function check_tripwire_capCanActuallyBind(
        uint256 a,
        uint256 p,
        uint256 D,
        uint256 B,
        uint256 Sv,
        uint256 Av,
        uint256 q,
        uint256 V,
        uint256 tb
    ) public pure {
        _bound(a);
        _bound(p);
        _bound(D);
        _bound(B);
        _bound(Sv);
        _bound(Av);
        _bound(q);
        _bound(V);
        _bound(tb);
        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        vm.assume(a <= p);
        vm.assume(p <= D);

        _assumeFloorShares(q, a, Sv, Av);
        _assumeFloorAssets(V, B, Sv, Av);
        _assumeFloorProRata(tb, V, p, D);

        // "the cap never binds" -- expected FAIL (witness = a reachable binding state)
        assert(!(q > B));
    }

    // ==================================================================
    // T4 -- ROUNDING SENSITIVITY.  Same theorem, but convertToAssets rounds UP
    //       (a non-OZ / exotic vault).  Tests whether dominance survives a vault
    //       that does not round assets down.
    // ==================================================================
    function check_capBindsImpliesUnderwater_assetsRoundUp(
        uint256 a,
        uint256 p,
        uint256 D,
        uint256 B,
        uint256 Sv,
        uint256 Av,
        uint256 q,
        uint256 V,
        uint256 tb
    ) public pure {
        _bound(a);
        _bound(p);
        _bound(D);
        _bound(B);
        _bound(Sv);
        _bound(Av);
        _bound(q);
        _bound(V);
        _bound(tb);
        vm.assume(Sv > 0);
        vm.assume(Av > 0);
        vm.assume(p > 0);
        vm.assume(D > 0);
        vm.assume(a <= p);
        vm.assume(p <= D);

        _assumeFloorShares(q, a, Sv, Av);
        // V == ceil(B * Av / Sv)
        vm.assume(V * Sv >= B * Av);
        vm.assume(V == 0 || (V - 1) * Sv < B * Av);
        _assumeFloorProRata(tb, V, p, D);

        assert(!(q > B && !(tb < p)));
    }
}
