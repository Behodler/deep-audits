<!--
C4 Submission Metadata
Title: [M-02] Pausing any single token blocks all claims via claim() revert inconsistency with calculateClaimAmount()
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L584-L601
PoC File: poc-M-02.t.sol
-->

## Finding description and impact

### Summary

`claim()` reverts with `TokenIsPaused()` when iterating yield strategies if **any** strategy's token is paused ([StableYieldAccumulator.sol#L589](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L589)). In contrast, `calculateClaimAmount()` gracefully skips paused tokens using `continue` ([StableYieldAccumulator.sol#L803](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L803)). This inconsistency means pausing a single compromised token -- an action designed as a surgical response to depeg events -- blocks **all** yield claims across every strategy, including claims for healthy tokens.

### Vulnerability details

The `claim()` function iterates all yield strategies and checks each strategy's token pause status:

```solidity
// StableYieldAccumulator.sol — claim(), lines 584-601
for (uint256 i = 0; i < yieldStrategies.length; i++) {
    address strategy = yieldStrategies[i];
    address token = strategyTokens[strategy];
    if (token == address(0)) continue;

    if (tokenConfigs[token].paused) revert TokenIsPaused(); // <-- reverts on ANY paused token

    uint256 yield = _getYieldForStrategy(strategy, token);
    if (yield > 0) {
        IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
        emit RewardsCollected(strategy, yield);
        totalNormalizedYield += _normalizeAmount(yield, token);
        strategiesWithYield++;
    }
}
```

The companion view function `calculateClaimAmount()` handles the same iteration differently:

```solidity
// StableYieldAccumulator.sol — calculateClaimAmount(), lines 799-808
for (uint256 i = 0; i < yieldStrategies.length; i++) {
    address strategy = yieldStrategies[i];
    address token = strategyTokens[strategy];
    if (token == address(0)) continue;
    if (tokenConfigs[token].paused) continue; // <-- skips paused tokens gracefully

    uint256 yield = _getYieldForStrategy(strategy, token);
    if (yield > 0) {
        totalNormalizedYield += _normalizeAmount(yield, token);
    }
}
```

This creates a two-part problem:

1. **Availability denial**: Pausing one token (e.g., USDT during a depeg) prevents all claimers from collecting yield from any strategy, including perfectly healthy ones (e.g., USDC, USDS).

2. **Misleading view function**: `calculateClaimAmount()` reports non-zero claimable yield (correctly skipping the paused token), but `claim()` reverts when called. Off-chain integrations, including the `ClaimArbitrage` bot that relies on `calculateClaimAmount()` to calibrate its parameters, will repeatedly attempt claims that always fail.

### Attack path

1. Owner calls `pauseToken(USDT)` to isolate a depegging stablecoin -- the intended protective action.
2. `calculateClaimAmount()` returns a non-zero value reflecting yield from unpaused strategies (e.g., USDC yield).
3. A claimer or `ClaimArbitrage` bot sees available yield, prepares reward token payment, and calls `claim()`.
4. `claim()` iterates strategies, encounters the paused USDT token at line 589, and reverts with `TokenIsPaused()`.
5. All yield remains unclaimed. Phlimbo receives no reward tokens for distribution to stakers.
6. This DoS persists until the owner unpauses the problematic token, which may be unsafe to do.

### Impact

Protocol availability is degraded during precisely the scenarios where per-token pausing is most critical. When the owner pauses one compromised token to protect the system, they inadvertently freeze all yield claims across all strategies. This defeats the purpose of per-token pause functionality and creates a system-wide denial of service.

Concrete consequences:

- **Yield accumulation without distribution**: Yield accrues in strategies but cannot flow to Phlimbo or stakers.
- **ClaimArbitrage failure**: The arbitrage bot reads `calculateClaimAmount()`, sees positive yield, spends gas attempting `claim()`, and reverts every time.
- **Forced choice for the owner**: Either unpause the compromised token (accepting exposure to the compromised asset) or leave all claims blocked indefinitely.
- **No partial claiming**: Users cannot selectively claim yield from healthy strategies while a single strategy's token is paused.

## Recommended mitigation steps

Make `claim()` consistent with `calculateClaimAmount()` by skipping paused tokens instead of reverting. Replace the revert at line 589 with `continue`:

```solidity
// StableYieldAccumulator.sol — claim(), line 589
// Before (reverts on any paused token):
if (tokenConfigs[token].paused) revert TokenIsPaused();

// After (skips paused tokens, matching calculateClaimAmount() behavior):
if (tokenConfigs[token].paused) continue;
```

This change preserves the per-token pause as a surgical isolation mechanism: paused tokens are excluded from claims while healthy tokens remain claimable. The owner can pause a compromised token without disrupting the rest of the system.

If all-or-nothing claim semantics are intentionally desired, the alternative fix is to update `calculateClaimAmount()` to also revert when any token is paused, so that the view and state-changing functions are at least consistent with each other. However, the `continue` approach is recommended because it aligns with the documented design intent of per-token pausing for black swan events.
