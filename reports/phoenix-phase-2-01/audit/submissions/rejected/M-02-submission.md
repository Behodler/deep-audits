<!--
C4 Submission Metadata
Title: [M-02] Missing Slippage Protection in claim() allows front-running and rate manipulation
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L420-L460
PoC File: workspace/phoenix-phase-2/test/poc-M-02.t.sol
-->

## Finding description and impact

### Summary

The `claim()` function in StableYieldAccumulator.sol lacks slippage protection parameters, allowing claimers to be front-run or experience rate changes between quoting and execution.

### Vulnerability details

The vulnerable code pattern at [StableYieldAccumulator.sol#L420-L460](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L420-L460):

```solidity
function claim() external override whenNotPaused nonReentrant {
    if (phlimbo == address(0)) revert ZeroAddress();
    if (rewardToken == address(0)) revert ZeroAddress();
    if (minterAddress == address(0)) revert ZeroAddress();

    uint256 totalNormalizedYield = 0;
    uint256 strategiesWithYield = 0;

    // Single pass: withdraw yield from each strategy and accumulate total
    for (uint256 i = 0; i < yieldStrategies.length; i++) {
        address strategy = yieldStrategies[i];
        address token = strategyTokens[strategy];
        if (token == address(0)) continue;

        if (tokenConfigs[token].paused) revert TokenIsPaused();

        uint256 yield = _getYieldForStrategy(strategy, token);
        if (yield > 0) {
            IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
            emit RewardsCollected(strategy, yield);
            totalNormalizedYield += _normalizeAmount(yield, token);
            strategiesWithYield++;
        }
    }

    if (totalNormalizedYield == 0) revert ZeroAmount();

    // Calculate and collect claimer payment (apply discount)
    // discountRate is in basis points (e.g., 200 = 2%)
    uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
    uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

    // Transfer reward tokens FROM claimer TO this contract
    IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
    IPhlimbo(phlimbo).collectReward(actualPayment);

    emit RewardsClaimed(msg.sender, actualPayment, strategiesWithYield);
}
```

The function signature accepts no parameters to bound the payment amount. Users are expected to call `calculateClaimAmount()` first to get a quote, but both functions read the same mutable state variables (`discountRate`, `tokenConfigs`) at execution time.

The attack path is straightforward:

1. Claimer calls `calculateClaimAmount()` and receives a quote (e.g., 980 USDC with 2% discount)
2. Owner or front-runner calls `setDiscountRate(0)` to reduce/eliminate the discount
3. Claimer's `claim()` transaction executes at the new rate (1000 USDC with 0% discount)
4. Claimer pays 20 USDC more than expected with no way to revert the transaction

The same vulnerability exists for exchange rate changes via `setTokenConfig()`, where the `normalizedExchangeRate` parameter can be modified between quote and execution.

### Impact

Claimers have no mechanism to protect against rate changes occurring between quote retrieval and transaction execution. The concrete impacts are:

1. **Direct financial loss**: Claimers overpay when discount rates are reduced or exchange rates are manipulated
2. **Front-running exposure**: Any observer of the mempool can sandwich attack claimers by manipulating rates
3. **Operational uncertainty**: Users cannot rely on quotes, undermining trust in the claim mechanism

The PoC demonstrates three distinct scenarios with measured overpayments:
- **Discount rate change**: Claimer overpaid 20 USDC when discount changed from 2% to 0%
- **Exchange rate manipulation**: Claimer overpaid 98 USDC when exchange rate changed from 1.0 to 1.1
- **Race condition**: Claimer overpaid 15 USDC due to rate change between blocks

While the owner is trusted, even legitimate rate adjustments can inadvertently harm claimers whose transactions are pending. The lack of slippage protection is a design flaw that exposes users to unnecessary risk.

## Recommended mitigation steps

Add a `maxPayment` parameter to the `claim()` function to allow claimers to specify the maximum amount they are willing to pay:

```solidity
function claim(uint256 maxPayment) external override whenNotPaused nonReentrant {
    if (phlimbo == address(0)) revert ZeroAddress();
    if (rewardToken == address(0)) revert ZeroAddress();
    if (minterAddress == address(0)) revert ZeroAddress();

    uint256 totalNormalizedYield = 0;
    uint256 strategiesWithYield = 0;

    for (uint256 i = 0; i < yieldStrategies.length; i++) {
        address strategy = yieldStrategies[i];
        address token = strategyTokens[strategy];
        if (token == address(0)) continue;

        if (tokenConfigs[token].paused) revert TokenIsPaused();

        uint256 yield = _getYieldForStrategy(strategy, token);
        if (yield > 0) {
            IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
            emit RewardsCollected(strategy, yield);
            totalNormalizedYield += _normalizeAmount(yield, token);
            strategiesWithYield++;
        }
    }

    if (totalNormalizedYield == 0) revert ZeroAmount();

    uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
    uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

    // @audit-fix: Add slippage protection
    if (actualPayment > maxPayment) revert SlippageExceeded(actualPayment, maxPayment);

    IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
    IPhlimbo(phlimbo).collectReward(actualPayment);

    emit RewardsClaimed(msg.sender, actualPayment, strategiesWithYield);
}
```

Additionally, consider adding a timelock or governance delay for rate changes to give pending transactions time to execute at their quoted rates.
