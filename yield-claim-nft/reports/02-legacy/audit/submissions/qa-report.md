# QA Report: yield-claim-nft

## Summary

This report consolidates all Low severity and Centralization risk findings identified during the yield-claim-nft audit. The findings cover missing safety guards, token compatibility issues, design coupling concerns, and owner privilege risks in the NFTMinter and dispatcher subsystem.

| Severity | Count |
|----------|-------|
| Low Risk | 9 |
| Centralization Risk | 1 |
| **Total** | **10** |

---

## Low Risk Findings

### [L-01] No reentrancy guard on `_executeMint` despite ERC1155 callback to user-controlled recipient

**Severity**: Low

**Contract**: `src/NFTMinter.sol` -- `_executeMint` (lines 147-155)

**Description**: The `_executeMint` function calls `_mint()`, which triggers an `onERC1155Received` callback to the recipient. While the current implementation follows checks-effects-interactions (price is updated before the callback) and no direct economic exploit was identified, there is no explicit `nonReentrant` modifier on the function. This is a defense-in-depth concern; future code changes could introduce state that becomes exploitable through the callback without this guard in place.

**Recommendation**: Add OpenZeppelin's `nonReentrant` modifier to `_executeMint` as a defensive measure.

```solidity
function _executeMint(...) internal nonReentrant {
    // existing logic
}
```

---

### [L-02] `BalancerPooler.unlockCallback` lacks explicit reentrancy protection

**Severity**: Low

**Contract**: `src/dispatchers/BalancerPooler.sol` -- `unlockCallback` (lines 72-110)

**Description**: The `unlockCallback` function relies entirely on the Balancer vault's internal reentrancy lock for protection. There is no explicit `nonReentrant` modifier on the function itself. If the vault's lock behavior changes in a future upgrade or if the function is called in an unexpected context, the lack of an independent guard creates unnecessary risk.

**Recommendation**: Add a `nonReentrant` modifier to `unlockCallback` as defense-in-depth, independent of the vault's own reentrancy protections.

---

### [L-03] Dispatcher contracts lack token recovery mechanism -- stuck tokens permanently lost

**Severity**: Low

**Contract**: `src/dispatchers/ATokenDispatcher.sol` (lines 12-46), also affects other dispatchers

**Description**: Dispatcher contracts have no emergency withdrawal or token recovery function. Any tokens accidentally sent directly to a dispatcher contract, or dust accumulating from rounding in dispatch operations, are permanently locked. The `NFTMinter` contract has an `emergencyWithdraw()` function, but this pattern was not extended to the dispatchers. `BalancerPooler` has a `withdrawBPT()` function, but it only covers BPT tokens, not arbitrary ERC-20s that may be sent by mistake.

**Recommendation**: Add an owner-restricted `recoverToken(address token, uint256 amount)` function to each dispatcher contract, allowing the owner to retrieve accidentally stuck tokens.

```solidity
function recoverToken(address token, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(owner(), amount);
}
```

---

### [L-04] NFTMinter hardcodes `ATokenDispatcher` cast for all dispatchers

**Severity**: Low

**Contract**: `src/NFTMinter.sol` -- `_executeMint`, `setDispatcherActive` (lines 150, 208)

**Description**: `NFTMinter` casts all dispatcher addresses to the concrete `ATokenDispatcher` type when making external calls, rather than using a shared interface. This creates tight coupling between the minter and a specific dispatcher implementation. If an alternative dispatcher base is introduced that does not inherit from `ATokenDispatcher`, the cast will revert, preventing that dispatcher from being used without modifying the minter.

**Recommendation**: Define an `IDispatcher` interface with the required external methods and use that for all dispatcher interactions in `NFTMinter`. This decouples the minter from any specific dispatcher implementation.

---

### [L-05] All claim NFTs minted with the same token ID regardless of payment context

**Severity**: Low

**Contract**: `src/NFTMinter.sol` -- `_executeMint` (lines 14, 153)

**Description**: Every claim NFT is minted with `CLAIM_TOKEN_ID = 1`. There is no on-chain distinction between NFTs minted at different prices, through different dispatchers, or at different points in the price curve. Early minters who paid a lower price receive a claim token functionally identical to later minters who paid significantly more. This makes it impossible to differentiate claim entitlements on-chain without relying on off-chain indexing of mint events.

**Recommendation**: Consider using incrementing token IDs or encoding the dispatcher index and mint price into the token ID or metadata. This would allow on-chain differentiation of claims and support more granular yield distribution logic if needed in the future.

---

### [L-06] Owner can set price to zero, permanently breaking the multiplicative growth formula

**Severity**: Low

**Contract**: `src/NFTMinter.sol` -- `setPrice` (lines 178-183)

**Description**: The `setPrice` function has no minimum price validation. If the owner sets the price to zero, the multiplicative growth formula (`0 * growthBasisPoints / 10000 = 0`) will always evaluate to zero, keeping the price at zero permanently. This allows unlimited free minting and cannot be corrected by adjusting `growthBasisPoints` alone -- the price must be explicitly reset to a non-zero value.

**Recommendation**: Enforce a minimum price floor in `setPrice`.

```solidity
function setPrice(uint256 newPrice) external onlyOwner {
    require(newPrice > 0, "Price must be non-zero");
    price = newPrice;
    emit PriceUpdated(newPrice);
}
```

---

### [L-07] Missing `SafeERC20` causes permanent revert for USDT and non-bool-returning tokens

**Severity**: Low

**Contract**: `src/NFTMinter.sol` -- `_executeMint` (line 142), `emergencyWithdraw` (line 198); also `src/dispatchers/BalancerPooler.sol` (lines 79, 85) and `src/dispatchers/Gather.sol` (line 60)

**Description**: The codebase uses raw `IERC20` interface calls (`transfer`, `transferFrom`) without OpenZeppelin's `SafeERC20` wrapper. USDT and certain other tokens return `void` instead of `bool` on transfer calls, which causes an ABI decoding revert when the caller expects a boolean return value. Any dispatcher registered with such a token would be permanently non-functional, as every mint and withdrawal attempt would revert.

**Recommendation**: Import and use `SafeERC20` for all ERC-20 interactions across the codebase.

```solidity
using SafeERC20 for IERC20;

// Replace:
token.transfer(to, amount);
// With:
token.safeTransfer(to, amount);
```

---

### [L-08] Price growth calculated on gross price instead of `actualReceived` for fee-on-transfer tokens

**Severity**: Low

**Contract**: `src/NFTMinter.sol` -- `_executeMint` (lines 138-147)

**Description**: When fee-on-transfer (FOT) tokens are used, the price growth formula is applied to the full gross price rather than the `actualReceived` amount after the FOT deduction. Over many mints, this causes the nominal price to escalate faster than the actual value collected by the protocol, creating a growing divergence between the advertised price and the real economic value behind each claim NFT.

**Recommendation**: Apply the growth formula to `actualReceived` rather than the gross price when FOT tokens are detected, or document that FOT tokens are not supported and add a validation check during dispatcher registration.

---

### [L-09] Unchecked 1:1 phUSD minting with UNBALANCED addLiquidity causes suboptimal BPT returns when pool ratio diverges

**Severity**: Low

**Contract**: `src/dispatchers/BalancerPooler.sol` -- `unlockCallback` (lines 82-107)

**Description**: The `BalancerPooler` always mints phUSD at a fixed 1:1 decimal-normalized ratio to the prime token via `_normalizeToPhUSD()` and adds both as `UNBALANCED` liquidity to a Balancer V3 pool. When the pool's actual ratio diverges from 1:1, the unbalanced deposit results in fewer BPT than the fair value of the deposited tokens, with the excess effectively donated to existing LPs. While the NatSpec documents this as intended behavior ("adds unbalanced liquidity"), the economic cost of the 1:1 ratio mismatch grows with pool divergence. At a 4:1 pool ratio, the protocol receives ~38% fewer BPT than baseline.

**Note**: Downgraded from Medium. The unbalanced addLiquidity and 1:1 phUSD minting ratio appear to be intentional design choices documented in the contract's NatSpec. The BPT accrues to the contract, not to users, and no direct attacker exists. This is a design observation about the economic trade-offs of the chosen approach.

**Recommendation**: Consider adding a configurable minimum BPT tolerance or using proportional addLiquidity when pool ratio diverges significantly from 1:1.

---

## Centralization Risks

### [C-01] Uncapped `growthBasisPoints` allows owner to effectively halt minting via price escalation

**Severity**: Centralization Risk

**Contract**: `src/NFTMinter.sol` -- `setGrowthFactor` (lines 186-191)

**Description**: There is no upper bound on `growthBasisPoints`. The owner can set an extreme growth rate (e.g., 10000 bps = 100% per mint), which would cause the price to double with each mint, making minting prohibitively expensive within just a few transactions. Combined with the fact that price changes are irreversible (the growth formula only increases the price), this functions as a non-obvious kill switch that can permanently halt new minting.

**Impact**: Users who expected to mint at a reasonable price trajectory could be priced out abruptly. Since price only increases, the owner cannot undo the effect by lowering `growthBasisPoints` after the price has already escalated.

**Recommendation**: Enforce a reasonable upper bound on `growthBasisPoints` (e.g., 1000 bps = 10%) to prevent abusive escalation while still allowing meaningful price growth configuration.

```solidity
uint256 public constant MAX_GROWTH_BPS = 1000; // 10%

function setGrowthFactor(uint256 newGrowthBps) external onlyOwner {
    require(newGrowthBps <= MAX_GROWTH_BPS, "Growth too high");
    growthBasisPoints = newGrowthBps;
    emit GrowthFactorUpdated(newGrowthBps);
}
```

---
