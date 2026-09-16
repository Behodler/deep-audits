# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 33)

**Project**: phoenix-phase-2-staging  ·  **Run**: `phoenix-phase-2-staging-33`
**Commit**: `29aeb2b6df9ade4b69d573c59268bce752a37c1d`, branch `master`  ·  **Baseline**: `884ccf8` (run 32)
**Entry point**: `stable-staker-v2-cutover` (`package.json` → `:preview` / `:broadcast` / `:verify`)
**Fork**: mainnet block 25981150; harness `phoenix-phase-2-staging/work/test/audit-run33/CutoverAuditRun33.t.sol` (12/12 PASS, `fork-logs/r33-ALL-summary.log`)
**Report scope**: Law-2 faithfulness only. This file is kept separate from the QA bundle on purpose, so story deviations are not buried among QA items.

This run has **no standalone F-XX finding** and **two Low findings cross-listed here** because they also break the
stories they implement. Both are new ledger entries. The primary write-ups are in `qa-report.md`. No High or Medium
exists, so no separate H/M submission is owed.

| Label | `issueId` | Fingerprint | Story graded against | Deviation type | Severity | Routing |
|---|---|---|---|---|---|---|
| **L-05** | `pps33l5` | `fc44ca36bccc…` | story-084 (close the global-pause window) | DECLARED-BUT-UNMET (the breaker is not live all session) | Low | cross-listed (primary: `qa-report.md`) |
| **L-06** | `pps33l6` | `cf4b531aee54…` | story-085 (aggregate floor) + story-086 (read-only verifier) | INTENT-MISMATCH (loss gate misreads a designed exit as a loss) | Low, **borderline Medium** | cross-listed (primary: `qa-report.md`) |

> **Labels are run-scoped.** Run-33 `L-05`/`L-06` continue this entry point's sequence (run 31: L-01..L-03, F-01..F-03,
> Q-01; run 32: L-04, Q-02, Q-03). Use the `issueId` or fingerprint as the stable handle.

Still-open faithfulness entries from earlier runs are carried in `carryover/`:
[`carryover/spec-conformance-31.md`](./carryover/spec-conformance-31.md) (`F-01` `pps31f1`, and the cross-listed
`L-01`/`L-02`). All three are **proposed `fixed`** by this run on fork evidence, **not applied**; see that file's header.

---

## Story resolution

Each tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree. Each returned exactly one document.

- **`[story-084]`** →
  `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/084-cutover-close-global-pause-window.md`
- **`[story-085]`** →
  `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/085-cutover-aggregate-principal-floor.md`
- **`[story-086]`** →
  `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/086-cutover-readonly-post-broadcast-verifier.md`
- **State folder: `auto-complete`** for all three. They were machine-approved through the story-batch workflow and no
  human has reviewed them. No human has signed off on either deviation below.

---

## L-05 *(cross-listed; primary report in `qa-report.md`)*: Phase 7 registers StableStakerV2 with the global Pauser while V2 is still paused, so `Pauser.pause()` reverts `EnforcedPause` for 3 transactions, or indefinitely if the run halts there

- **Fingerprint**: `fc44ca36bccc72681b8ec2f608c5539068ad4a705e4185adb16bd96ba88d43c5`
- **Location**: [`script/CutoverStableStakerV2Mainnet.s.sol#L605-L615`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L605-L615) (`_phase7_finalize`)
- **Related**: `L-04` (`pps32l4`, `46c053534c58…`) is the Phase-1 sibling that story 084 fixed. It is held open until this entry is dispositioned. `L-03` (`pps31l3`) is coverage context.

### Story text this deviates from (verbatim)

story-084, Story Overview:

> The StableStakerV2 mainnet cutover script (stories 082/083) disables the protocol's permissionless emergency
> breaker for the whole cutover session. [...] `Pauser.pause()` loops over every registrant
> with no try/catch, reaches V1, and reverts `StableStaker: only pauser`, so no registrant gets paused. A halt
> anywhere between Phase 1 and Phase 7 leaves the breaker dead indefinitely.

The story is titled *"close the mid-run global-pause window"*. Its review accepts exactly one residual window, and names it (Issues Found 3, and the carried-forward list):

> [low] In broadcast mode a one-transaction dead-breaker window remains between setPauser(OWNER) and
> Pauser.unregister(V1). The contract forces this order (unregister requires pauser() != Pauser), and the script
> NatSpec and the runbook doc key both tell the operator to resume a halted run or unregister V1 before walking away.

The script NatSpec written for story 084 states the resulting guarantee ([`L33-L36`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L33-L36) and L311):

> V1 is UNREGISTERED BEFORE it is paused so the permissionless
> global `Pauser.pause()` (which loops every registrant with no try/catch) stays live all session.

> Unregistering BEFORE pausing keeps the global breaker live for the entire Ledger session.

### Deviation

Story 084 fixed the V1 instance of the rule *never have a registrant that `pause()` cannot pause*. The same rule is broken for V2 in Phase 7.
V2 has been paused since Phase 3, and Phase 7 hands it back and registers it **before** unpausing it:

```solidity
if (v2.pauser() != PAUSER) v2.setPauser(PAUSER);                                                  // L605
if (!IPauserRegistry(PAUSER).isRegistered(address(v2))) IPauserRegistry(PAUSER).register(address(v2)); // L606
if (antimatter.pauser() != PAUSER) antimatter.setPauser(PAUSER);                                  // L607
if (!IPauserRegistry(PAUSER).isRegistered(address(antimatter))) {
    IPauserRegistry(PAUSER).register(address(antimatter));                                        // L609
}
...
if (!_doneV2Unpaused()) v2.unpause();                                                             // L614
```

Once `register(V2)` lands, `Pauser.pause()` reaches V2. V2's pauser is now the Pauser and V2 is already paused, so OZ `_pause()` reverts
`EnforcedPause()` and the whole global pause reverts. This lasts for 3 Ledger transactions: receipts #42 `register(V2)`, #43
`Antimatter.setPauser`, #44 `register(Antimatter)`, before #45 `unpause()` (`fork-logs/anvil-broadcast-gas-budget.txt`). The session
therefore has **two** dead-breaker windows, not the one the story accepts. The second is not forced: `unpause` is owner-or-pauser, and
`register` requires only `pauser() == Pauser`, so the unpause can come first.

Neither story-084 check can see it. The preview simulation runs only at `phase0`, `after-phase1` and `after-phase8`, and the
Phase-8 and `:verify` sweeps check only the end state. On a run halted inside the window, story 084's own runbook advice fails:
`:preview` reverts at phase0 with `first failing registrant: <V2>`, because the Decision-2 tolerance covers V1 only.

**Evidence**: `test_P7W_registeredWhilePausedWindow` PASS. `GLOBAL_PAUSE|P7-after-register(V2)|REVERTED|err=0xd93c0665`, and the same after
the two Antimatter steps. `HALTED_P7|preview run()|... first failing registrant: 0x5582...8161 (V2)`. Then
`P7-after-V2.unpause()|SUCCEEDED|registered=27`. Control `test_P7W_fixOrderingControl` PASS: with the unpause moved first, the breaker stays live after every
step. `test_P7W_haltedStateBroadcastResumeConverges` PASS.

### Why it stays Low

No asset moves. The window is 3 attended transactions, harm needs an independent emergency during it, and the owner at the keyboard can close it
with one `v2.unpause()`. The severity-auditor agreed with high confidence. It is also a Law-3 footgun, because an operator following story 084's
guidance, that a halt is dangerous only between `setPauser` and `unregister`, would be surprised.

### Recommendation

In `_phase7_finalize`, move `if (!_doneV2Unpaused()) v2.unpause(); require(_doneV2Unpaused(), ...)` to immediately after
`v2.setPauser(PAUSER)` and before `IPauserRegistry(PAUSER).register(address(v2))`. The finalized marker is unchanged, and a resume still
converges. Extend `test/CutoverStableStakerV2Mainnet.fork.t.sol` with a `Pauser.pause()` probe after each Phase-7 transaction. Correct the
NatSpec (L33-36, L76-80, L311) and the `:broadcast` doc key so they name the one remaining forced window.

---

## L-06 *(cross-listed; primary report in `qa-report.md`)*: The story-085 aggregate floor counts a staker's permissionless `V1.userMigrate` self-exit as V2 principal loss, so a correct cutover fails `:verify` with a false loss alarm, and a halted run cannot be resumed

- **Fingerprint**: `cf4b531aee540a854c4f68201857a360f1af1970c5e2800fc00673749f610abc`
- **Location**: [`script/helpers/StableStakerCutoverCore.sol#L427-L518`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/helpers/StableStakerCutoverCore.sol#L427-L518) (`_aggregatePrincipalFloor`, called from `_assertPoolPostMigration` L514), reached from [`script/VerifyStableStakerV2Cutover.s.sol#L223-L235`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/VerifyStableStakerV2Cutover.s.sol#L223-L235) and from every cutover Phase-6 resume leg
- **Severity**: Low, **borderline Medium, flagged for human review** (severity-auditor: AGREE low, medium confidence, borderline flag kept)
- **Related**: `F-01` (`pps31f1`) is the tautological floor this one replaced. `F-01` was a false-green; this is a false-red with a distinct root cause, so it is neither an incomplete fix nor a regression. `L-02` (`pps31l2`) is the verify chain, and its recheck names this as the only residual. `L-07` (`pps33l7`) compounds it: an ETH-shortfall halt is the likeliest trigger for the unresumable case.

### Story text this deviates from (verbatim)

story-085, Story Overview: the floor is meant to measure **loss**:

> No aggregate check anchors the migrated total on the
> pre-migration booked principal, which is what story 067 (and story 082 Phase 6, "realized ≥ booked principal
> (067)") asked for.

story-085, Implementation Note 1: the story's own reasoning for subtracting stragglers is that the floor must not fail on principal that legitimately never reaches V2:

> Subtracting straggler principal is required: stragglers stay on V1 by design and are not credited into V2, so
> anchoring on the raw `P` would fail every run that leaves dust behind.

story-085, Implementation Note 6: what the floor is meant to catch:

> The floor catches what the loop cannot see: resume legs (empty `plan.migratable`), and any
> divergence between `P` and the sum of planned `pre` amounts.

story-086, Implementation Notes 3 and 4: the verifier reuses the floor as its loss gate:

> - story 085's aggregate floor via `_assertPoolPostMigration` with an empty plan built from live state;

> The `pre → credit` haircut (R/P) is covered by the aggregate floor, not per user, because pre-migration amounts are
> not in events.

story-086, review note carried forward:

> the aggregate floor and straggler checks still bound each pool

The verifier NatSpec implementing story 086 already treats a self-exit as a designed non-loss path, but only for the per-user check
([`VerifyStableStakerV2Cutover.s.sol` L45-46](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/VerifyStableStakerV2Cutover.s.sol#L45-L46)):

> Self-exits via V1 `userMigrate` (which also emit `MigratedOut` but never deposit into V2) are
> excluded by their `UserMigrated` event.

### Deviation

The floor is `v2Staked >= (P - v1Staked) * (MAX_BPS - bps) / MAX_BPS - n * WEI_SLACK`, where `P` is `V1.migrationInfo(token).principalSnapshot`,
frozen at `initiateMigration`. `StableStakerV1.userMigrate` is permissionless and not pause-gated. It needs only
`poolState == Migrating`, so from the moment `initiateMigration` lands, any V1 staker can take their credit to their own wallet
(`lib/stable-staker/src/versions/v1/StableStakerV1.sol` L593-601). `batchMigrate` then skips them silently (L539). The self-exited
principal is still inside `P` and has left `v1Staked`, but V2 never receives it. `P - v1Staked` therefore overstates what was due to move by
exactly that principal. This is the same category of principal as stragglers: it legitimately never reaches V2. Story 085 subtracts stragglers for that reason
and does not subtract self-exits. The story also lists "divergence between `P` and the sum of planned `pre`" as a loss signal, which a benign self-exit
creates. Story 086 excludes self-exits from its per-user check but not from the floor it reuses.

Per-pool headroom at the fork block is about 0.24 DOLA, 0.236 USDC and 6.46 USDe. Any self-exit larger than that trips the floor even when every
remaining staker migrated within the bound. Under `--slow`, `initiateMigration` and `migrate` are separate transactions in separate blocks, so a
self-exit can land between them. The broadcast's local pass has already asserted, the chain ends correct, and every post-chain check that
re-reads live state fails.

**Evidence**: `test_SX_selfExitBetweenTxs_verifierFalseFailsOnFloor` PASS. One user self-exits 5.4999 DOLA and the other 29 positions migrate.
The real Phase 8 passes, but `floor 1222483056933011776952 > v2Staked 1217223596276947632021` and the verifier reverts
`cutover-post: V2 booked total below pre-migration principal floor (067)`. A preview `run()` on the same state reverts the same way.
Control `test_SX_controlNoSelfExit_verifierPasses` PASS, with 29 users re-checked. `test_SX_haltedResumeCannotFinish` PASS: halted after the
DOLA migrate, the resume `run()` reverts on the DOLA floor, the USDC pool stays Active, and V2 stays paused and unregistered.

### Impact on the stories' intent

- **Story 086**: on a correct cutover, `:verify`, which `:broadcast` chains after the patch, raises a principal-loss alarm when nothing was
  lost. It reverts inside `_verifyPhase6_migration`, so it also **skips** the Phase-7, per-user credit, registrant-sweep and Phase-8
  checks, and the chained `:preview` never runs. The story's post-broadcast verification becomes unusable whenever any V1 staker self-exits
  during the Migrating window, which a griefer can arrange for gas only.
- **Story 085**: the gate measures "principal that left V1" rather than loss. If a run halts after a pool's `migrate` and before Phase 7, every resume
  leg reverts on the floor, and the run cannot finish without editing the script. V2 stays paused and unregistered, the V1 phUSD mint stays live, and V2 stakers
  have only `emergencyWithdraw`. No funds are lost, and the owner can recover.

### Recommendation

Anchor the loss gate on quantities a self-exit cannot move.

- **(a) Preferred:** replace the P-anchored floor with an exit-realization bound read from V1:
  `(R, P) = V1.migrationInfo(token); require(min(R, P) * MAX_BPS >= P * (MAX_BPS - exitBps))`. Use `exitBps` of 0-2 for ERC4626 and
  `slippageToleranceBps + 1` for market strategies. Keep the per-user credit-to-credited check, in-leg in the cutover and from logs in the verifier.
- **(b)** Alternatively, keep the floor and subtract self-exited principal. In the verifier, sum the `UserMigrated` credits from the same log
  fetch and convert them back to principal. The cutover script cannot recover that from state, so (a) is preferable there.

Add a `StableStakerCutoverDust` / verifier fork test in which a staker calls `userMigrate` between `initiateMigration` and `migrate`.
Correct the story-086 claim that the floor "still bounds each pool". Before broadcast, fix this entry and top up OWNER (`L-07`).

---

## Not in this report (for orientation)

- **L-07** (`pps33l7`, `d6896c6e843d…`): OWNER's ETH covers the 46-transaction broadcast only at the pinned 0.3 gwei. It is an operational
  footgun rather than a story deviation, and it sits only in `qa-report.md`. It compounds L-06.
- **Q-02** (`pps32q2`, `1c859cdebb64…`): the `//StableStakerV2Cutover` operator doc key is still open and now also contradicts stories 084 and 085
  and omits `:verify`. Stories 084 and 086 explicitly left it out of scope, so it is documentation drift rather than a story deviation. It is carried in
  [`carryover/qa-report-32.md`](./carryover/qa-report-32.md).
- **Story-085 carried nits, not re-filed**: the lockstep revert string says `!=` for a `>=` check, and the floor revert string still ends `(067)`.
