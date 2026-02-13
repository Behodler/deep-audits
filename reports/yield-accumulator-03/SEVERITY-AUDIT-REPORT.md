# Severity Audit Report -- yield-accumulator-03

**Project:** yield-accumulator (StableYieldAccumulator + ClaimArbitrage)
**Mode:** Regular audit (C4 severity criteria)
**Date:** 2026-02-10
**Auditor:** severity-auditor

---

## Executive Summary

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| H-01    | High    | **High** | AGREE     | HIGH       |
| M-01    | Medium  | **Medium** | AGREE   | HIGH       |
| M-02    | Medium  | **Medium** | AGREE   | MEDIUM     |
| M-03    | Medium  | **Medium** | AGREE   | HIGH       |
| M-04    | Medium  | **Low**  | DISAGREE  | MEDIUM     |

**Result: 4 agreements, 1 disagreement (M-04 recommended downgrade to Low/QA)**

---

## H-01: Spot Price Oracle Manipulation Bypasses targetPrice Minimum in claim()

**Claimed: High | Assessed: High | AGREE | Confidence: HIGH**

### Analysis

**Asset Risk:** Direct value extraction from the protocol. During a phUSD depeg, an attacker claims yield at the full discount rate when the protocol intended to block all claims. The spread between yield face value and discounted payment is extracted from Phlimbo stakers.

**Attack Path Validation:** The attack path is concrete and executable, not hypothetical. The protocol's own `ClaimArbitrage.sol` (lines 141-187) implements the exact same pump-claim-unwind pattern. The vulnerability pattern (spot price manipulation via `getSlot0()`) is a well-established attack vector in Uniswap V4. No extraordinary conditions are required.

**Conditions Assessment:**
- Requires a phUSD depeg event where true price < targetPrice -- the `targetPrice` check exists precisely because depegs are expected
- Requires accumulated yield in strategies -- this is the contract's core function
- No special attacker capabilities beyond a standard contract call
- Cost: only round-trip swap fees, negligible relative to extractable yield

**Impact Verification:** The targetPrice mechanism is the protocol's sole defense against depeg-based yield extraction. With it bypassed, the full discount spread is extractable. Impact scales linearly with total accumulated yield.

**PoC Verification:** A standalone PoC exists at `/home/justin/code/C4/solidity-audit/reports/yield-accumulator-03/audit/pocs/poc-H-01.t.sol`. Three tests demonstrate: (1) claim correctly reverts at true price 0.90 below target 0.95, (2) atomic price manipulation to 1.10 bypasses the check and extracts full yield, (3) pool price returns to 0.90 after attack. The PoC uses a mocked PoolManager but accurately reproduces the `extsload`/`getSlot0` pattern from Uniswap V4's `StateLibrary`.

### Verdict

High severity is justified. This meets all High criteria:
- Assets can be directly extracted (yield at discount during depeg)
- Valid attack path with no hypotheticals
- Protocol's own code validates the attack pattern
- No extraordinary conditions required

---

## M-01: ClaimArbitrage Tokens Permanently Locked When Not in knownStables

**Claimed: Medium | Assessed: Medium | AGREE | Confidence: HIGH**

### Analysis

**Asset Risk:** Permanent token locking. Tokens are irrecoverable because ClaimArbitrage exposes no rescue, sweep, or arbitrary transfer function. The submission thoroughly enumerates all external functions to prove no recovery path exists.

**Attack Path Validation:** Not an active exploit. This is a configuration desynchronization between two independently managed registries: SYA's `yieldStrategies` and CA's `knownStables[]`. The contracts may have different owners, making synchronization purely an off-chain operational concern.

**Conditions Assessment:**
- Requires SYA owner to add a new yield strategy for a token not yet in CA's `knownStables` -- this is a normal operational event
- Requires `execute()` to be called during the desynchronization window -- virtually guaranteed since `execute()` is permissionless and designed for MEV bots
- The timing gap between SYA's `addYieldStrategy()` transaction (block N) and CA's `addKnownStable()` transaction (block N+k) is inherent and unavoidable
- Multiple calls during the gap compound the locked amount

**Impact Verification:** Tokens are permanently locked. No workaround exists short of deploying a new ClaimArbitrage contract. The loss scales with accumulated yield in the unregistered strategy.

### Verdict

Medium severity is appropriate. This is a value leak (permanent token locking) with an external requirement (configuration desynchronization). Not direct theft by an attacker, but a foreseeable operational failure mode with permanent, irrecoverable consequences. The lack of a rescue function elevates this within the Medium range.

---

## M-02: Residual phUSD Delta Silently Dropped Causing ClaimArbitrage DoS

**Claimed: Medium | Assessed: Medium | AGREE | Confidence: MEDIUM**

### Analysis

**Asset Risk:** No direct asset theft. DoS on ClaimArbitrage functionality only. Yield is not lost -- it remains in strategies and can be claimed directly through `SYA.claim()` by other actors.

**Attack Path Validation:** Not an active exploit. This is a code defect triggered automatically when the pump/unwind cycle leaves any nonzero phUSD residual delta. The silent return at line 335 of `_settleResidualDelta()` causes `PoolManager` to revert when it detects unsettled deltas.

**Conditions Assessment:**
- Requires `stableToUSDCPool[phUSD]` to not be configured -- described as a natural default since phUSD is not an external stablecoin
- Requires pump/unwind to leave nonzero phUSD residual -- AMM mechanics with fees plausibly produce rounding residuals
- The comment at lines 333-334 acknowledges the gap: "residual phUSD delta should be negligible after unwind" -- but the PoolManager enforces zero, not negligible

**Impact Verification:** ClaimArbitrage is non-functional for scenarios producing residual phUSD delta. However, the finding overstates impact by saying "yield distribution is blocked" without clarifying that direct `SYA.claim()` calls remain unaffected. The DoS is limited to the ClaimArbitrage helper. The owner can resolve this by calling `setStableToUSDCPool(phUSD, ...)`.

### Observations

The confidence level is MEDIUM because the claim that AMM rounding always produces nonzero residuals is plausible but not empirically verified in the PoC. If the residual is truly zero in practice (e.g., the unwind sells the exact amount received from the pump), the DoS would not trigger.

### Verdict

Medium severity is appropriate. Protocol function/availability is impacted (ClaimArbitrage DoS). The finding correctly identifies that the silent return masks the root cause, making debugging difficult. However, the scope of impact is narrower than presented -- only ClaimArbitrage is affected, not direct claims.

---

## M-03: Pausing Any Single Token Blocks ALL Claims

**Claimed: Medium | Assessed: Medium | AGREE | Confidence: HIGH**

### Analysis

**Asset Risk:** No direct asset theft. Temporary DoS on all yield claiming. Yield is not lost -- it remains in strategies and becomes claimable once the paused token is unpaused. However, during a depeg event, timing matters significantly.

**Attack Path Validation:** Not an active exploit. Triggered by normal admin operations (pausing a token during a depeg event, which is documented as expected behavior). The behavioral inconsistency is clearly demonstrated in source code:
- `StableYieldAccumulator.sol` line 589: `if (tokenConfigs[token].paused) revert TokenIsPaused();`
- `StableYieldAccumulator.sol` line 803: `if (tokenConfigs[token].paused) continue;`

**Conditions Assessment:**
- Requires admin to pause any single token -- documented as expected operational behavior for black swan events
- No attacker involvement required
- Trigger is routine administration, not adversarial

**Impact Verification:**
- All claims blocked when any single token is paused (verified by code inspection)
- `calculateClaimAmount()` returns misleading values that cannot actually be claimed
- ClaimArbitrage and all direct claimers are DoSed
- Phlimbo reward distribution pipeline stalls

### Verdict

Medium severity is well-justified. Clear protocol function/availability impact with a well-demonstrated behavioral inconsistency. The intended pause granularity (per-token) is defeated by the implementation (global block). The misleading `calculateClaimAmount()` return value compounds the issue for integrators. The admin action triggering this is expected, not adversarial.

---

## M-04: No Slippage Protection on Internal Swaps (Sandwich)

**Claimed: Medium | Assessed: Low/QA | DISAGREE | Confidence: MEDIUM**

### Analysis

**Asset Risk:** Value extracted from the arbitrageur's (MEV bot's) profit margin. The protocol and Phlimbo stakers receive their full payment regardless of any sandwich on the conversion swaps. The `NoProfit` check at line 252 provides a floor -- if USDC profit reaches zero, the transaction reverts entirely.

**Attack Path Validation:** The sandwich attack vector is technically valid and well-understood. However, the victim is the permissionless arbitrageur calling `execute()`, not the protocol or its users.

**Conditions Assessment:**
- Requires mempool visibility of `execute()` transactions -- standard MEV condition
- Requires sufficient pool liquidity for profitable sandwiching -- standard
- The stable-to-USDC swaps are between stablecoins pegged near 1:1, inherently limiting sandwich price impact

**Impact Verification -- Mitigating Factors:**

1. **The victim is an MEV bot, not the protocol.** Phlimbo stakers receive their full discounted payment whether or not the arbitrageur's conversion swaps are sandwiched. The sandwich extracts from the bot's profit margin, not from protocol assets.

2. **MEV bots routinely use private mempools.** Flashbots Protect, MEV-Share, and similar services prevent public mempool exposure. The finding's attack path ("monitor mempool for execute() transactions") assumes public submission, which sophisticated arbitrageurs avoid.

3. **The NoProfit check bounds maximum extraction.** The sandwich attacker must calibrate to leave residual profit, or the entire transaction reverts and no value is extracted.

4. **Stablecoin-to-stablecoin swaps have limited price impact.** The conversion in Step 5 swaps between stablecoins pegged near 1:1. The absolute price movement achievable via sandwich is inherently small compared to volatile-pair sandwiches.

5. **The "arbitrageur deterrence" argument is speculative.** The submission chains multiple hypothetical steps: sandwich reduces profit -> bots stop calling execute() -> yield conversion stalls. This indirect consequence chain is not proven and relies on rational actor assumptions that may not hold (e.g., bots may accept lower margins).

### Disagreement Reasoning

Per C4 Medium criteria: "Assets not at direct risk, but protocol function/availability impacted, or value leak with stated assumptions and external requirements."

The value leak here is from a third-party's profit margin (the permissionless arbitrageur), not from protocol assets or user funds. The protocol receives its full payment regardless. The "protocol function impacted" framing (that bots will stop calling execute()) is speculative and not directly caused by the vulnerability.

The user context states "The only MEV vector I'm ok with on the claimArbitrage is front running as that can never be helped," confirming sandwich attacks are valid findings. However, being a valid finding does not automatically mean Medium severity. The question is whether the impact rises to Medium, and I assess it does not because:
- No protocol assets are at risk
- No user funds are at risk
- The victim (arbitrageur) has standard mitigations available (private mempools)
- The NoProfit check prevents catastrophic outcomes
- The indirect protocol impact (deterrence) is hypothetical

### Verdict

Recommend downgrade to Low/QA. The finding is technically correct -- the swaps lack slippage protection and sandwich attacks are possible. As a best-practice recommendation for defense-in-depth, it belongs in the QA report. However, the impact on protocol security does not meet the Medium severity threshold because the primary victim is a third-party MEV bot, not the protocol or its users.

**Note on confidence:** This assessment has MEDIUM confidence because severity for MEV-related findings is a judgment call. A reasonable judge could argue that indirect deterrence of arbitrageurs impacts protocol function (yield conversion pipeline stalls). I weight the NoProfit check and private mempool mitigations more heavily, but acknowledge the borderline nature.

---

## Summary of Recommendations

| Finding | Action | Reasoning |
|---------|--------|-----------|
| H-01 | **Keep as High** | Direct value extraction, concrete attack path, PoC verified |
| M-01 | **Keep as Medium** | Permanent token locking, operational desynchronization risk |
| M-02 | **Keep as Medium** | ClaimArbitrage DoS, but note direct claim() remains functional |
| M-03 | **Keep as Medium** | Clear behavioral inconsistency defeating pause granularity |
| M-04 | **Downgrade to Low/QA** | Victim is third-party MEV bot, not protocol; speculative indirect impact |
