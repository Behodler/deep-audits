# QA Report - phlimbo-ea V2 (PhlimboV2 + MigratorV1V2)

## Introduction

This QA report bundles non-critical observations from the V2 security review of the phlimbo-ea suite (`PhlimboV2.sol` and `MigratorV1V2.sol`) conducted on 2026-05-19. It contains one Low-severity hardening item that amplifies a separately-submitted Medium finding, and two Centralization observations covering defense-in-depth gaps around owner-controlled parameters. Owner trust is documented as a known assumption in the project; the items below are surfaced as structural hardening recommendations rather than allegations of admin malice. High and Medium findings are submitted separately.

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| Centralization | 2 |
| **Total** | **3** |

---

## Low Severity

### [L-01] `collectReward` is callable while paused, eliminating the wait-for-unpause precondition on the `pauseWithdraw` reward windfall

**Location**: `lib/phlimbo-ea/src/PhlimboV2.sol#L298-L312` (`collectReward`)

**Description**

`collectReward` does not carry the `whenNotPaused` modifier. It is callable by any address (the function gates only on `amount > 0`; there is no role check) and calls `_updatePool()` as its first action, advancing `lastRewardTime` and `accStablePerShare` based on `rewardPerSecond * timeElapsed`.

This interacts with the M-01 finding (separately reported), which describes how `pauseWithdraw` decrements `totalStaked` without invoking `_updatePool`. The result is that the next `_updatePool` call distributes accrued rewards across the reduced share base, inflating the per-share accumulators for the remaining stakers — a windfall to non-exiting users and a forfeiture for the `pauseWithdraw` user. M-01 implicitly assumes the trigger is a normal user interaction after unpause. The observation here is that `collectReward` can trigger the same `_updatePool` advance **while the contract is still paused**, removing any wait.

For comparison, `stake`, `withdraw`, and `claim` all carry `whenNotPaused`. `collectReward` is the only reward-flow-mutating entry point that does not.

**Impact**

Amplifies M-01: a `pauseWithdraw` exit immediately becomes recoverable by any third party calling `collectReward(1)` during the pause, rather than waiting until the pause is lifted. The pauser cannot bound the windfall by leaving the contract paused indefinitely. The trigger cost is one wei of reward token, so the grief is effectively free.

This is Low rather than Medium because M-01 already carries the full economic loss; this finding accelerates rather than enlarges it. It does, however, remove a natural mitigation (`keep the contract paused until pauseWithdraw users have fully exited`) that the pauser might otherwise rely on while M-01 is being remediated.

**Recommendation**

Add `whenNotPaused` to `collectReward`. The pause state is intended to suspend all yield flows; accepting new reward deposits during a pause is operationally unnecessary. If the design genuinely requires accepting rewards during a pause (e.g., a fixed-cadence yield-accumulator bot that cannot easily back off), gate `_updatePool()` itself on the paused flag instead. Best fixed jointly with M-01 (invoke `_updatePool()` inside `pauseWithdraw`) for layered safety.

**Code Reference**

```solidity
// PhlimboV2.sol — collectReward, no whenNotPaused
function collectReward(uint256 amount) external nonReentrant {
    require(amount > 0, "Amount must be greater than 0");
    _updatePool();   // advances accumulators using post-pauseWithdraw totalStaked
    rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    rewardBalance += amount;
    rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
    emit RewardCollected(amount, rewardBalance, rewardPerSecond);
}

// Compare: stake / withdraw / claim all carry whenNotPaused.
```

---

## Centralization

### [C-01] `setDesiredAPY` has no magnitude cap (missing `MAX_APY_BPS` constant present in sibling project)

**Location**: `lib/phlimbo-ea/src/PhlimboV2.sol#L172-L190` (`setDesiredAPY`, `_updatePhUSDEmissionRate`)

**Description**

`setDesiredAPY` is gated by `onlyOwner` and uses a two-step preview/commit pattern: the first call previews `bps` and starts a 100-block window, the second call (with the same `bps` inside the window) commits. The two-step provides a notice window, but it does not impose any upper bound on the `bps` argument. The commit branch unconditionally assigns `desiredAPYBps = bps` and recomputes `phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR`. There is no cap on `bps`, no cap on `phUSDPerSecond`, no cap on cumulative minted phUSD per epoch, and no rate-limit on how often APY can be re-committed beyond the 100-block window.

Owner trust is documented as a known issue, and this finding is **not** alleging owner malice. It is a defense-in-depth observation: the sibling project `nft-staking` in the same ecosystem defines `MAX_TARGET_APY = 0.5e18` as a hard constant, establishing a clear in-ecosystem precedent for a structural magnitude cap. PhlimboV2 has no equivalent. Because phUSD is both the staked asset and the minted reward, any APY commit propagates through the staking loop without an upper bound on phUSD inflation enforced at the contract level.

This is filed as Centralization rather than reckless-admin (which C4 treats as invalid): a reckless-admin issue covers an admin picking a wrong-but-sensible-looking value within an existing bound. C-01 documents the absence of any bound at all on a parameter that controls native-token minting.

**Impact**

A misconfigured or compromised commit can produce a phUSD emission rate orders of magnitude higher than intended within a single 100-block window (~20 minutes on Ethereum, ~3 minutes on most L2s). Migrator-staked users (positions created on a V1 user's behalf, who did not opt into V2) are the worst-case affected population: they are unlikely to be monitoring `IntendedSetAPY` events. The two-step preview alone is insufficient as a magnitude defense; it is a timing defense.

The action is irreversible (minted phUSD cannot be clawed back), the affected supply is the project's native token, and the mechanism feeds back through the staking loop. These three properties together place the finding at the upper end of centralization severity.

**Recommendation**

Add a hard upper bound to `setDesiredAPY`, matching the `nft-staking` precedent:

```solidity
uint256 public constant MAX_APY_BPS = 100_000; // 1000% APY

function setDesiredAPY(uint256 bps) external onlyOwner {
    require(bps <= MAX_APY_BPS, "APY exceeds cap");
    // ...existing two-step logic
}
```

If a parametric cap is preferred over a constant, make the cap itself timelocked (e.g., 7-day delay) so any expansion of the cap has a meaningful pre-commit window. Document the chosen upper bound in the contract NatSpec so migrator-staked users know the worst-case emission rate before their V1 position is migrated. A secondary defense is a cap on cumulative phUSD minted per epoch, which neutralizes long-uninterrupted high-emission periods even at moderate per-second values.

**Code Reference**

```solidity
// PhlimboV2.sol — setDesiredAPY, no upper bound on bps
function setDesiredAPY(uint256 bps) external onlyOwner {
    bool isPreview = !apySetInProgress ||
                    block.number > pendingAPYBlockNumber + 100 ||
                    bps != pendingAPYBps;
    if (isPreview) {
        emit IntendedSetAPY(bps, block.number, msg.sender);
        pendingAPYBps = bps;
        pendingAPYBlockNumber = block.number;
        apySetInProgress = true;
    } else {
        _updatePool();
        uint256 oldAPY = desiredAPYBps;
        desiredAPYBps = bps;          // accepts any uint256
        _updatePhUSDEmissionRate();   // propagates unchecked
        emit DesiredAPYUpdated(oldAPY, bps);
        apySetInProgress = false;
    }
}

function _updatePhUSDEmissionRate() internal {
    if (totalStaked == 0) { phUSDPerSecond = 0; return; }
    phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR; // unbounded
}
```

---

### [C-02] Hook calls are not wrapped in `try/catch`; a buggy or misconfigured hook reverts the outer `stake`/`withdraw`/`claim`

**Location**: `lib/phlimbo-ea/src/PhlimboV2.sol#L242-L246` (`setHook`); hook invocation sites in `stake`, `withdraw`, `claim`

**Description**

The `hook` address is invoked unconditionally at the end of every successful `stake`, `withdraw`, and `claim`. The project's documented design (per the `IPhlimboHook` NatSpec) explicitly acknowledges: *"a reverting hook will revert the outer call."* This is a documented design choice, and the hook is owner-installed under a trusted-owner assumption. The finding is **not** alleging owner malice.

The value of the observation is the absence of `try/catch` around what the interface itself labels an **optional** integration point. Because the hook is optional, a revert from the hook should not need to roll back state transitions that have already been validated and executed (token transfers, accumulator updates, `totalStaked` adjustments). Today, a buggy or misconfigured non-malicious hook — for example, a hook that runs out of gas under specific input, makes an external call to a contract that is later self-destructed, or has a regression after an upgrade — will brick user-facing functionality the same way a malicious hook would. The trust assumption protects against bad intent; it does not protect against bad code in the hook contract.

This is a hardening recommendation rather than a vulnerability. The fix is local, low-risk, and preserves existing semantics for well-behaved hooks.

**Impact**

A non-malicious bug in a future hook contract (gas, external dependency, integer overflow in hook logic, etc.) causes `stake`, `withdraw`, and `claim` to revert for affected users until the owner deploys a corrected hook or sets `hook` back to `address(0)`. During the window, users' funds remain on-deposit and unclaimable through normal paths; `pauseWithdraw` remains available only if the contract is in paused state, and that path is itself constrained by separately-reported H-01 / M-01 issues.

The mid-stream hook-swap scenario (owner changes the hook between a migrator-created V2 position and the user's first interaction) is in scope of documented owner-trust and not separately submitted; it is the buggy-hook variant that motivates the hardening request.

**Recommendation**

Wrap each hook invocation in `try/catch` so a reverting hook does not roll back state mutations that have already validated and completed. Reentrancy is still blocked by the contract's `nonReentrant` guard.

```solidity
if (address(hook) != address(0)) {
    try hook.onDeposit(msg.sender, user, amount) {
        // ok
    } catch {
        emit HookCallFailed("onDeposit", user);
    }
}
```

Apply the same wrapper at the `onWithdraw` and `onClaim` call sites. The `HookCallFailed` event preserves off-chain observability so operators can detect a misbehaving hook without freezing user flows. Optionally pair this with a two-step `setHook` (mirroring `setDesiredAPY`) so users observe pending hook changes during a confirmation window, and emit per-call invocation events so off-chain monitors can detect anomalous hook behavior.

The `try/catch` wrapper alone is the smallest change with the highest user value and addresses the buggy-hook DoS variant without altering trust assumptions.

**Code Reference**

```solidity
// PhlimboV2.sol — setHook, single-step, no notice
function setHook(address _hook) external onlyOwner {
    address oldHook = address(hook);
    hook = IPhlimboHook(_hook);
    emit HookSet(oldHook, _hook);
}

// stake — hook is the last call; a revert here rolls back the deposit
emit Staked(user, amount);
if (address(hook) != address(0)) {
    hook.onDeposit(msg.sender, user, amount);   // no try/catch
}

// withdraw and claim follow the same pattern.
// Per IPhlimboHook NatSpec:
//   "Hooks fire AFTER all internal state mutations and external token transfers complete,
//    inside PhlimboV2's nonReentrant guard. The owner of PhlimboV2 is trusted to set
//    non-malicious hooks; a reverting hook will revert the outer call."
```

---
