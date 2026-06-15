# [CARRYOVER] L (`ss9l1`) — `finalizeAndReset` revives a pool without resetting `phusdPerSecond` / re-wiring `yieldStrategy`

> **Carryover stub, not new analysis.** Reported in a prior run, still **open** at HEAD `ffa4947`.
> This run ([story-012] InPlaceMigrator, new contract) did **not** change the revival-config behaviour
> of `finalizeAndReset`. Reproduced so it is not lost between runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `ss9l1` (`ss9l1-finalizeAndReset-revival-stale-emission-rate`)
- **Severity:** Low/QA (Law-3 footgun) · **Status:** open
- **Location:** `src/StableStaker.sol` — `finalizeAndReset` (L585-596)
- **First seen:** stable-staker-09 · **Still present as of:** stable-staker-12
- **Original report:** [reports/stable-staker-09/submissions/qa-report.md](../../../stable-staker-09/submissions/qa-report.md)

**Cross-ref (run-12):** Same revival-runbook surface as this run's new `ss12l3` (`86fcf00e`,
revived-pool permissionless-stake window). Distinct root cause (stale-config vs interloper-stake
window); both recommend pause-wrapping the revival session.

See the original report for full description, impact, and recommendation.
