# Severity Audit Report: stable-yield-accumulator-04

**Project**: stable-yield-accumulator (re-audit after mitigations)
**Auditor**: severity-auditor
**Date**: 2026-02-11
**Mode**: C4 Regular Audit

## Executive Summary

Reviewed 8 findings for severity accuracy. 2 confirmed as Medium (submittable), 1 disagreement (downgrade M-03 from Medium to Low), 1 repeat disagreement (M-04 remains Low/QA), 3 assessed as non-issues, 1 assessed as QA.

| Finding | Claimed | Assessed | Agreement | Submit? |
|---------|---------|----------|-----------|---------|
| M-01 (carry 03-M-02) | Medium | **Medium** | Yes | **Yes** |
| M-02 (carry 03-M-03) | Medium | **Medium** | Yes | **Yes** |
| M-03 (NEW) | Medium | **Low** | No | No |
| M-04 (carry 03-M-04) | Medium | **Low/QA** | No | No |
| DEDUP-005 | Needs assessment | **Non-issue** | - | No |
| DEDUP-010 | Needs assessment | **Non-issue** | - | No |
| DEDUP-008 | Needs assessment | **QA** | - | No |
| DEDUP-004 | Needs assessment | **Non-issue** | - | No |

---

## Finding-by-Finding Analysis

### M-01: Residual phUSD delta silently dropped -- ClaimArbitrage DoS

**Carried from**: 03-M-02
**Claimed**: Medium | **Assessed**: Medium | **Agreement**: Yes
**Confidence**: High
**Mitigated**: NO (verified at `ClaimArbitrage.sol` line 364)

**Analysis**:

The `_settleResidualDelta(phUSD)` function at line 349 silently returns at line 364 when `stableToUSDCPool[phUSD]` is not configured and `phUSD != sUSDS`. Any non-zero phUSD delta remaining after the pump/unwind cycle (virtually guaranteed due to AMM fee mechanics) remains unsettled, causing PoolManager to revert the entire transaction.

The key insight validating Medium severity: not configuring `stableToUSDCPool[phUSD]` is the **natural default**, not an admin mistake. phUSD is the protocol's own synthetic stablecoin. The `stableToUSDCPool` mapping is conceptually for external stablecoins requiring USDC conversion. The code comment at line 363 ("residual phUSD delta should be negligible after unwind") reveals the developers themselves assumed the delta would be zero, which is incorrect given AMM fee mechanics.

The DoS affects only ClaimArbitrage, not direct `SYA.claim()` calls. The owner can workaround by configuring `stableToUSDCPool[phUSD]`, but the silent return masks the root cause.

**Verdict**: Medium is appropriate. Protocol function/availability impact on the ClaimArbitrage helper contract.

---

### M-02: Pause single token blocks ALL claims

**Carried from**: 03-M-03
**Claimed**: Medium | **Assessed**: Medium | **Agreement**: Yes
**Confidence**: High
**Mitigated**: NO (verified at `StableYieldAccumulator.sol` lines 589 and 803)

**Analysis**:

`claim()` at line 589 uses `revert TokenIsPaused()` for ANY paused token encountered during iteration. `calculateClaimAmount()` at line 803 uses `continue` to skip paused tokens. This semantic inconsistency means:

1. Admin pauses one token during a depeg (expected operational behavior per project docs)
2. `calculateClaimAmount()` reports claimable yield (skips the paused token)
3. `claim()` reverts when it encounters the paused token
4. ALL yield claiming is blocked for ALL strategies, not just the depegged token

This is NOT an admin trust issue. The admin is performing the intended action ("Pause tokens for black swan events"). The bug is the disproportionate protocol response (global DoS) to a correct admin action. The design intent of per-token granular pausing is defeated by the implementation.

**Verdict**: Medium is well-justified. Clear protocol function/availability impact from a genuine code logic inconsistency.

---

### M-03: Incomplete M-01 mitigation -- validates knownStables membership but not pool route

**Claimed**: Medium | **Assessed**: Low | **DISAGREEMENT**
**Confidence**: High

**Analysis**:

`_validateKnownStablesCoverage()` at lines 411-424 checks whether each SYA strategy token exists in `knownStables[]` but does not verify whether `stableToUSDCPool[token]` is configured. If a token passes the membership check but has no pool route, Step 5 (line 233) will attempt to swap using a zeroed `PoolKey`, causing PoolManager to revert.

**Why this should be Low, not Medium**:

The attack path requires **two owner configuration actions where the owner forgets the second step**:
1. Owner calls `addKnownStable(token)` -- token is added to the list
2. Owner forgets to call `setStableToUSDCPool(token, poolKey)` -- no pool route configured

This is qualitatively different from M-01 where:
- M-01: The code has a design flaw (no fallback for phUSD in `_settleResidualDelta`). The natural default state is broken.
- M-03: The code works correctly when the owner completes the expected two-step configuration. The owner who is sophisticated enough to call `addKnownStable()` is expected to also call `setStableToUSDCPool()`.

Per C4 criteria, "reckless admin mistakes" are known-invalid findings. Forgetting a configuration step in a two-step owner setup process falls into this category.

The `_validateKnownStablesCoverage()` function was added specifically as a mitigation for the original M-01 (token locking). It correctly validates what it was designed to validate: token membership in `knownStables[]` to prevent silent token locking. Extending the validation to also check pool routes would be a defense-in-depth improvement, but the absence of that check is not a distinct vulnerability -- it is an incomplete admin configuration.

**Recommendation**: Downgrade to QA/Low. Mention as a suggested improvement to the M-01 mitigation, not as a standalone Medium finding.

---

### M-04: No slippage protection on Steps 5/6/7 internal swaps

**Carried from**: 03-M-04
**Claimed**: Medium | **Assessed**: Low/QA | **DISAGREEMENT** (repeat from 03)
**Confidence**: Medium

**Analysis**:

This is the same finding from the 03 audit where the severity-auditor already recommended downgrade to Low/QA. The reasoning remains unchanged:

1. **Victim is the arbitrageur, not the protocol**: The sandwich extracts value from the MEV bot's profit margin. Phlimbo stakers and the protocol receive their full discounted payment regardless.

2. **NoProfit check provides a floor**: Line 281 reverts if `usdcProfit <= 0`. The sandwich cannot cause the bot to lose money -- worst case, the transaction reverts.

3. **Arbitrageurs are MEV-aware**: The execute() function is explicitly designed for MEV bots (per NatSpec). These actors routinely use private mempools (Flashbots, MEV-Share, MEV Blocker) to avoid public mempool exposure.

4. **Stablecoin swaps limit sandwich profitability**: The stable-to-USDC swaps at Step 5 are between tokens pegged near 1:1, inherently limiting the price impact available for a sandwich.

5. **Speculative chain of consequences**: The "reduced effective discount rate" argument chains multiple hypothetical steps (sandwich reduces profit -> bots stop calling execute() -> yield is not converted -> protocol is impacted). This is exactly the kind of hand-wavy reasoning that disqualifies High and is borderline for Medium.

Per C4 criteria, Medium requires "protocol function/availability impacted or value leak with stated assumptions." The value leak here is from a third-party profit margin, not from protocol assets.

**Recommendation**: QA/Low. Best-practice improvement recommendation for defense-in-depth slippage protection.

---

### DEDUP-005: Stale USDC approval persists on SYA after claim()

**Claimed**: Needs assessment | **Assessed**: Non-issue
**Confidence**: High

**Analysis**:

Line 177 sets `IERC20(USDC).approve(address(sya), p.usdcNeeded)` during the unlock callback. After `execute()` completes:

1. CA's USDC balance is **zero**. All USDC was consumed by `claim()` (transferred to Phlimbo) or deposited back into PoolManager.
2. Even with a stale approval allowing SYA to `transferFrom(CA, ...)`, there are zero USDC to transfer.
3. The approval is overwritten by the next `execute()` call.
4. Within the atomic callback, there is no exploitation window -- the approval is set and consumed in the same transaction.

The stale approval is a code hygiene observation with zero security impact. Setting approval to zero after `claim()` would be wasted gas for defense-in-depth with no practical benefit.

**Verdict**: Not submittable at any severity.

---

### DEDUP-010: Phlimbo approval exhaustion

**Claimed**: Needs assessment | **Assessed**: Non-issue (Known Issue overlap)
**Confidence**: High

**Analysis**:

The owner must call `approvePhlimbo()` to set USDC approval for Phlimbo's `collectReward()`. If the approval is exhausted, `claim()` reverts.

This falls squarely under Known Issue #5 (owner trust). The `approvePhlimbo()` function is an owner-controlled admin operation. The owner can:
- Call `approvePhlimbo(type(uint256).max)` to eliminate the issue entirely
- Monitor and refresh approval as needed

The fact that an owner-controlled approval needs periodic refreshing is standard admin operations, not a vulnerability. The sanitizer correctly flagged the overlap.

**Verdict**: Not submittable. Known issue overlap with owner trust.

---

### DEDUP-008: ETH-only profit blocks non-payable contract callers

**Claimed**: Needs assessment | **Assessed**: QA
**Confidence**: High

**Analysis**:

Line 310 sends profit as raw ETH via low-level `call`. Contract callers without `receive()` or `fallback()` get `ETHTransferFailed` revert. However:

1. **Target users are unaffected**: `execute()` is explicitly designed for MEV bots (per NatSpec), which universally implement `receive()`.
2. **Safe failure**: The revert at line 311 is atomic -- no funds are lost or locked.
3. **EOAs are unaffected**: Only smart contract callers without receive() are impacted.
4. **Minimal interoperability concern**: Any contract wanting to use CA would trivially add `receive() external payable {}`.

**Verdict**: QA at best. Not a protocol function/availability issue. The target users are unaffected, and the failure mode is safe.

---

### DEDUP-004: Fee asymmetry in pump/unwind creates systematic sUSDS deficit

**Claimed**: Needs assessment | **Assessed**: Non-issue
**Confidence**: High

**Analysis**:

This describes the inherent cost of executing round-trip swaps in an AMM. Selling X sUSDS in Step 1 (pump) and buying back in Step 4 (unwind) always costs more due to:
- AMM trading fees (both legs)
- Price impact asymmetry

This is **not a bug** -- it is the expected economic cost of the arbitrage operation. The contract explicitly accounts for this:
- **Step 6** (lines 253-270): Covers sUSDS round-trip slippage cost by buying the deficit with USDC
- **NoProfit check** (line 281): Ensures the operation is only executed when the discount exceeds all costs

The protocol's economic model is: `discount_rate > round_trip_AMM_cost + gas_cost`. If this inequality does not hold, the transaction reverts (NoProfit). The discount rate is an owner parameter calibrated for this purpose.

Submitting this as a finding would demonstrate a misunderstanding of the protocol's economic design and the purpose of the discount rate.

**Verdict**: Not submittable. This is an observation about AMM economics, not a vulnerability.

---

## Submission Recommendations

### Submit as Medium (2 findings)

| ID | Title | Rationale |
|----|-------|-----------|
| M-01 | Residual phUSD delta silently dropped -- CA DoS | Genuine code design bug (not admin mistake). Protocol availability impacted. |
| M-02 | Pause single token blocks ALL claims | Genuine code logic inconsistency. Protocol availability impacted. Expected admin action triggers disproportionate DoS. |

### QA Candidates (2 findings)

| ID | Title | Rationale |
|----|-------|-----------|
| M-04 | No slippage protection on internal swaps | Best-practice improvement. Victim is arbitrageur, not protocol. |
| DEDUP-008 | ETH-only profit blocks non-payable callers | Minor interoperability limitation. Target users unaffected. |

### Do Not Submit (4 findings)

| ID | Title | Rationale |
|----|-------|-----------|
| M-03 | Incomplete M-01 mitigation (no pool route check) | Admin configuration oversight (known-invalid per C4). |
| DEDUP-005 | Stale USDC approval | Unexploitable -- CA holds zero USDC between calls. |
| DEDUP-010 | Phlimbo approval exhaustion | Known Issue #5 overlap (owner trust). |
| DEDUP-004 | Fee asymmetry / sUSDS deficit | AMM economics observation, not a vulnerability. |

---

## Overstatement Summary

| Finding | Overstatement Detected | Details |
|---------|----------------------|---------|
| M-01 | No | Severity accurate |
| M-02 | No | Severity accurate |
| M-03 | **Yes** | Admin mistake elevated to Medium. Should be QA/Low. |
| M-04 | **Yes** (repeat) | Third-party value leak elevated to Medium. Should be QA/Low. |
| DEDUP-005 | **Yes** | Considered possible High -- actually non-issue (no exploitable state). |
| DEDUP-010 | No | Correctly flagged for assessment. Known issue overlap confirmed. |
| DEDUP-008 | No | Correctly flagged for assessment. QA confirmed. |
| DEDUP-004 | No | Correctly flagged for assessment. Non-issue confirmed. |

---

## Final Severity Validation Pass (M-01 and M-02)

**Date**: 2026-02-11
**Purpose**: Independent final validation of the two submittable Medium findings. Specifically checking for overstatement (should be Low/QA) and understatement (should be High).

### M-01 Final Validation: CONFIRMED MEDIUM

**Source verification**: `ClaimArbitrage.sol` lines 349-383, called at line 273.

Code path verified in source:
1. Line 273: `_settleResidualDelta(phUSD)` is called after the pump/unwind cycle.
2. Line 350: `int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token))` reads the residual.
3. Line 351: `if (d >= 0) return;` -- positive residuals are silently dropped without settlement.
4. Line 355: `PoolKey memory pool = stableToUSDCPool[token]` -- reads empty/zeroed pool for phUSD.
5. Line 357: Check for zero-address currencies passes (pool is not configured).
6. Line 359: `if (token == sUSDS)` -- false, since token is phUSD.
7. Line 364: `return;` -- silent return, delta remains unsettled.

**Could this be High (3)?**
- NO. High requires "assets can be stolen/lost/compromised directly."
- No assets are stolen or permanently lost. Yield remains safely in yield strategies.
- `SYA.claim()` (StableYieldAccumulator.sol line 566) is a public external function callable by anyone. The core claim path is unaffected; only the ClaimArbitrage helper contract is DoSed.
- The owner has a workaround: call `setStableToUSDCPool(phUSD, poolKey)` to configure a phUSD/USDC pool. The silent return masks the need for this, but the escape hatch exists.
- There is no exploit path leading to fund loss.

**Could this be Low/QA?**
- NO. The DoS occurs under normal operating conditions with no special requirements.
- AMM fee asymmetry producing non-zero residual deltas after a round-trip swap is a fundamental property of constant-product AMMs, not an edge case. The developer comment at line 363 ("should be negligible") confirms they expected zero residuals, which is incorrect.
- The root cause is a code design flaw (no settlement path for phUSD), not an admin configuration mistake. The natural default state of `stableToUSDCPool[phUSD]` being unconfigured is the expected state -- phUSD is the protocol's own synthetic token, not an external stablecoin that would logically have a USDC conversion pool registered.
- ClaimArbitrage is a key protocol component for decentralized yield distribution. Its DoS has meaningful protocol function impact.
- The silent return (rather than a descriptive revert) further qualifies this as a code bug rather than a documentation issue.

**Final verdict**: Medium (2) is correct. Protocol function/availability is impacted (ClaimArbitrage DoS under normal operating conditions). No overstatement. No understatement.

**Confidence**: High.

---

### M-02 Final Validation: CONFIRMED MEDIUM

**Source verification**: `StableYieldAccumulator.sol` line 589 vs line 803.

Code path verified in source:
1. `claim()` line 589: `if (tokenConfigs[token].paused) revert TokenIsPaused();` -- hard revert on any paused token.
2. `calculateClaimAmount()` line 803: `if (tokenConfigs[token].paused) continue;` -- graceful skip of paused tokens.
3. Both functions iterate the same `yieldStrategies` array and check the same `tokenConfigs[token].paused` flag.
4. The behavioral divergence is unambiguous in the source code.

**Could this be High (3)?**
- NO. High requires "assets can be stolen/lost/compromised directly."
- No assets are stolen or permanently lost. Yield continues to accrue safely in yield strategies.
- The DoS is temporary: it persists only while the token is paused. The owner can unpause at any time.
- The claim mechanism itself is not broken -- it works correctly when no tokens are paused. The bug is the disproportionate response (global block) to a per-token pause action.
- There is no exploit path where an attacker gains unauthorized access to funds.

**Could this be Low/QA?**
- NO. The trigger condition (admin pausing a token) is an expected operational action, not an edge case or admin mistake.
- The project documentation explicitly describes per-token pausing as the intended response to depeg/black swan events (see `CLAUDE.md` of the submodule: "Pause tokens (for black swan events)").
- The impact is system-wide: ALL yield claims across ALL strategies are blocked when ANY single token is paused. This is a clear protocol availability impact.
- The `calculateClaimAmount()` / `claim()` inconsistency is a genuine code logic bug that creates a misleading API surface. Off-chain integrations (including ClaimArbitrage) will repeatedly read non-zero claimable amounts but fail on every claim attempt.
- This is not an "admin trust" or "centralization risk" issue. The admin is performing the correct, intended action. The bug is in how the code responds to that action.
- The forced choice for the admin (unpause a compromised token OR leave all claims blocked) is a meaningful operational constraint that qualifies as protocol function impact.

**Final verdict**: Medium (2) is correct. Protocol function/availability is impacted (global claim DoS from expected admin action). No overstatement. No understatement.

**Confidence**: High.

---

### Validation Summary

| Finding | Claimed | Final Assessment | Overstatement? | Understatement? | Confidence |
|---------|---------|------------------|----------------|-----------------|------------|
| M-01 | Medium | **Medium (confirmed)** | No | No | High |
| M-02 | Medium | **Medium (confirmed)** | No | No | High |

Both findings correctly identify genuine code-level bugs (not admin mistakes, not hypotheticals) that impact protocol function/availability without causing direct asset theft. They are squarely within the C4 Medium (2) definition: "Assets not at direct risk, but protocol function/availability impacted."

Neither finding should be upgraded to High because:
- No assets are stolen, lost, or compromised
- Alternative claim paths exist (direct `SYA.claim()` for M-01; unpausing for M-02)
- Both are availability/function issues, not asset-risk issues

Neither finding should be downgraded to Low because:
- Both trigger under normal/expected operating conditions (not edge cases)
- Both have root causes in code logic (not admin mistakes)
- Both have verified, concrete impact on protocol functionality
- Both have passing PoC tests (4/4 for M-01, 3/3 for M-02)
