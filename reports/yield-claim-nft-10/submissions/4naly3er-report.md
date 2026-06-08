# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 3 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 32 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 9 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 1 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 24 |
| [GAS-6](#GAS-6) | Use calldata instead of memory for function arguments that do not get mutated | 4 |
| [GAS-7](#GAS-7) | For Operations that will not overflow, you could use unchecked | 118 |
| [GAS-8](#GAS-8) | Use Custom Errors instead of Revert Strings to save Gas | 60 |
| [GAS-9](#GAS-9) | Avoid contract existence checks by using low level calls | 14 |
| [GAS-10](#GAS-10) | Stack variable used as a cheaper cache for a state variable is only used once | 7 |
| [GAS-11](#GAS-11) | State variables only set in the constructor should be declared `immutable` | 18 |
| [GAS-12](#GAS-12) | Functions guaranteed to revert when called by normal users can be marked `payable` | 48 |
| [GAS-13](#GAS-13) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 7 |
| [GAS-14](#GAS-14) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-15](#GAS-15) | Superfluous event fields | 1 |
| [GAS-16](#GAS-16) | Use of `this` instead of marking as `public` an `external` function | 1 |
| [GAS-17](#GAS-17) | Increments/decrements can be unchecked in for-loops | 4 |
| [GAS-18](#GAS-18) | Use != 0 instead of > 0 for unsigned integer comparison | 10 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (3)*:
```solidity
File: BurnRecorder.sol

51:         totalBurnt[token] += amount;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

153:         authVersion += 1;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

113:         mintDebt += added;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (32)*:
```solidity
File: NFTMinter.sol

124:         require(dispatcher != address(0), "NFTMinter: zero dispatcher address");

151:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

173:         require(config.dispatcher != address(0), "NFTMinter: index not registered");

209:         if (dispatcher == address(0)) {

232:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

243:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

251:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

95:         require(address(newHook) != address(0), "ATokenDispatcherV2: zero hook");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

99:         require(sUSDS_ != address(0), "BalancerPoolerV2: zero sUSDS");

100:         require(router_ != address(0), "BalancerPoolerV2: zero router");

133:         require(newPool != address(0), "BalancerPoolerV2: zero pool address");

141:         require(pooler != address(0), "BalancerPoolerV2: zero pooler");

178:         require(newPSM != address(0), "BalancerPoolerV2: zero psm");

210:         bool donationEnabled = batchMinter != address(0) && psm != address(0) && batchDonationSize > 0;

351:         require(to != address(0), "BalancerPoolerV2: zero recipient");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

27:         require(recipient_ != address(0), "GatherV2: zero recipient address");

45:         require(newRecipient != address(0), "GatherV2: zero recipient address");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

67:         require(dispatcher_ != address(0), "dispatcher=0");

68:         require(phUSD_ != address(0), "phUSD=0");

99:         require(newDispatcher != address(0), "dispatcher=0");

121:         if (recipient == address(0)) revert RecipientUnset();

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/Gather.sol

28:         require(recipient_ != address(0), "Gather: zero recipient address");

46:         require(newRecipient != address(0), "Gather: zero recipient address");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (9)*:
```solidity
File: BurnRecorder.sol

13:     mapping(address => bool) private _burners;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

43:     mapping(address => bool) public authorizedBurners;

93:     bool public paused;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

15:     bool public initialized;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

40:     mapping(address => bool) public authorizedBurners;

43:     mapping(address => bool) public authorizedMinters;

98:     bool public paused;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

43:     bool private immutable _sUSDSIsFirst;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: dispatchers/BalancerPooler.sol

22:     bool private immutable _primeTokenIsFirst;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (1)*:
```solidity
File: V2/NFTMigrator.sol

43:         for (uint256 i = 0; i < v1Indexes.length; i++) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (24)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

144:             emit PoolerAuthorized(pooler, authVersion);

218:             IERC4626(_sUSDS).deposit(poolingUSDS, address(this));

224:             uint256 remainingUSDS = IERC20(_primeToken).balanceOf(address(this));

252:         uint256 conv = ISkyPSM(psm).to18ConversionFactor();

259:         IERC20(_primeToken).forceApprove(psm, usdsSpent);

260:         ISkyPSM(psm).buyGem(batchMinter, gemAmt); // USDC delivered straight to batchMinter.

261:         IERC20(_primeToken).forceApprove(psm, 0); // tidy allowance.

261:         IERC20(_primeToken).forceApprove(psm, 0); // tidy allowance.

286:             IERC20(_sUSDS).safeTransfer(_vault, sUSDSAmount);

286:             IERC20(_sUSDS).safeTransfer(_vault, sUSDSAmount);

287:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

287:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

307:             (, uint256 bptAmountOut,) = IBalancerVault(_vault).addLiquidity(params);

308:             IBalancerVault(_vault).settle(IERC20(_sUSDS), actualInVault);

308:             IBalancerVault(_vault).settle(IERC20(_sUSDS), actualInVault);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

38:         _burnRecorder.burn(_token, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: dispatchers/BalancerPooler.sol

65:         IERC20(_primeToken).safeTransfer(_vault, primeAmount);

65:         IERC20(_primeToken).safeTransfer(_vault, primeAmount);

66:         uint256 actualPrimeInVault = IERC20(_primeToken).balanceOf(_vault) - vaultPrimeBefore;

66:         uint256 actualPrimeInVault = IERC20(_primeToken).balanceOf(_vault) - vaultPrimeBefore;

87:         IBalancerVault(_vault).addLiquidity(params);

88:         IBalancerVault(_vault).settle(IERC20(_primeToken), actualPrimeInVault);

88:         IBalancerVault(_vault).settle(IERC20(_primeToken), actualPrimeInVault);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

41:         _burnRecorder.burn(_token, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

### <a name="GAS-6"></a>[GAS-6] Use calldata instead of memory for function arguments that do not get mutated
When a function with a `memory` array is called externally, the `abi.decode()` step has to use a for-loop to copy each index of the `calldata` to the `memory` index. Each iteration of this for-loop costs at least 60 gas (i.e. `60 * <mem_array>.length`). Using `calldata` directly bypasses this loop. 

If the array is passed to an `internal` function which passes the array to another internal function where the array is modified and therefore `memory` is used in the `external` call, it's still more gas-efficient to use `calldata` when the `external` function uses modifiers, since the modifiers may prevent the internal functions from being called. Structs have the same overhead as an array of length one. 

 *Saves 60 gas per instance*

*Instances (4)*:
```solidity
File: interfaces/balancer/IBalancerRouter.sol

7:         uint256[] memory exactAmountsIn,

9:         bytes memory userData

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/balancer/IBalancerRouter.sol)

```solidity
File: interfaces/balancer/IBalancerVault.sol

9:     function addLiquidity(AddLiquidityParams memory params)

12:     function swap(VaultSwapParams memory params)

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/balancer/IBalancerVault.sol)

### <a name="GAS-7"></a>[GAS-7] For Operations that will not overflow, you could use unchecked

*Instances (118)*:
```solidity
File: BurnRecorder.sol

4: import {IBurnRecorder} from "./interfaces/IBurnRecorder.sol";

5: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

51:         totalBurnt[token] += amount;

67:         _latestIndex++;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

4: import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

5: import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

10: import {ITokenDispatcher} from "./interfaces/ITokenDispatcher.sol";

11: import {ATokenDispatcher} from "./dispatchers/ATokenDispatcher.sol";

12: import {INFTMinter} from "./interfaces/INFTMinter.sol";

13: import {ITokenMinter} from "./interfaces/ITokenMinter.sol";

14: import {IPausable} from "pauser/interfaces/IPausable.sol";

21:         address dispatcher; // TokenDispatcher contract address

22:         uint256 price; // current mint price in token units (18 decimals)

23:         uint256 growthBasisPoints; // price growth per mint in basis points (100 = 1%)

24:         bool disabled; // if true, new mints are blocked but existing NFTs remain valid

128:         nextIndex++;

185:         uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

189:         config.price = price + (price * config.growthBasisPoints) / 10000;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

4: import {INFTMinter} from "../interfaces/INFTMinter.sol";

5: import {INFTMinterV2} from "./interfaces/INFTMinterV2.sol";

6: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

43:         for (uint256 i = 0; i < v1Indexes.length; i++) {

53:         for (uint256 i = 1; i < upperBound; i++) {

65:         for (uint256 i = 1; i < upperBound; i++) {

70:                 for (uint256 j = 0; j < balance; j++) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

4: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

5: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

6: import {DefaultDispatchHook} from "../hooks/DefaultDispatchHook.sol";

7: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

8: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

9: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

7: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

8: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

9: import {ISkyPSM} from "../interfaces/ISkyPSM.sol";

10: import {IBalancerVault} from "../../interfaces/balancer/IBalancerVault.sol";

11: import {IBalancerRouter} from "../../interfaces/balancer/IBalancerRouter.sol";

12: import {IUnlockCallback} from "../../interfaces/balancer/IUnlockCallback.sol";

13: import {AddLiquidityParams, AddLiquidityKind} from "../../interfaces/balancer/BalancerTypes.sol";

153:         authVersion += 1;

205:         bytes calldata /*extraData*/

212:         uint256 donationUSDS = donationEnabled ? (amount * batchDonationSize) / 100 : 0;

213:         uint256 poolingUSDS = amount - donationUSDS;

228:                     emit DonationSkipped(remainingUSDS); // USDS parks on the contract.

253:         uint256 gemAmt = (usdsAmount * WAD) / (conv * (WAD + tout));

257:         uint256 usdsSpent = gemAmt * conv * (WAD + tout) / WAD;

260:         ISkyPSM(psm).buyGem(batchMinter, gemAmt); // USDC delivered straight to batchMinter.

261:         IERC20(_primeToken).forceApprove(psm, 0); // tidy allowance.

287:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

4: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

5: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

6: import {IBurnable} from "../../interfaces/IBurnable.sol";

7: import {IBurnRecorder} from "../../interfaces/IBurnRecorder.sol";

32:         bytes calldata /* extraData */

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";

7: import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";

56:         bytes calldata /* extraData */

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

4: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

5: import {IBalancerPoolerMintDebtHook} from "../interfaces/IBalancerPoolerMintDebtHook.sol";

6: import {IMintable} from "../../interfaces/IMintable.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

111:         uint256 added = (amount * ratio) / 100;

113:         mintDebt += added;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: V2/hooks/DefaultDispatchHook.sol

4: import {IDispatchHook} from "../interfaces/IDispatchHook.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/DefaultDispatchHook.sol)

```solidity
File: V2/interfaces/INFTMinterV2.sol

4: import {ITokenMinterV2} from "./ITokenMinterV2.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/interfaces/INFTMinterV2.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

4: import {ITokenDispatcher} from "../interfaces/ITokenDispatcher.sol";

5: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {ATokenDispatcher} from "./ATokenDispatcher.sol";

7: import {ITokenDispatcher} from "../interfaces/ITokenDispatcher.sol";

8: import {IBalancerVault} from "../interfaces/balancer/IBalancerVault.sol";

9: import {IUnlockCallback} from "../interfaces/balancer/IUnlockCallback.sol";

10: import {AddLiquidityParams, AddLiquidityKind} from "../interfaces/balancer/BalancerTypes.sol";

66:         uint256 actualPrimeInVault = IERC20(_primeToken).balanceOf(_vault) - vaultPrimeBefore;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

4: import {ATokenDispatcher} from "./ATokenDispatcher.sol";

5: import {ITokenDispatcher} from "../interfaces/ITokenDispatcher.sol";

6: import {IBurnable} from "../interfaces/IBurnable.sol";

7: import {IBurnRecorder} from "../interfaces/IBurnRecorder.sol";

33:         bytes calldata /* extraData */

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

```solidity
File: dispatchers/Gather.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {ATokenDispatcher} from "./ATokenDispatcher.sol";

7: import {ITokenDispatcher} from "../interfaces/ITokenDispatcher.sol";

57:         bytes calldata /* extraData */

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

```solidity
File: interfaces/INFTMinter.sol

4: import {ITokenMinter} from "./ITokenMinter.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/INFTMinter.sol)

```solidity
File: interfaces/balancer/BalancerTypes.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/balancer/BalancerTypes.sol)

```solidity
File: interfaces/balancer/IBalancerVault.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {AddLiquidityParams, VaultSwapParams} from "./BalancerTypes.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/balancer/IBalancerVault.sol)

### <a name="GAS-8"></a>[GAS-8] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (60)*:
```solidity
File: BurnRecorder.sol

32:         require(_burners[msg.sender], "BurnRecorder: caller is not burner");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

107:         require(msg.sender == pauser, "Only pauser");

114:         require(msg.sender == pauser, "Only pauser");

124:         require(dispatcher != address(0), "NFTMinter: zero dispatcher address");

125:         require(dispatcherToIndex[dispatcher] == 0, "NFTMinter: dispatcher already registered");

151:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

171:         require(!paused, "Contract is paused");

173:         require(config.dispatcher != address(0), "NFTMinter: index not registered");

174:         require(!config.disabled, "NFTMinter: dispatcher is disabled");

178:         require(dispatcherToken == token, "NFTMinter: token mismatch");

232:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

243:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

251:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

261:         require(balance > 0, "NFTMinter: no tokens to withdraw");

270:         require(dispatcherToIndex[dispatcher] != 0, "NFTMinter: dispatcher not registered");

302:         require(authorizedBurners[msg.sender], "NFTMinter: caller is not authorized burner");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

42:         require(v1Indexes.length == v2Indexes.length, "NFTMigrator: array length mismatch");

54:             require(indexMapping[i] != 0, "NFTMigrator: missing mapping");

63:         require(initialized, "NFTMigrator: not initialized");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

45:         require(msg.sender == _minter, "ATokenDispatcherV2: caller is not minter");

95:         require(address(newHook) != address(0), "ATokenDispatcherV2: zero hook");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

87:         require(poolerAuthVersion[msg.sender] == authVersion, "BalancerPoolerV2: caller not authorized pooler");

99:         require(sUSDS_ != address(0), "BalancerPoolerV2: zero sUSDS");

100:         require(router_ != address(0), "BalancerPoolerV2: zero router");

133:         require(newPool != address(0), "BalancerPoolerV2: zero pool address");

141:         require(pooler != address(0), "BalancerPoolerV2: zero pooler");

161:         require(newSize <= 100, "BalancerPoolerV2: size > 100");

178:         require(newPSM != address(0), "BalancerPoolerV2: zero psm");

241:         require(msg.sender == address(this), "BalancerPoolerV2: only self");

244:         require(tout <= maxTout, "BalancerPoolerV2: tout too high");

254:         require(gemAmt > 0, "BalancerPoolerV2: donation dust");

271:         require(sUSDSAmount > 0, "BalancerPoolerV2: nothing to pool");

279:         require(msg.sender == _vault, "BalancerPoolerV2: caller is not vault");

351:         require(to != address(0), "BalancerPoolerV2: zero recipient");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

27:         require(recipient_ != address(0), "GatherV2: zero recipient address");

45:         require(newRecipient != address(0), "GatherV2: zero recipient address");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

67:         require(dispatcher_ != address(0), "dispatcher=0");

68:         require(phUSD_ != address(0), "phUSD=0");

99:         require(newDispatcher != address(0), "dispatcher=0");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

26:         require(msg.sender == _minter, "ATokenDispatcher: caller is not minter");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

59:         require(msg.sender == _vault, "BalancerPooler: caller is not vault");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Gather.sol

28:         require(recipient_ != address(0), "Gather: zero recipient address");

46:         require(newRecipient != address(0), "Gather: zero recipient address");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="GAS-9"></a>[GAS-9] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (14)*:
```solidity
File: NFTMinter.sol

183:         uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);

185:         uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

260:         uint256 balance = IERC20(token).balanceOf(address(this));

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

66:             uint256 balance = IERC1155(address(v1)).balanceOf(msg.sender, i);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

182:         uint256 balanceBefore = IERC20(token).balanceOf(config.dispatcher);

184:         uint256 actualReceived = IERC20(token).balanceOf(config.dispatcher) - balanceBefore;

300:         uint256 balance = IERC20(token).balanceOf(address(this));

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

224:             uint256 remainingUSDS = IERC20(_primeToken).balanceOf(address(this));

270:         uint256 sUSDSAmount = IERC20(_sUSDS).balanceOf(address(this));

285:             uint256 vaultBefore = IERC20(_sUSDS).balanceOf(_vault);

287:             uint256 actualInVault = IERC20(_sUSDS).balanceOf(_vault) - vaultBefore;

319:         uint256 sUSDSAmount = IERC20(_sUSDS).balanceOf(address(this));

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: dispatchers/BalancerPooler.sol

64:         uint256 vaultPrimeBefore = IERC20(_primeToken).balanceOf(_vault);

66:         uint256 actualPrimeInVault = IERC20(_primeToken).balanceOf(_vault) - vaultPrimeBefore;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

### <a name="GAS-10"></a>[GAS-10] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (7)*:
```solidity
File: NFTMinter.sol

100:         address oldPauser = pauser;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

105:         address oldPauser = pauser;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

46:         address oldRecipient = _recipient;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

79:         uint8 old = ratio;

88:         address old = recipient;

100:         address old = dispatcher;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/Gather.sol

47:         address oldRecipient = _recipient;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="GAS-11"></a>[GAS-11] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (18)*:
```solidity
File: V2/NFTMigrator.sol

26:         v1 = INFTMinter(v1Minter);

27:         v2 = INFTMinterV2(v2Minter);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

101:         _sUSDS = sUSDS_;

102:         _primeToken = IERC4626(sUSDS_).asset();

104:         _vault = vault_;

105:         _router = router_;

106:         _sUSDSIsFirst = sUSDSIsFirst_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

18:         _token = token_;

19:         _burnRecorder = IBurnRecorder(burnRecorder_);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

28:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

70:         phUSD = IMintable(phUSD_);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/BalancerPooler.sol

31:         _primeToken = primeToken_;

32:         _pool = pool_;

33:         _vault = vault_;

34:         _primeTokenIsFirst = primeTokenIsFirst_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

19:         _token = token_;

20:         _burnRecorder = IBurnRecorder(burnRecorder_);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

```solidity
File: dispatchers/Gather.sol

29:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="GAS-12"></a>[GAS-12] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (48)*:
```solidity
File: BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {

50:     function burn(address token, uint256 amount) external onlyBurner {

65:     function registerToken(address token) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

99:     function setPauser(address newPauser) external onlyOwner {

150:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {

242:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {

250:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {

259:     function emergencyWithdraw(address token) external onlyOwner {

269:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {

292:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

33:     function setMapping(uint256 v1Index, uint256 v2Index) external onlyOwner {

41:     function setMappings(uint256[] calldata v1Indexes, uint256[] calldata v2Indexes) external onlyOwner {

51:     function setInitialized() external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

85:     function setMinter(address minter_) external onlyOwner {

94:     function setHook(IDispatchHook newHook) external onlyOwner {

102:     function pause() external onlyMinter {

107:     function unpause() external onlyMinter {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

132:     function setPool(address newPool) external onlyOwner {

140:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

152:     function incrementAuthVersion() external onlyOwner {

160:     function setBatchDonationSize(uint256 newSize) external onlyOwner {

169:     function setBatchMinter(address newBatchMinter) external onlyOwner {

177:     function setPSM(address newPSM) external onlyOwner {

185:     function setMaxTout(uint256 newMaxTout) external onlyOwner {

269:     function pool(uint256 minBPT) external onlyAuthorizedPooler whenNotPaused nonReentrant {

337:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

350:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

44:     function setRecipient(address newRecipient) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

77:     function setRatio(uint8 newRatio) external onlyOwner {

87:     function setRecipient(address newRecipient) external onlyOwner {

98:     function setDispatcher(address newDispatcher) external onlyOwner {

120:     function pull() external onlyOwnerOrRecipient nonReentrant {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

37:     function setMetadata(string calldata name_, string calldata image_, string calldata description_) external onlyOwner {

61:     function setMinter(address minter_) external onlyOwner {

66:     function pause() external onlyMinter {

71:     function unpause() external onlyMinter {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

50:     function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {

96:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Gather.sol

45:     function setRecipient(address newRecipient) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

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

*Instances (7)*:
```solidity
File: BurnRecorder.sol

67:         _latestIndex++;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

128:         nextIndex++;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

43:         for (uint256 i = 0; i < v1Indexes.length; i++) {

53:         for (uint256 i = 1; i < upperBound; i++) {

65:         for (uint256 i = 1; i < upperBound; i++) {

70:                 for (uint256 j = 0; j < balance; j++) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

133:         nextIndex++;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="GAS-14"></a>[GAS-14] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

24:     uint8 public constant MAX_RATIO = 50;

27:     uint8 public constant DEFAULT_RATIO = 50;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

### <a name="GAS-15"></a>[GAS-15] Superfluous event fields
`block.timestamp` and `block.number` are added to event information by default so adding them manually wastes gas

*Instances (1)*:
```solidity
File: BurnRecorder.sol

28:     event tokenBurnt(address indexed token, uint256 quantity, uint256 timestamp);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

### <a name="GAS-16"></a>[GAS-16] Use of `this` instead of marking as `public` an `external` function
Using `this.` is like making an expensive external call. Consider marking the called function as public

*Saves around 2000 gas per instance*

*Instances (1)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

226:                 try this._psmDonate(remainingUSDS) {}

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

### <a name="GAS-17"></a>[GAS-17] Increments/decrements can be unchecked in for-loops
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

*Instances (4)*:
```solidity
File: V2/NFTMigrator.sol

43:         for (uint256 i = 0; i < v1Indexes.length; i++) {

53:         for (uint256 i = 1; i < upperBound; i++) {

65:         for (uint256 i = 1; i < upperBound; i++) {

70:                 for (uint256 j = 0; j < balance; j++) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

### <a name="GAS-18"></a>[GAS-18] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (10)*:
```solidity
File: NFTMinter.sol

261:         require(balance > 0, "NFTMinter: no tokens to withdraw");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

67:             if (balance > 0) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

301:         require(balance > 0, "NFTMinterV2: no tokens to withdraw");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

210:         bool donationEnabled = batchMinter != address(0) && psm != address(0) && batchDonationSize > 0;

216:         if (poolingUSDS > 0) {

225:             if (remainingUSDS > 0) {

254:         require(gemAmt > 0, "BalancerPoolerV2: donation dust");

271:         require(sUSDSAmount > 0, "BalancerPoolerV2: nothing to pool");

284:         if (sUSDSAmount > 0) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: dispatchers/BalancerPooler.sol

51:         uint256 minBptAmountOut = extraData.length > 0 ? abi.decode(extraData, (uint256)) : 0;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 2 |
| [NC-2](#NC-2) | Missing checks for `address(0)` when assigning values to address state variables | 13 |
| [NC-3](#NC-3) | Array indices should be referenced via `enum`s rather than via numeric literals | 12 |
| [NC-4](#NC-4) | Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked` | 2 |
| [NC-5](#NC-5) | `constant`s should be defined rather than using magic numbers | 5 |
| [NC-6](#NC-6) | Control structures do not follow the Solidity Style Guide | 8 |
| [NC-7](#NC-7) | Consider disabling `renounceOwnership()` | 7 |
| [NC-8](#NC-8) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 22 |
| [NC-9](#NC-9) | Events should use parameters to convey information | 1 |
| [NC-10](#NC-10) | Event missing indexed field | 10 |
| [NC-11](#NC-11) | Events that mark critical parameter changes should contain both the old and the new value | 30 |
| [NC-12](#NC-12) | Function ordering does not follow the Solidity style guide | 4 |
| [NC-13](#NC-13) | Functions should not be longer than 50 lines | 146 |
| [NC-14](#NC-14) | Change int to int256 | 4 |
| [NC-15](#NC-15) | Lack of checks in setters | 14 |
| [NC-16](#NC-16) | Missing Event for critical parameters change | 4 |
| [NC-17](#NC-17) | Incomplete NatSpec: `@param` is missing on actually documented functions | 3 |
| [NC-18](#NC-18) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 16 |
| [NC-19](#NC-19) | Consider using named mappings | 15 |
| [NC-20](#NC-20) | Owner can renounce while system is paused | 2 |
| [NC-21](#NC-21) | Adding a `return` statement when the function defines a named return variable, is redundant | 1 |
| [NC-22](#NC-22) | Take advantage of Custom Error's return value property | 4 |
| [NC-23](#NC-23) | Strings should use double quotes rather than single quotes | 8 |
| [NC-24](#NC-24) | Contract does not follow the Solidity style guide's suggested layout ordering | 3 |
| [NC-25](#NC-25) | Use Underscores for Number Literals (add an underscore every 3 digits) | 2 |
| [NC-26](#NC-26) | Internal and private variables and functions names should begin with an underscore | 2 |
| [NC-27](#NC-27) | Event is missing `indexed` fields | 33 |
| [NC-28](#NC-28) | Constants should be defined rather than using magic numbers | 2 |
| [NC-29](#NC-29) | `public` functions not called by the contract should be declared `external` instead | 3 |
| [NC-30](#NC-30) | Variables need not be initialized to zero | 2 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (2)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

273:         bytes memory data = abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, innerData);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: dispatchers/BalancerPooler.sol

53:         bytes memory data = abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, innerData);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

### <a name="NC-2"></a>[NC-2] Missing checks for `address(0)` when assigning values to address state variables

*Instances (13)*:
```solidity
File: NFTMinter.sol

101:         pauser = newPauser;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

106:         pauser = newPauser;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

86:         _minter = minter_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

103:         _pool = pool_;

104:         _vault = vault_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

18:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

28:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

62:         _minter = minter_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

31:         _primeToken = primeToken_;

32:         _pool = pool_;

33:         _vault = vault_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

19:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

```solidity
File: dispatchers/Gather.sol

29:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="NC-3"></a>[NC-3] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (12)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

291:                 maxAmountsIn[0] = actualInVault;

292:                 maxAmountsIn[1] = 0;

294:                 maxAmountsIn[0] = 0;

295:                 maxAmountsIn[1] = actualInVault;

324:             exactAmountsIn[0] = sUSDSAmount;

325:             exactAmountsIn[1] = 0;

327:             exactAmountsIn[0] = 0;

328:             exactAmountsIn[1] = sUSDSAmount;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: dispatchers/BalancerPooler.sol

71:             maxAmountsIn[0] = actualPrimeInVault;

72:             maxAmountsIn[1] = 0;

74:             maxAmountsIn[0] = 0;

75:             maxAmountsIn[1] = actualPrimeInVault;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

### <a name="NC-4"></a>[NC-4] Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked`
Solidity version 0.8.4 introduces `bytes.concat()` (vs `abi.encodePacked(<bytes>,<bytes>)`)

Solidity version 0.8.12 introduces `string.concat()` (vs `abi.encodePacked(<str>,<str>), which catches concatenation errors (in the event of a `bytes` data mixed in the concatenation)`)

*Instances (2)*:
```solidity
File: NFTMinter.sol

218:             abi.encodePacked(

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

263:             abi.encodePacked(

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="NC-5"></a>[NC-5] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (5)*:
```solidity
File: NFTMinter.sol

189:         config.price = price + (price * config.growthBasisPoints) / 10000;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

188:         config.price = price + (price * config.growthBasisPoints) / 10000;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

161:         require(newSize <= 100, "BalancerPoolerV2: size > 100");

212:         uint256 donationUSDS = donationEnabled ? (amount * batchDonationSize) / 100 : 0;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

111:         uint256 added = (amount * ratio) / 100;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

### <a name="NC-6"></a>[NC-6] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (8)*:
```solidity
File: NFTMinter.sol

24:         bool disabled; // if true, new mints are blocked but existing NFTs remain valid

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

24:         bool disabled; // if true, new mints are blocked but existing NFTs remain valid

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

320:         if (sUSDSAmount == 0) return 0;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

78:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

110:         if (msg.sender != dispatcher) revert OnlyDispatcher();

112:         if (added == 0) return;

121:         if (recipient == address(0)) revert RecipientUnset();

123:         if (debt == 0) return;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

### <a name="NC-7"></a>[NC-7] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (7)*:
```solidity
File: BurnRecorder.sol

11: contract BurnRecorder is IBurnRecorder, Ownable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

16: contract NFTMinter is ERC1155Supply, Ownable, INFTMinter, IPausable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

12: contract NFTMigrator is Ownable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

16: contract NFTMinterV2 is ERC1155Supply, Ownable, INFTMinterV2, IPausable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

23: abstract contract ATokenDispatcherV2 is ITokenDispatcherV2, Pausable, Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

22: contract BalancerPoolerMintDebtHook is IDispatchHook, IBalancerPoolerMintDebtHook, Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

12: abstract contract ATokenDispatcher is ITokenDispatcher, Pausable, Ownable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

### <a name="NC-8"></a>[NC-8] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (22)*:
```solidity
File: NFTMinter.sol

107:         require(msg.sender == pauser, "Only pauser");

114:         require(msg.sender == pauser, "Only pauser");

151:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

173:         require(config.dispatcher != address(0), "NFTMinter: index not registered");

232:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

243:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

251:         require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

27:         require(recipient_ != address(0), "GatherV2: zero recipient address");

45:         require(newRecipient != address(0), "GatherV2: zero recipient address");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

67:         require(dispatcher_ != address(0), "dispatcher=0");

99:         require(newDispatcher != address(0), "dispatcher=0");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/Gather.sol

28:         require(recipient_ != address(0), "Gather: zero recipient address");

46:         require(newRecipient != address(0), "Gather: zero recipient address");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="NC-9"></a>[NC-9] Events should use parameters to convey information
For example, rather than using `event Paused()` and `event Unpaused()`, use `event PauseState(address indexed whoChangedIt, bool wasPaused, bool isNowPaused)`

*Instances (1)*:
```solidity
File: V2/NFTMigrator.sol

19:     event Initialized();

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

### <a name="NC-10"></a>[NC-10] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (10)*:
```solidity
File: V2/NFTMigrator.sol

18:     event MappingSet(uint256 v1Index, uint256 v2Index);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

38:     event MetadataUpdated(string name, string image, string description);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

70:     event AuthVersionIncremented(uint256 newAuthVersion);

73:     event BatchDonationSizeSet(uint256 newSize);

74:     event BatchMinterSet(address newBatchMinter);

75:     event PSMSet(address newPSM);

76:     event MaxToutSet(uint256 newMaxTout);

84:     event DonationSkipped(uint256 usdsParked);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

45:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

22:     event MetadataUpdated(string name, string image, string description);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

### <a name="NC-11"></a>[NC-11] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (30)*:
```solidity
File: NFTMinter.sol

99:     function setPauser(address newPauser) external onlyOwner {
            address oldPauser = pauser;
            pauser = newPauser;
            emit PauserChanged(oldPauser, newPauser);

150:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {
             require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");
             configs[index].disabled = disabled;
             emit DispatcherDisabledChanged(index, disabled);

242:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {
             require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");
             uint256 oldPrice = configs[index].price;
             configs[index].price = newPrice;
             emit PriceUpdated(index, oldPrice, newPrice);

250:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {
             require(configs[index].dispatcher != address(0), "NFTMinter: index not registered");
             uint256 oldGrowthBasisPoints = configs[index].growthBasisPoints;
             configs[index].growthBasisPoints = newGrowthBasisPoints;
             emit GrowthFactorUpdated(index, oldGrowthBasisPoints, newGrowthBasisPoints);

269:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {
             require(dispatcherToIndex[dispatcher] != 0, "NFTMinter: dispatcher not registered");
     
             ATokenDispatcher dispatcherContract = ATokenDispatcher(dispatcher);
     
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

292:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {
             authorizedBurners[burner] = authorized;
             emit AuthorizedBurnerSet(burner, authorized);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

33:     function setMapping(uint256 v1Index, uint256 v2Index) external onlyOwner {
            indexMapping[v1Index] = v2Index;
            emit MappingSet(v1Index, v2Index);

41:     function setMappings(uint256[] calldata v1Indexes, uint256[] calldata v2Indexes) external onlyOwner {
            require(v1Indexes.length == v2Indexes.length, "NFTMigrator: array length mismatch");
            for (uint256 i = 0; i < v1Indexes.length; i++) {
                indexMapping[v1Indexes[i]] = v2Indexes[i];
                emit MappingSet(v1Indexes[i], v2Indexes[i]);

51:     function setInitialized() external onlyOwner {
            uint256 upperBound = v1.nextIndex();
            for (uint256 i = 1; i < upperBound; i++) {
                require(indexMapping[i] != 0, "NFTMigrator: missing mapping");
            }
            initialized = true;
            emit Initialized();

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

140:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "BalancerPoolerV2: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);
             } else {
                 delete poolerAuthVersion[pooler];
                 emit PoolerDeauthorized(pooler);

140:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
             require(pooler != address(0), "BalancerPoolerV2: zero pooler");
             if (authorized) {
                 poolerAuthVersion[pooler] = authVersion;
                 emit PoolerAuthorized(pooler, authVersion);

160:     function setBatchDonationSize(uint256 newSize) external onlyOwner {
             require(newSize <= 100, "BalancerPoolerV2: size > 100");
             batchDonationSize = newSize;
             emit BatchDonationSizeSet(newSize);

169:     function setBatchMinter(address newBatchMinter) external onlyOwner {
             batchMinter = newBatchMinter;
             emit BatchMinterSet(newBatchMinter);

177:     function setPSM(address newPSM) external onlyOwner {
             require(newPSM != address(0), "BalancerPoolerV2: zero psm");
             psm = newPSM;
             emit PSMSet(newPSM);

185:     function setMaxTout(uint256 newMaxTout) external onlyOwner {
             maxTout = newMaxTout;
             emit MaxToutSet(newMaxTout);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

44:     function setRecipient(address newRecipient) external onlyOwner {
            require(newRecipient != address(0), "GatherV2: zero recipient address");
            address oldRecipient = _recipient;
            _recipient = newRecipient;
            emit RecipientUpdated(oldRecipient, newRecipient);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

37:     function setMetadata(string calldata name_, string calldata image_, string calldata description_) external onlyOwner {
            _name = name_;
            _image = image_;
            _description = description_;
            emit MetadataUpdated(name_, image_, description_);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/Gather.sol

45:     function setRecipient(address newRecipient) external onlyOwner {
            require(newRecipient != address(0), "Gather: zero recipient address");
            address oldRecipient = _recipient;
            _recipient = newRecipient;
            emit RecipientUpdated(oldRecipient, newRecipient);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="NC-12"></a>[NC-12] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (4)*:
```solidity
File: BurnRecorder.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

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
   public uri
   external getPrice
   external getDispatchers
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
   external getPrice
   external getDispatchers
   external setPrice
   external setGrowthFactor
   external emergencyWithdraw
   external setDispatcherActive
   external setAuthorizedBurner
   external burn
   public uri
   internal _executeMint

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

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
   external _psmDonate
   external pool
   external unlockCallback
   external getIdealBPT
   external withdrawBPT
   external rescueERC20
   internal _dispatch

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

### <a name="NC-13"></a>[NC-13] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (146)*:
```solidity
File: BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {

50:     function burn(address token, uint256 amount) external onlyBurner {

58:     function getTotalBurnt(address token) public view returns (uint256) {

65:     function registerToken(address token) external onlyOwner {

72:     function getTokenCount() public view returns (uint256) {

79:     function getTokenAtIndex(uint256 index) public view returns (address) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

99:     function setPauser(address newPauser) external onlyOwner {

120:     function registerDispatcher(address dispatcher, uint256 initialPrice, uint256 growthBasisPoints)

150:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {

157:     function mint(address token, uint256 index, address recipient) external returns (bool) {

162:     function mint(address token, uint256 index, address recipient, bytes calldata extraData) external returns (bool) {

167:     function _executeMint(address token, uint256 index, address recipient, bytes memory extraData)

207:     function uri(uint256 id) public view override returns (string memory) {

231:     function getPrice(uint256 index) external view returns (uint256) {

237:     function getDispatchers(address token) external view returns (uint256[] memory) {

242:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {

250:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {

259:     function emergencyWithdraw(address token) external onlyOwner {

269:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {

292:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {

301:     function burn(address holder, uint256 tokenId, uint256 quantity) external {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

33:     function setMapping(uint256 v1Index, uint256 v2Index) external onlyOwner {

41:     function setMappings(uint256[] calldata v1Indexes, uint256[] calldata v2Indexes) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

58:     function setMetadata(string calldata name_, string calldata image_, string calldata description_)

69:     function name() external view returns (string memory) {

74:     function image() external view returns (string memory) {

79:     function description() external view returns (string memory) {

85:     function setMinter(address minter_) external onlyOwner {

94:     function setHook(IDispatchHook newHook) external onlyOwner {

118:     function dispatch(address minter, uint256 amount, bytes calldata extraData)

132:     function _dispatch(address minter, uint256 amount, bytes calldata extraData) internal virtual {}

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

111:     function primeToken() external view override returns (address) {

116:     function sUSDS() external view returns (address) {

121:     function vault() external view returns (address) {

132:     function setPool(address newPool) external onlyOwner {

140:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

152:     function incrementAuthVersion() external onlyOwner {

160:     function setBatchDonationSize(uint256 newSize) external onlyOwner {

169:     function setBatchMinter(address newBatchMinter) external onlyOwner {

177:     function setPSM(address newPSM) external onlyOwner {

185:     function setMaxTout(uint256 newMaxTout) external onlyOwner {

240:     function _psmDonate(uint256 usdsAmount) external {

269:     function pool(uint256 minBPT) external onlyAuthorizedPooler whenNotPaused nonReentrant {

278:     function unlockCallback(bytes calldata data) external returns (bytes memory) {

318:     function getIdealBPT() external returns (uint256 bptAmountOut) {

337:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

350:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

23:     function primeToken() external view returns (address) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

33:     function primeToken() external view returns (address) {

38:     function recipient() external view returns (address) {

44:     function setRecipient(address newRecipient) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

77:     function setRatio(uint8 newRatio) external onlyOwner {

87:     function setRecipient(address newRecipient) external onlyOwner {

98:     function setDispatcher(address newDispatcher) external onlyOwner {

109:     function onDispatch(address minter, uint256 amount, bytes calldata) external {

120:     function pull() external onlyOwnerOrRecipient nonReentrant {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: V2/hooks/DefaultDispatchHook.sol

12:     function onDispatch(address, uint256, bytes calldata) external {}

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/DefaultDispatchHook.sol)

```solidity
File: V2/interfaces/IBalancerPoolerMintDebtHook.sol

10:     function mintDebt() external view returns (uint256);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/interfaces/IBalancerPoolerMintDebtHook.sol)

```solidity
File: V2/interfaces/IDispatchHook.sol

11:     function onDispatch(address minter, uint256 amount, bytes calldata extraData) external;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/interfaces/IDispatchHook.sol)

```solidity
File: V2/interfaces/INFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/interfaces/INFTMinterV2.sol)

```solidity
File: V2/interfaces/ISkyPSM.sol

32:     function buyGem(address usr, uint256 gemAmt) external returns (uint256 usdsInWad);

36:     function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOutWad);

45:     function to18ConversionFactor() external view returns (uint256);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/interfaces/ISkyPSM.sol)

```solidity
File: V2/interfaces/ITokenDispatcherV2.sol

6:     function primeToken() external view returns (address);

9:     function name() external view returns (string memory);

12:     function image() external view returns (string memory);

15:     function description() external view returns (string memory);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/interfaces/ITokenDispatcherV2.sol)

```solidity
File: V2/interfaces/ITokenMinterV2.sol

9:     function mint(uint256 index, address recipient) external returns (bool);

16:     function mint(uint256 index, address recipient, bytes calldata extraData) external returns (bool);

22:     function registerDispatcher(address dispatcher, uint256 initialPrice, uint256 growthBasisPoints) external;

27:     function getPrice(uint256 index) external view returns (uint256);

32:     function setPrice(uint256 index, uint256 newPrice) external;

37:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/interfaces/ITokenMinterV2.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

37:     function setMetadata(string calldata name_, string calldata image_, string calldata description_) external onlyOwner {

45:     function name() external view returns (string memory) {

50:     function image() external view returns (string memory) {

55:     function description() external view returns (string memory) {

61:     function setMinter(address minter_) external onlyOwner {

79:     function dispatch(address minter, uint256 amount, bytes calldata extraData)

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

38:     function primeToken() external view returns (address) {

43:     function vault() external view returns (address) {

50:     function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {

58:     function unlockCallback(bytes calldata data) external returns (bytes memory) {

96:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

24:     function primeToken() external view returns (address) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

```solidity
File: dispatchers/Gather.sol

34:     function primeToken() external view returns (address) {

39:     function recipient() external view returns (address) {

45:     function setRecipient(address newRecipient) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

```solidity
File: interfaces/IBurnRecorder.sol

8:     function burn(address token, uint256 amount) external;

13:     function setBurner(address burner_, bool approved_) external;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/IBurnRecorder.sol)

```solidity
File: interfaces/IMintable.sol

5:     function mint(address recipient, uint256 amount) external;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/IMintable.sol)

```solidity
File: interfaces/INFTMinter.sol

15:     function burn(address holder, uint256 tokenId, uint256 quantity) external;

20:     function authorizedBurners(address burner) external view returns (bool);

25:     function setAuthorizedBurner(address burner, bool authorized) external;

36:     function setDispatcherDisabled(uint256 index, bool disabled) external;

40:     function emergencyWithdraw(address token) external;

45:     function setDispatcherActive(address dispatcher, bool active) external;

53:     function nextIndex() external view returns (uint256);

61:     function configs(uint256 index) external view returns (address dispatcher, uint256 price, uint256 growthBasisPoints, bool disabled);

66:     function dispatcherToIndex(address dispatcher) external view returns (uint256);

71:     function tokenIdToDispatcher(uint256 tokenId) external view returns (address);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/INFTMinter.sol)

```solidity
File: interfaces/ITokenDispatcher.sol

6:     function primeToken() external view returns (address);

9:     function name() external view returns (string memory);

12:     function image() external view returns (string memory);

15:     function description() external view returns (string memory);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/ITokenDispatcher.sol)

```solidity
File: interfaces/ITokenMinter.sol

10:     function mint(address token, uint256 index, address recipient) external returns (bool);

18:     function mint(address token, uint256 index, address recipient, bytes calldata extraData) external returns (bool);

24:     function registerDispatcher(address dispatcher, uint256 initialPrice, uint256 growthBasisPoints) external;

29:     function getPrice(uint256 index) external view returns (uint256);

34:     function getDispatchers(address token) external view returns (uint256[] memory);

39:     function setPrice(uint256 index, uint256 newPrice) external;

44:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/ITokenMinter.sol)

```solidity
File: interfaces/balancer/IBalancerVault.sol

8:     function unlock(bytes calldata data) external returns (bytes memory result);

9:     function addLiquidity(AddLiquidityParams memory params)

15:     function settle(IERC20 token, uint256 amountHint) external returns (uint256 credit);

16:     function sendTo(IERC20 token, address to, uint256 amount) external;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/balancer/IBalancerVault.sol)

```solidity
File: interfaces/balancer/IUnlockCallback.sol

5:     function unlockCallback(bytes calldata data) external returns (bytes memory result);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/balancer/IUnlockCallback.sol)

### <a name="NC-14"></a>[NC-14] Change int to int256
Throughout the code base, some variables are declared as `int`. To favor explicitness, consider changing all instances of `int` to `int256`

*Instances (4)*:
```solidity
File: NFTMinter.sol

22:         uint256 price; // current mint price in token units (18 decimals)

23:         uint256 growthBasisPoints; // price growth per mint in basis points (100 = 1%)

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

22:         uint256 price; // current mint price in token units (18 decimals)

23:         uint256 growthBasisPoints; // price growth per mint in basis points (100 = 1%)

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="NC-15"></a>[NC-15] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (14)*:
```solidity
File: BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {
            _burners[burner_] = approved_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

99:     function setPauser(address newPauser) external onlyOwner {
            address oldPauser = pauser;
            pauser = newPauser;
            emit PauserChanged(oldPauser, newPauser);

292:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {
             authorizedBurners[burner] = authorized;
             emit AuthorizedBurnerSet(burner, authorized);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

33:     function setMapping(uint256 v1Index, uint256 v2Index) external onlyOwner {
            indexMapping[v1Index] = v2Index;
            emit MappingSet(v1Index, v2Index);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

169:     function setBatchMinter(address newBatchMinter) external onlyOwner {
             batchMinter = newBatchMinter;
             emit BatchMinterSet(newBatchMinter);

185:     function setMaxTout(uint256 newMaxTout) external onlyOwner {
             maxTout = newMaxTout;
             emit MaxToutSet(newMaxTout);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

87:     function setRecipient(address newRecipient) external onlyOwner {
            address old = recipient;
            recipient = newRecipient;
            emit RecipientUpdated(old, newRecipient);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

37:     function setMetadata(string calldata name_, string calldata image_, string calldata description_) external onlyOwner {
            _name = name_;
            _image = image_;
            _description = description_;
            emit MetadataUpdated(name_, image_, description_);

61:     function setMinter(address minter_) external onlyOwner {
            _minter = minter_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

### <a name="NC-16"></a>[NC-16] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (4)*:
```solidity
File: BurnRecorder.sol

42:     function setBurner(address burner_, bool approved_) external onlyOwner {
            _burners[burner_] = approved_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

85:     function setMinter(address minter_) external onlyOwner {
            _minter = minter_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

132:     function setPool(address newPool) external onlyOwner {
             require(newPool != address(0), "BalancerPoolerV2: zero pool address");
             _pool = newPool;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

61:     function setMinter(address minter_) external onlyOwner {
            _minter = minter_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

### <a name="NC-17"></a>[NC-17] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (3)*:
```solidity
File: dispatchers/BalancerPooler.sol

47:     /// @notice Dispatches tokens (already on this contract) to the Balancer pool via unlock pattern.
        /// @param amount The FOT-adjusted amount of prime token to dispatch.
        /// @param extraData Optional ABI-encoded uint256 for minBptAmountOut slippage protection.
        function dispatch(address, uint256 amount, bytes calldata extraData) external override onlyMinter whenNotPaused {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

28:     /// @notice Burns tokens already on this contract and records the burn.
        /// @param amount The FOT-adjusted amount of prime token to burn.
        function dispatch(
            address,
            uint256 amount,
            bytes calldata /* extraData */

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

```solidity
File: dispatchers/Gather.sol

52:     /// @notice Forwards tokens (already on this contract) to the recipient.
        /// @param amount The FOT-adjusted amount of prime token to forward.
        function dispatch(
            address,
            uint256 amount,
            bytes calldata /* extraData */

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="NC-18"></a>[NC-18] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (16)*:
```solidity
File: BurnRecorder.sol

32:         require(_burners[msg.sender], "BurnRecorder: caller is not burner");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

107:         require(msg.sender == pauser, "Only pauser");

114:         require(msg.sender == pauser, "Only pauser");

302:         require(authorizedBurners[msg.sender], "NFTMinter: caller is not authorized burner");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

112:         require(msg.sender == pauser, "Only pauser");

119:         require(msg.sender == pauser, "Only pauser");

207:         require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");

342:         require(authorizedBurners[msg.sender], "NFTMinterV2: caller is not authorized burner");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

45:         require(msg.sender == _minter, "ATokenDispatcherV2: caller is not minter");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

87:         require(poolerAuthVersion[msg.sender] == authVersion, "BalancerPoolerV2: caller not authorized pooler");

241:         require(msg.sender == address(this), "BalancerPoolerV2: only self");

279:         require(msg.sender == _vault, "BalancerPoolerV2: caller is not vault");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

57:         if (msg.sender != owner() && msg.sender != recipient) {

110:         if (msg.sender != dispatcher) revert OnlyDispatcher();

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

26:         require(msg.sender == _minter, "ATokenDispatcher: caller is not minter");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

59:         require(msg.sender == _vault, "BalancerPooler: caller is not vault");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

### <a name="NC-19"></a>[NC-19] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (15)*:
```solidity
File: BurnRecorder.sol

13:     mapping(address => bool) private _burners;

16:     mapping(address => uint256) private totalBurnt;

19:     mapping(uint256 => address) private tokenIndex;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

31:     mapping(uint256 => DispatcherConfig) public configs;

34:     mapping(address => uint256) public dispatcherToIndex;

37:     mapping(address => uint256[]) internal _tokenToIndexes;

40:     mapping(uint256 => address) public tokenIdToDispatcher;

43:     mapping(address => bool) public authorizedBurners;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

16:     mapping(uint256 => uint256) public indexMapping;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

31:     mapping(uint256 => DispatcherConfig) public configs;

34:     mapping(address => uint256) public dispatcherToIndex;

37:     mapping(uint256 => address) public tokenIdToDispatcher;

40:     mapping(address => bool) public authorizedBurners;

43:     mapping(address => bool) public authorizedMinters;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

46:     mapping(address => uint256) public poolerAuthVersion;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

### <a name="NC-20"></a>[NC-20] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (2)*:
```solidity
File: NFTMinter.sol

99:     function setPauser(address newPauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="NC-21"></a>[NC-21] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (1)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

316:     /// @notice Queries the Balancer Router for the expected BPT output from pooling current sUSDS balance.
         /// @return bptAmountOut The expected BPT amount, or 0 if sUSDS balance is 0.
         function getIdealBPT() external returns (uint256 bptAmountOut) {
             uint256 sUSDSAmount = IERC20(_sUSDS).balanceOf(address(this));
             if (sUSDSAmount == 0) return 0;
     
             uint256[] memory exactAmountsIn = new uint256[](2);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

### <a name="NC-22"></a>[NC-22] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (4)*:
```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

58:             revert OnlyOwnerOrRecipient();

78:         if (newRatio > MAX_RATIO) revert RatioTooHigh();

110:         if (msg.sender != dispatcher) revert OnlyDispatcher();

121:         if (recipient == address(0)) revert RecipientUnset();

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

### <a name="NC-23"></a>[NC-23] Strings should use double quotes rather than single quotes
See the Solidity Style Guide: https://docs.soliditylang.org/en/v0.8.20/style-guide.html#other-recommendations

*Instances (8)*:
```solidity
File: NFTMinter.sol

219:                 '{"name":"',

221:                 '","image":"',

223:                 '","description":"',

225:                 '"}'

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

264:                 '{"name":"',

266:                 '","image":"',

268:                 '","description":"',

270:                 '"}'

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="NC-24"></a>[NC-24] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (3)*:
```solidity
File: NFTMinter.sol

1: 
   Current order:
   UsingForDirective.IERC20
   StructDefinition.DispatcherConfig
   VariableDeclaration.nextIndex
   VariableDeclaration.configs
   VariableDeclaration.dispatcherToIndex
   VariableDeclaration._tokenToIndexes
   VariableDeclaration.tokenIdToDispatcher
   VariableDeclaration.authorizedBurners
   EventDefinition.DispatcherRegistered
   EventDefinition.ClaimMinted
   EventDefinition.PriceUpdated
   EventDefinition.GrowthFactorUpdated
   EventDefinition.EmergencyWithdraw
   EventDefinition.DispatcherActiveChanged
   EventDefinition.PauserChanged
   EventDefinition.Paused
   EventDefinition.Unpaused
   EventDefinition.DispatcherDisabledChanged
   EventDefinition.AuthorizedBurnerSet
   EventDefinition.ClaimBurned
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
   FunctionDefinition.uri
   FunctionDefinition.getPrice
   FunctionDefinition.getDispatchers
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
   VariableDeclaration._tokenToIndexes
   VariableDeclaration.tokenIdToDispatcher
   VariableDeclaration.authorizedBurners
   VariableDeclaration.pauser
   VariableDeclaration.paused
   StructDefinition.DispatcherConfig
   EventDefinition.DispatcherRegistered
   EventDefinition.ClaimMinted
   EventDefinition.PriceUpdated
   EventDefinition.GrowthFactorUpdated
   EventDefinition.EmergencyWithdraw
   EventDefinition.DispatcherActiveChanged
   EventDefinition.PauserChanged
   EventDefinition.Paused
   EventDefinition.Unpaused
   EventDefinition.DispatcherDisabledChanged
   EventDefinition.AuthorizedBurnerSet
   EventDefinition.ClaimBurned
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.registerDispatcher
   FunctionDefinition.setDispatcherDisabled
   FunctionDefinition.mint
   FunctionDefinition.mint
   FunctionDefinition._executeMint
   FunctionDefinition.uri
   FunctionDefinition.getPrice
   FunctionDefinition.getDispatchers
   FunctionDefinition.setPrice
   FunctionDefinition.setGrowthFactor
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.setDispatcherActive
   FunctionDefinition.setAuthorizedBurner
   FunctionDefinition.burn

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

### <a name="NC-25"></a>[NC-25] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (2)*:
```solidity
File: NFTMinter.sol

189:         config.price = price + (price * config.growthBasisPoints) / 10000;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

188:         config.price = price + (price * config.growthBasisPoints) / 10000;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="NC-26"></a>[NC-26] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (2)*:
```solidity
File: BurnRecorder.sol

16:     mapping(address => uint256) private totalBurnt;

19:     mapping(uint256 => address) private tokenIndex;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

### <a name="NC-27"></a>[NC-27] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (33)*:
```solidity
File: BurnRecorder.sol

28:     event tokenBurnt(address indexed token, uint256 quantity, uint256 timestamp);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

60:     event PriceUpdated(uint256 indexed index, uint256 oldPrice, uint256 newPrice);

63:     event GrowthFactorUpdated(uint256 indexed index, uint256 oldGrowthBasisPoints, uint256 newGrowthBasisPoints);

66:     event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

69:     event DispatcherActiveChanged(address indexed dispatcher, bool active);

81:     event DispatcherDisabledChanged(uint256 indexed index, bool disabled);

84:     event AuthorizedBurnerSet(address indexed burner, bool authorized);

87:     event ClaimBurned(address indexed holder, uint256 indexed tokenId, uint256 quantity);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

18:     event MappingSet(uint256 v1Index, uint256 v2Index);

20:     event Migrated(address indexed user, uint256 v1Index, uint256 quantity, uint256 v2Index);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

38:     event MetadataUpdated(string name, string image, string description);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

68:     event PoolerAuthorized(address indexed pooler, uint256 atAuthVersion);

70:     event AuthVersionIncremented(uint256 newAuthVersion);

71:     event Pooled(address indexed pooler, uint256 sUSDSPooled, uint256 bptReceived, uint256 minBPT);

73:     event BatchDonationSizeSet(uint256 newSize);

74:     event BatchMinterSet(address newBatchMinter);

75:     event PSMSet(address newPSM);

76:     event MaxToutSet(uint256 newMaxTout);

80:     event BatchDonatedViaPSM(uint256 usdsSpent, uint256 usdcDonated, address indexed batchMinter);

84:     event DonationSkipped(uint256 usdsParked);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

45:     event RatioUpdated(uint8 oldRatio, uint8 newRatio);

47:     event DebtAccrued(address indexed minter, uint256 dispatchedAmount, uint256 debtAdded, uint256 newTotalDebt);

48:     event DebtPulled(address indexed recipient, uint256 amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

22:     event MetadataUpdated(string name, string image, string description);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

### <a name="NC-28"></a>[NC-28] Constants should be defined rather than using magic numbers

*Instances (2)*:
```solidity
File: NFTMinter.sol

22:         uint256 price; // current mint price in token units (18 decimals)

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

22:         uint256 price; // current mint price in token units (18 decimals)

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="NC-29"></a>[NC-29] `public` functions not called by the contract should be declared `external` instead

*Instances (3)*:
```solidity
File: BurnRecorder.sol

58:     function getTotalBurnt(address token) public view returns (uint256) {

72:     function getTokenCount() public view returns (uint256) {

79:     function getTokenAtIndex(uint256 index) public view returns (address) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

### <a name="NC-30"></a>[NC-30] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (2)*:
```solidity
File: V2/NFTMigrator.sol

43:         for (uint256 i = 0; i < v1Indexes.length; i++) {

70:                 for (uint256 j = 0; j < balance; j++) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 8 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 11 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 13 |
| [L-4](#L-4) | `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 14 |
| [L-5](#L-5) | Division by zero not prevented | 1 |
| [L-6](#L-6) | Prevent accidentally burning tokens | 18 |
| [L-7](#L-7) | Owner can renounce while system is paused | 2 |
| [L-8](#L-8) | Loss of precision | 2 |
| [L-9](#L-9) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 13 |
| [L-10](#L-10) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 7 |
| [L-11](#L-11) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
| [L-12](#L-12) | Upgradeable contract not initialized | 6 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (8)*:
```solidity
File: BurnRecorder.sol

11: contract BurnRecorder is IBurnRecorder, Ownable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

16: contract NFTMinter is ERC1155Supply, Ownable, INFTMinter, IPausable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

12: contract NFTMigrator is Ownable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

16: contract NFTMinterV2 is ERC1155Supply, Ownable, INFTMinterV2, IPausable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

23: abstract contract ATokenDispatcherV2 is ITokenDispatcherV2, Pausable, Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

22: contract BalancerPoolerMintDebtHook is IDispatchHook, IBalancerPoolerMintDebtHook, Ownable, ReentrancyGuard {

66:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

12: abstract contract ATokenDispatcher is ITokenDispatcher, Pausable, Ownable {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (11)*:
```solidity
File: NFTMinter.sol

184:         IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price);

262:         IERC20(token).safeTransfer(msg.sender, balance);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

183:         IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price);

302:         IERC20(token).safeTransfer(msg.sender, balance);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

286:             IERC20(_sUSDS).safeTransfer(_vault, sUSDSAmount);

338:         IERC20(_pool).safeTransfer(recipient, amount);

352:         IERC20(token).safeTransfer(to, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

61:         IERC20(_token).safeTransfer(_recipient, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: dispatchers/BalancerPooler.sol

65:         IERC20(_primeToken).safeTransfer(_vault, primeAmount);

97:         IERC20(_pool).safeTransfer(recipient, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Gather.sol

64:         IERC20(_token).safeTransfer(_recipient, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (13)*:
```solidity
File: NFTMinter.sol

101:         pauser = newPauser;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

106:         pauser = newPauser;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

86:         _minter = minter_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

103:         _pool = pool_;

104:         _vault = vault_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

18:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

28:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

62:         _minter = minter_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

31:         _primeToken = primeToken_;

32:         _pool = pool_;

33:         _vault = vault_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

19:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

```solidity
File: dispatchers/Gather.sol

29:         _token = token_;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

### <a name="L-4"></a>[L-4] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (14)*:
```solidity
File: NFTMinter.sol

219:                 '{"name":"',

220:                 dispatcherName,

221:                 '","image":"',

222:                 dispatcherImage,

223:                 '","description":"',

224:                 dispatcherDescription,

225:                 '"}'

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

264:                 '{"name":"',

265:                 dispatcherName,

266:                 '","image":"',

267:                 dispatcherImage,

268:                 '","description":"',

269:                 dispatcherDescription,

270:                 '"}'

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="L-5"></a>[L-5] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

253:         uint256 gemAmt = (usdsAmount * WAD) / (conv * (WAD + tout));

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

### <a name="L-6"></a>[L-6] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (18)*:
```solidity
File: BurnRecorder.sol

32:         require(_burners[msg.sender], "BurnRecorder: caller is not burner");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

197:         _mint(recipient, resolvedTokenId, 1, "");

294:         emit AuthorizedBurnerSet(burner, authorized);

303:         _burn(holder, tokenId, quantity);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

196:         _mint(recipient, resolvedTokenId, 1, "");

211:         _mint(recipient, index, 1, "");

221:         emit AuthorizedMinterSet(minter, authorized);

334:         emit AuthorizedBurnerSet(burner, authorized);

343:         _burn(holder, tokenId, quantity);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

45:         require(msg.sender == _minter, "ATokenDispatcherV2: caller is not minter");

124:         _dispatch(minter, amount, extraData);

125:         hook.onDispatch(minter, amount, extraData);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

19:         _burnRecorder = IBurnRecorder(burnRecorder_);

38:         _burnRecorder.burn(_token, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

114:         emit DebtAccrued(minter, amount, added, mintDebt);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

26:         require(msg.sender == _minter, "ATokenDispatcher: caller is not minter");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/Burner.sol

20:         _burnRecorder = IBurnRecorder(burnRecorder_);

41:         _burnRecorder.burn(_token, amount);

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

### <a name="L-7"></a>[L-7] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (2)*:
```solidity
File: NFTMinter.sol

99:     function setPauser(address newPauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMinterV2.sol

104:     function setPauser(address newPauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

### <a name="L-8"></a>[L-8] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (2)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

253:         uint256 gemAmt = (usdsAmount * WAD) / (conv * (WAD + tout));

257:         uint256 usdsSpent = gemAmt * conv * (WAD + tout) / WAD;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

### <a name="L-9"></a>[L-9] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (13)*:
```solidity
File: BurnRecorder.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/BurnerV2.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BurnerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: V2/hooks/DefaultDispatchHook.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/DefaultDispatchHook.sol)

```solidity
File: dispatchers/BalancerPooler.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Burner.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Burner.sol)

```solidity
File: dispatchers/Gather.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

```solidity
File: interfaces/balancer/BalancerTypes.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/interfaces/balancer/BalancerTypes.sol)

### <a name="L-10"></a>[L-10] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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
File: BurnRecorder.sol

5: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

8: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

### <a name="L-11"></a>[L-11] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

350:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

### <a name="L-12"></a>[L-12] Upgradeable contract not initialized
Upgradeable contracts are initialized via an initializer function rather than by a constructor. Leaving such a contract uninitialized may lead to it being taken over by a malicious user

*Instances (6)*:
```solidity
File: V2/NFTMigrator.sol

15:     bool public initialized;

19:     event Initialized();

51:     function setInitialized() external onlyOwner {

56:         initialized = true;

57:         emit Initialized();

63:         require(initialized, "NFTMigrator: not initialized");

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 54 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (54)*:
```solidity
File: BurnRecorder.sol

11: contract BurnRecorder is IBurnRecorder, Ownable {

37:     constructor(address initialOwner) Ownable(initialOwner) {}

42:     function setBurner(address burner_, bool approved_) external onlyOwner {

65:     function registerToken(address token) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/BurnRecorder.sol)

```solidity
File: NFTMinter.sol

16: contract NFTMinter is ERC1155Supply, Ownable, INFTMinter, IPausable {

95:     constructor(address initialOwner) ERC1155("") Ownable(initialOwner) {}

99:     function setPauser(address newPauser) external onlyOwner {

150:     function setDispatcherDisabled(uint256 index, bool disabled) external onlyOwner {

242:     function setPrice(uint256 index, uint256 newPrice) external onlyOwner {

250:     function setGrowthFactor(uint256 index, uint256 newGrowthBasisPoints) external onlyOwner {

259:     function emergencyWithdraw(address token) external onlyOwner {

269:     function setDispatcherActive(address dispatcher, bool active) external onlyOwner {

292:     function setAuthorizedBurner(address burner, bool authorized) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/NFTMinter.sol)

```solidity
File: V2/NFTMigrator.sol

12: contract NFTMigrator is Ownable {

25:     constructor(address v1Minter, address v2Minter, address initialOwner) Ownable(initialOwner) {

33:     function setMapping(uint256 v1Index, uint256 v2Index) external onlyOwner {

41:     function setMappings(uint256[] calldata v1Indexes, uint256[] calldata v2Indexes) external onlyOwner {

51:     function setInitialized() external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMigrator.sol)

```solidity
File: V2/NFTMinterV2.sol

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
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/NFTMinterV2.sol)

```solidity
File: V2/dispatchers/ATokenDispatcherV2.sol

23: abstract contract ATokenDispatcherV2 is ITokenDispatcherV2, Pausable, Ownable, ReentrancyGuard {

50:     constructor(address initialOwner) Ownable(initialOwner) {

85:     function setMinter(address minter_) external onlyOwner {

94:     function setHook(IDispatchHook newHook) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/ATokenDispatcherV2.sol)

```solidity
File: V2/dispatchers/BalancerPoolerV2.sol

132:     function setPool(address newPool) external onlyOwner {

140:     function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {

152:     function incrementAuthVersion() external onlyOwner {

160:     function setBatchDonationSize(uint256 newSize) external onlyOwner {

169:     function setBatchMinter(address newBatchMinter) external onlyOwner {

177:     function setPSM(address newPSM) external onlyOwner {

185:     function setMaxTout(uint256 newMaxTout) external onlyOwner {

337:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

350:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/BalancerPoolerV2.sol)

```solidity
File: V2/dispatchers/GatherV2.sol

44:     function setRecipient(address newRecipient) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/dispatchers/GatherV2.sol)

```solidity
File: V2/hooks/BalancerPoolerMintDebtHook.sol

22: contract BalancerPoolerMintDebtHook is IDispatchHook, IBalancerPoolerMintDebtHook, Ownable, ReentrancyGuard {

66:     constructor(address initialOwner, address dispatcher_, address phUSD_) Ownable(initialOwner) {

77:     function setRatio(uint8 newRatio) external onlyOwner {

87:     function setRecipient(address newRecipient) external onlyOwner {

98:     function setDispatcher(address newDispatcher) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/V2/hooks/BalancerPoolerMintDebtHook.sol)

```solidity
File: dispatchers/ATokenDispatcher.sol

12: abstract contract ATokenDispatcher is ITokenDispatcher, Pausable, Ownable {

31:     constructor(address initialOwner) Ownable(initialOwner) {}

37:     function setMetadata(string calldata name_, string calldata image_, string calldata description_) external onlyOwner {

61:     function setMinter(address minter_) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/ATokenDispatcher.sol)

```solidity
File: dispatchers/BalancerPooler.sol

96:     function withdrawBPT(address recipient, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/BalancerPooler.sol)

```solidity
File: dispatchers/Gather.sol

45:     function setRecipient(address newRecipient) external onlyOwner {

```
[Link to code](https://github.com/Behodler/yield-claim-nft/blob/cf75ec9520fd16b19e20c4b77ada2be28d7d4382/src/dispatchers/Gather.sol)

