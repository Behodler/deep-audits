# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 58 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 66 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 7 |
| [GAS-4](#GAS-4) | State variables should be cached in stack variables rather than re-reading them from storage | 2 |
| [GAS-5](#GAS-5) | For Operations that will not overflow, you could use unchecked | 383 |
| [GAS-6](#GAS-6) | Use Custom Errors instead of Revert Strings to save Gas | 134 |
| [GAS-7](#GAS-7) | Avoid contract existence checks by using low level calls | 48 |
| [GAS-8](#GAS-8) | State variables only set in the constructor should be declared `immutable` | 21 |
| [GAS-9](#GAS-9) | Functions guaranteed to revert when called by normal users can be marked `payable` | 92 |
| [GAS-10](#GAS-10) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 12 |
| [GAS-11](#GAS-11) | Using `private` rather than `public` for constants, saves gas | 23 |
| [GAS-12](#GAS-12) | Splitting require() statements that use && saves gas | 3 |
| [GAS-13](#GAS-13) | Increments/decrements can be unchecked in for-loops | 14 |
| [GAS-14](#GAS-14) | Use != 0 instead of > 0 for unsigned integer comparison | 116 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (58)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

227:                 parked[users[i]] += amt;

230:                 totalParked += amt;

231:                 total += amt;

288:             total += amt;

328:                     unforwarded[user] += captured;

329:                     totalUnforwarded += captured;

333:                 unforwarded[user] += captured;

334:                 totalUnforwarded += captured;

```

```solidity
File: src/NFTStaker.sol

332:             committedDebt += reward;

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

405:             V += dispatcherHook.mintDebt();

446:         user.amount += amount;

447:         totalStaked += amount;

557:             rewardBudget += forfeit;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerDepletion.sol

479:             committedDebt += reward;

480:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

528:             V += dispatcherHook.mintDebt();

565:         user.amount += amount;

566:         totalStaked += amount;

644:             rewardBudget += forfeit;

700:             totalAmount += amount;

783:         info.amount += amount;

784:         totalStaked += amount;

832:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerDepletionV2.sol

480:             committedDebt += reward;

481:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

529:             V += dispatcherHook.mintDebt();

571:         user.amount += amount;

572:         totalStaked += amount;

650:             rewardBudget += forfeit;

706:             totalAmount += amount;

787:         info.amount += amount;

788:         totalStaked += amount;

836:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerMigrator.sol

175:             total += amounts[i];

231:                     unforwarded[user] += captured;

232:                     totalUnforwarded += captured;

236:                 unforwarded[user] += captured;

237:                 totalUnforwarded += captured;

```

```solidity
File: src/NFTStakerPriceScaled.sol

366:             committedDebt += reward;

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

444:             V += dispatcherHook.mintDebt();

485:         user.amount += amount;

486:         totalStaked += amount;

596:             rewardBudget += forfeit;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

522:             committedDebt += reward;

523:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

600:             V += dispatcherHook.mintDebt();

646:         user.amount += amount;

647:         totalStaked += amount;

768:             rewardBudget += forfeit;

825:             totalAmount += amount;

906:         info.amount += amount;

907:         totalStaked += amount;

972:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NudgeStreamer.sol

201:         s.buffer += received;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (66)*:
```solidity
File: src/BatchNFTMinter.sol

182:         if (to == address(0)) revert Rescue__ZeroRecipient();

245:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

248:         if (address(nftMinter) == address(0)) {

256:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

261:         if (_nudgeTokenEntry != address(0) && _nudgeTokenEntry == address(paymentToken)) {

279:         if (_nudgeSize != 0 && count >= _nudgeSize && _nudgeTokenEntry != address(0)) {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

330:             if (token == address(0)) revert BatchMint__ZeroNudgeToken();

387:         if (to == address(0)) revert Rescue__ZeroRecipient();

472:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

531:                 uint256 nudgeCount = _nudgeTokens.length;

740:             revert BatchMint__MinterNotConfigured();

748:         paymentToken = IERC20(ITokenDispatcherV2(dispatcher).primeToken());

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

163:         require(address(_staker) != address(0), "InPlace: zero staker");

164:         require(address(_stakedToken) != address(0), "InPlace: zero staked token");

166:         require(address(_rewardToken) != address(0), "InPlace: zero reward token");

391:         require(to != address(0), "InPlace: zero recipient");

409:         require(to != address(0), "InPlace: zero recipient");

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

299:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

300:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

301:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

363:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

414:         if (to == address(0)) revert Rescue__ZeroRecipient();

436:         if (address(dispatcherHook) == address(0)) {

527:         if (address(dispatcherHook) != address(0)) {

862:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

873:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

```solidity
File: src/NFTStakerDepletionV2.sol

300:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

301:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

302:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

364:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

415:         if (to == address(0)) revert Rescue__ZeroRecipient();

437:         if (address(dispatcherHook) == address(0)) {

529:             V += dispatcherHook.mintDebt();

866:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

877:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

```solidity
File: src/NFTStakerMigrator.sol

128:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

129:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

130:         require(address(_stakedToken) != address(0), "Migrator: zero staked token");

132:         require(address(_rewardToken) != address(0), "Migrator: zero reward token");

269:         require(to != address(0), "Migrator: zero recipient");

287:         require(to != address(0), "Migrator: zero recipient");

```

```solidity
File: src/NFTStakerPriceScaled.sol

227:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

228:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

229:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

287:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

335:         if (address(dispatcherHook) == address(0)) {

443:         if (address(dispatcherHook) != address(0)) {

647:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

657:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

323:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

324:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

325:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

392:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

443:         if (to == address(0)) revert Rescue__ZeroRecipient();

471:         if (address(dispatcherHook) == address(0)) {

599:         if (address(dispatcherHook) != address(0)) {

1006:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

1016:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (7)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

224:         for (uint256 i = 0; i < users.length; i++) {

435:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerDepletionV2.sol

703:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

174:         for (uint256 i = 0; i < amounts.length; i++) {

189:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

822:         for (uint256 i = 0; i < accounts.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (2)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

299:         emit MigratedIn(count, total);

```

```solidity
File: src/NFTStakerMigrator.sol

186:         stakedToken.setApprovalForAll(address(newStaker), true);

```

### <a name="GAS-5"></a>[GAS-5] For Operations that will not overflow, you could use unchecked

*Instances (383)*:
```solidity
File: src/BatchNFTMinter.sol

4: import {ITokenMinterV2} from "yield-claim-nft/interfaces/ITokenMinterV2.sol";

5: import {INFTMinterV2} from "yield-claim-nft/interfaces/INFTMinterV2.sol";

6: import {ITokenDispatcherV2} from "yield-claim-nft/interfaces/ITokenDispatcherV2.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

10: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

11: import {IPausable} from "pauser/interfaces/IPausable.sol";

286:         for (uint256 i; i < count; ++i) {

306:         if (remaining / DUST_THRESHOLD != 0) {

308:             totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0;

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

4: import {ITokenMinterV2} from "yield-claim-nft/interfaces/ITokenMinterV2.sol";

5: import {INFTMinterV2} from "yield-claim-nft/interfaces/INFTMinterV2.sol";

6: import {ITokenDispatcherV2} from "yield-claim-nft/interfaces/ITokenDispatcherV2.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

10: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

11: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

12: import {IPausable} from "pauser/interfaces/IPausable.sol";

13: import {INudgeStreamer} from "./INudgeStreamer.sol";

341:                 address lastToken = _nudgeTokens[length - 1];

342:                 _nudgeTokens[oneBasedIndex - 1] = lastToken;

532:                 for (uint256 i; i < nudgeCount; ++i) {

582:             uint256 credited = paymentToken.balanceOf(address(this)) - heldBeforePull;

645:         for (uint256 i; i < count; ++i) {

649:             budget -= price;

710:             if (refund / DUST_THRESHOLD != 0) {

712:                 totalPaid = paymentAmount - refund;

799:         for (uint256 i; i < tokenCount; ++i) {

829:         for (uint256 i; i < tokenCount; ++i) {

```

```solidity
File: src/INudgeStreamer.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

```

```solidity
File: src/IStakerViews.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

9: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

10: import {INFTStakerMigratable} from "./INFTStakerMigratable.sol";

11: import {IStakerViews} from "./IStakerViews.sol";

184:             _parkedIndex[user] = _parkedUsers.length; // 1-based

194:             address moved = _parkedUsers[last - 1];

195:             _parkedUsers[idx - 1] = moved;

224:         for (uint256 i = 0; i < users.length; i++) {

227:                 parked[users[i]] += amt;

230:                 totalParked += amt;

231:                 total += amt;

232:                 count++;

262:         uint256 sliceLen = end - start;

264:         for (uint256 i = 0; i < sliceLen; i++) {

265:             slice[i] = _parkedUsers[start + i];

277:         for (uint256 i = 0; i < sliceLen; i++) {

286:             totalParked -= amt;

288:             total += amt;

289:             count++;

317:         uint256 captured = rewardToken.balanceOf(address(this)) - pre;

328:                     unforwarded[user] += captured;

329:                     totalUnforwarded += captured;

333:                 unforwarded[user] += captured;

334:                 totalUnforwarded += captured;

350:         totalUnforwarded -= amount;

367:         require(block.timestamp >= migrationBegin[msg.sender] + migrationTimeout, "InPlace: timeout not elapsed");

372:         totalParked -= amount;

394:             uint256 surplus = balance - totalUnforwarded;

412:             uint256 surplus = balance - totalParked;

434:         out = new address[](end - start);

435:         for (uint256 i = 0; i < out.length; i++) {

436:             out[i] = _parkedUsers[start + i];

447:         return begin + migrationTimeout;

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

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

94:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

435:         _updatePool();                                 // always: settle accrual

437:             return;                                    // no hook → no pull → no budget change → no recompute

441:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

442:         if (inflow > 0) {                              // new NFT minted → budget grew → restart window (intended)

474:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

475:         uint256 reward = elapsed * rewardRate;

478:             rewardBudget -= reward;

479:             committedDebt += reward;

480:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

524:         uint256 windowSeconds = depletionWindowMonths * SECONDS_PER_MONTH;

528:             V += dispatcherHook.mintDebt();

534:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

536:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

540:         windowEnd = block.timestamp + windowSeconds;

558:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

565:         user.amount += amount;

566:         totalStaked += amount;

567:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

576:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

581:         user.amount -= amount;

582:         totalStaked -= amount;

583:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

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

776:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

783:         info.amount += amount;

784:         totalStaked += amount;

785:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

829:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

830:             uint256 reward = elapsed * rewardRate;

832:             acc += (reward * ACC_PRECISION) / totalStaked;

834:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

853:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

854:         uint256 reward = elapsed * rewardRate;

856:         return committedDebt + reward;

863:         return rewardToken.balanceOf(address(this)) + pending;

874:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerDepletionV2.sol

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

95:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

436:         _updatePool();                                 // always: settle accrual

438:             return;                                    // no hook → no pull → no budget change → no recompute

442:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

443:         if (inflow > 0) {                              // new NFT minted → budget grew → restart window (intended)

475:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

476:         uint256 reward = elapsed * rewardRate;

479:             rewardBudget -= reward;

480:             committedDebt += reward;

481:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

525:         uint256 windowSeconds = depletionWindowMonths * SECONDS_PER_MONTH;

529:             V += dispatcherHook.mintDebt();

535:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

537:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

541:         windowEnd = block.timestamp + windowSeconds;

564:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

571:         user.amount += amount;

572:         totalStaked += amount;

573:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

582:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

587:         user.amount -= amount;

588:         totalStaked -= amount;

589:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

597:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

602:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

625:                 rewardBudget -= (amount - committedDebt);

628:                 committedDebt -= amount;

643:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

646:         totalStaked -= amount;

649:             committedDebt -= forfeit;

650:             rewardBudget += forfeit;

703:         for (uint256 i = 0; i < accounts.length; i++) {

706:             totalAmount += amount;

745:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

748:         totalStaked -= amount;

780:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

787:         info.amount += amount;

788:         totalStaked += amount;

789:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

833:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

834:             uint256 reward = elapsed * rewardRate;

836:             acc += (reward * ACC_PRECISION) / totalStaked;

838:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

857:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

858:         uint256 reward = elapsed * rewardRate;

860:         return committedDebt + reward;

867:         return rewardToken.balanceOf(address(this)) + pending;

878:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

6: import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

7: import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

10: import {INFTStakerMigratable} from "./INFTStakerMigratable.sol";

11: import {IStakerViews} from "./IStakerViews.sol";

174:         for (uint256 i = 0; i < amounts.length; i++) {

175:             total += amounts[i];

189:         for (uint256 i = 0; i < users.length; i++) {

192:                 migratedCount++;

220:         uint256 captured = rewardToken.balanceOf(address(this)) - pre;

231:                     unforwarded[user] += captured;

232:                     totalUnforwarded += captured;

236:                 unforwarded[user] += captured;

237:                 totalUnforwarded += captured;

252:         totalUnforwarded -= amount;

272:             uint256 surplus = balance - totalUnforwarded;

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

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

15: import {INFTStakerMigratable} from "./INFTStakerMigratable.sol";

118:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

477:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

517:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

518:         uint256 reward = elapsed * rewardRate;

521:             rewardBudget -= reward;

522:             committedDebt += reward;

523:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

585:             uint256 r = APY_PRECISION + growthBasisPoints * 1e14;

591:         latestPrice = latestPrice * priceScale;

596:         uint256 S = (totalStaked == 0 || latestPrice == 0) ? 0 : totalStaked * latestPrice;

600:             V += dispatcherHook.mintDebt();

609:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

612:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

613:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

617:         windowEnd = block.timestamp + runway;

639:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

646:         user.amount += amount;

647:         totalStaked += amount;

648:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

664:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

669:         user.amount -= amount;

670:         totalStaked -= amount;

671:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

683:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

688:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

725:                 rewardBudget -= (amount - committedDebt);

728:                 committedDebt -= amount;

753:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

756:         totalStaked -= amount;

767:             committedDebt -= forfeit;

768:             rewardBudget += forfeit;

822:         for (uint256 i = 0; i < accounts.length; i++) {

825:             totalAmount += amount;

864:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

867:         totalStaked -= amount;

899:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

906:         info.amount += amount;

907:         totalStaked += amount;

908:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

969:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

970:             uint256 reward = elapsed * rewardRate;

972:             acc += (reward * ACC_PRECISION) / totalStaked;

974:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

997:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

998:         uint256 reward = elapsed * rewardRate;

1000:         return committedDebt + reward;

1007:         return rewardToken.balanceOf(address(this)) + pending;

1017:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NudgeStreamer.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

7: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

8: import {INudgeStreamer} from "./INudgeStreamer.sol";

139:         s.rewardPerSecond = (s.buffer * PRECISION) / duration;

195:         uint256 received = IERC20(token).balanceOf(address(this)) - heldBefore;

201:         s.buffer += received;

206:         s.rewardPerSecond = (s.buffer * PRECISION) / s.duration;

222:         if (s.duration == 0) return; // not registered -> no-op

242:             s.buffer -= settled;

267:         uint256 elapsed = block.timestamp - s.lastUpdate;

268:         uint256 accrued = (s.rewardPerSecond * elapsed) / PRECISION;

```

### <a name="GAS-6"></a>[GAS-6] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (134)*:
```solidity
File: src/BatchNFTMinter.sol

119:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

249:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

163:         require(address(_staker) != address(0), "InPlace: zero staker");

164:         require(address(_stakedToken) != address(0), "InPlace: zero staked token");

165:         require(_migrationTimeout >= MIN_TIMEOUT && _migrationTimeout <= MAX_TIMEOUT, "InPlace: timeout out of bounds");

166:         require(address(_rewardToken) != address(0), "InPlace: zero reward token");

258:         require(start <= end, "InPlace: bad range");

318:         require(captured <= owed, "Migrator: capture exceeds owed");

347:         require(amount > 0, "InPlace: nothing unforwarded");

366:         require(amount > 0, "InPlace: nothing parked");

367:         require(block.timestamp >= migrationBegin[msg.sender] + migrationTimeout, "InPlace: timeout not elapsed");

391:         require(to != address(0), "InPlace: zero recipient");

395:             require(amount <= surplus, "InPlace: cannot touch unforwarded");

409:         require(to != address(0), "InPlace: zero recipient");

413:             require(amount <= surplus, "InPlace: cannot touch parked principal");

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

282:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

287:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

299:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

300:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

301:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

345:         require(totalStaked == 0, "NFTStaker: stake outstanding");

353:         require(totalStaked == 0, "NFTStaker: stake outstanding");

362:         require(totalStaked == 0, "NFTStaker: stake outstanding");

363:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

376:         require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");

389:         require(amount > 0, "NFTStaker: zero topUp");

418:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

551:         require(amount > 0, "NFTStaker: zero stake");

572:         require(amount > 0, "NFTStaker: zero unstake");

574:         require(user.amount >= amount, "NFTStaker: insufficient stake");

615:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

636:         require(amount > 0, "NFTStaker: nothing to withdraw");

665:         require(poolState == PoolState.Active, "NFTStaker: not active");

693:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

717:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

718:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

771:         require(amount > 0, "NFTStaker: zero deposit");

772:         require(poolState == PoolState.Active, "NFTStaker: not active");

801:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

802:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

```solidity
File: src/NFTStakerDepletionV2.sol

283:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

288:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

300:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

301:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

302:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

346:         require(totalStaked == 0, "NFTStaker: stake outstanding");

354:         require(totalStaked == 0, "NFTStaker: stake outstanding");

363:         require(totalStaked == 0, "NFTStaker: stake outstanding");

364:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

377:         require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");

390:         require(amount > 0, "NFTStaker: zero topUp");

419:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

552:         require(amount > 0, "NFTStaker: zero stake");

557:         require(poolState == PoolState.Active, "NFTStaker: not active");

578:         require(amount > 0, "NFTStaker: zero unstake");

580:         require(user.amount >= amount, "NFTStaker: insufficient stake");

621:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

642:         require(amount > 0, "NFTStaker: nothing to withdraw");

671:         require(poolState == PoolState.Active, "NFTStaker: not active");

699:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

723:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

724:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

775:         require(amount > 0, "NFTStaker: zero deposit");

776:         require(poolState == PoolState.Active, "NFTStaker: not active");

805:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

806:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

```solidity
File: src/NFTStakerMigrator.sol

128:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

129:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

130:         require(address(_stakedToken) != address(0), "Migrator: zero staked token");

131:         require(address(_oldStaker) != address(_newStaker), "Migrator: same staker");

132:         require(address(_rewardToken) != address(0), "Migrator: zero reward token");

221:         require(captured <= owed, "Migrator: capture exceeds owed");

249:         require(amount > 0, "Migrator: nothing unforwarded");

269:         require(to != address(0), "Migrator: zero recipient");

273:             require(amount <= surplus, "Migrator: cannot touch unforwarded");

287:         require(to != address(0), "Migrator: zero recipient");

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

305:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

310:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

323:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

324:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

325:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

326:         require(_priceScale != 0, "NFTStaker: zero price scale");

371:         require(totalStaked == 0, "NFTStaker: stake outstanding");

381:         require(totalStaked == 0, "NFTStaker: stake outstanding");

391:         require(totalStaked == 0, "NFTStaker: stake outstanding");

392:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

404:         require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");

418:         require(amount > 0, "NFTStaker: zero topUp");

447:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

627:         require(amount > 0, "NFTStaker: zero stake");

632:         require(poolState == PoolState.Active, "NFTStaker: not active");

660:         require(amount > 0, "NFTStaker: zero unstake");

662:         require(user.amount >= amount, "NFTStaker: insufficient stake");

721:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

752:         require(amount > 0, "NFTStaker: nothing to withdraw");

789:         require(poolState == PoolState.Active, "NFTStaker: not active");

818:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

842:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

843:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

894:         require(amount > 0, "NFTStaker: zero deposit");

895:         require(poolState == PoolState.Active, "NFTStaker: not active");

940:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

941:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

### <a name="GAS-7"></a>[GAS-7] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (48)*:
```solidity
File: src/BatchNFTMinter.sol

280:             nudgeAmount = IERC20(_nudgeTokenEntry).balanceOf(address(this));

305:         uint256 remaining = paymentToken.balanceOf(address(this));

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

580:             uint256 heldBeforePull = paymentToken.balanceOf(address(this));

582:             uint256 credited = paymentToken.balanceOf(address(this)) - heldBeforePull;

708:             uint256 available = paymentToken.balanceOf(address(this));

801:             uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

313:         uint256 pre = rewardToken.balanceOf(address(this));

317:         uint256 captured = rewardToken.balanceOf(address(this)) - pre;

393:             uint256 balance = rewardToken.balanceOf(address(this));

411:             uint256 balance = stakedToken.balanceOf(address(this), stakedId);

```

```solidity
File: src/NFTStaker.sol

305:         uint256 pre = rewardToken.balanceOf(address(this));

307:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

403:         uint256 V = rewardToken.balanceOf(address(this));

510:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

609:         return rewardToken.balanceOf(address(this)) + pending;

619:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerDepletion.sol

418:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

439:         uint256 pre = rewardToken.balanceOf(address(this));

441:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

526:         uint256 V = rewardToken.balanceOf(address(this));

615:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

863:         return rewardToken.balanceOf(address(this)) + pending;

874:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerDepletionV2.sol

419:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

440:         uint256 pre = rewardToken.balanceOf(address(this));

442:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

527:         uint256 V = rewardToken.balanceOf(address(this));

621:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

867:         return rewardToken.balanceOf(address(this)) + pending;

878:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerMigrator.sol

216:         uint256 pre = rewardToken.balanceOf(address(this));

220:         uint256 captured = rewardToken.balanceOf(address(this)) - pre;

271:             uint256 balance = rewardToken.balanceOf(address(this));

```

```solidity
File: src/NFTStakerPriceScaled.sol

339:         uint256 pre = rewardToken.balanceOf(address(this));

341:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

442:         uint256 V = rewardToken.balanceOf(address(this));

549:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

648:         return rewardToken.balanceOf(address(this)) + pending;

658:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

447:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

475:         uint256 pre = rewardToken.balanceOf(address(this));

477:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

598:         uint256 V = rewardToken.balanceOf(address(this));

721:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

1007:         return rewardToken.balanceOf(address(this)) + pending;

1017:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NudgeStreamer.sol

193:         uint256 heldBefore = IERC20(token).balanceOf(address(this));

195:         uint256 received = IERC20(token).balanceOf(address(this)) - heldBefore;

```

### <a name="GAS-8"></a>[GAS-8] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (21)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

172:         stakedToken = _stakedToken;

173:         stakedId = _stakedId;

174:         migrationTimeout = _migrationTimeout;

175:         rewardToken = _rewardToken;

```

```solidity
File: src/NFTStaker.sol

198:         stakedToken = _stakedToken;

200:         rewardToken = _rewardToken;

```

```solidity
File: src/NFTStakerDepletion.sol

302:         stakedToken = _stakedToken;

304:         rewardToken = _rewardToken;

```

```solidity
File: src/NFTStakerDepletionV2.sol

303:         stakedToken = _stakedToken;

305:         rewardToken = _rewardToken;

```

```solidity
File: src/NFTStakerMigrator.sol

141:         oldStaker = _oldStaker;

142:         newStaker = _newStaker;

143:         stakedToken = _stakedToken;

144:         stakedId = _stakedId;

145:         rewardToken = _rewardToken;

```

```solidity
File: src/NFTStakerPriceScaled.sol

231:         stakedToken = _stakedToken;

233:         rewardToken = _rewardToken;

236:         priceScale = _priceScale;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

327:         stakedToken = _stakedToken;

329:         rewardToken = _rewardToken;

332:         priceScale = _priceScale;

```

### <a name="GAS-9"></a>[GAS-9] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (92)*:
```solidity
File: src/BatchNFTMinter.sol

126:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

135:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

142:     function setNudgeSize(uint256 newSize) external onlyOwner {

149:     function setNudgePaymentToken(address newToken) external onlyOwner {

156:     function setPauser(address newPauser) external onlyOwner {

164:     function pause() external override onlyPauser {

169:     function unpause() external override onlyPauser {

181:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

256:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

265:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

272:     function setNudgeSize(uint256 newSize) external onlyOwner {

297:     function setNudgeStreamer(address newStreamer) external onlyOwner {

328:     function setNudgeTokenWhitelist(address token, bool allowed) external onlyOwner {

353:     function setPauser(address newPauser) external onlyOwner {

361:     function pause() external override onlyPauser {

366:     function unpause() external override onlyPauser {

386:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

207:     function initiateMigration() external onlyOwner {

219:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

253:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

390:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

408:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

313:     function setPauser(address newPauser) external onlyOwner {

322:     function setMigrator(address newMigrator) external onlyOwner {

327:     function pause() external onlyPauser {

331:     function unpause() external onlyPauser {

339:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

344:     function setStakedId(uint256 newId) external onlyOwner {

352:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

361:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

375:     function setDepletionWindow(uint256 months) external onlyOwner {

388:     function topUp(uint256 amount) external onlyOwner {

397:     function pullAndRefresh() external onlyOwner {

413:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

664:     function initiateMigration() external override nonReentrant onlyMigrator {

770:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

800:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NFTStakerDepletionV2.sol

314:     function setPauser(address newPauser) external onlyOwner {

323:     function setMigrator(address newMigrator) external onlyOwner {

328:     function pause() external onlyPauser {

332:     function unpause() external onlyPauser {

340:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

345:     function setStakedId(uint256 newId) external onlyOwner {

353:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

362:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

376:     function setDepletionWindow(uint256 months) external onlyOwner {

389:     function topUp(uint256 amount) external onlyOwner {

398:     function pullAndRefresh() external onlyOwner {

414:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

670:     function initiateMigration() external override nonReentrant onlyMigrator {

774:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

804:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NFTStakerMigrator.sol

153:     function initiateMigration() external onlyOwner {

170:     function migrate(address[] calldata users) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

286:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

339:     function setPauser(address newPauser) external onlyOwner {

348:     function setMigrator(address newMigrator) external onlyOwner {

353:     function pause() external onlyPauser {

357:     function unpause() external onlyPauser {

365:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

370:     function setStakedId(uint256 newId) external onlyOwner {

380:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

390:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

403:     function setTargetAPY(uint256 newAPY) external onlyOwner {

417:     function topUp(uint256 amount) external onlyOwner {

426:     function pullAndRefresh() external onlyOwner {

442:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

788:     function initiateMigration() external override nonReentrant onlyMigrator {

893:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

939:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NudgeStreamer.sol

125:     function registerStream(address batchMinter, address token, uint256 duration) external override onlyOwner {

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

*Instances (12)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

224:         for (uint256 i = 0; i < users.length; i++) {

232:                 count++;

264:         for (uint256 i = 0; i < sliceLen; i++) {

277:         for (uint256 i = 0; i < sliceLen; i++) {

289:             count++;

435:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerDepletionV2.sol

703:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

174:         for (uint256 i = 0; i < amounts.length; i++) {

189:         for (uint256 i = 0; i < users.length; i++) {

192:                 migratedCount++;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

822:         for (uint256 i = 0; i < accounts.length; i++) {

```

### <a name="GAS-11"></a>[GAS-11] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (23)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

134:     uint256 public constant MIN_TIMEOUT = 1 days;

138:     uint256 public constant MAX_TIMEOUT = 30 days;

```

```solidity
File: src/NFTStaker.sol

39:     uint256 public constant ACC_PRECISION = 1e18;

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

50:     uint256 public constant APY_PRECISION = 1e18;

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NFTStakerDepletion.sol

83:     uint256 public constant ACC_PRECISION = 1e18;

88:     uint256 public constant SECONDS_PER_YEAR = 365 days;

94:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

99:     uint256 public constant MAX_DEPLETION_MONTHS = 120;

```

```solidity
File: src/NFTStakerDepletionV2.sol

84:     uint256 public constant ACC_PRECISION = 1e18;

89:     uint256 public constant SECONDS_PER_YEAR = 365 days;

95:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

100:     uint256 public constant MAX_DEPLETION_MONTHS = 120;

```

```solidity
File: src/NFTStakerPriceScaled.sol

62:     uint256 public constant ACC_PRECISION = 1e18;

69:     uint256 public constant SECONDS_PER_YEAR = 365 days;

73:     uint256 public constant APY_PRECISION = 1e18;

79:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

101:     uint256 public constant ACC_PRECISION = 1e18;

108:     uint256 public constant SECONDS_PER_YEAR = 365 days;

112:     uint256 public constant APY_PRECISION = 1e18;

118:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NudgeStreamer.sol

68:     uint256 public constant PRECISION = 1e18;

```

### <a name="GAS-12"></a>[GAS-12] Splitting require() statements that use && saves gas

*Instances (3)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

165:         require(_migrationTimeout >= MIN_TIMEOUT && _migrationTimeout <= MAX_TIMEOUT, "InPlace: timeout out of bounds");

```

```solidity
File: src/NFTStakerDepletion.sol

376:         require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");

```

```solidity
File: src/NFTStakerDepletionV2.sol

377:         require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");

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

*Instances (14)*:
```solidity
File: src/BatchNFTMinter.sol

286:         for (uint256 i; i < count; ++i) {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

532:                 for (uint256 i; i < nudgeCount; ++i) {

645:         for (uint256 i; i < count; ++i) {

799:         for (uint256 i; i < tokenCount; ++i) {

829:         for (uint256 i; i < tokenCount; ++i) {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

224:         for (uint256 i = 0; i < users.length; i++) {

264:         for (uint256 i = 0; i < sliceLen; i++) {

277:         for (uint256 i = 0; i < sliceLen; i++) {

435:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerDepletionV2.sol

703:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

174:         for (uint256 i = 0; i < amounts.length; i++) {

189:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

822:         for (uint256 i = 0; i < accounts.length; i++) {

```

### <a name="GAS-14"></a>[GAS-14] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (116)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

226:             if (amt > 0) {

271:         if (totalParked > 0) {

320:         if (captured > 0) {

347:         require(amount > 0, "InPlace: nothing unforwarded");

366:         require(amount > 0, "InPlace: nothing parked");

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

389:         require(amount > 0, "NFTStaker: zero topUp");

442:         if (inflow > 0) {                              // new NFT minted → budget grew → restart window (intended)

477:         if (reward > 0) {

551:         require(amount > 0, "NFTStaker: zero stake");

557:         if (user.amount > 0) {

559:             if (pending > 0) {

561:                 if (pending > 0) emit Claimed(msg.sender, pending);

572:         require(amount > 0, "NFTStaker: zero unstake");

577:         if (pending > 0) {

579:             if (pending > 0) emit Claimed(msg.sender, pending);

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

771:         require(amount > 0, "NFTStaker: zero deposit");

775:         if (info.amount > 0) {

777:             if (pending > 0) {

779:                 if (pending > 0) emit Claimed(user, pending);

827:         if (poolState == PoolState.Active && block.timestamp > lastRewardTime && totalStaked > 0) {

```

```solidity
File: src/NFTStakerDepletionV2.sol

390:         require(amount > 0, "NFTStaker: zero topUp");

443:         if (inflow > 0) {                              // new NFT minted → budget grew → restart window (intended)

478:         if (reward > 0) {

552:         require(amount > 0, "NFTStaker: zero stake");

563:         if (user.amount > 0) {

565:             if (pending > 0) {

567:                 if (pending > 0) emit Claimed(msg.sender, pending);

578:         require(amount > 0, "NFTStaker: zero unstake");

583:         if (pending > 0) {

585:             if (pending > 0) emit Claimed(msg.sender, pending);

598:         if (pending > 0) {

600:             if (paid > 0) emit Claimed(msg.sender, paid);

622:         if (amount > 0) {

642:         require(amount > 0, "NFTStaker: nothing to withdraw");

647:         if (pending > 0) {

707:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

709:         if (totalAmount > 0) {

724:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

749:         if (pending > 0) {

751:             if (paid > 0) emit Claimed(account, paid);

775:         require(amount > 0, "NFTStaker: zero deposit");

779:         if (info.amount > 0) {

781:             if (pending > 0) {

783:                 if (pending > 0) emit Claimed(user, pending);

831:         if (poolState == PoolState.Active && block.timestamp > lastRewardTime && totalStaked > 0) {

```

```solidity
File: src/NFTStakerMigrator.sol

190:             if (amounts[i] > 0) {

223:         if (captured > 0) {

249:         require(amount > 0, "Migrator: nothing unforwarded");

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

418:         require(amount > 0, "NFTStaker: zero topUp");

479:         if (inflow > 0) {

520:         if (reward > 0) {

627:         require(amount > 0, "NFTStaker: zero stake");

638:         if (user.amount > 0) {

640:             if (pending > 0) {

642:                 if (pending > 0) emit Claimed(msg.sender, pending);

660:         require(amount > 0, "NFTStaker: zero unstake");

665:         if (pending > 0) {

667:             if (pending > 0) emit Claimed(msg.sender, pending);

684:         if (pending > 0) {

686:             if (paid > 0) emit Claimed(msg.sender, paid);

722:         if (amount > 0) {

752:         require(amount > 0, "NFTStaker: nothing to withdraw");

757:         if (pending > 0) {

826:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

828:         if (totalAmount > 0) {

843:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

868:         if (pending > 0) {

870:             if (paid > 0) emit Claimed(account, paid);

894:         require(amount > 0, "NFTStaker: zero deposit");

898:         if (info.amount > 0) {

900:             if (pending > 0) {

902:                 if (pending > 0) emit Claimed(user, pending);

967:         if (poolState == PoolState.Active && block.timestamp > lastRewardTime && totalStaked > 0) {

```

```solidity
File: src/NudgeStreamer.sol

241:         if (settled > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 12 |
| [NC-2](#NC-2) | Constants should be in CONSTANT_CASE | 3 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 88 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 9 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 49 |
| [NC-6](#NC-6) | Events should use parameters to convey information | 3 |
| [NC-7](#NC-7) | Event missing indexed field | 33 |
| [NC-8](#NC-8) | Events that mark critical parameter changes should contain both the old and the new value | 44 |
| [NC-9](#NC-9) | Function ordering does not follow the Solidity style guide | 7 |
| [NC-10](#NC-10) | Functions should not be longer than 50 lines | 153 |
| [NC-11](#NC-11) | Change uint to uint256 | 2 |
| [NC-12](#NC-12) | Interfaces should be defined in separate files from their usage | 1 |
| [NC-13](#NC-13) | Lack of checks in setters | 23 |
| [NC-14](#NC-14) | NatSpec is completely non-existent on functions that should have them | 40 |
| [NC-15](#NC-15) | Incomplete NatSpec: `@param` is missing on actually documented functions | 36 |
| [NC-16](#NC-16) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 29 |
| [NC-17](#NC-17) | Constant state variables defined more than once | 22 |
| [NC-18](#NC-18) | Consider using named mappings | 12 |
| [NC-19](#NC-19) | Owner can renounce while system is paused | 7 |
| [NC-20](#NC-20) | Adding a `return` statement when the function defines a named return variable, is redundant | 6 |
| [NC-21](#NC-21) | Take advantage of Custom Error's return value property | 21 |
| [NC-22](#NC-22) | Avoid the use of sensitive terms | 11 |
| [NC-23](#NC-23) | Contract does not follow the Solidity style guide's suggested layout ordering | 8 |
| [NC-24](#NC-24) | Event is missing `indexed` fields | 84 |
| [NC-25](#NC-25) | Variables need not be initialized to zero | 9 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (12)*:
```solidity
File: src/BatchNFTMinter.sol

150:         nudgePaymentToken = newToken;

158:         pauser = newPauser;

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

300:     }

358:     /// @notice Pause `batchMint`. Callable only by the registered `pauser`

```

```solidity
File: src/NFTStaker.sol

211:         pauser = newPauser;

```

```solidity
File: src/NFTStakerDepletion.sol

315:         pauser = newPauser;

324:         migrator = newMigrator;

```

```solidity
File: src/NFTStakerDepletionV2.sol

317:     }

326:     }

```

```solidity
File: src/NFTStakerPriceScaled.sol

245:         pauser = newPauser;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

341:         pauser = newPauser;

350:         migrator = newMigrator;

```

### <a name="NC-2"></a>[NC-2] Constants should be in CONSTANT_CASE
For `constant` variable names, each word should use all capital letters, with underscores separating each word (CONSTANT_CASE)

*Instances (3)*:
```solidity
File: src/NFTStaker.sol

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NFTStakerPriceScaled.sol

79:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

118:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (88)*:
```solidity
File: src/BatchNFTMinter.sol

182:         if (to == address(0)) revert Rescue__ZeroRecipient();

244:         if (count == 0) revert BatchMint__ZeroCount();

245:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

253:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

256:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

330:             if (token == address(0)) revert BatchMint__ZeroNudgeToken();

338:             if (oneBasedIndex == 0) revert BatchMint__NudgeTokenNotWhitelisted(token);

387:         if (to == address(0)) revert Rescue__ZeroRecipient();

471:         if (count == 0) revert BatchMint__ZeroCount();

472:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

510:         bool qualifies;

513:             qualifies = _nudgeSize != 0 && count >= _nudgeSize;

538:         uint256[] memory snapshot = _snapshotRewards(minRewards, qualifies);

647:             if (price > budget) revert BatchMint__PaymentBudgetExhausted(i, price, budget);

744:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

747:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

792:     function _snapshotRewards(uint256[] calldata minRewards, bool qualifies)

801:             uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;

831:             if (amount == 0) continue;

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

191:         if (idx == 0) return;

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

414:         if (to == address(0)) revert Rescue__ZeroRecipient();

468:         if (block.timestamp <= lastRewardTime) return;

476:         if (reward > rewardBudget) reward = rewardBudget;

561:                 if (pending > 0) emit Claimed(msg.sender, pending);

579:             if (pending > 0) emit Claimed(msg.sender, pending);

594:             if (paid > 0) emit Claimed(msg.sender, paid);

701:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

745:             if (paid > 0) emit Claimed(account, paid);

779:                 if (pending > 0) emit Claimed(user, pending);

831:             if (reward > rewardBudget) reward = rewardBudget;

840:         if (block.timestamp >= windowEnd) return 0;

855:         if (reward > rewardBudget) reward = rewardBudget;

872:         if (rewardRate == 0) return 0;

```

```solidity
File: src/NFTStakerDepletionV2.sol

415:         if (to == address(0)) revert Rescue__ZeroRecipient();

469:         if (block.timestamp <= lastRewardTime) return;

477:         if (reward > rewardBudget) reward = rewardBudget;

567:                 if (pending > 0) emit Claimed(msg.sender, pending);

585:             if (pending > 0) emit Claimed(msg.sender, pending);

600:             if (paid > 0) emit Claimed(msg.sender, paid);

707:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

751:             if (paid > 0) emit Claimed(account, paid);

783:                 if (pending > 0) emit Claimed(user, pending);

835:             if (reward > rewardBudget) reward = rewardBudget;

844:         if (block.timestamp >= windowEnd) return 0;

859:         if (reward > rewardBudget) reward = rewardBudget;

876:         if (rewardRate == 0) return 0;

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

443:         if (to == address(0)) revert Rescue__ZeroRecipient();

472:             _recomputeScheduleIfActive();

478:         _recomputeScheduleIfActive();

492:         if (poolState == PoolState.Migrating) return;

511:         if (block.timestamp <= lastRewardTime) return;

519:         if (reward > rewardBudget) reward = rewardBudget;

642:                 if (pending > 0) emit Claimed(msg.sender, pending);

656:         _recomputeScheduleIfActive();

667:             if (pending > 0) emit Claimed(msg.sender, pending);

677:         _recomputeScheduleIfActive();

686:             if (paid > 0) emit Claimed(msg.sender, paid);

826:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

870:             if (paid > 0) emit Claimed(account, paid);

902:                 if (pending > 0) emit Claimed(user, pending);

971:             if (reward > rewardBudget) reward = rewardBudget;

980:         if (block.timestamp >= windowEnd) return 0;

999:         if (reward > rewardBudget) reward = rewardBudget;

1015:         if (rewardRate == 0) return 0;

```

```solidity
File: src/NudgeStreamer.sol

126:         if (duration == 0) revert NudgeStreamer__ZeroDuration();

158:         if (s.duration == 0) revert NudgeStreamer__NotRegistered();

163:         if (amount == 0) revert NudgeStreamer__ZeroAmount();

196:         if (received > amount) received = amount;

199:         if (received == 0) revert NudgeStreamer__ZeroReceived();

222:         if (s.duration == 0) return; // not registered -> no-op

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (9)*:
```solidity
File: src/BatchNFTMinter.sol

62: contract BatchNFTMinter is Ownable, Pausable, IPausable {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

159: contract BatchNFTMinterMultiToken is Ownable, Pausable, ReentrancyGuard, IPausable {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

77: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: src/NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: src/NFTStakerDepletion.sol

75: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: src/NFTStakerDepletionV2.sol

76: contract NFTStakerDepletionV2 is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: src/NFTStakerMigrator.sol

77: contract NFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: src/NFTStakerPriceScaled.sol

54: contract NFTStakerPriceScaled is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: src/NudgeStreamer.sol

63: contract NudgeStreamer is INudgeStreamer, Ownable, ReentrancyGuard {

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (49)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

391:         require(to != address(0), "InPlace: zero recipient");

409:         require(to != address(0), "InPlace: zero recipient");

```

```solidity
File: src/NFTStaker.sol

197:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

232:         require(totalStaked == 0, "NFTStaker: stake outstanding");

242:         require(totalStaked == 0, "NFTStaker: stake outstanding");

252:         require(totalStaked == 0, "NFTStaker: stake outstanding");

253:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

```

```solidity
File: src/NFTStakerDepletion.sol

301:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

345:         require(totalStaked == 0, "NFTStaker: stake outstanding");

353:         require(totalStaked == 0, "NFTStaker: stake outstanding");

362:         require(totalStaked == 0, "NFTStaker: stake outstanding");

363:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

665:         require(poolState == PoolState.Active, "NFTStaker: not active");

693:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

717:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

772:         require(poolState == PoolState.Active, "NFTStaker: not active");

801:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

802:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

```solidity
File: src/NFTStakerDepletionV2.sol

302:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

346:         require(totalStaked == 0, "NFTStaker: stake outstanding");

354:         require(totalStaked == 0, "NFTStaker: stake outstanding");

363:         require(totalStaked == 0, "NFTStaker: stake outstanding");

364:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

557:         require(poolState == PoolState.Active, "NFTStaker: not active");

671:         require(poolState == PoolState.Active, "NFTStaker: not active");

699:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

723:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

776:         require(poolState == PoolState.Active, "NFTStaker: not active");

805:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

806:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

```solidity
File: src/NFTStakerMigrator.sol

269:         require(to != address(0), "Migrator: zero recipient");

287:         require(to != address(0), "Migrator: zero recipient");

```

```solidity
File: src/NFTStakerPriceScaled.sol

229:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

266:         require(totalStaked == 0, "NFTStaker: stake outstanding");

276:         require(totalStaked == 0, "NFTStaker: stake outstanding");

286:         require(totalStaked == 0, "NFTStaker: stake outstanding");

287:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

325:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

371:         require(totalStaked == 0, "NFTStaker: stake outstanding");

381:         require(totalStaked == 0, "NFTStaker: stake outstanding");

391:         require(totalStaked == 0, "NFTStaker: stake outstanding");

392:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

632:         require(poolState == PoolState.Active, "NFTStaker: not active");

789:         require(poolState == PoolState.Active, "NFTStaker: not active");

818:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

842:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

895:         require(poolState == PoolState.Active, "NFTStaker: not active");

940:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

941:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

### <a name="NC-6"></a>[NC-6] Events should use parameters to convey information
For example, rather than using `event Paused()` and `event Unpaused()`, use `event PauseState(address indexed whoChangedIt, bool wasPaused, bool isNowPaused)`

*Instances (3)*:
```solidity
File: src/NFTStakerDepletion.sol

275:     event PoolReset();

```

```solidity
File: src/NFTStakerDepletionV2.sol

278:     // ---------------------------------------------------------------------

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

298:     event PoolReset();

```

### <a name="NC-7"></a>[NC-7] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (33)*:
```solidity
File: src/BatchNFTMinter.sol

110:     event NudgeSizeChanged(uint256 newSize);

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

239:     event NudgeSizeChanged(uint256 newSize);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

140:     event MigratedOut(uint256 userCount, uint256 totalAmount);

141:     event MigratedIn(uint256 userCount, uint256 totalAmount);

```

```solidity
File: src/NFTStaker.sol

154:     event Pulled(uint256 inflow, uint256 newBudget);

159:     event StakedIdChanged(uint256 previous, uint256 next);

161:     event TargetAPYChanged(uint256 previous, uint256 next);

162:     event DispatcherIndexChanged(uint256 previous, uint256 next);

176:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

```

```solidity
File: src/NFTStakerDepletion.sol

238:     event Pulled(uint256 inflow, uint256 newBudget);

242:     event StakedIdChanged(uint256 previous, uint256 next);

246:     event DepletionWindowChanged(uint256 previous, uint256 next);

247:     event DispatcherIndexChanged(uint256 previous, uint256 next);

256:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

264:     event MigrationInitiated(uint256 totalStaked);

```

```solidity
File: src/NFTStakerDepletionV2.sol

239:     event Pulled(uint256 inflow, uint256 newBudget);

243:     event StakedIdChanged(uint256 previous, uint256 next);

247:     event DepletionWindowChanged(uint256 previous, uint256 next);

248:     event DispatcherIndexChanged(uint256 previous, uint256 next);

257:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

265:     event MigrationInitiated(uint256 totalStaked);

```

```solidity
File: src/NFTStakerMigrator.sol

107:     event Migrated(uint256 userCount, uint256 totalAmount);

```

```solidity
File: src/NFTStakerPriceScaled.sol

185:     event Pulled(uint256 inflow, uint256 newBudget);

190:     event StakedIdChanged(uint256 previous, uint256 next);

192:     event TargetAPYChanged(uint256 previous, uint256 next);

193:     event DispatcherIndexChanged(uint256 previous, uint256 next);

207:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

257:     event Pulled(uint256 inflow, uint256 newBudget);

262:     event StakedIdChanged(uint256 previous, uint256 next);

264:     event TargetAPYChanged(uint256 previous, uint256 next);

265:     event DispatcherIndexChanged(uint256 previous, uint256 next);

279:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

287:     event MigrationInitiated(uint256 totalStaked);

```

### <a name="NC-8"></a>[NC-8] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (44)*:
```solidity
File: src/BatchNFTMinter.sol

126:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

135:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

142:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

149:     function setNudgePaymentToken(address newToken) external onlyOwner {
             nudgePaymentToken = newToken;
             emit NudgePaymentTokenChanged(newToken);

156:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

256:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

265:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

272:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

297:     function setNudgeStreamer(address newStreamer) external onlyOwner {
             emit NudgeStreamerChanged(nudgeStreamer, newStreamer);

328:     function setNudgeTokenWhitelist(address token, bool allowed) external onlyOwner {
             if (allowed) {
                 if (token == address(0)) revert BatchMint__ZeroNudgeToken();
                 if (_nudgeTokenIndex[token] != 0) {
                     revert BatchMint__NudgeTokenAlreadyWhitelisted(token);
                 }
                 _nudgeTokens.push(token);
                 _nudgeTokenIndex[token] = _nudgeTokens.length;
             } else {
                 uint256 oneBasedIndex = _nudgeTokenIndex[token];
                 if (oneBasedIndex == 0) revert BatchMint__NudgeTokenNotWhitelisted(token);
                 uint256 length = _nudgeTokens.length;
                 if (oneBasedIndex != length) {
                     address lastToken = _nudgeTokens[length - 1];
                     _nudgeTokens[oneBasedIndex - 1] = lastToken;
                     _nudgeTokenIndex[lastToken] = oneBasedIndex;
                 }
                 _nudgeTokens.pop();
                 delete _nudgeTokenIndex[token];
             }
             emit NudgeTokenWhitelistChanged(token, allowed);

353:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

313:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

322:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);

339:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));

344:     function setStakedId(uint256 newId) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit StakedIdChanged(stakedId, newId);

352:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit DispatcherIndexChanged(dispatcherIndex, newIndex);

361:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             require(address(newMinter) != address(0), "NFTStaker: zero nft minter");
             emit NFTMinterChanged(address(nftMinter), address(newMinter));

375:     function setDepletionWindow(uint256 months) external onlyOwner {
             require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");
             _updatePool();
             emit DepletionWindowChanged(depletionWindowMonths, months);

```

```solidity
File: src/NFTStakerDepletionV2.sol

314:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

323:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);

340:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));

345:     function setStakedId(uint256 newId) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit StakedIdChanged(stakedId, newId);

353:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit DispatcherIndexChanged(dispatcherIndex, newIndex);

362:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             require(address(newMinter) != address(0), "NFTStaker: zero nft minter");
             emit NFTMinterChanged(address(nftMinter), address(newMinter));

376:     function setDepletionWindow(uint256 months) external onlyOwner {
             require(months >= 1 && months <= MAX_DEPLETION_MONTHS, "NFTStaker: window out of range");
             _updatePool();
             emit DepletionWindowChanged(depletionWindowMonths, months);

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

339:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

348:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);

365:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));

370:     function setStakedId(uint256 newId) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit StakedIdChanged(stakedId, newId);

380:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit DispatcherIndexChanged(dispatcherIndex, newIndex);

390:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             require(address(newMinter) != address(0), "NFTStaker: zero nft minter");
             emit NFTMinterChanged(address(nftMinter), address(newMinter));

403:     function setTargetAPY(uint256 newAPY) external onlyOwner {
             require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");
             _updatePool();
             emit TargetAPYChanged(targetAPY, newAPY);

```

### <a name="NC-9"></a>[NC-9] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (7)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

1: 
   Current order:
   private _addParked
   private _removeParked
   external initiateMigration
   external migrateOut
   external migrateIn
   private _depositForAndForward
   external claimForwarded
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
   external claimForwarded
   external claimTimedOut
   external rescueERC20
   external rescueERC1155
   external parkedUserCount
   external parkedUsersRange
   external claimableAt
   private _addParked
   private _removeParked
   private _depositForAndForward

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

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
File: src/NFTStakerDepletionV2.sol

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
File: src/NFTStakerMigrator.sol

1: 
   Current order:
   external initiateMigration
   external migrate
   private _depositForAndForward
   external claimForwarded
   external rescueERC20
   external rescueERC1155
   
   Suggested order:
   external initiateMigration
   external migrate
   external claimForwarded
   external rescueERC20
   external rescueERC1155
   private _depositForAndForward

```

```solidity
File: src/NFTStakerPriceScaled.sol

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
File: src/NFTStakerPriceScaledMigrateReady.sol

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
   external setTargetAPY
   external topUp
   external pullAndRefresh
   external rescueERC20
   internal _syncBudget
   internal _recomputeScheduleIfActive
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
   external setTargetAPY
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
   internal _recomputeScheduleIfActive
   internal _updatePool
   internal _recomputeSchedule
   internal _safePay
   internal _safePayTo
   internal _exitPosition

```

### <a name="NC-10"></a>[NC-10] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (153)*:
```solidity
File: src/BatchNFTMinter.sol

126:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

135:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

142:     function setNudgeSize(uint256 newSize) external onlyOwner {

149:     function setNudgePaymentToken(address newToken) external onlyOwner {

156:     function setPauser(address newPauser) external onlyOwner {

181:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

256:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

265:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

272:     function setNudgeSize(uint256 newSize) external onlyOwner {

281:     function getNudgeTokens() external view returns (address[] memory) {

289:     function isNudgeToken(address token) external view returns (bool) {

297:     function setNudgeStreamer(address newStreamer) external onlyOwner {

328:     function setNudgeTokenWhitelist(address token, bool allowed) external onlyOwner {

353:     function setPauser(address newPauser) external onlyOwner {

386:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

464:     function batchMint(uint256 count, address recipient, uint256 paymentAmount, uint256[] calldata minRewards)

792:     function _snapshotRewards(uint256[] calldata minRewards, bool qualifies)

827:     function _payRewards(address recipient, uint256[] memory snapshot) private {

```

```solidity
File: src/INFTStakerMigratable.sol

38:     function batchMigrate(address[] calldata users) external returns (uint256[] memory amounts);

64:     function depositFor(address user, uint256 amount) external;

71:     function userInfo(address user) external view returns (uint256 amount, uint256 rewardDebt);

```

```solidity
File: src/INFTSupply.sol

25:     function totalSupply(uint256 id) external view returns (uint256);

```

```solidity
File: src/INudgeStreamer.sol

31:     function pullPendingStream(address token) external;

```

```solidity
File: src/IStakerViews.sol

26:     function rewardToken() external view returns (IERC20);

30:     function pendingReward(address account) external view returns (uint256);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

219:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

253:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

311:     function _depositForAndForward(address user, uint256 amount) private {

390:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

408:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

421:     function parkedUserCount() external view returns (uint256) {

426:     function parkedUsersRange(uint256 start, uint256 end) external view returns (address[] memory out) {

442:     function claimableAt(address user) external view returns (uint256) {

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

313:     function setPauser(address newPauser) external onlyOwner {

322:     function setMigrator(address newMigrator) external onlyOwner {

339:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

344:     function setStakedId(uint256 newId) external onlyOwner {

352:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

361:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

375:     function setDepletionWindow(uint256 months) external onlyOwner {

388:     function topUp(uint256 amount) external onlyOwner {

413:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

550:     function stake(uint256 amount) external nonReentrant whenNotPaused {

571:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

588:     function claim() external nonReentrant whenNotPaused {

604:     function _safePay(uint256 amount) internal returns (uint256) {

614:     function _safePayTo(address account, uint256 amount) internal returns (uint256) {

633:     function emergencyWithdraw() external nonReentrant {

664:     function initiateMigration() external override nonReentrant onlyMigrator {

686:     function batchMigrate(address[] calldata accounts)

731:     function _exitPosition(address account) internal returns (uint256 amount, uint256 paid) {

770:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

816:     function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {

821:     function pendingReward(address account) external view returns (uint256) {

839:     function currentRewardRate() external view returns (uint256) {

847:     function totalDebt() external view returns (uint256) {

861:     function totalBudget() external view returns (uint256) {

871:     function runwaySeconds() external view returns (uint256) {

```

```solidity
File: src/NFTStakerDepletionV2.sol

314:     function setPauser(address newPauser) external onlyOwner {

323:     function setMigrator(address newMigrator) external onlyOwner {

340:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

345:     function setStakedId(uint256 newId) external onlyOwner {

353:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

362:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

376:     function setDepletionWindow(uint256 months) external onlyOwner {

389:     function topUp(uint256 amount) external onlyOwner {

414:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

551:     function stake(uint256 amount) external nonReentrant whenNotPaused {

577:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

594:     function claim() external nonReentrant whenNotPaused {

610:     function _safePay(uint256 amount) internal returns (uint256) {

620:     function _safePayTo(address account, uint256 amount) internal returns (uint256) {

639:     function emergencyWithdraw() external nonReentrant {

670:     function initiateMigration() external override nonReentrant onlyMigrator {

692:     function batchMigrate(address[] calldata accounts)

737:     function _exitPosition(address account) internal returns (uint256 amount, uint256 paid) {

774:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

820:     function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {

825:     function pendingReward(address account) external view returns (uint256) {

843:     function currentRewardRate() external view returns (uint256) {

851:     function totalDebt() external view returns (uint256) {

865:     function totalBudget() external view returns (uint256) {

875:     function runwaySeconds() external view returns (uint256) {

```

```solidity
File: src/NFTStakerMigrator.sol

170:     function migrate(address[] calldata users) external onlyOwner nonReentrant {

214:     function _depositForAndForward(address user, uint256 amount) private {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

286:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

339:     function setPauser(address newPauser) external onlyOwner {

348:     function setMigrator(address newMigrator) external onlyOwner {

365:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

370:     function setStakedId(uint256 newId) external onlyOwner {

380:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

390:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

403:     function setTargetAPY(uint256 newAPY) external onlyOwner {

417:     function topUp(uint256 amount) external onlyOwner {

442:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

626:     function stake(uint256 amount) external nonReentrant whenNotPaused {

659:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

680:     function claim() external nonReentrant whenNotPaused {

694:     function _safePay(uint256 amount) internal returns (uint256) {

720:     function _safePayTo(address account, uint256 amount) internal returns (uint256) {

749:     function emergencyWithdraw() external nonReentrant {

788:     function initiateMigration() external override nonReentrant onlyMigrator {

811:     function batchMigrate(address[] calldata accounts)

856:     function _exitPosition(address account) internal returns (uint256 amount, uint256 paid) {

893:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

956:     function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {

961:     function pendingReward(address account) external view returns (uint256) {

979:     function currentRewardRate() external view returns (uint256) {

991:     function totalDebt() external view returns (uint256) {

1005:     function totalBudget() external view returns (uint256) {

1014:     function runwaySeconds() external view returns (uint256) {

```

```solidity
File: src/NudgeStreamer.sol

16:     function isNudgeToken(address token) external view returns (bool);

125:     function registerStream(address batchMinter, address token, uint256 duration) external override onlyOwner {

152:     function collectNudge(address recipientBatchMinter, address token, uint256 amount)

220:     function pullPendingStream(address token) external override nonReentrant {

230:     function pendingStream(address batchMinter, address token) external view override returns (uint256) {

238:     function _settle(Stream storage s, address recipient, address token) private {

266:     function _accrued(Stream storage s) private view returns (uint256) {

```

### <a name="NC-11"></a>[NC-11] Change uint to uint256
Throughout the code base, some variables are declared as `uint`. To favor explicitness, consider changing all instances of `uint` to `uint256`

*Instances (2)*:
```solidity
File: src/INudgeStreamer.sol

27:         uint amount

41:         uint duration

```

### <a name="NC-12"></a>[NC-12] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (1)*:
```solidity
File: src/NudgeStreamer.sol

15: interface IMultiTokenNudgeWhitelist {

```

### <a name="NC-13"></a>[NC-13] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (23)*:
```solidity
File: src/BatchNFTMinter.sol

126:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

135:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

142:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

149:     function setNudgePaymentToken(address newToken) external onlyOwner {
             nudgePaymentToken = newToken;
             emit NudgePaymentTokenChanged(newToken);

156:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

256:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

265:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

272:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

297:     function setNudgeStreamer(address newStreamer) external onlyOwner {
             emit NudgeStreamerChanged(nudgeStreamer, newStreamer);
             nudgeStreamer = newStreamer;
         }

353:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;
         }
     
         /// @notice Pause `batchMint`. Callable only by the registered `pauser`

```

```solidity
File: src/NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

226:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

```solidity
File: src/NFTStakerDepletion.sol

313:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

322:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);
             migrator = newMigrator;

339:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

```solidity
File: src/NFTStakerDepletionV2.sol

314:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;
         }

323:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);
             migrator = newMigrator;
         }

340:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

```solidity
File: src/NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

339:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

348:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);
             migrator = newMigrator;

365:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

### <a name="NC-14"></a>[NC-14] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (40)*:
```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

313:     function setPauser(address newPauser) external onlyOwner {

327:     function pause() external onlyPauser {

331:     function unpause() external onlyPauser {

339:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

344:     function setStakedId(uint256 newId) external onlyOwner {

550:     function stake(uint256 amount) external nonReentrant whenNotPaused {

571:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

588:     function claim() external nonReentrant whenNotPaused {

```

```solidity
File: src/NFTStakerDepletionV2.sol

314:     function setPauser(address newPauser) external onlyOwner {

328:     function pause() external onlyPauser {

332:     function unpause() external onlyPauser {

340:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

345:     function setStakedId(uint256 newId) external onlyOwner {

551:     function stake(uint256 amount) external nonReentrant whenNotPaused {

577:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

594:     function claim() external nonReentrant whenNotPaused {

```

```solidity
File: src/NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

248:     function pause() external onlyPauser {

252:     function unpause() external onlyPauser {

260:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

265:     function setStakedId(uint256 newId) external onlyOwner {

470:     function stake(uint256 amount) external nonReentrant whenNotPaused {

497:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

518:     function claim() external nonReentrant whenNotPaused {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

339:     function setPauser(address newPauser) external onlyOwner {

353:     function pause() external onlyPauser {

357:     function unpause() external onlyPauser {

365:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

370:     function setStakedId(uint256 newId) external onlyOwner {

626:     function stake(uint256 amount) external nonReentrant whenNotPaused {

659:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

680:     function claim() external nonReentrant whenNotPaused {

```

### <a name="NC-15"></a>[NC-15] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (36)*:
```solidity
File: src/BatchNFTMinter.sol

123:     /// @notice Owner-gated update of the trusted NFT minter. Setting
         ///         `address(0)` disables `batchMint` (it reverts
         ///         `BatchMint__MinterNotConfigured`).
         function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

131:     /// @notice Owner-gated update of the only dispatcher index `batchMint`
         ///         mints. Setting `0` disables `batchMint` (it reverts
         ///         `BatchMint__DispatcherNotConfigured`). Stays callable while
         ///         paused.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

140:     /// @notice Owner-gated update of the batch-size threshold for the nudge
         ///         payout. Setting `0` disables the feature.
         function setNudgeSize(uint256 newSize) external onlyOwner {

147:     /// @notice Owner-gated update of the nudge payout token. Setting
         ///         `address(0)` disables the feature.
         function setNudgePaymentToken(address newToken) external onlyOwner {

154:     /// @notice Owner-gated update of the pauser address. Setting `address(0)`
         ///         disables pausing. Stays callable while paused.
         function setPauser(address newPauser) external onlyOwner {

173:     /// @notice Owner-only recovery of an arbitrary ERC20. The deployed
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
File: src/BatchNFTMinterMultiToken.sol

253:     /// @notice Owner-gated update of the trusted NFT minter. Setting
         ///         `address(0)` disables `batchMint` (it reverts
         ///         `BatchMint__MinterNotConfigured`).
         function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

261:     /// @notice Owner-gated update of the only dispatcher index `batchMint`
         ///         mints. Setting `0` disables `batchMint` (it reverts
         ///         `BatchMint__DispatcherNotConfigured`). Stays callable while
         ///         paused.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

270:     /// @notice Owner-gated update of the batch-size threshold for the nudge
         ///         payout. Setting `0` disables the feature.
         function setNudgeSize(uint256 newSize) external onlyOwner {

293:     /// @notice Owner-gated update of the optional nudge streamer. Setting
         ///         `address(0)` disables the streamer flush in `batchMint`, leaving
         ///         all other behaviour unchanged. Stays callable while paused
         ///         (matches the other setters).
         function setNudgeStreamer(address newStreamer) external onlyOwner {

302:     /// @notice Owner-gated add/remove of a nudge-reward token. Stays callable
         ///         while paused (matches the other setters).
         ///
         /// @dev    Adding (`allowed == true`) rejects only the zero address and a
         ///         duplicate entry. It performs **no payment-token derivation**:
         ///         story-032 removed the admin-time rejection of the dispatcher's
         ///         prime token, which story-029 had already reduced to defence in
         ///         depth. `batchMint` is safe with the payment token on the
         ///         whitelist because the refund is bounded by the caller's tracked
         ///         `budget` (see the contract header), so the collision is now
         ///         creatable in a single call as well as by repointing
         ///         `tokenMinter`/`dispatcherIndex`. Whether to build such a
         ///         whitelist is an operating decision for the owner; the contract
         ///         no longer expresses an opinion about it.
         ///
         ///         Because nothing here reads the payment path, adding works while
         ///         `tokenMinter`/`dispatcherIndex` are unset — symmetric with
         ///         removal, and no longer an ordering constraint on deployment
         ///         scripts. Re-adding an existing entry and removing an absent one
         ///         both revert loudly rather than silently no-op'ing.
         ///
         ///         Removal is swap-and-pop (O(1)): the LAST token moves into the
         ///         removed slot, so the `getNudgeTokens()` ordering changes.
         ///         Removal deliberately performs no payment-token derivation, so
         ///         the owner can always shrink the whitelist even while the
         ///         minter/dispatcher are unconfigured.
         function setNudgeTokenWhitelist(address token, bool allowed) external onlyOwner {

351:     /// @notice Owner-gated update of the pauser address. Setting `address(0)`
         ///         disables pausing. Stays callable while paused.
         function setPauser(address newPauser) external onlyOwner {

370:     /// @notice Owner-only recovery of an arbitrary ERC20.
         /// @dev    Under the whitelist model this is the **dependable escape
         ///         hatch for anything not on the whitelist**: non-whitelisted
         ///         tokens sent here can never be claimed through `batchMint`, so
         ///         rescuing them is no longer a race against watching bots —
         ///         weird/unsupported tokens are explicitly left to this function.
         ///         Only balances of currently whitelisted tokens (and the
         ///         payment token's sweepable residue) compete with callers; for
         ///         those, "pause first (or unwhitelist), then rescue" remains the
         ///         dependable sequence.
         ///
         ///         Owner-trusted (the owner can already zero `nudgeSize`, edit
         ///         the whitelist, and stop all payouts), so no token restriction
         ///         is needed; an explicit `amount` is preferred over a
         ///         full-balance sweep so it composes with the nudge pot. Stays
         ///         callable while paused (mirrors `NFTStaker.emergencyWithdraw`).
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

382:     /// @notice Sweep a STRAY/DONATED ERC20 balance to `to`. Unconditional for
         ///         every token EXCEPT the reward token, where the sweep is floored
         ///         by `totalUnforwarded` — reward escrowed by a failed forward
         ///         belongs to its user and must be unreachable by the owner.
         /// @dev    Owner-only. Parked principal is ERC1155 and therefore
         ///         structurally untouchable by this function; the reward-token
         ///         floor is the ERC20 analogue of the `totalParked` floor
         ///         `rescueERC1155` applies to the staked id.
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

400:     /// @notice Sweep STRAY ERC1155 of an UNPARKED id, or surplus of the staked
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
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

318:     /// @notice Set/rotate the migration orchestrator authorised to call the
         ///         `onlyMigrator` primitives. Setting to `address(0)` disables
         ///         migration. No empty-pool gate — the migrator must be wired
         ///         before `initiateMigration` is called.
         function setMigrator(address newMigrator) external onlyOwner {

350:     /// @notice Update the dispatcher index (identity only). Guarded by
         ///         `totalStaked == 0` for parity with the other stakers.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

359:     /// @notice Swap the `nftMinter` reference (identity only). Guarded by
         ///         `totalStaked == 0`.
         function setNFTMinter(INFTSupply newMinter) external onlyOwner {

401:     /// @notice Owner-only recovery of an arbitrary ERC20. Modelled on
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
File: src/NFTStakerDepletionV2.sol

319:     /// @notice Set/rotate the migration orchestrator authorised to call the
         ///         `onlyMigrator` primitives. Setting to `address(0)` disables
         ///         migration. No empty-pool gate — the migrator must be wired
         ///         before `initiateMigration` is called.
         function setMigrator(address newMigrator) external onlyOwner {

351:     /// @notice Update the dispatcher index (identity only). Guarded by
         ///         `totalStaked == 0` for parity with the other stakers.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

360:     /// @notice Swap the `nftMinter` reference (identity only). Guarded by
         ///         `totalStaked == 0`.
         function setNFTMinter(INFTSupply newMinter) external onlyOwner {

402:     /// @notice Owner-only recovery of an arbitrary ERC20. Modelled on
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
File: src/NFTStakerMigrator.sol

260:     /// @notice Sweep a STRAY/DONATED ERC20 balance to `to`. For the reward
         ///         token the sweep is floored by `totalUnforwarded` (escrowed user
         ///         value the owner must never be able to reach); every other token
         ///         is an unconditional sweep.
         /// @dev    Owner-only. Without any rescue primitive at all, anything
         ///         delivered to this contract is PERMANENTLY stranded — that
         ///         permanence is what made `pns20h1` a High rather than a Medium,
         ///         so the primitive ships with the forwarding fix, not after it.
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

278:     /// @notice Sweep STRAY ERC1155 to `to`. UNCONDITIONAL — no `stakedId`
         ///         floor.
         /// @dev    Owner-only. Unlike `InPlaceNFTStakerMigrator`, this migrator's
         ///         ERC1155 custody is INTRA-CALL ONLY: `batchMigrate` pulls the
         ///         stake in and `depositFor` pushes it out within the same
         ///         `migrate` transaction. There is no `totalParked` analogue and no
         ///         cross-transaction principal to protect, so a floor here would
         ///         guard nothing.
         function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

344:     /// @notice Set/rotate the migration orchestrator authorised to call the
         ///         `onlyMigrator` primitives. Setting to `address(0)` disables
         ///         migration. No empty-pool gate — the migrator must be wired
         ///         before `initiateMigration` is called.
         function setMigrator(address newMigrator) external onlyOwner {

376:     /// @notice Update the dispatcher index read from `nftMinter.configs`.
         ///         Guarded by `totalStaked == 0` — a mid-stake swap to a
         ///         different dispatcher could swing APY violently in either
         ///         direction, so the safest policy is to require an empty pool.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

387:     /// @notice Swap the `nftMinter` reference. Guarded by
         ///         `totalStaked == 0` for the same reason as `setStakedId` and
         ///         `setDispatcherIndex`.
         function setNFTMinter(INFTSupply newMinter) external onlyOwner {

430:     /// @notice Owner-only recovery of an arbitrary ERC20. Modelled on
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
File: src/NudgeStreamer.sol

118:     /// @notice Register (or re-register) the stream for `(batchMinter, token)`.
         /// @dev    `onlyOwner`. Requires `duration > 0` and that `token` is on
         ///         `batchMinter`'s nudge whitelist — the `isNudgeToken` call also
         ///         reverts for non-multitoken targets, which is the structural
         ///         "only MultiToken batchMinter can be registered" guard. Any
         ///         pre-existing accrual is settled at the OLD rate before the window
         ///         is reset, mirroring phlimbo's `setDepletionDuration`.
         function registerStream(address batchMinter, address token, uint256 duration) external override onlyOwner {

145:     /// @notice Donor-facing deposit (`msg.sender` = donor). Settles the accrued
         ///         stream to `recipientBatchMinter` at the OLD rate, pulls `amount`
         ///         from the donor into the buffer, then recomputes the rate.
         /// @dev    `nonReentrant`. Checks-effects-interactions: the settle updates
         ///         `buffer`/`lastUpdate` before its transfer, and the deposit pulls
         ///         funds before recomputing the rate. Mirrors phlimbo's
         ///         `collectReward` (which calls `_updatePool` before adding funds).
         function collectNudge(address recipientBatchMinter, address token, uint256 amount)
             external

214:     /// @notice BatchMinter-facing flush (`msg.sender` = batchMinter = recipient).
         ///         Settles the accrued stream and transfers it to `msg.sender`.
         ///         Unregistered streams are a cheap no-op so `batchMint` can loop
         ///         blindly over `getNudgeTokens()`.
         /// @dev    `nonReentrant`. NO rate recompute (mirrors phlimbo's
         ///         `_updatePool`, which never resets the window).
         function pullPendingStream(address token) external override nonReentrant {

```

### <a name="NC-16"></a>[NC-16] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (29)*:
```solidity
File: src/BatchNFTMinter.sol

119:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

249:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

367:         require(block.timestamp >= migrationBegin[msg.sender] + migrationTimeout, "InPlace: timeout not elapsed");

```

```solidity
File: src/NFTStaker.sol

183:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

442:                 if (pending > 0) emit Claimed(msg.sender, pending);

466:             if (pending > 0) emit Claimed(msg.sender, pending);

485:             if (paid > 0) emit Claimed(msg.sender, paid);

```

```solidity
File: src/NFTStakerDepletion.sol

282:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

287:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

561:                 if (pending > 0) emit Claimed(msg.sender, pending);

579:             if (pending > 0) emit Claimed(msg.sender, pending);

594:             if (paid > 0) emit Claimed(msg.sender, paid);

718:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

```

```solidity
File: src/NFTStakerDepletionV2.sol

283:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

288:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

567:                 if (pending > 0) emit Claimed(msg.sender, pending);

585:             if (pending > 0) emit Claimed(msg.sender, pending);

600:             if (paid > 0) emit Claimed(msg.sender, paid);

724:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

```

```solidity
File: src/NFTStakerPriceScaled.sol

214:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

481:                 if (pending > 0) emit Claimed(msg.sender, pending);

505:             if (pending > 0) emit Claimed(msg.sender, pending);

524:             if (paid > 0) emit Claimed(msg.sender, paid);

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

305:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

310:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

642:                 if (pending > 0) emit Claimed(msg.sender, pending);

667:             if (pending > 0) emit Claimed(msg.sender, pending);

686:             if (paid > 0) emit Claimed(msg.sender, paid);

843:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

```

### <a name="NC-17"></a>[NC-17] Constant state variables defined more than once
Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (22)*:
```solidity
File: src/BatchNFTMinter.sol

70:     uint256 internal constant DUST_THRESHOLD = 1e6;

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

167:     uint256 internal constant DUST_THRESHOLD = 1e6;

```

```solidity
File: src/NFTStaker.sol

39:     uint256 public constant ACC_PRECISION = 1e18;

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

50:     uint256 public constant APY_PRECISION = 1e18;

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NFTStakerDepletion.sol

83:     uint256 public constant ACC_PRECISION = 1e18;

88:     uint256 public constant SECONDS_PER_YEAR = 365 days;

94:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

99:     uint256 public constant MAX_DEPLETION_MONTHS = 120;

```

```solidity
File: src/NFTStakerDepletionV2.sol

84:     uint256 public constant ACC_PRECISION = 1e18;

89:     uint256 public constant SECONDS_PER_YEAR = 365 days;

95:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

100:     uint256 public constant MAX_DEPLETION_MONTHS = 120;

```

```solidity
File: src/NFTStakerPriceScaled.sol

62:     uint256 public constant ACC_PRECISION = 1e18;

69:     uint256 public constant SECONDS_PER_YEAR = 365 days;

73:     uint256 public constant APY_PRECISION = 1e18;

79:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

101:     uint256 public constant ACC_PRECISION = 1e18;

108:     uint256 public constant SECONDS_PER_YEAR = 365 days;

112:     uint256 public constant APY_PRECISION = 1e18;

118:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="NC-18"></a>[NC-18] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (12)*:
```solidity
File: src/BatchNFTMinterMultiToken.sol

196:     mapping(address => uint256) private _nudgeTokenIndex;

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

103:     mapping(address => uint256) public parked;

107:     mapping(address => uint256) public migrationBegin;

116:     mapping(address => uint256) private _parkedIndex;

125:     mapping(address => uint256) public unforwarded;

```

```solidity
File: src/NFTStaker.sol

139:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NFTStakerDepletion.sol

193:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NFTStakerDepletionV2.sol

194:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NFTStakerMigrator.sol

101:     mapping(address => uint256) public unforwarded;

```

```solidity
File: src/NFTStakerPriceScaled.sol

170:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

209:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NudgeStreamer.sol

83:     mapping(address => mapping(address => Stream)) public streams;

```

### <a name="NC-19"></a>[NC-19] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (7)*:
```solidity
File: src/BatchNFTMinter.sol

156:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

353:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletion.sol

313:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletionV2.sol

314:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

339:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="NC-20"></a>[NC-20] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (6)*:
```solidity
File: src/NFTStakerDepletion.sol

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

812:     /// @notice `INFTStakerMigratable` accessor for the public `users` mapping.
         ///         Returns `user`'s currently-credited ERC1155 position and
         ///         reward-debt bookkeeping value. Used by the in-place migrator to
         ///         snapshot credited principal around a `depositFor`.
         function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {
             UserInfo memory info = users[user];
             return (info.amount, info.rewardDebt);
         }
     
         function pendingReward(address account) external view returns (uint256) {

```

```solidity
File: src/NFTStakerDepletionV2.sol

730:     /// @dev Shared migration exit for one user: settles+pays their pending
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

816:     /// @notice `INFTStakerMigratable` accessor for the public `users` mapping.
         ///         Returns `user`'s currently-credited ERC1155 position and
         ///         reward-debt bookkeeping value. Used by the in-place migrator to
         ///         snapshot credited principal around a `depositFor`.
         function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {
             UserInfo memory info = users[user];
             return (info.amount, info.rewardDebt);
         }
     
         function pendingReward(address account) external view returns (uint256) {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

849:     /// @dev Shared migration exit for one user: settles+pays their pending
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

952:     /// @notice `INFTStakerMigratable` accessor for the public `users` mapping.
         ///         Returns `user`'s currently-credited ERC1155 position and
         ///         reward-debt bookkeeping value. Used by the in-place migrator to
         ///         snapshot credited principal around a `depositFor`.
         function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {
             UserInfo memory info = users[user];
             return (info.amount, info.rewardDebt);
         }
     
         function pendingReward(address account) external view returns (uint256) {

```

### <a name="NC-21"></a>[NC-21] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (21)*:
```solidity
File: src/BatchNFTMinter.sol

182:         if (to == address(0)) revert Rescue__ZeroRecipient();

244:         if (count == 0) revert BatchMint__ZeroCount();

245:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

249:             revert BatchMint__MinterNotConfigured();

253:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

256:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

262:             revert BatchMint__NudgeTokenMatchesPaymentToken();

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

330:             if (token == address(0)) revert BatchMint__ZeroNudgeToken();

387:         if (to == address(0)) revert Rescue__ZeroRecipient();

471:         if (count == 0) revert BatchMint__ZeroCount();

472:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

740:             revert BatchMint__MinterNotConfigured();

744:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

747:         if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

```

```solidity
File: src/NFTStakerDepletion.sol

414:         if (to == address(0)) revert Rescue__ZeroRecipient();

```

```solidity
File: src/NFTStakerDepletionV2.sol

415:         if (to == address(0)) revert Rescue__ZeroRecipient();

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

443:         if (to == address(0)) revert Rescue__ZeroRecipient();

```

```solidity
File: src/NudgeStreamer.sol

126:         if (duration == 0) revert NudgeStreamer__ZeroDuration();

158:         if (s.duration == 0) revert NudgeStreamer__NotRegistered();

163:         if (amount == 0) revert NudgeStreamer__ZeroAmount();

199:         if (received == 0) revert NudgeStreamer__ZeroReceived();

```

### <a name="NC-22"></a>[NC-22] Avoid the use of sensitive terms
Use [alternative variants](https://www.zdnet.com/article/mysql-drops-master-slave-and-blacklist-whitelist-terminology/), e.g. allowlist/denylist instead of whitelist/blacklist

*Instances (11)*:
```solidity
File: src/BatchNFTMinterMultiToken.sol

223:     error BatchMint__NudgeTokenAlreadyWhitelisted(address token);

226:     error BatchMint__NudgeTokenNotWhitelisted(address token);

240:     event NudgeTokenWhitelistChanged(address indexed token, bool allowed);

328:     function setNudgeTokenWhitelist(address token, bool allowed) external onlyOwner {

332:                 revert BatchMint__NudgeTokenAlreadyWhitelisted(token);

338:             if (oneBasedIndex == 0) revert BatchMint__NudgeTokenNotWhitelisted(token);

348:         emit NudgeTokenWhitelistChanged(token, allowed);

```

```solidity
File: src/NudgeStreamer.sol

15: interface IMultiTokenNudgeWhitelist {

94:     error NudgeStreamer__NotWhitelisted(address batchMinter, address token);

127:         if (!IMultiTokenNudgeWhitelist(batchMinter).isNudgeToken(token)) {

128:             revert NudgeStreamer__NotWhitelisted(batchMinter, token);

```

### <a name="NC-23"></a>[NC-23] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (8)*:
```solidity
File: src/BatchNFTMinter.sol

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
File: src/BatchNFTMinterMultiToken.sol

1: 
   Current order:
   UsingForDirective.IERC20
   FunctionDefinition.constructor
   VariableDeclaration.DUST_THRESHOLD
   VariableDeclaration.tokenMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.nudgeSize
   VariableDeclaration.pauser
   VariableDeclaration._nudgeTokens
   VariableDeclaration._nudgeTokenIndex
   VariableDeclaration.nudgeStreamer
   ErrorDefinition.BatchMint__ZeroCount
   ErrorDefinition.BatchMint__ZeroRecipient
   ErrorDefinition.BatchMint__ArrayLengthMismatch
   ErrorDefinition.BatchMint__MinterNotConfigured
   ErrorDefinition.BatchMint__DispatcherNotConfigured
   ErrorDefinition.BatchMint__ZeroNudgeToken
   ErrorDefinition.BatchMint__NudgeTokenAlreadyWhitelisted
   ErrorDefinition.BatchMint__NudgeTokenNotWhitelisted
   ErrorDefinition.Rescue__ZeroRecipient
   ErrorDefinition.BatchMint__RewardBelowMinimum
   ErrorDefinition.BatchMint__PaymentBudgetExhausted
   EventDefinition.NudgeSizeChanged
   EventDefinition.NudgeTokenWhitelistChanged
   EventDefinition.NudgePaid
   EventDefinition.TokenMinterSet
   EventDefinition.DispatcherIndexSet
   EventDefinition.Rescued
   EventDefinition.PauserChanged
   EventDefinition.NudgeStreamerChanged
   ModifierDefinition.onlyPauser
   FunctionDefinition.setTokenMinter
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNudgeSize
   FunctionDefinition.getNudgeTokens
   FunctionDefinition.isNudgeToken
   FunctionDefinition.setNudgeStreamer
   FunctionDefinition.setNudgeTokenWhitelist
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.rescueERC20
   FunctionDefinition.batchMint
   FunctionDefinition._resolvePaymentPath
   FunctionDefinition._snapshotRewards
   FunctionDefinition._payRewards
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.DUST_THRESHOLD
   VariableDeclaration.tokenMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.nudgeSize
   VariableDeclaration.pauser
   VariableDeclaration._nudgeTokens
   VariableDeclaration._nudgeTokenIndex
   VariableDeclaration.nudgeStreamer
   ErrorDefinition.BatchMint__ZeroCount
   ErrorDefinition.BatchMint__ZeroRecipient
   ErrorDefinition.BatchMint__ArrayLengthMismatch
   ErrorDefinition.BatchMint__MinterNotConfigured
   ErrorDefinition.BatchMint__DispatcherNotConfigured
   ErrorDefinition.BatchMint__ZeroNudgeToken
   ErrorDefinition.BatchMint__NudgeTokenAlreadyWhitelisted
   ErrorDefinition.BatchMint__NudgeTokenNotWhitelisted
   ErrorDefinition.Rescue__ZeroRecipient
   ErrorDefinition.BatchMint__RewardBelowMinimum
   ErrorDefinition.BatchMint__PaymentBudgetExhausted
   EventDefinition.NudgeSizeChanged
   EventDefinition.NudgeTokenWhitelistChanged
   EventDefinition.NudgePaid
   EventDefinition.TokenMinterSet
   EventDefinition.DispatcherIndexSet
   EventDefinition.Rescued
   EventDefinition.PauserChanged
   EventDefinition.NudgeStreamerChanged
   ModifierDefinition.onlyPauser
   FunctionDefinition.constructor
   FunctionDefinition.setTokenMinter
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNudgeSize
   FunctionDefinition.getNudgeTokens
   FunctionDefinition.isNudgeToken
   FunctionDefinition.setNudgeStreamer
   FunctionDefinition.setNudgeTokenWhitelist
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.rescueERC20
   FunctionDefinition.batchMint
   FunctionDefinition._resolvePaymentPath
   FunctionDefinition._snapshotRewards
   FunctionDefinition._payRewards

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

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
File: src/NFTStakerDepletionV2.sol

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
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

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
   EventDefinition.TargetAPYChanged
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
   FunctionDefinition.setTargetAPY
   FunctionDefinition.topUp
   FunctionDefinition.pullAndRefresh
   FunctionDefinition.rescueERC20
   FunctionDefinition._syncBudget
   FunctionDefinition._recomputeScheduleIfActive
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
   EventDefinition.TargetAPYChanged
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
   FunctionDefinition.setTargetAPY
   FunctionDefinition.topUp
   FunctionDefinition.pullAndRefresh
   FunctionDefinition.rescueERC20
   FunctionDefinition._syncBudget
   FunctionDefinition._recomputeScheduleIfActive
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
File: src/NudgeStreamer.sol

1: 
   Current order:
   FunctionDefinition.isNudgeToken
   UsingForDirective.IERC20
   VariableDeclaration.PRECISION
   StructDefinition.Stream
   VariableDeclaration.streams
   ErrorDefinition.NudgeStreamer__NotRegistered
   ErrorDefinition.NudgeStreamer__ZeroDuration
   ErrorDefinition.NudgeStreamer__ZeroAmount
   ErrorDefinition.NudgeStreamer__ZeroReceived
   ErrorDefinition.NudgeStreamer__NotWhitelisted
   EventDefinition.StreamRegistered
   EventDefinition.Streamed
   EventDefinition.NudgeCollected
   FunctionDefinition.constructor
   FunctionDefinition.registerStream
   FunctionDefinition.collectNudge
   FunctionDefinition.pullPendingStream
   FunctionDefinition.pendingStream
   FunctionDefinition._settle
   FunctionDefinition._accrued
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.PRECISION
   VariableDeclaration.streams
   StructDefinition.Stream
   ErrorDefinition.NudgeStreamer__NotRegistered
   ErrorDefinition.NudgeStreamer__ZeroDuration
   ErrorDefinition.NudgeStreamer__ZeroAmount
   ErrorDefinition.NudgeStreamer__ZeroReceived
   ErrorDefinition.NudgeStreamer__NotWhitelisted
   EventDefinition.StreamRegistered
   EventDefinition.Streamed
   EventDefinition.NudgeCollected
   FunctionDefinition.isNudgeToken
   FunctionDefinition.constructor
   FunctionDefinition.registerStream
   FunctionDefinition.collectNudge
   FunctionDefinition.pullPendingStream
   FunctionDefinition.pendingStream
   FunctionDefinition._settle
   FunctionDefinition._accrued

```

### <a name="NC-24"></a>[NC-24] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (84)*:
```solidity
File: src/BatchNFTMinter.sol

110:     event NudgeSizeChanged(uint256 newSize);

112:     event NudgePaid(address indexed recipient, address indexed token, uint256 amount);

115:     event Rescued(address indexed token, address indexed to, uint256 amount);

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

239:     event NudgeSizeChanged(uint256 newSize);

240:     event NudgeTokenWhitelistChanged(address indexed token, bool allowed);

241:     event NudgePaid(address indexed recipient, address indexed token, uint256 amount);

244:     event Rescued(address indexed token, address indexed to, uint256 amount);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

140:     event MigratedOut(uint256 userCount, uint256 totalAmount);

141:     event MigratedIn(uint256 userCount, uint256 totalAmount);

142:     event TimedOutClaim(address indexed user, uint256 amount);

146:     event RewardForwarded(address indexed user, uint256 amount);

150:     event RewardForwardFailed(address indexed user, uint256 amount);

153:     event ForwardedClaimed(address indexed user, uint256 amount);

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

232:     event Staked(address indexed user, uint256 amount);

233:     event Unstaked(address indexed user, uint256 amount);

234:     event Claimed(address indexed user, uint256 amount);

235:     event EmergencyWithdrawn(address indexed user, uint256 amount);

238:     event Pulled(uint256 inflow, uint256 newBudget);

240:     event ToppedUp(address indexed from, uint256 amount, uint256 newBudget);

242:     event StakedIdChanged(uint256 previous, uint256 next);

246:     event DepletionWindowChanged(uint256 previous, uint256 next);

247:     event DispatcherIndexChanged(uint256 previous, uint256 next);

256:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

259:     event Rescued(address indexed token, address indexed to, uint256 amount);

264:     event MigrationInitiated(uint256 totalStaked);

268:     event MigratedOut(address indexed user, uint256 amount, uint256 reward);

271:     event UserMigrated(address indexed user, uint256 amount, uint256 reward);

273:     event DepositedFor(address indexed user, uint256 amount);

```

```solidity
File: src/NFTStakerDepletionV2.sol

233:     event Staked(address indexed user, uint256 amount);

234:     event Unstaked(address indexed user, uint256 amount);

235:     event Claimed(address indexed user, uint256 amount);

236:     event EmergencyWithdrawn(address indexed user, uint256 amount);

239:     event Pulled(uint256 inflow, uint256 newBudget);

241:     event ToppedUp(address indexed from, uint256 amount, uint256 newBudget);

243:     event StakedIdChanged(uint256 previous, uint256 next);

247:     event DepletionWindowChanged(uint256 previous, uint256 next);

248:     event DispatcherIndexChanged(uint256 previous, uint256 next);

257:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

260:     event Rescued(address indexed token, address indexed to, uint256 amount);

265:     event MigrationInitiated(uint256 totalStaked);

269:     event MigratedOut(address indexed user, uint256 amount, uint256 reward);

272:     event UserMigrated(address indexed user, uint256 amount, uint256 reward);

274:     event DepositedFor(address indexed user, uint256 amount);

```

```solidity
File: src/NFTStakerMigrator.sol

107:     event Migrated(uint256 userCount, uint256 totalAmount);

111:     event RewardForwarded(address indexed user, uint256 amount);

115:     event RewardForwardFailed(address indexed user, uint256 amount);

118:     event ForwardedClaimed(address indexed user, uint256 amount);

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

248:     event Staked(address indexed user, uint256 amount);

249:     event Unstaked(address indexed user, uint256 amount);

250:     event Claimed(address indexed user, uint256 amount);

251:     event EmergencyWithdrawn(address indexed user, uint256 amount);

257:     event Pulled(uint256 inflow, uint256 newBudget);

260:     event ToppedUp(address indexed from, uint256 amount, uint256 newBudget);

262:     event StakedIdChanged(uint256 previous, uint256 next);

264:     event TargetAPYChanged(uint256 previous, uint256 next);

265:     event DispatcherIndexChanged(uint256 previous, uint256 next);

279:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

282:     event Rescued(address indexed token, address indexed to, uint256 amount);

287:     event MigrationInitiated(uint256 totalStaked);

291:     event MigratedOut(address indexed user, uint256 amount, uint256 reward);

294:     event UserMigrated(address indexed user, uint256 amount, uint256 reward);

296:     event DepositedFor(address indexed user, uint256 amount);

```

```solidity
File: src/NudgeStreamer.sol

97:     event StreamRegistered(

105:     event Streamed(address indexed batchMinter, address indexed token, uint256 amount);

```

### <a name="NC-25"></a>[NC-25] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (9)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

224:         for (uint256 i = 0; i < users.length; i++) {

264:         for (uint256 i = 0; i < sliceLen; i++) {

277:         for (uint256 i = 0; i < sliceLen; i++) {

435:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

697:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerDepletionV2.sol

703:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

174:         for (uint256 i = 0; i < amounts.length; i++) {

189:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

822:         for (uint256 i = 0; i < accounts.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 9 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 32 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 12 |
| [L-4](#L-4) | Division by zero not prevented | 22 |
| [L-5](#L-5) | Owner can renounce while system is paused | 7 |
| [L-6](#L-6) | Possible rounding issue | 10 |
| [L-7](#L-7) | Loss of precision | 65 |
| [L-8](#L-8) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 9 |
| [L-9](#L-9) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 10 |
| [L-10](#L-10) | Sweeping may break accounting if tokens with multiple addresses are used | 9 |
| [L-11](#L-11) | Unsafe ERC20 operation(s) | 2 |
| [L-12](#L-12) | A year is not always 365 days | 5 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (9)*:
```solidity
File: src/BatchNFTMinter.sol

62: contract BatchNFTMinter is Ownable, Pausable, IPausable {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

159: contract BatchNFTMinterMultiToken is Ownable, Pausable, ReentrancyGuard, IPausable {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

77: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: src/NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: src/NFTStakerDepletion.sol

75: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: src/NFTStakerDepletionV2.sol

76: contract NFTStakerDepletionV2 is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: src/NFTStakerMigrator.sol

77: contract NFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: src/NFTStakerPriceScaled.sol

54: contract NFTStakerPriceScaled is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: src/NudgeStreamer.sol

63: contract NudgeStreamer is INudgeStreamer, Ownable, ReentrancyGuard {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (32)*:
```solidity
File: src/BatchNFTMinter.sol

183:         token.safeTransfer(to, amount);

283:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

301:             IERC20(_nudgeTokenEntry).safeTransfer(recipient, nudgeAmount);

307:             paymentToken.safeTransfer(msg.sender, remaining);

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

389:         emit Rescued(address(token), to, amount);

581:             paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

712:                 totalPaid = paymentAmount - refund;

834:             emit NudgePaid(recipient, rewardToken, amount);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

324:             try rewardToken.transfer(user, captured) returns (bool ok) {

352:         rewardToken.safeTransfer(msg.sender, amount);

397:         token.safeTransfer(to, amount);

```

```solidity
File: src/NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

512:             rewardToken.safeTransfer(msg.sender, amount);

```

```solidity
File: src/NFTStakerDepletion.sol

391:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

417:             token.safeTransfer(to, amount);

421:             token.safeTransfer(to, amount);

617:             rewardToken.safeTransfer(account, amount);

```

```solidity
File: src/NFTStakerDepletionV2.sol

392:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

418:             token.safeTransfer(to, amount);

422:             token.safeTransfer(to, amount);

624:             if (amount > committedDebt) {

```

```solidity
File: src/NFTStakerMigrator.sol

227:             try rewardToken.transfer(user, captured) returns (bool ok) {

254:         rewardToken.safeTransfer(msg.sender, amount);

275:         token.safeTransfer(to, amount);

```

```solidity
File: src/NFTStakerPriceScaled.sol

315:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

551:             rewardToken.safeTransfer(msg.sender, amount);

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

420:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

446:             token.safeTransfer(to, amount);

450:             token.safeTransfer(to, amount);

723:             rewardToken.safeTransfer(account, amount);

```

```solidity
File: src/NudgeStreamer.sol

194:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

243:             IERC20(token).safeTransfer(recipient, settled);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (12)*:
```solidity
File: src/BatchNFTMinter.sol

150:         nudgePaymentToken = newToken;

158:         pauser = newPauser;

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

300:     }

358:     /// @notice Pause `batchMint`. Callable only by the registered `pauser`

```

```solidity
File: src/NFTStaker.sol

211:         pauser = newPauser;

```

```solidity
File: src/NFTStakerDepletion.sol

315:         pauser = newPauser;

324:         migrator = newMigrator;

```

```solidity
File: src/NFTStakerDepletionV2.sol

317:     }

326:     }

```

```solidity
File: src/NFTStakerPriceScaled.sol

245:         pauser = newPauser;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

341:         pauser = newPauser;

350:         migrator = newMigrator;

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (22)*:
```solidity
File: src/NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

418:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

619:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerDepletion.sol

480:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

536:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

832:             acc += (reward * ACC_PRECISION) / totalStaked;

874:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerDepletionV2.sol

481:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

537:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

836:             acc += (reward * ACC_PRECISION) / totalStaked;

878:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerPriceScaled.sol

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

457:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

658:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

523:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

613:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

972:             acc += (reward * ACC_PRECISION) / totalStaked;

1017:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NudgeStreamer.sol

139:         s.rewardPerSecond = (s.buffer * PRECISION) / duration;

206:         s.rewardPerSecond = (s.buffer * PRECISION) / s.duration;

```

### <a name="L-5"></a>[L-5] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (7)*:
```solidity
File: src/BatchNFTMinter.sol

156:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

353:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletion.sol

313:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletionV2.sol

314:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

339:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="L-6"></a>[L-6] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (10)*:
```solidity
File: src/NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerDepletion.sol

480:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

832:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerDepletionV2.sol

481:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

836:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerPriceScaled.sol

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

523:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

972:             acc += (reward * ACC_PRECISION) / totalStaked;

```

### <a name="L-7"></a>[L-7] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (65)*:
```solidity
File: src/BatchNFTMinter.sol

306:         if (remaining / DUST_THRESHOLD != 0) {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

710:             if (refund / DUST_THRESHOLD != 0) {

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

480:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

558:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

567:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

576:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

583:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

591:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

596:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

637:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

739:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

776:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

785:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

832:             acc += (reward * ACC_PRECISION) / totalStaked;

834:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

```

```solidity
File: src/NFTStakerDepletionV2.sol

481:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

564:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

573:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

582:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

589:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

597:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

602:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

643:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

745:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

780:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

789:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

836:             acc += (reward * ACC_PRECISION) / totalStaked;

838:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

523:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

612:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

639:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

648:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

664:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

671:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

683:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

688:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

753:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

864:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

899:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

908:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

972:             acc += (reward * ACC_PRECISION) / totalStaked;

974:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

```

```solidity
File: src/NudgeStreamer.sol

268:         uint256 accrued = (s.rewardPerSecond * elapsed) / PRECISION;

```

### <a name="L-8"></a>[L-8] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (9)*:
```solidity
File: src/BatchNFTMinter.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/NFTStaker.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/NFTStakerDepletion.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/NFTStakerDepletionV2.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/NFTStakerMigrator.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/NFTStakerPriceScaled.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

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

*Instances (10)*:
```solidity
File: src/BatchNFTMinter.sol

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/NFTStaker.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/NFTStakerDepletion.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/NFTStakerDepletionV2.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/NFTStakerMigrator.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/NFTStakerPriceScaled.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/NudgeStreamer.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-10"></a>[L-10] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (9)*:
```solidity
File: src/BatchNFTMinter.sol

181:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

386:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

390:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

408:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletion.sol

413:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletionV2.sol

414:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerMigrator.sol

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

286:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

442:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

### <a name="L-11"></a>[L-11] Unsafe ERC20 operation(s)

*Instances (2)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

324:             try rewardToken.transfer(user, captured) returns (bool ok) {

```

```solidity
File: src/NFTStakerMigrator.sol

227:             try rewardToken.transfer(user, captured) returns (bool ok) {

```

### <a name="L-12"></a>[L-12] A year is not always 365 days
On leap years, the number of days is 366, so calculations during those years will return the wrong value

*Instances (5)*:
```solidity
File: src/NFTStaker.sol

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: src/NFTStakerDepletion.sol

88:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: src/NFTStakerDepletionV2.sol

89:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: src/NFTStakerPriceScaled.sol

69:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

108:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 8 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 92 |
| [M-3](#M-3) | Return values of `transfer()`/`transferFrom()` not checked | 2 |
| [M-4](#M-4) | Unsafe use of `transfer()`/`transferFrom()` with `IERC20` | 2 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (8)*:
```solidity
File: src/BatchNFTMinter.sol

283:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

581:             paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

```

```solidity
File: src/NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NFTStakerDepletion.sol

391:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NFTStakerDepletionV2.sol

392:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NFTStakerPriceScaled.sol

315:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

420:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NudgeStreamer.sol

194:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (92)*:
```solidity
File: src/BatchNFTMinter.sol

62: contract BatchNFTMinter is Ownable, Pausable, IPausable {

65:     constructor(address initialOwner) Ownable(initialOwner) {}

126:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

135:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

142:     function setNudgeSize(uint256 newSize) external onlyOwner {

149:     function setNudgePaymentToken(address newToken) external onlyOwner {

156:     function setPauser(address newPauser) external onlyOwner {

181:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/BatchNFTMinterMultiToken.sol

159: contract BatchNFTMinterMultiToken is Ownable, Pausable, ReentrancyGuard, IPausable {

162:     constructor(address initialOwner) Ownable(initialOwner) {}

256:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

265:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

272:     function setNudgeSize(uint256 newSize) external onlyOwner {

297:     function setNudgeStreamer(address newStreamer) external onlyOwner {

328:     function setNudgeTokenWhitelist(address token, bool allowed) external onlyOwner {

353:     function setPauser(address newPauser) external onlyOwner {

386:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

77: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

162:     ) Ownable(initialOwner) {

207:     function initiateMigration() external onlyOwner {

219:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

253:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

390:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

408:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStaker.sol

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
File: src/NFTStakerDepletion.sol

75: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

298:     ) Ownable(_initialOwner) {

313:     function setPauser(address newPauser) external onlyOwner {

322:     function setMigrator(address newMigrator) external onlyOwner {

339:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

344:     function setStakedId(uint256 newId) external onlyOwner {

352:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

361:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

375:     function setDepletionWindow(uint256 months) external onlyOwner {

388:     function topUp(uint256 amount) external onlyOwner {

397:     function pullAndRefresh() external onlyOwner {

413:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

800:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NFTStakerDepletionV2.sol

76: contract NFTStakerDepletionV2 is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

299:     ) Ownable(_initialOwner) {

314:     function setPauser(address newPauser) external onlyOwner {

323:     function setMigrator(address newMigrator) external onlyOwner {

340:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

345:     function setStakedId(uint256 newId) external onlyOwner {

353:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

362:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

376:     function setDepletionWindow(uint256 months) external onlyOwner {

389:     function topUp(uint256 amount) external onlyOwner {

398:     function pullAndRefresh() external onlyOwner {

414:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

804:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NFTStakerMigrator.sol

77: contract NFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

127:     ) Ownable(initialOwner) {

153:     function initiateMigration() external onlyOwner {

170:     function migrate(address[] calldata users) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

286:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

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

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

87:     Ownable,

322:     ) Ownable(_initialOwner) {

339:     function setPauser(address newPauser) external onlyOwner {

348:     function setMigrator(address newMigrator) external onlyOwner {

365:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

370:     function setStakedId(uint256 newId) external onlyOwner {

380:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

390:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

403:     function setTargetAPY(uint256 newAPY) external onlyOwner {

417:     function topUp(uint256 amount) external onlyOwner {

426:     function pullAndRefresh() external onlyOwner {

442:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

939:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NudgeStreamer.sol

63: contract NudgeStreamer is INudgeStreamer, Ownable, ReentrancyGuard {

116:     constructor(address initialOwner) Ownable(initialOwner) {}

125:     function registerStream(address batchMinter, address token, uint256 duration) external override onlyOwner {

```

### <a name="M-3"></a>[M-3] Return values of `transfer()`/`transferFrom()` not checked
Not all `IERC20` implementations `revert()` when there's a failure in `transfer()`/`transferFrom()`. The function signature has a `boolean` return value and they indicate errors that way instead. By not checking the return value, operations that should have marked as failed, may potentially go through without actually making a payment

*Instances (2)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

324:             try rewardToken.transfer(user, captured) returns (bool ok) {

```

```solidity
File: src/NFTStakerMigrator.sol

227:             try rewardToken.transfer(user, captured) returns (bool ok) {

```

### <a name="M-4"></a>[M-4] Unsafe use of `transfer()`/`transferFrom()` with `IERC20`
Some tokens do not implement the ERC20 standard properly but are still accepted by most code that accepts ERC20 tokens.  For example Tether (USDT)'s `transfer()` and `transferFrom()` functions on L1 do not return booleans as the specification requires, and instead have no return value. When these sorts of tokens are cast to `IERC20`, their [function signatures](https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca) do not match and therefore the calls made, revert (see [this](https://gist.github.com/IllIllI000/2b00a32e8f0559e8f386ea4f1800abc5) link for a test case). Use OpenZeppelin's `SafeERC20`'s `safeTransfer()`/`safeTransferFrom()` instead

*Instances (2)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

324:             try rewardToken.transfer(user, captured) returns (bool ok) {

```

```solidity
File: src/NFTStakerMigrator.sol

227:             try rewardToken.transfer(user, captured) returns (bool ok) {

```

