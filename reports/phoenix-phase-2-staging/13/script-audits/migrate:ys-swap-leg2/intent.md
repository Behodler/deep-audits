# Intent — migrate:ys-swap-leg2 (Leg2Migration, story-060 step 4)
## Stated purpose
- [x] initiateMigration on tempStaker; batch-migrate DOLA/USDC back to original (now V2-backed)
- [x] story-062: resume guard (skip initiateMigration when tempStaker poolState != Active)
## Pre/post
- pre: migrator2 wired both sides; V2 buffer recipients set; JSON count == tempStaker stakerCount
- post: tempStaker count==0; original count==expected; V2 principalOf(original)>0
## Verdict: completes; ~0.006-0.02% per-user redeem-rounding haircut (carryover Low, unchanged by stable-staker bump 212a6d2).
