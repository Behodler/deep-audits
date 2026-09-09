<!--
ID: pe4m1
C4 Submission Metadata
Title: [M-01] "Linear Depletion" reward distribution is actually exponential decay: rewardPerSecond re-anchored on every interaction strands ~37% of each tranche
Severity: Medium
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L389-L426
PoC File: workspace/phlimbo-ea/test/poc-2004-M-01-linear-depletion-decay.t.sol
-->

## Finding description and impact

### Summary

`PhlimboEA`'s headline, advertised mechanism is **Linear Depletion**: a funded reward tranche of size `R` should pay out at a constant `R/D` per second so that it is fully delivered after one `depletionDuration` (`D`). In practice the payout curve is **exponential decay**, not linear, because `rewardPerSecond` is re-anchored to the *residual* `rewardBalance` on **every** distributing interaction. Over one nominal depletion window with no new funding, stakers receive only `1 - (1 - 1/N)^N` of the funded tranche, which falls from ~100% at a single update to the `1 - 1/e ≈ 63.2%` asymptote as the pool is poked more often. The remaining ~37% is pushed into an indefinitely-receding tail and, once the per-update reward rounds below 1 wei/share, a residual is permanently stranded in `rewardBalance` — recoverable only by the owner via `emergencyTransfer`.

### Severity: Medium

No principal is at risk, no theft occurs, and the stranded remainder is owner-recoverable, so this is not a High. However the defect systemically under-delivers the protocol's core advertised feature to **every staker under entirely normal usage** (no attacker required), leaking in-motion reward yield. Per the loss-of-yield rule (in-motion, owner-recoverable yield) this is capped at, and held at, **Medium**. It is borderline Medium-vs-Low; it is held at Medium because the magnitude of under-delivery is large and systemic (~37% of every tranche) rather than incidental.

### Root cause

`_updatePool` distributes the accrued reward, debits `rewardBalance`, and then **recomputes `rewardPerSecond` from the reduced balance** on every call:

- [`src/Phlimbo.sol#L413`](lib/phlimbo-ea/src/Phlimbo.sol#L413) — `rewardBalance -= toDistribute;`
- [`src/Phlimbo.sol#L416`](lib/phlimbo-ea/src/Phlimbo.sol#L416) — `rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;`  ← the re-anchor

```solidity
// src/Phlimbo.sol  _updatePool()  (L389-L426)
uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;        // L403
uint256 toDistribute = potentialReward > rewardBalance ? rewardBalance : potentialReward; // L406
if (toDistribute > 0) {
    accStablePerShare += (toDistribute * PRECISION) / totalStaked;            // L410
    rewardBalance -= toDistribute;                                            // L413
    rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;        // L416  ← re-anchor
}
```

The same recompute is performed at the two funding-class entry points, which is where it *belongs*:

- [`src/Phlimbo.sol#L283`](lib/phlimbo-ea/src/Phlimbo.sol#L283) — `collectReward`, after `rewardBalance += amount`.
- [`src/Phlimbo.sol#L188`](lib/phlimbo-ea/src/Phlimbo.sol#L188) — `setDepletionDuration`, after the duration changes.

`_updatePool` is invoked by every `stake`, `withdraw`, `claim`, `collectReward`, and `setDepletionDuration`. Because line L416 fires on **distribution** (not just on funding), each interaction restarts the entire `D`-length depletion window against a balance that has just been reduced. Re-anchoring `rate = balance / D` after each debit is the discrete form of the ODE `B'(t) = -B(t)/D`, whose solution is `B(t) = B0 · e^(−t/D)` — exponential decay — rather than the intended linear `B(t) = B0 · (1 − t/D)`.

### Vulnerability details

Split one full window `D` into `N` evenly-spaced pokes of `dt = D/N`. Each poke distributes a fraction `dt/D = 1/N` of the *current* balance and then re-anchors, so after `N` pokes the residual balance is `R·(1 − 1/N)^N`. The amount **delivered** within one nominal window is therefore:

```
delivered(N) = R · (1 − (1 − 1/N)^N)
```

which is strictly decreasing in `N`:

| pokes `N` | delivered | stranded |
|-----------|-----------|----------|
| 1         | 100.0%    | 0%       |
| 2         | 75.0%     | 25%      |
| 100       | 63.4%     | 36.6%    |
| → ∞       | `1 − 1/e ≈ 63.2%` | `≈ 36.8%` |

The "linear" path (`N = 1`, a single update over the whole window) is the *only* case that delivers the full tranche; any realistic pool that is touched more than once per window under-delivers, converging to delivering only ~63% of every funded tranche. The undelivered remainder is not lost arithmetic — it persists in `rewardBalance` and feeds the next window's re-anchored rate, producing an ever-receding tail. Once `rewardPerSecond * timeElapsed / PRECISION` rounds below 1 wei per share, `toDistribute` is zero and the residual stalls permanently until topped up or swept by the owner.

### Impact

Every staker is passively under-paid: each reward tranche delivers only ~63% (worst case) of its funded value within the intended `depletionDuration`, with ~37% delayed into a receding tail and a dust residual permanently stranded in `rewardBalance`. There is no theft and no principal at risk; the stranded remainder is recoverable only by the owner via `emergencyTransfer` ([`src/Phlimbo.sol#L214`](lib/phlimbo-ea/src/Phlimbo.sol#L214)). The concrete consequence is a material, systemic value-leak of in-motion yield and a direct contradiction of the protocol's headline "Linear Depletion" guarantee.

### Related: permissionless on-demand amplification (folded in from ex-M-03 / now L-07)

The decay above is normally emergent from organic activity, but it is also **reachable on demand by an unprivileged actor**. Because the same re-anchor at [`src/Phlimbo.sol#L416`](lib/phlimbo-ea/src/Phlimbo.sol#L416) fires on every pool touch, anyone can force it for free: `collectReward(1 wei)` is permissionless, and a `claim()` call from a **non-staker** still runs `_updatePool` (the `_claimRewards` early-return on `amount == 0` happens only after the re-anchor). By poking every block an attacker drives `N` arbitrarily high, pushing delivery to the same worst-case `delivered(N) = 1 − (1 − 1/N)^N` curve (the identical ~63.4% figure) at gas-only cost and zero attacker payoff, and — once the per-update distribution rounds below ~`depletionDuration/12` reward-wei — **permanently stalls the dust tail** (the residual is consumed in time via `lastRewardTime` but never in value). This access-control / tail-stall angle was previously tracked as M-03 and has been folded in here; it is reported at Low severity as **L-07** (see `submissions/L-07-permissionless-collectReward-griefing.md`, which retains the full PoC). The durable fix is the same one recommended below — removing the distribution-time re-anchor — which makes the pokes idempotent and the griefing pointless.

### Faithfulness framing (Law-2 deviation with economic impact)

This is reported honestly as a story-faithfulness deviation, not a hypothetical:

- The stated design intent is "Linear Depletion" (registry `designDecisions[0]`: *"Linear depletion model for reward distribution (rewardBalance / depletionDuration)"*; contract NatSpec at [`src/Phlimbo.sol#L386`](lib/phlimbo-ea/src/Phlimbo.sol#L386) — *"Updates pool accumulators based on linear depletion reward rate"*). The actual curve is exponential, so the implementation does not do what the story says.
- The registry `designDecisions[1]` (*"Rate recalculates after each balance change (collection or distribution)"*) **describes the mechanism** but does not bless the emergent ~37% under-delivery. Crucially this item is **not** in the project's formal `knownIssues[]` list (KI-1..KI-10), so it is not an accepted/out-of-scope known issue.
- `lib/phlimbo-ea/CLAUDE.md` explicitly calls this *"the V1 rate-recompute bug"* and notes upstream `PhlimboV2` *"removes the depletion-rate recompute from `_updatePool` so the window does not reset on user interactions."* The existence of a deliberate V2 fix confirms the behaviour is regarded internally as a defect, not intended behaviour.

This cross-references the adjacent spec-conformance observation (F-01-adjacent): the contract's "linear" naming and documentation are inconsistent with its realized payout curve. V1 is frozen/deployed, so beyond the fix below, the actionable operational guidance is (a) awareness that delivered yield per window is ~63%, not 100%, and (b) periodic owner sweep / re-funding to recover the stranded tail.

### Proof of Concept

A standalone, passing Foundry test reproduces the exact curve. It runs three independent fundings of an identical tranche `R = 100e18` over one full `depletionDuration` with **no new funding**, differing only in how many times the pool is poked. Pokes use a non-staker `claim()` so only `_updatePool` runs and no tokens move, isolating the re-anchor effect from any transfer rounding.

Run command:

```bash
forge test --match-path test/poc-2004-M-01-linear-depletion-decay.t.sol -vv
```

Observed output (key numbers):

```
[PASS] test_M01_linearDepletionIsExponentialDecay()
  R (funded tranche)            : 100000000000000000000
  Delivered N=1   (wei)         : 99999999999999999999   (9999 bps ≈ 100.0%)
  Delivered N=2   (wei)         : 74999999999999999999   (7499 bps ≈  75.0%)
  Delivered N=100 (wei)         : 63396765872677049477   (6339 bps ≈  63.4%)
```

The result is monotonic — `delivered(1) > delivered(2) > delivered(100)` — and converges to the `1 − 1/e` asymptote, exactly matching `delivered(N) = R·(1 − (1 − 1/N)^N)`. At `N = 100`, ~36.6% of `R` is stranded in the receding tail. This was independently corroborated by forge, Medusa, and Halmos (Tier-3: CONFIRMED).

Full test:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Phlimbo.sol";
import "./Mocks.sol";

/// @dev "Linear Depletion" is actually EXPONENTIAL DECAY: rewardPerSecond is
///      re-anchored to the residual balance on every poke (src/Phlimbo.sol#L416),
///      so each interaction restarts the full depletion window against a shrinking
///      balance. delivered(N) = R*(1 - (1 - 1/N)^N), decreasing in N toward 1 - 1/e.
contract PoC2004_M01 is Test {
    MockFlax public phUSD;
    MockStable public rewardToken;

    address public staker = address(0xA11CE);
    address public funder = address(0xF00D);
    address public poker  = address(0x0B0B); // NON-staker, only pokes _updatePool

    uint256 constant DEPLETION_DURATION = 3600;      // 1 hour window (scale-invariant in dt/D)
    uint256 constant STAKE_AMOUNT       = 100 ether;
    uint256 constant REWARD_AMOUNT      = 100 ether; // R: the funded tranche

    function _freshFunded() internal returns (PhlimboEA phlimbo) {
        phUSD = new MockFlax();
        rewardToken = new MockStable();
        phlimbo = new PhlimboEA(address(phUSD), address(rewardToken), DEPLETION_DURATION);
        phUSD.setMinter(address(phlimbo), true);

        phUSD.mint(staker, STAKE_AMOUNT);
        rewardToken.mint(funder, REWARD_AMOUNT);

        vm.prank(staker);
        phUSD.approve(address(phlimbo), type(uint256).max);
        vm.prank(funder);
        rewardToken.approve(address(phlimbo), type(uint256).max);

        // Single staker so totalStaked != 0 and _updatePool always proceeds.
        vm.prank(staker);
        phlimbo.stake(STAKE_AMOUNT, staker);

        // Fund one tranche R; anchors rewardPerSecond = R*PRECISION/D.
        vm.prank(funder);
        phlimbo.collectReward(REWARD_AMOUNT);
    }

    /// Run one full depletion window split into `n` evenly-spaced pokes.
    function _deliveredOverWindow(uint256 n) internal returns (uint256 delivered) {
        PhlimboEA phlimbo = _freshFunded();
        uint256 dt = DEPLETION_DURATION / n;

        for (uint256 i = 0; i < n; ++i) {
            vm.warp(block.timestamp + dt);
            // Pure poke: NON-staker claim() runs _updatePool (re-anchor) and returns
            // early in _claimRewards (amount==0). No tokens move.
            vm.prank(poker);
            phlimbo.claim();
        }

        // Everything accrued out of rewardBalance is "delivered" to the sole staker.
        delivered = REWARD_AMOUNT - phlimbo.rewardBalance();
    }

    function test_M01_linearDepletionIsExponentialDecay() public {
        uint256 d1   = _deliveredOverWindow(1);
        uint256 d2   = _deliveredOverWindow(2);
        uint256 d100 = _deliveredOverWindow(100);

        emit log_named_uint("R (funded tranche)            ", REWARD_AMOUNT);
        emit log_named_uint("Delivered N=1   (wei)         ", d1);
        emit log_named_uint("Delivered N=2   (wei)         ", d2);
        emit log_named_uint("Delivered N=100 (wei)         ", d100);
        emit log_named_uint("Delivered N=1   (bps of R)    ", d1   * 10_000 / REWARD_AMOUNT);
        emit log_named_uint("Delivered N=2   (bps of R)    ", d2   * 10_000 / REWARD_AMOUNT);
        emit log_named_uint("Delivered N=100 (bps of R)    ", d100 * 10_000 / REWARD_AMOUNT);

        // N=1: a single update over the whole window delivers ~100% (intended linear).
        assertApproxEqRel(d1, REWARD_AMOUNT, 0.001e18, "N=1 should deliver ~100% of R (intended linear)");
        // N=2: re-anchoring once mid-window strands 25% -> ~75% delivered.
        assertApproxEqRel(d2, (REWARD_AMOUNT * 75) / 100, 0.01e18, "N=2 should deliver ~75% of R");
        // N=100: many re-anchors drive delivery to the 1-1/e ~= 63.2% asymptote.
        assertGt(d100 * 100, REWARD_AMOUNT * 60, "N=100 delivered must be > 60% of R");
        assertLt(d100 * 100, REWARD_AMOUNT * 67, "N=100 delivered must be < 67% of R");
        // Core claim: over one full window, delivery is materially less than R once poked.
        assertLt(d100, REWARD_AMOUNT, "N=100 delivers strictly less than funded R");
        assertLt(d100 * 100, REWARD_AMOUNT * 66, "N=100: ~37% of R stranded in the receding tail");
        // Path-dependence / monotonic degradation: delivered decreases in N.
        assertGt(d1, d2,   "delivered(1) > delivered(2)");
        assertGt(d2, d100, "delivered(2) > delivered(100)");
        // The stranded tail at N=100 is ~37% of R.
        uint256 stranded100 = REWARD_AMOUNT - d100;
        assertGt(stranded100 * 100, REWARD_AMOUNT * 33, "stranded tail must be > 33% of R");
    }
}
```

## Recommended mitigation steps

Re-anchor `rewardPerSecond` **only on funding events**, never on routine distribution. The rate should be fixed at the time the schedule changes (a `collectReward` top-up or a `setDepletionDuration` change) and then consumed against a fixed schedule until the window closes — exactly what upstream `PhlimboV2`/story-020 does by removing the recompute from `_updatePool`.

Concretely, delete the distribution-time re-anchor at [`src/Phlimbo.sol#L416`](lib/phlimbo-ea/src/Phlimbo.sol#L416):

```solidity
// in _updatePool(), after rewardBalance -= toDistribute;
-   // Recalculate rate after balance decrease
-   rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
```

Keep the funding-time anchors at `collectReward` (L283) and `setDepletionDuration` (L188), and track an explicit window end so `_updatePool` distributes `rate * elapsed` (capped by `rewardBalance`) against a fixed schedule rather than recomputing the rate from the residual balance:

```solidity
// state
uint256 public rewardWindowEnd;            // timestamp the current tranche fully depletes

// collectReward / setDepletionDuration (funding-class only)
rewardPerSecond  = (rewardBalance * PRECISION) / depletionDuration;
rewardWindowEnd  = block.timestamp + depletionDuration;

// _updatePool: clamp elapsed to the window end; do NOT re-anchor the rate
uint256 effectiveNow = block.timestamp < rewardWindowEnd ? block.timestamp : rewardWindowEnd;
if (effectiveNow > lastRewardTime) {
    uint256 timeElapsed     = effectiveNow - lastRewardTime;
    uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;
    uint256 toDistribute    = potentialReward > rewardBalance ? rewardBalance : potentialReward;
    // ... distribute, debit rewardBalance, but no rewardPerSecond recompute here ...
}
```

This delivers the full tranche `R` linearly over `D` regardless of how often the pool is poked, eliminating both the ~37% in-window under-delivery and the stranded receding tail.

Because V1 (`src/Phlimbo.sol`) is frozen and deployed, if a code change is not possible the operational mitigations are: (1) document that realized delivery per window is ~63% rather than 100%, (2) re-fund/top-up frequently so the receding tail is repeatedly re-anchored upward, and (3) periodically sweep the stranded residual via `emergencyTransfer` and redistribute. Migrating stakers to `PhlimboV2` (which removes the recompute) is the durable fix.
