<!--
C4 Submission Metadata
Title: [M-03] rewardRate sized against aggregate minted-NFT notional has no upper ceiling, letting a lone staker capture the full T-derived stream at N x targetAPY and breaking runway predictability
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L340-L379
PoC File: workspace/nft-staking/test/poc-M-03.t.sol
-->

## Finding description and impact

### Summary

`NFTStaker._recomputeSchedule` sizes the per-second emission rate `R` against the aggregate notional value `T` of **all minted NFTs** in the configured dispatcher, but `_updatePool` divides that same rate across `totalStaked` only. The spec frames this as an APY-as-floor guarantee for the median NFT holder at full participation — which is honored — but leaves the corresponding **ceiling** unbounded. When participation is low, effective APY per staked NFT scales as `targetAPY * (N / totalStaked)` and the reward budget depletes at the same `N / totalStaked` multiple of the advertised rate. The runway-grows-with-V property of the variable-runway design silently breaks in this regime.

### Vulnerability details

The relevant sites in `src/NFTStaker.sol` (commit `66af47d`):

`_recomputeSchedule` sets the emission rate from aggregate minted supply ([L340-L379](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L340-L379)):

```solidity
// T is the closed-form aggregate across ALL minted NFTs (N = totalSupply, not totalStaked).
uint256 F = T.mulDiv(targetAPY, APY_PRECISION);
uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;
uint256 runway  = (newRate == 0) ? 0 : V / newRate;

rewardRate = newRate;
rewardBudget = V;
windowEnd = block.timestamp + runway;
```

`_updatePool` then distributes that aggregate-sized rate across only the currently-staked population ([L291-L306](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L291-L306)):

```solidity
uint256 reward = elapsed * rewardRate;
if (reward > rewardBudget) reward = rewardBudget;
if (reward > 0) {
    rewardBudget -= reward;
    accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;
}
```

With `growthBasisPoints == 0` (so `T = price * N`) the per-NFT effective APY over a holding period `dt` is:

```
effAPY = (rewardRate * dt / totalStaked) * SECONDS_PER_YEAR / (price * dt)
       = (T * targetAPY / 1e18) / (price * totalStaked)
       = targetAPY * N / totalStaked
```

That is a pure function of `N / totalStaked` with no upper cap. The geometric-growth branch has the same structural property — `T` is still sized against `N`, not against the staked subset.

The spec's "APY-as-floor for median NFT" invariant is respected: when every NFT is staked, every holder earns at least the target APY. What is unstated is the symmetric upper side. The contract's economic guarantee is effectively:

> APY is a **floor** at full participation and an **unbounded multiple** of the target at low participation.

That is a legitimate design choice if it is explicit and budgeted for. It is not currently explicit, and the variable-runway design's "runway grows with V, shrinks with emissions" narrative breaks in the low-participation regime: the runway actually shrinks `N / totalStaked` times faster than `V / R` alone suggests, because `R` was sized assuming all N NFTs would draw against it.

### Attack path / scenario

No adversarial actor is required; the issue manifests under realistic operating conditions. The sharpest manifestations:

1. **Launch and low-TVL windows.** Early stakers naturally face `totalStaked << N`. The first staker to deposit a single NFT, before other holders stake, captures the entire `T`-sized stream on one unit of notional. An opportunistic but legitimate actor who watches mints and stakes first captures `N`-times the intended per-NFT APY for as long as they remain the only staker.
2. **Passive-holder populations.** If a meaningful share of minted NFTs sits in long-term wallets, airdrop claimers, or lost keys, `totalStaked` structurally stays well below `N`. Every active staker permanently earns a multiple of the advertised target, and the budget depletes at the same multiple.
3. **Operator mis-forecast of runway.** The operator chooses `targetAPY` and funds `V` expecting runway `V / R`. In practice runway is `V / (R_effective)` where `R_effective` can be up to `N / totalStaked` larger than `R`. The operator either over-funds the contract (capital inefficiency) or under-funds it (premature depletion, emissions end before the intended window), depending on which participation assumption turns out correct.

### Impact

This is a **value-leak with stated assumptions** rather than theft. All emissions are consistent with the contract's own math; no staker receives more than the per-share accounting credits them for. The protocol-level consequences are:

- **Runway predictability is broken.** The operator cannot forecast `V / R` as a user-visible runway, because the effective burn rate scales with `N / totalStaked`. This contradicts the variable-runway design's advertised "runway is a derived quantity from V and R" property.
- **Reward budget depletes up to N-times faster than the advertised APY implies.** The PoC demonstrates a 100-times over-emission factor at realistic parameters (`N = 100`, `MAX_TARGET_APY = 50%`).
- **Early/opportunistic stakers capture a disproportionate share of emissions** at the expense of late stakers and holders who stake only after participation rises. Late entrants face a contract that has already paid out a large fraction of the budget at 50–100× the target APY.
- **No upper bound exists on individual APY.** A staker holding a single NFT while `totalStaked == 1` earns `targetAPY * N`, which for `N` in the hundreds pushes advertised-50% rewards into the thousands-of-percent range (see PoC).

### Proof of Concept

The standalone test file lives at `workspace/nft-staking/test/poc-M-03.t.sol` and imports the real `NFTStaker` contract unmodified. Three tests run to green:

| Test | Scenario | Result |
|------|----------|--------|
| `test_M03_LoneStakerEarnsNxTargetAPY` | 1 of 100 minted NFTs staked | Effective APY = **500,000 bps ≈ 4999.99%** (N × target) |
| `test_M03_FullParticipationEarnsTargetAPY` | 100 of 100 minted NFTs staked | Effective APY = **5,000 bps ≈ 50%** (matches target) |
| `test_M03_LoneVsFullRatioEqualsN` | Side-by-side | Claim ratio = **100** (exactly `N`) |

Parameters chosen for exact arithmetic:

- `N = 100` minted NFTs, `price = 100 ether`, `growthBasisPoints = 0` → `T = 10_000 ether`.
- `targetAPY = 50%` (= `MAX_TARGET_APY`), holding period `dt = 1 day`.
- Seed budget `10_000 ether` (depletion is not the story — rate is).

The ratio test asserts `soloClaim / perUserClaim == N` to within a two-wei floor-division tolerance, and the APY-ratio framing `soloAPYbps ≈ N × fullAPYbps` within 0.2% relative tolerance. The rate assertion `staker.rewardRate() == T * targetAPY / SECONDS_PER_YEAR` confirms the aggregate-sized rate is exactly what the contract sets.

Run with:

```
forge test --match-contract PoCM03_LoneStakerCapturesAggregateAPY -vv
```

## Recommended mitigation steps

### Chosen mitigation — Size rate by `totalStaked * currentMintPrice`

Replace the `T`-based (aggregate-notional across all minted NFTs) sizing in `_recomputeSchedule` with a count-based sizing anchored to the **current mint price** (the highest geometric-growth price, i.e. the price the most recent minter paid). Conceptually: treat staked NFTs as homogeneous units for reward distribution — which `_updatePool` already does — and size the rate so that the latest/most-expensive minter earns exactly `targetAPY`. Every earlier minter paid less, so their effective APY is `≥ targetAPY`, preserving the spec's "APY floor" framing.

**Implementation sketch** (replace the `T` computation block in `_recomputeSchedule` at `src/NFTStaker.sol:340-379`):

```solidity
// Replace: T = closed-form aggregate notional across N minted NFTs
// With:   F = totalStaked * currentMintPrice * targetAPY
//
// currentMintPrice is the geometric-growth price of the most recent mint:
//   currentMintPrice = basePrice * (1 + growthBasisPoints/1e4)^(N-1)
// which the dispatcher already exposes (or can be read from the price snapshot
// maintained for the next mint — whichever the dispatcher interface provides).

uint256 F = totalStaked == 0
    ? 0
    : (totalStaked * currentMintPrice).mulDiv(targetAPY, APY_PRECISION);
uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;
uint256 runway  = (newRate == 0) ? 0 : V / newRate;

rewardRate = newRate;
rewardBudget = V;
windowEnd = block.timestamp + runway;
```

**Why this shape:**

- **Closes M-03.** Rate scales with `totalStaked`, not `N`, so there is no low-participation multiplier. Runway is deterministic: actual burn rate equals `R`, so runway is exactly `V / R` as the variable-runway design advertises.
- **Preserves the APY floor guarantee.** The latest minter (who paid `currentMintPrice`) earns exactly `targetAPY`. Earlier minters paid `currentMintPrice / (1+g)^k` for some `k > 0` and earn `targetAPY * (1+g)^k > targetAPY`. Advertise `targetAPY` as the minimum; UI may show a range or disclose that earlier minters earn more.
- **Internally consistent with the existing distribution math.** `_updatePool` already divides rewards by `totalStaked` (count), treating NFTs as homogeneous. Sizing the rate by count keeps both sides of the emission engine on the same basis and removes the notional-vs-count asymmetry that produced this finding.
- **No `stakedNotional` bookkeeping required.** No per-stake / per-unstake SSTORE, no snapshotting of mint price per token ID. The only inputs are `totalStaked` (already tracked) and `currentMintPrice` (already derivable from the dispatcher's mint state).

**Trigger sites for `_recomputeSchedule`:**

- **On mint:** `currentMintPrice` increases (geometric growth) and `N` increases, but `totalStaked` is unchanged. Rate rises in lockstep with `currentMintPrice`, which is the correct behaviour — the new floor price applies to the whole staked pool going forward.
- **On stake / unstake:** `totalStaked` changes, `currentMintPrice` is unchanged. Rate tracks participation.
- **On `setTargetAPY` / `fund`:** unchanged from current behaviour.

**Spec / UI update required:**

- Document that advertised `targetAPY` is a **floor** earned by the most recent minter. Earlier minters earn a multiple of the floor equal to `currentMintPrice / theirMintPrice`.
- Consider a view helper `effectiveAPY(uint256 tokenId)` returning the token's floor-multiple so the UI can render "your APY: X% (floor: targetAPY%)" or a range across the user's staked set.
- If `growthBasisPoints == 0` the multiple is always `1`, so the advertised number is exact — the range framing only applies when geometric growth is enabled.

### Discarded alternatives

The following were considered and rejected. Documented here for auditor traceability; do not implement.

- **Rate based on `stakedNotional` (sum of per-token stake-time prices).** Closes M-03 but requires tracking `stakedNotional` on every stake/unstake, snapshotting `price` per tokenId at stake time, and changes the distribution-vs-sizing basis from homogeneous to notional-weighted — inconsistent with `_updatePool`'s count-based distribution. Chosen mitigation is strictly simpler.
- **Clamp `T` to `stakedNotional`.** Equivalent to the above under normal parameters; same bookkeeping cost, same inconsistency with count-based distribution.
- **Keep current math, document the ceiling, budget for expected participation.** No code change, but retains the low-participation multiplier and forces operators to guess participation when funding `V`. Contradicts the variable-runway design's own "runway is derived from V and R" framing.
