# [CARRYOVER] L-07 — setRoute accepts tokenIn == tokenOut and paths with internal zero-gap segments — relies entirely on off-chain verification

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AMMAdapters/CurveAMMAdapter.sol#L62-L89` (`setRoute`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-12
- **Original report:** [reports/reflax-yield-vault/07/findings/low/L-07.json](../../../07/findings/low/L-07.json)
- **Fingerprint:** `b28e77daefb3252934e24269b930a8438e5580e4c23a1bd1e677d5e63f3c75cc`

**Run-12 update (no new finding):** Re-surfaced this run by **DEDUP-008** — `setRoute`
endpoint-only validation (swapParams coin indices, pools array, and reverse-route
inverse-consistency are unvalidated on-chain). Same root cause as this entry (incomplete
on-chain route validation; blast radius bounded because Curve Router NG reverts a genuinely
invalid route and minOut floors every swap). **Note:** the Slither `lastToken`
uninitialized-local sub-flag bundled with DEDUP-008 is dismissed as a **false positive**
(CODE-004), which reconciles ledger **L-10** to false-positive this run. Severity/status of
L-07 unchanged.

See the original report for the full description, impact, attack path, and recommendation.
