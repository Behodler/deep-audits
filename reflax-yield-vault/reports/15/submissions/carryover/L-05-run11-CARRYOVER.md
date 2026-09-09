# [CARRYOVER] L-05-run11 — Constructor _owner shadowing across three contracts

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AMMAdapters/CurveAMMAdapter.sol`, `src/AYieldStrategy.sol`, `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (constructors, L48-L171)
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-15
- **Original report:** [reports/reflax-yield-vault/11/findings/low/L-05-constructor-owner-shadowing.json](../../../11/findings/low/L-05-constructor-owner-shadowing.json)
- **Fingerprint:** `adc461fa…`

Re-observed this run via DEDUP-15-011 / ADERYN-002/003/004 (exact match: local constructor parameter hides inherited `Ownable._owner`). Style/QA-class; severity/status unchanged.

See the original report for the full description, impact, and recommendation.
