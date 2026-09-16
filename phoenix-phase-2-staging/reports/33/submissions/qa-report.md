# QA Report: phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 33)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `29aeb2b6df9ade4b69d573c59268bce752a37c1d` (branch `master`). Baseline `884ccf8` (run 32).
- **Entry point**: `stable-staker-v2-cutover` (`package.json` → `stable-staker-v2-cutover:preview` / `:broadcast`, with the story-086 `:verify` tail)
- **Stories**: story-084 (V1 retirement / breaker liveness), story-085 (aggregate principal floor), story-086 (read-only post-broadcast verifier), all under `~/code/product-owner/stories/phStaging2/`.
- **Fork harness**: `phoenix-phase-2-staging/work/test/audit-run33/CutoverAuditRun33.t.sol`, mainnet fork at block **25981150**, inheriting the unmodified script, core and verifier. Summary: `fork-logs/r33-ALL-summary.log` (12/12 PASS).
- **Anvil rehearsal**: full 46-tx `:broadcast`-flag run on a local anvil fork of 25981150 (`fork-logs/anvil-broadcast-leg1.log`, `fork-logs/anvil-broadcast-gas-budget.txt`).
- **Log paths** below are relative to `phoenix-phase-2-staging/reports/33/script-audits/stable-staker-v2-cutover/`.

## Summary

| Severity | New this run | Total in this bundle |
|----------|-------------:|---------------------:|
| Low Risk | 3 | 3 |
| Centralization | 0 | 0 |
| **Total** | **3** | **3** |

This run produced no centralization findings.

| Label | Issue ID | Fingerprint | Title (short) | Verified | Recommended before broadcast |
|---|---|---|---|---|---|
| L-05 | `pps33l5` | `fc44ca36bccc…` | Phase 7 registers V2 while paused; global `Pauser.pause()` reverts for 3 txs | fork + anvil receipts | **yes** |
| L-06 | `pps33l6` | `cf4b531aee54…` | Aggregate floor counts a `userMigrate` self-exit as loss; `:verify` false-fails, resume blocked (**borderline Medium**) | fork | **yes** |
| L-07 | `pps33l7` | `d6896c6e843d…` | OWNER ETH barely covers the 46-tx run; halts mid-Phase 6 at ≥ 0.31 gwei | anvil | **yes** |

> **Labels are run-scoped.** L-05..L-07 continue this entry point's per-entry-point sequence (run 31: L-01..L-03; run 32: L-04). Use the `issueId` or fingerprint as the stable handle.

### Carryover QA (not re-sectioned here)

- **Q-02** (`pps32q2`, fingerprint `1c859cdebb6424756c073b1358559f38d84feff33eb6f6a6563414e352a03542`) is still open and was re-observed at `29aeb2b`: the `package.json` `//StableStakerV2Cutover` operator doc key (L49) still describes the superseded story-082 end state, and now also contradicts stories 084/085 and omits the story-086 `:verify` step. Full text and audit-33 disposition: [`carryover/qa-report-32.md`](./carryover/qa-report-32.md).
- **L-04** (`pps32l4`) is held open in the same carryover file pending disposition of L-05 below (sibling mechanism, not a duplicate).
- Run-31 carryover entries: [`carryover/qa-report-31.md`](./carryover/qa-report-31.md).

### Faithfulness cross-listing

L-05 (story-084) and L-06 (stories 085/086) are also Law-2 deviations and are cross-listed in [`spec-conformance.md`](./spec-conformance.md). This file is their primary report. L-07 has no story anchor and appears only here.

### Compounding note

L-06 and L-07 have independent root causes and independent fixes, but they compound: an L-07 ETH-shortfall halt inside Phase 6, combined with any V1 `userMigrate` self-exit, produces a halted cutover that cannot be resumed without editing the script. Fixing either one removes that combination.

---

## Low Risk Findings

### [L-05] Phase 7 registers StableStakerV2 with the global Pauser while V2 is still paused, so the permissionless `Pauser.pause()` reverts `EnforcedPause` for 3 transactions, and indefinitely if the run halts there <!-- id: pps33l5 -->

**Recommended before broadcast.**

- **Severity**: Low (operational hazard / footgun, Law 3; Law-2 deviation from story-084)
- **Entry Point**: `stable-staker-v2-cutover`
- **Fingerprint**: `fc44ca36bccc72681b8ec2f608c5539068ad4a705e4185adb16bd96ba88d43c5`
- **Story**: story-084
- **Root cause**: [CutoverStableStakerV2Mainnet.s.sol#L605-L615](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L605-L615) (`_phase7_finalize`)

```solidity
if (v2.pauser() != PAUSER) v2.setPauser(PAUSER);                                                         // L605
if (!IPauserRegistry(PAUSER).isRegistered(address(v2))) IPauserRegistry(PAUSER).register(address(v2));   // L606
if (antimatter.pauser() != PAUSER) antimatter.setPauser(PAUSER);                                         // L607
    ...  IPauserRegistry(PAUSER).register(address(antimatter));                                          // L609
// unpause is owner-or-pauser, so it works after the pauser hand-back.
if (!_doneV2Unpaused()) v2.unpause();                                                                    // L614
```

- **Also relevant**: `lib/pauser/src/Pauser.sol` L56-69 (nested `Behodler/pauser` @ `545928d0`): `pause()` loops `IPausable(_pausableContracts[i]).pause()` with no try/catch. Script NatSpec [L33-L36](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L33-L36) claims the global breaker "stays live all session".

**Description**

V2 is paused in Phase 3 (pauser OWNER) and stays paused through the migration. Phase 7 then hands V2's pauser to the Pauser (L605), registers V2 (L606), hands over and registers Antimatter (L607, L609), and only then unpauses V2 (L614). Once `register(V2)` lands, `Pauser.pause()` reaches V2, whose pauser is now the Pauser, and OpenZeppelin `_pause()` reverts `EnforcedPause()` because V2 is already paused. The whole global pause reverts.

This is the same registered-while-paused brick that story 084 fixed for V1 in Phase 1 by unregistering V1 before pausing it. The mirror rule for V2, unpause before registering, is not applied. The ordering is not forced: `unpause` is owner-or-pauser, and `register` only requires `pauser() == Pauser`. The preview's simulated global pause runs only at Phase 0, after Phase 1 and after Phase 8, and the Phase 8 / `:verify` sweep checks only the end state, so nothing in the repository detects the intra-Phase-7 window.

**Impact**

For 3 Ledger-signed transactions near the end of the session (broadcast txs #42 `register(V2)`, #43 `Antimatter.setPauser`, #44 `register(Antimatter)`), every EYE-funded `Pauser.pause()` reverts and pauses none of the 26-27 registrants, including the live strategies YS_DOLA / YS_USDC / YS_USDE. If the session halts inside that window (Ledger timeout, RPC error, operator interrupt), the permissionless breaker stays unavailable until someone resumes or sends `v2.unpause()`.

On that halted state the runbook's "run `:preview` before resuming" step reverts at Phase 0 with `first failing registrant: <V2>`, because the simulation's tolerance covers V1 only, so the operator loses the rehearsal without a clear explanation. A broadcast-mode resume does converge through the unpause gate. No funds move; harm requires an independent emergency on some registrant to coincide with the window, and the owner at the keyboard can end it with one `v2.unpause()`. Severity-auditor verdict: AGREE, Low, high confidence.

**Evidence** (fork @25981150)

- `forge test --match-path test/audit-run33/CutoverAuditRun33.t.sol --match-test test_P7W_registeredWhilePausedWindow -vv --threads 1` → PASS (`fork-logs/r33-test_P7W_registeredWhilePausedWindow.log`):
  - `GLOBAL_PAUSE|P7-after-V2.setPauser(Pauser)|SUCCEEDED|registered=25`
  - `GLOBAL_PAUSE|P7-after-register(V2)|REVERTED|registered=26|err=0xd93c0665` (`EnforcedPause`), and the same after `Antimatter.setPauser(Pauser)` and `register(Antimatter)`
  - `HALTED_P7|preview run()|globalPause(phase0): Pauser.pause() does not pause every registrant; first failing registrant: 0x5582060396E38c9D83BEF379386Ed98853348161` (V2)
  - `GLOBAL_PAUSE|P7-after-V2.unpause()|SUCCEEDED|registered=27`; the real `_phase8_wiringAssertions` passes on the replicated end state.
- `test_P7W_fixOrderingControl` → PASS: with `unpause` moved before `register`, the breaker is live after every step (`fork-logs/r33-test_P7W_fixOrderingControl.log`).
- `test_P7W_haltedStateBroadcastResumeConverges` → PASS: a broadcast-mode resume heals the halted state (`fork-logs/r33-test_P7W_haltedStateBroadcastResumeConverges.log`).
- Call order confirmed against anvil broadcast receipts #41 `setPauser` (V2), #42 `register`, #43 `setPauser` (Antimatter), #44 `register`, #45 `unpause()` (`fork-logs/anvil-broadcast-gas-budget.txt`).

**Related**: L-04 (`pps32l4`, `46c053534c58…`) is the Phase-1 V1 window (wrong pauser, `only pauser` revert). Different contract, transactions, revert and fix; not a duplicate. L-03 (`pps31l3`): its three-stage simulated pause cannot see this intra-Phase-7 window.

**Recommended Mitigation**

In `_phase7_finalize`, move `if (!_doneV2Unpaused()) v2.unpause(); require(_doneV2Unpaused(), ...)` to immediately after `v2.setPauser(PAUSER)` and before `IPauserRegistry(PAUSER).register(address(v2))`, so V2 is never registered while paused. The finalized marker (`v2.pauser() == PAUSER`) is unchanged, and a resume from "pauser handed back, still paused" still converges through the same gate. Extend `test/CutoverStableStakerV2Mainnet.fork.t.sol` with a per-transaction `Pauser.pause()` probe across Phase 7, like `test_P7W_registeredWhilePausedWindow`. Correct the NatSpec (L33-36, L76-80) and the `:broadcast` doc key so they name the one remaining forced window: the single tx between `V1.setPauser(OWNER)` and `Pauser.unregister(V1)`.

```solidity
if (v2.pauser() != PAUSER) v2.setPauser(PAUSER);
// Unpause BEFORE registering: a paused registrant makes Pauser.pause() revert EnforcedPause.
if (!_doneV2Unpaused()) v2.unpause();
require(_doneV2Unpaused(), "Phase7: V2 still paused");
if (!IPauserRegistry(PAUSER).isRegistered(address(v2))) IPauserRegistry(PAUSER).register(address(v2));
```

---

### [L-06] The story-085 aggregate floor counts a staker's permissionless `V1.userMigrate` self-exit as V2 principal loss, so a correct cutover fails `:verify` with a false loss alarm and skips its remaining checks, and a halted run cannot be resumed <!-- id: pps33l6 -->

**Recommended before broadcast. Flagged for human review: borderline Medium.**

- **Severity**: Low (**borderline Medium**, see below; Law-2 intent mismatch vs stories 085/086)
- **Entry Point**: `stable-staker-v2-cutover`
- **Fingerprint**: `cf4b531aee540a854c4f68201857a360f1af1970c5e2800fc00673749f610abc`
- **Story**: story-085 (floor), story-086 (verifier reuses the floor)
- **Root cause**: [StableStakerCutoverCore.sol#L427-L518](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/helpers/StableStakerCutoverCore.sol#L427-L518) (`_aggregatePrincipalFloor`, applied in `_assertPoolPostMigration`)

```solidity
uint256 migratingPrincipal = principalSnapshot - v1Staked;                        // L437
floor = migratingPrincipal * (CUTOVER_MAX_BPS - maxLossBps) / CUTOVER_MAX_BPS;   // L438
...
(, uint256 principalSnapshot) = v1.migrationInfo(token);                         // L512
require(v2Staked >= floor, "cutover-post: V2 booked total below pre-migration principal floor (067)"); // L517
```

- **Also relevant**:
  - [VerifyStableStakerV2Cutover.s.sol#L223-L235](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/VerifyStableStakerV2Cutover.s.sol#L223-L235): `_verifyPhase6_migration` calls `_assertPoolPostMigration` with a live re-plan. Its NatSpec [L45-L46](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/VerifyStableStakerV2Cutover.s.sol#L45-L46) excludes `userMigrate` self-exits from the per-user check, but not from the floor.
  - [StableStakerV1.sol#L593](https://github.com/Behodler/stable-staker/blob/cf8de2718816a1c7df794dafb9d567e5694d826d/src/versions/v1/StableStakerV1.sol#L593) (nested `lib/stable-staker` @ `cf8de271`): `function userMigrate(address token) external nonReentrant` — permissionless, requires only `poolState == Migrating`, not pause-gated. L539: `// Empty or already self-migrated positions return 0 and are skipped`.

**Description**

The floor is `v2Staked >= (P - v1Staked) * (MAX_BPS - bps) / MAX_BPS - n * WEI_SLACK`, where `P = V1.migrationInfo(token).principalSnapshot` is frozen at `initiateMigration`. From the moment `initiateMigration` lands, any V1 staker can call `userMigrate` and take their snapshot credit to their own wallet. `batchMigrate` then skips them silently, and the broadcast, whose `require`s were evaluated in forge's local pass, still completes.

The self-exited principal remains inside `P` and has left `v1Staked`, but V2 never receives it, so `P - v1Staked` overstates what was due to move by exactly that principal. Per-pool headroom at the fork block is about 0.24 DOLA, 0.236 USDC and 6.46 USDe; any self-exit larger than that trips the floor even when every remaining staker migrated within bound.

The live window is between the `initiateMigration` and `migrate` transactions of a pool; with `--slow` and Ledger confirmation they are separate txs in at least consecutive blocks (anvil receipts #31/#32, #34/#35, #36/#37). A fresh run's local pass can never observe the self-exit, because `Migrating` only exists on chain. The post-chain checks, which re-read live state, then fail. The trigger is reachable both by a deliberate griefer (gas cost only) and by an ordinary staker using the designed escape hatch.

**Impact**

1. **False-red verifier on a correct cutover.** `:verify`, which `:broadcast` chains right after the address patch, reverts with `cutover-post: V2 booked total below pre-migration principal floor (067)`. Because the revert is inside `_verifyPhase6_migration`, the verifier also **skips** `_verifyPhase7_finalize`, `_verifyPerUserCredits`, the story-084 registrant sweep and the Phase 8 wiring assertions, and the chained `:preview` smoke test never runs. The operator sees a principal-loss alarm on mainnet with no loss, and may take unnecessary emergency action. The failure is loud, not silent.
2. **Blocked resume (conditional).** If the broadcast halted after that pool's `migrate` and before Phase 7 (for example the L-07 ETH shortfall at tx #37), every resume leg reverts at the same floor in its local pass. The resume cannot migrate the remaining pools or finalize without editing the script: V2 stays paused and unregistered from the Pauser, the V1 phUSD mint is not revoked, and migrated V2 stakers have only `emergencyWithdraw`. No funds are lost, and the owner can recover with a script edit or manual transactions. Pool TVL at the fork block is small (about 1.2k DOLA, 2.0k USDC, 2.6k USDe).

**Borderline-Medium flag and upgrade triggers** (from `severityAudit`: verdict AGREE, Low, confidence medium, `keepBorderlineFlag: true`)

On its own the finding produces a false alarm on a correct end state; the availability consequence needs an independent halt as well, and the resulting state is owner-recoverable with no loss. That falls short of C4 Medium's "protocol function impaired without stacked preconditions". A reviewer who treats the post-broadcast verifier and resume path as a protocol function could reasonably argue Medium. The auditor recorded that precondition (b), a halt inside Phase 6, is not purely external: mid-session halts have occurred in this project before (stories 071/073), and L-07 makes one likely at ≥ 0.31 gwei.

Upgrade to **Medium** if either trigger is met:

- **The live USDe strategy's on-chain slippage revert is confirmed to be cheaply manipulable.** Lead, **UNVERIFIED**: the USDe `initiateMigration` (tx #36) swaps through an AMM with an on-chain `minOut` of `ideal * (1 - slippageToleranceBps)`. A price move beyond tolerance, natural or pushed by a frontrunner, would revert #36 on chain after the DOLA/USDC migrates landed and halt forge. This has **not** been checked against the live USDe strategy bytecode. A griefer would pay AMM round-trip losses for no gain, which is why it does not lift the rating on its own, but it weakens the assumption that no attacker can influence the halt.
- **The owner counts `:verify` or resume availability as a protocol function.**

**Evidence** (fork @25981150, real phases, core and verifier)

- `forge test --match-path test/audit-run33/CutoverAuditRun33.t.sol --match-test test_SX_selfExitBetweenTxs_verifierFalseFailsOnFloor -vv --threads 1` → PASS (`fork-logs/r33-test_SX_selfExitBetweenTxs_verifierFalseFailsOnFloor.log`):
  - `SELF_EXIT|user=0x25AdA296F30976024d675Cd219f9aAF1F2Ad4eb1|V1principal=5499869851883238089|paidToWallet=5499860523851791803`
  - All 29 other positions migrated; real Phase 8 passes.
  - `SX|DOLA|floor=1222483056933011776952|v2Staked=1217223596276947632021|shortfall=5259460656064144931`
  - `SX|verifier|cutover-post: V2 booked total below pre-migration principal floor (067)`; `SX|preview run() on same state|` reverts identically.
- `test_SX_controlNoSelfExit_verifierPasses` → PASS, 29 users re-checked (`fork-logs/r33-test_SX_controlNoSelfExit_verifierPasses.log`).
- `test_SX_haltedResumeCannotFinish` → PASS: halt after the DOLA migrate, resume `run()` reverts on the DOLA floor; USDC `poolState` still Active, V2 paused and not registered (`fork-logs/r33-test_SX_haltedResumeCannotFinish.log`).
- The verifier harness is the story's own `VerifyStableStakerV2CutoverHarness` (injected addresses and recorded logs); its live path was separately shown equivalent on anvil (`fork-logs/anvil-verify-clean.log`). Story-085 floor spot check: `fork-logs/spot-story085-aggregateFloor.log`.
- Halt-mode premise (forge 1.5.1-stable `b0a9dd9`, `:broadcast` flags, low-balance key on anvil): forge sent 5 txs, then aborted with `-32003 Insufficient funds for gas * price + value`; no total-ETH pre-check in either simulation mode.

**Related**: F-01 (`pps31f1`, `dfed42790952…`) was the tautological floor this one replaced (false-green); this is a false-red on the replacement anchor, neither an incomplete fix nor a regression. L-02 (`pps31l2`): its recheck names this as its only residual. L-07 (`pps33l7`): compounding halt trigger.

**Recommended Mitigation**

Anchor the loss gate on quantities a self-exit cannot move.

(a) Replace the P-anchored aggregate floor with an exit-realization bound read from V1: `(R, P) = V1.migrationInfo(token); require(min(R, P) * MAX_BPS >= P * (MAX_BPS - exitBps))`, where `exitBps` is 0-2 for ERC4626 and `slippageToleranceBps + 1` for market strategies. That bounds the pre → credit haircut for every user, however they exit. Keep the per-user credit → credited check: in-leg in the cutover, and from `MigratedOut` / `DepositedFor` logs in the verifier.

(b) Alternatively, keep the floor and subtract self-exited principal. In the verifier, sum the `UserMigrated` credits from the same log fetch and convert them back to principal (`credit * P / min(R, P)`, plus 1 wei per exiter). The cutover script cannot recover that from state, so (a) is preferable there.

Add a `StableStakerCutoverDust` / verifier fork test where a staker calls `userMigrate` between `initiateMigration` and `migrate`. Correct the story-086 review claim in the NatSpec.

```solidity
(uint256 R, uint256 P) = v1.migrationInfo(token);
uint256 realized = R < P ? R : P;
require(realized * CUTOVER_MAX_BPS >= P * (CUTOVER_MAX_BPS - exitBps),
    "cutover-post: exit realization below bound");
```

---

### [L-07] The 46-transaction cutover fits OWNER's ETH balance only at the pinned 0.3 gwei, with 0.000147 ETH to spare; at 0.31 gwei or more tx #37 (USDe `migrate`) is rejected for funds and the run halts mid-Phase 6, and neither the script nor the runbook states an ETH budget <!-- id: pps33l7 -->

**Recommended before broadcast.**

- **Severity**: Low (operational hazard / footgun, Law 3; raised from the sanitizer's QA)
- **Entry Point**: `stable-staker-v2-cutover`
- **Fingerprint**: `d6896c6e843de66ebc7ef9202fb8071aa60fcc13a3f22b69323f1256f58d7bcd`
- **Story**: none
- **Root cause**: [CutoverStableStakerV2Mainnet.s.sol#L236-L298](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/script/CutoverStableStakerV2Mainnet.s.sol#L236-L298) (`_phase0_preconditions`: checks owners, pausers, strategies, minter registration and mint rights, but not OWNER's ETH)

```solidity
function _phase0_preconditions() internal {                                          // L236
    require(_owner(STABLE_STAKER_V1) == OWNER, "Phase0: V1 owner != OWNER");         // L240
    ...
    _snapshotPhusdMinterSet();                                                       // L297
}                                                                                    // no OWNER.balance check
```

- **Also relevant**: [package.json#L52-L53](https://github.com/Behodler/phoenix-phase-2-staging/blob/29aeb2b6df9ade4b69d573c59268bce752a37c1d/package.json#L52-L53): `:broadcast` pins `--skip-simulation --slow --legacy --with-gas-price 0.3gwei --gas-estimate-multiplier 200`, and its doc key says "base fee was ~0.16 gwei at planning - re-check before signing".

**Description**

A full broadcast rehearsal on an anvil fork of 25981150 used 18,317,077 gas across 46 transactions. OWNER's live balance is 0.005642012 ETH (nonce 1631, unchanged since run 32). At 0.3 gwei the run costs 0.005495 ETH and completes with 0.000147 ETH left.

Using the actual per-tx gas limits from the rehearsal, a node's upfront `balance >= gasLimit * price` check rejects tx #37 (USDe `migrate`) at any price from 0.31 to 0.35 gwei, and tx #32 (DOLA `migrate`) at 0.4 gwei. An operator who follows the doc key's "re-check before signing" and raises the price even slightly halts the run mid-Phase 6.

Forge 1.5.1 sends the transactions one at a time and has no total-cost pre-flight. Under `--skip-simulation` it does not print its "Estimated amount required" line either, so the operator gets no warning before signing.

**Impact**

The halt at #37 lands after the USDe pool is initiated (V1 USDe funds idle, pool `Migrating`) and before its 7 stakers are migrated or V2 is finalized: V2 stays paused and unregistered, and the V1 phUSD mint is not revoked. Every step is state-gated, so topping up OWNER and resuming converges, but a single planned session becomes an unplanned halted state. It is also the most likely trigger that turns L-06 into a resume that cannot finish without a script edit. No asset loss and no third-party trigger. Severity-auditor verdict: AGREE, Low, high confidence (noting the finding is slightly understated because `--skip-simulation` suppresses forge's only ETH estimate).

**Evidence** (anvil mainnet fork @25981150; no forge test in `CutoverAuditRun33.t.sol` for this entry)

- `fork-logs/anvil-broadcast-leg1.log`: `forge script --broadcast --skip-simulation --slow --legacy --with-gas-price 0.3gwei --gas-estimate-multiplier 200 --unlocked` → `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`, 46 txs; OWNER balance after 146889306269851 wei.
- `fork-logs/anvil-broadcast-gas-budget.txt`: `txs 46 total gasUsed 18317077 OWNER balance wei 5642012406269851`; per-tx `gasUsed`; actual gas limits from `cast tx <hash> gas`. Recomputed with actual limits: `0.3 gwei: ... None`; `0.31 gwei: ... (37, 'migrate(address,address[])')` through `0.35 gwei`; `0.4 gwei: ... (32, 'migrate(address,address[])')`. Pre-tx balance before #37 was 1079992206269851 wei against a `3383096 * 0.3 gwei = 1014928800000000` wei requirement.
- Forge halt behaviour (forge 1.5.1-stable `b0a9dd9`, low-balance key on local anvil): 5 txs sent, then abort with `-32003 Insufficient funds for gas * price + value`; with simulation on it prints an estimate and still sends 5 of 9 before halting.

**Related**: L-06 (`pps33l6`): compounding, see the note in the summary.

**Recommended Mitigation**

Add a broadcast-mode pre-flight in Phase 0: `require(OWNER.balance >= CUTOVER_GAS_BUDGET * gasPrice * 12 / 10, "Phase0: OWNER ETH below cutover gas budget")`, with `CUTOVER_GAS_BUDGET` about 18.4M gas from the anvil rehearsal and `gasPrice` taken from `tx.gasprice` or an env cap. State the ETH budget in the `:broadcast` doc key (for example "needs >= 0.0064 ETH at 0.35 gwei; top up OWNER before signing").

```solidity
uint256 constant CUTOVER_GAS_BUDGET = 18_400_000;

// in _phase0_preconditions, broadcast mode only
require(
    OWNER.balance >= CUTOVER_GAS_BUDGET * tx.gasprice * 12 / 10,
    "Phase0: OWNER ETH below cutover gas budget"
);
```

---

## Centralization Risks

None this run. Owner-controlled actions in this entry point were assessed under Law 3; the non-obvious consequences are filed above as footguns (L-05, L-07).

---

## Appendix: automated QA baseline (4naly3er)

**No report was produced this run (tooling gap, same as runs 31 and 32).** Scope attempted: `script/CutoverStableStakerV2Mainnet.s.sol`, `script/helpers/StableStakerCutoverCore.sol`, `script/VerifyStableStakerV2Cutover.s.sol` at `29aeb2b`.

- `yarn analyze <audit-root>/phoenix-phase-2-staging/src/ <scope.txt>` (basePath at the submodule root, scope list as arg 3) failed at compilation: `@forge-std/Script.sol import not found`, followed by `TypeError: Cannot read properties of undefined (reading 'contents')`. The project has no `remappings.txt` and resolves imports only through `foundry.toml`, which 4naly3er does not read.
- The staged-`remappings.txt` fallback was not repeated: in run 32 it compiled on this same scope and then hit the 480-second cap without writing a report, and in run 31 it hung for more than 32 minutes.

All entries in this bundle come from the script-audit pipeline, the mainnet fork harness and the anvil rehearsal, not from a bot report.
