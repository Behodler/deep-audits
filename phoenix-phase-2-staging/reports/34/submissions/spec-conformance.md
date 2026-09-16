# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 34)

**Project**: phoenix-phase-2-staging  ·  **Run**: `phoenix-phase-2-staging-34`
**Commit**: `84e2324829bd6470ea4a42480290c5239dbec49e`, branch `master`  ·  **Baseline**: `29aeb2b` (run 33)
**Entry point**: `stable-staker-v2-cutover` (`package.json` → `:preview` / `:broadcast` / `:verify`)
**Delta**: `9ea09d5` [story-087] and `3275151` [story-087] NatSpec polish. The untagged commits `0a497f5` and `49d7804` touch only `src/mocks/MockAutoDOLA.sol` and do not reach either cutover forge target.
**Scope of this report**: Law-2 faithfulness only. Low/QA text lives in `qa-report.md`, and prior-run carryover lives in `carryover/`.

**Result: no standalone F-XX finding filed this run.** Two run-34 findings are faithfulness-tagged. Their primary entries are QA-bundle items, and they are listed here as pointers:

| Label | `issueId` | Fingerprint | Story graded against | Severity | Routing |
|---|---|---|---|---|---|
| **L-08** | `pps34l8` | `6022a9eb99899924db7239991e3f47124815eb4d15dec6ad2636ed32b88dd3ac` | stories 082/083 (per-user bound), story 087 Concerns | Low (borderline) | pointer; primary in `qa-report.md` |
| **Q-04** | `pps34q4` | `a62956952abd4fe22391f1fbff9f5e219961d003367a3c8a1dc4162529b9ea86` | story 087 A (breaker live at every Phase 7 halt), `//:broadcast` doc key | QA (borderline) | pointer; primary in `qa-report.md` |

Carried over and still open from run 31: **F-01** (`pps31f1`, `dfed4279095251f3acd34987e79e3a1eecfce16adaca31cc6c776e8f724e713a`), **proposed fixed at run 34, human confirmation via `/ledger` required**. Full text is in [`carryover/spec-conformance-31.md`](carryover/spec-conformance-31.md).

---

## Story resolution

Every tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree. Each tag matched exactly one file:

| Tag | State folder | File |
|---|---|---|
| story-082 | `auto-complete` | `phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md` |
| story-083 | `auto-complete` | `…/083-cutover-wei-slack-and-v1-pauser-unregister.md` |
| story-084 | `auto-complete` | `…/084-cutover-close-global-pause-window.md` |
| story-085 | `auto-complete` | `…/085-cutover-aggregate-principal-floor.md` (floor superseded by 087) |
| story-086 | `auto-complete` | `…/086-cutover-readonly-post-broadcast-verifier.md` |
| **story-087** | `auto-complete` | `…/087-cutover-audit33-breaker-window-selfexit-gate-eth-preflight.md` (**the story under regression**) |
| story-080 | `auto-complete` | `…/080-deploymocks-stablestakerv2-antimatter-cutover.md` (rehearsal only) |
| story-067 | `complete` | `phStaging2-ys-induced-stable-staker-migration-script/067-enforce-zero-haircut-floor-gate.md` (loss-gate lineage) |

---

## Story 087 acceptance tally

Story 087 has 30 acceptance items in sections A–E. Every item is ticked `[x]` in the story.

| Outcome | Count | Items |
|---|---:|---|
| Met | **27** | A1–A8, B2–B8, C1, C3–C6, D1–D3, E1, E2, E4, E5 |
| Deviation, justified | **2** | **B1** (weiSlack added to the realization bound), **C2** (`eth_getBalance` + env gas price instead of `OWNER.balance` + `max(env, tx.gasprice)`) |
| Partial | **1** | **E3** (live `:preview` ticked, but the story's own preview failed in Phase 6) |

### B1: justified deviation (weiSlack in the realization bound)

Acceptance text (verbatim, `closure-manifest.json` → `story087`):

> - [x] In `StableStakerCutoverCore`, replace the `P - v1Staked` aggregate floor with an **exit-realization bound** read from V1's immutable `migrationInfo`: `(R, P) = v1.migrationInfo(token); realized = min(R, P); require(realized * CUTOVER_MAX_BPS >= P * (CUTOVER_MAX_BPS - maxLossBps), "cutover-post: V1 exit realization below loss bound")`. This bounds the pre → credit haircut for every staker however they exit, and is resume-safe because it reads only state fixed at `initiateMigration`. Keep the `principalSnapshot > 0` sanity require.

**Implemented:** `(min(R,P) + 1000) · 10000 ≥ P · (10000 − bps)`. That is one `WEI_SLACK` (1000 wei) per pool, which the story text does not include.

**Why the deviation is justified:** 1000 wei is 8e-19 of the DOLA principal P and 5.1e-7 of the USDC principal P (0.005 bps). It cannot hide a loss measured in bps, and it exists only to absorb share rounding. Real haircuts still fail closed: `test_F01_haircut5bps_failsClosedBothShapes`, and `test_F01_boundarySweep_resumeShape` passes at 1.92 bps and fails at 2.12 bps (`fork-logs/r34-gapfix-fullfile.log`).

### C2: justified deviation (ETH preflight reader and price)

Acceptance text (verbatim):

> - [x] Add `_preflightOwnerEth()` called from `run()` **only when not preview**, before `vm.startBroadcast()`, and **not** from `_phase0_preconditions` (the verifier calls that). It requires the gas-price env var to be set (loud revert if missing) and `OWNER.balance >= CUTOVER_GAS_BUDGET * max(gasPriceEnv, tx.gasprice) * 12 / 10`.

**Implemented:** OWNER's balance is read with `vm.rpc eth_getBalance`, and the price is the env `CUTOVER_GAS_PRICE_WEI` alone.

**Why the deviation is justified:**
- **Reader.** The story's premise that forge pre-funds `--sender` in its local EVM did **not** reproduce. In a `ProbeOwnerEth.s.sol` dry run, the in-EVM balance equals `eth_getBalance` both before and after `vm.startBroadcast`. `test_L07_ownerEthReader` confirms this: `eth_getBalance(latest)=6424919451687286`, which matches the in-EVM value. Either way, `eth_getBalance` is the authoritative source.
- **Price.** In the local pass, `tx.gasprice` equals `block.basefee`, not the `--with-gas-price` value. Legacy txs pay exactly the pinned price, so `max(env, tx.gasprice)` would over-demand only when base fee exceeds the pinned price, and in that case the txs would not mine anyway.

The `:broadcast` script passes the same `$CUTOVER_GAS_PRICE_WEI` to `--with-gas-price` within the same `&&` chain. This matches C1's single-sourcing.

### E3: partial (live preview)

Acceptance text (verbatim):

> - [x] Run `npm run stable-staker-v2-cutover:preview` against mainnet RPC; confirm every `GLOBAL_PAUSE|…|SUCCEEDED` stage, the new loss-gate log lines, and the ETH budget line. Save the log under `scratchpad/planning-docs/phoenix/phStaging2/story-087/`.

The item is ticked, but the story's own Verification Results say the live preview **failed in Phase 6** at block 25985945. The stages after-phase6 through after-phase8 never ran live, and the story's "FOR THE HUMAN" section says so:

> the live preview cannot complete today, for a reason outside this story … `ERC4626_MAX_LOSS_BPS = 2` is now too tight for the live autoDOLA autopool: at block 25985945 the V1 exit alone realizes ~1.035 bps below par … The cutover therefore cannot be broadcast until that constant is revisited … It predates this story.

Run 34 supplies the missing evidence. At block 25988932 the full preview passes all 9 `GLOBAL_PAUSE` stages (`fork-logs/preview-25988932.log`). At 25985945 the same `run()` still reverts on the per-user bound (`test_B_previewRun_atStory087Block`, which asserts the exact revert string). Whether preview passes depends on the block, and that dependence is the subject of **L-08**.

---

## Pointer: L-08 (`pps34l8`), faithfulness-tagged, primary report in `qa-report.md`

**Title:** The Phase 6 per-user loss bound (`ERC4626_MAX_LOSS_BPS = 2`) sits inside autoDOLA's stepwise live spread, so `:preview`'s go/no-go flips between blocks. The bound is enforced only in forge's local pass, so a regime step during the Ledger session can land a migration above 2 bps, and only `:verify`'s live-balance aggregate detects it.

**Stories it binds against:**
- **Stories 082 and 083.** The per-user bound (≤ 2 bps + 1000 wei on ERC4626 pools) is the story contract. If the autopool regime steps between forge's local pass and on-chain inclusion, the landed Phase 6 txs exceed it. The fork shows this: at block 25985945, 9/9 DOLA users breach at 2.069–2.093 bps, and at 25988932, 0/9 breach at 0.948–0.959 bps. `test_B_driftLanding_postBroadcastTools` shows that on a drift landing the resume-shape and per-user checks both pass. Only the `:verify` aggregate reverts, and it is short by 0.008936 DOLA.
- **Story 087 Concerns.** The claim below is **false**:

  > This is looser on the exit leg for USDe; the per-user in-leg check and the verifier's per-user credit check still bound the total.

  The verifier's per-user credit check covers only the re-deposit leg (credit → credited). It does not bound the pre → credited total. The Phase 6 in-leg check does not run on chain, so a regime step between the local pass and inclusion escapes it.

**Why this is not an F-XX:** the root cause is gate calibration and where the bound is enforced (a Law-3 footgun), not a mis-implementation of story text. The script implements the constant and check that the story specifies. The faithfulness tag keeps the deviation visible here. Recommendation 4 of L-08 asks for the story 087 Concerns claim to be corrected, or for a per-user total check to be added to the verifier.

## Pointer: Q-04 (`pps34q4`), faithfulness-tagged, primary report in `qa-report.md`

The `//stable-staker-v2-cutover:broadcast` doc key and the Phase 7 NatSpec say every Phase 7 halt point keeps the breaker live. At halt 5 (after `v2.unpause()`, before `Pauser.register(V2)`), a committed global `Pauser.pause()` does not reach V2. The strategies still contain the exposure: 0 user entry points succeed (`test_P7_halt5_globalPauseCannotReachV2`). This is a documentation overclaim against story 087 A, and it is `residualOf` L-05 (`fc44ca36`), not an incomplete fix.

---

## Governance observation (for the human; not a code finding)

- **Undocumented state folder.** All of stories 080–087 sit in `auto-complete/`, which is **not** one of the documented states (`complete | incomplete | review | archive`). Each story carries an `## Auto-Completed` stamp: "Approved by: story-batch workflow (machine approval — not human-reviewed)". The `incomplete/` and `review/` folders are empty for this sprint.
- **087 completed despite ISSUES_FOUND.** Story 087 was auto-completed with **Review Status: ISSUES_FOUND**, triaged "non-blocking". One carried-forward issue is that the archived `preview-mainnet.log` and `anvil-broadcast-preflight-refusal.log` predate the final build: they reflect the superseded `max(env, tx.gasprice)` formula and the in-EVM OWNER balance read.
- **Reduced independence.** Every step of 087 (execution, review, polish, auto-complete) ran with `--inline-delegation`. The story itself records "Independence: reduced".
- **Timestamp inversion.** The `Auto-Completed` stamp and `Base Commit Updated` are dated **2026-09-15T23:46:26Z**. That is earlier than the Autonomous Decisions (2026-09-16T00:20Z) and the Review (**2026-09-16T02:05Z**) that the stamp claims to act on.
- **Ticked but unmet.** Checklist item E3 is ticked while the story's own evidence shows it unmet (see E3 above).

Taken together, the story tree's "complete" signal for this cutover has had no human review. Law-2 grading in this run relied on the story text and on independent fork evidence, not on the completion state. A human should review stories 082–087 before broadcast.
