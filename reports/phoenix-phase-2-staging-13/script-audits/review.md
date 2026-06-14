# Script-Audit Review — phoenix-phase-2-staging run-13

**Mode:** Fix-wave regression follow-up (script-review) to run-12 on the story-060 YS-swap migration suite
**Submodule HEAD:** `e935a05` (baseline `b27c6ac`, run-12)
**Submodule bumps:** vault `→ 0110ce4` (convertToAssets fix), stable-staker `→ 212a6d2`, phUSD-stable-minter `d6ed115` (newly pulled into scope by story-064)
**Fix-wave stories:** 061 (SYA repoint), 062 (mid-suite-halt hardening), 063 (drop cleanup buffer band), 064 (new minter-repoint script)
**Fork:** shared anvil mainnet fork, chainId 1, blocks 25305669–25305686
**Repo:** https://github.com/Behodler/phoenix-phase-2-staging (links pinned at `e935a05`)

---

## 1. Context and scope

This run is targeted follow-up work on "all the scripts for story 60." It is not a cold scan: it verifies whether the run-12 fix wave (stories 061–064) plus two submodule bumps actually remediated run-12's findings, and — the higher-value half — whether the fixes themselves introduced new bugs.

The audited closure is the same YS-swap migration suite reviewed in run-12, now comprising:

- **5 wired forge entry points** (each with a `-preview` variant and, after story-062, a hard preview-gate prepended to the broadcast key):
  - `migrate:ys-swap-deploy` — `script/DeployTempStableStakerAndMigrators.s.sol`
  - `migrate:ys-swap-leg1` — `script/SkimAndLeg1Migration.s.sol`
  - `migrate:ys-swap-reset` — `script/ResetAndRewire.s.sol`
  - `migrate:ys-swap-leg2` — `script/Leg2Migration.s.sol`
  - `migrate:ys-swap-cleanup` — `script/PostMigrationCleanup.s.sol`
- **2 gather legs** (node, non-broadcasting): `migrate:ys-swap-gather-leg1` / `-leg2` — `scripts/gather-migration-inputs.js`
- **1 new, UNWIRED script** added by story-064: `script/PhusdMinterRepoint.s.sol` (the YS-12 minter-repoint remediation). It has **no `package.json` key**, so it received neither the story-062 `--skip-simulation` drop nor the preview hard-gate; its NatSpec still prescribes a manual `--skip-simulation` hand-broadcast.

The fix-wave delta (`b27c6ac → e935a05`) is summarised per story in `delta-stories-061-064.json`. The largest behavioural change is story-062, which makes deploy pause both stakers and take their pauser role, makes cleanup the sole unpause/restore path, and makes every wiring step resume-idempotent. story-063 removes a false-reverting buffer sanity band. story-061 wires the live SYA to the new V2 strategies so the buffer has a consumer. story-064 is the new minter-repoint script.

This suite is the **prescribed full migration** for swapping the market yield strategy. It is the compliant path under the standing operational constraint (memory: *phStaging must never `setYieldStrategy` in place on a market yield strategy with staked users*) — the suite stands up a temp staker, migrates users in legs, and resets the original onto the V2 strategies rather than mutating a live strategy in place.

Scope authority and closure resolution: `closure-manifest.json`. Per-entry-point intent and observed side effects: `migrate:ys-swap-*/intent.md` + `side-effects.json` and `PhusdMinterRepoint-UNWIRED/`.

---

## 2. Did the fixes land? (the headline)

**Yes — the suite is no longer dead-on-arrival, and all four run-12 Mediums in this wave's remit are fork-verified FIXED.** These are **PROPOSED** `acknowledged → fixed` transitions only; the sanitizer fork-verified them at `e935a05`, but human triage is authoritative and is not auto-overwritten. Confirm via `/ledger phoenix-phase-2-staging`.

| Run-12 finding | fp | Story / bump | Verdict | Evidence |
|---|---|---|---|---|
| YS-01 previewRedeem vs convertToAssets | `28d5044e` | vault `0110ce4` | **FIXED** | proven 3 ways |
| YS-03 SYA dead-buffer / no consumer | `44dc0e3a` | story-061 (`333251f`) | **FIXED** | wiring + cleanup asserts pass |
| YS-09 mid-suite-halt non-resumable broadcast | `55ebe2c0` | story-062 (`38e7a20`) | **FIXED** (introduces YS-21) | preview-gate + resume guards |
| YS-10 cleanup buffer-band false revert | `e34ac20e` | story-063 (`4cbe524`) | **FIXED** | cleanup completes; minter-revoke still runs |

**YS-01 (`28d5044e`) — FIXED, proven three ways.** vault `ERC4626YieldStrategy.sol:115` now credits `convertToAssets(sharesReceived)` (was `previewRedeem` at the run-12 baseline `ad12cb1`). (1) `PoC_YS01` still confirms `previewRedeem` STATICCALL reverts with `StateChangeDuringStaticCall` on the real autoDOLA/autoUSDC Autopools — i.e. the old path was genuinely dead. (2) A full deposit/withdraw round-trip (`Run13_YS01_RealStrategyLive.t.sol`) **succeeds** against both real Tokemak Autopools (credited ~999.94 DOLA / ~999.86 USDC). (3) The exact run-12 brick point — `reset` `setYieldStrategy(token, V2)` idle-sweep deposit — completed on the shared fork, sweeping 26.785 DOLA / 28.54 USDC with no revert. This aligns the script with the intent doc that prescribed `convertToAssets`.

**YS-03 (`44dc0e3a`) — FIXED.** story-061 wires the live SYA (`0x3C69…8270`) to both V2 strategies. On the fork, `_verifySyaWiring()` passed: SYA is `authorizedWithdrawer` on both V2 strategies and both are present in `SYA.getYieldStrategies()`; cleanup verifications 11a–11d passed. The run-12 dead-buffer / silent value-leak gap (a buffer with no authorized consumer) is closed. The deliberately-deferred deregistration of the **old** SYA strategy entries is benign and unchecked here (see §3, YS-20, and the safe-config note).

**YS-09 (`55ebe2c0`) — FIXED.** `--skip-simulation` is dropped from all 5 broadcast keys and a `npm run <key>-preview &&` hard-gate is prepended, so a failing simulation under the PREVIEW_MODE owner-prank aborts before the ledger broadcast. Resume guards verified idempotent (poolState / yieldStrategy / migrator skip-guards). `leg1` `_globalPreflight` hard-asserts both stakers are paused (confirmed it reverts otherwise). **Note: this story-062 fix INTRODUCED a new pause-DoS surface (YS-21 below). The two MUST NOT be netted — YS-09 is fixed and YS-21 is a separate new finding.**

**YS-10 (`e34ac20e`) — FIXED.** story-063 removes the `[skim/2, skim*2]` band require that false-reverted valid migrated state in run-12 (buffer is dominated by realize-over-credit surplus, not skim). Cleanup completed against post-leg2 state: buffers logged DOLA 26.78 / USDC 28.54 (>> skim of 0 / 1.77 — the surplus-dominates state the band wrongly rejected); the retained HARD `require(principal >= totalStaked)` solvency invariant held; and critically the **tempStaker phUSD minter-revoke (`setMinter(tempStaker, false)`) still executes — it was NOT skipped by the band removal.**

**End-to-end (PASS).** The full suite now completes on a shared fork with no source patches. A migrated staker (`0x25AdA29…4eb1`) withdrew full DOLA principal post-migration: received 5.4990 DOLA vs 5.4994 principal (~0.006% protocol-favoring rounding), `user.amount → 0`. The original staker was unpaused, its pauser restored, and both pools point at V2. The only fixups required were operational, not code patches: the YS-04 gather JSON correction and the old-strategy withdrawer grant (both carryovers, §4). **No `convertToAssets` source patch and no `anvil_setCode` were needed — the YS-01 fix is real in the deployed build.**

---

## 3. What new problems did the fixes introduce? (the higher-value half)

The fix wave introduced **four new findings** — 2 Medium, 2 Low. Three of the four are direct side effects of the very stories that earned the FIXED verdicts above (story-062's pause coupling and catch-path; story-064's new script), which is exactly where a fix-wave regression earns its keep.

### YS-20 (Medium) — PhusdMinterRepoint incompatible with the live 4-field minter
- **fingerprint:** `6fd3eddc` · **entryPoint:** `PhusdMinterRepoint` (UNWIRED) · **footgun**
- **record:** `reports/phoenix-phase-2-staging-13/findings/medium/YS-20-phusdminterrepoint-abi-drift.json`
- **location:** [`script/PhusdMinterRepoint.s.sol#L174-L229`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e935a05/script/PhusdMinterRepoint.s.sol#L174-L229)
- **PoC:** `test/PoC_YS20_MinterRepointAbiDrift.t.sol` (generated in parallel)

story-064's minter-repoint script was authored against `PhusdStableMinter@d6ed115`, whose `StablecoinConfig` has 7 fields and which exposes `setMaxMintPerDay`. The phUSD minter **actually deployed** at `0x435B0A1884bd0fb5667677C9eb0e59425b1477E5` is an **earlier 4-field build** with no per-day-cap setter. Fork-confirmed: `stablecoinConfigs(DOLA)` and `(USDC)` each return 4 words; `setMaxMintPerDay(token, 0)` reverts with empty returndata (selector absent); the PREVIEW_MODE forge preview `[Revert]`s immediately after `stablecoinConfigs(DOLA)` in the 7-tuple decode.

Two outcomes:
- **Default (preview-gated):** the 7-tuple decode of a 4-word return reverts **before any mutation** → nothing changes → the minter stays pointed at the evacuated old strategies = **status quo**, which run-12 already classified Low (`633f3485`). The YS-12 remediation simply **cannot complete**.
- **Harmful (hand-broadcast):** because the script is **UNWIRED** it escaped the story-062 preview-gate hardening, and its NatSpec still prescribes `--skip-simulation`. An operator who hand-broadcasts tx-by-tx lands `setClient` + `registerStablecoin(token, V2, …)` (selectors present), then reverts on `setMaxMintPerDay` (absent) → the minter is **half-repointed** with the per-day cap potentially stuck at 0 = **mint DoS** for DOLA/USDC phUSD.

There is **no asset-theft/loss path**: the phUSD minter is architecturally immune to the story-060 over-credit bug (`mint()` never reads `principalOf`; no redemption/burn path — run-12 `633f3485` scoped analysis). That immunity is why the auditor's candidate **High** was rejected by the classifier and the severity-auditor **upheld Medium**: the genuinely-new harm is an availability/function impact (half-broadcast mint-DoS) gated behind a manual off-script hand-broadcast — the textbook Medium ceiling and a Law-3 non-obvious footgun.

### YS-21 (Medium) — story-062 live-staker pause has no break-glass
- **fingerprint:** `be9a5a92` · **entryPoint:** `migrate:ys-swap-deploy` / `migrate:ys-swap-cleanup` · **footgun**
- **record:** `reports/phoenix-phase-2-staging-13/findings/medium/YS-21-story062-livestaker-pause-no-breakglass.json`
- **location:** [`script/PostMigrationCleanup.s.sol#L174-L361`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e935a05/script/PostMigrationCleanup.s.sol#L174-L361) (unpause gated behind the verifications block)
- **PoC:** `test/PoC_YS21_LiveStakerPauseNoBreakglass.t.sol` (generated in parallel)

story-062 `deploy` now calls `setPauser(OWNER)` + `pause()` on **both** stakers, including the **LIVE original**. The pause is **contract-global**, so it also freezes the unrelated, un-migrated **USDe** pool for the entire migration window — and it is **always-on for the whole window, not just on a halt**. The only code that unpauses + restores the original staker's pauser is `PostMigrationCleanup` (unpause ~L329, setPauser-restore ~L342), and that path is gated behind ~12 verifications plus the solvency invariant. An incomplete or insolvent migration **cannot reach the unpause**, and there is **no standalone reopen script** in `script/`.

Fork-confirmed: after `deploy`, the original staker `0xbce8…079A` is `paused()==true` with `pauser==OWNER`; after a full cleanup it is `paused()==false` with pauser restored to `0x7c5A8EeF…85a3`; no other `script/*.s.sol` calls `unpause()`. Consequence: a mid-suite halt — e.g. the YS-02 leg1 withdrawer revert or the YS-04 gather preflight DoS, both of which currently halt this suite, *exactly the scenario story-062 was hardening for* — strands the live original staker **and** the unrelated USDe pool frozen with no scripted break-glass, until the operator either completes the entire migration or manually unpauses out-of-band. Assets are frozen, not lost (owner-recoverable), so **Medium**, not High: protocol availability of a live contract is impacted under a stated external requirement (a halt), and a competent non-malicious operator would not anticipate that the only reopen path is coupled to full-migration success — a Law-3 footgun. **Must not be netted against the FIXED YS-09.**

### YS-22 (Low) — cleanup catch-path leaves the deployer EOA as pauser
- **fingerprint:** `10fac478` · **entryPoint:** `migrate:ys-swap-cleanup` · **footgun**
- **record:** `reports/phoenix-phase-2-staging-13/findings/low/YS-22-cleanup-catchpath-pauser-restore-skip.json`
- **location:** [`script/PostMigrationCleanup.s.sol#L129-L361`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e935a05/script/PostMigrationCleanup.s.sol#L129-L361)

cleanup reads `origPauser`/`tempPauser` from `ys-swap-deployments.json` via try/catch (~L132–143). On the **catch path** (JSON missing those keys — e.g. a deploy run before the hardening, or a regenerated/partial JSON), `origPauserRecorded` stays false and the `setPauser` restore (~L342) is gated on that flag → **skipped with only a console warning**. The unpause still runs (so the staker IS reopened — no availability loss), but the live staker's pauser is left as the **deployer EOA** instead of the governance pauser `0x7c5A8EeF…85a3`. The post-assert checks `pauser == recorded` **only when `*Recorded` is true**, so it passes **vacuously** and does not catch the wrong end state — the run reports COMPLETE with a buried warning. Silent privilege/wiring drift; owner-fixable; honest **Low**. The happy path (JSON present) restored correctly on the fork, so this only bites the degraded-input path. **Distinct from the FIXED YS-10 on the same script — do not collapse.**

### YS-23 (Low) — PhusdMinterRepoint Phase B below-par reseed, no solvency floor
- **fingerprint:** `6db84596` · **entryPoint:** `PhusdMinterRepoint` (UNWIRED) · **footgun** · **depends on YS-20**
- **record:** `reports/phoenix-phase-2-staging-13/findings/low/YS-23-phusdminterrepoint-phaseb-no-solvency-floor.json`
- **location:** [`script/PhusdMinterRepoint.s.sol#L245-L322`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e935a05/script/PhusdMinterRepoint.s.sol#L245-L322)

Phase B does `withdrawAsOwner(minter, owner, p)` then `recovered = balance delta`; if `recovered < p` (a below-par autopool) it **warns and continues** (~L258), then `noMintDeposit(V2, token, recovered)` re-seeds V2 with the short amount. The only post-verify is `principalOf > 0` (~L319) — there is no `require(recovered >= p)` floor. So a pre-existing autopool shortfall is silently migrated into the V2 position as under-collateralization. The shortfall **originates in the external autopool**, not the script — the defect is the absent solvency floor. This is doubly-gated and **moot until YS-20 is fixed** (the script cannot reach Phase B against the live minter today), hence **Low**.

---

## 4. Carryovers still live

### Re-verified still-live (positive evidence this run)

- **YS-02 / `106d5c6e` (Low) — leg1 dead-on-arrival.** `migrate:ys-swap-leg1` (`script/SkimAndLeg1Migration.s.sol`). The owner is **not** an `authorizedWithdrawer` on the **3 OLD strategies** — story-061 only granted SYA as a withdrawer on the **new V2** strategies, so leg1's first mutating call (`skimSurplus`) reverts dead-on-arrival (`onlyAuthorizedWithdrawer`). Re-verified STILL-LIVE on the fork. A **Low→Medium bump was considered and rejected**: the failure is a clean revert before any mutation, no value loss, no bad state landed, recoverable by one `setWithdrawer(OWNER, true)` per old strategy then re-run — a recoverable operational precondition that blocks the operator's own run, not a protocol-availability harm to users (contrast YS-21, which freezes live users and is correctly Medium). **Stays Low; carryover identity `106d5c6e` fixed (no split).**
- **YS-04 / `8168c808` (Low) — gather off-by-one.** `scripts/gather-migration-inputs.js`, byte-for-byte unchanged since story-060 (zero diff `b27c6ac..e935a05`). The JS treats `getStakersRange`'s half-open `[start,end)` as inclusive, dropping the last staker of every pool; the JSON `.count` undercount then fails the leg1/leg2 preflight `count == on-chain count` check → **hard preflight DoS / unbreakable re-run loop** for any non-empty pool. Fork-confirmed: `getStakersRange(0,2)` returns 2 of 3 DOLA stakers; leg1 preview reverts `'stale DOLA staker count … re-run gather'`. Availability DoS, not value loss.
- **YS-05 / `5c9f1cee` (Low) — leg2 redeposit haircut.** `lib/stable-staker/src/StableStaker.sol`. Unchanged by the stable-staker bump `c3ec65b → 212a6d2` (getStakersRange / migration-credit semantics unchanged); magnitude on fork ~0.006%, consistent with run-12. Bump lastSeen, no status change.

### Applied FIXED

- **YS-13 / `86a0f4fd` — non-idempotent / no-resume.** story-062 made deploy + leg2 resume-idempotent (skip-if-already-target-state on every wiring call; leg2 `initiateMigration` skipped when `poolState != Active`; preview hard-gate). This directly addresses the root cause. The entry is `open` (not human-triaged), so finding-manager may apply the `fixed` transition — flagged here as an automated-reconciliation proposed fix.

### Unverified carryovers — STILL-OPEN (NOT guessed fixed)

Per *recall beats tidiness*, the following were **not positively re-verified** this run and are therefore left **open** (lastSeen bumped to `e935a05`), not silently marked fixed. They are parked in this visible channel rather than dropped:

| id | fp | entryPoint | why still-open |
|---|---|---|---|
| YS-06 | `7621c743` | leg1 | count-equality-only staleness guard; mechanism unchanged (related to live YS-04) |
| YS-07 | `58911bd3` | leg1 | skim-destination doc divergence; no story addresses it |
| YS-08 | `aad98685` | deploy | 25%→10% buffer percent figure untouched by 061–064 |
| YS-11 | `6b3c3b98` | cleanup | standing migrator2 left on the live staker; no `setMigrator(0)` revocation added |
| YS-14 | `e3f6e7a0` | deploy | pauser **registration** so emergency pause reaches the V2 strategies — delta shows staker `setPauser`, not registry registration; needs explicit re-verification |
| YS-15 | `5b5f1d8b` | reset | no on-chain identity verification of JSON-sourced strategy addresses |
| YS-16 | `691e85a6` | reset | PREVIEW_MODE leaking into the broadcast leg not demonstrably closed by prepending a preview gate; candidate for targeted re-verification |
| YS-17 | `470eed06` | reset | doc/NatSpec/code three-way post-condition disagreement; unreconciled |
| YS-18 | `9caa24f4` | deploy | stale `_acquireShares` NatSpec ("full nominal amount") not demonstrably corrected |
| YS-19 | `44107b0e` | leg1 | `viem` not declared in package.json |

Two benign deltas were examined and produced **no finding**: story-061's old-strategy double-registration on SYA (benign), and story-063's band removal (the retained hard solvency require is the real safety property).

---

## 5. Knock-on effects / operator guidance

Concrete, safe-config guidance for running this suite against live mainnet state:

1. **Before running leg1, grant the owner `authorizedWithdrawer` on the 3 OLD strategies** (one `setWithdrawer(OWNER, true)` each). story-061 only granted SYA on the new V2 strategies; without this, leg1 reverts dead-on-arrival at `skimSurplus` (YS-02). This is the prerequisite that unblocks the suite.
2. **Fix the gather off-by-one (YS-04) or expect a preflight DoS.** The unchanged half-open/inclusive mismatch in `gather-migration-inputs.js` undercounts every pool and the leg1/leg2 preflight will revert in an unbreakable re-run loop until the JSON count is corrected.
3. **Add a standalone break-glass unpause before pausing the live staker (YS-21).** Ship a minimal `EmergencyUnpauseAndRestorePausers` script that reads `origPauser`/`tempPauser` from `ys-swap-deployments.json`, unpauses, and restores — **decoupled** from the migration-complete verifications — so a mid-suite halt cannot strand the live original staker and the unrelated USDe pool frozen. Document the contract-global live-pool freeze (especially the USDe pool) and its expected duration in the runbook. On the cleanup catch-path, fail loudly and make the post-assert unconditional (YS-22).
4. **Do NOT hand-broadcast `PhusdMinterRepoint` against the current live minter (YS-20).** The live minter is the 4-field build with no `setMaxMintPerDay`; a hand-broadcast can half-repoint the minter and stick the cap at 0 (mint DoS). Either rewrite the script for the 4-field minter (drop the `maxMintPerDay` save/restore + `setMaxMintPerDay` calls and add a config-word-count preflight that aborts with a clear "wrong minter version" message), or redeploy the minter to the `d6ed115` build first. Then **wire it as an npm key** so it inherits the story-062 preview hard-gate, and remove `--skip-simulation` from its NatSpec. Until YS-20 is resolved the script reverts safely at preview (status quo preserved), and YS-23 is moot.
5. **The SYA old-strategy registration is benign.** story-061 deliberately deferred deregistering the old SYA entries to YS-12; their presence is harmless and the new V2 wiring is verified. No action required beyond eventually completing a corrected YS-12.
6. **Compliance note.** This suite IS the prescribed full migration — it never `setYieldStrategy`s in place on a market yield strategy with staked users (memory: phStaging must never do so). It stands up a temp staker, migrates users in legs, and resets onto the V2 strategies. The suite is compliant with that constraint; the operational hazards above are about *running it safely*, not about the migration pattern itself.

---

### Finding index

| id | sev | fp | record |
|---|---|---|---|
| YS-20 | Medium | `6fd3eddc` | `findings/medium/YS-20-phusdminterrepoint-abi-drift.json` |
| YS-21 | Medium | `be9a5a92` | `findings/medium/YS-21-story062-livestaker-pause-no-breakglass.json` |
| YS-22 | Low | `10fac478` | `findings/low/YS-22-cleanup-catchpath-pauser-restore-skip.json` |
| YS-23 | Low | `6db84596` | `findings/low/YS-23-phusdminterrepoint-phaseb-no-solvency-floor.json` |

Proposed ledger transitions (confirm via `/ledger phoenix-phase-2-staging`): `acknowledged → fixed` for YS-01 (`28d5044e`), YS-03 (`44dc0e3a`), YS-09 (`55ebe2c0`), YS-10 (`e34ac20e`); `open → fixed` for YS-13 (`86a0f4fd`). New findings YS-21 and YS-22 must NOT be netted against the FIXED YS-09 and YS-10 respectively.
