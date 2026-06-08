# [CARRYOVER] Q-04 — setMinter emits no event (and V2 uses single-step Ownable)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** QA
- **Status:** qa-bundled (still-open)
- **Location:** `src/V2/dispatchers/ATokenDispatcherV2.sol#L85` (`setMinter`)
- **First seen:** yield-claim-nft-08  ·  **Still present as of:** yield-claim-nft-10
- **Original report:** [reports/yield-claim-nft-08/submissions/qa-report.md](../../../yield-claim-nft-08/submissions/qa-report.md)
- **Fingerprint:** `daada310…`

This run's DD-07 (single-step Ownable across in-scope contracts, no Ownable2Step) reconciles to Q-04, which already bundles both the missing-event note and the single-step-Ownable item; no duplicate is emitted. Owner-trust is an explicit known issue, so this stays QA-only. Not a regression.

See the original report for the full description, impact, attack path, PoC, and recommendation.
