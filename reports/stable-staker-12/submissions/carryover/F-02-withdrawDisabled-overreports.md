# [CARRYOVER] F-02 / L (`a56f8778`) — `withdrawDisabled` view over-reports raw `_isUnderwater` after story-002 added the buffer path

> **Carryover stub, not new analysis.** Reported in a prior run, still **open** at HEAD `ffa4947`.
> This run ([story-012] InPlaceMigrator, new contract) did **not** touch `withdrawDisabled`.
> Reproduced so it is not lost between runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `a56f8778`
- **Severity:** Low/QA (faithfulness, F-02) · **Status:** open
- **Location:** `src/StableStaker.sol` — `withdrawDisabled` (L594-600)
- **First seen:** stable-staker-07 · **Still present as of:** stable-staker-12
- **Original report:** [reports/stable-staker-07/submissions/spec-conformance.md](../../../stable-staker-07/submissions/spec-conformance.md)

See the original report for full description, impact, and recommendation.
