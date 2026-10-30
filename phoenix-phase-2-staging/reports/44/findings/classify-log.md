# Severity classification log: phoenix-phase-2-staging run 44 (script-audit)

Entry points: `antimatter-pool` (Script B), `sya-harvester` (Script A). Story: story-122 (auto-complete). Submodule 669cbc1, branch master.
Neither entry point is broadcast; the AM/sUSDS pair is absent at block 26304034. Input: 11 sanitized findings, all origin `new`. Ledger NOT written.
Output: 2 Medium, 5 Low, 3 QA (security records) and 4 F-xx spec-conformance records (3 derived, plus DEDUP-011 routed to F).

## Labels
Labels are sequential per entry point (`submissions/<entryPoint>/<label>.md`). issueIds (`pps44<type><n>`) are unique across the run, because L-01/F-01/F-02 exist under both entry points. This avoids the run-35 Q-01 issueId collision.

| label | entryPoint | sev | issueId | fp12 | source |
|---|---|---|---|---|---|
| M-01 | antimatter-pool | Medium (borderline High, flagged) | pps44m1 | 3c8730ba2a83 | DEDUP-001 |
| M-02 | antimatter-pool | Medium (flagged) | pps44m2 | cc55a47ec045 | DEDUP-003 |
| L-01 | antimatter-pool | Low | pps44l1 | 3b115d7566b3 | DEDUP-002 |
| L-02 | antimatter-pool | Low | pps44l2 | d7e81a8dfc48 | DEDUP-004 |
| L-03 | antimatter-pool | Low | pps44l3 | 01af21afa2ae | DEDUP-005 |
| F-01 | antimatter-pool | spec (Medium weight, unsafe story) | pps44f1 | 9d2f2c79c3ef | derived from DEDUP-001 |
| F-02 | antimatter-pool | spec (Low) | pps44f2 | 7a2a50635466 | derived from DEDUP-002 |
| L-01 | sya-harvester | Low | pps44l4 | f7cafa264ec4 | DEDUP-007 |
| L-02 | sya-harvester | Low | pps44l5 | eed486cbeaf3 | DEDUP-008 |
| Q-01 | sya-harvester | QA (down from Low) | pps44q1 | c28c5f19e81b | DEDUP-006 |
| Q-02 | sya-harvester | QA | pps44q2 | eb9785c544a5 | DEDUP-009 |
| Q-03 | sya-harvester | QA | pps44q3 | 6f2c622285c7 | DEDUP-010 |
| F-01 | sya-harvester | spec (Medium weight, unsafe story) | pps44f3 | 031dd8696af0 | derived from DEDUP-007 |
| F-02 | sya-harvester | spec (Low) | pps44f4 | ff8c0cb81a45 | DEDUP-011 (routed to F) |

The 3 derived F fingerprints are `sha256(contract:function:rootCauseClass:entryPoint)` over new rootCauseClasses (StoryGuaranteeNotEnforcedOnChain, StoryAlwaysRunCleanupSkipped, UnsafeStoryOrderingClaim). They do not collide with any security fingerprint. The F records do not count as additional H/M.

## Judgment calls

### M-01 (DEDUP-001): Medium, not High
- **For High:** the theft is fork-proven (test_r44_02/03 PASS). The attacker is an unprivileged third party. The protocol loses real POL: AM is minted only against burning 2,457.70 protocol-owned phUSD, so "freshly minted AM is not an asset" is rejected. The protocol's LP ends at 6.05 AM + 1e-6 sUSDS (about $2,315 lost); the 2,077 sUSDS half returns to OWNER. Attacker +$1,320 realized / +$2,168 mark.
- **Why Medium:** (1) The enabling state (A-before-B) is an owner ordering choice made in advance between two sanctioned options. The other option (B-before-A) removes the attack entirely (AM totalSupply==0, claim disabled; test_r44_05/06/13), and the attacker cannot force the bad order. The ordering is not an owner *mistake*: the runbook sanctions it, which is exactly why this is filed rather than dropped. It is still a precondition outside the attacker's control. (2) The attacker must hold AM and must target a specific, unannounced one-shot operation inside a ~4-block window, which is bespoke targeting rather than generic MEV. (3) The loss is bounded (one 10% slice), one-shot, and fully preventable pre-broadcast. This matches C4 Medium: "leak value with a hypothetical attack path with stated assumptions, but external requirements".
- **Opportunity-cost memory rule:** does NOT apply. That rule covers externally-derived yield over-paid to intended beneficiaries (misallocation). Here an outside party captures protocol principal (seeded inventory) at a price it chose.
- **Prior dispositions:** antimatter M-02 wont-fix covers only the annihilate realization path. yield-claim-nft Q-24 (off-chain-only cutover floors, QA) is not analogous, because its value leak was refuted on fork, while this one is fork-proven profitable.
- **Re-weigh trigger:** Plausible High if the owner commits to A-before-B and broadcasts B unchanged.
- AP-06 (private RPC misdescribed) stays folded into M-01; its story/runbook facet surfaces in antimatter-pool F-01.

### M-02 (DEDUP-003): Medium (independent of the story's [medium])
All four integrity gates (resume gate, in-script post-conditions, verifier, patcher) report success for a mainnet cutover that never happened. They then write the attacker's pair into the canonical book, which Script C consumes without distinguishing a seeded pair from a foreign one. That is protocol-function impact with stated assumptions. Not High, because no funds move.
**Downgrade case, for human review:** the attacker gains nothing (a profit-seeker runs M-01 instead), the Script C consequence is inferred and was not executed, and a tx5 revert is loud. Re-weigh to Low if Script C gains a chain-anchored pair check, or the runbook mandates pair inspection after a tx5 revert.

### sya-harvester L-01 (DEDUP-007): Low, kept separate
Its own impact is availability-only: B aborts fail-safe. The theft has a different root cause (the seed tx does not enforce the pair-absent precondition on chain) and a different fix, and it lives in M-01. Merging would let "reorder the runbook" be mistaken for the M-01 fix, or the reverse. The unsafe story ordering rule ("A and B in either order", L16/L192) is flagged as sya-harvester F-01 (unsafeStory, Law 1 > Law 2).

### antimatter-pool L-01 (DEDUP-002): Low
A Law-3 footgun: the story and runbook promise the revoke always runs, and a competent owner would be surprised that it does not. The stale minter grant is unexploitable by non-owners, because seed() is onlyOwner (test_r44_01). The story deviation goes to antimatter-pool F-02.

### Other Low / QA
- L-02 (DEDUP-004), the verifier gap: Low. It amplifies M-01/M-02 rather than causing loss itself.
- L-03 (DEDUP-005), dust to the seeder: Low. Fail-safe griefing that the owner can recover from.
- sya L-02 (DEDUP-008), thin DOLA route: Low. A conditional future availability problem with a setRoute remedy, and the story chose the pool, so it is not an F.
- Q-01 (DEDUP-006): downgraded Low to QA. It is disclosed, conditional, and mitigated by three chain-anchored gates. The same factor has teeth only in M-02.
- Q-02 / Q-03 (DEDUP-009/010): QA as proposed.

### sya F-02 (DEDUP-011): spec-conformance, not L
A ticked-but-false checklist item. The Phase 6b abort is the L-09 (78cb5942) fix firing correctly, so no code is wrong.
**Flagged for human review:**
1. Confirm the provenance of the 88138771830498 wei DOLA residual before relaxing Phase 6b, otherwise L-09 silently reopens.
2. Check the reopenTrigger of M-01 cf684d5d (wont-fix), since story-122 edited VerifyStableStakerV2Cutover Phase 7.

## Evidence spot-check
- logs/forktest-run44-antimatter.log: 17/18 PASS, including test_r44_02/03/04.
- test_r44_10 (the L-03 post-deploy leg) FAILs SUsds/insufficient-balance in the suite run but PASSes in isolation (forktest-run44-t10.log). This is a fixture interaction; the PoC needs suite-stability work.
- The classifier did not re-run the fork tests.

## Flagged for human review
antimatter-pool M-01 (borderline High), antimatter-pool M-02 (downgrade case), sya-harvester F-02 (L-09 provenance and cf684d5d reopenTrigger).
