> **Carryover QA report — audit 22** (copied from `reports/phoenix-phase-2-staging/22/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 23): **L-01, L-02, L-03, L-04, L-05, L-06, L-07, L-08, Q-01, Q-02, Q-03** — **all 11 entries**.
> Removed as no longer live: **none.** Every entry in audit 22's QA report is still `open` in the ledger,
> so this is a complete copy with nothing pruned and no gaps in the label sequence.
> Labels are the originals. Line numbers were accurate at the originating commit `5ae94bd`; re-verify against current HEAD `c4396b1`.

**Ledger fingerprints (verbatim), for triage:**

| Label | Fingerprint | Status as of audit 23 |
|---|---|---|
| L-01 | `c04da307336ccff090b5e9f25b9a9451f9c2007d46483f562ee711ad378a7243` | open |
| L-02 | `4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42` | open — **`fixed` PROPOSED, not applied** |
| L-03 | `ea648ec5eab0c92624bed78b303577423967385a48df8738b68153c50cba9324` | open |
| L-04 | `e6f32c475e7a9213fd03495f3aa8ad326e8928fb91d9be5403df48a2cd57986a` | open — materially de-risked (see note) |
| L-05 | `3c957109ef53404376145e81a57d23db18474cc1ba0174dc7fc0f4f60e33190d` | open |
| L-06 | `78c91a8727eb99aa4ba339497a890988c8a9cb3407214d7af4402a499b80404f` | open |
| L-07 | `b28492ce9719af2d7117f52fa3cc04138c7f1764ca6e1848da9ebf6de0d19685` | open — scope-narrowed vs new M-01 (SN-23-01) |
| L-08 | `d5d55f34c5d6ffa3f24c7833b43d707dbba4e1336eb558db9f7a3bde54946576` | open |
| Q-01 | `909e6d267d4c99d5dc44600c4a96700b6f3334005840ac3b24ca50530817398e` | open |
| Q-02 | `b3caa280e070dbb4aa16956cce8598a7025e7ad76346d412cf65eb8efca943ff` | open |
| Q-03 | `050428e852c4e27de20a44cbec65bb1b764b15af73bb5fa987e5b2acb871a8bf` | open |

### Audit-23 evidence notes on three of these entries (no status was changed)

- **L-02 — `fixed` PROPOSED, NOT APPLIED.** Story-074 landed the write-once `bptAtCutover`
  baseline; the script-auditor's fork verdict was COMPLETE FIX, and four rails were added with one
  tightened — **none weakened**, so story-074's own conditional-Medium trigger does **not** fire.
  The entry nevertheless remains **`open`** and is carried over here. Only a human applies `fixed`:
  `/ledger phoenix-phase-2-staging fixed 4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42`.
  Read audit 23's new **L-04** (`80a741a27fe0fded…`) first: it is a residual **introduced by this
  very fix** — the persisted baseline carries no provenance binding, so a hand-mangled digit is
  accepted as the write-once value.
- **L-04 — still open, materially de-risked (flag L-04-23-01).** The Kendu fee-on-transfer probe ran
  **green** on the live fork at block 25670926: `sent == received == credited == 1e24`, i.e. Kendu is
  not taxed today. That removes the realized-harm case but **not** the finding — the probe is still
  PREVIEW-only, so the broadcast path continues to whitelist Kendu without running it. Re-weighing
  belongs at `/ledger`, not to a scan.
- **L-07 — still open, scope-narrowed (SN-23-01).** Audit 23's new Medium **M-01**
  (`f59e177a97c88429…`) is deliberately **not merged** with this entry. The file-**existence** probe
  and the `.blockNumber` freshness assertion remain **L-07's**; the new M-01 keeps only the
  address-set mismatch. Both fixes belong in the same Phase 0 block so the operator implements one
  probe, not two. **Reopen trigger:** if L-07 is closed without its *full* recommendation landing,
  the ceded dimensions must be re-filed — closing it on a partial fix would silently drop both
  dimensions from every future scan.

---

# QA Report — phoenix-phase-2-staging @ `5ae94bd453bab0a5d5e5a10bd6133c11188ae6d5`

**Run**: `reports/phoenix-phase-2-staging/22` (run-22)
**Audit type**: script audit (`/audit-script`) — not a full contract scan of the submodule
**Entry point**: `promotion-ready:broadcast`
**Story**: `story-072` — mainnet NudgeStreamer cutover, multi-token BatchMinter, staker V2 migration
**Verification mode**: mainnet-fork PREVIEW execution of `promotion-ready:dry`, **fork pin block 25659373**
**Dry-run result**: **PASSED** — exit 0, no revert, **ZERO unintended state writes** (`side-effects.json`: `unintendedEffectCount: 0`). Every Phase 0 precondition and Phase 7 read-back assertion that was actually asserted passed; the snapshot was proven complete; the Kendu BLOCKING fee-on-transfer gate exact-passed against the REAL token. **Two declared postconditions returned *not asserted* rather than pass** (`side-effects.json` `postconditionResults`: *"phUSD minter set byte-identical"* — NOT ASSERTED ANYWHERE; *"rescueERC20 still works on the paused old batch minter"* — NOT PROVEN), and the Phase 7 BPT check is **vacuous on a resume path** — see **M-01**, **L-05** and **L-02**.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 8 |
| QA / hardening | 3 |
| **Centralization** | **0** |
| **Total** | **11** |

**Medium: 1**, submitted separately as `submissions/M-01.md` — the run total is **12**, of which this bundle carries 11.

**Centralization risk: none.** No `C-XX` findings were produced by this run. This is stated explicitly rather than omitted — the category was assessed and came back empty. Every owner-privileged operation in this closure (`setNudgeTokenWhitelist`, `setMinter`, `rescueERC20`, `topUp`, `setPauser`/`pause`) is a **lever the findings below rely on for recoverability**, and none was found to constitute an unbounded or non-obvious centralization hazard in its own right.

### Scope and suppression notes

- **Nothing was suppressed on known-issues authority in this run.** `registered-projects.json` declares `knownIssuesFile: "lib/phoenix-phase-2-staging/known-issues.md"` with `knownIssuesCount: 11`, but **that file does not exist on disk**. The 11 cached entries are a non-re-derivable 2026-01-09 snapshot. Under Law 1 the dedup and sanitize passes were both barred from suppressing on that basis, and this bundle inherits the same constraint. (Cached known-issue #10, "Admin trust assumptions…", was considered against Q-03 and **rejected as authority** on exactly this ground — and would have failed on the merits regardless.)
- **No sections were merged.** All 11 entries survived a deduplication pass that specifically tested and **rejected six merge candidates**: `PR-02+PR-05`, `PR-03+PR-10`, `PR-06+PR-09+PR-10`, `PR-04+PR-11`, `PR-07+PR-08`, `PR-01+PR-12`. In each case the test applied was *"does the fix for A also fix B?"* and the answer was no in both directions — and for `PR-09 → PR-06` the answer is that A's fix **actively regresses** B. Collapsing any of these would let a reader fix the most visible member and believe the rest were addressed.
- **Two entries are also faithfulness (Law-2) items** — **L-05 (F-02)** and **L-08 (F-03)**. They are bundled here at their honest Low severity, but **the QA bundle does not satisfy their spec-conformance routing**; both must also appear in `spec-conformance.md`.
- **Fingerprints** are the CANONICAL lib-prefixed hashes the ledger keys on, reproduced verbatim from the finding records. Each record also carries a `fingerprintAltUnprefixed` for future path-normalising reconciliation; that alternate is not reproduced here.
- **Automated QA/gas appendix (4naly3er): NOT ATTACHED — gap declared.** 4naly3er is installed at `tools/4naly3er` but aborted on this submodule with `EISDIR: illegal operation on a directory, read` (`src/compile.ts:124`) after enumerating 14,000+ tree entries; it did not honour the scope list. No automated report was produced for run-22. The manual QA bundle below proceeds unaffected. This gap is recorded rather than papered over.

---

## Low Risk Findings

### [L-01] A user who stakes between snapshot generation and the on-chain pause is silently stranded on a paused, defunded, Pauser-deregistered V1 staker <!-- id: pps22l1 -->

**Severity**: Low — **CONDITIONAL MEDIUM, TRIGGER ARMED. Do not file this as routine.**
**Fingerprint**: `c04da307336ccff090b5e9f25b9a9451f9c2007d46483f562ee711ad378a7243`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-11 (classifier CLASS-002)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1388-L1398` — `_migrateStaker`

> ### ⚠ CONDITIONAL-MEDIUM REOPEN TRIGGER — carried verbatim
>
> **RE-CLASSIFY AS MEDIUM if ANY of the following holds at broadcast time: (a) story-072 checklist line 1195 is still unticked when the Ledger session begins - the sole reason this is Low is that a specific, sufficient detection control is designated, and an unticked control is not a control; (b) the snapshot is older than a documented freshness bound at consumption time; (c) the staker population grows materially beyond the 6 addresses observed at block 25659373. This trigger must be carried into the ledger entry verbatim.**
>
> **Primary trigger**: story-072 checklist **line 1195** is still UNTICKED when the Ledger session begins — *an unticked control is not a control*, and it is the sole reason this is Low rather than Medium.
> **Armed if**: remediation option (b) below (freshness gate only) is chosen. It **narrows** the window; it does not close it. Only option (a) closes it.

**Description**: `snapshot-depletion-stakers.js` freezes the migrate user list at block N, and forge's local pass freezes it a second time. `NFTStakerDepletion.stake` is UNGATED during `Migrating` (`NFTStakerDepletion.sol:550`, audit-20 M-05), and V1 is not actually paused until the `st_<label>_pause` transaction lands on-chain — potentially hours into the Ledger session. A user who stakes inside that window is absent from `users`, so `migrate(users)` skips them.

The stated backstop `require(old.totalStaked() == 0, "V1 still holds stake after migrate - widen the snapshot and re-run")` at `:1394` cannot catch it: like all of Phase 6 it evaluates in the local pass against pre-broadcast state (see M-01). Step 9 then sweeps V1's reward budget down to a ~1% residual, and V1 has already been unregistered from the global `Pauser`, so a later `Pauser.unpause()` will not reach it.

*(The vacuous guard at `:1394` is a **citation** of M-01/PR-09, not an overlap: L-01 remains a finding even if the guard were made real, because the user would then merely halt the cutover rather than be silently skipped.)*

**Impact**: An end user's staked NFT position and its future emissions become UNAVAILABLE on a retired contract. No value is destroyed and nothing is transferred to a third party: the position remains on V1, the owner retains `setPauser`/`unpause`, `migrate` is re-runnable by design, and V1 can be re-funded or V2 topped up. Recovery is full and owner-controlled — but manual, and undetected until someone looks.

**Recommendation** (verbatim):

> Close the window rather than narrow it: split the pause out of the frozen plan. Either (a) pause all three V1 stakers in a separate, short broadcast BEFORE generating the snapshot, so the user list is taken against an already-frozen contract - the snapshot header's 'does NOT need to be taken after a pause' rationale then no longer applies and the list becomes provably final; or (b) add a hard freshness gate: record the snapshot's `blockNumber` in the JSON (it already is) and `require(snapshotBlock >= block.number - N)` in Phase 0 so a stale list cannot be consumed at all. (b) is cheap and also fixes PR-03's late-failure problem. Independently, keep the story's 'Open items carried to review' instruction - re-run `promotion-ready:snapshot` immediately before the session - as an operator gate.
>
> CLASSIFIER ADDENDUM: option (a) is the only one that CLOSES the window; (b) only narrows it. If (b) is chosen, the conditional-Medium reopen trigger above stays armed.

**Remediation overlap (preserved)**: a Phase 0 `require(snapshotBlock >= block.number - N)` would narrow L-01's window and satisfy part of **L-07 (PR-03)**. If L-07's recommendation is implemented in full, re-check L-01 for partial closure — **but do not auto-close it**: narrowing a window is not closing it, and the ungated `NFTStakerDepletion.stake` during `Migrating` (audit-20 M-05) is unchanged.

---

### [L-02] Phase 7's BPT conservation assertion degrades to `>= 0` on every resume path, leaving the largest asset in the cutover unverified exactly when verification matters most <!-- id: pps22l2 -->

**Severity**: Low — **CONDITIONAL MEDIUM + FIX-ORDERING CONSTRAINT**
**Fingerprint**: `4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-06 (classifier CLASS-003)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1563-L1564` — `_phase7_wiringAssertions`

> ### ⚠ FIX-ORDERING CONSTRAINT — load-bearing
>
> **IMPLEMENT L-02 BEFORE M-01.** This is the decisive inversion the deduplicator preserved and it must survive into the report: a consolidation of L-02 into M-01, or an M-01 fix shipped alone, would **silently widen this bug while reading as a resolution**.
>
> ### ⚠ CONDITIONAL-MEDIUM REOPEN TRIGGER — carried verbatim
>
> **RE-CLASSIFY AS MEDIUM if any of the six `_moveBPT` guard rails is weakened, removed, or refactored - they are the sole reason this is Low. In particular, M-01's recommended fix (relocating Phase 7 to a standalone post-broadcast verifier) ACTIVELY WORSENS this finding: the relocated Phase 7 would re-read `bptAtPhase0` from an already-emptied `OLD_POOLER`, making the assertion vacuous on the FRESH path too. If M-01's fix is implemented without persisting `bptAtCutover`, this becomes a Medium.**

**Description**: A first broadcast leg completes the BPT move (`OLD_POOLER` → `newPooler`) and the session is then interrupted. The operator runs `:resume`. Phase 0 re-reads `bptAtPhase0 = IERC20(BALANCER_POOL).balanceOf(OLD_POOLER)` at `:505`; the old pooler is now empty, so `bptAtPhase0 == 0`. Phase 7's `require(IERC20(BALANCER_POOL).balanceOf(newPooler) >= bptAtPhase0)` therefore reduces to `>= 0` — unconditionally true, and would remain true even if the 16,338 BPT sat on a third address. The companion `require(balanceOf(OLD_POOLER) == 0)` at `:1563` still holds, but "the old pooler is empty" and "the new pooler is full" are different claims; only the vacuous one covers the second. This is the exact step the `//promotion-ready:resume` annotation singles out as "THE ONE STEP A BAD RESUME COULD RUIN".

**Impact**: None demonstrated. 16,338.8190 BPT is the largest single asset in the closure and the assertion intended to confirm its arrival becomes `balanceOf(newPooler) >= 0` on any resume leg where the move already landed. But the audit could not construct a state in which the BPT actually goes astray: the six `_moveBPT` guard rails were independently assessed as effective in EVERY enumerated resume branch. The loss is one layer of defence-in-depth, not custody. The 16,338.8190 BPT magnitude justifies the L-02 **ordering** and the conditional-Medium trigger, **not** a Medium tier.

**Recommendation** (verbatim):

> Persist the Phase 0 BPT reading across resumes rather than re-deriving it. Record it in the progress file as a first-class entry (the `ContractDeployment` struct already carries unused `uint256` fields, or add a sibling `bptAtCutover` key) and, when a progress file is present, assert `balanceOf(newPooler) >= recordedBpt` instead of the freshly-read zero. A cheaper stopgap: when `_isConfigured("pooler_bpt")` is true, assert `balanceOf(newPooler) > 0` at minimum, so the resume path is never fully vacuous.
>
> CLASSIFIER ADDENDUM: land this BEFORE M-01's verification entry point, and have that entry point consume the persisted `bptAtCutover` rather than a freshly-read Phase 0 value.

**Class siblings — linked, NOT collapsed**:
- ledger `2f8e1ff5e1aed9ffb17444b2ccd3e57b4029363045955aaa412217a4e41facae` (UBC-02, `uniboost-cutover`, run-20, low/open) — same resume-semantics family, distinct instance. UBC-02 is a checkpoint whose GRANULARITY lets resume skip real work; L-02 is a checkpoint-derived BASELINE that resume reads as zero.
- ledger `141aceaae3946026f516a8f74fedf3e067bb80769fc21b6704b31433404d33cc` (L-01, `deploy:ratchet-mainnet`, run-19, low/open) — head of the resume-footgun chain.

**Systemic observation (preserved)**: THREE consecutive mainnet-cutover script audits (run-19, run-20, run-22) have each produced a distinct resume-path footgun on the same `_writeProgressFile` / `_isConfigured` checkpoint idiom, copy-inherited across `DeployMainnetNudgeRatchet.s.sol`, `DeployMainnetUniboostCutover.s.sol` and `DeployMainnetPromotionReady.s.sol`. Harden the shared idiom once — this is a pattern-level recommendation, **not** a consolidation of the three ledger entries.

---

### [L-03] The progress file is stamped `deploymentStatus: "completed"` during the local pass, making the patch script's own gate structurally inert <!-- id: pps22l3 -->

**Severity**: Low
**Fingerprint**: `ea648ec5eab0c92624bed78b303577423967385a48df8738b68153c50cba9324`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-10 (classifier CLASS-004)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L402-L404` — `run` / `_writeProgressFileWithStatus`
**Consumer**: `lib/phoenix-phase-2-staging/scripts/patch-mainnet-addresses-promotion-ready.js#L122-L124` (header at `:16-22`)

**Description**: `_writeProgressFileWithStatus("completed")` is called at the end of `run()` — the end of forge's LOCAL pass, before any transaction is broadcast. `_trackDeployment`/`_trackConfig` write `"in_progress"` during the same pass, so `"in_progress"` is only ever observable after a LOCAL-pass revert (which also yields a non-zero forge exit). Any run that reaches the broadcast stage at all has therefore already written `"completed"` with every step marked done.

**The material addition over the ledger sibling is the consumer**: `patch-mainnet-addresses-promotion-ready.js:122-123` gates on exactly `deploymentStatus === 'completed'`, and its own header at `:16-22` describes that gate as **"necessary but not sufficient"**. It is in fact necessary **AND unconditionally true** at every point the patcher can run — i.e. **it carries zero information**.

Harm requires THREE compounded operator deviations: the broadcast crashes; the operator invokes the patcher manually OUTSIDE the `&&` chain; and the operator skips the documented mandatory hand-trim against `run-latest.json` receipts.

**Impact**: None on-chain. The blast radius is an OFF-CHAIN artefact: `mainnet-addresses.ts` patched with addresses for contracts that may never have been deployed, which then feeds the UI and downstream scripts. Fully recoverable — `backup-mainnet-addresses.js` precedes the patch in the chain and the address file is version-controlled.

**Recommendation** (verbatim):

> Either (a) write `"completed"` from the JS side after `forge script` returns 0 - i.e. have `patch-mainnet-addresses-promotion-ready.js` itself accept an explicit `--confirm-broadcast` flag and stop reading `deploymentStatus` as evidence - or (b) restate the header honestly: 'deploymentStatus is written pre-broadcast and is NOT evidence that anything landed; the only interlocks are the `&&` short-circuit and the mandatory hand-trim against run-latest.json receipts.' Option (b) is a one-line documentation fix and is sufficient.
>
> CLASSIFIER ADDENDUM: whichever option is chosen, apply it to the SHARED idiom rather than this one script - `_writeProgressFileWithStatus` has six users (see MR-22-01) and the paired `patch-mainnet-addresses-*.js` gate exists on at least three of them.

**Class sibling — LINKED, NOT COLLAPSED**: ledger `1e8cc0dc58ba0ecbe43faf12ea343e3d6eb784c36d3ad2b0141668e33777871e` (L-01, entry point `dev`, run-21, `DeployMocks.s.sol` / `_writeProgressFile`, low/open). This is a **disclosed re-file on a new entry point**, not a duplicate:
- Different `entryPoint` (`promotion-ready:broadcast` vs `dev`) ⇒ different fingerprint; reconciles separately by design.
- Different contract (`DeployMainnetPromotionReady.s.sol` vs `DeployMocks.s.sol`) and different function.
- Different target: the ledger instance writes `progress.31337.json` on ANVIL; L-03 writes the **MAINNET** progress file a live cutover depends on.
- **Different consumer — the material addition**, as detailed above. The ledger's `dev` instance had no such consumer analysis.
- The ledger entry's own note ANTICIPATES this filing: *"PROPAGATES-TO-MAINNET as a PATTERN - this shape has already poisoned three committed mainnet progress files."* Dropping L-03 as a duplicate would erase the confirmation that note was written to invite.

Ledger entry `1e8cc0dc` was **not modified** by this run.

---

### [L-04] Kendu is whitelisted unconditionally while its BLOCKING fee-on-transfer probe is PREVIEW-only, and a taxed token bricks batchMint for every reward token <!-- id: pps22l4 -->

**Severity**: Low — **severity depends on a fix-pending ledger entry; flagged for human re-weigh, NOT auto-closed**
**Fingerprint**: `e6f32c475e7a9213fd03495f3aa8ad326e8928fb91d9be5403df48a2cd57986a`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-01 (classifier CLASS-005)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L636-L644` — `_phase2_deployBatchMinter` / `_probeKenduFeeOnTransfer`

**Description**: `bm_.setNudgeTokenWhitelist(KENDU, true)` at `:640-644` is unconditional on the broadcast path. `_probeKenduFeeOnTransfer()` — which **story checklist line 1154 designates BLOCKING** — lives in `_phase8_previewSmokeTests()`, and Phase 8 runs only when `PREVIEW_MODE=true` (`run():402-408`). A `--broadcast` run therefore whitelists the token with the blocking gate never executing; enforcement rests entirely on the operator having run `promotion-ready:dry` first. If a whitelisted token is confiscatory or reverting, `batchMint` step 3.5 loops `pullPendingStream` over the whole whitelist with NO try/catch (`BatchNFTMinterMultiToken.sol:528-536`), so one bad token bricks `batchMint` for USDC and phUSD too.

**Not suppressed under the fee-on-transfer known-invalid rule**: the project itself designated this a BLOCKING gate (story line 1154), which is sponsor scope-in, and the root cause is **structural placement**, not a token quirk. Nor is it tagged F-class: the deviation is disclosed and accepted in the story itself (lines 1464, 1498, post-review correction #2), so Law 2 is satisfied and the residual is a structural-vs-procedural design choice.

**Impact**: None for Kendu, empirically: the fork probe against the REAL token at block 25659373 returned exact 1e24-in / 1e24-credited, and Kendu's ownership is renounced (`owner() == 0x0`) so its fee switches can never be moved again. The structural exposure is AVAILABILITY of the entire batch-mint reward path if a FUTURE third reward token is whitelisted on a broadcast run with no tax check. Remedy is immediate — `setNudgeTokenWhitelist(token, false)` is owner-only and takes effect at once. This is availability-with-a-lever, not loss.

**Recommendation** (verbatim):

> Make the gate structural rather than procedural: perform the round-trip probe INSIDE Phase 2, immediately before `setNudgeTokenWhitelist(KENDU, true)`, in BOTH modes. It needs no cheatcode when broadcasting - the owner can fund the probe from its own Kendu balance with a small amount, or the check can be reduced to a broadcast-safe static assertion (`buyTotalFees() == 0 && sellTotalFees() == 0 && owner() == address(0)`) that the script `require`s unconditionally. If the probe must stay preview-only, gate the whitelist call on a `KENDU_PREFLIGHT_PASSED=true` env var that only the dry run instructs the operator to set.

#### Ledger relationship 1 — PARTIAL DISCHARGE of a blocking pre-broadcast action

Ledger `acabc052baaa956e35d5f668f303ce40f244c0778b8154f71ff318ad46c74709` (**L-09**, entry point `dev`, run-21, low/open, `NudgeStreamer.sol` / `registerStream` / `collectNudge`) carries a **BLOCKING PRE-BROADCAST ACTION**: *"tick story 072 Preflight line 514 against the REAL Kendu token 0xaa95f26e30001251fb905d264aa7b00ee9df6c18, NOT MockKendu. Story 073's `_seedNudgeStream` probe does NOT discharge it."*

**L-04 is the venue that PARTIALLY DISCHARGES that action.** The run-22 fork probe exercised the **REAL Kendu token `0xaa95…`** — not `MockKendu` — at block 25659373 and returned an exact result: **1e24 sent / 1e24 received / 1e24 credited**, with `owner() == 0x0` (ownership renounced, so the fee switches can never be moved again). That is the substantive proof L-09 said was missing.

**Residual**: the probe ran in PREVIEW only. L-09's *evidentiary* gap is now closed for Kendu specifically; L-04's *structural* gap remains open for any FUTURE third reward token whitelisted on a broadcast run with no tax check at all.

**Action for the human**: re-weigh L-09 (`acabc052`) in light of run-22's real-token fork probe — it may now be closable or downgradable on the Kendu-specific limb. **Do NOT auto-close**: L-09's `reopenTrigger` and its wider story-safety framing are untouched by this pass.

**Citation correction**: L-09's note cites "story 072 Preflight line 514". At the current story revision that line number is **STALE** — line 514 is a row of the live-hook-state table. The BLOCKING Kendu preflight is checklist **line 1154**, verbatim: *"- [x] **BLOCKING** — confirm Kendu is not fee-on-transfer by round-tripping a non-zero amount through `collectNudge` and asserting the credited buffer delta equals the amount sent. If it is taxed, drop Kendu from the whitelist and leave its `mainnet-addresses.ts` key at zero."* That item is now TICKED, with PASS evidence at story lines 1392 and 1436. Ledger entry `acabc052` was **not modified** by this run.

#### Ledger relationship 2 — impact-chain dependency on the project's only `fix-pending`

Ledger `a753907e2a4c6261389ea642ede743e198b50741d4bcb43fa8bad900729174d1` (**M-01**, entry point `dev`, medium, **status `fix-pending`**). L-04's amplifier — *"one confiscatory or reverting reward token bricks batchMint for USDC and phUSD too"* — **IS** that entry (NudgeStreamer pooled-custody + `BatchNFTMinterMultiToken.batchMint` looping `pullPendingStream` with no try/catch). Being `fix-pending`, it is **never suppressed** and still live.

- **M-01 being fix-pending is NOT treated as a mitigation for severity purposes** — a fix that is owed is not a fix that exists. L-04's Low rests on the empirical Kendu evidence and the immediate owner lever.
- **Triage note**: if M-01's fix lands, L-04's blast radius shrinks from "all reward tokens" to "the tainted token only", which would justify **re-weighing L-04 downward** (from Low toward QA, not from Medium toward Low). Check any landed fix against the INCOMPLETE FIX rule. **This is flagged for human re-weigh; nothing is auto-closed.**
- L-04 does **not** depend on M-01 for validity — the unconditional whitelist write is real either way. Ledger entry `a753907e` was **not modified** by this run.

---

### [L-05] Phase 4d's post-pause residue sweep can never fire, so its stated rationale and the story's "rescueERC20 still works while paused" assertion are both unproven <!-- id: pps22l5 -->

**Severity**: Low — **also a Law-2 faithfulness item, routed to `spec-conformance.md` as F-02**
**Fingerprint**: `3c957109ef53404376145e81a57d23db18474cc1ba0174dc7fc0f4f60e33190d`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-02 (classifier CLASS-006)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1137-L1148` — `_phase4d_retireOldBatchMinter`

**Description**: Autonomous Decision 2 reasons: *"Donors keep pushing USDC at the old sink for the whole interval between Phase 3's rescue and their own repoint… On the dry run the residue was 0 (Phase 3 ran seconds earlier); on a real multi-hour Ledger session it will not be."* That reasoning does not survive forge's execution model. `uint256 residue = IERC20(USDC).balanceOf(OLD_BATCH_MINTER)` at `:1140` is evaluated in the LOCAL pass, seconds after Phase 3's LOCAL rescue — so `residue` is 0 there too. The `if (residue > 0)` branch is therefore never taken and **no rescue transaction is ever queued into the broadcast plan**. Whatever USDC actually accumulates on the old minter during the multi-hour broadcast is not swept. The trailing `require(balanceOf(OLD_BATCH_MINTER) == 0)` at `:1148` likewise evaluates only locally and passes vacuously. Fork-confirmed: the run logged "no residue to sweep".

**Faithfulness deviation (F-02)** — story line 1166, ticked: *"- [x] Phase 4d (after every donor is repointed): retire the old batch-minter — `setPauser(OWNER)` then `pause()`. **Do not register it with the global `Pauser`.** Assert `paused() == true` and that `rescueERC20` still works while paused."* Only the first two obligations are met. `paused() == true` IS asserted at `:1134`. *"that `rescueERC20` still works while paused"* is **not asserted anywhere**: the else branch at `:1146` merely LOGS the claim as prose, and the `if (residue > 0)` branch that would have exercised it is structurally unreachable in the local pass. A ticked acceptance criterion claims an assertion the code only prints as a sentence. **Second deviation**: Autonomous Decision 2 asserts a leak is structurally closed when it is not — a documented design decision contradicted by the code it describes, independent of the checklist tick.

**Impact**: A small, bounded amount of USDC — donations landing on the old sink between Phase 3's rescue and each donor's repoint — is left on a paused, retired contract instead of entering the stream. It is **NOT lost**: `rescueERC20` is `onlyOwner` and is not pause-gated, so the funds are recoverable at any later time. Stranded-value-pending-a-manual-step. **Explicitly NOT framed as an economic value leak.**

#### Recommendation

> ⚠ **The auditor's original limb (1) is SELF-NEGATING and is NOT presented as the fix.** As written it proposes an unconditional full-balance rescue and withdraws it in the same sentence (*"if the legacy minter supports it, or - since it does not -"*), leaving "add an explicit post-broadcast operator step to the runbook" with no stated content. A finding whose primary fix retracts itself is incomplete. The **`CLASSIFIER ADDENDUM` below is the recommendation of record.** It was not invented over the auditor's text — that text is preserved in the finding record — but the **owner must choose between the two options it supplies.**

**CLASSIFIER ADDENDUM** (verbatim — the recommendation of record):

> CLASSIFIER ADDENDUM (limb (1) is self-negating as written and needs a decision, see recommendationQuality): the concrete form of the fallback is - add to the runbook, as a numbered post-broadcast step alongside story checklist line 1195, 'read `IERC20(USDC).balanceOf(OLD_BATCH_MINTER)`; if non-zero, call `rescueERC20(USDC, OWNER, bal)` then `forceApprove` + `collectNudge(newBM, USDC, bal)` so it enters the stream rather than the pot' - i.e. mirror Phase 3's own sequence by hand. Alternatively, if the legacy minter's `rescueERC20` accepts an explicit amount, queue a SECOND rescue unconditionally with a `try`-wrapped call so a zero-balance case is a no-op rather than a revert. Either way, Autonomous Decision 2's 'structurally closed' claim must be retracted - that part is not optional.

**NON-NEGOTIABLE, independent of the owner's choice**: **Autonomous Decision 2's claim that the leak is STRUCTURALLY CLOSED must be RETRACTED — regardless of which fix the owner chooses.** That part is not optional and is not contingent on the choice between the two remediation options above.

**Primary fix (strong and concrete as originally written — limb (2))**: prove the pause-transparency property in Phase 8 instead — `deal` 1 USDC onto the paused old minter and assert `rescueERC20` succeeds, which is a real test rather than a comment. The runbook step above is the **compensating control**, not the primary fix.

**Not merged with L-08**, though both surface as comment drift: comment drift is the shared **symptom**, not the shared cause. L-05 is a conditional evaluated in the local pass so no rescue tx is ever queued (functional); L-08 is two dispatcher indices never exercised (coverage). A merged "fix the drifted comments" finding would leave both underlying defects live while reading as resolved.

---

### [L-06] The snapshot scanner's `DEFAULT_FROM_BLOCK = 25000000` is an undocumented correctness horizon for the `migrate()` user list <!-- id: pps22l6 -->

**Severity**: Low
**Fingerprint**: `78c91a8727eb99aa4ba339497a890988c8a9cb3407214d7af4402a499b80404f`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-04 (classifier CLASS-007)
**Location**: `lib/phoenix-phase-2-staging/scripts/snapshot-depletion-stakers.js#L89` — `main`

**Description**: `const DEFAULT_FROM_BLOCK = 25000000n` bounds the `Staked`/`Unstaked`/`DepositedFor` log scan that produces Phase 6's `migrate()` user list. Any position opened before block 25,000,000 yields a SHORT list unless `FROM_BLOCK` is overridden. Neither the story, the script NatSpec, nor the (absent) npm annotation records that this constant is load-bearing for migration completeness. The TOTAL-miss case is guarded — `die(4, ...)` fires when `totalStaked > 0` but zero holders were found (`:242-243`). **The PARTIAL-miss case is not**: `sumStaked != totalStaked` emits a non-fatal WARNING to stdout only (`:245-248`), so a partial under-enumeration still emits a snapshot that the Foundry script then trusts.

Retained rather than dropped as speculation: the C4 "speculation on future code without demonstrated root cause" carve-out does not apply — the root cause is present in committed code, and empirical cleanliness today is **confidence, not absence of root cause**.

**Impact**: Latent, none realised. Under-enumeration would strand a user's staked position on V1 — the same end state as L-01, reached by an orthogonal route. Recoverable by owner action (`migrate` is re-runnable by design). Likelihood is nil today, **verified rather than assumed**: the run at the pin block reconciled EXACTLY on all three stakers (1 user / sum 2 == totalStaked 2; 2 users / 146 == 146; 3 users / 13 == 13).

**Recommendation** (verbatim):

> Promote the `sumStaked !== totalStaked` warning at `:245-248` to a hard `die(4, ...)`: a list that does not reconcile against `totalStaked` is exactly the subset case the header says to avoid, and `migrate` being re-runnable makes a false abort cheap while a silent subset is expensive. Additionally, document `DEFAULT_FROM_BLOCK` as 'must precede the earliest of the three stakers' deployment blocks' and record those three block numbers in the comment so the constant can be audited rather than trusted.

**Report emphasis (preserved)**: this ask — promote the `sumStaked !== totalStaked` warning to a hard `die(4)` — is **the single cheapest structural improvement in the whole candidate set**. It converts the silent-subset case into a refusal, and `migrate` being re-runnable makes a false abort nearly free. Worth surfacing despite the Low severity.

**Not merged with L-01**, despite an identical end impact: these are orthogonal bounds on the same enumeration — L-06 is the scan's **lower block bound**, L-01 is the **wall-clock upper bound**. Different contracts, different fixes, and each leaves the other's window fully open.

---

### [L-07] The snapshot file is a documented hard prerequisite with no Phase 0 probe; it fails at line 1390 of 2171 with a generic filesystem error <!-- id: pps22l7 -->

**Severity**: Low
**Fingerprint**: `b28492ce9719af2d7117f52fa3cc04138c7f1764ca6e1848da9ebf6de0d19685`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-03 (classifier CLASS-008)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1440-L1443` — `_phase0_preconditions` / `_loadSnapshotUsers`

**Description**: `scripts/snapshots/depletion-stakers-latest.json` is a hard prerequisite named by the `//promotion-ready`, `//promotion-ready:dry` and `//promotion-ready:resume` annotations and by the script NatSpec at `:129-131`, and it is deliberately gitignored (Autonomous Decision 8). **Phase 0 — the designated `require`-gated precondition phase, which checks 17 owners, 5 dispatcher slots, 5 prime tokens, 6 donor sinks and 5 hooks — never probes for it.** The first read is an untry'd `vm.readFile(SNAPSHOT_FILE)` at `:1441`, reached from `:1390` inside Phase 6, after roughly 50 transactions have already been built. The failure surfaces as Foundry's generic fs error, not as "run promotion-ready:snapshot first". Separately, `promotion-ready:snapshot` is the only one of the five npm keys with no `//` annotation.

**The finding is the absent Phase 0 probe and the generic error at line 1390/2171 — it is not a fund risk.**

**Impact**: **None.** The failure is **fail-closed and atomic**: because the whole body executes locally before any dispatch (true even under `--skip-simulation`), a missing snapshot aborts the run **before a single transaction is broadcast**, so nothing is half-applied on mainnet. Nothing is applied and nothing is recoverable-from, because there is nothing to recover. The cost is operator time and an unactionable error message mid-session with a Ledger connected. Likelihood is moderate as an operator event (a gitignored prerequisite is exactly the file a fresh checkout or a second operator machine lacks); **nil as a funds event**.

**Recommendation** (verbatim):

> Add to Phase 0: `try vm.readFile(SNAPSHOT_FILE) returns (string memory j) { require(bytes(j).length > 0, "snapshot file empty - run: npm run promotion-ready:snapshot"); } catch { revert("snapshot missing - run: npm run promotion-ready:snapshot"); }`, and while there, parse `.blockNumber` and assert freshness (which also addresses PR-11). Add a `//promotion-ready:snapshot` annotation to package.json documenting the prerequisite relationship, the `FROM_BLOCK` horizon and exit code 4.

**Not merged with L-03**, and the reason is an **inversion that must not be collapsed**: for L-07 the local-pass execution model is the **MITIGATION** — it is precisely why a missing snapshot fails closed and atomically; for L-03 the same model is the **DEFECT**. Root causes are a missing Phase 0 prerequisite probe vs a status flag written before the event it attests. No shared code, no shared fix.

**Secondary observation (preserved inside this finding, not split out)**: `promotion-ready:snapshot` is the only one of the five npm keys with no `//` annotation — the same documentation gap on the same prerequisite relationship.

---

### [L-08] Indices 2 and 3 are never functionally exercised, so `setMinter` on two of the three new Uniboosts has no verification of any kind — and Autonomous Decision 5 claims otherwise <!-- id: pps22l8 -->

**Severity**: Low — **also a Law-2 faithfulness item, routed to `spec-conformance.md` as F-03**
**Fingerprint**: `d5d55f34c5d6ffa3f24c7833b43d707dbba4e1336eb558db9f7a3bde54946576`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-05 (classifier CLASS-009)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1665-L1707` — `_probeDonorPaths` / `_assertSlot` (claim repeated in code at `:1575-1580`)

**Description**: Autonomous Decision 5 removes the `dispatcher.minter()` read-back from Phase 7 on correct grounds (`ATokenDispatcherV2._minter` is `internal` with no accessor). It substitutes the claim: *"Phase 8's mints verify it MORE strongly than a read-back would… a dispatcher whose minter was not set reverts on the first mint through its index, which all three donor-path probes exercise."*

**The concrete fact**: Phase 8 exercised **idx1, idx7 and idx4** — `_mintOnce(IDX_EYE)`, the inline pooler mint at `IDX_POOLER`, and `_mintOnce(IDX_RATCHET)`. It **never minted through idx2 or idx3**. Indices 2 (Uniboost SCX) and 3 (Uniboost FLX) are never exercised, so `newUniboostSCX.setMinter()` and `newUniboostFLX.setMinter()` have **neither a read-back (structurally impossible) nor a functional probe (absent)** — `setMinter` on two of the three Uniboosts is unverified. **Autonomous Decision 5 claims otherwise.** Fork evidence is explicit: idx2 and idx3 "NEVER EXERCISED".

**Faithfulness deviation (F-03)** — story line 1174, ticked: *"- [x] Phase 8 (PREVIEW only): mock `batchMint`s; a donation on each of the four donor paths with the pooler asserted **positively** via `BatchDonatedViaPSM` + a balance increase; …"* — "a donation on each of the four donor paths" is ticked; **three** run. The tick is unearned on its own terms, independently of how many paths "four" was meant to enumerate. Second-order note (preserved): *this drift survived the review that caught two others, on a story whose own checklist line 1161 demands "every comment traceable to pinned source"*.

**Impact**: None. If the unverified `setMinter` were ever wrong, the symptom would be post-cutover mints on indices 2/3 reverting `"ATokenDispatcherV2: caller is not minter"` — an availability symptom, discovered by a user rather than by the runbook, and fixable by an owner call. Likelihood is very low: all three Uniboosts are configured by the same `_swapUniboost` body in one `ub_<label>_config` block, so a `setMinter` omission on SCX/FLX but not EYE is not a realistic failure mode.

**Recommendation** (verbatim):

> Add `_mintOnce(actor, IDX_SCX, USDC, "Uniboost SCX (idx 2)")` and `_mintOnce(actor, IDX_FLX, USDC, "Uniboost FLX (idx 3)")` to `_probeDonorPaths` - two lines, using the helper that already exists, closing the gap and making Autonomous Decision 5's argument true as written. Simultaneously correct the code comment at `:1575-1580` and the Autonomous Decision text to say 'all five donor-path probes' once they exist, or to name the covered indices explicitly if they are not added.

**Kept separate from L-05** despite the shared comment-drift symptom — see L-05 for the rejected-merge rationale.

---

## QA / Hardening Notes

### [Q-01] The knowingly-accepted mint-UI breakage has no tracked remediation story, so the cutover ships an indefinite outage <!-- id: pps22q1 -->

**Severity**: QA (auditor proposed Low; downgraded — a precision correction, **not** a suppression)
**Fingerprint**: `909e6d267d4c99d5dc44600c4a96700b6f3334005840ac3b24ca50530817398e`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-12 (classifier CLASS-010)
**Location**: `lib/phoenix-phase-2-staging/package.json#L282` — the `//promotion-ready` annotation

**Description**: Whitelisting three reward tokens makes `batchMint`'s `minRewards` array length-3, and `getNudgeTokens()` reorders on removal (swap-and-pop), so callers must re-fetch immediately before every call. The `//promotion-ready` annotation and the script both record that *"the live mint UI is BROKEN until a phlimbo-ui story ships a 3-element array plus a getNudgeTokens() re-fetch"*. Story line 1447 states: *"The `phlimbo-ui` follow-up story … is **still unraised**. The live mint UI breaks the moment this broadcasts. Tracked as a comment at `story-dependencies.md:218`."* A comment in a dependencies file is not a raised story, so the outage is **unbounded in duration rather than sequenced**.

**Law-3 split**: the outage itself is a knowing, documented, priced owner decision with an OBVIOUS consequence — the owner would not be surprised — so the **decision** is trusted and out of scope. Only the **tracking** is reportable: a same-day-or-never outage recorded solely inside a `package.json` comment and a comment at `story-dependencies.md:218` can silently persist. Explicitly **NOT** closed under the "reckless admin mistakes" known-invalid rule — nobody is acting recklessly and nothing is being second-guessed. The sanitizer's candour note (a reasonable triager could legitimately close this on Law 3) is preserved so the human decides deliberately rather than inheriting the decision from a filter.

**Impact**: None on-chain. Contracts are correct; direct and multicall callers are unaffected. User-facing mint availability via the UI is lost from the moment of broadcast until an unscheduled follow-up ships. The breakage is certain and deterministic on broadcast — and intended.

**Recommendation** (verbatim):

> Raise the phlimbo-ui story before the Ledger session and sequence it as a same-day follow-up, so the outage window is a known number of hours rather than open-ended. If the cutover must go first, state the expected remediation date in the completion summary. Related: the two-coexisting-batch-minter-ABIs trap (legacy 3-arg on the four per-token minters, 4-arg multi-token on the shared one) belongs in that story's scope explicitly, since a UI that re-fetches `getNudgeTokens()` against a legacy minter will revert - that view does not exist there.
>
> CLASSIFIER ADDENDUM: cite ledger Q-04 (a807cc7a) in that story's scope so the script-side legacy scalar-`minReward` call sites and the UI-side 3-element-array surface are covered by one follow-up rather than two.

**Class sibling — COMPLEMENTARY HALVES OF ONE STORY-072 ABI BREAK, NOT DUPLICATES**: ledger `a807cc7a66991388e22dfa8a50ec1bddeb4f491ad5efdd82bc861028f81a9321` (**Q-04**, entry point `dev`, run-21, qa/open, rootCause `IncompletePreflightCallSiteSweep`). Q-04 covers the **script side** — call sites that still bind the legacy scalar-`minReward` signature and *"silently break on the story-072 cutover"*. Q-01 covers the **UI side** — the 3-element array plus the `getNudgeTokens()` re-fetch. Q-04's ledger note already states it is *"OWNER-VISIBLE and explicitly NOT bundled away (Law 2)"*. **Action**: Q-01's recommendation (scope the two-coexisting-ABI trap into the phlimbo-ui story) should cite Q-04 so the follow-up story covers both surfaces at once. Ledger entry `a807cc7a` was **not modified** by this run.

**Not merged with L-04**, though both end in `batchMint` availability: an unverified token entering the whitelist (contract-input risk) vs a client that cannot construct the resulting 3-element `minRewards` array (compatibility schedule). Shared endpoint, unrelated causes.

---

### [Q-02] The Phase 6 budget top-up approval lacks the before/after allowance assertions that guard every other approval in the script <!-- id: pps22q2 -->

**Severity**: QA (auditor proposed Low; downgraded because the finding's own impact analysis establishes there is no live bug)
**Fingerprint**: `b3caa280e070dbb4aa16956cce8598a7025e7ad76346d412cf65eb8efca943ff`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-07 (classifier CLASS-011)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1409-L1410` — `_migrateStaker`

**Description**: `IERC20(PHUSD).approve(v2, movable); NFTStakerDepletionV2(v2).topUp(movable);` at `:1409-1410` has no pre-check that the existing allowance is zero and no post-check that it returned to zero. The script's own USDC donation helper `_collectNudgeFromOwner` does both and states why: *"The allowance is fully consumed inside `collectNudge`, so it always returns to 0 - asserted here so a stale approval can never silently accumulate"* (`:742-744`, `:753`). Three separate `approve` calls run across the three stakers with no such guard. For value to move, `topUp` would have to under-pull AND the spender would have to later draw the residue — but `topUp` is `onlyOwner` on a contract deployed moments earlier in the same script, and the fork run showed exact consumption (swept 4.6326 / 708.8243 / 51.9974 phUSD with V2 balances matching).

**Not suppressed under the tool-noise / style carve-out** — that basis was considered and **REJECTED**. The defect is an asymmetry against a convention the same file establishes and documents 660 lines earlier, which no automated tool can surface. Downgrading the tier is not the same as accepting the carve-out.

**Impact**: None demonstrated. The theoretical residual is a leftover phUSD allowance from the OWNER EOA to a V2 staker — **BOUNDED at `movable`, not infinite** — if `topUp` ever pulled less than approved. Likelihood is nil on current code: there is no state in which value moves.

**Recommendation** (verbatim):

> Mirror the USDC helper exactly: `require(IERC20(PHUSD).allowance(OWNER, v2) == 0, "stale V2 topUp allowance");` before, `forceApprove` (or `approve`) in the middle, and `require(IERC20(PHUSD).allowance(OWNER, v2) == 0, "topUp left allowance behind");` after. Three lines per staker, and it makes the script's approval hygiene uniform - which is the actual value, since a reader currently cannot tell whether the asymmetry is deliberate.

**Not merged with Q-03**, though both concern approval hygiene: missing zero-allowance bookends on a **bounded** approval (Phase 6, phUSD) vs an **unbounded** approval whose magnitude is hardcoded instead of mirrored (Phase 5, SYA/phlimbo). Different phases, tokens, defects and fixes.

---

### [Q-03] The new StableYieldAccumulator is given an unbounded phlimbo approval that is hardcoded rather than mirrored from the retiring instance <!-- id: pps22q3 -->

**Severity**: QA (agrees with the auditor's proposed bucket; this pass makes the severity field consistent with it)
**Fingerprint**: `050428e852c4e27de20a44cbec65bb1b764b15af73bb5fa987e5b2acb871a8bf`
**Entry point**: `promotion-ready:broadcast`
**Origin**: PR-08 (classifier CLASS-012)
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1187` — `_phase5_stableYieldAccumulator`

**Description**: Phase 5 mirrors the retiring accumulator's configuration field by field — `rewardToken`, `phlimbo`, `nftMinter`, `discountRate`, three `tokenConfigs`, three strategies, `nudgeSplit` — each read live off `OLD_SYA`. **One value is not mirrored**: `sya.approvePhlimbo(type(uint256).max)` is a hardcoded infinite approval. The inline comment justifies the mechanism ("collectReward pulls via transferFrom") but not the magnitude. The project's own `CLAUDE.md` Configuration Safety section names caps and unbounded allowances as parameters requiring explicit justification rather than a default.

Retained rather than dropped: it is anchored to a **written in-repo standard**, not auditor preference; the fix is one sentence; and Phase 5 mirrors **eleven** values off the live retiring instance while hardcoding exactly this one. Under Law 1, keep — dropping it would remove the only record that the discipline break was noticed. **Cached known-issue #10 ("Admin trust assumptions…") was considered and rejected as authority**: it has no suppression standing in this project (the declared known-issues file does not exist) and would fail on the merits anyway, since a discipline break against the repo's own written standard is not an admin-trust concession.

**Impact**: None. PhlimboV2 is a first-party contract and an infinite approval to it is the conventional pattern for a pull-based reward collector. Likelihood nil — no impact path exists on current code. A future repoint of the phlimbo dependency would be required for the unbounded magnitude to matter.

**Recommendation** (verbatim):

> Either read the retiring instance's existing phlimbo allowance and mirror it, or keep `type(uint256).max` and extend the comment to record why unbounded is correct here (PhlimboV2 is first-party, the approval is scoped to one spender, and `collectReward` is the only consumer) so the choice reads as deliberate rather than defaulted.

---

## Cross-run items carried forward for the human

These are process items, not contract findings, reproduced here so they reach a document a human reads. They are **not** assigned C4 severities.

- **MR-22-01** (ledger watch-note) — Cross-run recall gap: the `deploymentStatus:"completed"`-in-the-local-pass pattern shipped on two MAINNET cutover scripts (`DeployMainnetNudgeRatchet.s.sol:811`, `DeployMainnetUniboostCutover.s.sol:802`) that were each script-audited (run-19, run-20), and **neither audit filed it**. First filed only in run-21 as `1e8cc0dc`. **Four of the six `_writeProgressFileWithStatus` users remain unexamined.** This is a defect in the audit MODEL, not in the code; its code-side realisation for this entry point is **L-03**.
- **MR-22-02** — run-22's real-Kendu fork probe supplies the evidence ledger L-09 (`acabc052`) declared missing. **Human re-weigh of L-09 only; do NOT auto-close.** Correct the stale "line 514" citation to checklist line 1154 when re-weighing (see L-04).
- **MR-22-03** — Severity dependency: if fix-pending `a753907e` (M-01, `dev`) lands, **L-04's** blast radius narrows from "all reward tokens" to "the tainted token only". Re-weigh L-04 downward then (Low → QA), and check the landed fix against the INCOMPLETE FIX rule.

## Operator pre-broadcast summary

> If only one thing is done before the Ledger session, **tick story-072 checklist lines 1195 and 1197 as mandatory blocking steps.** That single zero-code action discharges most of M-01's impact and removes the sole reason **L-01** could escalate to Medium.

## Related artifacts

- `reports/phoenix-phase-2-staging/22/submissions/M-01.md` — the run's single Medium. **Read the L-02 fix-ordering constraint before implementing it.**
- `reports/phoenix-phase-2-staging/22/submissions/spec-conformance.md` — F-01, **F-02 (= L-05)**, **F-03 (= L-08)**. The QA bundle does not satisfy that routing.
- `reports/phoenix-phase-2-staging/22/script-audits/promotion-ready-broadcast/` — closure manifest, side effects, dedup and classification records.
