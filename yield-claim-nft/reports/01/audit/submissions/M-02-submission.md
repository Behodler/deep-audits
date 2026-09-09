<!--
C4 Submission Metadata
Title: [M-02] Missing zero-amount validation on actualReceived allows free NFT minting
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L180-L194
PoC File: workspace/yield-claim-nft/test/poc-M-02.t.sol
-->

## Finding description and impact

### Summary

`NFTMinter._executeMint` computes `actualReceived` via a balance-before/after pattern but never validates that `actualReceived > 0`. When the payment transfer delivers zero tokens -- whether due to a token returning `false` on failure instead of reverting, or any other edge case producing a zero delta -- the mint proceeds unconditionally: the bonding curve price advances, the dispatcher is called with `amount = 0`, and the caller receives a free claim NFT. Additionally, all ERC20 interactions across the codebase use raw `IERC20` calls without `SafeERC20`, enabling silent failures at five separate call sites.

### Vulnerability details

In [`NFTMinter._executeMint`](https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L180-L182), the payment transfer uses a raw `transferFrom` call:

```solidity
uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);
IERC20(token).transferFrom(msg.sender, config.dispatcher, price);
uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;
```

When the token returns `false` instead of reverting, the call succeeds at the EVM level, no tokens move, and `actualReceived` evaluates to zero. Execution continues to advance the bonding curve price and mint the NFT.

The same pattern affects four additional call sites:

1. [`NFTMinter.emergencyWithdraw` (line 259)](https://github.com/Behodler/yield-claim-nft/blob/master/src/NFTMinter.sol#L259) -- `IERC20(token).transfer(msg.sender, balance)` silently fails, leaving tokens stuck despite the owner believing rescue succeeded.

2. [`Gather.dispatch` (line 61)](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/Gather.sol#L61) -- `IERC20(_token).transfer(_recipient, amount)` silently fails, permanently trapping dispatched tokens in the Gather contract.

3. [`BalancerPooler.unlockCallback` (line 61)](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/BalancerPooler.sol#L61) -- `IERC20(_primeToken).transfer(_vault, primeAmount)` silently fails, causing the subsequent `addLiquidity` call to operate on zero tokens and the LP provision to produce no meaningful result.

4. [`BalancerPooler.withdrawBPT` (line 93)](https://github.com/Behodler/yield-claim-nft/blob/master/src/dispatchers/BalancerPooler.sol#L93) -- `IERC20(_pool).transfer(recipient, amount)` silently fails, preventing BPT withdrawal while emitting no error.

### Impact

When the payment token returns `false` on failure rather than reverting, an attacker can mint claim NFTs for free. Each mint still advances the bonding curve price via `config.price = price + (price * config.growthBasisPoints) / 10000`, inflating costs for legitimate users who pay the full amount. The attacker accumulates NFTs backed by zero payment, diluting the claim pool.

Beyond the minting path, silent failures in the dispatcher and emergency withdrawal functions mean tokens can become permanently stuck in contracts with no indication of failure to the caller.

## Recommended mitigation steps

Import and apply OpenZeppelin's `SafeERC20` library to all contracts that interact with ERC20 tokens. Replace all raw `transfer` and `transferFrom` calls with `safeTransfer` and `safeTransferFrom`:

```solidity
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NFTMinter {
    using SafeERC20 for IERC20;

    // In _executeMint:
    IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price);

    // In emergencyWithdraw:
    IERC20(token).safeTransfer(msg.sender, balance);
}
```

Apply the same change to `Gather.dispatch`, `BalancerPooler.unlockCallback`, and `BalancerPooler.withdrawBPT`.

As defense-in-depth, add an explicit check in `_executeMint` after the balance-before/after calculation:

```solidity
require(actualReceived > 0, "NFTMinter: zero tokens received");
```

This guards against edge cases where `safeTransferFrom` succeeds but a fee-on-transfer token delivers zero net tokens.
