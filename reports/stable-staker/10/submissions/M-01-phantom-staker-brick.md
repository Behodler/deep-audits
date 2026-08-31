<!--
ID: ss10m1
C4 Submission Metadata
Title: [M-01] Zero-credit `depositFor` strands an unremovable phantom staker that permanently bricks `finalizeAndReset`, freezing the pool in Migrating forever
Severity: Medium
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L616-L637
PoC File: workspace/stable-staker/test/PoC_DEDUP001_PhantomStakerBrick.t.sol
Ledger Lineage: escalation of ledgered finding eae10d60 (missing `credited > 0` guard in depositFor, previously filed submitted-qa as Low)
-->

## Finding description and impact

### Summary

`depositFor` (`StableStaker.sol:616-637`) inserts the credited user into the per-token staker set unconditionally, without the `require(credited > 0)` guard that `stake` enforces at line 301. A deposit whose strategy credit floors to zero therefore books `userInfo.amount == 0` yet still adds the address to `_stakers`. This zero-amount "phantom" staker can never be removed once the pool enters terminal migration, which makes `finalizeAndReset` (which requires `_stakers.length() == 0`) revert forever. The pool is left permanently frozen in the `Migrating` state with no on-chain recovery path — it must be redeployed.

`depositFor` is `onlyMigrator` — a deposit-on-behalf hook called by the trusted `StableStakerMigrator` while it forwards each user's position during the migration runbook. The phantom is therefore not planted by an arbitrary attacker; it arises **unknowingly** when the migrator forwards a real user's dust-sized position (or any entry whose post-haircut credit floors to zero) into a pool backed by a market-type strategy. This is the textbook Law-3 footgun: a competent, non-malicious operator running the prescribed `initiateMigration → batchMigrate → finalizeAndReset` flow has no reason to expect a routine dust migrant to permanently wedge the pool. There is no direct loss of user funds; the impact is denial of service / permanent loss of pool availability, hence Medium.

### Vulnerability details

The vulnerable path is `depositFor` at [StableStaker.sol#L616-L637](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L616-L637):

```solidity
function depositFor(address token, address user, uint256 amount)
    external
    nonReentrant
    onlyMigrator
    poolExists(token)
{
    require(amount > 0, "StableStaker: amount=0");        // guards the PRE-haircut INPUT only
    require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
    PoolInfo storage pool = poolInfo[token];
    _updatePool(token);
    UserInfo storage info = userInfo[token][user];
    _settle(user, info, pool);

    uint256 received = _pullToken(token, msg.sender, amount);
    uint256 credited = _routeDeposit(token, received);    // POST-haircut credit, may floor to 0
    info.amount += credited;                              // += 0  -> userInfo.amount stays 0
    pool.totalStaked += credited;                         // += 0
    info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;
    _stakers[token].add(user);                            // UNCONDITIONAL: phantom inserted
    emit DepositedFor(token, user, credited);
}
```

The `require(amount > 0)` on line 622 only validates the pre-haircut *input* amount. It does **not** validate the post-haircut credited principal returned by `_routeDeposit`. Contrast `stake`, which places the check on the credited amount at [StableStaker.sol#L301](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L301) before touching `userInfo` / `_stakers`:

```solidity
uint256 credited = _routeDeposit(token, received);
require(credited > 0, "StableStaker: nothing credited");   // depositFor omits this
```

For a market/AMM-style strategy (`ERC4626MarketYieldStrategy`), the booked credit is a pure pre-swap function of the input:

```
creditedPrincipal = amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS
```

With a realistic slippage tolerance (e.g. 100 bps) and a dust input (e.g. 1 wei), this floors to `0`. The strategy's base `AYieldStrategy._depositInternal` only enforces `require(amount > 0)` on the pre-haircut input (line 672); there is no `require(creditedPrincipal > 0)`, and the strategy's own `require(sharesReceived > 0)` still passes at par / near-par vault-share prices. So a positive input legitimately books a `0` credit and `depositFor` inserts a staker with `userInfo.amount == 0`.

Once the phantom is in the set, terminal migration makes it unremovable:

- `_exitPosition` ([StableStaker.sol#L519-L543](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L519-L543)) early-returns on `amt == 0` at lines 522-524, *before* the `_stakers[token].remove(account)` at line 537. So `batchMigrate` / `userMigrate` skip the phantom and never evict it.
- `userMigrate` requires `amount > 0` (line 557), so the phantom cannot self-exit.
- `stake`, `withdraw`, `emergencyWithdraw`, and `depositFor` all require `PoolState.Active`, so none of them can run while the pool is `Migrating`.

No path removes a zero-amount account while the pool is `Migrating`. Consequently `finalizeAndReset` at [StableStaker.sol#L595](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L595):

```solidity
require(_stakers[token].length() == 0, "StableStaker: stakers remain");
```

reverts with `StableStaker: stakers remain` on every call. The pool can never return to `Active` and is permanently frozen in `Migrating`.

### Ledger lineage (escalation)

This finding escalates ledgered issue **eae10d60** — the missing `credited > 0` guard in `depositFor` — which was previously filed `submitted-qa` as a Low. The escalation is driven by a newer consequence, not a re-litigation of the old severity. Story-009 introduced the `finalizeAndReset` / `stakerCount == 0` lifecycle gate that allows a migrated pool to be revived back to `Active`. That very lifecycle gate is what turns a harmless zero-amount staker into a **permanent** denial of service: before the gate existed, a phantom set entry had no terminal-availability consequence; with the gate, it deterministically and irrecoverably bricks pool revival. The root cause (missing post-haircut guard) is unchanged; its blast radius grew with the lifecycle state machine.

### Impact

A single dust `depositFor` permanently bricks `finalizeAndReset` for the affected token's pool. The pool is frozen in `Migrating` with:

- No revival path (`finalizeAndReset` reverts forever).
- No further `stake` / `withdraw` / `emergencyWithdraw` (all require `Active`).
- The strategy already decoupled by `initiateMigration`, so the pool cannot resume healthy operation.

Recovery requires redeploying the StableStaker (or the affected token pool) and re-wiring the migrator, strategy, and minter authorization. No user principal is stolen — real stakers still exit via `batchMigrate` / `userMigrate` for their snapshot credit — so this is an availability / DoS issue, not a direct fund loss. The phantom arises through the trusted migrator forwarding an ordinary dust-credited position during migration, not through any privileged actor's misuse — the harmed party is the operator's own pool, which makes this an unintended operational footgun rather than a malicious-actor vector.

### Plausibility (stated honestly)

The trigger is conditional and is reported at Medium, not High:

- It requires a **market/AMM-type strategy with nonzero slippage** (e.g. `ERC4626MarketYieldStrategy`). An idle-hold (`address(0)`) or par-credit ERC4626 strategy that credits the full received amount does not floor to zero.
- The floor-to-zero is fully reachable in the par / near-par vault-share-price regime, where the strategy's own `require(sharesReceived > 0)` still passes. A highly-appreciated vault raises the dust threshold (more input wei needed before the credit floors) but does not eliminate the trigger.
- The trigger path is the trusted migrator (`onlyMigrator`), not an arbitrary caller. The phantom arises unknowingly from an ordinary dust-credited position forwarded during migration; it does not require owner malice and the operator is genuinely surprised by the permanent brick. This is a non-obvious operational footgun (Law 3, in scope) — realistic but conditional, hence Medium not High.

## Recommended mitigation steps

The cleanest fix mirrors the invariant `stake` already enforces. Add the post-haircut guard to `depositFor`, rejecting zero-credit deposits:

```solidity
uint256 received = _pullToken(token, msg.sender, amount);
uint256 credited = _routeDeposit(token, received);
require(credited > 0, "StableStaker: nothing credited");   // mirror stake() L301
info.amount += credited;
pool.totalStaked += credited;
...
_stakers[token].add(user);
```

This restores the system-wide invariant that an address is only ever in `_stakers` while it holds a nonzero credited position, and it prevents the phantom from ever being created. It is the minimal change and matches the existing `stake` semantics exactly.

Alternative (or defensive, belt-and-suspenders) mitigations:

- Have `_exitPosition` remove zero-amount accounts from `_stakers` instead of early-returning before the `remove` — i.e. move the `_stakers[token].remove(account)` ahead of (or duplicate it into) the `amt == 0` branch so a stranded phantom is swept during migration.
- Have `finalizeAndReset` tolerate / sweep zero-amount phantom stakers (e.g. iterate the set and remove any `userInfo.amount == 0` entries) before asserting the set is empty.

The `depositFor` guard is preferred because it eliminates the phantom at the source and re-establishes the staker-set invariant that the rest of the lifecycle logic implicitly relies on.

### Proof of Concept

A standalone, passing Foundry test is provided at `workspace/stable-staker/test/PoC_DEDUP001_PhantomStakerBrick.t.sol`. Run:

```bash
forge test --match-path test/PoC_DEDUP001_PhantomStakerBrick.t.sol -vvv
```

The test:

1. Wires a 1%-slippage market strategy (`MockYieldStrategy`, credit = `amount * (10000 - 100) / 10000`, mirroring `ERC4626MarketYieldStrategy`) on the empty pool and sets the migrator.
2. Stakes 100 ether of real principal as `realUser`.
3. Has the migrator call `depositFor(dai, phantom, 1)` — a 1-wei dust input. The input guard `require(amount > 0)` passes; the strategy books `credited = 1 * 9900 / 10000 = 0`. It asserts `userInfo[phantom].amount == 0` yet `stakerCount` rose from 1 to 2 and `phantom` is present in `getStakers`.
4. Runs `initiateMigration` then `batchMigrate([realUser, phantom])`. `totalStaked` drains to 0 and `realUser` is evicted, but the phantom survives (`_exitPosition`'s `amt == 0` early-return skips the `remove`), leaving `stakerCount == 1`.
5. Confirms the phantom cannot be healed while `Migrating`: `userMigrate` reverts `StableStaker: nothing staked`; `depositFor` and `withdraw` revert `StableStaker: pool not active`.
6. Asserts the final consequence — `finalizeAndReset(dai)` reverts with the exact string `StableStaker: stakers remain`, proving the pool is permanently frozen in `Migrating`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableStaker.sol";
import "flax-token/FlaxToken.sol";
import "reflax-yield-vault/interfaces/IYieldStrategy.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockYieldStrategy} from "./mocks/MockYieldStrategy.sol";

contract DEDUP001PoCTest is Test {
    FlaxToken internal phUSD;
    StableStaker internal staker;
    MockERC20 internal dai; // 18 decimals
    MockYieldStrategy internal strategy;

    address internal owner = address(this);
    address internal migrator = address(0x4191A704); // configured migrator (EOA in this PoC)
    address internal realUser = address(0xA11CE);    // a real staker with real principal
    address internal phantom = address(0xDEAD);      // user stranded with a 0-credit deposit

    uint256 internal constant SLIP_BPS = 100; // 1% deposit haircut (market/AMM strategy)
    uint256 internal constant REAL_STAKE = 100 ether;

    function setUp() public {
        phUSD = new FlaxToken();
        staker = new StableStaker(phUSD, owner);
        phUSD.setMinter(address(staker), true);

        dai = new MockERC20("Dai", "DAI", 18);
        staker.addToken(address(dai));

        // 1% haircutting market strategy wired on the EMPTY pool. Mirrors ERC4626MarketYieldStrategy:
        // deposit credits amount*(1-slip).
        strategy = new MockYieldStrategy();
        strategy.setClient(address(staker), true);
        strategy.setDepositSlippageBps(SLIP_BPS);
        staker.setYieldStrategy(address(dai), IYieldStrategy(address(strategy)));

        staker.setMigrator(migrator);

        dai.mint(migrator, 1_000_000 ether);
        vm.prank(migrator);
        dai.approve(address(staker), type(uint256).max);

        dai.mint(realUser, 1_000_000 ether);
        vm.prank(realUser);
        dai.approve(address(staker), type(uint256).max);
    }

    function test_DEDUP001_phantomStakerPermanentlyBricksFinalizeAndReset() public {
        // 1. A real user stakes real principal.
        vm.prank(realUser);
        staker.stake(address(dai), REAL_STAKE);

        // 2. Migrator performs a DUST depositFor (1 wei): input guard passes, strategy books
        //    credited = 1 * (10000-100)/10000 = 0. depositFor has NO require(credited > 0).
        assertEq(staker.stakerCount(address(dai)), 1, "only real user staked before dust deposit");

        vm.prank(migrator);
        staker.depositFor(address(dai), phantom, 1); // dust input -> 0 credit

        // 3. Strategy floored credit to 0.
        (uint256 phantomAmt,) = staker.userInfo(address(dai), phantom);
        assertEq(phantomAmt, 0, "phantom userInfo.amount == 0 (zero-credit deposit)");

        // 4. Phantom nonetheless inserted into the staker set.
        assertEq(staker.stakerCount(address(dai)), 2, "BUG: phantom inserted despite 0 credit");
        bool phantomPresent = false;
        address[] memory stakers = staker.getStakers(address(dai));
        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakers[i] == phantom) phantomPresent = true;
        }
        assertTrue(phantomPresent, "phantom present in _stakers set");

        // 5. Terminal migration drains real principal; phantom keeps stakerCount at 1.
        vm.prank(migrator);
        staker.initiateMigration(address(dai));

        address[] memory batch = new address[](2);
        batch[0] = realUser;
        batch[1] = phantom; // explicitly attempt to evict the phantom
        vm.prank(migrator);
        staker.batchMigrate(address(dai), batch);

        // 6. totalStaked == 0 but phantom remains (amt==0 skip never removes it).
        (,,, uint256 totalStakedEnd) = staker.poolInfo(address(dai));
        assertEq(totalStakedEnd, 0, "all real principal drained; pool principal == 0");
        assertEq(staker.stakerCount(address(dai)), 1, "phantom survives batchMigrate");

        // 7. Phantom cannot be healed while Migrating.
        vm.prank(phantom);
        vm.expectRevert(bytes("StableStaker: nothing staked"));
        staker.userMigrate(address(dai));

        vm.prank(migrator);
        vm.expectRevert(bytes("StableStaker: pool not active"));
        staker.depositFor(address(dai), phantom, 1 ether);

        vm.prank(phantom);
        vm.expectRevert(bytes("StableStaker: pool not active"));
        staker.withdraw(address(dai), 1);

        assertEq(staker.stakerCount(address(dai)), 1, "phantom unremovable while Migrating");

        // 8. finalizeAndReset reverts forever with the exact string -> permanent freeze.
        vm.expectRevert(bytes("StableStaker: stakers remain"));
        staker.finalizeAndReset(address(dai));
    }
}
```
