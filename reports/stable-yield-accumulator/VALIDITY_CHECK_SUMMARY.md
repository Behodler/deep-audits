# Validity Check Summary - stable-yield-accumulator

**Date**: 2026-03-19
**Findings Checked**: 2
**Valid**: 2 | **Invalid**: 0

---

## M-01: Inverted Slippage Protection -- VALID (PASS)

**Finding**: The `claim()` function's `minRewardTokenSupplied` parameter enforces a floor on payment, not a ceiling. Claimer cannot protect against overpaying if owner changes discount rate between off-chain calculation and on-chain execution.

### Invalid Pattern Checks

| Pattern | Detected | Reasoning |
|---------|----------|-----------|
| Non-standard token | No | Not a token standards issue |
| Fee-on-transfer | No | Not a FOT issue |
| Approve race | No | Not an approval issue |
| User mistake | **No** | The bug is the direction of the comparison (`<` instead of `>`). No user input value can fix a check that protects in the wrong direction. The user is not making a mistake -- the code is broken. |
| Admin mistake | **No** | The owner changing the discount rate is normal, expected administrative behavior (the function exists for this purpose). The root cause is the inverted slippage check at line 460, not admin misbehavior. Even without any admin action, the slippage parameter fundamentally cannot protect against overpaying. |
| Out of scope | No | Root cause is in `StableYieldAccumulator.claim()` at line 460 |
| Speculative | **No** | The inverted comparison `if (actualPayment < minRewardTokenSupplied)` is plainly visible in the current code. No hypothetical future state is required. |

### Key Distinction: Code Bug vs Admin Mistake

The "reckless admin mistake" pattern applies when the finding requires the admin to act irresponsibly or maliciously. Here, the admin changing the discount rate is a legitimate, intended operation. The vulnerability exists because the code's slippage protection mechanism is directionally wrong -- it reverts when payment is too LOW (protecting the protocol from getting too little) rather than when payment is too HIGH (protecting the claimer from overpaying). This is a logic error in the contract, not an assumption about admin behavior.

---

## M-02: All-or-Nothing Claim DoS via Broken Strategy -- VALID (PASS)

**Finding**: If any registered strategy's `withdrawFrom` reverts, the entire `claim()` reverts, blocking all yield claims across all strategies.

### Invalid Pattern Checks

| Pattern | Detected | Reasoning |
|---------|----------|-----------|
| Non-standard token | No | Not a token standards issue |
| Fee-on-transfer | No | Not a FOT issue |
| Approve race | No | Not an approval issue |
| User mistake | No | Not a user input issue |
| Admin mistake | No | Not about admin misbehavior |
| Out of scope | **No** | The root cause is the lack of error handling in the in-scope `claim()` function (lines 434-451). The vulnerability is in how `StableYieldAccumulator` handles external call failures, not in the external strategies themselves. |
| Speculative | **No** | Strategy reverts are a standard operational risk. The contract itself demonstrates awareness of strategy-level issues by implementing `tokenConfigs[token].paused` functionality at line 439. A strategy can revert for many non-speculative reasons: being paused, running out of liquidity, being upgraded, having a bug, or encountering an unexpected state. |

### Key Distinction: In-Scope Root Cause vs External Behavior

The "out of scope" pattern applies when the root cause is in external/OOS code. Here, the root cause is the absence of try/catch or error isolation in the in-scope `claim()` loop. The fix belongs in `StableYieldAccumulator`, not in the external strategies. The external strategies reverting is the trigger, but the vulnerability is the lack of graceful degradation in the in-scope contract.

### Key Distinction: Operational Risk vs Speculation

A "speculative" finding requires hypothetical future code changes or conditions that may never occur. Strategy reverts are not speculative -- they are a well-understood operational risk that any protocol integrating with external contracts must handle. The protocol's own `pauseToken` mechanism acknowledges that strategies can become unavailable.

---

## Conclusion

Both findings pass the validity check. Neither matches any C4 known-invalid pattern. Both have clearly identifiable root causes in the in-scope `StableYieldAccumulator.sol` contract, and neither relies on speculative conditions, user errors, or reckless admin behavior.
