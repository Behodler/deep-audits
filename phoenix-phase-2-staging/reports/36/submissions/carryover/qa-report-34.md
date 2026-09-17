# Carryover QA report: audit 34 (entry point `stable-staker-v2-cutover`), carried at audit 36

> **Carryover QA report, audit 34** (cut down from
> [`reports/34/submissions/qa-report.md`](../../../34/submissions/qa-report.md)). Audit 36 prepended this header and pruned one entry.
> Retained below (still `fix-pending` as of audit 36): **Q-04**.
> Removed as no longer live: **L-08** (`pps34l8`, `6022a9eb9989`): status `fixed` in the ledger as of audit 36.
> Labels are the originals. The empty Low section is the L-08 removal above, not an omission. Relative links in the body (`./carryover/…`, `./spec-conformance.md`) point into the audit-34 directory.
>
> - **`Q-04` / `pps34q4` / `a62956952abd4fe22391f1fbff9f5e219961d003367a3c8a1dc4162529b9ea86`: status `fix-pending (fix owed, not yet verified)`. Fix landed; PROPOSED `fixed` at run 36, a human must confirm.** Story 095 corrected the halt-5 overclaim in `//stable-staker-v2-cutover:broadcast` and the Phase 7 NatSpec. The recommendation's probe hardening was worded "Optionally" and was not done; the existing probe already asserts every registrant is paused, and the uncovered case is exactly the now-documented unregistered gap. Evidence: [`reports/36/script-audits/cluster-analysis.md`](../../script-audits/cluster-analysis.md). Apply with `/ledger phoenix-phase-2-staging fixed a62956952abd`.
> - **First seen:** phoenix-phase-2-staging-34 · **Last flagged:** phoenix-phase-2-staging-35 (`7ac6e70`) · **Not flagged at:** phoenix-phase-2-staging-36 (`91ed727`).
> - **Line numbers below were accurate at the originating commit `84e2324`. Re-verify them against current HEAD `91ed727` before acting.**

---

# QA Report: phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 34)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `84e2324829bd6470ea4a42480290c5239dbec49e` (branch `master`). Baseline `29aeb2b` (run 33).
- **Audit type**: `/audit-script`, run 34
- **Entry Point**: `stable-staker-v2-cutover` (`package.json` → `stable-staker-v2-cutover:preview` / `:broadcast`, with the story-086 `:verify` tail)
- **Stories**: story-082/083 (per-user loss bound), story-084 (V1 retirement / breaker liveness), story-087 (audit-33 fix wave), all under `~/code/product-owner/stories/phStaging2/`.
- **Fork harness**: `phoenix-phase-2-staging/work/test/audit-run34/CutoverAuditRun34.t.sol`, mainnet forks at blocks **25985945** (story-087 planning block) and **25988932** (live block), inheriting the unmodified script and core. Full-file run: `fork-logs/r34-gapfix-fullfile.log` (**19/19 PASS**).
- **Log paths** below are relative to `phoenix-phase-2-staging/reports/34/script-audits/stable-staker-v2-cutover/`.

## Summary

*Counts and the summary table updated by the audit-36 carryover to the retained set (original bundle: 1 Low, 1 QA; L-08 removed as fixed).*

| Severity | New this run | Total in this bundle |
|----------|-------------:|---------------------:|
| Low Risk | 0 | 0 |
| QA (doc/behaviour) | 1 | 1 |
| Centralization | 0 | 0 |
| **Total** | **1** | **1** |

This run produced no centralization findings.

| Label | Issue ID | Fingerprint | Title (short) | Verified | Borderline |
|---|---|---|---|---|---|
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

_L-08 (`pps34l8`) removed from this carryover copy: status `fixed`. See the header._

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
