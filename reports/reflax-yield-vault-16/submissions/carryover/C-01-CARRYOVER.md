# [CARRYOVER] C-01 — Centralization / owner-power bundle

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Centralization
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (multiple owner setters; also `ERC4626YieldStrategy.sol` sibling)
- **First seen:** reflax-yield-vault-05  ·  **Still present as of:** reflax-yield-vault-16
- **Original report:** [reports/reflax-yield-vault-05/submissions/qa-report.md](../../../reflax-yield-vault-05/submissions/qa-report.md)
- **Fingerprint:** `679c917d…`

Re-observed this run on the newly-in-scope `ERC4626YieldStrategy.sol` sibling: the `_emergencyWithdraw` no-ledger-update desync (ERC4626YieldStrategy.sol:148-170) folds into the C-01 envelope (the H-01 downgraded-to-centralization property — NOT re-filed at High), and the `actualAmount` dust-strand (:165-169) is folded one-line into C-01. lastSeenRun bumped; narrative-only, no status change.

See the original report for the full description, impact, attack path, and recommendation.
