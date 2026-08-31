# Contract Profile: src/StableStaker.sol

- **Run**: stable-staker-10 (REGRESSION, range `93b7ce6..125f585` = story-010 only)
- **Commit profiled**: `125f585` ([story-010] Rework tests and docs for empty-pool-only setYieldStrategy gate; gate itself added in `bbfa140`)
- **Profiled**: 2026-06-09
- **Solidity**: `^0.8.20` (project pins solc 0.8.28; checked arithmetic throughout, no `unchecked`, no assembly)
- **Inheritance**: `Ownable` (OZ v5.6.1), `Pausable`, `ReentrancyGuard`, `IPausable`
- **LOC**: 815 | external/public functions: 23 | state-mutating externals: 16 | views: 7

## 1. Regression delta (93b7ce6..125f585)

Source delta on `src/StableStaker.sol` is exactly **8 lines, all in `setYieldStrategy`**: a 7-line
comment plus one new require. Everything else in the range is tests (`Migration.t.sol`,
`YieldStrategyIntegration.t.sol`) and `CLAUDE.md`. `StableStakerMigrator.sol` and
`IStableStaker.sol` are untouched in the range.

```solidity
function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
    require(poolState[token] == PoolState.Active, "StableStaker: pool not active");   // pre-existing (story-009)
    require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");        // NEW (story-010, bbfa140)
    ...
}
```

### What the gate checks and where

- **Predicate**: `poolInfo[token].totalStaked == 0` — i.e. zero *principal*, not zero *stakers*
  (contrast `finalizeAndReset`, which requires BOTH `stakerCount == 0 && totalStaked == 0`).
- **Enforced**: at the top of `setYieldStrategy` (line 228), before any external call and before
  `yieldStrategy[token]` is written. It is the second gate after the `PoolState.Active` check, so
  the full precondition is **Active AND empty**.
- **Intent (per in-code comment)**: strategy (un)wiring is an empty-pool-only operation; in-place
  principal moves are the shared root cause of ss6m1/M-01 (first-adoption sweep), M-06 (underwater
  swap) and M-07 (AMM-execution swap). Principal may only move via the terminal-migration path:
  `initiateMigration → batchMigrate/userMigrate → finalizeAndReset (empty) → setYieldStrategy`.

### Interaction with the lifecycle enum and finalizeAndReset

State machine (`PoolState`, default `Active`):

```
Active --initiateMigration (onlyMigrator)--> Migrating
Migrating --finalizeAndReset (onlyOwner, requires stakerCount==0 && totalStaked==0)--> Active
```

- `setYieldStrategy` requires `Active`, so it is blocked outright while `Migrating` (pre-existing).
- The revival sequence is the **only** way to re-wire a pool that ever had stakers:
  `finalizeAndReset` itself can only fire on a fully drained pool, and the pool it returns to
  Active is empty (`totalStaked == 0`), so the new gate passes immediately afterwards. There is no
  window in which `finalizeAndReset` revives a pool that still carries positions: its own
  preconditions are strictly stronger than the gate's.
- `initiateMigration` is the only path that *clears* `yieldStrategy[token]` with stakers present
  (line 457, sets to `address(0)` after fully realizing the position and post-checking
  `strategy.principalOf(token, this) == 0`). This is by design (terminal realize-once path) and is
  not a bypass: it never *installs* a strategy, only decouples one after a verified full drain.

### Consequences inside setYieldStrategy (now-conditional dead code)

With the gate, the `if (address(old) != address(0))` block runs with `totalStaked == 0`
guaranteed. Under the contract's lockstep invariant (`totalStaked == strategy.principalOf`,
maintained by `_routeDeposit` crediting strategy-booked principal and `_routeExit` debiting the
requested amount, incl. the buffer path's `relinquishPrincipal`):

- the `staked > 0` in-place drain (`_routeExit(token, staked, false)`) is **unreachable** — the
  whole "moves YS1→YS2 in this single call" mechanism is structurally dead;
- the story-008 underwater guard `require(!_isUnderwater(token, old))` **cannot trip** for a
  conforming strategy: `principalOf == 0` ⇒ `totalBalanceOf >= 0 == principalOf` ⇒ not underwater
  (strict `<`). It survives only as defense against a non-conforming strategy that desyncs
  principal upward (see Observations O-2);
- the idle-balance sweep into the new strategy still runs, but at `totalStaked == 0` the idle
  balance can never be user principal (only donations/dust/buffer residue), which is exactly what
  closes the M-01 first-adoption-sweep root cause.

## 2. Function inventory

### Owner config
| Function | Mutability/guards | State touched | External calls |
|---|---|---|---|
| `addToken(address)` | `onlyOwner` | `_registeredTokens`, `poolInfo.lastRewardTime` | — |
| `phUSDPerDay(address,uint256)` | `onlyOwner poolExists` | `poolInfo.phusdPerSecond` (+ `_updatePool`: `accPhusdPerShare`, `lastRewardTime`) | — |
| `setMigrator(address)` | `onlyOwner` | `migrator` | — |
| `setPauser(address)` | `onlyOwner` | `pauser` | — |
| `setYieldStrategy(address,IYieldStrategy)` | `onlyOwner poolExists` + **Active** + **totalStaked==0 (NEW)**; NOT `nonReentrant` | `yieldStrategy[token]` | `token.forceApprove(old,0)`, `token.forceApprove(new,max)`, `new.deposit(token, idle, this)`; (`_routeExit` drain path now dead) |
| `finalizeAndReset(address)` | `onlyOwner poolExists` + Migrating + `stakerCount==0 && totalStaked==0`; works while paused | `migrationInfo` (zeroed), `poolInfo.lastRewardTime`, `poolState→Active` | — |
| `rescueERC20(address,address,uint256)` | `onlyOwner`; works while paused; reserve check `bal >= reserved + amount` (`reserved = totalStaked` iff no strategy) | — | `token.balanceOf`, `token.safeTransfer` |

### Pausing
| Function | Guards |
|---|---|
| `pause()` | `onlyPauser` |
| `unpause()` | owner OR pauser |

### User staking (all `nonReentrant`)
| Function | Guards | State touched | External calls |
|---|---|---|---|
| `stake(address,uint256)` | `whenNotPaused poolExists` + Active | `userInfo`, `poolInfo.totalStaked`, `_stakers` (+pool accrual) | `phUSD.mint` (settle), `token.safeTransferFrom`+`balanceOf` (`_pullToken`), `strategy.deposit` (`_routeDeposit`) |
| `withdraw(address,uint256)` | `whenNotPaused poolExists` + Active | same (decrement; `_stakers.remove` iff amount→0) | `phUSD.mint`, `strategy.totalBalanceOf/principalOf` (underwater guard ON), `strategy.withdraw` or buffer path (`strategy.relinquishPrincipal`), `token.safeTransfer` |
| `claim(address)` | `whenNotPaused poolExists` | `userInfo.rewardDebt` (+pool accrual) | `phUSD.mint` |
| `emergencyWithdraw(address)` | Active only; **works while paused** | zeroes position, `totalStaked -=`, `_stakers.remove` | `_routeExit` guard OFF, `token.safeTransfer`; forfeits pending, skips `_updatePool` (known M-02, won't-fix) |

### Terminal migration
| Function | Guards | Notes |
|---|---|---|
| `initiateMigration(address)` | `nonReentrant onlyMigrator poolExists` + Active | settles+freezes emissions, snapshots P, realizes R via `_routeExit(guard OFF)`, post-checks `principalOf==0`, decouples strategy, `poolState→Migrating` |
| `batchMigrate(address,address[])` | `nonReentrant onlyMigrator poolExists` + Migrating; callable while paused | loop over caller-supplied `users` (migrator-paged, not user-controlled); credits `p_i·min(R,P)/P` via `_exitPosition`; one aggregate transfer to migrator |
| `userMigrate(address)` | `nonReentrant` + Migrating + own position > 0 | permissionless escape hatch; CEI (zero-then-transfer) |
| `depositFor(address,address,uint256)` | `nonReentrant onlyMigrator poolExists` + Active; callable while paused | migrator redeposit into NEW staker |

### Views
`pendingReward`, `getStakers` (unbounded `values()` — view-only, known), `getStakersRange`
(paged), `stakerCount`, `getStakedTokens`, `withdrawDisabled`.

## 3. Verified local properties

| Property | Status | Evidence |
|---|---|---|
| Checked arithmetic, no unchecked/assembly | **verified** | solc 0.8.x, grep clean |
| Reentrancy guards on all user value paths | **verified** | `stake/withdraw/claim/emergencyWithdraw/userMigrate/batchMigrate/initiateMigration/depositFor` all `nonReentrant`; `userMigrate` additionally CEI |
| `setYieldStrategy` NOT `nonReentrant` | **verified** (see O-3) | gate checked before externals; only owner-wired strategy can call back |
| Access control on all config/migration | **verified** | onlyOwner / onlyMigrator / onlyPauser as tabled above |
| No unbounded attacker-controlled loops in mutators | **verified** | `batchMigrate` loop bounded by migrator's calldata |
| **G-1: gate ⇒ no outstanding principal claims** | **verified** | `totalStaked` is the exact sum of all `userInfo.amount` (every mutator — `stake`, `depositFor` `+=`; `withdraw`, `emergencyWithdraw`, `_exitPosition` `-=` — updates both in the same statement pair). `totalStaked == 0 ⇒ ∀u: userInfo[token][u].amount == 0`. So "empty pool" by principal genuinely means no staker can be harmed by a swap. |
| **G-2: no zero-amount stranding in `_stakers`** | **verified** | every path that drops `user.amount` to 0 (`withdraw`'s `if (user.amount == 0)`, `emergencyWithdraw`, `_exitPosition`) also calls `_stakers.remove`. Hence `totalStaked == 0 ⇔ stakerCount == 0` in practice; the gate's totalStaked-only check is equivalent to finalizeAndReset's two-condition check (asymmetry is cosmetic, see O-1). |
| **G-3: gate covers all strategy-installation paths** | **verified** | `yieldStrategy[token]` is written in exactly two places: `setYieldStrategy` L256 (gated) and `initiateMigration` L457 (clears to `address(0)` only, after a verified full drain). `StableStakerMigrator` holds no strategy reference; `IStableStaker` exposes no setter. No other function swaps/sets the strategy. |
| **G-4: finalizeAndReset revival cannot bypass the gate** | **verified** | revival requires `Migrating ∧ stakerCount==0 ∧ totalStaked==0`; it returns an *empty* pool to Active, so the post-revival `setYieldStrategy` passes trivially and no staker from the previous epoch survives (`migrationInfo` zeroed, `lastRewardTime` fast-forwarded — no retro-accrual). Conversely, while `Migrating` the Active check blocks `setYieldStrategy` entirely. |
| **G-5: gate kills the M-01/M-06/M-07 root cause locally** | **verified** | with `totalStaked == 0` at entry, no user principal can be moved, haircut, or desynced by the call; the idle sweep can only move protocol-owned balance. The desync invariant (`totalStaked == strategy.principalOf`) can no longer be broken by `setYieldStrategy` for a conforming strategy. |
| Emission-cap invariant untouched | **verified** | the range adds no writer of `accPhusdPerShare`; `_updatePool` unchanged |

## 4. Local findings

| ID | Sev (local) | Where | Description |
|---|---|---|---|
| LOCAL-001 | low (QA/doc) | `setYieldStrategy` NatSpec L206-214; `finalizeAndReset` NatSpec L580-583 | **Stale NatSpec contradicts the new gate.** The `setYieldStrategy` docstring still describes the in-place YS1→YS2 whole-position drain ("the old strategy is best-effort drained… The whole position therefore moves YS1->YS2 in this single call, with no per-user migration") — behaviour that is now structurally impossible (`totalStaked == 0` required, drain branch dead). `finalizeAndReset`'s NatSpec still credits "story 008's underwater guard" as the thing forbidding in-place swaps; story-010's empty-pool gate is now the (stronger) forbidder. Misleading for the future operator the contract's own comments say it is written for. |

No new local High/Medium. The change is a pure restriction (one extra `require`); it removes
reachable behaviour rather than adding any.

## 5. Observations on gate completeness (for Tier-2)

- **O-1 (benign asymmetry)**: gate checks `totalStaked == 0` only; `finalizeAndReset` checks
  `stakerCount == 0 && totalStaked == 0`. By G-1/G-2 these are equivalent under conforming flows;
  recorded so nobody mistakes the asymmetry for a hole.
- **O-2 (defensive-code wedge, non-conforming strategy only — defer to interaction tier)**: if a
  strategy ever desyncs `principalOf` ABOVE `totalStaked` (non-conforming `withdraw`/`deposit`
  bookkeeping), then with `totalStaked == 0` but residual `principalOf > 0`: (a) the gated
  `setYieldStrategy` drain is skipped (`staked == 0`) so the residual is never recovered, only the
  allowance is revoked; (b) the story-008 underwater guard CAN then trip (`totalBalanceOf <
  principalOf`), blocking even `setYieldStrategy(token, 0)`; and (c) `initiateMigration` on the
  empty pool reverts too (`_routeExit` calls `strategy.withdraw(token, 0)` which conforming
  strategies revert on, and the `principalOf == 0` post-check fails regardless). A
  residual-desynced strategy therefore wedges both re-wiring paths for that token. Requires a
  non-conforming strategy, so it is a trust assumption, not a finding — but Tier-2 should check it
  against the real `reflax-yield-vault` strategies (incl. `relinquishPrincipal` paths).
- **O-3 (TOCTOU via callback, trusted-strategy assumption)**: `setYieldStrategy` is not
  `nonReentrant`, and the gate is checked before the external calls. A malicious *new* strategy's
  `deposit` (idle sweep) could re-enter `stake()` (the ReentrancyGuard lock is NOT held by
  `setYieldStrategy`), making `totalStaked > 0` mid-call. Effect is benign for value flow —
  `yieldStrategy[token]` is already the new strategy before the sweep, so the re-entrant stake
  routes into the same strategy — and the strategy is owner-selected infrastructure (Law 3). Not a
  finding; recorded as the precise boundary of what the gate proves: it is a *precondition*, not
  an invariant held across the call's external calls.
- **O-4 (operational consequence, intended)**: with the gate, the ONLY way to change strategy on a
  live pool is full terminal migration of every staker. This matches the owner's decision memo
  (collapses M-01/M-06/M-07) and the phStaging "no in-place setYieldStrategy" runbook rule. The
  emission freeze during `Migrating` means stakers earn no phUSD for the duration of a strategy
  rotation — known/accepted cost of the design, not new.

## 6. Interface abstraction — yield-strategy trust boundary

External calls to `IYieldStrategy` (from `reflax-yield-vault`, semi-trusted: owner-wired, but
market/AMM-backed implementations have haircut/slippage semantics):

| Call | Call sites | Assumption relied on |
|---|---|---|
| `deposit(token, amount, this)` | `_routeDeposit` (stake, depositFor), idle sweep in `setYieldStrategy` | returns principal actually booked; farm credits the *returned* amount (haircut-safe) |
| `withdraw(token, amount, this)` | `_routeExit` (withdraw, emergencyWithdraw, initiateMigration; setYieldStrategy drain now dead) | synchronous, caps at available principal, **reverts on amount == 0**, decrements `principalOf` by the requested amount (lockstep) |
| `totalBalanceOf` / `principalOf` | `_isUnderwater` (withdraw guard, M-06 guard, `withdrawDisabled`), initiateMigration post-check | honest par measurement; `principalOf` tracks farm-side `totalStaked` |
| `relinquishPrincipal(token, amount)` | `_routeExit` buffer path (underwater withdraw served from on-contract buffer) | strategy forgets principal without asset movement (story-045/046 in reflax) |
| `totalWithdrawal` | **deliberately NOT used** (onlyOwner, 2-phase, redeems to strategy owner) | — |

Other trust boundaries: `phUSD.mint` (farm must be authorized minter; mint failure traps rewards
but `emergencyWithdraw` rescues principal), staked ERC20s (standard, fee-on-transfer tolerated via
`_pullToken` balance-delta), `migrator` (`StableStakerMigrator`, owner-set), `pauser`.

Events: `TokenAdded, RewardRateSet, MigratorSet, PauserUpdated, YieldStrategySet, Staked,
Withdrawn, Claimed, EmergencyWithdrawn, MigratedOut, MigrationInitiated, UserMigrated,
DepositedFor, BufferWithdrawn, ERC20Rescued, PoolReset`.

## 7. Ledger relevance

The gate is the implemented fix for the owner-decided collapse of **M-01 / M-06 / M-07**
(stable-staker-setyieldstrategy-empty-pool-gate). On this local analysis the fix is sound: all
three findings shared the in-place-principal-move root cause, which is now unreachable (G-5).
Tier-2/recheck should confirm via PoC replay that the M-01 sweep, M-06 underwater-swap and M-07
AMM-slippage-swap PoCs now revert with `"StableStaker: pool not empty"`. Remainders per memory:
M-05 (deferred pending reflax integration — F-03 gate landed in reflax run-14) and ss9l1 are NOT
addressed by this range and stay open.
