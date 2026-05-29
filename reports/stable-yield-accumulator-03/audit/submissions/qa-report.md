# QA Report: StableYieldAccumulator / ClaimArbitrage

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 |
| **Total** | **4** |

---

## Low Risk Findings

### [L-01] Rounding dust in denormalization truncates claimer payment

**Location**: [`StableYieldAccumulator.sol#L687-L710`](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L687-L710)

**Description**: The `_denormalizeAmount()` function converts normalized 18-decimal amounts to the token's native decimal precision using integer division. When the target token has fewer than 18 decimals (e.g., USDC with 6 decimals), the division at line 704 truncates the remainder:

```solidity
if (decimals < 18) {
    scaled = scaled / (10 ** (18 - decimals));
}
```

For a 6-decimal token, this divides by `1e12`. A normalized value of `1234567890123456789` becomes `1234567`, discarding `890123456789` wei of precision. This truncation consistently rounds down, meaning every claim underpays the protocol by up to `1e12 - 1` wei in the normalized amount. While each individual loss is negligible, the direction is systematic: the claimer always benefits at the expense of Phlimbo.

**Impact**: Negligible per-transaction loss, but the consistent rounding direction means the protocol accumulates a small deficit over time.

**Recommendation**: Round up when computing the claimer payment to favor the protocol:

```solidity
if (decimals < 18) {
    uint256 divisor = 10 ** (18 - decimals);
    scaled = (scaled + divisor - 1) / divisor;
}
```

---

### [L-02] `setDiscountRate` allows 100% discount, enabling free yield claims

**Location**: [`StableYieldAccumulator.sol#L417-L423`](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L417-L423)

**Description**: The `setDiscountRate()` validation uses a strict greater-than check:

```solidity
function setDiscountRate(uint256 rate) external override onlyOwner {
    if (rate > 10000) revert ExceedsMaxDiscount();
    // ...
}
```

This permits `rate = 10000` (100% discount). The claimer payment formula at line 607 is:

```solidity
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
```

With `discountRate = 10000`, this evaluates to `totalNormalizedYield * 0 / 10000 = 0`. The claimer would receive all pending yield strategy tokens while paying nothing, effectively giving away accumulated yield for free.

While this requires the owner to explicitly set a 100% discount, it represents an operational footgun with no legitimate use case.

**Impact**: Owner misconfiguration could result in yield being distributed at zero cost. Requires owner action, so impact is limited to operational error scenarios.

**Recommendation**: Use a greater-than-or-equal check, or enforce a reasonable ceiling:

```solidity
if (rate >= 10000) revert ExceedsMaxDiscount();
```

Alternatively, set a protocol-appropriate maximum such as 5000 (50%) to prevent extreme configurations.

---

### [L-03] `ClaimArbitrage` has no token rescue function for stuck ERC20 tokens

**Location**: [`ClaimArbitrage.sol`](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol) (entire contract)

**Description**: The `ClaimArbitrage` contract has no mechanism to recover ERC20 tokens that arrive outside the normal `unlockCallback` flow. The contract's complete public interface consists of:

- `execute()` -- initiates arbitrage via `poolManager.unlock()`
- `unlockCallback()` -- processes arbitrage steps (only callable by PoolManager)
- `setStableToUSDCPool()` / `addKnownStable()` / `removeKnownStable()` / `setPoolKeys()` -- owner configuration
- `receive()` -- accepts ETH from WETH unwrap

None of these functions can transfer arbitrary ERC20 tokens out of the contract. Tokens can become stranded due to: (1) accidental direct transfers by users, (2) airdropped tokens, or (3) stablecoins received during `claim()` that are not registered in `knownStables` (the Step 5 loop at lines 195-217 only processes known stables, leaving unregistered tokens behind).

**Impact**: Any ERC20 tokens that arrive at the contract address outside the `knownStables` conversion loop are permanently locked with no recovery path.

**Recommendation**: Add an owner-callable rescue function:

```solidity
function rescue(address token, uint256 amount, address to) external onlyOwner {
    if (to == address(0)) revert ZeroAddress();
    IERC20(token).safeTransfer(to, amount);
}
```

---

### [L-04] `approvePhlimbo` uses raw `approve` instead of `forceApprove`

**Location**: [`StableYieldAccumulator.sol#L478-L483`](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L478-L483)

**Description**: The `approvePhlimbo()` function calls `IERC20(rewardToken).approve()` directly:

```solidity
function approvePhlimbo(uint256 amount) external onlyOwner {
    if (phlimbo == address(0)) revert ZeroAddress();
    if (rewardToken == address(0)) revert ZeroAddress();

    IERC20(rewardToken).approve(phlimbo, amount);
}
```

The contract imports `SafeERC20` and uses `safeTransferFrom` for the claim payment at line 611, but does not use the safe approval pattern here. Tokens like USDT require the allowance to be set to zero before setting a new non-zero value. If `approvePhlimbo()` is called when a non-zero approval already exists and the reward token enforces this behavior, the transaction will revert.

While USDC is the currently intended reward token and does not have this restriction, the contract architecture allows `rewardToken` to be set to any address, and the inconsistency with the rest of the contract's SafeERC20 usage introduces unnecessary fragility.

**Impact**: If the reward token is ever changed to a token with USDT-like approval semantics, `approvePhlimbo()` will revert when updating a non-zero allowance, requiring a workaround (first approving zero, then the desired amount in two separate transactions via a different path -- which may not exist).

**Recommendation**: Use OpenZeppelin's `forceApprove` from `SafeERC20`, which handles the zero-reset pattern automatically:

```solidity
IERC20(rewardToken).forceApprove(phlimbo, amount);
```
