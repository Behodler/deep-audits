# [CARRYOVER] L-03 — No aggregate cap on per-client buffer percentages allows total set-aside to reach 100% of underlyingReceived, reducing recipient take to zero with no revert

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (carryover — not re-triggered in run-11)
- **Location:** `src/AYieldStrategy.sol#L253-L259` (`setSetAsideBuffer`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-11
- **Original report:** [reports/reflax-yield-vault/07/findings/low/L-03.json](../../../07/findings/low/L-03.json)
- **Fingerprint:** `1a4e3e8f13bdc492fee2dc6df6a0b214432e156195e781cd45fdae1ea32d700c`

**Carryover note:** L-03 was not re-triggered by any finding in this scan run. DEDUP-018 (deposit dilution) shares the same function area but has a different root cause (proportional surplus dilution vs. missing buffer aggregate cap). L-03 was last confirmed open at run-08; story-043 did not address setSetAsideBuffer. This carryover indicates the issue persists as acknowledged-open in likely-unchanged code. Use `/recheck reflax-yield-vault L-03` if targeted verification is needed.

See the original report for the full description, impact, attack path, and recommendation.
