> # Carryover QA report — still-open Low / QA findings from audits **22** and **23**
>
> **Cut down from** `reports/phoenix-phase-2-staging-22/submissions/qa-report.md` and
> `reports/phoenix-phase-2-staging-23/submissions/qa-report.md`.
>
> **Retained below: all 17 entries** that remain `open` in the ledger as of audit 24 —
> **13 Low + 4 QA**.
> **Removed as no longer live: none.** Every Low/QA entry from audits 22 and 23 on the
> `promotion-ready` suite is still `open`; nothing was pruned and there are no gaps in either
> label sequence.
>
> **Originating run is stated per section**, and each section carries its **full, unshortened
> ledger fingerprint** — labels alone are ambiguous, because audit 22, audit 23 and audit 24 each
> have their own `L-01`…`L-0n` / `Q-01` sequences and they are **different findings**.
>
> **File-naming note (deviation, declared):** convention is one carryover file per originating
> audit (`qa-report-22.md` + `qa-report-23.md`). Both cohorts are consolidated into this single
> file at the operator's instruction, so that a reader of run-24 sees the entire outstanding
> Low/QA picture for the `promotion-ready` suite in one place. Nothing is omitted by the merge;
> the originating audit is named on every section.
>
> **Not re-tested this run.** Run-24 audited the **story-076 delta only** (Phase 4e: PhlimboV3
> cutover + PhlimboV2 user-base migration). None of the 17 findings below was re-observed or
> re-tested, and **a finding not re-observed is not evidence that it was fixed**. No status is
> changed or proposed here, and **no ledger write was performed**.
>
> **Line numbers** were accurate at the originating commits `5ae94bd` (audit 22) and `c4396b1`
> (audit 23); re-verify against current HEAD `b9391b1` before acting.

**Run-24 context**: `phoenix-phase-2-staging` @ `b9391b199ef38d7bf5066b6cd81d21b283a3a4e1` (`b9391b1`), branch `master`, script audit of the `promotion-ready` mainnet cutover suite.

**Companion carryover**: the still-open **Medium** on this suite — `2c53e944caee2e74a1a351c9b30b9e92cd8feac28203e8d5c1c9b7d9e8b4102f`, status **`fix-pending`** — is carried in full at `submissions/M-01-C1.md`. That file is **not** run-24's own `submissions/M-01.md` (`6b63ef6516ac…`).

---

## Index — 17 carried findings

| Origin | Label | Fingerprint (full) | Sev | Entry point | Status as of audit 24 |
|---|---|---|---|---|---|
| audit 22 | L-01 | `c04da307336ccff090b5e9f25b9a9451f9c2007d46483f562ee711ad378a7243` | Low | `promotion-ready:broadcast` | open — **conditional-Medium trigger armed** |
| audit 22 | L-02 | `4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42` | Low | `promotion-ready:broadcast` | open — historic `fixed` **proposal, never applied** |
| audit 22 | L-03 | `ea648ec5eab0c92624bed78b303577423967385a48df8738b68153c50cba9324` | Low | `promotion-ready:broadcast` | open |
| audit 22 | L-04 | `e6f32c475e7a9213fd03495f3aa8ad326e8928fb91d9be5403df48a2cd57986a` | Low | `promotion-ready:broadcast` | open — materially de-risked, **not fixed** |
| audit 22 | L-05 | `3c957109ef53404376145e81a57d23db18474cc1ba0174dc7fc0f4f60e33190d` | Low | `promotion-ready:broadcast` | open — also faithfulness **F-02** |
| audit 22 | L-06 | `78c91a8727eb99aa4ba339497a890988c8a9cb3407214d7af4402a499b80404f` | Low | `promotion-ready:broadcast` | open |
| audit 22 | L-07 | `b28492ce9719af2d7117f52fa3cc04138c7f1764ca6e1848da9ebf6de0d19685` | Low | `promotion-ready:broadcast` | open — scope-narrowed (SN-23-01) |
| audit 22 | L-08 | `d5d55f34c5d6ffa3f24c7833b43d707dbba4e1336eb558db9f7a3bde54946576` | Low | `promotion-ready:broadcast` | open — also faithfulness **F-03** |
| audit 22 | Q-01 | `909e6d267d4c99d5dc44600c4a96700b6f3334005840ac3b24ca50530817398e` | QA | `promotion-ready:broadcast` | open |
| audit 22 | Q-02 | `b3caa280e070dbb4aa16956cce8598a7025e7ad76346d412cf65eb8efca943ff` | QA | `promotion-ready:broadcast` | open |
| audit 22 | Q-03 | `050428e852c4e27de20a44cbec65bb1b764b15af73bb5fa987e5b2acb871a8bf` | QA | `promotion-ready:broadcast` | open |
| audit 23 | L-01 | `2212c1c4e8c8cd2271cc3c0c5c7e9180d0e2597cfbbdd97631431724e899525d` | Low | `promotion-ready:broadcast` | open — also faithfulness **F-01-072** |
| audit 23 | L-02 | `d99738d3a05c44aa0171efb976164815c8dec5c8d75ab5762d0cfd894b364c29` | Low | `promotion-ready:broadcast` | open — also faithfulness **F-02-072** |
| audit 23 | L-03 | `5c6d2c9e3b9806b89ca5484e3af8dab3f5ee9aa7240e93b526f0808b324d8818` | Low | **`promotion-ready:verify`** | open |
| audit 23 | L-04 | `80a741a27fe0fded541073aa2e3c4e8d37a6dbeff5920e0ff64b0e71273aac1a` | Low | `promotion-ready:broadcast` | open — residual **introduced by a fix** |
| audit 23 | L-05 | `f59e177a97c8842940bc0ccf4b3e28be506074e9e85fb7fed3a52aec87866bf2` | Low | `promotion-ready:broadcast` | open — walked back from Medium |
| audit 23 | Q-01 | `5e2e125056eb91aef164c9626c81cef04a3c73a6bfb20e198582781b9bc84bac` | QA | **`promotion-ready:verify`** | open — deliberate downgrade Low→QA |

**Label-collision warning.** Audit 22's `L-01` and audit 23's `L-01` are different findings, as are
the two `L-02`s, `L-03`s, `L-04`s, `L-05`s and `Q-01`s — and run-24 has a third set of its own in
`submissions/qa-report.md`. Always disambiguate by fingerprint.

---
---

# PART A — Carried from **audit 22** (`5ae94bd`)

*11 entries: 8 Low, 3 QA. Section text is reproduced verbatim from `reports/phoenix-phase-2-staging-22/submissions/qa-report.md`; labels are the originals.*

## Low Risk Findings (audit 22)

### [audit 22 · L-01] A user who stakes between snapshot generation and the on-chain pause is silently stranded on a paused, defunded, Pauser-deregistered V1 staker

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `c04da307336ccff090b5e9f25b9a9451f9c2007d46483f562ee711ad378a7243`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low — **CONDITIONAL MEDIUM, TRIGGER ARMED. Do not file this as routine.**
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1388-L1398` — `_migrateStaker`
**Root cause class**: `FrozenUserListVersusLiveStakingWindow`

> ### ⚠ CONDITIONAL-MEDIUM REOPEN TRIGGER — carried verbatim
>
> **RE-CLASSIFY AS MEDIUM if ANY of the following holds at broadcast time: (a) story-072 checklist line 1195 is still unticked when the Ledger session begins - the sole reason this is Low is that a specific, sufficient detection control is designated, and an unticked control is not a control; (b) the snapshot is older than a documented freshness bound at consumption time; (c) the staker population grows materially beyond the 6 addresses observed at block 25659373. This trigger must be carried into the ledger entry verbatim.**
>
> **Primary trigger**: story-072 checklist **line 1195** is still UNTICKED when the Ledger session begins — *an unticked control is not a control*, and it is the sole reason this is Low rather than Medium.
> **Armed if**: remediation option (b) below (freshness gate only) is chosen. It **narrows** the window; it does not close it. Only option (a) closes it.

**Description**: `snapshot-depletion-stakers.js` freezes the migrate user list at block N, and forge's local pass freezes it a second time. `NFTStakerDepletion.stake` is UNGATED during `Migrating` (`NFTStakerDepletion.sol:550`, audit-20 M-05), and V1 is not actually paused until the `st_<label>_pause` transaction lands on-chain — potentially hours into the Ledger session. A user who stakes inside that window is absent from `users`, so `migrate(users)` skips them.

The stated backstop `require(old.totalStaked() == 0, "V1 still holds stake after migrate - widen the snapshot and re-run")` at `:1394` cannot catch it: like all of Phase 6 it evaluates in the local pass against pre-broadcast state (see the carried Medium `M-01-C1.md`). Step 9 then sweeps V1's reward budget down to a ~1% residual, and V1 has already been unregistered from the global `Pauser`, so a later `Pauser.unpause()` will not reach it.

*(The vacuous guard at `:1394` is a **citation** of the Medium, not an overlap: this finding remains valid even if the guard were made real, because the user would then merely halt the cutover rather than be silently skipped.)*

**Impact**: An end user's staked NFT position and its future emissions become UNAVAILABLE on a retired contract. No value is destroyed and nothing is transferred to a third party: the position remains on V1, the owner retains `setPauser`/`unpause`, `migrate` is re-runnable by design, and V1 can be re-funded or V2 topped up. Recovery is full and owner-controlled — but manual, and undetected until someone looks.

**Recommendation** (verbatim, in full):

> Close the window rather than narrow it: split the pause out of the frozen plan. Either (a) pause all three V1 stakers in a separate, short broadcast BEFORE generating the snapshot, so the user list is taken against an already-frozen contract - the snapshot header's 'does NOT need to be taken after a pause' rationale then no longer applies and the list becomes provably final; or (b) add a hard freshness gate: record the snapshot's `blockNumber` in the JSON (it already is) and `require(snapshotBlock >= block.number - N)` in Phase 0 so a stale list cannot be consumed at all. (b) is cheap and also fixes PR-03's late-failure problem. Independently, keep the story's 'Open items carried to review' instruction - re-run `promotion-ready:snapshot` immediately before the session - as an operator gate.
>
> CLASSIFIER ADDENDUM: option (a) is the only one that CLOSES the window; (b) only narrows it. If (b) is chosen, the conditional-Medium reopen trigger above stays armed.

**Remediation overlap (preserved)**: a Phase 0 `require(snapshotBlock >= block.number - N)` would narrow this window and satisfy part of **audit 22 L-07** (`b28492ce…`). If L-07's recommendation is implemented in full, re-check this entry for partial closure — **but do not auto-close it**: narrowing a window is not closing it, and the ungated `NFTStakerDepletion.stake` during `Migrating` (audit-20 M-05) is unchanged.

---

### [audit 22 · L-02] Phase 7's BPT conservation assertion degrades to `>= 0` on every resume path, leaving the largest asset in the cutover unverified exactly when verification matters most

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low — **CONDITIONAL MEDIUM + FIX-ORDERING CONSTRAINT**
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1563-L1564` — `_phase7_wiringAssertions`
**Root cause class**: `VacuousAssertionUnderResumeSemantics`

> ### ⚠ HISTORIC `fixed` PROPOSAL — RECORDED, NEVER APPLIED, AND **NOT** RE-PROPOSED HERE
>
> Audit 23 recorded a script-auditor fork verdict of COMPLETE FIX for this entry after story-074
> landed the write-once `bptAtCutover` baseline, and wrote it to the ledger as
> `proposedStatus: "fixed"`. **That proposal was never applied and the entry's status is still
> `open`.** Run-24 did **not** re-test this finding and does **not** re-propose the flip.
> Only a human applies `fixed`:
> `/ledger phoenix-phase-2-staging fixed 4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42`
>
> **Read audit 23's L-04 (`80a741a27fe0fded…`, Part B below) first**: it is a residual introduced
> by that very fix — the persisted baseline carries no provenance binding, so a hand-mangled digit
> is accepted as the write-once value.

> ### ⚠ FIX-ORDERING CONSTRAINT — load-bearing
>
> **IMPLEMENT THIS BEFORE THE MEDIUM (`2c53e944caee…`, `M-01-C1.md`).** This is the decisive inversion the deduplicator preserved and it must survive into the report: a consolidation of this entry into the Medium, or a Medium fix shipped alone, would **silently widen this bug while reading as a resolution**.
>
> ### ⚠ CONDITIONAL-MEDIUM REOPEN TRIGGER — carried verbatim
>
> **RE-CLASSIFY AS MEDIUM if any of the six `_moveBPT` guard rails is weakened, removed, or refactored - they are the sole reason this is Low. In particular, M-01's recommended fix (relocating Phase 7 to a standalone post-broadcast verifier) ACTIVELY WORSENS this finding: the relocated Phase 7 would re-read `bptAtPhase0` from an already-emptied `OLD_POOLER`, making the assertion vacuous on the FRESH path too. If M-01's fix is implemented without persisting `bptAtCutover`, this becomes a Medium.**

**Description**: A first broadcast leg completes the BPT move (`OLD_POOLER` → `newPooler`) and the session is then interrupted. The operator runs `:resume`. Phase 0 re-reads `bptAtPhase0 = IERC20(BALANCER_POOL).balanceOf(OLD_POOLER)` at `:505`; the old pooler is now empty, so `bptAtPhase0 == 0`. Phase 7's `require(IERC20(BALANCER_POOL).balanceOf(newPooler) >= bptAtPhase0)` therefore reduces to `>= 0` — unconditionally true, and would remain true even if the 16,338 BPT sat on a third address. The companion `require(balanceOf(OLD_POOLER) == 0)` at `:1563` still holds, but "the old pooler is empty" and "the new pooler is full" are different claims; only the vacuous one covers the second. This is the exact step the `//promotion-ready:resume` annotation singles out as "THE ONE STEP A BAD RESUME COULD RUIN".

**Impact**: None demonstrated. 16,338.8190 BPT is the largest single asset in the closure and the assertion intended to confirm its arrival becomes `balanceOf(newPooler) >= 0` on any resume leg where the move already landed. But the audit could not construct a state in which the BPT actually goes astray: the six `_moveBPT` guard rails were independently assessed as effective in EVERY enumerated resume branch. The loss is one layer of defence-in-depth, not custody. The 16,338.8190 BPT magnitude justifies the **ordering** and the conditional-Medium trigger, **not** a Medium tier.

**Recommendation** (verbatim, in full):

> Persist the Phase 0 BPT reading across resumes rather than re-deriving it. Record it in the progress file as a first-class entry (the `ContractDeployment` struct already carries unused `uint256` fields, or add a sibling `bptAtCutover` key) and, when a progress file is present, assert `balanceOf(newPooler) >= recordedBpt` instead of the freshly-read zero. A cheaper stopgap: when `_isConfigured("pooler_bpt")` is true, assert `balanceOf(newPooler) > 0` at minimum, so the resume path is never fully vacuous.
>
> CLASSIFIER ADDENDUM: land this BEFORE M-01's verification entry point, and have that entry point consume the persisted `bptAtCutover` rather than a freshly-read Phase 0 value.

**Class siblings — linked, NOT collapsed**:
- ledger `2f8e1ff5e1aed9ffb17444b2ccd3e57b4029363045955aaa412217a4e41facae` (UBC-02, `uniboost-cutover`, run-20, low/open) — same resume-semantics family, distinct instance. UBC-02 is a checkpoint whose GRANULARITY lets resume skip real work; this one is a checkpoint-derived BASELINE that resume reads as zero.
- ledger `141aceaae3946026f516a8f74fedf3e067bb80769fc21b6704b31433404d33cc` (L-01, `deploy:ratchet-mainnet`, run-19, low/open) — head of the resume-footgun chain.

**Systemic observation (preserved)**: THREE consecutive mainnet-cutover script audits (run-19, run-20, run-22) have each produced a distinct resume-path footgun on the same `_writeProgressFile` / `_isConfigured` checkpoint idiom, copy-inherited across `DeployMainnetNudgeRatchet.s.sol`, `DeployMainnetUniboostCutover.s.sol` and `DeployMainnetPromotionReady.s.sol`. Harden the shared idiom once — this is a pattern-level recommendation, **not** a consolidation of the three ledger entries.

---

### [audit 22 · L-03] The progress file is stamped `deploymentStatus: "completed"` during the local pass, making the patch script's own gate structurally inert

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `ea648ec5eab0c92624bed78b303577423967385a48df8738b68153c50cba9324`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L402-L404` — `run` / `_writeProgressFileWithStatus`
**Consumer**: `lib/phoenix-phase-2-staging/scripts/patch-mainnet-addresses-promotion-ready.js#L122-L124` (header at `:16-22`)
**Root cause class**: `StatusFlagWrittenBeforeTheEventItClaimsToAttest`

**Description**: `_writeProgressFileWithStatus("completed")` is called at the end of `run()` — the end of forge's LOCAL pass, before any transaction is broadcast. `_trackDeployment`/`_trackConfig` write `"in_progress"` during the same pass, so `"in_progress"` is only ever observable after a LOCAL-pass revert (which also yields a non-zero forge exit). Any run that reaches the broadcast stage at all has therefore already written `"completed"` with every step marked done.

**The material addition over the ledger sibling is the consumer**: `patch-mainnet-addresses-promotion-ready.js:122-123` gates on exactly `deploymentStatus === 'completed'`, and its own header at `:16-22` describes that gate as **"necessary but not sufficient"**. It is in fact necessary **AND unconditionally true** at every point the patcher can run — i.e. **it carries zero information**.

Harm requires THREE compounded operator deviations: the broadcast crashes; the operator invokes the patcher manually OUTSIDE the `&&` chain; and the operator skips the documented mandatory hand-trim against `run-latest.json` receipts.

**Impact**: None on-chain. The blast radius is an OFF-CHAIN artefact: `mainnet-addresses.ts` patched with addresses for contracts that may never have been deployed, which then feeds the UI and downstream scripts. Fully recoverable — `backup-mainnet-addresses.js` precedes the patch in the chain and the address file is version-controlled.

**Recommendation** (verbatim, in full):

> Either (a) write `"completed"` from the JS side after `forge script` returns 0 - i.e. have `patch-mainnet-addresses-promotion-ready.js` itself accept an explicit `--confirm-broadcast` flag and stop reading `deploymentStatus` as evidence - or (b) restate the header honestly: 'deploymentStatus is written pre-broadcast and is NOT evidence that anything landed; the only interlocks are the `&&` short-circuit and the mandatory hand-trim against run-latest.json receipts.' Option (b) is a one-line documentation fix and is sufficient.
>
> CLASSIFIER ADDENDUM: whichever option is chosen, apply it to the SHARED idiom rather than this one script - `_writeProgressFileWithStatus` has six users (see MR-22-01) and the paired `patch-mainnet-addresses-*.js` gate exists on at least three of them.

**Class sibling — LINKED, NOT COLLAPSED**: ledger `1e8cc0dc58ba0ecbe43faf12ea343e3d6eb784c36d3ad2b0141668e33777871e` (L-01, entry point `dev`, run-21, `DeployMocks.s.sol` / `_writeProgressFile`, low/open). This is a **disclosed re-file on a new entry point**, not a duplicate:
- Different `entryPoint` (`promotion-ready:broadcast` vs `dev`) ⇒ different fingerprint; reconciles separately by design.
- Different contract (`DeployMainnetPromotionReady.s.sol` vs `DeployMocks.s.sol`) and different function.
- Different target: the ledger instance writes `progress.31337.json` on ANVIL; this one writes the **MAINNET** progress file a live cutover depends on.
- **Different consumer — the material addition**, as detailed above. The ledger's `dev` instance had no such consumer analysis.
- The ledger entry's own note ANTICIPATES this filing: *"PROPAGATES-TO-MAINNET as a PATTERN - this shape has already poisoned three committed mainnet progress files."* Dropping this as a duplicate would erase the confirmation that note was written to invite.

**Sequencing note (from audit 23)**: audit 23's L-03 (`5c6d2c9e3b98…`, Part B) has a *preferred* mitigation that would start reading `deploymentStatus`. If this entry's accepted fix (restate the header honestly) lands first, fix **this header's semantics before** making that verifier depend on the string.

---

### [audit 22 · L-04] Kendu is whitelisted unconditionally while its BLOCKING fee-on-transfer probe is PREVIEW-only, and a taxed token bricks batchMint for every reward token

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `e6f32c475e7a9213fd03495f3aa8ad326e8928fb91d9be5403df48a2cd57986a`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low — **materially de-risked by audit 23's green fork probe, but NOT fixed; flagged for human re-weigh, NOT auto-closed**
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L636-L644` — `_phase2_deployBatchMinter` / `_probeKenduFeeOnTransfer`
**Root cause class**: `BlockingPreflightNotOnTheBroadcastPath`

**Description**: `bm_.setNudgeTokenWhitelist(KENDU, true)` at `:640-644` is unconditional on the broadcast path. `_probeKenduFeeOnTransfer()` — which **story checklist line 1154 designates BLOCKING** — lives in `_phase8_previewSmokeTests()`, and Phase 8 runs only when `PREVIEW_MODE=true` (`run():402-408`). A `--broadcast` run therefore whitelists the token with the blocking gate never executing; enforcement rests entirely on the operator having run `promotion-ready:dry` first. If a whitelisted token is confiscatory or reverting, `batchMint` step 3.5 loops `pullPendingStream` over the whole whitelist with NO try/catch (`BatchNFTMinterMultiToken.sol:528-536`), so one bad token bricks `batchMint` for USDC and phUSD too.

**Not suppressed under the fee-on-transfer known-invalid rule**: the project itself designated this a BLOCKING gate (story line 1154), which is sponsor scope-in, and the root cause is **structural placement**, not a token quirk. Nor is it tagged F-class: the deviation is disclosed and accepted in the story itself (lines 1464, 1498, post-review correction #2), so Law 2 is satisfied and the residual is a structural-vs-procedural design choice.

**Impact**: None for Kendu, empirically: the fork probe against the REAL token at block 25659373 returned exact 1e24-in / 1e24-credited, and Kendu's ownership is renounced (`owner() == 0x0`) so its fee switches can never be moved again. The structural exposure is AVAILABILITY of the entire batch-mint reward path if a FUTURE third reward token is whitelisted on a broadcast run with no tax check. Remedy is immediate — `setNudgeTokenWhitelist(token, false)` is owner-only and takes effect at once. This is availability-with-a-lever, not loss.

**Recommendation** (verbatim, in full):

> Make the gate structural rather than procedural: perform the round-trip probe INSIDE Phase 2, immediately before `setNudgeTokenWhitelist(KENDU, true)`, in BOTH modes. It needs no cheatcode when broadcasting - the owner can fund the probe from its own Kendu balance with a small amount, or the check can be reduced to a broadcast-safe static assertion (`buyTotalFees() == 0 && sellTotalFees() == 0 && owner() == address(0)`) that the script `require`s unconditionally. If the probe must stay preview-only, gate the whitelist call on a `KENDU_PREFLIGHT_PASSED=true` env var that only the dry run instructs the operator to set.

**Flag L-04-23-01 (from audit 23, carried)**: the Kendu fee-on-transfer probe ran **green** on the live fork at block 25670926 — `sent == received == credited == 1e24`, i.e. Kendu is not taxed today. That removes the realized-harm case but **not** the finding: the probe is still PREVIEW-only, so the broadcast path continues to whitelist Kendu without running it. Re-weighing belongs at `/ledger`, not to a scan.

#### Ledger relationship 1 — PARTIAL DISCHARGE of a blocking pre-broadcast action

Ledger `acabc052baaa956e35d5f668f303ce40f244c0778b8154f71ff318ad46c74709` (**L-09**, entry point `dev`, run-21, low/open) carries a **BLOCKING PRE-BROADCAST ACTION**: *"tick story 072 Preflight line 514 against the REAL Kendu token 0xaa95f26e30001251fb905d264aa7b00ee9df6c18, NOT MockKendu. Story 073's `_seedNudgeStream` probe does NOT discharge it."*

**This finding is the venue that PARTIALLY DISCHARGES that action.** The run-22 fork probe exercised the **REAL Kendu token `0xaa95…`** — not `MockKendu` — at block 25659373 and returned an exact result: **1e24 sent / 1e24 received / 1e24 credited**, with `owner() == 0x0` (ownership renounced, so the fee switches can never be moved again). That is the substantive proof L-09 said was missing.

**Residual**: the probe ran in PREVIEW only. L-09's *evidentiary* gap is now closed for Kendu specifically; the *structural* gap remains open for any FUTURE third reward token whitelisted on a broadcast run with no tax check at all.

**Action for the human**: re-weigh L-09 (`acabc052`) in light of the real-token fork probes. **Do NOT auto-close**: L-09's `reopenTrigger` and its wider story-safety framing are untouched.

**Citation correction**: L-09's note cites "story 072 Preflight line 514". At the current story revision that line number is **STALE** — line 514 is a row of the live-hook-state table. The BLOCKING Kendu preflight is checklist **line 1154**, verbatim: *"- [x] **BLOCKING** — confirm Kendu is not fee-on-transfer by round-tripping a non-zero amount through `collectNudge` and asserting the credited buffer delta equals the amount sent. If it is taxed, drop Kendu from the whitelist and leave its `mainnet-addresses.ts` key at zero."* That item is now TICKED, with PASS evidence at story lines 1392 and 1436. Ledger entry `acabc052` was **not modified** by run-22, run-23 or run-24.

#### Ledger relationship 2 — impact-chain dependency on a `fix-pending` entry

Ledger `a753907e2a4c6261389ea642ede743e198b50741d4bcb43fa8bad900729174d1` (**M-01**, entry point `dev`, medium, **status `fix-pending`**). This finding's amplifier — *"one confiscatory or reverting reward token bricks batchMint for USDC and phUSD too"* — **IS** that entry (NudgeStreamer pooled-custody + `BatchNFTMinterMultiToken.batchMint` looping `pullPendingStream` with no try/catch). Being `fix-pending`, it is **never suppressed** and still live.

- **`fix-pending` is NOT treated as a mitigation for severity purposes** — a fix that is owed is not a fix that exists. This entry's Low rests on the empirical Kendu evidence and the immediate owner lever.
- **Triage note**: if that fix lands, this finding's blast radius shrinks from "all reward tokens" to "the tainted token only", which would justify **re-weighing it downward** (from Low toward QA, not from Medium toward Low). Check any landed fix against the INCOMPLETE FIX rule. **This is flagged for human re-weigh; nothing is auto-closed.**
- This entry does **not** depend on `a753907e` for validity — the unconditional whitelist write is real either way. Ledger entry `a753907e` was **not modified** by run-24.

---

### [audit 22 · L-05] Phase 4d's post-pause residue sweep can never fire, so its stated rationale and the story's "rescueERC20 still works while paused" assertion are both unproven

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `3c957109ef53404376145e81a57d23db18474cc1ba0174dc7fc0f4f60e33190d`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low — **also a Law-2 faithfulness item, routed as F-02**
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1137-L1148` — `_phase4d_retireOldBatchMinter`
**Root cause class**: `ConditionalBranchDecidedAtLocalExecTimeNotBroadcastTime`

**Description**: Autonomous Decision 2 reasons: *"Donors keep pushing USDC at the old sink for the whole interval between Phase 3's rescue and their own repoint… On the dry run the residue was 0 (Phase 3 ran seconds earlier); on a real multi-hour Ledger session it will not be."* That reasoning does not survive forge's execution model. `uint256 residue = IERC20(USDC).balanceOf(OLD_BATCH_MINTER)` at `:1140` is evaluated in the LOCAL pass, seconds after Phase 3's LOCAL rescue — so `residue` is 0 there too. The `if (residue > 0)` branch is therefore never taken and **no rescue transaction is ever queued into the broadcast plan**. Whatever USDC actually accumulates on the old minter during the multi-hour broadcast is not swept. The trailing `require(balanceOf(OLD_BATCH_MINTER) == 0)` at `:1148` likewise evaluates only locally and passes vacuously. Fork-confirmed: the run logged "no residue to sweep".

**Faithfulness deviation (F-02)** — story line 1166, ticked: *"- [x] Phase 4d (after every donor is repointed): retire the old batch-minter — `setPauser(OWNER)` then `pause()`. **Do not register it with the global `Pauser`.** Assert `paused() == true` and that `rescueERC20` still works while paused."* Only the first two obligations are met. `paused() == true` IS asserted at `:1134`. *"that `rescueERC20` still works while paused"* is **not asserted anywhere**: the else branch at `:1146` merely LOGS the claim as prose, and the `if (residue > 0)` branch that would have exercised it is structurally unreachable in the local pass. A ticked acceptance criterion claims an assertion the code only prints as a sentence. **Second deviation**: Autonomous Decision 2 asserts a leak is structurally closed when it is not — a documented design decision contradicted by the code it describes, independent of the checklist tick.

**Impact**: A small, bounded amount of USDC — donations landing on the old sink between Phase 3's rescue and each donor's repoint — is left on a paused, retired contract instead of entering the stream. It is **NOT lost**: `rescueERC20` is `onlyOwner` and is not pause-gated, so the funds are recoverable at any later time. Stranded-value-pending-a-manual-step. **Explicitly NOT framed as an economic value leak.**

#### Recommendation (in full)

> ⚠ **The auditor's original limb (1) is SELF-NEGATING and is NOT presented as the fix.** As written it proposes an unconditional full-balance rescue and withdraws it in the same sentence (*"if the legacy minter supports it, or - since it does not -"*), leaving "add an explicit post-broadcast operator step to the runbook" with no stated content. A finding whose primary fix retracts itself is incomplete. The **`CLASSIFIER ADDENDUM` below is the recommendation of record.** It was not invented over the auditor's text — that text is preserved in the finding record — but the **owner must choose between the two options it supplies.**

**CLASSIFIER ADDENDUM** (verbatim — the recommendation of record):

> CLASSIFIER ADDENDUM (limb (1) is self-negating as written and needs a decision, see recommendationQuality): the concrete form of the fallback is - add to the runbook, as a numbered post-broadcast step alongside story checklist line 1195, 'read `IERC20(USDC).balanceOf(OLD_BATCH_MINTER)`; if non-zero, call `rescueERC20(USDC, OWNER, bal)` then `forceApprove` + `collectNudge(newBM, USDC, bal)` so it enters the stream rather than the pot' - i.e. mirror Phase 3's own sequence by hand. Alternatively, if the legacy minter's `rescueERC20` accepts an explicit amount, queue a SECOND rescue unconditionally with a `try`-wrapped call so a zero-balance case is a no-op rather than a revert. Either way, Autonomous Decision 2's 'structurally closed' claim must be retracted - that part is not optional.

**NON-NEGOTIABLE, independent of the owner's choice**: **Autonomous Decision 2's claim that the leak is STRUCTURALLY CLOSED must be RETRACTED — regardless of which fix the owner chooses.** That part is not optional and is not contingent on the choice between the two remediation options above.

**Primary fix (strong and concrete as originally written — limb (2))**: prove the pause-transparency property in Phase 8 instead — `deal` 1 USDC onto the paused old minter and assert `rescueERC20` succeeds, which is a real test rather than a comment. The runbook step above is the **compensating control**, not the primary fix.

**Not merged with L-08**, though both surface as comment drift: comment drift is the shared **symptom**, not the shared cause. This one is a conditional evaluated in the local pass so no rescue tx is ever queued (functional); L-08 is two dispatcher indices never exercised (coverage). A merged "fix the drifted comments" finding would leave both underlying defects live while reading as resolved.

---

### [audit 22 · L-06] The snapshot scanner's `DEFAULT_FROM_BLOCK = 25000000` is an undocumented correctness horizon for the `migrate()` user list

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `78c91a8727eb99aa4ba339497a890988c8a9cb3407214d7af4402a499b80404f`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low
**Location**: `lib/phoenix-phase-2-staging/scripts/snapshot-depletion-stakers.js#L89` — `main`
**Root cause class**: `UndocumentedScanHorizonOnASafetyCriticalEnumeration`

**Description**: `const DEFAULT_FROM_BLOCK = 25000000n` bounds the `Staked`/`Unstaked`/`DepositedFor` log scan that produces Phase 6's `migrate()` user list. Any position opened before block 25,000,000 yields a SHORT list unless `FROM_BLOCK` is overridden. Neither the story, the script NatSpec, nor the (absent) npm annotation records that this constant is load-bearing for migration completeness. The TOTAL-miss case is guarded — `die(4, ...)` fires when `totalStaked > 0` but zero holders were found (`:242-243`). **The PARTIAL-miss case is not**: `sumStaked != totalStaked` emits a non-fatal WARNING to stdout only (`:245-248`), so a partial under-enumeration still emits a snapshot that the Foundry script then trusts.

Retained rather than dropped as speculation: the C4 "speculation on future code without demonstrated root cause" carve-out does not apply — the root cause is present in committed code, and empirical cleanliness today is **confidence, not absence of root cause**.

**Impact**: Latent, none realised. Under-enumeration would strand a user's staked position on V1 — the same end state as L-01, reached by an orthogonal route. Recoverable by owner action (`migrate` is re-runnable by design). Likelihood is nil today, **verified rather than assumed**: the run at the pin block reconciled EXACTLY on all three stakers (1 user / sum 2 == totalStaked 2; 2 users / 146 == 146; 3 users / 13 == 13).

**Recommendation** (verbatim, in full):

> Promote the `sumStaked !== totalStaked` warning at `:245-248` to a hard `die(4, ...)`: a list that does not reconcile against `totalStaked` is exactly the subset case the header says to avoid, and `migrate` being re-runnable makes a false abort cheap while a silent subset is expensive. Additionally, document `DEFAULT_FROM_BLOCK` as 'must precede the earliest of the three stakers' deployment blocks' and record those three block numbers in the comment so the constant can be audited rather than trusted.

**Report emphasis (preserved)**: this ask — promote the `sumStaked !== totalStaked` warning to a hard `die(4)` — is **the single cheapest structural improvement in the whole candidate set**. It converts the silent-subset case into a refusal, and `migrate` being re-runnable makes a false abort nearly free. Worth surfacing despite the Low severity.

**Not merged with L-01**, despite an identical end impact: these are orthogonal bounds on the same enumeration — this one is the scan's **lower block bound**, L-01 is the **wall-clock upper bound**. Different contracts, different fixes, and each leaves the other's window fully open.

---

### [audit 22 · L-07] The snapshot file is a documented hard prerequisite with no Phase 0 probe; it fails at line 1390 of 2171 with a generic filesystem error

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `b28492ce9719af2d7117f52fa3cc04138c7f1764ca6e1848da9ebf6de0d19685`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low — **scope-narrowed vs audit 23's L-05 (SN-23-01)**
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1440-L1443` — `_phase0_preconditions` / `_loadSnapshotUsers`
**Root cause class**: `MissingPrerequisiteProbeInThePreconditionPhase`

**Description**: `scripts/snapshots/depletion-stakers-latest.json` is a hard prerequisite named by the `//promotion-ready`, `//promotion-ready:dry` and `//promotion-ready:resume` annotations and by the script NatSpec at `:129-131`, and it is deliberately gitignored (Autonomous Decision 8). **Phase 0 — the designated `require`-gated precondition phase, which checks 17 owners, 5 dispatcher slots, 5 prime tokens, 6 donor sinks and 5 hooks — never probes for it.** The first read is an untry'd `vm.readFile(SNAPSHOT_FILE)` at `:1441`, reached from `:1390` inside Phase 6, after roughly 50 transactions have already been built. The failure surfaces as Foundry's generic fs error, not as "run promotion-ready:snapshot first". Separately, `promotion-ready:snapshot` is the only one of the five npm keys with no `//` annotation.

**The finding is the absent Phase 0 probe and the generic error at line 1390/2171 — it is not a fund risk.**

**Impact**: **None.** The failure is **fail-closed and atomic**: because the whole body executes locally before any dispatch (true even under `--skip-simulation`), a missing snapshot aborts the run **before a single transaction is broadcast**, so nothing is half-applied on mainnet. Nothing is applied and nothing is recoverable-from, because there is nothing to recover. The cost is operator time and an unactionable error message mid-session with a Ledger connected. Likelihood is moderate as an operator event (a gitignored prerequisite is exactly the file a fresh checkout or a second operator machine lacks); **nil as a funds event**.

**Recommendation** (verbatim, in full):

> Add to Phase 0: `try vm.readFile(SNAPSHOT_FILE) returns (string memory j) { require(bytes(j).length > 0, "snapshot file empty - run: npm run promotion-ready:snapshot"); } catch { revert("snapshot missing - run: npm run promotion-ready:snapshot"); }`, and while there, parse `.blockNumber` and assert freshness (which also addresses PR-11). Add a `//promotion-ready:snapshot` annotation to package.json documenting the prerequisite relationship, the `FROM_BLOCK` horizon and exit code 4.

**Not merged with L-03**, and the reason is an **inversion that must not be collapsed**: for this entry the local-pass execution model is the **MITIGATION** — it is precisely why a missing snapshot fails closed and atomically; for L-03 the same model is the **DEFECT**. Root causes are a missing Phase 0 prerequisite probe vs a status flag written before the event it attests. No shared code, no shared fix.

**Secondary observation (preserved inside this finding, not split out)**: `promotion-ready:snapshot` is the only one of the five npm keys with no `//` annotation — the same documentation gap on the same prerequisite relationship.

> **SN-23-01 — scope boundary and REOPEN TRIGGER, carried verbatim.** Audit 23's L-05
> (`f59e177a97c8842940bc0ccf4b3e28be506074e9e85fb7fed3a52aec87866bf2`, Part B) is deliberately
> **not merged** with this entry. File-**existence** probing and `.blockNumber` **freshness** remain
> **this entry's**; the address-set/provenance dimension is L-05's. **If this entry is closed
> without its *full* recommendation landing, the ceded dimensions must be re-filed** — closing it
> on a partial fix would silently drop both dimensions from every future scan. Both fixes belong
> in the same Phase 0 block so the operator implements one probe, not two.

---

### [audit 22 · L-08] Indices 2 and 3 are never functionally exercised, so `setMinter` on two of the three new Uniboosts has no verification of any kind — and Autonomous Decision 5 claims otherwise

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `d5d55f34c5d6ffa3f24c7833b43d707dbba4e1336eb558db9f7a3bde54946576`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low — **also a Law-2 faithfulness item, routed as F-03**
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1665-L1707` — `_probeDonorPaths` / `_assertSlot` (claim repeated in code at `:1575-1580`)
**Root cause class**: `CoverageGapMaskedByAnOverstatedVerificationClaim`

**Description**: Autonomous Decision 5 removes the `dispatcher.minter()` read-back from Phase 7 on correct grounds (`ATokenDispatcherV2._minter` is `internal` with no accessor). It substitutes the claim: *"Phase 8's mints verify it MORE strongly than a read-back would… a dispatcher whose minter was not set reverts on the first mint through its index, which all three donor-path probes exercise."*

**The concrete fact**: Phase 8 exercised **idx1, idx7 and idx4** — `_mintOnce(IDX_EYE)`, the inline pooler mint at `IDX_POOLER`, and `_mintOnce(IDX_RATCHET)`. It **never minted through idx2 or idx3**. Indices 2 (Uniboost SCX) and 3 (Uniboost FLX) are never exercised, so `newUniboostSCX.setMinter()` and `newUniboostFLX.setMinter()` have **neither a read-back (structurally impossible) nor a functional probe (absent)** — `setMinter` on two of the three Uniboosts is unverified. **Autonomous Decision 5 claims otherwise.** Fork evidence is explicit: idx2 and idx3 "NEVER EXERCISED".

**Faithfulness deviation (F-03)** — story line 1174, ticked: *"- [x] Phase 8 (PREVIEW only): mock `batchMint`s; a donation on each of the four donor paths with the pooler asserted **positively** via `BatchDonatedViaPSM` + a balance increase; …"* — "a donation on each of the four donor paths" is ticked; **three** run. The tick is unearned on its own terms, independently of how many paths "four" was meant to enumerate. Second-order note (preserved): *this drift survived the review that caught two others, on a story whose own checklist line 1161 demands "every comment traceable to pinned source"*.

**Impact**: None. If the unverified `setMinter` were ever wrong, the symptom would be post-cutover mints on indices 2/3 reverting `"ATokenDispatcherV2: caller is not minter"` — an availability symptom, discovered by a user rather than by the runbook, and fixable by an owner call. Likelihood is very low: all three Uniboosts are configured by the same `_swapUniboost` body in one `ub_<label>_config` block, so a `setMinter` omission on SCX/FLX but not EYE is not a realistic failure mode.

**Recommendation** (verbatim, in full):

> Add `_mintOnce(actor, IDX_SCX, USDC, "Uniboost SCX (idx 2)")` and `_mintOnce(actor, IDX_FLX, USDC, "Uniboost FLX (idx 3)")` to `_probeDonorPaths` - two lines, using the helper that already exists, closing the gap and making Autonomous Decision 5's argument true as written. Simultaneously correct the code comment at `:1575-1580` and the Autonomous Decision text to say 'all five donor-path probes' once they exist, or to name the covered indices explicitly if they are not added.

**Kept separate from L-05** despite the shared comment-drift symptom — see L-05 for the rejected-merge rationale.

---

## QA / Hardening Notes (audit 22)

### [audit 22 · Q-01] The knowingly-accepted mint-UI breakage has no tracked remediation story, so the cutover ships an indefinite outage

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `909e6d267d4c99d5dc44600c4a96700b6f3334005840ac3b24ca50530817398e`
**Entry point**: `promotion-ready:broadcast`
**Severity**: QA (auditor proposed Low; downgraded — a precision correction, **not** a suppression)
**Location**: `lib/phoenix-phase-2-staging/package.json#L282` — the `//promotion-ready` annotation
**Root cause class**: `AcceptedBreakageWithoutABoundedRemediation`

**Description**: Whitelisting three reward tokens makes `batchMint`'s `minRewards` array length-3, and `getNudgeTokens()` reorders on removal (swap-and-pop), so callers must re-fetch immediately before every call. The `//promotion-ready` annotation and the script both record that *"the live mint UI is BROKEN until a phlimbo-ui story ships a 3-element array plus a getNudgeTokens() re-fetch"*. Story line 1447 states: *"The `phlimbo-ui` follow-up story … is **still unraised**. The live mint UI breaks the moment this broadcasts. Tracked as a comment at `story-dependencies.md:218`."* A comment in a dependencies file is not a raised story, so the outage is **unbounded in duration rather than sequenced**.

**Law-3 split**: the outage itself is a knowing, documented, priced owner decision with an OBVIOUS consequence — the owner would not be surprised — so the **decision** is trusted and out of scope. Only the **tracking** is reportable: a same-day-or-never outage recorded solely inside a `package.json` comment and a comment at `story-dependencies.md:218` can silently persist. Explicitly **NOT** closed under the "reckless admin mistakes" known-invalid rule — nobody is acting recklessly and nothing is being second-guessed. The sanitizer's candour note (a reasonable triager could legitimately close this on Law 3) is preserved so the human decides deliberately rather than inheriting the decision from a filter.

**Impact**: None on-chain. Contracts are correct; direct and multicall callers are unaffected. User-facing mint availability via the UI is lost from the moment of broadcast until an unscheduled follow-up ships. The breakage is certain and deterministic on broadcast — and intended.

**Recommendation** (verbatim, in full):

> Raise the phlimbo-ui story before the Ledger session and sequence it as a same-day follow-up, so the outage window is a known number of hours rather than open-ended. If the cutover must go first, state the expected remediation date in the completion summary. Related: the two-coexisting-batch-minter-ABIs trap (legacy 3-arg on the four per-token minters, 4-arg multi-token on the shared one) belongs in that story's scope explicitly, since a UI that re-fetches `getNudgeTokens()` against a legacy minter will revert - that view does not exist there.
>
> CLASSIFIER ADDENDUM: cite ledger Q-04 (a807cc7a) in that story's scope so the script-side legacy scalar-`minReward` call sites and the UI-side 3-element-array surface are covered by one follow-up rather than two.

**Class sibling — COMPLEMENTARY HALVES OF ONE STORY-072 ABI BREAK, NOT DUPLICATES**: ledger `a807cc7a66991388e22dfa8a50ec1bddeb4f491ad5efdd82bc861028f81a9321` (**Q-04**, entry point `dev`, run-21, qa/open, rootCause `IncompletePreflightCallSiteSweep`). Q-04 covers the **script side** — call sites that still bind the legacy scalar-`minReward` signature and *"silently break on the story-072 cutover"*. This entry covers the **UI side** — the 3-element array plus the `getNudgeTokens()` re-fetch. Q-04's ledger note already states it is *"OWNER-VISIBLE and explicitly NOT bundled away (Law 2)"*. **Action**: this recommendation (scope the two-coexisting-ABI trap into the phlimbo-ui story) should cite Q-04 so the follow-up story covers both surfaces at once. Ledger entry `a807cc7a` was **not modified** by run-24.

**Not merged with L-04**, though both end in `batchMint` availability: an unverified token entering the whitelist (contract-input risk) vs a client that cannot construct the resulting 3-element `minRewards` array (compatibility schedule). Shared endpoint, unrelated causes.

---

### [audit 22 · Q-02] The Phase 6 budget top-up approval lacks the before/after allowance assertions that guard every other approval in the script

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `b3caa280e070dbb4aa16956cce8598a7025e7ad76346d412cf65eb8efca943ff`
**Entry point**: `promotion-ready:broadcast`
**Severity**: QA (auditor proposed Low; downgraded because the finding's own impact analysis establishes there is no live bug)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1409-L1410` — `_migrateStaker`
**Root cause class**: `InconsistentApprovalHygiene`

**Description**: `IERC20(PHUSD).approve(v2, movable); NFTStakerDepletionV2(v2).topUp(movable);` at `:1409-1410` has no pre-check that the existing allowance is zero and no post-check that it returned to zero. The script's own USDC donation helper `_collectNudgeFromOwner` does both and states why: *"The allowance is fully consumed inside `collectNudge`, so it always returns to 0 - asserted here so a stale approval can never silently accumulate"* (`:742-744`, `:753`). Three separate `approve` calls run across the three stakers with no such guard. For value to move, `topUp` would have to under-pull AND the spender would have to later draw the residue — but `topUp` is `onlyOwner` on a contract deployed moments earlier in the same script, and the fork run showed exact consumption (swept 4.6326 / 708.8243 / 51.9974 phUSD with V2 balances matching).

**Not suppressed under the tool-noise / style carve-out** — that basis was considered and **REJECTED**. The defect is an asymmetry against a convention the same file establishes and documents 660 lines earlier, which no automated tool can surface. Downgrading the tier is not the same as accepting the carve-out.

**Impact**: None demonstrated. The theoretical residual is a leftover phUSD allowance from the OWNER EOA to a V2 staker — **BOUNDED at `movable`, not infinite** — if `topUp` ever pulled less than approved. Likelihood is nil on current code: there is no state in which value moves.

**Recommendation** (verbatim, in full):

> Mirror the USDC helper exactly: `require(IERC20(PHUSD).allowance(OWNER, v2) == 0, "stale V2 topUp allowance");` before, `forceApprove` (or `approve`) in the middle, and `require(IERC20(PHUSD).allowance(OWNER, v2) == 0, "topUp left allowance behind");` after. Three lines per staker, and it makes the script's approval hygiene uniform - which is the actual value, since a reader currently cannot tell whether the asymmetry is deliberate.

**Not merged with Q-03**, though both concern approval hygiene: missing zero-allowance bookends on a **bounded** approval (Phase 6, phUSD) vs an **unbounded** approval whose magnitude is hardcoded instead of mirrored (Phase 5, SYA/phlimbo). Different phases, tokens, defects and fixes.

---

### [audit 22 · Q-03] The new StableYieldAccumulator is given an unbounded phlimbo approval that is hardcoded rather than mirrored from the retiring instance

**Originating run**: `phoenix-phase-2-staging-22` (`5ae94bd`)
**Fingerprint**: `050428e852c4e27de20a44cbec65bb1b764b15af73bb5fa987e5b2acb871a8bf`
**Entry point**: `promotion-ready:broadcast`
**Severity**: QA
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1187` — `_phase5_stableYieldAccumulator`
**Root cause class**: `UnboundedApprovalNotSourcedFromTheMirroredInstance`

**Description**: Phase 5 mirrors the retiring accumulator's configuration field by field — `rewardToken`, `phlimbo`, `nftMinter`, `discountRate`, three `tokenConfigs`, three strategies, `nudgeSplit` — each read live off `OLD_SYA`. **One value is not mirrored**: `sya.approvePhlimbo(type(uint256).max)` is a hardcoded infinite approval. The inline comment justifies the mechanism ("collectReward pulls via transferFrom") but not the magnitude. The project's own `CLAUDE.md` Configuration Safety section names caps and unbounded allowances as parameters requiring explicit justification rather than a default.

Retained rather than dropped: it is anchored to a **written in-repo standard**, not auditor preference; the fix is one sentence; and Phase 5 mirrors **eleven** values off the live retiring instance while hardcoding exactly this one. Under Law 1, keep — dropping it would remove the only record that the discipline break was noticed. **Cached known-issue #10 ("Admin trust assumptions…") was considered and rejected as authority**: it has no suppression standing in this project (the declared known-issues file does not exist) and would fail on the merits anyway, since a discipline break against the repo's own written standard is not an admin-trust concession.

**Impact**: None. PhlimboV2 is a first-party contract and an infinite approval to it is the conventional pattern for a pull-based reward collector. Likelihood nil — no impact path exists on current code. A future repoint of the phlimbo dependency would be required for the unbounded magnitude to matter.

**Recommendation** (verbatim, in full):

> Either read the retiring instance's existing phlimbo allowance and mirror it, or keep `type(uint256).max` and extend the comment to record why unbounded is correct here (PhlimboV2 is first-party, the approval is scoped to one spender, and `collectReward` is the only consumer) so the choice reads as deliberate rather than defaulted.

---
---

# PART B — Carried from **audit 23** (`c4396b1`)

*6 entries: 5 Low, 1 QA. Section text is reproduced verbatim from `reports/phoenix-phase-2-staging-23/submissions/qa-report.md`; labels are the originals and are **independent of Part A's**.*

## Low Risk Findings (audit 23)

### [audit 23 · L-01] Phase 8's `_probePoolerDonation` — the mechanised form of story-072 checklist line 1197 — is reachable only under `if (isPreview)`, so the broadcast path never runs it

**Originating run**: `phoenix-phase-2-staging-23` (`c4396b1`)
**Fingerprint**: `2212c1c4e8c8cd2271cc3c0c5c7e9180d0e2597cfbbdd97631431724e899525d`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low · **Faithfulness deviation** (story-072, checklist line 1197, routed as **F-01-072**) · plausible · not a regression
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L439` — `_phase8_previewSmokeTests`, reached from `run()` at `:439` via `if (isPreview)`

**Description**

`BalancerPoolerV2._psmDonate` failures are swallowed by `try/catch`, so a green index-4 mint transaction is **not** evidence that the donation leg works — the exact failure mode story-072 checklist line 1197 exists to catch. That line is a **post-broadcast HUMAN step**, is **UNTICKED**, and story-075's `:verify` explicitly declines to discharge it (`VerifyPromotionReady.s.sol:85-86` prints *"STILL A HUMAN STEP … line 1197"*). Nothing in the npm chain enforces that the human step ever happens.

Meanwhile Phase 8's `_probePoolerDonation` performs **exactly this assertion** and **PASSED** in audit 23's `:dry` run (`BatchDonatedViaPSM = true`, `DonationSkipped = false`, USDC stream-buffer delta `2485691`) — but Phase 8 is gated `if (isPreview)`, so it never runs on the broadcast path. The same preview-only gating is the only thing that exercises `BALANCER_ROUTER` and `SUSDS_IS_FIRST`, which are `private immutable` with no getter and therefore unassertable by Phase 0 or by `:verify`.

**Impact**

None directly. If `_psmDonate` were to fail after the cutover, the `try/catch` swallows it and the index-4 mint still succeeds; the consequence is a donation that should have reached the batch minter's nudge pot being skipped. Per this project's standing position, those pots are funded by **externally-derived yield on protocol-owned capital**, so an under-delivered donation is an allocation/marketing miss, **not** an economic loss and **not** a value leak. The real impact is on **detection**: the wiring assertions cannot see it, because the wiring is in fact *correct*, so a fully green `:verify` run coexists with a silently non-donating pooler.

Likelihood is low — the donation leg was empirically exercised **green** on the live fork at commit `c4396b1`, so the pooler was not broken then. The residual is that no automated gate would notice if it broke.

**Evidence**: audit 23 `side-effects.json → events[0]`, `externalCalls[4]`, `leadsResolution[6]`; `scratchpad/dry.log:282`; source `run() :439`; `VerifyPromotionReady.s.sol:85-86`.

**Recommended Mitigation** (in full)

Add a `promotion-ready:verify-mint` npm key that runs the existing Phase 8 pooler probe in `PREVIEW_MODE` against **live post-cutover state**: prank `OWNER`, trigger one index-4 mint, and `require` that `BatchDonatedViaPSM` fired and `DonationSkipped` did not. It needs no broadcast and no signing, so it chains after `:verify` with the same `&&` discipline, converting line 1197 from an unenforced human step into a **fail-closed gate**. Until that ships, tick line 1197 explicitly before disconnecting the Ledger.

Secondary: expose `BALANCER_ROUTER` and `SUSDS_IS_FIRST` via public getters so Phase 0 and `:verify` can assert them at all.

**Cross-references**

- **Faithfulness**: graded in `reports/phoenix-phase-2-staging-23/submissions/spec-conformance.md` as **F-01-072**; not duplicated here.
- **Class sibling — NOT merged**: audit 22 **L-04** (`e6f32c475e7a9213fd03495f3aa8ad326e8928fb91d9be5403df48a2cd57986a`, Part A). Same `BlockingProbeGatedToPreviewOnly` family, but L-04's probe is a **preflight that must move EARLIER** on the broadcast path (ahead of the Kendu whitelist write); this one is a **post-mint verification that must move LATER**, into a post-broadcast read-only leg. Neither fix delivers the other.

---

### [audit 23 · L-02] Phase 0's expected-value literal is hardcoded into a control the runbook presents as a manual human check, and is both stale and structurally incomplete

**Originating run**: `phoenix-phase-2-staging-23` (`c4396b1`)
**Fingerprint**: `d99738d3a05c44aa0171efb976164815c8dec5c8d75ab5762d0cfd894b364c29`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low · **Faithfulness deviation** (story-072, checklist line 1195, routed as **F-02-072**) · **Law-3 footgun (in scope)** · plausible
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L544-L558` — `_phase0_preconditions`

**Description**

story-072 checklist line 1195 — one of only two unticked items and, alongside line 1197, the entire compensating human control — instructs the operator to confirm *"the new pooler holds the full 16,338.8190 BPT"* and *"the rescued ~349 USDC sits in the streamer buffer"*. **Both figures are stale.**

Audit 23's live `:dry` run measured **16,867.5264 BPT** (`16867526417628291567945` wei) and a final stream buffer of **530.761796 USDC**, decomposing as `99.224124` (old batch minter) + `51.537672` (UniboostSCX residual prime) + `380.000000` (DelayRelease) — a **third component the checklist never names at all**.

The **code is unaffected**: Phase 0 derives the BPT baseline live (`side-effects.json` confirms `bptAtPhase0` equals the live figure), no assertion references the stale number, and the `16,338.819e18` literal survives only as a self-contained fixture in `test/BptBaselinePersistence.t.sol:96`. The defect is confined to the **manual control**.

**Impact**

None directly — and that is load-bearing for the grade. The degraded asset is a **compensating human control**: line 1195, one of the two unticked rows, and the row the operator is meant to use for the post-cutover state that `:verify` cannot mechanise.

Two branches follow, and the dangerous one is the second:

- **Benign (certain to occur)**: the operator treats the mismatch as a real failure and raises an alarm on a healthy cutover. Because line 1195 is a **post-broadcast** row, this causes confusion and delay — **never** a partial application.
- **Dangerous (needs a coincidence)**: the operator reconciles the mismatch as *"the checklist numbers are always a bit off"*, and the control is now calibrated to be waved through — so a **genuine** BPT shortfall or a missing buffer component on the day reads exactly like the noise they have been trained to ignore.

The BPT half is partially backstopped (`:verify` consumes story-074's persisted baseline and re-runs the Phase 7 conservation assertion). The **USDC-buffer half is not backstopped by anything** — and that is precisely the half whose decomposition is structurally incomplete.

**Evidence**: audit 23 `side-effects.json → leadsResolution[3]`, `preconditionResults` (`bptAtPhase0 = 16867526417628291567945`), `stateWrites` (`99224124 + 51537672 + 380000000 = 530761796`); `scratchpad/dry.log:117-124`, `:156`, `:184-185`, `:199`.

**Recommended Mitigation** (in full)

Stop hardcoding balances in the human checklist. Rewrite line 1195 to read: *"confirm the new pooler's BPT equals the `BPT cutover baseline` printed by Phase 0 of the immediately preceding `:dry` run, and the streamer buffer equals its final `collectNudge -> stream buffer now` figure"* — the script already prints both, under a `--- stranded value (live) ---` header built for exactly this purpose.

Additionally, have `_printSummary()` emit a copy-paste **"POST-BROADCAST HUMAN CHECKLIST"** block with the live-derived expected values filled in, so the operator compares against measurements taken **minutes** earlier rather than prose written **weeks** earlier.

When rewriting, enumerate **all three** buffer components (old batch minter / DelayRelease / UniboostSCX residual prime) or, better, quote only the **total** the script prints — a control that names two of three sources will drift again the moment a fourth donor appears.

**Cross-references**

- **Faithfulness**: **F-02-072** in audit 23's `spec-conformance.md`. The deviation is in the **story text**, not the implementation — the code is faithful; the acceptance criterion is not accurate.
- **Collapse refused (carried)**: audit 23's L-01 and L-02 share the story-072 checklist as an artefact but were confirmed distinct by the deduplicator — *enforceable-but-unenforced* (fails silent) versus *stated-but-wrong* (fails noisy, then numb), with non-overlapping fixes in both directions.

> **Note for run-24 readers**: the measured figures above are from audit 23's fork at block 25670926.
> Run-24 did not re-measure them. Do not treat them as current — re-derive from a fresh `:dry` run.

---

### [audit 23 · L-03] `VerifyPromotionReady._loadAndValidateProgressFile` trusts a progress file whose write-side entries are stamped during forge's LOCAL pass

**Originating run**: `phoenix-phase-2-staging-23` (`c4396b1`)
**Fingerprint**: `5c6d2c9e3b9806b89ca5484e3af8dab3f5ee9aa7240e93b526f0808b324d8818`
**Entry point**: **`promotion-ready:verify`**
**Severity**: Low · not a faithfulness deviation · plausible · **7th member of the `ForgeLocalPassPrecedesBroadcast` family** (MR-22-01 recall gap)
**Location**: `lib/phoenix-phase-2-staging/script/VerifyPromotionReady.s.sol#L126-L131` — `_loadAndValidateProgressFile`

**Description**

The verifier guards against *"a verifier run against a file the cutover never finished writing"* with:

```solidity
require(
    _isDeployed("NudgeStreamer") && _isDeployed("BatchNFTMinter"),
    "Progress file is missing core deployment records - the cutover did not complete. Resume it before verifying"
);
```

Those records **cannot signal dispatch completion**. `_trackDeployment` / `_trackConfig` call `_writeProgressFileWithStatus("in_progress")` on **every** step (`DeployMainnetPromotionReady.s.sol:2161`, `:2169`), and `run()` flips it to `"completed"` at `:435` — **all inside forge's single local pass, before transaction #1 is signed**. On a partial broadcast the file therefore already exists, already carries all 14 addresses, and already says `"completed"`.

The gate can only distinguish *"the local pass aborted early"* from *"the local pass succeeded"* — a **pre-broadcast** condition, not the post-broadcast one its message names. The verifier also never reads `deploymentStatus` **at all**; only `scripts/patch-mainnet-addresses-promotion-ready.js:122` does.

**Impact**

None. No assets, no availability, no on-chain state. The impact is **diagnostic quality on the contract built to be the cutover's safety net**. On a partial broadcast the gate passes, the operator proceeds past a guard that told them the cutover completed when it did not — and then `_phase7_wiringAssertions()` runs against **live chain state** and fails loudly. The incompleteness **is** detected, just with a worse and later message than the named gate implied.

This earns **Low** rather than QA for two reasons: it sits **inside the safety-net contract itself**, where a guard overstating its own coverage is worse than elsewhere (falsely-exhaustive self-certification raises severity rather than sanitizing it); and it is the **seventh** consumer of the `ForgeLocalPassPrecedesBroadcast` idiom flagged in run-22's **MR-22-01** recall gap — a gap the project's own `package.json:289` documents in its own words as *"after a crash IT LIES"*. A defect the project has written down and then re-instantiated inside its own safety net is a systemic signal, not a nit. It does **not** reach Medium: nothing is lost, nothing becomes unavailable, and the incomplete cutover is still caught.

**Not an `incompleteFixOf` the carried Medium** (`2c53e944caee…`), and not graded as one: that finding's actual detection mechanism — `_phase7_wiringAssertions()` against live chain state — works and fires.

**Evidence**: audit 23 `side-effects.json → fixVerification.run22_M01.residuals`; source `DeployMainnetPromotionReady.s.sol:2161`, `:2169`, `:435`; `VerifyPromotionReady.s.sol:126-131`; `patch-mainnet-addresses-promotion-ready.js:122`.

**Recommended Mitigation** (in full)

Make the gate read something only **dispatch** can produce.

- **Preferred**: have the verifier require `deploymentStatus == "completed"` **and** independently confirm on-chain code at the recorded `NudgeStreamer` and `BatchNFTMinter` addresses (`addr.code.length > 0`). That costs two staticcalls and turns the guard honest, because **bytecode at a recorded address cannot exist unless a transaction actually landed**.
- **Alternative**: drop the misleading `require` entirely and let Phase 7 be the sole authority, with a comment explaining why a pre-dispatch record check is impossible.
- **Do NOT** leave the current wording in place with a comment — **the message is what misleads**.

**Cross-references**

- **Class sibling — NOT a duplicate**: audit 22 **L-03** (`ea648ec5eab0c92624bed78b303577423967385a48df8738b68153c50cba9324`, Part A). That entry's gate reads the `deploymentStatus` **string** from JS with an off-chain blast radius; **this** finding establishes that the verifier never reads `deploymentStatus` **at all** and gates on record **presence** instead. The two gates share no input and neither accepted fix touches the other.
  **Sequencing warning for the fix author**: the *preferred* mitigation above **would** start reading `deploymentStatus`. If audit 22 L-03's accepted fix (restate the header honestly) lands first, fix **that header's semantics before** making this verifier depend on that string.
- **Recall gap (carried verbatim)**: MR-22-01 counted **six** users of the `_writeProgressFileWithStatus` local-pass idiom across the mainnet cutover scripts. **This is the seventh, and the first inside a contract introduced specifically to close a verification gap.** Recorded so the gap is not narrowed by omission — **it widened.**

---

### [audit 23 · L-04] The persisted `baselines.bptAtCutover` carries no provenance binding, so a hand-edited digit is accepted as the write-once baseline

**Originating run**: `phoenix-phase-2-staging-23` (`c4396b1`)
**Fingerprint**: `80a741a27fe0fded541073aa2e3c4e8d37a6dbeff5920e0ff64b0e71273aac1a`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low · **Law-3 footgun (in scope)** · plausibility: *implausible-but-cheap-to-close* · **residual introduced by the fix for audit 22 L-02** (`4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42`)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L2013-L2020` — `_parseBaselines` (related: `:549`, `:564`, `:571`; `VerifyPromotionReady.s.sol:147-154`)

**Description**

Story 074's rails check that `baselines.bptAtCutover` is **present** (`:564`) and **non-zero** (`:571`, and again in the verifier at `:151`). They never check that it is the **right value**. There is no `chainId`, block-number, or run binding on the `baselines` object, and no checksum. `_parseBaselines` accepts any non-zero decimal string.

On a **resume** leg the live read of the emptied old pooler is `0`, so `bptAtPhase0 = max(persisted, 0) = persisted` — the monotonic floor cannot rescue the value; **the corrupted number *is* the floor**. A baseline hand-edited downward to any smaller non-zero value is adopted verbatim, and Phase 7's conservation assertion `balanceOf(newPooler) >= bptAtPhase0` (`:1725`) then passes against a lowered bar.

The `//promotion-ready:resume` doc key's rule (*"TRIM THE contracts BLOCK ONLY, NEVER the top-level baselines block"*) is enforced **for deletion** by two independent aborts, but is **documentation-only for the value**. Note that a resume leg is exactly where the runbook **mandates** hand-editing the progress file — the operator's hand is already in the file by design.

**Impact**

Indirect and **detection-only**. The BPT position itself (16,867.5264 BPT — the largest single item in the cutover) is **moved by code, not by the baseline**; the baseline only decides how large a shortfall Phase 7 will notice. A downward-corrupted baseline under-detects a shortfall **by exactly the delta**. No value is moved, lost, or made unavailable by this finding alone.

Three rails hold it down, and the grading says so plainly rather than dressing it up: the corruption needs an operator slip **inside a block flagged do-not-touch** (and not the trimming slip the runbook actually warns about, which is already caught); it only weakens **detection**; and it needs an **independent real shortfall** to coincide before anything is missed.

**Explicitly NOT inflated on story-074's conditional trigger.** Story-074 states *"weakening any rail re-classifies L-02 as Medium"*. **No rail was weakened** — four were added and one was tightened — so that trigger does **not** fire and was not used.

**Evidence**: audit 23 `side-effects.json → fixVerification.run22_L02.adversarialProbes` (the two `covered: false` / `partial` entries); source `:2013-2020`, `:549`, `:564`, `:571`; `VerifyPromotionReady.s.sol:147-154`.

**Recommended Mitigation** (in full)

Emit a sibling `baselines.bptAtCutoverBlock` (decimal string, written **atomically** with the value) and have **both** Phase 0 **and** the verifier require it is non-zero and `<= block.number`. One key plus two `require`s binds the value to a block, so a hand-mangled figure no longer travels alone.

**Cheaper alternative** if that is not worth the change: log `baselines.bptAtCutover` in human units at the top of **every** leg and require the operator confirm it against the immediately preceding `:dry` run's Phase 0 `--- stranded value (live) ---` block. **Prefer the first** — the second re-introduces exactly the human-comparison weakness that audit 23's **L-02** documents.

**Triage note**

This is a **residual introduced by a fix** — the pattern this repo treats as more dangerous than an unfixed bug, because it reads as done. That shape justifies reporting it and justifies the cheap fix; it does **not** justify a Medium, because the fix genuinely did what the story specified. It was retained through dedup and sanitization on Law-1 recall grounds with the auditor's own *"filed for recall, not because it is likely"* preserved. Triage may reasonably decide to carry it; that decision belongs at `/ledger`.

**Cross-reference**: audit 22 **L-02** (`4fd1642310fda0d3…`, Part A) remains `open` with `fixed` **proposed but never applied**. Read this finding before applying that status.

---

### [audit 23 · L-05] Phase 6 never asserts the snapshot describes the same staker addresses Phase 0 checks: no `.address`/`.chainId` provenance probe, and `resolveAddress()` accepts `0x0`

**Originating run**: `phoenix-phase-2-staging-23` (`c4396b1`)
**Fingerprint**: `f59e177a97c8842940bc0ccf4b3e28be506074e9e85fb7fed3a52aec87866bf2`
**Entry point**: `promotion-ready:broadcast`
**Severity**: **Low** — **walked back from Medium** on 2026-08-03 after adversarial PoC validation refuted the mid-sequence premise. Fingerprint **unchanged** (severity is not a fingerprint input); the ledger entry stays joinable. Retired label: `M-01` (audit 23).
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1599-L1601` — `_loadSnapshotUsers` (guards: `:1550`; post-migrate `:1553-1554`; Phase 7 backstop `:1697-1699`)

> **Two retracted claims — must never be restated**: (1) *"mid-sequence / partially-applied cutover"* — FALSE, `forge script` executes `run()` as one local EVM frame and a later revert unwinds it entirely (atomic pre-broadcast abort); (2) *"L-07 is atomic, this is mid-sequence"* as the reason the two were not merged — FALSE, **both** are atomic pre-broadcast.

**Description**

`_loadSnapshotUsers` reads **only** `.stakers.<key>.users` from `scripts/snapshots/depletion-stakers-latest.json`. The snapshot file **does** record `.stakers.<key>.address` (verified at `c4396b1`: all three equal `V1_STAKER_EYE` / `SCX` / `FLX` exactly) and `.chainId` — but the script never cross-checks the address against its own constants, never checks `blockNumber` for staleness, and never checks the file exists at all before Phases 1-5 are queued.

Upstream, `scripts/snapshot-depletion-stakers.js:98-106` resolves those addresses by regex over `server/deployments/mainnet-addresses.ts`. The regex `(0x[0-9a-fA-F]{40})` **accepts a `0x000…0` "not deployed" placeholder as a valid match** — the stale-trap pattern already realized on this project, where that file has previously carried zero placeholders for **live, funded** contracts.

**Impact — read carefully; the original framing was wrong**

**No assets are stolen, no user stake is lost, and NO partially-applied cutover occurs.** The failure is an **ATOMIC PRE-BROADCAST ABORT**: `forge` runs `run()` as a **single local EVM frame** before dispatching anything, so a revert at `:1550` unwinds Phases 1-5 in full — **zero transactions signed, zero mined** — and forge's non-zero exit halts the `&&` chain in `package.json:288`, so the patch and verify legs never run.

What remains is a **precondition-hygiene** defect on a one-shot, hardware-signed mainnet cutover: Phase 6 never asserts that the snapshot targeted the same staker addresses Phase 0 asserts on. A mis-resolved snapshot is therefore caught **late** and only **incidentally** — by the empty-user-list guard at `:1550`, which fires on the **symptom** (an empty list) rather than the **cause** (a wrong address) — instead of by an explicit Phase 0 precondition that would name the actual problem. The operator cost is a late, mis-attributed abort and a re-run, not a broken protocol.

**Causal inertness — disclosed, not buried.** The address mismatch is **causally inert on its own**. `_loadSnapshotUsers` (`:1599-1601`) reads only `.users` and never `.address`, so **corrupting `.address` alone reverts nothing** — a probe that did exactly that completed the run. Only an **empty** user list fires `:1550`, and the PoC established that emptiness **by fixture construction**. The causal step *"mis-resolved address ⇒ empty/wrong user list"* was **asserted, never demonstrated**. This materially weakens the finding and is recorded here rather than omitted (Law 1: visible, not silent). The recommendation still stands on its own terms — an explicit provenance assertion plus a zero-address reject is cheap and closes a historically realized upstream hole — but the finding **may not be graded on a demonstrated causal chain, because none was demonstrated**.

**Scale, corrected**: the three `NFTStakerDepletion` instances hold **1 / 2 / 3 users** respectively (`UniboostStakerEYE` 1, `UniboostStakerSCX` 2, `UniboostStakerFLX` 3), verified directly from the snapshot file. The figures **2 / 156 / 13** that appear in superseded audit-23 stage artifacts are **STAKE UNITS** from the migrate log, **not user counts** — do not restate them as users.

**Why Low, in the classifier's own terms**: the Medium rested entirely on *when* the guard fires — *"converting an atomic pre-broadcast abort into a mid-sequence revert IS the impact"*. That premise is empirically false: there is **no mid-sequence state on this script**. With the availability impact gone, what is left is a missing explicit precondition and a late, mis-attributed error message on a one-shot script — QA/Low. Not suppressed, because the recommendation is cheap, the upstream `resolveAddress()` zero-address hole is real and historically realized, and it shares a Phase 0 fix site with audit 22 L-07.

**Refutation method (for the record)**: an independent probe ran `forge script` **without** `--broadcast`. Both broadcast-recorded actions were rolled back, forge exited 1, and nothing dispatched. `--skip-simulation` skips the **per-transaction pre-send check**, **not** the local pass. The guard's inputs (`users.length` from `vm.readFile`, `preTotal` from local forked state) are fully deterministic in the local pass, so `:1550` **always** fires pre-broadcast. This is the `ForgeLocalPassPrecedesBroadcast` family already on the ledger from run-22, whose semantics the Medium had inverted; the project's own `package.json:287` states the mechanism verbatim.

**Line-number corrections applied (carry these, do not revert them)**

- `:1681-1682` was originally cited as the fail-closed guard. **It is not.** At `c4396b1`, `:1680-1682` are Pauser-registry membership checks (`!Pauser(PAUSER).isRegistered(V1_STAKER_SCX / V1_STAKER_FLX / OLD_SYA)`), unrelated to the migration guard. That citation must appear nowhere.
- The correct Phase 6 guards are **`:1550`** (`require(users.length > 0 || preTotal == 0, "snapshot user list is empty but V1 still holds stake")`) and **`:1553-1554`** (post-migrate `require(old.totalStaked() == 0, …)` plus the conservation `require`). An intermediate correction citing `:1549` / `:1552-1553` was itself off by one — `:1549` is the `_loadSnapshotUsers(v2Key)` call site and `:1552` is the `migrate(users)` call, neither a guard.
- The Phase 7 backstop `:1697-1699` (*"V1 EYE / SCX / FLX still holds stake"*) is exact.
- **Retracted**: the sentence *"All corrected guards remain inside Phase 6 / Phase 7, which confirms the mid-sequence framing the Medium rests on."* Guard **placement inside `run()` is irrelevant**, because the whole of `run()` executes as one local EVM frame before any dispatch.

**PoC — supports a weaker claim only**

`workspace/phoenix-phase-2-staging/test/SnapshotAddressMismatchOrdering.t.sol` — **passing**, last run 2026-08-03. It is **AUDIT-AUTHORED and UNTRACKED in the upstream repo**; it must **never** be presented as an upstream project test, and it must **never** be presented as proving this finding's impact. It does not demonstrate a partially-applied cutover, because no such state exists in the real invocation.

What it actually supports:
- (a) the `:1550` guard exists, is fail-closed, and emits exactly `snapshot user list is empty but V1 still holds stake`;
- (b) `_loadSnapshotUsers` never reads `.address` (only `.users`);
- (c) **only under a counterfactual model** — where Phases 1-5 and Phase 6 are separate **top-level transactions** — does Phase 1-5 state survive the Phase 6 revert.

**Harness caveat**: the harness splits `run()` at the Phase 5 / Phase 6 boundary into two external entry points (its own header calls this *"a DEVIATION … forced by the EVM"*). That split has **no counterpart** in the real invocation, where `run()` is a single local frame. The counterfactual is the **entire source** of the harness's surviving state. The PoC is **re-scoped, not deleted** — it is a correct and useful artifact for (a)-(c).

**Recommended Mitigation** (in full)

Add a **Phase 0 snapshot-provenance probe**, before any mutation, requiring `.stakers.<key>.address == V1_STAKER_<X>` for all three stakers and `.chainId == 1`, and **rejecting the zero address**. Cost: three string comparisons on a file Phase 0 must open anyway.

Separately, harden `resolveAddress()` at `scripts/snapshot-depletion-stakers.js:98-106` to **reject `0x000…0` explicitly** rather than accepting it as a valid 40-hex match — that closes the realized upstream cause.

The benefit is **diagnostic, not availability**: the run already aborts safely and atomically, but it aborts on the symptom (*"user list is empty"*) rather than the cause (*"this snapshot is for a different address"*).

**Note for the fix author**: file-**existence** probing and `.blockNumber` **freshness** belong to open entry **audit 22 L-07** (`b28492ce…`, Part A) per SN-23-01, and should land in the **same Phase 0 block** so the operator implements one probe, not two.

**Cross-reference — audit 22 L-07 (`b28492ce9719af2d7117f52fa3cc04138c7f1764ca6e1848da9ebf6de0d19685`), deliberately NOT merged**

- **The old discriminator is FALSE and is retracted**: *"L-07 is atomic pre-broadcast, this one is mid-sequence."* **Both are atomic pre-broadcast.** Do not restate the retracted version anywhere.
- **Corrected basis for separation — different root cause, different fix**: L-07 is **file absence / staleness with no Phase 0 probe** — the file is missing or old. **This entry is content provenance** — the file may exist and be perfectly fresh yet **name the wrong addresses**. Fixing L-07 does **not** fix this entry, and vice versa.
- **SN-23-01** stands as a **scope boundary**, but its *stated rationale* is superseded by the corrected basis above. Its **reopen triggers survive verbatim**: if L-07 is closed without its **full** recommendation landing, the ceded dimensions **must be re-filed**.

---

## QA / Hardening Notes (audit 23)

### [audit 23 · Q-01] `_requireNoBroadcastFlag` asserts an invariant it structurally cannot check (cheatcode string-literal scan misses inherited mutating helpers)

**Originating run**: `phoenix-phase-2-staging-23` (`c4396b1`)
**Fingerprint**: `5e2e125056eb91aef164c9626c81cef04a3c73a6bfb20e198582781b9bc84bac`
**Entry point**: **`promotion-ready:verify`**
**Severity**: QA — **deliberate downgrade from the auditor's Low**; see the review flag below. Plausibility: **latent**.
**Location**: `lib/phoenix-phase-2-staging/script/VerifyPromotionReady.s.sol#L96-L98` — `_requireNoBroadcastFlag` (context `:89-98`; guard test `test/VerifyPromotionReadyGuards.t.sol:114-133`; `foundry.toml` `fs_permissions` read-write `./server/deployments`)

**Description**

Two compounding weaknesses in the verifier's safety story.

1. **`_requireNoBroadcastFlag()` is named for a check it cannot perform.** It only rejects `PREVIEW_MODE` (`:97`); its own NatSpec admits that **no cheatcode reports `--broadcast`**.
2. **The read-only guarantee is pinned by substring scanning, not by structure.** `VerifyPromotionReady is DeployMainnetPromotionReady is Script, StdCheats`, so the compiled artifact retains `StdCheats` and the read-write `./server/deployments` `fs_permissions` grant — while `test/VerifyPromotionReadyGuards.t.sol` pins read-only-ness with raw substring scans for cheatcode **literals only** (`startBroadcast`, `startPrank`, `vm.deal`, `vm.warp`, `forge-std/Test.sol`, `OLD_POOLER`). A future edit calling an **inherited mutating helper** — `_writeProgressFileWithStatus(...)` is the obvious one — contains none of those literals and would pass **every** current assertion, as would a live-read BPT fallback routed through a local variable or a differently-named constant instead of the literal `OLD_POOLER`.

**Impact**

**None as of `c4396b1` — and that "today" was verified, not assumed.** The verifier's complete call graph is `run -> _requireNoBroadcastFlag / _loadAndValidateProgressFile / _adoptPersistedBptBaseline / _phase7_wiringAssertions / _verifyMintAuthorityInvariance / _printSummary` — all view or storage-only. The closure-mapper independently confirmed that **every** phase function and **every** broadcast site in the inherited `DeployMainnetPromotionReady` is `internal` and **uncalled** from the verifier. The standalone run empirically mutated nothing (trace: `vm.envOr` plus a failed `vm.readFile`, then abort). A `:verify` run mistakenly given `--broadcast` is **inert**, because no broadcast context is ever opened.

So the **present-day** impact is **maintainer comprehension**: a maintainer reads `_requireNoBroadcastFlag()` and believes the verifier rejects `--broadcast`. It does not. Their mental model of what protects the read-only leg is wrong. The **latent** hazard is reachable **only from code no one has written**.

**Why QA rather than Low**: C4 QA covers *"function incorrect as to spec, issues with comments"* — a guard function whose **name** asserts an invariant it cannot check is that category exactly. The substring-only guard test is a defence-in-depth weakness on a guarantee that currently holds **structurally** rather than by the test, and its harmful branch needs code that does not exist. C4 names *"speculation on future code without demonstrated root cause"* as invalid, so grading the latent branch as a live Low would be overstatement. The finding is nonetheless **retained and reportable** — a guard overstating its own coverage is not a style nit under this project's standing position on falsely-exhaustive self-certification.

**Evidence**: audit 23 `side-effects.json → verifyLegStandalone`, `testHarnessAssessment`, `leadsResolution[0]` and `[1]`; source `VerifyPromotionReady.s.sol:89-98`; `test/VerifyPromotionReadyGuards.t.sol:114-133`; `foundry.toml` `fs_permissions` read-write `./server/deployments`.

**Recommended Mitigation** (in full)

Three parts, all cheap and all worth landing **before** the broadcast.

1. **Rename** `_requireNoBroadcastFlag` to `_requireNoPreviewMode` so the name matches the check, and **keep** the NatSpec paragraph explaining why the broadcast flag is unobservable — the explanation is good; only the name lies.
2. **Strengthen `test/VerifyPromotionReadyGuards.t.sol` from substring scanning to a call-graph assertion**: assert the verifier's source contains **no call, by name**, to any inherited mutating helper (`_writeProgressFileWithStatus`, `_trackDeployment`, `_trackConfig`, `_phase1_`..`_phase6_`, `_phase4d_`, `_phase8_`, `_moveBPT`, `_rescueTo`, `_migrateStaker`, `_collectNudgeFromOwner`, `_swapUniboost`), and assert the **presence** of `bptAtCutoverPersisted` rather than only the boolean flag.
3. **Best structural fix**, if the refactor is affordable: split the shared constants and read-only helpers into a **base contract**, so the verifier does not inherit a broadcast surface at all and the guarantee stops depending on a test at all.

**Review flag**

**DELIBERATE DOWNGRADE (Low → QA).** Recorded so a human can push it back to Low if they weight regression risk on the verifier more heavily. The downgrade rests entirely on the **empirically-verified-clean call graph at `c4396b1`**; if that verification is ever wrong, or if a mutating call site lands, **this returns to Low immediately**. Run-24 did **not** re-verify the call graph — story-076 touched this suite, so re-verify before relying on the downgrade.

---
---

## Cross-run items carried forward for the human

Process items, not contract findings, reproduced so they reach a document a human reads. **Not** assigned C4 severities.

- **MR-22-01** (ledger watch-note) — Cross-run recall gap: the `deploymentStatus:"completed"`-in-the-local-pass pattern shipped on two MAINNET cutover scripts (`DeployMainnetNudgeRatchet.s.sol:811`, `DeployMainnetUniboostCutover.s.sol:802`) that were each script-audited (run-19, run-20), and **neither audit filed it**. First filed only in run-21 as `1e8cc0dc`. Audit 23 raised the count to **seven** consumers (its L-03, inside the safety net itself). Several `_writeProgressFileWithStatus` users remain unexamined. This is a defect in the audit MODEL, not in the code.
- **MR-22-02** — the real-Kendu fork probes supply the evidence ledger L-09 (`acabc052`) declared missing. **Human re-weigh of L-09 only; do NOT auto-close.** Correct the stale "line 514" citation to checklist line 1154 when re-weighing (see audit 22 L-04).
- **MR-22-03** — Severity dependency: if `fix-pending` ledger entry `a753907e` (M-01, `dev`) lands, **audit 22 L-04's** blast radius narrows from "all reward tokens" to "the tainted token only". Re-weigh it downward then (Low → QA), and check the landed fix against the INCOMPLETE FIX rule.
- **SN-23-01** — scope boundary between audit 22 L-07 and audit 23 L-05, with reopen triggers; carried verbatim in both sections above.
- **KI-23-01** — `lib/phoenix-phase-2-staging/known-issues.md` is **absent**, although the registry claims 11 entries extracted 2026-01-09. Known-issues suppression was **blocked** in runs 22, 23 and 24; **nothing** in this bundle was suppressed on KI grounds, and the 11 cached entries are **not re-derivable** and cannot be used to suppress anything until re-extracted.

## Operator pre-broadcast summary

> If only one thing is done before the Ledger session, **tick story-072 checklist lines 1195 and 1197 as mandatory blocking steps.** That single zero-code action discharges most of the carried Medium's impact (`M-01-C1.md`, `fix-pending`) and removes the sole reason **audit 22 L-01** could escalate to Medium. Note that audit 23 L-02 establishes line 1195's hardcoded figures are **stale** — re-derive them from a fresh `:dry` run rather than trusting the prose.

## Related artifacts

- `submissions/M-01-C1.md` — the carried **`fix-pending` Medium** (`2c53e944caee…`). **Not** run-24's `submissions/M-01.md` (`6b63ef6516ac…`).
- `reports/phoenix-phase-2-staging-22/submissions/qa-report.md` and `reports/phoenix-phase-2-staging-23/submissions/qa-report.md` — the originating bundles.
- `reports/phoenix-phase-2-staging-22/submissions/spec-conformance.md` — F-01, **F-02 (= audit 22 L-05)**, **F-03 (= audit 22 L-08)**.
- `reports/phoenix-phase-2-staging-23/submissions/spec-conformance.md` — **F-01-072 (= audit 23 L-01)**, **F-02-072 (= audit 23 L-02)**.
- `submissions/qa-report.md` (run-24) — this run's **own, separate** Low/QA findings. Do not conflate the label sequences.
