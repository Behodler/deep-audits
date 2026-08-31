<!--
ID: ryv11h1
C4 Submission Metadata
Title: [H-01] `emergencyWithdraw` transfers vault shares without updating `clientBalances`, permanently corrupting accounting and rendering all client funds unrecoverable
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L386-L395
PoC File: poc-H01-emergency-withdraw-corruption.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy._emergencyWithdraw` transfers vault shares directly to the owner via `safeTransfer` but never decrements `clientBalances[token][client]` or `totalDeposited[token]`. After the call the strategy holds zero vault shares while its accounting maps still record the full pre-emergency principal, creating a permanent insolvency: every subsequent client `withdraw` receives zero underlying, and `skimSurplus` becomes a permanent no-op.

### Vulnerability details

The call chain is:

```
AYieldStrategy.emergencyWithdraw(uint256 amount)   // AYieldStrategy.sol L304-L310
  └─> _emergencyWithdraw(amount)                   // virtual, dispatches to concrete impl
        └─> ERC4626MarketYieldStrategy._emergencyWithdraw(uint256 amount)
```

The public entry point in `AYieldStrategy` (L304-L310):

```solidity
// AYieldStrategy.sol L304-L310
function emergencyWithdraw(uint256 amount) external override onlyOwner {
    require(amount > 0, "AYieldStrategy: amount must be greater than zero");

    _emergencyWithdraw(amount);

    emit EmergencyWithdraw(msg.sender, amount);
}
```

The concrete override in `ERC4626MarketYieldStrategy` (L386-L395):

```solidity
// ERC4626MarketYieldStrategy.sol L386-L395
function _emergencyWithdraw(uint256 amount) internal override {
    uint256 totalShares = vault.balanceOf(address(this));
    require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

    uint256 sharesToTransfer = amount < totalShares ? amount : totalShares;

    // Transfer vault tokens (shares) directly to owner
    // This avoids vault withdrawal restrictions (e.g., cooldown periods)
    IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer);
}
```

The function transfers `sharesToTransfer` vault shares to the owner and returns. Neither `clientBalances` (L46) nor `totalDeposited` (L49) is touched.

The downstream impact flows through `_withdrawInternal` and `_skimSurplus`:

**`_withdrawInternal` (L338-L375)** — the share quantity to sell is derived as:

```solidity
uint256 sharesToSell = vault.convertToShares(amount);          // L350
uint256 availableShares = vault.balanceOf(address(this));      // L351
if (sharesToSell > availableShares) {
    sharesToSell = availableShares;                            // L353 — clamped to 0
}
```

After `emergencyWithdraw`, `vault.balanceOf(address(this)) == 0`, so `sharesToSell` is clamped to zero. The subsequent AMM swap sells zero shares and delivers zero underlying to the client.

**`_skimSurplus` (L449-L487)** — surplus per client is computed as:

```solidity
uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // L457 == 0
uint256 total = (totalValue * principal) / td;                               // L514 == 0
if (total <= principal) continue;                                            // L515 — always true, skip
```

With `totalValue == 0`, no client ever passes the surplus threshold. The function accumulates zero shares, performs no swap, and returns zero. This condition persists indefinitely.

### Impact

1. **Total loss of client funds.** All clients who deposited before the emergency call have their `clientBalances` intact but their share of the vault is gone. Every `withdraw` call returns zero underlying. There is no on-chain path to recover the recorded principal without a fresh external deposit by the owner followed by manual re-accounting.

2. **Permanent `skimSurplus` failure.** Yield distribution to protocol recipients ceases permanently. Any keeper or scheduler that calls `skimSurplus` receives zero, with no revert to signal the broken state.

3. **`totalDeposited` cannot be zeroed.** Because neither `emergencyWithdraw` nor the callers clear these maps, no standard protocol operation can restore the strategy to a consistent state. The only remediation is a contract upgrade or owner-funded `depositAsOwner` followed by client-by-client `withdrawAsOwner` — neither of which is documented or gated by the emergency path.

The severity is High: all client principal deposited into any `ERC4626MarketYieldStrategy` instance is at risk of permanent loss whenever the owner exercises the emergency withdrawal function.

## Recommended mitigation steps

### Option A — Zero out accounting in `_emergencyWithdraw` (preferred)

Iterate over authorized clients and clear their balances before (or immediately after) the share transfer. The abstract base already exposes `getAuthorizedClients()`:

```solidity
function _emergencyWithdraw(uint256 amount) internal override {
    uint256 totalShares = vault.balanceOf(address(this));
    require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

    uint256 sharesToTransfer = amount < totalShares ? amount : totalShares;

    // If all shares are being transferred, zero out all accounting
    if (sharesToTransfer == totalShares) {
        address[] memory clients = getAuthorizedClients();
        address token = address(underlyingToken);
        for (uint256 i = 0; i < clients.length; i++) {
            clientBalances[token][clients[i]] = 0;
        }
        totalDeposited[token] = 0;
    } else {
        // Partial emergency: reduce totalDeposited proportionally
        // and zero out each client proportionally, or restrict to full-drain only.
        // Simplest safe choice: disallow partial emergency withdrawals.
        revert("ERC4626MarketYieldStrategy: partial emergency withdraw not supported");
    }

    IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer);
}
```

### Option B — Require the strategy to be paused before an emergency withdrawal

Add a `whenPaused` modifier to `emergencyWithdraw` in `AYieldStrategy` so no new deposits or withdrawals can race with the emergency action, and document clearly that the strategy must be redeployed after an emergency drain:

```solidity
// AYieldStrategy.sol
function emergencyWithdraw(uint256 amount) external override onlyOwner whenPaused {
    require(amount > 0, "AYieldStrategy: amount must be greater than zero");
    _emergencyWithdraw(amount);
    emit EmergencyWithdraw(msg.sender, amount);
}
```

Option B alone does not fix the accounting corruption — it only prevents clients from observing the broken state while the strategy is paused. It must be combined with Option A, or the contract must be considered permanently decommissioned after the call.

### Option C — Replace `emergencyWithdraw` with `totalWithdrawal`

The existing `totalWithdrawal` two-phase mechanism (L319-L347 in `AYieldStrategy`) already handles accounting correctly via `_totalWithdraw` (which zeroes `clientBalances[token][client]` and reduces `totalDeposited[token]`). Callers who need emergency fund migration should use `totalWithdrawal` per client rather than the unchecked `emergencyWithdraw` path. If `emergencyWithdraw` is kept, its NatSpec must document that it is an **accounting-destructive last resort** and that the strategy cannot be reused after it is called.
