# QA Report for phoenix-phase-2-staging, run 41 (script audit, entry point `unipooler-cutover`)

- **Project**: `phoenix-phase-2-staging` @ [`e75ee07`](https://github.com/Behodler/phoenix-phase-2-staging/tree/e75ee0776efcf20918b7db71d717eafb61bbd1a6) (`e75ee0776efcf20918b7db71d717eafb61bbd1a6`), branch `master`, read-only
- **Run**: `phoenix-phase-2-staging-41`, `/audit-script` on the npm entry point **`unipooler-cutover`** (`:preview` / `:broadcast` / `:verify`, story 103, sprint Balancexit)
- **Closure**: `script/DeployMainnetUniPoolerCutover.s.sol`, `script/VerifyUniPoolerCutover.s.sol`, `script/helpers/UniPoolerCutoverCore.sol`, `package.json` L76, plus `src/periphery/UniswapHelper.sol` (L-04). Nested `lib/yield-claim-nft` pinned at [`0fd6bdf`](https://github.com/Behodler/yield-claim-nft/tree/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630) (escrow, hook, BalancerPoolerV2).
- **Fork evidence**: mainnet block 26221713. Audit-authored tests (`test_r41_*`) live in the writable `work/` clone, not the upstream repo. Logs: `reports/41/script-audits/unipooler-cutover/logs/run41-forktests.log`.
- **Inputs**: `reports/41/findings/low/unipooler-cutover__L-01..L-04.json`, `reports/41/findings/qa/unipooler-cutover__Q-01..Q-03.json`, `reports/41/script-audits/unipooler-cutover/classified-findings.json`
- **Automated baseline**: [`4naly3er-report.md`](./4naly3er-report.md) (4 of 4 files analysed; no bot item rises to a finding).

> **Faithfulness is not in this file.** F-01 and F-02 for this run are in [`spec-conformance.md`](./spec-conformance.md).
> Q-02 and Q-03 carry a faithfulness facet; their full text is here, and spec-conformance cross-references them.
>
> **Labels are run- and entry-point-scoped.** This run's `L-01` (`pps41l1`) is not run-40 L-01 or run-39 L-01. Every
> reconciliation target is cited by its full ledger fingerprint.
>
> **Carryover QA is not merged here.** Earlier runs' open entries are in [`carryover/`](./carryover/) (`qa-report-39.md`, `qa-report-40.md`).

---

## Summary

| Severity | Count |
|----------|------:|
| High | 0 |
| Medium | 0 |
| Low Risk | 4 |
| QA | 3 |
| Centralization | 0 |
| **Total (this bundle)** | **7** |

**No Centralization findings.** The owner is trusted for knowing actions (Law 3), so no "a malicious owner could…" vector
is reported. Non-obvious owner footguns are in scope: **L-01** and **L-04** are tagged footguns.

No finding moves value out of protocol custody or lets a third party extract it. In every failure mode below the BPT stays in
the old pooler or the escrow, OWNER is never credited, and `abort()` or a re-quoted call recovers. The Lows are liveness
hazards on a one-shot migration under a hard deadline (Balancer pool pause on 30 Oct 2026).

| Label | issueId | Fingerprint | Reconciles with | Human review |
|---|---|---|---|---|
| L-01 | `pps41l1` | `8142ab6d393c295776e2e344246635fa2b3a62380f27bb364cd8cab8451d853e` | pps40 L-03 `85095591a60a…` (open) | **Yes** (borderline M) |
| L-02 | `pps41l2` | `01d60c7d1d494d0112fd31a66dd91b3bd746ca68cd55b45476cf0591d82ddde7` | ycn L-28 `d77a482de757…` (**fix-pending**) | No; **FIX-PENDING STILL LIVE** |
| L-03 | `pps41l3` | `4f454372eed28cd72780b588ac2c1e265b1dcd3e61a464326049cbcfa73b7169` | pps39 L-01 `9a694ae01fe1…` (open); discloses ycn L-26 (wont-fix) | **Yes** |
| L-04 | `pps41l4` | `a6764bb1edf199d5e2e887152b754fb3dabc56e6326d49f4bad53b2c6d9d4cd4` | pps40 L-02 `1d7e436f7dad…` (open) | No; **UNVERIFIED THIS RUN** |
| Q-01 | `pps41q1` | `c62a58a1a8f8687e432f42673afdbb2629e43f25767c6a223e18554a6b537eb4` | pps40 Q-01 `c8fb41a168e1…` (open) | No |
| Q-02 | `pps41q2` | `e2909097a253570554b172ae8052da95a17078cf07f0abb67fdebca0e8bb0032` | none (new) | No |
| Q-03 | `pps41q3` | `3da1655208b7dda10c7b11f6c2912907d18db206724cb15517280f390dd01522` | none (new) | No |

### Borderline: owner decision needed

| Finding | Question | Raise to Medium if... |
|---|---|---|
| **L-01** `pps41l1` | The index-4 mint outage window is 12 broadcast txs long and has no resume path. | ...the cutover is ever run unattended, or a halt could persist past a point where index-4 users have no alternative. |
| **L-03** `pps41l3` | A 1-wei synced donation bricks the cutover tooling. Same root cause as a ycn wont-fix. | ...the old pooler's index-4 dispatch or the RECOVERY exit is shown to fail while the cutover is blocked. |

---

## Low Risk Findings

### [L-01] Index-4 mints revert `OnlyDispatcher` for 12 broadcast txs (tx 8..19) between `hook.setDispatcher` and `replaceDispatcher`, and a halt inside that window has no resume path <!-- id: pps41l1 -->

- **Severity**: Low (footgun; flagged for human review, borderline Medium)
- **Entry Point**: `unipooler-cutover`
- **Fingerprint**: `8142ab6d393c295776e2e344246635fa2b3a62380f27bb364cd8cab8451d853e`
- **Reconciles with**: pps40 L-03 `85095591a60a255bbf6aea9f34526957ce4c921c2c5ef74c2e7c8111b58bd2fa` (phoenix-phase-2-staging, open). This is a still-open manifestation of the same root cause in this entry point, unchanged by story 103. Folds manual-review item MR-41-UPC-01 (ETH-balance halt cause).
- **Location**:
  - [`script/helpers/UniPoolerCutoverCore.sol#L337-L344`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L337-L344) (`_runCutover`)
  - [`lib/yield-claim-nft/src/hooks/BalancerPoolerMintDebtHook.sol#L109-L110`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/hooks/BalancerPoolerMintDebtHook.sol#L109-L110)
  - [`package.json#L76`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/package.json#L76) (`unipooler-cutover:broadcast`)

```solidity
// UniPoolerCutoverCore.sol L337-344
        _step8RepointHook(p, l);
        _afterStep(CUTOVER_STEP_REPOINT_HOOK, p, l, o);

        _step9ConfigurePooler(p, l);
        _afterStep(CUTOVER_STEP_CONFIGURE, p, l, o);

        _step10ReplaceDispatcher(p, l);
        _afterStep(CUTOVER_STEP_REPLACE_DISPATCHER, p, l, o);
```

```solidity
// BalancerPoolerMintDebtHook.sol L109-110
    function onDispatch(address minter, uint256 amount, bytes calldata) external {
        if (msg.sender != dispatcher) revert OnlyDispatcher();
```

**Description**: `_runCutover` runs step 8 (`hook.setDispatcher(UniPoolerV2)` = tx 7, then `UniPoolerV2.setHook` = tx 8), then step 9
(`setMinter`, `setPSM`, `setMaxTout`, `setBatchMinter`, `setBatchDonationSize`, 4x `setAuthorizedPooler`, `setNudgeStreamer` = txs 9..18),
then step 10 (`replaceDispatcher` = tx 19). `BalancerPoolerMintDebtHook.onDispatch` reverts `OnlyDispatcher` unless
`msg.sender == dispatcher`. Once tx 7 lands, the old pooler, which is still `configs(4).dispatcher`, can no longer dispatch, so
every index-4 mint reverts until tx 19 lands. Step 9 depends on neither the hook nor the index, so its 11 txs sit inside the
window for no reason.

With `--slow`, a Ledger confirmation per tx and the 0.3 gwei legacy default gas price, the window lasts minutes. If the session
halts inside it (Ledger disconnect, a gas spike above 0.3 gwei, a forge receipt timeout), `run()` offers no resume: a re-run
reverts POISONED, or reverts at step 0 with `index not on old pooler` / `hook not on old pooler`.

Folded halt cause (MR-41-UPC-01): if the operator raises `CUTOVER_GAS_PRICE_WEI` into the ~1.45-1.6 gwei band, the cumulative
cost plus 21k intrinsic gas per tx and the per-tx 2x-limit admission check exceed OWNER's 0.01303 ETH balance even though the
headline cost estimate fits. Forge then stops mid-session, most likely inside this window. A competent owner who checks
"estimated cost < balance" would be surprised by this, so it is a Law-3 footgun. (Gas-band figures are estimates from recorded
simulation gas, not fork-measured per-tx `eth_estimateGas`.)

**Impact**: Availability only. Index-4 NFT mints (the USDS mint) are DoS'd for the session window, and indefinitely after a
mid-window halt until the operator hand-sends the remaining txs from `run-latest.json` receipts. No funds at risk.

**Evidence**: Fork `test_r41_window_mintsRevertOnlyDispatcher`: a mint after step 7 succeeds; after steps 8 and 9 it reverts
`OnlyDispatcher()`. Tx order from the broadcast-mode state diff (`side-effects.json`, `logs/fullrun-statediff.log`).

**Recommendation**: Run step 9 (configure UniPoolerV2) before step 8 in `_runCutover`. The window then shrinks to `setHook` +
`replaceDispatcher` (2 txs). Optionally move `replaceDispatcher` immediately after `hook.setDispatcher` / `setHook`. In the
runbook, document a receipts-driven manual resume for txs 8..19 (exact `cast` commands).

Safe-config (folds MR-41-UPC-01): before `:broadcast`, either fund OWNER with at least (sum over all 24 txs of the 2x-estimate
gas limit, plus 21k intrinsic each) x `CUTOVER_GAS_PRICE_WEI` — a conservative upper bound on session spend, since each tx's gas limit
already carries the 200% multiplier (at the 0.3 gwei default about 0.006 ETH; above ~1.3 gwei the current
0.01303 ETH balance is insufficient), or add a preflight `require(OWNER.balance >= totalGasLimit * gasPrice)` evaluated before
tx 1, and print the computed figure in `:preview`. Do not raise `CUTOVER_GAS_PRICE_WEI` without re-running that check.

```solidity
        _step9ConfigurePooler(p, l);          // moved out of the window: touches neither hook nor index 4
        _afterStep(CUTOVER_STEP_CONFIGURE, p, l, o);

        _step8RepointHook(p, l);              // window opens (hook.setDispatcher)
        _afterStep(CUTOVER_STEP_REPOINT_HOOK, p, l, o);

        _step10ReplaceDispatcher(p, l);       // window closes
        _afterStep(CUTOVER_STEP_REPLACE_DISPATCHER, p, l, o);
```

---

### [L-02] Script does not mitigate ycn L-28: with 10 bps floors and a public-mempool `--slow` broadcast, a ~30 sUSDS swap (~$0.10 fee) between tx 4 and tx 5 reverts `exitAndSeed` <!-- id: pps41l2 -->

- **Severity**: Low
- **Entry Point**: `unipooler-cutover`
- **Fingerprint**: `01d60c7d1d494d0112fd31a66dd91b3bd746ca68cd55b45476cf0591d82ddde7`
- **Reconciles with**: yield-claim-nft L-28 (`ycn22l28`) `d77a482de757221d9ff311a43a46c11b40aa7df997199914fad7469d7128b209`, status **fix-pending**. This is a still-open manifestation of L-28 in this entry point.
- **FIX-PENDING STILL LIVE (owed, not delivered).** The owner triaged ycn L-28 fix-pending on 2026-10-10: *"The owner has noted the cheap mempool griefing of exitAndSeed and will handle it for the cutover."* That fix is **owed and not delivered**. Story 103 (auto-complete) contains no reference to L-28, the mempool, a private relay or MEV; its floors (default 10 bps, cap 50) address pool drift, not griefing. Because story 103 never claims to address L-28, this is not an INCOMPLETE FIX signal. L-28 stays fix-pending and must not be auto-closed. Its closeCondition (`successful mainnet unipooler cutover -> wont-fix (obsolete)`) applies only after a successful mainnet cutover.
- **Location**:
  - [`script/DeployMainnetUniPoolerCutover.s.sol#L402-L430`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L402-L430) (`_buildParams`)
  - [`package.json#L76`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/package.json#L76) (`unipooler-cutover:broadcast`)

```solidity
// DeployMainnetUniPoolerCutover.s.sol L402-407
    function _buildParams() internal view returns (CutoverParams memory p) {
        (uint256 minS, uint256 minP) = _minAmountsFromEnv();
        require(
            minS > 0 && minP > 0,
            "MIN_SUSDS_OUT_WEI and MIN_PHUSD_OUT_WEI must both be set and non-zero: eval \"$(node scripts/quote-balancer-exit-min-amounts.js 10)\""
        );
```

```json
"unipooler-cutover:broadcast": "... forge script script/DeployMainnetUniPoolerCutover.s.sol:DeployMainnetUniPoolerCutover --rpc-url $RPC_MAINNET ... --broadcast --skip-simulation --slow --ledger ..."
```

**Description**: The floors come from `quote-balancer-exit-min-amounts.js` (default 10 bps, max 50). The `:broadcast` key sends
every tx, including `escrow.exitAndSeed`, through the public mempool via `$RPC_MAINNET`. Nothing selects a private relay, and the
runbook never mentions one. Anyone watching OWNER's tx 4 (`withdrawBPT` to the escrow) can swap on the Balancer phUSD/sUSDS
pool so that the proportional phUSD out falls below its floor. Tx 5 then reverts in the Vault with `AmountOutBelowMin(phUSD)`.
At 10 bps the grief needs ~30 sUSDS (~$0.10 in the 0.30% pool fee); at the 50 bps cap it needs only ~160 sUSDS (~$0.53).

**Impact**: DoS of the cutover, repeatable on every retry at about $0.10-$0.53 per attempt. Custody is fail-safe: the BPT stays in
the escrow, OWNER is never credited, and `abort()` or a re-quoted `exitAndSeed` recover it. Not a loss. After 30 Oct the pool is
paused, which removes the swap vector and forces RECOVERY mode.

**Evidence**: Fork `test_r41_L28_griefCost_10bps` (20 sUSDS: no revert; 30/40/60 sUSDS: revert `AmountOutBelowMin(phUSD)`
`0x2f785e46`) and `test_r41_L28_griefCost_50bps` (120: no revert; 160/220: revert). Both also assert that after the grief the
escrow still holds 20401.809 BPT, OWNER holds 0, and a re-quoted `exitAndSeed` succeeds. Pool fee 0.30% (Vault
`getStaticSwapFeePercentage` = 3e15).

**Recommendation**: Send the broadcast session (at minimum tx 5) through a private relay (e.g. Flashbots Protect as `--rpc-url` for
`:broadcast`) and quote at 40-50 bps. Document in `//UniPoolerCutover` the resume after a griefed tx 5: re-quote on the escrow's
BPT and call `exitAndSeed` privately. Leave L-28 fix-pending until the cutover lands, then apply its closeCondition. Owed-fix
note: the owner's L-28 commitment is not reflected in story 103; either amend the runbook/`:broadcast` key to use a private relay
before the session, or record explicitly that the owner accepts public-mempool exposure for this cutover.

```bash
# :broadcast, private-relay variant
export CUTOVER_RPC=${CUTOVER_RPC:-https://rpc.flashbots.net}
eval "$(node scripts/quote-balancer-exit-min-amounts.js 50)"
forge script ... --rpc-url $CUTOVER_RPC --broadcast --skip-simulation --slow --ledger ...
```

---

### [L-03] Canonical sUSDS/phUSD pair does not exist on mainnet yet: anyone can `createPair` and `sync` 1+1 wei for ~$1-2 of gas, after which the cutover fails step 2 permanently and the script has no recovery branch <!-- id: pps41l3 -->

- **Severity**: Low (flagged for human review)
- **Entry Point**: `unipooler-cutover`
- **Fingerprint**: `4f454372eed28cd72780b588ac2c1e265b1dcd3e61a464326049cbcfa73b7169`
- **Reconciles with**: pps39 L-01 `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` (phoenix-phase-2-staging, entry point `dev`, open). This is a still-open manifestation of the script's missing recovery branch in this entry point.
- **Disclosure: same root cause as an owner wont-fix.** yield-claim-nft L-26 (`ycn22l26`) `b2a29359fde54466776d650fd0a1097730653f4ed0fc21d380a3b9b00c0742f7` was set **wont-fix by the owner on 2026-10-07**. Ledger `triageReason`, quoted verbatim:

  > Owner triage 2026-10-07: wont-fix. Owner: "I guess, it should just panic and then I'll have to figure out what to do if there is a pair. I think it's safe to mark as won't fix." Basis: the escrow's strict empty-pair gate is fail-loud by design — a synced donation or dust first-mint only reverts exitAndSeed; no value moves and abort() fully restores the old pooler (fork-proven run-22). Recovery from a poisoned pair is an attended, manual operator decision, consistent with L-24 (ycn20l24, wont-fix 2026-10-01). Safe-recovery guidance retained (footgun): if the pair is poisoned, abort(); for a synced 1-wei donation seed via a separate contract using direct transfer + pair.mint(newPooler) (fork-proven to absorb the dust); for a dust-minted pair, arbitrage to the target ratio first, then transfer + mint with a reserve-ratio assertion. Never relax the empty-pair precondition and never router-addLiquidity with zero mins into a skewed pair. Re-weigh if a hard deadline would expose value, or if no replacement seeder is permissible under the story-052 tax constraint.

  L-26 is **not re-raised** here. L-26 covers the escrow-side panic; this entry tracks the phStaging script's missing recovery
  branch, which is already open as pps39 L-01. L-26's wont-fix therefore does not suppress it.
- **Location**:
  - [`script/helpers/UniPoolerCutoverCore.sol#L478-L483`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L478-L483) (`_step2EnsurePairEmpty`)
  - [`lib/yield-claim-nft/src/migration/UniPoolerCutoverEscrow.sol#L359-L375`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L359-L375) (`_requireEmptyPair`)

```solidity
// UniPoolerCutoverCore.sol L478-483
    function _step2EnsurePairEmpty(CutoverLive memory l) internal view returns (uint256 donS, uint256 donP) {
        (uint112 r0, uint112 r1,) = ICutoverUniV2Pair(l.pair).getReserves();
        require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");
        donS = ICutoverERC20(l.sUSDS).balanceOf(l.pair);
        donP = ICutoverERC20(l.phUSD).balanceOf(l.pair);
    }
```

**Description**: Step 2 requires pair reserves `(0,0)`. A synced donation therefore reverts, as designed (story 103 Decision 5),
and the escrow's `_requireEmptyPair` reverts `PairNotEmpty` for the same state. `getPair(sUSDS, phUSD)` = `0x0` at block
~26,221,761, so the grief is open to anyone today and stays open until the session's tx 1 lands:

1. Before OWNER's tx 1, anyone calls `UniswapV2Factory.createPair(sUSDS, phUSD)`.
2. They transfer 1 wei of each token to the pair and call `sync()` (~$1-2 gas).
3. Step 2 reverts in both `:preview` and `:broadcast`; the script has no recovery branch.

Per the run-39 note on pps39 L-01, any recovery must be atomic (one tx doing transfer + `pair.mint(newPooler)`, never Router02).

**Impact**: DoS only: the cutover tooling cannot run. BalancerPoolerV2 keeps serving index 4 and the BPT stays recoverable, but
recovery needs new tooling, and the 30 Oct pause forces it into RECOVERY mode. Deadline check: the brick fires at step 2, before
`withdrawBPT` (tx 4), so the BPT never leaves the old pooler. Index-4 dispatch on the old pooler wraps USDS to sUSDS without
calling the Balancer Vault, so mints keep working after the pool pause; accumulated sUSDS stays rescuable via `rescueERC20`, and
the BPT stays exitable via RECOVERY once the permissionless `enableRecoveryMode` is called (fork-proven, `test_r41_recovery_*`).
The Medium trigger is therefore not met.

**Evidence**: Fork `test_r41_pairSyncedDonation_bricksPreview` (third-party `createPair` + 1 wei each + `sync` makes preview revert
`UniPoolerCutoverCore: pair reserves not empty`); `test_r41_pairUnsyncedDonation_doesNotBlock` (the unsynced variant is now
tolerated). `cast call getPair` = `0x0`.

**Recommendation**: Owner decision (L-26 wont-fix stands). Cheapest pre-emption: create the pair in its own owner tx well before
the session; the core reuses an existing pair at step 1. That alone does not stop a sync-poison, so also prepare, but do not run,
an atomic recovery helper (transfer exit proceeds + `pair.mint(UniPoolerV2)` in one tx) per run-39's guidance.

---

### [L-04] `UniswapHelper._requirePair` is still existence-only at e75ee07: if story 111's helper is deployed and UI-exposed before this cutover, an honest add-liquidity in the tx 1 -> tx 5 window makes `exitAndSeed` revert `PairNotEmpty` <!-- id: pps41l4 -->

- **Severity**: Low (footgun)
- **Entry Point**: `unipooler-cutover`
- **Fingerprint**: `a6764bb1edf199d5e2e887152b754fb3dabc56e6326d49f4bad53b2c6d9d4cd4`
- **Verification**: **UNVERIFIED THIS RUN.** Static re-check at e75ee07 (`UniswapHelper.sol` is unchanged since run 40's `a4f9f3c`), plus run-40's fork proof of the helper path (pps40 L-02) and this run's re-proof of the synced-reserves revert (`test_r41_pairSyncedDonation_bricksPreview`). The helper path itself was not freshly fork-proven this run.
- **Reconciles with**: pps40 L-02 `1d7e436f7dad8616b42dd5e2616dd93ac83c8f7a23e82f60fb599675de405f91` (phoenix-phase-2-staging, open). pps40 L-02 itself re-raises the helper side of ycn L-26 (`b2a29359fde5…`, wont-fix 2026-10-07; see the disclosure under L-03). pps40 L-02 is open, so there is no suppression.
- **Location**:
  - [`src/periphery/UniswapHelper.sol#L428-L431`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/src/periphery/UniswapHelper.sol#L428-L431) (`_requirePair`, used by `addLiquiditySUSDS` / `addLiquidityUSDS`)
  - [`lib/yield-claim-nft/src/migration/UniPoolerCutoverEscrow.sol#L359-L375`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L359-L375)

```solidity
// UniswapHelper.sol L428-431
    function _requirePair() internal view returns (address p) {
        p = pair();
        if (p == address(0)) revert PairNotFound();
    }
```

```solidity
// UniPoolerCutoverEscrow.sol L372-374
        if (r0 != 0 || r1 != 0 || b0 != 0 || b1 != 0) {
            revert UniPoolerCutoverEscrow__PairNotEmpty(r0, r1, b0, b1);
        }
```

**Description**: Story 111 calls the helper deploy independent of the cutover ("may go before or after"). The helper is not on
mainnet yet (address-book `UniswapHelper` = `0x0`). The cutover creates the pair at tx 1 and seeds it at tx 5. If the helper is
live first, `PairNotFound` stops reverting after tx 1, and a user's add-liquidity lands a first-LP mint on the empty pair before
tx 5. `exitAndSeed` then reverts `UniPoolerCutoverEscrow__PairNotEmpty` (synced reserves). Story 111's "either order" wording makes
this ordering consequence non-obvious to a competent owner, so it is a Law-3 footgun.

**Impact**: DoS of the cutover. The BPT stays safe in the escrow and `abort()` restores it. The hazard disappears if the helper
is deployed after the cutover.

**Recommendation**: Sequence `uniswap-helper:broadcast` strictly after `unipooler-cutover:verify` passes, and state this in
story 111 and the runbook. Alternatively, land the one-line `reserves != 0` check in `_requirePair` first.

```solidity
    function _requirePair() internal view returns (address p) {
        p = pair();
        if (p == address(0)) revert PairNotFound();
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(p).getReserves();
        if (r0 == 0 || r1 == 0) revert PairNotFound(); // never be the first LP on the canonical pair
    }
```

---

## QA Findings

### [Q-01] Rescue amounts (txs 20/21) and the `withdrawBPT` amount are baked in forge's local pass; interim index-4 mints or third-party dust leave a residue on the paused old pooler that makes the mandatory `:verify` tail hard-fail <!-- id: pps41q1 -->

- **Severity**: QA
- **Entry Point**: `unipooler-cutover`
- **Fingerprint**: `c62a58a1a8f8687e432f42673afdbb2629e43f25767c6a223e18554a6b537eb4`
- **Reconciles with**: pps40 Q-01 `c8fb41a168e1ed1098cb04eb88f045c722d43597e243550968b621a56df6d86a` (phoenix-phase-2-staging, open). Still-open manifestation in this entry point.
- **Location**:
  - [`script/helpers/UniPoolerCutoverCore.sol#L671-L711`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L671-L711) (`_step11MoveBalances`)
  - [`script/DeployMainnetUniPoolerCutover.s.sol#L251-L254`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L251-L254) (`_checkDrained`, run by `script/VerifyUniPoolerCutover.s.sol`)
  - [`lib/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol#L437-L440`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/dispatchers/BalancerPoolerV2.sol#L437-L440) (`rescueERC20`, not pause-gated)

```solidity
// UniPoolerCutoverCore.sol L677-680
        sUSDSRescued = ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler);
        if (sUSDSRescued > 0) {
            uint256 npBefore = ICutoverERC20(l.sUSDS).balanceOf(l.newPooler);
            old.rescueERC20(l.sUSDS, l.newPooler, sUSDSRescued);
```

```solidity
// DeployMainnetUniPoolerCutover.s.sol L252-254 (_checkDrained)
        require(ICutoverERC20(BPT).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds BPT");
        require(ICutoverERC20(SUSDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds sUSDS");
        require(ICutoverERC20(USDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds USDS (parked USDS not moved)");
```

**Description**: With `--skip-simulation`, every "read live" amount in step 11 (`sUSDSRescued = balanceOf(oldPooler)`) and the
`old pooler not drained` require are evaluated only in forge's local pass, and the amount is fixed in tx 20's calldata. Any public
index-4 mint landing between the local pass and tx 7 wraps USDS into sUSDS on the old pooler (16.3 sUSDS per mint at the current
price). So does any 1-wei donation of sUSDS/USDS/BPT to the old pooler. That residue survives tx 20, tx 24 pauses the pool, and
`_checkDrained` keeps "old pooler empty" a HARD require (revision 2 kept it hard on purpose). The `:broadcast` tail
`&& npm run unipooler-cutover:verify` then exits non-zero right after a successful cutover.

**Impact**: Operational only. The verify chain breaks and needs one OWNER `rescueERC20(token, UniPoolerV2, residue)` tx, which is
not pause-gated and is contract-to-contract. A stranger can re-grief `:verify` at any time after the cutover with 1 wei, the same
donation class that revision 2 downgraded to a warning for the escrow.

**Evidence**: Fork `test_r41_bakedRescue_interimDust_failsVerify_ownerCanSweep` (modelled: residue injected after the run, since a
single-pass harness re-reads live): full cutover, +16 sUSDS on the old pooler, verify reverts `verify: old pooler holds sUSDS`;
OWNER `rescueERC20` then verify passes.

**Recommendation**: In `_checkDrained`, keep "old pooler holds 0 BPT" hard but report sUSDS/USDS residue as a WARNING with the exact
`rescueERC20` command, or compare against a small dust threshold. In the runbook, note that interim mints during txs 1..7 leave
sUSDS to sweep.

```solidity
        require(ICutoverERC20(BPT).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds BPT");
        uint256 s = ICutoverERC20(SUSDS).balanceOf(OLD_POOLER);
        if (s != 0) console.log("WARNING: old pooler holds sUSDS; sweep with rescueERC20(sUSDS, UniPooler, amount):", s);
        uint256 u = ICutoverERC20(USDS).balanceOf(OLD_POOLER);
        if (u != 0) console.log("WARNING: old pooler holds USDS; sweep with rescueERC20(USDS, escrow, amount) + wrapUsds:", u);
```

---

### [Q-02] No resume tooling: `_alreadyCompleted` treats `configs(4) == UniPooler` (tx 19's effect alone) as "completed", so a crash after tx 19 re-runs as "Nothing to do"; the header's `_fundEscrow` resume claim is true of no reachable path <!-- id: pps41q2 -->

- **Severity**: QA (faithfulness facet; cross-listed in `spec-conformance.md`)
- **Entry Point**: `unipooler-cutover`
- **Fingerprint**: `e2909097a253570554b172ae8052da95a17078cf07f0abb67fdebca0e8bb0032`
- **Reconciles with**: none (new). Related: pps40 L-03 `85095591a60a255bbf6aea9f34526957ce4c921c2c5ef74c2e7c8111b58bd2fa` (rewire window, no resume) and the story-103 review carry-forward "no guarded script entry point for resuming into an existing escrow".
- **Location**:
  - [`script/DeployMainnetUniPoolerCutover.s.sol#L450-L468`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L450-L468) (`_alreadyCompleted`)
  - [`script/DeployMainnetUniPoolerCutover.s.sol#L50-L54`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L50-L54) (header)

```solidity
// DeployMainnetUniPoolerCutover.s.sol L458-464
        address np = completed ? _progressAddress(json, "UniPooler") : address(0);
        (address d,,,) = ICutoverNFTMinter(NFT_MINTER).configs(DISPATCHER_INDEX);
        if (completed && np != address(0) && np.code.length > 0 && d == np) {
            console.log("Progress file is completed and its UniPooler is live at index 4:", np);
            console.log("Nothing to do - no transaction sent. Run `npm run unipooler-cutover:verify`.");
            return true;
        }
```

```solidity
// header L53-54
 *   floors or `escrow.abort()` (everything back to the old pooler) and re-runs from a clean state. Any re-funding
 *   of an existing escrow goes through the core's guarded `_fundEscrow`.
```

**Description**: Story 103 Technical Details require "step gating via `_isConfigured`/`_trackConfig`". The implementation (story
Decision 7, disclosed) writes the progress file once, at the end of forge's local pass, as `completed`, and has no step gating.
`_alreadyCompleted` returns "Nothing to do - no transaction sent" when the file is completed, the UniPooler has code and
`configs(4) == UniPooler`. That is tx 19's effect alone; txs 20-24 (sUSDS rescue, USDS rescue, `wrapUsds`,
`old.setMinter(OWNER)`, `old.pause()`) may not have landed. Separately, the header states that any re-funding of an existing
escrow goes through the core's guarded `_fundEscrow`, but no entry point ever calls `_fundEscrow` on an existing escrow: `run()`
always deploys a fresh pooler and escrow. A resume into an existing escrow is a hand-typed `cast withdrawBPT` with no L-27 guard.

**Impact**: Misleading operator output on the most likely partial-failure path. `:verify`, next in the `&&` chain, does catch it
(`verify: old pooler not paused`). The L-27 protection on the manual-resume path rests only on the header rule, which the owner
is trusted to follow. Live state also lowers the L-27 stakes: the old pooler holds only escrow snapshot tokens.

**Evidence**: Fork `test_r41_crashAfterReplaceDispatcher_rerunIsNoOp_verifyCatches` (re-run no-op, verify reverts
`verify: old pooler not paused`); `test_r41_L27_withoutGuard_manualResumeStrandsX` (the unguarded manual path strands a
non-snapshot token).

**Recommendation**: Make `_alreadyCompleted` require the full end state (old pooler paused, minter OWNER, drained) and otherwise
print a precise list of which of txs 20..24 are missing. Correct the header sentence, or add a small `RESUME_ESCROW=<addr>` entry
point that calls `_fundEscrow` / `exitAndSeed` / steps 11-12 against an existing escrow behind the same guards.

---

### [Q-03] Plan §4 step 11's post-broadcast "forked test mint dispatches, wraps and accrues debt" never runs against landed state: `:verify` has no mint and the `:broadcast` tail's trailing `:preview` is a guaranteed no-op <!-- id: pps41q3 -->

- **Severity**: QA (faithfulness facet; cross-listed in `spec-conformance.md`)
- **Entry Point**: `unipooler-cutover`
- **Fingerprint**: `3da1655208b7dda10c7b11f6c2912907d18db206724cb15517280f390dd01522`
- **Reconciles with**: none (new).
- **Location**:
  - [`script/VerifyUniPoolerCutover.s.sol#L35-L85`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/VerifyUniPoolerCutover.s.sol#L35-L85) (`run`)
  - [`package.json#L76`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/package.json#L76) (`:broadcast` tail)

```solidity
// VerifyUniPoolerCutover.s.sol L79-84
        _checkDrained(escrow);
        console.log("OK: old pooler paused, minter OWNER, 0 sUSDS / 0 BPT / 0 USDS (escrow residuals reported above).");

        _reportOwnerBpt();
        _simulateQuotedPool(np);
        console.log("VERIFY PASSED");
```

```json
"unipooler-cutover:broadcast": "... && npm run unipooler-cutover:verify && npm run unipooler-cutover:preview"
```

**Description**: Story 103 Background quotes Plan §4 step 11: "Verify: … A forked test mint dispatches, wraps and accrues debt."
The implementation performs the mint only in `_previewEndToEnd`, pre-broadcast, on simulated state. `VerifyUniPoolerCutover`
checks wiring and simulates `pool()` but not a mint. The `:broadcast` tail re-runs `:preview`, which returns at
`_alreadyCompleted()` before any end-to-end code once the progress file is completed and live. The trailing step therefore
cannot exercise the landed contracts.

**Impact**: Verification gap only. `_checkWiring` covers most mint-path dependencies (minter slot, hook both ways, `configs(4)`,
paused flags), so this is low value.

**Evidence**: Fork `test_r41_fullRun_stateDiff_verify` asserts the `:preview` tail is a no-op and logs
`Nothing to do - no transaction sent`. `VerifyUniPoolerCutover.s.sol` L35-85 contains no mint.

**Recommendation**: Move the dealt-user test mint (in a reverted snapshot) into `VerifyUniPoolerCutover.run`, next to
`_simulateQuotedPool`, and drop or relabel the trailing `:preview` in `:broadcast`.

```solidity
        _reportOwnerBpt();
        _simulateQuotedPool(np);
        uint256 snap = vm.snapshotState();
        _simulateIndex4Mint(np);   // deal a user USDS, mint at index 4, assert sUSDS lands on np and hook debt accrues
        vm.revertToState(snap);
        console.log("VERIFY PASSED");
```

---

## Centralization Risks

None. Owner actions are trusted under Law 3; the owner footguns found by this run are reported above as L-01 and L-04.

---

## Appendix: automated report

The 4naly3er output for the four closure files, with triage, is in [`4naly3er-report.md`](./4naly3er-report.md). No High or
Medium bot hit survives triage (oracle-price, fee-on-transfer and L2 `block.number` hits are false positives or known-invalid
classes). The one Low hit on a real defect site (`rescueERC20` sweep, `UniPoolerCutoverCore.sol` L680/L690) is subsumed by Q-01.
