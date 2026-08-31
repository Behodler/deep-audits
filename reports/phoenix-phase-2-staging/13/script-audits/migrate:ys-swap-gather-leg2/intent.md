# Intent — migrate:ys-swap-gather-leg1 / -leg2 (gather-migration-inputs.js)
## Stated purpose
- Page the on-chain staker set for DOLA/USDC and write leg1/leg2-stakers.json for the forge legs
## Verdict: YS-04 off-by-one STILL-LIVE (unchanged file). getStakersRange half-open [start,end) treated as inclusive -> drops last staker per pool -> JSON undercount -> forge preflight count-equality reverts -> unbreakable re-run loop (availability DoS).
