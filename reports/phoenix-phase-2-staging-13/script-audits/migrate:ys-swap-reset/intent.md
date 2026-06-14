# Intent — migrate:ys-swap-reset (ResetAndRewire, story-060 step 3)
## Stated purpose
- [x] finalizeAndReset(DOLA/USDC); setYieldStrategy to V2 (idle-sweep) = run-12 YS-01 BRICK POINT; setMigrator(migrator2)
- [x] story-062: resume guards (skip finalize/setYieldStrategy/setMigrator when already in target state)
## Declared pre/post-conditions
- pre: original stakerCount/totalStaked==0; owner() checks
- post: yieldStrategy==V2; dolaWired/usdcWired-gated swept-amount asserts; totalStaked==0
## Verdict: YS-01 FIXED — setYieldStrategy idle-sweep deposits via convertToAssets without reverting (swept 26.785 DOLA / 28.54 USDC on fork).
