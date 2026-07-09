# [CARRYOVER] L-12 — Pausing the dispatcher does not freeze custody: release()/rescueERC20() are not whenNotPaused

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged away). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low (Law-3 operational footgun, in scope)
- **Status:** open (re-confirmed still-open at f46a5cb in run-16)
- **Location:** `src/dispatchers/NudgeRatchetDelayRelease.sol#L108-L121` (`release` / `rescueERC20` vs `dispatch`)
- **First seen:** yield-claim-nft-15  ·  **Still present as of:** yield-claim-nft-16
- **Original report:** [reports/yield-claim-nft-15/submissions/qa-report.md](../../yield-claim-nft-15/submissions/qa-report.md)
- **Fingerprint:** `d9d8e16a…`
- **Run-16 note:** KI-4/KI-5 grant trust for the pause *action* but do not bless the non-obvious pause≠custody-freeze semantic gap — retained Low, not suppressed. Funds conserved to owner-pinned batchMinter sink. Cross-refs OPEN L-04 (not merged).

See the original report for the full description, impact, attack path, and recommendation.
