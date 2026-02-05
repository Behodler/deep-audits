# QA Report: yield-accumulator

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| **Total** | **5** |

---

## Low Risk Findings

### [L-01] Precision Loss in Decimal Normalization Round Trip

**Location:** [StableYieldAccumulator.sol#L548-549](https://github.com/code-423n4/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L548-L549)

**Description:** When denormalizing amounts from 18 decimals back to token decimals for tokens with fewer than 18 decimals (e.g., USDC with 6 decimals), integer division causes precision loss. The calculation truncates rather than rounds, systematically favoring claimers by a dust amount on each claim.

```solidity
// In _denormalizeAmount():
if (decimals < 18) {
    scaled = scaled / (10 ** (18 - decimals));  // @audit truncation here
}
```

For example, if the normalized claimer payment is `14700000000000000001` (18 decimals), denormalizing to USDC (6 decimals) yields `14700000` instead of `14700001`, losing 1 wei equivalent.

**Impact:** Dust amounts are lost per claim. While individually negligible, this creates a systematic bias that favors claimers over the protocol across many transactions.

**Recommendation:** Consider implementing rounding-up logic for the protocol's benefit, or document this as accepted behavior:

```solidity
if (decimals < 18) {
    uint256 divisor = 10 ** (18 - decimals);
    scaled = (scaled + divisor - 1) / divisor;  // Round up
}
```

---

### [L-02] Missing Validation of Yield Strategy Return Values

**Location:** [StableYieldAccumulator.sol#L437-440](https://github.com/code-423n4/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L437-L440)

**Description:** The `claim()` function calls `IYieldStrategy(strategy).withdrawFrom()` but does not verify that the actual tokens received match the expected yield amount. If a yield strategy misbehaves (returns fewer tokens than expected), the claimer still pays the full calculated amount.

```solidity
// Withdraw yield from strategy to claimer
IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
emit RewardsCollected(strategy, yield);  // @audit assumes full amount was transferred

// Accumulate normalized yield for payment calculation
totalNormalizedYield += _normalizeAmount(yield, token);  // @audit payment based on expected, not actual
```

**Impact:** Claimers may overpay if strategies malfunction or are compromised. However, since claiming is voluntary and claimers can verify strategy health beforehand, this primarily affects sophisticated actors who accept this risk for the discount.

**Recommendation:** Verify actual token receipt by checking balance changes:

```solidity
uint256 balanceBefore = IERC20(token).balanceOf(msg.sender);
IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
uint256 actualReceived = IERC20(token).balanceOf(msg.sender) - balanceBefore;

if (actualReceived < yield) {
    revert InsufficientYieldReceived(strategy, yield, actualReceived);
}
```

---

### [L-03] MEV Front-Running on Claim Transactions

**Location:** [StableYieldAccumulator.sol#L420](https://github.com/code-423n4/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L420)

**Description:** The `claim()` function allows any external caller to claim all pending yield. Since yield accumulates continuously, MEV bots can monitor the mempool and front-run regular users' claim transactions to capture yield as soon as it becomes profitable.

```solidity
function claim() external override whenNotPaused nonReentrant {
    // No access control - anyone can claim
    // ...
}
```

**Impact:** This is fair competition rather than value extraction since all claimers pay the same discounted rate. However, it creates an uneven playing field where sophisticated MEV actors consistently capture yield before regular users, potentially discouraging broader participation in the claim mechanism.

**Recommendation:** This is a design choice that enables decentralized conversion. Consider documenting this behavior so users understand the competitive nature of claiming. If desired, a minimum yield threshold could be added to batch smaller accumulations.

---

### [L-04] Discount Rate Change Front-Running

**Location:** [StableYieldAccumulator.sol#L334-340](https://github.com/code-423n4/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L334-L340)

**Description:** When the owner calls `setDiscountRate()` to change the discount, the transaction is visible in the mempool. MEV bots can front-run this transaction to claim at the old (more favorable) rate before the change takes effect.

```solidity
function setDiscountRate(uint256 rate) external override onlyOwner {
    if (rate > 10000) revert ExceedsMaxDiscount();

    uint256 oldRate = discountRate;
    discountRate = rate;  // @audit takes effect immediately
    emit DiscountRateSet(oldRate, rate);
}
```

**Impact:** Information asymmetry favoring sophisticated actors. When the discount rate is being reduced (less favorable for claimers), bots can capture the last claims at the better rate. This is primarily a fairness concern rather than a security issue.

**Recommendation:** Consider implementing a timelock for discount rate changes, or use a commit-reveal scheme. At minimum, coordinate rate changes with low-yield periods:

```solidity
uint256 public pendingDiscountRate;
uint256 public discountRateEffectiveTime;

function setDiscountRate(uint256 rate) external onlyOwner {
    pendingDiscountRate = rate;
    discountRateEffectiveTime = block.timestamp + 1 days;
    emit DiscountRateChangeScheduled(discountRate, rate, discountRateEffectiveTime);
}
```

---

### [L-05] State Change After External Calls (CEI Pattern Violation)

**Location:** [StableYieldAccumulator.sol#L428-460](https://github.com/code-423n4/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L428-L460)

**Description:** The `claim()` function performs external calls to yield strategies (`withdrawFrom`) before completing all state changes and final transfers. While this violates the Checks-Effects-Interactions (CEI) pattern, the vulnerability is mitigated by the `nonReentrant` modifier.

```solidity
function claim() external override whenNotPaused nonReentrant {
    // ...
    for (uint256 i = 0; i < yieldStrategies.length; i++) {
        // ...
        IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);  // External call
        // ...
    }
    // ...
    IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);  // State change after
    IPhlimbo(phlimbo).collectReward(actualPayment);
}
```

**Impact:** No exploitable vulnerability exists due to EVM atomicity (entire transaction succeeds or reverts) and the `ReentrancyGuard`. However, the code pattern is non-idiomatic and could become problematic if the guard is removed in future refactoring.

**Recommendation:** Refactor to follow CEI pattern for code clarity and defense-in-depth. Consider a two-phase approach: first collect payment from claimer, then distribute yield:

```solidity
function claim() external override whenNotPaused nonReentrant {
    // 1. CHECKS: Validate state
    // 2. EFFECTS: Calculate amounts, update state
    // 3. INTERACTIONS: Transfer claimer payment first, then distribute yield

    IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

    for (uint256 i = 0; i < yieldStrategies.length; i++) {
        IYieldStrategy(strategy).withdrawFrom(token, minterAddress, yield, msg.sender);
    }
}
```

---
