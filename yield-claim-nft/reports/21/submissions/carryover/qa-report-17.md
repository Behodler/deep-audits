# Carryover QA Report — originating audit 17 (carried into yield-claim-nft-21)

> **Carryover QA report — audit 17** (pruned copy of `yield-claim-nft/reports/17/submissions/qa-report.md`; originating commit `8dd8963`; carried at `267660b`, run 21).
> Retained (still `qa-bundled`): **Q-13, Q-14, Q-15**.
> Removed as disposed: **L-13** (`ac8eadefd1`, `wont-fix`), **Q-12** (`69f9f9ca67`, `wont-fix`), and the run's carryover instance of **L-06** (`342075dfba`, `wont-fix`). The run-17 instance sections of **L-09** and **Q-05** are carried under their parent entries in `qa-report-13.md` and `qa-report-10.md`. "Visible suppressions" and the 4naly3er appendix are not copied.
> Run 18 re-observed and enriched Q-13/Q-14/Q-15; those run-18 sections are appended verbatim under each entry.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder, and many point at the retired `lib/yield-claim-nft/...` reference tree. Re-verify every location against `267660b` before acting.
> Global issue IDs in the `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped). Where an originating report minted an ID inconsistently (run 08 stamped QA items with `l`), the original stamp is kept and the discrepancy is noted, not corrected.
> *The finding text below each heading is a verbatim copy of the originating report; the `Carryover status` block after each section is added by the run-21 qa-bundler.*

---

## QA / Non-critical Findings

### [Q-13] Unchecked UniV2 swap return values on the ETH legs <!-- id: ycn17q13 -->

**Location:** [`PromotionUniV2_Eth.sol` `_legB` L337, L343](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L332)

The UniV2 router swap calls on the ETH legs (`swapExactTokensForETH`, `swapExactETHForTokens`) do not capture the returned `amounts` array. This is inert: the router enforces `amountOutMin` (`minEthOut`/`minPromoOut`) internally, so a shortfall already reverts the swap regardless of whether the return is inspected — the unchecked return cannot admit an under-execution. Optional hardening only: capture and assert the return amounts for clearer post-conditions.

> **Carryover status (run 21, `267660b`).** Ledger **Q-13** · fingerprint `28ad35745a1aa6e99bec566cb70dcde00b36ac66ecda9cfb821587d08ab35fbe` · status **`qa-bundled`** · severity `qa` · first seen `yield-claim-nft-17` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.

#### Run-18 re-observation (verbatim from `reports/18/submissions/qa-report.md`)

##### [Q-13] Unchecked UniV2 router swap return values on the ETH legs of `_legB` <!-- id: ycn18q13 -->

**Status:** qa-bundled (QA), static-analysis-sourced, already ledgered this run (`28ad3574…`).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol#_legB`

**Description:** The UniV2 router swap return values (amounts out) on the ETH legs of `_legB` are
not captured or checked. Effective slippage protection comes from the router's own `amountOutMin`
argument, but ignoring the returned amounts removes an on-contract sanity check and any ability to
react to a partial/degenerate fill.

**Recommendation:** Capture and assert the router swap return values against the expected minimums
in-contract, in addition to the router-level `amountOutMin`.

---

### [Q-14] Unchecked Balancer `settle` return in `unlockCallback` <!-- id: ycn17q14 -->

**Location:** [`PromotionUniV2_Eth.sol` `unlockCallback` L376](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L376)

**Description:** The Balancer V3 `settle()` return value inside `unlockCallback` (the pay → swap → settle → sendTo sequence) is not checked.

**Impact:** Safe by construction — informational only. Balancer V3 `unlock()` reverts if the transient debt is not fully settled, so any shortfall reverts the entire `pool()` call regardless of whether the `settle` return is inspected. No value leak, no availability impact.

**Recommendation:** Optionally assert `settle()`'s return equals the paid amount for clarity; the `unlock`-level revert already enforces settlement.

> **Carryover status (run 21, `267660b`).** Ledger **Q-14** · fingerprint `e5d7aff2ea44b548b4ee3b0d22e970a31b85fb4c2bf5363268c392fa9fbb5aa3` · status **`qa-bundled`** · severity `qa` · first seen `yield-claim-nft-17` · last seen `yield-claim-nft-17` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

#### Run-18 re-observation (verbatim from `reports/18/submissions/qa-report.md`)

##### [Q-14] Unchecked Balancer `settle` return value in `unlockCallback` <!-- id: ycn18q14 -->

**Status:** qa-bundled (QA), static-analysis-sourced, already ledgered this run (`e5d7aff2…`).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol#unlockCallback`

**Description:** The return value of the Balancer `settle` call in `unlockCallback` is not checked.
A mismatch between the settled amount and the expected amount would go undetected on-contract.

**Recommendation:** Check the `settle` return value against the expected settled amount and revert
on mismatch.

---

### [Q-15] `addLiquidity` residual dust ignored (by-design, documented, recoverable) <!-- id: ycn17q15 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` / `addLiquidity` L299-301](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L299)

**Description:** `addLiquidity(..., amountAMin = 0, amountBMin = 0, ...)` can leave residual dust on the imbalanced side; the router refunds the excess side and the dust is not swept within the same call.

**Impact:** No loss. The behavior is by-design and NatSpec-documented ([L292-294](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L292)): slippage is bounded by the leg floors and the final `minLP` check. Residual dust is retained and recoverable — swept into the next `pool()` or via `rescueERC20`.

**Recommendation:** None required; optionally sweep or account residual dust per `pool()` for tidiness. Confirm the documented-dust behavior remains intended.

> **Carryover status (run 21, `267660b`).** Ledger **Q-15** · fingerprint `b4df4a252b208b0a9fc83a396ba9d2342c60b86dd841fffae7ca872724cd328e` · status **`qa-bundled`** · severity `qa` · first seen `yield-claim-nft-17` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.

#### Run-18 enrichment (verbatim from `reports/18/submissions/qa-report.md`)

##### [Q-15] `PromotionUniV2_Eth.pool()` addLiquidity residual dust ignored — enriched <!-- id: ycn18q15 -->

**Status:** qa-bundled (QA) — carried from a prior run, **enriched** this run (same fingerprint
`b4df4a25…`, `lastSeenRun` → 18). By-design, NatSpec-documented, recoverable.

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol#pool`

**Description:** UniV2 `addLiquidity` consumes the two input legs at the pool's current ratio and
leaves a residual of whichever leg was over-supplied; the residual is intentionally left in the
contract (NatSpec-documented, recoverable via rescue). The run-18 enrichment (from ECON-03) is that
the asymmetric per-leg fee structure makes the residue **self-reinforcing**: phUSD tends to
accumulate as the residual over repeated `pool()` calls, and this interacts with the consolidated
`Pooled` event's reconciliation — the emitted pooled amounts do not net out the retained dust, so
off-chain accounting that reconciles against the event must account for the residual separately.

**Impact:** No asset loss (dust is recoverable), no availability impact. Accounting/observability
nuance for off-chain reconcilers plus a slow, bounded phUSD residue accumulation. Stays QA.

**Recommendation:** Document the asymmetric-fee residue accumulation alongside the existing
by-design note, and either net the retained dust in the `Pooled` event or document that consumers
must reconcile it separately. Periodic rescue of accumulated phUSD residue keeps the contract clean.
