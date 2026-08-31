# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 2 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 12 |
| [GAS-3](#GAS-3) | State variables should be cached in stack variables rather than re-reading them from storage | 24 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 20 |
| [GAS-5](#GAS-5) | Use Custom Errors instead of Revert Strings to save Gas | 19 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 4 |
| [GAS-7](#GAS-7) | Stack variable used as a cheaper cache for a state variable is only used once | 3 |
| [GAS-8](#GAS-8) | State variables only set in the constructor should be declared `immutable` | 5 |
| [GAS-9](#GAS-9) | Functions guaranteed to revert when called by normal users can be marked `payable` | 11 |
| [GAS-10](#GAS-10) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-11](#GAS-11) | Use shift right/left instead of division/multiplication if possible | 1 |
| [GAS-12](#GAS-12) | Use != 0 instead of > 0 for unsigned integer comparison | 4 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (2)*:
```solidity
File: dispatchers/Uniboost.sol

270:         authVersion += 1;

```

```solidity
File: hooks/UniboostMintDebtHook.sol

134:         mintDebt += added;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (12)*:
```solidity
File: dispatchers/Uniboost.sol

86:         require(primeToken_ != address(0), "Uniboost: zero prime");

87:         require(router_ != address(0), "Uniboost: zero router");

88:         require(targetToken_ != address(0), "Uniboost: zero target token");

125:         require(newPool != address(0), "Uniboost: zero pool");

192:         bool donationEnabled = recipient != address(0) && donationSplit > 0;

258:         require(pooler != address(0), "Uniboost: zero pooler");

281:         require(to != address(0), "Uniboost: zero recipient");

```

```solidity
File: hooks/UniboostMintDebtHook.sol

82:         require(dispatcher_ != address(0), "dispatcher=0");

83:         require(phUSD_ != address(0), "phUSD=0");

84:         require(primeToken_ != address(0), "primeToken=0");

118:         require(newDispatcher != address(0), "dispatcher=0");

142:         if (recipient == address(0)) revert RecipientUnset();

```

### <a name="GAS-3"></a>[GAS-3] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (24)*:
```solidity
File: dispatchers/Uniboost.sol

217:         IERC20(_primeToken).forceApprove(_router, amountIn);

218:         IUniswapV2Router02(_router).swapExactTokensForTokens(

221:         IERC20(_primeToken).forceApprove(_router, 0);

221:         IERC20(_primeToken).forceApprove(_router, 0);

228:             pairToTargetPath[0] = _pairToken;

230:             IERC20(_pairToken).forceApprove(_router, half);

230:             IERC20(_pairToken).forceApprove(_router, half);

231:             IUniswapV2Router02(_router).swapExactTokensForTokens(

234:             IERC20(_pairToken).forceApprove(_router, 0);

234:             IERC20(_pairToken).forceApprove(_router, 0);

240:         uint256 targetBal = IERC20(targetToken).balanceOf(address(this));

241:         uint256 pairRemaining = IERC20(_pairToken).balanceOf(address(this));

242:         IERC20(targetToken).forceApprove(_router, targetBal);

242:         IERC20(targetToken).forceApprove(_router, targetBal);

243:         IERC20(_pairToken).forceApprove(_router, pairRemaining);

243:         IERC20(_pairToken).forceApprove(_router, pairRemaining);

244:         (,, uint256 liquidity) = IUniswapV2Router02(_router).addLiquidity(

245:             targetToken, _pairToken, targetBal, pairRemaining, 0, 0, address(this), block.timestamp

245:             targetToken, _pairToken, targetBal, pairRemaining, 0, 0, address(this), block.timestamp

248:         IERC20(targetToken).forceApprove(_router, 0);

248:         IERC20(targetToken).forceApprove(_router, 0);

249:         IERC20(_pairToken).forceApprove(_router, 0);

249:         IERC20(_pairToken).forceApprove(_router, 0);

261:             emit PoolerAuthorized(pooler, authVersion);

```

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (20)*:
```solidity
File: dispatchers/Uniboost.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

7: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

8: import {IUniswapV2Router02} from "../interfaces/uniswap/IUniswapV2Router02.sol";

9: import {IUniswapV2Pair} from "../interfaces/uniswap/IUniswapV2Pair.sol";

160:         require(path[path.length - 1] == _pairToken, "Uniboost: path end not pair");

187:         bytes calldata /* extraData */

193:         uint256 donationAmount = donationEnabled ? (amount * donationSplit) / 100 : 0;

225:         uint256 half = pairBal / 2;

270:         authVersion += 1;

```

```solidity
File: hooks/UniboostMintDebtHook.sol

4: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

5: import {IUniboostMintDebtHook} from "../interfaces/IUniboostMintDebtHook.sol";

6: import {IMintable} from "../interfaces/IMintable.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

9: import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

89:         scale = 10 ** (18 - d);

132:         uint256 added = (amount * scale * ratio) / 100;

134:         mintDebt += added;

```

### <a name="GAS-5"></a>[GAS-5] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (19)*:
```solidity
File: dispatchers/Uniboost.sol

70:         require(poolerAuthVersion[msg.sender] == authVersion, "Uniboost: caller not authorized pooler");

86:         require(primeToken_ != address(0), "Uniboost: zero prime");

87:         require(router_ != address(0), "Uniboost: zero router");

88:         require(targetToken_ != address(0), "Uniboost: zero target token");

125:         require(newPool != address(0), "Uniboost: zero pool");

128:         require(targetToken == token0 || targetToken == token1, "Uniboost: pool missing target token");

139:         require(newSplit <= 100, "Uniboost: split > 100");

158:         require(path.length >= 2, "Uniboost: path too short");

159:         require(path[0] == _primeToken, "Uniboost: path start not prime");

160:         require(path[path.length - 1] == _pairToken, "Uniboost: path end not pair");

216:         require(amountIn > 0, "Uniboost: nothing to pool");

247:         require(liquidity >= minLP, "Uniboost: insufficient LP");

258:         require(pooler != address(0), "Uniboost: zero pooler");

281:         require(to != address(0), "Uniboost: zero recipient");

```

```solidity
File: hooks/UniboostMintDebtHook.sol

82:         require(dispatcher_ != address(0), "dispatcher=0");

83:         require(phUSD_ != address(0), "phUSD=0");

84:         require(primeToken_ != address(0), "primeToken=0");

86:         require(d <= 18, "decimals>18");

118:         require(newDispatcher != address(0), "dispatcher=0");

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (4)*:
```solidity
File: dispatchers/Uniboost.sol

215:         uint256 amountIn = IERC20(_primeToken).balanceOf(address(this));

224:         uint256 pairBal = IERC20(_pairToken).balanceOf(address(this));

240:         uint256 targetBal = IERC20(targetToken).balanceOf(address(this));

241:         uint256 pairRemaining = IERC20(_pairToken).balanceOf(address(this));

```

### <a name="GAS-7"></a>[GAS-7] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (3)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

98:         uint8 old = ratio;

107:         address old = recipient;

119:         address old = dispatcher;

```

### <a name="GAS-8"></a>[GAS-8] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (5)*:
```solidity
File: dispatchers/Uniboost.sol

89:         _primeToken = primeToken_;

90:         _router = router_;

91:         targetToken = targetToken_;

```

```solidity
File: hooks/UniboostMintDebtHook.sol

88:         phUSD = IMintable(phUSD_);

89:         scale = 10 ** (18 - d);

```

### <a name="GAS-9"></a>[GAS-9] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (11)*:
```solidity
File: dispatchers/Uniboost.sol

118:     function setPool(address newPool) external onlyOwner {

138:     function setDonationSplit(uint256 newSplit) external onlyOwner {

147:     function setRecipient(address newRecipient) external onlyOwner {

157:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {

257:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

269:     function incrementAuthVersion() external onlyOwner {

280:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: hooks/UniboostMintDebtHook.sol

96:     function setRatio(uint8 newRatio) external onlyOwner {

106:     function setRecipient(address newRecipient) external onlyOwner {

117:     function setDispatcher(address newDispatcher) external onlyOwner {

141:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

### <a name="GAS-10"></a>[GAS-10] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

31:     uint8 public constant MAX_RATIO = 50;

34:     uint8 public constant DEFAULT_RATIO = 50;

```

### <a name="GAS-11"></a>[GAS-11] Use shift right/left instead of division/multiplication if possible
While the `DIV` / `MUL` opcode uses 5 gas, the `SHR` / `SHL` opcode only uses 3 gas. Furthermore, beware that Solidity's division operation also includes a division-by-0 prevention which is bypassed using shifting. Eventually, overflow checks are never performed for shift operations as they are done for arithmetic operations. Instead, the result is always truncated, so the calculation can be unchecked in Solidity version `0.8+`
- Use `>> 1` instead of `/ 2`
- Use `>> 2` instead of `/ 4`
- Use `<< 3` instead of `* 8`
- ...
- Use `>> 5` instead of `/ 2^5 == / 32`
- Use `<< 6` instead of `* 2^6 == * 64`

TL;DR:
- Shifting left by N is like multiplying by 2^N (Each bits to the left is an increased power of 2)
- Shifting right by N is like dividing by 2^N (Each bits to the right is a decreased power of 2)

*Saves around 2 gas + 20 for unchecked per instance*

*Instances (1)*:
```solidity
File: dispatchers/Uniboost.sol

225:         uint256 half = pairBal / 2;

```

### <a name="GAS-12"></a>[GAS-12] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (4)*:
```solidity
File: dispatchers/Uniboost.sol

192:         bool donationEnabled = recipient != address(0) && donationSplit > 0;

194:         if (donationAmount > 0) {

216:         require(amountIn > 0, "Uniboost: nothing to pool");

226:         if (half > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 2 |
| [NC-2](#NC-2) | Array indices should be referenced via `enum`s rather than via numeric literals | 5 |
| [NC-3](#NC-3) | `constant`s should be defined rather than using magic numbers | 7 |
| [NC-4](#NC-4) | Control structures do not follow the Solidity Style Guide | 5 |
| [NC-5](#NC-5) | Consider disabling `renounceOwnership()` | 1 |
| [NC-6](#NC-6) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 2 |
| [NC-7](#NC-7) | Event missing indexed field | 5 |
| [NC-8](#NC-8) | Events that mark critical parameter changes should contain both the old and the new value | 8 |
| [NC-9](#NC-9) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-10](#NC-10) | Functions should not be longer than 50 lines | 18 |
| [NC-11](#NC-11) | Lack of checks in setters | 3 |
| [NC-12](#NC-12) | Missing Event for critical parameters change | 1 |
| [NC-13](#NC-13) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 3 |
| [NC-14](#NC-14) | Consider using named mappings | 1 |
| [NC-15](#NC-15) | Take advantage of Custom Error's return value property | 4 |
| [NC-16](#NC-16) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-17](#NC-17) | Event is missing `indexed` fields | 9 |
| [NC-18](#NC-18) | Constants should be defined rather than using magic numbers | 1 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (2)*:
```solidity
File: dispatchers/Uniboost.sol

131:         _pairToken = pairToken_;

148:         recipient = newRecipient;

```

### <a name="NC-2"></a>[NC-2] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (5)*:
```solidity
File: dispatchers/Uniboost.sol

159:         require(path[0] == _primeToken, "Uniboost: path start not prime");

170:             path[0] = _primeToken;

171:             path[1] = _pairToken;

228:             pairToTargetPath[0] = _pairToken;

229:             pairToTargetPath[1] = targetToken;

```

### <a name="NC-3"></a>[NC-3] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (7)*:
```solidity
File: dispatchers/Uniboost.sol

139:         require(newSplit <= 100, "Uniboost: split > 100");

158:         require(path.length >= 2, "Uniboost: path too short");

193:         uint256 donationAmount = donationEnabled ? (amount * donationSplit) / 100 : 0;

225:         uint256 half = pairBal / 2;

```

```solidity
File: hooks/UniboostMintDebtHook.sol

86:         require(d <= 18, "decimals>18");

89:         scale = 10 ** (18 - d);

132:         uint256 added = (amount * scale * ratio) / 100;

```

### <a name="NC-4"></a>[NC-4] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (5)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

97:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

129:         if (msg.sender != dispatcher) revert OnlyDispatcher();

133:         if (added == 0) return;

142:         if (recipient == address(0)) revert RecipientUnset();

144:         if (debt == 0) return;

```

### <a name="NC-5"></a>[NC-5] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

29: contract UniboostMintDebtHook is IDispatchHook, IUniboostMintDebtHook, Ownable, ReentrancyGuard {

```

### <a name="NC-6"></a>[NC-6] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (2)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

82:         require(dispatcher_ != address(0), "dispatcher=0");

118:         require(newDispatcher != address(0), "dispatcher=0");

```

### <a name="NC-7"></a>[NC-7] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (5)*:
```solidity
File: dispatchers/Uniboost.sol

61:     event AuthVersionIncremented(uint256 newAuthVersion);

65:     event DonationSplitSet(uint256 newSplit);

66:     event RecipientSet(address newRecipient);

67:     event PrimeToPairPathSet(address[] path);

```

```solidity
File: hooks/UniboostMintDebtHook.sol

58:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

```

### <a name="NC-8"></a>[NC-8] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (8)*:
```solidity
File: dispatchers/Uniboost.sol

138:     function setDonationSplit(uint256 newSplit) external onlyOwner {
             require(newSplit <= 100, "Uniboost: split > 100");
             donationSplit = newSplit;
             emit DonationSplitSet(newSplit);

147:     function setRecipient(address newRecipient) external onlyOwner {
             recipient = newRecipient;
             emit RecipientSet(newRecipient);

157:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {
             require(path.length >= 2, "Uniboost: path too short");
             require(path[0] == _primeToken, "Uniboost: path start not prime");
             require(path[path.length - 1] == _pairToken, "Uniboost: path end not pair");
             _primeToPairPath = path;
             emit PrimeToPairPathSet(path);

257:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "Uniboost: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);
             } else {
                 delete poolerAuthVersion[pooler];
                 emit PoolerDeauthorized(pooler);

257:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "Uniboost: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);

```

```solidity
File: hooks/UniboostMintDebtHook.sol

96:     function setRatio(uint8 newRatio) external onlyOwner {
            if (newRatio > MAX_RATIO) revert RatioTooHigh();
            uint8 old = ratio;
            ratio = newRatio;
            emit RatioUpdated(old, newRatio);

106:     function setRecipient(address newRecipient) external onlyOwner {
             address old = recipient;
             recipient = newRecipient;
             emit RecipientUpdated(old, newRecipient);

117:     function setDispatcher(address newDispatcher) external onlyOwner {
             require(newDispatcher != address(0), "dispatcher=0");
             address old = dispatcher;
             dispatcher = newDispatcher;
             emit DispatcherUpdated(old, newDispatcher);

```

### <a name="NC-9"></a>[NC-9] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: dispatchers/Uniboost.sol

1: 
   Current order:
   external primeToken
   external router
   external targetPool
   external pairToken
   external setPool
   internal _setPool
   external setDonationSplit
   external setRecipient
   external setPrimeToPairPath
   public primeToPairPath
   internal _dispatch
   external pool
   external setAuthorizedPooler
   external incrementAuthVersion
   external rescueERC20
   
   Suggested order:
   external primeToken
   external router
   external targetPool
   external pairToken
   external setPool
   external setDonationSplit
   external setRecipient
   external setPrimeToPairPath
   external pool
   external setAuthorizedPooler
   external incrementAuthVersion
   external rescueERC20
   public primeToPairPath
   internal _setPool
   internal _dispatch

```

### <a name="NC-10"></a>[NC-10] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (18)*:
```solidity
File: dispatchers/Uniboost.sol

97:     function primeToken() external view override returns (address) {

102:     function router() external view returns (address) {

107:     function targetPool() external view returns (address) {

112:     function pairToken() external view returns (address) {

118:     function setPool(address newPool) external onlyOwner {

138:     function setDonationSplit(uint256 newSplit) external onlyOwner {

147:     function setRecipient(address newRecipient) external onlyOwner {

157:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {

167:     function primeToPairPath() public view returns (address[] memory) {

208:     function pool(uint256 minPairOut, uint256 minTargetOut, uint256 minLP)

257:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

269:     function incrementAuthVersion() external onlyOwner {

280:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: hooks/UniboostMintDebtHook.sol

96:     function setRatio(uint8 newRatio) external onlyOwner {

106:     function setRecipient(address newRecipient) external onlyOwner {

117:     function setDispatcher(address newDispatcher) external onlyOwner {

128:     function onDispatch(address minter, uint256 amount, bytes calldata) external {

141:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

### <a name="NC-11"></a>[NC-11] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (3)*:
```solidity
File: dispatchers/Uniboost.sol

118:     function setPool(address newPool) external onlyOwner {
             _setPool(newPool);

147:     function setRecipient(address newRecipient) external onlyOwner {
             recipient = newRecipient;
             emit RecipientSet(newRecipient);

```

```solidity
File: hooks/UniboostMintDebtHook.sol

106:     function setRecipient(address newRecipient) external onlyOwner {
             address old = recipient;
             recipient = newRecipient;
             emit RecipientUpdated(old, newRecipient);

```

### <a name="NC-12"></a>[NC-12] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (1)*:
```solidity
File: dispatchers/Uniboost.sol

118:     function setPool(address newPool) external onlyOwner {
             _setPool(newPool);

```

### <a name="NC-13"></a>[NC-13] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (3)*:
```solidity
File: dispatchers/Uniboost.sol

70:         require(poolerAuthVersion[msg.sender] == authVersion, "Uniboost: caller not authorized pooler");

```

```solidity
File: hooks/UniboostMintDebtHook.sol

70:         if (msg.sender != owner() && msg.sender != recipient) {

129:         if (msg.sender != dispatcher) revert OnlyDispatcher();

```

### <a name="NC-14"></a>[NC-14] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (1)*:
```solidity
File: dispatchers/Uniboost.sol

57:     mapping(address => uint256) public poolerAuthVersion;

```

### <a name="NC-15"></a>[NC-15] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (4)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

71:             revert OnlyOwnerOrRecipient();

97:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

129:         if (msg.sender != dispatcher) revert OnlyDispatcher();

142:         if (recipient == address(0)) revert RecipientUnset();

```

### <a name="NC-16"></a>[NC-16] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

1: 
   Current order:
   VariableDeclaration.MAX_RATIO
   VariableDeclaration.DEFAULT_RATIO
   VariableDeclaration.dispatcher
   VariableDeclaration.phUSD
   VariableDeclaration.scale
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
   VariableDeclaration.scale
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

### <a name="NC-17"></a>[NC-17] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (9)*:
```solidity
File: dispatchers/Uniboost.sol

59:     event PoolerAuthorized(address indexed pooler, uint256 atAuthVersion);

61:     event AuthVersionIncremented(uint256 newAuthVersion);

62:     event Pooled(address indexed pooler, uint256 primeSpent, uint256 liquidity, uint256 minLP);

65:     event DonationSplitSet(uint256 newSplit);

66:     event RecipientSet(address newRecipient);

67:     event PrimeToPairPathSet(address[] path);

```

```solidity
File: hooks/UniboostMintDebtHook.sol

58:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

60:     event DebtAccrued(address indexed minter, uint256 dispatchedAmount, uint256 debtAdded, uint256 newTotalDebt);

61:     event DebtPulled(address indexed recipient, uint256 amount);

```

### <a name="NC-18"></a>[NC-18] Constants should be defined rather than using magic numbers

*Instances (1)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

89:         scale = 10 ** (18 - d);

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 2 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 2 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 2 |
| [L-4](#L-4) | `decimals()` is not a part of the ERC-20 standard | 1 |
| [L-5](#L-5) | Prevent accidentally burning tokens | 1 |
| [L-6](#L-6) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 2 |
| [L-7](#L-7) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
| [L-8](#L-8) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

29: contract UniboostMintDebtHook is IDispatchHook, IUniboostMintDebtHook, Ownable, ReentrancyGuard {

81:     constructor(address initialOwner, address dispatcher_, address phUSD_, address primeToken_) Ownable(initialOwner) {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (2)*:
```solidity
File: dispatchers/Uniboost.sol

195:             IERC20(_primeToken).safeTransfer(recipient, donationAmount);

282:         IERC20(token).safeTransfer(to, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (2)*:
```solidity
File: dispatchers/Uniboost.sol

131:         _pairToken = pairToken_;

148:         recipient = newRecipient;

```

### <a name="L-4"></a>[L-4] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (1)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

85:         uint8 d = IERC20Metadata(primeToken_).decimals();

```

### <a name="L-5"></a>[L-5] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (1)*:
```solidity
File: hooks/UniboostMintDebtHook.sol

135:         emit DebtAccrued(minter, amount, added, mintDebt);

```

### <a name="L-6"></a>[L-6] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (2)*:
```solidity
File: dispatchers/Uniboost.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: hooks/UniboostMintDebtHook.sol

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
File: hooks/UniboostMintDebtHook.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-8"></a>[L-8] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: dispatchers/Uniboost.sol

280:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 12 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (12)*:
```solidity
File: dispatchers/Uniboost.sol

118:     function setPool(address newPool) external onlyOwner {

138:     function setDonationSplit(uint256 newSplit) external onlyOwner {

147:     function setRecipient(address newRecipient) external onlyOwner {

157:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {

257:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

269:     function incrementAuthVersion() external onlyOwner {

280:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: hooks/UniboostMintDebtHook.sol

29: contract UniboostMintDebtHook is IDispatchHook, IUniboostMintDebtHook, Ownable, ReentrancyGuard {

81:     constructor(address initialOwner, address dispatcher_, address phUSD_, address primeToken_) Ownable(initialOwner) {

96:     function setRatio(uint8 newRatio) external onlyOwner {

106:     function setRecipient(address newRecipient) external onlyOwner {

117:     function setDispatcher(address newDispatcher) external onlyOwner {

```

