// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/StableStaker.sol";
import "../../src/InPlaceMigrator.sol";
import "../../src/interfaces/IStableStaker.sol";
import "flax-token/FlaxToken.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockYieldStrategy} from "../mocks/MockYieldStrategy.sol";
import "reflax-yield-vault/interfaces/IYieldStrategy.sol";

/// @title PoC M-01 — Re-injection haircut: silent per-user principal loss in InPlaceMigrator.migrateIn
/// @author stable-staker run-12 (DEDUP-12-001 / CLASS-12-001), submodule HEAD ffa4947
///
/// @notice WHAT THIS PROVES
/// --------------------------------------------------------------------------------------------
/// The in-place migration round trip is NOT value-conserving when the freshly-wired re-injection
/// strategy haircuts the deposit. A single staker parks `P` principal on migrateOut, then
/// migrateIn re-credits them only `P*(1-slip)` while zeroing their parked balance (and the global
/// totalParked) by the FULL `P`. The `P*slip` difference is permanently lost to the user: there is
/// no residual parked balance to reclaim, no event, and no revert. The delta physically lands in
/// the strategy as protocol-owned surplus credited to nobody.
///
/// @notice INVARIANT VIOLATED (story-012 AC-1, InPlaceMigrator.sol:168 / :221-223)
/// --------------------------------------------------------------------------------------------
/// "migrateIn credits each user the exact principal parked for them, back into the immutable
///  staker." The PoC shows the staker's re-credited `userInfo.amount` is STRICTLY LESS than the
///  amount parked, so the migrator's own stated accounting guarantee is broken.
///
/// @notice ROOT CAUSE (exact source lines)
/// --------------------------------------------------------------------------------------------
/// InPlaceMigrator.migrateIn (src/InPlaceMigrator.sol):
///   :215  parked[token][user] = 0;          // parked zeroed by the FULL requested `amt`
///   :217  totalParked[token] -= amt;        // global total reduced by the FULL requested `amt`
///   :223  staker.depositFor(token, user, amt);
/// StableStaker.depositFor (src/StableStaker.sol):
///   :631  uint256 credited = _routeDeposit(token, received);  // strategy HAIRCUTS: credited < amt
///   :633  info.amount   += credited;        // user re-credited only the haircut amount
///   :634  pool.totalStaked += credited;     // pool tracks only the haircut amount
/// => parked is debited by `amt` but the user is credited only `credited` (= amt*(1-slip)).
///    The `amt - credited` gap is unaccounted for on the user side.
///
/// @notice WHY MEDIUM (not High)
/// --------------------------------------------------------------------------------------------
/// No external attacker; the loss is gated on the operator wiring a haircutting (market/AMM/fee'd
/// ERC4626) re-injection strategy. Par / idle / direct / 1:1-ERC4626 targets preserve principal
/// exactly. That conditionality is the C4 "value leak with stated assumptions and external
/// requirements" Medium clause. Consistent with ledger M-07 (969722dc), the same rate-vs-execution
/// deposit-slippage vector, re-expressed through story-012's sanctioned in-place migrateIn door.
contract PoC_M01_ReinjectionHaircut is Test {
    FlaxToken internal phUSD;
    StableStaker internal staker;
    InPlaceMigrator internal migrator;
    MockERC20 internal usdc;

    address internal owner = address(this);
    address internal staker_user = address(0xA11CE); // the single representative staker

    uint256 internal constant PER_DAY = 86_400 ether; // emission budget (irrelevant to the loss)
    uint256 internal constant TIMEOUT = 7 days; // migrator timeout-claim window (default-grade)

    /// Representative numbers: a 1,000 USDC (6-dec) position re-injected through a 2% haircut.
    uint256 internal constant PRINCIPAL = 1_000e6; // 1,000.000000 USDC
    uint256 internal constant SLIPPAGE_BPS = 200; // 2.00% deposit haircut on the new strategy

    /// @dev Mirrors the seed Tier-3 test event for an explicit, greppable shortfall record.
    event ReinjectionShortfall(uint256 parked, uint256 credited, uint256 lost);

    function setUp() public {
        // ---- Standard StableStaker wiring (per workspace CLAUDE.md "Wiring") ----
        phUSD = new FlaxToken();
        staker = new StableStaker(phUSD, owner);
        phUSD.setMinter(address(staker), true);

        usdc = new MockERC20("USD Coin", "USDC", 6);
        staker.addToken(address(usdc));
        staker.phUSDPerDay(address(usdc), PER_DAY);

        // The in-place migrator must be set as the staker's migrator to drive the terminal flow.
        migrator = new InPlaceMigrator(IStableStaker(address(staker)), TIMEOUT, owner);
        staker.setMigrator(address(migrator));

        // Fund and approve the single staker.
        usdc.mint(staker_user, PRINCIPAL);
        vm.prank(staker_user);
        usdc.approve(address(staker), type(uint256).max);
    }

    /// @dev Reads the staker's recorded principal (userInfo.amount) for the USDC pool.
    function _userAmount(address user) internal view returns (uint256 amt) {
        (amt,) = staker.userInfo(address(usdc), user);
    }

    /// @dev Reads pool.totalStaked for the USDC pool.
    function _poolTotalStaked() internal view returns (uint256 total) {
        (,,, total) = staker.poolInfo(address(usdc));
    }

    function _singleUser() internal view returns (address[] memory users) {
        users = new address[](1);
        users[0] = staker_user;
    }

    // ================================================================================
    // THE PoC: a clean single-staker walk through the full in-place migration round trip
    // ================================================================================
    function test_M01_reinjectionHaircut_silentlyLosesPrincipal() public {
        // ---------------------------------------------------------------------------
        // STEP 1 — Staker deposits principal at par (idle hold, no strategy yet).
        // ---------------------------------------------------------------------------
        vm.prank(staker_user);
        staker.stake(address(usdc), PRINCIPAL);

        assertEq(_userAmount(staker_user), PRINCIPAL, "precondition: staked at par");
        assertEq(_poolTotalStaked(), PRINCIPAL, "precondition: pool tracks full principal");

        // ---------------------------------------------------------------------------
        // STEP 2 — Operator runs the terminal migrate-OUT: principal is parked in the
        //          migrator. With no old strategy this is a par exit, so parked == staked.
        // ---------------------------------------------------------------------------
        migrator.initiateMigration(address(usdc));
        migrator.migrateOut(address(usdc), _singleUser());

        uint256 parked = migrator.parked(address(usdc), staker_user);
        assertEq(parked, PRINCIPAL, "parked principal must equal the par exit (1,000 USDC)");
        assertEq(migrator.totalParked(address(usdc)), PRINCIPAL, "totalParked holds the full principal");
        // Pool has been drained to empty by the terminal exit.
        assertEq(_poolTotalStaked(), 0, "pool drained to empty after migrateOut");

        // ---------------------------------------------------------------------------
        // STEP 3 — Operator resets the now-empty pool and wires a FRESH strategy that
        //          haircuts deposits by SLIPPAGE_BPS (models a market/AMM/fee'd-ERC4626
        //          target — exactly the realistic deployment class from the M-07 lineage).
        //          setYieldStrategy is permitted only on an empty pool, which is satisfied.
        // ---------------------------------------------------------------------------
        staker.finalizeAndReset(address(usdc));

        MockYieldStrategy haircutStrategy = new MockYieldStrategy();
        haircutStrategy.setClient(address(staker), true); // authorize the farm as a client
        haircutStrategy.setDepositSlippageBps(SLIPPAGE_BPS); // 2% deposit haircut
        staker.setYieldStrategy(address(usdc), IYieldStrategy(address(haircutStrategy)));

        // ---------------------------------------------------------------------------
        // STEP 4 — Operator runs migrate-IN. This is where the silent loss happens:
        //          InPlaceMigrator.sol:215/:217 zero parked & totalParked by the FULL `amt`,
        //          but depositFor (StableStaker.sol:631/:633) credits only the haircut return.
        // ---------------------------------------------------------------------------
        migrator.migrateIn(address(usdc), 0, migrator.parkedUserCount(address(usdc)));

        // ===========================================================================
        // BEFORE / AFTER ACCOUNTING
        //   parked (debited from user/global):  PRINCIPAL              = 1,000.000000 USDC
        //   credited (re-injected to user):     PRINCIPAL*(1-2%)       =   980.000000 USDC
        //   silent shortfall (lost principal):  PRINCIPAL*2%           =    20.000000 USDC
        // ===========================================================================
        uint256 credited = _userAmount(staker_user);
        uint256 expectedCredited = (parked * (10_000 - SLIPPAGE_BPS)) / 10_000; // floor, mirrors mock
        uint256 shortfall = parked - credited;

        emit log_string("--- M-01 re-injection haircut: before/after accounting (USDC, 6 dp) ---");
        emit log_named_uint("parked at migrateOut        ", parked);
        emit log_named_uint("re-credited at migrateIn    ", credited);
        emit log_named_uint("SILENT SHORTFALL (lost)     ", shortfall);
        emit log_named_uint("strategy holds (orphaned)   ", usdc.balanceOf(address(haircutStrategy)));
        emit ReinjectionShortfall(parked, credited, shortfall);

        // ---------------------------------------------------------------------------
        // ASSERTION (a) — the user is re-credited strictly LESS than they parked.
        //   This is the core invariant violation: AC-1 promises exact-principal re-credit.
        // ---------------------------------------------------------------------------
        assertEq(credited, expectedCredited, "credited must equal the haircut formula amt*(1-slip)");
        assertLt(credited, parked, "VIOLATION: re-credited principal is strictly less than parked");
        assertEq(_poolTotalStaked(), credited, "pool.totalStaked tracks only the haircut amount");

        // ---------------------------------------------------------------------------
        // ASSERTION (b) — totalParked (and the user's parked balance) are driven to 0
        //   by the FULL requested amount, regardless of the haircut. There is NO residual
        //   parked balance left to reclaim, and claimTimedOut can no longer rescue anything.
        // ---------------------------------------------------------------------------
        assertEq(migrator.totalParked(address(usdc)), 0, "totalParked zeroed by full requested amt");
        assertEq(migrator.parked(address(usdc), staker_user), 0, "user parked balance fully zeroed");
        assertEq(migrator.parkedUserCount(address(usdc)), 0, "user removed from parked set");

        // ---------------------------------------------------------------------------
        // ASSERTION (c) — the lost delta sits in the strategy credited to NOBODY.
        //   The migrator surrendered the full `parked` USDC into the strategy on the deposit
        //   leg; the strategy only booked `credited` as the user's principal. The remaining
        //   `shortfall` is protocol-owned surplus (skimmable elsewhere), unattributed to the
        //   user — the loss is real and irrecoverable from the user's perspective.
        // ---------------------------------------------------------------------------
        assertGt(shortfall, 0, "there must be a real, positive principal shortfall");
        assertEq(shortfall, (parked * SLIPPAGE_BPS) / 10_000, "shortfall == slippage * parked (2% of 1,000)");
        // Full parked principal physically left the migrator into the strategy...
        assertEq(usdc.balanceOf(address(migrator)), 0, "migrator surrendered the full parked principal");
        // ...but the strategy only attributed `credited` to the user; the rest is orphaned surplus.
        assertEq(
            haircutStrategy.principalOf(address(usdc), address(staker)),
            credited,
            "strategy attributes only the haircut amount to the staker"
        );
        assertEq(
            usdc.balanceOf(address(haircutStrategy)),
            parked,
            "strategy physically holds the FULL parked principal; the shortfall is credited to nobody"
        );
    }
}
