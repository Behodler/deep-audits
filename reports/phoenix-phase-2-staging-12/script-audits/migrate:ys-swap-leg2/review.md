# Script Review — `migrate:ys-swap-leg2`

**Entry point:** `migrate:ys-swap-leg2` (`script/Leg2Migration.s.sol:Leg2Migration.run`)
**Story:** Story 060 — yield-strategy swap migration, step 4 of 5
**Project:** phoenix-phase-2-staging @ `b27c6ac` (nested: stable-staker `c3ec65b`, vault `ad12cb1`)
**Mode:** fork-preview (shared anvil fork; predecessors `ys-swap-deploy`, `ys-swap-leg1`, `ys-swap-reset` already executed) at blocks 25297397 → 25297401

---

## Verdict

This is the cleanest leg of the story-060 suite. Once the predecessors' deploy/skim/rewire steps are in place, Leg2Migration does exactly what it intends — it drains the temp staker to zero and repopulates the original StableStaker (now wired to the fixed V2 strategies) with the full pre-migration staker set, all post-conditions passing on-fork with zero unintended writes. The only finding original to this entry point is a disclosure gap: a tiny, uniform `convertToAssets` re-deposit haircut (~0.026% DOLA / ~0.016% USDC) that the intent doc does not mention while claiming 1:1 principal preservation (**YS-05, Low**). Every other hazard reachable here is a recurrence of an issue already canonical at another entry point and is tracked there.

---

## 1. Does it do what it intends?

**Intent (NatSpec + `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md`):** call `migrator2.initiateMigration(DOLA)` then `initiateMigration(USDC)` on the temp staker, chunk-loop `migrator2.migrate(token, chunk[i])` for both tokens, and land every staker back on `ORIGINAL_STABLE_STAKER` (`0xbce8ABC09BaEDCabE93419bF875f6186e182079A`), which step 3 (ResetAndRewire) rewired to the fixed V2 yield strategies. The USDe pool is deliberately untouched.

**Preflight (`_globalPreflight`, reverts before any state change) — all passed on-fork:**
- `block.chainid == 1`; migrator2 / tempStaker / ysDolaV2 / ysUsdcV2 addresses non-zero.
- `migrator2.owner() == OWNER_ADDRESS`; `original.migrator() == migrator2`; `tempStaker.migrator() == migrator2` (step-3 wiring present on both stakers).
- `ysDolaV2.setAsideBufferRecipient() != 0` and `ysUsdcV2.setAsideBufferRecipient() != 0` (both resolve to the original staker `0xbce8…`, confirming the V2 strategies are wired).
- Count-equality drift guards: `leg2DolaCount(3) == tempStaker.stakerCount(DOLA)(3)` and `leg2UsdcCount(6) == tempStaker.stakerCount(USDC)(6)`.

**Execution.** `initiateMigration` engaged terminal migration on both temp pools (snapshot `(R,P)`, realize idle pile, decouple). The chunk loop ran a single chunk per token (3 DOLA + 6 USDC addresses), each `migrate` → `batchMigrate` (pays snapshot credit from temp's idle pile) → `depositFor` on the original → `_routeDeposit` into the fixed V2 strategy. Nine `MigratedOut` and nine `DepositedFor` events fired; no external call reverted (the patched `convertToAssets` deposit path produced no underwater/staleness revert).

**Post-conditions (asserts after the migrate loops) — all passed on-fork:**
- `tempStaker.stakerCount(DOLA) == 0`, `tempStaker.stakerCount(USDC) == 0` (source drained).
- `original.stakerCount(DOLA) == 3`, `original.stakerCount(USDC) == 6` (== pre-migration snapshot).
- `ysDolaV2.principalOf(DOLA, original) == 1060.128 DOLA (1060128287002905075447) > 0`.
- `ysUsdcV2.principalOf(USDC, original) == 1981.493 USDC (1981492890) > 0`.

A withdraw smoke-test run at cleanup confirmed `withdrawDisabled(DOLA) == withdrawDisabled(USDC) == false`, i.e. the restored users can actually withdraw — the migration did not leave the original staker in a frozen state.

**Conclusion:** the script faithfully implements step 4 of story-060. Source drained, destination restored to the exact snapshot count, principal seated on both fixed V2 strategies, USDe untouched.

---

## 2. Does it introduce unintended side effects?

**Fork side-effects (after the inherited/input fixups described in §3) — `unintendedEffects: []`.** Every observed state write is intended:

| Contract | Effect | Result |
|---|---|---|
| tempStaker `0xAb51…` | `initiateMigration` + `batchMigrate _exitPosition ×9` | counts → 0/0, totalStaked → 0, pools idle/decoupled |
| original `0xbce8…` | `depositFor ×9` | counts restored 3 / 6; userInfo + totalStaked repopulated |
| ysDolaV2 `0xc4D5…` | `_routeDeposit` deposit | `principalOf(DOLA, original)` 26.778 → **1060.128 DOLA** (+1033.350) |
| ysUsdcV2 `0x0C2d…` | `_routeDeposit` deposit | `principalOf(USDC, original)` 27.230 → **1981.493 USDC** (+1954.263) |
| autoDOLA / autoUSDC ERC4626 | `vault.deposit` | shares minted to the V2 strategies; underlying pulled from temp's idle pile |

No writes outside this set; the USDe pool and mainnet-addresses files are untouched (leg2 has no `patch-mainnet-addresses` wrapper, unlike the reset step).

**Per-user value preservation.** Because the temp staker holds principal idle (`yieldStrategy(DOLA) == yieldStrategy(USDC) == address(0)`, verified on-fork), leg1's deposit-into-temp was lossless — so leg2 introduces a **single fresh** ERC4626 round-trip haircut, not a compounded one. The fixed V2 strategy credits `convertToAssets(sharesReceived)` (story-060's own fix); the integer-rounding shortfall stays protocol-owned in the strategy.

| Token | Before | After | Loss | Loss % |
|---|---|---|---|---|
| DOLA `0xCad1…` | 9.997399 | 9.994780 | 0.002619 | 0.0262% |
| DOLA `0x4B75…` | 1018.122903 | 1017.858186 | 0.264718 | 0.0260% |
| DOLA `0x25Ad…` *(LEG1-02 dropped)* | 5.498569 | 5.497140 | 0.001430 | 0.0260% |
| **DOLA total** | **1033.618872** | **1033.350106** | **0.268766** | **0.0260%** |
| USDC `0x186c…` | 399.967116 | 399.904139 | 0.062977 | 0.0157% |
| USDC `0xCad1…` | 9.999177 | 9.997602 | 0.001575 | 0.0158% |
| USDC `0x4B75…` | 500.270470 | 500.191705 | 0.078765 | 0.0157% |
| USDC `0xeCbc…` | 400.334986 | 400.271959 | 0.063027 | 0.0157% |
| USDC `0x25Ad…` | 633.340229 | 633.240527 | 0.099702 | 0.0157% |
| USDC `0x0f25…` *(LEG1-02 dropped)* | 10.658723 | 10.657045 | 0.001678 | 0.0157% |
| **USDC total** | **1954.570701** | **1954.262977** | **0.307724** | **0.0157%** |

The haircut is uniform and proportional — the correct, conservative accounting — but the story-060 intent doc's User Impact section discloses only the *old-strategy* `(R,P)` socialization haircut and claims principal is otherwise preserved 1:1. The fresh leg2 re-deposit haircut is undisclosed. This is the sole finding original to this entry point.

> **YS-05 (Low, intent-mismatch / Law-2 doc-faithfulness)** — *Leg2 re-deposit silently haircuts each user's principal by ~0.026% (DOLA) / ~0.016% (USDC); intent doc states principal is preserved 1:1.*
> Root cause: `StableStaker.depositFor / _routeDeposit` — [StableStaker.sol#L616-L638](https://github.com/Behodler/phoenix-phase-2-staging/blob/b27c6ac/lib/stable-staker/src/StableStaker.sol#L616-L638). Finding file: `reports/phoenix-phase-2-staging-12/findings/low/YS-05-leg2-redeposit-haircut.json`.
> No code change required — the rounding is correct conservative behaviour; the fix is to amend the intent doc's User Impact section to disclose the ~0.02–0.03% `convertToAssets` haircut as distinct from the `(R,P)` socialization.
> **Cross-link:** YS-05 ↔ stable-staker `4f143a95` (batchMigrate-vs-userMigrate migration-credit asymmetry) — **distinct mechanism**: YS-05 is uniform deposit-leg `convertToAssets` rounding applied to every migrated position; `4f143a95` is an exit-method asymmetry between the two migration entry paths. Verified not a cross-project duplicate.

**Story-011 compliance (credited > 0).** `depositFor` reverts if `credited == 0`. The smallest migrated positions — `0xCad1…` USDC (~10 USDC, credited 9.997602) and `0x0f25…` USDC (~10.66 USDC, credited 10.657045) — credit fine; no position rounds to zero. The ~0.0157% USDC haircut would only zero a credit for a position below ~64 wei (6.4e-5 USDC), far below any real staker. **COMPLIANT** — `depositFor` never reverts.

---

## 3. Have other problems surfaced because of it?

Three cluster-level hazards are reachable through leg2 but each is a recurrence of an issue whose canonical entry point is elsewhere. They are recorded here for reachability and are **tracked (not re-reported) at their canonical entry points**:

- **Gather off-by-one (LEG1-02) — canonical YS-04 (Low), entry point `migrate:ys-swap-leg1`.** `scripts/gather-migration-inputs.js --leg 2` treats the half-open `getStakersRange(token, start, end)` as inclusive (passes `Math.min(start+PAGE, count) - 1` as the exclusive end), dropping the last staker of each pool. Confirmed on-fork: gather wrote `count=2` (DOLA, expected 3) and `count=5` (USDC, expected 6), stranding `0x25AdA296…` (DOLA) and `0x0f254C40…` (USDC) — see `leg2-stakers.BUGGY-LEG1-02.json`. **The unmodified preview reverted fail-SAFE** at the count-equality preflight: `require(leg2DolaCount == onchainDolaCount)` → *"Preflight: stale DOLA staker count in leg2-stakers.json - re-run gather"* (2 != 3). LEG1-02 therefore cannot cause a silent partial leg2 migration — it forces a hard halt and a re-gather. The fork run proceeded only after regenerating `leg2-stakers.json` from full `getStakers()` membership (3/6); without that workaround the two dropped stakers would have remained on temp with no automated path back.

- **Count-only staleness guard — canonical YS-06 (Low, footgun), spans both legs.** The only freshness check on `leg2-stakers.json` is staker-*count* equality, which catches additions/removals but not a count-preserving membership swap (a withdraw-to-zero plus a fresh stake in the gather→broadcast window while the temp pool is still Active). A stale chunk would migrate a now-exited address (no-op) and miss the new joiner. This is self-fail-safing — the post-assert `tempStaker.stakerCount(token) == 0` fails fail-loud — but the guard is weaker than a set-membership hash. Narrow for leg2 since temp is a short-lived transit contract.

- **Non-idempotent broadcast / no resume path — canonical YS-13 (Low, footgun), `NonIdempotentBroadcastNoResume` family.** The broadcast variant uses `--skip-simulation` (a response to the story-055 RESUME stale-calldata incident). If a broadcast halts after `initiateMigration` but before all `migrate` chunks land (RPC drop, gas spike, Ctrl-C, chunk revert), the temp pools are left in terminal `PoolState.Migrating`; re-running the documented command reverts at `initiateMigration` (`require(poolState == Active)`) with no scripted resume. Funds are not lost (the migrate loop is per-user replay-safe and `userMigrate` exists as permissionless recovery), but the runbook command cannot finish a half-completed leg2 — the same failure class as story-055's `ResumeStableStakerMigration`. A resume-aware branch (read `poolState`; skip `initiateMigration` if already `Migrating`; proceed to the replay-safe migrate loop) is the fix shape.

**Fork fixups applied (none are leg2 script bugs):**
- `LEG1-02-workaround` — regenerated `leg2-stakers.json` to full 3/6 membership (input-gatherer bug YS-04, not a Leg2Migration bug; the script's preflight correctly fail-safed on the buggy input).
- `FX-1/FX-2` — V2 strategy patched `convertToAssets` bytecode, hot-swapped by predecessors, kept.
- `FX-3` — Chainlink ETH/USD aggregator mock from predecessors, kept. **No additional feed fixups were needed** — leg2's preview and broadcast ran with zero Tokemak / `InvalidDataReturned` / staleness reverts at blocks 25297397–25297401.

---

## Findings summary

| ID | Severity | Entry point | Status | Where tracked |
|---|---|---|---|---|
| YS-05 | Low | `migrate:ys-swap-leg2` | **Original here** | `findings/low/YS-05-leg2-redeposit-haircut.json` |
| YS-04 | Low | `migrate:ys-swap-leg1` | Recurs here | canonical at leg1 |
| YS-06 | Low | `migrate:ys-swap-leg1` | Recurs here (both legs) | canonical at leg1 |
| YS-13 | Low | `migrate:ys-swap-deploy` | Recurs here | canonical at deploy (no-resume family) |

No High or Medium findings at this entry point. The migration works correctly once the predecessors' fixes (notably the V2 `convertToAssets` patch and the regenerated staker input) are in place.
