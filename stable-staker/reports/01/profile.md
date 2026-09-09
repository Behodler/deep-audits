# Contract Profiles — stable-staker

Generated: 2026-06-01
solc: 0.8.28 (pragma `^0.8.20`), OZ v5.6.1
Scope: `src/StableStaker.sol` (529 LoC), `src/StableStakerMigrator.sol` (69 LoC)
Context-only (not analyzed for findings): `src/interfaces/IStableStaker.sol`, dependency interfaces `IFlax`, `IYieldStrategy`, `IPausable`.

---

## 1. StableStaker.sol

### Purpose and role
MasterChef-style multi-token yield farm. One pool per registered stable token. Rewards are paid in **phUSD** (the `flax-token` `FlaxToken`), **minted on demand** — the contract is an authorized phUSD minter rather than pre-funded. Principal can optionally be routed into a per-token `IYieldStrategy` adapter; accrued strategy yield stays protocol-owned and is never credited to stakers. Supports Behodler3 pausing and a permissioned, zero-user-action migration via `migrateOut` / `depositFor`.

Inheritance chain: `Ownable`, `Pausable`, `ReentrancyGuard`, `IPausable` (OZ v5.6.1).

### Reward accounting model
Canonical MasterChef:
```
accPhusdPerShare += elapsed * phusdPerSecond * ACC_PRECISION / totalStaked   (in _updatePool)
pending(user)     = user.amount * accPhusdPerShare / ACC_PRECISION - user.rewardDebt
```
- `ACC_PRECISION = 1e18`, `SECONDS_PER_DAY = 86400`.
- `phusdPerSecond = amountPerDay / SECONDS_PER_DAY` (rounded down at config time).
- Dust always rounds DOWN; realized emission `<= phusdPerSecond * elapsed`.

### State variables
| Variable | Type | Notes |
|---|---|---|
| `phUSD` | `IFlax` immutable | reward token; contract must be authorized minter |
| `pauser` | address (override) | Behodler3 pauser |
| `migrator` | address | authorized for `migrateOut`/`depositFor` |
| `poolInfo` | `mapping(address => PoolInfo)` | `{phusdPerSecond, accPhusdPerShare, lastRewardTime, totalStaked}` |
| `userInfo` | `mapping(token => user => UserInfo)` | `{amount, rewardDebt}` |
| `_stakers` | `mapping(token => EnumerableSet.AddressSet)` | non-zero positions |
| `_registeredTokens` | `EnumerableSet.AddressSet` | registered pools |
| `yieldStrategy` | `mapping(address => IYieldStrategy)` | `address(0)` ⇒ idle hold |

### External / public functions

| Function | Access | Guards | State mutated | External calls |
|---|---|---|---|---|
| `addToken(token)` | onlyOwner | — | `_registeredTokens`, `poolInfo.lastRewardTime` | — |
| `phUSDPerDay(token, amountPerDay)` | onlyOwner, poolExists | — | `_updatePool` then `phusdPerSecond` | — |
| `setMigrator(_migrator)` | onlyOwner | — | `migrator` | — |
| `setPauser(_pauser)` | onlyOwner | — | `pauser` | — |
| `setYieldStrategy(token, strategy)` | onlyOwner, poolExists | — | `yieldStrategy[token]` | `forceApprove(old,0)`, `forceApprove(new,max)`, `token.balanceOf`, `strategy.deposit` |
| `pause()` | onlyPauser | — | paused | — |
| `unpause()` | owner OR pauser | — | paused | — |
| `stake(token, amount)` | public | nonReentrant, whenNotPaused, poolExists | user/pool amounts, rewardDebt, `_stakers` | `phUSD.mint` (via `_settle`), `token.transferFrom`, `strategy.deposit` |
| `withdraw(token, amount)` | public | nonReentrant, whenNotPaused, poolExists | user/pool amounts, rewardDebt, `_stakers` | `phUSD.mint`, `strategy.withdraw`/balanceOf, `token.transfer` |
| `claim(token)` | public | nonReentrant, whenNotPaused, poolExists | rewardDebt | `phUSD.mint` |
| `emergencyWithdraw(token)` | public | nonReentrant (NO poolExists, NO whenNotPaused) | user amount/debt, pool.totalStaked, `_stakers` | `strategy.withdraw`/balanceOf, `token.transfer` |
| `migrateOut(token, users[])` | onlyMigrator | nonReentrant, poolExists (callable while paused) | per-user amount/debt, totalStaked, `_stakers` | `phUSD.mint` (loop), `strategy.withdraw`/balanceOf, `token.transfer` |
| `depositFor(token, user, amount)` | onlyMigrator | nonReentrant, poolExists (callable while paused) | user/pool amounts, rewardDebt, `_stakers` | `phUSD.mint` (via `_settle`), `token.transferFrom`, `strategy.deposit` |
| `rescueERC20(token, to, amount)` | onlyOwner | NO nonReentrant (callable while paused) | — | `token.balanceOf`, `token.transfer` |
| views: `pendingReward`, `getStakers`, `getStakersRange`, `stakerCount`, `getStakedTokens`, `withdrawDisabled` | view | — | — | `withdrawDisabled`→`strategy.totalBalanceOf`/`principalOf` |

### Trust assumptions and privileged roles
- **owner**: registers tokens, sets emission rate, sets migrator/pauser/yield strategy, rescues ERC20s. Trusted not to set malicious yield strategies. Owner CANNOT directly drain user principal — `rescueERC20` reserves `totalStaked` for idle tokens (but see LOCAL-002 for the strategy-set case).
- **pauser**: pauses; owner or pauser unpauses.
- **migrator**: can pull all user principal via `migrateOut` and credit deposits via `depositFor`. A malicious/compromised migrator can mass-exit every user's principal to itself (mints rewards to users but takes principal). High-trust role.
- **phUSD minter authorization**: external precondition. If revoked (`revokeAllMintPrivileges` / version bump on the FlaxToken), every reward-minting path (`stake`/`withdraw`/`claim`/`depositFor`/`migrateOut` via `_settle`/`mint`) reverts — see LOCAL-001. `emergencyWithdraw` is the deliberate escape hatch (no mint).
- **yield strategy**: must authorize this contract via `setClient` before deposits succeed; otherwise `stake`/`depositFor` revert. Strategy is semi-trusted (phoenix `reflax-yield-vault`).
- **staked tokens**: assumed standard ERC20. `_pullToken`/`_routeExit` use measured balance deltas (defensive against fee-on-transfer for accounting), but fee-on-transfer / rebasing tokens are out of the documented model.

### External interaction surface
1. **phUSD.mint(recipient, amount)** — untrusted-return but trusted contract; reverts propagate. Reachable in `_settle`, `claim`, `withdraw`, `migrateOut` (per-user in loop).
2. **IYieldStrategy.deposit / withdraw / totalBalanceOf / principalOf** — per-token adapter. `deposit` reachable in `stake`/`depositFor`/`setYieldStrategy`; `withdraw` in `withdraw`/`emergencyWithdraw`/`migrateOut`. Balance-delta measured around `withdraw` to forward actual received.
3. **IERC20 token.transferFrom / transfer / balanceOf / forceApprove** — staked token. `forceApprove(max)` granted to active strategy; reset to 0 on clear/replace.

### Local invariants that should hold
- **I1 (share conservation)**: `sum_u userInfo[token][u].amount == poolInfo[token].totalStaked` for each token. Maintained: every `amount` mutation pairs with an equal `totalStaked` mutation (`stake`, `withdraw`, `emergencyWithdraw`, `migrateOut`, `depositFor`).
- **I2 (staker-set membership)**: `u ∈ _stakers[token] ⇔ userInfo[token][u].amount > 0`. `add` on deposit, `remove` when amount hits 0. Note `stake`/`depositFor` call `add` unconditionally (idempotent for set) and never remove on amount==0 (can't reach 0 there).
- **I3 (emission cap)**: cumulative phUSD minted for a token over any window `<= phusdPerSecond * elapsed` (≈ `phUSDPerDay`). Single writer `_updatePool`; empty-pool windows fast-forward `lastRewardTime` and accrue nothing; rate change settles old rate first. Core safety property.
- **I4 (rewardDebt baseline)**: after every settle, `rewardDebt == amount * accPhusdPerShare / ACC_PRECISION`. Holds in all mutating paths except `emergencyWithdraw`/`migrateOut` which zero both `amount` and `rewardDebt` together.
- **I5 (no double accrue)**: `_updatePool` returns early when `block.timestamp <= lastRewardTime`.
- **I6 (principal reservation in rescue)**: idle-token rescue cannot touch `totalStaked` principal. Holds for idle; see LOCAL-002 for strategy-set case where `reserved = 0` and the buffer (intended protocol-owned, but may contain underwater-withdraw buffer funds) becomes fully rescuable.

### Reentrancy / CEI observations
- All user/migrator state-mutating entrypoints carry `nonReentrant` EXCEPT `rescueERC20` (owner-only, trailing transfer, no post-call state — acceptable per inline note).
- **CEI in `stake`/`depositFor`**: `_settle` mints phUSD (external call) BEFORE updating `user.amount`/`totalStaked`/`rewardDebt`. The mint happens against the OLD position which is already settled-consistent, then `_pullToken`/`_routeDeposit` (more external calls) occur before final accounting writes. Protected by `nonReentrant`; phUSD is the only callee in `_settle` and is a trusted mint. Note external calls are interleaved with accounting — reentrancy guard is load-bearing.
- **CEI in `withdraw`**: state (amount/totalStaked/rewardDebt/_stakers) updated BEFORE `phUSD.mint` and BEFORE `_routeExit`/`safeTransfer` — good CEI ordering. `nonReentrant` present.
- **`migrateOut`**: all per-user accounting zeroed inside loop before the single aggregate `_routeExit`+transfer; `phUSD.mint` interleaved in loop (untrusted only if phUSD malicious — trusted). `nonReentrant`.
- **External-call ordering risk surface (defer to interaction analysis)**: `strategy.deposit`/`withdraw` are external calls to a semi-trusted adapter, interleaved with state writes in `stake`/`depositFor` (deposit before final `amount` write) — reentrancy guard mitigates same-contract reentry, but cross-contract / strategy-callback effects on `phUSD` or token balances are interaction-level.

### Local findings

- **LOCAL-001 (reward-mint dependency / liveness)** — severity: local-medium. Every reward path calls `phUSD.mint`, which reverts if this contract is no longer an authorized minter or the FlaxToken mint version was bumped (`revokeAllMintPrivileges`). Then `stake`/`withdraw`/`claim`/`depositFor`/`migrateOut` all revert for any user with pending > 0, including the migration path. Mitigation exists: `emergencyWithdraw` forgoes rewards and recovers principal. Surface for interaction analysis: a revoked minter bricks normal withdraw for users with pending rewards (they must use emergencyWithdraw and forfeit rewards). Not a principal-loss bug locally; flagged as availability/trust dependency.

- **LOCAL-002 (rescueERC20 buffer scope when strategy set)** — severity: local-low/medium. When `yieldStrategy[token] != 0`, `rescueERC20` sets `reserved = 0` and allows the owner to sweep the ENTIRE contract balance of `token`. The contract balance in the strategy-set case is documented as "buffer + dust" (protocol-owned). However, the underwater-withdraw path (`_routeExit` with `guardUnderwater`) and `setYieldStrategy` sweep logic both rely on / interact with on-contract buffer; an owner rescue could remove buffer that a pending underwater withdraw would have drawn from. Locally this is a centralization/spec-deviation concern (owner is trusted), not a direct theft of accounted principal since principal sits in the strategy. Flag for severity-classifier as centralization.

- **LOCAL-003 (unbounded loops, bounded by caller)** — severity: informational. `migrateOut` loops over caller-supplied `users[]`; `getStakersRange` loops over a clamped range; `Migrator.migrate` loops twice over `users`/`amounts`. All are caller-controlled (onlyMigrator / view / onlyOwner), so DoS is self-inflicted and batches are paginated off-chain via `getStakersRange`. No unbounded loop over protocol-controlled growth in a permissionless path. `getStakers()` returns the full set (view, off-chain). Not a finding; documented for completeness.

- **LOCAL-004 (`emergencyWithdraw` lacks `poolExists`)** — severity: informational. `emergencyWithdraw` omits the `poolExists` modifier. For an unregistered token `user.amount` is 0 ⇒ reverts on `require(amount > 0)`. Reading `poolInfo[token].totalStaked -= amount` for amount>0 only happens when a position exists (positions only created in registered pools). Benign; no underflow path. Documented.

### Verified properties
| Property | Status |
|---|---|
| Checked arithmetic (0.8.28, no `unchecked`) | verified |
| Reentrancy-guarded mutating entrypoints | verified (all except owner `rescueERC20`, by design) |
| Access control on privileged config | verified (onlyOwner / onlyPauser / onlyMigrator) |
| No unbounded permissionless loops | verified (loops are caller-bounded / paginated) |
| Share-conservation (I1) maintained per path | likely (static pairing of amount/totalStaked writes) |
| Emission cap (I3) | likely (single accumulator writer; depends on no overflow of `elapsed*phusdPerSecond` — extreme rate config could overflow, owner-controlled) |
| Initializer protection | n/a (non-upgradeable, constructor-based) |

---

## 2. StableStakerMigrator.sol

### Purpose and role
Orchestrates a permissioned, zero-user-action batch migration between two `StableStaker` instances. Owner calls `migrate(token, users[])`; it pulls principal out of `oldStaker` (which mints each user's earned phUSD to them) and redeposits crediting the same users on `newStaker`. Uses the per-user `amounts` returned by `migrateOut` so approval/redeposit totals exactly match pulled principal.

Inheritance: `Ownable`.

### State variables
| Variable | Type | Notes |
|---|---|---|
| `oldStaker` | `IStableStaker` immutable | source staker |
| `newStaker` | `IStableStaker` immutable | destination staker |

Both validated non-zero in constructor.

### External functions
| Function | Access | State mutated | External calls |
|---|---|---|---|
| `migrate(token, users[])` | onlyOwner | none (no migrator state) | `oldStaker.migrateOut`, `IERC20(token).forceApprove(newStaker, total)`, `newStaker.depositFor` (loop) |

### Trust assumptions / privileged roles
- **owner**: sole caller of `migrate`. Must be the configured `migrator` on BOTH stakers, and `newStaker` must have the token registered and be an authorized phUSD minter (deployment wiring). Trusted to batch correctly.
- Relies on `oldStaker.migrateOut` returning `amounts` parallel to `users` so totals reconcile.

### External interactions / ordering
1. `oldStaker.migrateOut(token, users)` — pulls aggregate principal to this migrator and returns per-user `amounts`.
2. `forceApprove(newStaker, total)` — exact-total approval.
3. Loop `newStaker.depositFor(token, users[i], amounts[i])` for non-zero entries — pulls from this contract.

### Local invariants
- **M1 (conservation through migration)**: `sum(amounts) == total` approved; `depositFor` totals consume exactly `total` (each `amounts[i]>0` redeposited once). After a successful `migrate`, the migrator holds 0 of `token` (all redeposited).
- **M2 (no residual approval theft)**: `forceApprove(total)` is exact; after `depositFor` calls consume it, residual allowance should be 0 assuming each `depositFor` pulls exactly `amounts[i]`.

### Local findings

- **LOCAL-M01 (received-vs-requested mismatch leaves stranded principal / residual allowance)** — severity: local-low, surface for interaction analysis. `migrateOut` transfers the strategy-redeemed **actual received** amount (balance delta, possibly < requested when underwater) to the migrator, but returns `amounts[i]` = the **requested** principal. The migrator then `forceApprove(newStaker, total = sum(requested))` and `depositFor(..., amounts[i] = requested)`. If the old staker's strategy was underwater, the migrator received LESS than `total`, so the later `depositFor` calls (which `transferFrom` the requested amount from the migrator) will revert with insufficient balance once the running shortfall is hit — bricking the batch mid-loop, or the approval over-grants relative to actual balance. This is a cross-contract (old-staker strategy state ⇄ migrator) concern; flag for interaction analysis. Under the happy path (idle tokens or strategy at/above par) received == requested and it reconciles.

- **LOCAL-M02 (no nonReentrant)** — severity: informational. `migrate` has no reentrancy guard, but it is `onlyOwner` and the external callees are the two trusted `StableStaker` instances (themselves `nonReentrant`). No untrusted callout. Benign.

- **LOCAL-M03 (partial-batch atomicity)** — severity: informational. If any `depositFor` reverts (e.g. paused-state edge, minter revoked, balance shortfall per M01), the whole `migrate` reverts — but `migrateOut` has already been... it is atomic within the single tx, so a revert rolls back the `migrateOut` too. No split-state risk within a single call. Cross-call batching (multiple `migrate` calls) is owner-sequenced.

### Verified properties
| Property | Status |
|---|---|
| Checked arithmetic | verified |
| Access control (onlyOwner) | verified |
| Loops bounded by caller-supplied batch | verified |
| Conservation through migration (M1) | likely — holds only when received == requested (LOCAL-M01) |

---

## Complexity
| | StableStaker | Migrator |
|---|---|---|
| LoC | 529 | 69 |
| External/public fns | ~18 (incl. views) | 1 |
| Distinct external-call targets | 3 (phUSD, strategy, token) | 3 (oldStaker, newStaker, token) |
| State variables | 8 | 2 |
