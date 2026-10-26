# 4naly3er Automated QA/Gas Report: sya-harvester (run 02)

> Appendix to [qa-report.md](./qa-report.md). This file is raw automated output. It is **not** triaged and does **not** carry this audit's severity labels; the bot's `L-n`/`M-n`/`NC-n`/`GAS-n` numbering is its own.
>
> - **Tool**: 4naly3er (`/home/justin/code/audits/tools/4naly3er`), `yarn analyze /home/justin/code/audits/sya-harvester/src/ <scope.txt>`. basePath is the submodule root, so imports resolve through its own `remappings.txt` (mirrors the `foundry.toml` remappings). Arg 3 is the scope list. Run read-only; `src/` is unmodified (`git status` clean).
> - **Commit**: `6b862aa0af3d3182d2fd311c4402a4056b69ef42` (https://github.com/Behodler/sya-harvester, branch `master`)
> - **Part A, production scope (2 files)**: `src/SYAHarvester.sol`, `src/interfaces/ICurveRouterNG.sol`. Same scope as run 01, so the two reports are directly comparable. No import-resolution failures. `ICurveRouterNG.sol` parsed cleanly and drew no instances.
> - **Part B, full first-party scope (18 files)**: every first-party `.sol` outside `src/lib/` (the 2 production files plus 16 test, mock, fork and test-script files), per the default-in-scope policy. All 18 files were parsed. The compiler emitted only warnings, the EIP-1153 transient-storage notice coming from `v4-core/src/libraries/CurrencyReserves.sol`, and no import-resolution failures. The extra bot items in Part B (`M-1` fee-on-transfer, `M-2` `block.number`, `M-4` `supportsInterface`, `L-1`/`L-6` approve, and others) fall only in `test/` files. They have no production impact and were not promoted.
> - **Coverage gap**: 4naly3er reads only Solidity. `script/harvest.sh` and `test/script/harvest_anvil.sh` are not covered here. They were reviewed manually; see the carried L-02, L-04 and Q-07.
> - **Reading the Part A labels**: `M-1 Centralization Risk for trusted owners`, `L-1` and `L-5` (two-step ownership) are generic owner-privilege items. Under Law 3 they are not findings in this audit. `L-3` (external call recipient may consume all gas) is the `msg.sender.call{value: ethOut}` payout at `SYAHarvester.sol:299`. The recipient is the caller, so only the caller's own transaction is affected. `L-2` (zero-value transfers) and `L-4` (PUSH0) do not apply to a mainnet-only, `cancun` deployment with the configured tokens. No bot item was promoted into the manual QA bundle. The one new manual Low, L-05 (`setRoute` swap_type range), is not detected by 4naly3er.
> - **Known false positive (unchanged from run 01)**: `GAS-7` ("state variables only set in the constructor should be `immutable`") flags `poolManager`, `sya` and `router` at L127-129. All three are already declared `immutable` (L39, L41, L43).

---

# Part A: production scope (`src/SYAHarvester.sol`, `src/interfaces/ICurveRouterNG.sol`)

# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 1 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 11 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 2 |
| [GAS-4](#GAS-4) | State variables should be cached in stack variables rather than re-reading them from storage | 2 |
| [GAS-5](#GAS-5) | For Operations that will not overflow, you could use unchecked | 34 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 3 |
| [GAS-7](#GAS-7) | State variables only set in the constructor should be declared `immutable` | 3 |
| [GAS-8](#GAS-8) | Functions guaranteed to revert when called by normal users can be marked `payable` | 2 |
| [GAS-9](#GAS-9) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 6 |
| [GAS-10](#GAS-10) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-11](#GAS-11) | Increments/decrements can be unchecked in for-loops | 6 |
| [GAS-12](#GAS-12) | Use != 0 instead of > 0 for unsigned integer comparison | 2 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

382:             debt += uint256(int256(-delta.amount1()));

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (11)*:
```solidity
File: src/SYAHarvester.sol

124:         if (address(_poolManager) == address(0) || address(_sya) == address(0) || address(_router) == address(0)) {

124:         if (address(_poolManager) == address(0) || address(_sya) == address(0) || address(_router) == address(0)) {

157:         if (token == address(0)) revert ZeroAddress();

162:         while (k < 5 && path[2 * k + 1] != address(0)) k++;

165:             if (path[i] != address(0)) revert InvalidRouteGap(i);

169:             if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);

183:                 if (pools[h] != address(0)) revert InvalidRoutePools(h);

219:         if (Currency.unwrap(key.currency0) != address(0) || Currency.unwrap(key.currency1) != sya.rewardToken()) {

276:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

279:         bool moveNft = nftIndex != 0 && nftAddr != address(0);

356:             if (token == address(0) || token == reward) continue;

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

331:         IERC20(reward).forceApprove(address(sya), 0);

364:             IERC20(token).forceApprove(address(router), 0);

```

### <a name="GAS-5"></a>[GAS-5] For Operations that will not overflow, you could use unchecked

*Instances (34)*:
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

162:         while (k < 5 && path[2 * k + 1] != address(0)) k++;

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

168:         for (uint256 i = 1; i < k; i++) {

169:             if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);

172:         address delivered = path[2 * k];

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

296:         uint256 gasCost = (g0 - gasleft() + GAS_OVERHEAD) * tx.gasprice;

326:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

336:         uint256 surplus = IERC20(reward).balanceOf(address(this)) - owed;

353:         for (uint256 i = 0; i < strategies.length; i++) {

358:             if (balance == 0) continue; // nothing delivered, or a shared token already sold

377:                     amountSpecified: -SafeCast.toInt256(surplus),

378:                     sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1

382:             debt += uint256(int256(-delta.amount1()));

397:         for (uint256 i = 0; i < list.length; i++) {

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (3)*:
```solidity
File: src/SYAHarvester.sol

287:             uint256 bal = IERC1155(nftAddr).balanceOf(address(this), nftIndex);

336:         uint256 surplus = IERC20(reward).balanceOf(address(this)) - owed;

357:             uint256 balance = IERC20(token).balanceOf(address(this));

```

### <a name="GAS-7"></a>[GAS-7] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (3)*:
```solidity
File: src/SYAHarvester.sol

127:         poolManager = _poolManager;

128:         sya = _sya;

129:         router = _router;

```

### <a name="GAS-8"></a>[GAS-8] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

200:     function clearRoute(address token) external onlyOwner {

218:     function setEthPool(PoolKey calldata key) external onlyOwner {

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

*Instances (6)*:
```solidity
File: src/SYAHarvester.sol

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

168:         for (uint256 i = 1; i < k; i++) {

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

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

*Instances (6)*:
```solidity
File: src/SYAHarvester.sol

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

168:         for (uint256 i = 1; i < k; i++) {

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

```

### <a name="GAS-12"></a>[GAS-12] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

372:         if (surplus > 0) {

391:         if (ethAmount > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Array indices should be referenced via `enum`s rather than via numeric literals | 2 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 5 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 20 |
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
| [NC-14](#NC-14) | Variables need not be initialized to zero | 4 |
### <a name="NC-1"></a>[NC-1] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

158:         if (path[0] != token) revert InvalidRouteStart(token, path[0]);

178:                 if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (5)*:
```solidity
File: src/SYAHarvester.sol

162:         while (k < 5 && path[2 * k + 1] != address(0)) k++;

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

326:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (20)*:
```solidity
File: src/SYAHarvester.sol

157:         if (token == address(0)) revert ZeroAddress();

158:         if (path[0] != token) revert InvalidRouteStart(token, path[0]);

165:             if (path[i] != address(0)) revert InvalidRouteGap(i);

169:             if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);

173:         if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);

178:                 if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);

181:                     if (swapParams[h][f] != 0) revert InvalidRouteSwapParams(h);

183:                 if (pools[h] != address(0)) revert InvalidRoutePools(h);

276:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

294:         if (ethOut < minEthOut) revert InsufficientEthOut(ethOut, minEthOut);

297:         if (ethOut < gasCost) revert Unprofitable(ethOut, gasCost);

300:         if (!ok) revert EthTransferFailed();

322:         if (msg.sender != address(poolManager)) revert NotPoolManager();

343:         if (msg.sender != address(poolManager)) revert NotPoolManager();

354:             if (_contains(exempt, strategies[i])) continue;

356:             if (token == address(0) || token == reward) continue;

358:             if (balance == 0) continue; // nothing delivered, or a shared token already sold

360:             if (!r.configured) revert RouteNotConfigured(token);

377:                     amountSpecified: -SafeCast.toInt256(surplus),

398:             if (list[i] == item) return true;

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

151:     function setRoute(
             address token,
             address[11] calldata path,
             uint256[5][5] calldata swapParams,
             address[5] calldata pools
         ) external onlyOwner {
             if (token == address(0)) revert ZeroAddress();
             if (path[0] != token) revert InvalidRouteStart(token, path[0]);
     
             // Router NG executes hop k while path[2k+1] != 0 and delivers path[2k] at the first empty pool slot.
             uint256 k;
             while (k < 5 && path[2 * k + 1] != address(0)) k++;
             // Nothing may follow the executed prefix: a trailing entry is never executed (empty when k == 5).
             for (uint256 i = 2 * k + 1; i < 11; i++) {
                 if (path[i] != address(0)) revert InvalidRouteGap(i);
             }
             // Every executed intermediate token must exist: hop i-1 outputs path[2i].
             for (uint256 i = 1; i < k; i++) {
                 if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);
             }
             address rewardToken = sya.rewardToken();
             address delivered = path[2 * k];
             if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);
             // Swap params and pools must match the executed prefix: executed rows dispatch on a real swap_type,
             // rows and pools the router never reads are zero.
             for (uint256 h = 0; h < 5; h++) {
                 if (h < k) {
                     if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);
                 } else {
                     for (uint256 f = 0; f < 5; f++) {
                         if (swapParams[h][f] != 0) revert InvalidRouteSwapParams(h);
                     }
                     if (pools[h] != address(0)) revert InvalidRoutePools(h);
                 }
             }
     
             CurveRoute storage r = routes[token];
             r.path = path;
             r.swapParams = swapParams;
             r.pools = pools;
             r.configured = true;
     
             emit RouteSet(token);

218:     function setEthPool(PoolKey calldata key) external onlyOwner {
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

200:     function clearRoute(address token) external onlyOwner {

210:     function getRoute(address token) external view returns (CurveRoute memory) {

218:     function setEthPool(PoolKey calldata key) external onlyOwner {

232:     function getEthPool() external view returns (PoolKey memory) {

271:     function harvest(address[] calldata exemptStrategies, uint256 nftIndex, uint256 minEthOut)

321:     function unlockCallback(bytes calldata data) external returns (bytes memory) {

351:     function _sellYield(address[] memory exempt, address reward) internal {

369:     function _swapSurplusAndSettle(address reward, uint256 owed, uint256 surplus) internal {

396:     function _contains(address[] memory list, address item) internal pure returns (bool) {

```

### <a name="NC-7"></a>[NC-7] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

322:         if (msg.sender != address(poolManager)) revert NotPoolManager();

343:         if (msg.sender != address(poolManager)) revert NotPoolManager();

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

125:             revert ZeroAddress();

157:         if (token == address(0)) revert ZeroAddress();

220:             revert InvalidEthPool();

276:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

300:         if (!ok) revert EthTransferFailed();

322:         if (msg.sender != address(poolManager)) revert NotPoolManager();

343:         if (msg.sender != address(poolManager)) revert NotPoolManager();

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
   ErrorDefinition.InvalidRouteGap
   ErrorDefinition.InvalidRouteToken
   ErrorDefinition.InvalidRouteSwapParams
   ErrorDefinition.InvalidRoutePools
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
   ErrorDefinition.InvalidRouteGap
   ErrorDefinition.InvalidRouteToken
   ErrorDefinition.InvalidRouteSwapParams
   ErrorDefinition.InvalidRoutePools
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

326:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

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

*Instances (4)*:
```solidity
File: src/SYAHarvester.sol

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

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

388:         IERC20(reward).safeTransfer(address(poolManager), debt);

```

### <a name="L-3"></a>[L-3] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

299:         (bool ok,) = msg.sender.call{value: ethOut}("");

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

122:         Ownable(_owner)

156:     ) external onlyOwner {

200:     function clearRoute(address token) external onlyOwner {

218:     function setEthPool(PoolKey calldata key) external onlyOwner {

```



---

# Part B: full first-party scope (18 files, including test/mocks/fork/script)

# Report (full first-party scope)


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 5 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 20 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 5 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 13 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 116 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 221 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 9 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 50 |
| [GAS-9](#GAS-9) | State variables only set in the constructor should be declared `immutable` | 4 |
| [GAS-10](#GAS-10) | Functions guaranteed to revert when called by normal users can be marked `payable` | 2 |
| [GAS-11](#GAS-11) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 30 |
| [GAS-12](#GAS-12) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-13](#GAS-13) | Increments/decrements can be unchecked in for-loops | 30 |
| [GAS-14](#GAS-14) | Use != 0 instead of > 0 for unsigned integer comparison | 6 |
| [GAS-15](#GAS-15) | `internal` functions not called by the contract should be removed | 1 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (5)*:
```solidity
File: src/SYAHarvester.sol

382:             debt += uint256(int256(-delta.amount1()));

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

361:             g += data[i] == 0 ? 4 : 16;

```

```solidity
File: test/mocks/MockSYA.sol

114:             if (received > 0) totalNormalizedYield += _normalize(received, token);

122:         totalCollected += payment;

134:             if (y > 0) totalNormalizedYield += _normalize(y, token);

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (20)*:
```solidity
File: src/SYAHarvester.sol

124:         if (address(_poolManager) == address(0) || address(_sya) == address(0) || address(_router) == address(0)) {

124:         if (address(_poolManager) == address(0) || address(_sya) == address(0) || address(_router) == address(0)) {

157:         if (token == address(0)) revert ZeroAddress();

162:         while (k < 5 && path[2 * k + 1] != address(0)) k++;

165:             if (path[i] != address(0)) revert InvalidRouteGap(i);

169:             if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);

183:                 if (pools[h] != address(0)) revert InvalidRoutePools(h);

219:         if (Currency.unwrap(key.currency0) != address(0) || Currency.unwrap(key.currency1) != sya.rewardToken()) {

276:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

279:         bool moveNft = nftIndex != 0 && nftAddr != address(0);

356:             if (token == address(0) || token == reward) continue;

```

```solidity
File: test/mocks/MockCurveRouter.sol

47:         if (_route[1] == address(0)) revert NoHop();

51:             if (i == 4 || _route[2 * i + 3] == address(0)) break;

52:             if (tokenOut == address(0)) revert ZeroIntermediateToken();

54:         if (tokenOut == address(0)) revert ZeroOutputToken();

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

51:         for (uint256 h = 0; h < 5 && path[2 * h + 1] != address(0); h++) {

```

```solidity
File: test/mocks/MockSYA.sol

98:             require(nftMinter != address(0), "NFT minter not configured");

102:         } else if (nftMinter != address(0) && nftIndex != 0) {

148:         if (token == address(0)) return true;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

44:         if (address(nestPoolManager) != address(0)) {

```

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (5)*:
```solidity
File: test/fork/SYAHarvester.fork.t.sol

75:     bool internal unlockCallbackHit;

```

```solidity
File: test/mocks/MockERC1155.sol

14:     mapping(address => bool) public authorizedBurners;

```

```solidity
File: test/mocks/MockSYA.sol

53:     mapping(address => bool) public isRegisteredStrategy;

54:     mapping(address => bool) public tokenPaused;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

20:     bool public paused;

```

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (13)*:
```solidity
File: src/SYAHarvester.sol

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

140:         for (uint256 i = 0; i < strategies.length; i++) {

165:         for (uint256 i = 0; i < withCode.length; i++) {

188:         for (uint256 i = 0; i < strategies.length; i++) {

255:         for (uint256 i = 0; i < fees.length; i++) {

274:         for (uint256 i = 0; i < strategies.length; i++) {

321:         for (uint256 i = 0; i < strategies.length; i++) {

360:         for (uint256 i = 0; i < data.length; i++) {

```

```solidity
File: test/mocks/MockSYA.sol

109:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

129:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

142:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

150:         for (uint256 j = 0; j < exemptStrategies.length; j++) {

```

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (116)*:
```solidity
File: src/SYAHarvester.sol

331:         IERC20(reward).forceApprove(address(sya), 0);

364:             IERC20(token).forceApprove(address(router), 0);

```

```solidity
File: test/SYAHarvester.nft.t.sol

48:         vm.expectCall(address(nft), _refundCallPrefix(), 0);

```

```solidity
File: test/SYAHarvester.registry.t.sol

137:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

138:         harvester.setRoute(usde, _singleHop(usde), _params(), _pools());

143:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

149:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

167:         harvester.setRoute(usde, _singleHop(dola), _params(), _pools());

176:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));

177:         harvester.setRoute(usde, path, _params(), _pools());

184:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, dola));

185:         harvester.setRoute(usde, path, _params(), _pools());

200:         path[5] = pool0;

202:         path[7] = pool1;

204:         path[9] = pool0;

218:         harvester.setRoute(usde, path, _params(), _pools());

228:         path[10] = usdc;

231:         harvester.setRoute(usde, path, _params(), _pools());

239:         harvester.setRoute(usde, path, _params(), _pools());

249:         path[6] = usdc; // path[5] == 0: the route ends at path[4]; path[6] is a trailing entry

252:         harvester.setRoute(usde, path, _params(), _pools());

267:         harvester.setRoute(usde, path, _params(), _pools());

275:         harvester.setRoute(usde, path, _params(), _pools());

281:         harvester.setRoute(usde, path, _params(5), _pools(5));

283:         SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);

293:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));

294:         harvester.setRoute(usde, path, _params(5), _pools(5));

302:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, usde));

303:         harvester.setRoute(usde, path, _params(), _pools());

313:         harvester.setRoute(usde, path, _params(), _pools());

322:         harvester.setRoute(usdc, path, _params(0), _pools(0));

324:         SYAHarvester.CurveRoute memory r = harvester.getRoute(usdc);

326:         assertEq(r.path[0], usdc);

336:         harvester.setRoute(usdc, path, _params(), _pools());

342:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, other, usdc));

343:         harvester.setRoute(usde, _singleHop(usde), _params(), _pools());

352:         harvester.setRoute(usde, path, params, pools);

354:         SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);

371:         harvester.setRoute(dola, path, _params(), _pools());

373:         SYAHarvester.CurveRoute memory r = harvester.getRoute(dola);

375:         assertEq(r.path[0], dola);

386:         harvester.setRoute(usde, _singleHop(usde), _params(1), _pools(1));

402:         harvester.setRoute(usde, path, _params(2), _pools(2));

412:         path[5] = pool0;

414:         path[7] = pool1;

418:         harvester.setRoute(usde, path, _params(4), _pools(4));

427:         harvester.setRoute(usde, path, _params(2), _pools(2));

435:         harvester.setRoute(usde, _singleHop(usde), p, _pools(1));

443:         harvester.setRoute(usde, _multiHop(usde), p, _pools(2));

451:         harvester.setRoute(usde, _fiveHop(usde, usdc), p, _pools(5));

458:         harvester.setRoute(usde, _singleHop(usde), _params(), _pools(1));

467:         harvester.setRoute(usde, _singleHop(usde), p, _pools(1));

475:         harvester.setRoute(usde, _singleHop(usde), _params(1), pools);

483:         harvester.setRoute(usde, _multiHop(usde), _params(2), pools);

492:         harvester.setRoute(usde, _singleHop(usde), _params(), pools);

503:         harvester.setRoute(usde, _singleHop(usde), p, pools);

510:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));

511:         harvester.setRoute(usde, path, _params(), _pools());

519:         harvester.setRoute(usdc, path, _params(1), _pools(0));

527:         harvester.setRoute(usdc, path, _params(0), _pools(1));

534:         harvester.setRoute(usde, path, p, _pools(5));

536:         SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);

551:         harvester.setRoute(usde, path, p, pools);

553:         SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);

572:         harvester.setRoute(usdc, path, p, pools);

573:         assertTrue(harvester.getRoute(usdc).configured);

588:         harvester.setRoute(usde, _singleHop(usde), _params(1), _pools(1));

591:         emit RouteCleared(usde);

592:         vm.prank(owner);

593:         harvester.clearRoute(usde);

595:         SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);

632:         assertEq(Currency.unwrap(stored.currency1), usdc);

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

92:         vm.startPrank(owner);

93:         MainnetRoutes.configure(harvester);

101:         vm.prank(keeper);

102:         nft.setApprovalForAll(address(harvester), true);

128:         vm.prank(keeper, keeper);

134:         assertEq(IERC20(A.USDC).balanceOf(address(harvester)), 0, "harvester USDC");

135:         assertEq(IERC20(A.DOLA).balanceOf(address(harvester)), 0, "harvester DOLA");

136:         assertEq(IERC20(A.USDE).balanceOf(address(harvester)), 0, "harvester USDe");

137:         assertEq(IERC20(A.CRVUSD).balanceOf(address(harvester)), 0, "harvester crvUSD");

138:         assertEq(IERC20(A.FRAX).balanceOf(address(harvester)), 0, "harvester FRAX");

142:             assertEq(IERC20(token).balanceOf(address(harvester)), 0, "harvester strategy token");

144:         assertEq(nft.balanceOf(address(harvester), A.NFT_INDEX), 0, "harvester NFT");

296:         assertEq(nft.balanceOf(keeper, A.NFT_INDEX), nftBefore - 1, "caller NFT unit");

342:         vm.prank(keeper, keeper);

350:         vm.prank(keeper, keeper);

378:         vm.prank(keeper, keeper);

389:         vm.prank(keeper, keeper);

391:         (ok, ret) = address(harvester).call(data);

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

39:         mid2.mint(address(router), 1e30);

40:         mid3.mint(address(router), 1e30);

41:         mid4.mint(address(router), 1e30);

42:         tokenOut.mint(address(router), 1e30);

46:         tokenIn.approve(address(router), type(uint256).max);

73:         assertEq(mid.balanceOf(receiver), 0);

74:         assertEq(router.calls(address(tokenIn)), 1);

89:         assertEq(tokenOut.balanceOf(receiver), 0, "trailing entry is never delivered");

105:         assertEq(tokenOut.balanceOf(receiver), 0);

115:         path[5] = pool0;

117:         path[7] = pool1;

119:         path[9] = pool0;

125:         assertEq(mid4.balanceOf(receiver), 0);

177:         path[5] = pool0; // path[4] == 0 inside the executed prefix (k = 3)

211:         assertEq(tokenOut.balanceOf(receiver), AMOUNT);

```

```solidity
File: test/mocks/MockSYA.sol

101:             IMockNFTMinter(nftMinter).burn(msg.sender, nftIndex, 1);

103:             nftBalanceSeenInClaim = IERC1155(nftMinter).balanceOf(msg.sender, nftIndex);

121:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), payment);

```

```solidity
File: test/utils/HarvesterFixture.sol

64:         sya = new MockSYA(address(usdc));

74:             ICurveRouterNG(address(router))

77:         usdeStrategy = _addStrategy(usde, USDE_YIELD);

79:         vm.startPrank(owner);

81:         harvester.setRoute(address(usde), _path(address(usde)), _params(), _pools());

114:         assertEq(usdc.balanceOf(address(harvester)), 0, "harvester USDC");

115:         assertEq(usde.balanceOf(address(harvester)), 0, "harvester USDe");

116:         assertEq(dola.balanceOf(address(harvester)), 0, "harvester DOLA");

```

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (221)*:
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

162:         while (k < 5 && path[2 * k + 1] != address(0)) k++;

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

168:         for (uint256 i = 1; i < k; i++) {

169:             if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);

172:         address delivered = path[2 * k];

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

296:         uint256 gasCost = (g0 - gasleft() + GAS_OVERHEAD) * tx.gasprice;

326:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

336:         uint256 surplus = IERC20(reward).balanceOf(address(this)) - owed;

353:         for (uint256 i = 0; i < strategies.length; i++) {

358:             if (balance == 0) continue; // nothing delivered, or a shared token already sold

377:                     amountSpecified: -SafeCast.toInt256(surplus),

378:                     sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1

382:             debt += uint256(int256(-delta.amount1()));

397:         for (uint256 i = 0; i < list.length; i++) {

```

```solidity
File: test/SYAHarvester.gas.t.sol

4: import {HarvesterFixture} from "./utils/HarvesterFixture.sol";

52:         assertEq(gasCost % price, 0, "gasCost is units * tx.gasprice");

53:         units = gasCost / price;

58:         uint256 price = 1e6; // ~3e11 wei of gas against ~9e7 wei out

77:         assertEq(keeper.balance - before, ethOut, "paid");

89:         assertGt(units, overhead + 100_000, "measured gas spans the harvest");

90:         assertLt(units, overhead + 2_000_000, "measured gas is sane");

95:         uint256 breakEven = ethOut / units;

96:         assertGt(breakEven, 20, "harness gives a usable break-even price");

99:         (bool okBelow,) = _harvestAt(breakEven * 9 / 10);

100:         assertTrue(okBelow, "10% below break-even passes");

103:         (bool okAbove, bytes memory ret) = _harvestAt(breakEven * 11 / 10);

104:         assertFalse(okAbove, "10% above break-even fails");

```

```solidity
File: test/SYAHarvester.harvest.t.sol

4: import {stdError} from "forge-std/StdError.sol";

5: import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

6: import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

8: import {SYAHarvester} from "../src/SYAHarvester.sol";

9: import {ICurveRouterNG} from "../src/interfaces/ICurveRouterNG.sol";

10: import {HarvesterFixture} from "./utils/HarvesterFixture.sol";

27:         assertEq(keeper.balance - before, ethOut, "keeper received ethOut");

53:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InsufficientEthOut.selector, ethOut, ethOut + 1));

55:         harvester.harvest(_none(), 1, ethOut + 1);

63:         _addStrategy(dola, DOLA_YIELD); // no route registered for DOLA

71:         usdcStrategy = _addStrategy(usdc, USDC_YIELD); // pays SYA's reward token directly, no route

87:         dolaStrategy.setPaused(true); // a misbehaving strategy would revert the whole claim

103:         dolaStrategy = _addStrategy(dola, DOLA_YIELD); // no route registered for DOLA

129:         assertFalse(ok, "ETH from non-PoolManager accepted");

```

```solidity
File: test/SYAHarvester.nft.t.sol

4: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

5: import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

6: import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

7: import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

9: import {HarvesterFixture} from "./utils/HarvesterFixture.sol";

10: import {MockERC1155} from "./mocks/MockERC1155.sol";

11: import {MockSYA} from "./mocks/MockSYA.sol";

54:         assertEq(nft.balanceOf(keeper, NFT_INDEX), before - 1, "caller lost exactly one unit");

56:         assertEq(nft.totalSupply(NFT_INDEX), before - 1, "unit burned, not parked");

61:                     POST GATING-OFF: SYA IGNORES THE NFT

89:         assertEq(nft.balanceOf(keeper, NFT_INDEX), before + 1, "caller receives the whole balance");

```

```solidity
File: test/SYAHarvester.registry.t.sol

4: import {Test} from "forge-std/Test.sol";

5: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

6: import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

7: import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

8: import {PoolKey} from "v4-core/src/types/PoolKey.sol";

9: import {Currency} from "v4-core/src/types/Currency.sol";

10: import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

12: import {SYAHarvester} from "../src/SYAHarvester.sol";

13: import {ICurveRouterNG} from "../src/interfaces/ICurveRouterNG.sol";

14: import {MockSYA} from "./mocks/MockSYA.sol";

75:         for (uint256 h = 0; h < k; h++) {

189:                ROUTER NG CONTIGUITY (audit 01, M-01)

236:         path[4] = other; // never executed: path[3] == 0 ends the route at path[2]

249:         path[6] = usdc; // path[5] == 0: the route ends at path[4]; path[6] is a trailing entry

272:         path[5] = pool1; // a pool slot after the executed prefix is still a trailing entry

285:         for (uint256 i = 0; i < 11; i++) {

356:         for (uint256 i = 0; i < 11; i++) {

359:         for (uint256 i = 0; i < 5; i++) {

361:             for (uint256 j = 0; j < 5; j++) {

390:         ROUTE TOKEN / SWAP PARAMS / POOLS CONSISTENCY (audit 01, M-01 residual + mitigation 2)

424:         path[4] = other; // also delivers a non-reward token: the zero intermediate is reported first

440:         p[1][2] = 0; // i/j/pool_type/n_coins still set: only swap_type decides "executed row non-empty"

538:         for (uint256 h = 0; h < 5; h++) {

540:             for (uint256 f = 0; f < 5; f++) {

555:         for (uint256 i = 0; i < 11; i++) {

558:         for (uint256 h = 0; h < 5; h++) {

560:             for (uint256 f = 0; f < 5; f++) {

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

4: import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

6: import {SYAHarvester} from "../src/SYAHarvester.sol";

7: import {HarvesterFixture} from "./utils/HarvesterFixture.sol";

```

```solidity
File: test/Toolchain.t.sol

4: import {Deployers} from "v4-core/test/utils/Deployers.sol";

```

```solidity
File: test/fork/MainnetAddresses.sol

32:     address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // mainnet-addresses.ts

33:     address internal constant DOLA = 0x865377367054516e17014CcdED1e7d814EDC9ce4; // mainnet-addresses.ts

34:     address internal constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3; // mainnet-addresses.ts

35:     address internal constant CRVUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E; // archive scripts

36:     address internal constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e; // fork (FRAXBP coin0)

39:     address internal constant CURVE_ROUTER_NG = 0x16C6521Dff6baB339122a0FE25a9116693265353; // archive scripts

41:     address internal constant CURVE_META_REGISTRY = 0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC; // fork

```

```solidity
File: test/fork/MainnetRoutes.sol

4: import {PoolKey} from "v4-core/src/types/PoolKey.sol";

5: import {Currency} from "v4-core/src/types/Currency.sol";

6: import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

7: import {SYAHarvester} from "../../src/SYAHarvester.sol";

8: import {MainnetAddresses as A} from "./MainnetAddresses.sol";

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

4: import {Test, console2} from "forge-std/Test.sol";

5: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

7: import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

8: import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";

9: import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

10: import {PoolKey} from "v4-core/src/types/PoolKey.sol";

11: import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

12: import {Currency} from "v4-core/src/types/Currency.sol";

13: import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

14: import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

16: import {SYAHarvester} from "../../src/SYAHarvester.sol";

17: import {ICurveRouterNG} from "../../src/interfaces/ICurveRouterNG.sol";

18: import {MainnetAddresses as A} from "./MainnetAddresses.sol";

19: import {MainnetRoutes} from "./MainnetRoutes.sol";

20: import {MockCurveRouter} from "../mocks/MockCurveRouter.sol";

106:         vm.warp(block.timestamp + ACCRUAL_WARP);

107:         vm.roll(block.number + ACCRUAL_WARP / 12);

140:         for (uint256 i = 0; i < strategies.length; i++) {

165:         for (uint256 i = 0; i < withCode.length; i++) {

188:         for (uint256 i = 0; i < strategies.length; i++) {

193:             assertTrue(harvester.getRoute(token).configured, "non-reward strategy token without a route");

194:             routed++;

237:         console2.log("20 USDe -> USDC (6dp)", u20);

238:         console2.log("20 DOLA -> USDC (6dp)", d20);

239:         console2.log("1000 DOLA -> USDC (6dp)", d1000);

255:         for (uint256 i = 0; i < fees.length; i++) {

274:         for (uint256 i = 0; i < strategies.length; i++) {

295:         assertEq(keeper.balance - keeperEthBefore, ethOut, "caller received ethOut");

296:         assertEq(nft.balanceOf(keeper, A.NFT_INDEX), nftBefore - 1, "caller NFT unit");

297:         assertEq(ITotalSupply1155(A.NFT_MINTER).totalSupply(A.NFT_INDEX), supplyBefore - 1, "NFT unit burned");

315:         assertGt(ethOut, 0, "USDe-only harvest paid ETH: no AlreadyUnlocked from a nested unlock");

321:         for (uint256 i = 0; i < strategies.length; i++) {

360:         for (uint256 i = 0; i < data.length; i++) {

361:             g += data[i] == 0 ? 4 : 16;

381:         uint256 executionGas = before - gasleft();

383:         uint256 realGas = 21_000 + _calldataGas(data) + executionGas;

398:         uint256 inContract = gasCost / price - harvester.GAS_OVERHEAD();

400:         uint256 gap = realGas - inContract;

402:         console2.log("in-contract estimate", inContract);

407:         assertLe(harvester.GAS_OVERHEAD(), gap + 25_000, "GAS_OVERHEAD over-padded");

434:         vm.txGasPrice(0); // isolate the route effect from the gas-profitability gate

437:         _assertHarvesterEmpty(); // includes crvUSD, the USDe route's intermediate token

453:         uint256 crvGot = IERC20(A.CRVUSD).balanceOf(address(this)) - crvBefore;

467:         assertEq(IERC20(A.CRVUSD).balanceOf(address(this)) - crvBefore, amount, "mock delivered crvUSD too");

533:         params[1][2] = 0; // hop 1 (crvUSD -> USDC) executed with swap_type 0

```

```solidity
File: test/mocks/MockCurveRouter.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

48:         for (uint256 i = 0; i < 5; i++) {

49:             tokenOut = _route[2 * i + 2];

50:             hops = i + 1;

51:             if (i == 4 || _route[2 * i + 3] == address(0)) break;

67:         for (uint256 h = 0; h < hops; h++) {

70:         calls[tokenIn]++;

72:         out = _amount * rate[tokenIn] / 1e18;

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

4: import {Test} from "forge-std/Test.sol";

5: import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

7: import {MockCurveRouter} from "./MockCurveRouter.sol";

51:         for (uint256 h = 0; h < 5 && path[2 * h + 1] != address(0); h++) {

155:         vm.expectRevert(abi.encodeWithSelector(MockCurveRouter.Slippage.selector, AMOUNT, AMOUNT + 1));

156:         router.exchange(path, _rows(path), AMOUNT, AMOUNT + 1, pools, receiver);

177:         path[5] = pool0; // path[4] == 0 inside the executed prefix (k = 3)

```

```solidity
File: test/mocks/MockERC1155.sol

4: import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

5: import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

```

```solidity
File: test/mocks/MockSYA.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

47:     uint256 public discountRate = 1000; // 10%

109:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

114:             if (received > 0) totalNormalizedYield += _normalize(received, token);

118:         uint256 payment = _denormalize(totalNormalizedYield * (10000 - discountRate) / 10000, rewardToken);

122:         totalCollected += payment;

129:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

134:             if (y > 0) totalNormalizedYield += _normalize(y, token);

137:         uint256 payment = _denormalize(totalNormalizedYield * (10000 - discountRate) / 10000, rewardToken);

138:         return payment * (10000 + overEstimateBps) / 10000;

142:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

150:         for (uint256 j = 0; j < exemptStrategies.length; j++) {

158:         return d <= 18 ? amount * 10 ** (18 - d) : amount / 10 ** (d - 18);

163:         return d <= 18 ? amount / 10 ** (18 - d) : amount * 10 ** (d - 18);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

```

```solidity
File: test/script/DeployHarvesterForTest.s.sol

4: import {Script, console2} from "forge-std/Script.sol";

5: import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

6: import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

8: import {SYAHarvester} from "../../src/SYAHarvester.sol";

9: import {ICurveRouterNG} from "../../src/interfaces/ICurveRouterNG.sol";

10: import {MainnetAddresses as A} from "../fork/MainnetAddresses.sol";

11: import {MainnetRoutes} from "../fork/MainnetRoutes.sol";

```

```solidity
File: test/utils/HarvesterFixture.sol

4: import {Deployers} from "v4-core/test/utils/Deployers.sol";

5: import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

6: import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

7: import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

8: import {PoolKey} from "v4-core/src/types/PoolKey.sol";

9: import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";

10: import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

12: import {SYAHarvester} from "../../src/SYAHarvester.sol";

13: import {ICurveRouterNG} from "../../src/interfaces/ICurveRouterNG.sol";

14: import {MockSYA} from "../mocks/MockSYA.sol";

15: import {MockYieldStrategy} from "../mocks/MockYieldStrategy.sol";

16: import {MockCurveRouter} from "../mocks/MockCurveRouter.sol";

41:     uint256 internal constant USDE_YIELD = 1000e18; // ~1000 USDC of value at rate 1:1

67:         router.setRate(address(usde), 1e6); // 1 USDe -> 1 USDC

68:         router.setRate(address(dola), 1e6); // 1 DOLA -> 1 USDC

```

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (9)*:
```solidity
File: test/SYAHarvester.gas.t.sol

34:         require(ret.length == 68, "not Unprofitable(uint256,uint256)");

41:         require(sel == UNPROFITABLE, "wrong selector");

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

113:         require(msg.sender == address(pm), "not pm");

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

134:         vm.expectRevert(abi.encodeWithSignature("NoHop()"));

144:         vm.expectRevert(abi.encodeWithSignature("ZeroOutputToken()"));

167:         vm.expectRevert(abi.encodeWithSignature("ZeroIntermediateToken()"));

180:         vm.expectRevert(abi.encodeWithSignature("ZeroIntermediateToken()"));

```

```solidity
File: test/mocks/MockSYA.sol

98:             require(nftMinter != address(0), "NFT minter not configured");

99:             require(nftIndex > 0, "Invalid index");

```

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (50)*:
```solidity
File: src/SYAHarvester.sol

287:             uint256 bal = IERC1155(nftAddr).balanceOf(address(this), nftIndex);

336:         uint256 surplus = IERC20(reward).balanceOf(address(this)) - owed;

357:             uint256 balance = IERC20(token).balanceOf(address(this));

```

```solidity
File: test/SYAHarvester.harvest.t.sol

97:         assertEq(dola.balanceOf(address(dolaStrategy)), DOLA_YIELD, "exempt tokens stay in strategy");

```

```solidity
File: test/SYAHarvester.nft.t.sol

43:         uint256 before = nft.balanceOf(keeper, NFT_INDEX);

54:         assertEq(nft.balanceOf(keeper, NFT_INDEX), before - 1, "caller lost exactly one unit");

55:         assertEq(nft.balanceOf(address(harvester), NFT_INDEX), 0, "harvester holds none");

66:         uint256 before = nft.balanceOf(keeper, NFT_INDEX);

72:         assertEq(nft.balanceOf(keeper, NFT_INDEX), before, "caller balance unchanged");

73:         assertEq(nft.balanceOf(address(harvester), NFT_INDEX), 0, "harvester holds none");

79:         uint256 before = nft.balanceOf(keeper, NFT_INDEX);

89:         assertEq(nft.balanceOf(keeper, NFT_INDEX), before + 1, "caller receives the whole balance");

90:         assertEq(nft.balanceOf(address(harvester), NFT_INDEX), 0, "harvester holds none");

143:         assertEq(nft.balanceOf(keeper, NFT_INDEX), 1, "burned one unit");

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

47:         assertGt(crvusd.balanceOf(receiver), 0, "intermediate delivered");

48:         assertEq(usdc.balanceOf(receiver), 0, "reward token not delivered");

63:         assertEq(crvusd.balanceOf(address(harvester)), 0, "harvester crvUSD");

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

134:         assertEq(IERC20(A.USDC).balanceOf(address(harvester)), 0, "harvester USDC");

135:         assertEq(IERC20(A.DOLA).balanceOf(address(harvester)), 0, "harvester DOLA");

136:         assertEq(IERC20(A.USDE).balanceOf(address(harvester)), 0, "harvester USDe");

137:         assertEq(IERC20(A.CRVUSD).balanceOf(address(harvester)), 0, "harvester crvUSD");

138:         assertEq(IERC20(A.FRAX).balanceOf(address(harvester)), 0, "harvester FRAX");

142:             assertEq(IERC20(token).balanceOf(address(harvester)), 0, "harvester strategy token");

144:         assertEq(nft.balanceOf(address(harvester), A.NFT_INDEX), 0, "harvester NFT");

286:         uint256 nftBefore = nft.balanceOf(keeper, A.NFT_INDEX);

296:         assertEq(nft.balanceOf(keeper, A.NFT_INDEX), nftBefore - 1, "caller NFT unit");

450:         uint256 crvBefore = IERC20(A.CRVUSD).balanceOf(address(this));

451:         uint256 usdcBefore = IERC20(A.USDC).balanceOf(address(this));

453:         uint256 crvGot = IERC20(A.CRVUSD).balanceOf(address(this)) - crvBefore;

456:         assertEq(IERC20(A.USDC).balanceOf(address(this)), usdcBefore, "real Router NG delivered no USDC");

465:         crvBefore = IERC20(A.CRVUSD).balanceOf(address(this));

467:         assertEq(IERC20(A.CRVUSD).balanceOf(address(this)) - crvBefore, amount, "mock delivered crvUSD too");

468:         assertEq(IERC20(A.USDC).balanceOf(address(this)), usdcBefore, "mock delivered no USDC");

513:         uint256 usdcBefore = IERC20(A.USDC).balanceOf(address(this));

521:         assertEq(IERC20(A.USDC).balanceOf(address(this)), usdcBefore, "no USDC delivered");

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

72:         assertEq(tokenOut.balanceOf(receiver), AMOUNT, "delivered path[4]");

73:         assertEq(mid.balanceOf(receiver), 0);

75:         assertEq(tokenIn.balanceOf(address(router)), AMOUNT, "input pulled");

88:         assertEq(mid.balanceOf(receiver), AMOUNT, "delivered path[2], the intermediate");

89:         assertEq(tokenOut.balanceOf(receiver), 0, "trailing entry is never delivered");

104:         assertEq(mid2.balanceOf(receiver), AMOUNT, "delivered path[4]");

105:         assertEq(tokenOut.balanceOf(receiver), 0);

124:         assertEq(tokenOut.balanceOf(receiver), AMOUNT, "delivered path[10]");

125:         assertEq(mid4.balanceOf(receiver), 0);

211:         assertEq(tokenOut.balanceOf(receiver), AMOUNT);

```

```solidity
File: test/mocks/MockSYA.sol

100:             if (IERC1155(nftMinter).balanceOf(msg.sender, nftIndex) == 0) revert NoValidNFT();

103:             nftBalanceSeenInClaim = IERC1155(nftMinter).balanceOf(msg.sender, nftIndex);

```

```solidity
File: test/utils/HarvesterFixture.sol

114:         assertEq(usdc.balanceOf(address(harvester)), 0, "harvester USDC");

115:         assertEq(usde.balanceOf(address(harvester)), 0, "harvester USDe");

116:         assertEq(dola.balanceOf(address(harvester)), 0, "harvester DOLA");

```

### <a name="GAS-9"></a>[GAS-9] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (4)*:
```solidity
File: src/SYAHarvester.sol

127:         poolManager = _poolManager;

128:         sya = _sya;

129:         router = _router;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

24:         token = _token;

```

### <a name="GAS-10"></a>[GAS-10] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

200:     function clearRoute(address token) external onlyOwner {

218:     function setEthPool(PoolKey calldata key) external onlyOwner {

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

*Instances (30)*:
```solidity
File: src/SYAHarvester.sol

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

168:         for (uint256 i = 1; i < k; i++) {

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

```

```solidity
File: test/SYAHarvester.registry.t.sol

75:         for (uint256 h = 0; h < k; h++) {

285:         for (uint256 i = 0; i < 11; i++) {

356:         for (uint256 i = 0; i < 11; i++) {

359:         for (uint256 i = 0; i < 5; i++) {

361:             for (uint256 j = 0; j < 5; j++) {

538:         for (uint256 h = 0; h < 5; h++) {

540:             for (uint256 f = 0; f < 5; f++) {

555:         for (uint256 i = 0; i < 11; i++) {

558:         for (uint256 h = 0; h < 5; h++) {

560:             for (uint256 f = 0; f < 5; f++) {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

140:         for (uint256 i = 0; i < strategies.length; i++) {

165:         for (uint256 i = 0; i < withCode.length; i++) {

188:         for (uint256 i = 0; i < strategies.length; i++) {

194:             routed++;

255:         for (uint256 i = 0; i < fees.length; i++) {

274:         for (uint256 i = 0; i < strategies.length; i++) {

321:         for (uint256 i = 0; i < strategies.length; i++) {

360:         for (uint256 i = 0; i < data.length; i++) {

```

```solidity
File: test/mocks/MockCurveRouter.sol

48:         for (uint256 i = 0; i < 5; i++) {

67:         for (uint256 h = 0; h < hops; h++) {

```

```solidity
File: test/mocks/MockSYA.sol

109:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

129:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

142:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

150:         for (uint256 j = 0; j < exemptStrategies.length; j++) {

```

### <a name="GAS-12"></a>[GAS-12] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

46:     uint256 public constant BORROW_BUFFER_BPS = 100;

60:     uint256 public constant GAS_OVERHEAD = 60_000;

```

### <a name="GAS-13"></a>[GAS-13] Increments/decrements can be unchecked in for-loops
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

*Instances (30)*:
```solidity
File: src/SYAHarvester.sol

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

168:         for (uint256 i = 1; i < k; i++) {

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

```

```solidity
File: test/SYAHarvester.registry.t.sol

75:         for (uint256 h = 0; h < k; h++) {

285:         for (uint256 i = 0; i < 11; i++) {

356:         for (uint256 i = 0; i < 11; i++) {

359:         for (uint256 i = 0; i < 5; i++) {

361:             for (uint256 j = 0; j < 5; j++) {

538:         for (uint256 h = 0; h < 5; h++) {

540:             for (uint256 f = 0; f < 5; f++) {

555:         for (uint256 i = 0; i < 11; i++) {

558:         for (uint256 h = 0; h < 5; h++) {

560:             for (uint256 f = 0; f < 5; f++) {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

140:         for (uint256 i = 0; i < strategies.length; i++) {

165:         for (uint256 i = 0; i < withCode.length; i++) {

188:         for (uint256 i = 0; i < strategies.length; i++) {

255:         for (uint256 i = 0; i < fees.length; i++) {

274:         for (uint256 i = 0; i < strategies.length; i++) {

321:         for (uint256 i = 0; i < strategies.length; i++) {

360:         for (uint256 i = 0; i < data.length; i++) {

```

```solidity
File: test/mocks/MockCurveRouter.sol

48:         for (uint256 i = 0; i < 5; i++) {

67:         for (uint256 h = 0; h < hops; h++) {

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

51:         for (uint256 h = 0; h < 5 && path[2 * h + 1] != address(0); h++) {

```

```solidity
File: test/mocks/MockSYA.sol

109:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

129:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

142:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

150:         for (uint256 j = 0; j < exemptStrategies.length; j++) {

```

### <a name="GAS-14"></a>[GAS-14] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (6)*:
```solidity
File: src/SYAHarvester.sol

372:         if (surplus > 0) {

391:         if (ethAmount > 0) {

```

```solidity
File: test/mocks/MockSYA.sol

99:             require(nftIndex > 0, "Invalid index");

114:             if (received > 0) totalNormalizedYield += _normalize(received, token);

134:             if (y > 0) totalNormalizedYield += _normalize(y, token);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

49:         if (amount > 0) {

```

### <a name="GAS-15"></a>[GAS-15] `internal` functions not called by the contract should be removed
If the functions are required by an interface, the contract should inherit from that interface and use the `override` keyword

*Instances (1)*:
```solidity
File: test/fork/MainnetRoutes.sol

103:     function configure(SYAHarvester harvester) internal {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 50 |
| [NC-2](#NC-2) | Missing checks for `address(0)` when assigning values to address state variables | 4 |
| [NC-3](#NC-3) | Array indices should be referenced via `enum`s rather than via numeric literals | 220 |
| [NC-4](#NC-4) | `constant`s should be defined rather than using magic numbers | 104 |
| [NC-5](#NC-5) | Control structures do not follow the Solidity Style Guide | 45 |
| [NC-6](#NC-6) | Consider disabling `renounceOwnership()` | 1 |
| [NC-7](#NC-7) | Draft Dependencies | 1 |
| [NC-8](#NC-8) | Events that mark critical parameter changes should contain both the old and the new value | 2 |
| [NC-9](#NC-9) | Function ordering does not follow the Solidity style guide | 7 |
| [NC-10](#NC-10) | Functions should not be longer than 50 lines | 178 |
| [NC-11](#NC-11) | Interfaces should be defined in separate files from their usage | 7 |
| [NC-12](#NC-12) | Lack of checks in setters | 60 |
| [NC-13](#NC-13) | Missing Event for critical parameters change | 57 |
| [NC-14](#NC-14) | NatSpec is completely non-existent on functions that should have them | 119 |
| [NC-15](#NC-15) | Incomplete NatSpec: `@param` is missing on actually documented functions | 2 |
| [NC-16](#NC-16) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 5 |
| [NC-17](#NC-17) | Constant state variables defined more than once | 2 |
| [NC-18](#NC-18) | Consider using named mappings | 7 |
| [NC-19](#NC-19) | `address`s shouldn't be hard-coded | 21 |
| [NC-20](#NC-20) | Take advantage of Custom Error's return value property | 43 |
| [NC-21](#NC-21) | Contract does not follow the Solidity style guide's suggested layout ordering | 9 |
| [NC-22](#NC-22) | Use Underscores for Number Literals (add an underscore every 3 digits) | 12 |
| [NC-23](#NC-23) | Internal and private variables and functions names should begin with an underscore | 54 |
| [NC-24](#NC-24) | Event is missing `indexed` fields | 2 |
| [NC-25](#NC-25) | Constants should be defined rather than using magic numbers | 2 |
| [NC-26](#NC-26) | `public` functions not called by the contract should be declared `external` instead | 116 |
| [NC-27](#NC-27) | Variables need not be initialized to zero | 28 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (50)*:
```solidity
File: test/SYAHarvester.harvest.t.sol

53:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InsufficientEthOut.selector, ethOut, ethOut + 1));

65:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.RouteNotConfigured.selector, address(dola)));

```

```solidity
File: test/SYAHarvester.nft.t.sol

34:         return abi.encodeWithSelector(IERC1155.safeTransferFrom.selector, address(harvester));

129:             abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(harvester), keeper)

```

```solidity
File: test/SYAHarvester.registry.t.sol

125:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));

137:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

143:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

149:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

166:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteStart.selector, usde, dola));

176:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));

184:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, dola));

217:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

230:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

238:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 4));

251:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));

266:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));

274:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 5));

293:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));

302:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, usde));

312:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));

335:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));

342:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, other, usdc));

401:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));

417:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 6));

426:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));

434:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 0));

442:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));

450:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 4));

457:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));

466:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 3));

474:         vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 1));

482:         vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 4));

491:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));

502:         vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 1));

510:         vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));

518:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 0));

526:         vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 0));

639:         (bool ok,) = address(harvester).call(abi.encodeWithSignature("harvest(uint256,uint256,address[])", 0, 0, new address[](0)));

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

32:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

424:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

525:         assertEq(ret, abi.encodeWithSignature("ZeroIntermediateToken()"));

540:         assertEq(ret, abi.encodeWithSignature("Error(string)", "Bad swap type"), "real Router NG: Bad swap type");

544:         assertEq(ret, abi.encodeWithSignature("BadSwapType(uint256)", 1));

550:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

134:         vm.expectRevert(abi.encodeWithSignature("NoHop()"));

144:         vm.expectRevert(abi.encodeWithSignature("ZeroOutputToken()"));

155:         vm.expectRevert(abi.encodeWithSelector(MockCurveRouter.Slippage.selector, AMOUNT, AMOUNT + 1));

167:         vm.expectRevert(abi.encodeWithSignature("ZeroIntermediateToken()"));

180:         vm.expectRevert(abi.encodeWithSignature("ZeroIntermediateToken()"));

195:         vm.expectRevert(abi.encodeWithSignature("BadSwapType(uint256)", 1));

```

### <a name="NC-2"></a>[NC-2] Missing checks for `address(0)` when assigning values to address state variables

*Instances (4)*:
```solidity
File: test/mocks/MockSYA.sol

59:         rewardToken = _rewardToken;

63:         rewardToken = _rewardToken;

67:         nftMinter = _nftMinter;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

24:         token = _token;

```

### <a name="NC-3"></a>[NC-3] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (220)*:
```solidity
File: src/SYAHarvester.sol

158:         if (path[0] != token) revert InvalidRouteStart(token, path[0]);

178:                 if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);

```

```solidity
File: test/SYAHarvester.harvest.t.sol

90:         exempt[0] = address(dolaStrategy);

```

```solidity
File: test/SYAHarvester.registry.t.sol

50:         path[0] = tokenIn;

51:         path[1] = pool0;

52:         path[2] = usdc;

56:         path[0] = tokenIn;

57:         path[1] = pool0;

58:         path[2] = other;

59:         path[3] = pool1;

60:         path[4] = usdc;

64:         p[0] = [uint256(0), 1, 1, 1, 2];

65:         p[1] = [uint256(1), 0, 1, 10, 2];

69:         pools[0] = pool1;

83:         if (k >= 1) pools[0] = pool1;

172:         path[0] = usde;

173:         path[1] = pool0;

174:         path[2] = other;

182:         path[4] = dola;

195:         path[0] = tokenIn;

196:         path[1] = pool0;

197:         path[2] = other;

198:         path[3] = pool1;

199:         path[4] = dola;

200:         path[5] = pool0;

201:         path[6] = other2;

202:         path[7] = pool1;

203:         path[8] = other3;

204:         path[9] = pool0;

205:         path[10] = tokenOut;

212:         path[0] = usde;

213:         path[1] = pool0;

214:         path[2] = other;

215:         path[10] = usdc;

225:         path[0] = usde;

226:         path[1] = pool0;

227:         path[2] = usdc;

228:         path[10] = usdc;

236:         path[4] = other; // never executed: path[3] == 0 ends the route at path[2]

244:         path[0] = usde;

245:         path[1] = pool0;

246:         path[2] = other;

247:         path[3] = pool1;

248:         path[4] = usdc;

249:         path[6] = usdc; // path[5] == 0: the route ends at path[4]; path[6] is a trailing entry

259:         path[0] = usde;

260:         path[1] = pool0;

261:         path[2] = other;

262:         path[3] = pool1;

263:         path[4] = other2;

264:         path[6] = usdc;

272:         path[5] = pool1; // a pool slot after the executed prefix is still a trailing entry

300:         path[0] = usde;

309:         path[0] = usde;

310:         path[2] = usdc;

320:         path[0] = usdc;

326:         assertEq(r.path[0], usdc);

327:         assertEq(r.path[1], address(0));

332:         path[0] = usdc;

333:         path[2] = other;

375:         assertEq(r.path[0], dola);

376:         assertEq(r.path[2], other);

377:         assertEq(r.path[4], usdc);

378:         assertEq(r.path[5], address(0));

379:         assertEq(r.swapParams[1][3], 10);

379:         assertEq(r.swapParams[1][3], 10);

396:         path[0] = usde;

397:         path[1] = pool0;

398:         path[3] = pool1;

399:         path[4] = usdc;

407:         path[0] = usde;

408:         path[1] = pool0;

409:         path[2] = other;

410:         path[3] = pool1;

411:         path[4] = dola;

412:         path[5] = pool0;

414:         path[7] = pool1;

415:         path[8] = usdc;

423:         path[2] = address(0);

424:         path[4] = other; // also delivers a non-reward token: the zero intermediate is reported first

432:         p[0][2] = 0;

432:         p[0][2] = 0;

440:         p[1][2] = 0; // i/j/pool_type/n_coins still set: only swap_type decides "executed row non-empty"

440:         p[1][2] = 0; // i/j/pool_type/n_coins still set: only swap_type decides "executed row non-empty"

448:         delete p[4];

464:         p[3][0] = 1;

464:         p[3][0] = 1;

472:         pools[1] = pool1;

480:         pools[4] = pool0;

489:         pools[1] = pool1;

498:         p[2][2] = 1;

498:         p[2][2] = 1;

500:         pools[1] = pool1;

508:         path[2] = other;

516:         path[0] = usdc;

524:         path[0] = usdc;

539:             assertGt(r.swapParams[h][2], 0, "executed row has a swap type");

568:         path[0] = usdc;

579:         assertEq(r.path[0], address(0));

597:         assertEq(r.path[0], address(0));

598:         assertEq(r.swapParams[0][4], 0);

598:         assertEq(r.swapParams[0][4], 0);

599:         assertEq(r.pools[0], address(0));

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

24:         p[0] = address(usde);

25:         p[1] = curvePool;

26:         p[2] = address(crvusd);

27:         p[10] = address(usdc);

37:         assertEq(r.path[2], address(usdc));

38:         assertEq(r.path[10], address(0));

```

```solidity
File: test/fork/MainnetRoutes.sol

62:         r.path[0] = A.USDE;

63:         r.path[1] = POOL_USDE_CRVUSD;

64:         r.path[2] = A.CRVUSD;

65:         r.path[3] = POOL_CRVUSD_USDC;

66:         r.path[4] = A.USDC;

68:         r.swapParams[0] = [uint256(0), 1, 1, 10, 2];

70:         r.swapParams[1] = [uint256(1), 0, 1, 1, 2];

76:         r.path[0] = A.DOLA;

77:         r.path[1] = POOL_DOLA_FRAXBP;

78:         r.path[2] = A.USDC;

81:         r.swapParams[0] = [uint256(0), 2, 2, 1, 3];

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

124:         l[0] = a;

211:         assertEq(u.path[0], A.USDE);

212:         assertEq(ICurvePoolCoins(u.path[1]).coins(u.swapParams[0][0]), A.USDE, "usde hop1 i");

212:         assertEq(ICurvePoolCoins(u.path[1]).coins(u.swapParams[0][0]), A.USDE, "usde hop1 i");

212:         assertEq(ICurvePoolCoins(u.path[1]).coins(u.swapParams[0][0]), A.USDE, "usde hop1 i");

213:         assertEq(ICurvePoolCoins(u.path[1]).coins(u.swapParams[0][1]), A.CRVUSD, "usde hop1 j");

213:         assertEq(ICurvePoolCoins(u.path[1]).coins(u.swapParams[0][1]), A.CRVUSD, "usde hop1 j");

213:         assertEq(ICurvePoolCoins(u.path[1]).coins(u.swapParams[0][1]), A.CRVUSD, "usde hop1 j");

214:         assertEq(u.path[1], 0xF55B0f6F2Da5ffDDb104b58a60F2862745960442, "usde hop1 pool");

215:         assertEq(u.path[2], A.CRVUSD);

216:         assertEq(ICurvePoolCoins(u.path[3]).coins(u.swapParams[1][0]), A.CRVUSD, "usde hop2 i");

216:         assertEq(ICurvePoolCoins(u.path[3]).coins(u.swapParams[1][0]), A.CRVUSD, "usde hop2 i");

216:         assertEq(ICurvePoolCoins(u.path[3]).coins(u.swapParams[1][0]), A.CRVUSD, "usde hop2 i");

217:         assertEq(ICurvePoolCoins(u.path[3]).coins(u.swapParams[1][1]), A.USDC, "usde hop2 j");

217:         assertEq(ICurvePoolCoins(u.path[3]).coins(u.swapParams[1][1]), A.USDC, "usde hop2 j");

217:         assertEq(ICurvePoolCoins(u.path[3]).coins(u.swapParams[1][1]), A.USDC, "usde hop2 j");

218:         assertEq(u.path[4], A.USDC);

222:         assertEq(d.path[0], A.DOLA);

223:         assertEq(ICurvePoolCoins(d.path[1]).coins(0), A.DOLA, "dola meta coin0");

224:         assertEq(ICurvePoolCoins(d.path[1]).coins(1), FRAXBP_LP, "dola meta coin1 is FRAXBP LP");

228:         assertEq(d.swapParams[0][1], 2, "USDC underlying index");

228:         assertEq(d.swapParams[0][1], 2, "USDC underlying index");

229:         assertEq(d.path[2], A.USDC);

311:         exempt[0] = A.YS_USDC;

312:         exempt[1] = A.YS_DOLA;

415:         gap[0] = A.USDE;

416:         gap[1] = MainnetRoutes.POOL_USDE_CRVUSD;

417:         gap[2] = A.CRVUSD;

418:         gap[10] = A.USDC;

429:         assertEq(r.path[3], MainnetRoutes.POOL_CRVUSD_USDC, "contiguous route kept");

430:         assertEq(r.path[10], address(0));

476:         p[0] = A.USDE;

477:         p[1] = MainnetRoutes.POOL_USDE_CRVUSD;

478:         p[3] = MainnetRoutes.POOL_CRVUSD_USDC;

479:         p[4] = A.USDC;

533:         params[1][2] = 0; // hop 1 (crvUSD -> USDC) executed with swap_type 0

533:         params[1][2] = 0; // hop 1 (crvUSD -> USDC) executed with swap_type 0

554:         assertEq(r.path[2], A.CRVUSD, "shipped route kept");

```

```solidity
File: test/mocks/MockCurveRouter.sol

47:         if (_route[1] == address(0)) revert NoHop();

65:         address tokenIn = _route[0];

68:             if (_swapParams[h][2] == 0) revert BadSwapType(h);

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

63:         path[0] = address(tokenIn);

64:         path[1] = pool0;

65:         path[2] = address(mid);

66:         path[3] = pool1;

67:         path[4] = address(tokenOut);

81:         path[0] = address(tokenIn);

82:         path[1] = pool0;

83:         path[2] = address(mid);

84:         path[10] = address(tokenOut);

95:         path[0] = address(tokenIn);

96:         path[1] = pool0;

97:         path[2] = address(mid);

98:         path[3] = pool1;

99:         path[4] = address(mid2);

100:         path[6] = address(tokenOut);

110:         path[0] = address(tokenIn);

111:         path[1] = pool0;

112:         path[2] = address(mid);

113:         path[3] = pool1;

114:         path[4] = address(mid2);

115:         path[5] = pool0;

116:         path[6] = address(mid3);

117:         path[7] = pool1;

118:         path[8] = address(mid4);

119:         path[9] = pool0;

120:         path[10] = address(tokenOut);

131:         path[0] = address(tokenIn);

132:         path[2] = address(tokenOut);

141:         path[0] = address(tokenIn);

142:         path[1] = pool0;

150:         path[0] = address(tokenIn);

151:         path[1] = pool0;

152:         path[2] = address(tokenOut);

162:         path[0] = address(tokenIn);

163:         path[1] = pool0;

164:         path[3] = pool1;

165:         path[4] = address(tokenOut);

173:         path[0] = address(tokenIn);

174:         path[1] = pool0;

175:         path[2] = address(mid);

176:         path[3] = pool1;

177:         path[5] = pool0; // path[4] == 0 inside the executed prefix (k = 3)

178:         path[6] = address(tokenOut);

186:         path[0] = address(tokenIn);

187:         path[1] = pool0;

188:         path[2] = address(mid);

189:         path[3] = pool1;

190:         path[4] = address(tokenOut);

192:         params[1][2] = 0;

192:         params[1][2] = 0;

202:         path[0] = address(tokenIn);

203:         path[1] = pool0;

204:         path[2] = address(tokenOut);

206:         params[3] = [uint256(7), 7, 7, 7, 7];

208:         pools[4] = pool1;

```

```solidity
File: test/utils/HarvesterFixture.sol

97:         p[0] = tokenIn;

98:         p[1] = curvePool;

99:         p[2] = address(usdc);

103:         p[0] = [uint256(0), 1, 1, 1, 2];

```

### <a name="NC-4"></a>[NC-4] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (104)*:
```solidity
File: src/SYAHarvester.sol

162:         while (k < 5 && path[2 * k + 1] != address(0)) k++;

164:         for (uint256 i = 2 * k + 1; i < 11; i++) {

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

326:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

```

```solidity
File: test/SYAHarvester.gas.t.sol

34:         require(ret.length == 68, "not Unprofitable(uint256,uint256)");

89:         assertGt(units, overhead + 100_000, "measured gas spans the harvest");

90:         assertLt(units, overhead + 2_000_000, "measured gas is sane");

96:         assertGt(breakEven, 20, "harness gives a usable break-even price");

99:         (bool okBelow,) = _harvestAt(breakEven * 9 / 10);

103:         (bool okAbove, bytes memory ret) = _harvestAt(breakEven * 11 / 10);

```

```solidity
File: test/SYAHarvester.harvest.t.sol

29:         assertEq(sya.totalCollected(), 900e6, "payment");

43:         assertEq(sya.totalCollected(), 900e6, "payment on actual delivered");

81:         assertEq(sya.totalCollected(), 1080e6, "payment");

```

```solidity
File: test/SYAHarvester.nft.t.sol

27:         nft.mint(keeper, NFT_INDEX, 2);

82:             address(nft), abi.encodeCall(IERC1155.safeTransferFrom, (address(harvester), keeper, NFT_INDEX, 2, "")), 1

88:         assertEq(sya.nftBalanceSeenInClaim(), 2, "pulled unit plus stray unit held during claim");

```

```solidity
File: test/SYAHarvester.registry.t.sol

64:         p[0] = [uint256(0), 1, 1, 1, 2];

65:         p[1] = [uint256(1), 0, 1, 10, 2];

76:             p[h] = h == 1 ? [uint256(1), 0, 1, 10, 2] : [uint256(0), 1, 1, 1, 2];

90:             fee: 500,

91:             tickSpacing: 10,

217:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

230:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

238:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 4));

251:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));

266:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));

274:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 5));

285:         for (uint256 i = 0; i < 11; i++) {

312:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));

335:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));

356:         for (uint256 i = 0; i < 11; i++) {

359:         for (uint256 i = 0; i < 5; i++) {

361:             for (uint256 j = 0; j < 5; j++) {

379:         assertEq(r.swapParams[1][3], 10);

390:         ROUTE TOKEN / SWAP PARAMS / POOLS CONSISTENCY (audit 01, M-01 residual + mitigation 2)

401:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));

417:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 6));

426:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));

450:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 4));

466:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 3));

482:         vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 4));

538:         for (uint256 h = 0; h < 5; h++) {

540:             for (uint256 f = 0; f < 5; f++) {

555:         for (uint256 i = 0; i < 11; i++) {

558:         for (uint256 h = 0; h < 5; h++) {

560:             for (uint256 f = 0; f < 5; f++) {

626:         emit EthPoolSet(address(0), usdc, 500, 10, address(0));

633:         assertEq(stored.fee, 500);

634:         assertEq(stored.tickSpacing, 10);

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

18:         crvusd = new MockERC20("crvUSD", "crvUSD", 18);

32:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

44:         usde.mint(address(this), 100e18);

45:         usde.approve(address(router), 100e18);

46:         router.exchange(_gapPath(), _params(), 100e18, 0, _pools(), receiver);

```

```solidity
File: test/fork/MainnetRoutes.sol

68:         r.swapParams[0] = [uint256(0), 1, 1, 10, 2];

70:         r.swapParams[1] = [uint256(1), 0, 1, 1, 2];

81:         r.swapParams[0] = [uint256(0), 2, 2, 1, 3];

96:             fee: 3000,

97:             tickSpacing: 60,

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

107:         vm.roll(block.number + ACCRUAL_WARP / 12);

180:         assertLt(rate, 10_000, "discount rate");

186:         assertEq(strategies.length, 3, "live strategy count differs from the address table");

196:         assertEq(routed, 2, "USDe and DOLA routed");

227:         assertEq(ICurvePoolCoins(basePool).coins(1), A.USDC, "FRAXBP coin1 (underlying index 2)");

228:         assertEq(d.swapParams[0][1], 2, "USDC underlying index");

234:         uint256 u20 = _quote(MainnetRoutes.usdeRoute(), 20e18);

235:         uint256 d20 = _quote(MainnetRoutes.dolaRoute(), 20e18);

236:         uint256 d1000 = _quote(MainnetRoutes.dolaRoute(), 1000e18);

240:         assertGt(u20, 19.8e6, "USDe route quote");

241:         assertGt(d20, 19.8e6, "DOLA route quote");

242:         assertGt(d1000, 990e6, "DOLA route depth");

253:         uint24[4] memory fees = [uint24(100), 500, 3000, 10_000];

254:         int24[4] memory spacings = [int24(1), 10, 60, 200];

288:         console2.log("calculateClaimAmount (USDC 6dp)", sya.calculateClaimAmount(_none()));

352:             address(harvester).call(abi.encodeCall(harvester.harvest, (_none(), A.NFT_INDEX, 1000 ether)));

361:             g += data[i] == 0 ? 4 : 16;

383:         uint256 realGas = 21_000 + _calldataGas(data) + executionGas;

407:         assertLe(harvester.GAS_OVERHEAD(), gap + 25_000, "GAS_OVERHEAD over-padded");

424:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));

550:         vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));

```

```solidity
File: test/mocks/MockCurveRouter.sol

48:         for (uint256 i = 0; i < 5; i++) {

49:             tokenOut = _route[2 * i + 2];

51:             if (i == 4 || _route[2 * i + 3] == address(0)) break;

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

30:         tokenIn = new MockERC20("In", "IN", 18);

31:         mid = new MockERC20("Mid", "MID", 18);

32:         mid2 = new MockERC20("Mid2", "MID2", 18);

33:         mid3 = new MockERC20("Mid3", "MID3", 18);

34:         mid4 = new MockERC20("Mid4", "MID4", 18);

35:         tokenOut = new MockERC20("Out", "OUT", 18);

51:         for (uint256 h = 0; h < 5 && path[2 * h + 1] != address(0); h++) {

52:             params[h] = [uint256(0), 1, 1, 1, 2];

206:         params[3] = [uint256(7), 7, 7, 7, 7];

```

```solidity
File: test/mocks/MockSYA.sol

47:     uint256 public discountRate = 1000; // 10%

118:         uint256 payment = _denormalize(totalNormalizedYield * (10000 - discountRate) / 10000, rewardToken);

137:         uint256 payment = _denormalize(totalNormalizedYield * (10000 - discountRate) / 10000, rewardToken);

138:         return payment * (10000 + overEstimateBps) / 10000;

158:         return d <= 18 ? amount * 10 ** (18 - d) : amount / 10 ** (d - 18);

163:         return d <= 18 ? amount / 10 ** (18 - d) : amount * 10 ** (d - 18);

```

```solidity
File: test/utils/HarvesterFixture.sol

48:         usdc = new MockERC20("USD Coin", "USDC", 6);

49:         usde = new MockERC20("USDe", "USDe", 18);

50:         dola = new MockERC20("DOLA", "DOLA", 18);

59:             3000,

103:         p[0] = [uint256(0), 1, 1, 1, 2];

```

### <a name="NC-5"></a>[NC-5] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (45)*:
```solidity
File: src/SYAHarvester.sol

157:         if (token == address(0)) revert ZeroAddress();

158:         if (path[0] != token) revert InvalidRouteStart(token, path[0]);

165:             if (path[i] != address(0)) revert InvalidRouteGap(i);

169:             if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);

173:         if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);

178:                 if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);

181:                     if (swapParams[h][f] != 0) revert InvalidRouteSwapParams(h);

183:                 if (pools[h] != address(0)) revert InvalidRoutePools(h);

276:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

294:         if (ethOut < minEthOut) revert InsufficientEthOut(ethOut, minEthOut);

297:         if (ethOut < gasCost) revert Unprofitable(ethOut, gasCost);

300:         if (!ok) revert EthTransferFailed();

322:         if (msg.sender != address(poolManager)) revert NotPoolManager();

343:         if (msg.sender != address(poolManager)) revert NotPoolManager();

354:             if (_contains(exempt, strategies[i])) continue;

356:             if (token == address(0) || token == reward) continue;

358:             if (balance == 0) continue; // nothing delivered, or a shared token already sold

360:             if (!r.configured) revert RouteNotConfigured(token);

377:                     amountSpecified: -SafeCast.toInt256(surplus),

398:             if (list[i] == item) return true;

```

```solidity
File: test/SYAHarvester.registry.t.sol

83:         if (k >= 1) pools[0] = pool1;

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

186:         assertEq(strategies.length, 3, "live strategy count differs from the address table");

192:             if (token == reward) continue;

```

```solidity
File: test/mocks/MockCurveRouter.sol

47:         if (_route[1] == address(0)) revert NoHop();

51:             if (i == 4 || _route[2 * i + 3] == address(0)) break;

52:             if (tokenOut == address(0)) revert ZeroIntermediateToken();

54:         if (tokenOut == address(0)) revert ZeroOutputToken();

68:             if (_swapParams[h][2] == 0) revert BadSwapType(h);

73:         if (out < _expected) revert Slippage(out, _expected);

```

```solidity
File: test/mocks/MockERC1155.sol

27:         if (!authorizedBurners[msg.sender]) revert NotAuthorizedBurner(msg.sender);

```

```solidity
File: test/mocks/MockSYA.sol

100:             if (IERC1155(nftMinter).balanceOf(msg.sender, nftIndex) == 0) revert NoValidNFT();

112:             if (_skip(strategy, token, exemptStrategies)) continue;

114:             if (received > 0) totalNormalizedYield += _normalize(received, token);

116:         if (totalNormalizedYield == 0) revert ZeroAmount();

119:         if (payment < minRewardTokenSupplied) revert InsufficientYield();

132:             if (_skip(strategy, token, exemptStrategies)) continue;

134:             if (y > 0) totalNormalizedYield += _normalize(y, token);

136:         if (totalNormalizedYield == 0) return 0;

143:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

148:         if (token == address(0)) return true;

149:         if (tokenPaused[token]) return true;

151:             if (exemptStrategies[j] == strategy) return true;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

42:         if (paused) revert StrategyPaused();

43:         if (_token != token) revert WrongToken();

```

```solidity
File: test/utils/HarvesterFixture.sol

54:         usdc.approve(address(modifyLiquidityRouter), type(uint256).max);

```

### <a name="NC-6"></a>[NC-6] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

27: contract SYAHarvester is Ownable, ERC1155Holder, IUnlockCallback {

```

### <a name="NC-7"></a>[NC-7] Draft Dependencies
Draft contracts have not received adequate security auditing or are liable to change with future developments.

*Instances (1)*:
```solidity
File: test/SYAHarvester.nft.t.sol

6: import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

```

### <a name="NC-8"></a>[NC-8] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

151:     function setRoute(
             address token,
             address[11] calldata path,
             uint256[5][5] calldata swapParams,
             address[5] calldata pools
         ) external onlyOwner {
             if (token == address(0)) revert ZeroAddress();
             if (path[0] != token) revert InvalidRouteStart(token, path[0]);
     
             // Router NG executes hop k while path[2k+1] != 0 and delivers path[2k] at the first empty pool slot.
             uint256 k;
             while (k < 5 && path[2 * k + 1] != address(0)) k++;
             // Nothing may follow the executed prefix: a trailing entry is never executed (empty when k == 5).
             for (uint256 i = 2 * k + 1; i < 11; i++) {
                 if (path[i] != address(0)) revert InvalidRouteGap(i);
             }
             // Every executed intermediate token must exist: hop i-1 outputs path[2i].
             for (uint256 i = 1; i < k; i++) {
                 if (path[2 * i] == address(0)) revert InvalidRouteToken(2 * i);
             }
             address rewardToken = sya.rewardToken();
             address delivered = path[2 * k];
             if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);
             // Swap params and pools must match the executed prefix: executed rows dispatch on a real swap_type,
             // rows and pools the router never reads are zero.
             for (uint256 h = 0; h < 5; h++) {
                 if (h < k) {
                     if (swapParams[h][2] == 0) revert InvalidRouteSwapParams(h);
                 } else {
                     for (uint256 f = 0; f < 5; f++) {
                         if (swapParams[h][f] != 0) revert InvalidRouteSwapParams(h);
                     }
                     if (pools[h] != address(0)) revert InvalidRoutePools(h);
                 }
             }
     
             CurveRoute storage r = routes[token];
             r.path = path;
             r.swapParams = swapParams;
             r.pools = pools;
             r.configured = true;
     
             emit RouteSet(token);

218:     function setEthPool(PoolKey calldata key) external onlyOwner {
             if (Currency.unwrap(key.currency0) != address(0) || Currency.unwrap(key.currency1) != sya.rewardToken()) {
                 revert InvalidEthPool();
             }
             ethPool = key;
             emit EthPoolSet(

```

### <a name="NC-9"></a>[NC-9] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (7)*:
```solidity
File: test/SYAHarvester.gas.t.sol

1: 
   Current order:
   external GAS_OVERHEAD
   internal _ethOutAtZeroPrice
   internal _harvestAt
   internal _decodeUnprofitable
   internal _chargedGasUnits
   public test_gas_costAboveEthOut_revertsUnprofitable
   public test_gas_zeroGasPrice_passesTrivially
   public test_gas_chargedUnits_coverMeasuredWorkPlusOverhead
   public test_gas_borderlinePrice_flipsPassFail
   public test_gas_minEthOutSatisfied_butUnprofitable_stillReverts
   
   Suggested order:
   external GAS_OVERHEAD
   public test_gas_costAboveEthOut_revertsUnprofitable
   public test_gas_zeroGasPrice_passesTrivially
   public test_gas_chargedUnits_coverMeasuredWorkPlusOverhead
   public test_gas_borderlinePrice_flipsPassFail
   public test_gas_minEthOutSatisfied_butUnprofitable_stillReverts
   internal _ethOutAtZeroPrice
   internal _harvestAt
   internal _decodeUnprofitable
   internal _chargedGasUnits

```

```solidity
File: test/SYAHarvester.nft.t.sol

1: 
   Current order:
   public setUp
   internal _refundCallPrefix
   public test_nft_pulledThenBurned_noRefund
   public test_nft_ignoredBySya_heldDuringUnlock_thenRefunded
   public test_nft_refundReturnsWholeBalance_includingStrayUnits
   public test_nft_indexZero_noErc1155Calls
   public test_nft_noMinterConfigured_skipsBothTransfers
   public test_nft_callerWithoutApproval_revertsOnPull
   public test_nft_burnNeedsNoApprovalFromHarvester
   public test_supportsInterface_erc1155Receiver
   
   Suggested order:
   public setUp
   public test_nft_pulledThenBurned_noRefund
   public test_nft_ignoredBySya_heldDuringUnlock_thenRefunded
   public test_nft_refundReturnsWholeBalance_includingStrayUnits
   public test_nft_indexZero_noErc1155Calls
   public test_nft_noMinterConfigured_skipsBothTransfers
   public test_nft_callerWithoutApproval_revertsOnPull
   public test_nft_burnNeedsNoApprovalFromHarvester
   public test_supportsInterface_erc1155Receiver
   internal _refundCallPrefix

```

```solidity
File: test/SYAHarvester.registry.t.sol

1: 
   Current order:
   public setUp
   internal _singleHop
   internal _multiHop
   internal _params
   internal _pools
   internal _params
   internal _pools
   internal _ethKey
   public test_constructor_storesImmutablesAndOwner
   public test_constructor_rejectsZeroPoolManager
   public test_constructor_rejectsZeroSya
   public test_constructor_rejectsZeroRouter
   public test_constructor_rejectsZeroOwner
   public test_setRoute_revertsForNonOwner
   public test_clearRoute_revertsForNonOwner
   public test_setEthPool_revertsForNonOwner
   public test_setRoute_rejectsZeroToken
   public test_setRoute_rejectsWrongFirstToken
   public test_setRoute_rejectsRouteEndingAtNonRewardToken
   public test_setRoute_rejectsMultiHopEndingAtWrongToken
   internal _fiveHop
   public test_setRoute_rejectsGappedRoute_trailingRewardToken
   public test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry
   public test_setRoute_rejectsStrayEntryAfterRewardToken
   public test_setRoute_rejectsGapInMultiHopRoute
   public test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate
   public test_setRoute_rejectsTrailingPoolSlotAfterRewardToken
   public test_setRoute_storesFullFiveHopRoute
   public test_setRoute_rejectsFiveHopEndingAtNonRewardToken
   public test_setRoute_rejectsNoHopRouteForNonRewardToken
   public test_setRoute_rejectsNoHopRouteWithTrailingRewardToken
   public test_setRoute_acceptsNoHopRouteForRewardToken
   public test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry
   public test_setRoute_validatesAgainstCurrentRewardToken
   public test_setRoute_storesSingleHop
   public test_setRoute_storesMultiHop
   public test_setRoute_emitsRouteSet
   public test_setRoute_rejectsZeroIntermediateToken_twoHop
   public test_setRoute_rejectsZeroIntermediateToken_index6InFourHop
   public test_setRoute_zeroIntermediateReportedBeforeWrongEnd
   public test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop
   public test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop
   public test_setRoute_rejectsAllZeroExecutedRow_fiveHop
   public test_setRoute_rejectsRowAtHopK_singleHop
   public test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow
   public test_setRoute_rejectsPoolAtHopK_singleHop
   public test_setRoute_rejectsPoolInLastSlot_twoHop
   public test_setRoute_unexecutedHopChecksParamsBeforePools
   public test_setRoute_unexecutedHopsAreCheckedInHopOrder
   public test_setRoute_wrongEndReportedBeforeSwapParams
   public test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow
   public test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool
   public test_setRoute_storesFullFiveHopRouteWithFiveValidRows
   public test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools
   public test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools
   public test_getRoute_unsetTokenIsNotConfigured
   public test_clearRoute_resetsConfiguredAndEmits
   public test_setEthPool_rejectsNonNativeCurrency0
   public test_setEthPool_rejectsCurrency1NotRewardToken
   public test_setEthPool_storesKeyAndEmits
   public test_noHarvestFunction
   
   Suggested order:
   public setUp
   public test_constructor_storesImmutablesAndOwner
   public test_constructor_rejectsZeroPoolManager
   public test_constructor_rejectsZeroSya
   public test_constructor_rejectsZeroRouter
   public test_constructor_rejectsZeroOwner
   public test_setRoute_revertsForNonOwner
   public test_clearRoute_revertsForNonOwner
   public test_setEthPool_revertsForNonOwner
   public test_setRoute_rejectsZeroToken
   public test_setRoute_rejectsWrongFirstToken
   public test_setRoute_rejectsRouteEndingAtNonRewardToken
   public test_setRoute_rejectsMultiHopEndingAtWrongToken
   public test_setRoute_rejectsGappedRoute_trailingRewardToken
   public test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry
   public test_setRoute_rejectsStrayEntryAfterRewardToken
   public test_setRoute_rejectsGapInMultiHopRoute
   public test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate
   public test_setRoute_rejectsTrailingPoolSlotAfterRewardToken
   public test_setRoute_storesFullFiveHopRoute
   public test_setRoute_rejectsFiveHopEndingAtNonRewardToken
   public test_setRoute_rejectsNoHopRouteForNonRewardToken
   public test_setRoute_rejectsNoHopRouteWithTrailingRewardToken
   public test_setRoute_acceptsNoHopRouteForRewardToken
   public test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry
   public test_setRoute_validatesAgainstCurrentRewardToken
   public test_setRoute_storesSingleHop
   public test_setRoute_storesMultiHop
   public test_setRoute_emitsRouteSet
   public test_setRoute_rejectsZeroIntermediateToken_twoHop
   public test_setRoute_rejectsZeroIntermediateToken_index6InFourHop
   public test_setRoute_zeroIntermediateReportedBeforeWrongEnd
   public test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop
   public test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop
   public test_setRoute_rejectsAllZeroExecutedRow_fiveHop
   public test_setRoute_rejectsRowAtHopK_singleHop
   public test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow
   public test_setRoute_rejectsPoolAtHopK_singleHop
   public test_setRoute_rejectsPoolInLastSlot_twoHop
   public test_setRoute_unexecutedHopChecksParamsBeforePools
   public test_setRoute_unexecutedHopsAreCheckedInHopOrder
   public test_setRoute_wrongEndReportedBeforeSwapParams
   public test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow
   public test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool
   public test_setRoute_storesFullFiveHopRouteWithFiveValidRows
   public test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools
   public test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools
   public test_getRoute_unsetTokenIsNotConfigured
   public test_clearRoute_resetsConfiguredAndEmits
   public test_setEthPool_rejectsNonNativeCurrency0
   public test_setEthPool_rejectsCurrency1NotRewardToken
   public test_setEthPool_storesKeyAndEmits
   public test_noHarvestFunction
   internal _singleHop
   internal _multiHop
   internal _params
   internal _pools
   internal _params
   internal _pools
   internal _ethKey
   internal _fiveHop

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

1: 
   Current order:
   public setUp
   internal _gapPath
   public test_routeGap_gappedRouteCannotBeStored
   public test_routeGap_mockDeliversIntermediateForGappedPath
   public test_routeGap_contiguousFixtureRoute_harvestLeavesNoBalances
   
   Suggested order:
   public setUp
   public test_routeGap_gappedRouteCannotBeStored
   public test_routeGap_mockDeliversIntermediateForGappedPath
   public test_routeGap_contiguousFixtureRoute_harvestLeavesNoBalances
   internal _gapPath

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

1: 
   Current order:
   external coins
   external get_dy
   external poolManager
   external totalSupply
   public setUp
   external unlockCallback
   internal _none
   internal _one
   internal _harvest
   internal _assertHarvesterEmpty
   public test_fork_addresses_verifiedOnFork
   public test_fork_liveStrategies_everyNonRewardTokenHasRoute
   internal _quote
   public test_fork_routes_coinIndicesMatchPools
   public test_fork_routes_quoteCloseToPar
   public test_fork_ethPool_isDeepestNativeEthUsdcPool
   public test_fork_accrual_warpAloneProducesYield
   public test_fork_harvest_endToEnd_paysEthBurnsNftLeavesNoBalances
   public test_fork_harvest_usdeStrategyNonExempt_noNestedUnlock
   public test_fork_harvest_eachStrategyExemptedInTurn
   public test_fork_harvest_highGasPrice_revertsUnprofitable
   public test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut
   internal _calldataGas
   public test_fork_gasOverhead_coversMeasuredGap
   internal _gapPath
   public test_fork_M01_gapRoute_rejectedBySetRoute
   public test_fork_M01_contiguousRoute_harvestsAndLeavesHarvesterEmpty
   public test_fork_M01_realRouterDeliversIntermediate_mockAgrees
   internal _zeroIntermediatePath
   internal _realRouterExchange
   internal _mockExchange
   public test_fork_zeroIntermediate_realRouterReverts_mockAgrees
   public test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees
   public test_fork_zeroIntermediate_rejectedBySetRoute
   public test_fork_shippedRoutes_passNewRules_andHarvestLeavesHarvesterEmpty
   
   Suggested order:
   external coins
   external get_dy
   external poolManager
   external totalSupply
   external unlockCallback
   public setUp
   public test_fork_addresses_verifiedOnFork
   public test_fork_liveStrategies_everyNonRewardTokenHasRoute
   public test_fork_routes_coinIndicesMatchPools
   public test_fork_routes_quoteCloseToPar
   public test_fork_ethPool_isDeepestNativeEthUsdcPool
   public test_fork_accrual_warpAloneProducesYield
   public test_fork_harvest_endToEnd_paysEthBurnsNftLeavesNoBalances
   public test_fork_harvest_usdeStrategyNonExempt_noNestedUnlock
   public test_fork_harvest_eachStrategyExemptedInTurn
   public test_fork_harvest_highGasPrice_revertsUnprofitable
   public test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut
   public test_fork_gasOverhead_coversMeasuredGap
   public test_fork_M01_gapRoute_rejectedBySetRoute
   public test_fork_M01_contiguousRoute_harvestsAndLeavesHarvesterEmpty
   public test_fork_M01_realRouterDeliversIntermediate_mockAgrees
   public test_fork_zeroIntermediate_realRouterReverts_mockAgrees
   public test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees
   public test_fork_zeroIntermediate_rejectedBySetRoute
   public test_fork_shippedRoutes_passNewRules_andHarvestLeavesHarvesterEmpty
   internal _none
   internal _one
   internal _harvest
   internal _assertHarvesterEmpty
   internal _quote
   internal _calldataGas
   internal _gapPath
   internal _zeroIntermediatePath
   internal _realRouterExchange
   internal _mockExchange

```

```solidity
File: test/mocks/MockCurveRouter.sol

1: 
   Current order:
   external setRate
   public resolveOutput
   internal _resolve
   external exchange
   
   Suggested order:
   external setRate
   external exchange
   public resolveOutput
   internal _resolve

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

1: 
   Current order:
   public setUp
   internal _rows
   internal _exchange
   public test_exchange_contiguousRoute_deliversFinalToken
   public test_exchange_gappedRoute_deliversIntermediateToken
   public test_exchange_gapInMultiHopRoute_deliversPath2k
   public test_exchange_fiveHopRoute_deliversPath10
   public test_exchange_noHop_reverts
   public test_exchange_zeroOutputToken_reverts
   public test_exchange_slippage_stillEnforced
   public test_exchange_zeroIntermediateToken_reverts
   public test_resolveOutput_zeroIntermediateToken_reverts
   public test_exchange_executedRowWithZeroSwapType_reverts
   public test_exchange_ignoresRowsBeyondExecutedPrefix
   
   Suggested order:
   public setUp
   public test_exchange_contiguousRoute_deliversFinalToken
   public test_exchange_gappedRoute_deliversIntermediateToken
   public test_exchange_gapInMultiHopRoute_deliversPath2k
   public test_exchange_fiveHopRoute_deliversPath10
   public test_exchange_noHop_reverts
   public test_exchange_zeroOutputToken_reverts
   public test_exchange_slippage_stillEnforced
   public test_exchange_zeroIntermediateToken_reverts
   public test_resolveOutput_zeroIntermediateToken_reverts
   public test_exchange_executedRowWithZeroSwapType_reverts
   public test_exchange_ignoresRowsBeyondExecutedPrefix
   internal _rows
   internal _exchange

```

### <a name="NC-10"></a>[NC-10] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (178)*:
```solidity
File: src/SYAHarvester.sol

200:     function clearRoute(address token) external onlyOwner {

210:     function getRoute(address token) external view returns (CurveRoute memory) {

218:     function setEthPool(PoolKey calldata key) external onlyOwner {

232:     function getEthPool() external view returns (PoolKey memory) {

271:     function harvest(address[] calldata exemptStrategies, uint256 nftIndex, uint256 minEthOut)

321:     function unlockCallback(bytes calldata data) external returns (bytes memory) {

351:     function _sellYield(address[] memory exempt, address reward) internal {

369:     function _swapSurplusAndSettle(address reward, uint256 owed, uint256 surplus) internal {

396:     function _contains(address[] memory list, address item) internal pure returns (bool) {

```

```solidity
File: test/SYAHarvester.gas.t.sol

7:     function GAS_OVERHEAD() external view returns (uint256);

18:     function _ethOutAtZeroPrice() internal returns (uint256 ethOut) {

27:     function _harvestAt(uint256 price) internal returns (bool ok, bytes memory ret) {

33:     function _decodeUnprofitable(bytes memory ret) internal pure returns (uint256 ethOut, uint256 gasCost) {

45:     function _chargedGasUnits(uint256 price) internal returns (uint256 ethOut, uint256 units) {

56:     function test_gas_costAboveEthOut_revertsUnprofitable() public {

69:     function test_gas_zeroGasPrice_passesTrivially() public {

81:     function test_gas_chargedUnits_coverMeasuredWorkPlusOverhead() public {

93:     function test_gas_borderlinePrice_flipsPassFail() public {

110:     function test_gas_minEthOutSatisfied_butUnprofitable_stillReverts() public {

```

```solidity
File: test/SYAHarvester.harvest.t.sol

20:     function test_harvest_profitablePath_paysEthToCaller() public {

35:     function test_harvest_profitablePath_withLiveLikeOverEstimate() public {

47:     function test_harvest_minEthOutAboveOutput_reverts() public {

62:     function test_harvest_unroutedToken_revertsRouteNotConfigured() public {

70:     function test_harvest_rewardTokenStrategy_skippedNoRouterCall() public {

85:     function test_harvest_exemptStrategy_notSkimmedNotSold() public {

102:     function test_harvest_pausedToken_skippedNoCoverageRevert() public {

119:     function test_unlockCallback_directCall_revertsNotPoolManager() public {

125:     function test_receive_fromNonPoolManager_reverts() public {

137:     function test_harvest_unprofitableClaim_reverts() public {

147:     function test_harvest_nestedUnlockInSkimSurplus_reverts() public {

155:     function test_harvest_ethPoolNotSet_reverts() public {

```

```solidity
File: test/SYAHarvester.nft.t.sol

33:     function _refundCallPrefix() internal view returns (bytes memory) {

41:     function test_nft_pulledThenBurned_noRefund() public {

64:     function test_nft_ignoredBySya_heldDuringUnlock_thenRefunded() public {

76:     function test_nft_refundReturnsWholeBalance_includingStrayUnits() public {

97:     function test_nft_indexZero_noErc1155Calls() public {

108:     function test_nft_noMinterConfigured_skipsBothTransfers() public {

124:     function test_nft_callerWithoutApproval_revertsOnPull() public {

135:     function test_nft_burnNeedsNoApprovalFromHarvester() public {

150:     function test_supportsInterface_erc1155Receiver() public view {

```

```solidity
File: test/SYAHarvester.registry.t.sol

49:     function _singleHop(address tokenIn) internal view returns (address[11] memory path) {

55:     function _multiHop(address tokenIn) internal view returns (address[11] memory path) {

63:     function _params() internal pure returns (uint256[5][5] memory p) {

68:     function _pools() internal view returns (address[5] memory pools) {

74:     function _params(uint256 k) internal pure returns (uint256[5][5] memory p) {

82:     function _pools(uint256 k) internal view returns (address[5] memory pools) {

86:     function _ethKey() internal view returns (PoolKey memory) {

100:     function test_constructor_storesImmutablesAndOwner() public view {

107:     function test_constructor_rejectsZeroPoolManager() public {

112:     function test_constructor_rejectsZeroSya() public {

117:     function test_constructor_rejectsZeroRouter() public {

124:     function test_constructor_rejectsZeroOwner() public {

135:     function test_setRoute_revertsForNonOwner() public {

141:     function test_clearRoute_revertsForNonOwner() public {

147:     function test_setEthPool_revertsForNonOwner() public {

157:     function test_setRoute_rejectsZeroToken() public {

164:     function test_setRoute_rejectsWrongFirstToken() public {

170:     function test_setRoute_rejectsRouteEndingAtNonRewardToken() public {

180:     function test_setRoute_rejectsMultiHopEndingAtWrongToken() public {

194:     function _fiveHop(address tokenIn, address tokenOut) internal view returns (address[11] memory path) {

208:     function test_setRoute_rejectsGappedRoute_trailingRewardToken() public {

221:     function test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry() public {

234:     function test_setRoute_rejectsStrayEntryAfterRewardToken() public {

242:     function test_setRoute_rejectsGapInMultiHopRoute() public {

255:     function test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate() public {

270:     function test_setRoute_rejectsTrailingPoolSlotAfterRewardToken() public {

278:     function test_setRoute_storesFullFiveHopRoute() public {

290:     function test_setRoute_rejectsFiveHopEndingAtNonRewardToken() public {

297:     function test_setRoute_rejectsNoHopRouteForNonRewardToken() public {

306:     function test_setRoute_rejectsNoHopRouteWithTrailingRewardToken() public {

318:     function test_setRoute_acceptsNoHopRouteForRewardToken() public {

330:     function test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry() public {

339:     function test_setRoute_validatesAgainstCurrentRewardToken() public {

393:     function test_setRoute_rejectsZeroIntermediateToken_twoHop() public {

405:     function test_setRoute_rejectsZeroIntermediateToken_index6InFourHop() public {

421:     function test_setRoute_zeroIntermediateReportedBeforeWrongEnd() public {

430:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop() public {

438:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop() public {

446:     function test_setRoute_rejectsAllZeroExecutedRow_fiveHop() public {

454:     function test_setRoute_rejectsRowAtHopK_singleHop() public {

461:     function test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow() public {

470:     function test_setRoute_rejectsPoolAtHopK_singleHop() public {

478:     function test_setRoute_rejectsPoolInLastSlot_twoHop() public {

486:     function test_setRoute_unexecutedHopChecksParamsBeforePools() public {

495:     function test_setRoute_unexecutedHopsAreCheckedInHopOrder() public {

506:     function test_setRoute_wrongEndReportedBeforeSwapParams() public {

514:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow() public {

522:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool() public {

530:     function test_setRoute_storesFullFiveHopRouteWithFiveValidRows() public {

546:     function test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools() public {

566:     function test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools() public {

576:     function test_getRoute_unsetTokenIsNotConfigured() public view {

586:     function test_clearRoute_resetsConfiguredAndEmits() public {

606:     function test_setEthPool_rejectsNonNativeCurrency0() public {

614:     function test_setEthPool_rejectsCurrency1NotRewardToken() public {

622:     function test_setEthPool_storesKeyAndEmits() public {

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

23:     function _gapPath() internal view returns (address[11] memory p) {

30:     function test_routeGap_gappedRouteCannotBeStored() public {

41:     function test_routeGap_mockDeliversIntermediateForGappedPath() public {

51:     function test_routeGap_contiguousFixtureRoute_harvestLeavesNoBalances() public {

```

```solidity
File: test/Toolchain.t.sol

13:     function test_deployFreshManagerAndRouters_deploysManager() public view {

```

```solidity
File: test/fork/MainnetRoutes.sol

60:     function usdeRoute() internal pure returns (Route memory r) {

74:     function dolaRoute() internal pure returns (Route memory r) {

92:     function ethPoolKey() internal pure returns (PoolKey memory) {

103:     function configure(SYAHarvester harvester) internal {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

23:     function coins(uint256 i) external view returns (address);

36:     function poolManager() external view returns (address);

40:     function totalSupply(uint256 id) external view returns (uint256);

112:     function unlockCallback(bytes calldata) external returns (bytes memory) {

118:     function _none() internal pure returns (address[] memory) {

122:     function _one(address a) internal pure returns (address[] memory l) {

127:     function _harvest(address[] memory exempt, uint256 minEthOut) internal returns (uint256) {

149:     function test_fork_addresses_verifiedOnFork() public {

183:     function test_fork_liveStrategies_everyNonRewardTokenHasRoute() public view {

204:     function _quote(MainnetRoutes.Route memory r, uint256 amount) internal view returns (uint256) {

208:     function test_fork_routes_coinIndicesMatchPools() public view {

232:     function test_fork_routes_quoteCloseToPar() public view {

245:     function test_fork_ethPool_isDeepestNativeEthUsdcPool() public view {

272:     function test_fork_accrual_warpAloneProducesYield() public view {

284:     function test_fork_harvest_endToEnd_paysEthBurnsNftLeavesNoBalances() public {

308:     function test_fork_harvest_usdeStrategyNonExempt_noNestedUnlock() public {

319:     function test_fork_harvest_eachStrategyExemptedInTurn() public {

340:     function test_fork_harvest_highGasPrice_revertsUnprofitable() public {

349:     function test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut() public {

359:     function _calldataGas(bytes memory data) internal pure returns (uint256 g) {

372:     function test_fork_gasOverhead_coversMeasuredGap() public {

414:     function _gapPath() internal pure returns (address[11] memory gap) {

421:     function test_fork_M01_gapRoute_rejectedBySetRoute() public {

433:     function test_fork_M01_contiguousRoute_harvestsAndLeavesHarvesterEmpty() public {

442:     function test_fork_M01_realRouterDeliversIntermediate_mockAgrees() public {

475:     function _zeroIntermediatePath() internal pure returns (address[11] memory p) {

483:     function _realRouterExchange(address[11] memory path, uint256[5][5] memory params, uint256 amount)

495:     function _mockExchange(address[11] memory path, uint256[5][5] memory params, uint256 amount)

511:     function test_fork_zeroIntermediate_realRouterReverts_mockAgrees() public {

530:     function test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees() public {

547:     function test_fork_zeroIntermediate_rejectedBySetRoute() public {

559:     function test_fork_shippedRoutes_passNewRules_andHarvestLeavesHarvesterEmpty() public {

```

```solidity
File: test/mocks/MockCurveRouter.sol

36:     function setRate(address tokenIn, uint256 _rate) external {

41:     function resolveOutput(address[11] calldata _route) public pure returns (address tokenOut) {

46:     function _resolve(address[11] calldata _route) internal pure returns (address tokenOut, uint256 hops) {

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

50:     function _rows(address[11] memory path) internal pure returns (uint256[5][5] memory params) {

56:     function _exchange(address[11] memory path) internal returns (uint256) {

61:     function test_exchange_contiguousRoute_deliversFinalToken() public {

78:     function test_exchange_gappedRoute_deliversIntermediateToken() public {

92:     function test_exchange_gapInMultiHopRoute_deliversPath2k() public {

108:     function test_exchange_fiveHopRoute_deliversPath10() public {

138:     function test_exchange_zeroOutputToken_reverts() public {

148:     function test_exchange_slippage_stillEnforced() public {

159:     function test_exchange_zeroIntermediateToken_reverts() public {

171:     function test_resolveOutput_zeroIntermediateToken_reverts() public {

184:     function test_exchange_executedRowWithZeroSwapType_reverts() public {

199:     function test_exchange_ignoresRowsBeyondExecutedPrefix() public {

```

```solidity
File: test/mocks/MockERC1155.sol

18:     function mint(address to, uint256 id, uint256 amount) external {

22:     function setAuthorizedBurner(address burner, bool authorized) external {

26:     function burn(address from, uint256 id, uint256 amount) external {

31:     function _update(address from, address to, uint256[] memory ids, uint256[] memory values)

```

```solidity
File: test/mocks/MockSYA.sol

10:     function burn(address from, uint256 id, uint256 amount) external;

14:     function surplus() external view returns (uint256);

15:     function skimSurplus(address token, address recipient) external returns (uint256);

62:     function setRewardToken(address _rewardToken) external {

66:     function setNFTMinter(address _nftMinter) external {

78:     function setOverEstimateBps(uint256 bps) external {

82:     function addYieldStrategy(address strategy, address token) external {

92:     function getYieldStrategies() external view returns (address[] memory) {

96:     function claim(uint256 nftIndex, uint256 minRewardTokenSupplied, address[] calldata exemptStrategies) external {

125:     function calculateClaimAmount(address[] calldata exemptStrategies) external view returns (uint256) {

141:     function _validateExempt(address[] calldata exemptStrategies) internal view {

147:     function _skip(address strategy, address token, address[] calldata exemptStrategies) internal view returns (bool) {

156:     function _normalize(uint256 amount, address token) internal view returns (uint256) {

161:     function _denormalize(uint256 amount, address token) internal view returns (uint256) {

```

```solidity
File: test/mocks/MockYieldStrategy.sol

37:     function setNestPoolManager(IPoolManager pm) external {

41:     function skimSurplus(address _token, address recipient) external returns (uint256 amount) {

```

```solidity
File: test/script/DeployHarvesterForTest.s.sol

20:     function run() external returns (SYAHarvester harvester) {

```

```solidity
File: test/utils/HarvesterFixture.sol

89:     function _addStrategy(MockERC20 token, uint256 surplus) internal returns (MockYieldStrategy s) {

96:     function _path(address tokenIn) internal view returns (address[11] memory p) {

102:     function _params() internal pure returns (uint256[5][5] memory p) {

106:     function _pools() internal pure returns (address[5] memory pools) {}

108:     function _none() internal pure returns (address[] memory) {

```

### <a name="NC-11"></a>[NC-11] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (7)*:
```solidity
File: test/SYAHarvester.gas.t.sol

6: interface IGasOverhead {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

22: interface ICurvePoolCoins {

26: interface ICurveRouterNGQuote {

35: interface IStateView {

39: interface ITotalSupply1155 {

```

```solidity
File: test/mocks/MockSYA.sol

9: interface IMockNFTMinter {

13: interface IMockStrategy {

```

### <a name="NC-12"></a>[NC-12] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (60)*:
```solidity
File: test/SYAHarvester.nft.t.sol

21:     function setUp() public override {
            super.setUp();
            nft = new MockERC1155();
            nft.setAuthorizedBurner(address(sya), true);
            sya.setNFTMinter(address(nft));
    
            nft.mint(keeper, NFT_INDEX, 2);
            vm.prank(keeper);
            nft.setApprovalForAll(address(harvester), true);

```

```solidity
File: test/SYAHarvester.registry.t.sol

38:     function setUp() public {
            sya = new MockSYA(usdc);
            harvester = new SYAHarvester(

135:     function test_setRoute_revertsForNonOwner() public {
             vm.prank(stranger);
             vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
             harvester.setRoute(usde, _singleHop(usde), _params(), _pools());

147:     function test_setEthPool_revertsForNonOwner() public {
             vm.prank(stranger);
             vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
             harvester.setEthPool(_ethKey());

157:     function test_setRoute_rejectsZeroToken() public {
             address[11] memory path = _singleHop(address(0));
             vm.prank(owner);
             vm.expectRevert(SYAHarvester.ZeroAddress.selector);
             harvester.setRoute(address(0), path, _params(), _pools());

164:     function test_setRoute_rejectsWrongFirstToken() public {
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteStart.selector, usde, dola));
             harvester.setRoute(usde, _singleHop(dola), _params(), _pools());

170:     function test_setRoute_rejectsRouteEndingAtNonRewardToken() public {
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));
             harvester.setRoute(usde, path, _params(), _pools());

180:     function test_setRoute_rejectsMultiHopEndingAtWrongToken() public {
             address[11] memory path = _multiHop(usde);
             path[4] = dola;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, dola));
             harvester.setRoute(usde, path, _params(), _pools());

208:     function test_setRoute_rejectsGappedRoute_trailingRewardToken() public {
             // The audit's mis-entered route: Router NG stops at path[3] == 0 and delivers `other`; the trailing
             // reward token at path[10] is never reached. The gap is reported first (it is the root cause).
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[10] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));
             harvester.setRoute(usde, path, _params(), _pools());

221:     function test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry() public {
             // The executed prefix already ends at the reward token; a duplicate trailing reward entry is still
             // a non-executed entry and is rejected.
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = usdc;
             path[10] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));
             harvester.setRoute(usde, path, _params(), _pools());

234:     function test_setRoute_rejectsStrayEntryAfterRewardToken() public {
             address[11] memory path = _singleHop(usde);
             path[4] = other; // never executed: path[3] == 0 ends the route at path[2]
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 4));
             harvester.setRoute(usde, path, _params(), _pools());

242:     function test_setRoute_rejectsGapInMultiHopRoute() public {
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[3] = pool1;
             path[4] = usdc;
             path[6] = usdc; // path[5] == 0: the route ends at path[4]; path[6] is a trailing entry
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));
             harvester.setRoute(usde, path, _params(), _pools());

255:     function test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate() public {
             // [usde, pool0, other, pool1, other2, 0, usdc, 0...]: Router NG delivers `other2` (path[4]); the
             // trailing reward token at path[6] is never reached.
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[3] = pool1;
             path[4] = other2;
             path[6] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));
             harvester.setRoute(usde, path, _params(), _pools());

270:     function test_setRoute_rejectsTrailingPoolSlotAfterRewardToken() public {
             address[11] memory path = _singleHop(usde);
             path[5] = pool1; // a pool slot after the executed prefix is still a trailing entry
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 5));
             harvester.setRoute(usde, path, _params(), _pools());

278:     function test_setRoute_storesFullFiveHopRoute() public {
             address[11] memory path = _fiveHop(usde, usdc);
             vm.prank(owner);
             harvester.setRoute(usde, path, _params(5), _pools(5));
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 i = 0; i < 11; i++) {

290:     function test_setRoute_rejectsFiveHopEndingAtNonRewardToken() public {
             address[11] memory path = _fiveHop(usde, other);
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));
             harvester.setRoute(usde, path, _params(5), _pools(5));

297:     function test_setRoute_rejectsNoHopRouteForNonRewardToken() public {
             // path[1] == 0: Router NG executes nothing; the "delivered" token is path[0] itself
             address[11] memory path;
             path[0] = usde;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, usde));
             harvester.setRoute(usde, path, _params(), _pools());

306:     function test_setRoute_rejectsNoHopRouteWithTrailingRewardToken() public {
             // path[1] == 0 with a trailing reward token: nothing executes, path[2] is a trailing entry
             address[11] memory path;
             path[0] = usde;
             path[2] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));
             harvester.setRoute(usde, path, _params(), _pools());

318:     function test_setRoute_acceptsNoHopRouteForRewardToken() public {
             address[11] memory path;
             path[0] = usdc;
             vm.prank(owner);
             harvester.setRoute(usdc, path, _params(0), _pools(0));
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usdc);
             assertTrue(r.configured);
             assertEq(r.path[0], usdc);
             assertEq(r.path[1], address(0));

330:     function test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry() public {
             address[11] memory path;
             path[0] = usdc;
             path[2] = other;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));
             harvester.setRoute(usdc, path, _params(), _pools());

339:     function test_setRoute_validatesAgainstCurrentRewardToken() public {
             sya.setRewardToken(other);
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, other, usdc));
             harvester.setRoute(usde, _singleHop(usde), _params(), _pools());

346:     function test_setRoute_storesSingleHop() public {
             address[11] memory path = _singleHop(usde);
             uint256[5][5] memory params = _params(1);
             address[5] memory pools = _pools(1);
     
             vm.prank(owner);
             harvester.setRoute(usde, path, params, pools);
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 i = 0; i < 11; i++) {
                 assertEq(r.path[i], path[i]);
             }
             for (uint256 i = 0; i < 5; i++) {

367:     function test_setRoute_storesMultiHop() public {
             address[11] memory path = _multiHop(dola);
     
             vm.prank(owner);
             harvester.setRoute(dola, path, _params(), _pools());
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(dola);
             assertTrue(r.configured);
             assertEq(r.path[0], dola);
             assertEq(r.path[2], other);
             assertEq(r.path[4], usdc);
             assertEq(r.path[5], address(0));
             assertEq(r.swapParams[1][3], 10);

382:     function test_setRoute_emitsRouteSet() public {
             vm.expectEmit(true, false, false, true, address(harvester));
             emit RouteSet(usde);
             vm.prank(owner);
             harvester.setRoute(usde, _singleHop(usde), _params(1), _pools(1));

393:     function test_setRoute_rejectsZeroIntermediateToken_twoHop() public {
             // [usde, pool0, 0, pool1, usdc, 0...]: the executed prefix delivers usdc but hop 0 outputs address(0)
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[3] = pool1;
             path[4] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));
             harvester.setRoute(usde, path, _params(2), _pools(2));

405:     function test_setRoute_rejectsZeroIntermediateToken_index6InFourHop() public {
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[3] = pool1;
             path[4] = dola;
             path[5] = pool0;
             // path[6] == 0: hop 2 outputs address(0)
             path[7] = pool1;
             path[8] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 6));
             harvester.setRoute(usde, path, _params(4), _pools(4));

421:     function test_setRoute_zeroIntermediateReportedBeforeWrongEnd() public {
             address[11] memory path = _multiHop(usde);
             path[2] = address(0);
             path[4] = other; // also delivers a non-reward token: the zero intermediate is reported first
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));
             harvester.setRoute(usde, path, _params(2), _pools(2));

430:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop() public {
             uint256[5][5] memory p = _params(1);
             p[0][2] = 0;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 0));
             harvester.setRoute(usde, _singleHop(usde), p, _pools(1));

438:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop() public {
             uint256[5][5] memory p = _params(2);
             p[1][2] = 0; // i/j/pool_type/n_coins still set: only swap_type decides "executed row non-empty"
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));
             harvester.setRoute(usde, _multiHop(usde), p, _pools(2));

446:     function test_setRoute_rejectsAllZeroExecutedRow_fiveHop() public {
             uint256[5][5] memory p = _params(5);
             delete p[4];
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 4));
             harvester.setRoute(usde, _fiveHop(usde, usdc), p, _pools(5));

454:     function test_setRoute_rejectsRowAtHopK_singleHop() public {
             // single-hop with row 1 set (the old two-row `_params()`): row 1 is never executed
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), _params(), _pools(1));

461:     function test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow() public {
             // a non-executed row with only its `i` field set is still non-zero
             uint256[5][5] memory p = _params(1);
             p[3][0] = 1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 3));
             harvester.setRoute(usde, _singleHop(usde), p, _pools(1));

470:     function test_setRoute_rejectsPoolAtHopK_singleHop() public {
             address[5] memory pools = _pools(1);
             pools[1] = pool1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), _params(1), pools);

478:     function test_setRoute_rejectsPoolInLastSlot_twoHop() public {
             address[5] memory pools = _pools(2);
             pools[4] = pool0;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 4));
             harvester.setRoute(usde, _multiHop(usde), _params(2), pools);

486:     function test_setRoute_unexecutedHopChecksParamsBeforePools() public {
             // hop 1 (k = 1) has both a stray row and a stray pool: the row is reported
             address[5] memory pools = _pools(1);
             pools[1] = pool1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), _params(), pools);

495:     function test_setRoute_unexecutedHopsAreCheckedInHopOrder() public {
             // stray pool at hop 1 and stray row at hop 2 (k = 1): hop 1 is checked first
             uint256[5][5] memory p = _params(1);
             p[2][2] = 1;
             address[5] memory pools = _pools(1);
             pools[1] = pool1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), p, pools);

506:     function test_setRoute_wrongEndReportedBeforeSwapParams() public {
             address[11] memory path = _singleHop(usde);
             path[2] = other;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));
             harvester.setRoute(usde, path, _params(), _pools());

514:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow() public {
             address[11] memory path;
             path[0] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 0));
             harvester.setRoute(usdc, path, _params(1), _pools(0));

522:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool() public {
             address[11] memory path;
             path[0] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 0));
             harvester.setRoute(usdc, path, _params(0), _pools(1));

530:     function test_setRoute_storesFullFiveHopRouteWithFiveValidRows() public {
             address[11] memory path = _fiveHop(usde, usdc);
             uint256[5][5] memory p = _params(5);
             vm.prank(owner);
             harvester.setRoute(usde, path, p, _pools(5));
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 h = 0; h < 5; h++) {

546:     function test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools() public {
             address[11] memory path = _singleHop(usde);
             uint256[5][5] memory p = _params(1);
             address[5] memory pools;
             vm.prank(owner);
             harvester.setRoute(usde, path, p, pools);
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 i = 0; i < 11; i++) {
                 assertEq(r.path[i], path[i]);
             }
             for (uint256 h = 0; h < 5; h++) {

566:     function test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools() public {
             address[11] memory path;
             path[0] = usdc;
             uint256[5][5] memory p;
             address[5] memory pools;
             vm.prank(owner);
             harvester.setRoute(usdc, path, p, pools);
             assertTrue(harvester.getRoute(usdc).configured);

586:     function test_clearRoute_resetsConfiguredAndEmits() public {
             vm.prank(owner);
             harvester.setRoute(usde, _singleHop(usde), _params(1), _pools(1));
     
             vm.expectEmit(true, false, false, true, address(harvester));
             emit RouteCleared(usde);
             vm.prank(owner);
             harvester.clearRoute(usde);
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertFalse(r.configured);
             assertEq(r.path[0], address(0));
             assertEq(r.swapParams[0][4], 0);
             assertEq(r.pools[0], address(0));

606:     function test_setEthPool_rejectsNonNativeCurrency0() public {
             PoolKey memory key = _ethKey();
             key.currency0 = Currency.wrap(other);
             vm.prank(owner);
             vm.expectRevert(SYAHarvester.InvalidEthPool.selector);
             harvester.setEthPool(key);

614:     function test_setEthPool_rejectsCurrency1NotRewardToken() public {
             PoolKey memory key = _ethKey();
             key.currency1 = Currency.wrap(other);
             vm.prank(owner);
             vm.expectRevert(SYAHarvester.InvalidEthPool.selector);
             harvester.setEthPool(key);

622:     function test_setEthPool_storesKeyAndEmits() public {
             PoolKey memory key = _ethKey();
     
             vm.expectEmit(true, true, false, true, address(harvester));
             emit EthPoolSet(address(0), usdc, 500, 10, address(0));
             vm.prank(owner);
             harvester.setEthPool(key);
     
             PoolKey memory stored = harvester.getEthPool();
             assertEq(Currency.unwrap(stored.currency0), address(0));
             assertEq(Currency.unwrap(stored.currency1), usdc);
             assertEq(stored.fee, 500);
             assertEq(stored.tickSpacing, 10);
             assertEq(address(stored.hooks), address(0));

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

16:     function setUp() public override {
            super.setUp();
            crvusd = new MockERC20("crvUSD", "crvUSD", 18);
            // The faithful mock would pay crvUSD for a gapped route, so make that payout possible
            crvusd.mint(address(router), 1e30);

```

```solidity
File: test/Toolchain.t.sol

9:     function setUp() public {
           deployFreshManagerAndRouters();

```

```solidity
File: test/mocks/MockCurveRouter.sol

36:     function setRate(address tokenIn, uint256 _rate) external {
            rate[tokenIn] = _rate;

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

28:     function setUp() public {
            router = new MockCurveRouter();
            tokenIn = new MockERC20("In", "IN", 18);
            mid = new MockERC20("Mid", "MID", 18);
            mid2 = new MockERC20("Mid2", "MID2", 18);
            mid3 = new MockERC20("Mid3", "MID3", 18);
            mid4 = new MockERC20("Mid4", "MID4", 18);
            tokenOut = new MockERC20("Out", "OUT", 18);
    
            // Pre-fund the payout side of every token a route could resolve to
            mid.mint(address(router), 1e30);
            mid2.mint(address(router), 1e30);
            mid3.mint(address(router), 1e30);
            mid4.mint(address(router), 1e30);
            tokenOut.mint(address(router), 1e30);
    
            router.setRate(address(tokenIn), 1e18);
            tokenIn.mint(address(this), 1e30);
            tokenIn.approve(address(router), type(uint256).max);

```

```solidity
File: test/mocks/MockERC1155.sol

22:     function setAuthorizedBurner(address burner, bool authorized) external {
            authorizedBurners[burner] = authorized;

31:     function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
            internal
            override(ERC1155Supply)
        {
            super._update(from, to, ids, values);

```

```solidity
File: test/mocks/MockSYA.sol

62:     function setRewardToken(address _rewardToken) external {
            rewardToken = _rewardToken;

66:     function setNFTMinter(address _nftMinter) external {
            nftMinter = _nftMinter;

70:     function setNftMode(NftMode mode) external {
            nftMode = mode;

74:     function setDiscountRate(uint256 rate) external {
            discountRate = rate;

78:     function setOverEstimateBps(uint256 bps) external {
            overEstimateBps = bps;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

28:     function setSurplus(uint256 _surplus) external {
            surplus = _surplus;

32:     function setPaused(bool _paused) external {
            paused = _paused;

37:     function setNestPoolManager(IPoolManager pm) external {
            nestPoolManager = pm;

```

### <a name="NC-13"></a>[NC-13] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (57)*:
```solidity
File: test/SYAHarvester.nft.t.sol

21:     function setUp() public override {
            super.setUp();
            nft = new MockERC1155();
            nft.setAuthorizedBurner(address(sya), true);
            sya.setNFTMinter(address(nft));
    
            nft.mint(keeper, NFT_INDEX, 2);
            vm.prank(keeper);
            nft.setApprovalForAll(address(harvester), true);

```

```solidity
File: test/SYAHarvester.registry.t.sol

38:     function setUp() public {
            sya = new MockSYA(usdc);
            harvester = new SYAHarvester(

135:     function test_setRoute_revertsForNonOwner() public {
             vm.prank(stranger);
             vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
             harvester.setRoute(usde, _singleHop(usde), _params(), _pools());

147:     function test_setEthPool_revertsForNonOwner() public {
             vm.prank(stranger);
             vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
             harvester.setEthPool(_ethKey());

157:     function test_setRoute_rejectsZeroToken() public {
             address[11] memory path = _singleHop(address(0));
             vm.prank(owner);
             vm.expectRevert(SYAHarvester.ZeroAddress.selector);
             harvester.setRoute(address(0), path, _params(), _pools());

164:     function test_setRoute_rejectsWrongFirstToken() public {
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteStart.selector, usde, dola));
             harvester.setRoute(usde, _singleHop(dola), _params(), _pools());

170:     function test_setRoute_rejectsRouteEndingAtNonRewardToken() public {
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));
             harvester.setRoute(usde, path, _params(), _pools());

180:     function test_setRoute_rejectsMultiHopEndingAtWrongToken() public {
             address[11] memory path = _multiHop(usde);
             path[4] = dola;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, dola));
             harvester.setRoute(usde, path, _params(), _pools());

208:     function test_setRoute_rejectsGappedRoute_trailingRewardToken() public {
             // The audit's mis-entered route: Router NG stops at path[3] == 0 and delivers `other`; the trailing
             // reward token at path[10] is never reached. The gap is reported first (it is the root cause).
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[10] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));
             harvester.setRoute(usde, path, _params(), _pools());

221:     function test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry() public {
             // The executed prefix already ends at the reward token; a duplicate trailing reward entry is still
             // a non-executed entry and is rejected.
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = usdc;
             path[10] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 10));
             harvester.setRoute(usde, path, _params(), _pools());

234:     function test_setRoute_rejectsStrayEntryAfterRewardToken() public {
             address[11] memory path = _singleHop(usde);
             path[4] = other; // never executed: path[3] == 0 ends the route at path[2]
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 4));
             harvester.setRoute(usde, path, _params(), _pools());

242:     function test_setRoute_rejectsGapInMultiHopRoute() public {
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[3] = pool1;
             path[4] = usdc;
             path[6] = usdc; // path[5] == 0: the route ends at path[4]; path[6] is a trailing entry
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));
             harvester.setRoute(usde, path, _params(), _pools());

255:     function test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate() public {
             // [usde, pool0, other, pool1, other2, 0, usdc, 0...]: Router NG delivers `other2` (path[4]); the
             // trailing reward token at path[6] is never reached.
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[3] = pool1;
             path[4] = other2;
             path[6] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 6));
             harvester.setRoute(usde, path, _params(), _pools());

270:     function test_setRoute_rejectsTrailingPoolSlotAfterRewardToken() public {
             address[11] memory path = _singleHop(usde);
             path[5] = pool1; // a pool slot after the executed prefix is still a trailing entry
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 5));
             harvester.setRoute(usde, path, _params(), _pools());

278:     function test_setRoute_storesFullFiveHopRoute() public {
             address[11] memory path = _fiveHop(usde, usdc);
             vm.prank(owner);
             harvester.setRoute(usde, path, _params(5), _pools(5));
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 i = 0; i < 11; i++) {

290:     function test_setRoute_rejectsFiveHopEndingAtNonRewardToken() public {
             address[11] memory path = _fiveHop(usde, other);
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));
             harvester.setRoute(usde, path, _params(5), _pools(5));

297:     function test_setRoute_rejectsNoHopRouteForNonRewardToken() public {
             // path[1] == 0: Router NG executes nothing; the "delivered" token is path[0] itself
             address[11] memory path;
             path[0] = usde;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, usde));
             harvester.setRoute(usde, path, _params(), _pools());

306:     function test_setRoute_rejectsNoHopRouteWithTrailingRewardToken() public {
             // path[1] == 0 with a trailing reward token: nothing executes, path[2] is a trailing entry
             address[11] memory path;
             path[0] = usde;
             path[2] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));
             harvester.setRoute(usde, path, _params(), _pools());

318:     function test_setRoute_acceptsNoHopRouteForRewardToken() public {
             address[11] memory path;
             path[0] = usdc;
             vm.prank(owner);
             harvester.setRoute(usdc, path, _params(0), _pools(0));
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usdc);
             assertTrue(r.configured);
             assertEq(r.path[0], usdc);
             assertEq(r.path[1], address(0));

330:     function test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry() public {
             address[11] memory path;
             path[0] = usdc;
             path[2] = other;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteGap(uint256)", 2));
             harvester.setRoute(usdc, path, _params(), _pools());

339:     function test_setRoute_validatesAgainstCurrentRewardToken() public {
             sya.setRewardToken(other);
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, other, usdc));
             harvester.setRoute(usde, _singleHop(usde), _params(), _pools());

346:     function test_setRoute_storesSingleHop() public {
             address[11] memory path = _singleHop(usde);
             uint256[5][5] memory params = _params(1);
             address[5] memory pools = _pools(1);
     
             vm.prank(owner);
             harvester.setRoute(usde, path, params, pools);
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 i = 0; i < 11; i++) {
                 assertEq(r.path[i], path[i]);
             }
             for (uint256 i = 0; i < 5; i++) {

367:     function test_setRoute_storesMultiHop() public {
             address[11] memory path = _multiHop(dola);
     
             vm.prank(owner);
             harvester.setRoute(dola, path, _params(), _pools());
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(dola);
             assertTrue(r.configured);
             assertEq(r.path[0], dola);
             assertEq(r.path[2], other);
             assertEq(r.path[4], usdc);
             assertEq(r.path[5], address(0));
             assertEq(r.swapParams[1][3], 10);

393:     function test_setRoute_rejectsZeroIntermediateToken_twoHop() public {
             // [usde, pool0, 0, pool1, usdc, 0...]: the executed prefix delivers usdc but hop 0 outputs address(0)
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[3] = pool1;
             path[4] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));
             harvester.setRoute(usde, path, _params(2), _pools(2));

405:     function test_setRoute_rejectsZeroIntermediateToken_index6InFourHop() public {
             address[11] memory path;
             path[0] = usde;
             path[1] = pool0;
             path[2] = other;
             path[3] = pool1;
             path[4] = dola;
             path[5] = pool0;
             // path[6] == 0: hop 2 outputs address(0)
             path[7] = pool1;
             path[8] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 6));
             harvester.setRoute(usde, path, _params(4), _pools(4));

421:     function test_setRoute_zeroIntermediateReportedBeforeWrongEnd() public {
             address[11] memory path = _multiHop(usde);
             path[2] = address(0);
             path[4] = other; // also delivers a non-reward token: the zero intermediate is reported first
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteToken(uint256)", 2));
             harvester.setRoute(usde, path, _params(2), _pools(2));

430:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop() public {
             uint256[5][5] memory p = _params(1);
             p[0][2] = 0;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 0));
             harvester.setRoute(usde, _singleHop(usde), p, _pools(1));

438:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop() public {
             uint256[5][5] memory p = _params(2);
             p[1][2] = 0; // i/j/pool_type/n_coins still set: only swap_type decides "executed row non-empty"
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));
             harvester.setRoute(usde, _multiHop(usde), p, _pools(2));

446:     function test_setRoute_rejectsAllZeroExecutedRow_fiveHop() public {
             uint256[5][5] memory p = _params(5);
             delete p[4];
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 4));
             harvester.setRoute(usde, _fiveHop(usde, usdc), p, _pools(5));

454:     function test_setRoute_rejectsRowAtHopK_singleHop() public {
             // single-hop with row 1 set (the old two-row `_params()`): row 1 is never executed
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), _params(), _pools(1));

461:     function test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow() public {
             // a non-executed row with only its `i` field set is still non-zero
             uint256[5][5] memory p = _params(1);
             p[3][0] = 1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 3));
             harvester.setRoute(usde, _singleHop(usde), p, _pools(1));

470:     function test_setRoute_rejectsPoolAtHopK_singleHop() public {
             address[5] memory pools = _pools(1);
             pools[1] = pool1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), _params(1), pools);

478:     function test_setRoute_rejectsPoolInLastSlot_twoHop() public {
             address[5] memory pools = _pools(2);
             pools[4] = pool0;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 4));
             harvester.setRoute(usde, _multiHop(usde), _params(2), pools);

486:     function test_setRoute_unexecutedHopChecksParamsBeforePools() public {
             // hop 1 (k = 1) has both a stray row and a stray pool: the row is reported
             address[5] memory pools = _pools(1);
             pools[1] = pool1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), _params(), pools);

495:     function test_setRoute_unexecutedHopsAreCheckedInHopOrder() public {
             // stray pool at hop 1 and stray row at hop 2 (k = 1): hop 1 is checked first
             uint256[5][5] memory p = _params(1);
             p[2][2] = 1;
             address[5] memory pools = _pools(1);
             pools[1] = pool1;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 1));
             harvester.setRoute(usde, _singleHop(usde), p, pools);

506:     function test_setRoute_wrongEndReportedBeforeSwapParams() public {
             address[11] memory path = _singleHop(usde);
             path[2] = other;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSelector(SYAHarvester.InvalidRouteEnd.selector, usdc, other));
             harvester.setRoute(usde, path, _params(), _pools());

514:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow() public {
             address[11] memory path;
             path[0] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRouteSwapParams(uint256)", 0));
             harvester.setRoute(usdc, path, _params(1), _pools(0));

522:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool() public {
             address[11] memory path;
             path[0] = usdc;
             vm.prank(owner);
             vm.expectRevert(abi.encodeWithSignature("InvalidRoutePools(uint256)", 0));
             harvester.setRoute(usdc, path, _params(0), _pools(1));

530:     function test_setRoute_storesFullFiveHopRouteWithFiveValidRows() public {
             address[11] memory path = _fiveHop(usde, usdc);
             uint256[5][5] memory p = _params(5);
             vm.prank(owner);
             harvester.setRoute(usde, path, p, _pools(5));
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 h = 0; h < 5; h++) {

546:     function test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools() public {
             address[11] memory path = _singleHop(usde);
             uint256[5][5] memory p = _params(1);
             address[5] memory pools;
             vm.prank(owner);
             harvester.setRoute(usde, path, p, pools);
     
             SYAHarvester.CurveRoute memory r = harvester.getRoute(usde);
             assertTrue(r.configured);
             for (uint256 i = 0; i < 11; i++) {
                 assertEq(r.path[i], path[i]);
             }
             for (uint256 h = 0; h < 5; h++) {

566:     function test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools() public {
             address[11] memory path;
             path[0] = usdc;
             uint256[5][5] memory p;
             address[5] memory pools;
             vm.prank(owner);
             harvester.setRoute(usdc, path, p, pools);
             assertTrue(harvester.getRoute(usdc).configured);

606:     function test_setEthPool_rejectsNonNativeCurrency0() public {
             PoolKey memory key = _ethKey();
             key.currency0 = Currency.wrap(other);
             vm.prank(owner);
             vm.expectRevert(SYAHarvester.InvalidEthPool.selector);
             harvester.setEthPool(key);

614:     function test_setEthPool_rejectsCurrency1NotRewardToken() public {
             PoolKey memory key = _ethKey();
             key.currency1 = Currency.wrap(other);
             vm.prank(owner);
             vm.expectRevert(SYAHarvester.InvalidEthPool.selector);
             harvester.setEthPool(key);

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

16:     function setUp() public override {
            super.setUp();
            crvusd = new MockERC20("crvUSD", "crvUSD", 18);
            // The faithful mock would pay crvUSD for a gapped route, so make that payout possible
            crvusd.mint(address(router), 1e30);

```

```solidity
File: test/Toolchain.t.sol

9:     function setUp() public {
           deployFreshManagerAndRouters();

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

81:     function setUp() public {
            string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
            if (bytes(rpc).length == 0) {
                console2.log("MAINNET_RPC_URL unset: skipping the mainnet fork suite");
                vm.skip(true);
                return;
            }
            vm.createSelectFork(vm.rpcUrl("mainnet"), A.PINNED_BLOCK);
    
            harvester = new SYAHarvester(owner, pm, sya, ICurveRouterNG(A.CURVE_ROUTER_NG));
            vm.label(address(harvester), "SYAHarvester");
            vm.startPrank(owner);
            MainnetRoutes.configure(harvester);
            vm.stopPrank();
    
            // Claim NFT, method 1 of 3 (preferred): prank an existing holder of a valid index and transfer one
            // unit. NFT_HOLDER is an EOA with exactly 1 unit of index 1 at PINNED_BLOCK, so neither
            // `setAuthorizedMinter`+`mintFor` (method 2) nor the paid `mint` (method 3) is needed.
            vm.prank(A.NFT_HOLDER);
            nft.safeTransferFrom(A.NFT_HOLDER, keeper, A.NFT_INDEX, 1, "");
            vm.prank(keeper);
            nft.setApprovalForAll(address(harvester), true);
    
            // Accrual: time alone grows every live strategy's surplus (see test_fork_accrual_warpAloneProducesYield),
            // so no donation/simulated accrual is needed.
            vm.warp(block.timestamp + ACCRUAL_WARP);
            vm.roll(block.number + ACCRUAL_WARP / 12);

```

```solidity
File: test/mocks/MockCurveRouter.sol

36:     function setRate(address tokenIn, uint256 _rate) external {
            rate[tokenIn] = _rate;

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

28:     function setUp() public {
            router = new MockCurveRouter();
            tokenIn = new MockERC20("In", "IN", 18);
            mid = new MockERC20("Mid", "MID", 18);
            mid2 = new MockERC20("Mid2", "MID2", 18);
            mid3 = new MockERC20("Mid3", "MID3", 18);
            mid4 = new MockERC20("Mid4", "MID4", 18);
            tokenOut = new MockERC20("Out", "OUT", 18);
    
            // Pre-fund the payout side of every token a route could resolve to
            mid.mint(address(router), 1e30);
            mid2.mint(address(router), 1e30);
            mid3.mint(address(router), 1e30);
            mid4.mint(address(router), 1e30);
            tokenOut.mint(address(router), 1e30);
    
            router.setRate(address(tokenIn), 1e18);
            tokenIn.mint(address(this), 1e30);
            tokenIn.approve(address(router), type(uint256).max);

```

```solidity
File: test/mocks/MockERC1155.sol

22:     function setAuthorizedBurner(address burner, bool authorized) external {
            authorizedBurners[burner] = authorized;

```

```solidity
File: test/mocks/MockSYA.sol

62:     function setRewardToken(address _rewardToken) external {
            rewardToken = _rewardToken;

66:     function setNFTMinter(address _nftMinter) external {
            nftMinter = _nftMinter;

70:     function setNftMode(NftMode mode) external {
            nftMode = mode;

74:     function setDiscountRate(uint256 rate) external {
            discountRate = rate;

78:     function setOverEstimateBps(uint256 bps) external {
            overEstimateBps = bps;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

28:     function setSurplus(uint256 _surplus) external {
            surplus = _surplus;

32:     function setPaused(bool _paused) external {
            paused = _paused;

37:     function setNestPoolManager(IPoolManager pm) external {
            nestPoolManager = pm;

```

### <a name="NC-14"></a>[NC-14] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (119)*:
```solidity
File: test/SYAHarvester.gas.t.sol

56:     function test_gas_costAboveEthOut_revertsUnprofitable() public {

69:     function test_gas_zeroGasPrice_passesTrivially() public {

81:     function test_gas_chargedUnits_coverMeasuredWorkPlusOverhead() public {

93:     function test_gas_borderlinePrice_flipsPassFail() public {

110:     function test_gas_minEthOutSatisfied_butUnprofitable_stillReverts() public {

```

```solidity
File: test/SYAHarvester.harvest.t.sol

20:     function test_harvest_profitablePath_paysEthToCaller() public {

35:     function test_harvest_profitablePath_withLiveLikeOverEstimate() public {

47:     function test_harvest_minEthOutAboveOutput_reverts() public {

62:     function test_harvest_unroutedToken_revertsRouteNotConfigured() public {

70:     function test_harvest_rewardTokenStrategy_skippedNoRouterCall() public {

85:     function test_harvest_exemptStrategy_notSkimmedNotSold() public {

102:     function test_harvest_pausedToken_skippedNoCoverageRevert() public {

119:     function test_unlockCallback_directCall_revertsNotPoolManager() public {

125:     function test_receive_fromNonPoolManager_reverts() public {

137:     function test_harvest_unprofitableClaim_reverts() public {

147:     function test_harvest_nestedUnlockInSkimSurplus_reverts() public {

155:     function test_harvest_ethPoolNotSet_reverts() public {

```

```solidity
File: test/SYAHarvester.nft.t.sol

21:     function setUp() public override {

41:     function test_nft_pulledThenBurned_noRefund() public {

64:     function test_nft_ignoredBySya_heldDuringUnlock_thenRefunded() public {

76:     function test_nft_refundReturnsWholeBalance_includingStrayUnits() public {

97:     function test_nft_indexZero_noErc1155Calls() public {

108:     function test_nft_noMinterConfigured_skipsBothTransfers() public {

124:     function test_nft_callerWithoutApproval_revertsOnPull() public {

135:     function test_nft_burnNeedsNoApprovalFromHarvester() public {

```

```solidity
File: test/SYAHarvester.registry.t.sol

38:     function setUp() public {

107:     function test_constructor_rejectsZeroPoolManager() public {

112:     function test_constructor_rejectsZeroSya() public {

117:     function test_constructor_rejectsZeroRouter() public {

124:     function test_constructor_rejectsZeroOwner() public {

135:     function test_setRoute_revertsForNonOwner() public {

141:     function test_clearRoute_revertsForNonOwner() public {

147:     function test_setEthPool_revertsForNonOwner() public {

157:     function test_setRoute_rejectsZeroToken() public {

164:     function test_setRoute_rejectsWrongFirstToken() public {

170:     function test_setRoute_rejectsRouteEndingAtNonRewardToken() public {

180:     function test_setRoute_rejectsMultiHopEndingAtWrongToken() public {

208:     function test_setRoute_rejectsGappedRoute_trailingRewardToken() public {

221:     function test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry() public {

234:     function test_setRoute_rejectsStrayEntryAfterRewardToken() public {

242:     function test_setRoute_rejectsGapInMultiHopRoute() public {

255:     function test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate() public {

270:     function test_setRoute_rejectsTrailingPoolSlotAfterRewardToken() public {

278:     function test_setRoute_storesFullFiveHopRoute() public {

290:     function test_setRoute_rejectsFiveHopEndingAtNonRewardToken() public {

297:     function test_setRoute_rejectsNoHopRouteForNonRewardToken() public {

306:     function test_setRoute_rejectsNoHopRouteWithTrailingRewardToken() public {

330:     function test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry() public {

339:     function test_setRoute_validatesAgainstCurrentRewardToken() public {

346:     function test_setRoute_storesSingleHop() public {

367:     function test_setRoute_storesMultiHop() public {

382:     function test_setRoute_emitsRouteSet() public {

393:     function test_setRoute_rejectsZeroIntermediateToken_twoHop() public {

405:     function test_setRoute_rejectsZeroIntermediateToken_index6InFourHop() public {

421:     function test_setRoute_zeroIntermediateReportedBeforeWrongEnd() public {

430:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop() public {

438:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop() public {

446:     function test_setRoute_rejectsAllZeroExecutedRow_fiveHop() public {

454:     function test_setRoute_rejectsRowAtHopK_singleHop() public {

461:     function test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow() public {

470:     function test_setRoute_rejectsPoolAtHopK_singleHop() public {

478:     function test_setRoute_rejectsPoolInLastSlot_twoHop() public {

486:     function test_setRoute_unexecutedHopChecksParamsBeforePools() public {

495:     function test_setRoute_unexecutedHopsAreCheckedInHopOrder() public {

506:     function test_setRoute_wrongEndReportedBeforeSwapParams() public {

514:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow() public {

522:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool() public {

530:     function test_setRoute_storesFullFiveHopRouteWithFiveValidRows() public {

546:     function test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools() public {

566:     function test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools() public {

586:     function test_clearRoute_resetsConfiguredAndEmits() public {

606:     function test_setEthPool_rejectsNonNativeCurrency0() public {

614:     function test_setEthPool_rejectsCurrency1NotRewardToken() public {

622:     function test_setEthPool_storesKeyAndEmits() public {

638:     function test_noHarvestFunction() public {

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

16:     function setUp() public override {

30:     function test_routeGap_gappedRouteCannotBeStored() public {

41:     function test_routeGap_mockDeliversIntermediateForGappedPath() public {

51:     function test_routeGap_contiguousFixtureRoute_harvestLeavesNoBalances() public {

```

```solidity
File: test/Toolchain.t.sol

9:     function setUp() public {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

81:     function setUp() public {

112:     function unlockCallback(bytes calldata) external returns (bytes memory) {

149:     function test_fork_addresses_verifiedOnFork() public {

284:     function test_fork_harvest_endToEnd_paysEthBurnsNftLeavesNoBalances() public {

319:     function test_fork_harvest_eachStrategyExemptedInTurn() public {

349:     function test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut() public {

421:     function test_fork_M01_gapRoute_rejectedBySetRoute() public {

433:     function test_fork_M01_contiguousRoute_harvestsAndLeavesHarvesterEmpty() public {

547:     function test_fork_zeroIntermediate_rejectedBySetRoute() public {

```

```solidity
File: test/mocks/MockCurveRouter.sol

36:     function setRate(address tokenIn, uint256 _rate) external {

57:     function exchange(

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

28:     function setUp() public {

61:     function test_exchange_contiguousRoute_deliversFinalToken() public {

78:     function test_exchange_gappedRoute_deliversIntermediateToken() public {

92:     function test_exchange_gapInMultiHopRoute_deliversPath2k() public {

108:     function test_exchange_fiveHopRoute_deliversPath10() public {

128:     function test_exchange_noHop_reverts() public {

138:     function test_exchange_zeroOutputToken_reverts() public {

148:     function test_exchange_slippage_stillEnforced() public {

159:     function test_exchange_zeroIntermediateToken_reverts() public {

171:     function test_resolveOutput_zeroIntermediateToken_reverts() public {

184:     function test_exchange_executedRowWithZeroSwapType_reverts() public {

199:     function test_exchange_ignoresRowsBeyondExecutedPrefix() public {

```

```solidity
File: test/mocks/MockERC1155.sol

18:     function mint(address to, uint256 id, uint256 amount) external {

22:     function setAuthorizedBurner(address burner, bool authorized) external {

26:     function burn(address from, uint256 id, uint256 amount) external {

```

```solidity
File: test/mocks/MockSYA.sol

10:     function burn(address from, uint256 id, uint256 amount) external;

15:     function skimSurplus(address token, address recipient) external returns (uint256);

62:     function setRewardToken(address _rewardToken) external {

66:     function setNFTMinter(address _nftMinter) external {

70:     function setNftMode(NftMode mode) external {

74:     function setDiscountRate(uint256 rate) external {

78:     function setOverEstimateBps(uint256 bps) external {

82:     function addYieldStrategy(address strategy, address token) external {

88:     function pauseToken(address token) external {

96:     function claim(uint256 nftIndex, uint256 minRewardTokenSupplied, address[] calldata exemptStrategies) external {

```

```solidity
File: test/mocks/MockYieldStrategy.sol

32:     function setPaused(bool _paused) external {

41:     function skimSurplus(address _token, address recipient) external returns (uint256 amount) {

```

```solidity
File: test/script/DeployHarvesterForTest.s.sol

20:     function run() external returns (SYAHarvester harvester) {

```

### <a name="NC-15"></a>[NC-15] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (2)*:
```solidity
File: test/mocks/MockYieldStrategy.sol

27:     /// @notice Set the surplus; the caller must ensure this contract holds at least that much `token`
        function setSurplus(uint256 _surplus) external {

36:     /// @notice When set, `skimSurplus` calls `pm.unlock` (reverts `AlreadyUnlocked` inside a callback)
        function setNestPoolManager(IPoolManager pm) external {

```

### <a name="NC-16"></a>[NC-16] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (5)*:
```solidity
File: src/SYAHarvester.sol

322:         if (msg.sender != address(poolManager)) revert NotPoolManager();

343:         if (msg.sender != address(poolManager)) revert NotPoolManager();

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

113:         require(msg.sender == address(pm), "not pm");

```

```solidity
File: test/mocks/MockERC1155.sol

27:         if (!authorizedBurners[msg.sender]) revert NotAuthorizedBurner(msg.sender);

```

```solidity
File: test/mocks/MockSYA.sol

100:             if (IERC1155(nftMinter).balanceOf(msg.sender, nftIndex) == 0) revert NoValidNFT();

```

### <a name="NC-17"></a>[NC-17] Constant state variables defined more than once
Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (2)*:
```solidity
File: test/SYAHarvester.nft.t.sol

19:     uint256 internal constant NFT_INDEX = 3;

```

```solidity
File: test/fork/MainnetAddresses.sol

52:     uint256 internal constant NFT_INDEX = 1;

```

### <a name="NC-18"></a>[NC-18] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (7)*:
```solidity
File: src/SYAHarvester.sol

63:     mapping(address => CurveRoute) private routes;

```

```solidity
File: test/mocks/MockCurveRouter.sol

32:     mapping(address => uint256) public rate;

34:     mapping(address => uint256) public calls;

```

```solidity
File: test/mocks/MockERC1155.sol

14:     mapping(address => bool) public authorizedBurners;

```

```solidity
File: test/mocks/MockSYA.sol

52:     mapping(address => address) public strategyTokens;

53:     mapping(address => bool) public isRegisteredStrategy;

54:     mapping(address => bool) public tokenPaused;

```

### <a name="NC-19"></a>[NC-19] `address`s shouldn't be hard-coded
It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (21)*:
```solidity
File: test/fork/MainnetAddresses.sol

19:     address internal constant SYA = 0x0cD353bfda674D04823B2826ffafB83B560D21B6;

21:     address internal constant YS_USDC = 0xaFDf8DeA96a0F37Aae4869f813901bf73a3eAB83;

23:     address internal constant YS_USDE = 0xaC2e5936Eca286eC364d4D5Bcca33145fBe57f95;

25:     address internal constant YS_DOLA = 0x981c7BE1460c7C8Cb40B8EB5908B29510Ae0B7EE;

27:     address internal constant NFT_MINTER = 0x39Af088408e815844c567037C157B31d48d2E10F;

29:     address internal constant USDE_AMM_ADAPTER = 0x2D024e0d03Fb6Ead4F8E7Ba1EBECF6db0E755D6f;

32:     address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // mainnet-addresses.ts

33:     address internal constant DOLA = 0x865377367054516e17014CcdED1e7d814EDC9ce4; // mainnet-addresses.ts

34:     address internal constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3; // mainnet-addresses.ts

35:     address internal constant CRVUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E; // archive scripts

36:     address internal constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e; // fork (FRAXBP coin0)

39:     address internal constant CURVE_ROUTER_NG = 0x16C6521Dff6baB339122a0FE25a9116693265353; // archive scripts

41:     address internal constant CURVE_META_REGISTRY = 0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC; // fork

44:     address internal constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;

46:     address internal constant V4_STATE_VIEW = 0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227;

51:     address internal constant NFT_HOLDER = 0x025494682Fb33792145F1a459555C7000BaB53C4;

```

```solidity
File: test/fork/MainnetRoutes.sol

53:     address internal constant POOL_USDE_CRVUSD = 0xF55B0f6F2Da5ffDDb104b58a60F2862745960442;

55:     address internal constant POOL_CRVUSD_USDC = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;

57:     address internal constant POOL_DOLA_FRAXBP = 0xE57180685E3348589E9521aa53Af0BCD497E884d;

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

78:     address internal constant FRAXBP_POOL = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;

79:     address internal constant FRAXBP_LP = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;

```

### <a name="NC-20"></a>[NC-20] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (43)*:
```solidity
File: src/SYAHarvester.sol

125:             revert ZeroAddress();

157:         if (token == address(0)) revert ZeroAddress();

220:             revert InvalidEthPool();

276:         if (Currency.unwrap(ethPool.currency1) == address(0)) revert EthPoolNotSet();

300:         if (!ok) revert EthTransferFailed();

322:         if (msg.sender != address(poolManager)) revert NotPoolManager();

343:         if (msg.sender != address(poolManager)) revert NotPoolManager();

```

```solidity
File: test/SYAHarvester.gas.t.sol

56:     function test_gas_costAboveEthOut_revertsUnprofitable() public {

110:     function test_gas_minEthOutSatisfied_butUnprofitable_stillReverts() public {

```

```solidity
File: test/SYAHarvester.harvest.t.sol

47:     function test_harvest_minEthOutAboveOutput_reverts() public {

62:     function test_harvest_unroutedToken_revertsRouteNotConfigured() public {

102:     function test_harvest_pausedToken_skippedNoCoverageRevert() public {

119:     function test_unlockCallback_directCall_revertsNotPoolManager() public {

125:     function test_receive_fromNonPoolManager_reverts() public {

137:     function test_harvest_unprofitableClaim_reverts() public {

147:     function test_harvest_nestedUnlockInSkimSurplus_reverts() public {

155:     function test_harvest_ethPoolNotSet_reverts() public {

```

```solidity
File: test/SYAHarvester.nft.t.sol

124:     function test_nft_callerWithoutApproval_revertsOnPull() public {

```

```solidity
File: test/SYAHarvester.registry.t.sol

135:     function test_setRoute_revertsForNonOwner() public {

141:     function test_clearRoute_revertsForNonOwner() public {

147:     function test_setEthPool_revertsForNonOwner() public {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

340:     function test_fork_harvest_highGasPrice_revertsUnprofitable() public {

349:     function test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut() public {

511:     function test_fork_zeroIntermediate_realRouterReverts_mockAgrees() public {

530:     function test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees() public {

```

```solidity
File: test/mocks/MockCurveRouter.sol

47:         if (_route[1] == address(0)) revert NoHop();

52:             if (tokenOut == address(0)) revert ZeroIntermediateToken();

54:         if (tokenOut == address(0)) revert ZeroOutputToken();

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

128:     function test_exchange_noHop_reverts() public {

134:         vm.expectRevert(abi.encodeWithSignature("NoHop()"));

138:     function test_exchange_zeroOutputToken_reverts() public {

144:         vm.expectRevert(abi.encodeWithSignature("ZeroOutputToken()"));

159:     function test_exchange_zeroIntermediateToken_reverts() public {

167:         vm.expectRevert(abi.encodeWithSignature("ZeroIntermediateToken()"));

171:     function test_resolveOutput_zeroIntermediateToken_reverts() public {

180:         vm.expectRevert(abi.encodeWithSignature("ZeroIntermediateToken()"));

184:     function test_exchange_executedRowWithZeroSwapType_reverts() public {

```

```solidity
File: test/mocks/MockSYA.sol

100:             if (IERC1155(nftMinter).balanceOf(msg.sender, nftIndex) == 0) revert NoValidNFT();

116:         if (totalNormalizedYield == 0) revert ZeroAmount();

119:         if (payment < minRewardTokenSupplied) revert InsufficientYield();

143:             if (!isRegisteredStrategy[exemptStrategies[i]]) revert ExemptStrategyNotRegistered();

```

```solidity
File: test/mocks/MockYieldStrategy.sol

42:         if (paused) revert StrategyPaused();

43:         if (_token != token) revert WrongToken();

```

### <a name="NC-21"></a>[NC-21] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (9)*:
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
   ErrorDefinition.InvalidRouteGap
   ErrorDefinition.InvalidRouteToken
   ErrorDefinition.InvalidRouteSwapParams
   ErrorDefinition.InvalidRoutePools
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
   ErrorDefinition.InvalidRouteGap
   ErrorDefinition.InvalidRouteToken
   ErrorDefinition.InvalidRouteSwapParams
   ErrorDefinition.InvalidRoutePools
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

```solidity
File: test/SYAHarvester.gas.t.sol

1: 
   Current order:
   FunctionDefinition.GAS_OVERHEAD
   VariableDeclaration.UNPROFITABLE
   FunctionDefinition._ethOutAtZeroPrice
   FunctionDefinition._harvestAt
   FunctionDefinition._decodeUnprofitable
   FunctionDefinition._chargedGasUnits
   FunctionDefinition.test_gas_costAboveEthOut_revertsUnprofitable
   FunctionDefinition.test_gas_zeroGasPrice_passesTrivially
   FunctionDefinition.test_gas_chargedUnits_coverMeasuredWorkPlusOverhead
   FunctionDefinition.test_gas_borderlinePrice_flipsPassFail
   FunctionDefinition.test_gas_minEthOutSatisfied_butUnprofitable_stillReverts
   
   Suggested order:
   VariableDeclaration.UNPROFITABLE
   FunctionDefinition.GAS_OVERHEAD
   FunctionDefinition._ethOutAtZeroPrice
   FunctionDefinition._harvestAt
   FunctionDefinition._decodeUnprofitable
   FunctionDefinition._chargedGasUnits
   FunctionDefinition.test_gas_costAboveEthOut_revertsUnprofitable
   FunctionDefinition.test_gas_zeroGasPrice_passesTrivially
   FunctionDefinition.test_gas_chargedUnits_coverMeasuredWorkPlusOverhead
   FunctionDefinition.test_gas_borderlinePrice_flipsPassFail
   FunctionDefinition.test_gas_minEthOutSatisfied_butUnprofitable_stillReverts

```

```solidity
File: test/SYAHarvester.registry.t.sol

1: 
   Current order:
   EventDefinition.RouteSet
   EventDefinition.RouteCleared
   EventDefinition.EthPoolSet
   VariableDeclaration.harvester
   VariableDeclaration.sya
   VariableDeclaration.owner
   VariableDeclaration.stranger
   VariableDeclaration.poolManager
   VariableDeclaration.router
   VariableDeclaration.usdc
   VariableDeclaration.usde
   VariableDeclaration.dola
   VariableDeclaration.other
   VariableDeclaration.other2
   VariableDeclaration.other3
   VariableDeclaration.pool0
   VariableDeclaration.pool1
   FunctionDefinition.setUp
   FunctionDefinition._singleHop
   FunctionDefinition._multiHop
   FunctionDefinition._params
   FunctionDefinition._pools
   FunctionDefinition._params
   FunctionDefinition._pools
   FunctionDefinition._ethKey
   FunctionDefinition.test_constructor_storesImmutablesAndOwner
   FunctionDefinition.test_constructor_rejectsZeroPoolManager
   FunctionDefinition.test_constructor_rejectsZeroSya
   FunctionDefinition.test_constructor_rejectsZeroRouter
   FunctionDefinition.test_constructor_rejectsZeroOwner
   FunctionDefinition.test_setRoute_revertsForNonOwner
   FunctionDefinition.test_clearRoute_revertsForNonOwner
   FunctionDefinition.test_setEthPool_revertsForNonOwner
   FunctionDefinition.test_setRoute_rejectsZeroToken
   FunctionDefinition.test_setRoute_rejectsWrongFirstToken
   FunctionDefinition.test_setRoute_rejectsRouteEndingAtNonRewardToken
   FunctionDefinition.test_setRoute_rejectsMultiHopEndingAtWrongToken
   FunctionDefinition._fiveHop
   FunctionDefinition.test_setRoute_rejectsGappedRoute_trailingRewardToken
   FunctionDefinition.test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry
   FunctionDefinition.test_setRoute_rejectsStrayEntryAfterRewardToken
   FunctionDefinition.test_setRoute_rejectsGapInMultiHopRoute
   FunctionDefinition.test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate
   FunctionDefinition.test_setRoute_rejectsTrailingPoolSlotAfterRewardToken
   FunctionDefinition.test_setRoute_storesFullFiveHopRoute
   FunctionDefinition.test_setRoute_rejectsFiveHopEndingAtNonRewardToken
   FunctionDefinition.test_setRoute_rejectsNoHopRouteForNonRewardToken
   FunctionDefinition.test_setRoute_rejectsNoHopRouteWithTrailingRewardToken
   FunctionDefinition.test_setRoute_acceptsNoHopRouteForRewardToken
   FunctionDefinition.test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry
   FunctionDefinition.test_setRoute_validatesAgainstCurrentRewardToken
   FunctionDefinition.test_setRoute_storesSingleHop
   FunctionDefinition.test_setRoute_storesMultiHop
   FunctionDefinition.test_setRoute_emitsRouteSet
   FunctionDefinition.test_setRoute_rejectsZeroIntermediateToken_twoHop
   FunctionDefinition.test_setRoute_rejectsZeroIntermediateToken_index6InFourHop
   FunctionDefinition.test_setRoute_zeroIntermediateReportedBeforeWrongEnd
   FunctionDefinition.test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop
   FunctionDefinition.test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop
   FunctionDefinition.test_setRoute_rejectsAllZeroExecutedRow_fiveHop
   FunctionDefinition.test_setRoute_rejectsRowAtHopK_singleHop
   FunctionDefinition.test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow
   FunctionDefinition.test_setRoute_rejectsPoolAtHopK_singleHop
   FunctionDefinition.test_setRoute_rejectsPoolInLastSlot_twoHop
   FunctionDefinition.test_setRoute_unexecutedHopChecksParamsBeforePools
   FunctionDefinition.test_setRoute_unexecutedHopsAreCheckedInHopOrder
   FunctionDefinition.test_setRoute_wrongEndReportedBeforeSwapParams
   FunctionDefinition.test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow
   FunctionDefinition.test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool
   FunctionDefinition.test_setRoute_storesFullFiveHopRouteWithFiveValidRows
   FunctionDefinition.test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools
   FunctionDefinition.test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools
   FunctionDefinition.test_getRoute_unsetTokenIsNotConfigured
   FunctionDefinition.test_clearRoute_resetsConfiguredAndEmits
   FunctionDefinition.test_setEthPool_rejectsNonNativeCurrency0
   FunctionDefinition.test_setEthPool_rejectsCurrency1NotRewardToken
   FunctionDefinition.test_setEthPool_storesKeyAndEmits
   FunctionDefinition.test_noHarvestFunction
   
   Suggested order:
   VariableDeclaration.harvester
   VariableDeclaration.sya
   VariableDeclaration.owner
   VariableDeclaration.stranger
   VariableDeclaration.poolManager
   VariableDeclaration.router
   VariableDeclaration.usdc
   VariableDeclaration.usde
   VariableDeclaration.dola
   VariableDeclaration.other
   VariableDeclaration.other2
   VariableDeclaration.other3
   VariableDeclaration.pool0
   VariableDeclaration.pool1
   EventDefinition.RouteSet
   EventDefinition.RouteCleared
   EventDefinition.EthPoolSet
   FunctionDefinition.setUp
   FunctionDefinition._singleHop
   FunctionDefinition._multiHop
   FunctionDefinition._params
   FunctionDefinition._pools
   FunctionDefinition._params
   FunctionDefinition._pools
   FunctionDefinition._ethKey
   FunctionDefinition.test_constructor_storesImmutablesAndOwner
   FunctionDefinition.test_constructor_rejectsZeroPoolManager
   FunctionDefinition.test_constructor_rejectsZeroSya
   FunctionDefinition.test_constructor_rejectsZeroRouter
   FunctionDefinition.test_constructor_rejectsZeroOwner
   FunctionDefinition.test_setRoute_revertsForNonOwner
   FunctionDefinition.test_clearRoute_revertsForNonOwner
   FunctionDefinition.test_setEthPool_revertsForNonOwner
   FunctionDefinition.test_setRoute_rejectsZeroToken
   FunctionDefinition.test_setRoute_rejectsWrongFirstToken
   FunctionDefinition.test_setRoute_rejectsRouteEndingAtNonRewardToken
   FunctionDefinition.test_setRoute_rejectsMultiHopEndingAtWrongToken
   FunctionDefinition._fiveHop
   FunctionDefinition.test_setRoute_rejectsGappedRoute_trailingRewardToken
   FunctionDefinition.test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry
   FunctionDefinition.test_setRoute_rejectsStrayEntryAfterRewardToken
   FunctionDefinition.test_setRoute_rejectsGapInMultiHopRoute
   FunctionDefinition.test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate
   FunctionDefinition.test_setRoute_rejectsTrailingPoolSlotAfterRewardToken
   FunctionDefinition.test_setRoute_storesFullFiveHopRoute
   FunctionDefinition.test_setRoute_rejectsFiveHopEndingAtNonRewardToken
   FunctionDefinition.test_setRoute_rejectsNoHopRouteForNonRewardToken
   FunctionDefinition.test_setRoute_rejectsNoHopRouteWithTrailingRewardToken
   FunctionDefinition.test_setRoute_acceptsNoHopRouteForRewardToken
   FunctionDefinition.test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry
   FunctionDefinition.test_setRoute_validatesAgainstCurrentRewardToken
   FunctionDefinition.test_setRoute_storesSingleHop
   FunctionDefinition.test_setRoute_storesMultiHop
   FunctionDefinition.test_setRoute_emitsRouteSet
   FunctionDefinition.test_setRoute_rejectsZeroIntermediateToken_twoHop
   FunctionDefinition.test_setRoute_rejectsZeroIntermediateToken_index6InFourHop
   FunctionDefinition.test_setRoute_zeroIntermediateReportedBeforeWrongEnd
   FunctionDefinition.test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop
   FunctionDefinition.test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop
   FunctionDefinition.test_setRoute_rejectsAllZeroExecutedRow_fiveHop
   FunctionDefinition.test_setRoute_rejectsRowAtHopK_singleHop
   FunctionDefinition.test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow
   FunctionDefinition.test_setRoute_rejectsPoolAtHopK_singleHop
   FunctionDefinition.test_setRoute_rejectsPoolInLastSlot_twoHop
   FunctionDefinition.test_setRoute_unexecutedHopChecksParamsBeforePools
   FunctionDefinition.test_setRoute_unexecutedHopsAreCheckedInHopOrder
   FunctionDefinition.test_setRoute_wrongEndReportedBeforeSwapParams
   FunctionDefinition.test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow
   FunctionDefinition.test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool
   FunctionDefinition.test_setRoute_storesFullFiveHopRouteWithFiveValidRows
   FunctionDefinition.test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools
   FunctionDefinition.test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools
   FunctionDefinition.test_getRoute_unsetTokenIsNotConfigured
   FunctionDefinition.test_clearRoute_resetsConfiguredAndEmits
   FunctionDefinition.test_setEthPool_rejectsNonNativeCurrency0
   FunctionDefinition.test_setEthPool_rejectsCurrency1NotRewardToken
   FunctionDefinition.test_setEthPool_storesKeyAndEmits
   FunctionDefinition.test_noHarvestFunction

```

```solidity
File: test/fork/MainnetRoutes.sol

1: 
   Current order:
   StructDefinition.Route
   VariableDeclaration.POOL_USDE_CRVUSD
   VariableDeclaration.POOL_CRVUSD_USDC
   VariableDeclaration.POOL_DOLA_FRAXBP
   FunctionDefinition.usdeRoute
   FunctionDefinition.dolaRoute
   FunctionDefinition.ethPoolKey
   FunctionDefinition.configure
   
   Suggested order:
   VariableDeclaration.POOL_USDE_CRVUSD
   VariableDeclaration.POOL_CRVUSD_USDC
   VariableDeclaration.POOL_DOLA_FRAXBP
   StructDefinition.Route
   FunctionDefinition.usdeRoute
   FunctionDefinition.dolaRoute
   FunctionDefinition.ethPoolKey
   FunctionDefinition.configure

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

1: 
   Current order:
   FunctionDefinition.coins
   FunctionDefinition.get_dy
   FunctionDefinition.poolManager
   FunctionDefinition.totalSupply
   UsingForDirective.PoolKey
   UsingForDirective.IPoolManager
   VariableDeclaration.ACCRUAL_WARP
   VariableDeclaration.GAS_PRICE
   VariableDeclaration.sya
   VariableDeclaration.pm
   VariableDeclaration.nft
   VariableDeclaration.harvester
   VariableDeclaration.owner
   VariableDeclaration.keeper
   VariableDeclaration.unlockCallbackHit
   VariableDeclaration.FRAXBP_POOL
   VariableDeclaration.FRAXBP_LP
   FunctionDefinition.setUp
   FunctionDefinition.unlockCallback
   FunctionDefinition._none
   FunctionDefinition._one
   FunctionDefinition._harvest
   FunctionDefinition._assertHarvesterEmpty
   FunctionDefinition.test_fork_addresses_verifiedOnFork
   FunctionDefinition.test_fork_liveStrategies_everyNonRewardTokenHasRoute
   FunctionDefinition._quote
   FunctionDefinition.test_fork_routes_coinIndicesMatchPools
   FunctionDefinition.test_fork_routes_quoteCloseToPar
   FunctionDefinition.test_fork_ethPool_isDeepestNativeEthUsdcPool
   FunctionDefinition.test_fork_accrual_warpAloneProducesYield
   FunctionDefinition.test_fork_harvest_endToEnd_paysEthBurnsNftLeavesNoBalances
   FunctionDefinition.test_fork_harvest_usdeStrategyNonExempt_noNestedUnlock
   FunctionDefinition.test_fork_harvest_eachStrategyExemptedInTurn
   FunctionDefinition.test_fork_harvest_highGasPrice_revertsUnprofitable
   FunctionDefinition.test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut
   FunctionDefinition._calldataGas
   FunctionDefinition.test_fork_gasOverhead_coversMeasuredGap
   FunctionDefinition._gapPath
   FunctionDefinition.test_fork_M01_gapRoute_rejectedBySetRoute
   FunctionDefinition.test_fork_M01_contiguousRoute_harvestsAndLeavesHarvesterEmpty
   FunctionDefinition.test_fork_M01_realRouterDeliversIntermediate_mockAgrees
   FunctionDefinition._zeroIntermediatePath
   FunctionDefinition._realRouterExchange
   FunctionDefinition._mockExchange
   FunctionDefinition.test_fork_zeroIntermediate_realRouterReverts_mockAgrees
   FunctionDefinition.test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees
   FunctionDefinition.test_fork_zeroIntermediate_rejectedBySetRoute
   FunctionDefinition.test_fork_shippedRoutes_passNewRules_andHarvestLeavesHarvesterEmpty
   
   Suggested order:
   UsingForDirective.PoolKey
   UsingForDirective.IPoolManager
   VariableDeclaration.ACCRUAL_WARP
   VariableDeclaration.GAS_PRICE
   VariableDeclaration.sya
   VariableDeclaration.pm
   VariableDeclaration.nft
   VariableDeclaration.harvester
   VariableDeclaration.owner
   VariableDeclaration.keeper
   VariableDeclaration.unlockCallbackHit
   VariableDeclaration.FRAXBP_POOL
   VariableDeclaration.FRAXBP_LP
   FunctionDefinition.coins
   FunctionDefinition.get_dy
   FunctionDefinition.poolManager
   FunctionDefinition.totalSupply
   FunctionDefinition.setUp
   FunctionDefinition.unlockCallback
   FunctionDefinition._none
   FunctionDefinition._one
   FunctionDefinition._harvest
   FunctionDefinition._assertHarvesterEmpty
   FunctionDefinition.test_fork_addresses_verifiedOnFork
   FunctionDefinition.test_fork_liveStrategies_everyNonRewardTokenHasRoute
   FunctionDefinition._quote
   FunctionDefinition.test_fork_routes_coinIndicesMatchPools
   FunctionDefinition.test_fork_routes_quoteCloseToPar
   FunctionDefinition.test_fork_ethPool_isDeepestNativeEthUsdcPool
   FunctionDefinition.test_fork_accrual_warpAloneProducesYield
   FunctionDefinition.test_fork_harvest_endToEnd_paysEthBurnsNftLeavesNoBalances
   FunctionDefinition.test_fork_harvest_usdeStrategyNonExempt_noNestedUnlock
   FunctionDefinition.test_fork_harvest_eachStrategyExemptedInTurn
   FunctionDefinition.test_fork_harvest_highGasPrice_revertsUnprofitable
   FunctionDefinition.test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut
   FunctionDefinition._calldataGas
   FunctionDefinition.test_fork_gasOverhead_coversMeasuredGap
   FunctionDefinition._gapPath
   FunctionDefinition.test_fork_M01_gapRoute_rejectedBySetRoute
   FunctionDefinition.test_fork_M01_contiguousRoute_harvestsAndLeavesHarvesterEmpty
   FunctionDefinition.test_fork_M01_realRouterDeliversIntermediate_mockAgrees
   FunctionDefinition._zeroIntermediatePath
   FunctionDefinition._realRouterExchange
   FunctionDefinition._mockExchange
   FunctionDefinition.test_fork_zeroIntermediate_realRouterReverts_mockAgrees
   FunctionDefinition.test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees
   FunctionDefinition.test_fork_zeroIntermediate_rejectedBySetRoute
   FunctionDefinition.test_fork_shippedRoutes_passNewRules_andHarvestLeavesHarvesterEmpty

```

```solidity
File: test/mocks/MockCurveRouter.sol

1: 
   Current order:
   UsingForDirective.IERC20
   ErrorDefinition.Slippage
   ErrorDefinition.NoHop
   ErrorDefinition.ZeroOutputToken
   ErrorDefinition.ZeroIntermediateToken
   ErrorDefinition.BadSwapType
   VariableDeclaration.rate
   VariableDeclaration.calls
   FunctionDefinition.setRate
   FunctionDefinition.resolveOutput
   FunctionDefinition._resolve
   FunctionDefinition.exchange
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.rate
   VariableDeclaration.calls
   ErrorDefinition.Slippage
   ErrorDefinition.NoHop
   ErrorDefinition.ZeroOutputToken
   ErrorDefinition.ZeroIntermediateToken
   ErrorDefinition.BadSwapType
   FunctionDefinition.setRate
   FunctionDefinition.resolveOutput
   FunctionDefinition._resolve
   FunctionDefinition.exchange

```

```solidity
File: test/mocks/MockERC1155.sol

1: 
   Current order:
   ErrorDefinition.NotAuthorizedBurner
   VariableDeclaration.authorizedBurners
   FunctionDefinition.constructor
   FunctionDefinition.mint
   FunctionDefinition.setAuthorizedBurner
   FunctionDefinition.burn
   FunctionDefinition._update
   
   Suggested order:
   VariableDeclaration.authorizedBurners
   ErrorDefinition.NotAuthorizedBurner
   FunctionDefinition.constructor
   FunctionDefinition.mint
   FunctionDefinition.setAuthorizedBurner
   FunctionDefinition.burn
   FunctionDefinition._update

```

```solidity
File: test/mocks/MockSYA.sol

1: 
   Current order:
   FunctionDefinition.burn
   FunctionDefinition.surplus
   FunctionDefinition.skimSurplus
   UsingForDirective.IERC20
   ErrorDefinition.ExemptStrategyNotRegistered
   ErrorDefinition.ZeroAmount
   ErrorDefinition.InsufficientYield
   ErrorDefinition.NoValidNFT
   EnumDefinition.NftMode
   VariableDeclaration.nftMode
   VariableDeclaration.nftBalanceSeenInClaim
   VariableDeclaration.rewardToken
   VariableDeclaration.nftMinter
   VariableDeclaration.discountRate
   VariableDeclaration.overEstimateBps
   VariableDeclaration.yieldStrategies
   VariableDeclaration.strategyTokens
   VariableDeclaration.isRegisteredStrategy
   VariableDeclaration.tokenPaused
   VariableDeclaration.totalCollected
   FunctionDefinition.constructor
   FunctionDefinition.setRewardToken
   FunctionDefinition.setNFTMinter
   FunctionDefinition.setNftMode
   FunctionDefinition.setDiscountRate
   FunctionDefinition.setOverEstimateBps
   FunctionDefinition.addYieldStrategy
   FunctionDefinition.pauseToken
   FunctionDefinition.getYieldStrategies
   FunctionDefinition.claim
   FunctionDefinition.calculateClaimAmount
   FunctionDefinition._validateExempt
   FunctionDefinition._skip
   FunctionDefinition._normalize
   FunctionDefinition._denormalize
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.nftMode
   VariableDeclaration.nftBalanceSeenInClaim
   VariableDeclaration.rewardToken
   VariableDeclaration.nftMinter
   VariableDeclaration.discountRate
   VariableDeclaration.overEstimateBps
   VariableDeclaration.yieldStrategies
   VariableDeclaration.strategyTokens
   VariableDeclaration.isRegisteredStrategy
   VariableDeclaration.tokenPaused
   VariableDeclaration.totalCollected
   EnumDefinition.NftMode
   ErrorDefinition.ExemptStrategyNotRegistered
   ErrorDefinition.ZeroAmount
   ErrorDefinition.InsufficientYield
   ErrorDefinition.NoValidNFT
   FunctionDefinition.burn
   FunctionDefinition.surplus
   FunctionDefinition.skimSurplus
   FunctionDefinition.constructor
   FunctionDefinition.setRewardToken
   FunctionDefinition.setNFTMinter
   FunctionDefinition.setNftMode
   FunctionDefinition.setDiscountRate
   FunctionDefinition.setOverEstimateBps
   FunctionDefinition.addYieldStrategy
   FunctionDefinition.pauseToken
   FunctionDefinition.getYieldStrategies
   FunctionDefinition.claim
   FunctionDefinition.calculateClaimAmount
   FunctionDefinition._validateExempt
   FunctionDefinition._skip
   FunctionDefinition._normalize
   FunctionDefinition._denormalize

```

```solidity
File: test/mocks/MockYieldStrategy.sol

1: 
   Current order:
   UsingForDirective.IERC20
   ErrorDefinition.StrategyPaused
   ErrorDefinition.WrongToken
   VariableDeclaration.token
   VariableDeclaration.surplus
   VariableDeclaration.paused
   VariableDeclaration.nestPoolManager
   FunctionDefinition.constructor
   FunctionDefinition.setSurplus
   FunctionDefinition.setPaused
   FunctionDefinition.setNestPoolManager
   FunctionDefinition.skimSurplus
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.token
   VariableDeclaration.surplus
   VariableDeclaration.paused
   VariableDeclaration.nestPoolManager
   ErrorDefinition.StrategyPaused
   ErrorDefinition.WrongToken
   FunctionDefinition.constructor
   FunctionDefinition.setSurplus
   FunctionDefinition.setPaused
   FunctionDefinition.setNestPoolManager
   FunctionDefinition.skimSurplus

```

### <a name="NC-22"></a>[NC-22] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (12)*:
```solidity
File: src/SYAHarvester.sol

326:         uint256 owed = sya.calculateClaimAmount(exempt) * (10000 + BORROW_BUFFER_BPS) / 10000;

```

```solidity
File: test/SYAHarvester.harvest.t.sol

81:         assertEq(sya.totalCollected(), 1080e6, "payment");

```

```solidity
File: test/fork/MainnetRoutes.sol

96:             fee: 3000,

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

236:         uint256 d1000 = _quote(MainnetRoutes.dolaRoute(), 1000e18);

253:         uint24[4] memory fees = [uint24(100), 500, 3000, 10_000];

352:             address(harvester).call(abi.encodeCall(harvester.harvest, (_none(), A.NFT_INDEX, 1000 ether)));

```

```solidity
File: test/mocks/MockSYA.sol

47:     uint256 public discountRate = 1000; // 10%

118:         uint256 payment = _denormalize(totalNormalizedYield * (10000 - discountRate) / 10000, rewardToken);

137:         uint256 payment = _denormalize(totalNormalizedYield * (10000 - discountRate) / 10000, rewardToken);

138:         return payment * (10000 + overEstimateBps) / 10000;

```

```solidity
File: test/utils/HarvesterFixture.sol

41:     uint256 internal constant USDE_YIELD = 1000e18; // ~1000 USDC of value at rate 1:1

59:             3000,

```

### <a name="NC-23"></a>[NC-23] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (54)*:
```solidity
File: src/SYAHarvester.sol

63:     mapping(address => CurveRoute) private routes;

66:     PoolKey private ethPool;

```

```solidity
File: test/SYAHarvester.nft.t.sol

17:     MockERC1155 internal nft;

```

```solidity
File: test/SYAHarvester.registry.t.sol

21:     SYAHarvester internal harvester;

22:     MockSYA internal sya;

24:     address internal owner = makeAddr("owner");

25:     address internal stranger = makeAddr("stranger");

26:     address internal poolManager = makeAddr("poolManager");

27:     address internal router = makeAddr("router");

29:     address internal usdc = makeAddr("usdc");

30:     address internal usde = makeAddr("usde");

31:     address internal dola = makeAddr("dola");

32:     address internal other = makeAddr("other");

33:     address internal other2 = makeAddr("other2");

34:     address internal other3 = makeAddr("other3");

35:     address internal pool0 = makeAddr("pool0");

36:     address internal pool1 = makeAddr("pool1");

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

14:     MockERC20 internal crvusd;

```

```solidity
File: test/fork/MainnetRoutes.sol

60:     function usdeRoute() internal pure returns (Route memory r) {

74:     function dolaRoute() internal pure returns (Route memory r) {

92:     function ethPoolKey() internal pure returns (PoolKey memory) {

103:     function configure(SYAHarvester harvester) internal {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

67:     IStableYieldAccumulator internal sya = IStableYieldAccumulator(A.SYA);

68:     IPoolManager internal pm = IPoolManager(A.POOL_MANAGER);

69:     IERC1155 internal nft = IERC1155(A.NFT_MINTER);

71:     SYAHarvester internal harvester;

72:     address internal owner = makeAddr("harvesterOwner");

73:     address internal keeper = makeAddr("keeper");

75:     bool internal unlockCallbackHit;

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

13:     MockCurveRouter internal router;

15:     MockERC20 internal tokenIn;

16:     MockERC20 internal mid;

17:     MockERC20 internal mid2;

18:     MockERC20 internal mid3;

19:     MockERC20 internal mid4;

20:     MockERC20 internal tokenOut;

22:     address internal pool0 = makeAddr("pool0");

23:     address internal pool1 = makeAddr("pool1");

24:     address internal receiver = makeAddr("receiver");

```

```solidity
File: test/mocks/MockSYA.sol

51:     address[] internal yieldStrategies;

```

```solidity
File: test/utils/HarvesterFixture.sol

22:     SYAHarvester internal harvester;

23:     MockSYA internal sya;

24:     MockCurveRouter internal router;

26:     MockERC20 internal usdc;

27:     MockERC20 internal usde;

28:     MockERC20 internal dola;

30:     MockYieldStrategy internal usdeStrategy;

31:     MockYieldStrategy internal dolaStrategy;

32:     MockYieldStrategy internal usdcStrategy;

34:     PoolKey internal ethKey;

36:     address internal owner = makeAddr("owner");

37:     address internal keeper = makeAddr("keeper");

38:     address internal stranger = makeAddr("stranger");

39:     address internal curvePool = makeAddr("curvePool");

```

### <a name="NC-24"></a>[NC-24] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

73:     event EthPoolSet(

```

```solidity
File: test/SYAHarvester.registry.t.sol

19:     event EthPoolSet(address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address hooks);

```

### <a name="NC-25"></a>[NC-25] Constants should be defined rather than using magic numbers

*Instances (2)*:
```solidity
File: test/mocks/MockSYA.sol

158:         return d <= 18 ? amount * 10 ** (18 - d) : amount / 10 ** (d - 18);

163:         return d <= 18 ? amount / 10 ** (18 - d) : amount * 10 ** (d - 18);

```

### <a name="NC-26"></a>[NC-26] `public` functions not called by the contract should be declared `external` instead

*Instances (116)*:
```solidity
File: test/SYAHarvester.gas.t.sol

56:     function test_gas_costAboveEthOut_revertsUnprofitable() public {

69:     function test_gas_zeroGasPrice_passesTrivially() public {

81:     function test_gas_chargedUnits_coverMeasuredWorkPlusOverhead() public {

93:     function test_gas_borderlinePrice_flipsPassFail() public {

110:     function test_gas_minEthOutSatisfied_butUnprofitable_stillReverts() public {

```

```solidity
File: test/SYAHarvester.harvest.t.sol

20:     function test_harvest_profitablePath_paysEthToCaller() public {

35:     function test_harvest_profitablePath_withLiveLikeOverEstimate() public {

47:     function test_harvest_minEthOutAboveOutput_reverts() public {

62:     function test_harvest_unroutedToken_revertsRouteNotConfigured() public {

70:     function test_harvest_rewardTokenStrategy_skippedNoRouterCall() public {

85:     function test_harvest_exemptStrategy_notSkimmedNotSold() public {

102:     function test_harvest_pausedToken_skippedNoCoverageRevert() public {

119:     function test_unlockCallback_directCall_revertsNotPoolManager() public {

125:     function test_receive_fromNonPoolManager_reverts() public {

137:     function test_harvest_unprofitableClaim_reverts() public {

147:     function test_harvest_nestedUnlockInSkimSurplus_reverts() public {

155:     function test_harvest_ethPoolNotSet_reverts() public {

```

```solidity
File: test/SYAHarvester.nft.t.sol

41:     function test_nft_pulledThenBurned_noRefund() public {

64:     function test_nft_ignoredBySya_heldDuringUnlock_thenRefunded() public {

76:     function test_nft_refundReturnsWholeBalance_includingStrayUnits() public {

97:     function test_nft_indexZero_noErc1155Calls() public {

108:     function test_nft_noMinterConfigured_skipsBothTransfers() public {

124:     function test_nft_callerWithoutApproval_revertsOnPull() public {

135:     function test_nft_burnNeedsNoApprovalFromHarvester() public {

150:     function test_supportsInterface_erc1155Receiver() public view {

```

```solidity
File: test/SYAHarvester.registry.t.sol

38:     function setUp() public {

100:     function test_constructor_storesImmutablesAndOwner() public view {

107:     function test_constructor_rejectsZeroPoolManager() public {

112:     function test_constructor_rejectsZeroSya() public {

117:     function test_constructor_rejectsZeroRouter() public {

124:     function test_constructor_rejectsZeroOwner() public {

135:     function test_setRoute_revertsForNonOwner() public {

141:     function test_clearRoute_revertsForNonOwner() public {

147:     function test_setEthPool_revertsForNonOwner() public {

157:     function test_setRoute_rejectsZeroToken() public {

164:     function test_setRoute_rejectsWrongFirstToken() public {

170:     function test_setRoute_rejectsRouteEndingAtNonRewardToken() public {

180:     function test_setRoute_rejectsMultiHopEndingAtWrongToken() public {

208:     function test_setRoute_rejectsGappedRoute_trailingRewardToken() public {

221:     function test_setRoute_rejectsGappedRoute_whenDeliveredIsRewardButTrailingEntry() public {

234:     function test_setRoute_rejectsStrayEntryAfterRewardToken() public {

242:     function test_setRoute_rejectsGapInMultiHopRoute() public {

255:     function test_setRoute_rejectsGapInMultiHopRoute_deliveringIntermediate() public {

270:     function test_setRoute_rejectsTrailingPoolSlotAfterRewardToken() public {

278:     function test_setRoute_storesFullFiveHopRoute() public {

290:     function test_setRoute_rejectsFiveHopEndingAtNonRewardToken() public {

297:     function test_setRoute_rejectsNoHopRouteForNonRewardToken() public {

306:     function test_setRoute_rejectsNoHopRouteWithTrailingRewardToken() public {

318:     function test_setRoute_acceptsNoHopRouteForRewardToken() public {

330:     function test_setRoute_rejectsNoHopRewardRouteWithTrailingEntry() public {

339:     function test_setRoute_validatesAgainstCurrentRewardToken() public {

346:     function test_setRoute_storesSingleHop() public {

367:     function test_setRoute_storesMultiHop() public {

382:     function test_setRoute_emitsRouteSet() public {

393:     function test_setRoute_rejectsZeroIntermediateToken_twoHop() public {

405:     function test_setRoute_rejectsZeroIntermediateToken_index6InFourHop() public {

421:     function test_setRoute_zeroIntermediateReportedBeforeWrongEnd() public {

430:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_singleHop() public {

438:     function test_setRoute_rejectsExecutedRowWithZeroSwapType_secondHop() public {

446:     function test_setRoute_rejectsAllZeroExecutedRow_fiveHop() public {

454:     function test_setRoute_rejectsRowAtHopK_singleHop() public {

461:     function test_setRoute_rejectsSingleNonZeroFieldInUnexecutedRow() public {

470:     function test_setRoute_rejectsPoolAtHopK_singleHop() public {

478:     function test_setRoute_rejectsPoolInLastSlot_twoHop() public {

486:     function test_setRoute_unexecutedHopChecksParamsBeforePools() public {

495:     function test_setRoute_unexecutedHopsAreCheckedInHopOrder() public {

506:     function test_setRoute_wrongEndReportedBeforeSwapParams() public {

514:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroRow() public {

522:     function test_setRoute_rejectsNoHopRewardRouteWithNonZeroPool() public {

530:     function test_setRoute_storesFullFiveHopRouteWithFiveValidRows() public {

546:     function test_setRoute_storesSingleHopWithOnlyRowZeroAndZeroPools() public {

566:     function test_setRoute_acceptsNoHopRewardRouteWithAllZeroParamsAndPools() public {

576:     function test_getRoute_unsetTokenIsNotConfigured() public view {

586:     function test_clearRoute_resetsConfiguredAndEmits() public {

606:     function test_setEthPool_rejectsNonNativeCurrency0() public {

614:     function test_setEthPool_rejectsCurrency1NotRewardToken() public {

622:     function test_setEthPool_storesKeyAndEmits() public {

638:     function test_noHarvestFunction() public {

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

30:     function test_routeGap_gappedRouteCannotBeStored() public {

41:     function test_routeGap_mockDeliversIntermediateForGappedPath() public {

51:     function test_routeGap_contiguousFixtureRoute_harvestLeavesNoBalances() public {

```

```solidity
File: test/Toolchain.t.sol

9:     function setUp() public {

13:     function test_deployFreshManagerAndRouters_deploysManager() public view {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

81:     function setUp() public {

149:     function test_fork_addresses_verifiedOnFork() public {

183:     function test_fork_liveStrategies_everyNonRewardTokenHasRoute() public view {

208:     function test_fork_routes_coinIndicesMatchPools() public view {

232:     function test_fork_routes_quoteCloseToPar() public view {

245:     function test_fork_ethPool_isDeepestNativeEthUsdcPool() public view {

272:     function test_fork_accrual_warpAloneProducesYield() public view {

284:     function test_fork_harvest_endToEnd_paysEthBurnsNftLeavesNoBalances() public {

308:     function test_fork_harvest_usdeStrategyNonExempt_noNestedUnlock() public {

319:     function test_fork_harvest_eachStrategyExemptedInTurn() public {

340:     function test_fork_harvest_highGasPrice_revertsUnprofitable() public {

349:     function test_fork_harvest_excessiveMinEthOut_revertsInsufficientEthOut() public {

372:     function test_fork_gasOverhead_coversMeasuredGap() public {

421:     function test_fork_M01_gapRoute_rejectedBySetRoute() public {

433:     function test_fork_M01_contiguousRoute_harvestsAndLeavesHarvesterEmpty() public {

442:     function test_fork_M01_realRouterDeliversIntermediate_mockAgrees() public {

511:     function test_fork_zeroIntermediate_realRouterReverts_mockAgrees() public {

530:     function test_fork_zeroSwapTypeOnExecutedHop_realRouterReverts_mockAgrees() public {

547:     function test_fork_zeroIntermediate_rejectedBySetRoute() public {

559:     function test_fork_shippedRoutes_passNewRules_andHarvestLeavesHarvesterEmpty() public {

```

```solidity
File: test/mocks/MockCurveRouter.sol

41:     function resolveOutput(address[11] calldata _route) public pure returns (address tokenOut) {

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

28:     function setUp() public {

61:     function test_exchange_contiguousRoute_deliversFinalToken() public {

78:     function test_exchange_gappedRoute_deliversIntermediateToken() public {

92:     function test_exchange_gapInMultiHopRoute_deliversPath2k() public {

108:     function test_exchange_fiveHopRoute_deliversPath10() public {

128:     function test_exchange_noHop_reverts() public {

138:     function test_exchange_zeroOutputToken_reverts() public {

148:     function test_exchange_slippage_stillEnforced() public {

159:     function test_exchange_zeroIntermediateToken_reverts() public {

171:     function test_resolveOutput_zeroIntermediateToken_reverts() public {

184:     function test_exchange_executedRowWithZeroSwapType_reverts() public {

199:     function test_exchange_ignoresRowsBeyondExecutedPrefix() public {

```

### <a name="NC-27"></a>[NC-27] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (28)*:
```solidity
File: src/SYAHarvester.sol

176:         for (uint256 h = 0; h < 5; h++) {

180:                 for (uint256 f = 0; f < 5; f++) {

353:         for (uint256 i = 0; i < strategies.length; i++) {

397:         for (uint256 i = 0; i < list.length; i++) {

```

```solidity
File: test/SYAHarvester.registry.t.sol

75:         for (uint256 h = 0; h < k; h++) {

285:         for (uint256 i = 0; i < 11; i++) {

356:         for (uint256 i = 0; i < 11; i++) {

359:         for (uint256 i = 0; i < 5; i++) {

361:             for (uint256 j = 0; j < 5; j++) {

538:         for (uint256 h = 0; h < 5; h++) {

540:             for (uint256 f = 0; f < 5; f++) {

555:         for (uint256 i = 0; i < 11; i++) {

558:         for (uint256 h = 0; h < 5; h++) {

560:             for (uint256 f = 0; f < 5; f++) {

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

140:         for (uint256 i = 0; i < strategies.length; i++) {

165:         for (uint256 i = 0; i < withCode.length; i++) {

188:         for (uint256 i = 0; i < strategies.length; i++) {

255:         for (uint256 i = 0; i < fees.length; i++) {

274:         for (uint256 i = 0; i < strategies.length; i++) {

321:         for (uint256 i = 0; i < strategies.length; i++) {

360:         for (uint256 i = 0; i < data.length; i++) {

```

```solidity
File: test/mocks/MockCurveRouter.sol

48:         for (uint256 i = 0; i < 5; i++) {

67:         for (uint256 h = 0; h < hops; h++) {

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

51:         for (uint256 h = 0; h < 5 && path[2 * h + 1] != address(0); h++) {

```

```solidity
File: test/mocks/MockSYA.sol

109:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

129:         for (uint256 i = 0; i < yieldStrategies.length; i++) {

142:         for (uint256 i = 0; i < exemptStrategies.length; i++) {

150:         for (uint256 j = 0; j < exemptStrategies.length; j++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 7 |
| [L-2](#L-2) | Use a 2-step ownership transfer pattern | 1 |
| [L-3](#L-3) | Some tokens may revert when zero value transfers are made | 5 |
| [L-4](#L-4) | Missing checks for `address(0)` when assigning values to address state variables | 4 |
| [L-5](#L-5) | `decimals()` is not a part of the ERC-20 standard | 2 |
| [L-6](#L-6) | Deprecated approve() function | 7 |
| [L-7](#L-7) | Division by zero not prevented | 3 |
| [L-8](#L-8) | Empty Function Body - Consider commenting why | 1 |
| [L-9](#L-9) | External call recipient may consume all transaction gas | 19 |
| [L-10](#L-10) | Prevent accidentally burning tokens | 2 |
| [L-11](#L-11) | Loss of precision | 2 |
| [L-12](#L-12) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 13 |
| [L-13](#L-13) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-14](#L-14) | Unsafe ERC20 operation(s) | 7 |
### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (7)*:
```solidity
File: test/SYAHarvester.routeGap.t.sol

45:         usde.approve(address(router), 100e18);

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

449:         IERC20(A.USDE).approve(A.CURVE_ROUTER_NG, amount);

464:         IERC20(A.USDE).approve(address(mock), amount);

489:         IERC20(A.USDE).approve(A.CURVE_ROUTER_NG, amount);

505:         IERC20(A.USDE).approve(address(mock), amount);

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

46:         tokenIn.approve(address(router), type(uint256).max);

```

```solidity
File: test/utils/HarvesterFixture.sol

54:         usdc.approve(address(modifyLiquidityRouter), type(uint256).max);

```

### <a name="L-2"></a>[L-2] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/SYAHarvester.sol

27: contract SYAHarvester is Ownable, ERC1155Holder, IUnlockCallback {

```

### <a name="L-3"></a>[L-3] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (5)*:
```solidity
File: src/SYAHarvester.sol

388:         IERC20(reward).safeTransfer(address(poolManager), debt);

```

```solidity
File: test/mocks/MockCurveRouter.sol

71:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), _amount);

74:         IERC20(tokenOut).safeTransfer(_receiver, out);

```

```solidity
File: test/mocks/MockSYA.sol

121:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), payment);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

50:             IERC20(token).safeTransfer(recipient, amount);

```

### <a name="L-4"></a>[L-4] Missing checks for `address(0)` when assigning values to address state variables

*Instances (4)*:
```solidity
File: test/mocks/MockSYA.sol

59:         rewardToken = _rewardToken;

63:         rewardToken = _rewardToken;

67:         nftMinter = _nftMinter;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

24:         token = _token;

```

### <a name="L-5"></a>[L-5] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (2)*:
```solidity
File: test/mocks/MockSYA.sol

157:         uint8 d = IERC20Metadata(token).decimals();

162:         uint8 d = IERC20Metadata(token).decimals();

```

### <a name="L-6"></a>[L-6] Deprecated approve() function
Due to the inheritance of ERC20's approve function, there's a vulnerability to the ERC20 approve and double spend front running attack. Briefly, an authorized spender could spend both allowances by front running an allowance-changing transaction. Consider implementing OpenZeppelin's `.safeApprove()` function to help mitigate this.

*Instances (7)*:
```solidity
File: test/SYAHarvester.routeGap.t.sol

45:         usde.approve(address(router), 100e18);

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

449:         IERC20(A.USDE).approve(A.CURVE_ROUTER_NG, amount);

464:         IERC20(A.USDE).approve(address(mock), amount);

489:         IERC20(A.USDE).approve(A.CURVE_ROUTER_NG, amount);

505:         IERC20(A.USDE).approve(address(mock), amount);

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

46:         tokenIn.approve(address(router), type(uint256).max);

```

```solidity
File: test/utils/HarvesterFixture.sol

54:         usdc.approve(address(modifyLiquidityRouter), type(uint256).max);

```

### <a name="L-7"></a>[L-7] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (3)*:
```solidity
File: test/SYAHarvester.gas.t.sol

53:         units = gasCost / price;

95:         uint256 breakEven = ethOut / units;

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

398:         uint256 inContract = gasCost / price - harvester.GAS_OVERHEAD();

```

### <a name="L-8"></a>[L-8] Empty Function Body - Consider commenting why

*Instances (1)*:
```solidity
File: test/utils/HarvesterFixture.sol

106:     function _pools() internal pure returns (address[5] memory pools) {}

```

### <a name="L-9"></a>[L-9] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (19)*:
```solidity
File: src/SYAHarvester.sol

299:         (bool ok,) = msg.sender.call{value: ethOut}("");

```

```solidity
File: test/SYAHarvester.gas.t.sol

30:         (ok, ret) = address(harvester).call(abi.encodeCall(harvester.harvest, (_none(), 0, 0)));

116:             address(harvester).call(abi.encodeCall(harvester.harvest, (_none(), 0, expectedEthOut)));

```

```solidity
File: test/SYAHarvester.harvest.t.sol

31:         assertEq(router.calls(address(usde)), 1, "router called once");

77:         assertEq(router.calls(address(usdc)), 0, "router not called for reward token");

78:         assertEq(router.calls(address(usde)), 1, "router called for USDe");

98:         assertEq(router.calls(address(dola)), 0, "exempt token not sold");

111:         assertEq(router.calls(address(dola)), 0, "paused token not sold");

128:         (bool ok,) = address(harvester).call{value: 1 ether}("");

```

```solidity
File: test/SYAHarvester.registry.t.sol

639:         (bool ok,) = address(harvester).call(abi.encodeWithSignature("harvest(uint256,uint256,address[])", 0, 0, new address[](0)));

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

61:         assertEq(router.calls(address(usde)), 1);

62:         assertEq(router.calls(address(dola)), 1);

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

344:             address(harvester).call(abi.encodeCall(harvester.harvest, (_none(), A.NFT_INDEX, 0)));

352:             address(harvester).call(abi.encodeCall(harvester.harvest, (_none(), A.NFT_INDEX, 1000 ether)));

380:         (bool ok,) = address(harvester).call(data);

391:         (ok, ret) = address(harvester).call(data);

491:             .call(abi.encodeCall(ICurveRouterNG.exchange, (path, params, amount, 0, pools, address(this))));

506:         (ok, ret) = address(mock).call(abi.encodeCall(mock.exchange, (path, params, amount, 0, pools, address(this))));

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

74:         assertEq(router.calls(address(tokenIn)), 1);

```

### <a name="L-10"></a>[L-10] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (2)*:
```solidity
File: test/mocks/MockERC1155.sol

19:         _mint(to, id, amount, "");

28:         _burn(from, id, amount);

```

### <a name="L-11"></a>[L-11] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (2)*:
```solidity
File: test/SYAHarvester.registry.t.sol

390:         ROUTE TOKEN / SWAP PARAMS / POOLS CONSISTENCY (audit 01, M-01 residual + mitigation 2)

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

398:         uint256 inContract = gasCost / price - harvester.GAS_OVERHEAD();

```

### <a name="L-12"></a>[L-12] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (13)*:
```solidity
File: src/SYAHarvester.sol

2: pragma solidity ^0.8.26;

```

```solidity
File: test/SYAHarvester.harvest.t.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/SYAHarvester.nft.t.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/SYAHarvester.registry.t.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/SYAHarvester.routeGap.t.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/Toolchain.t.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/fork/MainnetAddresses.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/fork/MainnetRoutes.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/mocks/MockCurveRouter.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/mocks/MockERC1155.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

2: pragma solidity 0.8.26;

```

```solidity
File: test/script/DeployHarvesterForTest.s.sol

2: pragma solidity 0.8.26;

```

### <a name="L-13"></a>[L-13] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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

*Instances (2)*:
```solidity
File: src/SYAHarvester.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: test/SYAHarvester.registry.t.sol

5: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-14"></a>[L-14] Unsafe ERC20 operation(s)

*Instances (7)*:
```solidity
File: test/SYAHarvester.routeGap.t.sol

45:         usde.approve(address(router), 100e18);

```

```solidity
File: test/fork/SYAHarvester.fork.t.sol

449:         IERC20(A.USDE).approve(A.CURVE_ROUTER_NG, amount);

464:         IERC20(A.USDE).approve(address(mock), amount);

489:         IERC20(A.USDE).approve(A.CURVE_ROUTER_NG, amount);

505:         IERC20(A.USDE).approve(address(mock), amount);

```

```solidity
File: test/mocks/MockCurveRouter.t.sol

46:         tokenIn.approve(address(router), type(uint256).max);

```

```solidity
File: test/utils/HarvesterFixture.sol

54:         usdc.approve(address(modifyLiquidityRouter), type(uint256).max);

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 2 |
| [M-2](#M-2) | `block.number` means different things on different L2s | 1 |
| [M-3](#M-3) | Centralization Risk for trusted owners | 5 |
| [M-4](#M-4) | Direct `supportsInterface()` calls may cause caller to revert | 2 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (2)*:
```solidity
File: test/mocks/MockCurveRouter.sol

71:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), _amount);

```

```solidity
File: test/mocks/MockSYA.sol

121:         IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), payment);

```

### <a name="M-2"></a>[M-2] `block.number` means different things on different L2s
On Optimism, `block.number` is the L2 block number, but on Arbitrum, it's the L1 block number, and `ArbSys(address(100)).arbBlockNumber()` must be used. Furthermore, L2 block numbers often occur much more frequently than L1 block numbers (any may even occur on a per-transaction basis), so using block numbers for timing results in inconsistencies, especially when voting is involved across multiple chains. As of version 4.9, OpenZeppelin has [modified](https://blog.openzeppelin.com/introducing-openzeppelin-contracts-v4.9#governor) their governor code to use a clock rather than block numbers, to avoid these sorts of issues, but this still requires that the project [implement](https://docs.openzeppelin.com/contracts/4.x/governance#token_2) a [clock](https://eips.ethereum.org/EIPS/eip-6372) for each L2.

*Instances (1)*:
```solidity
File: test/fork/SYAHarvester.fork.t.sol

107:         vm.roll(block.number + ACCRUAL_WARP / 12);

```

### <a name="M-3"></a>[M-3] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (5)*:
```solidity
File: src/SYAHarvester.sol

27: contract SYAHarvester is Ownable, ERC1155Holder, IUnlockCallback {

122:         Ownable(_owner)

156:     ) external onlyOwner {

200:     function clearRoute(address token) external onlyOwner {

218:     function setEthPool(PoolKey calldata key) external onlyOwner {

```

### <a name="M-4"></a>[M-4] Direct `supportsInterface()` calls may cause caller to revert
Calling `supportsInterface()` on a contract that doesn't implement the ERC-165 standard will result in the call reverting. Even if the caller does support the function, the contract may be malicious and consume all of the transaction's available gas. Call it via a low-level [staticcall()](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/f959d7e4e6ee0b022b41e5b644c79369869d8411/contracts/utils/introspection/ERC165Checker.sol#L119), with a fixed amount of gas, and check the return code, or use OpenZeppelin's [`ERC165Checker.supportsInterface()`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/f959d7e4e6ee0b022b41e5b644c79369869d8411/contracts/utils/introspection/ERC165Checker.sol#L36-L39).

*Instances (2)*:
```solidity
File: test/SYAHarvester.nft.t.sol

152:         assertTrue(h.supportsInterface(type(IERC1155Receiver).interfaceId), "IERC1155Receiver");

153:         assertTrue(h.supportsInterface(type(IERC165).interfaceId), "IERC165");

```

