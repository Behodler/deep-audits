# Carryover QA report: audit 39 (entry point `dev`), carried at audit 40

> ## Carried at audit 40. Read this first.
>
> **This block was prepended by audit 40** (run `phoenix-phase-2-staging-40`, full-audit regression contract scan,
> commit `a4f9f3c66ee133a7cacb79f4d24300bba5945966`, range `0e190e8..a4f9f3c`, branch `master`, `entryPoint: ""`).
> **Everything after the run-40 index is run 39's `qa-report.md`, copied VERBATIM and not edited.** It is a
> full copy, not a stub: a reader does not need to open `reports/39/` to read any finding below.
>
> - **Source of the verbatim body:** `../../../39/submissions/qa-report.md`. The machine-readable records are
>   under `reports/39/findings/low/` and `reports/39/findings/qa/`.
> - **Retained (ledger status `open` as of audit 40): L-01, Q-01, Q-02. That is 3 entries.** No entry was removed:
>   none of run 39's QA findings has been disposed of.
> - **Statuses changed by audit 40 in this file: NONE.** Only a human applies a status, with `/ledger`.
> - **Labels are the originals and are run-scoped.** Run 40 has its own, unrelated `L-01` (`pps40l1`,
>   `7d5a26570be9…`). **Always select by fingerprint or issueId, never by bare label.**
> - **Line numbers below were accurate at run 39's commit `dfbf2f9`.** Re-verify them against `a4f9f3c` before acting.
>   `UniPoolerCutoverCore.sol` is unchanged between `dfbf2f9` and `a4f9f3c`, so the L-01 location `#L336-L349` still holds.
>   `DeployMocks.s.sol` gained 80 lines (story 110, Phase 11.8), so the Q-01 and Q-02 line numbers may have shifted.
> - **Not in this file:** F-01 (`pps39f1`, `b8036903340e…`) is a faithfulness finding. It lives in run 39's
>   `spec-conformance.md`, not in a QA bundle. The `dev` entry point's older carryovers (audits 05, 21, 26–30) were
>   re-carried by audit 39 under `reports/39/submissions/carryover/`. They are still open in the ledger.
>   This contract scan did not re-walk the `dev` entry point, so it neither reconfirms them nor closes them.
>   Absence from a scan is never evidence of a fix.

## Run-40 index of retained entries

| Original label | issueId | Fingerprint | Ledger status | Run-40 reconciliation |
|---|---|---|---|---|
| L-01 | `pps39l1` | `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` | `open` | **Reconfirmed, still open.** PATTERN-001 and SLITHER-005 in run 40 re-matched the core's step-2 strict `reserves == (0,0)` gate, which is unchanged at `a4f9f3c` (L336-L349). The finding was merged into this ledger entry rather than re-filed, and `lastSeenRun` was bumped to 40 (see `reports/40/filtered/dedup-log.md` and `sanitize-log.md`). Run 40's L-02 (`1d7e436f7dad…`) is a separate **honest-user** trigger for the same brick, through `UniswapHelper`. Run 40's L-01 (`7d5a26570be9…`) leaves this poisoning window open for longer. Neither is a duplicate of this entry. |
| Q-01 | `pps39q1` | `9fa8eee3010ec38a3aa38c93bdc8141dd42eb6a2a469648865c02f5ca2f84787` | `open` | **Not re-observed.** It is scoped to entry point `dev`, which this contract scan did not run, so it is carried as-is. Run 40's Q-01 (`c8fb41a168e1…`) is the same root-cause class (`ForgeLocalPassPrecedesBroadcast`) in a different contract. It is not a duplicate. |
| Q-02 | `pps39q2` | `c35d7cea7c0c71f66d59e5cf2b52b4ea844f1f1e1874540e5393664d8fc615a9` | `open` | **Not re-observed.** It is scoped to entry point `dev` and carried as-is. Its owner-ruling-borderline flag (2026-09-15 DeployMocks UI-mock ruling) still stands. |

---

# QA Report for phoenix-phase-2-staging, run 39 (script audit)

- **Project**: `phoenix-phase-2-staging` @ [`dfbf2f9`](https://github.com/Behodler/phoenix-phase-2-staging/tree/dfbf2f97643688aacee2f6f32281288e83cb0cac) (`dfbf2f97643688aacee2f6f32281288e83cb0cac`), branch `master`, read-only
- **Run**: `phoenix-phase-2-staging-39` (run-39, script audit)
- **Entry Point**: `dev`
- **Baseline**: `e6eded0` (`entryPointBaselines.dev`, set by run 30)
- **Inputs**: `reports/39/findings/low/L-01-unipoolercutovercore-step2-no-recovery-branch.json`, `reports/39/findings/qa/Q-01-phase97-principal-cleared-only-in-simulation.json`, `reports/39/findings/qa/Q-02-phase97-maxmintperday-restore-vacuous.json`
- **Fork test**: `work/test/audit-run39/UniPoolerCoreMainnetFork.t.sol` (audit-authored, in the writable `work/` clone, not part of the upstream repo), mainnet fork at block 26,109,485

> **Labels are run-scoped.** Entry point `dev` already carries same-letter labels from runs 21 to 30 under
> different fingerprints. Identify these findings by `issueId` or fingerprint, never by label alone.
>
> **Faithfulness is not in this file.** This run's Law-2 finding, **F-01** (`pps39f1`, `simulate-yield.sh`
> still targets `MockAutoDOLA` after story 089's repoint), is reported only in
> [`spec-conformance.md`](./spec-conformance.md). It is mentioned here as a cross-reference and is not restated.
>
> **Carryover QA is not in this file.** Open QA carried from earlier `dev` audits is in
> [`carryover/qa-report-NN.md`](./carryover/) (one file per originating audit: 05, 21, 26, 27, 28, 29, 30). It is not merged or renumbered here.

## Summary

| Severity | Count |
|----------|------:|
| Low Risk | 1 |
| QA | 2 |
| Centralization | 0 |
| **Total** | **3** |

No finding puts value at risk. **L-01** is an availability defect in the shared cutover core. It **propagates to the story-103 mainnet cutover** and is **flagged for human review (Low vs Medium)**. Q-01 and Q-02 are self-assertions in `DeployMocks.s.sol` Phase 9.7 that certify less than they claim. **Q-02 carries an owner-ruling-borderline flag** (2026-09-15 DeployMocks UI-mock ruling).

| Label | issueId | Fingerprint | Human review |
|---|---|---|---|
| L-01 | `pps39l1` | `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` | **Yes**: Low vs Medium |
| Q-01 | `pps39q1` | `9fa8eee3010ec38a3aa38c93bdc8141dd42eb6a2a469648865c02f5ca2f84787` | No |
| Q-02 | `pps39q2` | `c35d7cea7c0c71f66d59e5cf2b52b4ea844f1f1e1874540e5393664d8fc615a9` | **Yes**: QA vs wont-fix under the 2026-09-15 ruling |

---

## Low Risk Findings

### [L-01] Shared UniPoolerCutoverCore step 2 has no recovery branch: a 2-wei donate+sync on the permissionless canonical sUSDS/phUSD pair makes the mainnet cutover core revert for good <!-- id: pps39l1 -->

- **Severity**: Low. **HUMAN REVIEW FLAG: Low vs Medium** (the sanitizer argued Medium, the classifier rated Low; see *Severity rationale*)
- **issueId**: `pps39l1`
- **Fingerprint**: `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add`
- **Fingerprint input**: `lib/phoenix-phase-2-staging/script/helpers/UniPoolerCutoverCore.sol:_step2EnsurePairEmpty:UnrecoverablePreconditionOnPermissionlessState:dev`
- **Root cause class**: `UnrecoverablePreconditionOnPermissionlessState`
- **Propagates to**: the story-103 mainnet UniPoolerCutover, which inherits the shared `UniPoolerCutoverCore` (story 103, `incomplete`). The dev rehearsal (story 101, `auto-complete`) inherits it too.
- **Location**: [script/helpers/UniPoolerCutoverCore.sol#L336-L349](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/script/helpers/UniPoolerCutoverCore.sol#L336-L349) (`_step2EnsurePairEmpty`)

```solidity
    /// @notice Step 2. Skim any unsynced donation to OWNER, then require reserves AND balances (0,0).
    function _step2EnsurePairEmpty(CutoverParams memory p, CutoverLive memory l) internal {
        ICutoverUniV2Pair pair = ICutoverUniV2Pair(l.pair);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");
        if (ICutoverERC20(l.sUSDS).balanceOf(l.pair) > 0 || ICutoverERC20(l.phUSD).balanceOf(l.pair) > 0) {
            pair.skim(p.owner);
        }
        (r0, r1,) = pair.getReserves();
        require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");
        require(
            ICutoverERC20(l.sUSDS).balanceOf(l.pair) == 0 && ICutoverERC20(l.phUSD).balanceOf(l.pair) == 0,
            "UniPoolerCutoverCore: pair balances not empty"
        );
    }
```

**Description**: Core step 2 requires the canonical pair's reserves to be (0,0) both before and after an optional skim, and there is no other branch. Uniswap V2 reserves set by `sync()` can never return to (0,0) once LP `totalSupply` is 0: `skim()` does not touch reserves and `burn()` needs LP. yield-claim-nft:051's constructor check (`UniPoolerV2__PairNotCanonical`) binds `UniPoolerV2` to `factory.getPair(sUSDS, phUSD)`, so the pooler cannot be pointed at a different pair. Any third party can therefore `createPair` today (mainnet `getPair == 0` at block 26109485), transfer 1 wei of each token and call `sync()`. After that, every run of the shared core reverts at step 2.

The core is inherited by the dev rehearsal (story 101) and by the future mainnet cutover script and fork test (story 103), so this defect propagates to the mainnet operation. `docs/BalancerWinddownPlan.md` §4 (lines 410-414) discusses only in-window griefing between steps 1 and 6. It points to a recovery helper (transfer + `pair.mint(UniPoolerV2)` with a price check) that does not exist in the core. Pre-emptive poisoning before the run starts is not addressed.

Story evidence:
- Story 103 (`incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md`): "Preconditions `require`d: authorized-pooler set revoked (story 099); pair absent or reserves (0,0)" and "createPair is permissionless, so a griefer can donate+sync between creation and seeding to break the (0,0) precondition — follow the mitigation phStaging2:108 documents."
- Story 108 (`complete/phStaging2-Balancexit/108-balancer-winddown-plan-audit-corrections.md`): "**[Low-Medium, doc] No recovery path if the step 2 empty-pair `require` fails.** A donation plus `sync()` before step 2 leaves the canonical pair permanently non-empty". The human accepted it as non-blocking. That review acceptance is **not** a ledger disposition, so it does not suppress this finding. The finding stays open because the core still has no branch for this case.

**Attack path**:
1. Today, mainnet `getPair(sUSDS, phUSD) == 0` (block 26109485).
2. A griefer calls `factory.createPair(sUSDS, phUSD)`, transfers 1 wei of each token to the pair, then calls `pair.sync()`. Reserves become (1,1) and LP `totalSupply` stays 0.
3. `skim()` does not change reserves and `burn()` needs LP, so reserves can never return to (0,0). `UniPoolerV2`'s constructor (`UniPoolerV2__PairNotCanonical`) rules out using any other pair.
4. Every run of `UniPoolerCutoverCore` reverts at `_step2EnsurePairEmpty` with `UniPoolerCutoverCore: pair reserves not empty` in forge's simulation.
5. The owner has to write, review and broadcast a different seeding path before the 103 cutover can run. That delays the migration, but no value is lost.

**Evidence (mainnet fork)**: `work/test/audit-run39/UniPoolerCoreMainnetFork.t.sol::test_B_dustSyncedPairPermanentlyBlocksCoreStep2` **passes against mainnet at block 26109485** (reproduced by the orchestrator). Observed: grief cost 1 wei sUSDS + 1 wei phUSD + gas, reserves (1,1) after `sync`, pair `totalSupply` 0, reserves still (1,1) after `skim`, and the core reverts with `UniPoolerCutoverCore: pair reserves not empty`. A live read confirms `getPair(sUSDS, phUSD) == 0x0`, so the window is open now. Test A in the same file shows the core otherwise completes on live state.

**Impact**: Availability of the Balancexit index-4 cutover, not funds. The revert happens in forge's simulation, before any broadcast, so nothing is half-done and the recovered sUSDS/phUSD never leave the Balancer position. But the 103 script as built on this core cannot run at all until someone writes, reviews and broadcasts a bespoke seeding path under the Balancer wind-down timeline. The griefer's cost is 2 wei plus gas. Meanwhile index-4 keeps working on `BalancerPoolerV2` (`configs(4)` unchanged and unpaused). After 30 Oct `pool()` reverts and accrued sUSDS sits idle. After 30 Nov the proportional recovery exit still works (`BalancerWinddownPlan.md` L16-38, L250).

The pair itself is not unusable. With reserves (1,1) and `totalSupply` 0, `UniswapV2Pair.mint` still credits `amount = balance - reserve` and gives the first minter `sqrt(a0*a1) - MINIMUM_LIQUIDITY`, so an atomic transfer+mint absorbs the dust at our ratio. Only the core's strict `reserves == 0` require blocks. This recovery outside the core caps severity at Low.

**Severity rationale (human review)**: The case for Medium is a cheap, permissionless and permanent DoS of a mainnet-bound migration core, which is a fair Law-1 availability argument, and nothing here dismisses it. It is rated Low for four reasons. (1) No asset is at risk and protocol function is not impaired. The delay costs at most idle sUSDS (opportunity cost). (2) The revert is fail-loud in simulation before any broadcast. (3) "Permanent" applies only to the core's strict require, not to the pair. An atomic transfer+mint seed absorbs the dust, and once LP `totalSupply > 0` further dust-syncs cannot block a mint-based seed. (4) The workaround is a script-level change. **Re-weigh to Medium** if index-4 or the Balancer exit stops working while the cutover is blocked, or if deadline pressure turns the delay into a value loss.

The strict check is **load-bearing**. `Router02.addLiquidity` quotes against existing reserves, so any relaxation that seeds through the router would let the griefer choose the opening price. The mitigation below keeps that protection.

**Recommended Mitigation**:

Add a pre-poisoned-pair branch to the core instead of relaxing the router path. When reserves != 0 AND `pair.totalSupply() == 0`, do NOT seed through Router02, because it would quote against griefer-set reserves. Instead, from ONE transaction via a small reviewed helper contract (never two owner txs, since anyone can call `pair.mint(to)` after a bare transfer and take all the LP), transfer all recovered sUSDS/phUSD to the pair, call `pair.mint(newPooler)`, and then require:

- (a) the post-mint reserve ratio is within `seedToleranceBps` of the Balancer exit ratio (`sAmt:pAmt`),
- (b) the pre-existing reserves are below an explicit dust bound, and
- (c) `newPooler` holds `totalSupply - MINIMUM_LIQUIDITY`.

Keep the strict (0,0) path when `totalSupply == 0` and reserves == 0. Revert, as today, when `totalSupply > 0` or the reserves exceed the dust bound. Better still, do createPair-if-missing, the skim check and the transfer+mint seed atomically in the helper, which also closes the step-2-to-6 window. Add a core unit test that pre-syncs (1,1) and expects the branch to succeed with the ratio check enforced, plus a test where a large skewed pre-sync fails the ratio check. Land it in the shared core before the story-103 broadcast.

A sketch of the atomic helper's shape (illustrative, not a drop-in):

```solidity
// One transaction: transfer + mint can never be split across owner txs.
function seedPoisonedPair(IUniV2Pair pair, address newPooler, uint256 sAmt, uint256 pAmt, ...) external onlyOwner {
    (uint112 r0, uint112 r1,) = pair.getReserves();
    require(pair.totalSupply() == 0, "LP exists");
    require(r0 <= DUST && r1 <= DUST, "pre-reserves exceed dust bound");
    sUSDS.transfer(address(pair), sAmt);
    phUSD.transfer(address(pair), pAmt);
    pair.mint(newPooler);                                  // never Router02.addLiquidity here
    // (a) post-mint ratio within seedToleranceBps of sAmt:pAmt
    // (c) pair.balanceOf(newPooler) == pair.totalSupply() - MINIMUM_LIQUIDITY
}
```

**Story-103 propagation note**: This finding is filed under entry point `dev`, but the root cause is in the shared `UniPoolerCutoverCore`, which the story-103 mainnet cutover also inherits. When the story-103 entry point is audited, the same `contract:function` will get a **different fingerprint**, because `entryPoint` is folded into the hash. Reconcile it against `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` rather than re-filing it as new. The fix has to land in the core (or in a 103-only seeding branch) before the 103 broadcast.

**Related ledger entries (not duplicates)**: run-38 `balancer-holding` L-01 `59527bfa84786a87002d80b9bf678c5e798c4d9b2905609ac0f786bd46737632` (verifier covers 4 hardcoded addresses; story-103 step-0 precondition) and `batch-minter-replace` `22fc436d9483c95c1462e3775839e6da2ac3757ffd86155d587ad9a0d96791fe` (same griefing family, different script and root cause).

---

## QA Findings

### [Q-01] Phase 9.7's "minter principal cleared from the legacy strategy" post-condition holds only in forge's simulation; on the broadcast chain 1.2e13 wei of minter principal stays on the de-registered legacy DOLA strategy <!-- id: pps39q1 -->

- **Severity**: QA (classified down from Low)
- **issueId**: `pps39q1`
- **Fingerprint**: `9fa8eee3010ec38a3aa38c93bdc8141dd42eb6a2a469648865c02f5ca2f84787`
- **Fingerprint input**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:_repointDolaMinterAndSya:ForgeLocalPassPrecedesBroadcast:dev`
- **Root cause class**: `ForgeLocalPassPrecedesBroadcast` (normalised from the candidate class `SimulationBakedAmountOverTimeDependentState`)
- **Story**: 089 (`auto-complete`)
- **Location**: [script/DeployMocks.s.sol#L2504-L2513](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/script/DeployMocks.s.sol#L2504-L2513) (`_repointDolaMinterAndSya`, Phase 9.7 step 2)

```solidity
        uint256 principal = yieldStrategyDolaLegacy.principalOf(address(dola), address(minter));
        require(principal > 0, "story-089: minter holds no DOLA principal on the legacy strategy to move");
        uint256 balBefore = dola.balanceOf(deployer);
        yieldStrategyDolaLegacy.withdrawAsOwner(address(minter), deployer, principal);
        uint256 recovered = dola.balanceOf(deployer) - balBefore;
        require(
            yieldStrategyDolaLegacy.principalOf(address(dola), address(minter)) == 0,
            "story-089: minter principal not cleared from the legacy strategy"
        );
```

**Description**: Story 089 requires the minter's DOLA collateral to move off the legacy (`MockAutoDOLA`) strategy. Phase 9.7 reads `principalOf(minter)`, passes that number to `withdrawAsOwner`, then `require()`s `principalOf == 0`. forge evaluates both during the simulation pass, where the whole run shares one timestamp, and bakes the amount (`5000e18`) into calldata. On the broadcast chain (`anvil --block-time 2`), `MockAutoDOLA`'s time-based `_updateYield` runs between blocks, so `ERC4626YieldStrategy._acquireShares` (`convertToAssets`) credits `5000.000011999712006910e18` at the block-434 `minter.mint`. The block-436 `withdrawAsOwner(5000e18)` leaves 11,999,712,006,910 wei behind. The require never runs on chain.

**Impact**: The local end state differs from what dev asserts and logs (`Phase 9.7 end state asserted`). The minter stays the sole principal holder on a strategy that SYA no longer lists and cannot withdraw from, so legacy `totalBalanceOf(minter)` = 3,299.64 DOLA (all mock yield, including simulate-yield's 2,300) accrues to an unreachable bucket. No value is involved: the residue is about 1.2e-5 mock DOLA on a local anvil chain, and story 089 already discloses the legacy yield seed as stranded locally. The finding is kept because it is a concrete instance of the `ForgeLocalPassPrecedesBroadcast` class: a simulation-time self-assert passes over time-dependent state while the chain diverges. That class has caused real issues on mainnet entry points (siblings `78cb5942d4834f366ab7d5600a449c73bb8d43833dd8b822e25801d623e39cc6` fixed, `2c53e944caee2e74a1a351c9b30b9e92cd8feac28203e8d5c1c9b7d9e8b4102f` fix-pending). The 2026-09-15 UI-mock ruling does not apply, because the problem is dev's own post-condition being false on chain, not a mock-vs-mainnet fidelity gap.

**Evidence**: `script-audits/dev/side-effects.json` state writes (`YieldStrategyDolaLegacy` principal: block 435 = `5000.000011999712006910e18`, block 436+ = `11999712006910`); broadcast txs 433-436 (approve, `PhusdStableMinter.mint 5000e18`, `MockDola.mint`, `withdrawAsOwner(minter, deployer, 5000e18)`); `dev-run.filtered.log` shows Phase 9.7 principal `5000e18` in simulation.

**Recommended Mitigation**: Withdraw against the on-chain principal rather than a simulation-time number. Pass `type(uint256).max` (`withdrawAsOwner` caps to the available principal in `AYieldStrategy._withdrawInternal`), or principal plus a margin, and re-seed the deployer's actual DOLA delta. Alternatively, accept and log residual dust explicitly instead of asserting `principalOf == 0`.

```solidity
-        yieldStrategyDolaLegacy.withdrawAsOwner(address(minter), deployer, principal);
+        // capped to live principal at execution time, not the simulation-baked amount
+        yieldStrategyDolaLegacy.withdrawAsOwner(address(minter), deployer, type(uint256).max);
```

---

### [Q-02] Phase 9.7's maxMintPerDay restore assertion is vacuous locally: the pre-value is 0, which is exactly what registerStablecoin resets to <!-- id: pps39q2 -->

- **Severity**: QA (classified down from Low)
- **OWNER-RULING-BORDERLINE FLAG**: the 2026-09-15 "DeployMocks is a UI mock" ruling was **assessed and NOT applied**. This is borderline, and the **human decides between QA and wont-fix-by-ruling**. The finding concerns a self-assertion that cannot fail (test adequacy), not mock-vs-mainnet fidelity. But the only remedy is seeding a non-zero local cap, which an owner could reasonably call a fidelity change covered by the ruling. Story 092's fork tests own the mainnet proof of the reset-then-restore ordering.
- **issueId**: `pps39q2`
- **Fingerprint**: `c35d7cea7c0c71f66d59e5cf2b52b4ea844f1f1e1874540e5393664d8fc615a9`
- **Fingerprint input**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:_assertDolaRepoint:VacuousPostcondition:dev`
- **Root cause class**: `VacuousPostcondition`
- **Story**: 089 (`auto-complete`)
- **Location**:
  - [script/DeployMocks.s.sol#L2551-L2556](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/script/DeployMocks.s.sol#L2551-L2556) (`_assertDolaRepoint`)
  - [script/DeployMocks.s.sol#L2519-L2521](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/script/DeployMocks.s.sol#L2519-L2521) (the re-apply that the assertion is meant to guard)
  - [lib/phUSD-stable-minter/src/PhusdStableMinter.sol#L120-L128](https://github.com/Behodler/phoenix-phase-2-staging/blob/dfbf2f97643688aacee2f6f32281288e83cb0cac/lib/phUSD-stable-minter/src/PhusdStableMinter.sol#L120-L128) (`registerStablecoin` reset)

```solidity
// DeployMocks.s.sol, _assertDolaRepoint
        (address ys, uint256 rate, uint8 dec, bool enabled, uint256 maxMintPerDay,,) =
            minter.stablecoinConfigs(address(dola));
        require(ys == address(yieldStrategyDola), "story-089: minter DOLA registration is not the sDOLA strategy");
        require(rate == exchangeRate && dec == decimals_, "story-089: minter DOLA rate/decimals changed on repoint");
        require(enabled, "story-089: minter DOLA left disabled after repoint");
        require(maxMintPerDay == prevMaxMintPerDay, "story-089: maxMintPerDay not restored after registerStablecoin");

// DeployMocks.s.sol, _repointDolaMinterAndSya step 3
        yieldStrategyDola.setClient(address(minter), true);
        minter.registerStablecoin(address(dola), address(yieldStrategyDola), exchangeRate, decimals_);
        minter.setMaxMintPerDay(address(dola), prevMaxMintPerDay);

// PhusdStableMinter.sol, registerStablecoin
        stablecoinConfigs[stablecoin] = StablecoinConfig({
            yieldStrategy: yieldStrategy,
            exchangeRate: exchangeRate,
            decimals: decimals,
            enabled: true,
            maxMintPerDay: 0,
            mintedToday: 0,
            lastMintTimestamp: 0
        });
```

**Description**: Story 089's Background names the trap this phase exists to rehearse: `registerStablecoin` resets `maxMintPerDay` to 0 (`PhusdStableMinter.sol:125`), so `setMaxMintPerDay` must be re-applied. Its acceptance criterion is "maxMintPerDay equals its value before re-registration". DeployMocks never sets a non-zero DOLA cap, so `prevMaxMintPerDay == 0` (logged: `maxMintPerDay restored: 0`). If the `setMaxMintPerDay` line (2521) were deleted, `require(maxMintPerDay == prevMaxMintPerDay)` would still pass. The acceptance criterion is literally met (0 == 0), so this is not an F deviation, but the evidence for it carries no information.

**Impact**: The rehearsal reports the reset-then-restore ordering as asserted while proving nothing about it. A future regression in that ordering would pass dev silently. No asset or availability impact.

**Evidence**: `dev-run.filtered.log` Phase 9.7 line `maxMintPerDay restored: 0`; `PhusdStableMinter.registerStablecoin` writes `maxMintPerDay: 0`; grep finds no other `setMaxMintPerDay` for DOLA in `DeployMocks.s.sol`.

**Recommended Mitigation**: Seed a non-zero DOLA cap at registration (`setMaxMintPerDay(DOLA, X)`) and require `prevMaxMintPerDay > 0` before the restore check as an anti-vacuity gate, matching Phase 11.7's pattern. If the owner rules this within the UI-mock ruling, triage it as wont-fix and cite the ruling.

```solidity
         (address oldYS, uint256 exchangeRate, uint8 decimals_,, uint256 prevMaxMintPerDay,,) =
             minter.stablecoinConfigs(address(dola));
+        require(prevMaxMintPerDay > 0, "story-089: anti-vacuity: seed a non-zero DOLA cap before the repoint");
```

**Related ledger entries (not duplicates)**: dev L-06 `c76a8f9f94795987c0d2aa5626c69a8afc430b24423cf3c853b9199022e4e9d1` (story-073 stream probe vacuous) and dev Q-01 `9067d8a232b53421317b2663c757a6b80f5dc77076d138bd691a8fcfff49f947` (Phase 7.6 `tokenIdToDispatcher` not asserted).

---

## Centralization Risks

None this run.

---

## Cross-references

- **F-01** (`pps39f1`, fingerprint `b8036903340e5737add73ade7e0c0640dd93fad9020bc7ba5ce2685c5615dca9`): see [`spec-conformance.md`](./spec-conformance.md). Not repeated here.
- **Carryover QA** from earlier `dev` audits: see `submissions/carryover/qa-report-NN.md` (05, 21, 26, 27, 28, 29, 30).

## Appendix: automated QA baseline (4naly3er)

**Attached: [`4naly3er-report.md`](./4naly3er-report.md).** It ran on the writable `work/` clone at `dfbf2f9` (analysed files byte-identical to `src/`) with a `forge remappings`-generated `remappings.txt`. Both helpers in the `dev` closure were analysed with 0 AST failures: `script/helpers/UniPoolerCutoverCore.sol` (8 Low, 13 NC, 11 Gas categories) and `script/helpers/UniswapV2Deployer.sol` (1 Medium, 7 NC, 2 Gas categories). **`script/DeployMocks.s.sol`, where Q-01 and Q-02 live, could not be analysed.** solc-js raises `DeclarationError: Identifier already declared` because `IYieldStrategy` is reached through both the `reflax-yield-vault/` and `vault/interfaces/` remappings. This is the same gap as run 30, and silence on that file is a tool limitation, not a clean result. No 4naly3er item rises to a finding. The Low hits are approve() patterns on known tokens and tolerance or pro-rata arithmetic. The UniswapV2Deployer "Medium" matches interface declarations as library functions, a false positive.
