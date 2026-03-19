# Severity Audit Report: stable-yield-accumulator

**Date:** 2026-03-19
**Auditor:** Severity Auditor (Second Opinion)
**Contract:** StableYieldAccumulator.sol

---

## M-01: Inverted Slippage Protection Allows Claimer to Overpay Without Protection

### Claimed Severity: Medium
### Assessed Severity: Low (QA)
### Agreement: NO -- Recommend Downgrade

### Analysis

**Root Cause Assessment:**
The finding claims the `minRewardTokenSupplied` parameter is "inverted" slippage protection. However, upon independent review, this is **not a bug -- it is working exactly as documented and intended**.

The NatSpec in the interface (`IStableYieldAccumulator.sol` line 274) explicitly states:

> `@param minRewardTokenSupplied Minimum acceptable payment amount in reward token decimals. Reverts with InsufficientYield if actual payment is less than this value. Pass 0 to disable slippage protection.`

The parameter name is `minRewardTokenSupplied`. The documentation says "Minimum acceptable payment amount." The code does exactly what both the name and documentation describe: it enforces a floor on the payment amount.

**Is this a vulnerability or a missing feature?**
The finding reframes the absence of an upper-bound parameter as a "vulnerability." But the protocol intentionally designed the slippage check from the claimer's perspective of ensuring the claim is worth executing (i.e., covers gas costs). The claimer is an arbitrageur who profits from the discount between what they pay and what they receive. Their primary risk is that yield drops between calculation and execution, making the claim unprofitable -- hence the floor check.

**Attack Path Critique:**
The described attack path requires the owner to front-run the claimer by changing the discount rate. This has several issues:
1. **Admin front-running is not a valid attack vector** per C4 guidelines -- it falls under "reckless admin mistakes" or requires trusting the admin, which is a centralization risk (QA at best).
2. The claimer receives proportionally more yield tokens when they pay more. The "overpayment" is matched by additional value received. The finding acknowledges this: "the claimer receives proportionally more yield tokens."
3. The claimer has `safeTransferFrom` approval as a natural upper bound -- they only approve what they are willing to spend.

**Impact Verification:**
- No assets are stolen or lost
- The claimer receives fair value for what they pay (more payment = more yield tokens)
- The "overpayment" is relative to an off-chain expectation, not a loss of funds
- The claimer can limit exposure via ERC20 approval amounts

**Factual Errors:**
The finding states the parameter's purpose is to protect against overpayment, but both the parameter name (`min...`) and NatSpec documentation explicitly describe it as a minimum floor. Calling this "inverted" implies it was intended to be a ceiling, which contradicts the code's own documentation.

### Recommendation: DOWNGRADE to QA/Low

**Reasoning:**
- The code works exactly as documented and named
- The absence of a max-payment parameter is a design suggestion (missing feature), not a vulnerability
- The attack path relies on admin action (discount rate change), which is a centralization concern
- No actual loss occurs -- claimer receives proportional value
- This is a spec deviation at most: one could argue the protocol "should" offer upper-bound protection, but the protocol never claims to

---

## M-02: All-or-Nothing Claim Design Creates Protocol-Wide DoS via Single Broken Strategy

### Claimed Severity: Medium
### Assessed Severity: Medium
### Agreement: YES

### Analysis

**Root Cause Assessment:**
The root cause is correctly identified. The `claim()` function iterates all strategies in a single atomic transaction without `try/catch` isolation. If any strategy's `withdrawFrom()` reverts, the entire claim fails. This is a genuine architectural vulnerability.

**Attack Path Validation:**
The attack path is realistic and does not rely on hypotheticals:
1. External yield strategies can legitimately pause or enter error states (e.g., Aave pausing a market, a vault reaching withdrawal limits)
2. This is not an admin-dependent scenario -- external protocol conditions can trigger it
3. The DoS affects all claimers, not just one user

**Conditions Assessment:**
- Requires an external strategy to enter a reverting state -- this is achievable and has historical precedent (DeFi protocols pause regularly)
- The owner can mitigate via `pauseToken()`, but there is a real DoS window
- No on-chain mechanism to identify which strategy failed

**Impact Verification:**
- Protocol's core claim functionality is blocked
- Phlimbo receives no reward tokens during the DoS window
- Limbo stakers receive no stable rewards
- Yield accumulates but is inaccessible
- Funds are not permanently lost but are temporarily frozen

The impact is accurately described. This is a legitimate availability issue with external conditions that are realistic and historically precedented.

**Factual Accuracy:**
The finding is factually accurate. The code at lines 434-451 does perform unguarded external calls in a loop. The `tokenConfigs[token].paused` check at line 439 provides an owner mitigation path, which the finding correctly acknowledges.

**Why this stays Medium and not High:**
- No direct asset theft or permanent loss
- Owner has a mitigation path (pauseToken)
- Requires external strategy failure (external condition)
- Temporary DoS, not permanent

**Why this is not Low/QA:**
- Protocol availability is genuinely impacted
- All claimers are affected, not just edge cases
- External strategy failures are realistic, not hypothetical
- The DoS window is real and depends on owner response time

### Recommendation: KEEP as Medium

**Reasoning:**
This meets C4 Medium criteria: "Assets not at direct risk, but protocol function/availability impacted." The external requirement (strategy failure) is realistic and well-documented. The impact on protocol availability is concrete and affects all users.

---

## Summary

| Finding | Claimed | Assessed | Agreement | Confidence | Action |
|---------|---------|----------|-----------|------------|--------|
| M-01 | Medium | Low/QA | NO | High | Downgrade -- working as designed, missing feature not a vulnerability |
| M-02 | Medium | Medium | YES | High | Keep -- legitimate availability impact with realistic conditions |
