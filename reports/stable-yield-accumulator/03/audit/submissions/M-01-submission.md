<!--
C4 Submission Metadata
Title: [M-01] ClaimArbitrage fails when SYA distributes tokens not in knownStables -- tokens permanently locked
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L195-L217
PoC File: poc-M-01.t.sol
-->

## Finding description and impact

### Summary

`ClaimArbitrage.unlockCallback()` converts received stablecoins to USDC in Step 5 (lines 195-217) by iterating exclusively over the `knownStables[]` array. When `StableYieldAccumulator.claim()` distributes a stablecoin that is not present in `knownStables[]`, the token is silently skipped and remains in the `ClaimArbitrage` contract. Because `ClaimArbitrage` has no rescue, sweep, or emergency withdrawal function, these tokens are permanently irrecoverable.

### Root cause

The `StableYieldAccumulator` (SYA) and `ClaimArbitrage` (CA) are two independent contracts with independently managed registries:

- **SYA** maintains a dynamic yield strategy list via `addYieldStrategy(address, address)`, controlled by the SYA owner. Each strategy corresponds to a different stablecoin. When `claim()` is called (line 594 of `StableYieldAccumulator.sol`), it iterates all registered strategies and transfers their underlying stablecoins to `msg.sender` via `withdrawFrom()`.

- **CA** maintains a separate `knownStables[]` array via `addKnownStable(address)`, controlled by the CA owner. Step 5 of the arbitrage logic only processes tokens that appear in this array.

There is no on-chain enforcement that these two registries remain synchronized. No validation exists in `execute()` or `unlockCallback()` to verify that all tokens SYA might distribute are covered by `knownStables[]`. The contracts may even have different owners, making coordination purely an off-chain operational concern.

### Vulnerability details

The vulnerable code in `ClaimArbitrage.sol` at [lines 195-217](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/ClaimArbitrage.sol#L195-L217):

```solidity
// STEP 5: CONVERT RECEIVED STABLECOINS -> USDC
for (uint256 i = 0; i < knownStables.length; i++) {
    address stable = knownStables[i];
    uint256 bal = IERC20(stable).balanceOf(address(this));
    if (bal == 0) continue;

    _depositIntoPM(stable, bal);

    PoolKey memory pool = stableToUSDCPool[stable];
    bool stableIsToken0 = (Currency.unwrap(pool.currency0) == stable);
    poolManager.swap(
        pool,
        SwapParams({
            zeroForOne: stableIsToken0,
            amountSpecified: -int256(bal),
            sqrtPriceLimitX96: stableIsToken0
                ? type(uint160).min + 1
                : type(uint160).max - 1
        }),
        ""
    );
}
```

The loop is bounded by `knownStables.length` and checks `balanceOf` only for addresses in that array. Any ERC20 token sitting in the contract's balance that is not enumerated in `knownStables[]` is never touched.

Critically, `ClaimArbitrage` exposes no function capable of transferring arbitrary ERC20 tokens out of the contract. Its complete external interface is:

| Function | Can extract ERC20? |
|---|---|
| `execute(ExecuteParams)` | No -- triggers `poolManager.unlock()`, processes only `knownStables` |
| `unlockCallback(bytes)` | No -- restricted to PoolManager caller, only processes `knownStables` |
| `setStableToUSDCPool(address, PoolKey)` | No -- only writes a mapping entry |
| `addKnownStable(address)` | No -- only appends to the array |
| `removeKnownStable(address)` | No -- only removes from the array |
| `setPoolKeys(...)` | No -- only writes pool key storage |
| `getKnownStables()` | No -- view function |
| `receive() external payable` | No -- accepts ETH only |
| Inherited `Ownable` functions | No -- ownership management only |

None of these functions call `transfer`, `transferFrom`, or any ERC20 movement on an arbitrary token address.

### Impact

Tokens permanently locked in `ClaimArbitrage` with no recovery path. This occurs under two realistic scenarios:

1. **Configuration desynchronization**: SYA's owner adds a new yield strategy for a stablecoin (e.g., FRAX via `addYieldStrategy`), but CA's owner does not add FRAX to `knownStables[]`. Every subsequent `execute()` call that triggers `sya.claim()` will deposit FRAX into the CA contract where it is permanently stranded.

2. **Timing gap**: Even with diligent administration, there is always a nonzero window between when SYA registers a new strategy (block N) and when CA's owner submits and confirms the corresponding `addKnownStable()` transaction (block N+k). Any `execute()` calls during this gap will lock the new stablecoin. Since `execute()` is permissionless and designed for MEV bots, calls during this window are expected.

The amount of locked value scales with the yield accumulated by the unregistered strategy. Multiple `execute()` calls during the desynchronization window compound the loss, as each call locks additional tokens with no mechanism to recover previously locked amounts.

### Attack path

1. SYA owner calls `addYieldStrategy(fraxStrategy, FRAX)` to register a new yield strategy that produces FRAX.
2. ClaimArbitrage's `knownStables[]` does not yet include FRAX (either due to oversight or the inherent multi-transaction timing gap).
3. An MEV bot calls `ClaimArbitrage.execute()`, which internally calls `sya.claim()` at line 170.
4. `SYA.claim()` iterates all registered yield strategies (line 584) and calls `withdrawFrom(..., msg.sender)` (line 594), transferring FRAX tokens to ClaimArbitrage.
5. Step 5 of `unlockCallback` iterates only `knownStables[]` (lines 195-217). FRAX is not in the array, so it is silently skipped.
6. FRAX tokens remain in the ClaimArbitrage contract's balance. No external function exists to extract them.
7. If additional `execute()` calls occur before the configuration is corrected, more FRAX accumulates and is locked.

## Recommended mitigation steps

Two complementary approaches address this vulnerability:

**Option A: Add an owner-callable rescue function.**

This provides a safety net for any tokens that become stranded, regardless of the cause:

```solidity
/// @notice Rescue ERC20 tokens stuck in the contract
/// @param token The token to rescue
/// @param to The recipient address
/// @param amount The amount to rescue
function rescueToken(address token, address to, uint256 amount) external onlyOwner {
    require(to != address(0), "Invalid recipient");
    IERC20(token).safeTransfer(to, amount);
    emit TokenRescued(token, to, amount);
}
```

**Option B: Validate strategy token coverage before executing.**

Add a pre-execution check that all tokens SYA's strategies might distribute are present in `knownStables[]`:

```solidity
function _validateKnownStablesCoverage() internal view {
    address[] memory strategies = sya.getYieldStrategies();
    for (uint256 i = 0; i < strategies.length; i++) {
        address token = sya.strategyTokens(strategies[i]);
        bool found = false;
        for (uint256 j = 0; j < knownStables.length; j++) {
            if (knownStables[j] == token) {
                found = true;
                break;
            }
        }
        require(found, "Strategy token not in knownStables");
    }
}
```

Option A is the simpler and more robust solution, as it handles edge cases beyond just the SYA synchronization issue (e.g., tokens sent directly to the contract by mistake). Option B provides a fail-fast guarantee but adds gas overhead. Both can be implemented together for defense in depth.
