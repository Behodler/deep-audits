# QA Report for Phlimbo (Linear Distribution) — Run phlimbo-ea-03

**Submodule head**: `1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301`
**Target**: `lib/phlimbo-ea/src/Phlimbo.sol`

## Summary

| Severity | Count |
|----------|-------|
| Centralization Risk | 4 |
| Low Risk | 13 (+1 dual-listed) |
| **Total unique** | **17** |

`C-04` and `L-05` describe the same root cause (pauser sandwich); per C4 deduplication
convention the issue is documented once under Centralization and the matching Low slot is
preserved as a cross-reference so the L-numbering remains contiguous with the ledger.

The automated 4naly3er bot report is attached as Appendix A.

---

## Centralization Risks

### [C-01] `setDepletionDuration` has no minimum floor and no two-step gate — one-tx flash-drain of `rewardBalance` <!-- id: pe3c1 -->

**Location**: [`src/Phlimbo.sol#L178-L191`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L178-L191)

`setDepletionDuration` is `onlyOwner`, has only `require(_duration > 0)`, and applies
immediately in the same transaction. There is no minimum-duration floor and no two-step
preview/commit gate — strictly asymmetric with `setDesiredAPY`, which at least has a
100-block delay. An adversarial or compromised owner can collapse the depletion window to
1 second so that the next `_updatePool` credits the entire `rewardBalance` to
`accStablePerShare` in a single block.

In an MEV bundle the sequence is `setDepletionDuration(1) → stake(huge) → _updatePool
absorbs entire rewardBalance → claim() → withdraw`; all external funder rewards are
captured by the owner-aligned staker. This is the strongest concentration finding in the
bundle because there is no friction at all, making it structurally worse than C-03 which
at least retains the two-step gate.

**Impact**: Owner can drain the entire `rewardBalance` to itself in one transaction.
Every external funder's contributions are exposed to capture.

**Recommendation**: Add (a) a hard floor `require(_duration >= MIN_DEPLETION_DURATION)`
matching the intended distribution cadence (e.g. 1 day or 1 week), and (b) a two-step
preview/commit gate symmetric with `setDesiredAPY` (preview emits `IntendedSetDuration`;
commit applies after a delay window). Optionally route through a timelock controller.

---

### [C-02] `emergencyTransfer` sweeps all funds without zeroing accounting, silently bricking `pauseWithdraw` <!-- id: pe3c2 -->

**Location**: [`src/Phlimbo.sol#L214-L227`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L214-L227)

`emergencyTransfer` sweeps both `phUSD` and `rewardToken` balances to a recipient address
and then pauses the contract. It does not zero `totalStaked`, `userInfo[*].amount`, or any
accumulator, and does not credit users for the swept principal. After the sweep the
documented emergency-exit path (`pauseWithdraw`) silently reverts at the `SafeERC20` layer
because the contract holds zero `phUSD`, while every user still has a non-zero
`user.amount` entitlement on chain.

The trap is structural rather than adversarial-only: even an honest owner who uses this
function in good faith breaks the documented escape hatch. Stakers retain on-chain
entitlements against an empty vault.

**Impact**: Owner can sweep all principal and reward tokens; the documented user escape
hatch silently reverts afterward. User entitlements persist against an empty vault.

**Recommendation**: Pick one: (a) restrict the sweep to *excess* balance only — compute
`owed = totalStaked + rewardBalance`, sweep `max(0, balanceOf(this) - owed)`; (b) zero
per-user accounting (loop over users or require migration shutdown) before sweeping;
(c) add a timelock + multisig + on-chain rationale event; or (d) replace
`emergencyTransfer` with a per-user opt-in claim against a frozen snapshot.

---

### [C-03] Uncapped `desiredAPYBps` converts directly into unbounded `phUSD` mint pressure; the two-step gate is delay-only <!-- id: pe3c3 -->

**Location**: [`src/Phlimbo.sol#L151-L172`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L151-L172)

`setDesiredAPY` is `onlyOwner` with a two-step preview/commit gate (100-block delay), but
has no on-chain magnitude bound on `bps`. `SYMBOLIC-005 PASS` confirms the gate state
machine works exactly as designed — it provides a 100-block delay and nothing more.
Because `phUSD` is both stake and reward, an arbitrarily large APY converts directly into
an arbitrarily large per-second `phUSD` mint flow.

An adversarial owner can pre-stake, hike APY, accrue and exit with freshly-minted `phUSD`
with only roughly twenty minutes of mempool friction (the 100-block window). The
structural critique is that the gate's design intent (mitigate magnitude attacks) is not
actually realized — the gate is delay-only.

**Impact**: Owner can set arbitrary APY; combined with `phUSD` being both stake and
reward, an adversarial owner can pre-stake → hike → claim → exit with only ~20 minutes of
friction. Affects `phUSD` supply system-wide.

**Recommendation**: Add a hard magnitude cap `require(bps <= MAX_APY_BPS)` reflecting the
protocol's economic envelope (e.g. `10_000` = 100%). Optionally extend the commit window
from 100 blocks to a time-based delay (e.g. 24h) and route the setter through a timelock.
Converting the current delay-only design into a delay + magnitude-bound design is
minimal-code, high-value hardening.

---

### [C-04] Pauser can sandwich `pause`/`unpause` cycles to selectively deny yield to specific stakers <!-- id: pe3c4 -->

**Location**: [`src/Phlimbo.sol#L197-L261`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L197-L261)

The pauser role has unilateral `pause`/`unpause` power with no minimum unpause-cooldown
and no commit-reveal on the timing. A pauser observing a substantial `accStablePerShare`
credit pending after `collectReward` can pause immediately after the credit and force
liquidity-constrained users into `pauseWithdraw`, which silently forfeits the pending
rewards. The forfeited share is then implicitly redistributed to the pauser-aligned cohort
on `unpause`.

This sharpens the documented KI-6 pauser trust assumption into a concrete economic
exploitation pattern: pauser-aligned stakers extract a disproportionate yield share while
targeted stakers forced into `pauseWithdraw` forfeit accrued rewards. (Dual-listed at
QA level as L-05 below; this entry is the primary write-up.)

**Impact**: Pauser-aligned stakers extract a disproportionate yield share; targeted
stakers forced into `pauseWithdraw` forfeit accrued rewards. No direct fund theft, but
value redistribution against the documented operator intent.

**Recommendation**: Add (a) a minimum unpause-cooldown so `pause` cannot be re-armed for a
configurable window after every `unpause`, (b) require the pauser to be a multisig or DAO
module rather than an EOA, and (c) emit `Paused`/`Unpaused` events with sufficient
context for off-chain monitoring. Pairs naturally with the M-01 / L-06 `pauseWithdraw`
rebase recommendation.

---

## Low Risk Findings

### [L-01] Declared event `RateUpdated` is never emitted <!-- id: pe3l1 -->

**Location**: [`src/Phlimbo.sol#L105-L106`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L105-L106)

The event `RateUpdated(uint256 newRate, uint256 newBalance)` is declared at line 106 but
never emitted anywhere in the contract. Off-chain indexers register the event from the
ABI and silently miss every rate transition. Rate transitions occur in `_updatePool`
(L416), `collectReward` (L283), and `setDepletionDuration` (L188) without an explicit
`RateUpdated` emit.

**Impact**: No fund risk. Dead event declaration; off-chain observability gap.

**Recommendation**: Either remove the declaration or — preferably — emit
`RateUpdated(rewardPerSecond, rewardBalance)` inside `_updatePool` after the recompute,
and inside `setDepletionDuration` / `collectReward` after `rewardPerSecond` is reset.
Emitting is the better fix because the observability is genuinely useful.

---

### [L-02] `setDesiredAPY` commit is mempool-visible; stakers front-run to capture rate-change delta <!-- id: pe3l2 -->

**Location**: [`src/Phlimbo.sol#L151-L172`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L151-L172)

The commit branch of `setDesiredAPY` is a public, mempool-visible transaction with a
known signature. `SYMBOLIC-005 PASS` confirms the two-step gate is delay-only — it
provides exactly the 100-block window the spec advertises and nothing more. MEV bots can
stake just before the commit lands and exit shortly after the new rate takes effect,
capturing a disproportionate share of post-commit accrual at the expense of passive
stakers.

**Impact**: Sophisticated mempool-watching stakers capture a disproportionate share of
post-commit accrual. No direct fund theft; the two-step gate's intended MEV mitigation is
not realized.

**Recommendation**: Route the commit transaction through a private mempool (e.g.
Flashbots Protect) as operational practice. For an on-chain mitigation, pair the
magnitude-cap recommendation in C-03 with a rate-of-change cap
(`max |bps_new - bps_old|` per epoch) to bound the MEV size.

---

### [L-03] `setDesiredAPY` commit branch does not clear `pendingAPYBps` / `pendingAPYBlockNumber` <!-- id: pe3l3 -->

**Location**: [`src/Phlimbo.sol#L163-L171`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L163-L171)

The commit branch of `setDesiredAPY` only resets `apySetInProgress = false` (line 170).
It does not zero `pendingAPYBps` or `pendingAPYBlockNumber`. The `getPendingAPYInfo()`
view continues to return the just-committed value as if it were still pending until the
next preview overwrites those slots.

**Impact**: No on-chain impact. Off-chain integrators reading `getPendingAPYInfo()` get a
stale pending value that misrepresents protocol state.

**Recommendation**: In the commit branch (after line 170), also clear `pendingAPYBps = 0`
and `pendingAPYBlockNumber = 0` so `getPendingAPYInfo()` unambiguously reports no pending
change.

```solidity
// commit branch
desiredAPYBps = pendingAPYBps;
pendingAPYBps = 0;
pendingAPYBlockNumber = 0;
apySetInProgress = false;
```

---

### [L-04] `setPauser` emits no event <!-- id: pe3l4 -->

**Location**: [`src/Phlimbo.sol#L206-L208`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L206-L208)

`setPauser` is a privileged `onlyOwner` setter that rotates the pauser role but emits no
event. Off-chain monitoring (pauser-key health checks, security alerts, governance
dashboards) cannot detect rotation via log subscription alone.

**Impact**: No fund risk. Off-chain observability gap: pauser rotation is not
log-discoverable.

**Recommendation**: Declare and emit
`PauserUpdated(address indexed oldPauser, address indexed newPauser, address indexed updatedBy)`
inside `setPauser`. Privileged role-rotation events are a baseline observability
requirement.

---

### [L-05] Pauser sandwich (dual-listed) — see [C-04] above

This QA-level entry is reserved to preserve label continuity with the persistent ledger.
The full description, impact, and recommendation are documented under **C-04** because the
root cause is the documented KI-6 pauser trust assumption and belongs primarily in the
Centralization bundle. The QA-only mitigations (emit `Paused(by, reason)` /
`Unpaused(by)` with sufficient context for off-chain anomaly detection, and require an
unpause-cooldown) are repeated in the C-04 recommendation.

---

### [L-06] `pauseWithdraw` silently forfeits accrued rewards with no event and orphans per-share accumulator residue <!-- id: pe3l6 -->

**Location**: [`src/Phlimbo.sol#L245-L261`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L245-L261)

`pauseWithdraw` decrements `user.amount` and `totalStaked` but neither calls
`_updatePool` nor settles/forfeits rewards explicitly. `user.phUSDDebt` and
`user.stableDebt` are left at pre-withdraw values, and `accStablePerShare` retains the
per-share credit that was attributable to the withdrawn portion. The bare forfeiture is
acknowledged in KI-4. The downstream DoS aspect is captured by M-01; this finding captures
only the residual angles: (a) no `RewardsForfeited(user, phUSDAmount, stableAmount)`
event is emitted, and (b) the orphaned accumulator residue has undefined redistribution
semantics — it implicitly enriches future entrants rather than being explicitly returned
to `rewardBalance`.

**Impact**: No direct fund risk beyond the documented KI-4 forfeiture. Off-chain
reconciliation cannot distinguish a "normal" partial exit from a forfeiture event.
Orphan-accumulator residue implicitly enriches future entrants instead of being
explicitly returned to `rewardBalance`.

**Recommendation**: (a) Emit `RewardsForfeited(user, phUSDAmount, stableAmount)` computed
from the stale debts at the moment of withdrawal. (b) Define orphan-residue semantics:
either return the forfeited share to `rewardBalance` (and recompute `rewardPerSecond`),
or explicitly document the redistribution-to-future-entrants behavior. Pair with the
M-01 fix (rebase debts) for a consistent `pauseWithdraw` shape.

---

### [L-07] `collectReward` is mempool-visible: searchers can sandwich a funding deposit to capture rewards intended for long-term stakers <!-- id: pe3l7 -->

**Location**: [`src/Phlimbo.sol#L270-L286`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L270-L286)

`collectReward(amount)` is a public mempool-visible transaction with a known signature.
MEV bots front-run with `stake(big_amount)`, let `collectReward` execute (growing
`rewardBalance` and `accStablePerShare`), then back-run with `claim() + withdraw`,
exiting with a captured slice of freshly-deposited rewards. This is the standard
MasterChef-style MEV sandwich applied to the funding path.

**Impact**: MEV searchers capture a slice of freshly-deposited rewards. Long-term stakers
see depressed effective APY. No direct fund theft from the protocol contract; this
redistributes value from passive stakers to MEV bots.

**Recommendation**: Route the funding transaction through a private mempool (Flashbots
Protect or similar). For an on-chain mitigation, see M-02: restricting `collectReward`
to a whitelisted funder also eliminates this surface by allowing the funder to use
private inclusion. Alternative: implement a stake-cooldown so a stake within N blocks of
a `collectReward` is excluded from that batch's accrual.

---

### [L-08] `collectReward` with zero `totalStaked` silently leaks funder value: rate is anchored but the depletion clock does not advance <!-- id: pe3l8 -->

**Location**: [`src/Phlimbo.sol#L270-L286`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L270-L286)

When `totalStaked == 0`, `_updatePool` early-returns and only advances `lastRewardTime`
without distributing. If `collectReward` fires during this window, `rewardPerSecond` is
set as if the depletion clock will advance from now, but no accrual actually happens
until a staker arrives. Either funder value parks in `rewardBalance`, or the first
subsequent staker captures a disproportionate windfall, depending on timing.

**Impact**: Funder deposits during zero-staked periods are not distributed in the
advertised window; either parked or windfall to the next entrant. No funds lost outright,
but value-allocation deviates from the documented intent.

**Recommendation**: Add `require(totalStaked > 0, "No stakers")` at the top of
`collectReward`, or defer the `rewardPerSecond` recompute until the first subsequent
stake. The first option matches the documented funding cadence; the second preserves
liveness but needs an explicit semantics decision about windfall allocation.

---

### [L-09] `claim()` / `stake()` / `withdraw()` violate CEI; cross-function reentrancy lever conditional on hooked-token semantics <!-- id: pe3l9 -->

**Location**: [`src/Phlimbo.sol#L295-L381`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L295-L381)

`claim`, `stake`, and `withdraw` all execute external token interactions (`phUSD.mint`,
`rewardToken.safeTransfer`, `safeTransferFrom`) before updating `user.phUSDDebt` /
`user.stableDebt`. The functions also lack the `nonReentrant` modifier (only
`collectReward` is `nonReentrant`). Under the documented trust model neither `phUSD` nor
`rewardToken` has callback hooks, so the cross-function reentrancy lever is not currently
exploitable — but the defense-in-depth gap is real and would be exploitable under any
future governance choice to point `rewardToken` at a hooked ERC-20.

**Impact**: Conditional on `rewardToken` having ERC777-style callbacks OR `phUSD.mint`
dispatching to user-controlled code: double-claim of pending rewards and (for `withdraw`)
`totalStaked` corruption. Under documented trust assumptions, none of these tokens have
callbacks, so the exploit is not realized today. Defense-in-depth QA.

**Recommendation**: Add `nonReentrant` to `claim`, `stake`, and `withdraw` as cheap
belt-and-braces. Additionally, restructure `_claimRewards` and the bodies of `stake` /
`withdraw` to follow strict CEI: compute the pending amounts, update `user.phUSDDebt` /
`user.stableDebt` *first*, then make the external `mint` / `transfer` calls. The
state-write reorder is the more thorough fix and matches the modifier-free idiom used
elsewhere in the codebase.

---

### [L-10] `stake(amount, recipient)` lets anyone forcibly re-anchor a victim's reward-debt clock <!-- id: pe3l10 -->

**Location**: [`src/Phlimbo.sol#L295-L328`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L295-L328)

`stake(amount, recipient)` accepts any recipient and, if `recipient.amount > 0`, triggers
`_claimRewards(recipient)` — a forced claim on the victim's behalf at the attacker's
schedule. The attacker pays `MINIMUM_STAKE` (`1e15` phUSD) per grief. The function also
opens a selective-DoS variant: if the victim is USDC-blacklisted or `phUSD.mint` reverts
on the victim (the M-03 surface), the entire stake reverts but the attacker has
enumerated the victim by address.

**Impact**: Forced-claim grief — attacker can trigger `_claimRewards` on a victim
(forced taxable event, forced mint/transfer at non-optimal time) and can selectively
probe or DoS via the M-03 path. The victim's rewards still flow to the victim; only
timing is hijacked.

**Recommendation**: Either (a) `require(recipient == msg.sender)`, (b) require
per-recipient approval (`mapping(address => mapping(address => bool)) stakeApproval`),
or (c) skip the forced `_claimRewards` path when `msg.sender != recipient` (snapshot the
recipient's debt against accumulators without minting/transferring). Option (a) is the
simplest and matches the V2 pattern's natural shape.

---

### [L-11] `phUSD`-is-stake-AND-reward tokenomic compounding spiral <!-- id: pe3l11 -->

**Location**: [`src/Phlimbo.sol#L432-L469`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L432-L469)

`phUSD` is both the staked asset and one of the reward assets (minted via `phUSD.mint`
inside `_claimRewards`). A sophisticated staker can repeatedly claim and re-stake,
growing their share of `totalStaked` faster than passive stakers. Combined with C-03's
uncapped APY, `phUSD` supply expansion is unbounded under the worst-case configuration.
Profile §8.5 confirms no invariant violation; this is a tokenomic design observation, not
a protocol bug.

**Impact**: Stated APY overstates dilution-adjusted real APY; passive stakers are diluted
by compounders; `phUSD` supply expansion under uncapped APY is unbounded. No fund theft
and no invariant break.

**Recommendation**: Document the dilution-adjusted real APY in the user-facing spec, or
amend the spec to compute APY against an external reference (not just stake-time
accrual). Pairs with the C-03 magnitude cap as a sufficient mitigation envelope.

---

### [L-12] Contract publishes no cumulative-distribution audit trail <!-- id: pe3l12 -->

**Location**: [`src/Phlimbo.sol#L270-L455`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L270-L455)

There is no on-chain counter (`totalPhUSDMinted`, `totalStableDistributed`,
`totalRewardsForfeited`) and no periodic summary event that lets an auditor verify
"rewards distributed == rewards funded" over an arbitrary window. The only signal is
per-call `RewardsClaimed` / `RewardCollected` event scraping plus token-transfer log
reconstruction, which is brittle and operationally expensive.

**Impact**: No fund risk. Observability gap: auditors and integrators cannot quickly
verify the linear-depletion intent vs. realized distribution. The workaround is
per-transfer log scraping plus state-diff math.

**Recommendation**: Add cumulative counters
`uint256 public totalPhUSDMinted`, `uint256 public totalStableDistributed`,
`uint256 public totalRewardsForfeited`. Bump them inside `_claimRewards` and
`pauseWithdraw` (after the L-06 fix). Emit a periodic
`DistributionSummary(totalMinted, totalDistributed, totalForfeited, rewardBalance)` event
at every `_updatePool` or at owner-triggered checkpoints.

---

### [L-13] `_updatePhUSDEmissionRate` truncates `phUSDPerSecond` to zero at low TVL × low APY <!-- id: pe3l13 -->

**Location**: [`src/Phlimbo.sol#L461-L470`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L461-L470)

`phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR` uses integer
division with a denominator of `10000 * 365 * 24 * 3600 = 3.1536e11`. When
`totalStaked * desiredAPYBps < 3.1536e11` the result truncates to zero and `phUSD`
accrual silently stops. `MINIMUM_STAKE = 1e15` protects most configurations but not the
boundary cases of sub-1-bps APY or sub-`MINIMUM_STAKE` positions accumulated through
`pauseWithdraw` partials.

**Impact**: Silent under-payment of `phUSD` rewards at boundary configurations (sub-1-bps
APY or sub-`MINIMUM_STAKE` positions). Dust-level impact per C4 fees/yield-rounding rule.

**Recommendation**: Reorder multiply-first:
`phUSDPerSecond = (totalStaked * desiredAPYBps * PRECISION) / 10000 / SECONDS_PER_YEAR`,
and store `phUSDPerSecond` scaled by `PRECISION` (matching the `accStablePerShare`
convention). Apply the matching divide-by-`PRECISION` in `_updatePool`'s `phUSDReward`
computation.

---

### [L-14] `pendingPhUSD()` and `pendingStable()` view-helpers underflow for users with stale debt after `pauseWithdraw` <!-- id: pe3l14 -->

**Location**: [`src/Phlimbo.sol#L479-L514`](https://github.com/Behodler/phlimbo-ea/blob/1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301/src/Phlimbo.sol#L479-L514)

`pendingPhUSD(user)` at line 489 and `pendingStable(user)` at line 513 both end with
`(userDetails.amount * _accPerShare) / PRECISION - userDetails.debt`. For users in the
post-`pauseWithdraw` stale-debt state (same precondition as M-01) the subtraction
underflows and the view reverts with Panic `0x11`. Off-chain dashboards, indexers, and
contracts calling these views revert. `INV-01` + `SYMBOLIC-003` + `SYMBOLIC-004` confirm.

**Impact**: No fund risk. Off-chain dashboards, indexers, and contracts calling these
view functions revert. UI cannot display position info for affected users.

**Recommendation**: Mirror the M-01 fix in the view path: clamp the subtraction to zero.

```solidity
uint256 gross = (userDetails.amount * _accPerShare) / PRECISION;
return gross > userDetails.<token>Debt ? gross - userDetails.<token>Debt : 0;
```

The mutating-path fix in M-01 makes this fix mostly cosmetic, but it remains correct
defensive coding.

---

## Appendix A — 4naly3er Automated QA / Gas Report

The canonical C4-style automated bot report was generated against
`lib/phlimbo-ea/src/` (whole-directory sweep, all of `IFlax.sol`, `MigratorV1V2.sol`,
`Phlimbo.sol`, `PhlimboV2.sol`, and the `interfaces/` group) and is attached as a
separate file in this submissions directory: **`4naly3er-report.md`**.

The bot surfaced 16 gas-optimization classes (e.g. `a += b` vs `a = a + b` for state
variables, custom-error migration, `++i` over `i++`, immutable promotions for
constructor-only state) and the usual non-critical observability nits that overlap with
the manual L-01 / L-04 findings here.
