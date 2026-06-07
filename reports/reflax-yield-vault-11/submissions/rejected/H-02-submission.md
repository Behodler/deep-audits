<!--
ID: ryv11h2
C4 Submission Metadata
Title: [H-02] `_totalWithdraw` ignores Phase-1 cached balance and reads live `clientBalances`, enabling silent over-extraction via inter-phase deposit injection
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435
PoC File: poc-H02-total-withdraw-live-balance.t.sol
-->

## Finding description and impact

### Summary

The two-phase `totalWithdrawal` mechanism in `AYieldStrategy` caches the client's balance at Phase 1 and passes it as the `amount` parameter to `_totalWithdraw` at Phase 2. However, `ERC4626MarketYieldStrategy._totalWithdraw` completely ignores this `amount` parameter and instead re-reads the client's current live `clientBalances` entry to size the proportional share sale. If the owner calls `depositAsOwner` for the same client between Phase 1 and Phase 2, the live balance silently inflates above the announced amount. Phase 2 then extracts the full inflated balance while the `WithdrawalExecuted` event still reports only the Phase-1 snapshot, masking the over-extraction on-chain.

A secondary consequence: if the injection causes the live client balance to exceed `totalDeposited[token]`, the `totalDeposited[token] -= clientStoredBalance` subtraction at Phase 2 reverts with an arithmetic underflow, permanently bricking the `totalWithdrawal` path for all remaining clients.

### Vulnerability details

#### Phase 1 — snapshot and cache

`AYieldStrategy._initiateWithdrawal` (lines 464–479) queries the current balance and stores it in `WithdrawalState.balance`:

```solidity
// AYieldStrategy.sol L464-L479
function _initiateWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)
    internal
{
    uint256 balance = this.balanceOf(token, client);
    require(balance > 0, "AYieldStrategy: no balance to withdraw");

    state.initiatedAt = currentTime;
    state.status = WithdrawalStatus.Initiated;
    state.balance = balance;                          // <-- cached here

    uint256 executableAt = currentTime + WAITING_PERIOD;
    emit WithdrawalInitiated(token, client, balance, currentTime, executableAt);
}
```

`WithdrawalInitiated` announces `balance` to observers as the amount that will be extracted.

#### Phase 2 — cache forwarded but silently ignored

`AYieldStrategy._executeWithdrawal` (lines 488–502) reads back the cached value and passes it to `_totalWithdraw`:

```solidity
// AYieldStrategy.sol L488-L502
function _executeWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)
    internal
{
    uint256 withdrawAmount = state.balance;           // <-- uses cache

    state.status = WithdrawalStatus.None;
    state.initiatedAt = 0;
    state.balance = 0;

    _totalWithdraw(token, client, withdrawAmount);    // <-- passes cache as `amount`

    emit WithdrawalExecuted(token, client, withdrawAmount, currentTime); // <-- emits cache
}
```

`ERC4626MarketYieldStrategy._totalWithdraw` receives `amount` but never uses it. Instead it re-reads `clientBalances[token][client]` directly:

```solidity
// ERC4626MarketYieldStrategy.sol L404-L435
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(underlyingToken), "...");
    require(amount > 0, "...");

    uint256 totalShares = vault.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

    uint256 clientStoredBalance = clientBalances[token][client]; // <-- live storage, NOT `amount`
    uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];
    // ...
    clientBalances[token][client] = 0;
    totalDeposited[token] -= clientStoredBalance;    // underflow if balance > totalDeposited
    // ...
}
```

The `amount` parameter on line 404 is validated (`require(amount > 0)`) but otherwise completely unused for the share calculation.

#### Attack path

The 24-hour waiting period between Phase 1 and Phase 2 is the injection window:

1. Owner calls `totalWithdrawal(token, client)` at time T. Phase 1 snapshots `state.balance = X` and emits `WithdrawalInitiated(token, client, X, T, T+24h)`. Community observers see a withdrawal of `X` tokens announced.
2. During the 24-hour window the owner calls `depositAsOwner(token, Y, client)`, incrementing `clientBalances[token][client]` from `X` to `X + Y`.
3. At time T + 25 hours the owner calls `totalWithdrawal(token, client)` again. Phase 2 executes.
4. `_executeWithdrawal` reads `state.balance = X` and calls `_totalWithdraw(token, client, X)`.
5. `_totalWithdraw` ignores `X` and reads `clientStoredBalance = X + Y` from live storage. It sells shares proportional to `X + Y`, transfers the full proceeds to the owner, and emits `WithdrawalExecuted(token, client, X, ...)`.
6. The owner has extracted `X + Y` underlying tokens while the event log shows only `X`. The `Y` tokens are extracted without any event coverage.

`depositAsOwner` (lines 262–269) intentionally bypasses `whenNotPaused`, so this injection path is available even if the contract is paused. The owner comment in the NatSpec acknowledges this as a design choice for emergencies.

### Impact

**Funds stolen / extracted without announced notice.** The two-phase mechanism exists specifically to give the community a 24-hour window to observe and react to a full fund migration. By injecting additional principal between the phases, the owner can extract an arbitrarily larger amount than announced while the `WithdrawalExecuted` event — the only on-chain record of what was taken — reports the smaller cached figure.

The severity is further elevated by the secondary denial-of-service path: if the injected `Y` causes `clientStoredBalance > totalDeposited[token]` (possible when other clients' balances are small), the subtraction `totalDeposited[token] -= clientStoredBalance` reverts with an arithmetic underflow, bricking `totalWithdrawal` permanently for every remaining client in the strategy.

Concrete magnitude: with 1,000 tokens announced and 5,000 tokens injected, the Forge PoC demonstrates 6,000 tokens extracted while the event log reports 1,000 — a 6x silent over-extraction with no on-chain signal.

## Recommended mitigation steps

Use the `amount` parameter that `_executeWithdrawal` already passes to `_totalWithdraw`. This is clearly the design intent: the parameter exists precisely so the concrete implementation can honour the Phase-1 snapshot. Replace the live storage read with the passed value:

```solidity
// ERC4626MarketYieldStrategy.sol — _totalWithdraw (fixed)
function _totalWithdraw(address token, address client, uint256 amount) internal override {
    require(token == address(underlyingToken), "...");
    require(amount > 0, "...");

    uint256 totalShares = vault.balanceOf(address(this));
    if (totalShares == 0 || totalDeposited[token] == 0) {
        return;
    }

    // Use the Phase-1 cached `amount`, NOT the live clientBalances entry
    uint256 sharesToSell = (totalShares * amount) / totalDeposited[token];

    if (sharesToSell > 0) {
        uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
        uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

        IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);
        uint256 underlyingReceived =
            ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);

        clientBalances[token][client] -= amount;     // decrement by snapshot, not full balance
        totalDeposited[token] -= amount;

        underlyingToken.safeTransfer(owner(), underlyingReceived);
    }
}
```

Note that `clientBalances[token][client] -= amount` (rather than zeroing) is the correct form after this fix: any balance deposited by `depositAsOwner` between the phases remains correctly tracked and is not wiped. If the intent is truly to zero out a client completely, a separate, explicitly announced mechanism should be used rather than silently expanding the Phase-1 withdrawal scope.

As defence-in-depth, consider adding a guard in `depositAsOwner` that reverts when a withdrawal is in the `Initiated` or `Executable` state for the same `(token, client)` pair, preventing the injection window from being used at all.
