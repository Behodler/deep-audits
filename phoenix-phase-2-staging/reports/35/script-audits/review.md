# Cluster script review: DOLA withdrawal + StableStaker V2 cutover (run 35)

- **Run**: `phoenix-phase-2-staging-35`, cluster script audit of three coupled entry points
- **Source**: [Behodler/phoenix-phase-2-staging @ `7ac6e70`](https://github.com/Behodler/phoenix-phase-2-staging/tree/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963), branch `master`, read-only
- **Entry points**:
  - [`initiate-dola-ys-withdrawal`](./initiate-dola-ys-withdrawal/review.md)
  - [`dola-ys-withdrawal:status`](./dola-ys-withdrawal-status/review.md)
  - [`stable-staker-v2-cutover`](./stable-staker-v2-cutover/review.md)
- **Mode**: fork preview on anvil, mainnet block 25990689. `--ledger` was replaced by `--unlocked`, with every other flag verbatim. **Nothing was broadcast to mainnet.** All execution ran from `work/`, which was restored afterwards. Evidence lives under `fork-logs/`.
- **Primary reports**: [`../submissions/qa-report.md`](../submissions/qa-report.md) (authoritative text and line numbers), [`../submissions/spec-conformance.md`](../submissions/spec-conformance.md), [`../submissions/carryover/qa-report-34.md`](../submissions/carryover/qa-report-34.md)

## Conclusions

1. **The three scripts compose correctly on real bytecode.** The full sequence ran end to end on anvil: initiate → status EXECUTABLE → cutover preview → 67-transaction broadcast → address patch → `:verify` → post-cutover status, initiate and smoke checks. Every stage failed closed where it should.
2. **No High or Medium findings.** Across the cluster the run files **3 Low and 4 QA**. All seven are new, with 0 regressions, 0 re-filed wont-fix entries and 0 known-issue suppressions (the known-issues cache carries no authority).
3. **The core cross-script hazard is local pass versus mined state (L-09).** The cutover signs a Phase 6b amount computed before earlier transactions in the same session have mined. That enforces a story-092 acceptance criterion only locally. On a clean run 0.0023 DOLA stayed on OWNER without `:verify` noticing. A mid-session SYA claim made it halt with ~14.6k DOLA on the Ledger EOA. The documented resume converges.
4. **Timing is the cluster's real operating risk.** The ETH budget is stale (L-10, 4.7% slack), and a halt that outlives the window freezes migrated stakers (L-11). Both operator timing signals ignore the 6h start margin (two Q-01 findings). None of these loses funds, but they compound.
5. **Four decisions are for a human** (see "Human-review decisions"). Most consequential: whether L-09 stays Low, and whether L-10 reopens L-07.

## Coupling timeline

T0 is the **mined** `initiatedAt` of the initiate transaction, not the timestamp that script prints (see initiate Q-01).

```
T0                  initiate-dola-ys-withdrawal:broadcast mined
                    (status Initiated; nothing moves; 1 tx, 101,456 gas)
│
│  waiting period   status: "waiting"; cutover Phase 0 reverts (too early)
│
T0 + 6h             window opens. status: "EXECUTABLE"
│                   ├─ Phase 0 gate: T0+6h <= start < T0+78h − WINDOW_SAFETY_MARGIN (6h)
│                   │    so the cutover may START only in [T0+6h, T0+72h)
│                   ├─ Phases 1–6 (V1 → V2 migration, V2 paused since Phase 3)
│                   ├─ Phase 6b: record minter config → disable DOLA → EXECUTE
│                   │    (tx #43, must MINE <= T0+78h) → R → re-seed (#47/#48)
│                   │    → re-register → SYA repoint → retire 0x1760 (dead window #56→#57)
│                   └─ Phase 7 unpause/register V2 → Phase 8 asserts → patch → :verify
│
T0 + 72h            last legal START. status still says "cutover may broadcast now" (status Q-01)
│
T0 + 78h            window closes (execute lazily expires)
│
WINDOW LAPSE        ├─ halt BEFORE Phase 6: re-initiate, wait 6h, resume; stakers unaffected
                    │    (V1 still live)
                    └─ halt AFTER Phase 6, before the execute lands: every resume reverts in
                         Phase 0 ("window EXPIRED") before Phase 7 can unpause V2, so all
                         migrated stakers stay frozen for the halt + re-initiate + >= 6h
                         (L-11, fork-proven)
```

Once the execute has landed, the minter's autoDOLA principal is 0 and Phase 0 skips the window gate. From then on a lapse no longer blocks resumes.

## Anvil sequence achieved

| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | `initiate-dola-ys-withdrawal:preview` | PASS, READBACK OK, minter P = 14,594.562 DOLA | `01` |
| 1b | Initiate broadcast (`--unlocked`) | OK, 101,456 gas. Only the 3 `withdrawalStates[DOLA][minter]` slots written | `02` + state diff |
| 2 | Age `initiatedAt` by 6h1m (storage) | See limits below | — |
| 2b | `dola-ys-withdrawal:status` | EXECUTABLE | `03` |
| 2c | Same state aged to 75h | Status says "may broadcast now", but the cutover preview reverts on the margin | `04` |
| 3 | `stable-staker-v2-cutover:preview` | PASS for all phases and 11 GLOBAL_PAUSE stages. ETH_BUDGET SHORTFALL at the live balance | `05` |
| 3b | `:broadcast` at OWNER's live ETH | Preflight refuses, 0 txs | `06` |
| 3c | `:broadcast` with OWNER at exactly 0.00792 ETH | 67 txs, 22,982,701 gas. Completed with 4.7% of the margin left | `07` |
| 3d | Patch script | PATCH/FILL/SAME, key-set 57 = 57 | `08` |
| 4 | `:verify` | PASS (29 per-user credits), yet 0.0023 DOLA was left on OWNER | `09` |
| 4b–4d | Post-cutover status / initiate preview / smoke preview | "retired" / reverts "strategy is paused" / PASS | `10`, `10b`, `11` |
| 5 | `:broadcast` with a claim-equivalent skim injected after the local pass | tx #48 `noMintDeposit` reverts. Halt with 14,593.85 DOLA on OWNER | `12` |
| 5b–5c | Resume, then `:verify` | Re-derives R live, converges, PASS | `13`, `14` |
| 6 | Harness `test_R35_OBS04_windowLapseAfterPhase6_resumeBlocked_stakersFrozen` | PASS (stakers frozen, resume blocked) | `16` |

### Limits of the sequence

- **Oracle freeze forced storage ageing.** A real 6h `evm_increaseTime` makes the autoDOLA redeem revert `InvalidDataReturned()` (0x8d54ba1f) against the fork-frozen Chainlink feed. `initiatedAt` was therefore aged in storage, as the sponsor's own tests do. Wall-clock effects over the window were not exercised. These include price accretion over 6–78h, Chainlink heartbeats and other actors' transactions.
- **Unverified L-09 triggers.**
  - A **DOLA mint landing mid-session**, before `setStablecoinEnabled(false)` mines. There were 0 DOLA mints in the last 30 days, so this was not reproduced.
  - A **Tokemak valuation down-step** between session start and tx #43. Not reproduced. The skim trigger stood in for both.
- **Live bytecode not Etherscan-verified.** 0x1760 (YieldStrategyDola), the PhusdStableMinter and SYA were reasoned about from submodule source. Selectors and behaviour were corroborated on the fork only, not by verified-source equality.
- **Broadcast signer substitution.** `--unlocked` replaces `--ledger`, so Ledger signing latency, which is the exposure window for L-09, was not modelled.

## Findings across the cluster

Full text, evidence and recommendations are in [`qa-report.md`](../submissions/qa-report.md). Labels are per entry point, and Q-01 appears twice.

| Entry point | Label | Sev | Fingerprint | What | Mitigation | Where (`7ac6e70`) |
|---|---|---|---|---|---|---|
| stable-staker-v2-cutover | L-09 (`pps35l9`) | Low (borderline M) | `78cb5942d483` | Phase 6b re-seed `R` baked in the local pass. Excess DOLA can stay on OWNER unseen by `:verify`, or `noMintDeposit` reverts and halts the session | End the first leg after the execute so the resume reads the mined `R`; add an OWNER-residual check to `:verify`; fix the halt (b) NatSpec | [Cutover#L1116-L1145](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L1116-L1145), [#L166-L167](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L166-L167), [Verify#L318](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/VerifyStableStakerV2Cutover.s.sol#L318) |
| stable-staker-v2-cutover | L-10 (`pps35l10`) | Low, ⚠ INCOMPLETE FIX of L-07 | `72e528c8715f` | `CUTOVER_GAS_BUDGET` 22M was sized for 46 txs. The 67-tx session peaks at 25.16M, so `ETH_BUDGET\|OK` can precede `-32003` mid-Phase 6 | Re-derive from the 67-tx run (max cumulative used + signed limit), round up to ~27M, or compute in `:preview` | [Cutover#L411-L423](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L411-L423), [#L456-L486](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L456-L486) |
| stable-staker-v2-cutover | L-11 (`pps35l11`) | Low (QA/Low borderline) | `e6e1f293bbad` | A window lapse after a post-Phase-6 halt blocks Phase 7, so migrated stakers stay frozen | Document the freeze in the RE-INITIATE PATH; preferably let a lapsed resume run Phase 7 with DOLA minting kept off | [Cutover#L597-L645](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L597-L645) |
| stable-staker-v2-cutover | Q-05 (`pps35q5`) | QA | `df5f14bae8a7` | The `:broadcast` comment misses the second breaker dead window (#56→#57) and still says 46 txs | Rewrite the breaker paragraph together with the Q-04 fix | [package.json#L52](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L52) |
| stable-staker-v2-cutover | Q-06 (`pps35q6`) | QA (may be `dev`) | `9c4e21bb9fd7` | Committed merge-conflict markers break `local.json` parsing and `addresses.ts` | Resolve and regenerate; add a CI conflict-marker / JSON parse check | [local.json#L5-L9](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/local.json#L5-L9), [addresses.ts#L1-L5](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/addresses.ts#L1-L5) |
| dola-ys-withdrawal:status | Q-01 (id pending) | QA | `8633815e4b2b` | "EXECUTABLE - cutover may broadcast now" is printed in the last 6h and while paused | Split into may-START / too-late output, add a PAUSED override, share the margin constant | [DolaStrategyWithdrawalStatus.s.sol#L53-L60](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/DolaStrategyWithdrawalStatus.s.sol#L53-L60) |
| initiate-dola-ys-withdrawal | Q-01 (id pending) | QA | `4cdafc61037c` | The instruction ignores the 6h start margin; the timestamps are local-pass values | Print `expiresAt − 6h` as the start deadline, label the estimates, update story 090 | [InitiateDolaStrategyWithdrawal.s.sol#L181-L196](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/InitiateDolaStrategyWithdrawal.s.sol#L181-L196) |

**How the findings compound.** L-09 (revert branch) and L-10 are the two realistic halt sources inside the window. Either one, plus operator latency beyond `T0+78h`, triggers L-11. The two Q-01 findings raise the chance of a late start, which shrinks the margin before L-11 applies. None of these is merged, because each has an independent root cause and fix.

### Refuted / not filed (visible, with reasons)

Per-entry-point detail is in each `review.md`. Cluster-relevant items:

- **OBS-35-I2 (Temp.s.sol out-of-band execute): not filed (Law 3).** It needs a knowing out-of-band OWNER call inside a window the owner opened. The "pulls V1 value" framing is overstated because `_totalWithdraw` is pro-rata. The only real consequence is losing the minter cushion if autoDOLA is below par, and it is above par at 25990689.
- **OBS-35-05 / -06 / -09(iii) (mint-window reset, 38.58 DOLA routed into collateral, standing approval removed):** story-acknowledged or benign. -06 is opportunity cost, not loss.
- **OBS-35-08 (preview impossible before T0+6h):** ordering prescribed by story 092. Suggestion only: a preview-only simulated initiation.
- **OBS-35-09(i)/(ii):** documented deviations, judged justified.
- **OBS-35-07 (patch/tsc break):** refuted for the mainnet path. The residual dev breakage is filed as Q-06.
- **OBS-35-S1 (status has no chainid guard):** refuted, because the script is view-only and reverts rather than misreports.
- **OBS-35-10 (auto-complete, machine-approved stories):** noted; see the story-policy note.

## Carryover

| Label | Fingerprint | Ledger status | Run-35 disposition |
|---|---|---|---|
| L-08 (`pps34l8`) | `6022a9eb9989` | fix-pending | **Propose `fixed`.** `ERC4626_MAX_LOSS_BPS` went from 2 to 5 (story 088). Measured losses are 0.47 bps DOLA and 0.34 bps USDC. Residual: still enforced only in the local pass (L-09 class). A human applies `/ledger phoenix-phase-2-staging fixed 6022a9eb9989` |
| Q-04 (`pps34q4`) | `a62956952abd` | fix-pending | **Still live, possible incomplete fix.** The `:broadcast` Phase 7 overclaim is unchanged at `7ac6e70`. Fix in the same edit as Q-05, then `/recheck phoenix-phase-2-staging a62956952abd` |
| L-07 (`pps33l7`) | `d6896c6e843d` | fixed | Stays `fixed` pending human decision; L-10 carries `incompleteFixOf` |

The other stable-staker-v2-cutover entries (fixed L-01 to L-06, F-01, Q-02; wont-fix F-02, Q-01, F-03, Q-03) showed no regression and are unaffected by the delta. `ledger.json` was not modified by this review.

## Human-review decisions

1. **L-09: Low or Medium.** The classifier kept Low. Nothing is lost, the halt is loud on an attended path, the resume is fork-proven, and `:verify` covers registration and principal. Unlike run-22 M-01, which had no outcome verification, only OWNER's residual goes unchecked here. **Re-rate to Medium if:**
   - (a) a halt here can compound with a late-window start into L-11's staker freeze, which makes the timing controls below load-bearing; or
   - (b) pool count or size, or SYA claim frequency (currently 5 per 30 days), grows materially.
   Also consider (c): if the DOLA-mint or Tokemak down-step triggers are later shown to be frequent, the revert-branch likelihood is no longer under 1% per session.
2. **L-10: separate entry or reopen L-07.** The preflight mechanism from L-07 works; its constant went stale after stories 091 and 092. The auditor proposes keeping L-07 `fixed` and filing L-10 with `incompleteFixOf`. Reopening L-07 is the alternative if the team treats "budget covers the session" as L-07's scope.
3. **L-11: QA or Low.** Kept Low for its concrete effect on the availability of user funds, and below Medium because of the compound precondition and bounded, recoverable duration. If downgraded to QA, the label Q-06 is already taken by the conflict-marker finding and must not be reused.
4. **Q-06: move under `dev`.** The conflict markers affect the dev and UI toolchain, not the mainnet path. The finding relates to open dev L-07 `98e72721` ("local.json removed from git tracking"), which may no longer apply now that `local.json` is tracked again. Proposed: `/recheck phoenix-phase-2-staging 98e72721`, then re-attribute if confirmed. No status change is proposed.
5. **issueId for the two Q-01 findings.** Both derive to `pps35q1` under per-entry-point labelling, so both ledger entries carry `issueId: null`. A human should choose distinct IDs, for example by disambiguating the entry point, and record the convention in `docs/issue-id-scheme.md`. Until then, reference them by fingerprint (`8633815e4b2b` status, `4cdafc61037c` initiate).

## Tooling gaps

- **4naly3er crashed.** It exited 1 inside the solc 0.8.27 wasm compile with `TypeError: Cannot read properties of undefined (reading 'contents')`, most likely an import-resolution failure on the scripts' nested `lib/` remappings. The partial output was discarded rather than presented as a clean report. **This run has no automated QA baseline.** All seven findings come from manual review plus fork verification.
- **Run-33 PoC bit-rot.** The run-33 harness in `phoenix-phase-2-staging/work/test/audit-run33` has bit-rotted against `7ac6e70` and was not used as regression evidence this run. Per the recheck rules, a PoC that no longer compiles is inconclusive, not proof of a fix. The findings it covered rely on the run-35 fork run instead. Repair or retire it before any `/recheck` that depends on it.
- **Warp-based tests cannot see L-09.** The sponsor fork tests (`test/CutoverStableStakerV2Mainnet.fork.t.sol`, `test/InitiateDolaStrategyWithdrawal.fork.t.sol`) execute in a single EVM. They cannot reproduce drift between the local pass and mined calldata. Only a real multi-block broadcast, as run here, exposes it.

## Story-policy note

- All stories for this cluster (082–092, specifically 087, 090 and 092 cited in findings) resolved to exactly one document each, in the **`auto-complete`** state folder. That state is **not** listed in `registered-projects.json` → `storyPolicy` (`complete|incomplete|review|archive`). It was treated as metadata and the stories stayed in scope. `storyPolicy` should be extended to name `auto-complete`.
- Stories **087, 090 and 092 record machine approval, not human review.** The **090 vs 092 conflict** is therefore between two machine-approved documents that no human has reconciled:
  - story 090's "broadcast the cutover between executableAt and expiresAt"
  - story 092's `WINDOW_SAFETY_MARGIN` start gate

  The script follows 090 literally (initiate Q-01). The fix belongs in the story text as well as the script, and it is for the product owner, because the stories tree is read-only to the audit. Story 092's Decision 3 also still describes "a ~46-tx session", the same drift behind L-10.

## Pre-broadcast operator checklist (recommendations)

These are derived from the findings and do not replace the fixes. Until the fixes land, following this checklist removes most of the cluster's operating risk.

**Before initiating**
1. Schedule the cutover window before signing the initiate. Plan to **start the cutover early in `[T0+6h, T0+72h)`**, ideally within the first day. That leaves the widest margin before a post-Phase-6 halt could reach L-11's freeze at `T0+78h`.
2. Confirm the strategy is not paused and that no global pause is planned during the window (OBS-35-I3).
3. After the initiate mines, take `T0` from the `WithdrawalInitiated` event or from `dola-ys-withdrawal:status`, **not** from the initiate script's printed timestamps (initiate Q-01). Compute your own last start time as `T0 + 72h`.

**Before `:broadcast`**
4. Treat status "EXECUTABLE" as necessary but not sufficient. Also check that at least 6h remain to expiry, that `strategy paused: false`, and that `:preview` passes Phase 0 (status Q-01).
5. **Fund OWNER to a recomputed budget, not the printed `ETH_BUDGET`.** Use at least about 27M gas × `CUTOVER_GAS_PRICE_WEI` × 1.2 (L-10), and re-derive it if V1 staker counts have grown beyond DOLA 9 / USDC 13 / USDe 7. The same full budget is needed again for any resume.
6. Run `:preview` as close to the broadcast as practical, on the same block conditions, and re-check staker counts.

**During the session**
7. **Avoid SYA claim activity** between session start and the Phase 6b execute (tx #43). Coordinate with claim-NFT holders or schedule the session at a quiet time, and do not run protocol keepers that skim DOLA surplus (L-09 revert branch). Avoid sessions straddling known Tokemak valuation updates where possible.
8. If the session halts at or after Phase 6b, **resume promptly.** The resume re-reads `R` live and converges (L-09). Until then ~14.6k DOLA of phUSD collateral sits on the Ledger EOA, and a delay risks crossing `T0+78h` (L-11).
9. If the session halts between tx #56 (`setPauser(OWNER)`) and tx #57 (`Pauser.unregister`), the protocol-wide breaker is dead until OWNER calls `Pauser.unregister(0x1760…)`. Do not rely on the `:broadcast` comment (Q-05, Q-04). Use the halt (g) NatSpec.

**After the session**
10. Beyond `:verify`, **manually check `DOLA.balanceOf(OWNER)`** against its level before the execute (`minterMove.ownerDolaBeforeExec`). Also compare the minter's sDOLA principal against the DOLA amount in the execute receipt's `Transfer`, not against the recorded `R` (L-09 excess branch). Deposit or record any residual.
11. If the window lapsed after Phase 6 but before the execute, expect V2 stakers to stay frozen until re-initiation plus 6h (L-11). Communicate this to users, and consider an attended manual Phase 7 unpause, with DOLA minting kept disabled, instead of waiting.
