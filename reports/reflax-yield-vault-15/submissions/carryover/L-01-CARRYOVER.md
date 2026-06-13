# [CARRYOVER] L-01 — slippageToleranceBps default-0 plus setter missing sane cap (missing validation)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195` (`setSlippageTolerance`)
- **First seen:** reflax-yield-vault-05  ·  **Still present as of:** reflax-yield-vault-15
- **Original report:** [reports/reflax-yield-vault-05/submissions/qa-report.md](../../../reflax-yield-vault-05/submissions/qa-report.md)
- **Fingerprint:** `6460e353…`

Re-observed this run via DEDUP-15-003 (ECON-001): the global `slippageToleranceBps` couples withdrawal/skim slippage floors to deposit principal-credit — temporarily raising tolerance to clear an operational withdrawal silently haircuts concurrent depositors' credited principal, bounded only by the still-missing cap. Ledger entry enriched with this blast-radius note + safe-config guidance (cap `setSlippageTolerance` well below MAX_BPS, e.g. <= 1000, and pause deposits before temporarily raising tolerance). Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
