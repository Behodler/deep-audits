# Carryover QA report — originating audit 22 (carried into yield-claim-nft-23)

> **Carryover QA report — audit 22** (cut down from `yield-claim-nft/reports/22/submissions/qa-report.md`; originating commit `0fd6bdf`). Carried at `c5ad56d` (`c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`), run 23, branch `master`. Original report: [`reports/22/submissions/qa-report.md`](../../../22/submissions/qa-report.md).
> Retained (still live in the ledger: `open` / `fix-pending`): **L-28, Q-24, Q-25**.
> Removed as no longer live: **L-26** (`b2a29359fd…`, `wont-fix`, owner triage 2026-10-07), **L-27** (`2268ead7cb…`, `fixed` @ `0fd6bdf`, human-applied 2026-10-19; fix verified in phoenix-phase-2-staging@e75ee07 run-41).
> Not carried (run-scoped framing, named so deletion is visible): § Awaiting triage, § Carryover index, Appendices A–B. Kept verbatim: run-22 title block and summary, the retained findings, § Q-21 numbers update (Q-21 is live `fix-pending`, carried in `qa-report-20.md`) and § Parked, not dropped.
> ⚠ **L-28 is `fix-pending` — FIX-PENDING (fix not yet landed).** `UniPoolerCutoverEscrow.sol` is unchanged in `0fd6bdf..c5ad56d`; the fix is routed to phStaging2 story-103, so a yield-claim-nft rescan that still sees L-28 is **not** an incomplete fix. LIFETIME-BOUND (triageReason 2026-10-10): once the mainnet cutover has succeeded, a human should close it `wont-fix` (obsolete — cutover completed, escrow consumed). Sanitizer: cutover likely complete (gate cleared 2026-10-24, block 26260804; not verified on chain by the sanitizer). Never auto-closed.
> Q-24 and Q-25 (and F-01-052, F-03-052, F-04-052 in `spec-conformance-22.md`) are cutover-lifetime escrow entries: candidates for the same human review once the cutover is confirmed.
> Labels are the originals — gaps in the sequence are the removals above, not omissions. Global issue IDs in `<!-- id: -->` stamps are run 22's, copied verbatim (never restamped). Run-22's own summary counts below describe run 22 as written; the retained count after pruning is the table below.
> **Why still valid:** the source changes in this run's range `0fd6bdf..c5ad56d` are the new `src/NFTBonfire.sol` (story-053), the deletion of `src/dispatchers/BalancerPoolerV2.sol` and the Balancer interfaces (story-050), and comment/NatSpec-only renames in `NudgeRatchetDelayRelease.sol`, `Uniboost.sol` and `IUniboostPooler.sol`. No retained entry's code logic changed (`NFTMinterV2.sol`, `src/hooks/**` and `src/migration/**` are unchanged), no fix landed for any of them, and no human triage disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-23 tool is **not** a fix.
> Line numbers were accurate at `0fd6bdf`; relative links resolve from `reports/22/submissions/`, not from this `carryover/` folder. Re-verify against `c5ad56d` before acting.
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 23) | Re-observed in run 23 | Contract |
> |---|---|---|---|---|---|---|---|
> | L-28 | ycn22l28 | `d77a482de757221d9ff311a43a46c11b40aa7df997199914fad7469d7128b209` | `fix-pending` | yield-claim-nft-22 | yield-claim-nft-22 | no (carried; code unchanged) | `src/migration/UniPoolerCutoverEscrow.sol` |
> | Q-24 | ycn22q24 | `88bfa94936213380dceec14420e7b0131b707e29a6d949878e162a3981c45936` | `open` | yield-claim-nft-22 | yield-claim-nft-22 | no (carried; code unchanged) | `src/migration/UniPoolerCutoverEscrow.sol` |
> | Q-25 | ycn22q25 | `b4c10f0f8938ec8a7bae9d6204cdc34844c8faf756807d56567dfa7aa0e1b5c9` | `open` | yield-claim-nft-22 | yield-claim-nft-22 | no (carried; code unchanged) | `src/migration/UniPoolerCutoverEscrow.sol` |

---
# QA Report for yield-claim-nft (run 22)

| | |
|---|---|
| **Project** | yield-claim-nft |
| **Run** | yield-claim-nft-22 |
| **Mode** | REGRESSION `267660b` → `0fd6bdf` (`master`) |
| **Audited commit** | [`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`](https://github.com/Behodler/yield-claim-nft/tree/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630) |
| **Change under review** | story-052: new `src/migration/UniPoolerCutoverEscrow.sol`, a one-off escrow that exits the Balancer BPT and seeds the empty canonical sUSDS/phUSD Uniswap V2 pair for `UniPoolerV2` (plus its tests and `test/mocks/MockV3ExitRouter.sol`) |
| **Story** | story-052 (`~/code/product-owner/stories/yield-claim-nft/review/yield-claim-nft-Balancexit/052-unipooler-cutover-escrow.md`), state folder **`review/`** |
| **Automated baseline** | [`4naly3er-report.md`](./4naly3er-report.md) (Appendix A) |

This bundle holds every new Low and QA item from run 22. There are **no High/Medium findings and no Centralization findings this run.** The Law-2 deviations (F-01-052 … F-04-052, `ycn22f1`–`ycn22f4`) are in [`spec-conformance.md`](./spec-conformance.md), not here. Open findings from earlier runs are **not** restated here. They are carried in full, one file per originating run, under [`carryover/`](./carryover/) (index in § Carryover).

_[§ Awaiting triage — run-22 triage table, superseded by the ledger and by this header; not carried.]_

---

## Summary

| Severity | New this run |
|----------|-------|
| Low Risk | 3 (L-26, L-27, L-28) |
| Centralization | 0 |
| QA / Non-Critical | 2 (Q-24, Q-25) |
| **Total new** | **5** |

| Other sections | Count |
|---|---|
| Borderline severities, stated per item | 2: **L-26** (Low vs Medium), **L-28** (Low vs QA) |
| Re-raise of an owner `wont-fix`, disclosed | 1: **L-26** re-raises the root of **L-24** `8511fd5206` (`wont-fix`) |
| `fix-pending` entries re-weighed | 1: **Q-21** `4c2f9c705c`, numbers update only, stays `fix-pending` (§ Q-21) |
| Carried-over open entries (`carryover/`) | 41 (32 QA-channel entries in 10 `qa-report-NN.md`, 9 faithfulness records in 5 `spec-conformance-NN.md`) |
| Shared root, counted once | **L-28** and **F-01-052** (`ycn22f1`, now Informational in `spec-conformance.md`) are one DEDUP-004 root, never two independent issues |

**Final review.** This bundle was corrected after the step-7 final review: [`../final-review-severity.json`](../final-review-severity.json) (severity second opinion) and [`../final-review-validity.json`](../final-review-validity.json) (validity). Every item here was confirmed valid and **no label in this bundle changed**: L-26, L-27, L-28 stay Low, Q-24 stays QA (non-critical), Q-25 stays informational. Prose and citation corrections applied: L-26 (dust `pair.mint` costs ~1,001 wei per side, not ~1 wei; mitigation framed as a pre-broadcast decision; Medium re-weigh triggers recorded), L-27 (story-052 L345 / L208 cited; abort-and-reuse window; cross-ref L-26/L-28), L-28 (tight tolerance sourced to `BalancerWinddownPlan.md` L385, not story-103; cost stated as tolerance-dependent; shared root with F-01-052), Q-24 (retitled to lead with the fork refutation), Q-25 (figures are closed-form, stray-sUSDS variant is counterfactual). The only severity change of the review is F-01-052, Low → Informational, in `spec-conformance.md`.

**Labels** continue the ledger sequence (last `Q-23` → `L-26`…`L-28`, `Q-24`, `Q-25`). The next free labels are **`L-29`, `Q-26`, `C-02`**. Every item's evidence is a fork test in `yield-claim-nft/work/test/run22/` at mainnet block 26,136,000 (chainid 1). No High or Medium finding means no PoC is required. Tier 3 found no counterexample on the real escrow: invariants 12/12 PASS on forge and Medusa with mutant controls, and Halmos 4/4 PASS with generality mutants.

---

## Low Risk Findings

_[L-26] removed as no longer live: `wont-fix`, owner triage 2026-10-07. See the header._

---

_[L-27] removed as no longer live: `fixed` @ `0fd6bdf`, human-applied 2026-10-19; fix verified in phoenix-phase-2-staging@e75ee07 run-41. See the header._

---

### [L-28] Tight off-chain exit floors plus a public-mempool `--slow` broadcast let anyone cheaply revert `exitAndSeed` (cost scales with the chosen tolerance). Story-052's claim that the operator gate prevents the mid-cutover front-run revert is incomplete <!-- id: ycn22l28 -->

**Severity:** Low (footgun). **Borderline Low vs QA** (see *Borderline* below).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L256-L266`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L256-L266) (floors passed to the exit). The design rationale is at [`#L63-L65`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L63-L65).

```solidity
///      The `operator` gate exists only to deny strangers control of timing and slippage floors
///      (sandwiching, front-running the cutover broadcast between `withdrawBPT` and
///      `exitAndSeed`, griefing `abort`). The custody guarantee does not depend on it.
...
        if (minAmountsOut.length != 2) revert UniPoolerCutoverEscrow__BadMinAmountsLength(minAmountsOut.length);
        for (uint256 i = 0; i < 2; i++) {
            if (minAmountsOut[i] == 0) revert UniPoolerCutoverEscrow__ZeroMinAmountOut(i);
        }
        ...
        _exit(mode, bptIn, minAmountsOut);
```

**Description:** Story-052 justifies the immutable-operator gate partly on the grounds that a stranger "front-running between the owner's `withdrawBPT` and `exitAndSeed` … would revert the forge broadcast mid-cutover". Story-103 broadcasts through the public mempool (`forge --broadcast --slow --ledger --legacy`, with no private relay, 103 L99), with floors quoted at simulation time. The runbook, phStaging2 `docs/BalancerWinddownPlan.md` **L385**, sets `minAmountsOut` to "the live proportional share minus a tight tolerance". (Story-103 L189 only asks for a quote helper with a tolerance argument, following `scripts/compute-min-bpt-poolerv2.js`, whose default is 100 bps = 1%. Story-052 L194 is a fork-test spec, not the runbook.) The gate does not stop the cheapest form of that front-run: any Balancer swap that moves one side past the tolerance makes the Vault revert. This is fork-proven at the repo's 1 bp tolerance. A 4 sUSDS → phUSD Balancer swap makes `exitAndSeed` revert with `AmountOutBelowMin(phUSD, 22,453.35e18, 22,454.12e18)`, and the griefer unwinds for a round-trip cost of 0.024 sUSDS (about $0.027) plus gas. **That cost is tolerance-dependent:** about $0.03 at the 1 bp test tolerance; at the story-103 helper-pattern default of 1% the griefer must move the pool roughly 100× further, a round trip of roughly a few hundred dollars notional (fees plus impact), still cheap and still unprofitable. Organic Balancer flow during the multi-tx `--slow` broadcast can trip the same check with no attacker. ECON-001 (see Q-24) proves a loose floor gives up no value, because sandwiching is net-negative. So the tight tolerance buys **no** economic protection and only maximises griefability.

**Impact:** Funds are safe: the tx is atomic, the BPT stays in the escrow, and the operator can re-quote and retry, or `abort()`. The impact is repeated liveness denial of the cutover at a tolerance-dependent cost per attempt (~$0.03 at 1 bp; roughly a few hundred dollars notional at 1%), plus a mid-broadcast revert that leaves the story-103 forge progress file inconsistent.

**Borderline (Low vs QA).** *For QA:* the revert is temporary, and both retry and `abort()` remain available. *For Low (the classification):* the runbook's own "tight tolerance" advice (`BalancerWinddownPlan.md` L385) maximises griefability while buying no protection, and a mid-broadcast revert poisons the progress file. That is a concrete operational hazard with a cheap fix, and a competent operator would expect tighter floors to be strictly safer. It is not Medium: the delay is recoverable, the operator can mitigate it, and no value is at risk.

**Recommended mitigation:** Size the exit tolerance for griefing resistance (e.g. 0.5–1%), not tight. ECON-001 shows sandwiching is net-negative at 1% and 5%. Use a private relay for `exitAndSeed` if one is available. Document that floor reverts are expected and recoverable, and how the progress file resumes after an `exitAndSeed` revert.

**Evidence:** `work/test/run22/EscrowSandwichEcon.fork.t.sol::test_run22_econ_tightFloor_griefCost` PASS (trace: Vault `AmountOutBelowMin(phUSD, 22,453.35e18, 22,454.12e18)`; grief round-trip cost 23961190401828642 wei sUSDS); `::test_run22_econ_sandwich_tol{100,500}bps_{buy,sell}Phusd` PASS.

*Fingerprint `d77a482de757221d9ff311a43a46c11b40aa7df997199914fad7469d7128b209` (`UniPoolerCutoverEscrow.sol:exitAndSeed:griefing-dos-tight-floors`). issueId `ycn22l28`. Sources: ECON-002, F-01-052 (DEDUP-004 / CLASS-22-03). The story-rationale half is filed separately as **F-01-052** (`ycn22f1`, Informational after final review) in `spec-conformance.md`. They share one root and are **not** counted as two independent issues in any tally. Related: Q-24 covers the same floors and the opposite failure mode.*

---

## QA / Non-Critical Findings

### [Q-24] Sandwich value-leak hypothesis on the escrow's exit and seed refuted on fork (attacker net-negative). Residual defence-in-depth note: by documented design (story-052 L223) price protection is off-chain, `minAmountsOut` is checked only for length 2 and non-zero, and the V2 seed inherits the Balancer spot ratio with no band <!-- id: ycn22q24 -->

**Severity:** QA (informational / defence in depth).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L256-L270`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L256-L270)

```solidity
        if (minAmountsOut.length != 2) revert UniPoolerCutoverEscrow__BadMinAmountsLength(minAmountsOut.length);
        for (uint256 i = 0; i < 2; i++) {
            if (minAmountsOut[i] == 0) revert UniPoolerCutoverEscrow__ZeroMinAmountOut(i);   // 1 wei passes; order unchecked
        }
        ...
        // 5. Seed with the whole balances.
        uint256 s = IERC20(_sUSDS).balanceOf(address(this));
        uint256 p = IERC20(_phUSD).balanceOf(address(this));
        liquidity = _seed(s, p, deadline);                     // ratio = Balancer composition at exit
```

**Description:** Off-chain price protection is the documented design, not a defect: story-052 L223 makes `minAmountsOut` the exit's slippage guard. On-chain validation of `minAmountsOut` is minimal. A floor of 1 wei passes, and the token order is never checked against the pool's `[sUSDS, phUSD]`. The V2 seed ratio is whatever composition the Balancer pool has at exit, and story-103's floors are quoted from live state. So a pre-skewed Balancer pool would be baked into both the floors and the V2 seed price. Checked on-chain: the pool is a hookless 50/50 weighted pool (constant-product, like V2) with a 0.3% fee. For two constant-product venues, an LP position's value at a given price depends only on its invariant. Back-arbitraging both venues returns the attacker roughly their own slippage minus 0.3% fees on each leg, and protocol-owned liquidity is not extracted. Because the pool has no hooks, no V3 hook can adjust amounts or call back. The residual risk is a wrong-order or loose floor (PATTERN-002), which the escrow cannot detect.

**Impact:** None demonstrated. On fork, a sandwich that skews the Balancer pool inside the floors loses money for the attacker (−1.753 sUSDS at 1% tolerance, −8.808 sUSDS at 5%), and the protocol's seeded invariant rises slightly (+0.96 / +4.82 sUSDS at p0). This assumes the pool stays a hookless 50/50 weighted pool. A different curve or hooked pool would reopen the question.

**Recommended mitigation:** In `UniPoolerCutoverCore`, assert that `getPoolTokenInfo` order is `[sUSDS, phUSD]` when building `minAmountsOut`. Optionally add an on-chain ratio band on the seed.

**Evidence:** `work/test/run22/EscrowSandwichEcon.fork.t.sol::test_run22_econ_sandwich_tol100bps_buyPhusd` / `_sellPhusd` / `tol500bps_buyPhusd` / `_sellPhusd` PASS.

*Fingerprint `88bfa94936213380dceec14420e7b0131b707e29a6d949878e162a3981c45936` (`UniPoolerCutoverEscrow.sol:exitAndSeed:offchain-only-slippage-floor`). issueId `ycn22q24`. Sources: LOCAL-003, PATTERN-002, PATTERN-003, CODE-003, ECON-001, PATTERN-MR-001 (DEDUP-003 / CLASS-22-04). Related `wont-fix` entries: L-22 `a846cc40e6…` (tolerance is an accepted MEV budget) and L-06 `342075dfba…`. L-06's own triageReason says "If BalancerPoolerV2 is NOT retired, or is re-used by new code, this disposition should be revisited". It was revisited here and the conclusion is QA, so this is **not** suppressed under L-06. PATTERN-002/003's mechanical "potential-high" did not set the label.*

---

### [Q-25] After the cutover, the third party's 37.1% Balancer remainder stays a live second venue at the same price, so part of the Stage-4 peg lift is arbitraged into it ($8–$11 at current depth; V2 settles at ~$0.9735, not $1) <!-- id: ycn22q25 -->

**Severity:** QA (informational, opportunity cost).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L268-L270`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L268-L270)

```solidity
        uint256 s = IERC20(_sUSDS).balanceOf(address(this));
        uint256 p = IERC20(_phUSD).balanceOf(address(this));
        liquidity = _seed(s, p, deadline);
```

**Description:** The escrow migrates only the protocol's 62.9% share. The external EOA's 37.1% (11,007 sUSDS / 13,249 phUSD) stays on Balancer at the same price and remains swappable until Balancer swaps stop or that LP exits. Any later price lift on the V2 pair is partly arbitraged into the remainder. The figures below come from a **closed-form** constant-product model (ECON-004, confidence medium) on fork-state inputs. They were **not** fork-executed. Constant-product model, 0.3% fees on both venues:

- **Zap Δ\* = 1,540 sUSDS** (V2 to $1.000): the arbitrage moves 259.5 sUSDS through and nets 9.68 sUSDS (~$11). V2 settles at **$0.9735**, Balancer at $0.9678.
- **Stray-sUSDS variant (counterfactual, off the story-103 path):** if the old pooler's idle 1,308.1 sUSDS had been routed through the escrow before `exitAndSeed`, instead of `rescueERC20` → `UniPoolerV2` as story-103 step 9 specifies, the seed price becomes $0.9885 and the arbitrage nets 6.84 sUSDS (~$8).

The profile's claim that donor strays sent to the escrow are seeded as 100% POL at the donor's cost is confirmed.

**Impact:** Opportunity cost only, about $11 on the story-103 path (the ~$8 figure is the counterfactual variant), and nobody is harmed. Per the project rule, over-payment or misallocation of externally-derived yield is opportunity cost, not a value leak. This is distinct from **Q-21** (plan §5 zap sizing against seeded depth), which is a separate subject.

**Recommended mitigation:** Note in story-103 / plan §5 that the 37.1% Balancer remainder absorbs part of the peg lift until swaps stop or the LP exits, and resize the Stage-4 zap chunks for the combined depth.

**Evidence:** ECON-004 closed-form constant-product model on fork-state inputs (block 26,136,000), confidence medium.

*Fingerprint `b4c10f0f8938ec8a7bae9d6204cdc34844c8faf756807d56567dfa7aa0e1b5c9` (`UniPoolerCutoverEscrow.sol:exitAndSeed:cross-venue-arb-remainder`). issueId `ycn22q25`. Source: ECON-004 (DEDUP-007 / CLASS-22-05). Bundled into the Q sequence per the Q-21 precedent for informational items.*

---

## Q-21 (`fix-pending`): numbers update, reference only

**Q-21** (`ycn20q21`, fingerprint `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6`, `fix-pending`) is **not** re-filed or restated here. The full entry is carried in [`carryover/qa-report-20.md`](./carryover/qa-report-20.md). `UniPoolerV2.sol` is unchanged in `267660b..0fd6bdf`. This run's re-weigh (ECON-003 + F-03-052, DEDUP-006; recorded in `reconciliation-log.json → fix-pending[0]`) only updates the numbers:

- The seed price inherited from Balancer is **~0.924 USDS/phUSD at block 26,136,000**. Plan §5 assumed 0.971 at block 26,093,540. Seeded share: 18,656.33 sUSDS / 22,456.37 phUSD (on-chain `Vault.getPoolTokenInfo` balancesRaw `[29663475643465047886662, 35705515073095210602274]`, sUSDS rate 1.1119186).
- phUSD now crosses $1 at a zap of **~$1,711.7**, not the ~$638 of the story-108 plan re-baseline or Q-21's original ~$636. That is about **2.7×**.
- **Status stays `fix-pending`; do not propose `fixed`.** Story-108's plan-§5 re-baseline (the fix intended for Q-21) landed and is itself already stale by 2.7×, so treat this as a plan-side incomplete fix. The plan figure moves with the market, so any fix should state its block and require a live re-quote before Stage 2 rather than a fixed number. The unenforced human seed-price confirmation is filed separately as F-03-052 (`ycn22f3`) in `spec-conformance.md`, and the human may fold it into Q-21.

---

_[§ Carryover — run-22 index of earlier carryover files, superseded by `reports/23/submissions/carryover/`; not carried.]_

---

## Parked, not dropped

These run-22 items are in `manual-review.json` and await a human decision. None of them was quality-filtered out.

- **PATTERN-MR-003** (`UniPoolerCutoverEscrow`, contract-wide): no rescue for non-protected tokens, and losing the immutable operator's key strands the escrow. Story-052 accepts this as INFO (Law-3 design). It is the generic stranding mechanism behind L-27, with a different mitigation.
- **PATTERN-MR-004** (`wrapUsds :287`, hint "potential-high", low confidence): the ERC-4626 deposit has no min-shares. Pattern-matcher and econ-scanner cleared it (sUSDS is priced off the `chi` accumulator, and the old pooler's USDS is 4.7e11 wei). Kept visible for that reason.
- **PATTERN-MR-005** (`_requireEmptyPair :366`): `skim(_newPooler)` leaves skimmed phUSD on `UniPoolerV2`, reachable only through the owner's `rescueERC20` (story-052 accepts this). `PairSkimmed` emits pre-skim balances, which is correct only because reserves are 0.
- PATTERN-MR-001/-002 (escrow) are kept verbatim as supporting context for Q-24/L-27. Three run-21 `UniPoolerV2` pattern items are carried unchanged.

---

_[Appendices A (4naly3er) and B (static tool-noise bucket) — run-22 tool output, regenerated each run; not carried.]_
