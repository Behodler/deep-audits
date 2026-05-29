<!--
C4 Submission Metadata
Title: [M-02] AMM withdraw slippage anchored to vault internal rate bricks exits during AMM discount
Severity: Medium
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L313-L328
Target File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol
Target Lines: 276-283 (deposit), 313-328 (withdraw), 378-390 (totalWithdraw), 428-442 (withdrawFrom)
PoC File: M-02-poc.t.sol
Note: This finding was downgraded from High to Medium during second-opinion severity review. Reason: DoS-on-withdraw maps to "protocol availability impacted" = Medium; the sandwich-extraction framing is structurally weak because the vault-anchored minOut is conservative, so manipulated swaps revert rather than executing at unfavorable rates.
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy` is positioned as the strategy of choice for ERC4626 vaults whose secondary AMM market price decouples from the vault's internal accumulator (the canonical example called out in the natspec is sUSDe, which can trade at a discount on Curve during cooldown pressure). The whole reason to route through an AMM rather than `vault.deposit/redeem` is that the AMM and the vault's internal price are expected to diverge.

The implementation, however, computes its slippage anchor (`minOut`) directly from `vault.convertToAssets` / `vault.convertToShares`, i.e. from the vault's own internal price-per-share. The slippage check therefore protects against deviation from the wrong reference: it requires the AMM to deliver something close to the *vault internal* value rather than something close to the *AMM market* value.

This shows up in four call sites, all using the same anti-pattern:

- `_depositInternal` ([L276-L283](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L276-L283))
- `_withdrawInternal` ([L313-L328](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L313-L328))
- `_totalWithdraw` ([L378-L390](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L378-L390))
- `_withdrawFrom` ([L428-L442](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L428-L442))

The withdraw-side code at [L313-L328](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L313-L328):

```solidity
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
```

### Vulnerability details

There are two dimensions to the bug; both stem from anchoring `minOut` to the vault internal rate.

**1. Withdraw DoS during AMM discount (the failure mode demonstrated in the PoC).**

For any withdrawal, the strategy first computes `sharesToSell = vault.convertToShares(amount)` and then `idealUnderlying = vault.convertToAssets(sharesToSell)`. This is a round trip through the vault's internal price-per-share, so `idealUnderlying` is approximately equal to the requested `amount` regardless of how much the vault has appreciated. `minOut` therefore reduces to:

```
minOut ~= amount * (MAX_BPS - slippageBps) / MAX_BPS
```

The AMM, by contrast, returns underlying at the *market* price for the vault token. When the AMM is trading the vault token at any discount larger than `slippageBps`, the AMM's actual `amountOut` is strictly below `minOut`, and the swap reverts. Crucially, this is independent of withdrawal size: a 1-wei withdrawal fails the same way as a 1,000-token withdrawal because the round-trip math cancels the price-per-share factor.

The result is that the strategy is bricked precisely under the market condition it was advertised to handle. Clients have no self-service exit. The only escape is `emergencyWithdraw`, which is `onlyOwner` and transfers raw vault shares to the owner address; this delivers nothing to the affected client and bypasses the AMM entirely, defeating the strategy's stated purpose.

**2. Sandwich extraction during deposits/withdraws (the failure mode at all four call sites).**

Even when the AMM and vault rates are roughly aligned, `slippageToleranceBps` is being applied to the wrong reference. The slippage budget is meant to absorb transient AMM price impact and small adversarial reordering. By anchoring to the slow-moving vault accumulator, the check tolerates *any* AMM deviation up to `slippageBps` away from the vault rate, even when the prevailing AMM mid-price is much closer. An MEV searcher can:

1. Front-run the strategy's swap by skewing the Curve pool against the strategy's swap direction.
2. Let the strategy's swap execute at the disadvantageous price (the vault-anchored `minOut` is permissive enough to accept it).
3. Back-run by reverting the pool skew and pocketing the difference.

Because `slippageToleranceBps` is set in the natspec example to values like 50-100 bps and is decoupled from the live AMM mid, every deposit and withdraw becomes a free, mechanical sandwich opportunity for any MEV bot. Value bleeds out of the client share pool one swap at a time.

### Impact

- **Withdrawal DoS / fund lockup (High).** Any AMM discount on the vault token greater than the configured slippage tolerance bricks every client withdrawal — including small/dust withdrawals — across `withdraw`, `withdrawAsOwner` (via `_withdrawInternal`), `_totalWithdraw`, and `_withdrawFrom`. Funds are trapped indefinitely with no client-side recovery; only the owner's `emergencyWithdraw` can pull funds, and it routes vault shares to the owner rather than returning underlying to the client. The market condition that triggers this is exactly the cooldown-pressure scenario the strategy is designed for, so the failure mode coincides with the strategy's intended use case rather than an edge case.
- **Direct value leak via sandwich attacks (High).** All four AMM swap sites (deposit, withdraw, totalWithdraw, withdrawFrom) accept up to `slippageToleranceBps` of deviation away from the vault internal rate, not from the live AMM mid. MEV searchers can front-/back-run every strategy swap and extract the full slippage budget per swap. Losses accumulate per deposit/withdraw and compound over time, transferring value from the client share pool to MEV.
- **No privileged access required.** Both attack paths are available to any external actor under normal market conditions. The DoS path requires only that the AMM trade at a discount; the sandwich path requires only that an MEV bot observe the public mempool.

## Recommended mitigation steps

The root cause is that `minOut` must be derived from the *AMM-fair* expected output, not from the vault's internal accumulator. Any of the following remediations is appropriate; the first is preferred because it requires no new infrastructure and is symmetric across deposit and withdraw.

### Option 1 (preferred): Anchor `minOut` to the AMM's own quoted output

Query the AMM for its expected output immediately before the swap and apply the slippage tolerance to that quote. For Curve, use `get_dy(i, j, dx)` (or the equivalent on the routed pool) so the quote reflects the live pool state including any recent skew:

```solidity
// In _withdrawInternal, replacing the vault-anchored minOut:
uint256 expectedOut = ammAdapter.getAmountOut(address(vault), address(underlyingToken), sharesToSell);
uint256 minOut = expectedOut * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
```

This requires extending `IAMMAdapter` with a `getAmountOut` (or `quote`) view function, and implementing it in `CurveAMMAdapter` via `IStableSwapNG.get_dy` / `IRouterNG.get_dy`. Apply the same change to all four swap sites (deposit at L276-L283, withdraw at L313-L328, totalWithdraw at L378-L390, withdrawFrom at L428-L442).

This eliminates both the DoS (the quote reflects the discount, so `minOut` is reachable) and most of the sandwich exposure (the slippage budget is now applied around the live mid rather than around a stale anchor). It does not eliminate intra-block sandwiching of the same block's AMM state, which is why Option 2 is recommended as a defence-in-depth on top of Option 1.

### Option 2: Cross-check against an external price oracle (defence in depth)

Integrate a Chainlink (or equivalent) USDe/USD or sUSDe/USD feed and require the AMM-quoted output to also be within tolerance of the oracle-implied output:

```solidity
uint256 oracleImplied = (sharesToSell * oraclePrice) / 1e18;
uint256 minOutOracle = oracleImplied * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
require(amountOut >= minOutOracle, "AMM price too far from oracle");
```

This bounds the per-swap value an MEV searcher can extract by the oracle staleness window (typically much tighter than what AMM-only `minOut` can express).

### Option 3: Treat the strategy as oracle-dependent and refuse to operate without one

If no oracle is configured for the underlying/vault pair, refuse to execute swaps. This is a stricter version of Option 2 — useful if the strategy is to be deployed against vault tokens where no liquid AMM quote source exists.

### Option 4 (fallback): Switch the anchor to the AMM's own recent observation

If the AMM exposes a recent TWAP/cumulative price, use it as the slippage anchor in place of `vault.convertToAssets`. This is strictly better than the current implementation, but weaker than Options 1-2 because it cannot react to a fast-moving discount within the TWAP window.

---

In all cases, the structural fix is the same: the slippage check must measure the swap against an *AMM-fair* reference, not against the vault's internal accumulator. The vault accumulator is the right reference for accounting (`totalBalanceOf`) and the wrong reference for slippage protection.

### Proof of Concept

A standalone Foundry test, `test/poc-M-02.t.sol`, demonstrates the withdraw-DoS failure mode end to end. The test reuses the same mock infrastructure (`MockERC20`, `MockERC4626Vault`, `MockAMMAdapter`) the project's own unit tests use, so it requires no fork.

### Test flow

1. Deploy `ERC4626MarketYieldStrategy` against a mock ERC4626 vault and mock AMM. Configure slippage tolerance to 100 bps (1%) — the same value used in the project's own unit tests.
2. Authorize the client and deposit 1,000 underlying at the healthy 1:1 AMM rate.
3. Simulate vault yield by minting underlying directly into the mock vault (`simulateYield(2_000_000e18)`), pushing the internal price-per-share above 1.
4. Drop the AMM rate `vault -> underlying` to `0.95e18` (a 5% discount). Confirm the AMM has ample underlying reserves so any revert can only come from the slippage check.
5. Call `withdraw(500e18)`. The strategy computes `minOut` from `vault.convertToAssets(sharesToSell)` (which round-trips back to ~500e18 minus 1%, i.e. ~495e18). The AMM only delivers `sharesToSell * 0.95` (~475e18). `minOut > amountOut`, so the AMM adapter reverts with `MockAMMAdapter: insufficient output amount`.
6. Repeat with a 1e18 withdrawal to demonstrate that the bug is independent of size: even a tiny withdrawal is bricked, because the round-trip math cancels the price-per-share factor and leaves `minOut` anchored to the requested underlying amount.
7. Assert that `principalOf(client)` is unchanged — the client is fully DoS'd from their position.

### Test source

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol";
import "../src/mocks/MockERC20.sol";
import "./mocks/MockERC4626Vault.sol";
import "./mocks/MockAMMAdapter.sol";

contract PoC_M02_SlippageAnchorBricksWithdrawals is Test {
    ERC4626MarketYieldStrategy strategy;
    MockERC20 underlyingToken;
    MockERC4626Vault erc4626Vault;
    MockAMMAdapter ammAdapter;

    address owner = address(0x1234);
    address client = address(0x5678);
    address pauser = address(0x9ABC);

    uint256 constant INITIAL_TOKEN_SUPPLY = 10_000_000e18;

    function setUp() public {
        underlyingToken = new MockERC20("Underlying", "UNDERLYING", 18);
        erc4626Vault = new MockERC4626Vault("Vault Shares", "vUNDERLYING", address(underlyingToken));
        ammAdapter = new MockAMMAdapter();

        vm.prank(owner);
        strategy = new ERC4626MarketYieldStrategy(
            owner, address(underlyingToken), address(erc4626Vault), address(ammAdapter)
        );

        // Initial 1:1 exchange rates (favorable, healthy market) for both swap directions
        ammAdapter.setExchangeRate(address(underlyingToken), address(erc4626Vault), 1e18);
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 1e18);

        underlyingToken.mint(client, INITIAL_TOKEN_SUPPLY);

        // Pre-fund the AMM with vault shares so deposit swaps can succeed.
        underlyingToken.mint(address(this), INITIAL_TOKEN_SUPPLY);
        underlyingToken.approve(address(erc4626Vault), INITIAL_TOKEN_SUPPLY);
        erc4626Vault.deposit(INITIAL_TOKEN_SUPPLY, address(ammAdapter));

        // Pre-fund the AMM with underlying reserves so withdraw swaps have tokens
        // to pay out. The discount is enforced by the AMM rate, not by reserve
        // shortage; we want the revert to come from the slippage check.
        underlyingToken.mint(address(ammAdapter), INITIAL_TOKEN_SUPPLY);

        vm.startPrank(owner);
        strategy.setClient(client, true);
        strategy.setPauser(pauser);
        strategy.setSlippageTolerance(100); // 100 bps = 1%
        vm.stopPrank();

        vm.prank(client);
        underlyingToken.approve(address(strategy), type(uint256).max);
    }

    function test_DepositSucceedsAtFavorableRate() public {
        uint256 depositAmount = 1000e18;

        vm.prank(client);
        strategy.deposit(address(underlyingToken), depositAmount, client);

        assertEq(strategy.principalOf(address(underlyingToken), client), depositAmount, "principal mismatch");
        assertGt(strategy.getTotalShares(), 0, "expected vault shares received");
    }

    function test_WithdrawRevertsWhenMarketPriceBelowInternalRate() public {
        // Step 1: client deposits 1000 underlying at the healthy 1:1 AMM rate
        uint256 depositAmount = 1_000e18;
        vm.prank(client);
        strategy.deposit(address(underlyingToken), depositAmount, client);

        assertEq(strategy.principalOf(address(underlyingToken), client), depositAmount, "deposit pre-condition");

        // Step 2: vault accrues real yield (internal share price increases)
        erc4626Vault.simulateYield(2_000_000e18);

        uint256 internalValue = strategy.totalBalanceOf(address(underlyingToken), client);
        assertGt(internalValue, depositAmount, "vault internal rate should have increased");

        // Step 3: AMM price for vault -> underlying drops to a 5% discount
        ammAdapter.setExchangeRate(address(erc4626Vault), address(underlyingToken), 0.95e18);

        // Sanity: AMM has plenty of reserves; revert must be from the slippage check.
        assertGt(
            underlyingToken.balanceOf(address(ammAdapter)),
            depositAmount * 10,
            "AMM should have ample underlying reserves; revert must be from slippage check"
        );

        // Step 4: client tries to withdraw - reverts with the AMM slippage error
        vm.expectRevert("MockAMMAdapter: insufficient output amount");
        vm.prank(client);
        strategy.withdraw(address(underlyingToken), 500e18, client);

        // Step 5: even a 1e18 withdrawal fails - the bug is size-independent
        vm.expectRevert("MockAMMAdapter: insufficient output amount");
        vm.prank(client);
        strategy.withdraw(address(underlyingToken), 1e18, client);

        // Step 6: principal is unchanged - funds are confirmed trapped
        assertEq(
            strategy.principalOf(address(underlyingToken), client),
            depositAmount,
            "principal must be unchanged - withdrawals are bricked"
        );
    }
}
```

### Math walkthrough

The strategy computes:

```
sharesToSell    = vault.convertToShares(500e18)              // < 500e18 because pricePerShare > 1
idealUnderlying = vault.convertToAssets(sharesToSell)        // ~= 500e18 (round-trip cancels pricePerShare)
minOut          = idealUnderlying * (10000 - 100) / 10000    // ~= 495e18
```

The AMM (set to a 5% discount on `vault -> underlying`) returns:

```
amountOut = sharesToSell * 0.95
          = (500e18 / pricePerShare) * pricePerShare * 0.95
          = 500e18 * 0.95
          = 475e18
```

`minOut` (~495e18) > `amountOut` (~475e18), so the swap reverts.

The cancellation of `pricePerShare` is the structural reason the bug is independent of how much yield has accrued: any AMM discount strictly greater than `slippageToleranceBps` bricks the withdraw, even if the vault price has not moved at all.

### Run instructions

From the project root:

```bash
forge test --match-contract PoC_M02_SlippageAnchorBricksWithdrawals -vvv
```

### Expected output

Both tests pass:

- `test_DepositSucceedsAtFavorableRate` — baseline showing the happy-path deposit at the 1:1 AMM rate works.
- `test_WithdrawRevertsWhenMarketPriceBelowInternalRate` — the smoking gun. Both the 500e18 and 1e18 withdrawals revert with `MockAMMAdapter: insufficient output amount`, and the final assertion confirms `principalOf(client) == 1_000e18` (i.e. the client is fully DoS'd from their position with no recovery path that does not require owner intervention).
