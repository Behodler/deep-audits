<!--
ID: ns12h1
C4 Submission Metadata
Title: [H-01] Value-blind nudge gate lets any caller drain the entire nudge pot for a fraction of its value (incomplete fix of the prior nudge-drain exploit)
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L214-L226
PoC File: poc-NudgeDrain.t.sol
Ledger Fingerprint: 858e9e807abee888b378db210bae982f23fe7b5d91052321e204d7ba568579b7
-->

## Finding description and impact

### Summary

`BatchNFTMinter.batchMint` pays out its **entire** `nudgePaymentToken` balance to a caller-chosen `recipient` whenever the purely numeric condition `count >= nudgeSize` is satisfied ([`BatchNFTMinter.sol#L214-L226`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L214-L226)). The gate is **value-blind**: it never relates the size of the pot it releases to the value the caller actually paid. Because `batchMint` is permissionless and `count`, `dispatcherIndex`, and `recipient` are all caller-controlled, any outsider can clear the gate with the cheapest possible qualifying batch and seize the whole pot.

This is the central case, and it does **not** depend on any admin misconfiguration: the nudge pot is funded externally and asynchronously (e.g. a yield funnel directing USDC into the contract — see the NatSpec at [`BatchNFTMinter.sol#L31-L35`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L31-L35)). The pot grows monotonically with yield inflow, while the attacker's cost to clear the gate is fixed at roughly `nudgeSize × latestPrice` for the cheapest registered dispatcher. The pot therefore *inevitably* drifts above that fixed qualifying cost during normal operation. The moment `pot_balance > nudgeSize × cheapest_price`, any permissionless caller can drain the full pot at a net profit. This is a "when, not if" condition under the feature's intended operating state.

### Vulnerability details

The nudge payout in `batchMint`:

```solidity
uint256 _nudgeSize = nudgeSize;
if (_nudgeSize != 0 && count >= _nudgeSize) {          // PURELY NUMERIC gate
    if (_nudgeTokenEntry != address(0)) {
        uint256 nudgeAmount = IERC20(_nudgeTokenEntry).balanceOf(address(this));
        if (nudgeAmount != 0) {
            IERC20(_nudgeTokenEntry).safeTransfer(recipient, nudgeAmount);  // ENTIRE balance
            emit NudgePaid(recipient, _nudgeTokenEntry, nudgeAmount);
        }
    }
}
```

The qualifying predicate is `count >= nudgeSize` — a count of *mints*, with no reference to how much `paymentToken` value those mints cost. The payout is the contract's **full** `nudgePaymentToken` balance, regardless of how far that balance exceeds the qualifying cost. The function is `external whenNotPaused` with no caller restriction ([`BatchNFTMinter.sol#L184-L190`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L184-L190)), and `dispatcherIndex` is a free call parameter ([`BatchNFTMinter.sol#L186`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L186)), so the caller picks the cheapest registered dispatcher to minimize cost while still incrementing `count`.

**Incomplete-fix narrative.** The dev NatSpec at [`BatchNFTMinter.sol#L17-L29`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L17-L29) documents a prior fix: the minter was pinned to owner-set state so that an attacker can no longer pass a no-op minter and fake cheap "mints." The stated goal is that "qualifying for the nudge now requires genuinely paying for `>= nudgeSize` real mints at the dispatcher's ramping price." That fix closes the *no-op-minter* drain but leaves the *value-blind full-pot payout* intact. The stated goal fails on its own terms: the attacker still minimizes the qualifying cost (cheapest dispatcher, `count == nudgeSize`) while seizing a pot whose value bears no relation to that cost. Genuinely paying for `nudgeSize` mints at the cheapest dispatcher's price is cheap; the pot is not.

**Root cause is in scope.** The defect is the value-blind `count >= nudgeSize` condition releasing the entire balance, inside the in-scope `BatchNFTMinter`. The sibling `NFTMinterV2`'s permissive pricing — `registerDispatcher`/`setPrice` impose no minimum price ([`NFTMinterV2.sol#L125`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L125), [`#L282`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L282)) and `mint` is permissionless ([`#L159`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L159)) — is out-of-scope *context/amplifier*, not the root cause. The gate is exploitable even with a well-priced sibling once the pot grows past the qualifying cost (see Variant B in the PoC), so this is not an "OOS parent root cause" issue.

**Zero-price amplifier (secondary).** If any registered dispatcher is cheaply or zero-priced — which `NFTMinterV2` permits with no min-price validation — the attacker's cost approaches zero, and the drain becomes free. This amplifier alone would be admin-misconfiguration-dependent and is explicitly **not** the basis for the High severity; it merely makes an already-profitable attack costless.

### Impact

Protocol-owned nudge funds (externally-funded `nudgePaymentToken`, e.g. USDC) are redirected from the intended large-batch participant to a minimal-cost sniper who calls `batchMint` permissionlessly. The intended recipient of the nudge incentive is front-run, and the entire pot is captured by an outsider.

This is not theft of user staking deposits — it is **protocol-treasury value captured permissionlessly** via a valid attack path with no hypotheticals. It qualifies as High under C4: assets are lost via a realistic attack path, with the only precondition being the feature's intended operating state.

**Precondition (stated honestly).** The only external requirement is that the nudge feature is enabled and funded: `nudgeSize > 0` and `nudgePaymentToken` set, with a non-zero pot balance. That is the feature's intended operating state, not an edge configuration. No admin error is required.

**Rebuttal of "working as designed."** The nudge is intended to reward proportional participation in large batches. But the payout is the *entire* balance regardless of how far the pot exceeds the qualifying cost. Once `pot > nudgeSize × cheapest_price`, the rational behavior of any outsider is to snipe the pot via the minimum qualifying batch, and the intended recipients are front-run. The mechanism does not implement the proportionality it is meant to reward.

## Recommended mitigation steps

The fix must couple the payout to the value actually spent, rather than to the raw mint `count`:

1. **Gate and scale on cumulative payment value, not `count`.** Track the cumulative `paymentToken` value actually charged across the loop and qualify/scale the nudge on that figure instead of `count >= nudgeSize`.

2. **Pay a bounded, proportional nudge instead of the entire balance.** For example, pay `min(potShare, k × totalPaid)` for a configured constant `k`, so the payout can never exceed a multiple of what the caller genuinely spent. This removes the windfall regardless of how large the pot grows.

3. **Optionally cap the per-call payout** to a configured maximum, and/or **pin `dispatcherIndex` to owner-set state** so the caller cannot freely select the cheapest dispatcher to minimize qualifying cost.

Illustrative shape:

```solidity
// totalPaid computed from actual cumulative dispatcher charges over the loop
uint256 potBalance = IERC20(_nudgeTokenEntry).balanceOf(address(this));
uint256 payout = Math.min(potBalance, nudgeFactor * totalPaid); // bounded & proportional
if (payout != 0) {
    IERC20(_nudgeTokenEntry).safeTransfer(recipient, payout);
    emit NudgePaid(recipient, _nudgeTokenEntry, payout);
}
```

This keeps the intended large-batch incentive while ensuring the released amount is always proportional to genuine spend, eliminating the snipe.
