<!--
Law-2 spec-conformance report (F-XX faithfulness findings)
Project: phoenix-phase-2-staging @ 1d8a3a7515adca7819c530a01a87c132863a5ae2 (run-27, /audit-script)
Entry Point: dev
Branch: master
Result: ZERO F-XX findings owed. This is a reasoned conclusion, not an empty file.
-->

# Spec Conformance (Law 2) — phoenix-phase-2-staging, entry point `dev`

**Project:** phoenix-phase-2-staging
**Commit:** `1d8a3a7515adca7819c530a01a87c132863a5ae2` (`1d8a3a7`)
**Baseline:** `e1db0f1` (`entryPointBaselines.dev`, set by run-26)
**Run:** `reports/phoenix-phase-2-staging/27/` (`/audit-script`, entry point `dev`)
**Branch:** `master`
**Delta:** one commit, `1d8a3a7` — *"[story-079] Rehearse cutover mechanics, toggle Kendu promo, sweep deployer grant"* — one file, `script/DeployMocks.s.sol`, **+293 / −1**.

## Conclusion

> **No `F-XX` findings are owed this run.**

**This is an affirmative finding, not an omission.** The story under audit was located, read in full, and
graded clause by clause, and the implementation was found **faithful** to it. Three separate candidates
were considered for routing here and **each was declined for a stated reason**, recorded in §3 below so
the decision can be re-litigated rather than merely trusted. Nothing was buried in the QA bundle to avoid
this channel, and nothing that belongs here was filed elsewhere.

Where run-27 *does* have something to say about the story's residuals, it says it as a **Low or QA
finding about the engineering**, not as a faithfulness deviation about the spec. The distinction matters:
a deviation says *the code does not do what the story says*; these say *the story deliberately scoped
something out, and the residual is worth scheduling*. Filing the latter as `F-XX` would misattribute a
deliberate, disclosed scoping decision as an implementation failure.

---

## 1. Stories graded

| Story | Role | State folder | Disposition |
|---|---|---|---|
| **079** — *Remediate script-audit run-26 findings L-01, L-03, L-04 in `DeployMocks.s.sol`* | **Primary.** The sole story behind the delta; the commit subject points at it and it is the only story the +293/−1 implements. | `complete/phStaging2-script-audit-26/` | **FAITHFUL.** All checklist items re-proved; all three targeted findings verified addressed (DEV27-V01 / V02 / V03). |
| **073** — nudge-streamer wiring | Contextual. Supplies the streamer/batch-minter phases that Phase 7.6 sits beside, and the still-open `L-06` (`c76a8f9f…`) family this run cites. | `complete/` | No new deviation. Its outstanding assertion gap remains ledger `c76a8f9f…`, cited and not re-filed. |
| **076** — PhlimboV3 promotion-ready | Contextual. The source of the "Kendu promotion must be dormant on mainnet" invariant that story 079's `LOCAL_PROMO_KENDU` toggle exists to make reachable. | `complete/` | No new deviation. The dormant leg now reproduces the contract-state half of 076's invariant (verified on chain). |
| **077 / 078** — DepositPageViewV3 / view-surface rework | Contextual. **078 carries an explicit constraint at line 301 that the delta appears to cross** — adjudicated in §2 as **nominal**. | `complete/` | No deviation. See §2. |

**Story retrieval.** Story 079 was resolved by globbing the whole `phStaging2` project tree, not one
sprint or one state folder:
`~/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`.
Exactly one match. It is in the `complete` state folder, consistent with the landed commit.

**A note the reader needs.** Story 079 **exists** and was graded — but it is *not* the missing story that
the 22 in-source `Story 079` comments refer to. Its own **Concerns** section says so verbatim, and lists
run-26's `Q-01` (`1c98937375ad…` / `pps26q1`) as **explicitly out of scope**. That QA entry therefore
stays **`open`**; the number being consumed is not a closure. Run-27 confirmed the 22 in-source
references are byte-identical across `e1db0f1 → 1d8a3a7` (only line numbers moved), so the attribution
gap is unchanged and marginally aggravated.

---

## 2. Story 079's checklist — independently re-proved

Story 079 ships **19 ticked checklist boxes**. The 19th is the closing *"commit with a `[story-079]`
prefix, staging by explicit path"* box, verified separately against the commit record: the delta is a
single commit with that exact subject prefix touching a single file. The remaining **18 substantive boxes
were each independently re-proved to hold** — the tick was treated as a claim to be tested, never as
evidence. **10 of the 18 were re-executed** (fresh `npm run clean:local && npm run dev` on both toggle
legs, broadcast-bundle call counting, `cast call` state reads, ACL read-back, an out-of-band mint probe);
the remaining 8 are static or process claims and were proved by direct inspection of the diff and the
tree.

**All 18 hold. Zero were found ticked-without-implementation.** That result is worth stating plainly,
because the opposite has been found on this project before — ledger `daab9e86d033…` (audit-21 `L-08`,
still open) is exactly a ticked checklist line whose implementation was partial, and run-27 looked for a
repeat and did not find one. The two boxes most at risk of a vacuous green were:

- **Non-vacuity of the mint-debt conservation assertion.** The story itself flags this as *"the most
  likely place for the executing agent to produce a green result that means nothing"* — `hook.pull()` is
  a no-op at zero debt, so `require(mintDebt == 0)` after it is trivially true. **Re-proved live:**
  `_accrueIndex1MintDebt` deterministically drives one real index-1 mint before the pull, and the hook's
  debt was observed non-zero at pull time. The gate is genuinely non-vacuous.
- **`npm run dev` completing end-to-end on both toggle legs.** **Re-executed on both**, including
  `deploy:local` broadcasting clean, `simulate-yield.sh`, `extract:addresses` / `generate:ts-anvil`
  producing a `local-addresses.ts` naming the **replacement** index-1 dispatcher, and `serve` reporting
  `deploymentsLoaded: true` on `/health`.

Evidence for the whole set is under
[`../script-audits/dev/evidence/`](../script-audits/dev/evidence/) — principally
`legA-armed-03-deploy.log`, `legA-armed-04-broadcast-callcounts.txt`,
`legA-armed-07-onchain-swap-state.txt`, `legA-armed-09-phusd-acl.txt`,
`legA-armed-11-postswap-mint-probe.txt`, `legB-dormant-01-npm-run-dev.log`,
`legB-dormant-02-onchain-state.txt`, `legB-dormant-03-broadcast-callcounts.txt`,
`static-01-story079-refs-and-scope.txt` and `static-04-law2-078-and-scope.txt`.

### The story-078:301 constraint — recorded, and **nominal**

Story **078** states at line **301**: **"Do not modify `DeployMocks.s.sol`."** The delta under audit
modifies exactly that file, +293/−1. The tension is recorded here rather than left for a reader to
discover — and adjudicated as **nominal, not a deviation**:

1. **078's constraint is scoped to its own change, not to the file in perpetuity.** It is a blast-radius
   fence around 078's view-surface rework (`DepositPageView` → `DepositPageViewV3` and the read side that
   binds it), instructing *that* story's executor not to widen into the deploy script. It is not a
   standing repository-wide freeze, and reading it as one would make every subsequent story that touches
   the file — including the audit remediations the project asked for — a spec violation by construction.
2. **The delta touches zero 078 view surfaces.** Verified mechanically rather than argued: a sweep of
   078's view symbols across the **added** lines of the diff returns **0 occurrences**, and the single
   **deleted** line is `_armLocalKenduPromotion(deployer, v3);` — the `L-03` gating target, not a view
   surface (`static-04-law2-078-and-scope.txt`).
3. **Every added symbol traces to `L-01`, `L-03` or `L-04`.** The scope-creep sweep enumerates the added
   top-level symbols — `armKenduPromo`, `REHEARSAL_SWAP_INDEX`, `_rehearseDispatcherSwap`,
   `_accrueIndex1MintDebt`, `_pinNudgeRatchetStaticClaims`, `_sweepResidualPrivileges`,
   `_requireLiveMinter` — and each maps to one of the three findings the story was written to remediate.
   Nothing rides along.
4. **Story 079 is a later, more specific instruction covering the same file.** Where two stories speak to
   one file, the one that names the work wins; 079 names `DeployMocks.s.sol` in its title.

**No `F-XX` is owed for this, and no follow-up action is proposed.** It is recorded so a future reader who
greps 078 for constraints does not mistake a resolved tension for an unexamined one.

---

## 3. Faithfulness candidates considered and **declined**

Three findings in this run were assessed for `F-XX` routing. Each was declined deliberately. Listing them
is the point: a spec-conformance report with no findings is only credible if it shows what it looked at.

### 3.1 `pps27l1` — `test:fund-user` bricked by the terminal privilege sweep (`65db3324e7d0…`) — **DECLINED**

The one with the strongest surface case: a change shipped a broken developer command. **But story 079
found this itself.** It is recorded in the story as **Autonomous Decision 4** *("the revoke is safe for
`npm run dev`, but breaks `npm run test:fund-user`")* and as **Review Issue 1**, and the story
**deliberately declined to fix it** to honour its own single-file constraint. Both of the story's
validators endorsed that reading and both recommended scheduling the one-liner.

The implementation therefore does **exactly** what the story says, including the part where the story
says *"this breaks, and I am not fixing it here."* That is faithfulness, not deviation. Filing `F-XX`
would penalise a story for disclosing a consequence honestly. **The finding is the scheduling of work the
story explicitly deferred**, and it is filed as a Low on the engineering, at `pps27l1`.

*Coupling that must survive this page:* `pps27l1`'s ledger relation to `pps26l4` is **`introducedBy`**,
**not** `incompleteFixOf`. The `L-04` fix is complete and correct for the claim it closed (DEV27-V03).
This is collateral in a different file.

### 3.2 `pps27l2` — 1 of 5 dispatcher swaps rehearsed (`6af1ae30ed82…`) — **DECLINED**

Run-26's recommendation said in terms that *"one index is sufficient to make the ordering executable and
therefore regression-testable"* and **left the index unspecified**. Story 079 chose index 1, explained the
choice in its Concerns (blast radius: swapping index 7 means re-wiring `RatchetNFTStaker`, the ratchet
batch minter, the nudge streamer and the target APY on the exact chain the UI is about to be tested
against), and pinned index 7's two distinguishing claims with static assertions instead. **One index is
what was asked for and one index is what was built.** No story or spec claim says all five classes would
be mirrored, so there is no deviation to report — only a residual coverage gap, filed as a Low.

*Preserved, unresolved:* a triager who instead reads run-26's recommendation as having asked for **all
five** should **reopen `pps26l1` as an incomplete fix and decline `pps27l2`**. That choice is **mutually
exclusive** with `/ledger phoenix-phase-2-staging fixed pps26l1`. It is a ledger-shape decision and no
agent took a position on it. Note that even under the reopen reading, the correct instrument is an
incomplete-fix reopen, **not** an `F-XX`.

### 3.3 `pps27q2` — dormant leg's `local-addresses.ts` still ships a funded MockKendu (`e0ac78243e5f…`) — **DECLINED**

Story 079 **discloses this in its own Concerns**, verbatim: *"The dormant leg is not a perfect mainnet
mirror… `local-addresses.ts` still carries a real `MockKendu` address, whereas `mainnet-addresses.ts`
carries `Kendu: 0x0`."* It considered blanking the local address and **correctly rejected it as out of
scope** — the Kendu nudge stream legitimately uses MockKendu, and gating it was explicitly forbidden. The
implementation is faithful.

The only claim that over-reaches is the **dormant-leg log line's unqualified "this is the day-one mainnet
shape"**, which is a comment-accuracy issue and is squarely QA under C4, not a story deviation. Filed as
QA at `pps27q2`, with the log-line wording in its recommendation.

*Adjudicated distinct, do not collapse:* `pps27q2` (the **local** artifact failing to reproduce the
mainnet shape) is a different finding from ledger `3177eed94ecb…` (audit-21 `L-03`, open — the **mainnet**
artifact's type ambiguity). Neither fix closes the other. If both are scheduled, fix `3177eed9` first.

---

## 4. Law-1 and Law-3 notes on this page

- **Law 1 (no silent drops).** Nothing was set aside here. All six of the run's findings are filed in
  visible channels (four Low, two QA), all four verification records are reported, and all twenty
  still-open ledger entries are carried over in full. This page's declines route findings **to** another
  visible channel, never out of the report.
- **Law 3 (owner trust).** No malicious-owner vector appears anywhere in this run. One finding
  (`pps27l4`, the retired dispatcher retaining unswept prime) was assessed against the footgun test and
  **retained** as a non-obvious operational hazard with safe-config guidance — a competent, non-malicious
  operator would reasonably assume the dispatcher the address book names is the one holding the retained
  pot. It is not a faithfulness item: no story claims the pot is swept.

## 5. What this page does **not** claim

- It does **not** claim the `dev` closure is free of spec risk beyond the graded stories. Run-27 was
  scoped to the `e1db0f1 → 1d8a3a7` delta and its transitive closure; the project-level baseline remains
  `0e190e8` and was deliberately **not** advanced.
- It does **not** close run-26's `Q-01` (`1c98937375ad…` / `pps26q1`). The 22 in-source *"Story 079"*
  references still point at a story that does not exist, and story 079 disclaims being it. That entry
  stays `open`.
- It does **not** grade the mainnet cutover itself. Where a mainnet leg was asserted but not demonstrated
  — the retained-prime magnitude held by the live indices 1/2/3 Uniboost incumbents — it is recorded as an
  **open question referred to the `promotion-ready` entry point**, and contributed nothing to any label
  on this run.
