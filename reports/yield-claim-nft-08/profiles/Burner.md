# Profile: src/dispatchers/Burner.sol  (V1 — CONTEXT)

- ^0.8.20 | ATokenDispatcher

## Verified Local Properties
- `dispatch` onlyMinter whenNotPaused -> `IBurnable(_token).burn(amount)` then `_burnRecorder.burn(_token, amount)`. _token/_burnRecorder immutable.
- Equivalent to BurnerV2 minus the hook + nonReentrant base.

## Interface Abstraction
- `dispatch(_,amount,_)` onlyMinter whenNotPaused -> burn + record. `primeToken() view`.

## Trust / External
- _token burnable; must be authorized burner on BurnRecorder. Trusted in-suite.
