# Severity Audit Report: yield-claim-NFT

**Project:** yield-claim-NFT
**Audit Type:** Regular C4 Audit -- Second-Opinion Severity Validation
**Date:** 2026-02-27
**Auditor Role:** severity-auditor (independent reviewer)

---

## Executive Summary

This report provides an independent severity assessment of 6 High/Medium findings submitted for the yield-claim-NFT project. The goal is to prevent severity overstatement and ensure accuracy against C4 severity criteria.

**Key findings from this audit:**
- 1 of 6 findings confirmed at claimed severity (H-01)
- 3 of 6 findings recommended for downgrade
- 2 of 6 findings confirmed at claimed severity with caveats

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| H-01    | High    | High     | Yes       | High       |
| M-01    | Medium  | Low      | No        | High       |
| M-02    | Medium  | Low      | No        | High       |
| M-03    | Medium  | Medium   | Yes       | Medium     |
| M-04    | Medium  | Low      | No        | Medium     |
| M-05    | Medium  | Medium   | Yes       | Medium     |

---

## Detailed Analysis

### H-01: Missing access control on dispatch() -- anyone can drain NFTMinter tokens

**Claimed Severity:** High
**Assessed Severity:** High
**Agreement:** YES
**Confidence:** High

#### Independent Analysis

**Asset Risk:** Direct token theft confirmed. The `dispatch()` function on `ATokenDispatcher` (line 44 of `src/dispatchers/ATokenDispatcher.sol`) has no access control beyond `whenNotPaused`. The `minter` parameter is caller-supplied and used as the `transferFrom` source. Since `NFTMinter.registerDispatcher()` grants `type(uint256).max` approval at line 106 of `src/NFTMinter.sol`, any caller can drain the NFTMinter's entire token balance.

**Attack Path Validation:** Concrete and unconditional.
1. No special conditions required -- any address can call `dispatch()`.
2. The `minter` parameter is not validated against `_minter` storage variable in the dispatch functions.
3. For Gather dispatcher: tokens are redirected to `_recipient` (could be attacker-controlled if attacker also controls the Gather owner). Even without controlling recipient, this is a griefing/destruction vector via Burner.
4. For Burner dispatcher: tokens are irreversibly burned.
5. For BalancerPooler: tokens are force-donated to pool at attacker's chosen timing.

**Conditions:** None. Exploitable by anyone, anytime, as long as the dispatcher is not paused. The dispatchers start unpaused by default (OpenZeppelin Pausable starts unpaused).

**Impact Verification:** Full drain of all ERC20 tokens held by NFTMinter. This is direct asset theft/loss. The Burner variant is especially devastating as it is irreversible.

**Code Evidence:**
```solidity
// ATokenDispatcher.sol:44 -- no caller restriction
function dispatch(address minter, uint256 amount) external virtual whenNotPaused {}

// Burner.sol:32 -- pulls from caller-supplied 'minter' address
function dispatch(address minter, uint256 amount) external override whenNotPaused {
    IERC20(_token).transferFrom(minter, address(this), amount);
    // ...burns tokens
}

// NFTMinter.sol:106 -- unlimited approval granted at registration
IERC20(token).approve(dispatcher, type(uint256).max);
```

**Verdict:** Severity is accurate. This is a textbook missing access control vulnerability with direct, unconditional asset loss. No hypotheticals, no external conditions, any attacker can execute immediately.

---

### M-01: Reentrancy in mint() -- CEI violation, dispatch before price update

**Claimed Severity:** Medium
**Assessed Severity:** Low (QA)
**Agreement:** NO
**Confidence:** High

#### Independent Analysis

**Asset Risk:** The claimed impact is "minting at stale price" via reentrancy through ERC777-like token hooks or ERC1155 `onERC1155Received` callback. Let me trace the actual attack paths.

**Attack Path 1 -- via ERC1155 callback (line 142):** The `_mint` on line 142 triggers `onERC1155Received` on the recipient. However, by this point, the price has ALREADY been updated on line 139. The execution order is:
1. Read price (line 128)
2. transferFrom user (line 132)
3. dispatch (line 136)
4. **Update price (line 139)** -- happens BEFORE the callback
5. _mint ERC1155 triggers callback (line 142)

So reentering via `onERC1155Received` would face the ALREADY-UPDATED price. This path does not achieve the claimed impact.

**Attack Path 2 -- via dispatch callback:** The dispatch call at line 136 happens BEFORE the price update at line 139. However, for reentrancy to work, the attacker would need to re-enter `mint()` during the `dispatch()` call. This requires:
- The token used in `transferFrom` must have a transfer hook (ERC777 or similar)
- OR the dispatcher itself must callback to an attacker-controlled contract

Looking at the dispatchers:
- **Accumulator:** No external calls at all. No reentrancy vector.
- **Burner:** Calls `IBurnable.burn()` on the token. The token contract would need to callback -- extremely unlikely for standard tokens.
- **Gather:** Calls `IERC20.transfer()` to recipient. Standard ERC20 transfer has no callback. ERC777 `tokensReceived` hook could theoretically trigger, but this requires the prime token to BE an ERC777 token.
- **BalancerPooler:** Calls vault.unlock() which calls back unlockCallback(), which then transfers to vault and calls addLiquidity/settle. None of these call back to an attacker-controlled address.

**Critical Assessment:** The reentrancy requires the prime token to be an ERC777 (or similar hook-enabled token). Standard ERC20 tokens do not have transfer hooks. The protocol explicitly handles fee-on-transfer tokens (evidence: balance-before/after pattern, MockFOTToken tests), suggesting the expected token set is standard ERC20/FOT tokens, not ERC777.

**C4 Classification:** Per C4 criteria, findings that require non-standard/weird ERC-20 tokens are "Known Invalid Findings" unless explicitly in scope. ERC777 is a non-standard token type. The project's test suite uses standard ERC20 mocks and FOT token mocks -- no ERC777 tokens are tested or mentioned anywhere.

**Conditions Required:**
1. Prime token must implement ERC777 or equivalent transfer hooks
2. Attacker must be the token recipient on a Gather dispatcher, or the token must callback during burn
3. Attack is meaningless for Accumulator (no-op dispatch)

**Impact if exploitable:** Even IF all conditions are met, the impact is minting at a stale price -- the attacker saves `price * growthBasisPoints / 10000` per re-entrant call. At 2% growth and 100 token price, that is 2 tokens per re-entrant mint. This is a value leak, not direct theft.

**Disagreement Reason:** This finding requires non-standard ERC-20 tokens (ERC777) which are explicitly listed as "Known Invalid Findings" in C4 criteria. The attack path through the ERC1155 callback is factually incorrect (price is already updated). The only viable path requires extraordinary token assumptions not supported by the codebase. This is Low/QA at best.

---

### M-02: BalancerPooler MEV sandwich on donation

**Claimed Severity:** Medium
**Assessed Severity:** Low (QA)
**Agreement:** NO
**Confidence:** High

#### Independent Analysis

**Critical Technical Error in Finding:** The finding claims that `minBptAmountOut = 0` allows sandwich attacks on liquidity provision. However, this finding fundamentally misunderstands Balancer V3 DONATION semantics.

**Balancer V3 DONATION does NOT mint BPT tokens.** Per [Balancer V3 documentation](https://docs.balancer.fi/build/build-a-hook/interacting-with-the-vault.html): "It would mint BPTs to router, but it's a donation so no BPT is minted" and "Donation does not return BPTs, any number above 0 will revert."

This means:
1. `minBptAmountOut = 0` is **correct and required** for DONATION kind. Setting it to any other value would REVERT the transaction.
2. There is no slippage to protect against because no BPT is being received.
3. The "sandwich" attack described (front-run with BPT acquisition, back-run after value increase) does not apply because the donation simply increases the value of existing BPT for current LPs without minting new BPT.

**MEV Considerations:** The finding's description of "attacker front-runs with BPT acquisition, back-runs after value increase" describes a legitimate but well-known MEV pattern that affects ALL donations to public pools, regardless of the `minBptAmountOut` parameter. This is inherent to Balancer's DONATION mechanism, not a bug in the BalancerPooler contract. The contract is using the DONATION kind exactly as intended.

**The finding itself acknowledges uncertainty:** "Note: the AddLiquidityKind is DONATION, which may mitigate this depending on Balancer V3's DONATION semantics (donations may not mint BPT). This should be verified against the Balancer V3 specification."

The verification confirms: DONATION does not mint BPT. The `minBptAmountOut = 0` is not a vulnerability -- it is the only correct value.

**Regarding the MEV sandwich on donation value:** While it is true that an attacker could front-run a donation by acquiring BPT (through normal LP operations) and then benefit from the donation increasing their BPT value, this is:
1. Inherent to the DONATION mechanism in Balancer V3
2. Not caused by any code deficiency
3. The same MEV risk that exists for any pool donation anywhere

**Disagreement Reason:** The core technical claim (minBptAmountOut=0 is a vulnerability) is incorrect -- it is the only valid value for DONATION kind. The broader MEV concern about donation sandwiching is a design property of Balancer V3's DONATION mechanism, not a code bug. This is at best a known limitation/design consideration (Low/QA), not a Medium severity finding.

---

### M-03: 1:1 phUSD minting ignores yield-bearing token premium

**Claimed Severity:** Medium
**Assessed Severity:** Medium
**Agreement:** YES
**Confidence:** Medium

#### Independent Analysis

**Asset Risk:** Value leak, not direct theft. The `_normalizeToPhUSD()` function in `BalancerPooler.sol` (lines 117-125) performs only decimal conversion, not value conversion. When the prime token is a yield-bearing asset like sUSDS (worth >1 USD), the contract mints phUSD at 1:1 decimal-adjusted ratio, creating an imbalanced donation.

**Attack Path Validation:** The attack path is indirect but valid:
1. sUSDS accrues yield, so 1 sUSDS > 1 USD over time
2. BalancerPooler donates [X sUSDS + X phUSD] to pool
3. Pool receives more value on the sUSDS side
4. Arbitrageurs extract the imbalance from the pool
5. This bleeds value from the protocol's donations

**Conditions Required:**
- Prime token must be a yield-bearing token (sUSDS, stETH, etc.)
- This is explicitly supported: Accumulator NatSpec says "tokens like sUSDS"
- The premium must be non-trivial for meaningful extraction

**Impact Assessment:** The value leak is proportional to the yield premium and donation volume. At 5% sUSDS premium, approximately 2.5% of each donation is extractable. This is real but limited -- it is a value leak with stated assumptions (yield-bearing token premium), which is precisely the C4 definition of Medium: "value leak with stated assumptions and external requirements."

**Concern about overstatement:** This could be an intentional design choice. If phUSD is designed to track the prime token's value rather than USD, then the 1:1 ratio is correct. However, the name "phUSD" strongly implies a USD peg, and the decimal normalization function confirms the intent is to equalize units, not value. The lack of any oracle or exchange rate function supports this being an oversight.

**Verdict:** Medium severity is appropriate. Real value leak with clear conditions. Not direct theft, but measurable protocol value loss on every donation. The assumptions (yield-bearing prime token) are explicitly supported by the codebase documentation.

---

### M-04: Irrevocable infinite approval, no deregistration

**Claimed Severity:** Medium
**Assessed Severity:** Low (QA)
**Agreement:** NO
**Confidence:** Medium

#### Independent Analysis

**Asset Risk:** The finding describes two gaps: (1) `type(uint256).max` approval cannot be revoked, and (2) there is no dispatcher deregistration function.

**Independence from H-01:** The finding notes it "compounds H-01 severity." If H-01 is fixed (adding `onlyMinter` check to `dispatch()`), does this finding independently rise to Medium?

With H-01 fixed:
- The dispatcher can only be called by the authorized minter
- The infinite approval is only usable by the dispatcher's `dispatch()` function, which would require minter authorization
- A "compromised dispatcher" would need to be an upgradeable proxy that is maliciously upgraded -- but the dispatchers in this codebase are NOT upgradeable (no proxy pattern)

**Without H-01 being fixed:** This finding is already captured by H-01 itself. The infinite approval is what enables H-01. Reporting it separately as Medium is double-counting.

**Analysis of the actual risk:**
1. **Compromised dispatcher:** The dispatchers are not upgradeable contracts. Once deployed, their code is immutable. A "compromised" dispatcher would require a bug in the dispatcher's own logic, which is already the subject of other findings.
2. **Buggy dispatcher discovered post-registration:** The owner can pause a dispatcher via `setDispatcherActive(dispatcher, false)`, which prevents dispatch() from executing (via `whenNotPaused`). While this does not revoke the approval, it prevents the approval from being exploited through the normal dispatch path.
3. **Direct transferFrom by dispatcher:** Even with infinite approval, the dispatcher contracts have no function that allows arbitrary transferFrom calls. The only path is through `dispatch()`, which is guarded by `whenNotPaused`.

**C4 Classification:** This is a centralization risk / design recommendation. The lack of a deregistration function is a design gap, but not one that puts assets at risk independent of H-01. The mitigation (pausing) exists. Per C4 criteria, centralization risks and design recommendations are QA/Low.

**Disagreement Reason:** Without H-01, this is absorbed into H-01. With H-01 fixed, the residual risk requires an upgradeable proxy dispatcher (not present in the codebase) or a separate dispatcher vulnerability. Pausing provides adequate mitigation. This is a design recommendation / centralization risk, which is Low/QA per C4 criteria.

---

### M-05: Price growth stagnation from integer rounding

**Claimed Severity:** Medium
**Assessed Severity:** Medium
**Agreement:** YES
**Confidence:** Medium

#### Independent Analysis

**Asset Risk:** Protocol function impacted -- the bonding curve mechanism fails silently for small prices.

**Attack Path Validation:** The math is straightforward and verifiable:
```
config.price = price + (price * growthBasisPoints) / 10000
```
When `price * growthBasisPoints < 10000`, the increment is 0 due to integer division.

Examples:
- price = 99, growthBps = 100 (1%): 99 * 100 / 10000 = 0
- price = 1, growthBps = 9999 (99.99%): 1 * 9999 / 10000 = 0
- price = 100, growthBps = 100 (1%): 100 * 100 / 10000 = 1 (works)

**Conditions Required:**
- `price * growthBasisPoints < 10000`
- This requires either small initial price or small growth rate
- Owner sets both parameters, so this requires misconfiguration

**Impact Assessment:** Once stagnated, unlimited NFTs can be minted at the stuck price. If NFTs carry economic rights (yield claims, governance), this enables unbounded extraction. The bonding curve -- a core protocol mechanism -- silently fails.

**Concern about overstatement:** This requires the owner to set parameters that trigger the rounding issue. With 18-decimal tokens, a "reasonable" price of 1e18 (1 token) with 100 bps (1%) gives: 1e18 * 100 / 10000 = 1e16. This works fine. The issue only manifests at very small prices (sub-100 wei with typical growth rates).

However, there is no validation preventing these configurations, and the failure is silent (no revert, no warning). The owner has no way to know the growth mechanism has stopped working. This is a genuine protocol function failure, not just a theoretical concern.

**Verdict:** Medium severity is defensible but borderline. The protocol's core pricing mechanism silently fails under specific configurations. While those configurations require small prices, the lack of any validation or warning makes this a genuine design flaw that impacts protocol function. It fits C4 Medium: "protocol function/availability impacted."

**Note:** If C4 judges determine that owner misconfiguration findings are Low regardless of impact, this should be downgraded. The key question is whether silent failure of a core mechanism due to missing validation is Medium (protocol function impacted) or Low (admin should know better).

---

## Summary of Severity Changes

| Finding | Original | Recommended | Change | Rationale |
|---------|----------|-------------|--------|-----------|
| H-01    | High     | High        | None   | Confirmed: unconditional direct asset theft |
| M-01    | Medium   | Low         | Downgrade | Requires ERC777 (non-standard token, C4 invalid); ERC1155 reentrancy path is factually wrong (price already updated) |
| M-02    | Medium   | Low         | Downgrade | Core claim is technically incorrect: minBptAmountOut=0 is required for DONATION kind (BPT is not minted); MEV on donations is inherent to Balancer V3, not a code bug |
| M-03    | Medium   | Medium      | None   | Confirmed: value leak with stated assumptions (yield-bearing prime token) |
| M-04    | Medium   | Low         | Downgrade | Centralization risk / design recommendation; absorbed by H-01 or mitigated by pausing; dispatchers are not upgradeable |
| M-05    | Medium   | Medium      | None   | Confirmed: silent failure of core pricing mechanism under specific configurations |

## Key Observations

1. **H-01 is a clear High.** No debate. Missing access control with unconditional asset drain.

2. **M-01's reentrancy claim has a factual error.** The ERC1155 `_mint` callback at line 142 happens AFTER the price update at line 139, not before. The only viable reentrancy path is through ERC777 tokens in the dispatch call, which is a non-standard token assumption.

3. **M-02 misunderstands Balancer V3 DONATION semantics.** DONATION does not mint BPT, so `minBptAmountOut = 0` is correct behavior, not a vulnerability. The finding's own text acknowledges this uncertainty.

4. **M-04 is dependent on H-01.** If H-01 is fixed, M-04's residual risk is minimal. If H-01 is not fixed, M-04 is already captured by H-01. Either way, it does not independently merit Medium severity.

## Sources

- [Balancer V3 Vault API Documentation](https://docs.balancer.fi/developer-reference/contracts/vault-api.html)
- [Interacting With The Vault - Balancer V3](https://docs.balancer.fi/build/build-a-hook/interacting-with-the-vault.html)
