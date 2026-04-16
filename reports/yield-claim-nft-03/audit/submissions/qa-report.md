# QA Report for Yield Claim NFT V2

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| **Total** | **5** |

---

## Low Risk Findings

### [L-01] NFTMigrator lacks reentrancy guard on `migrate()`

**Location**: [NFTMigrator.sol#L62-L76](src/V2/NFTMigrator.sol#L62-L76)

**Description**: The `migrate()` function makes multiple cross-contract calls in nested loops -- `v1.burn()` and `v2.mintFor()` for each V1 index. Each `v2.mintFor()` triggers `ERC1155._mint`, which invokes `onERC1155Received` on the caller. A contract-based caller can re-enter `migrate()` from within this callback. While analysis shows the current code ordering prevents exploitation (V1 tokens are burned before V2 minting per-index, so re-entering finds zero balances for already-processed indexes), the safety guarantee relies on fragile execution ordering rather than an explicit guard.

**Impact**: Defense-in-depth concern. The function is not currently exploitable, but any future refactoring that alters the burn-then-mint ordering within the loop could introduce a reentrancy vulnerability without warning.

**Recommendation**: Apply `nonReentrant` from OpenZeppelin's `ReentrancyGuard` to `migrate()`:

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMigrator is Ownable, ReentrancyGuard {
    // ...
    function migrate() external nonReentrant {
        // existing logic
    }
}
```

---

### [L-02] `getIdealBPT()` can serve as manipulation oracle for `minBPT` calculation

**Location**: [BalancerPoolerV2.sol#L171-L187](src/V2/dispatchers/BalancerPoolerV2.sol#L171-L187)

**Description**: `getIdealBPT()` is an unrestricted non-view function that queries the Balancer router for expected BPT output based on the contract's current sUSDS balance. If an authorized pooler or off-chain system uses this return value to set `minBPT` for `pool()` in the same transaction or block, an attacker can manipulate the Balancer pool state via a flash loan swap before the query executes. This produces a deflated BPT estimate, which, when used as the slippage floor, effectively neutralizes the slippage protection that `minBPT` is meant to provide.

**Impact**: If `minBPT` is derived from `getIdealBPT()` while the pool is in a manipulated state, the slippage protection parameter becomes meaningless and the protocol can receive fewer BPT than fair value.

**Recommendation**: Document explicitly that `getIdealBPT()` must NOT be used as the `minBPT` source in the same transaction as `pool()`. Authorized poolers should compute `minBPT` off-chain using TWAP or other manipulation-resistant pricing methods. Consider adding a NatSpec warning:

```solidity
/// @notice Queries the Balancer Router for the expected BPT output from pooling current sUSDS balance.
/// @dev WARNING: This value reflects spot pricing and is manipulable via flash loans.
///      Do NOT use this as the minBPT parameter for pool() in the same transaction.
///      Compute minBPT off-chain using TWAP or similar manipulation-resistant methods.
/// @return bptAmountOut The expected BPT amount, or 0 if sUSDS balance is 0.
function getIdealBPT() external returns (uint256 bptAmountOut) {
```

---

### [L-03] Authorized pooler `pool()` transaction is sandwichable without private mempool

**Location**: [BalancerPoolerV2.sol#L123-L129](src/V2/dispatchers/BalancerPoolerV2.sol#L123-L129)

**Description**: The authorized pooler's `pool(minBPT)` transaction, when submitted through a public mempool, is visible to MEV bots who can sandwich it. The single-sided `UNBALANCED` liquidity add is inherently more susceptible to price manipulation than proportional adds because it creates a one-directional price pressure that sandwich attackers can exploit. With large accumulated sUSDS balances (many dispatches between pool calls), the extractable value increases proportionally.

**Impact**: The protocol receives fewer BPT than fair value if the pooler submits via a public mempool with an insufficient `minBPT` floor.

**Recommendation**: Authorized poolers MUST use private mempools (e.g., Flashbots Protect) when submitting `pool()` transactions. Additionally, consider adding an owner-settable minimum floor for `minBPT` that prevents any pooler from passing a value below it:

```solidity
uint256 public minBPTFloor;

function setMinBPTFloor(uint256 floor) external onlyOwner {
    minBPTFloor = floor;
}

function pool(uint256 minBPT) external onlyAuthorizedPooler whenNotPaused {
    require(minBPT >= minBPTFloor, "BalancerPoolerV2: minBPT below floor");
    // existing logic
}
```

---

### [L-04] GatherV2 and BurnerV2 lack `rescueERC20` escape hatch

**Location**: [GatherV2.sol](src/V2/dispatchers/GatherV2.sol), [BurnerV2.sol](src/V2/dispatchers/BurnerV2.sol)

**Description**: `BalancerPoolerV2` includes a `rescueERC20()` function (added in Story-027) that allows the owner to recover tokens accidentally sent to the contract. However, `GatherV2` and `BurnerV2` lack this function. Under normal operation tokens pass through these dispatchers immediately via `dispatch()`, but any tokens sent directly to these contracts (user error, integration mishap, or airdrops) are permanently stuck with no recovery path.

**Impact**: Tokens accidentally transferred directly to the GatherV2 or BurnerV2 contract addresses are permanently irrecoverable.

**Recommendation**: Add `rescueERC20()` to the `ATokenDispatcherV2` base contract so all dispatchers inherit a uniform recovery mechanism:

```solidity
// In ATokenDispatcherV2.sol
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ATokenDispatcherV2 is ITokenDispatcherV2, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // ...existing code...

    /// @notice Rescues ERC20 tokens stuck on this dispatcher. Only callable by owner.
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "ATokenDispatcherV2: zero recipient");
        IERC20(token).safeTransfer(to, amount);
    }
}
```

---

### [L-05] `NFTMigrator.migrate()` DoS when V1 dispatcher registered after initialization

**Location**: [NFTMigrator.sol#L62-L76](src/V2/NFTMigrator.sol#L62-L76)

**Description**: `setInitialized()` validates that every existing V1 index has a corresponding V2 mapping at the time of initialization. However, `migrate()` iterates up to the live `v1.nextIndex()`, which reflects the current state of the V1 contract. If the V1 owner registers a new dispatcher after the migrator has been initialized, the newly created V1 index will have no V2 mapping (`indexMapping[i] == 0`). When `migrate()` encounters this index and a user holds a balance of the corresponding V1 token, it calls `v2.mintFor(0, msg.sender)`, which reverts because index 0 has no registered dispatcher. This reverts the entire transaction, blocking ALL of the user's migrations -- not just the unmapped index.

**Impact**: Users whose V1 portfolio includes tokens from any post-initialization V1 index have their migration transaction fully revert, creating a denial-of-service for those users. This requires the V1 owner to register a new dispatcher (an owner-driven action), but represents an operational footgun that could unintentionally block migrations.

**Recommendation**: In `migrate()`, skip indexes where `indexMapping[i] == 0` instead of attempting to mint with index zero:

```solidity
function migrate() external {
    require(initialized, "NFTMigrator: not initialized");
    uint256 upperBound = v1.nextIndex();
    for (uint256 i = 1; i < upperBound; i++) {
        uint256 v2Index = indexMapping[i];
        if (v2Index == 0) continue; // skip unmapped indexes
        uint256 balance = IERC1155(address(v1)).balanceOf(msg.sender, i);
        if (balance > 0) {
            v1.burn(msg.sender, i, balance);
            for (uint256 j = 0; j < balance; j++) {
                v2.mintFor(v2Index, msg.sender);
            }
            emit Migrated(msg.sender, i, balance, v2Index);
        }
    }
}
```

Alternatively, freeze V1 dispatcher registration after migrator initialization.

---
