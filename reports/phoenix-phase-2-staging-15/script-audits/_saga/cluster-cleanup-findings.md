# Cluster-cleanup tail audit — steps 9, 11, 12, OOB-breakglass

Saga: Story 060+065 YS-swap migration · HEAD 0e190e8 · fork block 25313321 · mode: fork-preview

## Primary finding (Medium) — SAGA-SYA-BRICK (merge with peer step-11 finding)

**Cleanup tail bricks `SYA.claim()`.** Step 11 (`DeregisterOldStrategiesFromSYA`) hardcodes
`LIVE_SYA = 0x3bBE…` — the **superseded, now-empty** accumulator. The live production accumulator is
`0x3C69…` (`mainnet-addresses.ts:34`; `progress.replace-sya.1.json` records `oldSYA=0x3bBE, newSYA=0x3C69`;
step 1 registered V2 onto 0x3C69 and step 9 asserts against it).

Fork-confirmed at block 25313321:
- `0x3bBE.getYieldStrategies()` = `[]`  → step 11 removes nothing (silent no-op).
- `0x3C69.getYieldStrategies()` = `[YS_DOLA_OLD, YS_USDE, YS_USDC_OLD]` → olds stay registered.
- Both SYAs `owner == OWNER`, so the script's owner-equality preflight does **not** catch the wrong target;
  post-asserts pass vacuously on the empty registry.

Then step 12 (`DecommissionOldStrategies`) `pause()`s the old strategies while they're still registered on
0x3C69. `SYA.claim()` loops registered strategies and calls `skimSurplus` on each whose **SYA token-config**
is not paused (DOLA/USDC configs are live). `AYieldStrategy.skimSurplus` is `whenNotPaused` → reverts
`EnforcedPause`. The SYA's skip is keyed on its own `tokenConfig.paused`, **not** the strategy's pause state,
so the paused old strategy is not skipped → the whole `claim()` reverts for **every** caller on the canonical
(empty-`exemptStrategies`) path. Yield consolidation to Phlimbo is dead by default.

**Severity = Medium** (protocol function/availability DoS, self-inflicted, no theft). Bounded below High by the
`exemptStrategies` escape hatch: a claimer can pass the (still-registered) paused olds as exempt to route around
them — but the UI/keepers/default callers use an empty array and all revert.

**Fix:** point step 11 at 0x3C69 (address fix) AND/OR make step 11 assert the olds are *present before* removal
(fail loud on wrong/empty target) and step 12 assert they're no longer registered before pausing.

PoC: `workspace/phoenix-phase-2-staging/test/SagaCleanupSYABrick.t.sol` — 4/4 PASS (pre-state skim OK; step 11
no-op on 0x3C69; post-tail `skimSurplus` reverts; exempt-eligibility holds).

## Secondary (Low)

- **SAGA-DEREGISTER-VACUOUS-GUARD** — step 11's owner-check + post-asserts pass green on a wrong-but-owned empty
  SYA; never asserts the olds were present before removal. Enabling weakness behind the brick; track the
  assert-present-before-remove fix even if the address is corrected.
- **SAGA-STEP9-PARTIAL-BROADCAST** — step 9 unpauses both stakers *before* the YS-22 pauser-recorded `require`;
  with the documented `--skip-simulation`, a missing pauser key leaves stakers unpaused but pauser un-restored
  until a re-run. Narrow (hand-edited JSON) operator window; fix = validate-then-mutate ordering.

## Cleared (no new Medium+)

- Step 9 minter teardown: only temp staker revoked; step-2 new minter untouched. Clean.
- Step 12 `emergencyWithdraw`: guarded by `getTotalShares()>0`, no revert on empty. Residual evacuated by
  earlier steps. Clean.
- Step 12 other consumers: live staker on V2 by step 6; USDe strategy correctly left live; OLD_MINTER already
  neutered in step 3. Only SYA consumer affected (→ brick).
- Pauser restoration: origPauser gate requires recorded + non-zero. Wrong-non-zero-record risk folded into the
  step-9 Low family.
- OOB breakglass: owner-gated, early-return-if-not-paused, no unintended writes. YS-21 fix confirmed by peer.
