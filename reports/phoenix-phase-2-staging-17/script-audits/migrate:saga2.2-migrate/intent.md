# Intent — migrate:saga2.2-migrate (`MigrateSaga2Migrate.s.sol:MigrateSaga2Migrate`)

STEP 2.2 of "MIGRATE SAGA 2 — InPlaceMigrator route" (2.1 deploy/freeze → **2.2 migrate (this)** → 2.3 accumulator rewire).
Time-critical: must land inside the in-flight `totalWithdrawal` Executable window `[initiatedAt+24h, initiatedAt+72h]` on the OLD DOLA/USDC strategies (deployed bytecode uses 24h-wait/48h-window; confirmed live: `WAITING_PERIOD=86400`, `EXECUTION_WINDOW=172800`).

## Stated purpose (from `//`comment, script NatSpec, plan §5 Script 2)
- [x] Top up Phlimbo reward pot with 60 USDC from the deployer (`collectReward(60e6)`).
- [x] Skim surplus: OLD DOLA/USDC → owner (measured, parked), USDe → staker (buffer, no sweep risk).
- [x] Pause the StableStaker for the duration of the rewire (capture & restore real pauser).
- [x] Drain the staker FIRST (`initiateMigration` + `migrateOut`) so principal is parked in the migrator.
- [x] Execute the minter's `totalWithdrawal` phase-2 SECOND (minter absorbs any haircut; funds → owner).
- [x] Rewire the now-empty pools onto the new strategies (`finalizeAndReset` + `setYieldStrategy`).
- [x] Re-inject parked stakers into the new strategies at par (`migrateIn`, surplus-funded top-up).
- [x] Seed V2 minter with the recovered minter funds via `noMintDeposit` (amount = actually received).
- [x] Transfer skimmed DOLA/USDC surplus to the staker AFTER the rewire as a set-aside buffer.
- [x] Unpause and restore the original pauser.
- [x] No new contracts deployed → `mainnet-addresses.ts` NOT touched, no JS chain.

## Ordered steps (script lines 84–144)
1. `pauser()` capture → `setPauser(OWNER)` → `pause()`.
2. `USDC.forceApprove(PHLIMBO_V2,60e6)` → `PHLIMBO_V2.collectReward(60e6)`.
3. `_ensureWithdrawer(oldDolaYS/oldUsdcYS/USDE_MARKET_YS)` → `skimSurplus(DOLA,OWNER)` / `skimSurplus(USDC,OWNER)` / `skimSurplus(USDE,STAKER)`.
4. `_drainStaker(DOLA)` then `_drainStaker(USDC)` (`initiateMigration` + `migrateOut`; require `stakerCount==0`). **TERMINAL: no resume path.**
5. `_executeMinterWithdrawal(oldDolaYS,DOLA)` then `(oldUsdcYS,USDC)` (`totalWithdrawal(token, MINTER_V1)`; recovered = owner balance delta).
6. `finalizeAndReset(DOLA)` / `(USDC)` → `setYieldStrategy(DOLA,ysDolaV2)` / `(USDC,ysUsdcV2)`.
7. `migrateIn(DOLA,0,max)` / `migrateIn(USDC,0,max)` (re-credit parked stakers; per-user gross-up top-up from migrator surplus).
8. `_seedV2(DOLA,ysDolaV2,recoveredDola)` / `(USDC,ysUsdcV2,recoveredUsdc)` (`forceApprove` + `noMintDeposit`; skipped if 0).
9. `if(dolaSkim>0) safeTransfer(STAKER,dolaSkim)` / `if(usdcSkim>0) safeTransfer(STAKER,usdcSkim)`.
10. `unpause()` → `setPauser(realPauser)`.

## Declared pre-conditions (`_loadDeployments` + `_preflight`, before broadcast)
- `saga2-deployments.json` present and `.migrator/.ysDolaV2/.ysUsdcV2/.minterV2` all non-zero (else "run saga 2.1 first").
- `block.chainid == 1` (setUp).
- `STAKER.owner() == OWNER_ADDRESS`.
- `USDC.balanceOf(OWNER) >= 60e6` (Phlimbo collectReward).
- `STAKER.migrator() == migrator` (2.1 wired the migrator).
- `oldDolaYS = STAKER.yieldStrategy(DOLA)` and `oldUsdcYS = ...(USDC)`, both `!= address(0)` (captured before drain).
- `principalOf(DOLA/USDC, MINTER_V1) >= 0` (trivially true — read smoke test only, NOT a window check).

## Declared post-conditions (`_postAssert`, AFTER broadcast block)
- `STAKER.yieldStrategy(DOLA) == ysDolaV2` and `(USDC) == ysUsdcV2`.
- `migrator.parkedUserCount(DOLA) == 0` and `(USDC) == 0`.
- `!STAKER.paused()`.
- `STAKER.pauser() == realPauser`.
- `oldDolaYS.principalOf(DOLA, MINTER_V1) == 0` and `oldUsdcYS.principalOf(USDC, MINTER_V1) == 0`.

## Plan-doc invariants beyond the script's own asserts
- (§3.2 HARD ORDERING) staker `migrateOut` MUST precede the minter's `totalWithdrawal` phase-2 — script honours this (steps 4→5).
- (§4) 2.2 must run inside `[init+24h, init+72h]`; **the script never asserts the withdrawal status is `Executable`** — it blindly calls `totalWithdrawal`. Window adherence is operator-assumed, not enforced.
- (§6) If `migrateIn` never completes, parked stakers recover principal via `claimTimedOut` after `migrationTimeout` (14 days), principal-only.
- (2.1 carryover) `DOLA_ALLOTMENT`/`USDC_ALLOTMENT` (hardcoded 0 + `require(>0)` tripwire in 2.1) fund the migrator's `migrateIn` top-up. If the allotment is zero/under-sized, 2.2's `migrateIn` reverts ("top-up surplus exhausted").

## Conformance summary (fork-verified at block 25322425)
- **Purposes met:** ALL 11 stated purposes execute end-to-end with a correctly-sized allotment (scenario A, 1000e18/1000e6).
- **Pre-conditions:** all satisfiable on live state EXCEPT the absent `saga2-deployments.json` (2.1 not yet broadcast — expected; 2.1 must precede 2.2).
- **Post-conditions:** ALL pass with a correctly-sized allotment. Stakers re-credited to par (V2 DOLA staker principal 1060e18 ≥ old 1033e18; minter funds 13816e18 DOLA / 11933e6 USDC seeded into V2).
- **Write-path ABI drift (2.1 M-01/M-02 lens):** CLEARED — `skimSurplus`/`totalWithdrawal`/`setWithdrawer` on the OLD strategies and `finalizeAndReset`/`setYieldStrategy`/`pause`/`unpause`/`setPauser` on the staker all execute without revert against the deployed (pre-current-lib) bytecode.
