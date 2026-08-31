<!--
C4 Submission Metadata
Title: [M-01] User-path pulls silently lower `rewardRate`, diluting emissions (regression of v02 M-01)
Severity: Medium
Root Cause Link: lib/phoenix-nft-staking/src/NFTStaker.sol#L206-L220
Secondary Location: lib/phoenix-nft-staking/src/NFTStaker.sol#L281-L290
Default-Interval Location: lib/phoenix-nft-staking/src/NFTStaker.sol#L86
Commit: 960e20d
PoC File: workspace/phoenix-nft-staking/test/poc-M-01.t.sol
PoC Tests: testM01_PostFixCooldownDoesNotStopGrief, testM01_DefaultZeroIntervalAllowsEveryBlockGrief
-->

## Finding description and impact

### TL;DR

`_syncBudget` unconditionally rewrites `rewardRate = rewardBudget / windowDuration` on every dispatcher pull, regardless of whether the inflow justifies a fresh window. When the inflow under-refills the schedule (`I < elapsed * R`), the rate is silently lowered and the tail is extended. Every user-entrypoint interaction during a mint-debt dry spell applies this contraction. The v03 `minPullInterval` cooldown does not help — the per-unit-time rate decay is mathematically independent of the pull cadence.

### Summary

This is a regression of the v02 M-01 root cause. The mutation site (`NFTStaker.sol:206-220`) still drops `rewardRate` on under-refill. The v03 remediation (`minPullInterval`) was predicated on the belief that rate-limiting the pull cadence would control the compression; the time-integrated decay is invariant to cadence, so the cooldown only spaces the compression out without changing its magnitude. Separately, `minPullInterval` defaults to `0` (`NFTStaker.sol:86`), so the pre-fix unrestricted form is active from deployment until the owner calls `setMinPullInterval`.

### The rate decay is cadence-independent

Let `R` denote the pre-pull rate, `W` the window duration, `dt` elapsed since the previous pull, and `I` the inflow observed on this pull. `_updatePool()` runs first and decrements `rewardBudget` by `dt * R`, so the rewrite at `:218` produces:

```
R_new = (rewardBudget - dt*R + I) / W
      = R * (1 - dt/W) + I/W                 (budget ≈ R*W at equilibrium)
```

This is a contraction mapping with fixed point `R* = I/dt` — the natural inflow rate from the dispatcher. Over wall-clock time `T` with pull cadence `dt`, the total decay factor across `T/dt` applications is:

```
(1 - dt/W)^(T/dt)  →  e^(-T/W)  as dt → 0
```

**The per-unit-time decay depends on `W`, not on `dt`.** A 1-hour cooldown, a 1-week cooldown, or a zero cooldown all produce essentially the same rate-compression curve over the same wall-clock span. The cooldown controls how often compression is sampled, not how fast it accumulates.

### Sponsor's stated mitigation, contradicted

The submodule spec (`lib/phoenix-nft-staking/CLAUDE.md`, feature item 5) describes the cooldown as a complete fix:

> "This rate-limit is the M-01 mitigation: the zero-stake EOA grief that pinned the rate by spamming `claim()` each block is neutralised at the mutation site."

The mutation site (`NFTStaker.sol:206-220`) still rewrites `rewardRate` downward on every under-refill. The cooldown only adjusts sampling frequency; the decay integral is cadence-independent (above). The attack is not neutralised at the mutation site — the mutation site was never changed.

### Cost-to-trigger is zero — the bug fires under normal usage

Unlike a typical grief, this requires no attacker. Any honest `stake` / `unstake` / `claim` during a dry spell (no fresh mint debt since the last pull) triggers the same contraction. A zero-stake attacker can force the sampling themselves, but because the decay is cadence-independent they add negligibly over organic traffic.

The security relevance is therefore not "a griefer can attack" but: **the contract's emission rate drifts downward from ordinary user activity during mint-debt dry spells, and this drift compounds over time.** The NFT series has rising mint prices by design, so the intended emission should *track upward* with mint inflow. The bug drags `R` toward the short-term-dry-spell average, suppressing the natural rate growth that the economic design depends on.

### Scenario B — default-zero interval

`minPullInterval` defaults to `0` (`NFTStaker.sol:86`). From deployment until the owner calls `setMinPullInterval`, every user interaction triggers `_syncBudget`. No constructor argument enforces a non-zero default; no setter-call requirement gates user functions. The contract is live and rate-compression-active at `t = 0`.

### Vulnerability details

Mutation site at `NFTStaker.sol:216-218`:

```solidity
rewardBudget += inflow;
windowEnd = block.timestamp + windowDuration;
rewardRate = rewardBudget / windowDuration;
```

There is no guard distinguishing "inflow large enough to justify a fresh window at the current rate" from "inflow too small — preserve the existing schedule." Any caller into `_syncBudget(false)` — `stake`, `unstake`, and notably `claim()` (`:281-290`), callable with zero stake at zero marginal cost — triggers the rewrite.

### Relationship to the accepted v02 M-01 (not a duplicate)

v02 M-01 described the same root cause. Its v03 remediation (`minPullInterval`) does not address the invariant. This submission is distinct:

1. **Cadence-independence of the decay** makes the v03 remediation ineffective at any cooldown value, not only at misconfigured ones. This is a mathematical property the sponsor's mitigation argument did not account for; the finding is not about admin misconfiguration.
2. **Scenario B** — `minPullInterval = 0` default — is a live regression independent of the cadence argument.

A correct fix reinstates monotonic-upward behavior of `rewardRate` on user paths (below). The v03 change did not.

### Impact

- **Who**: Honest stakers lose yield; owner loses control of the emission schedule; the natural rising-`R` economics of the NFT series are suppressed.
- **What**: Per-second reward rate drifts downward during mint-debt dry spells. Stakers receive materially fewer rewards over any fixed holding period than the posted schedule implies. The schedule's tail extends indefinitely at reduced rate.
- **Cost / actor**: None required. The behavior arises from ordinary user interaction; no griefer needed. A zero-stake attacker adds little over organic traffic due to cadence-independence.
- **Likelihood**: Certain. Deterministic under any non-uniform dispatcher inflow pattern.

**"Value delay, not value loss" pre-empted.** Unspent `rewardBudget` is not burned; it sits in the contract longer. That framing ignores the staker-side time dimension: any staker with a finite holding period (every real staker who unstakes, rotates capital, or bears opportunity cost) earns strictly less phUSD under the dragged schedule than under the honest schedule over the same wall-clock window. The PoC's 28.8% shortfall is the integral of the rate reduction against a fixed holding period — money the honest staker never recovers because they are not staked during the extended tail. Residual budget accruing to late entrants does not compensate them.

### PoC results (validated)

File: `workspace/phoenix-nft-staking/test/poc-M-01.t.sol`.

**`testM01_PostFixCooldownDoesNotStopGrief`** (`minPullInterval = 1 hour`):
- 10,000 hourly ticks (~416 simulated days); `rewardRate` 231,481 → 113,227 (2.04× collapse), strictly monotonic-decreasing every tick.
- Honest staker receives 2.399e21 wei phUSD less than intended (28.8% shortfall); `windowEnd` pushed ~416 days beyond schedule.
- The observed collapse ratio (0.489) approximates the theoretical `e^(-T/W) ≈ e^(-416/540) ≈ 0.46` — consistent with the decay being governed by `W` and wall-clock time, not the cooldown.

**`testM01_DefaultZeroIntervalAllowsEveryBlockGrief`** (default `minPullInterval = 0`):
- 1,200 blocks; `windowEnd` reset every block, `rewardRate` strictly decreases every block. Confirms the default-zero state is immediately exploitable.

## Recommended mitigation steps

Make `rewardRate` monotonic-upward on user paths. Replace the mutation block in `_syncBudget` (`NFTStaker.sol:216-218`) with the asymmetric rule:

```solidity
rewardBudget += inflow;

uint256 candidate   = windowDuration > 0 ? rewardBudget / windowDuration : 0;
bool scheduleExpired = block.timestamp >= windowEnd;

if (scheduleExpired || candidate > rewardRate) {
    // Bootstrap, post-expiry restart, or legitimate rate raise — full reset
    rewardRate = candidate;
    windowEnd  = block.timestamp + windowDuration;
} else if (rewardRate > 0) {
    // Under-refill — preserve R, extend windowEnd at current rate
    windowEnd += inflow / rewardRate;
}

emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
```

**Semantics**: the reset branch fires when a fresh-window redistribution would *raise* the rate (the legitimate response to a large burst inflow, e.g. a high-priced mint) or when the schedule has expired (bootstrap / restart). Otherwise the inflow is absorbed as extra budget and `windowEnd` is extended proportionally, preserving the existing `rewardRate`. User paths can never drive `R` downward.

This preserves the natural rising-`R` economics the NFT series is designed around (large mints push `R` up; APY can stay constant or grow even as the staker set expands) while structurally eliminating rate compression (trickle / dry-spell inflows preserve `R` instead of diluting it).

### Edge cases covered by the rule

- `rewardRate == 0` (deploy, pre-first-topup): `candidate > 0 = rewardRate` triggers the reset branch, bootstrapping `R`.
- `block.timestamp >= windowEnd` (natural depletion): `scheduleExpired` forces the reset. Since emission has effectively been zero during expiry, any new `R` is an increase.
- Tiny inflow with `candidate == 0` (`inflow < windowDuration`): extend branch fires; `inflow / rewardRate` is well-defined. May round to 0 under extreme asymmetry; budget still grew, next larger inflow resets.

### Code to remove alongside the fix

Once the asymmetric rule is in place, the v03 throttling infrastructure becomes dead weight. Remove it to keep the contract honest:

1. **Remove `minPullInterval`, `lastPullAt`, `setMinPullInterval`, `MinPullIntervalChanged`, and the `bypassInterval` parameter on `_syncBudget`** (`NFTStaker.sol:82-89`, `105`, `170-173`, `203-213`). Their sole purpose was to throttle rate compression; under the asymmetric rule, compression is structurally impossible. `pullAndRefresh` and user-path `_syncBudget` converge to the same call; the parameter becomes redundant.

2. **Remove the `rewardRate` rewrite from `setWindowDuration`** (`NFTStaker.sol:166-167`). The new `_syncBudget` reset branch will rescale `R` at the next invocation if the new duration makes `candidate > rewardRate`. Reducing `setWindowDuration` to a config-only setter is also consistent with the new invariant — an owner choosing a longer duration should not be able to drop `R` via a parameter setter, which the current immediate-rescale behavior silently allows. Simplified setter:

```solidity
function setWindowDuration(uint256 newDuration) external onlyOwner {
    require(newDuration >= MIN_WINDOW && newDuration <= MAX_WINDOW, "NFTStaker: window out of bounds");
    _updatePool();
    emit WindowDurationChanged(windowDuration, newDuration);
    windowDuration = newDuration;
}
```

3. **Update `CLAUDE.md` feature item 5**. The current text describes `minPullInterval` as the M-01 mitigation, which is both mechanically incorrect (above) and forward-incorrect (it is being removed). Replace with a description of the monotonic-upward invariant on user-path `_syncBudget`.
