<!--
ID: 1c222d5485 (ledger fingerprint — this record mints NO new finding ID and NO M-nn label)
C4 Submission Metadata — ⚠ FIX-PENDING STILL LIVE (possible incomplete fix) / LEDGER STATUS PROPOSAL
Title: ⚠ FIX-PENDING STILL LIVE (possible incomplete fix) — run-20 High (`depositFor` pays the migrator):
       PoC-INVERTED, LIKELY-FIXED FOR THE COVERED PATHS by story-023 f3b92c0
Record kind: LEDGER STATUS PROPOSAL. Not a severity item, not a new finding, no label.
Project: phoenix-nft-staking
Run: phoenix-nft-staking-21 @ c881a428c87ef4ef42ba07a71be5d49101c9006d
Baseline: 0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54
Ledger fingerprint: 1c222d54852333a8a166c267329d3b4c02adb65faa2842bbc1e48f3c8b88bd37
Current ledger status: fix-pending (severity: high) — human-set 2026-07-20
Proposed status: KEEP fix-pending. Record the migrator-side fix as LIKELY-FIXED-FOR-COVERED-PATHS.
Contract: src/NFTStakerDepletion.sol (depositFor), line 756
Closing change under evaluation: f3b92c0 [story-023] Version-agnostic migrator settlement-capture forwarding (pns20h1)
Evidence: poc-replay.md §5 (three PoCs inverted) + faithfulness-notes.md (F-21-01 residual reach-paths)
Linked (DO NOT COLLAPSE): run-21 M-03 b3243f42… — the residual source-tree hazard, filed as its own finding
-->

> ### ⚠ Read this framing first — the fix is good; the closure is not earned
>
> **This record must not be read as "the fix failed." It did not.** story-023's migrator-side
> capture-and-forward is a **well-built mechanism**, it is **correct and complete for the paths it
> covers**, and three PoCs that previously proved the bug now **fail because the bug is gone on those
> paths**. That deserves explicit credit and gets it below.
>
> **What is not earned is the closure.** `src/NFTStakerDepletion.sol:756` is **unchanged**, and four
> reach-paths survive that no migrator-side control can reach by construction. Under `CLAUDE.md`,
> `fix-pending` is human-set and never auto-closed, and *a fix that merely stops tripping the scanner is
> not a verified fix.* This is the **⚠ FIX-PENDING STILL LIVE (possible incomplete fix)** class — ranked
> second only to a REGRESSION, **because an incomplete fix reads as done.**
>
> **⚠ Whatever is decided, this must NOT be reported as "the defect is gone."**

> **⚠ Label-collision guard.** This record concerns **run-20's `H-01` = `1c222d5485…`**
> (`NFTStakerDepletion.depositFor`). It is **not** ledger `H-01` `858e9e80…` (value-blind nudge gate,
> a separate expired-closure reopen this run). Disambiguate by fingerprint, never by label.

## Finding description and impact

### The entry and its current disposition

Ledger `1c222d5485…`, severity **high**, status **`fix-pending`**, `fixedAtCommit: null`, set by human
triage on 2026-07-20:

> *"[2026-07-20 human triage] Set fix-pending (was: open). Fix owed; fixedAtCommit stays null.
> REMEDIATION ROUTE AGREED: the affected NFTStakerDepletion instance is deployed and immutable, so the
> canonical source fix (`_safePay(pending)` → `_safePayTo(user, pending)` at NFTStakerDepletion.sol:756)
> CANNOT be applied to it. Instead a MIGRATOR-SIDE capture-and-forward patch will be built…"*

The same triage set four **closure criteria** and recorded an explicit **residual**:

> *"RESIDUAL, NOT CLOSED BY THIS FIX: `setMigrator` (NFTStakerDepletion.sol:311-314) does zero validation
> — no code-size check, no interface probe, no lifecycle gate — so an EOA migrator, a future third
> orchestrator, or a script calling `depositFor` directly reproduces this at full severity with no
> on-chain guard. The migrator patch is a DEPLOYMENT-DISCIPLINE control, not a source fix."*

### What story-023 delivered — and it is genuinely well-built

`f3b92c0 [story-023] Version-agnostic migrator settlement-capture forwarding (pns20h1)` gave both
`NFTStakerMigrator` and `InPlaceNFTStakerMigrator`:

- an **immutable `rewardToken`** (a new 6th constructor argument, cross-checked against the staker's own
  `rewardToken()` getter);
- a **settlement-capture measure-and-forward leg**;
- a `require(captured <= owed)` **tripwire** (*"Migrator: capture exceeds owed"*);
- a per-user `unforwarded` **escrow** plus `claimForwarded()`, with a `totalUnforwarded` **floor that
  `rescueERC20` cannot cross**.

**The bound is fail-closed, and this was traced rather than taken on the NatSpec's word.** `_syncBudget`
(`src/NFTStakerDepletion.sol:423-435`) runs `_updatePool()` at `:424` **before** `dispatcherHook.pull()`
at `:429`. `_updatePool` (`:448-472`) and `pendingReward` (`:799-813`) consume identical inputs — same
`accRewardPerShare`, `rewardRate`, `windowEnd`, the same `reward > rewardBudget` cap, the same
`totalStaked > 0` / `Active` guards — at the same `block.timestamp`. So the `pending` settled at `:754`
equals the pre-call projection **exactly**, and `_safePayTo` can only pay less, never more. The tripwire
is genuinely a tripwire, and it **cannot misfire on a legitimate migration**.

**The self-disabling claim holds.** `NFTStakerPriceScaledMigrateReady.depositFor` settles via
`_safePayTo(user, …)` at `:887`, so the migrator's balance is unchanged, `captured == 0`, and the branch
at `NFTStakerMigrator.sol:223` is skipped — pinned by `testVersionAgnosticPairDepletionVsPriceScaled` and
`testVersionAgnosticInPlaceAgainstPriceScaled`.

**D-6 parity holds.** `NFTStakerMigrator.sol:214-241` and `InPlaceNFTStakerMigrator.sol:311-338` differ
only in the staker handle and a revert-string prefix.

#### It is materially STRONGER than the audit's own run-20 proposed patch, in five places

The run-20 workspace patch was never merged and carries no authority; this is corroboration, and the run
must not understate a good fix.

| | run-20 proposed patch | **story-023 (shipped)** |
|---|---|---|
| Reentrancy | none | `ReentrancyGuard` + `nonReentrant` on `migrate` / `migrateIn` / `claimForwarded` |
| Bound on the capture | **none** — would have forwarded any mid-call foreign inflow to whichever user the loop was on | `require(captured <= owed)` against the pre-call `pendingReward` |
| Blocklisted recipient | `safeTransfer` → **whole batch reverts** (a batch-DoS the patch shipped with) | escrow-on-failure + permissionless, self-only `claimForwarded()` |
| Owner reach into escrowed value | `rescueERC20` unconditional | floored by `totalUnforwarded` (`NFTStakerMigrator.sol:270-274`, `InPlaceNFTStakerMigrator.sol:392-396`) |
| InPlace rescue | untouched | `totalUnforwarded` floor retrofitted |

Both also added the missing rescue primitives to `NFTStakerMigrator`, which previously had none — that
independently closes ledger `L-02` (`cb1b52790cf1`, proposed `fixed`).

### The PoCs are INVERTED — three tests now fail because the bug is gone

This is the one place where a PoC *failing* is the good news: the assertion messages are literally
asserting the presence of the bug (poc-replay.md §5). All figures at `c881a42`.

| Test | Old (buggy) expectation | Observed at `c881a42` | Verdict |
|---|---|---|---|
| `PoC_Drift01_DepositForPaysMigrator::testC_InPlaceMigrateInCapturesReward_RecoverableViaRescue` | `assertEq(aliceGain, 0, "BUG: alice got nothing")` | **alice received 8,219.178082191780691200e18** | **LIKELY-FIXED** |
| `PoC_Drift01_DepositForPaysMigrator::testD_CrossStakerMigrateStrandsRewardPermanently` | migrator holds **82,191.78e18** captured | **migrator holds 0** — fully forwarded | **LIKELY-FIXED** |
| `PoC_Drift01_MigratorSidePatch::testA_Control_UnpatchedMigratorStrandsReward` | control: unpatched migrator strands 82,191.78e18 | **migrator holds 0** | **LIKELY-FIXED** (the "unpatched" control is no longer unpatched) |

Green within a healthy upstream baseline: **412 tests passed, 0 failed** across the 28 tracked upstream
suites with all audit-authored files parked out (poc-replay.md §1). The `+16` over the previously-claimed
396 is exactly `test/MigratorRewardForwarding.t.sol`, introduced by story-023 itself.

Upstream's own inversion claims were verified in source and both pass in that baseline:
`testE2_MispointedHookRecipientRevertsInsteadOfOverCrediting` (the batch reverts wholesale on
`vm.expectRevert("Migrator: capture exceeds owed")`, alice's balance unchanged, nothing half-applied,
`stillOnOld == 10`, against a baseline **50,000e18** unrecoverable over-credit) and
`testG_RevertingRecipientDoesNotBrickTheBatch` (with `testG2_FalseReturningTransferEscrowsRatherThanReverting`
covering the silent-false-return variant). **Both claims confirmed.**

> **Scoping note.** `PoC_Drift01_MigratorSidePatch::testE2_HOLE_*` and `testG_HOLE_*` still **PASS**, but
> they construct `PatchedNFTStakerMigrator` from `test/patched/`, i.e. **run-20's own superseded patch
> proposal**, not shipped `src/`. They demonstrate holes in a superseded audit proposal and **say nothing
> about HEAD**. They are moot / reference-only and must not be read as live findings against `c881a42`.

### Why the entry must NOT be closed

`src/NFTStakerDepletion.sol:756` is **unchanged**. story-023 declined a source fix on the ground that
*"that staker is deployed and immutable"* — true of the **instances**, false of the **file**, which is the
live deployment template used by `lib/phoenix-phase-2-staging/script/DeployMainnetUniboostCutover.s.sol:478`
to mint fresh mainnet instances.

**Four residual reach-paths survive the migrator-side remedy:**

1. **Direct EOA / multisig caller.** `setMigrator` (`:311-314`) accepts **any** address — no code-size
   check, no interface probe, no lifecycle gate. An operator address wired as migrator reaches
   `depositFor` directly and receives the user's settlement, with `Claimed(user, …)` still emitted.
   **Nothing in either migrator can prevent this.**
2. **Any pre-`f3b92c0` migrator instance already deployed and wired.** The fix lands only on *redeploy
   plus re-running `setMigrator` on both stakers* — and the commit body never states that prerequisite.
3. **Any future third orchestrator** written against `INFTStakerMigratable` alone, which is silent about
   the trap (spec-conformance `F-21-01`).
4. **Every future `NFTStakerDepletion` deployment.**

`PoC_Drift01_DepositForPaysMigrator::testA_DepositForPaysMigratorNotUser` and
`testB_BatchMigratePaysUserCorrectly` **still PASS** at `c881a42` — they characterise `depositFor`'s raw
behaviour, which is exactly what did not change.

### The disputed positions, recorded

| Source | Position |
|---|---|
| **poc-replay §5** | Propose `fixed` — three PoCs inverted, green within the 412-test baseline. |
| **story-faithfulness F-21-01** | **KEEP `fix-pending`.** The mechanism is correct and complete *for the paths it covers*, but `:756` is unchanged, four reach-paths survive, and the cutover script deploys fresh mainnet instances from that file. |
| **sanitizer** | KEEP `fix-pending`. |
| **classifier** | KEEP `fix-pending`, concurring with the sanitizer. |
| **Decided by** | **A human, via `/ledger`.** |

## Recommended mitigation steps

### 1. Ledger action — KEEP `fix-pending`, and record what landed

**Do not flip `1c222d5485…` to `fixed`.** Instead annotate the entry:

- story-023 `f3b92c0` is **LIKELY-FIXED-FOR-COVERED-PATHS** — the migrator-side mechanism is verified
  correct, complete for its coverage, and stronger than the audit's own proposal in five respects.
- Closure criterion **(4)** of the 2026-07-20 triage — *"the un-deployed source still takes the one-line
  `_safePayTo` fix, and all four staker clones' `depositFor` settlement lines are diffed together"* — is
  **NOT met**. That criterion alone blocks closure on the operator's own stated terms.
- Closure criteria (1) escrow-bound, (2) escrow-on-failure and (3) rescue primitives on
  `NFTStakerMigrator` **are** met.

### 2. Close the residual at source, or banner the file

Apply `_safePayTo(user, pending)` at `:756` for future instances — zero cost, and the correct primitive
already exists in-tree at `src/NFTStakerPriceScaledMigrateReady.sol:887` and in-file at `:733`. Keep the
migrator-side forwarding as the compensating control for the already-deployed stakers. If the source fix
is declined, add an unmissable `DEPLOYED / FROZEN — requires a capture-and-forward orchestrator` banner
to the file and to `depositFor`.

### 3. Re-weigh ledger `L-04` (`066eccff`) — `setMigrator` has no lifecycle gate

The 2026-07-20 triage already flagged this: with the migrator patch acting as a **deployment-discipline
control rather than a source fix**, `L-04` becomes the load-bearing control for reach-path 1 and is
currently only Low.

### 4. Do not collapse with run-21 `M-03` (`b3243f42…`)

`M-03` carries the residual source-tree hazard **as its own finding, precisely so that a later flip of
`1c222d54…` to `fixed` cannot orphan it.** Both entries must exist simultaneously (deduplicator
`doNotCollapseRegister`, new this run).

### 5. Retire the superseded reference tests

Relabel `PoC_Drift01_MigratorSidePatch::testE2_HOLE_*` and `testG_HOLE_*` as reference-only against
run-20's superseded patch proposal, so a future run does not misread their PASS as a live finding at HEAD.
