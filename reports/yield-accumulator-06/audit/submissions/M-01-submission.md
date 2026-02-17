<!--
C4 Submission Metadata
Title: [M-01] Denormalization truncation to zero allows free yield extraction with low-decimal reward tokens
Severity: Medium
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L704
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Lines of Code

- [StableYieldAccumulator.sol#L607](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L607) - Discount division truncates normalized yield
- [StableYieldAccumulator.sol#L675](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L675) - Exchange rate division in `_normalizeAmount`
- [StableYieldAccumulator.sol#L699](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L699) - Reverse exchange rate division in `_denormalizeAmount`
- [StableYieldAccumulator.sol#L704](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L704) - Decimal denormalization truncates to zero

### Summary

The `claim()` function in `StableYieldAccumulator` passes the claimer's payment through a normalize-discount-denormalize pipeline that performs four sequential integer divisions, all of which truncate in favor of the claimer. When the reward token has low decimals (e.g., USDC with 6 decimals), the final denormalization at line 704 divides by `10^12`. If the accumulated value before this division is less than `10^12`, `actualPayment` truncates to zero. The claimer receives real yield tokens withdrawn from strategies (line 594) while `safeTransferFrom(claimer, SYA, 0)` succeeds silently, and `collectReward(0)` sends nothing to Phlimbo. There is no validation that `actualPayment > 0` when `totalNormalizedYield > 0`.

### Vulnerability details

The `claim()` function withdraws yield from all registered strategies to the claimer, then calculates how much the claimer must pay in the reward token:

```solidity
// Line 594: Yield is withdrawn to claimer BEFORE payment is calculated
IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);

// Line 598: Normalize yield to 18 decimals
totalNormalizedYield += _normalizeAmount(yield, token);

// Line 607: Apply discount (division #1 and #2 via exchange rate in _normalizeAmount)
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

// Line 608: Convert back to reward token decimals
uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

// Line 611: Transfer FROM claimer -- succeeds with amount=0
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

// Line 612: Protocol receives nothing
IPhlimbo(phlimbo).collectReward(actualPayment);
```

The `_denormalizeAmount` function performs the truncation:

```solidity
function _denormalizeAmount(uint256 amount, address token) internal view returns (uint256) {
    uint8 decimals = tokenConfigs[token].decimals;
    uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

    // Reverse exchange rate (division #3)
    uint256 scaled = amount;
    if (exchangeRate > 0 && exchangeRate != 1e18) {
        scaled = scaled * 1e18 / exchangeRate;
    }

    // Scale from 18 decimals to token decimals (division #4)
    if (decimals < 18) {
        scaled = scaled / (10 ** (18 - decimals));  // Line 704
    }

    return scaled;
}
```

For USDC (6 decimals) with a 2% discount, the math for 1 unit of yield:

| Step | Operation | Value |
|------|-----------|-------|
| Normalize | `1 * 10^12` | `1,000,000,000,000` |
| Discount | `1e12 * 9800 / 10000` | `980,000,000,000` |
| Denormalize | `980,000,000,000 / 10^12` | **0** |

The claimer receives 1 unit of USDC from the strategy but pays nothing. The boundary analysis shows that for yield amounts of 1 unit, `actualPayment = 0`, while for yield amounts of 2 units, `actualPayment = 1` (the claimer should pay ~1.96 but only pays 1, still benefiting from truncation bias).

### Impact

The impact manifests in two distinct ways:

**Free yield extraction (zero-payment claims):** When pending yield from any strategy is small enough that the normalized-discounted value falls below `10^(18 - rewardDecimals)` after all divisions, the claimer extracts yield tokens for free. With USDC as the reward token, any single-strategy yield below 2 units (0.000002 USDC) results in zero payment. The attack is essentially costless -- only gas is required -- making it particularly attractive on L2s where gas is negligible. An attacker can repeatedly call `claim()` as small yield amounts accrue, extracting each increment for free.

**Systematic rounding bias on non-zero claims:** Even when `actualPayment > 0`, the four truncation points consistently round down in the claimer's favor. Over thousands of claims across the protocol's lifetime, this compounds into a meaningful value leak from Phlimbo (and thus from stakers) to claimers.

**Concrete consequences:**
- `safeTransferFrom(claimer, SYA, 0)` succeeds -- claimer pays nothing
- `collectReward(0)` is called on Phlimbo -- protocol distributes nothing to stakers
- Yield tokens are irrecoverably transferred to the claimer at line 594 before payment is validated
- The withdraw-before-validate ordering means the protocol cannot recover from a zero-payment claim

### Proof of Concept

The PoC file (`poc-M-01.t.sol`) contains four passing tests that demonstrate the vulnerability:

1. **`test_M01_FreeYieldExtraction_SingleUnit`**: Sets up 1 unit of USDC yield in a strategy. After `claim()`, the claimer's balance increases by 1 while Phlimbo receives 0. Confirms `withdrawFrom` was called and `collectReward(0)` was invoked.

2. **`test_M01_FreeYieldExtraction_HigherDiscount`**: With a 50% discount rate, the free-yield window is identical (1 unit still truncates to 0), confirming the issue persists across discount configurations.

3. **`test_M01_RepeatedFreeExtraction`**: Executes 5 sequential `claim()` calls, each extracting 1 unit of yield for free. Total extracted: 5 units. Phlimbo balance: 0. Demonstrates the attack is repeatable.

4. **`test_M01_TruncationBoundary`**: Shows the exact boundary -- yield of 1 pays 0, yield of 2 pays 1 (should pay ~1.96). Even the non-zero case loses ~49% to truncation.

All four tests pass, confirming the vulnerability with the current contract code.

## Recommended mitigation steps

Two complementary fixes address both the zero-payment case and the systematic rounding bias:

### 1. Revert on zero payment when yield is non-zero

Add a minimum payment validation after denormalization to prevent free extraction:

```solidity
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);

// Prevent free yield extraction due to truncation
if (actualPayment == 0) revert ZeroAmount();

IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
IPhlimbo(phlimbo).collectReward(actualPayment);
```

This prevents the zero-payment attack entirely. Small yield amounts that would truncate to zero will simply revert, accumulating until the yield is large enough to produce a non-zero payment.

### 2. Use ceiling division in `_denormalizeAmount`

To eliminate the systematic rounding bias on non-zero payments, apply ceiling division so rounding favors the protocol:

```solidity
function _denormalizeAmount(uint256 amount, address token) internal view returns (uint256) {
    uint8 decimals = tokenConfigs[token].decimals;
    uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

    if (decimals == 0 && exchangeRate == 0) {
        return amount;
    }

    uint256 scaled = amount;
    if (exchangeRate > 0 && exchangeRate != 1e18) {
        // Ceiling division for exchange rate reversal
        scaled = (scaled * 1e18 + exchangeRate - 1) / exchangeRate;
    }

    if (decimals < 18) {
        uint256 divisor = 10 ** (18 - decimals);
        // Ceiling division for decimal scaling
        scaled = (scaled + divisor - 1) / divisor;
    } else if (decimals > 18) {
        scaled = scaled * (10 ** (decimals - 18));
    }

    return scaled;
}
```

With ceiling division, 1 unit of USDC yield would produce `actualPayment = 1` instead of 0, ensuring the claimer always pays at least the minimum denomination for any non-zero yield. This also corrects the boundary case: yield of 2 units would pay 2 instead of 1.

Both mitigations should be applied together. The revert guard provides a hard safety boundary, while ceiling division eliminates the cumulative rounding leak across all claims.
