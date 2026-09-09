# [CARRYOVER] L-07 — replaceDispatcher() carries stale per-index price to a new dispatcher whose primeToken may have different decimals (price re-denomination)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/NFTMinterV2.sol#L227-L247` (`replaceDispatcher`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../../10/submissions/qa-report.md)
- **Fingerprint:** `ac91a046…`
- **Run-17 note:** Not re-scanned this run (NFTMinterV2 outside the story-044 slice). Remains open; same decimal-config family as L-10 (cross-ref, not merged). lastSeenRun unchanged (yield-claim-nft-12).

See the original report for the full description, impact, attack path, PoC, and recommendation.
