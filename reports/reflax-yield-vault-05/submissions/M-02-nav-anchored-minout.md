<!--
C4 Submission Metadata
Title: [M-02] NAV-anchored minOut is execution-price-blind, letting a sandwich extract up to slippageToleranceBps per swap (concentrated onto the last withdrawer by requested-not-received accounting)
Severity: Medium
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L276-L283
PoC Files: poc-M02-nav-sandwich.t.sol, poc-M03-socialized-slippage.t.sol
-->

## Finding description and impact

### Summary

Every swap performed by `ERC4626MarketYieldStrategy` derives its slippage floor (`minOut`) from the vault's own NAV (`vault.convertToShares` / `vault.convertToAssets`), haircut by `slippageToleranceBps`. This NAV is computed entirely independently of the Curve pool the trade actually clears on, and `CurveAMMAdapter` forwards the floor verbatim to the router. As a result the floor cannot detect that the pool is skewed: a swap can clear at a price strictly worse than fair value yet still above the NAV-derived floor. An MEV sandwich can therefore extract up to `slippageToleranceBps × tradeSize` on every deposit, withdrawal, and skim, with no on-chain detection.

The absence of any swap deadline aggravates the exposure (neither `IAMMAdapter.swap` nor `ICurveRouterNG.exchange` accepts one), widening the window during which a builder/validator can position the trade against a co-located sandwich.

### Vulnerability details

The strategy computes its swap floor identically on every value-moving path:

```solidity
minOut = ideal * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
```

where `ideal` is `vault.convertToShares(amount)` on the deposit leg or `vault.convertToAssets(shares)` on the withdraw/skim legs. The `minOut` sites are:

- Deposit: `ERC4626MarketYieldStrategy.sol#L276-L277` (then `swap` at `:283`)
- Withdraw: `ERC4626MarketYieldStrategy.sol#L321-L322` (then `swap` at `:328`)
- Total withdraw: `ERC4626MarketYieldStrategy.sol#L383-L384`
- Skim: `ERC4626MarketYieldStrategy.sol#L435-L436`
- Batch skim: `ERC4626MarketYieldStrategy.sol#L482-L483`

The adapter adds no independent price bound; it passes `minAmountOut` straight through to the router:

```solidity
// CurveAMMAdapter.sol:138
amountOut = router.exchange(r.path, r.swapParams, amountIn, minAmountOut, r.pools, msg.sender);
```

The defect is that `ideal` is a NAV reference that has nothing to do with the venue. The realised slippage cap is `slippageToleranceBps` measured against fair NAV, and that cap is the only thing standing between the trade and a sandwich. The reference never observes the pool, so it cannot reject a trade merely because the pool is skewed; it only rejects when realised output falls below `fairValue × (1 - bps)`. The attacker's profit per swap is therefore bounded by, and approaches, `slippageToleranceBps × tradeSize`:

1. Attacker front-runs the strategy's Curve swap, pushing the USDe/sUSDe pool off-peg.
2. The strategy's swap clears at the worsened marginal price. Because the NAV-derived `minOut` absorbs up to `bps` of deviation, the swap succeeds.
3. Attacker back-runs to restore the pool and banks the difference, net of Curve fees and gas.
4. The matching deposit/withdraw on the other leg presents the same opportunity.

### Severity rationale (why Medium, not High)

For the in-scope deployment the "vault" is sUSDe (Ethena staked USDe). Its `convertToAssets`/`convertToShares` derive from an internal `totalAssets()/totalSupply()` ratio with reward vesting, **not** an AMM spot price. There is no flash-loan-atomic lever to raise it within a transaction: you cannot increase `sUSDe.totalAssets` without an actual USDe transfer (a gift to all holders), and mint/burn move supply and assets in lockstep. The NAV anchor is therefore poor-but-safe: blind to execution price but not atomically manipulable.

Consequently this is a value leak under stated assumptions (a public mempool, a profitably skewable pool, and an active MEV sandwicher) bounded by an admin-set parameter, with an external requirement — i.e. C4 Medium. It is **not** a High: there is no atomic NAV manipulation and no unbounded theft primitive on the current USDe/sUSDe route.

**Forward-looking deployment constraint.** The flaw is structural to `ERC4626MarketYieldStrategy`, not specific to sUSDe. If this strategy is ever deployed over a vault whose ERC4626 share price *is* atomically manipulable (for example a vault whose `totalAssets` tracks an AMM-derived or otherwise same-transaction-movable balance), the NAV reference itself becomes attacker-controlled and the same code path escalates to a High-severity direct-theft primitive. This is flagged as a deployment constraint on future routes, not a claim about the present sUSDe route.

### Impact amplification: requested-not-received accounting concentrates the leak onto the last withdrawer

The deposit-side leak does not simply vanish into the depositor's own balance — it under-collateralizes a shared pool, and a second accounting behaviour concentrates that deficit onto whoever withdraws last.

`_withdrawInternal` sells `sharesToSell = vault.convertToShares(amount)` (capped to held shares at `:316-318`), forwards `underlyingReceived` to the recipient, then debits principal by the **requested** `amount`, not the received value:

```solidity
// ERC4626MarketYieldStrategy.sol#L333-L336
// SECURITY: Decrement principal by REQUESTED amount, not RECEIVED amount
// Any difference accumulates as protocol-owned yield
clientBalances[token][balanceHolder] -= amount;
totalDeposited[token] -= amount;
```

Decrementing by the requested amount is a documented design decision. The economic consequence, however, is that when the pool is under-collateralized (from M-02 deposit-side leakage), early withdrawers are debited their full principal and the strategy sells `convertToShares(amount)` worth of shares to honour it — removing more value from the shared backing than was ever deposited for them. The principal ledger stays internally consistent (`totalDeposited == Σ clientBalances` holds throughout), so nothing reverts and nothing flags. The deficit is silently socialized across the remaining share pool until the last withdrawer requests their principal, finds `convertToShares(amount) > availableShares`, hits the `:316-318` cap, and silently recovers less than their fully-debited principal.

**This amplification is a worst-case impact concentration of M-02, not an independent bug.** It has no standalone loss primitive: it requires M-02's deposit-side leak (or another finding's leak) to first under-collateralize the pool. The PoC validator confirmed this with a counterfactual — with fair deposits and only adverse withdrawals, the requested-not-received decrement distributes slippage evenly across withdrawers (each absorbs exactly their own swap's slippage) and produces no concentrated last-withdrawer shortfall. The amplifier turns a pool-wide, per-client leak into a single concentrated, silent shortfall borne by the last exiter.

## Proof of Concept

Two runnable Foundry PoCs are provided. Both import the real in-scope `ERC4626MarketYieldStrategy` directly (verified byte-identical to the read-only `lib/reflax-yield-vault` source) and use faithful mocks. `MockAMMAdapter.swap` genuinely enforces `require(amountOut >= minAmountOut)`, so the contract's own `minOut` logic is the component under test; `MockERC4626Vault` uses standard proportional ERC4626 share math. No mock fakes the vulnerability.

Run:

```bash
cd workspace/reflax-yield-vault
forge test --match-path 'test/poc-M02-nav-sandwich.t.sol' -vv
forge test --match-path 'test/poc-M03-socialized-slippage.t.sol' -vv
```

### PoC 1 — `poc-M02-nav-sandwich.t.sol`: the floor is blind to execution price

`slippageToleranceBps = 50` (0.5%). The adapter is configured to deliver exactly `(1 - bps)` of fair NAV — the worst output the NAV-derived floor still accepts — modelling a sandwich that skews the pool below fair value but not below the floor. Both deposit and withdraw legs are exercised on a 1,000,000 USDe trade.

The assertions are non-tautological — each compares a measured on-chain quantity against fair value:

- `assertGe(out, navFloor)` — the skewed swap **clears** the NAV floor (no revert; the protection "passes"). This is the crux: `minOut` is derived from vault NAV and never observes execution price.
- `assertLt(out, fairValue)` — the protocol nonetheless received strictly less than fair NAV value.
- `assertApproxEqRel(leak, bps × tradeSize, 0.1%)` — the leak equals the full tolerance.

Demonstrated numbers:

- Deposit: fair shares 1,000,000; NAV floor 995,000; shares bought **995,000** (clears, no revert); principal debited the full **1,000,000**; backing value 995,000 → **leak ≈ 5,000 USDe = bps × tradeSize**.
- Withdraw: fair out 1,000,000; NAV floor 995,000; received **995,000** vs fair 1,000,000 → **leak ≈ 5,000 USDe**.

### PoC 2 — `poc-M03-socialized-slippage.t.sol`: the leak concentrates onto the last withdrawer

10 clients deposit 100,000 each while the swap venue is sustainedly adverse (deposits clear at 0.5% below NAV — the M-02 leak), so the pool is under-collateralized from inception. The withdraw leg then runs at fair NAV, isolating the requested-not-received accounting as the concentration mechanism rather than further withdraw slippage.

Non-tautological assertions:

- `assertLt(backingStart, totalPrincipal)` — 995,000 backing vs 1,000,000 principal at start; the pool is under-collateralized while `totalDeposited == Σ clientBalances` (INV-1) still holds exactly.
- `assertLt(sharesLeft, sharesRequested)` — the last withdrawer hits the `sharesToSell > availableShares` cap at `:316-318`.
- `assertLt(lastGot, DEPOSIT)` — the last withdrawer recovers less than their fully-debited principal.
- `assertApproxEqRel(DEPOSIT - lastGot, totalPoolLeak, 2%)` — the last client absorbs the entire pool's socialized under-collateral, not merely one swap's slippage.

Demonstrated numbers:

- Aggregate principal 1,000,000; held-share backing **995,000** at start (5,000 deposit-side leak).
- The 9 early clients each fully recover **100,000** (full principal debited), draining the pool.
- The last client requests 100,000 but only **95,000** shares remain → receives **95,000** against a fully-debited 100,000 → **silent 5,000 USDe shortfall**, exactly the pool's total socialized under-collateral. No insolvency revert fires.

The validator's counterfactual (since removed) confirmed the dependency: with fair deposits and an adverse withdraw leg, every withdrawer including the last received 99,500 (each absorbing only their own 500 slippage) — no concentration. The last-withdrawer shortfall therefore exists only because the M-02 deposit-side leak first under-collateralizes the pool.

## Recommended mitigation steps

### 1. Bound execution price independently of NAV (primary fix)

The NAV anchor must not be the only slippage control, because it cannot see the venue. Add an execution-price cross-check so that a skewed-pool fill is rejected even when it clears the NAV floor:

- In `CurveAMMAdapter` (or the strategy), cross-check the realised `amountOut` against a pool-aware quote (e.g. the Curve router's `get_dy` for the same path/params at execution) within a tight tolerance, reverting if the fill deviates from the live pool quote by more than a small bound. This bounds the trade against the price it actually clears on, closing the structural gap between the reference and the venue.
- Keep `slippageToleranceBps` as tight as the pool's organic slippage allows; on a stable pair organic slippage is small, so a tight bound is feasible.
- Consider routing swaps through a private relay / private orderflow to remove the public-mempool sandwich precondition entirely.

### 2. Add a per-swap deadline

Thread a `deadline` parameter through `IAMMAdapter.swap` and into the router call so pending deposit/withdraw transactions cannot be held and executed later under attacker-favourable pool conditions. (The current `ICurveRouterNG.exchange` binding omits a deadline; the interface should be extended, or a `block.timestamp <= deadline` guard added at the adapter boundary.)

### 3. Remove the amplification: debit principal by realised value

To eliminate the last-withdrawer concentration even if some residual leak remains, debit principal by `min(requested, fairValueOfSharesActuallySold)` rather than the full requested amount, or track per-client share backing directly. This ensures that any execution shortfall is borne by the withdrawer who incurred it rather than being socialized onto the remaining pool and concentrated on the last exiter. Alternatively, document explicitly that a single strategy instance must not be shared across mutually-distrusting clients.
