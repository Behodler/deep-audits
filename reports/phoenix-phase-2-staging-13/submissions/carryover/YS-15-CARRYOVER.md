# [CARRYOVER] YS-15 (5b5f1d8b) — Reset preflight wires JSON-sourced strategy addresses + grants unlimited approval with no on-chain identity verification

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-reset`
- **Location:** `script/ResetAndRewire.s.sol#L98-L149` (`_globalPreflight`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** story-062 reset added resume guards but NO on-chain identity verification of JSON-sourced strategy addresses (code presence / vault / underlying / client auth). Root cause untouched.
- **Original report:** [reports/phoenix-phase-2-staging-12/findings/low/YS-15-missing-strategy-identity-preflight.json](../../phoenix-phase-2-staging-12/findings/low/YS-15-missing-strategy-identity-preflight.json)
- **Fingerprint:** `5b5f1d8b`

See the original report for the full description, impact, attack path, and recommendation.
