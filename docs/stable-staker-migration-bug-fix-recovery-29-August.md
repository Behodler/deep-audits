# stable-staker — migration bug: fix, recovery, and the V1/V2 pivot

**Date:** 2026-08-29 · **Audit run:** `stable-staker-14` · **Commit audited:** `8856781` (`master`)
**Live staker:** `0xbce8ABC09BaEDCabE93419bF875f6186e182079A` · **Owner (staker + all three strategies):** `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6`

This document is the fix plan, not the finding. The evidence sits in
`reports/stable-staker-14/submissions/M-01.md` (`ss14m1`, fingerprint `d1aa4060…`) and
`reports/stable-staker-14/submissions/L-08-set-aside-buffer-not-swept.md` (`ss14l8`, fingerprint `f7991b64…`).

---

## 1. What is actually wrong

**Terminal migration is bricked on two funded mainnet pools, and the migration arithmetic ignores the set-aside buffer.**
Both defects are the same omission seen from opposite sides: the staker's own idle balance is absent from the
migration arithmetic on the way in and on the way out.

`setYieldStrategy` sweeps the whole idle balance into the newly wired strategy without recording it anywhere:

```solidity
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    strategy.deposit(token, idleBalance, address(this));   // src/StableStaker.sol:272-274
}
```

`initiateMigration` then requests exactly `totalStaked` back and asserts the strategy books nothing further:

```solidity
uint256 R = _routeExit(token, P, false);                   // requests P == totalStaked
require(
    address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0,
    "StableStaker: incomplete exit"                        // src/StableStaker.sol:456-459
);
```

`AYieldStrategy._withdrawInternal` caps downward only, so requesting `P` debits exactly `P`. Whatever the sweep
added beyond `P` stays booked forever, and the post-check can never pass. DOLA and USDC are both in this state today.

Separately, `R` counts only what the strategy delivers — `_routeExit` returns `balanceAfter - balanceBefore`
(`src/StableStaker.sol:801-803`), so idle balance already on the staker is subtracted straight back out. Credits are
`amt * min(R, P) / P`, so a below-par exit haircuts every user while the cushion that exists for exactly that case
sits idle on the same contract.

**`totalStaked` is not the place to fix this.** `totalStaked` is the sum of user positions and nothing else.
Booking swept protocol funds into it would dilute emissions (`_updatePool` divides by `totalStaked` at `:734`),
shrink every user's migration credit (`P` is the denominator), and leave a residue that no user withdrawal can
drain — permanently failing `require(poolInfo[token].totalStaked == 0)` in `finalizeAndReset` at `:605`, so the
pool could never be revived. The desync is not the defect. The defect is that `initiateMigration` *assumes*
`totalStaked == principalOf` and reverts instead of reconciling.

---

## 2. Changes for V2 — make the migration self-heal

The governing principle for all of the changes below: **every precondition a runbook is currently trusted to
satisfy must be either self-healed or asserted on-chain before the irreversible step.** A correctly ordered
runbook should be a convenience, never a load-bearing safety mechanism.

### 2.1 (PRIMARY) Reconcile the strategy to zero instead of reverting on a remainder

In `initiateMigration`, after realizing the position and before the post-check:

```solidity
uint256 P = poolInfo[token].totalStaked;
IYieldStrategy strategy = yieldStrategy[token];

_routeExit(token, P, false);                       // realize the position, as today

// Write down anything the strategy still books to us. setYieldStrategy's idle sweep can leave
// principalOf > totalStaked; that excess is protocol-owned and is relinquished here rather than
// blocking the migration. relinquishPrincipal is onlyAuthorizedClient, so we may call it on our
// own behalf — this contract already does so on the underwater buffer path at :796.
uint256 booked = address(strategy) == address(0)
    ? 0
    : strategy.principalOf(token, address(this));

// Emitted on EVERY migration, a clean one included (booked == 0). See 2.3: one event per
// migration means a missing log is itself a signal, rather than being indistinguishable
// from a migration that reconciled nothing.
emit PrincipalDivergence(token, P, booked, booked);

if (booked > 0) {
    strategy.relinquishPrincipal(token, booked);
}

require(
    address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0,
    "StableStaker: incomplete exit"                 // retained; now satisfiable by construction
);
```

Two mechanical requirements, both load-bearing:

1. **The `strategy == address(0)` case must keep its short-circuit.** With no strategy wired, `_routeExit`
   returns `P` (principal already idle) and there is nothing to relinquish; calling into a zero address reverts.
2. **The relinquish call — not the event — must be guarded on `booked > 0`.** `_relinquishInternal` reverts on zero twice — at
   `AYieldStrategy.sol:669` (`"amount must be greater than zero"`) and again at `:676` after capping
   (`"no principal to relinquish"`). An unguarded call would turn a clean migration into a reverting one,
   which is precisely the failure this change exists to remove.

`_relinquishInternal` writes down `clientBalances` and `totalDeposited` only and leaves vault shares untouched
(`AYieldStrategy.sol:678-680`), so the relinquished value stays in the strategy as protocol-owned capital and
returns through the yield accumulator. That is the stated intent implemented literally.

**Decision recorded (owner, 2026-08-29): always self-heal, never revert on divergence.** No
`maxDivergenceBps` bound and no revert path. A bound would reintroduce exactly one brick that only the owner
could clear, which is the failure mode being removed. The event below is what makes the silence observable.

### 2.2 Count the set-aside buffer in `R`, capped at par

Replace the assignment of `R` so it measures the liquid pile the contract can actually pay from:

```solidity
// R is the whole liquid position this contract can pay migration credits from, capped at par.
// This counts the set-aside buffer, so a below-par exit is softened before any user is haircut.
uint256 R = IERC20(token).balanceOf(address(this));
if (R > P) R = P;

migrationInfo[token] = MigrationInfo({realized: R, principalSnapshot: P});
emit MigrationInitiated(token, R, P);
```

The buffer is already spendable — credits pay by plain `safeTransfer` from the whole balance at `:571` — so this
is an accounting change, not a liquidity change. The par cap preserves "stakers get principal plus phUSD only",
and `min(R, P)` downstream at `:536` becomes redundant but is worth keeping as defence against a stray donation.

Replace the comment at `:472-475`, which currently justifies the exclusion, with a statement of the new rule:
all liquid value up to par is paid to users; anything above par stays protocol-owned in the decoupled strategy.

### 2.3 Observability — two events, no new storage

**Decision recorded (owner, 2026-08-29): no `protocolPrincipal` mapping.** It would buy observability, not
accounting — the self-heal relinquishes whatever is booked regardless of whether the amount was predicted — and
`StableStaker` is already 813 bytes over EIP-170 (see 2.6). Two events reconstruct the same picture off-chain at
zero storage cost.

```solidity
/// @notice Emitted once by EVERY initiateMigration, including a clean one. `claimed` is the pool's
///         totalStaked snapshot P; `booked` is strategy.principalOf after the full exit;
///         `relinquished` is what was written down. `booked == 0` is the clean case and is
///         reported explicitly — the absence of this log means the migration did not happen, not
///         that it happened cleanly. A non-zero `booked` means something moved principal without
///         the pool's accounting following it; see setYieldStrategy's idle sweep for the known cause.
event PrincipalDivergence(
    address indexed token,
    uint256 claimed,
    uint256 booked,
    uint256 relinquished
);

/// @notice Emitted when setYieldStrategy sweeps idle (non-user) balance into a newly wired strategy.
///         The pool is empty at this point by the totalStaked == 0 gate, so `amount` is protocol
///         money by construction: set-aside buffer, dust, and donations. Pairs with
///         PrincipalDivergence — an observer subtracting the swept history from a later divergence
///         is left with the UNEXPLAINED part, which is the number worth alerting on.
event ProtocolPrincipalSwept(address indexed token, address indexed strategy, uint256 amount, uint256 credited);
```

Emit the second one inside the existing sweep branch, capturing the strategy's own credited return (which the
current code discards — that discard is ledger entry `dab5a656`):

```solidity
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    uint256 credited = strategy.deposit(token, idleBalance, address(this));
    emit ProtocolPrincipalSwept(token, address(strategy), idleBalance, credited);
}
```

**Decision recorded (owner, 2026-08-29): the sweep itself is unchanged.** It keeps moving the full idle
balance; the migration-time reconciliation absorbs whatever divergence it creates.

**Decision recorded (owner, 2026-08-29): `PrincipalDivergence` fires on a clean migration too.**
A conditional event makes silence ambiguous — a clean reconciliation and a migration that never ran
look identical in the logs. Emitting unconditionally costs one log per migration and makes the
absence of a log a positive signal. The event is therefore emitted before the `booked > 0` guard,
never inside it, and it fires even when no strategy is wired (`booked == 0` by construction).

**Monitoring rule this enables.** Sum `ProtocolPrincipalSwept.credited` per token since the last
`PoolReset`; a `PrincipalDivergence.booked` larger than that sum is divergence from an unknown cause and should
page someone. Equal means the known sweep, and nothing else, produced it.

### 2.4 Close the one-way door in `CrossVersionMigrator`

`initiateMigration` on the migrator is a bare forwarder that checks none of the destination preconditions its own
NatSpec section (C) declares mandatory, all of which are discovered only at the first `migrate` — after the
source is already frozen and decoupled. Add the constructor guard and a destination pre-flight:

```solidity
// constructor
require(_oldStaker != _newStaker, "Migrator: aliased stakers");

// initiateMigration, before forwarding
require(newStaker.poolExists(token), "Migrator: destination token not registered");
require(newStaker.migrator() == address(this), "Migrator: destination not wired");
oldStaker.initiateMigration(token);
```

This is the same principle as 2.1 applied to the wiring order: a runbook step performed out of order should
fail loudly *before* the irreversible step, not silently after it.

### 2.5 Name the clear in the NatSpec

Even with the self-heal, V1 remains live and an operator may still meet the revert. At
`src/StableStaker.sol:453-459`:

```solidity
// RECOVERY (V1 only — V2 self-heals): if this reverts, the strategy holds client principal this
// contract never accounted for (see setYieldStrategy's idle sweep). The STRATEGY's owner clears it:
//   AYieldStrategy.relinquishPrincipalAsOwner(address(this), surplus)
// where surplus = strategy.principalOf(token, address(this)) - poolInfo[token].totalStaked.
// Owner-only, on the STRATEGY, in reflax-yield-vault — not on this contract.
```

### 2.6 Build constraint — read before writing any of this

**Decision recorded (owner, 2026-08-29): the source repo deliberately suspends the size limit; the
deployment build lives in staging.** `forge build --sizes` fails at `8856781` — `StableStaker` is 25,389 bytes
against the 24,576-byte EIP-170 limit — and `foundry.toml` in `stable-staker` configures no optimizer. That is
intentional. Unoptimized builds keep test ergonomics intact for the suite that manipulates block time, so the
source repo raises the limit rather than shrinking the contract:

```toml
[profile.default]
code_size_limit = 100000   # deliberate: tests deploy unoptimized. NOT the deployment profile.
```

Deployment is built in `phoenix-phase-2-staging`, whose `foundry.toml` sets `optimizer = true`,
`optimizer_runs = 10000` and `via_ir = true` — verified directly in that file at HEAD, not taken from a story
or a comment. Under that profile the contract fits.

Two consequences follow, and the second is the one that matters:

- **An over-limit `forge build --sizes` in `stable-staker` is not a defect and must not be filed as one.**
  It is a deliberate configuration. Audit runs should record it as expected, exactly as `stable-staker-14`
  already did.
- **The tested bytecode is not the deployed bytecode.** Tests run unoptimized without `via_ir`; the deployment
  runs optimized with `via_ir = true`. `via_ir` changes codegen substantially, so a suite that is green in the
  source repo has not exercised the artifact that goes on chain. Close that gap by running the full test suite
  once under the staging profile — `optimizer = true`, `optimizer_runs = 10000`, `via_ir = true` — in CI before
  each deployment. This costs one slow CI job and is the only thing standing between "tests pass" and "the
  deployed contract was tested".

### 2.7 Operational scripts (phoenix-phase-2-staging)

`PostMigrationCleanup.s.sol:218-230` and `SkimAndLeg1Migration.s.sol:478-481` both treat a large principal
divergence as expected and use a deliberate `>=` floor, with a comment saying an `==` check "would wrongly
revert". That floor is correct for solvency and silent on migration liveness, which is why this ran unnoticed
for seven months. Add an assertion — or at minimum a warning — that a non-zero divergence disables
`initiateMigration` on V1 before a pool is left in service.

---

## 3. Deriving the amounts to relinquish on DOLA and USDC

**Do not hard-code a number.** Derive it immediately before the call and re-derive if any time passes. The
figures recorded during the audit were correct at block 25,851,201 and are evidence, not operating input.

The amount to relinquish for a token is the **principal divergence**:

```
D(token) = strategy.principalOf(token, staker) - staker.poolInfo(token).totalStaked
```

Derive it with three read-only calls per token. `poolInfo` returns the `PoolInfo` struct in declaration order —
`phusdPerSecond, accPhusdPerShare, lastRewardTime, totalStaked` — so `totalStaked` is the **fourth** value:

```bash
STAKER=0xbce8ABC09BaEDCabE93419bF875f6186e182079A
TOKEN=<DOLA or USDC address>

# 1. resolve the wired strategy for this token (do not assume it from a deploy record —
#    reports/ledgers and mainnet-addresses files have been stale before)
STRAT=$(cast call $STAKER "yieldStrategy(address)(address)" $TOKEN --rpc-url $RPC_MAINNET)

# 2. what the strategy books for the staker
cast call $STRAT "principalOf(address,address)(uint256)" $TOKEN $STAKER --rpc-url $RPC_MAINNET

# 3. what the pool claims (fourth return value)
cast call $STAKER "poolInfo(address)(uint256,uint256,uint256,uint256)" $TOKEN --rpc-url $RPC_MAINNET

# D = (2) - (3), in the token's own decimals: 18 for DOLA, 6 for USDC.
```

Two properties make this safe to compute ahead of the transaction:

- **`D` is stable under normal flow.** `principalOf` is `clientBalances`, moved only by deposit, withdraw and
  relinquish. A `stake` increments `totalStaked` and `principalOf` by the same credited amount, so `D` does not
  drift with staking, withdrawing, or yield accrual. It changes only if someone runs another principal-moving
  owner action in between — which is why the runbook below re-derives rather than reusing.
- **Relinquishing exactly `D` is sufficient and not excessive.** After it, `principalOf == totalStaked == P`,
  so `initiateMigration` requests `P`, drains fully, and the post-check passes. Relinquishing *more* than `D`
  would write down principal the pool genuinely claims and force a haircut on users; **never round up.**

The clearing call is on the **strategy**, owner-only, and it moves no vault shares:

```solidity
AYieldStrategy.relinquishPrincipalAsOwner(address client, uint256 amount)   // :654, onlyOwner
// client = the staker address, amount = D
```

`withdrawAsOwner(client, recipient, amount)` at `:644` would also clear the books, but it *moves tokens out* to a
recipient. `relinquishPrincipalAsOwner` leaves the value inside the strategy as protocol-owned capital, which is
the stated intent. **Use `relinquishPrincipalAsOwner`.**

USDe needs nothing — it was never rewired, its divergence is zero, and `initiateMigration(USDe)` already
succeeds. Confirm that rather than assuming it.

---

## 4. Order of migration

**The order is not the obvious one.** `StableStaker` is a plain `Ownable` contract with no proxy, so the fix
ships only in a newly deployed staker — and reaching a new staker requires `initiateMigration` on the old one,
which is the call that is currently bricked. **Clearing DOLA and USDC on mainnet is a prerequisite for shipping
the fix, not an alternative to it.**

Per token, in this order:

1. **Derive `D`** exactly as in section 3, at the current block. Record the three raw values.
2. **Dry-run the clear.** `cast call` (not `send`) `relinquishPrincipalAsOwner(staker, D)` on the strategy from
   the owner address, and confirm it does not revert.
3. **Simulate the outcome before committing.** `eth_call` `initiateMigration(token)` on the staker `--from` the
   configured migrator `0x17DC492AfA0C25fb7293edc5c00c7d4d2FCcb342`, at a state override or fork with the clear
   applied. Confirm the `"StableStaker: incomplete exit"` revert is gone.
4. **Send the clear.** `relinquishPrincipalAsOwner(staker, D)` on the strategy, as the owner.
5. **Re-simulate `initiateMigration` against real chain state** — step 3 proved it against a fork; this proves
   it against what actually landed. Do not proceed on the fork result alone.
6. Repeat 1–5 for the second token. **Do not batch the two.** Each is independently derivable and independently
   verifiable; batching removes the checkpoint between them for no gain.

Then, once both pools are clear:

7. **Deploy V2** with the changes in section 2, optimizer enabled, size verified under EIP-170.
8. **Wire both sides before touching the source.** `setMigrator` on both stakers, `addToken` on the destination,
   phUSD minter authorization on the destination, `setClient` on the destination's strategies. With 2.4 in place
   the migrator itself will refuse to start if any of this is missing — but wire it first regardless, because the
   V1 side has no such guard.
9. **`initiateMigration`** through `CrossVersionMigrator` on the V1 staker, per token. This is the irreversible
   step: it realizes the position, decouples the strategy, freezes emissions, and takes the immutable `(R, P)`
   snapshot.
10. **`migrate` / `batchMigrate`** in batches built off-chain from `getStakersRange`. Credits come solely from
    the `(R, P)` snapshot, so they are identical regardless of batch composition or ordering — this step is
    genuinely order-independent, and it is the only one that is.
11. **Zero the emission rate**: `phUSDPerDay(token, 0)`. It is `onlyOwner` with no state gate
    (`src/StableStaker.sol:192`), so it works while the pool is `Migrating` and while paused. This is what
    makes step 13 inert — see below.
12. **`pause()`** the staker. This blocks `stake`, `withdraw` and `claim` (the only three `whenNotPaused`
    functions) across every pool. It does **not** block `emergencyWithdraw`, `userMigrate`, `batchMigrate`,
    `depositFor` or `finalizeAndReset`, so no migration work is impeded and no user loses their escape.
13. **`finalizeAndReset`** per token. This is safe to run *after* the pause because the function
    **deliberately carries no `whenNotPaused`** — its own NatSpec at `:579` says so: "so the operator can
    reset while paused (the recommended revival runbook wraps the reconfiguration in pause/unpause)."
14. **Sweep the residue**: `rescueERC20`. With no strategy wired and `totalStaked == 0`, `reserved` is zero
    (`:820`), so the full remaining balance — rounding dust and any above-par remainder — is recoverable.
15. **Leave it paused, permanently.** Retirement is the paused state; nothing further is owed.

**Ordering hazards this sequence removes**, stated so a reader knows what the ceremony is for: starting the
migration before clearing the divergence (steps 1–5 before 9); starting it before the destination is wired
(step 8 before 9, plus the on-chain guard in 2.4); and re-wiring a strategy on a pool that still holds staked
principal, which the `totalStaked == 0` gate already refuses and which remains prohibited operationally under
ledger entry `969722dc9e`.

**Why finalize-then-park is the right retirement, and why pause comes first.** The concern with
`finalizeAndReset` is that it flips the pool back to `Active` and zeroes the `(R, P)` snapshot at `:609`,
which would destroy the claim of any staker still owed one. **That concern is already enforced in code rather
than left to the runbook**: the function reverts unless the pool is fully ejected —

```solidity
require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");
require(_stakers[token].length() == 0,           "StableStaker: stakers remain");    // :604
require(poolInfo[token].totalStaked == 0,        "StableStaker: principal remains"); // :605
```

so "there are no stragglers" is a machine-checked precondition, not an assumption. It cannot silently strand
anyone; at worst it reverts and the operator keeps batching.

What *does* need care is the state it leaves behind: `Active`, empty, **no strategy wired**, and — per open
ledger entry `ss9l1` — **with `phusdPerSecond` untouched**. `finalizeAndReset` does not reset the emission
rate. An `Active` pool with a live rate and no backing strategy is stakeable, and anything staked into it
accrues phUSD against nothing. Steps 11 and 12 close that on both axes: the rate is zeroed so there is nothing
to accrue, and the pause blocks `stake` outright.

**The ordering matters and it is the reverse of the intuitive one.** Pause *before* finalizing, not after.
`finalizeAndReset` deliberately carries no `whenNotPaused` (`:579`), so pausing first costs nothing — while
finalizing first would leave the pool `Active`, empty, unpaused and stakeable for the length of one
transaction gap. That gap is small, but it is exactly the class of ordering hazard this whole document exists
to remove, and it costs nothing to close.

Three further consequences of retirement, worth holding:

- **`emergencyWithdraw` is unavailable while a pool is `Migrating`.** It requires `PoolState.Active` at `:365`,
  so between `initiateMigration` and the finalize, `userMigrate` *is* the escape hatch. That is the good
  direction — the lossy first-come-first-served exit is replaced by the pro-rata snapshot credit — but it means
  a stuck `userMigrate` has no fallback beneath it during the cutover window.
- **Pausing early is a feature, not a cost.** Only `stake`, `withdraw` and `claim` carry `whenNotPaused`.
  `batchMigrate`, `userMigrate`, `depositFor`, `emergencyWithdraw` and `finalizeAndReset` all work while
  paused, so an early pause freezes user churn on pools not yet initiated — keeping the operator's off-chain
  staker lists from drifting mid-run — without removing anyone's exit. The one real cost is that ordinary
  withdrawals stop for the duration of the cutover; that is a user-communication decision, not a safety one.
- **Retirement rests on a reversible flag, and that is acceptable here.** A paused `Active` pool is protected
  by `pause()`, which the owner or pauser can lift, whereas a pool left `Migrating` is protected by a latched
  state that `stake` structurally rejects (`:301`). With the emission rate zeroed and no strategy wired, an
  accidental unpause is close to harmless — someone could stake into a dead pool that pays nothing and
  withdraw again. Confirm the emission rate is zero on chain after step 11, because that check is what makes
  the difference between the two designs stop mattering.

**Fallback if a migration cannot be completed:** the only remaining exit is `emergencyWithdraw`, which pays at
par first-come-first-served and carries `// No underwater guard` at `:374` — it concentrates loss on whoever
exits last (ledger entries `0dca43f315` and `69c7666eee`). Treat it as the outcome to avoid, not as a plan B.

---

## 5. The V1/V2 pivot — keeping the buggy V1 alongside the fixed V2

**Chosen layout (owner, 2026-08-29): a full deployable frozen V1 beside an evergreen V2.**

```
src/
  StableStakerV2.sol            <- all forward work happens here
  interfaces/                   <- shared, version-agnostic (already extracted)
    IStableStaker.sol
    IStableStakerMigratable.sol
  versions/
    v1/
      StableStakerV1.sol        <- FROZEN: the source as deployed, bugs included, never edited
      IStableStakerV1.sol       <- FROZEN: the existing interface snapshot
```

This reverses the evergreen-single-contract approach in favour of the explicit V1/V2 split, while keeping the
extracted common interfaces that made `CrossVersionMigrator` version-agnostic in the first place. The reason is
operational: the live contract has known defects, and a runbook, a fork test, or an audit that needs to reason
about the deployed behaviour must be able to compile the deployed behaviour.

Three properties the frozen copy must have, or it is worse than useless:

- **It compiles and deploys.** An interface-only snapshot cannot be fork-tested, and a copy that has silently
  stopped building is a copy nobody can check the live contract against.
- **It is never edited, including to fix the bugs it documents.** A "tidied" V1 no longer describes what is on
  chain, which is the only thing it is for. `ss14m1` and `ss14l8` stay present in it, deliberately.
Since V1 is retired rather than revived (owner, 2026-08-29), the frozen copy is a **reference and fork-test
artifact**, not a deployment target. That lowers the bar on none of the properties below: a reference nobody
can compile is not a reference, and the un-migrated stakers left claiming against the live V1 make its exact
behaviour a thing people still need to reason about.

- **It is provably the deployed source.** Pin the commit the deployment was built from in a header comment and
  verify the copy against it. The current snapshot ritual targets `master` HEAD rather than the deploy commit
  (audit finding `ss14l4`, `L-04`) — fix that as part of this restructure, because a frozen copy taken from the
  wrong commit is a confident lie rather than a gap.

The golden-rule CI gate needs one extension: it currently catches mutation of the migration surface but is blind
to **deletion** of the frozen snapshot (`ss14l3`, `L-03`). With a full V1 contract in the tree that gap matters
more, not less — extend the gate to assert the frozen files exist and hash to their pinned values.

For the audit tooling: both contracts are first-party `.sol` under a submodule, so both are in scope by default.
`StableStakerV1.sol` will re-raise the defects it deliberately preserves on every scan. Those must be triaged
against the frozen copy explicitly rather than suppressed by habit — see the accompanying memory note so future
runs reconcile them instead of re-filing them.

---

## 6. Ledger action taken

`dab5a656` — *Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers*, Medium —
moved from `acknowledged` to **`fix-pending`** on owner instruction, 2026-08-29, per `HTQ-14-01`. Its own triage
note already read "Owner-accepted 2026-06-09, WILL FIX", and `acknowledged` suppresses an entry from every future
scan; `fix-pending` restores it to the scan and to `/open-issues` while a fix is owed.

**Still held, and not changed by this document:** the proposed closure of `dab5a656`, `dbdc3ac9b9` and
`969722dc9e` (fix group `setyieldstrategy-empty-pool-gate`) remains on hold under `HTQ-14-02`. The shared fix
basis for all three is the story-010 empty-pool gate, and that gate is precisely what makes the swept divergence
permanent. The gate is a correct fix; the hold is about not closing the group while its side effect is unowned.
Section 2.1 is what gives that side effect an owner — once it ships and is verified, the hold can lift.

---

## 7. Decisions resolved, and what is still open

Answered by the owner on 2026-08-29, recorded here so the reasoning is not re-litigated:

1. **V1 is retired after migration**, not revived — by migrating every position out, zeroing the emission
   rate, pausing, and then finalizing (section 4, steps 10-15). `finalizeAndReset`'s own guards make
   "no stragglers" a machine-checked precondition rather than a runbook promise.
2. **The source repo suspends the size limit deliberately**, via `code_size_limit`, to keep unoptimized builds
   for the block-time test suite. The deployment build lives in `phoenix-phase-2-staging` with
   `optimizer = true`, `optimizer_runs = 10000`, `via_ir = true` (section 2.6).
3. **`PrincipalDivergence` fires on every migration**, clean ones included — "absence is unsettling"
   (section 2.3).

Still open, and each one changes something concrete:

- **Does CI run the suite under the staging profile before a deployment?** Section 2.6 explains why the split
  build profiles mean a green source-repo suite has not exercised the deployed artifact. This is the one
  residual risk introduced by decision 2, and it is closable with a single CI job.
- **Who watches the `PrincipalDivergence` / `ProtocolPrincipalSwept` pair?** The events make the desync
  observable; they do not make anyone observe it. The monitoring rule in section 2.3 needs a home.
- **Is `CrossVersionMigrator` the migration path for this cutover, or `InPlaceMigrator`?** Section 4 assumes
  the cross-version path, which is correct for a V1-to-V2 contract swap. Confirm before wiring, since the two
  have different preconditions and different open findings.
