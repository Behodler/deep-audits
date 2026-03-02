// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTMinter} from "../src/NFTMinter.sol";
import {Accumulator} from "../src/dispatchers/Accumulator.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title M-05 PoC: Price growth stagnation due to integer rounding
 * @notice Demonstrates that small initial prices cause the price growth
 *         mechanism to permanently stagnate due to integer division rounding.
 *
 * @dev Vulnerability Location: NFTMinter.sol#L139
 *      config.price = price + (price * config.growthBasisPoints) / 10000;
 *
 * VULNERABILITY SUMMARY:
 * When `price * growthBasisPoints < 10000`, the integer division truncates
 * the increment to zero. The price never increases, allowing unlimited
 * cheap minting at a fixed price that was intended to grow.
 *
 * Example: price = 50 wei, growthBps = 100 (1%)
 *          increment = (50 * 100) / 10000 = 5000 / 10000 = 0
 *
 * ATTACK PATH:
 * 1. Owner registers a dispatcher with a small initial price and reasonable growth rate
 * 2. Users mint repeatedly -- price never increases
 * 3. All mints occur at the initial price instead of an escalating curve
 * 4. The growth mechanism is completely bypassed
 */

/// @dev Simple mock ERC20 for testing.
contract PoCMockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract M05PoCTest is Test {
    NFTMinter public minter;
    PoCMockERC20 public token;
    Accumulator public accumulator;

    address public owner = address(this);
    address public user = address(0xBEEF);
    address public recipient = address(0xCAFE);

    function setUp() public {
        minter = new NFTMinter(owner);
        token = new PoCMockERC20("Token", "TKN");

        // Create an Accumulator dispatcher (no-op: tokens stay in minter)
        accumulator = new Accumulator(address(token), "Accumulate TKN", owner);
        accumulator.setMinter(address(minter));
    }

    /**
     * @notice Main PoC: proves price stagnation when initial price is small.
     *
     * Setup: initialPrice = 50 wei, growthBps = 100 (1%)
     * Expected increment per mint: (50 * 100) / 10000 = 0 (truncated)
     * Result: price remains 50 wei forever, no growth occurs.
     */
    function test_poc_M05_priceGrowthStagnation() public {
        console.log("=== M-05 PoC: Price Growth Stagnation Due to Integer Rounding ===");
        console.log("");

        // ----------------------------------------------------------------
        // Step 1: Register dispatcher with small price and 1% growth rate
        // ----------------------------------------------------------------
        uint256 initialPrice = 50; // 50 wei
        uint256 growthBps = 100;   // 1% per mint (reasonable growth rate)
        uint256 numMints = 10;

        minter.registerDispatcher(address(accumulator), initialPrice, growthBps);

        console.log("Initial price (wei):      ", initialPrice);
        console.log("Growth basis points:      ", growthBps);
        console.log("Expected growth per mint:  1%");
        console.log("");

        // Fund user and approve
        token.mint(user, 1 ether); // plenty of tokens
        vm.prank(user);
        token.approve(address(minter), type(uint256).max);

        // Record starting balance
        uint256 balanceBefore = token.balanceOf(user);

        // ----------------------------------------------------------------
        // Step 2: Mint 10 times -- price should grow but does NOT
        // ----------------------------------------------------------------
        console.log("--- Minting 10 times ---");

        uint256[] memory pricesObserved = new uint256[](numMints);

        for (uint256 i = 0; i < numMints; i++) {
            // Record price BEFORE this mint
            pricesObserved[i] = minter.getPrice(1);

            vm.prank(user);
            minter.mint(address(token), 1, recipient);

            console.log("Mint #%d | Price paid: %d wei | Next price: %d wei",
                i + 1, pricesObserved[i], minter.getPrice(1));
        }

        uint256 balanceAfter = token.balanceOf(user);
        uint256 totalPaid = balanceBefore - balanceAfter;
        uint256 finalPrice = minter.getPrice(1);

        console.log("");
        console.log("--- Results ---");
        console.log("Final price after 10 mints: ", finalPrice);
        console.log("Total paid (wei):           ", totalPaid);
        console.log("Expected total (flat price):", initialPrice * numMints);

        // ----------------------------------------------------------------
        // Step 3: Assert the price NEVER changed (stagnation proven)
        // ----------------------------------------------------------------

        // The price after 10 mints should still be the initial price
        assertEq(
            finalPrice,
            initialPrice,
            "VULNERABILITY: Price did not grow after 10 mints -- stagnation confirmed"
        );

        // Every mint was charged the same initial price
        for (uint256 i = 0; i < numMints; i++) {
            assertEq(
                pricesObserved[i],
                initialPrice,
                "VULNERABILITY: Every mint was at the initial price"
            );
        }

        // Total paid equals initialPrice * numMints (no escalation at all)
        assertEq(
            totalPaid,
            initialPrice * numMints,
            "VULNERABILITY: Total paid is flat -- no growth curve applied"
        );

        // Recipient got all 10 NFTs at the stagnant price
        assertEq(minter.balanceOf(recipient, minter.CLAIM_TOKEN_ID()), numMints);

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED: Price growth is permanently stagnant ===");
    }

    /**
     * @notice Control case: proves growth DOES work with a sufficiently large price.
     *
     * Setup: initialPrice = 10000 wei (the minimum where 1 bps = 1 wei increment),
     *        growthBps = 100 (1%)
     * Expected increment per mint: (10000 * 100) / 10000 = 100 wei
     * Result: price increases every mint as intended.
     *
     * This control proves the stagnation is caused by the small initial price,
     * not by a broken growth mechanism in general.
     */
    function test_poc_M05_controlCase_largerPriceDoesGrow() public {
        console.log("=== M-05 Control Case: Larger Price DOES Grow ===");
        console.log("");

        // Same growth rate, but price large enough to avoid truncation
        uint256 initialPrice = 10_000; // 10,000 wei
        uint256 growthBps = 100;       // 1% per mint
        uint256 numMints = 10;

        // Need a second accumulator for a fresh dispatcher registration
        Accumulator accumulator2 = new Accumulator(address(token), "Accumulate TKN v2", owner);
        accumulator2.setMinter(address(minter));
        minter.registerDispatcher(address(accumulator2), initialPrice, growthBps);

        console.log("Initial price (wei):      ", initialPrice);
        console.log("Growth basis points:      ", growthBps);
        console.log("");

        // Fund user and approve
        token.mint(user, 10 ether);
        vm.prank(user);
        token.approve(address(minter), type(uint256).max);

        uint256 balanceBefore = token.balanceOf(user);

        console.log("--- Minting 10 times ---");

        for (uint256 i = 0; i < numMints; i++) {
            uint256 priceBefore = minter.getPrice(1);

            vm.prank(user);
            minter.mint(address(token), 1, recipient);

            uint256 priceAfter = minter.getPrice(1);
            console.log("Mint #%d | Price paid: %d wei | Next price: %d wei",
                i + 1, priceBefore, priceAfter);
        }

        uint256 balanceAfter = token.balanceOf(user);
        uint256 totalPaid = balanceBefore - balanceAfter;
        uint256 finalPrice = minter.getPrice(1);

        console.log("");
        console.log("--- Results ---");
        console.log("Final price after 10 mints:", finalPrice);
        console.log("Total paid (wei):          ", totalPaid);
        console.log("Flat total would have been:", initialPrice * numMints);

        // The price MUST have grown beyond the initial price
        assertGt(
            finalPrice,
            initialPrice,
            "Control: price should grow with a sufficiently large initial value"
        );

        // Total paid must exceed flat pricing (growth curve applied)
        assertGt(
            totalPaid,
            initialPrice * numMints,
            "Control: total paid should exceed flat pricing due to growth"
        );

        console.log("");
        console.log("=== CONTROL CONFIRMED: Growth works when price is large enough ===");
        console.log("");
        console.log("CONCLUSION: The rounding bug causes permanent stagnation for small");
        console.log("prices. Any initialPrice where (price * growthBps) < 10000 will");
        console.log("never grow. For 1% growth (100 bps), any price below 100 wei is");
        console.log("affected. The threshold is: price < 10000 / growthBps.");
    }

    /**
     * @notice Edge case: demonstrates the exact threshold where growth breaks.
     *
     * For growthBps = 100 (1%):
     *   - price = 99 wei  -> increment = (99 * 100) / 10000 = 0 (STAGNANT)
     *   - price = 100 wei -> increment = (100 * 100) / 10000 = 1 (GROWS)
     *
     * This shows the sharp boundary where integer rounding kills growth.
     */
    function test_poc_M05_thresholdBoundary() public {
        console.log("=== M-05 Threshold Boundary Test ===");
        console.log("");

        uint256 growthBps = 100; // 1%

        // --- Case A: price = 99 (just below threshold) => STAGNANT ---
        Accumulator accA = new Accumulator(address(token), "AccA", owner);
        accA.setMinter(address(minter));
        minter.registerDispatcher(address(accA), 99, growthBps);
        uint256 indexA = 1;

        token.mint(user, 1 ether);
        vm.prank(user);
        token.approve(address(minter), type(uint256).max);

        vm.prank(user);
        minter.mint(address(token), indexA, recipient);

        uint256 priceAfterA = minter.getPrice(indexA);
        console.log("Price 99 wei + 1% growth => next price:", priceAfterA, "(expected: 99, stagnant)");
        assertEq(priceAfterA, 99, "99 wei with 1% growth should be stagnant");

        // --- Case B: price = 100 (at threshold) => GROWS ---
        Accumulator accB = new Accumulator(address(token), "AccB", owner);
        accB.setMinter(address(minter));
        minter.registerDispatcher(address(accB), 100, growthBps);
        uint256 indexB = 2;

        vm.prank(user);
        minter.mint(address(token), indexB, recipient);

        uint256 priceAfterB = minter.getPrice(indexB);
        console.log("Price 100 wei + 1% growth => next price:", priceAfterB, "(expected: 101, grows)");
        assertEq(priceAfterB, 101, "100 wei with 1% growth should increase to 101");

        console.log("");
        console.log("=== THRESHOLD CONFIRMED: price < ceil(10000 / growthBps) causes stagnation ===");
    }
}
