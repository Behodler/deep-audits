# H-01: Surplus Withdrawal From One Client Drains Yield From All Other Clients

## Severity
**High**

## Affected Contract
`/home/justin/code/C4/solidity-audit/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol`

**Primary location**: `_withdrawFrom()` (lines 368-396)
**Contributing location**: `totalBalanceOf()` (lines 119-133)

## Root Cause

The `_withdrawFrom()` function burns vault shares from a **shared pool** to extract surplus for a single client, but the `totalBalanceOf()` function computes each client's balance as a **proportional share of total vault value**. Since all clients share the same pool of vault shares, burning shares for one client's surplus withdrawal reduces the vault value visible to **all** clients, effectively stealing yield from uninvolved depositors.

The core issue is an architectural mismatch: the surplus accounting model treats each client as having an independent yield balance, but the underlying share pool is communal. When surplus is extracted for client A, the shares burned come from the shared pool, reducing `vault.convertToAssets(vault.balanceOf(address(this)))` for everyone.

## Impact

An authorized withdrawer (SurplusWithdrawer) extracting surplus yield from one client will proportionally reduce the `totalBalanceOf()` of every other client. This means:

1. Other clients lose their accrued yield without their consent.
2. The loss is proportional -- if client A has 50% of deposits and their surplus is fully extracted, other clients lose roughly 50% of *their* surplus too.
3. This is exploitable through the SurplusWithdrawer contract, which is the designed entry point for yield extraction.

## Proof of Concept Outline

```
Setup:
- Client A deposits 1000 tokens (via authorized client)
- Client B deposits 1000 tokens (via authorized client)
- totalDeposited = 2000, vault has 2000 shares worth of value

Step 1: Yield accrues
- Vault generates 200 tokens of yield (total vault value = 2200)
- totalBalanceOf(A) = (2200 * 1000) / 2000 = 1100 (surplus = 100)
- totalBalanceOf(B) = (2200 * 1000) / 2000 = 1100 (surplus = 100)

Step 2: Withdraw surplus for Client A
- SurplusWithdrawer calls withdrawFrom() for client A, amount = 100
- _withdrawFrom burns shares worth ~100 from the shared pool
- Total vault value drops to ~2100

Step 3: Client B's yield is stolen
- totalBalanceOf(B) = (2100 * 1000) / 2000 = 1050 (surplus = 50)
- Client B lost 50 tokens of yield they rightfully earned
- The 100 tokens of surplus extracted for A came partially (50) from B's yield
```

## Detailed Trace

1. `SurplusWithdrawer.withdrawSurplusPercent(100, recipient)` is called by the SurplusWithdrawer owner.
2. It calculates surplus via `SurplusTracker.getSurplus()`, which calls `yieldStrategy.totalBalanceOf(token, client)` and subtracts `principalOf`.
3. It calls `yieldStrategy.withdrawFrom(token, client, surplusAmount, recipient)`.
4. `AYieldStrategy.withdrawFrom()` (base) calls `_withdrawFrom()` (override in ERC4626YieldStrategy).
5. `_withdrawFrom()` converts the surplus amount to shares via `vault.convertToShares(amount)`, then calls `vault.redeem(sharesToRedeem, recipient, address(this))`.
6. The redeemed shares reduce `vault.balanceOf(address(this))`, which is the denominator input for ALL clients' `totalBalanceOf()` calculations.
7. `clientBalances` and `totalDeposited` are intentionally NOT modified (correct for surplus), but the shared share pool shrinkage affects every client.

## Recommended Fix

The contract needs per-client share tracking rather than proportional-principal accounting. Two approaches:

**Option A (Minimal change)**: Track shares per client instead of (or in addition to) principal amounts. When surplus is withdrawn for client A, only burn shares from A's tracked allocation.

```solidity
mapping(address => mapping(address => uint256)) private clientShares;
mapping(address => uint256) private totalTrackedShares;

function _depositInternal(...) internal {
    // ...
    uint256 sharesReceived = vault.deposit(amount, address(this));
    clientShares[token][recipient] += sharesReceived;
    totalTrackedShares[token] += sharesReceived;
    // ...
}
```

**Option B (Design constraint)**: Document and enforce that this strategy only supports a single client at a time. If only one client exists, the cross-client yield theft is impossible. Add a guard:

```solidity
// In _depositInternal, after updating clientBalances:
// Enforce single-client invariant
require(
    /* only one client has non-zero balance */,
    "ERC4626YieldStrategy: only single client supported"
);
```

Option A is the more robust solution. Option B trades flexibility for simplicity.
