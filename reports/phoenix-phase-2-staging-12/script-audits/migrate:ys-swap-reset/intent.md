# Intent — migrate:ys-swap-reset (ResetAndRewire.s.sol, story 060 step 3 of 5)

## Stated purpose
Sources: package.json `//ys-swap-migration` comment; ResetAndRewire.s.sol NatSpec; docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md ("Step 3 — Reset original and wire new strategies" + "Step 4 — Wire migrator2", which this script merges); [story-060] commits.

- [ ] `finalizeAndReset(DOLA)` + `finalizeAndReset(USDC)` on the original StableStaker (0xbce8…079A): revive both fully-drained pools Migrating → Active, clearing the `(R,P)` migration snapshot and fast-forwarding `lastRewardTime`.
- [ ] `setYieldStrategy(DOLA, ysDolaV2)` + `setYieldStrategy(USDC, ysUsdcV2)`: wire the new story-048-fixed `ERC4626YieldStrategy` V2 instances (addresses from `script/migration-inputs/ys-swap-deployments.json`). The call synchronously sweeps the idle base-token balance sitting on the staker (leg1 skim surplus + migration dust) into the new strategy via `strategy.deposit(token, idleBalance, this)`.
- [ ] `setMigrator(migrator2)` on BOTH stakers (temp + original), replacing migrator1, arming the return leg (step 4, temp → original).
- [ ] The USDe pool is deliberately untouched (doc: "USDe pool never moves"; its `ERC4626MarketYieldStrategy` is correct).
- [ ] JS pre-wrapper `backup-mainnet-addresses.js`: snapshot `server/deployments/mainnet-addresses.ts` to `server/deployments/mainnet.backup.<timestamp>.ts` before the broadcast.
- [ ] JS post-wrapper `patch-mainnet-addresses-ys-swap.js`: rewrite EXACTLY two fields of `server/deployments/mainnet-addresses.ts` — `YieldStrategyDola` ← ysDolaV2, `YieldStrategyUSDC` ← ysUsdcV2 (unconditional overwrite of the old non-zero addresses) — plus a one-time header comment. It must NOT touch `StableStaker` (same address, rewired in place), `YieldStrategyUSDe`, tempStaker, or migrators.

## Declared pre-conditions (`require`s before the prank/broadcast block)
1. `setUp`: `block.chainid == 1` (mainnet only).
2. `vm.readFile("script/migration-inputs/ys-swap-deployments.json")` parses; `.ysDolaV2`, `.ysUsdcV2`, `.tempStaker`, `.migrator2` all non-zero.
3. Leg1-completion drift guards on the original staker: `stakerCount(DOLA) == 0`, `poolInfo(DOLA).totalStaked == 0`, `stakerCount(USDC) == 0`, `poolInfo(USDC).totalStaked == 0`.
4. `original.migrator() != address(0)` (migrator1 wired in step 1).
5. Ownership: `migrator2.owner() == OWNER`, `tempStaker.owner() == OWNER`, `original.owner() == OWNER`, OWNER = 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6.

Notable ABSENT pre-checks (assessed in findings):
- No check that the pools are in `PoolState.Migrating` (finalizeAndReset would revert anyway, but no early drift guard).
- No check that ysDolaV2/ysUsdcV2 have code, are wired to the right vaults/underlying, or that `authorizedClients(original) == true` (doc "Wire" checklist item) — a missing setClient surfaces only mid-suite as a deposit revert.
- No smoke-test deposit into the V2 strategies before mutating the staker (would have caught F1 pre-broadcast).

## Declared post-conditions (asserts after prank/broadcast stop — reads only)
1. `ysDolaV2.principalOf(DOLA, original) <= dolaIdleSwept` (no over-credit) AND `> 0` if `dolaIdleSwept > 0` (sweep fired). Same pair for USDC. (Deterministic buffer post-asserts added by commit 71c545c; note the NatSpec header still says `principalOf > 0` unconditionally and the doc says `principalOf == 0` expected — the code's two-sided bound supersedes both.)
2. `original.poolInfo(DOLA).totalStaked == 0` and same for USDC (still empty after reset).
3. Logged but NOT asserted: `setAsideBufferSize(original)` and `setAsideBufferRecipient()` on both V2 strategies (doc says verify == 10 after leg 2).

## Implicit expectations (from doc/story, not coded)
- New strategies credit `vault.convertToAssets(sharesReceived)` per the doc's prescribed fix (the deployed code actually uses `vault.previewRedeem(sharesReceived)` — upstream finding F1).
- After this step, leg 2's `depositFor` → `_routeDeposit` → V2 `deposit` must succeed for 9 users parked in the temp staker.
- migrator1 is fully superseded; only migrator2 retains migration authority on both stakers.
