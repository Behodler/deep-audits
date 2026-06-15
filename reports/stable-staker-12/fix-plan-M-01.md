# Fix Plan (DRAFT) — M-01 re-injection haircut (`ss12m1`)

**Status:** DRAFT — design only, no code written. Implement upstream in `stable-staker`.
**Finding:** M-01 / `ss12m1` — `InPlaceMigrator.migrateIn` zeroes parked accounting by the requested
`amt` while `StableStaker.depositFor` credits only the strategy's haircut return, silently
underpaying re-injected stakers. See `submissions/M-01.md`.
**Hard constraint:** **No changes to `StableStaker.sol`.** Fix lives entirely in `InPlaceMigrator.sol`.
**Target commit context:** stable-staker @ `ffa4947`.

---

## 1. Approach

The migration slippage is a real, unavoidable economic cost of moving principal between strategies.
Rather than letting the re-injected user silently absorb it (M-01), the **owner pre-funds an explicit
allotment** that `migrateIn` draws on to top each user back up to par. If the allotment is
insufficient, the **whole batch reverts** (all users made whole, or none) — so a half-funded run
never produces an unfair partial migration.

This is achievable read-only against the unmodified staker because:
- `StableStaker.userInfo` is a **public mapping** (StableStaker.sol:78) → auto-getter
  `userInfo(token, user)` exposes the user's `amount` (credited principal, struct field at :69-70).
- `depositFor` credits **additively** (`info.amount += credited`, StableStaker.sol:633), so a second
  `depositFor` call stacks onto the same position in the same staker.

So `migrateIn` measures the haircut via a before/after snapshot of `userInfo(...).amount` and issues
a single grossed-up top-up deposit. No staker interface or storage change required.

## 2. Per-user algorithm inside `migrateIn` (replaces the single `depositFor` call)

For each parked user with parked amount `amt`:

1. `before = staker.userInfo(token, user).amount`
2. `staker.depositFor(token, user, amt)`  — funded from the parked principal (as today)
3. `credited = staker.userInfo(token, user).amount - before`
4. If `credited < amt`:
   a. `shortfall = amt - credited`
   b. **Gross-up** so the top-up itself survives its own haircut:
      `topup = shortfall * amt / credited`   ( = `shortfall / (credited/amt)` )
   c. Require the owner allotment can cover it: `topup <= allotment[token]`; **else revert the whole
      batch** (`"InPlaceMigrator: allotment exhausted"`).
   d. `allotment[token] -= topup`
   e. `staker.depositFor(token, user, topup)`  — funded from the owner allotment
5. **Tolerance backstop** (see §3):
   `finalCredited = staker.userInfo(token, user).amount - before`
   `require(finalCredited >= amt - amt/1000, "InPlaceMigrator: par not restored")`
6. Zero parked accounting by the full `amt` (as today): `parked[token][user] = 0; totalParked[token] -= amt`
7. Emit a per-user event carrying `amt`, `credited`, `topup`, `finalCredited` (see §6).

> The gross-up is exact at a constant marginal haircut rate: `topup * (credited/amt) == shortfall`.
> Because migration deposits are tiny relative to the underlying pool TVL, the marginal rate is
> effectively constant across the two deposits, so a single top-up lands at par (modulo integer dust,
> which §3 absorbs). No iterative loop and no over-fund/refund needed.

## 3. Tolerance (per owner decision)

Hardcode a relative tolerance of **`amt / 1000`** (0.1% of the deposit):

```
require(finalCredited >= amt - amt/1000, "InPlaceMigrator: par not restored");
```

- For USDC (6 decimals) this bounds the worst-case residual to the 0.1%-of-deposit level — i.e. for
  a 1 USDC unit it is sub-cent (≈ 0.001 USDC), which is more than enough precision for a USD stable.
- **This is a non-reverting backstop, not a loss budget.** Step 4 still targets *exact* par; the
  tolerance only forgives the few-wei integer-division residual so the require doesn't spuriously
  revert. In normal operation realized residual is a handful of wei, far below `amt/1000`. The
  tolerance is breached only if a top-up genuinely could not close the gap (e.g. a pathological
  ~100% haircut), in which case reverting the batch is the correct outcome.

## 4. New state / storage (migrator only)

- `mapping(address => uint256) public allotment;`  — owner-supplied top-up budget per token.
- Owner funding entry point, e.g. `fundAllotment(address token, uint256 amount)` (onlyOwner): pulls
  `amount` of `token` into the migrator and increments `allotment[token]`.
- Owner defunding entry point, e.g. `withdrawAllotment(address token, uint256 amount)` (onlyOwner):
  returns unused allotment after a migration completes.

## 5. `rescueERC20` fencing change

Today `rescueERC20` is floored at `totalParked` (so parked principal can't be rescued). The allotment
is balance held *above* that floor and would currently be rescuable. Tighten the floor to:

```
rescuable balance = balanceOf(token) - totalParked[token] - allotment[token]
```

so neither parked principal nor the funded allotment can be swept mid-migration.

## 6. Events / observability

Add a per-user event (e.g. `ReinjectedWithTopup(token, user, parked, credited, topup, finalCredited)`)
emitted in `migrateIn`. This makes the owner subsidy fully on-chain auditable and removes the
"silent" character that was central to the M-01 finding.

## 7. Explicitly OUT of scope for this fix (do not assume these are covered)

- **L-01 / `ss12l1` (zero-credit dust user)** is a *separate* revert and survives this fix. If a
  user's *first* `depositFor(amt)` credits `0`, `require(credited > 0)` (StableStaker.sol:632) reverts
  the batch at step 2 — before the top-up logic runs, and the gross-up cannot divide by a zero
  `credited`. With all-or-nothing batching, one such dust position still blocks the batch. If this
  matters operationally, handle separately (pre-filter dust positions, or skip-and-leave-parked for
  `claimTimedOut`). The owner accepted allotment-exhaustion grief; this is a *different* revert source
  and should be a conscious, separate decision.
- **Exit-side slippage.** This fix makes users whole on the *deposit* (re-injection) leg only.
  Whether a later `withdraw`/`emergencyWithdraw` haircuts on the way out is a pre-existing staker
  property (`_routeExit`), unchanged here and not part of M-01.

## 8. Cost / behaviour notes

- **~2× gas for haircut users** — the top-up is a second real `_routeDeposit` (strategy deposit +
  `_updatePool` + `_settle` + `EnumerableSet.add`). Size `migrateIn` batches accordingly.
- **Reward-safe** — the second `depositFor` runs in the same block, so its `_updatePool` accrues 0;
  no double-mint, emission cap intact.
- Par-funded / idle / 1:1 strategies trigger no top-up (credited == amt at step 3); the fix is a
  no-op cost there.

## 9. Acceptance criteria (for the follow-up PoC / tests)

1. Existing M-01 PoC (`workspace/.../test/poc/PoC_M01_ReinjectionHaircut.t.sol`) **flips to whole**:
   re-injected `userInfo.amount` == parked `amt` (within `amt/1000`), allotment debited by ≈ the
   grossed-up shortfall.
2. Conservation control at 0 bps: no top-up, allotment untouched, behaviour identical to today.
3. Fuzz haircut 1–500 bps: every user lands `>= amt - amt/1000`; allotment debit matches the
   gross-up formula; total allotment spent ≈ aggregate slippage.
4. Under-funded allotment: batch reverts with `allotment exhausted`, all users remain parked and
   `claimTimedOut`-recoverable (no state mutation leaks).
5. `rescueERC20` cannot reduce balance below `totalParked + allotment`.
6. Zero-credit dust user still reverts the batch (documents L-01 as knowingly out of scope).

## 10. Open decisions for the owner

- **Allotment sizing guidance** — recommend funding ≳ (expected haircut % × total parked) with margin;
  document the chosen target strategy's measured deposit slippage at migration time.
- **L-01 dust handling** — accept batch-revert grief, or add a dust pre-filter? (separate decision)
- **Refund of leftover allotment** — auto-return after a completed migration, or manual
  `withdrawAllotment`?
