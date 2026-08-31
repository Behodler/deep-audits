# Interface-Abstraction Profile — `NFTStakerDepletionV2`

- **Path**: `/home/justin/code/audits/lib/phoenix-nft-staking/src/NFTStakerDepletionV2.sol`
- **Commit**: `9611312` (`96113129b57ebf7a7c45c65996f792a92c71cdce`)
- **Pragma**: `^0.8.20` (checked arithmetic)
- **Inheritance**: `Ownable`, `Pausable`, `ReentrancyGuard`, `ERC1155Holder`, `IPausable`, `INFTStakerMigratable`
- **Depth**: interface-abstraction only. No deep local-property derivation, no findings adjudicated.
- **Role in this run**: ambient context only. Real subject is `BatchNFTMinterMultiToken` / `NudgeStreamer`.
- **Provenance**: hand-maintained copy of `NFTStakerDepletion` (itself a copy of `NFTStaker`). Emission model is inverted: owner sets `depletionWindowMonths`, rate is **derived** as `rewardBudget / windowSeconds`. `targetAPY`/`latestPrice`/notional math is dropped; `nftMinter` + `dispatcherIndex` are retained as *identity only*.
- **Lifecycle**: `PoolState { Active, Migrating }`, plus a `migrator` role.

---

## 1. External / public entry points

Legend: `RG` = `nonReentrant`, `WNP` = `whenNotPaused`, `PS` = `poolState` gate.

| Function | Access control | RG | WNP | PS gate | State written | External calls |
|---|---|---|---|---|---|---|
| `setPauser(address)` | `onlyOwner` | – | – | – | `pauser` | none |
| `setMigrator(address)` | `onlyOwner` | – | – | – | `migrator` (no empty-pool gate; `0` disables migration) | none |
| `pause()` / `unpause()` | `onlyPauser` | – | – | – | `_paused` | none |
| `setDispatcherHook(IUniboostMintDebtHook)` | `onlyOwner` | – | – | – | `dispatcherHook` | none |
| `setStakedId(uint256)` | `onlyOwner` + `totalStaked==0` | – | – | – | `stakedId` | none |
| `setDispatcherIndex(uint256)` | `onlyOwner` + `totalStaked==0` | – | – | – | `dispatcherIndex` + schedule quad | `balanceOf`, `mintDebt()` |
| `setNFTMinter(INFTSupply)` | `onlyOwner` + `totalStaked==0` + non-zero | – | – | – | `nftMinter` + schedule quad | `balanceOf`, `mintDebt()` |
| `setDepletionWindow(uint256 months)` | `onlyOwner`, `1 <= months <= 120` | – | – | – | `_updatePool` set; `depletionWindowMonths`; schedule quad | `balanceOf`, `mintDebt()` |
| `topUp(uint256)` | `onlyOwner`, `amount>0` | – | – | – | `_updatePool` set; schedule quad | `rewardToken.safeTransferFrom(owner→this)`, `balanceOf`, `mintDebt()` |
| `pullAndRefresh()` | `onlyOwner` | – | – | – | `_syncBudget` set | `dispatcherHook.pull()`, `balanceOf` ×2, `mintDebt()` |
| `rescueERC20(IERC20,address,uint256)` | `onlyOwner`, `to != 0`; **callable while paused** | ❌ **no `nonReentrant`** | ❌ | – | if `token == rewardToken`: `_updatePool` set + schedule quad; else none | `token.safeTransfer(to, amount)`; reward-token branch adds `_updatePool`, post-check `balanceOf >= committedDebt`, `_recomputeSchedule` |
| `stake(uint256)` | **none (permissionless)**, `amount>0` | ✅ | ✅ | **`Active` required** (audit-20 M-05) | `_syncBudget` set; `users[msg.sender]`, `totalStaked`, `committedDebt`/`rewardBudget` | `pull()`, `rewardToken.balanceOf/safeTransfer`, `stakedToken.safeTransferFrom(user→this)`, `mintDebt()`. **No tail `_recomputeSchedule`** (rate is `totalStaked`-independent) |
| `unstake(uint256)` | **none**, `user.amount>=amount` | ✅ | ✅ | **ungated by design** (drains pool to 0 so `finalizeAndReset` is reachable) | same set, `totalStaked -=` | `pull()`, `balanceOf/safeTransfer`, **`stakedToken.safeTransferFrom(this→msg.sender)`**, `mintDebt()` |
| `claim()` | **none** | ✅ | ✅ | **ungated** (settles benignly against frozen `accRewardPerShare`) | `_syncBudget` set; `rewardDebt`, `committedDebt`/`rewardBudget` | `pull()`, `balanceOf/safeTransfer`, `mintDebt()` |
| `emergencyWithdraw()` | **none**; **callable while paused** | ✅ | ❌ (deliberate) | ungated | `users[msg.sender]` zeroed, `totalStaked -=`, `committedDebt -= forfeit`, `rewardBudget += forfeit` | **`stakedToken.safeTransferFrom(this→msg.sender)`** only; no `_syncBudget`/`_updatePool` |
| `initiateMigration()` | `onlyMigrator` | ✅ | ❌ | requires `Active` → sets `Migrating` | `_syncBudget` set; `poolState` | `pull()`, `balanceOf` ×2, `mintDebt()` |
| `batchMigrate(address[])` | `onlyMigrator` | ✅ | ❌ (works while paused) | requires `Migrating` | per user: `users[a]` zeroed, `totalStaked -=`, `committedDebt`/`rewardBudget` | per user `rewardToken.balanceOf/safeTransfer(user)`; one aggregate **`stakedToken.safeTransferFrom(this→migrator)`**. **Unbounded caller-supplied loop** over `accounts` (migrator-only, batched off-chain) |
| `userMigrate()` | **none (permissionless)** | ✅ | ❌ | requires `Migrating` + non-zero position | `users[msg.sender]` zeroed, `totalStaked -=`, `committedDebt`/`rewardBudget` | `balanceOf/safeTransfer(self)`, **`stakedToken.safeTransferFrom(this→msg.sender)`** |
| `depositFor(address user, uint256 amount)` | `onlyMigrator`, `amount>0`; callable while paused | ✅ | ❌ | **`Active` required** | `_syncBudget` set; `users[user]`, `totalStaked`, `committedDebt`/`rewardBudget`; schedule quad (tail recompute) | `pull()`, `rewardToken.balanceOf/safeTransfer(user)`, `stakedToken.safeTransferFrom(migrator→this)`, `mintDebt()` |
| `finalizeAndReset()` | `onlyOwner` | ❌ | ❌ (works while paused) | requires `Migrating` + `totalStaked==0` → `Active` | `lastRewardTime`, `poolState` | none |
| `userInfo(address)` | external view (`INFTStakerMigratable`) | – | – | – | none | none |
| `pendingReward` / `currentRewardRate` / `totalDebt` / `totalBudget` / `runwaySeconds` | external view | – | – | – | none | `mintDebt()`, `balanceOf` in 3 |
| `onERC1155Received` / `onERC1155BatchReceived` / `supportsInterface` | public (`ERC1155Holder`) | – | – | – | none | none |
| `transferOwnership` / `renounceOwnership` | `onlyOwner` (OZ) | – | – | – | `_owner` | none |

"schedule quad" = `rewardRate`, `rewardBudget`, `windowEnd`, `lastRewardTime` (V2's `_recomputeSchedule` also pins `lastRewardTime`, unlike `NFTStaker`'s). No initializer / proxy. No assembly. One custom error: `Rescue__ZeroRecipient`.

---

## 2. External calls out

| Target | Interface / methods | Trust level | Assumed of callee |
|---|---|---|---|
| `rewardToken` (phUSD) | `IERC20` via `SafeERC20`: `balanceOf`, `safeTransfer`, `safeTransferFrom` | semi-trusted first-party | SafeERC20 normalises bool-or-revert. **No fee-on-transfer, no rebase, no ERC777 hooks.** Decimals never read. Assumed non-reentrant. |
| `token` argument of `rescueERC20` | `IERC20.safeTransfer` on an **arbitrary owner-supplied address** | **untrusted** | Owner-chosen callee invoked with **no reentrancy guard** and no `whenNotPaused`. A malicious/hostile `token` gets control mid-call; in the `token != rewardToken` branch no staker state is touched, and in the `token == rewardToken` branch the address equality forces the trusted token. Owner-reachable only (Law 3: obvious-misuse suppressed), recorded for completeness. |
| `stakedToken` (ERC1155) | `IERC1155.safeTransferFrom(from,to,id,amount,"")` | semi-trusted first-party that **calls back** | Moves exactly `amount` of `stakedId`, reverts on failure, fires `onERC1155Received` on the recipient (§4). No burn/fee on transfer. |
| `nftMinter` | `INFTSupply` — **retained but never called in V2** (identity only) | n/a | V2's `_recomputeSchedule` dropped the `configs(dispatcherIndex)` read entirely, so the minter is a pure wiring reference. Consequence: `setDispatcherIndex`/`setNFTMinter` recompute nothing price-dependent; their `_recomputeSchedule` only re-pins the window. |
| `dispatcherHook` | `IUniboostMintDebtHook.pull()`, `.mintDebt()` | semi-trusted first-party, externally-imposed permission | `pull()` is `onlyOwnerOrRecipient` on the hook, so this staker must be the hook's `recipient`/owner or every `_syncBudget` reverts → `stake`/`unstake`/`claim`/`depositFor`/`initiateMigration` DoS (`emergencyWithdraw` and `rescueERC20` survive). `pull()` return ignored; effect **measured** as a balance delta. `mintDebt()` counted into `V` and into `totalBudget`/`runwaySeconds`; over-reporting inflates `rewardBudget`/rate, under-reporting deflates; `budget` clamps at 0 when `V < committedDebt`. |

---

## 3. Value flow map

### ERC20 (`rewardToken` / phUSD)

| Path | Debited | Credited | Order | Amount basis |
|---|---|---|---|---|
| `topUp(amount)` | owner | this contract | `_updatePool()` → `safeTransferFrom` → `_recomputeSchedule()` | transfer **STATED**; resulting `rewardBudget` **MEASURED** from post-transfer `balanceOf + mintDebt - committedDebt`. `ToppedUp` event reports the *stated* amount, so a lossy token would desync event vs budget |
| `_syncBudget()` → `pull()` | hook / phUSD minter | this contract | `pre = balanceOf` → `pull()` → `inflow = balanceOf - pre` → **only if `inflow > 0`**: `_recomputeSchedule()` + `Pulled` | **MEASURED delta**, and here the delta is **load-bearing**: unlike `NFTStaker`, V2 gates the recompute on `inflow > 0`. A zero-inflow `pull()` leaves `rewardRate`/`windowEnd` untouched (intended: a non-zero inflow *restarts* the depletion window). Any unrelated phUSD arriving during the same call is attributed to the hook and can trigger a window restart |
| `_safePay(amount)` → `_safePayTo(msg.sender, …)` | this contract | `msg.sender` (`stake`/`unstake`/`claim`) | `require(balanceOf >= amount)` → `safeTransfer` → decrement `committedDebt`, spill to `rewardBudget` | **STATED** (`pending` from `accRewardPerShare`); reverts on shortfall |
| `_safePayTo(account, amount)` | this contract | **`account`**, not `msg.sender` | used by `_exitPosition` (`batchMigrate`, `userMigrate`) and by `depositFor`'s pre-credit settlement | **STATED**. This is the audit-21 M-03 / run-20 DRIFT-01 fix: V1's `depositFor` used `_safePay`, i.e. paid the **migrator** while emitting `Claimed(user, …)`. V2 pays the user. |
| `rescueERC20(rewardToken, to, amount)` | this contract | owner-chosen `to` | `_updatePool()` → `safeTransfer` → `require(balanceOf >= committedDebt)` → `_recomputeSchedule()` | **STATED**; the post-transfer solvency check is a **MEASURED** `balanceOf` assertion. Only genuine surplus is removable; `rewardBudget`/rate/window re-derive downward |
| `emergencyWithdraw()` | — | — | forfeit moved `committedDebt → rewardBudget`, phUSD stays in balance | **STATED**, clamped to `committedDebt` |

Maintained invariant: `balanceOf(this) == rewardBudget + committedDebt`.

### ERC1155 (`stakedToken`, `stakedId`)

| Path | Debited | Credited | Order | Amount basis |
|---|---|---|---|---|
| `stake(amount)` | `msg.sender` | this contract | reward settled → `safeTransferFrom(user→this)` → `user.amount +=`, `totalStaked +=` → `rewardDebt` reset | **STATED** (never a measured `balanceOf(this, stakedId)` delta) |
| `depositFor(user, amount)` | **`msg.sender` (the migrator)** | this contract, credited to `user` | `_syncBudget` → settle `user`'s pending to `user` → `safeTransferFrom(migrator→this)` → credit `users[user]`, `totalStaked +=` → `_recomputeSchedule()` | **STATED**. Debited party (migrator) ≠ credited party (`user`) — deliberate, and the reason `_safePayTo` exists |
| `unstake(amount)` | this contract | `msg.sender` | accounting decremented **before** transfer | **STATED** |
| `batchMigrate(accounts)` | this contract | **the migrator** (aggregate), rewards to each user | loop `_exitPosition` (each: zero position, `totalStaked -=`, pay reward to `account`) → **one** aggregate `safeTransferFrom(this→migrator, Σamounts)` | **STATED** per user; the aggregate is the **sum of stated per-user amounts**. Idempotent: already-zeroed users contribute 0 |
| `userMigrate()` | this contract | `msg.sender` | `_exitPosition(msg.sender)` (full accounting) → transfer | **STATED** |
| `emergencyWithdraw()` | this contract | `msg.sender` | full accounting zeroed before transfer | **STATED** |

No batch ERC1155 methods; single mutable `stakedId` throughout.

---

## 4. Inbound callback surface

- **As receiver**: `ERC1155Holder` accepts any `onERC1155Received` / `onERC1155BatchReceived` unconditionally (no collection/id/amount filter). Unsolicited 1155 units are untracked; there is no ERC1155 rescue (only `rescueERC20`), so they are stranded. Custody note only.
- **Outbound-triggering-inbound (the real surface)** — `stakedToken.safeTransferFrom` to a recipient that can be an arbitrary contract:

| Site | Recipient | Position accounting finalized before hook? | Schedule state finalized? | Guard |
|---|---|---|---|---|
| `unstake` :590 | `msg.sender` (**attacker-controlled**) | ✅ (`user.amount`, `totalStaked`, `rewardDebt` at :587–589) | ✅ — V2 has **no tail recompute** on `unstake`, so no stale-window window exists (unlike `NFTStaker`) | `nonReentrant`, `whenNotPaused` |
| `emergencyWithdraw` :652 | `msg.sender` (**attacker-controlled**) | ✅ fully | n/a (deliberately no recompute) | `nonReentrant` |
| `userMigrate` :726 | `msg.sender` (**attacker-controlled**) | ✅ — `_exitPosition` zeroes the position and pays the reward before returning; strict CEI | frozen (`Migrating`) | `nonReentrant` |
| `batchMigrate` :710 | **`msg.sender` = the `migrator` contract** | ✅ — the entire loop completes before the single aggregate transfer | frozen (`Migrating`) | `nonReentrant`, `onlyMigrator`. The migrator receives control after all positions are zeroed |
| `depositFor` :786 | inbound `from = migrator` → hook fires on **this** contract (`ERC1155Holder`, benign) | reward settled before; position credited after | tail recompute at :793 | `nonReentrant`, `onlyMigrator` |
| `stake` :570 | inbound `from = msg.sender` → hook fires on this contract (benign) | position credited after | no tail recompute | `nonReentrant` |

Also note: `rescueERC20` hands control to an **arbitrary owner-supplied ERC20** with **no `nonReentrant`**, i.e. it is the one entry point on this contract that can be re-entered from an external callee. Recorded, not adjudicated.

---

## 5. Nudge / BatchNFTMinter coupling

**NO on-chain coupling.** The only hits are two **NatSpec comment** references to `BatchNFTMinter` used purely as a design-pattern citation for `rescueERC20`. There is no import, no address field, no interface, no call site, and **zero** occurrences of `nudge` / `Nudge` / `NudgeStreamer` / `INudgeStreamer` / `BatchNFTMinterMultiToken`.

```
$ grep -rniE "batchnftminter|nudge|streamer" src/NFTStakerDepletionV2.sol
src/NFTStakerDepletionV2.sol:259:    ///      `BatchNFTMinter.Rescued`.
src/NFTStakerDepletionV2.sol:403:    ///         `BatchNFTMinter.rescueERC20`: zero-recipient guard, explicit
```

Line 259 documents `event Rescued` ("Mirrors `BatchNFTMinter.Rescued`"); line 403 documents `rescueERC20` ("Modelled on `BatchNFTMinter.rescueERC20`"). Both are comments on independent, self-contained code. Grep for the nudge subsystem specifically returns nothing:

```
$ grep -rnE "INudgeStreamer|NudgeStreamer|nudge|BatchNFTMinterMultiToken" src/NFTStakerDepletionV2.sol
(no output)
```

Actual external couplings are the five in §2: `rewardToken`, `stakedToken`, `nftMinter` (declared, never called), `dispatcherHook` (`IUniboostMintDebtHook`), and the arbitrary `rescueERC20` token. Plus the `migrator` address (called *into* this contract, not out of it).
