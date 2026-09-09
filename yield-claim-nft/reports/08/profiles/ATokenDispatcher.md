# Profile: src/dispatchers/ATokenDispatcher.sol  (V1 — CONTEXT)

- ^0.8.20 | ITokenDispatcher, Pausable, Ownable (abstract). No ReentrancyGuard, no hook (V2 added both).

## Verified Local Properties
- `dispatch` external virtual onlyMinter whenNotPaused (overridden by concretes — V1 puts modifiers ON the override, unlike V2's template-method split).
- owner: setMetadata/setMinter; minter: pause/unpause. primeToken in V1 interface (V2 removed from interface but concretes keep it).

## Interface Abstraction
- `dispatch(minter,amount,extraData)` onlyMinter whenNotPaused (no nonReentrant in V1).
- setMinter/setMetadata (owner), pause/unpause (minter), name/image/description/primeToken views.

## Trust Assumptions
- _minter = NFTMinter (V1). No reentrancy guard at base — V1 concretes (Burner/Gather/BalancerPooler) rely on their own flows. Owner/minter trusted.
