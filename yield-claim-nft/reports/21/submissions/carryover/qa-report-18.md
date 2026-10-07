# Carryover QA Report — originating audit 18 (carried into yield-claim-nft-21)

> **Carryover QA report — audit 18** (pruned copy of `yield-claim-nft/reports/18/submissions/qa-report.md`; originating commit `e4de393`; carried at `267660b`, run 21).
> Retained (still `open`): **Q-16, Q-17**.
> Removed as disposed: **L-15** (`e64f73d629`, `wont-fix`), the re-confirmed **L-06** (`wont-fix`), **Q-12** (`wont-fix`), and the "Carryover (wont-fix)" block (L-13, F-01-044, both `wont-fix`). The run-18 Q-13/Q-14/Q-15 sections are carried under their run-17 parents in `qa-report-17.md`. The 4naly3er appendix is not copied.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder, and many point at the retired `lib/yield-claim-nft/...` reference tree. Re-verify every location against `267660b` before acting.
> Global issue IDs in the `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped). Where an originating report minted an ID inconsistently (run 08 stamped QA items with `l`), the original stamp is kept and the discrepancy is noted, not corrected.
> *The finding text below each heading is a verbatim copy of the originating report; the `Carryover status` block after each section is added by the run-21 qa-bundler.*

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

> **Carryover status (run 21, `267660b`).** Ledger **Q-16** · fingerprint `78164abf6f5f86df8777996396174cf5dfd8bdebc88ad1f77c58910e3e9c38d2` · status **`open`** · severity `qa` · first seen `yield-claim-nft-18` · last seen `yield-claim-nft-18` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

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

> **Carryover status (run 21, `267660b`).** Ledger **Q-17** · fingerprint `696cc3452e1c247e3e8eaff37e543a5ec9e9278c8379fbbf20db9d33bbc474c5` · status **`open`** · severity `qa` · first seen `yield-claim-nft-18` · last seen `yield-claim-nft-19` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
