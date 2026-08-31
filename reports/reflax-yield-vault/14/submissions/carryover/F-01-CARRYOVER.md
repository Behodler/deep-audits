# [CARRYOVER] F-01 — story-043 "provable solvency invariant" overstated: ERC4626 double round-down can leave convertToAssets(convertToShares(creditedPrincipal)) a few wei below creditedPrincipal

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Faithfulness (spec-conformance)
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L207-L210` (`_depositInternal` / `_creditedPrincipal`)
- **First seen:** reflax-yield-vault-12  ·  **Still present as of:** reflax-yield-vault-14
- **Original report:** [reports/reflax-yield-vault/12/findings/faithfulness/F-01-provable-solvency-invariant-overstated.json](../../../12/findings/faithfulness/F-01-provable-solvency-invariant-overstated.json)
- **Fingerprint:** `ec9191e4…`

Re-observed this run via DEDUP-CAR-003 (un-regressed faithfulness carryover; not re-triggered by changed files this run). Reported in the spec-conformance channel, not the QA bundle. Severity/status unchanged.

See the original report for the full description, impact, and recommendation.
