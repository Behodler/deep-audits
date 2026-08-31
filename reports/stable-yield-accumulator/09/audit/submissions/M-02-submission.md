<!-- METADATA
Title: Slippage parameter is one-sided and does not protect claimers from overpaying
Severity: Medium
Root Cause Link: lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L496
PoC File: workspace/stable-yield-accumulator/test/poc-M-02.t.sol
-->

# Slippage parameter is one-sided and does not protect claimers from overpaying

## Lines of code
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L458-L518
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L496

## Vulnerability details

### Description

`claim()` accepts a `minRewardTokenSupplied` parameter and, at line 496, enforces:

```solidity
if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();
```

This check is a LOWER bound on what the claimer pays. The economic risk to a claimer (the bot the protocol relies on to perform the externalised conversion) is OVERPAYING - paying more reward token than was simulated when they decided the trade was profitable. The current parameter does not defend against this direction at all.

The relevant state inputs to `actualPayment` are `discountRate` (line 492), the per-token `normalizedExchangeRate` and `decimals` consumed by `_denormalizeAmount` (lines 605-628), and per-token pause flags. Each is mutable by the owner via `setDiscountRate`, `setTokenConfig`, `pauseToken`, and `unpauseToken`. Any of these mutations between the bot's simulation and the claim's inclusion shifts `actualPayment` upward. When the value moves up, the check at line 496 becomes trivially satisfied (the bot's `min` is below the new, higher payment), and the claim succeeds at the new, worse-for-the-bot price.

The protocol explicitly relies on external bots to perform the conversion (see contract NatSpec at lines 47-49). Bots quote against `calculateClaimAmount()`, sign a transaction, and submit. If the owner front-runs (for example via `setDiscountRate(0)`), or if an MEV searcher sandwiches an owner state-change, the bot pays the full undiscounted price and the entire intended margin disappears. The bot has no on-chain way to express "I expected to pay no more than X".

### Impact

A claimer's economic margin (the discount) can be silently zeroed by any owner-side mutation that lands before the claim executes. Bots are exposed to deterministic loss equal to the discount component plus gas plus the burned NFT. Because the protocol's design depends on these bots showing up, a parameter that ostensibly protects them but actually leaves them open to overpayment is a value-leak vector against the externalised arbitrage layer. Repeated incidents incentivise bots to widen quoting margins or stop participating, degrading the protocol's claim throughput.

### Proof of Concept

Drop into `lib/stable-yield-accumulator/test/poc-M-02.t.sol` and run with `forge test --match-contract PoC_M_02 -vvv`. The test inlines self-contained mocks so it does not depend on the existing test harness shape.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "../src/interfaces/IStableYieldAccumulator.sol";
import "vault/interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC20WithDecimals is ERC20 {
    uint8 private _decimals;
    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) { _decimals = d; }
    function decimals() public view override returns (uint8) { return _decimals; }
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract MockPhlimbo {
    address public rewardToken;
    address public yieldAccumulator;
    uint256 public collectRewardCallCount;
    constructor(address rt) { rewardToken = rt; }
    function setYieldAccumulator(address y) external { yieldAccumulator = y; }
    function collectReward(uint256 amount) external {
        require(msg.sender == yieldAccumulator, "only sya");
        collectRewardCallCount++;
        IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
    }
}

contract MockYieldStrategy is IYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;
    function setBalances(address t, address a, uint256 p, uint256 y) external {
        principals[t][a] = p; yields[t][a] = y;
    }
    function deposit(address, uint256, address) external pure override {}
    function withdraw(address, uint256, address) external pure override {}
    function balanceOf(address t, address a) external view override returns (uint256) { return principals[t][a] + yields[t][a]; }
    function principalOf(address t, address a) external view override returns (uint256) { return principals[t][a]; }
    function totalBalanceOf(address t, address a) external view override returns (uint256) { return principals[t][a] + yields[t][a]; }
    function setClient(address, bool) external pure override {}
    function emergencyWithdraw(uint256) external pure override {}
    function totalWithdrawal(address, address) external pure override {}
    function withdrawFrom(address t, address c, uint256 a, address r) external override {
        IERC20(t).transfer(r, a); yields[t][c] -= a;
    }
}

contract MockNFTMinter {
    uint256 public nextIndex;
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(address => bool) public authorizedBurners;
    constructor() { nextIndex = 1; }
    function configs(uint256) external pure returns (address, uint256, uint256, bool) { return (address(0), 0, 0, false); }
    function registerDispatcher(address, uint256, uint256) external { nextIndex++; }
    function setAuthorizedBurner(address b, bool a) external { authorizedBurners[b] = a; }
    function mintNFT(address h, uint256 id, uint256 a) external { balances[h][id] += a; }
    function balanceOf(address h, uint256 id) external view returns (uint256) { return balances[h][id]; }
    function burn(address h, uint256 id, uint256 q) external {
        require(authorizedBurners[msg.sender], "na");
        balances[h][id] -= q;
    }
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
}

contract PoC_M_02 is Test {
    StableYieldAccumulator public accumulator;
    MockERC20WithDecimals public usdc;
    MockERC20WithDecimals public usdcStrategyToken;
    MockYieldStrategy public strategy;
    MockPhlimbo public phlimbo;
    MockNFTMinter public nftMinter;

    address public bot;
    address public minterAddr;

    event RewardsClaimed(address indexed claimer, uint256 amountPaid, uint256 strategiesClaimed);

    function setUp() public {
        bot = makeAddr("bot");
        minterAddr = makeAddr("minter");

        usdc = new MockERC20WithDecimals("USDC", "USDC", 6);
        usdcStrategyToken = new MockERC20WithDecimals("sUSDC", "sUSDC", 6);

        strategy = new MockYieldStrategy();
        accumulator = new StableYieldAccumulator();
        phlimbo = new MockPhlimbo(address(usdc));
        phlimbo.setYieldAccumulator(address(accumulator));

        nftMinter = new MockNFTMinter();
        nftMinter.setAuthorizedBurner(address(accumulator), true);
        nftMinter.registerDispatcher(makeAddr("dispatcher1"), 1e18, 100);

        accumulator.setPhlimbo(address(phlimbo));
        accumulator.setRewardToken(address(usdc));
        accumulator.setMinter(minterAddr);
        accumulator.setNFTMinter(address(nftMinter));
        accumulator.setDiscountRate(200); // 2%
        accumulator.addYieldStrategy(address(strategy), address(usdcStrategyToken));
        accumulator.setTokenConfig(address(usdcStrategyToken), 6, 1e18);
        accumulator.setTokenConfig(address(usdc), 6, 1e18);
        accumulator.approvePhlimbo(type(uint256).max);

        strategy.setBalances(address(usdcStrategyToken), minterAddr, 1000e6, 15e6);
        usdcStrategyToken.mint(address(strategy), 15e6);

        usdc.mint(bot, 100e6);
        vm.prank(bot);
        usdc.approve(address(accumulator), type(uint256).max);

        nftMinter.mintNFT(bot, 1, 1);
    }

    function test_M02_SlippageDoesNotProtectAgainstDiscountRateDecrease() public {
        // Bot simulates the claim at the current 2% discount.
        uint256 simulatedPayment = accumulator.calculateClaimAmount();
        assertEq(simulatedPayment, 14_700_000, "simulated payment 14.7 USDC at 2% discount");

        // Bot uses the simulated value as its slippage floor.
        uint256 minRewardTokenSupplied = simulatedPayment;

        // Owner front-runs by setting discount rate to 0.
        accumulator.setDiscountRate(0);

        uint256 botUsdcBefore = usdc.balanceOf(bot);

        vm.recordLogs();
        vm.prank(bot);
        accumulator.claim(1, minRewardTokenSupplied);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 actualPayment = _extractActualPaymentFromRewardsClaimed(logs, bot);

        // Bot was charged the FULL 15 USDC; the slippage check did NOT fire.
        assertEq(actualPayment, 15_000_000, "bot paid 15 USDC, not the simulated 14.7");
        assertGt(actualPayment, minRewardTokenSupplied, "actualPayment > min: parameter is one-sided");

        uint256 botPaid = botUsdcBefore - usdc.balanceOf(bot);
        assertEq(botPaid, 15_000_000, "bot paid 15 USDC out-of-pocket");
        assertEq(actualPayment - minRewardTokenSupplied, 300_000, "bot overpaid by 0.3 USDC");
    }

    function _extractActualPaymentFromRewardsClaimed(Vm.Log[] memory logs, address claimer)
        internal pure returns (uint256 amountPaid)
    {
        bytes32 sig = keccak256("RewardsClaimed(address,uint256,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == sig) {
                if (address(uint160(uint256(logs[i].topics[1]))) == claimer) {
                    (amountPaid, ) = abi.decode(logs[i].data, (uint256, uint256));
                    return amountPaid;
                }
            }
        }
        revert("RewardsClaimed event not found");
    }
}
```

### Tools Used
Manual review, Foundry.

### Recommended Mitigation Steps

Add a symmetric upper bound on what the claimer is willing to pay. Two minimally invasive options:

1. Add a `maxRewardTokenSupplied` parameter to `claim()` and revert when `actualPayment > maxRewardTokenSupplied`. Keep the existing lower bound for callers that want both sides.
2. Alternatively, accept an `expectedRewardToken`, `expectedDiscountBps`, and `expectedPaymentExact` triple and revert if any of the three diverges from current state at execution time. This pins the entire price path the claimer simulated.

In addition, route owner mutations to `discountRate`, `tokenConfig`, and `setRewardToken` through a short timelock or a "config epoch" counter that `claim()` can assert against, so off-chain bots can detect a config rotation and re-quote rather than landing into a moved price.
