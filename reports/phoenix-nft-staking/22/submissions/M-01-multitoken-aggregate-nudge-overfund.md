<!--
ID: pns22m1
C4 Submission Metadata
Fingerprint: 43e8c486
Title: [M-01] Multi-token nudge whitelist lets one qualifying batch capture the aggregate pot across all whitelisted tokens, making a per-token-safe owner configuration net-profitable to snipe
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinterMultiToken.sol#L405-L434
PoC File: workspace/phoenix-nft-staking/test/poc-M01-aggregate-nudge.t.sol (test_M01_aggregateNudgeSnipeProfitsDespitePerTokenUnderMargin)
Related ledger finding: 858e9e80 (H-01, per-token nudge snipe; dispositioned wont-fix / Medium-at-HEAD) — see disclosure below
-->

## Finding description and impact

### Summary

`BatchNFTMinterMultiToken.batchMint` pays out the **entire pre-loop balance of every whitelisted nudge token** to a single caller-chosen recipient when a batch clears a **count-only** gate (`count >= nudgeSize`), in exchange for one fixed qualifying cost (`nudgeSize` mints at the current mint price). Because the payout is the **sum of all whitelisted pots** while the qualifying cost is a **single fixed spend**, the whitelist becomes collectively snipeable as soon as `Σ(pot_i)` exceeds that one cost — even when the owner has funded **every token individually below** the cost, exactly as the contract's own safety guidance instructs. A diligent, non-malicious owner following the stated per-token rule can therefore stand up a configuration that is net-profitable to snipe, leaking owner-seeded reward tokens to an at-will attacker.

### Vulnerability details

The gate is purely on count ([`BatchNFTMinterMultiToken.sol#L405-L408`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinterMultiToken.sol#L405-L408)):

```solidity
bool qualifies;
{
    uint256 _nudgeSize = nudgeSize;
    qualifies = _nudgeSize != 0 && count >= _nudgeSize;
}
uint256[] memory snapshot = _snapshotRewards(minRewards, address(paymentToken), qualifies);
```

`_snapshotRewards` then reads the **full `balanceOf` of each whitelisted token** ([`#L516`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinterMultiToken.sol#L516)):

```solidity
uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;
```

and `_payRewards` transfers each entire snapshot entry to the caller-supplied `recipient` ([`#L541-L549`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinterMultiToken.sol#L541-L549), recipient chosen at [`#L372`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinterMultiToken.sol#L372)):

```solidity
function _payRewards(address recipient, uint256[] memory snapshot) private {
    uint256 tokenCount = snapshot.length;
    for (uint256 i; i < tokenCount; ++i) {
        uint256 amount = snapshot[i];
        if (amount == 0) continue;
        address rewardToken = _nudgeTokens[i];
        IERC20(rewardToken).safeTransfer(recipient, amount);
        emit NudgePaid(recipient, rewardToken, amount);
    }
}
```

There is no value accounting anywhere in this path. The single count-only gate authorises the sweep of the **whole whitelist at once**, so:

- **Payout** = `Σ_i pot_i` — scales linearly with the number of whitelisted tokens `N`.
- **Qualifying cost** = `nudgeSize × mintPrice` — fixed, independent of `N`.

The economic safety bound the contract documents is stated **per token** and is silent on cross-token summation ([NatSpec `#L57-L69`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinterMultiToken.sol#L57-L69)):

> *"The 'honeypot' framing does not apply, because the pot is by construction a fraction of the cost of the `nudgeSize` mints required to qualify — every claim is net-positive for the protocol."*

A competent owner reads "the pot is a fraction of the qualifying cost" **per token** — funding each token's pot strictly below one qualifying cost — and reasonably concludes each is snipe-safe (a sniper who paid the full cost to drain one under-cost pot takes a loss). The count-only aggregate payout breaks that reasoning silently: with `N ≥ 2` tokens each individually under the margin, `Σ(pot_i)` can still exceed the single fixed cost, and the whole whitelist is captured for one qualifying spend. Nothing in the code or the stated rule warns the owner that the safety bound must hold in **aggregate**, not per token — so the consequence is genuinely surprising to a non-malicious owner. Under the three-law hierarchy this is an in-scope **owner footgun** (Law 3): a non-obvious owner configuration hazard that unknowingly enables a value leak.

### Impact

An attacker who observes an armed configuration where `Σ(pot_i) > nudgeSize × mintPrice` calls `batchMint(nudgeSize, attackerRecipient, cost, [0,...])` once and walks away with the entire whitelist's reward balances for a single qualifying spend, netting the positive difference. The path is **permissionless and at-will** (any address, any time the pool is armed and not paused), and the recipient is caller-chosen, so the attacker keeps the loot even if the mints themselves are directed elsewhere. The leaked value is owner-seeded reward token.

Severity is **Medium**, not High: arming requires an owner-controlled funding precondition (whitelisting `N ≥ 2` tokens and seeding them such that `Σ(pot_i)` clears the qualifying cost) that the **attacker cannot create** — the attacker only snipes an already-armed pot. There is also **zero present on-chain exposure** at the current mainnet configuration. The finding is a realistic value-leak hazard that materialises the moment a per-token-diligent owner arms a multi-token whitelist, which is precisely the configuration the multi-token feature exists to support.

### Proof of Concept

Runnable Foundry test: `workspace/phoenix-nft-staking/test/poc-M01-aggregate-nudge.t.sol`, test `test_M01_aggregateNudgeSnipeProfitsDespitePerTokenUnderMargin` (PASS, validated).

The test whitelists three par-valued 18-decimal tokens, funds each pot at **40% of one qualifying cost** (so each is individually under the per-token margin), and has the attacker pay the single qualifying cost exactly once:

- single qualifying cost (paid once): **5256.33e18**
- per-token pot, each: **2102.53e18** (40% of cost → each pot alone < cost → a per-token snipe is a net loss)
- aggregate captured `Σ(pot_i)`: **6307.59e18**
- **net profit** (aggregate haul − cost): **1051.27e18**

Key load-bearing assertions (the aggregation delta):

```solidity
// (1) EACH pot alone is under the single qualifying cost -> per-token snipe is a loss
assertLt(haulA, qualifyingCost, "DELTA: pot A alone < qualifying cost -> per-token snipe is a loss");
assertLt(haulB, qualifyingCost, "DELTA: pot B alone < qualifying cost -> per-token snipe is a loss");
assertLt(haulC, qualifyingCost, "DELTA: pot C alone < qualifying cost -> per-token snipe is a loss");

// (2) YET the AGGREGATE haul exceeds the single qualifying cost -> aggregate snipe profits
assertGt(aggregateHaul, qualifyingCost, "DELTA: Sigma(pot_i) > single qualifying cost -> aggregate snipe profits");

// (3) Concrete net profit
uint256 netProfit = aggregateHaul - qualifyingCost;
assertGt(netProfit, 0, "M-01 demonstrated: attacker walks away net-positive despite every pot being under margin");
```

The test also asserts real balances move (each pot fully drained from the contract into `attackerRecipient`, attacker's payment balance fully spent), ruling out a vacuous mock.

### Relationship to existing ledger finding 858e9e80 (disclosure)

This finding **shares its root cause and its single fix** with existing ledger finding **`858e9e80`** (H-01, the **per-token** nudge snipe), which is dispositioned **wont-fix** (Medium-at-HEAD). M-01 is **not wholly novel**, and `858e9e80` is **not** being represented as unfixed or in need of reopening — its disposition stands. The reason M-01 is filed as a distinct entry:

- `858e9e80` covers the case where the owner **over-funds a single pot** beyond the qualifying cost (the owner broke the stated per-token rule) and a bot re-drains that one pot. Its documented re-arm / watch triggers (WATCH-19) reason **per token** and **do not monitor the cross-token aggregate path**.
- M-01's distinct contribution is exactly that **cross-token aggregate arming path**: **every** pot individually **honours** the stated per-token rule, and the snipe is still net-positive purely from summation across the whitelist. This case is invisible to a per-token watch and is not covered by `858e9e80`'s framing.

Because the two share a root cause, a single value-aware remediation (below) closes both; this entry exists so the aggregate arming path is not lost under the per-token wont-fix.

## Recommended mitigation steps

Make the payout **value-aware** rather than relying on per-token reasoning. Either of the following closes the aggregate path (and, being at the shared root cause, also subsumes `858e9e80`):

1. **Cap the total reward payout at the qualifying cost.** Compute the batch's actual qualifying spend (`nudgeSize × mintPrice`, or the realised mint cost) and bound the aggregate reward transferred across all whitelisted tokens to at most that value (paying out pro-rata across tokens, or in whitelist order until the cap is reached). This guarantees every claim is net-neutral-or-positive for the protocol regardless of `N`.

2. **Add a cross-token aggregate re-arm / eligibility check.** Before paying out, evaluate `Σ_i value(pot_i)` against the qualifying cost (using the same valuation basis the owner reasons about) and refuse to sweep — or scale the payout down — when the aggregate would exceed the cost. This turns the documented per-token safety bound into an enforced aggregate invariant.

Whichever is chosen, the fix must reason over the **sum of all whitelisted pots**, not each pot in isolation, so that a per-token-diligent owner configuration can no longer be snipe-profitable in aggregate. If the design intent is genuinely to allow winner-take-all sweeps, the NatSpec safety bound at `#L57-L69` should at minimum be corrected to state the aggregate condition (`Σ pots < qualifying cost`) so owners do not seed multi-token whitelists under a false per-token safety assumption.
