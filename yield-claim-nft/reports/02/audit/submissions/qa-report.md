# QA Report — yield-claim-nft

## Summary

This QA report covers Low-severity findings identified during the audit of the `yield-claim-nft` V2 migration and the related V1 owner withdrawal paths. The in-scope surface includes the V2 migration contract (`NFTMigrator`), the V2 minter (`NFTMinterV2`), and the V1/V2 dispatcher contracts (`Gather`, `GatherV2`, `BurnerV2`). The issues below do not place user funds at direct risk but represent defense-in-depth gaps, scaling concerns, trust/transparency issues, and operational ergonomics that the team should consider before deployment.

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| **Total** | **5** |

---

## Low Risk Findings

### [L-01] NFTMigrator lacks reentrancy guard

**Location**: `src/V2/NFTMigrator.sol#L62-L76` (`migrate`)

**Description**: `migrate()` mints V2 NFTs via `v2.mintFor`, which invokes `_mint` and triggers `onERC1155Received` on contract recipients. A contract-based V1 holder can reenter `migrate()` from its callback. The current code is not exploitable for double-mint because the V1 burn precedes the V2 mint loop and the cached `balance` is not re-read — but this safety depends on a subtle code ordering. No `ReentrancyGuard` is applied, and event emissions may become inconsistent under reentrancy.

**Impact**: Defense-in-depth concern. Not currently exploitable for double-mint, but relies on fragile code ordering; event/state ordering under reentrancy may be inconsistent, which can confuse off-chain indexers and future maintainers who modify the function.

**Recommendation**: Apply `nonReentrant` from OpenZeppelin's `ReentrancyGuard` to `migrate()`.

---

### [L-02] NFTMigrator `setInitialized` not frozen; mappings editable post-init

**Location**: `src/V2/NFTMigrator.sol#L33-L58` (`setInitialized` / `setMapping` / `setMappings`)

**Description**: `setInitialized()` can be called repeatedly, and `setMapping`/`setMappings` have no post-init freeze. The owner can change V1→V2 mappings after users have already begun migrating, altering which V2 NFTs future migrants receive for the same underlying V1 tokens.

**Impact**: Users who migrate at different times can receive inconsistent V2 NFTs for the same V1 entitlement. This is a transparency/trust concern: the migration mapping is a protocol-critical parameter and should be immutable once migration opens.

**Recommendation**: Make `initialized` one-way (revert if already true) and gate `setMapping` / `setMappings` on `!initialized` so mappings cannot be altered after migration begins.

---

### [L-03] NFTMigrator.migrate() is O(v1.nextIndex()) and may hit block gas limit at scale

**Location**: `src/V2/NFTMigrator.sol#L62-L76` (`migrate`)

**Description**: Users pay gas proportional to the total number of V1 dispatchers, regardless of how many they actually hold. As the owner registers more V1 dispatchers over time, every migrator pays for iterating across every index. At sufficient scale, the per-tx gas cost may exceed the block gas limit and block migration entirely.

**Impact**: Scaling and UX concern. Gas cost grows linearly with dispatcher count; in the limit, migration becomes impossible for users whose calls exceed the block gas limit.

**Recommendation**: Add a per-index migrate overload (e.g. `migrate(uint256 v1Index)`) so users can migrate incrementally and bound their gas cost to only the indices they actually hold.

---

### [L-04] Gather / GatherV2 / BurnerV2 lack generic `rescueERC20`

**Location**: `src/dispatchers/Gather.sol`; `src/V2/dispatchers/GatherV2.sol`; `src/V2/dispatchers/BurnerV2.sol` (missing functionality)

**Description**: None of these dispatcher contracts expose an owner-only `rescueERC20` function. Under normal operation tokens pass through immediately, so accumulation is not expected. However, tokens sent directly to the contract — whether via user error, integration mishap, or fake-token transfers from external actors — become permanently stuck with no recovery path. V1 `Gather` has the same gap; although it is a pass-through, the missing rescue path removes any operational remedy.

**Impact**: Accidentally-transferred tokens are permanently stuck. No operational path exists to recover user or protocol funds that end up at the dispatcher addresses.

**Recommendation**: Add `rescueERC20(address token, address to, uint256 amount) onlyOwner` to the `ATokenDispatcher` / V2 dispatcher base so all dispatchers inherit a uniform recovery path.

---

### [L-05] NFTMinterV2 `ClaimMinted` event emits nominal `price` rather than `actualReceived`

**Location**: `src/V2/NFTMinterV2.sol#L195` (`_executeMint`; related ratchet at L185)

**Description**: The `ClaimMinted` event emits `pricePaid = price`, but the protocol actually receives `actualReceived`, which can diverge for fee-on-transfer tokens (and in adversarial fake-token scenarios). The price-growth ratchet at line 185 also uses the nominal `price` rather than `actualReceived`, so when FOT tokens are involved the on-chain price curve desynchronizes from real revenue.

**Impact**: Off-chain indexers and analytics misrepresent protocol revenue. The price-growth ratchet diverges from actual received value when fee-on-transfer tokens are used, compounding the discrepancy over time.

**Recommendation**: Emit `actualReceived` in the `ClaimMinted` event and use `actualReceived` in the price-growth ratchet formula so both on-chain state and off-chain observers reflect the value the protocol actually received.

---
