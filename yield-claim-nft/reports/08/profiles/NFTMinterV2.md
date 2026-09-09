# Profile: src/V2/NFTMinterV2.sol

- solidityVersion: ^0.8.20
- inheritanceChain: ERC1155Supply, ERC1155, Ownable, INFTMinterV2, IPausable
- LOC: 346 | functions: ~22 | stateVars: many (configs, mappings, pauser, paused, nextIndex)
- PRIMARY

## Verified Local Properties
- checkedArithmetic: true (0.8.20). Price growth `price + price*growthBasisPoints/10000` is unchecked-free; owner controls growthBasisPoints (compounding growth documented design, OOS).
- noUnboundedLoops: true (no loops).
- accessControlled: registerDispatcher, setDispatcherDisabled, setAuthorizedMinter, replaceDispatcher, setPrice, setGrowthFactor, emergencyWithdraw, setDispatcherActive, setAuthorizedBurner, setPauser (onlyOwner). pause/unpause (only pauser). mintFor (authorizedMinters). burn (authorizedBurners).
- initializerProtected: n/a (not upgradeable; constructor only).
- H-01 fix verified: `_executeMint` fetches `token` from `dispatcher.primeToken()` rather than caller-supplied — caller cannot spoof the payment token.
- FOT safety: balance-before/after around safeTransferFrom; `actualReceived` forwarded to dispatch.
- CEI: price grown before external dispatch call. `_mint` (NFT) happens after dispatch.
- `nextIndex` starts at 1; index 0 is sentinel for "unregistered" across configs / dispatcherToIndex.
- tokenId == dispatcher index (resolvedTokenId = index).

## Local Findings

### LOCAL-002 — mint() not reentrancy-guarded; relies on dispatcher's nonReentrant (informational/defer)
- function: _executeMint (line 170-201)
- NFTMinterV2 itself has no ReentrancyGuard. After `safeTransferFrom` and before `_mint`, it calls `ATokenDispatcherV2.dispatch(...)`, which is `nonReentrant` on the dispatcher (not on the minter). The dispatcher's hook (`onDispatch`) could in principle re-enter `NFTMinterV2.mint` (different dispatcher index) since the minter has no guard. State effects (price growth) are applied before the dispatch call (CEI), and `_mint` mints exactly 1 NFT after. No local invariant is broken by reentry (each mint pays its own price + grows its own config). Cross-contract reentrancy exploitability depends on hook behaviour — DEFER to interaction analysis. Flagging as a trust boundary, not a confirmed local bug.

### LOCAL-003 — mintFor mints with no payment and no supply/price effect (by-design, note)
- function: mintFor (line 206-214)
- authorizedMinters can mint claim NFTs free of charge and without dispatch/price update. This is the migration path (NFTMigrator is the intended authorizedMinter). Centralization/authorized-role surface; not a local bug. NOTE for downstream: free minting power = whoever is an authorizedMinter can mint unlimited claim NFTs of any registered index.

## Interface Abstraction
- `mint(uint256 index, address recipient) external returns(bool)` / `mint(uint256 index, address recipient, bytes extraData)` — requires !paused, index registered, !disabled. Pulls `config.price` of `dispatcher.primeToken()` from msg.sender to dispatcher (FOT-adjusted). Grows price. Calls `dispatcher.dispatch(this, actualReceived, extraData)`. Mints 1 NFT (tokenId=index) to recipient. External calls: primeToken() (view), token.balanceOf/safeTransferFrom, dispatcher.dispatch.
- `mintFor(uint256 index, address recipient)` — authorizedMinters only. Mints 1 NFT, no payment/dispatch.
- `burn(address holder, uint256 tokenId, uint256 quantity)` — authorizedBurners only. _burn.
- `registerDispatcher / replaceDispatcher / setDispatcherDisabled / setDispatcherActive / setPrice / setGrowthFactor / setAuthorizedMinter / setAuthorizedBurner / setPauser / emergencyWithdraw` — onlyOwner.
- `pause()/unpause()` — pauser only.
- `uri(id)` — reads dispatcher name/image/description; returns "" if unmapped.
- views: configs, dispatcherToIndex, tokenIdToDispatcher, getPrice, nextIndex, authorizedBurners, authorizedMinters, paused, pauser.

## External Calls / Trust Boundaries
- `ITokenDispatcherV2(dispatcher).primeToken()` — authoritative token source.
- `IERC20(token)` balanceOf/safeTransferFrom/safeTransfer — assumed standard ERC20 (FOT handled; non-standard/dodgy tokens OOS).
- `ATokenDispatcherV2(dispatcher).dispatch(...)` and `.pause()/.unpause()/.paused()`.
- mintFor caller = authorizedMinters (NFTMigrator). burn caller = authorizedBurners.

## Trust Assumptions
- Owner registers/replaces dispatchers, sets prices/growth, authorizes minters/burners, emergency-withdraws. Owner trusted (OOS).
- pauser is a separate trusted role (global pauser).
- DOWNSTREAM: `replaceDispatcher` can swap the dispatcher behind an existing tokenId/index — existing NFTs keep their tokenId but their `dispatcher`/`primeToken`/redemption semantics change. Interaction scanners should consider redemption-mapping integrity across a replace.
