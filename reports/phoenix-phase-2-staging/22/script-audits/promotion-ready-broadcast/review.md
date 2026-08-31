# Script audit review — `promotion-ready:broadcast` (story 072)

**Project** `phoenix-phase-2-staging` · **Commit** `5ae94bd` (`[story-072] Fix the two comment-drift defects found in review`)
**Entry point** `promotion-ready:broadcast` · **Run** `phoenix-phase-2-staging-22`
**Mode** mainnet-fork PREVIEW (`promotion-ready:dry`, `PREVIEW_MODE=true`), anvil pinned at block **25659373**
**Story** `~/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/072-mainnet-nudgestreamer-cutover-multitoken-batchminter-staker-v2-migration.md` (state: `complete`; graded against the *Revision 2026-08-01 — replanned against current upstream* text and its `## Post-review corrections 2026-08-01`)

## Framing

This is a **pre-broadcast** audit. The cutover has **not been executed**: `broadcastAttempted: false`, no progress file exists, nothing has been signed. What was audited is the plan — 2,171 lines of `DeployMainnetPromotionReady.s.sol` read in full, its JS pre/post legs, and the on-chain state it will mutate — plus one full PREVIEW execution of that plan against a forked mainnet.

The operation is **one-shot and Ledger-signed**: a single manual session of order 60+ transactions from `0xCad1a786…D0B6`, with `--broadcast --skip-simulation --slow --legacy --with-gas-price 0.5gwei --gas-estimate-multiplier 200`. Every finding below should be read against that irreversibility, not against the standards of a redeployable contract.

Value inside the closure:

| Asset / action | Quantity |
|---|---|
| BPT moved old pooler → new pooler | **16,338.8190** BPT (`16338818951239025717919` wei, exact) |
| USDC rescued into the stream buffer | **348.810608** (225.040608 old batch minter + 123.77 DelayRelease) |
| Staker migrations (V1 → V2) | **3** instances, `totalStaked` 2 / 146 / 13 |
| Mint-debt hooks repointed | **5** (indices 1, 2, 3, 4, 7) |
| Dispatchers replaced | **4** (+ StableYieldAccumulator = 5 donor legs) |
| Contracts deployed | 13 (streamer, multi-token minter, pooler, 3 Uniboosts, ratchet, SYA, 3 V2 stakers, 3 transient migrators) |

---

## 1. Does it do what it intends?

**Substantially yes.** The PREVIEW run exited `0` with no revert, and every declared pre- and post-condition that can be evaluated locally passed.

Specifically verified by this audit, beyond re-reading the script's own assertion output:

- **Zero `phUSD.setMinter` calls.** The story's central safety claim is that mint authority is byte-identical after the cutover *by construction*, because hooks are repointed rather than redeployed. This audit checked it independently from source rather than accepting the claim: all three `setMinter` call sites in the file (`:799`, `:951`, `:1073`) are `dispatcher.setMinter(NFTMinterV2)`, and `PHUSD` appears elsewhere only as an `IERC20` `balanceOf`/`approve` target and as a whitelist argument. **The "by construction" argument is sound.** (It is, however, never *asserted* — see the cascade in §3.)
- **Phase 6 ordering is the corrected one.** The story carries a `Revision 2026-08-01 — replanned against current upstream` banner; the original Phase 6 ordering is superseded and was *proven to revert* during the story-073 local rehearsal. The code matches the corrected text, including the hook-`recipient` repoint from V1 staker to V2 staker at Phase 6 step 10.
- **Phase 4d is correctly sequenced after Phase 5** (Autonomous Decision 1), because the sixth donor — the StableYieldAccumulator — is only repointed in Phase 5; retiring the old batch minter before that would strand it.
- **Hook repointing is fail-closed on all five indices.** Per index: `pull()` → `hook.setDispatcher(new)` → `newDispatcher.setHook(hook)` → `replaceDispatcher(idx, new)`. `mintDebt` observed going `0/0/0/0/70e18` → `0`; `price`/`growth` preserved across all five `replaceDispatcher` calls.
- **`registerStream` durations are 10/30/30 days as named constants**, gate-checked in `run()` at `:358-366` alongside `NUDGE_SIZE == 40`, split range, window range and `SWEEP_HEADROOM_BPS`. Observed on-fork as `864000 / 2592000 / 2592000`.
- **The `&&` patcher chain is correct.** `backup-mainnet-addresses.js && forge script … && patch-mainnet-addresses-promotion-ready.js`, short-circuit not `;`. The patcher fills the two zero placeholders (`NudgeStreamer`, `Kendu`), repoints 15 keys by name, re-checks the post-patch key set against the `ContractAddresses` interface (**57 == 57**, the `tsc --strict` drift guard) and exits non-zero on a collision (exit 4) or a key-set mismatch (exit 3). Under `update:false`, "already equals the wanted address" is success, so the patcher is idempotent across resume legs.
- **The staker snapshot is provably complete.** `sum(userInfo.amount) == on-chain totalStaked` **exactly** on all three stakers (2 == 2, 146 == 146, 13 == 13). There is no under-enumeration at the pin block.
- **Runtime values are genuinely read at runtime, not taken from the story's literals.** The old batch minter held **225.040608** USDC against the story's stated 98.040608, and the DelayRelease held **123.77** against the story's 250.77. Both components drifted, in opposite directions — and the **aggregate, 348.810608, coincidentally matches the story's "~349 USDC"**. Had the script been using the stale literals, that coincidence would have masked the bug completely. It does not: the runtime figures were confirmed in use.

---

## 2. Does it introduce unintended side effects?

**No. Zero unintended state writes.**

Every mutation observed on the fork maps to one of the five coupled changes or to their declared supporting steps. Concretely: **no ownership moved**, **no configuration reset to a constructor default**, **no unrelated contract touched**, and **no off-chain file written outside `scripts/snapshots/`** (the progress file was verified *absent* after the preview run, as the preview leg promises).

Structural drift against the story's block-25656206 tables is **zero** across all 44 address constants (13 MUTATED, 5 REPLACED, 5 RETIRED, 20 READ, 1 actor). The only drift is in balances, on the two USDC figures noted above. The **BPT matches to the wei** in both directions — `16338818951239025717919` off the old pooler, the identical figure onto the new one, asserted both ways.

The methodological caveat is stated plainly: state-diff capture was by the script's own instrumented before/after reads plus independent `cast` reads at the pin block, not a `--json` state-diff dump. The mutation set is therefore **source-complete** (2,171 lines read in full, external-call surface enumerated) rather than **trace-complete**.

**None of the findings in this report say the script does something it did not say it would do.** They are about guard strength, verification coverage, and read-versus-replay semantics.

---

## 3. Have other problems surfaced because of it?

Yes. This is the substantive section.

### 3.1 The `ForgeLocalPassPrecedesBroadcast` family — one execution model, five defects, five fixes

`forge script` executes the entire Solidity body **once, locally**, collecting calldata; the transactions are signed and dispatched only afterwards. `--skip-simulation` does not change this — it removes the pre-send sanity check, not the local pass. The consequence is that **every `require`, every `assert`, and every `vm.writeFile` in the script runs before transaction #1 leaves the machine.**

That single fact produces five distinct defects with five distinct fixes:

| | Manifestation | Fix |
|---|---|---|
| **M-01** | Phase 7's entire read-back — and every in-phase post-condition — asserts that the *plan* is internally consistent, never that the *chain* matches it | A standalone post-broadcast verification entry point |
| **L-03** | `_writeProgressFileWithStatus("completed")` is stamped during the local pass, so the patcher's `deploymentStatus === 'completed'` gate carries zero information | Write the status from JS after `forge` returns 0, or restate the header honestly |
| **L-05** | Phase 4d's post-pause residue sweep is inside `if (residue > 0)`, evaluated against a residue that is zero locally; the branch can never fire | Unconditional queued rescue, plus a runbook step; retract Autonomous Decision 2's "structurally closed" claim |
| **L-04** | The BLOCKING Kendu fee-on-transfer probe lives in Phase 8, which is `PREVIEW_MODE`-only, while the whitelist write at `:640-644` is unconditional | Move the check into Phase 2 in both modes, or make it a broadcast-safe static assertion |
| **L-01 (partial)** | The `require(old.totalStaked() == 0)` backstop at `:1394` — cited as the guard against a stale staker list — evaluates in the same local pass and cannot observe the chain | Close the snapshot window (pause first) rather than rely on the guard |

Note that the model is not always a defect. For a **missing snapshot file** (L-07) the same mechanism is the **mitigation**: the run fails closed and atomically, before a single transaction is broadcast, so nothing is half-applied. The defect is only where the mechanism is being relied on for *outcome* verification. That distinction is what separates L-07 (operator-experience hardening) from M-01 (an absent control).

### 3.2 The cascade — the story's remedy for the first drift created the second

This is the most consequential single fact in the run, and it is a two-step chain:

1. Commit `5ae94bd` exists to fix comment drift found in review. One of those fixes was **post-review correction #1** on story line **1167**: a script comment had claimed Phase 7 asserts mint-authority invariance. It does not. The correction removed the false comment and **reassigned the check to "the post-broadcast HUMAN item at the end of this checklist"** — that is, to story line **1195**.
2. **Line 1195 is unticked.**

Net effect: the obligation was transferred to a control that has not been discharged, so **no verification of mint-authority invariance exists on any path** — not in Phase 7, not in Phase 8, not in the runbook as executed. The "by construction" argument (§1) remains sound as an argument, and this audit independently confirmed it from source; but an unverified argument is not a control.

The same unticked line 1195 is also **L-01's sole escalation trigger**: L-01 (a user stranded on a paused V1 staker by staking between snapshot generation and pause) is Low *because* a designated on-chain detection control for exactly that failure exists in the checklist. If line 1195 is not ticked, that basis evaporates and L-01's conditional-Medium trigger arms. Its sibling, line **1197** — *"trigger one index-4 mint and assert `BatchDonatedViaPSM` fired — a green transaction is **not** evidence for the pooler"* — is also unticked.

### 3.3 MR-22-01 — an audit-model gap, not a code finding

The `_writeProgressFileWithStatus("completed")` + patcher-gate idiom described in L-03 is not new to this script. It **shipped, unflagged, on two audited mainnet cutover scripts**:

- `script/DeployMainnetUniboostCutover.s.sol:802` — audited in **run-20**, whose UBC-03 was *the verification-completeness finding on that very script*, and which still did not catch this.
- `script/DeployMainnetNudgeRatchet.s.sol:811` — audited in **run-19**.

The two helper bodies are **byte-identical**. The consumer gate at `patch-mainnet-addresses-promotion-ready.js:122-123` describes itself in its own header as "necessary but not sufficient", when in fact the condition is necessary *and unconditionally true at every point the patcher can run* — it carries zero information.

The defect was first caught only in **run-21**, and then on a **mock** script (`DeployMocks.s.sol:1922`, filed as `1e8cc0dc`), whose note already read *"PROPAGATES-TO-MAINNET as a PATTERN"*.

**Coverage, stated honestly:** `_writeProgressFileWithStatus` has **six users** (enumerated at `5ae94bd` by definition site: `DeployMainnetNFTStaking.s.sol:519`, `DeployMainnetNFTV2.s.sol:750`, `DeployMainnetNudgePoolerV2.s.sol:1049`, `DeployMainnetNudgeRatchet.s.sol:818`, `DeployMainnetPromotionReady.s.sol:1984`, `DeployMainnetUniboostCutover.s.sol:809`). **Three were examined. Three were not.** Examined: `DeployMainnetNudgeRatchet.s.sol` (run-19), `DeployMainnetUniboostCutover.s.sol` (run-20), and `DeployMainnetPromotionReady.s.sol` (this run, filed as L-03). The genuinely unexamined set is exactly these three, and the sweep should name them rather than re-derive them:

- `script/DeployMainnetNFTStaking.s.sol` (`:519`)
- `script/DeployMainnetNFTV2.s.sol` (`:750`)
- `script/DeployMainnetNudgePoolerV2.s.sol` (`:1049`)

That three is an **UPPER BOUND and outstanding work — not a count of confirmed instances.** Until the sweep runs, absence of a finding on those three is absence of evidence, not evidence of absence. Two further files must not be miscounted in that sweep:

- `DeployMocks.s.sol:1922` uses a **stricter inline form**; it corroborates and **strengthens** `1e8cc0dc` rather than weakening it, and that entry was not modified by this run.
- `DeployMainnetUniboostBatchMinters.s.sol:230` is the **parameterised writer body** (status is an argument), not an unconditional `"completed"` write. It is not a seventh instance.

The lesson is about the audit model itself, not about any one script: **a copy-inherited idiom is structurally invisible to an audit scoped to a single entry point.** Each run looked at its own script, found the idiom already present and apparently blessed by two prior audits of the same shape, and moved on. The remedy proposed to the closure mapper is a cross-script check for the `_writeProgressFileWithStatus` + `patch-mainnet-addresses-*.js` gate pair, so the next inheriting script surfaces it automatically. Recorded as ledger `watchNotes[0]`, deliberately carrying **no C4 severity** — its code-side realisation for this entry point is L-03, filed at Low.

### 3.4 Fix-ordering constraint — L-02 must land before M-01

**This is blocking, and it is easy to get backwards.**

M-01's fix relocates Phase 7 into a standalone post-broadcast verification run. But Phase 7's BPT conservation assertion reads `bptAtPhase0`, a value taken in Phase 0. On a post-broadcast run, `OLD_POOLER` has already been emptied, so `bptAtPhase0` reads **zero** and the assertion on 16,338.8190 BPT — the largest single asset in the closure — degrades to `balanceOf(newPooler) >= 0`.

That is L-02's defect (today it only bites on the `:resume` path). Shipping M-01's fix on its own would **widen L-02 to the fresh path too, while reading as a resolution of M-01.** The verification entry point must consume a **persisted `bptAtCutover`** from the progress file, never a freshly-read Phase 0 value. Implement L-02 first.

### 3.5 Cluster interactions

Thirteen sibling scripts were resolved into the cluster. Two matter here:

- **`DeployMainnetUniboostCutover.s.sol` (story 071, run-20)** is the explicit template for this script's `PREVIEW_MODE` / progress-file / `:resume` / `--legacy` gas design — and it supplied the pattern **including the defect that becomes L-03**. It also deployed the very Uniboost ×3 and index-7 DelayRelease that 072 now replaces. Inheritance here carried the bug along with the design.
- **`DeployMocks.s.sol` (story 073, run-21)** shared **zero mainnet addresses** with this closure, which makes it a **null economic rehearsal**: every mainnet-only precondition (the `_hasNudgeStreamer` probes, the `OLD_*` owner checks, the Kendu fee-on-transfer gate) has no local counterpart and was never exercised there. Its real value was the **ordering findings** — and those transferred correctly: findings 1 and 2 from that rehearsal rewrote 072's Phase 6 ordering and mandated the V1 Pauser deregistration, both of which are present and correct in this script.

Two further cluster facts worth carrying into the session: `FixRatchetBatchMinterSink.s.sol` exists because the index-7 donor sink has already been mis-wired once (a self-refund loop), and 072 re-routes that same sink; and `RescuePoolAndDonateUSDC.s.sol` is the prior art that `BalancerPoolerV2._psmDonate` failures are silently swallowed by `try`/`catch` — which is precisely why Autonomous Decision 7 requires the pooler donation to be verified **positively** via `BatchDonatedViaPSM`, not by a green transaction.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **M-01** | Medium | A broadcast run performs zero on-chain verification of its own outcome: Phase 7 and every in-phase post-condition evaluate in forge's local pass, Phase 8 is gated off under `--broadcast`, and the compensating human check (story line 1195) is unticked | Add a read-only `promotion-ready:verify` entry point that re-runs `_phase7_wiringAssertions()` against live post-broadcast state and append it to the `:broadcast` / `:resume` `&&` chains; until then tick line 1195 as a hard gate. **Land L-02 first** | `script/DeployMainnetPromotionReady.s.sol:400-411` (`run` / `_phase7_wiringAssertions`) |
| **L-01** | Low | A user who stakes between snapshot generation and the on-chain pause is silently stranded on a paused, defunded, Pauser-deregistered V1 staker | Close the window rather than narrow it: pause all three V1 stakers in a separate short broadcast *before* generating the snapshot. Fallback (narrows only): record the snapshot `blockNumber` and `require(snapshotBlock >= block.number - N)` in Phase 0 | `DeployMainnetPromotionReady.s.sol:1388-1398` (`_migrateStaker`) |
| **L-02** | Low | Phase 7's BPT conservation assertion degrades to `>= 0` on every resume path, leaving 16,338.8190 BPT unverified exactly when verification matters most | Persist the Phase 0 BPT reading in the progress file as `bptAtCutover` and assert `balanceOf(newPooler) >= recordedBpt`; cheap stopgap, assert `> 0` when `_isConfigured("pooler_bpt")` | `DeployMainnetPromotionReady.s.sol:1563-1564` (`_phase7_wiringAssertions`) |
| **L-03** | Low | The progress file is stamped `deploymentStatus: "completed"` during the local pass, making the patch script's own gate structurally inert | Write `"completed"` from the JS side after `forge` returns 0 (patcher takes an explicit `--confirm-broadcast`), or restate the header honestly that the status is not evidence anything landed. Apply to the **shared idiom**, not this one script (MR-22-01) | `DeployMainnetPromotionReady.s.sol:402-404` (`run` / `_writeProgressFileWithStatus`) |
| **L-04** | Low | Kendu is whitelisted unconditionally while its BLOCKING fee-on-transfer probe is PREVIEW-only; a taxed token would brick `batchMint` for every reward token | Make the gate structural: run the round-trip probe inside Phase 2 in both modes, or reduce it to a broadcast-safe static assertion (`buyTotalFees() == 0 && sellTotalFees() == 0 && owner() == address(0)`) that is `require`d unconditionally. If it must stay preview-only, gate the whitelist call on a `KENDU_PREFLIGHT_PASSED` env var | `DeployMainnetPromotionReady.s.sol:636-644` (`_phase2_deployBatchMinter` / `_probeKenduFeeOnTransfer`) |
| **L-05** | Low | Phase 4d's post-pause residue sweep can never fire, so its stated rationale and the story's "`rescueERC20` still works while paused" assertion are both unproven | Add a numbered post-broadcast runbook step alongside line 1195: read `IERC20(USDC).balanceOf(OLD_BATCH_MINTER)`; if non-zero, `rescueERC20(USDC, OWNER, bal)` then `forceApprove` + `collectNudge(newBM, USDC, bal)` so it enters the stream — mirroring Phase 3 by hand. Or queue a second `try`-wrapped rescue unconditionally. **Retracting Autonomous Decision 2's "structurally closed" claim is not optional.** Separately, prove pause-transparency in Phase 8 by `deal`-ing 1 USDC onto the paused minter and asserting `rescueERC20` succeeds | `DeployMainnetPromotionReady.s.sol:1137-1148` (`_phase4d_retireOldBatchMinter`) |
| **L-06** | Low | The snapshot scanner's `DEFAULT_FROM_BLOCK = 25000000` is an undocumented correctness horizon for the `migrate()` user list | Promote the `sumStaked !== totalStaked` warning at `:245-248` to a hard `die(4, …)`; document the constant as "must precede the earliest of the three stakers' deployment blocks" and record those three block numbers so it can be audited rather than trusted | `scripts/snapshot-depletion-stakers.js:89` (`main`) |
| **L-07** | Low | The snapshot file is a documented hard prerequisite with no Phase 0 probe; it fails at line 1390 of 2171 with a generic filesystem error | Add a `try vm.readFile(SNAPSHOT_FILE)` probe to Phase 0 with an actionable message (`run: npm run promotion-ready:snapshot`), parse `.blockNumber` and assert freshness (also addresses L-01); add the missing `//promotion-ready:snapshot` package.json annotation documenting the prerequisite, the `FROM_BLOCK` horizon and exit code 4 | `DeployMainnetPromotionReady.s.sol:1440-1443` (`_phase0_preconditions` / `_loadSnapshotUsers`) |
| **L-08** | Low | Indices 2 and 3 are never functionally exercised, so `setMinter` on two of the three new Uniboosts has no verification of any kind — and Autonomous Decision 5 claims otherwise | Add `_mintOnce(actor, IDX_SCX, USDC, …)` and `_mintOnce(actor, IDX_FLX, USDC, …)` to `_probeDonorPaths` — two lines using the existing helper — and correct the comment at `:1575-1580` and the Autonomous Decision text, or name the covered indices explicitly if the probes are not added | `DeployMainnetPromotionReady.s.sol:1665-1707` (`_probeDonorPaths` / `_assertSlot`) |
| **Q-01** | QA | The knowingly-accepted mint-UI breakage has no tracked remediation story, so the cutover ships an indefinite outage | Raise the `phlimbo-ui` story before the Ledger session and sequence it as a same-day follow-up so the outage is a known number of hours; scope the two-coexisting-batch-minter-ABIs trap into it explicitly, and cite ledger Q-04 (`a807cc7a`) so the script-side legacy scalar-`minReward` call sites and the UI-side 3-element-array surface are covered by one follow-up | `package.json:282` (`//promotion-ready`) |
| **Q-02** | QA | The Phase 6 budget top-up approval lacks the before/after allowance assertions that guard every other approval in the script | Mirror the USDC helper exactly: `require(allowance(OWNER, v2) == 0)` before, `forceApprove` in the middle, `require(allowance(OWNER, v2) == 0)` after — three lines per staker, making approval hygiene uniform so a reader can tell the asymmetry is not deliberate | `DeployMainnetPromotionReady.s.sol:1409-1410` (`_migrateStaker`) |
| **Q-03** | QA | The new StableYieldAccumulator is given an unbounded phlimbo approval that is hardcoded rather than mirrored from the retiring instance | Either read the retiring instance's existing phlimbo allowance and mirror it, or keep `type(uint256).max` and extend the comment to record why unbounded is correct here (PhlimboV2 is first-party, one spender, `collectReward` the only consumer) so the choice reads as deliberate rather than defaulted | `DeployMainnetPromotionReady.s.sol:1187` (`_phase5_stableYieldAccumulator`) |
| *MR-22-01* | *n/a — watch-note* | *Cross-run recall gap: the `_writeProgressFileWithStatus("completed")` + patcher-gate idiom shipped unflagged on two audited mainnet scripts* | *Sweep the 4 unexamined `_writeProgressFileWithStatus` users and their paired patcher gates; add a cross-script check for the helper + `patch-mainnet-addresses-*.js` gate pair to the `/audit-script` closure mapper* | *ledger `watchNotes[0]`; instances at `DeployMainnetUniboostCutover.s.sol:802`, `DeployMainnetNudgeRatchet.s.sol:811`* |

---

## Recommendations, in order

**Zero-code, before the Ledger session — do this first.**

1. **Tick story-072 checklist lines 1195 and 1197 as mandatory, blocking, signed-off steps** in the runbook, before the Ledger key is disconnected. Line 1195 is a well-specified and sufficient on-chain confirmation (dispatcher configs, drained retiring contracts, rescued USDC in the streamer buffer not on `newBM`, mint-debt pulled, hooks repointed, **phUSD minter set byte-identical**, full BPT on the new pooler, V1 drained / V2 funded, donor `nudgeStreamer()` routing, streams at 10/30/30). Line 1197 is its functional half. Ticking both **discharges most of M-01's impact with no code change and removes L-01's only escalation path.**
2. **Re-run `promotion-ready:snapshot` immediately before the session** (the story's own carried-open instruction) to narrow L-01's window.
3. **Confirm forge's behaviour under `--broadcast --skip-simulation --slow` when a dispatched transaction reverts on-chain** — does it halt the sequence, and what exit code does it return? This audit did **not** verify it. The answer determines how much of the gap the interim control must cover.
4. Add the L-05 residue sweep as a numbered post-broadcast step.

**Code, in this order.**

5. **L-02** — persist `bptAtCutover`. *Blocking prerequisite for step 6.*
6. **M-01** — add the `promotion-ready:verify` entry point consuming that persisted value, appended to the `:broadcast` and `:resume` `&&` chains.
7. **L-04** — make the Kendu gate structural; **L-07** — Phase 0 snapshot probe with freshness; **L-08** — two `_mintOnce` lines for indices 2 and 3.
8. **L-03** — fix at the level of the shared idiom (MR-22-01), not this one script; **L-06**, **Q-02**, **Q-03** as hygiene.
9. **L-01** option (a) — pause before snapshot — if this cutover pattern will be repeated.

---

## Honesty notes — read these before quoting anything above

- **M-01 rests on a narrowed basis.** The limb *"a 60+-tx one-shot cutover can exit 0 while half-applied"* was **REJECTED from the severity basis**. The fork run was **PREVIEW**, so forge's receipt-handling and exit-code behaviour under `--broadcast --skip-simulation --slow` on a reverted on-chain transaction **was never observed**. It is **reasoned, not evidenced**. The Medium rests only on three directly-verified structural facts: Phase 7 and every in-phase assertion evaluate before dispatch (`run():400-411`), Phase 8 is gated off under broadcast (`run():402-408`), and story line 1195 is unticked. Those hold regardless of what forge's exit code does.
- **Phase 8 exercised three of five donor indices.** idx1 (+5.001 USDC), idx7 (+70.0 USDC) and idx4 (+2.456043 USDC, with `BatchDonatedViaPSM` asserted **positively** and `DonationSkipped` confirmed absent). **idx2 and idx3 were never minted through** — that gap is L-08. `StableYieldAccumulator.claim()` was not simulated either; it was verified structurally only (Autonomous Decision 6, disclosed).
- **The Kendu BLOCKING gate passed exactly, against the real token.** 1e24 sent, 1e24 received by the streamer, 1e24 credited to the buffer, against `0xaa95f26e…6c18` — not a mock. `deal()` only seeded the balance; `collectNudge` performed a genuine `transferFrom` through Kendu's transfer path. Kendu's ownership is renounced (`owner() == 0x0`), so its fee switches can never move again. This discharges L-09's (`acabc052`) Kendu-specific evidentiary limb — flagged as **MR-22-02** for human re-weigh, **not auto-closed**. L-04's structural limb survives regardless.
- **`known-issues.md` is declared in the registry but absent from disk.** `registered-projects.json` names `lib/phoenix-phase-2-staging/known-issues.md` with `knownIssuesCount: 11`; the file does not exist, and the cached entries are a non-re-derivable 2026-01-09 snapshot. **Nothing in this run was suppressed on that authority.**
- **Nothing was parked and nothing was dropped.** All 12 candidates (PR-01…PR-12) survive into the report; 0 merged, 0 matched as ledger duplicates. `manual-review.json` carries an explicit zero-park declaration so its emptiness cannot be read as a missing pass.
- **`lastAuditedCommit` was deliberately NOT advanced** to `5ae94bd`. This was a single-entry-point script audit, not a contract scan of the submodule; advancing the project baseline would falsely claim contract-level coverage and cause a future regression run to skip files this run never read. The entry-point baseline for `promotion-ready:broadcast` was advanced instead.
- **M-01 is adjacent to, and deliberately not collapsed into, three ledger siblings** — UBC-03 (`06028eac`), L-01 (`ad7041ef`) and L-06 (`c76a8f9f`). UBC-03 is a **breadth** gap (5 of ~25 mutations covered); M-01 is a **timing** gap (100% of assertions, 0% post-broadcast). Adding twenty more assertions would not move M-01 at all, because all twenty would still evaluate in the local pass. No pre-existing ledger entry was modified by this run (verified: 12 additions, 0 removals, 0 modifications to the 93 pre-existing entries).
