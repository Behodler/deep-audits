# Validity Check Summary -- yield-accumulator-06

**Date**: 2026-02-13
**Findings Checked**: 3
**Result**: 2 VALID, 1 INVALID

---

## M-01: INVALID

**Title**: Denormalization truncation to zero allows free yield extraction with low-decimal reward tokens

**Root Cause**: Integer division truncation in `_denormalizeAmount()` at `StableYieldAccumulator.sol:704`

**Invalid Reason**: Known Issue Overlap

The finding's root cause -- integer division truncation during denormalization of 6-decimal tokens -- is the same mechanism documented in known issue #2: "Decimal normalization precision loss (documented design choice)." The finding acknowledges a prior L-01 identified dust-level truncation and argues that truncation to exactly zero is a "qualitative escalation." However:

- The root cause is identical: `scaled / (10 ** (18 - decimals))` at line 704 performs integer division that truncates.
- Truncation to zero is the boundary condition of the same precision loss, not a distinct vulnerability class.
- The project explicitly documented this as a "design choice," which inherently accepts the full range of truncation outcomes including zero.
- An attacker deliberately targeting small amounts where truncation reaches zero is exploiting the known precision loss, not a separate bug.

**Recommendation**: Remove from submission. If the warden believes the zero boundary is categorically different, they should argue this explicitly in the submission and accept the risk of judge disagreement.

---

## M-02: VALID

**Title**: ClaimArbitrage positive residual deltas stranded in contract instead of contributing to caller profit

**Root Cause**: `ClaimArbitrage.sol:372-378` -- `_settleResidualDelta()` takes tokens from PoolManager to the contract but does not route them to the caller or convert them to profit.

**Validity Checks Passed**:
- Not a non-standard token issue
- Not a fee-on-transfer issue
- Not an approve race condition
- Not a user mistake
- Not an admin mistake
- Root cause is in-scope (ClaimArbitrage.sol)
- Does not match any of the 8 known issues
- Concrete attack path, not speculation

**Caveats**: The code comments at lines 373-376 acknowledge that tokens "remain in the contract and can be used in subsequent operations or rescued via rescueToken()." This developer awareness may affect severity assessment (potentially QA rather than Medium) but does not invalidate the finding per C4 rules. The severity question should be addressed separately.

---

## M-03: VALID

**Title**: Raw approve() call in ClaimArbitrage permanently blocks execution for USDT-like reward tokens

**Root Cause**: `ClaimArbitrage.sol:184` and `StableYieldAccumulator.sol:482` use raw `IERC20.approve()` instead of `SafeERC20.forceApprove()`.

**Validity Checks Passed**:
- USDT is the explicit C4 exception to the non-standard token rule -- USDT findings are VALID
- This is NOT the approve race condition (which is about front-running between approve/transferFrom). This is about USDT's requirement that existing allowance be zero before setting a new non-zero value.
- Not a user mistake or admin mistake (setting USDT as reward token is reasonable)
- Root causes are in-scope
- Does not match any known issues (known issue #5 "front-running of setRewardToken" is a different vector)
- Concrete attack path: first execution succeeds, second reverts permanently

**Key Evidence**: Both contracts import SafeERC20 (`using SafeERC20 for IERC20;`) but use raw `approve()` at the affected lines, confirming this is a code defect rather than intentional design.

---

## Summary Table

| Finding | Status  | Reason                                              |
|---------|---------|-----------------------------------------------------|
| M-01    | INVALID | Overlaps with known issue #2 (precision loss)       |
| M-02    | VALID   | No invalid patterns (note: severity may be debated) |
| M-03    | VALID   | USDT exception applies; genuine code defect         |
