<!--
C4 Submission Metadata
Title: [M-03] Pausing any single token blocks ALL claims via DoS -- inconsistency between claim() and calculateClaimAmount()
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L434
PoC File: poc-M-03.t.sol
-->

## Finding description and impact

### Summary

`claim()` and `calculateClaimAmount()` handle paused tokens with contradictory semantics. When a token is paused, `calculateClaimAmount()` (line 576) gracefully skips it with `continue` and returns a valid claimable amount reflecting only the healthy strategies. However, `claim()` (line 434) treats any paused token as a hard stop, reverting the entire transaction with `TokenIsPaused()`. This means pausing a single low-value token creates a denial-of-service on all yield claiming across every registered strategy.

### Root cause

In [`StableYieldAccumulator.sol#L434`](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L434), the `claim()` function reverts when it encounters any paused token during its iteration over yield strategies:

```solidity
// claim() at line 420-460
function claim() external override whenNotPaused nonReentrant {
    // ...
    for (uint256 i = 0; i < yieldStrategies.length; i++) {
        address strategy = yieldStrategies[i];
        address token = strategyTokens[strategy];
        if (token == address(0)) continue;

        if (tokenConfigs[token].paused) revert TokenIsPaused(); // @audit LINE 434: REVERTS entire tx

        uint256 yield = _getYieldForStrategy(strategy, token);
        // ...
    }
    // ...
}
```

Meanwhile, `calculateClaimAmount()` uses `continue` to skip paused tokens:

```solidity
// calculateClaimAmount() at line 562-591
function calculateClaimAmount() external view override returns (uint256) {
    // ...
    for (uint256 i = 0; i < yieldStrategies.length; i++) {
        address strategy = yieldStrategies[i];
        address token = strategyTokens[strategy];
        if (token == address(0)) continue;
        if (tokenConfigs[token].paused) continue; // @audit LINE 576: SKIPS gracefully

        uint256 yield = _getYieldForStrategy(strategy, token);
        // ...
    }
    // ...
}
```

The view function and the state-changing function disagree on the protocol's behavior when a token is paused. The view function promises that partial claiming (excluding paused tokens) is possible; the state function rejects all claims entirely.

### Vulnerability details

The token pause mechanism is designed for black swan events such as a stablecoin depeg. The project documentation explicitly lists "Pause tokens (for black swan events)" as an owner control. In a realistic scenario:

1. The protocol has three yield strategies: USDC (100 tokens yield), USDT (50 tokens yield), and DAI (30 tokens yield).
2. DAI begins depegging. The owner correctly pauses the DAI token config to prevent claiming DAI at a stale 1:1 exchange rate.
3. A user (or the automated `ClaimArbitrage` mechanism) calls `calculateClaimAmount()` to check whether yield is claimable. The function returns 147 tokens (150 tokens from USDC + USDT yield, minus 2% discount), correctly excluding the paused DAI.
4. The user calls `claim()` expecting to receive USDC and USDT yield for 147 reward tokens.
5. `claim()` iterates over all strategies, hits the paused DAI token at line 434, and reverts with `TokenIsPaused()`.
6. No yield is claimed from any strategy. The 150 tokens of healthy USDC and USDT yield remain locked.

Additionally, `getTotalYield()` (line 630) does not check pause status at all, further compounding the inconsistency across the contract's public interface.

### Impact

**Denial of service on all yield claiming.** Pausing a single token -- even a low-value or zero-yield token -- blocks yield collection from every registered strategy. The concrete consequences are:

- **Accumulated yield from healthy strategies becomes uncollectable** until the paused token is unpaused. If the pause is due to a genuine depeg event, the token may remain paused for an extended period.
- **`calculateClaimAmount()` returns misleading values.** External integrations and users relying on this view function will prepare transactions that always revert, wasting gas and creating a poor user experience.
- **Phlimbo reward distribution stalls.** Since `claim()` is the mechanism by which reward tokens flow to Phlimbo for staker distribution, the entire reward pipeline halts.
- **The intended pause granularity is defeated.** The admin's intent is to pause one problematic token, but the effect is a global freeze on all claiming.

### Attack path

1. Protocol operates with multiple yield strategies (USDC, USDT, DAI) accumulating yield normally.
2. Admin pauses a single stablecoin token config (e.g., DAI during a depeg event) -- this is expected admin behavior, not adversarial.
3. `calculateClaimAmount()` returns a non-zero amount (skips paused DAI, reports yield from USDC + USDT).
4. Any caller invokes `claim()` expecting to collect the reported yield.
5. `claim()` encounters the paused DAI token and reverts with `TokenIsPaused()`.
6. All yield claiming is blocked across all strategies, not just the paused token.
7. This persists until the admin unpauses the token, which may not be appropriate if the underlying issue (e.g., depeg) is ongoing.

## Recommended mitigation steps

Align `claim()` with `calculateClaimAmount()` so that paused tokens are skipped rather than causing a revert. This preserves the admin's ability to isolate a problematic token without disrupting yield collection from healthy strategies:

```solidity
// In claim(), change line 434 from:
if (tokenConfigs[token].paused) revert TokenIsPaused();

// To:
if (tokenConfigs[token].paused) continue;
```

If the all-or-nothing behavior in `claim()` is intentional (i.e., the protocol deliberately wants to block all claims when any token is paused), then `calculateClaimAmount()` should be updated to match by also reverting:

```solidity
// In calculateClaimAmount(), change line 576 from:
if (tokenConfigs[token].paused) continue;

// To:
if (tokenConfigs[token].paused) revert TokenIsPaused();
```

The first option (skip in `claim()`) is recommended because it preserves the granularity of the pause mechanism and matches the documented design intent of pausing individual tokens during black swan events without impacting unrelated strategies.
