# Script Audit Review — `promotion-ready` suite (run-24)

**Project**: `phoenix-phase-2-staging`
**Commit**: `b9391b199ef38d7bf5066b6cd81d21b283a3a4e1` (`b9391b1`), branch `master`
**Entry points**: `promotion-ready:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`
**Regression baseline**: run-23 `c4396b1`. **Sole delta since baseline: story-076.**
**Mode**: fork-preview, RPC live — probe block **25678098**, dry run at **~25678182**, PoC pinned at **25678190**.

> This document is the **narrative supplement** to the run's submissions. It does not replace them.
> The authoritative artifacts are `submissions/qa-report.md`, `submissions/spec-conformance.md`,
> `submissions/M-01-C1.md` and `submissions/carryover/qa-report-23.md`.
> Where this review and a submission differ in detail, the submission governs.
>
> **Human triage, 2026-08-04:** this run's only Medium, `M-01`, was **re-graded Medium → Low by human triage**
> and is now **`L-07`** at status **`fix-pending`**; `submissions/M-01.md` was retired and its full content folded
> into `qa-report.md` § `L-07`. **The (a)-before-(b) ordering guidance survives the re-grade unchanged.**
> (`submissions/M-01-C1.md` is unaffected — it is the carryover of run-22's *different* Medium `2c53e944caee…`,
> still `fix-pending`, and keeps its Medium grade.)

---

## 1. Scope and closure

Story-076 adds **Phase 4e** to the mainnet cutover script: deploy `PhlimboV3`, deploy `MigratorV2V3`,
migrate the PhlimboV2 user base, wind V2 down, and repoint the new `StableYieldAccumulator` at V3.

The closure resolved cleanly:

- **97-file** import closure for `DeployMainnetPromotionReady.s.sol` and **98-file** for
  `VerifyPromotionReady.s.sol`, with **zero unresolved imports** in either.
- **37 on-chain entries** in scope — 17 compile-time constants plus 8 runtime `CREATE`s (the balance being
  referenced third-party/token addresses).
- A **14-script cluster** of siblings touching the same contracts.
- `lib/phlimbo-ea` was bumped to `f279c627…` by delta commit `c9bd423` as a story-076 dependency.

Two closure caveats are recorded rather than glossed: `PhlimboV2.sol` is **not** in the compiled closure —
V2 is reached only through hand-written inline interfaces (see §5.2) — and `codeMatchesSource` was
`skipped` for every on-chain entry (no Etherscan verified-source fetch, no `extcodehash` comparison).
Neither is a gate; both bound what the closure alone can prove.

---

## 2. Does it do what it intends?

**Verdict: substantially yes.**

Story-076's own "Proposed Phase 4e ordering" enumerates 14 steps. Every one of them is present, in the
stated order, at the stated line ranges (`intent.md` records the mapping step-by-step). The two properties
the story states negatively also hold, verified by exhaustive grep: there is **no `pause()` on PhlimboV2
anywhere** (the only `pause()` calls are Phase 4d's old batch minter at `:1596` and Phase 6's V1 staker at
`:2165`), and there is **no `startPromotion` anywhere**.

The strongest evidence is empirical rather than structural. The dry run **reproduced story-076's own
Autonomous Decision 8 numbers exactly**, from a run executed independently in this audit:

| Claim | Reproduced value |
|---|---|
| V2 snapshot stakers | **16** |
| Dust (sub-`MINIMUM_STAKE`) users | **0** |
| `migrate` calls needed | **1** |
| `UserMigrationSkipped` events | **0** |
| `PhlimboV2.totalStaked()` after | `0` |
| `PhlimboV3.totalStaked()` after | `13095559131012692364262` |
| Conservation baseline (`phlimboV2StakedAtCutover`) | `13095559131012692364262` |
| Conservation | **exact equality** — the `>=` slack was never exercised |
| Completeness gate `PhlimboV2.totalStaked() == 0` | **PASS** |
| Phase 0 phUSD minter mask / mintVersion | **270080** / **0** |
| Phase 7 wiring assertions | **ALL PASS** |
| Phase 8 mint leg delivered / banked | `8219178082191678` / **0** |

The run exited `0`, did not revert, and ran with `PREVIEW_MODE=true` under an owner prank — no `--broadcast`
and no `--ledger` at any point, executed only from `workspace/`, never from the read-only `lib/` tree.

What the intent check did surface is a set of **verification gaps around the steps**, not defects in the
steps themselves: properties the script's own docstrings and banners claim to assert but do not
(`L-05`, `Q-01`), assertions that live only inside `_isConfigured` gates a `:resume` leg skips
(`L-01`, `L-04`), and preconditions the plan depends on but never states (`L-03`). Those are §4.

---

## 3. Does it introduce unintended side effects?

**Verdict: zero unintended on-chain writes.**

All **17** observed state writes in the Phase 4e / Phase 5 slice map onto a numbered step of story-076's
plan or onto documented `MigratorV2V3` internals. `unintendedEffects` is empty.

Two writes are **intended but under-described** by the story, and are recorded here because a reader of the
story alone would not expect them:

1. **`PhlimboV2.setMigrator(migratorV2V3)` does not write into an empty slot.** The slot still holds the
   story-049 `MigratorV1V2`. That instance reads `migrateIterator == -1` — its pass is complete — so
   clobbering it retires a **finished** migrator, not a live one. The story describes this write as if the
   slot were free.
2. **`migrate()` performs a `forceApprove` of phUSD to V3.** This is intended by `MigratorV2V3`'s design but
   is not named anywhere in story-076's step list.

Three further writes are **no-ops against current mainnet state**, kept deliberately for idempotence, and
worth knowing before reading the deploy log:

- `PhlimboV2.setDesiredAPY(0)` — V2's APY is already `0`, so the wind-down moves no value today.
- `phUSD.setMinter(PHLIMBO_V2, false)` — bit 19 was **already clear** at Phase 0. The revoke changes
  nothing. The cutover summary nevertheless states it happened unconditionally; that is `Q-01`.
- The Phase 5 ordering (`sya.setPhlimbo(newPhlimboV3)` then `approvePhlimbo`) is correct — the approve
  follows the repoint, as the story requires.

**Incidental clearance.** The dry run cleared story-072's blocking **Kendu fee-on-transfer preflight**
through the `NudgeStreamer.collectNudge` probe: **sent == received == credited**; Kendu is *not*
fee-on-transfer. That blocker can be closed on evidence rather than assumption.

---

## 4. Have other problems surfaced because of it?

**Tally: 0 High / 0 Medium / 7 Low / 1 QA** (as triaged 2026-08-04; originally 0 High / 1 Medium / 6 Low / 1 QA —
`M-01` was re-graded to `L-07`, Low, `fix-pending`). Ledger **111 → 119**, unchanged by the re-grade. In addition, **18 findings carried
still-open from runs 22–23** (1 Medium at `fix-pending`, 13 Low, 4 QA) — see
`submissions/carryover/qa-report-23.md` and `submissions/M-01-C1.md`; they are **not** merged into this
run's numbering.

### 4.1 Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-01** | Low | `baselines.phusdMinterMask` is the **one** write-once baseline with no deploy-side resume abort, so a `:resume` leg silently re-derives a **post**-cutover mask and the two-sided mint delta self-certifies. Fails **open**. | Mirror the existing `:798-801` RESUME ABORT verbatim for the mint-authority baseline in `_phase0_preconditions`, aborting when a `setMinter` step is configured but no persisted `phusdMinterMask` baseline exists; optionally refuse to overwrite the baseline after any Phase 4e mutation. | [`qa-report.md` → L-01](../../submissions/qa-report.md) · `script/DeployMainnetPromotionReady.s.sol:974-997` (`_snapshotPhusdMinterSet`, `:resume`) |
| **L-02** | Low | The `totalStaked() == 0` completeness gate that makes `phUSD.setMinter(PHLIMBO_V2, false)` safe runs in forge's **local pass**, so it constrains pre-broadcast state, not the state the revoke lands in (`ForgeLocalPassPrecedesBroadcast`). Empty today: V2's APY, `phUSDPerSecond` and `accPhUSDPerShare` all read `0`. | Either split the revoke into a separately-signed follow-up key run **after** `:verify` confirms `totalStaked() == 0` against live post-broadcast state, or route it through a helper that reads `PhlimboV2.totalStaked()` and reverts if non-zero **atomically** with the `setMinter`; plus a Phase 0 `require(desiredAPYBps() == 0)` to pin the safe case. | [`qa-report.md` → L-02](../../submissions/qa-report.md) · `script/DeployMainnetPromotionReady.s.sol:1779-1795` (`_phase4e_phlimboV3Cutover`) |
| **L-03** | Low | Phase 0 never establishes that PhlimboV2 **can mint phUSD** during migration, yet every migrated position carrying pending phUSD routes through V2's bare, reverting `phUSD.mint`. Dormant today (`authorizedMinters(V2) == (false, 0)`, `accPhUSDPerShare == 0`). | Add a self-diagnosing Phase 0 precondition — `require(V2.accPhUSDPerShare() == 0 \|\| _v2HoldsPhusdMint(), …)` — so an armed-APY V2 produces a one-line diagnosis instead of a whole-cutover abort explained only by raw revert bytes in `UserMigrationSkipped`. | [`qa-report.md` → L-03](../../submissions/qa-report.md) · `script/DeployMainnetPromotionReady.s.sol:784-787` (`_phase0_phlimboV3Preconditions`, `:dry`) |
| **L-04** | Low | PhlimboV3's committed APY is proven only inside the `_isConfigured` gate a `:resume` skips; neither Phase 7 nor `VerifyPromotionReady` ever reads `v3.desiredAPYBps()` or `v3.apySetInProgress()`. Phase 8's probe is self-defeating — it arms its own 1000 bps when it reads 0. | Add two `view` assertions to `_phase7_phlimboV3Assertions` (inherited by the verifier for free): `!apySetInProgress()` on V3, and V3's `desiredAPYBps()` against the mirrored target — capturing that target as a write-once baseline since step 11 zeroes V2 — plus the same latch check for V2 beside `:2419`. | [`qa-report.md` → L-04](../../submissions/qa-report.md) · `script/DeployMainnetPromotionReady.s.sol:1684-1688` (`_setDesiredAPYTwoStep`, `:resume`) · **F-02** |
| **L-05** | Low | Phase 4e's docstring (`:1643-1645`) and Phase 7's banner and log (`:2418`, `:2454`) all claim the "NOT paused" property is asserted, but **no `require(!v2.paused())` exists** in Phase 7 or in the verifier. The only check sits inside the `p4e_migrate` gate. | Add `require(!IPhlimboV2Like(PHLIMBO_V2).paused(), …)` to `_phase7_phlimboV3Assertions` beside the existing `desiredAPYBps() == 0` check — it is `view`, so the verifier inherits it — or, if a post-cutover pause is acceptable, delete the claim from `:1643-1645` and the log at `:2454`. Do not leave both. | [`qa-report.md` → L-05](../../submissions/qa-report.md) · `script/DeployMainnetPromotionReady.s.sol:2418-2454` (`_phase7_phlimboV3Assertions`, `:verify`) · **F-01** |
| **L-06** | Low | `PhlimboV3` and `MigratorV2V3` deploy to mainnet from `via_ir = true` bytecode that **no phlimbo-ea test has ever exercised**, while story-076's Preflight ticks a `via_ir off` premise this repo does not have. Disclosed cross-repo re-file of phlimbo-ea `V3-L-19`. | Either run phlimbo-ea's PhlimboV3/MigratorV2V3 suites once under a `via_ir = true` profile and record the result, or set `via_ir = false` for this repo's build of those sources (V3-L-19 measures 8,597 B of EIP-170 margin, so `via_ir` is not load-bearing); independently, correct story-076's Preflight tick and Implementation Notes. | [`qa-report.md` → L-06](../../submissions/qa-report.md) · `lib/phoenix-phase-2-staging/foundry.toml:1-7` (build configuration) · **F-04** |
| **L-07** | Low · **`fix-pending`** | *(filed this run as `M-01` at Medium; **re-graded Low by human triage 2026-08-04** — fingerprint `6b63ef65…` unchanged.)* Story-076 Concerns §4 states both deposit views are bound to PhlimboV2; the ViewRouter-registered `DepositPageView` is in fact bound to **PhlimboV1**, so the recorded follow-up (b) would move the live UI onto a **staler** view. Post-cutover the deprecated `DepositView` the UI actually reads points at a deliberately-emptied V2 — a **known and accepted** consequence per Concerns §4, already covered by run-22's `Q-01`. The live UI polls `DepositView` directly (`useDepositViewPolling.ts:94`), so today's live blast radius is zero. No asset risk. The residual Low is the **factual error in the record**: the story says V2, the chain says V1. | **Ordering constraint first — it survives the re-grade:** redeploy `DepositPageView` against V3 and re-register it via `ViewRouter.setPage("deposit", …)` — **(a)** — *before* moving phlimbo-ui onto ViewRouter resolution — **(b)**; the reverse order regresses the live deposit page a generation. Then: correct the false premise at `story-dependencies.md:222`, record the **(a)-before-(b)** ordering explicitly, promote both follow-ups from HTML comments to numbered stories, and add a read-only Phase 7/verifier NOTE logging `DepositPageView.phlimbo()` and `DepositView.phlimbo()` next to `newPhlimboV3` so the drift shows up in the cutover record. | [`qa-report.md` → L-07](../../submissions/qa-report.md#l-07) · `src/views/DepositPageView.sol:9-15` · faithfulness leg **F-03** |
| **Q-01** | QA | The cutover summary prints `+PhlimboV3, -PhlimboV2. Nothing else moved.` **unconditionally**, contradicting the same run's Phase 0 read (`V2 holds phUSD mint: false`, mask `270080`) and the verifier's own conditional NOTE — deploy log and verify log disagree about whether a revoke occurred. | Make the `-PhlimboV2` clause conditional on `phusdMinterMaskAtPhase0 & (1 << PHUSD_MINTER_BIT_PHLIMBO_V2) != 0`, copying the conditional the verifier already prints at `VerifyPromotionReady.s.sol:259-263`; when the bit was clear, print that V2 held no mint authority at Phase 0 and the revoke was a no-op. | [`qa-report.md` → Q-01](../../submissions/qa-report.md) · `script/DeployMainnetPromotionReady.s.sol:3114-3115` (`_printSummary`) |

Entry-point split: `L-01`/`L-04` are `:resume`; `L-02`/`L-06`/`L-07`/`Q-01` are `:broadcast`; `L-03` is `:dry`;
`L-05` is `:verify`. `entryPoint` is a fingerprint input, so the same `contract:function` under two entry
points is two distinct ledger entries by construction.

### 4.2 `L-07` was `M-01` — `borderline: true`, resolved by human triage on 2026-08-04

`M-01` was filed at Medium on protocol-function/availability grounds — **no asset risk** — and flagged
`borderline: true` explicitly for human review. The counter-case for **Low** was reproduced so a human could
re-grade with the whole argument in front of them:

> The harm ceiling is a display defect. The remedy is a routine view redeploy. The V1 staleness has existed
> since story 049 without any reported harm. On that weighting, this is a Low.

The case originally acted on for Medium: the post-cutover misreport is **certain** (it is the designed cutover,
not a contingency) and **universal** (the whole migrated user base), the scope exclusion rests on a premise that
is false on chain, and the documented remediation is **inverted** with the correcting order recorded nowhere.

**Human triage decision, 2026-08-04 — recorded here, not an automated re-classification: the grade was moved
Medium → Low and the finding relabelled `L-07`, at status `fix-pending`.** The three legs did not survive
re-examination at Medium: the router-resolved `DepositPageView` is **not** the surface the live UI polls
(phlimbo-ui reads `DepositView` directly, `useDepositViewPolling.ts:94`), so today's live blast radius is zero;
the false-premise leg is a spec/documentation deviation, which is QA/Low by C4; and the (b)-before-(a) ordering
trap is contingent on a follow-up `story-dependencies.md:222` records as *"not yet a story"*. The post-cutover
blank deposit page is a **known and accepted** consequence recorded in story-076 Concerns §4 and already covered
by run-22's `Q-01`. What remains genuinely new — and is the Low — is the **factual error in the record: the story
says V2, the chain says V1**.

**The ordering guidance survives the re-grade unchanged** and still leads the mitigation: **(a)** redeploy and
re-register `DepositPageView` **before (b)** moving phlimbo-ui onto ViewRouter resolution.

`fix-pending`, **not** `acknowledged` — the human's words were *"funds aren't lost but this is important and
needs tending to"*. A fix is owed, so the finding is never suppressed, is rescanned every run, and is carried
over until a human marks it `fixed`. The **fingerprint `6b63ef65…` is unchanged**: severity is not a fingerprint
input, so the ledger identity and history survive the re-grade intact (ledger count **119**, unchanged).

### 4.3 Cluster knock-on

The 14-script cluster produced one filed knock-on and three disclosed lineages:

- **phlimbo-ea `V3-L-19`** — the `usefulNegativeResults.v3Unwired` basis on which it was held prospective
  ("PhlimboV3 has ZERO references in phoenix-phase-2-staging"; "phStaging pins `lib/phlimbo-ea` at
  `6cb0bc0c`") is **false at `b9391b1`**: the pin is `f279c62` and story-076 deploys both contracts. Re-filed
  here as `L-06` with lineage and re-file basis disclosed. Its unresolved Low-vs-QA severity dispute
  travels with the entry and is **not** re-decided.
- **phStaging2 ledger `M-01` `2c53e944ca` (fix-pending)** — story-075's `VerifyPromotionReady` is its fix and
  story-076 extends it correctly. `L-02` is a *different* property (a gate's ordering, which post-hoc
  verification cannot restore), so it is not a duplicate; the lineage is disclosed on the entry.
- **phStaging2 ledger `L-02` `4fd1642310`** — same defect class as `L-01` on a different baseline
  (degradation-to-zero vs. silent re-derivation of a post-state baseline); disclosed as lineage.
- **phStaging2 ledger `L-03` `ea648ec5ea`** — its progress-file-written-during-the-local-pass mechanism is
  *widened* by story-076's 10 new keys but not changed. Parked rather than re-filed (§6).

---

## 5. Negative results — deliberately sought, and not found

Two hypotheses were pursued specifically and came back negative. A negative result that was looked for is
a result, and is recorded as such.

### 5.1 The rewritten mint-authority control is **intact**

Story-076 replaced story-072's now-false "minter set byte-identical" invariant with a two-sided delta. The
question asked was whether the shipped control actually rejects the four failure shapes. All four are
rejected:

- **Stray grant elsewhere in the candidate set** — rejected by `liveMask == baseline & ~v2Bit`
  (`VerifyPromotionReady.s.sol:251-254`).
- **Stray revoke elsewhere in the candidate set** — rejected by the same assertion.
- **V3 grant never landed** — rejected by positive assertions on the runtime address in *both*
  `_phase7_phlimboV3Assertions` (`:2397-2402`) and the verifier (`:266-275`), checked against the current
  `mintVersion` so an inert grant is caught.
- **V2 revoke never landed** — rejected, though **not by the mask**: with baseline bit 19 already clear,
  `baseline & ~v2Bit == baseline`, so the delta degenerates to the old invariance check. The case is caught
  unconditionally by the separate absolute assertion at `:2421-2426`, and the verifier prints an explicit
  NOTE (`:259-263`) rather than implying otherwise.

The lens-1 hypothesis — that the delta assertion dies quietly over a no-op revoke — is **not borne out**,
and no finding was filed on it. The supporting suite `test/PhusdMinterDeltaGuards.t.sol` was run in this
audit: **9 passed / 0 failed**. Six of the nine exercise a *local re-model* of the mask assertion rather
than the shipped verifier (the file's header says so and gives the reason); three are source-level string
pins that stop the model and the shipped assertion drifting apart. The honest caveat is that a semantically
equivalent rewrite would break the pins (noisy but safe), while a change preserving the literal substring
while altering surrounding logic would not be caught.

### 5.2 **No ABI drift** — the YS-20 / YS-31 class does not recur

`PhlimboV2` is not in the compiled closure; V2 is reached only through the hand-written `IPhlimboV2Like`
(`:3267`) and `IPhlimboAPYLike` (`:3282`), and phUSD only through `IFlaxAdmin` (`:3257`). This is exactly the
shape that produced two real Mediums in this project before — run-13 `YS-20` and run-15 `YS-31`. Every one
of the **15** inline-interface members was therefore checked against **live deployed bytecode** (`cast sig`
grepped against `cast code`, plus a live `cast call` wherever the member is a getter), not against a header.

**All 15 selectors resolve. No ABI drift.** Recorded as a verified negative.

### 5.3 CAND-03 **refuted** — `skipCurrent()` is unwired, but no pin is reachable

`skipCurrent` genuinely occurs exactly once in the whole script tree — a comment at
`DeployMainnetPromotionReady.s.sol:376` inside the `MIGRATE_CHUNK` NatSpec — is never called, and is not
declared on the script's migrator interface. It does **not** follow that a cursor pin is reachable.
`MigratorV2V3.migrate` (`lib/phlimbo-ea/src/MigratorV2V3.sol:172-211` @ `f279c62`) advances the cursor
**unconditionally**: the only per-user statements outside the try/catch cannot revert per-user, and every
remaining path `continue`s or is absorbed, so `migrateIterator` reaches `-1`. The full phlimbo-ea `V3-M-04`
record was read rather than inferred from its title — its two originally-unskippable revert vectors were
closed by phlimbo stories **026/028**, and the surviving residual is **out-of-gas only**.

There was nothing to back-stop, so nothing was filed. The real Phase 4e failure mode is skip accumulation →
`totalStaked() != 0` → the hard gate at `:1779` aborts, which under `ForgeLocalPassPrecedesBroadcast` happens
**before any transaction is dispatched** — atomic, costing nothing on chain. That is liveness, not asset
risk, and its substantive cause is filed as `L-03`. **For a human:** if `V3-M-04` is ever re-graded such
that a pin becomes reachable, reopen this — Phase 4e has no in-band recovery.

### 5.4 The `>=` conservation relaxation was **NOT re-filed**

Story-076 lines **895-901**, human-confirmed **2026-08-04**, accept the relaxation of the conservation
assertion from `==` to `v3Staked >= phlimboV2StakedAtCutover`. The recorded rationale: the cutover broadcast
runs for minutes with the UI paused, there is no MEV incentive to mask diverted stake with a direct V3
deposit inside that window, and the load-bearing `require(phlimboV2.totalStaked() == 0)` completeness gate is
unaffected.

No new basis was found to disturb it. The dry run reproduced **exact equality**, so the slack was never
exercised, and `L-02` concerns the gate's **ordering**, not its strength. **Recorded as honoured.**

---

## 6. Not findings — but do not lose these

### 6.1 Known-issues provenance defect

The project's declared `knownIssuesFile` **does not exist at HEAD**. The 11 known issues are a registry-only
cache dated **2026-01-09**, roughly seven months older than stories 072-076. KI-based suppression is
therefore **unavailable on this project until the known issues are re-extracted**. Run-24 suppressed nothing
on KI grounds.

### 6.2 Ledger fingerprint-integrity defect

Run-24's 8 fingerprints reproduce **8/8**. Existing ledger entries reproduce **37/40**. The three failures
are all from the `deploy:ratchet-mainnet` entry point (run-19), all currently `open`, and all fail under
**both** `contract`-path conventions:

- `141aceaae3946026…`
- `a57ad9ad18ffca91…`
- `3283779c37019774…`

**Consequence**: a future audit of that entry point would match nothing and silently re-file three
known-open findings as new. **Not repaired** — rewriting a fingerprint rewrites finding identity, which is a
human decision, not an agent's.

### 6.3 Stranded-stake watch (outside this closure)

PhlimboV1 `0x3984eBC8…` still reports `totalStaked == 13615682000000000000000`, even though its story-049
V1→V2 migrator (`0xb50CaF00…`) reads `migrateIterator == -1` and `userCount == 19` — i.e. its pass completed.
That may be stranded stake, an un-decremented accumulator, or users who simply never migrated. The root
cause lives in **story 049 / phlimbo-ea**, outside this entry point's closure, so it is not graded here.
**Recommendation: a targeted `/recheck` or `/analyze` against phlimbo-ea.** Flagged rather than dropped
because a non-empty V1 is a plausible user-funds question.

### 6.4 4naly3er did not run at this commit

4naly3er was re-attempted against the audited slice from the writable workspace with a `remappings.txt`
generated from `foundry.toml` (52 entries). Imports resolved, but solc failed both script files with the
**diamond-dependency duplicate-interface** condition already recorded in run-23 (`Invalid implicit conversion
from contract ITokenMinterV2 to contract ITokenMinterV2`, and the same for `IUniboostMintDebtHook`, at
`DeployMainnetPromotionReady.s.sol:2212`). `forge build` compiles the same files without complaint under
`foundry.toml`, so this is a **tool-integration gap, not a code defect**.

**Net effect: this run has no automated bot-report baseline.** Every finding is manual and fork-verified. A
Low/QA issue of the kind 4naly3er surfaces (gas, NC, style) may be missing. Stated plainly rather than left
to imply tool coverage that did not happen.

### 6.5 `promotion-ready:verify` is static / unverified

`VerifyPromotionReady` **could not be executed**: it requires `server/deployments/progress.promotion-ready.1.json`,
which only a real broadcast produces, and story 072 has never been broadcast from this tree (the dry run
confirmed `PREVIEW: no progress file written (by design)`). Its **Phase 7 body *was* exercised** end to end —
the verifier inherits `_phase7_wiringAssertions` verbatim and the dry run ran it green against live mainnet
state. Only the five **verifier-only** members are unexecuted: `_loadAndValidateProgressFile`,
`_adoptPersistedBptBaseline`, `_adoptPersistedPhlimboBaseline`, `_verifyMintAuthorityInvariance`,
`_requireNoBroadcastFlag`. **Every claim about those five is source-level and tagged unverified.**

### 6.6 Also parked

- **Minter candidate-set scope** — `_phusdMinterCandidates()` is a fixed 20-entry `pure` set plus the 15
  swept runtime deployments. A phUSD grant to any address outside those 35 moves neither the mask nor the
  sweep, so "nothing else moved" is scoped to a whitelist, not to the minter set. Inherent to what story 075
  shipped; unchanged by story 076. Closing it properly needs an enumerable minter set on phUSD — a FlaxToken
  change, not a script change.
- **`forge script` import-resolution noise** — every `:dry` invocation prints two red `ERROR` lines and an
  `Unable to resolve imports:` block for `script/FixBalancerPoolerMainnet.s.sol`, despite `foundry.toml`'s
  `skip` list. `forge build` is clean and the script proceeds, so it is noise — but a red ERROR block at the
  head of a Ledger cutover run is exactly what an operator learns to scroll past, and the next genuine
  resolution failure would look identical. Cheap fix: delete the three dead V1-era scripts rather than
  skipping them.
- **Progress file stamped during the local pass** — story-076 raises the key guard from 50 to 60 and adds a
  second write-once baseline, widening a known blast radius. Same mechanism as ledger `L-03` `ea648ec5ea`;
  attach as a scope note at triage rather than opening a new entry. It fails **closed** (a phantom
  `PhlimboV3` address degrades loudly on the first `owner()` call).

---

## 7. Summary judgement

Story-076's Phase 4e does what it says, and the dry run proves it against live mainnet state rather than
against the story's own prose. There are **no unintended on-chain writes**, the mint-authority control that
replaces story-072's broken invariant is **intact**, and the inline-interface ABI class that bit this project
twice before **does not recur**.

What run-24 found is a consistent shape rather than a single defect: **the cutover's assertions are weaker
than its documentation claims**, in four independent places — a property asserted only in a banner (`L-05`),
a summary line asserting a transition that did not occur (`Q-01`), and two proofs that live inside gates a
`:resume` leg skips (`L-01`, `L-04`) — plus one ordering property that forge's execution model makes
unenforceable where it matters (`L-02`). None of these puts assets at risk today, and each was verified
empirically against chain state rather than assumed. The remaining finding (`L-07`, filed as `M-01` and flagged
borderline) is a documentation-premise error whose consequence is a user-visible display regression; **human
triage on 2026-08-04 re-graded it Medium → Low and set it `fix-pending`**, leaving the run at **0 High / 0
Medium / 7 Low / 1 QA**. Its **(a)-before-(b) ordering guidance survives the re-grade** and is still owed.

The two most important things a reader should carry away are not findings at all: **KI-based suppression is
unavailable on this project** until the known issues are re-extracted (§6.1), and **three open ledger
fingerprints no longer reproduce** and will silently re-file as new on the next audit of their entry point
(§6.2).
