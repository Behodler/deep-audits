# [CARRYOVER] F-01 / L (`4f143a95`) — Migration credit asymmetry: `batchMigrate` books users below principal via a haircutting destination

> **Carryover stub, not new analysis.** Reported in a prior run, still **open** at HEAD `ffa4947`.
> This run ([story-012] InPlaceMigrator, new contract) did **not** touch `batchMigrate`/`depositFor`
> internals. Reproduced so it is not lost between runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `4f143a95`
- **Severity:** Low (faithfulness, F-01) · **Status:** open
- **Location:** `src/StableStaker.sol` — `batchMigrate` (L429-450); `StableStakerMigrator.migrate` (L76-80)
- **First seen:** stable-staker-07 · **Still present as of:** stable-staker-12
- **Original report:** [reports/stable-staker/07/submissions/spec-conformance.md](../../../07/submissions/spec-conformance.md)

**Cross-ref (run-12):** Adjacent deposit-side asymmetry. Distinct from this run's new `ss12m1`
(`970d7307`, InPlaceMigrator re-injection haircut), which is the in-place-migration re-credit leg.

See the original report for full description, impact, and recommendation.
