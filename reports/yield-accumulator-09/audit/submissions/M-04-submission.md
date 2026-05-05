<!-- METADATA
Title: A single misbehaving strategy reverts the entire claim() across all strategies
Severity: Medium
Root Cause Link: lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L470-L487
PoC File: workspace/stable-yield-accumulator/test/poc-M-04.t.sol
-->

# A single misbehaving strategy reverts the entire claim() across all strategies

## Lines of code
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L470-L487

## Vulnerability details

### Description

`claim()` iterates the registered strategies in a single loop (lines 470-487) and calls `IYieldStrategy(strategy).withdrawFrom(...)` directly on each strategy that reports non-zero yield. There is no `try/catch` around the external call, no per-strategy error isolation, and no skip-on-failure path. Any revert from any single strategy bubbles out of `claim()` and rolls back the entire transaction.

A revert in `withdrawFrom` is realistic in production: a third-party strategy adapter can pause, a strategy's underlying protocol can revert on withdrawal (e.g. paused vault, insufficient liquidity, frozen market), or a strategy's accounting can briefly disagree with `totalBalanceOf` minus `principalOf`. Each of these is a normal failure mode for an adapter pattern. The contract's only mitigation is the per-token `paused` flag (line 475), which only short-circuits the loop AFTER the owner explicitly pauses that token. Until the owner intervenes, every claim across every strategy is dead.

The `nonReentrant` guard (line 458) does not help here - it prevents re-entry but does nothing for liveness. Strategy yield continues to accrue inside the broken adapter and the healthy adapters, but no one can harvest any of it through SYA.

### Impact

Liveness loss across the entire claim path. Phlimbo receives no rewards while the offender remains registered, regardless of how much yield healthy strategies have accumulated. Limbo stakers' reward distribution stalls. The protocol depends on permissionless claimers to perform the conversion, but there is no permissionless way to skip a broken strategy. The owner is required to remove or pause the offender; until they do, all yield is stranded behind a single bad sibling.

### Proof of Concept

Drop into `lib/stable-yield-accumulator/test/poc-M-04.t.sol` and run with `forge test --match-contract PoC_M_04 -vvv`. Self-contained; uses no shared mocks.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "../src/interfaces/IStableYieldAccumulator.sol";
import "vault/interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PoC_M04_MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract PoC_M04_MockPhlimbo {
    address public rewardToken;
    address public yieldAccumulator;
    uint256 public collectRewardCallCount;
    constructor(address rt) { rewardToken = rt; }
    function setYieldAccumulator(address a) external { yieldAccumulator = a; }
    function collectReward(uint256 a) external {
        require(msg.sender == yieldAccumulator, "only sya");
        collectRewardCallCount++;
        IERC20(rewardToken).transferFrom(msg.sender, address(this), a);
    }
}

contract PoC_M04_GoodStrategy is IYieldStrategy {
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

contract PoC_M04_RevertingStrategy is IYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;
    error StrategyBroken();
    function setBalances(address t, address a, uint256 p, uint256 y) external { principals[t][a]=p; yields[t][a]=y; }
    function deposit(address, uint256, address) external pure override {}
    function withdraw(address, uint256, address) external pure override {}
    function balanceOf(address t, address a) external view override returns (uint256) { return principals[t][a]+yields[t][a]; }
    function principalOf(address t, address a) external view override returns (uint256) { return principals[t][a]; }
    function totalBalanceOf(address t, address a) external view override returns (uint256) { return principals[t][a]+yields[t][a]; }
    function setClient(address, bool) external pure override {}
    function emergencyWithdraw(uint256) external pure override {}
    function totalWithdrawal(address, address) external pure override {}
    function withdrawFrom(address, address, uint256, address) external pure override {
        revert StrategyBroken();
    }
}

contract PoC_M04_MockNFTMinter {
    struct C { address d; uint256 p; uint256 g; bool dis; }
    uint256 public nextIndex = 1;
    mapping(uint256 => C) public _configs;
    mapping(address => bool) public authorizedBurners;
    mapping(address => mapping(uint256 => uint256)) public balances;
    function configs(uint256 i) external view returns (address, uint256, uint256, bool) {
        C memory c = _configs[i]; return (c.d, c.p, c.g, c.dis);
    }
    function registerDispatcher(address d, uint256 p, uint256 g) external {
        _configs[nextIndex] = C(d, p, g, false); nextIndex++;
    }
    function setAuthorizedBurner(address b, bool a) external { authorizedBurners[b] = a; }
    function mintNFT(address h, uint256 id, uint256 a) external { balances[h][id] += a; }
    function balanceOf(address h, uint256 id) external view returns (uint256) { return balances[h][id]; }
    function burn(address h, uint256 id, uint256 q) external {
        require(authorizedBurners[msg.sender], "na"); balances[h][id] -= q;
    }
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
}

contract PoC_M_04 is Test {
    StableYieldAccumulator internal accumulator;
    PoC_M04_MockERC20 internal rewardToken;
    PoC_M04_MockERC20 internal tokenA;
    PoC_M04_MockERC20 internal tokenB;
    PoC_M04_GoodStrategy internal strategyA;
    PoC_M04_RevertingStrategy internal strategyB;
    PoC_M04_MockPhlimbo internal phlimbo;
    PoC_M04_MockNFTMinter internal nft;

    address internal minterAddr;
    address internal claimer;

    uint256 internal constant YIELD_A = 100e18;
    uint256 internal constant YIELD_B = 50e18;

    function setUp() public {
        minterAddr = makeAddr("minter");
        claimer    = makeAddr("claimer");

        rewardToken = new PoC_M04_MockERC20("Reward", "RWD");
        tokenA = new PoC_M04_MockERC20("Token A", "TKA");
        tokenB = new PoC_M04_MockERC20("Token B", "TKB");

        accumulator = new StableYieldAccumulator();
        strategyA = new PoC_M04_GoodStrategy();
        strategyB = new PoC_M04_RevertingStrategy();

        phlimbo = new PoC_M04_MockPhlimbo(address(rewardToken));
        phlimbo.setYieldAccumulator(address(accumulator));

        nft = new PoC_M04_MockNFTMinter();
        nft.setAuthorizedBurner(address(accumulator), true);
        nft.registerDispatcher(makeAddr("dispatcher1"), 1e18, 100);

        accumulator.setPhlimbo(address(phlimbo));
        accumulator.setRewardToken(address(rewardToken));
        accumulator.setMinter(minterAddr);
        accumulator.setDiscountRate(200);
        accumulator.setNFTMinter(address(nft));
        accumulator.addYieldStrategy(address(strategyA), address(tokenA));
        accumulator.addYieldStrategy(address(strategyB), address(tokenB));
        accumulator.setTokenConfig(address(tokenA), 18, 1e18);
        accumulator.setTokenConfig(address(tokenB), 18, 1e18);
        accumulator.setTokenConfig(address(rewardToken), 18, 1e18);

        strategyA.setBalances(address(tokenA), minterAddr, 1_000e18, YIELD_A);
        strategyB.setBalances(address(tokenB), minterAddr, 500e18, YIELD_B);
        tokenA.mint(address(strategyA), YIELD_A);

        rewardToken.mint(claimer, 1_000e18);
        vm.prank(claimer);
        rewardToken.approve(address(accumulator), type(uint256).max);

        accumulator.approvePhlimbo(type(uint256).max);
        nft.mintNFT(claimer, 1, 1);
    }

    function test_M04_OneBadStrategyDoSesAllClaims() public {
        // claim() reverts with the strategy's error - one bad sibling kills the loop.
        vm.prank(claimer);
        vm.expectRevert(PoC_M04_RevertingStrategy.StrategyBroken.selector);
        accumulator.claim(1, 0);

        // Healthy strategy's yield stranded behind the bad one.
        assertEq(tokenA.balanceOf(claimer), 0, "no tokenA delivered");
        assertEq(tokenA.balanceOf(address(strategyA)), YIELD_A, "strategyA stranded");
        assertEq(rewardToken.balanceOf(address(phlimbo)), 0, "phlimbo got nothing");
        assertEq(phlimbo.collectRewardCallCount(), 0, "collectReward never invoked");
        assertEq(nft.balanceOf(claimer, 1), 1, "NFT not burned (claim reverted)");

        // Owner intervention restores liveness.
        accumulator.removeYieldStrategy(address(strategyB));
        vm.prank(claimer);
        accumulator.claim(1, 0);

        assertEq(tokenA.balanceOf(claimer), YIELD_A, "post-remediation: yield delivered");
        assertEq(rewardToken.balanceOf(address(phlimbo)), YIELD_A * 98 / 100, "phlimbo paid");
    }
}
```

### Tools Used
Manual review, Foundry.

### Recommended Mitigation Steps

Isolate per-strategy failures so one bad adapter cannot DoS the whole claim:

1. Wrap the `withdrawFrom` call (and ideally also the balance reads in `_getYieldForStrategy`) in `try/catch`. On failure, emit a `StrategyClaimSkipped(strategy, reason)` event and continue the loop. Skip the strategy's contribution to `totalNormalizedYield` for that claim only.
2. Add a permissionless `quarantineStrategy(address strategy)` callable when a recent claim attempt has reverted on that strategy (with a small bond and dispute window if needed), so liveness is not gated on the owner.
3. Optionally allow callers to pass an explicit list of strategy indices to `claim()`, so claimers can sidestep a known-broken strategy until the owner remediates.
