# [CARRYOVER] BMR-L-01 — Old-minter retirement guard `require(USDC.balanceOf(OLD)==0)` can be griefed to abort the entire migration mid-broadcast, leaving an inconsistent half-cutover

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `batch-minter-replace`
- **Location:** `lib/phoenix-phase-2-staging/script/ReplaceBatchNFTMinter.s.sol#L419-L427` (`_retireOld`)
- **First seen:** phoenix-phase-2-staging-03  ·  **Still present as of:** phoenix-phase-2-staging-04 (HEAD `912a33d`)
- **Original report:** [reports/phoenix-phase-2-staging-03/findings/low/BMR-L-01-retire-guard-grief.json](../../../phoenix-phase-2-staging-03/findings/low/BMR-L-01-retire-guard-grief.json)
- **Fingerprint:** `22fc436d9483c95c1462e3775839e6da2ac3757ffd86155d587ad9a0d96791fe`

Untouched by the fix diff (`ebc2808..912a33d`); a concrete third-party front-run DoS (not mere admin trust). See the original report for the full description, impact, attack path, PoC, and recommendation.
