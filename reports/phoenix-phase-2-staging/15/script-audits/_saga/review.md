# Script-Audit Review — Story 060+065 "YS-swap" migration saga

**Project:** phoenix-phase-2-staging
**Scope mode:** whole-saga script-audit (12 ordered steps + 1 out-of-band break-glass)
**HEAD commit:** `0e190e8`
**Fork:** mainnet (chainId 1), block range `25313222`–`25313321`, RPC live
**Owner / deployer:** `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (Ledger, hd index 46)
**Run:** phoenix-phase-2-staging-15 · 2026-06-14

This is not a single-entry-point audit. The `//migration-saga` block in `package.json` stages an
ordered sequence of one-shot operational scripts, threaded together by an off-chain JSON bus and a
strict on-chain ordering, plus an off-band break-glass. The review is structured around the three
script-audit questions at *saga* scope: (1) context & scope, (2) did the previously-reported fixes
land, (3) does the saga do what it intends / introduce unintended side effects / knock-on problems,
and closes with a safe-broadcast checklist.

All findings are framed under the project's three-law hierarchy: security (Law 1) over
story-faithfulness (Law 2) over owner-trust (Law 3). The owner is assumed non-malicious; we do not
report "a malicious owner could…" vectors. We *do* report **non-obvious owner footguns** — places
where a competent, non-malicious operator running the documented runbook would be surprised by a
consequence that unknowingly bricks a function or shorts a user.

---

## 1. Context & scope — what the saga does

The saga swaps the live StableStaker's DOLA and USDC yield strategies from the old
`ERC4626YieldStrategy` instances to freshly-deployed V2 instances (wrapping autoDOLA `0x79eB…AA54d`
and autoUSDC `0xa756…0D35`), and deploys a fresh phUSD collateral minter on the V2 strategies. The
strategy swap is performed without disturbing user principal by a **two-leg "temp-staker bounce"**:
leg-1 migrates every staker out of the live staker into a throwaway temp staker, the live staker is
reset and rewired to V2, then leg-2 migrates everyone back onto the live staker now sitting on V2.

The USDe strategy is intentionally left live (skimmed only, never swapped). The same live staker
address `0xbce8…079A` is retained throughout — it is rewired in place, not redeployed.

### The 12 ordered steps + break-glass

| # | npm key | Script | Intent (one line) |
|---|---------|--------|-------------------|
| 1 | `migrate:ys-swap-deploy` | `DeployTempStableStakerAndMigrators` | Deploy V2 strategies + temp staker + 2 migrators; pause live staker; set tempStaker as phUSD minter; register V2 on SYA `0x3C69`; write `ys-swap-deployments.json` |
| 2 | `migrate:phusd-minter-deploy` | `DeployNewPhusdMinter` | Deploy fresh phUSD minter (4000/token/day cap) on V2; set as phUSD minter + V2 client |
| 3 | `migrate:phusd-minter-cutover` | `CutoverAndRevokeOldMinter` | Revoke OLD_MINTER (mint authority + V2-client) after preflight asserts new minter `canMint`; repoint `mainnet-addresses.ts` |
| 4 | `migrate:ys-swap-gather-leg1` | `gather-migration-inputs.js --leg 1` | Read-only snapshot of live-staker stakers → `leg1-stakers.json` |
| 5 | `migrate:ys-swap-leg1` | `SkimAndLeg1Migration` | Skim surplus to staker; leg-1 migrate to temp; Phase-4 minter shortfall pre-fund; persist `preMigBooked` anchor |
| 6 | `migrate:ys-swap-reset` | `ResetAndRewire` | `finalizeAndReset` + `setYieldStrategy(V2)` (sweeps prefunded idle into V2 as principal); repoint `mainnet-addresses.ts` strategy keys |
| 7 | `migrate:ys-swap-gather-leg2` | `gather-migration-inputs.js --leg 2` | Read-only snapshot of temp-staker stakers → `leg2-stakers.json` |
| 8 | `migrate:ys-swap-leg2` | `Leg2Migration` | Leg-2 migrate temp → live staker now on V2 |
| 9 | `migrate:ys-swap-cleanup` | `PostMigrationCleanup` | Verify (incl. zero-haircut floor); unpause both stakers; restore pausers; revoke tempStaker phUSD minter |
| 10 | `migrate:phusd-minter-evacuate` | `EvacuateAndReseedMinter` | Evacuate OLD_MINTER residual old-strategy position → reseed new minter on V2 |
| 11 | `migrate:ys-sya-deregister` | `DeregisterOldStrategiesFromSYA` | Remove old DOLA/USDC strategies from the live SYA |
| 12 | `migrate:ys-old-strategy-decommission` | `DecommissionOldStrategies` | Emergency-sweep residual to owner-treasury; deregister clients; revoke withdrawers; `setPauser(owner)` + `pause()`; retain ownership |
| OOB | `migrate:ys-swap-breakglass` | `UnpauseStakerBreakGlass` | Contingency: owner unpause of the live staker if a mid-suite halt strands the live USDe pool (YS-21) |

### Off-chain JSON bus + inter-step dependency graph

The steps communicate primarily through `script/migration-inputs/ys-swap-deployments.json`
(written by steps 1/2/5; read by steps 2/3/5/6/8/9/10/11), plus the two gather snapshots
(`leg1-stakers.json` from step 4, `leg2-stakers.json` from step 7) and the off-worktree
`server/deployments/mainnet-addresses.ts` (patched by steps 3 and 6). Several **critical** edges
constrain ordering and are load-bearing for user safety:

- **step5 → step6 (on-chain, critical):** Phase-4 prefund + skim deposit *idle* into the live
  staker; `setYieldStrategy` in step 6 is what sweeps that idle into V2 as principal. The prefund
  MUST precede the reset.
- **step5 → step9 (off-chain, critical):** step 5 persists `dolaPreMigBooked` / `usdcPreMigBooked`
  — the anchor for the step-9 zero-haircut floor.
- **step8 → step9 (on-chain, critical):** the step-9 floor only becomes satisfiable after leg-2
  re-books full principal onto the live staker on V2.
- **step11 → step12 (on-chain ordering):** old strategies must be deregistered from the SYA before
  step 12 pauses them — otherwise a paused-but-registered strategy poisons `SYA.claim()` (this
  ordering edge is exactly where the saga breaks; see §3, YS-31).

Note two expected runtime gaps, not defects: `ys-swap-deployments.json` (non-preview) and the
two gather snapshots are absent on disk and produced at broadcast time; a pure-preview chain reads
the live/stale (or `-preview`) file rather than previewed addresses. `.newMinter` is written
broadcast-only, so a full preview chain cannot resolve it downstream.

### The user's framing

Two run-14 Mediums were "attended to" upstream and the user's #1 question is whether the fixes
landed: **YS-24** (`ba886105`, tempPauser zero-gate, story-066) and **YS-25** (`75e4305a`,
zero-haircut floor, story-067). The break-glass itself was the run-13 **YS-21** fix (story-065).
§2 answers each precisely.

---

## 2. Did the fixes land? (the user's #1 question)

| Finding | Fix | Verdict |
|---|---|---|
| YS-24 (`ba886105`) tempPauser zero-gate | story-066 / `e5f79ce` | **FIXED** |
| YS-21 (`be9a5a92`) live-staker pause, no break-glass | story-065 | **FIXED** |
| YS-25 (`75e4305a`) zero-haircut floor | story-067 / `17dcfdf` | **INCOMPLETE — spawns new Medium YS-26 (+ Low YS-32)** |

### YS-24 — FIXED

`PostMigrationCleanup.s.sol:382-385` drops the `&& recordedTempPauser != address(0)` clause from
the tempPauser require: a *recorded* zero now passes, while a *missing* JSON key still fails loud
via the `try/catch → tempPauserRecorded=false` path. We traced the recorded value to confirm the
zero is legitimate, not a masked misconfiguration: `DeployTempStableStakerAndMigrators.s.sol:256`
reads `tempStaker.pauser()` *before* line 270-271 sets it to OWNER; a freshly-deployed
`StableStaker` leaves `pauser` uninitialised (`StableStaker.sol:55`, no constructor assignment),
so the recorded value is a legitimate `address(0)`, persisted at `:303`. Restore-to-zero on the
decommissioned temp staker is a harmless no-op. Critically, the **origPauser** gate
(`:371-374`, recorded **and** non-zero) is untouched — the live staker can never be left with the
deployer EOA as pauser. The live staker's current pauser is a real non-zero `Pauser` contract
(`0x7c5A…85a3`), so a production run passes. No new hole.

### YS-21 — FIXED

`UnpauseStakerBreakGlass.s.sol` is fully standalone: it reads no migration-inputs, only constants
and live staker reads. `StableStaker.unpause()` is gated `owner() || pauser` (`StableStaker.sol:282`);
the script signs as owner and preflights `require(staker.owner() == OWNER)`. Fork-confirmed owner
== `0xCad1…D0B6`. Idempotent early-return if `!paused()`. Fork preview ran clean (staker currently
unpaused → "nothing to do"); a transient fork test forced the live staker into the deploy-step
paused state, then owner `unpause()` succeeded and `paused()==false`. A mid-suite halt leaves
exactly the state break-glass needs and requires no downstream artifact. It unsticks a stranded
live USDe pool.

### YS-25 — INCOMPLETE-FIX (spawns Medium YS-26 + Low YS-32)

The floor itself is sound and well-placed: `PostMigrationCleanup.s.sol:247-256`,
`require(principalOf(token, original) >= preMigBooked)` per token, using `>=` (not `==`, which
would falsely revert on legitimate surplus). On a **clean first run** the `preMigBooked` anchor is
pinned by the `SkimAndLeg1` preflight at `:204-218` (snapshot `totalStaked` == on-chain
`poolInfo[3]`), and the downstream-only placement is correct given the step8→step9 ordering. While
`leg1-stakers.json` is not re-gathered, the JSON-bus threading is tamper-free.

Two gaps remain, both confirmed:

1. **Self-defeating on the supported leg-1 RESUME path (→ Medium YS-26).** When leg-1 drains the
   pool (`stakerCount→0`, `totalStaked→0`) and the broadcast halts *before* the `preMigBooked`
   persistence block (`SkimAndLeg1:393-402`, the last writes in `run()`), the count-staleness
   preflight (`:187-194`) forces the operator to re-gather. `gather-migration-inputs.js:257-263`
   reads `totalStaked` live from `poolInfo[3]` and overwrites the snapshot with the post-drain `0`.
   On the re-run the `totalStaked==chain` preflight is *skipped* (the `stakerCount==0` gate at
   `:204`), so the script persists `preMigBooked = 0`, and the step-9 floor degrades to
   `require(principalOf >= 0)` — vacuous. The story-067 author's own comment
   (`SkimAndLeg1:388-392`) asserts a resume "re-persists the IDENTICAL value instead of the
   post-drain 0" — false once the forced re-gather rewrites the snapshot.

2. **Buffer-blind even on a clean run (→ Low YS-32).** The floor measures the buffer-inflated
   `principalOf` rather than user-withdrawable `poolInfo.totalStaked`. The protocol-owned skim+idle
   buffer (folded into V2 principal by `setYieldStrategy`) masks a genuine per-user haircut, so the
   gate passes even when stakers were collectively shorted. Bounded to redeem-rounding dust on the
   current ERC4626 strategies.

Both are detailed in §3. The existing unit tests
(`YsSwapMigrationHardening.t.sol::test_zeroHaircutGate_*`) only re-test a copy of the require
expression (message + `>=` direction); they never exercise the JSON-bus threading or the resume
re-gather, so they pass while the gap is live.

---

## 3. Does it do what it intends? Side effects and knock-on problems

### Per-step intent vs implementation

| # | Intends to | Implementation verdict |
|---|------------|------------------------|
| 1 | Deploy V2/temp/migrators; pause live; register V2 on SYA `0x3C69` | Correct on a single run. SYA target `0x3C69` is the right production accumulator (verified). Five `new` deployments are **unconditional** → non-idempotent on re-run (Low **YS-35**) |
| 2 | Deploy fresh minter (4000/day cap) on V2 | Correct. Old+new minter coexist (per-address authorization map). 4000/day cap cannot brick (cleared below) |
| 3 | Revoke OLD_MINTER, repoint UI | Correct. Cutover preflight asserts new minter `canMint` before revoking. `withdrawAsOwner` survives client revocation by design |
| 4 | Snapshot leg-1 stakers | Correct (read-only). Feeds both leg-1 input and the `preMigBooked` anchor |
| 5 | Skim + leg-1 migrate + Phase-4 prefund + persist anchor | Correct on clean run. Anchor persistence is **resume-fragile** (Medium **YS-26**). Phase-4 under-prefund only WARNs |
| 6 | Reset + rewire to V2 (sweep idle to principal) | Correct. Over-credit ceiling is one-sided `<=` (misses under-credit) — the floor in step 9 is the real user guard |
| 7 | Snapshot leg-2 stakers | Correct (read-only) |
| 8 | Leg-2 migrate temp → live on V2 | Correct. Re-books full principal onto live staker on V2 |
| 9 | Verify + unpause + restore pausers + revoke temp minter | Floor is **resume-fragile / buffer-blind** (YS-26 / YS-32). `unpause()` runs **before** the pauser-recorded require (Low **YS-34**) |
| 10 | Evacuate OLD_MINTER residual → reseed new minter on V2 | Correct. No double-count; reads residual fresh; intended minter shock-absorber haircut (~0.015%) |
| 11 | Deregister old strategies from the **live** SYA | **WRONG TARGET** — hardcodes the decommissioned, empty `0x3bBE` (Medium **YS-31**). Guards pass vacuously (Low **YS-33**) |
| 12 | Sweep residual; deregister/pause old strategies | Correct *in isolation*, but pausing strategies still registered on `0x3C69` (because step 11 no-op'd) is what triggers the **YS-31** brick |
| OOB | Owner unpause of stranded live staker | Correct (YS-21 fix) |

### On-chain side effects verified on the fork

The saga has **not** been broadcast yet: the live staker is unpaused, no migrator set, still on the
old strategies. Both old DOLA/USDC strategies are currently **above par**
(`totalBalanceOf > principalOf` for staker and minter), so `_prefundShortfall` is a no-op today
(fork: `dolaPrefunded == usdcPrefunded == 0`). User safety therefore rests today on the skim+idle
fold into V2 plus the step-9 floor. Fork-verified positive controls: Phase-4 drain recovers
13815.459 of 13816.564 booked DOLA *after* OLD_MINTER revocation; evacuate/reseed moves 13814.467
DOLA onto V2 under the new minter with old principal zeroed; the 4000/day cap reverts a >4000 user
mint while the staker reward path mints 100000 phUSD uncapped.

### New findings

#### Medium — YS-31: cleanup tail bricks `SYA.claim()` (SAGA-SYA-BRICK)

Step 11 (`DeregisterOldStrategiesFromSYA.s.sol`) hardcodes `LIVE_SYA = 0x3bBE…` — the
**superseded, now-empty** accumulator — instead of the live production accumulator `0x3C69…` that
step 1 registered V2 onto and step 9 asserts against (`mainnet-addresses.ts:34`;
`progress.replace-sya.1.json` records `{oldSYA: 0x3bBE, newSYA: 0x3C69}`). Because `0x3bBE`'s
registry is empty, `removeYieldStrategy` is a silent no-op; the owner-equality preflight passes
(both SYAs are owner-owned) and the post-asserts pass vacuously (the olds are "absent" from the
empty registry). The old DOLA/USDC strategies therefore **remain registered on the live `0x3C69`**.

Step 12 (`DecommissionOldStrategies.s.sol`) then pauses those strategies while they are still
registered. The default permissionless `StableYieldAccumulator.claim(i, m, [])` — the path the UI
and keepers call — iterates registered strategies and skips only on `tokenConfig.paused`; the old
DOLA/USDC *token* configs are NOT paused (only the strategy *contracts* are), so `claim()` calls
`skimSurplus()` on a paused strategy → `whenNotPaused` reverts `EnforcedPause` → the entire
`claim()` reverts for **every** caller.

The root footgun is the **internal repo ambiguity** itself: `mainnet-addresses.ts` says `0x3C69`,
`mainnet-addresses-post-phlimbo-upgrade.ts` says `0x3bBE`. **Q-SYA-SEL must be resolved before
broadcast.**

- *Severity:* Medium — no theft, no permanent loss; availability/protocol-function DoS on the
  canonical yield-claim path. Bounded below High by the `exemptStrategies` escape hatch (a caller
  passing the still-registered paused olds routes around the revert) and full owner remediability.
  Not Low because the *default* path all users hit is dead until owner action.
- *Three-law:* Law 1 governs; non-obvious owner footgun (Law 3, in scope) — a green run that
  silently bricks the canonical path. Not a Law-2 deviation (the intent is correct; the address is
  wrong).
- *Fork PoC:* `workspace/phoenix-phase-2-staging/test/SagaCleanupSYABrick.t.sol` — 4/4 PASS,
  `EnforcedPause` confirmed at block 25313321.
- *Record:* [`findings/medium/YS-31-saga-sya-brick.json`](../../findings/medium/YS-31-saga-sya-brick.json)
- *Root cause:* [`DeregisterOldStrategiesFromSYA.s.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/main/script/DeregisterOldStrategiesFromSYA.s.sol)

#### Medium — YS-26: zero-haircut floor silently disabled on a leg-1 resume (resume-zero-floor)

As laid out in §2: a leg-1 resume forces a re-gather that overwrites `leg1-stakers.json`
`totalStaked` with the post-drain `0`, `SkimAndLeg1` persists `preMigBooked = 0`, and the step-9
floor degrades to `require(principalOf >= 0)` — vacuous. The floor is the *sole* end-to-end
zero-haircut guarantee (the step-6 ceiling is one-sided `<=`; Phase-4 under-prefund only WARNs), so
a real haircut now reaches users uncaught on exactly the path most likely to produce one.

- *Severity:* Medium (capped) — value leak with stated assumptions and an external/sequence
  requirement (resume + re-gather). Not High: no theft/attacker, and the realized haircut on the
  current autoDOLA/autoUSD ERC4626 strategies is redeem-rounding dust (~0.024% round-trip). Not Low:
  the finding is the silent disablement of the protocol's sole user-protection invariant — recall
  over report-tidiness (Law 1).
- *Three-law:* Law 1 sets severity; Law 2 cross-refs spec-conformance (story-067's guaranteed
  zero-haircut behaviour is broken on resume); Law 3 confirms a non-obvious footgun — the operator
  follows the script's own re-gather instruction and the author's own comment claims the re-persist
  is identical.
- *Fork PoC:* `workspace/phoenix-phase-2-staging/test/PoC_YS26_ResumeZeroFloor.t.sol` — 3/3 PASS;
  mechanism corroborated by `PoC_YS25_PreMigBookedResumeZeroing.t.sol` (2/2 PASS: first run catches
  a 1% haircut, resume re-gather zeroes the anchor and the same haircut passes vacuously).
- *Record:* [`findings/medium/YS-26-resume-zero-floor.json`](../../findings/medium/YS-26-resume-zero-floor.json)
- *Root cause:* [`SkimAndLeg1Migration.s.sol#L187-L219`](https://github.com/Behodler/phoenix-phase-2-staging/blob/main/script/SkimAndLeg1Migration.s.sol#L187-L219)
  + floor at [`PostMigrationCleanup.s.sol#L247-L256`](https://github.com/Behodler/phoenix-phase-2-staging/blob/main/script/PostMigrationCleanup.s.sol#L247-L256)

#### Low findings (4)

- **YS-32 — floor measures the wrong comparand.** The story-067 floor compares buffer-inflated
  `principalOf` instead of user-withdrawable `poolInfo.totalStaked`, so the protocol-owned buffer
  masks a per-user haircut even on a clean run (fork: a single user −0.243 DOLA ≈ 0.024%; aggregate
  `totalStaked` ended 0.165 DOLA below `preMigBooked` while the gate passed at `principalOf=1061`).
  Dust on ERC4626 → Low; would amplify on a future high-slippage market strategy (speculative).
  Faithfulness-tagged. Fix: gate on `poolInfo.totalStaked`, keep `>=`.
  [`findings/low/YS-32-floor-wrong-comparand.json`](../../findings/low/YS-32-floor-wrong-comparand.json) ·
  [`PostMigrationCleanup.s.sol#L247-L256`](https://github.com/Behodler/phoenix-phase-2-staging/blob/main/script/PostMigrationCleanup.s.sol#L247-L256)
- **YS-33 — vacuous deregister guards.** Step 11's owner-equality preflight + post-asserts pass
  green on a wrong-but-owned empty SYA; they never assert the olds were *present before* removal.
  This is the guard-design weakness that lets YS-31 reach production; tracked separately so the
  assert-present-before-remove fix survives even if only the address constant is corrected.
  [`findings/low/YS-33-deregister-vacuous-guards.json`](../../findings/low/YS-33-deregister-vacuous-guards.json) ·
  [`DeregisterOldStrategiesFromSYA.s.sol#L69-L104`](https://github.com/Behodler/phoenix-phase-2-staging/blob/main/script/DeregisterOldStrategiesFromSYA.s.sol#L69-L104)
- **YS-34 — unpause before pauser-require (validate-after-mutate).** Step 9 `unpause()`s both
  stakers (`:357-368`) *before* the YS-22 pauser-recorded require (`:371-385`). Under the
  documented `--skip-simulation` flag, a missing/hand-edited pauser key leaves the live staker
  unpaused with its pauser un-restored until a corrective re-run. Fail-loud on re-run, no fund
  loss. Fix: move the require above `unpause()`, or drop `--skip-simulation`.
  [`findings/low/YS-34-unpause-before-pauser-require.json`](../../findings/low/YS-34-unpause-before-pauser-require.json) ·
  [`PostMigrationCleanup.s.sol#L357-L385`](https://github.com/Behodler/phoenix-phase-2-staging/blob/main/script/PostMigrationCleanup.s.sol#L357-L385)
- **YS-35 — non-idempotent step-1 deploy.** The five `new` deployments in step 1 are
  unconditional; a mid-saga re-run mints a fresh contract set and overwrites the deployments bus
  while live wiring still references the first set. Downstream preflights catch the mismatch and
  revert (fail-loud, no silent corruption); the stale bus must be restored manually. Cross-linked
  to fixed YS-13/`86a0f4fd` (which made *wiring* idempotent); this is the narrower never-closed
  residual, not a regression.
  [`findings/low/YS-35-step1-non-idempotent-deploy.json`](../../findings/low/YS-35-step1-non-idempotent-deploy.json) ·
  [`DeployTempStableStakerAndMigrators.s.sol#L178-L206`](https://github.com/Behodler/phoenix-phase-2-staging/blob/main/script/DeployTempStableStakerAndMigrators.s.sol#L178-L206)

### Cleared items (checked and refuted — so the reader knows what was examined)

- **Minter-authority window — no zero-minter gap.** The staker reward-mint path is a *separate,
  independent* phUSD minter (StableStaker `0xbce8` is itself authorized on phUSD and calls
  `phUSD.mint()` directly); none of the saga scripts touch it. Old+new collateral minters coexist
  through steps 1–2; OLD_MINTER is revoked in step 3 only *after* the preflight asserts the new
  minter is live with `canMint`. (VER-1)
- **Phase-4 prefund survives revocation.** `withdrawAsOwner` is `onlyOwner`-gated, so step 5's
  Phase-4 drain works after step 3 revokes OLD_MINTER as a *client* — intentional. (VER-2)
- **4000/token/day cap cannot brick.** Checked only inside `mint()` against the user-collateral
  path; Phase-4 prefund mints nothing (it is a `withdrawAsOwner`), staker rewards are uncapped.
  Deliberate story-065 circuit-breaker. (VER-3)
- **Evacuate/reseed — no double-count.** Step 10 reads `principalOf(OLD_MINTER)` fresh, moving only
  the residual; step 5 caps `principalToWithdraw` at `minterBooked`. phUSD has no redemption path,
  so minter backing is protocol-owned yield, not a user redemption reserve. (VER-4)
- **6fd3eddc PhusdMinterRepoint — superseded confirmed.** Fresh deploy is the same source with the
  7-field config; old live minter is the 4-field build; public ABI is a strict superset; no on-chain
  callers. No new ABI drift.
- **SYA choice in step 1 — correct.** Step 1's `SYA=0x3C69` is the right live accumulator (the
  inconsistency is isolated to step 11). (VER-5)
- **Idle-sweep attribution** — full balance swept to V2 principal, only ERC4626 rounding residual.
- **`setYieldStrategy` empty-pool precondition** — satisfied by `finalizeAndReset` + the contract's
  `totalStaked==0` require.
- **JSON-bus staleness guards** — preflight count/totalStaked checks + loud post-asserts; step 1
  writes all 7 fields, downstream uses the merge form preserving them.
- **Phase-4 over-delivery** — capped at `minterBooked`, hard-reverts on under-cover, no-op at the
  current above-par state.
- **YS-01 / YS-03 / YS-09 / YS-10 fixes** — present (YS-09 resume idempotency re-checked across
  steps 5/6/8, re-run-safe).

(Two ledger duplicates were excluded from classification: DEDUP-15-006 = open YS-28/`34335a28`
UI minter-repoint drift, and the orphaned-USDe-skim Low = open YS-07/`58911bd3`. The orphaned-USDe
idle remains a known protocol-owned, owner-rescuable Low.)

---

## 4. Recommendations / safe-broadcast checklist

All items are non-obvious owner footguns with safe-config guidance (three-law: owner is
non-malicious; these are surprises, not malice). **Do not broadcast the saga until the two Mediums
are resolved or manually compensated.**

1. **Resolve Q-SYA-SEL and fix step-11's `LIVE_SYA` (YS-31, blocking).** Pin step 11's SYA target
   to the production accumulator `0x3C69` (matching `mainnet-addresses.ts` / step 1 / step 9), and
   reconcile `mainnet-addresses-post-phlimbo-upgrade.ts` so the repo has one authoritative SYA
   address. Add a cross-script equality assertion that step 1 (register) and step 11 (deregister)
   target the **same** SYA constant.
2. **Add deregister-before-pause ordering assertions (YS-31 / YS-33).** Make step 11 assert the old
   strategies are **present** on the target SYA *before* `removeYieldStrategy` (so a wrong/empty
   target reverts instead of no-op'ing), and make step 12 assert they are **no longer registered**
   on `0x3C69` *before* it pauses them (so a pause can never land on a still-registered strategy).
3. **Do not rely on the resume path for the zero-haircut guarantee until YS-26 is fixed.** Until
   the anchor is made resume-safe, treat any leg-1 resume as *not* protected by the step-9 floor and
   **manually verify post-resume principal** (`ysV2.principalOf(token, original) >=` the *original*
   pre-drain `totalStaked`). Preferred fix: make `preMigBooked` write-once (refuse to overwrite a
   recorded non-zero with a smaller value), **or** `require(preMigBooked > 0)` in cleanup so a
   zeroed anchor fails loud (the YS-22 pattern), **or** source it from a first-run-only file never
   overwritten on resume; **and** make `_prefundShortfall` hard-revert on `injected < shortfall`
   instead of WARN.
4. **Gate the floor on `poolInfo.totalStaked`, not `principalOf` (YS-32).** Keep `>=` for
   legitimate surplus. This closes the buffer-blind spot and matters if the gate is ever reused on a
   higher-slippage market strategy.
5. **Move the YS-22 pauser-recorded require above `unpause()` (YS-34)**, or drop `--skip-simulation`
   for step 9 so a revert rolls back the whole run.
6. **Gate step-1 deployment on idempotency (YS-35)** — check for an existing deployments JSON with
   live-code addresses before the five `new`s, or document that step 1 is run exactly once and never
   re-run after step 2.
7. **Confirm the off-worktree UI repoint** of `mainnet-addresses.ts` after step 3 (Q-REFS) to avoid
   `phUSD.mint: not authorized` reverts for UI users.

---

### Severity summary

| Severity | Count | Findings |
|---|---|---|
| High | 0 | — |
| Medium | 2 | YS-31 (SYA-brick), YS-26 (resume-zero-floor) |
| Low | 4 | YS-32, YS-33, YS-34, YS-35 |

No High: no asset-theft or permanent-loss path. The SYA-brick is owner-remediable with an escape
hatch (availability Medium); the haircut leak is in-motion user value bounded to dust on the current
strategies (Medium-capped). Both Mediums are deterministic, non-malicious operator footguns reached
through the documented runbook, fork-PoC'd.
