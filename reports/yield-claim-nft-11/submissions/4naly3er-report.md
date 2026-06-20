# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 1 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 6 |
| [GAS-3](#GAS-3) | For Operations that will not overflow, you could use unchecked | 14 |
| [GAS-4](#GAS-4) | Use Custom Errors instead of Revert Strings to save Gas | 6 |
| [GAS-5](#GAS-5) | Stack variable used as a cheaper cache for a state variable is only used once | 4 |
| [GAS-6](#GAS-6) | State variables only set in the constructor should be declared `immutable` | 2 |
| [GAS-7](#GAS-7) | Functions guaranteed to revert when called by normal users can be marked `payable` | 5 |
| [GAS-8](#GAS-8) | Using `private` rather than `public` for constants, saves gas | 2 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (1)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

116:         mintDebt += added;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (6)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

36:         require(batchMinter_ != address(0), "NudgeRatchet: zero batchMinter");

51:         require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

69:         require(dispatcher_ != address(0), "dispatcher=0");

70:         require(phUSD_ != address(0), "phUSD=0");

102:         require(newDispatcher != address(0), "dispatcher=0");

124:         if (recipient == address(0)) revert RecipientUnset();

```

### <a name="GAS-3"></a>[GAS-3] For Operations that will not overflow, you could use unchecked

*Instances (14)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

8: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

38:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

59:     function _dispatch(address, uint256 amount, bytes calldata /* extraData */) internal override {

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

4: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

5: import {INudgeRatchetMintDebtHook} from "../interfaces/INudgeRatchetMintDebtHook.sol";

6: import {IMintable} from "../../interfaces/IMintable.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

114:         uint256 added = (amount * ratio) / 100;

116:         mintDebt += added;

```

### <a name="GAS-4"></a>[GAS-4] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (6)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

36:         require(batchMinter_ != address(0), "NudgeRatchet: zero batchMinter");

38:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

51:         require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

69:         require(dispatcher_ != address(0), "dispatcher=0");

70:         require(phUSD_ != address(0), "phUSD=0");

102:         require(newDispatcher != address(0), "dispatcher=0");

```

### <a name="GAS-5"></a>[GAS-5] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (4)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

52:         address old = batchMinter;

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

82:         uint8 old = ratio;

91:         address old = recipient;

103:         address old = dispatcher;

```

### <a name="GAS-6"></a>[GAS-6] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (2)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

39:         _token = token_;

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

72:         phUSD = IMintable(phUSD_);

```

### <a name="GAS-7"></a>[GAS-7] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (5)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

50:     function setBatchMinter(address newBatchMinter) external onlyOwner {

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

80:     function setRatio(uint8 newRatio) external onlyOwner {

90:     function setRecipient(address newRecipient) external onlyOwner {

101:     function setDispatcher(address newDispatcher) external onlyOwner {

123:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

### <a name="GAS-8"></a>[GAS-8] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

25:     uint8 public constant MAX_RATIO = 200;

28:     uint8 public constant DEFAULT_RATIO = 100;

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 2 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 5 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 1 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 4 |
| [NC-6](#NC-6) | Event missing indexed field | 1 |
| [NC-7](#NC-7) | Events that mark critical parameter changes should contain both the old and the new value | 4 |
| [NC-8](#NC-8) | Functions should not be longer than 50 lines | 8 |
| [NC-9](#NC-9) | Lack of checks in setters | 1 |
| [NC-10](#NC-10) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-11](#NC-11) | Take advantage of Custom Error's return value property | 4 |
| [NC-12](#NC-12) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-13](#NC-13) | Event is missing `indexed` fields | 3 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

39:         _token = token_;

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (2)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

38:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

114:         uint256 added = (amount * ratio) / 100;

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (5)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

81:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

113:         if (msg.sender != dispatcher) revert OnlyDispatcher();

115:         if (added == 0) return;

124:         if (recipient == address(0)) revert RecipientUnset();

126:         if (debt == 0) return;

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

22: contract NudgeRatchetMintDebtHook is IDispatchHook, INudgeRatchetMintDebtHook, Ownable, ReentrancyGuard {

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (4)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

36:         require(batchMinter_ != address(0), "NudgeRatchet: zero batchMinter");

51:         require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

69:         require(dispatcher_ != address(0), "dispatcher=0");

102:         require(newDispatcher != address(0), "dispatcher=0");

```

### <a name="NC-6"></a>[NC-6] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (1)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

47:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

```

### <a name="NC-7"></a>[NC-7] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (4)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

50:     function setBatchMinter(address newBatchMinter) external onlyOwner {
            require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");
            address old = batchMinter;
            batchMinter = newBatchMinter;
            emit BatchMinterUpdated(old, newBatchMinter);

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

80:     function setRatio(uint8 newRatio) external onlyOwner {
            if (newRatio > MAX_RATIO) revert RatioTooHigh();
            uint8 old = ratio;
            ratio = newRatio;
            emit RatioUpdated(old, newRatio);

90:     function setRecipient(address newRecipient) external onlyOwner {
            address old = recipient;
            recipient = newRecipient;
            emit RecipientUpdated(old, newRecipient);

101:     function setDispatcher(address newDispatcher) external onlyOwner {
             require(newDispatcher != address(0), "dispatcher=0");
             address old = dispatcher;
             dispatcher = newDispatcher;
             emit DispatcherUpdated(old, newDispatcher);

```

### <a name="NC-8"></a>[NC-8] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (8)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

44:     function primeToken() external view returns (address) {

50:     function setBatchMinter(address newBatchMinter) external onlyOwner {

59:     function _dispatch(address, uint256 amount, bytes calldata /* extraData */) internal override {

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

80:     function setRatio(uint8 newRatio) external onlyOwner {

90:     function setRecipient(address newRecipient) external onlyOwner {

101:     function setDispatcher(address newDispatcher) external onlyOwner {

112:     function onDispatch(address minter, uint256 amount, bytes calldata) external {

123:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

### <a name="NC-9"></a>[NC-9] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (1)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

90:     function setRecipient(address newRecipient) external onlyOwner {
            address old = recipient;
            recipient = newRecipient;
            emit RecipientUpdated(old, newRecipient);

```

### <a name="NC-10"></a>[NC-10] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

59:         if (msg.sender != owner() && msg.sender != recipient) {

113:         if (msg.sender != dispatcher) revert OnlyDispatcher();

```

### <a name="NC-11"></a>[NC-11] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (4)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

60:             revert OnlyOwnerOrRecipient();

81:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

113:         if (msg.sender != dispatcher) revert OnlyDispatcher();

124:         if (recipient == address(0)) revert RecipientUnset();

```

### <a name="NC-12"></a>[NC-12] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

1: 
   Current order:
   VariableDeclaration.MAX_RATIO
   VariableDeclaration.DEFAULT_RATIO
   VariableDeclaration.dispatcher
   VariableDeclaration.phUSD
   VariableDeclaration.recipient
   VariableDeclaration.mintDebt
   VariableDeclaration.ratio
   EventDefinition.RatioUpdated
   EventDefinition.RecipientUpdated
   EventDefinition.DebtAccrued
   EventDefinition.DebtPulled
   EventDefinition.DispatcherUpdated
   ErrorDefinition.OnlyDispatcher
   ErrorDefinition.OnlyOwnerOrRecipient
   ErrorDefinition.RecipientUnset
   ErrorDefinition.RatioTooHigh
   ModifierDefinition.onlyOwnerOrRecipient
   FunctionDefinition.constructor
   FunctionDefinition.setRatio
   FunctionDefinition.setRecipient
   FunctionDefinition.setDispatcher
   FunctionDefinition.onDispatch
   FunctionDefinition.pull
   
   Suggested order:
   VariableDeclaration.MAX_RATIO
   VariableDeclaration.DEFAULT_RATIO
   VariableDeclaration.dispatcher
   VariableDeclaration.phUSD
   VariableDeclaration.recipient
   VariableDeclaration.mintDebt
   VariableDeclaration.ratio
   ErrorDefinition.OnlyDispatcher
   ErrorDefinition.OnlyOwnerOrRecipient
   ErrorDefinition.RecipientUnset
   ErrorDefinition.RatioTooHigh
   EventDefinition.RatioUpdated
   EventDefinition.RecipientUpdated
   EventDefinition.DebtAccrued
   EventDefinition.DebtPulled
   EventDefinition.DispatcherUpdated
   ModifierDefinition.onlyOwnerOrRecipient
   FunctionDefinition.constructor
   FunctionDefinition.setRatio
   FunctionDefinition.setRecipient
   FunctionDefinition.setDispatcher
   FunctionDefinition.onDispatch
   FunctionDefinition.pull

```

### <a name="NC-13"></a>[NC-13] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (3)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

47:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

49:     event DebtAccrued(address indexed minter, uint256 dispatchedAmount, uint256 debtAdded, uint256 newTotalDebt);

50:     event DebtPulled(address indexed recipient, uint256 amount);

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 2 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 1 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-4](#L-4) | `decimals()` is not a part of the ERC-20 standard | 1 |
| [L-5](#L-5) | Prevent accidentally burning tokens | 1 |
| [L-6](#L-6) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 2 |
| [L-7](#L-7) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

22: contract NudgeRatchetMintDebtHook is IDispatchHook, INudgeRatchetMintDebtHook, Ownable, ReentrancyGuard {

68:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (1)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

60:         IERC20(_token).safeTransfer(batchMinter, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

39:         _token = token_;

```

### <a name="L-4"></a>[L-4] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (1)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

38:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

```

### <a name="L-5"></a>[L-5] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (1)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

117:         emit DebtAccrued(minter, amount, added, mintDebt);

```

### <a name="L-6"></a>[L-6] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (2)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

2: pragma solidity ^0.8.20;

```

### <a name="L-7"></a>[L-7] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
Use [Ownable2Step.transferOwnership](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol) which is safer. Use it as it is more secure due to 2-stage ownership transfer.

**Recommended Mitigation Steps**

Use <a href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol">Ownable2Step.sol</a>
  
  ```solidity
      function acceptOwnership() external {
          address sender = _msgSender();
          require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
          _transferOwnership(sender);
      }
```

*Instances (1)*:
```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 6 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (6)*:
```solidity
File: src/V2/dispatchers/NudgeRatchet.sol

50:     function setBatchMinter(address newBatchMinter) external onlyOwner {

```

```solidity
File: src/V2/hooks/NudgeRatchetMintDebtHook.sol

22: contract NudgeRatchetMintDebtHook is IDispatchHook, INudgeRatchetMintDebtHook, Ownable, ReentrancyGuard {

68:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

80:     function setRatio(uint8 newRatio) external onlyOwner {

90:     function setRecipient(address newRecipient) external onlyOwner {

101:     function setDispatcher(address newDispatcher) external onlyOwner {

```

