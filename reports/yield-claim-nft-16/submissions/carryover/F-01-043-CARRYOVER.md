# [CARRYOVER] F-01-043 — story-043 decouples phUSD-debt-realisation (at dispatch) from USDC-release (later)

> **This is a carryover stub, not new analysis.** This faithfulness / spec-conformance
> record was raised in a prior run and is **still open** (visible, not promoted, not buried).
> It is reproduced here so it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Informational (spec-conformance / faithfulness record — **NOT** a security Medium)
- **Status:** open (re-confirmed still-open at f46a5cb in run-16)
- **Location:** `src/dispatchers/NudgeRatchetDelayRelease.sol` (`_dispatch` / `release`)
- **First seen:** yield-claim-nft-15  ·  **Still present as of:** yield-claim-nft-16
- **Original report:** [reports/yield-claim-nft-15/submissions/spec-conformance.md](../../yield-claim-nft-15/submissions/spec-conformance.md)
- **Fingerprint:** `6753c76b…`
- **Run-16 note:** FAITHFUL to story-043 across all six acceptance criteria. The Law-1 solvency-window security escalation stays resolved OUT-OF-SCOPE under DEDUP-001 (external phUSD backing model); the faithfulness record is retained in a **visible** channel (Law-1 parked-in-visible-channel). Do **not** promote to a security Medium; do **not** bury.

See the original spec-conformance report for the full description and analysis.
