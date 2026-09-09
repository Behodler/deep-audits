# QA Report — phoenix-phase-2-staging @ `c4396b19aea6b7b09573ba90e2e65ca9293d20a1`

**Project**: `phoenix-phase-2-staging`
**Commit**: `c4396b19aea6b7b09573ba90e2e65ca9293d20a1` (`c4396b1`)
**Branch**: `master`
**Run**: `reports/phoenix-phase-2-staging/23` (run-23)
**Audit type**: **script audit** (`/audit-script`) of the **story-072 promotion-ready suite** — *not* a full contract scan of the submodule.
**Entry points covered**: `promotion-ready:broadcast` and `promotion-ready:verify`
**Verification mode**: mainnet-fork PREVIEW execution (`promotion-ready:dry`), **fork pin block 25670926**
**Story**: `story-072` — mainnet NudgeStreamer cutover, multi-token BatchMinter, staker V2 migration
(`~/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/072-mainnet-nudgestreamer-cutover-multitoken-batchminter-staker-v2-migration.md`)

## Severity distribution

| Severity | Count |
|----------|-------|
| High | 0 |
| Medium | 0 |
| Low | 5 |
| QA | 1 |
| Centralization | 0 |
| **Total (this bundle)** | **6** |

Because this run produced **0 High and 0 Medium**, there are **no individual `submissions/<label>.md` files for new findings** — every new finding of this run lives in this bundle.

**Entry-point split**: `L-01`, `L-02`, `L-04`, `L-05` are `promotion-ready:broadcast`; **`L-03` and `Q-01` are `promotion-ready:verify`**.

---

## Reader's notes (read before triage)

### 1. L-05 was walked back from Medium to Low — the retracted claims must not be reintroduced

`L-05` (`f59e177a97c8842940bc0ccf4b3e28be506074e9e85fb7fed3a52aec87866bf2`) was filed during this run as a **Medium (M-01)** and was **walked back to Low** after adversarial PoC validation refuted its premise. Its fingerprint is **unchanged** (severity is not a fingerprint input), so the ledger join still holds, and `M-01` is retired in its `labelHistory`.

Two claims are **retracted and must never be restated**:

- **"Mid-sequence / partially-applied cutover."** FALSE. `forge script` executes `run()` as **one local EVM frame** and dispatches only if that frame returns; a later revert unwinds the entire frame — zero transactions signed, zero mined, non-zero exit, `&&` chain halted. The failure is an **atomic pre-broadcast abort**.
- **"L-07 is atomic, L-05 is mid-sequence" as the reason the two were not merged.** FALSE. **Both** are atomic pre-broadcast. The corrected basis for keeping them separate is in L-05's section.

The **`M-01.md` in this directory is *not* this finding.** `submissions/M-01-C1.md` is the **carryover** of run-22's Medium M-01 (`2c53e944caee2e74…`), a different issue entirely.

### 2. Superseded stage artifacts must not be quoted

`script-audits/promotion-ready-broadcast/{candidate,sanitized,classified}-findings.json` are retained as the historical record of what each pipeline stage emitted. They still carry the **Medium framing** and the **"2 / 156 / 13 users"** phrasing. They are **superseded** by the finding records under `findings/` and by this bundle, and must not be quoted downstream. (`intent.md:19` and `side-effects.json:66` are *correct* — they say **units**, not users.)

### 3. Carryover — 12 run-22 findings remain open and are **not** restated here

This run's `L-01…L-05` / `Q-01` sequence covers **only this run's new findings**. Run-22's still-open findings are carried separately and must be read there, not re-derived from this bundle:

- `submissions/M-01-C1.md` — run-22's open **Medium** M-01 (`2c53e944caee2e74…`).
- `submissions/carryover/qa-report-22.md` — run-22's **11 open QA/Low entries** (L-01…L-08, Q-01…Q-03), all still `open`, none pruned.

Together: **12 open run-22 findings**. Numbering is deliberately not adjusted around them — a run-22 `L-04` and this run's `L-04` are different findings, and each section below carries the fingerprint that disambiguates them.

### 4. `KI-23-01` — known-issues suppression was BLOCKED this run (human action required)

`lib/phoenix-phase-2-staging/known-issues.md` is **absent at `c4396b1`**, although the registry claims **11 entries extracted 2026-01-09**. The sanitizer therefore could **not** evaluate known-issues suppression, and **nothing in this bundle was suppressed on KI grounds**. Consequences, both of which cut toward over-reporting rather than under-reporting (correct under Law 1, but it means triage carries the load):

- A finding here may duplicate a documented known issue and would not have been caught.
- Conversely, the 11 cached KI entries are **not re-derivable from source at this commit**, so they cannot be used to suppress anything until re-extracted.

**Action:** restore or re-extract `known-issues.md`, then re-run sanitization against this bundle. Track as **`KI-23-01`**.

### 5. Automated SAST/gas appendix (4naly3er) — **not produced this run**

4naly3er was run against the audited slice (`script/DeployMainnetPromotionReady.s.sol`, `script/VerifyPromotionReady.s.sol`) and **failed to produce a report**. Two attempts:

1. `basePath` = submodule root → **`@forge-std/Script.sol import not found`**. The project declares its remappings **inline in `foundry.toml`** and ships **no `remappings.txt`**, which is the only remapping source 4naly3er's import resolver reads.
2. `basePath` = the writable `workspace/` clone at the same commit, with a `remappings.txt` generated from `foundry.toml` (52 entries) → imports resolved, but solc then failed both files with:
   - `TypeError: Invalid implicit conversion from contract ITokenMinterV2 to contract ITokenMinterV2 requested.`
   - `TypeError: Invalid implicit conversion from contract IUniboostMintDebtHook to contract IUniboostMintDebtHook requested.`

Both are the **diamond-dependency duplicate-interface** condition that `foundry.toml`'s own remapping canonicalization block exists to solve: 4naly3er's longest-prefix resolver plus its path-dedup heuristic resolves the same interface to **two physical files**, so `X` is not implicitly convertible to `X`. `forge build` (via `foundry.toml`, `via_ir = true`) compiles the same files without complaint — this is a **tool-integration gap, not a code defect**, and it is recorded here rather than silently dropped. The temporary `remappings.txt` was removed from the workspace afterwards; no file in `lib/` was touched.

**Net effect:** this bundle has **no automated bot-report baseline**. Every finding below is manual and fork-verified. A Low/QA issue of the kind 4naly3er surfaces (gas, NC, style) may be missing — acceptable here, since the audited artifacts are one-shot deployment scripts where gas and NC findings carry little weight, but the gap is real. Note also that 4naly3er over a `forge script` mega-file would in any case be low-signal.

---

# Low Risk Findings

### [L-01] Phase 8's `_probePoolerDonation` — the mechanised form of story-072 checklist line 1197 — is reachable only under `if (isPreview)`, so the broadcast path never runs it <!-- id: pps23l1 -->

**Fingerprint**: `2212c1c4e8c8cd2271cc3c0c5c7e9180d0e2597cfbbdd97631431724e899525d`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low · **Faithfulness deviation** (story-072, checklist line 1197) · plausible · not a regression
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L439`](../../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L439) — `_phase8_previewSmokeTests`, reached from `run()` at `:439` via `if (isPreview)`

**Description**

`BalancerPoolerV2._psmDonate` failures are swallowed by `try/catch`, so a green index-4 mint transaction is **not** evidence that the donation leg works — the exact failure mode story-072 checklist line 1197 exists to catch. That line is a **post-broadcast HUMAN step**, is **UNTICKED**, and story-075's `:verify` explicitly declines to discharge it (`VerifyPromotionReady.s.sol:85-86` prints *"STILL A HUMAN STEP … line 1197"*). Nothing in the npm chain enforces that the human step ever happens.

Meanwhile Phase 8's `_probePoolerDonation` performs **exactly this assertion** and **PASSED** in this audit's `:dry` run (`BatchDonatedViaPSM = true`, `DonationSkipped = false`, USDC stream-buffer delta `2485691`) — but Phase 8 is gated `if (isPreview)`, so it never runs on the broadcast path. The same preview-only gating is the only thing that exercises `BALANCER_ROUTER` and `SUSDS_IS_FIRST`, which are `private immutable` with no getter and therefore unassertable by Phase 0 or by `:verify`.

**Impact**

None directly. If `_psmDonate` were to fail after the cutover, the `try/catch` swallows it and the index-4 mint still succeeds; the consequence is a donation that should have reached the batch minter's nudge pot being skipped. Per this project's standing position, those pots are funded by **externally-derived yield on protocol-owned capital**, so an under-delivered donation is an allocation/marketing miss, **not** an economic loss and **not** a value leak. The real impact is on **detection**: the wiring assertions cannot see it, because the wiring is in fact *correct*, so a fully green `:verify` run coexists with a silently non-donating pooler.

Likelihood is low — the donation leg was empirically exercised **green** on the live fork at this exact commit, so the pooler is not broken today. The residual is that no automated gate would notice if it broke.

**Evidence**: `side-effects.json → events[0]`, `externalCalls[4]`, `leadsResolution[6]`; `scratchpad/dry.log:282` (*"pooler: BatchDonatedViaPSM / DonationSkipped: true false"*); source `run() :439`; `VerifyPromotionReady.s.sol:85-86`.

**Recommended Mitigation**

Add a `promotion-ready:verify-mint` npm key that runs the existing Phase 8 pooler probe in `PREVIEW_MODE` against **live post-cutover state**: prank `OWNER`, trigger one index-4 mint, and `require` that `BatchDonatedViaPSM` fired and `DonationSkipped` did not. It needs no broadcast and no signing, so it chains after `:verify` with the same `&&` discipline, converting line 1197 from an unenforced human step into a **fail-closed gate**. Until that ships, tick line 1197 explicitly before disconnecting the Ledger.

Secondary: expose `BALANCER_ROUTER` and `SUSDS_IS_FIRST` via public getters so Phase 0 and `:verify` can assert them at all.

**Cross-references**

- **Faithfulness**: routed to `submissions/spec-conformance.md` as **F-01-072**. See that document for the story-072 grading; it is not duplicated here.
- **Class sibling — NOT merged**: run-22 ledger entry **L-04** (`e6f32c475e7a9213fd03495f3aa8ad326e8928fb91d9be5403df48a2cd57986a`, Low, open). Same `BlockingProbeGatedToPreviewOnly` family, but L-04's probe is a **preflight that must move EARLIER** on the broadcast path (ahead of the Kendu whitelist write); this one is a **post-mint verification that must move LATER**, into a post-broadcast read-only leg. Neither fix delivers the other. Flag **L-04-23-01**: L-04's own probe ran green this session (`sent == received == credited == 1e24`), which **de-risks L-04 without fixing it** — that re-weighing belongs at `/ledger`, not to this scan.

---

### [L-02] Phase 0's expected-value literal is hardcoded into a control the runbook presents as a manual human check, and is both stale and structurally incomplete <!-- id: pps23l2 -->

**Fingerprint**: `d99738d3a05c44aa0171efb976164815c8dec5c8d75ab5762d0cfd894b364c29`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low · **Faithfulness deviation** (story-072, checklist line 1195) · **Law-3 footgun (in scope)** · plausible
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L544-L558`](../../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L544) — `_phase0_preconditions`

**Description**

story-072 checklist line 1195 — one of only two unticked items and, alongside line 1197, the entire compensating human control — instructs the operator to confirm *"the new pooler holds the full 16,338.8190 BPT"* and *"the rescued ~349 USDC sits in the streamer buffer"*. **Both figures are stale.**

This audit's live `:dry` run measured **16,867.5264 BPT** (`16867526417628291567945` wei) and a final stream buffer of **530.761796 USDC**, decomposing as `99.224124` (old batch minter) + `51.537672` (UniboostSCX residual prime) + `380.000000` (DelayRelease) — a **third component the checklist never names at all**.

The **code is unaffected**: Phase 0 derives the BPT baseline live (`side-effects.json` confirms `bptAtPhase0` equals the live figure), no assertion references the stale number, and the `16,338.819e18` literal survives only as a self-contained fixture in `test/BptBaselinePersistence.t.sol:96`. The defect is confined to the **manual control**.

**Impact**

None directly — and that is load-bearing for the grade. The degraded asset is a **compensating human control**: line 1195, one of the two unticked rows, and the row the operator is meant to use for the post-cutover state that `:verify` cannot mechanise.

Two branches follow, and the dangerous one is the second:

- **Benign (certain to occur)**: the operator treats the mismatch as a real failure and raises an alarm on a healthy cutover. Because line 1195 is a **post-broadcast** row, this causes confusion and delay — **never** a partial application.
- **Dangerous (needs a coincidence)**: the operator reconciles the mismatch as *"the checklist numbers are always a bit off"*, and the control is now calibrated to be waved through — so a **genuine** BPT shortfall or a missing buffer component on the day reads exactly like the noise they have been trained to ignore.

The BPT half is partially backstopped (`:verify` consumes story-074's persisted baseline and re-runs the Phase 7 conservation assertion). The **USDC-buffer half is not backstopped by anything** — and that is precisely the half whose decomposition is structurally incomplete.

**Evidence**: `side-effects.json → leadsResolution[3]`, `preconditionResults` (`bptAtPhase0 = 16867526417628291567945`), `stateWrites` (`99224124 + 51537672 + 380000000 = 530761796`); `scratchpad/dry.log:117-124`, `:156`, `:184-185`, `:199`.

**Recommended Mitigation**

Stop hardcoding balances in the human checklist. Rewrite line 1195 to read: *"confirm the new pooler's BPT equals the `BPT cutover baseline` printed by Phase 0 of the immediately preceding `:dry` run, and the streamer buffer equals its final `collectNudge -> stream buffer now` figure"* — the script already prints both, under a `--- stranded value (live) ---` header built for exactly this purpose.

Additionally, have `_printSummary()` emit a copy-paste **"POST-BROADCAST HUMAN CHECKLIST"** block with the live-derived expected values filled in, so the operator compares against measurements taken **minutes** earlier rather than prose written **weeks** earlier.

When rewriting, enumerate **all three** buffer components (old batch minter / DelayRelease / UniboostSCX residual prime) or, better, quote only the **total** the script prints — a control that names two of three sources will drift again the moment a fourth donor appears.

**Cross-references**

- **Faithfulness**: routed to `submissions/spec-conformance.md` as **F-02-072**. The deviation is in the **story text**, not the implementation — the code is faithful; the acceptance criterion is not accurate. Details there, not duplicated here.
- **Collapse refused (carried)**: L-01 and L-02 share the story-072 checklist as an artefact but were confirmed distinct by the deduplicator — *enforceable-but-unenforced* (fails silent) versus *stated-but-wrong* (fails noisy, then numb), with non-overlapping fixes in both directions.

---

### [L-03] `VerifyPromotionReady._loadAndValidateProgressFile` trusts a progress file whose write-side entries are stamped during forge's LOCAL pass <!-- id: pps23l3 -->

**Fingerprint**: `5c6d2c9e3b9806b89ca5484e3af8dab3f5ee9aa7240e93b526f0808b324d8818`
**Entry point**: **`promotion-ready:verify`**
**Severity**: Low · not a faithfulness deviation · plausible · **7th member of the `ForgeLocalPassPrecedesBroadcast` family** (MR-22-01 recall gap)
**Location**: [`lib/phoenix-phase-2-staging/script/VerifyPromotionReady.s.sol#L126-L131`](../../../../lib/phoenix-phase-2-staging/script/VerifyPromotionReady.s.sol#L126) — `_loadAndValidateProgressFile`

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

**Not an `incompleteFixOf` run-22 M-01**, and not graded as one: that fix's actual detection mechanism — `_phase7_wiringAssertions()` against live chain state — works and fires.

**Evidence**: `side-effects.json → fixVerification.run22_M01.residuals`; source `DeployMainnetPromotionReady.s.sol:2161`, `:2169`, `:435`; `VerifyPromotionReady.s.sol:126-131`; `patch-mainnet-addresses-promotion-ready.js:122`.

**Recommended Mitigation**

Make the gate read something only **dispatch** can produce.

- **Preferred**: have the verifier require `deploymentStatus == "completed"` **and** independently confirm on-chain code at the recorded `NudgeStreamer` and `BatchNFTMinter` addresses (`addr.code.length > 0`). That costs two staticcalls and turns the guard honest, because **bytecode at a recorded address cannot exist unless a transaction actually landed**.
- **Alternative**: drop the misleading `require` entirely and let Phase 7 be the sole authority, with a comment explaining why a pre-dispatch record check is impossible.
- **Do NOT** leave the current wording in place with a comment — **the message is what misleads**.

**Cross-references**

- **Class sibling — NOT a duplicate**: run-22 ledger entry **L-03** (`ea648ec5eab0c92624bed78b303577423967385a48df8738b68153c50cba9324`, Low, open). That entry's gate reads the `deploymentStatus` **string** from JS with an off-chain blast radius; **this** finding establishes that the verifier never reads `deploymentStatus` **at all** and gates on record **presence** instead. The two gates share no input and neither accepted fix touches the other.
  **Sequencing warning for the fix author**: the *preferred* mitigation above **would** start reading `deploymentStatus`. If run-22 L-03's accepted fix (restate the header honestly) lands first, fix **L-03's header semantics before** making this verifier depend on that string.
- **Recall gap (carried verbatim)**: MR-22-01 counted **six** users of the `_writeProgressFileWithStatus` local-pass idiom across the mainnet cutover scripts. **This is the seventh, and the first inside a contract introduced specifically to close a verification gap.** Recorded so the gap is not narrowed by omission — **it widened.**

---

### [L-04] The persisted `baselines.bptAtCutover` carries no provenance binding, so a hand-edited digit is accepted as the write-once baseline <!-- id: pps23l4 -->

**Fingerprint**: `80a741a27fe0fded541073aa2e3c4e8d37a6dbeff5920e0ff64b0e71273aac1a`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low · **Law-3 footgun (in scope)** · plausibility: *implausible-but-cheap-to-close* · **residual introduced by the fix for run-22 L-02** (`4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42`)
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L2013-L2020`](../../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L2013) — `_parseBaselines` (related: `:549`, `:564`, `:571`; `VerifyPromotionReady.s.sol:147-154`)

**Description**

Story 074's rails check that `baselines.bptAtCutover` is **present** (`:564`) and **non-zero** (`:571`, and again in the verifier at `:151`). They never check that it is the **right value**. There is no `chainId`, block-number, or run binding on the `baselines` object, and no checksum. `_parseBaselines` accepts any non-zero decimal string.

On a **resume** leg the live read of the emptied old pooler is `0`, so `bptAtPhase0 = max(persisted, 0) = persisted` — the monotonic floor cannot rescue the value; **the corrupted number *is* the floor**. A baseline hand-edited downward to any smaller non-zero value is adopted verbatim, and Phase 7's conservation assertion `balanceOf(newPooler) >= bptAtPhase0` (`:1725`) then passes against a lowered bar.

The `//promotion-ready:resume` doc key's rule (*"TRIM THE contracts BLOCK ONLY, NEVER the top-level baselines block"*) is enforced **for deletion** by two independent aborts, but is **documentation-only for the value**. Note that a resume leg is exactly where the runbook **mandates** hand-editing the progress file — the operator's hand is already in the file by design.

**Impact**

Indirect and **detection-only**. The BPT position itself (16,867.5264 BPT — the largest single item in the cutover) is **moved by code, not by the baseline**; the baseline only decides how large a shortfall Phase 7 will notice. A downward-corrupted baseline under-detects a shortfall **by exactly the delta**. No value is moved, lost, or made unavailable by this finding alone.

Three rails hold it down, and the grading says so plainly rather than dressing it up: the corruption needs an operator slip **inside a block flagged do-not-touch** (and not the trimming slip the runbook actually warns about, which is already caught); it only weakens **detection**; and it needs an **independent real shortfall** to coincide before anything is missed.

**Explicitly NOT inflated on story-074's conditional trigger.** Story-074 states *"weakening any rail re-classifies L-02 as Medium"*. **No rail was weakened** — four were added and one was tightened — so that trigger does **not** fire and was not used.

**Evidence**: `side-effects.json → fixVerification.run22_L02.adversarialProbes` (the two `covered: false` / `partial` entries); source `:2013-2020`, `:549`, `:564`, `:571`; `VerifyPromotionReady.s.sol:147-154`.

**Recommended Mitigation**

Emit a sibling `baselines.bptAtCutoverBlock` (decimal string, written **atomically** with the value) and have **both** Phase 0 **and** the verifier require it is non-zero and `<= block.number`. One key plus two `require`s binds the value to a block, so a hand-mangled figure no longer travels alone.

**Cheaper alternative** if that is not worth the change: log `baselines.bptAtCutover` in human units at the top of **every** leg and require the operator confirm it against the immediately preceding `:dry` run's Phase 0 `--- stranded value (live) ---` block. **Prefer the first** — the second re-introduces exactly the human-comparison weakness that **L-02** (this run) documents.

**Triage note**

This is a **residual introduced by a fix** — the pattern this repo treats as more dangerous than an unfixed bug, because it reads as done. That shape justifies reporting it and justifies the cheap fix; it does **not** justify a Medium, because the fix genuinely did what the story specified. It was retained through dedup and sanitization on Law-1 recall grounds with the auditor's own *"filed for recall, not because it is likely"* preserved. Triage may reasonably decide to carry it; that decision belongs at `/ledger`.

**Cross-reference**: run-22 **L-02** (`4fd1642310fda0d3…`) remains `open` with `fixed` **proposed but not applied** — see `submissions/carryover/qa-report-22.md`. Read this finding before applying that status.

---

### [L-05] Phase 6 never asserts the snapshot describes the same staker addresses Phase 0 checks: no `.address`/`.chainId` provenance probe, and `resolveAddress()` accepts `0x0` <!-- id: pps23l5 -->

**Fingerprint**: `f59e177a97c8842940bc0ccf4b3e28be506074e9e85fb7fed3a52aec87866bf2`
**Entry point**: `promotion-ready:broadcast`
**Severity**: **Low** — **walked back from Medium** on 2026-08-03 after adversarial PoC validation refuted the mid-sequence premise. Fingerprint **unchanged** (severity is not a fingerprint input); the ledger entry stays joinable. Retired label: `M-01` (this run).
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1599-L1601`](../../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1599) — `_loadSnapshotUsers` (guards: `:1550`; post-migrate `:1553-1554`; Phase 7 backstop `:1697-1699`)

**Description**

`_loadSnapshotUsers` reads **only** `.stakers.<key>.users` from `scripts/snapshots/depletion-stakers-latest.json`. The snapshot file **does** record `.stakers.<key>.address` (verified: all three currently equal `V1_STAKER_EYE` / `SCX` / `FLX` exactly) and `.chainId` — but the script never cross-checks the address against its own constants, never checks `blockNumber` for staleness, and never checks the file exists at all before Phases 1-5 are queued.

Upstream, `scripts/snapshot-depletion-stakers.js:98-106` resolves those addresses by regex over `server/deployments/mainnet-addresses.ts`. The regex `(0x[0-9a-fA-F]{40})` **accepts a `0x000…0` "not deployed" placeholder as a valid match** — the stale-trap pattern already realized on this project, where that file has previously carried zero placeholders for **live, funded** contracts.

**Impact — read carefully; the original framing was wrong**

**No assets are stolen, no user stake is lost, and NO partially-applied cutover occurs.** The failure is an **ATOMIC PRE-BROADCAST ABORT**: `forge` runs `run()` as a **single local EVM frame** before dispatching anything, so a revert at `:1550` unwinds Phases 1-5 in full — **zero transactions signed, zero mined** — and forge's non-zero exit halts the `&&` chain in `package.json:288`, so the patch and verify legs never run.

What remains is a **precondition-hygiene** defect on a one-shot, hardware-signed mainnet cutover: Phase 6 never asserts that the snapshot targeted the same staker addresses Phase 0 asserts on. A mis-resolved snapshot is therefore caught **late** and only **incidentally** — by the empty-user-list guard at `:1550`, which fires on the **symptom** (an empty list) rather than the **cause** (a wrong address) — instead of by an explicit Phase 0 precondition that would name the actual problem. The operator cost is a late, mis-attributed abort and a re-run, not a broken protocol.

**Causal inertness — disclosed, not buried.** The address mismatch is **causally inert on its own**. `_loadSnapshotUsers` (`:1599-1601`) reads only `.users` and never `.address`, so **corrupting `.address` alone reverts nothing** — a probe that did exactly that completed the run. Only an **empty** user list fires `:1550`, and the PoC established that emptiness **by fixture construction**. The causal step *"mis-resolved address ⇒ empty/wrong user list"* was **asserted, never demonstrated**. This materially weakens the finding and is recorded here rather than omitted (Law 1: visible, not silent). The recommendation still stands on its own terms — an explicit provenance assertion plus a zero-address reject is cheap and closes a historically realized upstream hole — but the finding **may not be graded on a demonstrated causal chain, because none was demonstrated**.

**Scale, corrected**: the three `NFTStakerDepletion` instances hold **1 / 2 / 3 users** respectively (`UniboostStakerEYE` 1, `UniboostStakerSCX` 2, `UniboostStakerFLX` 3), verified directly from the snapshot file. The figures **2 / 156 / 13** that appear in superseded stage artifacts are **STAKE UNITS** from the migrate log, **not user counts** — do not restate them as users.

**Why Low, in the classifier's own terms**: the Medium rested entirely on *when* the guard fires — *"converting an atomic pre-broadcast abort into a mid-sequence revert IS the impact"*. That premise is empirically false: there is **no mid-sequence state on this script**. With the availability impact gone, what is left is a missing explicit precondition and a late, mis-attributed error message on a one-shot script — QA/Low: a state-handling issue with no asset risk and no availability impact. Not suppressed, because the recommendation is cheap, the upstream `resolveAddress()` zero-address hole is real and historically realized, and it shares a Phase 0 fix site with run-22 L-07.

**Refutation method (for the record)**: an independent probe ran `forge script` **without** `--broadcast`. Both broadcast-recorded actions were rolled back, forge exited 1, and nothing dispatched. `--skip-simulation` skips the **per-transaction pre-send check**, **not** the local pass. The guard's inputs (`users.length` from `vm.readFile`, `preTotal` from local forked state) are fully deterministic in the local pass, so `:1550` **always** fires pre-broadcast. This is the `ForgeLocalPassPrecedesBroadcast` family already on the ledger from run-22, whose semantics the Medium had inverted; the project's own `package.json:287` states the mechanism verbatim.

**Line-number corrections applied (carry these, do not revert them)**

- `:1681-1682` was originally cited as the fail-closed guard. **It is not.** At `c4396b1`, `:1680-1682` are Pauser-registry membership checks (`!Pauser(PAUSER).isRegistered(V1_STAKER_SCX / V1_STAKER_FLX / OLD_SYA)`), unrelated to the migration guard. That citation must appear nowhere.
- The correct Phase 6 guards are **`:1550`** (`require(users.length > 0 || preTotal == 0, "snapshot user list is empty but V1 still holds stake")`) and **`:1553-1554`** (post-migrate `require(old.totalStaked() == 0, …)` plus the conservation `require`). An intermediate correction citing `:1549` / `:1552-1553` was itself off by one — `:1549` is the `_loadSnapshotUsers(v2Key)` call site and `:1552` is the `migrate(users)` call, neither a guard. Re-verified by `grep -n` on the require strings at HEAD `c4396b1`.
- The Phase 7 backstop `:1697-1699` (*"V1 EYE / SCX / FLX still holds stake"*) is exact.
- **Retracted**: the sentence *"All corrected guards remain inside Phase 6 / Phase 7, which confirms the mid-sequence framing the Medium rests on."* Guard **placement inside `run()` is irrelevant**, because the whole of `run()` executes as one local EVM frame before any dispatch.

**PoC — supports a weaker claim only**

`workspace/phoenix-phase-2-staging/test/SnapshotAddressMismatchOrdering.t.sol` — **passing**, last run 2026-08-03. It is **AUDIT-AUTHORED and UNTRACKED in the upstream repo**; it must **never** be presented as an upstream project test, and it must **never** be presented as proving this finding's impact. It does not demonstrate a partially-applied cutover, because no such state exists in the real invocation.

What it actually supports:
- (a) the `:1550` guard exists, is fail-closed, and emits exactly `snapshot user list is empty but V1 still holds stake`;
- (b) `_loadSnapshotUsers` never reads `.address` (only `.users`);
- (c) **only under a counterfactual model** — where Phases 1-5 and Phase 6 are separate **top-level transactions** — does Phase 1-5 state survive the Phase 6 revert.

**Harness caveat**: the harness splits `run()` at the Phase 5 / Phase 6 boundary into two external entry points (its own header calls this *"a DEVIATION … forced by the EVM"*). That split has **no counterpart** in the real invocation, where `run()` is a single local frame. The counterfactual is the **entire source** of the harness's surviving state. The PoC is **re-scoped, not deleted** — it is a correct and useful artifact for (a)-(c).

**Evidence**: source `:1599-1601`; guard `:1550`; post-migrate guards `:1553-1554`; Phase 7 backstop `:1697-1699`; `package.json:287` (the project's own statement of the local-pass mechanism) and `:288` (the `&&` chain); `scripts/snapshot-depletion-stakers.js:98-106`; snapshot inspected at `scripts/snapshots/depletion-stakers-latest.json` (chainId 1, all three `.address` fields match the script constants, user counts 1 / 2 / 3).

**Recommended Mitigation**

Add a **Phase 0 snapshot-provenance probe**, before any mutation, requiring `.stakers.<key>.address == V1_STAKER_<X>` for all three stakers and `.chainId == 1`, and **rejecting the zero address**. Cost: three string comparisons on a file Phase 0 must open anyway.

Separately, harden `resolveAddress()` at `scripts/snapshot-depletion-stakers.js:98-106` to **reject `0x000…0` explicitly** rather than accepting it as a valid 40-hex match — that closes the realized upstream cause.

The benefit is **diagnostic, not availability**: the run already aborts safely and atomically, but it aborts on the symptom (*"user list is empty"*) rather than the cause (*"this snapshot is for a different address"*).

**Note for the fix author**: file-**existence** probing and `.blockNumber` **freshness** belong to open ledger entry **L-07** (`b28492ce…`) per SN-23-01, and should land in the **same Phase 0 block** so the operator implements one probe, not two.

**Cross-reference — run-22 L-07 (`b28492ce9719af2d7117f52fa3cc04138c7f1764ca6e1848da9ebf6de0d19685`), deliberately NOT merged**

- **The old discriminator is FALSE and is retracted**: *"L-07 is atomic pre-broadcast, this one is mid-sequence."* **Both are atomic pre-broadcast.** Do not restate the retracted version anywhere.
- **Corrected basis for separation — different root cause, different fix**: L-07 is **file absence / staleness with no Phase 0 probe** — the file is missing or old. **This entry is content provenance** — the file may exist and be perfectly fresh yet **name the wrong addresses**. Fixing L-07 (probe that the file exists and `.blockNumber` is fresh) does **not** fix this entry, and vice versa.
- **SN-23-01** stands as a **scope boundary** (this entry = address-set/provenance only; file-existence and `.blockNumber` freshness = L-07), but its *stated rationale* is superseded by the corrected basis above. Its **reopen triggers survive verbatim**: if L-07 is closed without its **full** recommendation landing, the ceded dimensions **must be re-filed** — closing it on a partial fix would silently drop both dimensions from every future scan.

---

# QA / Hardening Notes

### [Q-01] `_requireNoBroadcastFlag` asserts an invariant it structurally cannot check (cheatcode string-literal scan misses inherited mutating helpers) <!-- id: pps23q1 -->

**Fingerprint**: `5e2e125056eb91aef164c9626c81cef04a3c73a6bfb20e198582781b9bc84bac`
**Entry point**: **`promotion-ready:verify`**
**Severity**: QA — **deliberate downgrade from the auditor's Low**; see the review flag below. Plausibility: **latent**.
**Location**: [`lib/phoenix-phase-2-staging/script/VerifyPromotionReady.s.sol#L96-L98`](../../../../lib/phoenix-phase-2-staging/script/VerifyPromotionReady.s.sol#L96) — `_requireNoBroadcastFlag` (context `:89-98`; guard test `test/VerifyPromotionReadyGuards.t.sol:114-133`; `foundry.toml` `fs_permissions` read-write `./server/deployments`)

**Description**

Two compounding weaknesses in the verifier's safety story.

1. **`_requireNoBroadcastFlag()` is named for a check it cannot perform.** It only rejects `PREVIEW_MODE` (`:97`); its own NatSpec admits that **no cheatcode reports `--broadcast`**.
2. **The read-only guarantee is pinned by substring scanning, not by structure.** `VerifyPromotionReady is DeployMainnetPromotionReady is Script, StdCheats`, so the compiled artifact retains `StdCheats` and the read-write `./server/deployments` `fs_permissions` grant — while `test/VerifyPromotionReadyGuards.t.sol` pins read-only-ness with raw substring scans for cheatcode **literals only** (`startBroadcast`, `startPrank`, `vm.deal`, `vm.warp`, `forge-std/Test.sol`, `OLD_POOLER`). A future edit calling an **inherited mutating helper** — `_writeProgressFileWithStatus(...)` is the obvious one — contains none of those literals and would pass **every** current assertion, as would a live-read BPT fallback routed through a local variable or a differently-named constant instead of the literal `OLD_POOLER`.

**Impact**

**None today — and the "today" is verified, not assumed.** The verifier's complete call graph is `run -> _requireNoBroadcastFlag / _loadAndValidateProgressFile / _adoptPersistedBptBaseline / _phase7_wiringAssertions / _verifyMintAuthorityInvariance / _printSummary` — all view or storage-only. The closure-mapper independently confirmed that **every** phase function and **every** broadcast site in the inherited `DeployMainnetPromotionReady` is `internal` and **uncalled** from the verifier. The standalone run empirically mutated nothing (trace: `vm.envOr` plus a failed `vm.readFile`, then abort). A `:verify` run mistakenly given `--broadcast` is **inert**, because no broadcast context is ever opened.

So the **present-day** impact is **maintainer comprehension**: a maintainer reads `_requireNoBroadcastFlag()` and believes the verifier rejects `--broadcast`. It does not. Their mental model of what protects the read-only leg is wrong. The **latent** hazard (step 4 above) is reachable **only from code no one has written**.

**Why QA rather than Low**: C4 QA covers *"function incorrect as to spec, issues with comments"* — a guard function whose **name** asserts an invariant it cannot check is that category exactly. The substring-only guard test is a defence-in-depth weakness on a guarantee that currently holds **structurally** rather than by the test, and its harmful branch needs code that does not exist. C4 names *"speculation on future code without demonstrated root cause"* as invalid, so grading the latent branch as a live Low would be overstatement. The finding is nonetheless **retained and reportable** — a guard overstating its own coverage is not a style nit under this project's standing position on falsely-exhaustive self-certification.

**Evidence**: `side-effects.json → verifyLegStandalone`, `testHarnessAssessment`, `leadsResolution[0]` and `[1]`; source `VerifyPromotionReady.s.sol:89-98`; `test/VerifyPromotionReadyGuards.t.sol:114-133`; `foundry.toml` `fs_permissions` read-write `./server/deployments`.

**Recommended Mitigation**

Three parts, all cheap and all worth landing **before** the broadcast.

1. **Rename** `_requireNoBroadcastFlag` to `_requireNoPreviewMode` so the name matches the check, and **keep** the NatSpec paragraph explaining why the broadcast flag is unobservable — the explanation is good; only the name lies.
2. **Strengthen `test/VerifyPromotionReadyGuards.t.sol` from substring scanning to a call-graph assertion**: assert the verifier's source contains **no call, by name**, to any inherited mutating helper (`_writeProgressFileWithStatus`, `_trackDeployment`, `_trackConfig`, `_phase1_`..`_phase6_`, `_phase4d_`, `_phase8_`, `_moveBPT`, `_rescueTo`, `_migrateStaker`, `_collectNudgeFromOwner`, `_swapUniboost`), and assert the **presence** of `bptAtCutoverPersisted` rather than only the boolean flag.
3. **Best structural fix**, if the refactor is affordable: split the shared constants and read-only helpers into a **base contract**, so the verifier does not inherit a broadcast surface at all and the guarantee stops depending on a test at all.

**Review flag**

**DELIBERATE DOWNGRADE (Low → QA).** Recorded so a human can push it back to Low if they weight regression risk on the verifier more heavily. The downgrade rests entirely on the **empirically-verified-clean current call graph**; if that verification is ever wrong, or if a mutating call site lands, **this returns to Low immediately**.

---

## Appendix — automated SAST / gas report (4naly3er)

**Not attached.** 4naly3er could not produce a report for this slice at `c4396b1`; see **Reader's note 5** above for the two attempts, the exact solc errors, and why this is a tool-integration gap rather than a code defect. No automated bot-report baseline backs this bundle — every finding above is manual and fork-verified at block **25670926**.
