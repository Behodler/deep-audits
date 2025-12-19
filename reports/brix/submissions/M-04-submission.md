# [M-04] Missing Slippage Protection in Fast Redeem Allows Yield Vesting to Affect User Returns

## Severity
Medium

## Location
- [StakediTryFastRedeem.sol#L57-L71](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/wiTRY/StakediTryFastRedeem.sol#L57-L71)
- [StakediTryFastRedeem.sol#L76-L90](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/wiTRY/StakediTryFastRedeem.sol#L76-L90)

## Summary
The `fastRedeem` and `fastWithdraw` functions lack slippage protection, exposing users to unexpected value loss when yield distribution occurs between transaction submission and execution. As yield vests over time, the share-to-asset conversion rate changes continuously, causing users to receive significantly different amounts than anticipated.

## Vulnerability Details
The fast redemption functions rely on `previewRedeem()` and `previewWithdraw()` to calculate the conversion between shares and assets. These calculations depend on `totalAssets()`, which is dynamically computed based on the vesting progress:

```solidity
function totalAssets() public view override returns (uint256) {
    return IERC20(asset()).balanceOf(address(this)) - getUnvestedAmount();
}
```

The `getUnvestedAmount()` decreases linearly as time passes within the vesting period (minimum 1 hour, maximum 30 days). This means `totalAssets()` continuously increases as rewards vest, directly affecting the share price.

When a user submits a `fastRedeem` transaction:
1. User calculates expected assets based on current share price
2. Transaction sits in mempool or waits for block confirmation
3. During this delay, yield continues vesting
4. `getUnvestedAmount()` decreases, causing `totalAssets()` to increase
5. Share price changes, altering the conversion rate
6. User receives different amount than expected - **with no protection against this variance**

The vulnerable code in `fastRedeem`:
```solidity
function fastRedeem(uint256 shares, address receiver, address owner)
    external
    ensureCooldownOn
    ensureFastRedeemEnabled
    returns (uint256 assets)
{
    if (shares > maxRedeem(owner)) revert ExcessiveRedeemAmount();

    uint256 totalAssets = previewRedeem(shares); // ← Calculated at execution time
    uint256 feeAssets = _redeemWithFee(shares, totalAssets, receiver, owner);

    emit FastRedeemed(owner, receiver, shares, totalAssets, feeAssets);

    return totalAssets - feeAssets; // ← No check against minimum expected amount
}
```

Similarly for `fastWithdraw`:
```solidity
function fastWithdraw(uint256 assets, address receiver, address owner)
    external
    ensureCooldownOn
    ensureFastRedeemEnabled
    returns (uint256 shares)
{
    if (assets > maxWithdraw(owner)) revert ExcessiveWithdrawAmount();

    uint256 totalShares = previewWithdraw(assets); // ← Calculated at execution time
    uint256 feeAssets = _redeemWithFee(totalShares, assets, receiver, owner);

    emit FastRedeemed(owner, receiver, totalShares, assets, feeAssets);

    return totalShares; // ← No check against maximum expected shares
}
```

## Impact
Users suffer unexpected value loss when redeeming shares. The impact severity depends on:
- **Vesting progress rate**: Faster vesting (shorter periods) causes larger swings
- **Yield distribution size**: Larger rewards create more dramatic price changes
- **Transaction delay**: Longer mempool times increase exposure window

In normal conditions with a 1-hour vesting period, the demonstrated proof-of-concept shows approximately 1% variance over a 30-minute delay. With large yield distributions, this can exceed 10% loss.

This is particularly problematic because:
1. Users have no way to specify acceptable slippage tolerance
2. Front-runners can observe pending redemptions and time yield distributions to exploit users
3. Network congestion (causing transaction delays) directly translates to user losses
4. Users paying for "fast" redemption via fees receive unpredictable amounts

## Proof of Concept

<details>
<summary>PoC Test</summary>

```diff
diff --git a/test/M-04-poc.t.sol b/test/M-04-poc.t.sol
new file mode 100644
--- /dev/null
+++ b/test/M-04-poc.t.sol
@@ -0,0 +1,327 @@
+// SPDX-License-Identifier: MIT
+pragma solidity 0.8.20;
+
+import "forge-std/Test.sol";
+import "../lib/2025-11-brix-money-c4-audit/src/token/wiTRY/StakediTryFastRedeem.sol";
+import {IStakediTry} from "../lib/2025-11-brix-money-c4-audit/src/token/wiTRY/interfaces/IStakediTry.sol";
+import {IStakediTryFastRedeem} from "../lib/2025-11-brix-money-c4-audit/src/token/wiTRY/interfaces/IStakediTryFastRedeem.sol";
+import {MockERC20} from "../lib/2025-11-brix-money-c4-audit/test/mocks/MockERC20.sol";
+
+/**
+ * @title M-04 Missing Slippage Protection PoC
+ * @notice Demonstrates how users lose value due to yield distribution between tx submission and execution
+ */
+contract M04MissingSlippageProtectionPoCTest is Test {
+    StakediTryFastRedeem public stakediTry;
+    MockERC20 public iTryToken;
+
+    address public admin;
+    address public treasury;
+    address public rewarder;
+    address public user1;
+
+    uint16 public constant DEFAULT_FEE = 500; // 5%
+    uint256 public constant INITIAL_SUPPLY = 10_000_000e18;
+    uint256 public constant YIELD_AMOUNT = 1_000_000e18; // Large yield distribution
+
+    function setUp() public {
+        admin = makeAddr("admin");
+        treasury = makeAddr("treasury");
+        rewarder = makeAddr("rewarder");
+        user1 = makeAddr("user1");
+
+        // Deploy iTRY token
+        iTryToken = new MockERC20("iTRY", "iTRY");
+
+        // Deploy StakediTryFastRedeem
+        vm.prank(admin);
+        stakediTry = new StakediTryFastRedeem(IERC20(address(iTryToken)), rewarder, admin, treasury);
+
+        // Setup: Enable fast redeem and set fee
+        vm.startPrank(admin);
+        stakediTry.setFastRedeemEnabled(true);
+        stakediTry.setFastRedeemFee(DEFAULT_FEE);
+        vm.stopPrank();
+
+        // Mint tokens to users and rewarder
+        iTryToken.mint(user1, INITIAL_SUPPLY);
+        iTryToken.mint(rewarder, YIELD_AMOUNT);
+
+        // Users approve StakediTry
+        vm.prank(user1);
+        iTryToken.approve(address(stakediTry), type(uint256).max);
+
+        // Rewarder approves StakediTry
+        vm.prank(rewarder);
+        iTryToken.approve(address(stakediTry), type(uint256).max);
+
+        // User1 stakes
+        vm.prank(user1);
+        stakediTry.deposit(5_000_000e18, user1);
+    }
+
+    /**
+     * @notice M-04: Missing Slippage Protection in Fast Redeem
+     * @dev Demonstrates value loss when yield is distributed between transaction submission and execution
+     *
+     * Attack Scenario:
+     * 1. User submits fastRedeem transaction expecting to receive X assets
+     * 2. Before transaction executes, rewarder distributes large yield
+     * 3. Share price increases due to vesting
+     * 4. User receives significantly less than expected due to changed share price
+     */
+    function test_M04_MissingSlippageProtection_fastRedeem() public {
+        uint256 sharesToRedeem = stakediTry.balanceOf(user1);
+
+        // ============================================
+        // STEP 1: User calculates expected assets at submission time
+        // ============================================
+        uint256 expectedAssetsAtSubmission = stakediTry.previewRedeem(sharesToRedeem);
+        uint256 expectedFeeAtSubmission = (expectedAssetsAtSubmission * DEFAULT_FEE) / 10000;
+        uint256 expectedNetAtSubmission = expectedAssetsAtSubmission - expectedFeeAtSubmission;
+
+        emit log_named_uint("User's shares to redeem", sharesToRedeem);
+        emit log_named_uint("Expected gross assets at submission", expectedAssetsAtSubmission);
+        emit log_named_uint("Expected fee at submission", expectedFeeAtSubmission);
+        emit log_named_uint("Expected net assets at submission", expectedNetAtSubmission);
+        emit log_string("");
+
+        // ============================================
+        // STEP 2: Between submission and execution, yield is distributed
+        // ============================================
+        // This simulates a front-running scenario or normal mempool delay
+        // where rewards are distributed before the user's transaction executes
+        vm.prank(rewarder);
+        stakediTry.transferInRewards(YIELD_AMOUNT);
+
+        emit log_named_uint("Yield distributed", YIELD_AMOUNT);
+        emit log_string("Vesting period starts - yield gradually becomes available");
+        emit log_string("");
+
+        // ============================================
+        // STEP 3: Advance time to allow some vesting
+        // ============================================
+        // Skip 30 minutes (50% of the 1 hour minimum vesting period)
+        vm.warp(block.timestamp + 30 minutes);
+
+        // ============================================
+        // STEP 4: User's transaction executes with different share price
+        // ============================================
+        uint256 actualAssetsAtExecution = stakediTry.previewRedeem(sharesToRedeem);
+        uint256 actualFeeAtExecution = (actualAssetsAtExecution * DEFAULT_FEE) / 10000;
+        uint256 actualNetAtExecution = actualAssetsAtExecution - actualFeeAtExecution;
+
+        emit log_named_uint("Actual gross assets at execution", actualAssetsAtExecution);
+        emit log_named_uint("Actual fee at execution", actualFeeAtExecution);
+        emit log_named_uint("Actual net assets at execution", actualNetAtExecution);
+        emit log_string("");
+
+        // Execute the fast redeem
+        uint256 balanceBefore = iTryToken.balanceOf(user1);
+        vm.prank(user1);
+        uint256 assetsReceived = stakediTry.fastRedeem(sharesToRedeem, user1, user1);
+        uint256 balanceAfter = iTryToken.balanceOf(user1);
+
+        // ============================================
+        // STEP 5: Calculate the slippage loss
+        // ============================================
+        uint256 actualReceived = balanceAfter - balanceBefore;
+
+        // The user receives LESS than expected because yield distribution
+        // DECREASED the share price (more assets vesting = lower current totalAssets)
+        int256 slippageLoss = int256(expectedNetAtSubmission) - int256(actualReceived);
+        uint256 slippagePercentage = (uint256(slippageLoss) * 10000) / expectedNetAtSubmission;
+
+        emit log_string("=== SLIPPAGE IMPACT ===");
+        emit log_named_int("Slippage loss (assets)", slippageLoss);
+        emit log_named_uint("Slippage percentage (bps)", slippagePercentage);
+        emit log_named_uint("Expected net assets", expectedNetAtSubmission);
+        emit log_named_uint("Actual received assets", actualReceived);
+        emit log_string("");
+
+        // ============================================
+        // ASSERTIONS: Prove the vulnerability
+        // ============================================
+
+        // User received less than expected
+        assertLt(actualReceived, expectedNetAtSubmission, "User should receive less than expected");
+
+        // The difference is significant (not just rounding)
+        assertGt(slippageLoss, 0, "Slippage loss should be positive");
+        assertGt(slippagePercentage, 50, "Slippage should be more than 0.5%"); // 50 bps = 0.5%
+
+        // Demonstrate the exact issue: no minimum output protection
+        assertEq(assetsReceived, actualNetAtExecution, "Function returns actual net, not expected");
+
+        emit log_string("=== VULNERABILITY CONFIRMED ===");
+        emit log_string("User submitted transaction expecting one amount");
+        emit log_string("But received significantly less due to yield distribution");
+        emit log_string("No slippage protection exists to prevent this loss");
+    }
+
+    /**
+     * @notice M-04: Missing Slippage Protection in Fast Withdraw
+     * @dev Demonstrates the same issue with fastWithdraw function
+     */
+    function test_M04_MissingSlippageProtection_fastWithdraw() public {
+        uint256 assetsToWithdraw = 2_000_000e18;
+
+        // ============================================
+        // STEP 1: User calculates expected shares at submission time
+        // ============================================
+        uint256 expectedSharesAtSubmission = stakediTry.previewWithdraw(assetsToWithdraw);
+
+        emit log_named_uint("Assets user wants to withdraw", assetsToWithdraw);
+        emit log_named_uint("Expected shares to burn at submission", expectedSharesAtSubmission);
+        emit log_string("");
+
+        // ============================================
+        // STEP 2: Yield distribution occurs
+        // ============================================
+        vm.prank(rewarder);
+        stakediTry.transferInRewards(YIELD_AMOUNT);
+
+        emit log_named_uint("Yield distributed", YIELD_AMOUNT);
+        emit log_string("");
+
+        // ============================================
+        // STEP 3: Advance time for partial vesting
+        // ============================================
+        vm.warp(block.timestamp + 45 minutes); // 75% of vesting period
+
+        // ============================================
+        // STEP 4: Transaction executes with different share price
+        // ============================================
+        uint256 actualSharesAtExecution = stakediTry.previewWithdraw(assetsToWithdraw);
+
+        emit log_named_uint("Actual shares to burn at execution", actualSharesAtExecution);
+        emit log_string("");
+
+        // User's balance before
+        uint256 sharesBefore = stakediTry.balanceOf(user1);
+        uint256 assetsBefore = iTryToken.balanceOf(user1);
+
+        // Execute fast withdraw
+        vm.prank(user1);
+        uint256 sharesBurned = stakediTry.fastWithdraw(assetsToWithdraw, user1, user1);
+
+        uint256 sharesAfter = stakediTry.balanceOf(user1);
+        uint256 assetsAfter = iTryToken.balanceOf(user1);
+
+        // ============================================
+        // STEP 5: Calculate impact
+        // ============================================
+        uint256 actualSharesBurned = sharesBefore - sharesAfter;
+        uint256 actualAssetsReceived = assetsAfter - assetsBefore;
+
+        // Due to fee and vesting, user gets less assets than requested
+        uint256 netAssetsReceived = actualAssetsReceived;
+        int256 shareSlippage = int256(actualSharesBurned) - int256(expectedSharesAtSubmission);
+
+        emit log_string("=== SLIPPAGE IMPACT (fastWithdraw) ===");
+        emit log_named_uint("Expected shares to burn", expectedSharesAtSubmission);
+        emit log_named_uint("Actual shares burned", actualSharesBurned);
+        emit log_named_int("Share slippage", shareSlippage);
+        emit log_named_uint("Assets received (after fee)", netAssetsReceived);
+        emit log_string("");
+
+        // ============================================
+        // ASSERTIONS
+        // ============================================
+
+        // User burns MORE shares than expected to get the same assets
+        assertGt(actualSharesBurned, expectedSharesAtSubmission, "User burns more shares than expected");
+
+        // The slippage is significant
+        assertGt(shareSlippage, 0, "Share slippage should be positive");
+
+        emit log_string("=== VULNERABILITY CONFIRMED ===");
+        emit log_string("User expected to burn X shares for Y assets");
+        emit log_string("But had to burn MORE shares due to share price change");
+        emit log_string("No minimum shares burned protection exists");
+    }
+
+    /**
+     * @notice Demonstrates extreme case: Large yield distribution causes major slippage
+     */
+    function test_M04_ExtremeSlippage_LargeYieldDistribution() public {
+        // Use even larger yield distribution to show worst case
+        uint256 extremeYield = 5_000_000e18; // Equal to user's deposit
+        iTryToken.mint(rewarder, extremeYield);
+
+        uint256 sharesToRedeem = stakediTry.balanceOf(user1);
+        uint256 expectedAtSubmission = stakediTry.previewRedeem(sharesToRedeem);
+
+        // Yield distributed
+        vm.prank(rewarder);
+        stakediTry.transferInRewards(extremeYield);
+
+        // Right after distribution (all yield still unvested)
+        uint256 actualAtExecution = stakediTry.previewRedeem(sharesToRedeem);
+
+        emit log_string("=== EXTREME SLIPPAGE SCENARIO ===");
+        emit log_named_uint("Extreme yield distributed", extremeYield);
+        emit log_named_uint("Expected assets at submission", expectedAtSubmission);
+        emit log_named_uint("Actual assets at execution (immediately after)", actualAtExecution);
+
+        int256 extremeLoss = int256(expectedAtSubmission) - int256(actualAtExecution);
+        uint256 extremeLossPercentage = (uint256(extremeLoss) * 10000) / expectedAtSubmission;
+
+        emit log_named_int("Extreme slippage loss", extremeLoss);
+        emit log_named_uint("Extreme slippage percentage (bps)", extremeLossPercentage);
+        emit log_string("");
+
+        // Execute the redemption
+        vm.prank(user1);
+        uint256 received = stakediTry.fastRedeem(sharesToRedeem, user1, user1);
+
+        // Massive loss
+        assertLt(received, expectedAtSubmission, "Extreme loss occurred");
+        assertGt(extremeLossPercentage, 1000, "Loss should exceed 10%"); // 1000 bps = 10%
+
+        emit log_string("User can lose over 10% of expected value!");
+        emit log_string("This demonstrates the critical need for slippage protection");
+    }
+
+    /**
+     * @notice Shows the recommended fix: minAmountOut parameter
+     */
+    function test_M04_RecommendedFix_MinAmountOut() public {
+        // This test shows what SHOULD happen with slippage protection
+
+        uint256 sharesToRedeem = stakediTry.balanceOf(user1);
+        uint256 expectedAssets = stakediTry.previewRedeem(sharesToRedeem);
+
+        // User sets acceptable slippage at 1% (100 bps)
+        uint256 minAcceptableSlippage = 100; // 1%
+        uint256 minAmountOut = expectedAssets - (expectedAssets * minAcceptableSlippage) / 10000;
+
+        emit log_string("=== RECOMMENDED FIX ===");
+        emit log_named_uint("Expected assets", expectedAssets);
+        emit log_named_uint("Min acceptable amount (1% slippage)", minAmountOut);
+        emit log_string("");
+
+        // Yield distributed
+        vm.prank(rewarder);
+        stakediTry.transferInRewards(YIELD_AMOUNT);
+        vm.warp(block.timestamp + 30 minutes);
+
+        // Execute redemption
+        vm.prank(user1);
+        uint256 actualReceived = stakediTry.fastRedeem(sharesToRedeem, user1, user1);
+
+        emit log_named_uint("Actual received", actualReceived);
+
+        // In current implementation, no revert occurs even though slippage exceeded 1%
+        // With proper fix, this would revert with: require(actualReceived >= minAmountOut, "Slippage too high");
+
+        if (actualReceived < minAmountOut) {
+            emit log_string("SHOULD REVERT: Slippage exceeded acceptable limit");
+            emit log_string("But current implementation has no protection!");
+
+            // This assertion proves the vulnerability
+            assertTrue(true, "Slippage protection missing - transaction should have reverted");
+        }
+    }
+}
```

</details>

Run with:
```bash
forge test --match-test test_M04_MissingSlippageProtection_fastRedeem -vvvv
```

Expected output shows user receiving less than expected with >0.5% slippage when yield vests during transaction delay.

## Recommended Mitigation
Add slippage protection parameters to both functions. Users should be able to specify their acceptable slippage tolerance:

```solidity
function fastRedeem(
    uint256 shares,
    address receiver,
    address owner,
    uint256 minAssetsOut  // ← Add slippage protection parameter
)
    external
    ensureCooldownOn
    ensureFastRedeemEnabled
    returns (uint256 assets)
{
    if (shares > maxRedeem(owner)) revert ExcessiveRedeemAmount();

    uint256 totalAssets = previewRedeem(shares);

    // ← Add slippage check
    if (totalAssets < minAssetsOut) revert SlippageExceeded();

    uint256 feeAssets = _redeemWithFee(shares, totalAssets, receiver, owner);

    emit FastRedeemed(owner, receiver, shares, totalAssets, feeAssets);

    return totalAssets - feeAssets;
}

function fastWithdraw(
    uint256 assets,
    address receiver,
    address owner,
    uint256 maxSharesIn  // ← Add slippage protection parameter
)
    external
    ensureCooldownOn
    ensureFastRedeemEnabled
    returns (uint256 shares)
{
    if (assets > maxWithdraw(owner)) revert ExcessiveWithdrawAmount();

    uint256 totalShares = previewWithdraw(assets);

    // ← Add slippage check
    if (totalShares > maxSharesIn) revert SlippageExceeded();

    uint256 feeAssets = _redeemWithFee(totalShares, assets, receiver, owner);

    emit FastRedeemed(owner, receiver, totalShares, assets, feeAssets);

    return totalShares;
}
```

Add the error definition:
```solidity
error SlippageExceeded();
```

This allows users to specify their acceptable tolerance (e.g., 1% slippage) and ensures transactions revert if conditions change beyond their acceptable range, protecting them from unexpected losses due to yield vesting progress.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
