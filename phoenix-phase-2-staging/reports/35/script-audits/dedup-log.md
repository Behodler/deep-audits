# Dedup log: phoenix-phase-2-staging run 35 (script audit, 3 entry points)

Input: `candidate-findings.json` (7). Output: `deduplicated-findings.json` (7).
I merged nothing, removed nothing and parked nothing, so `manual-review.json` is not needed.
I checked the ledger with jq projections only and did not modify `ledger.json`.

## Kept (7)

| dedupId | label | entryPoint | rootCauseClass | action |
|---|---|---|---|---|
| DEDUP-35-01 | L-09 | stable-staker-v2-cutover | ForgeLocalPassPrecedesBroadcast | kept |
| DEDUP-35-02 | L-10 | stable-staker-v2-cutover | StaleOperationalBudget | kept, `incompleteFixOf` L-07 |
| DEDUP-35-03 | Q-05 | stable-staker-v2-cutover | StaleOperatorRunbook | kept, related to Q-04 |
| DEDUP-35-04 | Q-06 | stable-staker-v2-cutover | PhaseCouplingBlocksUnpause | kept |
| DEDUP-35-05 | Q-07 | stable-staker-v2-cutover | CommittedMergeConflictMarkers | kept |
| DEDUP-35-06 | Q-01 | dola-ys-withdrawal:status | StatusIgnoresConsumerGate | kept |
| DEDUP-35-07 | Q-01 | initiate-dola-ys-withdrawal | StoryConflictOperatorTiming | kept |

## Merged
None.

## Dropped / routed to manual review
None. The seven `refutedOrNotFiled` observations from the auditor are carried through unchanged, so their verdicts stay visible (OBS-35-05, -06, -08, -09(i)/(ii), ...).

## Related, not merged (with reasons)

- **Q-05 vs ledger Q-04 `a62956952abd` (fix-pending).** Both concern the same `//stable-staker-v2-cutover:broadcast` comment, but they describe different defects. Q-04 says the Phase 7 halt-5 breaker claim is overstated (`_phase7_finalize`, BreakerLivenessDocOverclaimHalt5). Q-05 is the second dead window that story 092 added (autoDOLA `setPauser(OWNER)` -> `Pauser.unregister`, halt g) plus the stale 46-tx count. The fingerprints differ and each needs its own text correction. File both and fix them together. Flagged for review in case the reviewer prefers to widen Q-04.
- **L-10 vs ledger L-07 `d6896c6e843d` (fixed 84e2324).** This is an incomplete fix. The preflight mechanism works, but the 22M constant was not re-derived for the 67-tx session. L-10 carries `incompleteFixOf`. L-07 stays `fixed` and is not reopened or merged, because only a human changes a status.
- **status Q-01 vs initiate Q-01.** Both leave out the story-092 6h `WINDOW_SAFETY_MARGIN` from operator output. They are still different scripts, different code and different fixes. Status also ignores the strategy pause flag. Initiate has a story 090-vs-092 conflict and prints local-pass timestamps. They are not the same root cause in the same code, so I did not collapse them across entry points. Both use the label Q-01 under per-entry-point sequencing (flagged, so finding-manager must key by entryPoint).
- **L-09 / L-10 -> Q-06.** A Phase 6b halt (L-09 revert branch, or the L-10 budget halt) is one trigger for Q-06. Q-06's own root cause is separate: the Phase 0 window gate blocks the Phase 7 unpause. Compounding is noted and there is no merge.
- **L-09 vs ledger promotion-ready:broadcast L-02 `b57dcb4bb594`.** They share the ForgeLocalPassPrecedesBroadcast class but have a different script and entry point. This is a pattern precedent, not a duplicate. Initiate Q-01's local-pass timestamps belong to the same family.

## Tool noise filter
Nothing qualified. Q-07 (conflict markers) is off the mainnet path, but it breaks the dev API server's address loading, so it is not pure style.
