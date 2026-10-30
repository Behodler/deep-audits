# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 1 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 6 |
| [GAS-3](#GAS-3) | State variables should be cached in stack variables rather than re-reading them from storage | 25 |
| [GAS-4](#GAS-4) | Use calldata instead of memory for function arguments that do not get mutated | 3 |
| [GAS-5](#GAS-5) | For Operations that will not overflow, you could use unchecked | 19 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 4 |
| [GAS-7](#GAS-7) | State variables only set in the constructor should be declared `immutable` | 9 |
| [GAS-8](#GAS-8) | Use != 0 instead of > 0 for unsigned integer comparison | 3 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (1)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

375:                 lpSupply += (lpSupply * (rootK - rootKLast)) / (rootK * 5 + rootKLast);

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (6)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

171:             vault_ == address(0) || v3Router_ == address(0) || pool_ == address(0) || uniRouter_ == address(0)

172:                 || sUSDS_ == address(0) || phUSD_ == address(0)

172:                 || sUSDS_ == address(0) || phUSD_ == address(0)

187:         if (pair_ == address(0)) revert PairNotFound();

230:         if (to == address(0)) revert ZeroAddress();

371:         if (feeTo != address(0) && kLast != 0) {

```

### <a name="GAS-3"></a>[GAS-3] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (25)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

244:         IERC20(phUSD).forceApprove(uniRouter, phUSDOut);

245:         (sUSDSUsed, phUSDUsed, liquidity) = IUniV2RouterMigrator(uniRouter)

246:             .addLiquidity(sUSDS, phUSD, sUSDSOut, phUSDOut, amountSUSDSMin, amountPhUSDMin, to, deadline);

246:             .addLiquidity(sUSDS, phUSD, sUSDSOut, phUSDOut, amountSUSDSMin, amountPhUSDMin, to, deadline);

247:         IERC20(sUSDS).forceApprove(uniRouter, 0);

247:         IERC20(sUSDS).forceApprove(uniRouter, 0);

248:         IERC20(phUSD).forceApprove(uniRouter, 0);

248:         IERC20(phUSD).forceApprove(uniRouter, 0);

252:         if (sUSDSRefund > 0) IERC20(sUSDS).safeTransfer(msg.sender, sUSDSRefund);

253:         if (phUSDRefund > 0) IERC20(phUSD).safeTransfer(msg.sender, phUSDRefund);

291:         uint256 supply = IBalancerV3VaultMigrator(vault).totalSupply(pool);

321:         return v.isPoolInRecoveryMode(pool) || v.isPoolPaused(pool) || v.isVaultPaused();

329:         if (v.isPoolPaused(pool) || v.isVaultPaused()) {

330:             v.enableRecoveryMode(pool);

351:             IBalancerV3RouterMigrator(v3Router).removeLiquidityRecovery(pool, bptAmount, minAmountsOut);

351:             IBalancerV3RouterMigrator(v3Router).removeLiquidityRecovery(pool, bptAmount, minAmountsOut);

353:             IBalancerV3RouterMigrator(v3Router).removeLiquidityProportional(pool, bptAmount, minAmountsOut, false, "");

353:             IBalancerV3RouterMigrator(v3Router).removeLiquidityProportional(pool, bptAmount, minAmountsOut, false, "");

355:         IERC20(pool).forceApprove(v3Router, 0);

355:         IERC20(pool).forceApprove(v3Router, 0);

357:         sUSDSOut = IERC20(sUSDS).balanceOf(address(this)) - sBefore;

358:         phUSDOut = IERC20(phUSD).balanceOf(address(this)) - pBefore;

366:             IUniV2PairMigrator(pair).token0() == sUSDS ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));

367:         lpSupply = IUniV2PairMigrator(pair).totalSupply();

370:         uint256 kLast = IUniV2PairMigrator(pair).kLast();

```

### <a name="GAS-4"></a>[GAS-4] Use calldata instead of memory for function arguments that do not get mutated
When a function with a `memory` array is called externally, the `abi.decode()` step has to use a for-loop to copy each index of the `calldata` to the `memory` index. Each iteration of this for-loop costs at least 60 gas (i.e. `60 * <mem_array>.length`). Using `calldata` directly bypasses this loop. 

If the array is passed to an `internal` function which passes the array to another internal function where the array is modified and therefore `memory` is used in the `external` call, it's still more gas-efficient to use `calldata` when the `external` function uses modifiers, since the modifiers may prevent the internal functions from being called. Structs have the same overhead as an array of length one. 

 *Saves 60 gas per instance*

*Instances (3)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

50:         uint256[] memory minAmountsOut,

52:         bytes memory userData

55:     function removeLiquidityRecovery(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut)

```

### <a name="GAS-5"></a>[GAS-5] For Operations that will not overflow, you could use unchecked

*Instances (19)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

197:         phUSDIndex = 1 - sIdx;

250:         sUSDSRefund = sUSDSOut - sUSDSUsed;

251:         phUSDRefund = phUSDOut - phUSDUsed;

293:             sUSDSOut = (balancesRaw[sUSDSIndex] * bptAmount) / supply;

294:             phUSDOut = (balancesRaw[phUSDIndex] * bptAmount) / supply;

302:             leftoverAmount = sUSDSOut - sUSDSUsed;

305:             leftoverAmount = phUSDOut - phUSDUsed;

309:             uint256 root = Math.sqrt(sUSDSUsed * phUSDUsed);

310:             expectedLiquidity = root > MINIMUM_LIQUIDITY ? root - MINIMUM_LIQUIDITY : 0;

312:             expectedLiquidity = Math.min((sUSDSUsed * lpSupply) / reserveS, (phUSDUsed * lpSupply) / reserveP);

357:         sUSDSOut = IERC20(sUSDS).balanceOf(address(this)) - sBefore;

358:         phUSDOut = IERC20(phUSD).balanceOf(address(this)) - pBefore;

372:             uint256 rootK = Math.sqrt(uint256(r0) * uint256(r1));

375:                 lpSupply += (lpSupply * (rootK - rootKLast)) / (rootK * 5 + rootKLast);

387:         uint256 pOptimal = (sDesired * reserveP) / reserveS;

389:         uint256 sOptimal = (pDesired * reserveS) / reserveP;

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (4)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

346:         uint256 sBefore = IERC20(sUSDS).balanceOf(address(this));

347:         uint256 pBefore = IERC20(phUSD).balanceOf(address(this));

357:         sUSDSOut = IERC20(sUSDS).balanceOf(address(this)) - sBefore;

358:         phUSDOut = IERC20(phUSD).balanceOf(address(this)) - pBefore;

```

### <a name="GAS-7"></a>[GAS-7] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (9)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

189:         vault = vault_;

190:         v3Router = v3Router_;

191:         pool = pool_;

192:         uniRouter = uniRouter_;

193:         sUSDS = sUSDS_;

194:         phUSD = phUSD_;

195:         pair = pair_;

196:         sUSDSIndex = sIdx;

197:         phUSDIndex = 1 - sIdx;

```

### <a name="GAS-8"></a>[GAS-8] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (3)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

252:         if (sUSDSRefund > 0) IERC20(sUSDS).safeTransfer(msg.sender, sUSDSRefund);

253:         if (phUSDRefund > 0) IERC20(phUSD).safeTransfer(msg.sender, phUSDRefund);

292:         if (supply > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Array indices should be referenced via `enum`s rather than via numeric literals | 2 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 2 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 10 |
| [NC-4](#NC-4) | Functions should not be longer than 50 lines | 17 |
| [NC-5](#NC-5) | Interfaces should be defined in separate files from their usage | 5 |
| [NC-6](#NC-6) | NatSpec is completely non-existent on functions that should have them | 3 |
| [NC-7](#NC-7) | Incomplete NatSpec: `@param` is missing on actually documented functions | 1 |
| [NC-8](#NC-8) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-9](#NC-9) | Adding a `return` statement when the function defines a named return variable, is redundant | 3 |
| [NC-10](#NC-10) | Take advantage of Custom Error's return value property | 8 |
| [NC-11](#NC-11) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-12](#NC-12) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-13](#NC-13) | Event is missing `indexed` fields | 1 |
### <a name="NC-1"></a>[NC-1] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (2)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

178:         if (tokens[0] == sUSDS_ && tokens[1] == phUSD_) {

180:         } else if (tokens[0] == phUSD_ && tokens[1] == sUSDS_) {

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (2)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

176:         if (tokens.length != 2) revert PoolTokensMismatch();

375:                 lpSupply += (lpSupply * (rootK - rootKLast)) / (rootK * 5 + rootKLast);

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (10)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

170:         if (

176:         if (tokens.length != 2) revert PoolTokensMismatch();

187:         if (pair_ == address(0)) revert PairNotFound();

230:         if (to == address(0)) revert ZeroAddress();

231:         if (deadline < block.timestamp) revert Expired();

252:         if (sUSDSRefund > 0) IERC20(sUSDS).safeTransfer(msg.sender, sUSDSRefund);

253:         if (phUSDRefund > 0) IERC20(phUSD).safeTransfer(msg.sender, phUSDRefund);

328:         if (v.isPoolInRecoveryMode(pool)) return true;

386:         if (reserveS == 0 && reserveP == 0) return (sDesired, pDesired);

388:         if (pOptimal <= pDesired) return (sDesired, pOptimal);

```

### <a name="NC-4"></a>[NC-4] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (17)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

24:     function getPoolTokens(address pool) external view returns (address[] memory tokens);

36:     function totalSupply(address token) external view returns (uint256);

37:     function isPoolInRecoveryMode(address pool) external view returns (bool);

38:     function isPoolPaused(address pool) external view returns (bool);

39:     function isVaultPaused() external view returns (bool);

42:     function enableRecoveryMode(address pool) external;

55:     function removeLiquidityRecovery(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut)

63:     function factory() external view returns (address);

79:     function getPair(address tokenA, address tokenB) external view returns (address);

85:     function token0() external view returns (address);

86:     function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

87:     function totalSupply() external view returns (uint256);

319:     function _wouldUseRecovery() internal view returns (bool) {

326:     function _prepareExitMode() internal returns (bool) {

338:     function _exit(uint256 bptAmount, uint256 minSUSDSOut, uint256 minPhUSDOut, bool recoveryMode)

363:     function _pairState() internal view returns (uint256 reserveS, uint256 reserveP, uint256 lpSupply) {

381:     function _optimalAmounts(uint256 sDesired, uint256 pDesired, uint256 reserveS, uint256 reserveP)

```

### <a name="NC-5"></a>[NC-5] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (5)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

16: interface IBalancerV3VaultMigrator {

46: interface IBalancerV3RouterMigrator {

62: interface IUniV2RouterMigrator {

78: interface IUniV2FactoryMigrator {

84: interface IUniV2PairMigrator {

```

### <a name="NC-6"></a>[NC-6] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (3)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

47:     function removeLiquidityProportional(

55:     function removeLiquidityRecovery(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut)

65:     function addLiquidity(

```

### <a name="NC-7"></a>[NC-7] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (1)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

41:     /// @dev Permissionless while the pool or the Vault is paused (VaultAdmin).
        function enableRecoveryMode(address pool) external;

```

### <a name="NC-8"></a>[NC-8] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

252:         if (sUSDSRefund > 0) IERC20(sUSDS).safeTransfer(msg.sender, sUSDSRefund);

253:         if (phUSDRefund > 0) IERC20(phUSD).safeTransfer(msg.sender, phUSDRefund);

```

### <a name="NC-9"></a>[NC-9] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (3)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

380:     /// @dev Router02 `_addLiquidity`: the amounts it actually takes from (sDesired, pDesired).
         function _optimalAmounts(uint256 sDesired, uint256 pDesired, uint256 reserveS, uint256 reserveP)
             internal
             pure
             returns (uint256 sUsed, uint256 pUsed)
         {
             if (reserveS == 0 && reserveP == 0) return (sDesired, pDesired);
             uint256 pOptimal = (sDesired * reserveP) / reserveS;
             if (pOptimal <= pDesired) return (sDesired, pOptimal);
             uint256 sOptimal = (pDesired * reserveS) / reserveP;
             return (sOptimal, pDesired);

380:     /// @dev Router02 `_addLiquidity`: the amounts it actually takes from (sDesired, pDesired).
         function _optimalAmounts(uint256 sDesired, uint256 pDesired, uint256 reserveS, uint256 reserveP)
             internal
             pure
             returns (uint256 sUsed, uint256 pUsed)
         {
             if (reserveS == 0 && reserveP == 0) return (sDesired, pDesired);

380:     /// @dev Router02 `_addLiquidity`: the amounts it actually takes from (sDesired, pDesired).
         function _optimalAmounts(uint256 sDesired, uint256 pDesired, uint256 reserveS, uint256 reserveP)
             internal
             pure
             returns (uint256 sUsed, uint256 pUsed)
         {
             if (reserveS == 0 && reserveP == 0) return (sDesired, pDesired);
             uint256 pOptimal = (sDesired * reserveP) / reserveS;
             if (pOptimal <= pDesired) return (sDesired, pOptimal);

```

### <a name="NC-10"></a>[NC-10] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (8)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

173:         ) revert ZeroAddress();

176:         if (tokens.length != 2) revert PoolTokensMismatch();

183:             revert PoolTokensMismatch();

187:         if (pair_ == address(0)) revert PairNotFound();

228:             revert ZeroAmount();

230:         if (to == address(0)) revert ZeroAddress();

231:         if (deadline < block.timestamp) revert Expired();

233:             revert ZeroMinimum();

```

### <a name="NC-11"></a>[NC-11] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

1: 
   Current order:
   StructDefinition.TokenInfo
   FunctionDefinition.getPoolTokens
   FunctionDefinition.getPoolTokenInfo
   FunctionDefinition.totalSupply
   FunctionDefinition.isPoolInRecoveryMode
   FunctionDefinition.isPoolPaused
   FunctionDefinition.isVaultPaused
   FunctionDefinition.enableRecoveryMode
   FunctionDefinition.removeLiquidityProportional
   FunctionDefinition.removeLiquidityRecovery
   FunctionDefinition.factory
   FunctionDefinition.addLiquidity
   FunctionDefinition.getPair
   FunctionDefinition.feeTo
   FunctionDefinition.token0
   FunctionDefinition.getReserves
   FunctionDefinition.totalSupply
   FunctionDefinition.kLast
   UsingForDirective.IERC20
   VariableDeclaration.vault
   VariableDeclaration.v3Router
   VariableDeclaration.pool
   VariableDeclaration.uniRouter
   VariableDeclaration.sUSDS
   VariableDeclaration.phUSD
   VariableDeclaration.pair
   VariableDeclaration.sUSDSIndex
   VariableDeclaration.phUSDIndex
   VariableDeclaration.MINIMUM_LIQUIDITY
   EventDefinition.Migrated
   ErrorDefinition.ZeroAddress
   ErrorDefinition.ZeroAmount
   ErrorDefinition.ZeroMinimum
   ErrorDefinition.Expired
   ErrorDefinition.PoolTokensMismatch
   ErrorDefinition.PairNotFound
   FunctionDefinition.constructor
   FunctionDefinition.migrate
   FunctionDefinition.previewMigrate
   FunctionDefinition._wouldUseRecovery
   FunctionDefinition._prepareExitMode
   FunctionDefinition._exit
   FunctionDefinition._pairState
   FunctionDefinition._optimalAmounts
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.vault
   VariableDeclaration.v3Router
   VariableDeclaration.pool
   VariableDeclaration.uniRouter
   VariableDeclaration.sUSDS
   VariableDeclaration.phUSD
   VariableDeclaration.pair
   VariableDeclaration.sUSDSIndex
   VariableDeclaration.phUSDIndex
   VariableDeclaration.MINIMUM_LIQUIDITY
   StructDefinition.TokenInfo
   ErrorDefinition.ZeroAddress
   ErrorDefinition.ZeroAmount
   ErrorDefinition.ZeroMinimum
   ErrorDefinition.Expired
   ErrorDefinition.PoolTokensMismatch
   ErrorDefinition.PairNotFound
   EventDefinition.Migrated
   FunctionDefinition.getPoolTokens
   FunctionDefinition.getPoolTokenInfo
   FunctionDefinition.totalSupply
   FunctionDefinition.isPoolInRecoveryMode
   FunctionDefinition.isPoolPaused
   FunctionDefinition.isVaultPaused
   FunctionDefinition.enableRecoveryMode
   FunctionDefinition.removeLiquidityProportional
   FunctionDefinition.removeLiquidityRecovery
   FunctionDefinition.factory
   FunctionDefinition.addLiquidity
   FunctionDefinition.getPair
   FunctionDefinition.feeTo
   FunctionDefinition.token0
   FunctionDefinition.getReserves
   FunctionDefinition.totalSupply
   FunctionDefinition.kLast
   FunctionDefinition.constructor
   FunctionDefinition.migrate
   FunctionDefinition.previewMigrate
   FunctionDefinition._wouldUseRecovery
   FunctionDefinition._prepareExitMode
   FunctionDefinition._exit
   FunctionDefinition._pairState
   FunctionDefinition._optimalAmounts

```

### <a name="NC-12"></a>[NC-12] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

138:     uint256 private constant MINIMUM_LIQUIDITY = 1000;

```

### <a name="NC-13"></a>[NC-13] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (1)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

150:     event Migrated(

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Some tokens may revert when zero value transfers are made | 3 |
| [L-2](#L-2) | Division by zero not prevented | 5 |
| [L-3](#L-3) | Signature use at deadlines should be allowed | 1 |
| [L-4](#L-4) | Possible rounding issue | 5 |
| [L-5](#L-5) | Loss of precision | 4 |
### <a name="L-1"></a>[L-1] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (3)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

236:         IERC20(pool).safeTransferFrom(msg.sender, address(this), bptAmount);

252:         if (sUSDSRefund > 0) IERC20(sUSDS).safeTransfer(msg.sender, sUSDSRefund);

253:         if (phUSDRefund > 0) IERC20(phUSD).safeTransfer(msg.sender, phUSDRefund);

```

### <a name="L-2"></a>[L-2] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (5)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

293:             sUSDSOut = (balancesRaw[sUSDSIndex] * bptAmount) / supply;

312:             expectedLiquidity = Math.min((sUSDSUsed * lpSupply) / reserveS, (phUSDUsed * lpSupply) / reserveP);

375:                 lpSupply += (lpSupply * (rootK - rootKLast)) / (rootK * 5 + rootKLast);

387:         uint256 pOptimal = (sDesired * reserveP) / reserveS;

389:         uint256 sOptimal = (pDesired * reserveS) / reserveP;

```

### <a name="L-3"></a>[L-3] Signature use at deadlines should be allowed
According to [EIP-2612](https://github.com/ethereum/EIPs/blob/71dc97318013bf2ac572ab63fab530ac9ef419ca/EIPS/eip-2612.md?plain=1#L58), signatures used on exactly the deadline timestamp are supposed to be allowed. While the signature may or may not be used for the exact EIP-2612 use case (transfer approvals), for consistency's sake, all deadlines should follow this semantic. If the timestamp is an expiration rather than a deadline, consider whether it makes more sense to include the expiration timestamp as a valid timestamp, as is done for deadlines.

*Instances (1)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

231:         if (deadline < block.timestamp) revert Expired();

```

### <a name="L-4"></a>[L-4] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (5)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

293:             sUSDSOut = (balancesRaw[sUSDSIndex] * bptAmount) / supply;

294:             phUSDOut = (balancesRaw[phUSDIndex] * bptAmount) / supply;

312:             expectedLiquidity = Math.min((sUSDSUsed * lpSupply) / reserveS, (phUSDUsed * lpSupply) / reserveP);

387:         uint256 pOptimal = (sDesired * reserveP) / reserveS;

389:         uint256 sOptimal = (pDesired * reserveS) / reserveP;

```

### <a name="L-5"></a>[L-5] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (4)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

312:             expectedLiquidity = Math.min((sUSDSUsed * lpSupply) / reserveS, (phUSDUsed * lpSupply) / reserveP);

375:                 lpSupply += (lpSupply * (rootK - rootKLast)) / (rootK * 5 + rootKLast);

387:         uint256 pOptimal = (sDesired * reserveP) / reserveS;

389:         uint256 sOptimal = (pDesired * reserveS) / reserveP;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: src/periphery/BalancerLPMigrator.sol

236:         IERC20(pool).safeTransferFrom(msg.sender, address(this), bptAmount);

```

