<!--
ID: pns16m2
C4 Submission Metadata
Title: [M-02] `emergencyWithdraw` leaves `rewardRate` sized for the pre-exit pool, over-emitting the reward budget to surviving stakers
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L538-L561
PoC File: poc-M02-EmergencyWithdrawOverEmission.t.sol
Ledger Fingerprint: 911c54fd6d1bb7c2d6a228ab674bd8954bf466aa9232527ed0594b0f029e5a70
Spec-Conformance Cross-Ref: F-01 (submissions/spec-conformance.md)
-->

## Finding description and impact

### Summary

`NFTStaker.emergencyWithdraw` ([`NFTStaker.sol#L538-L561`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L538-L561)) is the masterchef escape hatch. It decrements `totalStaked` at [`NFTStaker.sol#L545`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L545) but calls **neither `_updatePool` nor `_recomputeSchedule`**, and never advances `lastRewardTime`.

The emission rate is sized closed-form as `R = totalStaked * latestPrice * targetAPY / SECONDS_PER_YEAR`, so it scales **linearly** with `totalStaked`. Because the emergency exit shrinks `totalStaked` without re-sizing `R`, `rewardRate` is left sized for the **pre-exit (larger)** pool while the staked subset has collapsed. The next `_updatePool` — fired by any later `stake` / `unstake` / `claim` (via `_syncBudget`), or by `topUp` / `setTargetAPY` — settles `elapsed * R_old` over the **smaller** `totalStaked`, inflating `accRewardPerShare` for the survivors by exactly `oldTotal / newTotal` across the whole `[lastRewardTime, now]` window.

This re-introduces the **participation multiplier** that the M-03 "no participation multiplier" Critical Invariant explicitly forbids: survivors earn `oldTotal/newTotal` more per NFT than the `targetAPY` policy authorizes, draining the real phUSD reward budget and collapsing the runway. The PoC demonstrates a **100x** over-emission.

### Relationship to the documented escape-hatch design (this is not the known issue)

The project documents that `emergencyWithdraw` "skips `_syncBudget`/`_updatePool`" **by design**, so that a broken dispatcher hook / NFT minter / recompute path can never trap user principal (see the spec checklist item 1 and the NatSpec at [`NFTStaker.sol#L523-L537`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L523-L537)). That known design point is about **two intended properties**: (a) the *exiting* user forfeits their own pending reward, and (b) the principal return must be robust to a reverting external call. Both of those hold and are correct.

The defect reported here is a **distinct, non-obvious second-order consequence** that the documented design does *not* cover: skipping the recompute leaves the emission rate `R` stale-high, so it over-pays **everyone who remains staked**. The forfeit-recycling NatSpec at L529-537 reasons only about the strong solvency invariant `balance == rewardBudget + committedDebt` (which does hold); it never addresses the fact that the un-resized `R` now distributes the budget at up to `oldTotal/newTotal` times the policy rate. A competent, non-malicious operator reading "emergencyWithdraw skips `_updatePool` so principal is never trapped" would be **surprised** to learn that a large emergency exit silently gifts the surviving stakers a runway-draining windfall and breaks a stated Critical Invariant. That surprise is the footgun.

Crucially, the fix does not require re-coupling the principal return to the external `pull()` call. `_updatePool` is storage-only — it settles accrual and advances `lastRewardTime` with no external transfers — and the rate resize can be done with pure arithmetic (no external calls at all), so the over-emission can be closed while fully preserving the escape-hatch guarantee (see Recommended mitigation steps).

### Vulnerability details

The sibling state-mutating functions both re-size `R` *after* mutating `totalStaked`, precisely to keep the rate matched to the staked subset:

```solidity
// stake() — NFTStaker.sol#L446-L455
user.amount += amount;
totalStaked += amount;
user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;
emit Staked(msg.sender, amount);
// Tail (audit M-03): R scales linearly with `totalStaked`, so re-size R
// against the post-mutation pool.
_recomputeSchedule();

// unstake() — NFTStaker.sol#L468-L476
user.amount -= amount;
totalStaked -= amount;
user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;
stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
emit Unstaked(msg.sender, amount);
// Tail (audit M-03): without this, an unstake leaves R sized for the OLD
// larger pool and the remaining stakers over-collect until the next interaction.
_recomputeSchedule();
```

`emergencyWithdraw` performs the identical `totalStaked -= amount` mutation but omits both the head `_syncBudget`/`_updatePool` and the tail `_recomputeSchedule`:

```solidity
// emergencyWithdraw() — NFTStaker.sol#L538-L561
function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = users[msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "NFTStaker: nothing to withdraw");
    uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    user.amount = 0;
    user.rewardDebt = 0;
    totalStaked -= amount;                 // <-- L545: pool shrinks, R NOT resized
    if (pending > 0) {
        uint256 forfeit = pending > committedDebt ? committedDebt : pending;
        committedDebt -= forfeit;
        rewardBudget += forfeit;
    }
    stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
    emit EmergencyWithdrawn(msg.sender, amount);
    // <-- NO _updatePool(); NO _recomputeSchedule(); lastRewardTime not advanced
}
```

Note that the unstake tail-recompute comment itself states the failure mode verbatim — "without this, an unstake leaves R sized for the OLD larger pool and the remaining stakers over-collect until the next interaction." `emergencyWithdraw` is exactly that missing-recompute case, with one aggravating difference: `lastRewardTime` is also not advanced, so the stale-high `R` is applied retroactively across the *entire* elapsed window at the next settlement, not merely going forward.

Attack path / exposure:

1. A staker calls `emergencyWithdraw`, decrementing `totalStaked` (L545) with no `_updatePool` and no `_recomputeSchedule`. `rewardRate` remains sized for the pre-exit pool; `lastRewardTime` is unchanged.
2. Time elapses with no interaction that would trigger a recompute (any `stake` / `unstake` / `claim` / `topUp` / `setTargetAPY` would resize `R` and halt the over-rate).
3. The next `_updatePool` settles `elapsed * R_old` over the now-smaller `totalStaked`, inflating `accRewardPerShare` for survivors by `oldTotal / newTotal` across `[lastRewardTime, now]`.

Two variants:

- **(a) Non-malicious value leak.** *Any* legitimate large emergency exit (e.g. an ID-migration escape, or a whale bailing through the hatch) silently over-emits to whoever remains staked and breaks the documented APY-as-policy floor. No attacker is required.
- **(b) Self-profit at zero net capital cost.** An attacker stakes a large position with **recoverable** capital plus a small side position. They `emergencyWithdraw` the large position — principal is returned in full by the escape hatch — leaving `R` sized for the whole (now-exited) pool while only the tiny side position remains staked. After an inactivity window the side position `claim`s rewards sized for the entire former pool. The attacker keeps the recovered principal *and* the inflated rewards.

### Impact

This is a **value leak of the protocol reward budget** (real phUSD allocated for emissions), redistributed to whoever is staked during the stale-rate window. It is:

- **Not principal theft.** `emergencyWithdraw` returns the exiting user's principal in full (PoC: 990/990 NFTs returned).
- **Not insolvency.** The strong solvency invariant `balance == rewardBudget + committedDebt` holds throughout (PoC-confirmed). The total settled into `accRewardPerShare` is hard-clamped to the remaining `rewardBudget` by `_updatePool`'s `if (reward > rewardBudget) reward = rewardBudget;` ([`NFTStaker.sol#L329`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L329)), so the stale-high rate over-distributes the *budgeted* phUSD rather than minting beyond it. As a separate backstop, `_safePay` reverts on a genuine balance shortfall ([`NFTStaker.sol#L509-L521`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L509-L521)).

What is lost is the protocol's **reward runway** — in-motion emissions intended for future stakers under the `targetAPY` policy — captured instead by the survivors of the stale-rate window. Who loses: the reward budget / protocol runway / future stakers' intended emissions. Who gains: whoever is staked while the rate is stale.

Severity is **Medium**. The no-hypothetical slice (a single block of over-emission immediately after the exit) is dust-scale. The dramatic, runway-draining outcome — and the self-profit escalation — requires a **post-exit inactivity window** the actor cannot guarantee (any interleaved interaction recomputes `R` and halts the over-rate). This squarely matches the C4 Medium definition: a value leak with stated assumptions and an external requirement, breaking a stated Critical Invariant via a core, expected-to-be-used function, without principal theft or insolvency.

This is the security face of spec-conformance finding **F-01** (`submissions/spec-conformance.md`): the same root cause breaks the M-03 "no participation multiplier" Critical Invariant. F-01 is the faithfulness cross-reference; severity is governed by this submission.

### Proof of Concept

A runnable Foundry PoC using the project's `NFTStaker` and the project mocks is provided. Both tests are written **green** — they pass by asserting the vulnerable outcome is present, so they double as a stable regression artifact and a fix-detector (the assertions flip once the schedule is resized inside `emergencyWithdraw`).

- `test_M02_emergencyWithdraw_inflatesSurvivorEmission` — variant (a): a large exit shrinks `totalStaked` 1000 → 10; `rewardRate` is left untouched and is therefore 100x stale-high vs the policy rate for the shrunken pool; the surviving stake realizes 100x the APY policy cap over the window; solvency still holds.
- `test_M02_selfProfit_recoverPrincipalThenSidecarDrains` — variant (b): the attacker recovers 100% of the whale principal via the escape hatch, then the tiny side position drains rewards sized for the whole exited pool at a 100x self-profit factor; solvency still holds.

Run:

```
cd workspace/phoenix-nft-staking && forge test --match-path test/poc-M02-EmergencyWithdrawOverEmission.t.sol -vv
```

Exact output:

```
Ran 2 tests for test/poc-M02-EmergencyWithdrawOverEmission.t.sol:M02EmergencyWithdrawOverEmissionPoCTest
[PASS] test_M02_emergencyWithdraw_inflatesSurvivorEmission() (gas: 400419)
Logs:
  totalStaked before EW          : 1000
  totalStaked after  EW          : 10
  rewardRate before EW           : 951293759512937
  rewardRate after  EW (stale)   : 951293759512937
  policy rewardRate for new pool : 9512937595129
  rate inflation factor (x)      : 100
  minnow staked units            : 10
  elapsed seconds                : 100
  minnow pendingReward (view)    : 95129375951293700
  minnow realized payout (phUSD) : 95129375951293700
  M-03 policy cap for window     : 951293759512900
  over-emission factor (x)       : 100

[PASS] test_M02_selfProfit_recoverPrincipalThenSidecarDrains() (gas: 393267)
Logs:
  whale principal recovered (NFT): 990
  rate sized for whole pool      : 951293759512937
  honest sidecar baseline (cap)  : 951293759512900
  parasite sidecar realized      : 95129375951293700
  self-profit factor (x)         : 100

Suite result: ok. 2 passed; 0 failed; 0 skipped
```

The numbers confirm the root cause precisely:

- `rewardRate` is **unchanged** by `emergencyWithdraw` (`951293759512937` before and after), while the policy rate for the shrunken pool is `9512937595129` — exactly **100x** stale (`oldTotal/newTotal = 1000/10`).
- Over the 100-second window the surviving stake realizes `95129375951293700` phUSD against an APY policy cap of `951293759512900` — a **100x** over-emission.
- In the self-profit variant the attacker recovers the full 990-NFT principal and the side position out-earns the honest baseline by **100x** at zero net capital cost.
- The solvency assertion `balance == rewardBudget + committedDebt` passes in both tests — this is a value leak, not a theft or insolvency.

## Recommended mitigation steps

Settle accrual and re-size the schedule **inside `emergencyWithdraw`, after the `totalStaked` decrement**, mirroring the `unstake` head+tail pattern — while preserving the escape-hatch guarantee that principal is always returned even if the schedule machinery reverts.

Two things must change: the in-flight accrual must be settled at the old rate so survivors cannot collect it retroactively, and `rewardRate` must be re-sized to the post-exit pool. The critical constraint is that **neither step may introduce an external call that could revert and trap principal** — that robustness is the whole point of the escape hatch.

The two helpers differ sharply on this point, so they cannot be treated the same way:

- `_updatePool` ([`NFTStaker.sol#L320-L336`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L320-L336)) is **storage-only**: it banks accrual into `accRewardPerShare`, moves it from `rewardBudget` to `committedDebt`, and advances `lastRewardTime`, with no external calls. It is therefore safe to call **unconditionally** inside `emergencyWithdraw` — it can never revert on a broken hook/minter and so can never trap principal. It must run **before** the `totalStaked -= amount` decrement, so the elapsed window is settled over the pool that actually earned it (calling it after the decrement would divide the banked reward by the *smaller* pool, re-introducing the very over-credit this finding describes).
- `_recomputeSchedule` ([`NFTStaker.sol#L385-L425`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L385-L425)) is **not** pure arithmetic: it makes three external view calls — `nftMinter.configs(dispatcherIndex)` ([L386](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L386)), `rewardToken.balanceOf(address(this))` ([L403](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L403)), and `dispatcherHook.mintDebt()` ([L405](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L405)). Inlining it bare would let a broken minter or hook revert the whole call and **trap principal** — the exact failure the escape-hatch design exists to prevent. So the rate resize must not call it on the unguarded path.

**Primary recommendation — pure-arithmetic resize (no external calls).** Because `R` scales linearly with `totalStaked`, the rate can be downscaled with a closed-form identity that touches no external contract. This is the only truly external-call-free option, so it best preserves the escape-hatch guarantee:

```solidity
function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = users[msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "NFTStaker: nothing to withdraw");

    _updatePool();                       // storage-only: settle accrual at the OLD rate
                                         // over the OLD pool, advance lastRewardTime
    uint256 oldTotalStaked = totalStaked;

    uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    user.amount = 0;
    user.rewardDebt = 0;
    totalStaked -= amount;               // pool shrinks

    // Pure-arithmetic rate resize — NO external calls, cannot trap principal.
    rewardRate = totalStaked == 0 ? 0 : rewardRate * totalStaked / oldTotalStaked;

    if (pending > 0) {                    // existing forfeit accounting, unchanged
        uint256 forfeit = pending > committedDebt ? committedDebt : pending;
        committedDebt -= forfeit;
        rewardBudget += forfeit;
    }
    stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "");
    emit EmergencyWithdrawn(msg.sender, amount);
}
```

This removes the retroactive over-settlement (via storage-only `_updatePool`) and the participation multiplier (via the linear rate downscale) while making **no external call at all** — so the escape-hatch robustness guarantee is fully preserved.

**Alternative — guarded full recompute.** If a full `_recomputeSchedule` is preferred (e.g. to also refresh `rewardBudget`/`windowEnd` from live `V`), it must be wrapped in `try/catch` so that a reverting minter/hook falls back to simply returning principal:

```solidity
_updatePool();                 // storage-only, unconditional
totalStaked -= amount;
// ... forfeit accounting, principal transfer, event — all unconditional ...
try this.afterEmergencyResize() {} catch {}   // external-call path, guarded

function afterEmergencyResize() external {
    require(msg.sender == address(this), "internal");
    _recomputeSchedule();      // makes external view calls; may revert, caught above
}
```

The trade-off: if the recompute reverts, the `catch` swallows it and `rewardRate` is left **unresized** — the over-emission persists for that exit (principal is still returned). The pure-arithmetic primary form has no such failure mode: it always resizes. Prefer the primary form; use the guarded recompute only if refreshing budget/window from live `V` is also required.

In both cases: keep the principal return and forfeit accounting unconditional (escape-hatch guarantee), settle via storage-only `_updatePool` before the decrement, and re-size `rewardRate` against the post-exit pool so survivors are paid at the policy rate the M-03 invariant requires.

### References

- Root cause — `emergencyWithdraw`: [`src/NFTStaker.sol#L538-L561`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L538-L561)
- Missing recompute on the decrement: [`src/NFTStaker.sol#L545`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L545)
- Correct `stake` tail-recompute (comparison): [`src/NFTStaker.sol#L446-L455`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L446-L455)
- Correct `unstake` tail-recompute (comparison): [`src/NFTStaker.sol#L468-L476`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L468-L476)
- Budget clamp on settlement (`if (reward > rewardBudget) reward = rewardBudget;`): [`src/NFTStaker.sol#L329`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L329)
- `_updatePool` (storage-only; safe to call inside `emergencyWithdraw`): [`src/NFTStaker.sol#L320-L336`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L320-L336)
- `_recomputeSchedule` (makes external view calls — `nftMinter.configs` L386, `rewardToken.balanceOf` L403, `dispatcherHook.mintDebt` L405): [`src/NFTStaker.sol#L385-L425`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L385-L425)
- Balance-shortfall revert (`_safePay` reverts on shortfall): [`src/NFTStaker.sol#L509-L521`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L509-L521)
- Spec-conformance cross-reference (M-03 invariant violated): F-01 in `submissions/spec-conformance.md`
- PoC: `workspace/phoenix-nft-staking/test/poc-M02-EmergencyWithdrawOverEmission.t.sol`
