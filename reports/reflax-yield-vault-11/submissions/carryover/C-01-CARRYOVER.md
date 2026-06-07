# [CARRYOVER] C-01 — Centralization / owner-power bundle

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Centralization
- **Status:** open (carryover — not re-triggered as a standalone finding in run-11)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (multiple: setRoute, setSlippageTolerance, depositAsOwner, withdrawAsOwner, emergencyWithdraw, setClient, setSetAsideBuffer, skim, totalWithdrawal)
- **First seen:** reflax-yield-vault-05  ·  **Still present as of:** reflax-yield-vault-11
- **Original report:** [reports/reflax-yield-vault-05/submissions/qa-report.md](../../../reflax-yield-vault-05/submissions/qa-report.md)
- **Fingerprint:** `679c917dabcb60af68eb46593ab6acc7ef62c12f86522ac3b767203cabdd3856`

**Carryover note:** C-01 as a broad centralization bundle was not re-triggered as a standalone finding this run. However, DEDUP-003 (withdrawAsOwner timelock bypass, reported as H-03 this run) and DEDUP-015 (withdrawAsOwner event opacity, reported as L-07 this run) are new findings that constitute concrete sub-elements of the C-01 owner-power envelope. They are reported as distinct new findings because their root causes and remediations are specific and independently reportable. The broad C-01 bundle (documenting the aggregate owner-power surface) remains open; run-11 new findings expand the concrete impact examples within C-01's scope. Last confirmed open at run-08.

See the original report for the full description, impact, and recommendation.
