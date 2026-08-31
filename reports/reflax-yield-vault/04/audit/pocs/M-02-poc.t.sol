// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../src/mocks/MockERC20.sol";
import "./mocks/MockERC4626Vault.sol";
import "./mocks/MockAMMAdapter.sol";

/**
 * @title PoC_M02_SlippageAnchorBricksWithdrawals
 * @notice Proof of Concept for H-01: minOut anchored to vault.convertToAssets/convertToShares
 *         (vault internal rate) instead of an AMM-fair price bricks all withdrawals during
 *         the exact market condition this strategy is designed to handle (AMM discount vs
 *         vault internal rate).
 *
 * @dev Vulnerability locations:
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:276-283 (deposit minOut)
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:313-328 (withdraw minOut)
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:378-390 (totalWithdraw minOut)
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:428-442 (withdrawFrom minOut)
 *
 * VULNERABILITY SUMMARY:
 *   The strategy computes minOut on every AMM swap as
 *       minOut = vault.convertToAssets(sharesToSell) * (MAX_BPS - slippageBps) / MAX_BPS
 *   This anchors slippage protection to the vault's INTERNAL accumulator price, not the
 *   AMM's actual market price. The whole point of using a "Market" strategy backed by an
 *   AMM is to handle vaults whose AMM secondary-market price diverges from the internal
 *   share price (e.g., sUSDe trading at a discount on Curve during cooldown pressure).
 *   When the AMM trades the vault token below the internal rate by more than the slippage
 *   tolerance, every withdraw reverts. The strategy is bricked exactly in the market
 *   condition it was designed to handle, trapping client funds with no exit.
 *
 * ATTACK / FAILURE PATH:
 *   1. Client deposits underlying through the strategy at a healthy AMM rate.
 *   2. Time passes; vault accrues yield -> internal share price > 1.
 *   3. AMM price for vault->underlying drops below the internal price (normal market event
 *      for cooldown-restricted ERC4626 vaults like sUSDe under stress).
 *   4. Client calls withdraw(). The strategy computes minOut from the (now-higher)
 *      vault.convertToAssets, which is unreachable on the AMM. The swap reverts.
 *   5. Funds are stuck. Only emergencyWithdraw (owner-only) can rescue them, but that
 *      transfers raw vault shares to the owner and bypasses the AMM entirely - i.e. the
 *      end user has no self-service exit during the very condition this contract claims
 *      to support.
 */
contract PoC_M02_SlippageAnchorBricksWithdrawals is Test {
    ERC4626MarketYieldStrategy strategy;
    MockERC20 underlyingToken;
    MockERC4626Vault erc4626Vault;
    MockAMMAdapter ammAdapter;

    address owner = address(0x1234);
    address client = address(0x5678);
    address pauser = address(0x9ABC);
    address user1 = address(0xDEF0);

    uint256 constant INITIAL_TOKEN_SUPPLY = 10_000_000e18;

    // ============ SETUP (mirrors test/unit/ERC4626MarketYieldStrategy.t.sol) ============

    function setUp() public {
        // Deploy mock underlying token
        underlyingToken = new MockERC20("Underlying", "UNDERLYING", 18);

        // Deploy mock ERC4626 vault wrapping the underlying
        erc4626Vault = new MockERC4626Vault("Vault Shares", "vUNDERLYING", address(underlyingToken));

        // Deploy mock AMM adapter
        ammAdapter = new MockAMMAdapter();

        // Deploy the strategy
        vm.prank(owner);
        strategy = new ERC4626MarketYieldStrategy(
            owner, address(underlyingToken), address(erc4626Vault), address(ammAdapter)
        );

        // Initial 1:1 exchange rates (favorable, healthy market) for both swap directions
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        // Mint underlying to client
        underlyingToken.mint(client, INITIAL_TOKEN_SUPPLY);

        // Pre-fund the AMM adapter with vault shares (so deposit swaps can succeed)
        // The AMM is the counterparty: when strategy deposits underlying, AMM hands over
        // vault shares from its reserves. We seed those reserves by minting underlying to
        // this test contract, depositing into the vault, and letting the vault mint shares
        // directly to the AMM adapter address.
        underlyingToken.mint(address(this), INITIAL_TOKEN_SUPPLY);
        underlyingToken.approve(address(erc4626Vault), INITIAL_TOKEN_SUPPLY);
        erc4626Vault.deposit(INITIAL_TOKEN_SUPPLY, address(ammAdapter));

        // Pre-fund the AMM adapter with underlying token reserves so withdraw swaps have
        // tokens to pay out. The discount is enforced by the AMM rate, not by reserve
        // shortage; we want the revert to come from the slippage check, not from a
        // SafeERC20 transfer failure due to empty reserves.
        underlyingToken.mint(address(ammAdapter), INITIAL_TOKEN_SUPPLY);

        // Authorize the client and configure 1% slippage tolerance
        vm.startPrank(owner);
        strategy.setClient(client, true);
        strategy.setPauser(pauser);
        strategy.setSlippageTolerance(100); // 100 bps = 1%
        vm.stopPrank();

        // Allow the strategy to pull underlying from the client
        vm.prank(client);
        underlyingToken.approve(address(strategy), type(uint256).max);
    }

    // ============ SANITY CHECK: DEPOSIT WORKS AT FAIR RATE ============

    /// @notice Sanity test: a normal deposit at the 1:1 favorable AMM rate succeeds.
    /// @dev This is the "happy path" baseline. The bug only manifests on withdraw
    ///      after the AMM rate diverges from the vault internal rate.
    function test_DepositSucceedsAtFavorableRate() public {
        uint256 depositAmount = 1000e18;

        vm.prank(client);
        strategy.deposit(address(underlyingToken), depositAmount, client);

        // Principal is tracked in input (underlying) units
        assertEq(strategy.principalOf(address(underlyingToken), client), depositAmount, "principal mismatch");
        // Strategy now holds vault shares (received from the AMM swap)
        assertGt(strategy.getTotalShares(), 0, "expected vault shares received");
    }

    // ============ THE SMOKING GUN ============

    /// @notice Demonstrates that withdraw is bricked when the AMM price for vault shares
    ///         falls below the vault internal rate by more than the slippage tolerance.
    ///
    /// @dev Math walkthrough (using the numbers in this test):
    ///
    ///   Initial deposit:
    ///     client deposits 1_000e18 underlying. AMM is 1:1, so strategy receives ~1_000e18
    ///     vault shares. Vault is empty before this deposit (other than the AMM seed
    ///     which we account for), and convertToShares for the strategy's deposit returns
    ///     1:1 because totalSupply == totalAssets at the time of conversion.
    ///
    ///   Yield simulation:
    ///     vault.simulateYield(2_000_000e18) inflates the vault's totalAssets without
    ///     minting new shares. Internal price (assets/share) increases. After yield:
    ///         pricePerShare = (totalAssets) / (totalSupply)  >  1.0
    ///     so vault.convertToAssets(N shares) > N (in underlying units).
    ///
    ///   AMM discount:
    ///     We set the AMM rate vault -> underlying to 0.95e18. The AMM will return
    ///         amountOut = sharesToSell * 0.95
    ///     for every swap, which is BELOW the vault internal redemption value of
    ///         vault.convertToAssets(sharesToSell)  ~= sharesToSell * pricePerShare
    ///     where pricePerShare > 1.
    ///
    ///   Strategy minOut:
    ///     On withdraw(500e18) the strategy computes:
    ///         sharesToSell    = vault.convertToShares(500e18)              // < 500 because price > 1
    ///         idealUnderlying = vault.convertToAssets(sharesToSell)        // ~= 500e18 (round trips)
    ///         minOut          = idealUnderlying * (10000 - 100) / 10000    // ~= 495e18
    ///
    ///   AMM swap result:
    ///         amountOut = sharesToSell * 0.95  ~= 0.95 * (500e18 / pricePerShare) * pricePerShare
    ///                   = 0.95 * 500e18 = 475e18    // (the pricePerShare cancels)
    ///
    ///   495e18 (minOut) > 475e18 (amountOut)  ->  MockAMMAdapter reverts with
    ///   "MockAMMAdapter: insufficient output amount". The withdraw is bricked.
    ///
    ///   Critical observation: the round-trip cancellation means the bug is independent
    ///   of how much yield has accrued. ANY AMM discount > slippageTolerance bricks the
    ///   withdraw, even if the vault price hasn't moved. This is because the strategy
    ///   anchors minOut to the *vault* round-trip value, not the AMM's quoted output.
    function test_WithdrawRevertsWhenMarketPriceBelowInternalRate() public {
        // ----- Step 1: client deposits 1000 underlying at the healthy 1:1 AMM rate -----
        uint256 depositAmount = 1_000e18;
        vm.prank(client);
        strategy.deposit(address(underlyingToken), depositAmount, client);

        // Sanity: principal recorded
        assertEq(strategy.principalOf(address(underlyingToken), client), depositAmount, "deposit pre-condition");

        // ----- Step 2: vault accrues real yield (internal share price increases) -----
        // simulateYield mints underlying to the vault contract and bumps totalAssets,
        // without minting new shares. After this, convertToAssets(N) > N for the
        // strategy's existing shares.
        erc4626Vault.simulateYield(2_000_000e18);

        // Sanity: totalBalanceOf > principal because the strategy's shares are now worth
        // more underlying at the vault internal rate.
        uint256 internalValue = strategy.totalBalanceOf(address(underlyingToken), client);
        assertGt(internalValue, depositAmount, "vault internal rate should have increased");

        // ----- Step 3: AMM price for vault -> underlying drops to a 5% discount -----
        // This is the exact market condition the "Market" strategy is supposed to handle:
        // the secondary AMM price for the vault token has decoupled from the vault's
        // internal accumulator (e.g., cooldown pressure on sUSDe causing the Curve pool
        // to discount sUSDe relative to its sDAI/USDe internal value).
        //
        // 0.95e18 = receive 0.95 underlying per 1 vault share via the AMM.
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 0.95e18);

        // The strategy's slippage tolerance is 100 bps (1%), set in setUp(). A 5% AMM
        // discount is well outside that tolerance, so any withdraw must revert.

        // Sanity: confirm the AMM adapter actually has the underlying reserves to pay out
        // the swap if it weren't blocked by the slippage check. We want to be sure the
        // revert is from the slippage anchor bug, not from an empty AMM.
        assertGt(
            underlyingToken.balanceOf(address(ammAdapter)),
            depositAmount * 10,
            "AMM should have ample underlying reserves; revert must be from slippage check"
        );

        // ----- Step 4: client tries to withdraw - reverts with the AMM slippage error -----
        // The minOut is anchored to vault.convertToAssets(sharesToSell), which corresponds
        // to the *internal* (high) price. The AMM only delivers at the *market* (low)
        // price. minOut is unreachable. Funds are trapped.
        vm.expectRevert("MockAMMAdapter: insufficient output amount");
        vm.prank(client);
        strategy.withdraw(address(underlyingToken), 500e18, client);

        // ----- Step 5: client cannot escape via partial / smaller / dust withdrawals -----
        // The bug is independent of size: any nonzero withdrawal is rejected because the
        // round-trip math (convertToShares -> convertToAssets) cancels the price-per-share
        // factor, leaving minOut anchored to the *requested underlying amount* instead of
        // to the actual AMM-deliverable amount. So a 1-wei withdrawal fails the same way.
        vm.expectRevert("MockAMMAdapter: insufficient output amount");
        vm.prank(client);
        strategy.withdraw(address(underlyingToken), 1e18, client);

        // ----- Step 6: principal is unchanged - funds are confirmed trapped -----
        // The client has been completely DoS'd from their position with no self-service
        // recovery. Only emergencyWithdraw (owner-only, transfers raw vault shares to
        // owner) can rescue funds, defeating the entire purpose of the Market strategy.
        assertEq(
            strategy.principalOf(address(underlyingToken), client),
            depositAmount,
            "principal must be unchanged - withdrawals are bricked"
        );
    }
}
