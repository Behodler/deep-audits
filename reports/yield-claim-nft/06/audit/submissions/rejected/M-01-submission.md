<!--
title: Single-sided UNBALANCED addLiquidity into sUSDS/phUSD Balancer V3 pool is sandwich-extractable; caller-supplied minBPT is the only on-chain defence
root_cause: https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L246-L273
severity: Medium
poc_path: workspace/yield-claim-nft/test/poc-ECON-RAW-001.t.sol
-->

## Summary

`BalancerPoolerV2.pool()` performs a single-sided `AddLiquidityKind.UNBALANCED` join on the sUSDS/phUSD Balancer V3 pool with no on-chain freshness check on the expected BPT. Because V3 charges a swap-fee-equivalent on the imbalance the joiner causes, the BPT received is highly sensitive to the pool's instantaneous sUSDS/phUSD spot, allowing a searcher to sandwich the call and siphon protocol-owned BPT.

## Vulnerability Detail

The dispatcher executes the LP add inside `unlockCallback` with `AddLiquidityKind.UNBALANCED` and a caller-supplied `minBPT` as the only slippage gate ([`BalancerPoolerV2.sol#L246-L273`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L246-L273)). Balancer V3's `computeAddLiquidityUnbalanced` (BasePoolMath) prices the single-sided add as if the joiner first swapped half of the deposit through the pool to balance it, charging a swap fee on the implied imbalance and only then performing a proportional add. The BPT returned therefore tracks the same price impact a swap of equivalent size would experience.

`getIdealBPT()` exists ([`BalancerPoolerV2.sol#L280-L296`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L280-L296)) but is intended for off-chain pre-quoting. It is not called atomically inside `pool()`, no `deadline` is enforced, and the quote is stale by the time the tx is mined. The operator bot must pick `minBPT` from a quote taken at block N for a tx that executes at block N+k, so a sandwich at block N+k can move the pool between the quote and execution.

Attack flow against a `pool()` tx visible in the mempool:

1. Front-run: swap into the sUSDS/phUSD pool to make sUSDS over-weight relative to the rate-provider price.
2. `pool()` executes against the skewed pool. The UNBALANCED add interprets the existing imbalance plus the joiner's sUSDS as additional imbalance, charges the maximum swap-fee penalty, and returns far fewer BPT than the off-chain quote — but still above a loose `minBPT`.
3. Back-run: reverse the swap and pocket the price-impact spread. The protocol's dispatcher receives less BPT than fair.

The same `unlockCallback` also performs the donation swap (see M-02), so a single MEV bundle can sandwich both legs of `pool()` in one tx.

## Impact

The dispatcher (and therefore the protocol) accrues less BPT per `pool()` call than the fair-value quote. This is realised value leak from protocol-owned BPT to the MEV searcher every time `pool()` is broadcast publicly.

The PoC, forked against mainnet at block `25134513` using the real Balancer V3 Vault (`0xbA1333...`), Router (`0xAE563E...`), and the real sUSDS/phUSD pool (`0x642BB6...`), measures a baseline BPT of `528.9e18` against a sandwiched BPT of `425.9e18` — a **19.46% BPT haircut**, roughly 194.6 sUSDS-equivalent value lost on a 3,000 sUSDS pool size. The attacker nets `181.9e18` sUSDS profit on `3,000e18` sUSDS capital with no flash-loan dependency.

Mitigating context: `pool()` is `onlyAuthorizedPooler` and the operator can submit through Flashbots Protect / MEV-Share / SUAVE. The on-chain code does not enforce private submission, so any public broadcast immediately exposes the protocol to this loss. This is the reason the finding is Medium rather than High: the bug requires the external assumption of public mempool submission to materialise.

## Code Snippet

[`src/V2/dispatchers/BalancerPoolerV2.sol#L246-L273`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L246-L273):

```solidity
// -------- LP add-liquidity phase (existing behaviour, on remaining sUSDS) --------
if (sUSDSAmount > 0) {
    uint256 vaultBefore = IERC20(_sUSDS).balanceOf(_vault);
    IERC20(_sUSDS).safeTransfer(_vault, sUSDSAmount);
    uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

    uint256[] memory maxAmountsIn = new uint256[](2);
    if (_sUSDSIsFirst) {
        maxAmountsIn[0] = actualInVault;
        maxAmountsIn[1] = 0;
    } else {
        maxAmountsIn[0] = 0;
        maxAmountsIn[1] = actualInVault;
    }

    AddLiquidityParams memory params = AddLiquidityParams({
        pool: _pool,
        to: address(this),
        maxAmountsIn: maxAmountsIn,
        minBptAmountOut: minBPT,
        kind: AddLiquidityKind.UNBALANCED,
        userData: ""
    });

    (, uint256 bptAmountOut,) = IBalancerVault(_vault).addLiquidity(params);
    IBalancerVault(_vault).settle(IERC20(_sUSDS), actualInVault);

    emit Pooled(pooler, actualInVault, bptAmountOut, minBPT);
}
```

## Tool Used

Manual Review + Foundry forked-mainnet PoC.

## Recommendation

Defence-in-depth across three layers:

1. **Replace UNBALANCED with PROPORTIONAL adds.** Source the second-side phUSD via on-chain mint-or-swap in the same tx so the joiner is not exposed to the implied swap-fee penalty at all. This is the structural fix.
2. **Add an on-chain freshness gate.** Before `addLiquidity`, read the pool's current spot via `Vault.getPoolTokens` / pool-token rate-provider and revert if the spot deviates from the rate-provider price by more than a tight threshold (e.g., 25 bps). Note: calling `IBalancerRouter.queryAddLiquidityUnbalanced(...)` inside the active `unlockCallback` is **not viable** — V3 router queries open their own unlock context and revert against a held lock; the freshness check must come from raw pool/vault state reads.
3. **Mandate private submission.** Add a `deadline` parameter to `pool()`, document that the pooler operator MUST submit through Flashbots Protect / MEV-Share / SUAVE, and consider a commit-reveal scheme.

## Proof of Concept

`workspace/yield-claim-nft/test/poc-ECON-RAW-001.t.sol` is a forked-mainnet test (block `25134513`, public RPC `https://ethereum-rpc.publicnode.com`, env `MAINNET_RPC_URL` overrideable). It uses real Balancer V3 contracts and the real sUSDS/phUSD pool — no AMM mocking. The test executes a baseline `pool()` against the pool in equilibrium, then re-runs the same scenario after a front-run swap, and asserts the BPT haircut and attacker profit numbers reported above.
