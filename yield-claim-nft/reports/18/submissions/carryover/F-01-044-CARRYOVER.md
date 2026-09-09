# [CARRYOVER] F-01-044 — PromotionUniV2_Eth._legB whole-balance ETH sweep (spec-conformance nuance)

> **This is a carryover stub, not new analysis.** This faithfulness record was filed
> in a prior run and re-observed this run on the story-045-reworked contract. It is
> triaged **wont-fix** (owner explicitly declared the whole-balance ETH sweep the
> intended spec, closing the under-specification basis; twin of L-13). It is
> reproduced here for cross-run visibility only — no action is owed. Triage it with
> `/ledger yield-claim-nft`.

- **Severity:** Low (informational faithfulness record)
- **Status:** wont-fix (intended-by-design; under-specification basis closed by owner)
- **Location:** `src/dispatchers/PromotionUniV2_Eth.sol#L332-L346` (`_legB`)
- **First seen:** yield-claim-nft-17  ·  **Still present as of:** yield-claim-nft-18
- **story-045 impact:** UNCHANGED — the whole-balance ETH sweep path is not modified by story-045; no Law-1 escalation (Tier-3 INV-4 HELD, value never reaches a third party).
- **Cross-ref:** L-13 (security/footgun twin, also wont-fix)
- **Original report:** [reports/yield-claim-nft/17/submissions/spec-conformance.md](../../../17/submissions/spec-conformance.md)
- **Fingerprint:** `3e638eb9…`

See the original spec-conformance report for the full faithfulness verdict and nuance.
