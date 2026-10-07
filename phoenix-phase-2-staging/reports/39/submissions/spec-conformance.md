# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit of the `dev` entry point (run 39)

**Project**: `phoenix-phase-2-staging`  ·  **Run**: `phoenix-phase-2-staging-39`
**Commit**: `dfbf2f97643688aacee2f6f32281288e83cb0cac` (`dfbf2f9`), branch `master`
**Baseline**: `e6eded0` (`entryPointBaselines.dev`, set by run 30)
**Entry point**: `dev`

This run raises **one new Law-2 finding**, `F-01` (`pps39f1`). It has no asset, value or
availability impact, so it **does not owe a separate High/Medium label or report**. The other
run-39 findings are not faithfulness deviations. `L-01`, `Q-01` and `Q-02` are in the QA channel.
Story 089's acceptance criterion behind `Q-02` is literally met (0 == 0), so the classifier did not
treat `Q-02` as an F deviation.

Earlier `dev` Law-2 findings that are still open (`pps28f1`, `pps28f2`, `pps28f3`, `pps29f4`, `pps30f1`)
were not re-graded. They are carried verbatim, with fingerprints and recommendations, in
`carryover/qa-report-28.md`, `qa-report-29.md` and `qa-report-30.md` (Part B of each).

---

## F-01: `simulate-yield.sh` still feeds `MockAutoDOLA` after story 089's repoint, so dev's yield-simulation step reaches no live DOLA consumer <!-- id: pps39f1 -->

- **issueId:** `pps39f1`  ·  **Fingerprint:** `b8036903340e5737add73ade7e0c0640dd93fad9020bc7ba5ce2685c5615dca9`
- **Fingerprint input:** `lib/phoenix-phase-2-staging/simulate-yield.sh:main:StaleTargetAfterRepoint:dev`
- **Severity:** QA (faithfulness channel). **Status:** open (new).
- **Location:** `lib/phoenix-phase-2-staging/simulate-yield.sh#L19-L48` (`main`)
- **Story:** 089, `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/089-deploymocks-sdola-mock-and-v2-dola-destination.md`. State: **`auto-complete`** (final state; machine approval, not human-reviewed).
- **Root cause class:** `StaleTargetAfterRepoint`

### What story 089 says (verbatim)

The story itself discloses the follow-up. Glob of the whole `phStaging2` tree for `089-*.md` returned exactly one document. Its text in four places:

Implementation Notes, *Execution-time findings* (line 104):

> - **autoDOLA-specific**: `simulate-yield.sh` reads `.contracts.MockAutoDOLA` and mints DOLA into the autoDOLA vault. After this story the local minter, V2 and SYA all sit on the sDOLA strategy, so that script now pumps yield into the LEGACY vault, which nothing skims any more. It needs retargeting to `MockSDOLA` (not done here: outside this story's file list). Follow-up candidate.

Autonomous Decisions, *Execution Summary* (line 182):

> - Follow-up candidate: retarget `simulate-yield.sh` from MockAutoDOLA to MockSDOLA (see Implementation Notes).

Review Results, *Issues Found* (line 216):

> - **`simulate-yield.sh` still targets MockAutoDOLA (disclosed follow-up):** after this story it pumps yield into a vault that nothing skims. Retargeting it to MockSDOLA is outside this story's file list.

Auto-Completed, *Non-blocking findings carried forward* (line 261):

> - [low] simulate-yield.sh still targets MockAutoDOLA, so it pumps yield into a vault nothing skims. Disclosed follow-up; outside this story's file list.

### The deviation

dev's step 6 ('Simulating yield') mints 2,300 DOLA into the vault at progress.31337.json .contracts.MockAutoDOLA. Since story 089's Phase 9.7, the minter, StableStakerV2 and SYA all sit on YieldStrategyDola over MockSDOLA. SYA no longer lists the legacy strategy, and its withdrawer flag there is revoked. The simulated yield therefore lands only in the legacy vault, and nothing in the live system can skim it. Story 089 (Implementation Notes, line 104; Review, line 216) records this as an out-of-file-list follow-up. simulate-yield.sh is unchanged since baseline, so the follow-up has not landed.

The disclosed follow-up has **not landed**. `simulate-yield.sh` is unchanged since the baseline, and
no tracked story covers it. A grep of the whole `phStaging2` tree for `simulate-yield` finds no story that retargets it. The only later mention, story 098 (`auto-complete`, line 154), explicitly scopes it out: "Post-deploy anvil tools (`simulate-yield.sh`, `dev-local.sh`, `server/index.js` health endpoint hardcoding 31337) are out of scope." So the earlier
`dev` behaviour, where step 6 simulates yield **for the live system**, stopped working when 089
landed, and the only record of that is the completed story's non-blocking notes.

### Why this is a Law-2 note, not a defect

Routed to spec-conformance as F-01 at QA severity, not as a Low defect. Story 089 itself scoped the retargeting out and recorded it as a disclosed follow-up ([low], carried at auto-complete), so 089's own stated behaviour is not violated. What is broken is a consequence: the earlier dev behaviour (step 6 simulates yield for the live system) silently stopped working when 089 landed, and the follow-up has not been landed or ticketed as its own story. Law 2 says to surface that to the owner and not bury it in the QA bundle. Because the story disclosed it, this is an outstanding-work note rather than a hidden defect. There is no security or value impact, so no Low/Medium rating. The UI-mock ruling does not apply, because this concerns dev's internal coherence, not mainnet fidelity.

### Impact

UI developers running npm run dev get no simulated DOLA surplus on the live strategy; SYA claim / yield displays are unaffected by the step that claims to drive them. Local only; no mainnet effect.

None. Local dev only: the 2,300 mock DOLA from dev's 'Simulating yield' step lands in the legacy MockAutoDOLA vault, which nothing live skims, so UI developers see no simulated DOLA surplus on the live sDOLA strategy.

### Evidence

Executed: MockAutoDOLA totalAssets 1000.12 -> 3300.12 DOLA; SYA isRegisteredStrategy(legacy) = false, (sDOLA) = true; legacy totalBalanceOf(minter) = 3,299.64 DOLA, unreachable (see DEV39-02). Story 089 lines 104, 182, 216, 261.

### Recommendation

Land the story-089 follow-up. Retarget simulate-yield.sh to .contracts.MockSDOLA (or call MockSDOLA.addYield), and assert that YieldStrategyDola's surplus for SYA increased after the step. If the work stays deferred, open a tracked story for it so the disclosure does not live only in 089's review notes.

---

## Run-39 Law-2 summary

| Label | issueId | Fingerprint | Story | Disposition |
|---|---|---|---|---|
| F-01 | `pps39f1` | `b8036903340e…` | 089 (`auto-complete`) | open (new). Disclosed, unlanded follow-up |

No unsafe-story (Law 1 over Law 2) flag was raised this run. The shared-core `L-01` (`pps39l1`,
`9a694ae01fe1…`) is a Law-1 availability finding against the story-103 mainnet cutover (`incomplete`),
not a faithfulness deviation. Story 103 does say to "follow the mitigation phStaging2:108 documents",
and the core does not yet carry that mitigation. That is recorded in `L-01`, not duplicated here.
