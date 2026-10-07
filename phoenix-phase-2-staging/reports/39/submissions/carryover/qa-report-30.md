# Carryover QA report: audit 30 (entry point `dev`), re-carried at audit 39

> ## Re-carried at audit 39. Read this first.
>
> **This block was prepended by audit 39** (run `phoenix-phase-2-staging-39`, commit `dfbf2f9`,
> baseline `e6eded0`, branch `master`, entry point `dev`). **Everything after the run-39 index,
> including every earlier carryover header, is preserved VERBATIM and has not been edited.** Where
> an earlier header says "as of audit 30", read it as "as of audit 30, and unchanged at audit 39 unless stated below". Run 39's statements below take precedence.
>
> - **Retained (still open or `fix-pending` as of audit 39): L-01, L-03, F-01, Q-01, Q-02, Q-03. That is 6 entries.**
> - **Removed as no longer live:** none. The run-30 `L-02` (`reports/30/findings/low/L-02-rehearsal-omits-cutover-mechanics.json`) was the REGRESSION re-observation of `pps26l1` / `eda17642828a…`. It has no ledger entry of its own and is counted under audit 26. `F-04-C1` in the spec-conformance body is the run-30 re-observation of `pps29f4`, counted under audit 29.
> - **Statuses changed by audit 39 in this file: NONE.** Proposals are recorded in the ledger
>   (`run39` field and `note`). Only a human applies them, with `/ledger`.
> - **Labels are the originals.** Any gap in the sequence is one of the removals named above, not an omission.
>   Entry point `dev` reuses the same labels across runs under different fingerprints, so **always
>   select by fingerprint or issueId**.
> - Run 30 filed `L-01` and `L-03` **only** as finding JSON. No markdown text was written for them, so **Part C** renders them from their finding records. That rendering is labelled as such and is not presented as an original report.
> - Part A is run 30's `qa-report.md` verbatim (Q-01..Q-03). Part B is run 30's `spec-conformance.md` verbatim (F-01, plus the F-04 re-observation).
> - **Line numbers below were accurate at the originating commit `e6eded0`. Re-verify them against current HEAD `dfbf2f9` before acting.**
> - Source of the verbatim body: `../../30/submissions/qa-report.md` + `../../30/submissions/spec-conformance.md`.

## Run-39 index of retained entries (fingerprint + recommendation)

#### L-01 · `pps30l1` · low · status `open`

- **Title:** Deleting the index-1 rehearsal mint removed the only executable proof that Uniboost.setNudgeStreamer landed on indices 1/2/3; the local run now exits 0 with all three dispatchers unmintable
- **Fingerprint:** `4fd01c83c32d0e5476a156c25537ef5053405426b1507c70a53a58079be68bcc`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/30/findings/low/L-01-unasserted-setnudgestreamer-write.json`):

  > Add require(dispatcher.nudgeStreamer() == address(nudgeStreamer), "<label>: nudgeStreamer not wired") as the last line of _finalizeUniboost, matching the SYA idiom at :1267. Cheaper than restoring the mint and closes the same gap.

#### L-03 · `pps30l3` · low · status `open`

- **Title:** Two of the deletions are justified by in-source claims about live mainnet state that a mainnet fork disproves
- **Fingerprint:** `85754b285c30ad497228a2184b853f3fd297201d5cbffe94e272bbb7df837f00`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/30/findings/low/L-03-unverified-mainnet-claim-as-deletion-rationale.json`):

  > Correct both comments against the chain. For the depletion window either use 2592000 to mirror mainnet or state the 7-day value as a deliberate local divergence with a reason, the way LOCAL_STREAM_DURATION and LOCAL_PROMO_DURATION already do.

#### F-01 · `pps30f1` · low · status `open`

- **Title:** e6eded0 is untagged, has no story, and silently unwinds 5 of the 6 L-01 acceptance criteria of story-079, which sits in complete/
- **Fingerprint:** `d862aec474e0f2e8bb06b2c8c9ab8d79b66a8e23bcd10e0a5a867503ae97d76a`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/30/findings/faithfulness/F-01-unauthorised-reversal-of-completed-story.json`):

  > Write the story. It needs to name story-079 items 536-541 and story-073's staker rehearsal as deliberately superseded, record the retained-exceptions rule and its two members, and carry the compensating assertions (the setNudgeStreamer read-back and a non-zero staker budget) so the assertion coverage the mint used to provide is not simply lost.

#### Q-01 · `pps30q1` · qa · status `open`

- **Title:** The three UniboostStakerV2 instances are published to the UI with zero stake and a zero phUSD reward budget: topUp and depositFor were the only producers and _deployUniboostStaker never tops up
- **Fingerprint:** `bb029fb3cabf67c8cdbd406e6ddce62f04c9b74d68d1609729d48146b5b31061`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/30/findings/qa/Q-01-producer-removed-consumer-retained.json`):

  > Either call staker.topUp(REHEARSAL_STAKER_BUDGET) once per staker inside _deployUniboostStaker (the constant already existed at 9563c68), or restore the single index-1 mint so hook.pull() funds them organically. Assert rewardRate > 0 afterwards so a future removal fails loudly.

#### Q-02 · `pps30q2` · qa · status `open`

- **Title:** Stale references to the deleted Phase 7.4 survive in the retained StableStaker cutover and in the toggle documentation
- **Fingerprint:** `66671224826b16690cf8dda784af7fc04b650c2f23e13fcfef50c57e243ce574`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/30/findings/qa/Q-02-stale-cross-reference-to-deleted-code.json`):

  > Repoint :2031 at _deployPhlimboV3:2287-2321, which is the live in-file precedent for both the mint grant and the role stand-down, and drop the Phase 7.4 pointer at :408. When re-triaging L-06, restate its basis on _deployPhlimboV3:2314-2321 - the slimmed code now demonstrates the correct pattern one screen away from the place that omits it.

#### Q-03 · `pps30q3` · qa · status `open`

- **Title:** DepositView.sol and DepositPageView.sol are now first-party in-scope contracts with zero deployers, retained only as wagmi ABIs and a revival guard
- **Fingerprint:** `e15cd2e251414517607a2cc9e2d4a7a8892448bba9ad1d330f178a331747ea14`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/30/findings/qa/Q-03-orphaned-first-party-depositview.json`):

  > Delete both sources and their wagmi entries, or add a compile-time impossibility (retype against IPhlimboV3, which will not compile against the 3-tuple). Keeping the extract-addresses.js guard entries is correct either way and should be noted as deliberate.

---

<!-- Part A: verbatim copy of reports/30/submissions/qa-report.md -->

# Part A: QA bundle (verbatim)

---

# QA Report — phoenix-phase-2-staging

**Run**: `reports/30` · **Commit**: `e6eded0` · **Baseline**: `9563c68` · **Branch**: `master`
**Entry point**: `dev` (script audit of `script/DeployMocks.s.sol`)

## Run outcome

This run produced **0 High and 0 Medium findings**. There are therefore **no individual H/M
submissions** for it — the `submissions/` directory carries this QA bundle and the run's
spec-conformance report only. No coded PoC is owed: C4 requires one for High/Medium findings, and
this run has neither. (`submissions/M-01-C1.md` and `M-01-C2.md` are **re-carried** Mediums from
earlier runs, still `fix-pending` and unchanged by audit 30 — they are not findings of this run.)

Three Low findings (**L-01**, **L-02**, **L-03**) were raised and are filed **individually** under
`reports/30/findings/low/`; two of the three are faithfulness / spec-conformance items and belong to
`spec-conformance.md`, not here. They are deliberately **not** bundled into this report and are not
renumbered by it.

Carryover QA from earlier audits is **not** merged here. Prior-run bundles, pruned to their still-open
entries, are copied verbatim to `submissions/carryover/qa-report-<NN>.md`. The `Q-XX` sequence below
covers only this run's new findings; entry point `dev` already carries a `Q-01` from runs 21, 26, 27
and 28 under different fingerprints, so **always disambiguate these by fingerprint, never by label**.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (bundled here) | 0 |
| QA | 3 |
| Centralization | 0 |
| **Total** | **3** |

No centralization-risk findings were raised this run.

An automated 4naly3er pass is attached as **`submissions/4naly3er-report.md`**. Read its provenance
header before relying on it: it covers 22 first-party files (`src/views/`, `src/mocks/`) but
**could not analyse `script/DeployMocks.s.sol`**, which is where Q-01 and Q-02 live. Its silence on
that file is a tool limitation, not a clean result.

---

## QA Findings

### [Q-02] Stale references to the deleted Phase 7.4 survive in the retained StableStaker cutover and in the toggle documentation <!-- id: pps30q2 -->

**Fingerprint**: `66671224826b16690cf8dda784af7fc04b650c2f23e13fcfef50c57e243ce574`
**Location**: `script/DeployMocks.s.sol:408` and `script/DeployMocks.s.sol:2031`
(`run` / `_rehearseStableStakerCutover`) · Root-cause class `StaleCrossReferenceToDeletedCode`

> Listed first among the QA items **solely because of the binding triage dependency below**, not
> because of its own impact.

**Description**

The story-080 slimming removed the Phase 7.4 cutover, but two in-source references to it survived.

*Instance 1 — `:408`, a stale navigational pointer.* The `LOCAL_PROMO_KENDU` toggle comment tells the
reader they need not scroll "to Phase 7.4" to see which leg they got:

```solidity
// Script-audit run-26, L-03. Resolved ONCE, here, and logged loudly next to the deployer
// and chain-id lines so a developer reading the transcript knows which leg they got
// without scrolling to Phase 7.4. ...
armKenduPromo = vm.envOr("LOCAL_PROMO_KENDU", true);
```

The arming now happens in Phase 3, inside `_deployPhlimboV3`. The pointer sends a reader to a phase
that no longer exists.

*Instance 2 — `:2031`, the one that matters.* Inside the **retained** story-080 StableStaker cutover,
the justification for revoking `StableStakerV1`'s phUSD mint grant is a comparison to the deleted code:

```solidity
// ---- 4. V1 is empty and inert. Take its phUSD mint authority away.
//         ... This mirrors PhlimboV2's treatment in the Phase 7.4 cutover.
//         Safe because V1 is provably drained: `stakerCount == 0` and `totalStaked == 0`
//         were asserted for all three pools above, ...
phUSD.setMinter(address(stableStaker), false);
```

The `setMinter(false)` call is live and executes regardless. What is lost is the *reviewability* of it:
the comparator that justifies a still-live privileged action cannot be checked by any future reader.
An unverifiable justification for a live privileged action is worse than an absent one, because it
reads as reasoned.

**Impact**

QA. Comments only — not a single byte of executed behaviour changes. The revoke at `:2031` happens or
does not happen independently of whether the comment justifying it points at code that still exists.
The finding is reported rather than dropped because it is a reviewability defect on a live privileged
action, and because of the ledger dependency below.

**BINDING TRIAGE DEPENDENCY — open ledger entry `08adbb692840…` (pps29l6, run-29 L-06)**

This is stated here in full rather than compressed to a cross-reference line, because losing it would
cause a false "cannot reproduce" at that entry's next re-triage.

Ledger entry `08adbb692840…` (label L-06, run-29, **status open**, root-cause class
`MissingPostStepConfiguration`, function `_rehearseStableStakerCutover`) states its basis on the
**Phase 7.4 cutover "400 lines below it"** — precisely the code this finding reports as deleted at
`e6eded0`. A re-triage that tries to verify L-06 against that landmark will find nothing there and may
close or mis-judge the entry on that basis.

**L-06's basis must instead be RESTATED on `script/DeployMocks.s.sol:_deployPhlimboV3:2314-2321`**,
which is the live in-file precedent for the same pattern — a privileged grant taken out and then
*read back* rather than fired and forgotten:

```solidity
// Stand the seeding grant down. Read back rather than fire-and-forget: a farm left with a
// live migrator is a farm where one address can move anybody's position.
v3.setMigrator(address(0));
require(v3.migrator() == address(0), "PhlimboV3 seeding migrator was not stood down");
```

L-06 and this finding are **distinct and must not be collapsed**: L-06 is that the migrator role is
actually left held; this finding is that a comment justifying a still-live revoke cites a comparator
that no longer exists. Different root-cause classes, different fixes (a role change versus a comment
repoint). A note recording this dependency has been appended to the L-06 ledger entry.

Related, not a duplicate: `d7242d7c43ac…` (run-28 Q-01, `StaleInSourceRationaleAfterUpstreamFix`) —
same stale-rationale family, different function and different stale claim.

**Recommendation**

Repoint `:2031` at `_deployPhlimboV3:2287-2321`, which is the live in-file precedent for both the mint
grant and the role stand-down, and drop the Phase 7.4 pointer at `:408`. When re-triaging L-06, restate
its basis on `_deployPhlimboV3:2314-2321` — the slimmed code now demonstrates the correct pattern one
screen away from the place that omits it.

---

### [Q-03] `DepositView.sol` and `DepositPageView.sol` are now first-party in-scope contracts with zero deployers, retained only as wagmi ABIs and a revival guard <!-- id: pps30q3 -->

**Fingerprint**: `e15cd2e251414517607a2cc9e2d4a7a8892448bba9ad1d330f178a331747ea14`
**Location**: `src/views/DepositView.sol` and `src/views/DepositPageView.sol` (whole contracts) ·
Root-cause class `OrphanedFirstPartySource`

**Description**

Neither contract has a deployer at `e6eded0`. No script in the live build constructs either one; the
only remaining construction site is under `script/archives/`, which `foundry.toml` excludes from the
build entirely (`skip = ["script/archives/**"]`). Their names sit in `server/extract-addresses.js`
`DROPPED_CONTRACT_NAMES` as a deliberate revival guard:

```javascript
const DROPPED_CONTRACT_NAMES = [
    "NFTMigrator",
    "BuggedPoolerV2Index6",
    "DepositView",
    "DepositPageView",
    "MintPageView",
];
```

What keeps this from being ordinary dead-code noise is a demonstrated root cause. Both are typed
against a V1/V2-shaped `IPhlimbo` whose `userInfo` is a **3-tuple**:

```solidity
// src/views/DepositView.sol:76        and  src/views/DepositPageView.sol:35
(uint256 amount,,) = phlimbo.userInfo(user);
```

`PhlimboV3.userInfo` returns a **4-tuple** — a fact the live replacement documents explicitly:

```solidity
// src/views/DepositPageViewV3.sol:29, :156
//  `PhlimboV3.userInfo(address)` returns a **4**-tuple (`amount`, `phUSDDebt`, ...
(uint256 amount,,,) = phlimbo.userInfo(user); // 4-tuple in V3
```

Because the orphaned views declare their own narrower interface, an instance pointed at V3 decodes the
first three words of a four-word return and **succeeds silently** rather than reverting. Meanwhile both
ABIs remain published in `wagmi.config.ts:105-106`, reachable to UI consumers, with nothing in the
build preventing someone from wiring one up.

**Impact**

QA. C4 places unused view functions at QA at best, and these are entire unused view *contracts*. There
is no asset impact today: nothing deploys them, so realising the hazard requires a future consumer to
deploy or wire one against V3 — code that does not exist. The finding earns its place in the report on
the strength of the demonstrated silent-mis-decode root cause, not on an elevated label. A silent
mis-decode is genuinely worse than a revert, and that is the part worth acting on.

**CROSS-LINK — fix-pending ledger entry `6b63ef65…`**

`DepositPageView` is simultaneously the subject of ledger entry `6b63ef6516ac…` (run-24 M-01, label
L-07, **status fix-pending**, root-cause class `StaleImmutableViewPointerAcrossCutover`, entry point
**`promotion-ready:broadcast`**) — a *live* view bound to the wrong phlimbo generation.

These are **different defects at different entry points and must not be collapsed**: that entry
concerns a deployed instance owed a fix; this one concerns first-party source with no deployer at all.
But the two interact at remediation time — **a "delete both sources" fix here would act on the same
contract that `6b63ef65…` still owes an open, unfulfilled obligation on**. Resolve the fix-pending
entry's disposition before deleting the source, or the deletion will silently moot an obligation a
human has not yet signed off. This is the reason the retype option below is preferred over deletion.

Nearest neighbour, kept separate: `f5bb2b654c9a…` (run-21 Q-02, `DeadScaffolding`, `MockERC4626Wrapper`)
— a *deployed*, funded mock serving a removed route, with no mis-decode hazard.

**Recommendation**

Delete both sources and their wagmi entries, or add a compile-time impossibility (retype against
`IPhlimboV3`, which will not compile against the 3-tuple). Keeping the `extract-addresses.js` guard
entries is correct either way and should be noted as deliberate.

*Preference, given the cross-link above*: the retype option closes the hazard permanently at compile
time without touching a contract that carries an open fix-pending obligation elsewhere.

---

### [Q-01] The three `UniboostStakerV2` instances are published to the UI with zero stake and a zero phUSD reward budget <!-- id: pps30q1 -->

**Fingerprint**: `bb029fb3cabf67c8cdbd406e6ddce62f04c9b74d68d1609729d48146b5b31061`
**Location**: `script/DeployMocks.s.sol:2407-2434` (`_deployUniboostStaker`) ·
Root-cause class `ProducerRemovedConsumerRetained`

**Description**

The V1 staker rehearsal was removed at this commit, and with it went the only producers of staker
funding: `topUp` call sites went 6 → 0 and `depositFor(address,uint256)` went 9 → 0
(`artifacts/s1-selector-counts-head.log` versus `s1-selector-counts-baseline.log`). The consumer was
retained. `_deployUniboostStaker` deploys each staker, wires the hook, and sets a deliberate 12-month
depletion window — but never tops it up:

```solidity
staker.setDispatcherHook(IUniboostMintDebtHook(address(hook)));
// pull() is onlyOwnerOrRecipient; the staker must be the hook's recipient to sweep mint debt.
hook.setRecipient(address(staker));
// Depletion window = 12 months (one APY-year analogue). Bounded 1..120. Budget is refilled
// by the hook's pull() on dispatch; rate = budget/windowSeconds. Deliberate, non-default.
staker.setDepletionWindow(12);
```

All three stakers end the script at `totalStaked = 0`, `phUSD.balanceOf = 0`, `rewardBudget = 0`,
`rewardRate = 0`, with `depletionWindowMonths = 12`
(`artifacts/s2-uniboost-stakers-head.log`).

**Impact**

QA — and this is the weakest of the run's candidates on impact. Nothing is bricked and nothing is
stranded: `setDepletionWindow(12)` against a zero budget is **inert** (rate 0, `windowEnd = now + 365d`;
verified against `NFTStakerDepletionV2.sol:435-450`), and the state **self-heals on the first
`hook.pull()`**, which funds the budget organically. There is no lost detector and no defect in shipped
behaviour — this is a local, throwaway-chain fixture in a correct-but-unseeded state. What it costs is
representativeness: the chain the UI is tested against ships three reward-bearing contracts that emit
nothing, which is not the "fully working" end state the script claims.

It is reported rather than dropped because it has a concrete, reproducible end state and a concrete fix.

**Related, not duplicated**: this shares an upstream cause with Q-02 — the same deletion removed
`topUp`/`depositFor` — but the retained consumer here is `_deployUniboostStaker`, a different function
with a different fix, and it is kept distinct.

**Recommendation**

Either call `staker.topUp(REHEARSAL_STAKER_BUDGET)` once per staker inside `_deployUniboostStaker`
(the constant already existed at `9563c68`), or restore the single index-1 mint so `hook.pull()` funds
them organically. Assert `rewardRate > 0` afterwards so a future removal fails loudly.

> The `assert rewardRate > 0` half is the durable value in this recommendation and is worth keeping even
> though the finding is QA: it is what converts a silent re-occurrence of this class into a loud one.

---

## Appendix

**`submissions/4naly3er-report.md`** — automated SAST/gas report for this run. 22 first-party files
analysed (`src/views/`, `src/mocks/`), 0 AST failures. `script/DeployMocks.s.sol` is **not covered**
(solc `DeclarationError: Identifier already declared`, caused by nested-submodule duplicate dependency
copies that 4naly3er's resolver does not canonicalise the way forge does); that gap is documented in
the report's own header and covers the locations of Q-01 and Q-02.


---

<!-- Part B: verbatim copy of reports/30/submissions/spec-conformance.md -->

# Part B: Law-2 / spec-conformance entries (verbatim)

---

# Spec Conformance (Law 2) — phoenix-phase-2-staging, script audit of the `dev` entry point (run 30)

**Project**: phoenix-phase-2-staging  ·  **Run**: `phoenix-phase-2-staging-30`
**Commit**: `e6eded0`, branch `master`  ·  **Baseline**: `9563c68` (`entryPointBaselines.dev`, set by run 29)
**Entry point**: `dev`
**Report scope**: Law-2 faithfulness only. Low/QA findings without a faithfulness tag are in
`qa-report.md`; this file is the anti-burial channel and is deliberately separate from that bundle.

This run raises **one new Law-2 finding** — `F-01` — and **carries `F-04` forward as still-open with
a materially new escalation**. Both are Low: neither has asset, value or availability impact, so
neither owes a separate High/Medium label or report.

| Label | `issueId` | Fingerprint | Story graded against | Deviation type | Severity | Origin |
|---|---|---|---|---|---|---|
| **F-01** | `pps30f1` | `d862aec474e0…` | **story-079** (`complete/`) | **REVERSED-WITHOUT-AUTHORISATION** | Low | new |
| **F-04** | `pps29f4` | `ee5aae66ac65…` | story-080 | DECLARED-BUT-UNMET | Low | still-open (run 29) |

> **Labels are run-scoped.** Run-30 `F-01` (`pps30f1`, `d862aec4…`) is **not** run-28 `F-01`
> (`pps28f1`, `dcf756f7a897…`), which is a different, still-open finding carried forward in
> `carryover/spec-conformance-29.md`. `F-04` keeps its **original** label and `issueId` from run 29;
> no run-30 label was minted for it and no second ledger entry was created.

---

## Story resolution for commit `e6eded0` — the story genuinely does not exist

`e6eded0` carries **no `[story-NNN]` prefix**. It is untagged, and the absence of an authorising
story is established by exhaustive search rather than asserted:

- **Whole-tree glob**, every state folder and every sprint/worktree folder under
  `~/code/product-owner/stories/phStaging2/` (`complete`, `auto-complete`, `incomplete`, `review`,
  `archive`): **82 story documents**, numbering **tops out at 081**. There is no 082 and no decimal
  insertion above 081 anywhere in the tree.
- **Whole-tree grep** for the vocabulary such a story would have to use —
  `slim` / `trim` / `retire-the-rehearsal` / `remove-old-cutover` — returns **no story about
  removing the Phase 7.6 rehearsal**. For precision: the only textual `trim` matches in the tree are
  unrelated — `074-persist-bpt-cutover-baseline-across-resume-legs.md` (hand-**trim**ming of the
  resume state file) and `045-mainnet-deploy-nft-staking-differential.md` ("**trim** it to the three"
  — a JS patch script). Neither concerns `DeployMocks.s.sol` or the rehearsal. `slim`,
  `retire-the-rehearsal` and `remove-old-cutover` have **zero** matches.

Per `storyPolicy`, that is the Law-2 standard for a negative: **the story genuinely does not exist.**
This is explicitly *not* a report that a story was unavailable, external, or unreadable — the tree was
read in full, and the work at `e6eded0` has no acceptance criteria anywhere to be graded against.

---

## F-01 — `e6eded0` is untagged, has no story, and silently unwinds 5 of the 6 `L-01` acceptance criteria of story-079, which sits in `complete/`

- **`issueId`**: `pps30f1`
- **Fingerprint**: `d862aec474e0f2e8bb06b2c8c9ab8d79b66a8e23bcd10e0a5a867503ae97d76a`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:run:UnauthorisedReversalOfACompletedStory:dev`
- **Root cause class**: `UnauthorisedReversalOfACompletedStory`  ·  **Entry point**: `dev`
- **Location**: [`script/DeployMocks.s.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol) (`run`)
- **Severity**: Low (no asset at risk; the loss is the authorisation record)
- **Law 3**: **FOOTGUN**, explicitly not a reckless-admin mistake and not a malicious-owner vector.
- **Story**: `~/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`

### The acceptance text this deviates from — verbatim

Story-079's checklist, **lines 536–541**, are the `L-01` acceptance items. They are reproduced here
exactly as written in the story document, including their ticked state:

```
536:- [x] **L-01:** add a new `_rehearseDispatcherSwap(...)` internal helper implementing steps 1–10 of *Implementation Notes*, called from `run()` as `Phase 7.6` between Phase 7.5 and Phase 8
537:- [x] **L-01:** ensure the mint-debt conservation assertion is **non-vacuous** — `hook.mintDebt()` must be non-zero at the moment of `pull()`. If the local run leaves it at zero, drive one mint through index 1 first (or otherwise accrue debt) and say so in *Autonomous Decisions*. A `require(mintDebt == 0)` after a no-op `pull()` proves nothing and is exactly the reward-hacking shape this story must not produce
538:- [x] **L-01:** assert the intermediate-window fail-closed state (`hook.dispatcher() == new` while `configs(1).dispatcher == old`) before `replaceDispatcher`
539:- [x] **L-01:** assert `price`, `growthBasisPoints` and `disabled` preserved across `replaceDispatcher`, plus `dispatcherToIndex` moved old→new
540:- [x] **L-01:** pin the two index-7 claims statically: `nudgeRatchetHook.hookTypeId() == keccak256("NudgeRatchetMintDebtHook.v1")` and `nudgeRatchetHook.ratio() == 100` (the non-default `DEFAULT_RATIO`)
541:- [x] **L-01:** finalise the replacement dispatcher so the local chain ends fully working, and update the tracked address-book entry for index 1 to the live dispatcher (adding to the `_markConfigured` block at `:1432-1493` if a new key is introduced)
```

All six are ticked `[x]`, and the story sits in **`complete/`** — these are accepted, closed-out
criteria, not a draft.

### Exactly what survived, and exactly what did not

Being accurate about what was **not** reverted matters as much as what was. The commit is a
**targeted reversal of story-079's `L-01` half**, and nothing wider:

| Story-079 checklist item | Subject | State at `e6eded0` |
|---|---|---|
| 536 | `_rehearseDispatcherSwap(...)` helper, called as `Phase 7.6` | **reverted** (deleted) |
| 537 | non-vacuous mint-debt conservation assertion | **reverted** |
| 538 | intermediate-window fail-closed assertion | **reverted** |
| 539 | `price` / `growthBasisPoints` / `disabled` preservation + `dispatcherToIndex` move | **reverted** |
| **540** | **static index-7 claims** (`hookTypeId()`, `ratio() == 100`) | **SURVIVES** — retained as `_pinNudgeRatchetStaticClaims` |
| 541 | finalise replacement dispatcher + index-1 address-book entry | **reverted** |
| 533–535 | the **`L-03`** `armKenduPromo` toggle (flag, gated call site, logging) | **retained intact — not touched** |
| 542 | the **`L-04`** `_sweepResidualPrivileges` deployer-grant sweep | **retained intact — not touched** |

So: **five of story-079's six `L-01` items were unwound; only item 540 survives**, as the static
claim-pinning helper `_pinNudgeRatchetStaticClaims`. The `L-03` toggle (items 533–535) and the `L-04`
privilege sweep (item 542) are **fully intact**. That selectivity is the evidence that this is a
deliberate, scoped reversal rather than an accidental revert or a botched merge — and it is why the
finding is stated as *story-079's `L-01` half was reversed*, not as *story-079 was reverted*.

### Impact

A completed story's remediation was reverted with **no superseding decision record**. The audit
finding that story-079 closed — ledger `eda17642828a…` / `pps26l1`, `L-01`, status **`fix-pending`**,
"`dev` rehearses the cutover's end state but not its cutover mechanics" — is **live again**, with
nothing in the story tree explaining why. Under the project's own rules `fix-pending` is the one
human-set status that is *not* a disposal: someone is relying on that fix landing. It has now been
unlanded without a record.

Likelihood is not inferred: the reversal is demonstrated by selector counts at head versus baseline
plus the preserved deleted helper (`artifacts/s3-deleted-rehearsal.txt`,
`s1-selector-counts-head.log`, `s1-selector-counts-baseline.log`).

### In fairness to the change

The source comments accompanying the deletions **make a coherent argument** that the removed
rehearsals are obsolete, and that argument may well be right. This finding does **not** claim the
three deleted rehearsals are still needed, and it does not claim the author was careless.

**The finding is that the judgement is unreviewable as filed.** There is no story, no superseding
decision record, and no note in the tree that a reviewer can weigh the argument against — so a
`fix-pending` remediation was withdrawn on reasoning that exists only in code comments, in a commit
nobody was asked to approve. F-01 would stand even if `eda17642` is later judged genuinely obsolete,
and the ledger regression stands even if a story is written tomorrow; the two are deliberately not
collapsed.

### Recommendation (verbatim)

> Write the story. It needs to name story-079 items 536-541 and story-073's staker rehearsal as
> deliberately superseded, record the retained-exceptions rule and its two members, and carry the
> compensating assertions (the setNudgeStreamer read-back and a non-zero staker budget) so the
> assertion coverage the mint used to provide is not simply lost.

---

## F-04 *(still open — carried forward from run 29, with a run-30 escalation)* — story-080's declared drift guard is unenforceable, and has now become load-bearing

- **`issueId`**: `pps29f4` (original label `F-04`, run `phoenix-phase-2-staging-29`)
- **Fingerprint**: `ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:mainnetAddresses: ContractAddresses:UnenforceableDeclaredDriftGuard:dev`
- **Root cause class**: `UnenforceableDeclaredDriftGuard`  ·  **Entry point**: `dev`
- **Location**: `server/deployments/mainnet-addresses.ts:46-110`
- **Ledger status**: `open`, severity Low. `lastSeenRun` bumped to `phoenix-phase-2-staging-30`;
  **nothing else about the status was touched, and no second entry was minted.**
- **Full original report**: [`carryover/spec-conformance-29.md`](carryover/spec-conformance-29.md)
  (verbatim copy of `reports/29/submissions/spec-conformance.md`)

**The deviation.** The stated reason for deleting the PhlimboEA key is that it "left the generated
`ContractAddresses` interface this file must satisfy". That constraint is a `console.error` string in
`generate-ts-addresses.js:81` — **not a check**; nothing runs `tsc`. And it is already violated: the
file carries three keys the interface does not (`BurnerEYE` / `BurnerSCX` / `BurnerFlax`, at
`:108-110`), retained since story 070 for exactly the historical-reference reason PhlimboEA was
denied. Measured: interface 55 keys, `mainnet-addresses.ts` 58, 0 missing, 3 extra.

**Run-30 escalation** — materially new evidence `F-04` did not carry when filed at run 29. A plain
copy-forward would have buried it, so it is stated both here and in the carried-forward report:

1. **The unenforceable guard has now been used as the AFFIRMATIVE JUSTIFICATION for deleting a live
   mainnet contract's only published resolution path.** At run 29 it was a declared rule that did not
   exist and was not enforced; at run 30 it is **load-bearing for an irreversible edit**.
2. **The rule is not merely unenforced — it is UNEVENLY APPLIED.** The same guard admits the three
   Burner keys and excludes a fourth, with no stated distinction.

**Consequence.** This may justify a **severity re-weigh at human re-triage**; it does **not** reach
Medium on current facts (no asset at risk, no protocol function or availability impact — the failure
mode is a hand-maintained address book drifting from a generated interface, which C4 places at
QA/Low). It does **not** justify a second ledger entry, and none was created.

**⚠ Still binding:** `F-04`'s inherited **DO-NOT-COLLAPSE** against `pps29f3` / `c476a12b04fa…`.
Audit 30 respected it; the two were not merged. Likewise `F-04` is **not** collapsed with run-30
`L-03` (`85754b285c30ad49…` / `pps30l3`), which touches the same file and the same deletion but is a
different root cause with a non-overlapping fix.

### Recommendation (verbatim)

> Restore the PhlimboEA key as a commented historical entry alongside the Burner precedent, or
> delete the three Burner keys so the rule is real. Then make the guard executable (a tsc --noEmit
> over server/deployments/, or a node key-set diff wired into generate:ts-anvil) - which also closes
> F-04.

---

## Pattern: three runs in four have raised un-storied work on this entry point

Stated as a **priority** signal, not a severity argument — recurrence does not make any single
instance Medium:

| Run | Label / `issueId` | Fingerprint | Root cause class | Status |
|---|---|---|---|---|
| 26 | `Q-01` / `pps26q1` | `1c98937375ad…` | `StoryProvenanceGap` | open |
| 28 | `F-03` / `pps28f3` | `da94d1ba03fd…` | `ShippedWorkWithoutAcceptanceCriteria` | open |
| 30 | `F-01` / `pps30f1` | `d862aec474e0…` | `UnauthorisedReversalOfACompletedStory` | new |

Three occurrences in four runs is a process signal about how work lands on the `dev` entry point, and
should be weighed as a pattern rather than triaged as three isolated Lows.

**These are different defects and must not be collapsed.** `Q-01` and `F-03` cover work that **never
had acceptance criteria** — nothing existed to grade it against. `F-01` is the distinct and stronger
claim that work which **had accepted criteria, sitting in `complete/`, was silently and selectively
reversed** — items 536–541 unwound while 533–535 and 542 were left intact. Merging them would lose
that distinction, and with it the reason `F-01` is the sharper of the three.

---

## Also still open from earlier runs (carried, not re-graded here)

Carried verbatim in `carryover/spec-conformance-28.md` and `carryover/spec-conformance-29.md`; listed
so nothing open is out of view:

| Label | `issueId` | Fingerprint | Story | Status |
|---|---|---|---|---|
| `F-01` (run 28) | `pps28f1` | `dcf756f7a897…` | story-079 | open |
| `F-02` (run 28) | `pps28f2` | `beb259209f88…` | story-079 | open |
| `F-03` (run 28) | `pps28f3` | `da94d1ba03fd…` | — (no story) | open |
| `F-03` (run 29) | `pps29f3` | `c476a12b04fa…` | story-080 | open (entry point `test:stable-staker`) |

Line numbers in the carried reports were accurate at their originating commits. Re-verify against
current HEAD `e6eded0` before acting.


---

# Part C: run-30 Low findings filed only as finding JSON (rendered from the records, not an original report)

## [L-01] Deleting the index-1 rehearsal mint removed the only executable proof that Uniboost.setNudgeStreamer landed on indices 1/2/3; the local run now exits 0 with all three dispatchers unmintable <!-- id: pps30l1 -->

- **Fingerprint:** `4fd01c83c32d0e5476a156c25537ef5053405426b1507c70a53a58079be68bcc`
- **Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol#L1733-L1744` (`_finalizeUniboost`)
- **Source record:** `reports/30/findings/low/L-01-unasserted-setnudgestreamer-write.json`

### Description

_finalizeUniboost writes dispatcher.setNudgeStreamer(address(nudgeStreamer)) with no read-back require, unlike the SYA idiom at :1267. At 9563c68 the omission was caught transitively by story-079's _accrueIndex1MintDebt mint; e6eded0 deleted it (NFTMinterV2.mint 10 -> 0).

### Impact

A mainnet operator relying on the local mirror to catch a missed setNudgeStreamer gets a green run. On mainnet that misconfiguration reverts every mint on indices 1/2/3 ('Uniboost: nudgeStreamer unset', Uniboost.sol:248). Local-only blast radius, hence Low; Medium was considered because the class is exactly what the mainnet cutover fears, and consistency with ledger eda17642 (Low) decided it.

### Recommendation

Add require(dispatcher.nudgeStreamer() == address(nudgeStreamer), "<label>: nudgeStreamer not wired") as the last line of _finalizeUniboost, matching the SYA idiom at :1267. Cheaper than restoring the mint and closes the same gap.

## [L-03] Two of the deletions are justified by in-source claims about live mainnet state that a mainnet fork disproves <!-- id: pps30l3 -->

- **Fingerprint:** `85754b285c30ad497228a2184b853f3fd297201d5cbffe94e272bbb7df837f00`
- **Location:** `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts#L46-L56` (`mainnetAddresses: ContractAddresses`)
- **Source record:** `reports/30/findings/low/L-03-unverified-mainnet-claim-as-deletion-rationale.json`

### Description

(a) The comment replacing the deleted PhlimboEA key states V2 'still exists on mainnet wound down, mint-revoked and NOT paused so a late staker can still exit'. Fork @25949772: paused() == true. The same claim is repeated in AddressLoader.sol:86-92. (b) DeployMocks.s.sol:2258-2263 justifies the new PhlimboV3 literal 604800 as 'the ones V2 carried and V3 inherited at the mainnet cutover'; mainnet V2 and V3 both read 2592000.

### Impact

No value at risk today (V2 holds totalStaked 0 and zero balances). The defect is that two irreversible edits rest on assertions about mainnet that were never checked, and the 604800 literal now pins the local depletion window 4.29x faster than mainnet's with no live read left to correct it.

### Recommendation

Correct both comments against the chain. For the depletion window either use 2592000 to mirror mainnet or state the 7-day value as a deliberate local divergence with a reason, the way LOCAL_STREAM_DURATION and LOCAL_PROMO_DURATION already do.
