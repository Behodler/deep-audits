# Intent — migrate:ys-swap-leg1 (SkimAndLeg1Migration, story-060 step 2)
## Stated purpose
- [x] Skim surplus from old DOLA/USDC/USDe strategies to original
- [x] PhlimboV2.collectReward(60 USDC); initiateMigration + batch-migrate DOLA/USDC to tempStaker
- [x] story-062: hard-assert BOTH stakers paused; resume-idempotent initiateMigration
## Declared pre-conditions
- owner USDC bal >= 60e6; migrator1 wired both sides; both stakers paused; old-strategy owner() checks; JSON count == on-chain stakerCount
## NOT declared (gaps -> findings)
- authorizedWithdrawers[OWNER] on the 3 old strategies (skim auth) — STILL-LIVE Medium
- JSON count is YS-04-undercounted — STILL-LIVE preflight DoS
## Verdict: reverts on as-shipped inputs (YS-04 count + skim-auth). Completes after 2 fixups.
