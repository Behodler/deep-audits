# M-02: Fee-Charging ERC4626 Vaults Inflate totalBalanceOf, Creating Phantom Surplus That Causes Withdrawal Reverts

## Severity
**Medium**

## Affected Contracts
- `<repo>/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` -- `totalBalanceOf()` (lines 119-133), `_withdrawFrom()` (lines 368-396)
- `<repo>/lib/reflax-yield-vault/src/SurplusWithdrawer.sol` -- `withdrawSurplusPercent()` (lines 90-123)
- `<repo>/lib/reflax-yield-vault/src/SurplusTracker.sol` -- `getSurplus()` (lines 36-57)

## Root Cause

When a fee-charging ERC4626 vault is used (e.g., one that takes a deposit fee), the `totalBalanceOf()` calculation produces a value **higher** than the actual redeemable value for the first depositor, because:

1. `_depositInternal` tracks `clientBalances[token][recipient] += amount` using the **pre-fee** deposit amount.
2. `totalDeposited[token] += amount` also uses the pre-fee amount.
3. However, `totalBalanceOf()` computes `(totalVaultValue * principal) / totalDeposited`, where `totalVaultValue = vault.convertToAssets(vault.balanceOf(address(this)))`.

For the first depositor in a fee-charging vault:
- Deposits 1000 tokens, vault takes 5% fee, mints shares worth 950.
- `clientBalances = 1000`, `totalDeposited = 1000`
- `totalVaultValue = vault.convertToAssets(shares) = 1000` (the vault's totalAssets includes the fee as vault-retained value)
- `totalBalanceOf = (1000 * 1000) / 1000 = 1000`

This looks correct for a single user. But when a **second** depositor enters:
- User B deposits 1000 tokens. After fee, gets fewer shares.
- `totalDeposited = 2000`, vault `totalAssets = 2000`
- `totalBalanceOf(A) = (2000 * 1000) / 2000 = 1000`
- `totalBalanceOf(B) = (2000 * 1000) / 2000 = 1000`
- Sum = 2000 = vault total assets. Aggregate is correct.

But B's shares are actually worth less than 1000. When B tries to withdraw their full principal of 1000, `convertToShares(1000)` will demand more shares than B's proportional share, and the shares get capped. B receives less than 1000, but their principal is decremented by 1000. This is the documented "rounding favors protocol" behavior.

The real problem emerges with the **surplus system**. After the fee is taken, the first depositor's `totalBalanceOf` can show a phantom surplus. Consider:

- Single depositor: 1000 tokens, 5% fee vault.
- Vault `totalAssets = 1000` (fee stays as vault value), shares worth 950 in actual redemption.
- `totalBalanceOf = (1000 * 1000) / 1000 = 1000` -- no surplus shown (principal = 1000).
- But if the vault reports `totalAssets = 1000` accurately, there's no phantom surplus for a single user.

The issue manifests when **yield accrues on top of fee revenue**:
- Depositor puts 1000, fee vault takes 50 (fee). Shares worth 950.
- Yield of 100 accrues. Vault `totalAssets = 1100`.
- `totalBalanceOf = (1100 * 1000) / 1000 = 1100`. Surplus = 100.
- But actual redeemable value of shares is: `convertToAssets(shares) = 1100 * shares / totalSupply`. If shares = 950 and totalSupply = 950, then redeemable = 1100. This checks out for a single depositor.
- SurplusWithdrawer tries to extract 100 surplus: `convertToShares(100) = 950 * 100 / 1100 = ~86 shares`.
- After redeeming 86 shares: remaining shares = 864, remaining vault value = ~1014.
- `totalBalanceOf = (1014 * 1000) / 1000 = 1014`. New surplus = 14. This works.

**Where it breaks**: Multiple depositors with a fee-charging vault:
- A deposits 1000 (950 shares), B deposits 1000 (451 shares due to diluted price).
- `totalDeposited = 2000`, vault `totalAssets = 2000`, total shares = 1401.
- B's shares are worth: `2000 * 451 / 1401 = 643.8` -- but B's principal is 1000.
- `totalBalanceOf(B) = (2000 * 1000) / 2000 = 1000` -- shows no deficit!
- B's actual redeemable value is only 643.8, but the accounting shows 1000.
- If yield accrues and surplus appears, attempting to withdraw surplus for B could try to redeem shares B does not effectively own, potentially draining A's shares.

## Impact

1. With fee-charging vaults and multiple clients, `totalBalanceOf()` overstates later depositors' balances by not accounting for entry fees in principal tracking.
2. The surplus system (`SurplusTracker` + `SurplusWithdrawer`) may calculate phantom surplus for later depositors, and extracting it will drain other clients' shares.
3. Full principal withdrawals by later depositors will silently receive less than their tracked principal, with the difference silently absorbed as "protocol yield."

## Proof of Concept Outline

```
Setup:
- Deploy ERC4626YieldStrategy with a 5% fee-charging vault

Step 1: User A deposits 1000
- clientBalances[A] = 1000, totalDeposited = 1000
- 950 vault shares minted, vault totalAssets = 1000

Step 2: User B deposits 1000
- clientBalances[B] = 1000, totalDeposited = 2000
- ~451 vault shares minted (diluted by A's fee), vault totalAssets = 2000
- total shares = ~1401

Step 3: Yield of 200 accrues (vault totalAssets = 2200)
- totalBalanceOf(A) = (2200 * 1000) / 2000 = 1100 (surplus = 100)
- totalBalanceOf(B) = (2200 * 1000) / 2000 = 1100 (surplus = 100)
- But B's shares are only worth 2200 * 451 / 1401 = ~708
- B's "surplus" of 100 is phantom -- B doesn't actually have surplus

Step 4: SurplusWithdrawer extracts B's "surplus" of 100
- Burns shares from shared pool worth ~100
- This drains shares that proportionally belong to A
- A's actual redeemable value decreases
```

## Recommended Fix

**Option A**: Track entry fees and adjust principal downward for fee-charging vaults:

```solidity
function _depositInternal(...) internal {
    // ...
    uint256 sharesReceived = vault.deposit(amount, address(this));
    uint256 effectiveValue = vault.convertToAssets(sharesReceived);

    // Track effective value, not input amount
    clientBalances[token][recipient] += effectiveValue;
    totalDeposited[token] += effectiveValue;
    // ...
}
```

**Option B**: Document that fee-charging vaults are not supported and add a constructor-time validation:

```solidity
constructor(...) {
    // ... existing code ...
    // Validate no entry fee: deposit and immediate redeem should return ~same amount
    // (within rounding tolerance)
}
```

**Option C**: Use per-client share tracking (as recommended in H-01), which inherently handles fee-charging vaults correctly since each client's shares directly reflect what they received after fees.
