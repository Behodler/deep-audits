# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 4 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 16 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 1 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 9 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 4 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 38 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 4 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 2 |
| [GAS-9](#GAS-9) | Stack variable used as a cheaper cache for a state variable is only used once | 6 |
| [GAS-10](#GAS-10) | Functions guaranteed to revert when called by normal users can be marked `payable` | 14 |
| [GAS-11](#GAS-11) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 11 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 10 |
| [GAS-13](#GAS-13) | Use != 0 instead of > 0 for unsigned integer comparison | 11 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (4)*:
```solidity
File: src/StableYieldAccumulator.sol

489:                 totalNormalizedYield += _normalizeAmount(underlyingReceived, token);

560:                 yield += totalBalance - principal;

677:                 totalNormalizedYield += _normalizeAmount(yield, token);

745:             total += _getNormalizedYieldForStrategy(strategy, token);

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (16)*:
```solidity
File: src/StableYieldAccumulator.sol

228:         if (strategy == address(0)) revert ZeroAddress();

229:         if (token == address(0)) revert ZeroAddress();

281:         if (token == address(0)) revert ZeroAddress();

349:         if (_phlimbo == address(0)) revert ZeroAddress();

361:         if (_rewardToken == address(0)) revert ZeroAddress();

370:         if (phlimbo == address(0)) revert ZeroAddress();

371:         if (rewardToken == address(0)) revert ZeroAddress();

449:         if (phlimbo == address(0)) revert ZeroAddress();

450:         if (rewardToken == address(0)) revert ZeroAddress();

467:             if (token == address(0)) continue;

506:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

532:         require(nftMinter != address(0), "NFT minter not configured");

662:             if (token == address(0)) continue;

701:         if (nftMinter == address(0)) {

727:         if (token == address(0)) return 0;

743:             if (token == address(0)) continue;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

118:     mapping(address => bool) public isRegisteredStrategy;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (9)*:
```solidity
File: src/StableYieldAccumulator.sol

247:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

453:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

464:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

473:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

556:         for (uint256 i = 0; i < clients.length; i++) {

653:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

659:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

667:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

740:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (4)*:
```solidity
File: src/StableYieldAccumulator.sol

509:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

516:             IERC20(rewardToken).safeTransfer(nudge, nudgeAmount);

536:             INFTMinter(nftMinter).burn(caller, index, 1);

707:             if (IERC1155(nftMinter).balanceOf(caller, i) > 0) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (38)*:
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

14: import "yield-claim-nft/interfaces/INFTMinter.sol";

197:                         PAUSE/UNPAUSE FUNCTIONS

247:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

250:                 yieldStrategies[i] = yieldStrategies[yieldStrategies.length - 1];

453:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

464:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

473:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

489:                 totalNormalizedYield += _normalizeAmount(underlyingReceived, token);

490:                 strategiesWithYield++;

497:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

512:         uint256 nudgeAmount = (actualPayment * nudgeSplit) / 100;

513:         uint256 phlimboAmount = actualPayment - nudgeAmount;

556:         for (uint256 i = 0; i < clients.length; i++) {

560:                 yield += totalBalance - principal;

598:             scaled = amount * (10 ** (18 - decimals));

600:             scaled = amount / (10 ** (decimals - 18));

605:             scaled = scaled * exchangeRate / 1e18;

629:             scaled = scaled * 1e18 / exchangeRate;

634:             scaled = scaled / (10 ** (18 - decimals));

636:             scaled = scaled * (10 ** (decimals - 18));

653:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

659:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

667:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

677:                 totalNormalizedYield += _normalizeAmount(yield, token);

684:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

706:         for (uint256 i = 1; i < count; i++) {

740:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

745:             total += _getNormalizedYieldForStrategy(strategy, token);

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (4)*:
```solidity
File: src/StableYieldAccumulator.sol

175:         require(msg.sender == pauser, "Only pauser can call this function");

213:         require(msg.sender == owner() || msg.sender == pauser, "Only owner or pauser can unpause");

532:         require(nftMinter != address(0), "NFT minter not configured");

533:         require(index > 0, "Invalid index");

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

535:         if (IERC1155(nftMinter).balanceOf(caller, index) > 0) {

707:             if (IERC1155(nftMinter).balanceOf(caller, i) > 0) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-9"></a>[GAS-9] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (6)*:
```solidity
File: src/StableYieldAccumulator.sol

191:         address oldPauser = pauser;

327:         uint256 oldRate = discountRate;

351:         address oldPhlimbo = phlimbo;

386:         address oldNudge = nudge;

399:         uint256 oldSplit = nudgeSplit;

415:         address oldNFTMinter = nftMinter;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-10"></a>[GAS-10] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (14)*:
```solidity
File: src/StableYieldAccumulator.sol

190:     function setPauser(address _pauser) external onlyOwner {

204:     function pause() external override onlyPauser {

227:     function addYieldStrategy(address strategy, address token) external override onlyOwner {

243:     function removeYieldStrategy(address strategy) external override onlyOwner {

280:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {

293:     function pauseToken(address token) external override onlyOwner {

302:     function unpauseToken(address token) external override onlyOwner {

324:     function setDiscountRate(uint256 rate) external override onlyOwner {

348:     function setPhlimbo(address _phlimbo) external onlyOwner {

360:     function setRewardToken(address _rewardToken) external onlyOwner {

369:     function approvePhlimbo(uint256 amount) external onlyOwner {

385:     function setNudgeAddress(address _nudge) external onlyOwner {

396:     function setNudgeSplit(uint256 _split) external onlyOwner {

414:     function setNFTMinter(address _nftMinter) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

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

247:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

453:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

464:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

473:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

490:                 strategiesWithYield++;

556:         for (uint256 i = 0; i < clients.length; i++) {

653:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

659:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

667:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

706:         for (uint256 i = 1; i < count; i++) {

740:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

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

247:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

453:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

464:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

473:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

556:         for (uint256 i = 0; i < clients.length; i++) {

653:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

659:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

667:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

706:         for (uint256 i = 1; i < count; i++) {

740:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="GAS-13"></a>[GAS-13] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (11)*:
```solidity
File: src/StableYieldAccumulator.sol

485:             if (underlyingReceived > 0) {

506:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

515:         if (nudgeAmount > 0) {

518:         if (phlimboAmount > 0) {

533:         require(index > 0, "Invalid index");

535:         if (IERC1155(nftMinter).balanceOf(caller, index) > 0) {

574:         if (yield > 0) {

604:         if (exchangeRate > 0 && exchangeRate != 1e18) {

628:         if (exchangeRate > 0 && exchangeRate != 1e18) {

676:             if (yield > 0) {

707:             if (IERC1155(nftMinter).balanceOf(caller, i) > 0) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 12 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 30 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 1 |
| [NC-5](#NC-5) | Events that mark critical parameter changes should contain both the old and the new value | 7 |
| [NC-6](#NC-6) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-7](#NC-7) | Functions should not be longer than 50 lines | 26 |
| [NC-8](#NC-8) | Lack of checks in setters | 3 |
| [NC-9](#NC-9) | Missing Event for critical parameters change | 1 |
| [NC-10](#NC-10) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-11](#NC-11) | Consider using named mappings | 3 |
| [NC-12](#NC-12) | Owner can renounce while system is paused | 3 |
| [NC-13](#NC-13) | Take advantage of Custom Error's return value property | 21 |
| [NC-14](#NC-14) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-15](#NC-15) | Use Underscores for Number Literals (add an underscore every 3 digits) | 3 |
| [NC-16](#NC-16) | Constants should be defined rather than using magic numbers | 2 |
| [NC-17](#NC-17) | Variables need not be initialized to zero | 14 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

192:         pauser = _pauser;

387:         nudge = _nudge;

416:         nftMinter = _nftMinter;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (12)*:
```solidity
File: src/StableYieldAccumulator.sol

282:         if (decimals > 18) revert InvalidDecimals();

325:         if (rate > 10000) revert ExceedsMaxDiscount();

397:         if (_split > 100) revert InvalidNudgeSplit();

497:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

512:         uint256 nudgeAmount = (actualPayment * nudgeSplit) / 100;

597:         if (decimals < 18) {

599:         } else if (decimals > 18) {

600:             scaled = amount / (10 ** (decimals - 18));

633:         if (decimals < 18) {

635:         } else if (decimals > 18) {

636:             scaled = scaled * (10 ** (decimals - 18));

684:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (30)*:
```solidity
File: src/StableYieldAccumulator.sol

167:                             MODIFIERS

228:         if (strategy == address(0)) revert ZeroAddress();

229:         if (token == address(0)) revert ZeroAddress();

230:         if (isRegisteredStrategy[strategy]) revert StrategyAlreadyRegistered();

244:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

281:         if (token == address(0)) revert ZeroAddress();

282:         if (decimals > 18) revert InvalidDecimals();

325:         if (rate > 10000) revert ExceedsMaxDiscount();

349:         if (_phlimbo == address(0)) revert ZeroAddress();

361:         if (_rewardToken == address(0)) revert ZeroAddress();

370:         if (phlimbo == address(0)) revert ZeroAddress();

371:         if (rewardToken == address(0)) revert ZeroAddress();

397:         if (_split > 100) revert InvalidNudgeSplit();

449:         if (phlimbo == address(0)) revert ZeroAddress();

450:         if (rewardToken == address(0)) revert ZeroAddress();

454:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

467:             if (token == address(0)) continue;

469:             if (tokenConfigs[token].paused) continue;

479:             if (exempt) continue;

494:         if (totalNormalizedYield == 0) revert ZeroAmount();

501:         if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();

506:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

654:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

662:             if (token == address(0)) continue;

663:             if (tokenConfigs[token].paused) continue;

673:             if (exempt) continue;

681:         if (totalNormalizedYield == 0) return 0;

724:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

727:         if (token == address(0)) return 0;

743:             if (token == address(0)) continue;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

57: contract StableYieldAccumulator is Ownable, Pausable, ReentrancyGuard, IPausable, IStableYieldAccumulator {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-5"></a>[NC-5] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (7)*:
```solidity
File: src/StableYieldAccumulator.sol

190:     function setPauser(address _pauser) external onlyOwner {
             address oldPauser = pauser;
             pauser = _pauser;
             emit PauserUpdated(oldPauser, _pauser);

280:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {
             if (token == address(0)) revert ZeroAddress();
             if (decimals > 18) revert InvalidDecimals();
     
             tokenConfigs[token].decimals = decimals;
             tokenConfigs[token].normalizedExchangeRate = normalizedExchangeRate;
             emit TokenConfigSet(token, decimals, normalizedExchangeRate);

324:     function setDiscountRate(uint256 rate) external override onlyOwner {
             if (rate > 10000) revert ExceedsMaxDiscount();
     
             uint256 oldRate = discountRate;
             discountRate = rate;
             emit DiscountRateSet(oldRate, rate);

348:     function setPhlimbo(address _phlimbo) external onlyOwner {
             if (_phlimbo == address(0)) revert ZeroAddress();
     
             address oldPhlimbo = phlimbo;
             phlimbo = _phlimbo;
             emit PhlimboUpdated(oldPhlimbo, _phlimbo);

385:     function setNudgeAddress(address _nudge) external onlyOwner {
             address oldNudge = nudge;
             nudge = _nudge;
             emit NudgeUpdated(oldNudge, _nudge);

396:     function setNudgeSplit(uint256 _split) external onlyOwner {
             if (_split > 100) revert InvalidNudgeSplit();
     
             uint256 oldSplit = nudgeSplit;
             nudgeSplit = _split;
             emit NudgeSplitUpdated(oldSplit, _split);

414:     function setNFTMinter(address _nftMinter) external onlyOwner {
             address oldNFTMinter = nftMinter;
             nftMinter = _nftMinter;
             emit NFTMinterUpdated(oldNFTMinter, _nftMinter);

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-6"></a>[NC-6] Function ordering does not follow the Solidity style guide
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
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-7"></a>[NC-7] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (26)*:
```solidity
File: src/StableYieldAccumulator.sol

190:     function setPauser(address _pauser) external onlyOwner {

227:     function addYieldStrategy(address strategy, address token) external override onlyOwner {

243:     function removeYieldStrategy(address strategy) external override onlyOwner {

265:     function getYieldStrategies() external view override returns (address[] memory) {

280:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {

293:     function pauseToken(address token) external override onlyOwner {

302:     function unpauseToken(address token) external override onlyOwner {

312:     function getTokenConfig(address token) external view override returns (TokenConfig memory) {

324:     function setDiscountRate(uint256 rate) external override onlyOwner {

336:     function getDiscountRate() external view override returns (uint256) {

348:     function setPhlimbo(address _phlimbo) external onlyOwner {

360:     function setRewardToken(address _rewardToken) external onlyOwner {

369:     function approvePhlimbo(uint256 amount) external onlyOwner {

385:     function setNudgeAddress(address _nudge) external onlyOwner {

396:     function setNudgeSplit(uint256 _split) external onlyOwner {

414:     function setNFTMinter(address _nftMinter) external onlyOwner {

443:     function claim(uint256 nftIndex, uint256 minRewardTokenSupplied, address[] calldata exemptStrategies)

531:     function _validateAndBurnNFT(address caller, uint256 index) internal {

552:     function _getYieldForStrategy(address strategy, address token) internal view returns (uint256) {

572:     function _getNormalizedYieldForStrategy(address strategy, address token) internal view returns (uint256) {

586:     function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {

617:     function _denormalizeAmount(uint256 amount, address token) internal view returns (uint256) {

651:     function calculateClaimAmount(address[] calldata exemptStrategies) external view override returns (uint256) {

700:     function canClaim(address caller) external view returns (bool) {

723:     function getYield(address strategy) external view override returns (uint256) {

738:     function getTotalYield() external view override returns (uint256) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-8"></a>[NC-8] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

190:     function setPauser(address _pauser) external onlyOwner {
             address oldPauser = pauser;
             pauser = _pauser;
             emit PauserUpdated(oldPauser, _pauser);

385:     function setNudgeAddress(address _nudge) external onlyOwner {
             address oldNudge = nudge;
             nudge = _nudge;
             emit NudgeUpdated(oldNudge, _nudge);

414:     function setNFTMinter(address _nftMinter) external onlyOwner {
             address oldNFTMinter = nftMinter;
             nftMinter = _nftMinter;
             emit NFTMinterUpdated(oldNFTMinter, _nftMinter);

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-9"></a>[NC-9] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

360:     function setRewardToken(address _rewardToken) external onlyOwner {
             if (_rewardToken == address(0)) revert ZeroAddress();
             rewardToken = _rewardToken;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-10"></a>[NC-10] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

175:         require(msg.sender == pauser, "Only pauser can call this function");

213:         require(msg.sender == owner() || msg.sender == pauser, "Only owner or pauser can unpause");

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-11"></a>[NC-11] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

88:     mapping(address => TokenConfig) public tokenConfigs;

118:     mapping(address => bool) public isRegisteredStrategy;

124:     mapping(address => address) public strategyTokens;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-12"></a>[NC-12] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

190:     function setPauser(address _pauser) external onlyOwner {

293:     function pauseToken(address token) external override onlyOwner {

302:     function unpauseToken(address token) external override onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-13"></a>[NC-13] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (21)*:
```solidity
File: src/StableYieldAccumulator.sol

228:         if (strategy == address(0)) revert ZeroAddress();

229:         if (token == address(0)) revert ZeroAddress();

230:         if (isRegisteredStrategy[strategy]) revert StrategyAlreadyRegistered();

244:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

281:         if (token == address(0)) revert ZeroAddress();

282:         if (decimals > 18) revert InvalidDecimals();

325:         if (rate > 10000) revert ExceedsMaxDiscount();

349:         if (_phlimbo == address(0)) revert ZeroAddress();

361:         if (_rewardToken == address(0)) revert ZeroAddress();

370:         if (phlimbo == address(0)) revert ZeroAddress();

371:         if (rewardToken == address(0)) revert ZeroAddress();

397:         if (_split > 100) revert InvalidNudgeSplit();

449:         if (phlimbo == address(0)) revert ZeroAddress();

450:         if (rewardToken == address(0)) revert ZeroAddress();

454:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

494:         if (totalNormalizedYield == 0) revert ZeroAmount();

501:         if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();

506:         if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured();

538:             revert NoValidNFT();

654:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

724:         if (!isRegisteredStrategy[strategy]) revert StrategyNotRegistered();

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-14"></a>[NC-14] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
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
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-15"></a>[NC-15] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

325:         if (rate > 10000) revert ExceedsMaxDiscount();

497:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

684:         uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-16"></a>[NC-16] Constants should be defined rather than using magic numbers

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

598:             scaled = amount * (10 ** (18 - decimals));

634:             scaled = scaled / (10 ** (18 - decimals));

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="NC-17"></a>[NC-17] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (14)*:
```solidity
File: src/StableYieldAccumulator.sol

247:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

453:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

460:         uint256 totalNormalizedYield = 0;

461:         uint256 strategiesWithYield = 0;

464:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

473:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

555:         uint256 yield = 0;

556:         for (uint256 i = 0; i < clients.length; i++) {

653:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

657:         uint256 totalNormalizedYield = 0;

659:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

667:             for (uint256 j = 0; j < exemptStrategies.length; j++) {

739:         uint256 total = 0;

740:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 1 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 2 |
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

57: contract StableYieldAccumulator is Ownable, Pausable, ReentrancyGuard, IPausable, IStableYieldAccumulator {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (2)*:
```solidity
File: src/StableYieldAccumulator.sol

509:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

516:             IERC20(rewardToken).safeTransfer(nudge, nudgeAmount);

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

192:         pauser = _pauser;

387:         nudge = _nudge;

416:         nftMinter = _nftMinter;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

600:             scaled = amount / (10 ** (decimals - 18));

629:             scaled = scaled * 1e18 / exchangeRate;

634:             scaled = scaled / (10 ** (18 - decimals));

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="L-5"></a>[L-5] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (3)*:
```solidity
File: src/StableYieldAccumulator.sol

190:     function setPauser(address _pauser) external onlyOwner {

293:     function pauseToken(address token) external override onlyOwner {

302:     function unpauseToken(address token) external override onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="L-6"></a>[L-6] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

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
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 15 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: src/StableYieldAccumulator.sol

509:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (15)*:
```solidity
File: src/StableYieldAccumulator.sol

57: contract StableYieldAccumulator is Ownable, Pausable, ReentrancyGuard, IPausable, IStableYieldAccumulator {

162:     constructor() Ownable(msg.sender) {

190:     function setPauser(address _pauser) external onlyOwner {

227:     function addYieldStrategy(address strategy, address token) external override onlyOwner {

243:     function removeYieldStrategy(address strategy) external override onlyOwner {

280:     function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external override onlyOwner {

293:     function pauseToken(address token) external override onlyOwner {

302:     function unpauseToken(address token) external override onlyOwner {

324:     function setDiscountRate(uint256 rate) external override onlyOwner {

348:     function setPhlimbo(address _phlimbo) external onlyOwner {

360:     function setRewardToken(address _rewardToken) external onlyOwner {

369:     function approvePhlimbo(uint256 amount) external onlyOwner {

385:     function setNudgeAddress(address _nudge) external onlyOwner {

396:     function setNudgeSplit(uint256 _split) external onlyOwner {

414:     function setNFTMinter(address _nftMinter) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-yield-accumulator/blob/71abe3e088559cb5d9c10e8475dc67e7cc57fac9src/StableYieldAccumulator.sol)

