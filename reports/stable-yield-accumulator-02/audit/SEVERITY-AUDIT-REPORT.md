# Severity Audit Report: yield-accumulator-02

**Audit Date:** 2026-02-05
**Auditor:** Severity-Auditor Agent
**Project:** AutoCompoundPositionHook (stable-yield-accumulator)

---

## Executive Summary

This report provides an independent severity assessment of three Medium findings for the AutoCompoundPositionHook contract. The assessment applies strict C4 severity criteria to validate whether claimed severities are accurate.

**Overall Assessment:**
- M-01 (Sandwich Attack): **AGREE - Medium is appropriate**
- M-02 (ExactOut Fee Bypass): **POTENTIAL UPGRADE to High warranted**
- M-03 (Single-Token Threshold): **AGREE - Medium is appropriate**

---

## Finding M-01: Sandwich Attack on Auto-Compound

### Claimed vs. Assessed

| Attribute | Claimed | Assessed |
|-----------|---------|----------|
| **Severity** | Medium | Medium |
| **Agreement** | - | YES |
| **Confidence** | - | High |

### Independent Analysis

**Asset Risk Assessment:**
- Value leak from accumulated fees through suboptimal compounding
- NOT direct asset theft - LP value is diluted, not stolen outright
- Fees are still added to liquidity, just at unfavorable ratios

**Attack Path Validation:**
The attack path is valid but has requirements:
1. Requires MEV infrastructure (Flashbots, private mempool access)
2. Requires mempool monitoring to detect compound transactions
3. Requires sufficient capital to move the price meaningfully
4. Must execute within same block (front-run + back-run)

**External Conditions:**
- MEV infrastructure required
- Gas costs may exceed profit for small compounds
- Competition from other MEV bots reduces profitability

**PoC Impact Review:**
- PoC shows 35 token profit per attack on 1,000 token compound
- This is ~3.5% value extraction per compound
- Impact is real but requires active MEV participation

**Severity Reasoning:**
Per C4 criteria, this is Medium because:
- Value leak with stated assumptions (MEV required)
- External requirements documented (infrastructure, capital)
- NOT direct asset theft - suboptimal compounding, not fund loss
- Protocol function impacted but not broken

**Verdict: AGREE - Medium severity is accurate**

The finding correctly identifies a value leak that requires external conditions. It does not meet High criteria because:
- No direct asset theft
- Requires MEV infrastructure (external condition)
- Impact is proportional, not catastrophic

---

## Finding M-02: ExactOut Swaps Bypass Hook Fees

### Claimed vs. Assessed

| Attribute | Claimed | Assessed |
|-----------|---------|----------|
| **Severity** | Medium | **Medium-High (borderline)** |
| **Agreement** | - | PARTIAL |
| **Confidence** | - | Medium |

### Independent Analysis

**Asset Risk Assessment:**
- Complete bypass of 0.05% hook fee on ALL exactOut swaps
- Protocol loses 100% of intended fee revenue from exactOut volume
- This is a direct, unconditional loss of protocol revenue

**Attack Path Validation:**
The attack path is trivially executable:
1. NO special conditions required
2. NO MEV infrastructure needed
3. ANY user can exploit by simply using exactOut swaps
4. NO front-running or timing required

**External Conditions:**
- **NONE** - This is the critical factor
- Anyone can bypass fees by choosing exactOut over exactIn
- No special knowledge or tools required

**PoC Impact Review:**
- PoC conclusively demonstrates the bug
- ExactIn charges fee, ExactOut charges ZERO
- 100% fee bypass, not partial

**Impact Calculation:**
- For $1M daily volume (50% exactOut): $250/day lost = $91,250/year
- For $10M daily volume: $912,500/year potential loss
- This compounds over time as compounded fees generate additional yield

**Severity Reasoning - Why This MAY Be High:**

Arguments FOR High:
1. **No conditions required** - Any user can exploit
2. **Direct protocol value loss** - Revenue stream completely bypassed
3. **Cumulative damage** - Loss compounds over protocol lifetime
4. **100% bypass rate** - Not partial mitigation, complete failure

Arguments FOR Medium:
1. **Not direct user fund theft** - Protocol fees, not user deposits
2. **Fee rate is small** (0.05%) - Individual loss per swap is minimal
3. **Requires awareness** - Users must know to use exactOut
4. **Protocol can update** - Fix is straightforward

**C4 Criteria Application:**

The C4 definition states:
- **High**: "Assets can be stolen/lost/compromised directly"
- **Medium**: "Assets not at direct risk, but protocol function/availability impacted, or value leak"

The fees ARE protocol assets. They are being directly lost due to a code bug. This is not hypothetical - it is guaranteed to occur on every exactOut swap.

**Verdict: DISAGREE (PARTIAL) - Consider upgrading to High**

This finding sits at the boundary between Medium and High. Key factors:
- **No external conditions** strongly favors High
- **100% bypass** strongly favors High
- **Protocol fees (not user funds)** favors Medium
- **Small individual amounts** favors Medium

**Recommendation:** This could reasonably be argued as High severity. The lack of ANY required conditions and 100% fee bypass make it more severe than typical Medium findings. However, since it affects protocol revenue rather than user principal, Medium is defensible.

**If I had to choose:** I would lean toward **High** because the attack requires ZERO conditions and results in guaranteed, permanent loss of protocol revenue.

---

## Finding M-03: Single-Token Threshold Prevents Compounding

### Claimed vs. Assessed

| Attribute | Claimed | Assessed |
|-----------|---------|----------|
| **Severity** | Medium | Medium |
| **Agreement** | - | YES |
| **Confidence** | - | High |

### Independent Analysis

**Asset Risk Assessment:**
- Fees accumulate but are not compounded
- Opportunity cost - yield not generated on idle fees
- NOT direct fund loss - fees are preserved, just not utilized

**Attack Path Validation:**
This is NOT an attack - it's a design flaw:
1. No attacker required
2. Natural market conditions trigger the issue
3. Directional swap activity is common and expected

**External Conditions:**
- Requires asymmetric swap volume (common in practice)
- Requires threshold configured on the "wrong" token
- Market must trend in one direction

**PoC Impact Review:**
- PoC shows 50,000 token1 stuck waiting for 900 token0
- Demonstrates 55:1 ratio of stuck value to blocking shortfall
- Extreme case shows 1M tokens blocked by single-unit shortfall

**Impact Assessment:**
- Core auto-compound functionality fails
- Protocol's value proposition undermined
- LP returns reduced due to idle capital
- BUT: Funds are NOT at risk - they're preserved

**Severity Reasoning:**
Per C4 criteria, this is Medium because:
- Protocol function impacted (compounding doesn't work)
- Availability of core feature compromised
- Value is not directly lost, just not optimally used
- Can be mitigated by owner adjusting threshold token

**Verdict: AGREE - Medium severity is accurate**

This is a clear Medium - protocol functionality is broken under realistic conditions, but no funds are at risk. The finding correctly identifies a design flaw that undermines the protocol's purpose.

---

## Summary Table

| Finding | Claimed | Assessed | Agreement | Confidence | Notes |
|---------|---------|----------|-----------|------------|-------|
| M-01 | Medium | Medium | YES | High | Value leak with MEV conditions |
| M-02 | Medium | Medium-High | PARTIAL | Medium | Consider upgrade - no conditions required |
| M-03 | Medium | Medium | YES | High | Design flaw, not attack |

---

## Recommendations for Submission

1. **M-01**: Submit as Medium. Severity is appropriate.

2. **M-02**: Consider arguing for High severity based on:
   - Zero external conditions
   - 100% fee bypass (not partial)
   - Guaranteed loss on every exactOut swap
   - If keeping as Medium, emphasize the unconditional nature in the report

3. **M-03**: Submit as Medium. Severity is appropriate.

---

## Potential Validity Issues

**M-01 Validity:** No issues identified. Clear vulnerability with working PoC.

**M-02 Validity:** No issues identified. Code analysis confirms the bug exists exactly as described. The negative delta check fails for exactOut swaps.

**M-03 Validity:** No issues identified. Design flaw is evident in code. However, note that:
- Owner CAN change thresholdTokenIndex
- This could be considered "admin can mitigate"
- Still valid as the default behavior is broken

---

## Auditor Notes

1. All three findings demonstrate real issues with valid PoCs.

2. None of the findings are overstated in the typical sense (claiming Medium when it's Low).

3. M-02 may actually be UNDERSTATED - the finding could reasonably be High given zero required conditions.

4. The quality of the submissions is high - clear explanations, working PoCs, and accurate root cause identification.

5. No findings appear to be duplicates of each other or commonly known issues.
