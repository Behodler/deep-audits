# [CARRYOVER] L-03 (informational) — initiateMigration writes state after the external strategy call (reentrancy ordering)

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Info (QA; guard- and trust-mitigated, no exploit demonstrated)
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L387-L408` (`initiateMigration`)
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker/07/submissions/qa-report.md](../../../07/submissions/qa-report.md)
- **Fingerprint:** `796f775f`

This run (stable-staker-08, regression) did not touch this path; the finding is unchanged. It is the
automated-tool CEI-ordering category C4 normally invalidates, deliberately preserved in a visible
channel (Law 1). Distinct from M-04 (`dc361b7d`, same function, different root cause — now fixed this
run). See the original QA report (L-03) for the full description and recommendation.
