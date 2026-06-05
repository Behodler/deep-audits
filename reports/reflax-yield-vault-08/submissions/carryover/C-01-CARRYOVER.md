# [CARRYOVER] C-01 — Centralization / owner-power bundle

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Centralization (QA)
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (multiple owner setters: setRoute, setSlippageTolerance, depositAsOwner, withdrawAsOwner, emergencyWithdraw, setClient, setSetAsideBuffer, skim, two-phase totalWithdrawal)
- **First seen:** reflax-yield-vault-05  ·  **Still present as of:** reflax-yield-vault-08
- **Original report:** [reports/reflax-yield-vault-05/submissions/qa-report.md](../../reflax-yield-vault-05/submissions/qa-report.md)
- **Fingerprint:** `679c917d…`

**Run-08 update (no new finding):** story-043's conservative-crediting haircut binds
owner-controlled `slippageToleranceBps` to deposit-side credited principal as well as
swap minOut, broadening the owner-power envelope. The uncapped `setSlippageTolerance`
setter remains the locus (tracked in detail under L-01). Extended by L-03/L-04/L-07.
Severity/status unchanged.

See the original report for the full description, impact, and recommendation.
