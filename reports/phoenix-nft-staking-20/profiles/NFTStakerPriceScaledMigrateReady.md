# Contract Profile — `src/NFTStakerPriceScaledMigrateReady.sol`

| | |
|---|---|
| Project | `phoenix-nft-staking` |
| Submodule HEAD | `0d1a0b2` |
| Introduced by | `[story-021]` @ `f65aec9` (2026-07-20) — purely additive, 1005 LOC |
| Solidity | `^0.8.20` (checked arithmetic; no `unchecked`, no `assembly`) |
| Inheritance | `Ownable`, `Pausable`, `ReentrancyGuard`, `ERC1155Holder`, `IPausable`, `INFTStakerMigratable` |
| Family position | 4th hand-maintained copy of the staker — see `FORK-PARITY-4WAY.md` |
| Deployment status | **not yet deployed** (side-by-side variant) |
| Test coverage | `test/NFTStakerPriceScaledMigrateReady.t.sol` (33 tests) + `test/NFTStakerPriceScaledMigratorOrchestrators.t.sol` (8 tests) |

---

## 1. Verified properties

| Property | Status | Evidence |
|---|---|---|
| Checked arithmetic | **verified** | `pragma ^0.8.20`; zero `unchecked` blocks; zero `assembly`. |
| No unbounded loops in unprivileged paths | **verified** | The only loop is `batchMigrate` (L797), `onlyMigrator`, over a caller-supplied array. See LOCAL-006. |
| No recursion | **verified** | — |
| Reentrancy guarded | **verified** | `nonReentrant` on every state-changing external: `stake`, `unstake`, `claim`, `emergencyWithdraw`, `initiateMigration`, `batchMigrate`, `userMigrate`, `depositFor`. Owner-only setters are unguarded but reach no untrusted callee. |
| CEI on every ERC1155 send | **verified** | `unstake` (L655–658), `emergencyWithdraw` (L740–756), `_exitPosition`+`userMigrate` (L846–830), `batchMigrate` (loop zeroes all positions before the single L812 transfer). Position state is zeroed before the outbound transfer in all four. |
| Access control coverage | **verified** | Every state-changing external is `onlyOwner`, `onlyPauser`, `onlyMigrator`, or an intentionally-permissionless user path. See §3. |
| Initializer protection | **n/a — verified** | Not upgradeable, no proxy, no initializer; constructor-only with zero-address + zero-`priceScale` guards. |
| Pause mechanism | **verified** | `IPausable` via global pauser. `stake`/`unstake`/`claim` are `whenNotPaused`; `emergencyWithdraw`, `userMigrate` and all migration primitives are deliberately **not**, preserving exit under pause. |
| Weak randomness | **verified absent** | `block.timestamp` appears only as an accrual clock (13 sites); no `blockhash`/`prevrandao`/`difficulty`/entropy-derived outcome. |
| Solvency invariant `balance == rewardBudget + committedDebt` | **likely** (holds under static reasoning across every mutator, incl. all new migration paths; in-repo test `testSolvencyAcrossFullMigrationCycle` asserts it end-to-end. Not symbolically proved here — flag for Tier-3.) | `_updatePool` moves budget→debt; `_safePayTo` decrements the sum by the transferred amount; `emergencyWithdraw` moves debt→budget; `_recomputeSchedule` re-derives `rewardBudget = V − committedDebt`; `_exitPosition` pays only via `_safePayTo`. |
| **Pending-reward snapshot is frozen while `Migrating`** | **verified** | `accRewardPerShare` is written **only** by `_updatePool` (L514), which early-returns while `Migrating` (L498). `user.rewardDebt` is written only in `stake`/`unstake`/`claim`/`depositFor`/`_exitPosition`, each of which either zeroes the position or leaves per-user pending arithmetically unchanged. Therefore every user's `pending = amount·acc/PREC − rewardDebt` is pinned at the `initiateMigration` snapshot. **This is the load-bearing freeze property and it holds.** |
| Schedule variables (`rewardRate`/`windowEnd`/`rewardBudget`) frozen while `Migrating` | **violated for owner paths — but inert** | See §2. The accrual path is fully gated; four owner-only paths can still move them. No user-visible effect. |
| `depositFor` cannot route a user's reward to the migrator | **verified** | L887 `_safePayTo(user, pending)`. The migrator (`msg.sender`) is never the transfer target on any reward path. |
| `INFTStakerMigratable` fully implemented | **verified** | All 4 members present with `override` and correct signatures. See `FORK-PARITY-4WAY.md` §6. |

---

## 2. Frozen-snapshot enumeration (claim 2 — verified empirically)

Every write to schedule/accrual state, and its gating while `poolState == Migrating`:

| Writer | Writes | Reachable while `Migrating`? | Gated? | Effect on user pending |
|---|---|---|---|---|
| `_updatePool` (L493) | `accRewardPerShare`, `rewardBudget`, `committedDebt`, `lastRewardTime` | yes (called from `_syncBudget`, `setTargetAPY`, `topUp`, `rescueERC20`) | **YES** — L498 early-return, only fast-forwards `lastRewardTime` | **none — frozen** ✅ |
| `_recomputeScheduleIfActive` (L482) → `_recomputeSchedule` | `rewardRate`, `rewardBudget`, `windowEnd` | via `_syncBudget` (L463/469), `stake` tail (L642), `unstake` tail (L663) | **YES** — L483 early-return | none ✅ |
| `setTargetAPY` (L394) | ↑ (direct `_recomputeSchedule`) | **yes, ungated, users may still be staked** | **NO** | none — `_updatePool` no-ops so no accrual occurs at the new rate; `finalizeAndReset` re-derives on exit |
| `topUp` (L408) | ↑ | **yes, ungated** | **NO** | none (same reasoning); `rewardBudget` grows consistently with `balance` |
| `rescueERC20` (L433, reward-token branch) | ↑ | **yes, ungated** | **NO** | none; `require(balance >= committedDebt)` protects the frozen payouts |
| `setDispatcherIndex` (L371) / `setNFTMinter` (L381) | ↑ | yes, but `require(totalStaked == 0)` → only after full drain | partially | none (pool empty) |
| `finalizeAndReset` (L925) | `lastRewardTime`, `poolState`, then `_recomputeSchedule` | by definition | intentional | intentional re-arm |
| `_safePayTo` (L706) | `committedDebt`, `rewardBudget` | yes (every exit) | intentional | pays out the frozen pending |
| `emergencyWithdraw` (L735) | `committedDebt`→`rewardBudget`, `totalStaked`, user | yes, ungated (by design) | intentional | forfeits own pending |

**Conclusion.** The story-021 claim *"the frozen snapshot cannot move while `Migrating`"* is **true for the accrual
path** (which is what the sentence is scoped to in context) and **false as a blanket statement** — four owner-only
paths still write `rewardRate`/`rewardBudget`/`windowEnd` mid-migration. The contract's own NatSpec at L479–481
explicitly acknowledges and endorses this ("Owner-driven recomputes … call `_recomputeSchedule` directly and are
deliberate"), and the divergence is **inert**: while `Migrating` no accrual is settled at any rate, per-user pending
is pinned by the frozen `accRewardPerShare`, and `finalizeAndReset` re-derives the whole schedule on the way out.
**Faithful in substance; recorded as a documentation-precision observation, not a finding.**

---

## 3. Interface abstraction

### 3.1 External entry points

| Function | Access | State written | External calls | `nonReentrant` | Paused-callable |
|---|---|---|---|---|---|
| `stake(uint256)` L617 | none | `users`, `totalStaked`, schedule (via `_syncBudget` + tail) | `dispatcherHook.pull()`, `nftMinter.configs()`, `dispatcherHook.mintDebt()`, `rewardToken.balanceOf/safeTransfer`, `stakedToken.safeTransferFrom` | ✅ | no |
| `unstake(uint256)` L645 | none | `users`, `totalStaked`, schedule | as above + outbound ERC1155 | ✅ | no |
| `claim()` L666 | none | `users[msg.sender].rewardDebt`, `committedDebt`, `rewardBudget`, schedule | as above (no ERC1155) | ✅ | no |
| `emergencyWithdraw()` L735 | none | `users`, `totalStaked`, `committedDebt`, `rewardBudget` | `stakedToken.safeTransferFrom` **only** | ✅ | **yes** |
| `userMigrate()` L827 | none, requires `Migrating` + position | `users`, `totalStaked`, `committedDebt`, `rewardBudget` | `rewardToken.*`, `stakedToken.safeTransferFrom` | ✅ | **yes** |
| `initiateMigration()` L774 | `onlyMigrator`, requires `Active` | `poolState`, schedule (final Active recompute) | `dispatcherHook.pull()`, `mintDebt()`, `configs()` | ✅ | **yes** |
| `batchMigrate(address[])` L797 | `onlyMigrator`, requires `Migrating` | `users[*]`, `totalStaked`, `committedDebt`, `rewardBudget` | `rewardToken.safeTransfer` × n, one `stakedToken.safeTransferFrom` | ✅ | **yes** |
| `depositFor(address,uint256)` L879 | `onlyMigrator`, requires `Active` + `amount > 0` | `users`, `totalStaked`, schedule (tail recompute) | `pull()`, `configs()`, `mintDebt()`, `rewardToken.*`, inbound `stakedToken.safeTransferFrom` | ✅ | **yes** |
| `finalizeAndReset()` L925 | `onlyOwner`, requires `Migrating` + `totalStaked == 0` | `lastRewardTime`, `poolState`, schedule | `configs()`, `mintDebt()`, `balanceOf()` | ✗ | **yes** |
| `setMigrator(address)` L339 | `onlyOwner` | `migrator` | — | ✗ | yes |
| `rescueERC20(IERC20,address,uint256)` L433 | `onlyOwner` | `committedDebt`, `rewardBudget`, schedule (reward branch) | `token.safeTransfer`, `balanceOf`, `configs()`, `mintDebt()` | ✗ | yes |
| `setTargetAPY` L394 / `topUp` L408 / `pullAndRefresh` L417 / `setDispatcherHook` L356 | `onlyOwner` | schedule | varies | ✗ | yes |
| `setStakedId` L361 / `setDispatcherIndex` L371 / `setNFTMinter` L381 | `onlyOwner` + `totalStaked == 0` | config + schedule | `configs()`, `mintDebt()` | ✗ | yes |
| `setPauser` L330 | `onlyOwner` | `pauser` | — | ✗ | yes |
| `pause()` / `unpause()` L344/348 | `onlyPauser` | `_paused` | — | ✗ | — |
| views: `userInfo`, `pendingReward`, `currentRewardRate`, `totalDebt`, `totalBudget`, `runwaySeconds` | none | — | `balanceOf`, `mintDebt` | — | — |

### 3.2 External calls / trust boundaries

| Target | Methods | Trust | Notes |
|---|---|---|---|
| `IERC20 rewardToken` (phUSD) | `balanceOf`, `safeTransfer`, `safeTransferFrom` | **semi-trusted (first-party)** | Assumed standard 18dp ERC20, no hooks, no fee-on-transfer. A fee-on-transfer reward token would break the solvency invariant. |
| `IERC1155 stakedToken` (NFTMinterV2) | `safeTransferFrom` (in and out) | **semi-trusted (first-party)** | Inbound `safeTransferFrom(…, address(this), …)` triggers `onERC1155Received` on this contract (`ERC1155Holder`, inert). |
| **Outbound ERC1155 recipient** — `msg.sender` in `unstake`/`userMigrate`/`emergencyWithdraw` | implicit `onERC1155Received` callback | **UNTRUSTED** | Arbitrary user address; a contract recipient receives control. All three are `nonReentrant` **and** zero the position before the transfer. Exploitability requires cross-contract context → **defer to interaction analysis**. |
| **Outbound ERC1155 recipient** — `msg.sender` in `batchMigrate` (L812) | `onERC1155Received` | semi-trusted (the migrator) | Single aggregate transfer *after* the whole loop; all positions already zeroed. |
| `IBalancerPoolerMintDebtHook dispatcherHook` | `pull()`, `mintDebt()` | **semi-trusted (first-party, owner-settable, live-rotatable)** | `pull()` is an unguarded external call inside `_syncBudget` on every user path. `mintDebt()` is read into `V` on every recompute. A reverting hook bricks `stake`/`unstake`/`claim`/`depositFor`/`finalizeAndReset` — but never `emergencyWithdraw`. |
| `INFTSupply nftMinter` | `configs(dispatcherIndex)` | **semi-trusted (first-party, owner-settable while empty)** | Supplies `price` + `growthBasisPoints`; a reverting or garbage read propagates into the rate. |
| `migrator` (`NFTStakerMigrator` / `InPlaceNFTStakerMigrator`) | inbound caller only | **semi-trusted (owner-set)** | Holds `onlyMigrator` authority over `initiateMigration`/`batchMigrate`/`depositFor`. |

### 3.3 State variables

| Name | Type | Mutators | Readers |
|---|---|---|---|
| `poolState` | `PoolState` | `initiateMigration`, `finalizeAndReset` | `_updatePool`, `_recomputeScheduleIfActive`, `batchMigrate`, `userMigrate`, `depositFor`, `pendingReward`, `totalDebt` |
| `migrator` | `address` | `setMigrator` | `onlyMigrator` |
| `totalStaked` | `uint256` | `stake`, `unstake`, `emergencyWithdraw`, `_exitPosition`, `depositFor` | `_updatePool`, `_recomputeSchedule`, `finalizeAndReset`, `setStakedId/DispatcherIndex/NFTMinter`, views |
| `users` (`mapping→UserInfo`) | | `stake`, `unstake`, `claim`, `emergencyWithdraw`, `_exitPosition`, `depositFor` | same + `userInfo`, `pendingReward` |
| `accRewardPerShare` | `uint256` | **`_updatePool` only** | all pending computations |
| `committedDebt` | `uint256` | `_updatePool`, `_safePayTo`, `emergencyWithdraw` | `_recomputeSchedule`, `rescueERC20`, `totalDebt` |
| `rewardBudget` | `uint256` | `_updatePool`, `_recomputeSchedule`, `_safePayTo`, `emergencyWithdraw` | `_updatePool`, `pendingReward`, `totalDebt` |
| `rewardRate`, `windowEnd` | `uint256` | `_recomputeSchedule` only | `_updatePool`, views |
| `lastRewardTime` | `uint256` | `_updatePool`, `finalizeAndReset` | `_updatePool`, views |
| `targetAPY` | `uint256` | `setTargetAPY` (≤ `MAX_TARGET_APY = 0.5e18`) | `_recomputeSchedule` |
| `priceScale` | `uint256 immutable` | constructor (`!= 0` only) | `_recomputeSchedule` |
| `stakedId`, `dispatcherIndex`, `nftMinter` | | empty-pool-gated setters | `_recomputeSchedule`, transfers |
| `dispatcherHook`, `pauser` | | `setDispatcherHook`, `setPauser` (ungated) | `_syncBudget`, `onlyPauser` |

### 3.4 Events / modifiers

Events: `Staked`, `Unstaked`, `Claimed`, `EmergencyWithdrawn`, `Pulled`, `ToppedUp`, `DispatcherHookChanged`,
`StakedIdChanged`, `PauserChanged`, `TargetAPYChanged`, `DispatcherIndexChanged`, `NFTMinterChanged`,
`ScheduleRecomputed`, **`Rescued`, `MigratorSet`, `MigrationInitiated`, `MigratedOut`, `UserMigrated`,
`DepositedFor`, `PoolReset`** (7 new).

Modifiers: `onlyOwner`, `onlyPauser`, `onlyMigrator`, `whenNotPaused`, `nonReentrant`.

---

## 4. Local findings

### LOCAL-001 — `stake()` is not `poolState`-gated; a permissionless stake blocks `finalizeAndReset`
**Type:** state-machine / griefing DoS · **Severity (local):** local-low · **Function:** `stake` L617; `finalizeAndReset` L927

While `poolState == Migrating`, `stake()` carries no `poolState` guard. Any holder of the ERC1155 can stake,
making `totalStaked > 0`, which makes `finalizeAndReset`'s `require(totalStaked == 0, "NFTStaker: stake outstanding")`
revert. Because `finalizeAndReset` is the **only** transition back to `Active`, and `depositFor` requires `Active`,
this blocks the in-place migrator's `migrateIn` re-injection for as long as the griefer keeps re-staking.
The operator can evict via `batchMigrate`, but the griefer can re-stake in the following block, front-running the
reset.

Notably the griefer earns **nothing** for the trouble — `accRewardPerShare` is frozen, so a stake placed during
`Migrating` accrues zero — making this pure-cost griefing rather than a profit vector.

**Complete in-protocol remedy exists:** `stake` is `whenNotPaused` while every migration primitive
(`initiateMigration`/`batchMigrate`/`depositFor`/`finalizeAndReset`) and every user escape (`userMigrate`,
`emergencyWithdraw`) is deliberately callable **while paused** (asserted by `testMigrationPrimitivesWorkWhilePaused`).
Pausing for the duration of the migration closes the vector entirely without trapping anyone.

This is the analogue of the sibling depletion copy's ledgered **L-03**, but **narrower**: on this copy only
`stake` is harmful. `unstake` and `claim` during `Migrating` are benign — both settle against the frozen
`accRewardPerShare`, the tail recompute no-ops, and `unstake` actively *helps* the drain.

**Recommendation:** either add `require(poolState == PoolState.Active)` to `stake`, or document
"pause before `initiateMigration`" as a mandatory operator step in the migration runbook.

---

### LOCAL-002 — `finalizeAndReset` newly depends on two external calls, adding a brick surface to the revival path
**Type:** availability / external-call dependency · **Severity (local):** local-low · **Function:** `finalizeAndReset` L925–933

The story-021 price-scaled delta adds `_recomputeSchedule()` to `finalizeAndReset` (correctly — see the parity
report). That call reads `nftMinter.configs(dispatcherIndex)` and `dispatcherHook.mintDebt()`. The sibling
`NFTStakerDepletion.finalizeAndReset` makes **no** external calls and therefore cannot revert on a broken dependency.

Consequence: with a reverting hook or minter, this copy's `finalizeAndReset` reverts, the pool is stuck in
`Migrating` forever, and `InPlaceNFTStakerMigrator.migrateIn` (which needs `Active`) is permanently blocked.
This is a **widening** of the run-19 L-01 in-place-migrator narrative.

The user-facing guarantee survives intact — parked stake still exits via `claimTimedOut`, the `totalParked`
floor still holds, `emergencyWithdraw` still bypasses everything. And a full owner remedy exists:
`setDispatcherHook(address(0))` has no guard and performs no recompute, and `setNFTMinter` (legal once drained)
recomputes against the *new* minter. So the brick is unwedgeable rather than terminal.

**Recommendation:** note the recovery order in the runbook (`setDispatcherHook(0)` / `setNFTMinter(good)` **before**
`finalizeAndReset` if either dependency is unhealthy). Do **not** repoint the migrator at a fresh staker id —
that was the run-19 incomplete-fix trap and it still applies.

---

### LOCAL-003 — `priceScale` magnitude is unchecked (inherited L-08)
**Type:** input validation / owner footgun · **Severity (local):** local-low · **Function:** constructor L317

`require(_priceScale != 0)` is the only guard. `priceScale` is `immutable` and multiplies `latestPrice` directly
(L582), so a mis-sized value (e.g. `1e18` where `1e12` was meant, for a 6dp prime token against 18dp phUSD)
inflates the staked notional `S` — and hence `rewardRate` — by 10^6, draining the budget accordingly. Being
immutable, the only recovery is redeploy + full migration.

Identical to the open Low **L-08** on `src/NFTStakerPriceScaled.sol` (run-17). **Inherited verbatim** — no new
root cause. Filed here so the family view stays honest; expect dedup to collapse it into L-08 with the new
contract added to the affected-file list.

---

### LOCAL-004 — `emergencyWithdraw` over-emission is inherited unchanged (acked wont-fix M-02)
**Type:** accounting / rate-drift · **Severity (local):** *disclosed, not re-filed* · **Function:** `emergencyWithdraw` L735

`emergencyWithdraw` decrements `totalStaked` with no trailing recompute — deliberately, so the escape hatch can
never be trapped by a broken hook/minter/recompute path (a CLAUDE.md invariant). On an APY/runway model
`R = totalStaked · latestPrice · A / yr`, so after an emergency exit `R` stays sized for the pre-exit pool and
surviving stakers over-collect until the next interaction.

This is structurally identical to **M-02** (`NFTStaker.emergencyWithdraw` over-emission), which the owner
triaged **WON'T-FIX** on 2026-06-09. Per the audit's disclosure rule for re-appearing wont-fixes on a new
contract: the original triage reason was *"deployed + no migrate-on-behalf; `pullAndRefresh` mitigation"*.
Both prongs of that rationale hold **more** strongly here, not less — this copy is not yet deployed (so the
"already deployed" constraint doesn't bind) and it has `pullAndRefresh` **plus** a full migration block, so the
operator's corrective surface is strictly larger. **No new finding; disclosed as inherited-unchanged.**

---

### LOCAL-005 — `setMigrator` has no lifecycle gate (owner footgun)
**Type:** operational hazard · **Severity (local):** local-low/QA · **Function:** `setMigrator` L339

`setMigrator` may be called at any time, including mid-migration with stake parked in the current
`InPlaceNFTStakerMigrator`. Because `depositFor` is `onlyMigrator`, rotating the pointer orphans the old
migrator's `migrateIn` path — parked stake can then only leave via `claimTimedOut`, which returns
**stake only** and drops the user out of the pool with no re-accrual.

Fully reversible (point `migrator` back), and the timeout hatch means principal is never lost — so this is a
*surprise-consequence* footgun rather than a loss vector. Surfaced under the Law-3 "would a competent
non-malicious owner be surprised?" test: the second-order effect on parked users is a step removed from the
action, so **yes**.

**Recommendation:** either gate `setMigrator` on `poolState == Active`, or document the rotation hazard.

---

### LOCAL-006 — `batchMigrate` unbounded array loop
**Type:** gas / DoS surface · **Severity (local):** informational · **Function:** `batchMigrate` L797–815

The loop iterates a caller-supplied `address[]` with one `_safePayTo` ERC20 transfer per non-empty position.
`onlyMigrator`, off-chain batched, and the migrator's own `migrateOut` is `onlyOwner` — so the bound is entirely
under operator control and the function is idempotent (a re-run returns 0 for already-zeroed users). Standard
batching pattern, no unprivileged amplification.

**Operational note (higher value than the loop itself):** `InPlaceNFTStakerMigrator.migrateIn` calls
`depositFor` per user, and on **this** copy each `depositFor` performs `_syncBudget` (external
`dispatcherHook.pull()`) **plus** a tail `_recomputeSchedule()` (external `configs()` + `mintDebt()`) — three
external calls per user per iteration, versus one storage-only recompute on the depletion copy. `migrateIn`
slices must be sized substantially smaller here than experience with the depletion staker suggests.

---

### LOCAL-007 — reward-token rescue to the exact `committedDebt` floor can brick a dust-affected exit
**Type:** arithmetic edge / availability · **Severity (local):** informational (inherited, all four copies) · **Function:** `rescueERC20` L433, `_safePayTo` L710

If the owner rescues reward token down to exactly `committedDebt`, the following `_recomputeSchedule` sets
`rewardBudget = V − committedDebt = 0`. A subsequent exit whose floor-rounded per-user `pending` marginally
exceeds `committedDebt` (the documented ~1 wei dust case) takes the `amount > committedDebt` branch and executes
`rewardBudget -= (amount − committedDebt)` against a zero budget → checked-arithmetic revert. That user's
`claim` / `userMigrate` / their slot in `batchMigrate` reverts until a `topUp`.

Requires the owner to rescue to the exact floor, and is fully recoverable by topping up 1 wei. **Pre-existing in
all four copies** via the shared `_safePay` dust branch — not introduced by story-021.

---

## 5. Trust assumptions (for downstream interaction analysis)

1. `rewardToken` (phUSD) is a standard 18-decimal ERC20: no transfer hooks, no fee-on-transfer, no rebasing. A
   fee-on-transfer reward token breaks `balance == rewardBudget + committedDebt`. (FoT is a known-invalid class
   for this project — noted for completeness only.)
2. `stakedToken` is the first-party NFTMinterV2 ERC1155 and is non-reentrant into this contract.
3. `dispatcherHook.pull()` is honest and non-reentrant, and `mintDebt()` is a truthful, monotone accounting read
   consumed as part of `V`. A hook that inflates `mintDebt` inflates the budget and hence the runway.
   **Cross-contract — defer to interaction analysis.**
4. `nftMinter.configs(dispatcherIndex)` returns the *next* mint price with `growthBasisPoints` such that
   `latestPrice = price / (1 + gbp/1e4)` recovers the most-recent paid price. Manipulating the dispatcher price
   moves the emission rate. **Defer to econ analysis.**
5. `priceScale` is correctly set at deploy to `10 ** (rewardDecimals − priceDecimals)`. Unverifiable on-chain
   (LOCAL-003).
6. `migrator` is one of the two audited first-party orchestrators. `onlyMigrator` grants authority to freeze the
   pool and to move every user's staked ERC1155 out; a wrong address is a total-custody misconfiguration
   (obvious-misuse → Law 3 suppressed, but the *rotation-mid-migration* second-order effect is LOCAL-005).
7. Owner is non-malicious (Law 3). `rescueERC20` on the reward token is bounded by the `committedDebt` guard, so
   owed reward cannot be stripped; `topUp`/`setTargetAPY` mid-migration are inert (§2).
8. Migration is operator-orchestrated with the recommended ordering
   (`pause` → `initiateMigration` → `batchMigrate`… → drain → `finalizeAndReset` → rewire → `migrateIn`…).
   LOCAL-001 and LOCAL-002 are both consequences of deviating from it.

---

## 6. Story faithfulness (story-021)

> "Side-by-side fourth copy of the staker: NFTStakerPriceScaled verbatim plus the story-019 owner-driven migration
> block … adapted for the fact that on a price-scaled staker the reward rate depends on totalStaked."

**Verdict: faithful, and unusually precise.** All five verifiable claims were checked against the code rather than
accepted:

1. *"NFTStakerPriceScaled verbatim plus the migration block"* — **VERIFIED.** Comment-stripped diff yields zero
   executable deltas beyond the migration block and the four declared price-scaled deltas.
2. *"the frozen snapshot cannot move while Migrating"* — **VERIFIED for the accrual path** (which is the clause's
   scope: "accrual-path recomputes route through `_recomputeScheduleIfActive()`"). Four owner-only paths can
   still write the schedule vars, but the effect is inert and the contract documents it. The property that
   actually matters — frozen per-user pending — holds unconditionally (§2).
3. *"`depositFor` settles existing pending via `_safePayTo(user, …)` rather than `_safePay(…)`, which would pay the
   migrator"* — **VERIFIED** (L887). The migrator cannot capture a migrating user's rewards on this copy.
   The same commit message documents that this defect is **live on `NFTStakerDepletion.sol:756`** and left
   unpatched → DRIFT-01 in `FORK-PARITY-4WAY.md`.
4. *"`finalizeAndReset` re-derives the schedule against the drained pool, matching unstake-to-zero"* —
   **VERIFIED** (L925–933) and it **does** close the depletion copy's L-02 analogue on this copy.
5. *"NFTStaker.sol, NFTStakerPriceScaled.sol, NFTStakerDepletion.sol, both migrators, INFTStakerMigratable and all
   existing tests are untouched"* — **VERIFIED** by `git show --stat`: 3 files, 2121 insertions, 0 deletions.

---

## 7. Complexity

| Metric | Value |
|---|---|
| LOC | 1005 |
| External/public functions | 30 (24 state-changing, 6 views) + 8 auto-getters |
| Internal functions | 6 (`_syncBudget`, `_recomputeScheduleIfActive`, `_updatePool`, `_recomputeSchedule`, `_safePay`, `_safePayTo`, `_exitPosition`) |
| Distinct external call targets | 4 (`rewardToken`, `stakedToken`, `dispatcherHook`, `nftMinter`) |
| State variables | 18 (2 new: `poolState`, `migrator`) |
| Events | 20 (7 new) |
| Loops | 1 (`batchMigrate`) |
| Modifiers | 5 |
