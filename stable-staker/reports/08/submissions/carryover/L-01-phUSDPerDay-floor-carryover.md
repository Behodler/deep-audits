# [CARRYOVER] L-01 — phUSDPerDay sub-86400-wei/day budget floors phusdPerSecond to 0 (silent zero emission)

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Low (QA; non-obvious owner-config footgun)
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L167-L172` (`phUSDPerDay`; floor at L169)
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker/07/submissions/qa-report.md](../../../07/submissions/qa-report.md)
- **Fingerprint:** `d47619d2`

This run (stable-staker-08, regression) did not touch this path; the finding is unchanged. Distinct
from the accepted integer-division dust class (KI#2 / wont-fix `35e9be8d`) — only the sub-86400
silent-zero edge is classified here. See the original QA report (L-01) for the full description and
recommendation.
