# Severity Audit Report: M-01

## Finding Under Review

**ID**: M-01
**Title**: ClaimArbitrage Step 3 hardcodes USDC approval but SYA rewardToken is mutable, causing permanent DoS if rewardToken changes
**Claimed Severity**: Medium
**Contract**: `src/ClaimArbitrage.sol`
**Line**: 177

---

## Independent Severity Assessment

### Assessed Severity: **Medium (AGREE)**

### Confidence: **High**

---

## Code Verification

### The Bug Is Real

Line 177 of `ClaimArbitrage.sol`:
```solidity
IERC20(USDC).approve(address(sya), p.usdcNeeded);
```

`USDC` is declared as `address public immutable USDC` at line 45. This is set once in the constructor and can never change.

Meanwhile, `StableYieldAccumulator.sol` line 611:
```solidity
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
```

And `rewardToken` is mutable via `setRewardToken()` at line 468:
```solidity
function setRewardToken(address _rewardToken) external onlyOwner {
    if (_rewardToken == address(0)) revert ZeroAddress();
    rewardToken = _rewardToken;
}
```

If `rewardToken` is changed from USDC to token X, then:
- Step 3 approves USDC to SYA (wrong token)
- SYA's `claim()` calls `safeTransferFrom` on token X from ClaimArbitrage
- ClaimArbitrage has zero allowance for token X to SYA
- Revert: permanent, no code path to fix without redeployment

### Internal Inconsistency Confirmed

Line 208 (Step 5) already handles this correctly:
```solidity
address _rewardToken = sya.rewardToken();
```

The code comment on lines 204-206 explicitly states the design intent:
> "We query sya.rewardToken() rather than using the immutable USDC address because
> the reward token is a property of SYA, not of this contract. If SYA's reward token
> ever changes, this logic adapts automatically."

The project's CLAUDE.md reinforces this:
> "If SYA's reward token were ever reconfigured, ClaimArbitrage's logic must adapt
> automatically without redeployment."

Step 3 was simply not updated to follow the same pattern as Step 5.

---

## Severity Analysis

### Arguments FOR Medium (Convincing)

1. **Objectively verifiable bug**: Step 3 hardcodes USDC, Step 5 queries dynamically. The inconsistency is indisputable.

2. **Developer intent is documented**: The comments and CLAUDE.md explicitly state the contract SHOULD adapt to rewardToken changes without redeployment. This is not speculation about future use -- it is the stated design requirement.

3. **`setRewardToken()` is a production feature**: It exists with a proper setter, zero-address validation, and no deprecation notice. It is designed to be called.

4. **Protocol function/availability impacted**: ClaimArbitrage is the PRIMARY mechanism for atomically consolidating yield. Its DoS means the yield consolidation pipeline (SYA -> Phlimbo -> Limbo stakers) loses its automated path.

5. **C4 Medium definition satisfied**: "the function of the protocol or its availability could be impacted" -- ClaimArbitrage's entire function is permanently disabled.

### Arguments AGAINST Medium (Evaluated and Rejected)

1. **"Requires owner action (admin prerequisite)"**

   **Rebuttal**: The owner action (`setRewardToken`) is not an attack vector or admin mistake. It is a documented, intended feature of SYA. The issue is that when this legitimate admin operation is performed, ClaimArbitrage silently breaks. This is a code defect, not an admin trust assumption. The admin is not acting recklessly -- they are using a feature that the code explicitly claims to support.

   C4 distinguishes between "requires admin to make a mistake" (Low/QA) and "admin uses a documented feature that reveals a bug" (Medium). This is firmly the latter.

2. **"ClaimArbitrage is just a helper"**

   **Rebuttal**: ClaimArbitrage is described in its own NatSpec as the permissionless mechanism for MEV bots to perform yield consolidation. The project's architecture documentation describes it as the decentralized conversion mechanism. It is not a peripheral utility -- it is the protocol's answer to "who performs the conversion?"

3. **"Direct claiming on SYA still works"**

   **Rebuttal**: True, but this is a mitigation, not an invalidation. The protocol function (automated yield consolidation through ClaimArbitrage) is still impacted. The existence of a manual workaround does not negate a Medium finding.

4. **"Owner can deploy a new ClaimArbitrage"**

   **Rebuttal**: The need to redeploy IS the impact. The finding correctly identifies that the current contract becomes permanently bricked. Redeployment requires new configuration, pool key setup, knownStables registration, and any integrators (MEV bots) must update their target address. This is operational disruption to protocol availability.

5. **"Could be centralization risk"**

   **Rebuttal**: This is not a centralization risk. Centralization risk is when an admin CAN do something harmful. Here the admin is doing something INTENDED and the code fails to handle it. The admin is using the protocol correctly.

### Is This Overstated as Medium?

**No.** The finding is squarely within C4 Medium territory:

- It is NOT High because there is no direct asset theft or loss. User funds are not at risk. The impact is availability/functionality disruption of a specific contract, not a financial exploit.
- It IS Medium because protocol function (yield consolidation via ClaimArbitrage) is permanently impacted when a documented, intended admin operation is performed.
- It is NOT Low/QA because it is not a spec deviation or best practice issue -- it is a concrete bug that causes permanent contract failure under documented operating conditions.

### PoC Validation

The PoC at `/home/justin/code/C4/solidity-audit/workspace/yield-accumulator/test/poc-M-01-v05.t.sol` correctly demonstrates:
- Phase 1: `execute()` succeeds when `rewardToken == USDC`
- Phase 2: SYA owner changes `rewardToken` via `setRewardToken()`
- Phase 3: `execute()` reverts due to approval mismatch
- Phase 4: The DoS is permanent, not recoverable

The PoC uses mock contracts but faithfully reproduces the critical interaction: SYA's `claim()` calls `safeTransferFrom` on `rewardToken`, and ClaimArbitrage only approved `USDC`.

---

## Likelihood and Impact Assessment

| Factor | Assessment |
|--------|------------|
| **Likelihood** | Medium -- Requires owner to call `setRewardToken()`, but this is a documented, intended feature with an explicit setter. Not speculative. |
| **Impact** | Medium -- Permanent DoS of ClaimArbitrage. No fund loss. Manual claiming on SYA still works. Requires redeployment. |
| **Severity (Matrix)** | Medium x Medium = **Medium** |

---

## Final Verdict

| Field | Value |
|-------|-------|
| Claimed Severity | Medium |
| Assessed Severity | **Medium** |
| Agreement | **YES** |
| Confidence | High |
| Should Submit | **YES** -- as standalone finding |

### Reasoning Summary

The finding identifies a real, objectively verifiable code inconsistency (Step 3 hardcoded vs Step 5 dynamic) with documented developer intent confirming the expected behavior. The impact (permanent DoS of ClaimArbitrage requiring redeployment) matches C4 Medium criteria: "protocol function or availability impacted." The trigger condition (owner using `setRewardToken()`) is a documented feature, not a reckless admin action. The PoC confirms the revert. Medium severity is accurate -- neither overstated nor understated.

---

## Validity Concerns

**None material.** The finding is:
- Technically accurate (hardcoded vs dynamic inconsistency confirmed in source)
- Not a duplicate of any known issue (the existing "audit M-01" referenced in code comments relates to `knownStables` coverage, a different issue)
- Not a known-invalid pattern per C4 rules (not admin mistake, not user error, not unused view function)
- Supported by developer documentation stating the contract should adapt to rewardToken changes

The only risk to validity is a C4 judge ruling that `setRewardToken()` will never be called in practice, making this "hypothetical." However, the explicit setter with validation, the dynamic query in Step 5, and the CLAUDE.md documentation all strongly indicate this is an intended operation.
