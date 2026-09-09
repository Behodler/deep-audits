<!--
title: BalancerPoolerMintDebtHook accrues phUSD debt against dispatched USDS notional, fully decoupled from realisable USDC; debt can be minted with zero backing
root_cause: https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L112-L122
severity: Medium
poc_path: workspace/yield-claim-nft/test/poc-ECON-RAW-003.t.sol
-->

## Summary

`BalancerPoolerMintDebtHook.onDispatch` accrues phUSD mint-debt as `amount * ratio / 100` of the dispatched USDS notional, while the USDC eventually delivered to `batchMinter` depends on the sUSDS/waUSDC pool spot, the Aave waUSDC redeem rate, the USDC peg, and whether the donation phase is enabled at all. The two ledgers are entirely decoupled, so phUSD can be minted to `recipient` against USDC that was never produced — most damningly when `batchDonationSize = 0` and zero USDC backing exists.

## Vulnerability Detail

The hook's accrual logic is at [`BalancerPoolerMintDebtHook.sol#L112-L122`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L112-L122):

```solidity
function onDispatch(
    address minter,
    uint256 amount,
    bytes calldata
) external {
    if (msg.sender != dispatcher) revert OnlyDispatcher();
    uint256 added = (amount * ratio) / 100;
    if (added == 0) return;
    mintDebt += added;
    emit DebtAccrued(minter, amount, added, mintDebt);
}
```

`amount` is the FOT-adjusted USDS notional passed into `_dispatch` ([`BalancerPoolerV2.sol#L178-L184`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L178-L184)), which is immediately wrapped to sUSDS. The corresponding USDC delivery, when it happens at all, occurs later inside `pool()` via the donation phase ([`BalancerPoolerV2.sol#L214-L243`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L214-L243)). The hook has no visibility into:

- the sUSDS ERC4626 share price at dispatch (sUSDS appreciates against USDS),
- the sUSDS/waUSDC pool spot at `pool()` time, including the V3 swap-fee penalty,
- the Aave waUSDC redeem rate at `pool()` time,
- USDC's market price vs USDS (USDC depegged to ~$0.87 during the SVB event in March 2023),
- whether `batchDonationSize`, `batchMinter`, `swapPool`, `waUsdc`, and `usdc` are all set non-zero — the gating predicate for the donation phase to execute at all.

`mintDebt` is realised by a separate `pull()` call that mints the full accrued debt to `recipient` regardless of how much USDC the dispatcher actually delivered.

The PoC enumerates four scenarios:

- **Scenario A (sUSDS appreciation):** phUSD under-minted by 3,000e18 against 52,000 USDC backing — windfall to `batchMinter` but phUSD undercollateralisation relative to assets produced.
- **Scenario B (donation disabled, `batchDonationSize = 0`):** **49,000e18 phUSD minted with 0 USDC backing produced through the donation path.** Every dispatch still accrues debt under the configured ratio. None of the sUSDS is ever converted to USDC, yet `pull()` mints the full debt. This is the most damning case.
- **Scenario C (USDC depeg):** 85k USDC delivered against 49k phUSD debt — ledger decoupling visible in the other direction.
- **Scenario D (partial donation + USDC depeg):** 49,000e18 phUSD over-issued by exactly 7,350e18 against 41,650 USDC backing (15% mismatch).

Scenario B is the structural worst case: it is reachable simply by the owner setting `batchDonationSize = 0` (or by leaving any of `swapPool` / `waUsdc` / `usdc` / `batchMinter` unset), and there is nothing in the hook that prevents debt from accruing while the donation phase is dormant.

## Impact

phUSD is a user-facing token; its value rests on the backing assets the protocol accrues against it. This bug mints phUSD against USDS notional the donation flow never converts to USDC, **diluting existing phUSD holders' pro-rata claim on backing assets**. Scenario A is a slow-drip dilution scaling with sUSDS/USDS/USDC deviation; Scenario B is a one-shot inflationary mint with zero corresponding USDC backing produced.

The known-issues clause that "owner sets prices" arguably covers `setRatio` misuse, but does not cover this finding. The defect is structural: even with a legitimate ratio and any legitimate `batchDonationSize` (including zero), the hook accrues against the wrong upstream signal (dispatched USDS notional rather than realised USDC). The decoupled-ledger design sits outside owner-trust scope.

Severity is Medium rather than High because materialisation requires a specific protocol configuration (Scenario B's `batchDonationSize = 0`, or Scenarios A/D's sUSDS appreciation / USDC depeg) — a stated external requirement per C4 Medium criteria — and the realised harm is holder dilution rather than direct theft.

## Code Snippet

[`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L112-L122`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L112-L122):

```solidity
function onDispatch(
    address minter,
    uint256 amount,
    bytes calldata
) external {
    if (msg.sender != dispatcher) revert OnlyDispatcher();
    uint256 added = (amount * ratio) / 100;
    if (added == 0) return;
    mintDebt += added;
    emit DebtAccrued(minter, amount, added, mintDebt);
}
```

[`src/V2/dispatchers/BalancerPoolerV2.sol#L178-L184`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98/src/V2/dispatchers/BalancerPoolerV2.sol#L178-L184):

```solidity
function _dispatch(address, uint256 amount, bytes calldata /*extraData*/)
    internal
    override
{
    IERC20(_primeToken).forceApprove(_sUSDS, amount);
    IERC4626(_sUSDS).deposit(amount, address(this));
}
```

## Tool Used

Manual Review + Foundry PoC (production `NFTMinterV2`, `BalancerPoolerV2`, `BalancerPoolerMintDebtHook` unmodified; Balancer V3 vault/router mocked because V3 cannot be ergonomically deployed in a unit test — the hook bug is independent of AMM math).

## Recommendation

The root cause is the decoupled-ledger design. Pick one of:

1. **Compute debt from realised USDC.** Move accrual out of `onDispatch` and into `unlockCallback`: have `BalancerPoolerV2` report `usdcReceived` to the hook (or accrue debt directly there) so `mintDebt` tracks the asset actually delivered to `batchMinter`.
2. **Disable the hook when donation is dormant.** Require that whenever `batchDonationSize == 0` or any of `batchMinter` / `swapPool` / `waUsdc` / `usdc` is unset, the hook is swapped out for `DefaultDispatchHook` so debt cannot accrue against undeliverable USDC. Closes Scenario B specifically.
3. **Cap `pull()` at an oracle-derived fair value** of the dispatcher's expected donation outputs (sUSDS->USDC), with a tight tolerance for USDC peg risk.

A combination of (1) and (2) is preferable: tie accrual to what's actually produced, and refuse accrual entirely when no production will happen.

## Proof of Concept

`workspace/yield-claim-nft/test/poc-ECON-RAW-003.t.sol` exercises the four scenarios above against unmodified production contracts. Scenario B is the most damning: `batchDonationSize` is set to zero, the dispatcher receives 100,000 USDS of dispatches at ratio=49, and the hook accrues `49,000e18` phUSD mint-debt while `0` USDC is delivered to `batchMinter`. `pull()` then mints the full `49,000e18` to `recipient` against literally zero USDC backing produced via the donation path.
