# Intent — dispatcher-replace-sky-pooler (DispatcherReplaceSkyPoolerAtIndex4)

Story 056. Single owner-signed Foundry cutover that swaps NFTMinterV2 dispatcher **index 4**
from the live "nudge" `BalancerPoolerV2` (`0x26F8…b38A`) to a freshly deployed Sky-PSM-route
`BalancerPoolerV2` + new `BalancerPoolerMintDebtHook`, migrating BPT + sUSDS and finishing with a
single-arg `pool(minBPT)`. NFT id 4 and the NFTStaker (stakedId=4 / dispatcherIndex=4) are
unchanged — only `configs[4].dispatcher` flips.

## Stated purpose (from NatSpec + Story-056 comment)
- [ ] Deploy a fixed (Sky-route) `BalancerPoolerV2` and a new `BalancerPoolerMintDebtHook`.
- [ ] Migrate the old pooler's BPT and sUSDS into the new pooler.
- [ ] Re-point NFTMinterV2 `configs[4].dispatcher` → newPooler (`replaceDispatcher(4, …)`), NFT id stays 4.
- [ ] Re-point NFTStaker.dispatcherHook → newHook; authorize newHook as a phUSD minter; decommission oldHook.
- [ ] Validate the Sky USDS→USDC `buyGem` donation route once (10% of swept sUSDS) before committing.
- [ ] Seed the remaining ~90% sUSDS + migrated BPT into newPooler and call `pool(minBPT>0)`.
- [ ] Leave index 4 **mintable** through the new pooler (the implicit, load-bearing intent — the whole
      point of keeping NFT id 4 and re-pointing the dispatcher is that `mint(4)` keeps working).

## Ordered steps performed by run()
1. `_step1_snapshotPreState` — read configs(4), oldHook, BPT/sUSDS/vault, batchDonationSize, batchMinter.
2. `_verifyStakerOwner` — assert NFTStaker.owner == NFTMinterV2.owner == OWNER_ADDRESS.
   (prank OWNER if PREVIEW, else startBroadcast)
3. `pullAndRefresh()` on NFTStaker (drain old hook mint-debt to 0).
4. Deploy new `BalancerPoolerV2(sUSDS, bpt, vault, ROUTER, SUSDS_IS_FIRST, OWNER)`.
5. Deploy new `BalancerPoolerMintDebtHook(OWNER, newPooler, PHUSD)`.
6. Wire hook: `newPooler.setHook(newHook)`, `newHook.setRecipient(NFTStaker)`, `phUSD.setMinter(newHook,true)`.
7. Mirror config: setBatchDonationSize, setBatchMinter, setPSM(SKY_PSM), setMaxTout(1%),
   setAuthorizedPooler(OWNER,true).
8. `oldPooler.withdrawBPT(OWNER, bptBal)`.
9. `oldPooler.rescueERC20(sUSDS, OWNER, susdsBal)`.
10. Manual Sky-route validation: redeem 10% sUSDS→USDS, `buyGem(batchMinter, gemAmt)`, assert USDC delta.
11. Seed newPooler with remaining sUSDS + migrated BPT.
12. `NFTStaker.setDispatcherHook(newHook)`.
13. `NFTMinterV2.replaceDispatcher(4, newPooler)`.
14. `phUSD.setMinter(oldHook, false)`.
15. Derive `minBPT` (env or DEFAULT_MIN_BPT=284e18) and `newPooler.pool(minBPT)`.
16. Post-state log + invariant asserts.

## Declared pre-conditions (require before / during the broadcast block)
- setUp(): `block.chainid == 1 || 31337`.
- `configs(4).dispatcher != 0` and `== LIVE_INDEX4_POOLER` (drift guard).      [LIVE: PASS]
- `NFTStaker.dispatcherHook() != 0`.                                            [LIVE: PASS — 0x1427…727e]
- oldPooler.pool()/sUSDS()/vault()/batchMinter() all non-zero; `preSusdsOld > 0`.[LIVE: PASS]
- `NFTStaker.owner() == OWNER_ADDRESS` and `NFTMinterV2.owner() == OWNER_ADDRESS`.[LIVE: PASS — both 0xCad1…D0B6]
- Step 3: `oldHook.mintDebt() == 0` after pullAndRefresh.                       [FORK: PASS]
- Step 7: `poolerAuthVersion(OWNER) == authVersion` after setAuthorizedPooler.  [FORK: PASS]
- Step 10: `tout <= MAX_TOUT`; `to18ConversionFactor > 0`; gemAmt>0; usdsSpent<=redeemed; USDC delta==gemAmt. [FORK: PASS, tout=0, conv=1e12]
- Step 15: on real network `minBPT > 0` (refuses unprotected pool()).          [FORK: PASS, 284e18]

## Declared post-conditions (require / assert after broadcast)
- Step 8: BPT withdraw delta exact; oldPooler BPT == 0.                         [FORK: PASS]
- Step 9: sUSDS sweep delta exact; oldPooler sUSDS == 0.                        [FORK: PASS]
- Step 11: newPooler received seeded sUSDS (and BPT).                           [FORK: PASS]
- Step 12: NFTStaker.dispatcherHook() == newHook.                              [FORK: PASS]
- Step 13: configs(4).dispatcher == newPooler.                                 [FORK: PASS]
- Step 15: newPooler BPT increased by >= minBPT; newPooler sUSDS == 0 after pool(). [FORK: PASS, +287.9 BPT]
- Step 16 invariants: configs(4)==newPooler; newPooler BPT >= preBptOld; staker hook==newHook;
  oldPooler BPT==0; oldPooler sUSDS==0.                                         [FORK: ALL PASS]

## NOT declared / NOT asserted (gap)
- **No post-condition smoke-tests `mint(4)`.** The script never calls `newPooler.setMinter(NFT_MINTER_V2)`
  (the ATokenDispatcherV2 `_minter`), so the new pooler's `_minter == address(0)` and any `mint(4)` reverts
  `"ATokenDispatcherV2: caller is not minter"`. The predecessor cutover required exactly this step
  (`SetMinterOnIndex4Pooler.s.sol`, Story-048 step 11). All of the script's own asserts pass while index 4
  is left unmintable — the spec is silent on the one invariant that matters most for the stated purpose.
