# [CARRYOVER] L-02 — Phlimbo standing-allowance depletion bricks permissionless claim() until owner re-approves

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger stable-yield-accumulator`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableYieldAccumulator.sol#L369-L374` (`approvePhlimbo`)
- **First seen:** stable-yield-accumulator-11  ·  **Still present as of:** stable-yield-accumulator-12
- **Original report:** [reports/stable-yield-accumulator-11/findings.json](../../../stable-yield-accumulator-11/findings.json)
- **Fingerprint:** `8c488648…`

Re-confirmed this run (DEDUP-004 / CODE-002 / ECON-02 at HEAD 71abe3e; the fixed-amount
`collectReward` pull is re-verified at `lib/.../phlimbo-ea/src/Phlimbo.sol:277`). `approvePhlimbo`
sets a fixed allowance that is never topped up, so cumulative pulls eventually brick every
permissionless `claim()` until the owner re-approves. Availability only, owner-recoverable, no value
loss. No severity change.

See the original report for the full description, impact, attack path, PoC, and recommendation.
