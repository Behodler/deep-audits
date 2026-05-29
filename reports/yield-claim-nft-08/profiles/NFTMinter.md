# Profile: src/NFTMinter.sol  (V1 — CONTEXT)

- solidityVersion: ^0.8.20 | ERC1155Supply, Ownable, INFTMinter, IPausable

## Verified Local Properties
- Mirrors NFTMinterV2 but `mint(address token, uint256 index, address recipient,[extraData])` takes a caller-supplied `token` and validates `dispatcherToken == token` (the V1 form of the H-01 mitigation). V2 dropped the param and reads primeToken directly.
- accessControlled owner setters + pauser pause/unpause + authorizedBurners burn. No mintFor / authorizedMinters in V1.
- FOT balance-before/after; CEI (price grown before dispatch).
- Extra mapping `_tokenToIndexes[token]` + `getDispatchers(token)` view (V2 removed this).
- tokenId == index.

## Local Findings (context only)
- No new local findings beyond shared owner/pauser centralization (OOS). No mintFor in V1, so the free-mint surface is V2-only.

## Interface Abstraction
- `mint(address token, uint256 index, address recipient)` / overload with extraData — requires !paused, registered, !disabled, token==dispatcher.primeToken; pulls price, grows, dispatches, mints 1 NFT.
- `burn(holder,tokenId,quantity)` authorizedBurners only.
- owner: registerDispatcher/setDispatcherDisabled/setDispatcherActive/setPrice/setGrowthFactor/setPauser/emergencyWithdraw/setAuthorizedBurner.
- pauser: pause/unpause. views: configs/getPrice/getDispatchers/tokenIdToDispatcher/dispatcherToIndex/nextIndex.

## Trust Assumptions
- Owner + pauser trusted (OOS). NFTMigrator must be an authorizedBurner here to burn user V1 NFTs during migration. DOWNSTREAM: V1 `nextIndex` drives the migrator's loop bound and setInitialized validation.
