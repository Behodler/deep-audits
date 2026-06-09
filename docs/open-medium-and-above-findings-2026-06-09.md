# Open Medium-and-Above Findings — 2026-06-09

Scope: all registered projects except `phoenix-phase-2-staging`.
Filter: severity **Medium and above**, status **untriaged (open)** or **acknowledged/will-fix**.
Excluded: won't-fix, rejected, false-positive, merged, downgraded-to-centralization, and fixed/closed entries; phlimbo-ea V1 (deprecated). Centralization-severity items are below the bar and not listed.

No **High** findings survive the filter — every High was fixed, downgraded to centralization, or ruled false-positive. All survivors are **Medium**.

| Ref ID | Project | Label | Sev | Status | Title |
|--------|---------|-------|-----|--------|-------|
| `d7f6c2df` | reflax-yield-vault | M-02 | Med | acknowledged | NAV-anchored `minOut` is execution-price-blind → sandwich value leak |
| `dab5a656` | stable-staker | M-01 | Med | submitted (live) | Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers |
| `0dca43f3` | stable-staker | M-05 | Med | acknowledged | `emergencyWithdraw` realizes underwater loss FCFS (bufferless par bank-run) |
| `dbdc3ac9` | stable-staker | M-06 | Med | acknowledged (will-fix) | `setYieldStrategy` underwater-swap silently lifts the withdraw block, FCFS-concentrates loss |
| `sya12m1` | stable-yield-accumulator | M-01 | Med | acknowledged | Unconfigured non-18-dec token treated 1:1 (fail-open) → drain or brick |
