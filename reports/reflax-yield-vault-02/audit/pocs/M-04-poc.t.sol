// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/**
 * @title M-04 PoC: Leftover Tokens After _addLiquidity Not Returned
 * @notice STANDALONE POC - No external dependencies required
 *
 * @dev Vulnerability Location: UniV4StableYieldStrategy.sol#L569-L587
 *      https://github.com/[project]/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol
 *
 * VULNERABILITY SUMMARY:
 * The _addLiquidity() function uses the minimum of normalized deposit and paired amounts
 * for liquidity calculation. When swaps result in imbalanced amounts (due to slippage,
 * price deviation, or decimal differences), the excess tokens from the larger amount
 * remain in the contract but are NOT tracked in clientDeposits or totalDeposited.
 *
 * ATTACK PATH:
 * 1. User deposits 100 USDC
 * 2. Strategy swaps 50 USDC to USDT, but due to slippage receives only 49.5 USDT
 * 3. _addLiquidity normalizes amounts: 50 USDC vs 49.5 USDT
 * 4. Uses min(50, 49.5) = 49.5 as liquidity base for BOTH tokens
 * 5. The 0.5 USDC difference remains in contract but is NOT tracked
 * 6. Over many deposits, orphaned tokens accumulate and represent value leakage
 *
 * IMPACT:
 * - Value leakage over time as orphaned tokens accumulate
 * - Users' clientDeposits underrepresent their actual contribution
 * - During migration, orphaned tokens may be lost or inappropriately distributed
 */

// ============ INLINED MOCK CONTRACTS ============

/// @notice Simplified ERC20 for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/// @notice Mock pool manager that simulates V4 behavior with slippage on swaps
contract MockPoolManager {
    MockERC20 public token0;
    MockERC20 public token1;

    // Configurable slippage (in basis points, e.g., 100 = 1%)
    uint256 public slippageBps;

    // Liquidity tracking
    uint128 public totalLiquidity;

    constructor(address _token0, address _token1, uint256 _slippageBps) {
        token0 = MockERC20(_token0);
        token1 = MockERC20(_token1);
        slippageBps = _slippageBps;
    }

    function setSlippage(uint256 _slippageBps) external {
        slippageBps = _slippageBps;
    }

    /// @notice Swap that applies slippage - user gets less than 1:1
    function swap(bool zeroForOne, uint256 amountIn) external returns (uint256 amountOut) {
        if (zeroForOne) {
            // token0 -> token1 with slippage
            token0.transferFrom(msg.sender, address(this), amountIn);
            // Apply slippage: user gets less
            amountOut = amountIn * (10000 - slippageBps) / 10000;
            token1.transfer(msg.sender, amountOut);
        } else {
            // token1 -> token0 with slippage
            token1.transferFrom(msg.sender, address(this), amountIn);
            amountOut = amountIn * (10000 - slippageBps) / 10000;
            token0.transfer(msg.sender, amountOut);
        }
    }

    /// @notice Add liquidity - takes tokens from caller
    function modifyLiquidity(uint256 amount0, uint256 amount1) external returns (uint128 liquidity) {
        // Transfer tokens to pool
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        // Calculate liquidity (simplified: just use the minimum)
        liquidity = uint128(amount0 < amount1 ? amount0 : amount1);
        totalLiquidity += liquidity;
    }
}

/// @notice Simplified yield strategy demonstrating the vulnerable pattern
contract VulnerableYieldStrategy {
    MockERC20 public depositToken;
    MockERC20 public pairedToken;
    MockPoolManager public pool;

    uint256 public totalDeposited;
    mapping(address => uint256) public clientDeposits;
    uint128 public liquidityPosition;

    address public owner;
    mapping(address => bool) public authorizedClients;

    event Deposited(address indexed client, address indexed recipient, uint256 amount, uint128 liquidityAdded);
    event LeftoverDetected(uint256 depositLeftover, uint256 pairedLeftover);

    constructor(address _depositToken, address _pairedToken, address _pool) {
        depositToken = MockERC20(_depositToken);
        pairedToken = MockERC20(_pairedToken);
        pool = MockPoolManager(_pool);
        owner = msg.sender;

        // Pre-approve pool for swaps and liquidity
        depositToken.approve(_pool, type(uint256).max);
        pairedToken.approve(_pool, type(uint256).max);
    }

    function setClient(address client, bool authorized) external {
        require(msg.sender == owner, "Only owner");
        authorizedClients[client] = authorized;
    }

    function deposit(address token, uint256 amount, address recipient) external {
        require(authorizedClients[msg.sender], "Unauthorized");
        require(token == address(depositToken), "Invalid token");
        require(amount > 0, "Zero amount");

        // Transfer deposit token from client
        depositToken.transferFrom(msg.sender, address(this), amount);

        // Swap ~50% to paired token
        uint256 halfAmount = amount / 2;
        uint256 remainingAmount = amount - halfAmount;

        // This swap may return LESS than halfAmount due to slippage
        uint256 pairedAmount = pool.swap(true, halfAmount);

        // VULNERABLE: _addLiquidity uses minimum, leaving excess untracked
        uint128 liquidityAdded = _addLiquidity(remainingAmount, pairedAmount);

        // Update state - only tracks original deposit, NOT accounting for leftovers
        liquidityPosition += liquidityAdded;
        totalDeposited += amount;
        clientDeposits[recipient] += amount;

        emit Deposited(msg.sender, recipient, amount, liquidityAdded);
    }

    /// @notice THE VULNERABLE FUNCTION
    /// Uses minimum of both amounts, leaving excess tokens untracked
    function _addLiquidity(uint256 depositAmount, uint256 pairedAmount) internal returns (uint128 liquidityAdded) {
        // Normalize to 18 decimals for liquidity calculation
        uint256 normalizedDeposit = _toStandardDecimals(depositAmount, depositToken.decimals());
        uint256 normalizedPaired = _toStandardDecimals(pairedAmount, pairedToken.decimals());

        // VULNERABILITY: Uses minimum of both for balanced liquidity
        // The excess from the larger amount is NOT tracked!
        uint256 liquidityAmount = normalizedDeposit < normalizedPaired ? normalizedDeposit : normalizedPaired;

        // Calculate how much of each token to actually use for liquidity
        uint256 depositToUse = _fromStandardDecimals(liquidityAmount, depositToken.decimals());
        uint256 pairedToUse = _fromStandardDecimals(liquidityAmount, pairedToken.decimals());

        // Calculate leftovers (for demonstration)
        uint256 depositLeftover = depositAmount > depositToUse ? depositAmount - depositToUse : 0;
        uint256 pairedLeftover = pairedAmount > pairedToUse ? pairedAmount - pairedToUse : 0;

        if (depositLeftover > 0 || pairedLeftover > 0) {
            emit LeftoverDetected(depositLeftover, pairedLeftover);
        }

        // Add liquidity to pool - only the balanced amounts are transferred
        // The LEFTOVER remains in this contract, untracked!
        pool.modifyLiquidity(depositToUse, pairedToUse);

        return uint128(liquidityAmount);
    }

    function _toStandardDecimals(uint256 amount, uint8 tokenDecimals) internal pure returns (uint256) {
        if (tokenDecimals == 18) {
            return amount;
        } else if (tokenDecimals > 18) {
            return amount / (10 ** (tokenDecimals - 18));
        } else {
            return amount * (10 ** (18 - tokenDecimals));
        }
    }

    function _fromStandardDecimals(uint256 amount, uint8 tokenDecimals) internal pure returns (uint256) {
        if (tokenDecimals == 18) {
            return amount;
        } else if (tokenDecimals > 18) {
            return amount * (10 ** (tokenDecimals - 18));
        } else {
            return amount / (10 ** (18 - tokenDecimals));
        }
    }

    /// @notice Get orphaned tokens stuck in contract (not transferred to pool)
    function getOrphanedTokens() external view returns (uint256 orphanedDeposit, uint256 orphanedPaired) {
        // Tokens held in contract that are not accounted for in liquidity
        orphanedDeposit = depositToken.balanceOf(address(this));
        orphanedPaired = pairedToken.balanceOf(address(this));
    }
}

// ============ TEST CONTRACT ============

contract M04PoCTest is Test {

    MockERC20 usdc;
    MockERC20 usdt;
    MockPoolManager pool;
    VulnerableYieldStrategy strategy;

    address owner = address(0x1234);
    address client = address(0x5678);
    address user1 = address(0xDEF0);

    function setUp() public {
        // Deploy tokens (both 6 decimals like real USDC/USDT)
        usdc = new MockERC20("USDC", "USDC", 6);
        usdt = new MockERC20("USDT", "USDT", 6);

        // Deploy pool with 1% slippage to demonstrate imbalance
        pool = new MockPoolManager(address(usdc), address(usdt), 100); // 1% slippage

        // Fund pool for swaps
        usdt.mint(address(pool), 10_000_000e6);

        // Deploy strategy
        vm.prank(owner);
        strategy = new VulnerableYieldStrategy(address(usdc), address(usdt), address(pool));

        // Authorize client
        vm.prank(owner);
        strategy.setClient(client, true);

        // Fund client with USDC
        usdc.mint(client, 10_000_000e6);

        // Client approves strategy
        vm.prank(client);
        usdc.approve(address(strategy), type(uint256).max);
    }

    // ============ PROOF OF CONCEPT ============

    /**
     * @notice Main PoC demonstrating leftover tokens not being tracked
     */
    function test_M04_LeftoverTokensNotTracked() public {
        console.log("=== M-04 PoC: Leftover Tokens After _addLiquidity Not Returned ===");
        console.log("");

        // Initial state
        uint256 depositAmount = 100e6; // 100 USDC

        console.log("Step 1: Initial Deposit Setup");
        console.log("  Deposit amount: %s USDC", depositAmount / 1e6);
        console.log("  Pool slippage: 1%%");
        console.log("");

        console.log("Step 2: Execute deposit");
        console.log("  Expected flow:");
        console.log("    - 50 USDC swapped for USDT");
        console.log("    - With 1%% slippage, receive 49.5 USDT");
        console.log("    - Remaining 50 USDC vs 49.5 USDT for liquidity");
        console.log("    - min(50, 49.5) = 49.5 used as liquidity base");
        console.log("    - 0.5 USDC LEFTOVER (not tracked!)");
        console.log("");

        // Execute deposit
        vm.prank(client);
        strategy.deposit(address(usdc), depositAmount, user1);

        // Check recorded values
        uint256 recordedDeposit = strategy.clientDeposits(user1);
        uint256 totalDeposited = strategy.totalDeposited();

        console.log("Step 3: Verify recorded values");
        console.log("  clientDeposits[user1]: %s USDC", recordedDeposit / 1e6);
        console.log("  totalDeposited: %s USDC", totalDeposited / 1e6);
        console.log("");

        // Check actual tokens remaining in contract (orphaned)
        (uint256 orphanedUsdc, uint256 orphanedUsdt) = strategy.getOrphanedTokens();

        console.log("Step 4: Check orphaned tokens in contract");
        console.log("  Orphaned USDC: %s (raw units)", orphanedUsdc);
        console.log("  Orphaned USDT: %s (raw units)", orphanedUsdt);
        console.log("");

        // CRITICAL ASSERTION: Orphaned USDC should exist
        assertTrue(orphanedUsdc > 0, "Expected orphaned USDC due to slippage imbalance");

        // With 1% slippage on 50 USDC swap:
        // - Swap 50 USDC -> get 49.5 USDT
        // - Remaining: 50 USDC, 49.5 USDT
        // - Liquidity uses min(50, 49.5) = 49.5 of each
        // - Leftover: 0.5 USDC = 500000 (in 6 decimal units)
        uint256 expectedLeftover = 500000; // 0.5 USDC

        console.log("  Expected leftover (approx): %s (0.5 USDC)", expectedLeftover);
        console.log("  Actual leftover: %s", orphanedUsdc);

        // Verify the leftover is within expected range (accounting for rounding)
        assertTrue(
            orphanedUsdc >= expectedLeftover - 10000 && orphanedUsdc <= expectedLeftover + 10000,
            "Orphaned USDC not within expected range"
        );

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("  Tokens left in contract but NOT tracked in clientDeposits!");
    }

    /**
     * @notice Demonstrate accumulation over multiple deposits
     */
    function test_M04_OrphanedTokensAccumulateOverTime() public {
        console.log("=== M-04 PoC: Orphaned Tokens Accumulate Over Multiple Deposits ===");
        console.log("");

        uint256 depositAmount = 100e6; // 100 USDC per deposit
        uint256 numDeposits = 10;

        console.log("Step 1: Perform %s deposits of %s USDC each", numDeposits, depositAmount / 1e6);
        console.log("  Pool slippage: 1%%");
        console.log("");

        for (uint256 i = 0; i < numDeposits; i++) {
            vm.prank(client);
            strategy.deposit(address(usdc), depositAmount, user1);
        }

        // Check final state
        uint256 totalRecorded = strategy.totalDeposited();
        (uint256 orphanedUsdc, uint256 orphanedUsdt) = strategy.getOrphanedTokens();

        console.log("Step 2: Final state after %s deposits", numDeposits);
        console.log("  Total deposited (recorded): %s USDC", totalRecorded / 1e6);
        console.log("  Orphaned USDC accumulated: %s (raw units)", orphanedUsdc);
        console.log("  Orphaned USDT accumulated: %s (raw units)", orphanedUsdt);
        console.log("");

        // Each deposit should leave ~0.5 USDC orphaned
        // After 10 deposits: ~5 USDC orphaned = 5000000 raw units
        uint256 expectedOrphanedPerDeposit = 500000; // 0.5 USDC
        uint256 expectedTotalOrphaned = expectedOrphanedPerDeposit * numDeposits;

        console.log("Step 3: Verify accumulation");
        console.log("  Expected orphaned per deposit: %s (0.5 USDC)", expectedOrphanedPerDeposit);
        console.log("  Expected total orphaned: %s (5 USDC)", expectedTotalOrphaned);
        console.log("  Actual orphaned: %s", orphanedUsdc);
        console.log("");

        // CRITICAL: Orphaned tokens should accumulate proportionally
        assertTrue(
            orphanedUsdc >= expectedTotalOrphaned - 100000 && orphanedUsdc <= expectedTotalOrphaned + 100000,
            "Orphaned tokens did not accumulate as expected"
        );

        // Calculate value leakage percentage
        uint256 valueLeakagePercent = (orphanedUsdc * 10000) / totalRecorded;
        console.log("  Value leakage: %s.%s%% of total deposits", valueLeakagePercent / 100, valueLeakagePercent % 100);

        assertTrue(orphanedUsdc > 0, "Expected accumulated orphaned tokens");

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED: VALUE LEAKAGE ACCUMULATES OVER TIME ===");
    }

    /**
     * @notice Demonstrate worse case with higher slippage
     */
    function test_M04_HigherSlippageWorseLeakage() public {
        console.log("=== M-04 PoC: Higher Slippage = Worse Value Leakage ===");
        console.log("");

        // Set higher slippage (5%)
        pool.setSlippage(500); // 5% slippage

        uint256 depositAmount = 1000e6; // 1000 USDC

        console.log("Step 1: Deposit with 5%% slippage");
        console.log("  Deposit amount: %s USDC", depositAmount / 1e6);
        console.log("");

        vm.prank(client);
        strategy.deposit(address(usdc), depositAmount, user1);

        (uint256 orphanedUsdc, ) = strategy.getOrphanedTokens();

        console.log("Step 2: Check orphaned tokens");
        console.log("  Orphaned USDC: %s (raw units)", orphanedUsdc);

        // With 5% slippage on 500 USDC swap:
        // - Swap 500 USDC -> get 475 USDT
        // - Remaining: 500 USDC, 475 USDT
        // - Liquidity uses min(500, 475) = 475 of each
        // - Leftover: 25 USDC = 25000000 raw units
        uint256 expectedLeftover = 25000000; // 25 USDC
        console.log("  Expected leftover: ~%s USDC = %s raw units", expectedLeftover / 1e6, expectedLeftover);
        console.log("");

        assertTrue(
            orphanedUsdc >= expectedLeftover - 100000 && orphanedUsdc <= expectedLeftover + 100000,
            "Orphaned tokens not matching high slippage expectation"
        );

        // Calculate percentage of deposit lost
        uint256 lossPercent = (orphanedUsdc * 10000) / depositAmount;
        console.log("  Untracked value: %s.%s%% of deposit", lossPercent / 100, lossPercent % 100);

        console.log("");
        console.log("=== CONFIRMED: Higher slippage leads to proportionally more orphaned tokens ===");
    }

    /**
     * @notice Verify orphaned tokens are excluded from user's tracked balance
     */
    function test_M04_OrphanedTokensExcludedFromClientBalance() public {
        console.log("=== M-04 PoC: Orphaned Tokens Excluded From Client Balance ===");
        console.log("");

        uint256 depositAmount = 100e6;

        // Deposit
        vm.prank(client);
        strategy.deposit(address(usdc), depositAmount, user1);

        uint256 clientBalance = strategy.clientDeposits(user1);
        (uint256 orphanedUsdc, ) = strategy.getOrphanedTokens();

        console.log("Step 1: Compare recorded vs actual contribution");
        console.log("  clientDeposits[user1]: %s USDC", clientBalance / 1e6);
        console.log("  Orphaned (untracked): %s raw units (~%s USDC)", orphanedUsdc, orphanedUsdc / 1e6);
        console.log("");

        // The clientDeposits shows 100 USDC, but the user's actual position
        // in the liquidity pool is worth less due to orphaned tokens
        assertTrue(
            clientBalance == depositAmount,
            "Client balance should equal full deposit amount"
        );

        assertTrue(
            orphanedUsdc > 0,
            "Should have orphaned tokens not reflected in balance"
        );

        // This creates a discrepancy between:
        // 1. What user thinks they deposited (clientDeposits = 100 USDC)
        // 2. What they actually have as LP position (~99.5 USDC worth)
        // 3. Orphaned tokens that belong to no one (~0.5 USDC)

        console.log("  DISCREPANCY:");
        console.log("    - Recorded deposit: 100 USDC");
        console.log("    - Actual LP value: ~99.5 USDC");
        console.log("    - Orphaned (lost): ~0.5 USDC");
        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
    }
}
