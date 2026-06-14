# Intent — migrate:ys-swap-deploy (DeployTempStableStakerAndMigrators, story-060 step 1)
See run-12 intent.md for the base. Run-13 deltas (stories 061/062):
## Stated purpose
- [x] Deploy ysDolaV2/ysUsdcV2 (vault@0110ce4 convertToAssets build), tempStaker, migrator1/2
- [x] Wire phUSD minter for tempStaker; addToken DOLA/USDC; setMigrator(migrator1) on both
- [x] Wire V2 strategies to original (setClient + buffer 10 + recipient)
- [x] story-061: setWithdrawer(SYA,true) + SYA.addYieldStrategy on BOTH V2 strategies (buffer consumer)
- [x] story-062: setPauser(OWNER)+pause() BOTH stakers; persist origPauser/tempPauser to JSON
## Declared pre-conditions
- all referenced addresses non-zero; SETASIDE_BUFFER==10; origPauser != 0; SYA.owner()==OWNER
- every wiring call idempotent (skip-if-already-target-state)
## Declared post-conditions
- _verifySyaWiring: both V2 authorizedWithdrawers(SYA) AND in SYA.getYieldStrategies()
- both stakers paused, pauser==OWNER
## Verdict: executes clean on fork. SYA wiring (YS-03) FIXED. NEW: live-staker pause introduces a pause-DoS surface (no break-glass unpauser).
