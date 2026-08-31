<!--
ID: pe7m2
C4 Submission Metadata
Title: [M-02] emergencyTransfer leaves promo bookkeeping stale, so the intuitive refund+unpause bricks stake/withdraw/claim for all stakers with pending promo
Severity: Medium
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L307-L325
PoC File: workspace/phlimbo-ea/test/poc-m02-emergencytransfer-brick.t.sol
-->

## Finding description and impact

### Summary

`PhlimboV3.emergencyTransfer` sweeps the on-hand promo-token balance while a promotion is
**Active**, but it does not touch the promo *bookkeeping* — `promoToken`, `promoRewardBalance`,
and `promoPhase` remain non-zero. The promo slot still reports "Active" even though the contract
now holds **zero** promo tokens. A competent, non-malicious owner who subsequently handles the
emergency and performs the intuitive resume — a bare `unpause()` — unknowingly bricks the entire
staking surface (`stake`, `withdraw`, and `claim`) for every staker who has pending promo.

This is a Law-3 **non-obvious owner footgun**: the owner would reasonably expect a refund plus
`unpause()` to restore service, and would be surprised that it does not. It is not a
malicious-owner vector.

### Vulnerability details

`emergencyTransfer` at [`src/PhlimboV3.sol:307-325`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L307-L325)
sweeps phUSD, the reward token, and — new in V3 — the promo token, then pauses:

```solidity
function emergencyTransfer(address recipient) external onlyOwner {
    ...
    if (address(promoToken) != address(0)) {
        uint256 promoBalance = promoToken.balanceOf(address(this));
        if (promoBalance > 0) {
            promoToken.safeTransfer(recipient, promoBalance);   // sweeps the tokens...
        }
    }
    _pause();
}
```

The sweep moves the tokens out, but `promoToken`, `promoRewardBalance` and `promoPhase` are left
exactly as they were. From the settlement leg's point of view the promotion is still live and
still owes every staker their accrued promo, while the on-hand balance backing those debts is now
zero.

The promo settlement leg lives inside `_claimRewards` at
[`src/PhlimboV3.sol:800-807`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV3.sol#L800-L807):

```solidity
if (address(promoToken) != address(0)) {
    uint256 pendingPromoAmount =
        (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;
    if (pendingPromoAmount > 0) {
        promoToken.safeTransfer(beneficiary, pendingPromoAmount);   // reverts: balance is 0
        emit PromoClaimed(user, pendingPromoAmount);
    }
}
```

Because `promoToken != address(0)` and `pendingPromoAmount > 0` for every staker with pending
promo, this `safeTransfer` executes against a zero balance and reverts with
`ERC20InsufficientBalance(address(phlimbo), 0, needed)`. `_claimRewards` is on the hot path of
`stake`, `withdraw`, **and** `claim`, so all three core entry points revert. After the owner's
bare `unpause()`, the staking surface is fully bricked for every affected staker.

Recovery is itself non-obvious. A bare refund + `unpause()` does *not* help unless the owner
re-funds the exact swept amount. The intended cure is the rotation flush, which routes the
un-payable promo into `unclaimablePromo` via the **non-reverting** `_tryTransfer` and realigns
every `promoDebt` before the slot is reset:

```
unpause() → beginFlush() → batchClaim(...) to completion → finalizePromotion(recipient) → unpause()
```

### Impact

Availability brick of the three core user functions (`stake`, `withdraw`, `claim`) for all
stakers with pending promo. No funds are stolen or permanently lost — the swept promo tokens are
in the recipient's hands and stakers' principal/phUSD/reward accounting is intact — but the
protocol's core function is unavailable until the owner performs the correct, non-obvious recovery
sequence. The trigger is an owner emergency action followed by the *intuitive* (wrong) resume, so
the hazard is realistic rather than adversarial. Rated **Medium**: core-function availability
impact, funds recoverable, gated behind an owner emergency action.

## Recommended mitigation steps

Preferred (code fix): make `emergencyTransfer` handle the promo slot **atomically** when it
sweeps during an active promotion — flush the outstanding promo into `unclaimablePromo` and reset
the promo bookkeeping (`promoToken` / `promoRewardBalance` / `promoPhase`) in the same call, so
the slot never reports "Active" while the backing balance is zero. This removes the footgun
entirely and makes a bare `unpause()` safe.

Operational safe-config guidance (until the code fix lands): after any `emergencyTransfer` that
fired while a promotion was Active, the owner must **not** perform a bare `unpause()`. Instead
either:

1. Run the full rotation flush/finalize sequence before re-opening the staking surface:
   `unpause() → beginFlush() → batchClaim(...) to completion → finalizePromotion(recipient) → unpause()`;
   or
2. Re-fund the **exact** swept promo balance back to the contract before `unpause()`, so the
   settlement leg has the tokens it expects.

Do not treat refund-and-unpause without the exact swept amount as a valid recovery — it leaves
the settlement leg under-funded and the surface bricked.

### Proof of Concept

Two tests in `workspace/phlimbo-ea/test/poc-m02-emergencytransfer-brick.t.sol` demonstrate both
the brick and the recovery:

- `test_M02_emergencyTransfer_bricks_staker_surface_after_unpause` — after
  `emergencyTransfer` during an active promo and a bare `unpause()`, a staker's `claim`/`stake`/
  `withdraw` revert with the exact error `ERC20InsufficientBalance(address(phlimbo), 0, 500e18)`.
- `test_M02_flush_dance_recovers_where_refund_unpause_fails` — a bare refund+unpause still
  fails, while the flush/finalize rotation restores the surface.

Reproduce (use `--match-path`, not `--match-contract`, to avoid matching an unrelated
`V2M02PoCTest`):

```
cd workspace/phlimbo-ea && forge test --match-path test/poc-m02-emergencytransfer-brick.t.sol -vv
```

Output:

```
Ran 2 tests for test/poc-m02-emergencytransfer-brick.t.sol:M02PoCTest
[PASS] test_M02_emergencyTransfer_bricks_staker_surface_after_unpause() (gas: 575356)
[PASS] test_M02_flush_dance_recovers_where_refund_unpause_fails() (gas: 554785)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 2.04ms (1.44ms CPU time)

Ran 1 test suite in 13.47ms (2.04ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```
