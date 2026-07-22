# Contract profile — `src/InPlaceNFTStakerMigrator.sol`

- Run: `phoenix-nft-staking-21`
- Submodule HEAD: `c881a42` (changed this cycle at `f3b92c0`, story-023, **+149 lines**)
- Profiled: **COLD**
- Solidity: `^0.8.20`; LOC 449; no `unchecked`, no assembly
- Inheritance: `Ownable`, `ReentrancyGuard`, `ERC1155Holder` (`:77`)

## 1. What changed

Same story-023 settlement-capture forwarding as `NFTStakerMigrator`. New surface:
`rewardToken` `:100`, `unforwarded` `:125`, `totalUnforwarded` `:129`, three events
`:146/:150/:153`, `_depositForAndForward` `:311`, `claimForwarded` `:345`, and a
`totalUnforwarded` floor added to the previously-unconditional `rescueERC20` `:390-398`.
Constructor gained `IERC20 _rewardToken` plus a zero-check `:166` and a cross-check against
`IStakerViews(staker).rewardToken()` `:167-170`.

Mechanism deep-dive and D-6 parity verification: **`MIGRATOR-FORWARDING-PROFILE.md`**.

## 2. External / public surface

| Function | Access | Guards | State written | External calls |
|---|---|---|---|---|
| `constructor(...)` `:155` | — | 5 `require`s `:163-170` | immutables | STATICCALL `staker.rewardToken()` `:168` |
| `initiateMigration()` `:207` | `onlyOwner` | — | none | CALL `staker.initiateMigration()` |
| `migrateOut(address[])` `:219` | `onlyOwner` | `nonReentrant` | `parked`, `migrationBegin`, `_parkedUsers`, `_parkedIndex`, `totalParked` | CALL `staker.batchMigrate` |
| `migrateIn(uint256,uint256)` `:253` | `onlyOwner` | `nonReentrant` | all of the above (cleared) + `unforwarded`, `totalUnforwarded` | see §4 |
| `claimForwarded()` `:345` | **permissionless, self-only** | `nonReentrant` | `unforwarded[msg.sender]`, `totalUnforwarded` | CALL `safeTransfer` |
| `claimTimedOut()` `:364` | **permissionless, self-only** | `nonReentrant` | `parked`, `migrationBegin`, `totalParked`, set | CALL `stakedToken.safeTransferFrom` |
| `rescueERC20(...)` `:390` | `onlyOwner` | — | none | STATICCALL `balanceOf` + CALL `safeTransfer` |
| `rescueERC1155(...)` `:408` | `onlyOwner` | — | none | STATICCALL `balanceOf` + CALL `safeTransferFrom` |
| `parkedUserCount()` `:421` / `parkedUsersRange(...)` `:426` / `claimableAt(address)` `:442` | view | — | — | — |
| `onERC1155Received` / `Batch` (inherited) | permissionless | — | none | none |

## 3. State variables

| Var | Type | Written by | Read by |
|---|---|---|---|
| `staker` `:83` | immutable | ctor | `initiateMigration`, `migrateOut:220`, `migrateIn:272,297`, `_depositForAndForward:312,315` |
| `stakedToken` `:86` / `stakedId` `:89` | immutable | ctor | `migrateIn:272,297`, `claimTimedOut:376`, `rescueERC1155:410-415` |
| `migrationTimeout` `:93` | immutable | ctor (bounded `:165` to `[MIN_TIMEOUT 1 days, MAX_TIMEOUT 30 days]`) | `claimTimedOut:367`, `claimableAt:447` |
| `rewardToken` `:100` | immutable | ctor | `_depositForAndForward`, `claimForwarded`, `rescueERC20` |
| `parked` `:103` | mapping | `migrateOut:227` (+=), `migrateIn:284` (=0), `claimTimedOut:370` (=0) | `migrateIn:279`, `claimTimedOut:365` |
| `migrationBegin` `:107` | mapping | `migrateOut:228`, deleted `:285`/`:371` | `claimTimedOut:367`, `claimableAt:443` |
| `_parkedUsers` `:113` / `_parkedIndex` `:116` | array + index (1-based) | `_addParked:181`, `_removeParked:189` | `migrateIn:254,265`, views |
| `totalParked` `:121` | uint256 | `+=` `:230`, `-=` `:286`/`:372` | `migrateIn:271`, `rescueERC1155:412` |
| `unforwarded` `:125` | mapping | `+=` `:328,333`; `=0` `:349` | `claimForwarded:346` |
| `totalUnforwarded` `:129` | uint256 | `+=` `:329,334`; `-=` `:350` | `rescueERC20:394` |

## 4. `migrateIn(start, end)` call graph

| Line | Call | Opcode | Trust |
|---|---|---|---|
| `:272` | `stakedToken.setApprovalForAll(staker, true)` | CALL | trusted ERC1155 |
| `:312` | `IStakerViews(staker).pendingReward(user)` | **STATICCALL** | semi-trusted, immutable |
| `:313`, `:317` | `rewardToken.balanceOf(this)` | **STATICCALL** | trusted (phUSD) |
| `:315` | `staker.depositFor(user, amt)` | CALL | semi-trusted; re-enters via `onERC1155Received` |
| `:324` | `rewardToken.transfer(user, captured)` in `try` | CALL | trusted token, **untrusted recipient** |
| `:297` | `stakedToken.setApprovalForAll(staker, false)` | CALL | trusted |

### 4.1 Inbound-callback surface

`ERC1155Holder.onERC1155Received` is reachable permissionlessly and from inside
`migrateOut`/`migrateIn`/`claimTimedOut`. **All accounting is finalized before every outbound
1155 transfer**: `migrateIn` zeroes `parked[user]`, deletes `migrationBegin`, decrements
`totalParked` and removes the set entry at `:284-287` *before* `_depositForAndForward` at
`:294`; `claimTimedOut` does the same at `:370-373` before the transfer at `:376`. Strict CEI,
plus `nonReentrant` on all three. **Verified — no reentrancy adjudication needed.**

## 5. Verified local properties

| Property | Status | Evidence |
|---|---|---|
| Checked arithmetic | **verified** | `^0.8.20`, no `unchecked`, no assembly |
| Weak randomness | **verified absent** | `block.timestamp` is used only at `:228` (migration start) and `:367` (timeout comparison) — **timekeeping, not entropy, and not value-bearing**. Not a randomness finding. |
| Reentrancy guards | **verified** | `:219`, `:253`, `:345`, `:364` |
| Strict CEI on every value-releasing path | **verified** | `:284-294`, `:349-352`, `:370-376` |
| Access control | **verified** | `onlyOwner` on `:207/:219/:253/:390/:408`; `claimForwarded`/`claimTimedOut` self-only via `msg.sender` indexing |
| Parked principal unreachable by owner | **verified** | `rescueERC1155:410-413` floors at `totalParked` for `id == stakedId` |
| Escrowed reward unreachable by owner | **verified** | `rescueERC20:392-396` floors at `totalUnforwarded` |
| Timeout bounded, no zero/tiny value | **verified** | `:165`, `MIN_TIMEOUT 1 days` `:134`, `MAX_TIMEOUT 30 days` `:138` |
| Set add/remove idempotent, swap-remove correct | **verified** | `:181-200`; 1-based index so `0` is a valid "absent" sentinel |
| Index-shift hazard in `migrateIn` handled | **verified** | slice snapshotted to memory at `:262-266` *before* the loop mutates the set |
| Range clamping | **verified** | `:255-258` clamps `end`, requires `start <= end`; `parkedUsersRange:428-433` clamps both |
| Initializer protection | **n/a** | plain constructor |
| Pause mechanism | **absent** | no `Pausable`; owner-gated entrypoints act as the breaker. Note `claimTimedOut` and `claimForwarded` are permissionless and **cannot be frozen** — deliberate (they are the user escape hatches). |
| Unbounded loops | **paginated** | `migrateIn` is `[start, end)`-sliced `:253`; `migrateOut` iterates an owner-supplied array `:224`. `_parkedUsers` growth is bounded by owner action only. |

## 6. Local findings

**LOCAL-301 — the forwarding mechanism is a structural no-op on the primary in-place flow.**
In `_depositForAndForward:312`, `owed = pendingReward(user)` is read on the **same** staker the
user was just migrated out of. While parked, `users[user].amount == 0` and `rewardDebt == 0`
(zeroed by `batchMigrate`), so `pendingReward` returns `0`
(`NFTStakerDepletion.sol:812`, `NFTStakerPriceScaledMigrateReady.sol:960`). Symmetrically,
`depositFor` only settles when `info.amount > 0` (`NFTStakerDepletion.sol:753`), so `captured`
is also `0`. **`0 <= 0` — the tripwire holds and nothing is forwarded, correctly.**
The mechanism only becomes live in the partial-round-trip case: a parked user who re-stakes
directly after `finalizeAndReset` returns the pool to `Active`, and is then re-injected by
`migrateIn`. That case is covered and correct. **This is a "verified benign" note, not a
defect** — recorded because a reviewer seeing `owed == 0` might otherwise read it as a
mis-wired bound.

**LOCAL-302 — a single tripping user reverts the entire `migrateIn` slice.**
`require(captured <= owed, "Migrator: capture exceeds owed")` at `:318` sits inside the
`:277-295` loop. Any foreign reward-token inflow arriving mid-call (the documented case: a
dispatcher hook whose `recipient` is mispointed at this migrator) aborts the whole slice, not
just the affected user. Recovery is available (the owner re-slices around the user, or fixes
the hook wiring), and the alternative — silently mis-attributing foreign value to whichever
user the loop is on — is strictly worse. **Fail-closed and intended** (`:52-59`). Severity:
local **informational / operational**; downstream should note it as an availability
consideration, not a vulnerability. Pinned by `testE2_MispointedHookRecipientRevertsInsteadOfOverCrediting`.

**LOCAL-303 — `rescueERC20` and `claimForwarded` both brick if the held reward balance ever
falls below `totalUnforwarded`.** `:394` computes `balance - totalUnforwarded` with checked
arithmetic: if `balance < totalUnforwarded` this **underflow-reverts**, permanently disabling
reward-token rescue; `claimForwarded:352` would likewise revert on insufficient balance. The
only reachable path is a reward token whose `transfer` returns `false` *while still moving the
tokens* (`:324-331` credits the escrow on a `false` return). **Not reachable with phUSD**,
which is a standard ERC20 — marked **token-conditional / unverified for any future reward
token**. Severity: local **QA**; recommendation is to clamp
(`balance > totalUnforwarded ? balance - totalUnforwarded : 0`) rather than let it revert, and
mirror the clamp in `NFTStakerMigrator.sol:272`.

**LOCAL-304 — `claimTimedOut` timeout starts at the LAST `migrateOut`, and `parked` is
`+=`-accumulated.** `:227-228`: `parked[user] += amt` accumulates, but
`migrationBegin[user] = block.timestamp` is **overwritten**, resetting the escape-hatch clock
for the user's *entire* parked balance including previously-parked amounts. Reachable only if
the owner runs `migrateOut` twice for the same user with a re-stake in between. Severity:
local **QA / owner footgun** — a competent operator would be surprised that re-running
`migrateOut` postpones an existing user's escape hatch by up to `migrationTimeout`.
Pre-existing (not introduced by story-023); confirm against the ledger before filing.

## 7. Trust assumptions

- `staker` is a deployed, **immutable** `INFTStakerMigratable` + `IStakerViews`. The
  constructor cross-check at `:167-170` prevents a wrong-reward-token deployment silently
  disabling the forwarding logic.
- `rewardToken` (phUSD) is a standard ERC20 — see LOCAL-303 for the branch where that fails.
- The owner is trusted to page `migrateIn` at a gas-safe slice size and to run
  `finalizeAndReset` on the staker before `migrateIn` (the staker requires `Active`,
  `NFTStakerDepletion.sol:750`).
- The `migrationTimeout` escape hatch is the user's protection against an owner who never runs
  `migrateIn`. It returns **stake only** — earned phUSD was already minted at `migrateOut`
  (`:361-362`). Verified against `NFTStakerDepletion.sol:733` (`_safePayTo(account, pending)`).
