# [CARRYOVER] BMR-L-02 — Seed amount is not asserted against the pot delta at the script level — a 0/short seed would pass silently if the helper floor were misconfigured

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `batch-minter-replace`
- **Location:** `lib/phoenix-phase-2-staging/script/ReplaceBatchNFTMinter.s.sol#L388-L435` (`_seedFromBpt` / `_postflight`)
- **First seen:** phoenix-phase-2-staging-03  ·  **Still present as of:** phoenix-phase-2-staging-04 (HEAD `912a33d`)
- **Original report:** [reports/phoenix-phase-2-staging/03/findings/low/BMR-L-02-seed-delta-not-asserted.json](../../../03/findings/low/BMR-L-02-seed-delta-not-asserted.json)
- **Fingerprint:** `7e3bd86b09aa39f1b6f0b08c9e2da036b2e92aed31f748c49cfa166949c4f72f`

Untouched by the fix diff (`ebc2808..912a33d`); remains live at HEAD `912a33d`. See the original report for the full description, impact, attack path, PoC, and recommendation.
