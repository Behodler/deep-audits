# Spot-reproduction: run-34, stable-staker-v2-cutover @ 84e2324

Re-run on 2026-09-16 by poc-validator from `phoenix-phase-2-staging/work`. Nothing was broadcast. Tests ran one after another with `-j 2`.

Provenance: `work` HEAD and `src` HEAD are both `84e2324829bd6470ea4a42480290c5239dbec49e`. `git ls-tree -r 84e2324 | grep audit-run34` returned nothing, so `test/audit-run34/CutoverAuditRun34.t.sol` was written by the audit, not upstream. The cutover script, verifier, core helper and the three project suites in `work` are byte-identical to `src`.

| # | Item | Verdict |
|---|------|---------|
| 1 | Preview @ 25988932 | CONFIRMED |
| 2 | Preview @ 25985945 reverts | CONFIRMED (loss 2.09 bps, not ~2.07; see notes) |
| 3 | Two key tests pass | CONFIRMED pass. `test_B_previewRun_atStory087Block` has NO assertion (vacuous). P7 test is sound, but "live" means less than the name says |
| 4 | run34 15/0; project 19+16+20 | CONFIRMED |
| 5 | `_maxLossBps` / `ERC4626_MAX_LOSS_BPS` | CONFIRMED to exist. The path the auditor wrote is WRONG |

## 1. Preview at 25988932
- Exit code 0. There are 9 `GLOBAL_PAUSE|` lines: phase0 (registered=26), then after-phase1 through after-phase6 (registered=25 each), then after-phase7 and after-phase8 (registered=27 each). All 9 say SUCCEEDED.
- `ETH_BUDGET|gasBudget / gasPriceWei / requiredWei: 22000000 300000000 7920000000000000`
- `ETH_BUDGET|SHORTFALL|OWNER balance / shortfall wei (TOP UP BEFORE :broadcast): 6424919451687286 1495080548312714`
- Phase 6 per-pool figures (bound = the per-pool bps loss bound; loss = P snapshot minus V2 totalStaked, as a pool total):

| Pool | R realized | P snapshot | V2 totalStaked | bound | P to R | P to V2 |
|------|-----------|-----------|----------------|-------|--------|---------|
| DOLA | 1222669637024202235699 | 1222727602453502485450 | 1222611470718702162733 | 2 bps | 0.474 bps | 0.950 bps |
| USDC | 1966404164 | 1966476179 | 1966332129 | 2 bps | 0.366 bps | 0.733 bps |
| USDe | 2565850122745184805919 | 2566815465400000000000 | 2558152572376949251495 | 61 bps | 3.76 bps | 33.75 bps |

All three pools logged "post-migration OK".

## 2. Preview at 25985945
- Exit code 1. The run printed `Error: script failed: cutover-post: cutover lost more principal than the strategy can explain`.
- It failed in Phase 6, on the DOLA pool (the first pool). The run got through "migrated 9 users / 1 batch" but never printed "exit realization", so the failure came before that line.
- The failing check is the per-user bound at `script/helpers/StableStakerCutoverCore.sol:499-502`.
- DOLA exit leg: R = 1222601073909172120703 against P = 1222727602453502485450, a loss of 1.035 bps.
- The last user checked before the revert was OWNER 0xCad1…D0B6: pre 50176872843431, post 50166371529588. That is a loss of 10501313843 wei (2.093 bps), against an allowance of 10035375568 wei (2 bps + 1000 wei).
- So we observe 2.09 bps, where the prior agent claimed ~2.07 bps. The failing user's stake is dust (5.0e13 wei, about 0.00005 DOLA).

## 3. Key tests
Both passed (2/0/0).

`test_B_previewRun_atStory087Block` is **vacuous**. It wraps `h.run()` in try/catch and only logs; it contains no assert, so it passes whether `run()` succeeds or reverts. The logged line does say `REVERTED|cutover-post: cutover lost more principal than the strategy can explain`, and that matches item 2. As a regression test it proves nothing. It should `fail()` in the try branch and `assertEq` the decoded reason in the catch branch.

`test_P7_everyHaltPoint_breakerLive_resumeConverges` is **sound, with a narrower meaning of "live"**:
- It loops k = 0..8. `_p7Steps` follows the Phase-7 order in the source at `script/CutoverStableStakerV2Mainnet.s.sol:703-747`: buffer recipient DOLA, buffer recipient USDC, V1 mint revoke, V2.setPauser, V2.unpause, register V2, Antimatter.setPauser, register Antimatter. `_retireV1` is a no-op on a normal run.
- k = 7 is the halt right after `Antimatter.setPauser`, before register(Antimatter). It is iterated, and its log says LIVE and CONVERGED.
- For every k it asserts that the breaker is live after resume and that V2 is unpaused. After the loop it asserts `dead == 0`, and that assertion is real.
- Caveat 1: `_tryGlobalPause` counts as "LIVE" whenever `Pauser.pause()` does not revert and every contract **registered** at that moment ends up paused. It does not check that V2 or Antimatter is reachable. At k = 5 (V2 unpaused, not yet registered) a global pause cannot reach V2, and the test still reports LIVE.
- Caveat 2: the resume runs with the harness `previewFlag = true`, and `p0` sets `isPreview = true`. It is broadcast-ordered but runs in preview mode.
- Caveat 3: it forks at the run-33 block 25981150, not the live block.

## 4. Suites
- `test/audit-run34/CutoverAuditRun34.t.sol`: 15 passed, 0 failed, 0 skipped.
- `test/CutoverStableStakerV2Mainnet.fork.t.sol`: 19/0/0.
- `test/StableStakerCutoverDust.t.sol`: 16/0/0.
- `test/VerifyStableStakerV2CutoverGuards.t.sol`: 20/0/0.
- Project total 55/0, which matches the claim.

## 5. Source location
The correct repo-relative path is `script/CutoverStableStakerV2Mainnet.s.sol`, not `lib/phoenix-phase-2-staging/script/...`.
- `ERC4626_MAX_LOSS_BPS = 2` is at L154. The comment justifying it is L147-153.
- `_maxLossBps` is at L1220-1223 (NatSpec L1214-1219).
- `_maxLossBps` is also called from `script/VerifyStableStakerV2Cutover.s.sol` L251, L375, L430, and is referenced in `script/helpers/StableStakerCutoverCore.sol` L467.
