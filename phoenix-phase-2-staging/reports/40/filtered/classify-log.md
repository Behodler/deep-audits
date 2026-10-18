# Classify log: phoenix-phase-2-staging run 40 (contract scan, master @ a4f9f3c)

Input: `filtered/sanitized.json`. Output: `filtered/classified.json`. The ledger was not written.

## Result: 0 H / 0 M / 5 L / 2 QA / 2 F, plus 2 left unclassified

| Label | DEDUP | Sev | Footgun | Faith | Human review | Short title |
|---|---|---|---|---|---|---|
| L-01 | 001 | Low (borderline M) | yes | tag | yes | Core steps 4-6 EOA custody, dust swap strands ~$41k POL, no resume |
| L-02 | 002 | Low (borderline M) | - | story-unsafe | yes | UniswapHelper existence-only guard, honest first LP bricks empty-pair design |
| L-03 | 004 | Low | yes | tag | - | Index-4 OnlyDispatcher window, steps 8-10, no resume gates |
| L-04 | 005 | Low | - | tag | yes | RECOVERY branch never enables Recovery Mode; mock conflation |
| L-05 | 006 | Low | yes | - | - | Thin hardcoded DOLA venue in helper |
| Q-01 | 003 | QA | - | - | - | Simulation-only post-conditions, baked rescue amounts |
| Q-02 | 007 | QA | - | story-unsafe | - | Story-103 respec turns the skim-healable donation into a grief |
| F-01 | 008 | F | - | yes | - | Story 103 / plan Stage 2 contradicts the 10-07/10-10 amendments |
| F-02 | 010 | F | - | yes | - | Story 103 names the wrong third-party BPT holders |
| - | 009 | unclassified | | | | ycn L-27 / F-02-052 obligation to story 103 (not landed) |
| - | 011 | unclassified | | | | Plan section 5 numbers refresh |

## Label collision check
- `reports/40/` has no `findings/` or `submissions/` dir yet, so no file collides.
- The literal "L-01" appears in run 40 only inside `ledgerDuplicates`, where it is the original label of carried entries: run-39 dev 9a694ae01fe1 and run-38 balancer-holding 59527bfa8478. "Q-24" is a ycn label.
- Run-40 L-01 (DEDUP-001) explicitly references 9a694ae01fe1. Downstream writers should therefore cite carried entries by fingerprint ("run-39 L-01 9a694ae01fe1"), never by bare label.

## DEDUP-001: the key call (Low, borderline Medium)

**Case for Medium:**
- Fork-confirmed in both scenarios, with a fuzz falsification.
- The trigger is organic (about 5 swaps/week) or costs about $0.03.
- About $41.3k of POL ends up on an EOA, with no resume entry point.
- It violates story 103's 2026-10-07 "no protocol funds transit the owner EOA".
- It leaves the pair-poisoning window (9a694ae01fe1) open.
- The 30 Oct / 30 Nov deadlines compress recovery time.
- A competent owner would be surprised. This is a genuine footgun, so it is in scope.

**Case for Low (chosen):**
- **Nothing is lost or extractable** (ECON-001). The custodian is the trusted owner.
- **The owner can recover by hand.** In scenario A the owner holds both legs and can seed directly. Plan L414 already anticipates "recovered sUSDS and phUSD sit on OWNER ... re-runs from step 6". In scenario B the owner holds the BPT and can exit it directly.
- **Availability impact is narrow.** Index-4 minting survives 30 Oct, because `_dispatch` never calls Balancer (plan L9). A proportional recovery exit stays open after 30 Nov (plan L22/L38).
- **Not reachable on mainnet.** No mainnet entry point calls the core at a4f9f3c. Only DeployMocks does. Story 103 is incomplete and specified to rewire the core onto the atomic escrow.
- **Precedent.** Runs 31-37 had 0 H/M for pre-broadcast cutover tooling, with borderline cases held at Low.

**Re-weigh trigger:** raise to Medium if any story-103 mainnet entry point or npm broadcast key wires core steps 4-6 in PROPORTIONAL mode without escrow or resume gates.

**Related:** flagged with DEDUP-009. Do not pre-close it when story 103 lands; re-check then.

## DEDUP-002 (Low, borderline Medium)

- **Law 1 override.** Story 109's safety rationale is not achieved, because an existing pair is not the same as an empty pair. Fork-proven.
- **Why not Medium:**
  - No asset is at risk, and live protocol functions are unaffected.
  - The outcome is already accepted for the adversarial trigger: 9a694ae01fe1 is open Low, and ycn L-26 b2a29359fde5 is wont-fix 2026-10-07 ("it should just panic and then I'll have to figure out what to do").
  - The brick hits one seeding design, not the protocol. A dust first position can be re-priced and minted into with new code (the plan L414 pattern).
  - L-26's re-weigh condition ("hard deadline would expose value") is only partly met: the deadline exists, but value is not exposed because the recovery exit stays open.
- **Disclosure.** This re-raises an owner wont-fix on a new contract and trigger. The prior entry and its quoted triage reason are carried in the finding (wontFixDisclosure).
- **Re-weigh trigger:** raise to Medium if the UI exposes the helper's add form before Stage 4, or if step 1 (createPair) stays in a separate tx from the seed while the helper is live.
- **Fix:** a one-line reserve check, before story 111 broadcasts.

## DEDUP-005 (Low, human review)

- **The fork result is not decisive.** The SenderNotAllowed revert for OWNER was observed on the LIVE pool, which is the expected authorized-only behaviour before a pause.
- **Remedy before re-running:** one call to `enableRecoveryMode`. Plan L38 says it becomes permissionless once the pool or Vault is paused, and plan L21/L34 say Balancer enables Recovery Mode where needed.
- **Fails closed.** The PoolNotInRecoveryMode revert happens in forge simulation, before step 4 broadcasts, so nothing is stranded.
- **Why the fallback does not raise severity:** it is reachable with one permissionless call. Severity would rise only if it were unreachable.
- **Unverified:** the paused-pool path was not tested.
- **Re-weigh trigger:** raise to Medium or higher if a fork that forces a pause shows `enableRecoveryMode` is still not callable.
- **Owed by story 103:** that forced-pause fork test, plus a mock that models Recovery Mode as its own state.

## Others
- **DEDUP-003 → QA:** dust-scale, recoverable residue. The halt branch cannot be reached with today's config. Class precedent: Q-01 9fa8eee3010e.
- **DEDUP-004 → Low:** fork-proven, fails closed, temporary. Hand completion is possible. Footgun against story 103's "resume from receipts".
- **DEDUP-006 → Low:** the immutable helper ships a route that cannot be used at size. Quote-derived minOut protects users (I3 PASS). Spec gap, not a deviation, so no F label.
- **DEDUP-007 → QA + faithfulness:** a marginal grief, weaker than the existing sync brick. Cross-reference it in spec-conformance.md under story 103, with no separate F label.
- **DEDUP-008 → F-01, DEDUP-010 → F-02:** pure Law-2 items, shown in spec-conformance.md.
