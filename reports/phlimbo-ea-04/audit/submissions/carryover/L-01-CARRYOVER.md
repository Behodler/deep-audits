# [CARRYOVER] L-01 — Declared event RateUpdated is never emitted

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open carryover)
- **Location:** `src/Phlimbo.sol#L105-L106` (event declaration)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea-03/audit/findings/low/L-01-RateUpdated-event-never-emitted.json](../../../../phlimbo-ea-03/audit/findings/low/L-01-RateUpdated-event-never-emitted.json)
- **Fingerprint:** `658a8b66…`

> **Note on labels:** this is **ledger** label L-01 (RateUpdated never emitted), NOT
> this run's run-label L-01 (the CEI reentrancy = ledger L-09). Carryover stubs use ledger labels.

See the original report for the full description, impact, attack path, PoC, and recommendation.
