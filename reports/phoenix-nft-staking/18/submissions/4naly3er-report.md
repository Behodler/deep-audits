# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 29 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 38 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 5 |
| [GAS-4](#GAS-4) | State variables should be cached in stack variables rather than re-reading them from storage | 2 |
| [GAS-5](#GAS-5) | For Operations that will not overflow, you could use unchecked | 206 |
| [GAS-6](#GAS-6) | Use Custom Errors instead of Revert Strings to save Gas | 69 |
| [GAS-7](#GAS-7) | Avoid contract existence checks by using low level calls | 22 |
| [GAS-8](#GAS-8) | State variables only set in the constructor should be declared `immutable` | 15 |
| [GAS-9](#GAS-9) | Functions guaranteed to revert when called by normal users can be marked `payable` | 50 |
| [GAS-10](#GAS-10) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 10 |
| [GAS-11](#GAS-11) | Using `private` rather than `public` for constants, saves gas | 14 |
| [GAS-12](#GAS-12) | Splitting require() statements that use && saves gas | 1 |
| [GAS-13](#GAS-13) | Increments/decrements can be unchecked in for-loops | 8 |
| [GAS-14](#GAS-14) | Use != 0 instead of > 0 for unsigned integer comparison | 61 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (29)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

160:                 parked[users[i]] += amt;

163:                 totalParked += amt;

164:                 total += amt;

221:             total += amt;

```

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

```solidity
File: NFTStakerDepletion.sol

469:             committedDebt += reward;

470:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

518:             V += dispatcherHook.mintDebt();

555:         user.amount += amount;

556:         totalStaked += amount;

644:             rewardBudget += forfeit;

700:             totalAmount += amount;

772:         info.amount += amount;

773:         totalStaked += amount;

821:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: NFTStakerMigrator.sol

86:             total += amounts[i];

```

```solidity
File: NFTStakerPriceScaled.sol

366:             committedDebt += reward;

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

444:             V += dispatcherHook.mintDebt();

485:         user.amount += amount;

486:         totalStaked += amount;

596:             rewardBudget += forfeit;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (38)*:
```solidity
File: BatchNFTMinter.sol

176:         if (to == address(0)) revert Rescue__ZeroRecipient();

239:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

242:         if (address(nftMinter) == address(0)) {

250:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

255:         if (_nudgeTokenEntry != address(0) && _nudgeTokenEntry == address(paymentToken)) {

273:         if (_nudgeSize != 0 && count >= _nudgeSize && _nudgeTokenEntry != address(0)) {

```

```solidity
File: InPlaceNFTStakerMigrator.sol

100:         require(address(_staker) != address(0), "InPlace: zero staker");

101:         require(address(_stakedToken) != address(0), "InPlace: zero staked token");

269:         require(to != address(0), "InPlace: zero recipient");

282:         require(to != address(0), "InPlace: zero recipient");

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

```solidity
File: NFTStakerDepletion.sol

288:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

289:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

290:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

352:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

403:         if (to == address(0)) revert Rescue__ZeroRecipient();

425:         if (address(dispatcherHook) == address(0)) {

517:         if (address(dispatcherHook) != address(0)) {

851:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

862:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

```solidity
File: NFTStakerMigrator.sol

55:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

56:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

57:         require(address(_stakedToken) != address(0), "Migrator: zero staked token");

```

```solidity
File: NFTStakerPriceScaled.sol

227:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

228:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

229:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

287:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

335:         if (address(dispatcherHook) == address(0)) {

443:         if (address(dispatcherHook) != address(0)) {

647:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

657:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (5)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (2)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

205:             stakedToken.setApprovalForAll(address(staker), true);

```

```solidity
File: NFTStakerMigrator.sol

108:         stakedToken.setApprovalForAll(address(newStaker), false);

```

### <a name="GAS-5"></a>[GAS-5] For Operations that will not overflow, you could use unchecked

*Instances (206)*:
```solidity
File: BatchNFTMinter.sol

4: import {ITokenMinterV2} from "yield-claim-nft/interfaces/ITokenMinterV2.sol";

5: import {INFTMinterV2} from "yield-claim-nft/interfaces/INFTMinterV2.sol";

6: import {ITokenDispatcherV2} from "yield-claim-nft/interfaces/ITokenDispatcherV2.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

10: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

11: import {IPausable} from "pauser/interfaces/IPausable.sol";

280:         for (uint256 i; i < count; ++i) {

300:         if (remaining / DUST_THRESHOLD != 0) {

302:             totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0;

```

```solidity
File: InPlaceNFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

9: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

10: import {INFTStakerMigratable} from "./INFTStakerMigratable.sol";

117:             _parkedIndex[user] = _parkedUsers.length; // 1-based

127:             address moved = _parkedUsers[last - 1];

128:             _parkedUsers[idx - 1] = moved;

157:         for (uint256 i = 0; i < users.length; i++) {

160:                 parked[users[i]] += amt;

163:                 totalParked += amt;

164:                 total += amt;

165:                 count++;

195:         uint256 sliceLen = end - start;

197:         for (uint256 i = 0; i < sliceLen; i++) {

198:             slice[i] = _parkedUsers[start + i];

210:         for (uint256 i = 0; i < sliceLen; i++) {

219:             totalParked -= amt;

221:             total += amt;

222:             count++;

245:         require(block.timestamp >= migrationBegin[msg.sender] + migrationTimeout, "InPlace: timeout not elapsed");

250:         totalParked -= amount;

285:             uint256 surplus = balance - totalParked;

307:         out = new address[](end - start);

308:         for (uint256 i = 0; i < out.length; i++) {

309:             out[i] = _parkedUsers[start + i];

320:         return begin + migrationTimeout;

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

13: import {IBalancerPoolerMintDebtHook} from "yield-claim-nft/interfaces/IBalancerPoolerMintDebtHook.sol";

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

```solidity
File: NFTStakerDepletion.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

6: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

8: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

9: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

10: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

11: import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

12: import {IPausable} from "pauser/interfaces/IPausable.sol";

13: import {IUniboostMintDebtHook} from "yield-claim-nft/interfaces/IUniboostMintDebtHook.sol";

14: import {INFTSupply} from "./INFTSupply.sol";

15: import {INFTStakerMigratable} from "./INFTStakerMigratable.sol";

83:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

431:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

464:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

465:         uint256 reward = elapsed * rewardRate;

468:             rewardBudget -= reward;

469:             committedDebt += reward;

470:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

514:         uint256 windowSeconds = depletionWindowMonths * SECONDS_PER_MONTH;

518:             V += dispatcherHook.mintDebt();

524:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

526:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

530:         windowEnd = block.timestamp + windowSeconds;

548:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

555:         user.amount += amount;

556:         totalStaked += amount;

557:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

573:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

578:         user.amount -= amount;

579:         totalStaked -= amount;

580:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

591:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

596:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

619:                 rewardBudget -= (amount - committedDebt);

622:                 committedDebt -= amount;

637:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

640:         totalStaked -= amount;

643:             committedDebt -= forfeit;

644:             rewardBudget += forfeit;

697:         for (uint256 i = 0; i < accounts.length; i++) {

700:             totalAmount += amount;

739:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

742:         totalStaked -= amount;

765:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

772:         info.amount += amount;

773:         totalStaked += amount;

774:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

818:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

819:             uint256 reward = elapsed * rewardRate;

821:             acc += (reward * ACC_PRECISION) / totalStaked;

823:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

842:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

843:         uint256 reward = elapsed * rewardRate;

845:         return committedDebt + reward;

852:         return rewardToken.balanceOf(address(this)) + pending;

863:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: NFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

6: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

7: import {INFTStakerMigratable} from "./INFTStakerMigratable.sol";

85:         for (uint256 i = 0; i < amounts.length; i++) {

86:             total += amounts[i];

100:         for (uint256 i = 0; i < users.length; i++) {

103:                 migratedCount++;

```

```solidity
File: NFTStakerPriceScaled.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

6: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

8: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

9: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

10: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

11: import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

12: import {IPausable} from "pauser/interfaces/IPausable.sol";

13: import {IBalancerPoolerMintDebtHook} from "yield-claim-nft/interfaces/IBalancerPoolerMintDebtHook.sol";

14: import {INFTSupply} from "./INFTSupply.sol";

79:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

341:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

361:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

362:         uint256 reward = elapsed * rewardRate;

365:             rewardBudget -= reward;

366:             committedDebt += reward;

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

429:             uint256 r = APY_PRECISION + growthBasisPoints * 1e14;

435:         latestPrice = latestPrice * priceScale;

440:         uint256 S = (totalStaked == 0 || latestPrice == 0) ? 0 : totalStaked * latestPrice;

444:             V += dispatcherHook.mintDebt();

453:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

456:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

457:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

461:         windowEnd = block.timestamp + runway;

478:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

485:         user.amount += amount;

486:         totalStaked += amount;

487:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

502:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

507:         user.amount -= amount;

508:         totalStaked -= amount;

509:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

521:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

526:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

553:                 rewardBudget -= (amount - committedDebt);

556:                 committedDebt -= amount;

581:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

584:         totalStaked -= amount;

595:             committedDebt -= forfeit;

596:             rewardBudget += forfeit;

611:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

612:             uint256 reward = elapsed * rewardRate;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

616:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

638:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

639:         uint256 reward = elapsed * rewardRate;

641:         return committedDebt + reward;

648:         return rewardToken.balanceOf(address(this)) + pending;

658:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="GAS-6"></a>[GAS-6] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (69)*:
```solidity
File: BatchNFTMinter.sol

113:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: InPlaceNFTStakerMigrator.sol

100:         require(address(_staker) != address(0), "InPlace: zero staker");

101:         require(address(_stakedToken) != address(0), "InPlace: zero staked token");

191:         require(start <= end, "InPlace: bad range");

244:         require(amount > 0, "InPlace: nothing parked");

245:         require(block.timestamp >= migrationBegin[msg.sender] + migrationTimeout, "InPlace: timeout not elapsed");

269:         require(to != address(0), "InPlace: zero recipient");

282:         require(to != address(0), "InPlace: zero recipient");

286:             require(amount <= surplus, "InPlace: cannot touch parked principal");

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

```solidity
File: NFTStakerDepletion.sol

271:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

276:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

288:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

289:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

290:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

334:         require(totalStaked == 0, "NFTStaker: stake outstanding");

342:         require(totalStaked == 0, "NFTStaker: stake outstanding");

351:         require(totalStaked == 0, "NFTStaker: stake outstanding");

352:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

365:         require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");

378:         require(amount > 0, "NFTStaker: zero topUp");

407:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

541:         require(amount > 0, "NFTStaker: zero stake");

569:         require(amount > 0, "NFTStaker: zero unstake");

571:         require(user.amount >= amount, "NFTStaker: insufficient stake");

615:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

636:         require(amount > 0, "NFTStaker: nothing to withdraw");

665:         require(poolState == PoolState.Active, "NFTStaker: not active");

693:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

717:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

718:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

760:         require(amount > 0, "NFTStaker: zero deposit");

761:         require(poolState == PoolState.Active, "NFTStaker: not active");

790:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

791:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

```solidity
File: NFTStakerMigrator.sol

55:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

56:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

57:         require(address(_stakedToken) != address(0), "Migrator: zero staked token");

58:         require(address(_oldStaker) != address(_newStaker), "Migrator: same staker");

```

```solidity
File: NFTStakerPriceScaled.sol

214:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

227:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

228:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

229:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

230:         require(_priceScale != 0, "NFTStaker: zero price scale");

266:         require(totalStaked == 0, "NFTStaker: stake outstanding");

276:         require(totalStaked == 0, "NFTStaker: stake outstanding");

286:         require(totalStaked == 0, "NFTStaker: stake outstanding");

287:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

299:         require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");

313:         require(amount > 0, "NFTStaker: zero topUp");

471:         require(amount > 0, "NFTStaker: zero stake");

498:         require(amount > 0, "NFTStaker: zero unstake");

500:         require(user.amount >= amount, "NFTStaker: insufficient stake");

549:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

580:         require(amount > 0, "NFTStaker: nothing to withdraw");

```

### <a name="GAS-7"></a>[GAS-7] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (22)*:
```solidity
File: BatchNFTMinter.sol

274:             nudgeAmount = IERC20(_nudgeTokenEntry).balanceOf(address(this));

299:         uint256 remaining = paymentToken.balanceOf(address(this));

```

```solidity
File: InPlaceNFTStakerMigrator.sol

284:             uint256 balance = stakedToken.balanceOf(address(this), stakedId);

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

```solidity
File: NFTStakerDepletion.sol

407:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

429:         uint256 pre = rewardToken.balanceOf(address(this));

431:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

516:         uint256 V = rewardToken.balanceOf(address(this));

615:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

852:         return rewardToken.balanceOf(address(this)) + pending;

863:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: NFTStakerPriceScaled.sol

339:         uint256 pre = rewardToken.balanceOf(address(this));

341:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

442:         uint256 V = rewardToken.balanceOf(address(this));

549:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

648:         return rewardToken.balanceOf(address(this)) + pending;

658:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="GAS-8"></a>[GAS-8] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (15)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

105:         staker = _staker;

106:         stakedToken = _stakedToken;

107:         stakedId = _stakedId;

108:         migrationTimeout = _migrationTimeout;

```

```solidity
File: NFTStaker.sol

198:         stakedToken = _stakedToken;

200:         rewardToken = _rewardToken;

```

```solidity
File: NFTStakerDepletion.sol

291:         stakedToken = _stakedToken;

293:         rewardToken = _rewardToken;

```

```solidity
File: NFTStakerMigrator.sol

59:         oldStaker = _oldStaker;

60:         newStaker = _newStaker;

61:         stakedToken = _stakedToken;

62:         stakedId = _stakedId;

```

```solidity
File: NFTStakerPriceScaled.sol

231:         stakedToken = _stakedToken;

233:         rewardToken = _rewardToken;

236:         priceScale = _priceScale;

```

### <a name="GAS-9"></a>[GAS-9] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (50)*:
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
File: InPlaceNFTStakerMigrator.sol

140:     function initiateMigration() external onlyOwner {

152:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

186:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

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

```solidity
File: NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {

311:     function setMigrator(address newMigrator) external onlyOwner {

316:     function pause() external onlyPauser {

320:     function unpause() external onlyPauser {

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

333:     function setStakedId(uint256 newId) external onlyOwner {

341:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

350:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

364:     function setDepletionWindow(uint256 months) external onlyOwner {

377:     function topUp(uint256 amount) external onlyOwner {

386:     function pullAndRefresh() external onlyOwner {

402:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

664:     function initiateMigration() external override nonReentrant onlyMigrator {

759:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

789:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: NFTStakerMigrator.sol

70:     function initiateMigration() external onlyOwner {

81:     function migrate(address[] calldata users) external onlyOwner {

```

```solidity
File: NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

248:     function pause() external onlyPauser {

252:     function unpause() external onlyPauser {

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

265:     function setStakedId(uint256 newId) external onlyOwner {

275:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

285:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

298:     function setTargetAPY(uint256 newAPY) external onlyOwner {

312:     function topUp(uint256 amount) external onlyOwner {

321:     function pullAndRefresh() external onlyOwner {

```

### <a name="GAS-10"></a>[GAS-10] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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

*Instances (10)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

165:                 count++;

197:         for (uint256 i = 0; i < sliceLen; i++) {

210:         for (uint256 i = 0; i < sliceLen; i++) {

222:             count++;

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

103:                 migratedCount++;

```

### <a name="GAS-11"></a>[GAS-11] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (14)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

83:     uint256 public constant MIN_TIMEOUT = 1 days;

87:     uint256 public constant MAX_TIMEOUT = 30 days;

```

```solidity
File: NFTStaker.sol

39:     uint256 public constant ACC_PRECISION = 1e18;

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

50:     uint256 public constant APY_PRECISION = 1e18;

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: NFTStakerDepletion.sol

72:     uint256 public constant ACC_PRECISION = 1e18;

77:     uint256 public constant SECONDS_PER_YEAR = 365 days;

83:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

88:     uint256 public constant MAX_DEPLETION_MONTHS = 120;

```

```solidity
File: NFTStakerPriceScaled.sol

62:     uint256 public constant ACC_PRECISION = 1e18;

69:     uint256 public constant SECONDS_PER_YEAR = 365 days;

73:     uint256 public constant APY_PRECISION = 1e18;

79:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="GAS-12"></a>[GAS-12] Splitting require() statements that use && saves gas

*Instances (1)*:
```solidity
File: NFTStakerDepletion.sol

365:         require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");

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

*Instances (8)*:
```solidity
File: BatchNFTMinter.sol

280:         for (uint256 i; i < count; ++i) {

```

```solidity
File: InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

197:         for (uint256 i = 0; i < sliceLen; i++) {

210:         for (uint256 i = 0; i < sliceLen; i++) {

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-14"></a>[GAS-14] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (61)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

159:             if (amt > 0) {

204:         if (totalParked > 0) {

244:         require(amount > 0, "InPlace: nothing parked");

```

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

```solidity
File: NFTStakerDepletion.sol

378:         require(amount > 0, "NFTStaker: zero topUp");

433:         if (inflow > 0) {

467:         if (reward > 0) {

541:         require(amount > 0, "NFTStaker: zero stake");

547:         if (user.amount > 0) {

549:             if (pending > 0) {

551:                 if (pending > 0) emit Claimed(msg.sender, pending);

569:         require(amount > 0, "NFTStaker: zero unstake");

574:         if (pending > 0) {

576:             if (pending > 0) emit Claimed(msg.sender, pending);

592:         if (pending > 0) {

594:             if (paid > 0) emit Claimed(msg.sender, paid);

616:         if (amount > 0) {

636:         require(amount > 0, "NFTStaker: nothing to withdraw");

641:         if (pending > 0) {

701:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

703:         if (totalAmount > 0) {

718:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

743:         if (pending > 0) {

745:             if (paid > 0) emit Claimed(account, paid);

760:         require(amount > 0, "NFTStaker: zero deposit");

764:         if (info.amount > 0) {

766:             if (pending > 0) {

768:                 if (pending > 0) emit Claimed(user, pending);

816:         if (poolState == PoolState.Active && block.timestamp > lastRewardTime && totalStaked > 0) {

```

```solidity
File: NFTStakerMigrator.sol

101:             if (amounts[i] > 0) {

```

```solidity
File: NFTStakerPriceScaled.sol

313:         require(amount > 0, "NFTStaker: zero topUp");

343:         if (inflow > 0) {

364:         if (reward > 0) {

471:         require(amount > 0, "NFTStaker: zero stake");

477:         if (user.amount > 0) {

479:             if (pending > 0) {

481:                 if (pending > 0) emit Claimed(msg.sender, pending);

498:         require(amount > 0, "NFTStaker: zero unstake");

503:         if (pending > 0) {

505:             if (pending > 0) emit Claimed(msg.sender, pending);

522:         if (pending > 0) {

524:             if (paid > 0) emit Claimed(msg.sender, paid);

550:         if (amount > 0) {

580:         require(amount > 0, "NFTStaker: nothing to withdraw");

585:         if (pending > 0) {

609:         if (block.timestamp > lastRewardTime && totalStaked > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 6 |
| [NC-2](#NC-2) | Constants should be in CONSTANT_CASE | 2 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 37 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 6 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 23 |
| [NC-6](#NC-6) | Events should use parameters to convey information | 1 |
| [NC-7](#NC-7) | Event missing indexed field | 20 |
| [NC-8](#NC-8) | Events that mark critical parameter changes should contain both the old and the new value | 24 |
| [NC-9](#NC-9) | Function ordering does not follow the Solidity style guide | 4 |
| [NC-10](#NC-10) | Functions should not be longer than 50 lines | 77 |
| [NC-11](#NC-11) | Lack of checks in setters | 12 |
| [NC-12](#NC-12) | NatSpec is completely non-existent on functions that should have them | 24 |
| [NC-13](#NC-13) | Incomplete NatSpec: `@param` is missing on actually documented functions | 16 |
| [NC-14](#NC-14) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 16 |
| [NC-15](#NC-15) | Constant state variables defined more than once | 10 |
| [NC-16](#NC-16) | Consider using named mappings | 6 |
| [NC-17](#NC-17) | Owner can renounce while system is paused | 4 |
| [NC-18](#NC-18) | Adding a `return` statement when the function defines a named return variable, is redundant | 2 |
| [NC-19](#NC-19) | Take advantage of Custom Error's return value property | 8 |
| [NC-20](#NC-20) | Contract does not follow the Solidity style guide's suggested layout ordering | 4 |
| [NC-21](#NC-21) | Event is missing `indexed` fields | 42 |
| [NC-22](#NC-22) | Variables need not be initialized to zero | 7 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

144:         nudgePaymentToken = newToken;

152:         pauser = newPauser;

```

```solidity
File: NFTStaker.sol

211:         pauser = newPauser;

```

```solidity
File: NFTStakerDepletion.sol

304:         pauser = newPauser;

313:         migrator = newMigrator;

```

```solidity
File: NFTStakerPriceScaled.sol

245:         pauser = newPauser;

```

### <a name="NC-2"></a>[NC-2] Constants should be in CONSTANT_CASE
For `constant` variable names, each word should use all capital letters, with underscores separating each word (CONSTANT_CASE)

*Instances (2)*:
```solidity
File: NFTStaker.sol

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: NFTStakerPriceScaled.sol

79:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (37)*:
```solidity
File: BatchNFTMinter.sol

176:         if (to == address(0)) revert Rescue__ZeroRecipient();

238:         if (count == 0) revert BatchMint__ZeroCount();

239:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

247:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

250:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

```

```solidity
File: InPlaceNFTStakerMigrator.sol

124:         if (idx == 0) return;

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

```solidity
File: NFTStakerDepletion.sol

403:         if (to == address(0)) revert Rescue__ZeroRecipient();

458:         if (block.timestamp <= lastRewardTime) return;

466:         if (reward > rewardBudget) reward = rewardBudget;

551:                 if (pending > 0) emit Claimed(msg.sender, pending);

576:             if (pending > 0) emit Claimed(msg.sender, pending);

594:             if (paid > 0) emit Claimed(msg.sender, paid);

701:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

745:             if (paid > 0) emit Claimed(account, paid);

768:                 if (pending > 0) emit Claimed(user, pending);

820:             if (reward > rewardBudget) reward = rewardBudget;

829:         if (block.timestamp >= windowEnd) return 0;

844:         if (reward > rewardBudget) reward = rewardBudget;

861:         if (rewardRate == 0) return 0;

```

```solidity
File: NFTStakerPriceScaled.sol

355:         if (block.timestamp <= lastRewardTime) return;

363:         if (reward > rewardBudget) reward = rewardBudget;

481:                 if (pending > 0) emit Claimed(msg.sender, pending);

505:             if (pending > 0) emit Claimed(msg.sender, pending);

524:             if (paid > 0) emit Claimed(msg.sender, paid);

613:             if (reward > rewardBudget) reward = rewardBudget;

622:         if (block.timestamp >= windowEnd) return 0;

640:         if (reward > rewardBudget) reward = rewardBudget;

656:         if (rewardRate == 0) return 0;

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

56: contract BatchNFTMinter is Ownable, Pausable, IPausable {

```

```solidity
File: InPlaceNFTStakerMigrator.sol

41: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: NFTStakerDepletion.sol

64: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: NFTStakerMigrator.sol

33: contract NFTStakerMigrator is Ownable, ERC1155Holder {

```

```solidity
File: NFTStakerPriceScaled.sol

54: contract NFTStakerPriceScaled is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (23)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

269:         require(to != address(0), "InPlace: zero recipient");

282:         require(to != address(0), "InPlace: zero recipient");

```

```solidity
File: NFTStaker.sol

197:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

232:         require(totalStaked == 0, "NFTStaker: stake outstanding");

242:         require(totalStaked == 0, "NFTStaker: stake outstanding");

252:         require(totalStaked == 0, "NFTStaker: stake outstanding");

253:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

```

```solidity
File: NFTStakerDepletion.sol

290:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

334:         require(totalStaked == 0, "NFTStaker: stake outstanding");

342:         require(totalStaked == 0, "NFTStaker: stake outstanding");

351:         require(totalStaked == 0, "NFTStaker: stake outstanding");

352:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

665:         require(poolState == PoolState.Active, "NFTStaker: not active");

693:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

717:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

761:         require(poolState == PoolState.Active, "NFTStaker: not active");

790:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

791:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

```solidity
File: NFTStakerPriceScaled.sol

229:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

266:         require(totalStaked == 0, "NFTStaker: stake outstanding");

276:         require(totalStaked == 0, "NFTStaker: stake outstanding");

286:         require(totalStaked == 0, "NFTStaker: stake outstanding");

287:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

```

### <a name="NC-6"></a>[NC-6] Events should use parameters to convey information
For example, rather than using `event Paused()` and `event Unpaused()`, use `event PauseState(address indexed whoChangedIt, bool wasPaused, bool isNowPaused)`

*Instances (1)*:
```solidity
File: NFTStakerDepletion.sol

264:     event PoolReset();

```

### <a name="NC-7"></a>[NC-7] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (20)*:
```solidity
File: BatchNFTMinter.sol

104:     event NudgeSizeChanged(uint256 newSize);

```

```solidity
File: InPlaceNFTStakerMigrator.sol

89:     event MigratedOut(uint256 userCount, uint256 totalAmount);

90:     event MigratedIn(uint256 userCount, uint256 totalAmount);

```

```solidity
File: NFTStaker.sol

154:     event Pulled(uint256 inflow, uint256 newBudget);

159:     event StakedIdChanged(uint256 previous, uint256 next);

161:     event TargetAPYChanged(uint256 previous, uint256 next);

162:     event DispatcherIndexChanged(uint256 previous, uint256 next);

176:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

```

```solidity
File: NFTStakerDepletion.sol

227:     event Pulled(uint256 inflow, uint256 newBudget);

231:     event StakedIdChanged(uint256 previous, uint256 next);

235:     event DepletionWindowChanged(uint256 previous, uint256 next);

236:     event DispatcherIndexChanged(uint256 previous, uint256 next);

245:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

253:     event MigrationInitiated(uint256 totalStaked);

```

```solidity
File: NFTStakerMigrator.sol

46:     event Migrated(uint256 userCount, uint256 totalAmount);

```

```solidity
File: NFTStakerPriceScaled.sol

185:     event Pulled(uint256 inflow, uint256 newBudget);

190:     event StakedIdChanged(uint256 previous, uint256 next);

192:     event TargetAPYChanged(uint256 previous, uint256 next);

193:     event DispatcherIndexChanged(uint256 previous, uint256 next);

207:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

```

### <a name="NC-8"></a>[NC-8] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (24)*:
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

```solidity
File: NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

311:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));

333:     function setStakedId(uint256 newId) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit StakedIdChanged(stakedId, newId);

341:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit DispatcherIndexChanged(dispatcherIndex, newIndex);

350:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             require(address(newMinter) != address(0), "NFTStaker: zero nft minter");
             emit NFTMinterChanged(address(nftMinter), address(newMinter));

364:     function setDepletionWindow(uint256 months) external onlyOwner {
             require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");
             _updatePool();
             emit DepletionWindowChanged(depletionWindowMonths, months);

```

```solidity
File: NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));

265:     function setStakedId(uint256 newId) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit StakedIdChanged(stakedId, newId);

275:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit DispatcherIndexChanged(dispatcherIndex, newIndex);

285:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             require(address(newMinter) != address(0), "NFTStaker: zero nft minter");
             emit NFTMinterChanged(address(nftMinter), address(newMinter));

298:     function setTargetAPY(uint256 newAPY) external onlyOwner {
             require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");
             _updatePool();
             emit TargetAPYChanged(targetAPY, newAPY);

```

### <a name="NC-9"></a>[NC-9] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (4)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

1: 
   Current order:
   private _addParked
   private _removeParked
   external initiateMigration
   external migrateOut
   external migrateIn
   external claimTimedOut
   external rescueERC20
   external rescueERC1155
   external parkedUserCount
   external parkedUsersRange
   external claimableAt
   
   Suggested order:
   external initiateMigration
   external migrateOut
   external migrateIn
   external claimTimedOut
   external rescueERC20
   external rescueERC1155
   external parkedUserCount
   external parkedUsersRange
   external claimableAt
   private _addParked
   private _removeParked

```

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

```solidity
File: NFTStakerDepletion.sol

1: 
   Current order:
   external setPauser
   external setMigrator
   external pause
   external unpause
   external setDispatcherHook
   external setStakedId
   external setDispatcherIndex
   external setNFTMinter
   external setDepletionWindow
   external topUp
   external pullAndRefresh
   external rescueERC20
   internal _syncBudget
   internal _updatePool
   internal _recomputeSchedule
   external stake
   external unstake
   external claim
   internal _safePay
   internal _safePayTo
   external emergencyWithdraw
   external initiateMigration
   external batchMigrate
   external userMigrate
   internal _exitPosition
   external depositFor
   external finalizeAndReset
   external userInfo
   external pendingReward
   external currentRewardRate
   external totalDebt
   external totalBudget
   external runwaySeconds
   
   Suggested order:
   external setPauser
   external setMigrator
   external pause
   external unpause
   external setDispatcherHook
   external setStakedId
   external setDispatcherIndex
   external setNFTMinter
   external setDepletionWindow
   external topUp
   external pullAndRefresh
   external rescueERC20
   external stake
   external unstake
   external claim
   external emergencyWithdraw
   external initiateMigration
   external batchMigrate
   external userMigrate
   external depositFor
   external finalizeAndReset
   external userInfo
   external pendingReward
   external currentRewardRate
   external totalDebt
   external totalBudget
   external runwaySeconds
   internal _syncBudget
   internal _updatePool
   internal _recomputeSchedule
   internal _safePay
   internal _safePayTo
   internal _exitPosition

```

```solidity
File: NFTStakerPriceScaled.sol

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

### <a name="NC-10"></a>[NC-10] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (77)*:
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
File: INFTStakerMigratable.sol

38:     function batchMigrate(address[] calldata users) external returns (uint256[] memory amounts);

46:     function depositFor(address user, uint256 amount) external;

53:     function userInfo(address user) external view returns (uint256 amount, uint256 rewardDebt);

```

```solidity
File: INFTSupply.sol

25:     function totalSupply(uint256 id) external view returns (uint256);

```

```solidity
File: InPlaceNFTStakerMigrator.sol

152:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

186:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

294:     function parkedUserCount() external view returns (uint256) {

299:     function parkedUsersRange(uint256 start, uint256 end) external view returns (address[] memory out) {

315:     function claimableAt(address user) external view returns (uint256) {

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

```solidity
File: NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {

311:     function setMigrator(address newMigrator) external onlyOwner {

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

333:     function setStakedId(uint256 newId) external onlyOwner {

341:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

350:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

364:     function setDepletionWindow(uint256 months) external onlyOwner {

377:     function topUp(uint256 amount) external onlyOwner {

402:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

540:     function stake(uint256 amount) external nonReentrant whenNotPaused {

568:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

588:     function claim() external nonReentrant whenNotPaused {

604:     function _safePay(uint256 amount) internal returns (uint256) {

614:     function _safePayTo(address account, uint256 amount) internal returns (uint256) {

633:     function emergencyWithdraw() external nonReentrant {

664:     function initiateMigration() external override nonReentrant onlyMigrator {

686:     function batchMigrate(address[] calldata accounts)

731:     function _exitPosition(address account) internal returns (uint256 amount, uint256 paid) {

759:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

805:     function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {

810:     function pendingReward(address account) external view returns (uint256) {

828:     function currentRewardRate() external view returns (uint256) {

836:     function totalDebt() external view returns (uint256) {

850:     function totalBudget() external view returns (uint256) {

860:     function runwaySeconds() external view returns (uint256) {

```

```solidity
File: NFTStakerMigrator.sol

81:     function migrate(address[] calldata users) external onlyOwner {

```

```solidity
File: NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

265:     function setStakedId(uint256 newId) external onlyOwner {

275:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

285:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

298:     function setTargetAPY(uint256 newAPY) external onlyOwner {

312:     function topUp(uint256 amount) external onlyOwner {

470:     function stake(uint256 amount) external nonReentrant whenNotPaused {

497:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

518:     function claim() external nonReentrant whenNotPaused {

548:     function _safePay(uint256 amount) internal returns (uint256) {

577:     function emergencyWithdraw() external nonReentrant {

606:     function pendingReward(address account) external view returns (uint256) {

621:     function currentRewardRate() external view returns (uint256) {

633:     function totalDebt() external view returns (uint256) {

646:     function totalBudget() external view returns (uint256) {

655:     function runwaySeconds() external view returns (uint256) {

```

### <a name="NC-11"></a>[NC-11] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (12)*:
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

```solidity
File: NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

311:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);
             migrator = newMigrator;

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

```solidity
File: NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

### <a name="NC-12"></a>[NC-12] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (24)*:
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

```solidity
File: NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {

316:     function pause() external onlyPauser {

320:     function unpause() external onlyPauser {

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

333:     function setStakedId(uint256 newId) external onlyOwner {

540:     function stake(uint256 amount) external nonReentrant whenNotPaused {

568:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

588:     function claim() external nonReentrant whenNotPaused {

```

```solidity
File: NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

248:     function pause() external onlyPauser {

252:     function unpause() external onlyPauser {

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

265:     function setStakedId(uint256 newId) external onlyOwner {

470:     function stake(uint256 amount) external nonReentrant whenNotPaused {

497:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

518:     function claim() external nonReentrant whenNotPaused {

```

### <a name="NC-13"></a>[NC-13] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (16)*:
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
File: InPlaceNFTStakerMigrator.sol

260:     /// @notice Sweep a STRAY/DONATED ERC20 balance to `to`. The migrator never
         ///         holds reward ERC20 as parked principal (parked principal is
         ///         ERC1155), so this is an unconditional ERC20 sweep — the ERC1155
         ///         stake is structurally untouchable by this function.
         /// @dev    Owner-only. Mirrors the spirit of `InPlaceMigrator.rescueERC20`:
         ///         the parked-principal floor is enforced for the staked token,
         ///         which here is an ERC1155 and therefore cannot be reached by an
         ///         ERC20 transfer at all.
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

273:     /// @notice Sweep STRAY ERC1155 of an UNPARKED id, or surplus of the staked
         ///         id strictly above the `totalParked` floor, to `to`. The floor is
         ///         what preserves the no-touch-parked-principal guarantee even
         ///         against the owner.
         /// @dev    Owner-only. For `id == stakedId`, `amount` must be <= balance -
         ///         totalParked (the donated surplus); any amount dipping into
         ///         `totalParked` reverts. For any other id, the full balance is
         ///         free (never parked here).
         function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

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

```solidity
File: NFTStakerDepletion.sol

307:     /// @notice Set/rotate the migration orchestrator authorised to call the
         ///         `onlyMigrator` primitives. Setting to `address(0)` disables
         ///         migration. No empty-pool gate — the migrator must be wired
         ///         before `initiateMigration` is called.
         function setMigrator(address newMigrator) external onlyOwner {

339:     /// @notice Update the dispatcher index (identity only). Guarded by
         ///         `totalStaked == 0` for parity with the other stakers.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

348:     /// @notice Swap the `nftMinter` reference (identity only). Guarded by
         ///         `totalStaked == 0`.
         function setNFTMinter(INFTSupply newMinter) external onlyOwner {

390:     /// @notice Owner-only recovery of an arbitrary ERC20. Modelled on
         ///         `BatchNFTMinter.rescueERC20`: zero-recipient guard, explicit
         ///         amount, `safeTransfer`, `Rescued` event, callable while paused.
         ///
         ///         Non-reward tokens transfer freely. If `token == rewardToken`,
         ///         the call is GUARDED so it cannot strip owed/committed reward:
         ///         settle accrual (`_updatePool`), require the post-transfer
         ///         balance still covers `committedDebt`, then `_recomputeSchedule`
         ///         so `rewardBudget` / `rewardRate` / `windowEnd` re-derive from
         ///         the reduced balance. This lets the owner recover genuine
         ///         surplus without desyncing the
         ///         `balance == rewardBudget + committedDebt` invariant.
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: NFTStakerPriceScaled.sol

271:     /// @notice Update the dispatcher index read from `nftMinter.configs`.
         ///         Guarded by `totalStaked == 0` — a mid-stake swap to a
         ///         different dispatcher could swing APY violently in either
         ///         direction, so the safest policy is to require an empty pool.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

282:     /// @notice Swap the `nftMinter` reference. Guarded by
         ///         `totalStaked == 0` for the same reason as `setStakedId` and
         ///         `setDispatcherIndex`.
         function setNFTMinter(INFTSupply newMinter) external onlyOwner {

```

### <a name="NC-14"></a>[NC-14] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (16)*:
```solidity
File: BatchNFTMinter.sol

113:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: InPlaceNFTStakerMigrator.sol

245:         require(block.timestamp >= migrationBegin[msg.sender] + migrationTimeout, "InPlace: timeout not elapsed");

```

```solidity
File: NFTStaker.sol

183:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

442:                 if (pending > 0) emit Claimed(msg.sender, pending);

466:             if (pending > 0) emit Claimed(msg.sender, pending);

485:             if (paid > 0) emit Claimed(msg.sender, paid);

```

```solidity
File: NFTStakerDepletion.sol

271:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

276:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

551:                 if (pending > 0) emit Claimed(msg.sender, pending);

576:             if (pending > 0) emit Claimed(msg.sender, pending);

594:             if (paid > 0) emit Claimed(msg.sender, paid);

718:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

```

```solidity
File: NFTStakerPriceScaled.sol

214:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

481:                 if (pending > 0) emit Claimed(msg.sender, pending);

505:             if (pending > 0) emit Claimed(msg.sender, pending);

524:             if (paid > 0) emit Claimed(msg.sender, paid);

```

### <a name="NC-15"></a>[NC-15] Constant state variables defined more than once
Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (10)*:
```solidity
File: NFTStaker.sol

39:     uint256 public constant ACC_PRECISION = 1e18;

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

50:     uint256 public constant APY_PRECISION = 1e18;

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: NFTStakerDepletion.sol

72:     uint256 public constant ACC_PRECISION = 1e18;

77:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: NFTStakerPriceScaled.sol

62:     uint256 public constant ACC_PRECISION = 1e18;

69:     uint256 public constant SECONDS_PER_YEAR = 365 days;

73:     uint256 public constant APY_PRECISION = 1e18;

79:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="NC-16"></a>[NC-16] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (6)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

60:     mapping(address => uint256) public parked;

64:     mapping(address => uint256) public migrationBegin;

73:     mapping(address => uint256) private _parkedIndex;

```

```solidity
File: NFTStaker.sol

139:     mapping(address => UserInfo) public users;

```

```solidity
File: NFTStakerDepletion.sol

182:     mapping(address => UserInfo) public users;

```

```solidity
File: NFTStakerPriceScaled.sol

170:     mapping(address => UserInfo) public users;

```

### <a name="NC-17"></a>[NC-17] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (4)*:
```solidity
File: BatchNFTMinter.sol

150:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="NC-18"></a>[NC-18] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (2)*:
```solidity
File: NFTStakerDepletion.sol

724:     /// @dev Shared migration exit for one user: settles+pays their pending
         ///      phUSD (floored in the protocol's favour by the accrual machinery),
         ///      zeroes their position and decrements `totalStaked`. Returns the
         ///      staked ERC1155 `amount` (0 for an empty position) and the `paid`
         ///      phUSD reward. Does NOT transfer the ERC1155 nor emit the exit
         ///      event — the caller forwards the stake (CEI) and emits its own
         ///      `MigratedOut` / `UserMigrated`.
         function _exitPosition(address account) internal returns (uint256 amount, uint256 paid) {
             UserInfo storage user = users[account];
             amount = user.amount;
             if (amount == 0) {
                 return (0, 0);
             }
             // Pending was frozen at the `initiateMigration` snapshot

801:     /// @notice `INFTStakerMigratable` accessor for the public `users` mapping.
         ///         Returns `user`'s currently-credited ERC1155 position and
         ///         reward-debt bookkeeping value. Used by the in-place migrator to
         ///         snapshot credited principal around a `depositFor`.
         function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {
             UserInfo memory info = users[user];
             return (info.amount, info.rewardDebt);

```

### <a name="NC-19"></a>[NC-19] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (8)*:
```solidity
File: BatchNFTMinter.sol

176:         if (to == address(0)) revert Rescue__ZeroRecipient();

238:         if (count == 0) revert BatchMint__ZeroCount();

239:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

243:             revert BatchMint__MinterNotConfigured();

247:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

250:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

256:             revert BatchMint__NudgeTokenMatchesPaymentToken();

```

```solidity
File: NFTStakerDepletion.sol

403:         if (to == address(0)) revert Rescue__ZeroRecipient();

```

### <a name="NC-20"></a>[NC-20] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (4)*:
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

```solidity
File: NFTStakerDepletion.sol

1: 
   Current order:
   UsingForDirective.IERC20
   UsingForDirective.Math
   VariableDeclaration.ACC_PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.SECONDS_PER_MONTH
   VariableDeclaration.MAX_DEPLETION_MONTHS
   VariableDeclaration.stakedToken
   VariableDeclaration.rewardToken
   VariableDeclaration.stakedId
   VariableDeclaration.dispatcherHook
   VariableDeclaration.pauser
   VariableDeclaration.nftMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.depletionWindowMonths
   VariableDeclaration.windowEnd
   VariableDeclaration.rewardRate
   VariableDeclaration.rewardBudget
   VariableDeclaration.committedDebt
   VariableDeclaration.lastRewardTime
   VariableDeclaration.totalStaked
   VariableDeclaration.accRewardPerShare
   StructDefinition.UserInfo
   VariableDeclaration.users
   EnumDefinition.PoolState
   VariableDeclaration.poolState
   VariableDeclaration.migrator
   ErrorDefinition.Rescue__ZeroRecipient
   EventDefinition.Staked
   EventDefinition.Unstaked
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.Pulled
   EventDefinition.ToppedUp
   EventDefinition.DispatcherHookChanged
   EventDefinition.StakedIdChanged
   EventDefinition.PauserChanged
   EventDefinition.DepletionWindowChanged
   EventDefinition.DispatcherIndexChanged
   EventDefinition.NFTMinterChanged
   EventDefinition.ScheduleRecomputed
   EventDefinition.Rescued
   EventDefinition.MigratorSet
   EventDefinition.MigrationInitiated
   EventDefinition.MigratedOut
   EventDefinition.UserMigrated
   EventDefinition.DepositedFor
   EventDefinition.PoolReset
   ModifierDefinition.onlyPauser
   ModifierDefinition.onlyMigrator
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.setMigrator
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.setDispatcherHook
   FunctionDefinition.setStakedId
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNFTMinter
   FunctionDefinition.setDepletionWindow
   FunctionDefinition.topUp
   FunctionDefinition.pullAndRefresh
   FunctionDefinition.rescueERC20
   FunctionDefinition._syncBudget
   FunctionDefinition._updatePool
   FunctionDefinition._recomputeSchedule
   FunctionDefinition.stake
   FunctionDefinition.unstake
   FunctionDefinition.claim
   FunctionDefinition._safePay
   FunctionDefinition._safePayTo
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.initiateMigration
   FunctionDefinition.batchMigrate
   FunctionDefinition.userMigrate
   FunctionDefinition._exitPosition
   FunctionDefinition.depositFor
   FunctionDefinition.finalizeAndReset
   FunctionDefinition.userInfo
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
   VariableDeclaration.SECONDS_PER_MONTH
   VariableDeclaration.MAX_DEPLETION_MONTHS
   VariableDeclaration.stakedToken
   VariableDeclaration.rewardToken
   VariableDeclaration.stakedId
   VariableDeclaration.dispatcherHook
   VariableDeclaration.pauser
   VariableDeclaration.nftMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.depletionWindowMonths
   VariableDeclaration.windowEnd
   VariableDeclaration.rewardRate
   VariableDeclaration.rewardBudget
   VariableDeclaration.committedDebt
   VariableDeclaration.lastRewardTime
   VariableDeclaration.totalStaked
   VariableDeclaration.accRewardPerShare
   VariableDeclaration.users
   VariableDeclaration.poolState
   VariableDeclaration.migrator
   EnumDefinition.PoolState
   StructDefinition.UserInfo
   ErrorDefinition.Rescue__ZeroRecipient
   EventDefinition.Staked
   EventDefinition.Unstaked
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.Pulled
   EventDefinition.ToppedUp
   EventDefinition.DispatcherHookChanged
   EventDefinition.StakedIdChanged
   EventDefinition.PauserChanged
   EventDefinition.DepletionWindowChanged
   EventDefinition.DispatcherIndexChanged
   EventDefinition.NFTMinterChanged
   EventDefinition.ScheduleRecomputed
   EventDefinition.Rescued
   EventDefinition.MigratorSet
   EventDefinition.MigrationInitiated
   EventDefinition.MigratedOut
   EventDefinition.UserMigrated
   EventDefinition.DepositedFor
   EventDefinition.PoolReset
   ModifierDefinition.onlyPauser
   ModifierDefinition.onlyMigrator
   FunctionDefinition.constructor
   FunctionDefinition.setPauser
   FunctionDefinition.setMigrator
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.setDispatcherHook
   FunctionDefinition.setStakedId
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNFTMinter
   FunctionDefinition.setDepletionWindow
   FunctionDefinition.topUp
   FunctionDefinition.pullAndRefresh
   FunctionDefinition.rescueERC20
   FunctionDefinition._syncBudget
   FunctionDefinition._updatePool
   FunctionDefinition._recomputeSchedule
   FunctionDefinition.stake
   FunctionDefinition.unstake
   FunctionDefinition.claim
   FunctionDefinition._safePay
   FunctionDefinition._safePayTo
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.initiateMigration
   FunctionDefinition.batchMigrate
   FunctionDefinition.userMigrate
   FunctionDefinition._exitPosition
   FunctionDefinition.depositFor
   FunctionDefinition.finalizeAndReset
   FunctionDefinition.userInfo
   FunctionDefinition.pendingReward
   FunctionDefinition.currentRewardRate
   FunctionDefinition.totalDebt
   FunctionDefinition.totalBudget
   FunctionDefinition.runwaySeconds

```

```solidity
File: NFTStakerPriceScaled.sol

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
   VariableDeclaration.priceScale
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
   VariableDeclaration.priceScale
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

### <a name="NC-21"></a>[NC-21] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (42)*:
```solidity
File: BatchNFTMinter.sol

104:     event NudgeSizeChanged(uint256 newSize);

106:     event NudgePaid(address indexed recipient, address indexed token, uint256 amount);

109:     event Rescued(address indexed token, address indexed to, uint256 amount);

```

```solidity
File: InPlaceNFTStakerMigrator.sol

89:     event MigratedOut(uint256 userCount, uint256 totalAmount);

90:     event MigratedIn(uint256 userCount, uint256 totalAmount);

91:     event TimedOutClaim(address indexed user, uint256 amount);

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

```solidity
File: NFTStakerDepletion.sol

221:     event Staked(address indexed user, uint256 amount);

222:     event Unstaked(address indexed user, uint256 amount);

223:     event Claimed(address indexed user, uint256 amount);

224:     event EmergencyWithdrawn(address indexed user, uint256 amount);

227:     event Pulled(uint256 inflow, uint256 newBudget);

229:     event ToppedUp(address indexed from, uint256 amount, uint256 newBudget);

231:     event StakedIdChanged(uint256 previous, uint256 next);

235:     event DepletionWindowChanged(uint256 previous, uint256 next);

236:     event DispatcherIndexChanged(uint256 previous, uint256 next);

245:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

248:     event Rescued(address indexed token, address indexed to, uint256 amount);

253:     event MigrationInitiated(uint256 totalStaked);

257:     event MigratedOut(address indexed user, uint256 amount, uint256 reward);

260:     event UserMigrated(address indexed user, uint256 amount, uint256 reward);

262:     event DepositedFor(address indexed user, uint256 amount);

```

```solidity
File: NFTStakerMigrator.sol

46:     event Migrated(uint256 userCount, uint256 totalAmount);

```

```solidity
File: NFTStakerPriceScaled.sol

176:     event Staked(address indexed user, uint256 amount);

177:     event Unstaked(address indexed user, uint256 amount);

178:     event Claimed(address indexed user, uint256 amount);

179:     event EmergencyWithdrawn(address indexed user, uint256 amount);

185:     event Pulled(uint256 inflow, uint256 newBudget);

188:     event ToppedUp(address indexed from, uint256 amount, uint256 newBudget);

190:     event StakedIdChanged(uint256 previous, uint256 next);

192:     event TargetAPYChanged(uint256 previous, uint256 next);

193:     event DispatcherIndexChanged(uint256 previous, uint256 next);

207:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

```

### <a name="NC-22"></a>[NC-22] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (7)*:
```solidity
File: InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

197:         for (uint256 i = 0; i < sliceLen; i++) {

210:         for (uint256 i = 0; i < sliceLen; i++) {

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 6 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 13 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 6 |
| [L-4](#L-4) | Division by zero not prevented | 12 |
| [L-5](#L-5) | Owner can renounce while system is paused | 4 |
| [L-6](#L-6) | Possible rounding issue | 6 |
| [L-7](#L-7) | Loss of precision | 36 |
| [L-8](#L-8) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 6 |
| [L-9](#L-9) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 6 |
| [L-10](#L-10) | Sweeping may break accounting if tokens with multiple addresses are used | 4 |
| [L-11](#L-11) | A year is not always 365 days | 3 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

56: contract BatchNFTMinter is Ownable, Pausable, IPausable {

```

```solidity
File: InPlaceNFTStakerMigrator.sol

41: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: NFTStakerDepletion.sol

64: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: NFTStakerMigrator.sol

33: contract NFTStakerMigrator is Ownable, ERC1155Holder {

```

```solidity
File: NFTStakerPriceScaled.sol

54: contract NFTStakerPriceScaled is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (13)*:
```solidity
File: BatchNFTMinter.sol

177:         token.safeTransfer(to, amount);

277:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

295:             IERC20(_nudgeTokenEntry).safeTransfer(recipient, nudgeAmount);

301:             paymentToken.safeTransfer(msg.sender, remaining);

```

```solidity
File: InPlaceNFTStakerMigrator.sol

270:         token.safeTransfer(to, amount);

```

```solidity
File: NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

512:             rewardToken.safeTransfer(msg.sender, amount);

```

```solidity
File: NFTStakerDepletion.sol

380:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

406:             token.safeTransfer(to, amount);

410:             token.safeTransfer(to, amount);

617:             rewardToken.safeTransfer(account, amount);

```

```solidity
File: NFTStakerPriceScaled.sol

315:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

551:             rewardToken.safeTransfer(msg.sender, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

144:         nudgePaymentToken = newToken;

152:         pauser = newPauser;

```

```solidity
File: NFTStaker.sol

211:         pauser = newPauser;

```

```solidity
File: NFTStakerDepletion.sol

304:         pauser = newPauser;

313:         migrator = newMigrator;

```

```solidity
File: NFTStakerPriceScaled.sol

245:         pauser = newPauser;

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (12)*:
```solidity
File: NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

418:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

619:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: NFTStakerDepletion.sol

470:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

526:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

821:             acc += (reward * ACC_PRECISION) / totalStaked;

863:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: NFTStakerPriceScaled.sol

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

457:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

658:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="L-5"></a>[L-5] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (4)*:
```solidity
File: BatchNFTMinter.sol

150:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="L-6"></a>[L-6] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (6)*:
```solidity
File: NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: NFTStakerDepletion.sol

470:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

821:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: NFTStakerPriceScaled.sol

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

```

### <a name="L-7"></a>[L-7] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (36)*:
```solidity
File: BatchNFTMinter.sol

300:         if (remaining / DUST_THRESHOLD != 0) {

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

```solidity
File: NFTStakerDepletion.sol

470:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

548:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

557:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

573:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

580:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

591:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

596:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

637:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

739:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

765:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

774:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

821:             acc += (reward * ACC_PRECISION) / totalStaked;

823:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

```

```solidity
File: NFTStakerPriceScaled.sol

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

456:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

478:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

487:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

502:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

509:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

521:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

526:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

581:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

616:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

```

### <a name="L-8"></a>[L-8] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: InPlaceNFTStakerMigrator.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: NFTStaker.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: NFTStakerDepletion.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: NFTStakerMigrator.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: NFTStakerPriceScaled.sol

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

*Instances (6)*:
```solidity
File: BatchNFTMinter.sol

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: InPlaceNFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: NFTStaker.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: NFTStakerDepletion.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: NFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: NFTStakerPriceScaled.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-10"></a>[L-10] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (4)*:
```solidity
File: BatchNFTMinter.sol

175:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: InPlaceNFTStakerMigrator.sol

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: NFTStakerDepletion.sol

402:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

### <a name="L-11"></a>[L-11] A year is not always 365 days
On leap years, the number of days is 366, so calculations during those years will return the wrong value

*Instances (3)*:
```solidity
File: NFTStaker.sol

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: NFTStakerDepletion.sol

77:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: NFTStakerPriceScaled.sol

69:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 4 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 52 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (4)*:
```solidity
File: BatchNFTMinter.sol

277:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

```

```solidity
File: NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: NFTStakerDepletion.sol

380:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: NFTStakerPriceScaled.sol

315:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (52)*:
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
File: InPlaceNFTStakerMigrator.sol

41: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

99:     ) Ownable(initialOwner) {

140:     function initiateMigration() external onlyOwner {

152:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

186:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

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

```solidity
File: NFTStakerDepletion.sol

64: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

287:     ) Ownable(_initialOwner) {

302:     function setPauser(address newPauser) external onlyOwner {

311:     function setMigrator(address newMigrator) external onlyOwner {

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

333:     function setStakedId(uint256 newId) external onlyOwner {

341:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

350:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

364:     function setDepletionWindow(uint256 months) external onlyOwner {

377:     function topUp(uint256 amount) external onlyOwner {

386:     function pullAndRefresh() external onlyOwner {

402:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

789:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: NFTStakerMigrator.sol

33: contract NFTStakerMigrator is Ownable, ERC1155Holder {

54:     ) Ownable(initialOwner) {

70:     function initiateMigration() external onlyOwner {

81:     function migrate(address[] calldata users) external onlyOwner {

```

```solidity
File: NFTStakerPriceScaled.sol

54: contract NFTStakerPriceScaled is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

226:     ) Ownable(_initialOwner) {

243:     function setPauser(address newPauser) external onlyOwner {

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

265:     function setStakedId(uint256 newId) external onlyOwner {

275:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

285:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

298:     function setTargetAPY(uint256 newAPY) external onlyOwner {

312:     function topUp(uint256 amount) external onlyOwner {

321:     function pullAndRefresh() external onlyOwner {

```

