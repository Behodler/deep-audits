# [CARRYOVER] V3-M-01 — MigratorV2V3 reverting/blocklisted reward recipient bricks the V2→V3 migration chunk

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is triaged **fix-pending** (a fix is owed and not yet verified as
> complete). It is reproduced here so it is not lost between runs. Triage/close it
> with `/ledger phlimbo-ea`.

- **Severity:** Medium
- **Status:** fix-pending (fix owed, not yet verified)
- **Location:** `src/MigratorV2V3.sol#L186-L194` (`migrate`/`seedUsers`/`withdrawAll`)
- **First seen:** phlimbo-ea-07  ·  **Still present as of:** phlimbo-ea-10
- **Original report:** [reports/phlimbo-ea/07/audit/submissions/M-01-migrator-reverting-recipient-brick.md](../../../07/audit/submissions/M-01-migrator-reverting-recipient-brick.md)
- **Fingerprint:** `0b7fa9be…`

**Run-10 re-verification:** the reverting-recipient brick **mitigation** (`_tryTransfer` + bank +
try/catch on the forward loop) was verified **INTACT** at HEAD `e32588d` — no re-surface, no
regression. The prior proposal to mark this `fixed` remains **UNAPPLIED**; status left
`fix-pending` until a human confirms. Spec-conformance cross-ref: V3-F-01.

See the original report for the full description, impact, attack path, PoC, and recommendation.
