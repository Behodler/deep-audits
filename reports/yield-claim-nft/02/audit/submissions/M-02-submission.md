<!--
C4 Submission Metadata
Title: [M-02] NFTMigrator.migrate() DoS when a V1 dispatcher is registered after setInitialized
Severity: Medium
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMigrator.sol#L62-L76
Supporting Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMigrator.sol#L51-L58
PoC File: test/poc-M-02.t.sol
-->

## Finding description and impact

### Summary

`NFTMigrator.setInitialized()` enforces a one-time invariant that every currently-registered V1 dispatcher index has a non-zero V2 mapping. However, V1 dispatcher registration is **not frozen** at that point and `migrate()` iterates over the live `v1.nextIndex()` every time it is called. If the owner registers any new V1 dispatcher after `setInitialized()`, users who hold a V1 NFT at that new index will see the **entire** `migrate()` call revert — locking them out of migrating even the V1 NFTs they own at correctly-mapped indexes.

### Vulnerability details

The relevant code in [`NFTMigrator.sol`](../../../../workspace/yield-claim-nft/src/V2/NFTMigrator.sol):

```solidity
function setInitialized() external onlyOwner {
    uint256 upperBound = v1.nextIndex();
    for (uint256 i = 1; i < upperBound; i++) {
        require(indexMapping[i] != 0, "NFTMigrator: missing mapping");
    }
    initialized = true;
    emit Initialized();
}

function migrate() external {
    require(initialized, "NFTMigrator: not initialized");
    uint256 upperBound = v1.nextIndex();
    for (uint256 i = 1; i < upperBound; i++) {
        uint256 balance = IERC1155(address(v1)).balanceOf(msg.sender, i);
        if (balance > 0) {
            v1.burn(msg.sender, i, balance);
            uint256 v2Index = indexMapping[i];
            for (uint256 j = 0; j < balance; j++) {
                v2.mintFor(v2Index, msg.sender);   // reverts when v2Index == 0
            }
            emit Migrated(msg.sender, i, balance, v2Index);
        }
    }
}
```

Key observations:

1. `setInitialized()` validates mappings only for V1 indexes `[1, v1.nextIndex())` at the time of the call.
2. `NFTMinter.registerDispatcher` remains callable by the V1 owner after `setInitialized()` returns — nothing in `NFTMigrator` freezes V1 registration.
3. `migrate()` re-reads `v1.nextIndex()` at call time, so the loop upper bound grows as new dispatchers are registered.
4. When a new V1 dispatcher at index `N` has no mapping, `indexMapping[N] == 0`, and `v2.mintFor(0, msg.sender)` reverts inside `NFTMinterV2` with `"NFTMinterV2: index not registered"`.

Because the failing external call is made **inside the migrate() loop**, the revert rolls back the entire transaction. Users cannot migrate the V1 NFTs they own at correctly mapped indexes either — even though each of those transitions, taken alone, would succeed.

### Attack / trigger path

1. Owner registers V1 dispatchers at indexes 1..k and the corresponding V2 dispatchers.
2. Owner configures `indexMapping` for all V1 indexes 1..k and calls `setInitialized()` — succeeds.
3. Owner later registers a new V1 dispatcher (e.g., a new `Gather` strategy), creating V1 index `k+1`, without first adding a V2 mapping. This does not require malice: adding strategies is a supported operation, and nothing in the contracts prevents this ordering.
4. Any V1 holder who already owns or later mints an NFT at index `k+1` calls `migrate()`.
5. The loop reaches `i = k+1`, the balance is non-zero, `indexMapping[k+1] == 0`, and `v2.mintFor(0, user)` reverts with `"NFTMinterV2: index not registered"`, reverting the whole transaction.
6. The user cannot migrate anything — including their NFTs at indexes 1..k — until the owner adds a mapping for index `k+1`.

### Impact

- Migration availability failure. Any user whose V1 inventory includes a post-init V1 index is locked out of migrating their entire V1 position until the owner intervenes.
- The issue is purely an availability/liveness flaw: V1 NFTs remain owned by users and V2 NFTs are not incorrectly minted, so this is not a direct theft vector.
- Severity is Medium: protocol availability is impaired for affected users under a realistic operational sequence (the V1 owner adding a new dispatcher after go-live), the condition arises from an ordinary owner action rather than an extraordinary circumstance, and remediation is operational (owner must set a mapping).

### Proof of concept

A runnable Foundry PoC is provided at `test/poc-M-02.t.sol`. It:

1. Deploys V1 and V2 minters with two dispatchers each (indexes 1, 2).
2. Has a user mint V1 NFTs at indexes 1 and 2.
3. Owner maps `[1, 2] -> [1, 2]` and calls `setInitialized()` (succeeds).
4. Owner registers a new V1 dispatcher at index 3 with no V2 mapping.
5. User mints a V1 NFT at index 3.
6. User calls `migrate()` — the call reverts with `"NFTMinterV2: index not registered"`.
7. Asserts that the user still holds their V1 NFTs at indexes 1 and 2 (i.e., even the valid migration did not proceed).

Run with:

```bash
forge test --match-contract M02PoCTest -vvv
```

## Recommended mitigation steps

Choose one (or combine):

**Option A — skip unmapped indexes in `migrate()` (minimum-invasive fix):**

```solidity
function migrate() external {
    require(initialized, "NFTMigrator: not initialized");
    uint256 upperBound = v1.nextIndex();
    for (uint256 i = 1; i < upperBound; i++) {
        uint256 v2Index = indexMapping[i];
        if (v2Index == 0) {
            continue; // no V2 mapping yet; skip this V1 index
        }
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

This preserves migration liveness for all mapped indexes while surfacing the unmapped ones (e.g., via an event or a view helper) so the owner can follow up without having blocked users in the meantime.

**Option B — freeze V1 registration after initialization:**

Add a lock mechanism on V1 (callable by the migrator or owner) that prevents `registerDispatcher` from being called after `setInitialized()`. Requires a small change on `NFTMinter`. This makes the `setInitialized()` invariant permanent instead of pointwise.

**Option C — require new mappings before new V1 registration:**

Alternatively, extend `setInitialized()` into a re-checkable state, and require owners to re-run a validation (or to call `setMapping` prior to registering new V1 dispatchers). Lower assurance than Option B.

Option A is the recommended first-line fix because it removes the DoS entirely with a one-line code change and preserves the intended owner-driven rollout of new dispatchers. Option B can be added for stronger guarantees that the mapping cannot drift out of sync.
