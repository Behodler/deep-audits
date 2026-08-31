<!--
C4 Submission Metadata
Title: [M-02] mintFor() ignores per-dispatcher disabled flag, allowing minting to disabled dispatchers
Root Cause Link: src/V2/NFTMinterV2.sol:206-214
PoC File: test/poc-M-02.t.sol
-->

## Finding description and impact

### Lines of code

`src/V2/NFTMinterV2.sol#L206-L214`

### Vulnerability details

`NFTMinterV2` provides two minting paths: the paid mint via `_executeMint()` and the privileged free mint via `mintFor()`. Each dispatcher registered in the `configs` mapping has a `disabled` flag that the owner can toggle via `setDispatcherDisabled()` to halt minting for a specific dispatcher index -- for example, if a vulnerability is discovered in that dispatcher or the associated strategy is being wound down.

The paid mint path correctly enforces this control at line 174:

```solidity
function _executeMint(uint256 index, address recipient, bytes memory extraData) internal returns (bool) {
    require(!paused, "Contract is paused");
    DispatcherConfig storage config = configs[index];
    require(config.dispatcher != address(0), "NFTMinterV2: index not registered");
    require(!config.disabled, "NFTMinterV2: dispatcher is disabled"); // <-- enforced
    // ...
}
```

However, `mintFor()` omits the disabled check entirely:

```solidity
function mintFor(uint256 index, address recipient) external {
    require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");
    require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

    // Mint 1 claim NFT to recipient -- no payment, no dispatch, no price update
    _mint(recipient, index, 1, "");

    emit ClaimMintedFor(recipient, index, msg.sender);
}
```

The only validation in `mintFor()` is that the caller is an authorized minter and that the dispatcher index is registered (non-zero address). The `disabled` flag is never read.

This creates a concrete bypass via the `NFTMigrator` contract, which is registered as an authorized minter and calls `mintFor()` on behalf of users migrating V1 NFTs to V2. The attack path is:

1. Owner discovers an issue with a V2 dispatcher at index N.
2. Owner calls `setDispatcherDisabled(N, true)` to halt all new mints for that dispatcher.
3. Regular `mint()` calls targeting index N are correctly blocked by `_executeMint`.
4. A user holding V1 NFTs mapped to index N calls `NFTMigrator.migrate()`.
5. The migrator calls `v2.mintFor(N, user)` -- the disabled check is absent.
6. V2 NFTs are minted for the disabled dispatcher, bypassing the owner's intent.

### Impact

The `disabled` flag is the owner's mechanism for halting minting to a specific dispatcher without pausing the entire contract. When `mintFor()` ignores this flag, the owner loses granular control over which dispatchers accept new mints through the privileged path.

In practice, if a dispatcher is disabled because a vulnerability has been identified, migration through `NFTMigrator` (or any other authorized minter) can still produce V2 NFTs linked to that compromised dispatcher. This inflates V2 supply in categories the owner explicitly halted and may expose migrating users to NFTs backed by a broken or exploitable dispatcher, undermining the safety mechanism the disabled flag was designed to provide.

### Proof of Concept

A runnable Foundry PoC is provided at `test/poc-M-02.t.sol`. It demonstrates both the migration path and the direct `mintFor()` path.

Run with:

```bash
forge test --match-test test_M02 -vvv
```

The test:
1. Deploys V1/V2 minters, a dispatcher, and the NFTMigrator.
2. Mints V1 NFTs for a user and configures the migrator mapping.
3. Disables the V2 dispatcher at the target index.
4. Confirms that `mint()` correctly reverts with `"NFTMinterV2: dispatcher is disabled"`.
5. Calls `migrate()` -- `mintFor()` succeeds despite the disabled flag.
6. Asserts that 2 V2 NFTs were minted at the disabled dispatcher index, confirming the bypass.

## Recommended mitigation steps

Add the `disabled` check to `mintFor()` to match the enforcement in `_executeMint()`:

```diff
 function mintFor(uint256 index, address recipient) external {
     require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");
     require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");
+    require(!configs[index].disabled, "NFTMinterV2: dispatcher is disabled");

     // Mint 1 claim NFT to recipient -- no payment, no dispatch, no price update
     _mint(recipient, index, 1, "");

     emit ClaimMintedFor(recipient, index, msg.sender);
 }
```

This ensures that both minting paths respect the owner's per-dispatcher disabled flag consistently.
