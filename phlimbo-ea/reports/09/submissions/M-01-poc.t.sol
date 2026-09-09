// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PhlimboV3.sol";
import "./Mocks.sol";

/**
 * @title PoC — promo blocklist freezes staker PRINCIPAL on the self-service path
 * @notice Story-027 hardened `batchClaim` against a blocked promo recipient
 *         (per-user bank + claimUnclaimablePromo pull). The SAME condition on the
 *         ordinary path is unhardened: `_claimRewards` (PhlimboV3.sol:873) uses a
 *         REVERTING `promoToken.safeTransfer`, and stake/withdraw/claim all run it
 *         before moving principal. A staker blocklisted on the live promo token
 *         therefore cannot withdraw their phUSD principal at all.
 */
contract PoC_PromoBlocklistPrincipalFreeze is Test {
    PhlimboV3 public phlimbo;
    MockFlax public phUSD;
    MockStable public rewardToken;
    MockBlocklistToken public blkPromo;

    address public alice = address(0x1);
    address public rewardDonor = address(0x3);

    uint256 constant STAKE_AMOUNT = 1000 ether;
    uint256 constant DEPLETION_DURATION = 604800;
    uint256 constant PROMO_AMOUNT = 1000 ether;
    uint256 constant PROMO_DURATION = 1_000_000;

    function setUp() public {
        phUSD = new MockFlax();
        rewardToken = new MockStable();
        phlimbo = new PhlimboV3(address(phUSD), address(rewardToken), DEPLETION_DURATION);
        phUSD.setMinter(address(phlimbo), true);

        phUSD.mint(alice, 10000 ether);
        vm.prank(alice);
        phUSD.approve(address(phlimbo), type(uint256).max);

        rewardToken.mint(rewardDonor, 10000 ether);
        vm.prank(rewardDonor);
        rewardToken.approve(address(phlimbo), type(uint256).max);

        // Live promo funded with a USDC-style recipient-blocklisting token.
        blkPromo = new MockBlocklistToken();
        blkPromo.mint(address(this), PROMO_AMOUNT);
        blkPromo.approve(address(phlimbo), type(uint256).max);
    }

    function test_PoC_blocklistedStakerCannotWithdrawPrincipal() public {
        // 1. Alice stakes 1000 phUSD.
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        assertEq(phUSD.balanceOf(alice), 9000 ether, "stake did not land");

        // 2. Owner starts a promotion on the blocklisting token.
        phlimbo.startPromotion(address(blkPromo), PROMO_AMOUNT, PROMO_DURATION);

        // 3. Time passes; Alice accrues promo.
        vm.warp(block.timestamp + 10_000);
        assertGt(phlimbo.pendingPromo(alice), 0, "alice should have accrued promo");

        // 4. The token issuer blocklists Alice. She did nothing wrong; the protocol
        //    has no control over this, and its own comments name it as a live threat.
        blkPromo.setBlocked(alice, true);

        // 5. Alice tries to exit. Her PRINCIPAL is now unreachable: _claimRewards'
        //    reverting promo transfer (PhlimboV3.sol:873) fires before the phUSD
        //    principal transfer at :723 and takes the whole tx down.
        vm.prank(alice);
        vm.expectRevert("recipient blocked");
        phlimbo.withdraw(STAKE_AMOUNT, alice);

        // 6. Every other self-service path is dead too.
        vm.prank(alice);
        vm.expectRevert("recipient blocked");
        phlimbo.claim(alice);

        vm.prank(alice);
        vm.expectRevert("recipient blocked");
        phlimbo.stake(1 ether, alice);

        // 7. Principal is still in the contract; Alice cannot retrieve it.
        (uint256 amt,,,) = phlimbo.userInfo(alice);
        assertEq(amt, STAKE_AMOUNT, "principal still locked in the farm");
        assertEq(phUSD.balanceOf(alice), 9000 ether, "alice never got her principal back");
    }

    /// @notice Contrast: the FLUSH path handles the identical condition gracefully.
    ///         This is the asymmetry — batchClaim was hardened, _claimRewards was not.
    function test_PoC_contrast_flushPathHandlesSameConditionFine() public {
        vm.prank(alice);
        phlimbo.stake(STAKE_AMOUNT, alice);
        phlimbo.startPromotion(address(blkPromo), PROMO_AMOUNT, PROMO_DURATION);
        vm.warp(block.timestamp + 10_000);
        blkPromo.setBlocked(alice, true);

        // The owner-driven rotation absorbs the blocked recipient by banking.
        phlimbo.beginFlush();
        phlimbo.batchClaim(10);
        assertGt(phlimbo.unclaimablePromoOf(address(blkPromo), alice), 0, "banked");

        // ...and only AFTER a full rotation (promoToken -> 0) can Alice move again.
        phlimbo.finalizePromotion(address(this));
        phlimbo.unpause();

        vm.prank(alice);
        phlimbo.withdraw(STAKE_AMOUNT, alice); // now succeeds
        assertEq(phUSD.balanceOf(alice), 10000 ether, "principal only recoverable via full rotation");
    }
}
