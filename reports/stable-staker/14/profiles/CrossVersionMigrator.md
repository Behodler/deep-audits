# Contract Profile — src/CrossVersionMigrator.sol

- Project: stable-staker @ 8856781 (story-018). NEW file, 162 lines.
- Baseline: d95f4a6 (did not exist). Supersedes deleted `src/StableStakerMigrator.sol`.
- solc: `^0.8.20` (project pins 0.8.28) — checked arithmetic throughout, no `unchecked`, no assembly except a `staticcall` via the high-level `address.staticcall`.
- Inheritance: `Ownable` (OZ v5.6.1) only. NO `ReentrancyGuard`, NO `Pausable`.
- Libraries: `SafeERC20` for `IERC20`.

## State variables

| Name | Type | Mutability | Invariant |
|---|---|---|---|
| `oldStaker` | `IStableStakerMigratable` | `immutable`, public | non-zero (ctor `require`); can never be retargeted |
| `newStaker` | `IStableStakerMigratable` | `immutable`, public | non-zero (ctor `require`); can never be retargeted |
| `_owner` (Ownable) | `address` | mutable via `transferOwnership` | sole caller of both state-changing fns |

**There is no mutable storage of the migrator's own.** The contract is stateless between calls except for
Ownable's owner slot. Consequence: *no per-batch bookkeeping is carried forward*, and there is no
`parked`/`totalParked` floor of the kind `InPlaceMigrator` maintains.

Constructor does **not** check `oldStaker != newStaker`. A same-staker misconfiguration is not rejected at
construction, but it self-blocks at runtime (see PROP-CVM-08).

## External / public functions

| Function | Visibility | Access control | Reentrancy guard | State written | External calls |
|---|---|---|---|---|---|
| `initiateMigration(address token)` | external | `onlyOwner` | none | none (own state) | `oldStaker.initiateMigration(token)` |
| `migrate(address token, address[] calldata users)` | external | `onlyOwner` | none | none (own state) | `oldStaker.batchMigrate`, `IERC20(token).forceApprove`, `newStaker.depositFor` xN, `staticcall STAKER_VERSION()` x2 |
| `versionOf(address staker)` | public view | none | n/a | none | `staker.staticcall(STAKER_VERSION())` |
| `owner()/transferOwnership()/renounceOwnership()` | Ownable | `onlyOwner` | none | `_owner` | none |

`token` in `migrate` is **caller-supplied and unvalidated** — it is the address the migrator
`forceApprove`s and the address both stakers are asked to operate on. Trust rests entirely on
`onlyOwner` plus the two stakers' own `poolExists(token)` gates (an unregistered token reverts on
`batchMigrate`).

There is **no `receive()`, no `fallback()`, no `payable` function** — ETH cannot be sent to it by a plain
transfer (only by selfdestruct/coinbase).

## Value flow of `migrate(token, users)`

```
oldStaker --(safeTransfer: total = Σ amounts[i])--> CrossVersionMigrator
CrossVersionMigrator --(forceApprove newStaker, total)-->
newStaker --(safeTransferFrom amounts[i] from migrator, ∀ i with amounts[i]>0)--> newStaker
   (and, if the destination pool has a yield strategy, onward into that strategy)
```

phUSD never touches the migrator: `oldStaker._exitPosition` mints each user's frozen pending phUSD
directly to the user inside `batchMigrate`.

## ANSWER 1 — Exact token conservation identity of a `migrate()` call

Let `B` = migrator's `token` balance before the call, `amounts = oldStaker.batchMigrate(token, users)`,
`total = Σ_i amounts[i]`, and `K = { i : amounts[i] > 0 }`.

**Enters:** `batchMigrate` performs `IERC20(token).safeTransfer(msg.sender, total)` iff `total > 0`
(StableStaker.sol:517). Inflow = `total` exactly (standard ERC20).

**Leaves:** the loop calls `newStaker.depositFor(token, users[i], amounts[i])` for each `i ∈ K`.
`StableStaker.depositFor` → `_pullToken(token, msg.sender, amount)` → `safeTransferFrom(migrator, staker,
amounts[i])` for the **full** `amounts[i]` — never a partial pull. Outflow = `Σ_{i∈K} amounts[i]`.

Since every `i ∉ K` contributes `amounts[i] == 0`, `Σ_{i∈K} amounts[i] == Σ_i amounts[i] == total`.

**Identity (standard, non-rebasing, non-fee-on-transfer ERC20):**

> `balance_after == balance_before` — inflow `total` == outflow `total`. The migrator is a **strict
> pass-through with exactly zero residual per call**. Nothing can remain.

**Residual allowance:** `forceApprove(newStaker, total)` grants exactly `total`; the loop causes the
newStaker to pull exactly `total`. **Ending allowance == 0.** (PROP-CVM-03.)

**Caveats to the identity, all verified as the only escapes:**
- **`total == 0` short-circuit** (line 125-128): no transfer in, no approve, no deposits, event emitted with
  zeros, `return`. Balance unchanged, allowance untouched. Safe.
- **Fee-on-transfer / rebasing `token`:** the inflow leg delivers `total − fee`, but the outflow leg still
  demands `total`, so the final `depositFor` reverts on insufficient balance and the whole call reverts
  atomically. (FoT is C4 known-invalid; recorded here only as a boundary of the identity.)
- **Pre-existing balance `B > 0`** (donation, prior FoT dust, misdirected transfer): the identity is
  *delta*-zero, not *absolute*-zero. `B` is untouched by `migrate` and, per ANSWER 4, is **permanently
  unrecoverable**.
- **Duplicate addresses in `users`:** the second occurrence hits `_exitPosition` with a zeroed position and
  returns 0, so no double-credit and no double-pull. Identity holds.
- **Partial failure:** any revert (an unregistered destination token, a `Migrating` destination pool, a
  zero-credit user — see ANSWER 2) reverts the entire transaction. There is **no partial-completion state**
  in which value could be stranded mid-flow. Atomicity is what protects the migrator here, not a guard.

## ANSWER 2 — Can `StableStaker.depositFor` credit LESS than it pulls?

**YES. Two independent shrink points, and the shortfall is never refunded.**

`StableStaker.sol:625-651`:
```solidity
uint256 received = _pullToken(token, msg.sender, amount);   // balance-delta measured
uint256 credited = _routeDeposit(token, received);          // strategy.deposit(...) return
require(credited > 0, "StableStaker: nothing credited");
info.amount   += credited;
pool.totalStaked += credited;
```

- `_pullToken` (`:750`) `safeTransferFrom`s the **full `amount`** out of the migrator, then measures the
  staker's balance delta. Shrink point 1: `received ≤ amount`, with a strict `<` only for
  fee-on-transfer/rebasing tokens. The fee is lost to the token contract; the migrator still paid `amount`.
- `_routeDeposit` (`:767`) returns `amount` verbatim when `yieldStrategy[token] == address(0)` (idle hold),
  but otherwise returns `strategy.deposit(token, received, address(this))` — **the principal the strategy
  actually books**. For an AMM/market strategy this is haircut below `received`. Shrink point 2:
  `credited ≤ received`.

**Chain: `credited ≤ received ≤ amount`.**

**Where the shortfall goes:** the whole `received` is pulled into the strategy by `strategy.deposit`; only
`credited` is booked as the client's principal. The difference `received − credited` remains **inside the
destination strategy as protocol-owned slippage** — it is not left in the migrator, not left idle in the
staker, and not creditable to any user. Internal accounting stays *self*-consistent (`info.amount` and
`pool.totalStaked` both move by `credited`, matching `strategy.principalOf`), so there is **no
`totalStaked`-vs-strategy desync** — the user is simply credited less than the migrator paid.

This is exactly the "migration slippage" that `InPlaceMigrator._reinjectWithTopup` grosses up and re-injects
(story-013 M-01 fix). **`CrossVersionMigrator` deliberately carries no equivalent** (contract NatSpec section
(E)) — a cross-version hop through a haircutting or underwater destination strategy delivers the user
strictly less than the snapshot credit that left the old staker, with no top-up and no event recording the
loss (`DepositedFor` emits `credited`, not `amount`; `MigratedAcrossVersions` emits `total`, the *source*
sum). **The shortfall is silently invisible from the migrator's own event stream.**

**Zero-credit boundary — a hole in the batch-survival guard.** `require(credited > 0)` reverts, and
`CrossVersionMigrator`'s `if (amounts[i] > 0)` skip (line 134) tests the **source-side** snapshot credit,
not the destination-side booked credit. A user with `amounts[i] > 0` whose destination-strategy deposit
rounds to zero therefore **reverts the entire `migrate()` batch**, which is precisely the failure mode the
skip guard was written (per NatSpec (D)) to prevent. Recorded as PROP-CVM-06 = **violated**; handed to
code-scanner / econ-scanner for exploitability and impact.

## ANSWER 3 — The PoolState machine (StableStaker)

```solidity
enum PoolState { Active, Migrating }   // zero value == Active, by design
mapping(address => PoolState) public poolState;
```

**States:** exactly two. Default `0 == Active`, so every pre-existing registered token behaves as before.
`poolState` is the *sole* gate source (a boolean inside `MigrationInfo` was removed in favour of it).

**Transitions (exactly two, both one-way per engagement):**

| Transition | Function | Access | Preconditions |
|---|---|---|---|
| `Active → Migrating` | `initiateMigration(token)` `:433` | `onlyMigrator` + `nonReentrant` + `poolExists` | `poolState == Active`; strategy exit must fully drain (`principalOf == 0`) |
| `Migrating → Active` | `finalizeAndReset(token)` `:602` | `onlyOwner` + `poolExists` (**no** `whenNotPaused`, **no** `nonReentrant`) | `poolState == Migrating` && `_stakers[token].length() == 0` && `totalStaked == 0` |

**Gating map — `require(poolState == Active)`:**
`setYieldStrategy` `:228` · `stake` `:301` · `withdraw` `:322` · `emergencyWithdraw` `:366` ·
`initiateMigration` `:434` · **`depositFor` `:634`**

**Gating map — `require(poolState == Migrating)`:**
`batchMigrate` `:505` · `userMigrate` `:565` · `finalizeAndReset` `:603`

**Ungated by state (behaviour still state-dependent):**
- `claim` `:347` — no `poolState` check. It calls `_updatePool`, which **no-ops while Migrating**, so it
  mints only the frozen snapshot pending and sets `rewardDebt = amount·acc/PREC`. `_exitPosition` then
  computes `pending = amount·acc/PREC − rewardDebt == 0`. **No double-mint. Verified (PROP-SS-05).**
- `pendingReward` `:653` — projects forward only when `Active`; returns the frozen pending while Migrating,
  matching what the exit mints.
- `rescueERC20` `:818` — no state gate. Its `reserved` floor is `totalStaked` **only when
  `yieldStrategy[token] == address(0)`**. `initiateMigration` clears the strategy to `address(0)` (`:466`),
  so during Migrating the floor is correctly `totalStaked` and the realized pile `R` is protected as
  positions exit. Verified.

**Terminality:** while `Migrating`, `stake`/`withdraw`/`emergencyWithdraw`/`depositFor` are all blocked, so
`P = totalStaked` at the snapshot can only shrink via `_exitPosition`. `_updatePool` is frozen. The **only**
route back to `Active` requires a fully-drained pool, so no stale `userInfo` can survive into a revived pool.

**Implication for the migrator:** `depositFor`'s `Active` requirement means the **destination** staker's pool
must NOT be under terminal migration. `migrate()` therefore cannot be run "in reverse" through the same
staker, and cannot bounce users into a destination that is itself mid-migration.

## ANSWER 4 — Rescue / sweep path, and stranded tokens

**`CrossVersionMigrator` has NO rescue path of any kind.** Full inventory of its code paths:
`initiateMigration`, `migrate`, `versionOf`, `_versionOf`, plus Ownable's three. There is **no
`rescueERC20`, no `sweep`, no `withdraw`, no `receive`, no `fallback`, no `delegatecall`, no self-destruct,
no upgrade path.**

**This is an explicit asymmetry with its sibling.** `InPlaceMigrator` *does* have
`rescueERC20(token, to, amount)` fenced below the `totalParked[token]` floor (section (G)). The
`CrossVersionMigrator` NatSpec discusses immutability (B), zero-credit skips (D), haircuts (E) and the
version probe (F) but is **silent on recovery** — nothing in the source records that the omission was a
decision rather than an oversight.

**Can any token become stranded?** Not by the contract's own logic — the per-call conservation identity is
delta-zero and every failure mode reverts atomically. But once a balance arrives by **any** route it is
**permanently and irrecoverably locked**:
1. A direct ERC20 transfer / airdrop / faucet mistake to the migrator address.
2. Fee-on-transfer or rebasing `token` — a positive rebase between the `batchMigrate` inflow and the
   `depositFor` outflows leaves the excess behind forever.
3. A donation of the migrated stable made *deliberately* to cover an anticipated shortfall — there is no
   mechanism that would consume it (the loop pulls exactly `amounts[i]`, never more), so it just sits.
4. ERC721 / ERC1155 sent via a non-safe transfer (safe transfers revert — no receiver hooks implemented).
5. ETH forced in by `selfdestruct` or block-reward payout.

The operational mitigation is that the contract is intended to hold a balance only *within* a single
transaction. The residual risk is bounded by whatever is mistakenly sent to it. Handed to
severity-classifier as an operational/QA-class observation, not adjudicated here.

## ANSWER 5 — State a second `migrate()` batch inherits from the first

**From the migrator itself: nothing.** It has no mutable storage. Specifically:

- **Residual allowance to `newStaker`: exactly 0.** Batch 1 approves `total₁` and the destination pulls
  `total₁`. Even if that were not exact, batch 2 calls `forceApprove(newStaker, total₂)` — a **set**, not an
  **increase** — so any residue would be *overwritten*, never accumulated. `forceApprove` also handles the
  USDT-style non-zero-to-non-zero approve revert. **No dangling-allowance carry. Verified (PROP-CVM-03).**
- **Residual token balance: 0** (per ANSWER 1), so batch 2 starts from a clean balance and cannot
  accidentally spend batch 1's leftovers.
- **No batch counter, no processed-user set, no re-entrancy flag, no pause flag.** Batches are fully
  independent and idempotent-by-source: re-passing an already-migrated user yields `amounts[i] == 0` from
  `_exitPosition` and is skipped.

**Inherited from the counterparties (this is where all cross-batch coupling lives):**
- `oldStaker.poolState[token] == Migrating` persists — required, and `initiateMigration` must NOT be called
  again (it would revert on `poolState != Active`, so the flow is naturally idempotent-guarded).
- `oldStaker.migrationInfo[token] = (R, P)` is **immutable for the life of the migration**. Every batch
  divides by the same fixed `P`, which is what makes credits order- and batch-composition-independent.
  `Σ_all batches amounts ≤ R` holds globally, not just per batch.
- `oldStaker.poolInfo[token].totalStaked` and `_stakers[token]` shrink monotonically across batches.
- `newStaker.poolInfo[token].totalStaked` and each `userInfo` grow monotonically; a user appearing in two
  batches is *added to* (`info.amount += credited`) — no overwrite, and `_settle` runs first so their
  accrued reward is minted before the reward-debt rebase. Verified safe.
- `newStaker.poolState[token]` must remain `Active` for every batch. If anyone puts the destination into
  terminal migration between batches, all subsequent batches revert (and the users already moved are then
  in a `Migrating` pool). Operational ordering hazard, handed downstream.

## Verified local properties

| ID | Property | Confidence |
|---|---|---|
| PROP-CVM-01 | Both migration targets are `immutable`; no setter exists. A compromised owner key cannot retarget `depositFor` at a drain contract. | **verified** |
| PROP-CVM-02 | Per-call token conservation is delta-zero: inflow `total` == outflow `total` (standard ERC20). | **verified** |
| PROP-CVM-03 | Ending allowance to `newStaker` is 0 after every `migrate`; `forceApprove` overwrites rather than accumulates. | **verified** |
| PROP-CVM-04 | Both state-changing entry points are `onlyOwner`. No permissionless path exists. | **verified** |
| PROP-CVM-05 | `versionOf` is advisory-only: no control flow branches on it; it feeds only the event. | **verified** |
| PROP-CVM-06 | The `amounts[i] > 0` skip guarantees a batch survives a zero-credit user. | **VIOLATED** — it tests the *source* credit; a nonzero source credit that the *destination* strategy books as 0 still trips `require(credited > 0)` and reverts the batch. |
| PROP-CVM-07 | Contract holds no balance across transactions. | **likely** — holds by its own logic; defeated by any external donation, with no recovery (ANSWER 4). |
| PROP-CVM-08 | `oldStaker == newStaker` misconfiguration is inert: `initiateMigration` sets `Migrating`, and `depositFor` requires `Active`, so `migrate` always reverts. No silent loss. | **verified** (defence is emergent, not an explicit ctor check) |
| PROP-CVM-09 | No unbounded-loop *self*-DoS: both loops are over the owner-supplied `users` array; the owner controls batch size and pages off-chain via `getStakersRange`. Gas cost is O(users), and an over-large batch simply reverts on gas — no state corruption, retryable with a smaller batch. | **verified** |
| PROP-CVM-10 | Checked arithmetic everywhere; `total += amounts[i]` cannot overflow in practice (`Σ ≤ R ≤ token supply`). No `unchecked`, no assembly arithmetic. | **verified** |
| PROP-CVM-11 | No weak randomness, no `block.timestamp`/`prevrandao`/`blockhash` use anywhere. | **verified** |
| PROP-CVM-12 | No initializer / proxy / storage-layout concern — plain constructor deployment, no `delegatecall`. | **verified** |
| PROP-CVM-13 | No inbound ERC721/ERC1155/ERC777 receive hooks implemented; no `_safeMint`/`safeTransfer` sites. | **verified** |

## Could NOT verify locally

- **CVM-U1 — reentrancy surface.** `migrate` has no `nonReentrant`. Every reachable callback is via the
  arbitrary `token` address (`forceApprove` and the destination's `transferFrom` can invoke an ERC777
  `tokensToSend`/`tokensReceived` hook). Re-entering `migrate`/`initiateMigration` requires the owner, and
  both stakers guard themselves with `nonReentrant`, so the classic path is closed — but a hook that
  re-enters the *destination staker* directly is outside this contract's local scope. **Deferred to
  code-scanner.**
- **CVM-U2 — `versionOf` revert propagation.** `versionOf` is called *inside* `migrate` (lines 126, 141) with
  no try/catch. A probed staker returning malformed ABI data would revert the whole batch. Both stakers are
  immutable and owner-chosen, so this is a wiring concern, not an attack surface — but the "advisory only"
  claim in NatSpec (F) is not strictly true: an advisory probe that can revert the batch is load-bearing.
  **Deferred (cross-contract).**
- **CVM-U3 — economic magnitude of the missing top-up** (ANSWER 2). Local analysis proves `credited` can be
  less than `amount` and that no compensation exists; whether that constitutes user loss vs. deliberate
  product asymmetry needs the destination strategy's behaviour. **Deferred to econ-scanner.**
- **CVM-U4 — two-sided wiring.** NatSpec (C) requires `setMigrator` on BOTH stakers, `addToken` on the
  destination, and phUSD minter authorization for the destination. None is asserted on-chain; a missing leg
  produces a mid-flow revert (safe) except that `initiateMigration` on the source is **terminal and
  irreversible** and can succeed even when the destination is unwired. **Ordering hazard, deferred.**

## Trust boundaries

| Counterparty | Reached via | Trust level | Notes |
|---|---|---|---|
| `oldStaker` (`IStableStakerMigratable`) | `initiateMigration`, `batchMigrate` | **trusted** (immutable, owner-chosen at deploy) | Must have this migrator as its `migrator`. Its `batchMigrate` return array is taken at face value and drives every subsequent transfer. |
| `newStaker` (`IStableStakerMigratable`) | `depositFor` | **trusted** (immutable, owner-chosen) | Pulls the scoped approval. Immutability is the whole defence. |
| `token` (arbitrary ERC20, caller-supplied per call) | `forceApprove`, and indirectly `transferFrom` | **semi-trusted / untrusted** | Assumed standard: no FoT, no rebase, no transfer hooks. Owner-supplied per call. |
| `versionOf` target | `staticcall` | untrusted-but-inert | Return value never branched on; can still revert the batch (CVM-U2). |
| Owner | both entry points | **trusted, non-malicious** (Law 3) | Footgun surface: batch composition, ordering, and the irreversible `initiateMigration`. |

## Complexity

LOC 162 (≈45 executable) · functions 4 (2 state-changing, 1 public view, 1 internal view) · external call
sites 5 · state variables 2 (both immutable) · loops 2 (both O(`users.length`), owner-bounded).
