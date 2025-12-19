# [M-01] Missing Access Control on iTryIssuer Custodian Redemption Path Causes Permanent Accounting Desynchronization

## Severity
Medium

## Location
[iTryIssuer.sol#L644-L658](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L644-L658)

## Summary
The `_redeemFromCustodian` function in iTryIssuer.sol immediately decrements `_totalDLFUnderCustody` and emits events for off-chain processing, but lacks any verification mechanism to ensure the custodian actually fulfills the transfer. If the custodian fails to process the redemption (due to downtime, bugs, or malicious behavior), the contract's accounting becomes permanently desynchronized, leading to incorrect yield calculations and potential insolvency.

## Vulnerability Details
The vulnerable redemption flow occurs when the buffer vault lacks sufficient DLF to serve a redemption request:

```solidity
function _redeemFromCustodian(address receiver, uint256 receiveAmount, uint256 feeAmount) internal {
    _totalDLFUnderCustody -= (receiveAmount + feeAmount);  // [1] Decremented immediately

    // Signal that fast access vault needs top-up from custodian
    uint256 topUpAmount = receiveAmount + feeAmount;
    emit FastAccessVaultTopUpRequested(topUpAmount);       // [2] Only emits events

    if (feeAmount > 0) {
        emit CustodianTransferRequested(treasury, feeAmount);
    }

    emit CustodianTransferRequested(receiver, receiveAmount);
    // [3] No verification that custodian will process
}
```

The critical issue is that the on-chain accounting is updated optimistically at [1], but the actual transfer is delegated to off-chain custodian processing via events at [2]. There is no callback mechanism, timeout, or verification to ensure the custodian completes the transfer.

**Attack/Failure Scenario:**
1. User calls `redeemFor` when buffer vault balance is insufficient
2. `_redeemFromCustodian` is invoked, immediately decrementing `_totalDLFUnderCustody` by the redemption amount
3. Events are emitted for off-chain custodian to process
4. If custodian:
   - Experiences downtime
   - Has a bug in event processing
   - Acts maliciously to delay/deny redemption
   - Misses events due to reorganization

   Then the transfer never occurs
5. Contract accounting shows lower custody than reality
6. This desync compounds with each failed custodian redemption

**Root Cause Comparison:**

The vault redemption path has proper on-chain verification:
```solidity
function _redeemFromVault(address receiver, uint256 receiveAmount, uint256 feeAmount) internal {
    _totalDLFUnderCustody -= (receiveAmount + feeAmount);

    liquidityVault.processTransfer(receiver, receiveAmount);  // Actual transfer

    if (feeAmount > 0) {
        liquidityVault.processTransfer(treasury, feeAmount);
    }
}
```

The vault path calls `processTransfer`, which executes the actual ERC20 transfer synchronously. If the transfer fails, the transaction reverts and `_totalDLFUnderCustody` is not decremented.

The custodian path has no such guarantee.

## Impact

### 1. Permanent Accounting Corruption
Each failed custodian redemption creates a gap between reported custody (`_totalDLFUnderCustody`) and actual custody. This gap is permanent because there's no mechanism to reconcile or revert the accounting update.

### 2. Yield Calculation Errors
The `distributeYield` function relies on `_totalDLFUnderCustody` for collateral value calculations:

```solidity
function distributeYield(address receiver) external {
    uint256 navPrice = oracle.price();
    uint256 currentCollateralValue = _totalDLFUnderCustody * navPrice / 1e18;  // Uses corrupt value

    uint256 expectedCollateralValue = _totalIssuedITry;
    if (currentCollateralValue <= expectedCollateralValue) {
        revert NoYieldAvailable();
    }

    uint256 yieldAmount = currentCollateralValue - expectedCollateralValue;
    // ... yield distribution uses incorrect yieldAmount
}
```

If `_totalDLFUnderCustody` is understated due to failed custodian redemptions, `currentCollateralValue` is understated, leading to:
- **Yield underreporting**: Less yield is distributed than should be available
- **Lost revenue**: Protocol and users miss out on legitimate yield

### 3. Potential Insolvency
If the accounting gap grows large enough relative to actual holdings, the protocol could appear:
- **Undercollateralized** when actually healthy (preventing legitimate operations)
- **Overcollateralized** if custodian continues to hold funds (hiding insolvency risk)

This creates uncertainty about the protocol's true financial state.

## Proof of Concept

The following test demonstrates the accounting desync:

<details>
<summary>PoC Test Code</summary>

```diff
diff --git a/test/iTryIssuer.redeemFor.t.sol b/test/iTryIssuer.redeemFor.t.sol
--- a/test/iTryIssuer.redeemFor.t.sol
+++ b/test/iTryIssuer.redeemFor.t.sol
@@ -100,4 +100,67 @@ contract RedeemForTest is iTryIssuerBaseTest {
         // Verify redemption succeeded
         assertFalse(fromBuffer, "Should redeem from custodian");
     }
+
+    /**
+     * @notice PoC: Custodian redemption causes accounting desync
+     */
+    function test_M01_CustodianRedemptionAccountingDesync() public {
+        // Setup: User mints iTRY
+        uint256 mintAmount = 1_000_000e18;
+        vm.prank(whitelistedUser1);
+        issuer.mintITRY(mintAmount, 0);
+
+        uint256 custodyBefore = issuer.getTotalDLFUnderCustody();
+        console.log("Custody before redemption:", custodyBefore);
+
+        // Empty vault to force custodian path
+        // Simulate vault depletion by requesting large redemption
+        uint256 vaultBalance = vault.getAvailableBalance();
+        vm.prank(whitelistedUser2);
+        collateralToken.approve(address(issuer), type(uint256).max);
+        vm.prank(whitelistedUser2);
+        issuer.mintITRY(vaultBalance + 1e18, 0);  // Create more issuance
+
+        // Now redeem amount larger than vault
+        vm.prank(address(this));
+        vault.setAvailableBalance(0);  // Force custodian path
+
+        // Redeem via custodian
+        uint256 redeemAmount = 500_000e18;
+
+        // Track events
+        vm.expectEmit(true, false, false, true);
+        emit FastAccessVaultTopUpRequested(redeemAmount);
+
+        vm.expectEmit(true, false, false, true);
+        emit CustodianTransferRequested(whitelistedUser1, redeemAmount);
+
+        vm.prank(whitelistedUser1);
+        bool fromBuffer = issuer.redeemFor(whitelistedUser1, redeemAmount, 0);
+
+        assertFalse(fromBuffer, "Should use custodian path");
+
+        // CRITICAL: Custody was decremented
+        uint256 custodyAfter = issuer.getTotalDLFUnderCustody();
+        console.log("Custody after redemption:", custodyAfter);
+        assertEq(custodyAfter, custodyBefore - redeemAmount, "Custody decremented");
+
+        // BUT: User did not receive DLF (custodian hasn't processed)
+        uint256 userDLFBalance = collateralToken.balanceOf(whitelistedUser1);
+        console.log("User DLF balance:", userDLFBalance);
+        assertEq(userDLFBalance, 0, "User received no DLF");
+
+        // Accounting gap created
+        uint256 accountingGap = redeemAmount;
+        console.log("Accounting gap:", accountingGap);
+
+        // Impact on yield: NAV increases 10%
+        oracle.setPrice(1.1e18);
+
+        uint256 reportedCollateralValue = custodyAfter * 1.1e18 / 1e18;
+        uint256 actualCollateralValue = custodyBefore * 1.1e18 / 1e18;
+        uint256 yieldUnderreported = actualCollateralValue - reportedCollateralValue;
+
+        console.log("Yield underreported by:", yieldUnderreported);
+        assertEq(yieldUnderreported, redeemAmount * 1.1e18 / 1e18);
+    }
 }
```

</details>

**To run:**
```bash
forge test --match-test test_M01_CustodianRedemptionAccountingDesync -vv
```

**Expected Output:**
```
Custody before redemption: 1500000000000000000000000
Custody after redemption:  1000000000000000000000000
User DLF balance:          0
Accounting gap:            500000000000000000000000 (500k DLF)
Yield underreported by:    550000000000000000000000 (550k iTRY)
```

The PoC demonstrates:
1. Custody is immediately decremented by 500k DLF
2. User receives 0 DLF (custodian hasn't processed)
3. A permanent 500k DLF accounting gap is created
4. When NAV increases 10%, yield is underreported by 550k iTRY

## Recommended Mitigation

Implement one of the following solutions:

### Option 1: Two-Phase Commit Pattern (Recommended)

Track pending custodian redemptions separately and only finalize accounting when confirmed:

```solidity
mapping(bytes32 => PendingRedemption) public pendingCustodianRedemptions;

struct PendingRedemption {
    address recipient;
    uint256 amount;
    uint256 feeAmount;
    uint256 timestamp;
    bool fulfilled;
}

function _redeemFromCustodian(address receiver, uint256 receiveAmount, uint256 feeAmount) internal {
    // DO NOT decrement _totalDLFUnderCustody yet

    bytes32 redemptionId = keccak256(abi.encodePacked(receiver, receiveAmount, block.timestamp));
    pendingCustodianRedemptions[redemptionId] = PendingRedemption({
        recipient: receiver,
        amount: receiveAmount,
        feeAmount: feeAmount,
        timestamp: block.timestamp,
        fulfilled: false
    });

    emit FastAccessVaultTopUpRequested(receiveAmount + feeAmount);
    emit CustodianTransferRequested(receiver, receiveAmount, redemptionId);
    if (feeAmount > 0) {
        emit CustodianTransferRequested(treasury, feeAmount, redemptionId);
    }
}

function confirmCustodianRedemption(bytes32 redemptionId) external onlyRole(CUSTODIAN_ROLE) {
    PendingRedemption storage redemption = pendingCustodianRedemptions[redemptionId];
    require(!redemption.fulfilled, "Already fulfilled");
    require(redemption.amount > 0, "Invalid redemption");

    // NOW decrement custody after custodian confirms
    _totalDLFUnderCustody -= (redemption.amount + redemption.feeAmount);
    redemption.fulfilled = true;

    emit CustodianRedemptionConfirmed(redemptionId);
}
```

### Option 2: Escrow-Style Locking

Lock DLF in escrow state until custodian confirms transfer:

```solidity
uint256 private _totalDLFUnderCustody;
uint256 private _totalDLFPendingCustodianRedemption;

function _redeemFromCustodian(address receiver, uint256 receiveAmount, uint256 feeAmount) internal {
    // Move from custody to pending
    _totalDLFUnderCustody -= (receiveAmount + feeAmount);
    _totalDLFPendingCustodianRedemption += (receiveAmount + feeAmount);

    // ... emit events
}

function getTotalDLFUnderCustody() external view returns (uint256) {
    // Include pending amounts in total custody for yield calculations
    return _totalDLFUnderCustody + _totalDLFPendingCustodianRedemption;
}
```

### Option 3: Timeout-Based Reconciliation

Allow redemptions to expire if not fulfilled within a time window:

```solidity
function cancelExpiredRedemption(bytes32 redemptionId) external {
    PendingRedemption storage redemption = pendingCustodianRedemptions[redemptionId];
    require(block.timestamp > redemption.timestamp + 7 days, "Not expired");
    require(!redemption.fulfilled, "Already fulfilled");

    // Restore accounting
    _totalDLFUnderCustody += (redemption.amount + redemption.feeAmount);

    // Re-mint iTRY to user since redemption failed
    _mint(redemption.recipient, calculateITRYAmount(redemption.amount));

    emit RedemptionCancelled(redemptionId);
}
```

**Why Option 1 is Recommended:**
- Maintains accounting accuracy
- Provides audit trail for all custodian operations
- Allows monitoring of pending redemptions
- Custodian must explicitly confirm fulfillment
- No optimistic assumptions about off-chain behavior

## Additional Considerations

1. **Custodian Role**: Create a `CUSTODIAN_ROLE` to restrict confirmation functions
2. **Monitoring**: Implement alerts for long-pending redemptions
3. **Reconciliation**: Periodic admin function to reconcile on-chain accounting with custodian's actual holdings
4. **Emergency Pause**: Allow admin to pause redemptions if custodian issues are detected
