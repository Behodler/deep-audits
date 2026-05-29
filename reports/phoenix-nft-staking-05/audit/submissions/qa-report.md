# QA Report — phoenix-nft-staking

## Overview

This report bundles the Low-severity, Centralization, and state-hygiene (QA) findings surfaced during the run-05 audit of `lib/phoenix-nft-staking/src/NFTStaker.sol` at commit `66af47d`. The High/Medium findings are submitted separately.

| Category                  | Count |
|---------------------------|-------|
| Low Risk                  | 3     |
| Centralization            | 2     |
| QA / state-hygiene        | 4     |
| **Total**                 | **9** |

All line references are against `src/NFTStaker.sol` at commit `66af47d`.

---

## Low Risk Findings

### [L-01] `_recomputeSchedule` trusts raw `balanceOf(this)` when deriving `V`, enabling donation-based schedule griefing

**Context:** [`NFTStaker.sol#L365-L376`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L365-L376)

**Description:** `_recomputeSchedule` derives the headline `V = balance + mintDebt` by reading the reward token balance directly:

```solidity
uint256 V = rewardToken.balanceOf(address(this));
if (address(dispatcherHook) != address(0)) {
    V += dispatcherHook.mintDebt();
}
// ...
rewardBudget = V;
windowEnd    = block.timestamp + runway;
```

Because there is no internal "accounted balance" tracking alongside `rewardBudget`, any unsolicited phUSD transfer into the contract is silently picked up the next time `_recomputeSchedule` runs and folded into `rewardBudget` and `windowEnd`. An attacker who front-runs an `setTargetAPY` / `setDispatcherIndex` / `setNFTMinter` / `topUp` / user-triggered `_syncBudget` call with a 1-wei `phUSD` transfer can perturb `V` (and thus `windowEnd`) at effectively zero cost to themselves. When combined with the over-commitment path flagged in the Medium findings (budget recomputed from a balance that still contains reward debt owed to existing stakers), the donation amplifies the over-emission.

**Impact:** Runway predictability and the APY invariant (`runway = V / R`) are perturbable by any address holding phUSD. No direct fund loss — the donor voluntarily subsidises the pool — but the contract's schedule becomes driftable by unsolicited transfers, which is a spec deviation from the closed-form APY model described in the submodule `CLAUDE.md`.

**Recommendation:** Track an internal `accountedBalance` that only moves on `topUp`, `_safePay`, `pull()` inflow, and user actions. Use `accountedBalance + mintDebt` for `V` instead of `rewardToken.balanceOf(address(this))`. Unsolicited transfers then sit idle until an owner explicitly acknowledges them via `topUp` or a dedicated `sweepDonations()`.

---

### [L-02] `setTargetAPY` settles prior accrual against `totalStaked` that has already been reduced by `emergencyWithdraw`

**Context:** [`NFTStaker.sol#L237-L243`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L237-L243), [`NFTStaker.sol#L452-L461`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L452-L461)

**Description:** `emergencyWithdraw` is the escape hatch and deliberately skips `_syncBudget` / `_updatePool`. It decrements `totalStaked` without advancing `lastRewardTime` or updating `accRewardPerShare`. If no other interaction fires in the interval between an `emergencyWithdraw` and the next `setTargetAPY`, the settlement inside `setTargetAPY`:

```solidity
function setTargetAPY(uint256 newAPY) external onlyOwner {
    require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");
    _updatePool();                              // <-- uses current (post-withdraw) totalStaked
    emit TargetAPYChanged(targetAPY, newAPY);
    targetAPY = newAPY;
    _recomputeSchedule();
}
```

runs `_updatePool` over the full elapsed window using the already-shrunk `totalStaked`, so remaining stakers are credited with a larger `accRewardPerShare` jump for the pre-withdrawal segment than they actually earned. The magnitude is bounded by the emergency-withdrawer's share × elapsed × `rewardRate`.

**Impact:** Minor over-crediting of remaining stakers at the APY-change boundary when an emergency withdrawal has occurred since the last touch. This is a downstream amplification of the core `emergencyWithdraw` accounting issue (M-series) and has no independent attack path: the attacker cannot profitably trigger an emergency-withdraw they did not make themselves.

**Recommendation:** Fix the root cause inside `emergencyWithdraw` by calling `_updatePool()` before decrementing `totalStaked` (the standard masterchef emergency-withdraw shape). That single change makes `setTargetAPY`'s settlement precise again without requiring per-setter rework.

---

### [L-03] `pendingReward` view diverges from the amount `claim` actually pays

**Context:** [`NFTStaker.sol#L467-L478`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L467-L478)

**Description:** `pendingReward(account)` computes an in-memory extension of `accRewardPerShare` using the *stored* `rewardRate`, `windowEnd`, and `rewardBudget`. It does **not** simulate the `dispatcherHook.pull()` that `_syncBudget` performs at the top of every `claim`, nor does it re-run `_recomputeSchedule`. Two divergence patterns follow:

1. **Under-quote on realised inflow:** when `mintDebt()` is nonzero, a subsequent `claim` pulls it, bumps `rewardBudget`, and (via `_recomputeSchedule`) may raise `rewardRate`. The user's paid amount exceeds the `pendingReward` quote.
2. **Over-quote against a depleting budget:** `pendingReward` clamps in-memory `reward` against the *current* `rewardBudget`, but by the time `claim` actually runs, `_updatePool` has further drained it. The UI-quoted value can exceed what `_safePay` has on hand, and `_safePay` reverts the claim with `"NFTStaker: insufficient reward balance"` rather than silently capping.

Because the contract emits `pendingReward` as a public view and the sibling ecosystem exposes it to front-ends, an integrator consuming it as an authoritative "claimable now" figure will display numbers that `claim` cannot reproduce.

**Impact:** UX / integrator consistency only. No principal or reward loss — the mismatch is a display-vs-execution divergence, and `_safePay`'s revert-on-shortfall prevents any silent over/under-payment inside the protocol itself. Front-ends or OTC buy-out counterparties quoting `pendingReward` are systematically off.

**Recommendation:** Either (a) rename the view to `pendingRewardPrePull()` and document the pre-pull semantics, or (b) add a parallel `pendingRewardSimulated()` view that mirrors the mutation path: peek at `dispatcherHook.mintDebt()`, apply the `_recomputeSchedule` math in memory, then re-run the `_updatePool` extension against the simulated post-pull `rewardRate` and `rewardBudget`.

---

## Centralization Risks

### [C-01] `_recomputeSchedule` trusts `dispatcherHook.mintDebt()` as an input to `V`, letting a hostile or buggy hook over-commit emissions

**Context:** [`NFTStaker.sol#L365-L376`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L365-L376), [`NFTStaker.sol#L272-L285`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L272-L285)

**Description:** `V` in the schedule recompute is the sum of the contract's phUSD balance and whatever `dispatcherHook.mintDebt()` returns, with no cross-check against the phUSD actually delivered by the paired `pull()` in `_syncBudget`:

```solidity
uint256 V = rewardToken.balanceOf(address(this));
if (address(dispatcherHook) != address(0)) {
    V += dispatcherHook.mintDebt();
}
```

Nothing in `NFTStaker` validates that the hook's `mintDebt()` reading is fulfilled by `pull()`. An owner who installs a hostile or buggy hook whose `mintDebt()` returns a large number but whose `pull()` transfers little or nothing causes `rewardBudget` and `windowEnd` to inflate against a budget that is never delivered. Stakers accrue against the inflated schedule; once realised balance falls below `pending`, `_safePay` reverts and normal claim flow is bricked until the owner tops up or rotates the hook.

**Impact:** Emission schedule is as trustworthy as the installed hook. A malicious owner (or compromised key) installing a hostile hook can freeze stakers' accrued rewards behind `_safePay` reverts; recovery requires `topUp` or an `emergencyWithdraw` that forfeits the rewards. Principal is never at risk — the escape hatch bypasses `_syncBudget`/`_updatePool` — so this is a classic centralization/supply-chain issue, not an external-attacker vector.

**Recommendation:** Treat the hook's reading as advisory rather than authoritative. Two concrete options:

1. Cap the `mintDebt()` contribution by what the paired `pull()` actually delivers: only credit `V` with the realised `inflow` (`balance_after − balance_before`) from `_syncBudget`, not the reported `mintDebt()`.
2. Keep the peek-based behaviour for the `totalBudget` / `runwaySeconds` views but exclude `mintDebt()` from the `V` used to set `rewardBudget` / `windowEnd` inside `_recomputeSchedule`.

Either change keeps the APY math honest against the *actual* delivered budget rather than a hook-reported promise.

---

### [C-02] `setDispatcherHook` rotates the hook without draining the outgoing one, stranding outstanding `mintDebt` and leaving `rewardBudget` inflated

**Context:** [`NFTStaker.sol#L199-L202`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L199-L202)

**Description:** `setDispatcherHook` is the only config setter without either a `totalStaked == 0` gate or a `_syncBudget`/`_recomputeSchedule` self-heal — sister setters (`setDispatcherIndex`, `setNFTMinter`) carry both guardrails; this one carries neither:

```solidity
function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
    emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
    dispatcherHook = newHook;
}
```

If the owner rotates while the outgoing hook still has outstanding `mintDebt`, three things go wrong simultaneously:

1. The outgoing `mintDebt` is never realised into the staker contract — `NFTStaker` only ever calls `pull()` against the *current* `dispatcherHook`, so after the write the old debt is unreachable from this contract.
2. `rewardBudget` and `windowEnd` remain as they were after the last `_recomputeSchedule`, which folded the now-unreachable `mintDebt` into `V`. Budget is stale-inflated.
3. Subsequent user interactions advance `accRewardPerShare` against the stale budget until `_safePay` starts reverting on claims.

**Impact:** Reward flow bricks between rotation and owner corrective action (`topUp`, or installing a replacement hook with sufficient debt to cover the gap). Principal is preserved — `emergencyWithdraw` remains unaffected — but users who cannot wait forfeit accrued rewards. No external-attacker path; this is an operational footgun that activates on a specific owner action ordering.

**Recommendation:** Drain before rotating, and recompute afterwards:

```solidity
function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
    _syncBudget();                 // drain the outgoing hook and settle accrual
    emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
    dispatcherHook = newHook;
    _recomputeSchedule();          // re-derive V against the new hook's mintDebt
}
```

This matches the discipline already encoded in `setDispatcherIndex`/`setNFTMinter` (self-healing via `_recomputeSchedule`) while preserving `setDispatcherHook`'s intended status as a mid-stake-legal live-ops setter.

---

## QA / State-Hygiene Findings

### [QA-01] Owner can zero emissions mid-stake via `setTargetAPY(0)`

**Context:** [`NFTStaker.sol#L232-L243`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L232-L243)

**Description:** `setTargetAPY` explicitly allows `newAPY == 0`:

```solidity
require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");
_updatePool();
// ...
targetAPY = newAPY;
_recomputeSchedule();
```

With `targetAPY == 0`, `_recomputeSchedule` derives `newRate = 0` and `windowEnd = block.timestamp`. Emissions halt immediately for all existing stakers with no advance notice. The submodule spec (`CLAUDE.md`, Feature Spec item 7) documents this as "`A == 0` is a supported 'pause emissions via APY' mode", so this is by design — but the owner has no counterbalance against it (no timelock, no minimum notice, no escrow).

**Impact:** Centralization / trust risk. No fund loss — rewards already accrued up to the cutover are settled at the old rate by the pre-mutation `_updatePool()` — but the emission rate contract stakers signed up for can be unilaterally zeroed at any time.

**Recommendation:** If the zero-APY pause is to remain, consider (a) a delay / timelock for decreases, or (b) emitting a `TargetAPYChanged` event with a larger `ScheduleRecomputed`-style event that explicitly signals the pause, so integrators and stakers can monitor the policy change.

---

### [QA-02] `setPauser` accepts `address(0)` without validation

**Context:** [`NFTStaker.sol#L182-L185`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L182-L185)

**Description:**

```solidity
function setPauser(address newPauser) external onlyOwner {
    emit PauserChanged(pauser, newPauser);
    pauser = newPauser;
}
```

There is no `require(newPauser != address(0))`. Since `pause()` / `unpause()` are guarded by an `onlyPauser` modifier, setting `pauser = address(0)` silently disables the emergency-pause capability until the owner explicitly re-sets a pauser. Compare to `setNFTMinter`, which does enforce a zero-address check; `setPauser` is inconsistent.

**Impact:** Reckless-admin-mistake class issue. The pause capability is a defensive lever for the protocol; losing it silently blunts incident response.

**Recommendation:**

```solidity
require(newPauser != address(0), "NFTStaker: zero pauser");
```

---

### [QA-03] `setStakedId` does not call `_recomputeSchedule`, leaving `rewardRate` / `windowEnd` stale until the next user interaction

**Context:** [`NFTStaker.sol#L204-L208`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L204-L208)

**Description:** Sister setters `setDispatcherIndex` and `setNFTMinter` both call `_recomputeSchedule()` after their state mutation, so an empty-pool reconfiguration leaves the schedule in a coherent state. `setStakedId` does not:

```solidity
function setStakedId(uint256 newId) external onlyOwner {
    require(totalStaked == 0, "NFTStaker: stake outstanding");
    emit StakedIdChanged(stakedId, newId);
    stakedId = newId;
}
```

Since `T = f(price[stakedId], totalSupply(stakedId), growthBasisPoints)` depends on the staked ID, a change to `stakedId` without a recompute leaves `rewardRate` and `windowEnd` reflecting the *previous* ID's aggregate value until the next user action (or `pullAndRefresh()`) fires `_syncBudget` → `_recomputeSchedule`. Because the function is gated on `totalStaked == 0`, no stakers are mid-accrual at that moment, but any front-end reading `currentRewardRate()` or `runwaySeconds()` between the setter and the first post-migration stake will see stale figures.

**Impact:** View-inconsistency and spec-deviation between sister setters. No fund impact.

**Recommendation:** Add a trailing `_recomputeSchedule();` to `setStakedId`, matching `setDispatcherIndex` and `setNFTMinter`:

```solidity
function setStakedId(uint256 newId) external onlyOwner {
    require(totalStaked == 0, "NFTStaker: stake outstanding");
    emit StakedIdChanged(stakedId, newId);
    stakedId = newId;
    _recomputeSchedule();
}
```

---

### [QA-04] Input-validation gaps on `setDispatcherHook` and `setNFTMinter`

**Context:** [`NFTStaker.sol#L199-L202`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L199-L202), [`NFTStaker.sol#L224-L230`](https://github.com/Behodler/phoenix-nft-staking/blob/66af47d/src/NFTStaker.sol#L224-L230)

**Description:** Admin setters are inconsistent in the validation they apply:

- `setDispatcherHook(IBalancerPoolerMintDebtHook newHook)` has *no* input validation at all — accepts `address(0)` (which the internal path treats as "hook unset and skip `pull()`") and accepts arbitrary arbitrary code as the new hook address with no interface sanity check.
- `setNFTMinter(INFTSupply newMinter)` correctly rejects `address(0)` but does no further sanity check (e.g. that `newMinter.configs(dispatcherIndex)` returns data consistent with the current `dispatcherIndex`).

Setting `dispatcherHook = address(0)` is arguably an intended mode (skip `pull()` entirely), but doing so via `setDispatcherHook` without `_syncBudget` first also triggers the stale-budget issue flagged in **C-02**. More broadly, the asymmetry between sister setters (some enforce `address(0)` check, some don't) makes deployment scripts error-prone.

**Impact:** Admin-misconfiguration class. No external-attacker path.

**Recommendation:** Harmonise validation across the admin setters. At minimum:

- Add an explicit "hook unset" helper (e.g. `unsetDispatcherHook()` that drains first, then sets to zero) and have `setDispatcherHook(newHook)` reject `newHook == address(0)`.
- Have `setNFTMinter` additionally call `_recomputeSchedule()` (it already does) but assert `newMinter.configs(dispatcherIndex)` reverts are caught early via an explicit staticcall probe, so a mis-typed minter is rejected at setter time rather than at the next stake.
