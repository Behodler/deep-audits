# [CARRYOVER] L-10 — UniboostMintDebtHook.scale derived from the hook's own ctor primeToken_ with no on-chain tie to the dispatcher primeToken(); decimals mismatch mis-scales all debt

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/hooks/UniboostMintDebtHook.sol#L85-L89` (`constructor`)
- **First seen:** yield-claim-nft-13  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft-13/submissions/qa-report.md](../../yield-claim-nft-13/submissions/qa-report.md)
- **Fingerprint:** `e064b2de…`
- **Run-17 note:** Not re-scanned this run (UniboostMintDebtHook outside the story-044 slice). Remains open; deploy-config footgun, over-scale direction mints unbacked phUSD (Law-1 tail) — kept. lastSeenRun unchanged (yield-claim-nft-13).

See the original report for the full description, impact, attack path, PoC, and recommendation.
