# Story ↔ audit-35 mitigation map (stories 093–097)

- Source: `phoenix-phase-2-staging/src` @ `91ed727`; delta `7ac6e70..91ed727`
- Audit-35 recommendations quoted from `reports/35/submissions/qa-report.md`. Q-04's recommendation is quoted from `reports/35/submissions/carryover/qa-report-34.md`.
- Ledger statuses were read with `jq` at the start of run 36. The ledger was not written.
- Story docs: `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/`. All five are in `auto-complete`, which counts as complete. They were machine-approved, not human-reviewed.
- The stories have no heading named "Acceptance Criteria". Their `## Checklist` items act as the acceptance criteria and are quoted verbatim below.

## Verdict legend

- **ADOPTED**: the story does what the audit recommended.
- **PARTIAL**: the story does some of it, or adds changes the audit did not ask for.
- **DEVIATES**: the story does something different from the audit's recommendation.
- **REJECTED**: the story explicitly declines an option the audit offered.
- **LEDGER CONFLICT**: the code change contradicts the ledger's triage status.

## Summary table

| Story | Audit-35 finding (fp12, ledger status) | Audit recommended | Story chose | Verdict |
|---|---|---|---|---|
| 093 | Q-06 `9c4e21bb9fd7` (open) | Resolve the markers and regenerate `local.json`. Add a CI or pre-commit check for conflict markers plus `JSON.parse` of `server/deployments/*.json`. | Fast-forward merge. Regenerated all generated deploy files from a fresh anvil DeployMocks run, including 2 files the audit missed (`local-addresses.ts`, `progress.31337.json`). The CI guard runs as the first step. | **ADOPTED**, extended. CI stays red at `forge fmt` (pre-existing). Master's DeployMocks run artifact was replaced. |
| 094 | L-09 `78cb5942d483` (fix-pending) | Option 1: end leg 1 after the execute. Option 2: re-seed a conservative amount, then sweep. Either way, add a verifier OWNER-residual check and a bound from the execute logs. Fix the (b) NatSpec. | Option 1, plus the verifier checks, **plus a HUMAN DECISION: approve 1.5R** instead of R. Preview still runs as one pass. | **ADOPTED (option 1) / REJECTED (option 2) / DEVIATES (1.5R approve was never recommended)** |
| 095 | L-10 `72e528c8715f` (fix-pending) | Re-derive the budget at about 27M and keep 1.2×. State staker counts. **"Better still": have `:preview` compute the budget.** Fix the "46 transactions" text. | A fixed 27M constant with a NatSpec derivation from the pre-094 67-tx run. Dynamic preview budget **explicitly not implemented**. | **PARTIAL / REJECTED (dynamic budget)** |
| 095 | Q-05 `df5f14bae8a7` (open) + carried Q-04 `a62956952abd` (fix-pending) | Rewrite the `:broadcast` breaker paragraph in one edit: name both dead windows, name the Phase 7 coverage gaps, fix the tx counts. Q-04 optional: harden the GLOBAL_PAUSE probe to assert V2/Antimatter are actually paused. | Breaker paragraph rewritten, HALTED RUNS and BREAKER LIVENESS NatSpec fixed, tx counts recounted 1-based per leg. **Probe hardening not done.** | **ADOPTED (docs) / NOT DONE (Q-04 optional probe)** |
| 096 | L-11 `e6e1f293bbad` (**wont-fix**, triageReason: "L-11 is expected so we'll just have to respond to crises in the moment. That's the purpose of 72 hours.") | Minimum: runbook note that V2 stays paused. Preferred: a resume past Phase 6 runs Phase 7 and leaves 6b pending with DOLA minting disabled. | The preferred mitigation, **extended**: it also defers when under 6h remain or during the wait. It adds a sticky `v2LiveBeforeMinterMove` that relaxes 2 live verifier checks after completion. It adds the new status `awaiting_minter_window`. | **LEDGER CONFLICT**: the owner triaged wont-fix, yet the story implements the fix. It also **extends** the fix beyond the audit's recommendation. |
| 097 | status Q-01 `8633815e4b2b` (open, no issueId) | Split EXECUTABLE into START-OK and too-late. Add a paused override. **Import `WINDOW_SAFETY_MARGIN` from a shared constant.** | Phase split and override use the audit's strings. The constant is **copied** into the base, with a drift-guard test. The paused override is **not applied to PHASE_NONE**. | **PARTIAL / DEVIATES** (copy instead of import; override narrowed) |
| 097 | initiate Q-01 `4cdafc61037c` (open, no issueId) | Print the "expiresAt − 6h" guidance, label timestamps as local-pass estimates, point to status. Update story-090 AC (PO). | All three output changes done. Story-090 AC update left to the PO. The readback is still local-pass, but labelled. | **ADOPTED** (AC update outstanding, out of the repo) |

---

## Story 093: Merge master and remove committed conflict markers (audit-35 Q-06)

- **Path:** `…/093-merge-master-and-remove-committed-conflict-markers.md` (auto-complete; commits `2420920`, `feb89a8`)
- **Responds to:** Q-06 `9c4e21bb9fd7` (pps35q6), ledger `open`
- **Audit recommended (verbatim):** "1. Resolve the conflicts: keep one generated header in `addresses.ts`, and regenerate `local.json` from the latest dev deploy. 2. Add a CI or pre-commit check that fails on conflict markers (`git diff --check`, or a grep for `^<<<<<<<|^>>>>>>>`) and runs `JSON.parse` over `server/deployments/*.json`."
- **Story chose:** regeneration (`deploy:local:forge -> extract:addresses -> generate:ts-anvil`) plus a CI step. After review, the step was moved ahead of `forge fmt`.
- **Stated rationale (verbatim):**
  - "This story fixes the problem whatever the label. Re-labelling the ledger is out of scope."
  - Decision 2: "This is the preferred path, and it produces files that match a real DeployMocks run."
  - Decision 3: "Without this fix, the new CI guard and the 'git grep returns nothing' checklist item would both fail."
- **Acceptance criteria (verbatim):**
  - "Merge master into sprint/stable-staker-v2 (expect fast-forward; if not, merge normally and record why). Do not push."
  - "Preferred: regenerate local.json, addresses.ts, local-addresses.ts from a fresh local anvil deploy (deploy:local:forge -> extract:addresses -> generate:ts-anvil). If a local deploy cannot run in this environment, resolve each conflict by hand keeping the side that matches the latest broadcast/31337 run artifacts (the newest DeployMocks run-latest.json) and record the choice in Autonomous Decisions."
  - "`node -e 'JSON.parse(require(\"fs\").readFileSync(\"server/deployments/local.json\",\"utf8\"))'` succeeds; `git grep -nE '^(<<<<<<<|=======|>>>>>>>)( |$)'` over tracked files returns nothing (exclude lib/ submodules)."
  - "Add a CI step to .github/workflows/test.yml before forge build that fails on conflict markers in tracked files (excluding lib/) and runs JSON.parse over every server/deployments/*.json."
  - "forge build and the non-fork test suite pass."
- **Deviation flags:** none against the audit.
  - The story went further than the audit (2 extra files).
  - Carried-forward residue: CI is still red at `forge fmt --check`. The master-side `broadcast/DeployMocks.s.sol/31337/run-1789510357096.json` was replaced by the executor's own anvil run.

## Story 094: Phase 6b execute-only leg and 1.5R approve headroom (audit-35 L-09)

- **Path:** `…/094-cutover-phase6b-execute-only-leg-and-reseed-approve-headroom.md` (auto-complete; commit `0622ec9`)
- **Responds to:** L-09 `78cb5942d483` (pps35l9), ledger `fix-pending`. Human triage: "fix owed (re-read R on chain / bound OWNER DOLA residual)".
- **Audit recommended (verbatim):**
  - "Never sign an amount derived from state that an earlier signed transaction changes. Either option below works: 1. **End the first broadcast leg right after the execute.** … 2. **Re-seed a deliberately conservative amount**, then sweep the remainder in the resume or verify leg."
  - "With either option, add two checks to `VerifyStableStakerV2Cutover._verifyPhase6b_minterMove`: `require(IERC20(DOLA).balanceOf(OWNER) == minterMove.ownerDolaBeforeExec …)` and bound the minter's sDOLA principal against the actual WithdrawalExecuted / DOLA Transfer amount … Also correct the halt-point (b) NatSpec."
- **Story chose:**
  - Option 1: a broadcast-only leg end, with status `awaiting_reseed`. The patch tail exits 2 with an instructive message.
  - The verifier gets the OWNER-residual equality and a mined-R lower bound from the **sum** of DOLA `Transfer(0x1760→OWNER)` logs since `cutoverStartBlock`.
  - **Plus:** approve `ceil(1.5R)`, sent only when the allowance is below R, with the leftover ~0.5R not zeroed.
  - Preview does not end the leg.
- **Stated rationale (verbatim):**
  - "**HUMAN DECISION:** \"set the approve as R*1.5\"."
  - Concern: "A 1.5R approve alone does not fix L-09. `noMintDeposit` pulls exactly the literal amount, so a larger allowance neither sweeps the excess nor prevents the shortfall revert (the revert comes from OWNER's balance, not the allowance). The planner therefore paired the human's 1.5R approve with the report's option 1 (end the leg after the execute), so the deposited amount is the mined R."
  - "The 1.5R allowance is headroom. The ~0.5R left over as allowance to the minter is harmless, because `noMintDeposit` is onlyOwner and pulls only from msg.sender. It is not zeroed afterwards, to avoid an extra tx."
  - "Option 2 (a conservative tranche plus a sweep) was rejected: a 5 bps margin would still revert on the audit's 0.27% skim injection."
  - Decision 3: "The L-09 divergence only exists when forge signs a local-pass value. In preview the local R is the only R."
  - Decision 6: "Summing makes the check stricter, never looser."
- **Acceptance criteria (verbatim):**
  - "TDD: fork test that an uninterrupted run from Phase 6b stops after the execute (no approve/noMintDeposit recorded in that run) and writes the leg-end progress status."
  - "TDD: fork test that leg 2 re-seeds the mined R when surplus is skimmed between the local pass and the execute (reproduce the audit's injection: impersonate SYA and call skimSurplus(DOLA, claimer) on the source strategy after leg-1 state is recorded), converges, and leaves OWNER DOLA == ownerDolaBeforeExec."
  - "TDD: test that the approve is r*3/2 and that an existing allowance >= r is not zeroed on resume."
  - "Implement execute-only leg end in CutoverStableStakerV2Mainnet.s.sol."
  - "Implement approve = R*1.5 in `_minterReseedSdola`."
  - "Verifier: OWNER DOLA residual check + mined-R bound from DOLA Transfer log; tests in VerifyStableStakerV2CutoverGuards.t.sol for both passing and failing cases."
  - "Update NatSpec (halt-point b, Phase 6b header) and package.json comments for the two-leg flow."
  - "Existing 092 fork tests (L983-1251, incl. haltAfterExecute_resumeConverges, haltAtSourceDeadWindow) still pass, updated only where the leg split changes expected behaviour."
  - "forge build, non-fork tests, and RPC_MAINNET fork tests pass."
- **Deviation flags:**
  - ⚑ **1.5R approve**: the audit never recommended this. It came from the human. The story itself says it does not fix L-09. It is harmless in isolation but leaves a standing ~0.5R allowance. On today's state it is dead code: OWNER→minter allowance is `type(uint256).max` at block 25994766, so no approve is signed.
  - ⚑ **Option 2 rejected**, with a stated reason.
  - ⚑ **Mined-R source.** The audit said to read "the execute receipt logs". The story sums every `Transfer(0x1760→OWNER)` since the start block. Any unrelated transfer on that pair inflates minedR and fails loud (OBS-36-C04).
  - ⚑ **Leg end is broadcast-only.** The real `isPreview == false` branch is untested; the tests use a preview override.
  - ⚑ **Collateral sits on OWNER between legs.** Every broadcast now leaves ~14.6k DOLA on the OWNER EOA for the operator latency between legs. Before, that happened only on a halt (OBS-36-C05).

## Story 095: Gas budget 27M and stale breaker runbook (audit-35 L-10, Q-05, carried Q-04)

- **Path:** `…/095-cutover-gas-budget-27m-and-stale-breaker-runbook.md` (auto-complete; commits `0f00562`, `0433062`)
- **Responds to:**
  - L-10 `72e528c8715f` (pps35l10), ledger `fix-pending`
  - Q-05 `df5f14bae8a7` (pps35q5), ledger `open`
  - Q-04 `a62956952abd` (pps34q4), ledger `fix-pending`
- **Audit recommended (verbatim):**
  - L-10: "1. Re-derive the budget from the 67-transaction session. The binding figure is the maximum over transactions of (cumulative gas used before the transaction + its signed limit), which is 25.16M at block 25990689. 2. Round up, for example to 27M, and keep the 1.2× factor. 3. State the staker counts the figure assumes: DOLA 9, USDC 13, USDe 7. 4. Better still, have `:preview` compute the budget instead of relying on a constant. … 5. Update the \"46 transactions\" text in the `:broadcast` comment and in the NatSpec."
  - Q-05: "Rewrite the breaker paragraph of the `:broadcast` comment in one edit that also fixes Q-04: Name both dead windows … Name the two Phase 7 coverage gaps (the Q-04 fix). Replace \"46 transactions\" with the current count."
  - Q-04 (run 34): "Correct the `//stable-staker-v2-cutover:broadcast` doc key and the cutover NatSpec to name the halt-5 window … Optionally, extend the Phase-8/preview `GLOBAL_PAUSE` probe to assert that V2 (and Antimatter) are actually paused after the simulated pause, not only that `Pauser.pause()` did not revert."
- **Story chose:**
  - `CUTOVER_GAS_BUDGET = 27_000_000` with the 1.2× factor. NatSpec cites the pre-094 67-tx measurement and says each leg checks the full budget.
  - Runbook and NatSpec rewritten with 1-based per-leg tx indices.
  - Dynamic budget not implemented. Probe hardening not implemented.
- **Stated rationale (verbatim):**
  - "**HUMAN DECISION:** budget = 27,000,000 gas, keeping the 1.2x factor."
  - Checklist: "Optional (not required): the report's suggestion that :preview compute the budget from simulated gas is out of scope; do not implement."
  - Concern: "Computing the budget dynamically in `:preview` is deferred; the human fixed a 27M constant."
  - "Whether this reopens L-07 or stands as a separate L-10 is a ledger decision for the human, not this story."
  - Decision 3: "Splitting cannot raise the per-leg peak, because leg 1 is a prefix of the old session and leg 2 is a subset of it."
- **Acceptance criteria (verbatim):**
  - "TDD: update test_ethBudget_math to 27_000_000, assert >= 25_163_101 (binding peak), and 9_720_000_000_000_000 / 11_340_000_000_000_000."
  - "Set CUTOVER_GAS_BUDGET = 27_000_000; rewrite derivation NatSpec with the 67-tx figures, the binding-peak rule (cumulative gasUsed + signed limit), fork block 25990689, staker counts DOLA 9 / USDC 13 / USDe 7, and a note on how story 094's two-leg split affects it (each leg's preflight checks the full budget)."
  - "Fix WINDOW_SAFETY_MARGIN NatSpec tx-number text."
  - "Rewrite the breaker paragraph of package.json `//stable-staker-v2-cutover:broadcast` in one edit: both dead windows (V1 tx pair, and autoDOLA 0x1760 setPauser->unregister with remedy), the Phase 7 coverage gaps (Q-04), current tx count / leg structure, 27M budget and new ETH figures. Remove the stale ~0.00564 OWNER-balance comparison or restate it."
  - "Update package.json L49 budget figure and the script HALTED RUNS NatSpec L120-125 to match."
  - "grep the repo (excluding lib/, broadcast/) for 22_000_000, 22,000,000, 0.00792, 0.00924, \"46 transactions\" and fix remaining hits."
  - "Optional (not required): the report's suggestion that :preview compute the budget from simulated gas is out of scope; do not implement."
  - "forge build, non-fork tests and fork tests pass."
- **Deviation flags:**
  - ⚑ **REJECTED: dynamic `:preview` budget.** This was the audit's "better still" option. The consequence: a staker-count growth of about 2 USDe stakers again erodes the headroom, which is now about 7% before the 1.2× factor. Mitigation is left to the "re-derive if staker counts grow" text.
  - ⚑ **No post-094 re-measurement.**
  - ⚑ **Q-04 optional probe hardening not done.** Q-04 stays fix-pending for that part only if the human counts it as in scope.
  - Live footgun check: OWNER ETH is `6424919451687286` wei at 25994766, below the required `9720000000000000`, so `:preview` should print `ETH_BUDGET|SHORTFALL`.

## Story 096: Lapsed-window resume unpauses V2 (audit-35 L-11)

- **Path:** `…/096-cutover-lapsed-window-resume-unpauses-v2.md` (auto-complete; commits `d0722f6`, `a2b9d75`, `bff40f3`)
- **Responds to:** L-11 `e6e1f293bbad` (pps35l11). **Ledger status: `wont-fix`.** triageReason: "L-11 is expected so we'll just have to respond to crises in the moment. That's the purpose of 72 hours." Note: "Reopen if the execution window shrinks or the recovery path (re-initiate + 6h) changes."
- **Audit recommended (verbatim):** "**Minimum:** in the RE-INITIATE PATH runbook, state that all V2 stakers stay paused until the re-initiated window opens. **Preferred:** when a resume past Phase 6 finds the window has lapsed, let it run Phase 7 (unpause and register V2) and leave Phase 6b pending. V2's DOLA `autoAnnihilate` would then mint into 0x1760 until 6b runs, so keep DOLA minting disabled (6b step (a)) in that branch."
- **Story chose:**
  - The preferred mitigation. `_resumePastPhase6()` checks migrator identity, that all V1 pools are Migrating, and that V1 principal is 0 on every source.
  - When it holds and the window is not executable with a 6h margin, the run sets `minterMovePending`. It runs 6b(a) only, runs Phase 7, and Phase 8 asserts the pending shape. Status becomes `awaiting_minter_window`.
  - The verifier reverts `Phase6b: PENDING` after checking everything else.
  - A sticky `minterMove.v2LiveBeforeMinterMove` makes a later completed `:verify` skip `V2 userInfo >= credited` and `V2 totalStaked >= floor`.
- **Stated rationale (verbatim):**
  - "The report's preferred mitigation was chosen over the doc-only minimum, because the finding affects whether users can reach their funds."
  - Decision 3: "Deferring is always safe: V2 is unpaused, DOLA minting stays disabled and the collateral stays on the source. Trying to execute close to the window's close risks the execute mining after expiry, where `totalWithdrawal` silently re-initiates."
  - Revision Decision 2: "The live-balance checks only mean something right after V2 goes live. The marker moves them to that point on this path instead of dropping them, and keeps them scoped to this path."
  - Disclosed risk: "A progress file carrying the marker by mistake relaxes the two live checks on a normal cutover."
- **Acceptance criteria (verbatim):**
  - "TDD fork test reproducing the audit PoC: initiate, age 6h, run Phases 0–6, age to 78h+1, resume → Phase 7 runs, V2 unpaused, a V2 DOLA staker can withdraw, DOLA minting disabled, 6b recorded as pending, progress not \"completed\"."
  - "TDD: re-initiate, age 6h, resume → 6b completes and run converges to completed (compose with 094's two-leg flow)."
  - "TDD: fresh session with lapsed window still reverts in Phase 0."
  - "Implement the branch in run()/Phase 0/6b gating without weakening the start gate."
  - "Verifier (VerifyStableStakerV2Cutover.s.sol) must not report success while 6b is pending; confirm or add a check + test."
  - "Update window NatSpec (L35-37, L159-161, L254-264) and RE-INITIATE PATH runbook in package.json to state V2 is unpaused on the lapsed-window resume and that 6b + DOLA minting remain pending until the re-initiated window opens."
  - "forge build, non-fork and fork tests pass."
- **Deviation flags:**
  - ⚑ **LEDGER CONFLICT.** The owner triaged L-11 `wont-fix` ("respond to crises in the moment"). The story says "The report's preferred mitigation was chosen" and implements it. Either the ledger disposition is stale (the human should consider `fixed` after run-36 verification), or the story overrode the owner's decision. Neither the story nor the ledger records the reversal.
  - ⚑ **Extends beyond the audit.** Deferral also triggers when under 6h remain, during the 6h wait, or with status None. The audit only said "lapsed".
  - ⚑ **Extends beyond the audit.** It adds verifier relaxation keyed on an operator-controlled progress-file flag. The audit proposed nothing about the verifier.
  - ⚑ **Narrower than the audit's failure scenario.** A halt inside Phase 6, with stakers frozen in a paused V1 or split across V1 and V2, still hard-fails (Decision 2 alternative rejected).
  - ⚑ **Runbook vs npm chain mismatch (OBS-36-C03).** The story and the runbook say the pending `:broadcast` tail "stops at `:verify`" and that this chained `:verify` runs the live V2 balance checks. But `patch-mainnet-addresses-stable-staker-v2.js` exits 2 for any status other than `completed`, and it runs before `:verify`. So on the pending path `:verify` is never chained, and the live checks the relaxation depends on only run if the operator invokes `:verify` by hand. The mainnet address book is also not patched with V2 while V2 is live. For script-auditor to confirm on a fork.

## Story 097: DOLA withdrawal status and initiate start-margin output (audit-35 status Q-01, initiate Q-01)

- **Path:** `…/097-dola-withdrawal-status-and-initiate-start-margin-output.md` (auto-complete; commit `91ed727`)
- **Responds to:**
  - `dola-ys-withdrawal:status` Q-01 `8633815e4b2b`, ledger `open`, issueId null
  - `initiate-dola-ys-withdrawal` Q-01 `4cdafc61037c`, ledger `open`, issueId null
- **Audit recommended (verbatim):**
  - Status: "Split the phase output: \"EXECUTABLE – cutover may START (>6h left)\" / \"EXECUTABLE but too late to START a cutover (<6h left): wait for expiry, then re-initiate\". When `strategy.paused()` is true, print an override: \"strategy PAUSED – execute will revert\". Import `WINDOW_SAFETY_MARGIN` from a shared constant instead of duplicating it."
  - Initiate: "Print \"start the cutover between executableAt and expiresAt − 6h (WINDOW_SAFETY_MARGIN)\". Label the printed timestamps as local-pass estimates, and point the operator to `npm run dola-ys-withdrawal:status` for the mined values. … Update story 090's AC text to include the margin."
- **Story chose:**
  - Pure helpers in `DolaStrategyWithdrawalBase`: `_effectivePhase`, `_phaseText`, `_phaseVerdict`, `_startDeadline`.
  - `WINDOW_SAFETY_MARGIN` **copied**, with a non-fork drift-guard test that imports the cutover.
  - The paused override applies to every pending phase but **not** PHASE_NONE.
  - Initiate output relabelled.
  - Story-090 AC not updated.
- **Stated rationale (verbatim):**
  - Concern: "The constant is copied into the base with a drift-guard test rather than extracted from the cutover. That avoids touching cutover window logic owned by 094–096 and keeps the dependency SOFT."
  - Concern: "Minting issueIds for the two Q-01 findings and updating story 090's AC text are human/ledger tasks, out of scope."
  - Decision 2: "Keeps the story-092 post-cutover sanity read accurate while giving the override on every state where a totalWithdrawal call is relevant."
- **Acceptance criteria (verbatim):**
  - "Add `WINDOW_SAFETY_MARGIN = 6 hours` to DolaStrategyWithdrawalBase (do not change the cutover's constant or its logic, owned by 094–096); add a non-fork test asserting the base constant equals the cutover's WINDOW_SAFETY_MARGIN so they cannot drift."
  - "Status script phases: WAITING; \"EXECUTABLE - cutover may START (>6h left)\"; \"EXECUTABLE but too late to START a cutover (<6h left): wait for expiry, then re-initiate\"; expired. When strategy.paused() is true print an override \"strategy PAUSED - execute will revert\". Add a test (fork or harness) covering the last-6h and paused cases."
  - "Initiate script: print \"start the cutover between executableAt and expiresAt - 6h (WINDOW_SAFETY_MARGIN)\", print the start deadline, label printed timestamps and READBACK as local-pass estimates, and point to `npm run dola-ys-withdrawal:status` for mined values."
  - "Update the package.json `//InitiateDolaStrategyWithdrawal` comment (and any status comment) with the margin."
  - "forge build, non-fork and fork tests pass."
- **Deviation flags:**
  - ⚑ **DEVIATES: copy instead of import.** The audit asked for a shared constant. The drift is guarded by a test, not by the compiler.
  - ⚑ **DEVIATES from the story's own literal wording.** The paused override is skipped for PHASE_NONE. This was disclosed and tested.
  - ⚑ **Outstanding outside the repo.** Story-090 AC text still says "between executableAt and expiresAt". issueIds are still unminted.

---

## Ledger actions this map implies (for the human; not applied)

- **L-11 `e6e1f293bbad`:** `wont-fix` now contradicts shipped code. Decide whether to verify in run 36 and move it to `fixed`, or record that story 096 overrode the triage.
- **L-09, L-10, Q-04** (`fix-pending`): the fixes landed. Only a human may set `fixed`, after run-36 verification. Q-04's optional probe hardening was not done.
- **Q-05, Q-06, status Q-01, initiate Q-01** (`open`): fixes landed. Propose `fixed` after verification. The two Q-01 entries still need issueIds.
