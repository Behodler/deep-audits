# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 4 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 18 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 1 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 9 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 5 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 39 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 4 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 2 |
| [GAS-9](#GAS-9) | Stack variable used as a cheaper cache for a state variable is only used once | 7 |
| [GAS-10](#GAS-10) | Functions guaranteed to revert when called by normal users can be marked `payable` | 15 |
| [GAS-11](#GAS-11) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 11 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 10 |
| [GAS-13](#GAS-13) | Use != 0 instead of > 0 for unsigned integer comparison | 11 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (4)*:
```solidity
File: src/StableYieldAccumulator.sol

563:                 totalNormalizedYield += _normalizeAmount(underlyingReceived, token);

643:                 yield += totalBalance - principal;

760:                 totalNormalizedYield += _normalizeAmount(yield, token);

828:             total += _getNormalizedYieldForStrategy(strategy, token);

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (18)*:
```solidity
File: src/StableYieldAccumulator.sol

285:         if (strategy == address(0)) revert ZeroAddress();

286:         if (token == address(0)) revert ZeroAddress();

338:         if (token == address(0)) revert ZeroAddress();

406:         if (_phlimbo == address(0)) revert ZeroAddress();

418:         if (_rewardToken == address(0)) revert ZeroAddress();

427:         if (phlimbo == address(0)) revert ZeroAddress();

428:         if (rewardToken == address(0)) revert ZeroAddress();

471:         if (_streamer == address(0)) revert ZeroAddress();

523:         if (phlimbo == address(0)) revert ZeroAddress();

524:         if (rewardToken == address(0)) revert ZeroAddress();

541:             if (token == address(0)) continue;

580:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

597:             if (streamer == address(0)) revert NudgeStreamerNotConfigured();

615:         require(nftMinter != address(0), "NFT minter not configured");

745:             if (token == address(0)) continue;

784:         if (nftMinter == address(0)) {

810:         if (token == address(0)) return 0;

826:             if (token == address(0)) continue;

```

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

175:     mapping(address => bool) public isRegisteredStrategy;

```

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (9)*:
```solidity
File: src/StableYieldAccumulator.sol

304:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

527:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

538:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

547:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

639:         for (uint256 i = 0; i < clients.length; i++) {

736:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

742:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

750:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

823:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (5)*:
```solidity
File: src/StableYieldAccumulator.sol

583:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

598:             IERC20(rewardToken).forceApprove(streamer, nudgeAmount);

599:             INudgeStreamer(streamer).collectNudge(nudge, rewardToken, nudgeAmount);

619:             INFTMinterV2(nftMinter).burn(caller, index, 1);

790:             if (IERC1155(nftMinter).balanceOf(caller, i) > 0) {

```

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (39)*:
```solidity
File: src/StableYieldAccumulator.sol

4: import "@openzeppelin/contracts/utils/Pausable.sol";

5: import "@openzeppelin/contracts/access/Ownable.sol";

6: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

10: import "pauser/interfaces/IPausable.sol";

11: import "./interfaces/IStableYieldAccumulator.sol";

12: import "vault/interfaces/IYieldStrategy.sol";

13: import "phlimbo-ea/interfaces/IPhlimbo.sol";

14: import "yield-claim-nft/interfaces/INFTMinterV2.sol";

15: import {INudgeStreamer} from "phoenix-nft-staking/INudgeStreamer.sol";

254:                         PAUSE/UNPAUSE FUNCTIONS

304:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

307:                 yieldStrategies[i] = yieldStrategies[yieldStrategies.length - 1];

527:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

538:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

547:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

563:                 totalNormalizedYield += _normalizeAmount(underlyingReceived, token);

564:                 strategiesWithYield++;

571:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

586:         uint256 nudgeAmount = (actualPayment * nudgeSplit) / 100;

587:         uint256 phlimboAmount = actualPayment - nudgeAmount;

639:         for (uint256 i = 0; i < clients.length; i++) {

643:                 yield += totalBalance - principal;

681:             scaled = amount * (10 ** (18 - decimals));

683:             scaled = amount / (10 ** (decimals - 18));

688:             scaled = scaled * exchangeRate / 1e18;

712:             scaled = scaled * 1e18 / exchangeRate;

717:             scaled = scaled / (10 ** (18 - decimals));

719:             scaled = scaled * (10 ** (decimals - 18));

736:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

742:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

750:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

760:                 totalNormalizedYield += _normalizeAmount(yield, token);

767:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

789:         for (uint256 i = 1; i < count; i++) {

823:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

828:             total += _getNormalizedYieldForStrategy(strategy, token);

```

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (4)*:
```solidity
File: src/StableYieldAccumulator.sol

232:         require(msg.sender == pauser, "Only pauser can call this function");

270:         require(msg.sender == owner() || msg.sender == pauser, "Only owner or pauser can unpause");

615:         require(nftMinter != address(0), "NFT minter not configured");

616:         require(index > 0, "Invalid index");

```

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

618:         if (IERC1155(nftMinter).balanceOf(caller, index) > 0) {

790:             if (IERC1155(nftMinter).balanceOf(caller, i) > 0) {

```

### <a name="GAS-9"></a>[GAS-9] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (7)*:
```solidity
File: src/StableYieldAccumulator.sol

248:         address oldPauser = pauser;

384:         uint256 oldRate = discountRate;

408:         address oldPhlimbo = phlimbo;

443:         address oldNudge = nudge;

457:         uint256 oldSplit = nudgeSplit;

473:         address oldStreamer = nudgeStreamer;

489:         address oldNFTMinter = nftMinter;

```

### <a name="GAS-10"></a>[GAS-10] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (15)*:
```solidity
File: src/StableYieldAccumulator.sol

247:     function setPauser(address _pauser) external onlyOwner {

261:     function pause() external override onlyPauser {

284:     function addYieldStrategy(address strategy, address token) external override onlyOwner {

300:     function removeYieldStrategy(address strategy) external override onlyOwner {

337:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {

350:     function pauseToken(address token) external override onlyOwner {

359:     function unpauseToken(address token) external override onlyOwner {

381:     function setDiscountRate(uint256 rate) external override onlyOwner {

405:     function setPhlimbo(address _phlimbo) external onlyOwner {

417:     function setRewardToken(address _rewardToken) external onlyOwner {

426:     function approvePhlimbo(uint256 amount) external onlyOwner {

442:     function setNudgeAddress(address _nudge) external onlyOwner {

454:     function setNudgeSplit(uint256 _split) external onlyOwner {

470:     function setNudgeStreamer(address _streamer) external onlyOwner {

488:     function setNFTMinter(address _nftMinter) external onlyOwner {

```

### <a name="GAS-11"></a>[GAS-11] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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

*Instances (11)*:
```solidity
File: src/StableYieldAccumulator.sol

304:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

527:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

538:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

547:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

564:                 strategiesWithYield++;

639:         for (uint256 i = 0; i < clients.length; i++) {

736:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

742:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

750:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

789:         for (uint256 i = 1; i < count; i++) {

823:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```

### <a name="GAS-12"></a>[GAS-12] Increments/decrements can be unchecked in for-loops
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

*Instances (10)*:
```solidity
File: src/StableYieldAccumulator.sol

304:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

527:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

538:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

547:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

639:         for (uint256 i = 0; i < clients.length; i++) {

736:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

742:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

750:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

789:         for (uint256 i = 1; i < count; i++) {

823:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```

### <a name="GAS-13"></a>[GAS-13] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (11)*:
```solidity
File: src/StableYieldAccumulator.sol

559:             if (underlyingReceived > 0) {

580:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

595:         if (nudgeAmount > 0) {

601:         if (phlimboAmount > 0) {

616:         require(index > 0, "Invalid index");

618:         if (IERC1155(nftMinter).balanceOf(caller, index) > 0) {

657:         if (yield > 0) {

687:         if (exchangeRate > 0 && exchangeRate != 1e18) {

711:         if (exchangeRate > 0 && exchangeRate != 1e18) {

759:             if (yield > 0) {

790:             if (IERC1155(nftMinter).balanceOf(caller, i) > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 12 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 32 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 1 |
| [NC-5](#NC-5) | Event missing indexed field | 2 |
| [NC-6](#NC-6) | Events that mark critical parameter changes should contain both the old and the new value | 8 |
| [NC-7](#NC-7) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-8](#NC-8) | Functions should not be longer than 50 lines | 47 |
| [NC-9](#NC-9) | Lack of checks in setters | 3 |
| [NC-10](#NC-10) | Missing Event for critical parameters change | 1 |
| [NC-11](#NC-11) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-12](#NC-12) | Consider using named mappings | 3 |
| [NC-13](#NC-13) | Owner can renounce while system is paused | 3 |
| [NC-14](#NC-14) | Take advantage of Custom Error's return value property | 23 |
| [NC-15](#NC-15) | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| [NC-16](#NC-16) | Use Underscores for Number Literals (add an underscore every 3 digits) | 3 |
| [NC-17](#NC-17) | Event is missing `indexed` fields | 5 |
| [NC-18](#NC-18) | Constants should be defined rather than using magic numbers | 2 |
| [NC-19](#NC-19) | Variables need not be initialized to zero | 14 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

249:         pauser = _pauser;

444:         nudge = _nudge;

490:         nftMinter = _nftMinter;

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (12)*:
```solidity
File: src/StableYieldAccumulator.sol

339:         if (decimals > 18) revert InvalidDecimals();

382:         if (rate > 10000) revert ExceedsMaxDiscount();

455:         if (_split > 100) revert InvalidNudgeSplit();

571:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

586:         uint256 nudgeAmount = (actualPayment * nudgeSplit) / 100;

680:         if (decimals < 18) {

682:         } else if (decimals > 18) {

683:             scaled = amount / (10 ** (decimals - 18));

716:         if (decimals < 18) {

718:         } else if (decimals > 18) {

719:             scaled = scaled * (10 ** (decimals - 18));

767:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (32)*:
```solidity
File: src/StableYieldAccumulator.sol

224:                             MODIFIERS

285:         if (strategy == address(0)) revert ZeroAddress();

286:         if (token == address(0)) revert ZeroAddress();

287:         if (isRegisteredStrategy[strategy]) revert StrategyAlreadyRegistered();

301:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

338:         if (token == address(0)) revert ZeroAddress();

339:         if (decimals > 18) revert InvalidDecimals();

382:         if (rate > 10000) revert ExceedsMaxDiscount();

406:         if (_phlimbo == address(0)) revert ZeroAddress();

418:         if (_rewardToken == address(0)) revert ZeroAddress();

427:         if (phlimbo == address(0)) revert ZeroAddress();

428:         if (rewardToken == address(0)) revert ZeroAddress();

455:         if (_split > 100) revert InvalidNudgeSplit();

471:         if (_streamer == address(0)) revert ZeroAddress();

523:         if (phlimbo == address(0)) revert ZeroAddress();

524:         if (rewardToken == address(0)) revert ZeroAddress();

528:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

541:             if (token == address(0)) continue;

543:             if (tokenConfigs[token].paused) continue;

553:             if (exempt) continue;

568:         if (totalNormalizedYield == 0) revert ZeroAmount();

575:         if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();

580:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

597:             if (streamer == address(0)) revert NudgeStreamerNotConfigured();

737:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

745:             if (token == address(0)) continue;

746:             if (tokenConfigs[token].paused) continue;

756:             if (exempt) continue;

764:         if (totalNormalizedYield == 0) return 0;

807:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

810:         if (token == address(0)) return 0;

826:             if (token == address(0)) continue;

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

103: contract StableYieldAccumulator is Ownable, Pausable, ReentrancyGuard, IPausable, IStableYieldAccumulator {

```

### <a name="NC-5"></a>[NC-5] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (2)*:
```solidity
File: src/interfaces/IStableYieldAccumulator.sol

67:     event DiscountRateSet(uint256 oldRate, uint256 newRate);

88:     event NudgeSplitUpdated(uint256 oldSplit, uint256 newSplit);

```

### <a name="NC-6"></a>[NC-6] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (8)*:
```solidity
File: src/StableYieldAccumulator.sol

247:     function setPauser(address _pauser) external onlyOwner {
             address oldPauser = pauser;
             pauser = _pauser;
             emit PauserUpdated(oldPauser, _pauser);

337:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {
             if (token == address(0)) revert ZeroAddress();
             if (decimals > 18) revert InvalidDecimals();
     
             tokenConfigs[token].decimals = decimals;
             tokenConfigs[token].normalizedExchangeRate = normalizedExchangeRate;
             emit TokenConfigSet(token, decimals, normalizedExchangeRate);

381:     function setDiscountRate(uint256 rate) external override onlyOwner {
             if (rate > 10000) revert ExceedsMaxDiscount();
     
             uint256 oldRate = discountRate;
             discountRate = rate;
             emit DiscountRateSet(oldRate, rate);

405:     function setPhlimbo(address _phlimbo) external onlyOwner {
             if (_phlimbo == address(0)) revert ZeroAddress();
     
             address oldPhlimbo = phlimbo;
             phlimbo = _phlimbo;
             emit PhlimboUpdated(oldPhlimbo, _phlimbo);

442:     function setNudgeAddress(address _nudge) external onlyOwner {
             address oldNudge = nudge;
             nudge = _nudge;
             emit NudgeUpdated(oldNudge, _nudge);

454:     function setNudgeSplit(uint256 _split) external onlyOwner {
             if (_split > 100) revert InvalidNudgeSplit();
     
             uint256 oldSplit = nudgeSplit;
             nudgeSplit = _split;
             emit NudgeSplitUpdated(oldSplit, _split);

470:     function setNudgeStreamer(address _streamer) external onlyOwner {
             if (_streamer == address(0)) revert ZeroAddress();
     
             address oldStreamer = nudgeStreamer;
             nudgeStreamer = _streamer;
             emit NudgeStreamerUpdated(oldStreamer, _streamer);

488:     function setNFTMinter(address _nftMinter) external onlyOwner {
             address oldNFTMinter = nftMinter;
             nftMinter = _nftMinter;
             emit NFTMinterUpdated(oldNFTMinter, _nftMinter);

```

### <a name="NC-7"></a>[NC-7] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

1: 
   Current order:
   external setPauser
   external pause
   external unpause
   external addYieldStrategy
   external removeYieldStrategy
   external getYieldStrategies
   external setTokenConfig
   external pauseToken
   external unpauseToken
   external getTokenConfig
   external setDiscountRate
   external getDiscountRate
   external setPhlimbo
   external setRewardToken
   external approvePhlimbo
   external setNudgeAddress
   external setNudgeSplit
   external setNudgeStreamer
   external setNFTMinter
   external claim
   internal _validateAndBurnNFT
   internal _getYieldForStrategy
   internal _getNormalizedYieldForStrategy
   internal _normalizeAmount
   internal _denormalizeAmount
   external calculateClaimAmount
   external canClaim
   external getYield
   external getTotalYield
   
   Suggested order:
   external setPauser
   external pause
   external unpause
   external addYieldStrategy
   external removeYieldStrategy
   external getYieldStrategies
   external setTokenConfig
   external pauseToken
   external unpauseToken
   external getTokenConfig
   external setDiscountRate
   external getDiscountRate
   external setPhlimbo
   external setRewardToken
   external approvePhlimbo
   external setNudgeAddress
   external setNudgeSplit
   external setNudgeStreamer
   external setNFTMinter
   external claim
   external calculateClaimAmount
   external canClaim
   external getYield
   external getTotalYield
   internal _validateAndBurnNFT
   internal _getYieldForStrategy
   internal _getNormalizedYieldForStrategy
   internal _normalizeAmount
   internal _denormalizeAmount

```

### <a name="NC-8"></a>[NC-8] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (47)*:
```solidity
File: src/StableYieldAccumulator.sol

247:     function setPauser(address _pauser) external onlyOwner {

284:     function addYieldStrategy(address strategy, address token) external override onlyOwner {

300:     function removeYieldStrategy(address strategy) external override onlyOwner {

322:     function getYieldStrategies() external view override returns (address[] memory) {

337:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {

350:     function pauseToken(address token) external override onlyOwner {

359:     function unpauseToken(address token) external override onlyOwner {

369:     function getTokenConfig(address token) external view override returns (TokenConfig memory) {

381:     function setDiscountRate(uint256 rate) external override onlyOwner {

393:     function getDiscountRate() external view override returns (uint256) {

405:     function setPhlimbo(address _phlimbo) external onlyOwner {

417:     function setRewardToken(address _rewardToken) external onlyOwner {

426:     function approvePhlimbo(uint256 amount) external onlyOwner {

442:     function setNudgeAddress(address _nudge) external onlyOwner {

454:     function setNudgeSplit(uint256 _split) external onlyOwner {

470:     function setNudgeStreamer(address _streamer) external onlyOwner {

488:     function setNFTMinter(address _nftMinter) external onlyOwner {

517:     function claim(uint256 nftIndex, uint256 minRewardTokenSupplied, address[] calldata exemptStrategies)

614:     function _validateAndBurnNFT(address caller, uint256 index) internal {

635:     function _getYieldForStrategy(address strategy, address token) internal view returns (uint256) {

655:     function _getNormalizedYieldForStrategy(address strategy, address token) internal view returns (uint256) {

669:     function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {

700:     function _denormalizeAmount(uint256 amount, address token) internal view returns (uint256) {

734:     function calculateClaimAmount(address[] calldata exemptStrategies) external view override returns (uint256) {

783:     function canClaim(address caller) external view returns (bool) {

806:     function getYield(address strategy) external view override returns (uint256) {

821:     function getTotalYield() external view override returns (uint256) {

```

```solidity
File: src/interfaces/IStableYieldAccumulator.sol

200:     function addYieldStrategy(address strategy, address token) external;

206:     function removeYieldStrategy(address strategy) external;

212:     function getYieldStrategies() external view returns (address[] memory);

219:     function strategyTokens(address strategy) external view returns (address);

231:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external;

250:     function getTokenConfig(address token) external view returns (TokenConfig memory);

266:     function getDiscountRate() external view returns (uint256);

282:     function phlimbo() external view returns (address);

294:     function setNudgeAddress(address _nudge) external;

315:     function setNudgeStreamer(address _streamer) external;

327:     function nudgeSplit() external view returns (uint256);

333:     function nudgeStreamer() external view returns (address);

343:     function rewardToken() external view returns (address);

368:     function claim(uint256 nftIndex, uint256 minRewardTokenSupplied, address[] calldata exemptStrategies) external;

381:     function calculateClaimAmount(address[] calldata exemptStrategies) external view returns (uint256);

393:     function getYield(address strategy) external view returns (uint256);

400:     function getTotalYield() external view returns (uint256);

410:     function setNFTMinter(address _nftMinter) external;

416:     function nftMinter() external view returns (address);

428:     function canClaim(address caller) external view returns (bool);

```

### <a name="NC-9"></a>[NC-9] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

247:     function setPauser(address _pauser) external onlyOwner {
             address oldPauser = pauser;
             pauser = _pauser;
             emit PauserUpdated(oldPauser, _pauser);

442:     function setNudgeAddress(address _nudge) external onlyOwner {
             address oldNudge = nudge;
             nudge = _nudge;
             emit NudgeUpdated(oldNudge, _nudge);

488:     function setNFTMinter(address _nftMinter) external onlyOwner {
             address oldNFTMinter = nftMinter;
             nftMinter = _nftMinter;
             emit NFTMinterUpdated(oldNFTMinter, _nftMinter);

```

### <a name="NC-10"></a>[NC-10] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

417:     function setRewardToken(address _rewardToken) external onlyOwner {
             if (_rewardToken == address(0)) revert ZeroAddress();
             rewardToken = _rewardToken;

```

### <a name="NC-11"></a>[NC-11] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

232:         require(msg.sender == pauser, "Only pauser can call this function");

270:         require(msg.sender == owner() || msg.sender == pauser, "Only owner or pauser can unpause");

```

### <a name="NC-12"></a>[NC-12] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

134:     mapping(address => TokenConfig) public tokenConfigs;

175:     mapping(address => bool) public isRegisteredStrategy;

181:     mapping(address => address) public strategyTokens;

```

### <a name="NC-13"></a>[NC-13] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

247:     function setPauser(address _pauser) external onlyOwner {

350:     function pauseToken(address token) external override onlyOwner {

359:     function unpauseToken(address token) external override onlyOwner {

```

### <a name="NC-14"></a>[NC-14] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (23)*:
```solidity
File: src/StableYieldAccumulator.sol

285:         if (strategy == address(0)) revert ZeroAddress();

286:         if (token == address(0)) revert ZeroAddress();

287:         if (isRegisteredStrategy[strategy]) revert StrategyAlreadyRegistered();

301:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

338:         if (token == address(0)) revert ZeroAddress();

339:         if (decimals > 18) revert InvalidDecimals();

382:         if (rate > 10000) revert ExceedsMaxDiscount();

406:         if (_phlimbo == address(0)) revert ZeroAddress();

418:         if (_rewardToken == address(0)) revert ZeroAddress();

427:         if (phlimbo == address(0)) revert ZeroAddress();

428:         if (rewardToken == address(0)) revert ZeroAddress();

455:         if (_split > 100) revert InvalidNudgeSplit();

471:         if (_streamer == address(0)) revert ZeroAddress();

523:         if (phlimbo == address(0)) revert ZeroAddress();

524:         if (rewardToken == address(0)) revert ZeroAddress();

528:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

568:         if (totalNormalizedYield == 0) revert ZeroAmount();

575:         if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();

580:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

597:             if (streamer == address(0)) revert NudgeStreamerNotConfigured();

621:             revert NoValidNFT();

737:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

807:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

```

### <a name="NC-15"></a>[NC-15] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

1: 
   Current order:
   UsingForDirective.IERC20
   VariableDeclaration.pauser
   VariableDeclaration.rewardToken
   VariableDeclaration.yieldStrategies
   VariableDeclaration.tokenConfigs
   VariableDeclaration.discountRate
   VariableDeclaration.phlimbo
   VariableDeclaration.nudge
   VariableDeclaration.nudgeSplit
   VariableDeclaration.nudgeStreamer
   VariableDeclaration.isRegisteredStrategy
   VariableDeclaration.strategyTokens
   VariableDeclaration.nftMinter
   EventDefinition.PauserUpdated
   EventDefinition.NFTMinterUpdated
   FunctionDefinition.constructor
   ModifierDefinition.onlyPauser
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.addYieldStrategy
   FunctionDefinition.removeYieldStrategy
   FunctionDefinition.getYieldStrategies
   FunctionDefinition.setTokenConfig
   FunctionDefinition.pauseToken
   FunctionDefinition.unpauseToken
   FunctionDefinition.getTokenConfig
   FunctionDefinition.setDiscountRate
   FunctionDefinition.getDiscountRate
   FunctionDefinition.setPhlimbo
   FunctionDefinition.setRewardToken
   FunctionDefinition.approvePhlimbo
   FunctionDefinition.setNudgeAddress
   FunctionDefinition.setNudgeSplit
   FunctionDefinition.setNudgeStreamer
   FunctionDefinition.setNFTMinter
   FunctionDefinition.claim
   FunctionDefinition._validateAndBurnNFT
   FunctionDefinition._getYieldForStrategy
   FunctionDefinition._getNormalizedYieldForStrategy
   FunctionDefinition._normalizeAmount
   FunctionDefinition._denormalizeAmount
   FunctionDefinition.calculateClaimAmount
   FunctionDefinition.canClaim
   FunctionDefinition.getYield
   FunctionDefinition.getTotalYield
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.pauser
   VariableDeclaration.rewardToken
   VariableDeclaration.yieldStrategies
   VariableDeclaration.tokenConfigs
   VariableDeclaration.discountRate
   VariableDeclaration.phlimbo
   VariableDeclaration.nudge
   VariableDeclaration.nudgeSplit
   VariableDeclaration.nudgeStreamer
   VariableDeclaration.isRegisteredStrategy
   VariableDeclaration.strategyTokens
   VariableDeclaration.nftMinter
   EventDefinition.PauserUpdated
   EventDefinition.NFTMinterUpdated
   ModifierDefinition.onlyPauser
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.addYieldStrategy
   FunctionDefinition.removeYieldStrategy
   FunctionDefinition.getYieldStrategies
   FunctionDefinition.setTokenConfig
   FunctionDefinition.pauseToken
   FunctionDefinition.unpauseToken
   FunctionDefinition.getTokenConfig
   FunctionDefinition.setDiscountRate
   FunctionDefinition.getDiscountRate
   FunctionDefinition.setPhlimbo
   FunctionDefinition.setRewardToken
   FunctionDefinition.approvePhlimbo
   FunctionDefinition.setNudgeAddress
   FunctionDefinition.setNudgeSplit
   FunctionDefinition.setNudgeStreamer
   FunctionDefinition.setNFTMinter
   FunctionDefinition.claim
   FunctionDefinition._validateAndBurnNFT
   FunctionDefinition._getYieldForStrategy
   FunctionDefinition._getNormalizedYieldForStrategy
   FunctionDefinition._normalizeAmount
   FunctionDefinition._denormalizeAmount
   FunctionDefinition.calculateClaimAmount
   FunctionDefinition.canClaim
   FunctionDefinition.getYield
   FunctionDefinition.getTotalYield

```

```solidity
File: src/interfaces/IStableYieldAccumulator.sol

1: 
   Current order:
   StructDefinition.TokenConfig
   EventDefinition.YieldStrategyAdded
   EventDefinition.YieldStrategyRemoved
   EventDefinition.TokenConfigSet
   EventDefinition.TokenPaused
   EventDefinition.TokenUnpaused
   EventDefinition.DiscountRateSet
   EventDefinition.PhlimboUpdated
   EventDefinition.NudgeUpdated
   EventDefinition.NudgeSplitUpdated
   EventDefinition.NudgeStreamerUpdated
   EventDefinition.RewardsClaimed
   EventDefinition.RewardsCollected
   ErrorDefinition.NotImplemented
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidDecimals
   ErrorDefinition.ExceedsMaxDiscount
   ErrorDefinition.StrategyNotRegistered
   ErrorDefinition.StrategyAlreadyRegistered
   ErrorDefinition.ExemptStrategyNotRegistered
   ErrorDefinition.InsufficientPending
   ErrorDefinition.ZeroAmount
   ErrorDefinition.NoValidNFT
   ErrorDefinition.InsufficientYield
   ErrorDefinition.InvalidNudgeSplit
   ErrorDefinition.NudgeNotConfigured
   ErrorDefinition.NudgeStreamerNotConfigured
   FunctionDefinition.addYieldStrategy
   FunctionDefinition.removeYieldStrategy
   FunctionDefinition.getYieldStrategies
   FunctionDefinition.strategyTokens
   FunctionDefinition.setTokenConfig
   FunctionDefinition.pauseToken
   FunctionDefinition.unpauseToken
   FunctionDefinition.getTokenConfig
   FunctionDefinition.setDiscountRate
   FunctionDefinition.getDiscountRate
   FunctionDefinition.setPhlimbo
   FunctionDefinition.phlimbo
   FunctionDefinition.setNudgeAddress
   FunctionDefinition.setNudgeSplit
   FunctionDefinition.setNudgeStreamer
   FunctionDefinition.nudge
   FunctionDefinition.nudgeSplit
   FunctionDefinition.nudgeStreamer
   FunctionDefinition.rewardToken
   FunctionDefinition.claim
   FunctionDefinition.calculateClaimAmount
   FunctionDefinition.getYield
   FunctionDefinition.getTotalYield
   FunctionDefinition.setNFTMinter
   FunctionDefinition.nftMinter
   FunctionDefinition.canClaim
   
   Suggested order:
   StructDefinition.TokenConfig
   ErrorDefinition.NotImplemented
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidDecimals
   ErrorDefinition.ExceedsMaxDiscount
   ErrorDefinition.StrategyNotRegistered
   ErrorDefinition.StrategyAlreadyRegistered
   ErrorDefinition.ExemptStrategyNotRegistered
   ErrorDefinition.InsufficientPending
   ErrorDefinition.ZeroAmount
   ErrorDefinition.NoValidNFT
   ErrorDefinition.InsufficientYield
   ErrorDefinition.InvalidNudgeSplit
   ErrorDefinition.NudgeNotConfigured
   ErrorDefinition.NudgeStreamerNotConfigured
   EventDefinition.YieldStrategyAdded
   EventDefinition.YieldStrategyRemoved
   EventDefinition.TokenConfigSet
   EventDefinition.TokenPaused
   EventDefinition.TokenUnpaused
   EventDefinition.DiscountRateSet
   EventDefinition.PhlimboUpdated
   EventDefinition.NudgeUpdated
   EventDefinition.NudgeSplitUpdated
   EventDefinition.NudgeStreamerUpdated
   EventDefinition.RewardsClaimed
   EventDefinition.RewardsCollected
   FunctionDefinition.addYieldStrategy
   FunctionDefinition.removeYieldStrategy
   FunctionDefinition.getYieldStrategies
   FunctionDefinition.strategyTokens
   FunctionDefinition.setTokenConfig
   FunctionDefinition.pauseToken
   FunctionDefinition.unpauseToken
   FunctionDefinition.getTokenConfig
   FunctionDefinition.setDiscountRate
   FunctionDefinition.getDiscountRate
   FunctionDefinition.setPhlimbo
   FunctionDefinition.phlimbo
   FunctionDefinition.setNudgeAddress
   FunctionDefinition.setNudgeSplit
   FunctionDefinition.setNudgeStreamer
   FunctionDefinition.nudge
   FunctionDefinition.nudgeSplit
   FunctionDefinition.nudgeStreamer
   FunctionDefinition.rewardToken
   FunctionDefinition.claim
   FunctionDefinition.calculateClaimAmount
   FunctionDefinition.getYield
   FunctionDefinition.getTotalYield
   FunctionDefinition.setNFTMinter
   FunctionDefinition.nftMinter
   FunctionDefinition.canClaim

```

### <a name="NC-16"></a>[NC-16] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

382:         if (rate > 10000) revert ExceedsMaxDiscount();

571:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

767:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

```

### <a name="NC-17"></a>[NC-17] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (5)*:
```solidity
File: src/interfaces/IStableYieldAccumulator.sol

48:     event TokenConfigSet(address indexed token, uint8 decimals, uint256 normalizedExchangeRate);

67:     event DiscountRateSet(uint256 oldRate, uint256 newRate);

88:     event NudgeSplitUpdated(uint256 oldSplit, uint256 newSplit);

103:     event RewardsClaimed(address indexed claimer, uint256 amountPaid, uint256 strategiesClaimed);

110:     event RewardsCollected(address indexed strategy, uint256 amount);

```

### <a name="NC-18"></a>[NC-18] Constants should be defined rather than using magic numbers

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

681:             scaled = amount * (10 ** (18 - decimals));

717:             scaled = scaled / (10 ** (18 - decimals));

```

### <a name="NC-19"></a>[NC-19] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (14)*:
```solidity
File: src/StableYieldAccumulator.sol

304:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

527:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

534:         uint256 totalNormalizedYield = 0;

535:         uint256 strategiesWithYield = 0;

538:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

547:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

638:         uint256 yield = 0;

639:         for (uint256 i = 0; i < clients.length; i++) {

736:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

740:         uint256 totalNormalizedYield = 0;

742:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

750:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

822:         uint256 total = 0;

823:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 1 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 1 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| [L-4](#L-4) | Division by zero not prevented | 3 |
| [L-5](#L-5) | Owner can renounce while system is paused | 3 |
| [L-6](#L-6) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
| [L-7](#L-7) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

103: contract StableYieldAccumulator is Ownable, Pausable, ReentrancyGuard, IPausable, IStableYieldAccumulator {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

583:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

249:         pauser = _pauser;

444:         nudge = _nudge;

490:         nftMinter = _nftMinter;

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

683:             scaled = amount / (10 ** (decimals - 18));

712:             scaled = scaled * 1e18 / exchangeRate;

717:             scaled = scaled / (10 ** (18 - decimals));

```

### <a name="L-5"></a>[L-5] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

247:     function setPauser(address _pauser) external onlyOwner {

350:     function pauseToken(address token) external override onlyOwner {

359:     function unpauseToken(address token) external override onlyOwner {

```

### <a name="L-6"></a>[L-6] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

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
File: src/StableYieldAccumulator.sol

5: import "@openzeppelin/contracts/access/Ownable.sol";

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 16 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

583:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (16)*:
```solidity
File: src/StableYieldAccumulator.sol

103: contract StableYieldAccumulator is Ownable, Pausable, ReentrancyGuard, IPausable, IStableYieldAccumulator {

219:     constructor() Ownable(msg.sender) {

247:     function setPauser(address _pauser) external onlyOwner {

284:     function addYieldStrategy(address strategy, address token) external override onlyOwner {

300:     function removeYieldStrategy(address strategy) external override onlyOwner {

337:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {

350:     function pauseToken(address token) external override onlyOwner {

359:     function unpauseToken(address token) external override onlyOwner {

381:     function setDiscountRate(uint256 rate) external override onlyOwner {

405:     function setPhlimbo(address _phlimbo) external onlyOwner {

417:     function setRewardToken(address _rewardToken) external onlyOwner {

426:     function approvePhlimbo(uint256 amount) external onlyOwner {

442:     function setNudgeAddress(address _nudge) external onlyOwner {

454:     function setNudgeSplit(uint256 _split) external onlyOwner {

470:     function setNudgeStreamer(address _streamer) external onlyOwner {

488:     function setNFTMinter(address _nftMinter) external onlyOwner {

```

