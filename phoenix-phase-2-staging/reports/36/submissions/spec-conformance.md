# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit run 36 (3 entry points)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `91ed727138e09720a28e70707d7d3df40a7d7ee2` (branch `master`)
- **Entry points**: `stable-staker-v2-cutover`, `initiate-dola-ys-withdrawal`, `dola-ys-withdrawal:status` (all baselined at `7ac6e70`, run 35)
- **Delta**: `7ac6e70..91ed727`, stories 093–097 (the audit-35 fix wave)
- **Faithfulness-tagged findings**: 1, **F-04** → M-01 (`pps36m1`; formerly L-12 `pps36l12`, re-rated Low → Medium by human triage 2026-09-17). It is a **cross-reference**, not a standalone finding: the primary label is `M-01`, and its primary report is [`M-01.md`](./M-01.md) (record: `reports/36/findings/medium/stable-staker-v2-cutover__M-01.json`). `F-04` is the next F label in the `stable-staker-v2-cutover` sequence (run 31: F-01..F-03). The classifier's run-local tag `F-L-12` is superseded by it.

## Story resolution

Each tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree (`find … -name '<NNN>-*.md' -o -name '<NNN>.*-*.md'`). Each matched exactly one document.

| Story | Path (under `~/code/product-owner/stories/phStaging2/`) | State folder |
|---|---|---|
| 093 | `auto-complete/phStaging2-stable-staker-v2/093-merge-master-and-remove-committed-conflict-markers.md` | `auto-complete` |
| 094 | `auto-complete/phStaging2-stable-staker-v2/094-cutover-phase6b-execute-only-leg-and-reseed-approve-headroom.md` | `auto-complete` |
| 095 | `auto-complete/phStaging2-stable-staker-v2/095-cutover-gas-budget-27m-and-stale-breaker-runbook.md` | `auto-complete` |
| 096 | `auto-complete/phStaging2-stable-staker-v2/096-cutover-lapsed-window-resume-unpauses-v2.md` | `auto-complete` |
| 097 | `auto-complete/phStaging2-stable-staker-v2/097-dola-withdrawal-status-and-initiate-start-margin-output.md` | `auto-complete` |

`auto-complete` is a final state equivalent to `complete`. Story 096 records "**Approved by**: story-batch workflow (machine approval — not human-reviewed)" (L381), so the text quoted below has been agent-reviewed, not human-reviewed.

---

## F-04 → M-01 (`pps36m1`, formerly L-12), `stable-staker-v2-cutover`, story 096 Decision 5 / Revision Decision 2

- **Fingerprint**: `cf684d5dc289b0f07a863e7682c6725f40e0ee943ad0aeca4d8f7f410b8b37ad`
- **Location**: [`scripts/patch-mainnet-addresses-stable-staker-v2.js#L70-L89`](https://github.com/Behodler/phoenix-phase-2-staging/blob/91ed727/scripts/patch-mainnet-addresses-stable-staker-v2.js#L70-L89) (`loadProgress`)
- **Severity**: **Medium** (re-rated from Low by human triage 2026-09-17: the owner confirmed the frontend reads `StableStakerV2` from `mainnet-addresses.ts`). Primary report: [`M-01.md`](./M-01.md).
- **Introduced by**: story 096, the response to L-11 `e6e1f293bbad` (`pps35l11`; `wont-fix` at scan time, triaged `fixed` 2026-09-17). Not a duplicate or incomplete fix of L-11.

**Story text (096, first Autonomous Decisions block, Decision 5 "Run outcome and verifier behaviour", L150), verbatim:**
> - The `:broadcast` tail therefore stops at `:verify` by design. The script output and the runbook both say so.

**Story text (096, revision attempt 2, Decision 2 "How the verifier and runbook agree after pending → V2 live → 6b completes", L282), verbatim:**
> 2. **Pending-state verify**: the `:verify` in the lapsed-window `:broadcast` tail runs right after V2 goes live. It no longer stops at the first 6b check. It skips the 6b block, then verifies Phase 7, the per-user credits including the live V2 balance checks, and Phase 8's pending shape. Only then does it revert `verify: Phase6b: PENDING`, and the message says what was verified and how many users. That is where the live checks run on this path.

**Rationale for relocating the checks (096, revision Decision 2, L286), verbatim:**
> - **Rationale**: The live-balance checks only mean something right after V2 goes live. The marker moves them to that point on this path instead of dropping them, and keeps them scoped to this path. The event-based checks do not change when users withdraw, so they all stay.

**Second review (096, L331), verbatim:**
> - Only the `:verify` chained right after the pending broadcast is sure to run before any withdrawals. Any later pending-state verify can hit a per-user revert once a migrated staker has withdrawn. That includes a second pending resume, e.g. during the 6h wait after re-initiating, whose `:broadcast` tail chains `:verify` again.

**Checklist criterion (096, L79), verbatim:**
> - [x] Verifier (VerifyStableStakerV2Cutover.s.sol) must not report success while 6b is pending; confirm or add a check + test.

> **Quote-provenance note.** The classifier paraphrased Revision Decision 2 as the live checks having "ran instead on the pending-state :verify that the lapsed-window :broadcast tail chains immediately after V2 went live". That wording does not appear in the story document. The verbatim text above is authoritative.

**Deviation.** `stable-staker-v2-cutover:broadcast` is `forge script … && node scripts/patch-mainnet-addresses-stable-staker-v2.js && npm run stable-staker-v2-cutover:verify && npm run stable-staker-v2-cutover:preview`. Story 096 added the progress status `awaiting_minter_window`, but the patcher's `loadProgress` has a branch only for story 094's `awaiting_reseed`. Any other non-`completed` status hits the generic check and exits 2:

```js
if (p.deploymentStatus !== 'completed') {
    fail(2, `deploymentStatus is "${p.deploymentStatus}", expected "completed" (broadcast not finished, or a resume leg is outstanding)`);
}
```

The `&&` chain then skips `:verify` and `:preview`. On the only path Decision 5 and Revision Decision 2 govern, the tail does **not** stop at `:verify`, the pending-state `:verify` does **not** run, and the live V2 balance checks the story relocated rather than dropped are **not** executed automatically. Once 6b later completes, the verifier reads the sticky `v2LiveBeforeMinterMove` marker and skips `V2 userInfo >= credited` and `V2 totalStaked >= floor`, relying on the earlier run that never happened. The story's claim that "the script output and the runbook both say so" holds only for the text. The chain behaves differently. `mainnet-addresses.ts` also keeps `StableStakerV2`/`Antimatter` at `0x0` for the whole pending period (at least 6h) while V2 is live and unpaused.

**Evidence (empirical).** Real broadcasts on an anvil mainnet fork at block 25994908, under `reports/36/script-audits/fork-logs/pending-path/`: P6/P7, with forge exit 0, progress `awaiting_minter_window`, `v2LiveBeforeMinterMove: true`, V2 `paused=false`, patcher `ERROR (2)`, chain exit 2, `:verify` not reached, `StableStakerV2` still `0x0`. P8 is a manual `:verify` that reverts `verify: Phase6b: PENDING … 29 per-user credits (incl. live V2 balances) verified`, so the check works when run and is simply not chained. There is also a node-only replay at `fork-logs/02-c03-patch-tail-awaiting_minter_window.log`. The sponsor test `test_fork_096_pendingWithdrawThenCompleted_verifierPasses` calls the verifier directly and never exercises the npm chain. A coded fork PoC, `work/test/audit-run36/M01PendingTailPoC.t.sol` (validated in `reports/36/pocs/M-01-validation.log`), reproduces the same result by running the `package.json` tail verbatim.

**Law 1 cross-check.** The story's intent is safe. The unfaithful implementation silently removes a detection gate. No exploit is shown, and a loss needs a second, independent per-user credit defect. Severity rationale (Medium, on the stated UI assumption) is in the primary report, [`M-01.md`](./M-01.md).

**Recommended remediation (summary; the full text is in [`M-01.md`](./M-01.md)).** Give `loadProgress` an `awaiting_minter_window` branch. The branch fills only `StableStakerV2` and `Antimatter` (fill-once, idempotent), leaves the DOLA strategy keys untouched, and exits 0 so the chained `:verify` produces the intended `Phase6b: PENDING` stop. If the owner prefers a non-zero exit instead, the branch should print an explicit "run `:verify` NOW" instruction. Correct the runbook, the `_printMinterMovePending` line and the verifier NatSpec to match, and add a guard test next to `test_broadcastChainsVerifyBeforePreview`.

---

## Audit-35 mitigations deliberately rejected by stories 094/095/097, and accepted by the auditor

Sources: `reports/36/script-audits/stable-staker-v2-cutover/story-mitigation-map.md` (story ↔ recommendation map, with verbatim story rationale) and `reports/36/script-audits/cluster-analysis.md` ("Story-rejected mitigations: accepted, and why"). **None of these is a faithfulness finding.** In each case the story knowingly chose a different remediation than the audit offered, recorded why, and the run-36 verification found no residual hazard that justifies filing.

| Story | Audit-35 finding | Audit option not taken | Story's stated reason (verbatim) | Auditor verdict (run 36) |
|---|---|---|---|---|
| 094 | L-09 `78cb5942d483` (`pps35l9`) | Option 2: re-seed a conservative tranche, then sweep | "Option 2 (a conservative tranche plus a sweep) was rejected: a 5 bps margin would still revert on the audit's 0.27% skim injection." | **Accepted.** Option 1 (execute-only leg end) closes both L-09 branches on a real two-leg broadcast: mined R was re-seeded, OWNER DOLA returned to 0, and `:verify` residual was 0. |
| 094 | L-09 | (Not recommended) the human-chosen `ceil(1.5R)` approve | "**HUMAN DECISION:** \"set the approve as R*1.5\"." / "The ~0.5R left over as allowance to the minter is harmless, because `noMintDeposit` is onlyOwner and pulls only from msg.sender." | **Accepted.** Harmless, and dead code on current state (OWNER→minter allowance is max). |
| 094 | L-09 | Bound mined R from "the execute receipt logs" | Decision 6: "Summing makes the check stricter, never looser." | **Accepted, no finding (OBS-36-C04).** Summing only tightens the lower bound, so a false PASS is impossible. A false FAIL needs an owner-originated outflow and fails loudly. |
| 095 | L-10 `72e528c8715f` (`pps35l10`) | "Better still": have `:preview` compute the gas budget dynamically | "Optional (not required): the report's suggestion that :preview compute the budget from simulated gas is out of scope; do not implement." / "**HUMAN DECISION:** budget = 27,000,000 gas, keeping the 1.2x factor." | **Accepted.** Re-measured after story 094: leg-1 peak 25,173,447 gives 7.26% raw headroom (about 6 more USDe stakers before the 1.2× requirement binds). The NatSpec tells the operator to re-derive if staker counts grow. |
| 095 | carried Q-04 `a62956952abd` (`pps34q4`) | Optional GLOBAL_PAUSE probe hardening | Not implemented. The run-34 recommendation called it "Optionally". | **Accepted.** The existing probe asserts that every registrant is paused. The uncovered case is exactly the now-documented unregistered gap. |
| 097 | status Q-01 `8633815e4b2b` | Import `WINDOW_SAFETY_MARGIN` from a shared constant | "The constant is copied into the base with a drift-guard test rather than extracted from the cutover. That avoids touching cutover window logic owned by 094–096 and keeps the dependency SOFT." | **Accepted.** The drift guard is a non-fork CI test and passes. |
| 097 | status Q-01 `8633815e4b2b` | Paused override on every phase | Decision 2: "Keeps the story-092 post-cutover sanity read accurate while giving the override on every state where a totalWithdrawal call is relevant." (override not applied to PHASE_NONE) | **Accepted.** It cannot mislead the operator into a bad initiate, because initiate's preflight `require(!strategy.paused())` reverts on a paused strategy. |

**Outstanding outside the repo (not findings):** story 090's AC text still says "between executableAt and expiresAt" (a PO task, since the stories tree is read-only to the audit). ~~The two `Q-01` ledger entries still have no issueId.~~ Resolved 2026-09-17: human triage minted `pps35q7` (status) and `pps35q8` (initiate), and marked both `fixed`.

---

## Informational: L-11 ledger disposition vs story 096 (for human triage, not a finding)

- **Ledger:** L-11 `e6e1f293bbad543573c8e564c9ee1f70a0139dc107fca28b629117292b79cfde` (`pps35l11`) is `wont-fix`. triageReason: "L-11 is expected so we'll just have to respond to crises in the moment. That's the purpose of 72 hours." Reopen trigger in the note: "Reopen if the execution window shrinks or the recovery path (re-initiate + 6h) changes."
- **Story 096** implements the audit's *preferred* L-11 mitigation, and goes further: "The report's preferred mitigation was chosen over the doc-only minimum, because the finding affects whether users can reach their funds." Neither the story nor the ledger records that the `wont-fix` triage was reversed.
- **Run-36 observation:** the fix works on a real anvil broadcast. On the lapsed-window resume V2 was unpaused, and the verifier refuses the pending state. The recovery path has changed as a result (a resume past Phase 6 now unpauses V2 instead of hard-failing), which is arguably the note's own reopen trigger in the benign direction.
- **Ledger action this run:** none. L-11's status and every field of its entry are untouched, it is not carried over, and it is not re-escalated. The new defect story 096 introduced is filed separately as L-12 (now M-01) and is not suppressed by L-11's `wont-fix`.
- **Resolved 2026-09-17 (human triage):** option (a) was applied. L-11 is `fixed` on the run-36 verification. M-01 (formerly L-12) stays an independent open entry.
