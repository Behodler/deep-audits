# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | For Operations that will not overflow, you could use unchecked | 16 |
| [GAS-2](#GAS-2) | Use Custom Errors instead of Revert Strings to save Gas | 7 |
| [GAS-3](#GAS-3) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 5 |
| [GAS-4](#GAS-4) | Using `private` rather than `public` for constants, saves gas | 9 |
| [GAS-5](#GAS-5) | Increments/decrements can be unchecked in for-loops | 5 |
| [GAS-6](#GAS-6) | Use != 0 instead of > 0 for unsigned integer comparison | 1 |
### <a name="GAS-1"></a>[GAS-1] For Operations that will not overflow, you could use unchecked

*Instances (16)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

4: import "@forge-std/Script.sol";

5: import "@forge-std/console.sol";

83:         for (uint256 i = 0; i < 4; i++) {

84:             if (_isAuthorized(ps[i])) n++;

91:         for (uint256 i = 0; i < 4; i++) {

94:             console.log(_isAuthorized(ps[i]) ? "    -> AUTHORIZED" : "    -> unauthorized");

104:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

117:             console.log("All four poolers already unauthorized - nothing to do, no transaction sent (idempotent).");

138:         require(versionAfter == versionBefore + 1, "post: authVersion not bumped exactly once");

140:         for (uint256 i = 0; i < 4; i++) {

145:             console.log("PREVIEW: nothing broadcast. Run balancer-holding:broadcast with the Ledger to apply.");

```

```solidity
File: script/VerifyBalancerHolding.s.sol

4: import "@forge-std/console.sol";

5: import {BalancerHoldingBase} from "./RevokeBalancerPoolersHoldingPattern.s.sol";

21:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

24:         for (uint256 i = 0; i < 4; i++) {

27:         for (uint256 i = 0; i < 4; i++) {

```

### <a name="GAS-2"></a>[GAS-2] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (7)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

104:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

105:         require(BALANCER_POOLER_V2.code.length > 0, "preflight: BalancerPoolerV2 has no code");

106:         require(_pooler().owner() == OWNER, "preflight: BalancerPoolerV2 owner is not OWNER");

138:         require(versionAfter == versionBefore + 1, "post: authVersion not bumped exactly once");

141:             require(!_isAuthorized(ps[i]), "post: pooler still authorized");

```

```solidity
File: script/VerifyBalancerHolding.s.sol

21:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

28:             require(!_isAuthorized(ps[i]), "verify: pooler still authorized");

```

### <a name="GAS-3"></a>[GAS-3] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
Pre-increments and pre-decrements are cheaper.

For a `uint256 i` variable, the following is true with the Optimizer enabled at 10k:

**Increment:**

- `i += 1` is the most expensive form
- `i++` costs 6 gas less than `i += 1`
- `++i` costs 5 gas less than `i++` (11 gas less than `i += 1`)

**Decrement:**

- `i -= 1` is the most expensive form
- `i--` costs 11 gas less than `i -= 1`
- `--i` costs 5 gas less than `i--` (16 gas less than `i -= 1`)

Note that post-increments (or post-decrements) return the old value before incrementing or decrementing, hence the name *post-increment*:

```solidity
uint i = 1;  
uint j = 2;
require(j == i++, "This will be false as i is incremented after the comparison");
```
  
However, pre-increments (or pre-decrements) return the new value:
  
```solidity
uint i = 1;  
uint j = 2;
require(j == ++i, "This will be true as i is incremented before the comparison");
```

In the pre-increment case, the compiler has to create a temporary variable (when used) for returning `1` instead of `2`.

Consider using pre-increments and pre-decrements where they are relevant (meaning: not where post-increments/decrements logic are relevant).

*Saves 5 gas per instance*

*Instances (5)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

83:         for (uint256 i = 0; i < 4; i++) {

91:         for (uint256 i = 0; i < 4; i++) {

140:         for (uint256 i = 0; i < 4; i++) {

```

```solidity
File: script/VerifyBalancerHolding.s.sol

24:         for (uint256 i = 0; i < 4; i++) {

27:         for (uint256 i = 0; i < 4; i++) {

```

### <a name="GAS-4"></a>[GAS-4] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (9)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

49:     uint256 public constant CHAIN_ID = 1;

52:     address public constant BALANCER_POOLER_V2 = 0x7f6874332c4629429d70D15f685A8230323F11F1;

54:     address public constant OWNER = 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6;

56:     address public constant MULTI_POOLER = 0xd1E5774159381915f5579dFd68507E2614f67b51;

57:     address public constant POOLER_7702_EOA = 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F;

58:     address public constant POOLER_EOA = 0x630966B668b321Cc6441754f96519a55F72Cd476;

61:     address public constant NFT_MINTER = 0x39Af088408e815844c567037C157B31d48d2E10F;

62:     address public constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

63:     address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

```

### <a name="GAS-5"></a>[GAS-5] Increments/decrements can be unchecked in for-loops
In Solidity 0.8+, there's a default overflow check on unsigned integers. It's possible to uncheck this in for-loops and save some gas at each iteration, but at the cost of some code readability, as this uncheck cannot be made inline.

[ethereum/solidity#10695](https://github.com/ethereum/solidity/issues/10695)

The change would be:

```diff
- for (uint256 i; i < numIterations; i++) {
+ for (uint256 i; i < numIterations;) {
 // ...  
+   unchecked { ++i; }
}  
```

These save around **25 gas saved** per instance.

The same can be applied with decrements (which should use `break` when `i == 0`).

The risk of overflow is non-existent for `uint256`.

*Instances (5)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

83:         for (uint256 i = 0; i < 4; i++) {

91:         for (uint256 i = 0; i < 4; i++) {

140:         for (uint256 i = 0; i < 4; i++) {

```

```solidity
File: script/VerifyBalancerHolding.s.sol

24:         for (uint256 i = 0; i < 4; i++) {

27:         for (uint256 i = 0; i < 4; i++) {

```

### <a name="GAS-6"></a>[GAS-6] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (1)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

105:         require(BALANCER_POOLER_V2.code.length > 0, "preflight: BalancerPoolerV2 has no code");

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Array indices should be referenced via `enum`s rather than via numeric literals | 4 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 5 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 4 |
| [NC-4](#NC-4) | Delete rogue `console.log` imports | 2 |
| [NC-5](#NC-5) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-6](#NC-6) | Functions should not be longer than 50 lines | 8 |
| [NC-7](#NC-7) | Interfaces should be defined in separate files from their usage | 1 |
| [NC-8](#NC-8) | NatSpec is completely non-existent on functions that should have them | 8 |
| [NC-9](#NC-9) | `address`s shouldn't be hard-coded | 8 |
| [NC-10](#NC-10) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-11](#NC-11) | Variables need not be initialized to zero | 5 |
### <a name="NC-1"></a>[NC-1] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (4)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

66:         ps[0] = OWNER;

67:         ps[1] = MULTI_POOLER;

68:         ps[2] = POOLER_7702_EOA;

69:         ps[3] = POOLER_EOA;

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (5)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

83:         for (uint256 i = 0; i < 4; i++) {

91:         for (uint256 i = 0; i < 4; i++) {

140:         for (uint256 i = 0; i < 4; i++) {

```

```solidity
File: script/VerifyBalancerHolding.s.sol

24:         for (uint256 i = 0; i < 4; i++) {

27:         for (uint256 i = 0; i < 4; i++) {

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (4)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

84:             if (_isAuthorized(ps[i])) n++;

```

```solidity
File: script/VerifyBalancerHolding.s.sol

19:         console.log("  VERIFY BALANCER HOLDING PATTERN (story 099)");

25:             if (_isAuthorized(ps[i])) console.log("STILL AUTHORIZED:", ps[i]);

28:             require(!_isAuthorized(ps[i]), "verify: pooler still authorized");

```

### <a name="NC-4"></a>[NC-4] Delete rogue `console.log` imports
These shouldn't be deployed in production

*Instances (2)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

5: import "@forge-std/console.sol";

```

```solidity
File: script/VerifyBalancerHolding.s.sol

4: import "@forge-std/console.sol";

```

### <a name="NC-5"></a>[NC-5] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

1: 
   Current order:
   external owner
   external paused
   external authVersion
   external poolerAuthVersion
   external incrementAuthVersion
   external pool
   external dispatch
   public poolers
   internal _pooler
   internal _isAuthorized
   internal _countAuthorized
   internal _logPoolers
   external run
   internal _previewModeFromEnv
   
   Suggested order:
   external owner
   external paused
   external authVersion
   external poolerAuthVersion
   external incrementAuthVersion
   external pool
   external dispatch
   external run
   public poolers
   internal _pooler
   internal _isAuthorized
   internal _countAuthorized
   internal _logPoolers
   internal _previewModeFromEnv

```

### <a name="NC-6"></a>[NC-6] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (8)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

40:     function authVersion() external view returns (uint256);

41:     function poolerAuthVersion(address pooler) external view returns (uint256);

44:     function dispatch(address minter, uint256 amount, bytes calldata extraData) external;

65:     function poolers() public pure returns (address[4] memory ps) {

72:     function _pooler() internal pure returns (IBalancerPoolerV2Holding) {

77:     function _isAuthorized(address p) internal view returns (bool) {

81:     function _countAuthorized() internal view returns (uint256 n) {

152:     function _previewModeFromEnv() internal view virtual returns (bool) {

```

### <a name="NC-7"></a>[NC-7] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (1)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

37: interface IBalancerPoolerV2Holding {

```

### <a name="NC-8"></a>[NC-8] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (8)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

42:     function incrementAuthVersion() external;

42:     function incrementAuthVersion() external;

43:     function pool(uint256 minBPT) external;

43:     function pool(uint256 minBPT) external;

44:     function dispatch(address minter, uint256 amount, bytes calldata extraData) external;

44:     function dispatch(address minter, uint256 amount, bytes calldata extraData) external;

100:     function run() external {

100:     function run() external {

```

### <a name="NC-9"></a>[NC-9] `address`s shouldn't be hard-coded
It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (8)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

52:     address public constant BALANCER_POOLER_V2 = 0x7f6874332c4629429d70D15f685A8230323F11F1;

54:     address public constant OWNER = 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6;

56:     address public constant MULTI_POOLER = 0xd1E5774159381915f5579dFd68507E2614f67b51;

57:     address public constant POOLER_7702_EOA = 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F;

58:     address public constant POOLER_EOA = 0x630966B668b321Cc6441754f96519a55F72Cd476;

61:     address public constant NFT_MINTER = 0x39Af088408e815844c567037C157B31d48d2E10F;

62:     address public constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

63:     address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

```

### <a name="NC-10"></a>[NC-10] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

1: 
   Current order:
   FunctionDefinition.owner
   FunctionDefinition.paused
   FunctionDefinition.authVersion
   FunctionDefinition.poolerAuthVersion
   FunctionDefinition.incrementAuthVersion
   FunctionDefinition.pool
   FunctionDefinition.dispatch
   VariableDeclaration.CHAIN_ID
   VariableDeclaration.BALANCER_POOLER_V2
   VariableDeclaration.OWNER
   VariableDeclaration.MULTI_POOLER
   VariableDeclaration.POOLER_7702_EOA
   VariableDeclaration.POOLER_EOA
   VariableDeclaration.NFT_MINTER
   VariableDeclaration.SUSDS
   VariableDeclaration.USDS
   FunctionDefinition.poolers
   FunctionDefinition._pooler
   FunctionDefinition._isAuthorized
   FunctionDefinition._countAuthorized
   FunctionDefinition._logPoolers
   FunctionDefinition.run
   FunctionDefinition._previewModeFromEnv
   
   Suggested order:
   VariableDeclaration.CHAIN_ID
   VariableDeclaration.BALANCER_POOLER_V2
   VariableDeclaration.OWNER
   VariableDeclaration.MULTI_POOLER
   VariableDeclaration.POOLER_7702_EOA
   VariableDeclaration.POOLER_EOA
   VariableDeclaration.NFT_MINTER
   VariableDeclaration.SUSDS
   VariableDeclaration.USDS
   FunctionDefinition.owner
   FunctionDefinition.paused
   FunctionDefinition.authVersion
   FunctionDefinition.poolerAuthVersion
   FunctionDefinition.incrementAuthVersion
   FunctionDefinition.pool
   FunctionDefinition.dispatch
   FunctionDefinition.poolers
   FunctionDefinition._pooler
   FunctionDefinition._isAuthorized
   FunctionDefinition._countAuthorized
   FunctionDefinition._logPoolers
   FunctionDefinition.run
   FunctionDefinition._previewModeFromEnv

```

### <a name="NC-11"></a>[NC-11] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (5)*:
```solidity
File: script/RevokeBalancerPoolersHoldingPattern.s.sol

83:         for (uint256 i = 0; i < 4; i++) {

91:         for (uint256 i = 0; i < 4; i++) {

140:         for (uint256 i = 0; i < 4; i++) {

```

```solidity
File: script/VerifyBalancerHolding.s.sol

24:         for (uint256 i = 0; i < 4; i++) {

27:         for (uint256 i = 0; i < 4; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
### <a name="L-1"></a>[L-1] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: script/VerifyBalancerHolding.s.sol

2: pragma solidity ^0.8.20;

```

