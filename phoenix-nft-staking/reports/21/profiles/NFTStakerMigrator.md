# Contract profile — `src/NFTStakerMigrator.sol`

- Run: `phoenix-nft-staking-21`
- Submodule HEAD: `c881a42` (changed this cycle at `f3b92c0`, story-023, **+184 lines**)
- Profiled: **COLD**
- Solidity: `^0.8.20`; LOC 290; no `unchecked`, no assembly
- Inheritance: `Ownable`, `ReentrancyGuard`, `ERC1155Holder` (`:77`)
  — `ReentrancyGuard` is **new this cycle**

## 1. What changed

Story-023 added the settlement-capture forwarding mechanism (audit `pns20h1`). Deep treatment
of the mechanism itself, including the D-6 parity verification against
`InPlaceNFTStakerMigrator`, is in **`MIGRATOR-FORWARDING-PROFILE.md`** — this profile covers
the contract's surface, state, and local properties.

New surface: `rewardToken` immutable `:97`, `unforwarded` mapping `:101`, `totalUnforwarded`
`:105`, three events `:111/:115/:118`, `_depositForAndForward` `:214`, `claimForwarded` `:247`,
`rescueERC20` `:268`, `rescueERC1155` `:286`. Constructor gained an `IERC20 _rewardToken` arg
and three new `require`s. **`migrate` gained `nonReentrant`** `:170`.

**Before story-023 this contract had NO rescue primitive at all** — anything delivered to it
was permanently stranded, which is stated at `:264-267` as what made `pns20h1` a High rather
than a Medium.

## 2. External / public surface

| Function | Access | Guards | State written | External calls |
|---|---|---|---|---|
| `constructor(...)` `:120` | — | 6 `require`s `:130-140` | all immutables | 2× STATICCALL `rewardToken()` on both stakers `:133/:137` |
| `initiateMigration()` `:153` | `onlyOwner` | none | none | CALL `oldStaker.initiateMigration()` |
| `migrate(address[])` `:170` | `onlyOwner` | `nonReentrant` | `unforwarded`, `totalUnforwarded` (via `:214`) | see §4 |
| `claimForwarded()` `:247` | **permissionless, self-only** | `nonReentrant` | `unforwarded[msg.sender]`, `totalUnforwarded` | CALL `rewardToken.safeTransfer` |
| `rescueERC20(...)` `:268` | `onlyOwner` | none | none | STATICCALL `balanceOf` + CALL `safeTransfer` |
| `rescueERC1155(...)` `:286` | `onlyOwner` | none | none | CALL `safeTransferFrom` |
| `onERC1155Received` / `Batch` (inherited) | permissionless | — | none | none |

Public auto-getters: `oldStaker`, `newStaker`, `stakedToken`, `stakedId`, `rewardToken`,
`unforwarded(address)`, `totalUnforwarded`, `owner()`.

## 3. State variables

| Var | Type | Written by | Read by |
|---|---|---|---|
| `oldStaker` `:81` | immutable | ctor | `initiateMigration`, `migrate:171` |
| `newStaker` `:84` | immutable | ctor | `_depositForAndForward:215,218`, `migrate:186,197` |
| `stakedToken` `:87` | immutable | ctor | `migrate:186,197`, `rescueERC1155:288` |
| `stakedId` `:90` | immutable | ctor | **nowhere in logic** — declared but only used as a public getter; the ERC1155 approval is `setApprovalForAll`, id-agnostic. Noted, not a defect. |
| `rewardToken` `:97` | immutable | ctor | `_depositForAndForward`, `claimForwarded`, `rescueERC20` |
| `unforwarded` `:101` | mapping | `_depositForAndForward:231,236`; zeroed `claimForwarded:251` | `claimForwarded:248` |
| `totalUnforwarded` `:105` | uint256 | `+=` `:232,237`; `-=` `:252` | `rescueERC20:272` |

## 4. `migrate(users)` call graph

| Line | Call | Opcode | Target trust |
|---|---|---|---|
| `:171` | `oldStaker.batchMigrate(users)` | CALL | owner-configured staker, **semi-trusted** (deployed + immutable) |
| `:186` | `stakedToken.setApprovalForAll(newStaker, true)` | CALL | trusted ERC1155 |
| `:215` | `IStakerViews(newStaker).pendingReward(user)` | **STATICCALL** (`view` in `IStakerViews:29`) | semi-trusted |
| `:216`, `:220` | `rewardToken.balanceOf(this)` | **STATICCALL** | trusted (phUSD) |
| `:218` | `newStaker.depositFor(user, amount)` | CALL | semi-trusted; **re-enters this contract via `stakedToken.safeTransferFrom` → `onERC1155Received`** |
| `:227` | `rewardToken.transfer(user, captured)` inside `try` | CALL | trusted token, **untrusted `user` recipient** |
| `:197` | `stakedToken.setApprovalForAll(newStaker, false)` | CALL | trusted |

### 4.1 Inbound-callback surface (for interaction analysis)

- `ERC1155Holder.onERC1155Received` is reachable from **any** caller and from inside
  `migrate`: `newStaker.depositFor` pulls the stake with `stakedToken.safeTransferFrom(migrator, staker, …)`
  (`NFTStakerDepletion.sol:760`), and `oldStaker.batchMigrate` pushes stake to the migrator.
  The inherited handler is stateless and returns the selector — **no accounting is finalized
  around it because this contract keeps no ERC1155 accounting at all** (custody is
  intra-transaction only, `:280-285`). Recorded for the scanner; no local finding.
- `rewardToken.transfer(user, …)` at `:227` calls an arbitrary user address only if phUSD has
  a transfer callback. It does not today. `nonReentrant` on both `migrate` `:170` and
  `claimForwarded` `:247` pre-closes it; the NatSpec at `:166-168` says so explicitly.
  **Verified: this is defence-in-depth, not a live hole.**

## 5. Verified local properties

| Property | Status | Evidence |
|---|---|---|
| Checked arithmetic | **verified** | `^0.8.20`, no `unchecked`, no assembly |
| Weak randomness | **verified absent** | no block/tx entropy anywhere |
| Reentrancy guards | **verified** | `migrate:170`, `claimForwarded:247`. `rescueERC20`/`rescueERC1155` unguarded but `onlyOwner`. |
| CEI in `claimForwarded` | **verified** | zero at `:251`, decrement `:252`, transfer `:254` |
| CEI in `migrate` loop | **N/A by construction** | this migrator holds no cross-tx per-user state |
| Access control | **verified** | `onlyOwner` on `:153/:170/:268/:286`; `claimForwarded` is self-only by `msg.sender` indexing |
| Escrowed value unreachable by owner | **verified** | `rescueERC20:270-274` floors at `totalUnforwarded` |
| Zero-address checks | **verified** | ctor `:130-133`, `rescueERC20:269`, `rescueERC1155:287` |
| Reward-token cross-check vs both stakers | **verified** | `:133-140` (checks **both** old and new) |
| Initializer protection | **n/a** | plain constructor, not upgradeable |
| Pause mechanism | **absent** | no `Pausable`. `migrate` is `onlyOwner` so the owner is the circuit breaker. Not a defect. |
| Unbounded loops | **2 sites, owner-supplied input** | `:174` and `:189` iterate `users.length` / `amounts.length`, both owner-batched off-chain (`:169`). Not a griefing surface. |
| `amounts.length == users.length` | **UNVERIFIED — not asserted** | see LOCAL-201 |

## 6. Local findings

**LOCAL-201 — `migrate` never asserts `amounts.length == users.length`.** `:171` takes
`amounts` from `oldStaker.batchMigrate(users)`; the sum loop at `:174` bounds on
`amounts.length` while the redeposit loop at `:189` bounds on `users.length` and indexes
`amounts[i]`. If a staker ever returned a shorter array, `:190` reverts with a panic
(array OOB) rather than a diagnosable error; a longer array would silently drop the tail from
`total` — no, from the redeposit — and mis-report `Migrated(count, total)`.
Reachability today: **none.** Both migration-capable stakers return `new uint256[](users.length)`.
This is an interface-contract assumption, not a live bug. Severity: local **QA / hardening**;
recommendation is a one-line `require(amounts.length == users.length)`.

**LOCAL-202 — `stakedId` `:90` is stored but never used in any code path.** The ERC1155
approval is `setApprovalForAll` (id-agnostic) and `rescueERC1155` takes `id` as a parameter.
The immutable therefore documents intent without enforcing it: a mis-set `stakedId` would be
silently inert, and `rescueERC1155` imposes **no floor at all** on any id (`:278-289`,
justified because custody is intra-transaction). Severity: local **informational**. Contrast
with `InPlaceNFTStakerMigrator`, where `stakedId` *is* load-bearing (`:410-413`).

**LOCAL-203 — the forwarding fix covers the `depositFor` leg only, not the `batchMigrate`
leg.** See `MIGRATOR-FORWARDING-PROFILE.md` §6 for the full argument. Summary: `:171` calls
`oldStaker.batchMigrate(users)` with **no snapshot around it**. If a source staker ever
settled the exiting user's reward to `msg.sender` (the migrator) rather than to the user, that
value would land *before* the per-iteration `pre` snapshot at `:216`, be absorbed into `pre`,
never be forwarded, and become owner-sweepable surplus under `rescueERC20` (it sits above the
`totalUnforwarded` floor). **Not exploitable against either staker in this repo today** —
`NFTStakerDepletion.sol:733` and `NFTStakerPriceScaledMigrateReady.sol:855` both use
`_safePayTo(account, pending)`. The finding is that the contract's own NatSpec claims to be
"version-agnostic across every staker exposing `depositFor`" (`:44-46`), and that claim is
**broader than the protection actually implemented**. Severity: defer; local weight
**low / documentation-vs-implementation mismatch**, with a Law-1 note that it is precisely the
same class of drift that produced `pns20h1`.

## 7. Trust assumptions

- `oldStaker` / `newStaker` are owner-configured, already-deployed, **immutable** contracts.
  The whole forwarding mechanism exists because they cannot be patched.
- `rewardToken` (phUSD) is assumed a standard ERC20: no transfer hook, no fee-on-transfer, no
  rebase, and `transfer` either reverts or returns a correct boolean. The `false`-return branch
  at `:230-234` is handled; a token that returns `false` **while still moving the tokens**
  would desynchronize `totalUnforwarded` from the held balance — see
  `MIGRATOR-FORWARDING-PROFILE.md` §5.2.
- The owner is trusted to batch `users` off-chain to a gas-safe size.
- `IStakerViews.pendingReward` is assumed to project exactly what `depositFor` settles at the
  same timestamp. **This was verified for both in-repo stakers** — see
  `MIGRATOR-FORWARDING-PROFILE.md` §4 — but it is an assumption about any *future* staker.
