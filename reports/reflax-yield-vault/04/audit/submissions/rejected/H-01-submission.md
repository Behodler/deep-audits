<!--
C4 Submission Metadata
Title: [H-01] First-mover bank run: principal debited by requested-not-received on AMM dislocation
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L302-L339
PoC File: H-01-poc.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy._withdrawInternal` swaps vault shares for whatever the AMM is willing to give, but always debits the caller's `clientBalances` (and the strategy-wide `totalDeposited`) by the **requested** amount rather than the **received** amount, and applies no per-client cap on how many of the strategy's shares a single withdrawal may consume. As soon as the underlying AMM dislocates, the first client to withdraw collects their full nominal principal in underlying while later clients are paid out at the depressed price and have their full principal silently zeroed. The shortfall is not absorbed pro-rata by the share pool — it is dumped entirely on whoever happens to withdraw last.

### Vulnerability details

The relevant code in [`ERC4626MarketYieldStrategy.sol#L302-L339`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L302-L339):

```solidity
function _withdrawInternal(address token, uint256 amount, address recipient, address balanceHolder) internal {
    require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
    require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");
    require(recipient != address(0), "ERC4626MarketYieldStrategy: recipient cannot be zero address");

    // Cap amount to available principal (prevents dust from blocking withdrawal)
    uint256 availablePrincipal = clientBalances[token][balanceHolder];
    if (amount > availablePrincipal) {
        amount = availablePrincipal;
    }

    // Convert requested amount to shares, cap to actual balance
    uint256 sharesToSell = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));
    if (sharesToSell > availableShares) {
        sharesToSell = availableShares;
    }

    // Calculate ideal underlying output and minimum acceptable
    uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
    uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

    // Approve AMM adapter to spend vault tokens
    IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);

    // Swap vault tokens -> underlying via AMM
    uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);

    // Transfer underlying to recipient
    underlyingToken.safeTransfer(recipient, underlyingReceived);

    // SECURITY: Decrement principal by REQUESTED amount, not RECEIVED amount
    // Any difference accumulates as protocol-owned yield
    clientBalances[token][balanceHolder] -= amount;
    totalDeposited[token] -= amount;

    emit Withdrawn(token, msg.sender, recipient, amount, sharesToSell);
}
```

Two design choices interact to create the vulnerability:

1. `sharesToSell` is computed from `vault.convertToShares(amount)` (the ERC4626 fair value of the requested principal) and then capped only at `availableShares` — the strategy's entire vault-share balance. There is **no cap** that limits an individual client to their pro-rata slice `(totalShares * clientBalances[token][holder]) / totalDeposited[token]`. A single client can therefore burn shares belonging to other clients in one call.
2. The principal accounting at lines 333-336 is debited by `amount` (the requested principal), not by an amount derived from `underlyingReceived` (what was actually paid out). When the AMM is dislocated, this turns a partial fill into a full debit: the client's balance is zeroed but they only got back a fraction of the underlying.

### Acknowledged design choice and why this exceeds it

The contract NatSpec at lines 22-23 explicitly documents the requested-vs-received rounding rule:

> Rounding rules: All rounding favors the protocol. Principal is decremented by requested amount, not received amount, so any shortfall accumulates as protocol-owned yield.

That documented design contemplates **small** slippage events around a fair AMM price, where the shortfall is a few basis points and is meant to accrue to the share pool as protocol-owned yield that benefits remaining clients pro-rata. Two assumptions silently underlie that model:

- the share pool absorbs the loss collectively, so all clients share the small slippage cost, and
- the AMM price stays close to fair value between calls.

Neither assumption holds during an actual AMM dislocation (depeg, low-liquidity attack, market crash, oracle drift between the ERC4626 vault's `convertToAssets` and the AMM's spot price). When the AMM dislocates by, say, 50%, the design no longer "rounds in favor of the protocol" — it asymmetrically dumps the entire dislocation on one client, while paying out an earlier withdrawer at full fair value out of shares that did not belong to them. The shortfall does **not** accumulate as pro-rata protocol-owned yield; it is realised as a direct loss against whichever client happens to withdraw second.

Combined with the missing per-client share cap, the result is not a rounding rule — it is a winner-takes-all bank run incentive.

### Impact

Two clients with **identical** principal and **identical** fair entitlement at `t0` end up with materially different recoveries based purely on withdrawal order. The PoC at `test/poc-H-01.t.sol` demonstrates the concrete asymmetric outcome:

1. Alice and Bob each deposit `1000e18` underlying at a fair 1:1 AMM rate. The strategy holds `2000e18` vault shares; both clients have `1000e18` recorded principal.
2. Alice calls `withdraw(underlying, 1000e18, alice)` while the AMM is still 1:1 — she receives the **full** `1000e18`. Her principal is correctly zeroed.
3. The AMM dislocates: vault->underlying rate drops to `0.5e18` (50% peg loss). The owner widens `slippageToleranceBps` to 5000 (50%) so that withdrawals can clear at all — refusing to do so simply bricks all client withdrawals, which is at least as bad an outcome.
4. Bob calls `withdraw(underlying, 1000e18, bob)`. `convertToShares(1000e18) = 1000e18` shares are burned, swapped at the dislocated rate, and Bob receives only **`~500e18`** underlying.
5. Bob's `clientBalances[underlying][bob]` and `totalDeposited[underlying]` are both decremented by the **full** `1000e18`. The strategy retains no record of the missing `~500e18` and Bob has no on-chain claim to recover it.

PoC console output:

```
Alice (first to withdraw): received full 1000000000000000000000
Bob   (last to withdraw):  received only 499999999999999999999
Bob's shortfall (silently absorbed): 500000000000000000001
```

The pathology generalizes:

- **Direct theft of one client by another.** Alice received underlying that economically belonged to Bob's pro-rata share of the (now-shared) pool. With the per-client cap absent, Alice was free to burn any number of vault shares, including ones that backed Bob's principal. A correctly-capped Alice would have received only her pro-rata share of the pool's current value.
- **Incentivises a bank run on any peg event.** Any client who notices an AMM discount — public information at all times — is rationally incentivised to withdraw immediately, because the cost of being last is the entire dislocation. This will drain a strategy long before any operational response (pause, slippage adjustment) can be coordinated.
- **No recourse.** Once `clientBalances` and `totalDeposited` are decremented, there is no on-chain accounting of the shortfall. The protocol cannot identify Bob as a creditor, cannot socialise the loss back across clients, and cannot dispute Alice's withdrawal.
- **The strategy is documented as multi-client (`setClient` / `clientBalances` / `withdrawAsOwner`)**, so this is the intended deployment shape, not a hypothetical.

The plain "documented as protocol-owned yield" defence does not apply here, because the lost value never reaches the share pool: the share pool **was** the loss. There is no protocol-owned yield to point at — only a missing balance on Bob's side of the ledger.

## Recommended mitigation steps

The root cause is two-fold and either fix is sufficient on its own; applying both is recommended.

### Option A (preferred): cap each withdrawal to the client's pro-rata share of the pool, then debit principal by received

Track or compute each client's share-of-pool entitlement and cap `sharesToSell` to that ceiling. The cleanest version is to track per-client share counts directly (Option C below), but a minimal patch on the existing storage layout works:

```solidity
// Compute the caller's pro-rata share entitlement.
uint256 totalShares     = vault.balanceOf(address(this));
uint256 clientMaxShares = (totalShares * clientBalances[token][balanceHolder]) / totalDeposited[token];

uint256 sharesToSell = vault.convertToShares(amount);
if (sharesToSell > clientMaxShares) {
    sharesToSell = clientMaxShares;
}

// ... swap ...

// Debit principal by what was actually received, not what was requested.
uint256 principalDebit = underlyingReceived > clientBalances[token][balanceHolder]
    ? clientBalances[token][balanceHolder]
    : underlyingReceived;
clientBalances[token][balanceHolder] -= principalDebit;
totalDeposited[token]                -= principalDebit;
```

This guarantees no client can ever burn shares belonging to another, and that a client's principal accounting reflects what they actually received.

### Option B (lighter-touch): pro-rate the principal debit to the realised price

If the maintainers wish to keep the existing share-pool model and only fix the asymmetric loss, debit `clientBalances` and `totalDeposited` in proportion to the realised price:

```solidity
// Debit principal in proportion to what was actually received vs. what the AMM should have paid.
uint256 principalDebit = (amount * underlyingReceived) / idealUnderlying;
clientBalances[token][balanceHolder] -= principalDebit;
totalDeposited[token]                -= principalDebit;
```

This converts the dislocation from a winner-takes-all event back into a pro-rata loss across all clients (since the unburnt principal still backs the same depleted share pool), restoring the documented "shortfall accumulates as protocol-owned yield" semantics in a way that survives large peg events. Note: this option still permits a single client to consume more than their pro-rata share count in one call, so it must be combined with the per-client share cap from Option A to fully eliminate the bank run incentive.

### Option C (architectural): track per-client shares, not per-client underlying

The most robust fix is to stop tracking principal in underlying units entirely and instead track each client's share count in the strategy. Withdrawals burn only the caller's own shares; deposits mint shares against the caller; the AMM swap rate at withdrawal time is the caller's own problem and cannot leak across clients. This eliminates the entire class of bug (the cross-client share pool no longer exists) at the cost of a more invasive refactor.

Whichever option is chosen, the invariant the strategy must enforce is: **no client withdrawal may consume more vault shares than the caller's pro-rata entitlement to the pool, and no client's principal accounting may be debited by more than what the caller actually received.**
