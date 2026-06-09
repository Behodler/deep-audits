# [CARRYOVER] rescueERC20 can sweep the buffer backing underwater withdrawals

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L702-L709` (`rescueERC20`)
- **First seen:** stable-staker-01  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker-01/submissions/qa-report.md](../../../stable-staker-01/submissions/qa-report.md)
- **Fingerprint:** `0790a76a`

This run (stable-staker-08, regression) did not touch the changed code path beyond what was
verified; the finding is unchanged. See the original QA report for the full description, impact, and
recommendation.
