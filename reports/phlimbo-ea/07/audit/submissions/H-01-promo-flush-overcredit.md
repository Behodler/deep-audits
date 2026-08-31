<!--
ID: pe7h1
C4 Submission Metadata
Title: [H-01] Permissionless collectReward advances promo accumulator during Flushing, over-crediting phantom pending promo that steals co-stakers' tokens or bricks claims
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L559-L573
PoC File: PromoFlushAccrualPoC.t.sol
Severity: High (Plausible-High)
-->

## Finding description and impact

### Summary

During the Promo **Flushing** phase, `PhlimboV3` pauses the contract so that staker membership and accumulators are frozen while `batchClaim` settles every staker's promo balance. However, `collectReward(uint256)` — [`src/PhlimboV3.sol:559`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L559) — is `external nonReentrant` with **no** `onlyOwner` guard and **no** `whenNotPaused` guard. Any unprivileged address can therefore call it during the flush window, and it invokes `_updatePool()` at [`src/PhlimboV3.sol:563`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L563), which advances `accPromoPerShare` at [`src/PhlimboV3.sol:759`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L759).

Because the accumulator is advanced **after** `batchClaim` has already aligned each staker's `promoDebt` to the pre-advance accumulator, the gap between the newly-advanced `accPromoPerShare` and the aligned `promoDebt` becomes **phantom pending promo** that survives `finalizePromotion` (which deliberately retains the accumulator; [`src/PhlimboV3.sol:481`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L481)). That phantom credit then applies against the **next** promotion's token.

> This is DISTINCT from the acknowledged Linear-Depletion rate-recompute grief (ledger M-04). M-04 concerns `rewardPerSecond`/`promoRewardPerSecond` being re-anchored by user interactions. This finding is a separate defect: the **promo accumulator (`accPromoPerShare`) is advanced during the Flushing phase**, when the design assumes it is frozen. The recompute discipline is irrelevant here — even with a perfectly stable rate, a single permissionless `collectReward` during flush injects phantom pending promo.

### Vulnerability details

The intended invariant (documented at [`src/PhlimboV3.sol:29-34`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L29) and [`src/PhlimboV3.sol:413`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L413)) is that once `beginFlush` pauses the contract, `accPromoPerShare` cannot advance because all mutating operations (`stake`/`withdraw`/`claim`) are `whenNotPaused`. `batchClaim` relies on this: it pays out each staker's pending promo and sets `promoDebt = amount * accPromoPerShare / PRECISION` ([`src/PhlimboV3.sol:452-456`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L452)), leaving every staker with exactly zero pending — provided the accumulator does not move afterward.

`collectReward` breaks that assumption:

1. `beginFlush()` pauses the contract and sets `promoPhase = Flushing` ([`src/PhlimboV3.sol:418-425`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L418)).
2. Owner runs `batchClaim`, zeroing every staker's pending promo and aligning `promoDebt` to the current `accPromoPerShare`.
3. **Any address** calls `collectReward(x)`. Despite the pause, it is not `whenNotPaused`-gated, so it proceeds and calls `_updatePool()`. With `promoToken != address(0)` and `timeElapsed > 0`, `accPromoPerShare` advances at [`src/PhlimboV3.sol:759`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L759).
4. Now every staker has phantom pending = `amount * (accPromoPerShare_new - accPromoPerShare_aligned) / PRECISION`, and no further `batchClaim` reconciles it before `finalizePromotion`.
5. `finalizePromotion` retains `accPromoPerShare` (by design), so the phantom pending **carries into the next promotion**, denominated in the next promo's token.

The same accrual site is also reachable during flush through the owner-only triggers `setDepletionDuration` and `setDesiredAPY` (each calls `_updatePool` while paused), so gating `collectReward` alone would not fully close the defect.

### Impact

Both outcomes are proven by the PoC and are pool-size dependent:

- **THEFT (phantom pending survives into the next promo).** In the PoC, a 100,000-token / 7-day promo collected 3 days into the flush window yields a phantom pending of `42,857142857142857142000` (≈42,857e18) for the beneficiary. That credit survives `finalizePromotion` and is claimable against a **brand-new** partner token in promotion #2 — with **zero stake time** in promotion #2. The beneficiary drains `42,857e18` of the new partner's tokens, directly stealing honest co-stakers' share of the new promo.

- **DoS (claim bricked).** When the phantom credit exceeds the next promo's funded pool, the victim's `claim` reverts with `ERC20InsufficientBalance`, freezing legitimate promo distribution for the affected staker(s).

Assets belonging to honest co-stakers are directly stolen (or their claims bricked) via a permissionless call, with no extraordinary preconditions beyond a live flush window — hence **High (Plausible-High)**.

## Proof of Concept

Two passing tests demonstrate both the theft and the DoS variant.

Location: `workspace/phlimbo-ea/test/invariant/PromoFlushAccrualPoC.t.sol`

Reproduce:

```bash
cd workspace/phlimbo-ea && forge test --match-contract PromoFlushAccrualPoC -vvv
```

- `test_collectReward_during_flush_breaks_zero_pending_and_solvency` — proves that a permissionless `collectReward` during flush injects phantom pending that survives into the next promo and is claimed against the new partner token with zero stake time in that promo.
- `test_flush_accrual_overcredits_beyond_next_promo_pool` — proves the phantom credit can exceed the next promo's funded pool, reverting the victim's `claim` with `ERC20InsufficientBalance`.

Output:

```
Ran 2 tests for test/invariant/PromoFlushAccrualPoC.t.sol:PromoFlushAccrualPoC
[PASS] test_collectReward_during_flush_breaks_zero_pending_and_solvency() (gas: 656206)
Logs:
  phantom pending promo while phase==None: 42857142857142857142000
  alice pending against BRAND-NEW promo token at t=0: 42857142857142857142000
  partner2 tokens claimed with zero time in promo #2: 42857142857142857142000

[PASS] test_flush_accrual_overcredits_beyond_next_promo_pool() (gas: 633738)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.76ms (769.56µs CPU time)

Ran 1 test suite in 1.41s: 2 tests passed, 0 failed, 0 skipped (2 total tests)
```

The key log lines confirm the impact: the beneficiary carries a phantom pending of `42857142857142857142000` while `promoPhase == None`, that same figure is claimable against the brand-new promo #2 token at `t=0` (zero stake time), and `42857142857142857142000` of `partner2`'s tokens are drained.

## Recommended mitigation steps

Freeze the promo accrual stream during the Flushing phase at its source. Gate the accumulator advance in `_updatePool` on the promo phase:

```solidity
// src/PhlimboV3.sol, in _updatePool (~L753)
if (address(promoToken) != address(0) && promoPhase != PromoPhase.Flushing) {
    uint256 potentialPromo = (promoRewardPerSecond * timeElapsed) / PRECISION;
    uint256 promoToDistribute =
        potentialPromo > promoRewardBalance ? promoRewardBalance : potentialPromo;

    if (promoToDistribute > 0) {
        accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;
        promoRewardBalance -= promoToDistribute;
    }
}
```

Gating at the accrual site (rather than only adding `whenNotPaused` to `collectReward`) is preferred because it also neutralizes the secondary owner-only triggers (`setDepletionDuration`, `setDesiredAPY`) that reach `_updatePool` while paused. Adding `whenNotPaused` to `collectReward` alone would close the permissionless path but leave those owner-only accrual paths open.

Note the phUSD/stable stream (`accPhUSDPerShare`) is intentionally paused by the existing `whenNotPaused` gating on user operations; the promo stream needs the explicit phase check because `collectReward` and the owner setters bypass the pause guard.
