# [CARRYOVER] Unused return value of EnumerableSet.add/remove

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Info (QA)
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L233-L361` (`add`/`remove` on the staker `EnumerableSet`)
- **First seen:** stable-staker-01  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker/01/submissions/qa-report.md](../../../01/submissions/qa-report.md)
- **Fingerprint:** `7b071779`

This run (stable-staker-08, regression) did not touch this path; the finding is unchanged. See the
original QA report for the full description and recommendation.
