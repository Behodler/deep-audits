# [CARRYOVER] L-03 — setDesiredAPY commit branch does not clear pendingAPYBps / pendingAPYBlockNumber

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open carryover)
- **Location:** `src/Phlimbo.sol#L163-L171` (`setDesiredAPY`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea-03/audit/findings/low/L-03-setDesiredAPY-pending-state-not-cleared.json](../../../../phlimbo-ea-03/audit/findings/low/L-03-setDesiredAPY-pending-state-not-cleared.json)
- **Fingerprint:** `ed76f5f1…`

> **Note on labels:** this is **ledger** label L-03 (setDesiredAPY pending-state-not-cleared),
> NOT this run's run-label L-03 (stable per-share rounding stranding, a NEW finding).
> Carryover stubs use ledger labels.

See the original report for the full description, impact, attack path, PoC, and recommendation.
