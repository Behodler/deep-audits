<!--
C4 Submission Metadata
Title: [H-01] Missing access control on dispatcher dispatch() allows anyone to drain tokens from NFTMinter
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/ATokenDispatcher.sol#L44
PoC File: poc-H-01.t.sol
-->

## Finding description and impact

### Summary

The `dispatch()` function in `ATokenDispatcher` and all concrete dispatcher implementations (`Gather`, `Burner`, `BalancerPooler`) is `external` with only a `whenNotPaused` modifier and no caller restriction. Because `NFTMinter.registerDispatcher()` grants each dispatcher `type(uint256).max` token approval, any external account can call `dispatch(nftMinterAddress, amount)` on any registered dispatcher to forcibly pull all ERC20 tokens out of the `NFTMinter` contract.

### Vulnerability details

The root cause is in [`ATokenDispatcher.sol#L44`](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/ATokenDispatcher.sol#L44), where `dispatch()` is declared with no access control:

```solidity
// ATokenDispatcher.sol L41-44
/// @notice Executes the dispatch logic. Reverts if the dispatcher is paused.
/// @param minter The NFTMinter contract address.
/// @param amount The amount of prime token that was paid for this mint.
function dispatch(address minter, uint256 amount) external virtual whenNotPaused {}
```

The contract defines an `onlyMinter` modifier (L17-20) that restricts access to the authorized minter address, and this modifier is correctly applied to `pause()` and `unpause()`. However, it is not applied to `dispatch()`:

```solidity
// ATokenDispatcher.sol L17-20
modifier onlyMinter() {
    require(msg.sender == _minter, "ATokenDispatcher: caller is not minter");
    _;
}

// L32-38 -- onlyMinter IS applied here
function pause() external onlyMinter { _pause(); }
function unpause() external onlyMinter { _unpause(); }

// L44 -- onlyMinter is NOT applied here
function dispatch(address minter, uint256 amount) external virtual whenNotPaused {}
```

All concrete dispatchers (`Gather`, `Burner`) inherit and override `dispatch()` without adding access control. For example, [`Gather.sol#L60`](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/Gather.sol#L60):

```solidity
// Gather.sol L60-68
function dispatch(address minter, uint256 amount) external override whenNotPaused {
    uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
    IERC20(_token).transferFrom(minter, address(this), amount);
    uint256 actualReceived = IERC20(_token).balanceOf(address(this)) - balanceBefore;
    IERC20(_token).transfer(_recipient, actualReceived);
}
```

The second prerequisite is that `NFTMinter.registerDispatcher()` grants unlimited token approval to each registered dispatcher at [`NFTMinter.sol#L106`](https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L106):

```solidity
// NFTMinter.sol L105-106
// Approve the prime token for the dispatcher (so dispatcher can pull it from minter)
IERC20(token).approve(dispatcher, type(uint256).max);
```

This creates a permanent, unlimited allowance from `NFTMinter` to every registered dispatcher. The intended flow is that only `NFTMinter.mint()` calls `dispatch()` (L136), but because `dispatch()` has no caller restriction, anyone can invoke it directly.

**Attack path:**

1. The protocol owner deploys `NFTMinter` and registers an `Accumulator` dispatcher (a no-op that leaves tokens in the minter) and a `Gather` dispatcher (which forwards tokens to a configured recipient).
2. Legitimate users call `NFTMinter.mint()` via the `Accumulator` dispatcher, paying ERC20 tokens that accumulate inside `NFTMinter`.
3. An attacker (any EOA, with zero tokens and zero NFTs) calls `Gather.dispatch(nftMinterAddress, accumulatedBalance)` directly.
4. `Gather` executes `transferFrom(minter, address(this), amount)`, which succeeds because `NFTMinter` previously approved `Gather` for `type(uint256).max`. All tokens are pulled from the minter and forwarded to Gather's recipient.
5. Alternatively, the attacker calls `Burner.dispatch(nftMinterAddress, amount)` to irreversibly burn all accumulated tokens.

The same attack vector applies to the `Burner` dispatcher at [`Burner.sol#L32`](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/Burner.sol#L32), where tokens pulled from the minter are permanently burned.

### Impact

This vulnerability enables direct theft of all ERC20 tokens held by `NFTMinter`. The consequences are:

- **Complete fund loss**: Every token accumulated from user mints via the `Accumulator` dispatcher (intended for later consumption by `BalancerPooler`) can be drained in a single transaction.
- **No special access required**: Any externally owned account can execute the attack. The attacker does not need to hold any tokens, NFTs, or special roles.
- **Irreversible in burn path**: If the attacker calls `Burner.dispatch()`, the tokens are permanently destroyed with no recovery path.
- **Immediate exploitability**: The vulnerability is exploitable as soon as any user mints an NFT via the `Accumulator` dispatcher, causing tokens to accumulate in the minter.

## Recommended mitigation steps

Apply the `onlyMinter` modifier to the `dispatch()` function in `ATokenDispatcher`. This restricts callers to the authorized minter address, ensuring that only `NFTMinter.mint()` can trigger token dispatch:

```diff
// ATokenDispatcher.sol
- function dispatch(address minter, uint256 amount) external virtual whenNotPaused {}
+ function dispatch(address minter, uint256 amount) external virtual onlyMinter whenNotPaused {}
```

Because the concrete dispatchers (`Gather`, `Burner`, `Accumulator`, `BalancerPooler`) all use `override` on their `dispatch()` implementations, the `onlyMinter` modifier on the base function will enforce that all overrides respect it as long as they also include it. Each override should be updated:

```diff
// Gather.sol
- function dispatch(address minter, uint256 amount) external override whenNotPaused {
+ function dispatch(address minter, uint256 amount) external override onlyMinter whenNotPaused {

// Burner.sol
- function dispatch(address minter, uint256 amount) external override whenNotPaused {
+ function dispatch(address minter, uint256 amount) external override onlyMinter whenNotPaused {

// Accumulator.sol
- function dispatch(address, uint256) external override whenNotPaused {
+ function dispatch(address, uint256) external override onlyMinter whenNotPaused {
```

Alternatively, if the intention is to allow the base contract to enforce access control without requiring each override to repeat the modifier, the base `dispatch()` can use the non-virtual pattern with an internal `_dispatch()` hook:

```solidity
// ATokenDispatcher.sol -- alternative pattern
function dispatch(address minter, uint256 amount) external onlyMinter whenNotPaused {
    _dispatch(minter, amount);
}

function _dispatch(address minter, uint256 amount) internal virtual {}
```

This approach centralizes the access check and eliminates the risk of a future dispatcher implementation omitting the modifier.
