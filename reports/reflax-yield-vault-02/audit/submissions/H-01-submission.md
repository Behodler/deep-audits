<!--
C4 Submission Metadata
Title: [H-01] Missing Access Control on collectYield() Allows Anyone to Steal Accumulated Fees
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L202-L233
PoC File: H-01-poc.t.sol
-->

## Finding description and impact

### Summary

The `collectYield()` function in `UniV4StableYieldStrategy.sol` lacks access control, allowing any external address to call it and receive all accumulated Uniswap V4 pool trading fees. This enables complete theft of protocol yield by unauthorized parties.

### Vulnerability details

The vulnerable function at [UniV4StableYieldStrategy.sol#L202-L233](https://github.com/Behodler/reflax-yield-vault/blob/main/src/concreteYieldStrategies/UniV4StableYieldStrategy.sol#L202-L233):

```solidity
function collectYield() external nonReentrant whenNotPaused returns (uint256 totalYieldInDepositToken) {
    (uint256 fees0, uint256 fees1) = _collectFees();

    // Determine which token is which based on pool key ordering
    uint256 depositTokenFees;
    uint256 pairedTokenFees;

    if (address(depositToken) == poolKey.currency0) {
        depositTokenFees = fees0;
        pairedTokenFees = fees1;
    } else {
        depositTokenFees = fees1;
        pairedTokenFees = fees0;
    }

    // Swap paired token fees to deposit token
    uint256 swappedAmount = 0;
    if (pairedTokenFees > 0) {
        swappedAmount = _swapWithSlippageCheck(pairedToken, depositToken, pairedTokenFees);
    }

    totalYieldInDepositToken = depositTokenFees + swappedAmount;

    // Transfer yield to caller
    if (totalYieldInDepositToken > 0) {
        depositToken.safeTransfer(msg.sender, totalYieldInDepositToken);  // <-- NO ACCESS CONTROL
    }

    emit YieldCollected(msg.sender, depositTokenFees, pairedTokenFees);

    return totalYieldInDepositToken;
}
```

The function only uses `nonReentrant` and `whenNotPaused` modifiers. In contrast, other state-changing functions in the same contract enforce strict access control:

| Function | Access Control |
|----------|----------------|
| `deposit()` | `onlyAuthorizedClient` |
| `migrate()` | `onlyOwner` |
| `setSlippageTolerance()` | `onlyOwner` |
| `setTolerableLoss()` | `onlyOwner` |
| `collectYield()` | **NONE** |

The base contract `AYieldStrategy.sol` defines multiple access control modifiers that are available but not applied:
- `onlyOwner` (line 278)
- `onlyAuthorizedClient` (line 121)
- `onlyAuthorizedWithdrawer` (line 130)

### Attack scenario

1. Protocol deposits user funds into the V4 stable pool via `deposit()`
2. Over time, the pool accumulates trading fees from swap activity
3. An attacker (any EOA or contract) monitors the pool for accumulated fees
4. Attacker calls `collectYield()` with no special permissions
5. The function collects fees from the PoolManager and transfers them directly to `msg.sender` (the attacker)
6. Attacker repeats this attack whenever new fees accumulate, or uses MEV to front-run legitimate collection attempts

### Impact

**Severity: High**

- **Complete loss of yield revenue**: All trading fees accumulated by the protocol can be stolen by any external address
- **Ongoing attack vector**: Attackers can continuously monitor and drain fees as they accumulate
- **MEV exploitation**: Bots can front-run any legitimate `collectYield()` transactions
- **No recovery mechanism**: Once fees are transferred to the attacker, they cannot be reclaimed
- **Protocol insolvency risk**: If the yield was expected to cover operational costs or be distributed to stakeholders, the protocol's economic model is broken

For a V4 stable pool handling significant trading volume, accumulated fees could reach substantial amounts. With a 0.05% fee tier and $10M daily volume, daily fees would be approximately $5,000. An attacker could drain this continuously.

## Recommended mitigation steps

Add the `onlyOwner` or `onlyAuthorizedWithdrawer` modifier to the `collectYield()` function:

```solidity
function collectYield() external onlyOwner nonReentrant whenNotPaused returns (uint256 totalYieldInDepositToken) {
    // ... existing implementation
}
```

Alternatively, if broader access is intended (e.g., for authorized yield aggregators), use the existing `onlyAuthorizedWithdrawer` modifier:

```solidity
function collectYield() external onlyAuthorizedWithdrawer nonReentrant whenNotPaused returns (uint256 totalYieldInDepositToken) {
    // ... existing implementation
}
```

If the yield should be sent to a specific address rather than the caller, modify the function to use a configurable recipient:

```solidity
address public yieldRecipient;

function collectYield() external onlyOwner nonReentrant whenNotPaused returns (uint256 totalYieldInDepositToken) {
    // ... existing fee collection logic ...

    if (totalYieldInDepositToken > 0) {
        depositToken.safeTransfer(yieldRecipient, totalYieldInDepositToken);  // Send to configured recipient
    }
    // ...
}
```
