# Carryover QA Report — originating audit 17 (carried into yield-claim-nft-20)

> **Carryover QA report — audit 17** (cut down from `yield-claim-nft/reports/17/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 20): **Q-12, Q-13, Q-14, Q-15 (plus the run-17 instance sections for still-open L-06, L-09, Q-05)**.
> Removed as no longer live: L-13 (wont-fix, owner triage 2026-07-18). The "Visible suppressions" block (DEDUP-001 suppressed; `setMaxTin` KI-4) is likewise not live and is not copied.
> Structural sections not copied (they carry no live findings of their own): title block + Summary, Appendix (4naly3er).
> Retained counts: Low 0 originating (2 instance sections) · QA 4 originating (+1 instance section).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Re-observed in run 20: Q-12, Q-13, Q-15 (`lastSeenRun` → yield-claim-nft-20). Q-12 gains the new Leg A call site `PromotionUniV2_Eth._swapSusdsForPhusd` L534. **Q-14 is PROPOSED `fixed`** — `PromotionUniV2_Eth.unlockCallback` and all Balancer code were deleted in `a4d80f4` (story-049); status left `qa-bundled` pending `/ledger yield-claim-nft fixed e5d7aff2ea`. It is retained here until a human applies that.
> Line numbers and links were accurate at the originating commit, and relative links reflect the repository
> layout of that run (`reports/yield-claim-nft/NN/`, `lib/yield-claim-nft/src/...`); the source now lives at
> `yield-claim-nft/src/src/...`. Re-verify every location against current HEAD `2bfa090`.
>
> Triage any of these with `/ledger yield-claim-nft`.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

---

## Low Risk Findings

### [L-06] LP add relies solely on off-chain keeper min-floors — MEV-sandwich class now extends to the ETH swap leg (carryover) <!-- id: ycn17l6 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` / `_legB` / `unlockCallback`](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L299); `addLiquidity(..., 0, 0, ...)` at [L300](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L300)
**Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../10/submissions/qa-report.md) · **Carryover stub:** [`carryover/L-06-CARRYOVER.md`](./carryover/L-06-CARRYOVER.md) · **Fingerprint:** `342075df…`

**Status:** carryover, still-open — confirmed **Low, not re-escalated** (settled precedent).

**Description (this-run instance):** The `pool()`/`unlockCallback` off-chain-keeper-floor MEV-sandwich class now recurs on the **new native-ETH swap leg** (`swapExactETHForTokens` floors + `amountAMin = amountBMin = 0` on `addLiquidity` (L300) + `block.timestamp` deadline). This adds two more sandwich surfaces, but each ETH leg carries its **own** floor (`minEthOut`, `minPromoOut`), and the post-call `require(liquidity >= minLP)` (L302) backstops the LP add; the `onlyAuthorizedPooler` gate means there is no unprivileged zero-floor trigger. Worst case is lazy-keeper slack on retained *protocol* funds — not user assets, not a permissionless exploit. More legs of the same keeper-quoted class, not a new class.

**Recommendation:** Non-blocking defense-in-depth — force `minLP > 0` and/or set non-zero `amountAMin`/`amountBMin` so a zero-floor keeper call cannot silently ship. See the original report for full detail.

---

### [L-09] Unwired dispatch hook has no `hookTypeId` guard — fail-open zero-debt accrual (carryover, 4th dispatcher) <!-- id: ycn17l9 -->

**Location:** [`PromotionUniV2_Eth.sol` `_dispatch`](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L255) → base `ATokenDispatcherV2._dispatch → hook.onDispatch(GROSS)`
**Original report:** [reports/yield-claim-nft/13/submissions/qa-report.md](../../13/submissions/qa-report.md) · **Carryover stub:** [`carryover/L-09-CARRYOVER.md`](./carryover/L-09-CARRYOVER.md) · **Fingerprint:** `563df2e6…`

**Status:** carryover, still-open — confirmed **Low**; kept OPEN and DISTINCT from the wont-fix Q-08 (BalancerPoolerV2, a separate contract/fingerprint) and NOT re-filed.

**Description (this-run instance):** `PromotionUniV2_Eth` reuses the base `ATokenDispatcherV2._dispatch → hook.onDispatch(GROSS)` path with **no `hookTypeId`/`keccak256` guard** (source-confirmed: the file declares no such literal), and the constructor defaults `hook` to the no-op `DefaultDispatchHook`. If the owner forgets to `setHook`, NFTs mint while **zero phUSD mint-debt accrues**. This is the fourth dispatcher to carry the M-04 fail-open class (M-04 NudgeRatchet = fixed with a guard; Q-08 BalancerPoolerV2 = wont-fix; L-09 Uniboost = open; now PromotionUniV2_Eth). The hook *call* itself is faithful (gross amount passed) — the gap is the fail-open. Story-044 faithfulness record **F-02-044 reconciles here**; no separate finding minted.

**Recommendation / safe-config guidance:** Apply the M-04-fixed NudgeRatchet `hookTypeId()` marker guard to this dispatch path (fail-closed on a default/unwired hook). Operationally: always `setHook` before opening dispatches, and verify debt accrual on the first dispatch.

---

## QA / Non-critical Findings

### [Q-12] `block.timestamp` router deadlines give no effective expiry <!-- id: ycn17q12 -->

**Location:** [`PromotionUniV2_Eth.sol` router deadlines — L300, L338, L344](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L300)

**Description:** All UniV2 swap and `addLiquidity` calls pass `deadline = block.timestamp`, which is always satisfied at execution and therefore provides no effective transaction expiry.

**Impact:** Informational hardening only. The real price protection is the per-leg min-out floors (`minEthOut`/`minPromoOut`) plus the final `minLP` check; a stale tx reverts on a floor, not on the deadline. Execution is same-block atomic inside an `onlyAuthorizedPooler` + `nonReentrant` frame, so there is no cross-block MEV window. This is a facet of the MEV class tracked at L-06.

**Recommendation:** Accept a caller-supplied deadline (or `block.timestamp + <bounded window>`) so a delayed/held transaction can expire rather than executing whenever it lands.

---

### [Q-13] Unchecked UniV2 swap return values on the ETH legs <!-- id: ycn17q13 -->

**Location:** [`PromotionUniV2_Eth.sol` `_legB` L337, L343](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L332)

The UniV2 router swap calls on the ETH legs (`swapExactTokensForETH`, `swapExactETHForTokens`) do not capture the returned `amounts` array. This is inert: the router enforces `amountOutMin` (`minEthOut`/`minPromoOut`) internally, so a shortfall already reverts the swap regardless of whether the return is inspected — the unchecked return cannot admit an under-execution. Optional hardening only: capture and assert the return amounts for clearer post-conditions.

---

### [Q-14] Unchecked Balancer `settle` return in `unlockCallback` <!-- id: ycn17q14 -->

**Location:** [`PromotionUniV2_Eth.sol` `unlockCallback` L376](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L376)

**Description:** The Balancer V3 `settle()` return value inside `unlockCallback` (the pay → swap → settle → sendTo sequence) is not checked.

**Impact:** Safe by construction — informational only. Balancer V3 `unlock()` reverts if the transient debt is not fully settled, so any shortfall reverts the entire `pool()` call regardless of whether the `settle` return is inspected. No value leak, no availability impact.

**Recommendation:** Optionally assert `settle()`'s return equals the paid amount for clarity; the `unlock`-level revert already enforces settlement.

---

### [Q-15] `addLiquidity` residual dust ignored (by-design, documented, recoverable) <!-- id: ycn17q15 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` / `addLiquidity` L299-301](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L299)

**Description:** `addLiquidity(..., amountAMin = 0, amountBMin = 0, ...)` can leave residual dust on the imbalanced side; the router refunds the excess side and the dust is not swept within the same call.

**Impact:** No loss. The behavior is by-design and NatSpec-documented ([L292-294](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L292)): slippage is bounded by the leg floors and the final `minLP` check. Residual dust is retained and recoverable — swept into the next `pool()` or via `rescueERC20`.

**Recommendation:** None required; optionally sweep or account residual dust per `pool()` for tidiness. Confirm the documented-dust behavior remains intended.

---

### [Q-05] `nonReentrant` is not the first modifier on `pool()` (carryover) <!-- id: ycn17q5 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` L277-282](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L277)
**Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../10/submissions/qa-report.md) · **Carryover stub:** [`carryover/Q-05-CARRYOVER.md`](./carryover/Q-05-CARRYOVER.md) · **Fingerprint:** `13fe448d…`

**Status:** carryover, still-open (de-dup-against-ledger, kept visible in this bundle — not a suppression).

**Description (this-run instance):** The class recurs byte-identically on `PromotionUniV2_Eth.pool` — modifier order is `onlyAuthorizedPooler, whenNotPaused, nonReentrant`. Defense-in-depth style only: the preceding modifiers merely read state, so ordering `nonReentrant` last is inert here, but placing it first is the safer convention. See the original report for full detail.

