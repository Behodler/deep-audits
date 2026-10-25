# 4naly3er Automated QA/Gas Report: sya-harvester (run 01)

> Appendix to [qa-report.md](./qa-report.md). This file is raw automated output. It is **not** triaged and does **not** carry this audit's severity labels.
>
> - **Tool**: 4naly3er (`/home/justin/code/audits/tools/4naly3er`), `yarn analyze <sya-harvester/src/> <scope.txt>`. basePath is the submodule root, so imports resolve through its own `remappings.txt`. Run read-only; `src/` is unmodified (`git status` clean).
> - **Commit**: `62c19c86be1594dcf82e8af794fcd6c28f9a8fc0` (https://github.com/Behodler/sya-harvester)
> - **Scope (2 files)**: `src/SYAHarvester.sol`, `src/interfaces/ICurveRouterNG.sol`. Both were analysed and there were no import-resolution failures.
> - **Coverage gap**: 4naly3er reads only Solidity. `script/harvest.sh` (operator script, in scope per story-005) is not covered here. It was reviewed manually: see L-02, L-04 and Q-07 in the QA report.
> - **Reading the bot's labels**: its `M-1 Centralization Risk for trusted owners` and `L-1`/`L-5` (two-step ownership) are generic owner-privilege findings. Under Law 3 (the owner is trusted for knowing actions) they are not separate findings in this audit. The one owner footgun with a non-obvious consequence is filed as L-03. The bot's `L-3` (external call recipient may consume all gas) is the `msg.sender.call{value: ethOut}` payout at L254. The recipient is the caller itself, so only the caller's own transaction is affected. The bot's `L-2` (zero-value transfers) and `L-4` (PUSH0) are not relevant to the mainnet-only deployment with the configured tokens. None of the bot items was promoted into the manual QA bundle.
> - **Known false positive**: `GAS-7` ("state variables only set in the constructor should be `immutable`") flags `poolManager`, `sya` and `router` at L110-112. All three are already declared `immutable` (L39, L41, L43).

---

# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 1 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 8 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 2 |
| [GAS-4](#GAS-4) | State variables should be cached in stack variables rather than re-reading them from storage | 2 |
| [GAS-5](#GAS-5) | For Operations that will not overflow, you could use unchecked | 28 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 3 |
| [GAS-7](#GAS-7) | State variables only set in the constructor should be declared `immutable` | 3 |
| [GAS-8](#GAS-8) | Functions guaranteed to revert when called by normal users can be marked `payable` | 2 |
| [GAS-9](#GAS-9) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 3 |
| [GAS-10](#GAS-10) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-11](#GAS-11) | Increments/decrements can be unchecked in for-loops | 3 |
| [GAS-12](#GAS-12) | Use != 0 instead of > 0 for unsigned integer comparison | 2 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

337:             debt += uint256(int256(-delta.amount1()));

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (8)*:
```solidity
File: src/SYAHarvester.sol

107:         if (address(_poolManager) == address(0) || address(_sya) == address(0) || address(_router) == address(0)) {

107:         if (address(_poolManager) == address(0) || address(_sya) == address(0) || address(_router) == address(0)) {

130:         if (token == address(0)) revert ZeroAddress();

135:             if (path[i] != address(0)) {

174:         if (Currency.unwrap(key.currency0) != address(0) || Currency.unwrap(key.currency1) != sya.rewardToken()) {

231:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

234:         bool moveNft = nftIndex != 0 && nftAddr != address(0);

311:             if (token == address(0) || token == reward) continue;

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

308:         for (uint256 i = 0; i < strategies.length; i++) {

352:         for (uint256 i = 0; i < list.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

286:         IERC20(reward).forceApprove(address(sya), 0);

319:             IERC20(token).forceApprove(address(router), 0);

```

### <a name="GAS-5"></a>[GAS-5] For Operations that will not overflow, you could use unchecked

*Instances (28)*:
```solidity
File: src/SYAHarvester.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

8: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

9: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

10: import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

11: import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";

12: import {PoolKey} from "v4-core/src/types/PoolKey.sol";

13: import {Currency} from "v4-core/src/types/Currency.sol";

14: import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

15: import {TickMath} from "v4-core/src/libraries/TickMath.sol";

16: import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

17: import {ICurveRouterNG} from "./interfaces/ICurveRouterNG.sol";

32:         address[11] path; // Interleaved [tokenIn, pool0, token1, pool1, ...], zero-padded

33:         uint256[5][5] swapParams; // Per-hop [i, j, swap_type, pool_type, n_coins]

34:         address[5] pools; // Base pools for meta-swaps, else zero

35:         bool configured; // Distinguishes "unset" from "all zeros"

134:         for (uint256 i = 0; i < 11; i++) {

251:         uint256 gasCost = (g0 - gasleft() + GAS_OVERHEAD) * tx.gasprice;

281:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

291:         uint256 surplus = IERC20(reward).balanceOf(address(this)) - owed;

308:         for (uint256 i = 0; i < strategies.length; i++) {

313:             if (balance == 0) continue; // nothing delivered, or a shared token already sold

332:                     amountSpecified: -SafeCast.toInt256(surplus),

333:                     sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1

337:             debt += uint256(int256(-delta.amount1()));

352:         for (uint256 i = 0; i < list.length; i++) {

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (3)*:
```solidity
File: src/SYAHarvester.sol

242:             uint256 bal = IERC1155(nftAddr).balanceOf(address(this), nftIndex);

291:         uint256 surplus = IERC20(reward).balanceOf(address(this)) - owed;

312:             uint256 balance = IERC20(token).balanceOf(address(this));

```

### <a name="GAS-7"></a>[GAS-7] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (3)*:
```solidity
File: src/SYAHarvester.sol

110:         poolManager = _poolManager;

111:         sya = _sya;

112:         router = _router;

```

### <a name="GAS-8"></a>[GAS-8] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

155:     function clearRoute(address token) external onlyOwner {

173:     function setEthPool(PoolKey calldata key) external onlyOwner {

```

### <a name="GAS-9"></a>[GAS-9] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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

*Instances (3)*:
```solidity
File: src/SYAHarvester.sol

134:         for (uint256 i = 0; i < 11; i++) {

308:         for (uint256 i = 0; i < strategies.length; i++) {

352:         for (uint256 i = 0; i < list.length; i++) {

```

### <a name="GAS-10"></a>[GAS-10] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

46:     uint256 public constant BORROW_BUFFER_BPS = 100;

60:     uint256 public constant GAS_OVERHEAD = 60_000;

```

### <a name="GAS-11"></a>[GAS-11] Increments/decrements can be unchecked in for-loops
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

*Instances (3)*:
```solidity
File: src/SYAHarvester.sol

134:         for (uint256 i = 0; i < 11; i++) {

308:         for (uint256 i = 0; i < strategies.length; i++) {

352:         for (uint256 i = 0; i < list.length; i++) {

```

### <a name="GAS-12"></a>[GAS-12] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

327:         if (surplus > 0) {

346:         if (ethAmount > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Array indices should be referenced via `enum`s rather than via numeric literals | 1 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 2 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 15 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 1 |
| [NC-5](#NC-5) | Events that mark critical parameter changes should contain both the old and the new value | 2 |
| [NC-6](#NC-6) | Functions should not be longer than 50 lines | 9 |
| [NC-7](#NC-7) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-8](#NC-8) | Consider using named mappings | 1 |
| [NC-9](#NC-9) | Take advantage of Custom Error's return value property | 7 |
| [NC-10](#NC-10) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-11](#NC-11) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-12](#NC-12) | Internal and private variables and functions names should begin with an underscore | 2 |
| [NC-13](#NC-13) | Event is missing `indexed` fields | 1 |
| [NC-14](#NC-14) | Variables need not be initialized to zero | 3 |
### <a name="NC-1"></a>[NC-1] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

131:         if (path[0] != token) revert InvalidRouteStart(token, path[0]);

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

134:         for (uint256 i = 0; i < 11; i++) {

281:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (15)*:
```solidity
File: src/SYAHarvester.sol

130:         if (token == address(0)) revert ZeroAddress();

131:         if (path[0] != token) revert InvalidRouteStart(token, path[0]);

140:         if (last != rewardToken) revert InvalidRouteEnd(rewardToken, last);

231:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

249:         if (ethOut < minEthOut) revert InsufficientEthOut(ethOut, minEthOut);

252:         if (ethOut < gasCost) revert Unprofitable(ethOut, gasCost);

255:         if (!ok) revert EthTransferFailed();

277:         if (msg.sender != address(poolManager)) revert NotPoolManager();

298:         if (msg.sender != address(poolManager)) revert NotPoolManager();

309:             if (_contains(exempt, strategies[i])) continue;

311:             if (token == address(0) || token == reward) continue;

313:             if (balance == 0) continue; // nothing delivered, or a shared token already sold

315:             if (!r.configured) revert RouteNotConfigured(token);

332:                     amountSpecified: -SafeCast.toInt256(surplus),

353:             if (list[i] == item) return true;

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

27: contract SYAHarvester is Ownable, ERC1155Holder, IUnlockCallback {

```

### <a name="NC-5"></a>[NC-5] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

124:     function setRoute(
             address token,
             address[11] calldata path,
             uint256[5][5] calldata swapParams,
             address[5] calldata pools
         ) external onlyOwner {
             if (token == address(0)) revert ZeroAddress();
             if (path[0] != token) revert InvalidRouteStart(token, path[0]);
     
             address last;
             for (uint256 i = 0; i < 11; i++) {
                 if (path[i] != address(0)) {
                     last = path[i];
                 }
             }
             address rewardToken = sya.rewardToken();
             if (last != rewardToken) revert InvalidRouteEnd(rewardToken, last);
     
             CurveRoute storage r = routes[token];
             r.path = path;
             r.swapParams = swapParams;
             r.pools = pools;
             r.configured = true;
     
             emit RouteSet(token);

173:     function setEthPool(PoolKey calldata key) external onlyOwner {
             if (Currency.unwrap(key.currency0) != address(0) || Currency.unwrap(key.currency1) != sya.rewardToken()) {
                 revert InvalidEthPool();
             }
             ethPool = key;
             emit EthPoolSet(

```

### <a name="NC-6"></a>[NC-6] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (9)*:
```solidity
File: src/SYAHarvester.sol

155:     function clearRoute(address token) external onlyOwner {

165:     function getRoute(address token) external view returns (CurveRoute memory) {

173:     function setEthPool(PoolKey calldata key) external onlyOwner {

187:     function getEthPool() external view returns (PoolKey memory) {

226:     function harvest(address[] calldata exemptStrategies, uint256 nftIndex, uint256 minEthOut)

276:     function unlockCallback(bytes calldata data) external returns (bytes memory) {

306:     function _sellYield(address[] memory exempt, address reward) internal {

324:     function _swapSurplusAndSettle(address reward, uint256 owed, uint256 surplus) internal {

351:     function _contains(address[] memory list, address item) internal pure returns (bool) {

```

### <a name="NC-7"></a>[NC-7] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

277:         if (msg.sender != address(poolManager)) revert NotPoolManager();

298:         if (msg.sender != address(poolManager)) revert NotPoolManager();

```

### <a name="NC-8"></a>[NC-8] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

63:     mapping(address => CurveRoute) private routes;

```

### <a name="NC-9"></a>[NC-9] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (7)*:
```solidity
File: src/SYAHarvester.sol

108:             revert ZeroAddress();

130:         if (token == address(0)) revert ZeroAddress();

175:             revert InvalidEthPool();

231:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

255:         if (!ok) revert EthTransferFailed();

277:         if (msg.sender != address(poolManager)) revert NotPoolManager();

298:         if (msg.sender != address(poolManager)) revert NotPoolManager();

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
File: src/SYAHarvester.sol

1: 
   Current order:
   UsingForDirective.IERC20
   StructDefinition.CurveRoute
   VariableDeclaration.poolManager
   VariableDeclaration.sya
   VariableDeclaration.router
   VariableDeclaration.BORROW_BUFFER_BPS
   VariableDeclaration.GAS_OVERHEAD
   VariableDeclaration.routes
   VariableDeclaration.ethPool
   EventDefinition.RouteSet
   EventDefinition.RouteCleared
   EventDefinition.EthPoolSet
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidRouteStart
   ErrorDefinition.InvalidRouteEnd
   ErrorDefinition.InvalidEthPool
   ErrorDefinition.RouteNotConfigured
   ErrorDefinition.InsufficientEthOut
   ErrorDefinition.NotPoolManager
   ErrorDefinition.EthPoolNotSet
   ErrorDefinition.EthTransferFailed
   ErrorDefinition.Unprofitable
   FunctionDefinition.constructor
   FunctionDefinition.setRoute
   FunctionDefinition.clearRoute
   FunctionDefinition.getRoute
   FunctionDefinition.setEthPool
   FunctionDefinition.getEthPool
   FunctionDefinition.harvest
   FunctionDefinition.unlockCallback
   FunctionDefinition.receive
   FunctionDefinition._sellYield
   FunctionDefinition._swapSurplusAndSettle
   FunctionDefinition._contains
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.poolManager
   VariableDeclaration.sya
   VariableDeclaration.router
   VariableDeclaration.BORROW_BUFFER_BPS
   VariableDeclaration.GAS_OVERHEAD
   VariableDeclaration.routes
   VariableDeclaration.ethPool
   StructDefinition.CurveRoute
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidRouteStart
   ErrorDefinition.InvalidRouteEnd
   ErrorDefinition.InvalidEthPool
   ErrorDefinition.RouteNotConfigured
   ErrorDefinition.InsufficientEthOut
   ErrorDefinition.NotPoolManager
   ErrorDefinition.EthPoolNotSet
   ErrorDefinition.EthTransferFailed
   ErrorDefinition.Unprofitable
   EventDefinition.RouteSet
   EventDefinition.RouteCleared
   EventDefinition.EthPoolSet
   FunctionDefinition.constructor
   FunctionDefinition.setRoute
   FunctionDefinition.clearRoute
   FunctionDefinition.getRoute
   FunctionDefinition.setEthPool
   FunctionDefinition.getEthPool
   FunctionDefinition.harvest
   FunctionDefinition.unlockCallback
   FunctionDefinition.receive
   FunctionDefinition._sellYield
   FunctionDefinition._swapSurplusAndSettle
   FunctionDefinition._contains

```

### <a name="NC-11"></a>[NC-11] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

281:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

```

### <a name="NC-12"></a>[NC-12] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

63:     mapping(address => CurveRoute) private routes;

66:     PoolKey private ethPool;

```

### <a name="NC-13"></a>[NC-13] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

73:     event EthPoolSet(

```

### <a name="NC-14"></a>[NC-14] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (3)*:
```solidity
File: src/SYAHarvester.sol

134:         for (uint256 i = 0; i < 11; i++) {

308:         for (uint256 i = 0; i < strategies.length; i++) {

352:         for (uint256 i = 0; i < list.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 1 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 1 |
| [L-3](#L-3) | External call recipient may consume all transaction gas | 1 |
| [L-4](#L-4) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
| [L-5](#L-5) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

27: contract SYAHarvester is Ownable, ERC1155Holder, IUnlockCallback {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

343:         IERC20(reward).safeTransfer(address(poolManager), debt);

```

### <a name="L-3"></a>[L-3] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

254:         (bool ok,) = msg.sender.call{value: ethOut}("");

```

### <a name="L-4"></a>[L-4] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

2: pragma solidity ^0.8.26;

```

### <a name="L-5"></a>[L-5] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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
File: src/SYAHarvester.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 5 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (5)*:
```solidity
File: src/SYAHarvester.sol

27: contract SYAHarvester is Ownable, ERC1155Holder, IUnlockCallback {

105:         Ownable(_owner)

129:     ) external onlyOwner {

155:     function clearRoute(address token) external onlyOwner {

173:     function setEthPool(PoolKey calldata key) external onlyOwner {

```

