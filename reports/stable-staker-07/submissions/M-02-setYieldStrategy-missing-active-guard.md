<!--
ID: ss7m2
C4 Submission Metadata
Title: [M-02] `setYieldStrategy` lacks a migration-active guard, letting strategy adoption sweep the migration payout pile and permanently brick the `userMigrate` escape hatch
Severity: Medium
Status: NEW
Ledger Fingerprint: 678e6fa2
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L198-L220
PoC File: workspace/stable-staker/test/PoC_M02_SetStrategyDuringMigration.t.sol
-->

## Finding description and impact

### Summary

`StableStaker.setYieldStrategy` ([StableStaker.sol#L198-L220](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L198-L220)) is the only principal-moving entry point that does **not** guard against an active terminal migration. Every other path that touches principal — `stake` ([L242](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L242)), `withdraw` ([L263](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L263)), `emergencyWithdraw` ([L307](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L307)), and `depositFor` ([L524](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L524)) — carries `require(!migrationInfo[token].active, "StableStaker: migrating")`. `setYieldStrategy` omits it.

If the owner (re)configures a yield strategy on a token that is already in terminal migration, the call is accepted and silently sweeps the migration payout pile out of the contract and into the newly-adopted strategy. This drains the funds that `userMigrate` / `batchMigrate` are required to pay out, and because every other exit path is also closed during migration, all migrants' principal is permanently stranded with no in-contract recovery path.

### Vulnerability details

Terminal migration deliberately concentrates a token's entire position into an idle pile held by the contract. In `initiateMigration` ([StableStaker.sol#L369-L410](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L369-L410)) the contract:

1. sets `migrationInfo[token].active = true` ([L408](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L408));
2. realizes the full strategy position into the contract as the idle pile `R` ([L387](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L387)); and
3. decouples the strategy by setting `yieldStrategy[token] = address(0)` ([L401](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L401)).

`userMigrate` ([L495-L496](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L495)) and `batchMigrate` ([L429-L436](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L429)) thereafter pay each migrant a fixed credit `p_i·min(R,P)/P` by transferring `token` directly out of that idle pile `R`.

`setYieldStrategy` has no such guard:

```solidity
function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
    IYieldStrategy old = yieldStrategy[token];
    if (address(old) != address(0)) {
        IERC20(token).forceApprove(address(old), 0);
    }

    yieldStrategy[token] = strategy;

    if (address(strategy) != address(0)) {
        IERC20(token).forceApprove(address(strategy), type(uint256).max);

        // Sweep any idle balance already sitting in the contract into the new strategy.
        uint256 idleBalance = IERC20(token).balanceOf(address(this));   // == R during migration
        if (idleBalance > 0) {
            strategy.deposit(token, idleBalance, address(this));        // pushes R into the new strategy
        }
    }

    emit YieldStrategySet(token, address(old), address(strategy));
}
```

Because migration already cleared the strategy to `address(0)`, the call takes the first-adoption branch (`old == address(0)`, no allowance reset) and executes the idle-balance sweep at [L213-L216](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L213-L216). The sweep reads `idleBalance = token.balanceOf(this)`, which during an active migration is exactly the payout pile `R`, and deposits all of it into the new strategy.

After the sweep, every path that could move that principal is dead:

- `userMigrate` / `batchMigrate` revert on their token transfer with `ERC20InsufficientBalance(staker, 0, p_i·min(R,P)/P)` — the contract balance is now `0` while the owed credit is unchanged.
- `withdraw` and `emergencyWithdraw` revert with `"StableStaker: migrating"` (the migration is still `active` and terminal — there is no resume path).
- `rescueERC20` ([L706-L713](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L706-L713)) reverts with `"StableStaker: would touch user principal"`: with a strategy now set, `reserved` collapses to `0` ([L708](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L708)), but the in-contract balance is also `0`, so `bal >= reserved + amount` fails for any `amount > 0`. The swept funds live inside the new strategy and there is no client-side round-trip back through it once migration is terminal.

The result is permanent stranding of all migrants' principal for that token.

### Impact

Permanent loss of availability of the permissionless `userMigrate` escape hatch and permanent stranding of **all** migrants' principal for the affected token. The contract offers no in-contract recovery path once the sweep has occurred.

Classified **Medium** as a non-obvious owner footgun:

- It is not a malicious-owner vector. The hazard is that `setYieldStrategy` is the sole state-mutating principal path that silently lacks the `active` guard every sibling carries — a competent, non-malicious owner who performs routine strategy configuration (e.g. reusing a deployment runbook, or pointing a token at a fresh strategy) during an active migration would be surprised that the call succeeds and bricks the migration, rather than reverting like the other paths.
- It impacts protocol availability and principal recoverability rather than enabling theft, and is conditional on the owner performing strategy configuration during an active migration.

Under the project's Law-3 trust model this is in scope: the consequence is non-obvious (the guard asymmetry is invisible at the call site), so it is a reportable operational hazard rather than a trusted owner action.

### Proof of Concept

A passing Foundry test is provided at `workspace/stable-staker/test/PoC_M02_SetStrategyDuringMigration.t.sol`.

Run it with:

```bash
cd workspace/stable-staker
forge test --match-contract M02PoCTest \
  --match-test test_M02_setStrategyDuringMigration_bricksUserMigrate -vvv
```

Result:

```
[PASS] test_M02_setStrategyDuringMigration_bricksUserMigrate() (gas: 2463236)
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

The test stakes 100e18 into `strat1`, engages terminal migration (realizing the idle pile `R = 100e18` into the contract and decoupling the strategy), then has the owner call `setYieldStrategy(token, strat2)` on the already-migrating token. It asserts the exact failure chain:

```solidity
// initiateMigration: R = 100 sits idle in the contract, strategy decoupled to address(0)
assertEq(dai.balanceOf(address(staker)), STAKE, "idle pile R == 100 sits in the contract");
assertEq(address(staker.yieldStrategy(address(dai))), address(0), "strategy decoupled by migration");

// THE BUG: setYieldStrategy during active migration sweeps R into strat2
staker.setYieldStrategy(address(dai), IYieldStrategy(address(strat2)));
assertEq(dai.balanceOf(address(staker)), 0, "idle migration pile SWEPT to zero");
assertEq(strat2.principalOf(address(dai), address(staker)), STAKE, "R now trapped inside strat2");

// userMigrate reverts: contract balance 0 < owed credit 100
vm.prank(userA);
vm.expectRevert(
    abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(staker), 0, expectedCredit)
);
staker.userMigrate(address(dai));

// batchMigrate reverts the same way
vm.prank(migrator);
vm.expectRevert(
    abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(staker), 0, expectedCredit)
);
staker.batchMigrate(address(dai), batch);

// every fallback exit is dead
vm.prank(userA);
vm.expectRevert(bytes("StableStaker: migrating"));
staker.emergencyWithdraw(address(dai));

vm.prank(userA);
vm.expectRevert(bytes("StableStaker: migrating"));
staker.withdraw(address(dai), STAKE);

vm.expectRevert(bytes("StableStaker: would touch user principal"));
staker.rescueERC20(address(dai), owner, 1);
```

The exact migration-payout revert demonstrated is `ERC20InsufficientBalance(staker, 0, 100e18)` (owed credit `expectedCredit = STAKE * min(R,P) / P = 100e18`), confirming the migration pile is gone and the position is unpayable while the user's recorded principal remains intact at `100e18`.

## Recommended mitigation steps

Add the same migration guard that the other principal-moving paths already carry to the top of `setYieldStrategy`:

```solidity
function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
    require(!migrationInfo[token].active, "StableStaker: migrating");
    // ... existing body ...
}
```

This makes the guard symmetric across all state-mutating principal paths (`stake`, `withdraw`, `emergencyWithdraw`, `depositFor`, and now `setYieldStrategy`), so strategy (re)configuration cannot disturb the realized payout pile once a token's terminal migration is engaged. A non-zero idle balance during an active migration is the migration pile by construction and must never be swept.
