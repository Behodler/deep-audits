# Economic / design-intent scan — stable-staker run-16 (REGRESSION)

Source: `lib/stable-staker` @ `fa06de5` · Profiles: `reports/stable-staker/16/profiles/`
Scope: `src/StableStakerV2.sol`, `src/CrossVersionMigrator.sol`, `src/InPlaceMigrator.sol`,
`src/versions/v1/vendor/FlaxToken.sol`. Context (not in scope): `lib/antimatter/src/Antimatter.sol`.

---

## 0. Headline: the suppression premise is VOID for V2

**Independently verified.** `Antimatter` is `contract Antimatter is ERC20, Ownable, ReentrancyGuard`
constructed `ERC20("Antimatter","AM")` (Antimatter.sol:132), no `decimals()` override (18dp), no
supply cap (`mint` :192-194 calls bare `_mint`), no pause, no transfer hook. Authorization is an
owner-managed set:

```solidity
function mint(address to, uint256 amount) external onlyApprovedMinters {   // :192
    _mint(to, amount);                                                     // :193
}
```

It is **redeemable** by anyone holding it, via the permissionless `annihilate` (:226-267):

```solidity
_burn(msg.sender, amount);                                    // :239  AM half burned
...
minter.mint(stable, stableAmount);                            // :251  stable half -> BACKED phUSD
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;  // :256
_phUSD.mint(recipient, amount);                               // :263  AM half -> UNBACKED phUSD
IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);         // :264
```

Line **:263** is load-bearing: it mints `amount` phUSD with **no collateral behind it**, keyed only
to the AM burned. Therefore:

> **1 AM is a bearer claim on 1e18 of unbacked phUSD.** Emitting AM is a quantifiable dilution
> liability against the phUSD collateral pool, not an opportunity cost and not a marketing spend.

**The party that bears it: every existing phUSD holder**, through a fall in the phUSD system's
collateralization ratio. The dilution is realised by an arbitrary third party (AM is freely
transferable and uncapped), so the historic "the minter cannot redeem, so over-crediting it is
inert" cushion has no analogue here.

**Distinguishing the two categories, per the run rules:** the *stablecoin* half at :251 is genuinely
backed and forwarded to a yield strategy — that half is not dilution. Only the AM half at :263 is.
An annihilator brings `N` stable and `N` AM and leaves with `2N` phUSD; their gain of `N` phUSD is
exactly the dilution imposed on the pool.

**The frozen V1 is unaffected.** `src/versions/v1/StableStakerV1.sol` still emits phUSD directly and
is hash-pinned by `FROZEN.sha256`; the vendored `FlaxToken` was verified byte-identical to the
deleted submodule at `f5300117`. The premise change is V2-only.

### 0.1 Intent mismatch (documentation vs implementation)

`docs/deferred-reward-accrual-plan.md`, the story-023 emissions note:

> "The mechanics below are **unchanged by that swap** — only the token, the identifier names
> (`accAntimatterPerShare`, `antimatterPerSecond`, `antimatterPerDay`) and the minter-authorization
> call (`setApprovedMinter` rather than `setMinter`) differ."

`CLAUDE.md` similarly frames story-023 as a token substitution. **That is accurate about the
mechanics and materially incomplete about the economics.** The accrual mechanics are indeed
unchanged; what changed is that the emitted unit stopped being unredeemable scrip and became a
bearer claim on phUSD backing. Consequences the docs do not state:

- `antimatterPerDay(token, amount)` is no longer a farm knob — it is a **phUSD monetary-policy
  instrument**. Its units are "phUSD of backing dilution per day", committed per unit *time*,
  independent of TVL attracted.
- Every historical judgement of the form "the emission cap is not violated, so nothing is at risk"
  now needs "…and the cap itself is a dilution budget" appended.

Recorded as **ECON-16-01 (Low, spec-conformance / documentation)** below.

---

## ECON-16-02 — Empty-pool emission cliff: 1 wei of stake converts a dormant, zero-cost pool into a full-rate phUSD dilution stream, capturable in full by the depositor

**Type:** mechanism design / unintended value extraction · **Preliminary severity: HIGH**
(argument for Medium recorded) · **Confidence: high** · **Contract:** `src/StableStakerV2.sol`
**Functions:** `_updatePool` :806-827, `stake` :318-339, `antimatterPerDay` :214-220

### The mechanism

Emission is time-denominated and TVL-independent, with a hard discontinuity at `totalStaked == 0`:

```solidity
if (pool.totalStaked == 0) {          // :817
    pool.lastRewardTime = block.timestamp;
    return;                           // :819  EMPTY POOL ACCRUES NOTHING
}
uint256 elapsed = block.timestamp - pool.lastRewardTime;
uint256 reward = elapsed * pool.antimatterPerSecond;                        // :822
pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;  // :824
```

`reward` at :822 does not reference `totalStaked` at all. So the pool's cost to the protocol is a
**step function of participation**: `totalStaked == 0` costs zero; `totalStaked == 1 wei` costs the
full `antimatterPerDay`. The marginal cost of switching the stream on is one wei of stake, gated
only by `require(credited > 0)` (:333) — trivially satisfied on an idle-hold pool, where
`_routeDeposit` returns the amount verbatim (`return amount; // idle hold: full credit`, :862).

The whole of that stream accrues to whoever is staked, so a sole staker captures 100 % of it
(`pending = amount * acc / ACC_PRECISION - rewardDebt`, :380).

**This is not redistribution.** In a genuinely empty pool the emission would never have existed
(:817-819). The 1-wei stake *causes* AM to be minted that otherwise would not be. That AM is a claim
on unbacked phUSD (Antimatter.sol:263). Net new dilution.

### Reachable windows — all four are ordinary operation, none is a misconfiguration

| # | Window | Why it exists |
|---|---|---|
| a | **Launch.** Between `antimatterPerDay` and the first genuine staker. | This is the documented wiring order verbatim — `CLAUDE.md`: "3. `staker.addToken(token)` for each stable, then `staker.antimatterPerDay(token, amountPerDay)`." No step defers the rate until users exist. |
| b | **Post-revival.** Between `finalizeAndReset` (:673-684, sets `poolState = Active`, `lastRewardTime = now`) and the migrator's `depositFor` re-injection. | `stake` is open the instant the pool goes Active; `finalizeAndReset` does not pause and does not zero the rate. |
| c | **Retired pool.** A pool drained by a terminal migration and never re-used. | Nothing zeroes `antimatterPerSecond` on the way out. |
| d | **Organic emptying.** All users withdraw from a live pool. | Same. |

Window (a) requires no operator error at all. Windows (c) and (d) are the *default* end-state,
because no code path resets the rate — which is precisely what ledger entry `ss9l1` already
records, at Low severity, under the now-void phUSD premise (see §3).

### Attack scenario with numbers

Take the retired-pool case (c), `antimatterPerDay(USDC, 10_000e18)` left armed:

1. Attacker observes the pool is Active, `totalStaked == 0`, `antimatterPerSecond == 10_000e18/86400
   ≈ 1.157e17`.
2. `stake(USDC, 1)` — one wei of USDC, ≈ $1e-6 of capital, plus gas.
3. Wait 90 days. `_updatePool` folds `elapsed * antimatterPerSecond = 7_776_000 × 1.157e17
   ≈ 900_000e18` and, with `totalStaked == 1`, assigns essentially all of it to the attacker.
4. `claim(USDC)` → `antimatter.mint(msg.sender, owed)` (:385) mints **900,000 AM**.
5. `annihilate(USDC, self, 900_000e18, …)`: attacker supplies 900,000 USDC, burns 900,000 AM,
   receives ≈ 900,000 backed phUSD (:264) **plus 900,000 unbacked phUSD** (:263).

**Profitability:** the attacker converts 900,000 USDC into ≈ 1,800,000 phUSD. At phUSD ≈ $1 that is
**≈ $900,000 of profit** against ~$1e-6 of principal and two transactions of gas. The constraint is
the attacker's working capital for the stablecoin half (they get it back as backed phUSD, so it is a
one-block round-trip, not a lock-up), not the size of the AM position.

**Affected parties:** all phUSD holders (backing ratio dilution). Not other stakers — the pool was
empty, so nobody else is short-changed.

Window (a) is smaller but needs zero misconfiguration: at 10,000 AM/day, a 6-hour launch-arming
window is 2,500 AM ≈ 2,500 phUSD of dilution to whoever front-runs the announcement with 1 wei.

### Severity reasoning (C4)

**High**, on the ground that the attack path is fully permissionless and free of hypotheticals, and
the enabling state (a non-zero rate on an empty pool) is the *default* rather than an exceptional
misconfiguration — no code path ever clears `antimatterPerSecond`, and window (a) arises from the
documented deployment sequence itself.

**The honest counter-argument for Medium:** every window still requires the owner to have armed a
rate against a pool with no users, which a severity-auditor may fairly characterise as "value leak
with stated assumptions and external requirements". I record it at High and flag the disagreement
rather than pre-resolving it. Under Law 3 this is squarely a **non-obvious owner footgun**: a
competent, non-malicious owner would be surprised that a pool with zero users still carries a live,
permissionlessly-triggerable dilution liability, and that the required hygiene is
`antimatterPerDay(token, 0)` on every pre-launch, drained and retired pool.

### Recommended mitigation (protocol-level, for the report writer)

Any one of: (i) zero `antimatterPerSecond` inside `finalizeAndReset` and require an explicit
re-arm — this is `ss9l1`'s existing recommendation, whose severity basis is now much stronger;
(ii) require a minimum `totalStaked` before accrual begins, or scale `reward` by
`min(totalStaked, threshold)/threshold` so a dust pool draws a dust stream; (iii) treat the rate as
arm-on-demand — set it in the same transaction that seeds the pool. (i)+(iii) together close all
four windows.

---

## ECON-16-03 — Sliced migration re-injection hands the first slice the entire emission budget of the inter-slice interval

**Type:** cross-contract incentive asymmetry · **Preliminary severity: LOW** · **Confidence: high**
**Contracts:** `src/InPlaceMigrator.sol` `migrateIn`, `src/CrossVersionMigrator.sol` `migrate`,
against `StableStakerV2.depositFor` :700-719

Both migrators re-inject users **in pages** — `migrateIn(token, start, end)` and
`migrate(token, users[])`. Each page is a separate transaction. Because the destination pool's
emission is time-denominated (:822) and TVL-independent, users re-injected in page 1 draw the
**full** `antimatterPerDay` for the entire interval before page 2 lands, despite every parked user's
principal having been equally immobilised throughout.

**Scenario.** 3 pages, each ~1/3 of a 3,000,000 USDC pool, run one per day for operational reasons
(gas, review). `antimatterPerDay = 10_000e18`.

- Day 1→2: only page-1 users staked (1,000,000). They accrue the full 10,000 AM.
  Pro-rata entitlement would have been ~3,333 AM.
- Day 2→3: pages 1+2 staked; page-1 users take 1/2 rather than 1/3.
- Net over the 3-day re-injection: page-1 users capture ≈ 18,333 AM against a fair ≈ 10,000 AM —
  an **83 % over-share, ≈ 8,333 AM ≈ 8,333 phUSD** transferred from page-3 users to page-1 users.

Page order is chosen by the owner (`start`/`end`, or the `users[]` array), not by the users, so this
is not user-exploitable — it is an unfair allocation the owner imposes without meaning to, and a
user who knows the page order can lobby for or trade on inclusion in page 1.

**Not incremental dilution.** Total AM emitted over the interval is unchanged, so unlike ECON-16-02
this is pure redistribution among legitimate users. Hence Low, not Medium.

**Mitigation:** `antimatterPerDay(token, 0)` for the duration of the re-injection and restore it once
the last page lands; or complete `migrateIn` in a single transaction. Worth adding to the migration
runbook in `CLAUDE.md`, which currently documents the page-wise re-injection without this caveat.

---

## ECON-16-04 — Retired stakers must remain approved Antimatter minters forever, against a token with no mass-revocation

**Type:** protocol-wide operational hazard / incident response · **Preliminary severity: LOW**
(argument for Medium recorded) · **Confidence: high**
**Contracts:** `src/StableStakerV2.sol` `claim` :376-388, `lib/antimatter/src/Antimatter.sol`
`setApprovedMinter` :164-168

Story-022 made the reward backlog outlive the position. `unclaimedReward` survives a full withdraw,
and `claim` is deliberately reachable with no position:

```solidity
/// @dev Succeeds for a caller with no position but a non-zero backlog (someone who fully withdrew
///      and has not claimed yet).                                       // :373-374
```

and `_exitPosition` early-returns before it could confiscate such a backlog:

```solidity
uint256 amt = info.amount;
if (amt == 0) { return 0; }                                              // :599-601
```

So after a V1→V2 or V2→V3 cross-version hop, users who had already withdrawn to zero keep an
unminted backlog **on the old staker**. Paying it requires the decommissioned staker to remain an
approved Antimatter minter and unpaused indefinitely. (The profiler records the local half of this
as LOCAL-004; the protocol-level consequence below is the Tier-2 addition.)

The consequence is a monotonically growing minter set that can never be collapsed. Antimatter's only
revocation is per-minter:

```solidity
function setApprovedMinter(address minter, bool approved) external onlyOwner {   // :164
    bool changed = approved ? _approvedMinters.add(minter) : _approvedMinters.remove(minter);
```

There is **no** equivalent of phUSD's mass revocation. `FlaxToken` has one —
`revokeAllMintPrivileges()` bumps `mintVersion`, invalidating every minter at once (FlaxToken.sol
:363, checked at :333-344). Story-023 therefore moved V2's emissions onto a token with **strictly
weaker incident response**, at the same moment the emitted unit became redeemable against phUSD
backing. Every retired staker is a standing, individually-revocable mint surface on a token that
mints unbacked phUSD on redemption.

**Severity.** Low as filed: no live leak, and the exposure is bounded by each retired staker's
accrued backlog, which is itself capped by the emission invariant. The argument for Medium is
incident-response availability: a compromise requiring mass revocation must enumerate `n` minters
across `n` transactions, and `approvedMinters()` (:186-188) makes enumeration possible but not
atomic. I file Low.

**Mitigation:** add a `mintVersion`-style mass revocation to Antimatter (out of this repo's scope but
in the same owner's control); or give `StableStakerV2` an owner-callable terminal sweep that mints
the residual backlogs in one batch so a retired staker's minter role can be dropped immediately.

---

## ECON-16-01 — story-023 is documented as a token substitution with unchanged economics

**Type:** intent verification · **Preliminary severity: LOW (spec-conformance)** · **Confidence: high**

Detailed in §0.1 above. Documentation quote (`docs/deferred-reward-accrual-plan.md`, emissions-token
note): *"The mechanics below are unchanged by that swap — only the token, the identifier names … and
the minter-authorization call … differ."* Actual behaviour: `Antimatter.annihilate` :263 mints
unbacked phUSD 1:1 against burned AM, so the emission became a claim on protocol backing.
`CLAUDE.md`'s "Core safety invariant" section still frames the emission cap purely as an accounting
bound ("No sequence of user actions can accrue more than `antimatterPerDay`") without stating that
the cap is now a **dilution budget denominated in phUSD backing**. Recommend both documents state
the phUSD-dilution character of AM explicitly, since it is the premise every future severity
judgement on this repo depends on.

---

## 1. Negative results — questions asked, answered NO, with the verification

Recorded per Law 1 so a future run does not have to re-derive them.

### 1.1 Deferred accrual (story-022) creates no timing asymmetry — CLEAN

- **Flash-stake / same-block stake-then-claim earns zero.** `stake` :320 calls `_updatePool`, which
  returns immediately on `block.timestamp <= pool.lastRewardTime` (:814-816), so `acc` is unchanged;
  `stake` then sets `rewardDebt = user.amount * acc / ACC_PRECISION` (:336) at that same `acc`. A
  same-block `claim` computes `pending = user.amount * acc / ACC_PRECISION - rewardDebt == 0` (:380)
  and reverts on `require(owed > 0)` (:382).
- **Staking just before a large accrual window closes gains nothing retroactively.** Ordering in
  `stake` is `_updatePool` (:320) → `_settle` (:322) → `user.amount += credited` (:334). The elapsed
  window is folded into `acc` *before* the new principal joins `totalStaked`, so it is distributed
  to the pre-existing cohort only. Same ordering in `depositFor` (:706 → :708 → :714).
- **No double-booking of the same pending.** Every site that increments `unclaimedReward`
  (`_settle` :836, `withdraw` :363) re-bases `rewardDebt` to the current `acc` in the same
  transaction (:336, :356), and both mint sites (`claim` :383-384, `_exitPosition` :613-616) zero
  the slot and re-base together.
- **Deferral does not let a backlog be re-rated.** `unclaimedReward` is a settled nominal quantity;
  `antimatterPerDay` (:214-220) settles the pool via `_updatePool` before writing the new rate, so a
  rate change is never retroactive in either direction.

Conclusion: story-022 is economically neutral. It moves *when* AM is minted, never *how much*.

### 1.2 V1→V2 migration boundary — no double-count, no user-timeable arbitrage

- The reward legs are disjoint in time. `_exitPosition` mints the departing user's whole V1 backlog
  at exit (`owed = unclaimedReward + pending`, :611-612, minted :620) and zeroes the position; V2
  accrual for that user starts at `depositFor`, which sets
  `info.rewardDebt = info.amount * accAntimatterPerShare / ACC_PRECISION` (:716) at the *current*
  index, so no V2 emission predating the deposit is claimable.
- The denominations differ by design and correctly: the V1 leg mints phUSD, the V2 leg accrues AM.
  `CrossVersionMigrator` never imports either token (profile CVM value-flow section), so it cannot
  conflate them. This asymmetry is now documented at `CrossVersionMigrator.sol` :35-36 and :55-57.
- **No user-side timing control.** `initiateMigration`, `migrate`/`batchMigrate` and `depositFor` are
  all `onlyOwner`/`onlyMigrator`; a user cannot elect to be migrated at a chosen moment. A user who
  self-exits V1 ahead of the migration simply gets their V1 reward minted normally — no advantage.
- **A user staked on both stakers is not double-credited.** `_exitPosition` zeroes the V1 position
  before the migrator credits V2 (:614-618, credit forwarded by the caller under CEI), and the V2
  `depositFor` adds to their existing position at a re-based `rewardDebt`.

The one real boundary effect is the page-ordering unfairness, filed separately as ECON-16-03.

### 1.3 Decimal mismatch (6dp stable vs 18dp AM) — CLEAN, does not reproduce the sibling Medium

The sibling `stable-yield-accumulator` M-01 was a decimal **fail-open** producing zero payment.
It does not reproduce here, for two independent reasons.

**(a) `StableStakerV2` never reads or assumes decimals.** `grep -n "decimals" src/StableStakerV2.sol`
returns nothing. The staked-token decimals cancel in the pro-rata:

```solidity
pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;   // :824
uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;  // :380
```

`pending ≈ reward × (user.amount / pool.totalStaked)`. `user.amount` and `pool.totalStaked` are both
in the staked token's decimals and appear only as a ratio; `reward` is in AM's 18dp and passes
through unscaled. The result is correctly 18dp AM regardless of whether the stable is 6dp or 18dp.
No conversion exists, so there is nothing to fail open.

**(b) Precision is comfortable, and 6dp is the *favourable* direction.** For USDC, a smaller
`totalStaked` divisor makes the `acc` increment *larger*, not smaller. Worst case: 100,000,000 USDC
(`totalStaked = 1e14`) at 10,000 AM/day (`antimatterPerSecond ≈ 1.157e17`), 1-second window →
`acc += 1.157e17 × 1e18 / 1e14 = 1.157e21`. No truncation to zero. Overflow headroom is likewise
ample: a year at that rate leaves `acc ≈ 3.6e28` and `user.amount × acc ≈ 3.6e42`, against a
`uint256` ceiling of ~1.15e77.

**(c) The one decimal conversion in the chain fails CLOSED, not open.**
`Antimatter.toStableAmount` (:283-304) validates on four axes and reverts on each:
`if (decimals > 18) revert UnsupportedDecimals` :289; `if (!ok || data.length != 32) revert
DecimalsUnavailable` :296; `if (actualDecimals != decimals) revert DecimalsMismatch` :298; and
`if (stableAmount * scale != amount) revert AmountNotRepresentable` :302. Residual: AM amounts that
are not an exact multiple of `10**(18-decimals)` — 1e12 for USDC — cannot be annihilated at all, so
sub-1e12 AM dust is permanently unredeemable. Immaterial and located in an out-of-scope contract;
noted for completeness only.

### 1.4 Rounding-direction checklist — CLEAN, all legs favour the protocol

Confirming the profiler's `roundingDirection` at the system level, on both legs of each round-trip:

| Operation | Site | Direction | Verdict |
|---|---|---|---|
| Emission rate | `perSecond = amountPerDay / SECONDS_PER_DAY` :216 | floor | protocol pays ≤ budget ✓ |
| Index accrual | `acc += reward * 1e18 / totalStaked` :824 | floor | under-accrues ✓ (the checklist's "reward-per-share accrual rounds down") |
| Pending owed to user | `amount * acc / 1e18 - rewardDebt` :353/380/609 | floor | user receives ≤ fair ✓ |
| Reward-debt baseline | `amount * acc / 1e18` :336/356/384/716 | floor | matches the pending formula exactly, so the two truncations cancel rather than compound ✓ |
| Migration credit | `credit = (amt * S) / P` :605, `S = min(R, P)` :604 | floor | user receives ≤ fair; residual dust stays in the staker as protocol-owned value ✓ |

**Composed round-trip:** stake `x` then immediately withdraw `x`. `stake` sets
`rewardDebt = amount × acc / 1e18` and `withdraw` computes `pending` against that same `acc` with
the same formula, giving exactly zero — the user ends with ≤ their starting position, never more.
No symmetric/banker's rounding anywhere; no site rounds up. There is no leg on which the user's
receipt is rounded up and none on which their obligation is rounded down. **Nothing to report.**

Note the emission cap holds independently of rounding: `_updatePool` folds exactly
`elapsed × antimatterPerSecond` per call and the floor at :824 only ever discards, so
`Σ minted ≤ Σ accrued ≤ cap`. ECON-16-02 is not a cap violation — it is a statement about the cap's
*cost basis*, which is a different question the cap invariant does not answer.

### 1.5 Deliberately NOT filed

- **Dust-stake grief of `setYieldStrategy`'s empty-pool gate.** A 1-wei stake between
  `finalizeAndReset` and `setYieldStrategy` flips `require(poolInfo[token].totalStaked == 0,
  "StableStaker: pool not empty")` (:258) and forces a fresh terminal-migration cycle. This is
  **already ledger entry `787e9faceb…` / ss10l1 (L-01, submitted-qa)** and is not re-filed. Its
  severity basis is unchanged by story-023 — it is an availability nuisance with no dilution leg,
  and recovery via a re-run migration (or an atomic owner batch) is intact.
- **Sub-86400-wei/day budget floors the rate to zero.** Already ledger entry `d47619d29f…`; the
  arithmetic is identical after the phUSD→AM rename and needs only a title refresh.
- **Terminal migration has no mint-free escape hatch** (the profiler's LOCAL-002). Already ledger
  entry `e4567dc343…`, closed **wont-fix as intended design** on 2026-06-08. The profiler
  independently rediscovered it; it should reconcile to that entry, not be filed as new. Worth
  noting for the sanitizer that story-022's robustness claim in `CLAUDE.md` ("a revoked minter role
  … can no longer brick a principal path") is over-broad exactly where `e4567dc343` says it is, so
  the wont-fix rationale still applies but the *documentation* should be narrowed to
  "`stake`/`withdraw`/`emergencyWithdraw`". That documentation half is a fair QA line if the report
  writer wants one; I have not filed it separately.
- **No "malicious owner" vectors** are filed anywhere in this scan (Law 3).

---

## 2. Emission cap — the actual bound, and paths that could exceed it

Answering the run's question 2 explicitly. **The cap holds; no out-of-band mint path exists.**

**The bound.** Over any window `[t0, t1]` for a token, total AM the staker can mint is

```
Σ over Active sub-windows of  (elapsed × antimatterPerSecond)   where totalStaked > 0
```

with `antimatterPerSecond = antimatterPerDay / 86400` (:216). Formally
`Σ_users unclaimedReward + Σ minted ≤ Σ elapsed × antimatterPerSecond`. Verified by:

- **Exactly one writer of the index** — `pool.accAntimatterPerShare +=` appears once, at :824
  (`grep -c` == 1). It is `+=` only and `finalizeAndReset` does not reset it (:679-681 clear
  `migrationInfo` and `lastRewardTime` only), so it is monotonic non-decreasing.
- **Exactly two mint sites** — `claim` :385 and `_exitPosition` :620. Both pay
  `unclaimedReward + pending` and zero the slot in the same transaction. `_settle` (:832-839) writes
  only `unclaimedReward` and never calls Antimatter.
- **Accrual is frozen while Migrating** — `_updatePool` returns at :810-812 on
  `poolState != PoolState.Active`, and `_pendingReward` :748 applies the identical guard, so views
  and state agree.
- **The migration gap is never retro-accrued** — `finalizeAndReset` :680 sets
  `lastRewardTime = block.timestamp`, belt-and-braces over the `totalStaked == 0` fast-forward
  at :817-819.

**Paths checked for out-of-band mint, all negative:**

| Path | Verdict |
|---|---|
| `emergencyWithdraw` :394-411 | Never mints; zeroes `unclaimedReward` (:404) — strictly reduces liability. Does mutate `totalStaked` without `_updatePool` first (profiler LOCAL-001), which **redistributes** the trailing window to survivors but folds exactly `elapsed × rate` regardless, so the cap is untouched. |
| `depositFor` :700-719 | `_updatePool` then `_settle` then re-based `rewardDebt` (:716). Cannot mint; cannot claim pre-deposit emissions. |
| Re-staking after a full exit | `rewardDebt` is zeroed on every path that zeroes `amount` (:356, :402, :615), and `0 × acc / 1e18 == 0`, so the subtraction at :380 cannot underflow into a spurious credit. |
| `batchMigrate` / `userMigrate` | Mint through `_exitPosition` only, once per position, `owed` zeroed before the mint (:616 before :620). |
| Migration round-trip (out then in) | Emission frozen throughout Migrating; `lastRewardTime` fast-forwarded at revival. The only leakage is the page-ordering share shift, ECON-16-03 — a redistribution, not extra mint. |

**The caveat that matters.** The cap bounds *quantity*, and it always did. What story-023 changed is
the cap's **denomination**: it is now a bound on how much unbacked phUSD the staker can cause to be
issued. ECON-16-02 does not break the cap — it shows the cap can be made to bind at full rate
against a pool holding one wei, i.e. the *cost* is bounded but the *value delivered for that cost*
is not bounded below.

---

## 3. Prior suppressions resting on the phUSD premise — VOID for V2, flagged for reconciliation

**Not re-filed.** Listed by fingerprint and root cause for the sanitizer and the human to reconcile
against the ledger. All are V2-path entries; the frozen V1 keeps emitting phUSD, so no V1 finding is
affected.

| Ledger entry | Status | The now-void rationale (quoted) | Re-weigh |
|---|---|---|---|
| **`ss9l1-finalizeAndReset-revival-stale-emission-rate`** (`ss9l1`, Low/QA, **open**) — "finalizeAndReset revives pool without resetting phusdPerSecond / re-wiring yieldStrategy (revival over-emission footgun)" | open | *"The per-second emission CAP is NOT violated and **no principal is at risk**; the hazard is that a non-obvious owner expectation … does not hold."* Impact field: *"QA / Law-3 non-obvious owner-config footgun. Emission cap not violated, **no principal is at risk**."* | **VOID as a Low.** "No principal at risk" was true when the emission was unredeemable phUSD scrip. It is now false: the stale rate on a revived empty pool is the direct enabler of ECON-16-02 window (b)/(c). This entry is the **same root cause as ECON-16-02** and should be re-weighed upward and merged with it rather than carried at QA. Its recommendation ("zero `phusdPerSecond` on revival") is also ECON-16-02's primary mitigation. |
| **`86fcf00ef786f496…`** (`ss12l3`, L-03, **qa, open**) — "Revived-pool permissionless-stake window before migrateIn (exploit refuted; emission-dilution only)" | open | *"Sole residual: **emission-share dilution (normal MasterChef TVL dilution of in-motion/unmatured yield, not a leak)**."* Impact: *"**None to principal; emission-dilution only.**"* | **VOID.** The downgrade to QA rests entirely on "emission dilution is not a leak". Under Antimatter that inference is exactly inverted — emission dilution *is* the leak, realised at `Antimatter.sol:263`. This entry describes ECON-16-02 window (b) precisely and its refutation of the *theft* angle remains correct; only the "so the residual is harmless" step fails. Re-weigh, or merge into ECON-16-02. |
| Memory note **`minter-cushion-socialized-losses-intended`** (*"minters can't redeem so there's no user-vs-user vector"*) | — | Premise: the reward minter has no redemption path. | **VOID for V2's reward leg.** AM holders redeem permissionlessly via `annihilate`. Still valid for the phUSD *minter* role generally and for frozen V1. |
| Memory note **`externally-derived-yield-opportunity-cost-not-loss`** (*"over-payment is misallocation/marketing spend, never economic loss"*) | — | Premise: emissions are funded by externally-derived yield on protocol-owned capital. | **VOID for V2's reward leg.** AM emissions are not funded by external yield; they are freshly minted claims on phUSD backing (:263). Still valid for the Phoenix pots it was written about. |
| Memory note **`phstaging-ys12-minter-immune`** (*"phUSD minter immune to over-credit — decoupled mint, no redeem"*) | — | Same premise. | **Unaffected as written** (it is about the phUSD minter), but the reasoning pattern must not be transplanted to AM. Flagged so it is not cited by analogy. |

**Reconciliation guidance.** `ss9l1` and `86fcf00ef7…` are both `open` (not `acknowledged`), so
neither is suppressed and both will be rescanned — the Law-1 exposure is bounded. The action needed
is a **severity re-weigh with a recorded reason**, not a re-file: their fingerprints must be
preserved, and per the disclosure rule the re-weigh should name the void premise explicitly rather
than silently overriding the original QA rationale. If the human prefers to keep them at QA and
carry ECON-16-02 as the single High, that is coherent too — but the two QA entries' *stated
rationales* must then be corrected, because as written they instruct a future reader that emission
dilution is harmless.

---

## 4. Assumption gaps and external dependencies

- **`lib/antimatter` is not in this run's scope** and is pinned as a nested dependency. Every
  economic conclusion here depends on `Antimatter.annihilate` :226-267 and specifically the unbacked
  mint at :263. If that contract changes, ECON-16-02's severity moves with it. A future run should
  re-confirm :263 before relying on this scan.
- **phUSD's peg and the `PhusdStableMinter` exchange rate** determine the dollar value of the
  dilution. I have assumed phUSD ≈ $1; the AM half's value is `amount` phUSD regardless of the
  stable half's rate, so the dilution *quantity* is rate-independent even though its dollar value is
  not.
- **`IYieldStrategy` behaviour** is imported from `reflax-yield-vault` (profiler P11, unverified
  from this repo). ECON-16-02's 1-wei stake assumes an idle-hold pool or a strategy that credits
  1 wei; a strategy that rounds a 1-wei deposit to zero credit would trip
  `require(credited > 0)` (:333) and raise the attack's entry cost — but only to the strategy's
  minimum credit, which is still negligible against a multi-day emission stream. It does not change
  the finding, only the size of the dust.
- **The launch-window exposure (a)** depends on operational sequencing that is outside this repo;
  the `phStaging` deployment scripts are where it would actually be closed or left open, and this is
  the same class as the already-recorded pause obligation on `2b9a89d29c` (M-01, wont-fix
  *"because the mitigation is OPERATIONAL rather than a code change, and is OUT OF SCOPE FOR THIS
  REPO"*). ECON-16-02 differs in that a code-level fix **is** available in this repo (zero the rate
  on revival / gate accrual on a minimum stake), so it should not inherit that wont-fix rationale.
