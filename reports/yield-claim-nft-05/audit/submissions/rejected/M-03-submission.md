<!--
C4 Submission Metadata
Title: [M-03] Mint-debt ledger denominated in pre-wrap USDS drifts from sUSDS backing as DSR yield accrues
Root Cause Links:
  - Hook accrual site:      https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L89-L95 (the `added = (amount * ratio) / 100` line)
  - Dispatcher wrap site:   https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/dispatchers/BalancerPoolerV2.sol#L115-L116 (USDS->sUSDS wrap before hook notification)
PoC File: workspace/yield-claim-nft/test/poc-M-03.t.sol
-->

## Finding description and impact

### Summary

`BalancerPoolerMintDebtHook.onDispatch` records `mintDebt` in **pre-wrap USDS units**, but the dispatcher's actual backing for that debt is held in **sUSDS ERC4626 shares**. sUSDS is a yield-bearing vault whose `assetsPerShare` increases monotonically with DSR accrual. Because the hook ledger is frozen at the nominal USDS value supplied at dispatch, while the sUSDS backing continues to appreciate in USDS-equivalent terms, the invariant "debt = `ratio%` of backing" holds only at the instant of dispatch and drifts further out of alignment the longer `pull()` is deferred.

The consequence is a systematic, time-proportional value leak at `pull()` time: the recipient's phUSD claim is minted against a stale USDS number that no longer reflects `ratio%` of the current productive position.

### Vulnerability details

Two contracts cooperate to produce the bug.

**1. `BalancerPoolerV2._dispatch` (wrap site)** takes the user's USDS, approves sUSDS, and calls `IERC4626(_sUSDS).deposit(amount, address(this))`. After this line the dispatcher no longer holds USDS at all — it holds sUSDS shares whose USDS-equivalent value is determined by `sUSDS.convertToAssets(shares)`. The `amount` variable continues to denote pre-wrap USDS wei.

**2. `BalancerPoolerMintDebtHook.onDispatch` (accrual site, lines 89–95)** is invoked with that same pre-wrap `amount`:

```solidity
function onDispatch(address minter, uint256 amount, bytes calldata) external {
    if (msg.sender != dispatcher) revert OnlyDispatcher();
    uint256 added = (amount * ratio) / 100;   // amount is pre-wrap USDS
    if (added == 0) return;
    mintDebt += added;                         // ledger frozen in USDS units
    ...
}
```

The `amount` here is not a measurement of what the dispatcher actually received; it is the USDS value forwarded blindly from `ATokenDispatcherV2.dispatch`. No balance-before / balance-after check is performed around the sUSDS deposit, and no conversion to shares is done in the hook.

Once recorded, `mintDebt` cannot change until `pull()` zeroes it. Meanwhile, the underlying sUSDS in the Balancer pool continues to accrue DSR yield: the same share count represents strictly more USDS as time passes. The hook's notion of "how much ratio-tax to mint" therefore decouples from the economic reality of "how much value is actually being taxed".

At `pull()` time, phUSD is minted against the stale `mintDebt`. The recipient can then swap phUSD into the sUSDS/phUSD pool and drain sUSDS whose USDS-equivalent value is larger than the `ratio%` the protocol advertised it would take, with the excess sourced from NFT holders' share of the pooled backing.

Three observations on severity-relevant characteristics:

1. The drift is **monotonic with time** — it cannot self-correct, because DSR yield does not reverse.
2. The drift is **proportional to both `ratio` and the sUSDS growth factor** — it scales with protocol volume.
3. The drift is **silent** — there is no on-chain signal that `mintDebt` is stale; an external observer comparing `hook.mintDebt()` to `sUSDS.convertToAssets(dispatcherShares)` is the only way to detect it.

### Impact

**Severity: Medium.** This is a continuous value leak from NFT holders to the hook's recipient whose magnitude grows deterministically with elapsed time between dispatch and `pull()`. It is not an atomic theft (an attacker does not call it directly), which rules out High, but it materially impairs the protocol's stated tokenomics: the `ratio` parameter no longer means what it claims to mean. Over realistic holding periods (months to years, which is the natural cadence for yield-claim NFTs backed by DSR accrual) the leakage is material and non-trivial — see the PoC numbers below.

The assumption required for the leak to matter economically (phUSD trades near 1 USDS on the sUSDS/phUSD pool) is the same assumption the protocol's design already relies on, so this does not require any speculative market condition.

### Proof of Concept

A standalone Foundry PoC is provided at `workspace/yield-claim-nft/test/poc-M-03.t.sol`. It reconstructs the dispatch -> wrap -> hook flow with a minimal `DispatcherHarness` that mirrors `BalancerPoolerV2._dispatch` lines 115–116 verbatim, and uses a mock sUSDS with an `accrueYield(bps)` primitive to simulate DSR accrual on `assetsPerShare`.

**Scenario: 1,000,000 USDS dispatched, `ratio = 30%`.**

| Timepoint | `hook.mintDebt()` (USDS units) | Backing USDS-equiv | Effective ratio vs current backing | Drift vs configured 3000 bps |
|---|---|---|---|---|
| t = 0             | 300,000         | 1,000,000          | 3000 bps (3.00%) | 0 bps   |
| t = 1 yr, +5% DSR | 300,000 (frozen)| 1,050,000          | 2857 bps (2.857%)| ~143 bps |
| t = 3 yr, +5%/yr  | 300,000 (frozen)| 1,157,625 (1.05^3) | 2592 bps (2.592%)| ~408 bps |

Additional measurements from the PoC:
- **Backing growth over 3 years: ~1576 bps (15.76%)**, matching `1.05^3 - 1`.
- **Debt shortfall at 1 year: 15,000 USDS** on a 1M USDS dispatch — i.e. the recipient under-claims by 15k USDS relative to the `ratio%` of true current backing.
- **`phUSD` minted at `pull()` is exactly the t=0 frozen debt**, strictly less than `ratio%` of the yield-grown backing.

The PoC asserts all of the above and completes the full `dispatch -> warp 1yr -> accrueYield -> pull()` sequence on the real `BalancerPoolerMintDebtHook` contract (not a mock). The only mocks are USDS, sUSDS, and the minimal dispatcher shim, all of which preserve the exact storage/call surface the hook observes.

Run with:

```
forge test --match-test test_M03_DebtDoesNotTrackSUSDSYieldAccrual -vv
```

## Recommended mitigation steps

The root cause is that the hook's `amount` parameter is semantically the wrong quantity — it is a user-input USDS value, not a measurement of the dispatcher's post-wrap productive holdings. Any of the following fixes resolves the drift; they can be combined.

### Option A — Denominate debt in sUSDS shares (preferred)

Extend `IDispatchHook` with an overload (or a second callback) that carries the post-wrap measurement, and have `BalancerPoolerV2._dispatch` measure sUSDS shares actually received via balance-before / balance-after around the `deposit`:

```solidity
// In BalancerPoolerV2._dispatch (around lines 115-116)
uint256 beforeShares = IERC20(_sUSDS).balanceOf(address(this));
IERC20(_USDS).approve(_sUSDS, amount);
IERC4626(_sUSDS).deposit(amount, address(this));
uint256 sharesReceived = IERC20(_sUSDS).balanceOf(address(this)) - beforeShares;

// Pass sharesReceived to the hook instead of (or alongside) amount.
hook.onDispatch(minter, sharesReceived, outputAssetTag, "");
```

The hook then accrues `mintDebt` in sUSDS-share space:

```solidity
uint256 added = (sharesReceived * ratio) / 100;
mintDebt += added; // now in sUSDS shares
```

At `pull()` time, convert the share-denominated debt to phUSD using the current `sUSDS.convertToAssets(mintDebt)`. This makes `mintDebt` track DSR yield by construction — the share count is constant, but its USDS-equivalent minted as phUSD grows with the backing.

### Option B — Convert USDS amount to sUSDS shares at dispatch time

If the hook's `IDispatchHook` interface cannot be changed, the hook itself can query sUSDS and store shares:

```solidity
uint256 sharesAtDispatch = IERC4626(sUSDS).convertToShares(amount);
uint256 added = (sharesAtDispatch * ratio) / 100;
mintDebt += added;
```

Plus the same `convertToAssets`-on-`pull()` change. This is functionally equivalent to Option A for any well-behaved ERC4626 where `convertToShares(deposit)` matches the shares actually minted (modulo 1-wei rounding).

### Option C — Snapshot the sUSDS rate per dispatch

Instead of storing shares, store `(amount, assetsPerShareAtDispatch)` tuples and, on `pull()`, scale each tuple's nominal USDS value by `currentAssetsPerShare / assetsPerShareAtDispatch` before summing. This preserves the existing USDS-denominated ledger shape at the cost of more storage; it yields the same economic outcome as Options A/B.

### Additional hardening

Independent of the drift fix, `BalancerPoolerV2._dispatch` should adopt balance-before / balance-after accounting around the `sUSDS.deposit` call regardless, so that ERC4626 rounding (which favours the vault, not the depositor) and any future sUSDS minimum-share-floor semantics cannot cause the dispatcher's internal accounting to silently diverge from its actual holdings.
