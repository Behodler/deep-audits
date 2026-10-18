# Intent — unipooler-cutover (run 41, src e75ee07)

Sources, highest authority first:
1. Story phStaging2:103 — `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md` (state **auto-complete**, gates `stage1-audit` 2026-10-18 and `holding-broadcast` 2026-10-01 cleared; amendments 2026-10-07 (052 escrow), 2026-10-08 (L-27), 2026-10-10 (F-02-052); review carry-forwards in its Auto-Completed block).
2. Amendment doc `~/code/product-owner/scratchpad/planning-docs/phoenix/phStaging2/story-103-amendment-l27-bpt-guard.md` (its "Target story" path still cites `incomplete/`; the story now lives in `auto-complete/`).
3. `package.json:74` `//UniPoolerCutover` comment; `script/DeployMainnetUniPoolerCutover.s.sol:20-76` NatSpec; `script/helpers/UniPoolerCutoverCore.sol:8-95` NatSpec.
4. `docs/BalancerWinddownPlan.md` §4 Stage 2 — **superseded** where it describes the pre-052 OWNER-custody flow (story Background L63-75 still quotes that flow; see F-01 reconcile).

## Stated purpose (story 103 + amendments)
- [x] Cut NFTMinterV2 index 4 over from BalancerPoolerV2 `0x7f68…11F1` to a freshly deployed UniPoolerV2 on the canonical sUSDS/phUSD UniV2 pair, in ONE owner broadcast session.
- [x] No protocol funds through any EOA (yield-claim-nft:052): BPT/sUSDS/phUSD/USDS move contract-to-contract via `UniPoolerCutoverEscrow` (operator = OWNER).
- [x] Old pooler's whole BPT (`withdrawBPT(escrow, bal)`) exited (PROPORTIONAL by default, RECOVERY via `RECOVERY_EXIT=true`), pair seeded with everything recovered, LP to UniPoolerV2.
- [x] `hook.pull()` then `mintDebt()==0`; `hook.setDispatcher(UniPoolerV2)` THEN `UniPoolerV2.setHook(hook)`.
- [x] UniPoolerV2: `setMinter(NFTMinterV2)`; copy PSM, maxTout, batchMinter, batchDonationSize, nudgeStreamer live; re-authorize the same four poolers. No Pauser registration.
- [x] `replaceDispatcher(4, UniPoolerV2)` with price/growth/disabled preserved.
- [x] Old pooler sUSDS → UniPoolerV2; parked USDS → escrow → `wrapUsds()` (shares to UniPoolerV2).
- [x] Retire old pooler: `old.setMinter(OWNER)` + `old.pause()`.
- [x] L-27: `require(old.pool() == escrow.bpt())` read live before `withdrawBPT` and before any re-fund of an existing escrow; header forbids `old.setPool` while an escrow is live.
- [x] F-02-052: no owner→escrow BPT transfer; floors sized on the old pooler's BPT only (≈20,401.809); no revert on non-zero owner BPT; owner BPT reported only.
- [x] Revision 2: no escrow balance check a third-party donation can fail (deltas only; escrow residuals are warnings).
- [ ] (Story Technical Details) step gating via `_isConfigured`/`_trackConfig` — **not implemented**; replaced by all-or-nothing refusal (story Decision 7, disclosed). See candidate F/QA "no resume tooling".
- [ ] (Plan §4 step 11, quoted in story Background) "A forked test mint dispatches, wraps and accrues debt" as a post-broadcast check — only done in the pre-broadcast preview; `:verify` has no simulated mint and the `:broadcast` tail's `:preview` is a guaranteed no-op.

## Inputs
- `MIN_SUSDS_OUT_WEI`, `MIN_PHUSD_OUT_WEI` REQUIRED > 0 (`_buildParams` DeployMainnetUniPoolerCutover.s.sol:402-430), from `eval "$(node scripts/quote-balancer-exit-min-amounts.js 10)"` (tolerance 1..50 bps, default 10; sized on `BPT.balanceOf(OLD_POOLER)`, quote.js:101,107).
- `RECOVERY_EXIT` (default false). `CUTOVER_GAS_PRICE_WEI` (default 300000000 = 0.3 gwei, `--legacy`, `--gas-estimate-multiplier 200`).
- Constants: `EXIT_TOLERANCE_BPS = 50` (:112), `SEED_DEADLINE_OFFSET = 1 hours` (:114), `POOL_PREVIEW_TOLERANCE_BPS = 50` (:116).

## Declared pre-conditions (require'd in forge's local pass, before any tx would be signed)
Script (`run`, :348-387; `_preflightAddresses` :156-178):
- chainid == 1.
- `_alreadyCompleted()` (:450-468): no progress file → fresh; `completed` file whose UniPooler has code AND is `configs(4).dispatcher` → no-op; any other file → revert POISONED.
- 11 address-book keys in `mainnet-addresses.ts` equal the script constants (NFTMinter stored all-lowercase; parsed comparison passes).
- Live wiring: `old.pool()==BPT`, `old.vault()==BalancerVault`, `old.sUSDS()==SUSDS`, `old.primeToken()==USDS`, `hook.phUSD()==PhUSD`, `Router02.factory()==UNIV2_FACTORY`, BalancerRouter has code.
- `MIN_*` both > 0; Balancer pool is exactly {sUSDS, phUSD}.
Core step 0 (`_step0Preconditions` UniPoolerCutoverCore.sol:407-465):
- OWNER owns old pooler, hook, NFT minter; balancer router non-zero; tolerance ≤ 100 bps; seed deadline in (now, now+1 day].
- every listed pooler fails `poolerAuthVersion(p) != authVersion` on the old pooler (story 099 revoke).
- `configs(4).dispatcher == old`, `hook.dispatcher() == old`, `old.hook() == hook`.
- every `minAmountsOut[i] > 0`, length 2.
Per-step guards: step 2 reserves (0,0) (:478-483); step 3/3b immutables (:486-506); step 4 L-27 guard + BPT delta (:519-532); step 5 floors in [share·(1−tol), share] of `bptWithdrawn` (:543-594); owner-not-credited after every step (:378-390).

## Declared post-conditions
Core: LP delta == liquidity, seeded reserves ≥ floors (:551-566); `mintDebt()==0` (:605); hook ↔ pooler (:612-616); config copied + four poolers authorized (:639-647); index config unchanged (:655-659); sUSDS/USDS rescue deltas and wrapped shares on pooler, old pooler drained (:677-710); old paused (:718); `_assertRetired` (:726-736).
Script: `_checkWiring` (:211-242), `_checkDrained` (old pooler empty hard; escrow residual warning, :251-262).
Preview-only E2E (`_previewEndToEnd` :511-531): dealt user mints index 4 → sUSDS on UniPoolerV2 rises, `mintDebt` rises; `quotePool`-floored `pool()` in a reverted snapshot.
Verify (`VerifyUniPoolerCutover.s.sol:35-106`): progress chainId 1 + completed + three addresses; book agrees; `_checkWiring`; reserves == seed (strict unless `VERIFY_ALLOW_RESERVE_DRIFT`); LP ≥ seeded; `_checkDrained`; owner BPT reported; simulated `pool()`.

## Observed vs declared (summary; detail in side-effects.json)
All declared pre- and post-conditions passed in the fork preview at block 26,221,761 (CLI, -vvvv) and in the exact `npm run unipooler-cutover:preview` at 26,221,847. `RECOVERY_EXIT=true` on the live pool fails closed in the local pass with `PoolNotInRecoveryMode(0x642B…db04)`. `:verify` passes against the post-cutover fork state, and fails pre-broadcast by design ("no progress file").
