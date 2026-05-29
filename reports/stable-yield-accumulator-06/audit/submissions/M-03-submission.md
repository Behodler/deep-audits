<!--
C4 Submission Metadata
Title: [M-03] Raw approve() call in ClaimArbitrage and StableYieldAccumulator permanently blocks execution for USDT-like reward tokens
Severity: Medium
Root Cause: src/ClaimArbitrage.sol#L184
PoC File: workspace/yield-accumulator/test/poc-M-03.t.sol
-->

## Finding description and impact

### Lines of Code

- [ClaimArbitrage.sol#L184](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L184)
- [StableYieldAccumulator.sol#L482](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L482)

### Vulnerability Details

Both `ClaimArbitrage` and `StableYieldAccumulator` import OpenZeppelin's `SafeERC20` and declare `using SafeERC20 for IERC20`, yet two critical approval calls use raw `approve()` instead of `forceApprove()`.

**Location 1 -- ClaimArbitrage.sol line 184:**

```solidity
// Inside unlockCallback(), Step 3:
IERC20(rewardToken_).approve(address(sya), p.rewardTokenNeeded);
sya.claim();
```

**Location 2 -- StableYieldAccumulator.sol line 482:**

```solidity
function approvePhlimbo(uint256 amount) external onlyOwner {
    if (phlimbo == address(0)) revert ZeroAddress();
    if (rewardToken == address(0)) revert ZeroAddress();

    IERC20(rewardToken).approve(phlimbo, amount);
}
```

USDT is one of the most widely used stablecoins and is explicitly in-scope for C4 audits. Its `approve()` function enforces a non-standard restriction: it reverts when setting a new non-zero allowance while the current allowance is already non-zero. The caller must first set the allowance to zero before setting a new value. This is the exact behavior that OpenZeppelin's `forceApprove()` handles.

**Why residual allowance persists in ClaimArbitrage:**

In `ClaimArbitrage.unlockCallback()`, Step 3 approves `p.rewardTokenNeeded` tokens to SYA. However, `SYA.claim()` only pulls `actualPayment` from the caller, which is strictly less than `rewardTokenNeeded` due to the discount rate:

```solidity
// StableYieldAccumulator.claim() lines 607-611:
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
```

With a 2% discount rate, if `rewardTokenNeeded = 100e6`, then `actualPayment = 98e6`, leaving a residual allowance of `2e6`. On the next `execute()` call, the raw `approve(sya, rewardTokenNeeded)` at line 184 attempts to set a non-zero allowance while `2e6` remains, causing USDT to revert.

**Why residual allowance persists in approvePhlimbo:**

`approvePhlimbo()` sets an allowance for Phlimbo to pull reward tokens. After Phlimbo calls `collectReward()` and consumes a partial amount, the residual allowance is non-zero. The next call to `approvePhlimbo()` reverts because it attempts a non-zero-to-non-zero approval.

### Impact

If USDT (or any token with the same non-standard approve behavior) is configured as the reward token:

1. **ClaimArbitrage permanently bricked after first execution.** The `execute()` function can never be called again. Since ClaimArbitrage is the mechanism that converts yield strategy rewards into the reward token for Phlimbo distribution, the entire yield distribution pipeline is permanently blocked. There is no recovery path within the contract -- no function exists to clear the residual allowance.

2. **SYA's `approvePhlimbo()` permanently blocked after partial consumption.** The owner cannot re-approve Phlimbo for additional reward tokens once any partial consumption has occurred. This breaks the reward collection flow between SYA and Phlimbo.

The protocol is designed to support configurable reward tokens (the reward token is a mutable state variable, not hardcoded), and USDT is a natural candidate for a stablecoin-based reward system. The contracts already import and use SafeERC20 for other operations (`safeTransfer`, `safeTransferFrom`), making the use of raw `approve()` at these two locations an inconsistency that creates a permanent denial of service.

### Proof of Concept

The PoC file (`poc-M-03.t.sol`) contains three passing tests that demonstrate this vulnerability:

**Test 1: `test_M03_ClaimArbitrageBlockedByUSDTApprove`**
1. Deploys a mock USDT with the standard USDT non-zero-to-non-zero approve restriction
2. First `executeArbitrage(100e6, 98e6)` succeeds -- allowance was 0, so approve works
3. After SYA pulls 98e6, residual allowance = 2e6
4. Second `executeArbitrage(100e6, 98e6)` reverts with "USDT: approve from non-zero to non-zero allowance"
5. Even with different parameters, the contract remains permanently bricked

**Test 2: `test_M03_SYAApprovePhlimboBlockedByUSDTApprove`**
1. Owner calls `approvePhlimbo(1000e6)` -- succeeds (allowance was 0)
2. Phlimbo collects 800e6, leaving residual allowance = 200e6
3. Owner calls `approvePhlimbo(1000e6)` again -- reverts permanently

**Test 3: `test_M03_ForceApproveFixesTheIssue`**
1. Demonstrates that the forceApprove pattern (approve to 0, then approve to new value) resolves the issue completely

## Recommended mitigation steps

Replace raw `approve()` with `forceApprove()` from OpenZeppelin's SafeERC20 library, which is already imported and declared with `using SafeERC20 for IERC20` in both contracts.

**ClaimArbitrage.sol line 184:**

```diff
- IERC20(rewardToken_).approve(address(sya), p.rewardTokenNeeded);
+ IERC20(rewardToken_).forceApprove(address(sya), p.rewardTokenNeeded);
```

**StableYieldAccumulator.sol line 482:**

```diff
- IERC20(rewardToken).approve(phlimbo, amount);
+ IERC20(rewardToken).forceApprove(phlimbo, amount);
```

`forceApprove()` handles the USDT edge case by first setting the allowance to zero before setting the desired value. Since both contracts already import and use SafeERC20 for other ERC20 operations, this change is minimal and consistent with the existing codebase patterns.
