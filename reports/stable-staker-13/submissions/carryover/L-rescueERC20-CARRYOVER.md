# [CARRYOVER] L-rescueERC20 — rescueERC20 can sweep the buffer backing underwater withdrawals

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L702-L709` (`rescueERC20`)
- **First seen:** stable-staker-01  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 touches InPlaceMigrator only; StableStaker.rescueERC20 can still sweep the buffer backing underwater withdrawals.
- **Original report:** [reports/stable-staker-01/submissions/qa-report.md](../../../stable-staker-01/submissions/qa-report.md)
- **Fingerprint:** `0790a76a…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
