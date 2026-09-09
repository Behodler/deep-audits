# QA Report - Phoenix NFT Staking (BatchNFTMinter)

## Summary

This QA report consolidates five Low-severity findings identified in the audit of the `BatchNFTMinter` contract (story-009 batch minter) and its interaction with `NFTStaker`. No High or Medium severity issues survived final review. The findings below are documentation, defense-in-depth, and integrator-correctness concerns; none enable direct theft, loss, or freezing of funds.

| ID    | Title                                                                                                              | Contract            |
|-------|--------------------------------------------------------------------------------------------------------------------|---------------------|
| L-01  | Mid-batch concurrent-minter griefing causes atomic rollback                                                        | BatchNFTMinter.sol  |
| L-02  | `paymentAmount=0` permits zero-capital extraction of pre-deposited donations                                       | BatchNFTMinter.sol  |
| L-03  | Reentrancy via ERC1155 callback causes inner `forceApprove(0)` to clobber outer batch's allowance, atomic rollback | BatchNFTMinter.sol  |
| L-04  | `batchMint` discards `mint()` bool return and `totalPaid` clamp under-reports caller spend in donation paths       | BatchNFTMinter.sol  |
| L-05  | `pendingReward` view does not simulate post-batch-mint schedule recompute, returns stale values around batch boundaries | NFTStaker.sol  |

---

## Low Risk Findings

### [L-01] Mid-batch concurrent-minter griefing causes atomic rollback

**Severity**: Low

**Location**: [BatchNFTMinter.sol#L74-L78](https://github.com/Behodler/phoenix-nft-staking/blob/49a68717d47feaf453ba03c5989cddadc1862070/contracts/BatchNFTMinter.sol#L74-L78)

**Description**:
The caller's `paymentAmount` budget is computed against the price observed at the moment of submission. Because the underlying minter follows a geometric price curve, a concurrent direct mint by another party between transaction submission and inclusion escalates the per-mint cost. If the cumulative cost exceeds `paymentAmount` partway through the loop, the inner `mint()` call reverts and the entire batch is rolled back atomically. The victim wastes gas and must retry with a higher slippage tolerance.

There is no theft or stuck-funds path — failed transactions revert cleanly — but the user experience and integrator semantics warrant explicit documentation.

**Recommendation**:
Document the slippage/race behavior for integrators. Consider exposing a max-price-per-mint parameter so callers can set explicit slippage tolerance, or alternatively return partial-fill semantics rather than reverting on budget exhaustion.

---

### [L-02] `paymentAmount=0` permits zero-capital extraction of pre-deposited donations

**Severity**: Low

**Location**: [BatchNFTMinter.sol#L71-L74](https://github.com/Behodler/phoenix-nft-staking/blob/49a68717d47feaf453ba03c5989cddadc1862070/contracts/BatchNFTMinter.sol#L71-L74)

**Description**:
`batchMint` does not enforce a `paymentAmount > 0` guard. Combined with the documented "donations flow forward" pattern, an attacker observing a pending donation (e.g. payment tokens accidentally sent to the contract by a user or integrator) can call `batchMint(count = K, paymentAmount = 0)`. The donation balance covers the mint cost, the attacker receives the NFTs, and any residue is refunded to the attacker.

All realistic donation sources here are user/integrator mistakes — a class C4 generally treats as known-invalid. Accordingly this is documentation and defense-in-depth rather than a direct attack surface, but cheap to mitigate.

**Recommendation**:
Revert if `paymentAmount == 0`, or validate that `paymentAmount` is at least the expected cost lower bound for the requested `count`.

---

### [L-03] Reentrancy via ERC1155 callback causes inner `forceApprove(0)` to clobber outer batch's allowance, atomic rollback

**Severity**: Low

**Location**: [BatchNFTMinter.sol#L75-L81](https://github.com/Behodler/phoenix-nft-staking/blob/49a68717d47feaf453ba03c5989cddadc1862070/contracts/BatchNFTMinter.sol#L75-L81)

**Description**:
A smart-contract recipient implementing `onERC1155Received` that re-enters `batchMint(...)` reaches the cleanup line `paymentToken.forceApprove(nftMinter, 0)` on the inner invocation, revoking the still-active allowance held by the outer call. When the outer call resumes its next iteration's `mint()`, the transfer fails for lack of allowance and the whole transaction reverts atomically.

This is DoS-only; no theft is possible. The caller controls the recipient address, so the impact is largely self-inflicted. The project documents an intentional absence of reentrancy guards on the staking contract; this finding refines that decision with a concrete DoS path on the batch minter and recommends a cheap defense-in-depth.

**Recommendation**:
Add OpenZeppelin's `nonReentrant` modifier to `batchMint()` for cheap defense-in-depth. Alternatively, track and restore the previous allowance instead of unconditionally calling `forceApprove(nftMinter, 0)` during cleanup.

---

### [L-04] `batchMint` discards `mint()` bool return and `totalPaid` clamp under-reports caller spend in donation paths

**Severity**: Low

**Location**: [BatchNFTMinter.sol#L78](https://github.com/Behodler/phoenix-nft-staking/blob/49a68717d47feaf453ba03c5989cddadc1862070/contracts/BatchNFTMinter.sol#L78) (discarded bool), [BatchNFTMinter.sol#L86](https://github.com/Behodler/phoenix-nft-staking/blob/49a68717d47feaf453ba03c5989cddadc1862070/contracts/BatchNFTMinter.sol#L86) (ternary clamp)

**Description**:
Two related spec/integrator-correctness concerns:

1. **Discarded bool return.** `ITokenMinterV2.mint()` is documented in interface NatSpec as returning `bool success`. Line 78 calls `nftMinter.mint(dispatcherIndex, recipient);` and discards the return value. If a future or alternate dispatcher uses soft-failure semantics (for example, returning `false` when a supply cap is reached rather than reverting), the loop iterates `count` times producing zero NFTs, returns the full refund, and reports `totalPaid = 0` — a silent no-op success. The current production dispatcher reverts on failure, so the issue is latent.

2. **`totalPaid` clamp.** Line 86 computes `paymentAmount > remaining ? paymentAmount - remaining : 0`. When `remaining > paymentAmount` (donation path), `totalPaid` is clamped to zero, under-reporting the caller's true net flow to off-chain accounting consumers.

**Recommendation**:
Check the bool return value of `nftMinter.mint()` and revert on `false`. For `totalPaid` accounting, either compute it as the actual delta of the `paymentToken` balance pre/post-loop, or document the clamp behavior explicitly for off-chain accounting consumers.

---

### [L-05] `pendingReward` view does not simulate post-batch-mint schedule recompute, returns stale values around batch boundaries

**Severity**: Low

**Location**: [NFTStaker.sol#L567-L578](https://github.com/Behodler/phoenix-nft-staking/blob/49a68717d47feaf453ba03c5989cddadc1862070/contracts/NFTStaker.sol#L567-L578)

**Description**:
`pendingReward(user)` simulates `_updatePool` forward, but it does not simulate `_syncBudget` — there is no pull and no `_recomputeSchedule` invocation in the view path. After a `batchMint` that bumps `latestPrice` (and would therefore alter the schedule on the next state-changing call), `pendingReward` returns values inconsistent with the amount `claim()` would actually pay in the same block.

There is no on-chain settlement impact; `claim()` itself produces the correct payout. The inconsistency surfaces as off-chain integrator/UI drift around batch-mint boundaries.

**Recommendation**:
Either simulate `_syncBudget` / `_recomputeSchedule` in the view path so `pendingReward` matches `claim()`'s on-chain behavior, or document `pendingReward` as a lower-bound estimate that may drift from `claim()` return values around batch-mint boundaries.

---
