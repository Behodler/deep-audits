# Contract Profile — src/StableStaker.sol (migration surface, full depth)

- stable-staker @ 8856781. 826 lines. Baseline d95f4a6 → HEAD diff is **+16/-8 lines, all
  interface-binding**: `import ./interfaces/IStableStaker.sol`, `is IStableStaker` added to the
  inheritance list, `STAKER_VERSION = 2` constant added, and `override` added to four members
  (`userInfo` mapping, `initiateMigration`, `batchMigrate`, `depositFor`).
- **No behavioural change landed in this contract across stories 014-018.** The `override` keywords are
  compiler bookkeeping; `STAKER_VERSION` is a `public constant` with no reader inside the contract. The
  migration semantics profiled below are unchanged from run-13 and are re-verified here because the new
  `CrossVersionMigrator` is their sole consumer.
- Inheritance chain: `Ownable`, `Pausable`, `ReentrancyGuard`, `IPausable`, **`IStableStaker`** (new)
  → which `is IStableStakerMigratable` (new).

## Golden-rule triad — compile-time binding (story-014)

`StableStaker is IStableStaker is IStableStakerMigratable` makes the three migration functions a
**build-breaking obligation**. Frozen selectors (pinned in `test/GoldenRule.t.sol`):

| Function | Signature | Selector |
|---|---|---|
| `initiateMigration` | `initiateMigration(address)` | `0x71726c92` |
| `batchMigrate` | `batchMigrate(address,address[])` | `0x0ad9aeb9` |
| `depositFor` | `depositFor(address,address,uint256)` | `0xb3db428b` |

All three are `onlyMigrator`. `userInfo` is declared on `IStableStaker` (not the triad) for
`InPlaceMigrator._reinjectWithTopup`; the public mapping's auto-getter carries `override`.

## State variables relevant to migration

| Name | Type | Writers | Invariant |
|---|---|---|---|
| `STAKER_VERSION` | `uint256 constant = 2` | none | **NEW.** No internal reader; probed externally by `CrossVersionMigrator.versionOf`. Deliberately not `1` — the live V1 instance predates it, so a `staticcall` to V1 reverts and must be read as "version 1". |
| `migrator` | `address` | `setMigrator` (onlyOwner) | Sole authority for the triad. Single address — one migrator at a time. |
| `poolState[token]` | `enum {Active, Migrating}` | `initiateMigration`, `finalizeAndReset` | Zero value MUST be `Active`. Sole source of truth for every migration gate. |
| `migrationInfo[token]` | `{realized R, principalSnapshot P}` | `initiateMigration` (set), `finalizeAndReset` (zero) | **Immutable for the life of one migration.** Every credit divides by this fixed `P`, never a re-summed batch total — this is what makes payouts order-, batch-composition- and method-independent (closes ss2m1/M-01). |
| `poolInfo[token].totalStaked` | `uint256` | stake/withdraw/emergencyWithdraw/`_exitPosition`/`depositFor` | While Migrating, only `_exitPosition` may decrement it — every growth path is state-gated off. |
| `yieldStrategy[token]` | `IYieldStrategy` | `setYieldStrategy`, **`initiateMigration` (clears to 0)** | Cleared on migration engagement, so the contract becomes an honest idle-hold and `rescueERC20`'s `reserved` floor correctly becomes `totalStaked`. |
| `userInfo[token][user]` | `{amount, rewardDebt}` | many; `override` added | Zeroed by `_exitPosition`; `finalizeAndReset` requires the staker set empty so no stale position survives a revival. |
| `_stakers[token]` | `EnumerableSet.AddressSet` | add on stake/depositFor, remove on exits | `length() == 0` is the `finalizeAndReset` gate. |

## Migration-surface functions

### `initiateMigration(address token)` — `:433`
`external override nonReentrant onlyMigrator poolExists(token)` · **no `whenNotPaused`** (deliberate:
migration must proceed during an incident).

Preconditions: `poolState == Active`. Effects, in order:
1. `_updatePool(token)` — settles to this block; every subsequent `_updatePool` no-ops (emissions frozen).
2. `P = poolInfo[token].totalStaked` snapshotted.
3. `R = _routeExit(token, P, false)` — full realization via the **client-callable** `strategy.withdraw`,
   underwater guard **OFF**. `totalWithdrawal` is deliberately not used (onlyOwner, two-phase 24h,
   redeems to the strategy owner not this client).
4. `require(strategy == 0 || strategy.principalOf(token, this) == 0, "incomplete exit")` — post-check that
   the client was fully drained. A tranche/queue vault that can only exit partially is rejected rather than
   silently understating `R`. **Terminal mode gives no retry**, so this check is load-bearing.
5. Decouple: `forceApprove(strategy, 0)`; `yieldStrategy[token] = address(0)`.
6. `poolState[token] = Migrating`; `migrationInfo[token] = (R, P)`; emit `MigrationInitiated`.

**Verified properties:** one-shot per engagement (Active gate); `R ≤ P` structurally (`withdraw` caps at
par), and above-par yield is left in the decoupled strategy as protocol-owned value; the `min(R,P)` cap at
`_exitPosition` additionally defends against a stray above-par `R` (e.g. a donation).

**Irreversibility:** this is the only Active→Migrating edge and there is no abort. Once engaged, the pool can
only return to Active by fully draining. `CrossVersionMigrator.initiateMigration` is a bare owner-only
forwarder with **no destination-readiness check**.

### `batchMigrate(address token, address[] calldata users)` — `:497`
`external override nonReentrant onlyMigrator poolExists(token) returns (uint256[] memory)` ·
**callable while paused**.

Requires `poolState == Migrating`. Builds `amounts[i] = _exitPosition(token, users[i])`, sums to `total`,
and — iff `total > 0` — `IERC20(token).safeTransfer(msg.sender, total)` from the realized idle pile.

**Verified:** `amounts.length == users.length` always (parallel arrays — the migrator's index-aligned second
loop is safe). `Σ amounts ≤ R` globally across all batches, so the migrator can never be handed more than
the realized pile. No `_routeExit`, no per-batch re-sum, no requested-vs-received delta — credits come solely
from the frozen `(R, P)`. A user already exited via `userMigrate` returns 0 and is skipped with no separate
flag. Duplicates in `users` return 0 on the second occurrence. Single trailing transfer ⇒ CEI holds.

### `_exitPosition(address token, address account)` — `:530` (internal)
```
S      = min(R, P)                                  // caps credits at par
credit = amt * S / P                                // floor division; dust accrues to protocol
pending= amt * accPhusdPerShare / ACC_PRECISION - rewardDebt   // frozen at snapshot
```
Effects: zero `amount`/`rewardDebt`, `totalStaked -= amt`, remove from `_stakers`, mint `pending` phUSD **to
the user directly** (never to the migrator), emit `MigratedOut`. Returns `credit`; **does not transfer** —
the caller forwards (CEI).

**Verified:** equal principal ⇒ equal credit, independent of batch vs. self and of ordering. Floor-division
dust is retained by the old staker as protocol value. `amt == 0` returns 0 early. Division by `P` cannot be
by zero because `amt > 0` implies `P ≥ amt > 0` at the snapshot.

### `userMigrate(address token)` — `:564`
`external nonReentrant` · **permissionless**, self-scoped. Requires `Migrating` and a non-zero position.
`_exitPosition` then `safeTransfer(msg.sender, credit)`. Pays exactly the same credit a batch exit would.
**This is the terminal-state escape hatch** (`emergencyWithdraw` is blocked while Migrating) and is the
user's unilateral recourse if the operator abandons a migration mid-way. Not in the golden-rule triad by
design (single-version lifecycle, not a version hop).

### `finalizeAndReset(address token)` — `:602`
`external onlyOwner poolExists(token)` · **no `whenNotPaused`, no `nonReentrant`** (no external calls).
Requires `Migrating` && `_stakers.length() == 0` && `totalStaked == 0`. Zeroes `migrationInfo`, sets
`lastRewardTime = block.timestamp` (so the frozen window is never retro-accrued), `poolState = Active`.

**Verified:** O(1) — asserts emptiness rather than iterating. The empty-pool requirement is the core safety
property: no stale `userInfo` can survive into the revived pool to cannibalize a future staker's principal.
After reset `yieldStrategy[token]` is still `address(0)`, so the owner must `setYieldStrategy` before
users stake again. **Not** on the golden-rule triad, and **not** exposed by `CrossVersionMigrator` — a
cross-version hop leaves the source pool parked in `Migrating` unless the owner calls it on the staker
directly.

### `depositFor(address token, address user, uint256 amount)` — `:625`
`external override nonReentrant onlyMigrator poolExists(token)` · **callable while paused** (a freshly
deployed, possibly-paused destination can be seeded).

Requires `amount > 0` **and `poolState == Active`** — so the *destination* must not itself be migrating.
Order: `_updatePool` → `_settle(user, info, pool)` (mints any pre-existing pending) → `_pullToken` →
`_routeDeposit` → `require(credited > 0)` → `info.amount += credited` → `totalStaked += credited` →
rebase `rewardDebt` → add to `_stakers` → emit `DepositedFor(token, user, credited)`.

**KEY PROPERTY (see the CrossVersionMigrator profile, ANSWER 2): `credited ≤ received ≤ amount`.** The
migrator always pays `amount`; the user may be credited less. `received − credited` stays inside the
destination strategy as protocol-owned slippage. Internal accounting remains self-consistent (both
`info.amount` and `totalStaked` move by `credited`, matching `strategy.principalOf`) — **no desync** — but
there is no refund, no top-up, and the emitted event reports only `credited`, so the shortfall is invisible
from the migrator's event stream. `credited == 0` reverts, and that revert propagates out through the whole
`CrossVersionMigrator.migrate()` batch.

**Ordering note (verified safe):** `_settle` runs before the balance change, so a user credited in two
separate batches has their accrued reward minted before `rewardDebt` is rebased against the larger amount.
No reward is lost or double-paid.

## PoolState machine — consolidated

```
        initiateMigration (onlyMigrator, requires Active, strategy fully drained)
 Active ───────────────────────────────────────────────────────────────► Migrating
   ▲                                                                        │
   └──── finalizeAndReset (onlyOwner, requires stakerCount==0 && totalStaked==0) ◄┘
```

| Gate | Functions |
|---|---|
| `require(Active)` | `setYieldStrategy` `:228`, `stake` `:301`, `withdraw` `:322`, `emergencyWithdraw` `:366`, `initiateMigration` `:434`, `depositFor` `:634` |
| `require(Migrating)` | `batchMigrate` `:505`, `userMigrate` `:565`, `finalizeAndReset` `:603` |
| state-blind but state-dependent | `claim` `:347` (`_updatePool` no-ops ⇒ mints frozen pending only), `pendingReward` `:653` (no forward projection while Migrating), `rescueERC20` `:818` |

## Verified local properties

| ID | Property | Confidence |
|---|---|---|
| PROP-SS-01 | All three golden-rule functions are `onlyMigrator` and `nonReentrant`; none is reachable permissionlessly. | **verified** |
| PROP-SS-02 | Emissions are frozen for the whole Migrating window (`_updatePool` early-returns on `poolState != Active`), and `finalizeAndReset` fast-forwards `lastRewardTime`, so the frozen gap can never be retro-emitted. | **verified** |
| PROP-SS-03 | `(R, P)` is written once and read-only until `finalizeAndReset` zeroes it ⇒ credits are order-, batch-composition- and method-independent. | **verified** |
| PROP-SS-04 | `Σ` of all credits paid across all exits `≤ R` (each credit is `amt·min(R,P)/P` with floor division and `Σ amt ≤ P`). The realized pile can never be over-drawn. | **verified** |
| PROP-SS-05 | `claim` during Migrating cannot double-mint: it rebases `rewardDebt` against the frozen `acc`, leaving `_exitPosition`'s `pending == 0`. | **verified** |
| PROP-SS-06 | `finalizeAndReset` cannot revive a pool holding any position (`stakerCount == 0 && totalStaked == 0`). | **verified** |
| PROP-SS-07 | `rescueERC20` cannot touch the realized migration pile: `initiateMigration` clears `yieldStrategy` to 0, so `reserved == totalStaked`, which shrinks in lockstep with the credits paid out. | **verified** |
| PROP-SS-08 | No unbounded loops. `batchMigrate` iterates the migrator-supplied `users` (owner-bounded, paged via `getStakersRange`); `finalizeAndReset` is O(1) by asserting emptiness. | **verified** |
| PROP-SS-09 | `depositFor` credits at most what it pulls, and may credit strictly less, with the shortfall permanently protocol-owned and no compensating mechanism. | **verified (as a property of the code, not adjudicated as a finding)** |
| PROP-SS-10 | Checked arithmetic (0.8.28); no `unchecked`, no assembly. Floor division consistently rounds against the user and toward the protocol. | **verified** |
| PROP-SS-11 | No weak randomness; `block.timestamp` is used only as an accrual clock and a `lastRewardTime` marker, never as entropy for a value-bearing outcome. | **verified** |
| PROP-SS-12 | No ERC721/1155/777 receive hooks implemented; no `_safeMint`/`safeTransfer`-to-recipient sites. The only inbound-callback surface is the arbitrary staked ERC20 itself. | **verified** |
| PROP-SS-13 | `STAKER_VERSION` has no internal reader and is not consulted by any gate — adding it is behaviourally inert. | **verified** |

## Could NOT verify locally

- **SS-U1 — `_routeExit` / `_routeDeposit` counterparty semantics.** `R`, `credited` and the underwater
  predicate all depend on the external `IYieldStrategy` (`reflax-yield-vault`). Whether `strategy.deposit`
  can return 0 for a non-trivial input (which would revert an entire `migrate` batch) requires the strategy
  implementation. **Deferred to code-scanner / interaction analysis.**
- **SS-U2 — `initiateMigration` "incomplete exit" post-check** relies on `strategy.principalOf` being honest
  and on `withdraw` draining fully. Cross-contract. **Deferred.**
- **SS-U3 — the buffer branch in `_routeExit`** (`:790`, `withdraw` path only): when underwater it satisfies
  the withdraw from the on-contract buffer and calls `strategy.relinquishPrincipal`. This path is **not**
  reachable from any migration function (all migration paths pass `guardUnderwater = false`), so it is out of
  the migration surface — but it is the only place the staker's idle balance is consumed outside the
  realized pile, and it interacts with `rescueERC20`'s `reserved == 0` branch when a strategy is set.
  **Deferred.**
- **SS-U4 — single `migrator` slot.** Only one migrator can be authorized at a time, so running
  `InPlaceMigrator` and `CrossVersionMigrator` against the same staker requires `setMigrator` flips between
  phases. Whether any flip window is exploitable is an interaction question. **Deferred.**
