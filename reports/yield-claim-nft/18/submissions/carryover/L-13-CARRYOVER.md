# [CARRYOVER] L-13 — PromotionUniV2_Eth._legB whole-balance ETH sweep + open receive() (Law-3 footgun)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and re-observed this run on the story-045-reworked contract. It is
> triaged **wont-fix** (owner-accepted: the whole-balance ETH sweep is an intended
> feature, not a defect; Tier-3 INV-4 fork-proved non-theft). It is reproduced here
> for cross-run visibility only — no action is owed. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** wont-fix (owner-accepted intended feature)
- **Location:** `src/dispatchers/PromotionUniV2_Eth.sol#L332-L346` (`_legB` / `receive`)
- **First seen:** yield-claim-nft-17  ·  **Still present as of:** yield-claim-nft-18
- **story-045 impact:** UNCHANGED — story-faithfulness confirms the story-045 rework did not alter the `_legB` whole-balance sweep or the open `receive()`.
- **Cross-ref:** F-01-044 (faithfulness twin, also wont-fix)
- **Original report:** [reports/yield-claim-nft/17/submissions/qa-report.md](../../../17/submissions/qa-report.md)
- **Fingerprint:** `ac8eadef…`

See the original report for the full description, impact, attack path, Tier-3 INV-4 proof, and safe-config guidance.
