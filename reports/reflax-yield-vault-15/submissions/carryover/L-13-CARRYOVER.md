# [CARRYOVER] L-13 — _totalWithdraw records migration as executed even when sharesToSell floors to 0

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435` (`_totalWithdraw`)
- **First seen:** reflax-yield-vault-12  ·  **Still present as of:** reflax-yield-vault-15
- **Original report:** [reports/reflax-yield-vault-12/findings/low/L-13-total-withdraw-false-migration-complete.json](../../../reflax-yield-vault-12/findings/low/L-13-total-withdraw-false-migration-complete.json)
- **Fingerprint:** `1456259d…`

Re-observed this run via DEDUP-15-008 (same strict-equality zero-snapshot early-return facet). Benign exact-zero balance guard, not attacker-griefable; no value duplication; no diff lines touch these guards. Adjacency note: covers only the benign live-balance-SHRANK/zero direction — the live-balance-GREW direction is the new L-14 (announced-vs-executed drift). Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
