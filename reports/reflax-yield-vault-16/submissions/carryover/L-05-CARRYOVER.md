# [CARRYOVER] L-05 — SurplusSkimmed event under-represents buffered-path beneficiaries

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L484-L519` (`_accrueSurplusShares` / `_distributeBuffer`); sibling `ERC4626YieldStrategy.sol#L310-L329` this run
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-16
- **Original report:** [reports/reflax-yield-vault-07/findings/low/L-05.json](../../../reflax-yield-vault-07/findings/low/L-05.json)
- **Fingerprint:** `efcdb9dc…`

Re-observed this run on the newly-in-scope sibling `ERC4626YieldStrategy._distributeBuffer` global-recipient transfer (same missing-event-detail surface; folds with L-15/F-04). lastSeenRun bumped; severity/status unchanged (Low).

See the original report for the full description, impact, attack path, and recommendation.
