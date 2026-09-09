# Profile: src/StableStakerV2.sol  @ fa06de5
solidity ^0.8.20 (pinned solc 0.8.28) | 918 LOC | Ownable, Pausable, ReentrancyGuard, IPausable, IStableStaker

## 1. Interface abstraction

| Function | Access | Other gates | Reads | Writes | External calls |
|---|---|---|---|---|---|
| `addToken(token)` | onlyOwner | — | `_registeredTokens` | `_registeredTokens`, `poolInfo.lastRewardTime` | — |
| `antimatterPerDay(token,amt)` | onlyOwner | poolExists | pool | `_updatePool`; `poolInfo.antimatterPerSecond` | — |
| `setMigrator(a)` | onlyOwner | — | — | `migrator` | — |
| `setPauser(a)` | onlyOwner | — | `pauser` | `pauser` | — |
| `setYieldStrategy(token,s)` | onlyOwner | poolExists, `poolState==Active`, `totalStaked==0`, `!underwater(old)` | `yieldStrategy`, pool | `yieldStrategy` | `old.totalBalanceOf/principalOf`, `_routeExit`, `IERC20.forceApprove(old,0)`, `forceApprove(new,max)`, `IERC20.balanceOf`, `new.deposit` |
| `pause()` | onlyPauser | — | — | `_paused` | — |
| `unpause()` | owner OR pauser | — | — | `_paused` | — |
| `stake(token,amt)` | none | nonReentrant, whenNotPaused, poolExists, Active, amt>0 | pool, user | `_updatePool`, `unclaimedReward`(+), `user.amount`, `pool.totalStaked`, `user.rewardDebt`, `_stakers` | `token.transferFrom`, `token.balanceOf` x2, `strategy.deposit` |
| `withdraw(token,amt)` | none | nonReentrant, whenNotPaused, poolExists, Active, amt>0, `user.amount>=amt` | pool, user | `_updatePool`, `user.amount`, `pool.totalStaked`, `user.rewardDebt`, `_stakers`, `unclaimedReward`(+) | `strategy.totalBalanceOf/principalOf`, `strategy.withdraw` OR `strategy.relinquishPrincipal`, `token.balanceOf`, `token.transfer` |
| `claim(token)` | none | nonReentrant, whenNotPaused, poolExists, `owed>0` | pool, user, `unclaimedReward` | `_updatePool`, `unclaimedReward`:=0, `user.rewardDebt` | **`antimatter.mint`** |
| `emergencyWithdraw(token)` | none | nonReentrant, Active, `amount>0`. **No poolExists, no whenNotPaused, NO `_updatePool`** | user, pool | `user.amount`:=0, `user.rewardDebt`:=0, `unclaimedReward`:=0, `pool.totalStaked`, `_stakers` | `_routeExit(guard=false)`, `token.transfer` |
| `initiateMigration(token)` | onlyMigrator | nonReentrant, poolExists, Active | pool, `yieldStrategy` | `_updatePool`, `yieldStrategy`:=0, `poolState`:=Migrating, `migrationInfo` | `strategy.withdraw`, `strategy.principalOf` x2, `strategy.relinquishPrincipal`, `forceApprove(0)`, `token.balanceOf` |
| `batchMigrate(token,users[])` | onlyMigrator | nonReentrant, poolExists, Migrating. **Callable while paused** | migrationInfo, pool, users | per-user via `_exitPosition` | **`antimatter.mint` per user**, `token.transfer(migrator,total)` |
| `userMigrate(token)` | none (self) | nonReentrant, Migrating, `amount>0`. **Callable while paused** | same | same | **`antimatter.mint`**, `token.transfer` |
| `finalizeAndReset(token)` | onlyOwner | poolExists, Migrating, `stakerCount==0`, `totalStaked==0`. No whenNotPaused | `_stakers`, pool | `migrationInfo`:=0, `lastRewardTime`, `poolState`:=Active | — |
| `depositFor(token,user,amt)` | onlyMigrator | nonReentrant, poolExists, Active, amt>0. **Callable while paused** | pool, user | `_updatePool`, `unclaimedReward`(+), `user.amount`, `pool.totalStaked`, `user.rewardDebt`, `_stakers` | `token.transferFrom`, `balanceOf` x2, `strategy.deposit` |
| `rescueERC20(token,to,amt)` | onlyOwner | `to!=0`, `bal>=reserved+amt`. No nonReentrant, works while paused | `yieldStrategy`, `poolInfo.totalStaked` | — | `token.balanceOf`, `token.transfer` |
| views | `pendingReward`, `claimableReward` (NEW), `unclaimedReward` (NEW public mapping), `getStakers`, `getStakersRange`, `stakerCount`, `getStakedTokens`, `withdrawDisabled`, `poolInfo`, `userInfo`, `poolState`, `migrationInfo`, `antimatter`, `migrator`, `pauser`, `STAKER_VERSION=2`, `ACC_PRECISION=1e18`, `SECONDS_PER_DAY=86400` |

Unbounded loops: `batchMigrate` (caller-supplied `users[]`, owner/migrator only) and
`getStakersRange` (view). No user-reachable unbounded loop.

## 2. Verified local properties

- **P1 (VERIFIED-BY-READING) — sole index writer.** `accAntimatterPerShare` is written at exactly one
  site, `_updatePool` :824. `grep -c 'accAntimatterPerShare +='` == 1.
- **P2 (VERIFIED-BY-READING) — index monotonic non-decreasing.** `+=` only; `finalizeAndReset` does
  NOT reset it (:680-682 resets `migrationInfo` and `lastRewardTime` only).
- **P3 (VERIFIED-BY-READING) — accrual cap.** Per `_updatePool` call the pool folds in
  `elapsed*antimatterPerSecond` of value; `Σ_users amount·Δacc = totalStaked · floor(reward·1e18/totalStaked)/1e18 ≤ reward`.
  Emissions cannot exceed `antimatterPerDay` over any window. Holds independently of the story-022
  deferral because no new path writes the index.
- **P4 (VERIFIED-BY-READING) — accrual frozen while Migrating.** `_updatePool` :810-812 returns early
  when `poolState != Active`, and `_pendingReward` :748 guards the projection identically.
- **P5 (VERIFIED-BY-READING) — `_settle` never mints.** :832-839 writes only `unclaimedReward`.
  Exactly two `antimatter.mint(` sites remain: `claim` :385 and `_exitPosition` :620.
- **P6 (VERIFIED-BY-READING) — no stale `rewardDebt` at `amount==0`.** Every path that zeroes
  `amount` also zeroes/recomputes `rewardDebt` to `0·acc/1e18 == 0` (`withdraw` :356,
  `emergencyWithdraw` :402, `_exitPosition` :614). So a re-stake after full exit cannot underflow
  `amount·acc/PREC - rewardDebt`.
- **P7 (VERIFIED-BY-READING) — state machine.** Only two transitions: `initiateMigration`
  Active→Migrating (:467 gate, :527 write) and `finalizeAndReset` Migrating→Active (:674-682), the
  latter gated on `stakerCount==0 && totalStaked==0`. `PoolState.Active` is the zero value, so an
  unregistered/never-migrated token reads Active — registration is gated separately by `poolExists`.
- **P8 (VERIFIED-BY-READING) — snapshot immutability.** `migrationInfo[token]` is written only at
  :543 and cleared at :680; nothing in `batchMigrate`/`userMigrate`/`_exitPosition` mutates it, so
  `credit_i = p_i·min(R,P)/P` is order- and batch-composition-independent.
- **P9 (VERIFIED-BY-READING) — migration conservation.** `S=min(R,P)`; `Σ floor(p_i·S/P) ≤ S ≤ R`
  and `R` is measured as the contract's own balance (:538) capped at `P`. The idle pile always
  covers every outstanding credit.
- **P10 (VERIFIED-BY-READING) — `rescueERC20` cannot cross migration credits.** While Migrating
  `yieldStrategy==0`, so `reserved = totalStaked`. Rescuable
  `= bal − reserved = (R − Σ_exited credit) − (P − Σ_exited p) = −(P−R)·Σ_remaining p / P ≤ 0`.
  The guard is exactly tight: nothing is rescuable until the pool is fully drained.
- **P11 (ASSUMED)** — `IYieldStrategy.deposit` returns credited principal ≤ amount, and `withdraw`
  moves at least the balance delta measured. Not verifiable from this contract.
- **P12 (VERIFIED-BY-READING) — `claim` is not gated on `poolState`.** A user with `amount==0` and a
  non-zero backlog can claim during Migrating and after `finalizeAndReset`; `_exitPosition`
  early-returns at :599 for `amt==0` **before** zeroing `unclaimedReward`, so `batchMigrate` never
  confiscates a fully-withdrawn user's backlog.
- **P13 (VIOLATED / see finding LOCAL-001) — index-before-supply-change.** `emergencyWithdraw`
  :394-411 decrements `pool.totalStaked` **without** calling `_updatePool` first.

## 3. Value-flow map

**Principal in:** `stake` / `depositFor` → `_pullToken` (measured delta, FoT-tolerant) →
`_routeDeposit` → `strategy.deposit` (returns `credited`, may be < received) or idle hold.
Moves together: `user.amount += credited`, `pool.totalStaked += credited`, `user.rewardDebt` reset,
`_stakers.add`.

**Principal out:** three doors.
1. `withdraw` — `_routeExit(guard=true)`; internal accounting decremented by the **requested**
   `amount`, user paid the **measured received** `payout`. Under-par: served from the on-contract
   buffer plus `strategy.relinquishPrincipal(amount)`, else reverts.
2. `emergencyWithdraw` — `_routeExit(guard=false)`, full position, all reward forfeited.
3. Migration — `_exitPosition` computes `credit = p_i·min(R,P)/P` from the idle pile;
   `batchMigrate` transfers the aggregate to the migrator, `userMigrate` to the user.

**Reward (changed by story-022):** accrue → `accAntimatterPerShare` (pool-level, `_updatePool`);
settle → `unclaimedReward[token][user]` (`_settle`, `withdraw` :362); pay → `antimatter.mint`
(`claim` :385, `_exitPosition` :620). `rewardDebt` is the per-user baseline and is re-based at every
settle. `emergencyWithdraw` :404 destroys the backlog.

**Rounding (all floor, all protocol-favouring):**
`perSecond = amountPerDay/86400` :216; `acc += reward*1e18/totalStaked` :824;
`pending = amount*acc/1e18 − rewardDebt` :353/380/609; `rewardDebt = amount*acc/1e18` :336/356/384/716;
`credit = amt*S/P` :605. Migration floor-dust stays in the old staker (protocol-owned).

## 4. Trust boundaries

| Callee | Reachable by | Assumption |
|---|---|---|
| `antimatter.mint` (:385, :620) | any user via `claim`; migrator via `batchMigrate`; any migrating user via `userMigrate` | this contract is a live approved minter. Antimatter reverts `NotApprovedMinter(caller)` otherwise. **Untrusted-availability: see LOCAL-002.** |
| `IERC20(token)` transfer/transferFrom/balanceOf | any staker | standard ERC20; FoT tolerated via measured deltas; no callback assumption but no reentrancy exposure (nonReentrant + CEI) |
| `IYieldStrategy` deposit/withdraw/principalOf/totalBalanceOf/relinquishPrincipal | any staker (indirectly), owner | semi-trusted, owner-wired. Can grief by reverting or mis-reporting `principalOf`; `initiateMigration` :513 hard-requires `principalOf==0` post-exit |
| `migrator` (`CrossVersionMigrator` / `InPlaceMigrator`) | owner-set | trusted to redeposit what it receives; the staker gives it the aggregate credit |
| `pauser` | owner-set | may halt `stake`/`withdraw`/`claim` but not `emergencyWithdraw`/migration |

## 5. Local findings

**LOCAL-001 — `emergencyWithdraw` mutates `totalStaked` without settling the pool (low-local).**
:394-411 has no `_updatePool(token)`. The window `[lastRewardTime, now]` is later accrued against
the *reduced* `totalStaked`, so the exiting user's share of that window is silently redistributed
to survivors. **The emission cap is NOT broken** (`_updatePool` still folds exactly
`elapsed·rate`), so this is a redistribution, not over-emission — materially different from the
`phoenix-nft-staking` `emergencyWithdraw` finding of the same shape. The exiting user forfeits all
reward by design, so the redistribution is arguably intended; flagged because it is undocumented
and because it makes `pendingReward` for survivors jump discontinuously.

**LOCAL-002 — story-022's mint-robustness does NOT extend to the terminal-migration exits
(medium-local, needs interaction confirmation).** The plan (`docs/deferred-reward-accrual-plan.md`
§2) and `CLAUDE.md` claim the principal paths no longer depend on the reward token. That holds for
`stake` / `withdraw` / `emergencyWithdraw`, but `_exitPosition` :619-621 still calls
`antimatter.mint`, and it is the **only** exit while `poolState == Migrating`
(`emergencyWithdraw` :397 and `withdraw` :347 both require Active). If Antimatter de-approves this
staker — or reverts for any reason — mid-migration, both `batchMigrate` and `userMigrate` revert
and 100% of the pool's principal is trapped with no hatch, because `finalizeAndReset` requires an
empty pool. The safe shape would mirror `claim`: book the owed amount and pay principal
unconditionally. CLAUDE.md's blanket claim ("a revoked minter role … can no longer brick a
principal path") is over-broad as written.

**LOCAL-003 — `antimatterPerDay` during Migrating does not settle (informational).** :215 calls
`_updatePool`, which no-ops while Migrating, so the rate is written without a settle. Harmless
because accrual is frozen and `finalizeAndReset` :681 fast-forwards `lastRewardTime`. Recorded so
a future edit that removes the fast-forward is recognised as a regression.

**LOCAL-004 — reward backlog is left behind by a cross-version migration (informational).**
`unclaimedReward` is per-staker state. A user fully exited via `batchMigrate` has their backlog
minted, but a user who had already withdrawn to zero keeps a backlog on the OLD staker (P12). The
old staker must therefore remain an approved Antimatter minter and unpaused indefinitely after a
cross-version hop, or that backlog is stranded. Runbook obligation, not guarded on chain.
