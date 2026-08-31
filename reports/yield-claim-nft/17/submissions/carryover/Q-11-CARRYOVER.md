# [CARRYOVER] Q-11 — Delay-release variant drops the sibling NudgeRatchet's in-contract require(bal >= amount) backing tripwire from _dispatch (latent under non-default setMinter repoint)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** QA
- **Status:** open (still-open)
- **Location:** `src/dispatchers/NudgeRatchetDelayRelease.sol#L131-L143` (`_dispatch`)
- **First seen:** yield-claim-nft-15  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft/15/submissions/qa-report.md](../../../15/submissions/qa-report.md)
- **Fingerprint:** `205afcf0…`
- **Run-17 note:** Not re-scanned this run (NudgeRatchetDelayRelease outside the story-044 slice). Remains open; kept deliberately SEPARATE from suppressed DEDUP-001 (narrower in-contract on-chain assertion, not the external phUSD backing model). lastSeenRun unchanged (yield-claim-nft-16).

See the original report for the full description, impact, attack path, PoC, and recommendation.
