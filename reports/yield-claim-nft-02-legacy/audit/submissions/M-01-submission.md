<!--
C4 Submission Metadata
Title: [M-01] Default zero slippage on BalancerPooler enables sandwich attacks on every mint via 3-parameter mint() overload
Root Cause Link: src/dispatchers/BalancerPooler.sol:66
PoC File: M-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `BalancerPooler` dispatcher sets `minBptAmountOut` to `0` whenever `extraData` is empty. The 3-parameter `mint(address, uint256, address)` overload in `NFTMinter` hardcodes empty bytes as `extraData`, making it structurally impossible for callers of this simpler interface to specify slippage protection. Every mint routed through the 3-parameter overload to a `BalancerPooler` dispatcher executes the Balancer `addLiquidity` call with zero slippage protection, enabling sandwich attacks on every such transaction.

### Vulnerability details

There are two contracts involved in this issue. The root cause is in `BalancerPooler.dispatch()`, which defaults `minBptAmountOut` to zero when no `extraData` is provided:

`src/dispatchers/BalancerPooler.sol:66`
```solidity
function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {
    uint256 minBptAmountOut = extraData.length > 0 ? abi.decode(extraData, (uint256)) : 0;
    bytes memory data = abi.encode(amount, minBptAmountOut);
    IBalancerVault(_vault).unlock(data);
}
```

The zero `minBptAmountOut` propagates directly into the `AddLiquidityParams` struct passed to the Balancer vault:

`src/dispatchers/BalancerPooler.sol:96-103`
```solidity
AddLiquidityParams memory params = AddLiquidityParams({
    pool: _pool,
    to: address(this),
    maxAmountsIn: maxAmountsIn,
    minBptAmountOut: minBptAmountOut,  // 0 when extraData is empty
    kind: AddLiquidityKind.UNBALANCED,
    userData: ""
});
```

The structural enabler is the 3-parameter `mint()` in `NFTMinter`, which always passes empty bytes:

`src/NFTMinter.sol:116-118`
```solidity
function mint(address token, uint256 index, address recipient) external returns (bool) {
    return _executeMint(token, index, recipient, "");
}
```

While a 4-parameter `mint()` overload exists that accepts user-provided `extraData`, the simpler 3-parameter version is the natural default for integrating contracts and end-user interfaces that are unaware of the slippage parameter. There is no documentation, revert, or warning indicating that this overload is unsafe when paired with a `BalancerPooler` dispatcher.

**Attack path:**

1. User (or integrating contract) calls `mint(token, index, recipient)` -- the 3-parameter overload.
2. `NFTMinter._executeMint()` forwards empty `extraData` (`""`) to the dispatcher.
3. `BalancerPooler.dispatch()` evaluates `extraData.length > 0` as `false`, setting `minBptAmountOut = 0`.
4. `unlockCallback()` constructs `AddLiquidityParams` with `minBptAmountOut = 0` and calls `vault.addLiquidity()`.
5. An MEV bot front-runs the transaction to manipulate the Balancer pool price, the victim's `addLiquidity` executes at the manipulated price with no minimum output check, and the bot back-runs to extract the price difference as profit.

### Impact

Every mint routed through the 3-parameter `mint()` overload to a `BalancerPooler` dispatcher is vulnerable to sandwich attacks. The consequences are:

- **Value leak per transaction**: The protocol receives fewer BPT tokens than the fair market value of the deposited liquidity. The difference is extracted by MEV bots.
- **Permanent dilution**: Since BPT represents the protocol's accumulated liquidity position, each sandwich attack permanently dilutes the value backing claim NFTs.
- **No special privileges required**: Any MEV bot monitoring the mempool can exploit this. The attack is permissionless, repeatable, and profitable on every qualifying transaction.
- **Likely high frequency**: The 3-parameter `mint()` is the simpler, more discoverable function signature. Frontend integrations and contracts that are unaware of the `extraData` requirement will default to it, meaning a significant share of mints will be unprotected.

### Proof of Concept

The PoC is located at `workspace/yield-claim-nft/test/poc-M-01.t.sol`.

The test (`test_poc_M01_threeParamMint_zeroSlippage`) deploys inlined, simplified versions of `BalancerPooler` and `NFTMinter` preserving the exact vulnerable logic, along with a mock Balancer vault that records the `AddLiquidityParams` passed to `addLiquidity()`. It demonstrates:

1. **3-parameter mint results in zero slippage**: Calling `mint(token, index, recipient)` produces `minBptAmountOut = 0` in the recorded vault parameters, confirming zero slippage protection.
2. **4-parameter mint correctly forwards slippage**: Calling `mint(token, index, recipient, abi.encode(95e18))` produces `minBptAmountOut = 95e18`, confirming the 4-parameter path works as intended.
3. **Structural gap**: The test asserts that the 3-parameter path has strictly less protection than the 4-parameter path, proving the issue is a design gap rather than user error.

## Recommended mitigation steps

The recommended approach depends on the protocol's design intent. Three options are presented in order of preference:

**Option 1 (Recommended): Compute a reasonable minimum on-chain when extraData is empty**

Query the Balancer pool's current state to derive a minimum BPT output with a configurable tolerance (e.g., 1-2% below spot):

```solidity
function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {
    uint256 minBptAmountOut;
    if (extraData.length > 0) {
        minBptAmountOut = abi.decode(extraData, (uint256));
    } else {
        // Query pool for expected BPT output and apply tolerance
        minBptAmountOut = _computeMinBptOut(amount) * (10000 - slippageToleranceBps) / 10000;
    }
    bytes memory data = abi.encode(amount, minBptAmountOut);
    IBalancerVault(_vault).unlock(data);
}
```

**Option 2: Add an owner-configurable minimum slippage floor**

Introduce a state variable that sets a floor for `minBptAmountOut` when `extraData` is not provided:

```solidity
uint256 public defaultMinBptBps = 9800; // 98% of input as default floor

function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {
    uint256 minBptAmountOut;
    if (extraData.length > 0) {
        minBptAmountOut = abi.decode(extraData, (uint256));
    } else {
        minBptAmountOut = amount * defaultMinBptBps / 10000;
    }
    bytes memory data = abi.encode(amount, minBptAmountOut);
    IBalancerVault(_vault).unlock(data);
}
```

**Option 3: Revert when extraData is empty to force explicit slippage**

This is the simplest fix but reduces usability:

```solidity
function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {
    require(extraData.length > 0, "BalancerPooler: slippage parameter required");
    uint256 minBptAmountOut = abi.decode(extraData, (uint256));
    bytes memory data = abi.encode(amount, minBptAmountOut);
    IBalancerVault(_vault).unlock(data);
}
```

If Option 3 is chosen, the 3-parameter `mint()` in `NFTMinter` should either be removed or updated to revert with a clear message when the target dispatcher is a `BalancerPooler`, so callers receive actionable feedback rather than a low-level revert from the dispatcher.
