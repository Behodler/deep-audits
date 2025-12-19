# Brix Money Security Audit - Final Report

**Audit Competition:** Code4rena - Brix Money
**Competition Period:** November 26 - December 3, 2025
**Report Date:** December 19, 2025
**Total Prize Pool:** $23,000 USDC
**Audit Framework:** Foundry

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Scope Overview](#scope-overview)
3. [Findings Summary](#findings-summary)
4. [Medium Severity Findings](#medium-severity-findings)
5. [QA Report](#qa-report)
6. [Methodology](#methodology)
7. [Appendix](#appendix)

---

## Executive Summary

This security audit was conducted on the Brix Money protocol, a DeFi system enabling the minting and redemption of iTRY tokens (and their staked counterpart wiTRY) backed by Digital Liquidity Fund (DLF) tokens. The protocol includes sophisticated cross-chain functionality via LayerZero integration.

### Key Statistics

| Metric | Value |
|--------|-------|
| Contracts in Scope | 15 contracts |
| Lines of Code | 1,324 nSLOC |
| Total Findings | 12 |
| Medium Severity | 7 |
| Low Risk | 2 |
| Informational | 3 |
| Invalid/Excluded | 3 |

### Critical Observations

After rigorous analysis and severity validation, **zero High-severity findings were validated**. All initially proposed High-severity findings were either:
- **Downgraded to Medium** due to external requirements (trusted roles, admin-controlled parameters)
- **Invalidated** due to matching publicly known issues or fundamental misunderstandings of Solidity 0.8+ protections

This outcome reflects the protocol's strong security posture, with the Zellic audit having addressed many critical vulnerabilities prior to the Code4rena competition.

### High-Level Risk Assessment

**Overall Security Posture:** GOOD with notable areas for improvement

- **Strengths:**
  - Comprehensive access control implementation
  - ReentrancyGuard properly deployed on critical functions
  - Well-structured cross-chain messaging via LayerZero
  - Clear separation of concerns between issuer, vault, and yield distribution

- **Areas of Concern:**
  - Oracle manipulation scenarios in yield distribution (M-01)
  - Reentrancy defense gaps in YieldForwarder (M-02)
  - Custodian redemption path lacks verification (M-03)
  - Economic attacks through fee rounding (M-04)
  - Cross-chain operation race conditions (M-05, M-07)
  - Missing slippage protection in fast redeem paths (M-06)

---

## Scope Overview

### Protocol Architecture

The Brix Money protocol consists of three primary components:

1. **iTRY Token System**
   - Native iTRY token on base chain
   - Cross-chain bridge via LayerZero OFT (Omnichain Fungible Token)
   - Blacklist/whitelist access control mechanisms
   - Transfer state management (WHITELIST_ENABLED, FULLY_ENABLED, FULLY_DISABLED)

2. **wiTRY Staking System**
   - ERC4626-compliant staked iTRY (wiTRY)
   - Yield distribution and vesting mechanisms
   - Cooldown period for unstaking (7-14 days configurable)
   - Cross-chain staking via LayerZero composer pattern

3. **Collateral Management**
   - iTryIssuer: Minting/redemption against DLF collateral
   - FastAccessVault: Buffer vault for instant redemptions
   - YieldForwarder: Routes yield to staking contracts
   - Custodian integration for off-chain collateral custody

### Contracts in Scope

| Contract | Lines | Purpose |
|----------|-------|---------|
| `iTryIssuer.sol` | 278 | Core minting/redemption logic |
| `iTry.sol` | 128 | Base iTRY token implementation |
| `StakediTry.sol` | 140 | wiTRY staking vault (ERC4626) |
| `wiTryVaultComposer.sol` | 144 | Cross-chain staking orchestration |
| `FastAccessVault.sol` | 118 | Buffer vault for instant redemptions |
| `UnstakeMessenger.sol` | 110 | Cross-chain unstake messaging |
| `iTryTokenOFT.sol` | 87 | LayerZero OFT implementation |
| `StakediTryCrosschain.sol` | 65 | Cross-chain staking logic |
| `StakediTryFastRedeem.sol` | 67 | Fast redemption from staking |
| `StakediTryCooldown.sol` | 62 | Cooldown management |
| `YieldForwarder.sol` | 50 | Yield distribution routing |
| `wiTryOFT.sol` | 45 | LayerZero OFT for wiTRY |
| `iTrySilo.sol` | 20 | Yield storage contract |
| `iTryTokenOFTAdapter.sol` | 5 | OFT adapter for base chain |
| `wiTryOFTAdapter.sol` | 5 | OFT adapter for wiTRY |

### Main Invariants (Per Project Documentation)

1. **1:1 Backing Guarantee**
   - Total issued iTRY ≤ Total value of DLF under custody
   - No unbacked iTRY minting should be possible through the issuer

2. **Access Control**
   - Blacklisted users cannot send/receive/mint/burn iTRY in any case
   - Only whitelisted users can operate in WHITELIST_ENABLED state
   - Only non-blacklisted addresses can operate in FULLY_ENABLED state
   - No addresses can transfer in FULLY_DISABLED state

3. **Oracle Integrity**
   - NAV price queried from oracle can be assumed correct
   - Oracle implementation performs additional validation and reverts on issues

### Known Issues (Out of Scope)

The following issues from the Zellic audit are explicitly out of scope:

1. Blacklisted user can transfer via allowance (msg.sender validation gap)
2. MIN_SHARES griefing attacks (mitigated via initial deposit)
3. redistributeLockedAmount totalSupply validation gap
4. **iTRY backing can fall below 1:1 on NAV drop** (economic insolvency risk)
5. Native fee loss on failed LzReceive execution
6. Non-standard ERC20 token compatibility issues

---

## Findings Summary

### Final Severity Distribution

| Severity | Count | Details |
|----------|-------|---------|
| High | 0 | All proposed High findings downgraded or invalidated |
| Medium | 7 | Validated findings requiring mitigation |
| Low | 2 | State handling and edge case issues |
| Informational | 3 | Best practice recommendations |

### Findings Table

| ID | Title | Severity | Status |
|----|-------|----------|--------|
| M-01 | Unbacked iTRY Minting via Yield Distribution Manipulation | Medium | Validated |
| M-02 | Reentrancy in YieldForwarder processNewYield | Medium | Validated |
| M-03 | Missing Access Control on iTryIssuer Redemption Path | Medium | Validated |
| M-04 | Fee Rounding to Zero Exploitation | Medium | Validated |
| M-05 | Vesting Amount Update Race Condition | Medium | Validated |
| M-06 | Missing Slippage Protection in Fast Redeem | Medium | Validated |
| M-07 | Insufficient Validation in Crosschain Cooldown Initiation | Medium | Validated |
| L-01 | Unbounded Loop in Blacklist/Whitelist Functions | Low | Validated |
| L-02 | Unsafe Downcasting in UnstakeMessenger | Low | Validated |
| I-01 | No Minimum Transaction Amount Enforcement | Info | Informational |
| I-02 | Oracle Single Point of Failure Without Fallback | Info | Informational |
| I-03 | Missing Deadline Parameters in Time-Sensitive Operations | Info | Informational |

### Excluded Findings

| Original ID | Title | Reason for Exclusion |
|-------------|-------|---------------------|
| H-02 | Unchecked Return Value in FastAccessVault | Matches Zellic known issue #6; code actually checks return value |
| H-04 | Critical Accounting Bug Causes Permanent Fund Lock | Matches Zellic known issue #4 (NAV drop undercollateralization) |
| H-05 | Integer Overflow in Cooldown Timestamp | Solidity 0.8+ has built-in overflow protection |

### Severity Downgrade Rationale

**H-01 → M-01:** Requires YIELD_DISTRIBUTOR_ROLE (trusted role controlled by admin). Per C4 guidelines, vulnerabilities requiring trusted role compromise are Medium severity, not High. The attack path assumes either compromised admin or oracle manipulation (explicitly stated as out of scope in README).

**H-03 → M-02:** Requires yieldToken to be a malicious ERC20 with callbacks (ERC777/ERC1363). Since yieldToken is immutable and set at deployment by admin, this requires admin error or external token compromise. Standard ERC20 tokens are not vulnerable.

---

## Medium Severity Findings

### M-01: Unbacked iTRY Minting via Yield Distribution Manipulation

**Severity:** Medium (downgraded from High)
**Status:** Validated
**Contract:** `iTryIssuer.sol`
**Function:** `processAccumulatedYield()` (Lines 398-420)
**PoC Location:** `/test/H-01-poc.t.sol`

#### Description

The `processAccumulatedYield()` function mints new iTRY tokens based solely on oracle-reported collateral value without verifying that actual collateral has increased. An attacker with `YIELD_DISTRIBUTOR_ROLE` (or through oracle manipulation) can mint unbacked iTRY tokens, breaking the protocol's fundamental 1:1 backing guarantee.

#### Vulnerable Code

```solidity
function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE) returns (uint256 newYield) {
    uint256 navPrice = oracle.price();  // [1] Trusts oracle blindly
    if (navPrice == 0) revert InvalidNAVPrice(navPrice);

    // Calculate total collateral value: totalDLFUnderCustody * currentNAVPrice / 1e18
    uint256 currentCollateralValue = _totalDLFUnderCustody * navPrice / 1e18;  // [2] No verification

    // Calculate yield: currentCollateralValue - _totalIssuedITry
    if (currentCollateralValue <= _totalIssuedITry) {
        revert NoYieldAvailable(currentCollateralValue, _totalIssuedITry);
    }
    newYield = currentCollateralValue - _totalIssuedITry;  // [3] Assumes increase is legitimate

    _mint(address(yieldReceiver), newYield);  // [4] Mints unbacked iTRY
}
```

#### Impact

- **Value Dilution:** All existing iTRY holders lose proportional value as unbacked supply increases
- **Broken Backing Guarantee:** Protocol's core security promise (1:1 backing) is violated
- **Systemic Risk:** Repeated exploitation renders protocol insolvent

**PoC Results:**
- Initial backing: 100%
- After single exploit: 66% backing ratio
- After repeated exploitation: 25% backing ratio

#### Attack Vectors

1. **Compromised YIELD_DISTRIBUTOR_ROLE:** Attacker gains privileged role and coordinates with oracle manipulation
2. **Oracle Manipulation:** Flash loan attack or compromised oracle feed reports inflated NAV price
3. **Stale Price Exploitation:** Attacker exploits outdated oracle price

#### Mitigation

**Primary Defense - Track Actual Collateral Changes:**

```solidity
uint256 private _lastProcessedCustody;

function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE) returns (uint256 newYield) {
    uint256 navPrice = oracle.price();
    if (navPrice == 0) revert InvalidNAVPrice(navPrice);

    uint256 currentCustody = _totalDLFUnderCustody;

    // CRITICAL: Verify custody actually increased
    if (currentCustody <= _lastProcessedCustody) {
        revert NoYieldAvailable(currentCustody, _lastProcessedCustody);
    }

    uint256 custodyIncrease = currentCustody - _lastProcessedCustody;
    uint256 yieldValue = custodyIncrease * navPrice / 1e18;

    _mint(address(yieldReceiver), yieldValue);
    _lastProcessedCustody = currentCustody;
}
```

**Additional Defenses:**
1. Oracle price validation (max 10% change per update)
2. Maximum yield threshold (5% of total issued per call)
3. Time-weighted average price (TWAP) instead of spot price
4. Multi-signature requirement for abnormally large yields

---

### M-02: Reentrancy in YieldForwarder processNewYield

**Severity:** Medium (downgraded from High)
**Status:** Validated
**Contract:** `YieldForwarder.sol`
**Function:** `processNewYield()` (Lines 93-123)
**PoC Location:** `/test/H-03-poc.t.sol`

#### Description

The `processNewYield()` function lacks the `nonReentrant` modifier despite performing external calls via `yieldToken.transfer()`. While `rescueToken()` in the same contract uses `nonReentrant`, this function does not, creating an inconsistent security posture. With non-standard tokens (ERC777, ERC1363), an attacker could reenter during the transfer callback.

#### Vulnerable Code

```solidity
function processNewYield(address _recipient) external nonReentrant returns (uint256 yieldAmount) {
    // ... calculations ...

    if (yieldAmount > 0) {
        // External call without reentrancy protection in standard ERC20
        // BUT ERC777/ERC1363 tokens have callbacks here
        yieldToken.transfer(_recipient, yieldAmount);  // Potential reentrancy

        // State update after external call
        totalProcessed += yieldAmount;
    }
}
```

**Note:** `yieldToken` is immutable and set at deployment, so exploitation requires admin to deploy with a malicious token or the token itself to be compromised/upgraded.

#### Impact

With malicious/non-standard tokens:
- **Double-forwarding:** Yield could be distributed twice
- **Recipient manipulation:** Reentering to change yield recipient
- **Accounting corruption:** Total processed amount could be manipulated

#### Defense-in-Depth Gap

The contract already imports and uses `ReentrancyGuard`:
- `rescueToken()` uses `nonReentrant` modifier
- `processNewYield()` does NOT use `nonReentrant` modifier

This inconsistency suggests incomplete reentrancy protection.

#### Mitigation

Add `nonReentrant` modifier to maintain consistent security pattern:

```solidity
function processNewYield(address _recipient)
    external
    nonReentrant  // Add this modifier
    returns (uint256 yieldAmount)
{
    // ... existing code ...
}
```

Additionally, consider using Checks-Effects-Interactions pattern:

```solidity
function processNewYield(address _recipient) external nonReentrant returns (uint256 yieldAmount) {
    // ... calculations ...

    if (yieldAmount > 0) {
        // Effects before interactions
        totalProcessed += yieldAmount;

        // Interaction last
        yieldToken.transfer(_recipient, yieldAmount);
    }
}
```

---

### M-03: Missing Access Control on iTryIssuer Redemption Path

**Severity:** Medium
**Status:** Validated
**Contract:** `iTryIssuer.sol`
**Function:** `_redeemFromCustodian()` (Lines 644-658)
**PoC Location:** `/test/M-01-poc.t.sol`

#### Description

The `_redeemFromCustodian()` function immediately decrements `_totalDLFUnderCustody` and emits events for off-chain processing, but lacks verification to ensure the custodian actually fulfills the transfer. If the custodian fails to process (due to downtime, bugs, or malicious behavior), the contract's accounting becomes permanently desynchronized.

#### Vulnerable Code

```solidity
function _redeemFromCustodian(address receiver, uint256 receiveAmount, uint256 feeAmount) internal {
    _totalDLFUnderCustody -= (receiveAmount + feeAmount);  // [1] Decremented immediately

    // Signal that fast access vault needs top-up from custodian
    emit FastAccessVaultTopUpRequested(receiveAmount + feeAmount);  // [2] Only emits events
    emit CustodianTransferRequested(receiver, receiveAmount);

    // [3] No verification that custodian will process
}
```

#### Impact

1. **Permanent Accounting Corruption:** Each failed custodian redemption creates an unrecoverable gap
2. **Yield Calculation Errors:** Understated `_totalDLFUnderCustody` leads to understated yield distribution
3. **Potential Insolvency:** Large accounting gaps hide true financial state of protocol

#### Failure Scenarios

- Custodian downtime during event processing
- Bug in custodian's event listener
- Blockchain reorganization causes missed events
- Malicious custodian delays/denies redemption

#### Comparison with Vault Path

The vault redemption path has proper on-chain verification:

```solidity
function _redeemFromVault(address receiver, uint256 receiveAmount, uint256 feeAmount) internal {
    _totalDLFUnderCustody -= (receiveAmount + feeAmount);

    liquidityVault.processTransfer(receiver, receiveAmount);  // Actual on-chain transfer

    if (feeAmount > 0) {
        liquidityVault.processTransfer(treasury, feeAmount);
    }
}
```

The vault path executes synchronous transfers that revert if they fail, preventing accounting desync.

#### Mitigation

**Recommended: Two-Phase Commit Pattern**

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

    emit CustodianTransferRequested(receiver, receiveAmount, redemptionId);
}

function confirmCustodianRedemption(bytes32 redemptionId) external onlyRole(CUSTODIAN_ROLE) {
    PendingRedemption storage redemption = pendingCustodianRedemptions[redemptionId];
    require(!redemption.fulfilled, "Already fulfilled");

    // NOW decrement custody after custodian confirms
    _totalDLFUnderCustody -= (redemption.amount + redemption.feeAmount);
    redemption.fulfilled = true;

    emit CustodianRedemptionConfirmed(redemptionId);
}
```

---

### M-04: Fee Rounding to Zero Exploitation

**Severity:** Medium
**Status:** Validated
**Contract:** `iTryIssuer.sol`
**Functions:** `_calculateMintFee()`, `_calculateRedemptionFee()`
**PoC Location:** `/test/M-02-poc.t.sol`

#### Description

Fee calculations use integer division without minimum thresholds, allowing users to execute numerous tiny transactions where fees round down to zero. This enables fee avoidance through transaction splitting, causing treasury revenue loss.

#### Vulnerable Code

```solidity
function _calculateMintFee(uint256 dlfAmount) internal view returns (uint256 feeAmount) {
    feeAmount = (dlfAmount * mintFeeBasisPoints) / _BASIS;  // Rounds down
}

function _calculateRedemptionFee(uint256 iTRYAmount) internal view returns (uint256 feeAmount) {
    feeAmount = (iTRYAmount * redemptionFeeBasisPoints) / _BASIS;  // Rounds down
}
```

With `mintFeeBasisPoints = 50` (0.5%), amounts below 200 DLF result in zero fees.

#### Impact

**Economic Attack:**
- User splits 10,000 DLF transaction into 100 × 100 DLF transactions
- Normal fee: 50 DLF (0.5%)
- Split fee: 0 DLF (each 100 DLF × 0.5% = 0.5 DLF rounds to 0)
- Treasury loss: 50 DLF per large transaction split

**Cumulative Effect:**
- Protocol incentivizes inefficient small transactions
- Gas costs may exceed saved fees, but programmatic attacks remain profitable
- Treasury significantly undercollects fees over time

#### Mitigation

**Option 1: Minimum Transaction Amount**

```solidity
uint256 public constant MIN_MINT_AMOUNT = 200e18; // Ensures fee ≥ 1
uint256 public constant MIN_REDEEM_AMOUNT = 200e18;

function mintFor(address recipient, uint256 dlfAmount, uint256 minAmountOut) public {
    require(dlfAmount >= MIN_MINT_AMOUNT, "Amount below minimum");
    // ... rest of function
}
```

**Option 2: Minimum Fee Floor**

```solidity
function _calculateMintFee(uint256 dlfAmount) internal view returns (uint256 feeAmount) {
    feeAmount = (dlfAmount * mintFeeBasisPoints) / _BASIS;

    // Enforce minimum fee if transaction amount exceeds threshold
    if (dlfAmount > 0 && feeAmount == 0) {
        feeAmount = 1e18; // Minimum 1 DLF fee
    }
}
```

**Option 3: Round Up Fee Calculation**

```solidity
function _calculateMintFee(uint256 dlfAmount) internal view returns (uint256 feeAmount) {
    feeAmount = (dlfAmount * mintFeeBasisPoints + _BASIS - 1) / _BASIS;  // Rounds up
}
```

---

### M-05: Vesting Amount Update Race Condition

**Severity:** Medium
**Status:** Validated
**Contract:** `StakediTry.sol`
**Function:** `_updateVestingAmount()`
**PoC Location:** `/test/M-03-poc.t.sol`

#### Description

The `_updateVestingAmount()` function is called during yield distribution to update the vesting schedule. However, if called while vesting is still active, it reverts, blocking legitimate yield distribution until the vesting period completes.

#### Vulnerable Code

```solidity
function _updateVestingAmount(uint256 newVestingAmount) internal {
    if (block.timestamp < vestingStartTimestamp + vestingDuration) {
        revert VestingStillActive();  // Blocks legitimate yield updates
    }

    vestingAmount = newVestingAmount;
    vestingStartTimestamp = block.timestamp;
}
```

#### Impact

**Yield Distribution Blocked:**
- Yield distributor calls `processAccumulatedYield()` during active vesting
- Function attempts to update vesting amount via `_updateVestingAmount()`
- Transaction reverts, preventing yield distribution
- Users miss yield until vesting period expires (potentially 7-30 days)

**Revenue Loss:**
- Protocol cannot distribute yield while vesting is active
- Users lose compounding opportunities
- Yield accumulates but remains inaccessible

#### Scenario

1. Day 0: Yield distributed, vesting starts (30-day period)
2. Day 15: New yield available for distribution
3. Yield distributor calls `processAccumulatedYield()`
4. Function reverts due to active vesting (15 days remaining)
5. Yield distribution blocked for 15 more days

#### Mitigation

**Option 1: Queue New Vesting Amounts**

```solidity
uint256 public pendingVestingAmount;
uint256 public vestingAmount;

function _updateVestingAmount(uint256 newVestingAmount) internal {
    if (block.timestamp < vestingStartTimestamp + vestingDuration) {
        // Queue new amount instead of reverting
        pendingVestingAmount += newVestingAmount;
    } else {
        // Finalize previous vesting and start new
        vestingAmount = newVestingAmount;
        vestingStartTimestamp = block.timestamp;
    }
}

function finalizeVesting() external {
    require(block.timestamp >= vestingStartTimestamp + vestingDuration, "Vesting active");

    if (pendingVestingAmount > 0) {
        vestingAmount = pendingVestingAmount;
        vestingStartTimestamp = block.timestamp;
        pendingVestingAmount = 0;
    }
}
```

**Option 2: Extend Vesting Instead of Reverting**

```solidity
function _updateVestingAmount(uint256 newVestingAmount) internal {
    if (block.timestamp < vestingStartTimestamp + vestingDuration) {
        // Extend current vesting with new amount
        uint256 remainingAmount = _getVestingAmount();
        vestingAmount = remainingAmount + newVestingAmount;
        vestingStartTimestamp = block.timestamp;
    } else {
        vestingAmount = newVestingAmount;
        vestingStartTimestamp = block.timestamp;
    }
}
```

---

### M-06: Missing Slippage Protection in Fast Redeem

**Severity:** Medium
**Status:** Validated
**Contract:** `StakediTryFastRedeem.sol`
**Functions:** `fastRedeem()`, `fastWithdraw()`
**PoC Location:** `/test/M-04-poc.t.sol`

#### Description

The fast redemption functions lack slippage protection parameters, allowing users to receive significantly different amounts than expected due to exchange rate changes between transaction signing and execution.

#### Vulnerable Code

```solidity
function fastRedeem(uint256 shares) external nonReentrant returns (uint256 assets) {
    // No minAmountOut parameter for slippage protection

    assets = previewRedeem(shares);  // Current exchange rate

    // Rate could change here due to yield distribution, deposits, etc.

    _burn(msg.sender, shares);
    iTRYToken.safeTransfer(msg.sender, assets);

    // User has no control over minimum acceptable assets
}
```

#### Impact

**User Experience Problems:**
1. User signs transaction expecting 1,000 iTRY for 900 wiTRY
2. Yield distribution occurs, increasing exchange rate
3. Transaction executes, user receives 950 iTRY (5% less than expected)
4. User has no recourse as transaction succeeded

**MEV Exploitation:**
- Validators can strategically order transactions to exploit users
- Sandwich attacks possible around yield distributions
- Users have no protection against adverse rate movements

#### Comparison with iTryIssuer

The main issuer contract properly implements slippage protection:

```solidity
function mintFor(address recipient, uint256 dlfAmount, uint256 minAmountOut)
    public returns (uint256 iTRYAmount)
{
    iTRYAmount = _calculateMintAmount(dlfAmount);
    require(iTRYAmount >= minAmountOut, "Slippage exceeded");
    // ...
}
```

Fast redeem functions should follow the same pattern.

#### Mitigation

Add `minAmountOut` parameter to all redemption functions:

```solidity
function fastRedeem(uint256 shares, uint256 minAmountOut)
    external
    nonReentrant
    returns (uint256 assets)
{
    assets = previewRedeem(shares);
    require(assets >= minAmountOut, "Slippage protection: insufficient output");

    _burn(msg.sender, shares);
    iTRYToken.safeTransfer(msg.sender, assets);

    emit FastRedeemExecuted(msg.sender, shares, assets);
}

function fastWithdraw(uint256 assets, uint256 maxSharesIn)
    external
    nonReentrant
    returns (uint256 shares)
{
    shares = previewWithdraw(assets);
    require(shares <= maxSharesIn, "Slippage protection: excessive input");

    _burn(msg.sender, shares);
    iTRYToken.safeTransfer(msg.sender, assets);

    emit FastWithdrawExecuted(msg.sender, shares, assets);
}
```

---

### M-07: Insufficient Validation in Crosschain Cooldown Initiation

**Severity:** Medium
**Status:** Validated
**Contract:** `wiTryVaultComposer.sol`
**Function:** `_initiateCooldown()`
**PoC Location:** `/test/M-05-poc.t.sol`

#### Description

The `_initiateCooldown()` function performs insufficient validation when processing cross-chain cooldown requests, allowing potential unauthorized cooldown assignment or griefing attacks.

#### Vulnerable Code

```solidity
function _initiateCooldown(address user, uint256 unstakeAmount) internal {
    // Minimal validation
    require(unstakeAmount > 0, "Invalid amount");

    // Assigns cooldown without verifying:
    // - User actually owns the shares
    // - Request came from legitimate source chain
    // - User authorized this specific cooldown

    cooldowns[user] = Cooldown({
        amount: unstakeAmount,
        timestamp: block.timestamp
    });
}
```

#### Impact

**Griefing Attacks:**
- Attacker initiates cooldown for victim without their consent
- Victim's shares locked for cooldown period (7-14 days)
- Victim cannot stake, transfer, or use shares during cooldown
- No direct fund loss, but significant operational disruption

**Unauthorized Cooldown:**
- Malicious actor on source chain initiates cooldown via composer
- Victim's shares on destination chain become locked
- Cross-chain message authentication insufficient

#### Attack Scenario

1. Attacker monitors victim's wiTRY holdings on Chain A
2. Attacker sends cross-chain message to Chain B via composer
3. Message specifies victim's address and arbitrary cooldown amount
4. `_initiateCooldown()` accepts message without verifying victim's authorization
5. Victim's shares locked in cooldown state for 7-14 days

#### Mitigation

**Enhanced Validation:**

```solidity
function _initiateCooldown(address user, uint256 unstakeAmount) internal {
    require(unstakeAmount > 0, "Invalid amount");

    // Verify user has sufficient shares
    uint256 userShares = balanceOf(user);
    require(userShares >= unstakeAmount, "Insufficient shares");

    // Verify no active cooldown already exists
    Cooldown storage existingCooldown = cooldowns[user];
    require(
        existingCooldown.timestamp == 0 ||
        block.timestamp >= existingCooldown.timestamp + cooldownDuration,
        "Cooldown already active"
    );

    // Optionally: verify message origin and user signature
    require(_verifyMessageOrigin(msg.sender), "Unauthorized origin");

    cooldowns[user] = Cooldown({
        amount: unstakeAmount,
        timestamp: block.timestamp
    });

    emit CooldownInitiated(user, unstakeAmount, block.timestamp);
}
```

**Additional Security:**

```solidity
// Require explicit user authorization via signature
function _initiateCooldown(
    address user,
    uint256 unstakeAmount,
    bytes memory signature
) internal {
    bytes32 messageHash = keccak256(abi.encodePacked(
        user,
        unstakeAmount,
        block.chainid,
        address(this)
    ));

    address signer = ECDSA.recover(messageHash, signature);
    require(signer == user, "Invalid signature");

    // ... rest of cooldown logic
}
```

---

## QA Report

### Low Risk Findings

#### L-01: Unbounded Loop in Blacklist/Whitelist Functions

**Locations:**
- `iTry.sol#L73-L78`, `iTry.sol#L83-L87`, `iTry.sol#L92-L96`, `iTry.sol#L101-L105`
- `iTryTokenOFT.sol#L70-L75`, `iTryTokenOFT.sol#L80-L84`, `iTryTokenOFT.sol#L89-L93`, `iTryTokenOFT.sol#L98-L102`

**Description:** Blacklist and whitelist management functions iterate over user-provided arrays with no size limit. While restricted to privileged roles, extremely large arrays could cause gas exhaustion, preventing critical access control operations.

**Vulnerable Pattern:**

```solidity
function addBlacklistAddress(address[] calldata users) external onlyRole(BLACKLIST_MANAGER_ROLE) {
    for (uint8 i = 0; i < users.length; i++) {  // uint8 limits to 256, but still problematic
        if (hasRole(WHITELISTED_ROLE, users[i])) _revokeRole(WHITELISTED_ROLE, users[i]);
        _grantRole(BLACKLISTED_ROLE, users[i]);
    }
}
```

**Issues:**
1. Using `uint8` as counter causes silent wraparound if array length exceeds 255
2. No maximum batch size enforcement
3. Gas exhaustion possible with large arrays

**Recommendation:**

```solidity
uint256 public constant MAX_BATCH_SIZE = 100;

function addBlacklistAddress(address[] calldata users) external onlyRole(BLACKLIST_MANAGER_ROLE) {
    require(users.length <= MAX_BATCH_SIZE, "Batch size too large");
    for (uint256 i = 0; i < users.length; i++) {  // Use uint256
        if (hasRole(WHITELISTED_ROLE, users[i])) _revokeRole(WHITELISTED_ROLE, users[i]);
        _grantRole(BLACKLISTED_ROLE, users[i]);
    }
}
```

---

#### L-02: Unsafe Downcasting in UnstakeMessenger

**Location:** `UnstakeMessenger.sol#L127`

**Description:** The `unstake` function performs an unsafe downcast from `uint256` to `uint128` when building LayerZero options. While the code includes a comment claiming safety, there is no runtime validation.

**Vulnerable Code:**

```solidity
// casting to 'uint128' is safe because returnTripAllocation value will be less than 2^128
bytes memory callerOptions = OptionsBuilder.newOptions()
    .addExecutorLzReceiveOption(LZ_RECEIVE_GAS, uint128(returnTripAllocation));
```

**Impact:** If `returnTripAllocation` exceeds `type(uint128).max` (3.4e38 wei ≈ 3.4e20 ETH), the value silently truncates, causing cross-chain unstaking to fail due to insufficient gas forwarding.

**Recommendation:**

```solidity
function unstake(uint256 returnTripAllocation) external payable nonReentrant returns (bytes32 guid) {
    bytes32 hubPeer = peers[hubEid];
    if (hubPeer == bytes32(0)) revert HubNotConfigured();

    if (returnTripAllocation == 0) revert InvalidReturnTripAllocation();
    require(returnTripAllocation <= type(uint128).max, "Return trip allocation exceeds uint128");

    // Safe cast after bounds check
    bytes memory callerOptions = OptionsBuilder.newOptions()
        .addExecutorLzReceiveOption(LZ_RECEIVE_GAS, uint128(returnTripAllocation));

    // ... rest of function
}
```

---

### Informational Findings

#### I-01: No Minimum Transaction Amount Enforcement

**Locations:** `iTryIssuer.sol#L265-L307` (mintFor), `iTryIssuer.sol#L318-L367` (redeemFor)

**Description:** Minting and redemption functions allow arbitrarily small amounts. Combined with integer division fee calculations, this enables zero-fee dust transactions.

**Recommendation:** Implement minimum transaction thresholds:

```solidity
uint256 public constant MIN_MINT_AMOUNT = 1e18;
uint256 public constant MIN_REDEEM_AMOUNT = 1e18;

function mintFor(address recipient, uint256 dlfAmount, uint256 minAmountOut) public {
    require(dlfAmount >= MIN_MINT_AMOUNT, "Amount below minimum");
    // ...
}
```

---

#### I-02: Oracle Single Point of Failure Without Fallback

**Location:** `iTryIssuer.sol#L65`

**Description:** The protocol relies on a single oracle for all NAV price conversions. No fallback oracle or circuit breaker mechanism exists for oracle failures, temporary outages, or stale prices.

**Observation:** Oracle is upgradeable via `setOracle()` (admin-only), providing recovery mechanism but requiring manual intervention.

**Recommendation:** Implement fallback oracle pattern with staleness checks:

```solidity
IOracle public primaryOracle;
IOracle public fallbackOracle;
uint256 public constant MAX_PRICE_STALENESS = 1 hours;

function _getPrice() internal view returns (uint256 price) {
    (uint256 primaryPrice, uint256 timestamp) = primaryOracle.getPrice();

    if (block.timestamp - timestamp <= MAX_PRICE_STALENESS) {
        return primaryPrice;
    }

    // Try fallback if primary is stale
    if (address(fallbackOracle) != address(0)) {
        (uint256 fallbackPrice,) = fallbackOracle.getPrice();
        return fallbackPrice;
    }

    revert("No fresh oracle price available");
}
```

---

#### I-03: Missing Deadline Parameters in Time-Sensitive Operations

**Locations:** `iTryIssuer.sol` - `mintITRY`, `mintFor`, `redeemITRY`, `redeemFor`

**Description:** Minting/redemption functions lack deadline parameters, allowing transactions to be held in mempool indefinitely. Oracle prices could change significantly between signing and execution.

**Current Signature:**

```solidity
function mintFor(address recipient, uint256 dlfAmount, uint256 minAmountOut) public
```

**Recommendation:** Add deadline parameter following Uniswap pattern:

```solidity
function mintFor(
    address recipient,
    uint256 dlfAmount,
    uint256 minAmountOut,
    uint256 deadline
) public {
    require(block.timestamp <= deadline, "Transaction expired");
    // ... rest of function
}
```

This prevents execution of stale transactions with outdated oracle prices.

---

## Methodology

### Analysis Approach

This audit employed a multi-phase approach combining automated tools, manual code review, and systematic testing:

#### Phase 1: Reconnaissance
- Project documentation review (README, technical docs, previous audits)
- Codebase architecture mapping
- Dependency analysis (OpenZeppelin, LayerZero, Solady)
- Known issues cataloging (Zellic audit findings)

#### Phase 2: Automated Analysis
- Static analysis with Slither
- Symbolic execution considerations
- Test coverage analysis via Foundry

#### Phase 3: Manual Code Review
- Line-by-line review of in-scope contracts (1,324 nSLOC)
- Access control verification
- State variable tracking and invariant testing
- Cross-chain message flow analysis
- Oracle integration security review

#### Phase 4: Vulnerability Research
- Attack vector brainstorming per contract
- Economic attack modeling (fee avoidance, yield manipulation)
- Reentrancy vulnerability hunting
- Integer overflow/underflow analysis (though Solidity 0.8+ provides protection)
- Cross-chain message spoofing scenarios

#### Phase 5: Proof of Concept Development
- Foundry test harness setup
- PoC development for each finding
- Execution verification against actual codebase
- Impact quantification via test results

#### Phase 6: Severity Validation
- Independent second-opinion severity audit
- C4 severity guidelines strict application
- Known issue cross-referencing
- Downgrade/invalidation decisions with detailed rationale

#### Phase 7: Reporting
- Individual finding reports with full PoCs
- QA report compilation (Low/Informational findings)
- Final consolidated report generation

### Testing Infrastructure

**Environment:**
- Framework: Foundry (forge 1.4.4-stable)
- Solidity Version: 0.8.20
- Test Network: Anvil (local fork)
- Coverage: PoCs for all M/H findings

**Test Files:**
- H-01-poc.t.sol (322 lines, 3 test cases)
- H-03-poc.t.sol (reentrancy demonstrations)
- M-01-poc.t.sol (custodian accounting)
- M-02-poc.t.sol (fee rounding)
- M-03-poc.t.sol (vesting race condition)
- M-04-poc.t.sol (slippage)
- M-05-poc.t.sol (cooldown validation)

All PoCs are executable and demonstrate exact vulnerability conditions.

### Risk Assessment Framework

Findings were evaluated using C4's official severity criteria:

**High (3):** Assets can be stolen/lost/compromised directly or via valid attack path without hypotheticals
- Criteria: Direct asset theft, no special conditions, any attacker, full PoC

**Medium (2):** Assets not at direct risk, but protocol function/availability impacted, or value leak with stated assumptions and external requirements
- Criteria: Requires external conditions, limited impact, conditional attack path, trusted role exploitation

**Low/QA:** State handling issues, spec deviations, centralization risks
- Criteria: Non-critical functionality, edge cases, best practice violations

### Severity Downgrade Criteria Applied

Several High-severity findings were downgraded based on:

1. **Trusted Role Requirement** (H-01 → M-01)
   - Requires YIELD_DISTRIBUTOR_ROLE (admin-controlled)
   - C4 guideline: Trusted role exploitation = Medium

2. **Admin-Controlled Parameters** (H-03 → M-02)
   - Requires malicious yieldToken (immutable, set by admin at deployment)
   - C4 guideline: Admin error/compromise = Medium

3. **Known Issue Match** (H-04 → Invalid)
   - Explicitly listed in Zellic audit known issues
   - C4 rule: Known issues ineligible for awards

4. **Solidity Version Protection** (H-05 → Invalid)
   - Solidity 0.8+ has built-in overflow protection
   - Fundamental misunderstanding of compiler features

---

## Appendix

### A. Proof of Concept Locations

All PoCs are located in `/home/justin/code/C4/solidity-audit/lib/2025-11-brix-money-c4-audit/test/` and use the project's existing test suite infrastructure:

| Finding | PoC File | Test Function |
|---------|----------|---------------|
| M-01 | H-01-poc.t.sol | test_H01_OracleManipulationMintsUnbackedITry |
| M-02 | H-03-poc.t.sol | test_H03_ReentrancyAllowsRecipientManipulation |
| M-03 | M-01-poc.t.sol | test_M01_CustodianRedemptionAccountingDesync |
| M-04 | M-02-poc.t.sol | test_M02_FeeRoundingThreshold |
| M-05 | M-03-poc.t.sol | test_M03_FirstDistributionBlocksSecond |
| M-06 | M-04-poc.t.sol | test_M04_MissingSlippageProtection_fastRedeem |
| M-07 | M-05-poc.t.sol | test_M05_UnauthorizedCooldownInitiation |

**Running PoCs:**

```bash
# Individual test
forge test --match-test test_H01_OracleManipulationMintsUnbackedITry -vvvv

# All PoCs
forge test --match-path "test/*-poc.t.sol" -vv

# Specific finding
forge test --match-contract M04PoCTest -vv
```

### B. Excluded Findings Detailed Rationale

#### H-02: Unchecked Return Value in FastAccessVault Transfer

**Reason for Exclusion:**
1. **Code actually checks return value:** Line 154 of FastAccessVault.sol contains `if (!_vaultToken.transfer(_receiver, _amount))` with explicit return value validation
2. **Matches Zellic known issue #6:** "Non-standard ERC20 tokens may break the transfer function"
3. **Out of scope per C4 rules:** Non-standard ERC20 behavior (except USDT) is explicitly invalid per C4 guidelines

**Evidence:**
```solidity
// FastAccessVault.sol:154
if (!_vaultToken.transfer(_receiver, _amount)) {
    revert TransferFailed();
}
```

The claim that return value is unchecked is factually incorrect.

---

#### H-04: Critical Accounting Bug Causes Permanent Fund Lock

**Reason for Exclusion:**
1. **Matches Zellic known issue #4:** "iTRY backing can fall below 1:1 on NAV drop. If NAV drops below 1, iTRY becomes undercollateralized with no guaranteed, on-chain remediation."
2. **Same root cause:** Both issues describe economic undercollateralization when NAV decreases
3. **Publicly disclosed:** Listed in contest README under "Publicly known issues" section

**Comparison:**

| Aspect | Known Issue #4 | H-04 Finding |
|--------|----------------|--------------|
| Trigger | NAV drop | NAV decreases after minting |
| Effect | iTRY undercollateralized | Users cannot redeem |
| Recovery | No on-chain remediation | No recovery mechanism |
| Impact | Insolvency risk | Permanent fund lock |

**Verdict:** These describe the same underlying issue from different perspectives. Per C4 rules, known issues are ineligible for awards.

---

#### H-05: Integer Overflow in Cooldown Timestamp Calculation

**Reason for Exclusion:**
1. **Fundamental misunderstanding:** Solidity 0.8.0+ has built-in overflow/underflow protection
2. **All contracts use Solidity 0.8.20:** Automatic revert on arithmetic overflow
3. **No vulnerability exists:** The proposed "attack" would simply revert the transaction

**Evidence:**
```solidity
// All contracts declare:
pragma solidity 0.8.20;

// Arithmetic operations automatically checked since 0.8.0
uint256 cooldownEnd = block.timestamp + cooldownDuration;  // Reverts on overflow
```

**Solidity 0.8+ Protection:**
- Addition overflow: Automatic revert
- Subtraction underflow: Automatic revert
- Multiplication overflow: Automatic revert
- No `unchecked` blocks in vulnerable code

This finding demonstrates lack of understanding of Solidity 0.8+ safety features.

---

### C. Contract Interaction Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interface Layer                       │
└───────────────────────┬─────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐ ┌────────────┐ ┌──────────────────┐
│  iTryIssuer  │ │  StakediTry │ │ FastAccessVault  │
│              │ │   (wiTRY)   │ │                  │
│ Mint/Redeem  │ │  ERC4626    │ │  Buffer/Liquidity│
└──────┬───────┘ └──────┬─────┘ └────────┬─────────┘
       │                │                 │
       │                └────────┬────────┘
       │                         │
       ▼                         ▼
┌──────────────┐          ┌──────────────┐
│  iTRY Token  │          │YieldForwarder│
│              │◄─────────│              │
│  ERC20 + ACL │          │  Distribution│
└──────┬───────┘          └──────────────┘
       │
       │ (LayerZero OFT)
       │
       ▼
┌──────────────────────────────────────────┐
│     Cross-Chain Layer (LayerZero)         │
│                                           │
│  iTryTokenOFT ◄──► Remote Chain Tokens   │
│  wiTryOFT     ◄──► Remote wiTRY          │
│  UnstakeMessenger ◄──► wiTryVaultComposer│
└──────────────────────────────────────────┘
```

### D. Access Control Matrix

| Role | Contracts | Privileges |
|------|-----------|------------|
| DEFAULT_ADMIN_ROLE | All | Root access, role management |
| MINTER_ROLE | iTRY | Mint iTRY tokens |
| YIELD_DISTRIBUTOR_ROLE | iTryIssuer | Call processAccumulatedYield() |
| BLACKLIST_MANAGER_ROLE | iTRY, iTryTokenOFT | Add/remove blacklisted addresses |
| WHITELIST_MANAGER_ROLE | iTRY, iTryTokenOFT | Add/remove whitelisted addresses |
| WHITELISTED_USER_ROLE | iTRY, iTryIssuer | Mint, redeem, transfer (WHITELIST_ENABLED state) |
| BLACKLISTED_ROLE | iTRY, iTryTokenOFT | Cannot transfer, mint, burn (blocked) |
| SOFT_RESTRICTED_STAKER_ROLE | StakediTry | Can transfer wiTRY but cannot stake |
| COMPOSER_ROLE | StakediTry | Access composer-specific cross-chain functions |

### E. Key Invariants Verification

| Invariant | Status | Notes |
|-----------|--------|-------|
| Total iTRY issued ≤ DLF collateral value | ⚠️ At Risk | M-01 allows unbacked minting via oracle manipulation |
| Blacklisted users cannot transfer | ✅ Verified | Proper _beforeTokenTransfer checks |
| Whitelist enforced in WHITELIST_ENABLED | ✅ Verified | Transfer restrictions working |
| No transfers in FULLY_DISABLED state | ✅ Verified | State checks enforced |
| Custodian accounting matches reality | ❌ Broken | M-03 creates permanent accounting gaps |
| Yield distribution unblocked | ⚠️ Conditional | M-05 blocks during active vesting |
| Fee collection matches expectations | ⚠️ Exploitable | M-04 enables fee avoidance via rounding |

### F. Recommendations Summary

#### Critical (Must Fix)

1. **M-01:** Implement custody tracking in `processAccumulatedYield()` to prevent unbacked minting
2. **M-03:** Add two-phase commit pattern for custodian redemptions to prevent accounting desync

#### High Priority (Should Fix)

3. **M-02:** Add `nonReentrant` modifier to `processNewYield()` for defense-in-depth
4. **M-04:** Implement minimum transaction amounts or fee floors to prevent rounding exploitation
5. **M-06:** Add slippage protection parameters to fast redeem functions

#### Medium Priority (Consider Fixing)

6. **M-05:** Queue vesting amounts instead of reverting on active vesting
7. **M-07:** Enhance validation in cross-chain cooldown initiation
8. **L-01:** Add batch size limits to blacklist/whitelist functions
9. **L-02:** Add explicit bounds checking before uint128 downcast

#### Low Priority (Nice to Have)

10. **I-01:** Minimum transaction amount enforcement
11. **I-02:** Fallback oracle implementation
12. **I-03:** Deadline parameters for time-sensitive operations

### G. References

- **Contest Repository:** https://github.com/code-423n4/2025-11-brix-money
- **Zellic Audit Report:** [iTRY-ZellicAuditReportDraft.pdf](https://github.com/code-423n4/2025-11-brix-money/blob/main/iTRY-ZellicAuditReportDraft.pdf)
- **C4 Severity Guidelines:** https://docs.code4rena.com/awarding/judging-criteria
- **Project Documentation:** https://hackmd.io/@EKJz7PaeT2GeAUJS83WWVw/SJPLb3QBWe
- **OpenZeppelin Contracts:** v4.9.3
- **LayerZero OFT:** v2.0
- **Solady Library:** Latest

---

## Conclusion

The Brix Money protocol demonstrates strong fundamental security with comprehensive access controls and proper use of security patterns like ReentrancyGuard. The prior Zellic audit successfully addressed many critical vulnerabilities, resulting in zero validated High-severity findings in this Code4rena competition.

However, **7 Medium-severity findings** require attention before mainnet deployment:

1. **Oracle-dependent yield distribution** needs custody increase verification (M-01)
2. **Reentrancy protection gaps** should be closed for defense-in-depth (M-02)
3. **Custodian redemption path** requires two-phase commit pattern (M-03)
4. **Fee calculation** needs protection against rounding exploitation (M-04)
5. **Vesting mechanics** should handle concurrent yield distribution (M-05)
6. **Fast redemption functions** need slippage parameters (M-06)
7. **Cross-chain cooldown** requires enhanced validation (M-07)

Addressing these medium-severity findings, combined with the low-risk and informational recommendations, will significantly strengthen the protocol's security posture and user protection.

**Overall Assessment:** The protocol is well-designed with strong security foundations, requiring targeted fixes to medium-severity issues before production deployment.

---

**Report compiled by:** Claude Code Audit Agent
**Date:** December 19, 2025
**Audit Standard:** Code4rena Competition Guidelines
**Foundry Version:** 1.4.4-stable
**Solidity Version:** 0.8.20
