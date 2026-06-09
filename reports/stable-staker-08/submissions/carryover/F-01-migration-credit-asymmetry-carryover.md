# [CARRYOVER] F-01 — Migration credit asymmetry: batchMigrate books users below principal via a haircutting destination strategy while userMigrate keeps full value

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Low (Law-2 faithfulness gap; non-obvious owner footgun)
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L429-L450` (`batchMigrate`); also `src/StableStakerMigrator.sol:migrate` L76-80
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker-07/submissions/spec-conformance.md](../../../stable-staker-07/submissions/spec-conformance.md)
- **Fingerprint:** `4f143a95`

This run (stable-staker-08, regression) did not touch this path; the finding is unchanged. See the
original spec-conformance (F-01) report for the full description, impact, and recommendation.
