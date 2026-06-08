# [CARRYOVER] L-01 — slippageToleranceBps default-0 plus setter missing sane cap (missing validation)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195` (`setSlippageTolerance`)
- **First seen:** reflax-yield-vault-05  ·  **Still present as of:** reflax-yield-vault-12
- **Original report:** [reports/reflax-yield-vault-05/submissions/qa-report.md](../../../reflax-yield-vault-05/submissions/qa-report.md)
- **Fingerprint:** `6460e35331dff5c220d596a134d4f71e1ce0c53b6bfd3b0b5f48edf97307b286`

**Run-12 update (no new finding):** Re-surfaced this run by **DEDUP-004** (overloaded
`slippageToleranceBps` haircuts credited principal as well as swap minOut, no sane upper
cap — non-obvious owner footgun at moderate tolerance) and **DEDUP-006** (zero-default
demands full vault-rate execution, so deposits/withdraws revert until the owner sets a
non-zero tolerance — fails-closed deploy footgun). Both map to this single ledger entry;
the MAX_BPS-zeroes-principal extreme is the obvious-misconfig owner-power sub-case tracked
under C-01, not this Low. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
