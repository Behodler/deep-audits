# QA Report — yield-claim-nft (run-17)

- **Project:** yield-claim-nft
- **Scope this run:** `src/dispatchers/PromotionUniV2_Eth.sol` (story-044 — new native-ETH-leg "buy-and-pool" dispatcher)
- **Submodule HEAD:** `8dd8963`
- **Date:** 2026-07-18
- **Pass type:** Low / QA bundle — **no High or Medium findings this run.** Value conservation holds across the new ETH leg (Tier-3 invariants all HELD; INV-4 confirmed donated ETH can never reach a third party).

An automated SAST/gas baseline (4naly3er) is attached as an appendix: [`4naly3er-report.md`](./4naly3er-report.md).

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (new) | 1 |
| Low Risk (carryover, still-open) | 2 |
| QA / Non-critical (new) | 4 |
| QA / Non-critical (carryover, still-open) | 1 |
| **Total** | **8** |

Centralization: none newly raised this run. Owner-privilege exposure on the ETH-leg dispatcher (`setMaxTin`, `setPSM`, `rescueETH`, `rescueERC20`) is either an obvious owner action (Law-3 trusted, suppressed — see *Visible suppressions*) or captured within the L-13 footgun below.

| Label | ID | Severity | Location | One-liner |
|-------|-----|----------|----------|-----------|
| L-13 | `ycn17l13` | Low (new) | `_legB` / `receive()` | Whole-balance ETH sweep + open `receive()`: stray ETH folds into the next pooler's promotion buy; `rescueETH` is front-runnable |
| L-06 | `ycn17l6` | Low (carryover) | `pool` / `unlockCallback` | Keeper-floor-only LP add — MEV-sandwich class now extends to the ETH swap leg |
| L-09 | `ycn17l9` | Low (carryover) | `_dispatch` → `hook.onDispatch` | Unwired-hook fail-open (no `hookTypeId` guard) — 4th dispatcher to carry the class |
| Q-12 | `ycn17q12` | QA (new) | router deadlines | `block.timestamp` deadlines give no effective expiry |
| Q-13 | `ycn17q13` | QA (new) | `_legB` | Unchecked UniV2 swap return values (router enforces min-out internally) |
| Q-14 | `ycn17q14` | QA (new) | `unlockCallback` | Unchecked Balancer `settle` return (safe by construction) |
| Q-15 | `ycn17q15` | QA (new) | `pool` / `addLiquidity` | `addLiquidity` residual dust (by-design, documented, recoverable) |
| Q-05 | `ycn17q5` | QA (carryover) | `pool` | `nonReentrant` is not the first modifier |

---

## Low Risk Findings

### [L-13] Whole-balance ETH sweep with an open `receive()`: stray ETH folds into the next pooler's promotion buy, and `rescueETH` is front-runnable <!-- id: ycn17l13 -->

**Location:** [`PromotionUniV2_Eth.sol` `_legB` L342-345](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L342), [`receive()` L400](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L400), [`rescueETH` L393](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L393)

**Severity note (Low/QA boundary):** This finding sits on the Low/QA boundary and was explicitly flagged by the severity auditor for possible human reclassification to QA. It is presented honestly as a **low-severity operational footgun with value fully conserved to protocol LP** — Tier-3 INV-4 HELD: donated ETH never reaches a third party, and there is **no theft**. It is kept at Low (not QA) because it has a *demonstrated non-obvious consequence* that a competent, non-malicious owner would be surprised by, consistent with the ledger's other footgun Lows (L-10 deploy-config, L-11 batch-floor staleness, L-12 pause-custody gap).

**Description:** Leg B of `pool()` first unwraps this call's USDC into native ETH via `swapExactTokensForETH`, then reads the **entire contract ETH balance** and swaps all of it into the promotion token:

```solidity
uint256 ethBal = address(this).balance;                       // L342 — WHOLE balance, not this swap's output
IUniswapV2Router02(UNIV2_ROUTER).swapExactETHForTokens{value: ethBal}(
    minPromoOut, ethToPromotionPath(), address(this), block.timestamp
);
```

The swap consumes `address(this).balance`, **not** the `amounts[1]` output the preceding `swapExactTokensForETH` just returned. Combined with an open, unguarded `receive()` (L400), any ETH sitting on the contract at `pool()` time — coinbase/`SELFDESTRUCT` transfer, a deliberate donation, or ETH stranded by a prior partial/failed Leg B not yet `rescueETH`'d — is irreversibly folded into whichever pooler calls `pool()` next, buying promotion tokens at **that keeper's** off-chain floors (`minPromoOut`/`minLP`) and mis-attributing the donation to them. The intended sweep, `rescueETH` (L393, `onlyOwner`, not pause-gated), can recover stray ETH — but an authorized pooler can front-run the owner's `rescueETH` with a `pool()` call, folding the ETH into LP before the sweep lands.

*(The naive "someone accidentally sends ETH" entry vector is C4 known-invalid — user error — and is only one illustrative way ETH lands here; it is **not** the basis of the finding. The basis is the whole-balance sweep semantics plus the `rescueETH` front-running/mis-attribution hazard.)*

**Impact:** No value at risk to the protocol or third parties. Swept ETH becomes `promotionToken` and enters the **protocol-owned** phUSD/promotion LP (withdrawable only via owner `rescueERC20`); the only party who can lose value is a self-harming donor. No revert/DoS path — extra ETH only raises promotion-out, easing `minPromoOut`; a UniV2 `uint112` reserve overflow would need an infeasible `> uint112`-worth donation. Tier-3 INV-4 confirmed the value can never route to a third party. The reportable substance is the surprising state-handling / value-misattribution consequence plus the `rescueETH` timing hazard, not theft.

**Recommendation / safe-config guidance:**
- Operationally, **sweep stray ETH (`rescueETH`) before authorizing a `pool()` call** if it must not enter LP — and do not treat `rescueETH` as a race-free escape, since a pooler can front-run it.
- Consider **bounding the Leg-B swap to the leg's own swap output** (`amounts[1]`) rather than `address(this).balance`, so pre-existing/stray ETH cannot be absorbed:

```solidity
uint256[] memory out = IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForETH(...);
uint256 ethIn = out[1]; // swap only this leg's proceeds
IUniswapV2Router02(UNIV2_ROUTER).swapExactETHForTokens{value: ethIn}(...);
```

- If the whole-balance sweep is retained intentionally, document it as intentional so a future maintainer does not "fix" it into a value leak.

Cross-ref: **F-01-044** (story-044 faithfulness record for the same whole-balance ETH sweep).

---

### [L-06] LP add relies solely on off-chain keeper min-floors — MEV-sandwich class now extends to the ETH swap leg (carryover) <!-- id: ycn17l6 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` / `_legB` / `unlockCallback`](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L299); `addLiquidity(..., 0, 0, ...)` at [L300](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L300)
**Original report:** [reports/yield-claim-nft-10/submissions/qa-report.md](../../yield-claim-nft-10/submissions/qa-report.md) · **Carryover stub:** [`carryover/L-06-CARRYOVER.md`](./carryover/L-06-CARRYOVER.md) · **Fingerprint:** `342075df…`

**Status:** carryover, still-open — confirmed **Low, not re-escalated** (settled precedent).

**Description (this-run instance):** The `pool()`/`unlockCallback` off-chain-keeper-floor MEV-sandwich class now recurs on the **new native-ETH swap leg** (`swapExactETHForTokens` floors + `amountAMin = amountBMin = 0` on `addLiquidity` (L300) + `block.timestamp` deadline). This adds two more sandwich surfaces, but each ETH leg carries its **own** floor (`minEthOut`, `minPromoOut`), and the post-call `require(liquidity >= minLP)` (L302) backstops the LP add; the `onlyAuthorizedPooler` gate means there is no unprivileged zero-floor trigger. Worst case is lazy-keeper slack on retained *protocol* funds — not user assets, not a permissionless exploit. More legs of the same keeper-quoted class, not a new class.

**Recommendation:** Non-blocking defense-in-depth — force `minLP > 0` and/or set non-zero `amountAMin`/`amountBMin` so a zero-floor keeper call cannot silently ship. See the original report for full detail.

---

### [L-09] Unwired dispatch hook has no `hookTypeId` guard — fail-open zero-debt accrual (carryover, 4th dispatcher) <!-- id: ycn17l9 -->

**Location:** [`PromotionUniV2_Eth.sol` `_dispatch`](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L255) → base `ATokenDispatcherV2._dispatch → hook.onDispatch(GROSS)`
**Original report:** [reports/yield-claim-nft-13/submissions/qa-report.md](../../yield-claim-nft-13/submissions/qa-report.md) · **Carryover stub:** [`carryover/L-09-CARRYOVER.md`](./carryover/L-09-CARRYOVER.md) · **Fingerprint:** `563df2e6…`

**Status:** carryover, still-open — confirmed **Low**; kept OPEN and DISTINCT from the wont-fix Q-08 (BalancerPoolerV2, a separate contract/fingerprint) and NOT re-filed.

**Description (this-run instance):** `PromotionUniV2_Eth` reuses the base `ATokenDispatcherV2._dispatch → hook.onDispatch(GROSS)` path with **no `hookTypeId`/`keccak256` guard** (source-confirmed: the file declares no such literal), and the constructor defaults `hook` to the no-op `DefaultDispatchHook`. If the owner forgets to `setHook`, NFTs mint while **zero phUSD mint-debt accrues**. This is the fourth dispatcher to carry the M-04 fail-open class (M-04 NudgeRatchet = fixed with a guard; Q-08 BalancerPoolerV2 = wont-fix; L-09 Uniboost = open; now PromotionUniV2_Eth). The hook *call* itself is faithful (gross amount passed) — the gap is the fail-open. Story-044 faithfulness record **F-02-044 reconciles here**; no separate finding minted.

**Recommendation / safe-config guidance:** Apply the M-04-fixed NudgeRatchet `hookTypeId()` marker guard to this dispatch path (fail-closed on a default/unwired hook). Operationally: always `setHook` before opening dispatches, and verify debt accrual on the first dispatch.

---

## QA / Non-critical Findings

### [Q-12] `block.timestamp` router deadlines give no effective expiry <!-- id: ycn17q12 -->

**Location:** [`PromotionUniV2_Eth.sol` router deadlines — L300, L338, L344](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L300)

**Description:** All UniV2 swap and `addLiquidity` calls pass `deadline = block.timestamp`, which is always satisfied at execution and therefore provides no effective transaction expiry.

**Impact:** Informational hardening only. The real price protection is the per-leg min-out floors (`minEthOut`/`minPromoOut`) plus the final `minLP` check; a stale tx reverts on a floor, not on the deadline. Execution is same-block atomic inside an `onlyAuthorizedPooler` + `nonReentrant` frame, so there is no cross-block MEV window. This is a facet of the MEV class tracked at L-06.

**Recommendation:** Accept a caller-supplied deadline (or `block.timestamp + <bounded window>`) so a delayed/held transaction can expire rather than executing whenever it lands.

---

### [Q-13] Unchecked UniV2 swap return values on the ETH legs <!-- id: ycn17q13 -->

**Location:** [`PromotionUniV2_Eth.sol` `_legB` L337, L343](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L332)

The UniV2 router swap calls on the ETH legs (`swapExactTokensForETH`, `swapExactETHForTokens`) do not capture the returned `amounts` array. This is inert: the router enforces `amountOutMin` (`minEthOut`/`minPromoOut`) internally, so a shortfall already reverts the swap regardless of whether the return is inspected — the unchecked return cannot admit an under-execution. Optional hardening only: capture and assert the return amounts for clearer post-conditions.

---

### [Q-14] Unchecked Balancer `settle` return in `unlockCallback` <!-- id: ycn17q14 -->

**Location:** [`PromotionUniV2_Eth.sol` `unlockCallback` L376](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L376)

**Description:** The Balancer V3 `settle()` return value inside `unlockCallback` (the pay → swap → settle → sendTo sequence) is not checked.

**Impact:** Safe by construction — informational only. Balancer V3 `unlock()` reverts if the transient debt is not fully settled, so any shortfall reverts the entire `pool()` call regardless of whether the `settle` return is inspected. No value leak, no availability impact.

**Recommendation:** Optionally assert `settle()`'s return equals the paid amount for clarity; the `unlock`-level revert already enforces settlement.

---

### [Q-15] `addLiquidity` residual dust ignored (by-design, documented, recoverable) <!-- id: ycn17q15 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` / `addLiquidity` L299-301](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L299)

**Description:** `addLiquidity(..., amountAMin = 0, amountBMin = 0, ...)` can leave residual dust on the imbalanced side; the router refunds the excess side and the dust is not swept within the same call.

**Impact:** No loss. The behavior is by-design and NatSpec-documented ([L292-294](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L292)): slippage is bounded by the leg floors and the final `minLP` check. Residual dust is retained and recoverable — swept into the next `pool()` or via `rescueERC20`.

**Recommendation:** None required; optionally sweep or account residual dust per `pool()` for tidiness. Confirm the documented-dust behavior remains intended.

---

### [Q-05] `nonReentrant` is not the first modifier on `pool()` (carryover) <!-- id: ycn17q5 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` L277-282](../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L277)
**Original report:** [reports/yield-claim-nft-10/submissions/qa-report.md](../../yield-claim-nft-10/submissions/qa-report.md) · **Carryover stub:** [`carryover/Q-05-CARRYOVER.md`](./carryover/Q-05-CARRYOVER.md) · **Fingerprint:** `13fe448d…`

**Status:** carryover, still-open (de-dup-against-ledger, kept visible in this bundle — not a suppression).

**Description (this-run instance):** The class recurs byte-identically on `PromotionUniV2_Eth.pool` — modifier order is `onlyAuthorizedPooler, whenNotPaused, nonReentrant`. Defense-in-depth style only: the preceding modifiers merely read state, so ordering `nonReentrant` last is inert here, but placing it first is the safer convention. See the original report for full detail.

---

## Visible suppressions (recorded for auditability — not filed as active findings)

- **DEDUP-001 (phUSD over-backing / external-backing convention)** — project-suppressed umbrella (`070fdf42…`). The gross-amount `hook.onDispatch` + donation-split path on this dispatcher is the same convention (over-backing, not under-mint); no new unbacked-mint path introduced. Suppressed, listed here so it stays visible.
- **`setMaxTin` uncapped (KI-4)** — `setMaxTin` is a price/fee-setting owner action whose consequence (raising the PSM `tin` ceiling that Leg A tolerates) is a Law-3 *obvious* owner action within known-issue KI-4. Suppressed as owner-trusted; listed for visibility, not filed.

---

## Appendix — Automated QA / Gas report (4naly3er)

The canonical C4-style automated bot report is attached: [`4naly3er-report.md`](./4naly3er-report.md).

- Generated by 4naly3er over `lib/yield-claim-nft/src/**` at HEAD `8dd8963` (33 files in scope).
- **Tooling workaround applied:** this project is `foundry.toml`-only (no `remappings.txt`), which makes 4naly3er fail. Resolved by staging an absolute-path `remappings.txt` + a `src` symlink in the scratchpad and pointing 4naly3er at that (the recurring remappings-gap fix). The run completed cleanly (exit 0).
- Contents: 20 Gas-optimization classes (GAS-1 … GAS-20) and the Non-Critical (NC) class table. These are advisory tool output and are **not** individually triaged into the ledger; genuine items are already reflected above (e.g. the unchecked-return and magic-number notes overlap Q-13/Q-14).
