// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @notice Base contract for invariant testing
/// @dev Extend this and implement protocol-specific invariants
abstract contract InvariantBase is Test {
    // Track actors for handler-based testing
    address[] internal actors;

    // Ghost variables for tracking cumulative values
    uint256 internal ghost_totalDeposits;
    uint256 internal ghost_totalWithdrawals;

    modifier useActor(uint256 actorIndexSeed) {
        address actor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    function addActor(address actor) internal {
        actors.push(actor);
        vm.deal(actor, 100 ether);
    }

    function getActorCount() internal view returns (uint256) {
        return actors.length;
    }

    /// @notice Helper to bound amounts to reasonable values
    function boundAmount(uint256 amount, uint256 min, uint256 max) internal pure returns (uint256) {
        return bound(amount, min, max);
    }
}

/// @notice Example ERC4626 vault invariants
abstract contract VaultInvariants is InvariantBase {
    // Override these in your test
    function vault() internal view virtual returns (address);
    function asset() internal view virtual returns (address);

    /// @notice Total assets must be backed by actual token balance
    function invariant_totalAssetsBacked() public view {
        uint256 totalAssets = IERC4626(vault()).totalAssets();
        uint256 actualBalance = IERC20(asset()).balanceOf(vault());
        assertGe(actualBalance, totalAssets, "Total assets exceeds balance");
    }

    /// @notice Shares should never become worthless (inflation attack)
    function invariant_noShareInflation() public view {
        uint256 totalSupply = IERC4626(vault()).totalSupply();
        if (totalSupply > 0) {
            uint256 totalAssets = IERC4626(vault()).totalAssets();
            // 1 share should always be worth at least 0.0001 assets
            assertGt(
                totalAssets * 1e18 / totalSupply,
                1e14,
                "Share value collapsed"
            );
        }
    }

    /// @notice Total supply should match sum of all balances
    function invariant_supplyConsistency() public view {
        uint256 totalSupply = IERC4626(vault()).totalSupply();
        uint256 sumOfBalances;
        for (uint256 i = 0; i < actors.length; i++) {
            sumOfBalances += IERC20(vault()).balanceOf(actors[i]);
        }
        // Note: This only checks actor balances, not all holders
        assertLe(sumOfBalances, totalSupply, "Sum of balances exceeds supply");
    }

    /// @notice Preview functions should be consistent with actual operations
    function invariant_previewConsistency() public view {
        // previewDeposit should match or underestimate actual shares received
        // previewMint should match or overestimate actual assets needed
        // previewWithdraw should match or overestimate actual shares burned
        // previewRedeem should match or underestimate actual assets received
    }
}

/// @notice Example lending protocol invariants
abstract contract LendingInvariants is InvariantBase {
    /// @notice Protocol should never have bad debt
    function invariant_noBadDebt() public view virtual {
        // Override: totalCollateralValue >= totalDebtValue
    }

    /// @notice Utilization rate should stay within bounds
    function invariant_utilizationBounded() public view virtual {
        // Override: utilization <= 100%
    }

    /// @notice Interest should only accrue, never decrease
    function invariant_interestMonotonic() public virtual {
        // Override: currentInterest >= previousInterest
    }

    /// @notice Liquidation should be profitable (or break-even) for liquidator
    function invariant_liquidationIncentive() public view virtual {
        // Override: Check liquidation bonus covers gas
    }
}

/// @notice Example AMM/DEX invariants
abstract contract AMMInvariants is InvariantBase {
    /// @notice Constant product formula: k should never decrease (only increase from fees)
    function invariant_constantProductPreserved() public view virtual {
        // Override: k_after >= k_before for all swaps
    }

    /// @notice LP tokens should always be redeemable for underlying
    function invariant_lpRedeemable() public view virtual {
        // Override: totalSupply > 0 => reserves > 0
    }

    /// @notice No tokens should get stuck in the contract
    function invariant_noStuckTokens() public view virtual {
        // Override: reserve balance >= tracked reserves
    }
}

/// @notice Example staking/reward invariants
abstract contract StakingInvariants is InvariantBase {
    /// @notice Total staked should match sum of individual stakes
    function invariant_stakingConsistency() public view virtual {
        // Override: sum(stakes[i]) == totalStaked
    }

    /// @notice Rewards should never exceed reward pool
    function invariant_rewardsSolvency() public view virtual {
        // Override: pendingRewards <= rewardPool
    }

    /// @notice Reward rate should be sustainable
    function invariant_rewardRateSustainable() public view virtual {
        // Override: rewardRate * duration <= totalRewards
    }
}

/// @notice Example governance/voting invariants
abstract contract GovernanceInvariants is InvariantBase {
    /// @notice Total voting power should equal total supply (or delegated supply)
    function invariant_votingPowerConsistency() public view virtual {
        // Override: sum(votingPower[i]) == totalSupply
    }

    /// @notice Proposal state transitions should be valid
    function invariant_proposalStateTransitions() public virtual {
        // Override: State machine only allows valid transitions
    }

    /// @notice Quorum should be calculated correctly
    function invariant_quorumIntegrity() public view virtual {
        // Override: quorum percentage applies correctly
    }
}

// Minimal interfaces for invariant checks
interface IERC4626 {
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
