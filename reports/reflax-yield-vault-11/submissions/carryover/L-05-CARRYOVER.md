# [CARRYOVER] L-05 — SurplusSkimmed event under-represents the buffered-path beneficiaries — no event records per-client buffer redirection

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (carryover — not re-triggered in run-11)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L484-L519` (`_accrueSurplusShares / _distributeBuffer`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-11
- **Original report:** [reports/reflax-yield-vault-07/findings/low/L-05.json](../../../reflax-yield-vault-07/findings/low/L-05.json)
- **Fingerprint:** `efcdb9dc8ff03289a0ef572082f634335c18338c09c5a6afbe9e10c1ecb0ee86`

**Carryover note:** L-05 was not re-triggered by any finding in this scan run. DEDUP-014 (WithdrawalExecuted event emits cached balance) and DEDUP-015 (withdrawAsOwner event missing client field) are both event-quality findings but cover different events and different functions from L-05. The SurplusSkimmed / _distributeBuffer event opacity issue is not covered by any finding in this run. Last confirmed open at run-07. Use `/recheck reflax-yield-vault L-05` if targeted verification is needed.

See the original report for the full description, impact, attack path, and recommendation.
