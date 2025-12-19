# Severity Audit Report - Brix Money
**Auditor:** severity-auditor
**Date:** 2025-12-19
**Purpose:** Independent second-opinion severity validation to prevent overstatement

---

## Executive Summary

**CRITICAL FINDING:** All three High-severity findings show severity overstatement and require downgrade or invalidation.

- **H-01**: Recommend downgrade to **MEDIUM** (requires trusted role)
- **H-03**: Recommend downgrade to **MEDIUM** (requires admin-controlled malicious token)
- **H-04**: Recommend marking as **INVALID** (matches known issue #5 exactly)

**Risk to Warden:** Without severity correction, these findings face high probability of judge downgrade, resulting in zero HM awards per contest rules.

---

## Finding-by-Finding Analysis

### H-01: Unbacked iTRY Minting via Yield Distribution Manipulation

**Claimed Severity:** HIGH
**Assessed Severity:** MEDIUM
**Agreement:** ❌ DISAGREE
**Confidence:** HIGH

#### Analysis

| Criterion | Assessment |
|-----------|------------|
| Asset Risk | Potential value dilution, not direct theft |
| Attack Path | Requires YIELD_DISTRIBUTOR_ROLE (trusted role) |
| Conditions | Attacker must have YIELD_DISTRIBUTOR_ROLE OR oracle must be compromised |
| Impact | Dilution of backing ratio, not immediate fund loss |

#### Disagreement Rationale

This finding **requires a trusted role** (`YIELD_DISTRIBUTOR_ROLE`) to execute the attack. The PoC explicitly demonstrates this:

```solidity
// From H-01 PoC line 114:
vm.prank(admin);
issuer.grantRole(YIELD_DISTRIBUTOR_ROLE, yieldDistributor);

// Attack execution requires this role (line 189):
vm.prank(yieldDistributor);
uint256 mintedYield = issuer.processAccumulatedYield();
```

**Code Evidence:**
- Line 398 in iTryIssuer.sol: `function processAccumulatedYield() external onlyRole(_YIELD_DISTRIBUTOR_ROLE)`
- Line 179 in iTryIssuer.sol: Role granted by admin during initialization
- README confirms: "Yield Processor" role is "Owner" controlled

**Oracle Manipulation Claims:**
The finding mentions oracle manipulation as an attack vector, but the README explicitly states:
> "In the context of this audit, the NAV price queried can be assumed to be correct. The Oracle implementation will perform additional checks on the data feed and revert if it encounters issues."

This removes oracle manipulation from scope, leaving only trusted role exploitation.

#### C4 Severity Classification

**C4 Medium Definition:**
> "Assets not at direct risk, but protocol function/availability impacted, or value leak with stated assumptions and external requirements."

This finding matches Medium criteria exactly:
- ✅ External requirement: YIELD_DISTRIBUTOR_ROLE (admin-controlled)
- ✅ Value leak (gradual dilution), not direct theft
- ✅ Requires stated assumption (compromised admin role)

**C4 High Definition:**
> "Assets can be stolen/lost/compromised directly or via valid attack path without hypotheticals."

This finding does NOT match High criteria:
- ❌ Requires hypothetical: "compromised admin with YIELD_DISTRIBUTOR_ROLE"
- ❌ Not direct theft - gradual value dilution
- ❌ Requires trusted role, not permissionless exploit

#### Recommendation

**Downgrade to MEDIUM**

The vulnerability is real and the PoC is valid, but this is a **governance/trust model risk**, not a permissionless High-severity exploit. Trusted role exploitation is explicitly Medium-severity per C4 standards.

---

### H-03: Reentrancy in YieldForwarder processNewYield

**Claimed Severity:** HIGH
**Assessed Severity:** MEDIUM
**Agreement:** ❌ DISAGREE
**Confidence:** HIGH

#### Analysis

| Criterion | Assessment |
|-----------|------------|
| Asset Risk | Limited risk - requires malicious yieldToken |
| Attack Path | Requires yieldToken to be malicious ERC20 with callbacks |
| Conditions | yieldToken must be malicious/non-standard (ERC777/ERC1363) AND set by admin |
| Impact | Potential yield redirection, but requires admin to set malicious token |

#### Disagreement Rationale

**Critical Code Context:**

```solidity
// Line 35 in YieldForwarder.sol:
IERC20 public immutable yieldToken;
```

The `yieldToken` is **immutable** and set at contract deployment. This means:
1. Admin must intentionally deploy with a malicious token, OR
2. The token itself must be compromised/upgraded after deployment

Both scenarios require either:
- Admin mistake (deploying with wrong token)
- External token compromise (token upgrade/exploit)

**Standard ERC20 Behavior:**
Standard ERC20 tokens (USDC, USDT, DAI, etc.) have **no transfer callbacks**. The vulnerability only applies to:
- ERC777 (with `tokensToSend` hooks)
- ERC1363 (with `transferAndCall`)
- Custom malicious implementations

**Defense-in-Depth Observation:**
The finding correctly notes that `rescueToken()` (line 156) uses `nonReentrant`, but `processNewYield()` does not. This is a valid defense-in-depth concern, but **not a High-severity exploitable bug** in the context of standard tokens.

#### C4 Severity Classification

**C4 Medium Definition:**
> "Value leak with stated assumptions and external requirements."

External requirements for exploitation:
- ✅ yieldToken must be malicious/non-standard
- ✅ Admin must set this token (either mistake or compromise)
- ✅ Not exploitable with standard ERC20 tokens

**C4 High Definition:**
> "Assets can be stolen/lost/compromised directly or via valid attack path without hypotheticals."

Does NOT meet High criteria:
- ❌ Requires hypothetical malicious token
- ❌ Requires admin to deploy with wrong token
- ❌ Standard tokens are not vulnerable

#### Recommendation

**Downgrade to MEDIUM**

This is a valid finding for **defense-in-depth** and the missing `nonReentrant` modifier should be added. However, the exploitability requires admin to set a malicious token, which makes this Medium-severity per C4 standards, not High.

---

### H-04: Critical Accounting Bug Causes Permanent Fund Lock

**Claimed Severity:** HIGH
**Assessed Severity:** INVALID (Known Issue)
**Agreement:** ❌ DISAGREE
**Confidence:** HIGH

#### Analysis

| Criterion | Assessment |
|-----------|------------|
| Asset Risk | NAV price volatility causing redemption issues |
| Attack Path | No attack - this is expected behavior |
| Conditions | NAV decreases below mint price |
| Impact | **Matches Known Issue #5 exactly** |

#### Known Issue Match

**From README.md - Publicly Known Issues Section:**

> **Known Issue #5:**
> "iTRY backing can fall below 1:1 on NAV drop. If NAV drops below 1, iTRY becomes undercollateralized with no guaranteed, on-chain remediation. Holders bear insolvency risk until a top-up or discretionary admin intervention occurs."

**From H-04 Finding:**

> "Users cannot redeem their iTRY tokens when NAV decreases after minting. This results in permanent loss of user funds with no recovery mechanism."

**Comparison:**

| Aspect | Known Issue #5 | H-04 Finding |
|--------|----------------|--------------|
| Trigger | NAV drop | NAV decreases after minting |
| Effect | iTRY becomes undercollateralized | Users cannot redeem (due to undercollateralization) |
| Recovery | No guaranteed on-chain remediation | No recovery mechanism |
| Impact | Holders bear insolvency risk | Permanent loss of user funds |

**VERDICT:** These describe **the exact same issue** - undercollateralization on NAV drop with no guaranteed on-chain recovery.

#### C4 Rules on Known Issues

From the contest README:
> "## Publicly known issues
>
> _Anything included in this section is considered a publicly known issue and is therefore ineligible for awards._"

The finding H-04 is explicitly covered by Known Issue #5 from the Zellic audit report.

#### Recommendation

**Mark as INVALID / OUT OF SCOPE**

This finding should be invalidated as it directly matches a known issue disclosed in the contest README. Per C4 rules, known issues are ineligible for awards regardless of severity or quality of PoC.

**Note to Warden:** The PoC may demonstrate a valid arithmetic scenario, but the underlying issue is already known to the protocol team and listed in the contest documentation.

---

## Summary Table

| Finding | Claimed | Assessed | Reason | Action Required |
|---------|---------|----------|--------|-----------------|
| H-01 | HIGH | MEDIUM | Requires YIELD_DISTRIBUTOR_ROLE (trusted role) | Downgrade |
| H-03 | HIGH | MEDIUM | Requires admin-controlled malicious token | Downgrade |
| H-04 | HIGH | INVALID | Matches known issue #5 exactly | Invalidate |

---

## C4 Severity Guidelines Reference

### High (3)
> Assets can be stolen/lost/compromised directly or via valid attack path **without hypotheticals**

**Key Requirements:**
- Direct asset theft/loss
- No special conditions required
- Exploitable by any attacker
- PoC demonstrates full impact

### Medium (2)
> Assets not at direct risk, but protocol function/availability impacted, or **value leak with stated assumptions and external requirements**

**Key Requirements:**
- Requires external conditions
- Impact is limited or conditional
- Attack path has assumptions
- Trusted role exploitation

### Low/QA
> State handling issues, spec deviations, centralization risks

---

## Impact Assessment

### Risk to Submissions

Without severity correction, these findings face **high probability of judge downgrade**:

**From Contest README:**
> "High- or Medium-risk submissions downgraded by the judge to Low-risk (QA) will be ineligible for awards."

**Financial Impact:**
- H-01 downgraded to M → Reduced payout
- H-03 downgraded to M → Reduced payout
- H-04 marked invalid → Zero payout
- Total HM pool at risk if no valid Highs remain

### Recommendations for Resubmission

1. **H-01**: Resubmit as Medium with focus on trusted role requirement
2. **H-03**: Resubmit as Medium with focus on defense-in-depth
3. **H-04**: Do not resubmit (known issue)

---

## Severity Assessment Criteria Applied

### Keep as High ✅
- Direct asset theft possible
- No conditions required
- Executable by any attacker
- PoC demonstrates full impact

### Downgrade to Medium ⚠️
- Requires external conditions ← **H-01, H-03**
- Impact is limited
- Attack path has assumptions
- Theoretical but plausible

### Downgrade to Invalid ❌
- Matches known issues ← **H-04**
- Out of scope per README
- Already disclosed

---

## Conclusion

**All three High findings require severity adjustment:**

1. **H-01** → Medium (trusted role requirement)
2. **H-03** → Medium (admin-controlled token requirement)
3. **H-04** → Invalid (known issue)

**Recommendation:** Update severity classifications before final submission to avoid judge downgrades and maximize HM award potential.

---

**Report Generated:** 2025-12-19T03:30:00Z
**Auditor:** severity-auditor (independent assessment)
**Methodology:** C4 severity guidelines strict application with code verification
