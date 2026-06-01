# StableStaker — Terminal Migration Mode (design plan)

**Status:** proposal / design plan (not yet implemented)
**Author:** drafted with Claude Code from a design discussion with the maintainer
**Target contract:** `lib/stable-staker/src/StableStaker.sol` @ `0812167` (+ `StableStakerMigrator.sol`)
**Closes / supersedes findings:**

- `b5218ab2` — *Sequential migrateOut batches through an AMM-backed strategy distribute non-uniform haircuts across identical-principal users* (ss2m1 / M-01). **Root cause.**
- `3d61c955` — *Underwater-pool migration bricked by requested-vs-received accounting mismatch.* Collaterally closed (paging no longer routes through the strategy).
- `69c7666e` — *Underwater withdraw buffer is FCFS at par.* No longer reachable via migration (there is no par/FCFS resume path); steady-state buffer behaviour is unchanged.

---

## 1. Problem recap

`migrateOut` (`StableStaker.sol:301-349`) re-credits an underwater migration pro-rata, but computes the haircut ratio **per `migrateOut` call (per batch)**: it sums `totalPrincipal` over the batch (`:325`) and divides this batch's realized `payout` by it (`:344`). When the yield strategy realizes value through an AMM with price impact, each batch's aggregate exit moves the pool price, so earlier batches realize a smaller haircut than later ones. Two users with identical principal are re-credited materially different amounts based solely on batch placement — the M-01 fix's stated uniform-pro-rata intent is violated for slippage-bearing strategies.

The fix collapses the realization to **one** event and distributes a **fixed** snapshot pro-rata, so distribution becomes order- and method-independent.

## 2. Goals / non-goals

**Goals**

- Uniform treatment of equal principal regardless of batch placement *or* exit method (operator batch vs. user self-exit).
- Preserve the documented economic invariant: stakers receive **principal** back (plus accrued phUSD), not strategy yield, in the healthy case.
- Preserve an always-available, permissionless escape hatch during the migration window.
- Eliminate the requested-vs-received per-batch accounting mismatch.

**Non-goals**

- Changing steady-state staking, reward accounting, or the steady-state underwater-buffer behaviour.
- Mitigating `rescueERC20` owner reach — see §10 (accepted centralization risk).
- Supporting return-to-healthy after migration begins — migration mode is **terminal** by design (§3).

## 3. State machine — terminal, per-token

Migration is a **terminal, per-token** state. Once `initiateMigration(token)` is called, that token's pool can never return to healthy operation on this contract.

```
        healthy ──initiateMigration(token)──▶ migrating(token)   [terminal]
```

**Why terminal.** `initiateMigration` performs a full `IYieldStrategy.totalWithdrawal(token, address(this))`, liquidating the entire strategy position into the contract. The motivating events — protocol upgrade or the underlying vault winding down — have no "healthy" state to return to: re-entry would require re-depositing into a strategy that may no longer exist and would make the snapshot ratio stale against a re-grown position. Terminal mode removes snapshot-staleness, resume races, and dual-state complexity by construction.

State is **per token** (`poolInfo`/`yieldStrategy` are already per token), so migrating one token does not affect other pools.

### New storage (per token)

```solidity
struct MigrationInfo {
    bool    active;            // migration mode engaged (terminal once true)
    uint256 realized;          // R: token balance realized by the full strategy exit
    uint256 principalSnapshot; // P: poolInfo[token].totalStaked captured at initiateMigration
}
mapping(address => MigrationInfo) public migrationInfo;
```

`R` and `P` are **immutable for the life of the migration** — every payout divides by the snapshot `P`, never a re-summed batch total. This is the single correctness lynchpin (see §9).

## 4. `initiateMigration(address token)` — owner/migrator only

Preconditions: `poolExists(token)`, `!migrationInfo[token].active`.

1. `_updatePool(token)` once to settle rewards to the current block, then **freeze emissions** for this token (subsequent `_updatePool` is a no-op while `active`). Each user's pending phUSD is now fixed at the snapshot.
2. Read `P = poolInfo[token].totalStaked` (== Σ `user.amount`, maintained in lockstep).
3. If a strategy is set: `balanceBefore = token.balanceOf(this)`; `strategy.totalWithdrawal(token, address(this))`; `R = token.balanceOf(this) - balanceBefore`. If no strategy is set, the principal already sits idle: `R = P` (no slippage event).
4. **Require the exit is complete.** After `totalWithdrawal`, require `strategy.principalOf(token, address(this)) == 0` (and optionally `totalBalanceOf == 0`). A vault that can only exit in tranches / via a withdrawal queue would otherwise understate `R` and strand value in an abandoned strategy with no second attempt (§11). If the strategy cannot fully exit atomically this must revert and be handled operationally.
5. Clear the strategy wiring: `yieldStrategy[token] = address(0)` and `forceApprove(strategy, 0)`. The contract is now an honest idle-hold for this token; `_routeExit`/`_isUnderwater` are not consulted by the migration paths anyway (they pay from idle balance).
6. **Sweep par-surplus to the new contract as buffer.** Compute `surplus = R > P ? R - P : 0`. Transfer `surplus` to the configured buffer recipient (the new staker) via a **plain `safeTransfer`** — this lands as idle balance (= buffer) on the new contract, *not* credited to any user via `depositFor`. After the sweep the contract holds exactly `min(R, P)`, which precisely covers all remaining user credits (§9). Yield never reaches users; it pre-funds the new contract's buffer. (Per the maintainer, surplus is small in practice — `yield-accumulator` skims it frequently.)
7. Set `migrationInfo[token] = {active:true, realized:R, principalSnapshot:P}`.
8. Emit `MigrationInitiated(token, R, P, surplus)`.

> The buffer recipient (new staker address) is supplied by the migrator/owner — either as a parameter to `initiateMigration` or via a setter — so the old (terminal) staker stays otherwise decoupled from the new deployment.

## 5. The credit formula (used by both exit paths)

For every user with snapshot principal `p_i = user.amount`:

```
credit_i = p_i * min(R, P) / P
```

- **Healthy (`R ≥ P`)** → `credit_i = p_i` (par). Users get exactly their principal; the `R − P` surplus was already swept to buffer (§4.6).
- **Underwater (`R < P`, rare)** → `credit_i = p_i * R / P` — a single uniform haircut for everyone.

Both `R` and `P` are snapshot constants, so `credit_i` depends only on `(p_i, R, P)` — never on live state, batch composition, or ordering.

## 6. `batchMigrate(address token, address[] users)` — migrator only (renamed from `migrateOut`)

Requires `migrationInfo[token].active`. For each user (skip `if (user.amount == 0) continue;` — this also naturally skips anyone who already self-migrated, §7):

1. `pending` phUSD (already frozen at snapshot) → `phUSD.mint(u, pending)`.
2. `credit = user.amount * min(R,P) / P` (using snapshot `R`,`P`).
3. Zero the position: `user.amount = 0`, `rewardDebt = 0`, `poolInfo.totalStaked -= p_i`, `_stakers.remove(u)`.
4. Accumulate `total += credit`.

After the loop, `safeTransfer(total)` to the migrator. The migrator `forceApprove`s the new staker for `total` and calls `depositFor(token, u, credit_i)` per user (existing `StableStakerMigrator.migrate` flow, §8). **No `_routeExit` call, no per-batch re-sum, no requested-vs-received delta.**

## 7. `userMigrate(address token)` — permissionless, migration-only

The escape hatch for the terminal state. `emergencyWithdraw` is for ordinary operation and is **blocked** while migrating (§8); `userMigrate` replaces it for this state and, like it, never depends on the migrator.

Requires `migrationInfo[token].active` and `user.amount > 0`. `nonReentrant`, strict CEI:

1. `pending` phUSD → `phUSD.mint(msg.sender, pending)`.
2. `credit = user.amount * min(R,P) / P`.
3. Zero the position (`user.amount = 0`, `rewardDebt = 0`, `poolInfo.totalStaked -= p_i`, `_stakers.remove(msg.sender)`) **before** the transfer.
4. `safeTransfer(msg.sender, credit)` from the idle pile.
5. Emit `UserMigrated(token, msg.sender, credit)`.

Because the position is zeroed, a subsequent `batchMigrate` `continue`s past this user automatically (no separate "migrated" flag required). The user receives exactly the same `credit_i` they would have via batch — order- and method-independent (§9). They exit the system entirely (tokens to their own wallet); they are **not** re-deposited into the new staker.

## 8. Functions blocked while `migrating(token)` is active

To keep `P` and the per-user snapshot fixed, every position-mutating path on the **old** staker is blocked for that token:

| Function | Healthy | Migrating |
|---|---|---|
| `stake` | ✓ | **blocked** (would pollute the snapshot) |
| `withdraw` | ✓ | **blocked** |
| `emergencyWithdraw` | ✓ | **blocked** (replaced by `userMigrate`) |
| `depositFor` (into old staker) | ✓ | **blocked** |
| `batchMigrate` | n/a | ✓ (migrator) |
| `userMigrate` | reverts | ✓ (permissionless) |

`claim` may remain callable or be folded into the migration mint; since emissions are frozen at the snapshot, pending is fixed either way.

## 9. Invariants & order-independence

Let `S = min(R, P)`. Total credited across **all** users, in **any** interleaving of `batchMigrate` and `userMigrate`:

```
Σ credit_i = Σ floor(p_i · S / P) ≤ (S / P) · Σ p_i = (S / P) · P = S = min(R, P) ≤ R
```

- **Conservation / no over-draw.** Post-surplus-sweep the pile holds exactly `min(R,P)`, and `Σ credit_i ≤ min(R,P)`. The pile is always sufficient; the last claimer can never be starved. Floor-division dust (`min(R,P) − Σ credit_i`) remains protocol-owned in the terminal staker (owner-rescuable, §10), consistent with the existing dust convention (`StableStaker.sol:339`).
- **Order/method independence.** `credit_i` is a pure function of `(p_i, R, P)`. Neither the order of exits, the batch composition, nor the choice of batch-vs-self changes any user's payout. This is the formal statement of the fix.
- **Equal principal ⇒ equal payout**, regardless of batch placement — directly negating ss2m1.
- **Yield ownership preserved (healthy case).** `R ≥ P ⇒ credit_i = p_i`; the surplus is swept to buffer, never to users — consistent with the documented "stakers get principal + phUSD only" invariant.
- **Cross-method consistency.** A self-migrating user gets `p_i·S/P`; a batch-migrated user gets `p_i·S/P` and the residual `p_i·(R−S)/P` they "leave behind" is part of the swept surplus. The remaining users' denominator stays the fixed `P`, so their payouts are unchanged.

## 10. Accepted risks (not mitigated)

- **`rescueERC20` reaches the idle pile (`0790a76a` / centralization).** During migration the realized cash sits idle with the strategy cleared, so `rescueERC20` can sweep it. **Accepted by the maintainer**: the owner orchestrates migration and could direct funds arbitrarily regardless (e.g. set itself as buffer recipient / migrate balances to a private wallet). This is an owner-trust assumption, documented, not fixed.

## 11. Edge cases & operational notes

- **Atomic full exit required.** `initiateMigration` must realize the entire position in the single `totalWithdrawal` call (§4.4). A closing/illiquid vault that can only exit in tranches understates `R` and strands value in the abandoned strategy — terminal mode gives no retry. Guard with the `principalOf == 0` post-check; handle tranche-exit vaults operationally before declaring terminal.
- **Per-client isolation.** `totalWithdrawal(token, client)` is scoped to a single client. The strategy typically has two clients — the StableStaker and the phUSD-minter / TVL vault. Migrating the StableStaker drains only *its* client position; the TVL vault's `principalOf` and its own exit path are unaffected. **Caveat:** a large single AMM exit transiently moves the *shared pool spot price*, so the other client's mark-to-market `totalBalanceOf` may dip until arbitrage restores it — principal accounting is isolated, spot valuation is not. Worth noting but not a correctness issue for the migrating pool.
- **Dust.** Per-user floor division leaves a tiny residual in the terminal staker; protocol-owned, owner-rescuable. Optionally fold into a final buffer sweep.
- **Multi-token.** The migration flag, snapshot, and frozen emissions are per token; multiple tokens can be migrated independently.

## 12. Migrator (`StableStakerMigrator`) changes

`migrate(token, users)` (currently `StableStakerMigrator.sol:45-68`):

- Call `oldStaker.batchMigrate(token, users)` (renamed) instead of `migrateOut`; it returns the per-user `credit_i` array and transfers `Σ credit_i` to the migrator.
- `forceApprove(newStaker, total)` and `depositFor(token, users[i], credit_i)` per user — **unchanged** logic, now fed snapshot-consistent amounts.
- The par-surplus buffer transfer is handled by `initiateMigration` (§4.6), so the migrator does not need to move surplus; it only ever forwards exact `credit_i` totals it actually received (the redeposit-never-exceeds-received property still holds trivially).

## 13. Test plan (PoC assertions, `workspace/stable-staker/`)

Adapt `test/PoC_M01_PerBatchAmmHaircut.t.sol` against the redesign:

1. **Order/method independence (core).** Two users, equal principal, underwater AMM strategy. Migrate via *any* interleaving — both in one batch / separate batches / one self-migrates / reversed order — and assert **identical** payout in every permutation. (The original PoC's 900k vs 750k disparity must collapse to equal.)
2. **Healthy case = par + buffer.** `R > P` (yield positive): every user re-credited exactly `p_i`; assert `newStaker` idle balance increased by `R − P` (surplus → buffer); assert no user received yield.
3. **Underwater case = uniform haircut.** `R < P`: all users (batch and self) credited `p_i·R/P`; assert `Σ credit ≤ R` and dust ≤ N wei.
4. **Conservation.** `Σ credit + swept surplus + dust == R` exactly.
5. **State guards.** `stake`/`withdraw`/`emergencyWithdraw`/`depositFor` revert while migrating; `userMigrate` reverts when not migrating; `batchMigrate` reverts without `initiateMigration`; migration mode cannot be exited (terminal).
6. **Atomic-exit guard.** A strategy that cannot fully exit makes `initiateMigration` revert on the `principalOf == 0` post-check.
7. **Per-client isolation.** A second client (mock TVL vault) on the same strategy retains its `principalOf` across the StableStaker migration.
