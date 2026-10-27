# Carryover Spec-Conformance report — originating audit 22 (carried into yield-claim-nft-23)

> **Carryover Spec-Conformance report — audit 22** (cut down from `yield-claim-nft/reports/22/submissions/spec-conformance.md`; originating commit `0fd6bdf`). Carried at `c5ad56d` (`c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`), run 23, branch `master`. Original report: [`reports/22/submissions/spec-conformance.md`](../../../22/submissions/spec-conformance.md).
> Retained (still live in the ledger: `open` / `fix-pending`): **F-01-052, F-03-052, F-04-052**.
> Removed as no longer live: **F-02-052** (`5a7732a4ea…`, `fixed` @ `0fd6bdf`, human-applied 2026-10-19; verified in phoenix-phase-2-staging@e75ee07 run-41).
> Not carried (named so deletion is visible): § Carried-over faithfulness records index. The run-22 header's `⚠ Awaiting triage` line and the summary table are run 22's as written; F-02-052 has since been fixed.
> Labels are the originals — gaps in the sequence are the removals above, not omissions. Global issue IDs in `<!-- id: -->` stamps are run 22's, copied verbatim (never restamped). Run-22's own summary counts below describe run 22 as written; the retained count after pruning is the table below.
> **Why still valid:** the source changes in this run's range `0fd6bdf..c5ad56d` are the new `src/NFTBonfire.sol` (story-053), the deletion of `src/dispatchers/BalancerPoolerV2.sol` and the Balancer interfaces (story-050), and comment/NatSpec-only renames in `NudgeRatchetDelayRelease.sol`, `Uniboost.sol` and `IUniboostPooler.sol`. No retained entry's code logic changed (`NFTMinterV2.sol`, `src/hooks/**` and `src/migration/**` are unchanged), no fix landed for any of them, and no human triage disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-23 tool is **not** a fix.
> Line numbers were accurate at `0fd6bdf`; relative links resolve from `reports/22/submissions/`, not from this `carryover/` folder. Re-verify against `c5ad56d` before acting.
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 23) | Re-observed in run 23 | Contract |
> |---|---|---|---|---|---|---|---|
> | F-01-052 | ycn22f1 | `2d7b84f0f5ed82d327da39d4b1208e07cc5b69619c8d3b248b354fe96dfb454e` | `open` | yield-claim-nft-22 | yield-claim-nft-22 | no (carried; code unchanged) | `src/migration/UniPoolerCutoverEscrow.sol` |
> | F-03-052 | ycn22f3 | `8ab7d54dc97ff12b9514c44ee52ee1c9fe55fcf74fd8a74ec59e171bd2c46eaf` | `open` | yield-claim-nft-22 | yield-claim-nft-22 | no (carried; code unchanged) | `src/migration/UniPoolerCutoverEscrow.sol` |
> | F-04-052 | ycn22f4 | `298ee7bb3b0bab68c0f7ca5a3e50034561ca621c81b33b4673e7a18cc4f4d137` | `open` | yield-claim-nft-22 | yield-claim-nft-22 | no (carried; code unchanged) | `src/migration/UniPoolerCutoverEscrow.sol` |

---
# Spec-Conformance Report (Law-2 Faithfulness): yield-claim-nft, run 22

- **Run:** `yield-claim-nft-22` · regression `267660b..0fd6bdf` · branch `master` · HEAD `0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`
- **Commits in range:** `2e4a28c [story-052] RED`, `0fd6bdf [story-052] GREEN` ("implement UniPoolerCutoverEscrow (operator-gated exit+seed, wrapUsds, abort to old pooler); tighten fork case-2 revert to Vault PoolPaused"). The commit bodies contain only the subject line and match the story document. The commits and the document do not diverge.
- **Story in range:** story-052, UniPoolerV2 cutover escrow. **State: `review`** (Review Status `ISSUES_FOUND`). The code has landed while the story is still in review, so its acceptance criteria may still change (see F-04-052).
  - story-052: `~/code/product-owner/stories/yield-claim-nft/review/yield-claim-nft-Balancexit/052-unipooler-cutover-escrow.md`. Resolved by globbing the whole tree (`find ~/code/product-owner/stories/yield-claim-nft -type f \( -name '052-*.md' -o -name '052.*-*.md' \)`), which returned exactly one hit.
  - Consumer story: phStaging2:103 (`incomplete`), `~/code/product-owner/stories/phStaging2/incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md`.
  - Related: yield-claim-nft:050 (`incomplete`; must keep `src/migration/`) and phStaging2:108 (`complete`; the plan-§5 re-baseline intended to fix Q-21).
- **Contract:** `src/migration/UniPoolerCutoverEscrow.sol` (new, +425 lines). It is the only `src/` change in the range.

> **⚠ Awaiting triage:** all four records below (F-01-052 … F-04-052) are `open` with no human decision. F-02-052 and F-03-052 carry human-only decisions that must land before the Stage-2 broadcast. The consolidated triage list, including the cutover-relevant carryovers, is in [`qa-report.md` § Awaiting triage](./qa-report.md#-awaiting-triage).

## Purpose

This report covers Law 2 only: does the feature do what its `[story-NNN]` document says? It is kept separate from the QA bundle (`qa-report.md`). Of the four deviations, F-01-052 also has a security half, which is filed as **L-28** in the QA bundle; the two share one root and are counted once. None of the four has asset or value impact, and none needs an H/M label.

**Final review.** This report was corrected after the step-7 final review: [`../final-review-severity.json`](../final-review-severity.json) (severity second opinion) and [`../final-review-validity.json`](../final-review-validity.json) (validity). All four records were confirmed valid. One severity changed: **F-01-052, Low → Informational** (the story text is incomplete rather than false, the causal link to the tight tolerance was not shown, and its security weight is already carried by L-28, which stays Low and open; no recall is lost). Other corrections are prose only: F-01-052 (`BalancerWinddownPlan.md` L385 cited as the tight-tolerance source; the "one broadcast?" amendment question dropped), F-02-052 (impacts (b) and (c) labelled conditional; (d) kept out of the severity basis), F-04-052 (landing before close is story-052's designed sequence). F-02-052 stays Low, F-03-052 and F-04-052 stay informational.

## Verdict

| Story | Verdict |
|---|---|
| story-052 | **The code is faithful. All 18 acceptance criteria are met, with 0 FAIL.** The four deviations are in the story text and in its hand-off to phStaging2:103, not in the implementation: F-01-052 (incomplete threat model for the operator gate), F-02-052 (a stale on-chain premise about the owner's 202.30 BPT), F-03-052 (a human seed-price confirmation that no gate enforces), and F-04-052 (the code landed while the story is in review). |

### Per-criterion conformance (summary)

Source: `reports/22/faithfulness-findings.json → conformanceMatrix`. Line numbers refer to `UniPoolerCutoverEscrow.sol` at `0fd6bdf`.

| # | Criterion (story-052 line) | Verdict | Evidence |
|---|---|---|---|
| 1 | Immutable, non-zero `operator` gates every state-changing function; no Ownable, `transferOwnership` or renounce (L36) | PASS | L95 immutable; `onlyOperator` L176-179 on `exitAndSeed`/`wrapUsds`/`abort`; zero check in the constructor at L190 |
| 2 | Constructor reads pair, router, sUSDS and phUSD from `newPooler`, and snapshots `oldPooler.pool()` and `primeToken()` (L46-49) | PASS | L195-200, stored as immutables at L213-222 |
| 3 | `oldPooler.sUSDS()==newPooler.sUSDS()` and `asset()==USDS` (L50) | PASS | L208-211 |
| 4 | Constructor rejects zero addresses (L52) | PASS (exceeds) | Checks the arguments and also the values read from the poolers |
| 5 | Step 1: skim to `newPooler` only if reserves are (0,0) and balances are non-zero, then require both to be (0,0) (L58) | PASS | L365-374 |
| 6 | Step 2: `bptIn = BPT.balanceOf(this) > 0` (L59) | PASS | L252-253. The premise in the same sentence is stale: see **F-02-052** |
| 7 | Step 3: `minAmountsOut` has length 2 and every entry is > 0; deadline in (now, now+1 day] (L61-62) | PASS | L256-262; `MAX_DEADLINE_WINDOW = 1 days` |
| 8 | Step 4: forceApprove, proportional or recovery exit chosen by `mode` (never derived from the clock), approval reset, BPT == 0 afterwards (L64-66) | PASS | `_exit` L380-388 |
| 9 | Step 5: seed the whole sUSDS/phUSD balances, require exact consumption, LP minted to `newPooler`, reserves == seeded, approvals reset (L67-71) | PASS | L268-270, `_seed` L394-411 |
| 10 | Step 6: escrow left empty; `Seeded` emitted (L72) | PASS | L273-277 |
| 11 | `wrapUsds` checks, `deposit(amt, newPooler)`, approval reset, event (L76-80) | PASS | L283-291 |
| 12 | `abort` sends everything to `oldPooler` only (L85-88) | PASS | L295-301, `_returnAll` L415-418. The `setPool` footgun (CODE-002 / L-27) is beyond the story text and is not a deviation |
| 13 | No `receive`/`fallback`; views only otherwise (L92-93) | PASS | |
| 14 | No caller-chosen recipient anywhere (L25) | PASS | Every destination is an immutable |
| 15 | File-local interfaces, 050 grep clean, only `src/migration/` touched (L97-110, L197-198) | PASS | grep returns rc=1; `git diff --stat 267660b -- src` shows only the escrow file |
| 16 | Mock exit router is faithful to mainnet (L182) | PASS (stricter) | Burns against the router allowance; `paused` and `recoveryMode` are separate flags |
| 17 | Unit-test coverage list (L184-192) | PASS | 37/37 re-run at `0fd6bdf`. The invariant is not vacuous: the seed path was reached in 70 of 386 runs |
| 18 | The fork test must fail, not skip, without an RPC, and must assert that the fork ran (L196) | PASS | `[FAIL …] setUp()` without an RPC; 4/4 PASS with one. Caveat: the assertions that the owner's BPT balance is unchanged are trivially true, because the owner holds 0 BPT (F-02-052) |
| — | `forge fmt --check` / `build --sizes` / `test` pass (L199) | Unticked in the story | Failures predate the story (9 unformatted files; `PromotionUniV2_Eth` at 24,770 B is over EIP-170). See **F-04-052** |

**Law-1 override check:** no story was escalated as unsafe (`storyUnsafeFindings: 0`). See the [Law-1 assessment](#law-1-assessment-no-unsafe-story) below.

---

## F-01-052: story-052's rationale for the immutable-operator gate is incomplete: the gate prevents the named stranger-calls-`exitAndSeed` front-run, but not the gate-independent mid-cutover revert vector

- **Ledger:** `ycn22f1` · fingerprint `2d7b84f0f5ed82d327da39d4b1208e07cc5b69619c8d3b248b354fe96dfb454e` · **Informational** (was Low; downgraded by final review) · status `open`
- **Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L63-L65`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L63-L65) (NatSpec repeating the rationale) and L256-266 (floor check, then `_exit`)
- **Detail:** `reports/22/findings/faithfulness/F-01-052-faithfulness-story052-operator-gate-threat-model-overstated.json`
- **Cross-ref:** security half is **L-28** (`ycn22l28`, `d77a482de757221d9ff311a43a46c11b40aa7df997199914fad7469d7128b209`) in `qa-report.md`. Same DEDUP-004 root: not counted as two independent issues. See also Q-24 (`ycn22q24`, the floors are off-chain only).

### Story text (what was directed)

> - **Why not permissionless:** a permissionless trigger would let a stranger choose timing and slippage floors:
>   - sandwiching via Balancer swaps before 30 Oct;
>   - front-running between the owner's `withdrawBPT` and `exitAndSeed`, which would revert the forge broadcast mid-cutover before any wiring step;
>   - griefing `abort`.
>
> (story-052 L37-40, Design > Access)

> … run `exitAndSeed(PROPORTIONAL, ...)` with `minAmountsOut` = live proportional share minus a tight tolerance.
>
> (story-052 L194, fork test Case 1)

> `minAmountsOut` is the live proportional share minus a tight tolerance.
>
> (phStaging2 `docs/BalancerWinddownPlan.md` L385, the runbook and the operative source of the "tight tolerance"; 052 L194 above is a fork-test spec)

The contract NatSpec at L63-65 repeats this rationale: the gate exists to deny strangers control of "front-running the cutover broadcast between `withdrawBPT` and `exitAndSeed`".

### Actual behaviour

The gate stops one front-run variant: a stranger calling `exitAndSeed` first, which would seed the pair and make the owner's call revert `PairNotEmpty`. It does not stop the cheaper variant, which needs no call to the escrow. A Balancer swap that moves either side of the proportional share by more than the floor tolerance does the same job. A fork test proved this at the repo's 1 bp tolerance (`work/test/run22/EscrowSandwichEcon.fork.t.sol::test_run22_econ_tightFloor_griefCost`, PASS). A swap of 4 sUSDS for phUSD makes `exitAndSeed` revert with `AmountOutBelowMin(phUSD, 22,453.35e18, 22,454.12e18)`, and the attacker's round-trip cost is about **$0.03** at that 1 bp tolerance (the cost is tolerance-dependent; see L-28). story-103 broadcasts through the public mempool as separate transactions (`--broadcast --skip-simulation --slow --ledger … --legacy`, 103 L99), with floors quoted before the broadcast. Organic Balancer flow can trip the same check.

### Deviation

The code implements the design faithfully. The story's security rationale for that design is incomplete. The gate does prevent the variant the story names (a stranger calling `exitAndSeed` or `abort` first), but the story implies it protects the broadcast from mid-cutover reverts, and a gate-independent vector (a Balancer swap past a tight floor) remains. The "tight" tolerance that makes this revert easy to trigger comes from the runbook (`BalancerWinddownPlan.md` L385) and the 052 L194 test spec, not from the access rationale. Informational: the security weight is carried by L-28 (Low, open). Funds are safe. The transaction is atomic, the BPT stays in the escrow, and the operator can re-quote and retry, or call `abort()` to return everything to the old pooler. ECON-001 shows that a sandwich inside the floors costs the attacker money.

### Recommended story/runbook amendment

Amend story-052 (Design > Access, L37-40 and fork Case 1, L194) and the phStaging2:103 runbook:

1. State that reverts from the floor tolerance are **expected and recoverable** (re-quote and retry, or `abort()`), and that the operator gate prevents only the `PairNotEmpty` pre-emption.
2. Size the tolerance to resist griefing rather than keeping it "tight" (`BalancerWinddownPlan.md` L385). ECON-001 shows a looser floor gives up no value across two constant-product venues.
3. Specify how the story-103 progress file resumes after an `exitAndSeed` revert.
4. Correct the NatSpec at L63-65 to match.

---

_[F-02-052] removed as no longer live: `fixed` @ `0fd6bdf`, human-applied 2026-10-19; verified in phoenix-phase-2-staging@e75ee07 run-41. See the header._

---

## F-03-052: story-052's human seed-price confirmation is not carried into any enforced gate, and the plan figures it would be checked against are stale by about 2.7x

- **Ledger:** `ycn22f3` · fingerprint `8ab7d54dc97ff12b9514c44ee52ee1c9fe55fcf74fd8a74ec59e171bd2c46eaf` · **informational** · status `open` · *borderline overlap with Q-21*
- **Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L268-L270`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L268-L270) (seeds the whole sUSDS/phUSD balances, with no on-chain price band, by design)
- **Detail:** `reports/22/findings/faithfulness/F-03-052-faithfulness-story052-unenforced-seed-price-confirmation.json`
- **Cross-ref:** **Q-21** (`ycn20q21`, `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6`, **`fix-pending`**). This run updates Q-21's numbers only. See `qa-report.md` § "Q-21 (`fix-pending`): numbers update", and the full entry in `carryover/qa-report-20.md`. Related: ECON-003.

### Story text (what was directed)

> - The seed price is inherited from the Balancer pool ratio, about 18,656 sUSDS : 22,456 phUSD at the fork block. The human should confirm the resulting phUSD price before phStaging2:103 runs.
>
> (story-052 L346, Review Fixes > "Accepted / for the auditor, no change")

The plan figures the confirmation would be checked against (phStaging2 `docs/BalancerWinddownPlan.md`): "Spot price: 33,804 / 34,817 ≈ 0.971 USDS per phUSD" (L54); "about $640 of sUSDS. A first call of about Δ* lifts phUSD to peg" (L457); "The crossing is about $638 at the seeded depth" (L490).

### Actual behaviour

The escrow has no on-chain bound on the seed price, by design, and story-052 accepts that. Story-052's own 18,656 : 22,456 figure is current. The confirmation request, however, appears only in the Review Fixes prose:

- It is not in story-052's "Required Human Action On Completion" list (L8-12, items 1-3: audit, bump phStaging2, CI fork job).
- It appears in none of story-103's gates or checklist items. A grep of 103 for the seed ratio, a phUSD price or a confirmation step finds nothing.

Meanwhile the plan's worked example is stale. On-chain, `Vault.getPoolTokenInfo(BPT)` balances and `sUSDS.convertToAssets(1e18)` give:

| Block | Pool balances (sUSDS, phUSD) | sUSDS rate | USDS per phUSD | Peg crossing at seeded depth |
|---|---|---|---|---|
| 26,093,540 (plan basis) | 30,418.87 / 34,816.80 | 1.11128 | 0.97091 | **$637.0** (matches the plan) |
| 26,136,000 and head | 29,663.48 / 35,705.52 | 1.11192 | 0.92377 | **$1,711.7** (about **2.7x** the plan) |

The seed at the fork block is 18,656.33 sUSDS and 22,456.37 phUSD. The plan's L492 ("Recompute Δ* from the pair's balances right after seeding rather than taking it from this table") partly mitigates this.

### Deviation

A human-confirmation requirement in story-052 is not carried into any enforced gate, and the downstream figures it would be checked against are stale by about 2.7x. Value is not at risk. ECON-003 shows the seed is at fair market, and the gap is the phUSD discount, not a leak.

### Recommended story/runbook amendment

- Promote the seed-price confirmation into story-052's Required Human Action list, or into a story-103 gate line that prints the live seed ratio and implied phUSD price and requires acknowledgement.
- Mark plan §5 as illustrative at block 26,093,540, and require a live re-quote before Stage 2.
- **Do not close Q-21 on the strength of story-108's $638.** That re-baseline has itself drifted by 2.7x, so Q-21 stays `fix-pending` with updated numbers only.

### Human-only decision

**Optionally fold F-03-052 into Q-21.** It is filed separately because its subject (an unenforced human confirmation) differs from Q-21's subject (the sizing numbers). The human may merge them during triage.

---

## F-04-052: UniPoolerCutoverEscrow landed on master (`0fd6bdf`) while story-052 is still in `review/`

- **Ledger:** `ycn22f4` · fingerprint `298ee7bb3b0bab68c0f7ca5a3e50034561ca621c81b33b4673e7a18cc4f4d137` · **informational** · status `open`
- **Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L1-L425`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L1-L425) (whole contract)
- **Detail:** `reports/22/findings/faithfulness/F-04-052-faithfulness-story052-landed-while-in-review.json`

### Story text (what was directed)

> 1. **Audit the escrow.** … The escrow must not be deployed to mainnet before the audit passes.
>
> (story-052 L10)

> - [ ] `forge fmt --check`, `forge build --sizes` and `forge test` (full suite) pass.
> - [ ] Final step: ⚠️ HUMAN ACTION REQUIRED — audit `src/migration/UniPoolerCutoverEscrow.sol` before any mainnet deployment; then phStaging2:103 bumps the pin.
>
> (story-052 L199, L201, both unticked)

> **Review Status**: ISSUES_FOUND
>
> (story-052 L307)

> … Also abort unless yield-claim-nft:052 is in complete/ or auto-complete/ …
>
> (story-103 L185, gate check)

### Actual behaviour

The feature is on master and is the current submodule HEAD, but story-052 is in `review/` with two checklist items unticked:

- The fmt and size failures predate the story (`PromotionUniV2_Eth` at 24,770 B is over EIP-170).
- The audit gate is what this run serves.

The review returned `ISSUES_FOUND`. Its MEDIUM was addressed by amendments to the documentation only, and those amendments **propagated the stale 202.30 BPT premise** (F-02-052). Required Human Action #3 (the CI fork job is red by design) is still open. The fork suite fails loudly as it should: this run verified `[FAIL …] setUp()` without an RPC and 4/4 PASS with one.

### Deviation

This is a process and state deviation, not a code deviation. The story policy requires the landed-while-in-review flag. The story's acceptance criteria are still changing, because F-02-052 and F-03-052 need text amendments. Story-103's gate at L185 correctly blocks execution until story-052 reaches `complete/` or `auto-complete/`, so this is informational. Landing before close is also story-052's **designed sequence**: its Required Human Action on completion (L10, L201) is to audit the escrow, and this run is that audit. The flag documents state; it does not indicate a process breach.

### Recommended story/runbook amendment

Before moving story-052 to `complete/`:

1. Apply the text amendments for F-01-052, F-02-052 and F-03-052.
2. Record the recovery decision for L-26 (`ycn22l26`, empty-pair dust poisoning).
3. Settle Required Human Action #3 (CI RPC secret, or accept the red job).

### Human-only decision

**Story-052 is still in review.** Only the human moves it to `complete/`, and doing so clears story-103's gate. Do that only after the amendments above.

---

## Law-1 assessment: no unsafe story

No story-052 intent was escalated as unsafe (`law1Override.storyUnsafeFindings = 0`). The following were assessed:

| Item | Assessment |
|---|---|
| Incomplete threat model for the operator gate (F-01-052 / ECON-002) | The rationale is incomplete, but the intent is safe. The transaction is atomic, `abort()` and retry exist, and the impact is liveness only. Not escalated. The security half is L-28. |
| Seeding the whole balance (052 L67, L225) | Faithful. ECON-001 and ECON-004 show no value extraction. Stray donations become protocol-owned liquidity at the donor's expense. Safe. |
| No on-chain share check (052 L226) | Safe given the non-zero floor requirement and operator gating. Per ECON-001, loosening the floor is not exploitable across two constant-product venues (Q-24 records that price protection is off-chain only). |
| Immutable operator with no rescue (losing the key strands funds) | A deliberate owner design stated in the story (Law 3). |
| `setPool` after construction strands a token outside the snapshot (CODE-002) | Beyond the story text. It is a Law-3 footgun filed by code-scanner (L-27), not a faithfulness deviation. |

---

_[§ Carried-over faithfulness records — run-22 index, superseded by `reports/23/submissions/carryover/`; not carried.]_

---

## Summary

| ID | issueId | Fingerprint | Story | Kind | Severity | Status | Cross-ref |
|---|---|---|---|---|---|---|---|
| F-01-052 | ycn22f1 | `2d7b84f0f5` | story-052 | incomplete threat model for the operator gate | informational (was Low; final review) | open (new) | L-28 `ycn22l28` (security half; same root, counted once) |
| F-02-052 | ycn22f2 | `5a7732a4ea` | story-052 → 103 | stale on-chain premise (owner's 202.30 BPT burned at block 25,985,119) | Low | open (new) | story-103 floor sizing and its L199 fork-test item; ECON-005 |
| F-03-052 | ycn22f3 | `8ab7d54dc9` | story-052 → 103 | seed-price confirmation not enforced by any gate; plan stale by 2.7x | informational | open (new) | Q-21 `ycn20q21` (fix-pending, numbers update) |
| F-04-052 | ycn22f4 | `298ee7bb3b` | story-052 | landed on master while in review (designed sequence) | informational | open (new) | story-103 L185 gate |

**Counts after final review:** 4 records: **1 Low** (F-02-052), **3 informational** (F-01-052, F-03-052, F-04-052). F-01-052 and L-28 are one root and count once across the two reports.

**Human-only decisions:**

1. F-02-052: the tax rationale is already unmet for the 202.30 BPT tranche, whose proceeds reached the owner EOA at block 25,985,119.
2. F-03-052: optionally fold it into Q-21.
3. F-04-052: story-052 is still in review. Move it to `complete/` only after the F-01, F-02 and F-03 amendments and the L-26 recovery decision.
