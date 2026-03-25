# Validity Check Summary: yield-claim-nft

**Date:** 2026-03-19
**Total Findings Checked:** 8
**Valid:** 2 | **Invalid:** 4 | **Borderline:** 2

## Token Context

The project README is a default Foundry template with no token restrictions. The only explicitly mentioned token is **sUSDS** (referenced in BalancerPooler NatSpec). The code explicitly handles FOT tokens via balance-before/after patterns and includes a `MockFOTToken.sol` test mock. SafeERC20 is NOT used.

---

## Results

### DEDUP-001: Missing SafeERC20 -- BORDERLINE

**Category:** Non-standard token assumption

The finding relies on tokens that return `false` instead of reverting. sUSDS (the identified prime token) is a standard ERC-20 that reverts on failure. If the finding applies only to tokens with non-standard return values, it is INVALID per C4 rules. However, the protocol is generic enough that non-standard tokens could be registered. Needs human judgment on whether the protocol's token set is restricted.

---

### DEDUP-002: No actualReceived > 0 check -- INVALID

**Category:** Defense-in-depth / Non-standard token assumption

Self-described as "defense-in-depth" and tied to DEDUP-001. Defense-in-depth findings without a demonstrated exploit path are QA at best under C4 rules. No standalone vulnerability.

---

### DEDUP-003: FOT bonding curve divergence -- BORDERLINE

**Category:** Fee-on-transfer token

Normally FOT findings are INVALID per C4. **However**, this project explicitly handles FOT tokens:
- NFTMinter.sol line 179 comment: "balance-before/after for FOT safety"
- Dispatcher NatSpec references "FOT-adjusted amount"
- `MockFOTToken.sol` exists in tests

This strongly suggests FOT tokens are in scope by design. The C4 exclusion applies when FOT tokens are NOT in scope. If the finding demonstrates that the FOT handling is actually insufficient (e.g., bonding curve price grows based on the full `price` amount while only `actualReceived` is dispatched), this could be VALID. Needs confirmation on whether FOT tokens are explicitly in scope for this audit.

---

### DEDUP-004: BurnRecorder accounting divergence -- INVALID

**Category:** Non-standard token assumption

The finding relies on a token's `burn()` function not actually burning the full amount. BurnRecorder records whatever amount it is told. If the underlying token's burn behavior is non-standard, that falls under the C4 non-standard token exclusion.

---

### DEDUP-005: Missing slippage protection -- VALID

**Category:** No invalid patterns detected

Two legitimate concerns:
1. **Mint price front-running:** Price grows after each mint (line 186). Users can be sandwiched to pay a higher price than expected. No max-price parameter exists.
2. **BalancerPooler zero slippage default:** When `extraData` is empty, `minBptAmountOut` defaults to 0 (line 48), enabling sandwich attacks on the Balancer liquidity addition.

Both are standard DeFi slippage/MEV concerns with no C4 exclusion.

---

### DEDUP-006: Authorized burner burns without holder consent -- INVALID

**Category:** Admin/centralization risk

The `burn()` function (line 298) requires `authorizedBurners[msg.sender]`, set by owner. This is the intended design -- the owner explicitly authorizes burner addresses. Per C4 rules, findings requiring trusted roles to act maliciously are INVALID. No privilege escalation is involved. At best a QA centralization observation (C-xx).

---

### DEDUP-007: Price growth truncation for small prices -- VALID

**Category:** No invalid patterns detected

The growth formula `price + (price * growthBasisPoints) / 10000` truncates to zero growth when `price * growthBasisPoints < 10000`. Example: price=99 wei, growthBasisPoints=100 results in 99*100/10000=0 growth. This is a legitimate arithmetic issue in the core pricing mechanism. The price would remain flat forever instead of growing as intended.

---

### DEDUP-008: Owner can set price to zero -- INVALID

**Category:** Reckless admin mistake

`setPrice()` is `onlyOwner` with no minimum value check. Setting price to zero requires the trusted owner to act recklessly. Per C4 rules, reckless admin mistakes are INVALID. The owner has full pricing authority by design.

---

## Recommendations

| Finding | Verdict | Action |
|---------|---------|--------|
| DEDUP-001 | BORDERLINE | Needs scope clarification on supported tokens |
| DEDUP-002 | INVALID | Remove -- defense-in-depth, not a vulnerability |
| DEDUP-003 | BORDERLINE | Likely VALID given explicit FOT handling in code; confirm scope |
| DEDUP-004 | INVALID | Remove -- non-standard token assumption |
| DEDUP-005 | VALID | Keep -- legitimate slippage/MEV concern |
| DEDUP-006 | INVALID | Downgrade to QA centralization risk at most |
| DEDUP-007 | VALID | Keep -- arithmetic issue in core pricing |
| DEDUP-008 | INVALID | Remove -- reckless admin assumption |
