// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MigratorV1V2.sol";
import "../src/PhlimboV2.sol";
import "./Mocks.sol";

/**
 * @title M-02 PoC: seedObligations missing MINIMUM_STAKE check bricks migrateDeposits
 *
 * @dev Vulnerability Location: src/MigratorV1V2.sol#L106-L142 (seedObligations)
 *      and src/MigratorV1V2.sol#L203-L239 (migrateDeposits).
 *      PhlimboV2.stake enforces `require(amount >= MINIMUM_STAKE, "Below minimum stake")`
 *      at src/PhlimboV2.sol#L324.
 *
 * VULNERABILITY SUMMARY:
 * `MigratorV1V2.seedObligations` does not validate that each non-zero `_deposits[i]`
 * is >= `PhlimboV2.MINIMUM_STAKE` (1e15). If any seeded deposit falls in (0, 1e15),
 * `migrateDeposits` will revert when it calls `phlimboV2.stake(deposits[i], users[i])`
 * with "Below minimum stake". Because `seeded` is a one-shot guard
 * (`require(!seeded, "Already seeded")`), there is NO on-chain remedy: the iterator
 * cannot advance past the bad entry, so every subsequent `migrateDeposits` call
 * reverts at the same index. The owner must `withdrawAll()`, redeploy a fresh
 * migrator, and re-wire V2 `setMigrator` + the phUSD mint role.
 *
 * ATTACK PATH (or operational mishap):
 * 1. Owner seeds five users; one user's deposit is 5e14 (below MINIMUM_STAKE=1e15).
 * 2. seedObligations accepts the bad value (no per-element minimum check).
 * 3. Owner funds the migrator with phUSD == totalPHUSD_deposited.
 * 4. Owner calls migrateDeposits — reverts on the offending index with
 *    "Below minimum stake".
 * 5. Retrying migrateDeposits reverts again with the same error: the loop never
 *    advances past index 2, so the migration is permanently stuck on-chain.
 */
contract M02PoC is Test {
    PhlimboV2 internal phlimboV2;
    MockFlax internal phUSD;
    MockStable internal usdc;
    MigratorV1V2 internal migrator;

    address internal owner = address(this);
    address internal alice = address(0xA1);
    address internal bob = address(0xB0);
    address internal carol = address(0xC0); // sub-minimum victim — chosen mid-array
    address internal dave = address(0xDA);
    address internal eve = address(0xE5);

    uint256 constant DEPLETION_DURATION = 604800;

    // Carol's deposit = 5e14 (below MINIMUM_STAKE=1e15). All other deposits well above.
    uint256 constant SUB_MIN_DEPOSIT = 5e14;
    uint256 constant MIN_STAKE = 1e15;

    function setUp() public {
        phUSD = new MockFlax();
        usdc = new MockStable();
        phlimboV2 = new PhlimboV2(address(phUSD), address(usdc), DEPLETION_DURATION);
        migrator = new MigratorV1V2(address(usdc), address(phUSD), address(phlimboV2));

        // Standard wiring from MigratorV1V2Test.setUp.
        phlimboV2.setMigrator(address(migrator));
        phUSD.setMinter(address(migrator), true);
    }

    function _users() internal view returns (address[] memory u) {
        u = new address[](5);
        u[0] = alice;
        u[1] = bob;
        u[2] = carol;
        u[3] = dave;
        u[4] = eve;
    }

    function test_M02_subMinimum_seed_bricks_migrateDeposits() public {
        // ----- Step 1: seed with carol@index=2 having deposit=5e14 (< 1e15) -----
        address[] memory users = _users();

        uint256[] memory deposits = new uint256[](5);
        deposits[0] = 100 ether;
        deposits[1] = 250 ether;
        deposits[2] = SUB_MIN_DEPOSIT; // <-- the poison entry; non-zero but below MIN_STAKE
        deposits[3] = 500 ether;
        deposits[4] = 180 ether;

        // USDC and phUSD-pending arrays are not the focus here; settleDebt is independent
        // of MINIMUM_STAKE. Set them to zero for everyone so we can exercise migrateDeposits
        // straight after seeding (settleDebt also goes to completion with totalUSDC=0,
        // but we skip it entirely since "Settlement complete" isn't required to reach the
        // migrate path — migrateDeposits only requires `seeded` and balance match).
        uint256[] memory usdcAmts = new uint256[](5);
        uint256[] memory phUSDAmts = new uint256[](5);

        // SANITY: MINIMUM_STAKE matches what we expect.
        assertEq(phlimboV2.MINIMUM_STAKE(), MIN_STAKE, "MIN_STAKE constant changed");
        assertLt(SUB_MIN_DEPOSIT, MIN_STAKE, "sub-min must be < MIN_STAKE");
        assertGt(SUB_MIN_DEPOSIT, 0, "sub-min must be > 0");

        // The vulnerable line: no per-element MINIMUM_STAKE validation here.
        migrator.seedObligations(users, deposits, usdcAmts, phUSDAmts);
        assertTrue(migrator.seeded(), "seeded set");

        uint256 totalDep = 100 ether + 250 ether + SUB_MIN_DEPOSIT + 500 ether + 180 ether;
        assertEq(migrator.totalPHUSD_deposited(), totalDep, "totalDep stored verbatim");

        // ----- Step 2: fund migrator with the EXACT phUSD float -----
        phUSD.mint(address(migrator), totalDep);

        // ----- Step 3: attempt migrateDeposits across the poison entry -----
        // First two users (alice, bob) migrate fine. The loop reverts at index 2 (carol).
        // Because the whole tx reverts, NO migrations are persisted — the iterator stays at 0.
        vm.expectRevert(bytes("Below minimum stake"));
        migrator.migrateDeposits(5);

        // ----- Step 4: confirm the migrator is permanently stuck -----
        // (a) iterator never advanced past 0 — alice didn't migrate either, despite being
        //     a perfectly valid entry, because the tx reverted atomically.
        assertEq(migrator.migrateIterator(), int256(0), "iterator stuck at 0");
        (uint256 aliceAmt,,) = phlimboV2.userInfo(alice);
        assertEq(aliceAmt, 0, "alice not migrated (atomic revert)");

        // (b) Re-trying any chunk size that reaches index 2 reverts again with the same error.
        vm.expectRevert(bytes("Below minimum stake"));
        migrator.migrateDeposits(5);

        vm.expectRevert(bytes("Below minimum stake"));
        migrator.migrateDeposits(3);

        // (c) Even trying to migrate ONE user at a time still reverts on the same iteration:
        //     index 0 (alice) migrates successfully → iterator becomes 1.
        //     index 1 (bob) migrates successfully   → iterator becomes 2.
        //     index 2 (carol) ALWAYS reverts because dep > 0 && dep < MIN_STAKE.
        //     The iterator cannot advance past 2 without losing carol's funds, and there is
        //     no skip / update / remove primitive in MigratorV1V2.
        migrator.migrateDeposits(1); // alice — succeeds
        assertEq(migrator.migrateIterator(), int256(1), "iter=1 after alice");

        migrator.migrateDeposits(1); // bob — succeeds
        assertEq(migrator.migrateIterator(), int256(2), "iter=2 after bob");

        // Now the iterator is parked AT carol. Any further call reverts forever.
        vm.expectRevert(bytes("Below minimum stake"));
        migrator.migrateDeposits(1);
        assertEq(migrator.migrateIterator(), int256(2), "iterator pinned at carol");

        // (d) seedObligations is one-shot — owner cannot re-seed to fix the bad entry.
        vm.expectRevert(bytes("Already seeded"));
        migrator.seedObligations(users, deposits, usdcAmts, phUSDAmts);

        // (e) Owner's only recourse is withdrawAll() + redeploy. Demonstrate the escape hatch
        //     drains funds but leaves the on-chain migration path permanently incomplete:
        //     dave and eve will never be migrated by THIS migrator.
        (uint256 daveAmtBefore,,) = phlimboV2.userInfo(dave);
        (uint256 eveAmtBefore,,) = phlimboV2.userInfo(eve);
        assertEq(daveAmtBefore, 0, "dave never migrated");
        assertEq(eveAmtBefore, 0, "eve never migrated");

        migrator.withdrawAll();
        // After withdrawAll, balance invariant breaks — even a chunk that would skip carol's
        // entry (impossible here, but if it were) would revert on the balance check first.
        vm.expectRevert(bytes("phUSD balance mismatch"));
        migrator.migrateDeposits(1);
    }
}
