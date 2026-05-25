// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BalancerPooler} from "../src/dispatchers/BalancerPooler.sol";
import {IMintable} from "../src/interfaces/IMintable.sol";
import {IUnlockCallback} from "../src/interfaces/balancer/IUnlockCallback.sol";
import {AddLiquidityParams, AddLiquidityKind} from "../src/interfaces/balancer/BalancerTypes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title M-03 PoC: BalancerPooler 1:1 phUSD minting assumes price parity with yield-bearing prime tokens
 * @notice Demonstrates that _normalizeToPhUSD() only adjusts for decimal differences, NOT
 *         market price, causing asymmetric donations to the Balancer pool whenever the prime
 *         token is yield-bearing (e.g., sUSDS, wstETH, sDAI).
 *
 * @dev Vulnerability Location: BalancerPooler.sol#L117-L125 (_normalizeToPhUSD)
 *      Called at: BalancerPooler.sol#L85
 *
 * VULNERABILITY SUMMARY:
 * In unlockCallback(), phUSD is minted 1:1 with the prime token (decimal-normalized only):
 *
 *     uint256 phUSDAmount = _normalizeToPhUSD(actualPrimeInVault);
 *     IMintable(_phUSD).mint(address(this), phUSDAmount);
 *
 * _normalizeToPhUSD() ONLY adjusts for decimal differences between the two tokens.
 * It does NOT account for the market price ratio. If the prime token is yield-bearing
 * (e.g., sUSDS worth $1.05 while phUSD pegs to $1.00), donating 100 prime + 100 phUSD
 * to the pool creates a $105 + $100 = $205 donation that is asymmetric.
 *
 * This creates an immediate arbitrage opportunity: LPs and MEV bots can extract the
 * excess value donated by the prime token side. Every dispatch() call leaks value.
 *
 * ATTACK PATH:
 * 1. BalancerPooler receives 100 sUSDS (worth $1.05 each = $105 total value)
 * 2. _normalizeToPhUSD(100e18) returns 100e18 -- pure decimal conversion, no price
 * 3. 100 phUSD is minted (worth $100 total value)
 * 4. Pool receives asymmetric donation: $105 in prime + $100 in phUSD
 * 5. Arbitrageurs extract ~$2.50 of the $5 imbalance (the exact amount depends on
 *    pool depth and swap fees, but the value leak is guaranteed and cumulative)
 */

// =============================================================================
// Mock contracts
// =============================================================================

/// @dev Mock ERC20 with configurable decimals for testing.
contract MockERC20 is ERC20 {
    uint8 private _customDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _customDecimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }
}

/// @dev Mock ERC20 that implements IMintable (represents phUSD). Actually mints tokens.
contract MockMintableToken is ERC20, IMintable {
    uint8 private _customDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _customDecimals = decimals_;
    }

    function mint(address recipient, uint256 amount) external override {
        _mint(recipient, amount);
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }
}

/// @dev Mock Balancer Vault that implements the unlock/callback pattern.
///      Records donation parameters for assertion.
contract MockBalancerVault {
    // Recorded addLiquidity call parameters
    AddLiquidityParams public lastParams;
    bool public addLiquidityCalled;

    struct Settlement {
        address token;
        uint256 amount;
    }

    Settlement[] public settlements;

    function unlock(bytes calldata data) external returns (bytes memory result) {
        result = IUnlockCallback(msg.sender).unlockCallback(data);
    }

    function addLiquidity(AddLiquidityParams memory params)
        external
        returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData)
    {
        lastParams.pool = params.pool;
        lastParams.to = params.to;
        lastParams.minBptAmountOut = params.minBptAmountOut;
        lastParams.kind = params.kind;
        lastParams.userData = params.userData;

        delete lastParams.maxAmountsIn;
        for (uint256 i = 0; i < params.maxAmountsIn.length; i++) {
            lastParams.maxAmountsIn.push(params.maxAmountsIn[i]);
        }

        addLiquidityCalled = true;
        amountsIn = params.maxAmountsIn;
        bptAmountOut = 0;
        returnData = "";
    }

    function settle(IERC20 token, uint256 amountHint) external returns (uint256 credit) {
        settlements.push(Settlement({token: address(token), amount: amountHint}));
        return amountHint;
    }

    function sendTo(IERC20, address, uint256) external pure {}

    function getSettlementsCount() external view returns (uint256) {
        return settlements.length;
    }

    function getSettlement(uint256 index) external view returns (address token, uint256 amount) {
        Settlement memory s = settlements[index];
        return (s.token, s.amount);
    }

    function getLastParamsMaxAmountsIn() external view returns (uint256[] memory) {
        return lastParams.maxAmountsIn;
    }
}

// =============================================================================
// PoC Test
// =============================================================================

contract M03PoCTest is Test {
    BalancerPooler public pooler;
    MockERC20 public primeToken;
    MockMintableToken public phUSDToken;
    MockBalancerVault public mockVault;
    address public pool = address(0xA001);
    address public owner = address(this);
    address public minter = address(0xBEEF);

    // Simulated market prices (in USD, scaled to 18 decimals for precision)
    // sUSDS is a yield-bearing stablecoin that accrues value over $1.00
    uint256 constant PRIME_TOKEN_PRICE_USD = 1.05e18; // sUSDS at $1.05 (5% yield accrued)
    uint256 constant PHUSD_PRICE_USD = 1.00e18; // phUSD pegged at $1.00

    function setUp() public {
        // Deploy both tokens with 18 decimals (same decimals, like sUSDS and phUSD)
        primeToken = new MockERC20("Savings USDS", "sUSDS", 18);
        phUSDToken = new MockMintableToken("phUSD", "phUSD", 18);
        mockVault = new MockBalancerVault();

        pooler = new BalancerPooler(
            address(primeToken),
            address(phUSDToken),
            pool,
            address(mockVault),
            true, // primeTokenIsFirst
            "Pool sUSDS/phUSD",
            owner
        );
    }

    /// @notice Core PoC: demonstrates that _normalizeToPhUSD only adjusts decimals,
    ///         not market price, creating asymmetric pool donations.
    function test_poc_M03_1to1_minting_ignores_yield_premium() public {
        console.log("=== M-03 PoC: 1:1 phUSD minting ignores yield-bearing token premium ===");
        console.log("");

        // =====================================================================
        // Step 1: Dispatch 100 sUSDS (yield-bearing, worth $1.05 each)
        // =====================================================================
        uint256 primeAmount = 100e18; // 100 sUSDS tokens
        primeToken.mint(minter, primeAmount);

        vm.prank(minter);
        primeToken.approve(address(pooler), type(uint256).max);

        console.log("Step 1: Dispatch 100 sUSDS (yield-bearing prime token)");
        console.log("  sUSDS amount:     ", primeAmount);
        console.log("  sUSDS market price: $1.05 per token");
        console.log("  sUSDS total value:  $105.00");
        console.log("");

        pooler.dispatch(minter, primeAmount);

        // =====================================================================
        // Step 2: Verify the 1:1 decimal-only normalization
        // =====================================================================
        uint256[] memory amounts = mockVault.getLastParamsMaxAmountsIn();
        uint256 donatedPrime = amounts[0]; // primeTokenIsFirst = true
        uint256 donatedPhUSD = amounts[1];

        console.log("Step 2: Verify donated amounts (raw tokens)");
        console.log("  Prime (sUSDS) donated:", donatedPrime);
        console.log("  phUSD minted+donated: ", donatedPhUSD);
        console.log("");

        // CRITICAL ASSERTION: phUSD amount exactly equals prime amount (1:1 by token count)
        // This is the bug -- no price adjustment is applied
        assertEq(
            donatedPhUSD,
            donatedPrime,
            "BUG: phUSD minted equals prime token count (1:1), ignoring price difference"
        );

        // Both should be exactly 100e18
        assertEq(donatedPrime, 100e18, "Prime donated should be 100e18");
        assertEq(donatedPhUSD, 100e18, "phUSD donated should be 100e18 (1:1 with prime)");

        // =====================================================================
        // Step 3: Calculate the USD value asymmetry
        // =====================================================================
        uint256 primeValueUSD = (donatedPrime * PRIME_TOKEN_PRICE_USD) / 1e18;
        uint256 phUSDValueUSD = (donatedPhUSD * PHUSD_PRICE_USD) / 1e18;
        uint256 totalDonationUSD = primeValueUSD + phUSDValueUSD;
        uint256 valueImbalance = primeValueUSD - phUSDValueUSD;

        console.log("Step 3: USD value analysis of pool donation");
        console.log("  Prime side USD value: $", primeValueUSD / 1e16, "(scaled by 1e16)");
        console.log("  phUSD side USD value: $", phUSDValueUSD / 1e16, "(scaled by 1e16)");
        console.log("  Total donation:       $", totalDonationUSD / 1e16);
        console.log("  Value imbalance:      $", valueImbalance / 1e16);
        console.log("");

        // The prime side is worth MORE than the phUSD side
        assertTrue(
            primeValueUSD > phUSDValueUSD,
            "Prime side has higher USD value than phUSD side"
        );

        // The imbalance is exactly the yield premium (5% of prime value)
        assertEq(
            valueImbalance,
            5e18, // $5.00 imbalance on a 100-token donation
            "Imbalance equals the yield premium ($5 on 100 tokens at 5% yield)"
        );

        // =====================================================================
        // Step 4: Verify that settlement amounts also reflect the 1:1 ratio
        // =====================================================================
        (address settledToken0, uint256 settledAmount0) = mockVault.getSettlement(0);
        (address settledToken1, uint256 settledAmount1) = mockVault.getSettlement(1);

        assertEq(settledToken0, address(primeToken), "First settlement is prime token");
        assertEq(settledToken1, address(phUSDToken), "Second settlement is phUSD");
        assertEq(settledAmount0, settledAmount1, "Settlement amounts are identical (1:1)");

        console.log("Step 4: Settlement verification");
        console.log("  Prime settled: ", settledAmount0);
        console.log("  phUSD settled: ", settledAmount1);
        console.log("  Ratio:          1:1 (no price adjustment)");
        console.log("");

        // =====================================================================
        // Step 5: Calculate the extractable arbitrage
        // =====================================================================
        // In a 50/50 balanced pool, an asymmetric donation creates an arbitrage
        // opportunity. An arbitrageur can swap phUSD for the excess prime tokens
        // at a discount.
        //
        // Simplified arbitrage model for a constant-product pool:
        //   If the pool receives $105 of prime + $100 of phUSD, the pool's
        //   internal price shifts. An arber can extract roughly half the imbalance
        //   (minus swap fees) by rebalancing the pool.
        //
        // For each 100-token dispatch:
        //   Imbalance = 100 * ($1.05 - $1.00) = $5.00
        //   Extractable value ~= $5.00 * 50% = ~$2.50 (varies with pool depth/fees)
        //
        // This is a CUMULATIVE leak: every dispatch() call donates asymmetrically.

        uint256 imbalancePerDispatch = valueImbalance; // $5.00 per 100-token dispatch
        uint256 estimatedExtractable = imbalancePerDispatch / 2; // Conservative estimate

        console.log("Step 5: Arbitrage opportunity (per 100-token dispatch)");
        console.log("  Value imbalance per dispatch:     $", imbalancePerDispatch / 1e16);
        console.log("  Estimated extractable (conserv.): $", estimatedExtractable / 1e16);
        console.log("");

        assertTrue(
            estimatedExtractable > 0,
            "Non-zero extractable value proves the arbitrage opportunity"
        );

        // =====================================================================
        // Step 6: Show cumulative impact over multiple dispatches
        // =====================================================================
        uint256 numDispatches = 1000; // Realistic over the protocol's lifetime
        uint256 cumulativeLeak = imbalancePerDispatch * numDispatches;

        console.log("Step 6: Cumulative impact projection");
        console.log("  Dispatches over protocol lifetime: ", numDispatches);
        console.log("  Cumulative value leak:             $", cumulativeLeak / 1e18);
        console.log("  (At 100 tokens per dispatch, 5% yield premium)");
        console.log("");

        assertTrue(
            cumulativeLeak > 0,
            "Cumulative leak is non-trivial over protocol lifetime"
        );

        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("");
        console.log("Root cause: _normalizeToPhUSD() at BalancerPooler.sol#L117-L125");
        console.log("  - Only adjusts for decimal differences between tokens");
        console.log("  - Does NOT query an oracle or apply any price ratio");
        console.log("  - Assumes 1 prime token = 1 phUSD in value");
        console.log("  - For yield-bearing prime tokens (sUSDS, wstETH, sDAI),");
        console.log("    this creates systematic asymmetric donations to the pool");
        console.log("  - MEV bots and arbitrageurs extract the excess value");
    }

    /// @notice Demonstrates the same bug with different decimals (6-to-18).
    ///         Even with decimal normalization, only decimals are adjusted, not price.
    function test_poc_M03_different_decimals_still_no_price_adjustment() public {
        console.log("=== M-03 PoC (Part 2): Different decimals, same 1:1 price assumption ===");
        console.log("");

        // Create a 6-decimal yield-bearing prime token (e.g., a hypothetical yield-bearing USDC)
        MockERC20 primeToken6 = new MockERC20("Yield USDC", "yUSDC", 6);
        MockMintableToken phUSD18 = new MockMintableToken("phUSD", "phUSD", 18);
        MockBalancerVault vault2 = new MockBalancerVault();

        BalancerPooler pooler6 = new BalancerPooler(
            address(primeToken6),
            address(phUSD18),
            pool,
            address(vault2),
            true,
            "Pool yUSDC/phUSD",
            owner
        );

        uint256 amount = 100e6; // 100 yUSDC (6 decimals)
        primeToken6.mint(minter, amount);

        vm.prank(minter);
        primeToken6.approve(address(pooler6), type(uint256).max);

        pooler6.dispatch(minter, amount);

        uint256[] memory amounts = vault2.getLastParamsMaxAmountsIn();
        uint256 donatedPrime = amounts[0];
        uint256 donatedPhUSD = amounts[1];

        console.log("Input:  100 yUSDC (6 decimals) worth $1.05 each = $105 value");
        console.log("Prime donated (raw):  ", donatedPrime, "(100e6)");
        console.log("phUSD donated (raw):  ", donatedPhUSD, "(100e18)");
        console.log("");

        // Decimals ARE adjusted: 100e6 -> 100e18
        assertEq(donatedPrime, 100e6, "Prime in 6-decimal representation");
        assertEq(donatedPhUSD, 100e18, "phUSD normalized to 18 decimals");

        // But in human-readable units, it is still 100 prime : 100 phUSD
        // (pure decimal scaling, no price ratio applied)
        uint256 primeHumanUnits = donatedPrime / 10 ** 6; // 100
        uint256 phUSDHumanUnits = donatedPhUSD / 10 ** 18; // 100

        assertEq(
            primeHumanUnits,
            phUSDHumanUnits,
            "Human-readable units are 1:1 regardless of yield premium"
        );

        // Value asymmetry persists
        uint256 primeValueUSD = primeHumanUnits * 1.05e18; // $105
        uint256 phUSDValueUSD = phUSDHumanUnits * 1.00e18; // $100

        assertTrue(
            primeValueUSD > phUSDValueUSD,
            "Price asymmetry exists even after decimal normalization"
        );

        console.log("Human-readable: 100 prime : 100 phUSD (1:1 ratio)");
        console.log("USD value:      $105 prime : $100 phUSD (5% imbalance)");
        console.log("");
        console.log("Conclusion: Decimal normalization does NOT fix the price assumption.");
        console.log("_normalizeToPhUSD() needs an oracle to convert at market rate.");
        console.log("");
        console.log("=== VULNERABILITY CONFIRMED (different decimals case) ===");
    }

    /// @notice Shows that every single dispatch creates the asymmetry by running
    ///         multiple dispatches and verifying the 1:1 ratio each time.
    function test_poc_M03_every_dispatch_creates_asymmetry() public {
        console.log("=== M-03 PoC (Part 3): Every dispatch creates asymmetry ===");
        console.log("");

        uint256[3] memory dispatchAmounts = [uint256(50e18), 200e18, 1000e18];

        for (uint256 i = 0; i < dispatchAmounts.length; i++) {
            // Fresh vault for each dispatch to isolate measurements
            MockBalancerVault freshVault = new MockBalancerVault();
            BalancerPooler freshPooler = new BalancerPooler(
                address(primeToken),
                address(phUSDToken),
                pool,
                address(freshVault),
                true,
                "Pool sUSDS/phUSD",
                owner
            );

            uint256 amount = dispatchAmounts[i];
            primeToken.mint(minter, amount);

            vm.prank(minter);
            primeToken.approve(address(freshPooler), type(uint256).max);

            freshPooler.dispatch(minter, amount);

            uint256[] memory amounts = freshVault.getLastParamsMaxAmountsIn();

            // Every dispatch has exact 1:1 token ratio regardless of amount
            assertEq(
                amounts[0], // prime
                amounts[1], // phUSD
                "1:1 ratio maintained for every dispatch amount"
            );

            // Calculate the imbalance in USD terms
            uint256 imbalanceUSD = (amounts[0] * (PRIME_TOKEN_PRICE_USD - PHUSD_PRICE_USD)) / 1e18;

            console.log("Dispatch", i + 1, ":");
            console.log("  Amount:          ", amount);
            console.log("  Prime donated:   ", amounts[0]);
            console.log("  phUSD donated:   ", amounts[1]);
            console.log("  USD imbalance:   $", imbalanceUSD / 1e16, "(scaled 1e16)");
            console.log("");

            // Imbalance scales linearly with dispatch size
            assertTrue(imbalanceUSD > 0, "Every dispatch has non-zero imbalance");
        }

        console.log("=== CONFIRMED: Every dispatch leaks value proportional to amount ===");
    }
}
