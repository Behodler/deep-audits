<!--
C4 Submission Metadata
Title: [H-01] Multi-Client Surplus Withdrawal Drains Other Clients' Yield
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L368-L396
PoC File: poc-H-01.t.sol
-->

## Finding description and impact

### Summary

The `_withdrawFrom()` function in `ERC4626YieldStrategy` burns vault shares from a communal share pool without adjusting `totalDeposited`, causing every other client's `totalBalanceOf()` to decrease proportionally. Extracting one client's surplus directly steals accrued yield from all other clients.

### Vulnerability details

`ERC4626YieldStrategy` tracks client deposits using two principal-tracking mappings and a communal pool of ERC4626 vault shares:

```solidity
// Line 40-43
mapping(address => mapping(address => uint256)) private clientBalances;
mapping(address => uint256) private totalDeposited;
```

Each client's total balance (principal + yield) is computed proportionally in [`totalBalanceOf()`](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L119-L133):

```solidity
// Line 128-132
uint256 totalShares = vault.balanceOf(address(this));
uint256 totalValue = vault.convertToAssets(totalShares);

// User's proportion: (userPrincipal / totalPrincipal) * totalValue
return (totalValue * principal) / totalDeposited[token];
```

The critical invariant is that `totalValue` and `totalDeposited` must remain in sync for the proportional formula to be accurate. The vulnerability lies in [`_withdrawFrom()`](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L368-L396), which is called by the `SurplusWithdrawer` to extract yield:

```solidity
// Line 368-396
function _withdrawFrom(address token, address client, uint256 amount, address recipient) internal override {
    require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");

    uint256 principal = clientBalances[token][client];
    uint256 totalBalance = this.totalBalanceOf(token, client);
    uint256 surplus = totalBalance > principal ? totalBalance - principal : 0;

    require(
        amount <= surplus,
        "ERC4626YieldStrategy: amount exceeds available surplus, use totalWithdrawal() for principal"
    );

    uint256 sharesToRedeem = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));
    if (sharesToRedeem > availableShares) {
        sharesToRedeem = availableShares;
    }
    vault.redeem(sharesToRedeem, recipient, address(this));

    // CORRECT: NEVER modify principal tracking for surplus withdrawals
    // clientBalances[token][client] stays unchanged
    // totalDeposited[token] stays unchanged
    // Only vault shares are reduced, affecting totalBalanceOf() but not principalOf()
}
```

The code comment on lines 392-395 states the decision to leave `clientBalances` and `totalDeposited` unchanged is intentional. However, this creates an accounting mismatch: `vault.redeem()` burns shares from the communal pool, which reduces the `totalValue` returned by `vault.convertToAssets(vault.balanceOf(address(this)))`. Since `totalDeposited[token]` remains unchanged, the ratio `totalValue / totalDeposited` decreases for all clients. Every client's `totalBalanceOf()` drops proportionally, not just the client whose surplus was extracted.

The attack path is straightforward:

1. User1 and User2 each deposit equal principal into the strategy.
2. The underlying ERC4626 vault generates yield, increasing `totalValue`.
3. Both users show surplus (yield) in their `totalBalanceOf()`.
4. An authorized withdrawer calls `withdrawFrom()` to extract User1's surplus.
5. Shares are burned from the communal pool, reducing `totalValue`.
6. User2's `totalBalanceOf()` drops because `totalValue` decreased but `totalDeposited` did not.
7. User2 has lost a portion of their accrued yield, which was extracted as part of User1's surplus.

This is not a rounding artifact. The loss is proportional to the surplus extracted relative to `totalValue`, and it compounds with each extraction cycle.

### Impact

Direct loss of accrued yield for all clients other than the one whose surplus is extracted. The loss magnitude scales with the number and size of surplus extractions.

Concrete numbers from the PoC with two equal-deposit clients:

- User1 and User2 each deposit 1000e18.
- The vault generates 200e18 in yield (100e18 per user expected).
- Both users show surplus of 100e18 before extraction.
- After extracting User1's 100e18 surplus: User2's `totalBalanceOf()` drops from 1100e18 to approximately 1050e18. User2 has lost 50e18, which is 50% of their accrued yield.
- After 5 yield-and-extract cycles: User2 has gained only approximately 97e18 instead of the expected 500e18, representing over 80% cumulative yield loss.

This vulnerability is exploitable in normal protocol operation whenever any client's surplus is extracted. It does not require malicious intent; the authorized `SurplusWithdrawer` contract triggers this automatically during routine yield distribution.

## Proof of concept

The PoC is in the test file `poc-H-01.t.sol`. It demonstrates the following:

1. Two users deposit equal principal (1000e18 each) into the strategy.
2. The vault generates yield, giving both users equal surplus.
3. Surplus extraction for User1 causes User2's `totalBalanceOf()` to decrease.
4. Over 5 cycles of yield generation and extraction, User2's cumulative yield loss exceeds 80%.
5. The test asserts the exact deficit amounts at each step, confirming the proportional drain is deterministic and predictable.

## Recommended mitigation steps

Replace the proportional-principal accounting model with per-client share tracking. Instead of computing balances via `(totalValue * principal) / totalDeposited`, track each client's vault shares directly:

```solidity
// Add per-client share tracking
mapping(address => mapping(address => uint256)) private clientShares;
uint256 private totalTrackedShares;

function _depositInternal(address token, uint256 amount, address recipient, address depositor) internal {
    // ... existing validation and transfer ...
    uint256 sharesReceived = vault.deposit(amount, address(this));

    clientBalances[token][recipient] += amount;
    totalDeposited[token] += amount;
    clientShares[token][recipient] += sharesReceived;
    totalTrackedShares += sharesReceived;
}

function totalBalanceOf(address token, address account) external view override returns (uint256) {
    uint256 shares = clientShares[token][account];
    if (shares == 0) return 0;
    return vault.convertToAssets(shares);
}

function _withdrawFrom(address token, address client, uint256 amount, address recipient) internal override {
    // ... existing surplus check against per-client totalBalanceOf ...
    uint256 sharesToRedeem = vault.convertToShares(amount);
    uint256 clientOwnedShares = clientShares[token][client];
    require(sharesToRedeem <= clientOwnedShares, "exceeds client shares");

    clientShares[token][client] -= sharesToRedeem;
    totalTrackedShares -= sharesToRedeem;
    vault.redeem(sharesToRedeem, recipient, address(this));
}
```

With per-client share tracking, burning shares for one client's surplus extraction does not affect any other client's share count or balance. Each client's `totalBalanceOf()` is computed exclusively from their own shares, providing full isolation between clients.
