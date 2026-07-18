# [CARRYOVER] L-04 — Privileged mintFor()/burn() ignore global paused + per-index disabled flags

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/NFTMinterV2.sol#L206-L214` (`mintFor / burn`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft-10/submissions/qa-report.md](../../yield-claim-nft-10/submissions/qa-report.md)
- **Fingerprint:** `49fb985f…`
- **Run-17 note:** Not re-scanned this run (NFTMinterV2 is outside the run-17 story-044 slice, which covered only the new PromotionUniV2_Eth dispatcher). Remains open; cross-referenced by L-12 as the 'privileged path ignores pause' family. lastSeenRun unchanged (yield-claim-nft-12).

See the original report for the full description, impact, attack path, PoC, and recommendation.
