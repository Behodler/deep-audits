# [CARRYOVER] F-01-migration-credit-asymmetry — Migration credit asymmetry: operator batchMigrate books users below principal through a haircutting destination strategy while userMigrate keeps full value

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L429-L450` (`batchMigrate`)
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not touch StableStaker.batchMigrate / StableStakerMigrator.migrate; the batch-vs-self-exit credit asymmetry (faithfulness F-01) is unchanged.
- **Original report:** [reports/stable-staker-07/submissions/spec-conformance.md](../../../stable-staker-07/submissions/spec-conformance.md)
- **Fingerprint:** `4f143a95…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
