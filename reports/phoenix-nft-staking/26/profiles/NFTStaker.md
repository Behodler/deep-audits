# Interface-Abstraction Profile — `NFTStaker`

- **Path**: `/home/justin/code/audits/lib/phoenix-nft-staking/src/NFTStaker.sol`
- **Commit**: `9611312` (`96113129b57ebf7a7c45c65996f792a92c71cdce`)
- **Pragma**: `^0.8.20` (checked arithmetic)
- **Inheritance**: `Ownable`, `Pausable`, `ReentrancyGuard`, `ERC1155Holder`, `IPausable`
- **Depth**: interface-abstraction only. No deep local-property derivation, no findings adjudicated.
- **Role in this run**: ambient context only. Real subject is `BatchNFTMinterMultiToken` / `NudgeStreamer`.

---

## 1. External / public entry points

Legend: `RG` = `nonReentrant`, `WNP` = `whenNotPaused`.

| Function | Access control | RG | WNP | State written | External calls |
|---|---|---|---|---|---|
| `setPauser(address)` | `onlyOwner` | – | – | `pauser` | none |
| `pause()` | `onlyPauser` | – | – | `Pausable._paused` | none |
| `unpause()` | `onlyPauser` | – | – | `Pausable._paused` | none |
| `setDispatcherHook(IBalancerPoolerMintDebtHook)` | `onlyOwner` | – | – | `dispatcherHook` | none (no empty-pool gate — live rotation) |
| `setStakedId(uint256)` | `onlyOwner` + `require(totalStaked==0)` | – | – | `stakedId` | none |
| `setDispatcherIndex(uint256)` | `onlyOwner` + `require(totalStaked==0)` | – | – | `dispatcherIndex`, then `_recomputeSchedule` → `rewardRate`, `rewardBudget`, `windowEnd` | `nftMinter.configs()`, `rewardToken.balanceOf()`, `dispatcherHook.mintDebt()` |
| `setNFTMinter(INFTSupply)` | `onlyOwner` + `require(totalStaked==0)` + non-zero | – | – | `nftMinter`, schedule triple | same as above |
| `setTargetAPY(uint256)` | `onlyOwner`, `<= MAX_TARGET_APY (0.5e18)` | – | – | `_updatePool` → `rewardBudget`, `committedDebt`, `accRewardPerShare`, `lastRewardTime`; `targetAPY`; schedule triple | `nftMinter.configs()`, `rewardToken.balanceOf()`, `dispatcherHook.mintDebt()` |
| `topUp(uint256)` | `onlyOwner`, `amount>0` | – | – | `_updatePool` set; schedule triple | `rewardToken.safeTransferFrom(owner→this)`, `nftMinter.configs()`, `balanceOf`, `dispatcherHook.mintDebt()` |
| `pullAndRefresh()` | `onlyOwner` | – | – | `_syncBudget` set (accrual + schedule triple) | `dispatcherHook.pull()`, `balanceOf` ×2, `nftMinter.configs()`, `mintDebt()` |
| `stake(uint256)` | **none (permissionless)** | ✅ | ✅ | `_syncBudget` set; `users[msg.sender].amount/.rewardDebt`, `totalStaked`, `committedDebt`/`rewardBudget` (via `_safePay`), schedule triple (tail recompute) | `dispatcherHook.pull()`, `rewardToken.balanceOf/safeTransfer`, `stakedToken.safeTransferFrom(user→this)`, `nftMinter.configs()`, `mintDebt()` |
| `unstake(uint256)` | **none** (`require(user.amount>=amount)`) | ✅ | ✅ | same set as `stake`, plus `totalStaked -=` | `dispatcherHook.pull()`, `rewardToken.balanceOf/safeTransfer`, **`stakedToken.safeTransferFrom(this→msg.sender)`**, `nftMinter.configs()`, `mintDebt()` |
| `claim()` | **none** | ✅ | ✅ | `_syncBudget` set; `users[msg.sender].rewardDebt`, `committedDebt`/`rewardBudget` | `dispatcherHook.pull()`, `rewardToken.balanceOf/safeTransfer`, `nftMinter.configs()`, `mintDebt()` |
| `emergencyWithdraw()` | **none**; **callable while paused** | ✅ | ❌ (deliberate) | `users[msg.sender]` zeroed, `totalStaked -=`, `committedDebt -= forfeit`, `rewardBudget += forfeit` | **`stakedToken.safeTransferFrom(this→msg.sender)`** only. No `_syncBudget`/`_updatePool` — principal cannot be trapped by a broken hook/minter |
| `onERC1155Received` / `onERC1155BatchReceived` / `supportsInterface` | public (from `ERC1155Holder`) | – | – | none | none |
| views: `pendingReward`, `currentRewardRate`, `totalDebt`, `totalBudget`, `runwaySeconds`, `users`, plus auto-getters | public view | – | – | none | `dispatcherHook.mintDebt()`, `rewardToken.balanceOf()` in 3 of them |
| `transferOwnership` / `renounceOwnership` | `onlyOwner` (OZ) | – | – | `_owner` | none |

No initializer / proxy pattern (immutables + constructor). No assembly.

---

## 2. External calls out

| Target | Interface / methods | Trust level | Assumed of callee |
|---|---|---|---|
| `rewardToken` (phUSD) | `IERC20` via `SafeERC20`: `balanceOf`, `safeTransfer`, `safeTransferFrom` | semi-trusted (first-party phUSD) | Return value trusted via SafeERC20 (bool-or-revert normalised). **No fee-on-transfer, no rebase, no ERC777 hooks** — `topUp` assumes credited amount == stated amount. `balanceOf` assumed exact and monotone w.r.t. own transfers. Decimals never read; all math is raw wei. Assumed non-reentrant on transfer. |
| `stakedToken` (ERC1155 NFT, same address as `nftMinter` in production) | `IERC1155.safeTransferFrom(from,to,id,amount,"")` | semi-trusted first-party, but **it calls back** | Assumed to move exactly `amount` of `stakedId` and to revert on failure. Assumed to invoke `onERC1155Received` on the recipient (see §4). Assumed no supply-side fee/burn on transfer. |
| `nftMinter` | `INFTSupply.configs(dispatcherIndex)` → `(_, price, growthBasisPoints, _)` | semi-trusted first-party | **Return value fully trusted, unvalidated**: `price` and `growthBasisPoints` flow straight into the rate. `price==0` handled (rate 0); `growthBasisPoints==0` handled. A wrong `dispatcherIndex` silently mis-prices the schedule (index bounds not checked here). Assumed to revert rather than return garbage on an out-of-range index. Assumed same decimal basis as `rewardToken`. |
| `dispatcherHook` | `IBalancerPoolerMintDebtHook.pull()`, `.mintDebt()` | semi-trusted first-party, **externally-imposed permission** | `pull()` return value ignored; effect is *measured* as a balance delta (§3). `pull()` assumed to either mint phUSD to this contract or no-op. Hook's own `pull()` is caller-gated, so this staker must be the hook `recipient`/owner. `mintDebt()` treated as claimable value in `V` and in three views — if the hook over-reports, `V` and hence `rewardBudget`/`windowEnd` over-state (recompute clamps `budget` at zero when `V < committedDebt`, so it cannot underflow). A reverting hook DoSes `stake`/`unstake`/`claim` but **not** `emergencyWithdraw`. |

---

## 3. Value flow map

### ERC20 (`rewardToken` / phUSD)

| Path | Debited | Credited | Order | Amount basis |
|---|---|---|---|---|
| `topUp(amount)` | owner | this contract | `_updatePool()` → `safeTransferFrom` → `_recomputeSchedule()` (budget re-derived from post-transfer `balanceOf`) | **STATED** on the transfer; the resulting `rewardBudget` is **MEASURED** (`balanceOf + mintDebt - committedDebt`), so a fee-on-transfer/rebasing reward token would silently self-correct the budget while the `ToppedUp` event reports the stated amount |
| `_syncBudget()` → `dispatcherHook.pull()` | dispatcher hook / phUSD minter | this contract | `pre = balanceOf` → `pull()` → `inflow = balanceOf - pre` → `_recomputeSchedule()` → emit `Pulled(inflow, …)` | **MEASURED balance delta.** `inflow` is used only for the event and the `inflow>0` emit gate; the budget itself is re-derived from `balanceOf`, so the accounting does not depend on `inflow` being right. Note the delta is measured across an external call, so any *other* inflow landing in the same call is attributed to the hook |
| `_safePay(amount)` (from `stake`/`unstake`/`claim`) | this contract | `msg.sender` | `require(balanceOf >= amount)` → `safeTransfer` → then decrement `committedDebt`, spilling into `rewardBudget` if `amount > committedDebt` | **STATED** (`pending` derived from `accRewardPerShare`). Balance check precedes the transfer; bookkeeping follows it (non-CEI on the state-decrement, mitigated by `nonReentrant` + trusted token). Reverts on shortfall — no silent forfeiture |
| `emergencyWithdraw()` | — (no ERC20 movement) | — | forfeited `pending` moved `committedDebt → rewardBudget`; phUSD stays in the contract and recycles as runway | **STATED**, clamped to `committedDebt` to absorb floor dust |

Invariant the code maintains at every exit: `balanceOf(this) == rewardBudget + committedDebt`.

### ERC1155 (`stakedToken`, `stakedId`)

| Path | Debited | Credited | Order | Amount basis |
|---|---|---|---|---|
| `stake(amount)` | `msg.sender` | this contract | reward settled first → `safeTransferFrom(user→this)` → `user.amount += amount`, `totalStaked += amount` → `rewardDebt` reset → `_recomputeSchedule()` | **STATED**. Credited amount is the *stated* argument, never a measured `balanceOf(this, stakedId)` delta. A non-standard 1155 that moved less than `amount` would over-credit the staker |
| `unstake(amount)` | this contract | `msg.sender` | accounting decremented **before** the transfer → transfer → `_recomputeSchedule()` **after** the transfer | **STATED** |
| `emergencyWithdraw()` | this contract | `msg.sender` | full accounting zeroed **before** the transfer | **STATED** (`user.amount`) |

No ERC1155 batch paths, no `id` other than the single mutable `stakedId`.

---

## 4. Inbound callback surface

Two directions:

- **Inbound as receiver**: `ERC1155Holder` supplies `onERC1155Received` / `onERC1155BatchReceived`, which accept unconditionally (no `id`/`operator`/amount filtering). Consequence: any ERC1155 of any collection/id can be pushed into this contract; only units credited through `stake`/`depositFor`-style accounting are tracked, so unsolicited units are stranded (there is no ERC1155 rescue function on this contract). Purely a custody note here.
- **Outbound-triggering-inbound (the real surface)**: `stakedToken.safeTransferFrom(address(this), msg.sender, …)` in `unstake` and `emergencyWithdraw` sends to an **arbitrary, attacker-controllable recipient**, so the 1155 fires `onERC1155Received` on `msg.sender` mid-call. Also `stake` pulls `from = msg.sender`, whose 1155 hook fires on *this* contract (benign, `ERC1155Holder`).

Accounting-finalized-before-hook status:

| Site | Position accounting | Schedule state (`rewardRate`/`rewardBudget`/`windowEnd`) | Guard |
|---|---|---|---|
| `unstake` :471 | ✅ finalized before hook (`user.amount`, `totalStaked`, `rewardDebt` all written at :468–470) | ❌ **NOT finalized** — the tail `_recomputeSchedule()` at :476 runs *after* the hook returns. During the hook, `totalStaked` is already reduced while `rewardRate` is still sized for the larger pool | `nonReentrant` blocks re-entry into `stake`/`unstake`/`claim`/`emergencyWithdraw`; the stale window is observable to **view** callers (`pendingReward`, `currentRewardRate`, `runwaySeconds`) and to any cross-contract reader during the hook |
| `emergencyWithdraw` :559 | ✅ fully finalized before hook | n/a — deliberately does not recompute | `nonReentrant` |
| `stake` :445 (inbound to self) | reward settled before; position credited after | tail recompute at :455 | `nonReentrant` |

Recorded, not adjudicated — cross-contract exploitability is for the interaction scanner.

---

## 5. Nudge / BatchNFTMinter coupling

**NO.** `NFTStaker.sol` contains zero references — not even in comments — to `BatchNFTMinter`, `BatchNFTMinterMultiToken`, `NudgeStreamer`, `INudgeStreamer`, or a "nudge" concept.

```
$ grep -rniE "batchnftminter|nudge|streamer" src/NFTStaker.sol
(no output)

$ grep -rncE "Nudge|nudge|BatchNFTMinter" src/NFTStaker.sol
src/NFTStaker.sol:0
```

Its only external couplings are the four in §2 (`rewardToken`, `stakedToken`, `nftMinter`/`INFTSupply`, `dispatcherHook`/`IBalancerPoolerMintDebtHook`). There is **no on-chain coupling** to the nudge/minter subsystem in either direction: no address field, no interface import, no call site, no event.
