<!--
title: Donation revert inside unlockCallback bricks the LP-add phase; pool() is fully DoS'd by USDC blocklist, Aave pause, or donation-pool depletion until owner intervenes
root_cause: https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L207-L243
severity: Medium
poc_path: workspace/yield-claim-nft/test/poc-ECON-RAW-006.t.sol
-->

## Summary

`pool()` executes the donation phase and the LP-add phase inside a single `unlockCallback`. Any revert inside the donation leg — USDC blocklisting of `batchMinter`, Aave waUSDC market pause, donation-pool depletion, or excessive swap-leg slippage — reverts the entire transaction and blocks the otherwise-healthy LP-add. Three independent, mainnet-precedented external events each fully brick `pool()` until the owner reconfigures the dispatcher.

## Vulnerability Detail

The donation and LP-add phases share an `unlockCallback` ([`BalancerPoolerV2.sol#L207-L243`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L207-L243) for donation; [`L246-L273`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L246-L273) for LP add). There is no `try`/`catch` around the donation external calls, no `skipDonation` parameter, and no separate function to perform only the LP add. The donation leg is gated solely on configuration being non-zero (`batchDonationSize > 0 && batchMinter != 0 && swapPool != 0 && waUsdc != 0 && usdc != 0`); once that predicate is satisfied, the donation must succeed for `pool()` to succeed.

Three independent failure surfaces each brick the call:

**A) USDC blocklist of `batchMinter`.** Circle's `FiatTokenV2.1` enforces a `blacklisted` mapping; transfers to a blacklisted address revert with `Blacklistable: account is blacklisted`. Precedent: Tornado Cash sanctions, August 2022, ~$75k frozen. If `batchMinter` (or any address routed through it) is ever blacklisted, `IERC20(usdc).safeTransfer(batchMinter, ...)` at line 238 reverts and every `pool()` call fails until the owner re-points `batchMinter` via `setBatchMinter`.

**B) Aave waUSDC market pause.** Aave's Pause Guardian can pause individual markets (governance vote or emergency admin action; precedent: Aave market freezes during the AAVE token vote in late 2022). `IERC4626(waUsdc).redeem(waUsdcReceived, address(this), address(this))` at line 232 reverts. `pool()` cannot progress until Aave unpauses; sUSDS continues to accumulate in the dispatcher.

**C) Donation pool depletion / excessive slippage.** If the sUSDS/waUSDC Balancer pool's waUSDC side is drained (arbitrageurs, JIT-LP removal, or an extreme depeg), the swap reverts (out-of-range / insufficient liquidity) or yields `waUsdcReceived` below `minUSDC` after unwrap. `pool()` reverts until pool conditions recover.

In each case the **secondary damage** is that the LP-add phase is also blocked — even though the sUSDS/phUSD pool is healthy and the LP add would have succeeded. The protocol's primary value-flow mechanism is halted by an unrelated impairment of the donation leg.

The dispatcher's owner has `rescueERC20` as an escape hatch ([line 314](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L314)), and `setBatchMinter(address(0))` cleanly disables donation. Both require an owner transaction; neither is automated recovery. During the impairment window, batch-minting cadence is halted entirely.

## Impact

Full denial of service of `pool()` — the protocol's primary value-flow mechanism — triggered by any of three independent, mainnet-precedented external conditions. Recovery requires owner intervention (re-configuring `batchMinter`, waiting for Aave to unpause, or waiting for the donation pool to recover). sUSDS remains locked in the dispatcher during the window; it is not lost, but cadence is halted and downstream BPT accrual is paused.

This is "function of the protocol or its availability could be impacted" — clearly Medium per C4. It is not High because assets are not directly at risk: funds remain in the dispatcher, and recovery is owner-controlled rather than attacker-driven.

## Code Snippet

[`src/V2/dispatchers/BalancerPoolerV2.sol#L207-L243`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L207-L243):

```solidity
// -------- Donation phase (optional) --------
uint256 donationSUSDS = (sUSDSAmount * batchDonationSize) / 100;
bool donationActive = donationSUSDS > 0
    && batchMinter != address(0)
    && swapPool != address(0)
    && waUsdc != address(0)
    && usdc != address(0);

if (donationActive) {
    // 1. Send donation sUSDS to the vault, swap to waUSDC, settle.
    IERC20(_sUSDS).safeTransfer(_vault, donationSUSDS);
    VaultSwapParams memory swapParams = VaultSwapParams({
        kind: SwapKind.EXACT_IN,
        pool: swapPool,
        tokenIn: IERC20(_sUSDS),
        tokenOut: IERC20(waUsdc),
        amountGivenRaw: donationSUSDS,
        limitRaw: 0,
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

Manual Review + Foundry PoC (production `BalancerPoolerV2` unmodified; mocks scoped to non-Balancer surfaces — `BlocklistableUSDC` mirrors Circle's `blacklisted` mapping and revert string, `PausableWaUSDC` mirrors the Aave Pause Guardian, `MockBalancerVault` bubbles inner reverts so the abort cascade matches mainnet behaviour).

## Recommendation

1. **Decouple donation from LP-add.** Either split them into two functions, or add a `skipDonation` parameter to `pool()` so an operator can complete the LP add even when the donation leg is impaired.
2. **Try/catch around the donation external calls.** Wrap the swap / `sendTo` / `redeem` / `safeTransfer` so that on failure the donation slice is deferred (track as a separately-accounted deferred-donation ledger) and the LP add proceeds with the full sUSDS balance. This handles transient mainnet conditions (Aave pauses, blocklist events, temporary pool depletion) gracefully.
3. **Document the emergency playbook.** `setBatchMinter(address(0))` already disables donation cleanly; add a runbook explicitly listing the failure modes (blocklist / pause / pool depletion / depeg) and the recovery sequence for each. Consider a timelock-bypass-for-emergency on `setBatchMinter` so the operator can act fast when blocklists hit.

## Proof of Concept

`workspace/yield-claim-nft/test/poc-ECON-RAW-006.t.sol` runs five tests against unmodified `BalancerPoolerV2`:

1. **Sanity baseline** — healthy `pool()` succeeds.
2. **USDC blocklist DoS** — `pool()` reverts with `Blacklistable: account is blacklisted` after `BlocklistableUSDC` blocklists `batchMinter`.
3. **Aave waUSDC pause DoS** — `pool()` reverts with `PAUSED: aave market frozen` after `PausableWaUSDC` is paused, then auto-recovers when unpaused.
4. **Donation pool depleted** — `pool()` reverts with `BAL: swap pool depleted`.
5. **Recovery requires owner intervention** — demonstrates that `setBatchMinter(address(0))` is needed to bypass the impairment and let the LP add proceed.

No imagined AMM behaviour — the PoC only exercises revert propagation through the shared `unlockCallback`.
