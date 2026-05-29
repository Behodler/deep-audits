# QA Report — StableYieldAccumulator

**Project:** stable-yield-accumulator
**Contract in scope:** `src/StableYieldAccumulator.sol`
**Commit:** `71abe3e088559cb5d9c10e8475dc67e7cc57fac9`
**Run:** stable-yield-accumulator-11 (COLD)

This report bundles all Low-severity and Centralization findings for the audit run. There are **no High or Medium** findings. The tone is measured throughout: every item below is non-critical, owner-recoverable, dust-bounded, or cosmetic. An automated 4naly3er QA/gas baseline is attached as an appendix.

---

## Summary

| Label | Title | Severity |
|-------|-------|----------|
| [L-01](#l-01-claim-charges-0-payment-while-delivering-skimmed-yield) | `claim()` charges 0 payment while delivering skimmed yield (post-denormalize floor not re-guarded) | Low / QA |
| [L-02](#l-02-phlimbo-allowance-depletion-bricks-permissionless-claim-until-owner-re-approves) | Phlimbo allowance depletion bricks permissionless `claim()` until owner re-approves | Low (availability) |
| [L-03](#l-03-claim-natspec-says-pay-then-skim-code-skims-then-pays) | `claim()` NatSpec says pay-then-skim; code skims-then-pays (doc/impl mismatch) | Low / QA (doc) |
| [C-01](#c-01-owner-configuration-guardrails-ownable2step-discount-cap) | Owner configuration guardrails (Ownable2Step, discount cap) | Centralization / QA |

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| Centralization | 1 |
| **Total** | **4** |

---

## Low Risk Findings

### [L-01] `claim()` charges 0 payment while delivering skimmed yield <!-- id: sya11l1 -->

**Location:** [`StableYieldAccumulator.sol#L494-L509`](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9/src/StableYieldAccumulator.sol#L494-L509) (zero-payment guard L494; floor mechanics L617-L640)

**Description:** The only zero-payment guard checks the 18-decimal aggregate `totalNormalizedYield` at L494:

```solidity
494:  if (totalNormalizedYield == 0) revert ZeroAmount();
...
497:  uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;
498:  uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);
...
509:  IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
```

The post-discount, post-denormalize `actualPayment` computed at L498 floors when converting back to the reward token's native decimals. For a low-decimal reward token (e.g. 6-decimal USDC) and a high discount, a non-zero aggregate yield can still floor `actualPayment` to `0`. The L494 guard never re-checks the floored value, so `safeTransferFrom(msg.sender, this, 0)` at L509 succeeds and the claimer receives the skimmed native yield for zero payment.

**Impact:** Dust only. Bounded at roughly ≤ 1 USDC-wei (~$0.000001) per claim at a 2% discount and ≤ ~$0.01 at a 99.99% discount, and **one NFT is burned per claim**, which makes farming strictly unprofitable. The round-trip corollary confirms the math is floor-only and never over-credits. Severity remains Low/QA despite the Tier-3 machine proof — proof strength does not inflate severity.

This finding is machine-proven: a Foundry stateful invariant and an independent Medusa run both shrank to `underlyingReceived = 1`, and Halmos refuted `actualPayment > 0` in 0.64s with the identical counterexample.

**Recommendation:** Re-guard the floored value immediately after L498:

```solidity
uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);
if (actualPayment == 0) revert ZeroAmount();
```

---

### [L-02] Phlimbo allowance depletion bricks permissionless `claim()` until owner re-approves <!-- id: sya11l2 -->

> **Verified.** The external pull semantics are confirmed: `lib/stable-yield-accumulator/lib/phlimbo-ea/src/Phlimbo.sol:277` shows `collectReward(uint256 amount)` doing `rewardToken.safeTransferFrom(msg.sender, address(this), amount)` — a fixed-amount pull (not a full-balance / max-allowance pull) that draws down SYA's never-replenished `forceApprove` allowance. The root cause is SYA's own fixed-allowance pattern at L369-L374, which is in-scope under the per-repo audit rule. The depletion is therefore real and the finding is LIVE at Low severity (owner-recoverable in a single `approvePhlimbo` tx, atomic, no fund loss).

**Location:** [`StableYieldAccumulator.sol#L369-L374`](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9/src/StableYieldAccumulator.sol#L369-L374) (approval) vs [`#L519`](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9/src/StableYieldAccumulator.sol#L519) (consumption)

**Description:** `approvePhlimbo` sets a fixed `forceApprove` allowance that is never topped up:

```solidity
369:  function approvePhlimbo(uint256 amount) external onlyOwner {
...
373:      IERC20(rewardToken).forceApprove(phlimbo, amount);
374:  }
```

Each `claim()` consumes allowance through the `IPhlimbo(phlimbo).collectReward(phlimboAmount)` pull at L519. Once cumulative `phlimboAmount` exceeds the approved amount, every subsequent **permissionless** `claim()` reverts on the depleted allowance until the owner calls `approvePhlimbo` again.

**Impact:** Availability only. Permissionless `claim()` can be temporarily bricked until the owner re-approves. There is no fund loss and the condition is fully owner-recoverable in one atomic transaction.

**Recommendation:** Re-approve in `claim()`, approve a sufficiently large allowance up front, or switch Phlimbo's pull to a push transfer.

---

### [L-03] `claim()` NatSpec says pay-then-skim; code skims-then-pays <!-- id: sya11l3 -->

**Location:** [`StableYieldAccumulator.sol#L426-L434`](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9/src/StableYieldAccumulator.sol#L426-L434) (docstring) and interface comment `IStableYieldAccumulator.sol#L314-L323`, vs implementation order (skim L484, pay L509)

**Description:** The `claim()` NatSpec (L426-L434, mirrored in `IStableYieldAccumulator.sol#L314-L323`) describes a pay-then-skim flow, but the implementation skims first (L484) then pays (L509). Its real value is documentary: it pins down why the "yield-delivered-before-payment" exploit angle is refuted — `claim()` is atomic and `nonReentrant`, so a failed payment rolls back both the skim and the NFT burn. Documentation-only; correct the NatSpec to reflect the actual skim-then-pay ordering.

---

## Centralization Risks

### [C-01] Owner configuration guardrails (Ownable2Step, discount cap) <!-- id: sya11c1 -->

**Location:**
- `Ownable` declaration — [`StableYieldAccumulator.sol#L57`](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9/src/StableYieldAccumulator.sol#L57)
- `setDiscountRate` — [`StableYieldAccumulator.sol#L324-L330`](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9/src/StableYieldAccumulator.sol#L324-L330)

**Description:** These are residual **configuration-robustness** observations on designed owner authority — not exploit primitives:

1. **Single-step ownership.** The contract uses single-step `Ownable` (declared L57). A mistyped address in `transferOwnership` can irrecoverably brick all owner controls.
2. **Discount cap.** `setDiscountRate` reverts only on `rate > 10000` (L325), so a discount of exactly `10000` (100%) is permitted. As defense-in-depth input validation, capping strictly below 100% removes a misconfiguration footgun. (This is not framed as an exploit; the owner-drain-via-100%-discount angle is accepted design — see Disputed / Out-of-Scope below.)

The Aderyn note about `nonReentrant` modifier ordering (around L447) was investigated and is benign: `whenNotPaused` makes no external call before the reentrancy guard takes effect.

**Impact:** Centralization / configuration robustness only. The single-step `Ownable` is the main concrete risk — an owner transfer typo can permanently disable administration. No exploit primitive is introduced.

**Recommendation:** Optional hardening guardrails:
- Adopt `Ownable2Step` in place of `Ownable` (L57) for two-step ownership transfer.
- Cap `discountRate < 10000` at L324-L330 (defense-in-depth input validation).

---

## Disputed / Out-of-Scope Framings

The following angles were considered during the audit and are **deliberately not raised as vulnerabilities**. They are recorded here for completeness so they are not re-litigated in future runs:

- **Owner drains protocol via a 100% discount** and **owner manipulates yield via depeg / exchange-rate adjustment** — These are **accepted design / known issues #4 and #5**. The depeg exchange-rate adjustment is a documented owner capability (per the contract design: "owner can adjust for permanent depegs"), the oracle-free 1:1 tradeoff was previously accepted, and the scenarios fall under the "reckless admin mistake" exclusion. The optional guardrails in **C-01** are presented purely as hardening; the High framing of owner-drain/depeg is **not** a finding and should not be re-raised.
- **"Yield delivered before payment" exploit** — Refuted: `claim()` is atomic and `nonReentrant`, so a failed payment rolls back the skim and NFT burn (see **L-03**). This is the root reason L-03 is documentation-only rather than a security issue.

---

## Appendix A — Automated QA/Gas Report (4naly3er)

**Status:** RAN SUCCESSFULLY. 4naly3er (the canonical C4-style automated report generator) was executed against the contract using the static-analyzer's scratch project (`/tmp/sya-scan/src`) with a `remappings.txt` wired to the checked-out dependency sources and a scope file limited to `StableYieldAccumulator.sol`. The nested dependency submodules were not available in the read-only `lib/` submodule for a full Foundry compile, so this scratch reuse was the degraded path; it produced a complete report.

The full markdown output is saved alongside this report at:

**`reports/stable-yield-accumulator-11/submissions/4naly3er-report.md`**

Headline automated counts (informational; these are tool-generated style/gas/centralization observations, not manual findings):

| Category | Issue types | Notable items |
|----------|-------------|----------------|
| Gas Optimizations | 13 (GAS-1 … GAS-13) | unchecked arithmetic (38), `address(0)` via assembly (16), cache array length (9) |
| Non-Critical | 17 (NC-1 … NC-17) | magic numbers, missing old/new value in events, custom-error usage, style/layout |
| Low (bot) | 7 (L-1 … L-7) | 2-step ownership transfer (L-1/L-7), zero-value-transfer reverts (L-2), missing `address(0)` checks (L-3), division-by-zero (L-4), renounce-while-paused (L-5), `PUSH0`/0.8.20 chain compat (L-6) |
| Medium (bot) | 2 (M-1, M-2) | fee-on-transfer accounting (M-1), centralization for trusted owners — 15 instances (M-2) |

**Corroboration with manual findings:** The bot's L-1/L-7 (2-step ownership) and M-2 (owner centralization) map onto manual finding **C-01**; the bot's L-2 (zero-value transfer reverts) is adjacent to manual **L-01**. The bot's M-1 (fee-on-transfer) is a known-invalid class per repository policy and is not promoted. No bot item surfaces a High/Medium exploit path beyond what the manual review already classified.

See `submissions/4naly3er-report.md` for the complete instance-level listings.
