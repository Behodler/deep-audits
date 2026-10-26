# Reject zero intermediate tokens and inconsistent swapParams/pools in setRoute (audit 01 M-01 residual + mitigation 2)

Current Sprint: 1
Base Commit: 6b862aa0af3d3182d2fd311c4402a4056b69ef42
Execution Type: existing_worktree
Base Commit Updated: 2026-10-25T12:27:13Z

## Story Overview

Story 006 implemented audit 01 M-01 **mitigation 1** (`setRoute` validates the route the way Curve Router NG executes it) and made `MockCurveRouter` model Router NG's output resolution. Two holes remain, and the auditors will flag both on re-check:

1. **Zero token slot inside the executed prefix.** `setRoute` checks pool slots `path[2i+1]` and the delivered token `path[2k]`, but never the intermediate token slots `path[2i]` for `0 < i < k`. A route like `[usde, pool0, 0, pool1, usdc, 0…]` is accepted by `setRoute` *and* by `MockCurveRouter` (which overwrites the intermediate without checking it and delivers usdc). Story 006's review logged this as a non-blocking finding with "the real router most likely reverts" — an unverified guess. This story closes it at `setRoute` and replaces the guess with fork evidence.
2. **Mitigation 2: `swapParams`/`pools` are stored without any check against `path`** (audit L42). Implement the audit's suggested rule: swapParams rows `k..4` must be zero and executed rows non-empty; additionally pools `k..4` must be zero.

Goal: `setRoute` stores only routes whose path, swap params and pools are mutually consistent with how Router NG will execute them; the mock models the real router for these cases; fork tests prove the real router's behaviour rather than assuming it.

## Background

- Repo: `/home/justin/code/reflax-mint/sya-harvester`. Work happens in the existing sprint worktree `/home/justin/code/product-owner/worktrees/sya-harvester/audit-fixes` (branch `sprint/audit-fixes`, HEAD `02130d0` = story-006 GREEN, clean). Foundry, solc 0.8.26, cancun, optimizer on, **via_ir intentionally OFF — do not enable it**. Root `CLAUDE.md` mandates TDD (RED → GREEN → refactor).
- Router NG v1.1 `0x16C6521Dff6baB339122a0FE25a9116693265353` (Vyper 0.3.10). Loop: for hop i, `output_token = _route[(i+1)*2]`; swap using `_swap_params[i]` (and `_pools[i]` only for zap swap types 3/5/7); `if i == 4 or _route[i*2+3] == empty(address): break`. First empty pool slot at `path[2k+1]` → delivered token `path[2k]`; k=5 → `path[10]`. No Router NG source is vendored in the repo.
- swapParams row layout `[i, j, swap_type, pool_type, n_coins]`. `i`/`j` are coin indices and 0 is legal, so "row non-empty" must be tested on `swap_type` (Router NG rejects unknown swap types; repo notes one such rejection for swap_type 9 at `test/fork/MainnetRoutes.sol` L52). We ship swap_type 1 (exchange) and 2 (exchange_underlying) only; `pools` is all-zero on every shipped route.
- Audit text: `/home/justin/code/product-owner/scratchpad/planning-docs/phoenix/sya-harvester/audits/01/M-01-submission.md`. Mitigation 2 (L183), verbatim: "**2. Optionally, also check `swapParams` and `pools` against the path.** For example, require `swapParams` rows `k..4` to be zero, and the executed rows to be non-zero. This would reject inconsistent parameter matrices. It is defence in depth only…". Safe-config guidance at L193-195 suggests an `eth_call` of Router NG `exchange`.
- Previous story: `/home/justin/code/product-owner/stories/sya-harvester/auto-complete/audit-fixes/006-router-ng-contiguity-route-validation.md` (terminal). Its review finding #2 is item 1 above.

## File Locations

| File | Change |
|---|---|
| `src/SYAHarvester.sol` | New errors near L77-102; `setRoute` L134-161 new checks; NatSpec L121-133 |
| `src/interfaces/ICurveRouterNG.sol` | NatSpec L16-19: note swapParams/pools per-hop semantics |
| `test/mocks/MockCurveRouter.sol` | `resolveOutput` L34-41: revert on zero intermediate; `exchange` L43-58: revert on executed row with swap_type 0 |
| `test/mocks/MockCurveRouter.t.sol` | `_exchange` L49-53 must pass valid rows; new tests |
| `test/SYAHarvester.registry.t.sol` | `_params` L63-66 / `_pools` L68-70 helpers become k-aware; new tests; fix fixtures listed below |
| `test/SYAHarvester.routeGap.t.sol` | Check it still passes (k=1 fixture, row 0 only — expected fine) |
| `test/fork/SYAHarvester.fork.t.sol` | New fork tests beside the M-01 block L410-469 |
| `script/harvest.sh` | `KNOWN_ERRORS` L152-164: add new error signatures |

`test/utils/HarvesterFixture.sol` (`_path` k=1, `_params` row 0 only, `_pools` zero) and `test/fork/MainnetRoutes.sol` (USDe k=2 rows 0-1, DOLA k=1 row 0, pools zero) are already consistent with the new rules — do not change them unless a test proves otherwise.

## Technical Details

### Current `setRoute` (src/SYAHarvester.sol L134-161)

```solidity
if (token == address(0)) revert ZeroAddress();
if (path[0] != token) revert InvalidRouteStart(token, path[0]);
uint256 k;
while (k < 5 && path[2 * k + 1] != address(0)) k++;
for (uint256 i = 2 * k + 1; i < 11; i++) {
    if (path[i] != address(0)) revert InvalidRouteGap(i);
}
address rewardToken = sya.rewardToken();
address delivered = path[2 * k];
if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);
// store path, swapParams, pools, configured = true; emit RouteSet
```

### Required validator (append to the above; check order is part of the spec)

```solidity
/// @dev path[2i] is zero for some executed intermediate hop 0 < i < k (audit 01, M-01 residual).
error InvalidRouteToken(uint256 index);
/// @dev swapParams row `hop` is inconsistent with the path: executed rows (hop < k) need swap_type != 0,
///      rows hop >= k must be all zero (audit 01, mitigation 2).
error InvalidRouteSwapParams(uint256 hop);
/// @dev pools[hop] is non-zero for a hop the router never executes (hop >= k) (audit 01, mitigation 2).
error InvalidRoutePools(uint256 hop);

// order: ZeroAddress → InvalidRouteStart → InvalidRouteGap → InvalidRouteToken → InvalidRouteEnd
//        → InvalidRouteSwapParams → InvalidRoutePools
for (uint256 i = 1; i < k; i++) {
    if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);
}
// (existing InvalidRouteEnd check here)
for (uint256 h = 0; h < 5; h++) {
    if (h < k) {
        if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);
    } else {
        for (uint256 f = 0; f < 5; f++) if (swapParams[h][f] != 0) revert InvalidRouteSwapParams(h);
        if (pools[h] != address(0)) revert InvalidRoutePools(h);
    }
}
```

Implementation may restructure loops (e.g. combine) as long as the accepted/rejected set **and the error raised for each case** are exactly as specified.

## Implementation Notes

- **Check order matters for existing tests.** The new param/pool checks run *after* Gap and End so every existing revert test keeps its expected error (registry k=1 rejects at L156, L194, L207, L220, L256, L325; k=0 at L283, L292, L316; fork `test_fork_M01_gapRoute_rejectedBySetRoute` L421-431 passes USDe rows 0-1 with a k=1 gap path and must still get `InvalidRouteGap(10)`).
- **`InvalidRouteToken` placement**: after Gap, before End. `path[2k] == 0` is still reported by `InvalidRouteEnd(reward, 0)` (unchanged behaviour), so the token loop covers `1 ≤ i < k` only.
- **Registry fixtures that break and must be fixed (make helpers k-aware, e.g. `_params(uint256 k)` / `_pools(uint256 k)`):**
  - Rule "rows k..4 zero": `test_setRoute_storesSingleHop` (L332; also its round-trip asserts L345-350), `test_setRoute_emitsRouteSet` (L368), `test_clearRoute_resetsConfiguredAndEmits` (L385), `test_setRoute_acceptsNoHopRouteForRewardToken` (L304; k=0 → all rows and pools zero).
  - Rule "executed rows non-empty": `test_setRoute_storesFullFiveHopRoute` (L264) needs rows 0-4 with swap_type != 0; `test_setRoute_rejectsFiveHopEndingAtNonRewardToken` (L276) keeps `InvalidRouteEnd` thanks to ordering, but give it valid rows anyway.
  - `_pools()` sets `pools[0] = pool1`: legal for k ≥ 1 (pools for executed hops are unconstrained), illegal for k = 0.
  - Do not weaken any existing assertion to make it pass; change only the fixture inputs.
- **Mock fidelity** (`MockCurveRouter`): (a) `resolveOutput` reverts `ZeroIntermediateToken()` (new mock error) when any executed intermediate `_route[2i]`, `0 < i < k`, is zero — keep `NoHop` and `ZeroOutputToken`; (b) `exchange` reverts `BadSwapType(hop)` (new mock error) when an executed hop's `swap_type == 0`. Keep `setRate`/`rate`/`calls`/`Slippage`/input-pull API intact. Update `MockCurveRouter.t.sol` `_exchange` (L49-53) to pass a valid row per executed hop. The mock does not validate rows beyond the executed prefix — the real router ignores them; that is `setRoute`'s job.
- **Real-router evidence comes first; the mock must match it.** Fork tests run the real Router NG. If the real router does **not** revert on a zero intermediate token or on swap_type 0, do not paper over it: the `setRoute` rejection stays (it is the point of the story), make the mock match the real behaviour, make the fork test assert what really happens, and record the finding in Autonomous Decisions.
- **Fork RPC**: no `.env` exists; `foundry.toml` maps `mainnet = "${MAINNET_RPC_URL}"` and the fork base `vm.skip`s without it. Story 006 ran the fork suite with `MAINNET_RPC_URL=https://eth.drpc.org` at block 26_261_000 — do the same; if that RPC is unavailable, record it in Autonomous Decisions and ensure the fork tests compile.
- Fork template: `test_fork_M01_realRouterDeliversIntermediate_mockAgrees` (fork file L442-469) — `deal` USDe, approve Router NG, call `exchange` directly. Zero-intermediate path: `[A.USDE, POOL_USDE_CRVUSD, address(0), POOL_CRVUSD_USDC, A.USDC, 0…]` with `MainnetRoutes.usdeRoute().swapParams` and zero pools. Pool constants in `MainnetRoutes.sol` L69-73.
- `harvest.sh`: add `"InvalidRouteToken(uint256)"`, `"InvalidRouteSwapParams(uint256)"`, `"InvalidRoutePools(uint256)"` to `KNOWN_ERRORS`.
- Commit messages `[story-007] <message>`; stage files by explicit path.

## Out of Scope

- Mitigation 3 (story-001 rule text; the same last-non-zero rule in `/home/justin/code/reflax-mint/vault/src/AMMAdapters/CurveAMMAdapter.sol` L73-80), mitigation 5 (owner sweep/rescue, audit Q-03).
- Validating `i`/`j`/`pool_type`/`n_coins` against on-chain pool coins, or tying `pools[h]` to swap_type for executed hops. Defence in depth stops at the audit's suggested rule.
- Any deployment / phStaging2 change (phStaging2 does not pin sya-harvester). Moving the `audits` workspace `lib/sya-harvester` pin is the human's call.

## Checklist

- [x] RED: registry tests in `test/SYAHarvester.registry.t.sol` that fail today: zero intermediate `[usde, pool0, 0, pool1, usdc, 0…]` (k=2, valid rows 0-1) reverts `InvalidRouteToken(2)`; zero intermediate at index 6 in a k=4 route reverts `InvalidRouteToken(6)`; executed row with `swap_type == 0` reverts `InvalidRouteSwapParams(hop)`; non-zero row at hop k (e.g. single-hop with row 1 set) reverts `InvalidRouteSwapParams(1)`; non-zero `pools[k]` reverts `InvalidRoutePools(k)`; reward-token k=0 route with any non-zero row or pool reverts the matching error
- [x] RED: mock tests in `test/mocks/MockCurveRouter.t.sol`: zero intermediate reverts `ZeroIntermediateToken`; executed row with swap_type 0 reverts `BadSwapType(hop)`
- [x] Commit RED tests as `[story-007] RED: ...`
- [x] Add `InvalidRouteToken`, `InvalidRouteSwapParams`, `InvalidRoutePools` errors with NatSpec and implement the checks in `setRoute` in the specified order; update `setRoute` NatSpec to describe all rules
- [x] Update `src/interfaces/ICurveRouterNG.sol` NatSpec: swapParams row h / pools[h] are used only for executed hops h < k
- [x] Make registry helpers k-aware and fix the fixtures listed in Implementation Notes without weakening any assertion; all existing accept/reject tests keep their expected outcomes and errors
- [x] Add accept tests: full 5-hop route with 5 valid rows stored; single-hop with only row 0 and zero pools stored and round-tripped; reward-token k=0 route with all-zero params/pools still accepted (story-006 documented case)
- [x] Update `MockCurveRouter` (`ZeroIntermediateToken`, `BadSwapType`) and its doc comment; update `_exchange` in `MockCurveRouter.t.sol` to pass valid rows; all mock tests green
- [x] Fork tests (gated on `MAINNET_RPC_URL`, inheriting `SYAHarvesterForkTest`): (a) real Router NG `exchange` with the zero-intermediate path — record and assert actual behaviour (expected: revert); the mock agrees; (b) real Router NG with an executed row whose swap_type is 0 — record and assert actual behaviour (expected: revert); the mock agrees; (c) `setRoute` rejects the zero-intermediate path with `InvalidRouteToken(2)`; (d) `MainnetRoutes.configure` still succeeds and a harvest leaves the harvester empty (`_assertHarvesterEmpty`)
- [x] Add the three new error signatures to `KNOWN_ERRORS` in `script/harvest.sh`
- [x] `forge build` clean; `forge test` passes (unit suites green; fork suites run with `MAINNET_RPC_URL` if available, otherwise skip — record which and the fork results in Autonomous Decisions)

# Concerns

- **Bundling**: mitigation 2 is bundled with the M-01 residual at the human's request (same function, same fixtures). Revisit the split only if the diff becomes unreviewable.
- **"Executed rows non-zero" interpreted as `swap_type != 0`**: `i`/`j` are legitimately 0, so a whole-row non-zero test would be weaker than needed only in contrived cases; `swap_type` is what Router NG dispatches on.
- **Pools rule added beyond the audit text**: audit mitigation 2 names `pools` but gives no rule; we require `pools[k..4] == 0` (never read by the router) and leave executed-hop pools unconstrained because zap swap types legitimately use them.
- **Dedicated errors rather than reusing `InvalidRouteGap`**: clearer revert reasons for operators and auditors; costs three `KNOWN_ERRORS` entries.
- **Reward-token k=0 route** (story 006's documented harmless case) now additionally requires all-zero params and pools. Still accepted in its canonical form; never executed.
- **Real-router behaviour is unverified at planning time**: the fork tests decide it, and the mock follows the real router, not the other way round.

---
## Autonomous Decisions
**Date**: 2026-10-25T12:45:00Z
**Command**: execute-story 007 in sya-harvester, sprint audit-fixes --inline-delegation

### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: story-manager (discovery, base-commit write, failure-report check, checklist validation, review transition), sprint-manager (sprint + dependency validation), repo-manager (worktree health, commits, product-owner checkpoint), base-commit-validator, workflow-validator (pre-execution and post-transition), implementation subagent (step 6)
**Independence**: reduced — these verdicts were reached by the agent that also performed/observed the work

### Decision 1: Story selection, sprint, dependency
- **Situation**: Argument `007 in sya-harvester, sprint audit-fixes`.
- **Decision**: Selected `stories/sya-harvester/incomplete/audit-fixes/007-route-token-and-params-consistency.md`. `Current Sprint: 1` maps to `audit-fixes` in `sprints.json`. Its only dependency, sya-harvester:006, is in `auto-complete/` (terminal), so it is resolved. `story-dependencies.md` already records that.
- **Rationale**: Exact match. No other story in the sprint is incomplete.
- **Alternatives**: None needed.

### Decision 2: Base commit / execution type
- **Situation**: Worktree `worktrees/sya-harvester/audit-fixes` already existed on `sprint/audit-fixes` and was clean at `02130d0`, story 006's GREEN. There are no failure reports.
- **Decision**: `existing_worktree`, Base Commit `02130d06a52efa5ce4657465a8cdc39871eac4b7` (the worktree HEAD).
- **Rationale**: base-commit-rules.md says existing worktree means current HEAD.
- **Alternatives**: None.

### Decision 3: Real Router NG behaviour (fork evidence, block 26_261_000, RPC https://eth.drpc.org)
- **Situation**: The story asked for the real router's behaviour to be proven, not assumed.
- **Decision / finding**: Both expectations held. (a) Zero intermediate path `[USDe, USDe/crvUSD, 0, crvUSD/USDC, USDC, 0…]` makes the real Router NG **revert with empty revert data**. (b) The USDe route with hop 1 swap_type 0 makes the real Router NG **revert `Error("Bad swap type")`**. The fork tests pin these exact payloads. The mock reverts `ZeroIntermediateToken()` and `BadSwapType(1)` respectively. The mock does not copy the real router's payloads, because its errors are diagnostic, and the "mock agrees" assertion checks that the mock reverts, which matches the real router.
- **Rationale**: The story says "the mock must match the real router". Both revert, so they agree. Distinct mock errors keep unit-test failures readable.
- **Alternatives**: Make the mock revert with empty data and `Error("Bad swap type")` byte-for-byte. That is a one-line change per revert in `test/mocks/MockCurveRouter.sol` if wanted.

### Decision 4: Fixture strategy for the registry suite
- **Situation**: The old `_params()` (rows 0 and 1) and `_pools()` (`pools[0]`) are inconsistent with k=1 and k=0 accept tests.
- **Decision**: Added overloads `_params(uint256 k)` / `_pools(uint256 k)`. Only the accept fixtures the story lists were switched: storesFullFiveHopRoute → `(5)`, rejectsFiveHopEndingAtNonRewardToken → `(5)`, acceptsNoHopRouteForRewardToken → `(0)`, storesSingleHop / emitsRouteSet / clearRoute → `(1)`. Every revert test that expects Gap/End/Start still passes the old two-row `_params()`, so those tests now also show that Gap/End are reported ahead of the new param checks. No assertion was changed.
- **Rationale**: This is the smallest diff, and it keeps the check-order coverage implicit in the existing tests.
- **Alternatives**: Convert every call to an explicit k.

### Decision 5: Check-order interpretation for params vs pools
- **Situation**: The spec's reference loop checks per hop: for h ≥ k, row h first, then pools[h], then h+1.
- **Decision**: Implemented that loop exactly. Two tests pin it. A stray row and a stray pool at the same hop raise `InvalidRouteSwapParams`. A stray pool at hop 1 plus a stray row at hop 2 raise `InvalidRoutePools(1)`.
- **Rationale**: "the error raised for each case exactly as specified".
- **Alternatives**: Check all rows before all pools. That would change only the second test.

### Decision 6: Test results
- `forge build` clean. The only lint warnings (`unsafe-typecast`, fork file L346/354/393) are on pre-existing lines.
- `forge test` (no RPC): 92 passed, 0 failed, 1 suite skipped (fork). 22 new unit tests: 18 in the registry suite (34 → 52) and 4 in the mock suite (7 → 11).
- Fork suite with `MAINNET_RPC_URL=https://eth.drpc.org`: **19/19 passed**, including the 4 new tests (zero intermediate real-router revert + mock, swap_type 0 real-router revert + mock, setRoute `InvalidRouteToken(2)`, shipped routes re-configure + harvest leaves harvester empty).
- `test/script/harvest_anvil.sh` (Anvil fork): **32/32 passed**. `bash -n script/harvest.sh` OK.
- `forge fmt --check`: the new code is clean. The registry file still has 2 formatting diffs on pre-existing lines (L19 event, `test_noHarvestFunction`). These were left untouched because they are out of scope.
- Commits on `sprint/audit-fixes`: `8a8064a` RED, `6b862aa` GREEN.

---
## Review Results
**Review Date**: 2026-10-25T12:25:58Z
**Review Command**: review-work sya-harvester:007 --inline-delegation
**Review Status**: PASSED

### Executive Summary
Story 007 is implemented as specified. `setRoute` now rejects zero intermediate tokens (`InvalidRouteToken`), executed swapParams rows with swap_type 0 and non-zero unexecuted rows (`InvalidRouteSwapParams`), and non-zero unexecuted pools (`InvalidRoutePools`). The checks run in the specified order: ZeroAddress, Start, Gap, Token, End, then per hop params before pools. `MockCurveRouter` reverts `ZeroIntermediateToken` and `BadSwapType(hop)` and ignores rows and pools beyond the executed prefix. Fork tests pin the real Router NG's behaviour: empty revert data for a zero intermediate, and `Error("Bad swap type")` for swap_type 0. The reviewer re-ran everything independently. `forge build` is clean. `forge test` gives 92 passed, 0 failed, 1 suite skipped (fork). The fork suite with `MAINNET_RPC_URL=https://eth.drpc.org` gives 19/19 passed, including the 4 new tests. `bash -n script/harvest.sh` is OK. The worktree is clean at `6b862aa`.

### Validation Results
1. Base Commit Validation: ✓ Base `02130d0` is story 006's GREEN commit and the parent of 007's RED commit `8a8064a`. Story 007 is the only story in review on `sprint/audit-fixes`. The worktree's branch point from source master, `62c19c8` (story-005 GREEN), is an ancestor of the base commit.
2. File Change Review: ✓ 7 files changed. All of them appear in the story's File Locations table. Nothing was flagged, so nothing was appended to FlaggedFiles.json and flag-investigator had no flags to investigate (PASSED).
3. Claim Validation: ✓ All 10 checked items were verified against the diff and the test runs. The RED/GREEN commits exist with `[story-007]` messages. The registry suite went from 34 to 52 tests and the mock suite from 7 to 11. The fixtures that changed are exactly the ones listed, and no assertion was weakened (only the fixture inputs changed to `_params(k)`/`_pools(k)`). The interface NatSpec, the setRoute NatSpec and the three `KNOWN_ERRORS` entries are present. Fork tests (a) through (d) are present and passing.
4. Purpose Alignment: ✓ The diff closes both audit holes (M-01 residual and mitigation 2) with the specified accept/reject set and error per case. The real-router guess from story 006 is replaced by fork evidence. Scope is confined to the listed files. via_ir is untouched and there are no deployment changes.

### Issues Found
None blocking. Non-blocking observations, for triage:
1. The mock's revert payloads (`ZeroIntermediateToken()`, `BadSwapType(uint256)`) differ from the real router's (empty data, `Error("Bad swap type")`). This is intentional and disclosed in the executor's Autonomous Decision 3. The "mock agrees" assertions check revert vs. no-revert, not byte equality.
2. `forge fmt --check` reports 2 diffs in `test/SYAHarvester.registry.t.sol`: the L19 `EthPoolSet` event and `test_noHarvestFunction`. Both are on pre-existing lines this story did not touch, and both were disclosed. The new code is fmt-clean. There are also pre-existing `unsafe-typecast` lint notes in the fork file.
3. Unrelated to this story: `FlaggedFiles.json` in product-owner does not parse as JSON ("Extra data" at line 3402). That is pre-existing state. This review had no flags to append, so it did not touch the file.

### Files Changed Since Base Commit
- script/harvest.sh
- src/SYAHarvester.sol
- src/interfaces/ICurveRouterNG.sol
- test/SYAHarvester.registry.t.sol
- test/fork/SYAHarvester.fork.t.sol
- test/mocks/MockCurveRouter.sol
- test/mocks/MockCurveRouter.t.sol

### Autonomous Decisions
- **Base-commit-validator definition**: The agent file is `.claude/agents/base-commit-validator-template.md`; there is no `base-commit-validator.md`. Decision: followed the template's review-work rules. Rationale: it is the only definition of that agent. Alternative: skip the step, which is not permitted.
- **Fork suite run**: `MAINNET_RPC_URL=https://eth.drpc.org` was reachable. Decision: re-ran the fork suite rather than relying on the executor's report. Rationale: independent evidence for checklist item (a)-(d).
- **Malformed FlaggedFiles.json**: Decision: left the file untouched and recorded it as observation 3. Rationale: there were no flags to append, and repairing product-owner state is outside a report-only review.

### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: base-commit-validator, file-flagger, flag-investigator, change-validator, sanity-check
**Independence**: reduced — these verdicts were reached inline by the reviewing agent rather than by separate validator agents (the reviewer did not perform the work under review)
---

---
## Auto-Completed
**Date**: 2026-10-25T12:27:13Z
**Approved by**: story-batch workflow (machine approval — not human-reviewed)
**Review Status acted on**: PASSED
**Triage verdict**: non-blocking
**Fixed by the polish pass before completion**:
- none
**Non-blocking findings carried forward**:
- [low] MockCurveRouter reverts with diagnostic errors ZeroIntermediateToken() and BadSwapType(uint256), while the real Router NG reverts with empty data and Error("Bad swap type"). The 'mock agrees' fork assertions only compare revert vs. no-revert. This was intentional and disclosed in Autonomous Decision 3. Revert behaviour matches, so the story goal is met. Matching the payloads byte-for-byte would be a design choice and a code change to the mock.
- [nit] forge fmt --check reports 2 diffs in test/SYAHarvester.registry.t.sol (the L19 EthPoolSet event and test_noHarvestFunction). Both are on pre-existing lines this story did not touch, and the new code is fmt-clean. The pre-existing unsafe-typecast lint notes in the fork file are also out of scope.
- [low] product-owner FlaggedFiles.json does not parse as JSON ('Extra data' at line 3402). This is pre-existing orchestration state, unrelated to this story's code, and repairing it is outside this story's repo and scope.
**Base commit set to**: 6b862aa0af3d3182d2fd311c4402a4056b69ef42
**Base commit derivation**: no later story exists in sprint `audit-fixes` (006 is auto-completed, 007 is the only remaining story), so the worktree HEAD of `sprint/audit-fixes` was used. Validated: it descends from the story's execution base `02130d0` and from the branch point `62c19c8` (merge-base with master), the range `02130d0..6b862aa` contains only `[story-007]` commits (`8a8064a` RED, `6b862aa` GREEN), the worktree is clean, and no other stories are in review on this worktree.
**Reversal**: `git -C worktrees/sya-harvester/audit-fixes log` from this base commit; move the story file
back to `review/` and delete this section to undo the completion.

### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: story-manager (location/validation, next-story lookup, stamp, move), repo-manager (worktree discovery, checkpoint commit), base-commit-validator, workflow-validator
**Independence**: reduced — these verdicts were reached by the agent that also performed the transition
