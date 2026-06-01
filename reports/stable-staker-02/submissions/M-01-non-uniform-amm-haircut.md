<!--
ID: ss2m1
C4 Submission Metadata
Title: [M-01] migrateOut distributes underwater loss non-uniformly across batches under a slippage-bearing yield strategy
Severity: Medium
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L301-L348
PoC File: workspace/stable-staker/test/PoC_M01_PerBatchAmmHaircut.t.sol
Audited HEAD: stable-staker @ 0812167
Fingerprint: b5218ab2...
-->

## Finding description and impact

### Summary

`StableStaker.migrateOut` ([src/StableStaker.sol#L301-L348](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L301-L348)) re-credits an underwater migration pro-rata, but it computes the haircut ratio **per `migrateOut` call (per batch)** rather than against the global pool position. When the configured `IYieldStrategy` realizes withdrawals through an AMM with price impact (e.g. `ERC4626MarketYieldStrategy`, which redeems vault shares and sells the underlying through a Curve/AMM pool), each batch's aggregate exit moves the pool price. Earlier batches realize a smaller haircut and later batches a larger one, so two users with **identical principal** are re-credited materially different amounts based solely on which batch they were placed in. The M-01 fix's stated intent — uniform pro-rata distribution of the underwater loss — is therefore not achieved for slippage-bearing strategies whenever migration spans multiple batches.

### Vulnerability details

The relevant code in `migrateOut` (the M-01 fix at lines 331-348):

```solidity
if (totalPrincipal > 0) {
    // Redeem the aggregate principal in a single strategy call (the farm is one client).
    uint256 payout = _routeExit(token, totalPrincipal, false);
    IERC20(token).safeTransfer(msg.sender, payout);

    // M-01 fix: when below par, re-credit users on the REALIZED basis so
    // Σ amounts[i] <= payout ...
    if (payout < totalPrincipal) {
        for (uint256 i = 0; i < users.length; i++) {
            if (amounts[i] > 0) {
                amounts[i] = (amounts[i] * payout) / totalPrincipal;
            }
        }
    }
}
```

Both inputs to the scaling ratio are scoped to the **single call**:

- `totalPrincipal` is the sum of principal of only the users included in *this* `migrateOut` call (the batch), accumulated in the loop at line 325.
- `payout` is the realized balance delta of a *single* aggregate `_routeExit(token, totalPrincipal, false)` withdrawal for *that* batch (line 334).

The full staker set generally cannot be migrated in one transaction: the per-user loop at line 312 is unbounded, and the project's own documentation directs operators to build batches off-chain via `getStakers` / `getStakersRange`. Migration therefore spans multiple `migrateOut` calls.

Under a strategy that realizes value by selling through an AMM, withdrawal price impact is cumulative and persistent across calls:

1. **Batch A** sells into a fresh pool and realizes a *higher* payout-per-principal (smaller haircut).
2. The pool is now more depleted (reserveBase down, the sold side up).
3. **Batch B** sells into the depleted pool and realizes a *lower* payout-per-principal (larger haircut).

Because the scaling ratio `payout / totalPrincipal` is recomputed independently inside each call, the re-credited amount for equal-principal users diverges purely as a function of batch ordering, which is not a property any user controls.

This is not a malicious-admin issue. The disparity arises under entirely honest migrator operation, as an inherent consequence of sequential AMM exits combined with per-batch scaling. A flat-redemption strategy (plain ERC-4626, no price impact) does not exhibit the disparity — confirmed by the control test below.

### Impact

- **Cross-user value redistribution.** Later-batch users systematically subsidize earlier-batch users. Two users who staked the same principal realize unequal losses based only on batch placement.
- **Spec deviation.** The M-01 fix is explicitly intended to distribute the underwater loss uniformly pro-rata; that property is silently violated for slippage-bearing strategies, which are an in-scope, supported strategy type (`reflax-yield-vault`'s AMM-backed strategies).
- Conservation is preserved within each call (`Σ amounts[i] <= payout`, division dust accrues to the protocol as already designed), so there is no theft and no protocol loss. This is a value leak / unfairness between users, not a drain.

Severity Medium: a value leak under stated assumptions and external requirements, with no direct loss of protocol assets.

### External requirements / preconditions

1. The pool is underwater at migration time (`totalBalanceOf < principalOf`), i.e. the scaling branch fires.
2. The configured yield strategy realizes withdrawals through an AMM with price impact (e.g. `ERC4626MarketYieldStrategy`). A flat-redemption strategy does not trigger the disparity.
3. Migration spans multiple `migrateOut` batches (forced by the unbounded loop and the project's off-chain batching guidance).

## Recommended mitigation steps

Decouple the **credited** ratio (which should be global and uniform across all batches) from the **realized** payout (which is necessarily per-call). Compute the underwater haircut ratio once, against the global pool position, and apply that same protocol-wide ratio to every batch:

```solidity
// At migration start (or first batch), snapshot the global ratio from the strategy's
// reported total vs. tracked principal, e.g.:
//   globalRatio = strategy.totalBalanceOf(token, address(this)) / strategy.principalOf(token, address(this))
// Then in every migrateOut batch, credit each user as:
//   amounts[i] = (amounts[i] * globalRatioNum) / globalRatioDen;
// rather than dividing this batch's realized payout by this batch's own totalPrincipal.
```

The realized `payout` still funds the migrator per call (and realized-vs-credited differences accrue to the protocol, as already designed), but every user with equal principal is credited identically regardless of batch.

Alternatives, in decreasing order of preference:

1. Snapshot a global haircut ratio at migration start and apply it uniformly to all batches (above).
2. Require the entire underwater pool to be migrated in a single call (limited by the unbounded-loop gas concern, so generally impractical for large staker sets).
3. At minimum, explicitly document that AMM-backed-strategy pools must not be migrated in multiple batches while underwater, so operators are aware of the fairness consequence.

## Proof of Concept

A runnable Foundry PoC is provided. It drives the **real** `StableStaker`, `StableStakerMigrator`, and `FlaxToken` (phUSD) through their real `_routeExit` / `_routeDeposit` paths, against a faithful constant-product (`xy = k`) AMM-price-impact strategy implementing the production `IYieldStrategy` interface. A control test swaps in a flat-discount (non-slippage) strategy to isolate the disparity to AMM price impact.

### Files

- `workspace/stable-staker/test/PoC_M01_PerBatchAmmHaircut.t.sol` — the test.
- `workspace/stable-staker/test/mocks/MockAmmYieldStrategy.sol` — the constant-product strategy mock.

### Run

```bash
cd workspace/stable-staker
forge test --match-path test/PoC_M01_PerBatchAmmHaircut.t.sol -vv
```

### Results (validated)

- `test_M01_amm_perBatch_haircut_is_unfair` **PASSES**: two users each stake 1,000,000 USDC; the pool is driven underwater; each user is migrated in a separate single-user batch against the same mutating AMM pool. `user1` (batch A, fresh pool) is re-credited **900,000 USDC**; `user2` (batch B, depleted pool) is re-credited **750,000 USDC**. Disparity 150,000 USDC = 1666 bps (16.66%) for identical principal.
  - `xy = k` arithmetic: `9.9M · 1M / 11M = 900k`; the pool then moves to `(9.0M, 11M)`; `9.0M · 1M / 12M = 750k`.
- `test_M01_flatDiscount_perBatch_haircut_is_fair` **PASSES** (control): a flat-discount strategy re-credits both batches equally at 900,000 USDC, confirming the disparity is specific to AMM price impact.

The magnitude scales with pool depth (shallower pool → larger gap), but the directional inequality (earlier batch > later batch for equal principal) is invariant.

### Key PoC excerpt — the strategy's constant-product withdraw (slippage source)

```solidity
// MockAmmYieldStrategy.withdraw: redeem `amount` of principal by SELLING it through an xy=k pool.
// Output = reserveBase * amount / (reserveQuote + amount). Sequential calls deplete reserveBase
// and inflate reserveQuote => each successive batch is priced worse (persistent price impact).
uint256 rb = reserveBase[token];
uint256 rq = reserveQuote[token];
uint256 out = (rb * amount) / (rq + amount);
if (out > rb) out = rb;
reserveBase[token] = rb - out;
reserveQuote[token] = rq + amount;
principal[token][recipient] -= amount;   // decremented by REQUESTED amount; diff is protocol-owned
totalPrincipal[token] -= amount;
if (out > 0) IERC20(token).safeTransfer(recipient, out);
```

### Key PoC excerpt — the two-batch migrateOut assertions

```solidity
// Seed a DEEP pool sitting just below par so the aggregate exit is underwater (scaling branch fires).
uint256 baseReserve  = 9_900_000e6;
uint256 quoteReserve = 10_000_000e6;
usdc.mint(owner, baseReserve);
usdc.approve(address(strat), baseReserve);
strat.seedPool(address(usdc), baseReserve, quoteReserve);
assertTrue(oldStaker.withdrawDisabled(address(usdc)), "pool must be underwater");

// Migrate in TWO SEPARATE batches against the SAME (mutating) pool.
migrator.migrate(address(usdc), _batch(user1)); // batch A: fresh pool, best price
migrator.migrate(address(usdc), _batch(user2)); // batch B: depleted pool, worse price

uint256 credited1 = _creditedOnNew(user1);
uint256 credited2 = _creditedOnNew(user2);

// Identical principal, different batch => different re-credit. EARLIER > LATER.
assertGt(credited1, credited2, "AMM price impact: earlier batch must be re-credited more");
uint256 gapBps = ((credited1 - credited2) * 10_000) / credited1;
assertGe(gapBps, 10, "disparity should be material under AMM price impact");
assertLt(credited1, PRINCIPAL, "user1 took a (smaller) haircut");
assertLt(credited2, PRINCIPAL, "user2 took a (larger) haircut");
```

The PoC source-under-test reflects the M-01 fix at commit `0812167` (the scaling branch at lines 341-347 is present and exercised). The two PoC files can be dropped into the project's `test/` and `test/mocks/` directories and run with the project's existing Foundry suite.

## Tools used

Foundry (forge test), manual review.
