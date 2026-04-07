<!--
C4 Submission Metadata
Title: [H-03] Surplus extraction sells from shared share pool, draining other clients' yield
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L411-L451
PoC File: H-03-poc.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy._withdrawFrom` is the function used by an authorized withdrawer to extract a specific client's accrued surplus (yield above their tracked principal). It is parameterized by `client`, but the underlying share inventory it draws from is a single shared pool held by the strategy. As a result, every call on behalf of one client also silently dilutes every other client's pro-rata balance, draining their surplus into the calling client's recipient.

A single authorized withdrawer can therefore drain other clients' yield with no consent and no privileged access to those clients. Principal accounting is correctly preserved (the strategy's documented invariant), but the surplus side of the accounting is completely cross-contaminated.

### Vulnerability details

The vulnerable function is `_withdrawFrom` in [`ERC4626MarketYieldStrategy.sol#L411-L451`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L411-L451):

```solidity
function _withdrawFrom(address token, address client, uint256 amount, address recipient) internal override {
    require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

    // Get current balances
    uint256 principal = clientBalances[token][client];
    uint256 totalBalance = this.totalBalanceOf(token, client);

    // Calculate available surplus (yield)
    uint256 surplus = totalBalance > principal ? totalBalance - principal : 0;

    require(
        amount <= surplus,
        "ERC4626MarketYieldStrategy: amount exceeds available surplus, use totalWithdrawal() for principal"
    );

    // Convert requested amount to shares, cap to available shares
    uint256 sharesToSell = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));
    if (sharesToSell > availableShares) {
        sharesToSell = availableShares;
    }

    // ...slippage / approve...

    uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);
    underlyingToken.safeTransfer(recipient, underlyingReceived);

    // CORRECT: NEVER modify principal tracking for surplus withdrawals
}
```

The function performs three steps that are individually reasonable but jointly broken:

1. It computes the *calling* client's surplus from `totalBalanceOf(token, client)`, which is itself derived as a pro-rata view of the strategy's shared share inventory.
2. It then translates that surplus from underlying units to vault shares via `vault.convertToShares(amount)` and pulls those shares **from the strategy's shared inventory**, not from any per-client share account.
3. It deliberately does not touch `clientBalances` or `totalDeposited`, on the documented basis that "principal is never modified."

Because the share pool is shared and there is no per-client share accounting, every share the function burns reduces `vault.balanceOf(strategy)` for all clients. After the call, `totalBalanceOf(token, otherClient)` for every other client returns a smaller pro-rata view of the (now shrunken) pool. With each client's `principal` entry unchanged, the entire shrinkage manifests as a reduction in those other clients' surplus.

In other words, the function attempts to bill client A's surplus extraction to "client A," but the only thing it can charge is the global pool, so the cost is automatically socialized across every client in proportion to their share of the pool.

### Concrete walkthrough (matches the PoC)

Two clients deposit 100 underlying each. Vault per-share value then doubles via real yield, so:

- `totalDeposited = 200`, vault holds 200 shares worth 400 underlying.
- `clientA.principal = 100`, `clientA.totalBalance = 200`, `clientA.surplus = 100`.
- `clientB.principal = 100`, `clientB.totalBalance = 200`, `clientB.surplus = 100`.

Client A's authorized withdrawer calls `withdrawFrom(token, clientA, 100, recipientA)`:

- `convertToShares(100) = 50`. The strategy sells 50 shares to the AMM and receives 100 underlying.
- The strategy now holds 150 shares worth 300 underlying.
- `clientA.principal = 100` (unchanged), `clientA.totalBalance = 150`, `clientA.surplus = 50`.
- `clientB.principal = 100` (unchanged), `clientB.totalBalance = 150`, `clientB.surplus = 50`.

Client A's recipient received 100 underlying, but client A only "owned" 50 of that — the other 50 came directly out of client B's surplus, even though client B's withdrawer never authorized anything and was never named in the call.

### Cumulative drain

The first PoC test (`test_ExtractingClientASurplusReducesClientBSurplus`) demonstrates the single-shot cross-client transfer above. The second PoC test (`test_RepeatedExtractionsDrainAllOfClientB`) shows the steady-state behavior: after each extraction, client A's `surplus` view recovers (because the pool reduction is split with client B), so the withdrawer can simply call again. Eight iterations are sufficient to drive client B's surplus to zero:

- Total extracted to client A's recipient: ~199.22 underlying (vs the 100 client A honestly earned).
- Client B's surplus: drops from 100 → ~0.39 (~99.6% drained).
- Both principals: untouched throughout.

There is no rate limit, no per-call cap derived from honest ownership, and no on-chain record that the cross-client transfer occurred. The drain is silent until client B's withdrawer attempts an extraction and finds the surplus gone (or, depending on rounding and slippage, until the function reverts on `amount <= surplus` because client B's surplus is now smaller than what the off-chain accounting expected).

### Impact

- **Direct theft of yield between clients.** Any single authorized withdrawer attached to *any* client can drain the surplus of every other client in the same strategy. There is no prerequisite, no race, and no need to compromise the victim's withdrawer.
- **Principal is preserved (correctly), but surplus is unprotected.** The strategy's documented invariant — "principal NEVER modified by `_withdrawFrom`" — holds, which is why this slipped past the obvious safety check. The bug is one layer up: surplus accounting is in the wrong unit (pro-rata underlying view of a shared share pool) for the operation being performed (selling shares out of that same shared pool).
- **Loss is silent and unbounded over time.** Repeated calls compound. There is no event distinguishing "client A's honest yield" from "client B's stolen yield" because the function does not track them separately.
- **No mitigating governance step.** `setWithdrawer` simply enables an address; once enabled, that withdrawer can target any client's address as the `client` parameter to `_withdrawFrom`. The protection model assumes the withdrawer only acts on a single client's behalf, but nothing in the contract enforces that.

### Relationship to other findings

This finding belongs to the same root-cause family as H-01 and H-02: per-client accounting is denominated in underlying (a pro-rata view of the shared share pool) while the operations that modify state act directly on the shared share pool. H-03 is the cleanest and most direct realization of that root cause because the cross-client transfer is purely a function of calling `withdrawFrom` — no deposit/withdraw race, no price movement timing, and no client-side cooperation is required. The exploit is one external call from any authorized withdrawer.

## Recommended mitigation steps

The structural fix is to track shares per client, not just underlying-denominated principal, so that "client A's surplus" can be expressed and consumed as a share quantity that is provably owned by client A.

A minimal in-place change is:

1. On `deposit`, record the shares minted for that deposit in a new mapping, e.g. `clientShares[token][client] += shares`.
2. Define each client's surplus in share terms: `surplusShares(client) = vault.balanceOf(strategy) * (clientShares[token][client] / sumOfClientShares) - convertToShares(clientBalances[token][client])`. Equivalently, track `clientInitialShares[token][client]` (shares purchased at deposit time) and compute surplus as `currentClientShares - clientInitialShares` where `currentClientShares = vault.balanceOf(strategy) * clientShares[token][client] / totalClientShares`.
3. In `_withdrawFrom`, cap `sharesToSell` to that client's surplus shares:

```solidity
uint256 surplusShares = _surplusSharesOf(token, client);
uint256 sharesToSell = vault.convertToShares(amount);
if (sharesToSell > surplusShares) {
    sharesToSell = surplusShares;
}
```

4. Decrement `clientShares[token][client]` by `sharesToSell` after the swap so subsequent calls cannot re-extract the same surplus.

A simpler near-equivalent: when extracting, cap the underlying `amount` to a share-fair value derived from the client's *own* share count rather than the pro-rata view of the pool, e.g.:

```solidity
uint256 ownedShares = clientShares[token][client];
uint256 maxFairAmount = vault.convertToAssets(ownedShares) - clientBalances[token][client];
require(amount <= maxFairAmount, "exceeds client's own surplus");
```

This still requires introducing per-client share tracking, but does not require reworking `totalBalanceOf` callers.

The most rigorous fix is full per-client share isolation (e.g. depositing into the underlying ERC4626 vault on a per-client subaccount, or maintaining a per-client `principalShares` ledger and a per-client `accruedShares` ledger). That eliminates the entire family of cross-client bugs (H-01, H-02, H-03) at the cost of a larger refactor.

In all cases, `_withdrawFrom` must additionally update its per-client share accounting on success — not doing so is the proximate reason this bug compounds across repeated calls.
