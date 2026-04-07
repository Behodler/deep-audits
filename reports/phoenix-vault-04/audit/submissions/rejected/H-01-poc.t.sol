// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../src/mocks/MockERC20.sol";
import "./mocks/MockERC4626Vault.sol";
import "./mocks/MockAMMAdapter.sol";

/**
 * @title PoC_H01_BankRunOnPegLoss
 * @notice Proof of Concept for finding H-02
 *
 *         Withdraws decrement principal by REQUESTED not RECEIVED and have no proportional
 *         share cap, converting any peg/AMM dislocation between withdrawals into a winner-
 *         takes-all bank run that mixes client share pools.
 *
 * @dev Vulnerability locations:
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L302-L339 (_withdrawInternal)
 *      - src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L335-L336 (principal debit)
 *
 * VULNERABILITY:
 *      `_withdrawInternal` swaps `sharesToSell` for whatever the AMM is willing to give
 *      (`underlyingReceived`), but then debits the caller's `clientBalances` and the
 *      pool-wide `totalDeposited` by the *requested* `amount` rather than the *received*
 *      amount. There is also no proportional cap that ties a single client's withdrawal
 *      to their pro-rata share of the strategy's vault shares. This produces two related
 *      pathologies:
 *
 *      1. Asymmetric loss: a client who withdraws while the AMM is at a fair rate gets
 *         their full principal back, while a client who withdraws after the AMM dislocates
 *         receives substantially less than their principal — even though both clients
 *         had identical positions and identical fair claims a moment earlier.
 *
 *      2. Pool mixing / bank run: because principal is debited by the requested amount,
 *         the first withdrawer can drain a disproportionate share of the strategy's vault
 *         shares relative to their fair pro-rata claim, leaving the remaining clients
 *         with a depleted share pool from which to redeem the same nominal principal.
 *
 *      This PoC demonstrates pathology (1) directly: two clients with identical 1000e18
 *      deposits at a fair 1:1 AMM rate. Alice withdraws first while the AMM is at 1:1 and
 *      receives her full principal. The AMM then dislocates to 0.5 (a 50% peg loss).
 *      Bob withdraws his identical 1000e18 principal and receives only ~500e18 — a 50%
 *      loss on the same nominal claim Alice just exited cleanly. Bob's `clientBalances`
 *      and `totalDeposited` are nonetheless debited by the full 1000e18, so the strategy
 *      has no record of Bob's missing funds and there is no recourse.
 *
 * ATTACK PATH (rational user behavior):
 *      1. Alice and Bob each deposit 1000e18 underlying through the strategy.
 *      2. AMM is at fair 1:1 rate; owner has set 1% slippage tolerance.
 *      3. Alice withdraws her full 1000e18 principal — receives 1000e18 underlying.
 *      4. AMM rate dislocates to 0.5 (e.g., depeg, market crash, or low-liquidity attack).
 *      5. Owner widens slippage tolerance so withdraws can clear at the new market price
 *         (a realistic operational response — otherwise withdrawals are bricked entirely).
 *      6. Bob withdraws his identical 1000e18 principal — receives only ~500e18 underlying.
 *      7. Bob's principal is fully debited even though he was shorted ~500e18.
 */
contract PoC_H01_BankRunOnPegLoss is Test {
    ERC4626MarketYieldStrategy strategy;
    MockERC20 underlyingToken;
    MockERC4626Vault erc4626Vault;
    MockAMMAdapter ammAdapter;

    address owner = address(0x1234);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant DEPOSIT = 1000e18;
    uint256 constant INITIAL_TOKEN_SUPPLY = 10_000_000e18;

    function setUp() public {
        // Deploy mock underlying, mock ERC4626 vault, and mock AMM adapter.
        underlyingToken = new MockERC20("Underlying", "UNDERLYING", 18);
        erc4626Vault = new MockERC4626Vault("Vault Shares", "vUNDERLYING", address(underlyingToken));
        ammAdapter = new MockAMMAdapter();

        // Deploy the strategy under test.
        vm.prank(owner);
        strategy = new ERC4626MarketYieldStrategy(
            owner,
            address(underlyingToken),
            address(erc4626Vault),
            address(ammAdapter)
        );

        // Start with a fair 1:1 AMM rate in both directions.
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        // Fund the AMM adapter with vault-share reserves so it can serve deposit swaps.
        underlyingToken.mint(address(this), INITIAL_TOKEN_SUPPLY);
        underlyingToken.approve(address(erc4626Vault), INITIAL_TOKEN_SUPPLY);
        erc4626Vault.deposit(INITIAL_TOKEN_SUPPLY, address(ammAdapter));

        // Fund the AMM adapter with underlying reserves so it can serve withdraw swaps.
        underlyingToken.mint(address(ammAdapter), INITIAL_TOKEN_SUPPLY);

        // Authorize Alice and Bob as clients (they are the entities calling deposit/withdraw).
        // For audit purposes, "clients" here are the integrating accounts; we model two
        // independent clients to expose the asymmetric loss between them.
        vm.startPrank(owner);
        strategy.setClient(alice, true);
        strategy.setClient(bob, true);
        strategy.setSlippageTolerance(100); // 1% default slippage
        vm.stopPrank();

        // Mint and approve underlying for both clients.
        underlyingToken.mint(alice, DEPOSIT);
        underlyingToken.mint(bob, DEPOSIT);

        vm.prank(alice);
        underlyingToken.approve(address(strategy), type(uint256).max);

        vm.prank(bob);
        underlyingToken.approve(address(strategy), type(uint256).max);
    }

    /**
     * @notice First-mover wins, last-mover eats the AMM dislocation despite identical positions.
     *         Both clients have identical principal and identical fair entitlement at t0;
     *         the only difference is withdrawal order.
     */
    function test_FirstWithdrawerEatsTheYield_LastWithdrawerEatsTheLoss() public {
        // -----------------------------------------------------------------------
        // Step 1: Alice and Bob each deposit 1000e18 at fair 1:1 AMM.
        // -----------------------------------------------------------------------
        vm.prank(alice);
        strategy.deposit(address(underlyingToken), DEPOSIT, alice);

        vm.prank(bob);
        strategy.deposit(address(underlyingToken), DEPOSIT, bob);

        // Sanity: strategy holds 2000e18 vault shares; both clients have 1000e18 principal.
        assertEq(strategy.principalOf(address(underlyingToken), alice), DEPOSIT, "Alice principal");
        assertEq(strategy.principalOf(address(underlyingToken), bob), DEPOSIT, "Bob principal");
        assertEq(strategy.getTotalDeposited(address(underlyingToken)), 2 * DEPOSIT, "totalDeposited");
        assertEq(strategy.getTotalShares(), 2 * DEPOSIT, "strategy vault shares");

        console.log("=== H-02 PoC: bank run on peg loss ===");
        console.log("");
        console.log("Initial state (fair 1:1 AMM):");
        console.log("  Alice principal:", strategy.principalOf(address(underlyingToken), alice));
        console.log("  Bob   principal:", strategy.principalOf(address(underlyingToken), bob));
        console.log("  Strategy shares:", strategy.getTotalShares());

        // -----------------------------------------------------------------------
        // Step 2: Alice withdraws her full principal at the fair 1:1 rate.
        //         She receives the full 1000e18 underlying back.
        // -----------------------------------------------------------------------
        uint256 aliceUnderlyingBefore = underlyingToken.balanceOf(alice);

        vm.prank(alice);
        strategy.withdraw(address(underlyingToken), DEPOSIT, alice);

        uint256 aliceReceived = underlyingToken.balanceOf(alice) - aliceUnderlyingBefore;

        console.log("");
        console.log("After Alice withdraws at fair rate:");
        console.log("  Alice received underlying:", aliceReceived);
        console.log("  Alice remaining principal:", strategy.principalOf(address(underlyingToken), alice));
        console.log("  totalDeposited:           ", strategy.getTotalDeposited(address(underlyingToken)));
        console.log("  Strategy shares remaining:", strategy.getTotalShares());

        // Alice cleanly recovered her full principal.
        assertEq(aliceReceived, DEPOSIT, "Alice should receive full 1000e18 at fair AMM rate");
        assertEq(strategy.principalOf(address(underlyingToken), alice), 0, "Alice principal zeroed");

        // -----------------------------------------------------------------------
        // Step 3: AMM dislocates — vault token now trades at 50% of fair value.
        //         This could be a market crash, depeg, or low-liquidity attack.
        // -----------------------------------------------------------------------
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 0.5e18);

        // Step 4: Owner widens slippage tolerance so withdrawals can still clear.
        // This is a realistic operational response — leaving slippage at 1% would
        // simply brick all client withdrawals, which is at least as bad an outcome.
        // Either way, the protocol is in a no-win position because of the bug.
        vm.prank(owner);
        strategy.setSlippageTolerance(5000); // 50%

        // -----------------------------------------------------------------------
        // Step 5: Bob withdraws his identical 1000e18 principal at the dislocated rate.
        //         He receives only ~500e18 — a 50% loss on the same claim Alice
        //         exited cleanly moments earlier.
        // -----------------------------------------------------------------------
        uint256 bobUnderlyingBefore = underlyingToken.balanceOf(bob);

        vm.prank(bob);
        strategy.withdraw(address(underlyingToken), DEPOSIT, bob);

        uint256 bobReceived = underlyingToken.balanceOf(bob) - bobUnderlyingBefore;

        console.log("");
        console.log("After Bob withdraws at dislocated rate (vault->underlying = 0.5):");
        console.log("  Bob received underlying:  ", bobReceived);
        console.log("  Bob remaining principal:  ", strategy.principalOf(address(underlyingToken), bob));
        console.log("  totalDeposited:           ", strategy.getTotalDeposited(address(underlyingToken)));

        // -----------------------------------------------------------------------
        // Assertions: prove the asymmetric outcome.
        // -----------------------------------------------------------------------

        // (a) Alice received her full principal.
        assertEq(aliceReceived, DEPOSIT, "Alice received full principal");

        // (b) Bob received materially less than his principal — the AMM rate
        //     dislocated by 50% so he gets ~500e18.
        assertLt(bobReceived, DEPOSIT, "Bob received less than principal");
        assertApproxEqAbs(bobReceived, DEPOSIT / 2, 1, "Bob received ~50% of principal");

        // (c) Alice received strictly more than Bob despite identical positions.
        assertGt(aliceReceived, bobReceived, "Alice strictly out-received Bob");

        // (d) The shortfall on Bob is roughly the entire 50% AMM dislocation —
        //     it is NOT shared pro-rata between Alice and Bob.
        uint256 bobShortfall = DEPOSIT - bobReceived;
        assertApproxEqAbs(bobShortfall, DEPOSIT / 2, 1, "Bob's shortfall is ~500e18");

        // (e) Bob's principal accounting was nonetheless fully debited — the
        //     strategy has no record of the missing ~500e18 and there is no
        //     recourse against Alice or the protocol.
        assertEq(strategy.principalOf(address(underlyingToken), bob), 0, "Bob principal zeroed despite shortfall");
        assertEq(
            strategy.getTotalDeposited(address(underlyingToken)),
            0,
            "totalDeposited zeroed despite shortfall"
        );

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("Identical positions, identical fair claims at t0.");
        console.log("Alice (first to withdraw): received full", DEPOSIT);
        console.log("Bob   (last to withdraw):  received only", bobReceived);
        console.log("Bob's shortfall (silently absorbed):    ", bobShortfall);
    }
}
