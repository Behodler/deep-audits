<!--
title: Nudge incentive subsidizes uneconomic minting — inflates ERC1155 supply and degrades NFTStaker runway via the latestPrice ladder
root_cause_link: https://github.com/Behodler/phoenix-nft-staking/blob/24b3f58/src/BatchNFTMinter.sol#L137-L155
severity: Medium
poc_file: workspace/phoenix-nft-staking/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

`BatchNFTMinter.batchMint` pays a fixed-size nudge incentive to whoever covers the dispatcher's payment cost for a batch. Because the nudge payout is sized in absolute units of a separately-funded incentive token and decoupled from the batch's economic value, an attacker can mint NFTs purely to capture the nudge. Each such uneconomic mint advances `NFTMinterV2`'s per-mint price ladder, and `NFTStaker._recomputeSchedule` reads that same `configs.price` when sizing its per-second emission rate. The net effect is a cross-contract value leak: the attacker pays a small payment-token outlay, walks away with a much larger nudge balance, and as a side effect compresses the runway of the protocol's reward budget against honest stakers.

### Vulnerability details

The vulnerability spans three contracts and one shared state slot (`NFTMinterV2.configs[index].price`):

1. **`BatchNFTMinter.batchMint`** ([`BatchNFTMinter.sol#L137-L155`](https://github.com/Behodler/phoenix-nft-staking/blob/24b3f58/src/BatchNFTMinter.sol#L137-L155)) loops `count` times calling `INFTSupply(nftMinter).mint(...)`. After the loop, if a nudge is configured, it transfers the entire nudge balance to `recipient`. The nudge payout is not derived from `count * mintPrice`; it is a flat amount funded out-of-band by the protocol. There is no check that the batch's payment-token cost is commensurate with the nudge value.

2. **`NFTMinterV2._executeMint`** is documented (in `INFTSupply.sol`) as ratcheting `configs[index].price` upward by `growthBasisPoints` per mint: `price <- price + price * growthBasisPoints / 10_000`. So a single `batchMint(count = N)` advances the ladder by factor `(1 + g/10_000)^N`.

3. **`NFTStaker._recomputeSchedule`** reads `nftMinter.configs(dispatcherIndex)` and uses `latestPrice = price / r` (with `r = 1 + g/10_000`) as the per-NFT notional in `R = totalStaked * latestPrice * targetAPY / SECONDS_PER_YEAR`. With `rewardBudget` fixed, the runway `V / R` is inversely proportional to `latestPrice`. Every uneconomic mint thus directly accelerates emission.

The attacker's ROI is independent of NFT utility. Provided the protocol has funded the nudge balance to any amount that exceeds the cumulative dispatcher cost of `nudgeSize` mints, calling `batchMint(count = nudgeSize)` is profitable on the nudge alone. The minted NFTs are pure side-effect; the attacker can hold, dump, or stake them for the inflated emissions they themselves caused.

#### Algebraic equivalence of the PoC's price-update formula

The PoC's `MockUnifiedMinter` advances price using `price * (10_000 + g) / 10_000`. `NFTMinterV2._executeMint` is documented as `price + price * g / 10_000`. These two expressions are algebraically identical:

```
price * (10_000 + g) / 10_000
  = (price * 10_000 + price * g) / 10_000
  = price + price * g / 10_000
```

Modulo a single integer-division floor at the end, both forms round identically when `price * g` is divisible by `10_000` (and differ by at most one wei otherwise). The PoC's price ladder therefore faithfully reproduces the production geometric.

### Impact

The PoC produces three concrete data points against a 100-NFT staked subset, 30 percent target APY, 100 ether starting `latestPrice`, 50 bps `growthBasisPoints`, and a 3,000 ether seed budget:

- **Single 5-mint nudge round:** `latestPrice` rises by ~2.53 percent (the geometric `(1.005)^5 - 1`), `rewardRate` rises by ~252 bps, runway shortens by ~780,595 seconds (~9 days) against a ~366-day baseline. The attacker spends ~505 PAY tokens on the dispatcher ladder and collects 50,000 nudge tokens — roughly 99x leverage in nominal units.
- **Two consecutive 5-mint rounds (10 mints total):** `latestPrice` rises ~5.11 percent, `rewardRate` rises ~5.11 percent, runway shortens by ~18 days versus baseline.
- **Repeated rounds compound geometrically:** after `k` rounds at `g = 50 bps`, the per-mint price is `(1.005)^(5k)` of starting price; runway is `1 / (1.005)^(5k)` of baseline. Ten rounds (50 mints) drives runway to ~78 percent of original; thirty rounds drive it below half.

Direct staker principal is not stolen and accrued rewards remain solvent (the staker's `V = balance + mintDebt` invariant is unchanged), so this does not meet C4's High threshold. It meets C4's Medium threshold: the protocol's emission schedule no longer reflects organic demand, and the reward budget — which honest stakers depend on for the runway over which their stake earns — is consumed at an attacker-controlled multiple of its designed rate. Value flows from honest stakers (who experience smaller emissions per second of remaining runway) to the nudge attacker.

#### External requirements (per C4 Medium criteria)

- The owner has configured `nudgeSize` and `nudgePaymentToken` (i.e., the standard nudge feature is live).
- The nudge balance is funded such that, for at least one batch size and price-token pair, `nudgeBalance > paymentTokenCost(nudgeSize)` in any common unit of account.
- `growthBasisPoints > 0` on the dispatcher (the production wiring per design notes).
- `NFTStaker.totalStaked > 0` and `targetAPY > 0` (otherwise `R = 0` and the rate inflation has no immediate runway impact).

#### Caveat: PoC omits dispatcher-side mint-debt feedback

The PoC does not model `ATokenDispatcherV2.dispatch(...)`'s effect of routing a fraction of the payment-token receipts back into `NFTStaker` as `mintDebt`, which raises `V` and partially offsets the runway compression. In production this self-funding term reduces — but does not cancel — the headline numbers above. The validator confirmed the PoC numbers are therefore conservative: production runway compression is at most the figures shown. Including the mint-debt feedback would require fully modelling `BalancerPoolerMintDebtHook` and is out of scope for a unit-level PoC; the directional and proportionality conclusions hold under the partial self-fund.

### Proof of Concept

A standalone Foundry test is provided at `workspace/phoenix-nft-staking/test/poc-M-01.t.sol`. Run with:

```
cd workspace/phoenix-nft-staking && forge test --match-path test/poc-M-01.t.sol -vv
```

The test:

1. Deploys a unified mock that implements both `ITokenMinterV2` (the surface `BatchNFTMinter` calls) and `INFTSupply` (the surface `NFTStaker` reads), so the same `configs[index].price` slot that gets ratcheted by `mint(...)` is the one read by `_recomputeSchedule`. This is the smallest faithful reproduction of the production wiring.
2. Sets up a 100-NFT organic stake, 30 percent APY, 3,000 ether seed budget, 100 ether starting price, 50 bps growth, `nudgeSize = 5`, and a 50,000-token nudge balance.
3. Snapshots `latestPrice`, `rewardRate`, `rewardBudget`, and `runwaySeconds()`.
4. Has the attacker pay the cumulative ladder cost of 5 mints (~505 PAY) and call `batchMint(... NUDGE_SIZE, attacker, cost)`. Asserts the attacker received the entire 50,000-token nudge balance and that the nudge payout exceeds payment outlay.
5. Calls `pullAndRefresh()` to push the new `configs.price` into `rewardRate`. Asserts `latestPrice`, `rewardRate` increased; `runway` shrunk.
6. Pins the rate increase at `>= 200 bps` (the geometric `(1.005)^5 - 1 ~= 252 bps` minus a floor-rounding margin).
7. Runs a second 5-mint round, asserts the ladder keeps climbing and the runway keeps shrinking, demonstrating geometric compounding across rounds.

The unified mock's price-update formula `price * (10_000 + g) / 10_000` is algebraically identical to `NFTMinterV2`'s documented `price + price * g / 10_000` (see equivalence proof under "Vulnerability details"), so the ladder dynamics in the PoC match the production semantics exactly.

## Recommended mitigation steps

The cross-contract impact dictates that the nudge incentive must not be triggerable in a way that subsidizes uneconomic mints. Options, in increasing order of structural change:

1. **Cap `count` per `batchMint` call.** Limiting `count` bounds the per-call ladder advance to `(1 + g/10_000)^count_max`, which caps the per-call runway compression any one nudge round can inflict. Combined with rate-limiting nudge eligibility (e.g., one nudge per refill window), this turns geometric compounding into a small, bounded one-shot impact per refill.

2. **Decouple `latestPrice` from `_recomputeSchedule`.** Replace the instantaneous post-mint `configs.price` read with a TWAP, a manually-set oracle, or an EMA over a multi-block window. This severs the attack's price-channel into the staker entirely: even if the ladder is ratcheted, the staker's notional `S` no longer follows it within the same transaction, and an attacker must sustain the inflated price across the smoothing window to achieve the same effect. This is the cleanest fix and is consistent with the M-03 design intent of insulating staker emissions from short-term notional shocks.

3. **Tie nudge to economic-substance proxies.** Require the batch's payment-token spend to clear a floor scaled by `count` and current `latestPrice` (e.g., `paymentAmount >= count * latestPrice * NUDGE_FLOOR_BPS / 10_000`). If the floor is set near 100 percent of fair-value, an attacker captures only the residual nudge minus the cost — which can be sized to be negligible.

4. **Time-decayed / vested nudge accounting.** Stream the nudge over a window during which the price-ladder gain must exceed marginal cost. This forces the attacker to bear NFT-holding risk and limits the per-block extractable arbitrage.

5. **Couple to the staker.** Allow the nudge claim only when the recipient demonstrates a current staked balance in `NFTStaker` covering the batch (e.g., `NFTStaker.users[recipient].amount >= count` post-batch). Aligns the incentive with the protocol's stated goal of growing staked supply rather than minted supply.

6. **Combine with H-01's mitigation.** H-01 recommends proportional nudge payout and `recipient = msg.sender`. Together with any of (1)–(3) above, this makes the per-cycle profit small enough that the per-cycle `latestPrice` inflation stays inside a tolerable band even under adversarial repetition.

The recommended minimum fix is (1) plus (3): a per-call `count` cap and a payment-amount floor are both small, surgical changes that close the arbitrage window without restructuring the staker's emission math. (2) is the principled long-term fix and should be considered if the staker is expected to remain coupled to `NFTMinterV2` over multiple price epochs.
