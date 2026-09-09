# [CARRYOVER] L-03 — No aggregate cap on per-client buffer percentages (total set-aside can reach 100% of underlyingReceived)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AYieldStrategy.sol#L253-L259` (`setSetAsideBuffer`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-08
- **Original report:** [reports/reflax-yield-vault/07/findings/low/L-03.json](../../../07/findings/low/L-03.json)
- **Fingerprint:** `1a4e3e8f…`

**Run-08 update (no new finding):** story-043 did not change the per-client buffer
aggregate-cap gap. This run's DEDUP-004 (buffer front-run amplification) was a
duplicate that consolidates into this entry; the cross-client-principal angle was
already adjudicated false-positive under M-04. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
