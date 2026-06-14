# Intent — migrate:ys-swap-cleanup (PostMigrationCleanup, story-060 step 5; story-062/063)
## Stated purpose
- [x] Verify final migrated state; revoke tempStaker phUSD minter (setMinter false)
- [x] story-062: unpause BOTH stakers; restore recorded pausers
- [x] story-063: REMOVE [skim/2,skim*2] buffer band (log-only); RETAIN solvency require(principal>=totalStaked)
## Pre/post
- pre: counts, principalOf>0, solvency, SYA consumer-exists 11a-d
- post: both !paused; pausers==recorded (gated on *Recorded)
## Verdict: YS-10 FIXED (band gone, cleanup completes on surplus-dominated buffers). Minter-revoke confirmed NOT skipped by band removal. NEW Low: catch-path skips pauser restore silently (vacuous post-assert).
