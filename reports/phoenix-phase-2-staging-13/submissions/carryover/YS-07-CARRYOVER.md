# [CARRYOVER] YS-07 (58911bd3) — Skim proceeds diverge from the migration doc: sent to the original staker instead of the treasury

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-leg1`
- **Location:** `script/SkimAndLeg1Migration.s.sol#L196-L201` (`run`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** No story addresses the skim destination (proceeds to staker, not treasury). Root cause untouched.
- **Original report:** [reports/phoenix-phase-2-staging-12/findings/low/YS-07-skim-destination-doc-divergence.json](../../phoenix-phase-2-staging-12/findings/low/YS-07-skim-destination-doc-divergence.json)
- **Fingerprint:** `58911bd3`

See the original report for the full description, impact, attack path, and recommendation.
