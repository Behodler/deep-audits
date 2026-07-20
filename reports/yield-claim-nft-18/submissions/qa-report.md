# QA Report for yield-claim-nft (run-18)

**Scope:** Regression scan @ `e4de393` (story-045 — `PromotionUniV2_Eth` rework: 60/30/10
split, half-phUSD burn, WBTC insurer reserve, settable `_legC`, insurer role, consolidated
`Pooled` event, `rescueERC20` WBTC-exclusion, donation-split-on-gross).

**Result:** No High or Medium severity findings, and no regressions. The story-045 rework was
verified faithful (F-01-045) and Law-1 clean (4 Tier-3 fork invariants confirmed at block
25,550,000; deterministic fork unit tests 70/70). This QA bundle collects the run's Low/QA
observations: 1 new Low (L-15, split out as a distinct sibling of L-06), 2 new QA notes (Q-16,
Q-17), 2 re-confirmed/enriched carried items (L-06, Q-15), the static-analysis QA notes already
ledgered this run (Q-12, Q-13, Q-14), and a carryover subsection for owner-accepted wont-fix items
(L-13, F-01-044). The automated 4naly3er GAS/NC/L report is referenced in the appendix.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 2 (L-06 carried/re-confirmed; L-15 new — PromotionUniV2_Eth MEV, sibling of L-06) |
| QA / Hardening | 6 (Q-12, Q-13, Q-14, Q-15, Q-16, Q-17) |
| Carryover (wont-fix, informational) | 2 (L-13, F-01-044) |
| **New this run** | **3 (L-15, Q-16, Q-17)** |

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

### [L-15] `PromotionUniV2_Eth.pool()` Legs A/B swap + addLiquidity at live pool ratio relies solely on pooler-supplied min-out floors with no on-chain price reference (MEV sandwich) <!-- id: ycn18l15 -->

**Status:** new this run (Low). Split out from L-06 as a **distinct sibling** on the
deduplicator's and severity-auditor's concurring recommendation, for independent per-contract fix
tracking (own fingerprint `e64f73d6…`, distinct from L-06's `342075df…`).

**Location:** `src/dispatchers/PromotionUniV2_Eth.sol#L443-L457` (Leg B swap) and `#L407-L415`
(LP add) — `pool()`.

**Description:** `pool()` executes on-chain swaps (Leg A `USDC→USDS(PSM)→sUSDS→phUSD` via Balancer
V3; Leg B `USDC→ETH→promotion` via UniV2) and then an `addLiquidity` into the phUSD/promotion pair
at the pool's **live ratio**. Slippage is protected **only** by the pooler-supplied minimum-out
floors (`minPhusdOut`, `minEthOut`, `minPromoOut`, `minWbtcOut`) plus the post-add `minLP` floor —
all five present and enforced — with **no on-chain price reference** (no spot/TWAP sanity bound).
The thin, two-hop `USDC→ETH→promotion` Leg B is the shallowest surface: if the keeper sets its
floors loosely relative to live depth, a searcher can sandwich the swap and/or the live-ratio LP
add.

**Impact:** Bounded and Low. Value at risk is **protocol-owned liquidity (POL) only** — no user
funds route through `pool()`, and the entry is keeper-gated (`onlyAuthorizedPooler`), so there is
no unprivileged zero-floor trigger. Loss is capped by the five present min-out floors + `minLP`,
which the keeper controls. Same severity ceiling as the sibling **L-06** class.

**Relationship to L-06 (sibling, do not re-fold):** Same root-cause class
(`onchain-priceless-lp-add-mev`), different contract and legs (two-leg UniV2 swap+add here vs
BalancerPoolerV2's single-sided sUSDS add). Tracked under its own label so a fix to one contract
does not silently close the other.

**Recommendation:** Keep the pooler min-out floors (especially Leg B's) tuned to live per-leg
depth; an on-chain spot/TWAP sanity bound on the swap and the LP-add ratio would remove the sole
reliance on the off-chain floor (not required to hold at Low). Fix per-contract independently of
the BalancerPoolerV2 sibling (L-06).

---

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

---

## Carryover (wont-fix, informational — reference only)

These items were reported in prior runs, re-observed this run on the story-045-reworked contract,
and are triaged **wont-fix** (owner-accepted). They are **unchanged by story-045** and no action is
owed. Full stubs: `submissions/carryover/`. Triage via `/ledger yield-claim-nft`.

### [L-13] `_legB` whole-balance ETH sweep + open `receive()` (Law-3 footgun) — wont-fix

- **Severity:** Low · **Status:** wont-fix (owner-accepted intended feature)
- **Location:** `src/dispatchers/PromotionUniV2_Eth.sol#L332-L346` (`_legB` / `receive`)
- **First seen:** run-17 · **Still present:** run-18 · **Fingerprint:** `ac8eadef…`
- **story-045 impact:** UNCHANGED — the whole-balance sweep and open `receive()` are not modified
  by story-045. Tier-3 INV-4 fork-proved non-theft.
- **Cross-ref:** F-01-044 (faithfulness twin, also wont-fix).
- **Original:** `reports/yield-claim-nft-17/submissions/qa-report.md`.

### [F-01-044] `_legB` whole-balance ETH sweep — spec-conformance nuance (informational) — wont-fix

- **Severity:** Low (informational faithfulness record) · **Status:** wont-fix (intended-by-design;
  under-specification basis closed by owner)
- **Location:** `src/dispatchers/PromotionUniV2_Eth.sol#L332-L346` (`_legB`)
- **First seen:** run-17 · **Still present:** run-18 · **Fingerprint:** `3e638eb9…`
- **story-045 impact:** UNCHANGED — no Law-1 escalation (Tier-3 INV-4 HELD, value never reaches a
  third party).
- **Cross-ref:** L-13 (security/footgun twin, also wont-fix).
- **Original:** `reports/yield-claim-nft-17/submissions/spec-conformance.md`.

> Note: spec-conformance faithfulness records (F-\*) live in the dedicated spec-conformance report,
> not in this QA bundle; F-01-044 is referenced here only because it is the twin of carryover L-13.

---

## Appendix: Automated Findings (4naly3er)

The canonical C4-style automated report was generated for this run and is attached at
[`reports/yield-claim-nft-18/4naly3er.md`](../4naly3er.md). It is a GAS / Non-Critical / Low
baseline (bot report); nothing in it rises to H/M, and its Low notes are style/hardening class
items already covered above or below the reporting bar per the Three-Law hierarchy. Highlights:

**Gas Optimizations — 20 categories.** Highest-instance items:
- GAS-7: operations that will not overflow could use `unchecked` — 148 instances
- GAS-8: use custom errors instead of revert strings — 96 instances
- GAS-12: functions that always revert for normal users can be `payable` — 66 instances
- GAS-2: use assembly for `address(0)` checks — 53 instances
- GAS-5: cache state variables in stack vars rather than re-reading — 47 instances

**Non-Critical — 30+ categories.** Notable:
- NC-2: missing `address(0)` checks when assigning address state vars — 11 instances (overlaps
  4naly3er L-3)
- NC-11: critical-parameter-change events should emit old + new value — 43 instances
- NC-13: functions longer than 50 lines — 159 instances
- NC-10: events missing `indexed` field — 22 instances

**Low (bot) — 14 categories.** Notable, and how they map to this report:
- L-6 (bot): division-by-zero not prevented — 1 instance
- L-7 (bot): empty `receive()` does not authenticate — 1 instance → same surface as our carryover
  **L-13** / **F-01-044** (open `receive()`), already triaged wont-fix
- L-14 (bot): sweeping may break accounting with multi-address tokens — 4 instances → same class as
  our L-13 whole-balance sweep, already covered
- L-1 / L-13 (bot): two-step ownership transfer — 10 / 7 instances (style hardening)
- L-2 (bot): tokens may revert on zero-value transfers — 15 instances
- L-11 (bot): loss of precision — 3 instances

No 4naly3er item introduces a finding not already surfaced in this report or intentionally held
below the bar. The full instance-level tables are in the attached `4naly3er.md`.
