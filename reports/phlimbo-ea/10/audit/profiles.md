# Contract Profiles — phlimbo-ea run-10

- Submodule HEAD: `e32588d` (`[story-030] Remove pauseWithdraw emergency-exit from PhlimboV3`)
- Baseline for change-diff: `7045a96` (run-07 cold scan)
- Solidity: `^0.8.19` (checked arithmetic; no `unchecked` blocks in either file)
- Scope of this profile: `src/PhlimboV3.sol` (primary, stories 029 & 030), `src/MigratorV2V3.sol`
- Related-but-NOT-analyzed (trust boundaries only): `IFlax`/phUSD, `rewardToken` (ERC20),
  `IPhlimboHook`, `IPhlimboV2`, external pauser (`IPausable`), OZ `Ownable`/`Pausable`/
  `ReentrancyGuard`/`SafeERC20`/`EnumerableSet`.

---

## 1. PhlimboV3.sol

### 1.1 Inheritance / primitives
- `Ownable, Pausable, ReentrancyGuard, IPhlimboV3, IPausable`
- Initialization: plain `constructor` (NOT upgradeable / no initializer) — initializer-protection N/A, no storage-collision surface.
- No assembly. No unbounded recursion. No `delegatecall`. No `block.*`/`blockhash` entropy used
  for any value-bearing outcome (no weak-randomness surface).

### 1.2 External / public function inventory + state-mutation summary

| Function | Vis | Access | Guards | Mutates | Moves tokens |
|---|---|---|---|---|---|
| `setDesiredAPY(bps)` | ext | onlyOwner | — | pendingAPY*/apySetInProgress; commit branch: `_updatePool`, desiredAPYBps, `_updatePhUSDEmissionRate` | no |
| `setDepletionDuration(d)` | ext | onlyOwner | — | `_updatePool`, depletionDuration, rewardPerSecond | no |
| `unpause()` | pub (override) | pauser \|\| owner | reverts if `Flushing` | Pausable._paused | no |
| `pause()` | pub (override) | pauser \|\| owner | — | Pausable._paused | no |
| `setPauser(a)` | ext | onlyOwner | — | pauser | no |
| `setMigrator(a)` | ext | onlyOwner | — | migrator | no |
| `setHook(a)` | ext | onlyOwner | — | hook | no |
| `emergencyTransfer(recipient)` | ext | onlyOwner | — | pauses | **YES** — sweeps phUSD + rewardToken + live promoToken (incl. banked) |
| `startPromotion(token,amt,dur)` | ext | onlyOwner | whenNotPaused | `_updatePool`, promo* slot, phase None→Active | **YES** — `transferFrom` owner (FoT-guarded) |
| `topUpPromotion(amt)` | ext | onlyOwner | — | `_updatePool`, promoRewardBalance/PerSecond | **YES** — `transferFrom` owner (FoT-guarded) |
| `setPromoDepletionDuration(d)` | ext | onlyOwner | — | `_updatePool`, promoDepletionDuration/PerSecond | no |
| `beginFlush()` | ext | onlyOwner | — | `_updatePool`, `_pause`, flushCursor=0, phase Active→Flushing | no |
| `batchClaim(maxIterations)` | ext | **permissionless** | nonReentrant, phase==Flushing | promoDebt align, flushCursor, banks | **YES** — `_tryTransfer` promo to each staker (non-reverting) |
| `finalizePromotion(recipient)` | ext | onlyOwner | phase==Flushing, cursor==len | promo slot cleared, phase→None | **YES** — sweeps `leftover = bal − banked` to recipient |
| `abortFlush()` | ext | onlyOwner | phase==Flushing | phase Flushing→Active | no |
| `claimUnclaimablePromo(token)` | ext | **permissionless** | nonReentrant | zeroes unclaimablePromoOf, dec totalUnclaimableOf | **YES** — reverting `safeTransfer` to caller |
| `claimUnclaimableStable()` | ext | **permissionless** | nonReentrant | zeroes unclaimableStableOf, dec totalUnclaimableStable | **YES** — reverting `safeTransfer` to caller |
| `collectReward(amt)` | ext | **permissionless** | nonReentrant | `_updatePool`, rewardBalance, rewardPerSecond | **YES** — `transferFrom` caller |
| `stake(amt,user)` | ext | user\|\|migrator | whenNotPaused, nonReentrant | full accrual + userInfo + totalStaked + `_stakers.add` + emission | **YES** — pulls phUSD from caller; auto-claim via `_claimRewards` |
| `withdraw(amt,user)` | ext | user\|\|migrator | whenNotPaused, nonReentrant | accrual + userInfo + totalStaked + `_stakers.remove` + emission | **YES** — sends phUSD to caller; auto-claim |
| `claim(user)` | ext | user\|\|migrator | whenNotPaused, nonReentrant | `_updatePool`, debt realign | **YES** — via `_claimRewards` |
| view: `pendingPhUSD/pendingStable/pendingPromo/getPromoInfo/stakerCount/stakerAt/getPoolInfo/getPendingAPYInfo` | ext view | — | — | — | no |

Internal token movers: `_claimRewards` (phUSD mint + stable/promo `_tryTransfer`), `_tryTransfer`,
`_updatePool`, `_updatePhUSDEmissionRate`.

### 1.3 Access-control map
- **onlyOwner**: setDesiredAPY, setDepletionDuration, setPauser, setMigrator, setHook,
  emergencyTransfer, startPromotion, topUpPromotion, setPromoDepletionDuration, beginFlush,
  finalizePromotion, abortFlush.
- **pauser || owner**: pause, unpause.
- **user || migrator** (delegated): stake, withdraw, claim.
- **permissionless** (state-fixed recipients, nonReentrant): batchClaim, claimUnclaimablePromo,
  claimUnclaimableStable, collectReward. All verified to have fixed/self-directed beneficiaries —
  no permissionless caller can redirect value.

### 1.4 Reward-accounting invariants (verified locally)
- **INV-1 (accumulators monotone non-decreasing)**: accStablePerShare, accPhUSDPerShare,
  accPromoPerShare only ever `+=` in `_updatePool`; never reset. `accPromoPerShare` explicitly
  NEVER reset across promotions (comment-documented, verified: no assignment other than `+=`).
- **INV-2 (stable/promo capped by balance)**: `_updatePool` caps `toDistribute`/`promoToDistribute`
  to `rewardBalance`/`promoRewardBalance` before accruing → cannot over-distribute; balances `-=`
  the distributed amount. phUSD stream is UNCAPPED by design (minted on demand, `phUSDPerSecond`).
- **INV-3 (rate recompute discipline — the V2 fix)**: `rewardPerSecond`/`promoRewardPerSecond`
  are recomputed ONLY at collectReward / setDepletionDuration (stable) and
  topUpPromotion / setPromoDepletionDuration (promo). `_updatePool` never recomputes → the
  depletion window does not silently re-anchor on user interaction.
- **INV-4 (Flushing accrual freeze — audit-07 H-01 fix)**: `_updatePool` gates promo accrual on
  `promoPhase != Flushing`; `pendingPromo` view mirrors the same gate. Verified both sites present.
- **INV-5 (promoDebt alignment)**: `batchClaim` aligns every `promoDebt` to current
  `accPromoPerShare` unconditionally (even on banked failure), so post-flush pending==0 and the
  next promotion starts clean. `finalizePromotion` requires `flushCursor == _stakers.length()`
  (contiguous full coverage) over a set frozen while paused.
- **INV-6 (debt reset on position change)**: stake/withdraw recompute all four debts from
  `userInfo.amount * acc / PRECISION` after mutating amount.
- **INV-7 (phUSD emission rate)**: `phUSDPerSecond = totalStaked*desiredAPYBps/10000/SECONDS_PER_YEAR`,
  recomputed after every totalStaked change. See §1.7 for the story-030 verification.

### 1.5 Promo phase state machine
`None → (startPromotion) → Active → (beginFlush) → Flushing → (finalizePromotion) → None`
with `Flushing → (abortFlush) → Active`. Verified: every phase-guarded function checks the
required phase; `unpause` blocked while Flushing; membership set frozen while paused.

### 1.6 story-029 banking mechanism (V3-M-05 "reverting transfer freezes principal")
**New storage (appended — no reordering of prior slots, no collision):**
- `mapping(address => uint256) public unclaimableStableOf` — user → banked stable (NOT keyed by
  token; `rewardToken` is construction-fixed and never rotates).
- `uint256 public totalUnclaimableStable` — aggregate banked stable.
- (Reuses story-027's promo bank: `unclaimablePromoOf[token][user]`, `totalUnclaimableOf[token]`.)

**Mechanism (verified):**
- In `_claimRewards` (:866-880) the stable leg now uses non-reverting `_tryTransfer`; on failure
  it credits `unclaimableStableOf[beneficiary] += pending`, `totalUnclaimableStable += pending`,
  emits `StableClaimFailed`. The promo leg (:891-907) mirrors this into the story-027 promo bank.
- Debt is realigned by the CALLER (stake/withdraw/claim) *after* `_claimRewards` returns, so a
  banked amount is removed from `pending*` views by design (documented in `pendingStable`/
  `pendingPromo`). Recovery is surfaced only via the bank mappings.
- **State-before-transfer ordering**: banking writes occur inside `_claimRewards` before the
  caller's debt realignment; the pull functions (`claimUnclaimableStable`/`claimUnclaimablePromo`)
  zero the per-user entry and decrement the aggregate BEFORE the `safeTransfer`
  (checks-effects-interactions), both nonReentrant. Verified CEI-correct.
- **Beneficiary routing**: banked stable/promo is credited to `beneficiary` (== msg.sender during
  migrator delegation), consistent with the reward-routing model — NOT to `user`. `batchClaim`
  differs deliberately: it forces to the staker directly.
- **Cap interaction (:789)**: banked stable was already debited from `rewardBalance` at accrual
  time, so it is intentionally NOT re-subtracted at the distribution cap; author asserts a
  regression test proves no redistribution. (Cross-contract solvency of phUSD/rewardToken supply
  is deferred to interaction/econ analysis — see trust assumptions.)

### 1.7 story-030 removal (V3-M-06 "pauseWithdraw skips emission-rate recompute")
- **VERIFIED REMOVED**: `pauseWithdraw` does not exist in `PhlimboV3.sol` nor in `IPhlimboV3.sol`.
  Grep confirms it survives only in V1 (`Phlimbo.sol`), V2 (`PhlimboV2.sol`), and their interfaces
  — all out of scope for this change. Diff at `e32588d` shows the function body and all doc
  references deleted from PhlimboV3.
- **No new bypass of the emission-rate path**: `totalStaked` is mutated at exactly two sites —
  `stake` (:678 `+=`) and `withdraw` (:724 `-=`) — and BOTH call `_updatePhUSDEmissionRate()`
  immediately after (:684, :735). The commit branch of `setDesiredAPY` also recomputes (:257).
  `emergencyTransfer` does not touch `totalStaked`. Therefore no path now mutates staked total
  without recomputing `phUSDPerSecond`. Property holds: **verified**.

### 1.8 Token-flow trust boundaries
- `rewardToken` — external stablecoin (USDC-class). Blocklisting recipients is the exact case
  story-029 banks. FoT/rebasing rejected by policy (guarded on promo intake, assumed on stable).
- `promoToken` — partner-supplied, rotates; treated untrusted for transfer success (`_tryTransfer`).
- `phUSD` (IFlax) — first-party mintable. NOTE (residual): `_claimRewards` mints phUSD directly
  (`phUSD.mint`, :863) WITHOUT `_tryTransfer` wrapping — if a phUSD mint reverts it bricks the
  stake/withdraw/claim principal path. story-029 only banks stable+promo, not the phUSD mint leg.
  Low concern (own token, mint expected non-reverting) but surfaced for interaction review.

---

## 2. MigratorV2V3.sol (regression check — changed +228 lines vs baseline)

### 2.1 Shape / primitives
- `Ownable, ReentrancyGuard, IMigratorV2V3`. Immutables: phlimboV2, phlimboV3, phUSD, rewardToken.
- One-shot chunked migrator; `int256 migrateIterator` cursor terminates at `-1`.
- No unbounded loop over user input: `migrate` is bounded by `maxIterations` (chunked). `seedUsers`
  loops over owner-supplied `_users` (owner-trusted input; bounded by owner's gas budget).

### 2.2 Function inventory
| Function | Vis | Access | Guards | Notes |
|---|---|---|---|---|
| `seedUsers(_users)` | ext | onlyOwner | reseed only when `!seeded \|\| iterator==-1` | replaces list wholesale, cursor→0 |
| `migrate(maxIterations)` | ext | **permissionless** | nonReentrant, seeded, iterator>=0 | forceApprove V3; try/catch `migrateOne` per user |
| `migrateOne(user,amount)` | ext | **self-only** (`msg.sender==this`) | NO nonReentrant (deliberate — shared OZ lock) | withdraw V2 → stake V3 → forward deltas |
| `skipCurrent()` | ext | onlyOwner | seeded, iterator>=0 | owner backstop for gas-starved index |
| `claimUnclaimable(token)` | ext | **permissionless** | nonReentrant | reverting safeTransfer to caller (CEI: zero before send) |
| `withdrawAll()` | ext | onlyOwner | — | sweeps phUSD+reward+live promo to owner (incl. banked) |
| `userCount()` | ext view | — | — | |

### 2.3 Verified properties
- **Reentrancy design (verified, non-obvious but correct)**: `migrateOne` MUST NOT carry
  `nonReentrant` because `migrate` already holds OZ v5's single shared lock when it self-calls;
  a guarded `migrateOne` would revert `ReentrancyGuardReentrantCall`, and the try/catch would then
  silently skip EVERY user. Protected by `require(msg.sender==address(this))` instead. Correct.
- **Non-reverting forwarding**: `_forward` uses `_tryTransfer`; on failure banks into
  `unclaimable[token][user]` and emits `RewardForwardFailed`. Pull via permissionless
  `claimUnclaimable` (CEI-correct, zeroes before transfer).
- **Skip semantics**: dust (`amount < minStake`) skipped up-front with empty reason; revert inside
  `migrateOne` caught and skipped carrying raw revert data; cursor ALWAYS advances → pass cannot
  brick. `skipCurrent` backstops gas exhaustion (try/catch does not absorb OOG under 63/64 rule).
- **Cursor / reseed invariant**: reseed forbidden mid-pass; `-1` marks completion; new pass only
  after completion.

### 2.4 Footgun surfaces (surface-for-triage, not adjudicated here)
- **Misconfigured pass still COMPLETES**: an unwired (`setMigrator` missing) or paused Phlimbo
  surfaces as a pass full of skips whose reasons decode to `Error(string)` — owner MUST read
  `UserMigrationSkipped` events after every pass. Operational hazard, author-documented.
- **`withdrawAll` sweeps banked `unclaimable`** leaving those claims unbacked — accepted
  escape-hatch trade-off (mirrors PhlimboV3.emergencyTransfer). Reimbursement is out-of-band
  owner obligation.
- Dead code: `_tryTransfer` is defined and used by `_forward`; no unused-function concern.

---

## 3. Trust assumptions handed to downstream (interaction/econ)
1. `rewardToken` may blocklist recipients (story-029 target); assumed no fee-on-transfer/rebasing.
2. `promoToken` untrusted for transfer success; assumed no FoT (guarded on intake).
3. `phUSD.mint` assumed non-reverting; if it can revert it bricks principal paths (§1.8 residual).
4. Solvency of the stable/promo banks vs. actual contract token balance (banked amounts physically
   held, never redistributed) is a cross-contract/econ property — NOT verified here beyond the
   local accounting that debits `rewardBalance`/`promoRewardBalance` at accrual.
5. `migrator` role (external MigratorV2V3) is owner-set and trusted to route rewards per the
   caller-beneficiary model; delegated auto-claims land in the migrator wallet by design.

## 4. Anomalies / watch-items for run-10 scanners
- **A1 (residual, §1.8)**: `_claimRewards` phUSD mint leg (:863) is the ONE token move NOT made
  non-reverting by story-029 — a reverting phUSD mint still bricks stake/withdraw/claim. Confirm
  IFlax.mint cannot revert for a valid staker (role/pause) before treating M-05 as fully closed.
- **A2**: banked stable/promo credited to `beneficiary` (msg.sender), not `user`. In migrator
  delegation a blocked migrator wallet banks to itself, then must self-pull via
  `claimUnclaimableStable/Promo`. Verify this is the intended custody (looks consistent with the
  routing model, but it is a behavioural change worth an interaction sanity check).
- **A3**: `totalUnclaimableStable`/`totalUnclaimableOf` are deliberately NOT subtracted at the
  `:789` distribution cap. Author cites a no-redistribution regression test — Tier-3 should
  re-derive this rather than trust the comment (echoes the historical KI-unfalsifiable caution).
- story-030 leaves no emission-rate bypass (§1.7) — no watch-item.
