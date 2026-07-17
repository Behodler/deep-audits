# [CARRYOVER] V3-L-11 — PhlimboV2 _claimRewards (:500): a reverting rewardToken.safeTransfer freezes staker principal on the self-service path -- NEUTRALIZED (not absent) by migrator routing

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV2.sol#L486-L507` (`_claimRewards`)
- **First seen:** phlimbo-ea-09  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea-09/submissions/qa-report.md](../../../phlimbo-ea-09/submissions/qa-report.md)
- **Fingerprint:** `b9de837c…`

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
