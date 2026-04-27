# QA Report — Phoenix NFT Staking (`NFTStaker.sol`)

Commit reviewed: `b11e49d`. Source file: [`src/NFTStaker.sol`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol).

This bundle collects state-handling, input-validation, runway-predictability, and centralization observations on `NFTStaker.sol`. Findings whose only impact is sub-wei dust, pure code-hygiene, or owner-trust defensive-depth have been omitted in keeping with C4's discouragement of low-effort QA bundles.

## Summary

| Severity              | Count |
|-----------------------|-------|
| Low Risk              | 11    |
| Centralization Risk   | 3     |
| **Total**             | **14**|

| ID    | Title                                                                                                        |
|-------|--------------------------------------------------------------------------------------------------------------|
| L-01  | `_recomputeSchedule` reads `balanceOf(this)` directly, allowing donation griefing to perturb the runway      |
| L-02  | Permissionless `claim()` lets any caller force-realise mint debt on the dispatcher hook                      |
| L-03  | Constructor accepts `dispatcherIndex == 0` without probing `nftMinter.configs(0)`                            |
| L-04  | External NFT mints can accelerate runway depletion via `latestPrice` growth                                  |
| L-05  | `setStakedId` does not call `_recomputeSchedule`; views and event stream report stale values                 |
| L-06  | `setPauser` accepts `address(0)`, silently disabling pause/unpause                                           |
| L-07  | `setDispatcherHook` performs no input validation on the new hook address                                     |
| L-09  | `_recomputeSchedule` on non-pull paths includes unrealised `mintDebt` in `rewardBudget`                      |
| L-10  | View functions (`currentRewardRate` / `runwaySeconds` / `pendingReward`) read stale state without simulation |
| L-11  | `stakedId` is owner-mutable while `totalStaked == 0`; `stake()` can race `setStakedId`                       |
| L-13  | No admin sweep when `totalStaked == 0`; reward residue stranded indefinitely                                 |
| C-01  | `setDispatcherHook` rotation orphans the old hook's outstanding `mintDebt`                                   |
| C-02  | `dispatcherHook.mintDebt()` is trusted input to `V`, `rewardBudget`, and `windowEnd`                         |
| C-03  | Owner can zero emissions mid-stake via `setTargetAPY(0)` or `setDispatcherHook(address(0))`                  |

---

## Low Risk Findings

### [L-01] `_recomputeSchedule` reads `balanceOf(this)` directly, allowing donation griefing to perturb the runway

**Location**: [`NFTStaker.sol#L403`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L403)

**Description**: `_recomputeSchedule` derives `rewardBudget` from `phUSD.balanceOf(address(this))` rather than an internally tracked accounting value. Any actor can transfer phUSD directly to the contract and force the next recompute to extend `windowEnd` by `donation / rewardRate`. The donation becomes irreversibly committed to staker rewards; if all stakers exit (see L-13) the residue is locked. There is no asset theft — the donor pays for the perturbation — but schedule predictability is impacted and rational front-running of `setTargetAPY` becomes possible.

**Recommendation**: Track an internal `accountedBudget` counter that increments on `topUp` / `_syncBudget` and decrements on payouts; consume that value inside `_recomputeSchedule` instead of `balanceOf(this)`.

---

### [L-02] Permissionless `claim()` triggers external `dispatcherHook.pull()` on a cadence the protocol cannot rate-limit

**Location**: [`NFTStaker.sol#L479-L488`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L479-L488)

**Description**: `claim()` invokes `_syncBudget`, which forces `dispatcherHook.pull()` regardless of whether the caller has any stake. A zero-stake griefer can call `claim()` every block, denying the hook side any batching efficiency and amplifying its per-call gas / state-update cost. NFTStaker itself incurs only the griefer's own gas spend, so the impact is operational on the dispatcher side.

**Recommendation**: Either guard `claim()` with `require(stakeOf[msg.sender].amount > 0)` or document and accept the permissionless-refresh property explicitly so dispatcher operators size their hook accordingly.

---

### [L-03] Constructor accepts `dispatcherIndex == 0` without validating against `nftMinter.configs(0)`

**Location**: [`NFTStaker.sol#L187-L203`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L187-L203)

**Description**: The constructor stores `dispatcherIndex` without probing `nftMinter.configs(dispatcherIndex)`. A deployment script that defaults `DISPATCHER_INDEX` to zero produces a silent misconfiguration: depending on the minter's behaviour at index 0, every subsequent stake / unstake / claim either reverts or silently emits zero. The condition is self-healing while `totalStaked == 0` (operator can call `setDispatcherIndex`) but it is a loud failure waiting to happen.

**Recommendation**: Add a constructor `require(dispatcherIndex != 0)` or call `nftMinter.configs(dispatcherIndex)` in the constructor and revert if the result is zero-valued.

---

### [L-04] External NFT mints accelerate runway depletion via `latestPrice` growth without consent of stakers or operator

**Location**: [`NFTStaker.sol#L386-L396, L401, L416-L418`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L386-L396)

**Description**: When `growthBasisPoints > 0`, `latestPrice` is a monotonically non-decreasing function of dispatcher mint activity. An adversary willing to pay mint costs at the dispatcher pushes `latestPrice` upward; the next on-chain interaction triggers `_recomputeSchedule` with a higher `rewardRate`, collapsing `windowEnd = now + budget / R`. Existing stakers benefit from the higher absolute emissions, so they are not griefed; only the operator's runway planning is impacted. With `growthBasisPoints == 0` the surface vanishes.

**Recommendation**: Document the dependency between mint cadence and runway, or cap the `latestPrice` delta consumed between recomputes so adversarial bursts cannot collapse the runway.

---

### [L-05] `setStakedId` does not call `_recomputeSchedule`; off-chain consumers see stale schedule data until the next interaction

**Location**: [`NFTStaker.sol#L231-L235`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L231-L235)

**Description**: Sister setters `setDispatcherIndex` and `setNFTMinter` both end with a `_recomputeSchedule()` call (which emits `ScheduleRecomputed`). `setStakedId` does not. Off-chain indexers driven by that event continue to attribute the prior `stakedId` to subsequent reward accrual until the next stake / unstake / claim / `pullAndRefresh`. There is no on-chain asset impact; the issue is a state-machine asymmetry that breaks the implicit invariant "schedule reflects current config once the setter returns."

**Recommendation**: Append `_recomputeSchedule()` to `setStakedId` to mirror the sister setters and fire `ScheduleRecomputed` on the configuration boundary.

---

### [L-06] `setPauser` accepts `address(0)` without validation, silently disabling pause/unpause capability

**Location**: [`NFTStaker.sol#L209-L212`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L209-L212)

**Description**: `setPauser` does not validate that the new pauser address is non-zero. A miscoded deployment script or a fat-fingered governance call sets the pauser to `address(0)`, silently removing the emergency pause capability until the owner notices and re-sets it. If a separately discovered vulnerability requires emergency pause during that window, the protocol cannot mitigate.

**Recommendation**: Add `require(newPauser != address(0), "pauser=0")`, or document `address(0)` as an explicit "pause disabled" mode if intentional.

---

### [L-07] `setDispatcherHook` lacks input validation; an EOA or wrong-interface address freezes core flows

**Location**: [`NFTStaker.sol#L226-L229`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L226-L229)

**Description**: `setDispatcherHook` accepts any address with no zero-check, no contract-existence probe, and no interface-conformance check. Installing an EOA, a wrong-network address, or an unrelated contract causes every subsequent `stake` / `unstake` / `claim` to revert at `dispatcherHook.pull()` (or at `dispatcherHook.mintDebt()` inside `_recomputeSchedule`). Users have no path forward except `emergencyWithdraw` (which forfeits pending rewards) until the owner re-sets the hook. Combined with C-01, the freeze window widens whenever hook rotation is fumbled.

**Recommendation**: Validate that `newHook` is a contract (`code.length > 0`), and probe a `staticcall` to `mintDebt()` before persisting the new value. Mirror the `_syncBudget` + `_recomputeSchedule` pattern of the sister setters so the rotation does not orphan state (see C-01).

---

### [L-09] `_recomputeSchedule` on non-pull paths sets `rewardBudget` to a value that includes unrealised `mintDebt`

**Location**: [`NFTStaker.sol#L385-L425`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L385-L425)

**Description**: `topUp`, `setTargetAPY`, `setDispatcherIndex`, and `setNFTMinter` end with `_recomputeSchedule()` directly rather than `_syncBudget()`. The recompute reads `mintDebt` and sets `rewardBudget = balance + mintDebt - committedDebt` without first realising the debt via `pull()`. If dispatcher-hook health degrades between this call and the next `_syncBudget`, stakers accrue against an inflated budget, the next `_syncBudget` pulls less than projected, and subsequent claims revert at `_safePay`. Closely related to C-02; recovery requires owner `topUp`.

**Recommendation**: Couple `topUp`, `setTargetAPY`, `setDispatcherIndex`, and `setNFTMinter` to `_syncBudget()` rather than the bare `_recomputeSchedule()`, so that `mintDebt` is realised before being booked into `rewardBudget`.

---

### [L-10] View functions read stored state without simulating a recompute, diverging from what the next interaction will pay

**Location**: [`NFTStaker.sol#L567-L620`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L567-L620)

**Description**: `currentRewardRate`, `runwaySeconds`, and `pendingReward` consume the cached `rewardRate` / `accRewardPerShare` rather than simulating `_syncBudget` + `_recomputeSchedule`. When dispatcher `mintDebt` or `latestPrice` has changed since the last on-chain interaction, these views report values that are inconsistent with what `claim()` will actually pay. Front-ends and integrators consuming the views as authoritative experience a UX gap, but no on-chain asset impact.

**Recommendation**: Document the staleness semantics in NatSpec, or expose simulated-view variants that fold the latest `mintDebt` and `latestPrice` into the projection.

---

### [L-11] `stakedId` is owner-mutable while `totalStaked == 0`; user `stake()` transactions can race `setStakedId`

**Location**: [`NFTStaker.sol#L71, L231-L235, L431-L456`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L431-L456)

**Description**: During a `setStakedId` migration (e.g., NFT v1 to v2), a user broadcasting a `stake()` transaction expecting the prior `stakedId` can be front-run by the owner's `setStakedId(newId)`. Because `setApprovalForAll` typically covers all token ids on a single ERC1155, the user's `stake()` then succeeds against `newId`, locking units of an unintended token. Recoverable via `unstake()`; no principal loss.

**Recommendation**: Add an `expectedStakedId` parameter to `stake()` and revert on mismatch, or document the race condition with off-chain coordination guidance during migrations.

---

### [L-13] Reward tokens left in the contract when `totalStaked` drops to zero are non-recoverable

**Location**: [`NFTStaker.sol`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol) — no admin sweep function

**Description**: The contract has no owner-only sweep path. When all stakers exit (via `unstake` or `emergencyWithdraw`), any phUSD residue — pre-exit `committedDebt` forfeited by `emergencyWithdraw` users plus donation residue from L-01 — remains stranded unless new stakers arrive. There is no theft, only a fund-recovery gap on pool sunset / migration.

**Recommendation**: Add an owner-only sweep function gated by `require(totalStaked == 0)`, or document indefinite-operation as an explicit deployment assumption so operators understand the lock-in.

---

## Centralization Risks

### [C-01] `setDispatcherHook` rotation orphans the old hook's outstanding `mintDebt`, leaving `rewardBudget` stale

**Location**: [`NFTStaker.sol#L226-L229`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L226-L229)

**Description**: `setDispatcherHook(newHook)` overwrites the hook reference without first calling `_syncBudget` against the old hook (to realise its outstanding `mintDebt = M`) and without calling `_recomputeSchedule` against the new hook. The prior recompute had set `rewardBudget = V - committedDebt` with `V` including `M`. After rotation, `M` is orphaned: stakers continue accruing against an inflated `rewardBudget`, `committedDebt` grows against value the contract no longer expects to receive, and a subsequent `claim()` eventually reverts in `_safePay` with "insufficient reward balance". Recovery requires owner `topUp`, rotating back to the old hook (if still callable), or installing a hook with sufficient `mintDebt` to cover the gap.

**Impact**: Reward-claim DoS for the window between the rotation and corrective owner action. Stakers forced onto `emergencyWithdraw` forfeit pending rewards. No principal theft.

**Recommendation**: Mirror the sister setters: call `_syncBudget()` against the old hook before overwriting, and `_recomputeSchedule()` against the new hook after. Optionally surface a `bool drainBeforeRotate` parameter for clarity.

---

### [C-02] `dispatcherHook.mintDebt()` is trusted input to `V`, `rewardBudget`, and `windowEnd`

**Location**: [`NFTStaker.sol#L403-L406`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L403-L406)

**Description**: `_recomputeSchedule` consumes `dispatcherHook.mintDebt()` directly into `V` and `rewardBudget`, then extends `windowEnd` accordingly. A buggy or hostile hook that returns a `mintDebt()` value larger than what `pull()` actually delivers causes `_updatePool` to advance `accRewardPerShare` against an inflated budget; the eventual `claim()` reverts in `_safePay` on shortfall. This is fundamentally a trust assumption on the owner-set dispatcher hook — the contract intentionally trusts the hook — but the failure mode is more severe than a typical input-validation footgun (full reward-claim DoS plus runway distortion), so it is worth surfacing.

**Impact**: Reward-claim DoS until owner topUp / hook replacement. Principal recoverable via `emergencyWithdraw` (with reward forfeit).

**Recommendation**: Either (a) reconcile the next `_syncBudget` against the realised `pull()` delta — track `prevMintDebt` and verify the balance increment matches before extending the runway — or (b) document explicitly that the dispatcher hook is in the same trust domain as the owner and require a deployment-time hook audit.

---

### [C-03] Owner can zero emissions mid-stake via `setTargetAPY(0)` or `setDispatcherHook(address(0))`

**Location**: [`NFTStaker.sol#L226-L229, L264-L270`](https://github.com/Behodler/phoenix-nft-staking/blob/b11e49d/src/NFTStaker.sol#L264-L270)

**Description**: Stakers commit NFTs based on a published `targetAPY` and runway. The owner can collapse future emissions to zero with no notice, no timelock, and no on-chain veto by calling `setTargetAPY(0)` (a documented "pause emissions via APY" mode) or `setDispatcherHook(address(0))` (which makes every subsequent recompute revert). Already-settled `committedDebt` remains claimable, but advertised future yield is gone. Per-spec behaviour rather than a code bug.

**Impact**: No theft; principal recoverable. Stakers lose advertised future APY without recourse.

**Recommendation**: Apply a timelock (e.g., 48 hours) to `setTargetAPY` and `setDispatcherHook` reductions, or enforce monotonicity on `targetAPY` decreases below a published floor. At minimum, document the unilateral emissions-pause power prominently in user-facing materials so stakers price the centralization risk in.
