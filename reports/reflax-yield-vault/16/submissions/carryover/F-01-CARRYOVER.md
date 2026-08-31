# [CARRYOVER] F-01 — story-043 'provable solvency invariant' overstated (ERC4626 double round-down)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Faithfulness
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L207-L210` (`_creditedPrincipal`); adjacency on sibling `ERC4626YieldStrategy._disposeShares` requested-write-down this run
- **First seen:** reflax-yield-vault-12  ·  **Still present as of:** reflax-yield-vault-16
- **Original report:** [reports/reflax-yield-vault/12/findings/faithfulness/F-01-provable-solvency-invariant-overstated.json](../../../12/findings/faithfulness/F-01-provable-solvency-invariant-overstated.json)
- **Fingerprint:** `ec9191e4…`

Adjacent to this run's sibling-file `_disposeShares` ignored-return + requested-write-down signal (intended protocol-favoring). DISTINCT from the new ECON-A (L-16) value leg, which is a different contract+function+rootCauseClass (fee-blind convertToAssets, not double-round-down). lastSeenRun bumped; severity/status unchanged.

See the original report for the full description, impact, and recommendation.
