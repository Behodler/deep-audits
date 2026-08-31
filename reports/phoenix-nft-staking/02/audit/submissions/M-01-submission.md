<!--
C4 Submission Metadata
Title: [M-01] `ownerOrNotGriefed` guard is bypassed via `claim()`, re-enabling the prior ES-01 rate-dilution grief
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L281
PoC File: workspace/phoenix-nft-staking/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

The `ownerOrNotGriefed` modifier added in story-003 to close the prior-audit ES-01 rate-dilution grief is applied only to `topUp()` and `pullAndRefresh()`. The actual schedule-mutating logic lives in `_syncBudget()`, which is also invoked from the unguarded `stake()`, `unstake()`, and `claim()` entrypoints. `claim()` is permissionless and requires no prior stake, so any EOA can reproduce the ES-01 attack at gas-only cost.

### Vulnerability details

The guard is defined on the modifier at [`NFTStaker.sol#L114-L121`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L114-L121):

```solidity
// NFTStaker.sol:114-121
modifier ownerOrNotGriefed() {
    uint256 rPre = rewardRate;
    uint256 endPre = windowEnd;
    _;
    require(
        msg.sender == owner() || rewardRate >= rPre || endPre <= block.timestamp, "NFTStaker: reward rate reduced"
    );
}
```

It is wired into two entrypoints — `topUp()` at [L185](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L185) and `pullAndRefresh()` at [L200](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L200):

```solidity
// NFTStaker.sol:185
function topUp(uint256 amount) external ownerOrNotGriefed { ... }

// NFTStaker.sol:200
function pullAndRefresh() external ownerOrNotGriefed {
    _syncBudget();
}
```

However, the schedule-mutating side effects the modifier is meant to guard live inside `_syncBudget()` at [`NFTStaker.sol#L208-L220`](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L208-L220):

```solidity
// NFTStaker.sol:208-220
function _syncBudget() internal {
    _updatePool();                                   // settles accrual under the OLD rate
    if (address(dispatcherHook) == address(0)) return;
    uint256 pre = rewardToken.balanceOf(address(this));
    dispatcherHook.pull();
    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
    if (inflow == 0) return;
    rewardBudget += inflow;
    windowEnd = block.timestamp + windowDuration;    // <-- schedule reset
    rewardRate = rewardBudget / windowDuration;      // <-- rate dilution
    emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
}
```

`_syncBudget()` is called unguarded from three additional user-facing entrypoints:

- `stake()` at [L248](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L248)
- `unstake()` at [L268](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L268)
- `claim()` at [L281-L290](https://github.com/Behodler/phoenix-nft-staking/blob/5062553/src/NFTStaker.sol#L281-L290)

`claim()` is the cleanest bypass because it enforces no preconditions on the caller:

```solidity
// NFTStaker.sol:281-290
function claim() external nonReentrant whenNotPaused {
    _syncBudget();                                   // <-- unguarded mutation
    UserInfo storage user = users[msg.sender];
    uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    if (pending > 0) {
        uint256 paid = _safePay(pending);
        if (paid > 0) emit Claimed(msg.sender, paid);
    }
    user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;
}
```

For a caller with `user.amount == 0`, `pending` is zero and the payout block is a no-op — but `_syncBudget()` has already run, stretching `windowEnd` to `now + windowDuration` and lowering `rewardRate` to `rewardBudget / windowDuration` whenever any non-zero mint-debt was pending on the dispatcher hook.

The modifier-per-entrypoint design is architecturally incomplete: the side effect it protects is reachable from five entrypoints, but the guard is attached to only two of them. Guarding entrypoints instead of the mutation site itself leaves the other three as open back-doors into the same state transition.

### Impact

Protocol function impairment with high likelihood and no capital cost:

- **Rate dilution on demand.** Any unprivileged EOA can permissionlessly lower `rewardRate` for legitimate stakers by calling `claim()` once per block. The prior-audit ES-01 scenario (~83% forward-emission cut pinnable indefinitely over the default 540-day window) is fully reachable again.
- **Quantified in the PoC.** Under a conservative 10-day window, a single `claim()` poke by a zero-stake EOA drops `rewardRate` by ≥ 9% (≥ 900 bps measured; ~9.99% in the representative run) and stretches `windowEnd` by the full configured window. Under the default 540-day window the per-poke dilution is proportionally larger.
- **Indefinitely sustainable.** Five repeated pokes keep the rate strictly below baseline, and the attack can be repeated every block at only the gas cost of a `claim()` no-op. The only external requirement — a non-zero dispatcher mint-debt — is the normal operating condition per the protocol spec (feature #4, pull-on-interaction).
- **Direct regression.** The story-003 fix introduced the `ownerOrNotGriefed` modifier specifically to close ES-01. The companion PoC confirms the modifier itself is correct: the same attacker, same inputs, and same dilution revert cleanly via both `topUp()` and `pullAndRefresh()`. The asymmetry between the guarded and unguarded entrypoints is the bug.

Assets are not directly stolen or permanently frozen — the budgeted rewards eventually pay out — so the finding is Medium rather than High. But the owner-configured emission schedule, which is the protocol's central configuration surface for this contract, is permissionlessly impairable by any EOA, and value is continually shifted from long-term stakers to JIT entrants.

### Proof of Concept

Full PoC at [`workspace/phoenix-nft-staking/test/poc-M-01.t.sol`](../../../../workspace/phoenix-nft-staking/test/poc-M-01.t.sol). Run with:

```bash
forge test --match-contract PocM01 -vv
```

Three tests demonstrate the finding:

1. **`test_M01_UnprivilegedClaimDilutesRewardRate`** — single unprivileged `claim()` by a zero-stake, zero-role EOA drops `rewardRate` by ≥ 900 bps and resets `windowEnd` to `now + windowDuration`. Key assertions:

   ```solidity
   assertEq(windowEndAfter, block.timestamp + WINDOW, "windowEnd must have been reset to now + full windowDuration");
   assertLt(rateAfter, rateBefore, "attack must reduce per-second emission rate");
   assertGe(dropBps, 900, "expected >= 9% reduction in rewardRate per attack");
   ```

   Representative log output (10-day window, 10,000 phUSD seed, 1 day elapsed):

   ```
   --- After 1 day elapsed, before attack ---
   rewardRate  (wei/sec) : 11574074074074074
   windowEnd   (ts)      : <t0 + 10 days>
   seconds remaining     : 777600
   --- After attacker claim() ---
   rewardRate  (wei/sec) : 10416666666666666
   windowEnd   (ts)      : <t1 + 10 days>
   seconds remaining     : 864000
   rate reduction (bps)  : 999
   ```

2. **`test_M01_RepeatedClaimsPinRateDiluted`** — five repeated `claim()` pokes with microscopic (1e6 wei) mint-debt between each keep the rate pinned strictly below baseline indefinitely. Each poke re-asserts `windowEnd == block.timestamp + WINDOW`.

3. **`test_M01_Companion_TopUpPathIsCorrectlyGuarded`** — the same attacker, mid-window, routing the same dilution through `topUp()` or `pullAndRefresh()` reverts with `"NFTStaker: reward rate reduced"`, while routing it through `claim()` succeeds and lowers `rewardRate`. This isolates the defect to missing wiring rather than a defective guard.

### Tools Used

Foundry (forge test), manual review.

## Recommended mitigation steps

### Design rationale

The `ownerOrNotGriefed` modifier is an entry-level defense that fails asymmetrically (it covers two of the five `_syncBudget()` callers) and is also an economic straitjacket: a revert on any non-owner rate reduction forces the owner to manually defend the schedule during quieter mint periods. A cleaner model treats the schedule reset as the normal consequence of a real dispatcher inflow, but rate-limits how often resets can occur so that high-frequency user activity (claim/stake/unstake) cannot repeatedly churn the schedule in a single window.

Concretely:

1. Remove `ownerOrNotGriefed` entirely.
2. Add an owner-settable `minPullInterval` that gates how often `_syncBudget()` is allowed to actually invoke `dispatcherHook.pull()` from a user-triggered path. Within the cooldown, the pull attempt silently no-ops and emissions continue against the existing schedule.
3. Restrict `pullAndRefresh()` and `topUp()` to the owner, and have them bypass the cooldown so the owner retains unconditional operational control (force a refresh, inject emergency phUSD, re-baseline the schedule after parameter changes).

This is a deliberate "version 1" with a single operator knob. Richer self-regulation (e.g. deriving the interval from on-chain mint cadence) can be layered on later once real-world interaction data is available.

### Concrete changes

#### New state and event

```solidity
/// @notice Minimum seconds between user-triggered `_syncBudget()` pulls.
///         Owner-triggered paths (`topUp`, `pullAndRefresh`) bypass this.
uint256 public minPullInterval;

/// @notice Timestamp of the last dispatcher pull attempt issued from any path.
uint256 public lastPullAt;

event MinPullIntervalChanged(uint256 previous, uint256 next);
```

Initialise `minPullInterval` in the constructor (or leave defaulted to 0 and document that the owner must call `setMinPullInterval` at deploy time). A sensible default is `windowDuration / 18` (≈ 30 days at the 540-day default); wire whatever the protocol team considers correct.

#### Owner setter

```solidity
function setMinPullInterval(uint256 newInterval) external onlyOwner {
    emit MinPullIntervalChanged(minPullInterval, newInterval);
    minPullInterval = newInterval;
}
```

#### `_syncBudget` becomes interval-aware

```diff
-function _syncBudget() internal {
-    _updatePool();
-    if (address(dispatcherHook) == address(0)) return;
-    uint256 pre = rewardToken.balanceOf(address(this));
-    dispatcherHook.pull();
-    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
-    if (inflow == 0) return;
-    rewardBudget += inflow;
-    windowEnd = block.timestamp + windowDuration;
-    rewardRate = rewardBudget / windowDuration;
-    emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
-}
+function _syncBudget(bool bypassInterval) internal {
+    _updatePool();
+    if (address(dispatcherHook) == address(0)) return;
+    if (!bypassInterval && block.timestamp < lastPullAt + minPullInterval) return;
+    uint256 pre = rewardToken.balanceOf(address(this));
+    dispatcherHook.pull();
+    lastPullAt = block.timestamp;
+    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
+    if (inflow == 0) return;
+    rewardBudget += inflow;
+    windowEnd = block.timestamp + windowDuration;
+    rewardRate = rewardBudget / windowDuration;
+    emit Pulled(inflow, rewardBudget, rewardRate, windowEnd);
+}
```

#### Entrypoint wiring

```diff
-function stake(uint256 amount) external nonReentrant whenNotPaused {
+function stake(uint256 amount) external nonReentrant whenNotPaused {
     require(amount > 0, "NFTStaker: zero stake");
-    _syncBudget();
+    _syncBudget(false);
     ...

-function unstake(uint256 amount) external nonReentrant whenNotPaused {
+function unstake(uint256 amount) external nonReentrant whenNotPaused {
     require(amount > 0, "NFTStaker: zero unstake");
     UserInfo storage user = users[msg.sender];
     require(user.amount >= amount, "NFTStaker: insufficient stake");
-    _syncBudget();
+    _syncBudget(false);
     ...

-function claim() external nonReentrant whenNotPaused {
-    _syncBudget();
+function claim() external nonReentrant whenNotPaused {
+    _syncBudget(false);
     ...
```

#### `pullAndRefresh` and `topUp` become owner-only with interval bypass

```diff
-function topUp(uint256 amount) external ownerOrNotGriefed {
+function topUp(uint256 amount) external onlyOwner {
     require(amount > 0, "NFTStaker: zero topUp");
     _updatePool();
     rewardToken.safeTransferFrom(msg.sender, address(this), amount);
     rewardBudget += amount;
     windowEnd = block.timestamp + windowDuration;
     rewardRate = rewardBudget / windowDuration;
     emit ToppedUp(msg.sender, amount, rewardBudget, rewardRate);
 }

-function pullAndRefresh() external ownerOrNotGriefed {
-    _syncBudget();
+function pullAndRefresh() external onlyOwner {
+    _syncBudget(true);
 }
```

#### Modifier removal

```diff
-modifier ownerOrNotGriefed() {
-    uint256 rPre = rewardRate;
-    uint256 endPre = windowEnd;
-    _;
-    require(
-        msg.sender == owner() || rewardRate >= rPre || endPre <= block.timestamp,
-        "NFTStaker: reward rate reduced"
-    );
-}
```

Delete in full. With `pullAndRefresh`/`topUp` restricted to the owner and user-path resets rate-limited by `minPullInterval`, the asymmetric guard has no remaining load-bearing role.

### Feature-spec implications

Two spec items in `lib/phoenix-nft-staking/CLAUDE.md` change meaning and should be updated alongside the implementation:

- **Feature #5 ("Window reset on inflow")** — amend to note that user-path resets are gated by `minPullInterval`; the window resets on the first qualifying pull after the cooldown elapses, not on every interaction.
- **Feature #7 ("Owner manual phUSD injection")** — `topUp` is now owner-only (previously permissionless). If permissionless top-ups were a desired feature, preserve them as a separate non-reset path that increments `rewardBudget` without touching `windowEnd` / `rewardRate`.

### Regression tests

At minimum:

1. **Cooldown enforced** — consecutive `claim()` / `stake()` / `unstake()` calls within `minPullInterval` do not reset `windowEnd` or `rewardRate` (the second call's pull no-ops). Replaces the current PoC `test_M01_RepeatedClaimsPinRateDiluted` assertion.
2. **Cooldown expiry** — after `minPullInterval` has elapsed and a real dispatcher inflow is available, the next user-path call does trigger the reset.
3. **Owner bypass** — `pullAndRefresh()` and `topUp()` reset the schedule even when `block.timestamp < lastPullAt + minPullInterval`.
4. **Access control** — non-owner calls to `pullAndRefresh()`, `topUp()`, and `setMinPullInterval()` revert with `OwnableUnauthorizedAccount`.
5. **Interval setter** — `setMinPullInterval` updates storage, emits `MinPullIntervalChanged`, and takes effect on the next user-path call.
6. **Zero-interval compatibility** — with `minPullInterval == 0`, user-path calls pull on every interaction (matches pre-fix feature #4 semantics).

The existing `test_M01_UnprivilegedClaimDilutesRewardRate` PoC should be retained as a regression guard and updated to assert that a single `claim()` mid-window does not reset the schedule while the cooldown is active.
