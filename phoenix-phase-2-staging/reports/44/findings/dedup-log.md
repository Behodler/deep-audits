# Dedup log: phoenix-phase-2-staging run 44 (script-audit, story-122)

Inputs: 12 candidates. 6 come from `sya-harvester`; they had no ids, so they were assigned SYA-01..06 in file order. The other 6 come from `antimatter-pool` (AP-01..06).
Output: 11 findings in `deduplicated.json`. 1 merge. 0 outright drops. 0 moved to manual review.
No severity changed. The ledger was not touched. Recommendations are kept verbatim. The single merge unions its recommendations, and each source text is also stored in `recommendationSources`. `disclosedInStory` flags, quotes and disclosure gaps are preserved.

## Phase 1: exact match
There were no identical `contract:line:function` tuples across the 12 inputs.

## Per-input disposition

| input | entryPoint | proposed sev | disposition | output | reason |
|---|---|---|---|---|---|
| SYA-01 | sya-harvester | low | kept | DEDUP-007 | A-before-B ordering is the *enabling condition* for AP-01/02/03 but has a different root cause: runbook/story ordering in Script A, not an on-chain-unenforced precondition in Script B/seeder. Each fix is independent, and either one alone leaves the other defect live: with the seed guard alone, R1 pre-pricing still blocks B; with B-first ordering alone, the seeder still has no on-chain price bound. Merging would also collapse a Low into a Medium. Kept separate and cross-linked via `relatedFindings`. |
| SYA-02 | sya-harvester | low | kept | DEDUP-008 | Unique: route depth config. It references sya-harvester ledger Q-04 (dd56134239f8) and does not refile it. |
| SYA-03 | sya-harvester | low (QA bucket) | kept | DEDUP-009 | Unique: dry-run isolation defect. It involves the same thin DOLA pool as SYA-02 but is a different defect with a different fix. Not tool noise, because it bears on what the story's preview evidence proves. |
| SYA-04 | sya-harvester | low (QA bucket) | kept | DEDUP-010 | Unique: operational gas price and replacement path. Not style or noise, because it affects the runbook's resume instruction. |
| SYA-05 | sya-harvester | low, disclosed | kept | DEDUP-011 | Unique: the ticked-but-false checklist item and the Phase 6b abort. The story quote is preserved. |
| SYA-06 | sya-harvester | low, disclosed | kept | DEDUP-006 | See "Progress-file decision" below. |
| AP-01 | antimatter-pool | medium (borderline high) | kept, survivor | DEDUP-001 | The core finding. Absorbs AP-06. The Medium-vs-High question goes to the severity-classifier. |
| AP-02 | antimatter-pool | low | kept | DEDUP-002 | Same Step-0 branch as AP-03, but a different failure (cleanup skipped, minter grant left in place vs. false completion) and a different fix (revoke-before-abort vs. chain-anchored resume gate). |
| AP-03 | antimatter-pool | medium, disclosed | kept | DEDUP-003 | Root cause WeakResumeGate. Distinct from AP-01: here the AM-dear variant is a seed *revert* and the result is a false-green completion, not theft. Distinct from AP-04: the resume gate and the verifier are separate components with separate fixes. |
| AP-04 | antimatter-pool | low, disclosed | kept | DEDUP-004 | The verifier is a separate component. It explains why AP-01/AP-03 states pass verification, but fixing it does not fix either of them. |
| AP-05 | antimatter-pool | low | kept | DEDUP-005 | Unique: an absolute-balance check that can be griefed. |
| AP-06 | antimatter-pool | low | **merged into DEDUP-001** | DEDUP-001 | Same root cause and window as AP-01 (the tx1-to-tx5 public gap with no on-chain pair-absent guard). AP-06 is its documentation facet: AP-01's disclosureGap (c) and recommendation already cover the "private RPC doesn't cover the window" point. The script-auditor itself proposed this fold (antimatter-pool manual-review item 1). The survivor keeps Medium. AP-06's Low, title, location, description, impact and evidence are all preserved in `mergedFrom`. Its recommendation is unioned into the survivor's. |

## Progress-file decision (SYA-06 vs AP-03)
Both trace to the same disclosed story-122 item: progress files are written in forge's local pass. Only SYA-06 is a standalone progress-file finding. On the antimatter-pool side, the local-pass record (`seeded=true`, `completed`) is one ingredient of AP-03, whose root cause is the weak Step-0 resume gate (seeder has code + OWNER LP > 0). They were **not merged**, for three reasons:
1. They are different scripts with different progress files and different consumers: `ClaimUnblockState.progressRecordsClaimEnabled` for SYA-06, and the Script B resume branch, the patcher's `completed && seeded` gate and the verifier for AP-03.
2. The fixes are separate: receipt-confirmed progress writes or a code check at the harvester for SYA-06, and a chain-anchored resume gate for AP-03. A receipt-confirmed progress writer would not by itself close AP-03, because AP-03's gate accepts any existing pair with dust OWNER LP regardless of `p.seeded`.
3. The proposed severities differ (Low vs Medium). Merging would collapse one into the other.

They are cross-linked via `relatedFindings`. Downstream note: if the classifier or finding-manager wants one systemic "local-pass progress writes" QA line, SYA-06 is the natural home, with AP-03 cited as a second instance.

## Manual-review and reference items
Neither entry point's `manual-review-and-references.json` items are findings. They are carried through unchanged into `deduplicated.json` → `manualReviewCarried` and `referencedNotRefiled`:
- sya-harvester: ClaimWithdrawStableStaker vs DeployMocks (anvil-only, not filed); story-121 test_bookKey_isZeroPlaceholder not re-run (carry); concurrent A/B nonce sharing (not filed). It also references sya-harvester ledger L-01, L-02, L-03, L-05, Q-04, Q-05 and M-01 (fixed); none are refiled.
- antimatter-pool: the AP-06 fold (resolved here: merged); the seeded AM price above annihilate parity (intended, story-113 L113); AP-01 Medium vs High (left to the classifier); unverified Antimatter/UniPoolerV2 bytecode (carry); the operator progress-file deletion (operator error, not filed); Script C not run against the AP-03 spoofed book (verify in the uniswap-helper audit). It also references antimatter M-02 (wont-fix, 64807f2b1456), which is not refiled.

No dedup-originated `manual-review.json` was written, because no candidate was quality-filtered.

## Flags for review
- DEDUP-001 severity: Medium vs borderline High, for the classifier.
- DEDUP-007 and DEDUP-001 are causally linked across entry points. The classifier should read them together. The fix for DEDUP-007 (B before A) is also listed as the interim mitigation in DEDUP-001.
