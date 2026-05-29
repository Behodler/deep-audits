<!--
C4 Submission Metadata
Title: [M-03] All-or-Nothing Claim Design Creates Griefing Vector via Paused Token Inconsistency
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L434
PoC File: <repo>/workspace/stable-yield-accumulator/test/poc-M-03.t.sol
-->

## Finding description and impact

### Summary

The `StableYieldAccumulator` contract exhibits a semantic inconsistency between its view function `calculateClaimAmount()` and its state function `claim()` when handling paused tokens. The view function silently skips paused tokens and returns a valid claimable amount, while the state function reverts entirely if any strategy's token is paused. This creates a griefing vector where a single paused token blocks all yield claiming across the entire protocol.

### Vulnerability details

The inconsistency exists between two functions in [StableYieldAccumulator.sol](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol):

**In `claim()` at line 434 - REVERTS on paused tokens:**

```solidity
// Single pass: withdraw yield from each strategy and accumulate total
for (uint256 i = 0; i < yieldStrategies.length; i++) {
    address strategy = yieldStrategies[i];
    address token = strategyTokens[strategy];
    if (token == address(0)) continue;

    if (tokenConfigs[token].paused) revert TokenIsPaused();  // @audit REVERTS

    uint256 yield = _getYieldForStrategy(strategy, token);
    // ... process yield
}
```

**In `calculateClaimAmount()` at line 576 - SKIPS paused tokens:**

```solidity
for (uint256 i = 0; i < yieldStrategies.length; i++) {
    address strategy = yieldStrategies[i];
    address token = strategyTokens[strategy];
    if (token == address(0)) continue;
    if (tokenConfigs[token].paused) continue;  // @audit SKIPS (inconsistent)

    uint256 yield = _getYieldForStrategy(strategy, token);
    // ... calculate claimable amount
}
```

This creates the following attack/griefing scenario:

1. Protocol has 3 yield strategies: USDC (100 tokens yield), USDT (50 tokens), DAI (30 tokens)
2. DAI strategy encounters an issue (e.g., oracle failure, depeg risk), owner legitimately pauses DAI token config
3. User calls `calculateClaimAmount()` which returns 147 tokens (USDC + USDT with discount, skips DAI)
4. User approves tokens and prepares transaction based on this valid, non-zero return value
5. User calls `claim()` - transaction REVERTS with `TokenIsPaused` error
6. ALL yield claiming is blocked, even for healthy USDC and USDT strategies

### Impact

**Denial of Service**: A single paused token completely halts the yield claiming mechanism for all strategies. Users cannot claim any accumulated yield from healthy strategies when one strategy's token is paused.

**User Experience Degradation**: The view function `calculateClaimAmount()` returns misleading information. Users see a valid claimable amount, approve tokens, pay gas to submit transactions, only to have them revert. This breaks the reasonable expectation that if `calculateClaimAmount() > 0`, then `claim()` should succeed.

**Protocol Liveness Impact**: The protocol design assumes external claimers will regularly convert yield tokens to the reward token for Phlimbo distribution. When claiming is blocked, reward distribution to all stakers is halted, affecting the entire ecosystem.

**Severity Justification**: This is Medium severity because:
- No direct loss of funds (yield accumulates but is not lost)
- Protocol functionality is significantly impaired
- The issue manifests through legitimate admin action (pausing a problematic token)
- Recovery requires admin intervention (unpause the token)

## Recommended mitigation steps

Make both functions behave consistently. The recommended approach is to modify `claim()` to skip paused tokens, matching `calculateClaimAmount()` behavior:

```solidity
// In claim() function, replace line 434:
// BEFORE:
if (tokenConfigs[token].paused) revert TokenIsPaused();

// AFTER:
if (tokenConfigs[token].paused) continue;
```

This allows the protocol to:
1. Continue operating for healthy strategies when one strategy is paused
2. Maintain consistent behavior between view and state functions
3. Provide accurate information to users about claimable amounts

**Alternative approach** (less recommended): Modify `calculateClaimAmount()` to return 0 when any token is paused. This makes the view function match the state function behavior but still results in complete DoS of the claiming mechanism.

**Additional consideration**: If the all-or-nothing behavior is intentional (to prevent partial claims during protocol instability), the view function should accurately reflect this by reverting or returning 0 when any token is paused, and this behavior should be documented.
