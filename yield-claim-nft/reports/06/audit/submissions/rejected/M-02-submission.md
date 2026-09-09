<!--
title: Donation swap (sUSDS -> waUSDC) executes with limitRaw=0; only post-unwrap USDC is slippage-checked, enabling sandwich extraction on the swap leg
root_cause: https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L214-L243
severity: Medium
poc_path: workspace/yield-claim-nft/test/poc-ECON-RAW-002.t.sol
-->

## Summary

Inside `BalancerPoolerV2.unlockCallback`, the donation swap `sUSDS -> waUSDC` is submitted with `limitRaw: 0` and a single `require(usdcReceived >= minUSDC)` is performed only after the waUSDC has been unwrapped to USDC. Because the Aave waUSDC -> USDC redeem rate is effectively constant within a block, the joint slippage check fails to protect the swap leg, allowing a sandwich on the sUSDS/waUSDC pool to extract value bounded only by a loose `minUSDC`.

## Vulnerability Detail

The donation phase is executed at [`BalancerPoolerV2.sol#L214-L243`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L214-L243). The swap params hard-code `limitRaw: 0` (any non-zero waUSDC out is accepted), and the only slippage gate is `require(usdcReceived >= minUSDC)` after `IERC4626(waUsdc).redeem(...)`.

This conflates two independent slippage surfaces into a single bound:

1. **Swap leg** — spot price of sUSDS/waUSDC on the Balancer V3 boosted pool at execution time. This is sandwichable.
2. **Unwrap leg** — the Aave waUSDC ERC4626 share-to-asset ratio. This is the Aave wrapper's `convertToAssets`, updated only as Aave interest accrues, and therefore effectively fixed within a single block.

Because the unwrap leg is fixed in-block, the entire variance in `usdcReceived` comes from the swap leg. Any sandwich on the sUSDS/waUSDC pool propagates one-for-one into `usdcReceived`. The pooler bot must set `minUSDC` loose enough to clear normal-state combined slippage; an attacker who can move the pool further than that loose threshold pockets the difference.

`limitRaw: 0` is not configurable by the caller — it is hard-coded in source. There is no per-leg cap, no `deadline`, and the donation swap shares the `unlockCallback` with the LP add (M-01), so a single MEV bundle can sandwich both legs in one tx.

Attack flow:

1. MEV bot observes `pool(minBPT, minUSDC)` in the mempool.
2. Front-run: flash-borrow sUSDS, swap sUSDS -> waUSDC on the donation pool to push waUSDC's price (per sUSDS) down.
3. `pool()` executes. The donation swap goes through at the degraded price; `limitRaw=0` does not revert. After unwrap, `usdcReceived` clears the loose `minUSDC` and the tx succeeds.
4. Back-run: reverse the swap, repay the flash loan, pocket the spread. `batchMinter` receives less USDC; the difference is captured by the searcher.

## Impact

Direct value leak from the protocol's donation/batch-minter funding stream. Every `pool()` broadcast publicly with non-zero `batchDonationSize` and a loose-by-necessity `minUSDC` is extractable.

The PoC, forked against mainnet using the real Balancer V3 Vault (`0xbA1333...`), Router (`0xAE563E...`), Permit2 (`0x000000...22D473`), and the real sUSDS/waEthUSDC/waEthUSDT boosted stable pool (`0x0B65A4...`), shows that at a 500 sUSDS attack size, USDC delivered to `batchMinter` drops from **219.0 USDC** (baseline) to **139.1 USDC** (sandwiched) — a **36.51% loss (~$79.97 victim loss)**, with the attacker recovering 570.99 sUSDS on 500 sUSDS input (~$77.87 attacker profit). A separate direct-proof test (`test_econ_raw_002_swap_leg_accepts_arbitrarily_bad_rate`) shows `pool()` succeeds with `minUSDC=1` even after the pool curve has been dumped by 400 sUSDS — confirming `limitRaw=0` is the structural gap, independent of how `minUSDC` is set.

Mitigating context: `pool()` is `onlyAuthorizedPooler` and the operator can submit privately. The bug is Medium rather than High because the at-risk assets are protocol-earmarked yield (USDC going to `batchMinter`) and the attack requires the external assumption of public mempool submission with a loose operator-set `minUSDC`. The amplification with M-01 (same `unlockCallback`, both legs sandwichable in one bundle) is real.

## Code Snippet

[`src/V2/dispatchers/BalancerPoolerV2.sol#L214-L243`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L214-L243):

```solidity
if (donationActive) {
    // 1. Send donation sUSDS to the vault, swap to waUSDC, settle.
    IERC20(_sUSDS).safeTransfer(_vault, donationSUSDS);
    VaultSwapParams memory swapParams = VaultSwapParams({
        kind: SwapKind.EXACT_IN,
        pool: swapPool,
        tokenIn: IERC20(_sUSDS),
        tokenOut: IERC20(waUsdc),
        amountGivenRaw: donationSUSDS,
        limitRaw: 0, // final slippage enforced on USDC after unwrap
        userData: ""
    });
    (, , uint256 waUsdcReceived) = IBalancerVault(_vault).swap(swapParams);
    IBalancerVault(_vault).settle(IERC20(_sUSDS), donationSUSDS);
    IBalancerVault(_vault).sendTo(IERC20(waUsdc), address(this), waUsdcReceived);

    // 2. Unwrap waUSDC -> USDC (ERC4626 redeem).
    uint256 usdcReceived =
        IERC4626(waUsdc).redeem(waUsdcReceived, address(this), address(this));

    // 3. Slippage check on the final delivered token (USDC).
    require(usdcReceived >= minUSDC, "BalancerPoolerV2: USDC slippage");

    // 4. Transfer USDC to BatchMinter.
    IERC20(usdc).safeTransfer(batchMinter, usdcReceived);

    emit BatchDonated(pooler, donationSUSDS, waUsdcReceived, usdcReceived, batchMinter);

    sUSDSAmount -= donationSUSDS;
}
```

## Tool Used

Manual Review + Foundry forked-mainnet PoC.

## Recommendation

1. **Add a per-leg slippage cap on the swap.** Extend `pool()` to take `minWaUsdc` (or `limitRaw` directly) and pass it through to the `VaultSwapParams`. The donation swap then reverts if pushed beyond a tight tolerance regardless of how the unwrap leg behaves.
2. **Split donation from LP-add** (or, at minimum, allow the operator to disable donation per-call) so the two legs are not both sandwichable in a single MEV bundle.
3. **Add a `deadline` parameter** to `pool()` and revert if `block.timestamp > deadline`.
4. **Operational guidance.** Document that the pooler operator must (a) submit `pool()` through a private relay (Flashbots Protect / MEV-Share / SUAVE) and (b) compute `minUSDC`/`minWaUsdc` from a fresh on-chain query made immediately before submission, not from a pre-cached estimate.

## Proof of Concept

`workspace/yield-claim-nft/test/poc-ECON-RAW-002.t.sol` is a forked-mainnet test using real Balancer V3 Vault, Router, Permit2, and the real sUSDS/waEthUSDC/waEthUSDT boosted stable pool — no AMM mocking. The headline test compares a baseline `pool()` against a sandwiched `pool()` at a 500 sUSDS attack size. A second test sweeps attack sizes and reports the profitability threshold. A third test (`test_econ_raw_002_swap_leg_accepts_arbitrarily_bad_rate`) directly demonstrates that `pool()` accepts an arbitrarily bad swap rate when `minUSDC` is set permissively, isolating `limitRaw=0` as the structural gap.
