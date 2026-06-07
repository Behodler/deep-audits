# [CARRYOVER] L-07 — setRoute accepts tokenIn == tokenOut and paths with internal zero-gap segments — relies entirely on off-chain verification

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (carryover — not re-triggered in run-11)
- **Location:** `src/AMMAdapters/CurveAMMAdapter.sol#L62-L89` (`setRoute`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-11
- **Original report:** [reports/reflax-yield-vault-07/findings/low/L-07.json](../../../reflax-yield-vault-07/findings/low/L-07.json)
- **Fingerprint:** `b28e77daefb3252934e24269b930a8438e5580e4c23a1bd1e677d5e63f3c75cc`

**Carryover note:** L-07 was not re-triggered by any finding in this scan run. DEDUP-009 covers a distinct sub-issue within the same function (uninitialized local lastToken, reported as L-10 this run) but has a different root cause and remediation from L-07 (tokenIn==tokenOut validation + zero-gap segments). The L-07 root cause was not re-detected by static or code scanners this run. CurveAMMAdapter.sol was noted as unchanged between story-042 commits; this pattern likely persists. Use `/recheck reflax-yield-vault L-07` if targeted verification is needed.

See the original report for the full description, impact, attack path, and recommendation.
