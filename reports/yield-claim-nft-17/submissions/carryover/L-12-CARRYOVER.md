# [CARRYOVER] L-12 — Pausing the dispatcher does not freeze custody: release()/rescueERC20() are not whenNotPaused, so held USDC can still leave during a pause (Law-3 footgun)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/dispatchers/NudgeRatchetDelayRelease.sol#L108-L121` (`release / rescueERC20 vs dispatch`)
- **First seen:** yield-claim-nft-15  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft-15/submissions/qa-report.md](../../yield-claim-nft-15/submissions/qa-report.md)
- **Fingerprint:** `d9d8e16a…`
- **Run-17 note:** Not re-scanned this run (NudgeRatchetDelayRelease outside the story-044 slice). Remains open; funds conserved to owner-pinned batchMinter sink, non-obvious semantic gap kept at Low. Cross-refs L-04 (family, not merged). lastSeenRun unchanged (yield-claim-nft-16).

See the original report for the full description, impact, attack path, PoC, and recommendation.
