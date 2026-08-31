# Intent — migrate:ys-swap-leg2 (Leg2Migration.s.sol, story-060 step 4)

## Stated purpose (from NatSpec + intent doc + package.json `//ys-swap-migration`)
- [x] Migrate all DOLA and USDC stakers back from `tempStaker` → `ORIGINAL_STABLE_STAKER`,
      which step 3 (ResetAndRewire) rewired to the fixed V2 yield strategies.
- [x] Step 1: `migrator2.initiateMigration(DOLA)` then `initiateMigration(USDC)` on the temp staker
      (engages terminal migration: snapshots (R,P), realizes idle pile, decouples).
- [x] Step 2: chunk-loop `migrator2.migrate(DOLA, chunk[i])` for every chunk in leg2-stakers.json.
- [x] Step 3: chunk-loop `migrator2.migrate(USDC, chunk[i])` for every chunk.
- [x] Each `migrate` → `batchMigrate` (pays snapshot credit from temp's idle pile) → `depositFor`
      on original → `_routeDeposit` into the fixed V2 strategy with `convertToAssets` accounting.
- [x] USDe pool is never touched (out of scope per intent doc).

## Declared pre-conditions (`_globalPreflight`, reverts before any state change)
- `setUp`: `block.chainid == 1` (mainnet only).
- migrator2 / tempStaker / ysDolaV2 / ysUsdcV2 addresses (read from ys-swap-deployments.json) != 0.
- `migrator2.owner() == OWNER_ADDRESS`.
- `ORIGINAL_STABLE_STAKER.migrator() == migrator2` (step-3 wiring present on original).
- `tempStaker.migrator() == migrator2` (step-3 wiring present on temp).
- `ysDolaV2.setAsideBufferRecipient() != 0` and `ysUsdcV2.setAsideBufferRecipient() != 0`
  (V2 strategies wired — step 1).
- `leg2DolaCount == tempStaker.stakerCount(DOLA)` (count-equality drift guard — staleness of
  leg2-stakers.json).
- `leg2UsdcCount == tempStaker.stakerCount(USDC)` (same for USDC).

## Declared post-conditions (asserts after the migrate loops)
- `tempStaker.stakerCount(DOLA) == 0` and `stakerCount(USDC) == 0` (source drained).
- `ORIGINAL_STABLE_STAKER.stakerCount(DOLA) == leg2 DOLA count` (3).
- `ORIGINAL_STABLE_STAKER.stakerCount(USDC) == leg2 USDC count` (6).
- `ysDolaV2.principalOf(DOLA, original) > 0`.
- `ysUsdcV2.principalOf(USDC, original) > 0`.

## Inputs (out-of-band, NOT produced by this entry point)
- `script/migration-inputs/ys-swap-deployments.json` — produced by `migrate:ys-swap-deploy`
  (addresses of migrator2 / tempStaker / ysV2s).
- `script/migration-inputs/leg2-stakers.json` — produced by `migrate:ys-swap-gather-leg2`
  (`gather-migration-inputs.js --leg 2`). **Subject to LEG1-02** (drops last staker per pool).

## Trust / signer
- Preview: `vm.startPrank(OWNER_ADDRESS)`. Broadcast: `vm.startBroadcast()` + Ledger
  (`--ledger --hd-paths m/44'/60'/46'/0/0`). Owner is the migrator2 owner — verified in preflight.
- Broadcast uses `--skip-simulation` (response to story-055 RESUME stale-calldata history).
