<!--
ID: ryv11h3
C4 Submission Metadata
Title: [H-03] `withdrawAsOwner` bypasses the 24-hour anti-rugpull timelock, enabling atomic drain of all client principal with no community notice
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L279-L281
PoC File: poc-H03-withdraw-as-owner-bypass.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy.withdrawAsOwner` is an owner-only function that routes directly to `_withdrawInternal` with no timelock, no Phase-1 announcement, and no `whenNotPaused` guard. The protocol documents `totalWithdrawal` as a two-phase mechanism with a 24-hour waiting period that exists specifically as protection against unauthorized or rushed withdrawals. `withdrawAsOwner` is absent from `IYieldStrategy` and `AYieldStrategy`, bypasses every control that two-phase mechanism enforces, and allows an owner (or a compromised owner key) to drain every client's full principal to an arbitrary address in a single block.

### Vulnerability details

`AYieldStrategy.totalWithdrawal` is the declared owner path for removing client principal from the strategy. Its NatSpec states:

> Provides community protection against rugpulls while allowing legitimate fund migrations.

The mechanism enforces two phases:

- **Phase 1** (`WithdrawalStatus.None` / `Expired`): records intent on-chain, emits `WithdrawalInitiated`, starts a `WAITING_PERIOD` of 24 hours.
- **Phase 2** (`WithdrawalStatus.Executable`): only callable after 24 hours have elapsed; executes the actual transfer and emits `WithdrawalExecuted`.

A call during the waiting period reverts explicitly:

```solidity
// AYieldStrategy.sol L335-L346
} else if (state.status == WithdrawalStatus.Initiated) {
    uint256 executableAt = state.initiatedAt + WAITING_PERIOD;
    revert(
        string(
            abi.encodePacked(
                "AYieldStrategy: withdrawal still in waiting period, executable at timestamp: ",
                _uint256ToString(executableAt)
            )
        )
    );
}
```

`ERC4626MarketYieldStrategy` introduces `withdrawAsOwner` outside the `IYieldStrategy` / `AYieldStrategy` hierarchy entirely:

```solidity
// ERC4626MarketYieldStrategy.sol L279-L281
function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {
    _withdrawInternal(address(underlyingToken), amount, recipient, client);
}
```

The function carries only two guards — `onlyOwner` and `nonReentrant` — and calls `_withdrawInternal` directly. `_withdrawInternal` debits `clientBalances[token][balanceHolder]`, decrements `totalDeposited`, swaps vault shares for underlying via the AMM adapter, and transfers the result to `recipient`. No `WithdrawalState` is consulted; no `WithdrawalInitiated` event fires; no `whenNotPaused` check is applied.

The attack flow requires a single transaction:

1. Three clients each deposit 1000e18 via the normal client-authorized path. Their principals are recorded in `clientBalances`.
2. With `block.timestamp` unchanged — no Phase-1 announcement, no time warp — the owner calls:
   ```
   withdrawAsOwner(clientA, attacker, 1000e18)
   withdrawAsOwner(clientB, attacker, 1000e18)
   withdrawAsOwner(clientC, attacker, 1000e18)
   ```
3. All three `clientBalances` are zeroed; the attacker receives approximately 3000e18 underlying tokens.
4. The `WithdrawalExecuted` event never fires. Only the lower-visibility `Withdrawn` event fires, and it carries no `client` field identifying which account was debited.

An additional monitoring gap compounds the severity: `Withdrawn` is indexed on `token`, `withdrawer`, and `recipient`, but not on the `balanceHolder` (the client whose principal was taken). Off-chain monitors watching for the high-visibility `WithdrawalExecuted` event — the natural signal for the two-phase path — will see nothing until client balances are already zero.

### Impact

- **All client principal is drainable to any address in a single transaction** with no prior on-chain signal.
- The 24-hour waiting period — the only durable security window between client funds and an owner-compromise event — provides zero protection for `ERC4626MarketYieldStrategy` deployments.
- Because `withdrawAsOwner` is absent from `IYieldStrategy` and `AYieldStrategy`, callers that hold only an `IYieldStrategy` reference cannot even observe its existence; it is invisible to the interface-level security surface.
- The `WithdrawalExecuted` event (the canonical signal for monitors and governance tooling) is never emitted; the only event that fires is `Withdrawn`, which lacks a `client` index, degrading incident-detection capability.

## Recommended mitigation steps

**Option A (strongly preferred): remove `withdrawAsOwner` entirely.**

All owner-initiated principal withdrawals should flow through `totalWithdrawal`. If the intent of `withdrawAsOwner` is to allow the owner to migrate a specific client's funds, the two-phase path already supports exactly that. Removing `withdrawAsOwner` eliminates the bypass surface at zero functional cost.

**Option B: subject `withdrawAsOwner` to the same 24-hour timelock.**

If the function must be retained, gate it through the existing `WithdrawalState` machinery — requiring a prior Phase-1 `totalWithdrawal` call and enforcing the 24-hour wait — so that it is functionally identical to Phase 2 of `totalWithdrawal`. This is substantially more complex than Option A and carries ongoing maintenance risk if the two paths diverge again in a future change.

**Option C (minimum viable, not sufficient alone): add `whenNotPaused`.**

Adding `whenNotPaused` gives the guardian the ability to halt abuse once detected, but provides no advance notice and offers no protection during the window between an attacker's action and the guardian's reaction. This does not address the root cause and should not be the sole mitigation.

Regardless of the option chosen, `depositAsOwner` (line 262) should be audited for analogous bypass vectors, and all owner-privileged paths on `ERC4626MarketYieldStrategy` should be reconciled against the security model documented in `AYieldStrategy`.
