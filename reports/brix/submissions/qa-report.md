# QA Report for Brix Money

## Summary
| Severity | Count |
|----------|-------|
| Low Risk | 2 |
| Informational | 3 |
| **Total** | **5** |

---

## Low Risk Findings

### [L-01] Unbounded Loop in Blacklist/Whitelist Functions

**Locations**:
- `iTry.sol#L73-L78` ([addBlacklistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/iTry.sol#L73-L78))
- `iTry.sol#L83-L87` ([removeBlacklistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/iTry.sol#L83-L87))
- `iTry.sol#L92-L96` ([addWhitelistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/iTry.sol#L92-L96))
- `iTry.sol#L101-L105` ([removeWhitelistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/iTry.sol#L101-L105))
- `iTryTokenOFT.sol#L70-L75` ([addBlacklistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/crosschain/iTryTokenOFT.sol#L70-L75))
- `iTryTokenOFT.sol#L80-L84` ([removeBlacklistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/crosschain/iTryTokenOFT.sol#L80-L84))
- `iTryTokenOFT.sol#L89-L93` ([addWhitelistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/crosschain/iTryTokenOFT.sol#L89-L93))
- `iTryTokenOFT.sol#L98-L102` ([removeWhitelistAddress](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/iTRY/crosschain/iTryTokenOFT.sol#L98-L102))

**Description**: The blacklist and whitelist management functions iterate over user-provided arrays with no size limit. While these functions are restricted to privileged roles (BLACKLIST_MANAGER_ROLE, WHITELIST_MANAGER_ROLE, owner), extremely large arrays could potentially cause the transaction to run out of gas, preventing critical access control operations.

The vulnerable code pattern from `iTry.sol`:

```solidity
function addBlacklistAddress(address[] calldata users) external onlyRole(BLACKLIST_MANAGER_ROLE) {
    for (uint8 i = 0; i < users.length; i++) {
        if (hasRole(WHITELISTED_ROLE, users[i])) _revokeRole(WHITELISTED_ROLE, users[i]);
        _grantRole(BLACKLISTED_ROLE, users[i]);
    }
}
```

Note that the loop uses `uint8` as the counter, which limits the maximum array size to 256 addresses. However, this still allows for gas-intensive operations and may fail silently if more than 256 addresses are provided.

**Impact**:
- Large arrays could cause gas exhaustion, preventing role management operations
- Using `uint8` as counter causes silent wraparound if array length exceeds 255
- Admin operations could become temporarily unavailable during periods of high network congestion

**Recommendation**:

1. Implement batch size limits to prevent gas exhaustion:

```solidity
uint256 public constant MAX_BATCH_SIZE = 100;

function addBlacklistAddress(address[] calldata users) external onlyRole(BLACKLIST_MANAGER_ROLE) {
    require(users.length <= MAX_BATCH_SIZE, "Batch size too large");
    for (uint256 i = 0; i < users.length; i++) {
        if (hasRole(WHITELISTED_ROLE, users[i])) _revokeRole(WHITELISTED_ROLE, users[i]);
        _grantRole(BLACKLISTED_ROLE, users[i]);
    }
}
```

2. Change loop counter from `uint8` to `uint256` to prevent wraparound issues:

```solidity
for (uint256 i = 0; i < users.length; i++) {
    // ... operations
}
```

3. Consider implementing pagination for very large batches or provide helper functions for emergency single-address operations.

---

### [L-02] Unsafe Downcasting in UnstakeMessenger

**Location**: `UnstakeMessenger.sol#L127` ([unstake function](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/token/wiTRY/crosschain/UnstakeMessenger.sol#L127))

**Description**: The `unstake` function performs an unsafe downcast from `uint256` to `uint128` when converting `returnTripAllocation` to the format required by LayerZero's `addExecutorLzReceiveOption`. While the code includes a comment claiming this cast is safe, there is no runtime validation to enforce this assumption.

The vulnerable code:

```solidity
// Build options WITH native value forwarding for return trip execution
// casting to 'uint128' is safe because returnTripAllocation value will be less than 2^128
// forge-lint: disable-next-line(unsafe-typecast)
bytes memory callerOptions =
    OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_RECEIVE_GAS, uint128(returnTripAllocation));
```

**Impact**:
- If `returnTripAllocation` exceeds `type(uint128).max` (2^128 - 1 = ~3.4e38 wei = ~3.4e20 ETH), the value will silently truncate
- The truncated value would be insufficient for the return trip, causing the cross-chain unstaking operation to fail on the hub chain
- While unlikely given current ETH prices, this represents a potential edge case that could brick user funds in a cross-chain operation

**Recommendation**: Add an explicit bounds check before the cast to prevent silent truncation:

```solidity
function unstake(uint256 returnTripAllocation) external payable nonReentrant returns (bytes32 guid) {
    // Validate hub peer configured
    bytes32 hubPeer = peers[hubEid];
    if (hubPeer == bytes32(0)) revert HubNotConfigured();

    // Validate returnTripAllocation
    if (returnTripAllocation == 0) revert InvalidReturnTripAllocation();
    require(returnTripAllocation <= type(uint128).max, "Return trip allocation too large");

    // Build return trip options (valid TYPE_3 header)
    bytes memory extraOptions = OptionsBuilder.newOptions();

    // Encode UnstakeMessage with msg.sender as user (prevents spoofing)
    UnstakeMessage memory message = UnstakeMessage({user: msg.sender, extraOptions: extraOptions});
    bytes memory payload = abi.encode(MSG_TYPE_UNSTAKE, message);

    // Build options WITH native value forwarding for return trip execution
    // Safe cast confirmed by bounds check above
    bytes memory callerOptions =
        OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_RECEIVE_GAS, uint128(returnTripAllocation));
    // ... rest of function
}
```

---

## Informational Findings

### [I-01] No Minimum Transaction Amount Enforcement

**Locations**:
- `iTryIssuer.sol#L265-L307` ([mintFor function](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L265-L307))
- `iTryIssuer.sol#L318-L367` ([redeemFor function](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L318-L367))

**Description**: The minting and redemption functions allow arbitrarily small transaction amounts. When combined with fee calculations that use integer division, very small amounts could result in:

1. Zero fee collection on tiny transactions (fee rounds down to zero)
2. Dust accumulation that provides no economic benefit
3. Potential griefing through numerous tiny transactions that consume block space

While the `minAmountOut` parameter provides some slippage protection, it does not enforce minimum transaction sizes.

**Recommendation**: Consider implementing minimum transaction thresholds:

```solidity
uint256 public constant MIN_MINT_AMOUNT = 1e18; // 1 iTRY minimum
uint256 public constant MIN_REDEEM_AMOUNT = 1e18; // 1 iTRY minimum

function mintFor(address recipient, uint256 dlfAmount, uint256 minAmountOut)
    public
    onlyRole(_WHITELISTED_USER_ROLE)
    nonReentrant
    returns (uint256 iTRYAmount)
{
    require(dlfAmount >= MIN_MINT_AMOUNT, "Amount below minimum");
    // ... rest of function
}
```

This prevents dust transactions while maintaining protocol efficiency.

---

### [I-02] Oracle Single Point of Failure Without Fallback

**Location**: `iTryIssuer.sol#L65` ([oracle state variable](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L65))

**Description**: The protocol relies on a single oracle (`IOracle public oracle`) for all NAV price conversions during minting and redemption operations. There is no fallback oracle or circuit breaker mechanism if the primary oracle:

1. Becomes unavailable
2. Returns stale prices
3. Returns manipulated prices
4. Experiences temporary outages

While this is a design decision that may align with the protocol's trust model, it represents a centralization risk where oracle failure completely halts minting and redemption operations.

**Observation**: The oracle is upgradeable via `setOracle()` (admin-only), which provides some recovery mechanism, but requires admin intervention and doesn't help with short-term outages.

**Recommendation**: Consider implementing:

1. A fallback oracle that can be queried if the primary oracle fails
2. Staleness checks on oracle prices before accepting them
3. A circuit breaker that pauses operations if oracle prices deviate beyond reasonable bounds
4. Grace period during which the last known good price can be used

Example pattern:

```solidity
function getPrice() internal view returns (uint256 price, bool isStale) {
    try oracle.getPrice() returns (uint256 primaryPrice, uint256 timestamp) {
        if (block.timestamp - timestamp > MAX_STALENESS) {
            // Try fallback oracle
            if (address(fallbackOracle) != address(0)) {
                return fallbackOracle.getPrice();
            }
            return (primaryPrice, true); // Return stale price with flag
        }
        return (primaryPrice, false);
    } catch {
        // Primary oracle failed, try fallback
        if (address(fallbackOracle) != address(0)) {
            return fallbackOracle.getPrice();
        }
        revert("Oracle unavailable");
    }
}
```

---

### [I-03] Missing Deadline Parameters in Time-Sensitive Operations

**Locations**:
- `iTryIssuer.sol#L265` ([mintITRY](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L265))
- `iTryIssuer.sol#L270` ([mintFor](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L270))
- `iTryIssuer.sol#L313` ([redeemITRY](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L313))
- `iTryIssuer.sol#L318` ([redeemFor](https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/iTryIssuer.sol#L318))

**Description**: The minting and redemption functions rely on oracle prices and have `minAmountOut` slippage protection, but lack a `deadline` parameter. This means:

1. Transactions could be held in the mempool for extended periods
2. Oracle prices could change significantly between signing and execution
3. Validators could strategically delay transactions to extract MEV
4. Users have no way to automatically cancel stale transactions

While `minAmountOut` provides slippage protection, it doesn't protect against time-based price movements or stuck transactions.

**Current function signatures**:

```solidity
function mintFor(address recipient, uint256 dlfAmount, uint256 minAmountOut)
    public
    onlyRole(_WHITELISTED_USER_ROLE)
    nonReentrant
    returns (uint256 iTRYAmount)

function redeemFor(address recipient, uint256 iTRYAmount, uint256 minAmountOut)
    public
    onlyRole(_WHITELISTED_USER_ROLE)
    nonReentrant
    returns (bool fromBuffer)
```

**Recommendation**: Add a `deadline` parameter following the pattern used by Uniswap and other DeFi protocols:

```solidity
function mintFor(
    address recipient,
    uint256 dlfAmount,
    uint256 minAmountOut,
    uint256 deadline
)
    public
    onlyRole(_WHITELISTED_USER_ROLE)
    nonReentrant
    returns (uint256 iTRYAmount)
{
    require(block.timestamp <= deadline, "Transaction expired");
    // ... rest of function
}

function redeemFor(
    address recipient,
    uint256 iTRYAmount,
    uint256 minAmountOut,
    uint256 deadline
)
    public
    onlyRole(_WHITELISTED_USER_ROLE)
    nonReentrant
    returns (bool fromBuffer)
{
    require(block.timestamp <= deadline, "Transaction expired");
    // ... rest of function
}
```

This allows users to specify the maximum time window for their transaction to be valid, preventing execution of stale transactions with outdated oracle prices.

---
