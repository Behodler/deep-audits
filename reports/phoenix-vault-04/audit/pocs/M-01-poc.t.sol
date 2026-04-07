// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AYieldStrategy.sol";
import "../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../src/mocks/MockERC20.sol";
import "./mocks/MockERC4626Vault.sol";
import "./mocks/MockAMMAdapter.sol";

/**
 * @title PoC_M01_EmergencyWithdrawSkewsAccountingAndBypassesDelay
 * @notice Proof of Concept for finding M-01
 *
 * @dev Vulnerability Locations:
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:350-359 (_emergencyWithdraw)
 *      - src/AYieldStrategy.sol:227-233 (emergencyWithdraw - onlyOwner, no delay, no whenNotPaused)
 *
 * VULNERABILITY SUMMARY:
 *   `_emergencyWithdraw(uint256 amount)` is called by the parent
 *   `AYieldStrategy.emergencyWithdraw()`, which is gated only by `onlyOwner` -- no
 *   24h waiting period, no 48h execution window, no `whenNotPaused`. The child
 *   implementation transfers raw vault SHARES directly to the owner via
 *   `IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer)` -- bypassing
 *   the AMM, bypassing the documented two-phase rugpull-protection delay used by
 *   `totalWithdrawal()`, AND leaving `clientBalances[*][*]` and `totalDeposited[*]`
 *   completely untouched.
 *
 *   Two distinct bugs co-exist in one function:
 *
 *   BUG A (delay bypass):
 *     `totalWithdrawal()` requires Phase 1 -> 24h wait -> Phase 2 within 48h, which
 *     the project's docs describe as "rugpull protection" / community delay.
 *     `emergencyWithdraw()` provides a one-tx escape hatch with NONE of those
 *     guards. An owner can drain all vault shares in a single transaction.
 *
 *   BUG B (accounting skew):
 *     `_emergencyWithdraw` only moves the SHARE token; it never decrements
 *     `clientBalances` or `totalDeposited`. After the call:
 *       - vault.balanceOf(strategy)            == 0  (drained)
 *       - strategy.principalOf(token, alice)   == 1000e18  (STALE / inflated)
 *       - strategy.getTotalDeposited(token)    == 2000e18  (STALE / inflated)
 *       - strategy.totalBalanceOf(token, alice)== 0       (computed live from
 *                                                          drained shares -- so
 *                                                          users see "I have 1000
 *                                                          principal but my
 *                                                          totalBalance is 0")
 *
 *   Subsequent legitimate `client.withdraw(token, 1000e18, ...)` calls are routed
 *   through `_withdrawInternal`, which decrements `clientBalances[alice]` by the
 *   *requested* amount, but the underlying swap pulls 0 shares (since
 *   `availableShares == 0`). The user's principal is silently zeroed while they
 *   receive zero underlying.
 *
 *   This is the textbook combination of (a) skipping a documented protective
 *   delay and (b) leaving global accounting in a permanently desynced state.
 */
contract PoC_M01_EmergencyWithdrawSkewsAccountingAndBypassesDelay is Test {
    ERC4626MarketYieldStrategy strategy;
    MockERC20 underlyingToken;
    MockERC4626Vault erc4626Vault;
    MockAMMAdapter ammAdapter;

    address owner = address(0x1234);
    address client = address(0x5678);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant INITIAL_TOKEN_SUPPLY = 10_000_000e18;
    uint256 constant DEPOSIT_AMOUNT = 1000e18;

    function setUp() public {
        // Deploy mock tokens
        underlyingToken = new MockERC20("Underlying", "UNDERLYING", 18);

        // Deploy mock ERC4626 vault
        erc4626Vault = new MockERC4626Vault("Vault Shares", "vUNDERLYING", address(underlyingToken));

        // Deploy mock AMM adapter
        ammAdapter = new MockAMMAdapter();

        // Deploy strategy
        vm.prank(owner);
        strategy = new ERC4626MarketYieldStrategy(
            owner,
            address(underlyingToken),
            address(erc4626Vault),
            address(ammAdapter)
        );

        // Set 1:1 exchange rates for underlying <-> vault tokens
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        // Mint tokens to client (which will deposit on behalf of alice and bob)
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
        strategy.setSlippageTolerance(100); // 1% slippage tolerance
        vm.stopPrank();

        // Approve strategy to spend client's tokens
        vm.prank(client);
        underlyingToken.approve(address(strategy), type(uint256).max);

        // Two clients each deposit 1000 underlying
        vm.prank(client);
        strategy.deposit(address(underlyingToken), DEPOSIT_AMOUNT, alice);

        vm.prank(client);
        strategy.deposit(address(underlyingToken), DEPOSIT_AMOUNT, bob);

        // Sanity-check the starting state
        assertEq(
            strategy.principalOf(address(underlyingToken), alice),
            DEPOSIT_AMOUNT,
            "alice principal should be 1000"
        );
        assertEq(
            strategy.principalOf(address(underlyingToken), bob),
            DEPOSIT_AMOUNT,
            "bob principal should be 1000"
        );
        assertEq(
            strategy.getTotalDeposited(address(underlyingToken)),
            2 * DEPOSIT_AMOUNT,
            "totalDeposited should be 2000"
        );
        assertEq(
            strategy.getTotalShares(),
            2 * DEPOSIT_AMOUNT,
            "strategy should hold 2000 vault shares (1:1)"
        );
    }

    /**
     * @notice BUG A: emergencyWithdraw is a one-transaction owner drain.
     *         No 24h waiting period, no 48h execution window, no `whenNotPaused`.
     *
     *         This is the "rugpull bypass": `totalWithdrawal()` enforces
     *         WAITING_PERIOD = 24h + EXECUTION_WINDOW = 48h, but
     *         `emergencyWithdraw()` enforces NOTHING beyond `onlyOwner`.
     */
    function test_EmergencyWithdrawIsSingleTransactionNoDelay() public {
        console.log("=== M-01 BUG A: rugpull-delay bypass ===");
        console.log("");

        uint256 totalShares = strategy.getTotalShares();
        uint256 ownerVaultBalanceBefore = erc4626Vault.balanceOf(owner);
        uint256 strategyVaultBalanceBefore = erc4626Vault.balanceOf(address(strategy));
        uint256 startTimestamp = block.timestamp;

        console.log("Vault constants from AYieldStrategy:");
        console.log("  WAITING_PERIOD  (sec):", strategy.WAITING_PERIOD());
        console.log("  EXECUTION_WINDOW(sec):", strategy.EXECUTION_WINDOW());
        console.log("  TOTAL_DURATION  (sec):", strategy.TOTAL_DURATION());
        console.log("");
        console.log("Strategy state BEFORE emergencyWithdraw:");
        console.log("  vault.balanceOf(strategy):", strategyVaultBalanceBefore);
        console.log("  vault.balanceOf(owner):   ", ownerVaultBalanceBefore);
        console.log("  block.timestamp:          ", startTimestamp);

        // CRITICAL: NO vm.warp() calls before this. NO Phase 1 / Phase 2.
        // Owner drains in a SINGLE transaction with NO time advancement at all.
        vm.prank(owner);
        strategy.emergencyWithdraw(totalShares);

        uint256 ownerVaultBalanceAfter = erc4626Vault.balanceOf(owner);
        uint256 strategyVaultBalanceAfter = erc4626Vault.balanceOf(address(strategy));
        uint256 endTimestamp = block.timestamp;

        console.log("");
        console.log("Strategy state AFTER emergencyWithdraw:");
        console.log("  vault.balanceOf(strategy):", strategyVaultBalanceAfter);
        console.log("  vault.balanceOf(owner):   ", ownerVaultBalanceAfter);
        console.log("  block.timestamp:          ", endTimestamp);

        // ============ ASSERTIONS: bypass proven ============

        // 1. NO time elapsed -- the entire drain happened in one tx with no warp.
        assertEq(
            endTimestamp,
            startTimestamp,
            "BUG A: drain executed without ANY time advancement"
        );

        // 2. Strategy was fully drained of shares.
        assertEq(strategyVaultBalanceAfter, 0, "strategy share balance must be 0 (drained)");

        // 3. Owner now directly holds ALL the vault shares.
        assertEq(
            ownerVaultBalanceAfter - ownerVaultBalanceBefore,
            totalShares,
            "owner directly holds the drained shares (no AMM, no underlying)"
        );

        // 4. Confirm the documented protection (totalWithdrawal Phase 1 / Phase 2)
        //    is meaningfully different in scope: it has a 24h delay before any
        //    funds can move. emergencyWithdraw skipped that entirely.
        assertGt(
            strategy.WAITING_PERIOD(),
            0,
            "documented rugpull-protection delay exists for totalWithdrawal..."
        );
        assertEq(
            endTimestamp - startTimestamp,
            0,
            "...but emergencyWithdraw bypasses it entirely (0s elapsed)"
        );

        console.log("");
        console.log("=== BUG A CONFIRMED ===");
        console.log("Owner drained the entire share pool in one tx, with");
        console.log("0 seconds elapsed -- no Phase 1, no 24h wait, no Phase 2.");
        console.log("documented WAITING_PERIOD:", strategy.WAITING_PERIOD());
        console.log("seconds actually elapsed:  ", endTimestamp - startTimestamp);
    }

    /**
     * @notice BUG B: emergencyWithdraw leaves clientBalances/totalDeposited
     *         permanently stale, producing accounting skew that breaks every
     *         downstream view function and silently zeroes user principal on
     *         the next withdraw().
     */
    function test_EmergencyWithdrawLeavesAccountingStale() public {
        console.log("=== M-01 BUG B: accounting skew ===");
        console.log("");

        // ----- Pre-state -----
        uint256 alicePrincipalBefore = strategy.principalOf(address(underlyingToken), alice);
        uint256 bobPrincipalBefore = strategy.principalOf(address(underlyingToken), bob);
        uint256 totalDepositedBefore = strategy.getTotalDeposited(address(underlyingToken));
        uint256 totalSharesBefore = strategy.getTotalShares();
        uint256 aliceTotalBalanceBefore = strategy.totalBalanceOf(address(underlyingToken), alice);

        console.log("BEFORE emergencyWithdraw:");
        console.log("  alice.principalOf:      ", alicePrincipalBefore);
        console.log("  bob.principalOf:        ", bobPrincipalBefore);
        console.log("  getTotalDeposited:      ", totalDepositedBefore);
        console.log("  getTotalShares:         ", totalSharesBefore);
        console.log("  alice.totalBalanceOf:   ", aliceTotalBalanceBefore);

        assertEq(alicePrincipalBefore, DEPOSIT_AMOUNT, "alice principal == 1000");
        assertEq(bobPrincipalBefore, DEPOSIT_AMOUNT, "bob principal == 1000");
        assertEq(totalDepositedBefore, 2 * DEPOSIT_AMOUNT, "totalDeposited == 2000");
        assertEq(totalSharesBefore, 2 * DEPOSIT_AMOUNT, "totalShares == 2000");
        assertEq(aliceTotalBalanceBefore, DEPOSIT_AMOUNT, "alice totalBalance == 1000");

        // ----- Owner drains everything via emergencyWithdraw -----
        vm.prank(owner);
        strategy.emergencyWithdraw(2 * DEPOSIT_AMOUNT);

        // ----- Post-state -----
        uint256 alicePrincipalAfter = strategy.principalOf(address(underlyingToken), alice);
        uint256 bobPrincipalAfter = strategy.principalOf(address(underlyingToken), bob);
        uint256 totalDepositedAfter = strategy.getTotalDeposited(address(underlyingToken));
        uint256 totalSharesAfter = strategy.getTotalShares();
        uint256 aliceTotalBalanceAfter = strategy.totalBalanceOf(address(underlyingToken), alice);

        console.log("");
        console.log("AFTER  emergencyWithdraw:");
        console.log("  alice.principalOf:      ", alicePrincipalAfter, "(STALE)");
        console.log("  bob.principalOf:        ", bobPrincipalAfter, "(STALE)");
        console.log("  getTotalDeposited:      ", totalDepositedAfter, "(STALE)");
        console.log("  getTotalShares:         ", totalSharesAfter, "(real)");
        console.log("  alice.totalBalanceOf:   ", aliceTotalBalanceAfter, "(real, computed live)");
        console.log("  vault.balanceOf(owner): ", erc4626Vault.balanceOf(owner));

        // ============ ASSERTIONS: skew proven ============

        // (1) clientBalances UNCHANGED -- principal is permanently stale.
        assertEq(
            alicePrincipalAfter,
            DEPOSIT_AMOUNT,
            "BUG B: alice.principalOf STILL equals 1000 even though all shares were drained"
        );
        assertEq(
            bobPrincipalAfter,
            DEPOSIT_AMOUNT,
            "BUG B: bob.principalOf STILL equals 1000 even though all shares were drained"
        );

        // (2) totalDeposited UNCHANGED.
        assertEq(
            totalDepositedAfter,
            2 * DEPOSIT_AMOUNT,
            "BUG B: getTotalDeposited STILL equals 2000 (denominator is now permanently stale)"
        );

        // (3) Real share holdings have moved entirely to owner.
        assertEq(totalSharesAfter, 0, "strategy now holds 0 vault shares");
        assertEq(
            erc4626Vault.balanceOf(owner),
            2 * DEPOSIT_AMOUNT,
            "owner directly holds the 2000 drained vault shares"
        );

        // (4) totalBalanceOf is computed LIVE from shares -- so it now returns 0.
        //     This means the strategy reports the textbook contradiction:
        //         principalOf(alice) == 1000  but  totalBalanceOf(alice) == 0
        assertEq(
            aliceTotalBalanceAfter,
            0,
            "BUG B: alice.totalBalanceOf == 0 because shares are gone -- contradicts principalOf == 1000"
        );

        // The contradiction itself, asserted explicitly:
        assertGt(
            alicePrincipalAfter,
            aliceTotalBalanceAfter,
            "BUG B: principal > totalBalance -- impossible state for a healthy vault"
        );

        console.log("");
        console.log("CONTRADICTION:");
        console.log("  alice.principalOf:    ", alicePrincipalAfter);
        console.log("  alice.totalBalanceOf: ", aliceTotalBalanceAfter);
        console.log("  (principal > totalBalance is impossible in a healthy vault)");

        // ----- (5) Downstream effect: alice's withdraw silently zeroes principal -----
        // alice tries to withdraw her full 1000 principal via the authorized client.
        // _withdrawInternal will:
        //   - cap amount to availablePrincipal (1000) -- still 1000, principal is stale-high
        //   - convertToShares(1000) = 1000 ideal shares
        //   - cap sharesToSell to availableShares = 0
        //   - swap(vault->underlying, 0) returns 0
        //   - transfer 0 underlying to alice
        //   - decrement clientBalances[alice] by REQUESTED amount (1000)
        //   - decrement totalDeposited by REQUESTED amount (1000)
        //
        // Net result: alice's principal goes from 1000 -> 0 while she receives 0
        // underlying. The user is fully wiped on paper but received nothing.
        //
        // Note: convertToAssets(0) = 0, idealUnderlying = 0, minOut = 0, so
        // the swap will not revert on slippage -- this path is reachable.

        uint256 aliceUnderlyingBefore = underlyingToken.balanceOf(alice);

        vm.prank(client);
        try strategy.withdraw(address(underlyingToken), DEPOSIT_AMOUNT, alice) {
            // Withdraw succeeded silently.
            uint256 aliceUnderlyingAfter = underlyingToken.balanceOf(alice);
            uint256 received = aliceUnderlyingAfter - aliceUnderlyingBefore;

            console.log("");
            console.log("AFTER alice.withdraw(1000) (silent zero path):");
            console.log("  underlying received by alice:", received);
            console.log("  alice.principalOf now:       ", strategy.principalOf(address(underlyingToken), alice));

            assertEq(received, 0, "alice received 0 underlying despite requesting 1000");
            assertEq(
                strategy.principalOf(address(underlyingToken), alice),
                0,
                "alice's principal was silently zeroed by the withdraw call"
            );

            console.log("  -> alice principal silently zeroed; alice received 0 underlying");
        } catch Error(string memory reason) {
            // Acceptable alternative: withdrawal reverts because the share pool
            // is empty. Either branch (silent zero or revert) demonstrates that
            // the accounting skew has broken the user's ability to safely
            // withdraw their stated principal.
            console.log("");
            console.log("AFTER alice.withdraw(1000) -> reverted with:", reason);
            assertTrue(
                bytes(reason).length > 0,
                "withdraw reverted; alice cannot retrieve her principal either way"
            );
        }

        console.log("");
        console.log("=== BUG B CONFIRMED ===");
        console.log("clientBalances + totalDeposited are permanently desynced from");
        console.log("the actual share pool. principalOf(alice) > totalBalanceOf(alice),");
        console.log("and alice's next withdraw either silently zeros her or reverts.");
    }
}
