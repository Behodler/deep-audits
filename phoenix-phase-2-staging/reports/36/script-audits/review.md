# Cluster script review: DOLA withdrawal + StableStaker V2 cutover, fix wave (run 36)

- **Run**: `phoenix-phase-2-staging-36`, cluster script audit of three coupled entry points (package.json L49–59)
- **Source**: [Behodler/phoenix-phase-2-staging @ `91ed727`](https://github.com/Behodler/phoenix-phase-2-staging/tree/91ed727138e09720a28e70707d7d3df40a7d7ee2), branch `master`, read-only
- **Delta audited**: `7ac6e70..91ed727`, stories **093–097** (the response to run 35), all resolved to exactly one document each in `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/`
- **Entry points**:
  - `stable-staker-v2-cutover` `:preview` / `:broadcast` / `:verify` (L49–55) — [intent](./stable-staker-v2-cutover/intent.md), [side effects](./stable-staker-v2-cutover/side-effects.json), [story ↔ mitigation map](./stable-staker-v2-cutover/story-mitigation-map.md)
  - `initiate-dola-ys-withdrawal` `:preview` / `:broadcast` (L56–58) — [intent](./initiate-dola-ys-withdrawal/intent.md), [side effects](./initiate-dola-ys-withdrawal/side-effects.json)
  - `dola-ys-withdrawal:status` (L59) — [intent](./dola-ys-withdrawal-status/intent.md), [side effects](./dola-ys-withdrawal-status/side-effects.json)
- **Mode**: stronger than preview. Live reads at mainnet block **25994830**. **Real `--broadcast --unlocked` runs on an anvil mainnet fork at block 25994908** (chain-id 1, OWNER impersonated): the happy path in two legs, and separately story 096's lapsed-window path. **Nothing was broadcast to mainnet.** Execution ran from `work/` (clean at `91ed727`). Evidence lives under [`fork-logs/`](./fork-logs/); `drive.sh`, `drive-pending.sh` and `gas.js` there are audit harness, not sponsor code.
- **Primary reports**: [`../submissions/M-01.md`](../submissions/M-01.md) (authoritative text for **M-01**, formerly L-12), [`../submissions/qa-report.md`](../submissions/qa-report.md) (0 Low / 0 Centralization this run; carryover triage table), [`../submissions/spec-conformance.md`](../submissions/spec-conformance.md) (M-01 cross-listed as F-04), [`../submissions/carryover/qa-report-34.md`](../submissions/carryover/qa-report-34.md), [`../submissions/carryover/qa-report-35.md`](../submissions/carryover/qa-report-35.md)
- **Ledger**: not written by this review.

## Conclusions

1. **The fix wave works.** All seven open or fix-pending run-34/35 entries on this cluster are closed by the code at `91ed727`, and so is the `wont-fix` L-11. Human triage **applied `fixed` to all eight on 2026-09-17** (see [Prior-entry verdicts](#prior-entry-verdicts)).
2. **The composition still holds on real bytecode.** initiate → status START-OK → leg 1 (44 txs, ends at the execute) → patch tail exit 2 (expected) → leg 2 `:preview` → leg 2 (21 txs) → patch → `:verify` PASS → post-cutover status "none pending". Every gate failed closed where it should.
3. **One new finding: M-01 (Medium; filed as L-12, re-rated by human triage 2026-09-17).** Story 096's own fix introduces it. On the lapsed-window path the `:broadcast` tail stops at the address patcher. As a result, the `:verify` that the story relocated the live V2 balance checks to never runs, and `mainnet-addresses.ts` keeps V2 at `0x0` while V2 is live. The owner confirmed the frontend reads `StableStakerV2` from that file, which makes this an availability impact for at least 6h.
4. **0 High / 1 Medium (M-01) / 0 Low**, 0 regressions, 0 incomplete fixes, 0 known-issue suppressions (the KI source file `src/known-issues.md` is absent at `91ed727`, so the cache has no authority).
5. **Stories and audit disagree in five places** (story 094's 1.5R approve and rejected option 2, story 095's rejected dynamic budget, story 097's copied constant and narrowed override, story 096's extension of a `wont-fix` finding). The auditor accepts every rejected mitigation on evidence. The one place a story's choice did *not* close its promise is story 096, and that is L-12.
6. **L-11's ledger/story contradiction is resolved.** The owner had triaged it `wont-fix`, but story 096 implemented the fix anyway. On 2026-09-17 human triage moved it to `fixed` on the run-36 evidence.

## Stories vs run-35 audit mitigations

This section is the direct answer to "where do the stories and the audit disagree, and does the story's choice close the defect?" Rationale quotes are **verbatim story text** from the documents under `auto-complete/phStaging2-stable-staker-v2/`. Where the classifier paraphrased a story (notably its rendering of story 096 Revision Decision 2), the paraphrase is not used; the real text is quoted instead. All five stories are machine-approved ("story-batch workflow"), not human-reviewed.

### At a glance

| Story | Finding | Audit recommended | Story chose | Agreement | Run-36 verdict |
|---|---|---|---|---|---|
| 093 | Q-06 `9c4e21bb` | Resolve markers, regenerate; CI marker + JSON.parse check | Regenerate from fresh DeployMocks (2 more files than asked); CI guard before fmt/build | **Adopted, extended** | **Closes.** Propose `fixed` |
| 094 | L-09 `78cb5942` | Option 1 (end leg after execute) **or** option 2 (conservative tranche + sweep); verifier residual + execute-log bound; fix halt (b) NatSpec | Option 1 + verifier checks; **option 2 rejected**; **plus human-decided 1.5R approve**; mined-R from **summed** logs | **Adopted / rejected / extended** | **Closes.** Propose `fixed` |
| 095 | L-10 `72e528c8` | Re-derive ~27M, keep 1.2×, state staker counts; **"better still" compute in `:preview`** | Fixed 27M constant; **dynamic budget explicitly declined** | **Partial** | **Closes at today's counts.** Propose `fixed` |
| 095 | Q-05 `df5f14ba`, Q-04 `a6295695` | Rewrite breaker paragraph; Q-04 *optionally* harden the GLOBAL_PAUSE probe | Docs rewritten, 1-based per-leg counts; probe hardening not done | **Adopted (docs)** | **Closes.** Propose `fixed` for both |
| 096 | L-11 `e6e1f293` (wont-fix → **fixed** 2026-09-17) | Minimum: runbook note. Preferred: lapsed resume runs Phase 7, 6b pending, DOLA minting off | Preferred mitigation, **extended** (deferral beyond "lapsed", sticky verifier-relaxation marker, new status) | **Ledger conflict; extends audit** | **L-11 hazard closed; introduces M-01 (was L-12)** |
| 097 | status Q-01 `8633815e` | Split phases, paused override, **import** shared margin constant | Split + override; constant **copied** with drift test; override **not on PHASE_NONE** | **Partial / deviates** | **Closes.** Propose `fixed` |
| 097 | initiate Q-01 `4cdafc61` | Print margin + deadline, label local-pass, point to status; PO updates story-090 AC | All three outputs; story-090 AC left to PO | **Adopted** (AC outside repo) | **Closes.** Propose `fixed` |

### Story 093 → Q-06 (committed merge-conflict markers)

- **Audit recommended:** "Resolve the conflicts … regenerate `local.json` from the latest dev deploy. Add a CI or pre-commit check that fails on conflict markers … and runs `JSON.parse` over `server/deployments/*.json`."
- **Story chose:** a fresh `deploy:local:forge -> extract:addresses -> generate:ts-anvil` regeneration covering `local.json`, `addresses.ts`, plus `local-addresses.ts` and `progress.31337.json` (not named by the audit), and a CI step later moved ahead of `forge fmt`.
- **Story rationale (verbatim):** "The report put Q-06 under the cutover entry point, with a human-review note that it may belong under `dev` (dev L-07 pps28l7). This story fixes the problem whatever the label. Re-labelling the ledger is out of scope."
- **Disagreement:** none material. The story went further than asked. Residue it discloses itself: CI remains red at `forge fmt --check` (pre-existing, repo-wide).
- **Run-36 verdict: closes.** At `91ed727` the marker `git grep` over tracked non-lib files is empty, every `server/deployments/*.json` parses, and the CI guard runs before fmt/build.

### Story 094 → L-09 (Phase 6b re-seed `R` baked in the local pass)

- **Audit recommended:** "Never sign an amount derived from state that an earlier signed transaction changes. Either option below works: 1. **End the first broadcast leg right after the execute.** … 2. **Re-seed a deliberately conservative amount**, then sweep the remainder …" plus an OWNER-residual `require` and a bound "against the actual WithdrawalExecuted / DOLA Transfer amount", and a halt (b) NatSpec fix.
- **Story chose:** option 1 (a broadcast-only leg end with status `awaiting_reseed`), the verifier residual equality, a mined-R lower bound from the **sum** of `Transfer(0x1760→OWNER)` logs since `cutoverStartBlock`, and an approve of `ceil(1.5R)` sent only when the allowance is below R.
- **Story rationale (verbatim):**
  - **HUMAN DECISION:** "set the approve as R*1.5".
  - "Option 2 (a conservative tranche plus a sweep) was rejected: a 5 bps margin would still revert on the audit's 0.27% skim injection."
  - On the allowance: "The allowance is harmless because noMintDeposit is onlyOwner and pulls from msg.sender. Revoking a pre-existing allowance is out of scope."
- **Disagreements:**
  1. **Option 2 rejected.** Accepted. The stated reason is correct, and option 1 alone closes both L-09 branches.
  2. **1.5R approve was never recommended.** The story itself concedes it does not fix L-09. It is harmless (`noMintDeposit` is onlyOwner and pulls from `msg.sender`), and on today's state it is dead code: OWNER→minter allowance is already `type(uint256).max`, so leg 2 signed no approve.
  3. **Summed logs instead of "the execute receipt logs" (OBS-36-C04).** No finding. Summing can only raise the lower bound, so it **cannot false-pass**. An over-deposit is caught separately by the residual equality. A false *fail* needs an OWNER-originated DOLA outflow from 0x1760 (`emergencyWithdraw` / `withdrawAsOwner`, both onlyOwner): loud and owner-controlled. A double execute is impossible.
- **Run-36 verdict: closes, empirically.** Real two-leg anvil broadcast ([`05-*`](./fork-logs/05-anvil-cutover-broadcast-leg1.log), [`08-*`](./fork-logs/08-anvil-cutover-broadcast-leg2.log), [`10-*`](./fork-logs/10-anvil-verify.log)):
  - Leg 1: 44 txs, the last is `totalWithdrawal(DOLA, minter)`, no approve/`noMintDeposit` signed, status `awaiting_reseed`, patch tail exits 2 with "LEG 1 ENDED AFTER THE MINTER EXECUTE (story 094) … This stop is expected."
  - Local-pass R `14620768299424230618909` vs mined R `14620769498660152819444` (+0.0012 DOLA). Before story 094 that difference would have been stranded on OWNER unseen.
  - Leg 2 (21 txs) re-seeded the **mined** R; OWNER DOLA returned to 0 (= `ownerDolaBeforeExec`).
  - `:verify`: "OWNER DOLA residual 0; mined R (Transfer logs) / transfers: 14620769498660152819444 1", CUTOVER VERIFIED.
  - The sponsor's skim-injection test (mined R < local R, the revert branch) passes ([`01`](./fork-logs/01-sponsor-story-tests.log), 49/49).

### Story 095 → L-10 (stale gas budget), Q-05 (stale breaker runbook), Q-04 (halt-5 overclaim)

- **Audit recommended (L-10):** "Re-derive the budget from the 67-transaction session … Round up, for example to 27M, and keep the 1.2× factor. State the staker counts … **Better still, have `:preview` compute the budget instead of relying on a constant.**"
- **Audit recommended (Q-05 / Q-04):** rewrite the breaker paragraph naming both dead windows and the Phase 7 coverage gaps; Q-04 "**Optionally**, extend the Phase-8/preview `GLOBAL_PAUSE` probe to assert that V2 (and Antimatter) are actually paused".
- **Story chose:** `CUTOVER_GAS_BUDGET = 27_000_000` with 1.2×, NatSpec derived from the pre-094 67-tx run; runbook and NatSpec rewritten with 1-based per-leg indices; no dynamic budget; no probe hardening.
- **Story rationale (verbatim):**
  - "**HUMAN DECISION:** budget = 27,000,000 gas, keeping the 1.2x factor."
  - Checklist: "Optional (not required): the report's suggestion that :preview compute the budget from simulated gas is out of scope; do not implement."
- **Disagreements:**
  1. **Dynamic `:preview` budget declined.** Accepted, with a bounded residual (next bullet). The NatSpec tells the operator to re-derive if staker counts grow.
  2. **No post-094 re-measurement in the story.** The audit did it instead.
  3. **Q-04 probe hardening not done.** Accepted: it was offered as optional, the existing probe already asserts every *registrant* is paused, and the uncovered case is exactly the unregistered gap that is now documented.
- **Run-36 verdict: closes at today's staker counts.** Re-measured on the real two-leg anvil run at 25994908 with counts unchanged (DOLA 9 / USDC 13 / USDe 7):
  - Leg-1 binding peak (max of cumulative gas used + signed limit) **25,173,447** (USDe migrate, tx 42); leg-2 peak 1,297,700.
  - Against the 27M constant: **7.26% headroom**. The funded amount with 1.2× corresponds to 32.4M gas.
  - Each extra USDe staker adds about 1.15M to the peak, so **about 6 more USDe stakers** fit before the ETH actually funded under the 1.2× factor would run out mid-session. Growth beyond that re-opens the L-10 class; the re-derive note is the only guard.
  - The NatSpec's "67-tx figure stays an upper bound" is 10,346 gas short at this block (state drift, 0.04%). Immaterial.
  - Q-05/Q-04 docs: both dead windows named; per-leg counts verified against the anvil run (V1 window txs 1→2; autoDOLA `setPauser`/`unregister` at leg-2 txs 11→12); 44 / 21 match.

### Story 096 → L-11 (lapsed window after Phase 6 freezes V2 stakers)

- **Ledger status of L-11 at scan time: `wont-fix`** (human triage moved it to `fixed` on 2026-09-17). triageReason (verbatim): "L-11 is expected so we'll just have to respond to crises in the moment. That's the purpose of 72 hours."
- **Audit recommended:** "**Minimum:** in the RE-INITIATE PATH runbook, state that all V2 stakers stay paused until the re-initiated window opens. **Preferred:** when a resume past Phase 6 finds the window has lapsed, let it run Phase 7 … and leave Phase 6b pending … keep DOLA minting disabled (6b step (a)) in that branch."
- **Story chose:** the preferred mitigation, extended:
  - deferral also triggers when the window is not yet executable, is in its 6h wait, or has under 6h left;
  - a new progress status `awaiting_minter_window`; the verifier reverts `Phase6b: PENDING` after checking everything else;
  - a sticky `minterMove.v2LiveBeforeMinterMove` marker that makes the post-completion `:verify` skip the two live-balance checks.
- **Story rationale (verbatim):**
  - "The report's preferred mitigation was chosen over the doc-only minimum, because the finding affects whether users can reach their funds."
  - Decision 5: "The `:broadcast` tail therefore stops at `:verify` by design. The script output and the runbook both say so."
  - Revision attempt 2, Decision 2, item 2: "**Pending-state verify**: the `:verify` in the lapsed-window `:broadcast` tail runs right after V2 goes live. … That is where the live checks run on this path."
  - Revision attempt 2, Decision 2, rationale: "The live-balance checks only mean something right after V2 goes live. The marker moves them to that point on this path instead of dropping them, and keeps them scoped to this path."
  - Disclosed risk: "A progress file carrying the marker by mistake relaxes the two live checks on a normal cutover. The file is operator-controlled and the marker is only written on the pending branch."
- **Disagreements:**
  1. **With the ledger.** The owner declined a fix; the story shipped one. Neither document records the reversal (informational item below).
  2. **Beyond the audit.** The verifier relaxation keyed on an operator-controlled progress-file flag was never proposed. It is sound *only if* the relocated checks really run, which is where it breaks (M-01, formerly L-12).
  3. **Narrower than the audit's scenario.** A halt *inside* Phase 6 (stakers split across paused V1 and V2) still hard-fails; the story rejected that alternative. Not re-raised: L-11 is `wont-fix` and this is its residue.
- **Run-36 verdict: the L-11 hazard is closed; the story's own verification promise is not kept.** Real broadcast on the lapsed-window path ([`pending-path/`](./fork-logs/pending-path/)):
  - P3: leg 1 halted at the execute; window lapsed by storage; P4 status "expired".
  - P6: resume `:broadcast` exits 0, progress `awaiting_minter_window`, `v2LiveBeforeMinterMove: true`, **V2 `paused=false`**, DOLA minting disabled. Stakers can reach funds; L-11's freeze is gone.
  - P7: the npm tail's patcher prints `ERROR (2): deploymentStatus is "awaiting_minter_window", expected "completed"`, so `&&` skips `:verify` and `:preview`, and `StableStakerV2` stays `0x0` in `mainnet-addresses.ts`.
  - P8: a manual `:verify` reverts `verify: Phase6b: PENDING … Phases 1-7, Phase 8's pending shape and 29 per-user credits (incl. live V2 balances) verified`. The check works; it is simply never chained. → **M-01 (formerly L-12)**.

### Story 097 → status Q-01 and initiate Q-01 (6h start margin not surfaced)

- **Audit recommended (status):** "Split the phase output … When `strategy.paused()` is true, print an override … **Import `WINDOW_SAFETY_MARGIN` from a shared constant instead of duplicating it.**"
- **Audit recommended (initiate):** "Print 'start the cutover between executableAt and expiresAt − 6h (WINDOW_SAFETY_MARGIN)'. Label the printed timestamps as local-pass estimates, and point the operator to `npm run dola-ys-withdrawal:status` … Update story 090's AC text to include the margin."
- **Story chose:** pure phase helpers in `DolaStrategyWithdrawalBase` using the audit's exact strings; the margin constant **copied** with a non-fork drift-guard test; the paused override on every pending phase but **not** `PHASE_NONE`; all three initiate output changes; story-090 AC left alone.
- **Story rationale (verbatim):**
  - "The constant is copied into the base with a drift-guard test rather than extracted from the cutover. That avoids touching cutover window logic owned by 094–096 and keeps the dependency SOFT."
  - "Minting issueIds for the two Q-01 findings and updating story 090's AC text are human/ledger tasks, out of scope."
- **Disagreements:**
  1. **Copy instead of import.** Accepted: the drift guard (`test_windowSafetyMargin_matches_cutover`) is a non-fork test in CI and passes, so drift fails CI rather than the compiler.
  2. **No paused override on `PHASE_NONE`.** Accepted: with nothing pending the only follow-on action is initiate, whose preflight `require(!strategy.paused())` refuses loudly; the raw `strategy paused:` line still prints.
  3. **Story-090 AC not updated.** A product-owner task outside the repo, not a code defect. Story 090 still says "between executableAt and expiresAt".
- **Run-36 verdict: closes both.** On anvil the status output agreed with the cutover's actual gate at every stage: WAITING, "EXECUTABLE - cutover may START (>6h left)" (leg 1 started), "expired" (lapsed resume deferred), "none pending" after completion. Last-6h and paused cases are covered by passing sponsor tests. Initiate prints the margin line, start deadline and LOCAL-PASS ESTIMATE labels; estimate `initiatedAt` 1789619459 vs mined 1789619475 (+16 s), so the label is accurate.

### L-11 `wont-fix` vs story 096 (resolved 2026-09-17)

> **Resolved.** Human triage chose option (a) on 2026-09-17: L-11 is now `fixed`. The original note is kept below for the record.

L-11 (`pps35l11`, `e6e1f293bbad`) is `wont-fix` in the ledger, yet story 096 implements its preferred mitigation and run 36 verified it on a real broadcast. This review does **not** re-escalate L-11, does not carry it over, and does not touch its entry. The human should either:

- (a) move it to `fixed` on the run-36 evidence: `/ledger phoenix-phase-2-staging fixed e6e1f293bbad`, or
- (b) keep `wont-fix` and record that story 096 superseded the triage.

Either way **M-01 (formerly L-12) stays an independent open entry**: a `wont-fix` on L-11 disposes of L-11 only and must not suppress the defect its fix introduced.

## 1. Does it do what it intends?

| Entry point | Intent (stories 090–097) | Verdict | Evidence |
|---|---|---|---|
| `initiate-dola-ys-withdrawal` | Initiate the minter's DOLA withdrawal from 0x1760; print the start window with the 6h margin, labelled as local-pass estimates | **Yes.** Only `withdrawalStates[DOLA][minter]` written: `(mined ts, Initiated, 14594562039048160037533)` | [`03`](./fork-logs/03-anvil-initiate-broadcast.log), [side effects](./initiate-dola-ys-withdrawal/side-effects.json) |
| `dola-ys-withdrawal:status` | Report a phase that matches the cutover's real start gate, with a paused override | **Yes**, at every observed stage | [`04`](./fork-logs/04-anvil-status-startok.log), [`P4`](./fork-logs/pending-path/P4-status-lapsed.log), [`11`](./fork-logs/11-anvil-status-postcutover.log) |
| `stable-staker-v2-cutover` happy path | V1 → V2 migration, minter move on mined R in two legs, patch, verify | **Yes.** Converged; `:verify` PASS with residual 0 | [`05`–`10`](./fork-logs/) |
| `stable-staker-v2-cutover` lapsed-window path (096) | Unpause V2 on a lapsed resume, leave 6b pending, **tail stops at `:verify`** which runs the live V2 balance checks | **Partly.** V2 unpaused and 6b pending as intended; the tail stops at the patcher instead of `:verify` (**M-01**) | [`pending-path/`](./fork-logs/pending-path/) |

## 2. Unintended side effects

- **M-01** (formerly L-12): on the 096 path the live V2 per-user / per-pool balance checks are silently dropped from automatic verification, and the address book lags V2 going live by at least the re-initiate + 6h wait.
- **C05, collateral on OWNER between legs (not a finding).** Every broadcast now leaves ~14.6k DOLA (`14620769498660152819444` wei after leg 1, [`06b`](./fork-logs/06b-owner-dola-between-legs.txt)) on the trusted OWNER EOA for the operator latency between legs. Before story 094 that only happened on a halt. The story chose this knowingly; leg 2 is idempotent and state-gated. Informational: a halt *at* the execute (P3) records `awaiting_reseed` even though the execute reverted, because status is written in the local pass. Harmless: forge exits 1, so the tail never runs, and the resume re-derives from chain and converged.
- **1.5R standing allowance** (story 094): harmless and currently unreachable (allowance already max).
- **Marker-driven verifier relaxation** (story 096 disclosed risk): an operator-controlled progress file carrying `v2LiveBeforeMinterMove` by mistake would skip two live checks on a normal cutover. Not filed on its own (Law 3, knowing edit of an operator file); it is load-bearing for M-01's secondary impact.

## 3. Knock-on / cluster problems

- **M-01 couples story 094's patcher to story 096's new status.** Story 094 taught `loadProgress` one non-completed status (`awaiting_reseed`); story 096 added a second (`awaiting_minter_window`) without a branch. The sponsor test `test_fork_096_pendingWithdrawThenCompleted_verifierPasses` calls the verifier directly and never exercises the npm chain, and story 096's own second review (L331) also assumed "whose `:broadcast` tail chains `:verify` again", so the gap passed two machine reviews.
- **L-10 residual under growth.** The 27M constant is correct today with ~6 USDe stakers of funded slack; the dynamic budget the audit preferred is the only thing that would remove the dependency on the re-derive note.
- **Timing chain from run 35 is defused.** L-09 (halt source) and L-11 (freeze on lapse) are both closed, and the two Q-01s now print the true start deadline, so the run-35 compounding path (late start → halt → lapse → frozen stakers) no longer ends in a freeze. It ends in M-01 (a verification gap plus the address-book `0x0` window) instead.

## Findings register

Full text in [`M-01.md`](../submissions/M-01.md); faithfulness cross-listing F-04 in [`spec-conformance.md`](../submissions/spec-conformance.md); record [`../findings/medium/stable-staker-v2-cutover__M-01.json`](../findings/medium/stable-staker-v2-cutover__M-01.json). Coded PoC: `work/test/audit-run36/M01PendingTailPoC.t.sol` (runner `run-poc.sh`, validation log `reports/36/pocs/M-01-validation.log`, diff `reports/36/pocs/M-01-poc.diff`). This run has no Low or Centralization findings ([`qa-report.md`](../submissions/qa-report.md)).

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| M-01 (`pps36m1`, `cf684d5dc289`; was L-12 `pps36l12`) | **Medium** (re-rated from Low by human triage 2026-09-17) | On story 096's lapsed-window resume, `patch-mainnet-addresses-stable-staker-v2.js` `loadProgress` has no `awaiting_minter_window` branch and exits 2, so `&&` never reaches `:verify`. **Availability (stated assumption: frontend reads `StableStakerV2` from `mainnet-addresses.ts`, owner-confirmed):** V2 is live and unpaused with all stakers migrated, but the address book holds `StableStakerV2: 0x0` for at least 6h, until a completed run patches it. **Coverage:** the pending-state `:verify`, the only run of the live V2 `userInfo >= credited` / `totalStaked >= floor` checks, never runs automatically. After 6b completes, the sticky marker skips those checks (an intentional skip, L602; no asset loss shown). Fork-proven (pending-path P6–P8) and by the coded PoC. | (1) Add a patcher `awaiting_minter_window` branch that fills only `StableStakerV2` and `Antimatter` (fill-once), leaves the DOLA strategy keys and finished-cutover comments untouched, and **exits 0** so the tail proceeds. (2) Because the pending `:verify` reverts `Phase6b: PENDING` by design, either make that state exit 0 with a distinct PENDING report (never `CUTOVER VERIFIED`), or keep the revert and have the patcher and runbook say explicitly that `:verify` runs next and must end in PENDING. (3) Fix the runbook (package.json L49), `_printMinterMovePending` L2262, and the verifier NatSpec L78–83 / comment L602–603. (4) Add guard tests beside `test_broadcastChainsVerifyBeforePreview`: a patcher run on an `awaiting_minter_window` fixture (exit 0, V2/Antimatter filled, DOLA keys unchanged), plus the verbatim tail with `npm` shadowed, asserting that `:verify` is invoked. **Until fixed:** run `:verify` by hand immediately after a pending resume and hand-fill V2/Antimatter in the address book. | [patch-mainnet-addresses-stable-staker-v2.js#L70-L89](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727138e09720a28e70707d7d3df40a7d7ee2/scripts/patch-mainnet-addresses-stable-staker-v2.js#L70-L89); [Cutover#L2251-L2263](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727138e09720a28e70707d7d3df40a7d7ee2/script/CutoverStableStakerV2Mainnet.s.sol#L2251-L2263); [Verify#L490](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727138e09720a28e70707d7d3df40a7d7ee2/script/VerifyStableStakerV2Cutover.s.sol#L490), [#L564](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727138e09720a28e70707d7d3df40a7d7ee2/script/VerifyStableStakerV2Cutover.s.sol#L564), [#L601](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727138e09720a28e70707d7d3df40a7d7ee2/script/VerifyStableStakerV2Cutover.s.sol#L601); [package.json#L49](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727138e09720a28e70707d7d3df40a7d7ee2/package.json#L49), [#L53](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727138e09720a28e70707d7d3df40a7d7ee2/package.json#L53) |

**Why Medium, and its limits.** The rating rests on availability under a stated, owner-confirmed assumption: the frontend resolves `StableStakerV2` from `mainnet-addresses.ts`, so during the at-least-6h pending window UI users cannot reach their live V2 positions. The PoC proves the address book says `0x0` while V2 is live; it does not run the UI. Future aggravator: the UI will also read `Antimatter` from the file. The verification-coverage loss is secondary. The post-completion skip is intentional in source, so turning it into asset loss would need a second, independent credit bug, and none is known (29 credits verified). Even a chained pending `:verify` reverts `Phase6b: PENDING` by design, so the practical difference today is that the live checks do not run and the addresses are not patched. The path is attended and fails loudly, but the runbook, NatSpec and console all promise a stop at `:verify`, so this is a Law-3 footgun.

## Prior-entry verdicts

None of these is flagged at `91ed727`. **Human triage applied `fixed` to all eight on 2026-09-17** and minted issueIds for the two Q-01 entries. The ledger was updated by that triage, not by this review.

| Label (issueId) | Fingerprint | Entry point | Ledger before | Ledger now | Evidence |
|---|---|---|---|---|---|
| L-09 (`pps35l9`) | `78cb5942d483` | cutover | fix-pending | **fixed** (applied 2026-09-17) | Two-leg broadcast re-seeded mined R; OWNER residual 0; `:verify` mined-R bound |
| L-10 (`pps35l10`) | `72e528c8715f` | cutover | fix-pending | **fixed** (applied 2026-09-17) | Peak 25,173,447 vs 27M, 7.26% headroom; ≈6 more USDe stakers of funded slack |
| Q-04 (`pps34q4`) | `a62956952abd` | cutover | fix-pending | **fixed** (applied 2026-09-17) | Halt-5 overclaim corrected in doc key and NatSpec; optional probe hardening declined, residual documented |
| Q-05 (`pps35q5`) | `df5f14bae8a7` | cutover | open | **fixed** (applied 2026-09-17) | Both dead windows named; 44/21 per-leg counts match anvil |
| Q-06 (`pps35q6`) | `9c4e21bb9fd7` | cutover | open | **fixed** (applied 2026-09-17) | No markers; all deployments JSON parse; CI guard |
| Q-01 (`pps35q7`) | `8633815e4b2b` | status | open | **fixed** (applied 2026-09-17; issueId minted) | Phase output agreed with cutover gate at every anvil stage; sponsor last-6h/paused tests pass |
| Q-01 (`pps35q8`) | `4cdafc61037c` | initiate | open | **fixed** (applied 2026-09-17; issueId minted) | Margin, deadline, LOCAL-PASS labels, status pointer printed; estimate vs mined +16 s |
| L-11 (`pps35l11`) | `e6e1f293bbad` | cutover | wont-fix | **fixed** (applied 2026-09-17) | Hazard resolved by story 096 on a real broadcast (V2 unpaused on lapsed resume); spawned M-01 (was L-12), which stays independent |

The remaining entries on these entry points (L-01..L-08, Q-02 `fixed`; F-02, F-03, Q-01 `ca095edf`, Q-03 `wont-fix`) showed no regression and are unaffected by the delta.

## Non-findings (visible, with reasons)

- **OWNER ETH shortfall: 0.006425 ETH held vs 0.00972 ETH required (27M × 0.3 gwei × 1.2).** `:preview` prints `ETH_BUDGET|SHORTFALL … (TOP UP BEFORE :broadcast)`. This is the L-07 preflight working as designed (run-34 precedent), not a finding. **Operational prerequisite: the operator must top OWNER up by at least 0.003295 ETH before `:broadcast`, and each leg's preflight checks the full budget again.**
- **C05, collateral on OWNER between legs.** ~14.6k DOLA sits on the trusted OWNER EOA between leg 1 and leg 2. Knowingly chosen by story 094; leg 2 is idempotent. Operator guidance: run leg 2 promptly once the execute has mined.
- **C04, mined-R from summed Transfer logs.** Cannot false-pass (see story 094 above).
- **Attempt-1 stale-oracle revert (fork artifact).** At block 25994830 the DOLA Chainlink round had about 6 minutes left; on the non-updating anvil fork the execute reverted `InvalidDataReturned()`. Archived under [`attempt1-block25994830-oracle-stale/`](./fork-logs/attempt1-block25994830-oracle-stale/); the run was redone at 25994908. On mainnet the feed heartbeats, so nothing to file. Future rehearsals must keep the round fresh for the whole session.
- **"67-tx figure stays an upper bound" NatSpec off by 10,346 gas.** State drift, 0.04%, immaterial.
- **Story 096 halt-inside-Phase-6 still hard-fails.** Residue of L-11 (`wont-fix` at scan time, `fixed` 2026-09-17); not re-raised.

## Tooling gaps

- **4naly3er crashed** (exit 1 in the solc-0.8.27 wasm compile, `TypeError: Cannot read properties of undefined (reading 'contents')`, same as run 35). No report was written, so **this run has no automated QA baseline**. L-12's root cause is in JavaScript, which 4naly3er does not analyse anyway.
- **Known-issues source absent.** `src/known-issues.md` does not exist at `91ed727`; no KI suppression was applied.
- **UI dependency on `mainnet-addresses.ts` not run by the audit.** No frontend was run. The owner confirmed on 2026-09-17 that the frontend reads `StableStakerV2` from the file, and M-01's Medium rating rests on that stated assumption.

## Outstanding human actions

1. **Fund OWNER** to at least 0.00972 ETH (top-up ≥ 0.003295 ETH at the live balance) before any `:broadcast`.
2. **Product owner: edit story 090's acceptance criterion** from "between executableAt and expiresAt" to include the 6h `WINDOW_SAFETY_MARGIN` (start by `expiresAt − 6h`). The stories tree is read-only to the audit.
3. **Fix M-01** (`pps36m1`, `cf684d5dc289`) as described in [`M-01.md`](../submissions/M-01.md), and triage it `fix-pending` (not `acknowledged`) while the fix is owed. Until it lands, on any lapsed-window resume run `:verify` by hand immediately and hand-fill `StableStakerV2`/`Antimatter` in `mainnet-addresses.ts`.
