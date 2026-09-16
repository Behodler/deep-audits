# Carryover spec-conformance report: audit 31 (entry point `stable-staker-v2-cutover`), carried at audit 34

> **Carryover spec-conformance report, audit 31** (cut down from
> [`reports/31/submissions/spec-conformance.md`](../../../31/submissions/spec-conformance.md)). Audit 34 replaced the audit-33 header. The body is the same cut-down copy that audit 33 carried.
> The per-finding text below is copied **verbatim**. Only the index table was cut down to the retained set.
>
> - **Retained below (still `open` as of audit 34 @ `84e2324`): `F-01` (`pps31f1`, `dfed4279095251f3acd34987e79e3a1eecfce16adaca31cc6c776e8f724e713a`), plus the cross-listed `L-01` and `L-02`.** Their primary reports are in [`qa-report-31.md`](qa-report-31.md).
> - **Removed as no longer live:** `F-02` (`pps31f2`, `436848b0e31b…`) and `F-03` (`pps31f3`, `103002cc2990…`) are both wont-fix (owner, 2026-09-14). The body's intro still says "three standalone Law-2 findings", but only `F-01` remains.
> - **Audit-34 disposition:**
>   - **`F-01` / `dfed42790952`: proposed fixed at run-34, human confirmation via /ledger required.** Story 087 deleted the story-085 aggregate floor. The exit-realization bound on V1's immutable `(R, P)` keeps the F-01 coverage: `test_F01_haircut5bps_failsClosedBothShapes` fails closed on both shapes, and in `test_F01_boundarySweep_resumeShape` 1.92 bps passes and 2.12 bps fails. What remains: on a resume leg, a haircut on the re-deposit leg is bounded only by `:verify`. That gap is folded into audit-34 **`L-08`** (`pps34l8`), recommendation 4. Apply with `/ledger phoenix-phase-2-staging fixed dfed42790952`.
>   - **`L-01`, `L-02`:** see [`qa-report-31.md`](qa-report-31.md). Both are proposed fixed at run-34, and a human must confirm via /ledger.
> - **Line numbers below were accurate at the originating commit `1c1608c`. Re-verify them against current HEAD `84e2324` before acting.**
>
> Run 34: `/audit-script` on entry point `stable-staker-v2-cutover`, commit `84e2324`, baseline `29aeb2b`, branch `master`, fork blocks 25985945 / 25988932. The harness is `phoenix-phase-2-staging/work/test/audit-run34/CutoverAuditRun34.t.sol` (19/19 PASS, `reports/34/script-audits/stable-staker-v2-cutover/fork-logs/r34-gapfix-fullfile.log`). The audit-33 harness no longer compiles at `84e2324` (MR-34-SSV2C-01), so any audit-33 PoC path in the body is bit-rotted. **Audit 34 changed no status.** Every `fixed` below is a *proposal*, and a human must confirm it with `/ledger`.

---


# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 31)

**Project**: phoenix-phase-2-staging  ·  **Run**: `phoenix-phase-2-staging-31`
**Commit**: `1c1608c0e56a55cbeb436926d139fa89ff7a3144`, branch `master`  ·  **Baseline**: none (new entry point, cold)
**Entry point**: `stable-staker-v2-cutover` (`package.json` → `stable-staker-v2-cutover:preview` / `:broadcast`)
**Report scope**: Law-2 faithfulness only. Low/QA findings without a faithfulness tag are in
`qa-report.md`. This file is kept separate from that bundle on purpose, so faithfulness findings are not buried among QA items.

This run has **three standalone Law-2 findings** (`F-01`, `F-02`, `F-03`) and **two Low findings
cross-listed here** because they also break the story (`L-01`, `L-02`). None is High or Medium, so no
separate H/M submission is owed. All five are new ledger entries. Nothing was carried over, because no
earlier entry exists for this entry point.

| Label | `issueId` | Fingerprint | Story graded against | Deviation type | Severity | Routing |
|---|---|---|---|---|---|---|
| **F-01** | `pps31f1` | `dfed42790952…` | story-082 Phase 6 + **story-067** | DECLARED-BUT-UNMET (tautological gate) | Low | standalone |
| **L-01** | `pps31l1` | `e0d4df1ddb69…` | story-082 Overview 5 / DUST HANDLING | DECLARED-BUT-UNMET | Low | cross-listed (primary: `qa-report.md`) |
| **L-02** | `pps31l2` | `2c82d65e65e1…` | story-082 "Preview doubles as post-broadcast verification" + `package.json` doc keys | DECLARED-BUT-UNMET | Low | cross-listed (primary: `qa-report.md`) |

> **Labels are run-scoped.** Run-31 `F-01`…`F-03` are not the run-29/30 `F-0x` labels (for example
> `pps30f1` / `d862aec474e0…` and `pps29f3` / `c476a12b04fa…` are different findings). Use the `issueId`
> or fingerprint as the stable handle.

---

## Story resolution

- **`[story-082]`** resolves to exactly one document in the whole `~/code/product-owner/stories/phStaging2/`
  tree:
  `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md`.
- **State folder: `auto-complete`.** The story's own completion stamp (line 322) reads:
  *"**Approved by**: story-batch workflow (machine approval — not human-reviewed)"*. The review status it
  acted on was `ISSUES_FOUND` with the triage verdict "non-blocking". So **no human has signed off**
  on any of the deviations below, including the three the story's own reviewer carried forward (lines
  328–331). That is why this report surfaces them in the audit channel instead of trusting that the
  story tree already covers them.
- **`story-067`** (cited by story-082 as the source of the "realized ≥ booked principal" check) resolves
  to exactly one document:
  `~/code/product-owner/stories/phStaging2/complete/phStaging2-ys-induced-stable-staker-migration-script/067-enforce-zero-haircut-floor-gate.md`
  (state `complete`).

---

## F-01: The "067 floor" post-condition compares two numbers booked identically, so it cannot fail; story-067's zero-haircut anchor on the pre-migration booked total is not implemented

- **`issueId`**: `pps31f1`
- **Fingerprint**: `dfed4279095251f3acd34987e79e3a1eecfce16adaca31cc6c776e8f724e713a`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/helpers/StableStakerCutoverCore.sol:_assertPoolPostMigration:TautologicalPostCondition:stable-staker-v2-cutover`
- **Root cause class**: `TautologicalPostCondition`  ·  **Severity**: Low  ·  **Verified**: yes (fork @25975869)
- **Location**: [`script/helpers/StableStakerCutoverCore.sol#L469-L471`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/helpers/StableStakerCutoverCore.sol#L469-L471) (`_assertPoolPostMigration`)
- **Finding record**: `reports/31/findings/faithfulness/F-01-tautological-post-condition.json`

### Acceptance text this deviates from (verbatim)

story-082, line 88 (Phase 6 post-conditions):

> Phase 6 post-conditions per token (080's `_assertStableStakerCutover`, extended): V1 totalStaked/stakerCount == stragglers only; each migrated user post>0, post<=pre, loss ≤ maxLossBps (0 for ERC4626 DOLA/USDC, strategy bps + slack for USDe) + 2 wei; V2 totalStaked == sum(post); **realized ≥ booked principal (067)**.

story-067, lines 40–48 (the definition story-082 cites):

> **Decision (user-confirmed): implement an end-to-end floor gate.** Capture the staker's
> *pre-migration* booked total … and … hard-require:
> ```solidity
> require(
>     ysDolaV2.principalOf(DOLA, ORIGINAL_STABLE_STAKER) >= savedPreMigBookedDola,
>     "Zero-haircut gate FAILED: realized principal < pre-migration booked"
> );
> ```

story-067 also warns against exactly this shape. It describes a `require(principalOf >= savedTotalStaked)`
that collapses into a no-op as *"a no-op that would *look* like a fix while enforcing nothing"*.

### What the code does

```solidity
// ---- Story 067 floor: what the strategy realizes for V2 covers what V2 books for users ----
uint256 realized = ICutoverStrategy(strategy).principalOf(token, address(v2));
require(realized >= v2Staked, "cutover-post: strategy principal for V2 < V2 booked totalStaked (067 floor)");
```

Both sides are read **after** migration, and both are credited from the same `credited` value in every
`depositFor`: the strategy books `clientBalances[V2] += credited` and V2 books `totalStaked += credited`.
So the two sides are equal by construction and the check can never detect a haircut. Fork evidence
(`fork-logs/h-A-users-events.log`, POSTPOOL) shows exact equality on all three pools: DOLA
`1222723447469613917495 | 1222723447469613917495`, USDC `1968305934 | 1968305934`, USDe
`2557881617164101522200 | 2557881617164101522200`.

### Impact

A named safety gate gives no protection. The aggregate principal change from before to after the
cutover (USDe −8.934, USDC −0.170245, DOLA −0.00415) is never checked against any aggregate floor. The
only loss protection left is the per-user bound, and Decision 4 (line 216) already relaxed that from the
story's 0 bps + 2 wei to 2 bps + 2 wei (ERC4626) and 61 bps (USDe). No asset impact is shown, because the
per-user bounds still stop a real vault loss, so this is not High or Medium. It stays at Low rather than
QA because it is the **third recurrence** of the story-067-floor defect class (YS-26 `018c109ec76f`, YS-32
`523ef3df52a6`) and because it misrepresents a safety gate to the operator. The story's reviewer flagged
it (line 328), but no human has accepted it.

### Recommendation

> Replace it with a real aggregate gate anchored on the snapshot: require `V2.totalStaked_after >= P * (MAX_BPS - maxLossBps) / MAX_BPS - n * WEI_SLACK`, where P is `V1.migrationInfo(token).principalSnapshot`. Alternatively rename the check (for example 'V2 book/strategy lockstep') so it is not presented as the 067 floor, and record the Decision-4 relaxation as a human-accepted deviation.

---

## L-01 *(cross-listed; primary report in `qa-report.md`)*: A 9-wei V1 DOLA stake makes the per-user loss post-condition revert, so dust can stall the cutover the story says it cannot

- **`issueId`**: `pps31l1`
- **Fingerprint**: `e0d4df1ddb699c8f34e034209cf8a6311bffa3bfd79429662637976f527dd054`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/helpers/StableStakerCutoverCore.sol:_assertPoolPostMigration:FixedWeiSlackBelowVaultRoundingLoss:stable-staker-v2-cutover`
- **Root cause class**: `FixedWeiSlackBelowVaultRoundingLoss`  ·  **Severity**: Low (Medium considered and rejected)  ·  **Verified**: yes (fork PoC)
- **Location**: [`script/helpers/StableStakerCutoverCore.sol#L452-L455`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/helpers/StableStakerCutoverCore.sol#L452-L455) (`_assertPoolPostMigration`)
- **Finding record**: `reports/31/findings/low/L-01-fixed-wei-slack-below-vault-rounding-loss.json`
- **Pre-broadcast blocker**: yes (the dust can also arise without an attacker).

### Acceptance text this deviates from (verbatim)

story-082, line 18 (Overview item 5):

> 5. Migrates every V1 staker to V2 through CrossVersionMigrator, with invariants that ensure dust cannot grief (revert/stall) the cutover.

story-082, line 79 (DUST HANDLING):

> DUST HANDLING (user requirement: dust must not grief the cutover). A single user whose V2 deposit reverts … reverts the whole `migrate` batch and the no-progress guard aborts the run.

story-082, line 84:

> d. Dust users: do NOT let them block.

### Deviation

The dust predicate (`_depositWouldFail`) only asks whether the V2 deposit would **revert**. The per-user
post-condition then allows a flat `WEI_SLACK = 2` on top of a bps term that is 0 for any position under
5,000 wei. On autoDOLA (share price ≈ 1.19) a stake of 9 wei books 8 wei on V1 and then loses 3 wei over
the exit and re-deposit. The planner marks the position MIGRATABLE, and the post-condition reverts
`cutover-post: cutover lost more principal than the strategy can explain`. It keeps reverting on every
retry while the position exists. V1 stays Active and unpaused until the run's own Phase 1, so anyone can
plant such a position for 9 wei plus gas. Fork evidence: `test_G_plantedDolaDustStallsCutover` shows
`PLANTED_DUST|cutover REVERTED`, and an exhaustive search over stakes of 1..400 wei gives
`worstStakeInput=9|worstLossWei=3|countAboveBound=63`. Live USDC dust users already lose exactly 2 wei,
right at the edge of the slack. No funds are at risk: the revert fires in forge's local pass, before any
transaction is sent.

### Recommendation

> Derive the absolute slack from the destination vault, not a constant, e.g. `weiSlack = 2 + ceil(vault.convertToAssets(1)) + 1` (share-price rounding on both floors), or add the planner's own predicted loss (`amount - convertToAssets(previewDeposit(amount*R/P))`) to the bound for that user. Alternatively classify positions whose predicted round-trip loss exceeds the bound as allow-listed stragglers under the existing 1-cent cap. Add a regression to test/StableStakerCutoverDust.t.sol that plants a 9-wei DOLA-shaped position on a vault with share price > 1.

---

## L-02 *(cross-listed; primary report in `qa-report.md`)*: The post-broadcast `:preview` "verification" re-runs any unfinished step under prank instead of asserting it is done, so a partial or diverged mainnet cutover still verifies green

- **`issueId`**: `pps31l2`
- **Fingerprint**: `2c82d65e65e163c9f986c669aaf0b56abcfc80ae9f91016dd3f84fc1fb6b7da7`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/CutoverStableStakerV2Mainnet.s.sol:run / _phase1.._phase7 (idempotent skip-if-done gates) / _phase8_wiringAssertions:VerificationPassSimulatesMissingSteps:stable-staker-v2-cutover`
- **Root cause class**: `VerificationPassSimulatesMissingSteps`  ·  **Severity**: Low  ·  **Verified**: yes (fork harness)
- **Location**: [`script/CutoverStableStakerV2Mainnet.s.sol#L143-L190`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/CutoverStableStakerV2Mainnet.s.sol#L143-L190)
- **Finding record**: `reports/31/findings/low/L-02-verification-pass-simulates-missing-steps.json`
- **Class recurrence**: the story-075 assert-only verifier pattern used to close fix-pending `2c53e944caee`
  (M-01, `promotion-ready:broadcast`) was not reused. This finding is cross-referenced to that entry, not
  filed as an incomplete fix of it.

### Acceptance text this deviates from (verbatim)

story-082, line 63:

> **Preview doubles as post-broadcast verification.** Preview READS the progress file when one exists (read-only — preview never writes it). After a completed broadcast, every idempotent phase therefore detects it is already done and is skipped, and preview then runs the Phase 8 wiring assertions and the preview-only smoke tests (including the Antimatter mint-revocation proof) against the live deployed contracts.

story-082, line 147 (Concerns):

> Verification: per user, no separate verify key — broadcast chains to `:preview`, which reads the progress file and re-runs wiring assertions and smoke tests against the live deployment.

`package.json` doc key `//stable-staker-v2-cutover:preview` (at `1c1608c`):

> … so AFTER a completed broadcast every idempotent phase detects - from on-chain state - that it is done and skips, and the run becomes the post-broadcast verification …

### Deviation

Every phase has the form `if (!done) do();` and runs under `vm.startPrank(OWNER)`. A step that did **not**
land on mainnet is therefore performed silently inside the simulation, and Phase 8 then asserts the
simulated state. Nothing in preview mode requires that zero mutations were needed. The per-user loss bound
is evaluated only over this leg's `plan.migratable`, which is empty after a broadcast. The story promises
that a completed broadcast is detected and skipped. The code actually repairs an incomplete one in
simulation and reports the same success. Fork harness evidence: `test_C_previewMasksMissingRevoke`
(`MASK_REVOKE|preview run() PASSED although V1 phUSD mint was live on-chain`) and
`test_C2_previewMasksPausedV2` (`MASK_PAUSED_V2|preview run() PASSED although V2 was paused on-chain`), with
console output byte-identical to a clean verification. A V1 stake that lands between the local pass and the
Phase-1 `pause()` transaction is absent from every frozen batch. It is stranded behind the revoked mint,
and the chained preview migrates it in simulation and reports success.

### Recommendation

> Add a separate assert-only verifier (mirroring story-075's standalone VerifyPromotionReady.s.sol) or an explicit VERIFY_ONLY env-flag mode that never calls vm.startPrank/vm.startBroadcast and never mutates. Gate it on ON-CHAIN state, not on the progress file: do NOT key verify-only mode off progress-file deploymentStatus == completed, because progress files can be stamped completed during forge's local pass (ledger 1e8cc0dc58ba). In that mode every phase must require(alreadyDone, 'verify: step X not on chain') and never perform it. Live asserts must include: V1 phUSD mint revoked, V2 and Antimatter unpaused, V1 stakerCount/totalStaked per pool <= the straggler allow-list, V2 pauser == Pauser, and the Antimatter minter set. Re-check the per-user loss bound from on-chain receipts (V1 MigratedOut / V2 DepositedFor events, or persisted pre-migration principals) against V2 userInfo rather than the empty same-leg plan. Separately, assert that the set of V1 stakers at the Phase-1 pause block equals the frozen planning set, and fail loudly if a staker raced the window.

---

## Not in this report (for orientation)

- **L-03** (`pps31l3`, `0711215fcc17…`), about the global Pauser loop, is not a story deviation and sits
  only in `qa-report.md`. Its root cause lies outside this entry point's slice (two already-paused retired
  contracts still registered with the mainnet Pauser, which breaks the emergency pause for every
  registered contract). That root cause is recorded in the ledger as manual-review item
  **`MR-31-SSV2C-01`**, awaiting a human decision.
- **Q-01** (`pps31q1`, `ca095edfd77e…`), about the DeployMocks rehearsal missing the Antimatter phUSD
  grant, is in `qa-report.md`. It is **unverified**: the claimed anvil revert was reasoned from code and
  never executed.
