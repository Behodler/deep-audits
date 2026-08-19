# Carryover QA report — audit 26 (entry point `dev`)

> **Carryover QA report — audit 26** (cut down from `reports/phoenix-phase-2-staging-26/submissions/qa-report.md`).
> Retained below (still open or `fix-pending` as of audit 27): **L-01, L-03, L-04, Q-01**.
> Removed as no longer live: **L-02** (`ec29eacd9501…` / `pps26l2`, `clean:local` leaves stale `.ts` address books) — triaged **`wont-fix`** by a human. It is a disposal: not re-filed, not resurrected, not carried over. It was checked against audit 27's new `L-01` (`65db3324…`) and ruled a different script and a different mechanism (a revoked ACL grant, not a stale artifact).
> **Labels are the originals — the gap at `L-02` below is that removal, not an omission.** Nothing else was cut.
> Audit 26's labels are a **separate sequence** from audit 21's and from audit 27's own. Three findings on this entry point share the string `L-01`, three share `L-02`, three share `L-03`, three share `L-04`, three share `Q-01` and two share `Q-02`. **`L-02` is the one to watch here: the `L-02` removed from this bundle is audit 26's (`pps26l2`, `wont-fix`), which is a different finding from audit 27's live `L-02` (`pps27l2`).** **Key every reference on the fingerprint.**
> Line numbers were accurate at the originating commit `e1db0f1`; **re-verify against current HEAD `1d8a3a7` before acting** — the story-079 delta moved much of this code.

## ⚠ Status of each retained entry as of audit 27 — READ THIS BEFORE THE BODY

**Audit 27 changed no status on any entry in this file.** Three of the four were verified as
no-longer-reproducing and carry a **propose-fixed proposal only**; the fourth stays open on the story's
own authority.

| Label | Fingerprint | `issueId` | Status (unchanged) | Audit-27 disposition |
|---|---|---|---|---|
| **L-01** | `eda17642828a…` | `pps26l1` | **`fix-pending`** | **PROPOSE FIXED — not applied.** DEV27-V01 verified from the broadcast bundle that `pull` / `setDispatcher` / `replaceDispatcher` now execute **1/1/1 on both legs** (vs **0/0/0** at baseline), in the mandated fail-closed order, with the non-vacuity gate proven live. The **filed claim** ("executed zero times") no longer reproduces. `/ledger phoenix-phase-2-staging fixed pps26l1` — **⚠ HOLD, see the mutually-exclusive choice below.** |
| **L-03** | `12bcca3b617c…` | `pps26l3` | **`fix-pending`** | **PROPOSE FIXED — not applied.** DEV27-V02 reached a genuinely dormant chain through the real `npm run dev` key with `LOCAL_PROMO_KENDU=false`: `promoToken` `0x0`, phase 0, balance 0, rate 0, and `startPromotion` absent from the 391-tx bundle. `/ledger phoenix-phase-2-staging fixed pps26l3`. A residual is filed separately as audit 27's `Q-02` (`e0ac78243e5f…` / `pps27q2`) and **explicitly does not reopen this entry**. |
| **L-04** | `b8e3d59139ae…` | `pps26l4` | **`fix-pending`** | **PROPOSE FIXED — not applied.** DEV27-V03 confirmed the deployer phUSD revoke is broadcast **tx [393] of 394**, the last in the bundle, and the sweep's ACL table was checked for completeness against every grant site rather than only the one filed. `/ledger phoenix-phase-2-staging fixed pps26l4` — **⚠ schedule the regression it ships in the same sitting, see below.** |
| **Q-01** | `1c98937375ad…` | `pps26q1` | **`open`** | **STILL FULLY OPEN.** Story 079 now *exists* and was read — but its own **Concerns** section states verbatim that it is **not** the missing story and that **Q-01 remains open**, listing Q-01 under *Explicitly OUT of scope*. Closing this on the strength of the story number being consumed would be exactly the auto-close the rules forbid. Marginally **aggravated**: the number is now taken. `lastSeenRun` bumped to 27. **This is NOT audit 27's own `Q-01`** (`9067d8a232b5…` / `pps27q1`, the `tokenIdToDispatcher` assertion gap) — the two must never be merged. |

### Why nothing was flipped

`fix-pending` is **human-set and never auto-closed**. A fix that merely stops tripping the scan is not a
verified fix, and this status exists precisely because someone is relying on the fix landing correctly.
Audit 27 therefore wrote the outcome into **recheck-only fields** on each entry
(`lastRecheckedCommit` = `1d8a3a7`, `lastRecheckedRun` = 27, `recheckResult` = `propose-fixed`) and left
the `/ledger` commands for a human. All three remain **carried over in full**, exactly as `open` findings
would be, because `fix-pending` is never suppressed.

`lastSeenRun` was **deliberately not bumped** on L-01, L-03 and L-04: audit 27 did not *observe* them
live, it verified their filed claims no longer reproduce, so recording run-27 as a sighting would be
false. The run-27 touch lives in the recheck fields instead. (The classifier's record asked for a bump;
that instruction was declined and the conflict is disclosed here rather than resolved silently.)

### ⚠ Two decisions audit 27 deliberately did NOT make

**1. `L-01` — close it, or reopen it as an incomplete fix? Mutually exclusive.**
Audit 27 filed a **new, narrower** Low: `6af1ae30ed82…` / `pps27l2` — the rehearsal covers **1 of 5**
mainnet dispatcher swaps and the `REHEARSAL_SWAP_INDEX` constant is not actually re-targetable, so
index 4 (18-decimal prime, BPT custody shift) is rehearsed nowhere. A triager who reads run-26's
recommendation as having asked for **all five** classes would reasonably prefer to **reopen `pps26l1` as
an incomplete fix and decline `pps27l2`** instead. The two outcomes are **mutually exclusive**: do not
apply `fixed pps26l1` *and* keep `pps27l2`. Corroboration for taking it seriously: ledger `85d794b386b1`
(acknowledged Medium, entry point `dispatcher-replace-sky-pooler`) is a real index-4 cutover defect that
has **already shipped once**, at precisely the index shown to be unrehearsed. No agent took a position.

**2. `L-04` — closing it leaves a documented developer command broken.**
Audit 27's new `L-01` (`65db3324e7d0…` / `pps27l1`) is the regression **shipped by this fix**: the
terminal privilege sweep revokes the deployer's phUSD mint authority, and
`npm run test:fund-user` — pointed at four times by `script/interactions/README.md` — now exits 1 with
`Not authorized to mint` on every fresh chain, under a comment that still claims the deployer is an
authorized minter. The relation on the ledger is **`introducedBy`, not `incompleteFixOf`**: this fix is
**complete and correct** for the claim it closed. **Schedule the one-line fix in the same sitting as
`fixed pps26l4`**, or the closure reads as clean while the command stays broken.

*The text below is a copy of the audit-26 QA report with the `L-02` section deleted and nothing else
changed. Do not re-severity or re-summarise it; every audit-27 fact is in the tables above. The copied
body's own summary counts and links describe **audit 26** as it stood at `e1db0f1`; the retained set is
the four entries in the table above, not the five that body counts.*

---

## Low Risk Findings

### [L-01] `dev` rehearses the cutover's end state but not its cutover mechanics: `setDispatcher`, `replaceDispatcher` and `hook.pull()` are executed zero times <!-- id: pps26l1 -->

**Severity:** Low · **Entry Point:** `dev` · **Origin:** new · **Status:** open
**Fingerprint:** `eda17642828a6dd3bce6890d9900add9d27a317f80b78212a30f123301d17fd4`
**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol` — `run` (the defect is an
*omission*: the three call sites exist zero times in the file, so there is no single line to point at;
the mainnet counterpart's ordering contract is documented at
`script/DeployMainnetPromotionReady.s.sol:145-156`, with the preservation assertions at `:1366-1372`
and `:1536`)
**Evidence:** [`script-audits/dev/evidence/cast-live-state.log`](../script-audits/dev/evidence/cast-live-state.log)
(also `dev-script-narrative.log`, `AuditRun26DevLiveState.t.sol`, `REPRODUCE.md`)
**Record:** [`findings/low/L-01-rehearsal-omits-cutover-mechanics.json`](../findings/low/L-01-rehearsal-omits-cutover-mechanics.json)
**Flagged for human review:** yes — borderline Low/Medium (see *Severity note* below)

**Description.** `DeployMainnetPromotionReady.s.sol` calls `setDispatcher` 9 times, `replaceDispatcher`
9 times and `hook.pull()` at least 3 times. `DeployMocks.s.sol` calls each of them **zero** times.
Verified on the live chain: `NFTMinterV2.nextIndex == 8` with `configs[1..7]` each populated exactly
once and never repointed — the local chain deploys the post-cutover dispatcher set greenfield, because
it has no incumbent to displace. The mainnet script documents the per-index order at `:145-156` —
`hook.pull() -> hook.setDispatcher(new) -> new.setHook(hook) -> replaceDispatcher(idx, new)` — and
states in its own words that the reverse order *"would put the new dispatcher live on the index while
it still carried the fresh DefaultDispatchHook that ATokenDispatcherV2's constructor gave it, so mints
would SUCCEED while accruing no mint debt — a silent value leak. Never do that."* The one ordering in
the whole cutover whose wrong direction is **silent** rather than loud is the one the local mirror
never executes.

The same omission means these mainnet claims are never exercised locally: that `replaceDispatcher`
preserves `price`/`growthBasisPoints` (asserted at `:1366-1372` and `:1536`); that
`NudgeRatchet._dispatch`'s `hookTypeId() == EXPECTED_HOOK_TYPE_ID` guard holds across a hook reuse; and
that `NudgeRatchetMintDebtHook`'s non-default `DEFAULT_RATIO == 100` is not silently reset. Two
adjacent cutover behaviours are likewise absent with no analogue: old-batch-minter retirement
(`setPauser(OWNER)` + `pause()`), and the story-074 write-once BPT custody baseline / resume-leg
handling — the latter structurally un-rehearsable because `DeployMocks` writes
`deploymentStatus: "completed"` unconditionally and can never record `in_progress` or `failed`.

**Impact.** A reordering regression in the mainnet cutover script — the exact defect class the mainnet
script's own comment flags as a silent value leak — would pass the local rehearsal unchanged, because
the local rehearsal contains none of the calls involved. The rehearsal's green result therefore carries
less assurance than it appears to, which is the concealment bar. **No claim is made that the mainnet
ordering IS wrong**; the finding is that `dev` cannot tell you either way.

**Recommendation.** Add a Phase 7.6 to `DeployMocks.s.sol` that, after the greenfield dispatcher set is
live, deploys ONE replacement dispatcher and performs a genuine
`hook.pull() -> hook.setDispatcher(new) -> new.setHook(hook) -> replaceDispatcher(idx, new)` on a single
index, asserting (i) mint-debt conservation across the swap, (ii) `price`/`growthBasisPoints` preserved,
and (iii) that a mint attempted in the intermediate window REVERTS rather than succeeding. One index is
sufficient to make the ordering executable and therefore regression-testable. Separately, run
`VerifyPromotionReady.s.sol` (story 075) against the local end state — it is free there, and story 075
closed via machine approval with its own declared regression gate never run.

**Severity note (human review).** Graded Low on demonstrated impact: `dev` never broadcasts, holds no
value, and the mainnet script it fails to rehearse was **not** shown to be defective. A reviewer who
regards the untested silent-leak path as an availability risk to the imminent cutover may argue Medium.

**Do not re-file.** The unconditional `deploymentStatus: "completed"` write named above is already
ledger entry `1e8cc0dc58ba` (L-01, open, re-observed STILL-LIVE this run). It is cited here as the
*cause* of one sub-gap, not re-filed; downstream must not mint a second entry for it.

---

### [L-03] The local chain arms a Kendu promotion that story 076 asserts must be dormant on mainnet, and never produces the dormant state the UI will actually ship against <!-- id: pps26l3 -->

**Severity:** Low · **Entry Point:** `dev` · **Origin:** new · **Status:** open
**Fingerprint:** `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79`
**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:1902-1921`
(`_armLocalKenduPromotion`; call site at `:1890`; declared-deliberate comment at `:183-198`)
**Evidence:** [`script-audits/dev/evidence/live-state-fork-test.log`](../script-audits/dev/evidence/live-state-fork-test.log)
(also `dev-script-narrative.log`, `AuditRun26DevLiveState.t.sol`)
**Record:** [`findings/low/L-03-local-kendu-promotion-never-reaches-dormant-state.json`](../findings/low/L-03-local-kendu-promotion-never-reaches-dormant-state.json)

**Description.** `_armLocalKenduPromotion` arms a 10,000-Kendu / 1-day promotion on PhlimboV3. Verified
live: `promoToken == MockKendu`, `promoPhase == Active (1)`, `promoRewardBalance == 10,000e18`,
`promoRewardPerSecond == 1.157e35`. Story 076 asserts the exact opposite for mainnet —
`promoToken == address(0)`, Kendu deliberately unset, Phase 7 asserting the negative — and
`DeployMainnetPromotionReady.s.sol` calls `startPromotion` nowhere.

**The arming itself is admissible and is not the finding.** It is declared deliberate at `:183-198`,
argued well (with no promotion running, every new V3 UI field — 13/16/17/18/19 plus the three
unclaimable banks on `DepositPageViewV3` — reads zero, which is indistinguishable from a broken
binding), and carefully sequenced dead-last so the migrator's `promoToken`-delta path stays dormant
during the migration. The finding is the **inverse**: because the promotion is armed unconditionally at
the end of *every* local run, no local run ever produces the **dormant** promo state that mainnet will
actually ship on day one. The UI's dormant-promotion rendering path is the one path `dev` never
exercises, and it is the path that goes live first. Compounding it, `mainnet-addresses.ts` carries
`Kendu: "0x000…0"` (ledger `3177eed94ecb`), so a UI developer working against `dev` sees an active
promotion on a live Kendu token where mainnet will present a dormant promotion on the zero address.

Per project policy, the in-source comment declaring this deliberate is **evidence of intent, not
suppression authority**.

**Impact.** The day-one mainnet UI state — dormant promo, zero-address Kendu — is the single state the
local rehearsal cannot produce, so any rendering bug specific to it (a zero-division on
`promoRewardPerSecond`, a null-token symbol lookup, a banner that renders "promotion active" off a
non-zero `promoPhase` enum) ships unrehearsed. This is a purpose-(b) blind spot created by an
otherwise-sound purpose-(b) shortcut.

**Recommendation.** Make both promo states reachable locally. Cheapest: gate the call on an env flag
(`LOCAL_PROMO=off` skips `_armLocalKenduPromotion`) so a developer can boot the dormant chain on demand.
Better: add a follow-on local phase that ends the promotion after arming it, so a single `npm run dev`
produces the armed state AND leaves a documented one-command path to the dormant/depleted state. Either
way, keep the four non-vacuous post-condition `require`s — they are correct and should not be relaxed.

**Do not re-file.** The `Kendu: 0x0` half of the compounding argument is ledger entry `3177eed94ecb`
(re-observed this run as `DEV26-01`, collapsed). Cited, not re-filed.

---

### [L-04] The deploy script grants itself phUSD mint authority and never revokes it, while correctly revoking PhlimboV2's grant in the same run <!-- id: pps26l4 -->

**Severity:** Low · **Entry Point:** `dev` · **Origin:** new · **Status:** open
**Fingerprint:** `b8e3d59139aeee24bd97a6e1087c3e992ab4dee99949a7bde8c30d55ee5e84f6`
**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:1784`, `:2025`, `:2122`
(`run` / `_seedNudgeStream`)
**Evidence:** [`script-audits/dev/evidence/cast-live-state.log`](../script-audits/dev/evidence/cast-live-state.log)
(also `dev-script-narrative.log`)
**Record:** [`findings/low/L-04-deployer-phusd-minter-grant-never-revoked.json`](../findings/low/L-04-deployer-phusd-minter-grant-never-revoked.json)
**Classification:** non-obvious owner footgun / operational hazard (Law 3). **No malicious-owner vector
is asserted anywhere in this finding.** Considered for `C-01` and rejected — see the Centralization
note in the summary above.
**Flagged for human review:** yes (see *Collapse condition* below)

**Description.** `phUSD.setMinter(deployer, true)` is granted at `:1784`, `:2025` and `:2122` and is
never revoked. Verified live at the end of the run:
`phUSD.authorizedMinters(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) == (true, 1)`. The grant is a
legitimate local shortcut — the deployer acts as a synthetic donor to seed the phUSD nudge stream,
which story 073 sanctions — and the token is a mock on a chain whose keys are public, so there is no
local risk.

The finding is the **inconsistency** and what it costs the rehearsal: the same script, in the same run,
correctly revokes PhlimboV2's grant as an explicit ordered step of the Phase 7.4 wind-down (verified:
`authorizedMinters(PhlimboV2) == (false, 1)`, `authorizedMinters(PhlimboV3) == (true, 1)`), and logs it
as such. So privilege revocation is clearly understood as a first-class cutover step here — just not
applied to the deployer's own grant. Consequently the local chain's end state carries a live minter
that mainnet's end state must not, and the "revoke the operational key's temporary grant" step is never
rehearsed even though it is precisely the kind of step that is easy to forget on a Ledger broadcast.

**Impact.** No local risk (mock token, public anvil key). The cost is rehearsal fidelity: a
residual-privilege sweep is never exercised, and the local end state differs from the intended mainnet
end state in a way no assertion catches. This is an owner footgun of the non-obvious kind — the
script's own careful revocation of the *other* grant makes it read as though residual privileges were
swept.

**Recommendation.** Revoke the deployer's grant at the end of `run()` with
`phUSD.setMinter(deployer, false)` and assert it, mirroring the Phase 7.4 wind-down's own pattern.
Better still, add a terminal "residual privilege sweep" phase that asserts the full expected end-state
ACL — deployer not a minter, PhlimboV2 not a minter, PhlimboV3 a minter — so the check is declarative
and a future grant that forgets to clean up fails the run.

**Collapse condition.** The keep rests entirely on the revocation-asymmetry argument. If the owner
confirms the deployer grant is intentionally permanent on the local chain, this collapses to a
non-finding and should be triaged **`wont-fix`** rather than re-graded.

---

## Centralization Risks

**None this run.** See the Centralization note under *Summary* for the reasoning that kept L-04 out of
this section. No other candidate reached this bucket.

---

## QA

### [Q-01] The un-storied "Story 079" work has no acceptance criteria anywhere to be graded against <!-- id: pps26q1 -->

> **This is a summary. The primary record is [`spec-conformance.md`](./spec-conformance.md), where this
> item is **F-01** at full narrative length.** It is the run's only Law-2 faithfulness item and the only
> QA item. Law 2 forbids burying a story deviation in the QA/gas bundle, so it is listed here for
> completeness of the QA record only — it is not reduced to this entry, and nothing here overrides or
> contradicts the fuller document.

**Severity:** QA · **Entry Point:** `dev` · **Origin:** new · **Status:** open
**Fingerprint:** `1c98937375adc20c171c86ba91246476283add1bf72736a0e945606c643d1e9e`
**Spec-conformance label:** `F-01`
**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol`
(`run` / `_rehearsePhlimboV3Cutover` / `_armLocalKenduPromotion`), plus
`script/interactions/AddressLoader.sol:12`, `:85`
**Evidence:** [`script-audits/dev/evidence/story-079-glob.log`](../script-audits/dev/evidence/story-079-glob.log)
(also `dev-script-narrative.log`)
**Record:** [`findings/qa/Q-01-story-079-does-not-exist.json`](../findings/qa/Q-01-story-079-does-not-exist.json)
**Flagged for human review:** yes — resolution requires an owner/product-owner action outside the code

**Description (summary).** `script/DeployMocks.s.sol` and its sibling interaction scripts attribute
their most substantial change to **"Story 079"**. Globbing the entire `phStaging2` story tree across
*all* state folders (`complete`, `incomplete`, `review`, `auto-complete`) for `079-*.md` and
`079.*-*.md` returns **zero hits**; the highest existing `phStaging2` story is 078. This is stated
positively — **the story does not exist**, it is not merely unavailable. The only `079` anywhere under
the stories tree belongs to a different project and is unrelated. Every occurrence was introduced by
head commit `e1db0f1`, which is itself **untagged** (no `[story-NNN]` prefix); the delta base `3fb4e34`
contains none.

The work so attributed is the whole subject of this audit — the Phase 7.4 PhlimboV2→V3 cutover
rehearsal, the local-only Kendu promotion, the keyless `DepositPageViewV3` registration, the
`AddressLoader` rewrite. It is also covered by no story that *does* exist: 076 and 077 scope themselves
to mainnet `script/`/`src/` and never mention `DeployMocks`, and **078 explicitly instructs "Do not
modify `DeployMocks.s.sol`."** Related metadata flag: four of the seven closure stories closed via an
undocumented `auto-complete` state carrying *"Approved by: story-batch workflow (machine approval — not
human-reviewed)"*, including **both** audit-remediation stories 074 and 075, and story 075's own
declared primary regression gate (`npm run promotion-ready:dry`) was never run.

**This is a provenance gap, not a correctness gap.** The work was verified to behave correctly on its
own terms: stake conserved at 300e18 through a chunked two-pass migration, V2 drained to 0, mint
authority moved V2→V3, the two-step APY latch committed on both, the promo armed with four non-vacuous
read-back `require`s, and `DepositPageViewV3` registered and returning a live 23-field tuple. The code
is unusually well commented and argues each divergence in place.

**Reference count — two statements, both standing.** The classified record states **11** occurrences
(10 in `DeployMocks.s.sol` + 1 in `AddressLoader.sol`); that count is **case-sensitive** for the exact
string `Story 079` and stands as its own statement. A **case-insensitive** sweep of the whole `script/`
tree at write time found **22** occurrences across **6** files: `DeployMocks.s.sol` (16),
`AddressLoader.sol` (2, upper-case `STORY 079` at `:12` and `:85`), `ClaimPhlimboRewards.s.sol` (1),
`FullFlowTest.s.sol` (1), `SetDesiredAPY.s.sol` (1), `WithdrawFromPhlimbo.s.sol` (1). The higher figure
is the one a remediation must work from — the four interaction scripts were outside the originally
searched path.

**Impact.** No behavioural impact. The cost is that a substantial, deliberately-divergent change to the
project's only cutover rehearsal cannot be graded for story-faithfulness by anyone — including a future
audit — because no acceptance criteria exist, and one story in scope actively forbids the change that
was made. Under Law 2 that is reportable in itself.

**Recommendation.** Write the missing story retrospectively and tag it, or re-attribute the work to a
real story number and correct the eleven in-source references so they do not point at a document that
does not exist. Separately, surface the `auto-complete` state in the story workflow's own documentation
and re-review 074/075 by a human — an audit-remediation story that closed by machine approval, whose
declared regression gate was never run, is the weakest link in the chain that this rehearsal exists to
strengthen.

> *Remediation scope note:* the recommendation above is reproduced verbatim from the finding record and
> says "eleven in-source references". Per the reference-count paragraph above, the corrective sweep must
> cover **22 occurrences across 6 files**, case-insensitively. The full treatment is in
> `spec-conformance.md`.

---

## Appendix A — Automated report (4naly3er)

**4naly3er produced no report for this entry point. The gap is recorded rather than left silent.**

4naly3er was run against the `dev` closure's first-party Solidity
(`script/DeployMocks.s.sol`, `script/interactions/AddressLoader.sol`) from a writable
`workspace/phoenix-phase-2-staging` checkout at `e1db0f1`, with the tool's `basePath` anchored at the
submodule root and the project's 52 `foundry.toml` remappings materialised as `remappings.txt` so the
tool could resolve them. It still fails to build an AST:

- Without a materialised `remappings.txt`: `@forge-std/Script.sol import not found`.
- With one: the compile aborts on repeated `DeclarationError: Identifier already declared` — e.g.
  `import "@pauser/Pauser.sol"` colliding with `lib/mutable/pauser/src/interfaces/IPausable.sol:15`,
  and `import "@stable-yield-accumulator/StableYieldAccumulator.sol"` colliding with both
  `@phlimbo-ea/IFlax.sol:10` and `@phlimbo-ea/interfaces/IPhlimbo.sol:11`. 4naly3er then throws in
  `uselessOverride` on the missing AST.

This is the **same tool limitation recorded in run-25**, now reproduced on the `dev` closure: 4naly3er's
own solc invocation does not honour the repo's `lib/<a>/lib/<b>/=` diamond-canonicalization remappings,
so the same physical dependency resolves under two identities. **The affected files compile cleanly
under `forge`** (`forge build` on the same workspace checkout completes with no errors), which confirms
the failure is the tool's resolution, not the source.

Failure transcript: [`script-audits/dev/evidence/4naly3er-failure.log`](../script-audits/dev/evidence/4naly3er-failure.log).
No `submissions/4naly3er-report.md` exists for this run. The manual QA bundle above proceeds without
that baseline; the temporary `remappings.txt` was removed from the workspace afterwards.

---

## Appendix B — Visible but not filed

These items were surfaced during the run and deliberately **not** filed as findings. They are recorded
here so they are not lost, per the recall-beats-tidiness rule.

**`MR-26-DEV-01` — `clean:local` reaches shared user state outside the repo.** The `clean:local` chain
ends in `rm -rf ~/.foundry/anvil/tmp/*`, which is outside the repository and shared by every Foundry
process on the machine. **The observed consequence was refuted:** 60/60 samples of that directory taken
across a full `npm run dev` were empty, so no in-flight state was destroyed in the exercised path. The
branch that was **not** tested is a *concurrently-running forked anvil*, which is the case that would
have state there to lose. **Parked, not closed** — the hypothesis is unrefuted for that branch.
Evidence: `script-audits/dev/evidence/anvil-tmp-watch.log`.

**`SAN-26-DEV-02` — two `dev` ledger entries carry no `rootCauseClass`.** Entries `0b497be32114`
(status `open`) and `c294d93f772b` (status `fixed`) lack the `rootCauseClass` component, so their
stored fingerprints **cannot be reproduced** from the recorded inputs. A re-audit that recomputes rather
than reads would fail to match `0b497be32114` and **re-file it as a new finding**. Fix is a **human
backfill of the missing field**, leaving the **stored fingerprints untouched** — recomputing them would
break reconciliation against every prior run. (Same class as the previously-noted phStaging fingerprint
drift on `deploy:ratchet-mainnet`.)

**`SAN-26-DEV-04` — `a37137b3e369` (Q-03) is a split condition.** That entry bundles two halves. Its
open **CORS** half is **still live** at `server/index.js:2` and `:11` and was re-observed this run. If
the stale-manifest half is fixed, the CORS half **must be split into its own ledger entry** and carried
forward — it must never be closed together with the manifest half, which would silently retire a live
issue.

**Known-issues suppression.** None applied, none available — see *Known issues* under *Summary*
(watch-note `KI-24-01`).
