# AutoPool Partial Migration Strategy

## Purpose

Safely extract a small portion of funds from an AutoPool concrete YieldStrategy for testing on a new YieldStrategy, while keeping accounting clean.

## Prerequisites

- Owner access to the YieldStrategy
- Access to the minter's `noMintDeposit` function
- The minter is an authorized client on the YieldStrategy

## Procedure

### Step 1: Initiate totalWithdrawal (Phase 1)

Call `totalWithdrawal(token, client)` as owner. This snapshots the client's principal balance and starts the timelock waiting period.

### Step 2: Wait for timelock

Wait for `WAITING_PERIOD` to elapse.

### Step 3: Execute totalWithdrawal (Phase 2)

Call `totalWithdrawal(token, client)` again. This:
- Redeems the client's proportional shares from the vault
- Zeros out `clientBalances[token][client]` and decrements `totalDeposited`
- Sends all redeemed assets to `owner()`

After this step, the strategy's accounting is clean (zeroed for that client) and the owner holds the underlying tokens.

### Step 4: Re-deposit 90% via noMintDeposit

Route 90% of the withdrawn tokens back through the minter's `noMintDeposit` function. This calls `deposit` on the YieldStrategy, which:
- Adds the amount to `clientBalances` and `totalDeposited`
- Deposits into the vault and receives fresh shares

Ensure the tokens are approved for transfer by whoever `noMintDeposit` pulls from.

### Step 5: Use the 10% for testing

The retained 10% is available for the owner to deposit into the new YieldStrategy for testing.

## Accounting Impact

- `clientBalances` and `totalDeposited` accurately reflect the 90% re-deposit
- Vault shares match the new deposit amount
- Any pending/accrued yield from the previous position is forfeited (acceptable trade-off)

## Notes

- This approach works for any concrete YieldStrategy that uses the `totalWithdrawal` two-phase flow from `AYieldStrategy`
- The 90/10 split is arbitrary -- adjust as needed
- The only delay is the timelock between Phase 1 and Phase 2
- `withdrawAsOwner` is an alternative for ERC4626YieldStrategy specifically (allows partial principal withdrawal without timelock), but is not available on the base `AYieldStrategy` or other concrete implementations like AutoPool
