# Carryover QA Report — originating audit 18 (carried into yield-claim-nft-19)

> **Carryover QA report — audit 18** (cut down from `reports/yield-claim-nft/18/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 19): **L-06 → see `qa-report-10.md`, Q-16, Q-17**.
> Removed as no longer live: **L-15** (`e64f73d6…`) — owner-triaged **wont-fix** 2026-07-19, a human disposal, so it is not carried. Removed as already carried elsewhere: **L-06** (`342075df…`) — still open, but audit 10 is its originating audit, so it is carried in `qa-report-10.md` rather than duplicated here; audit 18's own carryover block for **L-13** and **F-01-044** (both owner **wont-fix**) is likewise not copied. Not carried as open items: **Q-12**, **Q-13**, **Q-14**, **Q-15** — ledger status `qa-bundled` (already reported; automated-tool reconciliations, not untriaged open findings). They are reconciled by name in run-19's own `qa-report.md` (Appendix C tool-noise reconciliation), so nothing is silently dropped. Structural section not copied: "Appendix: Automated Findings (4naly3er)".
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers and links were accurate at the originating commit (`e4de393 (run-18)`); re-verify against current HEAD (`d4cc563`).
> These entries were **not re-examined** in the run-19 range (stories 046/047, dispatcher/streamer surface); they are carried for recall (Law 1), and their `lastSeenRun` was deliberately **not** bumped.
>
> ⚠ **Label-collision warning:** run-19's own C4 labels `L-04`/`L-05` are **new, unrelated findings** (ledger `L-19` / `9fdcb0c6…` and `L-20` / `1c1e0001…`). The `L-04`/`L-05` below are the **ledger** entries `674c799b…` / `e527a712…`. Do not conflate.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

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
