# [CARRYOVER] L-01 — Broadcast uses --skip-simulation with an offline-derived stale-able minBPT; no live re-query enforced

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open, mitigated)
- **Entry point:** `dispatcher-replace-sky-pooler`
- **Location:** `script/DispatcherReplaceSkyPoolerAtIndex4.s.sol#L542-L602` (`_step15_pool`)
- **First seen:** phoenix-phase-2-staging-09  ·  **Still present as of:** phoenix-phase-2-staging-10
- **Original report:** [reports/phoenix-phase-2-staging-09/findings/low/L-01-skip-simulation-stale-minbpt.json](../../../phoenix-phase-2-staging-09/findings/low/L-01-skip-simulation-stale-minbpt.json)
- **Fingerprint:** `d32e99aa…`

**Reconciliation @ HEAD 30775401 (fork block 25242176):** Mitigated, not closed. The rewrite
wraps `pool()` in a try/catch (step 17) so a too-high stale floor no longer strands a
half-applied cutover (fork-proven). Residual: no live in-script minBPT re-query was added —
weak-slippage / silent-LP-deferral persists, broadcast still carries `--skip-simulation`.

See the original report for the full description, impact, attack path, and recommendation.
