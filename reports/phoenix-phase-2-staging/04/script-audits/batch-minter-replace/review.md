<!--
Script review — batch-minter-replace (regression re-audit)
Project: phoenix-phase-2-staging
Run: phoenix-phase-2-staging-04
Mode: fork-preview, regression
Baseline: ebc2808043f6423b94856e5eaf2a65d62f0805ab
HEAD:     912a33db309386136a44478282ccfb1edf56dfad
Fork:     block 25208568 (RPC_MAINNET, chainId 1)
-->

# Script Review — `batch-minter-replace` (Story 050)

| Field | Value |
|---|---|
| **Project** | `phoenix-phase-2-staging` |
| **Entry point** | `script/ReplaceBatchNFTMinter.s.sol:ReplaceBatchNFTMinter` (Story 050) |
| **Run id** | `phoenix-phase-2-staging-04` |
| **Mode** | fork-preview, **regression re-audit** |
| **Baseline → HEAD** | `ebc2808` → `912a33d` |
| **Fork** | block `25208568` (RPC_MAINNET, chainId 1) |
| **Variant executed** | `preview` (`PREVIEW_MODE=true`, `vm.startPrank(OWNER)`); ran clean, no revert |

**Why this run was commissioned.** This is a **follow-up regression re-audit**, not a cold scan. The first audit (`phoenix-phase-2-staging-03`) raised two Medium findings against this one-shot cutover script:

- **BMR-M-02** — the proportional BPT exit passed `minAmountsOut = [0,0]` (unbounded slippage on the seed swap).
- **BMR-M-01** — the migration was *incomplete*: it repointed the funders but never re-enabled `SYA.nudgeSplit`, so the new minter would have been repointed but never funded.

The user applied two fixes and asked us to verify them. The entire closure delta between baseline and HEAD is a **single file** — `script/ReplaceBatchNFTMinter.s.sol` (+72/-7). No submodule gitlink moved (`nft-staking`, `stable-yield-accumulator`, `yield-claim-nft`, `flax-token-v2` all unchanged), no JS step changed, no contract source changed. Both fixes live entirely in the script. The job of this run is therefore narrow and concrete: **prove the two fixes are correct and complete, and confirm the fix did not introduce new problems.**

---

## 1. Does it do what it intends?

**Yes.** The Story-050 purpose chain is a single owner-signed mainnet broadcast that:

1. Re-deploys the fixed, minter-pinned `BatchNFTMinter(OWNER)` and configures it (`setTokenMinter(NFT_MINTER_V2)`, `setDispatcherIndex(4)`, `setNudgePaymentToken(USDC)`, `setNudgeSize(40)`).
2. Repoints the new minter's two real funders — `SYA.setNudgeAddress(newMinter)` (the `claim()`-path nudge recipient) and `BalancerPoolerV2.setBatchMinter(newMinter)` (the pooler batch-donation recipient).
3. Restores `SYA.setNudgeSplit(30)` (Fix B — see §2).
4. Seeds the new USDC nudge pot from the Balancer 50/50 phUSD/sUSDS BPT: a proportional exit yields sUSDS + phUSD, the sUSDS leg is swapped sUSDS→waUSDC→USDC into the pot via `SeedSwapHelper` (an aux contract deployed per run because an EOA cannot receive the Balancer V3 `unlock` callback), and the phUSD leg is burned.
5. Neutralizes the old exploited contract (`setNudgePaymentToken(0)`, `setNudgeSize(0)`), guarded by `require(USDC.balanceOf(OLD) == 0)`.

**Preview ran clean and every declared guard passed.** All **9 pre-conditions** (including the three new Fix-A guards: `EXIT_SLIPPAGE_BPS` in `(0, 10_000)`, `rawToks.length == 2`, `minAmountsOut[i] > 0` per leg) and all **5 post-conditions** (including the new Fix-B `SYA.nudgeSplit() == 30`) passed under the forked `OWNER` prank, and the preview did not revert.

**Closure summary.** Three on-chain targets are *mutated* by this entry point:

- `SYA` (`0x3bBE…606a`) — `nudge` set OLD → `newMinter`; `nudgeSplit` set `0` → `30`.
- `POOLER` / `BalancerPoolerV2` (`0x26F8…Edb38A`) — `batchMinter` set OWNER → `newMinter`; `49.88` BPT withdrawn to OWNER for the seed.
- `OLD_BATCH_MINTER` (`0x4ef0…41f3`) — nudge config zeroed (idempotent; already zeroed on-chain).

plus the freshly-deployed `newMinter`, and transient mutations to `PHUSD` (54.13 burned), the Balancer pool reserves (proportional exit), and `USDC` (50.42 seeded into the pot). `side-effects.json` records **`unintendedEffects: []`**.

---

## 2. Remediation verification

This is the heart of the follow-up. Both fixes are **verified fixed** empirically against the fork.

### Fix A — Slippage (BMR-M-02): VERIFIED FIXED

*Ledger fingerprint `3216feb8ce07ed5eefb06a02b2039eb22087907a1e042b270c8a47653683ee03` — transitioned open → fixed @ `912a33d`. Source: `ReplaceBatchNFTMinter.s.sol` `_seedFromBpt` (L418–L435).*

**Before.** The proportional exit was called with a hardcoded, unbounded floor:

```solidity
uint256[] memory minAmountsOut = new uint256[](2);
// minAmountsOut == [0, 0]  — accepts ANY output
router.removeLiquidityProportional(LP_POOL, bptSlice, minAmountsOut, false, "");
```

**After.** The floor is now computed per-leg from live Vault reserves and haircut by a 50 bps slippage knob, with a non-zero assertion on each leg:

```solidity
// EXIT_SLIPPAGE_BPS default 50; range-guarded at run() top: require(0 < bps < 10_000)
TokenInfo[] memory rawToks = vault.getPoolTokenInfo(LP_POOL);   // [sUSDS, phUSD]
require(rawToks.length == 2, "unexpected pool shape");
uint256 supply = IERC4626Min(LP_POOL).totalSupply();
for (uint256 i; i < rawToks.length; ++i) {
    uint256 expectedOut = rawToks[i].balanceRaw * bptSlice / supply;
    minAmountsOut[i] = expectedOut * (10_000 - EXIT_SLIPPAGE_BPS) / 10_000;
    require(minAmountsOut[i] > 0, "zero floor");
}
```

**Empirical evidence (fork @ block 25208568):**

- **Token order is index-consistent.** `getPoolTokenInfo` and `getPoolTokens` both return `[sUSDS, phUSD]`, and `amountsOut` from `removeLiquidityProportional` is indexed by the same `rawToks` ordering used to build `minAmountsOut` — leg-matching cannot transpose.
- **Denominator is correct.** `computeProportionalAmountsOut` uses `totalSupply()`; `getActualSupply()` *reverts* on this pool, so `totalSupply()` is the only and correct denominator. The computed `expectedOut(sUSDS) = balanceRaw * bptSlice / totalSupply = 46.0e18` matched the **actual** released sUSDS leg (`45.999…e18`) to the wei — denominator empirically correct and conservative.
- **Floor headroom is real.** The sUSDS leg released `46.0` against a floor of `45.77` (≈0.5% headroom); the phUSD leg released `54.13` against floor `53.86`. Both legs cleared their floors.
- **No rate-provider drift.** Both pool tokens are `STANDARD` (type 0) with `rateProvider == 0` — sUSDS is registered without a rate provider, so `balancesRaw == liveScaled balances` exactly and there is no scaling gap that a 50 bps floor could miss. 50 bps is adequate: a proportional exit is fee-free and exact.
- **No brick risk.** The `require(minAmountsOut[i] > 0)` guard only trips on dust pools far below current reserves (~`1.3e22` reserves, ~`5e19` bptSlice → ~`4.6e19` per leg). Not reachable at realistic state.

**Verdict:** the proportional exit is now correctly bounded; no sandwich/MEV exposure on the cutover seed. **Fixed.**

### Fix B — Incomplete script (BMR-M-01): VERIFIED FIXED

*Ledger fingerprint `f474129a96ee602a6b66acaf7fcd6cdd18aca2d4836cff80122bbb5aa0811b2a` — transitioned open → fixed @ `912a33d`. Source: `ReplaceBatchNFTMinter.s.sol` `_repoint` (L381–L389).*

**Before.** `_repoint` set the nudge *address* but left `nudgeSplit` at the incident-zeroed `0`, so `SYA.claim()` would route `0%` of the payment to the new minter — the pot was repointed but never funded:

```solidity
ISYANudge(SYA).setNudgeAddress(newMinter);
// nudgeSplit left at 0  — claim() funds the new minter with NOTHING
IBalancerPoolerV2Min(POOLER).setBatchMinter(newMinter);
```

**After.** The split is restored, in the load-bearing order, with a post-condition:

```solidity
ISYANudge(SYA).setNudgeAddress(newMinter);     // MUST precede setNudgeSplit
ISYANudge(SYA).setNudgeSplit(30);              // SYA_NUDGE_SPLIT
require(ISYANudge(SYA).nudge() == newMinter, "nudge repoint failed");
require(ISYANudge(SYA).nudgeSplit() == 30, "SYA nudgeSplit restore failed");
```

**The ordering is load-bearing and correct.** `SYA.claim()` reverts `NudgeNotConfigured` when `nudgeSplit > 0 && nudge == 0`. Calling `setNudgeAddress(newMinter)` *before* `setNudgeSplit(30)` ensures `nudge` is non-zero by the time the split is positive; no `NudgeNotConfigured` revert was observed on the fork.

**Empirical evidence (fork @ block 25208568):**

- After the script alone, `SYA.nudge == newMinter` and `SYA.nudgeSplit == 30` (was `OLD` / `0` at the fork head).
- **Funding is genuinely complete, not just configured.** `SYA.claim()` computes `nudgeAmount = actualPayment * nudgeSplit / 100` and routes it via a plain `IERC20(rewardToken = USDC).safeTransfer(nudge = newMinter)`. The nudge recipient requires **no further authorization** — an unauthenticated `safeTransfer` lands the USDC share directly. With the split restored to `30` and `nudge == newMinter`, the claim path now genuinely funds the new minter (it funded it `0%` before the fix).

**Verdict:** the migration is no longer half-cutover on the SYA funding path. **Fixed.**

---

## 3. Have other problems surfaced? (knock-on / cluster)

### Half-cutover hypothesis — INVESTIGATED and DISPROVEN at this block

A natural worry from the cluster was that `ReplaceBatchNFTMinter` repoints `POOLER.batchMinter` but does **not** run the sibling `SetMinterOnIndex4Pooler` step (Story 048 follow-up, noted "skipped" in the cutover) — leaving the pooler donation path unauthorized for the new minter and producing a *different* half-cutover. We checked this directly and it does not hold at HEAD:

- `POOLER._minter` (storage slot 1) reads `0x39Af…E10F == NFT_MINTER_V2` on the fork — the authorization `SetMinterOnIndex4Pooler` would set is **already applied** on-chain.
- A fork test (`test_poolerDonationFundsNewMinter`) ran **40 index-4 mints** plus `pool()`; dispatch did **not** revert `caller is not minter`, and it delivered **111.002464 USDC** to the new minter.

The pooler donation funding path is therefore complete after **this script alone** at this block; no separate `setMinter` is required for this entry point. Stated explicitly so the user knows it was checked and cleared.

### No unintended on-chain side effects

`side-effects.json` records `unintendedEffects: []`. Every observed state write maps to a declared step of the intent; every emitted event is intended.

### New observation considered and DROPPED — missing chainid guard

During this review we noticed the script has **no `require(block.chainid == 1)` guard**, unlike the sibling `SetMinterOnIndex4Pooler` (which carries one). Mainnet targeting relies solely on `--rpc-url $RPC_MAINNET`, and all addresses are hardcoded mainnet constants. We **evaluated and dropped** this as a reportable finding: it is an operator-mistake / known-invalid class (reckless-admin / wrong-RPC operator error), the broadcast is owner-signed via Ledger, and on a wrong chain the hardcoded constants would simply not resolve to live contracts. It is worth noting only as a cluster-consistency nit (the repo's own convention guards sibling scripts), not as an H/M/L. Not carried into the ledger.

### Two pre-existing lows remain LIVE and untouched by this fix

Both were first raised in `phoenix-phase-2-staging-03`, were **not** touched by the `ebc2808..912a33d` diff, and remain live at HEAD. They are carried forward (not re-reported) with their run-03 detail; the user should treat them as known operational caveats and remediate at convenience.

- **BMR-L-01 — Griefable retire guard.** *Fingerprint `22fc436d9483c95c1462e3775839e6da2ac3757ffd86155d587ad9a0d96791fe`. Source: `_retireOld` (L483–L491). First seen `phoenix-phase-2-staging-03`.* The retire step asserts `require(USDC.balanceOf(OLD_BATCH_MINTER) == 0)` inside the single broadcast tx, **after** the irreversible repoint and BPT seed. Any third party can front-run the broadcast with a 1-wei USDC transfer to `OLD_BATCH_MINTER` to make this `require` revert. Because the broadcast uses `--skip-simulation`, the revert is not caught pre-flight; the whole tx reverts on-chain. The rollback is atomic (no stuck half-state), but the owner-signed Ledger broadcast is wasted and must be retried — and is repeatably griefable. OLD's USDC balance is `0` at block 25208568, so the guard passes today, but the grief window is unchanged from baseline. *Recommendation:* replace the equality assert with a defensive sweep of any residual USDC from OLD, or gate it against a small dust threshold, or move neutralization to a separate idempotent tx.
- **BMR-L-02 — Seed not asserted against pot delta.** *Fingerprint `7e3bd86b09aa39f1b6f0b08c9e2da036b2e92aed31f748c49cfa166949c4f72f`. Source: `_seedFromBpt` / `_postflight` (L452–L459). First seen `phoenix-phase-2-staging-03`.* The USDC floor is enforced only inside `SeedSwapHelper` (`MIN_USDC_OUT = 47.0`) and `usdcOut` is measured as a balance delta, but there is no **script-level** post-condition tying the seeded amount to the intended ~50 USDC target — no upper bound, no tie to `SEED_USDS_TARGET`. A mis-calibrated or stale fork-tuned constant could over-drain the BPT or under-fund the pot silently within the broad `47.0` floor. Fork-observed seed was `50.418681` USDC (above floor), so it is correct today. *Recommendation:* add a script-level band assertion on `usdcSeeded` (lower **and** upper bound derived from `SEED_USDS_TARGET`), and re-tune the calibration constants against a fresh fork before broadcast.

---

## Closing

**Bottom line: both audited fixes are correct and complete.** Fix A (BMR-M-02) bounds the proportional BPT exit with index-consistent, denominator-correct per-leg floors and was confirmed against the actual released legs to the wei; Fix B (BMR-M-01) restores `SYA.nudgeSplit = 30` in the load-bearing order and the new minter is now genuinely funded through `SYA.claim()`'s unauthenticated `safeTransfer`. Both have been transitioned **open → fixed @ `912a33d`** in the ledger.

No new High or Medium issues surfaced. The half-cutover (pooler authorization) hypothesis was investigated and disproven at this block; the no-chainid observation was evaluated and dropped as operator-mistake noise. Two pre-existing lows (BMR-L-01 griefable retire guard, BMR-L-02 un-asserted seed delta) remain live, untouched by this fix, and are carried forward as known operational caveats.

**The migration is now safe to broadcast**, with those two residual lows as the only known operational caveats. All seed/swap/retire logic lives in `ReplaceBatchNFTMinter.s.sol` (`_seedFromBpt`, `_repoint`, `_retireOld`).

| Finding | Fingerprint | Source | Status @ `912a33d` |
|---|---|---|---|
| BMR-M-02 (slippage) | `3216feb8…3ee03` | `_seedFromBpt` (L418–435) | **fixed** (open → fixed) |
| BMR-M-01 (incomplete script) | `f474129a…11b2a` | `_repoint` (L381–389) | **fixed** (open → fixed) |
| BMR-L-01 (griefable retire) | `22fc436d…6791fe` | `_retireOld` (L483–491) | still-live (carryover) |
| BMR-L-02 (seed delta) | `7e3bd86b…c4f72f` | `_seedFromBpt`/`_postflight` (L452–459) | still-live (carryover) |
