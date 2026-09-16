# Script review: `stable-staker-v2-cutover` (phoenix-phase-2-staging, run 33)

| | |
|---|---|
| **Entry point** | `package.json` → `stable-staker-v2-cutover:preview`, `:broadcast`, `:verify` |
| **Source commit** | [`29aeb2b`](https://github.com/Behodler/phoenix-phase-2-staging/tree/29aeb2b6df9ade4b69d573c59268bce752a37c1d) on `master` (regression range `884ccf8..29aeb2b`: 12a36ba story-084, f453949 story-085, 2f9ee1c + 29aeb2b story-086) |
| **Fork** | Ethereum mainnet, block 25981150 (`RPC_MAINNET` liveness probe OK) |
| **Mainnet status** | **Not broadcast.** OWNER nonce 1631 (unchanged since run 32), no progress file, `StableStakerV2`/`Antimatter` placeholders still zero in `mainnet-addresses.ts` |
| **Ledger** | Not modified by this review. Every status change below is a proposal. |

Log and artefact paths below are relative to this directory
(`phoenix-phase-2-staging/reports/33/script-audits/stable-staker-v2-cutover/`).

---

## Conclusion

The cutover does what stories 082-086 ask of it, with two specific exceptions, and it is **fit to broadcast once three
pre-broadcast items are handled**: top up OWNER's ETH (L-07), reorder Phase 7 so V2 is unpaused before it is registered
with the global Pauser (L-05), and re-anchor the aggregate principal floor so a staker's own `userMigrate` exit is not
read as a loss (L-06).

- **No High or Medium.** Three new Lows (L-05, L-06, L-07). L-06 is flagged **borderline Medium** for human review. One
  QA carryover (Q-02) is still live.
- **Evidence is empirical.** The live preview passes at 25981150. A full anvil mainnet-fork chain
  `--broadcast → patch → :verify → :preview` ran end to end: 46 transactions, 18,317,077 gas, `:verify` passed with
  29/29 per-user credits re-checked, and `:verify` failed correctly on both negative runs. The run-33 fork harness
  passes 12/12.
- **Side effects are contained.** Exactly 20 accounts are written, the same set as run 32, and every write is intended.
- **Prior findings.** L-01, L-02, L-03 and F-01 are proposed `fixed` (not applied). L-04 is fixed for its Phase-1
  mechanism but held open pending L-05. Q-02 is still live.
- **Authority caveats.** All five governing stories sit in `auto-complete/` and were machine-approved, not human-reviewed.
  `src/known-issues.md` does not exist at `29aeb2b` and the registry's `knownIssuesSource` is `null`, so the 11-entry
  known-issues cache carries no suppression authority. Nothing was suppressed on its basis.

---

## 1. Does it do what it intends?

**Yes, except for the two story deviations filed as L-05 and L-06.**

### Story authority (Law 2)

Each tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree and returned exactly one
document. All five are in `auto-complete/phStaging2-stable-staker-v2/`, a non-standard state folder: they were approved
by the story-batch workflow with reduced review independence (`--inline-delegation`), and no human has signed them off.
That does not change any grade below, but no acceptance criterion here has human-confirmed intent behind it.

| Story | Role at 29aeb2b | Result |
|---|---|---|
| story-082 | Base cutover intent (as amended by 083-086) | Every stated purpose line holds on the fork |
| story-083 | `WEI_SLACK = 1000`; V1 retire triple | Met (8-wei DOLA and 2-wei USDC planted dust pass) |
| story-084 | Close the mid-run global-pause window | Met for Phase 1; **not met** for "breaker stays live all session" (L-05) |
| story-085 | Real aggregate principal floor; lockstep rename | Met for haircut detection; **gap** on self-exits (L-06) |
| story-086 | Read-only post-broadcast verifier chained before preview | Met; inherits the L-06 floor gap |

### Acceptance criteria, fork-checked

**story-084 (global-pause window).**
- [x] Phase 1 runs `setPauser(OWNER)` → `Pauser.unregister(V1)` → `pause()`, each gated and read back
  ([`_retireV1`, L329-L348](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L329-L348)).
  A simulated EYE-funded `Pauser.pause()` after every Phase-1 transaction and after phases 2-6 reverts only in the single
  forced transaction between `setPauser(OWNER)` and `unregister` (`r33-test_L04_breakerAtEveryPhase1StepAndPhase.log`).
- [x] The "V1 already paused - skipped" early return is gone; resumes converge. Phase 7 keeps `_retireV1` as a backstop.
- [x] `_assertGlobalPauseWorks` runs at phase0, after-phase1 and after-phase8. Live preview:
  `SUCCEEDED` with 26, 25 and 27 registrants (`preview-25981150.log`). Phase 8 sweeps every registrant.
- [ ] **"Breaker stays live all session" is false.** Phase 7 registers V2 while V2 is still paused, opening a second,
  unforced 3-transaction `EnforcedPause` window. → **L-05**.

**story-085 (aggregate floor).**
- [x] Loud requires `P > 0` and `P >= v1Staked`; floor with saturating slack
  ([`StableStakerCutoverCore.sol` L427-L518](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/helpers/StableStakerCutoverCore.sol#L427-L518)).
- [x] Falsification on real contracts: a 5 bps DOLA exit haircut trips the floor on the resume/verifier shape while the
  old lockstep passes it; a 1 bps haircut, inside the 2 bps bound, passes (`r33-test_F01_*.log`). Story-085 unit tests
  spot-reproduced 5/5 (`spot-story085-aggregateFloor.log`).
- [x] Lockstep renamed (still `>=` with a `!=` revert string; carried nit, not re-filed).
- [ ] **The floor treats a permissionless `V1.userMigrate` self-exit as principal loss.** → **L-06**.

**story-086 (read-only verifier).**
- [x] `run()` is virtual; phase gates and verifier share the `_done*` / `_v1*` predicates. The verifier rejects
  `PREVIEW_MODE`, checks addresses have code, ignores `deploymentStatus`, and never performs a step.
- [x] `:broadcast` chains `patch && :verify && :preview`; the `:preview` doc key no longer claims to verify.
- [x] **Live hydration exercised end to end** (see below). Provider accepted `eth_getLogs` ranges of 5000, 20001 and
  100001 blocks (`rpc-getlogs-range-probe.txt`). Story guard `test_fork_v2Paused_verifierReverts` spot-reproduced
  (`spot-story086-test_fork_v2Paused_verifierReverts.log`).
- [ ] The verifier's floor inherits L-06 and can report a loss on a correct cutover.

**story-082 / 083 (still in force).**
- [x] Phase 1 V1 retirement; Antimatter ("Antimatter"/"AM", owner OWNER) wired to phUSD and PhusdStableMinter;
  StableStakerV2 deployed and paused before any `addToken`; per-token wiring with `antimatterPerDay = C*21/10` and V1's
  buffer percentages; mint rights with the two-sided minter delta (mask 511 → 510).
- [x] Migration: surplus relinquished (DOLA 26.898 DOLA, USDC 27.043385 USDC), 9/13/7 users migrated per pool, 0
  stragglers, per-user bounds (2 bps / 61 bps + 1000 wei) all pass.
- [x] Finalize: buffer recipients → V2 (DOLA/USDC), V1 mint revoked, V2 and Antimatter registered with the Pauser, V2
  unpaused, `claimEnabled` false. Smoke tests pass.
- [ ] The `package.json` `//StableStakerV2Cutover` operator key (L49) is still stale. → **Q-02** (carryover).

### Execution evidence

| Leg | Command shape | Result | Log |
|---|---|---|---|
| Preview (live mainnet fork) | `PREVIEW_MODE=true forge script … --fork-block-number 25981150` | exit 0; 3 × `GLOBAL_PAUSE … SUCCEEDED`; smoke tests pass | `fork-logs/preview-25981150.log` |
| Broadcast (anvil fork, `--unlocked` in place of `--ledger`, all other flags verbatim) | `forge script … --broadcast --skip-simulation --slow --legacy --with-gas-price 0.3gwei --gas-estimate-multiplier 200` | `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`, **46 txs, 18,317,077 gas**; progress file `completed`, `cutoverStartBlock` 25981150 | `fork-logs/anvil-broadcast-leg1.log` |
| Patch | `patch-mainnet-addresses-stable-staker-v2.js` | exit 0; fills StableStakerV2 + Antimatter; key-set 55/55 | `fork-logs/anvil-patch.log` |
| `:verify` (real verifier, live hydration + `vm.eth_getLogs`) | `forge script script/VerifyStableStakerV2Cutover.s.sol …` | `CUTOVER VERIFIED ON CHAIN`; events 29/0/29; **29/29** per-user credits re-checked | `fork-logs/anvil-verify-clean.log` |
| `:verify` negative: OWNER re-grants V1 phUSD mint | same | exit 1, `verify: Phase7: phUSD.setMinter(V1, false) revoke not on chain` | `fork-logs/anvil-verify-v1MintRegranted.log` |
| `:verify` negative: `CUTOVER_START_BLOCK=25981196` | same | exit 1, `verify: per-user: no MigratedOut/DepositedFor pair found for DOLA although principal moved` (vacuity guard) | `fork-logs/anvil-verify-lateStartBlock.log` |
| `:preview` after verify (smoke leg) | same as preview, against anvil | exit 0; every phase skipped as done; 3 × `GLOBAL_PAUSE SUCCEEDED (27)` | `fork-logs/anvil-preview-postverify.log` |
| Fork harness | `forge test --match-path test/audit-run33/CutoverAuditRun33.t.sol` | **12 passed, 0 failed** | `fork-logs/r33-ALL-summary.log` |

All preconditions passed at the fork block (owners, V1 pauser = Pauser, token/strategy map, no strategy paused, minter
registration and decimals, V1 mint baseline mask 511). Nothing was sent to mainnet; `work/` was restored after the anvil
run.

---

## 2. Does it introduce unintended side effects?

**No unintended persistent state. Two transient operational hazards: L-05 and L-07.**

### State written

`vm.startStateDiffRecording` over the real phases 0-7 shows **20 accounts written**, the same set as run 32
(`fork-logs/r33-test_A_stateDiff.log`). No contract outside the closure is written.

| Account | Writes | Intended |
|---|---|---|
| StableStakerV1 `0xbce8…079A` | pauser Pauser → OWNER; paused; migrator → CVM; 3 pools Migrating; `migrationInfo` snapshots; 29 staker removals; `totalStaked` → 0 | yes |
| Pauser `0x7c5A…85a3` | `unregister(V1)` (26 → 25, swap-and-pop reorder, benign); `register(V2)`, `register(Antimatter)` (→ 27) | yes |
| phUSD `0xf3B5…D605` | minters V2 and Antimatter added, V1 removed (511 → 510); pending-reward mints | yes |
| YS_DOLA / YS_USDC / YS_USDE | V2 client, set-aside buffers 10/10/25, recipient → V2 (DOLA/USDC), V1 surplus relinquished, principal moved | yes |
| Antimatter (new) `0x7Bf5…0A5F` | owner, phUSD, minter, approved minter {V2}, pauser | yes |
| StableStakerV2 (new) `0x5582…8161` | 3 pools, strategies, rates, migrator, 29 users, pauser = Pauser, unpaused | yes |
| CrossVersionMigrator (new) `0x7068…11f6` | reentrancy slot | yes |
| External vaults, Curve pools, router, tokens | share and reserve balances from V1 exits and V2 deposits | yes |

The harness address `0x5615…b72f` is forge's own script storage. Residual, inert state (CVM keeps the migrator role on
V1 and V2; V1 idle set-aside buffers stay on V1) is covered by ledger F-02 (`436848b0e3`, wont-fix) and is not re-filed.

### Unintended effects

- **L-05, transient dead breaker in Phase 7.** For broadcast transactions #42-#44 (`register(V2)`,
  `Antimatter.setPauser`, `register(Antimatter)`) every permissionless `Pauser.pause()` reverts `EnforcedPause` and
  pauses none of the 26-27 registrants, including the live strategies. A halt inside that window keeps the breaker dead
  until someone resumes or sends `v2.unpause()`, and the runbook's `:preview` reverts at phase0 on that state. Moving the
  unpause first removes the window (`r33-test_P7W_fixOrderingControl.log`).
- **L-07, ETH budget.** OWNER holds 0.005642 ETH. The 46-transaction run costs 0.005495 ETH at the pinned 0.3 gwei,
  leaving 0.000147 ETH. At 0.31-0.35 gwei the node's upfront balance check rejects tx #37 (USDe `migrate`); at 0.4 gwei
  it rejects tx #32 (DOLA `migrate`). The run halts mid-Phase 6. It is resumable after a top-up, but the doc key's own
  "re-check base fee before signing" advice leads straight into it, and `--skip-simulation` suppresses forge's only ETH
  estimate (`fork-logs/anvil-broadcast-gas-budget.txt`).

---

## 3. Does it cause knock-on problems elsewhere?

**One real knock-on (L-06), which compounds with L-07, plus one unverified lead.**

- **L-06, false-red verifier and blocked resume.** From the moment a pool's `initiateMigration` lands, any V1 staker can
  call the permissionless, un-pause-gated `userMigrate` and take their credit to their wallet. The aggregate floor still
  counts that principal as due to V2. Per-pool headroom at the fork block is only ~0.24 DOLA, ~0.236 USDC and ~6.46 USDe,
  so any larger self-exit trips it. On a correct cutover, `:verify` then reverts with
  `V2 booked total below pre-migration principal floor (067)` inside Phase 6, **skipping** its Phase 7, per-user,
  registrant-sweep and Phase 8 checks, and the chained `:preview` never runs
  (`r33-test_SX_selfExitBetweenTxs_verifierFalseFailsOnFloor.log`; control passes 29/29). If the broadcast had already
  halted after that pool's `migrate`, every resume leg reverts on the same floor and cannot finish without a script edit:
  V2 stays paused and unregistered, the V1 mint stays live, and migrated V2 stakers have only `emergencyWithdraw`
  (`r33-test_SX_haltedResumeCannotFinish.log`). No funds are lost, and the owner can recover manually. The failure is
  loud, not silent.
- **L-06 × L-07 compounding.** Independent root causes and fixes, but an L-07 ETH halt at tx #37 plus any self-exit
  produces exactly the unresumable state above. Fixing either removes the combination; fixing both is recommended.
- **Lead, UNVERIFIED: USDe AMM `minOut` halt.** The USDe `initiateMigration` (tx #36) swaps through an AMM with an on-chain
  `minOut` of `ideal * (1 - slippageToleranceBps)`. A price move beyond tolerance, natural or pushed, would revert #36
  after the DOLA/USDC migrations landed and halt the run, giving a third-party-influenced trigger for the L-06 resume
  block. This has **not** been checked against the live USDe strategy bytecode. A griefer pays round-trip AMM losses for
  no gain. If confirmed cheap, it is an upgrade trigger for L-06 to Medium.
- **Coverage gaps in the project's own tests (observations, not findings).** No self-exit case exists in
  `StableStakerCutoverDust.t.sol` or the verifier guards; the story-084 fork test probes the breaker at three stages only
  and cannot see the Phase-7 window; `test_fork_cleanCompletedState_verifierPasses` runs after a preview smoke test that
  leaves a 1000-DOLA organic stake in V2, which can mask the DOLA floor (source read, not executed).
- **Sibling scripts.** DeployMocks' divergence is the owner-ruled Q-01/Q-03 class (UI mock, not a rehearsal); not
  re-filed. The out-of-band OWNER unregister of the two formerly paused registrants still holds (26 healthy registrants
  at the fork block).

### Prior findings recheck

| Label | Issue ID | Ledger status | Verdict | Proposal | Basis |
|---|---|---|---|---|---|
| L-01 | `pps31l1` | open | LIKELY-FIXED | `fixed` (second proposal) | `WEI_SLACK = 1000`; planted dust passes (`r33-test_L01_plantedDust.log`) |
| L-02 | `pps31l2` | open | LIKELY-FIXED | `fixed` | Read-only verifier chained before preview; live anvil chain green, both negatives red. Residual is L-06 (false-red, new root cause) |
| L-03 | `pps31l3` | open | LIKELY-FIXED | `fixed` | after-phase8 simulated pause `SUCCEEDED (27)` plus registrant sweep. Residual is L-05 |
| F-01 | `pps31f1` | open | LIKELY-FIXED | `fixed` | 5 bps haircut trips the new floor while the lockstep passes. Residual is L-06 |
| L-04 | `pps32l4` | open | Fixed for its Phase-1 mechanism | **hold open** until L-05 is dispositioned | Only the forced 1-tx window remains in Phase 1; sibling L-05 still breaks the story-084 "whole session" claim |
| Q-02 | `pps32q2` | open | STILL-LIVE | none | `package.json` L49 byte-unchanged; now also contradicts 084/085 and omits `:verify` |

F-02, F-03, Q-01 and Q-03 are wont-fix and were not re-filed; nothing in the delta touches their root causes.

### Tooling and authority notes

- **Known issues.** `src/known-issues.md` is absent at `29aeb2b` (no history for the path) and `knownIssuesSource` is
  `null` in the registry. The sanitizer compared against the 11-entry cache only, found no match, and removed nothing.
  The cache has no suppression authority and no in-source NatSpec was used as one.
- **4naly3er failed** at compilation (`@forge-std/Script.sol import not found`): the project resolves imports only through
  `foundry.toml` and has no `remappings.txt`. The staged-remappings fallback was not repeated (it timed out in runs 31
  and 32). No bot baseline exists for this run; all findings come from the script pipeline, fork harness and anvil
  rehearsal.

---

## Findings register

Code links are pinned to `29aeb2b`. "Record" links go to the run's finding JSON; "Report" links go to the primary
write-up. Labels are run-scoped; use the issue ID or fingerprint as the stable handle.

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-05** `pps33l5` | Low | Phase 7 registers V2 with the Pauser while V2 is still paused, so `Pauser.pause()` reverts `EnforcedPause` for 3 txs (indefinitely on a halt); breaks story-084's "live all session" | In `_phase7_finalize`, move `v2.unpause()` + `require(_doneV2Unpaused())` to directly after `v2.setPauser(PAUSER)` and before `register(V2)`; add a per-tx `Pauser.pause()` probe across Phase 7 to the fork test; correct NatSpec L33-36/L76-80 and the `:broadcast` key to name the one forced window | [`CutoverStableStakerV2Mainnet.s.sol#L605-L615`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L605-L615) · Report: [`qa-report.md` L-05](../../submissions/qa-report.md) · [`spec-conformance.md` L-05](../../submissions/spec-conformance.md) · Record: [`L-05…json`](../../findings/low/L-05-phase7-registered-while-paused-window-bricks-global-pause.json) |
| **L-06** `pps33l6` | Low (**borderline Medium**) | Aggregate floor counts a permissionless `V1.userMigrate` self-exit as V2 loss: correct cutover fails `:verify` (skipping later checks) and a halted run cannot resume | (a) Preferred: replace the P-anchored floor with an exit-realization bound from `V1.migrationInfo`: `min(R,P)*MAX_BPS >= P*(MAX_BPS - exitBps)` (0-2 bps ERC4626, `slippageToleranceBps+1` market), keeping the per-user credit checks; (b) or subtract self-exited principal from `UserMigrated` logs in the verifier. Add a self-exit fork test; correct the story-086 NatSpec claim | [`StableStakerCutoverCore.sol#L427-L518`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/helpers/StableStakerCutoverCore.sol#L427-L518), [`VerifyStableStakerV2Cutover.s.sol#L223-L235`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/VerifyStableStakerV2Cutover.s.sol#L223-L235) · Report: [`qa-report.md` L-06](../../submissions/qa-report.md) · [`spec-conformance.md` L-06](../../submissions/spec-conformance.md) · Record: [`L-06…json`](../../findings/low/L-06-aggregate-floor-counts-self-exit-as-loss.json) |
| **L-07** `pps33l7` | Low | OWNER's ETH covers the 46-tx run only at 0.3 gwei (0.000147 ETH spare); ≥ 0.31 gwei halts at tx #37 mid-Phase 6; no budget stated or checked | Broadcast-mode Phase 0 pre-flight `require(OWNER.balance >= CUTOVER_GAS_BUDGET * tx.gasprice * 12/10)` with `CUTOVER_GAS_BUDGET ≈ 18.4M`; state the ETH budget in the `:broadcast` doc key (e.g. ≥ 0.0064 ETH at 0.35 gwei) | [`CutoverStableStakerV2Mainnet.s.sol#L236-L298`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L236-L298), [`package.json#L52-L53`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/package.json#L52-L53) · Report: [`qa-report.md` L-07](../../submissions/qa-report.md) · Record: [`L-07…json`](../../findings/low/L-07-missing-gas-budget-preflight.json) |
| **Q-02** `pps32q2` (carryover, still live) | QA | `//StableStakerV2Cutover` operator key describes the superseded 082 end state; contradicts 084/085; omits `:verify` | Rewrite the key to match 082 as amended by 083-086 (Phase-1 retirement with V1 left paused, 2/61 bps + 1000 wei, aggregate floor plus lockstep, `patch && :verify && :preview`), or reduce it to a pointer to the script NatSpec and per-variant keys | [`package.json#L49`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/package.json#L49) · Report: [`carryover/qa-report-32.md` Q-02](../../submissions/carryover/qa-report-32.md) · Record: [`Q-02…json`](../../findings/qa/Q-02-C1-operator-doc-key-describes-superseded-end-state.json) |
| L-04 `pps32l4` (prior; **hold open**) | Low | Phase-1 → Phase-7 V1 registered-while-paused window | Implemented by story 084 (unregister V1 before pausing it; simulated pause at 3 stages). No further change; close once L-05 is dispositioned | [`CutoverStableStakerV2Mainnet.s.sol#L329-L348`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L329-L348) · Report: [`carryover/qa-report-32.md` L-04](../../submissions/carryover/qa-report-32.md) |
| L-01 `pps31l1` (prior; **proposed `fixed`**) | Low | Fixed 2-wei slack below autoDOLA rounding stalled dust | Implemented by story 083 (`WEI_SLACK = 1000`); no further change | [`CutoverStableStakerV2Mainnet.s.sol#L130`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L130) · Report: [`carryover/qa-report-31.md` L-01](../../submissions/carryover/qa-report-31.md) |
| L-02 `pps31l2` (prior; **proposed `fixed`**) | Low | Post-broadcast `:preview` "verification" performed missing steps under prank | Implemented by story 086 (read-only verifier chained before preview); address residual via L-06 | [`VerifyStableStakerV2Cutover.s.sol#L79`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/VerifyStableStakerV2Cutover.s.sol#L79), [`package.json#L53`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/package.json#L53) · Report: [`carryover/qa-report-31.md` L-02](../../submissions/carryover/qa-report-31.md) |
| L-03 `pps31l3` (prior; **proposed `fixed`**) | Low | Phase 8 asserted registration, not a working breaker | Implemented by story 084 (after-phase8 simulated pause and registrant sweep); intra-Phase-7 residual via L-05 | [`CutoverStableStakerV2Mainnet.s.sol#L226`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L226), [`#L723`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L723) · Report: [`carryover/qa-report-31.md` L-03](../../submissions/carryover/qa-report-31.md) |
| F-01 `pps31f1` (prior; **proposed `fixed`**) | Faithfulness | "067 floor" compared two identically booked numbers and could not fail | Implemented by story 085 (P-anchored aggregate floor, lockstep renamed); self-exit residual via L-06 | [`StableStakerCutoverCore.sol#L427-L527`](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/helpers/StableStakerCutoverCore.sol#L427-L527) · Report: [`carryover/spec-conformance-31.md` F-01](../../submissions/carryover/spec-conformance-31.md) |

---

## Before broadcast: operator checklist

Derived from the finding recommendations. Items 1-3 are recommended as blocking.

1. **Top up OWNER (L-07).** Fund `0xCad1…D0B6` well above the 0.3 gwei cost of 0.005495 ETH: at least ~0.0064 ETH to
   survive 0.35 gwei, with a margin for the gas-limit multiplier and any resume leg. Re-check the base fee immediately
   before signing. Ideally also land the Phase 0 `OWNER.balance` pre-flight so the script refuses to start underfunded.
2. **Reorder Phase 7 (L-05).** Move `v2.unpause()` and its `require` to directly after `v2.setPauser(PAUSER)` and before
   `Pauser.register(V2)`. Add the per-transaction breaker probe to `test/CutoverStableStakerV2Mainnet.fork.t.sol`, and
   correct the NatSpec and `:broadcast` doc key so the only dead-breaker window named is the single forced transaction
   between `V1.setPauser(OWNER)` and `Pauser.unregister(V1)`.
3. **Re-anchor the loss floor (L-06).** Replace the P-anchored aggregate floor with the exit-realization bound read from
   `V1.migrationInfo(token)` (`min(R,P) * MAX_BPS >= P * (MAX_BPS - exitBps)`), in both the cutover and the verifier, and
   add a fork test in which a staker calls `userMigrate` between `initiateMigration` and `migrate`.
   *If broadcasting before this lands:* treat a `:verify` revert on `below pre-migration principal floor (067)` as a
   prompt to check V1 `UserMigrated` events for the pool, not as a confirmed loss, and do not take emergency action on it
   alone.
4. **Rewrite the operator doc key (Q-02).** Make `//StableStakerV2Cutover` match stories 082-086, or reduce it to a pointer.
5. **Re-run `:preview` at a fresh block** after any code change and before signing. Confirm three
   `GLOBAL_PAUSE … SUCCEEDED` lines, all per-user bounds, and the aggregate-floor headroom per pool.
6. **Check the USDe strategy's on-chain slippage behaviour** (unverified lead): confirm `slippageToleranceBps` and the
   `minOut` path on the live USDe strategy, and consider the AMM price just before tx #36.
7. **Do not walk away from a halted run.** Resume immediately. If halted in Phase 1 between `setPauser(OWNER)` and
   `unregister`, at least call `Pauser.unregister(V1)`. Until L-05 is fixed, if halted in Phase 7 after `register(V2)`,
   send `v2.unpause()` before running `:preview`.
8. **Resume hygiene** (existing runbook): trim the progress file to on-chain-confirmed deployments using
   `run-latest.json` receipts and `cast nonce`, keep the baselines block verbatim, then re-run `:broadcast`.
9. **Run `:verify` immediately after broadcast** (the `:broadcast` chain does this). Its floor and `userInfo` checks read
   live balances that later organic withdrawals can legitimately lower.
10. **Human sign-off on stories 082-086.** They are machine-approved only; confirm the intended behaviour above before
    relying on it on mainnet.

---

## Ledger proposals (not applied)

This review changed no ledger status. The commands below are proposals for a human to run.

```text
# Prior findings proposed fixed on run-33 fork evidence
/ledger phoenix-phase-2-staging fixed e0d4df1ddb69   # L-01 pps31l1
/ledger phoenix-phase-2-staging fixed 2c82d65e65e1   # L-02 pps31l2
/ledger phoenix-phase-2-staging fixed 0711215fcc17   # L-03 pps31l3
/ledger phoenix-phase-2-staging fixed dfed42790952   # F-01 pps31f1

# Only after L-05 (fc44ca36bccc) is dispositioned
/ledger phoenix-phase-2-staging fixed 46c053534c58   # L-04 pps32l4
```

New entries L-05 (`fc44ca36bccc`), L-06 (`cf4b531aee54`) and L-07 (`d6896c6e843d`) and carryover Q-02 (`1c859cdebb64`)
remain `open`. If the owner commits to fixing them, the correct status is `fix-pending`, not `acknowledged`, so they stay
visible to future scans until a fix is verified. L-06's borderline-Medium flag is for human triage.
