# Script Review — `migrate:ys-swap-leg1`

**Script:** `script/SkimAndLeg1Migration.s.sol:SkimAndLeg1Migration`
**Entry point:** `migrate:ys-swap-leg1` (story-060 yield-strategy swap migration, step 2 of 5)
**Project:** phoenix-phase-2-staging @ `b27c6ac`
**Nested pins:** stable-staker `c3ec65b`, vault/reflax-yield-vault `ad12cb1`, phlimbo-ea `6cb0bc0`
**Verification:** fork preview + broadcast-equivalent against a persistent anvil fork of mainnet block 25297358 (step 1 pre-executed in blocks 25297359–25297374; leg1 executed 25297375–25297386)

---

## Verdict

The script's logic is faithful to its intent and, once unblocked, completes the leg-1 bounce losslessly — it correctly skims the three old strategies, injects the 60-USDC Phlimbo reward, and migrates all 9 stakers (3 DOLA + 6 USDC) from the original staker into the temp staker with a proportional `min(R,P)/P` haircut. **However, on a cold mainnet run the script is dead on arrival and cannot even produce a valid input snapshot.** The owner EOA is not an authorized withdrawer on any of the three strategies, so the very first mutating call (`skimSurplus`) reverts (`YS-02`), and the companion gather tool has a half-open/inclusive off-by-one that drops the last staker of every pool, making the staleness preflight permanently unsatisfiable (`YS-04`). Both are Low (clean fail-loud, no funds move, trivial fixes), but both are hard blockers of the runbook and `YS-04` recurs verbatim at leg2. Three further Low/QA items — a count-only staleness guard (`YS-06`), a skim-destination doc divergence leaving ~13.5 USDe orphaned (`YS-07`), and an undeclared `viem` dependency (`YS-19`) — round out the entry point. No High or Medium finding originates here.

To observe the intended end state at all, two out-of-band fork fixups were required, each standing in for a missing suite step:
1. **Regenerated `leg1-stakers.json`** from on-fork `getStakers()` (full 3/6 membership), working around the gather off-by-one (`YS-04`). The buggy as-gathered file (counts 2/5) is preserved at `/tmp/leg1-stakers-as-gathered.json`.
2. **`setWithdrawer(OWNER_ADDRESS, true)`** on all three strategies from the impersonated strategy owner — the real authorization function (`AYieldStrategy.setWithdrawer:309`, `onlyOwner`) — clearing the `skimSurplus` auth revert (`YS-02`).

---

## 1. Does it do what it intends?

Intent (`intent.md`, package.json `//ys-swap-migration`, `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md`): deployer-USDC preflight → skim all three old strategies → `PhlimboV2.collectReward(60 USDC)` → `initiateMigration` + chunked migrate of DOLA and USDC stakers from the original staker into the temp staker.

**With both fixups in place, every intended step executes and every post-condition holds.** The fork run (11 txs, blocks 25297375–25297386) reproduced the intended end state:

- **Deployer-USDC preflight (first, before prank/broadcast).** `IERC20(USDC).balanceOf(OWNER) == 99.075791 ≥ 60e6` — passes. The remaining preflight checks (`.migrator1 != 0`, original/temp `migrator() == migrator1`, `owner() == OWNER` on all three strategies + migrator1) all pass.
- **Skim all three old strategies → `ORIGINAL_STABLE_STAKER`.**
  - `YS_DOLA_OLD` (`0x90ce274b…`): **no-op skim** — the strategy is underwater (`totalBal 1033.692e18 < principal 1033.888e18`, the live story-060 bug that motivated the swap), so `skimSurplus` returns 0. Intended and correct.
  - `YS_USDC_OLD` (`0x90af002E…`): ~0.71 USDC surplus across two clients redeemed; principal untouched.
  - `YS_USDE` (`0xaC2e5936…`, the market strategy that is skimmed but **not** replaced): ~16.4 USDe surplus disposed via a slippage-guarded `sUSDe→USDe` AMM swap (minOut 16.366e18, received 16.409e18).
- **Phlimbo reward injection.** `USDC.approve(PHLIMBO_V2, 60e6)` then `PhlimboV2.collectReward(60e6)`: reward balance 23.45 → 83.28 USDC (accrual then +60), canonical rate recompute; the exact-approve allowance is fully consumed (no residual). Owner USDC 99.08 → 39.08.
- **`initiateMigration` (DOLA then USDC).** Terminal snapshots taken: DOLA `R=1033.618871…e18 / P=1033.8878e18` (ratio 0.999740); USDC `R=1954.570705e6 / P=1954.7314e6` (ratio 0.999918). Both pools moved Active → Migrating, strategies decoupled.
- **Chunked migrate (1 chunk each at default size 50).** All 9 positions credited on the temp staker at exactly `p_i·min(R,P)/P` (spot-checked: OWNER 10e18 → 9997398862720444927 = `10e18·R/P` exact). Pending phUSD minted directly to the 7 distinct user wallets (payout 1 of 2 per the intent doc).
- **Post-conditions (asserted).** Original `stakerCount(DOLA)==0` and `stakerCount(USDC)==0`; temp staker holds **3 DOLA + 6 USDC stakers, 1033.618871…e18 DOLA + 1954.570701e6 USDC** (`R − 1 wei` / `R − 4` floor-rounding dust), token balances matching `totalStaked` exactly. Original-staker balances ≥ skimmed amounts (vacuous for DOLA since the skim was 0).
- **Broadcast-only persistence.** `.dolaSkimmed=0`, `.usdcSkimmed=532748`, `.usdeSkimmed=12306817967624337566` appended to `ys-swap-deployments.json`.
- **USDe pool untouched.** No `initiateMigration(USDe)`; stakers and `poolInfo` unchanged — skim only, as intended.

**Faithfulness conclusion: the implemented logic does what story-060 step 2 says.** The value-preservation model (proportional `(R,P)` socialization of realized loss) matches the doc; the ~0.026%/0.016% haircut is the correct conservative accounting (the only doc-faithfulness gap on the per-user accounting side belongs to leg2's fresh re-deposit, tracked as `YS-05`, out of this entry point's slice).

But the script does **not** do what it intends **on a cold mainnet run**, for two independent reasons, both fail-loud before any state mutation:

- **`YS-02` — dead on arrival (auth).** `skimSurplus` is `onlyAuthorizedWithdrawer` (`AYieldStrategy.sol:461-471`, modifier `:224-229`, `require(authorizedWithdrawers[msg.sender])`). The `authorizedWithdrawers` registry (`:32`) is separate from `owner`; the owner is never implicitly authorized, and the only grant path is `setWithdrawer` (`:309`, `onlyOwner`). On-fork, `authorizedWithdrawers[OWNER]==false` on all three strategies — the **only** authorized withdrawer is the post-`ReplaceSYAMainnet` SYA (`0x3C690EC3…`, wired by replace-sya step 12). No story-060 step grants the owner. The preflight checks `owner()` on all three strategies but **not** withdrawer status, so the failure surfaces only at execution. Empirical, unmodified script with valid inputs: `revert "AYieldStrategy: unauthorized, only authorized withdrawers"` at `IOldYS(YS_DOLA_OLD).skimSurplus(DOLA, ORIGINAL_STABLE_STAKER)` — the first mutating call of `run()`. In broadcast mode (`--skip-simulation --slow`) this is a real failed mainnet tx and the suite halts at step 2 of 5.
- **`YS-04` — no valid input snapshot.** Before fixup, the as-gathered `leg1-stakers.json` (counts 2/5) failed the staleness preflight: `revert "Preflight: stale DOLA staker count in leg1-stakers.json - re-run gather"`. Re-running gather is deterministically non-convergent (see §3).

---

## 2. Does it introduce unintended side effects?

With the fixups applied, the fork diff is overwhelmingly the intended set of writes. Three side effects are **not** stated in any story-060 intent and surfaced empirically:

1. **Skim proceeds go to the original staker, not the treasury (`YS-07`).** The intent doc (lines 133–135, 224–234) skims to `treasuryAddress` and reasons in its Post-Migration section about surplus "sitting at the treasury address as raw tokens." The script instead skims to `ORIGINAL_STABLE_STAKER`, relying on `ResetAndRewire`'s `setYieldStrategy` sweep to fold the idle balance into the V2 strategies as a principal buffer.
2. **~13.5 USDe orphaned.** That sweep plan only covers DOLA and USDC. The **USDe pool is never re-wired**, so the USDe proceeds observed on the fork — `+12.307 USDe` recipient share + `~1.186 USDe` staker buffer share ≈ **13.49 USDe net** — sit as unreserved idle balance on the staker indefinitely (`ORIGINAL_STABLE_STAKER.idleUSDe` 26.68 → 40.18). It is reachable only via a manual `StableStaker.rescueERC20` (`StableStaker.sol:808`) that **no suite step performs**.
3. **~$3 routed to the phUSD minter via old-bytecode per-client buffer routing.** The **deployed** old-strategy bytecode (pre-story-025) routes each client's 25% set-aside buffer to the client contract itself — observed: **0.152660 USDC + 2.916739 USDe transferred to the phUSD minter `0x435B0A18…`**. This differs from the pinned `ad12cb1` source (which sends the aggregate buffer to `setAsideBufferRecipient`; on the deployed contracts that selector reverts). Mentioned nowhere in story-060.

All three flows are **protocol-owned** (no user funds at risk), so this is a Low-severity doc-divergence footgun: protocol value scattered to unintended resting places, where doc-driven follow-ups (e.g. the doc's "re-inject from treasury" option) would target an address holding nothing. A competent operator following the doc would be surprised — Law-3 footgun, low value at current scale.

**Benign-by-design dust:** `1 wei DOLA + 4 units USDC` migrate-dust accrete to the original staker's idle balance from floor rounding — negligible and intended.

**Off-chain artifact note (no finding):** `usdeSkimmed` is written as a bare JSON number `> 2^53`. Today the sole consumer is Solidity `vm.parseJsonUint` (PostMigrationCleanup), so no precision loss; any future JS consumer using `Number` would corrupt it. Recorded for the cleanup auditor.

---

## 3. Have other problems surfaced because of it?

Auditing leg1 against its cluster surfaced two issues that reach beyond this entry point:

- **The gather off-by-one also breaks leg2 (`YS-04`, recurrence).** `gather-migration-inputs.js` computes `end = Math.min(start + PAGE_SIZE, count) - 1` (`scripts/gather-migration-inputs.js:271-284`) and passes it to `StableStaker.getStakersRange`, which is **half-open `[start, end)`** (`StableStaker.sol:662-678`, NatSpec is explicit). Every page silently loses its final element; with counts ≤ page size that is the last staker of each pool. On a quiescent fork (no concurrent txs possible): DOLA fetched 2 of 3 (dropped `0x25AdA296…`), USDC fetched 5 of 6 (dropped `0x0f254C40…`). The script then writes `count = fetched length` and prints a **misleading** `WARNING` blaming "stakers joined between reads" and advising a re-run — which can never converge because the bug is deterministic. SkimAndLeg1Migration's preflight requires that count to equal live `stakerCount`, so leg1 (preview **and** broadcast) reverts forever. **The same pager is reused for `--leg 2`** against the temp staker (3 DOLA + 6 USDC after leg1), so `Leg2Migration` inherits the identical block at step 4 — fixing the JS is a prerequisite for the second leg. Fail-safe today only by the accident of double-bookkeeping: had the script written the on-chain count instead of the fetched length, the preflight would pass and the dropped staker would be silently stranded.

- **The staleness guard is count-only — and the weakness spans both legs (`YS-06`).** The preflight compares only `.count` against live `stakerCount` (`SkimAndLeg1Migration.s.sol:146-157`); there is no set-membership / hash check. If one staker exits and another enters between the gather snapshot and the broadcast (counts equal, membership different), preflight passes, `batchMigrate` processes the stale list, the departed address yields amount 0 (skipped), and the new staker is never migrated. The `stakerCount==0` post-assert catches it — but in `--skip-simulation --slow` broadcast it fires only **after** all txs land: both pools are then in terminal `Migrating` state with one stranded staker, and re-running reverts at the one-shot `initiateMigration` (`StableStaker.sol:425`). Recovery exists (permissionless `userMigrate`, or a manual `migrator1.migrate(token,[missed])`) but is undocumented. The exposure window is short (stake/withdraw freezes once `initiateMigration` lands) and the probability is low at the 3/6-staker population — hence Low — but this repo has prior history of exactly this snapshot-vs-broadcast drift biting this staker slice (story-055 `ResumeStableStakerMigration` baked stale simulated deltas into calldata and halted at tx 21/59), and **the identical count-only gate guards leg2.**

- **Packaging blocker (`YS-19`, QA).** The mandatory gather prerequisite `require`s `viem`, which is absent from both `dependencies` and `devDependencies` in `package.json` (only `cors`/`express`; devDep `@wagmi/cli`). The script's own remedy — "Run `npm install`" — fails, mirroring `YS-04`'s misleading-guidance pattern. On a clean checkout the gather step cannot run at all, and leg1 hard-depends on its output — exactly the fresh, Ledger-signing environment a mainnet operation runs from. To run the audit at all, `viem` was installed ad hoc (`npm install --no-save viem`).

**Cluster context not raised as leg1 findings (carried at their own entry points):** the V2 strategies' `previewRedeem`-under-STATICCALL brick (F1) that will hit `ResetAndRewire`/leg2 is `YS-01`; the SYA-not-rewired yield-collection leak is `YS-03`; the buffer-percent stale config is `YS-08`; the `--skip-simulation` mid-suite reset halt is `YS-09`. Leg1 itself never touches the V2-strategy `_acquireShares` path (the temp staker has no strategy), so F1 does not manifest here.

---

## Findings at this entry point

| ID | Severity | Title | Source location |
|----|----------|-------|-----------------|
| `YS-02` | Low (footgun) | Owner not an authorized withdrawer → leg1 reverts at first mutation | `script/SkimAndLeg1Migration.s.sol:196-200` (skim), `:126-138` (preflight); root cause `lib/vault/src/AYieldStrategy.sol:461-471`, `:224-229`, `:309` |
| `YS-04` | Low (footgun) | gather off-by-one half-open range → permanent count-preflight DoS (leg1 + leg2) | `scripts/gather-migration-inputs.js:271-284`; semantics `lib/stable-staker/src/StableStaker.sol:662-678` |
| `YS-06` | Low (footgun) | Count-only staleness guard → equal-count membership drift strands a staker | `script/SkimAndLeg1Migration.s.sol:146-157`, `:269-278`; `lib/stable-staker/src/StableStaker.sol:425` |
| `YS-07` | Low (footgun, faithfulness) | Skim destination doc-drift + ~13.5 USDe orphaned + ~$3 to phUSD minter | `script/SkimAndLeg1Migration.s.sol:196-201` vs `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md:133-135,224-234`; `StableStaker.sol:808` |
| `YS-19` | QA (footgun) | `viem` undeclared in `package.json` → mandatory gather step cannot run from a clean checkout | `scripts/gather-migration-inputs.js:130-136`; `package.json` deps |

Finding records:
- `reports/phoenix-phase-2-staging/12/findings/low/YS-02-deployer-not-authorized-withdrawer.json`
- `reports/phoenix-phase-2-staging/12/findings/low/YS-04-gather-offbyone-half-open-range.json`
- `reports/phoenix-phase-2-staging/12/findings/low/YS-06-snapshot-vs-broadcast-membership-drift.json`
- `reports/phoenix-phase-2-staging/12/findings/low/YS-07-skim-destination-doc-divergence.json`
- `reports/phoenix-phase-2-staging/12/findings/qa/YS-19-missing-dependency-declaration.json`

Cross-leg recurrence: `YS-04` recurs at `migrate:ys-swap-leg2` (same pager, `--leg 2` against the temp staker); `YS-06`'s count-only gate applies across both legs. Both should be fixed before any mainnet broadcast of step 2 or step 4.

---

## Recommended fixes (consolidated)

1. **`YS-02`:** inside the broadcast block, before the skims, call `IOldYS(ys).setWithdrawer(OWNER_ADDRESS, true)` for all three strategies (the strategies' owner is the same signing EOA — no extra signer needed), optionally revoking after; and add a preflight `require(authorizedWithdrawers(OWNER_ADDRESS))` so the script refuses to broadcast into a guaranteed failure.
2. **`YS-04`:** use the half-open convention — `const end = Math.min(start + PAGE_SIZE, countNum); … start = end;`. Make the fetched-vs-count mismatch fatal (exit non-zero) instead of a warning, and cross-check against `getStakers()` for small counts. Apply identically to `--leg 2`.
3. **`YS-06`:** have gather also store `keccak256` of the sorted staker list and recompute it on-chain in preflight, or read `getStakers()` directly inside the script (counts are tiny). Document the `userMigrate`/manual-batch recovery in the runbook.
4. **`YS-07`:** correct the migration doc's skim destination and sweep accounting; add an explicit cleanup step that `rescueERC20`s the idle USDe to the intended treasury; document or zero the minter-side buffer receipts.
5. **`YS-19`:** add `viem` (pinned) to `package.json` `dependencies`.
