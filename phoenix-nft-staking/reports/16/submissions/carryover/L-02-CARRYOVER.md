# [CARRYOVER] L-02 — Uncapped count loop in batchMint

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-nft-staking`.

- **Severity:** Low
- **Status:** open (still-open / submitted)
- **Location:** `src/BatchNFTMinter.sol#L238-L240` (`batchMint`)
- **First seen:** phoenix-nft-staking-12  ·  **Still present as of:** phoenix-nft-staking-16
- **Original report:** [reports/phoenix-nft-staking/12/submissions/qa-report.md](../../../12/submissions/qa-report.md)
- **Fingerprint:** `e35388bf…`

Re-confirmed this run at HEAD 5f863d2; the unbounded caller-supplied `count` loop is unchanged.
Impact stays self-bounded (oversized `count` reverts the caller's own tx — self-DoS only, no
third-party impact). No severity change.

See the original report for the full description, impact, attack path, PoC, and recommendation.
