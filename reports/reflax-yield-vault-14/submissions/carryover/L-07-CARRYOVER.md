# [CARRYOVER] L-07 — setRoute accepts tokenIn == tokenOut and paths with internal zero-gap segments (relies on off-chain verification)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AMMAdapters/CurveAMMAdapter.sol#L62-L89` (`setRoute`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-14
- **Original report:** [reports/reflax-yield-vault-07/findings/low/L-07.json](../../../reflax-yield-vault-07/findings/low/L-07.json)
- **Fingerprint:** `b28e77da…`

Re-observed this run via DEDUP-COL-006 (SLITHER-003): `setRoute` endpoint-only validation — swapParams coin indices, pools array, and reverse-route inverse-consistency are unvalidated on-chain. The bundled `lastToken` uninitialized-local sub-flag is a separate false positive (CODE-004, tracked as L-10 false-positive) and does not reopen here. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
