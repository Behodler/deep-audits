<!--
C4 Submission Metadata
Title: [M-03] BalancerPoolerV2.setPool strands previous pool's BPT in withdrawBPT path
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/BalancerPoolerV2.sol#L43-L99
PoC File: test/poc-M-03.t.sol
-->

## Finding description and impact

### Summary
`BalancerPoolerV2` makes `_pool` mutable via `setPool` (a new V2 capability) but `withdrawBPT` always dereferences the *current* `_pool` as the BPT token to transfer. If the owner rotates the pool while the contract still holds BPT of the previously configured pool, the standard `withdrawBPT` path can no longer reach those BPT tokens, leaving them stranded. No generic ERC20 rescue function exists.

### Vulnerability details

The two relevant locations in [`src/V2/dispatchers/BalancerPoolerV2.sol`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/BalancerPoolerV2.sol) are:

`setPool` at [L43-L46](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/BalancerPoolerV2.sol#L43-L46):
```solidity
function setPool(address newPool) external onlyOwner {
    require(newPool != address(0), "BalancerPoolerV2: zero pool address");
    _pool = newPool;
}
```

`withdrawBPT` at [L97-L99](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/BalancerPoolerV2.sol#L97-L99):
```solidity
function withdrawBPT(address recipient, uint256 amount) external onlyOwner {
    IERC20(_pool).transfer(recipient, amount);
}
```

In Balancer V3, the pool contract *is* the BPT ERC20, so `IERC20(_pool)` resolves to the BPT token for whichever pool is currently configured. `withdrawBPT` therefore has an implicit invariant that `_pool` equals the pool whose BPT is being withdrawn. V2 breaks that invariant by making `_pool` owner-mutable.

The failure sequence:

1. Owner deploys `BalancerPoolerV2` with `pool_ = POOL_A`.
2. `dispatch()` runs one or more times, accumulating BPT_A on the contract.
3. Owner rotates to `POOL_B` via `setPool(POOL_B)` (e.g. to migrate the dispatcher to a new liquidity pool).
4. Owner calls `withdrawBPT(recipient, amount)` intending to withdraw the BPT_A still on the contract.
5. `withdrawBPT` dereferences the current `_pool`, which is now `POOL_B`, and attempts `IERC20(POOL_B).transfer(...)`. The contract holds zero BPT_B, so the call reverts with `ERC20InsufficientBalance`.

The previous pool's BPT is unreachable via the intended admin path. Because there is no generic `rescueERC20(token, to, amount)`, the only workaround is to call `setPool(POOL_A)` to re-point the contract at the old pool, call `withdrawBPT`, then call `setPool(POOL_B)` to restore the active pool. This is operationally fragile: any minter-driven `dispatch()` call during the re-point window joins liquidity into the wrong pool, and the admin ends up flipping a state variable that is meant to represent the currently active pool purely to perform a rescue.

### Impact

Owner-controlled assets (BPT of a previously configured pool) become stranded via the standard withdrawal path after a pool rotation. The user has stated that one motivation for the V2 dispatcher is precisely to let the owner withdraw BPT in order to migrate to V2, so a failure mode that blocks BPT withdrawals after a `setPool` call directly undermines the intended operational flow. While not an attacker-driven loss, it is a realistic owner footgun and the "rescue" path requires temporarily corrupting the semantic meaning of `_pool`.

## Recommended mitigation steps

Either add a generic rescue function so that BPT of any pool can be recovered without re-pointing `_pool`:

```solidity
/// @notice Rescues arbitrary ERC20 tokens held by this contract.
///         Required because _pool is mutable and the previous pool's BPT
///         is not reachable via withdrawBPT after setPool.
function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
    require(to != address(0), "BalancerPoolerV2: zero recipient");
    IERC20(token).transfer(to, amount);
}
```

Or change `withdrawBPT` to accept the BPT/pool token address as an explicit parameter rather than reading it from state:

```solidity
function withdrawBPT(address bpt, address recipient, uint256 amount) external onlyOwner {
    IERC20(bpt).transfer(recipient, amount);
}
```

Either fix decouples the withdrawal target from the currently active `_pool`, eliminating the need for the temporary-re-point workaround and preventing stranded BPT after a pool rotation.

## Proof of Concept

The following Foundry test (`test/poc-M-03.t.sol`) demonstrates the stranding and the fragile workaround. Both tests pass against the current `BalancerPoolerV2` implementation.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BalancerPoolerV2} from "../src/V2/dispatchers/BalancerPoolerV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Minimal mock ERC20 standing in for Balancer BPT tokens (BPT_A and BPT_B).
// Balancer V3 pool contracts ARE ERC20 BPTs, so using a plain ERC20 mock
// faithfully models the storage/accounting behavior relevant to this bug.
contract MockBPT is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract M03PoCTest is Test {
    BalancerPoolerV2 internal pooler;

    MockBPT internal bptA; // represents POOL_A (BPT of pool A)
    MockBPT internal bptB; // represents POOL_B (BPT of pool B)
    MockBPT internal primeToken;
    address internal vaultAddr = address(0xBEEF);

    address internal owner = address(this);

    uint256 internal constant STRANDED_AMOUNT = 1000 ether;

    function setUp() public {
        bptA = new MockBPT("Balancer Pool Token A", "BPT_A");
        bptB = new MockBPT("Balancer Pool Token B", "BPT_B");
        primeToken = new MockBPT("Prime", "PRM");

        // Deploy BalancerPoolerV2 with pool = POOL_A (bptA).
        pooler = new BalancerPoolerV2(
            address(primeToken),
            address(bptA),
            vaultAddr,
            true,
            owner
        );

        // Simulate the pooler holding 1000 BPT_A from prior dispatch() joins.
        bptA.mint(address(pooler), STRANDED_AMOUNT);

        assertEq(bptA.balanceOf(address(pooler)), STRANDED_AMOUNT);
        assertEq(bptB.balanceOf(address(pooler)), 0);
        assertEq(pooler.pool(), address(bptA));
    }

    /// @notice After setPool(POOL_B), withdrawBPT reverts because it targets
    ///         BPT_B (balance = 0) instead of the stranded BPT_A.
    function test_M03_withdrawBPT_stranded_after_setPool() public {
        pooler.setPool(address(bptB));
        assertEq(pooler.pool(), address(bptB));

        // 1000 BPT_A is still sitting on the pooler contract.
        assertEq(bptA.balanceOf(address(pooler)), STRANDED_AMOUNT);
        assertEq(bptB.balanceOf(address(pooler)), 0);

        // withdrawBPT uses the CURRENT _pool (now BPT_B) and reverts.
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                address(pooler),
                uint256(0),
                STRANDED_AMOUNT
            )
        );
        pooler.withdrawBPT(owner, STRANDED_AMOUNT);

        // Confirm nothing moved.
        assertEq(bptA.balanceOf(address(pooler)), STRANDED_AMOUNT);
        assertEq(bptA.balanceOf(owner), 0);
        assertEq(bptB.balanceOf(owner), 0);
    }

    /// @notice The only available workaround: flip _pool back to POOL_A,
    ///         withdraw, then flip to POOL_B again. This motivates adding
    ///         a generic rescueERC20.
    function test_M03_workaround_requires_repointing_pool() public {
        pooler.setPool(address(bptB));

        // Natural path is still broken.
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                address(pooler),
                uint256(0),
                STRANDED_AMOUNT
            )
        );
        pooler.withdrawBPT(owner, STRANDED_AMOUNT);

        // Workaround: re-point _pool, withdraw, re-point back.
        pooler.setPool(address(bptA));
        pooler.withdrawBPT(owner, STRANDED_AMOUNT);
        pooler.setPool(address(bptB));

        assertEq(bptA.balanceOf(owner), STRANDED_AMOUNT);
        assertEq(bptA.balanceOf(address(pooler)), 0);
        assertEq(pooler.pool(), address(bptB));
    }
}
```

Run with:
```bash
forge test --match-contract M03PoCTest -vv
```

Both tests pass against the current source, confirming that `withdrawBPT` cannot recover previous-pool BPT after `setPool`, and that the only in-contract workaround is to temporarily repoint `_pool`.
