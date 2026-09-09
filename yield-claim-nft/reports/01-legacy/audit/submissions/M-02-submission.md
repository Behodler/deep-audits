<!--
C4 Submission Metadata
Title: [M-02] BalancerPooler MEV sandwich on predictable pool donation extracts value on every mint
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/main/src/dispatchers/BalancerPooler.sol#L98-L105
PoC File: M-02-poc.t.sol
-->

## Finding description and impact

### Summary

`BalancerPooler.unlockCallback()` donates tokens to a Balancer V3 pool using `AddLiquidityKind.DONATION` with a publicly predictable donation amount and no private transaction protection. An MEV searcher can sandwich every `dispatch()` call to extract a share of the donated value proportional to their pool ownership.

### Vulnerability details

The vulnerable code in [`BalancerPooler.sol#L98-L105`](https://github.com/Behodler/yield-claim-nft/blob/main/src/dispatchers/BalancerPooler.sol#L98-L105):

```solidity
AddLiquidityParams memory params = AddLiquidityParams({
    pool: _pool,
    to: address(this),
    maxAmountsIn: maxAmountsIn,
    minBptAmountOut: 0,
    kind: AddLiquidityKind.DONATION,
    userData: ""
});
```

Balancer V3's `DONATION` liquidity kind increases the reserves backing all existing BPT tokens **without minting new BPT**. This means every BPT holder's share becomes more valuable after a donation. The `minBptAmountOut: 0` is technically correct for donations (no BPT is minted), but the core issue is that the donation itself is unprotected against MEV extraction.

Two properties make this exploitable:

1. **Predictable donation amount**: The donation amount equals the NFT mint price, which is publicly readable on-chain via `NFTMinter.getPrice()`. An MEV searcher knows the exact value that will be donated before the transaction is mined.

2. **No private transaction mechanism**: The `dispatch()` call is submitted to the public mempool with no commit-reveal scheme, Flashbots integration, or other MEV protection.

The attack path is:

1. MEV searcher monitors the mempool for `NFTMinter.mint()` or `BalancerPooler.dispatch()` transactions.
2. **Front-run**: Searcher joins the Balancer pool (acquires BPT) in the same block, before the donation.
3. **Victim transaction**: `dispatch()` executes, donating both `primeToken` and `phUSD` to the pool. Reserves increase but BPT supply remains constant.
4. **Back-run**: Searcher exits the pool, receiving more underlying tokens than they deposited. Profit equals their pool share multiplied by the total donation amount.

### Impact

Value is extracted from every NFT mint that routes through `BalancerPooler`. The extracted value comes directly from the donation, meaning less value accrues to legitimate LP providers.

The profit scales linearly with the attacker's pool share:
- A searcher holding ~9% of the pool extracts ~9% of the donation.
- A well-capitalized searcher who temporarily acquires a majority pool share can extract the majority of the donation.

For a 100e18 donation against a 20,000e18 pool with a 1,000e18 searcher deposit (representing ~9.09% pool share), the searcher extracts approximately 9.09e18 in profit per mint. Over many mints, this represents a cumulative and significant value leak from the protocol to MEV searchers.

## Recommended mitigation steps

The most effective mitigation is to submit mint transactions through a private transaction relay (e.g., Flashbots Protect) to prevent mempool visibility. This can be enforced at the frontend/SDK level rather than in the contract itself.

If a contract-level mitigation is preferred, consider a commit-reveal pattern for mints:

```solidity
// Phase 1: User commits a hash of their mint parameters
function commitMint(bytes32 commitment) external {
    commitments[msg.sender] = Commitment({
        hash: commitment,
        blockNumber: block.number
    });
}

// Phase 2: User reveals and executes after a delay
function revealMint(uint256 tokenId, bytes32 salt) external {
    Commitment memory c = commitments[msg.sender];
    require(c.hash == keccak256(abi.encodePacked(msg.sender, tokenId, salt)), "Invalid reveal");
    require(block.number > c.blockNumber + COMMIT_DELAY, "Too early");
    delete commitments[msg.sender];
    // ... execute mint and dispatch
}
```

Alternatively, if the MEV leakage is considered an acceptable cost of the donation mechanism, document this as a known design tradeoff so that LP providers are aware their yield is partially diluted by MEV extraction.
