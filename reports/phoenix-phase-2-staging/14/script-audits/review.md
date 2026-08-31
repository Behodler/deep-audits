# Phoenix Phase 2 Staging — Script Audit Review
## Run 14 | Story-065 Fix-Wave Regression
**Commit audited:** `00dd45f` (story-065 merged)
**Last audited commit:** `e935a05` (run-13)
**Date:** 2026-06-13

---

## Executive Summary

Story-065 is a comprehensive restructure of the yield-strategy swap migration saga, rewriting it as a formal 12-step operational sequence that addresses five open findings from run-13 (YS-02, YS-04, YS-20, YS-21, YS-22) and two carried-over medium findings (YS-02's root cause in leg-1 withdrawer grant, the off-by-one in gather). The saga covers: deploying a fresh phUSD minter (replacing the in-place repoint approach of YS-20), authorizing it, cutting over and revoking the old minter, pausing the live staker, gathering staker lists, performing the two-leg user migration, resetting and rewiring the pool, completing cleanup, evacuating the old minter position, deregistering the old yield strategies from the SYA, decommissioning the old strategies, and providing an explicit break-glass unpause.

**Finding counts at HEAD 00dd45f:**

| Category | Count |
|---|---|
| Closed (Fixed) | 4 (YS-02, YS-04, YS-21, buffer-percent) |
| Closed (Superseded) | 3 (YS-20 / 6fd3eddc, YS-22 / 10fac478, YS-23 / 6db84596) |
| New findings this run | 8 (2 Medium, 3 Low, 1 QA, 2 Informational) |
| Still-live from prior runs | 13 (unchanged) |
| Total open (new + carry) | 21 |

**Is the suite safe to run?** No — two hard blockers must be resolved before broadcast:

1. **ba886105 (Medium)** — Story-065's own YS-22 fix introduces a zero-gate in `PostMigrationCleanup.s.sol` that permanently hard-reverts on every valid production run following a clean Step 1 broadcast, because `DeployTempStableStakerAndMigrators.s.sol` always writes `address(0)` as `.tempPauser` before the `setPauser` call. The cleanup entry point is DoS'd without manual JSON surgery.

2. **75e4305a (Medium)** — The comment in `SkimAndLeg1Migration.s.sol` promises a `staker_realized == staker_booked` "ultimate gate" in `ResetAndRewire.s.sol` that enforces zero haircut for users. That gate does not exist in the code. The only enforcement is an off-chain fork-preview run. Any Phase-4 integer truncation (finding 88331e64) or stale-estimation gap propagates silently into Leg-2 as user principal loss with no on-chain revert path.

Additional low-severity gaps (pauser registration for the new minter, post-cutover newMinter canMint assertion, UI repoint timing) should be addressed before broadcast but do not independently block execution.

---

## Story-065 Scope

### New Entry Points (12-Step Saga + Break-Glass)

| npm script | Script | Step |
|---|---|---|
| `migrate:phusd-minter-deploy` | `DeployNewPhusdMinter.s.sol` | Step 2 |
| `migrate:phusd-minter-cutover` | `CutoverAndRevokeOldMinter.s.sol` | Step 3 |
| `migrate:phusd-minter-evacuate` | `EvacuateAndReseedMinter.s.sol` | Step 10 |
| `migrate:ys-sya-deregister` | `DeregisterOldStrategiesFromSYA.s.sol` | Step 11 |
| `migrate:ys-old-strategy-decommission` | `DecommissionOldStrategies.s.sol` | Step 12 |
| `migrate:ys-swap-breakglass` | `UnpauseStakerBreakGlass.s.sol` | Break-glass |

Each of the above also has a `*-preview` variant in `package.json`.

### Modified Entry Points

The existing five-script YS-swap suite was substantially modified:

- `migrate:ys-swap-deploy` — `DeployTempStableStakerAndMigrators.s.sol`: adds pauser-capture JSON writes, migrator wiring, resume guards (story-062 integration)
- `migrate:ys-swap-leg1` — `SkimAndLeg1Migration.s.sol`: adds `_ensureWithdrawer` calls for all three strategies (YS-02 fix), adds Phase-4 prefund shortfall logic (`_prefundShortfall`)
- `migrate:ys-swap-reset` — `ResetAndRewire.s.sol`: modified to integrate Phase-5 reset with prefund accounting
- `migrate:ys-swap-gather-leg1` / `migrate:ys-swap-gather-leg2` — `scripts/gather-migration-inputs.js`: off-by-one paging fix (YS-04 fix, half-open range corrected)
- `migrate:ys-swap-cleanup` — `PostMigrationCleanup.s.sol`: YS-22 hardening (zero-gate on tempPauser, now defective per finding ba886105)

### Changed Approach: Fresh Minter Deploy vs In-Place Repoint

The run-13 `PhusdMinterRepoint.s.sol` approach (YS-20) has been abandoned. The root cause — the live phUSD minter at `0x435B...77E5` is a pre-story-007 4-field `StablecoinConfig` build lacking `setMaxMintPerDay` entirely — cannot be addressed by repointing. Story-065 instead deploys a fresh `PhusdStableMinter` from the `d6ed115` build, which has the 7-field config and `setMaxMintPerDay` from birth. The old minter's existing positions on the old strategies are intentionally left in place for owner-gated evacuation in Phase 6 (`EvacuateAndReseedMinter.s.sol`).

---

## Findings Closed by Story-065

### YS-02 — Leg-1 Broadcast Dead on Arrival: Owner Not an Authorized Withdrawer
**Fingerprint:** `106d5c6e`
**Prior severity:** Low
**What it was:** `SkimAndLeg1Migration.s.sol` called `skimSurplus` on all three old strategies before the deployer/owner EOA was registered as an authorized withdrawer on any of them. The first `skimSurplus` call reverted with an access-control error, making the entire Leg-1 broadcast dead on arrival.
**How story-065 addressed it:** `_ensureWithdrawer(address strategy)` is now called for all three strategies (`YS_DOLA_OLD`, `YS_USDC_OLD`, `YS_USDE`) at the start of `run()`, before any `skimSurplus` call. The helper reads `authorizedWithdrawers[OWNER_ADDRESS]` and calls `setWithdrawer(OWNER_ADDRESS, true)` only when not already granted (idempotent). Post-grant `require` assertions confirm all three strategies granted status before execution proceeds.
**Proposed status:** FIXED

### YS-04 — Off-by-One in gather-migration-inputs.js Paging
**Fingerprint:** `8168c808`
**Prior severity:** Low
**What it was:** `gather-migration-inputs.js` used `end = Math.min(start + PAGE_SIZE - 1, countNum)` and `start = end + 1` for the paging loop, treating the half-open `[start, end)` range returned by `StableStaker.getStakersRange` as inclusive. This dropped the last staker of every page, making the count preflight check permanently unsatisfiable and DoS'ing both gather steps.
**How story-065 addressed it:** The loop now uses `end = Math.min(start + PAGE_SIZE, countNum)` (no `-1`) and `start = end` (correct advancement for a half-open range). A `console.log('[start, end) ...')` annotation confirms documented intent. The `allStakers.length != countNum` warning at line 291 guards against race conditions.
**Proposed status:** FIXED

### YS-20 — PhusdMinterRepoint ABI Mismatch (Superseded)
**Fingerprint:** `6fd3eddc`
**Prior severity:** Medium
**What it was:** `PhusdMinterRepoint.s.sol` tried to call a 7-field `StablecoinConfig` struct decode and `setMaxMintPerDay` on the live phUSD minter at `0x435B...77E5`, which is a 4-field build that does not expose either interface. The script reverted before any state mutation on every run.
**How story-065 addressed it:** The `PhusdMinterRepoint.s.sol` approach is entirely abandoned. Story-065 deploys a fresh `PhusdStableMinter` from the `d6ed115` build via `DeployNewPhusdMinter.s.sol`. There is no ABI mismatch because the new minter is the 7-field build from birth. The old minter is revoked atomically in Step 3 (`CutoverAndRevokeOldMinter.s.sol`).
**Proposed status:** SUPERSEDED (approach replaced, not merely fixed)

### YS-21 — Live-Staker Pause Has No Break-Glass
**Fingerprint:** `be9a5a92`
**Prior severity:** Medium
**What it was:** The YS-swap deploy step globally paused the live `StableStaker`, which also froze the unrelated USDe pool. If the migration suite halted mid-run for any reason, there was no script-level path to unpause the staker without completing or aborting the full migration.
**How story-065 addressed it:** `UnpauseStakerBreakGlass.s.sol` is added as an explicit operator-controlled escape hatch. It verifies `staker.owner() == OWNER_ADDRESS`, returns early (no-op) if already unpaused, calls `staker.unpause()` if paused, and post-asserts `!paused()`. The script comment confirms that migration hooks (`initiateMigration`, `batchMigrate`, `userMigrate`, `depositFor`, `finalizeAndReset`) are all free of `whenNotPaused`, so an interim unpause does not corrupt migration state.
**Proposed status:** FIXED

### YS-22 — Cleanup Catch-Path Silently Leaves Deployer EOA as Pauser (Superseded by New Defect)
**Fingerprint:** `10fac478`
**Prior severity:** Low
**What it was:** `PostMigrationCleanup.s.sol`'s error handling for missing JSON state silently skipped the pauser-restore step when the recorded pauser addresses were absent from the deployments JSON, leaving the deployer EOA as the pauser on the live staker after migration.
**How story-065 addressed it:** Story-065 replaced the silent-skip with a hard-revert gate: `require(tempPauserRecorded && recordedTempPauser != address(0), 'YS-22: tempPauser not recorded (or zero)')`. The old silent-skip behavior is gone.
**Why it is superseded rather than fixed:** The new zero-gate itself introduces a new defect (finding `ba886105` — see New Findings below) of equal severity. `DeployTempStableStakerAndMigrators.s.sol` always writes `address(0)` as `.tempPauser` because it reads the freshly deployed `tempStaker`'s pauser before calling `setPauser(OWNER_ADDRESS)`, and the `StableStaker` constructor does not initialize `pauser`. The story-065 cleanup fix now hard-reverts on the zero that story-065's own deploy step intentionally writes. The old defect behavior is gone but a new DoS has replaced it.
**Proposed status:** SUPERSEDED (new defect ba886105 is the live issue)

### YS-23 — PhusdMinterRepoint Phase B Missing Solvency Floor (Superseded)
**Fingerprint:** `6db84596`
**Prior severity:** Low
**What it was:** `PhusdMinterRepoint.s.sol` Phase B re-seeded the V2 position with the recovered amount without asserting a minimum recovery ratio, silently carrying any pre-existing autopool shortfall into V2.
**How story-065 addressed it:** `PhusdMinterRepoint.s.sol` is entirely abandoned. The position handling is now performed by `EvacuateAndReseedMinter.s.sol` (Phase 6), which uses a different mechanism (`withdrawAsOwner` + `noMintDeposit`). The Phase B path in `PhusdMinterRepoint` is no longer in the migration sequence.
**Proposed status:** SUPERSEDED (gated finding on an abandoned approach)

---

## New Findings (Run-14)

### ba886105 — YS-22 Fix DoS: tempPauser Zero-Gate Always Reverts on Valid Production Runs
**Severity:** Medium
**Entry point:** `migrate:ys-swap-cleanup`
**Contract / line:** `script/PostMigrationCleanup.s.sol` lines 345–365; `script/DeployTempStableStakerAndMigrators.s.sol` lines 255–303

**Description:**
`PostMigrationCleanup.s.sol` line 351 now enforces `require(tempPauserRecorded && recordedTempPauser != address(0), 'YS-22: tempPauser not recorded (or zero)')`. The intent is to detect a missing JSON entry and fail loudly rather than silently.

However, `DeployTempStableStakerAndMigrators.s.sol` line 256 reads `tempPauser = IStakerOwnable(address(tempStaker)).pauser()` immediately after deploying a fresh `StableStaker` via `new StableStaker(phUSD, OWNER_ADDRESS)`. The `StableStaker` constructor does not initialize the `pauser` slot, so `tempStaker.pauser()` returns `address(0)` at this moment. The `setPauser(OWNER_ADDRESS)` call that would initialize it comes at lines 270–274, *after* the read. The script captures `address(0)` and writes it to the JSON at line 303.

The deploy script's own comment at lines 292–294 explicitly documents this as the intended contract: "A freshly deployed tempStaker pauser is address(0) by default; persist it anyway (cleanup treats a zero recorded temp pauser as restore to zero)." Story-065 invalidated that contract by adding the `!= address(0)` gate. On every clean Step 1 broadcast, the JSON will contain `"tempPauser":"0x0000...0000"`, and `PostMigrationCleanup` will hard-revert at line 351 with "YS-22: tempPauser not recorded (or zero)".

**Impact:** `migrate:ys-swap-cleanup` is permanently unrunnable after any valid Step 1 broadcast without manual JSON surgery. The final cleanup phase — which revokes the `tempStaker`'s phUSD mint authority (line 321), unpauses both stakers (lines 327–336), and restores the original pauser (lines 338–350) — cannot complete. Both stakers remain paused indefinitely after Leg-2 finishes, blocking all user deposit/withdraw operations on the live pool.

**Recommendation:** Two equivalent fixes:
1. Remove the `!= address(0)` condition from the tempPauser check only. Keep `tempPauserRecorded` (the key must be present in JSON) but permit zero (since `address(0)` is the valid as-deployed tempStaker pauser, not an unrecorded error). The `origPauser` check is correct as-is — the deploy script has a `require(origPauser != address(0))` gate at line 262, so `origPauser` can never legitimately be zero.
2. Alternatively, move lines 255–258 (the pauser reads) to occur *after* lines 270–274 (`setPauser(OWNER_ADDRESS)` calls) in `DeployTempStableStakerAndMigrators.s.sol`. This causes the JSON to record `OWNER_ADDRESS` for `.tempPauser`, which is non-zero and passes the cleanup gate. The cleanup then restores the pauser to `OWNER_ADDRESS`, which is idempotent if it was already the pauser.

---

### 75e4305a — Promised "Ultimate Gate" Zero-Haircut Assertion Absent from ResetAndRewire Post-Assert
**Severity:** Medium
**Entry point:** `migrate:ys-swap-reset`
**Contract / line:** `script/ResetAndRewire.s.sol` lines 271–325; `script/SkimAndLeg1Migration.s.sol` lines 432–434

**Description:**
`SkimAndLeg1Migration.s.sol` lines 432–434 include the comment: "The Phase-5 `staker_realized == staker_booked` assert is the ultimate gate. If this fires, abort and re-derive the pre-fund amount." This is presented as the definitive machine-enforced safety backstop proving users will receive 100% of their booked principal from the V2 re-deposit in Leg-2.

The actual post-assert block in `ResetAndRewire.s.sol` lines 271–325 contains none of this. The checks present are: (a) `dolaP <= dolaIdleSwept` — over-credit prevention; (b) `dolaIdleSwept == 0 || dolaP > 0` — the sweep fired and produced something; (c) `yieldStrategy(DOLA) == ysDolaV2` — correct strategy wiring; (d) `dolaTotalStaked == 0` — the pool was reset. Identical pattern for USDC. There is no check comparing `totalBalanceOf(staker)` to `principalOf(staker)` anywhere in the file.

The only mechanism providing the zero-haircut guarantee is the off-chain fork-preview operator run described in `_printSummary` — operator judgment, not machine enforcement. If Phase-4 prefunding under-delivers (due to integer truncation per finding 88331e64, stale snapshot between gather and broadcast, or a minter position change), no on-chain assertion prevents Leg-2 from migrating users at a haircut. The comment's claim that this is "the definitive gate" is factually false.

**Impact:** Any Phase-4 under-delivery propagates silently through `ResetAndRewire.s.sol` and into `Leg2Migration.s.sol`, where users are re-deposited into the V2 strategy at the V2 entry exchange rate. The ERC4626 `convertToAssets` rounding in `_acquireShares` (finding 5c9f1cee, still-live) adds an additional micro-haircut on each user deposit. The combined shortfall materializes as missing principal in users' V2 accounts with no revert, no alert, and no on-chain recovery path.

**Recommendation:** Add `staker_realized >= staker_booked` assertions to the `ResetAndRewire.s.sol` post-assert block for each token. Concretely, after the pool is wired and totalStaked is confirmed zero, add:

```solidity
require(
    IYSView(ysDolaV2).totalBalanceOf(DOLA, ORIGINAL_STABLE_STAKER) >=
    IYSView(ysDolaV2).principalOf(DOLA, ORIGINAL_STABLE_STAKER),
    "Post-assert: DOLA staker V2 realized < booked — abort and re-derive prefund"
);
```

and the equivalent for USDC. Also update the `SkimAndLeg1Migration.s.sol` comment to accurately state where the gate lives rather than referencing a non-existent check.

---

### 0a2387e6 — New phUSD Minter Deployed Without Pauser: Emergency Pause Absent from Birth
**Severity:** Low
**Entry point:** `migrate:phusd-minter-deploy`
**Contract / line:** `script/DeployNewPhusdMinter.s.sol` lines 159–236

**Description:**
`PhusdStableMinter` implements `IPausable` with a `pauser` state variable, `setPauser`, `pause`, and `unpause` functions. The constructor sets `pauser` to `address(0)`. `DeployNewPhusdMinter.s.sol` wires the minter (`setClient`, `registerStablecoin`, `approveYS`, `setMaxMintPerDay`, `IFlax.setMinter`) but never calls `minter.setPauser(...)`. As deployed, `pause()` and `unpause()` revert "Only pauser" for every caller — including the owner — because no address satisfies `msg.sender == pauser` when `pauser == address(0)`.

The global Pauser contract (`0x7c5A8EeF1d836450C019FB036453ac6eC97885a3`) is wired to every other `IPausable` in the Phoenix ecosystem (confirmed in `DeployMainnetNFTStaking.s.sol:55`, `DeployMainnetNudgePoolerV2.s.sol`) but is absent from the new minter's wiring sequence. The `_postVerify` block (lines 208–236) asserts YS wiring and mint authority but has no assertion that `pauser != address(0)` or that the minter is registered with the global Pauser.

**Impact:** If a mint exploit or abnormal behavior is discovered on the new minter after Phase 3 (cutover) makes it the sole live mint path, the operator cannot pause it via the normal `Pauser.pause(minter)` governance path. The only recourse is per-token `setStablecoinEnabled(token, false)` — at minimum two owner-signed transactions, slower and less composable than a single Pauser call. This gap persists for the full operational lifetime of the new minter.

**Recommendation:** Add the following two calls in `DeployNewPhusdMinter.s.sol` immediately after the `IFlax.setMinter` grant at line 178:

```solidity
minter.setPauser(PAUSER_ADDRESS);
IPauser(PAUSER_ADDRESS).register(address(minter));
```

where `PAUSER_ADDRESS = 0x7c5A8EeF1d836450C019FB036453ac6eC97885a3`. `setPauser` must precede `register` because `register` validates that `pauser()` already returns the Pauser's own address (established pattern: `DeployMocks.s.sol:795-798`). Add a corresponding post-verify assertion: `require(minter.pauser() == PAUSER_ADDRESS, "Verify: pauser not set")`.

---

### 5c19abfe — Post-Cutover Assert Omits newMinter canMint Check: Constant Transposition Footgun
**Severity:** Low
**Entry point:** `migrate:phusd-minter-cutover`
**Contract / line:** `script/CutoverAndRevokeOldMinter.s.sol` lines 126–144

**Description:**
The post-assert block confirms `!OLD_MINTER.canMint`, `!OLD_MINTER` authorized on `YS_DOLA_OLD`, and `!OLD_MINTER` authorized on `YS_USDC_OLD`. It does not confirm that `IFlaxMinter(PHUSD).authorizedMinters(newMinter).canMint` remains true.

The preflight at lines 86–88 verifies `newMinter.canMint` before revoking, but there is no re-verification after the three revocation calls. If an operator mistakenly transposes the `newMinter` and `OLD_MINTER` constants in the script (a realistic copy-paste error during deployment), the revocation call at line 115 disables the replacement minter. The three post-asserts pass because they only check that the `OLD_MINTER` constant is now revoked — the fact that the revoked address is actually `newMinter` is invisible.

**Impact:** A constant transposition atomically revokes both the old and new minters, leaving phUSD minting completely disabled with no active mint path. Recovery requires a new `setMinter(newMinter, true)` owner transaction. No user funds are at risk but mint availability is lost until recovery.

**Recommendation:** Add to the post-assert block:

```solidity
require(
    IFlaxMinter(PHUSD).authorizedMinters(newMinter).canMint,
    "Post-assert: newMinter lost mint authority during cutover"
);
```

---

### 34335a28 — UI Repoint After Cutover Is Fully Off-Chain With No On-Chain Gate
**Severity:** Low
**Entry point:** `migrate:phusd-minter-cutover`
**Contract / line:** `script/CutoverAndRevokeOldMinter.s.sol` lines 139–145

**Description:**
`CutoverAndRevokeOldMinter.s.sol` atomically revokes `OLD_MINTER`'s mint authority and client status in a single broadcast. The only safeguard ensuring the phoenix-ui is repointed before (or immediately after) cutover is a `console.log` reminder at lines 141–144 directing the operator to run `patch-mainnet-addresses-phusd-minter-replace.js` and manually redeploy the UI's `mainnet-addresses.ts` (acknowledged as "Q-REFS" in NatSpec). There is no mandatory delay, no timelock, no on-chain enforcement, and no required pre-broadcast check that the UI was updated. If the operator broadcasts Phase 3 while the live UI still points at `OLD_MINTER`, every user who clicks mint receives a revert until the UI is redeployed.

**Impact:** User-facing mint availability gap between Phase 3 broadcast and UI redeployment. Funds are not at risk (mint reverts cleanly). Duration is bounded only by operator speed, potentially minutes to hours depending on the UI CI/CD pipeline.

**Recommendation:** Document at the top of `CutoverAndRevokeOldMinter.s.sol` (and in the saga runbook) that the UI repoint and redeployment must be confirmed complete before running Phase 3 broadcast — not as an afterthought reminder. Consider chaining the off-chain patcher in the `migrate:phusd-minter-cutover` npm script (`forge broadcast && node scripts/patch-mainnet-addresses-phusd-minter-replace.js`) to reduce the window to seconds and enforce ordering at the shell level.

---

### f82e0a75 — NatSpec Dead-Letter Reference to KNOWN_WITHDRAWERS: Automated Revocation Loop That Does Not Exist
**Severity:** Low
**Entry point:** `migrate:ys-old-strategy-decommission`
**Contract / line:** `script/DecommissionOldStrategies.s.sol` lines 22–26, and lines 123–124

**Description:**
The contract-level NatSpec at lines 22–26 states: "Other withdrawers, if any, are revoked here too when known (see KNOWN_WITHDRAWERS)." No `KNOWN_WITHDRAWERS` constant, array, or enumeration loop exists anywhere in the file. The historical `setWithdrawer(newSYA, true)` call in `ReplaceSYAMainnet.s.sol` left the live SYA (`0x3bBE9283...`) as an authorized withdrawer on both `YS_DOLA_OLD` and `YS_USDC_OLD`. After decommissioning, neither strategy calls `setWithdrawer(SYA, false)`.

The inline implementation comment at lines 123–124 is accurate and contradicts the NatSpec: "other withdrawers, if any, must be revoked by the operator if they appear — there is no on-chain enumeration of withdrawers."

**Impact:** The residual SYA withdrawer authorization on both decommissioned strategies is completely inert in normal operation: `skimSurplus` is gated `whenNotPaused`, and both strategies are paused by the end of `_decommission`. If the owner ever unpauses either strategy for emergency residual recovery, the stale SYA withdrawer authorization would permit the live SYA to call `skimSurplus` on the decommissioned strategies, routing any yield from residual shares to the SYA's configured recipient rather than the treasury.

**Recommendation:** Remove the "(see KNOWN_WITHDRAWERS)" reference from the NatSpec or add an explicit `setWithdrawer(LIVE_SYA_ADDRESS, false)` call in `_decommission` for the known live SYA address (`0x3bBE9283...`), with a corresponding post-assert: `require(!s.authorizedWithdrawers(LIVE_SYA_ADDRESS))`. The inline comment at lines 123–124 is accurate and should be made consistent with the NatSpec.

---

### 88331e64 — Phase-4 Prefund Integer Truncation: principalToWithdraw Rounds Down, No Hard-Revert on Under-Delivery
**Severity:** Low
**Entry point:** `migrate:ys-swap-leg1`
**Contract / line:** `script/SkimAndLeg1Migration.s.sol` function `_prefundShortfall`, lines 454–481

**Description:**
`principalToWithdraw = (shortfall * minterBooked) / minterRealizable` (line 456) uses Solidity integer division, which truncates toward zero. In both the below-par case (minterBooked > minterRealizable) and the at-par case (exact division is not guaranteed), the result may be one wei low. The disposed shares then deliver slightly less than `shortfall` underlying to the staker. The code detects this via the `injected < shortfall` branch at lines 475–477 and emits a `WARNING` log, but does not hard-revert.

This finding is a compounding factor for finding 75e4305a (absent ultimate gate): the Phase-4 soft-warning is the only alert mechanism for an under-delivery that has no on-chain backstop in Phase-5 and propagates as user haircut into Leg-2.

**Impact:** Up to 1-wei per-pool under-delivery propagates into the V2 strategy as missing user principal. In isolation this is dust-level (immaterial economically). In combination with the absent `staker_realized == staker_booked` gate in ResetAndRewire (75e4305a), it removes machine-enforced safety at a point where the comment guarantees it exists. Fork confirmation of the exact delivered amount is required before mainnet broadcast regardless.

**Recommendation:** Apply ceiling division: `principalToWithdraw = (shortfall * minterBooked + minterRealizable - 1) / minterRealizable`. This guarantees the disposed shares deliver at least `shortfall` underlying. Replace the `WARNING` log branch with a `require(injected >= shortfall, ...)` hard-revert for a critical safety path. Also address finding 75e4305a (add the missing gate in ResetAndRewire).

---

### b9e4c2a1 — Break-Glass Early-Return Silently Succeeds When Staker Not Yet Paused: No Post-Assert on Early Path
**Severity:** QA
**Entry point:** `migrate:ys-swap-breakglass`
**Contract / line:** `script/UnpauseStakerBreakGlass.s.sol`

**Description:**
`UnpauseStakerBreakGlass.s.sol` returns early (console.log + return) when `staker.paused() == false` on entry — correct operational behavior, nothing to do. However, there is no `require(!pausedAfter)` in the early-return code path (that assertion exists only in the paused-and-then-unpaused path). An operator who runs this script before the migration suite has paused the staker will see "Staker already unpaused - nothing to do." — a correct message, but one that could be mistaken for confirmation of a successful unpause when read quickly in a busy migration log.

**Impact:** No security impact. Migration hooks (`initiateMigration`, `batchMigrate`, `userMigrate`, `depositFor`, `finalizeAndReset`) are all free of `whenNotPaused`; an interim unpause does not corrupt migration state. Ergonomic gap only.

**Recommendation:** Add a final `require(!staker.paused(), "Post-assert: staker not unpaused")` in the early-return code path for symmetry with the normal path. Low priority.

---

## Still-Live Open Findings

The following findings from prior runs remain unchanged at HEAD `00dd45f`. Each has been confirmed via code inspection of the relevant script or library file.

| Fingerprint | Title | Severity | Entry Point |
|---|---|---|---|
| `5c9f1cee` | Leg-2 re-deposit haircuts principal by ~0.026% DOLA / ~0.016% USDC (convertToAssets vs nominal) | Low | `migrate:ys-swap-leg2` |
| `7621c743` | Snapshot vs broadcast membership drift: equal-count guard does not verify address-set identity | Low | `migrate:ys-swap-leg1`, `leg2` |
| `58911bd3` | Skim proceeds sent to original staker not treasury — code now correct per story-065 redesign, plan doc not updated | Low (doc) | `migrate:ys-swap-leg1` |
| `6b3c3b98` | Standing migrator2 on live original staker after COMPLETE: PostMigrationCleanup omits setMigrator(address(0)) | Low | `migrate:ys-swap-cleanup` |
| `e3f6e7a0` | Replacement V2 strategies and tempStaker deployed without pauser registration | Low | `migrate:ys-swap-deploy` |
| `5b5f1d8b` | ResetAndRewire preflight wires JSON-sourced V2 strategy addresses without on-chain identity verification | Low | `migrate:ys-swap-reset` |
| `691e85a6` | PREVIEW_MODE env leak: broadcast npm scripts do not unset PREVIEW_MODE=false; a stale env silently degrades to prank-mode | Low | All broadcast entries |
| `470eed06` | Intent-doc / NatSpec / code three-way disagreement on expected post-wire principal for V2 DOLA | Low | `migrate:ys-swap-reset` |
| `9caa24f4` | Stale NatSpec on ERC4626YieldStrategy._acquireShares: doc says "full nominal amount", code now credits convertToAssets | QA | `migrate:ys-swap-deploy` |
| `44107b0e` | viem not declared in package.json: mandatory gather prerequisite fails on clean checkout | QA | `migrate:ys-swap-leg1`, `leg2` |
| `85d794b3` | Sky-pooler cutover leaves index-4 unmintable: newPooler._minter never set to NFTMinterV2 | Medium | `dispatcher-replace-sky-pooler` |
| `44dc0e3a` | Post-migration yield collection severed: SYA still points at old strategies, not authorized as withdrawer on V2 | Medium | `migrate:ys-swap-deploy` |
| `55ebe2c0` | ResetAndRewire broadcasts with --skip-simulation and non-idempotent step sequence | Medium | `migrate:ys-swap-reset` |

The remaining open findings from the full ledger (entry points `RestoreMintAtIndex4`, `batch-minter-replace`, `verify-stable-staker`, `dev`, `migrate:ss-*`, `batch-minter-migrate`, `PhusdMinterRepoint`) are not part of the story-065 saga scope and remain open per the existing ledger.

---

## Operator Guidance

### Pre-Flight Checklist (Resolve Before Any Broadcast)

The following must be addressed before running any saga step on mainnet:

1. **BLOCKER — Fix ba886105 (YS-22 tempPauser DoS):** Either remove the `!= address(0)` condition from the `recordedTempPauser` check in `PostMigrationCleanup.s.sol:351`, or move the tempStaker pauser-read in `DeployTempStableStakerAndMigrators.s.sol` to after the `setPauser(OWNER_ADDRESS)` call. Do not broadcast Step 1 without this fix deployed.

2. **BLOCKER — Add ultimate gate to ResetAndRewire (75e4305a):** Add `totalBalanceOf(DOLA, ORIGINAL_STABLE_STAKER) >= principalOf(DOLA, ORIGINAL_STABLE_STAKER)` assertions to the `ResetAndRewire.s.sol` post-assert block for each token. This must be in place before Leg-1 executes.

3. **Add pauser wiring for new phUSD minter (0a2387e6):** Add `minter.setPauser(PAUSER_ADDRESS)` + `IPauser(PAUSER_ADDRESS).register(address(minter))` calls to `DeployNewPhusdMinter.s.sol` and a corresponding post-verify assertion.

4. **Add newMinter canMint post-assert to CutoverAndRevokeOldMinter (5c19abfe):** Single-line addition. Prevents a catastrophic constant-transposition error.

5. **Install viem dependency (44107b0e):** `npm install --save viem` (or add to `devDependencies`). Without this, both gather steps fail on a clean checkout or in CI, blocking Leg-1 and Leg-2 entirely.

6. **Apply ceiling division to Phase-4 prefund (88331e64):** Change `(shortfall * minterBooked) / minterRealizable` to `(shortfall * minterBooked + minterRealizable - 1) / minterRealizable`. Replace the soft-warning branch with a hard-revert.

7. **Confirm `ys-swap-deployments.json` (production file) is absent:** Only `ys-swap-deployments-preview.json` exists in `script/migration-inputs/` at HEAD. The production file must be created by the Step 1 broadcast. Ensure the broadcast path (not preview) is executed first and the file is persisted before subsequent steps read from it.

8. **Confirm `PREVIEW_MODE` is unset in the broadcast shell (691e85a6):** Before running any broadcast npm script, `unset PREVIEW_MODE` or add `PREVIEW_MODE=false` to the beginning of each broadcast script entry in `package.json`.

9. **UI repoint timing (34335a28):** Confirm the phoenix-ui redeployment pipeline has been prepared before broadcasting Phase 3 (Step 3, `migrate:phusd-minter-cutover`). Users on the stale UI will see mint reverts for the full duration of the redeployment window.

### Key Monitoring Checkpoints During the Run

During execution of the saga, pause and verify state at each of the following critical transition points before proceeding to the next step:

- **After Step 2 (DeployNewPhusdMinter):** Read back `minter.pauser()`, `minter.getStablecoinConfig(DOLA).maxMintPerDay`, and `minter.getStablecoinConfig(USDC).maxMintPerDay`. Both caps must be `4000e18`, not `0`. A cap of `0` means `setMaxMintPerDay` ran before `registerStablecoin` (the documented footgun).
- **After Step 3 (CutoverAndRevokeOldMinter):** Verify `IFlaxMinter(PHUSD).authorizedMinters(OLD_MINTER).canMint == false` AND `IFlaxMinter(PHUSD).authorizedMinters(newMinter).canMint == true`. Deploy the UI repoint now if it was not pre-staged.
- **After gather-leg1 (Step 4):** Confirm `dolaCount` and `usdcCount` in `migration-inputs/staker-list.json` match on-chain `poolInfo(DOLA).stakerCount` and `poolInfo(USDC).stakerCount`. Count mismatch aborts leg-1.
- **After Leg-1 (Step 5, SkimAndLeg1Migration):** Read `poolInfo(DOLA).idleBalance` and `poolInfo(USDC).idleBalance` on the original staker. These must be >= the respective `poolInfo.totalStaked` values to satisfy the ResetAndRewire sweep assertion. Also confirm no `"WARNING: shortfall not fully covered"` line appears in broadcast output (if it does, halt and re-derive the prefund before proceeding).
- **After ResetAndRewire (Step 6):** Verify `poolInfo(DOLA).totalStaked == 0`, `poolInfo(USDC).totalStaked == 0`, and `yieldStrategy(DOLA) == ysDolaV2`, `yieldStrategy(USDC) == ysUsdcV2`. The new ultimate-gate assertion (to be added per 75e4305a) should appear in this step's post-assert output as a confirmation line.
- **After gather-leg2 (Step 7):** Re-run the same count comparison as gather-leg1.
- **After Leg-2 (Step 8, Leg2Migration):** Spot-check 2–3 user accounts: `poolInfo(DOLA, user).staked` on the original staker (should be 0), and `poolInfo(DOLA, user).staked` on the V2 path after staker wiring. If the ultimate gate was added correctly to ResetAndRewire, this is a belt-and-suspenders check.
- **After Cleanup (Step 9, PostMigrationCleanup):** Verify `staker.paused() == false` on the live original staker (and USDe staker if different). Verify `IFlaxMinter(PHUSD).authorizedMinters(tempStaker).canMint == false`. The break-glass fix (ba886105) must be merged before this step is reachable.
- **After EvacuateAndReseedMinter (Step 10):** Verify `YS_DOLA_OLD.principalOf(DOLA, OLD_MINTER) == 0` and `YS_USDC_OLD.principalOf(USDC, OLD_MINTER) == 0`. Any non-zero value means the evacuation did not complete and the old minter still has residual principal in the old strategies.
- **After DeregisterOldStrategiesFromSYA (Step 11):** Verify `!_isRegistered(sya, YS_DOLA_OLD)`, `!_isRegistered(sya, YS_USDC_OLD)`, and `_isRegistered(sya, ysDolaV2)`, `_isRegistered(sya, ysUsdcV2)`. The V2 strategies must remain registered.
- **After DecommissionOldStrategies (Step 12):** Verify `YS_DOLA_OLD.paused() == true`, `YS_USDC_OLD.paused() == true`, and `getAuthorizedClients().length == 0` on both.

### Break-Glass: When and How to Use migrate:ys-swap-breakglass

**When to use:** If the migration suite halts for any reason after Step 1 (`DeployTempStableStakerAndMigrators`) has paused the live `ORIGINAL_STABLE_STAKER` — whether due to a mainnet incident, gas spike, failed preflight on a later step, operator abort, or any unrecoverable mid-suite error — and USDe pool users or other users of the live staker are stranded with their funds inaccessible, run:

```
npm run migrate:ys-swap-breakglass
```

**What it does:** Calls `staker.unpause()` on `ORIGINAL_STABLE_STAKER = 0xbce8ABC09BaEDCabE93419bF875f6186e182079A` via the owner path. Verifies `staker.owner() == OWNER_ADDRESS` before broadcasting. Returns immediately (no transaction) if the staker is already unpaused. Post-asserts `!paused()` after the call.

**What it does NOT do:** It does not reset, advance, or corrupt the migration state machine. `initiateMigration`, `batchMigrate`, `userMigrate`, `depositFor`, and `finalizeAndReset` are all free of `whenNotPaused` — the migration sequence is unaffected by an interim unpause. A later migration step that requires the staker to be paused must re-issue the pause call.

**Important:** Do NOT run the preview variant (`migrate:ys-swap-breakglass-preview`) when an actual emergency unpause is needed — the preview uses `vm.startPrank` and issues no real transaction. The broadcast variant must be used. Run the preview only to confirm the script's preflight and paused-state check before committing to the broadcast.

**Sequence to resume after break-glass:** After using break-glass, consult the saga runbook to determine which step failed. The migration can typically resume from the step that failed, because each script has its own preflight that validates the required prior-step state. Steps are not automatically invalidated by an interim unpause.

---

*Audit performed at HEAD `00dd45f`, story-065 fix-wave. Regression basis: `e935a05` (run-13). All findings verified via source code inspection of `lib/phoenix-phase-2-staging` at the audited commit.*
