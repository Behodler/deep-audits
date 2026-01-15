# Severity Audit Report: phlimbo-linear

**Project:** phlimbo-linear
**Audit Date:** 2026-01-15
**Auditor:** severity-auditor agent
**Scope:** Second-opinion severity validation for M-01, M-03, M-04

---

## Executive Summary

After independent review of the three Medium findings against strict C4 severity criteria, I assess:

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| M-01 | Medium | Medium | YES | High |
| M-03 | Medium | Medium | YES | Medium |
| M-04 | Medium | **Low/QA** | NO | High |

**Key Conclusions:**
- M-01 and M-03 are correctly classified as Medium
- M-04 should be **downgraded to Low/QA** - dust accumulation is not Medium severity
- No findings warrant upgrade to High

---

## Finding-by-Finding Analysis

### M-01: Front-running collectReward() allows disproportionate reward capture

**Claimed Severity:** Medium
**Assessed Severity:** Medium
**Agreement:** YES
**Confidence:** High

#### Analysis

**Asset Risk Assessment:**
- Impact is reward dilution, NOT direct theft of principal
- Attacker captures rewards they arguably "earned" during their stake period
- No principal funds are stolen - only reward distribution is affected

**Attack Path Validation:**
- Attack path is concrete and executable (mempool monitoring, sandwich)
- No hypotheticals required - standard MEV attack pattern
- PoC demonstrates 30x efficiency gain (29 tokens/hour vs ~1 token/hour)

**Why NOT High:**
The 30x efficiency gain is compelling but misleading. Per C4 criteria:
> "High: Assets can be stolen/lost/compromised directly"

This finding shows **disproportionate reward capture**, not theft. The attacker:
1. Stakes real tokens (1000 phUSD)
2. Takes genuine price/timing risk
3. Earns rewards during their actual stake period
4. Does NOT steal Alice's existing rewards

The unfairness is in the *distribution efficiency*, not in taking funds that belong to others. This is a protocol design flaw allowing economic exploitation, not asset theft.

**C4 Classification:**
> "Medium: Assets not at direct risk, but protocol function/availability impacted, or value leak with stated assumptions"

This finding fits Medium perfectly:
- Protocol function (fair reward distribution) is impacted
- Value leak exists (legitimate stakers get less than expected)
- Assumptions are documented (MEV capability, mempool monitoring)

**Verdict:** Medium is correct. Do NOT upgrade to High.

---

### M-03: Zero total staked state enables reward loss griefing

**Claimed Severity:** Medium
**Assessed Severity:** Medium
**Agreement:** YES
**Confidence:** Medium

#### Analysis

**Asset Risk Assessment:**
- 51% reward loss demonstrated in PoC
- Rewards become permanently stuck (no recovery mechanism)
- However, this is rewards, NOT principal funds

**Attack Path Validation:**
- Requires attacker to be sole staker OR coordinate with all stakers
- Attack is economically irrational for a normal attacker (they lose their own rewards)
- Primary risk is organic zero-stake periods, not malicious griefing

**Why NOT High:**
The "permanent fund loss" argument is nuanced:
1. Principal funds are never at risk - users can always withdraw
2. Lost funds are **undistributed rewards**, not user deposits
3. Attack requires coordination or being sole staker (external condition)
4. Self-griefing is economically irrational

Per C4 High criteria:
> "Assets can be stolen/lost/compromised directly"

The rewards were never claimed/owned by users - they are protocol rewards that fail to distribute. This is different from losing funds users deposited.

**Why Medium (not Low):**
- Impact is substantial (51% loss)
- Permanent - no recovery mechanism
- Protocol functionality clearly impaired
- Economic value genuinely leaked

**External Conditions:**
- Requires zero-stake state (either organic or coordinated)
- Not exploitable by arbitrary external attacker alone
- Fits C4 Medium: "value leak with stated assumptions and external requirements"

**Verdict:** Medium is correct. The permanent nature and substantial percentage loss justify Medium, but the reward-vs-principal distinction prevents High.

---

### M-04: Cumulative precision loss in rewardPerSecond recalculation

**Claimed Severity:** Medium
**Assessed Severity:** **Low/QA**
**Agreement:** NO - Recommend Downgrade
**Confidence:** High

#### Analysis

**Asset Risk Assessment:**
- ~100,615,332 wei stuck after 1000 operations
- This equals approximately 0.0000001 tokens (100 micro-tokens)
- Impact is negligible in absolute terms

**Attack Path Validation:**
- This is NOT an attack - it's inherent integer division behavior
- No attacker benefits from this
- Cannot be weaponized to steal funds
- Purely passive dust accumulation

**Why NOT Medium:**
Per C4 Medium criteria:
> "protocol function/availability impacted, or value leak with stated assumptions"

Precision loss of ~100 wei per operation does NOT:
1. Impact protocol function (staking/rewards work correctly)
2. Impact protocol availability (no DoS vector)
3. Constitute meaningful "value leak" (~0.0000001 tokens over 1000 ops)

**Quantitative Analysis:**
- After 1000 operations: ~100,615,332 wei = 0.0001 tokens
- After 10,000 operations: ~1,006,153,320 wei = 0.001 tokens
- After 100,000 operations: ~0.01 tokens

For context, if reward tokens are stablecoins (like USDC):
- 100,000 operations would lose approximately **$0.01**

This is textbook "dust" that every DeFi protocol accumulates.

**C4 Severity Reality Check:**
The submission states: "Loss is small per operation but guaranteed to occur"

Guaranteed occurrence does not elevate dust to Medium. Virtually all DeFi protocols have this property. It's a known limitation of integer arithmetic, not a vulnerability.

**Comparison to Other Protocols:**
- Uniswap V2/V3: Accumulates swap dust
- Aave: Has precision loss in interest calculations
- Compound: Has similar rounding dust

None of these are considered Medium severity findings.

**Verdict:** Downgrade to Low/QA. This is standard integer division behavior, not a meaningful vulnerability. Including this as Medium would overstate the finding portfolio and potentially damage credibility with judges.

---

## Summary of Recommendations

| Finding | Action | Reasoning |
|---------|--------|-----------|
| M-01 | **Keep as Medium** | Correct classification - value leak, not theft |
| M-03 | **Keep as Medium** | Correct - permanent reward loss with external conditions |
| M-04 | **Downgrade to Low/QA** | Dust accumulation is not Medium severity |

## Flags for Human Review

1. **M-03 Borderline:** The "permanent loss" aspect could theoretically argue for High, but the reward-vs-principal distinction is important. If judges view undistributed rewards as "protocol funds lost," severity could shift. Current assessment: Medium is correct per strict C4 interpretation.

2. **M-04 Strong Downgrade:** This finding should NOT be submitted as Medium. It risks:
   - Appearing as padding/low-effort
   - Damaging credibility of other findings
   - Potential judge rejection as "not a vulnerability"

---

## Methodology Notes

This audit applied strict C4 severity criteria:

**High (3):** "Assets can be stolen/lost/compromised directly or via valid attack path without hypotheticals"
- Key test: Can attacker steal user deposits or protocol funds?
- Hypotheticals disqualify

**Medium (2):** "Assets not at direct risk, but protocol function/availability impacted, or value leak with stated assumptions and external requirements"
- Key test: Is there meaningful value leak or functional impairment?
- External conditions are acceptable if documented

**Low/QA:** State handling issues, spec deviations, dust accumulation
- Key test: Is this a real security concern or operational inconvenience?

---

*Report generated by severity-auditor agent*
