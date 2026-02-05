<!--
C4 Submission Metadata
Title: [H-01] Zero Exchange Rate Bypass Allows Unconfigured Token Exploitation
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L505-L507
PoC File: H-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `_normalizeAmount()` function in `StableYieldAccumulator.sol` contains a flawed fallback path that returns raw token amounts without decimal scaling when a token's configuration is uninitialized. This allows an attacker to drain all accumulated yield from strategies using non-18-decimal tokens for near-zero cost when the admin forgets to call `setTokenConfig()` after `addYieldStrategy()`.

### Root cause

In [`StableYieldAccumulator.sol#L505-L507`](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L505-L507), the normalization function checks if both `decimals` and `exchangeRate` are zero (indicating an unconfigured token) and returns the raw amount without any scaling:

```solidity
function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
    uint8 decimals = tokenConfigs[token].decimals;
    uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

    // If no config set, assume 18 decimals and 1:1 rate
    if (decimals == 0 && exchangeRate == 0) {
        return amount;  // BUG: Returns raw amount without scaling!
    }

    // ... scaling logic that is skipped
}
```

The comment states the intent is to "assume 18 decimals and 1:1 rate," but the implementation contradicts this by returning the raw amount instead of applying any scaling. For a 6-decimal token like USDC, `1000e6` (representing $1000) is returned as `1000e6` instead of being scaled to `1000e18`.

### Vulnerability details

The `addYieldStrategy()` function allows the owner to register a new yield strategy and its associated token, but it does not require or enforce that `setTokenConfig()` has been called for that token. This creates a dangerous operational gap where:

1. Admin calls `addYieldStrategy(strategy, USDC)` to add a USDC yield strategy
2. Admin forgets to call `setTokenConfig(USDC, 6, 1e18)`
3. The token config remains at default values: `decimals = 0`, `exchangeRate = 0`
4. When yield is claimed, `_normalizeAmount()` hits the early return path

The payment calculation flow becomes corrupted:
- Strategy has 1000 USDC yield (raw value: `1000e6`)
- `_normalizeAmount(1000e6, USDC)` returns `1000e6` (should return `1000e18`)
- With 2% discount, payment is calculated as `1000e6 * 0.98 = 980e6` normalized units
- If reward token is 18 decimals, `980e6` units represents `$0.00000000098`
- Attacker pays ~$0.00000000098 and receives $1000 worth of yield

### Impact

An attacker can drain the entire accumulated yield from any misconfigured strategy for essentially zero cost. The severity depends on the decimal mismatch between the yield token and reward token:

| Yield Token | Reward Token | Yield Value | Attacker Pays | Profit |
|-------------|--------------|-------------|---------------|--------|
| USDC (6 dec) | DAI (18 dec) | $1,000 | ~$0.000000001 | ~$1,000 |
| USDC (6 dec) | DAI (18 dec) | $1,000,000 | ~$0.000001 | ~$1,000,000 |

This constitutes direct theft of protocol funds with no constraints on the attacker. The attack is profitable from the first transaction and can drain all accumulated yield in a single call.

### Attack path

1. Admin adds yield strategy via `addYieldStrategy(strategy, USDC)` for a 6-decimal token
2. Admin forgets to call `setTokenConfig(USDC, 6, 1e18)`
3. Protocol operates normally; strategy accumulates 1000 USDC of yield
4. Attacker monitors for misconfigured tokens (trivial on-chain check)
5. Attacker calls `claim()` with minimal reward token balance
6. `_normalizeAmount(1000e6, USDC)` returns `1000e6` (not scaled to 18 decimals)
7. Payment calculated as `980e6` units of 18-decimal reward token = ~$0.00000000098
8. Attacker receives $1000 USDC, pays essentially nothing
9. Attacker repeats for any remaining yield

## Recommended mitigation steps

Require explicit token configuration before a strategy can be used. Add validation in `addYieldStrategy()` to revert if `setTokenConfig()` has not been called for the token:

```solidity
function addYieldStrategy(address strategy, address token) external onlyOwner {
    // Require token to be configured before strategy can be added
    require(
        tokenConfigs[token].decimals != 0 || tokenConfigs[token].normalizedExchangeRate != 0,
        "Token not configured"
    );

    strategies.push(StrategyInfo({
        strategy: IYieldStrategy(strategy),
        token: token
    }));

    emit YieldStrategyAdded(strategy, token);
}
```

Alternatively, modify `_normalizeAmount()` to properly implement the stated behavior of assuming 18 decimals when unconfigured:

```solidity
function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
    uint8 decimals = tokenConfigs[token].decimals;
    uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

    // If no config set, assume 18 decimals and 1:1 rate
    if (decimals == 0 && exchangeRate == 0) {
        // Already at 18 decimals, apply 1:1 rate (no change needed)
        return amount;
    }

    // For configured tokens with 0 decimals explicitly set,
    // treat as 18 decimals (this case should not occur in practice)
    if (decimals == 0) {
        decimals = 18;
    }

    // ... rest of scaling logic
}
```

The first approach is preferred as it enforces proper configuration at the operational level and prevents any possibility of the unconfigured path being reached with production funds.
