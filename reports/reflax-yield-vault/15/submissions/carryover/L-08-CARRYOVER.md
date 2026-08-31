# [CARRYOVER] L-08 — Ownable used instead of Ownable2Step across all three contracts

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AMMAdapters/CurveAMMAdapter.sol`, `src/AYieldStrategy.sol` (`constructor` / `transferOwnership`, L20)
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-15
- **Original report:** [reports/reflax-yield-vault/11/findings/low/L-08-ownable-single-step-ownership-transfer.json](../../../11/findings/low/L-08-ownable-single-step-ownership-transfer.json)
- **Fingerprint:** `207c3752…`

Re-observed this run via DEDUP-15-011 / SEMGREP-001/002 (exact match: single-step ownership transfer is irreversible if the new owner address is wrong). Severity/status unchanged.

See the original report for the full description, impact, and recommendation.
