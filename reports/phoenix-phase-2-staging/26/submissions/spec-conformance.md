<!--
C4 / Law-2 Spec-Conformance Report
Project: phoenix-phase-2-staging @ e1db0f1ca67f878f0f1a109fefc0319c8883bbba (run-26, /audit-script)
Entry Point: dev
Branch: master
Faithfulness labels this run: F-01 (one)
F-01 fingerprint: 1c98937375adc20c171c86ba91246476283add1bf72736a0e945606c643d1e9e
F-01 fingerprint input: lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:run / _rehearsePhlimboV3Cutover / _armLocalKenduPromotion:StoryProvenanceGap:dev
F-01 fingerprint formula: sha256(contract:function:rootCauseClass:entryPoint)
Run-label cross-reference: F-01 == Q-01 (findings/qa/Q-01-story-079-does-not-exist.json)
-->

# Spec Conformance Report (Law 2) — phoenix-phase-2-staging, entry point `dev`

**Project:** phoenix-phase-2-staging
**Commit:** `e1db0f1ca67f878f0f1a109fefc0319c8883bbba` (`e1db0f1`)
**Baseline:** `3fb4e34` (`entryPointBaselines.dev`, set by run-21)
**Run:** `reports/phoenix-phase-2-staging/26/` (`/audit-script`, entry point `dev`)
**Branch:** `master`

## Index

| F-label | Run label | Severity | Fingerprint | Routing |
|---|---|---|---|---|
| **F-01** | Q-01 | QA | `1c98937375ad…` | **PRIMARY — this document.** Listed in `qa-report.md` as `Q-01` for completeness of the QA record only. |

**One faithfulness item this run.** It is also the only QA item, and it is the reason this document
exists as a full narrative rather than an index: Law 2 forbids burying a story deviation in the QA/gas
bundle, and the classifier's routing instruction is explicit that F-01 **must not be reduced to a bundle
line**.

---

# [F-01] The un-storied "Story 079" work has no acceptance criteria anywhere to be graded against — and the one in-scope story that mentions the file forbids the change

**Severity:** QA. **Status:** `open`.
**Fingerprint:** `1c98937375adc20c171c86ba91246476283add1bf72736a0e945606c643d1e9e`
**Contract:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol`
**Function:** `run` / `_rehearsePhlimboV3Cutover` / `_armLocalKenduPromotion`
**Root cause class:** `StoryProvenanceGap` · **Entry point:** `dev` · **Origin:** new
**Evidence:** [`script-audits/dev/evidence/story-079-glob.log`](../script-audits/dev/evidence/story-079-glob.log)
**Finding record:** [`findings/qa/Q-01-story-079-does-not-exist.json`](../findings/qa/Q-01-story-079-does-not-exist.json)

## 1. What was found

`script/DeployMocks.s.sol` and four of its sibling interaction scripts attribute their most substantial
change in a year to **"Story 079"**. That story **does not exist**.

This is stated as a positive finding, not as a lookup failure. Project policy draws a hard line between
*"the story does not exist"* and *"the story is unavailable"*, and the distinction is load-bearing here:
the first is a reportable provenance defect, the second would be an audit that failed to do its job. The
absence was established by an **exhaustive project-wide glob across every state folder**, not by a
single-folder lookup:

```
$ find ~/code/product-owner/stories/phStaging2 -type f \( -name "079-*.md" -o -name "079.*-*.md" \)
   → 0 hits
```

The four state folders searched are **all** of them — `auto-complete`, `complete`, `incomplete`,
`review`. The decimal-insertion form (`079.5-…`) was included in the glob. The highest story that exists
anywhere in the `phStaging2` tree is **078**. The only `079` under the stories tree at all belongs to a
different project and is unrelated to this work.

**The introducing commit is untagged.** Every occurrence was introduced by head commit `e1db0f1`, whose
subject carries no `[story-NNN]` prefix at all:

```
HEAD       e1db0f1ca67f878f0f1a109fefc0319c8883bbba  "dev script brought up to speed with promot-ready cutover"
delta base 3fb4e34                                   "[story-073] Seed phUSD/Kendu nudge streams, widen local window to 6h"
```

The contrast with its own delta base is the point: the baseline commit is tagged in the project's normal
convention, and the commit under audit is not. The `3fb4e34` tree contains **zero** "Story 079"
references; all of them arrive at `e1db0f1`.

**The attribution is broader than first measured.** The severity-classifier recorded 11 in-source
references (10 in `DeployMocks.s.sol`, 1 in `AddressLoader.sol`) from a case-sensitive grep for the exact
string `Story 079`. A case-insensitive sweep of the whole `script/` tree at `e1db0f1` returns **22 hits
across 6 files** — `DeployMocks.s.sol` (16), `AddressLoader.sol` (2, upper-case `STORY 079` at `:12` and
`:85`), plus `ClaimPhlimboRewards.s.sol`, `FullFlowTest.s.sol`, `SetDesiredAPY.s.sol` and
`WithdrawFromPhlimbo.s.sol` (1 each). The count is corrected **upward** here; the correction is disclosed
rather than silently substituted, and it strengthens rather than alters the conclusion — the un-storied
attribution spans six files, not two.

## 2. What the un-storied work actually is

This is not a stray comment. The work attributed to the non-existent story is **the entire subject of
this audit**:

- **The Phase 7.4 PhlimboV2 → PhlimboV3 cutover rehearsal** — the local mirror of the mainnet cutover,
  including the chunked two-pass staker migration through `MigratorV2V3`, the phUSD mint-authority
  transfer from V2 to V3, and the V2 wind-down.
- **The local-only Kendu promotion** armed on PhlimboV3 (`_armLocalKenduPromotion`), a state that story
  076 asserts must be *dormant* on mainnet.
- **The keyless DepositPageViewV3 registration** — deliberately never `_trackDeployment`-ed.
- **The `AddressLoader` rewrite**, including the `require(block.chainid == 31337, …)` guard added at
  `:48`.

These are precisely the changes a faithfulness review exists to grade, and they are **deliberately
divergent** from mainnet by design — the local chain arms a promotion mainnet will not have, deploys the
post-cutover dispatcher set greenfield rather than repointing an incumbent, and registers a view mainnet
keys differently. Deliberate divergence is exactly the category that requires stated acceptance criteria,
because without them there is no way to distinguish an intended shortcut from a mistake.

**No story that *does* exist covers it.** This was checked, not assumed:

- **Stories 076 and 077** scope themselves to the mainnet `script/` and `src/` trees and never mention
  `DeployMocks.s.sol`.
- **Story 078** mentions it — to **forbid** the change.

## 3. The aggravating fact: story 078 explicitly forbids modifying this file

Story 078 exists. It is the most recent story in the tree and it is in scope for this delta — the commit
immediately preceding `e1db0f1` in the log is `f556d22 [story-078] Hydrate newDepositPageViewV3 in
_parseProgressJson; guard the class`. In its constraints section, at
`~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-promotion-ready/078-wire-depositpageviewv3-into-cutover-and-collapse-view-keys-onto-viewrouter.md:299-301`,
it says, verbatim:

> - **`DeployMocks.s.sol` keeps deploying all four views locally.** Adding them to
>   `DROPPED_CONTRACT_NAMES` only stops them being *published* into the generated interface;
>   the local anvil environment is unaffected. **Do not modify `DeployMocks.s.sol`.**

The operative sentence, quoted exactly as written at line 301:

> **Do not modify `DeployMocks.s.sol`.**

The very next commit modified `DeployMocks.s.sol` by roughly a third of its length.

This changes the character of the finding. It is not merely *un-storied* — work can outrun its paperwork,
and that alone would be a mild documentation defect. It is un-storied **and contrary to an explicit
instruction in the one in-scope story that addresses the file**. Two readings are available and the audit
cannot choose between them from the artifacts:

1. **The instruction was superseded** by a decision taken after 078 was written, and that decision is the
   thing "Story 079" was supposed to record. In that case the missing document is the *only* record that
   the supersession was deliberate, and it is missing.
2. **The instruction was overlooked**, and a constraint a story author thought binding was silently
   broken.

Under reading (1) the fix is to write the story. Under reading (2) the fix is to review the change
against 078's intent. **Both fixes start with the same missing document**, which is why this is filed
rather than noted.

## 4. Related metadata defect: four of seven closure stories closed by machine approval

Surfaced while resolving the story tree, and recorded here because it bears directly on how much
assurance the surrounding story record carries:

- **Four of the seven** closure stories relevant to this cutover closed via an **undocumented
  `auto-complete` state**, each carrying: *"Approved by: story-batch workflow (machine approval — not
  human-reviewed)"*. The `auto-complete` folder is not described in the story workflow's own
  documentation.
- **Both audit-remediation stories, 074 and 075, are among them.** An audit-remediation story that closed
  without human review is the weakest possible link in the chain that this rehearsal exists to
  strengthen.
- **Story 075's own declared primary regression gate — `npm run promotion-ready:dry` — was never run.**
  The story nominates that command as the thing that proves its remediation landed, and the command has
  no execution record.
- Story **078**, whose forbidding instruction is quoted above, is itself in `auto-complete`.

None of this is a code defect and none of it is scored. It is recorded because the question this document
asks — *can this work be graded against its stated intent?* — is answered "no" twice over: once because
the story is absent, and once because several of the stories that *are* present closed without anyone
reading them.

## 5. What this finding does NOT claim

Stated plainly, because a provenance finding is easy to misread as a correctness finding:

**The code was checked and it behaves correctly on its own terms.** Empirically verified against the live
local chain during this run:

- Stake **conserved at 300e18** through the chunked two-pass migration.
- `PhlimboV2` drained to **0**.
- phUSD mint authority moved **V2 → V3** (`authorizedMinters(PhlimboV2) == (false, 1)`,
  `authorizedMinters(PhlimboV3) == (true, 1)`).
- The two-step APY latch committed on **both** contracts.
- The promotion armed with **four non-vacuous read-back `require`s** (`DeployMocks.s.sol:1913-1916`), all
  passing.
- `DepositPageViewV3` registered and returning a live **23-field tuple**.

The code is also unusually well commented, and argues each divergence from mainnet in place at the point
of divergence. **There is no behavioural deviation to report, no exploit, and no asset at risk.** Nothing
in this document should be read as impugning the implementation.

Note also, per project policy, that **the in-source comments declaring these divergences deliberate are
evidence of intent and carry no suppression authority.** A comment cannot supply the acceptance criteria
a story is supposed to supply, because a comment is written by the same hand that wrote the code — it
records what the author *did*, not what they were *asked* to do, and those are the two things a
faithfulness review exists to compare.

## 6. Why this is QA, and why QA does not mean quiet

**Severity: QA.** C4 places pure provenance and spec-documentation defects in QA when there is no
behavioural consequence, and here there is none — §5 is the reason. There is no state-handling defect to
anchor a Low. Escalating would require showing the un-storied work actually misbehaves; it was checked
and does not. It is ranked **first** in the QA bucket on the strength of the story-078 contravention.

**Visibility is a separate axis from severity, and this document is the mechanism.** Law 2 requires that
a story deviation be owner-visible; sorting F-01 into a QA bundle by impact would file the faithfulness
question — which is the *entire point* of the finding — as noise between a dead mock deployment and a
stale contract count. The QA grade is the honest severity. It is **not** a demotion of visibility, and
this report, not `qa-report.md`, is F-01's primary home.

**What is actually lost.** A substantial, deliberately-divergent change to the project's **only** cutover
rehearsal — the artifact whose whole purpose is to de-risk an imminent mainnet cutover — cannot be graded
for story-faithfulness by anyone. Not by the owner, not by a reviewer, and not by a future audit,
including a future audit of the mainnet cutover this rehearsal is supposed to protect. Under Law 2 that
is reportable in itself, independent of whether the code happens to be right.

## 7. Recommended Mitigation

**Primary — restore gradeability.**

1. **Write the missing story retrospectively and tag it**, or **re-attribute the work to a real story
   number**, and correct the **22 in-source references across 6 files** so they no longer point at a
   document that does not exist. A reference to a non-existent story is worse than no reference: it
   tells a future reader that acceptance criteria exist and can be consulted.
2. **Resolve the story-078 contravention explicitly, in writing.** If the "do not modify
   `DeployMocks.s.sol`" instruction was superseded, say so in the new story and say why — that record is
   the only thing distinguishing a deliberate supersession from an overlooked constraint. If it was
   overlooked, review the change against 078's intent before the cutover.

**Secondary — repair the process that let this through.**

3. **Document the `auto-complete` state** in the story workflow's own documentation, including what
   "machine approval — not human-reviewed" does and does not certify.
4. **Have a human re-review stories 074 and 075.** An audit-remediation story that closed by machine
   approval, whose declared primary regression gate (`npm run promotion-ready:dry`) was never run, is the
   weakest link in exactly the chain this rehearsal exists to strengthen. Run the gate.

**Ownership.** Items 1–2 are product-owner actions outside the code; items 3–4 are process actions. None
of the four is a code change, which is why this finding is flagged for human review rather than left to a
fix-and-recheck cycle.

---

## Findings NOT routed here, and why

For completeness of the Law-2 record, the other four findings in this run were each considered for a
faithfulness label and each declined one. Recording the negatives so a reader can see the routing was
decided rather than defaulted:

- **L-01** (rehearsal omits `setDispatcher` / `replaceDispatcher` / `hook.pull()`) — a coverage gap. No
  story requires the rehearsal to contain those calls, so there is no spec to deviate from.
- **L-02** (`clean:local` leaves stale `.ts` address artifacts) — a lifecycle/state-handling defect in a
  build script. No story governs it.
- **L-03** (local Kendu promotion never reaches the dormant state) — **Law-2 adjacent but deliberately
  not tagged.** The local chain *does* invert a story-076 mainnet invariant (`promoToken == address(0)`),
  but 076 scopes itself to mainnet `script/`/`src/` and the divergence is declared and deliberate at
  `DeployMocks.s.sol:183-198`. The filed defect is the *inverse* — that the dormant state is
  unreachable locally — which is a coverage issue, not a story deviation. Faithfulness routing for this
  run belongs to F-01 alone.
- **L-04** (deployer's phUSD minter grant never revoked) — a Law-3 operational footgun, not a spec
  deviation.

**Carryover note.** Prior-run faithfulness items for this entry point are not restated here. Audit 21's
`F-01`…`F-05` live in
[`reports/phoenix-phase-2-staging/21/submissions/spec-conformance.md`](../../21/submissions/spec-conformance.md);
their underlying findings are all still `open` and are carried forward in full at
[`submissions/carryover/qa-report-21.md`](./carryover/qa-report-21.md). Audit 26's `F-01` is a **new,
separate sequence** and must not be conflated with audit 21's `F-01` (`L-07`, `test:balancer-donation`).
