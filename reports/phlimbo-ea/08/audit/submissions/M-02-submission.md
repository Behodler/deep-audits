<!--
ID: pe8m2
C4 Submission Metadata
Title: [M-02] MigratorV2V3.migrate has an unskippable per-user body: a dust or stale-debt V2 position permanently wedges the migration cursor, recoverable only by redeploying the migrator and re-wiring both setMigrator roles
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L171-L188
Fingerprint: 95552867719d92a56b055c2e4a2654433a1f620b119e8b897d93b5047a530097
Finding: 08-03 (DEDUP-08-03 / CLASS-08-03)
Commit: bf42c12
Severity: Medium
PoC: workspace/phlimbo-ea/test/probe-08-code3.t.sol, workspace/phlimbo-ea/test/probe-08-code4.t.sol
-->

## Finding description and impact

### Summary

`MigratorV2V3.migrate` makes three external calls per user inside its loop. story-025 hardened the **third** (reward forwarding) with a non-reverting `_forward`, and the rewritten NatSpec now claims the pass can never brick. The **first two** — `phlimboV2.withdraw` and `phlimboV3.stake` — remain unguarded. Neither is wrapped in `try/catch`, and the loop's only skip condition is an exactly-zero live position. Any revert from either call reverts the whole chunk and pins `migrateIterator` at that index permanently.

Two vectors are PoC'd, both triggered by pre-existing conditions on the already-deployed V2, one of them self-inflictable at ~1 wei.

### Vulnerability details

The loop body at [`MigratorV2V3.sol#L171-L188`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L171-L188):

```solidity
(uint256 amount,,) = phlimboV2.userInfo(user);
if (amount == 0) continue;              // L173 — the ONLY skip: exactly-zero position
...
phlimboV2.withdraw(amount, user);       // L182 — unguarded external call (vector 1b)
...
phlimboV3.stake(amount, user);          // L188 — unguarded external call (vector 1a)
```

The cursor cannot step past a bad index:

- `migrateIterator` is written **once, after the loop** ([`#L209-L213`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L209-L213)), so a revert inside the loop discards every iteration in the chunk, including the progress made before the bad index.
- There is no mid-pass reseed: `seedUsers` is guarded by `require(!seeded || migrateIterator == -1, "Pass in progress")` ([`#L126`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L126)). A wedged pass has `seeded == true` and `migrateIterator >= 0`, so the list cannot be replaced to route around the bad entry.
- `withdrawAll` does not help: its own NatSpec ([`#L241`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L241)) states *"the seeded list and iterator are untouched and migration can resume"* — it sweeps balances, it does not reset the cursor.
- There is no owner-only skip-index and no per-user retry.

Recovery therefore requires redeploying the migrator and re-wiring **both** `setMigrator` roles (on V2 and on V3).

**Vector 1a — dust position.** `PhlimboV2.pauseWithdraw` ([`#L280-L291`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV2.sol#L280-L291)) enforces no dust floor. A user can partially exit during any V2 pause and leave a position in `(0, MINIMUM_STAKE)`. `migrate`'s skip at L173 catches only `amount == 0`, so the dust position is passed to `phlimboV3.stake`, which reverts `"Below minimum stake"` ([`PhlimboV3.sol#L577`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L577), `MINIMUM_STAKE = 1e15`). **Self-inflictable at ~1 wei** — this is a grief vector requiring no privilege and no capital.

**Vector 1b — stale debt.** `pauseWithdraw` also reduces `user.amount` without realigning `phUSDDebt`/`stableDebt`. The debt is left sized against the *pre-exit* amount. Once `amount_new * acc_now < amount_old * acc_then`, the `amount * acc / PRECISION − debt` computation in `V2._claimRewards` ([`#L486`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV2.sol#L486)) underflows (Panic 0x11). `V2.withdraw` calls `_claimRewards` unconditionally ([`#L373`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV2.sol#L373)), so the migrator's L182 call reverts.

An exact full exit (`amount == 0`) is safe on both counts — a genuinely narrow escape.

### The vectors reinforce each other

Severity **rises** as the partial exit approaches a full exit. A user retaining ~1% of her position needs a ~100x accumulator move before the stale debt stops underflowing — she is bricked effectively permanently — and that same regime is exactly where the dust vector lives.

### Correction to the ledger/classifier narrative — do not read "positions remain safe and transactable in V2"

That characterization is **false** and must not be relied on. `PhlimboV2.pauseWithdraw` does not realign debts, and both of V2's ordinary user paths are `whenNotPaused` and go through the same underflowing `_claimRewards`:

- `PhlimboV2.withdraw` ([`#L363`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV2.sol#L363)) → `_claimRewards` at L373 → Panic 0x11.
- `PhlimboV2.claim` ([`#L407`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV2.sol#L407)) → `_claimRewards` at L424 → Panic 0x11.

**The users who brick the migration are the same users who are bricked in V2's normal paths.** The PoC confirms it directly: `bricked user can claim on V2 (1=yes): 0`.

The honest statement is: **principal is recoverable only via `pauseWithdraw` during an owner-initiated pause; ordinary `withdraw`/`claim` revert.** That is precisely why this stays Medium — the owner will pause, so principal is recoverable and no funds are lost — and it strengthens rather than weakens the case against Low.

### Impact

No assets are stolen and no principal is lost. The loss is of the **migration path**: any single user can permanently wedge it at ~1 wei of self-inflicted dust, stranding every user positioned after the bad index. The PoC leaves `carol` with 1000e18 stranded in V2 behind a 1-wei position. Recovery is a redeploy plus a re-wire of two privileged roles — operationally expensive, but available.

### Faithfulness: an incomplete fix that reads as done

The rewritten NatSpec at [`MigratorV2V3.sol#L59-L61`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L59-L61) states:

> *"...the amount is banked into the per-user `unclaimable` mapping and `RewardForwardFailed` is emitted, so **the cursor always advances and a single bad recipient can never brick a pass**."*

This is true for the forwarding legs and **false** for the withdraw/stake legs. story-025 set out to make the pass unbrickable and hardened one of three unguarded external calls in the loop; the invariant it now advertises is falsified by both PoCs. This is an incomplete fix that reads as complete — a reader of the NatSpec would conclude the pass is safe.

### Relationship to ledger entry V3-M-01 (`0b7fa9be`, fix-pending)

Same end state, **different root cause class**. V3-M-01's cause is a reverting *recipient* during reward forwarding. That cause is **genuinely fixed** — story-025's `_forward` + `claimUnclaimable` works, and it is PoC-verified (5/5 probes). This finding is a **distinct, still-live path** through the withdraw/stake legs, which story-025 never addressed. This is not a claim that story-025 failed at what it set out to do; it is a claim that what it set out to do covered one of three calls.

### Scope note

The root cause is in new in-scope code: the migrator's unskippable loop body at [`MigratorV2V3.sol#L171-L188`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L171-L188) — the `if (amount == 0) continue;` skip that is too narrow, and the absence of `try/catch` around two external calls. The V2 conditions are *preconditions*, not the root cause; and `PhlimboV2.sol` is first-party and in scope regardless. Both V2-side root defects are already ledgered as open (V2-L-01 `9ef309e7`, V2-L-03 `d6484512`), which corroborates that these positions may exist on-chain today, before the migration is ever run.

### Severity: Medium

**Why not High.** User funds are not stolen and not lost. Principal is recoverable via `pauseWithdraw` during an owner-initiated pause, and the owner can restore the migration path by redeploying the migrator and re-wiring two `setMigrator` roles. Permanent DoS of the migration path is protocol function/availability impact, which C4 caps at Medium. (A Tier-1 profiler rated this `local-high`; that is a *local*, within-contract rating by construction — Tier-1 does not model cross-contract recoverability, which is exactly the fact that caps this.)

**Why not Low.** A migration path that any single user can permanently wedge at ~1 wei, whose trigger is already on-chain and needs no attacker, and whose recovery requires a redeploy plus re-wiring of two privileged roles, is availability impact by any reading. Both vectors are PoC'd and unskippable — this is not a hypothesis.

### Proof of Concept

Both PoCs are assertion-style: the test **fails** to prove the brick — the `[FAIL: ...]` line is the finding, not a broken test.

#### Vector 1a — dust position

**File:** `/home/justin/code/audits/workspace/phlimbo-ea/test/probe-08-code3.t.sol`
**Test:** `test_P8_dust_position_bricks_migration_pass`

```
$ forge test --match-path test/probe-08-code3.t.sol -vv

[PASS] test_P8_control_clean_pass_completes() (gas: 670192)
[FAIL: P8: a 1-wei dust position permanently bricks the migration pass] test_P8_dust_position_bricks_migration_pass() (gas: 671458)
Logs:
  dust V2 position (wei): 1
  migrate past dust ok (1=yes): 0
  revert: 0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001342656c6f77206d696e696d756d207374616b6500000000000000000000000000
  migrate(10) ok (1=yes): 0
  reseed-to-skip ok (1=yes): 0
  final migrateIterator (stuck): 1
  carol still stranded in V2: 1000000000000000000000
```

The revert payload decodes to `Error(string)` / `"Below minimum stake"` — `phlimboV3.stake` at L188. Retrying with a larger chunk fails (`migrate(10) ok: 0`), reseeding to route around it fails (`reseed-to-skip ok: 0`, blocked by `"Pass in progress"`), the cursor is stuck at index 1, and carol's 1000e18 is stranded behind a 1-wei position. The control test confirms an identical pass with no dust position completes cleanly.

#### Vector 1b — stale debt

**File:** `/home/justin/code/audits/workspace/phlimbo-ea/test/probe-08-code4.t.sol`
**Test:** `test_P9_stale_debt_v2_position_bricks_migration_pass`

```
$ forge test --match-path test/probe-08-code4.t.sol --match-test test_P9 -vv

[FAIL: P9/LOCAL-101: stale-debt V2 position bricks the migration pass] test_P9_stale_debt_v2_position_bricks_migration_pass() (gas: 840873)
Logs:
  bricked phUSDDebt after claim (non-zero): 4109589041095296000
  bricked V2 position: 500000000000000000000
  bricked user can claim on V2 (1=yes): 0
  migrate past bricked ok (1=yes): 0
  revert: 0x4e487b710000000000000000000000000000000000000000000000000000000000000011
  migrate(10) ok (1=yes): 0
  reseed-to-skip ok (1=yes): 0
  final migrateIterator (stuck): 1
  carol stranded in V2: 1000000000000000000000
```

The revert payload decodes to `Panic(uint256)` with code `0x11` — arithmetic underflow, in `V2._claimRewards` reached from `phlimboV2.withdraw` at L182. Note `bricked user can claim on V2 (1=yes): 0`: this is the direct evidence for the narrative correction above — the same user is bricked in V2's ordinary paths, not "safe and transactable".

## Recommended mitigation steps

**Fix location: the per-user loop body, [`MigratorV2V3.sol#L171-L188`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L171-L188).**

**Preferred — make the body non-reverting, matching the invariant the NatSpec already claims.** Move the per-user work into an external self-call and `try/catch` it, so a bad position is skipped and the cursor advances:

```solidity
for (; i < end; i++) {
    address user = users[i];
    (uint256 amount,,) = phlimboV2.userInfo(user);
    if (amount == 0) continue;

    try this.migrateOne(user, amount) {
        // UserMigrated emitted inside
    } catch {
        emit UserMigrationSkipped(user, amount);   // cursor still advances
    }
}

/// @dev self-call only; reverts are caught by migrate()
function migrateOne(address user, uint256 amount) external {
    require(msg.sender == address(this), "Only self");
    ... // existing L175-L206 body
}
```

Skipped users are recorded on-chain by event and can be handled in a later, targeted pass. Note this changes the contract's reentrancy shape — `migrateOne` must be self-call gated as above, and `nonReentrant` must remain on `migrate` only (a `nonReentrant` on `migrateOne` would revert the self-call).

**Minimum viable alternative — an owner-only skip.** If the try/catch refactor is judged too large:

```solidity
function skipCurrent() external onlyOwner {
    require(seeded && migrateIterator >= 0, "Nothing to skip");
    emit UserMigrationSkipped(users[uint256(migrateIterator)], 0);
    migrateIterator = int256(uint256(migrateIterator) + 1);
}
```

This restores forward progress without a redeploy. It is strictly weaker than the try/catch — it requires an owner transaction per bad index, so a griefer seeding many dust positions still imposes real operational cost.

**Additionally, widen the skip at L173** to cover the dust band, which removes vector 1a outright and is a one-line change:

```solidity
if (amount < phlimboV3.MINIMUM_STAKE()) continue;   // was: if (amount == 0)
```

This alone does **not** close vector 1b (the stale-debt underflow occurs in `phlimboV2.withdraw` and is independent of position size), so it must not be treated as a complete fix.

Fixing the underlying V2 defects (ledger V2-L-01 / V2-L-03: have `pauseWithdraw` realign debts and enforce a dust floor) removes the preconditions for *future* positions but cannot repair positions already planted on the deployed V2. The migrator must be robust to them regardless.

