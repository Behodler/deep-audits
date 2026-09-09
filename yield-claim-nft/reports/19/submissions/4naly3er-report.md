# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 7 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 61 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 6 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 1 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 49 |
| [GAS-6](#GAS-6) | Use calldata instead of memory for function arguments that do not get mutated | 4 |
| [GAS-7](#GAS-7) | For Operations that will not overflow, you could use unchecked | 151 |
| [GAS-8](#GAS-8) | Use Custom Errors instead of Revert Strings to save Gas | 103 |
| [GAS-9](#GAS-9) | Avoid contract existence checks by using low level calls | 16 |
| [GAS-10](#GAS-10) | Stack variable used as a cheaper cache for a state variable is only used once | 18 |
| [GAS-11](#GAS-11) | State variables only set in the constructor should be declared `immutable` | 16 |
| [GAS-12](#GAS-12) | Functions guaranteed to revert when called by normal users can be marked `payable` | 70 |
| [GAS-13](#GAS-13) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 3 |
| [GAS-14](#GAS-14) | Using `private` rather than `public` for constants, saves gas | 16 |
| [GAS-15](#GAS-15) | Use shift right/left instead of division/multiplication if possible | 2 |
| [GAS-16](#GAS-16) | Superfluous event fields | 1 |
| [GAS-17](#GAS-17) | Use of `this` instead of marking as `public` an `external` function | 1 |
| [GAS-18](#GAS-18) | Increments/decrements can be unchecked in for-loops | 1 |
| [GAS-19](#GAS-19) | Use != 0 instead of > 0 for unsigned integer comparison | 16 |
| [GAS-20](#GAS-20) | WETH address definition can be use directly | 1 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (7)*:
```solidity
File: ./src/BurnRecorder.sol

51:         totalBurnt[token] += amount;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

203:         authVersion += 1;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

369:         authVersion += 1;

```

```solidity
File: ./src/dispatchers/Uniboost.sol

328:         authVersion += 1;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

113:         mintDebt += added;

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

129:         mintDebt += added;

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

134:         mintDebt += added;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (61)*:
```solidity
File: ./src/NFTMinterV2.sol

129:         require(dispatcher != address(0), "NFTMinterV2: zero dispatcher address");

153:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

173:         require(config.dispatcher != address(0), "NFTMinterV2: index not registered");

208:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

228:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

254:         if (dispatcher == address(0)) {

277:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

283:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

291:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

95:         require(address(newHook) != address(0), "ATokenDispatcherV2: zero hook");

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

149:         require(sUSDS_ != address(0), "BalancerPoolerV2: zero sUSDS");

150:         require(router_ != address(0), "BalancerPoolerV2: zero router");

183:         require(newPool != address(0), "BalancerPoolerV2: zero pool address");

191:         require(pooler != address(0), "BalancerPoolerV2: zero pooler");

228:         require(newPSM != address(0), "BalancerPoolerV2: zero psm");

247:         require(newStreamer != address(0), "BalancerPoolerV2: zero nudgeStreamer");

274:         bool donationEnabled = batchMinter != address(0) && psm != address(0) && batchDonationSize > 0;

344:             require(streamer != address(0), "BalancerPoolerV2: nudgeStreamer unset");

438:         require(to != address(0), "BalancerPoolerV2: zero recipient");

```

```solidity
File: ./src/dispatchers/GatherV2.sol

27:         require(recipient_ != address(0), "GatherV2: zero recipient address");

45:         require(newRecipient != address(0), "GatherV2: zero recipient address");

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

82:         require(batchMinter_ != address(0), "NudgeRatchet: zero batchMinter");

97:         require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");

106:         require(newStreamer != address(0), "NudgeRatchet: zero nudgeStreamer");

158:             require(streamer != address(0), "NudgeRatchet: nudgeStreamer unset");

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

73:         require(batchMinter_ != address(0), "NudgeRatchetDelayRelease: zero batchMinter");

90:         require(newBatchMinter != address(0), "NudgeRatchetDelayRelease: zero batchMinter");

119:         require(to != address(0), "NudgeRatchetDelayRelease: zero recipient");

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

210:         require(promotionToken_ != address(0), "PromotionUniV2_Eth: zero promotion token");

272:         address token0 = IUniswapV2Pair(newPair).token0();

306:         insurer = newInsurer;

314:         IERC20(WBTC).safeTransfer(to, amount);

321:         psm = newPSM;

350:         address old = nudgeStreamer;

358:         if (authorized) {

385:         uint256 donationAmount = donationEnabled ? (amount * donationSplit) / 100 : 0;

395:             IERC20(USDC).forceApprove(streamer, donationAmount);

577:         require(token != WBTC, "PromotionUniV2_Eth: WBTC is insurer-only");

585:         require(ok, "PromotionUniV2_Eth: eth rescue failed");

```

```solidity
File: ./src/dispatchers/Uniboost.sol

122:         require(primeToken_ != address(0), "Uniboost: zero prime");

123:         require(router_ != address(0), "Uniboost: zero router");

124:         require(targetToken_ != address(0), "Uniboost: zero target token");

161:         require(newPool != address(0), "Uniboost: zero pool");

191:         require(newStreamer != address(0), "Uniboost: zero nudgeStreamer");

238:         bool donationEnabled = recipient != address(0) && donationSplit > 0;

248:             require(streamer != address(0), "Uniboost: nudgeStreamer unset");

316:         require(pooler != address(0), "Uniboost: zero pooler");

339:         require(to != address(0), "Uniboost: zero recipient");

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

67:         require(dispatcher_ != address(0), "dispatcher=0");

68:         require(phUSD_ != address(0), "phUSD=0");

99:         require(newDispatcher != address(0), "dispatcher=0");

121:         if (recipient == address(0)) revert RecipientUnset();

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

79:         require(dispatcher_ != address(0), "dispatcher=0");

80:         require(phUSD_ != address(0), "phUSD=0");

112:         require(newDispatcher != address(0), "dispatcher=0");

137:         if (recipient == address(0)) revert RecipientUnset();

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

82:         require(dispatcher_ != address(0), "dispatcher=0");

83:         require(phUSD_ != address(0), "phUSD=0");

84:         require(primeToken_ != address(0), "primeToken=0");

118:         require(newDispatcher != address(0), "dispatcher=0");

142:         if (recipient == address(0)) revert RecipientUnset();

```

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (6)*:
```solidity
File: ./src/BurnRecorder.sol

13:     mapping(address => bool) private _burners;

```

```solidity
File: ./src/NFTMinterV2.sol

40:     mapping(address => bool) public authorizedBurners;

43:     mapping(address => bool) public authorizedMinters;

98:     bool public paused;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

83:     bool private immutable _sUSDSIsFirst;

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

47:     mapping(address => bool) public releasers;

```

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (1)*:
```solidity
File: ./src/MultiPooler.sol

62:         for (uint256 i = 0; i < calls.length; i++) {

```

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (49)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

195:         } else {

282:             IERC4626(_sUSDS).deposit(poolingUSDS, address(this));

288:             uint256 remainingUSDS = IERC20(_primeToken).balanceOf(address(this));

322:         uint256 gemAmt = (usdsAmount * WAD) / (conv * (WAD + tout));

334:             // Story 047: USDC lands HERE, not on the batch-minter — it is streamed on below.

336:             IERC20(_primeToken).forceApprove(psm, 0); // tidy allowance.

336:             IERC20(_primeToken).forceApprove(psm, 0); // tidy allowance.

338:             // Push the freshly-bought USDC through the streamer, which buffers it and releases

346:             IERC20(gem).forceApprove(streamer, gemAmt);

373:             IERC20(_sUSDS).safeTransfer(_vault, sUSDSAmount);

374:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

374:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

376:             uint256[] memory maxAmountsIn = new uint256[](2);

395:             IBalancerVault(_vault).settle(IERC20(_sUSDS), actualInVault);

397:             emit Pooled(pooler, actualInVault, bptAmountOut, minBPT);

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

38:         _burnRecorder.burn(_token, amount);

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

159:             IERC20(_token).forceApprove(streamer, bal);

160:             INudgeStreamer(streamer).collectNudge(batchMinter, _token, bal);

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

362:             delete poolerAuthVersion[pooler];

468:         (,, liquidity) = IUniswapV2Router02(UNIV2_ROUTER).addLiquidity(

471:         require(liquidity >= minLP, "PromotionUniV2_Eth: insufficient LP");

476:     /// @dev Leg A: USDC →(PSM sellGem)→ USDS →(ERC4626 deposit)→ sUSDS →(Balancer swap)→ phUSD.

485:         IERC20(USDC).forceApprove(psm, 0);

487:         // Step 2: USDS -> sUSDS (the Balancer phUSD pool pairs against sUSDS, not USDS).

```

```solidity
File: ./src/dispatchers/Uniboost.sol

250:             INudgeStreamer(streamer).collectNudge(recipient, _primeToken, donationAmount);

275:         IERC20(_primeToken).forceApprove(_router, amountIn);

276:         IUniswapV2Router02(_router).swapExactTokensForTokens(

279:         IERC20(_primeToken).forceApprove(_router, 0);

279:         IERC20(_primeToken).forceApprove(_router, 0);

286:             pairToTargetPath[0] = _pairToken;

288:             IERC20(_pairToken).forceApprove(_router, half);

288:             IERC20(_pairToken).forceApprove(_router, half);

289:             IUniswapV2Router02(_router).swapExactTokensForTokens(

292:             IERC20(_pairToken).forceApprove(_router, 0);

292:             IERC20(_pairToken).forceApprove(_router, 0);

298:         uint256 targetBal = IERC20(targetToken).balanceOf(address(this));

299:         uint256 pairRemaining = IERC20(_pairToken).balanceOf(address(this));

300:         IERC20(targetToken).forceApprove(_router, targetBal);

300:         IERC20(targetToken).forceApprove(_router, targetBal);

301:         IERC20(_pairToken).forceApprove(_router, pairRemaining);

301:         IERC20(_pairToken).forceApprove(_router, pairRemaining);

302:         (,, uint256 liquidity) = IUniswapV2Router02(_router).addLiquidity(

303:             targetToken, _pairToken, targetBal, pairRemaining, 0, 0, address(this), block.timestamp

303:             targetToken, _pairToken, targetBal, pairRemaining, 0, 0, address(this), block.timestamp

306:         IERC20(targetToken).forceApprove(_router, 0);

306:         IERC20(targetToken).forceApprove(_router, 0);

307:         IERC20(_pairToken).forceApprove(_router, 0);

307:         IERC20(_pairToken).forceApprove(_router, 0);

319:             emit PoolerAuthorized(pooler, authVersion);

```

### <a name="GAS-6"></a>[GAS-6] Use calldata instead of memory for function arguments that do not get mutated
When a function with a `memory` array is called externally, the `abi.decode()` step has to use a for-loop to copy each index of the `calldata` to the `memory` index. Each iteration of this for-loop costs at least 60 gas (i.e. `60 * <mem_array>.length`). Using `calldata` directly bypasses this loop. 

If the array is passed to an `internal` function which passes the array to another internal function where the array is modified and therefore `memory` is used in the `external` call, it's still more gas-efficient to use `calldata` when the `external` function uses modifiers, since the modifiers may prevent the internal functions from being called. Structs have the same overhead as an array of length one. 

 *Saves 60 gas per instance*

*Instances (4)*:
```solidity
File: ./src/interfaces/balancer/IBalancerRouter.sol

7:         uint256[] memory exactAmountsIn,

9:         bytes memory userData

```

```solidity
File: ./src/interfaces/balancer/IBalancerVault.sol

9:     function addLiquidity(AddLiquidityParams memory params)

12:     function swap(VaultSwapParams memory params)

```

### <a name="GAS-7"></a>[GAS-7] For Operations that will not overflow, you could use unchecked

*Instances (151)*:
```solidity
File: ./src/BurnRecorder.sol

4: import {IBurnRecorder} from "./interfaces/IBurnRecorder.sol";

5: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

51:         totalBurnt[token] += amount;

67:         _latestIndex++;

```

```solidity
File: ./src/MultiPooler.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {IUniboostPooler} from "./interfaces/IUniboostPooler.sol";

62:         for (uint256 i = 0; i < calls.length; i++) {

```

```solidity
File: ./src/NFTMinterV2.sol

4: import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

5: import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

10: import {ITokenDispatcherV2} from "./interfaces/ITokenDispatcherV2.sol";

11: import {ATokenDispatcherV2} from "./dispatchers/ATokenDispatcherV2.sol";

12: import {INFTMinterV2} from "./interfaces/INFTMinterV2.sol";

13: import {ITokenMinterV2} from "./interfaces/ITokenMinterV2.sol";

14: import {IPausable} from "pauser/interfaces/IPausable.sol";

21:         address dispatcher; // TokenDispatcher contract address

22:         uint256 price; // current mint price in token units (18 decimals)

23:         uint256 growthBasisPoints; // price growth per mint in basis points (100 = 1%)

24:         bool disabled; // if true, new mints are blocked but existing NFTs remain valid

133:         nextIndex++;

184:         uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

188:         config.price = price + (price * config.growthBasisPoints) / 10000;

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

4: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

5: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

6: import {DefaultDispatchHook} from "../hooks/DefaultDispatchHook.sol";

7: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

8: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

9: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

7: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

8: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

9: import {ISkyPSM} from "../interfaces/ISkyPSM.sol";

10: import {IBalancerVault} from "../interfaces/balancer/IBalancerVault.sol";

11: import {IBalancerRouter} from "../interfaces/balancer/IBalancerRouter.sol";

12: import {IUnlockCallback} from "../interfaces/balancer/IUnlockCallback.sol";

13: import {AddLiquidityParams, AddLiquidityKind} from "../interfaces/balancer/BalancerTypes.sol";

14: import {INudgeStreamer} from "phoenix-nft-staking/INudgeStreamer.sol";

203:         authVersion += 1;

269:         bytes calldata /*extraData*/

276:         uint256 donationUSDS = donationEnabled ? (amount * batchDonationSize) / 100 : 0;

277:         uint256 poolingUSDS = amount - donationUSDS;

292:                     emit DonationSkipped(remainingUSDS); // USDS parks on the contract.

322:         uint256 gemAmt = (usdsAmount * WAD) / (conv * (WAD + tout));

331:             uint256 usdsSpent = gemAmt * conv * (WAD + tout) / WAD;

336:             IERC20(_primeToken).forceApprove(psm, 0); // tidy allowance.

374:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

4: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

5: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

6: import {IBurnable} from "../interfaces/IBurnable.sol";

7: import {IBurnRecorder} from "../interfaces/IBurnRecorder.sol";

32:         bytes calldata /* extraData */

```

```solidity
File: ./src/dispatchers/GatherV2.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

7: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

56:         bytes calldata /* extraData */

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

8: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

9: import {INudgeRatchetMintDebtHook} from "../interfaces/INudgeRatchetMintDebtHook.sol";

10: import {INudgeStreamer} from "phoenix-nft-staking/INudgeStreamer.sol";

84:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

134:     function _dispatch(address, uint256 amount, bytes calldata /* extraData */) internal override {

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

8: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

9: import {INudgeRatchetMintDebtHook} from "../interfaces/INudgeRatchetMintDebtHook.sol";

77:             "NudgeRatchetDelayRelease: token must be 6-decimal USDC"

131:     function _dispatch(address, uint256 /* amount */, bytes calldata /* extraData */)

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

7: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

8: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

9: import {ISkyPSM} from "../interfaces/ISkyPSM.sol";

10: import {IPhusdBurnable} from "../interfaces/IPhusdBurnable.sol";

11: import {IBalancerVault} from "../interfaces/balancer/IBalancerVault.sol";

12: import {IUnlockCallback} from "../interfaces/balancer/IUnlockCallback.sol";

13: import {VaultSwapParams, SwapKind} from "../interfaces/balancer/BalancerTypes.sol";

14: import {IUniswapV2Router02} from "../interfaces/uniswap/IUniswapV2Router02.sol";

15: import {IUniswapV2Pair} from "../interfaces/uniswap/IUniswapV2Pair.sol";

16: import {INudgeStreamer} from "phoenix-nft-staking/INudgeStreamer.sol";

176:         uint256 primeSpent, // amountIn (USDC)

177:         uint256 phusdAcquired, // gross phUSD out of Leg A (pre-burn)

178:         uint256 phusdBurned, // = phusdAcquired / 2

179:         uint256 wbtcAcquired, // WBTC out of Leg C (8dp)

180:         uint256 liquidity // LP minted into the phUSD/promotion pair

286:         require(path[path.length - 1] == promotionToken, "PromotionUniV2_Eth: path end not promotion");

297:         require(path[path.length - 1] == WBTC, "PromotionUniV2_Eth: path end not WBTC");

369:         authVersion += 1;

383:     function _dispatch(address, uint256 amount, bytes calldata /* extraData */ ) internal override {

385:         uint256 donationAmount = donationEnabled ? (amount * donationSplit) / 100 : 0;

439:             uint256 amountA = (amountIn * 60) / 100; // phUSD leg

440:             uint256 amountB = (amountIn * 30) / 100; // promotion leg

441:             uint256 amountC = amountIn - amountA - amountB; // WBTC leg (~10% + rounding dust → reserve)

451:         uint256 phusdBurned = phusdAcquired / 2;

527:         wbtcOut = amounts[amounts.length - 1];

551:         IERC20(sUSDS).safeTransfer(BALANCER_VAULT, sharesIn); // 1. pay input

561:         (,, uint256 amountOut) = IBalancerVault(BALANCER_VAULT).swap(p); // 2. swap

562:         IBalancerVault(BALANCER_VAULT).settle(IERC20(sUSDS), sharesIn); // 3. settle input

563:         IBalancerVault(BALANCER_VAULT).sendTo(IERC20(phUSD), address(this), amountOut); // 4. pull output

577:         require(token != WBTC, "PromotionUniV2_Eth: WBTC is insurer-only");

```

```solidity
File: ./src/dispatchers/Uniboost.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

7: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

8: import {IUniswapV2Router02} from "../interfaces/uniswap/IUniswapV2Router02.sol";

9: import {IUniswapV2Pair} from "../interfaces/uniswap/IUniswapV2Pair.sol";

10: import {INudgeStreamer} from "phoenix-nft-staking/INudgeStreamer.sol";

205:         require(path[path.length - 1] == _pairToken, "Uniboost: path end not pair");

233:         bytes calldata /* extraData */

239:         uint256 donationAmount = donationEnabled ? (amount * donationSplit) / 100 : 0;

283:         uint256 half = pairBal / 2;

328:         authVersion += 1;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

4: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

5: import {IBalancerPoolerMintDebtHook} from "../interfaces/IBalancerPoolerMintDebtHook.sol";

6: import {IMintable} from "../interfaces/IMintable.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

111:         uint256 added = (amount * ratio) / 100;

113:         mintDebt += added;

```

```solidity
File: ./src/hooks/DefaultDispatchHook.sol

4: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

4: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

5: import {INudgeRatchetMintDebtHook} from "../interfaces/INudgeRatchetMintDebtHook.sol";

6: import {IMintable} from "../interfaces/IMintable.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

127:         uint256 added = (amount * USDC_TO_PHUSD_SCALE * ratio) / 100;

129:         mintDebt += added;

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

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

```solidity
File: ./src/interfaces/INFTMinterV2.sol

4: import {ITokenMinterV2} from "./ITokenMinterV2.sol";

```

```solidity
File: ./src/interfaces/balancer/BalancerTypes.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

```

```solidity
File: ./src/interfaces/balancer/IBalancerVault.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {AddLiquidityParams, VaultSwapParams} from "./BalancerTypes.sol";

```

### <a name="GAS-8"></a>[GAS-8] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (103)*:
```solidity
File: ./src/BurnRecorder.sol

32:         require(_burners[msg.sender], "BurnRecorder: caller is not burner");

```

```solidity
File: ./src/MultiPooler.sol

39:         require(msg.sender == pooler, "MultiPooler: caller not pooler");

61:         require(calls.length > 0, "MultiPooler: empty batch");

```

```solidity
File: ./src/NFTMinterV2.sol

112:         require(msg.sender == pauser, "Only pauser");

119:         require(msg.sender == pauser, "Only pauser");

129:         require(dispatcher != address(0), "NFTMinterV2: zero dispatcher address");

130:         require(dispatcherToIndex[dispatcher] == 0, "NFTMinterV2: dispatcher already registered");

153:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

171:         require(!paused, "Contract is paused");

173:         require(config.dispatcher != address(0), "NFTMinterV2: index not registered");

174:         require(!config.disabled, "NFTMinterV2: dispatcher is disabled");

207:         require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");

208:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

228:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

277:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

283:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

291:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

301:         require(balance > 0, "NFTMinterV2: no tokens to withdraw");

310:         require(dispatcherToIndex[dispatcher] != 0, "NFTMinterV2: dispatcher not registered");

342:         require(authorizedBurners[msg.sender], "NFTMinterV2: caller is not authorized burner");

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

45:         require(msg.sender == _minter, "ATokenDispatcherV2: caller is not minter");

95:         require(address(newHook) != address(0), "ATokenDispatcherV2: zero hook");

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

137:         require(poolerAuthVersion[msg.sender] == authVersion, "BalancerPoolerV2: caller not authorized pooler");

149:         require(sUSDS_ != address(0), "BalancerPoolerV2: zero sUSDS");

150:         require(router_ != address(0), "BalancerPoolerV2: zero router");

183:         require(newPool != address(0), "BalancerPoolerV2: zero pool address");

191:         require(pooler != address(0), "BalancerPoolerV2: zero pooler");

211:         require(newSize <= 100, "BalancerPoolerV2: size > 100");

228:         require(newPSM != address(0), "BalancerPoolerV2: zero psm");

247:         require(newStreamer != address(0), "BalancerPoolerV2: zero nudgeStreamer");

310:         require(msg.sender == address(this), "BalancerPoolerV2: only self");

313:         require(tout <= maxTout, "BalancerPoolerV2: tout too high");

344:             require(streamer != address(0), "BalancerPoolerV2: nudgeStreamer unset");

358:         require(sUSDSAmount > 0, "BalancerPoolerV2: nothing to pool");

366:         require(msg.sender == _vault, "BalancerPoolerV2: caller is not vault");

438:         require(to != address(0), "BalancerPoolerV2: zero recipient");

```

```solidity
File: ./src/dispatchers/GatherV2.sol

27:         require(recipient_ != address(0), "GatherV2: zero recipient address");

45:         require(newRecipient != address(0), "GatherV2: zero recipient address");

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

82:         require(batchMinter_ != address(0), "NudgeRatchet: zero batchMinter");

84:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

97:         require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");

106:         require(newStreamer != address(0), "NudgeRatchet: zero nudgeStreamer");

148:         require(bal >= amount, "NudgeRatchet: insufficient balance for dispatch");

158:             require(streamer != address(0), "NudgeRatchet: nudgeStreamer unset");

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

63:         require(releasers[msg.sender], "NudgeRatchetDelayRelease: caller is not releaser");

73:         require(batchMinter_ != address(0), "NudgeRatchetDelayRelease: zero batchMinter");

90:         require(newBatchMinter != address(0), "NudgeRatchetDelayRelease: zero batchMinter");

119:         require(to != address(0), "NudgeRatchetDelayRelease: zero recipient");

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

195:         require(poolerAuthVersion[msg.sender] == authVersion, "PromotionUniV2_Eth: caller not authorized pooler");

200:         require(msg.sender == insurer, "PromotionUniV2_Eth: not insurer");

210:         require(promotionToken_ != address(0), "PromotionUniV2_Eth: zero promotion token");

271:         require(newPair != address(0), "PromotionUniV2_Eth: zero pool");

275:         require(ok, "PromotionUniV2_Eth: pair missing token");

284:         require(path.length >= 2, "PromotionUniV2_Eth: path too short");

285:         require(path[0] == WETH, "PromotionUniV2_Eth: path start not WETH");

286:         require(path[path.length - 1] == promotionToken, "PromotionUniV2_Eth: path end not promotion");

295:         require(path.length >= 2, "PromotionUniV2_Eth: path too short");

296:         require(path[0] == USDC, "PromotionUniV2_Eth: path start not USDC");

297:         require(path[path.length - 1] == WBTC, "PromotionUniV2_Eth: path end not WBTC");

305:         require(newInsurer != address(0), "PromotionUniV2_Eth: zero insurer");

313:         require(to != address(0), "PromotionUniV2_Eth: zero recipient");

320:         require(newPSM != address(0), "PromotionUniV2_Eth: zero psm");

334:         require(newSplit <= 100, "PromotionUniV2_Eth: split > 100");

349:         require(newStreamer != address(0), "PromotionUniV2_Eth: zero nudgeStreamer");

357:         require(pooler != address(0), "PromotionUniV2_Eth: zero pooler");

394:             require(streamer != address(0), "PromotionUniV2_Eth: nudgeStreamer unset");

431:         require(amountIn > 0, "PromotionUniV2_Eth: nothing to pool");

432:         require(amountIn <= IERC20(USDC).balanceOf(address(this)), "PromotionUniV2_Eth: insufficient prime");

471:         require(liquidity >= minLP, "PromotionUniV2_Eth: insufficient LP");

482:         require(ISkyPSM(psm).tin() <= maxTin, "PromotionUniV2_Eth: tin too high");

548:         require(msg.sender == BALANCER_VAULT, "PromotionUniV2_Eth: caller is not vault");

576:         require(to != address(0), "PromotionUniV2_Eth: zero recipient");

577:         require(token != WBTC, "PromotionUniV2_Eth: WBTC is insurer-only");

583:         require(to != address(0), "PromotionUniV2_Eth: zero recipient");

585:         require(ok, "PromotionUniV2_Eth: eth rescue failed");

```

```solidity
File: ./src/dispatchers/Uniboost.sol

106:         require(poolerAuthVersion[msg.sender] == authVersion, "Uniboost: caller not authorized pooler");

122:         require(primeToken_ != address(0), "Uniboost: zero prime");

123:         require(router_ != address(0), "Uniboost: zero router");

124:         require(targetToken_ != address(0), "Uniboost: zero target token");

161:         require(newPool != address(0), "Uniboost: zero pool");

164:         require(targetToken == token0 || targetToken == token1, "Uniboost: pool missing target token");

175:         require(newSplit <= 100, "Uniboost: split > 100");

191:         require(newStreamer != address(0), "Uniboost: zero nudgeStreamer");

203:         require(path.length >= 2, "Uniboost: path too short");

204:         require(path[0] == _primeToken, "Uniboost: path start not prime");

205:         require(path[path.length - 1] == _pairToken, "Uniboost: path end not pair");

248:             require(streamer != address(0), "Uniboost: nudgeStreamer unset");

273:         require(amountIn > 0, "Uniboost: nothing to pool");

274:         require(amountIn <= IERC20(_primeToken).balanceOf(address(this)), "Uniboost: insufficient prime");

305:         require(liquidity >= minLP, "Uniboost: insufficient LP");

316:         require(pooler != address(0), "Uniboost: zero pooler");

339:         require(to != address(0), "Uniboost: zero recipient");

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

67:         require(dispatcher_ != address(0), "dispatcher=0");

68:         require(phUSD_ != address(0), "phUSD=0");

99:         require(newDispatcher != address(0), "dispatcher=0");

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

79:         require(dispatcher_ != address(0), "dispatcher=0");

80:         require(phUSD_ != address(0), "phUSD=0");

112:         require(newDispatcher != address(0), "dispatcher=0");

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

82:         require(dispatcher_ != address(0), "dispatcher=0");

83:         require(phUSD_ != address(0), "phUSD=0");

84:         require(primeToken_ != address(0), "primeToken=0");

86:         require(d <= 18, "decimals>18");

118:         require(newDispatcher != address(0), "dispatcher=0");

```

### <a name="GAS-9"></a>[GAS-9] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (16)*:
```solidity
File: ./src/NFTMinterV2.sol

182:         uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);

184:         uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

300:         uint256 balance = IERC20(token).balanceOf(address(this));

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

288:             uint256 remainingUSDS = IERC20(_primeToken).balanceOf(address(this));

357:         uint256 sUSDSAmount = IERC20(_sUSDS).balanceOf(address(this));

372:             uint256 vaultBefore = IERC20(_sUSDS).balanceOf(_vault);

374:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

406:         uint256 sUSDSAmount = IERC20(_sUSDS).balanceOf(address(this));

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

142:         uint256 bal = IERC20(_token).balanceOf(address(this));

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

432:         require(amountIn <= IERC20(USDC).balanceOf(address(this)), "PromotionUniV2_Eth: insufficient prime");

464:         uint256 phusdBal = IERC20(phUSD).balanceOf(address(this));

465:         uint256 promoBal = IERC20(promotionToken).balanceOf(address(this));

```

```solidity
File: ./src/dispatchers/Uniboost.sol

274:         require(amountIn <= IERC20(_primeToken).balanceOf(address(this)), "Uniboost: insufficient prime");

282:         uint256 pairBal = IERC20(_pairToken).balanceOf(address(this));

298:         uint256 targetBal = IERC20(targetToken).balanceOf(address(this));

299:         uint256 pairRemaining = IERC20(_pairToken).balanceOf(address(this));

```

### <a name="GAS-10"></a>[GAS-10] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (18)*:
```solidity
File: ./src/MultiPooler.sol

51:         address oldPooler = pooler;

```

```solidity
File: ./src/NFTMinterV2.sol

105:         address oldPauser = pauser;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

248:         address old = nudgeStreamer;

```

```solidity
File: ./src/dispatchers/GatherV2.sol

46:         address oldRecipient = _recipient;

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

98:         address old = batchMinter;

107:         address old = nudgeStreamer;

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

91:         address old = batchMinter;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

352:         emit NudgeStreamerUpdated(old, newStreamer);

```

```solidity
File: ./src/dispatchers/Uniboost.sol

192:         address old = nudgeStreamer;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

79:         uint8 old = ratio;

88:         address old = recipient;

100:         address old = dispatcher;

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

92:         uint8 old = ratio;

101:         address old = recipient;

113:         address old = dispatcher;

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

98:         uint8 old = ratio;

107:         address old = recipient;

119:         address old = dispatcher;

```

### <a name="GAS-11"></a>[GAS-11] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (16)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

152:         _primeToken = IERC4626(sUSDS_).asset();

155:         _router = router_;

156:         _sUSDSIsFirst = sUSDSIsFirst_;

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

18:         _token = token_;

19:         _burnRecorder = IBurnRecorder(burnRecorder_);

```

```solidity
File: ./src/dispatchers/GatherV2.sol

28:         _token = token_;

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

85:         _token = token_;

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

79:         _token = token_;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

213:         _setPool(targetPair_);

```

```solidity
File: ./src/dispatchers/Uniboost.sol

125:         _primeToken = primeToken_;

126:         _router = router_;

127:         targetToken = targetToken_;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

70:         phUSD = IMintable(phUSD_);

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

82:         phUSD = IMintable(phUSD_);

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

88:         phUSD = IMintable(phUSD_);

89:         scale = 10 ** (18 - d);

```

### <a name="GAS-12"></a>[GAS-12] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (70)*:
```solidity
File: ./src/BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {

50:     function burn(address token, uint256 amount) external onlyBurner {

65:     function registerToken(address token) external onlyOwner {

```

```solidity
File: ./src/MultiPooler.sol

50:     function setPooler(address newPooler) external onlyOwner {

60:     function pool(PoolCall[] calldata calls) external onlyPooler {

```

```solidity
File: ./src/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {

152:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {

219:     function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {

227:     function replaceDispatcher(uint256 index, address newDispatcher) external onlyOwner {

282:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {

290:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {

299:     function emergencyWithdraw(address token) external onlyOwner {

309:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {

332:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

85:     function setMinter(address minter_) external onlyOwner {

94:     function setHook(IDispatchHook newHook) external onlyOwner {

102:     function pause() external onlyMinter {

107:     function unpause() external onlyMinter {

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

182:     function setPool(address newPool) external onlyOwner {

190:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

202:     function incrementAuthVersion() external onlyOwner {

210:     function setBatchDonationSize(uint256 newSize) external onlyOwner {

219:     function setBatchMinter(address newBatchMinter) external onlyOwner {

227:     function setPSM(address newPSM) external onlyOwner {

235:     function setMaxTout(uint256 newMaxTout) external onlyOwner {

246:     function setNudgeStreamer(address newStreamer) external onlyOwner {

356:     function pool(uint256 minBPT) external onlyAuthorizedPooler whenNotPaused nonReentrant {

424:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

437:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/GatherV2.sol

44:     function setRecipient(address newRecipient) external onlyOwner {

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

96:     function setBatchMinter(address newBatchMinter) external onlyOwner {

105:     function setNudgeStreamer(address newStreamer) external onlyOwner {

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

89:     function setBatchMinter(address newBatchMinter) external onlyOwner {

97:     function setReleaser(address releaser, bool approved) external onlyOwner {

108:     function release(uint256 amount) external onlyReleaser nonReentrant {

118:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

264:     function setPool(address newPair) external onlyOwner {

283:     function setEthToPromotionPath(address[] calldata path) external onlyOwner {

294:     function setUsdcToWbtcPath(address[] calldata path) external onlyOwner {

304:     function setInsurer(address newInsurer) external onlyOwner {

312:     function withdrawWBTC(address to, uint256 amount) external onlyInsurer {

319:     function setPSM(address newPSM) external onlyOwner {

326:     function setMaxTin(uint256 newMaxTin) external onlyOwner {

333:     function setDonationSplit(uint256 newSplit) external onlyOwner {

341:     function setBatchMinter(address newBatchMinter) external onlyOwner {

348:     function setNudgeStreamer(address newStreamer) external onlyOwner {

356:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

368:     function incrementAuthVersion() external onlyOwner {

575:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

582:     function rescueETH(address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/Uniboost.sol

154:     function setPool(address newPool) external onlyOwner {

174:     function setDonationSplit(uint256 newSplit) external onlyOwner {

183:     function setRecipient(address newRecipient) external onlyOwner {

190:     function setNudgeStreamer(address newStreamer) external onlyOwner {

202:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {

315:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

327:     function incrementAuthVersion() external onlyOwner {

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

77:     function setRatio(uint8 newRatio) external onlyOwner {

87:     function setRecipient(address newRecipient) external onlyOwner {

98:     function setDispatcher(address newDispatcher) external onlyOwner {

120:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

90:     function setRatio(uint8 newRatio) external onlyOwner {

100:     function setRecipient(address newRecipient) external onlyOwner {

111:     function setDispatcher(address newDispatcher) external onlyOwner {

136:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

96:     function setRatio(uint8 newRatio) external onlyOwner {

106:     function setRecipient(address newRecipient) external onlyOwner {

117:     function setDispatcher(address newDispatcher) external onlyOwner {

141:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

### <a name="GAS-13"></a>[GAS-13] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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
File: ./src/BurnRecorder.sol

67:         _latestIndex++;

```

```solidity
File: ./src/MultiPooler.sol

62:         for (uint256 i = 0; i < calls.length; i++) {

```

```solidity
File: ./src/NFTMinterV2.sol

133:         nextIndex++;

```

### <a name="GAS-14"></a>[GAS-14] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (16)*:
```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

82:     address public constant phUSD = 0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605;

84:     address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

86:     address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

88:     address public constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

90:     address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

92:     address public constant BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

94:     address public constant BALANCER_POOL = 0x642BB6860b4776CC10b26B8f361Fd139E7f0db04;

96:     address public constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

100:     address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

24:     uint8 public constant MAX_RATIO = 50;

27:     uint8 public constant DEFAULT_RATIO = 50;

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

25:     uint8 public constant MAX_RATIO = 200;

28:     uint8 public constant DEFAULT_RATIO = 100;

31:     bytes32 public constant HOOK_TYPE_ID = keccak256("NudgeRatchetMintDebtHook.v1");

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

31:     uint8 public constant MAX_RATIO = 50;

34:     uint8 public constant DEFAULT_RATIO = 50;

```

### <a name="GAS-15"></a>[GAS-15] Use shift right/left instead of division/multiplication if possible
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

*Instances (2)*:
```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

451:         uint256 phusdBurned = phusdAcquired / 2;

```

```solidity
File: ./src/dispatchers/Uniboost.sol

283:         uint256 half = pairBal / 2;

```

### <a name="GAS-16"></a>[GAS-16] Superfluous event fields
`block.timestamp` and `block.number` are added to event information by default so adding them manually wastes gas

*Instances (1)*:
```solidity
File: ./src/BurnRecorder.sol

28:     event tokenBurnt(address indexed token, uint256 quantity, uint256 timestamp);

```

### <a name="GAS-17"></a>[GAS-17] Use of `this` instead of marking as `public` an `external` function
Using `this.` is like making an expensive external call. Consider marking the called function as public

*Saves around 2000 gas per instance*

*Instances (1)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

290:                 try this._psmDonate(remainingUSDS) {}

```

### <a name="GAS-18"></a>[GAS-18] Increments/decrements can be unchecked in for-loops
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

*Instances (1)*:
```solidity
File: ./src/MultiPooler.sol

62:         for (uint256 i = 0; i < calls.length; i++) {

```

### <a name="GAS-19"></a>[GAS-19] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (16)*:
```solidity
File: ./src/MultiPooler.sol

61:         require(calls.length > 0, "MultiPooler: empty batch");

```

```solidity
File: ./src/NFTMinterV2.sol

301:         require(balance > 0, "NFTMinterV2: no tokens to withdraw");

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

274:         bool donationEnabled = batchMinter != address(0) && psm != address(0) && batchDonationSize > 0;

280:         if (poolingUSDS > 0) {

289:             if (remainingUSDS > 0) {

329:         if (gemAmt > 0) {

358:         require(sUSDSAmount > 0, "BalancerPoolerV2: nothing to pool");

371:         if (sUSDSAmount > 0) {

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

156:         if (bal > 0) {

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

384:         bool donationEnabled = batchMinter != address(0) && donationSplit > 0;

392:         if (donationAmount > 0) {

431:         require(amountIn > 0, "PromotionUniV2_Eth: nothing to pool");

```

```solidity
File: ./src/dispatchers/Uniboost.sol

238:         bool donationEnabled = recipient != address(0) && donationSplit > 0;

246:         if (donationAmount > 0) {

273:         require(amountIn > 0, "Uniboost: nothing to pool");

284:         if (half > 0) {

```

### <a name="GAS-20"></a>[GAS-20] WETH address definition can be use directly
WETH is a wrap Ether contract with a specific address in the Ethereum network, giving the option to define it may cause false recognition, it is healthier to define it directly.

    Advantages of defining a specific contract directly:
    
    It saves gas,
    Prevents incorrect argument definition,
    Prevents execution on a different chain and re-signature issues,
    WETH Address : 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

*Instances (1)*:
```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

90:     address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 2 |
| [NC-2](#NC-2) | Missing checks for `address(0)` when assigning values to address state variables | 11 |
| [NC-3](#NC-3) | Array indices should be referenced via `enum`s rather than via numeric literals | 21 |
| [NC-4](#NC-4) | Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked` | 1 |
| [NC-5](#NC-5) | Constants should be in CONSTANT_CASE | 2 |
| [NC-6](#NC-6) | `constant`s should be defined rather than using magic numbers | 22 |
| [NC-7](#NC-7) | Control structures do not follow the Solidity Style Guide | 17 |
| [NC-8](#NC-8) | Consider disabling `renounceOwnership()` | 7 |
| [NC-9](#NC-9) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 26 |
| [NC-10](#NC-10) | Event missing indexed field | 22 |
| [NC-11](#NC-11) | Events that mark critical parameter changes should contain both the old and the new value | 47 |
| [NC-12](#NC-12) | Function ordering does not follow the Solidity style guide | 5 |
| [NC-13](#NC-13) | Functions should not be longer than 50 lines | 163 |
| [NC-14](#NC-14) | Change int to int256 | 2 |
| [NC-15](#NC-15) | Lack of checks in setters | 18 |
| [NC-16](#NC-16) | Missing Event for critical parameters change | 5 |
| [NC-17](#NC-17) | Incomplete NatSpec: `@param` is missing on actually documented functions | 13 |
| [NC-18](#NC-18) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 21 |
| [NC-19](#NC-19) | Constant state variables defined more than once | 10 |
| [NC-20](#NC-20) | Consider using named mappings | 12 |
| [NC-21](#NC-21) | `address`s shouldn't be hard-coded | 10 |
| [NC-22](#NC-22) | Owner can renounce while system is paused | 1 |
| [NC-23](#NC-23) | Adding a `return` statement when the function defines a named return variable, is redundant | 1 |
| [NC-24](#NC-24) | Take advantage of Custom Error's return value property | 12 |
| [NC-25](#NC-25) | Strings should use double quotes rather than single quotes | 4 |
| [NC-26](#NC-26) | Contract does not follow the Solidity style guide's suggested layout ordering | 5 |
| [NC-27](#NC-27) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-28](#NC-28) | Internal and private variables and functions names should begin with an underscore | 2 |
| [NC-29](#NC-29) | Event is missing `indexed` fields | 49 |
| [NC-30](#NC-30) | Constants should be defined rather than using magic numbers | 2 |
| [NC-31](#NC-31) | `public` functions not called by the contract should be declared `external` instead | 3 |
| [NC-32](#NC-32) | Variables need not be initialized to zero | 1 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (2)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

360:         bytes memory data = abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, innerData);

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

535:             IBalancerVault(BALANCER_VAULT).unlock(abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, inner));

```

### <a name="NC-2"></a>[NC-2] Missing checks for `address(0)` when assigning values to address state variables

*Instances (11)*:
```solidity
File: ./src/NFTMinterV2.sol

106:         pauser = newPauser;

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

86:         _minter = minter_;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

154:         _vault = vault_;

155:         _router = router_;

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

18:         _token = token_;

```

```solidity
File: ./src/dispatchers/GatherV2.sol

28:         _token = token_;

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

85:         _token = token_;

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

79:         _token = token_;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

343:         emit BatchMinterSet(newBatchMinter);

```

```solidity
File: ./src/dispatchers/Uniboost.sol

167:         _pairToken = pairToken_;

184:         recipient = newRecipient;

```

### <a name="NC-3"></a>[NC-3] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (21)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

379:                 maxAmountsIn[1] = 0;

380:             } else {

382:                 maxAmountsIn[1] = actualInVault;

383:             }

412:             exactAmountsIn[1] = 0;

413:         } else {

415:             exactAmountsIn[1] = sUSDSAmount;

416:         }

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

241:             return path;

243:         return _ethToPromotionPath;

253:             return path;

255:         return _usdcToWbtcPath;

286:         require(path[path.length - 1] == promotionToken, "PromotionUniV2_Eth: path end not promotion");

297:         require(path[path.length - 1] == WBTC, "PromotionUniV2_Eth: path end not WBTC");

503:         IERC20(USDC).forceApprove(UNIV2_ROUTER, usdcAmount);

504:         IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForETH(

```

```solidity
File: ./src/dispatchers/Uniboost.sol

204:         require(path[0] == _primeToken, "Uniboost: path start not prime");

215:             path[0] = _primeToken;

216:             path[1] = _pairToken;

286:             pairToTargetPath[0] = _pairToken;

287:             pairToTargetPath[1] = targetToken;

```

### <a name="NC-4"></a>[NC-4] Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked`
Solidity version 0.8.4 introduces `bytes.concat()` (vs `abi.encodePacked(<bytes>,<bytes>)`)

Solidity version 0.8.12 introduces `string.concat()` (vs `abi.encodePacked(<str>,<str>), which catches concatenation errors (in the event of a `bytes` data mixed in the concatenation)`)

*Instances (1)*:
```solidity
File: ./src/NFTMinterV2.sol

263:             abi.encodePacked(

```

### <a name="NC-5"></a>[NC-5] Constants should be in CONSTANT_CASE
For `constant` variable names, each word should use all capital letters, with underscores separating each word (CONSTANT_CASE)

*Instances (2)*:
```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

82:     address public constant phUSD = 0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605;

88:     address public constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

```

### <a name="NC-6"></a>[NC-6] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (22)*:
```solidity
File: ./src/NFTMinterV2.sol

188:         config.price = price + (price * config.growthBasisPoints) / 10000;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

211:         require(newSize <= 100, "BalancerPoolerV2: size > 100");

276:         uint256 donationUSDS = donationEnabled ? (amount * batchDonationSize) / 100 : 0;

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

84:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

76:             IERC20Metadata(token_).decimals() == 6,

77:             "NudgeRatchetDelayRelease: token must be 6-decimal USDC"

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

284:         require(path.length >= 2, "PromotionUniV2_Eth: path too short");

295:         require(path.length >= 2, "PromotionUniV2_Eth: path too short");

334:         require(newSplit <= 100, "PromotionUniV2_Eth: split > 100");

385:         uint256 donationAmount = donationEnabled ? (amount * donationSplit) / 100 : 0;

439:             uint256 amountA = (amountIn * 60) / 100; // phUSD leg

440:             uint256 amountB = (amountIn * 30) / 100; // promotion leg

451:         uint256 phusdBurned = phusdAcquired / 2;

```

```solidity
File: ./src/dispatchers/Uniboost.sol

175:         require(newSplit <= 100, "Uniboost: split > 100");

203:         require(path.length >= 2, "Uniboost: path too short");

239:         uint256 donationAmount = donationEnabled ? (amount * donationSplit) / 100 : 0;

283:         uint256 half = pairBal / 2;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

111:         uint256 added = (amount * ratio) / 100;

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

127:         uint256 added = (amount * USDC_TO_PHUSD_SCALE * ratio) / 100;

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

86:         require(d <= 18, "decimals>18");

89:         scale = 10 ** (18 - d);

132:         uint256 added = (amount * scale * ratio) / 100;

```

### <a name="NC-7"></a>[NC-7] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (17)*:
```solidity
File: ./src/NFTMinterV2.sol

24:         bool disabled; // if true, new mints are blocked but existing NFTs remain valid

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

407:         if (sUSDSAmount == 0) return 0;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

78:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

110:         if (msg.sender != dispatcher) revert OnlyDispatcher();

112:         if (added == 0) return;

121:         if (recipient == address(0)) revert RecipientUnset();

123:         if (debt == 0) return;

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

91:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

123:         if (msg.sender != dispatcher) revert OnlyDispatcher();

128:         if (added == 0) return;

137:         if (recipient == address(0)) revert RecipientUnset();

139:         if (debt == 0) return;

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

97:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

129:         if (msg.sender != dispatcher) revert OnlyDispatcher();

133:         if (added == 0) return;

142:         if (recipient == address(0)) revert RecipientUnset();

144:         if (debt == 0) return;

```

### <a name="NC-8"></a>[NC-8] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (7)*:
```solidity
File: ./src/BurnRecorder.sol

11: contract BurnRecorder is IBurnRecorder, Ownable {

```

```solidity
File: ./src/MultiPooler.sol

18: contract MultiPooler is Ownable {

```

```solidity
File: ./src/NFTMinterV2.sol

16: contract NFTMinterV2 is ERC1155Supply, Ownable, INFTMinterV2, IPausable {

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

23: abstract contract ATokenDispatcherV2 is ITokenDispatcherV2, Pausable, Ownable, ReentrancyGuard {

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

22: contract BalancerPoolerMintDebtHook is IDispatchHook, IBalancerPoolerMintDebtHook, Ownable, ReentrancyGuard {

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

22: contract NudgeRatchetMintDebtHook is IDispatchHook, INudgeRatchetMintDebtHook, Ownable, ReentrancyGuard {

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

29: contract UniboostMintDebtHook is IDispatchHook, IUniboostMintDebtHook, Ownable, ReentrancyGuard {

```

### <a name="NC-9"></a>[NC-9] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (26)*:
```solidity
File: ./src/NFTMinterV2.sol

112:         require(msg.sender == pauser, "Only pauser");

119:         require(msg.sender == pauser, "Only pauser");

153:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

173:         require(config.dispatcher != address(0), "NFTMinterV2: index not registered");

208:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

228:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

277:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

283:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

291:         require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");

```

```solidity
File: ./src/dispatchers/GatherV2.sol

27:         require(recipient_ != address(0), "GatherV2: zero recipient address");

45:         require(newRecipient != address(0), "GatherV2: zero recipient address");

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

82:         require(batchMinter_ != address(0), "NudgeRatchet: zero batchMinter");

97:         require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

73:         require(batchMinter_ != address(0), "NudgeRatchetDelayRelease: zero batchMinter");

90:         require(newBatchMinter != address(0), "NudgeRatchetDelayRelease: zero batchMinter");

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

285:         require(path[0] == WETH, "PromotionUniV2_Eth: path start not WETH");

296:         require(path[0] == USDC, "PromotionUniV2_Eth: path start not USDC");

314:         IERC20(WBTC).safeTransfer(to, amount);

577:         require(token != WBTC, "PromotionUniV2_Eth: WBTC is insurer-only");

585:         require(ok, "PromotionUniV2_Eth: eth rescue failed");

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

67:         require(dispatcher_ != address(0), "dispatcher=0");

99:         require(newDispatcher != address(0), "dispatcher=0");

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

79:         require(dispatcher_ != address(0), "dispatcher=0");

112:         require(newDispatcher != address(0), "dispatcher=0");

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

82:         require(dispatcher_ != address(0), "dispatcher=0");

118:         require(newDispatcher != address(0), "dispatcher=0");

```

### <a name="NC-10"></a>[NC-10] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (22)*:
```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

38:     event MetadataUpdated(string name, string image, string description);

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

115:     event AuthVersionIncremented(uint256 newAuthVersion);

118:     event BatchDonationSizeSet(uint256 newSize);

119:     event BatchMinterSet(address newBatchMinter);

120:     event PSMSet(address newPSM);

121:     event MaxToutSet(uint256 newMaxTout);

134:     event DonationSkipped(uint256 usdsParked);

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

173:     /// @notice Emitted once per `pool()`. Consolidates the full 60/30/10 outcome.

185:     event BatchMinterSet(address newBatchMinter);

186:     event NudgeStreamerUpdated(address indexed oldStreamer, address indexed newStreamer);

188:     event MaxTinSet(uint256 newMaxTin);

189:     event EthToPromotionPathSet(address[] path);

190:     event UsdcToWbtcPathSet(address[] path);

191:     event InsurerSet(address newInsurer);

192:     event WBTCWithdrawn(address indexed to, uint256 amount);

```

```solidity
File: ./src/dispatchers/Uniboost.sol

96:     event AuthVersionIncremented(uint256 newAuthVersion);

100:     event DonationSplitSet(uint256 newSplit);

101:     event RecipientSet(address newRecipient);

103:     event PrimeToPairPathSet(address[] path);

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

45:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

57:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

58:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

```

### <a name="NC-11"></a>[NC-11] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (47)*:
```solidity
File: ./src/MultiPooler.sol

50:     function setPooler(address newPooler) external onlyOwner {
            address oldPooler = pooler;
            pooler = newPooler;
            emit PoolerSet(oldPooler, newPooler);

```

```solidity
File: ./src/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {
             address oldPauser = pauser;
             pauser = newPauser;
             emit PauserChanged(oldPauser, newPauser);

152:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {
             require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");
             configs[index].disabled = disabled;
             emit DispatcherDisabledChanged(index, disabled);

219:     function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
             authorizedMinters[minter] = authorized;
             emit AuthorizedMinterSet(minter, authorized);

282:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {
             require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");
             uint256 oldPrice = configs[index].price;
             configs[index].price = newPrice;
             emit PriceUpdated(index, oldPrice, newPrice);

290:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {
             require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");
             uint256 oldGrowthBasisPoints = configs[index].growthBasisPoints;
             configs[index].growthBasisPoints = newGrowthBasisPoints;
             emit GrowthFactorUpdated(index, oldGrowthBasisPoints, newGrowthBasisPoints);

309:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {
             require(dispatcherToIndex[dispatcher] != 0, "NFTMinterV2: dispatcher not registered");
     
             ATokenDispatcherV2 dispatcherContract = ATokenDispatcherV2(dispatcher);
     
             if (active) {
                 // Only unpause if currently paused, to avoid revert from ExpectedPause()
                 if (dispatcherContract.paused()) {
                     dispatcherContract.unpause();
                 }
             } else {
                 // Only pause if currently not paused, to avoid revert from EnforcedPause()
                 if (!dispatcherContract.paused()) {
                     dispatcherContract.pause();
                 }
             }
     
             emit DispatcherActiveChanged(dispatcher, active);

332:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {
             authorizedBurners[burner] = authorized;
             emit AuthorizedBurnerSet(burner, authorized);

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

58:     function setMetadata(string calldata name_, string calldata image_, string calldata description_)
            external
            onlyOwner
        {
            _name = name_;
            _image = image_;
            _description = description_;
            emit MetadataUpdated(name_, image_, description_);

94:     function setHook(IDispatchHook newHook) external onlyOwner {
            require(address(newHook) != address(0), "ATokenDispatcherV2: zero hook");
            address oldHook = address(hook);
            hook = newHook;
            emit HookUpdated(oldHook, address(newHook));

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

190:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "BalancerPoolerV2: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);
             } else {
                 delete poolerAuthVersion[pooler];
                 emit PoolerDeauthorized(pooler);

190:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "BalancerPoolerV2: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);

210:     function setBatchDonationSize(uint256 newSize) external onlyOwner {
             require(newSize <= 100, "BalancerPoolerV2: size > 100");
             batchDonationSize = newSize;
             emit BatchDonationSizeSet(newSize);

219:     function setBatchMinter(address newBatchMinter) external onlyOwner {
             batchMinter = newBatchMinter;
             emit BatchMinterSet(newBatchMinter);

227:     function setPSM(address newPSM) external onlyOwner {
             require(newPSM != address(0), "BalancerPoolerV2: zero psm");
             psm = newPSM;
             emit PSMSet(newPSM);
         }

235:     function setMaxTout(uint256 newMaxTout) external onlyOwner {
             maxTout = newMaxTout;
             emit MaxToutSet(newMaxTout);

246:     function setNudgeStreamer(address newStreamer) external onlyOwner {
             require(newStreamer != address(0), "BalancerPoolerV2: zero nudgeStreamer");
             address old = nudgeStreamer;
             nudgeStreamer = newStreamer;
             emit NudgeStreamerUpdated(old, newStreamer);

```

```solidity
File: ./src/dispatchers/GatherV2.sol

44:     function setRecipient(address newRecipient) external onlyOwner {
            require(newRecipient != address(0), "GatherV2: zero recipient address");
            address oldRecipient = _recipient;
            _recipient = newRecipient;
            emit RecipientUpdated(oldRecipient, newRecipient);

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

96:     function setBatchMinter(address newBatchMinter) external onlyOwner {
            require(newBatchMinter != address(0), "NudgeRatchet: zero batchMinter");
            address old = batchMinter;
            batchMinter = newBatchMinter;
            emit BatchMinterUpdated(old, newBatchMinter);

105:     function setNudgeStreamer(address newStreamer) external onlyOwner {
             require(newStreamer != address(0), "NudgeRatchet: zero nudgeStreamer");
             address old = nudgeStreamer;
             nudgeStreamer = newStreamer;
             emit NudgeStreamerUpdated(old, newStreamer);

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

89:     function setBatchMinter(address newBatchMinter) external onlyOwner {
            require(newBatchMinter != address(0), "NudgeRatchetDelayRelease: zero batchMinter");
            address old = batchMinter;
            batchMinter = newBatchMinter;
            emit BatchMinterUpdated(old, newBatchMinter);

97:     function setReleaser(address releaser, bool approved) external onlyOwner {
            releasers[releaser] = approved;
            emit ReleaserUpdated(releaser, approved);

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

283:     function setEthToPromotionPath(address[] calldata path) external onlyOwner {
             require(path.length >= 2, "PromotionUniV2_Eth: path too short");
             require(path[0] == WETH, "PromotionUniV2_Eth: path start not WETH");
             require(path[path.length - 1] == promotionToken, "PromotionUniV2_Eth: path end not promotion");
             _ethToPromotionPath = path;
             emit EthToPromotionPathSet(path);
         }
     
         /// @notice Sets a custom routing path for the USDC → WBTC swap performed in `pool()` (Leg C).

294:     function setUsdcToWbtcPath(address[] calldata path) external onlyOwner {
             require(path.length >= 2, "PromotionUniV2_Eth: path too short");
             require(path[0] == USDC, "PromotionUniV2_Eth: path start not USDC");
             require(path[path.length - 1] == WBTC, "PromotionUniV2_Eth: path end not WBTC");
             _usdcToWbtcPath = path;
             emit UsdcToWbtcPathSet(path);
         }
     
         /// @notice Sets the insurance-reserve role permitted to withdraw WBTC. Must be non-zero.

305:         require(newInsurer != address(0), "PromotionUniV2_Eth: zero insurer");
             insurer = newInsurer;
             emit InsurerSet(newInsurer);
         }
     
         /// @notice Withdraws `amount` (WBTC, 8dp) of the insurance reserve to `to`. Insurer only.

320:         require(newPSM != address(0), "PromotionUniV2_Eth: zero psm");
             psm = newPSM;
             emit PSMSet(newPSM);
         }
     
         /// @notice Sets the WAD-scaled ceiling on the PSM `tin` accepted for Leg A. Only callable by owner.

327:         maxTin = newMaxTin;
             emit MaxTinSet(newMaxTin);
         }
     
         /// @notice Sets the donation percentage (0..100) of each dispatched USDC forwarded to

334:         require(newSplit <= 100, "PromotionUniV2_Eth: split > 100");
             donationSplit = newSplit;
             emit DonationSplitSet(newSplit);
         }
     
         /// @notice Sets the donation recipient. address(0) is allowed and disables the donation even if

342:         batchMinter = newBatchMinter;
             emit BatchMinterSet(newBatchMinter);
         }
     
         /// @notice Updates the NudgeStreamer donations are routed through. Only callable by owner.

349:         require(newStreamer != address(0), "PromotionUniV2_Eth: zero nudgeStreamer");
             address old = nudgeStreamer;
             nudgeStreamer = newStreamer;
             emit NudgeStreamerUpdated(old, newStreamer);
         }
     
         /// @notice Sets or revokes an authorized pooler. Only callable by owner.

356:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "PromotionUniV2_Eth: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);
             } else {
                 delete poolerAuthVersion[pooler];
                 emit PoolerDeauthorized(pooler);
             }
         }
     
         /// @notice Increments the auth version, mass-revoking all current pooler authorizations.

356:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "PromotionUniV2_Eth: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);
             } else {
                 delete poolerAuthVersion[pooler];

```

```solidity
File: ./src/dispatchers/Uniboost.sol

174:     function setDonationSplit(uint256 newSplit) external onlyOwner {
             require(newSplit <= 100, "Uniboost: split > 100");
             donationSplit = newSplit;
             emit DonationSplitSet(newSplit);

183:     function setRecipient(address newRecipient) external onlyOwner {
             recipient = newRecipient;
             emit RecipientSet(newRecipient);

190:     function setNudgeStreamer(address newStreamer) external onlyOwner {
             require(newStreamer != address(0), "Uniboost: zero nudgeStreamer");
             address old = nudgeStreamer;
             nudgeStreamer = newStreamer;
             emit NudgeStreamerUpdated(old, newStreamer);

202:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {
             require(path.length >= 2, "Uniboost: path too short");
             require(path[0] == _primeToken, "Uniboost: path start not prime");
             require(path[path.length - 1] == _pairToken, "Uniboost: path end not pair");
             _primeToPairPath = path;
             emit PrimeToPairPathSet(path);

315:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "Uniboost: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);
             } else {
                 delete poolerAuthVersion[pooler];
                 emit PoolerDeauthorized(pooler);

315:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "Uniboost: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

77:     function setRatio(uint8 newRatio) external onlyOwner {
            if (newRatio > MAX_RATIO) revert RatioTooHigh();
            uint8 old = ratio;
            ratio = newRatio;
            emit RatioUpdated(old, newRatio);

87:     function setRecipient(address newRecipient) external onlyOwner {
            address old = recipient;
            recipient = newRecipient;
            emit RecipientUpdated(old, newRecipient);

98:     function setDispatcher(address newDispatcher) external onlyOwner {
            require(newDispatcher != address(0), "dispatcher=0");
            address old = dispatcher;
            dispatcher = newDispatcher;
            emit DispatcherUpdated(old, newDispatcher);

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

90:     function setRatio(uint8 newRatio) external onlyOwner {
            if (newRatio > MAX_RATIO) revert RatioTooHigh();
            uint8 old = ratio;
            ratio = newRatio;
            emit RatioUpdated(old, newRatio);

100:     function setRecipient(address newRecipient) external onlyOwner {
             address old = recipient;
             recipient = newRecipient;
             emit RecipientUpdated(old, newRecipient);

111:     function setDispatcher(address newDispatcher) external onlyOwner {
             require(newDispatcher != address(0), "dispatcher=0");
             address old = dispatcher;
             dispatcher = newDispatcher;
             emit DispatcherUpdated(old, newDispatcher);

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

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

### <a name="NC-12"></a>[NC-12] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (5)*:
```solidity
File: ./src/BurnRecorder.sol

1: 
   Current order:
   external setBurner
   external burn
   public getTotalBurnt
   external registerToken
   public getTokenCount
   public getTokenAtIndex
   
   Suggested order:
   external setBurner
   external burn
   external registerToken
   public getTotalBurnt
   public getTokenCount
   public getTokenAtIndex

```

```solidity
File: ./src/NFTMinterV2.sol

1: 
   Current order:
   external setPauser
   external pause
   external unpause
   external registerDispatcher
   external setDispatcherDisabled
   external mint
   external mint
   internal _executeMint
   external mintFor
   external setAuthorizedMinter
   external replaceDispatcher
   public uri
   external getPrice
   external setPrice
   external setGrowthFactor
   external emergencyWithdraw
   external setDispatcherActive
   external setAuthorizedBurner
   external burn
   
   Suggested order:
   external setPauser
   external pause
   external unpause
   external registerDispatcher
   external setDispatcherDisabled
   external mint
   external mint
   external mintFor
   external setAuthorizedMinter
   external replaceDispatcher
   external getPrice
   external setPrice
   external setGrowthFactor
   external emergencyWithdraw
   external setDispatcherActive
   external setAuthorizedBurner
   external burn
   public uri
   internal _executeMint

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

1: 
   Current order:
   external primeToken
   external sUSDS
   external vault
   external pool
   external setPool
   external setAuthorizedPooler
   external incrementAuthVersion
   external setBatchDonationSize
   external setBatchMinter
   external setPSM
   external setMaxTout
   external setNudgeStreamer
   internal _dispatch
   external _psmDonate
   external pool
   external unlockCallback
   external getIdealBPT
   external withdrawBPT
   external rescueERC20
   
   Suggested order:
   external primeToken
   external sUSDS
   external vault
   external pool
   external setPool
   external setAuthorizedPooler
   external incrementAuthVersion
   external setBatchDonationSize
   external setBatchMinter
   external setPSM
   external setMaxTout
   external setNudgeStreamer
   external _psmDonate
   external pool
   external unlockCallback
   external getIdealBPT
   external withdrawBPT
   external rescueERC20
   internal _dispatch

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

1: 
   Current order:
   external primeToken
   external targetPool
   public ethToPromotionPath
   public usdcToWbtcPath
   external setPool
   internal _setPool
   external setEthToPromotionPath
   external setUsdcToWbtcPath
   external setInsurer
   external withdrawWBTC
   external setPSM
   external setMaxTin
   external setDonationSplit
   external setBatchMinter
   external setNudgeStreamer
   external setAuthorizedPooler
   external incrementAuthVersion
   internal _dispatch
   external pool
   internal _addPhusdPromoLiquidity
   internal _legA
   internal _legB
   internal _legC
   internal _swapSusdsForPhusd
   external unlockCallback
   external rescueERC20
   external rescueETH
   
   Suggested order:
   external primeToken
   external targetPool
   external setPool
   external setEthToPromotionPath
   external setUsdcToWbtcPath
   external setInsurer
   external withdrawWBTC
   external setPSM
   external setMaxTin
   external setDonationSplit
   external setBatchMinter
   external setNudgeStreamer
   external setAuthorizedPooler
   external incrementAuthVersion
   external pool
   external unlockCallback
   external rescueERC20
   external rescueETH
   public ethToPromotionPath
   public usdcToWbtcPath
   internal _setPool
   internal _dispatch
   internal _addPhusdPromoLiquidity
   internal _legA
   internal _legB
   internal _legC
   internal _swapSusdsForPhusd

```

```solidity
File: ./src/dispatchers/Uniboost.sol

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
   external setNudgeStreamer
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
   external setNudgeStreamer
   external setPrimeToPairPath
   external pool
   external setAuthorizedPooler
   external incrementAuthVersion
   external rescueERC20
   public primeToPairPath
   internal _setPool
   internal _dispatch

```

### <a name="NC-13"></a>[NC-13] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (163)*:
```solidity
File: ./src/BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {

50:     function burn(address token, uint256 amount) external onlyBurner {

58:     function getTotalBurnt(address token) public view returns (uint256) {

65:     function registerToken(address token) external onlyOwner {

72:     function getTokenCount() public view returns (uint256) {

79:     function getTokenAtIndex(uint256 index) public view returns (address) {

```

```solidity
File: ./src/MultiPooler.sol

50:     function setPooler(address newPooler) external onlyOwner {

60:     function pool(PoolCall[] calldata calls) external onlyPooler {

```

```solidity
File: ./src/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {

125:     function registerDispatcher(address dispatcher, uint256 initialPrice, uint256 growthBasisPoints)

152:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {

159:     function mint(uint256 index, address recipient) external returns (bool) {

164:     function mint(uint256 index, address recipient, bytes calldata extraData) external returns (bool) {

170:     function _executeMint(uint256 index, address recipient, bytes memory extraData) internal returns (bool) {

206:     function mintFor(uint256 index, address recipient) external {

219:     function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {

227:     function replaceDispatcher(uint256 index, address newDispatcher) external onlyOwner {

252:     function uri(uint256 id) public view override returns (string memory) {

276:     function getPrice(uint256 index) external view returns (uint256) {

282:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {

290:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {

299:     function emergencyWithdraw(address token) external onlyOwner {

309:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {

332:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {

341:     function burn(address holder, uint256 tokenId, uint256 quantity) external {

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

58:     function setMetadata(string calldata name_, string calldata image_, string calldata description_)

69:     function name() external view returns (string memory) {

74:     function image() external view returns (string memory) {

79:     function description() external view returns (string memory) {

85:     function setMinter(address minter_) external onlyOwner {

94:     function setHook(IDispatchHook newHook) external onlyOwner {

118:     function dispatch(address minter, uint256 amount, bytes calldata extraData)

132:     function _dispatch(address minter, uint256 amount, bytes calldata extraData) internal virtual {}

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

161:     function primeToken() external view override returns (address) {

166:     function sUSDS() external view returns (address) {

171:     function vault() external view returns (address) {

182:     function setPool(address newPool) external onlyOwner {

190:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

202:     function incrementAuthVersion() external onlyOwner {

210:     function setBatchDonationSize(uint256 newSize) external onlyOwner {

219:     function setBatchMinter(address newBatchMinter) external onlyOwner {

227:     function setPSM(address newPSM) external onlyOwner {

235:     function setMaxTout(uint256 newMaxTout) external onlyOwner {

246:     function setNudgeStreamer(address newStreamer) external onlyOwner {

309:     function _psmDonate(uint256 usdsAmount) external {

356:     function pool(uint256 minBPT) external onlyAuthorizedPooler whenNotPaused nonReentrant {

365:     function unlockCallback(bytes calldata data) external returns (bytes memory) {

405:     function getIdealBPT() external returns (uint256 bptAmountOut) {

424:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

437:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

23:     function primeToken() external view returns (address) {

```

```solidity
File: ./src/dispatchers/GatherV2.sol

33:     function primeToken() external view returns (address) {

38:     function recipient() external view returns (address) {

44:     function setRecipient(address newRecipient) external onlyOwner {

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

90:     function primeToken() external view returns (address) {

96:     function setBatchMinter(address newBatchMinter) external onlyOwner {

105:     function setNudgeStreamer(address newStreamer) external onlyOwner {

134:     function _dispatch(address, uint256 amount, bytes calldata /* extraData */) internal override {

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

84:     function primeToken() external view returns (address) {

89:     function setBatchMinter(address newBatchMinter) external onlyOwner {

97:     function setReleaser(address releaser, bool approved) external onlyOwner {

108:     function release(uint256 amount) external onlyReleaser nonReentrant {

118:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

131:     function _dispatch(address, uint256 /* amount */, bytes calldata /* extraData */)

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

226:     function primeToken() external pure override returns (address) {

231:     function targetPool() external view returns (address) {

236:     function ethToPromotionPath() public view returns (address[] memory) {

248:     function usdcToWbtcPath() public view returns (address[] memory) {

264:     function setPool(address newPair) external onlyOwner {

283:     function setEthToPromotionPath(address[] calldata path) external onlyOwner {

294:     function setUsdcToWbtcPath(address[] calldata path) external onlyOwner {

304:     function setInsurer(address newInsurer) external onlyOwner {

312:     function withdrawWBTC(address to, uint256 amount) external onlyInsurer {

319:     function setPSM(address newPSM) external onlyOwner {

326:     function setMaxTin(uint256 newMaxTin) external onlyOwner {

333:     function setDonationSplit(uint256 newSplit) external onlyOwner {

341:     function setBatchMinter(address newBatchMinter) external onlyOwner {

348:     function setNudgeStreamer(address newStreamer) external onlyOwner {

356:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

368:     function incrementAuthVersion() external onlyOwner {

383:     function _dispatch(address, uint256 amount, bytes calldata /* extraData */ ) internal override {

463:     function _addPhusdPromoLiquidity(uint256 minLP) internal returns (uint256 liquidity) {

480:     function _legA(uint256 usdcAmount, uint256 minPhusdOut) internal returns (uint256 phusdOut) {

499:     function _legB(uint256 usdcAmount, uint256 minEthOut, uint256 minPromoOut) internal {

521:     function _legC(uint256 usdcAmount, uint256 minWbtcOut) internal returns (uint256 wbtcOut) {

532:     function _swapSusdsForPhusd(uint256 sharesIn, uint256 minPhusdOut) internal returns (uint256) {

547:     function unlockCallback(bytes calldata data) external override returns (bytes memory) {

575:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

582:     function rescueETH(address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/Uniboost.sol

133:     function primeToken() external view override returns (address) {

138:     function router() external view returns (address) {

143:     function targetPool() external view returns (address) {

148:     function pairToken() external view returns (address) {

154:     function setPool(address newPool) external onlyOwner {

174:     function setDonationSplit(uint256 newSplit) external onlyOwner {

183:     function setRecipient(address newRecipient) external onlyOwner {

190:     function setNudgeStreamer(address newStreamer) external onlyOwner {

202:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {

212:     function primeToPairPath() public view returns (address[] memory) {

266:     function pool(uint256 amountIn, uint256 minPairOut, uint256 minTargetOut, uint256 minLP)

315:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

327:     function incrementAuthVersion() external onlyOwner {

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

77:     function setRatio(uint8 newRatio) external onlyOwner {

87:     function setRecipient(address newRecipient) external onlyOwner {

98:     function setDispatcher(address newDispatcher) external onlyOwner {

109:     function onDispatch(address minter, uint256 amount, bytes calldata) external {

120:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

```solidity
File: ./src/hooks/DefaultDispatchHook.sol

12:     function onDispatch(address, uint256, bytes calldata) external {}

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

90:     function setRatio(uint8 newRatio) external onlyOwner {

100:     function setRecipient(address newRecipient) external onlyOwner {

111:     function setDispatcher(address newDispatcher) external onlyOwner {

122:     function onDispatch(address minter, uint256 amount, bytes calldata) external {

136:     function pull() external onlyOwnerOrRecipient nonReentrant {

146:     function hookTypeId() external pure returns (bytes32) {

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

96:     function setRatio(uint8 newRatio) external onlyOwner {

106:     function setRecipient(address newRecipient) external onlyOwner {

117:     function setDispatcher(address newDispatcher) external onlyOwner {

128:     function onDispatch(address minter, uint256 amount, bytes calldata) external {

141:     function pull() external onlyOwnerOrRecipient nonReentrant {

```

```solidity
File: ./src/interfaces/IBalancerPoolerMintDebtHook.sol

10:     function mintDebt() external view returns (uint256);

```

```solidity
File: ./src/interfaces/IBurnRecorder.sol

8:     function burn(address token, uint256 amount) external;

13:     function setBurner(address burner_, bool approved_) external;

```

```solidity
File: ./src/interfaces/IDispatchHook.sol

11:     function onDispatch(address minter, uint256 amount, bytes calldata extraData) external;

```

```solidity
File: ./src/interfaces/IMintable.sol

5:     function mint(address recipient, uint256 amount) external;

```

```solidity
File: ./src/interfaces/INFTMinterV2.sol

16:     function burn(address holder, uint256 tokenId, uint256 quantity) external;

21:     function authorizedBurners(address burner) external view returns (bool);

26:     function setAuthorizedBurner(address burner, bool authorized) external;

33:     function authorizedMinters(address minter) external view returns (bool);

38:     function setAuthorizedMinter(address minter, bool authorized) external;

43:     function mintFor(uint256 index, address recipient) external;

50:     function replaceDispatcher(uint256 index, address newDispatcher) external;

61:     function setDispatcherDisabled(uint256 index, bool disabled) external;

65:     function emergencyWithdraw(address token) external;

70:     function setDispatcherActive(address dispatcher, bool active) external;

78:     function nextIndex() external view returns (uint256);

94:     function dispatcherToIndex(address dispatcher) external view returns (uint256);

99:     function tokenIdToDispatcher(uint256 tokenId) external view returns (address);

```

```solidity
File: ./src/interfaces/INudgeRatchetMintDebtHook.sol

10:     function mintDebt() external view returns (uint256);

20:     function hookTypeId() external pure returns (bytes32);

```

```solidity
File: ./src/interfaces/IPhusdBurnable.sol

7:     function burn(address holder, uint256 amount) external;

```

```solidity
File: ./src/interfaces/ISkyPSM.sol

32:     function buyGem(address usr, uint256 gemAmt) external returns (uint256 usdsInWad);

36:     function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOutWad);

45:     function to18ConversionFactor() external view returns (uint256);

```

```solidity
File: ./src/interfaces/ITokenDispatcherV2.sol

6:     function primeToken() external view returns (address);

9:     function name() external view returns (string memory);

12:     function image() external view returns (string memory);

15:     function description() external view returns (string memory);

```

```solidity
File: ./src/interfaces/ITokenMinterV2.sol

9:     function mint(uint256 index, address recipient) external returns (bool);

16:     function mint(uint256 index, address recipient, bytes calldata extraData) external returns (bool);

22:     function registerDispatcher(address dispatcher, uint256 initialPrice, uint256 growthBasisPoints) external;

27:     function getPrice(uint256 index) external view returns (uint256);

32:     function setPrice(uint256 index, uint256 newPrice) external;

37:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external;

```

```solidity
File: ./src/interfaces/IUniboostMintDebtHook.sol

10:     function mintDebt() external view returns (uint256);

```

```solidity
File: ./src/interfaces/IUniboostPooler.sol

12:     function pool(uint256 amountIn, uint256 minPairOut, uint256 minTargetOut, uint256 minLP) external;

```

```solidity
File: ./src/interfaces/balancer/IBalancerVault.sol

8:     function unlock(bytes calldata data) external returns (bytes memory result);

9:     function addLiquidity(AddLiquidityParams memory params)

15:     function settle(IERC20 token, uint256 amountHint) external returns (uint256 credit);

16:     function sendTo(IERC20 token, address to, uint256 amount) external;

```

```solidity
File: ./src/interfaces/balancer/IUnlockCallback.sol

5:     function unlockCallback(bytes calldata data) external returns (bytes memory result);

```

```solidity
File: ./src/interfaces/uniswap/IUniswapV2Pair.sol

8:     function token0() external view returns (address);

9:     function token1() external view returns (address);

```

### <a name="NC-14"></a>[NC-14] Change int to int256
Throughout the code base, some variables are declared as `int`. To favor explicitness, consider changing all instances of `int` to `int256`

*Instances (2)*:
```solidity
File: ./src/NFTMinterV2.sol

22:         uint256 price; // current mint price in token units (18 decimals)

23:         uint256 growthBasisPoints; // price growth per mint in basis points (100 = 1%)

```

### <a name="NC-15"></a>[NC-15] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (18)*:
```solidity
File: ./src/BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {
            _burners[burner_] = approved_;

```

```solidity
File: ./src/MultiPooler.sol

50:     function setPooler(address newPooler) external onlyOwner {
            address oldPooler = pooler;
            pooler = newPooler;
            emit PoolerSet(oldPooler, newPooler);

```

```solidity
File: ./src/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {
             address oldPauser = pauser;
             pauser = newPauser;
             emit PauserChanged(oldPauser, newPauser);

219:     function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
             authorizedMinters[minter] = authorized;
             emit AuthorizedMinterSet(minter, authorized);

332:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {
             authorizedBurners[burner] = authorized;
             emit AuthorizedBurnerSet(burner, authorized);

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

58:     function setMetadata(string calldata name_, string calldata image_, string calldata description_)
            external
            onlyOwner
        {
            _name = name_;
            _image = image_;
            _description = description_;
            emit MetadataUpdated(name_, image_, description_);

85:     function setMinter(address minter_) external onlyOwner {
            _minter = minter_;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

219:     function setBatchMinter(address newBatchMinter) external onlyOwner {
             batchMinter = newBatchMinter;
             emit BatchMinterSet(newBatchMinter);

235:     function setMaxTout(uint256 newMaxTout) external onlyOwner {
             maxTout = newMaxTout;
             emit MaxToutSet(newMaxTout);

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

97:     function setReleaser(address releaser, bool approved) external onlyOwner {
            releasers[releaser] = approved;
            emit ReleaserUpdated(releaser, approved);

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

265:         _setPool(newPair);
         }
     
         /// @dev Validates the pair's token set equals `{phUSD, promotionToken}` (order-agnostic),

327:         maxTin = newMaxTin;
             emit MaxTinSet(newMaxTin);
         }
     
         /// @notice Sets the donation percentage (0..100) of each dispatched USDC forwarded to

342:         batchMinter = newBatchMinter;
             emit BatchMinterSet(newBatchMinter);
         }
     
         /// @notice Updates the NudgeStreamer donations are routed through. Only callable by owner.

```

```solidity
File: ./src/dispatchers/Uniboost.sol

154:     function setPool(address newPool) external onlyOwner {
             _setPool(newPool);

183:     function setRecipient(address newRecipient) external onlyOwner {
             recipient = newRecipient;
             emit RecipientSet(newRecipient);

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

87:     function setRecipient(address newRecipient) external onlyOwner {
            address old = recipient;
            recipient = newRecipient;
            emit RecipientUpdated(old, newRecipient);

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

100:     function setRecipient(address newRecipient) external onlyOwner {
             address old = recipient;
             recipient = newRecipient;
             emit RecipientUpdated(old, newRecipient);

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

106:     function setRecipient(address newRecipient) external onlyOwner {
             address old = recipient;
             recipient = newRecipient;
             emit RecipientUpdated(old, newRecipient);

```

### <a name="NC-16"></a>[NC-16] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (5)*:
```solidity
File: ./src/BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {
            _burners[burner_] = approved_;

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

85:     function setMinter(address minter_) external onlyOwner {
            _minter = minter_;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

182:     function setPool(address newPool) external onlyOwner {
             require(newPool != address(0), "BalancerPoolerV2: zero pool address");
             _pool = newPool;
         }

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

265:         _setPool(newPair);
         }
     
         /// @dev Validates the pair's token set equals `{phUSD, promotionToken}` (order-agnostic),

```

```solidity
File: ./src/dispatchers/Uniboost.sol

154:     function setPool(address newPool) external onlyOwner {
             _setPool(newPool);

```

### <a name="NC-17"></a>[NC-17] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (13)*:
```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

88:     /// @notice Updates the batchMinter sink. Only callable by the owner.
        function setBatchMinter(address newBatchMinter) external onlyOwner {

96:     /// @notice Adds (`approved == true`) or removes (`approved == false`) a releaser. Owner only.
        function setReleaser(address releaser, bool approved) external onlyOwner {

102:     /// @notice Releases `amount` of held USDC to the batchMinter. Only callable by a releaser.
         /// @dev Reverts (via SafeERC20) if `amount` exceeds the held balance. KNOWN/ACCEPTED (not a
         ///      finding): the mint-debt backing this USDC was already accrued in the hook at DISPATCH
         ///      time and may already have been realised as phUSD by the downstream staker. This call
         ///      only RELOCATES already-held backing to the sink at an admin-controlled rate; it is
         ///      intentionally independent of phUSD realisation and creates no unbacked phUSD.
         function release(uint256 amount) external onlyReleaser nonReentrant {

113:     /// @notice Owner escape hatch to recover ERC20s held by this contract. Mirrors
         ///         BalancerPoolerV2/Uniboost. NOT pause-gated, by design.
         /// @dev NOTE: this CAN withdraw held `_token` (USDC), which is backing for already-accrued
         ///      mint-debt. Using it on `_token` can leave debt under-backed and is an owner
         ///      responsibility; intended use is recovering non-`_token` assets sent here by mistake.
         function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

302:     /// @notice Sets the insurance-reserve role permitted to withdraw WBTC. Must be non-zero.
         ///         Only callable by owner.
         function setInsurer(address newInsurer) external onlyOwner {
             require(newInsurer != address(0), "PromotionUniV2_Eth: zero insurer");

310:     /// @notice Withdraws `amount` (WBTC, 8dp) of the insurance reserve to `to`. Insurer only.
         ///         Not pause-gated (escape-hatch convention); insurer-gated instead.
         function withdrawWBTC(address to, uint256 amount) external onlyInsurer {
             require(to != address(0), "PromotionUniV2_Eth: zero recipient");

318:     /// @notice Sets the Sky USDS↔USDC PSM used by Leg A. Must be non-zero. Only callable by owner.
         function setPSM(address newPSM) external onlyOwner {
             require(newPSM != address(0), "PromotionUniV2_Eth: zero psm");

325:     /// @notice Sets the WAD-scaled ceiling on the PSM `tin` accepted for Leg A. Only callable by owner.
         function setMaxTin(uint256 newMaxTin) external onlyOwner {
             maxTin = newMaxTin;
             emit MaxTinSet(newMaxTin);

331:     /// @notice Sets the donation percentage (0..100) of each dispatched USDC forwarded to
         ///         `batchMinter`. Setting 0 disables the donation. Only callable by owner.
         function setDonationSplit(uint256 newSplit) external onlyOwner {
             require(newSplit <= 100, "PromotionUniV2_Eth: split > 100");

339:     /// @notice Sets the donation recipient. address(0) is allowed and disables the donation even if
         ///         `donationSplit > 0`. Only callable by owner.
         function setBatchMinter(address newBatchMinter) external onlyOwner {
             batchMinter = newBatchMinter;

356:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "PromotionUniV2_Eth: zero pooler");

572:     ///         Also the LP-withdrawal mechanism (the LP token is the pair ERC20). WBTC is excluded:
         ///         the insurance reserve leaves only via the insurer-gated `withdrawWBTC`, never the
         ///         owner escape hatch. Not pause-gated.
         function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
             require(to != address(0), "PromotionUniV2_Eth: zero recipient");
             require(token != WBTC, "PromotionUniV2_Eth: WBTC is insurer-only");

582:     function rescueETH(address to, uint256 amount) external onlyOwner {
             require(to != address(0), "PromotionUniV2_Eth: zero recipient");
             (bool ok,) = to.call{value: amount}("");

```

### <a name="NC-18"></a>[NC-18] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (21)*:
```solidity
File: ./src/BurnRecorder.sol

32:         require(_burners[msg.sender], "BurnRecorder: caller is not burner");

```

```solidity
File: ./src/MultiPooler.sol

39:         require(msg.sender == pooler, "MultiPooler: caller not pooler");

```

```solidity
File: ./src/NFTMinterV2.sol

112:         require(msg.sender == pauser, "Only pauser");

119:         require(msg.sender == pauser, "Only pauser");

207:         require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");

342:         require(authorizedBurners[msg.sender], "NFTMinterV2: caller is not authorized burner");

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

45:         require(msg.sender == _minter, "ATokenDispatcherV2: caller is not minter");

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

137:         require(poolerAuthVersion[msg.sender] == authVersion, "BalancerPoolerV2: caller not authorized pooler");

310:         require(msg.sender == address(this), "BalancerPoolerV2: only self");

366:         require(msg.sender == _vault, "BalancerPoolerV2: caller is not vault");

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

63:         require(releasers[msg.sender], "NudgeRatchetDelayRelease: caller is not releaser");

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

195:         require(poolerAuthVersion[msg.sender] == authVersion, "PromotionUniV2_Eth: caller not authorized pooler");

200:         require(msg.sender == insurer, "PromotionUniV2_Eth: not insurer");

548:         require(msg.sender == BALANCER_VAULT, "PromotionUniV2_Eth: caller is not vault");

```

```solidity
File: ./src/dispatchers/Uniboost.sol

106:         require(poolerAuthVersion[msg.sender] == authVersion, "Uniboost: caller not authorized pooler");

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

57:         if (msg.sender != owner() && msg.sender != recipient) {

110:         if (msg.sender != dispatcher) revert OnlyDispatcher();

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

69:         if (msg.sender != owner() && msg.sender != recipient) {

123:         if (msg.sender != dispatcher) revert OnlyDispatcher();

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

70:         if (msg.sender != owner() && msg.sender != recipient) {

129:         if (msg.sender != dispatcher) revert OnlyDispatcher();

```

### <a name="NC-19"></a>[NC-19] Constant state variables defined more than once
Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (10)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

76:     uint256 internal constant WAD = 1e18;

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

68:     bytes32 private constant EXPECTED_HOOK_TYPE_ID = keccak256("NudgeRatchetMintDebtHook.v1");

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

52:     bytes32 private constant EXPECTED_HOOK_TYPE_ID = keccak256("NudgeRatchetMintDebtHook.v1");

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

105:     // ---------------------------------------------------------------------

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

24:     uint8 public constant MAX_RATIO = 50;

27:     uint8 public constant DEFAULT_RATIO = 50;

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

25:     uint8 public constant MAX_RATIO = 200;

28:     uint8 public constant DEFAULT_RATIO = 100;

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

31:     uint8 public constant MAX_RATIO = 50;

34:     uint8 public constant DEFAULT_RATIO = 50;

```

### <a name="NC-20"></a>[NC-20] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (12)*:
```solidity
File: ./src/BurnRecorder.sol

13:     mapping(address => bool) private _burners;

16:     mapping(address => uint256) private totalBurnt;

19:     mapping(uint256 => address) private tokenIndex;

```

```solidity
File: ./src/NFTMinterV2.sol

31:     mapping(uint256 => DispatcherConfig) public configs;

34:     mapping(address => uint256) public dispatcherToIndex;

37:     mapping(uint256 => address) public tokenIdToDispatcher;

40:     mapping(address => bool) public authorizedBurners;

43:     mapping(address => bool) public authorizedMinters;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

86:     mapping(address => uint256) public poolerAuthVersion;

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

47:     mapping(address => bool) public releasers;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

163:     mapping(address => uint256) public poolerAuthVersion;

```

```solidity
File: ./src/dispatchers/Uniboost.sol

92:     mapping(address => uint256) public poolerAuthVersion;

```

### <a name="NC-21"></a>[NC-21] `address`s shouldn't be hard-coded
It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (10)*:
```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

82:     address public constant phUSD = 0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605;

84:     address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

86:     address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

88:     address public constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

90:     address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

92:     address public constant BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

94:     address public constant BALANCER_POOL = 0x642BB6860b4776CC10b26B8f361Fd139E7f0db04;

96:     address public constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

100:     address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

110:     address public psm = 0xA188EEC8F81263234dA3622A406892F3D630f98c;

```

### <a name="NC-22"></a>[NC-22] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: ./src/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="NC-23"></a>[NC-23] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (1)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

403:     /// @notice Queries the Balancer Router for the expected BPT output from pooling current sUSDS balance.
         /// @return bptAmountOut The expected BPT amount, or 0 if sUSDS balance is 0.
         function getIdealBPT() external returns (uint256 bptAmountOut) {
             uint256 sUSDSAmount = IERC20(_sUSDS).balanceOf(address(this));
             if (sUSDSAmount == 0) return 0;
     
             uint256[] memory exactAmountsIn = new uint256[](2);

```

### <a name="NC-24"></a>[NC-24] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (12)*:
```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

58:             revert OnlyOwnerOrRecipient();

78:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

110:         if (msg.sender != dispatcher) revert OnlyDispatcher();

121:         if (recipient == address(0)) revert RecipientUnset();

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

70:             revert OnlyOwnerOrRecipient();

91:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

123:         if (msg.sender != dispatcher) revert OnlyDispatcher();

137:         if (recipient == address(0)) revert RecipientUnset();

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

71:             revert OnlyOwnerOrRecipient();

97:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

129:         if (msg.sender != dispatcher) revert OnlyDispatcher();

142:         if (recipient == address(0)) revert RecipientUnset();

```

### <a name="NC-25"></a>[NC-25] Strings should use double quotes rather than single quotes
See the Solidity Style Guide: https://docs.soliditylang.org/en/v0.8.20/style-guide.html#other-recommendations

*Instances (4)*:
```solidity
File: ./src/NFTMinterV2.sol

264:                 '{"name":"',

266:                 '","image":"',

268:                 '","description":"',

270:                 '"}'

```

### <a name="NC-26"></a>[NC-26] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (5)*:
```solidity
File: ./src/MultiPooler.sol

1: 
   Current order:
   StructDefinition.PoolCall
   VariableDeclaration.pooler
   EventDefinition.PoolerSet
   EventDefinition.BatchPooled
   ModifierDefinition.onlyPooler
   FunctionDefinition.constructor
   FunctionDefinition.setPooler
   FunctionDefinition.pool
   
   Suggested order:
   VariableDeclaration.pooler
   StructDefinition.PoolCall
   EventDefinition.PoolerSet
   EventDefinition.BatchPooled
   ModifierDefinition.onlyPooler
   FunctionDefinition.constructor
   FunctionDefinition.setPooler
   FunctionDefinition.pool

```

```solidity
File: ./src/NFTMinterV2.sol

1: 
   Current order:
   UsingForDirective.IERC20
   StructDefinition.DispatcherConfig
   VariableDeclaration.nextIndex
   VariableDeclaration.configs
   VariableDeclaration.dispatcherToIndex
   VariableDeclaration.tokenIdToDispatcher
   VariableDeclaration.authorizedBurners
   VariableDeclaration.authorizedMinters
   EventDefinition.DispatcherRegistered
   EventDefinition.ClaimMinted
   EventDefinition.ClaimMintedFor
   EventDefinition.PriceUpdated
   EventDefinition.GrowthFactorUpdated
   EventDefinition.EmergencyWithdraw
   EventDefinition.DispatcherActiveChanged
   EventDefinition.PauserChanged
   EventDefinition.Paused
   EventDefinition.Unpaused
   EventDefinition.DispatcherDisabledChanged
   EventDefinition.AuthorizedBurnerSet
   EventDefinition.AuthorizedMinterSet
   EventDefinition.ClaimBurned
   EventDefinition.DispatcherReplaced
   VariableDeclaration.pauser
   VariableDeclaration.paused
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.registerDispatcher
   FunctionDefinition.setDispatcherDisabled
   FunctionDefinition.mint
   FunctionDefinition.mint
   FunctionDefinition._executeMint
   FunctionDefinition.mintFor
   FunctionDefinition.setAuthorizedMinter
   FunctionDefinition.replaceDispatcher
   FunctionDefinition.uri
   FunctionDefinition.getPrice
   FunctionDefinition.setPrice
   FunctionDefinition.setGrowthFactor
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.setDispatcherActive
   FunctionDefinition.setAuthorizedBurner
   FunctionDefinition.burn
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.nextIndex
   VariableDeclaration.configs
   VariableDeclaration.dispatcherToIndex
   VariableDeclaration.tokenIdToDispatcher
   VariableDeclaration.authorizedBurners
   VariableDeclaration.authorizedMinters
   VariableDeclaration.pauser
   VariableDeclaration.paused
   StructDefinition.DispatcherConfig
   EventDefinition.DispatcherRegistered
   EventDefinition.ClaimMinted
   EventDefinition.ClaimMintedFor
   EventDefinition.PriceUpdated
   EventDefinition.GrowthFactorUpdated
   EventDefinition.EmergencyWithdraw
   EventDefinition.DispatcherActiveChanged
   EventDefinition.PauserChanged
   EventDefinition.Paused
   EventDefinition.Unpaused
   EventDefinition.DispatcherDisabledChanged
   EventDefinition.AuthorizedBurnerSet
   EventDefinition.AuthorizedMinterSet
   EventDefinition.ClaimBurned
   EventDefinition.DispatcherReplaced
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.registerDispatcher
   FunctionDefinition.setDispatcherDisabled
   FunctionDefinition.mint
   FunctionDefinition.mint
   FunctionDefinition._executeMint
   FunctionDefinition.mintFor
   FunctionDefinition.setAuthorizedMinter
   FunctionDefinition.replaceDispatcher
   FunctionDefinition.uri
   FunctionDefinition.getPrice
   FunctionDefinition.setPrice
   FunctionDefinition.setGrowthFactor
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.setDispatcherActive
   FunctionDefinition.setAuthorizedBurner
   FunctionDefinition.burn

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

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

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

1: 
   Current order:
   VariableDeclaration.MAX_RATIO
   VariableDeclaration.DEFAULT_RATIO
   VariableDeclaration.HOOK_TYPE_ID
   VariableDeclaration.USDC_TO_PHUSD_SCALE
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
   FunctionDefinition.hookTypeId
   
   Suggested order:
   VariableDeclaration.MAX_RATIO
   VariableDeclaration.DEFAULT_RATIO
   VariableDeclaration.HOOK_TYPE_ID
   VariableDeclaration.USDC_TO_PHUSD_SCALE
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
   FunctionDefinition.hookTypeId

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

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

### <a name="NC-27"></a>[NC-27] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: ./src/NFTMinterV2.sol

188:         config.price = price + (price * config.growthBasisPoints) / 10000;

```

### <a name="NC-28"></a>[NC-28] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (2)*:
```solidity
File: ./src/BurnRecorder.sol

16:     mapping(address => uint256) private totalBurnt;

19:     mapping(uint256 => address) private tokenIndex;

```

### <a name="NC-29"></a>[NC-29] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (49)*:
```solidity
File: ./src/BurnRecorder.sol

28:     event tokenBurnt(address indexed token, uint256 quantity, uint256 timestamp);

```

```solidity
File: ./src/MultiPooler.sol

35:     event BatchPooled(address indexed pooler, uint256 count);

```

```solidity
File: ./src/NFTMinterV2.sol

46:     event DispatcherRegistered(

59:     event PriceUpdated(uint256 indexed index, uint256 oldPrice, uint256 newPrice);

62:     event GrowthFactorUpdated(uint256 indexed index, uint256 oldGrowthBasisPoints, uint256 newGrowthBasisPoints);

65:     event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

68:     event DispatcherActiveChanged(address indexed dispatcher, bool active);

80:     event DispatcherDisabledChanged(uint256 indexed index, bool disabled);

83:     event AuthorizedBurnerSet(address indexed burner, bool authorized);

86:     event AuthorizedMinterSet(address indexed minter, bool authorized);

89:     event ClaimBurned(address indexed holder, uint256 indexed tokenId, uint256 quantity);

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

38:     event MetadataUpdated(string name, string image, string description);

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

113:     event PoolerAuthorized(address indexed pooler, uint256 atAuthVersion);

115:     event AuthVersionIncremented(uint256 newAuthVersion);

116:     event Pooled(address indexed pooler, uint256 sUSDSPooled, uint256 bptReceived, uint256 minBPT);

118:     event BatchDonationSizeSet(uint256 newSize);

119:     event BatchMinterSet(address newBatchMinter);

120:     event PSMSet(address newPSM);

121:     event MaxToutSet(uint256 newMaxTout);

130:     event BatchDonatedViaPSM(uint256 usdsSpent, uint256 usdcDonated, address indexed batchMinter);

134:     event DonationSkipped(uint256 usdsParked);

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

57:     event ReleaserUpdated(address indexed releaser, bool approved);

59:     event Released(address indexed releaser, uint256 amount);

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

169:     event PoolerAuthorized(address indexed pooler, uint256 atAuthVersion);

173:     /// @notice Emitted once per `pool()`. Consolidates the full 60/30/10 outcome.

176:         uint256 primeSpent, // amountIn (USDC)

185:     event BatchMinterSet(address newBatchMinter);

186:     event NudgeStreamerUpdated(address indexed oldStreamer, address indexed newStreamer);

188:     event MaxTinSet(uint256 newMaxTin);

189:     event EthToPromotionPathSet(address[] path);

190:     event UsdcToWbtcPathSet(address[] path);

191:     event InsurerSet(address newInsurer);

192:     event WBTCWithdrawn(address indexed to, uint256 amount);

194:     modifier onlyAuthorizedPooler() {

```

```solidity
File: ./src/dispatchers/Uniboost.sol

94:     event PoolerAuthorized(address indexed pooler, uint256 atAuthVersion);

96:     event AuthVersionIncremented(uint256 newAuthVersion);

97:     event Pooled(address indexed pooler, uint256 primeSpent, uint256 liquidity, uint256 minLP);

100:     event DonationSplitSet(uint256 newSplit);

101:     event RecipientSet(address newRecipient);

103:     event PrimeToPairPathSet(address[] path);

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

45:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

47:     event DebtAccrued(address indexed minter, uint256 dispatchedAmount, uint256 debtAdded, uint256 newTotalDebt);

48:     event DebtPulled(address indexed recipient, uint256 amount);

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

57:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

59:     event DebtAccrued(address indexed minter, uint256 dispatchedAmount, uint256 debtAdded, uint256 newTotalDebt);

60:     event DebtPulled(address indexed recipient, uint256 amount);

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

58:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

60:     event DebtAccrued(address indexed minter, uint256 dispatchedAmount, uint256 debtAdded, uint256 newTotalDebt);

61:     event DebtPulled(address indexed recipient, uint256 amount);

```

### <a name="NC-30"></a>[NC-30] Constants should be defined rather than using magic numbers

*Instances (2)*:
```solidity
File: ./src/NFTMinterV2.sol

22:         uint256 price; // current mint price in token units (18 decimals)

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

89:         scale = 10 ** (18 - d);

```

### <a name="NC-31"></a>[NC-31] `public` functions not called by the contract should be declared `external` instead

*Instances (3)*:
```solidity
File: ./src/BurnRecorder.sol

58:     function getTotalBurnt(address token) public view returns (uint256) {

72:     function getTokenCount() public view returns (uint256) {

79:     function getTokenAtIndex(uint256 index) public view returns (address) {

```

### <a name="NC-32"></a>[NC-32] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (1)*:
```solidity
File: ./src/MultiPooler.sol

62:         for (uint256 i = 0; i < calls.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 10 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 12 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 11 |
| [L-4](#L-4) | `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 7 |
| [L-5](#L-5) | `decimals()` is not a part of the ERC-20 standard | 3 |
| [L-6](#L-6) | Division by zero not prevented | 1 |
| [L-7](#L-7) | Empty `receive()/payable fallback()` function does not authenticate requests | 1 |
| [L-8](#L-8) | External call recipient may consume all transaction gas | 1 |
| [L-9](#L-9) | Prevent accidentally burning tokens | 14 |
| [L-10](#L-10) | Owner can renounce while system is paused | 1 |
| [L-11](#L-11) | Loss of precision | 3 |
| [L-12](#L-12) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 15 |
| [L-13](#L-13) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 7 |
| [L-14](#L-14) | Sweeping may break accounting if tokens with multiple addresses are used | 4 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (10)*:
```solidity
File: ./src/BurnRecorder.sol

11: contract BurnRecorder is IBurnRecorder, Ownable {

```

```solidity
File: ./src/MultiPooler.sol

18: contract MultiPooler is Ownable {

```

```solidity
File: ./src/NFTMinterV2.sol

16: contract NFTMinterV2 is ERC1155Supply, Ownable, INFTMinterV2, IPausable {

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

23: abstract contract ATokenDispatcherV2 is ITokenDispatcherV2, Pausable, Ownable, ReentrancyGuard {

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

22: contract BalancerPoolerMintDebtHook is IDispatchHook, IBalancerPoolerMintDebtHook, Ownable, ReentrancyGuard {

66:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

22: contract NudgeRatchetMintDebtHook is IDispatchHook, INudgeRatchetMintDebtHook, Ownable, ReentrancyGuard {

78:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

29: contract UniboostMintDebtHook is IDispatchHook, IUniboostMintDebtHook, Ownable, ReentrancyGuard {

81:     constructor(address initialOwner, address dispatcher_, address phUSD_, address primeToken_) Ownable(initialOwner) {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (12)*:
```solidity
File: ./src/NFTMinterV2.sol

183:         IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price);

302:         IERC20(token).safeTransfer(msg.sender, balance);

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

373:             IERC20(_sUSDS).safeTransfer(_vault, sUSDSAmount);

425:         IERC20(_pool).safeTransfer(recipient, amount);

440:     }

```

```solidity
File: ./src/dispatchers/GatherV2.sol

61:         IERC20(_token).safeTransfer(_recipient, amount);

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

109:         IERC20(_token).safeTransfer(batchMinter, amount);

120:         IERC20(token).safeTransfer(to, amount);

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

315:         emit WBTCWithdrawn(to, amount);

552:         VaultSwapParams memory p = VaultSwapParams({

581:     /// @notice Owner escape hatch for native ETH left by a failed/partial Leg B. Not pause-gated.

```

```solidity
File: ./src/dispatchers/Uniboost.sol

340:         IERC20(token).safeTransfer(to, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (11)*:
```solidity
File: ./src/NFTMinterV2.sol

106:         pauser = newPauser;

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

86:         _minter = minter_;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

154:         _vault = vault_;

155:         _router = router_;

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

18:         _token = token_;

```

```solidity
File: ./src/dispatchers/GatherV2.sol

28:         _token = token_;

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

85:         _token = token_;

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

79:         _token = token_;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

343:         emit BatchMinterSet(newBatchMinter);

```

```solidity
File: ./src/dispatchers/Uniboost.sol

167:         _pairToken = pairToken_;

184:         recipient = newRecipient;

```

### <a name="L-4"></a>[L-4] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (7)*:
```solidity
File: ./src/NFTMinterV2.sol

264:                 '{"name":"',

265:                 dispatcherName,

266:                 '","image":"',

267:                 dispatcherImage,

268:                 '","description":"',

269:                 dispatcherDescription,

270:                 '"}'

```

### <a name="L-5"></a>[L-5] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (3)*:
```solidity
File: ./src/dispatchers/NudgeRatchet.sol

84:         require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

76:             IERC20Metadata(token_).decimals() == 6,

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

85:         uint8 d = IERC20Metadata(primeToken_).decimals();

```

### <a name="L-6"></a>[L-6] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

322:         uint256 gemAmt = (usdsAmount * WAD) / (conv * (WAD + tout));

```

### <a name="L-7"></a>[L-7] Empty `receive()/payable fallback()` function does not authenticate requests
If the intention is for the Ether to be used, the function should call another function, otherwise it should revert (e.g. require(msg.sender == address(weth))). Having no access control on the function means that someone may send Ether to the contract, and have no way to get anything back out, which is a loss of funds. If the concern is having to spend a small amount of gas to check the sender against an immutable address, the code should at least have a function to rescue unused Ether.

*Instances (1)*:
```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

591: 

```

### <a name="L-8"></a>[L-8] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (1)*:
```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

584:         (bool ok,) = to.call{value: amount}("");

```

### <a name="L-9"></a>[L-9] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (14)*:
```solidity
File: ./src/BurnRecorder.sol

32:         require(_burners[msg.sender], "BurnRecorder: caller is not burner");

```

```solidity
File: ./src/NFTMinterV2.sol

196:         _mint(recipient, resolvedTokenId, 1, "");

211:         _mint(recipient, index, 1, "");

221:         emit AuthorizedMinterSet(minter, authorized);

334:         emit AuthorizedBurnerSet(burner, authorized);

343:         _burn(holder, tokenId, quantity);

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

45:         require(msg.sender == _minter, "ATokenDispatcherV2: caller is not minter");

124:         _dispatch(minter, amount, extraData);

125:         hook.onDispatch(minter, amount, extraData);

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

19:         _burnRecorder = IBurnRecorder(burnRecorder_);

38:         _burnRecorder.burn(_token, amount);

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

114:         emit DebtAccrued(minter, amount, added, mintDebt);

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

130:         emit DebtAccrued(minter, amount, added, mintDebt);

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

135:         emit DebtAccrued(minter, amount, added, mintDebt);

```

### <a name="L-10"></a>[L-10] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: ./src/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="L-11"></a>[L-11] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (3)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

322:         uint256 gemAmt = (usdsAmount * WAD) / (conv * (WAD + tout));

331:             uint256 usdsSpent = gemAmt * conv * (WAD + tout) / WAD;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

439:             uint256 amountA = (amountIn * 60) / 100; // phUSD leg

```

### <a name="L-12"></a>[L-12] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (15)*:
```solidity
File: ./src/BurnRecorder.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/MultiPooler.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/NFTMinterV2.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/dispatchers/BurnerV2.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/dispatchers/GatherV2.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/dispatchers/Uniboost.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/hooks/DefaultDispatchHook.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: ./src/interfaces/balancer/BalancerTypes.sol

2: pragma solidity ^0.8.20;

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

*Instances (7)*:
```solidity
File: ./src/BurnRecorder.sol

5: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: ./src/MultiPooler.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: ./src/NFTMinterV2.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

8: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-14"></a>[L-14] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (4)*:
```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

437:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

118:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

575:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/Uniboost.sol

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 74 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (74)*:
```solidity
File: ./src/BurnRecorder.sol

11: contract BurnRecorder is IBurnRecorder, Ownable {

37:     constructor(address initialOwner) Ownable(initialOwner) {}

42:     function setBurner(address burner_, bool approved_) external onlyOwner {

65:     function registerToken(address token) external onlyOwner {

```

```solidity
File: ./src/MultiPooler.sol

18: contract MultiPooler is Ownable {

45:     constructor(address initialOwner) Ownable(initialOwner) {}

50:     function setPooler(address newPooler) external onlyOwner {

```

```solidity
File: ./src/NFTMinterV2.sol

16: contract NFTMinterV2 is ERC1155Supply, Ownable, INFTMinterV2, IPausable {

100:     constructor(address initialOwner) ERC1155("") Ownable(initialOwner) {}

104:     function setPauser(address newPauser) external onlyOwner {

152:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {

219:     function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {

227:     function replaceDispatcher(uint256 index, address newDispatcher) external onlyOwner {

282:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {

290:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {

299:     function emergencyWithdraw(address token) external onlyOwner {

309:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {

332:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {

```

```solidity
File: ./src/dispatchers/ATokenDispatcherV2.sol

23: abstract contract ATokenDispatcherV2 is ITokenDispatcherV2, Pausable, Ownable, ReentrancyGuard {

50:     constructor(address initialOwner) Ownable(initialOwner) {

85:     function setMinter(address minter_) external onlyOwner {

94:     function setHook(IDispatchHook newHook) external onlyOwner {

```

```solidity
File: ./src/dispatchers/BalancerPoolerV2.sol

182:     function setPool(address newPool) external onlyOwner {

190:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

202:     function incrementAuthVersion() external onlyOwner {

210:     function setBatchDonationSize(uint256 newSize) external onlyOwner {

219:     function setBatchMinter(address newBatchMinter) external onlyOwner {

227:     function setPSM(address newPSM) external onlyOwner {

235:     function setMaxTout(uint256 newMaxTout) external onlyOwner {

246:     function setNudgeStreamer(address newStreamer) external onlyOwner {

424:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

437:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/GatherV2.sol

44:     function setRecipient(address newRecipient) external onlyOwner {

```

```solidity
File: ./src/dispatchers/NudgeRatchet.sol

96:     function setBatchMinter(address newBatchMinter) external onlyOwner {

105:     function setNudgeStreamer(address newStreamer) external onlyOwner {

```

```solidity
File: ./src/dispatchers/NudgeRatchetDelayRelease.sol

89:     function setBatchMinter(address newBatchMinter) external onlyOwner {

97:     function setReleaser(address releaser, bool approved) external onlyOwner {

118:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/PromotionUniV2_Eth.sol

264:     function setPool(address newPair) external onlyOwner {

283:     function setEthToPromotionPath(address[] calldata path) external onlyOwner {

294:     function setUsdcToWbtcPath(address[] calldata path) external onlyOwner {

304:     function setInsurer(address newInsurer) external onlyOwner {

319:     function setPSM(address newPSM) external onlyOwner {

326:     function setMaxTin(uint256 newMaxTin) external onlyOwner {

333:     function setDonationSplit(uint256 newSplit) external onlyOwner {

341:     function setBatchMinter(address newBatchMinter) external onlyOwner {

348:     function setNudgeStreamer(address newStreamer) external onlyOwner {

356:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

368:     function incrementAuthVersion() external onlyOwner {

575:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

582:     function rescueETH(address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/dispatchers/Uniboost.sol

154:     function setPool(address newPool) external onlyOwner {

174:     function setDonationSplit(uint256 newSplit) external onlyOwner {

183:     function setRecipient(address newRecipient) external onlyOwner {

190:     function setNudgeStreamer(address newStreamer) external onlyOwner {

202:     function setPrimeToPairPath(address[] calldata path) external onlyOwner {

315:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

327:     function incrementAuthVersion() external onlyOwner {

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: ./src/hooks/BalancerPoolerMintDebtHook.sol

22: contract BalancerPoolerMintDebtHook is IDispatchHook, IBalancerPoolerMintDebtHook, Ownable, ReentrancyGuard {

66:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

77:     function setRatio(uint8 newRatio) external onlyOwner {

87:     function setRecipient(address newRecipient) external onlyOwner {

98:     function setDispatcher(address newDispatcher) external onlyOwner {

```

```solidity
File: ./src/hooks/NudgeRatchetMintDebtHook.sol

22: contract NudgeRatchetMintDebtHook is IDispatchHook, INudgeRatchetMintDebtHook, Ownable, ReentrancyGuard {

78:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

90:     function setRatio(uint8 newRatio) external onlyOwner {

100:     function setRecipient(address newRecipient) external onlyOwner {

111:     function setDispatcher(address newDispatcher) external onlyOwner {

```

```solidity
File: ./src/hooks/UniboostMintDebtHook.sol

29: contract UniboostMintDebtHook is IDispatchHook, IUniboostMintDebtHook, Ownable, ReentrancyGuard {

81:     constructor(address initialOwner, address dispatcher_, address phUSD_, address primeToken_) Ownable(initialOwner) {

96:     function setRatio(uint8 newRatio) external onlyOwner {

106:     function setRecipient(address newRecipient) external onlyOwner {

117:     function setDispatcher(address newDispatcher) external onlyOwner {

```

