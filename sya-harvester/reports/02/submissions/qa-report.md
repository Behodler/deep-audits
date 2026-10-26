# QA Report for sya-harvester (run 02)

- **Run**: `sya-harvester-02` (regression audit, baseline `62c19c8` to HEAD)
- **Source**: https://github.com/Behodler/sya-harvester @ `6b862aa0af3d3182d2fd311c4402a4056b69ef42` (branch `master`)
- **Delta under review**: stories 006 and 007 (route-gap validation and swap-param/pool consistency in `setRoute`, the `MockCurveRouter` rewrite, and `KNOWN_ERRORS` additions in `script/harvest.sh`).
- **Automated baseline**: [4naly3er-report.md](./4naly3er-report.md). This is raw bot output: Part A covers the production scope, Part B the full first-party scope. It is untriaged, and its `L-n`/`M-n` labels are **not** this audit's labels.
- **Carried QA**: the 11 still-open Low/QA entries from run 01 are carried in [carryover/qa-report-01.md](./carryover/qa-report-01.md). Their bodies are not repeated here; see [Carried Low/QA findings](#carried-lowqa-findings-run-01) below for their run-02 status.
- **Not in this bundle**: M-01 (`sh1m1`, fix-pending, `fixed` proposed) is carried separately as [M-01-C1.md](./M-01-C1.md). The faithfulness tags F-06, F-07 and F-08 belong in this run's `spec-conformance.md`, not here.

## Summary (new findings, this run)

| Severity | Count |
|----------|-------|
| Low Risk | 0 |
| QA (non-critical) | 1 (L-05, reclassified from Low by owner triage 2026-10-26) |
| Centralization | 0 |
| **Total** | **1** |

| Label | Issue ID | Title (short) | Fingerprint |
|---|---|---|---|
| L-05 | sh2l5 | `setRoute` checks swap_type presence, not the v1.1 router's range 1..8 (owner footgun) | `3dc300229056ed319371e4702b2d46163fb43e63b06fbb2b3baea6dde7077579` |

**Centralization: none.** The owner surface is the same as in run 01: `setRoute`, `clearRoute` and `setEthPool`. The contract holds no user funds between calls. Under Law 3, owner-privilege vectors are not reported. L-05 is filed as a QA-level owner footgun, not as a centralization risk. The misconfiguration fails loudly and atomically, and a wallet or `eth_call` preview catches it before broadcast.

---

## QA Findings (reclassified from Low)

### [L-05] `setRoute` requires only `swap_type != 0` on executed hops; Router NG v1.1 dispatches only 1..8 and reverts `"Bad swap type"` otherwise, so a `swap_type >= 9` route is stored as valid and reverts every harvest that sells that token (owner footgun) <!-- id: sh2l5 -->

> **Severity:** QA (reclassified from Low by owner triage 2026-10-26 — fail-loud, atomic, caught by wallet/eth_call preview so no caller gas is lost)

**Location**: [SYAHarvester.sol#L176-L185](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/SYAHarvester.sol#L176-L185) (`setRoute`). The NatSpec is at [#L145-L147](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/SYAHarvester.sol#L145-L147) and the router call at [#L363](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/SYAHarvester.sol#L363). The test-side blind spot is in [MockCurveRouter.sol#L68](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/test/mocks/MockCurveRouter.sol#L68).

**Description**: story-007 added a check that `swapParams` and `pools` are consistent with the executed prefix of the path. For executed rows (`h < k`), the check tests only whether a swap type is present:

```solidity
// Swap params and pools must match the executed prefix: executed rows dispatch on a real swap_type,
// rows and pools the router never reads are zero.
for (uint256 h = 0; h < 5; h++) {
    if (h < k) {
        if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);   // presence, not range
    } else {
        for (uint256 f = 0; f < 5; f++) {
            if (swapParams[h][f] != 0) revert InvalidRouteSwapParams(h);
        }
        if (pools[h] != address(0)) revert InvalidRoutePools(h);
    }
}
```

The router is immutable. It is Curve Router NG **v1.1** (`0x16C6521Dff6baB339122a0FE25a9116693265353`, `version = "1.1.0"`), and its `exchange` dispatches on `params[2]` over 1..8 only. Any other value raises. The excerpt below is from the verified source captured at `reports/02/profiles/evidence/RouterNG-v1.1-0x16C6.vy`, L243-L327:

```vyper
# perform the swap according to the swap type
if params[2] == 1:
    ...
elif params[2] == 2:
    ...
elif params[2] == 8:
    ...
        raise "Swap type 8 is only for ETH <-> WETH, ETH -> stETH or ETH -> frxETH, ..."
else:
    raise "Bad swap type"
```

The same `else: raise "Bad swap type"` appears in `get_dy` (L491) and `get_dx` (L657). Router NG v1.2 adds swap type 9 (ERC4626). A route copied from v1.2 tooling or examples, or a single mis-typed field, is therefore accepted by `setRoute` but cannot be executed by the deployed router. The NatSpec states that executed rows "dispatch on a real swap_type", and story-007's Goal says the same. Both claim more than the check establishes, so the new validator gives false confidence. The test suite cannot catch the gap either, because `MockCurveRouter` rejects only `swap_type == 0` (`BadSwapType`) and executes any value of 9 or above.

Prior awareness: the repository already records this router behaviour. `test/fork/MainnetRoutes.sol` L31-L32 notes that this Router NG rejects an ERC4626 redeem ("Bad swap type" for swap_type 9), and story-007 Background L21 repeats it (citing that file at L52; the note is now at L32). The shipped `ICurveRouterNG` NatSpec (L21-L22) states that unknown swap types revert "Bad swap type", and `test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees` (`test/fork/SYAHarvester.fork.t.sol` L528-L545) pins that revert on the real router for swap_type 0. The router behaviour is therefore known to the team; the gap is that `setRoute` enforces only the lower bound of the dispatch range (`!= 0`) and not the upper bound (`<= 8`), while its NatSpec says executed rows dispatch on a real swap_type.

story-007 explicitly places `i`, `j`, `pool_type`, `n_coins` and executed-hop pool addresses out of scope for validation. The swap_type range is **not** on that list, so this finding does not contradict the story's stated scope.

**Impact**: Availability only. No value is at risk. Every `harvest()` that includes a strategy delivering the affected token reverts inside `router.exchange` with `Error("Bad swap type")`. This lasts until the owner re-registers the route or callers exempt that strategy. `harvest()` is public, so the outage reaches third-party callers, but they are not locked out: a caller can exclude the strategy via `exemptStrategies` and still harvest the rest. The loss is that strategy's discounted yield until the owner fixes the route (opportunity cost, no value at risk). The revert is atomic, so nothing is stranded. `harvest.sh` simulates with `eth_call` before submitting and passes `Error(string)` reasons through (`script/harvest.sh` L183), so the operator sees the reason and does not burn gas on-chain. The contract is not yet deployed.

**Evidence**: the audit harness is under `reports/02/invariants/harness/`. It runs the real `SYAHarvester` against `RouterNGv11Model.sol`, a model of the v1.1 dispatch that is not a mainnet fork.

- `test_swapType9_acceptedThenFailLoud` (`RouteDiffInvariant.t.sol` L179; `forge-tripwires.log`) **PASS**. `setRoute` stores a route with `swapParams[0][2] = 9`, and a second route with a row-1 swap_type of about 2^256. Each subsequent harvest reverts `"Bad swap type"`, and `residueClean()` holds, so nothing is stranded.
- `invariant_swapTypeFailLoud` **PASS**. Against the real `SYAHarvester`, forge ran 3,000 runs / 300,000 calls (`forge-routediff-real.log`), and Medusa `property_swapTypeFailLoud` also passed. The property holds at 500 runs on the two validator mutants as well (`mutantnogap`, `mutantnoend`). Over fuzzed routes, every accepted route with an out-of-range swap_type reverts the harvest (`swapTypeChecks 7`, `swapTypeHarvestReverts 7`), and harvester and caller balances are unchanged.

**Relation to other findings**: this is not an incomplete fix of M-01. M-01's root cause was a silent strand; this residual fails loudly, and its root-cause class and mitigation are different. It is the same kind of mild, non-obvious owner footgun as the carried L-03. Severity is borderline Low/QA, which leaves the final call to the severity auditor: the floor is QA, because a fail-loud revert on an attended owner path is not a defect in itself, and the ceiling is Low.

**Safe-config guidance (until fixed)**:
1. Register only swap_type values **1..8** against the v1.1 router. Do not reuse v1.2 route-builder output that may emit 9 (ERC4626).
2. After every `setRoute`, simulate the stored route before relying on it: `eth_call` `router.get_dy(path, swapParams, amount, pools)` (or `exchange`), or run a `harvest.sh` dry run. Either raises `"Bad swap type"` for an unexecutable row.

**Recommendation**: bound the executed swap_type to the immutable router's dispatch range, and make the mock match the real router:

```solidity
error InvalidRouteSwapType(uint256 hop, uint256 swapType);

/// @dev Curve Router NG v1.1 (`router`, immutable) dispatches swap_type 1..8 only.
uint256 private constant MAX_SWAP_TYPE = 8;

for (uint256 h = 0; h < 5; h++) {
    if (h < k) {
        uint256 st = swapParams[h][2];
        if (st == 0 || st > MAX_SWAP_TYPE) revert InvalidRouteSwapType(h, st);
    } else {
        ...
    }
}
```

In `MockCurveRouter.exchange`, revert when `_swapParams[h][2] == 0 || _swapParams[h][2] > 8`, so the unit suite matches v1.1 (see the carried Q-06, sub-issue 4). Add the new error selector to `KNOWN_ERRORS` in `harvest.sh`. Avoid the `swapParams[h][2] - 1 >= 8` idiom: under checked arithmetic it panics with `0x11` for `swap_type == 0` instead of returning the custom error. A cheaper alternative is to change the NatSpec and story-007 so they say `setRoute` validates path shape only, and to make the post-registration simulation above a required step in the runbook.

---

## Centralization Risks

None this run (see Summary).

---

## Carried Low/QA findings (run 01)

These are carried, not re-filed. Full bodies are in [carryover/qa-report-01.md](./carryover/qa-report-01.md). Labels and issue IDs are the originals from run 01. All are still `open` in the ledger. Triage with `/ledger sya-harvester`.

| Label | Issue ID | Run-02 status |
|---|---|---|
| L-01 | sh1l1 | Still live. `_sellYield` is untouched by the `62c19c8..6b862aa` diff. |
| L-02 | sh1l2 | Still live. The profit floors are unchanged. The `Unprofitable` gas check is still not exercised by the invariants (gasprice 0). |
| L-03 | sh1l3 | Still live, with a **k=0 addendum**. After an SYA `setRewardToken`, the canonical k=0 route stored for the old reward token becomes reachable if a strategy delivers the old token. Router NG always executes hop 0, so the harvest reverts with empty data rather than `RouteNotConfigured`, and `harvest.sh` cannot decode the revert. It fails loudly and nothing is stranded; severity unchanged. Related: F-06. |
| L-04 | sh1l4 | Still live. Four setRoute-only errors were added to `KNOWN_ERRORS` (selectors verified), but the root cause is unaddressed. Two newly missing instances: `SafeERC20FailedOperation(address)` and `SafeCastOverflowedUintToInt(uint256)`. Both are reachable from the harvester and absent from `KNOWN_ERRORS`. |
| Q-01 | sh1q1 | Still live. The borrow buffer is unchanged. |
| Q-02 | sh1q2 | Still live. The V4 swap code is untouched. |
| Q-03 | sh1q3 | Still live. No rescue path was added. |
| Q-04 | sh1q4 | Still live. Slippage and deadline handling are unchanged. |
| Q-05 | sh1q5 | Still live. No fix in the diff. |
| Q-06 | sh1q6 | **Partly fixed.** Sub-issue 2 (the mock mirrors the validator) is fixed. Sub-issues 1 and 3 are unchanged. New residual 4: the mock accepts and executes swap_type >= 9, which hides L-05. It also reverts `NoHop` instead of modelling hop 0 always executing, and its revert payloads differ from the real router's. |
| Q-07 | sh1q7 | Still live. The `harvest.sh` change touched `KNOWN_ERRORS` only. |
