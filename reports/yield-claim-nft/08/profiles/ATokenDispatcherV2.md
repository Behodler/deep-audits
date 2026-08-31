# Profile: src/V2/dispatchers/ATokenDispatcherV2.sol

- solidityVersion: ^0.8.20
- inheritanceChain: ITokenDispatcherV2, Pausable, Ownable, ReentrancyGuard (abstract)
- LOC: 133 | PRIMARY (base for all V2 dispatchers)

## Verified Local Properties
- accessControlled: setMetadata/setMinter/setHook (onlyOwner), pause/unpause (onlyMinter).
- reentrancyGuarded: external `dispatch` is `nonReentrant onlyMinter whenNotPaused`. Template-method: concrete dispatchers override internal `_dispatch` and MUST NOT re-add these modifiers.
- `hook` invariant: never zero. Constructor deploys a `DefaultDispatchHook`; `setHook` rejects address(0). Dispatch path is branch-free (`hook.onDispatch(...)` always callable).
- noUnboundedLoops: true.

## Local Findings
- None confirmable at the abstract level.

### Note (verified, not a finding)
- `dispatch` calls `_dispatch(...)` THEN `hook.onDispatch(...)`, both inside the single `nonReentrant` scope. A malicious/misbehaving hook can revert dispatch (DoS) — documented design; owner swaps hook via setHook. A reentrant hook cannot re-enter `dispatch` (guard) but COULD re-enter other non-guarded functions on the minter — see NFTMinterV2 LOCAL-002. Reentrancy reachability is a cross-contract concern → DEFER.

## Interface Abstraction
- `dispatch(address minter, uint256 amount, bytes extraData) external nonReentrant onlyMinter whenNotPaused` — runs concrete `_dispatch` then `hook.onDispatch(minter, amount, extraData)`.
- `_dispatch(address,uint256,bytes) internal virtual` — overridden by concretes; default no-op.
- `setHook(IDispatchHook) onlyOwner` (non-zero), `setMinter(address) onlyOwner`, `setMetadata(...) onlyOwner`, `pause()/unpause() onlyMinter`.
- views: name/image/description, hook, paused.

## Trust Assumptions
- `_minter` is the NFTMinterV2 (set by owner via setMinter). Only the minter may trigger dispatch and pause/unpause.
- `hook` is owner-controlled; a hook revert bricks dispatch until swapped. Owner trusted (OOS).
- DOWNSTREAM: the hook receives `(minter, amount, extraData)` and runs INSIDE the dispatch (and thus inside the user's mint tx). The BalancerPoolerMintDebtHook installed here accrues phUSD debt on every dispatch.
