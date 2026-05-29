# Profile: src/V2/hooks/DefaultDispatchHook.sol

- solidityVersion: ^0.8.20
- inheritanceChain: IDispatchHook
- LOC: 13 | PRIMARY

## Verified Local Properties
- `onDispatch(address,uint256,bytes)` is an empty no-op (null-object). No state, no external calls, never reverts. Cannot be exploited.

## Interface Abstraction
- `onDispatch(...) external` — does nothing, returns.

## Trust Assumptions
- None. Deployed by ATokenDispatcherV2 constructor so `hook` is never zero until owner swaps it.
