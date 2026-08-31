<!--
C4 Submission Metadata
Title: [H-02] Deposit principal in underlying units lets later depositors dilute earlier discount buyers
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L273-L291
PoC File: H-02-poc.t.sol
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy._depositInternal` records each client's principal in the units of the underlying asset (the depositor's input `amount`), but the strategy actually owns vault shares purchased through an AMM at a market rate that fluctuates independently of the vault's internal share price. Because `totalBalanceOf` distributes the strategy's total vault value pro-rata by `principal / totalDeposited`, two depositors who put in the same amount of underlying are credited with the same share of the pool, even when one of them actually contributed substantially more vault shares than the other. A late depositor coming in at a fair AMM rate can therefore silently dilute an earlier depositor who came in at a discounted AMM rate, transferring value one-to-one from the earlier depositor to the later depositor.

### Vulnerability details

The bug lives in `_depositInternal` at [`ERC4626MarketYieldStrategy.sol#L273-L291`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L273-L291):

```solidity
// Transfer underlying token from depositor to this contract
underlyingToken.safeTransferFrom(depositor, address(this), amount);

// Calculate ideal shares and minimum acceptable output
uint256 idealShares = vault.convertToShares(amount);
uint256 minOut = idealShares * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

// Approve AMM adapter to spend underlying tokens
underlyingToken.safeIncreaseAllowance(address(ammAdapter), amount);

// Swap underlying -> vault tokens via AMM
uint256 sharesReceived = ammAdapter.swap(address(underlyingToken), address(vault), amount, minOut);
require(sharesReceived > 0, "ERC4626MarketYieldStrategy: no shares received");

// Update principal tracking
clientBalances[token][recipient] += amount;
totalDeposited[token] += amount;
```

`sharesReceived` (the actual number of vault shares the strategy now owns on behalf of `recipient`) is computed by the AMM at a market rate, but it is intentionally discarded for accounting purposes. Both `clientBalances[token][recipient]` and `totalDeposited[token]` are incremented by the requested `amount` of underlying instead of by `sharesReceived`.

The pro-rata yield distribution then runs through `totalBalanceOf` at [`ERC4626MarketYieldStrategy.sol#L138-L152`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L138-L152):

```solidity
function totalBalanceOf(address token, address account) external view override returns (uint256) {
    require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

    uint256 principal = clientBalances[token][account];
    if (principal == 0 || totalDeposited[token] == 0) {
        return 0;
    }

    // Calculate proportional share of total vault value
    uint256 totalShares = vault.balanceOf(address(this));
    uint256 totalValue = vault.convertToAssets(totalShares);

    // User's proportion: (userPrincipal / totalPrincipal) * totalValue
    return (totalValue * principal) / totalDeposited[token];
}
```

The numerator/denominator pair (`principal`, `totalDeposited`) is denominated in underlying units, while `totalValue` reflects the share-denominated reality of the vault holdings. As soon as two depositors enter the strategy at different AMM rates, this ratio no longer represents how many shares each depositor actually contributed to `vault.balanceOf(address(this))`, and `totalBalanceOf` redistributes value between them.

#### Concrete attack / dilution path

The PoC at `test/poc-H-02.t.sol` (`test_LateFairRateDepositorDilutesEarlyDiscountDepositor`) demonstrates the issue end-to-end against the real `ERC4626MarketYieldStrategy` plus mock vault and mock AMM adapter:

1. T0 - Vault shares trade at a discount on the AMM. The AMM rate is set so `1` underlying buys `1.25` vault shares; the vault's internal price remains `1:1`.
2. Alice deposits `1000` underlying through the strategy. The AMM swap delivers `1250` vault shares to the strategy. After the deposit:
   - `clientBalances[underlying][alice] = 1000`
   - `totalDeposited[underlying] = 1000`
   - `vault.balanceOf(strategy) = 1250`
3. T1 - The AMM normalizes back to a fair `1:1` rate.
4. Bob deposits `1000` underlying through the strategy. The AMM swap delivers `1000` vault shares. After the deposit:
   - `clientBalances[underlying][bob] = 1000`
   - `totalDeposited[underlying] = 2000`
   - `vault.balanceOf(strategy) = 2250`
5. The strategy now holds `2250` vault shares whose true value at the fair price is `2250` underlying. Pro-rata via `totalBalanceOf` gives:
   - `aliceTrackedBalance = 2250 * 1000 / 2000 = 1125`
   - `bobTrackedBalance   = 2250 * 1000 / 2000 = 1125`
6. The actual share contributions are unequal:
   - Alice's `1250` shares are worth `1250` underlying at the fair price.
   - Bob's `1000` shares are worth `1000` underlying at the fair price.
7. The PoC then asserts the zero-sum dilution:
   - `aliceTrackedBalance < aliceTrueValue`, `aliceLoss = 125 underlying`.
   - `bobTrackedBalance > bobTrueValue`, `bobGain = 125 underlying`.
   - `aliceLoss == bobGain` (exact zero-sum transfer).

The dilution magnitude scales linearly with both the deposit size and the discount: a `5%` AMM dislocation between two equal-sized deposits transfers `~2.5%` of one depositor's principal to the other; large institutional deposits during routine sUSDe/USDe Curve dislocations can move thousands of dollars per event.

#### Why this is exploitable in production

The attacker does not need privileged access or any extraordinary preconditions:

- Any authorized client can call `deposit(...)` for any `recipient`. A client serving multiple end-users (or a strategy aggregator) routinely makes deposits at whatever AMM rate is currently quoted.
- Curve sUSDe/USDe (the documented integration target via `AMMRoutes.json`) frequently dislocates by tens of basis points around redemption windows, incentive epochs, and large flow events. Each dislocation, followed by a normalizing deposit, reshuffles principal between existing holders.
- Because the strategy owner sets `slippageToleranceBps` for the strategy as a whole, even a `5000` bps tolerance (the value used in the PoC) lets the strategy accept the discount swap without reverting; and even a tight tolerance does not protect against the bug, because the AMM is willing to fill at the discount.
- An MEV searcher who watches the mempool for an AMM dislocation can deposit a large fair-rate position immediately afterwards (or sandwich the dislocation correction) to capture value from any earlier discount-rate depositor still in the pool. Since the dilution is path-dependent and zero-sum, the attacker's profit comes directly out of the earlier client's principal.

Critically, the value transfer is **silent**: there is no event, no revert, and no on-chain anomaly. Off-chain accounting that trusts `principalOf` and `totalBalanceOf` (the protocol's own external surface) will report numbers that look normal but no longer correspond to who actually owns what fraction of the vault shares.

#### Relationship to H-01

H-01 and H-02 share the same root cause family: the strategy tracks principal in underlying units while it actually owns shares purchased at a variable AMM rate. They are nevertheless distinct findings worth submitting separately:

- **H-01 attacks the withdraw side.** It is a bank-run style exploit in which the order of withdrawals (combined with the requested-amount-not-received-amount decrement at [`ERC4626MarketYieldStrategy.sol#L335-L336`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L335-L336)) lets the first withdrawer drain disproportionate value, leaving later withdrawers with less than their fair share.
- **H-02 attacks the deposit side.** No withdrawal is required; the dilution happens the moment a second deposit enters the pool at a different AMM rate. The attacker is a *depositor*, not a withdrawer, and their unfair gain materializes silently in `totalBalanceOf` rather than at withdraw time.

The two vectors compose: an attacker can first dilute an existing client via H-03 and then realize the stolen value via H-02 (or via any code path that pays out using `totalBalanceOf`, e.g. `_withdrawFrom`'s surplus check at [`ERC4626MarketYieldStrategy.sol#L411-L451`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L411-L451)). Fixing either finding in isolation does not fix the other; the deposit-side bug must be fixed at the moment principal is recorded.

### Impact

- **Direct loss of client funds.** Any client who deposits through `ERC4626MarketYieldStrategy` while the AMM is offering vault shares at a discount has their principal silently redistributed to subsequent depositors who enter at fairer rates. The transfer is one-for-one (zero-sum) and happens with no warning, event, or revert.
- **Broken pro-rata yield distribution.** The protocol's documented invariant - that `totalBalanceOf` returns each client's true proportional stake in the strategy's vault holdings - is false whenever two clients have entered at different AMM rates. Every downstream consumer (`_withdrawFrom`'s surplus check, off-chain accounting, integrators querying the IYieldStrategy interface) inherits the corruption.
- **Trivially exploitable by routine market activity.** The attacker needs no privileged role, no flash loans, and no special preconditions. Normal AMM rate fluctuations on Curve sUSDe/USDe (the documented production integration) trigger the bug on every deposit; an attentive MEV searcher can extract value from any earlier discount-rate position by depositing immediately afterwards.
- **Composes with H-01 to amplify losses.** The dilution recorded at deposit time persists in storage and can later be realized via the bank-run withdraw path, so H-01 and H-02 combined enable an attacker to both create and extract the stolen value.

## Recommended mitigation steps

The root cause is a units mismatch: the strategy must account in the same units it actually owns. There are two equivalent fixes; the first is preferred because it eliminates the entire class of unit-mismatch bugs.

### Preferred fix - track shares per client, not underlying

Replace the underlying-denominated principal map with a share-denominated one, and compute principal-vs-yield by comparing the current asset value of a client's recorded shares to the underlying they originally put in.

```solidity
// Replace:
//   mapping(address => mapping(address => uint256)) private clientBalances;  // underlying units
//   mapping(address => uint256) private totalDeposited;                      // underlying units
//
// With:
mapping(address => mapping(address => uint256)) private clientShares;     // vault-share units
mapping(address => mapping(address => uint256)) private clientCostBasis;  // underlying units, for principal-vs-yield
mapping(address => uint256) private totalShares;                          // vault-share units (mirrors vault.balanceOf for accounting)

function _depositInternal(address token, uint256 amount, address recipient, address depositor) internal {
    // ... existing checks ...

    underlyingToken.safeTransferFrom(depositor, address(this), amount);

    uint256 idealShares = vault.convertToShares(amount);
    uint256 minOut = idealShares * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
    underlyingToken.safeIncreaseAllowance(address(ammAdapter), amount);

    uint256 sharesReceived = ammAdapter.swap(address(underlyingToken), address(vault), amount, minOut);
    require(sharesReceived > 0, "ERC4626MarketYieldStrategy: no shares received");

    // Account in the units we actually own
    clientShares[token][recipient]    += sharesReceived;
    clientCostBasis[token][recipient] += amount;          // for principalOf reporting
    totalShares[token]                += sharesReceived;

    emit Deposited(token, depositor, recipient, amount, sharesReceived);
}

function totalBalanceOf(address token, address account) external view override returns (uint256) {
    require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
    uint256 shares = clientShares[token][account];
    if (shares == 0) return 0;
    return vault.convertToAssets(shares);
}

function principalOf(address token, address account) external view override returns (uint256) {
    require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
    return clientCostBasis[token][account];
}
```

With this change, two depositors who put in the same underlying at different AMM rates own different numbers of shares, `totalBalanceOf` returns the true asset value of the shares each one actually contributed, and there is no zero-sum redistribution between them. `principalOf` continues to report each client's original underlying cost basis for the surplus / yield-vs-principal logic in `_withdrawFrom`.

### Alternative fix - keep underlying accounting but normalize at deposit time

If a structural rewrite is undesirable, the deposit can be re-priced into a synthetic "principal-equivalent" so the pro-rata math stays internally consistent. The idea is that the principal credited to the depositor must be proportional to the shares they actually contributed, normalized by the current share-per-principal ratio of the pool:

```solidity
function _depositInternal(address token, uint256 amount, address recipient, address depositor) internal {
    // ... existing checks and token pull ...

    uint256 idealShares = vault.convertToShares(amount);
    uint256 minOut = idealShares * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
    underlyingToken.safeIncreaseAllowance(address(ammAdapter), amount);

    uint256 sharesReceived = ammAdapter.swap(address(underlyingToken), address(vault), amount, minOut);
    require(sharesReceived > 0, "ERC4626MarketYieldStrategy: no shares received");

    // Pre-deposit pool state
    uint256 totalSharesBefore = vault.balanceOf(address(this)) - sharesReceived;
    uint256 totalPrincipal    = totalDeposited[token];

    uint256 creditedPrincipal;
    if (totalSharesBefore == 0 || totalPrincipal == 0) {
        // Bootstrap deposit: principal == requested amount
        creditedPrincipal = amount;
    } else {
        // Mint principal proportional to shares contributed, against the existing pool ratio
        creditedPrincipal = (sharesReceived * totalPrincipal) / totalSharesBefore;
    }

    clientBalances[token][recipient] += creditedPrincipal;
    totalDeposited[token]            += creditedPrincipal;

    emit Deposited(token, depositor, recipient, amount, sharesReceived);
}
```

This preserves the existing storage layout and the meaning of `totalBalanceOf`, at the cost of `principalOf` no longer matching the underlying amount the user actually deposited. Because `_withdrawFrom`'s surplus check at [`ERC4626MarketYieldStrategy.sol#L411-L451`](https://github.com/Behodler/reflax-yield-vault/blob/f328d52/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L411-L451) compares `totalBalance` against `principal`, the credited-principal path also requires care so that "principal" and "yield" remain meaningful for that check. For these reasons we recommend the share-tracking fix above.

### Defense-in-depth recommendations

Independently of the chosen fix:

- Tighten `slippageToleranceBps` to a value that cannot accommodate large AMM dislocations (the `5000` bps used in the PoC is realistic for protocol mis-configuration but is itself a hazard).
- Add a sanity check inside `_depositInternal` that compares `sharesReceived` to `vault.convertToShares(amount)` and reverts if the deviation exceeds a per-deposit threshold; this caps the per-event dilution even if the underlying accounting bug were re-introduced.
- Add tests that deposit through the strategy at two different AMM rates and assert that `totalBalanceOf` returns each depositor's true `convertToAssets(sharesContributed)` value.
