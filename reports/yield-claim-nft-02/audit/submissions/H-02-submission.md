<!--
C4 Submission Metadata
Title: [H-02] BalancerPoolerV2 sandwich via user-controlled minBptAmountOut drains protocol BPT treasury
Severity: High
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/BalancerPoolerV2.sol#L51-L56
Secondary Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/BalancerPoolerV2.sol#L79-L88
PoC File: test/poc-H-02.t.sol
-->

## Finding description and impact

### Summary
`BalancerPoolerV2.dispatch` derives the slippage floor (`minBptAmountOut`) from caller-supplied `extraData` and defaults to `0` when empty. `NFTMinterV2.mint` forwards whatever `extraData` the caller passes straight through to the dispatcher, so anyone can cause the protocol's single-sided `UNBALANCED` join into a Balancer V3 pool to execute with zero slippage protection. The BPT minted from that join is retained on `BalancerPoolerV2` (withdrawable only by the owner via `withdrawBPT`), meaning the value lost to sandwich/imbalance is lost by the protocol, not by the caller.

### Vulnerability details

The root cause is the defaulting of `minBptAmountOut` to `0` in `dispatch`, and the unconditional forwarding of that value to the vault's `UNBALANCED` join inside `unlockCallback`:

`src/V2/dispatchers/BalancerPoolerV2.sol#L51-L56`:

```solidity
function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {
    uint256 minBptAmountOut = extraData.length > 0 ? abi.decode(extraData, (uint256)) : 0;
    bytes memory innerData = abi.encode(amount, minBptAmountOut);
    bytes memory data = abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, innerData);
    IBalancerVault(_vault).unlock(data);
}
```

`src/V2/dispatchers/BalancerPoolerV2.sol#L79-L88`:

```solidity
AddLiquidityParams memory params = AddLiquidityParams({
    pool: _pool,
    to: address(this),
    maxAmountsIn: maxAmountsIn,
    minBptAmountOut: minBptAmountOut,
    kind: AddLiquidityKind.UNBALANCED,
    userData: ""
});

IBalancerVault(_vault).addLiquidity(params);
```

Because the join is `UNBALANCED` (single-sided with `primeToken` only), the BPT yield is directly sensitive to the pool's current reserve ratio. A caller who sets `minBptAmountOut = 0` (or omits `extraData` entirely) signals to the vault that any BPT output is acceptable, including zero. The BPT is transferred to `address(this)` (the pooler), so the economic loss accrues to the protocol treasury rather than the mint caller.

Two concrete attack variants:

1. **Self-sandwich (most profitable):**
   - Attacker flash-loans `primeToken`.
   - Performs an unbalanced swap on the target Balancer V3 pool that saturates the pool with `primeToken`, depressing its marginal price relative to the paired asset.
   - Calls `NFTMinterV2.mint(primeToken, dispatcherIndex, recipient, "")` (or any `extraData` with a trivial floor). The pooler forwards `minBptAmountOut = 0` to the vault.
   - The single-sided join returns materially depressed BPT to `BalancerPoolerV2`.
   - Attacker rebalances the pool by swapping back, capturing the arbitrage spread, and repays the flash loan.
   - The NFT mint cost (one `PRICE` of `primeToken`) is more than recovered through the rebalancing arbitrage, and the shortfall is paid in permanent BPT loss to the protocol.

2. **Frontrun-a-legitimate-minter:** Any honest `mint` call with empty `extraData` can be sandwiched. The attacker imbalances the pool, the victim's mint registers depressed BPT with the pooler, the attacker rebalances for profit.

In both variants the mint itself succeeds (no user-facing revert) and nothing in the flow alerts the protocol — only the BPT balance on `BalancerPoolerV2` silently diverges from the fair amount. Over time the withdrawable owner treasury is permanently reduced.

### Impact

Direct, repeatable reduction of protocol-owned BPT. Every sandwiched mint permanently shaves value off what the owner can later recover via `withdrawBPT`. There is no recovery path — the BPT not minted cannot be clawed back, and the attacker's captured arbitrage is outside the protocol's control. Because this attack works on a per-transaction basis, there is no upper bound on the cumulative loss as long as the pool is open and mints occur.

This is a direct loss of protocol assets with a clear, MEV-standard attack path, qualifying as High severity under C4's classification (assets can be compromised via a valid attack path without hypothetical preconditions).

## Recommended mitigation steps

Remove the user-supplied `minBptAmountOut` path entirely; do not trust callers (or the minter relay) to specify slippage for value that belongs to the protocol. Replace it with one of the following, listed in order of preference:

1. **Decouple accumulation from pool interaction (owner-triggered pooling).** Let `dispatch` simply accept prime tokens (no pool interaction, no `extraData`). Prime tokens accumulate on the dispatcher. Add two new functions: a view `getIdealBPT()` that previews the BPT mint for the dispatcher's current prime balance against live pool state, and an `onlyOwner` `pool(uint256 minBPT)` that performs the `unlock` → `addLiquidity` with an owner-supplied floor. This entirely removes the sandwich surface from user-triggered mints — the join only fires when the owner signs a transaction with a deliberately chosen floor (computed off-chain from `getIdealBPT()` plus tolerance, optionally submitted via a private relay). Tradeoff: BPT accrues in batches rather than per-mint, but there is no oracle dependency and no trust shift beyond the existing owner-held BPT withdrawal right.

   ```solidity
   function dispatch(address, uint256, bytes calldata) external override onlyMinter whenNotPaused {
       // prime tokens are already on this contract; defer pooling to owner
   }

   function getIdealBPT() external view returns (uint256) {
       // query vault/pool for current reserves + totalSupply, compute
       // expected bptOut for balanceOf(address(this)) accounting for the unbalanced-join swap fee
   }

   function pool(uint256 minBPT) external onlyOwner whenNotPaused {
       uint256 amount = IERC20(_primeToken).balanceOf(address(this));
       require(amount > 0, "BalancerPoolerV2: nothing to pool");
       bytes memory innerData = abi.encode(amount, minBPT);
       bytes memory data = abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, innerData);
       IBalancerVault(_vault).unlock(data);
   }
   ```

2. **Owner-configured minimum BPT-per-primeToken ratio.** If per-mint pooling must be preserved, store an owner-settable `minBptPerPrimeWad` and enforce `minBptAmountOut = primeAmount * minBptPerPrimeWad / 1e18` inside `unlockCallback`. The owner sets this floor based on a fair-value estimate of the pool and can update it as pool composition drifts.

   ```solidity
   uint256 public minBptPerPrimeWad; // e.g., 0.95e18 = require >= 95% of prime as BPT

   function setMinBptPerPrime(uint256 wad) external onlyOwner { minBptPerPrimeWad = wad; }

   function dispatch(address, uint256 amount, bytes calldata /*extraData*/) external override onlyMinter whenNotPaused {
       uint256 minBpt = (amount * minBptPerPrimeWad) / 1e18;
       bytes memory innerData = abi.encode(amount, minBpt);
       bytes memory data = abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, innerData);
       IBalancerVault(_vault).unlock(data);
   }
   ```

3. **On-chain TWAP-derived floor.** Read a TWAP (e.g., a Balancer/Uniswap TWAP over N minutes) inside `unlockCallback` to derive a defensive `minBptAmountOut`. This removes the trust assumption on the owner at the cost of oracle complexity.

4. **Restrict `dispatch` callers and/or expose a pause.** At minimum, ensure the `extraData` slippage parameter is NOT sourced from the end user — the minter/owner should populate it — and honor `whenNotPaused` so the owner can halt mints during periods of known pool instability.

Additionally, consider switching from `AddLiquidityKind.UNBALANCED` to a proportional add when feasible, which materially reduces single-sided sandwich sensitivity.

