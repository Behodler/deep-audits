<!--
C4 Submission Metadata
Title: [M-02] All-or-Nothing Claim Design Creates Protocol-Wide DoS via Single Broken Strategy
Severity: Medium
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/70c0edab965681ea0447c756a51b777e21e339d2/src/StableYieldAccumulator.sol#L434-L451
PoC File: workspace/stable-yield-accumulator/test/poc-M-02.t.sol
-->

## Finding description and impact

### Summary

The `claim()` function in `StableYieldAccumulator.sol` iterates over all registered yield strategies in a single atomic transaction. Each strategy's `withdrawFrom()` is called directly without `try/catch` error handling. If any single strategy reverts -- due to insufficient liquidity, an external pause, or a bug -- the entire claim transaction reverts, blocking all yield collection across the protocol.

### Lines of Code

[StableYieldAccumulator.sol#L434-L451](https://github.com/Behodler/stable-yield-accumulator/blob/70c0edab965681ea0447c756a51b777e21e339d2/src/StableYieldAccumulator.sol#L434-L451)

### Vulnerability Details

The vulnerable code in the `claim()` function performs an unbounded loop over all registered yield strategies, calling `withdrawFrom()` on each one without any error isolation:

```solidity
// Single pass: withdraw yield from each strategy and accumulate total
for (uint256 i = 0; i < yieldStrategies.length; i++) {
    address strategy = yieldStrategies[i];
    address token = strategyTokens[strategy];
    if (token == address(0)) continue;

    if (tokenConfigs[token].paused) continue;

    uint256 yield = _getYieldForStrategy(strategy, token);
    if (yield > 0) {
        // Withdraw yield from strategy to claimer
        IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
        emit RewardsCollected(strategy, yield);

        // Accumulate normalized yield for payment calculation
        totalNormalizedYield += _normalizeAmount(yield, token);
        strategiesWithYield++;
    }
}
```

The `withdrawFrom()` call at line 444 is a direct external call with no `try/catch` wrapper. If this call reverts for any reason on any strategy, the entire transaction reverts. The consequence is that yield from all other healthy strategies becomes inaccessible.

The attack path is straightforward:

1. Strategies A (e.g., USDC vault) and B (e.g., USDT vault) are registered, both with pending yield.
2. Strategy B's underlying protocol pauses withdrawals, or the strategy contract has a bug causing `withdrawFrom()` to revert.
3. A user calls `claim()`. The loop processes Strategy A successfully, then reaches Strategy B. `withdrawFrom()` on Strategy B reverts.
4. The entire transaction reverts. The user receives nothing -- not even Strategy A's healthy yield.
5. All yield claims remain blocked until the owner identifies the broken strategy and calls `pauseToken(tokenB)` or removes the strategy.

While the owner can eventually mitigate this by pausing the broken strategy's token (the `tokenConfigs[token].paused` check at line 439 skips paused tokens), this creates a DoS window during which:

- The owner must detect the issue, identify the broken strategy, and submit a `pauseToken()` transaction.
- All yield accumulation during this window is inaccessible.
- There is no on-chain signal to indicate which strategy caused the failure.

### Impact

When any registered yield strategy enters a reverting state, all yield claims are blocked protocol-wide:

- **Phlimbo** receives no reward tokens, halting reward distribution to Limbo stakers.
- **Limbo stakers** receive no stable rewards for the duration of the DoS.
- **NFT holders** cannot exercise claim rights despite holding valid NFTs.
- **Yield continues accumulating** in healthy strategies but is completely inaccessible.

The severity is Medium because funds are not at direct risk of theft or permanent loss, but the protocol's core claim functionality is rendered unavailable. The DoS persists until manual owner intervention, and the duration depends on how quickly the owner detects and responds to the broken strategy.

## Proof of Concept

The full PoC is located at `workspace/stable-yield-accumulator/test/poc-M-02.t.sol`.

The core test demonstrates the vulnerability with two strategies -- one healthy and one that enters a broken state:

```solidity
function test_M02_BrokenStrategyBlocksAllClaims() public {
    uint256 yieldA = 60e18; // 60 DAI yield from healthy Strategy A
    uint256 yieldB = 40e18; // 40 USDT yield from Strategy B (will break)

    _setupYieldAndClaimer(yieldA, yieldB);

    // Verify both strategies have claimable yield
    uint256 totalYield = accumulator.getTotalYield();
    assertEq(totalYield, 100e18, "Should have 100e18 total yield");

    // Strategy B enters a broken state (withdrawFrom will revert)
    strategyB.setBroken(true);

    // Claimer tries to claim -- ENTIRE transaction reverts
    vm.prank(claimer);
    vm.expectRevert("Strategy: withdrawal failed - vault is locked");
    accumulator.claim(1, 0);

    // Strategy A's yield is still uncollected and inaccessible
    uint256 claimerTokenABalance = tokenA.balanceOf(claimer);
    assertEq(claimerTokenABalance, 0, "Claimer received ZERO from healthy Strategy A");

    uint256 stillPendingA = accumulator.getYield(address(strategyA));
    assertEq(stillPendingA, yieldA, "Strategy A yield is still pending, uncollectable");

    // Repeated attempts also fail (persistent DoS)
    vm.prank(claimer);
    vm.expectRevert("Strategy: withdrawal failed - vault is locked");
    accumulator.claim(1, 0);
}
```

A second test (`test_M02_MitigationViaPauseToken`) confirms the owner workaround exists but demonstrates the DoS window and that Strategy B's yield remains permanently uncollectable while paused.

## Recommended mitigation steps

Wrap each strategy's `withdrawFrom()` call in a `try/catch` block so that a single failing strategy does not poison the entire claim transaction. Emit an event for failed withdrawals to alert the owner:

```solidity
for (uint256 i = 0; i < yieldStrategies.length; i++) {
    address strategy = yieldStrategies[i];
    address token = strategyTokens[strategy];
    if (token == address(0)) continue;

    if (tokenConfigs[token].paused) continue;

    uint256 yield = _getYieldForStrategy(strategy, token);
    if (yield > 0) {
        try IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender) {
            emit RewardsCollected(strategy, yield);
            totalNormalizedYield += _normalizeAmount(yield, token);
            strategiesWithYield++;
        } catch {
            emit StrategyWithdrawalFailed(strategy, token, yield);
        }
    }
}
```

This approach allows claims to proceed with all available healthy strategies while gracefully skipping failed ones. The emitted `StrategyWithdrawalFailed` event provides an on-chain signal for monitoring and owner intervention.
