<!--
C4 Submission Metadata
Title: [M-02] seedObligations does not validate per-user deposit >= MINIMUM_STAKE, permanently bricking migrateDeposits
Severity: Medium
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV1V2.sol#L106-L142
PoC File: poc-M-02.t.sol
PoC Test: forge test --match-contract M02PoC -vv
-->

## Finding description and impact

### Summary

`MigratorV1V2.seedObligations` accepts the per-user `_deposits[]` array verbatim and never checks that each non-zero entry is `>= PhlimboV2.MINIMUM_STAKE` (`1e15`). The downstream `migrateDeposits` loop unconditionally invokes `phlimboV2.stake(deposits[i], users[i])`, which reverts with `"Below minimum stake"` whenever `0 < deposits[i] < 1e15`. Because `seedObligations` is one-shot (`require(!seeded, "Already seeded")`) and the migration iterator can only advance through successful `stake` calls, a single sub-minimum entry in the seeded array permanently pins the iterator at the offending index. There is no on-chain primitive to skip, update, or remove the bad entry — the migration path is bricked.

### Vulnerability details

Three contract constraints combine to make this a one-way trap.

1. **V2 enforces a strict minimum stake.** `PhlimboV2.stake` requires `amount >= MINIMUM_STAKE`. `MINIMUM_STAKE` is a public immutable-style constant (`1e15`). Any call with `amount` strictly between `0` and `1e15` reverts with the literal string `"Below minimum stake"`.

2. **The migrator's seeding is one-shot and copies blindly.** [`MigratorV1V2.seedObligations` at `MigratorV1V2.sol#L106-L142`](https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV1V2.sol#L106-L142) validates only that the four input arrays have matching, non-zero length. The loop body (L125-L134) does not inspect any individual `_deposits[i]`:

   ```solidity
   for (uint256 i = 0; i < _users.length; i++) {
       users.push(_users[i]);
       deposits.push(_deposits[i]);   // no MINIMUM_STAKE check
       usdcOwed.push(_usdc[i]);
       phUSDOwed.push(_phUSD[i]);
       ...
   }
   ...
   seeded = true;
   ```

   After this call, `seeded` is permanently `true` (the function gates re-entry with `require(!seeded, "Already seeded")` on L112). There is no `reseed`, no `replaceDeposit`, no `removeUser`.

3. **The migrate loop is atomic, and the iterator only advances on successful `stake`.** `migrateDeposits` reads `migrateIterator`, performs in-order stake calls, and writes back the new iterator at the end:

   ```solidity
   uint256 i = uint256(migrateIterator);
   for (; i < end; i++) {
       uint256 dep = deposits[i];
       if (dep > 0) {
           phlimboV2.stake(dep, users[i]);   // reverts here on sub-min
           totalPHUSD_deposited -= dep;
       }
   }
   ```

   If `phlimboV2.stake` reverts mid-loop, the entire transaction reverts — every prior successful migration inside the same chunk is rolled back, and `migrateIterator` is unchanged. On subsequent calls, the loop will reach the same offending index and revert identically.

   The owner can chunk the migration to advance `migrateIterator` up to the bad index (i.e., call `migrateDeposits(1)` repeatedly until just before the poison entry), but the iterator can **never** step past it: the offending index always reverts with `"Below minimum stake"`.

**`withdrawAll` is not a recovery path.** The contract exposes `withdrawAll` as an owner escape hatch, but its semantics are pure asset retrieval — it pulls phUSD/USDC out of the contract and does not touch `seeded`, `deposits`, or `migrateIterator`. After `withdrawAll`, the migrator's balance invariant (`phUSD balance == totalPHUSD_deposited remaining for un-migrated users`) is broken. Any subsequent `migrateDeposits` call fails the balance check ("phUSD balance mismatch") **before** even reaching the stake loop, so the post-withdraw state is even more wedged: not just the poison entry, but every remaining valid user becomes unmigratable through this contract instance.

### Impact

A single misconfigured entry — whether from an off-chain snapshot script bug, a V1 historical edge case, or a hand-edited deposit value — permanently disables migration for every downstream user in the seeded array. Concretely:

- All users at indices `>= badIndex` cannot be migrated through this migrator.
- The owner cannot re-seed (`seeded` is permanent), cannot skip the bad entry (no skip primitive), and cannot edit the stored deposit (no setter).
- The only recovery path is operationally heavy: deploy a fresh `MigratorV1V2`, re-execute the two deployment-time wirings (`phlimboV2.setMigrator(newMigrator)` and granting the phUSD mint role to `newMigrator`), re-fund the new contract with the corrected phUSD/USDC floats, and re-execute `seedObligations` with a sanitised deposit array. During the window in which the old migrator still holds the mint role and the new one is being wired up, two migrators may briefly coexist with mint privileges; if `withdrawAll` was already called on the broken migrator, every previously-migrated user from chunk-1 must be re-counted manually because the on-chain state on the bricked migrator is no longer reliable.

Severity is Medium per C4 audit-mode criteria: protocol function/availability is impaired (migration path bricked, requiring full migrator redeploy and authority re-wiring), funds are not directly stolen (the owner can still rescue them via `withdrawAll`), but the migration as designed is one-shot and the failure mode has no in-contract remediation.

### Proof of Concept

The test `test_M02_subMinimum_seed_bricks_migrateDeposits` in `poc-M-02.t.sol` exercises the full bricking sequence end-to-end:

1. Seeds five users — Alice, Bob, Carol, Dave, Eve — where Carol's deposit is `5e14` (half of `MINIMUM_STAKE`) and every other deposit is well above the minimum.
2. Asserts `seedObligations` accepts the array without complaint and sets `seeded = true`.
3. Funds the migrator with the exact `totalPHUSD_deposited` float.
4. Calls `migrateDeposits(5)` (full chunk) — reverts with `"Below minimum stake"`. The atomic revert rolls back Alice and Bob's stakes; `migrateIterator` stays at 0.
5. Re-tries with smaller chunk sizes — all revert at the same index.
6. Advances the iterator one user at a time via `migrateDeposits(1)`: Alice succeeds (iterator becomes 1), Bob succeeds (iterator becomes 2), Carol reverts. The iterator is now pinned at 2 and any further call reverts forever with `"Below minimum stake"`.
7. Confirms `seedObligations` cannot be replayed (reverts `"Already seeded"`).
8. Demonstrates the post-`withdrawAll` state: the balance invariant is broken and `migrateDeposits` now reverts with `"phUSD balance mismatch"` before even reaching the offending index, so Dave and Eve are also permanently unreachable through this migrator instance.

Run:

```
forge test --match-contract M02PoC -vv
```

## Recommended mitigation steps

Validate each non-zero deposit against the V2 minimum at seed time, before any state is committed. Reading `MINIMUM_STAKE()` from the V2 contract (rather than hard-coding `1e15`) keeps the check synchronised with any future V2 upgrade and avoids drift.

```solidity
function seedObligations(
    address[] calldata _users,
    uint256[] calldata _deposits,
    uint256[] calldata _usdc,
    uint256[] calldata _phUSD
) external onlyOwner {
    require(!seeded, "Already seeded");
    require(_users.length > 0, "Empty users");
    require(
        _deposits.length == _users.length &&
            _usdc.length == _users.length &&
            _phUSD.length == _users.length,
        "Length mismatch"
    );

    uint256 minStake = PhlimboV2(phlimboV2).MINIMUM_STAKE();

    uint256 sumUSDC;
    uint256 sumDep;
    uint256 sumPending;

    for (uint256 i = 0; i < _users.length; i++) {
        require(
            _deposits[i] == 0 || _deposits[i] >= minStake,
            "deposit below MINIMUM_STAKE"
        );

        users.push(_users[i]);
        deposits.push(_deposits[i]);
        usdcOwed.push(_usdc[i]);
        phUSDOwed.push(_phUSD[i]);

        sumUSDC += _usdc[i];
        sumDep += _deposits[i];
        sumPending += _phUSD[i];
    }

    totalUSDC = sumUSDC;
    totalPHUSD_deposited = sumDep;
    totalPHUSD_pending = sumPending;
    seeded = true;

    emit Seeded(_users.length, sumUSDC, sumDep, sumPending);
}
```

This fails fast at seed time — before any phUSD is minted, any USDC is moved, or the `seeded` one-shot is consumed — so the owner can correct the off-chain snapshot and re-call `seedObligations` on the same contract instance without redeployment.

As a defence-in-depth alternative (or complement), `migrateDeposits` could be updated to treat a sub-minimum non-zero entry as a skip rather than a revert (emit an event so the operator can settle the user manually). The seed-time validation is preferable on its own because it surfaces the misconfiguration before any funds or roles have been committed; the in-loop skip on its own would silently strand sub-minimum deposits, which is its own footgun.
