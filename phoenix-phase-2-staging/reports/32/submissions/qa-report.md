# QA Report: phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 32)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `884ccf8c4fc2cd0ece179745bf2ea381e2bba51e` (branch `master`). Baseline `1c1608c` (run 31).
- **Delta commits**: `bdbd850` [story-083], `0855338` [story-083 polish], `884ccf8` (untagged)
- **Entry point**: `stable-staker-v2-cutover` (`package.json` → `stable-staker-v2-cutover:preview` / `:broadcast`)
- **Stories**: story-083 (`~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/083-cutover-wei-slack-and-v1-pauser-unregister.md`) and story-082 (same folder, `082-mainnet-stable-staker-v2-cutover-script.md`). Both sit in the non-standard `auto-complete` state folder.
- **Fork harness**: `phoenix-phase-2-staging/work/test/audit-run32/CutoverAuditRun32.t.sol`, mainnet fork at block **25978784**, inheriting the unmodified script. Logs: `phoenix-phase-2-staging/reports/32/script-audits/stable-staker-v2-cutover/fork-logs/`.

## Summary

| Severity | New this run | Still open from run 31 (re-observed) | Total in this bundle |
|----------|-------------:|-------------------------------------:|---------------------:|
| Low Risk | 1 | 1 | 2 |
| QA | 1 | 0 | 1 |
| Centralization | 0 | 0 | 0 |
| **Total** | **2** | **1** | **3** |

Not counted: **Q-03** (`pps32q3`) and **Q-01** (`pps31q1`), triaged wont-fix (invalid, out of scope) by owner 2026-09-15. See [Triaged wont-fix](#triaged-wont-fix-invalid-out-of-scope-by-owner-2026-09-15).

This run produced no centralization findings.

| Label | Issue ID | Title (short) | Origin | Verified | Recommended before broadcast |
|---|---|---|---|---|---|
| L-04 | `pps32l4` | Phase 1 → Phase 7 window leaves V1 paused and registered, so global `Pauser.pause()` reverts | new | fork-verified | **yes** |
| Q-02 | `pps32q2` | `//StableStakerV2Cutover` operator doc key describes the superseded story-082 end state | new | static + preview log | **yes** |
| L-02 | `pps31l2` | Post-broadcast `:preview` re-runs missing steps instead of asserting them (surface widened) | still open, run 31 | fork-verified | no |

> **Labels are run-scoped.** Use the `issueId` or fingerprint as the stable handle. L-02 and Q-01 keep their
> run-31 labels and IDs; no run-32 label was minted for them. Q-01 and Q-03 are triaged wont-fix (see the end of this report). Label numbers L-04, Q-02 and Q-03 continue the
> per-entry-point sequence, so run 32 has no L-01..L-03 or Q-01 of its own.

### Faithfulness findings (not duplicated here)

Law-2 story deviations are reported in [`spec-conformance.md`](./spec-conformance.md):

- **F-01** (`pps31f1`, still open from run 31). The "067 floor" post-condition compares two identically booked numbers, so it cannot fail. Full write-up in `spec-conformance.md`; not repeated here.
- **L-02** is cross-listed there because it also contradicts story-082 text. This file is its primary report.

### Other run-31 QA entries (carryover only)

The full run-31 text of every run-31 QA entry is in [`carryover/qa-report-31.md`](./carryover/qa-report-31.md). Two entries there are **not** restated below because run 32 did not re-observe them as candidates:

- **L-01** (`pps31l1`, `e0d4df1ddb69…`): `fixed` **proposed, not applied** (story 083 set `WEI_SLACK = 1000`; fork tests `test_L1` / `test_L2` show no dust stall).
- **L-03** (`pps31l3`, `0711215fcc17…`): kept **open**. The end-state brick is currently absent only because the owner unregistered two pre-paused contracts on-chain. Clause (b), that Phase 8 asserts registration rather than a working breaker, is still live. L-04 below is a separate root cause that shares L-03's simulated-pause verification remedy.

---

## Low Risk Findings

### [L-04] From Phase 1 until Phase 7's `Pauser.unregister(V1)`, V1 is paused with pauser OWNER but still registered, so the permissionless global `Pauser.pause()` reverts for all 26 registrants for the whole cutover session, or indefinitely if the run halts <!-- id: pps32l4 -->

**Recommended before broadcast.**

- **Severity**: Low (operational hazard / owner footgun, Law 3). Flagged for human review.
- **Fingerprint**: `46c053534c586895fece77ca5a74f0991e02d36f5c513251c6847e84787f96b6`
- **Entry Point**: `stable-staker-v2-cutover`
- **Story**: story-083
- **Location**:
  - [CutoverStableStakerV2Mainnet.s.sol#L272-L288](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L272-L288) (`_phase1_pauseV1`: `setPauser(OWNER)` L283, `pause()` L285)
  - [CutoverStableStakerV2Mainnet.s.sol#L550-L568](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L550-L568) (`_phase7_finalize` V1 retirement: `unregister` L559)
  - `lib/pauser/src/Pauser.sol` L56-69 (`pause()` loop). This is the nested `Behodler/pauser` submodule, pinned at `545928d067a3dd7ffb853ce41ced7177a34febf1`, so it has no blob link in this repository.

**Description**

`Pauser.pause()` is the protocol's permissionless emergency breaker: anyone who burns 1000 EYE can trigger it. It loops `IPausable(c).pause()` over every registrant, with no try/catch.

Phase 1 sets V1's pauser to OWNER and pauses V1, but V1 is only removed from the registry in Phase 7, about 40 transactions later. For that whole window the loop reaches V1 (index 18), reverts with `StableStaker: only pauser`, and the entire call reverts, so no registrant is paused. The registrants include the live yield strategies that custody staker principal, PhlimboV3 and the hooks. During the window OWNER is the direct pauser of only 1 of the 26 registrants (V1 itself). An owner who notices an incident therefore cannot pause the others through the Pauser either, until V1 is unregistered.

The window lasts the whole `--slow` Ledger session. Phase 6 contains several `STOP AND REPORT` reverts, and the resume procedure and halt-and-trim runbook both stop the run as well. A halt anywhere between Phase 1 and Phase 7 therefore leaves the breaker dead until someone resumes the run.

Story 083's rationale ("once V1 is unregistered, that risk is gone") covers only the end state. The ordering predates 083, because story 082 also paused V1 in Phase 1 while it stayed registered. In run 31 the window was hidden: the Pauser was already bricked by two pre-paused registrants, which the owner has since removed. The window is now the only thing that breaks the breaker. A competent owner who has just cleared the registry so that the breaker works would not expect the cutover to break it again, so this is in scope as a footgun.

**Impact**

The protocol-wide emergency pause is unavailable to EYE holders, and to the owner acting through the Pauser, for the duration of the cutover, or indefinitely after a halted run. An exploit on any registered contract during that window cannot be stopped through the designated mechanism.

The script causes no direct loss. Harm requires an independent incident that coincides with the window. The owner can restore the breaker with one transaction (`Pauser.unregister(V1)`, allowed because `V1.pauser() == OWNER`), after which `Pauser.pause()` succeeds for the remaining 25 registrants. The severity is Low rather than Medium because the impact is transient and recoverable, and because L-03, a broader and permanent version of the same impact class, is already rated Low.

**Evidence** (fork @25978784; `fork-logs/h32-test_W_windowBricksGlobalPause.log`, `h32-test_W2_earlyUnregisterFromPhase0State.log`, `h32-test_B_globalPauseBeforeAndAfterCutover.log`)

- `test_W_windowBricksGlobalPause`:
  - `WINDOW_AFTER_P1|V1.paused=true|V1.pauser==OWNER=true|V1.registered=true`
  - EYE-funded `Pauser.pause()` → `GLOBAL_PAUSE|window-after-phase1|REVERTED|...StableStaker: only pauser`
  - After the real Phase 6 → `GLOBAL_PAUSE|window-after-phase6|REVERTED|...only pauser`
  - `WINDOW_OWNER_DIRECT_PAUSERS|1of26`
  - Remedy: `Pauser.unregister(V1)` during the window → `GLOBAL_PAUSE|window-after-early-unregister|SUCCEEDED|registered=25`. The **unmodified** `run()` then completes (`WINDOW_REMEDY|...PASSED (Phase 7 gate skipped)`).
- `test_W2_earlyUnregisterFromPhase0State`: from fresh state, `setPauser(OWNER)` + `unregister(V1)` + `pause()` before `run()` → the global pause succeeds and `run()` passes.
- `test_B_globalPauseBeforeAndAfterCutover` (controls): pre-cutover live state `GLOBAL_PAUSE|pre-cutover(live state)|SUCCEEDED|registered=26|pausedAfter=26`; post-finalize `SUCCEEDED|registered=27|pausedAfter=27`.

**Recommendation**

Move V1's retirement to the start of the window. In `_phase1_pauseV1`, immediately after `setPauser(OWNER)`, call `Pauser.unregister(V1)` (gated on `isRegistered`) BEFORE `pause()`, and require `!isRegistered(V1)`. Keep the Phase 7 block as the idempotent backstop it already is. This is fork-proven compatible: the unmodified Phase 7 gates skip, and the resume paths still converge.

Also add a preview-only check that simulates the full `Pauser.pause()` (deal EYE, approve, call inside `snapshotState/revertToState`) in Phase 0, again after Phase 1, and in Phase 8, so that "registered" is proven to mean "actually pausable" at every stage. Document in the runbook that a halted run must be resumed, or V1 unregistered, before the operator walks away.

```solidity
function _phase1_pauseV1() internal {
    // ... existing finalized / already-paused skips ...
    if (IPausableLike(STABLE_STAKER_V1).pauser() != OWNER) {
        IPausableLike(STABLE_STAKER_V1).setPauser(OWNER);
    }
    if (IPauserRegistry(PAUSER).isRegistered(STABLE_STAKER_V1)) {
        IPauserRegistry(PAUSER).unregister(STABLE_STAKER_V1);
    }
    require(!IPauserRegistry(PAUSER).isRegistered(STABLE_STAKER_V1), "Phase1: V1 still registered with Pauser");
    IPausableLike(STABLE_STAKER_V1).pause();
    require(IPausableLike(STABLE_STAKER_V1).paused(), "Phase1: V1 did not pause");
}
```

---

## QA Findings

### [Q-02] The `package.json` `//StableStakerV2Cutover` operator comment still describes the superseded story-082 end state ("2 bps + 2 wei", "V1 pauser back to Pauser and V1 UNPAUSED"), the opposite of what story 083 made the script do <!-- id: pps32q2 -->

**Recommended before broadcast.**

- **Severity**: QA (documentation / operator-facing comment)
- **Fingerprint**: `1c859cdebb6424756c073b1358559f38d84feff33eb6f6a6563414e352a03542`
- **Entry Point**: `stable-staker-v2-cutover`
- **Story**: story-083
- **Location**:
  - [package.json#L49](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/package.json#L49) (the stale doc key)
  - [CutoverStableStakerV2Mainnet.s.sol#L112](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L112) (`WEI_SLACK = 1000`)
  - [CutoverStableStakerV2Mainnet.s.sol#L550-L568](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L550-L568) and [#L635-L637](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L635-L637) (actual retirement and its Phase 8 asserts)

**Description**

The doc key is the text the operator is told to read before signing ("Run :preview first, read it, then :broadcast"). Story 083 changed the script but not this key; `package.json` is unchanged between `1c1608c` and `884ccf8`.

- The key says per-user loss is bounded by "2 bps + 2 wei on the ERC4626 autopools". `WEI_SLACK` is now 1000.
- The key says "V1 pauser back to Pauser and V1 UNPAUSED (inert ... a paused registered contract would make the global Pauser.pause() loop revert)". Phase 7 now sets the V1 pauser to OWNER, unregisters V1 and leaves it **paused**, and Phase 8 asserts exactly that.
- The key does not mention the new `Pauser.unregister` transaction in its description of what the Ledger will sign.

An operator reconciling the preview output ("V1 pauser -> OWNER, unregistered from Pauser, left paused") against the documented intent finds them contradicting each other.

**Impact**

This can confuse the operator at the signing step of a ~47-transaction mainnet Ledger session. A careful operator may abort a correct run, or after broadcast "restore" V1 to the documented unpaused, pauser=Pauser, registered state. The key has no direct on-chain effect. That "restore" state would not enable an exploit (the global pause keeps working), so the finding stays at QA. It is still worth fixing before broadcast because its audience is the Ledger signer.

**Evidence**

- `package.json` L49 at `884ccf8` contains "per-user loss <= 2 bps + 2 wei on the ERC4626 autopools" and "V1 pauser back to Pauser and V1 UNPAUSED". `entry-manifest.json` records `intentCommentStale.stale=true` and `packageJsonChangedSince1c1608c=false`.
- The script at the same commit has `WEI_SLACK = 1000` (L112), the retirement block at L550-568, and Phase 8 asserts L635-637 (`V1 pauser == OWNER`, `!isRegistered(V1)`, `V1 paused`).
- The preview log (`fork-logs/preview-25978784.log`, fork @25978784) prints "V1 pauser -> OWNER, unregistered from Pauser, left paused".

**Recommendation**

Update the `//StableStakerV2Cutover` key to match story 083:

- per-user loss <= 2 bps + 1000 wei on the ERC4626 autopools, and 61 bps + 1000 wei on USDe;
- finalize sets V1 pauser -> OWNER, calls `Pauser.unregister(V1)`, and leaves V1 PAUSED (retired; `userMigrate` is not pause-gated);
- add a transaction-count note for the extra unregister.

If L-04 is fixed by moving the unregister into Phase 1, describe it under Phase 1 instead.

---

## Still open from run 31 (re-observed at `884ccf8`)

This entry was first raised in run 31 and remains **open** in the ledger. It keeps its run-31 label and issue ID. It appears here because run 32 re-observed it and its surface widened. (Q-01, previously listed here, was triaged wont-fix by the owner on 2026-09-15 and moved to the triaged section below.) Its full run-31 text is preserved verbatim in [`carryover/qa-report-31.md`](./carryover/qa-report-31.md). Line numbers below are re-verified against `884ccf8`.

### [L-02] The post-broadcast `:preview` "verification" re-executes any outstanding step under prank instead of asserting it is already done, so a partial or diverged mainnet cutover verifies green <!-- id: pps31l2 -->

- **Status**: open, still open from run 31. **Surface widened by story 083** (new `test_C3`).
- **Severity**: Low
- **Fingerprint**: `2c82d65e65e163c9f986c669aaf0b56abcfc80ae9f91016dd3f84fc1fb6b7da7`
- **Entry Point**: `stable-staker-v2-cutover`
- **Story**: story-082 ("Preview doubles as post-broadcast verification"); cross-listed in `spec-conformance.md`
- **Location**:
  - [CutoverStableStakerV2Mainnet.s.sol#L146-L643](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L146-L643) (`run()` through `_phase8_wiringAssertions`)
  - [#L550-L568](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L550-L568) (new story-083 `if (!done) do();` retirement steps)
  - [#L587-L643](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L587-L643) (`_phase8_wiringAssertions`)
  - [package.json#L50](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/package.json#L50) and [#L52](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/package.json#L52) (the verification claim)

**Description**

The `package.json` doc keys and story 082 both claim that after a broadcast, `:preview` "re-runs every assertion and smoke test against the live deployment", and that every phase detects "from on-chain state that it is done and skips". In fact every phase is `if (!done) do();`. Preview impersonates OWNER, so any step that did **not** land on mainnet is silently performed inside the simulation, and Phase 8 then asserts the simulated state. Nothing in preview mode, even with a progress file loaded, requires that zero mutations were needed. The per-user loss bound is also evaluated only over `plan.migratable` from the same leg, which is empty after a broadcast, so the on-chain credits are never re-checked.

This is the run-22 `ForgeLocalPassPrecedesBroadcast` family. All planning and assertions run in forge's local pass, and the batches are frozen there, before the Ledger session sends ~47 transactions with `--slow --skip-simulation`. A V1 `stake` that lands after the local pass but before the Phase-1 `pause()` transaction is absent from every batch. Phase 7 then revokes V1's phUSD mint anyway, which bricks that user's `userMigrate` while their frozen pending reward is non-zero. The chained preview then migrates them in simulation and reports success.

**Run-32 widening.** Story 083 added three more `if (!done) do();` steps: V1 `setPauser(OWNER)` (L555), `Pauser.unregister(V1)` (L559) and V1 `pause()` (L566). A post-broadcast preview now also masks a missing or reverted V1 retirement.

**Impact**

The operator's only automated outcome check can report a finished cutover while mainnet still has V1's phUSD mint live, V2 still paused, V1 still registered and unpaused, or a staker stranded on V1 behind a revoked mint. Remedies exist (owner re-grant plus a re-run), but nothing tells the operator they are needed. No direct loss is proven, and mainnet per-user loss stays bounded by the strategies' own `minOut` floors.

**Evidence** (fork @25978784; `fork-logs/h32-test_C_previewMasksMissingRevoke.log`, `h32-test_C2_previewMasksPausedV2.log`, `h32-test_C3_previewMasksMissingV1Retirement.log`)

- `test_C_previewMasksMissingRevoke`: `MASK_REVOKE|preview run() PASSED although V1 phUSD mint was live on-chain` (reproduced from run 31).
- `test_C2_previewMasksPausedV2`: `MASK_PAUSED_V2|... V2 was paused on-chain` (reproduced from run 31).
- **New** `test_C3_previewMasksMissingV1Retirement`: after a full cutover, V1 is unpaused, its pauser set back to the Pauser and re-registered; preview `run()` → `MASK_V1_RETIRE|preview run() PASSED although V1 was registered+unpaused on-chain`.

**Recommendation**

When `isPreview` is set and the progress file has `deploymentStatus == completed`, run a verify-only pass BEFORE `vm.startPrank` that requires every phase's done-condition, including the V1 retirement triple (`pauser == OWNER`, `!isRegistered`, `paused`), instead of performing it. Revert with `verify: step X not on chain` on any gap, and only then run the smoke tests.

The run-31 recommendation still applies in full and is the more robust form:

- Add a separate assert-only verifier (mirroring story-075's standalone `VerifyPromotionReady.s.sol`), or an explicit `VERIFY_ONLY` env-flag mode that never calls `vm.startPrank` / `vm.startBroadcast` and never mutates.
- Gate that mode on **on-chain** state, not on the progress file. Progress files can be stamped `completed` during forge's local pass (ledger `1e8cc0dc58ba`), so a progress-file gate alone is weaker.
- In that mode, every phase must `require(alreadyDone, "verify: step X not on chain")` and never perform the step.
- Live asserts must cover: V1 phUSD mint revoked; V2 and Antimatter unpaused; V1 `stakerCount` / `totalStaked` per pool within the straggler allow-list; V2 pauser == Pauser; the Antimatter minter set; and the V1 retirement triple.
- Re-check the per-user loss bound from on-chain receipts (V1 `MigratedOut` / V2 `DepositedFor` events, or persisted pre-migration principals) against V2 `userInfo`, rather than against the empty same-leg plan.
- Separately, assert that the set of V1 stakers at the Phase-1 pause block equals the frozen planning set, and fail loudly if a staker raced the window.

---

## Triaged wont-fix (invalid, out of scope) by owner 2026-09-15

The two entries below (Q-03 new in run 32, Q-01 carried from run 31) have been triaged **wont-fix (invalid, out of scope)** by the project owner on 2026-09-15. They are **not live**, are excluded from the summary counts and the before-broadcast list, and will not be carried over. Owner, verbatim: *"Q-01 is out of scope and also wrong. The DeployMocks doesn't have to rehearse everything. It is used for UI testing, primarily. The main rehearsals in it are things which cannot be tested on the ui."* Asked whether Q-03 falls under the same reasoning, the owner answered: *invalid too*.

### ~~[Q-03]~~ The story-080 DeployMocks cutover rehearsal still asserts a 2-wei per-user slack and leaves dev V1 unpaused and registered with the Pauser, so it no longer rehearses the story-083 mainnet end state or its forced setPauser -> unregister -> pause ordering <!-- id: pps32q3 -->

> **Triaged wont-fix (invalid, out of scope) by owner 2026-09-15.** DeployMocks is a UI-testing mock stack, not a fidelity rehearsal of the mainnet cutover script; divergence from the mainnet script's wiring/end state is not a defect. Do not re-file. The write-up below is kept for the record only.

- **Status**: wont-fix (triaged by owner 2026-09-15; invalid, out of scope)
- **Severity**: QA (rehearsal / test fidelity)
- **Fingerprint**: `30510f331ea8d0067a9552be68956070da9429bcaaaf01c9bd3647a8e890a815`
- **Entry Point**: `stable-staker-v2-cutover`
- **Story**: story-083 (carried-forward non-blocking [low]) / story-080
- **Location**:
  - [DeployMocks.s.sol#L2075-L2095](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/DeployMocks.s.sol#L2075-L2095) (`_assertStableStakerCutover`, `+ 2` slack at L2090)
  - [DeployMocks.s.sol#L1957](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/DeployMocks.s.sol#L1957) (`_rehearseStableStakerCutover`, which has no V1 retirement)
  - [DeployMocks.s.sol#L1320-L1323](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/DeployMocks.s.sol#L1320-L1323) (V1 registered with the Pauser)
  - [CutoverStableStakerV2Mainnet.s.sol#L25-L28](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L25-L28) (NatSpec naming DeployMocks as the rehearsal it mirrors)

**Description**

The mainnet script's NatSpec names DeployMocks `_deployAntimatterAndStableStakerV2` + `_rehearseStableStakerCutover` as the Anvil rehearsal it mirrors, and story 082 calls that code "THE TEMPLATE". Commit `884ccf8` synced the Antimatter phUSD grant, but the rest of story 083 was not carried over:

1. `_assertStableStakerCutover` still checks `pre - post <= pre*maxLossBps/10_000 + 2` (L2090), with 0 bps on the 1:1 pools. That is 500x tighter than mainnet's 1000-wei slack.
2. The rehearsal registers V1 with the Pauser (L1320-1323) and never runs the story-083 retirement sequence. When it finishes, dev V1 is unpaused, its pauser is the Pauser, and it is still registered: the story-082 Decision-9 end state that 083 superseded. The console text at L1589 nonetheless labels V1 "(retired)".

The one new mainnet on-chain call (`Pauser.unregister`), and its forced ordering (`unregister` reverts while `pauser() == Pauser`), are therefore exercised only by the mainnet preview against live state, never by the local end-to-end rehearsal that story 080 exists to provide. Story 083's own Auto-Completed section discloses this as a carried-forward non-blocking [low]. It was disclosed but not fixed.

**Impact**

The local rehearsal cannot catch a regression in the Phase 7 retirement ordering or in the slack, and it ends with a different Pauser registry from mainnet (mainnet's 27 entries exclude V1; the local registry still contains it). Frontends and scripts developed against the dev chain see V1 as live and pausable rather than retired. There is no mainnet effect: the mainnet `:preview` against live state remains a working backstop.

**Evidence**

- At `884ccf8`: `script/DeployMocks.s.sol` L2088-2091 has `// 2-wei absolute floor ...` and `pre - post <= (pre * maxLossBps) / 10_000 + 2`. L1320 is `stableStaker.setPauser(address(pauser));` and L1323 is `pauser.register(address(stableStaker));`.
- A grep of the file finds no `unregister(address(stableStaker))` and no `stableStaker.pause()`.
- The mainnet end state, by contrast, is fork-verified at block 25978784 in `test_A_stateDiffAndUsers`: `PAUSER_REG_AFTER|count=27|V1registered=false`, `V1STATE|paused=true|pauser=OWNER`.

**Recommendation**

In `_rehearseStableStakerCutover`, after the V1 phUSD revoke, add the same gated sequence that mainnet Phase 7 runs: `stableStaker.setPauser(deployer)`, `pauser.unregister(address(stableStaker))` and `stableStaker.pause()`, each followed by a read-back require. Add the Phase 8 triple (pauser == deployer, `!isRegistered`, `paused`) as asserts.

Replace the literal `2` with a named constant equal to the mainnet `WEI_SLACK` (1000), or import it, so the two cannot drift again. If DeployMocks `run()` stack depth is the blocker the story cites, move the retirement into its own internal function called from the rehearsal.

---

### ~~[Q-01]~~ The story-080 DeployMocks rehearsal omits the Antimatter phUSD mint grant that the mainnet script proves load-bearing, and the local verifier never calls `autoAnnihilate`, so the rehearsal cannot exercise V2's only reward path <!-- id: pps31q1 -->

> **Triaged wont-fix (invalid, out of scope) by owner 2026-09-15.** DeployMocks is a UI-testing mock stack, not a fidelity rehearsal of the mainnet cutover script; divergence from the mainnet script's wiring/end state is not a defect. Do not re-file. The write-up below is kept for the record only.

- **Status**: wont-fix (triaged by owner 2026-09-15; invalid, out of scope). Previously open from run 31; the run-32 incomplete-fix signal is superseded by this triage.
- **Severity**: QA
- **Fingerprint**: `ca095edfd77eb5c995570804e32901905437b90bc37ed74d5484860593878257`
- **Entry Point**: `stable-staker-v2-cutover`
- **Story**: story-082 (Decision 3 follow-up) / story-080
- **Location**:
  - [DeployMocks.s.sol#L1897-L1906](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/DeployMocks.s.sol#L1897-L1906) (grant now present, `setMinter(antimatter, true)` L1904, read-back L1905)
  - [DeployMocks.s.sol#L1790](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/DeployMocks.s.sol#L1790) (new ACL assert)
  - [ClaimWithdrawStableStaker.s.sol#L24](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/interactions/ClaimWithdrawStableStaker.s.sol#L24) and [#L106](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/interactions/ClaimWithdrawStableStaker.s.sol#L106) (`autoAnnihilate` appears only in a comment and a log string)
  - [verify-stable-staker.sh](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/verify-stable-staker.sh) (unchanged since `1c1608c`)

**Description**

Story 082 names DeployMocks `_deployAntimatterAndStableStakerV2` + `_rehearseStableStakerCutover` as "THE TEMPLATE for ordering and assertions". The mainnet script grants `phUSD.setMinter(antimatter, true)` (Decision 3), because `Antimatter.annihilate` pays its antimatter half with `_phUSD.mint(recipient, amount)`. Without the grant, `autoAnnihilate` reverts `phUSD: caller is not authorized to mint`. At `1c1608c`, DeployMocks granted only `antimatter.setApprovedMinter(V2)` and `phUSD.setMinter(V2)`, and `verify-stable-staker.sh` → `ClaimWithdrawStableStaker.s.sol` asserts that `claimEnabled` is false and then withdraws, never calling `autoAnnihilate`.

**Run-32 observation (historical; superseded by owner triage).** Commit `884ccf8` (untagged) adds `phUSD.setMinter(address(antimatter), true)` with a `_requireLiveMinter` read-back (L1897-1906) and an ACL assert (L1790). The grant half was addressed. `verify-stable-staker.sh` and `script/interactions/ClaimWithdrawStableStaker.s.sol` are unchanged between `1c1608c` and `884ccf8`, and no local script or test calls `autoAnnihilate`.

**Impact**

The local rehearsal and dev environment (UI and integration testing of the V2 reward flow) have no coverage of V2's only reward path while `claimEnabled == false`. Future edits to the mainnet cutover or to the V2 reward path get no local signal. There is no mainnet impact: the mainnet preview smoke-tests `autoAnnihilate`, and this audit's fork run exercised all three pools.

**Evidence**

- `git diff 1c1608c 884ccf8 -- script/DeployMocks.s.sol` shows the grant added at L1897-1906 and the ACL assert at L1790.
- `git diff --stat` shows `verify-stable-staker.sh` and `script/interactions/` unchanged.
- `grep autoAnnihilate script/interactions/ClaimWithdrawStableStaker.s.sol` matches only L24 (comment) and L106 (log text).
- PoC status: unverified (`needs-poc`). A coded PoC is not required at QA.

**Recommendation**

Keep the `884ccf8` grant. Extend `verify-stable-staker.sh` / `ClaimWithdrawStableStaker.s.sol` so that, on every pool, it stakes, advances time with `evm_increaseTime` (short), calls `autoAnnihilate(token)`, and asserts that phUSD received is greater than 0 and that the Antimatter owed was consumed. (Superseded: no fix is owed; the owner ruled DeployMocks need not rehearse this.)

For completeness, the run-31 recommendation was: in `_deployAntimatterAndStableStakerV2`, add `phUSD.setMinter(address(antimatter), true)` with a read-back at the current `mintVersion` (now done), and extend the verifier with the stake + `evm_increaseTime` + `autoAnnihilate` step described above. First confirm by running the story-080 dev rehearsal and calling `autoAnnihilate` on anvil, recording the exact revert string.

---

## Appendix: automated QA baseline (4naly3er)

**No report was produced this run (tooling gap, same as run 31).** The scope was the entry point's first-party Solidity at `884ccf8`: `script/CutoverStableStakerV2Mainnet.s.sol` and `script/helpers/StableStakerCutoverCore.sol`.

1. **basePath at the submodule root** could not be used. The project has no `remappings.txt` and resolves imports only through `foundry.toml`, which 4naly3er does not read.
2. **Staged run 1.** The two scope files were copied into a scratchpad staging tree, with a `remappings.txt` generated from the `foundry.toml` remappings rewritten to absolute submodule paths. The submodule was not modified. It failed with `lib/vault/src/interfaces/IYieldStrategy.sol import not found`, caused by a literal root-relative import in a nested dependency.
3. **Staged run 2**, with an added `lib/=<abs>/lib/` remapping. Compilation succeeded, with only solc warnings. Analysis then ran until the 480-second cap (`timeout` exit 124) and wrote no report. This matches run 31's hang of more than 32 minutes on the same scope.

There is no automated baseline for this bundle. All entries in this bundle come from the script-audit pipeline and the mainnet fork harness, not from a bot report.
