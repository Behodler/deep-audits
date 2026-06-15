# [CARRYOVER] L (`ss10l1` / `787e9fac`) — Dust-stake grief of the empty-pool gate (1-wei stake forces a full terminal-migration cycle to rewire a strategy)

> **Carryover stub, not new analysis.** Reported in a prior run; status **submitted-qa**, not
> human-triaged-closed at HEAD `ffa4947`. This run ([story-012] InPlaceMigrator, new contract) did
> **not** touch the empty-pool gate at `setYieldStrategy:L228`. Reproduced so it is not lost between
> runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `787e9fac` (`ss10l1`)
- **Severity:** Low/QA (Law-3 footgun) · **Status:** submitted-qa
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` empty-pool gate (L228)
- **First seen:** stable-staker-10 · **Still present as of:** stable-staker-12
- **Original report:** [reports/stable-staker-10/submissions/qa-report.md](../../../stable-staker-10/submissions/qa-report.md)

**Cross-ref (run-12):** Same revival-runbook surface as this run's new `ss12l3` (`86fcf00e`) and
prior `ss9l1`; distinct root cause (gate-grief vs emission-dilution vs stale-config). Same pause-wrap
mitigation; candidate for a single 'revival-window pause-wrap' QA recommendation.

See the original report for full description, impact, and recommendation.
