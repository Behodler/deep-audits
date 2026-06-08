# [CARRYOVER] L-01-run11 — CEI violation in deposit/withdraw: state updates occur after external swap/transfer (latent reentrancy exposure)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L338-L375` (`_withdrawInternal` / `_depositInternal`)
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-12
- **Original report:** [reports/reflax-yield-vault-11/findings/low/L-01-cei-violation-withdraw-internal.json](../../../reflax-yield-vault-11/findings/low/L-01-cei-violation-withdraw-internal.json)
- **Fingerprint:** `3ab43381ffaf861f4cd5b1f25e1a8d4b9e709b1c9e53b2dfddda42c62fdf2a5d`

**Run-12 update (no new finding):** Re-surfaced this run by **DEDUP-009** — state written
after the external swap/transfer. **Refuted as exploitable** under the non-hooked-ERC20
trust model (OZ `nonReentrant` on all callers; the only external calls in the stale window
are to the trusted Curve adapter and to plain ERC20 transfer/transferFrom of non-hooked
tokens, so there is no attacker callback and read-only reentrancy against the unguarded
views is unreachable). Retained per Law-1 recall as a documented latent assumption that
becomes live only if a transfer-hook/FoT/ERC777 token is ever wired in. The six consolidated
Slither/Aderyn reentrancy flags (STATIC-006/007/012/013/014) are the Tier-1 precursors of
the same pattern. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
