# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 5 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 6 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 2 |
| [GAS-4](#GAS-4) | State variables should be cached in stack variables rather than re-reading them from storage | 4 |
| [GAS-5](#GAS-5) | For Operations that will not overflow, you could use unchecked | 32 |
| [GAS-6](#GAS-6) | Use Custom Errors instead of Revert Strings to save Gas | 18 |
| [GAS-7](#GAS-7) | Avoid contract existence checks by using low level calls | 6 |
| [GAS-8](#GAS-8) | Stack variable used as a cheaper cache for a state variable is only used once | 1 |
| [GAS-9](#GAS-9) | State variables only set in the constructor should be declared `immutable` | 3 |
| [GAS-10](#GAS-10) | Functions guaranteed to revert when called by normal users can be marked `payable` | 3 |
| [GAS-11](#GAS-11) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 2 |
| [GAS-12](#GAS-12) | Using `private` rather than `public` for constants, saves gas | 1 |
| [GAS-13](#GAS-13) | Use of `this` instead of marking as `public` an `external` function | 1 |
| [GAS-14](#GAS-14) | Increments/decrements can be unchecked in for-loops | 2 |
| [GAS-15](#GAS-15) | Use != 0 instead of > 0 for unsigned integer comparison | 7 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (5)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

312:         clientBalances[token][recipient] += creditedPrincipal;

313:         totalDeposited[token] += creditedPrincipal;

512:             totalShares += shares;

515:             totalBufferShares += shares;

541:             totalSetAside += buf;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (6)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

104:         require(_underlyingToken != address(0), "ERC4626MarketYieldStrategy: underlying token cannot be zero address");

105:         require(_erc4626Vault != address(0), "ERC4626MarketYieldStrategy: vault cannot be zero address");

106:         require(_ammAdapter != address(0), "ERC4626MarketYieldStrategy: AMM adapter cannot be zero address");

289:         require(recipient != address(0), "ERC4626MarketYieldStrategy: recipient cannot be zero address");

331:         require(recipient != address(0), "ERC4626MarketYieldStrategy: recipient cannot be zero address");

501:             require(client != address(0), "ERC4626MarketYieldStrategy: client cannot be zero address");

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (2)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

499:         for (uint256 i = 0; i < clients.length; i++) {

537:         for (uint256 i = 0; i < clients.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (4)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

308:         uint256 sharesReceived = ammAdapter.swap(address(underlyingToken), address(vault), amount, minOut);

354:         uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);

416:             uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);

466:         underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);

```

### <a name="GAS-5"></a>[GAS-5] For Operations that will not overflow, you could use unchecked

*Instances (32)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

4: import "../AYieldStrategy.sol";

5: import "../AMMAdapters/IAMMAdapter.sol";

6: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

7: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

8: import "@openzeppelin/contracts/interfaces/IERC4626.sol";

155:         return (totalValue * principal) / totalDeposited[token];

213:         return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

312:         clientBalances[token][recipient] += creditedPrincipal;

313:         totalDeposited[token] += creditedPrincipal;

348:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

361:         clientBalances[token][balanceHolder] -= amount;

362:         totalDeposited[token] -= amount;

401:             return; // Nothing to withdraw

405:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

410:             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

420:             totalDeposited[token] -= clientStoredBalance;

447:         uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

453:         uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;

461:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

499:         for (uint256 i = 0; i < clients.length; i++) {

506:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

508:                 surplus = total - principal;

511:             uint256 shares = vault.convertToShares(surplus); // per-client floor (protocol-favoring)

512:             totalShares += shares;

513:             shares = shares * setAsideBufferSize[client] / 100; // reuse slot: now buffer shares (0–100)

515:             totalBufferShares += shares;

537:         for (uint256 i = 0; i < clients.length; i++) {

539:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

541:             totalSetAside += buf;

542:             underlyingToken.safeTransfer(clients[i], buf); // set aside back to the client

544:         toRecipient = underlyingReceived - totalSetAside; // dust (rounding) favors recipient

546:         return toRecipient; // RETURN VALUE REDUCED by totalSetAside

```

### <a name="GAS-6"></a>[GAS-6] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (18)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

104:         require(_underlyingToken != address(0), "ERC4626MarketYieldStrategy: underlying token cannot be zero address");

105:         require(_erc4626Vault != address(0), "ERC4626MarketYieldStrategy: vault cannot be zero address");

106:         require(_ammAdapter != address(0), "ERC4626MarketYieldStrategy: AMM adapter cannot be zero address");

130:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

143:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

195:         require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");

287:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

288:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

289:         require(recipient != address(0), "ERC4626MarketYieldStrategy: recipient cannot be zero address");

309:         require(sharesReceived > 0, "ERC4626MarketYieldStrategy: no shares received");

329:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

330:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

331:         require(recipient != address(0), "ERC4626MarketYieldStrategy: recipient cannot be zero address");

378:         require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

395:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

396:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

444:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

501:             require(client != address(0), "ERC4626MarketYieldStrategy: client cannot be zero address");

```

### <a name="GAS-7"></a>[GAS-7] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (6)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

151:         uint256 totalShares = vault.balanceOf(address(this));

184:         return vault.balanceOf(address(this));

341:         uint256 availableShares = vault.balanceOf(address(this));

377:         uint256 totalShares = vault.balanceOf(address(this));

399:         uint256 totalShares = vault.balanceOf(address(this));

447:         uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

```

### <a name="GAS-8"></a>[GAS-8] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

196:         uint256 oldBps = slippageToleranceBps;

```

### <a name="GAS-9"></a>[GAS-9] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (3)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

108:         underlyingToken = IERC20(_underlyingToken);

109:         vault = IERC4626(_erc4626Vault);

110:         ammAdapter = IAMMAdapter(_ammAdapter);

```

### <a name="GAS-10"></a>[GAS-10] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (3)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

194:     function setSlippageTolerance(uint256 _bps) external onlyOwner {

261:     function depositAsOwner(address token, uint256 amount, address client) external onlyOwner nonReentrant {

273:     function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {

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

*Instances (2)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

499:         for (uint256 i = 0; i < clients.length; i++) {

537:         for (uint256 i = 0; i < clients.length; i++) {

```

### <a name="GAS-12"></a>[GAS-12] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

43:     uint256 public constant MAX_BPS = 10000;

```

### <a name="GAS-13"></a>[GAS-13] Use of `this` instead of marking as `public` an `external` function
Using `this.` is like making an expensive external call. Consider marking the called function as public

*Saves around 2000 gas per instance*

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

167:         return this.principalOf(token, account);

```

### <a name="GAS-14"></a>[GAS-14] Increments/decrements can be unchecked in for-loops
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

*Instances (2)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

499:         for (uint256 i = 0; i < clients.length; i++) {

537:         for (uint256 i = 0; i < clients.length; i++) {

```

### <a name="GAS-15"></a>[GAS-15] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (7)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

288:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

309:         require(sharesReceived > 0, "ERC4626MarketYieldStrategy: no shares received");

330:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

378:         require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

396:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

407:         if (sharesToSell > 0) {

545:         if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | `constant`s should be defined rather than using magic numbers | 1 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 7 |
| [NC-3](#NC-3) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 11 |
| [NC-4](#NC-4) | Event missing indexed field | 1 |
| [NC-5](#NC-5) | Events that mark critical parameter changes should contain both the old and the new value | 1 |
| [NC-6](#NC-6) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-7](#NC-7) | Functions should not be longer than 50 lines | 17 |
| [NC-8](#NC-8) | Consider using named mappings | 2 |
| [NC-9](#NC-9) | Adding a `return` statement when the function defines a named return variable, is redundant | 5 |
| [NC-10](#NC-10) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-11](#NC-11) | Internal and private variables and functions names should begin with an underscore | 2 |
| [NC-12](#NC-12) | Event is missing `indexed` fields | 1 |
| [NC-13](#NC-13) | Variables need not be initialized to zero | 2 |
### <a name="NC-1"></a>[NC-1] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

513:             shares = shares * setAsideBufferSize[client] / 100; // reuse slot: now buffer shares (0–100)

```

### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (7)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

446:         if (td == 0) return 0;

451:         if (totalShares == 0) return 0;

505:                 if (principal == 0) continue;

507:                 if (total <= principal) continue;

538:             if (bufferShares[i] == 0) continue;

540:             if (buf == 0) continue;

545:         if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);

```

### <a name="NC-3"></a>[NC-3] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (11)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

130:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

143:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

287:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

288:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

289:         require(recipient != address(0), "ERC4626MarketYieldStrategy: recipient cannot be zero address");

329:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

330:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

331:         require(recipient != address(0), "ERC4626MarketYieldStrategy: recipient cannot be zero address");

395:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

396:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

444:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

```

### <a name="NC-4"></a>[NC-4] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

90:     event SlippageToleranceSet(uint256 oldBps, uint256 newBps);

```

### <a name="NC-5"></a>[NC-5] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

194:     function setSlippageTolerance(uint256 _bps) external onlyOwner {
             require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
             uint256 oldBps = slippageToleranceBps;
             slippageToleranceBps = _bps;
             emit SlippageToleranceSet(oldBps, _bps);

```

### <a name="NC-6"></a>[NC-6] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

1: 
   Current order:
   external underlying
   external principalOf
   external totalBalanceOf
   external balanceOf
   external getTotalDeposited
   external getTotalShares
   external setSlippageTolerance
   internal _creditedPrincipal
   external deposit
   external withdraw
   external depositAsOwner
   external withdrawAsOwner
   internal _depositInternal
   internal _withdrawInternal
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   private _accrueSurplusShares
   private _distributeBuffer
   
   Suggested order:
   external underlying
   external principalOf
   external totalBalanceOf
   external balanceOf
   external getTotalDeposited
   external getTotalShares
   external setSlippageTolerance
   external deposit
   external withdraw
   external depositAsOwner
   external withdrawAsOwner
   internal _creditedPrincipal
   internal _depositInternal
   internal _withdrawInternal
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   private _accrueSurplusShares
   private _distributeBuffer

```

### <a name="NC-7"></a>[NC-7] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (17)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

119:     function underlying() external view returns (address) {

129:     function principalOf(address token, address account) external view override returns (uint256) {

142:     function totalBalanceOf(address token, address account) external view override returns (uint256) {

166:     function balanceOf(address token, address account) external view override returns (uint256) {

175:     function getTotalDeposited(address token) external view returns (uint256) {

183:     function getTotalShares() external view returns (uint256) {

194:     function setSlippageTolerance(uint256 _bps) external onlyOwner {

212:     function _creditedPrincipal(uint256 amount) internal view returns (uint256) {

225:     function deposit(address token, uint256 amount, address recipient)

243:     function withdraw(address token, uint256 amount, address recipient)

261:     function depositAsOwner(address token, uint256 amount, address client) external onlyOwner nonReentrant {

273:     function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {

286:     function _depositInternal(address token, uint256 amount, address recipient, address depositor) internal {

328:     function _withdrawInternal(address token, uint256 amount, address recipient, address balanceHolder) internal {

376:     function _emergencyWithdraw(uint256 amount) internal override {

394:     function _totalWithdraw(address token, address client, uint256 amount) internal override {

439:     function _skimSurplus(address token, address[] memory clients, address recipient)

```

### <a name="NC-8"></a>[NC-8] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (2)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

46:     mapping(address => mapping(address => uint256)) private clientBalances;

49:     mapping(address => uint256) private totalDeposited;

```

### <a name="NC-9"></a>[NC-9] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (5)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

428:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never sell beyond the protocol's surplus.
             uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;
             require(
                 totalShares <= vault.convertToShares(aggregateSurplus),
                 "ERC4626MarketYieldStrategy: skim exceeds aggregate surplus"
             );
             // minOut is computed on the full `totalShares`: the whole surplus is sold in ONE swap; only the
             // distribution of the proceeds changes when buffers are set, so slippage behavior is unchanged.
             uint256 idealUnderlying = vault.convertToAssets(totalShares);
             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
             IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);
             // SINGLE swap — output lands in address(this). Return value is the ACTUAL underlying received,
             // net of AMM price/slippage, and so will generally differ from the SurplusSkimmed snapshot sum
             // (vault-asset terms) — see CLAUDE.md.
             underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);
     
             // FAST PATH — no buffers configured (the default): forward the whole swap output to `recipient`.
             if (totalBufferShares == 0) {
                 underlyingToken.safeTransfer(recipient, underlyingReceived);
                 return underlyingReceived;
             }
     
             // BUFFERED PATH — split the actual proceeds: each client gets its proportional share of the
             // set-aside, the remainder goes to `recipient`. Principal tracking intentionally untouched.
             return _distributeBuffer(clients, bufferShares, underlyingReceived, totalShares, recipient);

428:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;

428:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;

428:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never sell beyond the protocol's surplus.
             uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;
             require(
                 totalShares <= vault.convertToShares(aggregateSurplus),
                 "ERC4626MarketYieldStrategy: skim exceeds aggregate surplus"
             );
             // minOut is computed on the full `totalShares`: the whole surplus is sold in ONE swap; only the
             // distribution of the proceeds changes when buffers are set, so slippage behavior is unchanged.
             uint256 idealUnderlying = vault.convertToAssets(totalShares);
             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
             IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);
             // SINGLE swap — output lands in address(this). Return value is the ACTUAL underlying received,
             // net of AMM price/slippage, and so will generally differ from the SurplusSkimmed snapshot sum
             // (vault-asset terms) — see CLAUDE.md.
             underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);
     
             // FAST PATH — no buffers configured (the default): forward the whole swap output to `recipient`.
             if (totalBufferShares == 0) {
                 underlyingToken.safeTransfer(recipient, underlyingReceived);
                 return underlyingReceived;

520:      * @notice Distribute actual swap proceeds: set-aside buffers to clients, remainder to recipient.
          * @param clients The client set (parallel to bufferShares)
          * @param bufferShares Per-client buffer shares (indexed by loop position)
          * @param underlyingReceived The actual underlying received from the single swap
          * @param totalShares The aggregate shares sold in the swap
          * @param recipient The address that receives the remainder
          * @return toRecipient The amount delivered to `recipient` (reduced by total set-aside)
          * @dev Factored out to keep the caller within the EVM stack-depth limit.
          */
         function _distributeBuffer(
             address[] memory clients,
             uint256[] memory bufferShares,
             uint256 underlyingReceived,
             uint256 totalShares,
             address recipient
         ) private returns (uint256 toRecipient) {
             uint256 totalSetAside;
             for (uint256 i = 0; i < clients.length; i++) {
                 if (bufferShares[i] == 0) continue;
                 uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional
                 if (buf == 0) continue;
                 totalSetAside += buf;
                 underlyingToken.safeTransfer(clients[i], buf); // set aside back to the client
             }
             toRecipient = underlyingReceived - totalSetAside; // dust (rounding) favors recipient
             if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);
             return toRecipient; // RETURN VALUE REDUCED by totalSetAside

```

### <a name="NC-10"></a>[NC-10] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

43:     uint256 public constant MAX_BPS = 10000;

```

### <a name="NC-11"></a>[NC-11] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (2)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

46:     mapping(address => mapping(address => uint256)) private clientBalances;

49:     mapping(address => uint256) private totalDeposited;

```

### <a name="NC-12"></a>[NC-12] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

90:     event SlippageToleranceSet(uint256 oldBps, uint256 newBps);

```

### <a name="NC-13"></a>[NC-13] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (2)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

499:         for (uint256 i = 0; i < clients.length; i++) {

537:         for (uint256 i = 0; i < clients.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Some tokens may revert when zero value transfers are made | 7 |
| [L-2](#L-2) | Division by zero not prevented | 4 |
| [L-3](#L-3) | Possible rounding issue | 4 |
| [L-4](#L-4) | Loss of precision | 8 |
| [L-5](#L-5) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
| [L-6](#L-6) | File allows a version of solidity that is susceptible to an assembly optimizer bug | 1 |
### <a name="L-1"></a>[L-1] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (7)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

292:         underlyingToken.safeTransferFrom(depositor, address(this), amount);

357:         underlyingToken.safeTransfer(recipient, underlyingReceived);

384:         IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer);

423:             underlyingToken.safeTransfer(owner(), underlyingReceived);

470:             underlyingToken.safeTransfer(recipient, underlyingReceived);

542:             underlyingToken.safeTransfer(clients[i], buf); // set aside back to the client

545:         if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);

```

### <a name="L-2"></a>[L-2] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (4)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

155:         return (totalValue * principal) / totalDeposited[token];

405:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

506:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

539:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

### <a name="L-3"></a>[L-3] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (4)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

155:         return (totalValue * principal) / totalDeposited[token];

405:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

506:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

539:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

### <a name="L-4"></a>[L-4] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (8)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

155:         return (totalValue * principal) / totalDeposited[token];

213:         return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

348:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

405:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

410:             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

461:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

506:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

539:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

### <a name="L-5"></a>[L-5] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

2: pragma solidity ^0.8.13;

```

### <a name="L-6"></a>[L-6] File allows a version of solidity that is susceptible to an assembly optimizer bug
In solidity versions 0.8.13 and 0.8.14, there is an [optimizer bug](https://github.com/ethereum/solidity-blog/blob/499ab8abc19391be7b7b34f88953a067029a5b45/_posts/2022-06-15-inline-assembly-memory-side-effects-bug.md) where, if the use of a variable is in a separate `assembly` block from the block in which it was stored, the `mstore` operation is optimized out, leading to uninitialized memory. The code currently does not have such a pattern of execution, but it does use `mstore`s in `assembly` blocks, so it is a risk for future changes. The affected solidity versions should be avoided if at all possible.

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

2: pragma solidity ^0.8.13;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 3 |
| [M-3](#M-3) | `increaseAllowance/decreaseAllowance` won't work on mainnet for USDT | 4 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

292:         underlyingToken.safeTransferFrom(depositor, address(this), amount);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (3)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

194:     function setSlippageTolerance(uint256 _bps) external onlyOwner {

261:     function depositAsOwner(address token, uint256 amount, address client) external onlyOwner nonReentrant {

273:     function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {

```

### <a name="M-3"></a>[M-3] `increaseAllowance/decreaseAllowance` won't work on mainnet for USDT
On mainnet, the mitigation to be compatible with `increaseAllowance/decreaseAllowance` isn't applied: https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7#code, meaning it reverts on setting a non-zero & non-max allowance, unless the allowance is already zero.

*Instances (4)*:
```solidity
File: concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

305:         underlyingToken.safeIncreaseAllowance(address(ammAdapter), amount);

351:         IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);

413:             IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);

462:         IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);

```

