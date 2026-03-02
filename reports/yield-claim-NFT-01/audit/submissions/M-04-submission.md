<!--
C4 Submission Metadata
Title: [M-04] Irrevocable infinite token approval to dispatchers with no deregistration mechanism
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L106
PoC File: poc-M-04.t.sol
-->

## Finding description and impact

### Summary

`NFTMinter.registerDispatcher()` grants `type(uint256).max` ERC20 approval to each registered dispatcher, but no function exists to revoke this approval or deregister a dispatcher. The `setDispatcherActive(false)` function only toggles the dispatcher's `Pausable` state and does not touch the underlying ERC20 allowance, leaving a permanently open token-drain vector that the owner cannot remediate.

### Vulnerability details

When a dispatcher is registered, `NFTMinter` grants it an unlimited, irrevocable token approval at [NFTMinter.sol#L95-L116](https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L95-L116):

```solidity
function registerDispatcher(address dispatcher, uint256 initialPrice, uint256 growthBasisPoints) external onlyOwner {
    require(dispatcher != address(0), "NFTMinter: zero dispatcher address");
    require(dispatcherToIndex[dispatcher] == 0, "NFTMinter: dispatcher already registered");

    uint256 index = nextIndex;
    nextIndex++;

    address token = ITokenDispatcher(dispatcher).primeToken();

    // @audit Unlimited approval -- never revoked anywhere in the contract
    IERC20(token).approve(dispatcher, type(uint256).max);

    configs[index] = DispatcherConfig({dispatcher: dispatcher, price: initialPrice, growthBasisPoints: growthBasisPoints});
    dispatcherToIndex[dispatcher] = index;
    _tokenToIndexes[token].push(index);

    emit DispatcherRegistered(index, dispatcher, token, initialPrice, growthBasisPoints);
}
```

The only administrative action available for an existing dispatcher is `setDispatcherActive`, which merely pauses or unpauses the dispatcher contract via OpenZeppelin's `Pausable` mechanism at [NFTMinter.sol#L194-L209](https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L194-L209):

```solidity
function setDispatcherActive(address dispatcher, bool active) external onlyOwner {
    require(dispatcherToIndex[dispatcher] != 0, "NFTMinter: dispatcher not registered");

    ATokenDispatcher dispatcherContract = ATokenDispatcher(dispatcher);

    if (active) {
        if (dispatcherContract.paused()) {
            dispatcherContract.unpause();
        }
    } else {
        if (!dispatcherContract.paused()) {
            dispatcherContract.pause();
        }
    }
}
```

This function does not call `IERC20(token).approve(dispatcher, 0)` and there is no `deregisterDispatcher()`, `revokeApproval()`, or any other mechanism to reduce the allowance. The `emergencyWithdraw` function transfers tokens out but likewise does not revoke approvals, so any tokens subsequently sent to the minter (e.g., from future mints) remain exposed.

This approval is:

1. **Unlimited** -- `type(uint256).max` allowance.
2. **Irrevocable** -- No function in `NFTMinter` can set it to zero.
3. **Permanent** -- No deregistration mechanism exists.
4. **Independent of pause state** -- `setDispatcherActive(false)` does not touch the ERC20 allowance.

The consequence is that a "paused" dispatcher retains full ability to call `transferFrom` on the minter's token balance. Combined with H-01 (missing access control on `dispatch()`), any caller can invoke `dispatch()` on the dispatcher contract directly -- bypassing `NFTMinter`'s `whenNotPaused` guard -- because the underlying ERC20 approval is still live.

Even if H-01 is independently fixed, this finding stands on its own: a compromised or upgraded dispatcher contract can drain the minter at any time, and the owner has no way to revoke the approval short of deploying a new `NFTMinter` and migrating all state.

### Impact

- **Pausing is an insufficient emergency response.** If a dispatcher is found to be vulnerable or compromised, the owner's only recourse (`setDispatcherActive(false)`) does not actually prevent token drainage because the ERC20 approval persists.
- **Growing, irreversible attack surface.** Each new dispatcher registration permanently adds another address with unlimited withdrawal rights over the minter's token balance.
- **Compounding risk with H-01.** The irrevocable approval converts the missing access control on `dispatch()` into an immediate fund-drain vector that cannot be mitigated by pausing.
- **No safe recovery path.** The owner cannot revoke approvals, deregister dispatchers, or otherwise reduce exposure without redeploying the entire minter contract.

## Recommended mitigation steps

Implement approval revocation in `setDispatcherActive` and add a `deregisterDispatcher` function:

```solidity
function setDispatcherActive(address dispatcher, bool active) external onlyOwner {
    require(dispatcherToIndex[dispatcher] != 0, "NFTMinter: dispatcher not registered");

    ATokenDispatcher dispatcherContract = ATokenDispatcher(dispatcher);
    address token = dispatcherContract.primeToken();

    if (active) {
        if (dispatcherContract.paused()) {
            dispatcherContract.unpause();
        }
        // Restore approval when reactivating
        IERC20(token).approve(dispatcher, type(uint256).max);
    } else {
        if (!dispatcherContract.paused()) {
            dispatcherContract.pause();
        }
        // Revoke approval when deactivating
        IERC20(token).approve(dispatcher, 0);
    }
}

function deregisterDispatcher(address dispatcher) external onlyOwner {
    uint256 index = dispatcherToIndex[dispatcher];
    require(index != 0, "NFTMinter: dispatcher not registered");

    address token = ITokenDispatcher(dispatcher).primeToken();

    // Revoke token approval
    IERC20(token).approve(dispatcher, 0);

    // Clean up state
    delete configs[index];
    delete dispatcherToIndex[dispatcher];

    emit DispatcherDeregistered(index, dispatcher, token);
}
```

As an additional defense-in-depth measure, consider replacing unlimited approvals with per-dispatch approvals sized to the actual transfer amount. This limits exposure even if a dispatcher is compromised between transactions.
