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
