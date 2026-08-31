<!--
ID: pe7m1
C4 Submission Metadata
Title: [M-01] A reverting/blocklisted reward recipient bricks the V2->V3 migration chunk with no in-contract recovery
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV2V3.sol#L186-L194
PoC File: poc-m01-migrator-brick.t.sol
Severity: Medium
Contract: src/MigratorV2V3.sol @ 7045a96
-->

# [M-01] A reverting/blocklisted reward recipient bricks the V2->V3 migration chunk with no in-contract recovery

**Severity:** Medium

**Contract:** `src/MigratorV2V3.sol` (commit `7045a96`)

**Root cause:** [`src/MigratorV2V3.sol:186-194`](https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV2V3.sol#L186-L194) (reverting reward forwarding), aggravated by the reseed guard at [`src/MigratorV2V3.sol:114`](https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV2V3.sol#L114).

## Finding description and impact

### Summary

`MigratorV2V3.migrate` performs the one-time, chunked migration of the PhlimboV2 staker base into PhlimboV3. For each seeded user it withdraws their V2 position (which routes the user's accrued stable + freshly-minted phUSD rewards to the migrator), restakes the principal into V3, and then **forwards the reward deltas to the user with a reverting `safeTransfer`**:

```solidity
// src/MigratorV2V3.sol:186-194
if (phUSDRewards > 0) {
    IERC20(address(phUSD)).safeTransfer(user, phUSDRewards);
}
if (stableRewards > 0) {
    rewardToken.safeTransfer(user, stableRewards);
}
if (promoRewards > 0) {
    promoToken.safeTransfer(user, promoRewards);
}
```

If any single seeded user cannot receive the reward token — the reward token is a blocklistable stablecoin (USDC/USDT) and that user's account is frozen, or the user is a contract with a reverting fallback — the `safeTransfer` reverts and the token's own error propagates straight out of `migrate` (not a generic revert). Because the whole chunk is one transaction, the loop unwinds and **no user in that chunk migrates**.

### Why there is no recovery

The migration cursor `migrateIterator` is pinned at the offending user's index and cannot be advanced past it:

1. **The cursor is stuck.** Every subsequent `migrate` call re-enters the loop at the same index, re-executes the same reverting `safeTransfer`, and reverts again. The pass can never step over the bad recipient.
2. **Reseeding is forbidden mid-pass.** `seedUsers` requires `!seeded || migrateIterator == -1` ([`src/MigratorV2V3.sol:114`](https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV2V3.sol#L114)). Since the pass is underway (`migrateIterator == 2 != -1`), re-seeding a corrected list that excludes the frozen address reverts with `"Pass in progress"`.
3. **`withdrawAll` does not help.** The owner's escape hatch ([`src/MigratorV2V3.sol:216-229`](https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV2V3.sol#L216-L229)) is a pure balance sweep; it deliberately does **not** touch `migrateIterator`, so `migrate` still reverts at the same index afterward.

The net effect: **every staker seeded after the frozen/reverting address is permanently stranded in V2 and never lands in V3.** The only recovery is redeploying a fresh migrator and re-wiring it (`setMigrator`) on both PhlimboV2 and PhlimboV3 — an out-of-contract operational fix.

### Story self-contradiction (F-01)

The contract's own NatSpec offers the exclude-from-seed route as the sanctioned escape:

```
// src/MigratorV2V3.sol:57-61
Recovery note: reward forwarding uses `safeTransfer`, so a recipient that
cannot receive the reward token (e.g. a blocklisted address) reverts the
batch. As with MigratorV1V2, the operational escape is to exclude such
addresses from the seed list (or deploy and re-wire a fresh migrator);
`withdrawAll` recovers any balances stranded in this contract.
```

But "exclude such addresses from the seed list" is only reachable **before** a pass begins or **after** it completes. Once a pass is underway and stuck on a bad recipient, the reseed guard at line 114 makes that escape unreachable. The documented mitigation contradicts the implementation: the only escape the NatSpec promises for the in-flight case does not exist, leaving redeploy-and-rewire as the sole remedy.

### Impact

- **Full liveness DoS of the one-time migration.** A single un-forwardable recipient permanently halts the pass and strands every later-seeded staker in V2 with no in-contract remedy.
- Blocklist freezes on USDC/USDT are routine and outside anyone's control, so this is not a contrived precondition; it is a realistic operational hazard for a migrator whose reward token is a blocklistable stablecoin.
- No funds are stolen and stranded balances are recoverable via `withdrawAll` + redeploy, which caps severity below High. But the migration is a one-shot, cooperation-free operation whose availability is exactly its purpose, and this breaks that availability. This matches the availability class of the prior V2-M-01 finding, now recurring on the **new** `MigratorV2V3` contract.

**Severity: Medium** — protocol function/availability is impacted (migration DoS); assets are not directly at risk of theft and are owner-recoverable via redeploy.

## Proof of Concept

The PoC exercises the real `MigratorV2V3`, `PhlimboV2`, and `PhlimboV3` contracts unchanged. The only substitution is a USDT-style reward token (`MockBlocklistToken`) whose transfers to a frozen address revert with `"recipient blocked"`, mirroring a real frozen USDC/USDT recipient. No migrator logic is reimplemented.

Scenario: five stakers (alice, bob, **carol [frozen]**, dave, eve) are seeded. Chunk 1 migrates alice + bob cleanly (cursor -> 2). The cursor then lands on carol, whose stable-reward `safeTransfer` reverts, bricking the pass. The test then proves that `seedUsers` (reseed), retry, and `withdrawAll` all fail to recover, and that carol/dave/eve are permanently stranded in V2 and absent from V3.

Test file: `workspace/phlimbo-ea/test/poc-m01-migrator-brick.t.sol`

Reproduce:

```bash
cd workspace/phlimbo-ea && forge test --match-contract M01PoCTest -vvv
```

Key assertions in `test_M01_frozenRewardRecipient_bricks_migration_no_recovery`:

- After `migrate(2)`: `migrateIterator == 2`, alice and bob are in V3.
- `migrate(10)` reverts with the exact token error `"recipient blocked"`; cursor stays at `2`.
- Single-step retry `migrate(1)` reverts identically; cursor still `2`.
- `seedUsers([dave, eve])` reverts `"Pass in progress"` — the NatSpec escape is unreachable.
- `withdrawAll()` succeeds but leaves `migrateIterator == 2`; `migrate(10)` still reverts.
- Final state: carol/dave/eve retain their full V2 positions and hold `0` in V3; `seeded == true` with a pass that can never complete.

Passing output:

```
No files changed, compilation skipped

Ran 1 test for test/poc-m01-migrator-brick.t.sol:M01PoCTest
[PASS] test_M01_frozenRewardRecipient_bricks_migration_no_recovery() (gas: 1915308)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 2.38ms (1.20ms CPU time)

Ran 1 test suite in 1.56s (2.38ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```

## Recommended mitigation steps

Adopt the non-reverting forwarding pattern that `PhlimboV3.batchClaim` already uses: replace each reverting `safeTransfer` in `migrate` with a `_tryTransfer` helper that attempts the transfer and, on failure, banks the un-forwardable amount into a claim-later mapping instead of reverting. A single bad recipient then cannot brick the whole pass — the cursor advances, everyone else migrates, and the frozen user can pull their reward once their account is un-frozen.

```solidity
mapping(address => mapping(address => uint256)) public unclaimable; // token => user => amount

function _tryForward(IERC20 token, address user, uint256 amount) internal {
    if (amount == 0) return;
    (bool ok, bytes memory ret) =
        address(token).call(abi.encodeWithSelector(token.transfer.selector, user, amount));
    if (ok && (ret.length == 0 || abi.decode(ret, (bool)))) {
        // forwarded successfully
    } else {
        unclaimable[address(token)][user] += amount; // bank for later, do not revert
    }
}

function claimUnclaimable(address token) external {
    uint256 amt = unclaimable[token][msg.sender];
    require(amt > 0, "nothing to claim");
    unclaimable[token][msg.sender] = 0;
    IERC20(token).safeTransfer(msg.sender, amt);
}
```

Then in `migrate`, forward via `_tryForward(IERC20(address(phUSD)), user, phUSDRewards)` etc.

Additionally, reconcile the NatSpec recovery note (lines 57-61): either implement the above so the exclude-from-seed guidance is no longer needed for in-flight failures, or remove the claim that excluding addresses is a viable escape once a pass is underway, since the reseed guard at line 114 makes it unreachable.
