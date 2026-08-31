# Profile: src/V2/dispatchers/GatherV2.sol

- solidityVersion: ^0.8.20
- inheritanceChain: ATokenDispatcherV2 (Pausable, Ownable, ReentrancyGuard)
- LOC: 63 | PRIMARY

## Verified Local Properties
- accessControlled: dispatch (inherited onlyMinter/whenNotPaused/nonReentrant), setRecipient (onlyOwner).
- `_recipient` non-zero enforced in constructor and setter.
- `_token` immutable. noUnboundedLoops/checkedArithmetic: true.

## Local Findings

### LOCAL-011 — constructor lacks zero-address check for token_ (local-low/QA)
- recipient_ is checked non-zero; token_ is not. Misconfiguration bricks dispatch; no loss.

## Interface Abstraction
- `_dispatch(_, amount, _)` — `IERC20(_token).safeTransfer(_recipient, amount)`. Forwards FOT-adjusted amount already on contract.
- `setRecipient(address) onlyOwner` (non-zero).
- `recipient() view`, `primeToken() view -> _token`.
- inherits base dispatch/hook/pause/setMinter/setHook/setMetadata.

## External Calls / Trust Boundaries
- `IERC20(_token).safeTransfer(_recipient, amount)` — standard ERC20.

## Trust Assumptions
- Owner controls `_recipient` (where all gathered tokens flow). Owner trusted (OOS).
