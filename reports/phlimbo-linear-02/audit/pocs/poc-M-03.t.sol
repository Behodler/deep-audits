// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MigratorV1V2.sol";
import "../src/PhlimboV2.sol";
import "../src/Phlimbo.sol";
import "./Mocks.sol";

/**
 * @title M-03 PoC: MigratorV1V2 has no on-chain V1-drain enforcement
 * @notice Protocol value leak via a missing on-chain prerequisite check
 *
 * @dev Finding: M-03
 *      Contract: MigratorV1V2 (workspace/phlimbo-linear/src/MigratorV1V2.sol)
 *      Lines: 106-239 (seedObligations / migrateDeposits)
 *
 * SUMMARY OF THE ISSUE
 * --------------------
 * MigratorV1V2 only ever reads an off-chain snapshot of V1 state. It never
 * references the live V1 contract. `seedObligations` records (users, deposits,
 * usdcOwed, phUSDOwed) verbatim; `migrateDeposits` then calls
 * `phlimboV2.stake(deposits[i], users[i])` using phUSD that the OWNER pre-funded
 * into the migrator. The migrator does NOT:
 *   (a) pause V1,
 *   (b) drain V1 via `Phlimbo.emergencyTransfer`,
 *   (c) check `Phlimbo.userInfo(user).amount == 0` per user, or
 *   (d) check `phUSD.balanceOf(V1) == 0` at seed time.
 *
 * The operational assumption — that V1 has been drained or frozen so users
 * cannot recover their original V1 phUSD — is undocumented in the migrator's
 * code-level prerequisites (NatSpec only enumerates phUSD mint role and
 * `PhlimboV2.setMigrator`) and not enforced anywhere.
 *
 * FRAMING (important)
 * -------------------
 * The user in this PoC is NOT performing an attack. They are exercising a
 * legitimate withdrawal right that V1's public interface continues to expose
 * during the migration window. The V1 user redeems their original V1 phUSD,
 * and SEPARATELY the migrator (which the owner has pre-funded) credits them a
 * fresh V2 stake. The duplication is a code-design omission in the migrator,
 * not a malicious action by the user.
 *
 * INTENDED FLOW (per MigratorV1V2 NatSpec)
 * ----------------------------------------
 *   1. Owner deploys MigratorV1V2.
 *   2. Owner takes off-chain V1 snapshot.
 *   3. Owner calls `seedObligations(...)`.
 *   4. Owner funds migrator with USDC + phUSD.
 *   5. (Owner-side, undocumented) V1 is supposedly drained via
 *      `Phlimbo.emergencyTransfer` BEFORE migrate runs. <--- not on-chain enforced
 *   6. Owner calls `settleDebt(...)` and `migrateDeposits(...)`.
 *
 * WHAT THIS POC DEMONSTRATES
 * --------------------------
 * The PoC follows the documented flow EXCEPT for the (un-enforced) step 5.
 * It proves that when step 5 is omitted, every user listed in `seedObligations`
 * who happens to withdraw from V1 in the gap between `seedObligations` and
 * `migrateDeposits` ends up holding ~2x their nominal V1 principal:
 *   - V1-withdrawn phUSD lands in their wallet,
 *   - The migrator stakes another (equivalent) phUSD position into V2 for them,
 *   - The user then withdraws from V2 to realize the duplicated principal.
 *
 * Two scenarios are exercised:
 *   test_M03_UnpausedV1Withdrawal           V1 left unpaused; user calls V1.withdraw
 *   test_M03_PausedV1NotDrained             V1 paused but not drained; user calls V1.pauseWithdraw
 */
contract M03PoCTest is Test {
    // ---------- contracts ----------
    MockFlax public phUSD;
    MockStable public usdc;
    PhlimboEA public phlimboV1;
    PhlimboV2 public phlimboV2;
    MigratorV1V2 public migrator;

    // ---------- actors ----------
    address public owner = address(this);
    address public alice = address(0xA11CE);
    address public pauser = address(0xBA5E);

    // ---------- parameters ----------
    uint256 constant DEPLETION_DURATION = 7 days;
    uint256 constant ALICE_DEPOSIT = 100 ether;

    function setUp() public {
        phUSD = new MockFlax();
        usdc = new MockStable();

        // Deploy V1
        phlimboV1 = new PhlimboEA(address(phUSD), address(usdc), DEPLETION_DURATION);
        phUSD.setMinter(address(phlimboV1), true);
        phlimboV1.setPauser(pauser);

        // Deploy V2 + migrator
        phlimboV2 = new PhlimboV2(address(phUSD), address(usdc), DEPLETION_DURATION);
        migrator = new MigratorV1V2(address(usdc), address(phUSD), address(phlimboV2));
        phlimboV2.setMigrator(address(migrator));
        phUSD.setMinter(address(migrator), true);
    }

    // ---------------------------------------------------------------------
    // SCENARIO 1: V1 left unpaused — user calls V1.withdraw between seed
    // and migrateDeposits. This is the "happy" withdrawal path on V1 and
    // demonstrates that any user (without doing anything irregular) ends up
    // with double their principal because the migrator does not enforce a
    // V1-drain precondition.
    // ---------------------------------------------------------------------
    function test_M03_UnpausedV1Withdrawal() public {
        console.log("=== M-03 PoC (Scenario 1): V1 unpaused, user calls V1.withdraw ===");
        console.log("");

        // ---- Step 1: Alice stakes in V1 (legitimate user activity pre-migration) ----
        console.log("Step 1: Alice stakes %s phUSD in V1", ALICE_DEPOSIT);
        phUSD.mint(alice, ALICE_DEPOSIT);
        vm.startPrank(alice);
        phUSD.approve(address(phlimboV1), type(uint256).max);
        phlimboV1.stake(ALICE_DEPOSIT, alice);
        vm.stopPrank();

        // Sanity: Alice has the V1 position; her wallet phUSD is 0.
        (uint256 v1Amount, , ) = phlimboV1.userInfo(alice);
        assertEq(v1Amount, ALICE_DEPOSIT, "Alice V1 position");
        assertEq(phUSD.balanceOf(alice), 0, "Alice wallet phUSD pre-migration");

        // ---- Step 2: owner takes off-chain snapshot, seeds the migrator ----
        // (Off-chain snapshot is just reading V1.userInfo at the snapshot block.)
        console.log("Step 2: Owner takes V1 snapshot and calls seedObligations");
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = ALICE_DEPOSIT;
        uint256[] memory usdcArr = new uint256[](1);
        usdcArr[0] = 0; // no USDC accrual yet — keeps this PoC focused on principal duplication
        uint256[] memory phUSDArr = new uint256[](1);
        phUSDArr[0] = 0; // no phUSD reward accrual — same reason

        migrator.seedObligations(users, deposits, usdcArr, phUSDArr);

        // ---- Step 3: owner funds the migrator with phUSD on Alice's behalf ----
        // This is the "migration float": owner-provided phUSD that will be
        // re-staked into V2 for the seeded user set.
        console.log("Step 3: Owner funds migrator with %s phUSD migration float", ALICE_DEPOSIT);
        phUSD.mint(address(migrator), ALICE_DEPOSIT);

        // ---- Step 4: BETWEEN seed and migrate, Alice exercises her V1 withdraw right ----
        //
        // This is a normal V1.withdraw call. V1 is whenNotPaused and Alice's
        // userInfo is still intact. Nothing in MigratorV1V2 prevents this.
        // The migrator does not know V1 even exists.
        console.log("Step 4: Alice calls V1.withdraw -- V1 is still operational");
        vm.prank(alice);
        phlimboV1.withdraw(ALICE_DEPOSIT);

        assertEq(phUSD.balanceOf(alice), ALICE_DEPOSIT, "Alice received V1 principal back");
        (uint256 v1AmountAfter, , ) = phlimboV1.userInfo(alice);
        assertEq(v1AmountAfter, 0, "Alice's V1 position now zero");

        // ---- Step 5: owner finishes the documented migration flow ----
        // From the migrator's perspective, nothing is wrong: its balance
        // invariant (phUSD.balanceOf(this) == totalPHUSD_deposited) still
        // holds because Alice withdrew from V1, not from the migrator.
        console.log("Step 5: Owner calls migrateDeposits -- migrator stakes Alice into V2");
        migrator.migrateDeposits(10);

        (uint256 v2Amount, , ) = phlimboV2.userInfo(alice);
        assertEq(v2Amount, ALICE_DEPOSIT, "Alice has a fresh V2 position credited by migrator");

        // ---- Step 6: Alice realizes the V2 position ----
        // PhlimboV2.withdraw(amount, user): msg.sender must equal user (Alice).
        // Tokens are transferred to msg.sender. Owner has not paused V2.
        console.log("Step 6: Alice calls V2.withdraw to realize the duplicated principal");
        vm.prank(alice);
        phlimboV2.withdraw(ALICE_DEPOSIT, alice);

        // ---- Final assertion: protocol leak ----
        uint256 aliceFinalPhUSD = phUSD.balanceOf(alice);
        console.log("Alice final phUSD wallet balance: %s", aliceFinalPhUSD);
        console.log("Alice original V1 principal     : %s", ALICE_DEPOSIT);
        console.log("Ratio (final / original)        : ~%s x", aliceFinalPhUSD / ALICE_DEPOSIT);

        assertEq(
            aliceFinalPhUSD,
            2 * ALICE_DEPOSIT,
            "Alice ends up with 2x V1 principal: 1x from V1.withdraw + 1x from migrator-funded V2 stake"
        );

        // The V1 contract still holds nothing on Alice's behalf; the migrator's
        // phUSD float is fully drained; the unfunded position came from owner
        // funds (the protocol). This is the value leak.
        assertEq(phUSD.balanceOf(address(migrator)), 0, "Migrator drained as documented");
        assertEq(migrator.totalPHUSD_deposited(), 0, "Migrator considers migration complete");

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED: 2x principal leaked to seeded user ===");
        console.log("Root cause: MigratorV1V2 enforces no on-chain check that V1 is drained.");
    }

    // ---------------------------------------------------------------------
    // SCENARIO 2: Operator pauses V1 (a partial mitigation they might
    // attempt) but FORGETS to drain via `Phlimbo.emergencyTransfer`. The
    // user still recovers their V1 phUSD via `Phlimbo.pauseWithdraw`, which
    // remains callable whenPaused. Same end state: 2x principal.
    // ---------------------------------------------------------------------
    function test_M03_PausedV1NotDrained() public {
        console.log("=== M-03 PoC (Scenario 2): V1 paused but NOT drained ===");
        console.log("");

        // Step 1: Alice stakes in V1.
        phUSD.mint(alice, ALICE_DEPOSIT);
        vm.startPrank(alice);
        phUSD.approve(address(phlimboV1), type(uint256).max);
        phlimboV1.stake(ALICE_DEPOSIT, alice);
        vm.stopPrank();

        // Step 2: Owner seeds the migrator from the snapshot.
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = ALICE_DEPOSIT;
        uint256[] memory usdcArr = new uint256[](1);
        uint256[] memory phUSDArr = new uint256[](1);
        migrator.seedObligations(users, deposits, usdcArr, phUSDArr);

        // Step 3: Owner funds migrator.
        phUSD.mint(address(migrator), ALICE_DEPOSIT);

        // Step 4: Owner pauses V1 — but does NOT call `emergencyTransfer`.
        // This is the partial-mitigation case the finding warns about: pause
        // alone is insufficient because pauseWithdraw remains whenPaused.
        console.log("Step 4: Pauser pauses V1 (but no emergencyTransfer drain follows)");
        vm.prank(pauser);
        phlimboV1.pause();

        // Step 5: Alice uses the pause-time emergency exit on V1.
        console.log("Step 5: Alice calls V1.pauseWithdraw");
        vm.prank(alice);
        phlimboV1.pauseWithdraw(ALICE_DEPOSIT);
        assertEq(phUSD.balanceOf(alice), ALICE_DEPOSIT, "Alice received V1 principal back via pauseWithdraw");

        // Step 6: Owner runs migrateDeposits — migrator stakes Alice into V2.
        console.log("Step 6: Owner calls migrateDeposits");
        migrator.migrateDeposits(10);
        (uint256 v2Amount, , ) = phlimboV2.userInfo(alice);
        assertEq(v2Amount, ALICE_DEPOSIT, "Alice has a V2 position from the migrator's float");

        // Step 7: Alice realizes V2 position.
        vm.prank(alice);
        phlimboV2.withdraw(ALICE_DEPOSIT, alice);

        // Final assertion: 2x principal.
        uint256 aliceFinalPhUSD = phUSD.balanceOf(alice);
        console.log("Alice final phUSD wallet balance: %s", aliceFinalPhUSD);

        assertEq(
            aliceFinalPhUSD,
            2 * ALICE_DEPOSIT,
            "Pausing V1 without draining it via emergencyTransfer does not prevent the leak"
        );

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED in pause-but-not-drained variant ===");
    }

    // ---------------------------------------------------------------------
    // CONTROL: When V1 has been drained via emergencyTransfer (the
    // un-enforced operational prerequisite that the finding recommends
    // turning into a code-level invariant), the leak does NOT occur because
    // V1.withdraw and V1.pauseWithdraw both revert (insufficient balance on
    // safeTransfer). This test documents that mitigation is a function of
    // operator discipline only — not enforced by MigratorV1V2.
    // ---------------------------------------------------------------------
    function test_M03_DrainedV1_NoLeak_Control() public {
        console.log("=== M-03 PoC (Control): V1 drained via emergencyTransfer ===");
        console.log("");

        // Step 1: Alice stakes in V1.
        phUSD.mint(alice, ALICE_DEPOSIT);
        vm.startPrank(alice);
        phUSD.approve(address(phlimboV1), type(uint256).max);
        phlimboV1.stake(ALICE_DEPOSIT, alice);
        vm.stopPrank();

        // Step 2: Owner seeds the migrator.
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = ALICE_DEPOSIT;
        uint256[] memory usdcArr = new uint256[](1);
        uint256[] memory phUSDArr = new uint256[](1);
        migrator.seedObligations(users, deposits, usdcArr, phUSDArr);

        // Step 3: Owner funds migrator.
        phUSD.mint(address(migrator), ALICE_DEPOSIT);

        // Step 4: Owner performs the un-enforced prerequisite — drain V1.
        // `emergencyTransfer` moves all V1 phUSD out and pauses V1.
        console.log("Step 4: Owner calls V1.emergencyTransfer to drain V1");
        phlimboV1.emergencyTransfer(owner);

        // Step 5: Alice tries to recover her V1 principal — both paths revert.
        // V1.withdraw is whenNotPaused — V1 was paused by emergencyTransfer.
        vm.prank(alice);
        vm.expectRevert();
        phlimboV1.withdraw(ALICE_DEPOSIT);

        // V1.pauseWithdraw is callable whenPaused but the safeTransfer
        // reverts because V1 holds no phUSD anymore.
        vm.prank(alice);
        vm.expectRevert();
        phlimboV1.pauseWithdraw(ALICE_DEPOSIT);

        // Step 6: Owner finishes migration normally.
        migrator.migrateDeposits(10);
        (uint256 v2Amount, , ) = phlimboV2.userInfo(alice);
        assertEq(v2Amount, ALICE_DEPOSIT, "Alice has the V2 position credited by the migrator");

        // Step 7: Alice realizes her V2 position — single principal, no leak.
        vm.prank(alice);
        phlimboV2.withdraw(ALICE_DEPOSIT, alice);

        assertEq(phUSD.balanceOf(alice), ALICE_DEPOSIT, "Alice has exactly her original V1 principal");
        console.log("Alice final phUSD: %s (single principal, no leak)", phUSD.balanceOf(alice));
        console.log("");
        console.log("This control confirms the mitigation is purely OPERATIONAL.");
        console.log("MigratorV1V2 has no code that detects or enforces the drain.");
    }
}
