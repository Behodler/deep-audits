# [CARRYOVER] L-03 — Nudge-token equality guard reverts even when nudge is size-disabled

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-nft-staking`.

- **Severity:** Low
- **Status:** open (still-open / submitted)
- **Location:** `src/BatchNFTMinter.sol#L230-L233` (`batchMint`)
- **First seen:** phoenix-nft-staking-12  ·  **Still present as of:** phoenix-nft-staking-16
- **Original report:** [reports/phoenix-nft-staking/12/submissions/qa-report.md](../../../12/submissions/qa-report.md)
- **Fingerprint:** `58b6c486…`

Not independently re-flagged by any tier this run, but the ledger records it as still live at
HEAD 5f863d2 (unchanged by story-016). Stub written so this open finding does not silently vanish
from this run's `submissions/`. QA/INFO usability nit; no severity change.

See the original report for the full description, impact, attack path, PoC, and recommendation.
