# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 39 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 48 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 6 |
| [GAS-4](#GAS-4) | State variables should be cached in stack variables rather than re-reading them from storage | 2 |
| [GAS-5](#GAS-5) | For Operations that will not overflow, you could use unchecked | 277 |
| [GAS-6](#GAS-6) | Use Custom Errors instead of Revert Strings to save Gas | 104 |
| [GAS-7](#GAS-7) | Avoid contract existence checks by using low level calls | 29 |
| [GAS-8](#GAS-8) | State variables only set in the constructor should be declared `immutable` | 18 |
| [GAS-9](#GAS-9) | Functions guaranteed to revert when called by normal users can be marked `payable` | 64 |
| [GAS-10](#GAS-10) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 11 |
| [GAS-11](#GAS-11) | Using `private` rather than `public` for constants, saves gas | 18 |
| [GAS-12](#GAS-12) | Splitting require() statements that use && saves gas | 1 |
| [GAS-13](#GAS-13) | Increments/decrements can be unchecked in for-loops | 11 |
| [GAS-14](#GAS-14) | Use != 0 instead of > 0 for unsigned integer comparison | 86 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (39)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

160:                 parked[users[i]] += amt;

163:                 totalParked += amt;

164:                 total += amt;

221:             total += amt;

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

468:             committedDebt += reward;

469:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

517:             V += dispatcherHook.mintDebt();

554:         user.amount += amount;

555:         totalStaked += amount;

633:             rewardBudget += forfeit;

689:             totalAmount += amount;

761:         info.amount += amount;

762:         totalStaked += amount;

810:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerMigrator.sol

86:             total += amounts[i];

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

513:             committedDebt += reward;

514:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

591:             V += dispatcherHook.mintDebt();

632:         user.amount += amount;

633:         totalStaked += amount;

754:             rewardBudget += forfeit;

811:             totalAmount += amount;

892:         info.amount += amount;

893:         totalStaked += amount;

958:             acc += (reward * ACC_PRECISION) / totalStaked;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (48)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

83:         require(TOKEN_MINTER != address(0), "deploy: tokenMinter unset");

90:         require(pauser != address(0), "deploy: pauser unset (set PAUSER env)");

91:         require(owner != address(0), "deploy: owner unset");

```

```solidity
File: src/BatchNFTMinter.sol

209:         if (to == address(0)) revert Rescue__ZeroRecipient();

303:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

311:         if (address(nftMinter) == address(0)) {

321:             if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

100:         require(address(_staker) != address(0), "InPlace: zero staker");

101:         require(address(_stakedToken) != address(0), "InPlace: zero staked token");

269:         require(to != address(0), "InPlace: zero recipient");

282:         require(to != address(0), "InPlace: zero recipient");

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

288:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

289:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

290:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

352:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

403:         if (to == address(0)) revert Rescue__ZeroRecipient();

425:         if (address(dispatcherHook) == address(0)) {

516:         if (address(dispatcherHook) != address(0)) {

840:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

851:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

```solidity
File: src/NFTStakerMigrator.sol

55:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

56:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

57:         require(address(_stakedToken) != address(0), "Migrator: zero staked token");

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

314:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

315:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

316:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

383:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

434:         if (to == address(0)) revert Rescue__ZeroRecipient();

462:         if (address(dispatcherHook) == address(0)) {

590:         if (address(dispatcherHook) != address(0)) {

992:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

1002:         uint256 pending = address(dispatcherHook) == address(0) ? 0 : dispatcherHook.mintDebt();

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (6)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

686:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

808:         for (uint256 i = 0; i < accounts.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (2)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

205:             stakedToken.setApprovalForAll(address(staker), true);

```

```solidity
File: src/NFTStakerMigrator.sol

108:         stakedToken.setApprovalForAll(address(newStaker), false);

```

### <a name="GAS-5"></a>[GAS-5] For Operations that will not overflow, you could use unchecked

*Instances (277)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

4: import {Script} from "forge-std/Script.sol";

5: import {console2} from "forge-std/console2.sol";

6: import {ITokenMinterV2} from "yield-claim-nft/interfaces/ITokenMinterV2.sol";

7: import {BatchNFTMinter} from "../src/BatchNFTMinter.sol";

123:         console2.log("  rewardAsset:   caller-selected per call (none configured on-chain)");

```

```solidity
File: src/BatchNFTMinter.sol

4: import {ITokenMinterV2} from "yield-claim-nft/interfaces/ITokenMinterV2.sol";

5: import {INFTMinterV2} from "yield-claim-nft/interfaces/INFTMinterV2.sol";

6: import {ITokenDispatcherV2} from "yield-claim-nft/interfaces/ITokenDispatcherV2.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

10: import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

11: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

12: import {IPausable} from "pauser/interfaces/IPausable.sol";

363:         for (uint256 i; i < count; ++i) {

382:         if (remaining / DUST_THRESHOLD != 0) {

384:             totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0;

424:         for (uint256 i; i < tokenCount; ++i) {

454:         for (uint256 i; i < tokenCount; ++i) {

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

83:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

424:         _updatePool();                                 // always: settle accrual

426:             return;                                    // no hook → no pull → no budget change → no recompute

430:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

431:         if (inflow > 0) {                              // new NFT minted → budget grew → restart window (intended)

463:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

464:         uint256 reward = elapsed * rewardRate;

467:             rewardBudget -= reward;

468:             committedDebt += reward;

469:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

513:         uint256 windowSeconds = depletionWindowMonths * SECONDS_PER_MONTH;

517:             V += dispatcherHook.mintDebt();

523:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

525:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

529:         windowEnd = block.timestamp + windowSeconds;

547:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

554:         user.amount += amount;

555:         totalStaked += amount;

556:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

565:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

570:         user.amount -= amount;

571:         totalStaked -= amount;

572:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

580:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

585:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

608:                 rewardBudget -= (amount - committedDebt);

611:                 committedDebt -= amount;

626:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

629:         totalStaked -= amount;

632:             committedDebt -= forfeit;

633:             rewardBudget += forfeit;

686:         for (uint256 i = 0; i < accounts.length; i++) {

689:             totalAmount += amount;

728:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

731:         totalStaked -= amount;

754:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

761:         info.amount += amount;

762:         totalStaked += amount;

763:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

807:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

808:             uint256 reward = elapsed * rewardRate;

810:             acc += (reward * ACC_PRECISION) / totalStaked;

812:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

831:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

832:         uint256 reward = elapsed * rewardRate;

834:         return committedDebt + reward;

841:         return rewardToken.balanceOf(address(this)) + pending;

852:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerMigrator.sol

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

109:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

468:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

508:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

509:         uint256 reward = elapsed * rewardRate;

512:             rewardBudget -= reward;

513:             committedDebt += reward;

514:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

576:             uint256 r = APY_PRECISION + growthBasisPoints * 1e14;

582:         latestPrice = latestPrice * priceScale;

587:         uint256 S = (totalStaked == 0 || latestPrice == 0) ? 0 : totalStaked * latestPrice;

591:             V += dispatcherHook.mintDebt();

600:         uint256 budget = V > committedDebt ? V - committedDebt : 0;

603:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

604:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

608:         windowEnd = block.timestamp + runway;

625:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

632:         user.amount += amount;

633:         totalStaked += amount;

634:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

650:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

655:         user.amount -= amount;

656:         totalStaked -= amount;

657:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

669:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

674:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

711:                 rewardBudget -= (amount - committedDebt);

714:                 committedDebt -= amount;

739:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

742:         totalStaked -= amount;

753:             committedDebt -= forfeit;

754:             rewardBudget += forfeit;

808:         for (uint256 i = 0; i < accounts.length; i++) {

811:             totalAmount += amount;

850:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

853:         totalStaked -= amount;

885:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

892:         info.amount += amount;

893:         totalStaked += amount;

894:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

955:             uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

956:             uint256 reward = elapsed * rewardRate;

958:             acc += (reward * ACC_PRECISION) / totalStaked;

960:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

983:         uint256 elapsed = end > lastRewardTime ? end - lastRewardTime : 0;

984:         uint256 reward = elapsed * rewardRate;

986:         return committedDebt + reward;

993:         return rewardToken.balanceOf(address(this)) + pending;

1003:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="GAS-6"></a>[GAS-6] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (104)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

83:         require(TOKEN_MINTER != address(0), "deploy: tokenMinter unset");

88:         require(NUDGE_SIZE != 0, "deploy: nudgeSize zero");

89:         require(DISPATCHER_INDEX != 0, "deploy: dispatcherIndex unset");

90:         require(pauser != address(0), "deploy: pauser unset (set PAUSER env)");

91:         require(owner != address(0), "deploy: owner unset");

112:         require(address(batch.tokenMinter()) == TOKEN_MINTER, "deploy: minter not pinned");

113:         require(batch.dispatcherIndex() == DISPATCHER_INDEX, "deploy: dispatcherIndex not pinned");

114:         require(batch.nudgeSize() == NUDGE_SIZE, "deploy: nudge size not set");

115:         require(batch.pauser() == pauser, "deploy: pauser not set");

```

```solidity
File: src/BatchNFTMinter.sol

143:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

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

540:         require(amount > 0, "NFTStaker: zero stake");

561:         require(amount > 0, "NFTStaker: zero unstake");

563:         require(user.amount >= amount, "NFTStaker: insufficient stake");

604:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

625:         require(amount > 0, "NFTStaker: nothing to withdraw");

654:         require(poolState == PoolState.Active, "NFTStaker: not active");

682:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

706:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

707:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

749:         require(amount > 0, "NFTStaker: zero deposit");

750:         require(poolState == PoolState.Active, "NFTStaker: not active");

779:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

780:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

```solidity
File: src/NFTStakerMigrator.sol

55:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

56:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

57:         require(address(_stakedToken) != address(0), "Migrator: zero staked token");

58:         require(address(_oldStaker) != address(_newStaker), "Migrator: same staker");

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

296:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

301:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

314:         require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");

315:         require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");

316:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

317:         require(_priceScale != 0, "NFTStaker: zero price scale");

362:         require(totalStaked == 0, "NFTStaker: stake outstanding");

372:         require(totalStaked == 0, "NFTStaker: stake outstanding");

382:         require(totalStaked == 0, "NFTStaker: stake outstanding");

383:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

395:         require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");

409:         require(amount > 0, "NFTStaker: zero topUp");

438:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

618:         require(amount > 0, "NFTStaker: zero stake");

646:         require(amount > 0, "NFTStaker: zero unstake");

648:         require(user.amount >= amount, "NFTStaker: insufficient stake");

707:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

738:         require(amount > 0, "NFTStaker: nothing to withdraw");

775:         require(poolState == PoolState.Active, "NFTStaker: not active");

804:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

828:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

829:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

880:         require(amount > 0, "NFTStaker: zero deposit");

881:         require(poolState == PoolState.Active, "NFTStaker: not active");

926:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

927:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

### <a name="GAS-7"></a>[GAS-7] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (29)*:
```solidity
File: src/BatchNFTMinter.sol

381:         uint256 remaining = paymentToken.balanceOf(address(this));

429:             uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

284:             uint256 balance = stakedToken.balanceOf(address(this), stakedId);

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

407:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

428:         uint256 pre = rewardToken.balanceOf(address(this));

430:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

515:         uint256 V = rewardToken.balanceOf(address(this));

604:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

841:         return rewardToken.balanceOf(address(this)) + pending;

852:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

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

438:             require(rewardToken.balanceOf(address(this)) >= committedDebt, "NFTStaker: rescue breaches committedDebt");

466:         uint256 pre = rewardToken.balanceOf(address(this));

468:         uint256 inflow = rewardToken.balanceOf(address(this)) - pre;

589:         uint256 V = rewardToken.balanceOf(address(this));

707:         require(rewardToken.balanceOf(address(this)) >= amount, "NFTStaker: insufficient reward balance");

993:         return rewardToken.balanceOf(address(this)) + pending;

1003:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="GAS-8"></a>[GAS-8] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (18)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

105:         staker = _staker;

106:         stakedToken = _stakedToken;

107:         stakedId = _stakedId;

108:         migrationTimeout = _migrationTimeout;

```

```solidity
File: src/NFTStaker.sol

198:         stakedToken = _stakedToken;

200:         rewardToken = _rewardToken;

```

```solidity
File: src/NFTStakerDepletion.sol

291:         stakedToken = _stakedToken;

293:         rewardToken = _rewardToken;

```

```solidity
File: src/NFTStakerMigrator.sol

59:         oldStaker = _oldStaker;

60:         newStaker = _newStaker;

61:         stakedToken = _stakedToken;

62:         stakedId = _stakedId;

```

```solidity
File: src/NFTStakerPriceScaled.sol

231:         stakedToken = _stakedToken;

233:         rewardToken = _rewardToken;

236:         priceScale = _priceScale;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

318:         stakedToken = _stakedToken;

320:         rewardToken = _rewardToken;

323:         priceScale = _priceScale;

```

### <a name="GAS-9"></a>[GAS-9] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (64)*:
```solidity
File: src/BatchNFTMinter.sol

150:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

159:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

166:     function setNudgeSize(uint256 newSize) external onlyOwner {

173:     function setPauser(address newPauser) external onlyOwner {

181:     function pause() external override onlyPauser {

186:     function unpause() external override onlyPauser {

208:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

140:     function initiateMigration() external onlyOwner {

152:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

186:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

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

653:     function initiateMigration() external override nonReentrant onlyMigrator {

748:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

778:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NFTStakerMigrator.sol

70:     function initiateMigration() external onlyOwner {

81:     function migrate(address[] calldata users) external onlyOwner {

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

330:     function setPauser(address newPauser) external onlyOwner {

339:     function setMigrator(address newMigrator) external onlyOwner {

344:     function pause() external onlyPauser {

348:     function unpause() external onlyPauser {

356:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

361:     function setStakedId(uint256 newId) external onlyOwner {

371:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

381:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

394:     function setTargetAPY(uint256 newAPY) external onlyOwner {

408:     function topUp(uint256 amount) external onlyOwner {

417:     function pullAndRefresh() external onlyOwner {

433:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

774:     function initiateMigration() external override nonReentrant onlyMigrator {

879:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

925:     function finalizeAndReset() external onlyOwner {

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

*Instances (11)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

165:                 count++;

197:         for (uint256 i = 0; i < sliceLen; i++) {

210:         for (uint256 i = 0; i < sliceLen; i++) {

222:             count++;

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

686:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

103:                 migratedCount++;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

808:         for (uint256 i = 0; i < accounts.length; i++) {

```

### <a name="GAS-11"></a>[GAS-11] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (18)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

83:     uint256 public constant MIN_TIMEOUT = 1 days;

87:     uint256 public constant MAX_TIMEOUT = 30 days;

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

72:     uint256 public constant ACC_PRECISION = 1e18;

77:     uint256 public constant SECONDS_PER_YEAR = 365 days;

83:     uint256 public constant SECONDS_PER_MONTH = 365 days / 12;

88:     uint256 public constant MAX_DEPLETION_MONTHS = 120;

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

92:     uint256 public constant ACC_PRECISION = 1e18;

99:     uint256 public constant SECONDS_PER_YEAR = 365 days;

103:     uint256 public constant APY_PRECISION = 1e18;

109:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="GAS-12"></a>[GAS-12] Splitting require() statements that use && saves gas

*Instances (1)*:
```solidity
File: src/NFTStakerDepletion.sol

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

*Instances (11)*:
```solidity
File: src/BatchNFTMinter.sol

363:         for (uint256 i; i < count; ++i) {

424:         for (uint256 i; i < tokenCount; ++i) {

454:         for (uint256 i; i < tokenCount; ++i) {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

197:         for (uint256 i = 0; i < sliceLen; i++) {

210:         for (uint256 i = 0; i < sliceLen; i++) {

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

686:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

808:         for (uint256 i = 0; i < accounts.length; i++) {

```

### <a name="GAS-14"></a>[GAS-14] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (86)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

159:             if (amt > 0) {

204:         if (totalParked > 0) {

244:         require(amount > 0, "InPlace: nothing parked");

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

378:         require(amount > 0, "NFTStaker: zero topUp");

431:         if (inflow > 0) {                              // new NFT minted → budget grew → restart window (intended)

466:         if (reward > 0) {

540:         require(amount > 0, "NFTStaker: zero stake");

546:         if (user.amount > 0) {

548:             if (pending > 0) {

550:                 if (pending > 0) emit Claimed(msg.sender, pending);

561:         require(amount > 0, "NFTStaker: zero unstake");

566:         if (pending > 0) {

568:             if (pending > 0) emit Claimed(msg.sender, pending);

581:         if (pending > 0) {

583:             if (paid > 0) emit Claimed(msg.sender, paid);

605:         if (amount > 0) {

625:         require(amount > 0, "NFTStaker: nothing to withdraw");

630:         if (pending > 0) {

690:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

692:         if (totalAmount > 0) {

707:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

732:         if (pending > 0) {

734:             if (paid > 0) emit Claimed(account, paid);

749:         require(amount > 0, "NFTStaker: zero deposit");

753:         if (info.amount > 0) {

755:             if (pending > 0) {

757:                 if (pending > 0) emit Claimed(user, pending);

805:         if (poolState == PoolState.Active && block.timestamp > lastRewardTime && totalStaked > 0) {

```

```solidity
File: src/NFTStakerMigrator.sol

101:             if (amounts[i] > 0) {

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

409:         require(amount > 0, "NFTStaker: zero topUp");

470:         if (inflow > 0) {

511:         if (reward > 0) {

618:         require(amount > 0, "NFTStaker: zero stake");

624:         if (user.amount > 0) {

626:             if (pending > 0) {

628:                 if (pending > 0) emit Claimed(msg.sender, pending);

646:         require(amount > 0, "NFTStaker: zero unstake");

651:         if (pending > 0) {

653:             if (pending > 0) emit Claimed(msg.sender, pending);

670:         if (pending > 0) {

672:             if (paid > 0) emit Claimed(msg.sender, paid);

708:         if (amount > 0) {

738:         require(amount > 0, "NFTStaker: nothing to withdraw");

743:         if (pending > 0) {

812:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

814:         if (totalAmount > 0) {

829:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

854:         if (pending > 0) {

856:             if (paid > 0) emit Claimed(account, paid);

880:         require(amount > 0, "NFTStaker: zero deposit");

884:         if (info.amount > 0) {

886:             if (pending > 0) {

888:                 if (pending > 0) emit Claimed(user, pending);

953:         if (poolState == PoolState.Active && block.timestamp > lastRewardTime && totalStaked > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 7 |
| [NC-2](#NC-2) | Constants should be in CONSTANT_CASE | 3 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 61 |
| [NC-4](#NC-4) | Delete rogue `console.log` imports | 1 |
| [NC-5](#NC-5) | Consider disabling `renounceOwnership()` | 6 |
| [NC-6](#NC-6) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 34 |
| [NC-7](#NC-7) | Events should use parameters to convey information | 2 |
| [NC-8](#NC-8) | Event missing indexed field | 26 |
| [NC-9](#NC-9) | Events that mark critical parameter changes should contain both the old and the new value | 30 |
| [NC-10](#NC-10) | Function ordering does not follow the Solidity style guide | 6 |
| [NC-11](#NC-11) | Functions should not be longer than 50 lines | 105 |
| [NC-12](#NC-12) | Lack of checks in setters | 14 |
| [NC-13](#NC-13) | NatSpec is completely non-existent on functions that should have them | 33 |
| [NC-14](#NC-14) | Incomplete NatSpec: `@param` is missing on actually documented functions | 19 |
| [NC-15](#NC-15) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 22 |
| [NC-16](#NC-16) | Constant state variables defined more than once | 14 |
| [NC-17](#NC-17) | Consider using named mappings | 7 |
| [NC-18](#NC-18) | `address`s shouldn't be hard-coded | 1 |
| [NC-19](#NC-19) | Owner can renounce while system is paused | 5 |
| [NC-20](#NC-20) | Adding a `return` statement when the function defines a named return variable, is redundant | 4 |
| [NC-21](#NC-21) | Take advantage of Custom Error's return value property | 8 |
| [NC-22](#NC-22) | Contract does not follow the Solidity style guide's suggested layout ordering | 5 |
| [NC-23](#NC-23) | Event is missing `indexed` fields | 57 |
| [NC-24](#NC-24) | Variables need not be initialized to zero | 8 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (7)*:
```solidity
File: src/BatchNFTMinter.sol

175:         pauser = newPauser;

```

```solidity
File: src/NFTStaker.sol

211:         pauser = newPauser;

```

```solidity
File: src/NFTStakerDepletion.sol

304:         pauser = newPauser;

313:         migrator = newMigrator;

```

```solidity
File: src/NFTStakerPriceScaled.sol

245:         pauser = newPauser;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

332:         pauser = newPauser;

341:         migrator = newMigrator;

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

109:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (61)*:
```solidity
File: src/BatchNFTMinter.sol

209:         if (to == address(0)) revert Rescue__ZeroRecipient();

302:         if (count == 0) revert BatchMint__ZeroCount();

303:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

316:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

321:             if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

349:         bool qualifies;

352:             qualifies = _nudgeSize != 0 && count >= _nudgeSize;

354:         uint256[] memory snapshot = _snapshotRewards(rewardTokens, minRewards, address(paymentToken), qualifies);

420:         bool qualifies

429:             uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;

456:             if (amount == 0) continue;

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

124:         if (idx == 0) return;

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

403:         if (to == address(0)) revert Rescue__ZeroRecipient();

457:         if (block.timestamp <= lastRewardTime) return;

465:         if (reward > rewardBudget) reward = rewardBudget;

550:                 if (pending > 0) emit Claimed(msg.sender, pending);

568:             if (pending > 0) emit Claimed(msg.sender, pending);

583:             if (paid > 0) emit Claimed(msg.sender, paid);

690:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

734:             if (paid > 0) emit Claimed(account, paid);

757:                 if (pending > 0) emit Claimed(user, pending);

809:             if (reward > rewardBudget) reward = rewardBudget;

818:         if (block.timestamp >= windowEnd) return 0;

833:         if (reward > rewardBudget) reward = rewardBudget;

850:         if (rewardRate == 0) return 0;

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

434:         if (to == address(0)) revert Rescue__ZeroRecipient();

463:             _recomputeScheduleIfActive();

469:         _recomputeScheduleIfActive();

483:         if (poolState == PoolState.Migrating) return;

502:         if (block.timestamp <= lastRewardTime) return;

510:         if (reward > rewardBudget) reward = rewardBudget;

628:                 if (pending > 0) emit Claimed(msg.sender, pending);

642:         _recomputeScheduleIfActive();

653:             if (pending > 0) emit Claimed(msg.sender, pending);

663:         _recomputeScheduleIfActive();

672:             if (paid > 0) emit Claimed(msg.sender, paid);

812:             if (amount > 0) emit MigratedOut(accounts[i], amount, paid);

856:             if (paid > 0) emit Claimed(account, paid);

888:                 if (pending > 0) emit Claimed(user, pending);

957:             if (reward > rewardBudget) reward = rewardBudget;

966:         if (block.timestamp >= windowEnd) return 0;

985:         if (reward > rewardBudget) reward = rewardBudget;

1001:         if (rewardRate == 0) return 0;

```

### <a name="NC-4"></a>[NC-4] Delete rogue `console.log` imports
These shouldn't be deployed in production

*Instances (1)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

5: import {console2} from "forge-std/console2.sol";

```

### <a name="NC-5"></a>[NC-5] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (6)*:
```solidity
File: src/BatchNFTMinter.sol

82: contract BatchNFTMinter is Ownable, Pausable, ReentrancyGuard, IPausable {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

41: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: src/NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: src/NFTStakerDepletion.sol

64: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: src/NFTStakerMigrator.sol

33: contract NFTStakerMigrator is Ownable, ERC1155Holder {

```

```solidity
File: src/NFTStakerPriceScaled.sol

54: contract NFTStakerPriceScaled is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

### <a name="NC-6"></a>[NC-6] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (34)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

269:         require(to != address(0), "InPlace: zero recipient");

282:         require(to != address(0), "InPlace: zero recipient");

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

290:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

334:         require(totalStaked == 0, "NFTStaker: stake outstanding");

342:         require(totalStaked == 0, "NFTStaker: stake outstanding");

351:         require(totalStaked == 0, "NFTStaker: stake outstanding");

352:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

654:         require(poolState == PoolState.Active, "NFTStaker: not active");

682:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

706:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

750:         require(poolState == PoolState.Active, "NFTStaker: not active");

779:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

780:         require(totalStaked == 0, "NFTStaker: stake outstanding");

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

316:         require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");

362:         require(totalStaked == 0, "NFTStaker: stake outstanding");

372:         require(totalStaked == 0, "NFTStaker: stake outstanding");

382:         require(totalStaked == 0, "NFTStaker: stake outstanding");

383:         require(address(newMinter) != address(0), "NFTStaker: zero nft minter");

775:         require(poolState == PoolState.Active, "NFTStaker: not active");

804:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

828:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

881:         require(poolState == PoolState.Active, "NFTStaker: not active");

926:         require(poolState == PoolState.Migrating, "NFTStaker: not migrating");

927:         require(totalStaked == 0, "NFTStaker: stake outstanding");

```

### <a name="NC-7"></a>[NC-7] Events should use parameters to convey information
For example, rather than using `event Paused()` and `event Unpaused()`, use `event PauseState(address indexed whoChangedIt, bool wasPaused, bool isNowPaused)`

*Instances (2)*:
```solidity
File: src/NFTStakerDepletion.sol

264:     event PoolReset();

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

289:     event PoolReset();

```

### <a name="NC-8"></a>[NC-8] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (26)*:
```solidity
File: src/BatchNFTMinter.sol

135:     event NudgeSizeChanged(uint256 newSize);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

89:     event MigratedOut(uint256 userCount, uint256 totalAmount);

90:     event MigratedIn(uint256 userCount, uint256 totalAmount);

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

227:     event Pulled(uint256 inflow, uint256 newBudget);

231:     event StakedIdChanged(uint256 previous, uint256 next);

235:     event DepletionWindowChanged(uint256 previous, uint256 next);

236:     event DispatcherIndexChanged(uint256 previous, uint256 next);

245:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

253:     event MigrationInitiated(uint256 totalStaked);

```

```solidity
File: src/NFTStakerMigrator.sol

46:     event Migrated(uint256 userCount, uint256 totalAmount);

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

248:     event Pulled(uint256 inflow, uint256 newBudget);

253:     event StakedIdChanged(uint256 previous, uint256 next);

255:     event TargetAPYChanged(uint256 previous, uint256 next);

256:     event DispatcherIndexChanged(uint256 previous, uint256 next);

270:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

278:     event MigrationInitiated(uint256 totalStaked);

```

### <a name="NC-9"></a>[NC-9] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (30)*:
```solidity
File: src/BatchNFTMinter.sol

150:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

159:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

166:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

173:     function setPauser(address newPauser) external onlyOwner {
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

330:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);

339:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);

356:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));

361:     function setStakedId(uint256 newId) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit StakedIdChanged(stakedId, newId);

371:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             emit DispatcherIndexChanged(dispatcherIndex, newIndex);

381:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {
             require(totalStaked == 0, "NFTStaker: stake outstanding");
             require(address(newMinter) != address(0), "NFTStaker: zero nft minter");
             emit NFTMinterChanged(address(nftMinter), address(newMinter));

394:     function setTargetAPY(uint256 newAPY) external onlyOwner {
             require(newAPY <= MAX_TARGET_APY, "NFTStaker: APY too high");
             _updatePool();
             emit TargetAPYChanged(targetAPY, newAPY);

```

### <a name="NC-10"></a>[NC-10] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (6)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

1: 
   Current order:
   internal _pauser
   internal _owner
   external run
   
   Suggested order:
   external run
   internal _pauser
   internal _owner

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

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

### <a name="NC-11"></a>[NC-11] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (105)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

68:     function _pauser() internal view returns (address) {

74:     function _owner() internal view returns (address) {

78:     function run() external returns (BatchNFTMinter batch) {

```

```solidity
File: src/BatchNFTMinter.sol

150:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

159:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

166:     function setNudgeSize(uint256 newSize) external onlyOwner {

173:     function setPauser(address newPauser) external onlyOwner {

208:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

452:     function _payRewards(address recipient, address[] calldata rewardTokens, uint256[] memory snapshot) private {

```

```solidity
File: src/INFTStakerMigratable.sol

38:     function batchMigrate(address[] calldata users) external returns (uint256[] memory amounts);

46:     function depositFor(address user, uint256 amount) external;

53:     function userInfo(address user) external view returns (uint256 amount, uint256 rewardDebt);

```

```solidity
File: src/INFTSupply.sol

25:     function totalSupply(uint256 id) external view returns (uint256);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

152:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

186:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

294:     function parkedUserCount() external view returns (uint256) {

299:     function parkedUsersRange(uint256 start, uint256 end) external view returns (address[] memory out) {

315:     function claimableAt(address user) external view returns (uint256) {

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

302:     function setPauser(address newPauser) external onlyOwner {

311:     function setMigrator(address newMigrator) external onlyOwner {

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

333:     function setStakedId(uint256 newId) external onlyOwner {

341:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

350:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

364:     function setDepletionWindow(uint256 months) external onlyOwner {

377:     function topUp(uint256 amount) external onlyOwner {

402:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

539:     function stake(uint256 amount) external nonReentrant whenNotPaused {

560:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

577:     function claim() external nonReentrant whenNotPaused {

593:     function _safePay(uint256 amount) internal returns (uint256) {

603:     function _safePayTo(address account, uint256 amount) internal returns (uint256) {

622:     function emergencyWithdraw() external nonReentrant {

653:     function initiateMigration() external override nonReentrant onlyMigrator {

675:     function batchMigrate(address[] calldata accounts)

720:     function _exitPosition(address account) internal returns (uint256 amount, uint256 paid) {

748:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

794:     function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {

799:     function pendingReward(address account) external view returns (uint256) {

817:     function currentRewardRate() external view returns (uint256) {

825:     function totalDebt() external view returns (uint256) {

839:     function totalBudget() external view returns (uint256) {

849:     function runwaySeconds() external view returns (uint256) {

```

```solidity
File: src/NFTStakerMigrator.sol

81:     function migrate(address[] calldata users) external onlyOwner {

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

330:     function setPauser(address newPauser) external onlyOwner {

339:     function setMigrator(address newMigrator) external onlyOwner {

356:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

361:     function setStakedId(uint256 newId) external onlyOwner {

371:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

381:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

394:     function setTargetAPY(uint256 newAPY) external onlyOwner {

408:     function topUp(uint256 amount) external onlyOwner {

433:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

617:     function stake(uint256 amount) external nonReentrant whenNotPaused {

645:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

666:     function claim() external nonReentrant whenNotPaused {

680:     function _safePay(uint256 amount) internal returns (uint256) {

706:     function _safePayTo(address account, uint256 amount) internal returns (uint256) {

735:     function emergencyWithdraw() external nonReentrant {

774:     function initiateMigration() external override nonReentrant onlyMigrator {

797:     function batchMigrate(address[] calldata accounts)

842:     function _exitPosition(address account) internal returns (uint256 amount, uint256 paid) {

879:     function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {

942:     function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {

947:     function pendingReward(address account) external view returns (uint256) {

965:     function currentRewardRate() external view returns (uint256) {

977:     function totalDebt() external view returns (uint256) {

991:     function totalBudget() external view returns (uint256) {

1000:     function runwaySeconds() external view returns (uint256) {

```

### <a name="NC-12"></a>[NC-12] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (14)*:
```solidity
File: src/BatchNFTMinter.sol

150:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {
             tokenMinter = newMinter;
             emit TokenMinterSet(address(newMinter));

159:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {
             dispatcherIndex = newIndex;
             emit DispatcherIndexSet(newIndex);

166:     function setNudgeSize(uint256 newSize) external onlyOwner {
             nudgeSize = newSize;
             emit NudgeSizeChanged(newSize);

173:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

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

330:     function setPauser(address newPauser) external onlyOwner {
             emit PauserChanged(pauser, newPauser);
             pauser = newPauser;

339:     function setMigrator(address newMigrator) external onlyOwner {
             emit MigratorSet(migrator, newMigrator);
             migrator = newMigrator;

356:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {
             emit DispatcherHookChanged(address(dispatcherHook), address(newHook));
             dispatcherHook = newHook;

```

### <a name="NC-13"></a>[NC-13] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (33)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

78:     function run() external returns (BatchNFTMinter batch) {

```

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

302:     function setPauser(address newPauser) external onlyOwner {

316:     function pause() external onlyPauser {

320:     function unpause() external onlyPauser {

328:     function setDispatcherHook(IUniboostMintDebtHook newHook) external onlyOwner {

333:     function setStakedId(uint256 newId) external onlyOwner {

539:     function stake(uint256 amount) external nonReentrant whenNotPaused {

560:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

577:     function claim() external nonReentrant whenNotPaused {

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

330:     function setPauser(address newPauser) external onlyOwner {

344:     function pause() external onlyPauser {

348:     function unpause() external onlyPauser {

356:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

361:     function setStakedId(uint256 newId) external onlyOwner {

617:     function stake(uint256 amount) external nonReentrant whenNotPaused {

645:     function unstake(uint256 amount) external nonReentrant whenNotPaused {

666:     function claim() external nonReentrant whenNotPaused {

```

### <a name="NC-14"></a>[NC-14] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (19)*:
```solidity
File: src/BatchNFTMinter.sol

147:     /// @notice Owner-gated update of the trusted NFT minter. Setting
         ///         `address(0)` disables `batchMint` (it reverts
         ///         `BatchMint__MinterNotConfigured`).
         function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

155:     /// @notice Owner-gated update of the only dispatcher index `batchMint`
         ///         mints. Setting `0` disables `batchMint` (it reverts
         ///         `BatchMint__DispatcherNotConfigured`). Stays callable while
         ///         paused.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

164:     /// @notice Owner-gated update of the batch-size threshold for the nudge
         ///         payout. Setting `0` disables the feature.
         function setNudgeSize(uint256 newSize) external onlyOwner {

171:     /// @notice Owner-gated update of the pauser address. Setting `address(0)`
         ///         disables pausing. Stays callable while paused.
         function setPauser(address newPauser) external onlyOwner {

190:     /// @notice Owner-only recovery of an arbitrary ERC20.
         /// @dev    **This is NOT a reliable escape hatch.** Under the
         ///         caller-selected nudge model, every ERC20 balance this contract
         ///         holds (except the dispatcher's payment token) is claimable in
         ///         full by the next caller who clears the `nudgeSize` gate and
         ///         lists that token. `rescueERC20` therefore competes with every
         ///         watching bot in the mempool and is a **race the owner will
         ///         usually lose**. It is retained for two cases where it still
         ///         works: while `batchMint` is paused (no caller can claim
         ///         anything), and for tokens no batch has bothered to claim.
         ///         Treat "pause first, then rescue" as the only dependable
         ///         sequence.
         ///
         ///         Owner-trusted (the owner can already zero `nudgeSize` and stop
         ///         all payouts), so no token restriction is needed; an explicit
         ///         `amount` is preferred over a full-balance sweep so it composes
         ///         with the nudge pot. Stays callable while paused (mirrors
         ///         `NFTStaker.emergencyWithdraw`).
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

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

335:     /// @notice Set/rotate the migration orchestrator authorised to call the
         ///         `onlyMigrator` primitives. Setting to `address(0)` disables
         ///         migration. No empty-pool gate — the migrator must be wired
         ///         before `initiateMigration` is called.
         function setMigrator(address newMigrator) external onlyOwner {

367:     /// @notice Update the dispatcher index read from `nftMinter.configs`.
         ///         Guarded by `totalStaked == 0` — a mid-stake swap to a
         ///         different dispatcher could swing APY violently in either
         ///         direction, so the safest policy is to require an empty pool.
         function setDispatcherIndex(uint256 newIndex) external onlyOwner {

378:     /// @notice Swap the `nftMinter` reference. Guarded by
         ///         `totalStaked == 0` for the same reason as `setStakedId` and
         ///         `setDispatcherIndex`.
         function setNFTMinter(INFTSupply newMinter) external onlyOwner {

421:     /// @notice Owner-only recovery of an arbitrary ERC20. Modelled on
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

### <a name="NC-15"></a>[NC-15] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (22)*:
```solidity
File: src/BatchNFTMinter.sol

143:         require(msg.sender == pauser, "BatchNFTMinter: caller is not pauser");

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

245:         require(block.timestamp >= migrationBegin[msg.sender] + migrationTimeout, "InPlace: timeout not elapsed");

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

271:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

276:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

550:                 if (pending > 0) emit Claimed(msg.sender, pending);

568:             if (pending > 0) emit Claimed(msg.sender, pending);

583:             if (paid > 0) emit Claimed(msg.sender, paid);

707:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

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

296:         require(msg.sender == pauser, "NFTStaker: caller is not pauser");

301:         require(msg.sender == migrator, "NFTStaker: caller is not migrator");

628:                 if (pending > 0) emit Claimed(msg.sender, pending);

653:             if (pending > 0) emit Claimed(msg.sender, pending);

672:             if (paid > 0) emit Claimed(msg.sender, paid);

829:         require(users[msg.sender].amount > 0, "NFTStaker: nothing staked");

```

### <a name="NC-16"></a>[NC-16] Constant state variables defined more than once
Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (14)*:
```solidity
File: src/NFTStaker.sol

39:     uint256 public constant ACC_PRECISION = 1e18;

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

50:     uint256 public constant APY_PRECISION = 1e18;

56:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

```solidity
File: src/NFTStakerDepletion.sol

72:     uint256 public constant ACC_PRECISION = 1e18;

77:     uint256 public constant SECONDS_PER_YEAR = 365 days;

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

92:     uint256 public constant ACC_PRECISION = 1e18;

99:     uint256 public constant SECONDS_PER_YEAR = 365 days;

103:     uint256 public constant APY_PRECISION = 1e18;

109:     uint256 public constant MAX_TARGET_APY = 50 * 1e16; // 0.5e18 = 50%

```

### <a name="NC-17"></a>[NC-17] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (7)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

60:     mapping(address => uint256) public parked;

64:     mapping(address => uint256) public migrationBegin;

73:     mapping(address => uint256) private _parkedIndex;

```

```solidity
File: src/NFTStaker.sol

139:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NFTStakerDepletion.sol

182:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NFTStakerPriceScaled.sol

170:     mapping(address => UserInfo) public users;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

200:     mapping(address => UserInfo) public users;

```

### <a name="NC-18"></a>[NC-18] `address`s shouldn't be hard-coded
It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (1)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

51:     address internal constant TOKEN_MINTER = 0x39Af088408e815844c567037C157B31d48d2E10F;

```

### <a name="NC-19"></a>[NC-19] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (5)*:
```solidity
File: src/BatchNFTMinter.sol

173:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

330:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="NC-20"></a>[NC-20] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (4)*:
```solidity
File: src/NFTStakerDepletion.sol

713:     /// @dev Shared migration exit for one user: settles+pays their pending
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

790:     /// @notice `INFTStakerMigratable` accessor for the public `users` mapping.
         ///         Returns `user`'s currently-credited ERC1155 position and
         ///         reward-debt bookkeeping value. Used by the in-place migrator to
         ///         snapshot credited principal around a `depositFor`.
         function userInfo(address user) external view override returns (uint256 amount, uint256 rewardDebt) {
             UserInfo memory info = users[user];
             return (info.amount, info.rewardDebt);
         }

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

835:     /// @dev Shared migration exit for one user: settles+pays their pending
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

938:     /// @notice `INFTStakerMigratable` accessor for the public `users` mapping.
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

*Instances (8)*:
```solidity
File: src/BatchNFTMinter.sol

209:         if (to == address(0)) revert Rescue__ZeroRecipient();

302:         if (count == 0) revert BatchMint__ZeroCount();

303:         if (recipient == address(0)) revert BatchMint__ZeroRecipient();

312:             revert BatchMint__MinterNotConfigured();

316:         if (_dispatcherIndex == 0) revert BatchMint__DispatcherNotConfigured();

321:             if (dispatcher == address(0)) revert BatchMint__DispatcherNotConfigured();

```

```solidity
File: src/NFTStakerDepletion.sol

403:         if (to == address(0)) revert Rescue__ZeroRecipient();

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

434:         if (to == address(0)) revert Rescue__ZeroRecipient();

```

### <a name="NC-22"></a>[NC-22] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (5)*:
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
   VariableDeclaration.pauser
   ErrorDefinition.BatchMint__ZeroCount
   ErrorDefinition.BatchMint__ZeroRecipient
   ErrorDefinition.BatchMint__RewardTokenIsPaymentToken
   ErrorDefinition.BatchMint__ArrayLengthMismatch
   ErrorDefinition.BatchMint__MinterNotConfigured
   ErrorDefinition.BatchMint__DispatcherNotConfigured
   ErrorDefinition.Rescue__ZeroRecipient
   ErrorDefinition.BatchMint__RewardBelowMinimum
   EventDefinition.NudgeSizeChanged
   EventDefinition.NudgePaid
   EventDefinition.TokenMinterSet
   EventDefinition.DispatcherIndexSet
   EventDefinition.Rescued
   EventDefinition.PauserChanged
   ModifierDefinition.onlyPauser
   FunctionDefinition.setTokenMinter
   FunctionDefinition.setDispatcherIndex
   FunctionDefinition.setNudgeSize
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.rescueERC20
   FunctionDefinition.batchMint
   FunctionDefinition._snapshotRewards
   FunctionDefinition._payRewards
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.DUST_THRESHOLD
   VariableDeclaration.tokenMinter
   VariableDeclaration.dispatcherIndex
   VariableDeclaration.nudgeSize
   VariableDeclaration.pauser
   ErrorDefinition.BatchMint__ZeroCount
   ErrorDefinition.BatchMint__ZeroRecipient
   ErrorDefinition.BatchMint__RewardTokenIsPaymentToken
   ErrorDefinition.BatchMint__ArrayLengthMismatch
   ErrorDefinition.BatchMint__MinterNotConfigured
   ErrorDefinition.BatchMint__DispatcherNotConfigured
   ErrorDefinition.Rescue__ZeroRecipient
   ErrorDefinition.BatchMint__RewardBelowMinimum
   EventDefinition.NudgeSizeChanged
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
   FunctionDefinition.setPauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.rescueERC20
   FunctionDefinition.batchMint
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

### <a name="NC-23"></a>[NC-23] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (57)*:
```solidity
File: src/BatchNFTMinter.sol

135:     event NudgeSizeChanged(uint256 newSize);

136:     event NudgePaid(address indexed recipient, address indexed token, uint256 amount);

139:     event Rescued(address indexed token, address indexed to, uint256 amount);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

89:     event MigratedOut(uint256 userCount, uint256 totalAmount);

90:     event MigratedIn(uint256 userCount, uint256 totalAmount);

91:     event TimedOutClaim(address indexed user, uint256 amount);

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
File: src/NFTStakerMigrator.sol

46:     event Migrated(uint256 userCount, uint256 totalAmount);

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

239:     event Staked(address indexed user, uint256 amount);

240:     event Unstaked(address indexed user, uint256 amount);

241:     event Claimed(address indexed user, uint256 amount);

242:     event EmergencyWithdrawn(address indexed user, uint256 amount);

248:     event Pulled(uint256 inflow, uint256 newBudget);

251:     event ToppedUp(address indexed from, uint256 amount, uint256 newBudget);

253:     event StakedIdChanged(uint256 previous, uint256 next);

255:     event TargetAPYChanged(uint256 previous, uint256 next);

256:     event DispatcherIndexChanged(uint256 previous, uint256 next);

270:     event ScheduleRecomputed(uint256 totalNFTValue, uint256 availableValue, uint256 newRate, uint256 newWindowEnd);

273:     event Rescued(address indexed token, address indexed to, uint256 amount);

278:     event MigrationInitiated(uint256 totalStaked);

282:     event MigratedOut(address indexed user, uint256 amount, uint256 reward);

285:     event UserMigrated(address indexed user, uint256 amount, uint256 reward);

287:     event DepositedFor(address indexed user, uint256 amount);

```

### <a name="NC-24"></a>[NC-24] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (8)*:
```solidity
File: src/InPlaceNFTStakerMigrator.sol

157:         for (uint256 i = 0; i < users.length; i++) {

197:         for (uint256 i = 0; i < sliceLen; i++) {

210:         for (uint256 i = 0; i < sliceLen; i++) {

308:         for (uint256 i = 0; i < out.length; i++) {

```

```solidity
File: src/NFTStakerDepletion.sol

686:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: src/NFTStakerMigrator.sol

85:         for (uint256 i = 0; i < amounts.length; i++) {

100:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

808:         for (uint256 i = 0; i < accounts.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 6 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 17 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 7 |
| [L-4](#L-4) | Division by zero not prevented | 16 |
| [L-5](#L-5) | Owner can renounce while system is paused | 5 |
| [L-6](#L-6) | Possible rounding issue | 8 |
| [L-7](#L-7) | Loss of precision | 50 |
| [L-8](#L-8) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 8 |
| [L-9](#L-9) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 7 |
| [L-10](#L-10) | Sweeping may break accounting if tokens with multiple addresses are used | 5 |
| [L-11](#L-11) | A year is not always 365 days | 4 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (6)*:
```solidity
File: src/BatchNFTMinter.sol

82: contract BatchNFTMinter is Ownable, Pausable, ReentrancyGuard, IPausable {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

41: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

```

```solidity
File: src/NFTStaker.sol

31: contract NFTStaker is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

```solidity
File: src/NFTStakerDepletion.sol

64: contract NFTStakerDepletion is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable, INFTStakerMigratable {

```

```solidity
File: src/NFTStakerMigrator.sol

33: contract NFTStakerMigrator is Ownable, ERC1155Holder {

```

```solidity
File: src/NFTStakerPriceScaled.sol

54: contract NFTStakerPriceScaled is Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (17)*:
```solidity
File: src/BatchNFTMinter.sol

210:         token.safeTransfer(to, amount);

357:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

383:             paymentToken.safeTransfer(msg.sender, remaining);

458:             IERC20(rewardToken).safeTransfer(recipient, amount);

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

270:         token.safeTransfer(to, amount);

```

```solidity
File: src/NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

512:             rewardToken.safeTransfer(msg.sender, amount);

```

```solidity
File: src/NFTStakerDepletion.sol

380:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

406:             token.safeTransfer(to, amount);

410:             token.safeTransfer(to, amount);

606:             rewardToken.safeTransfer(account, amount);

```

```solidity
File: src/NFTStakerPriceScaled.sol

315:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

551:             rewardToken.safeTransfer(msg.sender, amount);

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

411:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

437:             token.safeTransfer(to, amount);

441:             token.safeTransfer(to, amount);

709:             rewardToken.safeTransfer(account, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (7)*:
```solidity
File: src/BatchNFTMinter.sol

175:         pauser = newPauser;

```

```solidity
File: src/NFTStaker.sol

211:         pauser = newPauser;

```

```solidity
File: src/NFTStakerDepletion.sol

304:         pauser = newPauser;

313:         migrator = newMigrator;

```

```solidity
File: src/NFTStakerPriceScaled.sol

245:         pauser = newPauser;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

332:         pauser = newPauser;

341:         migrator = newMigrator;

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (16)*:
```solidity
File: src/NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

418:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

619:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

```solidity
File: src/NFTStakerDepletion.sol

469:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

525:         uint256 newRate = (windowSeconds == 0) ? 0 : budget / windowSeconds;

810:             acc += (reward * ACC_PRECISION) / totalStaked;

852:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

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

514:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

604:         uint256 runway = (newRate == 0) ? 0 : budget / newRate;

958:             acc += (reward * ACC_PRECISION) / totalStaked;

1003:         return (rewardToken.balanceOf(address(this)) + pending) / rewardRate;

```

### <a name="L-5"></a>[L-5] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (5)*:
```solidity
File: src/BatchNFTMinter.sol

173:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStaker.sol

209:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletion.sol

302:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaled.sol

243:     function setPauser(address newPauser) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

330:     function setPauser(address newPauser) external onlyOwner {

```

### <a name="L-6"></a>[L-6] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (8)*:
```solidity
File: src/NFTStaker.sol

333:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

575:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerDepletion.sol

469:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

810:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerPriceScaled.sol

367:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

614:             acc += (reward * ACC_PRECISION) / totalStaked;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

514:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

958:             acc += (reward * ACC_PRECISION) / totalStaked;

```

### <a name="L-7"></a>[L-7] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (50)*:
```solidity
File: src/BatchNFTMinter.sol

382:         if (remaining / DUST_THRESHOLD != 0) {

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

469:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

547:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

556:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

565:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

572:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

580:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

585:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

626:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

728:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

754:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

763:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

810:             acc += (reward * ACC_PRECISION) / totalStaked;

812:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

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

514:             accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;

603:         uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;

625:             uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

634:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

650:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

657:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

669:         uint256 pending = (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

674:         user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

739:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

850:         uint256 pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;

885:             uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;

894:         info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

958:             acc += (reward * ACC_PRECISION) / totalStaked;

960:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

```

### <a name="L-8"></a>[L-8] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (8)*:
```solidity
File: script/DeployBatchNFTMinter.s.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/BatchNFTMinter.sol

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

*Instances (7)*:
```solidity
File: src/BatchNFTMinter.sol

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

### <a name="L-10"></a>[L-10] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (5)*:
```solidity
File: src/BatchNFTMinter.sol

208:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerDepletion.sol

402:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

433:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

### <a name="L-11"></a>[L-11] A year is not always 365 days
On leap years, the number of days is 366, so calculations during those years will return the wrong value

*Instances (4)*:
```solidity
File: src/NFTStaker.sol

46:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: src/NFTStakerDepletion.sol

77:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: src/NFTStakerPriceScaled.sol

69:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

99:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 5 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 64 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (5)*:
```solidity
File: src/BatchNFTMinter.sol

357:         paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

```

```solidity
File: src/NFTStaker.sol

281:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NFTStakerDepletion.sol

380:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NFTStakerPriceScaled.sol

315:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: src/NFTStakerPriceScaledMigrateReady.sol

411:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (64)*:
```solidity
File: src/BatchNFTMinter.sol

82: contract BatchNFTMinter is Ownable, Pausable, ReentrancyGuard, IPausable {

85:     constructor(address initialOwner) Ownable(initialOwner) {}

150:     function setTokenMinter(ITokenMinterV2 newMinter) external onlyOwner {

159:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

166:     function setNudgeSize(uint256 newSize) external onlyOwner {

173:     function setPauser(address newPauser) external onlyOwner {

208:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: src/InPlaceNFTStakerMigrator.sol

41: contract InPlaceNFTStakerMigrator is Ownable, ReentrancyGuard, ERC1155Holder {

99:     ) Ownable(initialOwner) {

140:     function initiateMigration() external onlyOwner {

152:     function migrateOut(address[] calldata users) external onlyOwner nonReentrant {

186:     function migrateIn(uint256 start, uint256 end) external onlyOwner nonReentrant {

268:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

281:     function rescueERC1155(uint256 id, address to, uint256 amount) external onlyOwner {

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

778:     function finalizeAndReset() external onlyOwner {

```

```solidity
File: src/NFTStakerMigrator.sol

33: contract NFTStakerMigrator is Ownable, ERC1155Holder {

54:     ) Ownable(initialOwner) {

70:     function initiateMigration() external onlyOwner {

81:     function migrate(address[] calldata users) external onlyOwner {

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

78:     Ownable,

313:     ) Ownable(_initialOwner) {

330:     function setPauser(address newPauser) external onlyOwner {

339:     function setMigrator(address newMigrator) external onlyOwner {

356:     function setDispatcherHook(IBalancerPoolerMintDebtHook newHook) external onlyOwner {

361:     function setStakedId(uint256 newId) external onlyOwner {

371:     function setDispatcherIndex(uint256 newIndex) external onlyOwner {

381:     function setNFTMinter(INFTSupply newMinter) external onlyOwner {

394:     function setTargetAPY(uint256 newAPY) external onlyOwner {

408:     function topUp(uint256 amount) external onlyOwner {

417:     function pullAndRefresh() external onlyOwner {

433:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {

925:     function finalizeAndReset() external onlyOwner {

```

