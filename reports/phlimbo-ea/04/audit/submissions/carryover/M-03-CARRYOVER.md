# [CARRYOVER] M-03 — phUSD mint authority is load-bearing for solvency; revocation/pause/supply-cap bricks claim/stake/withdraw without graceful degradation

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Medium
- **Status:** open (still-open carryover; flagged partial-match-KI-7)
- **Location:** `src/Phlimbo.sol#L432-L455` (`_claimRewards`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea/03/audit/findings/medium/M-03-phUSD-mint-revocation-bricks-claim.json](../../../../03/audit/findings/medium/M-03-phUSD-mint-revocation-bricks-claim.json)
- **Fingerprint:** `d3a0c800…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
