# QA Report: phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 34)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `84e2324829bd6470ea4a42480290c5239dbec49e` (branch `master`). Baseline `29aeb2b` (run 33).
- **Audit type**: `/audit-script`, run 34
- **Entry Point**: `stable-staker-v2-cutover` (`package.json` → `stable-staker-v2-cutover:preview` / `:broadcast`, with the story-086 `:verify` tail)
- **Stories**: story-082/083 (per-user loss bound), story-084 (V1 retirement / breaker liveness), story-087 (audit-33 fix wave), all under `~/code/product-owner/stories/phStaging2/`.
- **Fork harness**: `phoenix-phase-2-staging/work/test/audit-run34/CutoverAuditRun34.t.sol`, mainnet forks at blocks **25985945** (story-087 planning block) and **25988932** (live block), inheriting the unmodified script and core. Full-file run: `fork-logs/r34-gapfix-fullfile.log` (**19/19 PASS**).
- **Log paths** below are relative to `phoenix-phase-2-staging/reports/34/script-audits/stable-staker-v2-cutover/`.

## Summary

| Severity | New this run | Total in this bundle |
|----------|-------------:|---------------------:|
| Low Risk | 1 | 1 |
| QA (doc/behaviour) | 1 | 1 |
| Centralization | 0 | 0 |
| **Total** | **2** | **2** |

This run produced no centralization findings.

| Label | Issue ID | Fingerprint | Title (short) | Verified | Borderline |
|---|---|---|---|---|---|
| L-08 | `pps34l8` | `6022a9eb9989…` | Phase 6 ERC4626 loss bound (2 bps) sits inside autoDOLA's stepwise live spread; bound enforced only in forge's local pass | fork (2 blocks) | yes, Medium watch |
| Q-04 | `pps34q4` | `a62956952abd…` | Doc and NatSpec claim every Phase 7 halt keeps the breaker live; at halt 5 a global pause does not reach V2 | fork | yes, Low watch |

> **Labels are run-scoped.** L-08 and Q-04 continue this entry point's per-entry-point sequence (run 31: L-01..L-03, F-01..F-03, Q-01; run 32: L-04, Q-02, Q-03; run 33: L-05..L-07). The classifier's run-local labels (L-01, Q-01) were overridden accordingly. Use the `issueId` or fingerprint as the stable handle.

### Carryover QA (not re-sectioned here)

Prior still-open entries for this entry point are carried, not merged, in `submissions/carryover/`:

- [`carryover/qa-report-31.md`](./carryover/qa-report-31.md): L-01, L-02, L-03
- [`carryover/qa-report-32.md`](./carryover/qa-report-32.md): L-04, Q-02
- [`carryover/qa-report-33.md`](./carryover/qa-report-33.md): L-05, L-06, L-07
- [`carryover/spec-conformance-31.md`](./carryover/spec-conformance-31.md): run-31 faithfulness entries

**All carried entries are proposed fixed at run 34, pending human confirmation via `/ledger`.** Audit 34 changed no status. Each carryover header names the evidence and the exact `/ledger ... fixed <fp>` command.

### Relationship to prior findings and faithfulness cross-listing

- **Q-04 is `residualOf` L-05** (`pps33l5`, `fc44ca36bccc72681b8ec2f608c5539068ad4a705e4185adb16bd96ba88d43c5`): it is the one-transaction trade-off inherent in L-05's unpause-before-register fix, not an incomplete fix.
- **L-08** absorbs the residual runbook gap noted against Q-02 (`pps32q2`): the runbook does not state that the Phase 6 bound depends on the autopool regime.
- Both findings are also Law-2 deviations (L-08 against stories 082/083/087; Q-04 against the documented breaker guarantee) and are cross-listed as pointers in [`spec-conformance.md`](./spec-conformance.md). This file is their primary report.

---

## Low Risk Findings

### [L-08] The Phase 6 per-user loss bound (`ERC4626_MAX_LOSS_BPS = 2`) sits inside autoDOLA's stepwise live spread, so `:preview`'s go/no-go flips between blocks; the bound is enforced only in forge's local pass, so a regime step during the Ledger session lands a migration above 2 bps that only `:verify`'s live-balance aggregate detects <!-- id: pps34l8 -->

**Flagged for human review: borderline Medium.**

- **Severity**: Low (operational hazard / footgun, Law 3; Law-2 deviation from stories 082/083/087)
- **Entry Point**: `stable-staker-v2-cutover`
- **Fingerprint**: `6022a9eb99899924db7239991e3f47124815eb4d15dec6ad2636ed32b88dd3ac`
- **Stories**: story-082/083 (per-user bound ≤ 2 bps + 1000 wei), story-087 (Concerns claim about the verifier)
- **Root cause**: [CutoverStableStakerV2Mainnet.s.sol#L147-L154](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L147-L154) (constant and NatSpec) and [CutoverStableStakerV2Mainnet.s.sol#L1220-L1223](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L1220-L1223) (`_maxLossBps`)

```solidity
    /// @dev Per-user loss bound on the 1:1 ERC4626 strategies. The story planned 0 bps, but the live         // L147
    ///      autoDOLA autopool is NOT loss-free on either leg: the planning preview (block ~25975061)
    ///      measured, per leg, autoDOLA: exit R/P = 1 - 1.70e-6, re-deposit x * (1 - 1.73e-6)
    ///      (~0.034 bps round trip); autoUSDC: exit R/P = 1 - 4.32e-5, re-deposit ~ 1 - 4.3e-5
    ///      (~0.86 bps round trip). 2 bps is ~2.3x the worst observation: loose enough not to trip on
    ///      the autopools' own valuation spread, tight enough that a real vault loss still stops the
    ///      run. Recorded in story 082's Autonomous Decisions.
    uint256 public constant ERC4626_MAX_LOSS_BPS = 2;                                                       // L154
```

```solidity
    function _maxLossBps(address ys) internal view returns (uint256) {                                      // L1220
        if (_marketAdapter(ys) == address(0)) return ERC4626_MAX_LOSS_BPS;
        return 2 * ICutoverStrategy(ys).slippageToleranceBps() + 1;
    }                                                                                                       // L1223
```

**Description**

`ERC4626_MAX_LOSS_BPS = 2` is the per-user loss bound (pre → credited, plus `WEI_SLACK = 1000` wei) on the ERC4626 strategies, and since story 087 also the bps part of the pool's exit-realization bound. Its NatSpec justifies 2 bps as about 2.3x the worst observed autopool round trip, based on a single planning sample.

On a mainnet fork the live autoDOLA round-trip spread is stepwise rather than stable:

- At block **25985945** (the story-087 block), all 9 DOLA users breach the bound at 2.069-2.093 bps, and `:preview`'s `run()` reverts with the exact bound revert string.
- At block **25988932**, all 9 pass at 0.948-0.959 bps, and the full preview passes all 9 stages.

The observed high-spread regime lasted about 22.5 hours. The bound is evaluated only in forge's local pass. The landed Phase 6 transactions do not re-check it on chain. If the regime steps up during the roughly 30-transaction Ledger session, the migration lands above 2 bps. On that landed state, the resume-shape check and `:verify`'s per-user checks both pass. Only `:verify`'s live per-pool aggregate reverts (short 0.008936 DOLA on the fork), and about 0.009 DOLA of organic V2 stake would mask that.

Story 087's Concerns section claims that the verifier's per-user credit check bounds the total. That is false: it covers only the re-deposit leg.

**Impact**

- **Go/no-go instability.** `:preview` flips red or green between blocks with no code change (red for about 22.5 h in the observed regime). This fails closed before any transaction: V1 keeps operating, no funds are locked, and the cutover can be retried.
- **Over-spec migration without a robust detector.** If the step happens mid-session, stakers are charged a round trip above the stated 2 bps bound. At current pool size that is about 0.26 DOLA of total spread (socialized by design, F-02 wont-fix), of which about 0.009 DOLA (under $1) exceeds the spec. The only detector that sees the landed state is a maskable aggregate.
- **Operational friction (by inspection, not executed).** A local-pass revert can leave a stale progress file that must be trimmed by hand.

Likelihood is low: it requires a discrete autopool regime step inside a single signing session, and steps were observed hours to days apart. It is not downgraded to QA because it is fork-proven, the constant's NatSpec rationale is empirically false, and a competent owner would be surprised that a green local pass bounds nothing about the landed Phase 6 transactions.

**Borderline-Medium note** (`borderline: true`, `flaggedForHumanReview: true`)

1. **Medium by availability** was rejected because the blocked function is a pre-broadcast owner migration, not a live user path. **Reconsider Medium if the cutover becomes time-critical** (for example, V1 deprecated or paused while awaiting V2), or if the stale progress-file state is proven to block a resume non-trivially (currently shown only by inspection).
2. **Magnitude scales with TVL.** The over-spec leak is proportional (bps). **Re-weigh toward Medium value leak if pool sizes grow materially (about 100x) before broadcast.**

**Evidence** (mainnet forks @25985945 and @25988932; `CutoverAuditRun34.t.sol`, 19/19 PASS in `fork-logs/r34-gapfix-fullfile.log`)

- `test_B_previewRun_atStory087Block` → PASS: asserts the exact bound revert string at 25985945 and fails if `run()` succeeds. An earlier vacuous version was corrected (`fail()` on success, `assertEq` on the revert reason); the PASS is at `r34-gapfix-fullfile.log` L1335.
- `test_B_previewRun_atCurrentBlockPasses` → PASS: `B_LIVEBLOCK|preview run() PASSED at 25988932`. Also `fork-logs/preview-25988932.log` (PASS, 9 stages).
- `test_B_087Block_dolaPerUserLossTable` → PASS: 9/9 `BREACH` (4 non-dust), loss 20693-20928 × 1e-4 bps.
- `test_B_liveBlock_dolaPerUserLossTable` → PASS: 0/9 breach, 0.948-0.959 bps.
- `test_B_driftLanding_postBroadcastTools` → PASS: resume-shape PASS; verifier `REVERTED|verify: aggregate: V2 booked total 1222474121170267702467 below the principal due net of self-exits (floor 1222483056933011775952) for DOLA`.
- `test_B_liveLoss_atLiveBlock`, `test_B_liveLoss_atRun33Block`, `test_B_liveLoss_atStory087Block` → PASS (per-pool `LIVE|...` realization and per-user tables across three blocks).
- `side-effects.json` → `autoDolaSpreadRegime`. Spot-reproduced by poc-validator (`spot-reproduction.md` items 1, 2, 5).

**Recommended Mitigation**

1. Re-derive `ERC4626_MAX_LOSS_BPS` in its own story from a multi-day sample of autoDOLA/autoUSDC `previewRedeem`/`previewDeposit` versus `convertToAssets`. The sample should cover at least one up-step (observed max 2.07 bps round trip). For example, use 2x the observed max (about 5 bps). Rewrite the L147-153 NatSpec to cite that sample.
2. In `_initiatePool`, for ERC4626 pools, pre-quote the round trip before `initiateMigration`, as is already done for the market strategy:
   - exit = `previewRedeem(convertToShares(P))`
   - re-deposit = `convertToAssets(previewDeposit(credit))`

   Log `LOSS_HEADROOM|token|bps` in preview, and STOP AND REPORT when it exceeds the bound.
3. In the runbook (`//:broadcast`), state:
   - that the Phase 6 bound depends on the autopool regime;
   - that `:preview` must be re-run immediately before signing;
   - that a red `:verify` aggregate right after a green local pass means the regime moved mid-session, and a resume will not detect it;
   - what to do with a progress file left by a local-pass revert: delete it when no transaction was sent.
4. Correct story 087's Concerns claim that the verifier's per-user check bounds the total, or add a per-user total (pre → credited) check to the verifier. Reconstruct pre-migration principal from the `MigratedOut` credit as `credit * P / min(R, P)`.

```solidity
// Sketch for (2), ERC4626 pools only, in _initiatePool before initiateMigration
uint256 exitAssets = IERC4626(vault).previewRedeem(IERC4626(vault).convertToShares(P));
uint256 reDeposit  = IERC4626(vault).convertToAssets(IERC4626(vault).previewDeposit(exitAssets));
uint256 lossBps    = (P - reDeposit) * CUTOVER_MAX_BPS / P;
console.log("LOSS_HEADROOM", token, lossBps);
require(lossBps <= _maxLossBps(strategy), "Phase6: autopool round trip above bound - STOP AND REPORT");
```

---

## QA Findings

### [Q-04] The `//stable-staker-v2-cutover:broadcast` doc key and the Phase 7 NatSpec claim every Phase 7 halt point keeps the breaker live, but at halt 5 (after `V2.unpause()`, before `Pauser.register(V2)`) a committed global `Pauser.pause()` does not reach StableStakerV2 <!-- id: pps34q4 -->

**Flagged for human review: borderline Low.**

- **Severity**: QA (doc/behaviour mismatch with no reachable value path; non-obvious Law-3 consequence)
- **Entry Point**: `stable-staker-v2-cutover`
- **Fingerprint**: `a62956952abd4fe22391f1fbff9f5e219961d003367a3c8a1dc4162529b9ea86`
- **Residual of**: L-05 (`pps33l5`) `fc44ca36bccc72681b8ec2f608c5539068ad4a705e4185adb16bd96ba88d43c5`, not an incomplete fix
- **Root cause**: [CutoverStableStakerV2Mainnet.s.sol#L689-L752](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L689-L752) (`_phase7_finalize`)

```solidity
        // owner-or-pauser, so it works after the hand-back. Every tx in this block keeps the breaker live.   // L736
        if (v2.pauser() != PAUSER) v2.setPauser(PAUSER);                                                     // L737
        // Unpause BEFORE registering: a paused registrant makes Pauser.pause() revert EnforcedPause (audit-33 L-05).
        if (!_doneV2Unpaused()) v2.unpause();                                                                // L739  <- halt 5 is after this tx
        require(_doneV2Unpaused(), "Phase7: V2 still paused");                                               // L740
        if (!IPauserRegistry(PAUSER).isRegistered(address(v2))) IPauserRegistry(PAUSER).register(address(v2)); // L741
```

- **Also relevant**: the file-header NatSpec at [L94-L95](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L94-L95), and `package.json` L52 (`//stable-staker-v2-cutover:broadcast`): "Every other halt point, including every Phase 7 one, keeps the breaker live and converges on resume."

```solidity
 *   `GLOBAL_PAUSE|phase0|BROKEN_BY_V1`. Every Phase 7 halt point keeps the breaker live, because V2 is   // L94
 *   unpaused before it is registered (audit-33 L-05); a resume from any of them converges.              // L95
```

**Description**

L-05's fix reorders Phase 7 to `setPauser(PAUSER)` → `unpause()` → `register(V2)`, so V2 is never registered while paused. That removes the `EnforcedPause` brick. It also opens a one-transaction state, halt 5, where V2 is unpaused but not yet registered. A committed global `Pauser.pause()` in that state succeeds, but it never reaches V2, so `V2.paused()` stays `false`. The documentation says every Phase 7 halt point keeps the breaker live, which does not hold for V2 at halt 5.

Containment holds at the strategy level. All three V2 strategies are registered with the Pauser and do pause, so under a global pause V2's `stake`, `withdraw` and `autoAnnihilate` revert `EnforcedPause` (`0xd93c0665`), and `claim` reverts `"claim disabled"`. No user entry point succeeds.

The intuitive owner remedy, a direct `V2.pause()`, reverts `onlyPauser`, because V2's pauser is already the Pauser contract. The working remedy takes 2 transactions: `V2.setPauser(OWNER)`, then `V2.pause()`.

The audit's own `test_P7_everyHaltPoint_breakerLive_resumeConverges` scored k=5 as LIVE because it probes only registered contracts. That is how the gap escaped the first pass (MR-34-SSV2C-04).

**Impact**

There is no value path: zero V2 user entry points succeed under a global pause at halt 5. The harm is operational. During an emergency, an operator who relies on the documented breaker coverage finds V2 unpaused, and the obvious remedy reverts. Likelihood is very low: it needs a halt at exactly that one transaction plus a concurrent incident. Assumes the strategies stay registered with the Pauser, which is true at `84e2324`.

**Borderline note** (`borderline: true`, `flaggedForHumanReview: true`)

**Raise to Low if any V2 user entry point becomes reachable under a global pause at halt 5.** For example: a strategy is later unregistered, or a new V2 path is added that is not gated by the strategy pause. A reviewer could argue Informational. QA is kept so the correction stays tracked, since L-05 is proposed fixed and a note attached there would disappear.

**Evidence** (mainnet fork; `CutoverAuditRun34.t.sol`, 19/19 PASS in `fork-logs/r34-gapfix-fullfile.log`)

- `test_P7_halt5_globalPauseCannotReachV2` → PASS (`fork-logs/r34-gapfix-halt5.log`):
  - `HALT5|V2=0x5582...8161|pauser=<Pauser>|registered=0|paused=0`
  - `HALT5|committed Pauser.pause() OK|V2.paused()=false`
  - per pool (DOLA, USDC, USDe): `strategyRegistered=1|strategyPaused=1`; `stake` / `withdraw` / `autoAnnihilate` `REVERTS|0xd93c0665`; `claim` `REVERTS|StableStaker: claim disabled`
  - `HALT5|user entry points that SUCCEED with V2 unreached=0`
  - `R1 OWNER V2.pause() direct|REVERTS (onlyPauser)`; `R2 OWNER setPauser(OWNER) + pause()|WORKS (2 txs)`; `R3 OWNER register(V2) + second global pause|REVERTS|err=0xd93c0665`
  - `HALT5|resume converged|registered=1|committed global pause reaches V2`
- `test_P7_everyHaltPoint_breakerLive_resumeConverges` → PASS, with the caveat above: it checks only registered contracts, so its k=5 LIVE verdict does not cover V2 (`spot-reproduction.md` item 3, Caveat 1).

**Recommended Mitigation**

Correct the `//stable-staker-v2-cutover:broadcast` doc key and the cutover NatSpec to name the halt-5 window: V2 is unpaused but not yet registered for one transaction. Record its containment (all three strategies are registered, so V2 value paths revert under a global pause) and the OWNER remedy (`V2.setPauser(OWNER)` then `V2.pause()`; a direct `V2.pause()` reverts). Optionally, extend the Phase-8/preview `GLOBAL_PAUSE` probe to assert that V2 (and Antimatter) are actually paused after the simulated pause, not only that `Pauser.pause()` did not revert.

```solidity
// Optional probe hardening, inside the snapshot-isolated simulated global pause
IPauser(PAUSER).pause();
require(ICutoverStaker(address(v2)).paused(), "GLOBAL_PAUSE: Pauser.pause() did not reach V2");
require(antimatter.paused() || !IPauserRegistry(PAUSER).isRegistered(address(antimatter)),
    "GLOBAL_PAUSE: Pauser.pause() did not reach registered Antimatter");
```

---

## Centralization Risks

None this run. Owner-controlled actions in this entry point were assessed under Law 3. Their non-obvious consequences are filed above as footguns (L-08, Q-04).

---

## Appendix: automated QA baseline (4naly3er)

**No report was produced this run (tooling gap, same as runs 31-33).** 4naly3er was not re-attempted on this scope (`script/CutoverStableStakerV2Mainnet.s.sol`, `script/helpers/StableStakerCutoverCore.sol`, `script/VerifyStableStakerV2Cutover.s.sol` at `84e2324`). In the three prior runs on the same files it failed every time: in run 33, compilation failed with `@forge-std/Script.sol import not found`, because the project resolves imports only through `foundry.toml`; in run 32, the staged-`remappings.txt` fallback hit its 480 s cap without writing a report; in run 31, the tool hung for more than 32 minutes. The import layout is unchanged: there is still no `remappings.txt`, and `foundry.toml` has no diff between `29aeb2b` and `84e2324`.

All entries in this bundle come from the script-audit pipeline and the mainnet fork harness, not from a bot report.
