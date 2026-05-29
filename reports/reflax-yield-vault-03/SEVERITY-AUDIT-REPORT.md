# Severity Audit Report -- reflax-yield-vault-03

**Auditor:** severity-auditor
**Date:** 2026-03-25
**Project:** reflax-yield-vault (ERC4626YieldStrategy)

---

## Executive Summary

Reviewed 5 findings (1 High, 4 Medium) with independent severity assessment against C4 criteria. Two disagreements identified: one recommended downgrade from High to Medium, one from Medium to Low. Three findings confirmed at their claimed severity.

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| H-01 | High | **Medium** | DISAGREE | High |
| M-01 | Medium | Medium | Agree | High |
| M-02 | Medium | Medium | Agree | Medium |
| M-03 | Medium | Medium | Agree | High |
| M-04 | Medium | **Low** | DISAGREE | Medium |

---

## H-01: Multi-Client Surplus Withdrawal Drains Other Clients' Yield

### Claimed Severity: High
### Assessed Severity: MEDIUM (Downgrade Recommended)

### Bug Validity: CONFIRMED

The PoC passes and clearly demonstrates the accounting error. When `_withdrawFrom()` burns shares from the communal pool for one client's surplus, every other client's `totalBalanceOf()` decreases proportionally. With two equal depositors and 200 yield, extracting client A's 100 surplus reduces client B's surplus from 100 to 50. The bug is real.

### Why Not High

The C4 definition of High requires: "Assets can be stolen/lost/compromised directly or via valid attack path without hypotheticals."

This finding fails the High threshold for these reasons:

1. **No attacker required.** The surplus extraction is performed by an authorized withdrawer through the intended protocol function `withdrawFrom()`. There is no adversarial exploit -- the loss occurs as a side effect of normal, authorized operations. The withdrawer is a trusted role explicitly configured by the contract owner.

2. **Principal is never at risk.** Only accumulated yield (surplus) is affected. The principal balances (`clientBalances`) are never modified by `_withdrawFrom()`. The worst case is that a client loses a portion of their *yield*, not their deposits.

3. **Bounded proportional loss.** The loss to any individual client is proportional to their share of the total deposits and bounded by the amount of surplus extracted. The PoC shows client B losing approximately `extractedSurplus * (clientB_principal / totalDeposited)`.

4. **Requires standard operating conditions.** Multiple clients with deposits, yield accumulation, and surplus extraction are all normal protocol operations -- not attack conditions. The vulnerability manifests through the authorized, intended workflow.

### Why Medium Is Correct

Per C4: "Assets not at direct risk, but protocol function/availability impacted, or value leak with stated assumptions and external requirements."

This is a textbook **value leak with stated assumptions**:
- Value leaked: accumulated yield from non-withdrawing clients
- Assumption: multiple clients with deposits and accrued yield
- External requirement: authorized withdrawer extracts surplus (the intended flow)

The proportional accounting system is fundamentally flawed for multi-client surplus extraction. The fix (per-client share tracking) is straightforward, and the finding is valuable. But framing this as "yield theft" overstates the adversarial nature -- it is an accounting error that causes unfair yield distribution through normal operations.

---

## M-01: Two-Phase totalWithdrawal Includes Deposits During Waiting Period

### Claimed Severity: Medium
### Assessed Severity: MEDIUM (Agree)

### Bug Validity: CONFIRMED

The PoC passes cleanly. Phase 1 caches `state.balance = 1000e18`. During the 24-hour waiting period, 2000e18 is deposited. Phase 2 withdraws all 3000e18 because `_totalWithdraw()` reads live `clientBalances` instead of using the cached `amount` parameter.

### Severity Rationale

**The user stipulates the owner is trusted.** This is an important consideration that could push toward Low. However, the timelock mechanism exists *precisely* to constrain the trusted owner's power. Its purpose (stated in the NatSpec: "Provides community protection against rugpulls") is to give the community advance warning before funds can be withdrawn by the owner.

A broken timelock is meaningful even with a trusted owner because:
- The trust model *depends* on the timelock working
- Community members can monitor Phase 1 events and react during the waiting period
- Deposits made during the waiting period bypass this protection entirely

**Counterarguments for Low:**
- The owner initiates both Phase 1 and controls the authorized client that deposits
- If the owner is truly trusted, the timelock bypass is a theoretical concern
- The actual harm requires owner collusion with a depositing client

**Why Medium holds:** The timelock is a protocol safety mechanism whose integrity matters for the trust model. Its bypass represents a protocol function impact. The root cause (ignoring the `amount` parameter) is clearly a bug, not a design choice. The external condition is that deposits must occur during the waiting period, which is a realistic scenario.

---

## M-02: Fee-Charging Vaults Create Phantom Surplus

### Claimed Severity: Medium
### Assessed Severity: MEDIUM (Agree)

### Bug Validity: CONFIRMED

The PoC demonstrates the accounting mismatch clearly. With a 5% fee vault:
- User1 deposits 1000, gets 950 shares, but `clientBalances` records 1000
- After yield accrues, user2 deposits 1000, gets fewer shares, but `clientBalances` records 1000
- `totalBalanceOf()` distributes vault value 50/50 by principal, not by actual share ownership
- User1 loses yield to user2 (difference < 1 token between received amounts)

### Scope Consideration

The critical question is whether fee-charging vaults are in scope. The NatSpec at line 15-17 states: *"This strategy is NOT designed for any specific token-vault combo. It works for any ERC4626-compliant vault."* The contract explicitly excludes rebasing vaults (line 22) but makes no mention of fee-charging vaults. Fee-on-deposit is a valid ERC4626 feature per the standard.

This supports the finding's validity. If the developers intended to exclude fee-charging vaults, they should have documented that exclusion as they did for rebasing vaults.

### Why Not Low

The impact is real value redistribution between depositors, not merely a spec deviation. The PoC shows concrete numbers. The "any ERC4626-compliant vault" claim creates a reasonable expectation of compatibility with fee-charging vaults.

### Why Not High

External condition required: a fee-charging vault must be used. Not all ERC4626 vaults charge fees. The finding is conditional on the vault selection, which is a configuration decision made at deployment time.

### Confidence: Medium

The scope question is genuinely debatable. A C4 judge could reasonably classify this as Low if fee-charging vaults are deemed out of scope, or as Medium if the NatSpec compatibility claim is taken at face value.

---

## M-03: withdrawFrom() Balance Check Caps Surplus at Principal

### Claimed Severity: Medium
### Assessed Severity: MEDIUM (Agree)

### Bug Validity: CONFIRMED

The PoC passes. With 1000 principal and 1500 surplus (150% yield):
- Attempting to withdraw 1200 of the 1500 surplus reverts with "AYieldStrategy: insufficient client balance"
- The parent contract checks `this.balanceOf()` (returns principal = 1000) >= 1200, which fails
- The child contract's surplus check would correctly allow it (1200 <= 1500)

### >100% Yield Realism

The user asks whether >100% yield is realistic. This depends on context:
- For a strategy deployed for months or years with a high-yield vault, exceeding 100% is achievable
- For short-term or low-yield strategies, it may not occur
- The code should handle all valid states correctly regardless of likelihood

### Why Medium Is Correct

1. **Funds are not lost.** The surplus exists in the vault. It can be recovered via `totalWithdrawal()`, which is a destructive but functional escape hatch.
2. **Protocol function impaired.** The intended surplus extraction mechanism does not work for its full range of valid inputs.
3. **Workaround exists.** `totalWithdrawal()` can recover the locked surplus, but it requires a 24-hour timelock and zeros out the entire position.
4. **The root cause is clear.** A deprecated function (`balanceOf()`) is used for a critical check despite being documented as deprecated in both the interface and implementation.

### Why Not High

The funds are not permanently lost or at risk of theft. They can be recovered through an alternative (if heavier) code path. The condition (>100% yield) is an external requirement that may not be common.

---

## M-04: No Slippage Protection

### Claimed Severity: Medium
### Assessed Severity: LOW (Downgrade Recommended)

### Bug Validity: DESIGN RECOMMENDATION (No PoC)

### Why This Should Be Low

1. **No PoC provided.** The submission explicitly states: *"A runnable PoC against a mock vault would not meaningfully demonstrate the issue."* C4 requires coded, runnable PoCs for Medium findings. A design finding without a demonstrated exploit path does not meet the Medium threshold.

2. **Entirely dependent on external conditions.** The attack requires:
   - The external ERC4626 vault must be susceptible to single-block share price manipulation
   - The attacker must be able to sandwich the transaction
   - The vault must lack its own anti-manipulation protections
   - None of these conditions are demonstrated or proven for any vault in scope

3. **Production vaults resist this.** The vaults mentioned in the codebase context (sBOLD, sUSDS, Inverse Finance vaults) are established protocols that typically implement anti-manipulation measures such as virtual share mechanisms, time-weighted averages, or minimum deposit thresholds.

4. **Authorized clients can potentially protect themselves.** While the finding argues clients cannot implement slippage protection (because the functions return void), authorized clients could implement external checks by querying vault share prices before and after their transactions, or by using deadline-based protection at a higher level.

5. **Common QA classification.** Missing slippage protection is routinely classified as QA/Low in C4 audits when no specific exploit path against in-scope contracts is demonstrated. This is a best-practice recommendation, not a demonstrated vulnerability.

### Acknowledgment

The finding correctly identifies a missing safety feature that should be implemented. Adding `minSharesOut` and `minAssetsOut` parameters is good defensive engineering. But the absence of this feature, without a demonstrated exploit against the specific vaults in scope, is a design recommendation -- not a Medium-severity vulnerability.

---

## Summary of Recommendations

| Finding | Action | Reasoning |
|---------|--------|-----------|
| H-01 | Downgrade to Medium | Value leak through normal operations, not adversarial theft. Only yield affected, not principal. |
| M-01 | Keep at Medium | Timelock bypass is a real protocol function failure despite trusted owner. |
| M-02 | Keep at Medium | NatSpec compatibility claim + real value redistribution supports Medium. |
| M-03 | Keep at Medium | Protocol function impaired, clear bug with deprecated function usage. |
| M-04 | Downgrade to Low | No PoC, depends on unproven external conditions, common QA finding. |
