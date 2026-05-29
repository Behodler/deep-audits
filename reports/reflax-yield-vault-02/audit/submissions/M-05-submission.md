<!--
C4 Submission Metadata
Title: [M-05] Migration Permanently Fails During Stablecoin Depeg Trapping User Funds
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L257-L292
PoC File: poc-M-05.t.sol
-->

## Finding description and impact

### Summary

The `migrate()` function in `UniV4StableYieldStrategy.sol` permanently fails during stablecoin depeg events due to a hardcoded 1% maximum slippage tolerance combined with a loss tolerance check. Since individual user withdrawals are disabled by design (`withdraw()` always reverts with `WithdrawalsDisabled`), this creates a scenario where user funds become trapped indefinitely during market stress conditions.

### Vulnerability details

The vulnerable code in [`UniV4StableYieldStrategy.sol#L257-L292`](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L257-L292):

```solidity
function migrate(address newStrategy) external onlyOwner nonReentrant {
    require(newStrategy != address(0), "UniV4StableYieldStrategy: new strategy cannot be zero address");

    // Remove all liquidity
    (uint256 depositOut, uint256 pairedOut) = _removeLiquidity(liquidityPosition);

    // FAILURE POINT 1: Swap paired tokens to deposit token
    uint256 swappedAmount = 0;
    if (pairedOut > 0) {
        swappedAmount = _swapWithSlippageCheck(pairedToken, depositToken, pairedOut);
    }

    uint256 totalRecovered = depositOut + swappedAmount;

    // Calculate loss
    uint256 actualLoss = 0;
    if (totalDeposited > totalRecovered) {
        actualLoss = totalDeposited - totalRecovered;
    }

    // FAILURE POINT 2: Check loss tolerance
    if (actualLoss > tolerableLoss) {
        revert MigrationLossExceedsTolerance(actualLoss, tolerableLoss);
    }
    // ...
}
```

The `_swapWithSlippageCheck()` function enforces slippage via a hardcoded maximum at [`UniV4StableYieldStrategy.sol#L522-L561`](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L522-L561):

```solidity
uint24 public constant MAX_SLIPPAGE_TOLERANCE = 100;  // 1% maximum

function _swapWithSlippageCheck(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)
    internal
    returns (uint256 amountOut)
{
    // Calculate minimum output based on 1:1 assumption
    uint256 expectedOut = _normalizeDecimals(amountIn, ...);
    uint256 minOut = (expectedOut * (BPS_DENOMINATOR - slippageTolerance)) / BPS_DENOMINATOR;

    // Execute swap...

    if (amountOut < minOut) {
        revert SlippageExceeded(minOut, amountOut);  // Reverts if depeg > 1%
    }
}
```

The owner cannot increase slippage tolerance above 1% due to the validation in `setSlippageTolerance()`:

```solidity
function setSlippageTolerance(uint24 newTolerance) external onlyOwner {
    if (newTolerance > MAX_SLIPPAGE_TOLERANCE) {
        revert SlippageToleranceTooHigh(newTolerance, MAX_SLIPPAGE_TOLERANCE);
    }
    slippageTolerance = newTolerance;
}
```

This creates two failure paths during depeg:

1. **SlippageExceeded**: If the stablecoin depeg exceeds 1%, the swap reverts
2. **MigrationLossExceedsTolerance**: Even if slippage were relaxed, the loss check would revert if losses exceed the configured tolerance

Combined with the disabled `withdraw()` function (which always reverts with `WithdrawalsDisabled`), users have no way to exit the strategy during depeg conditions.

### Impact

**Severity: Medium** - User funds are locked indefinitely during stablecoin depeg events.

The impact is significant because:

1. **Historical precedent**: Major stablecoins have depegged beyond 1% multiple times:
   - USDT dropped to ~$0.95 in May 2022 (5% depeg)
   - USDC dropped to ~$0.87 in March 2023 (13% depeg) during Silicon Valley Bank crisis
   - DAI has experienced 2-3% depegs during market volatility

2. **No escape mechanism**: Users cannot:
   - Withdraw individually (disabled by design)
   - Wait for owner to migrate (blocked by slippage/loss checks)
   - Access their funds through any other path

3. **Duration uncertainty**: Depeg events can last:
   - Hours to days for minor depegs
   - Weeks for sustained market stress
   - Permanently for failed stablecoins (UST scenario)

4. **Value at risk**: The entire TVL of the strategy is locked, not just the portion in the depegged token

For a strategy with $1,000,000 TVL in a USDC/USDT pool where USDT depegs to $0.95:
- ~$500,000 worth of USDT cannot be converted to USDC
- Migration fails, locking the full $1,000,000
- Users cannot access any funds until depeg resolves (if ever)

## Recommended mitigation steps

Implement one or more of the following solutions:

### Option 1: Emergency migration path with configurable slippage

Add an emergency function that allows the owner to set higher slippage during crisis scenarios:

```solidity
uint24 public emergencySlippageTolerance;
bool public emergencyModeActive;

function activateEmergencyMode(uint24 _emergencySlippage) external onlyOwner {
    require(_emergencySlippage <= 2000, "Max 20% emergency slippage");  // Reasonable upper bound
    emergencySlippageTolerance = _emergencySlippage;
    emergencyModeActive = true;
    emit EmergencyModeActivated(_emergencySlippage);
}

function emergencyMigrate(address newStrategy) external onlyOwner nonReentrant {
    require(emergencyModeActive, "Emergency mode not active");
    // Use emergencySlippageTolerance instead of slippageTolerance
    // Skip or relax loss tolerance check
}
```

### Option 2: Two-phase total withdrawal for users

Leverage the existing `totalWithdrawal` pattern from `AYieldStrategy`:

```solidity
function requestTotalWithdrawal() external onlyAuthorizedClient {
    // Initiate withdrawal with waiting period
    // Cache balance to prevent manipulation
}

function executeTotalWithdrawal() external onlyAuthorizedClient {
    // After waiting period, allow users to exit
    // Accept current market value (including depeg losses)
}
```

### Option 3: Circuit breaker with proportional exit

Add a depeg detection mechanism that pauses deposits and allows proportional exits:

```solidity
function checkDepegAndPause() external {
    // Query oracle or observe swap rates
    // If depeg > threshold, pause deposits
    // Enable proportional withdrawal of underlying tokens (not swapped)
}
```

The recommended approach is **Option 1** as it provides the most flexibility for crisis response while maintaining owner control over emergency decisions.
