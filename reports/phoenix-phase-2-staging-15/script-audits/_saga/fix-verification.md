# YS-swap saga — fix verification (run-15)

Head `0e190e8` · fork @ block `25313223` · RPC live · 2026-06-14

Live reads: ORIGINAL_STABLE_STAKER `0xbce8…079A` — owner `0xCad1…D0B6`, paused `false`, pauser `0x7c5A…85a3` (real Pauser contract, not the deployer EOA).

| Finding | Fix commit | Verdict |
|---|---|---|
| YS-24 (ba886105) tempPauser zero-gate | story-066 / e5f79ce | **FIXED** |
| YS-25 (75e4305a) zero-haircut floor | story-067 / 17dcfdf | **INCOMPLETE-FIX → new YS-26 (Medium)** |
| YS-21 (be9a5a92) live-staker pause no break-glass | story-065 | **FIXED** |

## YS-24 — FIXED
`PostMigrationCleanup.s.sol:382-385` drops `&& recordedTempPauser != address(0)` from the tempPauser require; the origPauser gate (`:371-374`, recorded **and** non-zero) is untouched. A recorded zero now passes while a genuinely-missing JSON key still fails loud via the `try/catch → tempPauserRecorded=false` path.

Traced the recorded value: `DeployTempStableStakerAndMigrators.s.sol:256` reads `tempStaker.pauser()` **before** line 270-271 sets it to OWNER. A freshly-deployed `StableStaker` leaves `pauser` uninitialised (`StableStaker.sol:55`, no ctor assignment), so the recorded value is a legitimate `address(0)`, persisted at `:303`. Zero is the *correct* value here (no governance pauser was ever wired on the throwaway temp staker) — it does **not** mask a misconfiguration, and restore-to-zero on the decommissioned temp staker is a harmless no-op. No new hole. The live-staker (origPauser) zero-rejection — the real hazard — is preserved, and the live pauser is a real non-zero contract, so a prod run passes.

## YS-21 — FIXED
`UnpauseStakerBreakGlass.s.sol` is fully standalone: reads **no** `ys-swap-deployments.json` / migration-inputs — only constants and live staker reads. `StableStaker.unpause()` is `owner() || pauser` (`StableStaker.sol:282`); the script signs as owner and preflights `require(staker.owner()==OWNER)`. Fork-confirmed: owner == `0xCad1…D0B6`. Idempotent early-return if `!paused()`.

- Fork preview ran clean (staker currently unpaused → "nothing to do").
- Fork test (transient): forced the live staker into the deploy-step paused state (`setPauser(OWNER)+pause`), then owner `unpause()` succeeded, `paused()==false`. A mid-suite halt leaves exactly the state breakglass needs (owner unchanged, staker paused); it requires no downstream artifact. It unsticks the stranded live USDe pool.

## YS-25 — INCOMPLETE-FIX (new finding YS-26, Medium)
The floor itself is correct and well-placed: `PostMigrationCleanup.s.sol:247-256`, `require(principalOf >= preMigBooked)` per token, `>=` (not `==`, which would falsely revert on legit surplus). On a **clean first run** the anchor is pinned by `SkimAndLeg1` preflight `:204-218` (snapshot totalStaked == on-chain `poolInfo[3]`), and the downstream-only placement is sound given the step8→step9 ordering. Sub-question (a) threading is tamper-free *while leg1-stakers.json is not re-gathered*.

**The gap (sub-question c), confirmed:** the fix is self-defeating on a resume.
1. `SkimAndLeg1` count preflight (`:187-194`) hard-reverts `"stale … re-run gather"` when `leg1.count != on-chain stakerCount`.
2. After leg1 drains the pool (`stakerCount→0`, `totalStaked→0`) and the broadcast halts **before** the preMigBooked persistence block (`:393-402`, the last writes in `run()`), a resume forces a re-gather.
3. `gather-migration-inputs.js:257-263` reads `totalStaked` **live** from `poolInfo[3]` and overwrites `leg1-stakers.json` (`:326`) with post-drain `0`.
4. The `SkimAndLeg1` re-run **skips** the `totalStaked==chain` preflight (`stakerCount==0` gate, `:204`) and persists `preMigBooked = 0`.
5. Step-9 floor degrades to `require(principalOf >= 0)` — **vacuous**.

The story-067 author's own comment (`SkimAndLeg1:388-392`) claims a resume "re-persists the IDENTICAL value instead of the post-drain 0" — false once the forced re-gather rewrites the snapshot.

Why it bites: with `preMigBooked` zeroed, the floor was the **sole** end-to-end zero-haircut guard. ResetAndRewire's step-6 post-assert is a one-sided `<=` over-credit ceiling (misses under-credit), and `_prefundShortfall` only **WARNs** on `injected < shortfall` (`SkimAndLeg1:523-528`), never reverts. So a real haircut (Phase-4 under-prefund + sub-swept principal) reaches step 9 uncaught and users withdraw less than booked. No malice, no concurrency — reachable through the documented resume runbook.

PoC: `test/PoC_YS25_PreMigBookedResumeZeroing.t.sol` (2 PASS) — first run catches a 1% haircut; resume re-gather zeroes the anchor and the same haircut passes vacuously. The existing `YsSwapMigrationHardening.t.sol::test_zeroHaircutGate_*` only unit-test a re-declared copy of the require expression (message + `>=` direction); they never exercise the JSON-bus threading or the resume re-gather, so they pass while the gap is live.

Fix options: make `preMigBooked` write-once (refuse to overwrite a recorded non-zero with a smaller value); **or** `require(preMigBooked > 0)` in cleanup so a zeroed anchor fails loud (the YS-22 pattern); **or** source it from a first-run-only file never overwritten on resume; **and** make `_prefundShortfall` hard-revert on `injected < shortfall` instead of warn.
