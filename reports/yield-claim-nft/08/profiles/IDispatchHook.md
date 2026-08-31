# Profile: src/V2/interfaces/IDispatchHook.sol

- solidityVersion: ^0.8.20 | interface | PRIMARY

## Interface Abstraction
- `onDispatch(address minter, uint256 amount, bytes extraData) external` — observation hook invoked by ATokenDispatcherV2.dispatch AFTER _dispatch, with the same tuple. NatSpec: implementations must not rely on dispatcher storage and must tolerate arbitrary extraData; a reverting hook reverts the enclosing dispatch.

## Notes for Downstream
- Two known implementations in scope: DefaultDispatchHook (no-op) and BalancerPoolerMintDebtHook (phUSD debt accrual). Hook runs inside the dispatch reentrancy scope on the dispatcher (not the minter).
