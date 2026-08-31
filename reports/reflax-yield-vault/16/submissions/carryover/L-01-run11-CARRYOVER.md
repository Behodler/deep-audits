# [CARRYOVER] L-01-run11 — CEI violation in _withdrawInternal (state updates after external calls)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L338-L375` (`_withdrawInternal`); mirrored on `ERC4626YieldStrategy.sol#L194` (`_totalWithdraw`) this run
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-16
- **Original report:** [reports/reflax-yield-vault/11/findings/low/L-01-cei-violation-withdraw-internal.json](../../../11/findings/low/L-01-cei-violation-withdraw-internal.json)
- **Fingerprint:** `3ab43381…`

Re-flagged this run as the same CEI class on the newly-in-scope `ERC4626YieldStrategy._totalWithdraw` (state written after `vault.redeem`). Benign under the non-hooked-ERC20 trust model (`nonReentrant` + `onlyOwner` + `whenNotPaused`); no diff lines touch this path. lastSeenRun bumped; severity/status unchanged (Low).

See the original report for the full description, impact, attack path, and recommendation.
