# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 7 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 14 |
| [GAS-3](#GAS-3) | For Operations that will not overflow, you could use unchecked | 61 |
| [GAS-4](#GAS-4) | Use Custom Errors instead of Revert Strings to save Gas | 16 |
| [GAS-5](#GAS-5) | Avoid contract existence checks by using low level calls | 8 |
| [GAS-6](#GAS-6) | State variables only set in the constructor should be declared `immutable` | 2 |
| [GAS-7](#GAS-7) | Functions guaranteed to revert when called by normal users can be marked `payable` | 18 |
| [GAS-8](#GAS-8) | Using `private` rather than `public` for constants, saves gas | 4 |
| [GAS-9](#GAS-9) | Increments/decrements can be unchecked in for-loops | 1 |
| [GAS-10](#GAS-10) | Use != 0 instead of > 0 for unsigned integer comparison | 16 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (7)*:
```solidity
File: NFTStaker.sol

332:             committedDebt += reward;

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

405:             V += dispatcherHook.mintDebt();

446:         user.amount += amount;

447:         totalStaked += amount;

557:             rewardBudget += forfeit;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (14)*:
```solidity
File: BatchNFTMinter.sol

176:         if (to == address(0)) revert Rescue__ZeroRecipient();

234:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

237:         if (address(nftMinter) == address(0)) {

245:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

250:         if (_nudgeTokenEntry != address(0) && _nudgeTokenEntry == address(paymentToken)) {

270:         if (_nudgeSize != 0 && count >= _nudgeSize && _nudgeTokenEntry != address(0)) {

```

```solidity
File: NFTStaker.sol

195:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

196:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

197:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

253:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

301:         if (address(dispatcherHook) == address(0)) {

404:         if (address(dispatcherHook) != address(0)) {

608:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

618:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

### <a name="GAS-3"></a>[GAS-3] For Operations that will not overflow, you could use unchecked

*Instances (61)*:
```solidity
File: BatchNFTMinter.sol

4: import {ITokenMinterV2} from "yield-claim-nft/V2/interfaces/ITokenMinterV2.sol";

5: import {INFTMinterV2} from "yield-claim-nft/V2/interfaces/INFTMinterV2.sol";

6: import {ITokenDispatcherV2} from "yield-claim-nft/V2/interfaces/ITokenDispatcherV2.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

10: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

11: import {IPausable} from "pauser/interfaces/IPausable.sol";

257:         for (uint256 i; i < count; ++i) {

288:         if (remaining / DUST_THRESHOLD != 0) {

290:             totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0;

```

```solidity
File: NFTStaker.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

6: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

8: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

9: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

10: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

11: import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

12: import {IPausable} from "pauser/interfaces/IPausable.sol";

13: import {IBalancerPoolerMintDebtHook} from "yield-claim-nft/V2/interfaces/IBalancerPoolerMintDebtHook.sol";

14: import {INFTSupply} from "./INFTSupply.sol";

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

307:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

327:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

328:         uint256 reward = elapsed * rewardRate;

331:             rewardBudget -= reward;

332:             committedDebt += reward;

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

394:             uint256 r = APY_PRECISION + growthBasisPoints * 1e14;

401:         uint256 S = (totalStaked == 0 || latestPrice == 0) ? 0 : totalStaked * latestPrice;

405:             V += dispatcherHook.mintDebt();

414:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

417:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

418:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

422:         windowEnd = block.timestamp + runway;

439:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

446:         user.amount += amount;

447:         totalStaked += amount;

448:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

463:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

468:         user.amount -= amount;

469:         totalStaked -= amount;

470:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

482:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

487:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

514:                 rewardBudget -= (amount - committedDebt);

517:                 committedDebt -= amount;

542:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

545:         totalStaked -= amount;

556:             committedDebt -= forfeit;

557:             rewardBudget += forfeit;

572:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

573:             uint256 reward = elapsed * rewardRate;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

577:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

599:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

600:         uint256 reward = elapsed * rewardRate;

602:         return committedDebt + reward;

609:         return rewardToken.balanceOf(address(this)) + pending;

619:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="GAS-4"></a>[GAS-4] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (16)*:
```solidity
File: BatchNFTMinter.sol

113:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: NFTStaker.sol

183:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

195:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

196:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

197:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

232:         require(totalStaked == 0, "NFTStaker: stake outstanding");

242:         require(totalStaked == 0, "NFTStaker: stake outstanding");

252:         require(totalStaked == 0, "NFTStaker: stake outstanding");

253:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

265:         require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");

279:         require(amount > 0, "NFTStaker: zero topUp");

432:         require(amount > 0, "NFTStaker: zero stake");

459:         require(amount > 0, "NFTStaker: zero unstake");

461:         require(user.amount >= amount, "NFTStaker: insufficient stake");

510:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

541:         require(amount > 0, "NFTStaker: nothing to withdraw");

```

### <a name="GAS-5"></a>[GAS-5] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (8)*:
```solidity
File: BatchNFTMinter.sol

271:             nudgeAmount = IERC20(_nudgeTokenEntry).balanceOf(address(this));

287:         uint256 remaining = paymentToken.balanceOf(address(this));

```

```solidity
File: NFTStaker.sol

305:         uint256 pre = rewardToken.balanceOf(address(this));

307:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

403:         uint256 V = rewardToken.balanceOf(address(this));

510:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

609:         return rewardToken.balanceOf(address(this)) + pending;

619:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="GAS-6"></a>[GAS-6] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (2)*:
```solidity
File: NFTStaker.sol

198:         stakedToken = _stakedToken;

200:         rewardToken = _rewardToken;

```

### <a name="GAS-7"></a>[GAS-7] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (18)*:
```solidity
File: BatchNFTMinter.sol

120:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

129:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

136:     function setNudgeSize(uint256 newSize) external onlyOwner {

143:     function setNudgePaymentToken(address newToken) external onlyOwner {

150:     function setPauser(address newPauser) external onlyOwner {

158:     function pause() external override onlyPauser {

163:     function unpause() external override onlyPauser {

175:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

214:     function pause() external onlyPauser {

218:     function unpause() external onlyPauser {

226:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

231:     function setStakedId(uint256 newId) external onlyOwner {

241:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

251:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

264:     function setTargetAPY(uint256 newAPY) external onlyOwner {

278:     function topUp(uint256 amount) external onlyOwner {

287:     function pullAndRefresh() external onlyOwner {

```

### <a name="GAS-8"></a>[GAS-8] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (4)*:
```solidity
File: NFTStaker.sol

39:     uint256 public constant ACC_PRECISION = 1e18;

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

50:     uint256 public constant APY_PRECISION = 1e18;

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="GAS-9"></a>[GAS-9] Increments/decrements can be unchecked in for-loops
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
File: BatchNFTMinter.sol

257:         for (uint256 i; i < count; ++i) {

```

### <a name="GAS-10"></a>[GAS-10] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (16)*:
```solidity
File: NFTStaker.sol

279:         require(amount > 0, "NFTStaker: zero topUp");

309:         if (inflow > 0) {

330:         if (reward > 0) {

432:         require(amount > 0, "NFTStaker: zero stake");

438:         if (user.amount > 0) {

440:             if (pending > 0) {

442:                 if (pending > 0) emit Claimed(msg.sender, pending);

459:         require(amount > 0, "NFTStaker: zero unstake");

464:         if (pending > 0) {

466:             if (pending > 0) emit Claimed(msg.sender, pending);

483:         if (pending > 0) {

485:             if (paid > 0) emit Claimed(msg.sender, paid);

511:         if (amount > 0) {

541:         require(amount > 0, "NFTStaker: nothing to withdraw");

546:         if (pending > 0) {

570:         if (block.timestamp > lastRewardTime && totalStaked > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| [NC-2](#NC-2) | Constants should be in CONSTANT_CASE | 1 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 14 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 2 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 5 |
| [NC-6](#NC-6) | Event missing indexed field | 6 |
| [NC-7](#NC-7) | Events that mark critical parameter changes should contain both the old and the new value | 11 |
| [NC-8](#NC-8) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-9](#NC-9) | Functions should not be longer than 50 lines | 24 |
| [NC-10](#NC-10) | Lack of checks in setters | 7 |
| [NC-11](#NC-11) | NatSpec is completely non-existent on functions that should have them | 8 |
| [NC-12](#NC-12) | Incomplete NatSpec: `@param` is missing on actually documented functions | 8 |
| [NC-13](#NC-13) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 5 |
| [NC-14](#NC-14) | Consider using named mappings | 1 |
| [NC-15](#NC-15) | Owner can renounce while system is paused | 2 |
| [NC-16](#NC-16) | Take advantage of Custom Error's return value property | 7 |
| [NC-17](#NC-17) | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| [NC-18](#NC-18) | Event is missing `indexed` fields | 13 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:
```solidity
File: BatchNFTMinter.sol

144:         nudgePaymentToken = newToken;

152:         pauser = newPauser;

```

```solidity
File: NFTStaker.sol

211:         pauser = newPauser;

```

### <a name="NC-2"></a>[NC-2] Constants should be in CONSTANT_CASE
For `constant` variable names, each word should use all capital letters, with underscores separating each word (CONSTANT_CASE)

*Instances (1)*:
```solidity
File: NFTStaker.sol

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (14)*:
```solidity
File: BatchNFTMinter.sol

176:         if (to == address(0)) revert Rescue__ZeroRecipient();

233:         if (count == 0) revert BatchMint__ZeroCount();

234:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

242:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

245:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

```

```solidity
File: NFTStaker.sol

321:         if (block.timestamp <= lastRewardTime) return;

329:         if (reward > rewardBudget) reward = rewardBudget;

442:                 if (pending > 0) emit Claimed(msg.sender, pending);

466:             if (pending > 0) emit Claimed(msg.sender, pending);

485:             if (paid > 0) emit Claimed(msg.sender, paid);

574:             if (reward > rewardBudget) reward = rewardBudget;

583:         if (block.timestamp >= windowEnd) return 0;

601:         if (reward > rewardBudget) reward = rewardBudget;

617:         if (rewardRate == 0) return 0;

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (2)*:
```solidity
File: BatchNFTMinter.sol

56: contract BatchNFTMinter is Ownable, Pausable, IPausable {

```

```solidity
File: NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (5)*:
```solidity
File: NFTStaker.sol

197:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

232:         require(totalStaked == 0, "NFTStaker: stake outstanding");

242:         require(totalStaked == 0, "NFTStaker: stake outstanding");

252:         require(totalStaked == 0, "NFTStaker: stake outstanding");

253:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

```

### <a name="NC-6"></a>[NC-6] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

104:     event NudgeSizeChanged(uint256 newSize);

```

```solidity
File: NFTStaker.sol

154:     event Pulled(uint256 inflow, uint256 newBudget);

159:     event StakedIdChanged(uint256 previous, uint256 next);

161:     event TargetAPYChanged(uint256 previous, uint256 next);

162:     event DispatcherIndexChanged(uint256 previous, uint256 next);

176:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

```

### <a name="NC-7"></a>[NC-7] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (11)*:
```solidity
File: BatchNFTMinter.sol

120:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

129:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

136:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

143:     function setNudgePaymentToken(address newToken) external onlyOwner {
             nudgePaymentToken = newToken;
             emit NudgePaymentTokenChanged(newToken);

150:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

226:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));

231:     function setStakedId(uint256 newId) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit StakedIdChanged(stakedId, newId);

241:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit DispatcherIndexChanged(dispatcherIndex, newIndex);

251:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             require(address(newMinter) != address(0), "NFTStaker: zero nft minter");
             emit NFTMinterChanged(address(nftMinter), address(newMinter));

264:     function setTargetAPY(uint256 newAPY) external onlyOwner {
             require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");
             _updatePool();
             emit TargetAPYChanged(targetAPY, newAPY);

```

### <a name="NC-8"></a>[NC-8] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: NFTStaker.sol

1: 
   Current order:
   external setPauser
   external pause
   external unpause
   external setDispatcherHook
   external setStakedId
   external setDispatcherIndex
   external setNFTMinter
   external setTargetAPY
   external topUp
   external pullAndRefresh
   internal _syncBudget
   internal _updatePool
   internal _recomputeSchedule
   external stake
   external unstake
   external claim
   internal _safePay
   external emergencyWithdraw
   external pendingReward
   external currentRewardRate
   external totalDebt
   external totalBudget
   external runwaySeconds
   
   Suggested order:
   external setPauser
   external pause
   external unpause
   external setDispatcherHook
   external setStakedId
   external setDispatcherIndex
   external setNFTMinter
   external setTargetAPY
   external topUp
   external pullAndRefresh
   external stake
   external unstake
   external claim
   external emergencyWithdraw
   external pendingReward
   external currentRewardRate
   external totalDebt
   external totalBudget
   external runwaySeconds
   internal _syncBudget
   internal _updatePool
   internal _recomputeSchedule
   internal _safePay

```

### <a name="NC-9"></a>[NC-9] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (24)*:
```solidity
File: BatchNFTMinter.sol

120:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

129:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

136:     function setNudgeSize(uint256 newSize) external onlyOwner {

143:     function setNudgePaymentToken(address newToken) external onlyOwner {

150:     function setPauser(address newPauser) external onlyOwner {

175:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: INFTSupply.sol

25:     function totalSupply(uint256 id) external view returns (uint256);

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

226:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

231:     function setStakedId(uint256 newId) external onlyOwner {

241:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

251:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

264:     function setTargetAPY(uint256 newAPY) external onlyOwner {

278:     function topUp(uint256 amount) external onlyOwner {

431:     function stake(uint256 amount) external nonReentrant whenNotPaused {

458:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

479:     function claim() external nonReentrant whenNotPaused {

509:     function _safePay(uint256 amount) internal returns (uint256) {

538:     function emergencyWithdraw() external nonReentrant {

567:     function pendingReward(address account) external view returns (uint256) {

582:     function currentRewardRate() external view returns (uint256) {

594:     function totalDebt() external view returns (uint256) {

607:     function totalBudget() external view returns (uint256) {

616:     function runwaySeconds() external view returns (uint256) {

```

### <a name="NC-10"></a>[NC-10] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (7)*:
```solidity
File: BatchNFTMinter.sol

120:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

129:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

136:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

143:     function setNudgePaymentToken(address newToken) external onlyOwner {
             nudgePaymentToken = newToken;
             emit NudgePaymentTokenChanged(newToken);

150:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

226:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

### <a name="NC-11"></a>[NC-11] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (8)*:
```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

214:     function pause() external onlyPauser {

218:     function unpause() external onlyPauser {

226:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

231:     function setStakedId(uint256 newId) external onlyOwner {

431:     function stake(uint256 amount) external nonReentrant whenNotPaused {

458:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

479:     function claim() external nonReentrant whenNotPaused {

```

### <a name="NC-12"></a>[NC-12] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (8)*:
```solidity
File: BatchNFTMinter.sol

117:     /// @notice Owner-gated update of the trusted NFT minter. Setting
         ///         `address(0)` disables `batchMint` (it reverts
         ///         `BatchMint__MinterNotConfigured`).
         function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

125:     /// @notice Owner-gated update of the only dispatcher index `batchMint`
         ///         mints. Setting `0` disables `batchMint` (it reverts
         ///         `BatchMint__DispatcherNotConfigured`). Stays callable while
         ///         paused.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

134:     /// @notice Owner-gated update of the batch-size threshold for the nudge
         ///         payout. Setting `0` disables the feature.
         function setNudgeSize(uint256 newSize) external onlyOwner {

141:     /// @notice Owner-gated update of the nudge payout token. Setting
         ///         `address(0)` disables the feature.
         function setNudgePaymentToken(address newToken) external onlyOwner {

148:     /// @notice Owner-gated update of the pauser address. Setting `address(0)`
         ///         disables pausing. Stays callable while paused.
         function setPauser(address newPauser) external onlyOwner {

167:     /// @notice Owner-only recovery of an arbitrary ERC20. The deployed
         ///         contract previously had no owner-withdraw at all, so a trapped
         ///         balance could only ever leave via the nudge — this is the
         ///         missing escape hatch. Owner-trusted (the owner can already pull
         ///         the nudge token via the nudge setters), so no token restriction
         ///         is needed; an explicit `amount` is preferred over a
         ///         full-balance sweep so it composes with the nudge pot. Stays
         ///         callable while paused (mirrors `NFTStaker.emergencyWithdraw`).
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: NFTStaker.sol

237:     /// @notice Update the dispatcher index read from `nftMinter.configs`.
         ///         Guarded by `totalStaked == 0` — a mid-stake swap to a
         ///         different dispatcher could swing APY violently in either
         ///         direction, so the safest policy is to require an empty pool.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

248:     /// @notice Swap the `nftMinter` reference. Guarded by
         ///         `totalStaked == 0` for the same reason as `setStakedId` and
         ///         `setDispatcherIndex`.
         function setNFTMinter(INFTSupply newMinter) external onlyOwner {

```

### <a name="NC-13"></a>[NC-13] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (5)*:
```solidity
File: BatchNFTMinter.sol

113:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: NFTStaker.sol

183:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

442:                 if (pending > 0) emit Claimed(msg.sender, pending);

466:             if (pending > 0) emit Claimed(msg.sender, pending);

485:             if (paid > 0) emit Claimed(msg.sender, paid);

```

### <a name="NC-14"></a>[NC-14] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (1)*:
```solidity
File: NFTStaker.sol

139:     mapping(address => UserInfo) public users;

```

### <a name="NC-15"></a>[NC-15] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (2)*:
```solidity
File: BatchNFTMinter.sol

150:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="NC-16"></a>[NC-16] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (7)*:
```solidity
File: BatchNFTMinter.sol

176:         if (to == address(0)) revert Rescue__ZeroRecipient();

233:         if (count == 0) revert BatchMint__ZeroCount();

234:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

238:             revert BatchMint__MinterNotConfigured();

242:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

245:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

251:             revert BatchMint__NudgeTokenMatchesPaymentToken();

```

### <a name="NC-17"></a>[NC-17] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (2)*:
```solidity
File: BatchNFTMinter.sol

1: 
   Current order:
   UsingForDirective.IERC20
   FunctionDefinition.constructor
   VariableDeclaration.DUST_THRESHOLD
   VariableDeclaration.tokenMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.nudgeSize
   VariableDeclaration.nudgePaymentToken
   VariableDeclaration.pauser
   ErrorDefinition.BatchMint__ZeroCount
   ErrorDefinition.BatchMint__ZeroRecipient
   ErrorDefinition.BatchMint__NudgeTokenMatchesPaymentToken
   ErrorDefinition.BatchMint__MinterNotConfigured
   ErrorDefinition.BatchMint__DispatcherNotConfigured
   ErrorDefinition.Rescue__ZeroRecipient
   ErrorDefinition.BatchMint__RewardBelowMinimum
   EventDefinition.NudgeSizeChanged
   EventDefinition.NudgePaymentTokenChanged
   EventDefinition.NudgePaid
   EventDefinition.TokenMinterSet
   EventDefinition.DispatcherIndexSet
   EventDefinition.Rescued
   EventDefinition.PauserChanged
   ModifierDefinition.onlyPauser
   FunctionDefinition.setTokenMinter
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNudgeSize
   FunctionDefinition.setNudgePaymentToken
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.rescueERC20
   FunctionDefinition.batchMint
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.DUST_THRESHOLD
   VariableDeclaration.tokenMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.nudgeSize
   VariableDeclaration.nudgePaymentToken
   VariableDeclaration.pauser
   ErrorDefinition.BatchMint__ZeroCount
   ErrorDefinition.BatchMint__ZeroRecipient
   ErrorDefinition.BatchMint__NudgeTokenMatchesPaymentToken
   ErrorDefinition.BatchMint__MinterNotConfigured
   ErrorDefinition.BatchMint__DispatcherNotConfigured
   ErrorDefinition.Rescue__ZeroRecipient
   ErrorDefinition.BatchMint__RewardBelowMinimum
   EventDefinition.NudgeSizeChanged
   EventDefinition.NudgePaymentTokenChanged
   EventDefinition.NudgePaid
   EventDefinition.TokenMinterSet
   EventDefinition.DispatcherIndexSet
   EventDefinition.Rescued
   EventDefinition.PauserChanged
   ModifierDefinition.onlyPauser
   FunctionDefinition.constructor
   FunctionDefinition.setTokenMinter
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNudgeSize
   FunctionDefinition.setNudgePaymentToken
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.rescueERC20
   FunctionDefinition.batchMint

```

```solidity
File: NFTStaker.sol

1: 
   Current order:
   UsingForDirective.IERC20
   UsingForDirective.Math
   VariableDeclaration.ACC_PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.APY_PRECISION
   VariableDeclaration.MAX_TARGET_APY
   VariableDeclaration.stakedToken
   VariableDeclaration.rewardToken
   VariableDeclaration.stakedId
   VariableDeclaration.dispatcherHook
   VariableDeclaration.pauser
   VariableDeclaration.nftMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.targetAPY
   VariableDeclaration.windowEnd
   VariableDeclaration.rewardRate
   VariableDeclaration.rewardBudget
   VariableDeclaration.committedDebt
   VariableDeclaration.lastRewardTime
   VariableDeclaration.totalStaked
   VariableDeclaration.accRewardPerShare
   StructDefinition.UserInfo
   VariableDeclaration.users
   EventDefinition.Staked
   EventDefinition.Unstaked
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.Pulled
   EventDefinition.ToppedUp
   EventDefinition.DispatcherHookChanged
   EventDefinition.StakedIdChanged
   EventDefinition.PauserChanged
   EventDefinition.TargetAPYChanged
   EventDefinition.DispatcherIndexChanged
   EventDefinition.NFTMinterChanged
   EventDefinition.ScheduleRecomputed
   ModifierDefinition.onlyPauser
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.setDispatcherHook
   FunctionDefinition.setStakedId
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNFTMinter
   FunctionDefinition.setTargetAPY
   FunctionDefinition.topUp
   FunctionDefinition.pullAndRefresh
   FunctionDefinition._syncBudget
   FunctionDefinition._updatePool
   FunctionDefinition._recomputeSchedule
   FunctionDefinition.stake
   FunctionDefinition.unstake
   FunctionDefinition.claim
   FunctionDefinition._safePay
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.pendingReward
   FunctionDefinition.currentRewardRate
   FunctionDefinition.totalDebt
   FunctionDefinition.totalBudget
   FunctionDefinition.runwaySeconds
   
   Suggested order:
   UsingForDirective.IERC20
   UsingForDirective.Math
   VariableDeclaration.ACC_PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.APY_PRECISION
   VariableDeclaration.MAX_TARGET_APY
   VariableDeclaration.stakedToken
   VariableDeclaration.rewardToken
   VariableDeclaration.stakedId
   VariableDeclaration.dispatcherHook
   VariableDeclaration.pauser
   VariableDeclaration.nftMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.targetAPY
   VariableDeclaration.windowEnd
   VariableDeclaration.rewardRate
   VariableDeclaration.rewardBudget
   VariableDeclaration.committedDebt
   VariableDeclaration.lastRewardTime
   VariableDeclaration.totalStaked
   VariableDeclaration.accRewardPerShare
   VariableDeclaration.users
   StructDefinition.UserInfo
   EventDefinition.Staked
   EventDefinition.Unstaked
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.Pulled
   EventDefinition.ToppedUp
   EventDefinition.DispatcherHookChanged
   EventDefinition.StakedIdChanged
   EventDefinition.PauserChanged
   EventDefinition.TargetAPYChanged
   EventDefinition.DispatcherIndexChanged
   EventDefinition.NFTMinterChanged
   EventDefinition.ScheduleRecomputed
   ModifierDefinition.onlyPauser
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.setDispatcherHook
   FunctionDefinition.setStakedId
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNFTMinter
   FunctionDefinition.setTargetAPY
   FunctionDefinition.topUp
   FunctionDefinition.pullAndRefresh
   FunctionDefinition._syncBudget
   FunctionDefinition._updatePool
   FunctionDefinition._recomputeSchedule
   FunctionDefinition.stake
   FunctionDefinition.unstake
   FunctionDefinition.claim
   FunctionDefinition._safePay
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.pendingReward
   FunctionDefinition.currentRewardRate
   FunctionDefinition.totalDebt
   FunctionDefinition.totalBudget
   FunctionDefinition.runwaySeconds

```

### <a name="NC-18"></a>[NC-18] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (13)*:
```solidity
File: BatchNFTMinter.sol

104:     event NudgeSizeChanged(uint256 newSize);

106:     event NudgePaid(address indexed recipient, address indexed token, uint256 amount);

109:     event Rescued(address indexed token, address indexed to, uint256 amount);

```

```solidity
File: NFTStaker.sol

145:     event Staked(address indexed user, uint256 amount);

146:     event Unstaked(address indexed user, uint256 amount);

147:     event Claimed(address indexed user, uint256 amount);

148:     event EmergencyWithdrawn(address indexed user, uint256 amount);

154:     event Pulled(uint256 inflow, uint256 newBudget);

157:     event ToppedUp(address indexed from, uint256 amount, uint256 newBudget);

159:     event StakedIdChanged(uint256 previous, uint256 next);

161:     event TargetAPYChanged(uint256 previous, uint256 next);

162:     event DispatcherIndexChanged(uint256 previous, uint256 next);

176:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 2 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 6 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| [L-4](#L-4) | Division by zero not prevented | 4 |
| [L-5](#L-5) | Owner can renounce while system is paused | 2 |
| [L-6](#L-6) | Possible rounding issue | 2 |
| [L-7](#L-7) | Loss of precision | 12 |
| [L-8](#L-8) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 2 |
| [L-9](#L-9) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-10](#L-10) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
| [L-11](#L-11) | A year is not always 365 days | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: BatchNFTMinter.sol

56: contract BatchNFTMinter is Ownable, Pausable, IPausable {

```

```solidity
File: NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

177:         token.safeTransfer(to, amount);

254:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

283:             IERC20(_nudgeTokenEntry).safeTransfer(recipient, nudgeAmount);

289:             paymentToken.safeTransfer(msg.sender, remaining);

```

```solidity
File: NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

512:             rewardToken.safeTransfer(msg.sender, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:
```solidity
File: BatchNFTMinter.sol

144:         nudgePaymentToken = newToken;

152:         pauser = newPauser;

```

```solidity
File: NFTStaker.sol

211:         pauser = newPauser;

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (4)*:
```solidity
File: NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

418:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

619:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="L-5"></a>[L-5] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (2)*:
```solidity
File: BatchNFTMinter.sol

150:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="L-6"></a>[L-6] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (2)*:
```solidity
File: NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

```

### <a name="L-7"></a>[L-7] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (12)*:
```solidity
File: BatchNFTMinter.sol

288:         if (remaining / DUST_THRESHOLD != 0) {

```

```solidity
File: NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

417:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

439:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

448:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

463:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

470:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

482:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

487:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

542:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

577:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

```

### <a name="L-8"></a>[L-8] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (2)*:
```solidity
File: BatchNFTMinter.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: NFTStaker.sol

2: pragma solidity ^0.8.20;

```

### <a name="L-9"></a>[L-9] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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
File: BatchNFTMinter.sol

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: NFTStaker.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-10"></a>[L-10] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: BatchNFTMinter.sol

175:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

### <a name="L-11"></a>[L-11] A year is not always 365 days
On leap years, the number of days is 366, so calculations during those years will return the wrong value

*Instances (1)*:
```solidity
File: NFTStaker.sol

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 2 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 18 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (2)*:
```solidity
File: BatchNFTMinter.sol

254:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

```

```solidity
File: NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (18)*:
```solidity
File: BatchNFTMinter.sol

56: contract BatchNFTMinter is Ownable, Pausable, IPausable {

59:     constructor(address initialOwner) Ownable(initialOwner) {}

120:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

129:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

136:     function setNudgeSize(uint256 newSize) external onlyOwner {

143:     function setNudgePaymentToken(address newToken) external onlyOwner {

150:     function setPauser(address newPauser) external onlyOwner {

175:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

194:     ) Ownable(_initialOwner) {

209:     function setPauser(address newPauser) external onlyOwner {

226:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

231:     function setStakedId(uint256 newId) external onlyOwner {

241:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

251:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

264:     function setTargetAPY(uint256 newAPY) external onlyOwner {

278:     function topUp(uint256 amount) external onlyOwner {

287:     function pullAndRefresh() external onlyOwner {

```

