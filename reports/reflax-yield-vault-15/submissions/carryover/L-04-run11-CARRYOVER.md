# [CARRYOVER] L-04-run11 — nonReentrant is not the first modifier across multiple entry points

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AYieldStrategy.sol` (L319, L366) and `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (L229, L248, L265, L279)
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-15
- **Original report:** [reports/reflax-yield-vault-11/findings/low/L-04-nonreentrant-modifier-ordering.json](../../../reflax-yield-vault-11/findings/low/L-04-nonreentrant-modifier-ordering.json)
- **Fingerprint:** `46ab675c…`

Re-observed this run via DEDUP-15-011 / ADERYN-005 (8 entry points). Defense-in-depth only; every preceding modifier is a no-external-call auth check, so no live reentrancy window. Severity/status unchanged.

See the original report for the full description, impact, and recommendation.
