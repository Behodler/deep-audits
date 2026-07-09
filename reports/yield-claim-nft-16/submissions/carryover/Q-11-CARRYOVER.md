# [CARRYOVER] Q-11 — Delay-release variant drops the sibling NudgeRatchet's in-contract require(bal >= amount) backing tripwire

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged away). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** QA
- **Status:** open (re-confirmed still-LIVE at f46a5cb in run-16 — resolves MR-16-005)
- **Location:** `src/dispatchers/NudgeRatchetDelayRelease.sol#L131-L143` (`_dispatch`)
- **First seen:** yield-claim-nft-15  ·  **Still present as of:** yield-claim-nft-16
- **Original report:** [reports/yield-claim-nft-15/submissions/qa-report.md](../../yield-claim-nft-15/submissions/qa-report.md)
- **Fingerprint:** `205afcf0…`
- **Run-16 status re-check:** Verified `_dispatch` STILL omits `require(bal >= amount)`. The sibling's tripwire lives on `NudgeRatchet` (NudgeRatchet.sol:97), NOT on this DelayRelease variant, so Q-11 is **still live — NOT flipped to fixed**. Kept deliberately **SEPARATE** from suppressed DEDUP-001 (narrower in-contract on-chain assertion, not the external phUSD backing model).

See the original report for the full description, impact, and recommendation.
