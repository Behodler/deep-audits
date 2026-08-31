# Profile: src/dispatchers/Gather.sol  (V1 — CONTEXT)

- ^0.8.20 | ATokenDispatcher

## Verified Local Properties
- `dispatch` onlyMinter whenNotPaused -> `safeTransfer(_recipient, amount)`. _recipient non-zero in ctor + setter; _token immutable.
- Equivalent to GatherV2 minus hook + nonReentrant base.

## Interface Abstraction
- `dispatch(_,amount,_)` onlyMinter whenNotPaused -> forward to recipient. `setRecipient(addr) onlyOwner` (non-zero). `recipient()/primeToken()` views.

## Trust / External
- Owner controls recipient (all gathered funds). standard ERC20. Owner trusted (OOS).
