<!--
C4 Submission Metadata
Title: [M-02] `rewardBudget < windowDuration` permanently strands funds at `rewardRate = 0`
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L194
Additional Sites: https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L204
               https://github.com/Behodler/phoenix-nft-staking/blob/2e56588fd9cc81f43edf42914638d6a122164b3e/src/NFTStaker.sol#L228
PoC File: workspace/nft-staking/test/poc-CS-02.t.sol
Status: submitted
-->

## Finding description and impact

### Summary

Every code path that (re)computes the emission rate in `NFTStaker` uses unscaled integer floor division:

```solidity
rewardRate = rewardBudget / windowDuration;
```

Whenever `rewardBudget` is strictly smaller than `windowDuration` (in seconds), this expression floors to `0`. Because `_updatePool` computes per-interval accrual as `elapsed * rewardRate`, a zero rate means no phUSD is ever emitted and `rewardBudget` is never decremented. The residual budget is permanently trapped in the contract unless a subsequent `topUp` or `pull()` pushes the budget back above the `windowDuration`-seconds floor — which itself produces a new sub-floor dust residue on its own reset, compounding the loss.

### Vulnerability details

The same floor-division pattern appears at three locations in `src/NFTStaker.sol`:

1. `setWindowDuration` (line 194):
   ```solidity
   rewardRate = newDuration == 0 ? 0 : rewardBudget / newDuration;
   ```
2. `topUp` (line 204):
   ```solidity
   rewardRate = rewardBudget / windowDuration;
   ```
3. `_syncBudget` (line 228), invoked on every stake/unstake/claim and through the permissionless `pullAndRefresh`:
   ```solidity
   rewardRate = rewardBudget / windowDuration;
   ```

With the default `windowDuration = 540 days = 46,656,000 s`, any `rewardBudget` below `46,656,000` wei of phUSD resolves to `rewardRate = 0`. Under `MAX_WINDOW = 10 * 365 days`, the threshold climbs to `~3.15e8` wei. These thresholds are small in absolute terms, but they apply on every window reset, and — critically — `pullAndRefresh()` is permissionless:

```solidity
function pullAndRefresh() external {
    _syncBudget();
}
```

An attacker can therefore call `pullAndRefresh` the moment the dispatcher hook has only a dust-sized `mintDebt` queued. The resulting inflow, combined with any pre-existing sub-floor residue, is below `windowDuration` seconds of emissions and floors the rate to zero. All subsequent elapsed time accrues nothing until a sufficiently large admin top-up clears the floor. Even absent adversarial behaviour, each honest reset truncates sub-second dust that is never distributed and accumulates across cycles.

This directly violates the stated invariant `balance == rewardBudget + totalDebt`: the protocol continues to owe stakers the on-contract phUSD via `rewardBudget`, but `totalDebt` cannot grow because `accRewardPerShare` is frozen.

### Impact

- **Permanent stranding of reward funds.** phUSD held by the staker is owed to stakers per the accounting invariant, yet cannot be emitted because `rewardRate` rounds to zero. Stakers effectively lose these funds; the only recovery paths are owner-initiated top-ups large enough to clear the floor, which themselves leak new dust.
- **Permissionless denial of emissions.** Because `pullAndRefresh` is callable by anyone and every honest user action (stake/unstake/claim) also triggers `_syncBudget`, an attacker can front-run or opportunistically trigger a window reset during periods of low pending mint-debt to force `rewardRate = 0` and freeze emissions until the next large top-up.
- **Silent accounting drift.** `currentRewardRate()` returns `0` and `runwaySeconds()` returns `0` while `rewardBudget > 0`, breaking operator/frontend assumptions about remaining emission runway and the `balance == rewardBudget + totalDebt` invariant.

Given that the exploit leaks value rather than stealing the full pool, and requires specific inflow timing rather than being universally triggerable on any balance, Medium severity is appropriate: protocol function (emissions) is degraded and a value leak accrues to the contract under stated — and realistically reachable — conditions.

### Proof of Concept

A runnable Foundry PoC is provided at:

```
workspace/nft-staking/test/poc-CS-02.t.sol
```

The PoC covers three vectors:

- `test_CS02_PullAndRefreshStrandsDustBudgetAtZeroRate` — permissionless attacker triggers `pullAndRefresh()` with a dust mint-debt pending; asserts `rewardRate == 0`, `accRewardPerShare` does not advance across 365 days of elapsed time, `rewardBudget` is never decremented, and `pendingReward(alice)` stays flat, demonstrating permanent stranding.
- `test_CS02_SetWindowDurationFloorsRateToZero` — owner-side `setWindowDuration` with a sub-floor residue reproduces the same bug, proving the root cause is not limited to the permissionless path.
- `test_CS02_DustTopUpYieldsZeroRate` — a single owner `topUp` of `windowDuration - 1` wei yields `rewardRate = 0` with the full dust amount stranded.

Run with:

```bash
forge test --match-contract CS02PoCTest -vv
```

## Recommended mitigation steps

Any of the following closes the root cause; preferred is a combination of (B) and (E) because it both prevents the state and continues to favour the protocol on rounding:

- **Option A — Minimum rate floor.** In each of the three sites, if `rewardBudget > 0` and the floor-division rate would be `0`, bump the rate to `1` wei/sec so depletion eventually completes:
  ```solidity
  uint256 rate = rewardBudget / windowDuration;
  rewardRate = (rate == 0 && rewardBudget > 0) ? 1 : rate;
  ```
- **Option B — High-precision rate.** Store the rate scaled by `ACC_PRECISION`:
  ```solidity
  rewardRate = (rewardBudget * ACC_PRECISION) / windowDuration;
  ```
  and divide back out inside `_updatePool` / `pendingReward`. This eliminates sub-floor truncation entirely.
- **Option C — Accrue from budget directly.** Replace `elapsed * rewardRate` in `_updatePool` with `rewardBudget * elapsed / windowRemaining`, sidestepping the pre-divided rate.
- **Option D — Absorb residue at window close.** When `block.timestamp >= windowEnd` and `rewardBudget > 0`, emit the residual as a final chunk before the next reset.
- **Option E — Guard the reset.** In `_syncBudget` and `topUp`, short-circuit the window/rate reset when the new rate would round to zero, so a dust inflow does not freeze emissions:
  ```solidity
  uint256 newRate = rewardBudget / windowDuration;
  if (newRate == 0) return; // keep existing schedule, do not strand via reset
  rewardRate = newRate;
  windowEnd = block.timestamp + windowDuration;
  ```
  Pair this with Option A so any residue still in `rewardBudget` at window end is drained at the 1 wei/sec floor.

Whichever route is chosen, preserve the existing rounding direction in favour of the protocol (floor on per-user payout, not on the global rate) and add unit tests covering `rewardBudget < windowDuration` on all three mutation sites (`setWindowDuration`, `topUp`, `_syncBudget`).
