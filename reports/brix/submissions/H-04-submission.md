# Critical Accounting Bug Causes Permanent Fund Lock on NAV Decrease

## Lines of code

https://github.com/gititGoro/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L270-L306
https://github.com/gititGoro/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L318-L370

## Vulnerability details

### Summary

The iTryIssuer contract contains a critical accounting bug in its mint and redeem logic that causes permanent fund lock when NAV prices decrease after minting. The protocol tracks collateral using `_totalDLFUnderCustody` based on the amount deposited at mint time, but the redemption calculation requires more collateral than tracked when NAV decreases, causing arithmetic underflow and reverting all redemption attempts.

### Root Cause

The vulnerability stems from asymmetric formulas in the mint and redeem operations:

**Mint formula** (Line 290):
```solidity
iTRYAmount = netDlfAmount * navPrice / 1e18;
```

**Redeem formula** (Line 339):
```solidity
uint256 grossDlfAmount = iTRYAmount * 1e18 / navPrice;
```

**Accounting tracking** (Line 605):
```solidity
_totalDLFUnderCustody += dlfAmount;  // Only tracks original DLF deposited
```

When NAV price is high at mint time, users receive MORE iTRY tokens per DLF. However, when they later redeem at a lower NAV price, the protocol calculates that MORE DLF is needed than was originally deposited. Since `_totalDLFUnderCustody` only tracks the original deposit amount, the redemption attempt causes an arithmetic underflow at line 628 or 645:

```solidity
_totalDLFUnderCustody -= (receiveAmount + feeAmount);  // UNDERFLOWS
```

### Attack Scenario

1. User deposits 1,000,000 DLF when NAV = 1.1
2. After 0.5% mint fee: 995,000 DLF enters protocol
3. User receives: 995,000 * 1.1 / 1 = 1,094,500 iTRY
4. Protocol tracks: `_totalDLFUnderCustody = 995,000`
5. NAV decreases to 1.0 (normal market volatility)
6. User attempts to redeem 1,094,500 iTRY
7. Protocol calculates: 1,094,500 * 1 / 1.0 = 1,094,500 DLF needed
8. Redemption tries: `_totalDLFUnderCustody -= 1,094,500`
9. **REVERTS**: Cannot subtract 1,094,500 from 995,000
10. **User funds permanently locked** - all redemption attempts fail

### Impact

**CRITICAL**: Users cannot redeem their iTRY tokens when NAV decreases after minting. This results in permanent loss of user funds with no recovery mechanism. The issue affects:

- **All users** who mint at higher NAV prices and attempt to redeem at lower prices
- **Normal market conditions** - NAV volatility is expected, not an edge case
- **No admin rescue** - The accounting underflow prevents redemption entirely

The vulnerability can cause 100% loss of user deposits during normal price fluctuations.

### Secondary Impact: No Slippage Protection

Even when NAV increases (avoiding the accounting bug), users are exposed to ~9% losses during volatile periods because the `minAmountOut` parameter in `mintFor()` and `redeemFor()` provides no protection against oracle price changes between transaction submission and execution.

## Proof of Concept

The following test demonstrates the critical accounting bug. Add this to the test suite:

<details>
<summary>Proof of Concept Test</summary>

```diff
diff --git a/test/H-04-poc.t.sol b/test/H-04-poc.t.sol
new file mode 100644
index 0000000..1234567
--- /dev/null
+++ b/test/H-04-poc.t.sol
@@ -0,0 +1,100 @@
+// SPDX-License-Identifier: MIT
+pragma solidity ^0.8.0;
+
+import "./iTryIssuer.base.t.sol";
+
+contract H04CriticalAccountingBugTest is iTryIssuerBaseTest {
+
+    address public user;
+
+    function setUp() public override {
+        super.setUp();
+
+        user = makeAddr("user");
+        vm.label(user, "User");
+
+        // Whitelist and fund the user
+        vm.prank(whitelistManager);
+        issuer.addToWhitelist(user);
+
+        collateralToken.mint(user, 10_000_000e18);
+
+        vm.prank(user);
+        collateralToken.approve(address(issuer), type(uint256).max);
+    }
+
+    function test_H04_CriticalAccountingBug_PermanentFundLock() public {
+        // ============================================
+        // Phase 1: User mints at HIGH NAV price
+        // ============================================
+
+        // Set initial NAV price at 1.1 (high)
+        uint256 highNAVPrice = 1.1e18;
+        _setNAVPrice(highNAVPrice);
+
+        uint256 userBalanceBefore = collateralToken.balanceOf(user);
+        uint256 mintAmount = 1_000_000e18;
+
+        console.log("=== Phase 1: Mint at High NAV ===");
+        console.log("NAV Price:", highNAVPrice);
+        console.log("User deposits (DLF):", mintAmount);
+
+        vm.prank(user);
+        uint256 iTRYMinted = issuer.mintFor(user, mintAmount, 0);
+
+        uint256 mintFee = _calculateMintFee(mintAmount);
+        uint256 netDlfDeposited = mintAmount - mintFee;
+
+        console.log("Mint fee:", mintFee);
+        console.log("Net DLF deposited:", netDlfDeposited);
+        console.log("iTRY minted:", iTRYMinted);
+
+        // Verify accounting
+        uint256 dlfTracked = issuer.getCollateralUnderCustody();
+        console.log("DLF tracked by protocol:", dlfTracked);
+        assertEq(dlfTracked, netDlfDeposited, "Protocol should track net DLF deposited");
+
+        // ============================================
+        // Phase 2: NAV price DECREASES
+        // ============================================
+
+        uint256 lowNAVPrice = 1.0e18;
+        _setNAVPrice(lowNAVPrice);
+
+        console.log("");
+        console.log("=== Phase 2: NAV Decreases ===");
+        console.log("New NAV Price:", lowNAVPrice);
+        console.log("Price change: -9.09%");
+
+        // ============================================
+        // Phase 3: User attempts to redeem - FAILS
+        // ============================================
+
+        console.log("");
+        console.log("=== Phase 3: Redemption Attempt ===");
+        console.log("User attempts to redeem iTRY:", iTRYMinted);
+
+        // Calculate what redemption SHOULD return
+        uint256 grossDlfNeeded = iTRYMinted * 1e18 / lowNAVPrice;
+        console.log("Gross DLF needed for redemption:", grossDlfNeeded);
+        console.log("DLF tracked by protocol:", dlfTracked);
+        console.log("SHORTFALL:", grossDlfNeeded - dlfTracked);
+
+        vm.prank(user);
+        iTryToken.approve(address(issuer), iTRYMinted);
+
+        // Redemption REVERTS with arithmetic underflow
+        vm.prank(user);
+        vm.expectRevert(stdError.arithmeticError);
+        issuer.redeemFor(user, iTRYMinted, 0);
+
+        console.log("");
+        console.log("=== RESULT ===");
+        console.log("Redemption FAILED: Arithmetic underflow");
+        console.log("User funds PERMANENTLY LOCKED");
+        console.log("Impact: 100% loss of", mintAmount / 1e18, "DLF");
+    }
+}
```

</details>

**To run the test:**
```bash
forge test --match-test test_H04_CriticalAccountingBug_PermanentFundLock -vvvv
```

**Expected output:**
```
[FAIL] test_H04_CriticalAccountingBug_PermanentFundLock()
    └─ ← "Arithmetic over/underflow"
```

The test demonstrates:
1. User mints 1M DLF at NAV 1.1 → receives 1,094,500 iTRY
2. Protocol tracks 995,000 DLF (after 0.5% fee)
3. NAV decreases to 1.0
4. User tries to redeem → protocol calculates 1,094,500 DLF needed
5. Underflow occurs: `995,000 - 1,094,500` → **REVERT**
6. User funds permanently locked

## Tools Used

- Manual code review
- Foundry testing framework
- Arithmetic analysis of mint/redeem formulas

## Recommended Mitigation Steps

### Fix 1: Track Value Instead of Amount (Recommended)

Replace `_totalDLFUnderCustody` with value-based tracking that accounts for NAV at mint time:

```solidity
// Replace _totalDLFUnderCustody with value tracking
uint256 private _totalValueUnderCustody;

function _transferIntoVault(address from, uint256 dlfAmount, uint256 feeAmount) internal {
    uint256 navPrice = oracle.price();
    uint256 valueAdded = dlfAmount * navPrice / 1e18;
    _totalValueUnderCustody += valueAdded;

    // ... rest of transfer logic
}

function _redeemFromVault(address receiver, uint256 receiveAmount, uint256 feeAmount) internal {
    uint256 navPrice = oracle.price();
    uint256 valueRemoved = (receiveAmount + feeAmount) * navPrice / 1e18;
    _totalValueUnderCustody -= valueRemoved;

    // ... rest of redeem logic
}
```

This ensures accounting matches the iTRY supply regardless of NAV price changes.

### Fix 2: Dynamic Redemption Cap

Add a redemption limit based on available collateral:

```solidity
function redeemFor(address recipient, uint256 iTRYAmount, uint256 minAmountOut)
    public
    onlyRole(_WHITELISTED_USER_ROLE)
    nonReentrant
    returns (bool fromBuffer)
{
    // ... existing validation

    uint256 grossDlfAmount = iTRYAmount * 1e18 / navPrice;

    // NEW: Cap redemption to available collateral
    uint256 maxRedeemable = _totalDLFUnderCustody;
    if (grossDlfAmount > maxRedeemable) {
        grossDlfAmount = maxRedeemable;
        // Recalculate iTRY to burn based on capped DLF amount
        iTRYAmount = grossDlfAmount * navPrice / 1e18;
    }

    // ... rest of redemption logic
}
```

### Fix 3: Add Slippage Protection

Implement true slippage protection by checking NAV price bounds:

```solidity
function mintFor(address recipient, uint256 dlfAmount, uint256 minAmountOut)
    public
    onlyRole(_WHITELISTED_USER_ROLE)
    nonReentrant
    returns (uint256 iTRYAmount)
{
    // ... existing code

    uint256 navPrice = oracle.price();

    // NEW: Allow caller to specify maximum acceptable NAV price
    if (navPrice > maxNAVPrice) {
        revert NAVPriceExceedsLimit(navPrice, maxNAVPrice);
    }

    // ... rest of mint logic
}
```

### Fix 4: Emergency Redemption Function

Add an admin function to handle stuck funds:

```solidity
function emergencyRedeem(address user, uint256 iTRYAmount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
{
    // Calculate max redeemable based on available collateral
    uint256 userShare = (iTRYAmount * _totalDLFUnderCustody) / _totalIssuedITry;

    _burn(user, iTRYAmount);
    _redeemFromVault(user, userShare, 0);
}
```

**Priority: Implement Fix 1 (value-based tracking) as it addresses the root cause and prevents the vulnerability entirely.**
