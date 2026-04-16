<!--
C4 Submission Metadata
Title: [M-01] mintFor() bypasses global pause check, allowing minting during emergency stop
Root Cause Link: src/V2/NFTMinterV2.sol:206-214
PoC File: test/poc-M-01.t.sol
-->

## Finding description and impact

### Lines of code

`src/V2/NFTMinterV2.sol#L206-L214`

### Vulnerability details

`NFTMinterV2` implements a global pause mechanism through a dedicated `pauser` role and a `paused` state variable. When the contract is paused, the `_executeMint()` internal function correctly enforces the pause check at line 171:

```solidity
function _executeMint(uint256 index, address recipient, bytes memory extraData) internal returns (bool) {
    require(!paused, "Contract is paused");
    // ...
}
```

However, the `mintFor()` function -- which allows authorized minters (such as the `NFTMigrator` contract) to mint NFTs without payment or dispatch -- does not include this check:

```solidity
function mintFor(uint256 index, address recipient) external {
    require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");
    require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

    // Mint 1 claim NFT to recipient — no payment, no dispatch, no price update
    _mint(recipient, index, 1, "");

    emit ClaimMintedFor(recipient, index, msg.sender);
}
```

The `mintFor()` function validates the caller is an authorized minter and that the dispatcher index is registered, but entirely skips the `require(!paused)` guard. This means that when the contract owner or pauser triggers an emergency pause, the `mintFor()` code path remains operational.

The attack path is as follows:

1. A vulnerability is discovered in a dispatcher or the claim redemption system.
2. The pauser calls `pause()` to emergency-halt all minting activity.
3. Regular `mint()` calls correctly revert with "Contract is paused" due to the check in `_executeMint()`.
4. A user calls `NFTMigrator.migrate()` (or any other authorized minter contract calls `mintFor()`).
5. `mintFor()` succeeds because it never checks the `paused` state variable.
6. New claim NFTs are minted despite the emergency stop being active.

### Impact

The global pause mechanism is incomplete. During an emergency -- for example, a discovered vulnerability in a dispatcher contract or the NFT claim redemption system -- authorized minters can continue minting claim NFTs through `mintFor()`. This undermines the purpose of the pause functionality, which exists to give the protocol team the ability to freeze all minting activity during incident response.

Concretely, NFTs minted during a pause may entitle holders to claim yield from compromised dispatchers, or may inflate the total supply at a time when the protocol explicitly intended to halt all state changes. The `pauser` role is a dedicated safety mechanism (implemented via the Global Pauser pattern), and having `mintFor()` bypass it creates a gap in the emergency stop coverage.

### Proof of Concept

A runnable Foundry PoC is provided in `test/poc-M-01.t.sol`. The test demonstrates:

1. Both `mint()` and `mintFor()` succeed before pausing.
2. After the pauser calls `pause()`, regular `mint()` correctly reverts with "Contract is paused".
3. `mintFor()` succeeds despite `paused == true`, minting a new NFT to the recipient.
4. The total supply increases while the contract is in a paused state.

Run with:

```bash
forge test --match-test test_M01_mintFor_bypasses_global_pause -vvv
```

## Recommended mitigation steps

Add the `require(!paused)` check to `mintFor()`, consistent with the existing check in `_executeMint()`:

```diff
 function mintFor(uint256 index, address recipient) external {
+    require(!paused, "Contract is paused");
     require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");
     require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

     _mint(recipient, index, 1, "");

     emit ClaimMintedFor(recipient, index, msg.sender);
 }
```

Alternatively, extract the pause check into an internal `_requireNotPaused()` modifier or function and apply it to both `_executeMint()` and `mintFor()` to prevent future divergence.
