# Script review: `dev` (phoenix-phase-2-staging, run 39)

| | |
|---|---|
| **Entry point** | `dev` → `./dev-local.sh` (`package.json:24`) |
| **Commit** | `dfbf2f9` (`dfbf2f97643688aacee2f6f32281288e83cb0cac`), branch `master` |
| **Baseline** | run 30 @ `e6eded0` (`entryPointBaselines.dev`) |
| **Mode** | full local broadcast to a fresh anvil 31337 started by the script itself, plus an audit-local mainnet-fork probe of the shared cutover core (block 26109485). Nothing was broadcast to mainnet. |
| **Result** | **0 High, 0 Medium.** 1 Low, 2 QA, 1 faithfulness. 2 Medium carryovers (both `fix-pending`), 47 QA carryovers. |
| **Ledger statuses changed** | **None.** |

The headline is L-01 (`pps39l1`). It sits in the shared `UniPoolerCutoverCore`, so it propagates to the story-103 mainnet cutover, and the fix has to land before that broadcast. Every other run-39 finding is local to the dev stack.

---

## 1. Does `dev` do what it intends?

**Yes, mechanically: `dev` ran end to end with 432 transactions, 66 creates and 0 failed receipts.** `dev-local.sh` was executed verbatim from `work/` (synced to `dfbf2f9`). The forge banner reported `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`. `simulate-yield.sh`, `extract:addresses` (60 contracts) and `generate:ts-anvil` all completed, and `serve` came up on :3001. The regenerated `addresses.ts` differs from HEAD only in timestamp lines, so the story-102 key set is stable. Both story-081 guards held when re-tested negatively: a second `dev` against a live :8545 exits 1 at pre-flight, before `clean:local`, and DeployMocks refuses the dirty chain with `DeployMocks: chain is not fresh - a prior deployment is already on 8545; kill it and re-run`.

### Story 101: Phase 11.7 cutover dress rehearsal (`auto-complete`). Faithful.

**`_rehearseUniPoolerCutover` does what story 101 asks, with one observation that is not a finding.** The phase runs after Phase 3.6/3.7 and before the privilege sweep, as the story requires:

```solidity
        _rehearseUniPoolerCutover(deployer);   // DeployMocks.s.sol:1522
        ...
        _sweepResidualPrivileges(deployer);    // DeployMocks.s.sol:1604
```

| Story-101 requirement | Result |
|---|---|
| Build today's index-4 stack (mint at index 4, authorize the deployer, `pool()` into mock BPT) | Met. 20 mints, 141.34 BPT pooled. Anti-vacuity gates passed: interim sUSDS `21445445197451485003`, interim mint debt `116273899443750963217`. |
| `incrementAuthVersion()`, then core steps 0–12 with the proportional exit | Met. Each step is a separate broadcast transaction. |
| Post-state: `configs(4).dispatcher == UniPoolerV2`, hook repointed, reserves == seed, LP on UniPoolerV2, a test mint dispatches and accrues debt, `quotePool` + `pool()` succeed | Met in simulation. The durable parts were re-read on the broadcast chain: BPT `totalSupply` 12,141.34e18 → 1,000e18 (third-party LP only), old pooler drained, `minter = deployer`, `paused = true`. |
| Track `UniPoolerV2` and `PhusdSusdsPair`, keep `BalancerPoolerV2` | Met (story-102 keys `UniPooler`, `PhusdSusdsPair`). |
| "runs the exact mainnet cutover sequence" | Partial, not filed. The code is the same, inherited from the core, but step 11 takes a different branch locally. See below. |

**Step 11 takes the donation-live branch locally and the wrap branch on mainnet.** The branch is selected by live state:

```solidity
            bool donationLive = np.batchDonationSize() > 0 && np.batchMinter() != address(0) && np.psm() != address(0);
            if (donationLive) {
                // The next index-4 dispatch sweeps and retries it.
                old.rescueERC20(l.usds, l.newPooler, usdsRescued);
            } else {
                // The new pooler would never sweep it: wrap it into sUSDS for the new pooler.
```

Local `batchDonationSize` is 30, while mainnet's is 0 at block 26109485, so dev never exercises the wrap branch that mainnet will take. This is not filed: it is a value divergence of the kind the 2026-09-15 ruling excludes, and fork test A shows the wrap branch completing on live mainnet state (see *Verification provenance*).

### Story 089: Phase 9.7 sDOLA repoint (`auto-complete`). Structurally faithful, but two acceptance criteria are weaker than they look.

**The repoint itself is correct.** `MockSDOLA` is deployed, the minter is re-registered on the sDOLA strategy with its collateral moved, and the SYA strategy list and withdrawer flags are swapped. On the broadcast chain SYA lists sDOLA + USDC, with `isRegistered(legacy) = false`. Three things fall short of the story:

- **"Minter principal cleared from the legacy strategy" holds only in simulation (Q-01).** The `require(principalOf == 0)` passes in forge's single-timestamp simulation, but 11,999,712,006,910 wei of principal remains on chain. See section 2.
- **"maxMintPerDay equals its value before re-registration" is vacuous (Q-02).** The pre-value is 0, which is exactly what `registerStablecoin` resets to (`maxMintPerDay: 0`), so deleting the `setMaxMintPerDay` re-apply would still pass. The log line `maxMintPerDay restored: 0` carries no information.
- **The disclosed follow-up has not landed (F-01).** `simulate-yield.sh` still targets `MockAutoDOLA`. See section 2.

### Untagged in-delta edits (`6c9416d`, `884ccf8`)

**No residual privilege survives the sweep.** The deployer's phUSD mint authority reads `(false, 1)` at `mintVersion` 1 on chain, the Antimatter grant is asserted live, and the set-aside buffer recipient wiring is asserted (V1, then V2). Core step 12 setting the retired `BalancerPoolerV2`'s minter to the deployer is by design (story 100, Concerns) and is owner-trusted. These commits have no story, which is a provenance gap only, of the same kind as F-03 `da94d1ba03fd`.

---

## 2. Does `dev` have unintended side effects?

**Yes, three. All are local to anvil or the working tree, and none touches mainnet.**

### Phase 9.7 leaves minter principal on the de-registered legacy strategy (Q-01, `pps39q1`)

**Phase 9.7's own post-condition is false on the broadcast chain.** The amount is read and asserted during simulation, and forge bakes it into calldata:

```solidity
        uint256 principal = yieldStrategyDolaLegacy.principalOf(address(dola), address(minter));
        ...
        yieldStrategyDolaLegacy.withdrawAsOwner(address(minter), deployer, principal);
        ...
        require(
            yieldStrategyDolaLegacy.principalOf(address(dola), address(minter)) == 0,
            "story-089: minter principal not cleared from the legacy strategy"
        );
```

On chain (`--block-time 2`), `MockAutoDOLA`'s time-based yield runs between blocks, so the block-434 `minter.mint` credits `5000.000011999712006910e18` of principal. The block-436 `withdrawAsOwner(..., 5000e18)` leaves 11,999,712,006,910 wei behind, and the require never runs on chain. The minter remains the sole principal holder on a strategy SYA no longer lists, so the legacy `totalBalanceOf(minter)` of 3,299.64 DOLA (all mock yield) accrues to a bucket nothing can skim. The value is about 1.2e-5 mock DOLA. It is filed because it is a concrete instance of `ForgeLocalPassPrecedesBroadcast`, the class behind real mainnet-entry-point issues (`78cb5942d483…` fixed, `2c53e944caee…` fix-pending). The UI-mock ruling does not apply, because the defect is dev's own assertion being false, not a fidelity gap with mainnet.

### `simulate-yield.sh` feeds the wrong vault (F-01, `pps39f1`)

**dev's "Simulating yield" step reaches no live DOLA consumer.** The script still reads and mints into `MockAutoDOLA`:

```bash
MOCK_AUTODOLA=$(jq -r '.contracts.MockAutoDOLA.address' "$PROGRESS_JSON")
...
cast send "$MOCK_DOLA" "mint(address,uint256)" "$MOCK_AUTODOLA" "$AMOUNT_WEI" \
```

`MockAutoDOLA.totalAssets` went from 1000.12 to 3300.12 DOLA, but since story 089 the minter, StableStakerV2 and SYA all sit on the sDOLA strategy, so the live system sees zero simulated yield. Story 089 disclosed this as an out-of-file-list follow-up (lines 104, 182, 216, 261). No later story picks it up, and story 098 explicitly scopes `simulate-yield.sh` out. It is filed in the faithfulness channel at QA because there is no security or value impact.

### `clean:local` deletes four tracked files (existing L-06 `bd268808fbd5`, evidence update)

**Every `dev` run leaves a dirty working tree.** The pre-step is unchanged:

```json
"clean:local": "rm -rf broadcast/*/31337 server/deployments/progress.31337.json server/deployments/local.json",
```

Because `6c9416d` re-tracked `server/deployments/local.json`, the step now deletes four tracked files: `broadcast/DeployMocks.s.sol/31337/run-latest.json`, `broadcast/DeployMocks.s.sol/31337/run-1790927748502.json`, `server/deployments/progress.31337.json` and `server/deployments/local.json`. Observed after the run: `run-1790927748502.json` deleted; `run-latest.json`, `local.json`, `addresses.ts` and `local-addresses.ts` modified; a new `run-<ts>.json` created. This is evidence for the open L-06 `bd268808fbd5` (`pps28l6`), not a new finding. The same re-tracking voids the premise of L-07 `98e727214903` (see section 5).

---

## 3. Have other problems surfaced because of it?

### L-01 (`pps39l1`): the shared cutover core cannot recover from a pre-poisoned pair, and this propagates to story 103

**A 2-wei donate+sync on the canonical sUSDS/phUSD pair blocks every run of `UniPoolerCutoverCore`, including the future story-103 mainnet cutover.** Step 2 has a strict empty-pair precondition and no other branch:

```solidity
    function _step2EnsurePairEmpty(CutoverParams memory p, CutoverLive memory l) internal {
        ICutoverUniV2Pair pair = ICutoverUniV2Pair(l.pair);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");
```

Once a third party calls `createPair`, transfers 1 wei of each token and calls `sync()`, reserves are (1,1) with LP `totalSupply` 0. They can never return to (0,0): `skim()` does not touch reserves and `burn()` needs LP. `UniPoolerV2`'s constructor (`UniPoolerV2__PairNotCanonical`) prevents pointing the pooler at any other pair. Mainnet `getPair(sUSDS, phUSD) == 0x0` at block 26109485, so the window is open now. `docs/BalancerWinddownPlan.md` §4 (lines 410–414) covers only in-window griefing and refers to a recovery helper the core does not contain. Story 108 recorded the gap as "[Low-Medium, doc]" and accepted it as non-blocking. That review acceptance is not a ledger disposition, so it does not suppress this finding.

**Rated Low, with a Low-vs-Medium flag for human review.** No asset is at risk. The revert happens in simulation before any broadcast, and index 4 keeps working on `BalancerPoolerV2` in the meantime. An atomic transfer+`pair.mint` seed absorbs the dust, so the block applies only to the core, not to the pair. Re-weigh to Medium if index 4 or the Balancer exit stops working while the cutover is blocked, or if deadline pressure turns the delay into value loss.

**Reconciliation instruction for story 103.** `entryPoint` is folded into the fingerprint, so when the story-103 entry point is audited the same `contract:function` will hash differently. Reconcile it against `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` instead of filing it as new.

### Other cross-entry-point effects

- **The blast radius of carryover M-01 `a753907e2a4c` (`pps21m1`) has widened.** Core step 9 copies `nudgeStreamer` onto `UniPoolerV2`, so the same `NudgeStreamer` now also receives index-4 donations, a new caller of the unmeasured-receipt accounting. This carries over to story 103.
- **The cluster is otherwise consistent.** The four mainnet poolers pass core step 0 (revoked) in fork test A, which is consistent with the story-099 holding pattern. The `UniPooler` / `PhusdSusdsPair` placeholders in `mainnet-addresses.ts` are `0x0`, matching chain state, which is the same pattern as open L-03 `3177eed94ecb` and was not re-filed.

---

## 4. Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| L-01 `pps39l1` | Low (flag: Low vs Medium) | Core step 2 has no recovery branch: a 2-wei donate+sync on the permissionless canonical pair makes the shared cutover core, and therefore story 103, revert permanently | Add a pre-poisoned-pair branch that seeds via an atomic transfer+`pair.mint(newPooler)` helper with dust-bound and ratio checks (never Router02), and land it in the core before the 103 broadcast | [`script/helpers/UniPoolerCutoverCore.sol#L336-L349`](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/script/helpers/UniPoolerCutoverCore.sol#L336-L349) `_step2EnsurePairEmpty` |
| Q-01 `pps39q1` | QA | Phase 9.7's "principal cleared" require passes only in simulation; 1.2e13 wei stays on the de-registered legacy strategy on chain | Withdraw `type(uint256).max` (capped to live principal) instead of the simulation-baked amount, or log residual dust instead of asserting zero | [`script/DeployMocks.s.sol#L2504-L2513`](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/script/DeployMocks.s.sol#L2504-L2513) `_repointDolaMinterAndSya` |
| Q-02 `pps39q2` | QA (flag: borderline under the UI-mock ruling) | The maxMintPerDay restore assertion is vacuous: pre-value 0 equals the `registerStablecoin` reset value | Seed a non-zero DOLA cap and `require(prevMaxMintPerDay > 0)` as an anti-vacuity gate, or wont-fix citing the 2026-09-15 ruling | [`script/DeployMocks.s.sol#L2551-L2556`](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/script/DeployMocks.s.sol#L2551-L2556) `_assertDolaRepoint` |
| F-01 `pps39f1` | QA (Law 2) | `simulate-yield.sh` still feeds `MockAutoDOLA`; the disclosed story-089 follow-up never landed | Retarget to `.contracts.MockSDOLA` and assert the sDOLA strategy's surplus rose, or ticket the follow-up as its own story | [`simulate-yield.sh#L19-L48`](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/simulate-yield.sh#L19-L48) `main` |

Full write-ups: L-01, Q-01 and Q-02 in [`../../submissions/qa-report.md`](../../submissions/qa-report.md); F-01 in [`../../submissions/spec-conformance.md`](../../submissions/spec-conformance.md). Finding records: `reports/39/findings/`. Labels are run-scoped and entry point `dev` reuses them across runs, so select by `issueId` or fingerprint.

### Carryover (not restated here)

**Two Medium carryovers, both `fix-pending`:**

| File | issueId | Fingerprint | Run-39 state |
|---|---|---|---|
| [`../../submissions/M-01-C1.md`](../../submissions/M-01-C1.md) | `pps21m1` | `a753907e2a4c…` | still open, fix not landed (`lib/nft-staking` pin unchanged); blast radius widened |
| [`../../submissions/M-01-C2.md`](../../submissions/M-01-C2.md) | `pps28m1` | `11311795cd60…` | `fixed` proposed, not applied |

**47 QA carryovers, one file per originating run, in [`../../submissions/carryover/`](../../submissions/carryover/):**

| Origin run | File | Entries |
|---|---|---:|
| 05 | `qa-report-05.md` | 1 |
| 21 | `qa-report-21.md` | 14 (includes M-02 `f7de907d7981…`, owner-downgraded to Low) |
| 26 | `qa-report-26.md` | 4 |
| 27 | `qa-report-27.md` | 6 |
| 28 | `qa-report-28.md` | 12 |
| 29 | `qa-report-29.md` | 4 |
| 30 | `qa-report-30.md` | 6 |
| **Total** | | **47** |

Three `wont-fix` entries and one `fixed` entry are suppressed and not carried.

---

## 5. Fix-pending and proposal re-verification

**No ledger status was changed by run 39.** This was verified by diffing `ledger.json` against the pre-run snapshot: entries went from 192 to 196 (the four new run-39 findings), with 0 status transitions. Every proposal below is recorded in the entry's `run39` field with `statusFlipApplied: false`. Only a human applies them.

| Fingerprint | issueId | Status | Run-39 outcome | Basis | Proposed command |
|---|---|---|---|---|---|
| `a753907e2a4c` | `pps21m1` | fix-pending | **still open** | `lib/nft-staking` pin unchanged, so the fix has not landed | none |
| `b8e3d59139ae` | `pps26l4` | fix-pending | **proposed fixed** (human only) | `_sweepResidualPrivileges` revokes the deployer's phUSD minter; on chain it reads `(false, 1)` | `/ledger phoenix-phase-2-staging fixed b8e3d59139ae` |
| `11311795cd60` | `pps28m1` | fix-pending | **proposed fixed** (human only) | both story-081 gates re-executed at HEAD: pre-flight exit 1, and the non-fresh-chain revert | `/ledger phoenix-phase-2-staging fixed 11311795cd60` |
| `98e727214903` | `pps28l7` | open | **proposed fixed** (human only) | premise void: `local.json` was re-tracked by `6c9416d` | `/ledger phoenix-phase-2-staging fixed 98e727214903` |
| `ce524709d965` | — (pre-scheme) | open | **proposed fixed** (human only) | `require(block.chainid == 31337, "DeployMocks: local only")` at `DeployMocks.s.sol:412` (`9563c68`); close independently of `11311795cd60`; sibling `8468af472d` stays open | `/ledger phoenix-phase-2-staging fixed ce524709d965` |
| `eda17642828a` | `pps26l1` | fix-pending | **human decision** | story 101 adds a mechanics-level rehearsal of a *different* cutover; `_rehearseDispatcherSwap` is not restored, so this is not classified as an incomplete fix | (a) `/ledger phoenix-phase-2-staging fixed eda17642828a` (theme satisfied by story 101), **or** (b) `/ledger phoenix-phase-2-staging wont-fix eda17642828a` citing the 2026-09-15 ruling, **or** (c) leave `fix-pending` |
| `12bcca3b617c` | `pps26l3` | fix-pending | **owner ruling needed** | `_armLocalKenduPromotion` is unchanged and `dev-local.sh` still sets `LOCAL_PROMO_KENDU=true`; this is fidelity-class, so the 2026-09-15 ruling may cover it | leave `fix-pending`, **or** `/ledger phoenix-phase-2-staging wont-fix 12bcca3b617c` citing the ruling |

**MR-30-DEV-01 entries were deliberately left unbumped.** `6af1ae30ed82` (`pps27l2`), `19e2e0c2d6a3` (`pps27l3`), `9ee101a0cc41` (`pps27l4`) and `9067d8a232b5` (`pps27q1`) anchor on helpers deleted at `e6eded0`. They were not re-observed, so `lastSeenRun` stays at run 27. They remain `open` and carried, and per MR-30-DEV-01 `fixed` is never proposed for them on absence of evidence.

---

## 6. Verification provenance

- **Fork test, independently reproduced.** The orchestrator re-ran `work/test/audit-run39/UniPoolerCoreMainnetFork.t.sol` against `RPC_MAINNET` at block 26109485. **Both tests pass:** `test_A_coreCompletesOnMainnetForkAndIndex4Works` (the core completes on live state, taking the step-11 wrap branch) and `test_B_dustSyncedPairPermanentlyBlocksCoreStep2` (reserves (1,1) after `sync`, unchanged after `skim`, and the core reverts with `UniPoolerCutoverCore: pair reserves not empty`). The test is audit-authored and prank-only, lives in `work/`, and is not part of the upstream repo.
- **Local broadcast evidence.** [`evidence/dev-run.filtered.log`](./evidence/dev-run.filtered.log), [`evidence/broadcast-tx-index.json`](./evidence/broadcast-tx-index.json) (432 txs, 432 receipts, 0 failed) and [`evidence/progress.31337.run39.json`](./evidence/progress.31337.run39.json). Q-01's on-chain values come from broadcast txs 433–436 and state reads at blocks 435/436, recorded in [`side-effects.json`](./side-effects.json).
- **4naly3er's silence on `DeployMocks.s.sol` is not a clean result.** solc-js fails on the file with `DeclarationError: Identifier already declared`, because `IYieldStrategy` is reachable through both the `reflax-yield-vault/` and `vault/interfaces/` remappings. This is the same gap as run 30. Q-01 and Q-02 live in that file and were found by execution and reading, not by the tool. Both closure helpers (`UniPoolerCutoverCore.sol`, `UniswapV2Deployer.sol`) were analysed with 0 AST failures, and no hit rose to a finding ([`../../submissions/4naly3er-report.md`](../../submissions/4naly3er-report.md)).
- **Workspace hygiene.** The dev-touched tracked artefacts in `work/` were restored to HEAD after capture. `work/foundry.toml` gained audit-local skips for `test/audit-run35/**` and `test/audit-run36/**`, whose PoCs import tests deleted upstream by `c5cd3f7`. `src/` was not modified.

---

## 7. Scope notes

- **The 2026-09-15 UI-mock ruling was applied and suppressed nothing.** All four new findings were assessed against it and not suppressed: Q-01 and F-01 concern dev's internal coherence, and L-01 is in the mainnet-bound core. **Q-02 is borderline,** because its only remedy (seeding a non-zero local cap) can be read as a fidelity change. The ruling raised two human questions (`eda17642828a`, `12bcca3b617c`, section 5) and decided neither.
- **Known-issue suppression was withheld.** `src/known-issues.md` does not exist at `dfbf2f9` (`git ls-tree` finds no known-issues file), so the 11 registry-cached entries carry no authority. Story-disclosed follow-ups and in-source NatSpec are not known issues.
- **Only `entryPointBaselines.dev` was advanced** (`e6eded0` → `dfbf2f9`, run 39). The project-level `lastAuditedCommit` stays `0e190e8`, because a script audit does not cover the whole tree.
- **Observations not filed, each with its reason:**
  - **Anvil block-time drift.** `dev-local.sh:68` says *"Flags are byte-identical to the start:anvil key"*, but `dev-local.sh:69` launches `--block-time 2` while `start:anvil` is now `--block-time 5` (untagged `6c9416d`). This is the drift Q-03 `111b6f04c9b7` (`pps29q3`) predicted, so it is recorded as an evidence update to that entry, not as a new finding. The only behavioural coupling observed is that Q-01's residual magnitude depends on block time.
  - **sDOLA buffer of 10 locally vs 0 on mainnet.** This is a mock-vs-mainnet value divergence and is invalid under the 2026-09-15 ruling.
  - **The mainnet step-11 wrap branch is unexercised locally.** Local `batchDonationSize` = 30 selects the donation-live branch, but fork test A proves the wrap branch completes on live mainnet state.
  - **Untagged `6c9416d` / `884ccf8` edits.** They leave no residual privilege: the sweep holds on chain. The missing story is a provenance gap only.
  - **Story states.** Stories 101 and 100 are in `auto-complete` (final, machine-approved, no human review). Story 103 is in `incomplete`, and it is the story that inherits L-01, so the fix should land before 103 closes.
