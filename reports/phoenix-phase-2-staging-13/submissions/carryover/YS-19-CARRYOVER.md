# [CARRYOVER] YS-19 (44107b0e) — viem not declared in package.json: the mandatory gather prerequisite cannot run from a clean checkout

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** QA
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-leg1`
- **Location:** `scripts/gather-migration-inputs.js#L130-L136` (`main`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** story-062 touched package.json only for `--skip-simulation`/preview-gate; no dependency declaration added.
- **Original report:** [reports/phoenix-phase-2-staging-12/findings/qa/YS-19-missing-dependency-declaration.json](../../phoenix-phase-2-staging-12/findings/qa/YS-19-missing-dependency-declaration.json)
- **Fingerprint:** `44107b0e`

See the original report for the full description, impact, attack path, and recommendation.
