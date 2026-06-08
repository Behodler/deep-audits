# [CARRYOVER] L-03 — claim() NatSpec says pay-then-skim; code skims-then-pays (doc/impl mismatch)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger stable-yield-accumulator`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableYieldAccumulator.sol#L426-L434` (`claim` NatSpec) + `src/interfaces/IStableYieldAccumulator.sol#L314-L336`
- **First seen:** stable-yield-accumulator-11  ·  **Still present as of:** stable-yield-accumulator-12
- **Original report:** [reports/stable-yield-accumulator-11/findings.json](../../../stable-yield-accumulator-11/findings.json)
- **Fingerprint:** `7e6197ae…`

Re-confirmed this run (DEDUP-005 / CODE-003 at HEAD 71abe3e). **EXTENDED by F-01**
(story-faithfulness): beyond the known ordering drift, the NatSpec documents a *direct
claimer->phlimbo* transfer, but story-023's nudge split routes claimer->this then nudge
`safeTransfer` + phlimbo `collectReward` pull. The faithfulness facet is captured in
`findings/faithfulness/F-01-claim-natspec-payment-destination-drift.json` and routed to
`submissions/spec-conformance.md` (separate from the QA bundle). Documentation/spec-conformance
only — atomic (`nonReentrant` + `whenNotPaused`), value conservation holds. No severity change.

See the original report for the full description, impact, attack path, PoC, and recommendation.
