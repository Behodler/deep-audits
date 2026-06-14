# [CARRYOVER] YS-08 (aad98685) — Set-aside buffer downgraded 25% -> 10% on replacement strategies (contradicts user-set 25%)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-deploy`
- **Location:** `script/DeployTempStableStakerAndMigrators.s.sol#L84-L116` (`run`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** story-061 wired SYA as the buffer consumer (fixed the YS-03 dead-buffer) but the 25%->10% buffer PERCENT figure itself is untouched by any of stories 061-064. No fix evidence.
- **Original report:** [reports/phoenix-phase-2-staging-12/findings/low/YS-08-buffer-percent-stale-config.json](../../phoenix-phase-2-staging-12/findings/low/YS-08-buffer-percent-stale-config.json)
- **Fingerprint:** `aad98685`

See the original report for the full description, impact, attack path, and recommendation.
