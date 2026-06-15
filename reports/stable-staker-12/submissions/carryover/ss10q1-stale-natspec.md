# [CARRYOVER] QA-01 / F-01 (`ss10q1` / `b197e829`) — Stale NatSpec + structurally-dead in-place drain branch / underwater guard under the story-010 empty-pool gate

> **Carryover stub, not new analysis.** Reported in a prior run; status **submitted-qa**, not
> human-triaged-closed at HEAD `ffa4947`. This run ([story-012] InPlaceMigrator, new contract) did
> **not** revise the `setYieldStrategy`/`finalizeAndReset` in-source NatSpec. Reproduced so it is not
> lost between runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `b197e829` (`ss10q1`)
- **Severity:** Low/QA (faithfulness, in-source NatSpec doc-lie) · **Status:** submitted-qa
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` NatSpec/dead-branch/dead-guard (L204-250); `finalizeAndReset` NatSpec (L580-583)
- **First seen:** stable-staker-10 · **Still present as of:** stable-staker-12
- **Original report:** [reports/stable-staker-10/submissions/qa-report.md](../../../stable-staker-10/submissions/qa-report.md)
- **Spec-conformance:** [reports/stable-staker-10/submissions/spec-conformance.md](../../../stable-staker-10/submissions/spec-conformance.md)

**Note:** This is the in-SOURCE NatSpec surface that `125f585` did NOT fix (distinct from `ss9f3`'s
CLAUDE.md surface, which `125f585` did resolve).

See the original report for full description.
