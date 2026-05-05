<!-- METADATA
Title: Nudge as "soft pause" bypasses dual-unpause governance
Severity: Medium
Root Cause Link: lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L421-L427, L498-L515
PoC File: workspace/stable-yield-accumulator/test/poc-M-01.t.sol
-->

# Nudge as "soft pause" bypasses dual-unpause governance

## Lines of code
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L421-L427
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L498-L515

## Vulnerability details

### Description

`StableYieldAccumulator` documents and implements the Behodler3 dual-unpause pattern: pausing is exclusive to the pauser, but unpausing is callable by either the owner or the pauser. The contract NatSpec at lines 19-30 makes the intent explicit - the pauser exists as an independent guardian whose presence prevents the owner from unilaterally denying rewards by halting the contract.

`setNudgeAddress` (line 410-414) and `setNudgeSplit` (line 421-427) are protected only by `onlyOwner`. There is no pauser involvement, no timelock, and no cap below 100. When the owner sets `nudgeSplit = 100` and points `nudge` at any sink (including a burn address or owner-controlled wallet), the claim flow at lines 507-515 routes 100% of every payment to the nudge address. Because `nudgeAmount == actualPayment`, `phlimboAmount` evaluates to zero and the `phlimboAmount > 0` branch never invokes `IPhlimbo(phlimbo).collectReward(...)`.

The contract continues to report `paused() == false`. Claimers continue to claim, NFTs continue to burn, strategy yield continues to flow to claimers, and `RewardsClaimed` events continue to emit. The system appears live to every external observer. Phlimbo - the legitimate reward sink for Limbo stakers - receives nothing. The pauser cannot remediate: pause/unpause has no effect on nudge state, and the nudge configuration setters are owner-only. The documented trust-reducing invariant is silently nullified by configuration that requires no pauser cooperation.

### Impact

The pauser's role as an independent check on owner-driven reward denial is fully defeated. The owner gains a unilateral, persistent "soft pause" of reward distribution that the pauser cannot detect via `paused()`, cannot signal via the standard `Paused` event, and cannot reverse via `unpause()`. This breaks a stated trust-reducing design invariant of the Phoenix pausable architecture, and routes the entire claim revenue stream to an owner-chosen destination outside the pauser's control surface.

### Proof of Concept

Drop into `lib/stable-yield-accumulator/test/poc-M-01.t.sol` and run with `forge test --match-contract PoC_M_01 -vvv`. Reuses the existing `MockERC20`, `MockPhlimbo`, `MockYieldStrategy`, and `MockNFTMinter` from `test/StableYieldAccumulator.t.sol`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "../src/interfaces/IStableYieldAccumulator.sol";
import {MockERC20, MockPhlimbo, MockYieldStrategy, MockNFTMinter} from "./StableYieldAccumulator.t.sol";

contract PoC_M_01 is Test {
    StableYieldAccumulator internal accumulator;
    MockERC20 internal rewardToken;
    MockERC20 internal strategyToken;
    MockYieldStrategy internal strategy;
    MockPhlimbo internal phlimbo;
    MockNFTMinter internal nftMinter;

    address internal owner;
    address internal pauser;
    address internal claimer;
    address internal minterAddr;

    address internal constant NUDGE_SINK = address(0xdEaD);

    uint256 internal constant YIELD_AMOUNT = 100e18;
    uint256 internal constant DISCOUNT_BPS = 200; // 2%

    function setUp() public {
        owner = address(this);
        pauser = makeAddr("pauser");
        claimer = makeAddr("claimer");
        minterAddr = makeAddr("minter");

        rewardToken = new MockERC20("Reward Token", "RWD");
        strategyToken = new MockERC20("Strategy Token", "STK");

        strategy = new MockYieldStrategy();
        accumulator = new StableYieldAccumulator();

        phlimbo = new MockPhlimbo(address(rewardToken));
        phlimbo.setYieldAccumulator(address(accumulator));

        nftMinter = new MockNFTMinter();
        nftMinter.setAuthorizedBurner(address(accumulator), true);
        nftMinter.registerDispatcher(makeAddr("dispatcher1"), 1e18, 100);

        accumulator.setPauser(pauser);
        accumulator.setPhlimbo(address(phlimbo));
        accumulator.setRewardToken(address(rewardToken));
        accumulator.setMinter(minterAddr);
        accumulator.setDiscountRate(DISCOUNT_BPS);
        accumulator.setNFTMinter(address(nftMinter));
        accumulator.addYieldStrategy(address(strategy), address(strategyToken));
        accumulator.setTokenConfig(address(strategyToken), 18, 1e18);
        accumulator.setTokenConfig(address(rewardToken), 18, 1e18);
        accumulator.approvePhlimbo(type(uint256).max);

        strategy.setBalances(address(strategyToken), minterAddr, 1000e18, YIELD_AMOUNT);
        strategyToken.mint(address(strategy), YIELD_AMOUNT);

        uint256 claimerPayment = (YIELD_AMOUNT * (10000 - DISCOUNT_BPS)) / 10000; // 98e18
        rewardToken.mint(claimer, claimerPayment + 1e18);
        vm.prank(claimer);
        rewardToken.approve(address(accumulator), type(uint256).max);

        nftMinter.mintNFT(claimer, 1, 1);
    }

    function test_M01_NudgeAsSoftPause_BypassesDualUnpause() public {
        assertFalse(accumulator.paused(), "precondition: contract should be unpaused");
        assertEq(accumulator.pauser(), pauser, "precondition: pauser is set");

        // Owner unilaterally configures the soft pause - NO pauser involvement.
        accumulator.setNudgeAddress(NUDGE_SINK);
        accumulator.setNudgeSplit(100);

        assertFalse(accumulator.paused(), "contract still appears live: not paused");

        uint256 expectedPayment = (YIELD_AMOUNT * (10000 - DISCOUNT_BPS)) / 10000;
        uint256 phlimboBefore = rewardToken.balanceOf(address(phlimbo));
        uint256 nudgeBefore = rewardToken.balanceOf(NUDGE_SINK);

        vm.prank(claimer);
        accumulator.claim(1, 0);

        assertEq(rewardToken.balanceOf(NUDGE_SINK) - nudgeBefore, expectedPayment, "100% routed to nudge sink");
        assertEq(rewardToken.balanceOf(address(phlimbo)) - phlimboBefore, 0, "Phlimbo received zero");
        assertEq(phlimbo.collectRewardCallCount(), 0, "collectReward never invoked");

        // Pauser is powerless to remediate.
        vm.prank(pauser); accumulator.pause();
        vm.prank(pauser); accumulator.unpause();

        assertEq(accumulator.nudge(), NUDGE_SINK, "pause/unpause did not clear nudge");
        assertEq(accumulator.nudgeSplit(), 100, "pause/unpause did not clear nudgeSplit");

        vm.prank(pauser);
        vm.expectRevert(); // OwnableUnauthorizedAccount
        accumulator.setNudgeSplit(0);

        vm.prank(pauser);
        vm.expectRevert(); // OwnableUnauthorizedAccount
        accumulator.setNudgeAddress(address(0));
    }
}
```

### Tools Used
Manual review, Foundry.

### Recommended Mitigation Steps

Bring nudge configuration under the same dual-control surface as pausing, and bound the diversion below 100% so a residual phlimbo flow is always preserved:

1. Cap `nudgeSplit` strictly below 100 (for example, 50) so any nudge configuration still leaves a meaningful share to phlimbo.
2. Require either pauser co-signing or a timelock for `setNudgeAddress` and `setNudgeSplit`. A simple implementation is to require both `owner` and `pauser` calls within a window before the change applies, mirroring the dual-unpause pattern at the configuration layer.
3. Emit a high-visibility event when `nudgeSplit` is non-zero, and surface the effective split in `paused()`-equivalent monitoring helpers so off-chain observers can detect a soft pause.
