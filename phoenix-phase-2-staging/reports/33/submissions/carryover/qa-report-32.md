# Carryover QA report — audit 32 (entry point `stable-staker-v2-cutover`), carried at audit 33

> **Carryover QA report — audit 32** (cut down from
> [`reports/32/submissions/qa-report.md`](../../../32/submissions/qa-report.md)). Header prepended by audit 33.
> Per-finding text below is a **verbatim** copy; only the summary counts and the label table were cut to the retained set.
>
> - **Retained below (still open as of audit 33 @ `29aeb2b`): `L-04` (`pps32l4`), `Q-02` (`pps32q2`).**
> - **Removed as no longer live:** `Q-03` (`pps32q3`, `30510f331ea8…`) and `Q-01` (`pps31q1`, `ca095edfd77e…`) — both wont-fix (invalid, out of scope), owner 2026-09-15. The whole "Triaged wont-fix" section was deleted, so the body's "Not counted" link to it no longer resolves.
> - **Removed as carried elsewhere (still live, not a disposal):** the "Still open from run 31" section re-observing `L-02` (`pps31l2`). `L-02` originated in audit 31 and is carried in [`qa-report-31.md`](qa-report-31.md); audit 32's widened-surface write-up stays readable in the original report linked above.
> - **Labels are the originals.** Audit 32 minted no `L-01`..`L-03` of its own; the gaps are per-entry-point sequencing, not omissions.
> - **Audit-33 disposition per retained entry:**
>   - **`L-04` / `46c053534c58` — fixed for the Phase-1 mechanism it describes; HELD OPEN pending `L-05`. No `fixed` proposal recorded.** Story 084 reordered Phase 1 to `setPauser(OWNER) → Pauser.unregister(V1) → pause()`. `test_L04_breakerAtEveryPhase1StepAndPhase` shows the global pause reverting only in the single forced transaction between `setPauser(OWNER)` and `unregister`, and succeeding after every later Phase-1 step and after phases 2–6 (`fork-logs/r33-test_L04_breakerAtEveryPhase1StepAndPhase.log`). Story 084's claim that the breaker stays live for the whole session is still false: Phase 7 registers V2 while it is still paused and reopens a 3-transaction `EnforcedPause` window. That is a sibling root cause, filed as audit-33 **`L-05`** (`pps33l5`, `fc44ca36bccc…`), not an incomplete fix of this entry. Once `L-05` is dispositioned: `/ledger phoenix-phase-2-staging fixed 46c053534c58`.
>   - **`Q-02` / `1c859cdebb64` — STILL LIVE, re-observed (fingerprint reproduces); `lastSeenRun` bumped to audit 33.** `package.json` L49 is byte-unchanged. It now also contradicts story 084 (it says "pause V1" and "V1 pauser back to Pauser and V1 UNPAUSED", but the script retires V1 in Phase 1 and leaves it paused and unregistered) and story 085 (it describes "strategy principal >= V2 booked" as the post-condition; that check is now a lockstep and the loss gate is the aggregate floor), and it never mentions the story-086 `:verify` step. Fix before broadcast: rewrite the key to match story 082 as amended by 083–086, or reduce it to a pointer to the script NatSpec and the per-variant doc keys.
> - **Line numbers below were accurate at the originating commit `884ccf8`. Re-verify against current HEAD `29aeb2b` before acting.**
>
> Run 33: `/audit-script` on entry point `stable-staker-v2-cutover`, commit `29aeb2b`, baseline `884ccf8`, branch `master`, fork block 25981150. **No status was changed by audit 33** — every `fixed` below is a *proposal*; only a human `/ledger` action applies it.

---

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
| Low Risk | 1 | 0 | 1 |
| QA | 1 | 0 | 1 |
| Centralization | 0 | 0 | 0 |
| **Total** | **2** | **0** | **2** |

Not counted: **Q-03** (`pps32q3`) and **Q-01** (`pps31q1`), triaged wont-fix (invalid, out of scope) by owner 2026-09-15. See [Triaged wont-fix](#triaged-wont-fix-invalid-out-of-scope-by-owner-2026-09-15).

This run produced no centralization findings.

| Label | Issue ID | Title (short) | Origin | Verified | Recommended before broadcast |
|---|---|---|---|---|---|
| L-04 | `pps32l4` | Phase 1 → Phase 7 window leaves V1 paused and registered, so global `Pauser.pause()` reverts | new | fork-verified | **yes** |
| Q-02 | `pps32q2` | `//StableStakerV2Cutover` operator doc key describes the superseded story-082 end state | new | static + preview log | **yes** |

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

## Appendix: automated QA baseline (4naly3er)

**No report was produced this run (tooling gap, same as run 31).** The scope was the entry point's first-party Solidity at `884ccf8`: `script/CutoverStableStakerV2Mainnet.s.sol` and `script/helpers/StableStakerCutoverCore.sol`.

1. **basePath at the submodule root** could not be used. The project has no `remappings.txt` and resolves imports only through `foundry.toml`, which 4naly3er does not read.
2. **Staged run 1.** The two scope files were copied into a scratchpad staging tree, with a `remappings.txt` generated from the `foundry.toml` remappings rewritten to absolute submodule paths. The submodule was not modified. It failed with `lib/vault/src/interfaces/IYieldStrategy.sol import not found`, caused by a literal root-relative import in a nested dependency.
3. **Staged run 2**, with an added `lib/=<abs>/lib/` remapping. Compilation succeeded, with only solc warnings. Analysis then ran until the 480-second cap (`timeout` exit 124) and wrote no report. This matches run 31's hang of more than 32 minutes on the same scope.

There is no automated baseline for this bundle. All entries in this bundle come from the script-audit pipeline and the mainnet fork harness, not from a bot report.