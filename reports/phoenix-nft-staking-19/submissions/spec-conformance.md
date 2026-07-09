<!--
Spec-Conformance Report (Law-2 faithfulness deviations)
Project: phoenix-nft-staking
Run dir: reports/phoenix-nft-staking-19
HEAD commit: 321d0a96d7da9f261517fc53e2d14bf2b49f41c1
Governing story: story-020 ("Fix NFTStakerDepletion rate-drift (audit M-01)")
Contract: src/NFTStakerDepletion.sol
Sections: F-19-01 (pns19l1), F-19-02 (pns19q2), F-19-03 (pns19l2)
This report is kept SEPARATE from the QA/gas bundle by design.
-->

# Spec-Conformance Report — phoenix-nft-staking (run-19)

## Summary

This report covers three residual **Law-2 (story-faithfulness) deviations** left behind by the
story-020 fix of audit finding M-01 (depletion rate-drift), evaluated against
`src/NFTStakerDepletion.sol` @ `321d0a9`.

**The story-020 fix itself was verified FAITHFUL + COMPLETE + SOLVENCY-SAFE and is not in
question here.** The M-01 exploit surface — the permissionless `stake` / `unstake` / `claim`
path — was correctly closed: those functions now call only `_syncBudget()` at head, which
settles accrual via `_updatePool()` and recomputes the schedule **only** when a hook `pull()`
yields `inflow > 0` (`src/NFTStakerDepletion.sol#L423-L435`); with zero inflow, `windowEnd` and
`rewardRate` are untouched, so a bare interaction no longer resets the deadline or re-derives
the budget rate. The regression guard passed, the inverted PoC passed 3/3 (active matches
passive, no `windowEnd` drift, no rate decay), and the full suite reported 269/269. The
`balance == rewardBudget + committedDebt` solvency invariant is preserved independently of the
skipped recompute.

The three items below are **doc/edge deviations the fix left in its wake, not defects in the
fix.** Each is Low or QA. None reintroduces M-01. They are surfaced here — rather than buried in
the QA/gas bundle — because they are behaviour-parity / spec-text deviations against the
governing story, and recall beats report-tidiness (Law 1). Each cross-references its QA-bundle
twin so the two views reconcile.

The governing story text quoted throughout is the `[story-020]` commit body (`321d0a9`):

> Gate `_syncBudget()` recompute on non-zero pull inflow and drop the stake/unstake tail
> recomputes, so a bare stake/unstake/claim no longer resets the deadline or re-derives the
> budget-derived rate. Restart-on-mint (non-zero pull) is preserved. Brings the contract in
> line with the "zero-inflow pull() is a no-op" design invariant.

---

## F-19-01 — depositFor retains a tail recompute story-020 removed from stake; NatSpec "parity with stake" is now false
<!-- id: pns19l1 · fp: ced20f2e93493ac86505892c4038fbe58edf00d660a0d4c1ff588c65226de31c · cross-ref QA L-01 -->

**Severity:** Low (faithfulness / operational — value-conserving, trusted path)
**Location:** [`src/NFTStakerDepletion.sol#L748-L768`](https://github.com/Behodler/phoenix-nft-staking/blob/master/src/NFTStakerDepletion.sol#L748-L768) (`depositFor`)
**Story:** story-020

### Governing story text

The story-020 commit (`321d0a9`) states its intent as:

> ...**drop the stake/unstake tail recomputes**, so a bare stake/unstake/claim no longer resets
> the deadline or re-derives the budget-derived rate. ... Brings the contract in line with the
> **"zero-inflow pull() is a no-op" design invariant.**

Post-fix, `stake` no longer recomputes on a zero-inflow interaction — it calls only
`_syncBudget()` at head and returns without touching `windowEnd`/`rewardRate`
(`src/NFTStakerDepletion.sol#L539-L558`).

### Actual behaviour

`depositFor` still carries an **unconditional** tail `_recomputeSchedule()`, and its NatSpec
still justifies that recompute by appeal to a parity with `stake` that story-020 dissolved:

```solidity
// src/NFTStakerDepletion.sol#L764-L767
        emit DepositedFor(user, amount);
        // Tail recompute: rate is `budget / windowSeconds`, totalStaked-
        // independent, but pin `windowEnd` for parity with `stake`.
        _recomputeSchedule();
```

The claimed "parity with `stake`" no longer exists: `stake` was changed to **not** recompute on
zero inflow, while `depositFor` unconditionally resets `windowEnd = now + windowSeconds` and
re-derives `rewardRate = budget / windowSeconds` on every call. Both migrators drive
`depositFor` in a per-user loop (`NFTStakerMigrator`, `InPlaceNFTStakerMigrator`), so a
multi-batch / multi-tx re-seed restarts the depletion window on each call — the same
zero-inflow window-restart class story-020 removed from the permissionless path, now surviving
on the migrator path.

### Impact — not an M-01 reintroduction

M-01 was exploitable because the window reset was reachable via **permissionless**
`stake`/`unstake`/`claim`. `depositFor` is `onlyMigrator` (trusted orchestrator),
value-conserving (`budget = V - committedDebt`, and the head `_syncBudget()` settles accrual at
the old rate before crediting), and solvency-safe (`balance == rewardBudget + committedDebt`
preserved). The residual is a bounded, trusted-path window restart during migration re-seeding,
not a permissionless exploit. Honest severity: **Low** — Law 1 does not bump it because there is
no asset/availability/griefing impact.

### Recommended mitigation steps

Either:

- **(a)** Drop the `depositFor` tail recompute to match `stake`/`unstake` — a fresh re-seed then
  inherits the pool's existing window, and the owner re-arms via `setDepletionWindow` when a
  fresh window is genuinely intended (this also resolves F-19-03's self-heal asymmetry); **or**
- **(b)** Keep the recompute as a deliberate migration-reseed window restart and **rewrite the
  NatSpec to say so** — remove the now-false "for parity with `stake`" justification and
  declare it an intentional migration-reseed restart.

---

## F-19-02 — _syncBudget no-hook branch NatSpec claims "pure recompute"; post-story-020 it settles accrual only
<!-- id: pns19q2 · fp: 37783e0354ac53ed9a1436aa0e0cbd9a9efd79b12eee3488055f429f274d0772 · cross-ref QA Q-02 -->

**Severity:** QA (documentation-only; no runtime effect)
**Location:** [`src/NFTStakerDepletion.sol#L419-L435`](https://github.com/Behodler/phoenix-nft-staking/blob/master/src/NFTStakerDepletion.sol#L419-L435) (`_syncBudget`)
**Story:** story-020

### Governing NatSpec text

The `_syncBudget` docstring still describes the pre-fix behaviour of the no-hook branch:

```solidity
// src/NFTStakerDepletion.sol#L419-L422
    /// @dev Materialises pending mint debt as phUSD via `pull()`, then
    ///      recomputes the emission schedule against the new balance. If
    ///      the hook is unset, behaves like a pure recompute (still useful
    ///      after a state-changing config setter).
```

### Actual behaviour

After story-020, the no-hook branch **returns without recomputing** — it is a pure
`_updatePool()` (accrual settlement), not a recompute:

```solidity
// src/NFTStakerDepletion.sol#L423-L435
    function _syncBudget() internal {
        _updatePool();                                 // always: settle accrual
        if (address(dispatcherHook) == address(0)) {
            return;                                    // no hook → no pull → no budget change → no recompute
        }
        uint256 pre = rewardToken.balanceOf(address(this));
        dispatcherHook.pull();
        uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
        if (inflow > 0) {                              // new NFT minted → budget grew → restart window (intended)
            _recomputeSchedule();
            emit Pulled(inflow, rewardBudget);
        }
    }
```

The docstring's "behaves like a pure recompute" is stale: the branch no longer recomputes at
all. This is documentation-vs-code drift introduced **by** the story-020 fix.

### Impact

None functional. Every config setter that needs a recompute — `setDispatcherIndex`,
`setNFTMinter`, `setDepletionWindow`, `topUp`, `rescueERC20` — calls `_recomputeSchedule()`
**directly** and does not rely on `_syncBudget`'s no-hook branch. A no-hook `pullAndRefresh` has
no budget change to recompute. The only harm is future-maintenance confusion. Honest severity:
**QA.**

### Recommended mitigation steps

Update the `_syncBudget` NatSpec so the no-hook branch is described as "settles accrual only; no
recompute (config setters recompute directly)", replacing the stale "behaves like a pure
recompute" clause.

---

## F-19-03 — finalizeAndReset revives the pool without re-arming the window; organic stake() no longer auto-rearms post-story-020
<!-- id: pns19l2 · fp: 51e8255bf7097d92215821e8b3dba8a78330008ace63e249346d1d847c406f9b · cross-ref QA L-02 -->

**Severity:** Low (operational footgun — value-conserving; intended story-020 consequence)
**Location:** [`src/NFTStakerDepletion.sol#L778-L784`](https://github.com/Behodler/phoenix-nft-staking/blob/master/src/NFTStakerDepletion.sol#L778-L784) (`finalizeAndReset`)
**Story:** story-020

### Governing story text and NatSpec

story-020 removed the tail recompute from `stake` (quoted in F-19-01): a bare `stake` no longer
recomputes the schedule. The `finalizeAndReset` NatSpec states its purpose:

```solidity
// src/NFTStakerDepletion.sol#L770-L777
    /// @notice Return a fully-drained `Migrating` pool to `Active` so the SAME
    ///         staker can be revived (e.g. after an in-place dispatcher/hook
    ///         rewire). Requires every position to have exited
    ///         (`totalStaked == 0`). Fast-forwards `lastRewardTime` so the
    ///         frozen migration gap is never retro-accrued. No (R, P) snapshot
    ///         to clear (the Uniboost staker has none).
```

### Actual behaviour

`finalizeAndReset` revives the pool to `Active` and fast-forwards `lastRewardTime`, but does
**not** recompute the schedule:

```solidity
// src/NFTStakerDepletion.sol#L778-L784
    function finalizeAndReset() external onlyOwner {
        require(poolState == PoolState.Migrating, "NFTStaker: not migrating");
        require(totalStaked == 0, "NFTStaker: stake outstanding");
        lastRewardTime = block.timestamp;
        poolState = PoolState.Active;
        emit PoolReset();
    }
```

`windowEnd` and `rewardRate` keep their pre-freeze values, which after a migration freeze are
typically stale / in the past — `currentRewardRate()` returns 0 once `block.timestamp >=
windowEnd`. Pre-story-020, the **first** post-revival `stake()` would auto-rearm the window via
its tail recompute. Post-story-020, `stake()` no longer recomputes, so a revived pool that
resumes **organic** staking (with no `depositFor` re-seed) emits **nothing** until the owner
calls `setDepletionWindow` / `topUp` / a hook pull with `inflow > 0`.

### Impact — intended consequence, surfaced as a footgun

This is **not** a violation of any story-020 acceptance criterion — it is the *intended*
consequence of the fix (`stake` must not reset the window). It is surfaced here as a
non-obvious operational hazard (Law 3 footgun): the migration-revive path now requires an
explicit owner window re-arm before organic emissions resume, where previously the first stake
did it implicitly. The standard InPlace flow re-seeds via `depositFor` (which **does** recompute —
see F-19-01), so the documented migration path self-heals; only a revive-then-organic-stake
sequence with no `depositFor` exhibits the dormant window. **Value is never lost** (the budget is
conserved); emissions merely pause until re-arm. The asymmetry — migrator path self-heals,
organic path silently stalls — is what makes this a footgun a competent operator could be
marginally surprised by. Honest severity: **Low.**

### Recommended mitigation steps

Either recompute the schedule inside `finalizeAndReset` on revive (re-arm the window as part of
the reset), or document explicitly that `finalizeAndReset` leaves the depletion window dormant
and that the owner must re-arm it (`setDepletionWindow` / `topUp`) before organic staking
resumes emissions. Emitting an explicit `NEEDS-REARM` signal alongside `PoolReset` would make
the required follow-up self-evident. Resolving F-19-01 via option (a) would also close this
asymmetry by making the organic path consistent with the migrator path.

---

## Reconciliation

| Section | Fingerprint (prefix) | QA cross-ref | Story | Severity | Nature |
|---|---|---|---|---|---|
| F-19-01 (`pns19l1`) | `ced20f2e` | L-01 | story-020 | Low | Behaviour-parity deviation + false NatSpec (trusted path) |
| F-19-02 (`pns19q2`) | `37783e03` | Q-02 | story-020 | QA | Documentation-only drift |
| F-19-03 (`pns19l2`) | `51e8255b` | L-02 | story-020 | Low | Intended consequence surfaced as operational footgun |

All three are residual doc/edge deviations left by the story-020 M-01 fix; the fix itself is
FAITHFUL + COMPLETE + SOLVENCY-SAFE. None reintroduces the M-01 exploit surface.
