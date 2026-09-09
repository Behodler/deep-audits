# Tier-2 code scan — stable-staker run-16 (REGRESSION)

Source: `/home/justin/code/audits/lib/stable-staker` @ `fa06de5`
Range scanned: `2146428..fa06de5` (stories 022 / 023 / 024)
Profiles consumed: `StableStakerV2.profile.md`, `Migrators.profile.md`, `Antimatter.context.md`, `FlaxToken.vendor.profile.md`

Executable diff in range: `src/StableStakerV2.sol` (168 lines), `src/interfaces/IAntimatter.sol` (new),
`src/interfaces/IStableStakerMigratable.sol` (1 line). `CrossVersionMigrator.sol` and
`InPlaceMigrator.sol` are **NatSpec-only** — reconciled below, not re-scanned.
`src/versions/v1/**` is **additive only** (the vendored pair); the frozen V1 `.sol` files are untouched.

---

## Findings

### CODE-001 — Terminal migration is the only principal exit still coupled to Antimatter minting; a mint failure traps 100% of a pool's principal
**Severity (preliminary): Medium** · type: cross-contract availability / DoS · confidence: **high**
`src/StableStakerV2.sol` — line **620**, block **596-623** (`_exitPosition`), gates at **347**, **396**, **578**, **675-677**
Confirms and deepens profiler `LOCAL-002`.

Story-022's whole thesis is that principal handling no longer depends on the reward token. The code
says so in two places:

```solidity
// src/StableStakerV2.sol:387-390  (emergencyWithdraw NatSpec)
 *         the live pending AND the settled-but-unminted {unclaimedReward} backlog. Works while
 *         paused and never mints, so a broken mint path can never trap principal.

// src/StableStakerV2.sol:828-830  (_settle NatSpec)
/// @dev Book any outstanding pending reward for an existing position to {unclaimedReward}, where
///      {claim} will mint it. Never calls Antimatter, so a revoked minter role cannot brick the
///      principal paths that reach here.
```

That holds for `stake` / `withdraw` / `emergencyWithdraw`. It does **not** hold for the terminal-migration
exit, which still mints inline:

```solidity
// src/StableStakerV2.sol:609-622  (_exitPosition)
uint256 pending = (amt * pool.accAntimatterPerShare) / ACC_PRECISION - info.rewardDebt;
uint256 owed = unclaimedReward[token][account] + pending;

info.amount = 0;
info.rewardDebt = 0;
unclaimedReward[token][account] = 0;
pool.totalStaked -= amt;
_stakers[token].remove(account);

if (owed > 0) {
    antimatter.mint(account, owed);     // :620  <-- the coupling
}
```

`_exitPosition` is the **only** way out of a pool in `Migrating`, because every other principal door
requires `Active`:

```solidity
// :347   withdraw
require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
// :396   emergencyWithdraw
require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
```

**Failure scenario (state → outcome).** Pool P is `Migrating` with N users, each with `owed > 0`
(guaranteed whenever `antimatterPerSecond > 0` over the pre-migration window). `Antimatter.mint`
then starts reverting — the realistic trigger is the operator calling
`Antimatter.setApprovedMinter(staker, false)`, either as incident response (the Antimatter context
notes there is **no** phUSD-style `revokeAllMintPrivileges`, so an incident forces a per-minter
enumeration and this staker is one of them) or as the natural decommissioning order
*"retire the old staker's mint rights, then drain it"*. Result:

- `userMigrate` (:578) reverts for every affected user → no self-rescue.
- `batchMigrate` (:566-583) reverts on the **first** such user in the loop → the migrator cannot page
  around it, since the failing user is in `_stakers` and `finalizeAndReset` counts the whole set.
- `emergencyWithdraw` / `withdraw` are gated `Active` → no hatch.
- `finalizeAndReset` (:675-677) requires `stakerCount == 0 && totalStaked == 0` → the pool can never
  return to `Active`.
- `rescueERC20` (:911-913) is exactly tight during migration: `yieldStrategy == address(0)`, so
  `reserved = totalStaked`, and `bal = R − Σcredits_paid ≤ P − Σp_paid = reserved`. Nothing is
  rescuable. (Profiler P10, re-verified.)

100% of the pool's remaining principal is frozen for as long as the mint reverts.

**Remedy enumeration (required before claiming permanence).** Recoverable remedies:
1. `Antimatter.setApprovedMinter(staker, true)` — restores the mint and unblocks migration. This is
   the remedy in the common case and is why this is Medium, not High.
2. Setting `antimatterPerDay(token, 0)` does **not** help: `owed` is already accrued into
   `accAntimatterPerShare` / `unclaimedReward` and the rate change is not retroactive.

Non-recoverable case: `antimatter` is **`immutable`** —
```solidity
// src/StableStakerV2.sol:60
IAntimatter public immutable antimatter;
```
There is no setter (`grep "antimatter ="` → constructor only, :196). If the Antimatter deployment
itself is retired, its owner key is lost, or a replacement AM token is deployed, the trapped pool is
**permanently** unrecoverable — the staker cannot be repointed, cannot be reset, and cannot be
rescued.

**Why this is in scope under Law 3 (owner footgun, not "malicious owner").** The harmful action is
revoking a minter role — a routine, obviously-safe-looking operation whose consequence (freezing an
unrelated pool's *principal*) is not visible from Antimatter, is not visible from `emergencyWithdraw`,
and is actively contradicted by this contract's own NatSpec. A competent non-malicious operator would
be surprised. Per the in-source-NatSpec rule, docs that self-certify exhaustively and are wrong
raise severity rather than suppress.

**Recommended mitigation.** Mirror `claim`'s shape: leave the amount booked instead of minting.
Replace :619-621 with a booking that survives the exit, e.g. keep `unclaimedReward[token][account] = owed`
(do not zero it) and drop the inline mint, letting the user call `claim` afterwards — `claim` is not
`poolState`-gated (profiler P12) and already handles a zero position. Principal then leaves
unconditionally. If the inline mint must stay, wrap it in a `try/catch` that falls back to booking.

---

### CODE-002 — `emergencyWithdraw` shrinks `totalStaked` without settling the pool, recycling forfeited emissions to survivors
**Severity (preliminary): Low** · type: accounting / reward redistribution · confidence: **high**
`src/StableStakerV2.sol` — line **405**, block **394-411**
Confirms profiler `LOCAL-001`. **The profiler's "emission cap is NOT broken" claim is independently verified below.**

```solidity
// src/StableStakerV2.sol:394-411
function emergencyWithdraw(address token) external nonReentrant {
    require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
    UserInfo storage user = userInfo[token][msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "StableStaker: nothing staked");
    user.amount = 0;
    user.rewardDebt = 0;
    unclaimedReward[token][msg.sender] = 0;
    poolInfo[token].totalStaked -= amount;      // :405  <-- no _updatePool first
    _stakers[token].remove(msg.sender);
    uint256 payout = _routeExit(token, amount, false);
    IERC20(token).safeTransfer(msg.sender, payout);
    emit EmergencyWithdrawn(token, msg.sender, amount);
}
```

`totalStaked` has exactly four mutation sites — :335 (`stake`), :355 (`withdraw`), :405
(`emergencyWithdraw`), :616 (`_exitPosition`) — and :405 is the only one not preceded by
`_updatePool` (call sites: :215, :327, :351, :378, :471, :707). :616 is safe by a different argument:
it runs only while `Migrating`, where `_updatePool` is a deliberate no-op (:809-811) and the index
was already settled by `initiateMigration` (:471).

**Cap verification (I re-derived this rather than trusting it).** Let the outstanding claim be
`C = Σ_i (amount_i·acc/PREC − rewardDebt_i) + Σ_i unclaimed_i`. At :402-405 the leaver's three terms
all go to zero and `acc` is untouched, so `C` strictly *decreases*. The next `_updatePool` adds
`Δacc = floor(reward·PREC / totalStaked)` where `totalStaked = Σ_i amount_i` over the *survivors*, so
the added claim is `totalStaked·Δacc/PREC ≤ reward = elapsed·antimatterPerSecond`. The per-window
emission cap therefore holds. **Confirmed: this is redistribution, not over-emission.**

**Concrete effect.** Pool: honest H = 1,000,000 units, leaver A = 9,000,000 units, `lastRewardTime = T0`,
rate `r`. At `T0+D` A calls `emergencyWithdraw`. No settle, so at the next `_updatePool` the whole
window `D` accrues against `totalStaked = H`: H's pending jumps from `0.1·D·r` to `1.0·D·r`
discontinuously.

**Exploitability: none.** I tried to build a profitable version and it does not exist. The leaver
forfeits both the live pending *and* the `unclaimedReward` backlog (:404), and can only reduce
*their own* contribution to `totalStaked` — post-exit `totalStaked ≥` the honest float, so a paired
dust address captures `dust/(H+dust) ≈ 0`. In the degenerate case where the attacker is the only
staker, both addresses are theirs and the total is unchanged. Every variant is a donation to honest
survivors. **Not an attack; a Low.**

**Why it is still worth reporting.** (a) Under the run-16 premise change, emitted AM is a real
dilution liability (1 AM = a bearer claim on 1e18 *unbacked* phUSD via `Antimatter.annihilate`), so
"forfeited reward is recycled and minted" vs "forfeited reward is never minted" is a genuine, if
bounded, difference in realized dilution — and the NatSpec's "forfeiting ALL reward" does not say
which. (b) `pendingReward` / `claimableReward` step discontinuously for survivors with no event,
which any integrator polling those views will see as an unexplained jump.

**Recommended mitigation.** Add `_updatePool(token);` as the first statement of `emergencyWithdraw`
(before reading `user.amount`). Note this makes the hatch depend on nothing external — `_updatePool`
does not touch Antimatter — so it does not reintroduce CODE-001.

---

### CODE-003 — `pendingReward` reads **zero** for a fully-owed user after any stake / withdraw / depositFor
**Severity (preliminary): Low** · type: integration hazard / spec deviation · confidence: **high**
`src/StableStakerV2.sol` — line **731**, block **722-754**; interacts with `_settle` :832-839

Story-022 kept `pendingReward`'s ABI and *changed its meaning*: it is now the live projection only,
deliberately excluding the settled backlog.

```solidity
// src/StableStakerV2.sol:745-754
function _pendingReward(address token, address account) internal view returns (uint256) {
    ...
    UserInfo storage user = userInfo[token][account];
    return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;
}
```

Because `_settle` moves the pending into `unclaimedReward` **and** the callers immediately re-base
`rewardDebt`:

```solidity
// src/StableStakerV2.sol:332-336  (stake)
_settle(token, msg.sender, user, pool);
...
user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;
```

**Failure scenario.** User stakes 100 at `t0`; at `t1` `pendingReward` returns `P > 0`. The user
tops up by 1 unit. `_settle` books `P` into `unclaimedReward`, then `rewardDebt` is re-based to
`101·acc/PREC`, so `pendingReward` now returns `101·acc/PREC − 101·acc/PREC = 0` while
`claimableReward` correctly returns `P`. **A user who tops up sees their displayed pending reward
drop to zero.** Same for any `withdraw` (:362) and any `depositFor` (:709).

No value is lost — `claim` (:381) pays `unclaimedReward + pending`. This is a display / integration
defect, and it is load-bearing for callers that *branch* on the value. A live example exists in the
sibling repo: `lib/phoenix-phase-2-staging/script/interactions/ClaimWithdrawStableStaker.s.sol:57-63`
does

```solidity
uint256 pending = staker.pendingReward(dolaAddr, deployer);
...
require(pending > 0, "no reward accrued - did time advance via evm_increaseTime?");
```

which aborts falsely on any V2 pool where the user staked more than once. (That script currently
targets V1/phUSD, so this is a **cross-repo watch item for the next `/audit-script` on phStaging**,
not a stable-staker finding in itself.)

**Recommended mitigation.** Either point integrators at `claimableReward` explicitly in the
`pendingReward` NatSpec's first line (it is currently buried in `@dev`), or — better — accept the ABI
break on V2 and make `pendingReward` return the full owed figure, since V2 is a new deployment and
the "must match frozen V1 byte-for-byte" argument only binds a caller that genuinely reads both
versions through one interface.

---

### CODE-004 — `depositFor` has no zero-address recipient guard; the consequence is an unfixable `Migrating` brick
**Severity (preliminary): Low (defensive hardening)** · type: input validation → permanent DoS · confidence: **medium** (mechanism high, reachability blocked today)
`src/StableStakerV2.sol` — line **695**, block **694-719**

```solidity
// src/StableStakerV2.sol:702-717  (the only require()s in depositFor)
require(amount > 0, "StableStaker: amount=0");
require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
...
require(credited > 0, "StableStaker: nothing credited");
...
_stakers[token].add(user);
```

There is no `require(user != address(0))`. If a migrator ever credits `address(0)`:

- `_stakers[token]` gains `address(0)` permanently — `address(0)` can never call `userMigrate`
  (:576) or `withdraw`/`emergencyWithdraw` to remove itself.
- On the next `initiateMigration`, `batchMigrate` including `address(0)` calls
  `_exitPosition(token, address(0))`; once `owed > 0`, `antimatter.mint(address(0), owed)` (:620)
  reverts inside OZ `ERC20._mint` with `ERC20InvalidReceiver(address(0))`.
- Excluding it from the batch does not help: `finalizeAndReset` (:675-676) requires
  `_stakers[token].length() == 0`. The pool is stuck in `Migrating` forever, and by the same
  `reserved = totalStaked` arithmetic as CODE-001 the residual principal is not rescuable.

**Reachability today: blocked.** `depositFor` is `onlyMigrator`, and both shipped migrators skip
zero-credit users before calling it — `CrossVersionMigrator.migrate` :176-180
(`if (amounts[i] > 0)`) and `InPlaceMigrator.migrateOut` :170-179 (`if (amt > 0)`), and
`_exitPosition` returns 0 for an empty `address(0)` position (:599-601). So `address(0)` cannot be
credited through either. I am filing this as hardening rather than a live bug: the guard is one line,
the failure mode is unfixable-by-construction (`antimatter` is `immutable`), and `migrator` is an
owner-settable pointer, so the protection currently lives entirely outside the contract that suffers
the consequence.

**Recommended mitigation.** `require(user != address(0), "StableStaker: zero user");` in `depositFor`.
Optionally also skip rather than revert when `owed > 0 && account == address(0)` in `_exitPosition`
— though CODE-001's booking fix subsumes that.

---

### CODE-005 — Two `FlaxToken` artifacts with the same contract name in one build, with no CI pin on the vendored copy
**Severity (preliminary): QA** · type: build hazard / silent-drift · confidence: **high**
`remappings.txt:3` and `:7`; `src/versions/v1/vendor/FlaxToken.sol` (new)
Reconciles profiler `LOCAL-V01`; the vendoring itself is byte-identical (profiler VERIFIED), so this
is the only vendoring-created problem.

`flax-token/` → `src/versions/v1/vendor/`, `@phUSD/` → `lib/antimatter/lib/flax-token-v2/src/`. Both
are commit `f5300117` today, so `forge build` emits two same-named `FlaxToken` artifacts from
different paths. Two consequences:

1. Artifact-by-name resolution (`vm.getCode("FlaxToken.sol")`, `deployCode("FlaxToken")`) becomes
   ambiguous. I grepped the first-party tree and found **no** such call site today
   (`grep -rn 'getCode("\|deployCode("' --include=*.sol` returns only `lib/forge-std` self-tests), so
   nothing breaks now — but any future script or a downstream repo consuming these artifacts inherits
   the ambiguity.
2. A future `lib/antimatter` submodule bump silently drifts the two copies apart with no check.
   `.github/scripts/check-migration-surface.sh` asserts `FROZEN.sha256` holds exactly two entries and
   deliberately does not pin the vendored pair.

**Recommended mitigation.** Add a CI assertion that `src/versions/v1/vendor/{FlaxToken,IFlax}.sol`
hash-match the `@phUSD/` copies (or pin their hashes outright), so a submodule bump fails loudly.

---

## Reentrancy-class checklist (mandatory walk — all rows cleared, with reasons)

The staked token is arbitrary (`addToken` takes any address), so an inbound-hook token is in scope.

| Class | Verdict | Reason |
|---|---|---|
| Classic single-fn | **cleared** | Every value-handling entry point is `nonReentrant` and strict-CEI. `withdraw` :353-366 updates `user.amount`, `totalStaked`, `rewardDebt`, `unclaimedReward` and removes from `_stakers` **before** `_routeExit`/`safeTransfer` (:365-366). `userMigrate` :578-581 zeroes inside `_exitPosition` before the transfer. |
| Cross-contract A→B→A | **cleared** | The only external callees are `IERC20(token)`, `IYieldStrategy`, and `antimatter.mint`. Every A-side function reachable from a re-entry is `nonReentrant` on the same lock: `stake`, `withdraw`, `claim`, `emergencyWithdraw`, `userMigrate`, `batchMigrate`, `depositFor`, `initiateMigration`, `setYieldStrategy`. |
| Cross-function (sibling) | **cleared** | OZ `ReentrancyGuard` is **contract-wide**, not per-function, so the whole guarded set shares one lock. The unguarded functions are `addToken`, `setMigrator`, `setPauser`, `antimatterPerDay`, `pause`/`unpause`, `finalizeAndReset`, `rescueERC20` — all `onlyOwner`/`onlyPauser` and none reachable from a token or strategy callback unless that callee *is* the owner. |
| **Read-only reentrancy** | **cleared, with the window named** | External views: `pendingReward`, `claimableReward`, `unclaimedReward`, `poolInfo`, `userInfo`, `poolState`, `migrationInfo`, `withdrawDisabled`, `getStakers[Range]`, `stakerCount`. None is a price/exchange-rate oracle (no share price, no `totalAssets`, no NAV — `totalStaked` is a raw principal counter). Two transient windows exist and neither is consumable: **(a)** in `stake`/`depositFor`, `_pullToken` (:844, external `transferFrom`) and `_routeDeposit` (:867, `strategy.deposit`) run **before** `user.amount`/`totalStaked` are incremented (:334-335, :714-715), so a hook sees the contract's balance already raised while `totalStaked` lags. The only reader of that pair is `rescueERC20`'s `reserved` guard (:911), which is `onlyOwner` and errs *conservatively* in this window (`bal` is high, `reserved` low → more rescuable, but bounded by the fact that the extra `bal` is the in-flight deposit and the owner is trusted for knowing actions). **(b)** in `batchMigrate`, `antimatter.mint` (:620) fires mid-loop with users 0..i already zeroed but their aggregate still un-transferred; `Antimatter` is a plain OZ ERC20 with **no** hooks (profiler-verified), so no callback exists there. |
| ERC721 `onERC721Received` | **N/A** | No NFT surface — no `_safeMint`, `safeTransferFrom`, or `IERC721` import in `src/`. |
| ERC1155 receive hooks | **N/A** | No ERC1155 surface. |
| ERC777 `tokensReceived` / `tokensToSend` | **cleared** | An ERC777 staked token fires an inbound hook inside `_pullToken`'s `safeTransferFrom` and inside every outbound `safeTransfer`. All such call sites sit inside `nonReentrant` functions, and the outbound ones are last-statement CEI (:366, :411, :580, :583). The one non-`nonReentrant` transfer is `rescueERC20` :914, which is `onlyOwner`, is the final statement, and writes no state after it. |

## Cross-contract paths examined and cleared (no finding)

- **Double-mint across `claim` / `_exitPosition`.** `claim` (:378-386) is **not** `poolState`-gated, so a
  migrating user can `claim` first. It re-bases `rewardDebt = amount·acc/PREC` and zeroes
  `unclaimedReward`; `_exitPosition` then computes `pending = amt·acc/PREC − rewardDebt = 0` and
  `owed = 0 + 0`, so the mint is skipped. **No double pay.** (`acc` is frozen while `Migrating`, :809-811.)
- **Duplicate address inside one `batchMigrate` batch.** The second `_exitPosition` hits the
  `amt == 0` early return (:599-601) and contributes 0. **No double pay.**
- **Index-vs-settle ordering, exhaustively.** All five `_settle`-equivalent sites (:329 via `_settle`,
  :353+362 inlined in `withdraw`, :380 in `claim`, :609 in `_exitPosition`, :708 via `_settle`) are
  immediately preceded by a `_updatePool` that is either effective or a deliberate frozen no-op. No
  path settles against a stale index, and no path (other than CODE-002) moves supply against a stale index.
- **Decimals: 6-dec stablecoin vs 18-dec Antimatter — no fail-open.** `acc += reward·1e18/totalStaked`
  (:824) then `pending = amount·acc/1e18` (:353/:380/:609): the staked-token decimals **cancel**, so
  the payout is in AM units regardless. Worked example — `totalStaked = 1e12` (1M USDC),
  `antimatterPerDay = 100e18`, one day: `acc += 99.99e18·1e18/1e12 = 99.99e24`; a holder of all 1e12
  gets `1e12·99.99e24/1e18 = 99.99e18` AM. Correct. Truncation loss per `_updatePool` is
  `< totalStaked/1e18` AM-wei and accrues to the protocol. No overflow reachable
  (`amount·acc` for realistic stablecoin supplies stays ~1e42-1e53 vs a 1.16e77 ceiling).
- **Access control on the new emissions path.** `antimatterPerDay` is `onlyOwner` + `poolExists` and
  settles at the old rate first (:215), so no retroactive re-pricing. `antimatter` is `immutable`
  (:60) with no setter, so no rewardDebt-invalidating repoint is possible — that is a safety property
  here, and simultaneously the reason CODE-001's tail case is unrecoverable.
- **State machine.** Only two transitions exist: `initiateMigration` Active→Migrating (:467 gate,
  :527 write) and `finalizeAndReset` Migrating→Active (:674-682). `emergencyWithdraw` (:396) and
  `userMigrate` (:576) both omit `poolExists`, but neither is exploitable on an unregistered token:
  `PoolState.Active` is the zero value, and the follow-on `user.amount > 0` / `amount > 0` checks
  cannot pass because `user.amount` is written only by `stake`/`depositFor`, both `poolExists`-gated.
- **Post-`finalizeAndReset` revival.** `accAntimatterPerShare` is deliberately **not** reset (:679-681
  clears only `migrationInfo` and fast-forwards `lastRewardTime`). A user with a surviving
  `unclaimedReward` and `amount == 0` who re-stakes gets `rewardDebt = amount·acc/PREC` at the current
  `acc`, so no windfall and no underflow. Profiler P6 re-verified against all three zeroing sites
  (:356, :402, :614).
- **Migrator NatSpec-only range, reconciled.** `CrossVersionMigrator` and `InPlaceMigrator` have zero
  executable change in `2146428..fa06de5`. The V1→V2 reward-token asymmetry (phUSD out of V1, AM
  inside V2) is real, correct — the migrators never reference either token — and now documented.
  `InPlaceMigrator`'s claim at :53/:302 that the reward "was already minted at `migrateOut`" is
  **still true and now stronger** after story-022, since `_exitPosition` mints `pending + backlog`.
  Pre-existing `CVM-4` (probes fail open) is unchanged in this range and is not re-filed.
- **Story-022 makes the *destination* side of a migration safe.** If the new staker is not yet an
  approved AM minter when `depositFor` seeds it, nothing reverts — the backlog accumulates in
  `unclaimedReward` and `claim` works once the role is granted. This is exactly the property
  CODE-001 shows is missing on the *source* side.

## Watch items for other agents

- **econ-scanner:** CODE-002's recycled-forfeiture is bounded by `antimatterPerDay`, but under the
  run-16 premise (`Antimatter.annihilate` → 1 AM = 1e18 unbacked phUSD) the *realized* dilution of
  any emission schedule is now a balance-sheet item, not a marketing spend. The emission-cap proof
  above is the bound to hand you.
- **Next `/audit-script` on phoenix-phase-2-staging:**
  `script/interactions/ClaimWithdrawStableStaker.s.sol` asserts on a phUSD balance delta after
  `claim` and hard-requires `pendingReward > 0` — both break against a V2 staker (AM, and CODE-003).
