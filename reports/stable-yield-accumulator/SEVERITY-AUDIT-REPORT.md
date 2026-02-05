# Severity Audit Report: stable-yield-accumulator

**Audit Date:** 2025-01-29
**Auditor Role:** Severity Auditor (Independent Assessment)
**Project:** StableYieldAccumulator

---

## Executive Summary

This report provides an independent severity assessment for three findings in the StableYieldAccumulator audit. The assessment follows strict C4 severity criteria to identify potential overstatement and ensure accuracy.

**Key Conclusions:**
- **H-01**: DOWNGRADE to Medium - Requires admin misconfiguration, not a valid High attack path
- **M-02**: DOWNGRADE to Low/QA - Reliance on external contract bug is out of scope
- **M-03**: KEEP as Medium - Availability impact is correctly classified

---

## Finding 1: H-01 - Zero Exchange Rate Bypass Allows Unconfigured Token Exploitation

### Claimed Severity: High

### Independent Assessment: **MEDIUM**

### Agreement: **DISAGREE - Recommend Downgrade**

### Analysis

**Attack Path Review:**
The finding claims that if admin forgets to call `setTokenConfig()` after adding a strategy via `addYieldStrategy()`, an attacker can exploit the unconfigured token for near-zero cost.

**Code Analysis:**
From `_normalizeAmount()` (lines 500-524):
```solidity
function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
    uint8 decimals = tokenConfigs[token].decimals;
    uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

    // If no config set, assume 18 decimals and 1:1 rate
    if (decimals == 0 && exchangeRate == 0) {
        return amount;
    }
    // ...
}
```

The code has a **default fallback**: if no config is set (both decimals and exchangeRate are 0), it assumes 18 decimals and 1:1 rate. This is NOT a zero exchange rate - it is a reasonable default for 18-decimal tokens.

**Attack Path Validity:**
1. The attack ONLY works if a **6-decimal token** (like USDC) is added without config
2. In this case, 1,000,000 USDC (1 USDC) would be treated as 1,000,000 (1e18 USD)
3. This is a decimal scaling bug, NOT a zero exchange rate bug
4. The attack requires: Admin adds strategy + Admin forgets to configure token

**C4 High Severity Requirements Check:**
| Requirement | Met? | Notes |
|------------|------|-------|
| Assets can be stolen/lost/compromised | Partial | Only if admin makes specific mistake |
| Direct attack path | No | Requires admin misconfiguration |
| Valid indirect path | Partial | Depends on admin error |
| No hypotheticals | **No** | "Admin forgets" is hypothetical |
| Concrete, executable exploit | No | Cannot be executed without admin mistake |

**Critical Observation:**
Per C4 criteria from CLAUDE.md: High severity requires attack path "without hypotheticals." The scenario "admin forgets to call setTokenConfig()" is a hypothetical that requires admin mistake.

**Known Invalid Finding Pattern:**
From CLAUDE.md: "Reckless admin mistakes" are listed as known invalid findings. While this is not "reckless," it still requires admin operational error.

**Correct Classification:**
This is a **Medium** finding because:
- Assets are not at direct risk
- Protocol function could be impacted with stated assumptions (admin misconfiguration)
- It is a value leak with external requirements (admin error)

### Severity Matrix Application
- **Likelihood**: Low (requires admin to add strategy without configuring token)
- **Impact**: High (if triggered, significant value extraction)
- **Combined**: Medium

### Confidence: **High**

### Disagreement Reason
The finding requires external conditions (admin misconfiguration) that disqualify it from High severity per C4 criteria. "Admin forgets" is a hypothetical scenario. Per C4: "High - Assets can be stolen/lost/compromised directly or via valid attack path **without hypotheticals**."

### Recommendation
**Downgrade to Medium.** The finding is valid but misclassified. It should be framed as:
- "Missing token configuration validation in addYieldStrategy()"
- Impact: If admin fails to configure token, wrong exchange rate may be applied
- Mitigation: Add check in `claim()` to revert if token has no explicit config

---

## Finding 2: M-02 - collectReward Call Does Not Verify Token Transfer

### Claimed Severity: Medium

### Independent Assessment: **Low/QA**

### Agreement: **DISAGREE - Recommend Downgrade**

### Analysis

**Attack Path Review:**
The finding claims that if Phlimbo's `collectReward()` doesn't properly pull tokens via `transferFrom()`, the tokens would get stuck in the accumulator.

**Code Analysis:**
From `claim()` (lines 456-457):
```solidity
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
IPhlimbo(phlimbo).collectReward(actualPayment);
```

The accumulator:
1. Transfers tokens FROM claimer TO itself (verified with SafeERC20)
2. Calls `phlimbo.collectReward(amount)` - expects Phlimbo to pull tokens

**Critical Issue with Finding:**
This finding assumes a **bug in the Phlimbo contract** (external dependency). Per the IPhlimbo interface:
```solidity
/**
 * @notice Collects rewards from yield-accumulator and updates EMA-smoothed rate
 * @dev Can only be called by the yield accumulator contract
 * @param amount Amount of reward tokens to collect
 */
function collectReward(uint256 amount) external;
```

The interface clearly documents that Phlimbo should collect the rewards. If Phlimbo fails to implement this correctly, that is a **bug in Phlimbo, not in StableYieldAccumulator**.

**C4 Scope Analysis:**
Per CLAUDE.md: "Issues in parent/forked contracts where root cause is OOS" are out of scope. The root cause here would be Phlimbo's implementation, not the accumulator's code.

**Alternative Assessment:**
Even if we consider this an integration concern:
- The `approvePhlimbo()` function exists for the owner to pre-approve Phlimbo
- If approval is set, Phlimbo can successfully pull tokens
- The issue is operational (owner must call `approvePhlimbo()` before claims work)

**C4 Medium Requirements Check:**
| Requirement | Met? | Notes |
|------------|------|-------|
| Protocol function/availability impacted | No | Relies on external contract bug |
| Value leak with stated assumptions | No | Requires bug in external contract |
| External requirements documented | N/A | Not applicable - root cause is OOS |

### Confidence: **High**

### Disagreement Reason
The finding's root cause is the assumption that Phlimbo may not properly implement `collectReward()`. This is:
1. Speculation about an external contract's implementation
2. Out of scope per C4 rules (root cause in external contract)
3. Not a vulnerability in the audited contract itself

### Recommendation
**Downgrade to Low/QA** or mark as Out of Scope. If kept, reframe as:
- "Recommendation: Add return value check or event verification for Phlimbo integration"
- Classification: QA/Informational

---

## Finding 3: M-03 - All-or-Nothing Claim Design Creates Griefing Vector

### Claimed Severity: Medium

### Independent Assessment: **MEDIUM**

### Agreement: **AGREE**

### Analysis

**Attack Path Review:**
The finding states that if a single token is paused (via `pauseToken()`), the entire `claim()` function reverts, blocking claims from all strategies including healthy ones.

**Code Analysis:**
From `claim()` (lines 429-446):
```solidity
for (uint256 i = 0; i < yieldStrategies.length; i++) {
    address strategy = yieldStrategies[i];
    address token = strategyTokens[strategy];
    if (token == address(0)) continue;

    if (tokenConfigs[token].paused) revert TokenIsPaused();  // <-- Reverts for ANY paused token

    uint256 yield = _getYieldForStrategy(strategy, token);
    if (yield > 0) {
        // ... withdraw yield
    }
}
```

**Attack Path Validation:**
1. Owner pauses Token A due to legitimate concern (e.g., USDC blacklist)
2. Strategy B with healthy Token B has accumulated yield
3. ANY claim attempt reverts because Token A is in the loop
4. All yield accumulates but cannot be claimed

This is NOT griefing by an attacker - it's a design flaw in pause mechanism.

**C4 Medium Requirements Check:**
| Requirement | Met? | Notes |
|------------|------|-------|
| Protocol function/availability impacted | **Yes** | Claim function becomes unavailable |
| Value leak with stated assumptions | Partial | Yield accumulates but is locked |
| Assets not at direct risk | **Yes** | Funds are not stolen, just temporarily inaccessible |

**Key Distinction:**
- This is NOT "admin mistake" - the owner may have legitimate reason to pause one token
- The design flaw is that pausing ONE token blocks ALL claims
- This is an architectural issue, not an operational error

**Likelihood Assessment:**
- Moderate: Token pausing is a documented feature for "black swan events"
- Stablecoin depegs/issues happen periodically (UST, USDC temporary depeg, etc.)

**Impact Assessment:**
- Protocol availability impacted (claim function blocked)
- No direct fund loss (yield still accumulates, can be claimed after unpause)
- Temporary denial of service

### Confidence: **High**

### Agreement Reason
This correctly fits Medium criteria:
- Protocol function (claim) is impacted
- Availability is affected
- No direct asset theft
- Real scenario (token pausing for depegs is expected use case)

### Notes
The finding is correctly classified. The recommendation should include:
- Skip paused tokens instead of reverting
- Or provide selective claim function per strategy

---

## Summary Table

| Finding | Claimed | Assessed | Agreement | Confidence | Key Reason |
|---------|---------|----------|-----------|------------|------------|
| H-01 | High | **Medium** | DISAGREE | High | Requires admin misconfiguration - hypothetical attack path |
| M-02 | Medium | **Low/QA** | DISAGREE | High | Root cause is external contract (Phlimbo) - OOS |
| M-03 | Medium | Medium | AGREE | High | Availability impact correctly classified |

---

## Audit Signatures

**Severity Auditor Assessment Complete**

This independent review identified:
- 1 overstatement (H-01 should be Medium)
- 1 out-of-scope/speculative finding (M-02 should be Low/QA)
- 1 correctly classified finding (M-03)

The audit follows C4 severity criteria strictly, with particular attention to:
- Attack path validity (no hypotheticals for High)
- Scope boundaries (root cause must be in audited code)
- Impact vs. likelihood matrix
