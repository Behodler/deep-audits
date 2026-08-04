# QA Report — phoenix-phase-2-staging @ `b9391b199ef38d7bf5066b6cd81d21b283a3a4e1`

**Project**: `phoenix-phase-2-staging`
**Commit**: `b9391b199ef38d7bf5066b6cd81d21b283a3a4e1` (`b9391b1`)
**Branch**: `master`
**Run**: `reports/phoenix-phase-2-staging-24` (run-24)
**Audit type**: **script audit** (`/audit-script`) of the **promotion-ready mainnet cutover suite** — *not* a full contract scan of the submodule.
**Entry points covered**: `promotion-ready:snapshot`, `promotion-ready:dry`, `promotion-ready:broadcast`, `promotion-ready:resume`, `promotion-ready:verify`
**Regression baseline**: run-23 `c4396b1`
**Code delta since baseline**: **story-076** only — *Phase 4e: PhlimboV3 cutover + PhlimboV2 user-base migration*
(`~/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/076-phlimbo-v3-cutover-migration-in-promotion-ready-script.md`)

## Severity distribution

| Severity | Count |
|----------|-------|
| High | 0 |
| Medium | 0 |
| Low | 7 |
| QA | 1 |
| Centralization | 0 |
| **Total (this bundle)** | **8** |

**This run has no Medium.** The finding originally filed as `M-01` was **re-graded Medium → Low by human triage on 2026-08-04** and is restated **in full below as [`L-07`](#l-07)**, at status **`fix-pending`**. The separate `submissions/M-01.md` has been retired; its content lives in the `L-07` section. Its faithfulness component remains `F-03` in `submissions/spec-conformance.md`, now recorded there at Low.

> **Do not read `L-07` as a passive QA item.** It is `fix-pending` — a fix is owed and the human recorded it as *important and needing tending to*. It stays in every future scan until a human marks it `fixed`.

**Not to be confused with `submissions/M-01-C1.md`**, which is untouched by this re-grade: that file is the **carryover of a different finding** — run-22's Medium `2c53e944caee…`, still `fix-pending` — and keeps both its name and its **Medium** grade.

**Entry-point split**: `L-01` and `L-04` are `promotion-ready:resume`; `L-02`, `L-06`, `L-07` and `Q-01` are `promotion-ready:broadcast`; `L-03` is `promotion-ready:dry`; `L-05` is `promotion-ready:verify`. The `entryPoint` is a fingerprint input, so the same `contract:function` under two entry points is two distinct ledger entries by construction.

---

## Reader's notes (read before triage)

### 1. `L-02` carries an escalation trigger that must survive this Low grade

`L-02` is graded Low **only because its harmful leg is empty on today's chain state**, read empirically at block 25678182 (`PhlimboV2.desiredAPYBps() == 0`). The value is **observed, not pinned** — the script mirrors V2's APY live at `:1685` and no `require` constrains it, so any legitimate APY retune between now and the Ledger session arms the trigger.

> **REOPEN TRIGGER (FR-24-03)** — if `PhlimboV2.desiredAPYBps()` is **non-zero at cutover time**, `L-02` becomes a live principal-freeze vector and **must be re-weighed as Medium**. Re-verify `desiredAPYBps` / `phUSDPerSecond` / `accPhUSDPerShare` immediately before broadcast; any non-zero reading reopens at Medium.

This trigger belongs on the ledger entry, not only in this bundle. `L-03` and `L-04` share the same underlying condition (V2's APY being armed) and should be re-read together if it fires.

### 2. Faithfulness findings are cross-referenced, not duplicated

`L-04`, `L-05`, `L-06` and `L-07` carry `faithfulness: true` and also appear in `submissions/spec-conformance.md` as **F-02**, **F-01**, **F-04** and **F-03** respectively. The story-076 analysis lives **there**; the sections below state the deviation in one line and point across. Do not treat the two documents as independent findings.

### 3. `L-06` is a disclosed cross-repo re-file, not a fresh discovery

`L-06` re-files, at this repository's deploy site, a condition already open on the **phlimbo-ea** ledger as `V3-L-19`. Its **unresolved Low-vs-QA severity dispute is deliberately not re-decided here**. See the section for the full lineage and re-file basis.

### 4. `Q-01` was split out of `L-05` during classification

`Q-01` was bundled inside `L-05`'s evidence and recommendation and was split per **FR-24-01**. `L-05`'s original text is preserved verbatim in its record, so nothing was lost by the split; `Q-01` reproduces the relevant text as its own primary content. The two are cross-linked below and have **zero overlap in remediation** — fixing either leaves the other fully live.

### 5. Automated SAST/gas appendix (4naly3er) — **not produced this run**

4naly3er was re-attempted against the audited slice (`script/DeployMainnetPromotionReady.s.sol`, `script/VerifyPromotionReady.s.sol`) at `b9391b1`, from the writable `workspace/` clone with a `remappings.txt` generated from `foundry.toml` (52 entries). Imports resolved, but solc then failed both files with the same **diamond-dependency duplicate-interface** condition recorded in run-23:

- `TypeError: Invalid implicit conversion from contract ITokenMinterV2 to contract ITokenMinterV2 requested.`
- `TypeError: Invalid implicit conversion from contract IUniboostMintDebtHook to contract IUniboostMintDebtHook requested.`
  (`DeployMainnetPromotionReady.s.sol:2212`)

4naly3er's longest-prefix resolver plus its path-dedup heuristic resolves the same interface to **two physical files**, so `X` is not implicitly convertible to `X`. `forge build` compiles the same files without complaint under `foundry.toml`. This is a **tool-integration gap, not a code defect**, and it is recorded rather than silently dropped. The temporary `remappings.txt` was removed from the workspace afterwards; **no file in `lib/` was touched**.

**Net effect**: this bundle has **no automated bot-report baseline**. Every finding below is manual and fork-verified. A Low/QA issue of the kind 4naly3er surfaces (gas, NC, style) may be missing — acceptable here, since the audited artifacts are one-shot deployment scripts where gas and NC findings carry little weight, but the gap is real.

### 6. Carryover is not merged into this bundle

This run's `L-01…L-06` / `Q-01` sequence covers **only this run's new findings**. Still-open findings from earlier runs are carried separately under `submissions/carryover/` and must be read there, not re-derived from here. Numbering is deliberately **not** adjusted around them — a run-23 `L-04` and this run's `L-04` are different findings, and every section below carries the full fingerprint that disambiguates them.

### 7. `L-07` was `M-01` until human triage on 2026-08-04

`L-07` is the finding this run originally filed as **`M-01`** (Medium, `borderline: true`, explicitly flagged for human review). A human re-graded it **Low** and set it **`fix-pending`** on **2026-08-04**. This was a **human triage decision, recorded here — not an automated re-classification**, and the **fingerprint `6b63ef65…` is unchanged** (severity is not a fingerprint input), so the ledger identity and history survive the re-grade intact.

The re-grade rationale, and the ordering constraint that survives it, are stated in the `L-07` section itself. Two consequences for a reader: the finding sits at the **end** of the Low sequence rather than at its original severity rank, and its **`fix-pending`** status means it is **not** disposed of — it is rescanned and carried over exactly like an open finding.

---

# Low Risk Findings

### [L-01] `baselines.phusdMinterMask` is the one write-once baseline with no resume abort, so a resume leg silently re-derives a POST-cutover mask and the two-sided delta self-certifies <!-- id: pps24l1 -->

**Fingerprint**: `afe6374745896ddeb6c0c10cd3520c4015e71aa477f72080d856467e3560924f`
**Entry point**: `promotion-ready:resume`
**Severity**: Low · root cause `WriteOnceBaselineMissingResumeGuard` · not a regression · not a faithfulness deviation
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L974-L997`](../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L974-L997) — `_snapshotPhusdMinterSet`

**Description**

The suite now carries three write-once baselines. Two are mechanically protected against a hand-trimmed progress file: `bptAtCutover` (story 074) and `phlimboV2StakedAtCutover`, whose Phase 0 has an explicit `require(!_isConfigured("p4e_migrate") || phlimboBaselineFromProgressFile, "RESUME ABORT: ...")` at `:798-801`, precisely because re-deriving it from an emptied V2 would make the conservation assertion vacuous.

The third — `phusdMinterMask` / `phusdMintVersion`, which **story 076 promoted from a supporting record to the load-bearing input of the two-sided delta** — has no such guard. `_snapshotPhusdMinterSet` (`:974-997`) returns early only when `phusdMinterBaselineFromProgressFile` is already true; otherwise it records the **live** mask unconditionally, with no reference to whether `p4e_v3_mintGrant` / `p4e_v2_mintRevoke` have already run.

A `:resume` whose progress file lost the `baselines` block therefore stamps a **post-cutover** mask as the Phase 0 baseline and writes it straight back out. `VerifyPromotionReady._verifyMintAuthorityInvariance` then sees `phusdMinterBaselineFromProgressFile == true` (`:230-233` satisfied), compares live against a baseline taken from the same post-cutover state, and passes `liveMask == baseline & ~v2Bit` **trivially** — bit 19 is already clear on both sides after the revoke.

**Impact**

A green `promotion-ready:verify` that proves nothing about the phUSD mint-authority delta — the single control story 076 added to replace story 072's now-false "minter set byte-identical" invariant, and the one the operator is told (`:232`) is verified **nowhere else**. It fails **open**, not closed.

Reaching it requires an operator hand-trim error on the resume path, which the docs warn against in prose (`:800`, `:171-173`) — but the identical risk on the two sibling baselines was considered serious enough to guard **in code**, so **the asymmetry is the defect**.

**Why Low, not Medium**: the verifier is an assurance surface, not a protocol function; a vacuous pass does not by itself move value or impair availability.

**Recommendation**

Mirror `:798-801` verbatim for the mint-authority baseline: in `_phase0_preconditions`, immediately after `_snapshotPhusdMinterSet()`, add

```solidity
require(
    !(_isConfigured("p4e_v3_mintGrant") || _isConfigured("p4e_v2_mintRevoke"))
        || phusdMinterBaselineFromProgressFile,
    "RESUME ABORT: a phUSD setMinter step is already configured but the progress file carries no baselines.phusdMinterMask - restore that block verbatim; re-deriving it post-cutover makes the two-sided delta vacuous"
);
```

Optionally also refuse to overwrite when `phusdMinterBaselineRecorded` would be taken after any Phase 4e mutation.

**Lineage (disclosed, not collapsed)**: same *class* as ledger `L-02` `4fd1642310` (Phase 7's BPT conservation assertion degrades to `>= 0` on every resume path) and adjacent to `80a741a27f` (`bptAtCutover` provenance binding). Different baseline, different mechanism (silent re-derivation of a post-state baseline vs. degradation to a zero baseline vs. an unverifiable persisted value), different control, disjoint fixes. Fixing either leaves this fully live.

---

### [L-02] The `totalStaked() == 0` completeness gate that makes `phUSD.setMinter(PHLIMBO_V2, false)` safe is evaluated in forge's local pass, so it constrains pre-broadcast state, not the state the revoke actually lands in <!-- id: pps24l2 -->

**Fingerprint**: `b57dcb4bb59489f0676ca1a6a44293be0057b0649be5551bab4723fa5cbbf135`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low **on today's state** · root cause `ForgeLocalPassPrecedesBroadcast` · not a regression · not a faithfulness deviation
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1779-L1795`](../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1779-L1795) — `_phase4e_phlimboV3Cutover`

> ## ⚠ REOPEN TRIGGER — RE-WEIGH AS **MEDIUM** IF ARMED
>
> **If `PhlimboV2.desiredAPYBps()` is non-zero at cutover time, this finding is a live principal-freeze vector and MUST be re-weighed as Medium.**
>
> The safe value is **observed, not pinned**: the script mirrors V2's APY live at `:1685` and no Phase 0 `require` constrains it, so the trigger can be armed between now and the Ledger session by any legitimate APY retune. **Re-verify `desiredAPYBps` / `phUSDPerSecond` / `accPhUSDPerShare` immediately before broadcast; any non-zero reading reopens at Medium.** This trigger is part of the finding, not a footnote to it — it must be recorded on the ledger entry and must not be discarded with the Low grade.

**Description**

Story 076 Concerns §3 and the inline comment at `:1785-1790` argue the V2 mint revoke is safe because two facts hold at the moment it executes: `totalStaked == 0` (so `PhlimboV2._claimRewards` early-returns before its **bare, reverting** `phUSD.mint` at `PhlimboV2.sol:495`) and `desiredAPYBps == 0` (so a late staker accrues nothing).

Both are enforced by statements that forge evaluates during its **single local execution pass**, before transaction #1 is dispatched (the `ForgeLocalPassPrecedesBroadcast` property established by run-23 and documented for this suite in the `:verify` npm doc key). Under `--slow --ledger` the actual broadcast runs for minutes across many blocks, and `PhlimboV2.stake` is ungated and — by this story's own deliberate design — **unpausable**. So the gate at `:1779` is a statement about the fork state **at signing time**; the `setMinter(PHLIMBO_V2, false)` transaction lands later against state the gate never saw.

`VerifyPromotionReady` does re-check `v2.totalStaked() == 0` live (`:2420`), but only **after** the revoke has already landed — **it detects, it does not gate**.

**Impact**

A user who stakes into PhlimboV2 during the broadcast window, after Phase 4e's last `migrate` transaction and while V2 still carries a non-zero APY, accrues pending phUSD that V2 can no longer mint once the revoke lands, and their `withdraw` reverts — **freezing principal**, precisely the failure the gate is documented as preventing.

The window is **empty today**, verified empirically rather than assumed: `PhlimboV2.desiredAPYBps() == 0`, `phUSDPerSecond() == 0` and `accPhUSDPerShare() == 0` at block 25678182, so no position — existing or late — can accrue pending phUSD. The finding is the **ordering property**; see the trigger above.

**Not refuted by the run-23 walk-back.** That walk-back established that a local-pass **revert** aborts atomically before dispatch. This is the **converse**: the gate **passes** locally and the mutation lands minutes later against state the gate never saw. The atomic-abort property does not constrain post-local-pass state drift.

**Recommendation**

Two options, both cheap.

**(a)** Re-order so the revoke can never precede a live check: split `phUSD.setMinter(PHLIMBO_V2, false)` out of Phase 4e into a separate, separately-signed follow-up key run **after** `promotion-ready:verify` has confirmed `totalStaked() == 0` against live post-broadcast state.

**(b)** Make the revoke **self-gating on chain** by routing it through a tiny helper that reads `PhlimboV2.totalStaked()` and reverts if non-zero **in the same transaction** as the `setMinter` call, so the gate and the mutation are atomic.

Additionally, add a Phase 0 `require(IPhlimboV2Like(PHLIMBO_V2).desiredAPYBps() == 0)` so the safe case is **pinned rather than merely observed**, and the script refuses to run in the configuration where this bites.

**Lineage (disclosed)**: fifth-generation member of the `ForgeLocalPassPrecedesBroadcast` family (`ea648ec5ea`, `3c957109ef`, `2212c1c4e8`, `5c6d2c9e3b`, `2c53e944ca`), filed individually per this ledger's established precedent. Ancestor `M-01` `2c53e944ca` (fix-pending) is the *absence* of post-broadcast verification, answered by story 075's `VerifyPromotionReady`; this is the residual that verification structurally **cannot** answer, because a check that runs after the revoke detects but does not gate. `M-01` was read only — not matched, not modified.

---

### [L-03] Phase 0 never establishes that PhlimboV2 can mint phUSD during the migration, yet every migrated position with pending phUSD routes through V2's bare, reverting `phUSD.mint` <!-- id: pps24l3 -->

**Fingerprint**: `ea56e89aba49e10ad21f266530c5229849aca73526bdcf089c1c2d398ca7aa73`
**Entry point**: `promotion-ready:dry`
**Severity**: Low · root cause `UncheckedPreconditionOnMigrationPayoutPath` · not a regression · not a faithfulness deviation
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L784-L787`](../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L784-L787) — `_phase0_phlimboV3Preconditions`

**Description**

`MigratorV2V3.migrateOne` migrates a user by calling `phlimboV2.withdraw(amount, user)`, which runs `PhlimboV2._claimRewards` (`:486`) and pays the phUSD leg with a **bare, reverting** `phUSD.mint(beneficiary, pendingPhUSDAmount)` (`PhlimboV2.sol:495`) whenever `pendingPhUSDAmount > 0`. V3's non-reverting `try`/bank was added by phlimbo story 029 to **V3 only**.

So the migration's per-user body silently depends on PhlimboV2 holding an active phUSD mint grant for any position carrying pending phUSD. Phase 0 **reads that grant and logs it** (`:784-787`, `console.log("  V2 holds phUSD mint:  ", ...)`) but **never requires it**, and Phase 4e's step 14 only ever *revokes* it.

Because `migrateOne` runs inside `migrate`'s `try`/`catch`, a revert here is absorbed into `UserMigrationSkipped` and **the cursor advances** — so the failure is a **silent skip**, not an error. The hard `require(v2.totalStaked() == 0)` gate at `:1779` then aborts the **entire** promotion-ready cutover on behalf of a defect three contracts away.

**Impact**

Latent, not live, verified on chain rather than assumed: `phUSD.authorizedMinters(PhlimboV2)` reads `(false, 0)` and `PhlimboV2.accPhUSDPerShare()` reads `0` at block 25678182, so no live position carries pending phUSD and the dependency is dormant — consistent with the dry run migrating all 16 users with **zero skips**.

Were V2's APY ever armed between now and the Ledger session (which also re-arms accrual on existing positions), every position with pending phUSD would be skipped, the gate would abort the whole cutover, and the operator's only diagnostic would be **raw revert bytes** in `UserMigrationSkipped`. Because the abort happens in the local pass this is a **liveness/operational footgun, not asset risk** — nothing broadcasts, no user position changes, and a retry after granting the mint succeeds.

**Recommendation**

Add a Phase 0 precondition that makes the dependency explicit and self-diagnosing rather than leaving it to a log line:

```solidity
require(
    IPhlimboV2Like(PHLIMBO_V2).accPhUSDPerShare() == 0 || _v2HoldsPhusdMint(),
    "PhlimboV2 has advanced accPhUSDPerShare but holds no phUSD mint authority - every position carrying pending phUSD will be SILENTLY SKIPPED by migrateOne and the totalStaked()==0 gate will abort the cutover. Grant it before Phase 4e and let step 14 revoke it afterwards"
);
```

This costs nothing today (both sides read `0`) and turns an unexplained whole-cutover abort into a one-line diagnosis.

**Related**: `L-02` touches the same phUSD mint authority from the opposite end (revoke ordering vs. grant unasserted during payout) — different phases, different fixes. Ledger `L-07` `b28492ce97` is the same *shape* (missing Phase 0 probe) on the off-chain snapshot file. phlimbo-ea `V3-M-04` (`9555286771…`) is a skip-accumulation path ending at the same `:1779` gate abort; see manual-review `MR-24-01` for the refutation of the cursor-pin reading.

---

### [L-04] PhlimboV3's committed APY is proven only inside the `_isConfigured` gate a resume skips; neither Phase 7 nor VerifyPromotionReady ever reads `v3.desiredAPYBps()` or `v3.apySetInProgress()` <!-- id: pps24l4 -->

**Fingerprint**: `7bec406d1d46af89a6b476dde3c9c632e081693a92bdcb3dc5170590d669484e`
**Entry point**: `promotion-ready:resume`
**Severity**: Low · root cause `ResumeSkippedAssertionNotReprovedByVerifier` · not a regression
**Faithfulness**: **yes** — filed as **`F-02`** in [`spec-conformance.md`](spec-conformance.md) against **story-076** (Autonomous Decision 2). *The story analysis lives there and is not repeated here.*
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1684-L1688`](../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L1684-L1688) — `_setDesiredAPYTwoStep`

**Description**

Story 076 Autonomous Decision 2 correctly identifies that `desiredAPYBps() == bps` is a **vacuous** read-back when `bps == 0` (both real cases here), and adds `require(!p.apySetInProgress())` at `:1826-1832` so a missed 100-block commit window fails loudly.

That non-vacuous proof lives **entirely inside** `_setDesiredAPYTwoStep`, which Phase 4e calls only from within `if (!_isConfigured("p4e_v3_apy"))` (`:1684-1688`). `_trackConfig("p4e_v3_apy")` is stamped into the progress file during forge's **local pass** (`_trackConfig` → `_writeProgressFileWithStatus`, `:3009-3015`), i.e. **before either `setDesiredAPY` transaction is dispatched**. If the second (commit) transaction is rejected or dropped on the Ledger, the progress file already records the step as done, a `:resume` skips it, and PhlimboV3 is left **latched mid-preview with the APY uncommitted**.

Grep over both script files confirms `v3.desiredAPYBps()` appears **nowhere** in Phase 7 or `VerifyPromotionReady` (`:2419` checks V2 only), and `apySetInProgress()` appears nowhere outside `_setDesiredAPYTwoStep`. Phase 8's `_probePhlimboV3StakeClaim` cannot substitute: it is preview-only **and** it deliberately **arms its own 1000-bps probe APY whenever it reads 0** (`:2530-2535`), so it masks exactly this failure.

**Impact**

Today the mirrored target is `0` (verified live: `PhlimboV2.desiredAPYBps() == 0`), so a missed commit leaves V3 at the same value it was going to be set to, and the residue is a stuck `apySetInProgress` latch. The defect is **structural, not conditional**: if V2's APY is ever retuned non-zero before the Ledger session (the script mirrors it live, `:1685`), a resume leg would leave PhlimboV3 **emitting nothing** while every post-cutover assertion and the whole verifier report read green — the exact silent-failure shape story 076 exists to close on the mint side. Re-weigh then, on the same trigger recorded for `L-02`.

This raises **no objection to the two-step APY mechanism** (KI #4 blesses it, and this finding accepts it); it is a verification-coverage defect about that feature's outcome.

**Recommendation**

Add two `view` assertions to `_phase7_phlimboV3Assertions` so `VerifyPromotionReady` inherits them:

```solidity
require(
    !IPhlimboAPYLike(newPhlimboV3).apySetInProgress(),
    "PhlimboV3 left latched mid-preview - the APY commit never landed"
);
require(
    IPhlimboAPYLike(newPhlimboV3).desiredAPYBps() == IPhlimboV2Like(PHLIMBO_V2).desiredAPYBps(),
    "PhlimboV3 APY does not mirror V2's"
);
```

Note the second must be **sequenced against step 11** (which zeroes V2), so either capture the mirrored target as a write-once baseline alongside `phlimboV2StakedAtCutover`, or assert only the latch. Add the same `!apySetInProgress()` check for PhlimboV2 next to the existing `:2419` check.

**Kept separate from `L-05`**: `L-05`'s fix (adding a V2 pause assertion) leaves `v3.apySetInProgress()` and `v3.desiredAPYBps()` just as unread.

---

### [L-05] Phase 4e's docstring and Phase 7's banner both claim the "NOT paused" property is asserted, but no `require(!v2.paused())` exists in Phase 7 or in VerifyPromotionReady <!-- id: pps24l5 -->

**Fingerprint**: `4bb60f7984ef7282718d7c8e395b5fabe89b34d1667cfbfa970262da6979bb73`
**Entry point**: `promotion-ready:verify`
**Severity**: Low · root cause `AssertedPropertyNotActuallyAsserted` · not a regression
**Faithfulness**: **yes** — filed as **`F-01`** in [`spec-conformance.md`](spec-conformance.md) against **story-076** (Review Results item 1, story lines 825-833; Auto-Completed `[low]` at line 889, **not** covered by the human confirmation at lines 896-901). *The story analysis lives there and is not repeated here.*
**Split**: `Q-01` was split out of this finding per **FR-24-01** — see the cross-link below.
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L2418-L2454`](../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L2418-L2454) — `_phase7_phlimboV3Assertions`

**Description**

`_phase4e_phlimboV3Cutover`'s docstring at `:1643-1645` states of the no-pause and no-promotion properties: *"NOT DONE ANYWHERE IN HERE, both deliberate and both asserted in Phase 7"*.

Phase 7 does assert the no-promotion negative (`promoToken() == 0`, `promoPhase() == None`, `:2407-2408`) but carries **no pause assertion at all**: the section is only a banner comment `// ---- V2 wound down, NOT paused. ----` (`:2418`) plus a console line `"PhlimboV2: ... NOT paused"` (`:2454`).

Exhaustive (non-truncated) grep over both script files shows the **only** V2 pause check in the whole suite is `require(!v2.paused(), ...)` at `:1748-1751`, which sits **inside** `if (!_isConfigured("p4e_migrate"))` and is therefore skipped on every resume leg, and is **never reachable** from `VerifyPromotionReady` (which overrides `run()` and calls Phase 7 only).

Consequence: the post-broadcast verifier prints "NOT paused" for a PhlimboV2 that someone paused after the cutover, and a resume leg that has already completed the migration never checks the property at all.

**Impact**

A verification log line and a phase docstring both assert a property that **nothing proves**. On its own the impact is small — a paused V2 at `totalStaked == 0` traps nobody — but this is comment drift **inside the one control surface** whose entire purpose (story 075, ledger `M-01` `2c53e944ca`, fix-pending) is to replace unticked human checklist lines with executable assertions. A reader auditing the cutover from the logs would conclude the property was machine-verified.

**Why Low and not QA**: a paused V2 means the migration cannot be trusted, so a false green on *that specific* property is the one kind of log inaccuracy this control was built to eliminate, and the fix is a one-line `view` require that `VerifyPromotionReady` inherits for free.

**Recommendation**

Add to `_phase7_phlimboV3Assertions`, next to the existing `desiredAPYBps() == 0` check at `:2419`:

```solidity
require(
    !IPhlimboV2Like(PHLIMBO_V2).paused(),
    "PhlimboV2 is paused - the migration cannot be trusted and the log below would be false"
);
```

It is `view`, so `VerifyPromotionReady` inherits it for free — exactly the property story 076 relied on for every other Phase 7 addition. If the owner prefers to allow a post-cutover pause, **delete** the "NOT paused" claim from `:1643-1645` and the log at `:2454` instead — but **do not leave both**.

Separately, make the summary's `-PhlimboV2` line conditional on `phusdMinterMaskAtPhase0 & (1 << PHUSD_MINTER_BIT_PHLIMBO_V2) != 0`, mirroring the NOTE the verifier already prints at `VerifyPromotionReady.s.sol:259-263`, so the deploy log and the verify log stop disagreeing about whether a revoke happened. *(This clause is preserved verbatim from the pre-split record; it is now filed and tracked as **`Q-01`** below — fix it there.)*

---

### [L-06] PhlimboV3 and MigratorV2V3 are deployed to mainnet from `via_ir = true` bytecode that no phlimbo-ea test has ever exercised, and story 076's Preflight ticks a `via_ir off` premise this repo does not have <!-- id: pps24l6 -->

**Fingerprint**: `c544c9f6e6c40cdb9fbd3625da54151bdbe25ea03b7ddc71766c4ae292ee8e72`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low **for this deploy-site instance** · root cause `TestedBytecodeNotDeployableBytecode` · not a regression
**Faithfulness**: **yes** — filed as **`F-04`** in [`spec-conformance.md`](spec-conformance.md) against **story-076** (Implementation Notes line 382; Preflight line 538, ticked). *The story analysis lives there and is not repeated here.*
**Location**: [`lib/phoenix-phase-2-staging/foundry.toml#L1-L7`](../../../lib/phoenix-phase-2-staging/foundry.toml#L1-L7) — function: `n/a (build configuration)`

> ## Cross-repo lineage — this is a **re-file**, not a fresh discovery
>
> phlimbo-ea's ledger carries this **OPEN** as **`V3-L-19`** (Low), fingerprint
> `38aefbfbe6da599fc5250a2cc73125465c845480e34b6a63984b2febae4a053c`,
> which anticipated this exact situation from the phlimbo side.
>
> **Re-file basis** — it was not deduplicated against `V3-L-19` because that entry lives in a **different project ledger**, outside this ledger's fingerprint space entirely; cross-repo dedup would silently remove the deploy-site instance from the only ledger that governs the deploy site. The basis is non-trivial: **different repo**, **different entry point** (`promotion-ready:broadcast`), and a **new story-076 faithfulness component** absent from `V3-L-19`. Moreover, `V3-L-19`'s own `usefulNegativeResults.v3Unwired` basis — that *"PhlimboV3 has ZERO references anywhere in phoenix-phase-2-staging"* and that *"phStaging pins `lib/phlimbo-ea` at `6cb0bc0c`, a commit whose `src/` predates `PhlimboV3.sol` entirely"* — is **FALSE at `b9391b1`**: the pin is `f279c62` and story 076 deploys both contracts. The prospective leg `V3-L-19` explicitly declined to grade **is now real**.
>
> **Severity dispute NOT re-decided here (FR-24-02 honoured).** `V3-L-19` carries an **unresolved Low-vs-QA severity dispute** awaiting human triage. The Low assigned here applies **only** to the phoenix-phase-2-staging deploy-site instance under `promotion-ready:broadcast`, on grounds specific to this site. It is **not** a ruling on `V3-L-19`, does **not** settle the Low-vs-QA question in the phlimbo-ea ledger, and **must not be cited as having settled it**. That dispute travels forward open — and the falsified `v3Unwired` basis above is a fact the human triaging it needs.

**Description**

`phoenix-phase-2-staging/foundry.toml:1-7` sets `optimizer = true`, `optimizer_runs = 10000`, **`via_ir = true`**. `lib/phlimbo-ea/foundry.toml:6-15` sets **`via_ir = false`**, with an in-file comment explaining that `via_ir` caches `block.timestamp` and breaks repeated `vm.warp`.

Every phlimbo-ea test and every audit of `PhlimboV3` / `MigratorV2V3` (stories 022-031, audits phlimbo-ea-07..11) therefore validated **legacy-pipeline bytecode**. Story 076's Phase 4e is the code that actually `CREATE`s both contracts on mainnet, and it compiles them under phStaging2's `via_ir` pipeline.

Story 076's Implementation Notes assert *"Per house knowledge, phlimbo builds use legacy + optimizer with `via_ir` OFF"*, and its Preflight checklist ticks `[x] ... that PhlimboV3 lands under the EIP-170 24 KB limit in this repo's profile (optimizer on, via_ir off)`. **This repo's profile is `via_ir` ON.** The EIP-170 purpose of that criterion **is** satisfied (PhlimboV3 measures 14,529 B here, 10,047 B of margin, `forge build --sizes`; MigratorV2V3 8,248 B), so nothing is blocked — but the tick was recorded against a build profile that does not exist in this repository.

**Impact**

**Not an exploit and no defect is demonstrated** — `via_ir` and legacy are both supported solc pipelines, and no miscompilation is asserted. What *is* demonstrated is an **assurance gap at the deploy site**: the artifact that will hold user principal is not the artifact the audit and test suites exercised, and the story's own preflight records the opposite. This is a deploy-gate/QA-class issue, not a vulnerability, and its severity should not exceed what that supports.

**Recommendation**

Either:

**(a)** Run phlimbo-ea's `PhlimboV3` / `MigratorV2V3` suites once under `FOUNDRY_PROFILE` with `via_ir = true` and record the result, accepting the documented `vm.warp` / `block.timestamp` caveat by adjusting only the affected tests; **or**

**(b)** Set `via_ir = false` for this repo's build of the phlimbo-ea sources — phlimbo-ea ledger entry `V3-L-19` records the measured fact that the legacy build is 15,979 B with 8,597 B of EIP-170 margin, so **`via_ir` is NOT load-bearing for the size limit** and can be dropped freely.

Independently, **correct story 076's Implementation Notes and Preflight tick** to say `via_ir` is **ON** in phStaging2.

---

<a id="l-07"></a>

### [L-07] Story 076 Concerns §4 states both deposit views are bound to PhlimboV2; the ViewRouter-registered `DepositPageView` is in fact bound to PhlimboV1, so the recorded follow-up would move the live UI onto a staler view <!-- id: PR24-06 -->

> **STATUS: `fix-pending` — a fix is owed. This is not a passive QA item.**
> Human triage, **2026-08-04**: *"funds aren't lost but this is important and needs tending to."*
> Filed at **Medium as `M-01`** by the severity-classifier (flagged `borderline: true` for human review) and **re-graded Low by the human on 2026-08-04**. The **fingerprint is unchanged** — severity is not a fingerprint input. `submissions/M-01.md` has been retired and its content is reproduced here in full.

**Fingerprint**: `6b63ef6516ac1751c6611aa0de8273427425eba6b1d771824d4526adf76e7cea`
**Entry point**: `promotion-ready:broadcast`
**Severity**: Low (**human-triaged down from Medium, 2026-08-04**) · status **`fix-pending`** · root cause `StaleImmutableViewPointerAcrossCutover` · not a regression · **faithfulness deviation — `F-03`** in `submissions/spec-conformance.md`
**Location**: [`src/views/DepositPageView.sol#L9-L15`](https://github.com/Behodler/phoenix-phase-2-staging/blob/b9391b199ef38d7bf5066b6cd81d21b283a3a4e1/src/views/DepositPageView.sol#L9-L15) — `constructor`
**PoC**: `workspace/phoenix-phase-2-staging/test/poc-M-01-stale-view-router-deposit-page.t.sol` (filename retains the original label)

#### Why Low, and what the Medium rested on

The original Medium rested on **three legs together**, none of which cleared the Medium bar alone. Each was re-examined at triage:

1. **Live blast radius is zero today.** The router-resolved `DepositPageView` is **not the surface the live UI polls** — phlimbo-ui reads `DepositView` **directly**, via `useDepositViewPolling.ts:94`. Nothing today routes a user through the stale binding.
2. **The false-premise leg is a documentation deviation.** Story 076 Concerns §4 asserts a fact about chain state that is false. By C4 that is a spec deviation — **QA/Low**, not Medium.
3. **The ordering trap is contingent.** The (b)-before-(a) regression requires a follow-up that `story-dependencies.md:222` records as **"not yet a story"**. It is a hazard against a plan that has not been scheduled.

Additionally, the **post-cutover blank deposit page is a known and accepted consequence**, recorded in story-076 Concerns §4 and already covered by **run-22's `Q-01`** — it is not new information.

**What remains genuinely new is a factual error in the record: the story says V2, the chain says V1.** That is a Low. No funds are at risk; principal in PhlimboV2/V3 remains fully withdrawable throughout, and every value-bearing path — deposit, withdrawal, migration — is untouched. The defect is confined to on-chain read surfaces (`src/views/**`) and the record that describes them.

**The `fix-pending` status is the load-bearing half of this triage.** The grade moved down; the obligation did not. This is explicitly **not `acknowledged`** — nobody decided to live with it — so it is never suppressed, is rescanned every run, and is carried over until a human marks it `fixed`.

#### Description

Both deposit view contracts bake their Phlimbo target as an immutable set at construction ([`DepositPageView.sol#L9-L15`](https://github.com/Behodler/phoenix-phase-2-staging/blob/b9391b199ef38d7bf5066b6cd81d21b283a3a4e1/src/views/DepositPageView.sol#L9-L15); the same pattern at `src/views/DepositView.sol:21`). A Phlimbo generation change therefore requires a redeploy, not a setter.

Read live on mainnet:

- `ViewRouter.pages(keccak256("deposit"))` resolves to **`DepositPageView 0x50D4443782bB9A6e8D65dAcd593684EDd3FF03b8`**, whose immutable `phlimbo()` is **PhlimboV1 `0x3984eBC84d45a889dDAc595d13dc0aC2E54819F4`** — *not* PhlimboV2 `0x6084a02C2Ac0127ddF1e617De257c61480A2AeE0`.
- The **deprecated** `DepositView 0x0725722b…` — the contract the live UI actually polls (`useDepositViewPolling.ts:94`) — *is* correctly bound to **PhlimboV2 `0x6084a02C…`**. It was redeployed against V2 under the story 049 follow-up; `DepositPageView` was left behind on V1.

The three legs follow from that inversion.

**Leg 1 — the router surface is already stale, and gets worse at cutover.** The router-registered deposit page is one generation stale *today*, pre-cutover. PhlimboV1 still reports `totalStaked == 13615682000000000000000`, so the stale view returns plausible non-zero data rather than obviously-broken zeros. After Phase 4e it is two generations stale. Separately, the deprecated `DepositView` the live UI reads is bound to a PhlimboV2 that Phase 4e deliberately empties to `totalStaked == 0` — a post-cutover blank deposit page that story-076 Concerns §4 records as known and accepted, and that run-22's `Q-01` already covers.

**Leg 2 — a documented scope exclusion rests on a false basis.** Story 076 Concerns §4 (story line 475) states: *"So both views are bound to V2, and the live deposit UI is on the deprecated one."* That premise is false for the router-registered surface. The view layer was declared out of scope on the strength of it. **This factual error in the record is the residual substance of the finding at Low.**

**Leg 3 — the recorded follow-ups are in the harmful order.** Story 076 records two follow-ups: **(a)** redeploy `DepositPageView` against V3, and **(b)** move phlimbo-ui's deposit page onto ViewRouter resolution "the way the mint page already is". Executing **(b) before (a)** migrates the live deposit page **off** a V2-correct view **onto** a V1-bound router view — a one-generation regression onto a view that is itself two generations stale post-cutover, at the exact moment the UI is supposed to be repaired. The required **(a)-before-(b)** ordering is recorded nowhere: `story-dependencies.md:222` holds both items only as an HTML comment marked *"not yet a story"*, with no numbered dependency row and no sequencing note. The one artifact that discusses the matter — Concerns §4 — states a premise that makes (b)-first look safe.

This is a Law-3 footgun, not an owner-malice vector: a competent, non-malicious owner following their own written follow-ups would be surprised to discover they had regressed the deposit page a generation.

#### An API correction that matters here

The deprecated `DepositView` does **not** implement `IPageView.getData`. It exposes `getDepositData(address)`, returning a struct. **Only `DepositPageView` is router-compatible.** The two surfaces do not share the `IPageView` ABI, and nothing in this section should be read as implying they do. That asymmetry is itself part of *why* follow-up (b) exists — the deposit page cannot simply be pointed at the router without a correctly-bound page-view contract behind it — which is precisely what makes the (a)-before-(b) ordering load-bearing rather than cosmetic.

#### Impact

User-visible misreporting of staked balances on the **router-resolved** deposit surface. **No asset risk, and no live-UI exposure today** (the live UI does not read that surface). Two cases reproduced against real stakers from the live snapshot:

- Staker **`0xD57e5f043cB3C05be4E8138886cCEF2448a07C66`** holds **1517.6 phUSD** in PhlimboV2, and the router surface reports `stakedBalance == 0`.
- Staker **`0xc25cCd48…`** is the worse case: the router serves a **non-zero but fabricated** `398857400000000000000` read from the stale V1 contract, against a true V2 balance of `729672300000000000000`.

A wrong non-zero number is more dangerous than a zero. A zero reads as an outage — users retry, or report it. A wrong number reads as truth. The exposure becomes user-facing only if follow-up (b) lands before (a), which is exactly what the mitigation below prevents.

#### Proof of Concept

`workspace/phoenix-phase-2-staging/test/poc-M-01-stale-view-router-deposit-page.t.sol`

Run and **independently re-run by the orchestrator**: **3 passed / 0 failed**, mainnet fork pinned at block **25678190**.

- **`test_M01_routerDepositPageIsBoundToPhlimboV1_notV2`** — proves the binding as it stands today, pre-cutover: the router's registered deposit page resolves to `DepositPageView 0x50D4…`, whose `phlimbo()` is PhlimboV1, while the deprecated `DepositView` is on V2.
- **`test_M01_routerViewReportsZeroForRealV2Staker`** — uses real stakers from the live snapshot and reads `getData("deposit", user)[5]`. The test asserts `getNames()[5] == "stakedBalance"` so the field index is proven rather than taken on faith.
- **`test_M01_postCutoverBothDepositSurfacesAreWrong`** — rehearses the real Phase 4e under `vm.startPrank(OWNER)` using the project's own contracts, with **no `vm.mockCall` and no `vm.store`**. It asserts `PhlimboV2.totalStaked() == 0` after the rehearsal, so the migration is proven to have genuinely executed rather than the test being a pass full of silently skipped steps.

**What the PoC does not establish.** It cannot prove the documentation claims — story 076's false premise and the un-ordered follow-ups are facts about documents, not about chain state, and must be verified by reading story 076 Concerns §4 (line 475) and `story-dependencies.md:222`. It also does not prove that the real follow-ups will in fact be executed (b)-then-(a). It proves only that **if** they are executed in that order, the asserted regression follows. It likewise does not speak to which surface the live UI polls — that is established by `useDepositViewPolling.ts:94`, and it is the fact that carried the Medium → Low re-grade.

#### Recommended mitigation

**Lead with the ordering constraint — it survives the re-grade to Low unchanged.** Redeploy `DepositPageView` against PhlimboV3 and re-register it with `ViewRouter` via `setPage("deposit", ...)` — **(a)** — *before* migrating the phlimbo-ui deposit page onto ViewRouter resolution — **(b)**. In the reverse order the live UI regresses a generation.

In full:

1. **Correct the premise in the follow-up record** at `story-dependencies.md:222`: `DepositPageView` is on PhlimboV1, not V2. *(This is the residual Low itself: the record is factually wrong.)*
2. **State the ordering constraint explicitly** in that record: the phStaging2 redeploy + `ViewRouter.setPage("deposit", ...)` re-registration MUST land before the phlimbo-ui migration, or the UI regresses a generation.
3. **Number both follow-ups as real stories** rather than leaving them as HTML comments, since they become live the moment story 072 broadcasts.
4. **In the interim, add a read-only Phase 7 / verifier NOTE** that logs `DepositPageView.phlimbo()` and `DepositView.phlimbo()` alongside `newPhlimboV3`, so the drift is visible in the cutover record rather than discovered by users.

The redeploy itself is legitimately out of scope for a script-and-tooling story; the correction owed by this story is to the *record* — the false premise and the missing ordering — not to the view contracts.

**Related (not folded in):** manual-review `MR-24-05` — PhlimboV1's non-zero `totalStaked` was observed while verifying this finding and is parked as out-of-closure.

---

# QA Findings

### [Q-01] The cutover summary asserts `-PhlimboV2` phUSD minter movement unconditionally, contradicting the same run's Phase 0 read of `V2 holds phUSD mint: false` and the verifier's own conditional NOTE <!-- id: pps24q1 -->

**Fingerprint**: `5af6ac977dc57f5a9ce3ae10abb16fa57cbed2920a130c134daedc5356beb2d7`
**Entry point**: `promotion-ready:broadcast`
**Severity**: QA · root cause `UnconditionalMintDeltaClaimContradictsPhase0Mask` · not a regression · not a faithfulness deviation
**Split from**: **`L-05`** (`4bb60f7984ef7282718d7c8e395b5fabe89b34d1667cfbfa970262da6979bb73`) per **FR-24-01** — see the split basis below.
**Location**: [`lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L3114-L3115`](../../../lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol#L3114-L3115) — `_printSummary`

**Description**

`_printSummary` prints

```
phUSD minter-set DELTA (story 076): +PhlimboV3, -PhlimboV2. Nothing else moved.
```

at `:3114` **unconditionally on every run, including a broadcast**, while the same run's Phase 0 output five screens earlier reads `V2 holds phUSD mint: false` with membership mask `270080` — so the `-PhlimboV2` half is a **no-op the summary asserts happened**.

`VerifyPromotionReady._verifyMintAuthorityInvariance` handles the identical case **correctly and conditionally** at `:259-263`, printing `NOTE: PhlimboV2 did not hold phUSD mint authority at Phase 0 - the revoke was a no-op.` when the baseline bit is clear, and the affirmative line only when it was set. The deploy log and the verify log of the same cutover therefore **disagree about whether an authority movement occurred**.

Live corroboration at block 25678182: `phUSD.authorizedMinters(PhlimboV2)` reads `(false, 0)`.

**Impact**

**No state divergence**: PhlimboV2 could not mint phUSD before the run and cannot after it, so the end state matches the claim's intent even though the claimed transition never happened. The impact is confined to the **deploy record** — a reader certifying the cutover from the deploy log alone concludes a revoke occurred that did not, and must reconcile it against a verify log that says the opposite.

**Why QA and not Low** (unlike `L-05`): no assertion or control is claimed-but-absent here. The property the summary misreports **is** independently and correctly verified by `VerifyPromotionReady:259-263` on the same cutover, so there is no path by which a wrong belief survives the verify step. The defect is confined to one `console.log`'s phrasing.

**Recommendation**

Make the summary's `-PhlimboV2` clause conditional on `phusdMinterMaskAtPhase0 & (1 << PHUSD_MINTER_BIT_PHLIMBO_V2) != 0`, mirroring the NOTE the verifier already prints at `VerifyPromotionReady.s.sol:259-263`, so the deploy log and the verify log stop disagreeing about whether a revoke happened. When the bit was clear at Phase 0, print:

```
+PhlimboV3 only; PhlimboV2 held no phUSD mint authority at Phase 0, so the revoke was a no-op. Nothing else moved.
```

The conditional already exists in the suite and can be copied.

**Split basis (FR-24-01)** — exercised the authority dedup and the sanitizer explicitly declined, on four grounds: (1) **different artifact** — `_printSummary`'s deploy-log output at `:3114` vs `_phase7_phlimboV3Assertions`' missing `require` at `:2418-2454`; (2) **different property** — the phUSD minter-set delta vs PhlimboV2's pause state; (3) **different remediation with zero overlap** — gate the `-PhlimboV2` line on the Phase 0 mask bit, vs add `require(!v2.paused())` to Phase 7; fixing either leaves the other fully live; (4) **different severity** — the summary line is contradicted and corrected by a verifier check that already exists, while `L-05`'s property is proven nowhere at all. Bundling them would have forced one severity onto two defects and hidden a QA-grade log fix inside a Low-grade coverage gap. `L-05`'s evidence and recommendation text are preserved **verbatim and unedited** in its record, so no content was lost by the split.

---

# Centralization Risks

**None.** This run produced **0 Centralization findings**. Owner-privilege surfaces reached by the promotion-ready suite were screened under Law 3: the trusted-owner cases were suppressed as obvious, and the non-obvious ones surfaced as operational footguns above (`L-01`, `L-03`) rather than as centralization risk.

---

## Appendix — automated SAST / gas report (4naly3er)

**Not attached.** 4naly3er could not produce a report for this slice at `b9391b1`. The attempt (workspace clone at the audited commit, `remappings.txt` generated from `foundry.toml`, scope = the two promotion-ready scripts) resolved all imports but failed compilation on the **diamond-dependency duplicate-interface** condition — `ITokenMinterV2` and `IUniboostMintDebtHook` each resolving to two physical files, so `X` is not implicitly convertible to `X`. `forge build` compiles the same files without complaint. See **Reader's note 5** for the exact errors and why this is a tool-integration gap rather than a code defect.

**No automated bot-report baseline backs this bundle** — every finding above is manual and fork-verified against mainnet state at block **25678182**. The temporary `remappings.txt` was removed from the workspace afterwards; nothing under `lib/` was modified.
