# Carryover QA Report — originating audit 18 (carried into yield-claim-nft-20)

> **Carryover QA report — audit 18** (cut down from `yield-claim-nft/reports/18/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 20): **Q-16, Q-17 (plus the run-18 sections for still-open L-06, Q-15, Q-12, Q-13, Q-14)**.
> Removed as no longer live: L-15 (wont-fix, owner 2026-07-19 — note run-20 **L-23** `c15c71fd…` re-raises only the new cross-contract shared-venue coupling, with L-15's triageReason disclosed verbatim); the "Carryover (wont-fix, informational — reference only)" block for L-13 and F-01-044 (both wont-fix).
> Structural sections not copied (they carry no live findings of their own): title block + Summary, Appendix (4naly3er).
> Retained counts: QA 2 originating (+1 Low and 4 QA re-statement sections).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Re-observed in run 20: Q-12, Q-13, Q-15 (see qa-report-17.md). Q-16 is NOT re-flagged but stays live (half-burn NatSpec still present). **Q-17 is PROPOSED for false-positive / tooling reclass** — `test/Tier3PromotionInvariants.t.sol` is absent from `git ls-tree` at both `d4cc563` and `2bfa090` (audit-authored harness); status left `open`, human decides. **Q-14** is proposed `fixed` (see qa-report-17.md).
> Line numbers and links were accurate at the originating commit, and relative links reflect the repository
> layout of that run (`reports/yield-claim-nft/NN/`, `lib/yield-claim-nft/src/...`); the source now lives at
> `yield-claim-nft/src/src/...`. Re-verify every location against current HEAD `2bfa090`.
>
> Triage any of these with `/ledger yield-claim-nft`.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

---

## Low Risk Findings

### [L-06] Single-sided / thin-leg LP-add relies solely on off-chain keeper min-out with no on-chain price reference (MEV sandwich) <!-- id: ycn18l6 -->

**Status:** open (Low) — re-confirmed this run on the story-045-reworked legs; not a new finding
(same fingerprint `342075df…`, `lastSeenRun` advanced to run-18).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol` (Legs A/B `pool()` path); sibling class
originally on `src/dispatchers/BalancerPoolerV2.sol#pool` / `unlockCallback`.

**Description:** The pooling legs execute a swap-then-add-liquidity with slippage bounded only by
off-chain keeper-supplied minimum-out floors (`minPhusdOut`, `minPromoOut`, `minLp`, and the new
`minWbtcOut`), with no on-chain price reference. On the reworked contract this class re-appears on
Legs A/B; the thin ETH→promotion Leg B has a novel, comparatively shallow depth that a searcher
could sandwich if the keeper floors are set loosely. Value at risk is protocol-owned liquidity
(POL) only — no user funds route through this path.

**Impact:** Bounded. Loss is capped by the five keeper min-out floors plus `minLP`, and is
POL-only. Stays Low.

**Recommendation:** Keep keeper min-out floors tuned to live depth per leg (Leg B especially).
An on-chain spot/TWAP sanity bound would remove the sole reliance on the off-chain floor, but is
not required to hold the finding at Low. Tune per-contract; the mitigation is tracked
independently from the Balancer sibling instance.

> **Note on L-06 vs L-15 (regression-tracking hygiene):** L-06's ledger `contract` field is
> `src/dispatchers/BalancerPoolerV2.sol` (single-sided sUSDS LP-add). The `PromotionUniV2_Eth`
> Legs-A/B MEV instance is the SAME root-cause class but a DISTINCT contract and distinct legs, so
> it is now tracked separately as **L-15** below rather than folded into L-06. Folding would risk a
> silent cross-contract closure — if BalancerPoolerV2's L-06 were later marked `fixed`, the
> PromotionUniV2_Eth instance would have closed with it despite untouched code. L-06 above remains
> the BalancerPoolerV2 single-sided-add instance only.

## QA / Hardening Findings

### [Q-16] `PromotionUniV2_Eth.pool()` NatSpec under-explains the half-phUSD burn — correct on value-matching, silent on the deflationary-spend half of its role <!-- id: ycn18q16 -->

**Status:** new this run (QA). Surfaced as ECON-01 / L-14 by the econ-scanner, downgraded Low → QA
by the sanitizer (documentation-vs-effect transparency nit; no asset/value/availability impact).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol#L349-L353`, `#L392-L394` (`pool`)

**Description:** The `pool()` NatSpec states that the half-phUSD burn is required so the pooled-phUSD
value (~30%) value-matches the pooled-promotion value (~30%). That statement is **correct**, not a
misstatement: because Leg A is deliberately over-sized to **60%** of capital, burning half of it is
**precisely** what pulls the pooled phUSD from 60% down to the ~30% that matches Leg B — so the burn
genuinely **is** part of the value-match mechanism. What the NatSpec **omits** is the burn's dual
role: given the 60% over-sizing, that same burn is simultaneously an intentional
**~30%-of-`pool()`-capital permanent deflationary spend** that produces zero LP. The defect is an
**under-explanation** (the deflationary-spend half of the burn's role is undocumented), **not** a
mischaracterization of the value-match half.

**Impact:** No asset, value-leak, or availability impact. The behavior is story-045-faithful and
Law-1 clean: the burn is backing-accretive (supply-reducing, intra-protocol), there is no theft,
and fork verification confirmed a 5000e6 USDC input burns 1359e18 phUSD as designed. The QA value
is preserving the burn's **dual-role clarity** — value-match rebalance **and** ~30%-of-capital
deflationary spend — so that no future maintainer, reading only the value-match half of the
rationale, deletes or resizes the burn as "redundant to the leg sizing." Removing it would leave
the pooled phUSD at 60% (breaking the value-match the NatSpec **does** document) and silently drop
the intended deflationary economics. Retained (not dropped) precisely to prevent that.
(Cross-ref: F-01-045 spec-conformance.)

**Recommendation:** Augment (do not rewrite) the NatSpec at L349-353 and L392-394: keep the
existing correct statement that the burn brings the 60%-sized phUSD leg down to the ~30% that
value-matches Leg B, and **add** that this same burn is by design a permanent
~30%-of-`pool()`-capital deflationary spend that produces no LP — so a maintainer understands the
burn carries **both** roles and must not be removed or resized.

---

### [Q-17] Tier-3 stateful-fuzz harness calls the pre-story-045 5-arg `pool()`; fails to compile, so the reworked flow is not fuzzed <!-- id: ycn18q17 -->

**Status:** new this run (QA). Test-infrastructure coverage gap (Law-1 adjacent — recall risk, not
a live vulnerability).

**Location:** `test/Tier3PromotionInvariants.t.sol`

**Description:** The run-16 stateful-fuzz harness invokes the old 5-argument signature
`pool(amountIn, 0, 0, 0, 0)`. story-045 changed `PromotionUniV2_Eth.pool` to a 6-argument
signature (added `minWbtcOut` for the WBTC insurer-reserve leg). The harness therefore fails to
compile, so the Medusa/Foundry invariant campaigns do **not** exercise the reworked split / burn /
WBTC value flow. This is the vacuous-harness / silent-coverage-gap pattern: a green-looking suite
that no longer touches the changed path.

**Impact:** Stateful-fuzz coverage of the exact code story-045 reworked is silently dropped. Actual
coverage this run is provided by the deterministic fork unit tests (70/70 pass) and the 4
empirically-confirmed Tier-3 fork invariants; the fuzz harness needs a refresh to restore the
stateful campaigns.

**Recommendation:** Refresh `Tier3PromotionInvariants.t.sol` to the 6-arg
`pool(amountIn, minPhusdOut, minPromoOut, minLp, minWbtcOut, …)` signature (match the current
story-045 ABI) so the invariant campaigns compile and re-exercise the reworked split/burn/WBTC
flow.

---

### [Q-15] `PromotionUniV2_Eth.pool()` addLiquidity residual dust ignored — enriched <!-- id: ycn18q15 -->

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

---

### [Q-12] `block.timestamp` swap/LP deadlines give no effective expiry on router calls <!-- id: ycn18q12 -->

**Status:** qa-bundled (QA), static-analysis-sourced, already ledgered this run (`69f9f9ca…`).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol` (router swap / addLiquidity calls)

**Description:** Router calls pass `block.timestamp` as the deadline, which is always satisfied at
execution time and therefore provides no protection against a transaction being held and executed
in a later, less favorable block. Slippage protection here rests entirely on the keeper min-out
floors (see L-06).

**Recommendation:** Pass a caller-supplied deadline (or `block.timestamp + bounded_window`) so a
held/delayed transaction expires rather than executing at a stale price.

---

### [Q-13] Unchecked UniV2 router swap return values on the ETH legs of `_legB` <!-- id: ycn18q13 -->

**Status:** qa-bundled (QA), static-analysis-sourced, already ledgered this run (`28ad3574…`).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol#_legB`

**Description:** The UniV2 router swap return values (amounts out) on the ETH legs of `_legB` are
not captured or checked. Effective slippage protection comes from the router's own `amountOutMin`
argument, but ignoring the returned amounts removes an on-contract sanity check and any ability to
react to a partial/degenerate fill.

**Recommendation:** Capture and assert the router swap return values against the expected minimums
in-contract, in addition to the router-level `amountOutMin`.

---

### [Q-14] Unchecked Balancer `settle` return value in `unlockCallback` <!-- id: ycn18q14 -->

**Status:** qa-bundled (QA), static-analysis-sourced, already ledgered this run (`e5d7aff2…`).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol#unlockCallback`

**Description:** The return value of the Balancer `settle` call in `unlockCallback` is not checked.
A mismatch between the settled amount and the expected amount would go undetected on-contract.

**Recommendation:** Check the `settle` return value against the expected settled amount and revert
on mismatch.

