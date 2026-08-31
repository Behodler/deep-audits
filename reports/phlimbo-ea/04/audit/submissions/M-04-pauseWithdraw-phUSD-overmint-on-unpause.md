<!--
ID: pe4m4
C4 Submission Metadata
Title: [M-04] pauseWithdraw shrinks totalStaked without refreshing phUSDPerSecond, over-minting phUSD to remaining stakers on unpause
Severity: Medium
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L245-L261
PoC File: test/poc-2004-M-04-phusd-overmint-on-unpause.t.sol
-->

## Severity

**Medium.**

The phUSD emission stream has **no balance cap** (`PhlimboEA` holds phUSD mint authority and `_claimRewards` mints unconditionally at [`Phlimbo.sol#L442`](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L442)), so the bug is direct, unbacked supply inflation rather than a bounded mis-accounting. It is rated **Medium** rather than High because of two compounding likelihood requirements that must both hold:

1. `desiredAPYBps > 0` (otherwise `phUSDPerSecond == 0` and the phUSD branch in `_updatePool` is skipped entirely), and
2. the specific emergency sequence `pause -> pauseWithdraw -> unpause`.

The **live deployment is documented as zero-APY** (known issue KI-10), which immunizes the current production configuration and is the reason this is held at Medium as a *latent, config-dependent value leak*.

**Escalation note:** under a shipped non-zero-APY configuration with a long stale window and a large pre/post-exit stake ratio, the over-mint is effectively unbounded and this should be **re-classified as High**. This is a Law-3 operational **footgun** (a non-obvious consequence of a pauser-gated emergency path), not a malicious-owner vector — a competent, non-malicious operator who enables APY would be surprised that an emergency `pauseWithdraw` silently inflates phUSD for everyone else on unpause.

This is distinct from M-02, which is the `claim`-revert brick affecting the *exiting* user; here the damage instead reaches the **remaining, non-bricked** stakers as over-minted phUSD.

## Finding description and impact

### Summary

`phUSDPerSecond` is an absolute (not per-share) emission rate, sized as `phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR` ([`_updatePhUSDEmissionRate`, L461-L470](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L461-L470)). Because it scales with `totalStaked`, it must be recomputed every time `totalStaked` changes. Both normal entry/exit paths do exactly this — `stake` calls `_updatePhUSDEmissionRate()` after bumping `totalStaked` ([L321-L324](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L321-L324)), and `withdraw` calls `_updatePool()` **and then** `_updatePhUSDEmissionRate()` around its decrement ([L334-L369](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L334-L369)).

The emergency exit `pauseWithdraw` ([L245-L261](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L245-L261)) breaks this invariant: it decrements `totalStaked` at [L254](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L254) but **never calls `_updatePool()`** (so `lastRewardTime` is not advanced) and **never calls `_updatePhUSDEmissionRate()`** (so `phUSDPerSecond` is not resized).

### Vulnerability details

Let `S0` be `totalStaked` at the last stake/withdraw before the pause, and let `r0 = (S0 * desiredAPYBps) / 10000 / SECONDS_PER_YEAR` be the emission rate sized for `S0`. The sequence is:

1. Users have staked; `phUSDPerSecond = r0` (sized for `S0`), `desiredAPYBps > 0`.
2. Pauser calls `pause()`.
3. One or more users call `pauseWithdraw(...)`, dropping `totalStaked` to `S1 = S0 - exited < S0`. Per [L245-L261](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L245-L261), `phUSDPerSecond` stays at the stale `r0`, and `lastRewardTime` is **not** advanced (so the whole paused interval becomes accruable `timeElapsed` on unpause).
4. Pauser calls `unpause()`. The first `_updatePool()` ([L389-L426](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L389-L426)) computes `phUSDReward = timeElapsed * phUSDPerSecond` using the stale `r0` and divides by the **smaller** `S1`:

   ```solidity
   // Update phUSD rewards (if phUSDPerSecond is set)
   if (phUSDPerSecond > 0) {
       uint256 phUSDReward = timeElapsed * phUSDPerSecond;   // r0 (sized for S0)
       accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked; // / S1
   }
   ```

   so `accPhUSDPerShare` is inflated by a factor of `S0 / S1` relative to a correctly-resized rate.
5. `claim()` does **not** recompute the emission rate, so the stale over-rate persists until the next rate-recomputing `stake`/`withdraw`. Each remaining staker mints `S0/S1 x` their fair phUSD via `_claimRewards` -> `phUSD.mint` ([L440-L443](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L440-L443)).

### Impact

Uncapped, unbacked **phUSD supply inflation**. Remaining stakers are minted phUSD at an over-rate of `S0/S1` for the entire window between unpause and the next rate-recomputing interaction. The excess phUSD is value created from nothing: it dilutes every phUSD holder and breaks the APY/emission invariant (story-006 / INV-7) that the protocol mints phUSD at most at the configured APY on the live stake. There is no principal theft and no balance ceiling on the phUSD branch, so the over-mint is a pure solvency dilution whose magnitude grows with `S0/S1`, the stale window length, and the configured APY.

## Root cause

`pauseWithdraw` mutates `totalStaked` without keeping the phUSD accounting consistent, unlike every other path that touches `totalStaked`:

- [`Phlimbo.sol#L245-L261`](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L245-L261) — `pauseWithdraw`: decrements `totalStaked` at [L254](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L254) but calls neither `_updatePool()` nor `_updatePhUSDEmissionRate()`.
- [`Phlimbo.sol#L419-L423`](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L419-L423) — `_updatePool` accrues `phUSDReward = timeElapsed * phUSDPerSecond` (stale `r0`) and divides by the now-smaller `totalStaked` (`S1`).
- [`Phlimbo.sol#L461-L470`](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L461-L470) — `_updatePhUSDEmissionRate` is the function that would have resized `phUSDPerSecond` to `S1`, but it is never reached from `pauseWithdraw`.

Contrast with `withdraw` ([L334-L369](https://github.com/Behodler/phlimbo-ea/blob/master/src/Phlimbo.sol#L334-L369)), which calls `_updatePool()` (accruing at the old rate up to *now* and advancing `lastRewardTime`) and then `_updatePhUSDEmissionRate()` (resizing for the new `totalStaked`). `pauseWithdraw` omits both halves of that correct sequence.

## Proof of Concept

The PoC stakes A and B (100e18 each, `S0 = 200e18`), pauses, has B fully exit via `pauseWithdraw` (`S1 = 100e18`, rate left stale), unpauses, warps a 30-day window, and has A (the sole remaining staker, owning 100% of `S1`) claim. It measures phUSD minted to A against the *fair* APY cap for A's stake had the rate been resized to `S1`.

Note: the test uses a `RecordingFlax` mock that records cumulative minted supply; `PhlimboEA` only calls `phUSD.mint(...)` plus standard ERC20 ops and holds mint authority, so a recording-mint ERC20 is a faithful stand-in. All phUSD minted by the claim is attributed to A (A is the only claimer), so `mintedByClaim == aReceived`.

Run:

```bash
forge test --match-path test/poc-2004-M-04-phusd-overmint-on-unpause.t.sol -vv
```

Observed output (over-mint factor exactly 2.0x for `S0/S1 = 2`):

```
[PASS] test_M04_phUSDOverMintOnUnpause()
Logs:
  S0 (pre-pause totalStaked)     : 200000000000000000000
  S1 (post-pauseWithdraw)        : 100000000000000000000
  phUSD minted to A (claim)      : 1643835616437600000   (~1.6438e18)
  Fair APY cap for A             : 821917808217504000    (~0.8219e18)
  overMintFactor (x1e18)         : 2000000000003153600   (~2.0)
```

A minted ~1.6438e18 phUSD versus a fair cap of ~0.8219e18 — exactly the predicted `S0/S1 = 2.0x` over-mint.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Phlimbo.sol";
import "./Mocks.sol";

/**
 * @title RecordingFlax
 * @notice Mintable phUSD mock that records cumulative minted supply.
 * @dev PhlimboEA only ever calls phUSD.mint(...) plus standard ERC20 ops on it,
 *      so an ERC20 with a recording mint() is a faithful stand-in. PhlimboEA
 *      holds mint authority (it is the caller of mint()).
 */
contract RecordingFlax is ERC20 {
    uint256 public totalMinted;

    constructor() ERC20("Recording phUSD", "rPHUSD") {}

    function mint(address to, uint256 amount) external {
        totalMinted += amount;
        _mint(to, amount);
    }
}

/**
 * @title M-04 PoC: pause -> pauseWithdraw -> unpause OVER-MINTS phUSD by S0/S1
 *
 * @dev Vulnerability Location: src/Phlimbo.sol
 *      - phUSDPerSecond is sized for totalStaked at the last stake/withdraw (= S0).
 *      - pauseWithdraw (L245-261) drops totalStaked to S1 < S0 but does NOT call
 *        _updatePhUSDEmissionRate, so phUSDPerSecond stays sized for S0.
 *      - On unpause, _updatePool accrues phUSDReward = elapsed * phUSDPerSecond and
 *        divides by the smaller S1 (L420-422), inflating accPhUSDPerShare by S0/S1.
 *      - claim() never recomputes the rate, so remaining stakers mint S0/S1 x their
 *        fair phUSD until the next rate-recomputing stake/withdraw.
 *
 * SCENARIO (S0 = 200e18, S1 = 100e18 -> overMintFactor ~= 2.0)
 *   1. Owner sets desiredAPYBps = 1000 (10%).
 *   2. Users A and B each stake 100e18 (S0 = 200e18). phUSDPerSecond sized for S0.
 *   3. Pauser pauses.
 *   4. B full pauseWithdraw(100e18) -> totalStaked = S1 = 100e18, rate UNCHANGED (stale).
 *   5. Pauser unpauses; warp one window.
 *   6. A claims -> minted phUSD = ~2x the fair APY cap on A's 100e18 stake.
 */
contract PoC2004_M04 is Test {
    PhlimboEA public phlimbo;
    RecordingFlax public phUSD;
    MockStable public rewardToken;

    address public userA  = address(0xA11CE);
    address public userB  = address(0xB0B);
    address public pauser = address(0xBEEF);

    uint256 constant DEPLETION_DURATION = 7 days;
    uint256 constant STAKE_EACH         = 100 ether;   // A and B each
    uint256 constant APY_BPS            = 1000;        // 10% APY, > 0
    uint256 constant WINDOW             = 30 days;     // stale-rate accrual window
    uint256 constant SECONDS_PER_YEAR   = 365 days;

    function setUp() public {
        phUSD = new RecordingFlax();
        rewardToken = new MockStable();
        phlimbo = new PhlimboEA(address(phUSD), address(rewardToken), DEPLETION_DURATION);

        phUSD.mint(userA, STAKE_EACH);
        phUSD.mint(userB, STAKE_EACH);

        vm.prank(userA);
        phUSD.approve(address(phlimbo), type(uint256).max);
        vm.prank(userB);
        phUSD.approve(address(phlimbo), type(uint256).max);

        phlimbo.setPauser(pauser);

        // Two-step APY commit -> desiredAPYBps = 1000.
        phlimbo.setDesiredAPY(APY_BPS);
        vm.roll(block.number + 1);
        phlimbo.setDesiredAPY(APY_BPS);
    }

    function test_M04_phUSDOverMintOnUnpause() public {
        // 2. A and B stake in the SAME timestamp so accPhUSDPerShare stays 0 (debts = 0).
        vm.prank(userA);
        phlimbo.stake(STAKE_EACH, address(0));
        vm.prank(userB);
        phlimbo.stake(STAKE_EACH, address(0));

        uint256 S0 = phlimbo.totalStaked();
        assertEq(S0, 2 * STAKE_EACH, "S0 = 200e18");

        // phUSDPerSecond is sized for S0.
        uint256 rateForS0 = phlimbo.phUSDPerSecond();
        assertEq(rateForS0, (S0 * APY_BPS) / 10000 / SECONDS_PER_YEAR, "rate sized for S0");
        assertGt(rateForS0, 0, "non-zero emission rate (APY > 0)");

        // 3. Pause. 4. B fully exits via pauseWithdraw -> totalStaked = S1, rate stale.
        vm.prank(pauser);
        phlimbo.pause();
        vm.prank(userB);
        phlimbo.pauseWithdraw(STAKE_EACH);

        uint256 S1 = phlimbo.totalStaked();
        assertEq(S1, STAKE_EACH, "S1 = 100e18");
        assertEq(phlimbo.phUSDPerSecond(), rateForS0, "rate is STALE: still sized for S0 after pauseWithdraw");

        // 5. Unpause and let the stale rate accrue over the window.
        vm.prank(pauser);
        phlimbo.unpause();
        vm.warp(block.timestamp + WINDOW);

        // 6. A claims; measure phUSD minted to A.
        uint256 mintedBefore = phUSD.totalMinted();
        uint256 aBalBefore = phUSD.balanceOf(userA);

        vm.prank(userA);
        phlimbo.claim();

        uint256 mintedByClaim = phUSD.totalMinted() - mintedBefore;
        uint256 aReceived = phUSD.balanceOf(userA) - aBalBefore;
        assertEq(mintedByClaim, aReceived, "all minted phUSD went to A (A is the only claimer)");

        // FAIR cap: what A's 100e18 stake should earn at 10% APY over the window
        // had the rate been correctly recomputed for S1 (A is the sole remaining staker).
        uint256 fairRateForS1 = (S1 * APY_BPS) / 10000 / SECONDS_PER_YEAR;
        uint256 fairCap = WINDOW * fairRateForS1; // A owns 100% of S1

        emit log_named_uint("S0 (pre-pause totalStaked)     ", S0);
        emit log_named_uint("S1 (post-pauseWithdraw)        ", S1);
        emit log_named_uint("phUSD minted to A (claim)      ", mintedByClaim);
        emit log_named_uint("Fair APY cap for A             ", fairCap);
        emit log_named_uint("overMintFactor (x1e18)         ", mintedByClaim * 1e18 / fairCap);

        // A minted MORE than the fair APY cap...
        assertGt(mintedByClaim, fairCap, "A minted more phUSD than the fair APY cap");

        // ...by a factor of ~S0/S1 == 2.0x.
        assertApproxEqRel(
            mintedByClaim,
            fairCap * S0 / S1,
            0.001e18,
            "over-mint factor must equal S0/S1 (~2x)"
        );
        // Explicit numeric guard: factor is at least 1.99x.
        assertGt(mintedByClaim * 100, fairCap * 199, "over-mint factor >= 1.99x");
    }
}
```

## Recommended mitigation steps

Make `pauseWithdraw` settle and resize the phUSD stream before shrinking the pool, mirroring the correct ordering already used by `withdraw`. Concretely, accrue rewards up to the current timestamp at the old rate (advancing `lastRewardTime`), then decrement `totalStaked`, then recompute the rate:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance");
    require(amount > 0, "Amount must be greater than 0");

    // Accrue at the CURRENT (pre-shrink) rate and advance lastRewardTime,
    // so no elapsed time is later accrued at a rate sized for a larger pool.
    _updatePool();

    // Update user balance
    user.amount -= amount;

    // Update total staked
    totalStaked -= amount;

    // Resize the emission rate to the new (smaller) totalStaked so the
    // stream cannot over-mint on unpause.
    _updatePhUSDEmissionRate();

    // Transfer phUSD to user
    IERC20(address(phUSD)).safeTransfer(msg.sender, amount);

    emit EmergencyWithdrawal(msg.sender, amount);
}
```

Note `_updatePool()` early-returns when `totalStaked == 0` (still advancing `lastRewardTime`) and is a no-op while `block.timestamp <= lastRewardTime`, so adding it to the emergency path is safe. If preserving the strictly state-light "emergency exit" semantics of `pauseWithdraw` is preferred, an equivalent fix is to force a single `_updatePool()` + `_updatePhUSDEmissionRate()` on `unpause()` before any further accrual, so `phUSDPerSecond` is re-anchored to the live `totalStaked` and no stale interval is ever accrued at the old rate.

**Safe-config guidance (current live deployment):** the contract is currently zero-APY, which suppresses this entirely. Do not enable a non-zero `desiredAPYBps` without applying the fix above; doing so turns this latent footgun into an active, uncapped phUSD-inflation vector whose magnitude scales with `S0/S1` and the paused-window length.
