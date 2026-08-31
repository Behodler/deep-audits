# Profile: src/V2/dispatchers/BurnerV2.sol

- solidityVersion: ^0.8.20
- inheritanceChain: ATokenDispatcherV2 (Pausable, Ownable, ReentrancyGuard)
- LOC: 40 | PRIMARY

## Verified Local Properties
- accessControlled: dispatch (inherited onlyMinter, whenNotPaused, nonReentrant).
- `_token` and `_burnRecorder` immutable.
- noUnboundedLoops, checkedArithmetic: true.

## Local Findings

### LOCAL-010 — constructor lacks zero-address checks for token_/burnRecorder_ (local-low/QA)
- Misconfiguration bricks dispatch; no loss. Deployment concern.

### Note
- `_dispatch` burns `amount` (FOT-adjusted, passed from minter) via `IBurnable(_token).burn(amount)` then `_burnRecorder.burn(_token, amount)`. Tokens must already be on this contract (minter transferred them). If `_token.burn(amount)` burns from this contract's balance, the FOT-adjusted `actualReceived` is the correct amount. Burner must be an authorized burner on BurnRecorder (else burn() reverts).

## Interface Abstraction
- `_dispatch(_, amount, _)` — `IBurnable(_token).burn(amount)`; `_burnRecorder.burn(_token, amount)`.
- `primeToken() view -> _token`.
- inherits base dispatch/hook/pause/setMinter/setHook/setMetadata.

## External Calls / Trust Boundaries
- `IBurnable(_token).burn(amount)` — token must expose burn(uint256) burning from msg.sender (this dispatcher). Trusted in-suite token.
- `IBurnRecorder.burn(_token, amount)` — requires this dispatcher to be authorized burner on BurnRecorder.

## Trust Assumptions
- _token is a burnable protocol token; _burnRecorder is the shared BurnRecorder. Owner/deployer wires authorizations.
