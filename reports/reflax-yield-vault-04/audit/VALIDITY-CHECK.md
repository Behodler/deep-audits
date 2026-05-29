# Phoenix Vault - Validity Check Report

Date: 2026-04-07
Checker: validity-checker agent
Scope: 5 High + 1 Medium findings

## Summary

| ID   | Title (short)                              | Status  | Confidence |
|------|--------------------------------------------|---------|------------|
| H-01 | Slippage anchored to vault internal rate   | VALID   | High       |
| H-02 | Withdraws decrement principal by REQUESTED | VALID   | High       |
| H-03 | Underlying-unit principal dilution         | VALID   | High       |
| H-04 | Two-phase total withdrawal cache desync    | VALID   | High       |
| H-05 | Cross-client surplus drainage              | VALID   | High       |
| M-01 | emergencyWithdraw bypass + accounting skew | VALID   | Medium-High|

All six findings pass the C4 known-invalid filter. Detailed reasoning per finding below.

---

## H-01 — Slippage minOut anchored to vault.convertToAssets/convertToShares

**Status: VALID**

### Pattern checks
| Category                       | Detected | Notes |
|--------------------------------|----------|-------|
| non-standard-token             | No       | sUSDe / USDe are standard ERC-20 (sUSDe is ERC-4626; this is the very surface the strategy is built around) |
| fee-on-transfer                | No       | Not invoked |
| approve-race                   | No       | Not an approve issue |
| user-mistake                   | No       | No user input error required |
| admin-mistake                  | No       | No privileged action required |
| out-of-scope (parent/forked)   | No       | Bug is in `ERC4626MarketYieldStrategy.sol` (in-scope concrete strategy) |
| known-issues duplication       | No       | Not in project's documented limitations |
| speculation/future code        | No       | Code is deployed as-shown |
| unused view function           | No       | `_swapViaCurve` minOut path is on the live deposit/withdraw flow |
| auto-tool common finding       | No       | Requires understanding of vault rate vs AMM price divergence |

### Reasoning
Direct value loss path with no privileged trigger. Anchoring minOut to a slow-moving vault accumulator while the swap executes against an AMM with transient price impact is a textbook reference-price-mismatch bug. The DoS branch (AMM at discount → minOut unreachable → withdraws revert) is a structural availability impact independent of the sandwich path.

**Verdict: VALID. Submit.**

---

## H-02 — Withdraws decrement principal by REQUESTED not RECEIVED

**Status: VALID**

### Pattern checks
| Category                       | Detected | Notes |
|--------------------------------|----------|-------|
| non-standard-token             | No       | Standard ERC-4626 / ERC-20 |
| fee-on-transfer                | No       | Not invoked |
| approve-race                   | No       | N/A |
| user-mistake                   | No       | No input mistake required |
| admin-mistake                  | No       | Trigger is any client withdraw |
| out-of-scope                   | No       | Bug in `_withdrawInternal` of in-scope strategy |
| known-issues duplication       | Partial  | NatSpec acknowledges "REQUESTED not RECEIVED" rounding for SMALL slippage; bank-run dynamic on dislocation is NOT acknowledged |
| speculation/future code        | No       | Code is live |
| auto-tool common               | No       | Requires multi-client share-pool reasoning |

### User's specific concern: Is this invalidated by NatSpec?
The NatSpec documents the requested-vs-received rounding choice as an *intentional rounding policy for routine small slippage*. What it does **not** document — and what this finding actually exploits — is:
1. Absence of a per-client proportional share cap on `sharesToWithdraw`
2. Resulting cross-client share-pool drain when slippage is non-trivial (peg event)
3. Winner-takes-all bank-run dynamic that mixes client accounts

C4 known-invalid policy treats "documented spec deviation" as invalid only when the spec acknowledges the *security consequence*, not just the *mechanic*. Here the spec acknowledges the mechanic (rounding) but not the consequence (one client draining another's principal). The cross-client mixing is the load-bearing claim.

**Verdict: VALID. Submit. The report should explicitly call out that NatSpec covers small-slippage rounding only and does not anticipate the dislocation bank-run.**

---

## H-03 — Underlying-unit principal dilution

**Status: VALID**

### Pattern checks
| Category                       | Detected | Notes |
|--------------------------------|----------|-------|
| non-standard-token             | No       | Standard ERC-4626 |
| fee-on-transfer                | No       | Not invoked |
| approve-race                   | No       | N/A |
| user-mistake                   | No       | Triggered by routine deposit timing |
| admin-mistake                  | No       | No admin involvement |
| out-of-scope                   | No       | Bug in `_depositInternal` accounting |
| known-issues duplication       | No       | Research doc only modeled `vault.deposit()` deterministic path; AMM-swap variant not analysed |
| speculation/future code        | No       | Code is live |
| auto-tool common               | No       | Requires share-vs-underlying unit reasoning |

### Reasoning
Silent value transfer between honest depositors based on AMM rate at deposit time. No attacker required, no admin required, no input mistake required. The unit mismatch (principal stored in underlying, pool denominated in shares) is a real accounting bug. Note: this is structurally adjacent to H-02 — the dedup agent kept them separate because the entry vector and victim class differ. Validity check leaves dedup decision intact.

**Verdict: VALID. Submit.**

---

## H-04 — Two-phase total withdrawal cache desync

**Status: VALID**

### Pattern checks
| Category                       | Detected | Notes |
|--------------------------------|----------|-------|
| non-standard-token             | No       | N/A |
| fee-on-transfer                | No       | N/A |
| approve-race                   | No       | N/A |
| user-mistake                   | No       | Honest depositor in window is collateral damage, not the trigger |
| admin-mistake                  | No       | Phase 1 can be triggered by client; admin not required |
| out-of-scope                   | No       | Bug spans `ERC4626MarketYieldStrategy.sol` and the in-scope `AYieldStrategy.sol` parent (NOT a forked OOS lib — `AYieldStrategy.sol` is in-scope per finding's `files` list) |
| known-issues duplication       | No       | Design doc pseudocode is the bug source, not a documented limitation |
| speculation/future code        | No       | Code is live |
| auto-tool common               | No       | Requires reasoning about cached vs live state across a 24h window |

### Reasoning
Two distinct loss paths: (1) original requestor diluted by mid-window deposits, (2) honest mid-window depositor swept by Phase 2. The "code matches design doc" caveat in the finding's own justification is correctly handled — the design doc itself is buggy, and that does not absolve the strategy. C4 only treats spec-matched behavior as invalid when the spec is part of public known issues, which this is not.

One small concern: the finding cites `AYieldStrategy.sol` as part of the bug surface. Confirm that file is in-scope (not in `lib/` as a forked dependency). Based on the path (`src/AYieldStrategy.sol`), it is in-scope.

**Verdict: VALID. Submit.**

---

## H-05 — Cross-client surplus drainage via shared share pool

**Status: VALID**

### Pattern checks
| Category                       | Detected | Notes |
|--------------------------------|----------|-------|
| non-standard-token             | No       | N/A |
| fee-on-transfer                | No       | N/A |
| approve-race                   | No       | N/A |
| user-mistake                   | No       | Authorized withdrawer acting in their normal role |
| admin-mistake                  | No       | Authorized withdrawer is not "admin" — it is a per-client role; one client's withdrawer steals from another |
| out-of-scope                   | No       | Bug in in-scope `_withdrawFrom` |
| known-issues duplication       | No       | "principal NEVER modified" invariant is documented but cross-client mixing is not |
| speculation/future code        | No       | Code is live |
| auto-tool common               | No       | Requires multi-client share-pool reasoning |

### Reasoning
The "authorized withdrawer" is a delegated capability of one client, not a protocol admin. Cross-client theft via that capability is not a "reckless admin mistake" — it is privilege escalation across the client boundary. C4 explicitly carves out privilege escalation as VALID even when it involves a privileged role.

**Verdict: VALID. Submit.**

---

## M-01 — _emergencyWithdraw bypasses delay + skews accounting

**Status: VALID** (with caveat — see below)

### Pattern checks
| Category                       | Detected | Notes |
|--------------------------------|----------|-------|
| non-standard-token             | No       | N/A |
| fee-on-transfer                | No       | N/A |
| approve-race                   | No       | N/A |
| user-mistake                   | No       | N/A |
| admin-mistake                  | **Mixed**| The trigger is owner action; see analysis below |
| out-of-scope                   | No       | Bug in in-scope strategy |
| known-issues duplication       | No       | Not in known issues |
| speculation/future code        | No       | Code is live |
| auto-tool common               | No       | Requires accounting-invariant reasoning |

### User's specific concern: reckless admin mistake?
This is the critical question. Let me split the finding into its two prongs:

**Prong A — "bypasses 24h rugpull delay"**
This prong on its own is a centralization risk. C4 treats "owner has unilateral fund-removal power" as Centralization (QA at best), even if the docs claim a 24h delay. **If the finding were only Prong A, it would be downgraded to QA/Centralization (C-01), not Medium.**

**Prong B — "leaves clientBalances/totalDeposited untouched, producing permanent accounting skew"**
This prong is structural and triggers on **benign, intended owner use** of the emergency path. The owner does not need to be malicious or careless — even an honest emergency-then-restore flow leaves the strategy permanently mis-accounted unless the owner manually re-bookkeeps, and there is no documented re-bookkeeping API. The impact on clients (subsequent withdrawals revert / return wrong amounts) is suffered by honest users with no recourse.

C4 known-invalid pattern: *"Reckless admin mistakes"* → INVALID. But C4 distinguishes between:
- "Admin does an unexpected thing and clients suffer" → INVALID
- "Admin uses an intended function as documented and clients suffer due to a code bug" → VALID Medium (protocol availability impacted)

Prong B is the second case. The finding's own justification correctly identifies this: *"the rugpull-delay-bypass framing alone would be Centralization, but the accounting-skew bug makes this Medium because honest use of the intended emergency path produces broken state for clients afterward."*

**Verdict: VALID as Medium IFF the report leads with Prong B (accounting skew on intended use) and treats Prong A as supporting context, not the primary impact.**

### Recommendation for the report writer
1. Lead with: "Even when the owner uses `_emergencyWithdraw` exactly as intended, the function fails to update `clientBalances` and `totalDeposited`. This breaks subsequent client withdrawals."
2. Make Prong A (delay bypass) a one-paragraph aside, not the headline.
3. If the report leads with "owner can rugpull bypassing the 24h delay," a C4 judge will likely downgrade to QA Centralization.

---

## Cross-finding observations

1. **No findings rely on non-standard / FOT / weird tokens.** All claims are about standard ERC-4626 (sUSDe) and standard ERC-20 (USDe).
2. **No findings rely on user input mistakes or phishing.**
3. **No findings rely on admin malice.** M-01 relies on admin *action* but the impact triggers on benign use.
4. **All bug surface is in `src/` (in-scope), not in `lib/` (parent/forked).** Spot-check confirmed via `files` arrays.
5. **Several findings (H-02, H-04, H-05) cite documented invariants and explicitly note where the documentation does NOT cover the consequence.** This is the right defensive framing — judges will look for it.

## Final recommendation

Submit all 6. The single finding I would flag for re-framing before submission is **M-01**, where the report must lead with the structural accounting-skew prong, not the delay-bypass prong, to avoid being collapsed into Centralization/QA.

---

Files referenced:
- `<repo>/reports/phoenix-vault-04/audit/findings/high/H-01.json`
- `<repo>/reports/phoenix-vault-04/audit/findings/high/H-02.json`
- `<repo>/reports/phoenix-vault-04/audit/findings/high/H-03.json`
- `<repo>/reports/phoenix-vault-04/audit/findings/high/H-04.json`
- `<repo>/reports/phoenix-vault-04/audit/findings/high/H-05.json`
- `<repo>/reports/phoenix-vault-04/audit/findings/medium/M-01.json`
