# [CARRYOVER] L-06 — pauseWithdraw silently forfeits accrued rewards with no event and orphans per-share-accumulator residue

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open carryover; flagged partial-match-KI-4)
- **Location:** `src/Phlimbo.sol#L245-L261` (`pauseWithdraw`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea/03/audit/findings/low/L-06-pauseWithdraw-silent-forfeiture-and-orphan-redistribution.json](../../../../03/audit/findings/low/L-06-pauseWithdraw-silent-forfeiture-and-orphan-redistribution.json)
- **Fingerprint:** `e7c217bc…`

> This carries the BLESSED forfeiture framing (KI-4). The non-obvious downstream
> escalations — the stale-debt brick (this run's M-02 = ledger M-01) and the phUSD
> over-mint (this run's M-04, new) — are tracked as separate in-scope findings.

See the original report for the full description, impact, attack path, PoC, and recommendation.
