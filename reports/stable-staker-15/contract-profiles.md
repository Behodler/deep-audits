# Contract Profiles — stable-staker run-15

- **Submodule HEAD:** `2146428bdd9adb1fbaf1c1feaa4fbf36133e5506` — `[story-021] Polish: file the constructor aliasing guard as enforced, not a runbook obligation`
- **Prior audited commit:** `8856781` (run-14)
- **Profiled:** 2026-08-29
- **Solidity:** `pragma ^0.8.20`, project pins `solc 0.8.28`; OZ v5.6.1. Checked arithmetic throughout, no `unchecked`, no assembly except three `staticcall`s in `CrossVersionMigrator`.
- **Commits in the delta:** `387ed63` (freeze V1), `847cd98` (rename evergreen → StableStakerV2), `21a7cef` (CI pin), `3d096b3` (versioning doctrine rewrite), `69c6fef` (story-020: self-heal divergence + buffer in R), `2b9cf5e` + `2146428` (story-021: close the one-way door).

Files profiled (all first-party `src/**`, default-in-scope):

| File | LoC | Status this run |
|---|---|---|
| `src/StableStakerV2.sol` | 876 | Renamed from `src/StableStaker.sol`; **behaviour changed** (story-020) |
| `src/versions/v1/StableStakerV1.sol` | 854 | **NEW** — frozen, compilable copy of deployed V1 |
| `src/versions/v1/IStableStakerV1.sol` | 203 | Moved from `src/versions/` into `v1/`; content unchanged but for the import path |
| `src/CrossVersionMigrator.sol` | 240 | **Modified** (story-021 pre-flight + aliasing guard) |
| `src/InPlaceMigrator.sol` | 384 | Unchanged (context) |

---

## 0. THE THREE THINGS CALLED "BUFFER" — disambiguation (read this first)

Prior-run memory requires these never be conflated. All three appear in this run's code.

| # | Name here | Where it lives | What it is | What it is NOT |
|---|---|---|---|---|
| **B1** | **Strategy set-aside buffer** (`setAsideBufferSize[client]`, `setAsideBufferRecipient`) | `reflax-yield-vault/AYieldStrategy` + the concrete ERC4626 strategies | A **percentage dial** applied at `skimSurplus`: a share of the *yield* skim is routed as a single aggregate transfer to `setAsideBufferRecipient` instead of to the yield accumulator. Pure policy on the strategy side; `StableStaker` never reads or writes it. | Not held by the staker; not user-owned; not a reserve. |
| **B2** | **On-contract idle balance** (`IERC20(token).balanceOf(staker)`) | `StableStakerV1/V2` itself | **Working capital.** Composed of B1 deliveries (when the recipient is the staker), floor-division dust, donations, and — when `yieldStrategy == address(0)` — actual user principal. It funds `_routeExit`'s underwater par-payout path, and in **V2 only** it is now folded into the migration realized amount `R`. | **NOT a solvency reserve.** Nothing sizes it against outstanding principal; nothing tops it up; the owner may sweep the non-principal part via `rescueERC20`. Fractional-reserve intuition does not apply. |
| **B3** | **Migrator parked surplus** (`balanceOf(migrator) - totalParked[token]`) | `InPlaceMigrator` | The migrator's own token balance **above** the parked-principal floor. It is the *implicit budget* for `_reinjectWithTopup`'s grossed-up haircut compensation, and the only thing `InPlaceMigrator.rescueERC20` may touch. | Not the staker's buffer; not user principal; not available to `CrossVersionMigrator` (which deliberately does not compensate haircuts). |

**Yield framing (Law-1/econ carryover):** yield inside the strategy is externally derived (Tokemak-style, on protocol-owned capital). Over-payment out of it is misallocation / marketing spend, **never** an economic value leak. This is a standing suppression for downstream econ analysis of every path below.

---

## 1. `src/StableStakerV2.sol` — the evergreen farm

`contract StableStakerV2 is Ownable, Pausable, ReentrancyGuard, IPausable, IStableStaker`

### 1.1 State variables and the invariants they hold

| Variable | Type | Invariant / meaning |
|---|---|---|
| `ACC_PRECISION` | `constant 1e18` | Fixed-point scale for `accPhusdPerShare`. All division floors ⇒ dust rounds **down**, always in the protocol's favour. |
| `SECONDS_PER_DAY` | `constant 86400` | Rate conversion divisor. |
| `STAKER_VERSION` | `constant 2` | **NEW this run.** Source-shape identity. Deliberately not `1`: the live instance predates the constant. |
| `phUSD` | `immutable IFlax` | Reward token. The staker must be an authorized minter; rewards are **minted**, never pre-funded. Non-zero enforced in ctor. |
| `pauser` | `address` | Behodler3 pauser. Pauses; owner **or** pauser unpauses. |
| `migrator` | `address` | Sole caller of the golden-rule triad. |
| `poolInfo[token]` | `{phusdPerSecond, accPhusdPerShare, lastRewardTime, totalStaked}` | **Accounting core.** `totalStaked == Σ userInfo[token][*].amount` over all users — maintained in lockstep by every mutation site (`stake`, `withdraw`, `emergencyWithdraw`, `depositFor`, `_exitPosition`). `accPhusdPerShare` is written **only** by `_updatePool`. |
| `userInfo[token][user]` | `{amount, rewardDebt}` | `pending = amount*acc/1e18 - rewardDebt ≥ 0` by construction: `rewardDebt` is re-baselined to `amount*acc/1e18` at every settle, and `acc` is monotonically non-decreasing. |
| `_stakers[token]` | `EnumerableSet.AddressSet` (private) | `user ∈ _stakers[token] ⟺ userInfo[token][user].amount > 0` — added on every credit, removed on every zeroing (`withdraw` at 0, `emergencyWithdraw`, `_exitPosition`). |
| `_registeredTokens` | `EnumerableSet.AddressSet` (private) | Gate for `poolExists`. Add-only; no `removeToken` exists. |
| `yieldStrategy[token]` | `IYieldStrategy` | Custody pointer. `address(0)` ⇒ idle hold. **Invariant intended:** `strategy.principalOf(token, staker) == poolInfo[token].totalStaked`. This is the invariant the whole `setYieldStrategy` empty-pool gate exists to protect, and the one that story-020's self-heal repairs when it has already been broken. |
| `poolState[token]` | `enum {Active=0, Migrating}` | Sole gating source. Exactly two transitions: `initiateMigration` (Active→Migrating, `onlyMigrator`), `finalizeAndReset` (Migrating→Active, `onlyOwner`, **only when fully drained**). `Active` is the zero value so never-touched tokens behave as before. |
| `migrationInfo[token]` | `{realized R, principalSnapshot P}` | Meaningful only while `Migrating`. **Immutable for the life of an engagement** — this immutability is what makes `credit_i = p_i·min(R,P)/P` order-, batch- and method-independent. Zeroed by `finalizeAndReset`. |

**Accounting invariants (stated, and how the code holds them):**

1. **Emission cap.** `accPhusdPerShare` is written at exactly one site (`_updatePool:784`), folding in `elapsed * phusdPerSecond` per update. Empty-pool windows fast-forward `lastRewardTime` without accruing; `elapsed == 0` accrues nothing (flash-stake earns nothing); `phUSDPerDay` calls `_updatePool` **before** changing the rate, so a rate change is never retroactive. ⇒ realized emission over any window ≤ `phusdPerSecond * window`.
2. **Principal conservation.** `totalStaked` is incremented only by the **credited** amount returned from `_routeDeposit` (not the requested amount) and decremented only by an amount already checked against `user.amount`. Deposit haircuts are therefore never socialized.
3. **Stakers get principal + phUSD only.** No path reads `strategy.totalBalanceOf` to *credit* a user (`_isUnderwater` reads it only to gate). Above-par yield remains protocol-owned inside the strategy.
4. **Migration conservation.** With `S = min(R,P)`: `Σ floor(p_i·S/P) ≤ (S/P)·Σp_i = S ≤ R`. The idle pile always covers every credit under any interleaving of `batchMigrate` / `userMigrate`. Floor dust is protocol-owned.
5. **Rescue cannot touch principal.** `rescueERC20` reserves `totalStaked` when no strategy is set and `0` when one is (principal then lives in the strategy). Verified safe **during** migration too: the strategy is cleared by `initiateMigration`, so `reserved = remaining totalStaked ≥ remaining obligation Σp_i·S/P`, and when `R < P` the require blocks any non-zero rescue outright.

### 1.2 External / public function inventory

| Function | Access | Mutates accounting? | External calls |
|---|---|---|---|
| `addToken(token)` | `onlyOwner` | registers pool, sets `lastRewardTime` | — |
| `phUSDPerDay(token, amountPerDay)` | `onlyOwner`, `poolExists` | settles then sets rate | — |
| `setMigrator(address)` | `onlyOwner` | no | — |
| `setPauser(address)` | `onlyOwner` | no | — |
| `setYieldStrategy(token, strategy)` | `onlyOwner`, `poolExists`, **Active**, **`totalStaked == 0`**, **old not underwater** | re-custodies; sweeps idle B2 into new strategy | `old.totalBalanceOf/principalOf`, `_routeExit(old)`, `forceApprove(old,0)`, `forceApprove(new,max)`, `new.deposit` |
| `pause()` | `onlyPauser` | no | — |
| `unpause()` | owner **or** pauser | no | — |
| `stake(token, amount)` | **client**, `nonReentrant`, `whenNotPaused`, `poolExists`, **Active** | **yes** — `+credited` to `user.amount`/`totalStaked`, re-baselines `rewardDebt` | `token.transferFrom`, `phUSD.mint` (settle), `strategy.deposit` |
| `withdraw(token, amount)` | **client**, `nonReentrant`, `whenNotPaused`, `poolExists`, **Active** | **yes** — `-amount` | `phUSD.mint`, `strategy.withdraw` **or** underwater `strategy.relinquishPrincipal` (B2 par-payout), `token.transfer` |
| `claim(token)` | **client**, `nonReentrant`, `whenNotPaused`, `poolExists` | `rewardDebt` only | `phUSD.mint` |
| `emergencyWithdraw(token)` | **client**, `nonReentrant`, **Active** (no `poolExists`, no `whenNotPaused`) | **yes** — zeroes position, forfeits rewards | `strategy.withdraw` (guard OFF), `token.transfer` |
| `initiateMigration(token)` | `onlyMigrator`, `nonReentrant`, `poolExists`, **Active** | freezes emissions, snapshots `(R,P)`, clears strategy, sets `Migrating` | `strategy.withdraw`, `strategy.principalOf`, **`strategy.relinquishPrincipal`** (new), `forceApprove(0)`, `token.balanceOf` |
| `batchMigrate(token, users[])` | `onlyMigrator`, `nonReentrant`, `poolExists`, **Migrating** | **yes** — zeroes each position | `phUSD.mint` per user, one `token.transfer` of the aggregate to the migrator |
| `userMigrate(token)` | **client**, `nonReentrant`, **Migrating** | **yes** — zeroes own position | `phUSD.mint`, `token.transfer` |
| `finalizeAndReset(token)` | `onlyOwner`, `poolExists`, **Migrating**, `stakerCount==0`, `totalStaked==0` | clears `(R,P)`, fast-forwards `lastRewardTime`, → Active | — |
| `depositFor(token, user, amount)` | `onlyMigrator`, `nonReentrant`, `poolExists`, **Active** (no `whenNotPaused`) | **yes** — `+credited` for `user` | `token.transferFrom(migrator)`, `phUSD.mint` (settle), `strategy.deposit` |
| `rescueERC20(token, to, amount)` | `onlyOwner` (no `nonReentrant`, no `whenNotPaused`) | no (fenced below `reserved`) | `token.balanceOf`, `token.transfer` |
| `pendingReward` / `getStakers` / `getStakersRange` / `stakerCount` / `getStakedTokens` / `withdrawDisabled` / `poolInfo` / `userInfo` / `poolState` / `migrationInfo` / `yieldStrategy` | view | — | `withdrawDisabled` calls `totalBalanceOf`/`principalOf` |

**Client-callable set (permissionless):** `stake`, `withdraw`, `claim`, `emergencyWithdraw`, `userMigrate`, and all views. Note per prior context that **`relinquishPrincipal` on the strategy is client-callable** — the staker invokes it on its own behalf in two places (`_routeExit` underwater path, and `initiateMigration`'s new self-heal); no strategy-owner action is needed for either.

### 1.3 Trust boundaries and external calls

| Target | Methods | Trust | Notes |
|---|---|---|---|
| `IFlax phUSD` | `mint` | **trusted** (first-party, immutable) | Staker must be an authorized minter. A revoked minter role bricks `stake`/`withdraw`/`claim`/`batchMigrate` — but **not** `emergencyWithdraw`, which is the designed ejector seat. |
| `IERC20 token` | `transfer`, `transferFrom`, `balanceOf`, `forceApprove` | **semi-trusted** | Owner-registered stables only. `_pullToken` measures the balance delta, so FoT is tolerated at the accounting layer, but FoT/weird-ERC20 is a standing known-invalid class for this project. |
| `IYieldStrategy` | `deposit`, `withdraw`, `principalOf`, `totalBalanceOf`, `relinquishPrincipal` | **semi-trusted** (first-party `reflax-yield-vault`, but separately owned) | Two-sided wiring: the **strategy's** owner must `setClient(staker,true)` or every deposit/withdraw reverts. The strategy's own `pause` will brick `deposit`/`withdraw` (both `whenNotPaused` there) — including `initiateMigration`'s realization leg. Cross-contract exploitability deferred to interaction analysis. |
| `migrator` | inbound only | **trusted role** | Holds the triad. In practice one of the two migrators below. |
| arbitrary user | inbound `stake`/`withdraw`/`claim`/`emergencyWithdraw`/`userMigrate` | **untrusted** | All five are `nonReentrant`; `userMigrate` and `emergencyWithdraw` are strict CEI (state zeroed before the single trailing transfer). |

**No inbound callback surface:** no ERC721/1155 `safeMint`/`safeTransfer`, no ERC777 hooks, no native-ETH `receive`/`fallback`. The only re-entry vector is a malicious ERC20's `transfer`/`transferFrom` callback, and every value-moving external function carries `nonReentrant`.

### 1.4 Verified local properties

| Property | Confidence | Evidence |
|---|---|---|
| Checked arithmetic; no `unchecked`, no assembly arithmetic | **verified** | grep-clean |
| No unbounded loop over protocol-controlled state | **verified** | Only loops: `batchMigrate` (over `onlyMigrator`-supplied array), `getStakersRange` (view, caller-bounded). `getStakers()` returns the full set — a view, DoS-able only for off-chain readers. |
| Reentrancy-guarded | **verified** | `stake`, `withdraw`, `claim`, `emergencyWithdraw`, `initiateMigration`, `batchMigrate`, `userMigrate`, `depositFor`. **Not guarded:** `rescueERC20` (`onlyOwner`, no post-transfer state), `finalizeAndReset` (no external call), owner config setters. |
| Access control on every state-changing admin path | **verified** | `onlyOwner` ×7, `onlyMigrator` ×3, `onlyPauser` ×1, owner-or-pauser ×1. |
| Not upgradeable / no initializer | **verified** | Plain `Ownable`, constructor-only, no proxy. |
| No weak randomness | **verified** | `block.timestamp` used only for accrual and rate-limiting, never for a value-bearing outcome. |
| `pending` cannot underflow | **verified** | `rewardDebt` re-baselined at every mutation; `acc` monotonic. |
| Migration payout is order-/batch-/method-independent | **verified** | `_exitPosition` divides by the immutable `P` from `migrationInfo`, never a re-summed total; `batchMigrate` and `userMigrate` share it. |
| `finalizeAndReset` cannot revive a pool with stale positions | **verified** | Dual gate `stakerCount == 0 && totalStaked == 0`. |
| `rescueERC20` cannot reach user principal in any pool state | **verified** | See invariant 5 above (incl. the `Migrating` case). |

**Assumptions (not verified locally — carry into interaction analysis):**
- The strategy honours `relinquishPrincipal` by actually writing `clientBalances` down (`AYieldStrategy._relinquishInternal` does, and moves no shares — confirmed by reading the dependency, but a future concrete strategy is out of local scope).
- `strategy.withdraw` caps at available principal and drains the client fully — the `"incomplete exit"` post-check is the tripwire when it does not.
- phUSD minter authorization is live on this staker (and, for a migration target, on the destination).
- B1's `setAsideBufferRecipient` is (or is not) this staker — the code never asserts it; whether B2 accumulates at all is an off-chain configuration fact.

### 1.5 Local observations for downstream triage (not severity-rated)

- **`emergencyWithdraw` has no `poolExists` modifier** (identical in V1). Benign: an unregistered token yields `amount == 0` → `"nothing staked"`.
- **`migrate`-window allowance:** none here; see `InPlaceMigrator` below.
- **`initiateMigration` R now depends on the *whole* contract balance** for that token. Any donation landing between `_routeExit` and the balance read raises `R` (capped at `P`). The `min(R,P)` at the credit site is retained as defence; below par, a donation strictly benefits users.
- **`_routeExit` underwater path pays a single withdrawer at par out of B2 while relinquishing the same amount of principal**, i.e. it converts protocol working capital into a full-price exit for whoever withdraws first. Present identically in V1 and V2 — pre-existing, unchanged this run, listed here so it is not mistaken for new.
- `finalizeAndReset` does not reset `phusdPerSecond`; a revived pool resumes at the old rate. Documented behaviour (accrual is fast-forwarded so no retro-emission).

---

## 2. `src/versions/v1/StableStakerV1.sol` — the frozen deployed contract

`contract StableStakerV1 is Ownable, Pausable, ReentrancyGuard, IPausable` — note: **does not** implement `IStableStaker`.

- **Deployed at:** `0xbce8ABC09BaEDCabE93419bF875f6186e182079A` (Ethereum mainnet), from commit `c3ec65b`, deployed 2026-06-10.
- **Fidelity — mechanically verified this run:**
  - `git show c3ec65b:src/StableStaker.sol | diff - src/versions/v1/StableStakerV1.sol` yields **exactly** the declared permitted divergences: the frozen header block, the `@title` rename, and the `contract` declaration rename. Nothing else.
  - `sha256sum -c src/versions/v1/FROZEN.sha256` → **both files OK**.
- **Never-edit rule:** enforced by `.github/scripts/check-migration-surface.sh` (existence + hash) and `test/StableStakerV1Frozen.t.sol` / `StableStakerV1Snapshot.t.sol`.
- **Deliberately preserved defects** (`ss14m1`, `ss14l8`) — see §3. **Any finding re-filed against this file must be triaged "deliberately preserved", not actioned.** Fixing them here would make the file lie about live bytecode.
- **Must never gain a `STAKER_VERSION` getter** — the deployed bytecode has none, and `CrossVersionMigrator.versionOf` depends on the staticcall reverting to infer version 1.

Its state, invariants, access control, trust boundaries and verified properties are **identical to §1 except** for the six deltas in §3. It carries no `override` markers, and its `initiateMigration` / `batchMigrate` / `depositFor` are plain `external` (still selector-compatible with the golden-rule triad — `test/GoldenRule.t.sol` pins `0x71726c92` / `0x0ad9aeb9` / `0xb3db428b`).

---

## 3. **THE V1/V2 DIFF — what is frozen vs what evolved** (the run's central question)

Mechanical diff, with the file/contract renames normalized away. **Six** substantive deltas; everything else — storage layout, every revert string, every modifier, the entire staking/reward/rescue/pause surface — is byte-identical.

### 3.1 Storage layout: IDENTICAL

Every state slot in the same order with the same types: `pauser`, `migrator`, `poolInfo`, `userInfo`, `_stakers`, `_registeredTokens`, `yieldStrategy`, `poolState`, `migrationInfo`. `STAKER_VERSION` is a `constant` (no slot). **A V1↔V2 storage-collision class does not exist** — and it could not matter anyway, since neither is behind a proxy.

### 3.2 The six deltas

| # | Delta | V1 (frozen / deployed) | V2 (evergreen) | Consequence |
|---|---|---|---|---|
| **D1** | **Interface conformance** | `is Ownable, Pausable, ReentrancyGuard, IPausable` | `+ IStableStaker`; `userInfo`, `initiateMigration`, `batchMigrate`, `depositFor` gain `override` | Compile-time enforcement of the golden rule. **No runtime/ABI change** — same selectors, same behaviour. |
| **D2** | **`STAKER_VERSION`** | absent (staticcall reverts) | `uint256 public constant = 2` | Version probes must treat a revert as `1`. V1 must never gain this getter. |
| **D3** | **`initiateMigration` self-heal (`ss14m1`)** | Reads `R = _routeExit(token, P, false)`, then hard-`require(principalOf == 0, "incomplete exit")`. Any strategy-booked excess **bricks the migration permanently** — and V1 cannot be patched. | Reads `booked = strategy.principalOf(...)` after the exit, **always** emits `PrincipalDivergence(token, P, booked, booked)`, then `if (booked > 0) strategy.relinquishPrincipal(token, booked)`, and only then applies the same `principalOf == 0` post-check. | **The single most important behavioural divergence.** V2 self-heals the `setYieldStrategy` idle-sweep divergence; V1 requires the off-chain runbook (`relinquishPrincipalAsOwner` **on the strategy**, exact surplus, never rounded up). Live DOLA and USDC on V1 are in this state today. The V2 post-check survives as a genuine tripwire for a strategy whose relinquish does not write principal down. |
| **D4** | **Migration realized amount `R` (`ss14l8`)** | `R = _routeExit(...)` — the **strategy-exit delta only**. On-contract B2 (set-aside buffer, dust, donations) is **excluded** from the payout pool. | `R = IERC20(token).balanceOf(address(this))`, then `if (R > P) R = P` — the **whole liquid position**, capped at par. `_routeExit`'s return value is deliberately discarded. | V2 softens a below-par exit with B2 **before** any user is haircut. Above-par excess still stays protocol-owned in the decoupled strategy, so "principal + phUSD only" holds in both. |
| **D5** | **`PrincipalDivergence` event** | absent | emitted on **every** `initiateMigration`, clean case (`booked == 0`) included | Absence of the log now means "the migration did not happen", not "it was clean". |
| **D6** | **`ProtocolPrincipalSwept` event** | `strategy.deposit(token, idleBalance, address(this))` — return value discarded, silent | `uint256 credited = strategy.deposit(...)`; `emit ProtocolPrincipalSwept(token, strategy, idleBalance, credited)` | Makes the sweep that *causes* the D3 divergence observable, so an operator can subtract known sweeps from a later `PrincipalDivergence` and be left with the unexplained remainder. |

### 3.3 What is explicitly **unchanged** (frozen behaviour that V2 inherits verbatim)

- `setYieldStrategy`'s **empty-pool gate** (`totalStaked == 0`), the **underwater-swap refusal**, the old-strategy drain, and the **unrecorded idle sweep itself** — V2 logs the sweep (D6) but **does not stop it**; it fixes the downstream brick (D3) rather than the root cause. The divergence can therefore still be *created* on V2, it just no longer bricks.
- The whole `(R,P)` snapshot model, `_exitPosition`, `userMigrate`, `finalizeAndReset`'s dual empty-pool gate.
- `_routeExit`'s underwater par-payout-from-B2 path (identical, including `relinquishPrincipal` at par).
- `rescueERC20`'s reserve fence, `emergencyWithdraw`'s missing `poolExists`, `getStakers`' unbounded view, all revert strings, all `nonReentrant` placement, `_updatePool` / `_settle` / `_pullToken` / `_routeDeposit` / `_isUnderwater`.

### 3.4 Interface-level diff (`IStableStakerV1` vs `IStableStaker`)

`IStableStakerV1 is IStableStakerMigratable` and declares the **full** V1 external surface (36 members) using plain value types (`poolState` → `uint8`, no enum re-declaration). `IStableStaker is IStableStakerMigratable` is deliberately **narrow** — the triad plus `userInfo` — because it exists for `InPlaceMigrator`'s top-up, not for a version hop. `IStableStakerV1` correctly **omits** `STAKER_VERSION`.

---

## 4. `src/CrossVersionMigrator.sol` — staker A → staker B (any versions)

`contract CrossVersionMigrator is Ownable`

### 4.1 State

| Variable | Invariant |
|---|---|
| `oldStaker` | `immutable IStableStakerMigratable`, non-zero, **`!= newStaker`** (new this run) |
| `newStaker` | `immutable`, non-zero |

No other storage. **Holds no per-user state and parks nothing** — it is a pass-through within a single transaction.

### 4.2 Functions

| Function | Access | Behaviour |
|---|---|---|
| `initiateMigration(token)` | `onlyOwner` | **Pre-flight (new this run), then** `oldStaker.initiateMigration(token)`. |
| `migrate(token, users[])` | `onlyOwner` | `oldStaker.batchMigrate` → sum → `forceApprove(newStaker, total)` → per-user `newStaker.depositFor` **skipping `amounts[i] == 0`** → event. Early-returns on `total == 0` (still emits). |
| `versionOf(address)` | public view | Advisory `staticcall STAKER_VERSION()`; revert or `<32` bytes ⇒ **1**. |
| `_migratorOf` / `_isRegisteredOn` | internal view | Fail-**open** staticcall probes. |

### 4.3 Preconditions and guards on the migration path (complete enumeration)

**Enforced on chain, before the one-way door:**
1. `require(_isRegisteredOn(newStaker, token))` — `"Migrator: destination token not registered"`. Scans `getStakedTokens()`. **Fails open** if the probe reverts or returns `<64` bytes. Note a genuinely empty registry ABI-encodes to exactly 64 bytes, so `length == 0` is decoded honestly and correctly rejects.
2. `require(!probed || destMigrator == address(this))` — `"Migrator: destination not wired"`. Probes `migrator()`. **Fails open** when `probed == false`.
3. **Constructor:** `_oldStaker != _newStaker` — `"Migrator: aliased stakers"` (new this run; previously a runbook obligation). Closes the freeze-then-`depositFor`-into-the-frozen-pool footgun.

**Enforced on the staker side (inherited):** `onlyMigrator` on all three triad calls; `poolState == Active` for `initiateMigration` and destination `depositFor`; `poolState == Migrating` for `batchMigrate`; `poolExists` on all three; `amount > 0` and `credited > 0` on `depositFor`.

**Remaining runbook obligations, unguarded and explicitly documented as such:**
- **phUSD minter authorization on the destination** — lives on `FlaxToken`, which this contract deliberately does not import. Failure surfaces only at the first `depositFor` that mints a settle-reward, i.e. **after** the source is already frozen.
- **Source-side `setMigrator`** — the live V1 is unpatchable; a mis-wired source fails at call time.
- Destination token registration / wiring **when the destination is an unrecognised shape** (probe fails open by design, to preserve version-agnosticism).

### 4.4 Trust boundaries

| Target | Trust | Notes |
|---|---|---|
| `oldStaker`, `newStaker` | **trusted, immutable** | Pinned at construction precisely because an owner-mutable target is a drain vector. |
| `IERC20 token` | semi-trusted | `forceApprove(newStaker, total)` is scoped to the batch total and fully consumed by the `depositFor` loop, so nothing dangles — **unless** a `depositFor` credits less than requested, which cannot happen here (`depositFor` pulls exactly `amount`). |
| owner | **trusted, non-malicious (Law 3)** | Owner drives both entry points. |

### 4.5 Verified local properties

- **Immutable both ends** — no retarget path exists. **verified**
- **Fail-open probes are deliberate and documented**, and the doc is accurate: a probe that *succeeds and answers no* hard-reverts; only a probe that *fails* passes through. **verified**
- **Zero-credit skip** prevents one dust user from reverting a batch (`depositFor` reverts on zero credit). A skipped user is still fully exited from the source; their dust accrues to the protocol there. **verified — and a deliberate product decision, not a defect.**
- **No haircut compensation** — `migrate` redeposits exactly what `batchMigrate` returned. This asymmetry with `InPlaceMigrator` is deliberate and flagged in-source as wanting a human decision before running a cross-version migration on an underwater user base. **verified**
- Loops are bounded by owner-supplied arrays and a single-digit registered-token set. **verified**
- No reentrancy guard anywhere — acceptable: both entry points are `onlyOwner` and call only trusted immutable stakers. **likely** (defer any callback reasoning to interaction analysis)

---

## 5. `src/InPlaceMigrator.sol` — staker A → staker A (strategy rewire)

`contract InPlaceMigrator is Ownable, ReentrancyGuard` — **unchanged this run**; profiled for the migration-surface picture.

### 5.1 State and invariants

| Variable | Invariant |
|---|---|
| `staker` | `immutable IStableStaker`, non-zero. **Source AND target.** |
| `migrationTimeout` | `immutable`, `MIN_TIMEOUT (1 day) ≤ t ≤ MAX_TIMEOUT (30 days)` — floor stops a user front-running `migrateIn`; ceiling stops the hatch being neutered. |
| `parked[token][user]` | Principal in custody. |
| `migrationBegin[token][user]` | Timeout anchor, set at `migrateOut`. |
| `_parkedUsers[token]` | `user ∈ set ⟺ parked[token][user] > 0` (maintained at all three mutation sites). |
| `totalParked[token]` | **`== Σ parked[token][*]`**, and the **hard floor** `rescueERC20` may never cross. This is what makes invariant (C) hold *against the owner*. |

### 5.2 Functions

| Function | Access | Notes |
|---|---|---|
| `initiateMigration(token)` | `onlyOwner` | Thin forwarder. **No pre-flight** — unnecessary: source and target are the same contract, so there is no destination to mis-wire. |
| `migrateOut(token, users[])` | `onlyOwner`, `nonReentrant` | `staker.batchMigrate` → park per-user. Idempotent (a re-run returns 0 for an already-drained user). |
| `migrateIn(token, start, end)` | `onlyOwner`, `nonReentrant` | Snapshots the slice into memory **first** (set removal shifts live indices); `forceApprove(staker, full balance)`; per user: CEI-zero state, then `_reinjectWithTopup`. |
| `_reinjectWithTopup` | private | `depositFor(amt)` → measure credited via `userInfo` before/after → if short, `topup = mulDiv(amt-credited, amt, credited)` (grossed up to survive its own haircut) → `require(topup ≤ balance - totalParked)` (**B3 budget**) → second `depositFor(topup)` → `require(finalCredited ≥ amt - amt/1000)` par backstop. |
| `claimTimedOut(token)` | **client (self-scoped)**, `nonReentrant` | Strict CEI. Requires `parked > 0` and `block.timestamp ≥ migrationBegin + migrationTimeout`. **Principal only** — phUSD was already minted at `migrateOut`. |
| `rescueERC20(token, to, amount)` | `onlyOwner` | `amount ≤ balance - totalParked`. Underflows (reverts) if balance ever dips below the floor. |
| `parkedUserCount` / `parkedUsersRange` / `claimableAt` | view | Range clamped both ends. |

### 5.3 The two exits for parked principal (exhaustive — this is the security argument)

1. `migrateIn` → `staker.depositFor(token, user, amount)` — the **immutable** staker, crediting **the original parked user**.
2. `claimTimedOut` → `safeTransfer(msg.sender, amount)` — **the parked user themselves**.

There is no third. `rescueERC20` is fenced below `totalParked`. Verified by inspection of every `safeTransfer` / `depositFor` site.

### 5.4 Verified local properties and observations

- **Custody window is real and deliberate** (doc section B): between `migrateOut` and `migrateIn` the migrator holds raw principal. Mitigated, not eliminated, by (1) the immutable target, (2) the `totalParked` rescue floor, (3) the timeout hatch. **verified**
- **CEI everywhere**: `migrateIn` zeroes `parked`/`migrationBegin`/`totalParked`/set-membership *before* `depositFor`; `claimTimedOut` clears before transfer. Both `nonReentrant`. **verified**
- **`_reinjectWithTopup` ordering dependency**: it *requires* the caller's effects block to have already decremented `totalParked` by `amt`, otherwise the live-surplus budget check is wrong. This is documented and currently correct, but it is a latent refactor hazard — the helper is `private` and has one caller. **verified-with-caveat**
- **Local observation (doc/code mismatch):** `migrateIn` approves the migrator's **entire** token balance to the staker, but the deposits pull only `total + Σtopups`. The in-source claim "never left dangling: `forceApprove` overwrites the previous allowance, and `depositFor` pulls exactly the slice total" is **inaccurate** when a surplus (B3) is present — a residual allowance survives the call until the next `migrateIn`. Bounded: the allowance is to the immutable staker, whose only pull path is `depositFor`, itself `onlyMigrator` (i.e. this contract). Flagged as a local documentation/hygiene issue, not attributed as an exploit.
- **Par backstop is intentionally non-reverting in the normal case**: `amt/1000` tolerance forgives integer-division residue and binds only under a pathological ~100% haircut.
- Loops bounded by an owner-supplied array (`migrateOut`) and an owner-supplied slice (`migrateIn`). No unbounded iteration. **verified**

---

## 6. The migration surface, end to end

```
                      ┌─────────────────── CrossVersionMigrator (A → B) ───────────────────┐
                      │  ctor: oldStaker != newStaker, both non-zero, both immutable        │
  initiateMigration ──┤  pre-flight: dest token registered? dest.migrator() == this?        │
                      │  → oldStaker.initiateMigration(token)      [ONE-WAY DOOR]           │
                      │  migrate: oldStaker.batchMigrate → sum → forceApprove(total)        │
                      │           → newStaker.depositFor per user (skip zero-credit)        │
                      └────────────────────────────────────────────────────────────────────┘

                      ┌─────────────────── InPlaceMigrator (A → A) ────────────────────────┐
                      │  ctor: staker immutable, 1 day ≤ timeout ≤ 30 days                  │
  initiateMigration ──┤  → staker.initiateMigration(token)         [ONE-WAY DOOR]           │
                      │  migrateOut: batchMigrate → PARK in custody (totalParked floor)     │
                      │  [operator: finalizeAndReset → setYieldStrategy(new)]               │
                      │  migrateIn:  depositFor(parked) + grossed-up surplus top-up (B3)    │
                      │  claimTimedOut: user self-rescue after timeout (principal only)     │
                      └────────────────────────────────────────────────────────────────────┘
```

**Complete precondition list for either path to succeed:**

| # | Precondition | Enforced where |
|---|---|---|
| 1 | `poolState[token] == Active` on the source | staker `initiateMigration` |
| 2 | Caller is the configured `migrator` on the source | staker `onlyMigrator` |
| 3 | `token` registered on the source | staker `poolExists` |
| 4 | Strategy `withdraw` succeeds (strategy not paused; staker is an authorized client) | strategy `onlyAuthorizedClient` + `whenNotPaused` |
| 5 | After the exit, `strategy.principalOf == 0` | **V2: satisfied by construction via self-heal (D3). V1: hard brick — needs the off-chain `relinquishPrincipalAsOwner` runbook.** |
| 6 | `poolState[token] == Migrating` for every `batchMigrate` | staker |
| 7 | Destination `token` registered + destination `migrator()` wired | **CrossVersionMigrator pre-flight (new)**, fail-open on unknown shapes; N/A for InPlaceMigrator |
| 8 | Destination `poolState == Active` (never the frozen source) | staker `depositFor`; also the reason for the aliasing guard |
| 9 | Destination is an authorized phUSD minter | **NOT enforced anywhere — runbook obligation** |
| 10 | Per-user credit `> 0` | `depositFor` reverts on zero; CrossVersionMigrator skips such users, InPlaceMigrator's `amt > 0` check parks only non-zero |
| 11 | (InPlaceMigrator only) `balance - totalParked ≥ topup` | `_reinjectWithTopup` |
| 12 | Revival: `stakerCount == 0 && totalStaked == 0` | `finalizeAndReset` |

**Value-movement asymmetry that matters:** below par, `CrossVersionMigrator` credits the uniform snapshot haircut `p_i·min(R,P)/P` and **does not** top up; `InPlaceMigrator` restores each user to par out of B3. Documented as a deliberate product difference requiring a human decision before a cross-version migration over an underwater user base.

---

## 7. Complexity summary

| Contract | LoC | External/public fns | State vars | External call sites | Loops |
|---|---|---|---|---|---|
| `StableStakerV2` | 876 | 24 (11 mutating, 13 view) | 9 | 14 | 2 (both bounded) |
| `StableStakerV1` (frozen) | 854 | 23 (11 mutating, 12 view) | 8 | 12 | 2 (both bounded) |
| `CrossVersionMigrator` | 240 | 3 | 2 (both immutable) | 6 (3 staticcall probes) | 3 (owner-bounded) |
| `InPlaceMigrator` | 384 | 8 | 6 (2 immutable) | 8 | 3 (owner-bounded) |
