<!-- METADATA
Title: setRewardToken mid-life DoSes pending claims and silently shifts the payment unit
Severity: Medium
Root Cause Link: lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L385-L388, L493, L504
PoC File: workspace/stable-yield-accumulator/test/poc-M-07.t.sol
-->

# setRewardToken mid-life DoSes pending claims and silently shifts the payment unit

## Lines of code
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L385-L388
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L493
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L504

## Vulnerability details

### Description

`setRewardToken` (lines 385-388) performs an instant rotation of the reward token with only an `onlyOwner` and zero-address check. There is no timelock, no migration window, no event-based cooldown, and no per-claim mechanism for the claimer to assert which reward token they expected to pay in. The new reward token applies to the very next claim.

`claim()` reads `rewardToken` twice during execution: at line 493 to denormalize the payment into the new token's decimal base, and at line 504 to perform `safeTransferFrom(msg.sender, address(this), actualPayment)`. The `tokenConfig` mapping for the new reward token is not necessarily set, and the claimer's allowance is for the old token only. When the token rotates between simulation and inclusion of a claim, two distinct failures result:

1. **DoS of pending claims.** The bot has approved (and funded) the old token; the new token has no allowance from the bot. `safeTransferFrom` reverts on `ERC20InsufficientAllowance`. The bot's gas is burned, the yield window may close, and there was no signal in `claim()`'s parameters that the payment unit had moved.
2. **Silent payment-unit shift.** If a claimer happens to have approved both tokens (for example a multi-strategy bot), `claim()` proceeds in the new token at the new token's `tokenConfig` decimals and exchange rate. The amount transferred is now denominated in a different asset under a different rate path than the bot priced. This is a value mutation in flight with no on-chain signal.

The protocol externalises the conversion layer to claimers (NatSpec at lines 47-49). Claimers are the system's price-discovery actors. A reward-token rotation that lands between the bot's simulation and its execution is a normal operational event - either an owner-driven migration (e.g. USDC to a different stablecoin) or an MEV searcher front-running an owner state change. Either way, the bot has no on-chain primitive to assert "I am paying in USDC".

### Impact

A pending bot claim can be reverted at zero cost to the owner, wasting bot gas and griefing the externalised arbitrage layer the protocol depends on. In the worst case where the bot has dual approvals, the bot pays in an unexpected stablecoin at unexpected terms, with no on-chain mechanism to defend itself. Over time, repeated incidents push bots to widen quoting margins or stop participating, degrading throughput.

### Proof of Concept

Drop into `lib/stable-yield-accumulator/test/poc-M-07.t.sol` and run with `forge test --match-contract PoC_M_07 -vvv`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "vault/interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC20Dec is ERC20 {
    uint8 private immutable _customDecimals;
    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) { _customDecimals = d; }
    function decimals() public view override returns (uint8) { return _customDecimals; }
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract MockPhlimbo {
    address public sya;
    address public rewardToken;
    function setSYA(address _sya) external { sya = _sya; }
    function setRewardToken(address _rt) external { rewardToken = _rt; }
    function collectReward(uint256 amount) external {
        require(msg.sender == sya, "only SYA");
        IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
    }
}

contract MockNFTMinter {
    uint256 public nextIndex = 1;
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(address => bool) public authorizedBurners;
    function registerDispatcher(address, uint256, uint256) external { nextIndex++; }
    function setAuthorizedBurner(address b, bool a) external { authorizedBurners[b] = a; }
    function mintNFT(address h, uint256 id, uint256 a) external { balances[h][id] += a; }
    function balanceOf(address h, uint256 id) external view returns (uint256) { return balances[h][id]; }
    function burn(address h, uint256 id, uint256 q) external {
        require(authorizedBurners[msg.sender], "na"); balances[h][id] -= q;
    }
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
}

contract MockYieldStrategyHoldings is IYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    mapping(address => mapping(address => uint256)) public yields;
    function setBalances(address t, address a, uint256 p, uint256 y) external { principals[t][a]=p; yields[t][a]=y; }
    function principalOf(address t, address a) external view override returns (uint256) { return principals[t][a]; }
    function totalBalanceOf(address t, address a) external view override returns (uint256) { return principals[t][a]+yields[t][a]; }
    function balanceOf(address t, address a) external view override returns (uint256) { return principals[t][a]+yields[t][a]; }
    function withdrawFrom(address t, address c, uint256 a, address r) external override {
        IERC20(t).transfer(r, a); yields[t][c] -= a;
    }
    function deposit(address, uint256, address) external pure override {}
    function withdraw(address, uint256, address) external pure override {}
    function setClient(address, bool) external pure override {}
    function emergencyWithdraw(uint256) external pure override {}
    function totalWithdrawal(address, address) external pure override {}
}

contract PoC_M_07 is Test {
    StableYieldAccumulator internal sya;
    MockERC20Dec internal usdc;
    MockERC20Dec internal dai;
    MockERC20Dec internal stratToken;
    MockYieldStrategyHoldings internal strategy;
    MockPhlimbo internal phlimbo;
    MockNFTMinter internal nftMinter;

    address internal minterAddr = makeAddr("minter");
    address internal bot = makeAddr("claimerBot");

    uint256 internal constant PRINCIPAL = 1_000e18;
    uint256 internal constant YIELD = 100e18;
    uint256 internal constant DISCOUNT_BPS = 200;

    function setUp() public {
        usdc = new MockERC20Dec("USDC", "USDC", 6);
        dai  = new MockERC20Dec("DAI",  "DAI", 18);
        stratToken = new MockERC20Dec("STRAT", "STRAT", 18);

        sya = new StableYieldAccumulator();
        phlimbo = new MockPhlimbo();
        phlimbo.setSYA(address(sya));
        phlimbo.setRewardToken(address(usdc));
        nftMinter = new MockNFTMinter();
        nftMinter.setAuthorizedBurner(address(sya), true);
        nftMinter.registerDispatcher(makeAddr("dispatcher"), 1e18, 100);
        strategy = new MockYieldStrategyHoldings();

        sya.setPhlimbo(address(phlimbo));
        sya.setRewardToken(address(usdc));
        sya.setMinter(minterAddr);
        sya.setDiscountRate(DISCOUNT_BPS);
        sya.setNFTMinter(address(nftMinter));
        sya.addYieldStrategy(address(strategy), address(stratToken));
        sya.setTokenConfig(address(stratToken), 18, 1e18);
        sya.setTokenConfig(address(usdc), 6, 1e18);
        sya.setTokenConfig(address(dai), 18, 1e18);
        sya.approvePhlimbo(type(uint256).max);

        strategy.setBalances(address(stratToken), minterAddr, PRINCIPAL, YIELD);
        stratToken.mint(address(strategy), PRINCIPAL + YIELD);

        nftMinter.mintNFT(bot, 1, 1);

        // Bot funds + approves only USDC (the rewardToken at quote time).
        uint256 quotedUSDC = sya.calculateClaimAmount();
        usdc.mint(bot, quotedUSDC * 10);
        vm.prank(bot);
        usdc.approve(address(sya), type(uint256).max);
    }

    function test_M07_RewardTokenSwapDoSesPendingClaim() public {
        // Bot has USDC allowance, no DAI allowance.
        assertEq(usdc.allowance(bot, address(sya)), type(uint256).max);
        assertEq(dai.allowance(bot, address(sya)), 0);
        assertEq(sya.rewardToken(), address(usdc));

        // Owner front-runs with a reward-token flip.
        sya.setRewardToken(address(dai));
        assertEq(sya.rewardToken(), address(dai), "flipped to DAI mid-life");

        // Bot's pending claim now reverts on safeTransferFrom (no DAI allowance).
        vm.prank(bot);
        vm.expectRevert();
        sya.claim(1, 0);

        // No yield delivered, no payment received, NFT not burned.
        assertEq(stratToken.balanceOf(bot), 0);
        assertEq(usdc.balanceOf(address(phlimbo)), 0);
        assertEq(dai.balanceOf(address(phlimbo)), 0);
        assertEq(nftMinter.balanceOf(bot, 1), 1);
    }
}
```

### Tools Used
Manual review, Foundry.

### Recommended Mitigation Steps

Give claimers a way to assert the reward token they are paying in, and slow owner-side rotations:

1. Add an `expectedRewardToken` parameter to `claim()` and revert with a descriptive error when `rewardToken != expectedRewardToken`. This is a minimal, backwards-compatible fix that surfaces the rotation to the claimer as a clean revert before any state changes.
2. Route `setRewardToken` through a two-step migration: a `proposeRewardToken(address)` that emits an event and starts a delay, followed by a `commitRewardToken()` callable after the delay elapses. Bots watching the event can re-quote and re-approve before commit.
3. On commit, automatically clear stale `tokenConfig` for the previous reward token and reset Phlimbo allowance so accidental dual-approval claimers cannot be silently milked under the new token.
