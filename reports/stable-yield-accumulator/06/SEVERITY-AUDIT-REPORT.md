# Severity Audit Report: stable-yield-accumulator-06

**Date:** 2026-02-13
**Auditor:** severity-auditor
**Findings Reviewed:** 3 Medium (M-01, M-02, M-03)

## Executive Summary

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| M-01    | Medium  | **Low**  | DISAGREE  | High       |
| M-02    | Medium  | Medium   | AGREE     | High       |
| M-03    | Medium  | **Low**  | DISAGREE  | Medium     |

**Result:** 2 of 3 findings are overstated. Only M-02 is correctly classified as Medium. M-01 and M-03 should be downgraded to Low/QA.

---

## M-01: Denormalization Truncation to Zero Allows Free Yield Extraction

**Claimed:** Medium | **Assessed:** Low/QA | **Confidence:** High

### Independent Analysis

**Root cause verified:** The `_denormalizeAmount()` function at line 704 of `StableYieldAccumulator.sol` divides by `10^(18 - decimals)`. For USDC (6 decimals), this divides by `10^12`. If the pre-division value is less than `10^12`, the result truncates to zero. The code path is real -- `safeTransferFrom(claimer, SYA, 0)` succeeds silently, and yield was already withdrawn to the claimer at line 594.

**Why this is overstated:**

1. **Per-instance value is sub-dust.** The submission itself acknowledges each free extraction is worth less than 0.000001 USDC ($0.000001). Even the "boundary analysis" showing 2 units yielding a payment of 1 instead of ~1.96 involves amounts of $0.000002. These are not economically meaningful.

2. **Accumulation argument fails.** The submission claims "systematic rounding bias compounds over thousands of claims." One thousand claims at $0.000001 each yields $0.001 total. Even one million claims totals $1. The gas cost to execute one million claim transactions -- even on the cheapest L2 -- far exceeds $1.

3. **Prior classification as Low.** This exact root cause (`_denormalizeAmount` truncation for low-decimal tokens) was identified in `stable-yield-accumulator-01` as finding `L-01` ("Precision Loss in Decimal Normalization Round Trip") with severity Low. The prior finding's assessment: "Dust amounts are lost per claim transaction. The impact is systematic but negligible in practice -- each claim loses at most 1 unit of the smallest decimal representation." The current submission attempts to escalate by framing zero payment as qualitatively different from dust payment, but the economic reality is the same.

4. **C4 Medium criteria not met.** Medium requires "protocol function/availability impacted, or value leak with stated assumptions and external requirements." A value leak measured in millionths of a cent per instance does not constitute a meaningful value leak. The protocol functions correctly for all economically significant yield amounts.

**What IS valid:** The observation that there is no `actualPayment == 0` revert guard is a genuine code quality issue. Ceiling division in `_denormalizeAmount` is sound engineering advice. These belong in a QA report.

**Recommendation:** Downgrade to Low/QA.

---

## M-02: Positive Residual Deltas Stranded in ClaimArbitrage Contract

**Claimed:** Medium | **Assessed:** Medium | **Confidence:** High

### Independent Analysis

**Root cause verified:** At lines 372-378 of `ClaimArbitrage.sol`, when `_settleResidualDelta()` encounters a positive delta (credit owed by PoolManager to the contract), it calls `poolManager.take()` to materialize real tokens, then immediately returns. These tokens remain as ERC-20 balances in the ClaimArbitrage contract. They are never deposited back into PoolManager, never swapped to the reward token, and never included in the Step 7 profit conversion to WETH. Recovery requires the owner to manually call `rescueToken()`.

**Why Medium is correct:**

1. **Asymmetric accounting is a protocol function defect.** Negative residual deltas (costs) are correctly handled -- the function swaps to purchase the owed tokens and zeros the debt. But positive residual deltas (gains) are silently dropped from the profit pipeline. This creates a one-directional bias against arbitrage callers that is not documented as intended behavior.

2. **Value leak is systematic and unconditional.** Positive residual deltas arise naturally from AMM price impact asymmetry during the pump/unwind cycle. No special conditions or attacker action are required. Every execution where the unwind returns slightly more than the pump consumed leaks value.

3. **Second-order impact on protocol economics.** Reduced profitability for MEV bots means fewer bots compete to call `execute()`, which can slow yield distribution to Phlimbo stakers. This is a protocol availability concern.

4. **No direct asset theft.** Tokens are not stolen -- they sit in the contract and can be recovered by the owner via `rescueToken()`. But the centralized recovery path and the systematic nature of the leak justify Medium over High.

5. **Attack path has no hypotheticals.** The delta mechanics are well-understood, the code path is clear, and the impact is deterministic.

**Recommendation:** Severity is correctly classified. Keep as Medium.

---

## M-03: Raw approve() Blocks USDT-Like Reward Tokens

**Claimed:** Medium | **Assessed:** Low/QA | **Confidence:** Medium

### Independent Analysis

**Root cause verified:** At line 184 of `ClaimArbitrage.sol` and line 482 of `StableYieldAccumulator.sol`, raw `IERC20.approve()` is used instead of `SafeERC20.forceApprove()`. Both contracts import SafeERC20 and declare `using SafeERC20 for IERC20`, yet these two approve calls use the raw interface. For USDT (which reverts on non-zero-to-non-zero allowance changes), the second call to either function will permanently revert.

**Why this is overstated:**

1. **Triggering condition requires specific owner configuration.** The reward token is set by the owner via `setRewardToken()`. All protocol documentation, code comments, and examples reference USDC as the reward token. USDT would need to be explicitly configured as the reward token by the owner -- a deliberate configuration choice, not an automatic condition.

2. **USDT as strategy token vs. reward token.** The source code comment at line 119 mentions "USDC, USDT, DAI" as strategy tokens (tokens yielded to claimers). The approve issue only triggers when USDT is the REWARD token (the token claimers pay WITH). These are different roles. USDT as a strategy token does not trigger this bug.

3. **C4 known-invalid adjacency.** C4 rules list "Approve race condition / safeApprove front-running" as a known invalid finding. While this is not exactly the same pattern (this is about USDT's non-standard revert, not a front-running race), the underlying issue -- raw approve vs. safe approve patterns -- is closely related. The C4 USDT exception applies to non-standard token behavior generally, but the finding's core recommendation (use forceApprove instead of approve) is fundamentally a code quality / best-practice concern.

4. **Recovery path exists.** If the owner configures USDT and encounters this issue, they can switch the reward token back to USDC via `setRewardToken()`. The ClaimArbitrage contract would need redeployment, but the SYA contract itself is not permanently bricked since `approvePhlimbo()` is an owner function that can simply be called after resetting allowance.

5. **The impact depends on an owner mistake.** Setting USDT as reward token when the code was designed and tested with USDC is an admin configuration error. C4 known-invalid findings include "Reckless admin mistakes."

**What IS valid:** The inconsistency of importing SafeERC20 and using it for `safeTransfer`/`safeTransferFrom` but not for `approve` is a genuine code quality issue. The fix (replace with `forceApprove()`) is trivial and correct. This belongs in a QA report.

**Counterargument for keeping as Medium:** If one argues that the protocol is designed to support arbitrary reward tokens (the `setRewardToken()` function exists for this purpose), and USDT is the most common non-standard token, then a permanent DoS on second execution is a real availability impact. This argument has some merit, which is why my confidence is Medium rather than High.

**Recommendation:** Lean toward downgrade to Low/QA, but this is a borderline case. The strongest version of this finding would need to establish that USDT as reward token is a realistic production configuration, not just a theoretical possibility.

---

## Summary of Recommendations

| Finding | Action | Rationale |
|---------|--------|-----------|
| M-01    | **Downgrade to Low/QA** | Sub-dust economic impact ($0.000001 per instance). Same root cause was previously classified as L-01. Rounding/precision issue belongs in QA report. |
| M-02    | **Keep as Medium** | Systematic value leak with asymmetric accounting. No conditions required. Protocol function genuinely impacted. |
| M-03    | **Downgrade to Low/QA** | Requires owner to configure USDT as reward token (not the documented default). Adjacent to C4 known-invalid approve patterns. Code quality issue, not a security vulnerability under normal configuration. |

## Files Referenced

- **M-01 Finding:** `<repo>/reports/stable-yield-accumulator/06/audit/findings/medium/M-01.json`
- **M-01 Submission:** `<repo>/reports/stable-yield-accumulator/06/audit/submissions/M-01-submission.md`
- **M-02 Finding:** `<repo>/reports/stable-yield-accumulator/06/audit/findings/medium/M-02.json`
- **M-02 Submission:** `<repo>/reports/stable-yield-accumulator/06/audit/submissions/M-02-submission.md`
- **M-03 Finding:** `<repo>/reports/stable-yield-accumulator/06/audit/findings/medium/M-03.json`
- **M-03 Submission:** `<repo>/reports/stable-yield-accumulator/06/audit/submissions/M-03-submission.md`
- **Source (SYA):** `<repo>/lib/stable-yield-accumulator/src/StableYieldAccumulator.sol`
- **Source (CA):** `<repo>/lib/stable-yield-accumulator/src/ClaimArbitrage.sol`
- **Prior L-01:** `<repo>/reports/stable-yield-accumulator/01/audit/findings/low/L-01-precision-loss-decimal-normalization.json`
