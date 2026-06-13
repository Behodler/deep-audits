# [CARRYOVER] L-06-run11 — WithdrawalExecuted event emits the Phase-1 cached balance rather than the actual amount transferred

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/AYieldStrategy.sol#L501` (`_executeWithdrawal`)
- **First seen:** reflax-yield-vault-11  ·  **Still present as of:** reflax-yield-vault-15
- **Original report:** [reports/reflax-yield-vault-11/findings/low/L-06-withdrawal-executed-event-stale-amount.json](../../../reflax-yield-vault-11/findings/low/L-06-withdrawal-executed-event-stale-amount.json)
- **Fingerprint:** `f9194462…`

Re-observed this run as a compounding adjacency of new L-14 (DEDUP-15-001): because `WithdrawalExecuted` emits the stale announced figure, on-chain observers cannot detect the announced-vs-executed drift L-14 documents. Fixing this event to emit the actual swept amount is part of L-14's recommendation. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
