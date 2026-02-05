// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "vault/interfaces/IYieldStrategy.sol";
import "phlimbo-ea/interfaces/IPhlimbo.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title M-02 PoC: collectReward Call Does Not Verify Token Transfer
 * @notice Demonstrates tokens getting stuck in StableYieldAccumulator when Phlimbo's
 *         collectReward doesn't actually pull tokens
 *
 * @dev Vulnerability Location: StableYieldAccumulator.sol#L456-L457
 *      https://github.com/.../stable-yield-accumulator/src/StableYieldAccumulator.sol#L456-L457
 *
 * VULNERABILITY SUMMARY:
 * After the claimer sends payment to the accumulator via safeTransferFrom, the contract
 * calls IPhlimbo(phlimbo).collectReward(actualPayment) but does not verify that Phlimbo
 * actually received/pulled the tokens. If Phlimbo's collectReward implementation doesn't
 * actually transfer tokens (bug, paused, insufficient allowance), the tokens get stuck
 * in the StableYieldAccumulator contract indefinitely.
 *
 * ATTACK PATH:
 * 1. Claimer calls claim() on StableYieldAccumulator
 * 2. Payment tokens transferred from claimer to StableYieldAccumulator (SUCCESS)
 * 3. collectReward() called on Phlimbo
 * 4. Phlimbo's collectReward doesn't actually pull tokens (due to bug, pause, or no allowance)
 * 5. Yield distributed to claimer (SUCCESS), but payment tokens stuck in accumulator
 * 6. Phlimbo receives no tokens for staker distribution
 *
 * IMPACT:
 * - Payment tokens get stuck in StableYieldAccumulator with no recovery mechanism
 * - Stakers in Phlimbo receive no stable rewards despite yield being claimed
 * - Protocol loses value as tokens cannot be distributed
 */

// ============ MOCK CONTRACTS ============

/**
 * @title MockERC20
 * @notice Simple ERC20 mock for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title BuggyPhlimbo
 * @notice Mock Phlimbo that DOES NOT pull tokens in collectReward (simulates the bug)
 * @dev This demonstrates what happens when Phlimbo's implementation doesn't actually
 *      transfer tokens - the collectReward function succeeds but no tokens move
 */
contract BuggyPhlimbo {
    address public rewardToken;
    address public yieldAccumulator;
    uint256 public lastCollectedAmount;
    uint256 public collectRewardCallCount;

    // Flag to toggle between buggy and working behavior
    bool public buggyMode = true;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function setYieldAccumulator(address _yieldAccumulator) external {
        yieldAccumulator = _yieldAccumulator;
    }

    function setBuggyMode(bool _buggy) external {
        buggyMode = _buggy;
    }

    /**
     * @notice collectReward implementation that may NOT pull tokens
     * @dev In buggy mode: records the amount but doesn't transfer tokens
     *      In normal mode: properly pulls tokens via transferFrom
     */
    function collectReward(uint256 amount) external {
        require(msg.sender == yieldAccumulator, "Only yield accumulator can call");

        collectRewardCallCount++;
        lastCollectedAmount = amount;

        if (!buggyMode) {
            // Normal behavior: pull tokens from the yield accumulator
            IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        }
        // In buggy mode: We just record the amount but don't actually pull tokens
        // This simulates a bug where collectReward "succeeds" but doesn't transfer
    }
}

/**
 * @title MockYieldStrategy
 * @notice Mock yield strategy that provides yield for claims
 */
contract MockYieldStrategy is IYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;

    function setBalances(address token, address account, uint256 principal, uint256 yieldAmount) external {
        principals[token][account] = principal;
        yields[token][account] = yieldAmount;
    }

    function deposit(address, uint256, address) external pure override {}
    function withdraw(address, uint256, address) external pure override {}

    function balanceOf(address token, address account) external view override returns (uint256) {
        return principals[token][account] + yields[token][account];
    }

    function principalOf(address token, address account) external view override returns (uint256) {
        return principals[token][account];
    }

    function totalBalanceOf(address token, address account) external view override returns (uint256) {
        return principals[token][account] + yields[token][account];
    }

    function setClient(address, bool) external pure override {}
    function emergencyWithdraw(uint256) external pure override {}
    function totalWithdrawal(address, address) external pure override {}

    function withdrawFrom(
        address token,
        address,
        uint256 amount,
        address recipient
    ) external override {
        // Transfer yield tokens to recipient (claimer)
        IERC20(token).transfer(recipient, amount);
    }
}

/**
 * @title M02PoCTest
 * @notice Proof of Concept demonstrating tokens stuck when collectReward doesn't pull
 */
contract M02PoCTest is Test {
    StableYieldAccumulator public accumulator;
    MockERC20 public rewardToken;  // USDC - what claimer pays
    MockERC20 public strategyToken; // USDT - what yield strategy pays out
    MockYieldStrategy public yieldStrategy;
    BuggyPhlimbo public buggyPhlimbo;

    address public owner;
    address public claimer;
    address public minter;

    uint256 constant YIELD_AMOUNT = 100e18;  // 100 tokens of yield available
    uint256 constant DISCOUNT_RATE = 200;    // 2% discount

    function setUp() public {
        owner = address(this);
        claimer = makeAddr("claimer");
        minter = makeAddr("minter");

        // Deploy mock tokens
        rewardToken = new MockERC20("USDC", "USDC");
        strategyToken = new MockERC20("USDT", "USDT");

        // Deploy buggy Phlimbo
        buggyPhlimbo = new BuggyPhlimbo(address(rewardToken));

        // Deploy yield strategy
        yieldStrategy = new MockYieldStrategy();

        // Deploy accumulator
        accumulator = new StableYieldAccumulator();

        // Configure accumulator
        accumulator.setRewardToken(address(rewardToken));
        accumulator.setPhlimbo(address(buggyPhlimbo));
        accumulator.setMinter(minter);
        accumulator.setDiscountRate(DISCOUNT_RATE);

        // Configure token configs (18 decimals, 1:1 exchange rate)
        accumulator.setTokenConfig(address(rewardToken), 18, 1e18);
        accumulator.setTokenConfig(address(strategyToken), 18, 1e18);

        // Register yield strategy
        accumulator.addYieldStrategy(address(yieldStrategy), address(strategyToken));

        // Setup Phlimbo to accept calls from accumulator
        buggyPhlimbo.setYieldAccumulator(address(accumulator));

        // Give accumulator approval to Phlimbo (but Phlimbo won't use it in buggy mode)
        accumulator.approvePhlimbo(type(uint256).max);

        // Setup yield in strategy
        yieldStrategy.setBalances(address(strategyToken), minter, 1000e18, YIELD_AMOUNT);

        // Fund strategy with tokens to pay out
        strategyToken.mint(address(yieldStrategy), YIELD_AMOUNT);

        // Fund claimer with reward tokens to pay
        uint256 paymentNeeded = (YIELD_AMOUNT * (10000 - DISCOUNT_RATE)) / 10000;
        rewardToken.mint(claimer, paymentNeeded);

        // Claimer approves accumulator
        vm.prank(claimer);
        rewardToken.approve(address(accumulator), type(uint256).max);
    }

    /**
     * @notice Main PoC demonstrating the vulnerability
     * @dev Shows that when Phlimbo's collectReward doesn't pull tokens,
     *      they get stuck in the accumulator
     */
    function test_M02_TokensStuckWhenCollectRewardDoesNotPull() public {
        console.log("=== M-02 PoC: collectReward Call Does Not Verify Token Transfer ===");
        console.log("");

        // Calculate expected payment (with 2% discount)
        uint256 expectedPayment = (YIELD_AMOUNT * (10000 - DISCOUNT_RATE)) / 10000;
        console.log("Yield available:", YIELD_AMOUNT / 1e18, "tokens");
        console.log("Expected payment (98%):", expectedPayment / 1e18, "tokens");
        console.log("");

        // Record initial balances
        uint256 claimerRewardBefore = rewardToken.balanceOf(claimer);
        uint256 claimerYieldBefore = strategyToken.balanceOf(claimer);
        uint256 accumulatorBefore = rewardToken.balanceOf(address(accumulator));
        uint256 phlimboBefore = rewardToken.balanceOf(address(buggyPhlimbo));

        console.log("=== BEFORE CLAIM ===");
        console.log("Claimer reward token balance:", claimerRewardBefore / 1e18);
        console.log("Claimer yield token balance:", claimerYieldBefore / 1e18);
        console.log("Accumulator reward token balance:", accumulatorBefore / 1e18);
        console.log("Phlimbo reward token balance:", phlimboBefore / 1e18);
        console.log("");

        // Step 1: Claimer calls claim() - this should succeed even with buggy Phlimbo
        console.log("Step 1: Claimer calls claim()");
        vm.prank(claimer);
        accumulator.claim();
        console.log("  -> Claim succeeded!");
        console.log("");

        // Record balances after claim
        uint256 claimerRewardAfter = rewardToken.balanceOf(claimer);
        uint256 claimerYieldAfter = strategyToken.balanceOf(claimer);
        uint256 accumulatorAfter = rewardToken.balanceOf(address(accumulator));
        uint256 phlimboAfter = rewardToken.balanceOf(address(buggyPhlimbo));

        console.log("=== AFTER CLAIM ===");
        console.log("Claimer reward token balance:", claimerRewardAfter / 1e18);
        console.log("Claimer yield token balance:", claimerYieldAfter / 1e18);
        console.log("Accumulator reward token balance:", accumulatorAfter / 1e18);
        console.log("Phlimbo reward token balance:", phlimboAfter / 1e18);
        console.log("");

        // Step 2: Verify claimer received yield tokens (the claim "worked")
        console.log("Step 2: Verify claimer received yield tokens");
        assertEq(claimerYieldAfter, YIELD_AMOUNT, "Claimer should receive yield");
        console.log("  -> Claimer received", claimerYieldAfter / 1e18, "yield tokens");
        console.log("");

        // Step 3: Verify claimer paid reward tokens
        console.log("Step 3: Verify claimer paid reward tokens");
        assertEq(claimerRewardBefore - claimerRewardAfter, expectedPayment, "Claimer should pay");
        console.log("  -> Claimer paid", (claimerRewardBefore - claimerRewardAfter) / 1e18, "reward tokens");
        console.log("");

        // Step 4: THE BUG - Verify Phlimbo received NOTHING
        console.log("Step 4: THE BUG - Verify Phlimbo received NOTHING");
        assertEq(phlimboAfter, 0, "Phlimbo received nothing!");
        console.log("  -> Phlimbo balance: 0 (expected to receive", expectedPayment / 1e18, "tokens)");
        console.log("");

        // Step 5: THE BUG - Verify tokens are STUCK in accumulator
        console.log("Step 5: Verify tokens are STUCK in accumulator");
        assertEq(accumulatorAfter, expectedPayment, "Tokens stuck in accumulator!");
        console.log("  -> Accumulator balance:", accumulatorAfter / 1e18, "tokens (STUCK!)");
        console.log("");

        // Step 6: Verify collectReward was called (so the accumulator thinks it worked)
        console.log("Step 6: Verify collectReward was called on Phlimbo");
        assertEq(buggyPhlimbo.collectRewardCallCount(), 1, "collectReward was called");
        assertEq(buggyPhlimbo.lastCollectedAmount(), expectedPayment, "Correct amount passed");
        console.log("  -> collectReward was called with amount:", buggyPhlimbo.lastCollectedAmount() / 1e18);
        console.log("  -> But Phlimbo didn't actually pull the tokens!");
        console.log("");

        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Impact:");
        console.log("  1. Claimer received yield tokens (claim worked from their perspective)");
        console.log("  2. Payment tokens (", expectedPayment / 1e18, ") are stuck in accumulator");
        console.log("  3. Phlimbo stakers receive NO stable rewards");
        console.log("  4. No recovery mechanism exists for stuck tokens");
    }

    /**
     * @notice Demonstrates that with proper Phlimbo, tokens flow correctly
     * @dev Shows the expected behavior when collectReward actually pulls tokens
     */
    function test_M02_CompareWithWorkingPhlimbo() public {
        console.log("=== Comparison: Working Phlimbo vs Buggy Phlimbo ===");
        console.log("");

        // Switch to working mode
        buggyPhlimbo.setBuggyMode(false);
        console.log("Testing with WORKING Phlimbo (buggyMode = false)");

        uint256 expectedPayment = (YIELD_AMOUNT * (10000 - DISCOUNT_RATE)) / 10000;

        vm.prank(claimer);
        accumulator.claim();

        uint256 accumulatorBalance = rewardToken.balanceOf(address(accumulator));
        uint256 phlimboBalance = rewardToken.balanceOf(address(buggyPhlimbo));

        console.log("After claim with working Phlimbo:");
        console.log("  Accumulator balance (should be 0):", accumulatorBalance / 1e18);
        console.log("  Phlimbo balance (should be", expectedPayment / 1e18, "):");
        console.log("  Actual Phlimbo balance:", phlimboBalance / 1e18);

        // With working Phlimbo, accumulator should be empty and Phlimbo should have tokens
        assertEq(accumulatorBalance, 0, "Accumulator should be empty");
        assertEq(phlimboBalance, expectedPayment, "Phlimbo should have tokens");

        console.log("");
        console.log("=== CONCLUSION ===");
        console.log("The vulnerability exists because StableYieldAccumulator does not verify");
        console.log("that collectReward actually transferred the tokens. A simple balance");
        console.log("check before/after would detect this failure.");
    }

    /**
     * @notice Shows multiple claims compound the stuck token problem
     */
    function test_M02_MultipleClaimsAccumulateStuckTokens() public {
        console.log("=== Multiple Claims Accumulate Stuck Tokens ===");
        console.log("");

        uint256 expectedPaymentPerClaim = (YIELD_AMOUNT * (10000 - DISCOUNT_RATE)) / 10000;

        // Perform 3 claims
        for (uint256 i = 0; i < 3; i++) {
            // Reset yield for next claim
            yieldStrategy.setBalances(address(strategyToken), minter, 1000e18, YIELD_AMOUNT);
            strategyToken.mint(address(yieldStrategy), YIELD_AMOUNT);
            rewardToken.mint(claimer, expectedPaymentPerClaim);

            vm.prank(claimer);
            accumulator.claim();

            console.log("After claim", i + 1, ":");
            console.log("  Stuck tokens in accumulator:", rewardToken.balanceOf(address(accumulator)) / 1e18);
        }

        uint256 totalStuck = rewardToken.balanceOf(address(accumulator));
        assertEq(totalStuck, expectedPaymentPerClaim * 3, "All payments stuck");

        console.log("");
        console.log("Total stuck after 3 claims:", totalStuck / 1e18, "tokens");
        console.log("These tokens are unrecoverable!");
    }
}
