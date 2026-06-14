# [CARRYOVER] YS-14 (e3f6e7a0) — Replacement strategies and temp staker deployed without pauser registration

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open) — PARTIAL/UNVERIFIED; **needs explicit re-verification before any fixed claim**
- **Entry point:** `migrate:ys-swap-deploy`
- **Location:** `script/DeployTempStableStakerAndMigrators.s.sol#L141-L193` (`run`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** story-062 adds `setPauser(OWNER)+pause()` on the original and temp STAKERS, but YS-14 is about pauser REGISTRATION so emergency pause can reach the V2 STRATEGIES + temp staker. The delta shows staker setPauser, NOT Pauser-registry registration of the V2 strategies; no explicit fix-verdict. Per recall-beats-tidiness, NOT marked fixed.
- **Original report:** [reports/phoenix-phase-2-staging-12/findings/low/YS-14-missing-pauser-registration.json](../../phoenix-phase-2-staging-12/findings/low/YS-14-missing-pauser-registration.json)
- **Fingerprint:** `e3f6e7a0`

See the original report for the full description, impact, attack path, and recommendation.
