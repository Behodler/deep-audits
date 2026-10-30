# Sanitize log: phoenix-phase-2-staging-44 (script-audit, story-122)

Entry points: `antimatter-pool`, `sya-harvester`. Submodule `master` @ 669cbc1. Input `deduplicated.json` (11 findings).

## Result

11 in, 11 passed, 0 removed, 0 suppressed. Origins: 11 new. No still-open, regression or incomplete-fix entries, and no fix-pending matches. 2 findings flagged for human review (DEDUP-011, DEDUP-001).

## Known issues

- `src/known-issues.md` is gone upstream. The registry cache holds 11 KIs, which cannot be checked against a source, so they carry **no suppression authority**. Nothing was matched against them. The nearest topical entry ("Admin trust assumptions ... operational risk") would not cover non-obvious operator footguns in any case (Law 3).
- In-source NatSpec and comments were not used for suppression.
- Story-122/113 disclosures (`disclosedInStory`: DEDUP-003/004/006/011 true, DEDUP-001 partial) are **disclosure, not suppression**. All of these findings stay live and labelled, because the scripts have not been broadcast yet.

## Fingerprints

`sha256(contract:function:rootCauseClass:entryPoint)`, with fields taken verbatim from `deduplicated.json` and no normalisation. The convention was checked by reproducing ledger entries 357565f8425a (balancer-lp-migrator L-01) and 4f454372eed2 (unipooler-cutover L-03) byte for byte. `fingerprintInput` is stored on each finding.

| id | fingerprint | origin | linked prior entries |
|---|---|---|---|
| DEDUP-001 | 3c8730ba2a831faec24639e5860146edd37b1eb4bdcc9005fdd0b36b7fb0dbdd | new | pps unipooler L-03 4f454372eed2 (open), pps dev L-01 9a694ae01fe1 (open): pair-state family. pps balancer-lp-migrator L-01 357565f8425a (**wont-fix**, UI-scoped to BalancerLPMigrator, does not cover). antimatter M-02 64807f2b1456 (**wont-fix**, realization path only, does not cover) |
| DEDUP-002 | 3b115d7566b3761d97fb1472df1c0e43fa22e9629624795071014a705a3f5bf1 | new | none |
| DEDUP-003 | cc55a47ec045964ac80ffa8966ade24acd7478d9d8ba18edbe257377e9e49e2c | new | pps unipooler Q-02 e2909097a253 (open): weak resume-predicate family |
| DEDUP-004 | d7e81a8dfc482608ac6d9cc8130f27a04de069c14de01d17403935a588d19c4f | new | pps balancer-holding L-01 59527bfa8478 (open): verifier-coverage family |
| DEDUP-005 | 01af21afa2ae0515ac4b9b6e0dd4b1beaa5f070904e784d914b1debb4b1ef064 | new | pps unipooler L-03 4f454372eed2 (open), sya-harvester L-01 d7744b9d2400 (open): dust-donation family |
| DEDUP-006 | c28c5f19e81baa2b4444f1d6edb3f0a575c607fa57b42cf66b5b228b13a049a5 | new | pps dev L-01 1e8cc0dc58ba (open), pps promotion-ready L-03 ea648ec5eab0 (open): local-pass progress-write family (recurrence) |
| DEDUP-007 | f7cafa264ec4c31f670e1819486aaa8dc734a5fa40987989ba658b93fc9ebf9a | new | none |
| DEDUP-008 | eed486cbeaf36e6dea35297dc88e20280296d3ce987e303c6ba70d4995590b27 | new | sya-harvester Q-04 dd56134239f8 (open, referenced, not refiled), pps L-05 b7ff538a654c (open, UniswapHelper DOLA-3CRV thin venue, different contract and venue) |
| DEDUP-009 | eb9785c544a5041689f52c9a8a6847f9360f02bacc49c7dac0bce878af0d25ef | new | none |
| DEDUP-010 | 6f2c622285c7016f58d518c54194baef58fac111275f616aabb62e2283cb7812 | new | pps ssv2 L-07 d6896c6e843d (fixed; budget preflight, different root cause, not a regression), pps unipooler L-02 01d60c7d1d49 (open) |
| DEDUP-011 | ff8c0cb81a45292e6f000b20dfa90affd7ac0356af3bf7452c47331e87572b6d | new | pps ssv2 **L-09 78cb5942d483 (fixed)**: see flag. pps ssv2 M-01 cf684d5dc289 (**wont-fix**, patcher tail, does not cover) |

Exact-fingerprint hits in the pps ledger: 0 of 11. Entries with entryPoint `antimatter-pool` or `sya-harvester`: 0. No pps entry names AntimatterPoolSeeder, CutoverAntimatterPoolMainnet, DeploySyaHarvesterMainnet, ClaimUnblockState, AM/sUSDS or stories 112/113/114/120/122. Sibling ledgers `sya-harvester` (17 entries) and `antimatter` (29 entries) contain no duplicate of any of the 11.

## Owner dispositions checked (none re-filed; refilesOwnerDisposition=false for all)

- **antimatter M-02 64807f2b1456 (wont-fix).** The triage reason reads: "antimatter was generated from prior stablecoin staked in the vaults ... It's now just being rewarded." That reasoning presumes AM reaches its intended holders. DEDUP-001 is about an attacker capturing protocol-minted AM at a price the attacker sets, through an unenforced seeder precondition. The root cause differs, and the disposition does not cover it.
- **pps balancer-lp-migrator L-01 357565f8425a (wont-fix 2026-10-30).** The triage reason reads: "I'll deal with it on the ui side ... Premise: migrations are expected to go through the UI." It is scoped to BalancerLPMigrator user migrations. AntimatterPoolSeeder.seed (`amountBMin=0`) is an owner script with no UI path, so the disposition does not transfer.
- **pps ssv2 M-01 cf684d5dc289 (wont-fix 2026-09-18).** This covers the patcher's exit-2 tail on a lapsed-window resume, not DEDUP-011's checklist or residual abort. Its reopenTrigger includes "verifier NatSpec edited in this area without adding the awaiting_minter_window branch". Story-122 edited VerifyStableStakerV2Cutover Phase 7, so finding-manager or a human should check whether that trigger has fired.

## Flagged for human review

1. **DEDUP-011, linked to the fixed entry L-09 78cb5942d483.** The Phase 6b "OWNER DOLA residual" check that now aborts the verifier on mainnet *is* the L-09 fix (human 2026-09-16: "bound OWNER DOLA residual"; fixed @91ed727). This is not a regression: the fix is failing loudly where it previously passed silently. However, the residual of 88138771830498 wei on OWNER belongs to the same artefact class as the L-09 silent excess, and its provenance has not been established. Confirm where it came from before relaxing the check. A blanket dust tolerance could re-open L-09 without anyone noticing.
2. **DEDUP-001, severity borderline.** The deduplicator proposed Medium, borderline High, on fork-demonstrated protocol value capture (~$2.3k). The severity-classifier decides. The sanitizer confirms that no prior disposition covers it.

## Carryover

None. No still-open or fix-pending entry matched, so finding-manager has no carryover entries from this run's findings.
