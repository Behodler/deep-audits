<!--
C4 Submission Metadata
Title: [M-01] Cross-contract reentrancy in NFTMinter.mint() -- price state updated after external calls
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L119-L147
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

`NFTMinter.mint()` violates the Checks-Effects-Interactions (CEI) pattern by updating the price state variable (line 139) after making two external calls: `transferFrom` (line 132) and `dispatch()` (line 136). An attacker who controls a callback during `dispatch()` can re-enter `mint()` and mint additional NFTs at the stale, un-incremented price, bypassing the bonding-curve price growth mechanism entirely.

### Vulnerability details

The vulnerable code in [NFTMinter.sol#L119-L147](https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L119-L147):

```solidity
function mint(address token, uint256 index, address recipient) external returns (bool) {
    require(!paused, "Contract is paused");
    DispatcherConfig storage config = configs[index];
    require(config.dispatcher != address(0), "NFTMinter: index not registered");

    address dispatcherToken = ITokenDispatcher(config.dispatcher).primeToken();
    require(dispatcherToken == token, "NFTMinter: token mismatch");

    uint256 price = config.price;                                              // 1. Read stale price

    uint256 balanceBefore = IERC20(token).balanceOf(address(this));
    IERC20(token).transferFrom(msg.sender, address(this), price);              // 2. External call
    uint256 actualReceived = IERC20(token).balanceOf(address(this)) - balanceBefore;

    ATokenDispatcher(config.dispatcher).dispatch(address(this), actualReceived); // 3. External call (REENTRANCY VECTOR)

    config.price = price + (price * config.growthBasisPoints) / 10000;         // 4. State update AFTER external calls
    _mint(recipient, CLAIM_TOKEN_ID, 1, "");                                   // 5. ERC1155 callback

    emit ClaimMinted(recipient, index, token, price);
    return true;
}
```

The `dispatch()` call at line 136 invokes the registered `ATokenDispatcher`, which transfers tokens to a configured recipient. If the dispatcher is a `Gather` type, it forwards tokens to a recipient address via `transfer()`. When the token has transfer hooks (ERC777 `tokensReceived()`, or any token with callback-on-transfer behavior), the recipient gains execution control while `mint()` is still in progress -- before `config.price` has been updated at line 139.

The attack path:

1. Owner registers a `Gather` dispatcher with a hook-capable token. The Gather recipient is (or later becomes) a contract controlled by the attacker.
2. Attacker calls `mint()`. The function reads the current price, pulls tokens, then calls `dispatch()`.
3. Inside `dispatch()`, `Gather` transfers tokens to the attacker contract. The token's transfer hook fires `onTokenReceived()` on the attacker.
4. The attacker's callback re-enters `NFTMinter.mint()`. Because `config.price` has not been updated yet, the second `mint()` reads the same stale price.
5. This repeats for N iterations. All N mints execute at the original price.
6. When the call stack unwinds, each `mint()` frame writes `config.price = stalePrice + growth`, but they all compute the same value. The last write wins, so only a single price increment is applied instead of N.

No `nonReentrant` modifier or reentrancy guard exists on `mint()`.

### Impact

**Price curve bypass**: An attacker mints N NFTs at the initial price instead of paying the compounding growth curve. With 10% growth (1000 bps) and 3 mints, the honest cost would be `100 + 110 + 121 = 331` tokens, but the attacker pays `100` tokens three times at the stale price (and with circular token flow via Gather, recovers the tokens each time for zero net cost).

**Price state corruption**: After the attack, `config.price` reflects only one growth increment instead of N. All subsequent honest minters also pay less than intended, permanently undermining the price discovery mechanism.

**Zero-cost minting with circular flow**: When the attacker is the Gather recipient, the token flow is circular: `attacker -> minter -> gather -> attacker`. The attacker recovers all tokens paid, making the attack zero-cost while accumulating claim NFTs.

## Recommended mitigation steps

Add OpenZeppelin's `ReentrancyGuard` to `NFTMinter` and apply the `nonReentrant` modifier to `mint()`:

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMinter is ERC1155, Ownable, ITokenMinter, IPausable, ReentrancyGuard {
    // ...

    function mint(address token, uint256 index, address recipient) external nonReentrant returns (bool) {
        // ... existing logic
    }
}
```

Alternatively, reorder to follow CEI by moving the price update before the external calls:

```solidity
function mint(address token, uint256 index, address recipient) external returns (bool) {
    require(!paused, "Contract is paused");
    DispatcherConfig storage config = configs[index];
    require(config.dispatcher != address(0), "NFTMinter: index not registered");

    address dispatcherToken = ITokenDispatcher(config.dispatcher).primeToken();
    require(dispatcherToken == token, "NFTMinter: token mismatch");

    uint256 price = config.price;

    // EFFECT: Update price BEFORE external calls
    config.price = price + (price * config.growthBasisPoints) / 10000;

    // INTERACTIONS: External calls after state is finalized
    uint256 balanceBefore = IERC20(token).balanceOf(address(this));
    IERC20(token).transferFrom(msg.sender, address(this), price);
    uint256 actualReceived = IERC20(token).balanceOf(address(this)) - balanceBefore;

    ATokenDispatcher(config.dispatcher).dispatch(address(this), actualReceived);
    _mint(recipient, CLAIM_TOKEN_ID, 1, "");

    emit ClaimMinted(recipient, index, token, price);
    return true;
}
```

Both mitigations are recommended together for defense-in-depth: reorder for CEI compliance and add `nonReentrant` as a safety net.
