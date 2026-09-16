# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 32)

**Project**: phoenix-phase-2-staging  ·  **Run**: `phoenix-phase-2-staging-32`
**Commit**: `884ccf8c4fc2cd0ece179745bf2ea381e2bba51e`, branch `master`  ·  **Baseline**: `1c1608c` (`entryPointBaselines["stable-staker-v2-cutover"]`, set by run 31)
**Delta commits**: `bdbd850` [story-083], `0855338` [story-083 polish], `884ccf8` (untagged, "udpates")
**Entry point**: `stable-staker-v2-cutover` (`package.json` → `stable-staker-v2-cutover:preview` / `:broadcast`)
**Fork harness**: `phoenix-phase-2-staging/work/test/audit-run32/CutoverAuditRun32.t.sol`, mainnet fork @25978784, 13 tests `[PASS]`; logs under `phoenix-phase-2-staging/reports/32/script-audits/stable-staker-v2-cutover/fork-logs/`.
**Report scope**: Law-2 faithfulness only. Low/QA findings without a faithfulness tag are in `qa-report.md`.

This run raises **no new Law-2 finding**. Two still-open Law-2 findings from run 31 were **re-observed** at
`884ccf8` and are re-graded here against the current story set: **`F-01`** (standalone) and **`L-02`**
(cross-listed; primary report in the QA bundle). Neither is High or Medium, so no H/M submission is owed.
Both keep their original run-31 labels and `issueId`s; neither mints a new ledger entry, and neither status
was changed.

| Label | `issueId` | Fingerprint | Story graded against | Deviation type | Severity | Origin | Routing |
|---|---|---|---|---|---|---|---|
| **F-01** | `pps31f1` | `dfed42790952…` | story-082 Phase 6 + **story-067** (story-083 does not touch it) | DECLARED-BUT-UNMET (tautological gate) | Low | still-open (code unchanged) | standalone |
| **L-02** | `pps31l2` | `2c82d65e65e1…` | story-082 "Preview doubles as post-broadcast verification" + `package.json` doc key; surface widened by story-083 | DECLARED-BUT-UNMET | Low | still-open (surface widened) | cross-listed (primary: `qa-report.md`) |

> **Labels are run-scoped.** Use the `issueId` or fingerprint as the stable handle. The full run-31 text of
> both findings (plus `L-01`) is carried in
> [`carryover/spec-conformance-31.md`](carryover/spec-conformance-31.md).

---

## Story resolution

Each tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree (every state and
sprint folder). Each returned exactly one document.

- **`[story-083]`** →
  `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/083-cutover-wei-slack-and-v1-pauser-unregister.md`
- **`[story-082]`** →
  `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md`
- **`story-067`** (cited by 082 as the source of the "realized ≥ booked principal" check) →
  `~/code/product-owner/stories/phStaging2/complete/phStaging2-ys-induced-stable-staker-migration-script/067-enforce-zero-haircut-floor-gate.md` (state `complete`)

**State folder: `auto-complete` (082 and 083).** This is **not** one of the standard state folders
(`complete` / `incomplete` / `review` / `archive`). Both stories carry the same completion stamp:

> **Approved by**: story-batch workflow (machine approval — not human-reviewed)

(082 line 322; 083 line 267). 082 acted on review status `ISSUES_FOUND`, 083 on `PASSED`, both with triage
verdict "non-blocking". **No human has signed off** on either story, so their carried-forward observations
are surfaced in the audit channel rather than treated as accepted. Story 083 **supersedes** 082 Decision 9
(V1 ends unpaused, pauser restored) and 082's `+ 2 wei` per-user slack; where the two stories conflict, 083
governs.

---

## F-01 (still open): The "067 floor" post-condition compares two numbers booked identically, so it cannot fail; story-067's zero-haircut anchor on the pre-migration booked total is not implemented

- **`issueId`**: `pps31f1`  ·  **First seen**: `phoenix-phase-2-staging-31`  ·  **Last seen**: `phoenix-phase-2-staging-32`
- **Fingerprint**: `dfed4279095251f3acd34987e79e3a1eecfce16adaca31cc6c776e8f724e713a`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/helpers/StableStakerCutoverCore.sol:_assertPoolPostMigration:TautologicalPostCondition:stable-staker-v2-cutover`
- **Root cause class**: `TautologicalPostCondition`  ·  **Severity**: Low (unchanged)  ·  **Ledger status**: `open` (unchanged)
- **Location**: [`script/helpers/StableStakerCutoverCore.sol#L469-L471`](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/helpers/StableStakerCutoverCore.sol#L469-L471) (`_assertPoolPostMigration`)
- **Finding records**: `reports/32/findings/faithfulness/F-01-C1-tautological-post-condition.json` (run-32 re-observation), `reports/31/findings/faithfulness/F-01-tautological-post-condition.json` (original)

### Acceptance text this deviates from (verbatim)

story-082, line 88 (Phase 6 post-conditions):

> Phase 6 post-conditions per token (080's `_assertStableStakerCutover`, extended): V1 totalStaked/stakerCount == stragglers only; each migrated user post>0, post<=pre, loss ≤ maxLossBps (0 for ERC4626 DOLA/USDC, strategy bps + slack for USDe) + 2 wei; V2 totalStaked == sum(post); realized ≥ booked principal (067).

story-082, line 129 (checklist, ticked):

> - [x] Post-migration invariants (080 extended + 067 realized ≥ booked)

story-067, lines 40–48 (the gate story-082 cites):

> **Decision (user-confirmed): implement an end-to-end floor gate.** Capture the staker's
> *pre-migration* booked total (already snapshotted in `leg1-stakers.json` before any drain),
> persist it into the migration-state JSON, and in `PostMigrationCleanup` — which runs after
> leg 2, where users and their re-booked credits are present — hard-require:
>
> ```solidity
> require(
>     ysDolaV2.principalOf(DOLA, ORIGINAL_STABLE_STAKER) >= savedPreMigBookedDola,
>     "Zero-haircut gate FAILED: realized principal < pre-migration booked"
> );
> ```

story-067, lines 34–36, warning against exactly this shape:

> making the proposed
> `require(principalOf >= savedTotalStaked)` collapse to `require(principalOf >= 0)`: a
> no-op that would *look* like a fix while enforcing nothing

Story 083 changes only the per-user wei term of line 88 (083 line 14: *"**Raise `WEI_SLACK` from 2 to
1000.**"*). It does not amend or waive the "realized ≥ booked principal (067)" clause, so that clause still
governs.

### What the code does (unchanged at `884ccf8`)

```solidity
// script/helpers/StableStakerCutoverCore.sol:469-471
// ---- Story 067 floor: what the strategy realizes for V2 covers what V2 books for users ----
uint256 realized = ICutoverStrategy(strategy).principalOf(token, address(v2));
require(realized >= v2Staked, "cutover-post: strategy principal for V2 < V2 booked totalStaked (067 floor)");
```

Both sides are read **after** migration, and both are credited from the same `credited` value in each
`depositFor`, so they are equal by construction and the check cannot detect a haircut.
`StableStakerCutoverCore.sol` is byte-identical between `1c1608c` and `884ccf8`.

**Run-32 fork evidence** (`test_A_stateDiffAndUsers`, fork @25978784, POSTPOOL): exact equality on all three
pools again. DOLA `v2Staked=1222723447469613917497 | principalOfV2=1222723447469613917497`, USDC
`1968305934 | 1968305934`, USDe `2557834010080189682235 | 2557834010080189682235`.

### Impact

A named safety gate provides no protection, and no aggregate floor anchored on the pre-migration total
exists. **Story 083 makes this slightly more relevant**: it loosened the per-user bound, which is the only
real loss gate, from `+ 2 wei` to `+ 1000 wei` (083 line 159: *"WEI_SLACK 2 → 1000 loosens the per-user loss
bound (additive to the bps bound)"*). No asset impact is shown, because the per-user bound still catches a
real vault loss. The finding therefore stays at Low and is not High or Medium. The story-082 reviewer flagged
the defect (082 line 283, *"The 067 floor is close to a tautology"*; line 328, carried forward as `[low]`),
but no human has accepted it.

### Recommendation

Replace the check with a real aggregate gate anchored on the snapshot: require
`V2.totalStaked_after >= P * (MAX_BPS - maxLossBps) / MAX_BPS - n * WEI_SLACK`, where `P` is
`V1.migrationInfo(token).principalSnapshot` and `n` is the migrated staker count. With `WEI_SLACK = 1000` the
`n * WEI_SLACK` term is still economically negligible. Alternatively, rename the check (for example "V2
book/strategy lockstep") so that its NatSpec, inline comment and revert string no longer claim to be the
story-067 floor, and record the relaxation in story 082/083 as a human-accepted deviation.

---

## L-02 (still open, surface widened; cross-listed, primary report in `qa-report.md`): The post-broadcast `:preview` "verification" re-runs any unfinished step under prank instead of asserting it is done, so a partial or diverged mainnet cutover still verifies green

- **`issueId`**: `pps31l2`  ·  **First seen**: `phoenix-phase-2-staging-31`  ·  **Last seen**: `phoenix-phase-2-staging-32`
- **Fingerprint**: `2c82d65e65e163c9f986c669aaf0b56abcfc80ae9f91016dd3f84fc1fb6b7da7`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/CutoverStableStakerV2Mainnet.s.sol:run / _phase1.._phase7 (idempotent skip-if-done gates) / _phase8_wiringAssertions:VerificationPassSimulatesMissingSteps:stable-staker-v2-cutover`
- **Root cause class**: `VerificationPassSimulatesMissingSteps`  ·  **Severity**: Low (unchanged)  ·  **Ledger status**: `open` (unchanged)
- **Location**: [`script/CutoverStableStakerV2Mainnet.s.sol#L146-L190`](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L146-L190) (`run`), [#L510-L581](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L510-L581) (`_phase7_finalize`), [#L587-L643](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L587-L643) (`_phase8_wiringAssertions`)
- **Finding records**: `reports/32/findings/low/L-02-C1-verification-pass-simulates-missing-steps.json` (run-32 re-observation), `reports/31/findings/low/L-02-verification-pass-simulates-missing-steps.json` (original)

### Acceptance text this deviates from (verbatim)

story-082, line 63:

> **Preview doubles as post-broadcast verification.** Preview READS the progress file when one exists (read-only — preview never writes it). After a completed broadcast, every idempotent phase therefore detects it is already done and is skipped, and preview then runs the Phase 8 wiring assertions and the preview-only smoke tests (including the Antimatter mint-revocation proof) against the live deployed contracts.

story-082, line 147 (Concerns):

> - Verification: per user, no separate verify key — broadcast chains to `:preview`, which reads the progress file and re-runs wiring assertions and smoke tests against the live deployment.

`package.json` doc key `//stable-staker-v2-cutover:preview` (L50, unchanged at `884ccf8`):

> … It READS server/deployments/progress.stable-staker-v2-cutover.1.json when present, so AFTER a completed broadcast every idempotent phase detects - from on-chain state - that it is done and skips, and the run becomes the post-broadcast verification: Phase 8 wiring assertions plus the preview-only smoke tests against the live contracts.

Story 083 extends the same promise to the new V1 retirement steps. Line 131 (Implementation Notes):

> - **Preview**: `PREVIEW_MODE` uses `vm.startPrank(OWNER)`; OWNER is the Pauser owner so `unregister` succeeds in preview against live state (V1 is really registered there).

Line 171 (Execution Summary):

> Phase 1 skips when finalized (`v2.pauser() == PAUSER`) or when V1 is already paused, so a resumed or post-broadcast verification leg never re-pauses (which would revert) or misreads state.

### Deviation

Every phase has the form `if (!done) do();` and runs under `vm.startPrank(OWNER)` in preview. A step that did
**not** land on mainnet is therefore performed silently inside the simulation, and Phase 8 then checks the
simulated state. The stories describe preview detecting a *completed* broadcast and skipping. The code
actually *repairs* an incomplete one in simulation and reports the same success. 083 line 131 shows the
author knew `unregister` would really execute under prank in preview. That is fine before broadcast, but
after a broadcast the same property turns a missing on-chain step into a green verification.

**Surface widened by story 083.** `_phase7_finalize` now contains three more such gates, each of which preview
will perform instead of asserting:

```solidity
// script/CutoverStableStakerV2Mainnet.s.sol:554-567 (884ccf8)
if (IPausableLike(STABLE_STAKER_V1).pauser() != OWNER) {
    IPausableLike(STABLE_STAKER_V1).setPauser(OWNER);
}
...
if (IPauserRegistry(PAUSER).isRegistered(STABLE_STAKER_V1)) {
    IPauserRegistry(PAUSER).unregister(STABLE_STAKER_V1);
...
if (!IPausableLike(STABLE_STAKER_V1).paused()) {
    IPausableLike(STABLE_STAKER_V1).pause();
}
```

**Run-32 fork evidence** (fork @25978784):
- `test_C3_previewMasksMissingV1Retirement` (**new**): after a full cutover, V1 is unpaused, its pauser is set
  back to the Pauser and it is re-registered, then preview `run()` gives
  `MASK_V1_RETIRE|preview run() PASSED although V1 was registered+unpaused on-chain`.
- `test_C_previewMasksMissingRevoke`: `[PASS]`, the missing V1 phUSD revoke is still masked.
- `test_C2_previewMasksPausedV2`: `[PASS]`, a paused V2 is still masked.

A broadcast that halts after the Phase 7 revoke but before the V1 retirement would therefore "verify" green
while V1 is still registered and unpaused on chain. No direct loss is proven. The harm is that the operator's
only automated outcome check cannot see the divergence.

### Recommendation

Add an assert-only verification mode, following story-075's standalone `VerifyPromotionReady.s.sol`, that
never calls `vm.startPrank` / `vm.startBroadcast` and never mutates state. **Key it on on-chain state, not on
progress-file `deploymentStatus == completed`**, because progress files can be stamped `completed` during
forge's local pass (ledger `1e8cc0dc58ba`). In that mode every phase must
`require(alreadyDone, "verify: step X not on chain")` instead of performing the step. The checks must cover:

- V1 phUSD mint revoked;
- **the story-083 V1 retirement triple: `V1.pauser() == OWNER`, `!Pauser.isRegistered(V1)`, `V1.paused()`**;
- V2 and Antimatter unpaused, `V2.pauser() == Pauser`, the Antimatter minter set;
- V1 `stakerCount` / `totalStaked` per pool within the straggler allow-list;
- the per-user loss bound, re-checked from on-chain receipts (V1 `MigratedOut` / V2 `DepositedFor` events,
  or persisted pre-migration principals) against V2 `userInfo`, instead of the empty same-leg plan.

Separately, assert that the set of V1 stakers at the Phase-1 pause block equals the frozen planning set.

---

## Not in this report (for orientation)

- **`L-01`** (`pps31l1`, `e0d4df1ddb69…`), cross-listed here in run 31 against story-082 AC5 ("dust cannot
  grief (revert/stall) the cutover"). It was **not re-observed**. Story 083 set `WEI_SLACK = 1000`
  (`CutoverStableStakerV2Mainnet.s.sol` L112), and the fork harness refutes the stall:
  `test_L1_plantedDolaDust` gives `PLANTED_DUST|cutover PASSED|pre=8|postV2=5`, and `test_L2_dustSearch` over
  1..2000 wei gives `countAboveBound=0` (control `slack=2` gives `countAboveBound=319`). **`fixed` is proposed
  and not applied**: `/ledger phoenix-phase-2-staging fixed e0d4df1ddb69`. Its run-31 text stays in
  [`carryover/spec-conformance-31.md`](carryover/spec-conformance-31.md) until a human flips it.
- **`F-02`** (`pps31f2`) and **`F-03`** (`pps31f3`) were triaged **wont-fix** by the owner on 2026-09-14. They
  are suppressed and not re-graded.
- **New audit-32 findings are not faithfulness deviations**, so they appear only in `qa-report.md`:
  - **`L-04`** (`pps32l4`, `46c053534c58…`): from Phase 1 until Phase 7, V1 is paused with pauser OWNER but
    still registered, so the permissionless global `Pauser.pause()` reverts for all 26 registrants for the
    whole cutover session (fork: `GLOBAL_PAUSE|window-after-phase1|REVERTED`). The script follows story 083's
    wording. **Story-safety note (Law 1 over Law 2):** story 083's rationale, *"Once V1 is unregistered, that
    risk is gone"* (line 15), covers only the end state, and its ordering (unregister in Phase 7) creates the
    mid-run window. The gap is in the story's own safety reasoning, not in the implementation. A
    faithful-but-hazardous ordering is not blessed, and moving `Pauser.unregister(V1)` into Phase 1 is
    recommended before broadcast.
  - **`Q-02`** (`pps32q2`, `1c859cdebb64…`): the `//StableStakerV2Cutover` operator doc key still describes
    the superseded story-082 end state. This is a documentation defect. Story 083's comment-update checklist
    did not list `package.json`.
  - **`Q-03`** (`pps32q3`, `30510f331ea8…`): the DeployMocks rehearsal still uses `+ 2` wei and never rehearses
    the V1 retirement. Story 083 discloses this itself (line 273, carried forward as `[low]`). **Triaged wont-fix
    (invalid, out of scope) by owner 2026-09-15**: DeployMocks is a UI-testing mock stack, not a fidelity rehearsal
    of the mainnet cutover script.
- **`L-03`** (`pps31l3`) is not a story deviation. It is carried in
  [`carryover/qa-report-31.md`](carryover/qa-report-31.md). **`Q-01`** (`pps31q1`) was triaged wont-fix (invalid, out of
  scope) by owner 2026-09-15 and is not live.
