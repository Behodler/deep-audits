<!--
C4 Submission Metadata
Title: [M-04] `BalancerPoolerV2.setPool` rotation strands the hook's debt ledger, decoupling `mintDebt` from the currently bound pool's BPT backing
Root Cause Links:
  - https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/dispatchers/BalancerPoolerV2.sol#L84-L87
  - https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L89-L95
PoC File: workspace/yield-claim-nft/test/poc-M-04.t.sol
-->

## Finding description and impact

### Summary

`BalancerPoolerMintDebtHook` is bound to its dispatcher via an `immutable` address and has **no reference to the Balancer pool** that currently backs the NFT yield position. `BalancerPoolerV2.setPool(newPool)` is an owner action that rotates `_pool` on the dispatcher (see [BalancerPoolerV2.sol#L84-L87](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/dispatchers/BalancerPoolerV2.sol#L84-L87)) without informing, resetting, or settling the hook's `mintDebt` ledger (see [BalancerPoolerMintDebtHook.sol#L89-L95](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L89-L95)).

After a rotation:

- BPT minted by dispatches before the rotation stays on the dispatcher as an ERC20 balance but is no longer tied to the dispatcher's "active" pool and is invisible to the hook.
- New dispatches accrue into the same hook `mintDebt` counter as the pre-rotation accruals.
- `pull()` mints the full aggregated `mintDebt` as phUSD to the recipient, with no check that the backing sUSDS ever entered the currently bound pool.

The hook's ledger is therefore a simple running sum, with no partitioning by the pool that actually holds the backing sUSDS LP position.

### Vulnerability details

The relevant code on `BalancerPoolerV2`:

```solidity
// src/V2/dispatchers/BalancerPoolerV2.sol (L82-L87)
/// @notice Sets the Balancer pool address. Only callable by owner.
/// @param newPool The new pool address.
function setPool(address newPool) external onlyOwner {
    require(newPool != address(0), "BalancerPoolerV2: zero pool address");
    _pool = newPool;
}
```

The corresponding hook entry point:

```solidity
// src/V2/hooks/BalancerPoolerMintDebtHook.sol (L85-L95)
/// @inheritdoc IDispatchHook
/// @dev Gated to `dispatcher` to prevent unbounded phUSD debt inflation by
///      arbitrary callers. Silent no-op when `added == 0` (zero ratio or
///      small-amount rounding) so the debt ledger never emits empty events.
function onDispatch(address minter, uint256 amount, bytes calldata) external {
    if (msg.sender != dispatcher) revert OnlyDispatcher();
    uint256 added = (amount * ratio) / 100;
    if (added == 0) return;
    mintDebt += added;
    emit DebtAccrued(minter, amount, added, mintDebt);
}
```

`onDispatch` performs one lookup — `msg.sender == dispatcher` — and then increments `mintDebt`. There is no knowledge of, no reference to, and no constraint on the Balancer pool. The hook treats the dispatcher as a monolithic black box regardless of which pool that dispatcher is currently configured to use.

The decoupling manifests in three concrete ways on a pool rotation:

1. **Stranded BPT.** Any BPT held by the dispatcher for the previous pool sits as an orphaned ERC20 balance. It was previously counted in the hook's mental model ("sUSDS backing is in the pool") but is now unreferenced by the active pool binding, and the hook has never known about it at all.
2. **Cross-pool debt summation.** Fresh dispatches after the rotation increment the same `mintDebt` field as pre-rotation accruals. There is no way for `pull()` to distinguish "debt backed by pool A sUSDS" from "debt backed by pool B sUSDS".
3. **Unconstrained `pull()`.** `pull()` realises the aggregated debt as freshly minted phUSD to the recipient. The recipient's phUSD claim is a single pile; the currently bound pool's BPT backs only the post-rotation portion of that pile.

The hook's design invariant — that `mintDebt` is a claim on the pool-held backing — is not enforceable from the hook's side, and nothing on the dispatcher side prevents the rotation while `mintDebt > 0`.

### Impact

After a pool rotation and a `pull()`, the minted phUSD balance held by the recipient represents a mix of two unrelated backing positions: a stranded BPT position in a pool the protocol no longer recognises, and a BPT position in the currently bound pool. The recipient can dump the full phUSD balance into whichever sUSDS/phUSD pool is liquid, extracting real user sUSDS, while the protocol's accounting treats the two backing positions as fungible.

The trigger is a legitimate admin operation (`setPool`), not an unauthorised call; the owner is trusted to make rotation decisions but is not expected to manually keep an off-chain debt↔pool mapping in sync. A rotation is exactly the moment at which that invariant must be enforced on-chain, and it is not.

Classified as **Medium**: a protocol invariant (hook debt must be backed by the currently bound pool) is silently violated by a legitimate governance action. No external attacker is required; the decoupling arises mechanically from normal protocol operation. Funds are not directly stolen by the rotation itself, but NFT holders' backing ends up materially misrepresented, and the downstream `pull()` + dump path lets the recipient extract value that the hook's ledger does not correctly attribute to the active pool.

### Proof of Concept

See `workspace/yield-claim-nft/test/poc-M-04.t.sol` for the full Foundry test. Run from the project root (`workspace/yield-claim-nft`):

```
forge test --match-contract M04_PoolRotationDecouplesDebt -vv
```

The scenario:

1. Dispatch `1_000e18` USDS via the dispatcher bound to **pool A**. Hook accrues `300e18` phUSD debt (30% ratio). `pool()` is called, minting `1_000e18` of pool-A BPT to the dispatcher.
2. Owner calls `setPool(poolB)`. The dispatcher's active pool rotates to pool B. `1_000e18` of pool-A BPT remains on the dispatcher, stranded. The hook's `mintDebt` is unchanged (`300e18`).
3. Dispatch another `500e18` USDS. Hook debt grows to `450e18` total. `pool()` is called, minting `500e18` of pool-B BPT. Pool-A BPT still sits unclaimed on the dispatcher.
4. Recipient calls `pull()`. `450e18` phUSD is minted in one go.

The PoC asserts concrete numbers:

- `totalDebt = 450e18` phUSD minted to recipient on `pull()`.
- `phase3DebtSlice = 150e18` — the portion actually backed by the currently bound pool (pool B).
- `unbackedByCurrentPool = 300e18` — the portion backed only by stranded pool-A BPT.
- `poolA.balanceOf(dispatcher) = 1_000e18` — stranded BPT confirmed held outside the active-pool binding.
- `poolA.balanceOf(vault) = 0` — the stranded BPT is not in the active Balancer position.

i.e. `300e18` out of `450e18` minted phUSD is backed by a pool the protocol no longer treats as current, and `150e18` is backed by the current pool.

## Recommended mitigation steps

The hook must be coupled to a specific pool, not just a specific dispatcher. Any of the following closes the gap; the first two are the lightest changes:

1. **Gate rotations on a clean ledger.** Require `mintDebt == 0` on the bound hook before `setPool` succeeds. Force the owner to call `pull()` (or an equivalent settlement) first, so every post-rotation accrual is known to be backed by the new pool only:

    ```solidity
    function setPool(address newPool) external onlyOwner {
        require(newPool != address(0), "BalancerPoolerV2: zero pool address");
        if (address(hook) != address(0)) {
            require(IBalancerPoolerMintDebtHook(address(hook)).mintDebt() == 0, "settle debt first");
        }
        _pool = newPool;
    }
    ```

2. **Make the hook pool-aware.** Add a `pool` reference on the hook (either `immutable`, or cached and refreshed on a settlement flow) and have `onDispatch` `revert` if `IBalancerPoolerV2(dispatcher).pool()` differs from the expected pool. Rotations then require redeploying / re-pointing the hook as part of a deliberate migration.

3. **Partition debt by pool.** Replace the single `mintDebt` scalar with a `mapping(address pool => uint256 debt)` keyed on the pool active at the time of accrual, and keep each partition linked to the BPT balance for that pool. `pull()` must then realise debt against a specific pool's backing (and rotation leaves prior partitions settled or queued for redemption of the stranded BPT).

4. **Atomic stranded-BPT redemption on rotation.** Have `setPool` redeem the dispatcher's BPT from the outgoing pool as part of the same transaction (pulling sUSDS back to the dispatcher or re-depositing into the new pool), so no orphaned LP position can persist across the rotation boundary. This is the most disruptive option and changes the dispatcher's operational surface; (1) is typically sufficient.

Whichever shape is chosen, `BalancerPoolerV2.setPool` should not be executable while the hook has unsettled debt against the outgoing pool. A brief NatSpec note on the hook explaining the coupling expectation is also worthwhile.
