# [CARRYOVER] L-03-run11 — emergencyWithdraw lacks nonReentrant guard

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AYieldStrategy.sol#L304` (`emergencyWithdraw`); concrete `_emergencyWithdraw` on `ERC4626YieldStrategy.sol#L148-L170` this run
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-16
- **Original report:** [reports/reflax-yield-vault/11/findings/low/L-03-emergency-withdraw-no-reentrancy-guard.json](../../../11/findings/low/L-03-emergency-withdraw-no-reentrancy-guard.json)
- **Fingerprint:** `c97b6a93…`

Re-flagged this run on the newly-in-scope sibling `ERC4626YieldStrategy._emergencyWithdraw` (no `nonReentrant`, consistent with the original observation on the base). lastSeenRun bumped; severity/status unchanged (Low).

See the original report for the full description, impact, attack path, and recommendation.
