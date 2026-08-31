# Intent — RestoreMintAtIndex4

Source: `lib/phoenix-phase-2-staging/script/RestoreMintAtIndex4.s.sol`
Entry point (package.json `//` comment): "Story 048 follow-up — re-enable NFTMinterV2 dispatcher index 4 + repoint ViewRouter 'mint' to index-4 MintPageView"

## Stated purpose (from `@notice` + inline comments)
- [x] **Action 1** — `NFTMinterV2.setDispatcherDisabled(4, false)`: re-enable dispatcher index 4.
      Story-047 set `configs[4].disabled = true` to push minting onto the index-6 pooler; the
      story-048 cutover (`DispatcherReplaceAtIndex4`) replaced the index-4 dispatcher but did NOT
      clear the `disabled` flag, so `mint(4, …)` still reverts `"NFTMinterV2: dispatcher is disabled"`.
- [x] **Action 2** — `ViewRouter.setPage(keccak256("mint"), 0x64FE63ca…)`: re-point the "mint" page
      at the MintPageView that reads dispatcher index 4 (USDS). Currently-registered page hardcodes
      index 6 (now disabled).

## Declared pre-conditions (`require` before the prank/broadcast block)
- [x] `block.chainid == 1` (mainnet only).
- [x] `ViewRouter.owner() == OWNER_ADDRESS` (`0xCad1…D0B6`).  — verified live: owner matches.
- [x] `pages(keccak256("mint")) == CURRENT_MINT_PAGE_VIEW` (`0xeBEc…`) — **drift guard**.
- [x] `extcodesize(TARGET_MINT_PAGE_VIEW) > 0`.
- [x] `configs(4).dispatcher != address(0)`.
- [x] `configs(4).disabled == true` — "nothing to enable" drift guard.

## Declared post-conditions (`require`/smoke-test after the writes)
- [x] `configs(4).disabled == false`.
- [x] `pages(keccak256("mint")) == TARGET_MINT_PAGE_VIEW`.
- [x] `IPageView(TARGET).getData(OWNER_ADDRESS)` does not revert (smoke test).

## Trust / signer model
- Two owner-signed txs in one broadcast, Ledger HD path `m/44'/60'/46'/0/0` (index 46).
- Both target functions are `onlyOwner` (`NFTMinterV2.setDispatcherDisabled`, `ViewRouter.setPage`).
  The script asserts `ViewRouter.owner()` but does NOT assert `NFTMinterV2.owner()`; it relies on the
  on-chain `onlyOwner` revert if the Ledger signer is not the minter owner.

## Cluster (story-048 family)
- **predecessor** `DispatcherReplaceAtIndex4` — installed NEW_POOLER `0x26F8…` at index 4
  (step 10), disabled index 6 (step 14); intentionally **omitted step 11** (`setMinter` on the new
  pooler).
- **skipped-step** `SetMinterOnIndex4Pooler` — `NEW_POOLER.setMinter(NFT_MINTER_V2)`. Required for
  `mint(4)` to pass `ATokenDispatcherV2.dispatch`'s `onlyMinter` gate. NOT part of this script.
- **sibling-config** `SetBatchDonationSizeIndex4` — sets `batchDonationSize=10%` on NEW_POOLER.
- **evidence** `TempSimulate40MintsIndex4` — fork sim that applies all THREE owner fixes
  (`setDispatcherDisabled(4,false)` + `setMinter` + `setBatchDonationSize(10)`) before minting; its
  existence confirms this script is only 1 of 3 changes needed for a working index-4 mint path.
- **successor** `RedeployMintPageViewV2` — treats this script's TARGET `0x64FE…` as the OLD page to
  REPLACE and bumps the view source to index 6 — the inverse of this script's intent. Direct conflict.
