# [CARRYOVER] L-13 — _totalWithdraw records migration as executed even when sharesToSell floors to 0

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435` (`_totalWithdraw`)
- **First seen:** reflax-yield-vault-12  ·  **Still present as of:** reflax-yield-vault-14
- **Original report:** [reports/reflax-yield-vault/12/findings/low/L-13-total-withdraw-false-migration-complete.json](../../../12/findings/low/L-13-total-withdraw-false-migration-complete.json)
- **Fingerprint:** `1456259d…`

Re-observed this run via DEDUP-COL-002 (same strict-equality zero-snapshot early-return facet; tiny-balance client whose `sharesToSell` floors to 0 has its migration recorded as executed with principal left on the books). Benign exact-zero balance guard, not attacker-griefable; no value duplication. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
