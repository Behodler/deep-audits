# [CARRYOVER] YS-06 (7621c743) — Leg1/Leg2 staleness guard is count-equality only: equal-count membership drift strands an unlisted staker; script not re-runnable

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-leg1`
- **Location:** `script/SkimAndLeg1Migration.s.sol#L146-L157` (`run`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** story-062 leg1 added paused-asserts + resume guards but the count==count guard mechanism is unchanged; related to YS-04 which is STILL-LIVE. No fix evidence.
- **Original report:** [reports/phoenix-phase-2-staging-12/findings/low/YS-06-snapshot-vs-broadcast-membership-drift.json](../../phoenix-phase-2-staging-12/findings/low/YS-06-snapshot-vs-broadcast-membership-drift.json)
- **Fingerprint:** `7621c743`

See the original report for the full description, impact, attack path, and recommendation.
