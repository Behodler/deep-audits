# [CARRYOVER] V3-H-01 — PhlimboV3 promo Flushing-window accPromoPerShare over-credit steals co-stakers' promo tokens (or DoS)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is triaged **fix-pending** (a fix is owed and not yet verified as
> complete). It is reproduced here so it is not lost between runs. Triage/close it
> with `/ledger phlimbo-ea`.

- **Severity:** High (Plausible-High)
- **Status:** fix-pending (fix owed, not yet verified)
- **Location:** `src/PhlimboV3.sol#L559-L573` (`collectReward`/`_updatePool`)
- **First seen:** phlimbo-ea-07  ·  **Still present as of:** phlimbo-ea-10
- **Original report:** [reports/phlimbo-ea-07/audit/submissions/H-01-promo-flush-overcredit.md](../../../phlimbo-ea-07/audit/submissions/H-01-promo-flush-overcredit.md)
- **Fingerprint:** `88ae7589…`

**Run-10 re-verification:** the Flushing accrual-freeze gate was verified **INTACT** at HEAD
`e32588d` (accrual gated during Flushing at :834/:992) — no re-surface, no regression. The
run-08/run-09 proposals to mark this `fixed` remain **UNAPPLIED**; status left `fix-pending`
until a human confirms. Distinct from the acknowledged V1 Linear-Depletion (ledger M-04) — do
not collapse.

See the original report for the full description, impact, attack path, PoC, and recommendation.
