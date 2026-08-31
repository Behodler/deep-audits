# Script Review — `migrate:ys-swap-reset`

**Project:** phoenix-phase-2-staging · **Submodule HEAD:** `b27c6ac` · **Story:** [story-060] yield-strategy swap (June 12 2026)
**Entry point:** `package.json` → `migrate:ys-swap-reset` (step 3 of 5)
**Forge target:** `script/ResetAndRewire.s.sol:ResetAndRewire` (entry `run`, `setUp` guard `block.chainid == 1`)
**Broadcast chain:** `node scripts/backup-mainnet-addresses.js` → `forge script ... --broadcast --skip-simulation --slow --ledger` → `node scripts/patch-mainnet-addresses-ys-swap.js`
**Signer:** Ledger, HD path `m/44'/60'/46'/0/0`, expected owner `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6`
**Fork verification:** persistent anvil mainnet fork @ block 25297358 (shared with steps 1–2); this entry advanced the fork through step 3 for the leg2 auditor.

---

## Verdict

`ResetAndRewire` is **faithful in isolation** — given working V2 strategies it does exactly what story-060 step 3 intends (revive both drained pools, wire the V2 strategies, sweep idle balances, arm `migrator2`), and on the fork it produced **zero unintended state writes** and a patcher that rewrites exactly the two registry fields it is supposed to. But this entry is where the suite's upstream brick **lands on-chain**: the strategies as actually deployed make `setYieldStrategy`'s idle-sweep `deposit()` revert (upstream YS-01 / F1), and because the broadcast runs with `--skip-simulation` over a **non-idempotent, non-atomic** sequence, the real-mainnet run will succeed on tx1/tx2 (both `finalizeAndReset` calls), then halt at tx3 — leaving both pools revived-`Active` with **no strategy wired, unpaused, and not re-runnable** while 9 users sit parked in the temp staker. That amplification is the headline Medium (**YS-09**). To audit the rest of the suite past the brick, three documented fork fixups were applied (the doc-prescribed `convertToAssets` patch, `anvil_setCode` of the patched bytecode onto the live V2 strategies, and a fresh-Chainlink-aggregator mock to defeat fork-aging staleness); none of these are source fixes.

Findings at this entry point: **YS-09 (Medium)**, **YS-15 / YS-16 / YS-17 (Low)**. Known-issue compliance: `ss9l1` avoided in the happy path, `story-010` compliant, `ss9m7` compliant.

---

## 1. Does it do what it intends?

**Stated intent** (`package.json //ys-swap-migration`, `ResetAndRewire.s.sol` NatSpec, `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md`, [story-060]): on the original StableStaker `0xbce8…079A`, `finalizeAndReset(DOLA)` + `finalizeAndReset(USDC)` to revive both fully-drained pools `Migrating → Active`; `setYieldStrategy` the two new story-048-fixed `ERC4626YieldStrategy` V2 instances (sweeping the idle base-token balance into them); and `setMigrator(migrator2)` on **both** stakers to arm the return leg. The USDe pool is deliberately untouched. The JS pre-wrapper snapshots `server/deployments/mainnet-addresses.ts`; the post-wrapper surgically rewrites exactly two fields.

**On the fork (after the fixups in §2), every intended action fired** — broadcast-equivalent log and `side-effects.json.executed`:

| tx | target | call | result |
|----|--------|------|--------|
| 1 | StableStaker `0xbce8…079A` | `finalizeAndReset(DOLA)` | `0x1` — `Migrating → Active`, `(R,P)` snapshot cleared, `lastRewardTime` fast-forwarded (no retro-accrual) |
| 2 | StableStaker | `finalizeAndReset(USDC)` | `0x1` — same |
| 3 | StableStaker | `setYieldStrategy(DOLA, ysDolaV2)` | `0x1` — strategy `0x0 → 0xc4D5…c7c7`; idle **26.785 DOLA** swept |
| 4 | StableStaker | `setYieldStrategy(USDC, ysUsdcV2)` | `0x1` — strategy `0x0 → 0x0C2d…6a8a`; idle **27.234 USDC** swept |
| 5 | tempStaker `0xAb51…6EC1` | `setMigrator(migrator2)` | `0x1` — `migrator1 → migrator2` |
| 6 | StableStaker | `setMigrator(migrator2)` | `0x1` — `migrator1 → migrator2` (no residual authority for migrator1 on either staker) |

Declared pre-conditions all held on the fork: `chainid==1`; the four leg1-completion drift guards (`stakerCount==0 && totalStaked==0` for DOLA and USDC); `original.migrator() != 0`; and the three ownership checks (`migrator2`, `tempStaker`, `original` all owned by OWNER). Declared post-conditions all passed: the two-sided buffer bounds `principalOf <= idleSwept` and `> 0` for both tokens, and `totalStaked == 0` on both reset pools.

**The idle sweep behaves exactly as story-060 designed** — but note *who* it credits. The swept skim-surplus/migration-residue is folded into the V2 strategies as `clientBalances[token][staker]`, i.e. an **unattributed (no-user) principal buffer owned by the original staker itself**: 26.778 DOLA (haircut ~0.026%) and 27.229 USDC (haircut ~0.016%), the small shortfalls consistent with conservative `convertToAssets` crediting. This is intended (commit `71c545c` lineage) but it directly contradicts the doc's stated post-condition of `principalOf == 0`, recorded as **YS-17**.

**The JS wrappers conform.** `backup-mainnet-addresses.js` snapshotted to `server/deployments/mainnet.backup.2026-06-12_02-26-58-024.ts` before broadcast. `patch-mainnet-addresses-ys-swap.js` rewrote **exactly two fields** — `YieldStrategyDola` (`0x90ce274b… → 0xc4D5F377…`) and `YieldStrategyUSDC` (`0x90af002E… → 0x0C2d7516…`) — plus one header comment line; `StableStaker` and `YieldStrategyUSDe` were verified untouched by diff.

**Verdict (Q1): faithful.** In isolation the script and its wrappers do precisely what story-060 step 3 prescribes. The only intent-divergence is the documentation-level `principalOf` disagreement (YS-17, Low).

---

## 2. Does it introduce unintended side effects?

**On the fork, after fixups: zero unintended writes** (`side-effects.json.unintendedEffects: []`). Every entry in `stateWrites` is intended:

- `poolState[DOLA]` / `poolState[USDC]`: `Migrating → Active`.
- `migrationInfo[DOLA]` `(1033.6e18, 1033.9e18) → (0,0)`; `migrationInfo[USDC]` `(1954.57e6, 1954.73e6) → (0,0)`.
- `lastRewardTime` fast-forwarded `1781220572/573 → 1781230449` (no retro-accrual — this is the missing-reconfig companion `ss9l1` prescribes).
- `yieldStrategy[DOLA/USDC]`: `0x0 →` the two V2 addresses.
- DOLA/USDC `allowance[staker][V2] → type(uint256).max` — **unlimited approval is `setYieldStrategy`'s documented design** (flagged in YS-15 as a hardening gap, not a defect here).
- Idle base balances swept to `0`; credited as the unattributed `clientBalances` buffers above.
- `migrator` on both stakers `migrator1 → migrator2` (single-slot overwrite, migrator1 left with no authority).
- Tokemak autoDOLA/autoUSDC share mints + NAV accounting — the expected externality of `strategy.deposit`.

The USDe pool was confirmed untouched (`Active`, its own strategy, ~40.18 USDe left idle on the staker as benign extra withdraw liquidity). Emission rates `phusdPerSecond` are **not** reset by `finalizeAndReset` (5/7 phUSD/day carry over) — this is the `ss9l1` surface, but consistent with story-060's restore-identical intent, so not a violation in the happy path.

**The patcher's footprint is exactly 2 fields** (see §1). No on-chain side effect from the JS chain beyond the file rewrite.

### Fork fixups applied to reach this state (none are source fixes)

The script could not be audited past tx3 against the code/state as-is. Three fixups were applied to the **workspace** copy and the fork only — the read-only `lib/` tree was never modified:

- **FX-1** — `lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol:113`: `creditedPrincipal = vault.previewRedeem(sharesReceived)` → `vault.convertToAssets(sharesReceived)`, the doc-prescribed fix. Workspace nested-submodule copy only, commented in-source as `AUDIT FORK-FIXUP`.
- **FX-2** — `anvil_setCode` of the patched runtime bytecode onto the two **live** V2 strategies (`ysDolaV2 0xc4D5…c7c7`, `ysUsdcV2 0x0C2d…6a8a`), sourced from fresh reference deploys with identical constructor args so embedded immutables match; storage preserved (`authorizedClients(original)=true`, `setAsideBufferSize=10` intact). *Disclosed incident:* a first attempt set-code'd **empty** bytecode onto both addresses for a few seconds before being restored with the correct patched bytecode; storage was never touched and no suite-relevant state was perturbed.
- **FX-3** — Chainlink ETH/USD aggregator behind proxy `0x5f4eC3Df…` set-code'd with a `FreshAgg` mock returning the **same last real price** with `updatedAt = block.timestamp - 60`. This is a **fork-aging artifact, not a script bug**: anvil mines at wall-clock while the feed froze at fork time (~233 min stale), tripping Tokemak's ChainlinkOracle staleness window on direct anvil txs. The forge preview (executing at fork-block timestamp, ~75 min age) passed without it; on real mainnet the feed is fresh.
- **FX-4** — the 1-token smoke deposits validating FX-1..FX-3 were run under `evm_snapshot` and reverted (DOLA credited −0.0262%, USDC −0.0158% — `convertToAssets` accounting works as story-048 intends).

**Verdict (Q2): no unintended side effects.** With the brick neutralized for audit purposes, the script writes only intended state and the patcher rewrites only the two registry fields. The unattributed staker-owned buffer is intended but doc-divergent (YS-17).

---

## 3. Have other problems surfaced because of it?

**This is where the suite's brick lands on-chain — and `--skip-simulation` turns a free preflight catch into a half-configured mainnet system.**

### The unmodified preview reverts mid-suite (root cause: YS-01)

With the strategies and `ERC4626YieldStrategy.sol:113` **as actually deployed**, the unmodified fork preview (`PREVIEW_MODE=true forge script ... -vvvv`, `unmodified-preview.log`):

- `finalizeAndReset(DOLA)` and `finalizeAndReset(USDC)` **both succeed first** — so by the time the revert hits, **the pools are already reset to `Active`**.
- The run then reverts at **`ResetAndRewire.s.sol:201`** — the first `setYieldStrategy(DOLA, ysDolaV2)`. The revert chain:
  1. `StableStaker.setYieldStrategy(DOLA, …)` → idle-sweep branch
  2. → `ysDolaV2.deposit(DOLA, 26785198715928544274, staker)` (strategy deposit *inside* the staker's sweep — not a script-level call)
  3. → `ERC4626YieldStrategy._acquireShares`: `vault.deposit(...)` succeeds (22.93e18 shares minted)
  4. → **`ERC4626YieldStrategy._acquireShares:113`** `vault.previewRedeem(sharesReceived)` issued as a **STATICCALL** to autoDOLA `0x79eB…A54d`
  5. → Tokemak `AutopoolETH.previewRedeem` performs a **non-static internal write** (withdrawal-queue simulation, selector `0x5917e2a6`) → **`StateChangeDuringStaticCall`**, bubbled to forge as an empty-revert script failure.

`ysUsdcV2` would fail identically (autoUSDC is the same implementation); DOLA is simply hit first. Top-level `eth_call previewRedeem` succeeds (no static frame), which is why off-chain checks and the committed preview JSON never caught it. The root cause is the upstream deploy-entry finding **YS-01** ([`ERC4626YieldStrategy.sol:113`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L113)); it is *referenced, not duplicated* here.

### YS-09 — `--skip-simulation` + non-idempotent sequence amplifies the brick into a mid-suite mainnet halt (Medium · THE headline)

**Finding file:** `findings/medium/YS-09-skip-simulation-non-resumable-broadcast.json`
**Source:** [`package.json:219`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/package.json#L219) (`--skip-simulation`); [`ResetAndRewire.s.sol:185-205`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/ResetAndRewire.s.sol#L185-L205)

The broadcast entry runs `--skip-simulation --slow`, so forge sends txs **one-by-one with no pre-broadcast bundle simulation**. On the real mainnet target vaults the YS-01 brick is deterministic, so the run:

1. executes tx1 `finalizeAndReset(DOLA)` and tx2 `finalizeAndReset(USDC)` **successfully**, then
2. **halts at tx3** `setYieldStrategy(DOLA, ysDolaV2)` with an on-chain reverted transaction.

The resulting halt-state is **partial, non-atomic, and non-idempotent**: both pools revived `Active` with `yieldStrategy == address(0)`, migrator still `migrator1`, idle 26.785 DOLA + 27.234 USDC unswept, and **9 users (1033.6 DOLA + 1954.57 USDC) parked yield-less** in the temp staker. The entry point is **not re-runnable**: `finalizeAndReset` requires `PoolState.Migrating` (`StableStaker.sol:594`), so tx1 reverts `pool not migrating` on every retry — and under `--skip-simulation` each retry **burns another reverted mainnet tx** before the operator learns this.

Worse, the halt window is **publicly exposed and griefable**: neither staker is paused (`paused()==false` verified) and `stake()` on an `Active` strategyless pool succeeds via the idle-hold path. Any deposit — innocent stake or a **1-wei grief** — sets `totalStaked > 0` and **re-locks `setYieldStrategy` behind the story-010 empty-pool gate** (`StableStaker.setYieldStrategy:228`), forcing a full second terminal-migration cycle just to wire replacement strategies. A default forge simulation (no `--skip-simulation`) would have simulated the 6-tx bundle, hit the tx3 revert, and **refused to send anything** — zero on-chain damage.

- **Cross-link YS-09 ↔ YS-01 ↔ YS-13:** YS-01 is the vault-call brick (root cause, Medium, deploy entry); **YS-09** is the reset-entry **script-level amplification** (Medium — *most severe halt*: mid-suite, on-chain, after users parked, gate-relock griefable); **YS-13** is the deploy/leg2 non-idempotent-no-resume family (Low). Same brick consequence, three distinct root-cause classes — deliberately **not** merged.
- **Cross-link YS-09 ↔ ss10l1** (stable-staker ledger, L-01 `787e9fac…`): `ss10l1` is the **standing contract property** (dust-stake grief of the empty-pool gate); **YS-09** is the **script defect that exposes that gate-relock window mid-broadcast**. Distinct — cross-link only, not a duplicate.

**Severity:** Medium. No direct asset theft and principal remains recoverable, so not High; but a part-way mainnet halt after funds were moved is materially worse than a clean atomic revert, and the gate-relock is a cheap permissionless griefing surface.
**Fix shape:** drop `--skip-simulation`; make the script resumable (skip `finalizeAndReset` when already `Active`, skip `setMigrator` when already set); pause both stakers for the migration window; run the preview against live mainnet as a hard runbook gate immediately before broadcast (it demonstrably catches the brick).

### YS-15 — no on-chain strategy-identity preflight; unlimited approval granted before any compatibility check (Low)

**Finding file:** `findings/low/YS-15-missing-strategy-identity-preflight.json`
**Source:** [`ResetAndRewire.s.sol:98-149`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/ResetAndRewire.s.sol#L98-L149) (`_globalPreflight`)

`_globalPreflight` checks only that `ysDolaV2`/`ysUsdcV2` are **non-zero** in the mutable `script/migration-inputs/ys-swap-deployments.json`. It never verifies on-chain that the addresses (a) have code, (b) `vault()` is the expected autoDOLA/autoUSDC, (c) `underlyingToken()` matches the pool token, or (d) `authorizedClients(ORIGINAL_STABLE_STAKER) == true` — the doc's own "Wire" checklist item that, if missed in step 1, makes tx3 revert `AccessDenied` mid-suite with exactly the half-configured halt shape of YS-09. `setYieldStrategy` also grants an **unlimited token approval before the first compatibility check executes**. Address drift in this file is not hypothetical: the closure manifest documents a preview-derived address (`0x190cBd59…`) colliding with live foreign mainnet code, and the JSON is a build artifact rewritten by step 1. No loss was demonstrated (all fork values were correct). **Fix:** add per-strategy `code.length > 0`, `vault()`/`underlyingToken()`, and `authorizedClients(original)` asserts to preflight.

### YS-16 — `PREVIEW_MODE` env leak makes the broadcast a no-op that still patches the registry (Low)

**Finding file:** `findings/low/YS-16-preview-mode-env-leak-patches-registry.json`
**Source:** [`ResetAndRewire.s.sol:174-183`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/ResetAndRewire.s.sol#L174-L183); [`package.json:219`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/package.json#L219)

Mode is selected by an **environment variable, not a CLI fact**: `isPreview = vm.envOr("PREVIEW_MODE", false)`. If `PREVIEW_MODE=true` is still exported in the operator's shell (highly plausible — the runbook has them run the `*-preview` entries first), `npm run migrate:ys-swap-reset` runs forge with `--broadcast` but the script takes the `vm.startPrank` branch, records **zero broadcastable transactions**, prints only `Warning: No transactions to broadcast`, and **exits 0** (empirically verified on the fork). The `&&` chain then runs `patch-mainnet-addresses-ys-swap.js`, which **unconditionally rewrites** `YieldStrategyDola`/`YieldStrategyUSDC` — so the off-chain registry claims the V2 strategies are live while mainnet is still `Migrating` with no strategies wired and migrator1 in place. **Fix:** pin `PREVIEW_MODE=false` in the package.json broadcast entry (one word), derive mode from `vm.isContext(ForgeContext.ScriptBroadcast)`, and have the patcher verify `original.yieldStrategy(DOLA) == ysDolaV2` on-chain before rewriting.

### YS-17 — doc / NatSpec / code 3-way post-condition disagreement (Low)

**Finding file:** `findings/low/YS-17-doc-natspec-code-postcondition-disagreement.json`
**Source:** doc "Step 3" (`principalOf == 0` expected); [`ResetAndRewire.s.sol:23-27`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/ResetAndRewire.s.sol#L23-L27) (header: `principalOf > 0`); [`ResetAndRewire.s.sol:231-239`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/ResetAndRewire.s.sol#L231-L239) (code: two-sided bound)

The intent doc instructs the operator to verify `principalOf(DOLA, original) == 0` — written **before** the decision (commit `71c545c` lineage) to park the skim surplus as idle balance and let `setYieldStrategy` fold it into the V2 strategies as an unattributed buffer. The script's NatSpec header says the opposite (`principalOf > 0`), and the code implements a third, correct, two-sided variant (`principalOf <= idleSwept && (idleSwept==0 || principalOf>0)`). Empirically the code is right (26.778 DOLA / 27.229 USDC, both `<=` swept and `> 0`). The risk: an operator cross-checking against the doc's `== 0` during a live broadcast would conclude the migration mis-fired — a false alarm, or training to ignore verification mismatches. No on-chain impact. **Fix:** update the doc's Step-3 verification to the swept-idle bound and align the script header with its own code.

---

## Known-issue compliance

- **`ss9l1`** (finalizeAndReset revival footgun, open Low) — **AVOIDED in the happy path.** The script is precisely the missing-reconfig companion `ss9l1` prescribes: `setYieldStrategy` is wired in the **same broadcast** immediately after `finalizeAndReset`, and the `lastRewardTime` fast-forward prevents retro-accrual. The emission-rate half (`phusdPerSecond` not reset) is consistent with the suite's restore-identical intent. **Residual:** in the YS-09 halt scenario the pools sit revived-`Active` with no strategy and stale emission config — `ss9l1`'s exact exposure, reachable mid-suite.
- **`story-010`** (`totalStaked == 0` gate on `setYieldStrategy`) — **COMPLIANT.** Preflight mirrors the gate off-chain and the on-chain `require` held (`totalStaked == 0` at both wire calls).
- **`ss9m7`** (no in-place YS swap on a strategy with staked users) — **COMPLIANT.** This is the prescribed full-migration pattern: both `YieldStrategySet` events show `oldStrategy == address(0)` (cleared by leg1 `initiateMigration`) and the pool was empty — no in-place drain branch executed, no staked users present.

---

## Evidence index (this directory)

`entry-manifest.json` · `closure-manifest.json` · `intent.md` · `side-effects.json` · `candidate-findings.json` · `unmodified-preview.log` (tx3 revert with tx1/tx2 succeeding) · `fixedup-preview.log` · `broadcast-equivalent.log` (all 6 txs `0x1` post-fixup).
Classified findings: `../../classified-findings.json` (filter `entryPoint == migrate:ys-swap-reset`). Per-finding records under `../../findings/{medium,low}/`.
