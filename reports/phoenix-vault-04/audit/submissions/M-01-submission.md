<!--
C4 Submission Metadata
Title: [M-01] emergencyWithdraw bypasses 24h rugpull delay AND leaves client accounting permanently stale
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L350-L359
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy._emergencyWithdraw` is invoked from the parent `AYieldStrategy.emergencyWithdraw`, which is gated only by `onlyOwner` — no waiting period, no execution window, no `whenNotPaused`, no `nonReentrant`. The function transfers raw vault shares directly to the owner and never updates `clientBalances` or `totalDeposited`. Two distinct defects co-exist in this single code path:

- **Bug A — Delay bypass.** The strategy advertises a two-phase rugpull protection on `totalWithdrawal` (`WAITING_PERIOD = 24h` then `EXECUTION_WINDOW = 48h`), yet `emergencyWithdraw` provides a one-transaction owner escape hatch with none of these guards. The "rugpull protection" narrative and the actually-deployed escape hatch contradict each other.
- **Bug B — Permanent accounting skew.** Because `_emergencyWithdraw` only moves the share token, every per-client and per-token bookkeeping value (`clientBalances`, `totalDeposited`, and therefore `principalOf`) is left at its pre-drain value while the real share pool is empty. The strategy is left in an internally inconsistent state from which subsequent client withdrawals either revert or, worse, silently zero a user's principal while delivering zero underlying.

### Vulnerability details

The vulnerable implementation is at [ERC4626MarketYieldStrategy.sol#L350-L359](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L350-L359):

```solidity
function _emergencyWithdraw(uint256 amount) internal override {
    uint256 totalShares = vault.balanceOf(address(this));
    require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

    uint256 sharesToTransfer = amount < totalShares ? amount : totalShares;

    // Transfer vault tokens (shares) directly to owner
    // This avoids vault withdrawal restrictions (e.g., cooldown periods)
    IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer);
}
```

The parent dispatcher (`AYieldStrategy.sol#L227-L233`) is gated only by `onlyOwner`:

```solidity
function emergencyWithdraw(uint256 amount) external override onlyOwner {
    require(amount > 0, "AYieldStrategy: amount must be greater than zero");

    _emergencyWithdraw(amount);

    emit EmergencyWithdraw(msg.sender, amount);
}
```

Compare this to the documented "community protection against rugpulls" path (`AYieldStrategy.sol#L242` and below) which is `onlyOwner nonReentrant whenNotPaused` and additionally enforces the two-phase pattern Phase 1 → 24h wait → Phase 2 within 48h. The two paths drain the same shares; only one of them respects the documented delay.

#### Bug A — Delay bypass

The PoC test `test_EmergencyWithdrawIsSingleTransactionNoDelay` records `block.timestamp` before and after the drain, makes no `vm.warp` calls, and asserts that the entire share pool moves to the owner with `endTimestamp - startTimestamp == 0`. The owner is able to drain the strategy in a single transaction with zero seconds elapsed, while the documented `WAITING_PERIOD` is non-zero. This is a structural contradiction with the project's stated rugpull protection: a protective delay cannot meaningfully exist when an unrestricted, immediate alternative is available on the same contract.

#### Bug B — Permanent accounting skew

The PoC test `test_EmergencyWithdrawLeavesAccountingStale` demonstrates the second bug. After two clients (`alice` and `bob`) each deposit 1000 underlying and the owner calls `emergencyWithdraw(2000)`:

- `vault.balanceOf(strategy)` is `0` (real shares are gone)
- `principalOf(alice)` is still `1000e18` (stale)
- `principalOf(bob)` is still `1000e18` (stale)
- `getTotalDeposited(token)` is still `2000e18` (stale)
- `totalBalanceOf(alice)` is `0` (computed live from the now-empty share pool)

The contradiction `principalOf(alice) > totalBalanceOf(alice)` is asserted explicitly in the test — this is an impossible state for a healthy vault. Worse, the contradiction is not just a view-function curiosity. When `alice` (via the authorized client) subsequently calls `withdraw(token, 1000e18, alice)`, `_withdrawInternal` proceeds as follows:

1. `availablePrincipal == 1000e18` (still stale-high), so the requested amount is not capped.
2. `convertToShares(1000)` requests roughly `1000` ideal shares.
3. `sharesToSell` is then capped to `availableShares == 0`.
4. The AMM swap is invoked with `0` shares in and `minOut == 0`, returning `0` underlying.
5. The user receives `0` underlying.
6. `clientBalances[alice]` and `totalDeposited` are decremented by the **requested** amount (`1000e18`).

Net result: `alice`'s principal is silently zeroed while she receives nothing. The PoC verifies this with `assertEq(received, 0)` and `assertEq(strategy.principalOf(token, alice), 0)`. The PoC also accepts a clean revert as an alternative branch — both branches confirm that honest use of the (intended) emergency path leaves clients unable to safely retrieve their stated principal.

### Impact

This finding is filed at **Medium** severity rather than High because exploitation requires owner action, which is a centralization vector. However, the impact when the path is exercised is direct loss of client funds and broken protocol availability for honest clients:

- The two-phase rugpull-protection invariant the project documents is structurally unenforceable. Any "community delay" guarantee on `totalWithdrawal` is undermined by the simultaneous existence of a no-delay `emergencyWithdraw` that drains the same share pool.
- Even an entirely benign use of `emergencyWithdraw` (say, the owner is migrating funds for a vault upgrade) leaves the strategy in a state where every honest client's next withdrawal either reverts or silently consumes their on-paper principal in exchange for zero underlying. There is no recovery path inside the strategy short of manually re-injecting shares; the contract exposes no admin function to re-bookkeep `clientBalances` or `totalDeposited`.
- View functions (`principalOf`, `totalBalanceOf`, `getTotalDeposited`) start returning mutually contradictory values (`principal > totalBalance`), breaking any downstream protocol that relies on this strategy's accounting (e.g., a UI claiming a user can withdraw their principal, or another contract pricing vault positions off `principalOf`).

The combination of these two defects in a single function — skipping the documented protective delay **and** leaving global accounting in a permanently desynced state — produces a Medium-severity issue notwithstanding the owner-action precondition.

## Recommended mitigation steps

These recommendations should be applied together; addressing only one of the two bugs leaves the other unfixed.

**1. Reconcile `emergencyWithdraw` with the documented rugpull-protection model.** Pick one of:

- *Preferred:* Subject `emergencyWithdraw` to the same two-phase delay as `totalWithdrawal` (Phase 1 to start a 24h timer, Phase 2 to execute within the 48h window). This restores the "community protection against rugpulls" guarantee that the project's docs and `WAITING_PERIOD`/`EXECUTION_WINDOW` constants advertise.
- *Acceptable alternative:* Explicitly re-document `emergencyWithdraw` as an immediate, no-delay escape hatch and update the rugpull-protection narrative on `totalWithdrawal` to reflect that the delay is bypassable. This is strictly weaker — it merely converts the structural contradiction into an explicitly acknowledged centralization risk — and should be combined with operational mitigations such as multisig ownership and timelocked owner.

**2. Independently fix the accounting-skew path so honest use of `emergencyWithdraw` does not silently wipe clients.** Possible approaches, in increasing order of strictness:

- Have `_emergencyWithdraw` set `totalDeposited[underlyingToken] = 0` (or otherwise mark the strategy as drained) so that `_withdrawInternal` and `totalBalanceOf` early-return cleanly rather than silently decrementing client principal against an empty share pool. This avoids the silent-zero path but still loses the per-client accounting record.
- Track a "drained" flag and revert all subsequent client `deposit`/`withdraw` calls until the owner explicitly re-bookkeeps or re-funds the strategy. This is the strictest option and is appropriate if `emergencyWithdraw` is intended to be a one-way operation.
- If `emergencyWithdraw` is meant to be reversible (i.e., owner returns shares later), expose an admin `restoreShares` function and document the intended emergency-then-restore flow, with explicit invariants relating `vault.balanceOf(address(this))` to `totalDeposited[token]` checked on every state transition.

In all cases, add an invariant test that asserts `principalOf(client) <= totalBalanceOf(client)` for every client across the full lifecycle, including post-`emergencyWithdraw`. The current contract violates this invariant as soon as the emergency path is used.
