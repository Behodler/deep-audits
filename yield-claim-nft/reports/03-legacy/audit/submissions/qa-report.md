# QA Report: yield-claim-NFT (Round 3)

## Summary

This QA report consolidates all Low severity and Centralization risk findings for the yield-claim-NFT project across three audit rounds. Findings from rounds 1 and 2 that remain applicable to the current codebase are included alongside new findings from round 3. One previous Low finding (L-05, all claim NFTs sharing the same token ID) has been fixed via `setDispatcherTokenId`, and one previous Medium (M-02, 1:1 phUSD minting) is moot following the removal of phUSD from BalancerPooler.

| Severity | Count |
|----------|-------|
| Low Risk | 13 |
| Centralization | 3 |
| **Total** | **16** |

---

## Low Risk Findings

### [L-01] No reentrancy guard on `_executeMint` despite ERC1155 callback

**Location**: [NFTMinter.sol#L185-L223](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L185-L223)

**Description**: `_executeMint()` calls `_mint(recipient, resolvedTokenId, 1, "")` at L218, which triggers the `onERC1155Received` callback on the recipient if it is a contract. While the price state is updated before the mint (CEI pattern at L206), and no direct exploit path exists, the function lacks a `nonReentrant` modifier as a defense-in-depth measure.

**Impact**: No current exploit due to CEI ordering. However, future code changes that add state reads after the `_mint` call could introduce reentrancy vulnerabilities without the guard serving as a safety net.

**Recommendation**: Add OpenZeppelin's `ReentrancyGuard` and apply the `nonReentrant` modifier to `_executeMint`.

---

### [L-02] `BalancerPooler.unlockCallback` lacks explicit reentrancy protection

**Location**: [BalancerPooler.sol#L54-L87](https://github.com/example/yield-claim-nft/blob/main/src/dispatchers/BalancerPooler.sol#L54-L87)

**Description**: The `unlockCallback` function performs external calls to the Balancer vault (transfer, addLiquidity, settle) without a reentrancy guard. The Balancer V3 vault provides its own reentrancy protection via the unlock pattern, but the dispatcher contract itself has no redundant guard.

**Impact**: No current exploit -- the vault's `require(msg.sender == _vault)` check at L55 and the vault's own locking mechanism prevent unauthorized reentry. This is a defense-in-depth concern.

**Recommendation**: Add a `nonReentrant` modifier to `unlockCallback` as a secondary safeguard.

---

### [L-03] Dispatcher contracts lack token recovery mechanism

**Location**: All dispatchers (`BalancerPooler.sol`, `Gather.sol`, `Burner.sol`)

**Description**: Tokens accidentally sent directly to dispatcher contracts (not via the minting flow) become permanently stuck. `BalancerPooler` has `withdrawBPT` (L92-L94) for the pool token only, but no generic recovery for other ERC20 tokens. `Gather` and `Burner` have no recovery mechanism at all.

**Impact**: Any tokens sent to dispatcher addresses by mistake are irrecoverable. This includes both the prime token and unrelated ERC20 tokens.

**Recommendation**: Add an `emergencyWithdraw` function (similar to NFTMinter's at L280-L285) to the `ATokenDispatcher` base contract, restricted to `onlyOwner`.

---

### [L-04] NFTMinter hardcodes `ATokenDispatcher` cast

**Location**: [NFTMinter.sol#L209](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L209), [NFTMinter.sol#L293-L294](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L293-L294)

**Description**: `_executeMint` casts `config.dispatcher` to `ATokenDispatcher` at L209 rather than using the `ITokenDispatcher` interface. Similarly, `setDispatcherActive` casts to `ATokenDispatcher` at L293. This creates tight coupling between NFTMinter and the concrete abstract class.

**Impact**: No security impact. Any future dispatcher that does not inherit from `ATokenDispatcher` would fail at these call sites even if it correctly implements the `ITokenDispatcher` interface, limiting extensibility.

**Recommendation**: Define `dispatch`, `pause`, `unpause`, and `paused` on the `ITokenDispatcher` interface and use the interface type for all casts.

---

### [L-06] Owner can set price to zero, breaking the growth formula

**Location**: [NFTMinter.sol#L263-L268](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L263-L268)

**Description**: `setPrice` accepts `newPrice = 0` without validation. When `price = 0`, the growth formula at L206 (`price + (price * growthBasisPoints) / 10000`) permanently outputs zero, making all subsequent mints free until the owner calls `setPrice` again with a non-zero value.

**Impact**: Recoverable misconfiguration. Free mints could dilute NFT supply if not caught promptly.

**Recommendation**: Add `require(newPrice > 0, "NFTMinter: price must be non-zero")` in `setPrice`.

---

### [L-07] Missing SafeERC20 for USDT compatibility

**Location**: NFTMinter.sol (L201, L283), BalancerPooler.sol (L61, L93), Gather.sol (L61)

**Description**: All ERC20 interactions use bare `transfer` and `transferFrom` calls. Tokens like USDT that return `false` instead of reverting on failure will silently fail, leaving the protocol in an inconsistent state (NFT minted but tokens not actually transferred).

**Impact**: The protocol is incompatible with non-standard ERC20 tokens that do not revert on failure. If such a token is ever configured as a prime token, mints could succeed without actual payment.

**Recommendation**: Use OpenZeppelin's `SafeERC20` library (`safeTransfer` / `safeTransferFrom`) for all ERC20 interactions.

---

### [L-08] Price growth calculated on gross price for fee-on-transfer tokens

**Location**: [NFTMinter.sol#L206](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L206)

**Description**: The growth formula uses `price` (the gross amount before fee-on-transfer deductions) rather than `actualReceived` (the net amount the dispatcher receives, computed at L202). For FOT tokens, the stored price grows based on the gross amount, creating a minor divergence between the nominal price curve and the actual value dispatched.

**Impact**: Minimal. The price divergence is proportional to the FOT fee percentage and compounds over time, but since FOT tokens are edge cases, practical impact is negligible.

**Recommendation**: Document this behavior. If FOT support is important, consider basing growth on `actualReceived` instead.

---

### [L-09] Settle amount fragility in BalancerPooler

**Location**: [BalancerPooler.sol#L83-L84](https://github.com/example/yield-claim-nft/blob/main/src/dispatchers/BalancerPooler.sol#L83-L84)

**Description**: The `addLiquidity` return value (actual amounts consumed by the pool) is ignored. The subsequent `settle` call at L84 uses `actualPrimeInVault` -- the amount transferred, not the amount consumed. This is correct for `AddLiquidityKind.UNBALANCED` (which consumes all provided tokens), but would be incorrect if the liquidity kind were changed to `EXACT_OUT` or another kind that may consume less than provided.

**Impact**: No current issue. The `UNBALANCED` kind guarantees all transferred tokens are consumed. This becomes a bug only if the `AddLiquidityKind` is changed without updating the settle logic.

**Recommendation**: Capture the return value from `addLiquidity` and use the actual consumed amounts in `settle`:

```solidity
(uint256[] memory amountsIn, , ) = IBalancerVault(_vault).addLiquidity(params);
uint256 settleAmount = _primeTokenIsFirst ? amountsIn[0] : amountsIn[1];
IBalancerVault(_vault).settle(IERC20(_primeToken), settleAmount);
```

---

### [L-10] Hardcoded 2-token pool assumption

**Location**: [BalancerPooler.sol#L65](https://github.com/example/yield-claim-nft/blob/main/src/dispatchers/BalancerPooler.sol#L65)

**Description**: `maxAmountsIn` is hardcoded to `new uint256[](2)`, assuming the target Balancer pool always has exactly 2 tokens. If the contract is deployed against a pool with 3 or more tokens, the `addLiquidity` call will revert due to array length mismatch.

**Impact**: Deployment misconfiguration would brick the dispatcher. No runtime risk for correctly configured deployments, but the assumption is implicit and undocumented.

**Recommendation**: Either query the pool's token count dynamically, or add a constructor validation that confirms the pool has exactly 2 tokens. At minimum, add a NatSpec comment documenting the 2-token requirement.

---

### [L-11] Price overflow DoS from compound growth

**Location**: [NFTMinter.sol#L206](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L206)

**Description**: The compound growth formula `price + (price * growthBasisPoints) / 10000` can eventually overflow `uint256` after sustained minting. For example, with `growthBasisPoints = 100` (1% per mint), overflow occurs around mint #4200. With `growthBasisPoints = 1000` (10%), it occurs around mint #420.

**Impact**: Practically zero. The price reaches astronomically large values (exceeding total token supply) long before overflow. The overflow is a redundant failure mode -- minting would already be economically impossible. The owner can reset via `setPrice()`.

**Recommendation**: Consider using a `try/catch` or checked arithmetic cap to fail gracefully, or document the expected mint count range. Alternatively, add a maximum price cap.

---

### [L-12] JSON injection in `uri()` via unescaped metadata

**Location**: [NFTMinter.sol#L228-L249](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L228-L249)

**Description**: The `uri()` function concatenates dispatcher metadata (`name`, `image`, `description`) directly into a JSON string without escaping special characters (quotes, backslashes, newlines). A malicious or careless admin could set metadata containing `"` characters, breaking the JSON structure and potentially injecting arbitrary JSON keys.

**Impact**: Off-chain display issue only. Could cause NFT marketplaces or frontends to misrender metadata. Requires a malicious or negligent admin to set problematic metadata via `setMetadata()`.

**Recommendation**: Escape JSON special characters in the metadata strings, or validate that metadata does not contain `"`, `\`, or control characters when `setMetadata` is called.

---

### [L-13] Front-running via deterministic price growth

**Location**: [NFTMinter.sol#L206](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L206)

**Description**: The price growth after each mint is fully deterministic and publicly readable. MEV bots can observe pending mint transactions, calculate the post-mint price, and front-run to mint at the current (lower) price, then potentially resell the NFT at a profit.

**Impact**: Limited. Front-running is only profitable if a secondary market exists for the claim NFTs and the price difference per mint is material. For typical growth rates (1-10%), the per-mint arbitrage is small relative to gas costs.

**Recommendation**: This is an inherent property of bonding curve designs. Consider commit-reveal schemes for high-value mints, or document the front-running risk for users.

---

## Centralization Risks

### [C-01] Uncapped `growthBasisPoints` allows owner to halt minting

**Location**: [NFTMinter.sol#L271-L276](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L271-L276)

**Description**: The owner can set `growthBasisPoints` to an arbitrarily large value via `setGrowthFactor`, causing the price to spike to an unpayable amount after a single mint. Combined with `setPrice`, the owner has full unilateral control over mint economics.

**Impact**: The owner can effectively halt minting or make it prohibitively expensive at any time without a timelock or governance vote.

**Recommendation**: Implement a maximum cap on `growthBasisPoints` (e.g., 1000 = 10%) and/or add a timelock for changes to critical parameters.

---

### [C-02] BPT centralization -- owner controls all accumulated BPT

**Location**: [BalancerPooler.sol#L92-L94](https://github.com/example/yield-claim-nft/blob/main/src/dispatchers/BalancerPooler.sol#L92-L94)

**Description**: All BPT (Balancer Pool Tokens) generated from user-funded mints accumulate in the `BalancerPooler` contract. The owner can withdraw all BPT to any address via `withdrawBPT` with no restrictions. There is no on-chain mechanism for NFT holders to redeem or claim a proportional share of the underlying BPT.

**Impact**: Users pay real tokens during minting, which are converted to BPT. The resulting BPT is entirely under owner discretion. NFT holders must trust the owner to manage these funds honestly, with no on-chain enforcement or vesting schedule.

**Recommendation**: Consider implementing a BPT distribution mechanism tied to NFT holdings, or at minimum add a timelock and event logging for BPT withdrawals to increase transparency.

---

### [C-03] Burn bypasses ERC1155 approval mechanism

**Location**: [NFTMinter.sol#L322-L326](https://github.com/example/yield-claim-nft/blob/main/src/NFTMinter.sol#L322-L326)

**Description**: The `burn` function allows any `authorizedBurner` to burn NFTs from any holder's balance without requiring the holder's ERC1155 approval (`setApprovalForAll`). The standard ERC1155 `_burn` internal function does not check operator approval -- it only requires the caller to have sufficient balance or be the contract itself.

**Impact**: This is by design for the protocol's redemption/claim flow, but it represents a significant trust assumption. Authorized burners (set by the owner) can destroy any user's NFTs at any time. If a burner contract is compromised, all NFT holders are at risk.

**Recommendation**: Document this trust assumption clearly. Consider requiring holder opt-in (e.g., approval) for burn operations, or implement a time-delayed burn with a cancellation window.

---

## Previous Findings Status

| Finding | Status | Notes |
|---------|--------|-------|
| L-05 (Round 2): All claim NFTs share same token ID | **Fixed** | Resolved via `setDispatcherTokenId` (L148-L172) |
| M-02 (Round 2): 1:1 phUSD minting in BalancerPooler | **Moot** | phUSD removed from BalancerPooler entirely |
| All other L/C findings from Rounds 1-2 | **Still applicable** | Included in this report above |
