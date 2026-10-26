# Router NG contiguity rule in setRoute and a faithful MockCurveRouter (audit 01, M-01)

Current Sprint: 1
Base Commit: 02130d06a52efa5ce4657465a8cdc39871eac4b7
Execution Type: new_worktree
Base Commit Updated: 2026-10-25T11:11:27Z

## Story Overview

Audit 01 finding M-01 (`scratchpad/planning-docs/phoenix/sya-harvester/audits/01/M-01-submission.md`): `SYAHarvester.setRoute` validates that the *last non-zero* entry of the 11-slot `path` is `sya.rewardToken()`, but Curve Router NG executes hops only while `path[2k+1] != 0` and delivers `path[2k]` at the first empty pool slot. A gapped route such as `[USDe, poolUSDe/crvUSD, crvUSD, 0, …, 0, USDC]` passes validation, the router delivers crvUSD, and if other legs cover the flash borrow the harvest succeeds while the intermediate token is permanently stranded (no sweep). The unit suite missed it because `MockCurveRouter` implements the same last-non-zero rule.

This story implements the audit's **recommended mitigation 1** (validate the route the way Router NG executes it) and makes `MockCurveRouter` model Router NG faithfully, plus a real-router regression on the mainnet fork.

Goal: `setRoute` rejects every route whose Router NG–executed output is not the reward token, and rejects any non-zero entry after the executed prefix; the test double behaves like the real router so this class of bug cannot hide in unit tests again.

## Background

- Repo: `/home/justin/code/reflax-mint/sya-harvester` (Foundry, solc 0.8.26, cancun, optimizer on, **via_ir intentionally OFF** — do not enable it). Root `CLAUDE.md` mandates TDD (RED → GREEN → refactor) and states "The contract holds no balances between calls".
- HEAD `62c19c8` on master is the commit the audit ran against; `sprint/harvester-v1` is fully merged.
- Router NG v1.1 (`0x16C6521Dff6baB339122a0FE25a9116693265353`, Vyper 0.3.10) loop: for hop i, `output_token = _route[(i+1)*2]`; swap; `if i == 4 or _route[i*2+3] == empty(address): break`; then transfers `output_token` to receiver. So with first empty pool slot at `path[2k+1]` (k in 0..4), delivered token = `path[2k]`; with no empty pool slot in 1,3,5,7,9 (k=5), delivered = `path[10]`.
- Using the real Router NG in unit tests is **not feasible**: no Vyper source/artifact is vendored, no vyper compiler installed, and the router calls real Curve pools (would need ABI-faithful mock pools per swap_type). The real router is exercised only in the fork suite (gated on `MAINNET_RPC_URL`; skipped otherwise; no CI exists). Hence: faithful Solidity mock for unit tests + gated fork regression with the real router.

## File Locations

| File | Change |
|---|---|
| `src/SYAHarvester.sol` | Replace validator loop in `setRoute` (L124-149, loop L133-140); add `error InvalidRouteGap(uint256 index);` beside `InvalidRouteEnd` (errors L77-96, InvalidRouteEnd at L82); update NatSpec of `setRoute` (L115-123) and `InvalidRouteEnd` |
| `src/interfaces/ICurveRouterNG.sol` | NatSpec (L10-14): state that the router stops at the first empty pool slot and delivers `path[2k]` |
| `test/mocks/MockCurveRouter.sol` | Rewrite output-token resolution to Router NG semantics (currently last-non-zero at L34-37) |
| `test/SYAHarvester.registry.t.sol` | New validator tests (gap, trailing entry, 5-hop, k=0 cases) |
| `test/mocks/MockCurveRouter.t.sol` (new) or similar | Unit tests proving the mock matches Router NG delivery semantics |
| `test/fork/SYAHarvester.fork.t.sol` (or a new `test/fork/RouteGap.fork.t.sol` inheriting it) | Gated real-router regression adapted from the audit PoC |
| `test/utils/HarvesterFixture.sol` | Only if the mock API changes (keep `setRate`/`calls` so it shouldn't) |
| `script/harvest.sh` | Add `"InvalidRouteGap(uint256)"` to the `KNOWN_ERRORS` array (L151-163) |

## Technical Details

### Current validator (src/SYAHarvester.sol L130-140)

```solidity
if (token == address(0)) revert ZeroAddress();
if (path[0] != token) revert InvalidRouteStart(token, path[0]);
address last;
for (uint256 i = 0; i < 11; i++) {
    if (path[i] != address(0)) { last = path[i]; }
}
address rewardToken = sya.rewardToken();
if (last != rewardToken) revert InvalidRouteEnd(rewardToken, last);
```

Storage: `struct CurveRoute { address[11] path; uint256[5][5] swapParams; address[5] pools; bool configured; }`, `mapping(address => CurveRoute) private routes;`. `_sellYield` (L306-321) calls `router.exchange(r.path, r.swapParams, balance, 0, r.pools, address(this))` with `min_dy = 0` and never checks which token arrived.

### Required validator (mitigation 1, verbatim semantics)

```solidity
error InvalidRouteGap(uint256 index); // declared beside InvalidRouteEnd

address rewardToken = sya.rewardToken();
// Router NG executes hop k while path[2k+1] != 0 and delivers path[2k] at the first empty pool slot.
uint256 k;
while (k < 5 && path[2 * k + 1] != address(0)) k++;
address delivered = path[2 * k];
if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);
// Nothing may follow the executed prefix: a trailing entry is never executed.
for (uint256 i = 2 * k + 1; i < 11; i++) {
    if (path[i] != address(0)) revert InvalidRouteGap(i);
}
```

Keep the existing `ZeroAddress` and `InvalidRouteStart` checks first. Keep `InvalidRouteEnd`'s signature `(address expected, address last)` (renaming the second param to `delivered` in NatSpec/declaration is fine; the ABI selector must stay `InvalidRouteEnd(address,address)` so `harvest.sh` decoding keeps working). Note when k=5 the trailing loop runs zero iterations.

### Router NG interface

`function exchange(address[11] calldata _route, uint256[5][5] calldata _swap_params, uint256 _amount, uint256 _expected, address[5] calldata _pools, address _receiver) external payable returns (uint256);`

### Current MockCurveRouter (test/mocks/MockCurveRouter.sol, 44 lines)

- `rate[tokenIn]` (keyed by `_route[0]` only), `out = _amount * rate[tokenIn] / 1e18`; `calls[tokenIn]` counter; pulls input via `safeTransferFrom`; reverts `Slippage(out, expected)` if `out < _expected`; pays from a pre-funded balance; ignores swapParams/pools; picks tokenOut = last non-zero entry (the bug).
- Used by `test/utils/HarvesterFixture.sol` L65-68, L81, L96-106 (`setRate(usde,1e6)`, `setRate(dola,1e6)`, `usdc.mint(router,1e24)`), and `router.calls(token)` is asserted in `test/SYAHarvester.harvest.t.sol` L31, 77, 78, 98, 111; `setRate(usde, 0.5e6)` in `test_harvest_unprofitableClaim_reverts` (L139).

### Required MockCurveRouter behaviour

- Resolve output exactly like Router NG: iterate hops i = 0..4; output token for hop i is `_route[2i+2]`; stop after hop i if `i == 4 || _route[2i+3] == address(0)`. Delivered token = that last output token.
- Revert (loudly, custom error) if `_route[1] == address(0)` (no hop at all) or if the resolved output token is `address(0)` — the real router would fail in these cases.
- Keep the public API `setRate(address tokenIn, uint256 rate)`, `rate(address)`, `calls(address)`, `Slippage` behaviour, input pull, and pre-funded payout, so existing fixture/tests compile unchanged. Single-rate-per-tokenIn pricing is fine; per-hop rates are not required.
- Pay out the **resolved** token (so a gapped route given directly to the mock delivers the intermediate token, as on mainnet). The mock must hold a balance of that token; tests that exercise the gap set that up.
- Reference implementations to borrow from: `/home/justin/code/audits/sya-harvester/work/test/audit/invariant/InvDoubles.sol` L30-87 (`RouterNGModel`, has `resolveOutput(path)`), and `/home/justin/code/reflax-mint/vault/test/mocks/MockCurveRouterNGRouted.sol` (breaks at `_route[2k+1]==0`). Read them; do not import from outside the repo.

### Fork setup (for the real-router regression)

- `test/fork/SYAHarvester.fork.t.sol`: `setUp` (L80-107) uses `vm.envOr("MAINNET_RPC_URL","")` → `vm.skip(true)` if empty; else `vm.createSelectFork(vm.rpcUrl("mainnet"), A.PINNED_BLOCK)` (26_261_000); deploys the harvester with `ICurveRouterNG(A.CURVE_ROUTER_NG)` and runs `MainnetRoutes.configure(harvester)`. `_assertHarvesterEmpty` (L131-144) already checks crvUSD and FRAX.
- `test/fork/MainnetRoutes.sol` `usdeRoute()` = `[USDE, 0xF55B0f6F…(USDe/crvUSD), CRVUSD, 0x4DEcE678…(crvUSD/USDC), USDC]`.
- Audit PoC to adapt: `/home/justin/code/audits/sya-harvester/reports/01/pocs/M-01-poc.t.sol` (`M01PoCTest is SYAHarvesterForkTest`, `_gapPath()` = `[USDE, POOL_USDE_CRVUSD, CRVUSD, 0…0, USDC]`; tests `test_M01_validator_acceptsGap_rejectsHonestWrongEnd` L158, `test_M01_control_contiguousRoute_leavesNoCrvUsd` L149, `test_M01_gapRoute_strandsCrvUsd_andUnderpaysCaller` L85).

## Implementation Notes

- TDD: write the failing registry tests (gap accepted today) and failing mock-fidelity tests first; commit RED; then fix.
- No existing unit, fork or script test uses a gapped or trailing-padded path (all are contiguous with zero tails), so the new rule should not break existing tests. If one does break, it is evidence of a gapped route — investigate rather than loosening the rule.
- Registry helper `_params` fills swapParams rows 0 and 1 even for single-hop routes; that remains legal (swapParams/pools consistency is mitigation 2, out of scope).
- `token == rewardToken` with `path[1] == 0` (k=0, delivered = path[0] = reward) is accepted by mitigation 1. This is harmless because `_sellYield` skips the reward token. Keep that behaviour and add a test that documents it.
- A `path[1] == 0` route for a non-reward token is rejected with `InvalidRouteEnd(reward, token)`.
- Full 5-hop route (all pool slots 1,3,5,7,9 non-zero, `path[10] == reward`) must be accepted; a 5-hop route ending at a non-reward token is rejected with `InvalidRouteEnd`.
- The audit's Halmos model `_contiguous` uses a slightly different formulation that diverges when `path[1]==0`; do not copy it as the spec — the code block above is the spec. Running Halmos is optional, not required.
- Fork tests require an archive RPC in `MAINNET_RPC_URL`. If it is not set in the execution environment, the fork tests will skip; record that in Autonomous Decisions and ensure they at least compile (`forge build`), and that `forge test` overall passes.
- Commit messages: `[story-006] <message>`. Stage files by explicit path.

## Out of Scope (follow-ups)

- Mitigation 2 (swapParams/pools consistency check), mitigation 3 (amending story-001's rule text, and the same last-non-zero rule in `/home/justin/code/reflax-mint/vault/src/AMMAdapters/CurveAMMAdapter.sol` L73-80), mitigation 5 (owner-only sweep/rescue, audit Q-03). Do not implement them here.
- Any deployment / phStaging2 change.

## Checklist

- [x] RED: add registry tests in `test/SYAHarvester.registry.t.sol` that currently fail: (a) gapped route `[usde, pool0, other, 0, …, 0, usdc]` reverts `InvalidRouteGap(10)`; (b) contiguous route to the reward token followed by a stray non-zero entry (e.g. `[usde, pool0, usdc, 0, X, 0…]`) reverts `InvalidRouteGap(4)`; (c) gap in a multi-hop route, e.g. `[usde, pool0, other, pool1, other2, 0, usdc, 0…]`, reverts `InvalidRouteGap(6)`
- [x] Add registry tests for: full 5-hop route to the reward token accepted and stored; 5-hop ending at a non-reward token reverts `InvalidRouteEnd`; `path[1] == 0` for a non-reward token reverts `InvalidRouteEnd(reward, token)`; `token == reward` with `path[1] == 0` accepted (documented harmless case); existing reject/accept tests still pass unchanged
- [x] RED: add mock-fidelity unit tests (e.g. new `test/mocks/MockCurveRouter.t.sol`) showing that `MockCurveRouter.exchange` with a gapped path delivers `path[2k]` (the intermediate token), not the trailing entry; a 5-hop path delivers `path[10]`; a path with `path[1] == 0` reverts
- [x] Commit RED tests as `[story-006] RED: ...`
- [x] Add `error InvalidRouteGap(uint256 index);` beside `InvalidRouteEnd` in `src/SYAHarvester.sol`, with NatSpec
- [x] Replace the `setRoute` validator loop with the mitigation-1 contiguity rule (exact semantics in Technical Details), keeping `ZeroAddress`/`InvalidRouteStart` checks first and the `InvalidRouteEnd(address,address)` selector unchanged
- [x] Update `setRoute` NatSpec and `InvalidRouteEnd` NatSpec to describe the Router NG rule (first empty pool slot delivers `path[2k]`; no non-zero entries after the executed prefix)
- [x] Update `src/interfaces/ICurveRouterNG.sol` NatSpec to state that Router NG stops at the first empty pool slot and delivers `path[2k]`
- [x] Rewrite `test/mocks/MockCurveRouter.sol` output resolution to Router NG semantics (stop after hop i when `i == 4 || _route[2i+3] == 0`; revert if `_route[1] == 0` or resolved token is zero), keeping `setRate`/`rate`/`calls`/`Slippage`/input-pull API intact; update its doc comment
- [x] Add a harvest-level unit test with the faithful mock that demonstrates the M-01 failure mode is no longer reachable: the gapped route cannot be stored (`setRoute` reverts), and with the shipped contiguous fixture route the harvester ends with zero balance of every touched token
- [x] Add a `MAINNET_RPC_URL`-gated fork regression using the real Router NG (adapted from the audit PoC, inheriting `SYAHarvesterForkTest`): the gap path is rejected by `setRoute` with `InvalidRouteGap(10)`; the contiguous `MainnetRoutes` route still harvests and leaves the harvester empty (`_assertHarvesterEmpty`); and a direct `eth_call`/call of Router NG `exchange` (or `get_dy`-style check) with the gap path confirms the real router delivers crvUSD, proving the mock models it correctly
- [x] Add `"InvalidRouteGap(uint256)"` to `KNOWN_ERRORS` in `script/harvest.sh` (L151-163)
- [x] `forge build` clean; `forge test` passes (all unit suites green; fork suites pass if `MAINNET_RPC_URL` is set, otherwise skip — record which in Autonomous Decisions)
- [x] If `MAINNET_RPC_URL` is available, run the fork suite and record the result
- [x] All work committed to `sprint/audit-fixes` with `[story-006]` messages; worktree clean

## Concerns

- Real router vs mock: the real Router NG cannot run in unit tests (Vyper-only, no compiler or artifact vendored, and it calls live Curve pools). Decision: faithful Solidity mock for unit tests, plus a `MAINNET_RPC_URL`-gated fork regression against the real router for ground truth. Fork tests are skipped by default and there is no CI.
- Scope: implements mitigation 1 only, plus mock fidelity (part of mitigation 4) as the human asked. Mitigations 2, 3 and 5, and the matching bug in vault's `CurveAMMAdapter`, are left for follow-up stories.
- `token == rewardToken` with an empty route is still accepted under mitigation 1. It is harmless because `_sellYield` skips the reward token, so the rule is kept as written rather than tightened.
- `InvalidRouteEnd` keeps its selector so that `harvest.sh` revert decoding keeps working.
- story-001's spec still prescribes the old last-non-zero rule (F-02). That story is terminal, so its text is left alone; this story supersedes the rule.
- The `audits` workspace pins sya-harvester as `lib/sya-harvester`. Moving that pin forward so M-01 can be re-checked is the human's call.

---
## Autonomous Decisions
**Date**: 2026-10-25T11:08:07Z
**Command**: execute-story 006 in sya-harvester, sprint audit-fixes --inline-delegation

### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit; passed by the story-batch driver)
**Steps run inline**: story-manager (discovery, base-commit write, failure-report check, checklist validation, review transition), sprint-manager (sprint + dependency validation), repo-manager (worktree creation, sprint commits, product-owner checkpoint), base-commit-validator (execute-story / new_worktree), workflow-validator (pre-execution and post-transition), implementation subagent (story work, bound by the subagent-constraints block)
**Independence**: reduced — these verdicts were reached by the agent that also performed/observed the work

### Decision 1: Story selection and dependency status
- **Situation**: `sprint audit-fixes` (index 1 in sprints.json) has exactly one incomplete story, 006. story-dependencies.md lists it as blocked by none (001-005 are terminal in auto-complete/).
- **Decision**: Executed 006. No failure reports or review results exist, so execution type is `new_worktree`, not `revision`.
- **Rationale**: Single match in the named sprint; no open blockers.
- **Alternatives**: None needed.

### Decision 2: Worktree created from master @ 62c19c8; nested solmate submodule initialised
- **Situation**: `worktrees/sya-harvester/audit-fixes/` did not exist. The source repo (`~/code/reflax-mint/sya-harvester`) was clean on master @ `62c19c86`, with no `.env*`, `.vscode`, `*.local`, `*.secret` or `*.key` files to copy and no `main/` inspection worktree. A plain `git submodule update --init` left `lib/v4-core/lib/solmate` empty, and `HarvesterFixture` imports solmate's `MockERC20` through that path.
- **Decision**: Ran `git worktree add -b sprint/audit-fixes ... master` (no checkpoint commit was needed because the tree was clean) and initialised the top-level submodules. In `lib/v4-core` I initialised only `lib/solmate`, not the whole v4-core tree recursively. Base commit is `62c19c86be1594dcf82e8af794fcd6c28f9a8fc0`, the latest commit on the source branch, per the new_worktree rule. The baseline was 48 passed and 1 skipped.
- **Rationale**: The story names master @ 62c19c8 as the base. solmate is the only nested dependency the build needs.
- **Alternatives**: `git submodule update --init --recursive`, which also works but clones far more.

### Decision 3: Error precedence: the trailing-gap check runs before the delivered-token check
- **Situation**: The spec block in Technical Details checks `InvalidRouteEnd` (delivered token) first and the trailing loop second. The checklist instead expects a gap error in three places: (a) `[usde,pool0,other,0..0,usdc]` should revert `InvalidRouteGap(10)`, (c) `[usde,pool0,other,pool1,other2,0,usdc]` should revert `InvalidRouteGap(6)`, and the fork regression's audit gap path should revert `InvalidRouteGap(10)`. Under the spec order, all three of those paths would revert `InvalidRouteEnd` instead, because their executed prefix delivers an intermediate token.
- **Decision**: Kept the spec's semantics (the same k computation, the same `delivered = path[2k]`, the same trailing loop) but ran the trailing-gap loop before the delivered-token check. The set of routes accepted and rejected is identical under either order. Only the error reported differs, and only for routes that violate both rules.
- **Rationale**: This satisfies every checklist item literally. For a gapped route, the gap is the root cause and the more useful error for the owner. `InvalidRouteEnd(address,address)` keeps its selector (only the second param was renamed `last` → `delivered`), so `harvest.sh` decoding is unchanged. Every other required case behaves as specified: a 5-hop route to a non-reward token gives `InvalidRouteEnd`, `path[1]==0` for a non-reward token gives `InvalidRouteEnd(reward, token)`, a reward token with `path[1]==0` is accepted, and a full 5-hop route is accepted.
- **Alternatives**: Use the spec order exactly and change the three checklist expectations to `InvalidRouteEnd`. That means swapping the two blocks in `setRoute` and updating 4 registry tests, 1 routeGap test and 1 fork test.

### Decision 4: Test placement and error matching
- **Situation**: The story allowed either a new fork file inheriting `SYAHarvesterForkTest` or additions to the existing fork file. RED tests also have to compile before `InvalidRouteGap` and the mock's new errors exist.
- **Decision**: Added the three M-01 fork tests directly to `test/fork/SYAHarvester.fork.t.sol`, because an inheriting file would re-run all 12 parent fork tests. Added `test/mocks/MockCurveRouter.t.sol` (mock fidelity) and `test/SYAHarvester.routeGap.t.sol` (harvest-level). New errors are matched with `abi.encodeWithSignature("InvalidRouteGap(uint256)", i)`, which also pins the selector. The mock gained `NoHop()` and `ZeroOutputToken()` errors and a public `resolveOutput`; the existing `setRate`/`rate`/`calls`/`Slippage` API is unchanged.
- **Rationale**: No duplicated fork runs, and the RED commit compiles.
- **Alternatives**: A separate `test/fork/RouteGap.fork.t.sol` (`contract X is SYAHarvesterForkTest`).

### Decision 5: MAINNET_RPC_URL unset, so fork suites were run against a public archive RPC
- **Situation**: `MAINNET_RPC_URL` was not set in the environment.
- **Decision**: Following story 004's precedent, I ran the fork suite with the public keyless archive endpoint `https://eth.drpc.org`. No credential-bearing `.envrc` was read.
- **Results**: `forge build` is clean. `forge test` with no RPC gave 70 passed, 0 failed, 1 skipped (fork setUp). `MAINNET_RPC_URL=https://eth.drpc.org forge test --match-path test/fork/SYAHarvester.fork.t.sol` gave 15/15 passed at block 26261000. That includes `test_fork_M01_realRouterDeliversIntermediate_mockAgrees`: the real Router NG, given the gap path, delivered crvUSD and no USDC, and `MockCurveRouter` resolved the same path to crvUSD. `test/script/harvest_anvil.sh` gave 32 passed, 0 failed.
- **Alternatives**: Re-run with the human's own RPC: `MAINNET_RPC_URL=<rpc> forge test --match-path test/fork/SYAHarvester.fork.t.sol -vv`.

### Decision 6: RED-commit test fix carried in the GREEN commit
- **Situation**: After GREEN, `test_routeGap_mockDeliversIntermediateForGappedPath` failed. The failure was in the test, not the code: the fixture mints 1e30 USDC to the test contract for V4 liquidity, so asserting "USDC balance == 0" on `address(this)` was wrong.
- **Decision**: Changed only the receiver to a fresh `makeAddr("receiver")`. The assertions are unchanged. The fix is part of the GREEN commit `02130d0`.
- **Rationale**: The fix tightens the test's isolation and does not loosen anything it checks.
- **Alternatives**: None.

### Execution summary
- Worktree: `worktrees/sya-harvester/audit-fixes`, branch `sprint/audit-fixes`, base `62c19c8`
- Commits: `b84e907` RED, `02130d0` GREEN
- Files: `src/SYAHarvester.sol`, `src/interfaces/ICurveRouterNG.sol`, `test/mocks/MockCurveRouter.sol`, `test/mocks/MockCurveRouter.t.sol` (new), `test/SYAHarvester.registry.t.sol` (+13 tests), `test/SYAHarvester.routeGap.t.sol` (new), `test/fork/SYAHarvester.fork.t.sol` (+3 tests), `script/harvest.sh`
- Out of scope, untouched: mitigations 2, 3 and 5, vault `CurveAMMAdapter`, phStaging2. `via_ir` stays OFF.
- Workflow-validator (inline): the story has one location only, sprint index 1 maps to `audit-fixes` and the worktree branch matches, the worktree is clean after commit, and all 15 checkboxes are checked.

---
## Review Results
**Review Date**: 2026-10-25T11:09:50Z
**Review Command**: review-work sya-harvester:006 --inline-delegation
**Review Status**: PASSED

### Executive Summary
`setRoute` now validates routes the way Router NG executes them. It walks to the first empty pool slot, rejects any later non-zero entry with `InvalidRouteGap(index)`, and checks that the delivered `path[2k]` is the reward token with the selector `InvalidRouteEnd(address,address)` unchanged. `MockCurveRouter` now resolves its output with Router NG semantics. All 15 checklist claims are backed by code and by tests. I re-ran the suite on my own: `forge build` is clean, and `forge test` gave 70 passed, 0 failed, 1 skipped (the fork setUp, with no RPC). The three M-01 fork tests passed 3/3 against `https://eth.drpc.org` at block 26261000, which includes the real Router NG delivering crvUSD for the gap path, matching the mock. The worktree is clean, `via_ir` stays OFF, and nothing out of scope was touched.

### Validation Results
1. Base Commit Validation: ✓ `62c19c8` exists, equals the merge-base of `master` and `sprint/audit-fixes` (the new_worktree rule), is an ancestor of HEAD, and this is the only story in review on the worktree.
2. File Change Review: ✓ All 8 changed files are listed in the story's File Locations table. No flags were raised and nothing was appended to FlaggedFiles.json. Flag investigation had nothing to examine and returned PASSED.
3. Claim Validation: ✓ All 15 checked items are TRUE. RED commit `b84e907` contains only tests, and under the old last-non-zero rule the gap tests would not revert. GREEN commit `02130d0` contains the code. The registry tests cover (a) `InvalidRouteGap(10)`, (b) `InvalidRouteGap(4)` and (c) `InvalidRouteGap(6)`, plus the 5-hop accept and reject cases, the no-hop reject, and the reward-token no-hop accept. There are 7 mock-fidelity tests. The harvest-level test and 3 gated fork tests are present. `harvest.sh` `KNOWN_ERRORS` includes `InvalidRouteGap(uint256)`.
4. Purpose Alignment: ✓ The M-01 failure mode can no longer be reached through `setRoute`, and the test double no longer hides it. The scope is limited to mitigation 1 plus mock fidelity.

### Issues Found
None blocking. Two non-blocking observations:
- **Error precedence differs from the spec's code block** (disclosed in execution Decision 3). The gap loop runs before the delivered-token check. The story itself was contradictory here: the spec block checks End first, but the checklist and the fork test expect `InvalidRouteGap` for gapped paths. The set of routes accepted and rejected is identical under either order. Only the error reported for a route that breaks both rules differs.
- **A zero intermediate token inside the executed prefix is not caught.** Example: `[usde, pool0, 0, pool1, usdc, 0…]`. Both `setRoute` and `MockCurveRouter.resolveOutput` accept it, and the mock delivers `usdc`. The real Router NG would most likely revert on the zero-address hop, which fails loudly and strands nothing. The story only requires the mock to revert on `_route[1]==0` or a zero *resolved* token, so this is not a claim failure. It is a small fidelity gap that could join the out-of-scope mitigation-2 follow-up (swapParams/pools consistency).

### Files Changed Since Base Commit
- script/harvest.sh
- src/SYAHarvester.sol
- src/interfaces/ICurveRouterNG.sol
- test/SYAHarvester.registry.t.sol
- test/SYAHarvester.routeGap.t.sol (new)
- test/fork/SYAHarvester.fork.t.sol
- test/mocks/MockCurveRouter.sol
- test/mocks/MockCurveRouter.t.sol (new)

### Autonomous Decisions
- **Fork verification RPC**: `MAINNET_RPC_URL` was unset. I re-ran only the 3 new M-01 fork tests against the public keyless `https://eth.drpc.org`, the same endpoint the executor used. All 3 passed. I did not re-run the other 12 fork tests, which this story did not change. The alternative was to skip all fork re-verification and rely on the executor's 15/15.
- **RED failure not executed**: I did not check out `b84e907` to run the RED suite, because that would change the worktree's state. Instead I confirmed the RED property by reading the code: under the old rule, `last == usdc` for each gap path, so `setRoute` would not revert and the `expectRevert` tests would fail.
- **base-commit-validator definition**: no `.claude/agents/base-commit-validator.md` exists. I followed `.claude/agents/base-commit-validator-template.md`, which carries `name: base-commit-validator`.

### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: base-commit-validator, file-flagger, flag-investigator, change-validator, sanity-check
**Independence**: reduced. These verdicts were reached by a single review agent standing in for each validator. That agent did not perform or observe the execution.
---

---
## Auto-Completed
**Date**: 2026-10-25T11:11:27Z
**Approved by**: story-batch workflow (machine approval — not human-reviewed)
**Review Status acted on**: PASSED
**Triage verdict**: non-blocking
**Fixed by the polish pass before completion**:
- none
**Non-blocking findings carried forward**:
- [low] setRoute error order differs from the spec code block: the trailing-gap check (InvalidRouteGap) runs before the delivered-token check (InvalidRouteEnd). Disclosed as Autonomous Decision 3. It resolves a spec-block vs checklist/fork-test contradiction, accepts and rejects the same routes under either order, and leaves the InvalidRouteEnd(address,address) selector unchanged.
- [low] A zero intermediate token inside the executed prefix (e.g. [usde, pool0, 0, pool1, usdc, 0...]) is accepted by both setRoute and MockCurveRouter.resolveOutput. The real Router NG would most likely revert loudly (strands nothing). It needs a design decision and tests, and belongs with the out-of-scope mitigation-2 follow-up.
**Base commit set to**: 02130d06a52efa5ce4657465a8cdc39871eac4b7
**Base commit derivation**: no later story exists in sprint `audit-fixes` (006 is its only story), so the worktree HEAD of `sprint/audit-fixes` was used. Validated: it descends from the story's execution base `62c19c8` (the merge-base with master), the range `62c19c8..02130d0` contains only `[story-006]` commits (`b84e907` RED, `02130d0` GREEN), the worktree is clean, and no other stories are in review on this worktree.
**Reversal**: `git -C worktrees/sya-harvester/audit-fixes log` from this base commit; move the story file
back to `review/` and delete this section to undo the completion.

### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: story-manager (location/validation, next-story lookup, stamp, move), repo-manager (worktree discovery, checkpoint commit), base-commit-validator, workflow-validator
**Independence**: reduced — these verdicts were reached by the agent that also performed the transition
