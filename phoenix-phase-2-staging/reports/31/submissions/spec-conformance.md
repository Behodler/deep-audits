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
| **F-02** | `pps31f2` | `436848b0e31b…` | owner-intent memo 2026-08-28 + story-082 Background | INTENT-DEVIATION (loss allocation) | QA | standalone |
| **F-03** | `pps31f3` | `103002cc2990…` | story-082 Overview 4 / Phase 5 | SCOPE-ADDITION without human sign-off | QA | standalone |
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

## F-02: Stakers bear the cutover loss (USDe 34.8 bps) while the protocol keeps value several times larger

- **`issueId`**: `pps31f2`
- **Fingerprint**: `436848b0e31bb43b9e54b2d494f808528d190faa1fb6d93cff9462c1148497e9`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/helpers/StableStakerCutoverCore.sol:_initiatePool / _migratePool:MigrationLossAllocatedAgainstUserIntent:stable-staker-v2-cutover`
- **Root cause class**: `MigrationLossAllocatedAgainstUserIntent`  ·  **Severity**: QA (**capped**: opportunity cost, not value leak; do not escalate)  ·  **Verified**: yes (fork @25975869)
- **Location**: [`script/helpers/StableStakerCutoverCore.sol#L300-L413`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/helpers/StableStakerCutoverCore.sol#L300-L413) (`_initiatePool` / `_migratePool`)
- **Finding record**: `reports/31/findings/faithfulness/F-02-migration-loss-allocated-against-user-intent.json`

### Intent text this deviates from (verbatim)

Owner-stated migration intent, 2026-08-28 (Law-2 authority recorded for stable-staker migrations):

> 1. **Sweep everything into principal during a migration** — all accrued yield AND the set-aside buffer.
> 2. **Relinquish over-credit.** If the yield strategies credit the staker with MORE than StableStaker is claiming, write the excess down; it returns to the protocol via the yield accumulator (stable-yield-accumulator).
> 3. **Priority order:** safe migrations > precise migrations. Err toward the USER where possible. But NEVER break protocol functionality or open an exploit vector — that outranks erring toward the user.

story-082, line 29 (Background) implements intent #2 only:

> Story 060: DOLA/USDC surplus was skimmed into V1 so strategy `principalOf(token, V1) > V1.totalStaked` on mainnet; V1 `initiateMigration` requires `principalOf == 0` after exit ("StableStaker: incomplete exit") so the surplus must be cleared with `relinquishPrincipalAsOwner(v1, principalOf - totalStaked)` first

story-082 Decision 14 (lines 260–261) leaves the V1 buffers behind:

> V1 keeps idle token balances that `initiateMigration` does not touch: ~6.997 DOLA, ~10.43 USDC, ~49.85 USDe. They stay on V1; the owner can `rescueERC20` them later

### What the code does

The cutover follows the relinquish leg (intent #2) and none of the legs that favour users (intents #1 and #3).
Frozen V1 leaves its idle buffer out of `R`, and the script leaves those buffers on V1, so every
migrating staker takes the full exit-plus-re-entry haircut. On USDe the V2 re-deposit books
`credit * (1 - 30 bps)` while the swap delivered more, so part of the users' loss immediately becomes
strategy surplus that the protocol can skim. Story-060 gave the DOLA/USDC surplus a documented purpose
(`complete/phStaging2-ys-induced-stable-staker-migration-script/060-yield-strategy-swap-migration-scripts.md`,
line 183): it *"absorbs ERC4626 rounding dust and small realized losses in any future terminal migration (R
reaches P before users take a haircut)"*. That purpose is not realized here. Intent #2 supersedes it, but story-082 never says so.

### Impact (fork-measured)

- **Users lose**: USDe 8.933848235898477800 (34.805 bps, every holder), USDC 0.170245 (0.865 bps), DOLA 0.004154983888567955 (0.034 bps).
- **Protocol keeps**: idle V1 buffer of 49.845539781409382100 USDe / 10.430694 USDC / 6.997032072106485771 DOLA; relinquished surplus of 26.898455742910213445 DOLA / 27.043385 USDC; and immediately skimmable V2 surplus (`totalBalanceOf − principalOf`) of 4.136480965658327219 USDe / 4.326353 USDC / 2.664877367748603061 DOLA.

The amounts are small and disclosed (Decisions 4 and 14), and the owner's "safe > precise" rule may justify
accepting them. The finding is that the story contains **no recorded owner acceptance** of users bearing
the haircut while the buffers go to the protocol.

### Recommendation

> Either record explicit owner acceptance in story 082 (that users bear the cutover haircut and buffers go to the protocol), or add an optional Phase 7b top-up. `rescueERC20` the V1 idle buffer to OWNER, temporarily `v2.setMigrator(OWNER)`, `depositFor(user, pre - post)` for each migrated user (bounded by the rescued buffer, noting that the USDe top-up is itself haircut 30 bps), then `v2.setMigrator(address(0))`. At minimum, amend story 082 to state where the story-060 surplus goes and why its story-060 purpose no longer applies. Do not introduce a per-client cap as a remedy; the commingled cushion is by design.

---

## F-03: The script grants phUSD mint authority to the new Antimatter contract, a third mint grant missing from story 082's Phase 5 list, and only a machine approved it

- **`issueId`**: `pps31f3`
- **Fingerprint**: `103002cc29903e4e5aada96eae77148b740846e289e2218d5d3f613404a20db0`
- **Fingerprint basis**: `lib/phoenix-phase-2-staging/script/CutoverStableStakerV2Mainnet.s.sol:_phase5_mintRights:UndeclaredMintAuthorityGrant:stable-staker-v2-cutover`
- **Root cause class**: `UndeclaredMintAuthorityGrant`  ·  **Severity**: QA  ·  **Verified**: yes (fork preview)
- **Location**: [`script/CutoverStableStakerV2Mainnet.s.sol#L425-L450`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/CutoverStableStakerV2Mainnet.s.sol#L425-L450) (`_phase5_mintRights`)
- **Finding record**: `reports/31/findings/faithfulness/F-03-undeclared-mint-authority-grant.json`
- **Pre-broadcast blocker**: human sign-off required.

### Acceptance text this deviates from (verbatim)

story-082, line 17 (Overview item 4):

> 4. Grants V2 Antimatter mint rights and phUSD mint rights.

story-082, line 75 (Phase 5):

> **Phase 5 — mint rights**: `antimatter.setApprovedMinter(v2,true)`, read back (setter is silent no-op); `phUSD.setMinter(v2,true)` (match current phUSD minter API/version on mainnet), assert `v2.phUSDMintAvailable()`. Two-sided minter-set delta assertion (story 076 style).

Both passages list exactly **two** grants, both to V2.

### What the code does

```solidity
bool public constant GRANT_ANTIMATTER_PHUSD_MINT = true;
...
IPhUSDOwner(PHUSD).setMinter(address(antimatter), true);
```

The executor added this as Decision 3 (line 210). The story's reviewer carried it forward as
*"[medium] Scope addition … It still gives a new mainnet contract mint authority, so the human should be
aware before broadcast"* (line 330). Only the story-batch machine approval followed.

### Law-1 check (done so the deviation can be judged on faithfulness alone)

No exploit path was found. `Antimatter` mints phUSD only inside `annihilate`, at exactly the antimatter
amount the caller burns. The approved Antimatter minter set is asserted to be exactly {V2}
(`approvedMinterCount() == 1`). The phUSD candidate mask moves only by the V1 bit (511→510), and
mintVersion is unchanged. During the fork cutover the phUSD supply rose by +85.471458401387198196, which
equals the sum of V1 pending rewards, with no other mint. The grant is necessary: without it,
`autoAnnihilate` reverts `phUSD: caller is not authorized to mint`, proven by negative control.
KI#11 ("Minting rights requirements for PhlimboEA and PhusdStableMinter") matches only partly: it names
other contracts, so it does **not** suppress this finding.

### Recommendation

> Record a human sign-off for the Antimatter phUSD grant in story 082 (or a follow-up story) before broadcast, and note in the Phase 8 NatSpec that the grant's issuance is bounded by `approvedMinterCount()==1` plus the V2 rate.

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
