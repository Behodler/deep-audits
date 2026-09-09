# phoenix-phase-2-staging-21 — Spec-conformance (Law 2) index — entry point `dev`

> **Law 2 — story/spec deviations are routed here at honest severity and are NEVER buried in the QA/gas bundle.**
> Story scope: **story-073** (related: story-072). Audited commit `3fb4e34`.
> **Acceptance criteria are NON-FINAL** (story 073 is in `complete/` but still carries `Review Status: ISSUES_FOUND`; story 072 is `incomplete/` with line 514 unticked). Recorded as confidence, not severity inflation.

| F-label | Source id | Run label | Severity | Routing | Record |
|---|---|---|---|---|---|
| **F-01** | `FAITH-001` | **L-07** | low | PRIMARY | [`L-07-balancer-donation-test-certified-as-streamer-regression.json`](../low/L-07-balancer-donation-test-certified-as-streamer-regression.json) |
| **F-02** | `FAITH-002` | **L-08** | low | PRIMARY | [`L-08-checklist-544-ticked-without-implementation.json`](../low/L-08-checklist-544-ticked-without-implementation.json) |
| **F-03** | `FAITH-003` | **Q-04** | qa | PRIMARY — QA severity but owner-visible, NOT bundled | [`Q-04-incomplete-batchmint-callsite-preflight-sweep.json`](../qa/Q-04-incomplete-batchmint-callsite-preflight-sweep.json) |
| **F-04** | `FAITH-L1-001` | **L-09** | low | PRIMARY — Law-1 story-unsafe escalation | [`L-09-kendu-whitelist-sanctioned-without-real-token-roundtrip.json`](../low/L-09-kendu-whitelist-sanctioned-without-real-token-roundtrip.json) |
| **F-05** | `DEV-05` | **L-02** | low | CROSS-REFERENCE ONLY — primary home stays the QA/Low bundle; not double-counted | [`L-02-deploymocks-missing-chainid-guard.json`](../low/L-02-deploymocks-missing-chainid-guard.json) |

### F-01 — L-07 (`FAITH-001`, low)

**Routing:** PRIMARY

test:balancer-donation is ticked (story lines 505/539) as the index-4 streamer regression test, but the script was never modified by story 073, never calls batchMint, and asserts against the batch minter rather than the streamer — so a green run proves nothing about the repair, on the one leg where the breakage was silent.

### F-02 — L-08 (`FAITH-002`, low)

**Routing:** PRIMARY

Story line 544 is ticked certifying four clauses across seven setNudgeStreamer legs; one clause and one leg are actually asserted, with no recorded out-of-band evidence. Second instance in one story of the class the story's own review caught as HIGH Issue 1.

### F-03 — Q-04 (`FAITH-003`, qa)

**Routing:** PRIMARY — QA severity but owner-visible, NOT bundled

The preflight sweep instructed at line 491 missed two batchMint call sites (PreviewBatchMint40.s.sol:55,145 and SimulateMainnetNudgeMint.s.sol:77) that still bind the legacy scalar-minReward signature; both break on the story-072 cutover and neither is in the feedback list.

### F-04 — L-09 (`FAITH-L1-001`, low)

**Routing:** PRIMARY — Law-1 story-unsafe escalation

Both stories instruct whitelisting Kendu while story 072's real-token FoT round-trip (line 514) is unticked and story 073's probe runs against a mock the story itself defines as fee-free. No armed path today (USDC-only stream registration), but a latent arm-switch with a mandatory REOPEN-AS-MEDIUM trigger.

### F-05 — L-02 (`DEV-05`, low)

**Routing:** CROSS-REFERENCE ONLY — primary home stays the QA/Low bundle; not double-counted

Story line 66 states 'No mainnet contact of any kind. Everything here targets chainId 31337' as a flat property; nothing in DeployMocks.s.sol enforces it. A documented invariant that is not held.

## Non-final acceptance criteria — close triggers

- **F-02 / L-08** and **F-04 / L-09** carry an explicit **close trigger**: if story 073 line 544's four clauses are actually asserted across all seven `setNudgeStreamer` legs, and story 072 Preflight line 514 is ticked against the **real** Kendu token `0xaa95f26e30001251fb905d264aa7b00ee9df6c18` (not `MockKendu`), both may be closed.
- **F-04 / L-09** additionally carries a **REOPEN-AS-MEDIUM trigger** — see `findings/low/L-09-kendu-whitelist-sanctioned-without-real-token-roundtrip.json` → `reopenTrigger`. Its `blockingPreBroadcastAction` is mandatory before any mainnet broadcast.
- **F-05 / L-02** is a **CROSS-REFERENCE ONLY**: its primary home is the Low bundle. It is **not** double-counted in the severity totals (0 High / 2 Medium / 9 Low / 4 QA = 15).

