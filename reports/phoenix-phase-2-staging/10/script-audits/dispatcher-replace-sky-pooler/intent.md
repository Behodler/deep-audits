# Intent — dispatcher-replace-sky-pooler (DispatcherReplaceSkyPoolerAtIndex4)

Story 056. **REGRESSION run** at submodule HEAD `30775401` (prior audited `0bbbe8ca`,
run-09). The forge target was rewritten (+250/-58) to fix run-09 **M-01** (new pooler
`_minter` never set → `mint(4)` bricked). Single owner-signed Foundry cutover that swaps
NFTMinterV2 dispatcher **index 4** from the live "nudge" `BalancerPoolerV2` (`0x26F8…b38A`)
to a freshly deployed Sky-PSM-route `BalancerPoolerV2` + new `BalancerPoolerMintDebtHook`,
migrating BPT + sUSDS and finishing with `pool(minBPT)`. NFT id 4 and the NFTStaker
(stakedId=4 / dispatcherIndex=4) are unchanged — only `configs[4].dispatcher` flips.

## Stated purpose (from NatSpec + Story-056 comment)
- [x] Deploy a fixed (Sky-route) `BalancerPoolerV2` and a new `BalancerPoolerMintDebtHook`.
- [x] **Authorize NFTMinterV2 as the new pooler's `_minter`** (`newPooler.setMinter(NFT_MINTER_V2)`)
      so `mint(4)` keeps working — **the M-01 fix, newly added at step 6.**
- [x] Migrate the old pooler's BPT and sUSDS into the new pooler.
- [x] Re-point NFTMinterV2 `configs[4].dispatcher` → newPooler (`replaceDispatcher(4, …)`), NFT id stays 4.
- [x] Re-point NFTStaker.dispatcherHook → newHook; authorize newHook as a phUSD minter; decommission oldHook.
- [x] Validate the Sky USDS→USDC `buyGem` donation route once (10% of swept sUSDS) before committing.
- [x] Seed the remaining ~90% sUSDS + migrated BPT into newPooler and call `pool(minBPT>0)` (isolated, try/catch).
- [x] Leave index 4 **mintable** through the new pooler — now both asserted (slot1 require, step 6) AND
      proven end-to-end in preview (step 16 e2e `mint(4)`).

## Ordered steps performed by run()
1. `_step1_snapshotPreState` — read configs(4), oldHook, BPT/sUSDS/vault, batchDonationSize, batchMinter.
2. `_verifyStakerOwner` — assert NFTStaker.owner == NFTMinterV2.owner == OWNER_ADDRESS.
   (prank OWNER if PREVIEW, else startBroadcast)
3. `pullAndRefresh()` on NFTStaker (drain old hook mint-debt to 0).
4. Deploy new `BalancerPoolerV2(sUSDS, bpt, vault, ROUTER, SUSDS_IS_FIRST, OWNER)`.
5. Deploy new `BalancerPoolerMintDebtHook(OWNER, newPooler, PHUSD)`.
6. **Wire hook + MINTER (M-01 fix):** `newPooler.setHook(newHook)`; **`newPooler.setMinter(NFT_MINTER_V2)`**;
   **`require(vm.load(newPooler, slot1) == NFT_MINTER_V2)`**; `newHook.setRecipient(NFTStaker)`;
   `phUSD.setMinter(newHook,true)`.
7. Mirror config: setBatchDonationSize, setBatchMinter, setPSM(SKY_PSM), setMaxTout(1%),
   setAuthorizedPooler(OWNER,true) + `require(poolerAuthVersion(OWNER)==authVersion)`.
8. `oldPooler.withdrawBPT(OWNER, bptBal)`.
9. `oldPooler.rescueERC20(sUSDS, OWNER, susdsBal)`.
10. Manual Sky-route validation: redeem 10% sUSDS→USDS, `buyGem(batchMinter, gemAmt)`, assert USDC delta.
11. Seed newPooler with remaining sUSDS + migrated BPT.
12. `NFTStaker.setDispatcherHook(newHook)` + assert.
13. `NFTMinterV2.replaceDispatcher(4, newPooler)` + assert configs(4)==newPooler.
14. `phUSD.setMinter(oldHook, false)`.
15. `_step15_postStateLog` — cutover invariants (pre-pool): configs(4), hook, BPT migration, sUSDS drain.
16. **PREVIEW ONLY** `_step16_previewE2EMint` — deal USDS, `mint(4)`, assert NFT balance +1 and hook debt accrued.
17. `_step17_finalPool` — derive minBPT (env or DEFAULT_MIN_BPT=284e18); `pool(minBPT)` in **try/catch** (isolated).

## Declared pre-conditions (require before / during the broadcast block)
- setUp(): `block.chainid == 1 || 31337`.                                       [LIVE: PASS]
- `configs(4).dispatcher != 0` and `== LIVE_INDEX4_POOLER` (drift guard).        [LIVE: PASS — 0x26F8…b38A]
- `NFTStaker.dispatcherHook() != 0` (== 0x1427…727e).                            [LIVE: PASS]
- oldPooler.pool()/sUSDS()/vault()/batchMinter() all non-zero; `preSusdsOld > 0`.[LIVE: PASS — 586.34 sUSDS]
- `NFTStaker.owner() == OWNER_ADDRESS` and `NFTMinterV2.owner() == OWNER_ADDRESS`.[LIVE: PASS — 0xCad1…D0B6]
- Step 3: `oldHook.mintDebt() == 0` after pullAndRefresh.                        [FORK: PASS]
- **Step 6 (NEW): `vm.load(newPooler, slot1) == NFT_MINTER_V2` after setMinter** [FORK: PASS — both variants]
- Step 7: `poolerAuthVersion(OWNER) == authVersion` after setAuthorizedPooler.   [FORK: PASS]
- Step 10: `tout <= MAX_TOUT`; `to18ConversionFactor > 0`; gemAmt>0; usdsSpent<=redeemed; USDC delta==gemAmt. [FORK: PASS, tout=0, conv=1e12]
- Step 17: on real network `minBPT > 0` (refuses unprotected pool()).            [FORK: PASS, 284e18]

## Declared post-conditions (require / assert after broadcast)
- Step 8: BPT withdraw delta exact; oldPooler BPT == 0.                          [FORK: PASS]
- Step 9: sUSDS sweep delta exact; oldPooler sUSDS == 0.                         [FORK: PASS]
- Step 11: newPooler received seeded sUSDS (and BPT).                            [FORK: PASS]
- Step 12: NFTStaker.dispatcherHook() == newHook.                               [FORK: PASS]
- Step 13: configs(4).dispatcher == newPooler.                                  [FORK: PASS]
- Step 15: configs(4)==newPooler; newPooler BPT >= preBptOld; staker hook==newHook; oldPooler BPT/sUSDS==0. [FORK: PASS]
- **Step 16 (PREVIEW ONLY): `mint(4)` succeeds, NFT id-4 balance +1, hook mintDebt accrued.** [FORK: PASS]
- Step 17: newPooler BPT increased by >= minBPT; newPooler sUSDS == 0 after pool() (or DEFERRED on failure, try/catch). [FORK: PASS, +293.6 BPT]

## Gap closure vs run-09 (M-01)
- **M-01 spec gap is CLOSED.** Run-09 flagged that no post-condition smoke-tested `mint(4)` and
  that `newPooler.setMinter` was never called. HEAD adds the `setMinter` call AND a hard
  `require` on slot1 (executes on BOTH variants, fail-closed), plus a preview-only end-to-end
  `mint(4)` proof. The script now refuses to proceed with an unwired dispatcher.

## Residual / NOT-closed
- **L-01 (Low) is UNCHANGED:** broadcast still `--skip-simulation` with offline-derived
  `DEFAULT_MIN_BPT=284e18`; no live in-script re-query. The rewrite *mitigates* the worst
  sub-impact (a too-high minBPT no longer strands a half-applied cutover — pool() is now in
  try/catch, recoverable later), but the stale-floor / weak-slippage concern remains.
- **Broadcast-only correctness of M-01 fix** rests on step-6 `setMinter` + the slot1 require
  (step 16 e2e mint is preview-only, never on broadcast). Both run unconditionally on broadcast
  and fail closed, so this is sufficient — see side-effects.json `mintFixVerification`.
