# [CARRYOVER] L-06 — skimSurplus return-value semantics are path-dependent — fast path returns swap output, buffered path returns recipient-receipt; NatSpec leaves room for integrator confusion

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (carryover — not re-triggered in run-11)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L432-L521` (`_skimSurplus / _distributeBuffer`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-11
- **Original report:** [reports/reflax-yield-vault/07/findings/low/L-06.json](../../../07/findings/low/L-06.json)
- **Fingerprint:** `0f534a726502d2747df9b13c64fe0cebf046433a6b5a039866d8f407f3f198a3`

**Carryover note:** L-06 was not re-triggered by any finding in this scan run. DEDUP-017 covers vault oracle intra-tx rate drift in _skimSurplus (reported as L-09 this run), which is a different root cause (price source staleness vs. return-value semantic inconsistency). The path-dependent return-value issue is not covered by any finding in this run. Last confirmed open at run-07. Use `/recheck reflax-yield-vault L-06` if targeted verification is needed.

See the original report for the full description, impact, attack path, and recommendation.
