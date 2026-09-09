# Contract Profile — `src/StableStaker.sol`

- **Contract:** `lib/stable-staker/src/StableStaker.sol`
- **Profile timestamp:** 2026-06-08
- **Submodule HEAD:** `f85450b6d73a728f530a97854ecc882151695cd8` (`[story-007] Relinquish strategy principal on buffer withdrawal`)
- **Solidity:** `^0.8.20` (project pins `solc = 0.8.28`; checked arithmetic)
- **LOC:** 733
- **Inheritance chain:** `Ownable`, `Pausable`, `ReentrancyGuard`, `IPausable`
- **Scope of this regression profile:** withdrawal / buffer / yield-strategy-principal / migration logic. The two new commits in scope:
  - `e7bb675` `[story-006]` — `setYieldStrategy` migration guard + drain-old-strategy-on-swap.
  - `f85450b` `[story-007]` — buffer-withdrawal `relinquishPrincipal` reconciliation.

---

## 1. Withdrawal / exit paths and accounting mutation

All principal-moving exits funnel through one internal router: **`_routeExit(token, amount, guardUnderwater)`** at `StableStaker.sol:691-711`. The buffer-routing internal fn is `_routeExit`; there is no separately-named buffer fn.

### `_routeExit` (StableStaker.sol:691-711)

```solidity
function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
    IYieldStrategy strategy = yieldStrategy[token];
    if (address(strategy) == address(0)) {
        return amount;                                   // L693-695  idle hold: tokens already here
    }
    IERC20 t = IERC20(token);
    if (guardUnderwater && _isUnderwater(token, strategy)) {     // L697  buffer branch
        if (t.balanceOf(address(this)) >= amount) {              // L701  buffer can cover full request
            emit BufferWithdrawn(token, msg.sender, amount);     // L702
            strategy.relinquishPrincipal(token, amount);         // L703  <-- story-007 NEW
            return amount;                                       // L704
        }
        revert("StableStaker: strategy underwater");             // L706
    }
    uint256 balanceBefore = t.balanceOf(address(this));          // L708  strategy-redeem branch
    strategy.withdraw(token, amount, address(this));             // L709
    return t.balanceOf(address(this)) - balanceBefore;           // L710  ACTUAL received (balance delta)
}
```

Three branches:
- **Idle-hold** (no strategy, L693-695): returns the requested `amount` unchanged; tokens already sit in the contract.
- **Buffer path** (underwater + guard on + buffer covers, L697-704): pays out of the contract's idle balance, does NOT redeem strategy shares, and (story-007) calls `relinquishPrincipal(token, amount)`. Returns the requested `amount`.
- **Strategy-redeem path** (L708-710): `strategy.withdraw(token, amount, address(this))`, returns the **balance delta** (actual received), which can be `<= amount` after rounding/slippage.

### Public/external exit functions

#### `withdraw(address token, uint256 amount)` — StableStaker.sol:277-303
- `nonReentrant whenNotPaused poolExists`. Reverts if `migrationInfo[token].active` (L281).
- `_updatePool(token)` (L285); computes `pending` (L287).
- **Accounting mutated (unconditionally, before the exit):**
  - `user.amount -= amount` (L288)
  - `pool.totalStaked -= amount` (L289)
  - `user.rewardDebt` reset (L290)
  - staker-set removal if `user.amount == 0` (L291-293)
- Mints `pending` phUSD (L295-297).
- Calls `_routeExit(token, amount, true)` — **guard ON** (L300), then `safeTransfer(msg.sender, payout)` (L301). `clientBalances`/strategy `principalOf` are mutated only via the strategy call inside `_routeExit`: by `relinquishPrincipal` on the buffer branch, or by `strategy.withdraw` on the redeem branch.

#### `emergencyWithdraw(address token)` — StableStaker.sol:322-337
- `nonReentrant` only (works while paused; no `whenNotPaused`). Reverts if `active` (L325).
- Reads full `amount = user.amount` (L327).
- **Accounting mutated:** `user.amount = 0` (L329), `user.rewardDebt = 0` (L330), `poolInfo[token].totalStaked -= amount` (L331), staker-set removal (L332). Reward accounting deliberately untouched (no pending mint) — escape hatch.
- Calls `_routeExit(token, amount, false)` — **guard OFF** (L334): never takes the buffer/relinquish branch; always uses the idle-hold or `strategy.withdraw` redeem branch, accepting the haircut. Then `safeTransfer(payout)` (L335).

#### Terminal-migration exits — `_exitPosition` / `batchMigrate` / `userMigrate`
- `_exitPosition(token, account)` (L477-501): pays the fixed snapshot credit `credit = amt * min(R,P) / P` (L485-486). Mutates `info.amount = 0`, `info.rewardDebt = 0`, `pool.totalStaked -= amt`, staker-set removal (L492-495); mints frozen `pending` (L490, L497-499). **Does NOT call `_routeExit`** — pays from the realized idle pile only.
- `batchMigrate` (L447-468, `onlyMigrator`): loops `_exitPosition`, transfers `Σ credit` to migrator (L466).
- `userMigrate` (L513-522, permissionless): `_exitPosition` then `safeTransfer(credit)` (L520).

### Buffer-path vs strategy-redeem accounting summary

| Variable | Buffer path (`_routeExit` L697-704) | Strategy-redeem path (L708-710) |
|---|---|---|
| `user.amount` | `-= amount` (in `withdraw`, L288) | `-= amount` (L288) |
| `pool.totalStaked` | `-= amount` (L289) | `-= amount` (L289) |
| strategy `principalOf` / `clientBalances[this]` | `-= amount` via `relinquishPrincipal` (L703, **story-007**) | `-= amount` via `strategy.withdraw` |
| strategy `totalDeposited` | `-= amount` via `relinquishPrincipal` | `-= amount` via `strategy.withdraw` |
| vault shares | **untouched** (paid from buffer) | redeemed |
| tokens delivered | requested `amount` from idle buffer | balance-delta (actual received) |

Note `clientBalances`/`totalDeposited`/`principalOf` are **strategy-side** state (in `AYieldStrategy`), not StableStaker storage. StableStaker has no `principalOf`/`clientBalances`/`totalDeposited` of its own; its principal ledger is `poolInfo[token].totalStaked` + per-user `userInfo.amount`. `totalDeposited` is the strategy's own field.

---

## 2. Story-007 `relinquishPrincipal` call site

- **Call site:** `_routeExit`, buffer branch, **StableStaker.sol:703**: `strategy.relinquishPrincipal(token, amount);`
- **Argument:** the **requested** withdraw `amount` (the same value just decremented from `user.amount` and `pool.totalStaked` in `withdraw`, and the value paid out of the idle buffer).
- **Trigger conditions (all must hold):** a strategy is set (L692), `guardUnderwater == true` (only `withdraw` passes true — L300), strategy is underwater per `_isUnderwater` (L697 / L666-668), and the idle buffer fully covers the request (L701). Placed **after** `emit BufferWithdrawn` and **before** `return amount` (L702-704).
- **What it reconciles (strategy side, via `AYieldStrategy._relinquishInternal`, reflax `AYieldStrategy.sol:638-654`):** decrements **both** `clientBalances[token][address(this)]` and `totalDeposited[token]` by `amount` (capped to available), touching **no** vault shares. Because `principalOf(token, this)` returns `clientBalances[token][this]` (reflax `AYieldStrategy.sol:494-496), the call reduces the strategy-side principal by exactly the same `amount` that `withdraw` removed from `totalStaked`.

### Invariant restoration — VERIFIED

Before story-007 the buffer branch returned without touching strategy principal, so after a buffer withdrawal `strategy.principalOf(token, this) > poolInfo[token].totalStaked` by exactly `amount` (root cause of finding `dc361b7d` / M-04 in stable-staker-07). With L703 in place:

- `withdraw` does `pool.totalStaked -= amount` (L289), and
- `_routeExit` buffer branch does `strategy.principalOf(this) -= amount` (via L703 → `clientBalances[this] -= amount`).

Both sides drop by the **same** `amount`, so if `principalOf(token, this) == totalStaked[token]` held before the buffer withdrawal, it **still holds after** (the `relinquishPrincipal` cap-to-available cannot under-decrement here because `principalOf >= totalStaked` is the maintained relation and `amount <= user.amount <= totalStaked <= principalOf`). The invariant the migration path relies on (`strategy.principalOf(token, this) == poolInfo[token].totalStaked`) is **restored** after a buffer-path withdrawal. Consequently `initiateMigration`'s `principalOf(this) == 0` post-check (Section 4) becomes satisfiable again — the story-007 fix is the cross-submodule remediation that the M-04 triage `dc361b7d` specified ("Option A formalized").

Confidence: **verified** (static, plus mock parity in `test/mocks/MockYieldStrategy.sol` and the new assertion in `test/YieldStrategyIntegration.t.sol`).

---

## 3. `setYieldStrategy` after story-006 (StableStaker.sol:202-238)

`function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token)`

New guard / behaviour added by `e7bb675`:

1. **Migration guard (L203):** `require(!migrationInfo[token].active, "StableStaker: migrating");` — blocks re-wiring a strategy once a token is in terminal migration (closes M-02 noted in the commit body). Added at the top of the function.
2. **Drain-old-strategy-on-swap (L205-221):** when an old strategy is set, before revoking allowance:
   - reads `uint256 staked = poolInfo[token].totalStaked;` (L214)
   - if `staked > 0` calls `_routeExit(token, staked, false)` (L215-217) — **guard OFF**, same realization path as `initiateMigration`, draining the old strategy's full client position into this contract. Skipped at `staked == 0` because the strategy's `withdraw` reverts on a zero amount (first-adoption / idle).
   - then `forceApprove(address(old), 0)` (L220).
3. **Re-custody into new strategy (unchanged, L223-235):** set `yieldStrategy[token] = strategy`; if non-zero, `forceApprove(strategy, max)` (L227) and sweep idle balance via `strategy.deposit(token, idleBalance, this)` (L231-234). The drained funds from step 2 land in idle balance and are re-deposited here, so the whole position moves YS1→YS2 in one call.
4. Emits `YieldStrategySet(token, old, strategy)` (L237).

Notes for downstream interaction analysis (NOT flagged locally — require cross-contract context):
- The L215 drain uses `_routeExit(..., false)` with guard OFF; if the **old** strategy is underwater this realizes a loss into idle balance (above-par yield left behind as protocol-owned). Whether a swap-while-underwater leaves `totalStaked > recovered idle` (a haircut the protocol absorbs) is a strategy-behaviour concern.
- The drain reads `yieldStrategy[token]` inside `_routeExit` which is still `old` at L215 (assignment happens at L223) — correct ordering.
- `_routeExit(token, staked, false)` will not take the buffer/relinquish branch (guard OFF), so it does NOT use story-007's `relinquishPrincipal`; it does a real `strategy.withdraw`.

---

## 4. `initiateMigration` post-check (StableStaker.sol:387-428)

`function initiateMigration(address token) external nonReentrant onlyMigrator poolExists(token)`

The post-check the desync finding `dc361b7d` said becomes unsatisfiable is at **StableStaker.sol:410-413** (the finding cited pre-fix line numbers L392-395; at HEAD `f85450b` it is L410-413):

```solidity
require(
    address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0,
    "StableStaker: incomplete exit"
);
```

Surrounding flow and the variables it compares:
- `require(!migrationInfo[token].active, ...)` idempotency (L388).
- `_updatePool(token)` settles & freezes emissions (L392).
- `uint256 P = poolInfo[token].totalStaked;` — immutable principal denominator (L396).
- `IYieldStrategy strategy = yieldStrategy[token];` (L397).
- `uint256 R = _routeExit(token, P, false);` — realize the whole position, guard OFF (L405). `strategy.withdraw` caps the request to available principal.
- **Post-check L410-413:** compares **`strategy.principalOf(token, address(this))`** against the literal **`0`** (skipped when no strategy is set). It asserts the realization fully drained the client. With the strategy-side principal capped to `principalOf - P` after withdrawing `P`, this is satisfiable iff `principalOf(this) <= P == totalStaked` before the call — exactly the invariant story-007 restores (Section 2). Pre-story-007, a prior buffer withdrawal left `principalOf > totalStaked = P`, so the residual `principalOf - P > 0` and the require always reverted, bricking terminal migration permanently (no retry). **Story-007 makes this post-check satisfiable again.**
- On success: decouple strategy (revoke allowance L418, clear wiring L419), record `migrationInfo[token] = {active:true, realized:R, principalSnapshot:P}` (L426), emit (L427).

---

## 5. `IYieldStrategy` interface — `relinquishPrincipal` presence and reflax confirmation

StableStaker imports the interface via remap `reflax-yield-vault/interfaces/IYieldStrategy.sol` (`StableStaker.sol:12`), resolving to `lib/stable-staker/lib/reflax-yield-vault/src/interfaces/IYieldStrategy.sol` (reflax submodule HEAD `2f6774d`).

**Yes — the interface declares both primitives:**
- `relinquishPrincipal(address token, uint256 amount)` — `IYieldStrategy.sol:41`. Docstring (L34-40): "Write down the caller's own recorded principal by `amount`, WITHOUT touching the underlying vault's shares… Decrements both `clientBalances[token][msg.sender]` and `totalDeposited[token]`, preserving `totalDeposited == Σ clientBalances`… Over-requests capped… Client-gated (`onlyAuthorizedClient`)."
- `relinquishPrincipalAsOwner(address client, uint256 amount)` — `IYieldStrategy.sol:46` (owner override, same semantics; not called by StableStaker).

**Concrete implementation confirmed (reflax `AYieldStrategy.sol`):**
- `relinquishPrincipal` (L620-622): `onlyAuthorizedClient nonReentrant` → `_relinquishInternal(token, msg.sender, amount)`.
- `relinquishPrincipalAsOwner` (L625-627): `onlyOwner nonReentrant`.
- `_relinquishInternal` (L638-654): requires `token == underlyingToken` and `amount > 0`; caps `amount` to `clientBalances[token][holder]` (L643-646); decrements `clientBalances[token][holder]` and `totalDeposited[token]` by the capped amount (L650-651); **no** deposit/redeem/withdraw/swap/transfer of shares; emits `PrincipalRelinquished` (L653). `principalOf` returns `clientBalances[token][account]` (L494-496), so the primitive directly reduces what StableStaker reads as strategy principal.

The story-007 test mock matches these semantics: `test/mocks/MockYieldStrategy.sol` replaced the no-op stub with a real cap-to-available decrement of `principal[token][msg.sender]` and `totalPrincipal[token]` (commit `f85450b`).

---

## Verified properties

```
noUnboundedLoops:      false  (batchMigrate L458 + getStakersRange L591 loop over caller-supplied/bounded arrays — see local finding)
checkedArithmetic:     true   (^0.8.20 / 0.8.28, no unchecked blocks, no inline assembly)
reentrancyGuarded:     stake, withdraw, claim, emergencyWithdraw, initiateMigration, batchMigrate, userMigrate, depositFor
                       (NOT guarded: rescueERC20 — intentional, trailing transfer, see L724 comment)
accessControlled:      addToken/phUSDPerDay/setMigrator/setPauser/setYieldStrategy/rescueERC20 (onlyOwner);
                       initiateMigration/batchMigrate/depositFor (onlyMigrator); pause (onlyPauser)
initializerProtected:  n/a (non-upgradeable; immutable phUSD set in constructor)
pausable:              true   (Behodler3 pattern; emergencyWithdraw + migration hooks intentionally callable while paused)
migrationGuard:        stake/withdraw/emergencyWithdraw/depositFor/setYieldStrategy all revert while migrationInfo[token].active
storyInvariantRestored: strategy.principalOf(token,this) == poolInfo[token].totalStaked after buffer withdrawal (story-007, VERIFIED)
```

## Local findings (single-contract; not cross-contract)

| id | type | severity | fn | line | note |
|---|---|---|---|---|---|
| LOCAL-001 | unbounded-loop | local-low | `batchMigrate` | 458 | Loops over migrator-supplied `users[]`. `onlyMigrator` (trusted, off-chain batched via `getStakersRange`); DoS surface limited to migrator's own gas. |
| LOCAL-002 | unbounded-loop | local-info | `getStakersRange` | 591 | View; bounded by clamped `[start,end)`; caller paginates. No state change. |

Both are gas-scaling-with-input only, mitigated by access control / pagination — informational, not exploitable by an untrusted party.

## Trust assumptions / interaction-deferred items (for downstream agents)

- **Strategy is a trusted-but-external `AYieldStrategy`** (reflax-yield-vault). `relinquishPrincipal` is `onlyAuthorizedClient`: if the strategy ever de-authorizes StableStaker, the L703 call reverts and the underwater buffer withdrawal reverts (a liveness coupling, not a local bug). Defer exploitability.
- **`relinquishPrincipal` cap-to-available** means if strategy principal were somehow `< amount`, the relinquish under-decrements and the invariant could drift; in the maintained flow `amount <= totalStaked <= principalOf`, so this does not trigger. Cross-contract verification recommended only if a path can make `principalOf < totalStaked`.
- **Buffer funding source:** the idle buffer that pays the underwater branch must be funded (set-aside surplus via strategy `setAsideBuffer`/`skimSurplus`, or donation). Donation-funded buffer is NOT a pump vector (per M-04 triage: a donation never touches strategy `clientBalances`/`totalDeposited`/`totalValue`). Economic fairness of underwater FCFS-at-par is an econ/interaction concern (existing wont-fix), out of local scope.
- **`setYieldStrategy` swap drains old strategy with guard OFF** — realizing a loss if the old strategy is underwater; whether recovered idle < `totalStaked` (protocol-absorbed haircut) is strategy-behaviour, deferred.
- Standard ERC20 assumption for the staked token; `_pullToken` uses balance-delta so it tolerates fee-on-transfer for credit, but fee-on-transfer is out of scope per project known-issues.

## Interface abstraction (external entry points, condensed)

| fn | visibility | access | guard | strategy calls | key state mutated |
|---|---|---|---|---|---|
| `stake(token,amount)` | external | none | nonReentrant, whenNotPaused, !active | `deposit` | user.amount+, totalStaked+ |
| `withdraw(token,amount)` | external | none | nonReentrant, whenNotPaused, !active | `withdraw` OR `relinquishPrincipal` (buffer) | user.amount-, totalStaked-, strategy principal- |
| `claim(token)` | external | none | nonReentrant, whenNotPaused | — | rewardDebt, mints phUSD |
| `emergencyWithdraw(token)` | external | none | nonReentrant, !active | `withdraw` (guard OFF) | user.amount=0, totalStaked- |
| `initiateMigration(token)` | external | onlyMigrator | nonReentrant, !active | `withdraw`(guard OFF)+`principalOf` post-check | migrationInfo set, strategy decoupled |
| `batchMigrate(token,users[])` | external | onlyMigrator | nonReentrant, active | — | per-user zeroed, totalStaked- |
| `userMigrate(token)` | external | none | nonReentrant, active | — | caller zeroed, totalStaked- |
| `depositFor(token,user,amt)` | external | onlyMigrator | nonReentrant, !active | `deposit` | user.amount+, totalStaked+ |
| `setYieldStrategy(token,strat)` | external | onlyOwner | poolExists, !active | `withdraw`(drain old)+`deposit`(sweep new) | yieldStrategy[token], allowances |
| `rescueERC20(token,to,amt)` | external | onlyOwner | reserved-principal check | — | transfers idle/dust only |
| `pause/unpause` | external | onlyPauser / owner|pauser | — | — | paused flag |

External calls: `phUSD.mint` (trusted phoenix FlaxToken), `IYieldStrategy.{deposit,withdraw,relinquishPrincipal,principalOf,totalBalanceOf}` (semi-trusted reflax adapter), `IERC20.{transfer,transferFrom,balanceOf,forceApprove}` (semi-trusted staked token).
