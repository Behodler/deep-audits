# [CARRYOVER] YS-04 (8168c808) — gather-migration-inputs.js off-by-one: half-open getStakersRange drops the last staker of every pool (suite preflight DoS)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-leg1`
- **Location:** `scripts/gather-migration-inputs.js#L271-L284` (`gatherStakers`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Re-verified:** STILL-LIVE on fork at e935a05 — gather-migration-inputs.js unchanged (zero diff b27c6ac..e935a05). `getStakersRange(0,2)` returns 2 of 3 DOLA stakers; JSON `.count` < on-chain count -> leg1 preview reverts 'stale staker count'. Unbreakable re-run loop (single page always drops last). Availability DoS, not value-loss.
- **Original report:** [reports/phoenix-phase-2-staging/12/findings/low/YS-04-gather-offbyone-half-open-range.json](../../../12/findings/low/YS-04-gather-offbyone-half-open-range.json)
- **Fingerprint:** `8168c808`

See the original report for the full description, impact, attack path, and recommendation.
