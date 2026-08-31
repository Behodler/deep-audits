<!--
ID: pe6m3
C4 Submission Metadata
Title: [M-03] pauseWithdraw does not resync the phUSD emission rate: stale phUSDPerSecond over-mints phUSD to surviving stakers on unpause (conditional-High)
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L280-L291
PoC File: workspace/phlimbo-ea/test/poc-2006-V2-M-03-pausewithdraw-overmint-on-unpause.t.sol
Ledger: V2-M-03 (inherited from V1 M-05; conditional-High)
Severity: Medium (RE-CLASSIFY HIGH under any non-zero-APY config)
-->

## Finding description and impact

### Summary

`PhlimboV2.pauseWithdraw` ([`src/PhlimboV2.sol#L280-L291`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L280-L291)) decrements `totalStaked` at L286 but, unlike every other path that mutates `totalStaked`, does **not** call `_updatePhUSDEmissionRate`. The phUSD emission rate `phUSDPerSecond` remains sized for the pre-pause `totalStaked` while the actual staked base has shrunk. On unpause, `_updatePool` accrues that stale rate over the smaller base, inflating per-share phUSD accrual and letting surviving stakers mint phUSD by a factor of approximately `S0/S1` (pre-pause stake over post-pause stake) above their fair entitlement.

This carries the V1 finding (ledger M-05) forward into V2 unchanged in shape.

### Vulnerability details

`_updatePhUSDEmissionRate` ([`src/PhlimboV2.sol#L512-L519`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L512-L519)) sizes the emission rate to the current stake base:

```solidity
function _updatePhUSDEmissionRate() internal {
    if (totalStaked == 0) { phUSDPerSecond = 0; return; }
    phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;
}
```

Both normal paths that change `totalStaked` re-run it after the mutation: `withdraw` at **L394** and `stake` at **L349**. `pauseWithdraw` does not:

```solidity
// src/PhlimboV2.sol#L280-L291  (pauseWithdraw)
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    user.amount -= amount;
    totalStaked -= amount;            // L286 — stake base shrinks...
                                      // ...but _updatePhUSDEmissionRate() is NOT called.
    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);
    emit EmergencyWithdrawal(msg.sender, amount);
}
```

After a `pauseWithdraw` shrinks `totalStaked` from `S0` to `S1`, the stale `phUSDPerSecond` (sized for `S0`) is consumed by the next `_updatePool` ([`src/PhlimboV2.sol#L471-L474`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L471-L474)):

```solidity
if (phUSDPerSecond > 0) {
    uint256 phUSDReward = timeElapsed * phUSDPerSecond;        // numerator sized for S0
    accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked; // divided by S1 < S0
}
```

The per-share accrual is therefore inflated by exactly `S0/S1`. `claim` never recomputes the rate (it has no `_updatePhUSDEmissionRate` call), so the over-mint persists across claims until the next rate-recomputing `stake` or `withdraw` resyncs it. Surviving stakers mint `S0/S1 ×` their fair phUSD over that interval.

### Severity nuance — conditional-High

The finding is held at **Medium** strictly because the live configuration is zero-APY (KI-10): with `desiredAPYBps = 0`, `_updatePhUSDEmissionRate` sets `phUSDPerSecond = 0`, the `phUSDPerSecond > 0` guard at L471 short-circuits, and the over-mint cannot fire. The defect is real but currently immunized by parameterization, not by code.

**RE-CLASSIFY HIGH the moment any non-zero-APY config ships.** phUSD is the stake token and is minted as reward; an over-mint is unbacked value creation, so once `desiredAPYBps > 0` the impact is direct value creation in favor of surviving stakers at the protocol's expense. Any governance action setting a non-zero `desiredAPYBps` must re-trigger severity review.

### Three-law framing

This is a non-obvious **footgun** (Law 3), not a malicious-owner vector. `pauseWithdraw` is `msg.sender`-only and is meant to be a neutral emergency exit; a non-malicious operator would not expect that an emergency partial exit leaves the phUSD emission rate stale and over-mints to whoever remains. The surprising downstream consequence makes it in scope.

### Impact

Under any non-zero APY: after one or more `pauseWithdraw` exits shrink the stake base during a pause, surviving stakers over-mint phUSD by `≈ S0/S1` over the interval until the next rate-resyncing `stake`/`withdraw`. Because phUSD is minted unbacked, this is value leakage / inflation borne by the protocol and other phUSD holders. Under the current zero-APY config the effect is dormant.

### Proof of concept

PoC (passing, non-zero-APY harness): `workspace/phlimbo-ea/test/poc-2006-V2-M-03-pausewithdraw-overmint-on-unpause.t.sol`

Run:

```
forge test --match-path test/poc-2006-V2-M-03-pausewithdraw-overmint-on-unpause.t.sol -vvv
```

Scenario: `desiredAPYBps = 1000` (10% APY); A and B each stake `S = 100e18` in the same timestamp so `S0 = 200e18`; pause; A `pauseWithdraw(100e18)` so `S1 = 100e18`; unpause; warp 30 days; B (sole remaining staker) claims. The test proves:

- `S0 = 200e18`, `S1 = 100e18`.
- The emission rate is stale after `pauseWithdraw`: `phUSDPerSecond` stays at `634195839675` (sized for `S0`) instead of the correct `317097919837` (sized for `S1`).
- B mints `1.6438e18` (`1643835616437600000`) of phUSD versus the fair APY cap of `0.8219e18` (`821917808217504000`).
- `overMintFactor = 2.0×`, exactly `S0/S1`, with explicit numeric guards bracketing it to `1.99×–2.01×`.

The validator confirmed that a fixed contract (one that resyncs the rate in `pauseWithdraw`) yields an over-mint factor of `1.0×`, isolating the defect to the missing `_updatePhUSDEmissionRate` call.

## Recommended mitigation steps

Resync the phUSD emission rate whenever `pauseWithdraw` changes `totalStaked`, exactly as `stake` (L349) and `withdraw` (L394) already do. The minimal fix is to call `_updatePhUSDEmissionRate()` at the end of `pauseWithdraw`:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    user.amount -= amount;
    totalStaked -= amount;

    _updatePhUSDEmissionRate();   // <-- resync the rate to the shrunken base

    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);
    emit EmergencyWithdrawal(msg.sender, amount);
}
```

Note that `pauseWithdraw` deliberately does not call `_updatePool` (it is an emergency exit that forfeits rewards by design, per KI-4), so recomputing the rate here without accruing first is acceptable: the stale-rate window opens only at the *next* `_updatePool` on unpause. If exactness across the pause boundary is desired, alternatively recompute the rate on unpause (or accrue via `_updatePool` before resizing). Either approach eliminates the `S0/S1` inflation.
