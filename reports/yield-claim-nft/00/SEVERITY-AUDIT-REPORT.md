# Severity Audit Report: yield-claim-nft Deduplicated Findings

**Date**: 2026-03-19
**Audit Type**: Regular C4 (not bounty)
**Auditor Role**: Severity Auditor (independent second opinion)

---

## Executive Summary

Reviewed 8 deduplicated findings. **4 disagreements identified**, all involving overstatement of severity. Key actions:

| Finding | Claimed | Assessed | Action |
|---------|---------|----------|--------|
| DEDUP-001 | High | **Medium** | Downgrade - external conditions required |
| DEDUP-002 | High | **Low** | Downgrade + merge with DEDUP-001 |
| DEDUP-003 | Medium | **Rejected** | C4 known invalid (FOT tokens) |
| DEDUP-004 | Medium | **Low** | Downgrade - FOT-dependent, no security impact |
| DEDUP-005 | Medium | Medium | Agree |
| DEDUP-006 | Medium | **Low** | Downgrade - centralization risk |
| DEDUP-007 | Low | Low | Agree |
| DEDUP-008 | Low | Low | Agree |

**Net valid findings after audit**: 1 Medium (merged DEDUP-001/002), 1 Medium (DEDUP-005), 4 Low/QA, 1 Rejected.

---

## Detailed Assessments

### DEDUP-001 [Claimed: High -> Assessed: Medium]
**Unchecked ERC20 Transfer Return Values**

**Disagreement: Downgrade to Medium.**

The finding correctly identifies that `IERC20.transfer()` and `transferFrom()` return values are unchecked and SafeERC20 is not used. However, the claimed High severity requires "assets can be stolen/lost/compromised directly or via valid attack path without hypotheticals."

**Why this is not High:**

1. **External condition required**: Exploitation requires a non-standard ERC20 token that returns `false` instead of reverting on failure. Standard tokens (OpenZeppelin ERC20, USDC, USDT, DAI, WETH) either revert or return true on failure. The admin must register a dispatcher for such a non-standard token.

2. **Balance-before/after mitigation**: The code at lines 180-182 already uses a balance-before/after pattern:
   ```
   uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);
   IERC20(token).transferFrom(msg.sender, config.dispatcher, price);
   uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;
   ```
   If `transferFrom` returns false without transferring, `actualReceived` = 0, and `dispatch()` is called with amount = 0. No tokens are actually stolen from the protocol.

3. **Owner-only locations**: `emergencyWithdraw` (line 259) and `withdrawBPT` (line 93) are owner-only. The trust assumption already exists.

4. **Gather.dispatch** (line 61): Transfers tokens the contract already holds. If the token returns false, the Gather contract retains the tokens -- no loss to the protocol.

Per C4: "value leak with stated assumptions and external requirements" = Medium.

---

### DEDUP-002 [Claimed: High -> Assessed: Low, Merge with DEDUP-001]
**No actualReceived > 0 Check**

**Disagreement: Downgrade to Low and merge with DEDUP-001.**

This finding describes the consequence of DEDUP-001, not an independent vulnerability. The "zero-value mint" attack:

1. **Same root cause**: Only possible if `transferFrom` returns false without reverting (DEDUP-001's condition).
2. **No intrinsic asset risk**: The minted ERC1155 claim NFT has no on-chain redeemable value within the protocol's contracts. There is no redemption/payout mechanism in the audited code. The NFT's value is entirely external.
3. **Not independently exploitable**: Remove DEDUP-001 (add SafeERC20), and DEDUP-002 disappears entirely.

**Merge recommendation**: These share the same root cause and should be submitted as a single finding. The merged finding would be Medium severity: "Unchecked ERC20 return values allow zero-cost NFT minting with non-standard tokens."

---

### DEDUP-003 [Claimed: Medium -> Assessed: REJECTED]
**FOT Bonding Curve Divergence**

**Disagreement: Reject per C4 known invalid findings list.**

C4 explicitly lists "Fee-on-transfer tokens (unless explicitly in scope)" as a known invalid finding. This finding describes behavior specific to FOT tokens.

Additionally, the code demonstrates design awareness of FOT tokens:
- `MockFOTToken.sol` exists in the test suite
- Tests explicitly verify FOT behavior (lines 802-868)
- The balance-before/after pattern is specifically for FOT safety (comment on line 179)
- The price formula on line 186 intentionally uses stored `price`, not `actualReceived`

The divergence between nominal price and actual received is a known design tradeoff, not a bug.

---

### DEDUP-004 [Claimed: Medium -> Assessed: Low]
**BurnRecorder Accounting Divergence**

**Disagreement: Downgrade to Low/QA.**

1. **FOT-dependent**: The accounting divergence only occurs with fee-on-transfer tokens (C4 known invalid). For standard burnable tokens, `IBurnable.burn(amount)` and `_burnRecorder.burn(_token, amount)` on lines 40-41 of Burner.sol receive the same `amount` value.

2. **No security impact**: `BurnRecorder` is a pure accounting/event-logging contract. `getTotalBurnt()` is a view function. The recorded values are not used in any access control, fund distribution, or state-changing logic within the audited contracts.

3. **No asset risk**: Even if the accounting is inaccurate, no funds can be stolen, locked, or misdirected as a result.

This is a state-handling observation with no security consequence -- QA/Low by C4 criteria.

---

### DEDUP-005 [Claimed: Medium -> Assessed: Medium]
**Missing Slippage Protection**

**Agreement: Confirmed Medium.**

Both sub-findings are valid:

**Sub-finding 1 - No maxPrice on mint()**: The `mint()` function (lines 154-161) accepts no maximum price parameter. With `growthBasisPoints > 0`, a front-runner can mint first to grow the price, causing the victim to pay more. Impact is bounded by the growth rate (typically 1-2% per front-run).

**Sub-finding 2 - BalancerPooler minBptAmountOut=0 default**: Line 48 of BalancerPooler.sol defaults to `minBptAmountOut = 0` when `extraData` is empty. This enables sandwich attacks on the Balancer liquidity addition. This is the stronger sub-finding as the potential loss is unbounded by the contract's parameters.

Both meet Medium criteria: "protocol function impacted" and "value leak with stated assumptions" (MEV conditions on Ethereum mainnet).

**Note**: These could be argued as two separate Medium findings since they affect different contracts with different attack surfaces.

---

### DEDUP-006 [Claimed: Medium -> Assessed: Low]
**Authorized Burner Burns Without Holder Consent**

**Disagreement: Downgrade to Low/QA (centralization risk).**

C4 explicitly classifies centralization risks as QA at best.

The `burn()` function (line 298) allows `authorizedBurners` to burn any holder's NFTs. This is by design:
- The owner explicitly authorizes burner addresses via `setAuthorizedBurner()` (line 289)
- The intended use case is a redemption/claim contract that burns NFTs as part of processing claims
- Requiring `isApprovedForAll` would break the redemption pattern
- ERC1155's internal `_burn()` does not check approval -- this is standard OpenZeppelin behavior

The "risk" is that the owner could authorize a malicious burner. This is an admin trust assumption, not a protocol vulnerability.

---

### DEDUP-007 [Claimed: Low -> Assessed: Low]
**Price Growth Truncation**

**Agreement: Confirmed Low/QA.**

Integer division truncation in `(price * config.growthBasisPoints) / 10000` rounds to zero when `price * growthBasisPoints < 10000`. Since prices are expected to be in 18-decimal token units (comment on line 19: "price in token units (18 decimals)"), this requires prices below 1e-14 tokens -- not a realistic scenario. Owner can fix via `setPrice()`.

---

### DEDUP-008 [Claimed: Low -> Assessed: Low]
**Owner Can Set Price to Zero**

**Agreement: Confirmed Low/QA.**

`setPrice()` (line 239) has no minimum enforcement. The owner could set price to 0, enabling free minting. This is an admin configuration issue. The owner is trusted and zero-price minting could be intentional (promotional campaigns). Standard centralization/admin-trust QA finding.

---

## Merge Recommendations

| Merge Group | Findings | Merged Severity | Rationale |
|-------------|----------|-----------------|-----------|
| Group 1 | DEDUP-001 + DEDUP-002 | Medium | Same root cause: unchecked ERC20 return values. DEDUP-002 is the consequence, not an independent finding. |

---

## Rejection List

| Finding | Reason |
|---------|--------|
| DEDUP-003 | C4 known invalid: fee-on-transfer token finding. Not explicitly in scope. Design intent confirmed by test suite. |

---

## Final Severity Distribution

After applying all recommended changes:

| Severity | Count | Findings |
|----------|-------|----------|
| High | 0 | -- |
| Medium | 2 | DEDUP-001/002 (merged), DEDUP-005 |
| Low/QA | 4 | DEDUP-004, DEDUP-006, DEDUP-007, DEDUP-008 |
| Rejected | 1 | DEDUP-003 |
