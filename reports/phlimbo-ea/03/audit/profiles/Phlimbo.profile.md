# PhlimboEA — Local Properties / Interface Abstraction Profile

- **Contract**: `src/Phlimbo.sol`
- **Submodule**: `lib/phlimbo-ea`
- **HEAD**: `1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301`
- **Solidity**: `^0.8.19` (file). Note: OZ deps in the submodule use `^0.8.20`; effective floor for the deployed build is therefore `>=0.8.20`. Built-in checked arithmetic applies; no `unchecked` blocks and no assembly.
- **Profile scope**: Single-contract local analysis. Cross-contract interactions (phUSD minting authority, reward-token providers, mutable `IPausable` / Pauser orchestration) are surfaced as trust assumptions for downstream agents and NOT analyzed here.

---

## 1. Role / Purpose

`PhlimboEA` is the V1 of a "Linear Depletion" staking yield farm:

- Stakers deposit `phUSD` (a mintable Flax-family stablecoin, `IFlax`).
- The contract pays out two streams to stakers:
  1. **phUSD APY stream** — newly *minted* phUSD, sized as a configured APY of `totalStaked` (`phUSDPerSecond = totalStaked * desiredAPYBps / 10000 / 365 days`).
  2. **Stable (reward token) stream** — an *externally funded* stream of `rewardToken` (a generic `IERC20`, treated as a stablecoin) that depletes linearly. The intended depletion-window invariant is "given a fixed `rewardBalance`, distribute it over `depletionDuration` seconds at `rewardPerSecond = rewardBalance * PRECISION / depletionDuration`".
- Anyone may push reward funding in via `collectReward` (the contract is permissionless on the *deposit* side of rewards); the design comment names the "stable-yield-accumulator" contract as the expected funder.
- Accrual uses the classic SushiSwap MasterChef share/debt pattern: per-share accumulators (`accPhUSDPerShare`, `accStablePerShare`) scaled by `PRECISION = 1e18`, with per-user reward debts.

**Known V1 issue (per submodule CLAUDE.md, treat as in-scope-but-acknowledged):** `rewardPerSecond` is recomputed on every `stake`/`withdraw`/`claim` (indirectly via `_updatePool`), which re-anchors the depletion window on every user interaction. V2 (`PhlimboV2.sol`) deliberately removes this recompute. This profile records the property objectively; the econ-scanner / invariant-generator should weigh whether unique user-impactful exploits remain over and above the documented "rewards never fully deplete" behavior.

---

## 2. Inheritance Chain & Imports

```
PhlimboEA
  is Ownable                                  (OpenZeppelin, single-owner, renounceable)
  is Pausable                                 (OpenZeppelin, internal _pause / _unpause)
  is ReentrancyGuard                          (OpenZeppelin, transient/SLOT-based nonReentrant)
  is IPhlimbo                                 (local interface — events + getters)
  is IPausable                                (mutable Pauser interface — requires pause()/unpause()/pauser())
```

Imports of interest:

- `@openzeppelin/contracts/access/Ownable.sol` — constructor passes `msg.sender` as `initialOwner` (OZ v5 style). Owner can `renounceOwnership()` → would brick all admin paths permanently, including `emergencyTransfer` and `setPauser` (centralization-risk surface, not a finding).
- `@openzeppelin/contracts/utils/Pausable.sol` — only `_pause()` / `_unpause()` are called internally; `whenPaused` / `whenNotPaused` modifiers are used on `pauseWithdraw` / `stake`/`withdraw`/`claim` respectively.
- `@openzeppelin/contracts/utils/ReentrancyGuard.sol` — only `collectReward` is guarded with `nonReentrant`. **`stake`, `withdraw`, `claim`, `pauseWithdraw`, `emergencyTransfer` are NOT guarded.** They do perform external token calls (and `mint`), so this is a focus area for downstream interaction analysis (see Section 8).
- `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` — used everywhere a transfer occurs.
- `./IFlax.sol` — local interface; `phUSD.mint(user, amount)` is called in `_claimRewards`. The contract must hold an authorized minter role on the phUSD token; otherwise `_claimRewards` reverts and **all stake/withdraw/claim paths become unusable** (`pauseWithdraw` is the only exit; see Section 8).
- `./interfaces/IPhlimbo.sol` — defines public events (`EmergencyWithdrawal`, `Staked`, `Withdrawn`, `RewardsClaimed`) and the externally facing function shape.
- `lib/mutable/pauser/src/interfaces/IPausable.sol` — *mutable* sibling dep. Per submodule CLAUDE.md, only the interface is available; the real "Global Pauser" implementation is out-of-scope and treated as a trust boundary. The compliance contract here is `pauser` set via `setPauser(address)`; setting `pauser = address(0)` is explicitly allowed by the natspec and disables pausing entirely.

---

## 3. State Variables

| Name | Type | Semantic | Constraints / Domain | Mutators |
|---|---|---|---|---|
| `phUSD` | `IFlax` (public) | Staking + mintable reward asset | Set once in constructor, non-zero | constructor only (immutable in practice, but not declared `immutable`) |
| `rewardToken` | `IERC20` (public) | External stable reward asset | Set once in constructor, non-zero | constructor only |
| `pauser` | `address` (public, `override`) | Authorized pause/unpause caller | Any address incl. `address(0)` (disables pausing) | `setPauser` (onlyOwner) |
| `desiredAPYBps` | `uint256` (public) | Target APY in bps for phUSD emission | Unbounded — no max cap | committed via `setDesiredAPY` two-step |
| `phUSDPerSecond` | `uint256` (public) | Current phUSD mint rate per second | `(totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR` | `_updatePhUSDEmissionRate` (called from stake / withdraw / setDesiredAPY commit) |
| `pendingAPYBps` | `uint256` (public) | Proposed APY pending confirmation | Unbounded | `setDesiredAPY` (preview branch) |
| `pendingAPYBlockNumber` | `uint256` (public) | Block of preview proposal | `<= block.number` | `setDesiredAPY` (preview branch) |
| `apySetInProgress` | `bool` (public) | Whether a preview is open | true between preview and commit | `setDesiredAPY` |
| `rewardBalance` | `uint256` (public) | Undistributed reward-token balance accounted for in the depletion model | `<= rewardToken.balanceOf(this)` (under standard ERC20 assumptions); decremented in `_updatePool` | `collectReward` (+), `_updatePool` (−), `emergencyTransfer` does NOT zero it (see §7 invariants) |
| `depletionDuration` | `uint256` (public) | Target window over which `rewardBalance` is paid out | `> 0` (enforced in constructor and setter); no upper bound | constructor, `setDepletionDuration` |
| `rewardPerSecond` | `uint256` (public) | Scaled rate `rewardBalance * PRECISION / depletionDuration` | Recomputed after every `_updatePool`, `collectReward`, `setDepletionDuration` | `_updatePool`, `collectReward`, `setDepletionDuration` |
| `lastRewardTime` | `uint256` (public) | Timestamp of last `_updatePool` | Monotonically non-decreasing in `block.timestamp` | constructor, `_updatePool` |
| `accPhUSDPerShare` | `uint256` (public) | Cumulative phUSD reward per share (×`PRECISION`) | Monotonically non-decreasing | `_updatePool` |
| `accStablePerShare` | `uint256` (public) | Cumulative stable reward per share (×`PRECISION`) | Monotonically non-decreasing | `_updatePool` |
| `totalStaked` | `uint256` (public) | Sum of `userInfo[*].amount` | Equals Σ `userInfo[u].amount` if standard ERC20 (no fee-on-transfer); `<= phUSD.balanceOf(this)` modulo direct donations | `stake` (+), `withdraw` (−), `pauseWithdraw` (−) |
| `PRECISION` | `uint256 constant` | Scaling factor | `1e18` | — |
| `SECONDS_PER_YEAR` | `uint256 constant` | `365 days` = `31_536_000` | — | — |
| `MINIMUM_STAKE` | `uint256 constant` | Dust floor | `1e15` = `0.001 phUSD` (assuming 18-dec phUSD) | — |
| `userInfo[address]` | `mapping → UserInfo` | Per-user stake + reward debts | `amount == 0` for unused addresses; `amount >= MINIMUM_STAKE` after `stake`; `phUSDDebt`/`stableDebt` rebased to `amount * accX / PRECISION` after every mutation | `stake`, `withdraw`, `claim`, `pauseWithdraw` |

Notes on constraints:
- `desiredAPYBps` has **no upper bound** — `1_000_000` (= 10000%) is permitted; only the two-step gate slows it down. The phUSD-mint side is therefore bounded only by `totalStaked`, but it is unbounded in nominal terms.
- `MINIMUM_STAKE = 1e15` only protects the *first stake* path and the `withdraw` dust-path; it does NOT prevent first-depositor share inflation in a meaningful sense for this design (share-debt model, not LP-share model), so the comment "to prevent first depositor attack" is misleading. The first-depositor attack does not apply to MasterChef-style debt accounting; flag for code-scanner narrative review only.
- No `immutable` qualifiers on `phUSD` / `rewardToken` — small gas/clarity hit but no security impact.

---

## 4. External / Public Functions

Format below: `signature` — access control, state effects, external calls, return value, key local invariants.

### 4.1 Admin

**`setDesiredAPY(uint256 bps)`** — `onlyOwner`
- Two-step commit gate keyed on `(apySetInProgress, pendingAPYBlockNumber, pendingAPYBps)` with a 100-block window.
- Preview branch: only stores `pendingAPYBps`, `pendingAPYBlockNumber = block.number`, sets `apySetInProgress = true`, emits `IntendedSetAPY`. No accrual.
- Commit branch: calls `_updatePool()`, sets `desiredAPYBps = bps`, calls `_updatePhUSDEmissionRate()`, emits `DesiredAPYUpdated`, clears `apySetInProgress`. **Note:** `pendingAPYBps` and `pendingAPYBlockNumber` are NOT zeroed on commit; subsequent preview-trigger logic relies on `apySetInProgress` only, so stale `pendingAPYBps == bps` after commit will be ignored because `apySetInProgress == false`.
- Edge case: when `apySetInProgress == false` and the owner calls with the *same value* twice quickly, the second call still goes through the preview branch because `apySetInProgress` is checked first. Two distinct admin transactions are always required regardless. Confirm with code-scanner.
- No external calls (other than internal `_updatePool` which is callless, and `_updatePhUSDEmissionRate` which is pure arithmetic).

**`setDepletionDuration(uint256 _duration)`** — `onlyOwner`
- Requires `_duration > 0`.
- Calls `_updatePool()` first to accrue under the OLD rate, then sets `depletionDuration`, then recomputes `rewardPerSecond = rewardBalance * PRECISION / depletionDuration`.
- Side-effect: shortening `depletionDuration` raises `rewardPerSecond`; lengthening lowers it. Owner can effectively front-run a deposit window by lengthening, or accelerate a payout by shortening.

**`setPauser(address _pauser)`** — `onlyOwner`
- Single-write; zero-address explicitly allowed (disables pause flow).
- No event emitted (gap — flag).

**`emergencyTransfer(address recipient)`** — `onlyOwner`
- Sweeps `phUSD.balanceOf(this)` and `rewardToken.balanceOf(this)` to `recipient`, then `_pause()`.
- Does NOT update `totalStaked`, `rewardBalance`, `accPhUSDPerShare`, `accStablePerShare`, or `userInfo[*]`. After this call:
  - All accounting invariants between `totalStaked` and `phUSD.balanceOf(this)` are violated.
  - `pauseWithdraw` will revert at the SafeERC20 layer because the contract no longer holds phUSD.
  - The only exit becomes `unpause` → off-chain remediation; users have no on-chain claim.
- Centralization risk acknowledged; treat as documented owner power.
- No `nonReentrant` and no `whenNotPaused` — owner can call it from any state; reentrancy is moot because `onlyOwner` is the trust gate.

**`pause()` / `unpause()`** — `require(msg.sender == pauser)`
- Public, `override`. Reverts if `pauser == address(0)` (since `msg.sender` cannot be zero), so a zero `pauser` disables both pause and unpause.
- These satisfy the `IPausable` interface so the Global Pauser sibling can register this contract.

### 4.2 Reward funding

**`collectReward(uint256 amount)`** — `nonReentrant`, no access control (permissionless funding)
- Requires `amount > 0`.
- Order:
  1. `_updatePool()` — accrues under the OLD rate first (correct ordering).
  2. `rewardToken.safeTransferFrom(msg.sender, this, amount)` — pulls funds.
  3. `rewardBalance += amount`.
  4. `rewardPerSecond = rewardBalance * PRECISION / depletionDuration` — re-anchors the depletion window.
- Reentrancy point: the `safeTransferFrom` call. If `rewardToken` has an ERC777-style hook or callback, the transient state between steps 2 and 3 is "balance received but `rewardBalance` not yet incremented and `rewardPerSecond` not yet updated"; combined with `nonReentrant`, direct re-entry into `PhlimboEA` is blocked. Cross-function reentrancy into unguarded `stake/withdraw/claim` IS still possible from within the token hook (downstream concern).
- Fee-on-transfer / rebasing tokens: `rewardBalance` accounts the *requested* amount, not the *received* amount → `rewardBalance` would exceed the real balance, causing eventual `safeTransfer` failures in `_claimRewards`. Trust assumption: `rewardToken` is a standard, non-fee-on-transfer, non-rebasing stablecoin.

### 4.3 Core staking

**`stake(uint256 amount, address recipient)`** — `whenNotPaused`, no reentrancy guard
- `amount >= MINIMUM_STAKE`. `recipient == address(0)` → `recipient = msg.sender`. Caller (`msg.sender`) always pays the phUSD.
- Order: `_updatePool()` → (if pre-existing position) `_claimRewards(recipient)` → `safeTransferFrom(msg.sender, this, amount)` → update `user.amount`, `user.phUSDDebt`, `user.stableDebt` → `totalStaked += amount` → `_updatePhUSDEmissionRate()`.
- Behavior to note:
  - **`_claimRewards` runs BEFORE the inbound transfer**, so any reentrancy risk from `phUSD.mint` (inside `_claimRewards`) or `rewardToken.safeTransfer` happens with `user.amount` at its old value — re-entering `stake` for the same recipient would (a) reread the old `user.amount > 0` branch, (b) call `_claimRewards` again, which would re-mint/re-transfer **the same pending rewards** because `phUSDDebt`/`stableDebt` are not yet rebased. This is a concrete cross-function reentrancy lever **iff** `phUSD.mint` or `rewardToken.transfer` can call back into this contract. (phUSD is in-scope and presumed non-callback; `rewardToken` is generic ERC20 by assumption — downstream concern.) Flag as suspicious surface §8.
  - `stake` does NOT enforce `recipient != address(0)` after the defaulting branch (it remaps to `msg.sender`), so the only way to stake to address(0) is to pass a non-zero `recipient` that happens to be address(0) — impossible. OK.
  - Allows **staking on behalf of any recipient.** Anyone can grief a victim by topping them up — minor griefing surface (forces reward-debt rebase) but generally benign because rewards are still earned for the recipient.
  - Does not enforce a max stake or rate-limit; emission rate `phUSDPerSecond = totalStaked * APY / ...` scales linearly so phUSD inflation scales with TVL. No internal protocol-side cap.
- External calls: `_updatePool` (none), `_claimRewards` → `phUSD.mint`, `rewardToken.safeTransfer`; `phUSD.safeTransferFrom`. **Untrusted-callback surface = `phUSD.mint` and both transfers.**

**`withdraw(uint256 amount)`** — `whenNotPaused`, no reentrancy guard
- `user.amount >= amount`.
- Order: `_updatePool()` → `_claimRewards(msg.sender)` (uses OLD `user.amount`) → compute `remaining = user.amount - amount` → dust-prevent (if `0 < remaining < MINIMUM_STAKE`, force full withdrawal of `user.amount`) → update `user.amount`, debts → `totalStaked -= actualWithdrawAmount` → `phUSD.safeTransfer(msg.sender, actualWithdrawAmount)` → `_updatePhUSDEmissionRate()`.
- Same CEI concern as `stake`: external interactions (`_claimRewards` mint+transfer) happen BEFORE `user.amount`/debt update. Re-entry into `withdraw` from a token hook would compute `remaining = OLD_amount - amount` again. Flag.
- The final `phUSD.safeTransfer` happens AFTER state updates, so reentrancy on that specific transfer is safe locally; but if `phUSD` has callbacks, cross-function reentrancy into `claim` / `stake` / `pauseWithdraw` is still possible.
- Dust handling: forcing a full withdrawal silently when `remaining < MINIMUM_STAKE` — emitted `Withdrawn` event correctly uses `actualWithdrawAmount`, but caller's transaction will withdraw more than they requested. Downstream UX concern, not a security issue per se.

**`claim()`** — `whenNotPaused`, no reentrancy guard
- Order: `_updatePool()` → `_claimRewards(msg.sender)` → rebase `user.phUSDDebt`, `user.stableDebt`.
- Same CEI issue as `stake`/`withdraw`: `_claimRewards` mints phUSD and transfers reward tokens **before** rebasing debts. A callback during `phUSD.mint` or `rewardToken.transfer` re-entering `claim` would re-read OLD debts and double-claim. Concrete reentrancy lever conditional on token-callback semantics. **High-priority surface for code-scanner / invariant-generator.**

**`pauseWithdraw(uint256 amount)`** — `whenPaused`, no reentrancy guard
- Lets users escape with principal during a pause. Does NOT update pool, does NOT claim rewards.
- Order: validate `user.amount >= amount > 0` → `user.amount -= amount` → `totalStaked -= amount` → `phUSD.safeTransfer(msg.sender, amount)`. **Correct CEI ordering** (state update before external call). Locally safe.
- Implication: pending rewards (both phUSD and stable) are forfeited proportional to the amount withdrawn because `user.phUSDDebt` and `user.stableDebt` are not rebased; if the user later un-pauses + claims, the debt is stale (still computed on old `user.amount`), so the claim will *over*-credit rewards for the remaining stake compared to what they should be. Concretely:
  - Before pause-withdraw: `pending = user.amount * acc / PREC - user.debt`.
  - After pause-withdraw of `x`: `user.amount' = user.amount - x`, `user.debt` unchanged.
  - New pending = `(user.amount - x) * acc / PREC - user.debt`, which is `pending - x * acc / PREC` — *can underflow* (revert) if `x * acc / PREC > pending`, i.e., if the user's old debt was below the floor implied by their remaining amount.
  - Worked case: user has `amount = 100`, `debt = 0`, `acc = 1e18`. `pending = 100`. Pause-withdraw `50` → `amount = 50`, `debt = 0`. New pending = `50 - 0 = 50` — fine.
  - Worked case 2: user has `amount = 100`, `debt = 100e18` (set at a later checkpoint), `acc = 2e18`. `pending = 200 - 100 = 100`. Pause-withdraw `50` → `amount = 50`, `debt = 100e18`. New pending = `100 - 100 = 0` (could also underflow if `acc` had decreased — but `acc` is monotonic, so OK).
  - **Underflow can happen** in `_claimRewards` if `user.amount * accPhUSDPerShare / PRECISION < user.phUSDDebt`. After `pauseWithdraw`, `user.phUSDDebt` was anchored to `OLD_amount * accX_at_some_earlier_time / PRECISION`. If `accX` has grown but `user.amount` shrunk by enough, the product can be less than the debt. This is a concrete arithmetic-revert path — `_claimRewards` would revert on Solidity 0.8 checked subtraction, bricking `stake/withdraw/claim` for that user post-unpause. **Flag for invariant-generator.** Mitigation that exists: `pauseWithdraw` only runs while paused, so the user must also wait for unpause and then call `claim` to trigger it; UX is "rewards lost", not silent fund loss, but the user becomes unable to call core functions on their position. Workaround for the user: `withdraw(remaining)` would also revert from the same path; `pauseWithdraw(remaining)` would let them recover the principal during a future pause.
- No event for the implicit reward forfeiture beyond the `EmergencyWithdrawal` event.

### 4.4 Views

**`pendingPhUSD(address user)`** — view
- Lazily simulates `_updatePool()`'s phUSD branch only (does NOT simulate the depletion side-effects on `rewardBalance`). Returns `(user.amount * _accPhUSDPerShare) / PRECISION - user.phUSDDebt`.
- **Reverts (underflow) for the same edge case as `_claimRewards`** described above (post-`pauseWithdraw` debt staleness). Front-ends should treat this as "claim would revert".

**`pendingStable(address user)`** — view
- Simulates the depletion-capped distribution: `toDistribute = min(rewardPerSecond * timeElapsed / PRECISION, rewardBalance)`. Same potential underflow path.

**`getPoolInfo()`** — view; returns 5 fields. No reverts.

**`getPendingAPYInfo()`** — view; returns 3 fields. No reverts.

Plus auto-generated public getters: `phUSD`, `rewardToken`, `pauser`, `desiredAPYBps`, `phUSDPerSecond`, `pendingAPYBps`, `pendingAPYBlockNumber`, `apySetInProgress`, `rewardBalance`, `depletionDuration`, `rewardPerSecond`, `lastRewardTime`, `accPhUSDPerShare`, `accStablePerShare`, `totalStaked`, `PRECISION`, `SECONDS_PER_YEAR`, `MINIMUM_STAKE`, `userInfo(address)`.

Inherited externals: `Ownable.owner()`, `transferOwnership(address)`, `renounceOwnership()`; `Pausable.paused()`.

---

## 5. Internal Functions

**`_updatePool()`**
- Early-out if `block.timestamp <= lastRewardTime` (idempotent within the same block).
- If `totalStaked == 0`: advances `lastRewardTime` only; rewards do NOT accrue. *Side-effect of importance:* during periods of zero stake, the depletion clock does NOT consume `rewardBalance`. Combined with `collectReward`'s re-anchoring of `rewardPerSecond`, this is benign locally — rewards wait for stakers. But also: a single staker who waits for a long elapsed period gets the entire prorated `rewardPerSecond * timeElapsed / PRECISION` capped at `rewardBalance`, which is the design intent for first-to-stake.
- For the stable side: `toDistribute = min(rewardPerSecond * timeElapsed / PRECISION, rewardBalance)`; `accStablePerShare += toDistribute * PRECISION / totalStaked`; `rewardBalance -= toDistribute`; recomputes `rewardPerSecond`.
- **V1 window-reset bug (documented):** the recompute `rewardPerSecond = rewardBalance * PRECISION / depletionDuration` after every accrual means the depletion window is restarted every block-with-stakers. Under continuous interaction the depletion is *exponential with a tail*, not linear — `rewardBalance` is asymptotically depleted but never reaches zero from this branch alone. Concretely, in `N` updates with time deltas `Δt` and `K = Δt * PRECISION / (depletionDuration * PRECISION) = Δt / depletionDuration` per step: `rewardBalance_{n+1} = rewardBalance_n * (1 - Δt/depletionDuration)` (modulo precision rounding). This is the explicit, known V1 finding. The V2 fix removes the recompute from `_updatePool`.
- For the phUSD side: `accPhUSDPerShare += timeElapsed * phUSDPerSecond * PRECISION / totalStaked`. No cap (mint is unconstrained on this contract's side). Bound only by `desiredAPYBps` × `totalStaked`. **Centralization / governance concern:** owner-controlled `desiredAPYBps` directly converts to mint pressure on phUSD.

**`_claimRewards(address user)`**
- Skips if `userDetails.amount == 0`.
- Computes `pendingPhUSDAmount = user.amount * accPhUSDPerShare / PRECISION - user.phUSDDebt`. **Can underflow** (Solidity 0.8 reverts) under the `pauseWithdraw`-staleness scenario described above.
- If `pendingPhUSDAmount > 0`: `phUSD.mint(user, pendingPhUSDAmount)`. **External call to phUSD** — trust boundary; if mint reverts (e.g., contract is not authorized minter, phUSD revoked all mint privileges via `revokeAllMintPrivileges`, or paused), the entire stake/withdraw/claim path is bricked. `pauseWithdraw` becomes the only exit.
- Computes `pendingRewardAmount = user.amount * accStablePerShare / PRECISION - user.stableDebt`. Same underflow path.
- If `pendingRewardAmount > 0`: `rewardToken.safeTransfer(user, pendingRewardAmount)`. Standard ERC20 assumption — if `rewardToken` reverts (e.g., USDC blacklist of `user`), the user cannot stake/withdraw/claim either (DoS). Pause-withdraw still works.
- Emits `RewardsClaimed` only if at least one leg was nonzero. **Does NOT rebase `user.phUSDDebt` / `user.stableDebt`** — callers do that themselves after the call. The `claim()` external function does it explicitly; `stake` and `withdraw` rebase as part of their own bodies. **No path leaves debts un-rebased** after `_claimRewards` *from within the same external call*, but **mid-call reentrancy** would see un-rebased debts (see Section 8).

**`_updatePhUSDEmissionRate()`**
- If `totalStaked == 0`: `phUSDPerSecond = 0`. Else: `phUSDPerSecond = totalStaked * desiredAPYBps / 10000 / SECONDS_PER_YEAR`.
- **Division-before-multiplication order is benign** here because the multiplication is the leftmost op (`totalStaked * desiredAPYBps`) before the `/10000` and `/SECONDS_PER_YEAR`. However, *precision loss* on small `totalStaked` is large: with `totalStaked = 1e15` (one minimum-stake), `desiredAPYBps = 10_000` (100%): `phUSDPerSecond = 1e15 * 10000 / 10000 / 31_536_000 = ~31_709_791` wei/sec ≈ 1 wei/sec at 5% APY for the MINIMUM_STAKE. So `phUSDPerSecond` truncates to 0 for small stakes / small APYs. Not exploitable.
- **No max cap** on `desiredAPYBps`. Owner can set arbitrarily high. Combined with the two-step gate (100-block window ≈ 20 minutes on Ethereum mainnet) this is the only friction.

---

## 6. Trusted External Callers / Oracles / Token Addresses

- **`phUSD` (`IFlax`)** — both staking asset and a *mintable* reward asset. The contract calls `phUSD.mint(user, amount)` to pay phUSD rewards. **Implicit assumption: this contract is granted an authorized minter role on `phUSD` at deployment / governance time.** If not, `_claimRewards` (and therefore `stake` / `withdraw` / `claim`) revert. `phUSD.revokeAllMintPrivileges()` (per `IFlax`) is a documented kill-switch — if invoked, the contract bricks but `pauseWithdraw` (during pause) still recovers principal.
- **`rewardToken` (`IERC20`)** — opaque external stablecoin. Trust assumptions:
  - Standard ERC20 — no fee-on-transfer, no rebase, no ERC777-style callbacks.
  - `balanceOf` reflects real balance (no proxy upgrade games during a transfer).
  - `transfer`/`transferFrom` revert-on-failure or are safely wrapped by `SafeERC20`.
  - Blacklisting (USDC-style) would DoS specific stakers' claim/withdraw flows but cannot freeze others.
- **`pauser`** — sibling Global Pauser (mutable dep). Out-of-scope implementation; treated as a trusted operator able to pause this contract at any time, freezing `stake`/`withdraw`/`claim` but enabling `pauseWithdraw`.
- **`owner`** — single OZ Ownable owner. Full powers: `setDesiredAPY` (two-step gated), `setDepletionDuration`, `setPauser`, `emergencyTransfer`, `renounceOwnership`, `transferOwnership`. No timelock, no multisig enforcement on-chain. Centralization risk — flag as documented.
- **`collectReward` caller** — *anyone*. Permissionless reward funding. Acceptable design but worth noting: a third party can re-anchor the depletion window by injecting `amount = 0` ... actually `amount > 0` is enforced. Minimum `amount = 1` wei is still allowed and would re-anchor `rewardPerSecond` on every call. Minor griefing surface; impact is "slows depletion further" — *amplifies* the V1 window-reset bug. Worth a code-scanner note.
- **No oracles, no Chainlink, no time-feeds beyond `block.timestamp`.** All economic logic is internal arithmetic over staker balances and `rewardBalance`.

---

## 7. Local Invariants Verified by Reading the Code

Strong invariants (`verified`):

- **I1 (totalStaked balance bound):** `totalStaked <= phUSD.balanceOf(address(this))` at the end of every external call, *assuming standard ERC20 semantics for phUSD and ignoring direct donations / owner sweep*. **Violated after `emergencyTransfer`** by design.
- **I2 (sum-of-balances):** `totalStaked == Σ userInfo[u].amount` over all `u`. Holds by construction; `stake`/`withdraw`/`pauseWithdraw` all increment/decrement both sides by the same amount.
- **I3 (monotonic accumulators):** `accPhUSDPerShare` and `accStablePerShare` only ever increase (or stay equal). Holds because `_updatePool` only adds to them with non-negative terms.
- **I4 (monotonic `lastRewardTime`):** non-decreasing. Each `_updatePool` either returns early or sets `lastRewardTime = block.timestamp`. Holds.
- **I5 (depletion cap):** in any single `_updatePool` call, `rewardBalance` decreases by `min(rewardPerSecond * timeElapsed / PRECISION, rewardBalance)` — never goes negative.
- **I6 (apy emission rate identity):** after any `_updatePhUSDEmissionRate` call, `phUSDPerSecond == totalStaked * desiredAPYBps / 10000 / SECONDS_PER_YEAR` (integer-divided). Holds; but **is NOT maintained between calls** because `desiredAPYBps` can be committed via `setDesiredAPY` and `_updatePhUSDEmissionRate` IS called there, and `totalStaked` changes only via stake/withdraw which DO call `_updatePhUSDEmissionRate`. **All mutation paths re-establish the identity** — verified.
- **I7 (minimum stake):** every successful `stake` ends with `user.amount >= MINIMUM_STAKE` (because either the increment satisfies `amount >= MINIMUM_STAKE` and a pre-existing position is already `>= MINIMUM_STAKE`, or it's a new position with `amount >= MINIMUM_STAKE`). Withdraw dust-handler keeps post-withdraw `user.amount` either `0` or `>= MINIMUM_STAKE`. `pauseWithdraw` can leave `user.amount` in `(0, MINIMUM_STAKE)` because it has no dust handler. Document carefully — the invariant is "amount is `0` or `>= MINIMUM_STAKE` outside paused contexts", and is violated in paused contexts (but cannot harm new accounting because all functions that compute new debt rely on multiplication and are dust-tolerant).
- **I8 (`_updatePool` idempotency within block):** consecutive calls in the same block are no-ops. Holds via `block.timestamp <= lastRewardTime`.
- **I9 (two-step APY commit gate):** `desiredAPYBps` can only change via the commit branch of `setDesiredAPY`, which requires (a) `apySetInProgress == true`, (b) `block.number <= pendingAPYBlockNumber + 100`, (c) `bps == pendingAPYBps`. Verified by the boolean structure of `isPreview`.

Likely / unverified-but-asserted (`likely`):

- **I10 (no double-spend of reward debt within a single TX):** holds *under no-callback assumption* on `phUSD.mint` and `rewardToken.safeTransfer`. **Violated under callback** (cross-function reentrancy lever, Section 8).
- **I11 (`_claimRewards` underflow safety):** `user.amount * accX / PRECISION >= user.X_debt` for every reachable state. **NOT verified.** Counter-pattern: post-`pauseWithdraw` reduces `user.amount` without rebasing `user.X_debt`. If `user.X_debt` was set at an earlier checkpoint where `acc` was lower, after `pauseWithdraw` we can have `user.amount * acc_now / PRECISION < user.X_debt`. This is a concrete `revert`-able state. **Flag for invariant-generator: write a property test that drives `pauseWithdraw` → `unpause` → `claim` and asserts no revert OR documents that revert is acceptable / `pauseWithdraw(remaining)` is the only recovery.**
- **I12 (V1 linear-depletion property):** the claimed "`rewardBalance` is fully distributed over `depletionDuration` seconds" property is **violated** by the documented V1 recompute bug; depletion is asymptotic. Treat as documented behaviour, NOT as a fresh finding.

Violated (`violated`) — to surface as local findings (subject to severity-classifier and dedup-with-known):

- **V1** Re-anchoring of `rewardPerSecond` in `_updatePool` (lines 416, also `setDepletionDuration` and `collectReward`) breaks the linear-depletion claim. **DOCUMENTED V1 BUG — flag for dedup with ledger.**
- **V2** `_claimRewards` underflow under post-`pauseWithdraw` debt-staleness (lines 440, 446; reachable from `claim`, `stake`, `withdraw`, and views `pendingPhUSD`/`pendingStable`). Worst-case impact: user becomes unable to interact with their position except via a future `pauseWithdraw` (i.e., they can still recover principal during a future pause but cannot claim rewards). Flag for code-scanner to confirm reachability with a concrete sequence.
- **V3** `setPauser` emits no event (line 206). Minor — QA.
- **V4** `setDesiredAPY` has no upper bound (line 151). Owner can set arbitrarily high APY; the only friction is the 100-block two-step. Combined with phUSD mint power → arbitrary phUSD inflation. Centralization concern.
- **V5** `emergencyTransfer` does not zero `rewardBalance`, `totalStaked`, or per-user state (lines 214–227). After invocation, accounting state is internally inconsistent. Likely intended as a "abandon ship" path followed by off-chain remediation; flag for QA / docs.

---

## 8. Suspicious Surfaces for Downstream Scanners

Prioritized list for `code-scanner`, `econ-scanner`, and `invariant-generator`.

### 8.1 Reentrancy (high priority)
- **Cross-function reentrancy lever in `stake` / `withdraw` / `claim`.** Pattern: `_updatePool()` → `_claimRewards(user)` → external `phUSD.mint(user, pending)` and/or `rewardToken.safeTransfer(user, pending)` → **return** → then state rebase. Reentry into any of `stake` / `withdraw` / `claim` from the token callback would re-read OLD `user.phUSDDebt` / `user.stableDebt` and re-mint / re-transfer the same pending amount. **Mitigation present:** `nonReentrant` on `collectReward` only — none of the staker-facing functions are guarded. **Mitigation absent or trust-deferred:** phUSD is assumed non-callback (in-scope, presumed safe); `rewardToken` is assumed standard ERC20 (trust assumption). **Action:** code-scanner should construct the sequence given a non-standard `rewardToken` and verify whether the trust assumption is realistic (USDC/USDT/DAI all OK; ERC777 / hooked tokens not OK).
- **Same lever during `withdraw`'s final `phUSD.safeTransfer`** — state is fully updated by then, so re-entry would see a consistent post-withdraw state; lower risk.
- **`pauseWithdraw` is CEI-clean** — locally safe.

### 8.2 Reward-debt staleness after `pauseWithdraw`
- See V2 in Section 7. Invariant-generator should target: "after any sequence of legal external calls, `claim()` and `withdraw(0..user.amount)` do NOT revert except via explicit `require`/`Pause`-state guards". Expected: this property FAILS for sequences ending in `pauseWithdraw`.

### 8.3 Permissionless funding griefing
- `collectReward(1)` repeatedly amplifies the V1 window-reset bug (each call recomputes `rewardPerSecond` at a slightly slower rate due to negligible `amount` but very-frequent re-anchoring). Net effect: extends the de-facto depletion tail further than V1's already-extended tail. **Likely low impact** but should be quantified by econ-scanner.

### 8.4 Owner-controlled inflation
- `desiredAPYBps` unbounded. `phUSDPerSecond = totalStaked * desiredAPYBps / 10000 / SECONDS_PER_YEAR`. With `desiredAPYBps = 10_000_000_000`, the per-second mint scales 1e6× over a 100% APY. **Centralization risk** acknowledged; the two-step + 100-block gate is the only friction. Econ-scanner should treat owner as trusted but document.

### 8.5 Token-asset overlap (phUSD as both stake and reward)
- `_claimRewards` `mint`s phUSD to the user. Users may then re-`stake` the minted phUSD — compounding pressure. The accounting handles this correctly because `mint` flows to `user`, not to `address(this)`, so `totalStaked` is unchanged unless the user explicitly re-stakes. No invariant violation; flag for econ-scanner.

### 8.6 `emergencyTransfer` accounting drift
- See V5 in Section 7. The contract becomes an inconsistent "frozen shell" — `userInfo[*].amount > 0` but `phUSD.balanceOf(this) == 0`. Even after `unpause`, no user can `withdraw` (SafeERC20 revert) and `pauseWithdraw` is gated by `whenPaused`. **The only exit is `pause()` → `pauseWithdraw` (but it will revert because the contract holds no phUSD).** Effective outcome: stakers lose principal unless owner refills off-chain. Document the centralization implication.

### 8.7 `setDepletionDuration` interaction with depletion clock
- Owner can call `setDepletionDuration(1)` to set `rewardPerSecond = rewardBalance * PRECISION`. The very next `_updatePool` distributes the entire `rewardBalance` in one go (capped, of course, by `rewardBalance` itself). Combined with `nonReentrant` absent on stake/withdraw/claim, this is a "pull the rug forward" lever for the owner. Documented centralization power — flag for econ-scanner severity assessment.

### 8.8 Two-step APY edge cases
- After commit, `apySetInProgress` clears but `pendingAPYBps` / `pendingAPYBlockNumber` remain set. They are read again only when `apySetInProgress` is true, so they are inert. OK.
- If owner calls `setDesiredAPY(X)` (preview), then `setDesiredAPY(Y)` (preview-reset because `Y != X`), the original preview is silently dropped. Acceptable but worth a UX note.
- The 100-block window (~20 min on mainnet) is short enough that re-org-driven block-number drift is essentially irrelevant; flag only if deployed to L2 with different block cadence.

### 8.9 Precision / rounding
- All accumulator additions use `* PRECISION` scaling correctly. Division-before-multiplication patterns: none harmful identified. `(toDistribute * PRECISION) / totalStaked` — multiplication first.
- Rounding direction: floor (Solidity `/` is integer division). Rounding accrues to the *protocol* (less is distributed than the rate suggests). Standard MasterChef behavior. OK.
- **Precision lockout on tiny stakes**: `phUSDPerSecond` truncates to 0 for `totalStaked * desiredAPYBps < 10000 * SECONDS_PER_YEAR = 3.15e11`. With 18-dec phUSD and `MINIMUM_STAKE = 1e15`, a single staker at 100% APY yields `phUSDPerSecond ≈ 3.17e6` (≈ 0.0001 phUSD/year of resolution) — non-zero. At 1 bps APY, `phUSDPerSecond = 1e15 * 1 / 10000 / 31_536_000 = 0` → no phUSD emission. Not exploitable.

### 8.10 Front-running / MEV
- `setDesiredAPY` commit is publicly mempool-visible. A staker can monitor the mempool, stake just before the commit to capture the new (higher) phUSDPerSecond, then withdraw. Standard MEV; document but not a finding.
- `collectReward` can be sandwiched: an MEV bot could stake immediately before, claim immediately after. Standard MasterChef behavior; document but acceptable.

### 8.11 Upgrade hooks / proxy
- **No proxy, no upgradeability, no initializer.** Constructor-set immutable-by-convention state. No storage-layout / collision concerns. OK.

### 8.12 Assembly / unchecked
- None present. Checked arithmetic everywhere. OK.

### 8.13 Unbounded loops
- **None.** All state mutations are O(1) per call. OK.

---

## 9. Verified Properties (Summary Table)

| Property | Status | Notes |
|---|---|---|
| Solidity 0.8+ checked arithmetic | verified | No `unchecked`, no assembly |
| No unbounded loops | verified | All paths O(1) |
| Initializer protection | n/a | Not a proxy; constructor only |
| Reentrancy guards | partially-verified | Only `collectReward` guarded; `stake`/`withdraw`/`claim`/`pauseWithdraw`/`emergencyTransfer` unguarded — see §8.1 |
| Access control on admin functions | verified | `onlyOwner` on all setters and emergency sweep; `require(msg.sender == pauser)` on pause/unpause |
| Pause integration | verified | `whenNotPaused` on stake/withdraw/claim; `whenPaused` on pauseWithdraw; `pause()`/`unpause()` satisfy IPausable |
| Constructor input validation | verified | Non-zero addresses, non-zero duration |
| Two-step APY commit | verified | 100-block window, value match, `apySetInProgress` flag |
| SafeERC20 usage | verified | Used on all transfers, both directions |
| Storage layout collision | n/a | No proxy |
| `totalStaked` ↔ phUSD balance identity | likely-violated | `emergencyTransfer` breaks it by design |
| `_claimRewards` cannot underflow | violated (likely) | Reachable via `pauseWithdraw` staleness — see V2 |
| Linear depletion property | violated | Documented V1 bug — `rewardPerSecond` re-anchored every `_updatePool` |

---

## 10. Trust Assumptions (Carry-Forward to Downstream)

1. **`phUSD` is a non-callback ERC20** (no ERC777 / no `_beforeTokenTransfer` external dispatch into arbitrary code) AND grants this contract a minter role that remains valid through the audit horizon.
2. **`rewardToken` is a non-fee-on-transfer, non-rebasing, non-callback ERC20** (USDC / DAI-class). Fee-on-transfer would over-account `rewardBalance` and DoS claims at the tail. Callbacks would unlock §8.1 reentrancy.
3. **`pauser` (when non-zero) is the trusted Global Pauser sibling** and may pause at any time; users can recover principal via `pauseWithdraw` but forfeit pending rewards.
4. **`owner` is trusted but centralization-risky**: can sweep all funds via `emergencyTransfer`, set arbitrary APY (gated only by two-step), and accelerate depletion via `setDepletionDuration(1)`. No on-chain timelock.
5. **`collectReward` is permissionless funding** by design.
6. **Block timestamp is monotonic and non-manipulable beyond standard miner drift** (~15s). No sub-second-precision invariants.
7. **The V1 "rewards never fully deplete" behavior is documented and intended** (per submodule CLAUDE.md); the V2 fix is out of scope for this profile.

---

## 11. Complexity / Surface Metrics

- LOC (file): 558.
- External / public functions on `PhlimboEA` itself: 14 (`setDesiredAPY`, `setDepletionDuration`, `unpause`, `setPauser`, `emergencyTransfer`, `pause`, `pauseWithdraw`, `collectReward`, `stake`, `withdraw`, `claim`, `pendingPhUSD`, `pendingStable`, `getPoolInfo`, `getPendingAPYInfo`).
- Inherited externals: `owner()`, `transferOwnership(address)`, `renounceOwnership()`, `paused()`.
- Internal functions: 3 (`_updatePool`, `_claimRewards`, `_updatePhUSDEmissionRate`).
- External calls per state-mutating path:
  - `stake`: up to `phUSD.mint` + `rewardToken.safeTransfer` (from `_claimRewards`) + `phUSD.safeTransferFrom` = 3.
  - `withdraw`: up to `phUSD.mint` + `rewardToken.safeTransfer` + `phUSD.safeTransfer` = 3.
  - `claim`: up to `phUSD.mint` + `rewardToken.safeTransfer` = 2.
  - `collectReward`: `rewardToken.safeTransferFrom` = 1 (guarded).
  - `pauseWithdraw`: `phUSD.safeTransfer` = 1.
  - `emergencyTransfer`: `phUSD.balanceOf` + `rewardToken.balanceOf` + up to 2 `safeTransfer` = up to 4.
- State variables: 14 (plus 3 constants and a struct mapping).
- Events: 7 (`EmergencyWithdrawal`, `Staked`, `Withdrawn`, `RewardsClaimed` from interface; `RewardCollected`, `RateUpdated`, `DepletionDurationUpdated`, `IntendedSetAPY`, `DesiredAPYUpdated` declared in the contract). `RateUpdated` is declared but never emitted — flag QA.
- Modifiers used: `onlyOwner` (inherited), `whenNotPaused`, `whenPaused`, `nonReentrant`.

---

## 12. Downstream Agent Routing Hints

- **code-scanner**: focus on §8.1 (cross-function reentrancy reachability under `phUSD.mint` callback semantics), §8.2 (concrete sequence to trigger `_claimRewards` underflow post-`pauseWithdraw`), §8.6 (`emergencyTransfer` accounting drift narrative), and the un-emitted `RateUpdated` event.
- **econ-scanner**: §8.3 (permissionless funding griefing amplifying V1 bug), §8.4 + §8.7 (owner-controlled inflation and depletion-window manipulation), §8.10 (MEV around APY commit and `collectReward`).
- **invariant-generator**: build properties around I1–I9 (verify), I10–I11 (expect failure / produce counterexample), and I12 (encode V1 documented bug as a property to confirm it's the only depletion deviation). Use Foundry; `pauseWithdraw → unpause → claim` is the highest-value invariant target.
- **deduplicator**: the V1 window-reset finding (V1 in §7) is documented as a known issue in the submodule CLAUDE.md — should reconcile with ledger and likely demote to `known`. Everything else in V2–V5 is fresh.
