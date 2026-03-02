# Validity Check Summary: stable-yield-accumulator

**Date:** 2026-02-17
**Checker:** Validity-Checker Agent
**Findings Reviewed:** 5
**Valid:** 3 | **Invalid:** 2

---

## Results Overview

| # | Finding | Severity | Verdict | Invalid Pattern |
|---|---------|----------|---------|-----------------|
| 1 | sqrtPriceX96 overflow in _getPhUSDPriceInUSDS | Medium | VALID | -- |
| 2 | Hardcoded sUSDS_USDC_pool creates unsettled deltas | Medium | INVALID | Admin mistake |
| 3 | CEI violation in claim() | Medium | INVALID | OOS / Speculation |
| 4 | Inconsistent rewardToken caching | Low | VALID | -- |
| 5 | Step 4 zero-amount error | Low | VALID | -- |

---

## Detailed Analysis

### Finding 1: sqrtPriceX96 overflow in _getPhUSDPriceInUSDS -- VALID

**Claimed Severity:** Medium

**Verdict:** VALID -- No invalid patterns detected.

**Analysis:**

This is a genuine code defect in `StableYieldAccumulator.sol` at lines 754-758 and 766-770. The expression `uint256(sqrtPriceX96) * uint256(sqrtPriceX96)` is evaluated as an intermediate result BEFORE being passed to `FullMath.mulDiv`. Since `sqrtPriceX96` is a `uint160`, its maximum value is approximately 2^160. Squaring a value above 2^128 produces a result exceeding 2^256, overflowing `uint256`.

**Code evidence** (`StableYieldAccumulator.sol:754-758`):
```solidity
priceInSUSDS = FullMath.mulDiv(
    uint256(sqrtPriceX96) * uint256(sqrtPriceX96),  // overflows when sqrtPriceX96 > 2^128
    1e18,
    1 << 192
);
```

**Key facts:**
- Uniswap V4 `MAX_SQRT_PRICE` = ~2^160, well above the 2^128 overflow threshold
- The multiplication overflows before `FullMath.mulDiv` receives the argument
- The fix is to pass `sqrtPriceX96` as a separate argument to `FullMath.mulDiv` to avoid intermediate overflow
- Root cause is entirely within in-scope contract code
- No admin mistake, no user error, no token assumption issues

**Invalid pattern checks:** All negative.

---

### Finding 2: Hardcoded sUSDS_USDC_pool creates unsettled deltas when reward token != USDC -- INVALID

**Claimed Severity:** Medium

**Verdict:** INVALID -- Matches "reckless admin mistakes" pattern.

**Analysis:**

This finding describes a scenario where the SYA reward token changes from USDC to something else, but the admin fails to update `sUSDS_USDC_pool` in ClaimArbitrage. However, the code explicitly documents this as an admin responsibility.

**Code evidence** (`ClaimArbitrage.sol:366-370`):
```solidity
// Note on sUSDS_USDC_pool: This pool is genuinely an sUSDS/USDC pool used for slippage
// coverage from the pump/unwind cycle. It is not renamed to reference the dynamic reward
// token because it handles a specific known pair (sUSDS<->USDC). If the reward token
// changes from USDC, the owner must update this pool accordingly.
```

**Why it is invalid:**
1. The code comments explicitly state the admin must update the pool when reward token changes
2. The `setPoolKeys()` function (line 543) exists precisely for this purpose
3. Per C4 known-invalid rules: "Reckless admin mistakes" are invalid findings
4. The finding itself carries a WARN flag acknowledging this is admin responsibility
5. Admin is expected to execute configuration changes atomically or in correct order

---

### Finding 3: CEI violation in claim(): yield sent before payment collected -- INVALID

**Claimed Severity:** Medium

**Verdict:** INVALID -- Matches "out-of-scope root cause" and "speculation on future code" patterns.

**Analysis:**

The finding identifies that `claim()` withdraws yield tokens to the claimer (line 594) before collecting payment (line 611). While this is technically a CEI ordering concern, two factors render it invalid:

**Mitigating factor 1 -- nonReentrant guard:**
```solidity
function claim() external override whenNotPaused nonReentrant {  // line 566
```
The `nonReentrant` modifier from OpenZeppelin's `ReentrancyGuard` prevents any reentrant call to `claim()`. This is the standard, accepted mitigation for CEI ordering issues.

**Mitigating factor 2 -- OOS dependency:**
The finding acknowledges that exploitation requires a "callback-capable yield strategy" -- meaning the external yield strategy contract would need to execute a callback during `withdrawFrom()`. The yield strategy contracts are external dependencies (accessed via `IYieldStrategy` interface). The root cause of any exploit would be in the OOS yield strategy implementation, not in StableYieldAccumulator.

**Why it is invalid:**
1. Per C4 rules: "Issues in parent/forked contracts where root cause is OOS" are invalid
2. The finding requires speculation about external contract behavior (callback in yield strategy)
3. The `nonReentrant` guard provides standard protection
4. No concrete, demonstrated exploit path exists that bypasses the reentrancy guard

---

### Finding 4: Inconsistent rewardToken caching -- VALID

**Claimed Severity:** Low

**Verdict:** VALID -- No invalid patterns detected.

**Analysis:**

`ClaimArbitrage.sol` caches `sya.rewardToken()` at line 141 of `unlockCallback()`, but `_settleResidualDelta()` at line 381 queries `sya.rewardToken()` independently instead of using the cached value. This is a genuine code inconsistency in in-scope code.

While there is no practical exploitability (the reward token cannot change mid-transaction), this represents a code quality issue and deviation from the contract's own stated design pattern (see the "PRE-FLIGHT: CACHE REWARD TOKEN" comment at line 135-139). Appropriately classified as Low/QA.

---

### Finding 5: Step 4 zero-amount error -- VALID

**Claimed Severity:** Low

**Verdict:** VALID -- No invalid patterns detected.

**Analysis:**

When the pump swap in Step 4 produces zero output, the revert message is misleading. This is a genuine code quality issue within in-scope code. No funds at risk. Correctly classified as Low/QA. No invalid patterns apply.

---

## Recommendation

**Submit:** Findings 1, 4, 5
**Do NOT submit:** Findings 2, 3

Finding 1 (sqrtPriceX96 overflow) is the strongest finding and should be submitted as Medium. Findings 4 and 5 are appropriate for a QA report.
