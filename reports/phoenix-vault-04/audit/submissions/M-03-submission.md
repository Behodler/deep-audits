<!--
C4 Submission Metadata
Title: [M-03] Two-phase totalWithdrawal cache is decorative — child reads live balance
Severity: Medium
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L368-L399
PoC File: M-03-poc.t.sol
Note: This finding was downgraded from High to Medium during second-opinion severity review. Reason: The cached `amount` parameter is genuinely dead, but the realised exploit primitive collapses into H-01/H-02; reported as Medium for the snapshot being structurally insufficient.
-->

## Finding description and impact

### Summary
`AYieldStrategy` implements `totalWithdrawal` as a two-phase, owner-only flow whose purpose is to give clients a 24h notice window before their entire principal can be swept. Phase 1 takes a snapshot (`state.balance = balance`) and Phase 2, callable after the 24h `WAITING_PERIOD`, forwards that cached value as the `amount` argument to the strategy's `_totalWithdraw`. In `ERC4626MarketYieldStrategy._totalWithdraw`, the `amount` parameter is silently ignored: the function recomputes shares from `clientBalances[token][client]` read **live** at execution time. The cache is therefore decorative — Phase 2 always sweeps whatever the client's live balance happens to be at the moment Phase 2 is executed, not what was snapshotted at Phase 1.

### Vulnerability details

The parent in `AYieldStrategy.sol` performs a clean two-phase handoff:

[`AYieldStrategy.sol#L379-L417`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/AYieldStrategy.sol#L379-L417)

```solidity
function _initiateWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)
    internal
{
    uint256 balance = this.balanceOf(token, client);
    require(balance > 0, "AYieldStrategy: no balance to withdraw");

    state.initiatedAt = currentTime;
    state.status = WithdrawalStatus.Initiated;
    state.balance = balance;            // <-- snapshot

    uint256 executableAt = currentTime + WAITING_PERIOD;
    emit WithdrawalInitiated(token, client, balance, currentTime, executableAt);
}

function _executeWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)
    internal
{
    uint256 withdrawAmount = state.balance;     // <-- read snapshot

    state.status = WithdrawalStatus.None;
    state.initiatedAt = 0;
    state.balance = 0;

    _totalWithdraw(token, client, withdrawAmount);   // <-- forward snapshot as `amount`
    emit WithdrawalExecuted(token, client, withdrawAmount, currentTime);
}
```

The child in `ERC4626MarketYieldStrategy.sol` declares `amount` in its signature, requires it be non-zero, and then never uses it again:

[`ERC4626MarketYieldStrategy.sol#L368-L399`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L368-L399)

```solidity
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
    require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

    uint256 totalShares = vault.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

    uint256 clientStoredBalance = clientBalances[token][client];          // <-- LIVE, not `amount`
    uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

    if (sharesToSell > 0) {
        // ...swap and transfer to owner...
        clientBalances[token][client] = 0;
        totalDeposited[token] -= clientStoredBalance;
        underlyingToken.safeTransfer(owner(), underlyingReceived);
    }
}
```

The cached `amount` is unused. The function reads `clientBalances[token][client]` at the moment of execution, multiplies by the **current** `vault.balanceOf(address(this))`, and divides by the **current** `totalDeposited[token]`. None of those three inputs is snapshotted at Phase 1.

The PoC exercises both directions of the desync:

**Test 1 — `test_DepositDuringWindowGetsSweptByPhase2`** demonstrates the deposit-side desync:

1. Client deposits `1000` for `user1`.
2. Owner triggers Phase 1 — `state.balance` is cached as `1000`.
3. 12 hours into the 24h waiting window, the client deposits another `1000` for `user1`. Live `clientBalances[underlying][user1] = 2000`; the cached snapshot is still `1000`.
4. After the 24h period elapses, the owner triggers Phase 2.
5. Owner receives ~`2000` underlying (within slippage tolerance), not the `1000` that was snapshotted. `user1`'s principal is zeroed.

**Test 2 — `test_CachedBalanceIsIgnoredByChild`** demonstrates the symmetric withdrawal-side desync:

1. Client deposits `2000` for `user1`.
2. Owner triggers Phase 1 — cached snapshot is `2000`.
3. 6 hours into the window, the owner calls `withdrawAsOwner(user1, owner, 1500)`. Live principal = `500`; snapshot still `2000`.
4. After 24h, Phase 2 executes and sweeps ~`500`, not `2000`.

In both cases the cached `amount` parameter is verifiably unused.

### Impact

The 24h waiting period is the documented "rugpull protection" mechanism for `totalWithdrawal`. Its security narrative is: *clients can observe the queued sweep on chain and have 24 hours to react before their principal is forcibly migrated.* The desync defeats that narrative in three concrete ways:

1. **Deposits made in good faith during the window are silently swept.** A client who sees a Phase 1 event for `1000` reasonably believes only that `1000` is at risk. If they (or a depositor on their behalf) credit any additional funds to the same `(token, client)` slot during the window — for routine top-ups, automated yield routing, scheduled allocator transfers, etc. — those funds are swept by Phase 2 along with the original principal. The 24h notice does not protect them because the snapshot they observed is not what gets swept.

2. **The pro-rata is recomputed against live state.** Because `sharesToSell = totalShares * clientStoredBalance / totalDeposited[token]` uses the live denominators, any other client's deposit/withdrawal during the window also shifts how many shares back the targeted client. A third party can dilute or concentrate the share allocation by acting in the window, with no snapshot guard to prevent it.

3. **The 24h delay is publicly observable and front-runnable.** `WithdrawalInitiated` is emitted at Phase 1 with the cached balance. Anyone watching the mempool/event stream knows exactly when Phase 2 is executable (`executableAt = initiatedAt + 24h`) and can interleave deposits/withdrawals into the slot during the window with deterministic effect on what Phase 2 sweeps.

The result is direct loss: client funds added in good faith during what the documentation calls a "protection window" are taken, and the snapshot that the client observed bears no fixed relation to what is actually executed. The same `_totalWithdraw` is the only path through which `totalWithdrawal` reaches the asset layer, so this affects every two-phase withdrawal performed by `ERC4626MarketYieldStrategy`.

## Recommended mitigation steps

The intent of the two-phase design is that Phase 1 freezes a quantity that Phase 2 then realizes. The simplest fix is to make `_totalWithdraw` honor that contract:

**Option A — honor the cached `amount` as an upper bound (minimal change):**

```solidity
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
    require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

    uint256 totalShares = vault.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

    // Use the cached snapshot, capped by whatever live balance remains.
    uint256 liveBalance = clientBalances[token][client];
    uint256 effectiveBalance = amount < liveBalance ? amount : liveBalance;
    if (effectiveBalance == 0) return;

    uint256 sharesToSell = (totalShares * effectiveBalance) / totalDeposited[token];
    // ...swap and transfer...
    clientBalances[token][client] = liveBalance - effectiveBalance;
    totalDeposited[token] -= effectiveBalance;
}
```

This guarantees that Phase 2 sweeps no more than the value Phase 1 advertised, and that any post-Phase-1 deposits remain the client's property after the sweep.

**Option B — snapshot the entire pro-rata tuple at Phase 1:**

If the goal is to also lock in the share-conversion ratio, extend `WithdrawalState` to cache `(balance, totalShares, totalDeposited)` at Phase 1 and feed all three into Phase 2. This requires plumbing additional fields through `_totalWithdraw`'s signature (or storing them in `WithdrawalState` and reading them inside the override) but is the only way to make Phase 2 fully equivalent to a Phase-1-time execution when other clients are active in the same vault.

**Option C — re-document the behavior (not recommended):**

If the design genuinely intends for mid-window deposits to be swept, the rugpull-protection narrative needs to be rewritten and the `WithdrawalInitiated` event should not advertise a `balance` that has no binding meaning. This option is included only for completeness; it does not address the loss of funds for honest depositors and is unlikely to be acceptable to clients.

Option A is the smallest, lowest-risk fix and restores the security property the 24h window was designed to provide.
