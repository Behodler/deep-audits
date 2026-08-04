# Script Review — story-072 `promotion-ready` suite

**Project:** `phoenix-phase-2-staging`
**Submodule HEAD:** `c4396b19aea6b7b09573ba90e2e65ca9293d20a1` (`c4396b1`) · **branch** `master`
**Run:** `reports/phoenix-phase-2-staging-23` (run-23) · **command** `/audit-script`
**Entry points:** `promotion-ready:broadcast` (primary) · `promotion-ready:verify` (secondary)
**Audited as:** a **suite** of five npm keys — `:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`
**Fork verification block:** **25670926** (closure reference); the `:dry` execution ran against live mainnet at head, `:snapshot` pinned **25671016**
**Stories:** `story-072` (`complete/phStaging2-promotion-ready/`), `story-074` and `story-075` (`auto-complete/phStaging2-audit-fixes/`)

> **This document supplements the submissions; it does not replace them.** The authoritative
> per-finding records are `findings/low/L-0{1..5}.json`, `findings/qa/Q-01.json`,
> `submissions/qa-report.md` (bundle), `submissions/spec-conformance.md` (Law 2), and
> `decisions.md` (four decisions, including the severity walk-back). Carryover lives in
> `submissions/M-01-C1.md` and `submissions/carryover/qa-report-22.md`.

**Result: 0 High · 0 Medium · 5 Low · 1 QA.** The cutover **has not been broadcast**.

---

## 1. Fix verification — the run's primary purpose

Run-23 exists chiefly to grade the two stories written to close run-22's findings. Both close
their stated root cause. **Neither has been applied in the ledger** — both remain `open` with
proposal-only fields, because only a human applies `fixed`.

### run-22 `M-01` — `2c53e944caee2e74a1a351c9b30b9e92cd8feac28203e8d5c1c9b7d9e8b4102f` → **COMPLETE FIX** (story-075)

The stated defect was that *the broadcast run performs zero on-chain verification of its own
outcome*. `script/VerifyPromotionReady.s.sol` closes it: a separate `forge script` invocation with
no `--broadcast` that re-runs `_phase7_wiringAssertions()` against live post-dispatch state and
adds a **phUSD mint-authority invariance check that existed on no path before**. Every check is a
`require`.

The `&&` chain is **fail-closed, not fail-silent**: a non-zero forge exit skips *both* the
`patch-mainnet-addresses-promotion-ready.js` leg and the verify leg, and npm surfaces the failure.
Verification is not silently dropped — it is deferred to a manual invocation that remains
available. Empirically corroborated: the standalone `:verify` run performed exactly two cheatcode
operations (`vm.envOr("PREVIEW_MODE")` and a failed `vm.readFile`) before aborting — **zero state
mutation, zero broadcast context**.

Two residuals shipped *by* the fix, both filed and both Low/QA: `L-03` (the verifier's
"the cutover did not complete" gate is structurally incapable of detecting an incomplete cutover)
and `Q-01` (`_requireNoBroadcastFlag` names an invariant it cannot check). `L-03` is **not** the
dangerous "incomplete fix reads as done" pattern — the verifier discloses its own limits in its
`run()` epilogue.

### run-22 `L-02` — `4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42` → **COMPLETE FIX** (story-074)

Story-074 carried a conditional-Medium trigger: *"weakening any rail re-classifies L-02 as
Medium."* **It does not fire.** No rail was weakened; rails were **added**, and one was
**tightened** — the old escape hatch `bptAtPhase0 > 0 || newPooler != address(0)` is now the
strict `bptAtPhase0 > 0`. Rails verified in source:

| Rail | Location |
|---|---|
| `keyExistsJson`-guarded read of `.baselines.bptAtCutover` as a decimal **string** | `:2013-2020` |
| `bptAtPhase0 = max(persisted, live)` — monotonic ratchet | `:549` |
| RESUME ABORT when `pooler_bpt` configured but no persisted baseline | `:564` |
| `require(bptAtPhase0 > 0)` — **tightened** | `:571` |
| `balanceOf(newPooler) >= bptAtPhase0` | `:1725` |
| stopgap floor | `:1729` |
| verifier requires baseline present **and** `> 0`, deliberately **no** live-read fallback | `VerifyPromotionReady.s.sol:147-154` |
| guard test source-scan: verifier contains no `OLD_POOLER` reference at all | `test/VerifyPromotionReadyGuards.t.sol` |

The Phase 7 conservation assertion is now **non-vacuous**: the baseline in this run's `:dry` was
`16867526417628291567945`, not `0`. The one uncovered adversarial case — a baseline hand-edited
*downward* to a smaller non-zero value — is filed separately as `L-04`.

### The `/ledger` commands a human must run to apply these proposals

```
/ledger phoenix-phase-2-staging fixed 2c53e944caee2e74a1a351c9b30b9e92cd8feac28203e8d5c1c9b7d9e8b4102f
/ledger phoenix-phase-2-staging fixed 4fd1642310fda0d39651222b70258297d0eb35e8b48634287b584aeae4a3da42
```

Run-23 wrote nothing to `reports/ledgers/phoenix-phase-2-staging.json`. Entry count is unchanged
at **111**; `lastAuditedCommit` (`0e190e8`), `branchBaselines` and every human-set status are
untouched.

---

## 2. The severity walk-back — run-23's only Medium was refuted

This run filed a **Medium (`M-01`)** on a single premise: that a mis-resolved snapshot address
produces a **partially-applied, irreversible mainnet cutover**, because the guards sit inside
Phase 6 after Phases 1-5 have already dispatched.

**Adversarial PoC validation refuted it.** A self-contained probe (`forge script` without
`--broadcast`) established that:

- forge executes `run()` as **one local EVM frame** and dispatches only if that frame returns
  successfully. A later revert **unwinds the entire frame** — both broadcast-recorded actions
  rolled back, forge exited `1`, **nothing dispatched**.
- `--skip-simulation` skips the **per-transaction pre-send check**, not the local pass.
- The guard's inputs (`users.length` from `vm.readFile`; `preTotal` from local forked state) are
  fully deterministic in the local pass, so the `:1550` guard **always fires pre-broadcast**.

Corroborated by the project's **own `package.json:287`**, which states the mechanism verbatim.

The real outcome is an **atomic pre-broadcast abort**: zero transactions signed, zero mined, and
forge's non-zero exit halts the `&&` chain at `package.json:288` so the patch and verify legs
never run. The finding was **downgraded to `L-05`, fingerprint `f59e177a97c88429…` unchanged**
(severity is not a fingerprint input, so the ledger join holds); the retracted `justification` is
retained verbatim as `justificationRetracted`.

**This is the `ForgeLocalPassPrecedesBroadcast` family, already on this ledger from run-22 — and
the finding inverted the family's own semantics.** Standing lesson for this project: *before
grading any script finding on mid-sequence-failure grounds, first establish that a mid-sequence
state can exist at all.* On a `forge script` entry point whose `run()` is a single frame, it
cannot. Severity must then be graded on the **diagnostic cost of a late abort**, never on an
imagined partially-applied deployment.

Two corrections that further weaken the original record, recorded because they cut against it:

- **Causal inertness.** `_loadSnapshotUsers` (`:1599-1601`) reads only `.users` and never
  `.address`. A probe corrupting `.address` while leaving `users` intact reverted **nothing**. The
  PoC set the empty user list **by fixture construction**; the causal step *"mis-resolved address
  ⇒ empty user list"* was asserted, never demonstrated.
- **Factual correction.** The three stakers hold **1 / 2 / 3 users** (EYE / SCX / FLX). The
  figures **2 / 156 / 13** are **stake units** from the migrate log, not user counts.

The PoC — `workspace/phoenix-phase-2-staging/test/SnapshotAddressMismatchOrdering.t.sol` — is
**audit-authored and untracked**. It supports only the weaker claim (the `:1550` guard exists, is
fail-closed, and emits exactly `"snapshot user list is empty but V1 still holds stake"`; and that
`_loadSnapshotUsers` never reads `.address`). It must never be presented as proving impact, nor as
an upstream project test.

**What survives in `L-05`** is precondition hygiene: Phase 6 never asserts that the snapshot
targeted the same staker addresses Phase 0 checks (no `.address` / `.chainId` provenance probe,
and `resolveAddress()` in `scripts/snapshot-depletion-stakers.js:98-106` accepts `0x0` as a valid
40-hex match). A mis-resolved snapshot is therefore caught **late and only incidentally**, by the
empty-list guard at `:1550`, with the post-migrate guards at `:1553-1554` and the Phase 7 backstop
at `:1697-1699` behind it.

---

## 3. Does the suite do what it intends?

**Yes — and this run is the first time anyone has been able to say so empirically.**

The suite is a one-shot, irreversible, `--ledger`-signed mainnet cutover carrying five coupled
changes (story-072):

1. Deploy `NudgeStreamer`; convert every donor from *push USDC at the batch minter* to
   *`approve` + `collectNudge` through the streamer*.
2. Redeploy all four donor dispatchers — BalancerPoolerV2 (idx 4), Uniboost ×3 (idx 1/2/3),
   NudgeRatchet (idx 7) — plus a new `StableYieldAccumulator`.
3. Replace the shared `BatchNFTMinter` with `BatchNFTMinterMultiToken`; whitelist USDC / phUSD /
   Kendu; `registerStream` at **10 / 30 / 30 days**.
4. Silently migrate the three `NFTStakerDepletion` instances to `NFTStakerDepletionV2` via
   `NFTStakerMigrator` — **zero user action**.
5. Retire the old batch minter (`setPauser(OWNER)` + `pause()`).

The headline invariant — hooks **repointed, not redeployed**, hence **zero `phUSD.setMinter`
calls** — holds: no `setMinter` on PHUSD anywhere in the closure, mask `270080` / `mintVersion 0`
unchanged.

### Empirical result

| Command | Exit | Result |
|---|---|---|
| `forge build` | 0 | Compiler run successful (solc **0.8.30**) |
| `forge test --match-path test/BptBaselinePersistence.t.sol` | 0 | **11 passed** / 0 failed |
| `forge test --match-path test/VerifyPromotionReadyGuards.t.sol` | 0 | **8 passed** / 0 failed |
| `npm run promotion-ready:snapshot` | 0 | snapshot written at block **25671016** |
| **`npm run promotion-ready:dry`** | **0** | **all 8 phases green** (0, 1, 2, 3, 4a, 4b, 4c, 5, 4d, 6, 7, 8) |
| `npm run promotion-ready:verify` (standalone) | **1** | *"No progress file … Nothing to verify"* — **correct** |

**The `:dry` run discharges story-075 checklist line 396** — the suite's *self-declared primary
regression gate*, unticked because the story's headless environment had no `RPC_MAINNET`
(Autonomous Decision 2), and **never executed until this audit**. Result: **green**.

Green under `:dry` covers: all Phase 0 preconditions (chainid, duration/split/window config, all
**17** mutation targets `.owner() == OWNER`, dispatcher lineup at 1/2/3/4/7, prime tokens, all six
donors on the shared old batch minter, `nudgeStreamer()` reverting on every live donor, and
`bptAtPhase0 > 0`); the per-index fail-closed ordering `pull()` → `hook.setDispatcher(new)` →
`new.setHook(hook)` → `replaceDispatcher(idx)` on all five indices; price/growth preserved across
every `replaceDispatcher`; all twelve Phase 7 post-conditions; and the Phase 8 preview probes —
including the **blocking Kendu fee-on-transfer gate** (`sent == received == credited == 1e24`),
`MintPageView.getData()` (39 rows), a **positive** `BatchDonatedViaPSM = true` /
`DonationSkipped = false` on the pooler, a 40-mint qualifying batch after `vm.warp(+1 day)`, the
`ArrayLengthMismatch` negative test, and the BPT recovery path.

`:verify` failing standalone at exit 1 is intended and correct — it requires the progress file the
broadcast has not yet written.

### One caveat on the test harness

19/19 pass and the properties are genuinely falsifiable (this is **not** the vacuous-mock pattern).
But `BptBaselinePersistence.t.sol` tests a **hand-transcribed** `BptBaselineModel`, not
`script/DeployMainnetPromotionReady.s.sol` — the file admits this. The transcription was verified
faithful against the real source at `:549`, `:564-572`, `:1725`, `:1729` **today**; nothing
enforces that it stays so. The only structural link to the real file is
`VerifyPromotionReadyGuards.t.sol`'s substring scan, whose evadability is `Q-01`.

---

## 4. Does it introduce unintended side effects?

**No unintended on-chain effect was observed.** Every state write in the `:dry` run maps to a
`mutated` entry in `closure-manifest.json` and to a stated story-072 purpose: 14 new deployments
(NudgeStreamer, BatchNFTMinterMultiToken, four dispatchers, SYA, 3× V2 staker, 3× transient
migrator), five `replaceDispatcher` calls with price/growth preserved, five hook repoints, the
Pauser registry swap (5 in, 4 out, retired minter deliberately absent), the three
`setWithdrawer`/`setAuthorizedBurner` swaps, the old SYA rendered inert, and the drains of the old
batch minter, old pooler and old DelayRelease.

Three effects are **intended but worth an operator's attention**:

- **Transient OWNER custody.** OWNER holds rescued USDC between `rescueERC20` and `collectNudge`
  (99.224124 from the old batch minter, 380.000000 from DelayRelease). The funds land in the
  streamer buffer within the same run — final buffer **530.761796 USDC**. Not a leak.
- **~1% phUSD residual left on each V1 staker** by `SWEEP_HEADROOM_BPS`
  (`46571004566227843` / `7643177516472334009` / `522780043796433596`), logged by the script as
  *"recoverable later via `rescueERC20`"*. Intended headroom — but **nothing in the suite or the
  story checklist schedules the recovery**. Recorded as an operational loose end, not filed.
- **BPT conservation.** The full `16867526417628291567945` position moved old → new pooler;
  `balanceOf(OLD_POOLER) == 0`.

The audit's own `:snapshot` created `scripts/snapshots/` in the **workspace** (gitignored at
`.gitignore:15`). `lib/` was untouched; nothing was broadcast.

**Off-chain, one asymmetry is worth naming and is already covered by ledger entries L-02 / L-03 /
L-07 and the `:resume` doc key:** `vm.writeFile` is a filesystem cheatcode and is **not** subject
to EVM rollback, so a failed local pass still leaves `server/deployments/progress.promotion-ready.1.json`
claiming steps that were never broadcast. Recorded as an evidence note on `L-03`
(`ea648ec5eab0c926…`), flagged unverified. **No new finding was minted for it.**

---

## 5. Have other problems surfaced because of it?

The closure resolved **91 files, 0 unresolved imports**, across two script files, 42
nested-submodule files and 47 external-lib files — **zero files under `src/`**, consistent with
this repo carrying no production contract code. Twelve sibling scripts rank as cluster members,
headed by:

| Sibling | Story | Prior run | Why it matters here |
|---|---|---|---|
| `DeployMainnetUniboostCutover.s.sol` (`uniboost-cutover`) | 071 | run-20 | Created **every live artifact this cutover replaces** — the three Uniboosts, the DelayRelease stopgap at idx 7, the three depletion stakers, MultiPooler. Also the source of the `--legacy` / `--with-gas-price` and progress-file-poisoning lessons now encoded in these npm keys. |
| `DeployMainnetNudgeRatchet.s.sol` (`deploy:ratchet-mainnet`) | 069 | run-19 | Built the index-7 ratchet infrastructure; its progress file is the closest analogue of this suite's. |
| `FixRatchetBatchMinterSink.s.sol` | 069 follow-up | — | `Fix`-class evidence that index-7 donor-sink wiring **has been mis-set before** — the exact wiring this cutover re-does. |
| `DeployMainnetMintPageView.s.sol` | 071 follow-up | — | Precedent for the exact breakage Phase 8's `_probeMintPageView` guards — and that probe is preview-only. |
| the index-4 `Fix`/`Restore`/`SetBatchDonationSize` cluster | — | — | Explains why Phase 4a **mirrors** `psm`/`maxTout`/`batchDonationSize` off the live pooler rather than hardcoding. |

Two entry points were namespaced this run (`decisions.md`, Decisions 2 and 3): root cause in the
deploy script / `package.json` / the JS chain → `promotion-ready:broadcast` (matching run-22 so its
12 open findings reconcile rather than minting fresh fingerprints); root cause **solely** in
`script/VerifyPromotionReady.s.sol` → `promotion-ready:verify`. On-disk directories use the hyphen
form; the `entryPoint` field keeps the colon form because it is a fingerprint input. **Do not
"fix" either to match the other.**

Structural limits worth carrying forward, none of them filed as findings on their own:

- `BALANCER_ROUTER` and `SUSDS_IS_FIRST` are `private immutable` with **no getter** on
  `BalancerPoolerV2` (`:82-83`). Phase 0 and `:verify` are **definitionally unable** to assert
  them; the only thing that exercises them is the preview-only Phase 8 pooler probe — which
  returned `BatchDonatedViaPSM = true` at this block. That makes `:dry` **load-bearing, not
  optional**, and it is folded into `L-01`'s rationale.
- Five contracts the suite mutates or reads are **not in the import closure** and are reached only
  through inline interfaces: phUSD, the live `NudgeRatchetDelayRelease`, the legacy shared
  `BatchNFTMinter` build, `NFTStaker`/`RatchetNFTStaker`/`MultiPooler`, and the three
  YieldStrategies. `codeMatchesSource` is `unverified` throughout — liveness and codelen were
  confirmed by `eth_call`/`eth_getCode`, but no bytecode comparison was performed.
- `StableYieldAccumulator.claim()` was **not simulated**; the donation path was verified
  structurally via Phase 7 only. Logged as a gap, not a failure.

---

## 6. Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-01** | Low | Phase 8's `_probePoolerDonation` — the mechanised form of story-072 checklist **line 1197** — is reachable only under `if (isPreview)`, so the broadcast path never runs it. `_psmDonate` failures are swallowed by `try/catch`, so a green mint is not evidence and a fully green `:verify` coexists with a silently non-donating pooler. | Add a `promotion-ready:verify-mint` npm key running the **existing** Phase 8 pooler probe in `PREVIEW_MODE` against live **post**-cutover state and `require` `BatchDonatedViaPSM` fired / `DonationSkipped` did not; chain it after `:verify` with the same `&&` discipline. Until it ships, tick line 1197 explicitly before disconnecting the Ledger. Secondary: expose `BALANCER_ROUTER` and `SUSDS_IS_FIRST` via public getters. | `script/DeployMainnetPromotionReady.s.sol:439` · `_phase8_previewSmokeTests` · `promotion-ready:broadcast` · `2212c1c4e8c8cd22…` |
| **L-02** | Low | Story-072 checklist **line 1195** — one of the two unticked rows and the whole compensating human control — hardcodes expected values that are both **stale** (16,338.8190 BPT vs live 16,867.5264) and **structurally incomplete** (`~349 USDC` vs measured 530.76, decomposing into three components where the checklist names two). Law-3 footgun: an operator trained that "the numbers are always a bit off" waves through a genuine shortfall. | Stop hardcoding balances in a human checklist: rewrite line 1195 to reference the `BPT cutover baseline` and final `collectNudge -> stream buffer now` figures the script already prints under `--- stranded value (live) ---`, and have `_printSummary()` emit a copy-paste **POST-BROADCAST HUMAN CHECKLIST** with live-derived values filled in. Enumerate **all three** buffer components, or quote only the printed total. | `script/DeployMainnetPromotionReady.s.sol:544-558` · `_phase0_preconditions` · `promotion-ready:broadcast` · `d99738d3a05c44aa…` |
| **L-03** | Low | `VerifyPromotionReady._loadAndValidateProgressFile` guards against *"the cutover did not complete"* using record **presence** — but `_trackDeployment`/`_trackConfig` stamp every record during forge's **local pass** (`:2161`, `:2169`) and `run()` flips the status to `completed` at `:435`, all before transaction #1 is signed. The gate can only detect a *pre*-broadcast condition, and the verifier never reads `deploymentStatus` at all. `ForgeLocalPassPrecedesBroadcast` family. | Make the gate read something only **dispatch** can produce: require `deploymentStatus == "completed"` **and** independently confirm `addr.code.length > 0` at the recorded NudgeStreamer and BatchNFTMinter addresses (two staticcalls). Alternative: drop the misleading `require` and let Phase 7 be the sole authority, with a comment. Do **not** leave the wording in place with only a comment — the message is what misleads. | `script/VerifyPromotionReady.s.sol:126-131` · `_loadAndValidateProgressFile` · **`promotion-ready:verify`** · `5c6d2c9e3b9806b8…` |
| **L-04** | Low | The persisted `baselines.bptAtCutover` carries **no provenance binding** — presence (`:564`) and non-zero (`:571`, verifier `:151`) are checked, magnitude and origin are not. On a resume leg the live read is 0, so `max(persisted, 0) = persisted`: a digit hand-edited downward becomes the floor and the Phase 7 conservation assertion under-detects a shortfall by exactly the delta. The runbook's "never touch `baselines`" rule is enforced for **deletion** only. | Emit a sibling `baselines.bptAtCutoverBlock` (decimal string, written atomically with the value) and have **both** Phase 0 and the verifier require it non-zero and `<= block.number` — one key plus two requires binds the value to a block. Cheaper fallback (log the baseline in human units each leg and have the operator confirm it) is **not** preferred: it re-introduces the human-comparison weakness `L-02` documents. | `script/DeployMainnetPromotionReady.s.sol:2013-2020` · `_parseBaselines` · `promotion-ready:broadcast` · `80a741a27fe0fded…` |
| **L-05** | Low *(walked back from Medium — §2)* | Phase 6 never asserts the snapshot describes the **same staker addresses** Phase 0 checks: no `.address` / `.chainId` provenance probe, and `resolveAddress()` accepts `0x0` as a valid 40-hex match. A mis-resolved snapshot is caught **late and incidentally** by the empty-list guard at `:1550`. **Atomic pre-broadcast abort** — never a partially-applied cutover. | Add a Phase 0 snapshot-provenance probe, before any mutation, requiring `.stakers.<key>.address == V1_STAKER_<X>` for all three and `.chainId == 1`, rejecting the zero address (three string comparisons on a file Phase 0 must open anyway); and harden `resolveAddress()` at `scripts/snapshot-depletion-stakers.js:98-106` to reject `0x000…0` explicitly. File-**existence** probing and `.blockNumber` freshness belong to open ledger entry **L-07** (`b28492ce…`) per **SN-23-01** and should land in the same Phase 0 block. | `script/DeployMainnetPromotionReady.s.sol:1599-1601` · `_loadSnapshotUsers` · `promotion-ready:broadcast` · `f59e177a97c88429…` |
| **Q-01** | QA | `_requireNoBroadcastFlag` asserts an invariant it structurally **cannot** check (it only rejects `PREVIEW_MODE`; no cheatcode reports `--broadcast`), and `VerifyPromotionReadyGuards.t.sol` pins read-only-ness with **substring scans for cheatcode literals only** — a call to an inherited mutating helper such as `_writeProgressFileWithStatus(...)`, or a live-read fallback routed through a local variable, would pass every current assertion. Latent only: the verifier's current call graph is verified clean. | (1) Rename to `_requireNoPreviewMode` so the name matches the check, keeping the NatSpec that explains why the flag is unobservable. (2) Upgrade the guard test from substring scanning to a call-graph assertion — no call by name to any inherited mutating helper (`_writeProgressFileWithStatus`, `_trackDeployment`, `_trackConfig`, `_phase1_`…`_phase6_`, `_phase4d_`, `_phase8_`, `_moveBPT`, `_rescueTo`, `_migrateStaker`, `_collectNudgeFromOwner`, `_swapUniboost`) — and assert the **presence** of `bptAtCutoverPersisted`. (3) Best: split shared constants and read-only helpers into a base contract so the verifier never inherits a broadcast surface. | `script/VerifyPromotionReady.s.sol:96-98` · `_requireNoBroadcastFlag` · **`promotion-ready:verify`** · `5e2e125056eb91ae…` |

`L-01` and `L-02` are the two `faithfulness: true` findings; their Law-2 write-ups are
`F-01-072` and `F-02-072` in `submissions/spec-conformance.md`. They are cross-referenced here,
not duplicated.

---

## 7. Open operator items and run-level notes

### Story-072 checklist — two rows still unticked

- **Line 1195** (post-broadcast human confirmation sweep). `:verify` discharges **most** of it
  mechanically — Phase 7 re-run plus the mint-authority invariance check — but its quoted figures
  are stale and structurally incomplete (`L-02` / `F-02-072`).
- **Line 1197** (trigger one index-4 mint, assert `BatchDonatedViaPSM` fired). **Explicitly NOT
  discharged by `:verify`**, per the verifier's own `run()` epilogue and the
  `//promotion-ready:verify` doc key. Genuinely open (`L-01` / `F-01-072`).

### Stale operator reference figures (the evidence behind `L-02` / `F-02-072`)

| Line 1195 asserts | Measured live | Nature |
|---|---|---|
| **16,338.8190 BPT** | **16,867.5264 BPT** | stale — arithmetic drift |
| **~349 USDC** in the streamer buffer | **530.76 USDC** = 99.22 (old batch minter) + 380.00 (DelayRelease) + **51.54 (UniboostSCX residual prime)** | **structural** — a third component the checklist never names |

### Run-22 `L-04` (Kendu FoT probe, preview-only) — `e6f32c47…`

Stays **open** as a structural finding, but is **materially de-risked**: the blocking probe
executed **green** in this session's `:dry` run (`sent == received == credited == 1e24`), so the
procedural tax gate has now actually been discharged against live Kendu state at this block. The
root cause — the probe is reachable only under `if (isPreview)` — is unchanged, and no new
fingerprint was minted.

### `KI-23-01` — known-issues suppression BLOCKED (human decision required)

`lib/phoenix-phase-2-staging/known-issues.md` is **absent at `c4396b1`**, although the registry
claims **11 entries extracted 2026-01-09**. The sanitizer could not evaluate suppression, and
**nothing in this run was dropped on known-issue grounds** — correct under Law 1, but it means
triage carries the load, and a finding here may duplicate a documented known issue. **Action:**
restore or re-extract `known-issues.md`, then re-run sanitization against this bundle.

### 4naly3er integration gap

4naly3er produced **no report** for this slice. The project declares its remappings inline in
`foundry.toml` and ships no `remappings.txt`; both attempts hit the diamond-dependency
duplicate-interface condition that `foundry.toml`'s own canonicalization block exists to solve.
`forge build` compiles the same files without complaint. This is a **tool-integration failure, not
a code defect** — recorded rather than silently dropped. Net effect: no automated bot-report
baseline backs this run; every finding is manual and fork-verified. The temporary `remappings.txt`
was removed from the workspace afterwards; no file in `lib/` was touched.

### Carryover — 12 run-22 findings remain open

`submissions/M-01-C1.md` (run-22's Medium, `2c53e944…`) and `submissions/carryover/qa-report-22.md`
(11 open QA/Low entries). Numbering was deliberately **not** adjusted around them — a run-22
`L-04` and this run's `L-04` are different findings, and each section carries the fingerprint that
disambiguates them.

### Story state-folder anomaly

Stories **074** and **075** sit in a state folder named **`auto-complete`**, which is **not one of
the four states CLAUDE.md enumerates** (`complete` / `incomplete` / `review` / `archive`).
Recorded verbatim, not normalised; flagged for a human to reconcile the stories tree's taxonomy.

---

## 8. Accuracy guards for downstream readers

- **`L-05` is an atomic pre-broadcast abort.** Never describe it as a partially-applied or
  irreversible cutover. Its PoC is audit-authored and untracked and supports only the weaker claim.
- User counts are **1 / 2 / 3**. "2 / 156 / 13" are **stake units**.
- Correct line references for `L-05`: `:1550`, `:1553-1554`, backstop `:1697-1699`. The citations
  `:1681-1682` and `:1549` / `:1552-1553` that appear in earlier stage artifacts are **wrong** —
  use neither.
- **Do not quote the superseded stage artifacts** — `script-audits/promotion-ready-broadcast/{candidate,sanitized,classified}-findings.json`
  are retained as a historical record only; they still carry the Medium framing and the
  "2 / 156 / 13 users" phrasing.
- `submissions/M-01-C1.md` is run-22's carried-over Medium, **not** this run's walked-back finding.
