# Intent — migrate:ys-swap-leg1 (SkimAndLeg1Migration.s.sol, story 060 step 2 of 5)

## Stated purpose (package.json `//ys-swap-migration` + script NatSpec + docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md)
- [ ] Pre-flight: deployer holds >= 60 USDC (FIRST check, before any prank/broadcast) — for the Phlimbo reward injection
- [ ] Skim surplus from all 3 old yield strategies (YS_DOLA_OLD 0x90ce…, YS_USDC_OLD 0x90af…, YS_USDE 0xaC2e…) — **script sends proceeds to ORIGINAL_STABLE_STAKER; the intent doc (lines 133–135) says `treasuryAddress`** (divergence — see finding LEG1-04)
- [ ] USDC.approve(PHLIMBO_V2, 60e6) + PhlimboV2.collectReward(60e6) — reward injection atomic with the skim in the same broadcast ("guards against a dry run"; covers Phlimbo USDC rewards while the strategies are drained)
- [ ] migrator1.initiateMigration(DOLA), migrator1.initiateMigration(USDC) — snapshot (R, P), realize + decouple the old strategies on the original staker
- [ ] Chunked migrator1.migrate(token, chunk) for DOLA then USDC from leg1-stakers.json — batchMigrate pays each user p_i·min(R,P)/P from the realized idle pile, mints pending phUSD to the user's wallet (payout 1 of 2), depositFor credits the same principal on tempStaker
- [ ] Broadcast only: persist dolaSkimmed/usdcSkimmed/usdeSkimmed into script/migration-inputs/ys-swap-deployments.json (consumed by PostMigrationCleanup)
- [ ] USDe pool and its stakers untouched (skim only; ERC4626MarketYieldStrategy is correct and is NOT replaced)

## Declared pre-conditions (`_globalPreflight`, before prank/broadcast)
- IERC20(USDC).balanceOf(OWNER_ADDRESS) >= 60e6
- ys-swap-deployments.json readable; `.migrator1` != 0
- ORIGINAL_STABLE_STAKER.migrator() == migrator1 (step-1 wiring)
- tempStaker.migrator() == migrator1 (step-1 wiring)
- owner() == OWNER_ADDRESS on all 3 old strategies
- migrator1.owner() == OWNER_ADDRESS
- leg1-stakers.json `.tokens.DOLA.count` / `.tokens.USDC.count` exactly == live stakerCount (staleness guard — count equality ONLY, no set-membership check)
- setUp(): block.chainid == 1

**Notably absent:** no check that OWNER_ADDRESS is an authorized withdrawer on the 3 strategies, even though step 1 of run() is `skimSurplus` which is `onlyAuthorizedWithdrawer` (this is what kills the script — finding LEG1-01).

## Declared post-conditions (require after the migrate loop)
- ORIGINAL_STABLE_STAKER.stakerCount(DOLA) == 0
- ORIGINAL_STABLE_STAKER.stakerCount(USDC) == 0
- original staker DOLA/USDC/USDe balances >= respective skimmed amounts ("surplus must still be parked on the original staker"; the in-source comment explicitly defers folding this idle balance into the V2 strategies to ResetAndRewire's setYieldStrategy sweep — DOLA/USDC only; nothing ever sweeps the USDe proceeds)
- (logged, not asserted) tempStaker stakerCount(DOLA/USDC)

## Mode mechanics
- Preview: PREVIEW_MODE=true ⇒ vm.startPrank(OWNER_ADDRESS), skips the vm.writeJson persistence
- Broadcast: vm.startBroadcast() with --skip-simulation --slow --ledger (hd-path m/44'/60'/46'/0/0)

## Inputs
- script/migration-inputs/ys-swap-deployments.json (written by step-1 broadcast; read in preflight + run)
- script/migration-inputs/leg1-stakers.json (written by manual prerequisite `migrate:ys-swap-gather-leg1`; NOT chained into the npm command)
