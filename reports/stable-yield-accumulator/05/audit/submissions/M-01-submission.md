<!--
C4 Submission Metadata
Title: [M-01] ClaimArbitrage Step 3 hardcodes USDC approval but SYA rewardToken is mutable, causing permanent DoS if rewardToken changes
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/master/src/ClaimArbitrage.sol#L177
PoC File: poc-M-01-v05.t.sol
-->

## Finding description and impact

### Summary

`ClaimArbitrage.unlockCallback()` hardcodes `IERC20(USDC).approve(address(sya), p.usdcNeeded)` at line 177 (Step 3), but `StableYieldAccumulator.rewardToken` is mutable via `setRewardToken()`. If the SYA owner changes `rewardToken` from USDC to a different stablecoin, `SYA.claim()` attempts `safeTransferFrom` on the new reward token while ClaimArbitrage has only approved USDC. The transaction reverts permanently with no on-chain recovery path.

### Vulnerability details

ClaimArbitrage stores `USDC` as an `immutable` address set at construction:

```solidity
// ClaimArbitrage.sol, line 45
address public immutable USDC;
```

In `unlockCallback()`, Step 3 uses this immutable address to approve tokens for the SYA claim:

```solidity
// ClaimArbitrage.sol, line 177 -- Step 3 (BUG: hardcoded USDC)
IERC20(USDC).approve(address(sya), p.usdcNeeded);
sya.claim();
```

However, `StableYieldAccumulator.setRewardToken()` allows the owner to change which token `claim()` pulls from the caller:

```solidity
// StableYieldAccumulator.sol, lines 468-471
function setRewardToken(address _rewardToken) external onlyOwner {
    if (_rewardToken == address(0)) revert ZeroAddress();
    rewardToken = _rewardToken;
}
```

When `claim()` executes, it transfers the **current** `rewardToken` from `msg.sender` (ClaimArbitrage):

```solidity
// StableYieldAccumulator.sol, line 611
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);
```

If `rewardToken` has been changed to a token other than USDC, the `safeTransferFrom` call fails because ClaimArbitrage approved USDC (not the new reward token) at line 177. The allowance for the new token is zero.

The developer was aware of this mutability concern. Step 5 of the same function (line 208) correctly queries `sya.rewardToken()` dynamically and includes an explicit comment explaining why:

```solidity
// ClaimArbitrage.sol, lines 203-208 -- Step 5 (CORRECT: dynamic query)
// We query sya.rewardToken() rather than using the immutable USDC address because
// the reward token is a property of SYA, not of this contract. If SYA's reward token
// ever changes, this logic adapts automatically.
address _rewardToken = sya.rewardToken();
```

Step 3 was not updated to follow the same pattern. This is an internal code inconsistency where one code path adapts to rewardToken changes and the other does not.

### Lines of code

- [ClaimArbitrage.sol#L177](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/ClaimArbitrage.sol#L177) -- Step 3: hardcoded USDC approval (root cause)
- [ClaimArbitrage.sol#L208](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/ClaimArbitrage.sol#L208) -- Step 5: dynamic `sya.rewardToken()` query (correct pattern, demonstrates intent)
- [StableYieldAccumulator.sol#L468-L471](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L468-L471) -- `setRewardToken()` allowing owner to change reward token
- [StableYieldAccumulator.sol#L611](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L611) -- `claim()` pulls current `rewardToken` via `safeTransferFrom`

### Attack path

1. Protocol deploys ClaimArbitrage with `USDC` as the immutable address. `SYA.rewardToken` is also set to USDC. `ClaimArbitrage.execute()` works correctly.
2. The SYA owner calls `setRewardToken(newStable)` to change the reward token (e.g., migrating from USDC to USDT due to regulatory concerns or yield optimization).
3. A user calls `ClaimArbitrage.execute()`.
4. Inside `unlockCallback()`, Step 3 executes `IERC20(USDC).approve(address(sya), p.usdcNeeded)` -- approving the old USDC token.
5. `sya.claim()` calls `IERC20(rewardToken).safeTransferFrom(ClaimArbitrage, SYA, actualPayment)` where `rewardToken` is now `newStable`.
6. The call reverts because ClaimArbitrage has zero allowance for `newStable` to SYA.
7. ClaimArbitrage is permanently bricked. No admin function can fix the hardcoded approval. The contract must be redeployed.

### Impact

Permanent denial of service for the `ClaimArbitrage` contract if `SYA.rewardToken` is ever changed from USDC. The yield consolidation mechanism -- which is the primary economic function of ClaimArbitrage -- stops working entirely. Since `USDC` is an `immutable` variable, there is no setter function to update it. The only recovery path is deploying a new ClaimArbitrage contract, reconfiguring all pool keys and known stables, and updating any external integrations that reference the old address.

The `setRewardToken()` function exists explicitly for this use case (the NatSpec says "Sets the reward token address"), and Step 5 of ClaimArbitrage was written to handle it. The inconsistency between Step 3 and Step 5 means this failure mode was not tested.

### Proof of Concept

The PoC demonstrates the vulnerability in three phases:

1. **Phase 1**: With `rewardToken == USDC`, `execute()` succeeds and the caller receives ETH profit.
2. **Phase 2**: SYA owner calls `setRewardToken(newStable)`.
3. **Phase 3**: `execute()` reverts because Step 3 approves USDC but `claim()` pulls `newStable`.
4. **Phase 4**: Confirms the DoS is permanent -- even with sufficient `newStable` balance on ClaimArbitrage, the hardcoded USDC approval prevents execution.

PoC file: `workspace/stable-yield-accumulator/test/poc-M-01-v05.t.sol`

### Tools Used

Manual review, Foundry

## Recommended mitigation steps

Replace the hardcoded USDC approval at line 177 with a dynamic query to `sya.rewardToken()`, matching the pattern already used at line 208:

```diff
  // Step 3: Call claim
- IERC20(USDC).approve(address(sya), p.usdcNeeded);
+ address rt = sya.rewardToken();
+ IERC20(rt).approve(address(sya), p.usdcNeeded);
  sya.claim();
```

This aligns Step 3 with Step 5 and ensures ClaimArbitrage approves whichever token SYA currently expects. The additional `SLOAD` from the external call is negligible in the context of the multi-swap atomic transaction.

If the protocol also needs Step 2 (the USDC borrow from PoolManager) to adapt to rewardToken changes, the same dynamic query should be applied there as well. However, Step 2's borrow denomination may be intentionally fixed to USDC for PoolManager liquidity reasons, so this should be evaluated separately.
