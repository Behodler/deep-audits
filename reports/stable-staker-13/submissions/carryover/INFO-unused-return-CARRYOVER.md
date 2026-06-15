# [CARRYOVER] INFO-unused-return — Unused return value of EnumerableSet.add/remove

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Informational
- **Status:** open (still-open)
- **Location:** `src/StableStaker.sol#L233-L361` (`add`)
- **First seen:** stable-staker-01  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** story-013 does not touch the EnumerableSet add/remove call sites; the unused-return-value hygiene note is unchanged.
- **Original report:** [reports/stable-staker-01/submissions/qa-report.md](../../../stable-staker-01/submissions/qa-report.md)
- **Fingerprint:** `7b071779…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
