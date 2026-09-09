# Severity Audit Report: yield-claim-NFT (Round 2)

**Project:** yield-claim-NFT
**Audit Type:** Regular C4 Audit -- Second-Opinion Severity Validation
**Date:** 2026-03-03
**Auditor Role:** severity-auditor (independent reviewer)
**Code Version:** Current (post-refactor: UNBALANCED addLiquidity, onlyMinter access control)

---

## Executive Summary

This report provides an independent severity assessment of the 2 Medium findings and 9 Low/QA findings submitted for the yield-claim-NFT project (Round 2). The code has been substantially refactored since Round 1: the BalancerPooler now uses `UNBALANCED` addLiquidity instead of `DONATION`, dispatchers have `onlyMinter` access control, and tokens arrive on dispatchers via direct transfer rather than `transferFrom`.

**Key findings from this audit:**
- M-01 (zero slippage): Recommend DOWNGRADE to Low/QA
- M-02 (1:1 phUSD with UNBALANCED): Recommend DOWNGRADE to Low/QA
- No Low findings merit upgrade to Medium
- QA findings are appropriately classified

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| M-01    | Medium  | Low      | No        | High       |
| M-02    | Medium  | Low      | No        | High       |
| L-01    | Low     | Low      | Yes       | High       |
| L-02    | Low     | Low      | Yes       | High       |
| L-03    | Low     | Low      | Yes       | High       |
| L-04    | Low     | Low      | Yes       | High       |
| L-05    | Low     | Low      | Yes       | High       |
| L-06    | Low     | Low      | Yes       | High       |
| L-07    | Low     | Low      | Yes       | High       |
| L-08    | Low     | Low      | Yes       | High       |
| C-01    | Centralization | Centralization | Yes | High |

---

## Detailed Medium Finding Analysis

### M-01: Default zero slippage on BalancerPooler enables sandwich attacks

**Claimed Severity:** Medium
**Assessed Severity:** Low (QA)
**Agreement:** NO
**Confidence:** High

#### Independent Analysis

**Code Verification:** The finding accurately describes the code. Line 66 of `BalancerPooler.sol` defaults `minBptAmountOut` to 0 when `extraData` is empty:

```solidity
uint256 minBptAmountOut = extraData.length > 0 ? abi.decode(extraData, (uint256)) : 0;
```

The 3-parameter `mint()` in `NFTMinter.sol` (line 116-118) always passes empty `extraData`:

```solidity
function mint(address token, uint256 index, address recipient) external returns (bool) {
    return _executeMint(token, index, recipient, "");
}
```

**However, the severity assessment is overstated for the following reasons:**

**1. Slippage protection IS available.** The 4-parameter `mint()` overload (line 121-123) explicitly accepts `extraData` for slippage control. The interface (`ITokenMinter.sol` line 16) documents this parameter as "Dispatcher-specific encoded data (e.g. slippage parameters)." This is not a hidden or undocumented feature -- it is a first-class interface method on the same contract.

**2. The 3-parameter overload is a convenience function, not the only entry point.** Both overloads are equally accessible via the `ITokenMinter` interface. The claim that "the simpler overload is the default entry point" is an assumption, not a code-level fact. Any frontend or integrating contract can call either overload. The existence of a safe path that is equally accessible significantly reduces severity.

**3. Who bears the risk?** BPT goes to `address(this)` -- the BalancerPooler contract itself (line 98). The user minting the NFT does NOT receive BPT. The user receives a claim NFT. The user's economic exposure is the price they paid, and they always receive the NFT. The sandwich attack extracts value from the protocol's BPT position, not from the user.

**4. This is a protocol operational concern, not a user-facing vulnerability.** The protocol (owner/deployer) controls which dispatchers are registered and how the system is configured. The protocol team can:
- Use the 4-parameter overload exclusively in their frontend
- Set up a wrapper contract that computes slippage before calling
- Configure their own bot to submit with private mempool (Flashbots)

**5. MEV sandwich on liquidity provision is a well-known, generic concern.** Zero slippage defaults are a design pattern choice, not a vulnerability unique to this contract. The availability of a slippage-protected path means this is at most an informational/QA observation.

**C4 Classification:** Per C4 criteria, for Medium severity: "Assets not at direct risk, but protocol function/availability impacted." The protocol function IS NOT impacted -- minting works correctly, BPT is received, the contract operates as designed. The value leak (fewer BPT per mint) requires:
- An external MEV bot monitoring the mempool
- The 3-parameter overload to be used (when a protected overload exists)
- The value extracted per transaction is bounded by the mint amount

This matches the profile of a Low/QA finding: a design recommendation (default to non-zero slippage) rather than a security vulnerability.

**Disagreement Reason:** The finding overstates severity by framing a well-known MEV concern as a Medium vulnerability despite the existence of an equally accessible slippage-protected interface. The protocol, not individual users, bears the risk (BPT goes to the contract). The finding describes a design preference, not a function/availability impact. The 4-parameter overload's existence demonstrates the developers are aware of slippage protection and provided it intentionally.

---

### M-02: 1:1 phUSD minting with UNBALANCED addLiquidity causes suboptimal BPT

**Claimed Severity:** Medium
**Assessed Severity:** Low (QA)
**Agreement:** NO
**Confidence:** High

#### Independent Analysis

**Code Verification:** The finding accurately describes the code mechanics. Line 83 mints phUSD at 1:1 decimal-normalized ratio:

```solidity
uint256 phUSDAmount = _normalizeToPhUSD(actualPrimeInVault);
```

The `_normalizeToPhUSD` function (lines 122-130) performs only decimal scaling. The `UNBALANCED` addLiquidity kind is used at line 101.

**However, this is a deliberate design choice, not a vulnerability, for the following reasons:**

**1. phUSD is the protocol's own synthetic token -- they control its supply and value.** The protocol mints phUSD specifically for this purpose (line 84: `IMintable(_phUSD).mint(address(this), phUSDAmount)`). The 1:1 ratio is not an oversight -- it is the protocol asserting that 1 unit of prime token should correspond to 1 phUSD. The protocol defines phUSD's value by how much it mints.

**2. UNBALANCED addLiquidity is an intentional design choice.** The contract NatSpec explicitly states: "adds unbalanced liquidity to a Balancer V3 pool" (line 14-15). The `AddLiquidityKind.UNBALANCED` is hardcoded, not a misconfiguration. The previous version used `DONATION` kind; changing to `UNBALANCED` was a deliberate refactor.

**3. The PoC's BPT loss percentages are misleading.** The PoC tests BPT loss at 2:1, 4:1, and 10:1 pool ratios. But the protocol controls both sides of the deposit:
- The protocol decides how much prime token to accept (via the price mechanism)
- The protocol decides how much phUSD to mint (via `_normalizeToPhUSD`)
- The pool ratio is a result of prior protocol deposits plus trading activity

If the pool drifts from 1:1, that means either: (a) the market values one token differently, or (b) arbitrageurs have already traded against the pool. In either case, the protocol depositing at 1:1 is making a statement about the intended value relationship, and the "loss" vs. a proportional deposit is the cost of maintaining that 1:1 peg assertion.

**4. No attacker profits directly.** The finding acknowledges: "BPT goes to the BalancerPooler contract, not to any attacker." The "value leak" goes to existing LPs and arbitrageurs as a natural consequence of the AMM mechanism. No one specifically attacks this contract -- the suboptimal BPT is a cost the protocol pays for using UNBALANCED deposits at 1:1.

**5. The alternative (PROPORTIONAL) would defeat the purpose.** If the protocol matched the pool ratio for phUSD minting, it would be accepting the market's price rather than asserting its own. For a synthetic stablecoin (phUSD), this would mean the protocol is no longer anchoring the 1:1 peg -- it would be market-following instead of market-making.

**6. This is a design tradeoff, not a vulnerability.** The protocol knowingly deposits equal amounts of both tokens. The "cost" of this approach (fewer BPT when pool diverges) is the price of maintaining peg pressure. This is analogous to how any market maker accepts adverse selection cost to maintain their price quote.

**C4 Classification:** Per C4 criteria for Medium: "protocol function/availability impacted, or value leak with stated assumptions." The protocol function IS working as designed. The "value leak" is the intended behavior of UNBALANCED deposits at the protocol's chosen ratio. When the contract's own NatSpec explicitly describes unbalanced liquidity addition, the behavior matches specification.

Per C4's "Known Invalid Findings": design choices that the protocol team has consciously made are not vulnerabilities. The deliberate choice of UNBALANCED over PROPORTIONAL, combined with the intentional 1:1 minting ratio for a protocol-controlled synthetic token, makes this a spec-compliant design choice.

**Disagreement Reason:** This finding describes the intended and documented behavior of the contract as a vulnerability. The 1:1 minting ratio for a protocol-controlled synthetic token is a design assertion about value, not an oversight. The UNBALANCED addLiquidity kind is explicitly stated in the NatSpec. The "BPT loss" is the cost of peg maintenance, which is a design tradeoff the protocol accepts. There is no attacker, no asset at direct risk, and no protocol function that fails. This is a design review observation (Low/QA), not a Medium severity finding.

---

## Low/QA Finding Review

### L-01: No reentrancy guard on _executeMint despite ERC1155 callback

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Analysis:** Defense-in-depth recommendation. The code follows checks-effects-interactions pattern: price is updated at line 147 BEFORE `_mint` at line 153. No economic exploit identified. The reentrancy guard is a best practice recommendation, which is properly classified as Low.

---

### L-02: BalancerPooler.unlockCallback lacks explicit reentrancy protection

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Analysis:** The Balancer vault's unlock pattern provides its own reentrancy protection. Adding a redundant guard is defense-in-depth. Correctly classified as Low.

---

### L-03: Dispatcher contracts lack token recovery mechanism

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Analysis:** Tokens accidentally sent to dispatchers are stuck. The `BalancerPooler` has `withdrawBPT()` for BPT but no generic recovery. This is a best practice recommendation. Correctly classified as Low.

---

### L-04: NFTMinter hardcodes ATokenDispatcher cast

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Analysis:** Tight coupling between NFTMinter and ATokenDispatcher. This limits extensibility but has no security impact. Design recommendation, correctly classified as Low.

---

### L-05: All claim NFTs minted with the same token ID

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Analysis:** All claims use `CLAIM_TOKEN_ID = 1` regardless of payment context. This is a design limitation that affects on-chain differentiation of claims. No security impact. Correctly classified as Low.

**Note:** This finding borders on spec deviation / informational. It describes a design choice that may or may not be intentional. The protocol may intend all claims to be fungible.

---

### L-06: Owner can set price to zero, breaking growth formula

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Analysis:** `setPrice(0)` permanently breaks the multiplicative growth formula. This requires an owner action (admin misconfiguration). The owner can also fix it by calling `setPrice()` again with a non-zero value, so the damage is recoverable. Correctly classified as Low.

**Upgrade consideration:** Could this be Medium? No -- it requires owner misconfiguration and is immediately recoverable by the same owner calling `setPrice()` with a correct value. Per C4 criteria, admin mistakes are generally not Medium unless the impact is irreversible. Here it is fully reversible.

---

### L-07: Missing SafeERC20 for USDT compatibility

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Upgrade consideration:** This is the strongest candidate for a potential upgrade to Medium among the Low findings. USDT is a widely-used token, and the inability to use it would be a meaningful functional limitation. However:
- The protocol chooses which tokens to register dispatchers for
- If USDT is registered, minting would revert, but no funds are lost (the transferFrom reverts before any state change)
- The admin can simply not register USDT dispatchers

The impact is "protocol cannot support USDT" which is a functional limitation that the admin controls. No funds at risk. Correctly classified as Low.

---

### L-08: Price growth calculated on gross price for FOT tokens

**Claimed Severity:** Low
**Assessed Severity:** Low
**Agreement:** YES

**Analysis:** The growth formula uses `price` (gross) instead of `actualReceived` (net of fees). This creates a divergence between the advertised price and the actual value collected. However, the impact is minimal per transaction and only relevant for FOT tokens. Correctly classified as Low.

---

### C-01: Uncapped growthBasisPoints allows owner to halt minting

**Claimed Severity:** Centralization Risk
**Assessed Severity:** Centralization Risk
**Agreement:** YES

**Analysis:** The owner can set extreme growth rates that make minting prohibitively expensive. This is a standard centralization / admin power concern. The owner also has `setPrice()` which provides an even more direct way to control pricing. Correctly classified as a centralization risk.

---

## Summary of Severity Changes

| Finding | Original | Recommended | Change | Rationale |
|---------|----------|-------------|--------|-----------|
| M-01    | Medium   | Low         | Downgrade | Slippage-protected 4-param overload exists and is equally accessible; BPT accrues to contract not user; MEV sandwich is generic concern not contract-specific vulnerability; design preference not function/availability impact |
| M-02    | Medium   | Low         | Downgrade | Deliberate design choice: 1:1 ratio for protocol-controlled synthetic token is peg assertion; UNBALANCED kind explicitly documented in NatSpec; no attacker profits directly; "BPT loss" is cost of peg maintenance, not a vulnerability |
| L-01    | Low      | Low         | None   | Confirmed: defense-in-depth recommendation |
| L-02    | Low      | Low         | None   | Confirmed: defense-in-depth recommendation |
| L-03    | Low      | Low         | None   | Confirmed: missing recovery mechanism |
| L-04    | Low      | Low         | None   | Confirmed: design coupling concern |
| L-05    | Low      | Low         | None   | Confirmed: design limitation |
| L-06    | Low      | Low         | None   | Confirmed: admin misconfiguration, recoverable |
| L-07    | Low      | Low         | None   | Confirmed: token compatibility limitation, admin-controlled |
| L-08    | Low      | Low         | None   | Confirmed: minor divergence for FOT tokens |
| C-01    | Centralization | Centralization | None | Confirmed: standard admin power concern |

---

## Key Observations

1. **Both Medium findings describe design tradeoffs, not vulnerabilities.** M-01 describes a well-known MEV concern where the protocol already provides a mitigation path (4-param overload). M-02 describes the intentional behavior of a synthetic token peg mechanism documented in the contract's own NatSpec.

2. **No user funds are at direct risk from either Medium finding.** In both cases, BPT goes to the BalancerPooler contract. Users pay a price and receive a claim NFT -- this transaction completes regardless of slippage or pool ratio. The protocol's BPT position may be suboptimal, but the protocol team controls both the minting interface and the pool strategy.

3. **The strongest Low finding (L-07: SafeERC20) was considered for upgrade but does not meet Medium criteria.** The admin controls which tokens are registered, and failed minting reverts without fund loss. It is a functional limitation, not a security vulnerability.

4. **The QA report is well-calibrated.** All 9 Low/QA findings are genuine observations at appropriate severity. None are inflated, and none merit upgrade.

5. **Context from the previous audit round matters.** The code has been significantly refactored (DONATION changed to UNBALANCED, access control added to dispatch, token flow redesigned). The new findings reflect the updated code but may overreach on severity because the reviewer was looking for issues after the major H-01 was resolved.

---

## Final Verdict

**Recommended submission set:**

- **Medium findings: 0** (both M-01 and M-02 recommended for downgrade to Low/QA)
- **QA Report: 9 findings** (L-01 through L-08, C-01 -- plus M-01 and M-02 if downgraded)

**Rationale for zero Medium findings:** After thorough independent review, neither M-01 nor M-02 meets C4's Medium criteria of "protocol function/availability impacted" or "value leak with stated assumptions." M-01 describes a generic MEV concern with an existing mitigation in the same contract. M-02 describes the intended behavior of a peg maintenance mechanism. Both lack the concrete, protocol-specific impact required for Medium severity.

**Counter-argument (in fairness):** A reasonable C4 judge might keep M-01 as Medium, arguing that a default-unsafe convenience function is a footgun even when a safe alternative exists. The zero slippage default is objectively worse than a non-zero default, and the finding correctly identifies this. If the protocol team did not intentionally design the 3-param overload to be unsafe, it is a legitimate code-level issue. The severity-auditor's role is to flag overstatement risk, not to make the final call -- so the protocol team and C4 judges should weigh this counter-argument.

For M-02, the case for Medium is weaker. The NatSpec explicitly documents unbalanced liquidity addition, phUSD is a protocol-minted synthetic, and the 1:1 ratio is a deliberate design choice. This is more clearly a design review observation than a vulnerability.
