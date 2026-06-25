# Fix Plan — M-01 / F-18-01: NFTStakerDepletion linear-depletion rate-drift

**Status:** acknowledged, will-fix
**Finding:** M-01 (`pns18m1`) / spec-conformance F-18-01
**Contract:** `src/NFTStakerDepletion.sol` @ `24acff8`
**Severity:** Medium (solvency-safe; misallocation/timing, not theft)

> **Note:** `lib/` is a read-only audit reference. Apply this in the upstream
> `NFTStaking` submodule (TDD: red → green → refactor). The PoC lives in
> `workspace/phoenix-nft-staking/test/PoC_DepletionRateDrift.t.sol`.

---

## Root cause (recap)

`_recomputeSchedule()` (L513–534) re-derives the budget-driven rate and
**resets the deadline** on every call:

```solidity
rewardRate = budget / windowSeconds;          // re-derived against the SHRUNKEN budget
windowEnd  = block.timestamp + windowSeconds;  // fresh FULL window from "now"  (L530)
```

Because the depletion rate depends on the *remaining* budget, re-running this
on an interaction that did **not** change the budget re-spreads the leftover
over a fresh full window → geometric decay, deadline never arrives, ~37% of the
budget is perpetually deferred (PoC: active staker receives 63.26% vs a passive
staker's ~100%). Unlike the parent `NFTStaker`, whose rate `S·APY/Y` is
budget-independent and therefore safe under repeated recompute.

It fires on **every** interaction through three paths:

1. `_syncBudget` (L423–436) calls `_recomputeSchedule()` **unconditionally** —
   the `if (inflow > 0)` check at L433 gates only the `Pulled` **event**, not the
   recompute. The no-hook branch (L426) recomputes too.
2. `stake` tail — `_recomputeSchedule()` at **L565**.
3. `unstake` tail — `_recomputeSchedule()` at **L585**.

## Agreed design intent

A **non-zero `pull` inflow means a new NFT was minted** → the budget genuinely
grew → **restarting the window (`windowEnd = now + windowSeconds`) is correct and
intended.** So we keep the full-window reset on a real budget change; we only
stop recomputing when **nothing changed the budget.**

Recompute (and the deadline reset) should fire **only** on a genuine
budget/window change: a non-zero `pull`, `topUp`, `setDepletionWindow`, or a
reward-token `rescueERC20`. Never on a bare stake/unstake/claim.

---

## Changes

### 1. Gate the `_syncBudget` recompute on actual inflow (L423–436)

Only recompute when the pull brought in funds. Keep `_updatePool()` unconditional
(it settles accrual and never touches `rewardRate`/`windowEnd`).

```solidity
function _syncBudget() internal {
    _updatePool();                                 // always: settle accrual
    if (address(dispatcherHook) == address(0)) {
        return;                                    // no hook → no pull → no budget change → no recompute
    }
    uint256 pre = rewardToken.balanceOf(address(this));
    dispatcherHook.pull();
    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
    if (inflow > 0) {                              // new NFT minted → budget grew → restart window
        _recomputeSchedule();
        emit Pulled(inflow, rewardBudget);
    }
}
```

- Removes the unconditional recompute at L432 and the no-hook recompute at L426.
- This is exactly the `design.md` invariant *"zero-inflow `pull()` is a no-op."*

### 2. Delete the stake/unstake tail recomputes (L565, L585)

Remove `_recomputeSchedule()` at **L565** (`stake`) and **L585** (`unstake`),
and delete the now-stale "retained for parity" comments at L559–565 / L583–585.
The code already documents that the rate is `totalStaked`-independent; the only
thing these calls did was reset the deadline — i.e. the bug. Per-share dilution
on a new stake is already handled by `_updatePool` advancing `accRewardPerShare`
against the live `totalStaked`; an ERC1155 deposit changes neither `rewardBudget`
nor `committedDebt`, so no re-sizing is needed.

### 3. Leave untouched

- `_updatePool()` — per-interaction accrual settlement (correct; not part of the bug).
- Direct recomputes in `setDepletionWindow` (L369), `topUp` (L381),
  `rescueERC20` (L408) — all genuine budget/window changes.
- `pullAndRefresh()` (L387) — after the fix, a zero-inflow manual refresh only
  settles accrual (no deadline reset). That is the intended semantics; use
  `topUp`/`setDepletionWindow` to deliberately re-derive the schedule.

---

## Verification (add as tests)

1. **Invert the PoC:** `PoC_DepletionRateDrift.t.sol` currently asserts active
   `< 70%` of passive. After the fix, assert active **≈ passive** (both ≈ full
   budget over the window, within floor-rounding tolerance), and that `windowEnd`
   does **not** move on a zero-inflow `claim`.
2. **Restart-on-mint preserved:** with the hook set, a non-zero `pull` mid-window
   **does** restart `windowEnd = now + windowSeconds` and re-derive the rate
   upward — assert the intended behaviour still holds.
3. **Zero-inflow no-op:** a `pullAndRefresh()` / `claim()` with `inflow == 0`
   leaves `rewardRate` and `windowEnd` unchanged (enforces design.md invariant).
4. **Solvency:** `balance == rewardBudget + committedDebt` holds across all of
   the above.
5. **Regression:** existing depletion + migration suites stay green; migration
   `depositFor` (L762) must not restart the window on re-injection (zero inflow).

---

## Notes

- After the fix, the contract's own claims at **L150–151** and **L445–448**
  ("avoids phlimbo's V1 rate-drift bug") become **true** — keep them.
- **Do NOT mirror this into `NFTStaker.sol` / `NFTStakerPriceScaled.sol`.** Those
  use the APY/runway model where `windowEnd = now + V/R` *is* the intended
  per-interaction runway semantics and the rate is budget-independent — recompute
  -on-interaction is correct there. This fix is specific to the depletion model.
  (Fork-drift watch-note: the three files diverge here by design.)
- Update the M-01 report's mitigation section to record the agreed
  restart-on-mint design (kept), not a blanket "don't reset the window."
