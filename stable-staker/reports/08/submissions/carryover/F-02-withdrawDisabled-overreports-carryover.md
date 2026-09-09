# [CARRYOVER] F-02 — withdrawDisabled view over-reports: returns raw _isUnderwater so it reads true where a buffer-covered withdraw would succeed

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Low (QA; Law-2 faithfulness gap)
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L612-L617` (`withdrawDisabled`; `_isUnderwater` L666-668)
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker/07/submissions/spec-conformance.md](../../../07/submissions/spec-conformance.md)
- **Fingerprint:** `a56f8778`

> **Cross-reference (new this run):** thematically adjacent to **M-06** (`dbdc3ac9`,
> `setYieldStrategy` underwater-swap re-arms the withdraw block). Both concern the
> `withdrawDisabled`/`_isUnderwater` signal, but they are **opposite-direction and distinct**: F-02
> is a conservative *over*-report (the view reads `true` where a buffer-covered withdraw would
> succeed — UX false-negative, no value at risk), whereas M-06 is the hazardous *under*-report (the
> signal is silently lifted to `false` against a real shortfall, realizing an FCFS loss). Kept as
> separate ledger entries.

This run (stable-staker-08, regression) did not change `withdrawDisabled` itself; the finding is
unchanged. See the original spec-conformance (F-02) report for the full description and
recommendation.
