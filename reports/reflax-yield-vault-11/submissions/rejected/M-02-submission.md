<!--
ID: ryv11m2
C4 Submission Metadata
Title: [M-02] ERC4626 vault share price used as slippage oracle — donation attack permanently DoS-es deposits, withdrawals, and `skimSurplus`
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L312-L318
PoC File: poc-M02-vault-oracle-dos.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy` derives its AMM slippage floor (`minOut`) directly from `vault.convertToShares()` and `vault.convertToAssets()`, which are functions of the vault's spot `totalAssets / totalSupply` ratio. A standard ERC4626 vault exposes this ratio to manipulation: any actor can transfer underlying tokens directly to the vault address, instantly inflating `totalAssets` and therefore the share price. Once the oracle-inflated `minOut` exceeds what the Curve AMM can deliver, every call to `withdraw`, `withdrawAsOwner`, `_totalWithdraw`, and `skimSurplus` reverts. The DoS is stable for as long as the donation remains in the vault.

### Vulnerability details

Three separate code paths all derive `minOut` from the vault's manipulable spot price.

**`_depositInternal` — L312**

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol L308-L318
creditedPrincipal = _creditedPrincipal(amount);

// Minimum acceptable swap output derived from the SAME haircut value
uint256 minOut = vault.convertToShares(creditedPrincipal);  // <-- spot price oracle

underlyingToken.safeIncreaseAllowance(address(ammAdapter), amount);
uint256 sharesReceived = ammAdapter.swap(
    address(underlyingToken), address(vault), amount, minOut
);
```

After a donation, `convertToShares` returns a deflated (fewer shares per underlying) value, so `minOut` on deposit falls — deposits are unaffected by the inflation and continue to succeed. However the strategy then holds vault shares that `convertToAssets` reports as being worth far more underlying than the AMM will actually pay.

**`_withdrawInternal` — L350-L358**

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol L350-L358
uint256 sharesToSell = vault.convertToShares(amount);
uint256 availableShares = vault.balanceOf(address(this));
if (sharesToSell > availableShares) {
    sharesToSell = availableShares;
}

uint256 idealUnderlying = vault.convertToAssets(sharesToSell);   // <-- spot price oracle
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
```

After a donation, `convertToAssets(sharesToSell)` returns an inflated `idealUnderlying`. The AMM's price has not changed, so its output is unchanged. Once `minOut > ammOutput`, the swap reverts and the withdrawal is completely blocked.

**`_skimSurplus` via `_accrueSurplusShares` — L457-L471**

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol L457-L471
uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this)));  // snapshot

// ... per-client surplus shares accumulated in _accrueSurplusShares:
uint256 shares = vault.convertToShares(surplus);   // <-- spot price oracle

// back in _skimSurplus:
uint256 idealUnderlying = vault.convertToAssets(totalShares);  // <-- spot price oracle
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
```

The same inflation path applies; yield collection is DoS-ed alongside withdrawals.

**Attack math**

Let `S` = strategy's vault shares, `P` = vault `totalSupply`, `A_pre` = vault `totalAssets` before donation, `D` = donation amount. After donation:

```
totalAssets_post = A_pre + D
convertToAssets(S) = S * (A_pre + D) / P
minOut             = convertToAssets(S) * (MAX_BPS - slippage) / MAX_BPS
AMM output         = S * market_price  (unchanged)
```

DoS condition: `S * (A_pre + D) / P * (MAX_BPS - slippage) / MAX_BPS > S * market_price`

Simplifying: `D > P * market_price * MAX_BPS / (MAX_BPS - slippage) - A_pre`

For a vault starting at near-zero `totalAssets` (common for a freshly deployed or thinly-used vault) and a 1% slippage tolerance, the attacker needs to donate only slightly more than `P * market_price / 0.99` worth of underlying — which for small position sizes is cheap. The donation is not burned; the attacker can recover the full amount by redeeming vault shares in any vault that permits open redemption (e.g. sUSDe once the cooldown lapses).

**The DoS is self-sustaining**: after the donation the vault's `totalAssets` remains inflated until the vault processes normal redemptions that drain it. Since withdrawals from the strategy itself are frozen, the attacker's donation cannot be diluted by the strategy's own activity — the DoS cannot self-heal.

### Impact

Any authorized caller of `withdraw`, `withdrawAsOwner`, `_totalWithdraw`, or `skimSurplus` is denied service for as long as the donation persists. Users whose principal is recorded in the strategy cannot recover funds through normal channels. The protocol's yield collection is also blocked, which prevents downstream consumers (e.g. `stableYieldAccumulator`) from receiving yield proceeds. The only escape path is the owner's `emergencyWithdraw`, which transfers raw vault shares to the owner and bypasses the AMM — but this requires manual owner intervention and is not available to normal users.

The attack requires no privileged access and costs only the gas for an ERC20 transfer. On vaults with open redemption, the donated capital can be recovered, making the sustained DoS economically viable.

## Recommended mitigation steps

**Primary recommendation — use an independent price source for `minOut`.**

Replace `vault.convertToAssets` / `vault.convertToShares` in the `minOut` computation with a price derived from a Chainlink feed or a TWAP oracle for the underlying/vault-share pair. The vault ratio is a useful accounting tool but is not manipulation-resistant as a slippage oracle.

```solidity
// Example: replace the spot convertToAssets call with a Chainlink-backed price
uint256 idealUnderlying = priceOracle.getUnderlyingValue(sharesToSell);
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
```

**Alternative — time-weighted share price.**

If a Chainlink feed is unavailable for the vault share, maintain an EMA or TWAP of the vault's share price that is updated on each interaction and cannot be moved more than a configurable bound in a single block:

```solidity
uint256 twapPrice = _updateAndGetTWAP(); // max delta-per-block capped
uint256 minOut = sharesToSell * twapPrice / PRICE_PRECISION
                 * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
```

**Minimum mitigation — sanity-bound the spot price.**

If neither oracle option is immediately feasible, add a staleness / deviation check that rejects `convertToAssets` values that exceed a stored reference price by more than `N%` per block. This does not eliminate the attack but raises the required donation and provides a configurable circuit-breaker:

```solidity
uint256 spotPrice = vault.convertToAssets(1e18);
require(
    spotPrice <= lastKnownPrice * (MAX_BPS + maxPriceDeviationBps) / MAX_BPS,
    "ERC4626MarketYieldStrategy: share price deviation too large"
);
```

This minimum mitigation should be combined with `emergencyWithdraw` documentation so operators know to act when the circuit-breaker fires.
