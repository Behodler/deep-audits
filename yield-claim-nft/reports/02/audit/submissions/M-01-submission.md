<!--
C4 Submission Metadata
Title: [M-01] V2 migration mints into disabled V2 dispatchers (mintFor ignores `disabled` flag)
Severity: Medium
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L203-L211
PoC File: test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

`NFTMinterV2.mintFor(index, recipient)` is the privileged mint path intended for authorized minters such as `NFTMigrator` during V1 to V2 migration. Unlike the paid mint path (`_executeMint`), `mintFor` fails to check `configs[index].disabled`. As a result, an owner who disables a V2 dispatcher via `setDispatcherDisabled(index, true)` — e.g. to halt further entitlement into a particular category — cannot actually stop V2 NFTs from being minted into that index through the migration flow.

### Vulnerability details

In [`NFTMinterV2.sol#L203-L211`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L203-L211), `mintFor` only verifies that the dispatcher is registered:

```solidity
function mintFor(uint256 index, address recipient) external {
    require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");
    require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

    // Mint 1 claim NFT to recipient — no payment, no dispatch, no price update
    _mint(recipient, index, 1, "");

    emit ClaimMintedFor(recipient, index, msg.sender);
}
```

Compare this against the paid path `_executeMint` at [`NFTMinterV2.sol#L167-L198`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L167-L198), which correctly enforces the disabled flag at line 174:

```solidity
require(config.dispatcher != address(0), "NFTMinterV2: index not registered");
require(!config.disabled, "NFTMinterV2: dispatcher is disabled");
```

The `disabled` flag is the owner's circuit breaker for an individual dispatcher/index. When set to true, `mint()` correctly reverts with `"NFTMinterV2: dispatcher is disabled"`. However, because `NFTMigrator` is registered as an authorized minter and invokes `mintFor` during migration, a holder of V1 NFTs mapped to a disabled V2 index can still mint into that index by triggering migration:

1. Owner calls `setDispatcherDisabled(v2Index, true)` to halt new entitlement.
2. A user holding V1 NFTs mapped to `v2Index` calls `NFTMigrator.migrate()`.
3. `migrate()` calls `NFTMinterV2.mintFor(v2Index, user)`.
4. The registration check passes; the disabled flag is never consulted.
5. A V2 NFT is minted for `v2Index` and `totalSupply(v2Index)` increases despite `configs[v2Index].disabled == true`.

### Impact

- Owner intent is silently violated. An explicit governance action (disabling a dispatcher) fails to stop minting into that dispatcher's index via the migration route. Any supply cap, pause-for-remediation, or emergency-halt assumption the owner places on the disabled flag is void for as long as any unmigrated V1 NFTs mapped to that index still exist.
- V2 supply in categories the owner has explicitly halted can continue to inflate. Because `mintFor` takes no payment and performs no dispatch, each bypassed mint inflates the `totalSupply(index)` without any offsetting value flow.
- The invariant "`disabled == true` implies no new NFTs can be minted at `index`" — which the paid path establishes — does not hold protocol-wide. This is a state-handling inconsistency between the two mint entry points that breaks the owner's ability to isolate a specific index in response to operational issues.

The likelihood is standard: any time the owner disables a V2 dispatcher while unmigrated V1 holders still exist in the mapped category, the bypass is reachable with a normal `migrate()` call by any such holder.

## Recommended mitigation steps

Add the same `disabled` check to `mintFor` that `_executeMint` already performs:

```solidity
function mintFor(uint256 index, address recipient) external {
    require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");
    DispatcherConfig storage config = configs[index];
    require(config.dispatcher != address(0), "NFTMinterV2: index not registered");
    require(!config.disabled, "NFTMinterV2: dispatcher is disabled");

    _mint(recipient, index, 1, "");
    emit ClaimMintedFor(recipient, index, msg.sender);
}
```

If migration must remain possible for an index after it has been disabled (i.e. owners want to freeze paid sales but still let V1 holders migrate), introduce a second, dedicated flag such as `migrationAllowed` (or `migrationDisabled`) per index and gate `mintFor` on that flag instead. This keeps the two policies — "new paid entitlement" and "V1 to V2 migration" — independently controllable, and makes owner intent explicit in each case.

## Proof of Concept

The following standalone Foundry test demonstrates the bypass. It shows (a) the paid `mint()` path correctly reverts with `"NFTMinterV2: dispatcher is disabled"` after the owner disables the index, and (b) the `mintFor(index, recipient)` path called by an authorized minter still succeeds on the same disabled index, inflating `balanceOf` and `totalSupply`.

Place at `test/poc-M-01.t.sol` and run with `forge test --match-test test_M01_mintFor_bypassesDisabledFlag -vv`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NFTMinterV2} from "../src/V2/NFTMinterV2.sol";
import {GatherV2} from "../src/V2/dispatchers/GatherV2.sol";

/// @dev Simple mock ERC20 for the paid-mint flow.
contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

/**
 * @title M-01 PoC: NFTMinterV2.mintFor ignores `disabled` flag
 * @notice Vulnerability location: src/V2/NFTMinterV2.sol#L203-L211
 */
contract M01PoC is Test {
    NFTMinterV2 internal minter;
    GatherV2 internal gather;
    MockERC20 internal token;

    address internal owner = address(this);
    address internal migrator = address(0xAAAA);        // Simulates the NFTMigrator contract
    address internal user = address(0xBEEF);            // Paid-mint user
    address internal migratedUser = address(0xCAFE);    // User whose V1 NFT is being migrated
    address internal gatherRecipient = address(0xFEED);

    uint256 internal constant INITIAL_PRICE = 10e18;
    uint256 internal constant GROWTH_BPS = 100; // 1%

    function setUp() public {
        minter = new NFTMinterV2(owner);
        token = new MockERC20("Token A", "TKA");

        gather = new GatherV2(address(token), gatherRecipient, owner);
        gather.setMinter(address(minter));

        minter.registerDispatcher(address(gather), INITIAL_PRICE, GROWTH_BPS);
        minter.setAuthorizedMinter(migrator, true);

        token.mint(user, INITIAL_PRICE * 10);
        vm.prank(user);
        token.approve(address(minter), type(uint256).max);
    }

    function test_M01_mintFor_bypassesDisabledFlag() public {
        // Step 1: sanity-check paid-mint path works BEFORE disabling
        vm.prank(user);
        minter.mint(address(token), 1, user);
        assertEq(minter.balanceOf(user, 1), 1, "paid mint should work before disable");

        // Step 2: owner disables the dispatcher to stop NEW entitlement
        uint256 index = 1;
        minter.setDispatcherDisabled(index, true);

        (, , , bool disabled) = minter.configs(index);
        assertTrue(disabled, "dispatcher should be disabled");

        // Step 3: paid-mint path CORRECTLY reverts
        vm.prank(user);
        vm.expectRevert(bytes("NFTMinterV2: dispatcher is disabled"));
        minter.mint(address(token), index, user);
        assertEq(minter.balanceOf(user, index), 1, "paid-mint revert should not change balance");

        // Step 4: BUG — mintFor(index, recipient) still SUCCEEDS
        uint256 migratedBalanceBefore = minter.balanceOf(migratedUser, index);
        uint256 supplyBefore = minter.totalSupply(index);

        vm.prank(migrator);
        minter.mintFor(index, migratedUser); // SHOULD revert; it does not.

        uint256 migratedBalanceAfter = minter.balanceOf(migratedUser, index);
        uint256 supplyAfter = minter.totalSupply(index);

        // Invariant violation
        assertEq(migratedBalanceBefore, 0, "migrated user should start with 0");
        assertEq(migratedBalanceAfter, 1, "BUG: mintFor minted into disabled dispatcher");
        assertEq(supplyAfter, supplyBefore + 1, "BUG: total supply for disabled index inflated");

        (, , , bool stillDisabled) = minter.configs(index);
        assertTrue(stillDisabled, "dispatcher is still flagged disabled");
        assertGt(
            minter.balanceOf(migratedUser, index),
            0,
            "INVARIANT VIOLATED: disabled dispatcher produced a new NFT via mintFor"
        );
    }
}
```

Expected output (abridged):

```
Ran 1 test for test/poc-M-01.t.sol:M01PoC
[PASS] test_M01_mintFor_bypassesDisabledFlag()
```

The `[PASS]` confirms that a V2 NFT was minted into `index = 1` via `mintFor` despite `configs[1].disabled == true`, with the paid path `mint()` correctly reverting under the exact same state.
