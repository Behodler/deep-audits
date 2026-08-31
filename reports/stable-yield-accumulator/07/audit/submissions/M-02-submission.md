<!--
C4 Submission Metadata
Title: [M-02] NFT index validation does not verify dispatcher corresponds to StableYieldAccumulator claims
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L472-L489
PoC File: M-02-poc.t.sol
-->

## Finding description and impact

### Summary

The `_validateAndBurnNFT` function in `StableYieldAccumulator.sol` accepts an arbitrary `nftIndex` from the caller and validates only that a dispatcher exists at that index and the caller holds the corresponding token. It does not verify that the dispatcher is specifically authorized for StableYieldAccumulator claim operations. Since the NFTMinter is a protocol-wide ERC1155 system designed to support multiple dispatchers for different purposes, any NFT from any registered dispatcher satisfies the claim gate.

### Vulnerability details

The vulnerable code at [StableYieldAccumulator.sol#L472-L489](https://github.com/Behodler/stable-yield-accumulator/blob/main/src/StableYieldAccumulator.sol#L472-L489):

```solidity
function _validateAndBurnNFT(address caller, uint256 index) internal {
    require(nftMinter != address(0), "NFT minter not configured");
    INFTMinter minter = INFTMinter(nftMinter);

    (address dispatcher, , ) = minter.configs(index);
    if (dispatcher == address(0)) revert NoValidNFT();

    uint256 tokenId = minter.dispatcherTokenIdOverride(dispatcher);
    if (tokenId == 0) {
        tokenId = index;
    }

    if (IERC1155(nftMinter).balanceOf(caller, tokenId) > 0) {
        minter.burn(caller, tokenId, 1);
    } else {
        revert NoValidNFT();
    }
}
```

The function performs three checks:
1. `dispatcher != address(0)` -- confirms a dispatcher exists at the index
2. Resolves the token ID (via override or default to index)
3. Confirms the caller holds a balance of that token ID

Critically absent is any check that the dispatcher at `index` is the one designated for StableYieldAccumulator claim access. The NFTMinter's `configs` mapping can hold dispatchers registered for entirely unrelated protocol functions (e.g., governance participation, loyalty rewards, promotional mints). Each dispatcher can have its own pricing model via the `price` and `growthBasisPoints` fields in its config.

The `claim` function at line 422 passes the user-supplied `nftIndex` directly through:

```solidity
function claim(uint256 nftIndex) external override whenNotPaused nonReentrant {
    // ...
    _validateAndBurnNFT(msg.sender, nftIndex);
    // ...
}
```

A user who holds an NFT minted through a cheaper, unrelated dispatcher can pass that dispatcher's index to `claim()` and bypass the intended claim-access pricing.

### Impact

The NFT gate on `claim()` is designed to enforce an economic cost for accessing yield claims, creating a revenue stream for the protocol. This finding undermines that mechanism:

- If the NFTMinter has multiple dispatchers with different price points (which is its intended design as a protocol-wide system), users will use the cheapest available NFT to satisfy the claim gate.
- The protocol's intended claim-access pricing is bypassed. Instead of paying the price set by the designated claim dispatcher, users pay whatever the lowest-cost dispatcher charges.
- In the worst case, a dispatcher with zero or negligible cost (e.g., a promotional or free-mint dispatcher) would render the claim gate effectively non-existent.

This directly undermines the protocol's revenue model for gating claim access and breaks the assumption that claim NFTs carry a specific economic cost.

## Recommended mitigation steps

Store the expected dispatcher index (or address) in `StableYieldAccumulator` and validate it during NFT burn. Add a setter for the owner to configure the authorized dispatcher:

```solidity
uint256 public claimDispatcherIndex;

function setClaimDispatcherIndex(uint256 index) external onlyOwner {
    INFTMinter minter = INFTMinter(nftMinter);
    (address dispatcher, , ) = minter.configs(index);
    require(dispatcher != address(0), "Invalid dispatcher index");
    claimDispatcherIndex = index;
}

function _validateAndBurnNFT(address caller, uint256 index) internal {
    require(nftMinter != address(0), "NFT minter not configured");
    require(index == claimDispatcherIndex, "Invalid dispatcher for claims");
    INFTMinter minter = INFTMinter(nftMinter);

    (address dispatcher, , ) = minter.configs(index);
    if (dispatcher == address(0)) revert NoValidNFT();

    uint256 tokenId = minter.dispatcherTokenIdOverride(dispatcher);
    if (tokenId == 0) {
        tokenId = index;
    }

    if (IERC1155(nftMinter).balanceOf(caller, tokenId) > 0) {
        minter.burn(caller, tokenId, 1);
    } else {
        revert NoValidNFT();
    }
}
```

Alternatively, remove the `nftIndex` parameter from `claim()` entirely and use the stored `claimDispatcherIndex` internally, preventing any user-controlled dispatcher selection.
