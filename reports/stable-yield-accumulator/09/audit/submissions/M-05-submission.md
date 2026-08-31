<!-- METADATA
Title: removeYieldStrategy strands accrued yield and creates a windfall on re-addition
Severity: Medium
Root Cause Link: lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L256-L272
PoC File: workspace/stable-yield-accumulator/test/poc-M-05.t.sol
-->

# removeYieldStrategy strands accrued yield and creates a windfall on re-addition

## Lines of code
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L256-L272

## Vulnerability details

### Description

`removeYieldStrategy` (lines 256-272) deletes a strategy from the registry without any check that the strategy's pending yield has been harvested. The function unconditionally swaps the entry out of the array, clears `isRegisteredStrategy`, and `delete strategyTokens[strategy]`. The yield itself - tracked inside the underlying strategy as `totalBalanceOf - principalOf` - is unaffected, but `claim()` and `getTotalYield()` no longer iterate the removed strategy, so SYA loses sight of it.

This produces two distinct symptoms:

1. **Stranded yield.** Immediately after removal, the yield exists inside the strategy but is unreachable through SYA. A claimer who calls `claim()` while no other strategies hold yield reverts with `ZeroAmount` (line 489). Phlimbo permanently loses the value of that yield window unless the owner takes a manual recovery path that does not exist in the contract.

2. **Re-addition windfall.** If the owner later re-registers the same strategy, SYA suddenly sees the entire backlog (the previously stranded yield plus any further accrual that occurred while the strategy was off-book). The first claimer to land a `claim()` after re-registration sweeps the entire bunched amount in a single transaction at the standard discount, capturing value that under normal smooth-accrual operation would have been distributed across multiple claim windows and multiple claimers.

The contract gives the owner no `forceClaim` path, no migration helper, and no zero-yield assertion gate on removal. Strategy registration is documented as an owner-trusted action, but the architectural omission is in scope: a single-line guard would prevent both failure modes.

### Impact

The protocol loses pending yield on every removal that fires while yield is non-zero. On re-registration, the protocol's economic model - in which the discount is a fair price for spreading conversion gas costs across many claims - is broken: a single MEV bot captures a backlog with no elevated fee. Limbo stakers see lumpy, distorted reward distributions, and claimers with smaller capital are deterministically out-competed for the windfall.

### Proof of Concept

Drop into `lib/stable-yield-accumulator/test/poc-M-05.t.sol` and run with `forge test --match-contract PoC_M_05 -vvv`. The test exercises both the strand and the windfall.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "../src/interfaces/IStableYieldAccumulator.sol";
import "vault/interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}
contract MockPhlimbo {
    address public rewardToken;
    address public yieldAccumulator;
    constructor(address rt) { rewardToken = rt; }
    function setYieldAccumulator(address y) external { yieldAccumulator = y; }
    function collectReward(uint256 a) external {
        require(msg.sender == yieldAccumulator, "only sya");
        IERC20(rewardToken).transferFrom(msg.sender, address(this), a);
    }
}
contract MockYieldStrategy is IYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;
    function setBalances(address t, address a, uint256 p, uint256 y) external { principals[t][a]=p; yields[t][a]=y; }
    function deposit(address, uint256, address) external pure override {}
    function withdraw(address, uint256, address) external pure override {}
    function balanceOf(address t, address a) external view override returns (uint256) { return principals[t][a]+yields[t][a]; }
    function principalOf(address t, address a) external view override returns (uint256) { return principals[t][a]; }
    function totalBalanceOf(address t, address a) external view override returns (uint256) { return principals[t][a]+yields[t][a]; }
    function setClient(address, bool) external pure override {}
    function emergencyWithdraw(uint256) external pure override {}
    function totalWithdrawal(address, address) external pure override {}
    function withdrawFrom(address t, address c, uint256 a, address r) external override {
        IERC20(t).transfer(r, a); yields[t][c] -= a;
    }
}
contract MockNFTMinter {
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(address => bool) public authorizedBurners;
    uint256 public nextIndex;
    constructor() { nextIndex = 2; }
    function setAuthorizedBurner(address b, bool a) external { authorizedBurners[b] = a; }
    function mintNFT(address h, uint256 id, uint256 a) external { balances[h][id] += a; }
    function balanceOf(address h, uint256 id) external view returns (uint256) { return balances[h][id]; }
    function burn(address h, uint256 id, uint256 q) external {
        require(authorizedBurners[msg.sender], "na"); balances[h][id] -= q;
    }
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
}

contract PoC_M_05 is Test {
    StableYieldAccumulator public sya;
    MockERC20 public rewardToken;
    MockERC20 public strategyToken;
    MockYieldStrategy public strategy;
    MockPhlimbo public phlimbo;
    MockNFTMinter public nftMinter;

    address public minterAddr;
    address public claimerA;
    address public claimerB;

    uint256 internal constant DISCOUNT_BPS = 200;
    uint256 internal constant INITIAL_PRINCIPAL = 1_000e18;

    function setUp() public {
        minterAddr = makeAddr("minter");
        claimerA = makeAddr("claimerA");
        claimerB = makeAddr("claimerB");

        rewardToken = new MockERC20("Reward", "RWD");
        strategyToken = new MockERC20("Strat", "STK");
        strategy = new MockYieldStrategy();
        sya = new StableYieldAccumulator();
        phlimbo = new MockPhlimbo(address(rewardToken));
        phlimbo.setYieldAccumulator(address(sya));
        nftMinter = new MockNFTMinter();
        nftMinter.setAuthorizedBurner(address(sya), true);

        sya.setPhlimbo(address(phlimbo));
        sya.setRewardToken(address(rewardToken));
        sya.setMinter(minterAddr);
        sya.setDiscountRate(DISCOUNT_BPS);
        sya.setNFTMinter(address(nftMinter));
        sya.setTokenConfig(address(strategyToken), 18, 1e18);
        sya.setTokenConfig(address(rewardToken), 18, 1e18);
        sya.approvePhlimbo(type(uint256).max);
    }

    function _addStrategy() internal { sya.addYieldStrategy(address(strategy), address(strategyToken)); }

    function _setStrategyYield(uint256 amt) internal {
        strategyToken.mint(address(strategy), amt);
        uint256 cur = strategy.yields(address(strategyToken), minterAddr);
        strategy.setBalances(address(strategyToken), minterAddr, INITIAL_PRINCIPAL, cur + amt);
    }

    function _fundAndApproveClaimer(address c, uint256 budget) internal {
        rewardToken.mint(c, budget);
        vm.prank(c);
        rewardToken.approve(address(sya), type(uint256).max);
        nftMinter.mintNFT(c, 1, 1);
    }

    function test_M05_strategyRemovalStrandsYield() public {
        _addStrategy();
        _setStrategyYield(100e18);
        assertEq(sya.getTotalYield(), 100e18, "SYA sees 100e18 pre-removal");

        sya.removeYieldStrategy(address(strategy));
        assertEq(sya.getYieldStrategies().length, 0);

        // Yield still inside the strategy, but invisible to SYA.
        uint256 stranded = strategy.totalBalanceOf(address(strategyToken), minterAddr)
            - strategy.principalOf(address(strategyToken), minterAddr);
        assertEq(stranded, 100e18);
        assertEq(sya.getTotalYield(), 0, "SYA loop blind to it");

        _fundAndApproveClaimer(claimerA, 1_000e18);
        vm.prank(claimerA);
        vm.expectRevert(IStableYieldAccumulator.ZeroAmount.selector);
        sya.claim(1, 0);
    }

    function test_M05_reAdditionGivesSingleClaimerWindfall() public {
        _addStrategy();
        _setStrategyYield(100e18);
        sya.removeYieldStrategy(address(strategy));
        _setStrategyYield(50e18); // accrues while off-book

        sya.addYieldStrategy(address(strategy), address(strategyToken));
        assertEq(sya.getTotalYield(), 150e18, "full backlog visible at once");

        uint256 expectedPayment = 150e18 * (10000 - DISCOUNT_BPS) / 10000; // 147e18
        _fundAndApproveClaimer(claimerA, expectedPayment + 1e18);
        _fundAndApproveClaimer(claimerB, expectedPayment + 1e18);

        vm.prank(claimerA);
        sya.claim(1, 0);

        assertEq(strategyToken.balanceOf(claimerA), 150e18, "single claimer captures full 150e18");

        // claimerB - equally NFT-gated and ready - left with nothing.
        vm.prank(claimerB);
        vm.expectRevert(IStableYieldAccumulator.ZeroAmount.selector);
        sya.claim(1, 0);
    }
}
```

### Tools Used
Manual review, Foundry.

### Recommended Mitigation Steps

Prevent removal of strategies that still hold pending yield, or force-harvest before removal:

1. Add a guard at the top of `removeYieldStrategy`: read `_getYieldForStrategy(strategy, strategyTokens[strategy])` and `revert StrategyHasPendingYield()` when non-zero. Force the owner to wait for a claim or invoke an explicit force-harvest path before removing.
2. Provide an `ownerForceHarvest(address strategy, address recipient)` helper that drains pending yield to a designated recipient (phlimbo or treasury) before clearing the registry entry, so removal is always clean.
3. If lumpy backlogs become possible despite mitigations (e.g. mid-flight pause/unpause of an underlying), apply a temporarily elevated discount on the first post-re-registration claim, scaled to `currentYield - principalDelta`, so the protocol prices the windfall correctly.
