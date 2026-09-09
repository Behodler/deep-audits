# [CARRYOVER] L-01-run11 — CEI violation in _withdrawInternal: state updates after two external calls (latent reentrancy exposure)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L338-L375` (`_withdrawInternal`)
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-14
- **Original report:** [reports/reflax-yield-vault/11/findings/low/L-01-cei-violation-withdraw-internal.json](../../../11/findings/low/L-01-cei-violation-withdraw-internal.json)
- **Fingerprint:** `3ab43381…`

Re-observed this run via DEDUP-COL-001 (CEI: state written after the external swap/transfer in the owner-gated `_totalWithdraw` twin). Refuted as exploitable under the non-hooked-ERC20 trust model (`nonReentrant` present, no attacker callback); retained as a documented latent assumption. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
