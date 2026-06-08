# [CARRYOVER] L-04-run11 — nonReentrant is not the first modifier across 6 entry points (defense-in-depth note)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AYieldStrategy.sol` + `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L229-L366` (`totalWithdrawal`, `skimSurplus`, `deposit`, `withdraw`, `depositAsOwner`, `withdrawAsOwner` — lines 319, 366; 229, 248, 265, 279)
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-12
- **Original report:** [reports/reflax-yield-vault-11/findings/low/L-04-nonreentrant-modifier-ordering.json](../../../reflax-yield-vault-11/findings/low/L-04-nonreentrant-modifier-ordering.json)
- **Fingerprint:** `46ab675c76e9f7d7dc97e841f495efcdbb02bbb9473ceb903c78c1c3fa5ba884`

**Run-12 update (no new finding):** Re-surfaced this run by **DEDUP-013** across the same
6 functions/lines. Defense-in-depth/ordering-style note only: every preceding modifier is a
no-external-call auth/access check (`onlyOwner` / `onlyAuthorizedClient` /
`onlyAuthorizedWithdrawer`), so the reentrancy guard is effectively engaged before any
external interaction — no live reentrancy window. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
