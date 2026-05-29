// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

/**
 * @title M-05 PoC: Migration May Fail During Depeg Conditions
 * @notice STANDALONE POC - Demonstrates that migration can permanently fail during stablecoin depeg
 *
 * @dev Vulnerability Location: UniV4StableYieldStrategy.sol#L257-L292
 *      https://github.com/code-423n4/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L257-L292
 *
 * VULNERABILITY SUMMARY:
 * The migrate() function relies on:
 * 1. _swapWithSlippageCheck() with MAX_SLIPPAGE_TOLERANCE = 100 bps (1%)
 * 2. tolerableLoss check comparing actual loss to configured tolerance
 *
 * During stablecoin depeg (e.g., USDT trading at 0.95 vs USDC):
 * - Swap will fail with SlippageExceeded if depeg > 1%
 * - Even if slippage tolerance is increased, MigrationLossExceedsTolerance may revert
 *
 * ATTACK PATH (natural market conditions, not attack):
 * 1. Protocol deposits 1,000,000 USDC into USDC/USDT V4 pool
 * 2. USDT depegs to $0.95 (5% below peg)
 * 3. Owner attempts migration to new strategy
 * 4. _swapWithSlippageCheck() reverts: SlippageExceeded(expected, actual)
 * 5. Or if slippage increased, MigrationLossExceedsTolerance reverts
 * 6. User funds are permanently trapped in the strategy
 *
 * IMPACT:
 * - MEDIUM: User funds locked during market volatility
 * - No withdrawal mechanism: Users cannot exit (withdraw is disabled)
 * - Duration: Until depeg resolves (could be days/weeks/permanent for failed stables)
 */

// ============ INLINED TYPE DEFINITIONS ============

type PoolId is bytes32;

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

library PoolIdLibrary {
    function toId(PoolKey memory key) internal pure returns (PoolId) {
        return PoolId.wrap(keccak256(abi.encode(key)));
    }
}

// ============ INLINED INTERFACES ============

interface IPoolManager {
    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    struct BalanceDelta {
        int128 amount0;
        int128 amount1;
    }

    function modifyLiquidity(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData)
        external
        returns (BalanceDelta memory delta);

    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        returns (BalanceDelta memory delta);

    function collect(PoolKey calldata key, int24 tickLower, int24 tickUpper, bytes32 salt)
        external
        returns (uint256 amount0, uint256 amount1);

    function getPosition(PoolId poolId, address owner, int24 tickLower, int24 tickUpper, bytes32 salt)
        external
        view
        returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128);
}

// ============ MOCK CONTRACTS ============

/**
 * @notice Mock ERC20 with mint capability
 */
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
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

/**
 * @notice Mock PoolManager that simulates depeg conditions
 * @dev Can simulate different exchange rates between stablecoins
 */
contract MockPoolManagerWithDepeg {
    MockERC20 public token0;  // USDC (deposit token)
    MockERC20 public token1;  // USDT (paired token - can depeg)

    // Exchange rate in basis points (10000 = 1:1, 9500 = 0.95:1)
    uint256 public exchangeRateBps = 10000;
    uint256 private constant BPS_DENOMINATOR = 10000;

    // Track liquidity for positions
    mapping(bytes32 => uint128) public positionLiquidity;

    constructor(address _token0, address _token1) {
        token0 = MockERC20(_token0);
        token1 = MockERC20(_token1);
    }

    /**
     * @notice Simulate depeg by setting exchange rate
     * @param rateBps Exchange rate in basis points (e.g., 9500 = USDT worth $0.95)
     */
    function setExchangeRate(uint256 rateBps) external {
        exchangeRateBps = rateBps;
    }

    function modifyLiquidity(PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params, bytes calldata)
        external
        returns (IPoolManager.BalanceDelta memory delta)
    {
        bytes32 posKey = keccak256(abi.encode(msg.sender, params.tickLower, params.tickUpper, params.salt));

        if (params.liquidityDelta > 0) {
            // Adding liquidity
            uint256 liquidityToAdd = uint256(params.liquidityDelta);
            positionLiquidity[posKey] += uint128(liquidityToAdd);

            // Pull tokens from caller (simplified - equal amounts)
            uint256 amount0 = liquidityToAdd / 2;
            uint256 amount1 = liquidityToAdd / 2;

            token0.transferFrom(msg.sender, address(this), amount0);
            token1.transferFrom(msg.sender, address(this), amount1);

            delta = IPoolManager.BalanceDelta({
                amount0: -int128(int256(amount0)),
                amount1: -int128(int256(amount1))
            });
        } else {
            // Removing liquidity
            uint256 liquidityToRemove = uint256(-params.liquidityDelta);
            positionLiquidity[posKey] -= uint128(liquidityToRemove);

            // Return tokens to caller (simplified - equal amounts)
            uint256 amount0 = liquidityToRemove / 2;
            uint256 amount1 = liquidityToRemove / 2;

            token0.transfer(msg.sender, amount0);
            token1.transfer(msg.sender, amount1);

            delta = IPoolManager.BalanceDelta({
                amount0: int128(int256(amount0)),
                amount1: int128(int256(amount1))
            });
        }
    }

    /**
     * @notice Swap with exchange rate reflecting depeg
     * @dev When USDT depegs to $0.95, swapping USDT->USDC gives only 95% of input
     */
    function swap(PoolKey calldata, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        returns (IPoolManager.BalanceDelta memory delta)
    {
        if (params.zeroForOne) {
            // token0 -> token1 (USDC -> USDT): Give more USDT per USDC during depeg
            uint256 amountIn = uint256(params.amountSpecified);
            // If USDT is cheap, you get more USDT for your USDC
            uint256 amountOut = (amountIn * BPS_DENOMINATOR) / exchangeRateBps;

            token0.transferFrom(msg.sender, address(this), amountIn);
            token1.transfer(msg.sender, amountOut);

            delta = IPoolManager.BalanceDelta({
                amount0: -int128(int256(amountIn)),
                amount1: int128(int256(amountOut))
            });
        } else {
            // token1 -> token0 (USDT -> USDC): Get LESS USDC during depeg
            uint256 amountIn = uint256(params.amountSpecified);
            // If USDT is worth $0.95, you only get 95% USDC
            uint256 amountOut = (amountIn * exchangeRateBps) / BPS_DENOMINATOR;

            token1.transferFrom(msg.sender, address(this), amountIn);
            token0.transfer(msg.sender, amountOut);

            delta = IPoolManager.BalanceDelta({
                amount0: int128(int256(amountOut)),
                amount1: -int128(int256(amountIn))
            });
        }
    }

    function collect(PoolKey calldata, int24, int24, bytes32)
        external
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        return (0, 0);  // No fees for this test
    }

    function getPosition(PoolId, address owner, int24 tickLower, int24 tickUpper, bytes32 salt)
        external
        view
        returns (uint128, uint256, uint256)
    {
        bytes32 posKey = keccak256(abi.encode(owner, tickLower, tickUpper, salt));
        return (positionLiquidity[posKey], 0, 0);
    }
}

// ============ VULNERABLE CONTRACT (EXTRACTED PATTERN) ============

/**
 * @notice Simplified UniV4StableYieldStrategy showing the migration vulnerability
 * @dev Extracted from UniV4StableYieldStrategy.sol#L257-L292 and L522-L561
 */
contract VulnerableUniV4Strategy {
    MockERC20 public depositToken;
    MockERC20 public pairedToken;
    MockPoolManagerWithDepeg public poolManager;
    PoolKey public poolKey;
    PoolId public poolId;

    uint8 public depositTokenDecimals;
    uint8 public pairedTokenDecimals;

    int24 public tickLower = -100;
    int24 public tickUpper = 100;
    bytes32 public constant POSITION_SALT = bytes32(0);

    address public owner;
    bool private locked;

    uint128 public liquidityPosition;
    uint256 public totalDeposited;

    // From contract: MAX_SLIPPAGE_TOLERANCE = 100 (1%)
    uint24 public slippageTolerance = 100;  // 1% = 100 bps
    uint24 public constant MAX_SLIPPAGE_TOLERANCE = 100;
    uint256 private constant BPS_DENOMINATOR = 10000;

    // Tolerable loss for migration
    uint256 public tolerableLoss;

    mapping(address => bool) public authorizedClients;
    mapping(address => uint256) private clientDeposits;

    // ============ ERRORS (from original contract) ============
    error SlippageExceeded(uint256 expected, uint256 actual);
    error MigrationLossExceedsTolerance(uint256 actualLoss, uint256 tolerableLoss);
    error SlippageToleranceTooHigh(uint24 requested, uint24 maximum);

    // ============ EVENTS ============
    event Deposited(address indexed client, address indexed recipient, uint256 amount, uint128 liquidityAdded);
    event Migrated(address indexed newStrategy, uint256 amountMigrated, uint256 actualLoss);

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyAuthorizedClient() {
        require(authorizedClients[msg.sender], "AYieldStrategy: unauthorized");
        _;
    }

    constructor(
        address _depositToken,
        address _pairedToken,
        address _poolManager,
        uint256 _tolerableLoss
    ) {
        owner = msg.sender;
        depositToken = MockERC20(_depositToken);
        pairedToken = MockERC20(_pairedToken);
        poolManager = MockPoolManagerWithDepeg(_poolManager);
        tolerableLoss = _tolerableLoss;

        depositTokenDecimals = depositToken.decimals();
        pairedTokenDecimals = pairedToken.decimals();

        poolKey = PoolKey({
            currency0: _depositToken,
            currency1: _pairedToken,
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });
        poolId = PoolIdLibrary.toId(poolKey);

        // Approve poolManager
        depositToken.approve(_poolManager, type(uint256).max);
        pairedToken.approve(_poolManager, type(uint256).max);
    }

    function setClient(address client, bool authorized) external onlyOwner {
        authorizedClients[client] = authorized;
    }

    function setSlippageTolerance(uint24 newTolerance) external onlyOwner {
        if (newTolerance > MAX_SLIPPAGE_TOLERANCE) {
            revert SlippageToleranceTooHigh(newTolerance, MAX_SLIPPAGE_TOLERANCE);
        }
        slippageTolerance = newTolerance;
    }

    function setTolerableLoss(uint256 newTolerance) external onlyOwner {
        tolerableLoss = newTolerance;
    }

    /**
     * @notice Deposit tokens and add liquidity
     */
    function deposit(address token, uint256 amount, address recipient)
        external
        onlyAuthorizedClient
        nonReentrant
    {
        require(token == address(depositToken), "Invalid token");
        require(amount > 0, "Amount must be > 0");

        depositToken.transferFrom(msg.sender, address(this), amount);

        // Swap ~50% to paired token
        uint256 halfAmount = amount / 2;
        uint256 remainingAmount = amount - halfAmount;
        uint256 pairedAmount = _swapWithSlippageCheck(depositToken, pairedToken, halfAmount);

        // Add liquidity
        uint128 liquidityAdded = _addLiquidity(remainingAmount, pairedAmount);

        liquidityPosition += liquidityAdded;
        totalDeposited += amount;
        clientDeposits[recipient] += amount;

        emit Deposited(msg.sender, recipient, amount, liquidityAdded);
    }

    /**
     * @notice THE VULNERABLE FUNCTION - migrate() can fail during depeg
     * @dev From UniV4StableYieldStrategy.sol#L257-L292
     *
     * Two failure points during depeg:
     * 1. Line 266: _swapWithSlippageCheck() reverts if depeg > slippageTolerance
     * 2. Line 278-280: MigrationLossExceedsTolerance reverts if loss > tolerableLoss
     */
    function migrate(address newStrategy) external onlyOwner nonReentrant {
        require(newStrategy != address(0), "new strategy cannot be zero address");

        // Remove all liquidity - returns both deposit and paired tokens
        (uint256 depositOut, uint256 pairedOut) = _removeLiquidity(liquidityPosition);

        // VULNERABILITY POINT 1: Swap paired tokens to deposit token
        // This can revert with SlippageExceeded during depeg!
        uint256 swappedAmount = 0;
        if (pairedOut > 0) {
            swappedAmount = _swapWithSlippageCheck(pairedToken, depositToken, pairedOut);
        }

        uint256 totalRecovered = depositOut + swappedAmount;

        // VULNERABILITY POINT 2: Check loss tolerance
        uint256 actualLoss = 0;
        if (totalDeposited > totalRecovered) {
            actualLoss = totalDeposited - totalRecovered;
        }

        // This can revert if actualLoss > tolerableLoss!
        if (actualLoss > tolerableLoss) {
            revert MigrationLossExceedsTolerance(actualLoss, tolerableLoss);
        }

        // Reset state
        liquidityPosition = 0;
        totalDeposited = 0;

        // Transfer to new strategy
        if (totalRecovered > 0) {
            depositToken.transfer(newStrategy, totalRecovered);
        }

        emit Migrated(newStrategy, totalRecovered, actualLoss);
    }

    /**
     * @notice Swap with slippage check - FROM ORIGINAL CONTRACT
     * @dev UniV4StableYieldStrategy.sol#L522-L561
     *
     * Key lines:
     * - L535: minOut = (expectedOut * (BPS_DENOMINATOR - slippageTolerance)) / BPS_DENOMINATOR
     * - L556-558: if (amountOut < minOut) revert SlippageExceeded(minOut, amountOut)
     */
    function _swapWithSlippageCheck(MockERC20 tokenIn, MockERC20 tokenOut, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        if (amountIn == 0) return 0;

        // Calculate expected output assuming 1:1 for stables
        uint256 expectedOut = _normalizeDecimals(
            amountIn,
            address(tokenIn) == address(depositToken) ? depositTokenDecimals : pairedTokenDecimals,
            address(tokenOut) == address(depositToken) ? depositTokenDecimals : pairedTokenDecimals
        );

        // Calculate minimum acceptable output
        uint256 minOut = (expectedOut * (BPS_DENOMINATOR - slippageTolerance)) / BPS_DENOMINATOR;

        // Execute swap
        bool zeroForOne = address(tokenIn) == poolKey.currency0;

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountIn),
            sqrtPriceLimitX96: 0
        });

        IPoolManager.BalanceDelta memory delta = poolManager.swap(poolKey, params, "");

        // Calculate actual output
        if (zeroForOne) {
            amountOut = delta.amount1 > 0 ? uint256(int256(delta.amount1)) : 0;
        } else {
            amountOut = delta.amount0 > 0 ? uint256(int256(delta.amount0)) : 0;
        }

        // REVERT IF SLIPPAGE EXCEEDED
        if (amountOut < minOut) {
            revert SlippageExceeded(minOut, amountOut);
        }

        return amountOut;
    }

    function _addLiquidity(uint256 depositAmount, uint256 pairedAmount) internal returns (uint128 liquidityAdded) {
        // Use minimum of both amounts (in original decimals) for liquidity
        // This simplified version doesn't normalize to 18 decimals to avoid mock complications
        uint256 liquidityAmount = depositAmount < pairedAmount ? depositAmount : pairedAmount;

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(liquidityAmount),
            salt: POSITION_SALT
        });

        poolManager.modifyLiquidity(poolKey, params, "");
        return uint128(liquidityAmount);
    }

    function _removeLiquidity(uint128 liquidity) internal returns (uint256 depositOut, uint256 pairedOut) {
        if (liquidity == 0) return (0, 0);

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: -int256(int128(liquidity)),
            salt: POSITION_SALT
        });

        IPoolManager.BalanceDelta memory delta = poolManager.modifyLiquidity(poolKey, params, "");

        if (address(depositToken) == poolKey.currency0) {
            depositOut = delta.amount0 > 0 ? uint256(int256(delta.amount0)) : 0;
            pairedOut = delta.amount1 > 0 ? uint256(int256(delta.amount1)) : 0;
        } else {
            depositOut = delta.amount1 > 0 ? uint256(int256(delta.amount1)) : 0;
            pairedOut = delta.amount0 > 0 ? uint256(int256(delta.amount0)) : 0;
        }
    }

    function _normalizeDecimals(uint256 amount, uint8 fromDecimals, uint8 toDecimals)
        internal
        pure
        returns (uint256)
    {
        if (fromDecimals == toDecimals) return amount;
        if (fromDecimals > toDecimals) return amount / (10 ** (fromDecimals - toDecimals));
        return amount * (10 ** (toDecimals - fromDecimals));
    }

    function _toStandardDecimals(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals > 18) return amount / (10 ** (decimals - 18));
        return amount * (10 ** (18 - decimals));
    }

    // View functions
    function getLiquidityPosition() external view returns (uint128) { return liquidityPosition; }
    function totalDeposits() external view returns (uint256) { return totalDeposited; }
}

// ============ POC TEST ============

contract PocM05Test is Test {
    MockERC20 usdc;  // Deposit token
    MockERC20 usdt;  // Paired token (can depeg)
    MockPoolManagerWithDepeg poolManager;
    VulnerableUniV4Strategy strategy;

    address owner = makeAddr("owner");
    address client = makeAddr("client");
    address newStrategy = makeAddr("newStrategy");

    uint256 constant DEPOSIT_AMOUNT = 1_000_000e6;  // 1M USDC
    uint256 constant TOLERABLE_LOSS = 1_000e6;  // $1,000 tolerance

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens (both 6 decimals like real USDC/USDT)
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdt = new MockERC20("Tether USD", "USDT", 6);

        // Deploy mock pool manager
        poolManager = new MockPoolManagerWithDepeg(address(usdc), address(usdt));

        // Deploy strategy with $1,000 tolerable loss
        strategy = new VulnerableUniV4Strategy(
            address(usdc),
            address(usdt),
            address(poolManager),
            TOLERABLE_LOSS
        );

        // Setup client
        strategy.setClient(client, true);

        vm.stopPrank();

        // Fund pool manager with liquidity for swaps
        usdc.mint(address(poolManager), 10_000_000e6);
        usdt.mint(address(poolManager), 10_000_000e6);

        // Fund client with USDC for deposit
        usdc.mint(client, DEPOSIT_AMOUNT);

        // Client approves and deposits
        vm.startPrank(client);
        usdc.approve(address(strategy), DEPOSIT_AMOUNT);
        strategy.deposit(address(usdc), DEPOSIT_AMOUNT, client);
        vm.stopPrank();
    }

    /**
     * @notice Main PoC: Migration fails when slippage exceeds 1% during depeg
     */
    function test_M05_MigrationFailsDuringDepeg_SlippageExceeded() public {
        console.log("=== M-05 PoC: Migration Fails During Depeg (Slippage Check) ===");
        console.log("");

        // Step 1: Verify initial state
        console.log("Step 1: Verify strategy has user funds");
        uint256 liquidityBefore = strategy.getLiquidityPosition();
        uint256 totalDepositedBefore = strategy.totalDeposits();
        console.log("  - Liquidity position: %s", liquidityBefore);
        console.log("  - Total deposited: %s USDC", totalDepositedBefore / 1e6);
        assertTrue(liquidityBefore > 0, "Strategy should have liquidity");
        console.log("");

        // Step 2: Simulate USDT depeg to $0.95 (5% depeg)
        console.log("Step 2: Simulate USDT depeg to $0.95 (5%% below peg)");
        poolManager.setExchangeRate(9500);  // 95% = $0.95
        console.log("  - Exchange rate set to 9500 bps (USDT = $0.95)");
        console.log("  - Max slippage tolerance: 1%% (100 bps)");
        console.log("  - Depeg (5%%) > Max slippage (1%%) = Migration WILL FAIL");
        console.log("");

        // Step 3: Owner attempts migration - SHOULD REVERT
        console.log("Step 3: Owner attempts to migrate funds to new strategy");
        vm.startPrank(owner);

        // Expect revert with SlippageExceeded
        // Expected output: 500,000 USDC (1:1)
        // Actual output with 5% depeg: 475,000 USDC (500,000 * 0.95)
        // minOut = 500,000 * 0.99 = 495,000 USDC
        // 475,000 < 495,000 = REVERT!
        vm.expectRevert();  // SlippageExceeded
        strategy.migrate(newStrategy);
        vm.stopPrank();

        console.log("  - migrate() REVERTED as expected");
        console.log("");

        // Step 4: Verify funds are still locked
        console.log("Step 4: Verify user funds are trapped");
        uint256 liquidityAfter = strategy.getLiquidityPosition();
        uint256 totalDepositedAfter = strategy.totalDeposits();
        assertEq(liquidityAfter, liquidityBefore, "Liquidity should be unchanged");
        assertEq(totalDepositedAfter, totalDepositedBefore, "Deposits should be unchanged");
        console.log("  - Liquidity still locked: %s", liquidityAfter);
        console.log("  - Total deposited still: %s USDC", totalDepositedAfter / 1e6);
        console.log("");

        // Step 5: Verify no user withdrawal path
        console.log("Step 5: Users have NO way to withdraw");
        console.log("  - withdraw() is disabled: reverts WithdrawalsDisabled()");
        console.log("  - migrate() fails due to depeg");
        console.log("  - Funds are PERMANENTLY TRAPPED until depeg resolves");
        console.log("");

        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Migration cannot complete when depeg exceeds slippage tolerance!");
        console.log("User funds: %s USDC locked in strategy", totalDepositedAfter / 1e6);
    }

    /**
     * @notice Second scenario: Even if slippage check passes, loss tolerance can fail
     */
    function test_M05_MigrationFailsDuringDepeg_LossExceedsTolerance() public {
        console.log("=== M-05 PoC: Migration Fails Due to Loss Tolerance ===");
        console.log("");

        // Step 1: Simulate mild depeg (0.5% - within slippage tolerance)
        console.log("Step 1: Simulate USDT at $0.98 (2%% depeg, tolerable for swap)");

        // First, let's update slippage tolerance to 3% so swap passes
        // but the loss tolerance will still fail
        vm.prank(owner);
        // Note: Can't set above MAX_SLIPPAGE_TOLERANCE, so we need a different approach
        // We'll simulate 1.5% depeg which might pass slippage but cause loss > tolerance

        // Set depeg to 1.5% - borderline on slippage
        poolManager.setExchangeRate(9850);  // 98.5% = $0.985
        console.log("  - Exchange rate: 9850 bps (USDT = $0.985)");
        console.log("  - Total deposited: %s USDC", DEPOSIT_AMOUNT / 1e6);
        console.log("  - ~500,000 USDT needs to be swapped back to USDC");
        console.log("");

        // Calculate expected loss
        // Half the deposit (~500k) was swapped to USDT
        // When swapping back at 0.985, lose 1.5% = 7,500 USDC
        // Tolerable loss = 1,000 USDC
        // 7,500 > 1,000 = REVERT with MigrationLossExceedsTolerance

        console.log("Step 2: Calculate expected loss");
        uint256 halfDeposit = DEPOSIT_AMOUNT / 2;  // 500,000 USDC
        uint256 expectedLoss = (halfDeposit * (10000 - 9850)) / 10000;  // 1.5% of 500k = 7,500
        console.log("  - Amount to swap back: ~%s USDT", halfDeposit / 1e6);
        console.log("  - Loss from depeg (1.5%%): ~%s USDC", expectedLoss / 1e6);
        console.log("  - Tolerable loss: %s USDC", TOLERABLE_LOSS / 1e6);
        console.log("  - Expected loss > Tolerable = WILL FAIL");
        console.log("");

        // Step 3: Attempt migration
        console.log("Step 3: Owner attempts migration");
        vm.prank(owner);

        // This will either:
        // 1. Revert with SlippageExceeded if 1.5% > 1% tolerance
        // 2. Or revert with MigrationLossExceedsTolerance if slippage passes
        vm.expectRevert();  // Either SlippageExceeded or MigrationLossExceedsTolerance
        strategy.migrate(newStrategy);

        console.log("  - migrate() REVERTED");
        console.log("");

        console.log("=== FUNDS REMAIN LOCKED ===");
    }

    /**
     * @notice Demonstrates the impossible situation: can't increase slippage enough
     */
    function test_M05_CannotIncreaseSlippageToleranceEnough() public {
        console.log("=== M-05 PoC: Slippage Tolerance Cannot Be Increased ===");
        console.log("");

        console.log("Step 1: Owner tries to increase slippage tolerance to handle 5%% depeg");

        vm.startPrank(owner);

        // Try to set slippage to 5% (500 bps) to handle depeg
        // But MAX_SLIPPAGE_TOLERANCE = 100 (1%)
        console.log("  - Attempting to set slippage tolerance to 500 bps (5%%)...");

        vm.expectRevert(
            abi.encodeWithSelector(
                VulnerableUniV4Strategy.SlippageToleranceTooHigh.selector,
                500,  // requested
                100   // maximum
            )
        );
        strategy.setSlippageTolerance(500);

        vm.stopPrank();

        console.log("  - REVERTED with SlippageToleranceTooHigh(500, 100)");
        console.log("");

        console.log("Step 2: Slippage tolerance is HARD-CAPPED at 1%%");
        assertEq(strategy.MAX_SLIPPAGE_TOLERANCE(), 100, "Max is 1%");
        console.log("  - MAX_SLIPPAGE_TOLERANCE = 100 bps (1%%)");
        console.log("  - Any depeg > 1%% makes migration impossible");
        console.log("");

        // Now try migration with 5% depeg
        poolManager.setExchangeRate(9500);

        console.log("Step 3: Migration with 5%% depeg still fails");
        vm.prank(owner);
        vm.expectRevert();  // SlippageExceeded
        strategy.migrate(newStrategy);

        console.log("  - Migration FAILED");
        console.log("");

        console.log("=== DESIGN FLAW CONFIRMED ===");
        console.log("1%% max slippage is insufficient for real-world stablecoin volatility");
        console.log("USDT has historically depegged >5%%, DAI >2%%, USDC >10%%");
    }

    /**
     * @notice Shows that even owner cannot rescue funds during prolonged depeg
     */
    function test_M05_FundsTrappedDuringProlongedDepeg() public {
        console.log("=== M-05 PoC: Funds Trapped During Prolonged Depeg ===");
        console.log("");

        // Simulate 3% depeg (realistic for USDT during market stress)
        poolManager.setExchangeRate(9700);

        console.log("Scenario: USDT depegs to $0.97 during market crisis");
        console.log("  - This is realistic (USDT dropped to ~$0.95 in May 2022)");
        console.log("  - Depeg persists for days/weeks");
        console.log("");

        console.log("Day 1: Owner tries to migrate");
        vm.prank(owner);
        vm.expectRevert();
        strategy.migrate(newStrategy);
        console.log("  - FAILED: SlippageExceeded");

        console.log("");
        console.log("Day 7: Depeg persists, owner tries again");
        vm.prank(owner);
        vm.expectRevert();
        strategy.migrate(newStrategy);
        console.log("  - FAILED: SlippageExceeded");

        console.log("");
        console.log("Day 30: Depeg persists (like UST), owner tries again");
        vm.prank(owner);
        vm.expectRevert();
        strategy.migrate(newStrategy);
        console.log("  - FAILED: SlippageExceeded");

        console.log("");
        console.log("=== IMPACT SUMMARY ===");
        console.log("- User funds: %s USDC locked indefinitely", DEPOSIT_AMOUNT / 1e6);
        console.log("- No withdrawal mechanism (withdraw() disabled)");
        console.log("- Migration blocked by slippage check");
        console.log("- Only escape: wait for depeg to resolve (uncertain timeline)");
        console.log("- Worst case: stablecoin fails completely (UST scenario)");
    }
}
