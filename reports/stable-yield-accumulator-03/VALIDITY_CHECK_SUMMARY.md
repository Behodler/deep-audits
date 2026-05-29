# Validity Check Summary: yield-accumulator-03

**Project**: yield-accumulator (regular audit mode)
**Date**: 2026-02-10

---

## H-01 - Spot price oracle manipulation bypasses targetPrice minimum in claim()

**Status**: **VALID**

| Category | Detected | Result |
|---|---|---|
| Non-standard ERC-20 token | No | PASS |
| Fee-on-transfer token | No | PASS |
| Approve race condition | No | PASS |
| User input mistake | No | PASS |
| Reckless admin mistake | No | PASS |
| Out-of-scope root cause | No | PASS |
| Known issue overlap | No | PASS |
| CryptoPunks | No | PASS |
| Unused view function | No | PASS |
| Future code speculation | No | PASS |

### Detailed Analysis

**Root Cause Location**: `StableYieldAccumulator.sol` lines 731-733, function `_getPhUSDPriceInUSDS()`. Reads `poolManager.getSlot0(pricePoolId)` which returns instantaneous spot price, trivially manipulable within a single transaction.

**Why This Is Not a Known Issue**: The closest known issue is #4: "No oracle or AMM validation (known)". However, these are distinct concerns. Known issue #4 describes the protocol's deliberate design of assuming 1:1 exchange rates for stablecoin normalization without using any oracle or AMM for rate conversion. H-01 identifies that the `targetPrice` check in `claim()` -- which does use an on-chain price source (Uniswap V4 `getSlot0`) -- uses a source that is trivially manipulable via flash swaps in a single atomic transaction.

**Conclusion**: H-01 passes all C4 validity checks. It describes a concrete, well-understood vulnerability pattern (Uniswap spot price manipulation via `getSlot0`), the root cause is in in-scope code, it does not overlap with any listed known issues, and it requires no invalid assumptions about user mistakes, admin behavior, or non-standard tokens.

---

## M-02 - Residual phUSD delta silently dropped in _settleResidualDelta causes ClaimArbitrage DoS

**Status**: **VALID**

| Category | Detected | Result |
|---|---|---|
| Non-standard ERC-20 token | No | PASS |
| Fee-on-transfer token | No | PASS |
| Approve race condition | No | PASS |
| User input mistake | No | PASS |
| Reckless admin mistake | No | PASS |
| Out-of-scope root cause | No | PASS |
| Known issue overlap | No | PASS |
| CryptoPunks | No | PASS |
| Unused view function | No | PASS |
| Future code speculation | No | PASS |

### Detailed Analysis

**Root Cause Location**: `ClaimArbitrage.sol` line 335, function `_settleResidualDelta()`. Silent `return` when token is not `sUSDS` and `stableToUSDCPool[token]` is unconfigured, leaving a non-zero phUSD delta unsettled. The PoolManager's zero-delta invariant then reverts the entire `execute()` transaction.

**Root Cause Verification (Source Code)**:

Lines 320-354 of `<repo>/lib/stable-yield-accumulator/src/ClaimArbitrage.sol`:

```solidity
function _settleResidualDelta(address token) internal {
    int256 d = poolManager.currencyDelta(address(this), Currency.wrap(token));
    if (d >= 0) return;

    PoolKey memory pool = stableToUSDCPool[token];
    if (Currency.unwrap(pool.currency0) == address(0) && Currency.unwrap(pool.currency1) == address(0)) {
        if (token == sUSDS) {
            pool = sUSDS_USDC_pool;
        } else {
            // For phUSD, use phUSD/sUSDS pool with an intermediary step
            // In practice, residual phUSD delta should be negligible after unwind
            return;  // <-- BUG: silently returns without settling
        }
    }
    // ... swap logic to settle the delta ...
}
```

The developer comment on lines 333-334 explicitly acknowledges the gap: *"In practice, residual phUSD delta should be negligible after unwind."* However, "negligible" is not zero, and the PoolManager requires exactly zero delta.

**Why This Is Not an Admin Mistake**:

This is the most important invalid-pattern check for this finding. The finding could superficially appear to involve an admin configuration omission (owner not setting `stableToUSDCPool[phUSD]`). However, this is NOT an admin mistake for the following reasons:

1. The code itself contains a developer comment acknowledging the gap (lines 333-334), proving this is an intentional but flawed design decision, not a missing configuration step.
2. The `stableToUSDCPool` mapping is semantically for external stablecoins (USDT, DAI, etc.) received from `claim()`, not for the protocol's own synthetic stablecoin (phUSD). There is no documentation or code comment suggesting the owner should configure this mapping for phUSD.
3. The code explicitly handles `sUSDS` with a dedicated fallback to `sUSDS_USDC_pool` (line 330-331), showing the developers understood that some tokens need special handling. The gap is that phUSD was not given equivalent treatment.
4. Even if the owner knew to configure the pool, the silent `return` (rather than a `revert`) is independently a code defect that masks the failure.

**Why This Is Not a Known Issue**:

Checked against all 8 known issues:
1. Dual-unpause after adding token -- unrelated
2. Decimal normalization precision loss -- unrelated
3. Circular reference SYA/Phlimbo -- unrelated
4. No oracle or AMM validation -- unrelated (different mechanism)
5. Owner trust (centralization) -- unrelated
6. Pauser trust (centralization) -- unrelated
7. External strategy behavior OOS -- unrelated (root cause is in ClaimArbitrage.sol, not an external strategy)
8. Zero token config defaults -- closest match, but this refers to token configuration defaults in StableYieldAccumulator, not to the `stableToUSDCPool` mapping in ClaimArbitrage. The phUSD delta settlement gap is a logic bug in a specific code path, not a default configuration issue.

**Conclusion**: M-02 passes all C4 validity checks. The finding identifies a genuine logic bug where a silent `return` at line 335 of `ClaimArbitrage.sol` leaves a non-zero phUSD delta unsettled, causing PoolManager to revert. The root cause is in in-scope code. It does not match any C4 known-invalid pattern and does not overlap with any listed known issue. The finding should proceed to submission.

---

## M-01 - ClaimArbitrage fails when SYA distributes tokens not in knownStables -- tokens permanently locked

**Status**: **VALID**

| Category | Detected | Result |
|---|---|---|
| Non-standard ERC-20 token | No | PASS |
| Fee-on-transfer token | No | PASS |
| Approve race condition | No | PASS |
| User input mistake | No | PASS |
| Reckless admin mistake | No | PASS |
| Out-of-scope root cause | No | PASS |
| Known issue overlap | No | PASS |
| CryptoPunks | No | PASS |
| Unused view function | No | PASS |
| Future code speculation | No | PASS |

### Detailed Analysis

**Root Cause Location**: `ClaimArbitrage.sol` lines 195-217, function `unlockCallback()` Step 5 loop. The loop only iterates `knownStables[]` when converting received stablecoins to USDC. Tokens distributed by `SYA.claim()` that are not in `knownStables[]` are silently skipped and permanently locked in the contract, as no rescue or sweep function exists.

**Root Cause Verification (Source Code)**:

Lines 195-217 of `<repo>/lib/stable-yield-accumulator/src/ClaimArbitrage.sol`:

```solidity
// STEP 5: CONVERT RECEIVED STABLECOINS -> USDC
for (uint256 i = 0; i < knownStables.length; i++) {
    address stable = knownStables[i];
    uint256 bal = IERC20(stable).balanceOf(address(this));
    if (bal == 0) continue;

    _depositIntoPM(stable, bal);

    PoolKey memory pool = stableToUSDCPool[stable];
    bool stableIsToken0 = (Currency.unwrap(pool.currency0) == stable);
    poolManager.swap(
        pool,
        SwapParams({
            zeroForOne: stableIsToken0,
            amountSpecified: -int256(bal),
            sqrtPriceLimitX96: stableIsToken0
                ? type(uint160).min + 1
                : type(uint160).max - 1
        }),
        ""
    );
}
```

The loop is bounded by `knownStables.length` and only checks `balanceOf` for addresses in that array. Any ERC-20 token in the contract's balance that is not in `knownStables[]` is never touched.

**Why This Is Not an Admin Mistake**:

This is the most important invalid-pattern check for this finding. The finding describes two scenarios:

1. **Scenario 1 (Desynchronization):** SYA owner adds a yield strategy; CA owner does not add the corresponding `knownStable`. While this could superficially appear as an admin oversight, the two contracts may have **different owners**, and adding a yield strategy is a normal, expected operation -- not reckless behavior. The architectural flaw is the absence of any on-chain enforcement linking the two registries.

2. **Scenario 2 (Timing gap):** Even with perfectly diligent admins, there is an **inherent multi-block window** between the SYA `addYieldStrategy()` transaction (block N) and the CA `addKnownStable()` transaction (block N+k). Since `execute()` is permissionless and explicitly designed for MEV bots, calls during this window are expected. This is NOT an admin mistake -- it is an unavoidable architectural race condition.

Scenario 2 alone makes this a valid finding regardless of any admin behavior.

**Why This Is Not a Known Issue**:

Checked against all 8 known issues:
1. Dual-unpause after adding token -- concerns pause/unpause mechanics, not registry synchronization
2. Decimal normalization precision loss -- concerns decimal math, not token locking
3. Circular reference SYA/Phlimbo -- concerns SYA-Phlimbo relationship, not SYA-CA registry sync
4. No oracle or AMM validation -- concerns exchange rate assumptions, not cross-contract registry sync
5. Owner trust (centralization) -- this finding is NOT about owner power abuse but a missing synchronization mechanism
6. Pauser trust (centralization) -- unrelated to pauser functionality
7. External strategy behavior OOS -- root cause is in `ClaimArbitrage.sol` Step 5 loop (in-scope), not external strategies
8. Zero token config defaults -- refers to SYA token configuration, not CA's `knownStables[]` registry

**Code Verification**: All claims in the submission were verified against source code:
- Step 5 loop only iterates `knownStables[]` (confirmed, lines 195-217)
- No rescue/sweep function exists (confirmed, all external functions reviewed)
- SYA `claim()` distributes tokens from all strategies to `msg.sender` (confirmed, line 594)
- `execute()` is permissionless (confirmed, line 122, no access control)
- SYA and CA maintain independent unsynchronized registries (confirmed)

**Conclusion**: M-01 passes all C4 validity checks. It describes a concrete cross-contract registry desynchronization vulnerability where tokens can be permanently locked in `ClaimArbitrage` due to the absence of any on-chain enforcement linking SYA's yield strategy registry to CA's `knownStables[]` array. The timing gap scenario demonstrates that this vulnerability exists even with perfectly diligent administration. The root cause is in in-scope code, it does not overlap with any listed known issues, and it requires no invalid assumptions about user mistakes, admin behavior, or non-standard tokens. The finding should proceed to submission.
