# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit `unipooler-cutover` (run 41)

**Project**: `phoenix-phase-2-staging`  ·  **Run**: `phoenix-phase-2-staging-41`
**Commit**: `e75ee0776efcf20918b7db71d717eafb61bbd1a6` (`e75ee07`), branch `master`
**Entry point**: `unipooler-cutover` (`unipooler-cutover:preview` / `:broadcast` / `:verify`)
**Fork evidence**: `reports/41/script-audits/unipooler-cutover/logs/` (`run41-forktests.log`, `fullrun-statediff.log`, `preview-*.log`)

This run raises **two Law-2 findings**: `F-01` (`pps41f1`) and `F-02` (`pps41f2`). Both are
manifestations, in this entry point, of the open run-40 contract-scan findings `pps40f1` and
`pps40f2`. Neither has asset, value or availability impact, so neither owes a High/Medium label or
report. Two QA findings have a faithfulness side and are cross-listed here without new labels:
`Q-02` (`pps41q2`) and `Q-03` (`pps41q3`). Their full text is in `qa-report.md`.

The **Obligations verified** section records which of the cross-project amendments routed from
yield-claim-nft into story 103 are met in code. Two are met (L-27, F-02-052). One is not (L-28).

### Story resolution

Story 103 was found by globbing the whole `~/code/product-owner/stories/phStaging2/` tree. The tag
matched exactly one document:

| Story | Path (under `~/code/product-owner/stories/phStaging2/`) | State |
|---|---|---|
| 103 | `auto-complete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md` | **auto-complete** (final, equivalent to `complete`) |

The story has moved since run 40, when it was in `incomplete/`. `auto-complete` is a final state:
agent review passed, and no formal human review is required. Line numbers below refer to the story
file as it stood on 2026-10-18.

**Stale pointer.** The L-27 amendment doc,
`~/code/product-owner/scratchpad/planning-docs/phoenix/phStaging2/story-103-amendment-l27-bpt-guard.md`,
still gives at line 4:

> `**Target story:** phStaging2:103, \`stories/phStaging2/incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md\``

No file exists at that path now. Anyone following the amendment doc to its target will miss the
story. The doc's "Target story" line should be updated to the `auto-complete/` path. (The
product-owner tree is read-only to the audit.)

---

## F-01: Story 103's Background still prescribes the superseded OWNER-custody cutover <!-- id: pps41f1 -->

- **issueId:** `pps41f1`  ·  **Fingerprint:** `3d3c90ecbffc547b55a59b372e5b2135ecc218e72718915cbf0515b963a82ea0`
- **Fingerprint input:** `story-103 text / docs/BalancerWinddownPlan.md section 4 Stage 2:n/a (spec):story-internal-contradiction:unipooler-cutover`
- **Reconciles with:** `pps40f1`, fingerprint `48d88a589ca41396cb6e2c835c34bbf9296be43ffd0537d45e02e3df53bacab5` (ledger status `open`). It is the same root cause, still present, seen through the `unipooler-cutover` entry point. It is not a new duplicate.
- **Severity:** QA (faithfulness channel). **Status:** open.
- **Direction:** the **story text** is unfaithful to the story's own amendments. The **code** follows the amendments.

### What the story says (verbatim)

The Background section "Cutover sequence (implemented in `UniPoolerCutoverCore`, story 100; the plan's
version is corrected)" (story L63-75) still reads:

> 2. `BalancerPoolerV2.withdrawBPT(OWNER, fullBalance)`.
> 3. Exit the OWNER's whole BPT balance: `removeLiquidityProportional` before 30 Oct, `removeLiquidityRecovery` after, selected by parameter (env `RECOVERY_EXIT=true`). `minAmountsOut` is never 0.
> 4. Router02 `addLiquidity(sUSDS, phUSD, allRecoveredSUSDS, allRecoveredPhUSD, min, min, to = UniPoolerV2, deadline)` from the owner; this creates the pair.

The 2026-10-07 amendment in the same document (story L225-227) forbids exactly that flow:

> - **Requirement:** the human requires that no protocol funds (BPT, sUSDS, phUSD, USDS) transit the owner EOA `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` or any other EOA during the cutover, so that it is provable on-chain, for tax and accounting, that these funds move contract-to-contract.

and requires (L232-233):

> - step 4: `withdrawBPT(escrow, bal)`;
> - steps 5+6: replaced by `escrow.exitAndSeed`;

Nothing in the Background section marks it as superseded.

### Code reality

`script/helpers/UniPoolerCutoverCore.sol` at `e75ee07` implements the escrow flow. From its header
(L48 and L53-58):

```solidity
 *        4. BPT-address guard, then `BalancerPoolerV2.withdrawBPT(escrow, fullBalance)`. The guard
 ...
 *        5. Check `minAmountsOut` against the live proportional share of the ESCROW's BPT balance
 *           (the old pooler's BPT only), then `escrow.exitAndSeed(mode, minAmountsOut, deadline)`:
 ...
 *           (Replaces the pre-052 steps 5 and 6, which ran through the owner.)
```

The only `withdrawBPT` call site sends to the escrow (`UniPoolerCutoverCore.sol:525`):

```solidity
            ICutoverBalancerPooler(oldPooler).withdrawBPT(escrow, bal);
```

The fork state diff (`logs/fullrun-statediff.log`, `test_r41_fullRun_stateDiff_verify`) shows **zero
OWNER token deltas** across all steps. The core's own owner-not-credited invariant (story Decision 6)
also holds after every step.

### Impact

Documentation only. A future story, a rehearsal, or a reader re-deriving the runbook from the
Background section could rebuild the EOA-custody flow that the 2026-10-07 requirement forbids.

### Recommendation

Mark the Background "Cutover sequence" (L63-75) as **superseded inline**, and point it to the
2026-10-07 amendment and the core's header step list. The same correction to
`docs/BalancerWinddownPlan.md` §4 Stage 2, already owed under `pps40f1`, still applies. Keep
`pps40f1` open until both texts are corrected.

---

## F-02: Story 103 names the wrong third-party BPT holders <!-- id: pps41f2 -->

- **issueId:** `pps41f2`  ·  **Fingerprint:** `1b9d7d232bd097ada17bf48e46e7cadf936ebda541fc915d98e9c8ef628007a6`
- **Fingerprint input:** `script/helpers/UniPoolerCutoverCore.sol (story-103 Concerns):n/a (story text):story-stale-holder-list:unipooler-cutover`
- **Reconciles with:** `pps40f2`, fingerprint `91aa9008aaca30a35a88b0dda81d906ae8ba4b7beb915fca13298562d5991364` (ledger status `open`). It is the same root cause, still present, seen through the `unipooler-cutover` entry point.
- **Severity:** QA (faithfulness channel). **Status:** open.
- **Direction:** the **story text** is factually wrong. The **code** behaves correctly.

### What the story says (verbatim)

Background, "BPT moved off the pooler" (story L120):

> `withdrawBPT` sent 150 to `0xE74EBCBd1b4415c605c1D5EC85aADD0304af1322`, 200 to `0x5f972f06A95C2185d435c0C84D69d563dfad53d2`, 202.30 to the owner `0xCad1…`, and 1,847.77 to `0xde4409B56f9d45124e31D27E10b096BBaa303D07`. Only BPT the owner holds is in scope.

Concerns (story L217):

> - **BPT held by third parties** (`0xE74E…1322`, `0x5f97…d2`, `0xde44…3D07`) is out of scope. Only owner-held BPT is exited, and verify reports any residual owner BPT.

Both lines are unchanged since run 40.

### Code reality

On-chain at about block 26,221,761, `BPT.balanceOf` returns **0** for all three named addresses.
BPT `totalSupply` is 32,438.774. The old pooler holds 20,401.809. The remaining **12,036.965 BPT
(37.1%)** is held elsewhere; run 40 identified `0xc65f…e8db`. (Source:
`cluster-analysis.md` §pps40 F-02. These were interactive `cast call` reads, and no saved log
exists for them, so re-run the three `balanceOf` calls to reproduce.)

The script itself is correct. It exits only the old pooler's balance. The quote helper sizes on it
(`scripts/quote-balancer-exit-min-amounts.js:101`):

```js
    const bal = uintCall(rpc, BPT, 'balanceOf(address)(uint256)', OLD_POOLER);
```

and the core moves only `balanceOf(oldPooler)` (`UniPoolerCutoverCore.sol:521`). Preview log:
`BPT old pooler -> escrow: 20401809116957261204353`.

### Impact

Documentation only. The cutover does not depend on the holder list. A reader trying to account
for the 37.1% of supply that is not protocol-held would be pointed at the wrong addresses.

### Recommendation

Update the holder list at story L120 and L217 with the current holders (from run 40:
`0xc65f…e8db`), or remove the named addresses and keep the rule "only the old pooler's BPT is
exited".

---

## Cross-listed QA findings with a faithfulness side

These findings are labelled and reported in `qa-report.md`. They are listed here because each one
is also a deviation from story 103 text.

### Q-02: Story-specified step gating was dropped (disclosed in Decision 7) <!-- id: pps41q2 -->

- **issueId:** `pps41q2`  ·  **Fingerprint:** `e2909097a253570554b172ae8052da95a17078cf07f0abb67fdebca0e8bb0032`
- **Location:** `script/DeployMainnetUniPoolerCutover.s.sol` `_alreadyCompleted` L450-468; header L50-54.
- **Reconciles with:** none (new in run 41).

**Story text (verbatim).** Technical Details, Progress (story L153):

> - **Progress:** `PROGRESS_FILE = "server/deployments/progress.unipooler-cutover.1.json"`, with `_loadProgressFile()` / `_writeProgress(status)` and step gating via `_isConfigured`/`_trackConfig`.

The Background "Mainnet script pattern" (L97) says the same: "Steps are gated by
`_isConfigured`/`_trackConfig`".

**Disclosure.** The deviation is disclosed in the story's Autonomous Decision 7 (L307-310):

> - **Decision**: The script writes the progress file once, at the end, in broadcast mode only. On start it does nothing if a `completed` file's UniPooler is live at index 4. It reverts on any other existing file as POISONED and names the rename. Recovery is manual, from `run-latest.json` receipts: fresh-floored `exitAndSeed`, or `escrow.abort()` and a clean re-run. `_fundEscrow` is the core's only `withdrawBPT` call site, so every funding, including a resume, passes the L-27 guard.

**Code reality.** Neither file contains `_isConfigured` or `_trackConfig`. The "completed" test
checks only that index 4's dispatcher is the new pooler (tx 19's effect):

```solidity
        if (completed && np != address(0) && np.code.length > 0 && d == np) {
            console.log("Progress file is completed and its UniPooler is live at index 4:", np);
            console.log("Nothing to do - no transaction sent. Run `npm run unipooler-cutover:verify`.");
            return true;
        }
```

After a crash after tx 19, a re-run therefore logs "Nothing to do" while txs 20-24 (sUSDS rescue,
USDS rescue, `wrapUsds`, `old.setMinter(OWNER)`, `old.pause()`) may not have landed
(`test_r41_crashAfterReplaceDispatcher_rerunIsNoOp_verifyCatches`; `:verify` catches it with
`verify: old pooler not paused`). The header's claim, also restated in Decision 7, is:

```solidity
 *   floors or `escrow.abort()` (everything back to the old pooler) and re-runs from a clean state. Any re-funding
 *   of an existing escrow goes through the core's guarded `_fundEscrow`.
```

No reachable entry point makes that true. `run()` always deploys a fresh pooler and escrow, so a
resume into an existing escrow is a hand-typed `cast` `withdrawBPT` with no L-27 guard
(`test_r41_L27_withoutGuard_manualResumeStrandsX`).

**Faithfulness verdict.** The departure from the step-gating text was disclosed and is defensible,
because the story itself calls the progress file untrustworthy after a crash. The rationale given
for it is partly false: the "every resume passes the L-27 guard" sentence in the header and in
Decision 7 does not hold.

**Recommendation.** Make `_alreadyCompleted` require the full end state (old pooler paused, minter
OWNER, drained). Otherwise, print exactly which of txs 20-24 are missing. Then either correct the
header and Decision 7 sentence, or add a small `RESUME_ESCROW=<addr>` entry point that calls
`_fundEscrow` / `exitAndSeed` / the step 11-12 tail against an existing escrow, behind the same guards.

### Q-03: Plan §4 step 11's post-broadcast test mint never runs <!-- id: pps41q3 -->

- **issueId:** `pps41q3`  ·  **Fingerprint:** `3da1655208b7dda10c7b11f6c2912907d18db206724cb15517280f390dd01522`
- **Location:** `script/VerifyUniPoolerCutover.s.sol` `run` L35-85; `package.json:76` (`unipooler-cutover:broadcast` tail).
- **Reconciles with:** none (new in run 41).

**Story text (verbatim).** Background, Plan §4 Stage 2, step 11 (story L53-59):

> 11. **Verify:**
>     - `configs(4).dispatcher` is the new pooler.
>     - `hook.dispatcher()` is the new pooler.
>     - The pair's reserves match what was seeded.
>     - The new pooler holds the LP.
>     - A forked test mint dispatches, wraps and accrues debt.
>     - A `pool()` preview with `quotePool` floors succeeds.

Technical Details, npm keys (story L176):

> - `unipooler-cutover:broadcast`: `backup-mainnet-addresses` head, Ledger flags as in the template, then a tail of patcher + `unipooler-cutover:verify` + `unipooler-cutover:preview`.

The story is not internally consistent here. Its Technical Details narrow the mint to
"**Preview-only E2E:** a test mint at index 4 via `deal`…" (L155), and its Verify-script list
(L156-163) leaves the mint out. The plan step it quotes as the source places the mint under
**Verify**, after the cutover. The trailing `:preview` in the `:broadcast` tail is the only part of
the story that could carry that post-broadcast check.

**Code reality.** `VerifyUniPoolerCutover.run` (L35-85) checks wiring, reserves, LP custody, the
drained old pooler, owner BPT and `_simulateQuotedPool`. It performs no mint. The mint exists only
in `_previewEndToEnd`, on simulated pre-broadcast state. The `:broadcast` tail ends:

```
&& node scripts/patch-mainnet-addresses-unipooler-cutover.js && npm run unipooler-cutover:verify && npm run unipooler-cutover:preview
```

Once the progress file is `completed` and live, the trailing `:preview` returns at
`if (_alreadyCompleted()) return;` (`DeployMainnetUniPoolerCutover.s.sol:359`), before any E2E code.
In the fork full run it logs `Nothing to do - no transaction sent.`
(`test_r41_fullRun_stateDiff_verify`, `logs/run41-forktests.log`). No step ever runs a test mint
against the landed contracts.

**Faithfulness verdict.** The code implements the story's Technical Details literally, but it does
not meet the plan step 11 that those details claim to implement. The `:preview` tail looks like a
post-broadcast end-to-end check and is guaranteed to do nothing.

**Recommendation.** Move the `deal`-funded test mint, inside a reverted snapshot, into
`VerifyUniPoolerCutover.run` next to `_simulateQuotedPool`. Then drop the trailing `:preview` from
`:broadcast`, or relabel it. Amend story L155 and L176 to match.

---

## Obligations verified (cross-project amendments routed from yield-claim-nft)

Story 103 took on three obligations from yield-claim-nft run 22. The ycn ledger statuses below
were read by projection only. **No ycn ledger entry was written by this run.** Every "proposed
fixed" below is a proposal, recorded in
`reports/41/script-audits/unipooler-cutover/proposed-transitions.json` (`"applied": false`). A
human applies it.

| Obligation | ycn entry | ycn status | Story 103 text | Code at `e75ee07` | Result |
|---|---|---|---|---|---|
| L-27 BPT-address guard | `ycn22l27` `2268ead7cba40c097fd2723e45032f2afc947b04736bbc77b87450ba02111bd4` | fix-pending | Amendment 2026-10-08 (L208, L236, L241-246) | Guard present and live | **SATISFIED**, proposed fixed (not applied) |
| F-02-052 owner-BPT premise dropped | `ycn22f2` `5a7732a4ea711f11a15b9064bd6e2803aedec9f90b6b2ffe48cb3a3869ac7b7a` | fix-pending | Amendment 2026-10-10 (L207, L219, L248-258) | No owner BPT moved; floors sized on old pooler | **SATISFIED**, proposed fixed (not applied) |
| L-28 griefable exit floors / public mempool | `ycn22l28` `d77a482de757221d9ff311a43a46c11b40aa7df997199914fad7469d7128b209` | fix-pending | **Not mentioned anywhere in story 103** | No private relay, default 10 bps floors | **UNMET**, filed as `pps41l2` |

### L-27: SATISFIED

**Required (story L208, verbatim):**

> - **BPT-address guard (yield-claim-nft run 22, L-27; amended 2026-10-08).** Immediately before step 4 (`withdrawBPT(escrow, bal)`), `require(old.pool() == escrow.bpt())` with a descriptive revert message. Repeat the same `require` before any `withdrawBPT` or BPT transfer into an escrow that already exists (a resume from broadcast receipts, or a re-run after `escrow.abort()`). Read `old.pool()` live; never cache it across steps.

**Code** (`script/helpers/UniPoolerCutoverCore.sol:519-525`):

```solidity
        address livePool = ICutoverBalancerPooler(oldPooler).pool();
        require(livePool == ICutoverEscrow(escrow).bpt(), CUTOVER_BPT_GUARD_MESSAGE);
        bal = ICutoverERC20(livePool).balanceOf(oldPooler);
        if (bal > 0) {
            uint256 escrowBefore = ICutoverERC20(livePool).balanceOf(escrow);
            ICutoverBalancerPooler(oldPooler).withdrawBPT(escrow, bal);
```

`old.pool()` is read live inside `_fundEscrow` and is not taken from the step-0 cache. This is the
core's only `withdrawBPT` call site (`grep withdrawBPT`: L525 is the only call; the other hits are
NatSpec and the interface declaration). The revert message (L234) is descriptive. The operational
rule ("never call `setPool` … while an escrow is live") is in the script header
(`DeployMainnetUniPoolerCutover.s.sol` L56-59).

**Tests (all PASS, `logs/run41-forktests.log`, re-run independently by the orchestrator):**
`test_r41_L27_scriptFlow_setPoolAfterEscrowDeploy_revertsBeforeWithdrawBPT`,
`test_r41_L27_direct_guardRevertsAndNothingMoves`, `test_r41_L27_refundAfterAbort_guarded`, and the
non-vacuity control `test_r41_L27_withoutGuard_manualResumeStrandsX` (the unguarded path does strand
the token, so the guard is load-bearing). Upstream `test_L27_resumeAfterAbort_refundsThroughGuard`
also passes (`logs/upstream-story103-tests.log`).

**Residual (not an incomplete fix).** The "repeat the require before any transfer into an existing
escrow" clause is met only for paths that go through the core. No scripted resume path exists, so a
manual resume bypasses the guard. That is a documentation/tooling gap, filed as `pps41q2` above. It
does not reopen L-27.

**Proposed:** `/ledger yield-claim-nft fixed 2268ead7cba4` (not applied).

### F-02-052: SATISFIED

**Required (story L207, verbatim):**

> - **Owner BPT is out of scope (amended 2026-10-10, F-02-052).** The script never transfers owner BPT into the escrow, and it must NOT revert on a non-zero owner BPT balance: anyone can donate BPT to the owner, so such a revert would be a grief vector. Any residual owner BPT is only reported by verify (see Concerns).

**Code.** No owner-to-escrow BPT transfer exists anywhere in the closure. The quote helper sizes the
floors on the old pooler's balance only (`scripts/quote-balancer-exit-min-amounts.js:101,107`):

```js
    const bal = uintCall(rpc, BPT, 'balanceOf(address)(uint256)', OLD_POOLER);
    ...
    const floor = (r) => ((r * bal) / supply) * (10000n - tol) / 10000n;
```

Owner BPT is read (L103) only to be logged as "out of scope, NOT exited; F-02-052" (L119). Verify
reports it through `_reportOwnerBpt()` and has no require on it. The fork logs show
`owner BPT (out of scope, reported only): 0` and `owner BPT at start (not moved): 0`. In
`test_r41_fullRun_stateDiff_verify`, the in-test floors equal the CLI quote to the wei. Upstream
`test_fork_ownerBptDonation_isNotMoved_andReported` passes.

**Proposed:** `/ledger yield-claim-nft fixed 5a7732a4ea71` (not applied).

### L-28: UNMET (owed, not delivered)

`ycn22l28` (`d77a482de757221d9ff311a43a46c11b40aa7df997199914fad7469d7128b209`) was triaged
**fix-pending** on 2026-10-10 because the owner would handle it for the cutover. Story 103 does not
mention L-28 anywhere: there is no amendment, checklist item or Concern for it. The tooling does not
mitigate it either:

- The `:broadcast` key sends every tx, including `escrow.exitAndSeed`, through `--rpc-url $RPC_MAINNET`
  (public mempool) with `--slow`. Nothing selects a private relay, and the runbook never names one.
- The quote helper defaults to 10 bps (max 50).

On the fork, a Balancer swap of about 30 sUSDS (fee about $0.10) between tx 4 and tx 5 reverts the
exit at 10 bps. At 50 bps the threshold rises only to about 160 sUSDS (about $0.53)
(`test_r41_L28_griefCost_10bps`, `test_r41_L28_griefCost_50bps`). Custody stays safe: the escrow
keeps the BPT, and a re-quoted `exitAndSeed` succeeds. The impact is a liveness/grief cost.

This obligation is filed in this run as **`pps41l2`** (L-02, fingerprint
`01d60c7d1d494d0112fd31a66dd91b3bd746ca68cd55b45476cf0591d82ddde7`, `reconcilesWith` the ycn L-28
fingerprint above). Full text is in `qa-report.md`. **Leave `ycn22l28` fix-pending.** Do not propose
closing it until the cutover has landed. To meet the obligation, do one of the following before the
Stage 4 session:

- amend story 103 and the `:broadcast` key or runbook to use a private relay (at minimum for tx 5) and
  40-50 bps floors, or
- record explicitly that the owner accepts public-mempool exposure for this cutover.
