// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../../src/concreteYieldStrategies/ERC4626YieldStrategy.sol";
import "../../src/mocks/MockERC20.sol";
import "../mocks/MockERC4626Vault.sol";
import "../mocks/MockAMMAdapter.sol";

/**
 * @title DominanceRun17Grounding
 * @notice CONCRETE grounding for the abstract Halmos theorem in
 *         test/symbolic/DominanceRun17Narrow.t.sol.
 *
 *   The Halmos proof runs on a multiplicative ENCODING of the floors.  This file
 *   runs the SAME property against the REAL contracts and the REAL vault math, in
 *   the REAL two-client topology (StableStaker + PhusdStableMinter both wired as
 *   clients of one strategy, per MigrateStableStakerMainnet.s.sol:496/595), so an
 *   encoding mistake in the theorem would show up here.
 *
 *   Property under test, for the account that StableStakerV2 checks:
 *      capBinds(a)  ==>  _isUnderwater(token, strategy)
 *   with
 *      capBinds(a)     == vault.convertToShares(min(a, principalOf(acct)))
 *                            > vault.balanceOf(address(strategy))
 *      _isUnderwater() == totalBalanceOf(token, acct) < principalOf(token, acct)
 *                         (StableStakerV2.sol:851-853)
 */
contract DominanceRun17Grounding is Test {
    MockERC20 tok;
    MockERC4626Vault vlt;
    MockAMMAdapter amm;
    ERC4626MarketYieldStrategy mkt;
    ERC4626YieldStrategy dir;

    address owner = address(0x1234);
    address client = address(0x5678);
    address staker = address(0xDEF0); // StableStakerV2's account on the strategy
    address minter = address(0x1357); // PhusdStableMinter's account (the other client)

    uint256 constant SUP = 10_000_000e18;

    uint256 internal capBoundCount; // vacuity tripwire counter (persists across fuzz runs)

    function setUp() public {
        tok = new MockERC20("U", "U", 18);
        vlt = new MockERC4626Vault("V", "V", address(tok));
        amm = new MockAMMAdapter();
        vm.startPrank(owner);
        mkt = new ERC4626MarketYieldStrategy(owner, address(tok), address(vlt), address(amm));
        dir = new ERC4626YieldStrategy(owner, address(tok), address(vlt));
        mkt.setClient(client, true);
        dir.setClient(client, true);
        mkt.setSlippageTolerance(100); // 1%
        vm.stopPrank();

        amm.setExchangeRate(address(tok), address(vlt), 1e18);
        amm.setExchangeRate(address(vlt), address(tok), 1e18);

        tok.mint(client, SUP);
        tok.mint(address(this), SUP);
        tok.approve(address(vlt), SUP);
        vlt.deposit(SUP / 1000, address(amm));
        tok.mint(address(amm), SUP);

        vm.prank(client);
        tok.approve(address(mkt), type(uint256).max);
        vm.prank(client);
        tok.approve(address(dir), type(uint256).max);
    }

    // ------------------------------------------------------------------ utils

    function _isUnderwater(AYieldStrategy s, address acct) internal view returns (bool) {
        return s.totalBalanceOf(address(tok), acct) < s.principalOf(address(tok), acct);
    }

    function _capBinds(AYieldStrategy s, address acct, uint256 amount) internal returns (bool) {
        uint256 p = s.principalOf(address(tok), acct);
        uint256 a = amount > p ? p : amount; // _withdrawInternal's cap
        bool binds = vlt.convertToShares(a) > vlt.balanceOf(address(s));
        if (binds) capBoundCount++;
        return binds;
    }

    // =====================================================================
    // FUZZ 1 -- MARKET strategy, TWO clients (the CODE-01 topology).
    // =====================================================================
    /// forge-config: default.fuzz.runs = 50000
    function testFuzz_market_twoClients_capBindsImpliesUnderwater(
        uint96 depStaker,
        uint96 depMinter,
        uint96 loss,
        uint96 want
    ) public {
        depStaker = uint96(bound(depStaker, 1e6, 2_000e18));
        depMinter = uint96(bound(depMinter, 1e6, 2_000e18));

        vm.startPrank(client);
        mkt.deposit(address(tok), depStaker, staker);
        mkt.deposit(address(tok), depMinter, minter);
        vm.stopPrank();

        // Loss must be sized against the VAULT's total assets -- sizing it against the
        // strategy's own position moves the share price by ~0 and never binds the cap
        // (that mistake made the first version of this harness vacuous; the tripwire caught it).
        uint256 lossBps = bound(loss, 0, 9999);
        vlt.simulateLoss((vlt.totalAssets() * lossBps) / 10000);

        want = uint96(bound(want, 1, type(uint96).max));

        if (_capBinds(mkt, staker, want)) {
            assertTrue(_isUnderwater(mkt, staker), "COUNTEREXAMPLE: cap binds but NOT underwater (market)");
        }
    }

    // =====================================================================
    // FUZZ 2 -- DIRECT strategy (the mainnet-wired newYsDola/newYsUsdc kind),
    //           TWO clients.  This is the F-01-050 surface.
    // =====================================================================
    /// forge-config: default.fuzz.runs = 50000
    function testFuzz_direct_twoClients_capBindsImpliesUnderwater(
        uint96 depStaker,
        uint96 depMinter,
        uint96 loss,
        uint96 want
    ) public {
        depStaker = uint96(bound(depStaker, 1e6, 2_000e18));
        depMinter = uint96(bound(depMinter, 1e6, 2_000e18));

        vm.startPrank(client);
        dir.deposit(address(tok), depStaker, staker);
        dir.deposit(address(tok), depMinter, minter);
        vm.stopPrank();

        uint256 lossBps = bound(loss, 0, 9999);
        vlt.simulateLoss((vlt.totalAssets() * lossBps) / 10000);

        want = uint96(bound(want, 1, type(uint96).max));

        if (_capBinds(dir, staker, want)) {
            assertTrue(_isUnderwater(dir, staker), "COUNTEREXAMPLE: cap binds but NOT underwater (direct)");
        }
    }

    // =====================================================================
    // FUZZ 3 -- MARKET, two clients, with an interleaved partial withdrawal by
    //           the OTHER client first (the CODE-01 race the finding describes).
    // =====================================================================
    /// forge-config: default.fuzz.runs = 50000
    function testFuzz_market_otherClientDrainsFirst(uint96 depStaker, uint96 depMinter, uint96 drain, uint96 want)
        public
    {
        depStaker = uint96(bound(depStaker, 1e6, 2_000e18));
        depMinter = uint96(bound(depMinter, 1e6, 2_000e18));

        vm.startPrank(client);
        mkt.deposit(address(tok), depStaker, staker);
        mkt.deposit(address(tok), depMinter, minter);
        vm.stopPrank();

        vlt.simulateLoss((vlt.totalAssets() * 9000) / 10000); // drawdown, then the race
        uint256 pm = mkt.principalOf(address(tok), minter);
        drain = uint96(bound(drain, 1, pm));
        vm.prank(client);
        try mkt.withdraw(address(tok), drain, minter) {} catch {}

        want = uint96(bound(want, 1, type(uint96).max));
        if (_capBinds(mkt, staker, want)) {
            assertTrue(_isUnderwater(mkt, staker), "COUNTEREXAMPLE: cap binds but NOT underwater (drain-first)");
        }
    }

    // =====================================================================
    // VACUITY TRIPWIRE -- a deterministic state in which the cap DOES bind.
    // If this fails, every "no counterexample" result above is vacuous.
    // =====================================================================
    function test_tripwire_capActuallyBinds() public {
        vm.startPrank(client);
        mkt.deposit(address(tok), 1000e18, staker);
        mkt.deposit(address(tok), 1000e18, minter);
        vm.stopPrank();

        vlt.simulateLoss((vlt.totalAssets() * 9000) / 10000); // 90% vault drawdown

        uint256 p = mkt.principalOf(address(tok), staker);
        assertTrue(_capBinds(mkt, staker, p), "TRIPWIRE: the guarded (cap-binding) state was NEVER reached");
        assertTrue(_isUnderwater(mkt, staker), "and it is underwater, as the theorem requires");
        emit log_named_uint("principal (staker)", p);
        emit log_named_uint("positionValue", vlt.convertToAssets(vlt.balanceOf(address(mkt))));
        emit log_named_uint("totalBalanceOf(staker)", mkt.totalBalanceOf(address(tok), staker));
    }

    // The converse must NOT hold -- underwater without the cap binding, which is
    // what makes the guard conservative rather than equivalent.
    function test_converseFails_underwaterWithoutCapBinding() public {
        vm.startPrank(client);
        mkt.deposit(address(tok), 1000e18, staker);
        vm.stopPrank();
        vlt.simulateLoss((vlt.totalAssets() * 500) / 10000); // mild 5% impairment (1% is absorbed by the deposit haircut)
        assertTrue(_isUnderwater(mkt, staker), "mildly impaired => underwater");
        assertFalse(_capBinds(mkt, staker, 1e18), "small ask does NOT bind the cap");
    }

    // =====================================================================
    // GRID COVERAGE -- deterministic sweep that REPORTS how often the guarded
    // (cap-binding) state is actually entered, so "no counterexample" can be
    // audited rather than taken on trust.
    // =====================================================================
    function test_gridCoverage_marketAndDirect() public {
        uint256 cases;
        uint256 binds;
        uint256 underwaters;

        uint16[7] memory lossBps = [uint16(0), 100, 2500, 5000, 7500, 9000, 9900];
        uint16[5] memory wantPct = [uint16(1), 25, 50, 99, 100];
        uint16[3] memory ratio = [uint16(1), 2, 5]; // minter:staker deposit ratio

        for (uint256 i = 0; i < lossBps.length; i++) {
            for (uint256 j = 0; j < wantPct.length; j++) {
                for (uint256 k = 0; k < ratio.length; k++) {
                    uint256 snap = vm.snapshotState();

                    vm.startPrank(client);
                    mkt.deposit(address(tok), 500e18, staker);
                    mkt.deposit(address(tok), 500e18 * ratio[k], minter);
                    vm.stopPrank();
                    vlt.simulateLoss((vlt.totalAssets() * lossBps[i]) / 10000);

                    uint256 p = mkt.principalOf(address(tok), staker);
                    uint256 a = (p * wantPct[j]) / 100;
                    cases++;
                    bool b = _capBinds(mkt, staker, a);
                    bool u = _isUnderwater(mkt, staker);
                    if (b) binds++;
                    if (u) underwaters++;
                    assertTrue(!b || u, "COUNTEREXAMPLE in grid: cap binds but not underwater");

                    vm.revertToState(snap);
                }
            }
        }

        emit log_named_uint("grid cases            ", cases);
        emit log_named_uint("grid cases cap-binding", binds);
        emit log_named_uint("grid cases underwater ", underwaters);
        assertGt(binds, 0, "TRIPWIRE: grid never entered the cap-binding state");
        assertGt(underwaters, binds, "guard is strictly conservative, not equivalent");
    }

    // Direct-strategy tripwire (the mainnet-wired ERC4626YieldStrategy shape).
    function test_tripwire_direct_capActuallyBinds() public {
        vm.startPrank(client);
        dir.deposit(address(tok), 1000e18, staker);
        dir.deposit(address(tok), 1000e18, minter);
        vm.stopPrank();
        vlt.simulateLoss((vlt.totalAssets() * 9000) / 10000);
        uint256 p = dir.principalOf(address(tok), staker);
        assertTrue(_capBinds(dir, staker, p), "TRIPWIRE(direct): cap-binding state never reached");
        assertTrue(_isUnderwater(dir, staker), "and it is underwater");
    }
}
