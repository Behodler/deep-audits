# [CARRYOVER] L-04 — Privileged mintFor()/burn() ignore global paused + per-index disabled flags

> **This is a carryover stub, not new analysis.** Reported in a prior run and **still open**
> (not fixed, not triaged). Carried over from prior run, unchanged at the flattened path
> introduced by story-039. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/NFTMinterV2.sol#L206-L214` (`mintFor`)  ·  faithfulness tag F-03
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-12
- **Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../../10/submissions/qa-report.md)
- **Fingerprint:** `a25137b1…` — see ledger `a25137b12fded6680f3844bfd61dda7d1e661a72f78c3230916e684b3b5ce37c`

Privileged `mintFor()` / `burn()` bypass the global paused flag and per-index disabled flags. Unchanged by story-039 (pure structural flatten). See the original QA report for full description, impact, and recommendation.
