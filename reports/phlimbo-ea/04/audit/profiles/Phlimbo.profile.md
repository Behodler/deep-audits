# Contract Profile — PhlimboEA

- **Contract:** `src/Phlimbo.sol` (`contract PhlimboEA`)
- **Absolute path:** `/home/justin/code/audits/lib/phlimbo-ea/src/Phlimbo.sol`
- **Profile timestamp:** 2026-06-07T01:46:55Z
- **Solidity version:** `^0.8.19` (checked arithmetic; no `unchecked`, no assembly)
- **OpenZeppelin version:** 5.5.0
- **Inheritance chain:** `Ownable`, `Pausable`, `ReentrancyGuard`, `IPhlimbo`, `IPausable`
- **Scope note:** Single-contract local analysis only. `phUSD` (IFlax), `rewardToken` (IERC20), and the global `pauser` are **mutable dependencies / trust boundaries** — interfaces only, implementations NOT analyzed. The yield-accumulator that funds `collectReward` is external and not in scope.
- **Known-issue context (from `lib/phlimbo-ea/CLAUDE.md`):** This is V1, deployed, and carries the documented "rate-recompute bug" (`rewardPerSecond` re-anchored on every interaction). PhlimboV2 deliberately removes it. LOCAL-001 below is that documented behavior, surfaced here for completeness (Law 1: recall over tidiness); sanitizer should reconcile it against the known-issues list.

---

## 1. Public / external function inventory

| Function | Visibility | Access control | State mutated | External calls |
|---|---|---|---|---|
| `setDesiredAPY(uint256 bps)` | external | `onlyOwner` | `pendingAPYBps`, `pendingAPYBlockNumber`, `apySetInProgress` (preview) / `desiredAPYBps`, `phUSDPerSecond`, pool accumulators (commit) | none |
| `setDepletionDuration(uint256)` | external | `onlyOwner` | pool accumulators, `depletionDuration`, `rewardPerSecond`, `rewardBalance` | none |
| `pause()` | public (override) | `msg.sender == pauser` | OZ `_paused` | none |
| `unpause()` | public (override) | `msg.sender == pauser` | OZ `_paused` | none |
| `setPauser(address)` | external | `onlyOwner` | `pauser` | none |
| `emergencyTransfer(address recipient)` | external | `onlyOwner` | OZ `_paused` | `phUSD.balanceOf`, `rewardToken.balanceOf`, `phUSD.safeTransfer`, `rewardToken.safeTransfer` |
| `pauseWithdraw(uint256 amount)` | external | `whenPaused`, per-caller | `userInfo[msg.sender].amount`, `totalStaked` | `phUSD.safeTransfer` |
| `collectReward(uint256 amount)` | external | **permissionless**, `nonReentrant` | pool accumulators, `rewardBalance`, `rewardPerSecond` | `rewardToken.safeTransferFrom` |
| `stake(uint256 amount, address recipient)` | external | `whenNotPaused`, permissionless | pool accumulators, `userInfo[recipient]`, `totalStaked`, `phUSDPerSecond` | `_claimRewards` (`phUSD.mint`, `rewardToken.safeTransfer`), `phUSD.safeTransferFrom` |
| `withdraw(uint256 amount)` | external | `whenNotPaused`, per-caller | pool accumulators, `userInfo[msg.sender]`, `totalStaked`, `phUSDPerSecond` | `_claimRewards`, `phUSD.safeTransfer` |
| `claim()` | external | `whenNotPaused`, per-caller | pool accumulators, `userInfo[msg.sender]` debts | `_claimRewards` |
| `pendingPhUSD(address)` | external view | none | — | none |
| `pendingStable(address)` | external view | none | — | none |
| `getPoolInfo()` | external view | none | — | none |
| `getPendingAPYInfo()` | external view | none | — | none |
| auto getters (`phUSD`, `rewardToken`, `pauser`, `userInfo`, accumulators, etc.) | public view | none | — | none |

Internal: `_updatePool()`, `_claimRewards(address)`, `_updatePhUSDEmissionRate()`.

**Access-control summary**
- `onlyOwner`: `setDesiredAPY`, `setDepletionDuration`, `setPauser`, `emergencyTransfer`.
- `pauser`-gated: `pause`, `unpause`.
- `whenNotPaused`: `stake`, `withdraw`, `claim`.
- `whenPaused`: `pauseWithdraw`.
- Permissionless: `collectReward` (anyone may fund rewards), `stake` (anyone may stake to a recipient; caller pays).

---

## 2. State variables and intended invariants

Token / role wiring: `phUSD` (IFlax, mint authority), `rewardToken` (IERC20 stable), `pauser`.

Reward config: `desiredAPYBps`, `phUSDPerSecond`, `depletionDuration`, `rewardPerSecond` (scaled ×PRECISION), `rewardBalance`.
APY two-step: `pendingAPYBps`, `pendingAPYBlockNumber`, `apySetInProgress`.
Pool accounting: `accPhUSDPerShare`, `accStablePerShare` (both ×PRECISION), `lastRewardTime`, `totalStaked`.
Per-user: `mapping(address => UserInfo{amount, phUSDDebt, stableDebt})`.
Constants: `PRECISION = 1e18`, `SECONDS_PER_YEAR = 365 days`, `MINIMUM_STAKE = 1e15`.

**Intended invariants**
- **INV-1 (stake conservation):** `totalStaked == Σ userInfo[u].amount`. Maintained by stake/withdraw/pauseWithdraw.
- **INV-2 (phUSD custody):** `phUSD.balanceOf(this) == totalStaked` (only stake deposits add phUSD; rewards are minted to users, not held). Broken by `emergencyTransfer` and by un-credited direct donations.
- **INV-3 (stable solvency):** `rewardToken.balanceOf(this) >= rewardBalance + Σ unclaimedStable`. Distributed stable is always capped by `rewardBalance` (see `_updatePool`), so the contract can always cover stable claims. Broken only by `emergencyTransfer` / fee-on-transfer tokens.
- **INV-4 (no stable over-distribution):** cumulative stable credited to `accStablePerShare` ≤ cumulative `collectReward` amounts (cap-by-`rewardBalance`).
- **INV-5 (debt floor, no underflow):** for any user, `amount * accX / PRECISION >= Xdebt`, because the debt is reset to `amount * accX / PRECISION` every time `amount` changes and `accX` is monotonically non-decreasing → the `_claimRewards` subtractions never underflow.
- **INV-6 (minimum position, intended):** every non-zero position ≥ `MINIMUM_STAKE`, hence `totalStaked == 0 || totalStaked >= MINIMUM_STAKE`. Enforced by `stake` (require) and `withdraw` (dust-forces-full-exit). **Violable via `pauseWithdraw`** (see LOCAL-005).
- **INV-7 (phUSD APY targeting):** `phUSDPerSecond == totalStaked * desiredAPYBps / 10000 / SECONDS_PER_YEAR` so per-share phUSD emission ≈ `desiredAPYBps` per year per staked unit. Maintained by stake/withdraw/APY-commit; **goes stale after `pauseWithdraw`** (see LOCAL-003).

---

## 3. Linear-Depletion reward math (derivation)

Two independent reward streams accrue in `_updatePool()`:

### Stable stream (from `collectReward`)
On every update with `timeElapsed = block.timestamp - lastRewardTime`:
```
potentialReward = rewardPerSecond * timeElapsed / PRECISION
toDistribute    = min(potentialReward, rewardBalance)
accStablePerShare += toDistribute * PRECISION / totalStaked
rewardBalance     -= toDistribute
rewardPerSecond    = rewardBalance * PRECISION / depletionDuration      // <-- re-anchor
```
`rewardPerSecond` is stored ×PRECISION and equals `rewardBalance/depletionDuration`. The intent ("Linear Depletion") is to pay out `rewardBalance` evenly over `depletionDuration`.

**Derived actual behavior:** because the rate is recomputed as `remainingBalance / depletionDuration` after *every* distribution (and on every `collectReward`/`stake`/`withdraw`/`claim`/`setDepletionDuration`), the continuous dynamics are `dB/dt = -B/D`, i.e. **exponential decay** `B(t) = B0·e^(−t/D)`, not linear depletion. Consequences are documented as LOCAL-001.

### phUSD stream (from APY)
```
phUSDPerSecond = totalStaked * desiredAPYBps / 10000 / SECONDS_PER_YEAR
phUSDReward    = timeElapsed * phUSDPerSecond
accPhUSDPerShare += phUSDReward * PRECISION / totalStaked
```
Because `phUSDPerSecond ∝ totalStaked`, per-share phUSD emission is `≈ desiredAPYBps/year` independent of pool size — this stream IS genuinely linear/APY-correct while `phUSDPerSecond` is in sync with `totalStaked` (INV-7). phUSD is **minted** on claim (no balance backing) — so accounting errors here are direct phUSD inflation.

### Per-user settlement (`_claimRewards`)
```
pendingPhUSD  = amount * accPhUSDPerShare  / PRECISION - phUSDDebt   -> phUSD.mint(user, .)
pendingStable = amount * accStablePerShare / PRECISION - stableDebt  -> rewardToken.safeTransfer(user, .)
```

### Arithmetic safety review
- **No div-by-zero:** `depletionDuration > 0` enforced in constructor and `setDepletionDuration`; per-share math guarded by `totalStaked != 0`.
- **No underflow:** see INV-5. Subtractions `rewardBalance -= toDistribute` safe (`toDistribute = min(., rewardBalance)`); `totalStaked -= amount`/`user.amount -= amount` guarded by `require(amount <=` balance`)`.
- **Overflow:** all products (`rewardBalance*PRECISION`, `rewardPerSecond*timeElapsed`, `amount*accX`) stay well within 2²⁵⁶ for realistic token magnitudes; no `unchecked`, so any genuine overflow reverts rather than corrupts.
- **Rounding / precision loss (LOCAL-004):** `rewardBalance -= toDistribute` always subtracts the full `toDistribute`, but `accStablePerShare += toDistribute*PRECISION/totalStaked` floors. The floored remainder is debited from `rewardBalance` without ever being credited to any share → stable tokens are stranded (recoverable only via `emergencyTransfer`). Magnitude bounded by `< totalStaked/PRECISION` wei per update but accumulates with frequent small updates (which the LOCAL-001 re-anchoring encourages).
- **Emission rounding:** `phUSDPerSecond` and per-share increments floor; very small stake×APY combos can floor emission to 0 (negligible, expected for tiny pools).

---

## 4. Verified LOCAL properties & LOCAL findings

### Verified properties
| Property | Status | Notes |
|---|---|---|
| No unbounded loops | **verified** | Zero loops anywhere; all ops O(1). No DoS-by-iteration. |
| Checked arithmetic | **verified** | 0.8.19, no `unchecked`, no assembly. |
| No reward over-distribution (stable) | **verified** | `toDistribute = min(potential, rewardBalance)` (INV-4). |
| No reward-debt underflow | **verified** | Debt reset on every `amount` change; `accX` monotonic (INV-5). |
| Stake conservation | **verified** | `totalStaked` mirrors per-user `amount` across stake/withdraw/pauseWithdraw (INV-1). |
| Access control on admin fns | **verified** | `onlyOwner` on the 4 config fns; pauser-gated pause/unpause. |
| Reentrancy guarded | **violated/partial** | Only `collectReward` is `nonReentrant`; `stake`/`withdraw`/`claim` are not and settle reward debt *after* external calls (LOCAL-002). |
| Initializer protected | **N/A** | Constructor-based, not upgradeable; no storage-collision/initializer surface. |
| Pause mechanism present | **verified** | OZ `Pausable`; pauser-gated. |

### Local findings

**LOCAL-001 — "Linear Depletion" is exponential decay; depletion window re-anchors on every interaction (DOCUMENTED V1 BUG)**
- Type: spec deviation / reward-accounting. Severity: local-medium. Functions: `_updatePool` (L389-426), and every caller (`collectReward`, `stake`, `withdraw`, `claim`, `setDepletionDuration`).
- `rewardPerSecond = rewardBalance*PRECISION/depletionDuration` is recomputed after every distribution and on every state-changing call. Effect: `rewardBalance` decays as `B0·e^(−t/D)` → never fully distributed within `depletionDuration` (~63% in one window if continuously updated, residual asymptotes slowly to 0). The realized payout rate also becomes path-dependent: a long quiet period followed by one update pays out (near-)linearly, while frequent interactions slow it toward the exponential curve.
- This is explicitly the documented V1 rate-recompute bug (`lib/phlimbo-ea/CLAUDE.md`); PhlimboV2 removes the recompute from `_updatePool`. Surfaced for recall; expect sanitizer to map to known-issues.
- Recommendation: anchor `rewardPerSecond` once at funding/duration-change time (V2 approach), not inside `_updatePool`.

**LOCAL-002 — Inconsistent reentrancy protection; reward debt settled after external calls (CEI violation)**
- Type: reentrancy / CEI. Severity: local-medium (guard gap); exploitability deferred to interaction analysis. Functions: `stake` (L295-328), `withdraw` (L334-369), `claim` (L374-381) via `_claimRewards` (L432-455).
- `_claimRewards` performs external calls (`phUSD.mint`, `rewardToken.safeTransfer`) and `stake` additionally calls `phUSD.safeTransferFrom` **before** the caller writes back the user's `phUSDDebt`/`stableDebt`. None of these three functions carry `nonReentrant` (only `collectReward` does). If `rewardToken` or `phUSD.mint` invokes a recipient callback (ERC777-style hook / non-standard token), an attacker can re-enter `claim`/`withdraw` while debts are stale and re-collect the same pending amount (double/N-claim), draining stable rewards and minting excess phUSD.
- Local fact: the guard gap + claim-before-settle ordering exists. **Exploitability depends on token callback behavior (cross-contract)** → deferred. Under the stated "standard ERC20 / non-callback Flax mint" assumption it is not triggerable.
- Recommendation: add `nonReentrant` to `stake`/`withdraw`/`claim`, or reorder so debts are written before external transfers.

**LOCAL-003 — Pause does not freeze accrual; `pauseWithdraw` leaves `phUSDPerSecond` stale → over-emission to remaining stakers**
- Type: reward-accounting / spec. Severity: local-low/medium. Functions: `pauseWithdraw` (L245-261), `_updatePool` (L389-426), `claim` (L374-381).
- `pauseWithdraw` decrements `totalStaked` but (a) does NOT call `_updatePhUSDEmissionRate`, and (b) does NOT advance `lastRewardTime`. After `unpause`, the first `_updatePool` credits the **entire paused interval** of accrual against the now-reduced `totalStaked`, using a `phUSDPerSecond` still sized for the pre-pause (larger) `totalStaked`. Result: remaining stakers earn phUSD/stable for the paused period at an inflated per-share rate (effective APY > `desiredAPYBps`, extra phUSD minted). The phUSD rate stays stale until the next `stake`/`withdraw` (note: `claim` never refreshes it), so a run of `claim`-only activity prolongs the over-emission.
- Recommendation: refresh `phUSDPerSecond` in `pauseWithdraw` (and/or in `claim`), and decide explicitly whether accrual should pause while paused (e.g., advance `lastRewardTime` on `unpause`).

**LOCAL-004 — Stable reward stranding via per-share rounding**
- Type: precision loss. Severity: local-low. Function: `_updatePool` (L409-417).
- `rewardBalance -= toDistribute` (full) while `accStablePerShare += toDistribute*PRECISION/totalStaked` floors. The floored remainder leaves `rewardBalance` but is never credited to shares → permanently stranded stable tokens (recoverable only via `emergencyTransfer`). Bounded per update but accumulates, amplified by the frequent small updates LOCAL-001 induces.
- Recommendation: carry the rounding remainder forward (don't decrement `rewardBalance` by amounts not credited to `accStablePerShare`).

**LOCAL-005 — `pauseWithdraw` bypasses the MINIMUM_STAKE / dust invariant (INV-6)**
- Type: invariant weakening. Severity: local-low. Function: `pauseWithdraw` (L245-261).
- Unlike `withdraw`, `pauseWithdraw` only checks `amount > 0` and `user.amount >= amount`; it permits leaving a residual position `0 < remaining < MINIMUM_STAKE`. After `unpause` these sub-minimum positions persist, so `totalStaked` can fall below `MINIMUM_STAKE` (if all positions are dusted), weakening the first-depositor / per-share-inflation mitigation that `MINIMUM_STAKE` exists to provide.
- Recommendation: apply the same dust-forces-full-exit rule in `pauseWithdraw`, or re-validate minimums on `unpause`.

**LOCAL-006 — `emergencyTransfer` can permanently brick the contract into a paused state (owner footgun)**
- Type: operational hazard / footgun (Law 3 non-obvious consequence). Severity: local-low. Functions: `emergencyTransfer` (L214-227), `unpause` (L197-200), `setPauser` (L206-208).
- `emergencyTransfer` calls `_pause()` unconditionally, but `unpause()` requires `msg.sender == pauser`. If `pauser == address(0)` — the default until `setPauser` is called, and the value the `setPauser` docstring explicitly suggests to "disable pausing" — `unpause()` can never succeed (no caller is `address(0)`), so the contract is stuck paused. Additionally, `emergencyTransfer` drains the contract's entire phUSD balance, so even the `whenPaused` `pauseWithdraw` escape hatch then reverts (no phUSD to transfer), and `totalStaked`/`userInfo` are not zeroed. A competent, non-malicious owner who set `pauser=0` to "disable pausing" would be surprised that an emergency drain leaves the contract permanently frozen.
- Recommendation: allow `owner` to unpause (or zero out staking state on `emergencyTransfer`), and document the pauser==0 interaction.

> Deferred to interaction analysis (NOT local findings): exploitability of LOCAL-002 (depends on token callbacks); economic impact of over/under-emission; whether the external yield-accumulator can grief via `collectReward` timing; phUSD inflation impact on the wider protocol.

---

## 5. Trust assumptions

- **Owner (trusted, non-malicious):** controls `setDesiredAPY` (uncapped → controls phUSD inflation rate; obvious knob, suppressed as owner-trust), `setDepletionDuration`, `setPauser`, and `emergencyTransfer` (a full drain of staked principal + rewards — intended nuclear escape hatch; obvious owner power, suppressed; but see LOCAL-006 footgun on the resulting permanent-pause state).
- **Pauser (trusted role):** global pauser address can pause/unpause at will. Pausing halts stake/withdraw/claim but leaves `pauseWithdraw` open as emergency exit. `pauser == address(0)` disables `pause()`/`unpause()` (see LOCAL-006).
- **phUSD / IFlax (semi-trusted, mint authority granted to this contract):** assumed standard ERC20 semantics with a non-reentrant `mint` (no recipient hook). PhlimboEA holds phUSD **mint rights**, so reward-accounting bugs translate directly into phUSD supply inflation. Implementation is a mutable dependency (interface only) — not analyzed.
- **rewardToken (semi-trusted stable):** assumed standard ERC20, **no fee-on-transfer**, **no transfer hook/callback**. `collectReward` credits `rewardBalance += amount` on the requested amount, so a fee-on-transfer token would over-credit and break INV-3. (Fee-on-transfer/weird ERC20 are known-invalid per repo policy unless explicitly in scope.)
- **Yield-accumulator (external, untrusted-but-benign caller of `collectReward`):** anyone may fund rewards; funding is value-additive but re-anchors the depletion window (LOCAL-001). No privileged trust required.
- **No ETH handling:** contract holds/forwards no native value; no `call{value}`/`receive`/`fallback`.

---

## 6. Interface abstraction for downstream interaction scanners

External calls this contract makes (trust boundaries):
| Target | Methods | Trust | Notes |
|---|---|---|---|
| `IFlax phUSD` | `mint`, `transfer`/`transferFrom` (via SafeERC20), `balanceOf` | semi-trusted, **has mint authority here** | reward phUSD is minted, not balance-backed; mint assumed non-reentrant |
| `IERC20 rewardToken` | `transferFrom`, `transfer`, `balanceOf` | semi-trusted | assume standard ERC20, no FoT, no hook |

Entry points (pre/post-conditions):

- `collectReward(amount)` — `nonReentrant`, permissionless. Pre: `amount>0`, caller approved `amount` of `rewardToken`. Post: `_updatePool()` run; `rewardBalance += amount`; `rewardPerSecond = rewardBalance*PRECISION/depletionDuration`. External: `rewardToken.transferFrom(caller→this)`.
- `stake(amount, recipient)` — `whenNotPaused`, no reentrancy guard. Pre: `amount>=MINIMUM_STAKE`. Post: pool updated; recipient's prior rewards claimed; `userInfo[recipient].amount += amount`; debts reset; `totalStaked += amount`; `phUSDPerSecond` refreshed. External (before final state writes): `phUSD.mint`, `rewardToken.transfer` (claim), `phUSD.transferFrom(caller→this)`. Caller pays; recipient defaults to caller if zero.
- `withdraw(amount)` — `whenNotPaused`, no reentrancy guard, per-caller. Pre: `userInfo[caller].amount >= amount`. Post: pool updated; rewards claimed; dust rule (if `0 < remaining < MINIMUM_STAKE` → full exit); `totalStaked` and `userInfo` reduced; `phUSDPerSecond` refreshed. External (claim before final state writes): `phUSD.mint`, `rewardToken.transfer`; then `phUSD.transfer(this→caller)` (after state writes).
- `claim()` — `whenNotPaused`, no reentrancy guard, per-caller. Pre: none. Post: pool updated; pending phUSD minted + pending stable transferred; debts reset. (Does NOT refresh `phUSDPerSecond`.)
- `pauseWithdraw(amount)` — `whenPaused`, per-caller, CEI-correct (state before transfer), no pool/claim/rate update. Pre: paused, `0 < amount <= userInfo[caller].amount`. Post: `userInfo[caller].amount -= amount`, `totalStaked -= amount`, `phUSD.transfer(this→caller)`. Does NOT enforce MINIMUM_STAKE (LOCAL-005) and leaves `phUSDPerSecond` stale (LOCAL-003).
- `setDesiredAPY(bps)` — `onlyOwner`, two-step (re-call same `bps` within ≤100 blocks to commit). Commit post: `_updatePool()`, `desiredAPYBps = bps`, `phUSDPerSecond` refreshed.
- `setDepletionDuration(_duration)` — `onlyOwner`. Pre: `_duration>0`. Post: `_updatePool()`, `depletionDuration` set, `rewardPerSecond` recomputed.
- `setPauser(address)` — `onlyOwner`. Post: `pauser` set (zero ⇒ pause/unpause disabled; see LOCAL-006).
- `emergencyTransfer(recipient)` — `onlyOwner`. Post: transfers entire `phUSD` and `rewardToken` balances to `recipient`, then `_pause()`. Breaks INV-2/INV-3; can brick (LOCAL-006).
- `pause()` / `unpause()` — `msg.sender == pauser`. Toggle OZ `_paused`.
- Views: `pendingPhUSD(user)`, `pendingStable(user)` (simulate `_updatePool`; `pendingStable` does not re-anchor rate, so may diverge slightly from realized accrual under LOCAL-001), `getPoolInfo()`, `getPendingAPYInfo()`, plus state getters.

Events: `Staked`, `Withdrawn`, `RewardsClaimed`, `EmergencyWithdrawal` (IPhlimbo); `RewardCollected`, `RateUpdated` (declared, never emitted), `DepletionDurationUpdated`, `IntendedSetAPY`, `DesiredAPYUpdated`.
Modifiers in use: `onlyOwner`, `nonReentrant` (collectReward only), `whenNotPaused`, `whenPaused`.

---

## 7. Complexity

- LOC: 557
- External/public functions: 15 (+ auto getters)
- Internal functions: 3 (`_updatePool`, `_claimRewards`, `_updatePhUSDEmissionRate`)
- State variables: 16 + 1 mapping + 3 constants
- Distinct external-call sites: 7
- Loops: 0 | Assembly: 0 | `unchecked`: 0
