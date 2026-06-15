# [CARRYOVER] ss12l3 (run-12 L-03) — Revived-pool permissionless-stake window before migrateIn (exploit refuted; emission-dilution only)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** QA
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol` (`finalizeAndReset`)
- **First seen:** stable-staker-12  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not pause-wrap the revival window; the permissionless-stake-before-migrateIn emission-dilution residual is unchanged (exploit already refuted).
- **Original report:** [reports/stable-staker-12/submissions/qa-report.md](../../../stable-staker-12/submissions/qa-report.md)
- **Fingerprint:** `86fcf00e…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
