# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 34 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 36 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 5 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 2 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 18 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 213 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 86 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 26 |
| [GAS-9](#GAS-9) | Stack variable used as a cheaper cache for a state variable is only used once | 9 |
| [GAS-10](#GAS-10) | State variables only set in the constructor should be declared `immutable` | 11 |
| [GAS-11](#GAS-11) | Functions guaranteed to revert when called by normal users can be marked `payable` | 26 |
| [GAS-12](#GAS-12) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 6 |
| [GAS-13](#GAS-13) | Using `private` rather than `public` for constants, saves gas | 9 |
| [GAS-14](#GAS-14) | Splitting require() statements that use && saves gas | 2 |
| [GAS-15](#GAS-15) | Superfluous event fields | 2 |
| [GAS-16](#GAS-16) | Use of `this` instead of marking as `public` an `external` function | 1 |
| [GAS-17](#GAS-17) | Increments/decrements can be unchecked in for-loops | 6 |
| [GAS-18](#GAS-18) | Use != 0 instead of > 0 for unsigned integer comparison | 69 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (34)*:
```solidity
File: MigratorV1V2.sol

131:             sumUSDC += _usdc[i];

132:             sumDep += _deposits[i];

133:             sumPending += _phUSD[i];

```

```solidity
File: MigratorV2V3.sol

363:         unclaimable[address(token)][user] += amount;

```

```solidity
File: Phlimbo.sol

293:         rewardBalance += amount;

333:         user.amount += amount;

338:         totalStaked += amount;

429:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

441:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

512:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

541:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV2.sol

306:         rewardBalance += amount;

343:         userDetails.amount += amount;

347:         totalStaked += amount;

460:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

473:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

533:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

553:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV3.sol

412:         promoRewardBalance += amount;

498:                     unclaimablePromoOf[address(promoToken)][staker] += pending;

499:                     totalUnclaimableOf[address(promoToken)] += pending;

636:         rewardBalance += amount;

673:         userDetails.amount += amount;

678:         totalStaked += amount;

802:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

815:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

839:                 accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

876:                 unclaimableStableOf[beneficiary] += pendingRewardAmount;

877:                 totalUnclaimableStable += pendingRewardAmount;

902:                     unclaimablePromoOf[address(promoToken)][beneficiary] += pendingPromoAmount;

903:                     totalUnclaimableOf[address(promoToken)] += pendingPromoAmount;

945:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

970:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

1001:                 _accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (36)*:
```solidity
File: MigratorV1V2.sol

87:         require(_usdc != address(0), "Invalid USDC address");

88:         require(_phUSD != address(0), "Invalid phUSD address");

89:         require(_phlimboV2 != address(0), "Invalid phlimboV2 address");

```

```solidity
File: MigratorV2V3.sol

122:         require(_phlimboV2 != address(0), "Invalid phlimboV2 address");

123:         require(_phlimboV3 != address(0), "Invalid phlimboV3 address");

124:         require(_phUSD != address(0), "Invalid phUSD address");

125:         require(_rewardToken != address(0), "Invalid reward token address");

246:             address(promoToken) != address(0) ? promoToken.balanceOf(address(this)) : 0;

263:             ? promoToken.balanceOf(address(this)) - promoBefore

271:             _forward(promoToken, user, promoRewards);

327:             address(promoToken) != address(0) ? promoToken.balanceOf(address(this)) : 0;

```

```solidity
File: Phlimbo.sol

143:         require(_phUSD != address(0), "Invalid phUSD address");

144:         require(_rewardToken != address(0), "Invalid reward token address");

312:         if (recipient == address(0)) {

```

```solidity
File: PhlimboV2.sol

150:         require(_phUSD != address(0), "Invalid phUSD address");

151:         require(_rewardToken != address(0), "Invalid reward token address");

325:         require(user != address(0), "Invalid user");

353:         if (address(hook) != address(0)) {

364:         require(user != address(0), "Invalid user");

398:         if (address(hook) != address(0)) {

408:         require(user != address(0), "Invalid user");

429:         if (address(hook) != address(0)) {

```

```solidity
File: PhlimboV3.sol

223:         require(_phUSD != address(0), "Invalid phUSD address");

224:         require(_rewardToken != address(0), "Invalid reward token address");

354:         if (address(promoToken) != address(0)) {

375:         require(token != address(0) && token != address(phUSD) && token != address(rewardToken), "Invalid promo token");

535:         IERC20 retiredToken = promoToken;

656:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

689:             hook.onDeposit(msg.sender, user, amount);

700:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

740:             hook.onWithdraw(msg.sender, user, actualWithdrawAmount);

750:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

772:             hook.onClaim(msg.sender, user, pendingPhUSDAmount, pendingRewardAmount);

835:             uint256 potentialPromo = (promoRewardPerSecond * timeElapsed) / PRECISION;

892:             uint256 pendingPromoAmount = (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;

992:             address(promoToken) != address(0) && promoPhase != PromoPhase.Flushing && block.timestamp > lastRewardTime

```

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (5)*:
```solidity
File: MigratorV1V2.sol

76:     bool public seeded;

```

```solidity
File: MigratorV2V3.sol

104:     bool public seeded;

```

```solidity
File: Phlimbo.sol

51:     bool public apySetInProgress;

```

```solidity
File: PhlimboV2.sol

60:     bool public apySetInProgress;

```

```solidity
File: PhlimboV3.sol

73:     bool public apySetInProgress;

```

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (2)*:
```solidity
File: MigratorV1V2.sol

125:         for (uint256 i = 0; i < _users.length; i++) {

```

```solidity
File: MigratorV2V3.sol

149:         for (uint256 i = 0; i < _users.length; i++) {

```

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (18)*:
```solidity
File: MigratorV1V2.sol

192:         emit SettleProgress(settleIterator, totalUSDC, totalPHUSD_pending);

238:         emit MigrateProgress(migrateIterator, totalPHUSD_deposited);

```

```solidity
File: MigratorV2V3.sol

184:         uint256 end = i + maxIterations;

293:     // ========================== UNCLAIMABLE ==========================

```

```solidity
File: Phlimbo.sol

201:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

441:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV2.sol

208:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

474:         }

```

```solidity
File: PhlimboV3.sol

281:         emit DepletionDurationUpdated(oldDuration, _duration);

499:                     totalUnclaimableOf[address(promoToken)] += pending;

500:                     emit PromoClaimFailed(address(promoToken), staker, pending);

502:             }

818:         // Promo stream: capped linear depletion on the promo's OWN window, mirroring

842:         }

900:                     emit PromoClaimed(user, pendingPromoAmount);

903:                     totalUnclaimableOf[address(promoToken)] += pendingPromoAmount;

904:                     emit PromoClaimFailed(address(promoToken), beneficiary, pendingPromoAmount);

907:         }

```

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (213)*:
```solidity
File: IFlax.sol

4: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

```

```solidity
File: MigratorV1V2.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

6: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

7: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

8: import "./IFlax.sol";

9: import "./interfaces/IPhlimboV2.sol";

10: import "./interfaces/IMigratorV1V2.sol";

125:         for (uint256 i = 0; i < _users.length; i++) {

131:             sumUSDC += _usdc[i];

132:             sumDep += _deposits[i];

133:             sumPending += _phUSD[i];

166:         uint256 end = i + maxIterations;

170:         for (; i < end; i++) {

176:                 totalUSDC -= usdcAmt;

182:                 totalPHUSD_pending -= phusdAmt;

187:             settleIterator = -1;

217:         uint256 end = i + maxIterations;

221:         for (; i < end; i++) {

228:                 totalPHUSD_deposited -= dep;

233:             migrateIterator = -1;

```

```solidity
File: MigratorV2V3.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

6: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

7: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

8: import "./IFlax.sol";

9: import "./interfaces/IPhlimboV2.sol";

10: import "./interfaces/IPhlimboV3.sol";

11: import "./interfaces/IMigratorV2V3.sol";

145:         require(!seeded || migrateIterator == -1, "Pass in progress");

149:         for (uint256 i = 0; i < _users.length; i++) {

184:         uint256 end = i + maxIterations;

188:         for (; i < end; i++) {

193:             if (amount == 0) continue; // exited or already migrated

215:             migrateIterator = -1;

260:         uint256 phUSDRewards = phUSD.balanceOf(address(this)) - phUSDBefore;

261:         uint256 stableRewards = rewardToken.balanceOf(address(this)) - stableBefore;

263:             ? promoToken.balanceOf(address(this)) - promoBefore

288:         uint256 next = idx + 1;

289:         migrateIterator = next == users.length ? int256(-1) : int256(next);

363:         unclaimable[address(token)][user] += amount;

```

```solidity
File: Phlimbo.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/Pausable.sol";

6: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import "./IFlax.sol";

10: import "./interfaces/IPhlimbo.sol";

11: import {IPausable} from "lib/mutable/pauser/src/interfaces/IPausable.sol";

167:             block.number > pendingAPYBlockNumber + 100 ||

201:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

264:         user.amount -= amount;

267:         totalStaked -= amount;

293:         rewardBalance += amount;

296:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

333:         user.amount += amount;

334:         user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

335:         user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

338:         totalStaked += amount;

361:         uint256 remaining = user.amount - amount;

372:         user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

373:         user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

376:         totalStaked -= actualWithdrawAmount;

396:         user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

397:         user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

417:         uint256 timeElapsed = block.timestamp - lastRewardTime;

420:         uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

429:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

432:             rewardBalance -= toDistribute;

435:             rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

440:             uint256 phUSDReward = timeElapsed * phUSDPerSecond;

441:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

459:         uint256 pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) /

460:             PRECISION -

467:         uint256 pendingRewardAmount = (userDetails.amount * accStablePerShare) /

468:             PRECISION -

493:             (totalStaked * desiredAPYBps) /

494:             10000 /

510:             uint256 timeElapsed = block.timestamp - lastRewardTime;

511:             uint256 phUSDReward = timeElapsed * phUSDPerSecond;

512:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

516:             (userDetails.amount * _accPhUSDPerShare) /

517:             PRECISION -

531:             uint256 timeElapsed = block.timestamp - lastRewardTime;

532:             uint256 potentialReward = (rewardPerSecond * timeElapsed) /

541:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

546:             (userDetails.amount * _accStablePerShare) /

547:             PRECISION -

```

```solidity
File: PhlimboV2.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/Pausable.sol";

6: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import "./IFlax.sol";

10: import "./interfaces/IPhlimboV2.sol";

11: import "./interfaces/IPhlimboHook.sol";

12: import {IPausable} from "lib/mutable/pauser/src/interfaces/IPausable.sol";

174:                         block.number > pendingAPYBlockNumber + 100 ||

208:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

285:         user.amount -= amount;

286:         totalStaked -= amount;

306:         rewardBalance += amount;

309:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

343:         userDetails.amount += amount;

344:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

345:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

347:         totalStaked += amount;

375:         uint256 remaining = userDetails.amount - amount;

385:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

386:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

388:         totalStaked -= actualWithdrawAmount;

419:             pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

420:             pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

426:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

427:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

452:         uint256 timeElapsed = block.timestamp - lastRewardTime;

454:         uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

460:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

463:             rewardBalance -= toDistribute;

472:             uint256 phUSDReward = timeElapsed * phUSDPerSecond;

473:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

493:         uint256 pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

498:         uint256 pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

518:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

531:             uint256 timeElapsed = block.timestamp - lastRewardTime;

532:             uint256 phUSDReward = timeElapsed * phUSDPerSecond;

533:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

536:         return (userDetails.amount * _accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

547:             uint256 timeElapsed = block.timestamp - lastRewardTime;

548:             uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

553:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

557:         return (userDetails.amount * _accStablePerShare) / PRECISION - userDetails.stableDebt;

```

```solidity
File: PhlimboV3.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/Pausable.sol";

6: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

10: import "./IFlax.sol";

11: import "./interfaces/IPhlimboV3.sol";

12: import "./interfaces/IPhlimboHook.sol";

13: import {IPausable} from "lib/mutable/pauser/src/interfaces/IPausable.sol";

246:         bool isPreview = !apySetInProgress || block.number > pendingAPYBlockNumber + 100 || bps != pendingAPYBps;

279:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

385:         require(IERC20(token).balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

390:         promoRewardPerSecond = (amount * PRECISION) / duration;

410:         require(promoToken.balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

412:         promoRewardBalance += amount;

413:         promoRewardPerSecond = (promoRewardBalance * PRECISION) / promoDepletionDuration;

431:         promoRewardPerSecond = (promoRewardBalance * PRECISION) / duration;

474:         uint256 end = cursor + maxIterations;

479:         for (; cursor < end; cursor++) {

483:             uint256 pending = (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;

487:             userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

498:                     unclaimablePromoOf[address(promoToken)][staker] += pending;

499:                     totalUnclaimableOf[address(promoToken)] += pending;

538:         uint256 leftover = balance > banked ? balance - banked : 0;

584:         totalUnclaimableOf[token] -= amount;

607:         totalUnclaimableStable -= amount;

636:         rewardBalance += amount;

639:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

673:         userDetails.amount += amount;

674:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

675:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

676:         userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

678:         totalStaked += amount;

710:         uint256 remaining = userDetails.amount - amount;

720:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

721:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

722:         userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

724:         totalStaked -= actualWithdrawAmount;

760:             pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

761:             pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

767:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

768:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

769:         userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

794:         uint256 timeElapsed = block.timestamp - lastRewardTime;

796:         uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

802:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

805:             rewardBalance -= toDistribute;

814:             uint256 phUSDReward = timeElapsed * phUSDPerSecond;

815:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

835:             uint256 potentialPromo = (promoRewardPerSecond * timeElapsed) / PRECISION;

839:                 accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

840:                 promoRewardBalance -= promoToDistribute;

861:         uint256 pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

866:         uint256 pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

876:                 unclaimableStableOf[beneficiary] += pendingRewardAmount;

877:                 totalUnclaimableStable += pendingRewardAmount;

892:             uint256 pendingPromoAmount = (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;

902:                     unclaimablePromoOf[address(promoToken)][beneficiary] += pendingPromoAmount;

903:                     totalUnclaimableOf[address(promoToken)] += pendingPromoAmount;

930:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

943:             uint256 timeElapsed = block.timestamp - lastRewardTime;

944:             uint256 phUSDReward = timeElapsed * phUSDPerSecond;

945:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

948:         return (userDetails.amount * _accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

964:             uint256 timeElapsed = block.timestamp - lastRewardTime;

965:             uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

970:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

974:         return (userDetails.amount * _accStablePerShare) / PRECISION - userDetails.stableDebt;

995:             uint256 timeElapsed = block.timestamp - lastRewardTime;

996:             uint256 potentialPromo = (promoRewardPerSecond * timeElapsed) / PRECISION;

1001:                 _accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

1005:         return (userDetails.amount * _accPromoPerShare) / PRECISION - userDetails.promoDebt;

```

```solidity
File: interfaces/IPhlimbo.sol

4: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import "../IFlax.sol";

```

```solidity
File: interfaces/IPhlimboV2.sol

4: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import "../IFlax.sol";

6: import "./IPhlimboHook.sol";

```

```solidity
File: interfaces/IPhlimboV3.sol

4: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import "../IFlax.sol";

6: import "./IPhlimboHook.sol";

```

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (86)*:
```solidity
File: MigratorV1V2.sol

87:         require(_usdc != address(0), "Invalid USDC address");

88:         require(_phUSD != address(0), "Invalid phUSD address");

89:         require(_phlimboV2 != address(0), "Invalid phlimboV2 address");

112:         require(!seeded, "Already seeded");

113:         require(_users.length > 0, "Empty users");

156:         require(seeded, "Not seeded");

157:         require(settleIterator >= 0, "Settlement complete");

158:         require(maxIterations > 0, "maxIterations==0");

159:         require(usdc.balanceOf(address(this)) == totalUSDC, "USDC balance mismatch");

204:         require(seeded, "Not seeded");

205:         require(migrateIterator >= 0, "Migration complete");

206:         require(maxIterations > 0, "maxIterations==0");

```

```solidity
File: MigratorV2V3.sol

122:         require(_phlimboV2 != address(0), "Invalid phlimboV2 address");

123:         require(_phlimboV3 != address(0), "Invalid phlimboV3 address");

124:         require(_phUSD != address(0), "Invalid phUSD address");

125:         require(_rewardToken != address(0), "Invalid reward token address");

145:         require(!seeded || migrateIterator == -1, "Pass in progress");

146:         require(_users.length > 0, "Empty users");

173:         require(seeded, "Not seeded");

174:         require(migrateIterator >= 0, "Migration complete");

175:         require(maxIterations > 0, "maxIterations==0");

236:         require(msg.sender == address(this), "Only self");

285:         require(seeded && migrateIterator >= 0, "Nothing to skip");

304:         require(amount > 0, "Nothing to claim");

```

```solidity
File: Phlimbo.sol

143:         require(_phUSD != address(0), "Invalid phUSD address");

144:         require(_rewardToken != address(0), "Invalid reward token address");

145:         require(_depletionDuration > 0, "Duration must be > 0");

192:         require(_duration > 0, "Duration must be > 0");

211:         require(msg.sender == pauser, "Only pauser can unpause");

249:         require(msg.sender == pauser, "Only pauser can pause");

260:         require(user.amount >= amount, "Insufficient balance");

261:         require(amount > 0, "Amount must be greater than 0");

284:         require(amount > 0, "Amount must be greater than 0");

309:         require(amount >= MINIMUM_STAKE, "Below minimum stake");

353:         require(user.amount >= amount, "Insufficient balance");

```

```solidity
File: PhlimboV2.sol

150:         require(_phUSD != address(0), "Invalid phUSD address");

151:         require(_rewardToken != address(0), "Invalid reward token address");

152:         require(_depletionDuration > 0, "Duration must be > 0");

197:         require(_duration > 0, "Duration must be > 0");

217:         require(msg.sender == pauser, "Only pauser can unpause");

271:         require(msg.sender == pauser, "Only pauser can pause");

282:         require(user.amount >= amount, "Insufficient balance");

283:         require(amount > 0, "Amount must be greater than 0");

299:         require(amount > 0, "Amount must be greater than 0");

324:         require(amount >= MINIMUM_STAKE, "Below minimum stake");

325:         require(user != address(0), "Invalid user");

326:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

364:         require(user != address(0), "Invalid user");

365:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

368:         require(userDetails.amount >= amount, "Insufficient balance");

408:         require(user != address(0), "Invalid user");

409:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

```

```solidity
File: PhlimboV3.sol

223:         require(_phUSD != address(0), "Invalid phUSD address");

224:         require(_rewardToken != address(0), "Invalid reward token address");

225:         require(_depletionDuration > 0, "Duration must be > 0");

268:         require(_duration > 0, "Duration must be > 0");

292:         require(msg.sender == pauser || msg.sender == owner(), "Only pauser or owner can unpause");

293:         require(promoPhase != PromoPhase.Flushing, "Cannot unpause while flushing");

374:         require(promoPhase == PromoPhase.None, "Promo phase must be None");

375:         require(token != address(0) && token != address(phUSD) && token != address(rewardToken), "Invalid promo token");

376:         require(amount > 0, "Amount must be greater than 0");

377:         require(duration > 0, "Duration must be > 0");

385:         require(IERC20(token).balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

402:         require(promoPhase == PromoPhase.Active, "Promo phase must be Active");

403:         require(amount > 0, "Amount must be greater than 0");

410:         require(promoToken.balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

423:         require(promoPhase == PromoPhase.Active, "Promo phase must be Active");

424:         require(duration > 0, "Duration must be > 0");

449:         require(promoPhase == PromoPhase.Active, "Promo phase must be Active");

470:         require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

531:         require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

532:         require(flushCursor == _stakers.length(), "Flush incomplete");

533:         require(leftoverRecipient != address(0), "Invalid recipient");

559:         require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

582:         require(amount > 0, "Nothing to claim");

605:         require(amount > 0, "Nothing to claim");

619:         require(msg.sender == pauser || msg.sender == owner(), "Only pauser or owner can pause");

629:         require(amount > 0, "Amount must be greater than 0");

654:         require(amount >= MINIMUM_STAKE, "Below minimum stake");

655:         require(user != address(0), "Invalid user");

656:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

699:         require(user != address(0), "Invalid user");

700:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

703:         require(userDetails.amount >= amount, "Insufficient balance");

749:         require(user != address(0), "Invalid user");

750:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

```

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (26)*:
```solidity
File: MigratorV1V2.sol

159:         require(usdc.balanceOf(address(this)) == totalUSDC, "USDC balance mismatch");

161:             phUSD.balanceOf(address(this)) == totalPHUSD_deposited,

208:             phUSD.balanceOf(address(this)) == totalPHUSD_deposited,

251:         uint256 usdcBal = usdc.balanceOf(address(this));

252:         uint256 phUSDBal = phUSD.balanceOf(address(this));

```

```solidity
File: MigratorV2V3.sol

243:         uint256 phUSDBefore = phUSD.balanceOf(address(this));

244:         uint256 stableBefore = rewardToken.balanceOf(address(this));

246:             address(promoToken) != address(0) ? promoToken.balanceOf(address(this)) : 0;

260:         uint256 phUSDRewards = phUSD.balanceOf(address(this)) - phUSDBefore;

261:         uint256 stableRewards = rewardToken.balanceOf(address(this)) - stableBefore;

263:             ? promoToken.balanceOf(address(this)) - promoBefore

320:         uint256 phUSDBal = phUSD.balanceOf(address(this));

321:         uint256 rewardBal = rewardToken.balanceOf(address(this));

327:             address(promoToken) != address(0) ? promoToken.balanceOf(address(this)) : 0;

```

```solidity
File: Phlimbo.sol

228:         uint256 phUSDBalance = phUSD.balanceOf(address(this));

229:         uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));

```

```solidity
File: PhlimboV2.sol

252:         uint256 phUSDBalance = phUSD.balanceOf(address(this));

253:         uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));

```

```solidity
File: PhlimboV3.sol

345:         uint256 phUSDBalance = phUSD.balanceOf(address(this));

346:         uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));

355:             uint256 promoBalance = promoToken.balanceOf(address(this));

383:         uint256 balanceBefore = IERC20(token).balanceOf(address(this));

385:         require(IERC20(token).balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

408:         uint256 balanceBefore = promoToken.balanceOf(address(this));

410:         require(promoToken.balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

537:         uint256 balance = retiredToken.balanceOf(address(this));

```

### <a name="GAS-9"></a>[GAS-9] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (9)*:
```solidity
File: Phlimbo.sol

179:             uint256 oldAPY = desiredAPYBps;

197:         uint256 oldDuration = depletionDuration;

```

```solidity
File: PhlimboV2.sol

184:             uint256 oldAPY = desiredAPYBps;

202:         uint256 oldDuration = depletionDuration;

233:         address oldMigrator = migrator;

```

```solidity
File: PhlimboV3.sol

255:             uint256 oldAPY = desiredAPYBps;

273:         uint256 oldDuration = depletionDuration;

310:         migrator = _migrator;

429:         uint256 oldDuration = promoDepletionDuration;

```

### <a name="GAS-10"></a>[GAS-10] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (11)*:
```solidity
File: MigratorV1V2.sol

91:         usdc = IERC20(_usdc);

92:         phUSD = IFlax(_phUSD);

93:         phlimboV2 = IPhlimboV2(_phlimboV2);

```

```solidity
File: MigratorV2V3.sol

127:         phlimboV2 = IPhlimboV2(_phlimboV2);

128:         phlimboV3 = IPhlimboV3(_phlimboV3);

130:         rewardToken = IERC20(_rewardToken);

```

```solidity
File: Phlimbo.sol

147:         phUSD = IFlax(_phUSD);

148:         rewardToken = IERC20(_rewardToken);

```

```solidity
File: PhlimboV2.sol

154:         phUSD = IFlax(_phUSD);

155:         rewardToken = IERC20(_rewardToken);

```

```solidity
File: PhlimboV3.sol

228:         rewardToken = IERC20(_rewardToken);

```

### <a name="GAS-11"></a>[GAS-11] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (26)*:
```solidity
File: MigratorV1V2.sol

249:     function withdrawAll() external onlyOwner {

```

```solidity
File: MigratorV2V3.sol

144:     function seedUsers(address[] calldata _users) external onlyOwner {

284:     function skipCurrent() external onlyOwner {

318:     function withdrawAll() external onlyOwner {

```

```solidity
File: Phlimbo.sol

164:     function setDesiredAPY(uint256 bps) external onlyOwner {

191:     function setDepletionDuration(uint256 _duration) external onlyOwner {

219:     function setPauser(address _pauser) external onlyOwner {

227:     function emergencyTransfer(address recipient) external onlyOwner {

```

```solidity
File: PhlimboV2.sol

172:     function setDesiredAPY(uint256 bps) external onlyOwner {

196:     function setDepletionDuration(uint256 _duration) external onlyOwner {

224:     function setPauser(address _pauser) external onlyOwner {

232:     function setMigrator(address _migrator) external onlyOwner {

242:     function setHook(address _hook) external onlyOwner {

251:     function emergencyTransfer(address recipient) external onlyOwner {

```

```solidity
File: PhlimboV3.sol

245:     function setDesiredAPY(uint256 bps) external onlyOwner {

267:     function setDepletionDuration(uint256 _duration) external onlyOwner {

300:     function setPauser(address _pauser) external onlyOwner {

308:     function setMigrator(address _migrator) external onlyOwner {

318:     function setHook(address _hook) external onlyOwner {

344:     function emergencyTransfer(address recipient) external onlyOwner {

373:     function startPromotion(address token, uint256 amount, uint256 duration) external onlyOwner whenNotPaused {

401:     function topUpPromotion(uint256 amount) external onlyOwner {

422:     function setPromoDepletionDuration(uint256 duration) external onlyOwner {

448:     function beginFlush() external onlyOwner {

530:     function finalizePromotion(address leftoverRecipient) external onlyOwner {

558:     function abortFlush() external onlyOwner {

```

### <a name="GAS-12"></a>[GAS-12] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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
File: MigratorV1V2.sol

125:         for (uint256 i = 0; i < _users.length; i++) {

170:         for (; i < end; i++) {

221:         for (; i < end; i++) {

```

```solidity
File: MigratorV2V3.sol

149:         for (uint256 i = 0; i < _users.length; i++) {

188:         for (; i < end; i++) {

```

```solidity
File: PhlimboV3.sol

479:         for (; cursor < end; cursor++) {

```

### <a name="GAS-13"></a>[GAS-13] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (9)*:
```solidity
File: Phlimbo.sol

77:     uint256 public constant PRECISION = 1e18;

80:     uint256 public constant SECONDS_PER_YEAR = 365 days;

83:     uint256 public constant MINIMUM_STAKE = 1e15;

```

```solidity
File: PhlimboV2.sol

94:     uint256 public constant PRECISION = 1e18;

97:     uint256 public constant SECONDS_PER_YEAR = 365 days;

100:     uint256 public constant MINIMUM_STAKE = 1e15;

```

```solidity
File: PhlimboV3.sol

170:     uint256 public constant PRECISION = 1e18;

173:     uint256 public constant SECONDS_PER_YEAR = 365 days;

176:     uint256 public constant MINIMUM_STAKE = 1e15;

```

### <a name="GAS-14"></a>[GAS-14] Splitting require() statements that use && saves gas

*Instances (2)*:
```solidity
File: MigratorV2V3.sol

285:         require(seeded && migrateIterator >= 0, "Nothing to skip");

```

```solidity
File: PhlimboV3.sol

375:         require(token != address(0) && token != address(phUSD) && token != address(rewardToken), "Invalid promo token");

```

### <a name="GAS-15"></a>[GAS-15] Superfluous event fields
`block.timestamp` and `block.number` are added to event information by default so adding them manually wastes gas

*Instances (2)*:
```solidity
File: PhlimboV2.sol

132:     event IntendedSetAPY(uint256 indexed proposedAPY, uint256 blockNumber, address indexed proposer);

```

```solidity
File: PhlimboV3.sol

209:     event IntendedSetAPY(uint256 indexed proposedAPY, uint256 blockNumber, address indexed proposer);

```

### <a name="GAS-16"></a>[GAS-16] Use of `this` instead of marking as `public` an `external` function
Using `this.` is like making an expensive external call. Consider marking the called function as public

*Saves around 2000 gas per instance*

*Instances (1)*:
```solidity
File: MigratorV2V3.sol

202:             try this.migrateOne(user, amount) {

```

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

*Instances (6)*:
```solidity
File: MigratorV1V2.sol

125:         for (uint256 i = 0; i < _users.length; i++) {

170:         for (; i < end; i++) {

221:         for (; i < end; i++) {

```

```solidity
File: MigratorV2V3.sol

149:         for (uint256 i = 0; i < _users.length; i++) {

188:         for (; i < end; i++) {

```

```solidity
File: PhlimboV3.sol

479:         for (; cursor < end; cursor++) {

```

### <a name="GAS-18"></a>[GAS-18] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (69)*:
```solidity
File: MigratorV1V2.sol

113:         require(_users.length > 0, "Empty users");

158:         require(maxIterations > 0, "maxIterations==0");

174:             if (usdcAmt > 0) {

178:             if (phusdAmt > 0) {

206:         require(maxIterations > 0, "maxIterations==0");

223:             if (dep > 0) {

254:         if (usdcBal > 0) {

257:         if (phUSDBal > 0) {

```

```solidity
File: MigratorV2V3.sol

146:         require(_users.length > 0, "Empty users");

175:         require(maxIterations > 0, "maxIterations==0");

304:         require(amount > 0, "Nothing to claim");

329:         if (phUSDBal > 0) {

332:         if (rewardBal > 0) {

335:         if (promoBal > 0) {

```

```solidity
File: Phlimbo.sol

145:         require(_depletionDuration > 0, "Duration must be > 0");

192:         require(_duration > 0, "Duration must be > 0");

231:         if (phUSDBalance > 0) {

234:         if (rewardTokenBalance > 0) {

261:         require(amount > 0, "Amount must be greater than 0");

284:         require(amount > 0, "Amount must be greater than 0");

321:         if (user.amount > 0) {

365:         if (remaining > 0 && remaining < MINIMUM_STAKE) {

428:         if (toDistribute > 0) {

439:         if (phUSDPerSecond > 0) {

462:         if (pendingPhUSDAmount > 0) {

470:         if (pendingRewardAmount > 0) {

475:         if (pendingPhUSDAmount > 0 || pendingRewardAmount > 0) {

540:             if (toDistribute > 0) {

```

```solidity
File: PhlimboV2.sol

152:         require(_depletionDuration > 0, "Duration must be > 0");

197:         require(_duration > 0, "Duration must be > 0");

255:         if (phUSDBalance > 0) {

258:         if (rewardTokenBalance > 0) {

283:         require(amount > 0, "Amount must be greater than 0");

299:         require(amount > 0, "Amount must be greater than 0");

336:         if (userDetails.amount > 0) {

379:         if (remaining > 0 && remaining < MINIMUM_STAKE) {

418:         if (userDetails.amount > 0) {

459:         if (toDistribute > 0) {

471:         if (phUSDPerSecond > 0) {

494:         if (pendingPhUSDAmount > 0) {

499:         if (pendingRewardAmount > 0) {

503:         if (pendingPhUSDAmount > 0 || pendingRewardAmount > 0) {

552:             if (toDistribute > 0) {

```

```solidity
File: PhlimboV3.sol

225:         require(_depletionDuration > 0, "Duration must be > 0");

268:         require(_duration > 0, "Duration must be > 0");

348:         if (phUSDBalance > 0) {

351:         if (rewardTokenBalance > 0) {

356:             if (promoBalance > 0) {

376:         require(amount > 0, "Amount must be greater than 0");

377:         require(duration > 0, "Duration must be > 0");

403:         require(amount > 0, "Amount must be greater than 0");

424:         require(duration > 0, "Duration must be > 0");

489:             if (pending > 0) {

539:         if (leftover > 0) {

582:         require(amount > 0, "Nothing to claim");

605:         require(amount > 0, "Nothing to claim");

629:         require(amount > 0, "Amount must be greater than 0");

666:         if (userDetails.amount > 0) {

714:         if (remaining > 0 && remaining < MINIMUM_STAKE) {

759:         if (userDetails.amount > 0) {

801:         if (toDistribute > 0) {

813:         if (phUSDPerSecond > 0) {

838:             if (promoToDistribute > 0) {

862:         if (pendingPhUSDAmount > 0) {

867:         if (pendingRewardAmount > 0) {

882:         if (pendingPhUSDAmount > 0 || pendingRewardAmount > 0) {

893:             if (pendingPromoAmount > 0) {

969:             if (toDistribute > 0) {

1000:             if (promoToDistribute > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 5 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 6 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 30 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 5 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 46 |
| [NC-6](#NC-6) | Event is never emitted | 3 |
| [NC-7](#NC-7) | Event missing indexed field | 20 |
| [NC-8](#NC-8) | Events that mark critical parameter changes should contain both the old and the new value | 15 |
| [NC-9](#NC-9) | Function ordering does not follow the Solidity style guide | 4 |
| [NC-10](#NC-10) | Functions should not be longer than 50 lines | 153 |
| [NC-11](#NC-11) | Lack of checks in setters | 7 |
| [NC-12](#NC-12) | Missing Event for critical parameters change | 3 |
| [NC-13](#NC-13) | Incomplete NatSpec: `@param` is missing on actually documented functions | 26 |
| [NC-14](#NC-14) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 13 |
| [NC-15](#NC-15) | Constant state variables defined more than once | 9 |
| [NC-16](#NC-16) | Consider using named mappings | 7 |
| [NC-17](#NC-17) | Owner can renounce while system is paused | 3 |
| [NC-18](#NC-18) | Adding a `return` statement when the function defines a named return variable, is redundant | 9 |
| [NC-19](#NC-19) | Contract does not follow the Solidity style guide's suggested layout ordering | 3 |
| [NC-20](#NC-20) | Use Underscores for Number Literals (add an underscore every 3 digits) | 3 |
| [NC-21](#NC-21) | Event is missing `indexed` fields | 47 |
| [NC-22](#NC-22) | Variables need not be initialized to zero | 2 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (5)*:
```solidity
File: Phlimbo.sol

220:         pauser = _pauser;

```

```solidity
File: PhlimboV2.sol

225:         pauser = _pauser;

234:         migrator = _migrator;

```

```solidity
File: PhlimboV3.sol

304:     /**

311:         emit MigratorSet(oldMigrator, _migrator);

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (6)*:
```solidity
File: Phlimbo.sol

167:             block.number > pendingAPYBlockNumber + 100 ||

494:             10000 /

```

```solidity
File: PhlimboV2.sol

174:                         block.number > pendingAPYBlockNumber + 100 ||

518:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

```

```solidity
File: PhlimboV3.sol

246:         bool isPreview = !apySetInProgress || block.number > pendingAPYBlockNumber + 100 || bps != pendingAPYBps;

930:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (30)*:
```solidity
File: MigratorV1V2.sol

8: import "./IFlax.sol";

49:     using SafeERC20 for IFlax;

54:     IFlax public immutable phUSD;

92:         phUSD = IFlax(_phUSD);

168:         if (end > len) end = len;

219:         if (end > len) end = len;

```

```solidity
File: MigratorV2V3.sol

8: import "./IFlax.sol";

91:     using SafeERC20 for IFlax;

97:     IFlax public immutable phUSD;

129:         phUSD = IFlax(_phUSD);

186:         if (end > len) end = len;

193:             if (amount == 0) continue; // exited or already migrated

361:         if (amount == 0) return;

362:         if (_tryTransfer(token, user, amount)) return;

```

```solidity
File: Phlimbo.sol

9: import "./IFlax.sol";

29:     IFlax public phUSD;

147:         phUSD = IFlax(_phUSD);

```

```solidity
File: PhlimboV2.sol

9: import "./IFlax.sol";

38:     IFlax public phUSD;

154:         phUSD = IFlax(_phUSD);

```

```solidity
File: PhlimboV3.sol

10: import "./IFlax.sol";

51:     IFlax public phUSD;

227:         phUSD = IFlax(_phUSD);

991:         if (

```

```solidity
File: interfaces/IPhlimbo.sol

5: import "../IFlax.sol";

139:     function phUSD() external view returns (IFlax);

```

```solidity
File: interfaces/IPhlimboV2.sol

5: import "../IFlax.sol";

175:     function phUSD() external view returns (IFlax);

```

```solidity
File: interfaces/IPhlimboV3.sol

5: import "../IFlax.sol";

373:     function phUSD() external view returns (IFlax);

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (5)*:
```solidity
File: MigratorV1V2.sol

47: contract MigratorV1V2 is Ownable, ReentrancyGuard, IMigratorV1V2 {

```

```solidity
File: MigratorV2V3.sol

89: contract MigratorV2V3 is Ownable, ReentrancyGuard, IMigratorV2V3 {

```

```solidity
File: Phlimbo.sol

23: contract PhlimboEA is Ownable, Pausable, ReentrancyGuard, IPhlimbo, IPausable {

```

```solidity
File: PhlimboV2.sol

32: contract PhlimboV2 is Ownable, Pausable, ReentrancyGuard, IPhlimboV2, IPausable {

```

```solidity
File: PhlimboV3.sol

44: contract PhlimboV3 is Ownable, Pausable, ReentrancyGuard, IPhlimboV3, IPausable {

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (46)*:
```solidity
File: MigratorV1V2.sol

156:         require(seeded, "Not seeded");

158:         require(maxIterations > 0, "maxIterations==0");

161:             phUSD.balanceOf(address(this)) == totalPHUSD_deposited,

204:         require(seeded, "Not seeded");

206:         require(maxIterations > 0, "maxIterations==0");

208:             phUSD.balanceOf(address(this)) == totalPHUSD_deposited,

```

```solidity
File: Phlimbo.sol

145:         require(_depletionDuration > 0, "Duration must be > 0");

192:         require(_duration > 0, "Duration must be > 0");

260:         require(user.amount >= amount, "Insufficient balance");

261:         require(amount > 0, "Amount must be greater than 0");

284:         require(amount > 0, "Amount must be greater than 0");

353:         require(user.amount >= amount, "Insufficient balance");

```

```solidity
File: PhlimboV2.sol

152:         require(_depletionDuration > 0, "Duration must be > 0");

197:         require(_duration > 0, "Duration must be > 0");

282:         require(user.amount >= amount, "Insufficient balance");

283:         require(amount > 0, "Amount must be greater than 0");

299:         require(amount > 0, "Amount must be greater than 0");

325:         require(user != address(0), "Invalid user");

326:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

364:         require(user != address(0), "Invalid user");

365:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

368:         require(userDetails.amount >= amount, "Insufficient balance");

408:         require(user != address(0), "Invalid user");

409:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

```

```solidity
File: PhlimboV3.sol

225:         require(_depletionDuration > 0, "Duration must be > 0");

268:         require(_duration > 0, "Duration must be > 0");

376:         require(amount > 0, "Amount must be greater than 0");

377:         require(duration > 0, "Duration must be > 0");

385:         require(IERC20(token).balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

402:         require(promoPhase == PromoPhase.Active, "Promo phase must be Active");

403:         require(amount > 0, "Amount must be greater than 0");

410:         require(promoToken.balanceOf(address(this)) - balanceBefore == amount, "Fee-on-transfer not supported");

423:         require(promoPhase == PromoPhase.Active, "Promo phase must be Active");

424:         require(duration > 0, "Duration must be > 0");

449:         require(promoPhase == PromoPhase.Active, "Promo phase must be Active");

470:         require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

531:         require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

559:         require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

583:         unclaimablePromoOf[token][msg.sender] = 0;

606:         unclaimableStableOf[msg.sender] = 0;

631:         // Update pool FIRST to accrue pending rewards before adding new balance

656:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

700:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

702:         UserInfo storage userDetails = userInfo[user];

750:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

752:         _updatePool();

```

### <a name="NC-6"></a>[NC-6] Event is never emitted
The following are defined but never emitted. They can be removed to make the code cleaner.

*Instances (3)*:
```solidity
File: Phlimbo.sol

115:     event RateUpdated(uint256 newRate, uint256 newBalance);

```

```solidity
File: PhlimboV2.sol

126:     event RateUpdated(uint256 newRate, uint256 newBalance);

```

```solidity
File: PhlimboV3.sol

203:     event RateUpdated(uint256 newRate, uint256 newBalance);

```

### <a name="NC-7"></a>[NC-7] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (20)*:
```solidity
File: Phlimbo.sol

108:     event RewardCollected(

115:     event RateUpdated(uint256 newRate, uint256 newBalance);

118:     event DepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

128:     event DesiredAPYUpdated(uint256 oldAPY, uint256 newAPY);

```

```solidity
File: PhlimboV2.sol

123:     event RewardCollected(uint256 amount, uint256 newRewardBalance, uint256 newRate);

126:     event RateUpdated(uint256 newRate, uint256 newBalance);

129:     event DepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

135:     event DesiredAPYUpdated(uint256 oldAPY, uint256 newAPY);

```

```solidity
File: PhlimboV3.sol

200:     event RewardCollected(uint256 amount, uint256 newRewardBalance, uint256 newRate);

203:     event RateUpdated(uint256 newRate, uint256 newBalance);

206:     event DepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

212:     event DesiredAPYUpdated(uint256 oldAPY, uint256 newAPY);

```

```solidity
File: interfaces/IMigratorV1V2.sol

19:     event Seeded(

32:     event SettleProgress(int256 iterator, uint256 remainingUSDC, uint256 remainingPHUSDPending);

39:     event MigrateProgress(int256 iterator, uint256 remainingDepositPHUSD);

```

```solidity
File: interfaces/IMigratorV2V3.sol

21:     event Seeded(uint256 userCount);

47:     event MigrateProgress(int256 iterator, uint256 userCount);

```

```solidity
File: interfaces/IPhlimboV3.sol

83:     event PromotionToppedUp(uint256 amount, uint256 newBalance, uint256 newRate);

88:     event PromoDepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

102:     event FlushProgress(uint256 cursor, uint256 total);

```

### <a name="NC-8"></a>[NC-8] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (15)*:
```solidity
File: MigratorV1V2.sol

155:     function settleDebt(uint256 maxIterations) external nonReentrant {
             require(seeded, "Not seeded");
             require(settleIterator >= 0, "Settlement complete");
             require(maxIterations > 0, "maxIterations==0");
             require(usdc.balanceOf(address(this)) == totalUSDC, "USDC balance mismatch");
             require(
                 phUSD.balanceOf(address(this)) == totalPHUSD_deposited,
                 "phUSD balance mismatch"
             );
     
             uint256 i = uint256(settleIterator);
             uint256 end = i + maxIterations;
             uint256 len = users.length;
             if (end > len) end = len;
     
             for (; i < end; i++) {
                 uint256 usdcAmt = usdcOwed[i];
                 uint256 phusdAmt = phUSDOwed[i];
     
                 if (usdcAmt > 0) {
                     usdc.safeTransfer(users[i], usdcAmt);
                     totalUSDC -= usdcAmt;
                 }
                 if (phusdAmt > 0) {
                     // Mint authority prerequisite: phUSD-token owner must grant this
                     // migrator the canMint role before this line can execute.
                     phUSD.mint(users[i], phusdAmt);
                     totalPHUSD_pending -= phusdAmt;
                 }
             }
     
             if (i == len) {
                 settleIterator = -1;
             } else {
                 settleIterator = int256(i);
             }
     
             emit SettleProgress(settleIterator, totalUSDC, totalPHUSD_pending);

```

```solidity
File: Phlimbo.sol

164:     function setDesiredAPY(uint256 bps) external onlyOwner {
             // Check if we should treat this as a preview or commit
             bool isPreview = !apySetInProgress ||
                 block.number > pendingAPYBlockNumber + 100 ||
                 bps != pendingAPYBps;
     
             if (isPreview) {
                 // PREVIEW BRANCH: Emit intent, store pending state, no actual change
                 emit IntendedSetAPY(bps, block.number, msg.sender);
                 pendingAPYBps = bps;
                 pendingAPYBlockNumber = block.number;
                 apySetInProgress = true;
             } else {
                 // COMMIT BRANCH: Update actual APY, emit confirmation, reset state
                 _updatePool();
                 uint256 oldAPY = desiredAPYBps;
                 desiredAPYBps = bps;
                 _updatePhUSDEmissionRate();
                 emit DesiredAPYUpdated(oldAPY, bps);

164:     function setDesiredAPY(uint256 bps) external onlyOwner {
             // Check if we should treat this as a preview or commit
             bool isPreview = !apySetInProgress ||
                 block.number > pendingAPYBlockNumber + 100 ||
                 bps != pendingAPYBps;
     
             if (isPreview) {
                 // PREVIEW BRANCH: Emit intent, store pending state, no actual change
                 emit IntendedSetAPY(bps, block.number, msg.sender);

191:     function setDepletionDuration(uint256 _duration) external onlyOwner {
             require(_duration > 0, "Duration must be > 0");
     
             // Accrue pending rewards with old rate before changing duration
             _updatePool();
     
             uint256 oldDuration = depletionDuration;
             depletionDuration = _duration;
     
             // Recalculate rate with new duration
             rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
     
             emit DepletionDurationUpdated(oldDuration, _duration);

```

```solidity
File: PhlimboV2.sol

172:     function setDesiredAPY(uint256 bps) external onlyOwner {
             bool isPreview = !apySetInProgress ||
                             block.number > pendingAPYBlockNumber + 100 ||
                             bps != pendingAPYBps;
     
             if (isPreview) {
                 emit IntendedSetAPY(bps, block.number, msg.sender);
                 pendingAPYBps = bps;
                 pendingAPYBlockNumber = block.number;
                 apySetInProgress = true;
             } else {
                 _updatePool();
                 uint256 oldAPY = desiredAPYBps;
                 desiredAPYBps = bps;
                 _updatePhUSDEmissionRate();
                 emit DesiredAPYUpdated(oldAPY, bps);

172:     function setDesiredAPY(uint256 bps) external onlyOwner {
             bool isPreview = !apySetInProgress ||
                             block.number > pendingAPYBlockNumber + 100 ||
                             bps != pendingAPYBps;
     
             if (isPreview) {
                 emit IntendedSetAPY(bps, block.number, msg.sender);

196:     function setDepletionDuration(uint256 _duration) external onlyOwner {
             require(_duration > 0, "Duration must be > 0");
     
             // Accrue pending rewards with old rate before changing duration
             _updatePool();
     
             uint256 oldDuration = depletionDuration;
             depletionDuration = _duration;
     
             // Recalculate rate with new duration. This recompute stays in V2 because the
             // window has explicitly changed; the bug fix only removes the recompute from
             // _updatePool() (which fires on every user interaction).
             rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
     
             emit DepletionDurationUpdated(oldDuration, _duration);

232:     function setMigrator(address _migrator) external onlyOwner {
             address oldMigrator = migrator;
             migrator = _migrator;
             emit MigratorSet(oldMigrator, _migrator);

242:     function setHook(address _hook) external onlyOwner {
             address oldHook = address(hook);
             hook = IPhlimboHook(_hook);
             emit HookSet(oldHook, _hook);

```

```solidity
File: PhlimboV3.sol

245:     function setDesiredAPY(uint256 bps) external onlyOwner {
             bool isPreview = !apySetInProgress || block.number > pendingAPYBlockNumber + 100 || bps != pendingAPYBps;
     
             if (isPreview) {
                 emit IntendedSetAPY(bps, block.number, msg.sender);
                 pendingAPYBps = bps;
                 pendingAPYBlockNumber = block.number;
                 apySetInProgress = true;
             } else {
                 _updatePool();
                 uint256 oldAPY = desiredAPYBps;
                 desiredAPYBps = bps;
                 _updatePhUSDEmissionRate();
                 emit DesiredAPYUpdated(oldAPY, bps);

245:     function setDesiredAPY(uint256 bps) external onlyOwner {
             bool isPreview = !apySetInProgress || block.number > pendingAPYBlockNumber + 100 || bps != pendingAPYBps;
     
             if (isPreview) {
                 emit IntendedSetAPY(bps, block.number, msg.sender);

267:     function setDepletionDuration(uint256 _duration) external onlyOwner {
             require(_duration > 0, "Duration must be > 0");
     
             // Accrue pending rewards with old rate before changing duration
             _updatePool();
     
             uint256 oldDuration = depletionDuration;
             depletionDuration = _duration;
     
             // Recalculate rate with new duration. This recompute stays in V2 because the
             // window has explicitly changed; the bug fix only removes the recompute from
             // _updatePool() (which fires on every user interaction).
             rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;
     
             emit DepletionDurationUpdated(oldDuration, _duration);

308:     function setMigrator(address _migrator) external onlyOwner {
             address oldMigrator = migrator;
             migrator = _migrator;
             emit MigratorSet(oldMigrator, _migrator);

318:     function setHook(address _hook) external onlyOwner {
             address oldHook = address(hook);
             hook = IPhlimboHook(_hook);
             emit HookSet(oldHook, _hook);
         }

422:     function setPromoDepletionDuration(uint256 duration) external onlyOwner {
             require(promoPhase == PromoPhase.Active, "Promo phase must be Active");
             require(duration > 0, "Duration must be > 0");
     
             // Accrue at the old rate over the old window first.
             _updatePool();
     
             uint256 oldDuration = promoDepletionDuration;
             promoDepletionDuration = duration;
             promoRewardPerSecond = (promoRewardBalance * PRECISION) / duration;
     
             emit PromoDepletionDurationUpdated(oldDuration, duration);

```

### <a name="NC-9"></a>[NC-9] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (4)*:
```solidity
File: MigratorV2V3.sol

1: 
   Current order:
   external seedUsers
   external migrate
   external migrateOne
   external skipCurrent
   external claimUnclaimable
   external withdrawAll
   internal _tryTransfer
   internal _forward
   external userCount
   
   Suggested order:
   external seedUsers
   external migrate
   external migrateOne
   external skipCurrent
   external claimUnclaimable
   external withdrawAll
   external userCount
   internal _tryTransfer
   internal _forward

```

```solidity
File: Phlimbo.sol

1: 
   Current order:
   external setDesiredAPY
   external setDepletionDuration
   public unpause
   external setPauser
   external emergencyTransfer
   public pause
   external pauseWithdraw
   external collectReward
   external stake
   external withdraw
   external claim
   internal _updatePool
   internal _claimRewards
   internal _updatePhUSDEmissionRate
   external pendingPhUSD
   external pendingStable
   external getPoolInfo
   external getPendingAPYInfo
   
   Suggested order:
   external setDesiredAPY
   external setDepletionDuration
   external setPauser
   external emergencyTransfer
   external pauseWithdraw
   external collectReward
   external stake
   external withdraw
   external claim
   external pendingPhUSD
   external pendingStable
   external getPoolInfo
   external getPendingAPYInfo
   public unpause
   public pause
   internal _updatePool
   internal _claimRewards
   internal _updatePhUSDEmissionRate

```

```solidity
File: PhlimboV2.sol

1: 
   Current order:
   external setDesiredAPY
   external setDepletionDuration
   public unpause
   external setPauser
   external setMigrator
   external setHook
   external emergencyTransfer
   public pause
   external pauseWithdraw
   external collectReward
   external stake
   external withdraw
   external claim
   internal _updatePool
   internal _claimRewards
   internal _updatePhUSDEmissionRate
   external pendingPhUSD
   external pendingStable
   external getPoolInfo
   external getPendingAPYInfo
   
   Suggested order:
   external setDesiredAPY
   external setDepletionDuration
   external setPauser
   external setMigrator
   external setHook
   external emergencyTransfer
   external pauseWithdraw
   external collectReward
   external stake
   external withdraw
   external claim
   external pendingPhUSD
   external pendingStable
   external getPoolInfo
   external getPendingAPYInfo
   public unpause
   public pause
   internal _updatePool
   internal _claimRewards
   internal _updatePhUSDEmissionRate

```

```solidity
File: PhlimboV3.sol

1: 
   Current order:
   external setDesiredAPY
   external setDepletionDuration
   public unpause
   external setPauser
   external setMigrator
   external setHook
   external emergencyTransfer
   external startPromotion
   external topUpPromotion
   external setPromoDepletionDuration
   external beginFlush
   external batchClaim
   external finalizePromotion
   external abortFlush
   external claimUnclaimablePromo
   external claimUnclaimableStable
   public pause
   external collectReward
   external stake
   external withdraw
   external claim
   internal _updatePool
   internal _claimRewards
   internal _tryTransfer
   internal _updatePhUSDEmissionRate
   external pendingPhUSD
   external pendingStable
   external pendingPromo
   external getPromoInfo
   external stakerCount
   external stakerAt
   external getPoolInfo
   external getPendingAPYInfo
   
   Suggested order:
   external setDesiredAPY
   external setDepletionDuration
   external setPauser
   external setMigrator
   external setHook
   external emergencyTransfer
   external startPromotion
   external topUpPromotion
   external setPromoDepletionDuration
   external beginFlush
   external batchClaim
   external finalizePromotion
   external abortFlush
   external claimUnclaimablePromo
   external claimUnclaimableStable
   external collectReward
   external stake
   external withdraw
   external claim
   external pendingPhUSD
   external pendingStable
   external pendingPromo
   external getPromoInfo
   external stakerCount
   external stakerAt
   external getPoolInfo
   external getPendingAPYInfo
   public unpause
   public pause
   internal _updatePool
   internal _claimRewards
   internal _tryTransfer
   internal _updatePhUSDEmissionRate

```

### <a name="NC-10"></a>[NC-10] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (153)*:
```solidity
File: IFlax.sol

16:     function mint(address recipient, uint256 amount) external;

17:     function burn(address holder, uint256 amount) external;

18:     function authorizedMinters(address minter) external view returns (MinterInfo memory);

19:     function mintVersion() external view returns (uint256);

```

```solidity
File: MigratorV1V2.sol

155:     function settleDebt(uint256 maxIterations) external nonReentrant {

203:     function migrateDeposits(uint256 maxIterations) external nonReentrant {

267:     function userCount() external view returns (uint256) {

```

```solidity
File: MigratorV2V3.sol

144:     function seedUsers(address[] calldata _users) external onlyOwner {

172:     function migrate(uint256 maxIterations) external nonReentrant {

235:     function migrateOne(address user, uint256 amount) external {

302:     function claimUnclaimable(address token) external nonReentrant {

350:     function _tryTransfer(IERC20 token, address to, uint256 amount) internal returns (bool success) {

360:     function _forward(IERC20 token, address user, uint256 amount) internal {

370:     function userCount() external view returns (uint256) {

```

```solidity
File: Phlimbo.sol

164:     function setDesiredAPY(uint256 bps) external onlyOwner {

191:     function setDepletionDuration(uint256 _duration) external onlyOwner {

219:     function setPauser(address _pauser) external onlyOwner {

227:     function emergencyTransfer(address recipient) external onlyOwner {

258:     function pauseWithdraw(uint256 amount) external whenPaused {

283:     function collectReward(uint256 amount) external nonReentrant {

308:     function stake(uint256 amount, address recipient) external whenNotPaused {

351:     function withdraw(uint256 amount) external whenNotPaused {

505:     function pendingPhUSD(address user) external view returns (uint256) {

526:     function pendingStable(address user) external view returns (uint256) {

```

```solidity
File: PhlimboV2.sol

172:     function setDesiredAPY(uint256 bps) external onlyOwner {

196:     function setDepletionDuration(uint256 _duration) external onlyOwner {

224:     function setPauser(address _pauser) external onlyOwner {

232:     function setMigrator(address _migrator) external onlyOwner {

242:     function setHook(address _hook) external onlyOwner {

251:     function emergencyTransfer(address recipient) external onlyOwner {

280:     function pauseWithdraw(uint256 amount) external whenPaused {

298:     function collectReward(uint256 amount) external nonReentrant {

323:     function stake(uint256 amount, address user) external whenNotPaused nonReentrant {

363:     function withdraw(uint256 amount, address user) external whenNotPaused nonReentrant {

407:     function claim(address user) external whenNotPaused nonReentrant {

486:     function _claimRewards(address user, address beneficiary) internal {

526:     function pendingPhUSD(address user) external view returns (uint256) {

542:     function pendingStable(address user) external view returns (uint256) {

582:     function getPendingAPYInfo() external view returns (

```

```solidity
File: PhlimboV3.sol

245:     function setDesiredAPY(uint256 bps) external onlyOwner {

267:     function setDepletionDuration(uint256 _duration) external onlyOwner {

300:     function setPauser(address _pauser) external onlyOwner {

308:     function setMigrator(address _migrator) external onlyOwner {

318:     function setHook(address _hook) external onlyOwner {

344:     function emergencyTransfer(address recipient) external onlyOwner {

373:     function startPromotion(address token, uint256 amount, uint256 duration) external onlyOwner whenNotPaused {

401:     function topUpPromotion(uint256 amount) external onlyOwner {

422:     function setPromoDepletionDuration(uint256 duration) external onlyOwner {

469:     function batchClaim(uint256 maxIterations) external nonReentrant {

530:     function finalizePromotion(address leftoverRecipient) external onlyOwner {

580:     function claimUnclaimablePromo(address token) external nonReentrant {

603:     function claimUnclaimableStable() external nonReentrant {

628:     function collectReward(uint256 amount) external nonReentrant {

653:     function stake(uint256 amount, address user) external whenNotPaused nonReentrant {

698:     function withdraw(uint256 amount, address user) external whenNotPaused nonReentrant {

748:     function claim(address user) external whenNotPaused nonReentrant {

854:     function _claimRewards(address user, address beneficiary) internal {

916:     function _tryTransfer(IERC20 token, address to, uint256 amount) internal returns (bool success) {

938:     function pendingPhUSD(address user) external view returns (uint256) {

959:     function pendingStable(address user) external view returns (uint256) {

985:     function pendingPromo(address user) external view returns (uint256) {

1036:     function stakerCount() external view returns (uint256) {

1043:     function stakerAt(uint256 index) external view returns (address) {

```

```solidity
File: interfaces/IMigratorV1V2.sol

69:     function settleDebt(uint256 maxIterations) external;

75:     function migrateDeposits(uint256 maxIterations) external;

85:     function userCount() external view returns (uint256);

```

```solidity
File: interfaces/IMigratorV2V3.sol

106:     function seedUsers(address[] calldata _users) external;

129:     function migrateOne(address user, uint256 amount) external;

148:     function claimUnclaimable(address token) external;

164:     function unclaimable(address token, address user) external view returns (uint256);

169:     function userCount() external view returns (uint256);

```

```solidity
File: interfaces/IPhlimbo.sol

55:     function setDepletionDuration(uint256 _duration) external;

67:     function emergencyTransfer(address recipient) external;

92:     function stake(uint256 amount, address recipient) external;

112:     function pendingPhUSD(address user) external view returns (uint256);

119:     function pendingStable(address user) external view returns (uint256);

140:     function rewardToken() external view returns (IERC20);

141:     function desiredAPYBps() external view returns (uint256);

142:     function phUSDPerSecond() external view returns (uint256);

143:     function rewardBalance() external view returns (uint256);

144:     function depletionDuration() external view returns (uint256);

145:     function rewardPerSecond() external view returns (uint256);

146:     function lastRewardTime() external view returns (uint256);

147:     function accPhUSDPerShare() external view returns (uint256);

148:     function accStablePerShare() external view returns (uint256);

149:     function totalStaked() external view returns (uint256);

150:     function PRECISION() external view returns (uint256);

151:     function SECONDS_PER_YEAR() external view returns (uint256);

152:     function userInfo(address user) external view returns (uint256 amount, uint256 phUSDDebt, uint256 stableDebt);

```

```solidity
File: interfaces/IPhlimboHook.sol

22:     function onDeposit(address caller, address user, uint256 amount) external;

31:     function onWithdraw(address caller, address user, uint256 amount) external;

40:     function onClaim(address caller, address user, uint256 phUSDAmount, uint256 stableAmount) external;

```

```solidity
File: interfaces/IPhlimboV2.sol

74:     function setDepletionDuration(uint256 _duration) external;

98:     function emergencyTransfer(address recipient) external;

126:     function stake(uint256 amount, address user) external;

136:     function withdraw(uint256 amount, address user) external;

153:     function pendingPhUSD(address user) external view returns (uint256);

160:     function pendingStable(address user) external view returns (uint256);

176:     function rewardToken() external view returns (IERC20);

177:     function desiredAPYBps() external view returns (uint256);

178:     function phUSDPerSecond() external view returns (uint256);

179:     function rewardBalance() external view returns (uint256);

180:     function depletionDuration() external view returns (uint256);

181:     function rewardPerSecond() external view returns (uint256);

182:     function lastRewardTime() external view returns (uint256);

183:     function accPhUSDPerShare() external view returns (uint256);

184:     function accStablePerShare() external view returns (uint256);

185:     function totalStaked() external view returns (uint256);

186:     function migrator() external view returns (address);

187:     function hook() external view returns (IPhlimboHook);

188:     function PRECISION() external view returns (uint256);

189:     function SECONDS_PER_YEAR() external view returns (uint256);

190:     function userInfo(address user) external view returns (uint256 amount, uint256 phUSDDebt, uint256 stableDebt);

```

```solidity
File: interfaces/IPhlimboV3.sol

166:     function startPromotion(address token, uint256 amount, uint256 duration) external;

178:     function setPromoDepletionDuration(uint256 duration) external;

196:     function batchClaim(uint256 maxIterations) external;

207:     function finalizePromotion(address leftoverRecipient) external;

223:     function claimUnclaimablePromo(address token) external;

244:     function pendingPromo(address user) external view returns (uint256);

273:     function setDepletionDuration(uint256 _duration) external;

301:     function emergencyTransfer(address recipient) external;

321:     function stake(uint256 amount, address user) external;

331:     function withdraw(uint256 amount, address user) external;

348:     function pendingPhUSD(address user) external view returns (uint256);

355:     function pendingStable(address user) external view returns (uint256);

374:     function rewardToken() external view returns (IERC20);

375:     function desiredAPYBps() external view returns (uint256);

376:     function phUSDPerSecond() external view returns (uint256);

377:     function rewardBalance() external view returns (uint256);

378:     function depletionDuration() external view returns (uint256);

379:     function rewardPerSecond() external view returns (uint256);

380:     function lastRewardTime() external view returns (uint256);

381:     function accPhUSDPerShare() external view returns (uint256);

382:     function accStablePerShare() external view returns (uint256);

383:     function totalStaked() external view returns (uint256);

384:     function migrator() external view returns (address);

385:     function hook() external view returns (IPhlimboHook);

386:     function PRECISION() external view returns (uint256);

387:     function SECONDS_PER_YEAR() external view returns (uint256);

388:     function MINIMUM_STAKE() external view returns (uint256);

393:     function promoToken() external view returns (IERC20);

394:     function promoRewardBalance() external view returns (uint256);

395:     function promoDepletionDuration() external view returns (uint256);

396:     function promoRewardPerSecond() external view returns (uint256);

397:     function accPromoPerShare() external view returns (uint256);

398:     function promoPhase() external view returns (PromoPhase);

399:     function flushCursor() external view returns (uint256);

402:     function unclaimablePromoOf(address token, address user) external view returns (uint256);

405:     function totalUnclaimableOf(address token) external view returns (uint256);

408:     function unclaimableStableOf(address user) external view returns (uint256);

411:     function totalUnclaimableStable() external view returns (uint256);

418:     function stakerCount() external view returns (uint256);

424:     function stakerAt(uint256 index) external view returns (address);

```

### <a name="NC-11"></a>[NC-11] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (7)*:
```solidity
File: Phlimbo.sol

219:     function setPauser(address _pauser) external onlyOwner {
             pauser = _pauser;

```

```solidity
File: PhlimboV2.sol

224:     function setPauser(address _pauser) external onlyOwner {
             pauser = _pauser;

232:     function setMigrator(address _migrator) external onlyOwner {
             address oldMigrator = migrator;
             migrator = _migrator;
             emit MigratorSet(oldMigrator, _migrator);

242:     function setHook(address _hook) external onlyOwner {
             address oldHook = address(hook);
             hook = IPhlimboHook(_hook);
             emit HookSet(oldHook, _hook);

```

```solidity
File: PhlimboV3.sol

300:     function setPauser(address _pauser) external onlyOwner {
             pauser = _pauser;
         }
     
         /**

308:     function setMigrator(address _migrator) external onlyOwner {
             address oldMigrator = migrator;
             migrator = _migrator;
             emit MigratorSet(oldMigrator, _migrator);

318:     function setHook(address _hook) external onlyOwner {
             address oldHook = address(hook);
             hook = IPhlimboHook(_hook);
             emit HookSet(oldHook, _hook);
         }

```

### <a name="NC-12"></a>[NC-12] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (3)*:
```solidity
File: Phlimbo.sol

219:     function setPauser(address _pauser) external onlyOwner {
             pauser = _pauser;

```

```solidity
File: PhlimboV2.sol

224:     function setPauser(address _pauser) external onlyOwner {
             pauser = _pauser;

```

```solidity
File: PhlimboV3.sol

300:     function setPauser(address _pauser) external onlyOwner {
             pauser = _pauser;
         }
     
         /**

```

### <a name="NC-13"></a>[NC-13] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (26)*:
```solidity
File: PhlimboV2.sol

170:      * @notice Two-step APY setting: preview then commit
          */
         function setDesiredAPY(uint256 bps) external onlyOwner {

193:      * @notice Sets the depletion duration for reward distribution
          * @dev Recomputes rate after window change — kept from V1 per planning Concerns.
          */
         function setDepletionDuration(uint256 _duration) external onlyOwner {

222:      * @notice Sets the address authorized to pause the contract
          */
         function setPauser(address _pauser) external onlyOwner {

229:      * @notice Sets the migrator address authorized to act on behalf of any user.
          * @dev Accepts address(0) to disable the migrator role.
          */
         function setMigrator(address _migrator) external onlyOwner {

239:      * @notice Sets the hook contract invoked after stake/withdraw/claim.
          * @dev Accepts address(0) to disable the hook.
          */
         function setHook(address _hook) external onlyOwner {

249:      * @notice Emergency function to transfer all tokens to a recipient
          */
         function emergencyTransfer(address recipient) external onlyOwner {

276:      * @notice Allows users to withdraw their staked phUSD when contract is paused
          * @dev Emergency exit mechanism — strictly msg.sender-only. NOT delegatable to
          *      migrator. Does NOT claim rewards or update pool. Does NOT invoke any hook.
          */
         function pauseWithdraw(uint256 amount) external whenPaused {

296:      * @notice Collects rewards and updates linear depletion rate
          */
         function collectReward(uint256 amount) external nonReentrant {

317:      * @notice Stake phUSD tokens on behalf of `user`
          * @dev Auth: msg.sender == user || msg.sender == migrator. Tokens are pulled from
          *      msg.sender via safeTransferFrom. The position is credited to `user`.
          *      Any auto-claimed rewards go to msg.sender (not `user`) — consistent with
          *      withdraw/claim routing during migrator delegation.
          */
         function stake(uint256 amount, address user) external whenNotPaused nonReentrant {

359:      * @notice Withdraw staked phUSD and auto-claim rewards on behalf of `user`
          * @dev Auth: msg.sender == user || msg.sender == migrator. Withdrawn tokens AND
          *      any auto-claimed rewards are sent to msg.sender.
          */
         function withdraw(uint256 amount, address user) external whenNotPaused nonReentrant {

404:      * @notice Claim pending rewards on behalf of `user` without withdrawing stake
          * @dev Auth: msg.sender == user || msg.sender == migrator. Rewards go to msg.sender.
          */
         function claim(address user) external whenNotPaused nonReentrant {

```

```solidity
File: PhlimboV3.sol

243:      * @notice Two-step APY setting: preview then commit
          */
         function setDesiredAPY(uint256 bps) external onlyOwner {

264:      * @notice Sets the depletion duration for reward distribution
          * @dev Recomputes rate after window change — kept from V1 per planning Concerns.
          */
         function setDepletionDuration(uint256 _duration) external onlyOwner {

298:      * @notice Sets the address authorized to pause the contract
          */
         function setPauser(address _pauser) external onlyOwner {

305:      * @notice Sets the migrator address authorized to act on behalf of any user.
          * @dev Accepts address(0) to disable the migrator role.
          */
         function setMigrator(address _migrator) external onlyOwner {

315:      * @notice Sets the hook contract invoked after stake/withdraw/claim.
          * @dev Accepts address(0) to disable the hook.
          */
         function setHook(address _hook) external onlyOwner {

325:      * @notice Emergency function to transfer all tokens to a recipient
          * @dev V3: also sweeps the promo token when a promotion slot is set.
          *
          *      Trade-off (audit-08 M-01): this sweeps the LIVE promo token's entire
          *      balance, INCLUDING any per-user banked amounts (`unclaimablePromoOf`) —
          *      an accepted escape-hatch trade-off mirroring `MigratorV2V3.withdrawAll`;
          *      making users whole after such a sweep is an out-of-band owner
          *      obligation. Note the asymmetry with `finalizePromotion`, which is a
          *      routine lifecycle step and must NOT sweep the bank. A RETIRED token's
          *      bank (promoToken == address(0) for it) is unreachable here and stays
          *      pullable via `claimUnclaimablePromo`.
          *
          *      Same trade-off applies to the stable bank (audit-09 M-01): this sweeps the
          *      entire `rewardToken` balance, INCLUDING any live `unclaimableStableOf`
          *      amounts. `claimUnclaimableStable` has no `finalizePromotion`-equivalent
          *      reserve (the stable token never rotates and is not swept as routine
          *      leftover), so a live stable bank is reachable by this escape hatch —
          *      making users whole afterward is the same out-of-band owner obligation.
          */
         function emergencyTransfer(address recipient) external onlyOwner {

367:      * @notice Starts a new promotion: pulls `amount` of `token` from the owner and
          *         streams it linearly over `duration`. Phase None → Active.
          * @dev Fee-on-transfer/rebasing tokens are rejected by policy; the balance-delta
          *      check is the belt-and-braces guard. `_updatePool()` runs first so the promo
          *      stream cannot retroactively accrue over time before the promotion existed.
          */
         function startPromotion(address token, uint256 amount, uint256 duration) external onlyOwner whenNotPaused {

397:      * @notice Adds `amount` of the current promo token and recomputes the rate over
          *         the existing window (canonical recompute site, mirrors collectReward).
          *         Reactivates a dormant stream. Requires phase Active.
          */
         function topUpPromotion(uint256 amount) external onlyOwner {
             require(promoPhase == PromoPhase.Active, "Promo phase must be Active");

419:      * @notice Changes the promo depletion window and recomputes the rate over the
          *         remaining balance (mirrors setDepletionDuration). Requires phase Active.
          */
         function setPromoDepletionDuration(uint256 duration) external onlyOwner {

459:      * @notice Processes up to `maxIterations` stakers from the flush cursor: pays each
          *         staker's pending promo TO THE STAKER DIRECTLY (forced claim — beneficiary
          *         is the user, unlike the V2 caller-routing of ordinary claims) and aligns
          *         their promoDebt to the current accumulator.
          * @dev Permissionless: recipients and amounts are fixed by state, so anyone may
          *      help complete a flush. Failed transfers (e.g. blocklisted recipients) are
          *      banked per-user into `unclaimablePromoOf[token][staker]` (audit-08 M-01)
          *      for later pull via `claimUnclaimablePromo` — the flush must never brick.
          *      Touches ONLY promo state; stable/phUSD pendings are untouched.
          */
         function batchClaim(uint256 maxIterations) external nonReentrant {
             require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

510:      * @notice Finalizes the rotation: requires full cursor coverage of the frozen
          *         staker set. Sweeps only the UNENCUMBERED promo token balance
          *         (undistributed remainder + rounding dust) to
          *         `leftoverRecipient`; per-user banked amounts (`totalUnclaimableOf`)
          *         are reserved and survive the rotation (audit-08 M-01).
          *         Phase Flushing → None; owner then unpauses.
          * @dev `accPromoPerShare` is deliberately NOT reset (§2.1): all debts were aligned
          *      to it by the flush, so pending against the next token starts at exactly
          *      zero. Zeroing it while debts are non-zero would underflow amount*acc − debt.
          *
          *      Forfeit-sweep vs bank-retain (audit-08 M-01): undistributed remainder and
          *      rounding dust have NOTHING banked — those tokens are legitimately swept
          *      here as leftover. Failed flush transfers, by contrast, are banked
          *      per-user in `batchClaim` and reserved from this sweep via
          *      `totalUnclaimableOf`; they belong to users, not to `leftoverRecipient`.
          *
          *      The subtraction saturates deliberately: even under accounting drift this
          *      function must never revert — stranding some leftover is preferable to
          *      pinning the contract in `Flushing` forever.
          */
         function finalizePromotion(address leftoverRecipient) external onlyOwner {
             require(promoPhase == PromoPhase.Flushing, "Promo phase must be Flushing");

626:      * @notice Collects rewards and updates linear depletion rate
          */
         function collectReward(uint256 amount) external nonReentrant {
             require(amount > 0, "Amount must be greater than 0");

648:      * @dev Auth: msg.sender == user || msg.sender == migrator. Tokens are pulled from
          *      msg.sender via safeTransferFrom. The position is credited to `user`.
          *      Any auto-claimed rewards go to msg.sender (not `user`) — consistent with
          *      withdraw/claim routing during migrator delegation.
          */
         function stake(uint256 amount, address user) external whenNotPaused nonReentrant {
             require(amount >= MINIMUM_STAKE, "Below minimum stake");

694:      * @notice Withdraw staked phUSD and auto-claim rewards on behalf of `user`
          * @dev Auth: msg.sender == user || msg.sender == migrator. Withdrawn tokens AND
          *      any auto-claimed rewards are sent to msg.sender.
          */
         function withdraw(uint256 amount, address user) external whenNotPaused nonReentrant {
             require(user != address(0), "Invalid user");

745:      * @notice Claim pending rewards on behalf of `user` without withdrawing stake
          * @dev Auth: msg.sender == user || msg.sender == migrator. Rewards go to msg.sender.
          */
         function claim(address user) external whenNotPaused nonReentrant {
             require(user != address(0), "Invalid user");

```

### <a name="NC-14"></a>[NC-14] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (13)*:
```solidity
File: MigratorV2V3.sol

236:         require(msg.sender == address(this), "Only self");

```

```solidity
File: Phlimbo.sol

211:         require(msg.sender == pauser, "Only pauser can unpause");

249:         require(msg.sender == pauser, "Only pauser can pause");

```

```solidity
File: PhlimboV2.sol

217:         require(msg.sender == pauser, "Only pauser can unpause");

271:         require(msg.sender == pauser, "Only pauser can pause");

326:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

365:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

409:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

```

```solidity
File: PhlimboV3.sol

292:         require(msg.sender == pauser || msg.sender == owner(), "Only pauser or owner can unpause");

619:         require(msg.sender == pauser || msg.sender == owner(), "Only pauser or owner can pause");

656:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

700:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

750:         require(msg.sender == user || msg.sender == migrator, "Not authorized");

```

### <a name="NC-15"></a>[NC-15] Constant state variables defined more than once
Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (9)*:
```solidity
File: Phlimbo.sol

77:     uint256 public constant PRECISION = 1e18;

80:     uint256 public constant SECONDS_PER_YEAR = 365 days;

83:     uint256 public constant MINIMUM_STAKE = 1e15;

```

```solidity
File: PhlimboV2.sol

94:     uint256 public constant PRECISION = 1e18;

97:     uint256 public constant SECONDS_PER_YEAR = 365 days;

100:     uint256 public constant MINIMUM_STAKE = 1e15;

```

```solidity
File: PhlimboV3.sol

170:     uint256 public constant PRECISION = 1e18;

173:     uint256 public constant SECONDS_PER_YEAR = 365 days;

176:     uint256 public constant MINIMUM_STAKE = 1e15;

```

### <a name="NC-16"></a>[NC-16] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (7)*:
```solidity
File: MigratorV2V3.sol

112:     mapping(address => mapping(address => uint256)) public unclaimable;

```

```solidity
File: Phlimbo.sol

102:     mapping(address => UserInfo) public userInfo;

```

```solidity
File: PhlimboV2.sol

116:     mapping(address => UserInfo) public userInfo;

```

```solidity
File: PhlimboV3.sol

143:     mapping(address => mapping(address => uint256)) public unclaimablePromoOf;

150:     mapping(address => uint256) public totalUnclaimableOf;

156:     mapping(address => uint256) public unclaimableStableOf;

193:     mapping(address => UserInfo) public userInfo;

```

### <a name="NC-17"></a>[NC-17] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (3)*:
```solidity
File: Phlimbo.sol

219:     function setPauser(address _pauser) external onlyOwner {

```

```solidity
File: PhlimboV2.sol

224:     function setPauser(address _pauser) external onlyOwner {

```

```solidity
File: PhlimboV3.sol

300:     function setPauser(address _pauser) external onlyOwner {

```

### <a name="NC-18"></a>[NC-18] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (9)*:
```solidity
File: MigratorV2V3.sol

345:      * @notice Non-reverting ERC20 transfer used by the migration pass: a single
          *         blocklisted or otherwise reverting recipient must not brick migrate.
          * @return success True if the transfer succeeded (call succeeded and returned
          *         either nothing or true).
          */
         function _tryTransfer(IERC20 token, address to, uint256 amount) internal returns (bool success) {
             (bool callSuccess, bytes memory returndata) = address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));
             return callSuccess && (returndata.length == 0 || abi.decode(returndata, (bool)));

```

```solidity
File: Phlimbo.sol

551:     /**
          * @notice Returns current pool information
          * @return _totalStaked Total staked amount
          * @return _accPhUSDPerShare Accumulated phUSD per share
          * @return _accStablePerShare Accumulated stable per share
          * @return _phUSDPerSecond Current emission rate
          * @return _lastRewardTime Last update time
          */
         function getPoolInfo()
             external
             view
             returns (
                 uint256 _totalStaked,
                 uint256 _accPhUSDPerShare,
                 uint256 _accStablePerShare,
                 uint256 _phUSDPerSecond,
                 uint256 _lastRewardTime
             )
         {
             return (

579:     /**
          * @notice Returns information about pending APY setting operation
          * @return _pendingAPYBps The proposed APY value
          * @return _pendingAPYBlockNumber The block when APY was proposed
          * @return _apySetInProgress Whether a set operation is pending
          */
         function getPendingAPYInfo()
             external
             view
             returns (
                 uint256 _pendingAPYBps,
                 uint256 _pendingAPYBlockNumber,
                 bool _apySetInProgress
             )
         {
             return (pendingAPYBps, pendingAPYBlockNumber, apySetInProgress);

```

```solidity
File: PhlimboV2.sol

561:      * @notice Returns current pool information
          */
         function getPoolInfo() external view returns (
             uint256 _totalStaked,
             uint256 _accPhUSDPerShare,
             uint256 _accStablePerShare,
             uint256 _phUSDPerSecond,
             uint256 _lastRewardTime
         ) {
             return (
                 totalStaked,

580:      * @notice Returns information about pending APY setting operation
          */
         function getPendingAPYInfo() external view returns (
             uint256 _pendingAPYBps,
             uint256 _pendingAPYBlockNumber,
             bool _apySetInProgress
         ) {
             return (
                 pendingAPYBps,

```

```solidity
File: PhlimboV3.sol

911:      * @notice Non-reverting ERC20 transfer used by the flush: a single blocklisted or
          *         otherwise reverting recipient must not brick batchClaim.
          * @return success True if the transfer succeeded (call succeeded and returned
          *         either nothing or true).
          */
         function _tryTransfer(IERC20 token, address to, uint256 amount) internal returns (bool success) {
             (bool callSuccess, bytes memory returndata) = address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));
             return callSuccess && (returndata.length == 0 || abi.decode(returndata, (bool)));
         }

1011:     function getPromoInfo()
              external
              view
              returns (
                  address _promoToken,
                  uint256 _promoRewardBalance,
                  uint256 _promoRewardPerSecond,
                  uint256 _promoDepletionDuration,
                  PromoPhase _promoPhase,
                  uint256 _flushCursor
              )
          {
              return (
                  address(promoToken),
                  promoRewardBalance,
                  promoRewardPerSecond,

1051:         external
              view
              returns (
                  uint256 _totalStaked,
                  uint256 _accPhUSDPerShare,
                  uint256 _accStablePerShare,
                  uint256 _phUSDPerSecond,
                  uint256 _lastRewardTime
              )
          {
              return (totalStaked, accPhUSDPerShare, accStablePerShare, phUSDPerSecond, lastRewardTime);
          }

1067:     function getPendingAPYInfo()
              external
              view
              returns (uint256 _pendingAPYBps, uint256 _pendingAPYBlockNumber, bool _apySetInProgress)
          {
              return (pendingAPYBps, pendingAPYBlockNumber, apySetInProgress);
          }
      }
      

```

### <a name="NC-19"></a>[NC-19] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (3)*:
```solidity
File: Phlimbo.sol

1: 
   Current order:
   UsingForDirective.IERC20
   VariableDeclaration.phUSD
   VariableDeclaration.rewardToken
   VariableDeclaration.pauser
   VariableDeclaration.desiredAPYBps
   VariableDeclaration.phUSDPerSecond
   VariableDeclaration.pendingAPYBps
   VariableDeclaration.pendingAPYBlockNumber
   VariableDeclaration.apySetInProgress
   VariableDeclaration.rewardBalance
   VariableDeclaration.depletionDuration
   VariableDeclaration.rewardPerSecond
   VariableDeclaration.lastRewardTime
   VariableDeclaration.accPhUSDPerShare
   VariableDeclaration.accStablePerShare
   VariableDeclaration.totalStaked
   VariableDeclaration.PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.MINIMUM_STAKE
   StructDefinition.UserInfo
   VariableDeclaration.userInfo
   EventDefinition.RewardCollected
   EventDefinition.RateUpdated
   EventDefinition.DepletionDurationUpdated
   EventDefinition.IntendedSetAPY
   EventDefinition.DesiredAPYUpdated
   FunctionDefinition.constructor
   FunctionDefinition.setDesiredAPY
   FunctionDefinition.setDepletionDuration
   FunctionDefinition.unpause
   FunctionDefinition.setPauser
   FunctionDefinition.emergencyTransfer
   FunctionDefinition.pause
   FunctionDefinition.pauseWithdraw
   FunctionDefinition.collectReward
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition._updatePool
   FunctionDefinition._claimRewards
   FunctionDefinition._updatePhUSDEmissionRate
   FunctionDefinition.pendingPhUSD
   FunctionDefinition.pendingStable
   FunctionDefinition.getPoolInfo
   FunctionDefinition.getPendingAPYInfo
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.phUSD
   VariableDeclaration.rewardToken
   VariableDeclaration.pauser
   VariableDeclaration.desiredAPYBps
   VariableDeclaration.phUSDPerSecond
   VariableDeclaration.pendingAPYBps
   VariableDeclaration.pendingAPYBlockNumber
   VariableDeclaration.apySetInProgress
   VariableDeclaration.rewardBalance
   VariableDeclaration.depletionDuration
   VariableDeclaration.rewardPerSecond
   VariableDeclaration.lastRewardTime
   VariableDeclaration.accPhUSDPerShare
   VariableDeclaration.accStablePerShare
   VariableDeclaration.totalStaked
   VariableDeclaration.PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.MINIMUM_STAKE
   VariableDeclaration.userInfo
   StructDefinition.UserInfo
   EventDefinition.RewardCollected
   EventDefinition.RateUpdated
   EventDefinition.DepletionDurationUpdated
   EventDefinition.IntendedSetAPY
   EventDefinition.DesiredAPYUpdated
   FunctionDefinition.constructor
   FunctionDefinition.setDesiredAPY
   FunctionDefinition.setDepletionDuration
   FunctionDefinition.unpause
   FunctionDefinition.setPauser
   FunctionDefinition.emergencyTransfer
   FunctionDefinition.pause
   FunctionDefinition.pauseWithdraw
   FunctionDefinition.collectReward
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition._updatePool
   FunctionDefinition._claimRewards
   FunctionDefinition._updatePhUSDEmissionRate
   FunctionDefinition.pendingPhUSD
   FunctionDefinition.pendingStable
   FunctionDefinition.getPoolInfo
   FunctionDefinition.getPendingAPYInfo

```

```solidity
File: PhlimboV2.sol

1: 
   Current order:
   UsingForDirective.IERC20
   VariableDeclaration.phUSD
   VariableDeclaration.rewardToken
   VariableDeclaration.pauser
   VariableDeclaration.desiredAPYBps
   VariableDeclaration.phUSDPerSecond
   VariableDeclaration.pendingAPYBps
   VariableDeclaration.pendingAPYBlockNumber
   VariableDeclaration.apySetInProgress
   VariableDeclaration.rewardBalance
   VariableDeclaration.depletionDuration
   VariableDeclaration.rewardPerSecond
   VariableDeclaration.lastRewardTime
   VariableDeclaration.accPhUSDPerShare
   VariableDeclaration.accStablePerShare
   VariableDeclaration.totalStaked
   VariableDeclaration.migrator
   VariableDeclaration.hook
   VariableDeclaration.PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.MINIMUM_STAKE
   StructDefinition.UserInfo
   VariableDeclaration.userInfo
   EventDefinition.RewardCollected
   EventDefinition.RateUpdated
   EventDefinition.DepletionDurationUpdated
   EventDefinition.IntendedSetAPY
   EventDefinition.DesiredAPYUpdated
   FunctionDefinition.constructor
   FunctionDefinition.setDesiredAPY
   FunctionDefinition.setDepletionDuration
   FunctionDefinition.unpause
   FunctionDefinition.setPauser
   FunctionDefinition.setMigrator
   FunctionDefinition.setHook
   FunctionDefinition.emergencyTransfer
   FunctionDefinition.pause
   FunctionDefinition.pauseWithdraw
   FunctionDefinition.collectReward
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition._updatePool
   FunctionDefinition._claimRewards
   FunctionDefinition._updatePhUSDEmissionRate
   FunctionDefinition.pendingPhUSD
   FunctionDefinition.pendingStable
   FunctionDefinition.getPoolInfo
   FunctionDefinition.getPendingAPYInfo
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.phUSD
   VariableDeclaration.rewardToken
   VariableDeclaration.pauser
   VariableDeclaration.desiredAPYBps
   VariableDeclaration.phUSDPerSecond
   VariableDeclaration.pendingAPYBps
   VariableDeclaration.pendingAPYBlockNumber
   VariableDeclaration.apySetInProgress
   VariableDeclaration.rewardBalance
   VariableDeclaration.depletionDuration
   VariableDeclaration.rewardPerSecond
   VariableDeclaration.lastRewardTime
   VariableDeclaration.accPhUSDPerShare
   VariableDeclaration.accStablePerShare
   VariableDeclaration.totalStaked
   VariableDeclaration.migrator
   VariableDeclaration.hook
   VariableDeclaration.PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.MINIMUM_STAKE
   VariableDeclaration.userInfo
   StructDefinition.UserInfo
   EventDefinition.RewardCollected
   EventDefinition.RateUpdated
   EventDefinition.DepletionDurationUpdated
   EventDefinition.IntendedSetAPY
   EventDefinition.DesiredAPYUpdated
   FunctionDefinition.constructor
   FunctionDefinition.setDesiredAPY
   FunctionDefinition.setDepletionDuration
   FunctionDefinition.unpause
   FunctionDefinition.setPauser
   FunctionDefinition.setMigrator
   FunctionDefinition.setHook
   FunctionDefinition.emergencyTransfer
   FunctionDefinition.pause
   FunctionDefinition.pauseWithdraw
   FunctionDefinition.collectReward
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition._updatePool
   FunctionDefinition._claimRewards
   FunctionDefinition._updatePhUSDEmissionRate
   FunctionDefinition.pendingPhUSD
   FunctionDefinition.pendingStable
   FunctionDefinition.getPoolInfo
   FunctionDefinition.getPendingAPYInfo

```

```solidity
File: PhlimboV3.sol

1: 
   Current order:
   UsingForDirective.IERC20
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration.phUSD
   VariableDeclaration.rewardToken
   VariableDeclaration.pauser
   VariableDeclaration.desiredAPYBps
   VariableDeclaration.phUSDPerSecond
   VariableDeclaration.pendingAPYBps
   VariableDeclaration.pendingAPYBlockNumber
   VariableDeclaration.apySetInProgress
   VariableDeclaration.rewardBalance
   VariableDeclaration.depletionDuration
   VariableDeclaration.rewardPerSecond
   VariableDeclaration.lastRewardTime
   VariableDeclaration.accPhUSDPerShare
   VariableDeclaration.accStablePerShare
   VariableDeclaration.totalStaked
   VariableDeclaration.migrator
   VariableDeclaration.hook
   VariableDeclaration.promoToken
   VariableDeclaration.promoRewardBalance
   VariableDeclaration.promoDepletionDuration
   VariableDeclaration.promoRewardPerSecond
   VariableDeclaration.accPromoPerShare
   VariableDeclaration._stakers
   VariableDeclaration.promoPhase
   VariableDeclaration.flushCursor
   VariableDeclaration.unclaimablePromoOf
   VariableDeclaration.totalUnclaimableOf
   VariableDeclaration.unclaimableStableOf
   VariableDeclaration.totalUnclaimableStable
   VariableDeclaration.PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.MINIMUM_STAKE
   StructDefinition.UserInfo
   VariableDeclaration.userInfo
   EventDefinition.RewardCollected
   EventDefinition.RateUpdated
   EventDefinition.DepletionDurationUpdated
   EventDefinition.IntendedSetAPY
   EventDefinition.DesiredAPYUpdated
   FunctionDefinition.constructor
   FunctionDefinition.setDesiredAPY
   FunctionDefinition.setDepletionDuration
   FunctionDefinition.unpause
   FunctionDefinition.setPauser
   FunctionDefinition.setMigrator
   FunctionDefinition.setHook
   FunctionDefinition.emergencyTransfer
   FunctionDefinition.startPromotion
   FunctionDefinition.topUpPromotion
   FunctionDefinition.setPromoDepletionDuration
   FunctionDefinition.beginFlush
   FunctionDefinition.batchClaim
   FunctionDefinition.finalizePromotion
   FunctionDefinition.abortFlush
   FunctionDefinition.claimUnclaimablePromo
   FunctionDefinition.claimUnclaimableStable
   FunctionDefinition.pause
   FunctionDefinition.collectReward
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition._updatePool
   FunctionDefinition._claimRewards
   FunctionDefinition._tryTransfer
   FunctionDefinition._updatePhUSDEmissionRate
   FunctionDefinition.pendingPhUSD
   FunctionDefinition.pendingStable
   FunctionDefinition.pendingPromo
   FunctionDefinition.getPromoInfo
   FunctionDefinition.stakerCount
   FunctionDefinition.stakerAt
   FunctionDefinition.getPoolInfo
   FunctionDefinition.getPendingAPYInfo
   
   Suggested order:
   UsingForDirective.IERC20
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration.phUSD
   VariableDeclaration.rewardToken
   VariableDeclaration.pauser
   VariableDeclaration.desiredAPYBps
   VariableDeclaration.phUSDPerSecond
   VariableDeclaration.pendingAPYBps
   VariableDeclaration.pendingAPYBlockNumber
   VariableDeclaration.apySetInProgress
   VariableDeclaration.rewardBalance
   VariableDeclaration.depletionDuration
   VariableDeclaration.rewardPerSecond
   VariableDeclaration.lastRewardTime
   VariableDeclaration.accPhUSDPerShare
   VariableDeclaration.accStablePerShare
   VariableDeclaration.totalStaked
   VariableDeclaration.migrator
   VariableDeclaration.hook
   VariableDeclaration.promoToken
   VariableDeclaration.promoRewardBalance
   VariableDeclaration.promoDepletionDuration
   VariableDeclaration.promoRewardPerSecond
   VariableDeclaration.accPromoPerShare
   VariableDeclaration._stakers
   VariableDeclaration.promoPhase
   VariableDeclaration.flushCursor
   VariableDeclaration.unclaimablePromoOf
   VariableDeclaration.totalUnclaimableOf
   VariableDeclaration.unclaimableStableOf
   VariableDeclaration.totalUnclaimableStable
   VariableDeclaration.PRECISION
   VariableDeclaration.SECONDS_PER_YEAR
   VariableDeclaration.MINIMUM_STAKE
   VariableDeclaration.userInfo
   StructDefinition.UserInfo
   EventDefinition.RewardCollected
   EventDefinition.RateUpdated
   EventDefinition.DepletionDurationUpdated
   EventDefinition.IntendedSetAPY
   EventDefinition.DesiredAPYUpdated
   FunctionDefinition.constructor
   FunctionDefinition.setDesiredAPY
   FunctionDefinition.setDepletionDuration
   FunctionDefinition.unpause
   FunctionDefinition.setPauser
   FunctionDefinition.setMigrator
   FunctionDefinition.setHook
   FunctionDefinition.emergencyTransfer
   FunctionDefinition.startPromotion
   FunctionDefinition.topUpPromotion
   FunctionDefinition.setPromoDepletionDuration
   FunctionDefinition.beginFlush
   FunctionDefinition.batchClaim
   FunctionDefinition.finalizePromotion
   FunctionDefinition.abortFlush
   FunctionDefinition.claimUnclaimablePromo
   FunctionDefinition.claimUnclaimableStable
   FunctionDefinition.pause
   FunctionDefinition.collectReward
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition._updatePool
   FunctionDefinition._claimRewards
   FunctionDefinition._tryTransfer
   FunctionDefinition._updatePhUSDEmissionRate
   FunctionDefinition.pendingPhUSD
   FunctionDefinition.pendingStable
   FunctionDefinition.pendingPromo
   FunctionDefinition.getPromoInfo
   FunctionDefinition.stakerCount
   FunctionDefinition.stakerAt
   FunctionDefinition.getPoolInfo
   FunctionDefinition.getPendingAPYInfo

```

### <a name="NC-20"></a>[NC-20] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (3)*:
```solidity
File: Phlimbo.sol

494:             10000 /

```

```solidity
File: PhlimboV2.sol

518:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

```

```solidity
File: PhlimboV3.sol

930:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

```

### <a name="NC-21"></a>[NC-21] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (47)*:
```solidity
File: Phlimbo.sol

108:     event RewardCollected(

115:     event RateUpdated(uint256 newRate, uint256 newBalance);

118:     event DepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

121:     event IntendedSetAPY(

128:     event DesiredAPYUpdated(uint256 oldAPY, uint256 newAPY);

```

```solidity
File: PhlimboV2.sol

123:     event RewardCollected(uint256 amount, uint256 newRewardBalance, uint256 newRate);

126:     event RateUpdated(uint256 newRate, uint256 newBalance);

129:     event DepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

132:     event IntendedSetAPY(uint256 indexed proposedAPY, uint256 blockNumber, address indexed proposer);

135:     event DesiredAPYUpdated(uint256 oldAPY, uint256 newAPY);

```

```solidity
File: PhlimboV3.sol

200:     event RewardCollected(uint256 amount, uint256 newRewardBalance, uint256 newRate);

203:     event RateUpdated(uint256 newRate, uint256 newBalance);

206:     event DepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

209:     event IntendedSetAPY(uint256 indexed proposedAPY, uint256 blockNumber, address indexed proposer);

212:     event DesiredAPYUpdated(uint256 oldAPY, uint256 newAPY);

```

```solidity
File: interfaces/IMigratorV1V2.sol

19:     event Seeded(

32:     event SettleProgress(int256 iterator, uint256 remainingUSDC, uint256 remainingPHUSDPending);

39:     event MigrateProgress(int256 iterator, uint256 remainingDepositPHUSD);

47:     event WithdrawnAll(address indexed owner, uint256 usdcAmount, uint256 phUSDAmount);

```

```solidity
File: interfaces/IMigratorV2V3.sol

21:     event Seeded(uint256 userCount);

34:     event UserMigrated(

47:     event MigrateProgress(int256 iterator, uint256 userCount);

56:     event RewardForwardFailed(address indexed token, address indexed user, uint256 amount);

75:     event UserMigrationSkipped(address indexed user, uint256 amount, bytes reason);

83:     event UnclaimableClaimed(address indexed token, address indexed user, uint256 amount);

93:     event WithdrawnAll(

```

```solidity
File: interfaces/IPhlimbo.sol

19:     event EmergencyWithdrawal(address indexed user, uint256 amount);

26:     event Staked(address indexed user, uint256 amount);

33:     event Withdrawn(address indexed user, uint256 amount);

41:     event RewardsClaimed(address indexed user, uint256 phUSDAmount, uint256 stableAmount);

```

```solidity
File: interfaces/IPhlimboV2.sol

24:     event EmergencyWithdrawal(address indexed user, uint256 amount);

31:     event Staked(address indexed user, uint256 amount);

38:     event Withdrawn(address indexed user, uint256 amount);

46:     event RewardsClaimed(address indexed user, uint256 phUSDAmount, uint256 stableAmount);

```

```solidity
File: interfaces/IPhlimboV3.sol

35:     event Staked(address indexed user, uint256 amount);

42:     event Withdrawn(address indexed user, uint256 amount);

50:     event RewardsClaimed(address indexed user, uint256 phUSDAmount, uint256 stableAmount);

75:     event PromotionStarted(address indexed token, uint256 amount, uint256 duration, uint256 rate);

83:     event PromotionToppedUp(uint256 amount, uint256 newBalance, uint256 newRate);

88:     event PromoDepletionDurationUpdated(uint256 oldDuration, uint256 newDuration);

95:     event PromoClaimed(address indexed user, uint256 amount);

102:     event FlushProgress(uint256 cursor, uint256 total);

113:     event PromoClaimFailed(address indexed token, address indexed user, uint256 amount);

121:     event UnclaimablePromoClaimed(address indexed token, address indexed user, uint256 amount);

137:     event StableClaimFailed(address indexed user, uint256 amount);

145:     event UnclaimableStableClaimed(address indexed user, uint256 amount);

155:     event PromotionFinalized(address indexed token, address indexed leftoverRecipient, uint256 leftoverAmount);

```

### <a name="NC-22"></a>[NC-22] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (2)*:
```solidity
File: MigratorV1V2.sol

125:         for (uint256 i = 0; i < _users.length; i++) {

```

```solidity
File: MigratorV2V3.sol

149:         for (uint256 i = 0; i < _users.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 5 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 32 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 5 |
| [L-4](#L-4) | Division by zero not prevented | 23 |
| [L-5](#L-5) | External call recipient may consume all transaction gas | 2 |
| [L-6](#L-6) | Owner can renounce while system is paused | 3 |
| [L-7](#L-7) | Possible rounding issue | 14 |
| [L-8](#L-8) | Loss of precision | 60 |
| [L-9](#L-9) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 5 |
| [L-10](#L-10) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 5 |
| [L-11](#L-11) | Unsafe solidity low-level call can cause gas grief attack | 2 |
| [L-12](#L-12) | A year is not always 365 days | 3 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (5)*:
```solidity
File: MigratorV1V2.sol

47: contract MigratorV1V2 is Ownable, ReentrancyGuard, IMigratorV1V2 {

```

```solidity
File: MigratorV2V3.sol

89: contract MigratorV2V3 is Ownable, ReentrancyGuard, IMigratorV2V3 {

```

```solidity
File: Phlimbo.sol

23: contract PhlimboEA is Ownable, Pausable, ReentrancyGuard, IPhlimbo, IPausable {

```

```solidity
File: PhlimboV2.sol

32: contract PhlimboV2 is Ownable, Pausable, ReentrancyGuard, IPhlimboV2, IPausable {

```

```solidity
File: PhlimboV3.sol

44: contract PhlimboV3 is Ownable, Pausable, ReentrancyGuard, IPhlimboV3, IPausable {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (32)*:
```solidity
File: MigratorV1V2.sol

175:                 usdc.safeTransfer(users[i], usdcAmt);

255:             usdc.safeTransfer(ownerAddr, usdcBal);

258:             IERC20(address(phUSD)).safeTransfer(ownerAddr, phUSDBal);

```

```solidity
File: MigratorV2V3.sol

306:         IERC20(token).safeTransfer(msg.sender, amount);

330:             IERC20(address(phUSD)).safeTransfer(ownerAddr, phUSDBal);

334:         }

337:         }

```

```solidity
File: Phlimbo.sol

232:             IERC20(address(phUSD)).safeTransfer(recipient, phUSDBalance);

235:             rewardToken.safeTransfer(recipient, rewardTokenBalance);

270:         IERC20(address(phUSD)).safeTransfer(msg.sender, amount);

290:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

326:         IERC20(address(phUSD)).safeTransferFrom(

379:         IERC20(address(phUSD)).safeTransfer(msg.sender, actualWithdrawAmount);

471:             rewardToken.safeTransfer(user, pendingRewardAmount);

```

```solidity
File: PhlimboV2.sol

256:             IERC20(address(phUSD)).safeTransfer(recipient, phUSDBalance);

259:             rewardToken.safeTransfer(recipient, rewardTokenBalance);

288:         IERC20(address(phUSD)).safeTransfer(msg.sender, amount);

304:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

341:         IERC20(address(phUSD)).safeTransferFrom(msg.sender, address(this), amount);

392:         IERC20(address(phUSD)).safeTransfer(msg.sender, actualWithdrawAmount);

500:             rewardToken.safeTransfer(beneficiary, pendingRewardAmount);

```

```solidity
File: PhlimboV3.sol

349:             IERC20(address(phUSD)).safeTransfer(recipient, phUSDBalance);

352:             rewardToken.safeTransfer(recipient, rewardTokenBalance);

357:                 promoToken.safeTransfer(recipient, promoBalance);

384:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

409:         promoToken.safeTransferFrom(msg.sender, address(this), amount);

541:         }

586:         emit UnclaimablePromoClaimed(token, msg.sender, amount);

609:         emit UnclaimableStableClaimed(msg.sender, amount);

636:         rewardBalance += amount;

671:         IERC20(address(phUSD)).safeTransferFrom(msg.sender, address(this), amount);

735:         _updatePhUSDEmissionRate();

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (5)*:
```solidity
File: Phlimbo.sol

220:         pauser = _pauser;

```

```solidity
File: PhlimboV2.sol

225:         pauser = _pauser;

234:         migrator = _migrator;

```

```solidity
File: PhlimboV3.sol

304:     /**

311:         emit MigratorSet(oldMigrator, _migrator);

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (23)*:
```solidity
File: Phlimbo.sol

201:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

296:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

429:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

441:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

512:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

541:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV2.sol

208:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

309:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

460:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

473:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

533:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

553:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV3.sol

279:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

390:         promoRewardPerSecond = (amount * PRECISION) / duration;

413:         promoRewardPerSecond = (promoRewardBalance * PRECISION) / promoDepletionDuration;

431:         promoRewardPerSecond = (promoRewardBalance * PRECISION) / duration;

639:         rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;

802:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

815:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

839:                 accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

945:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

970:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

1001:                 _accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

```

### <a name="L-5"></a>[L-5] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (2)*:
```solidity
File: MigratorV2V3.sol

351:         (bool callSuccess, bytes memory returndata) = address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));

```

```solidity
File: PhlimboV3.sol

917:         (bool callSuccess, bytes memory returndata) = address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));

```

### <a name="L-6"></a>[L-6] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (3)*:
```solidity
File: Phlimbo.sol

219:     function setPauser(address _pauser) external onlyOwner {

```

```solidity
File: PhlimboV2.sol

224:     function setPauser(address _pauser) external onlyOwner {

```

```solidity
File: PhlimboV3.sol

300:     function setPauser(address _pauser) external onlyOwner {

```

### <a name="L-7"></a>[L-7] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (14)*:
```solidity
File: Phlimbo.sol

429:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

441:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

512:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

541:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV2.sol

460:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

473:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

533:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

553:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV3.sol

802:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

815:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

839:                 accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

945:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

970:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

1001:                 _accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

```

### <a name="L-8"></a>[L-8] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (60)*:
```solidity
File: Phlimbo.sol

334:         user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

335:         user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

372:         user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

373:         user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

396:         user.phUSDDebt = (user.amount * accPhUSDPerShare) / PRECISION;

397:         user.stableDebt = (user.amount * accStablePerShare) / PRECISION;

420:         uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

429:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

441:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

512:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

541:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

```

```solidity
File: PhlimboV2.sol

344:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

345:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

385:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

386:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

419:             pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

420:             pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

426:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

427:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

454:         uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

460:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

473:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

493:         uint256 pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

498:         uint256 pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

518:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

533:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

536:         return (userDetails.amount * _accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

548:             uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

553:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

557:         return (userDetails.amount * _accStablePerShare) / PRECISION - userDetails.stableDebt;

```

```solidity
File: PhlimboV3.sol

483:             uint256 pending = (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;

487:             userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

674:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

675:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

676:         userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

720:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

721:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

722:         userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

760:             pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

761:             pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

767:         userDetails.phUSDDebt = (userDetails.amount * accPhUSDPerShare) / PRECISION;

768:         userDetails.stableDebt = (userDetails.amount * accStablePerShare) / PRECISION;

769:         userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;

796:         uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

802:             accStablePerShare += (toDistribute * PRECISION) / totalStaked;

815:             accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

835:             uint256 potentialPromo = (promoRewardPerSecond * timeElapsed) / PRECISION;

839:                 accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

861:         uint256 pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

866:         uint256 pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;

892:             uint256 pendingPromoAmount = (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;

930:         phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR;

945:             _accPhUSDPerShare += (phUSDReward * PRECISION) / totalStaked;

948:         return (userDetails.amount * _accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;

965:             uint256 potentialReward = (rewardPerSecond * timeElapsed) / PRECISION;

970:                 _accStablePerShare += (toDistribute * PRECISION) / totalStaked;

974:         return (userDetails.amount * _accStablePerShare) / PRECISION - userDetails.stableDebt;

996:             uint256 potentialPromo = (promoRewardPerSecond * timeElapsed) / PRECISION;

1001:                 _accPromoPerShare += (promoToDistribute * PRECISION) / totalStaked;

1005:         return (userDetails.amount * _accPromoPerShare) / PRECISION - userDetails.promoDebt;

```

### <a name="L-9"></a>[L-9] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (5)*:
```solidity
File: MigratorV1V2.sol

2: pragma solidity ^0.8.19;

```

```solidity
File: MigratorV2V3.sol

2: pragma solidity ^0.8.19;

```

```solidity
File: Phlimbo.sol

2: pragma solidity ^0.8.19;

```

```solidity
File: PhlimboV2.sol

2: pragma solidity ^0.8.19;

```

```solidity
File: PhlimboV3.sol

2: pragma solidity ^0.8.19;

```

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

*Instances (5)*:
```solidity
File: MigratorV1V2.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: MigratorV2V3.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: Phlimbo.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: PhlimboV2.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: PhlimboV3.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-11"></a>[L-11] Unsafe solidity low-level call can cause gas grief attack
Using the low-level calls of a solidity address can leave the contract open to gas grief attacks. These attacks occur when the called contract returns a large amount of data.

So when calling an external contract, it is necessary to check the length of the return data before reading/copying it (using `returndatasize()`).

*Instances (2)*:
```solidity
File: MigratorV2V3.sol

351:         (bool callSuccess, bytes memory returndata) = address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));

```

```solidity
File: PhlimboV3.sol

917:         (bool callSuccess, bytes memory returndata) = address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));

```

### <a name="L-12"></a>[L-12] A year is not always 365 days
On leap years, the number of days is 366, so calculations during those years will return the wrong value

*Instances (3)*:
```solidity
File: Phlimbo.sol

80:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: PhlimboV2.sol

97:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```

```solidity
File: PhlimboV3.sol

173:     uint256 public constant SECONDS_PER_YEAR = 365 days;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 6 |
| [M-2](#M-2) | `block.number` means different things on different L2s | 9 |
| [M-3](#M-3) | Centralization Risk for trusted owners | 37 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (6)*:
```solidity
File: Phlimbo.sol

290:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: PhlimboV2.sol

304:         rewardToken.safeTransferFrom(msg.sender, address(this), amount);

341:         IERC20(address(phUSD)).safeTransferFrom(msg.sender, address(this), amount);

```

```solidity
File: PhlimboV3.sol

384:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

409:         promoToken.safeTransferFrom(msg.sender, address(this), amount);

671:         IERC20(address(phUSD)).safeTransferFrom(msg.sender, address(this), amount);

```

### <a name="M-2"></a>[M-2] `block.number` means different things on different L2s
On Optimism, `block.number` is the L2 block number, but on Arbitrum, it's the L1 block number, and `ArbSys(address(100)).arbBlockNumber()` must be used. Furthermore, L2 block numbers often occur much more frequently than L1 block numbers (any may even occur on a per-transaction basis), so using block numbers for timing results in inconsistencies, especially when voting is involved across multiple chains. As of version 4.9, OpenZeppelin has [modified](https://blog.openzeppelin.com/introducing-openzeppelin-contracts-v4.9#governor) their governor code to use a clock rather than block numbers, to avoid these sorts of issues, but this still requires that the project [implement](https://docs.openzeppelin.com/contracts/4.x/governance#token_2) a [clock](https://eips.ethereum.org/EIPS/eip-6372) for each L2.

*Instances (9)*:
```solidity
File: Phlimbo.sol

167:             block.number > pendingAPYBlockNumber + 100 ||

172:             emit IntendedSetAPY(bps, block.number, msg.sender);

174:             pendingAPYBlockNumber = block.number;

```

```solidity
File: PhlimboV2.sol

174:                         block.number > pendingAPYBlockNumber + 100 ||

178:             emit IntendedSetAPY(bps, block.number, msg.sender);

180:             pendingAPYBlockNumber = block.number;

```

```solidity
File: PhlimboV3.sol

246:         bool isPreview = !apySetInProgress || block.number > pendingAPYBlockNumber + 100 || bps != pendingAPYBps;

249:             emit IntendedSetAPY(bps, block.number, msg.sender);

251:             pendingAPYBlockNumber = block.number;

```

### <a name="M-3"></a>[M-3] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (37)*:
```solidity
File: MigratorV1V2.sol

47: contract MigratorV1V2 is Ownable, ReentrancyGuard, IMigratorV1V2 {

86:     constructor(address _usdc, address _phUSD, address _phlimboV2) Ownable(msg.sender) {

111:     ) external onlyOwner {

249:     function withdrawAll() external onlyOwner {

```

```solidity
File: MigratorV2V3.sol

89: contract MigratorV2V3 is Ownable, ReentrancyGuard, IMigratorV2V3 {

121:     ) Ownable(msg.sender) {

144:     function seedUsers(address[] calldata _users) external onlyOwner {

284:     function skipCurrent() external onlyOwner {

318:     function withdrawAll() external onlyOwner {

```

```solidity
File: Phlimbo.sol

23: contract PhlimboEA is Ownable, Pausable, ReentrancyGuard, IPhlimbo, IPausable {

142:     ) Ownable(msg.sender) {

164:     function setDesiredAPY(uint256 bps) external onlyOwner {

191:     function setDepletionDuration(uint256 _duration) external onlyOwner {

219:     function setPauser(address _pauser) external onlyOwner {

227:     function emergencyTransfer(address recipient) external onlyOwner {

```

```solidity
File: PhlimboV2.sol

32: contract PhlimboV2 is Ownable, Pausable, ReentrancyGuard, IPhlimboV2, IPausable {

149:     ) Ownable(msg.sender) {

172:     function setDesiredAPY(uint256 bps) external onlyOwner {

196:     function setDepletionDuration(uint256 _duration) external onlyOwner {

224:     function setPauser(address _pauser) external onlyOwner {

232:     function setMigrator(address _migrator) external onlyOwner {

242:     function setHook(address _hook) external onlyOwner {

251:     function emergencyTransfer(address recipient) external onlyOwner {

```

```solidity
File: PhlimboV3.sol

44: contract PhlimboV3 is Ownable, Pausable, ReentrancyGuard, IPhlimboV3, IPausable {

222:     constructor(address _phUSD, address _rewardToken, uint256 _depletionDuration) Ownable(msg.sender) {

245:     function setDesiredAPY(uint256 bps) external onlyOwner {

267:     function setDepletionDuration(uint256 _duration) external onlyOwner {

300:     function setPauser(address _pauser) external onlyOwner {

308:     function setMigrator(address _migrator) external onlyOwner {

318:     function setHook(address _hook) external onlyOwner {

344:     function emergencyTransfer(address recipient) external onlyOwner {

373:     function startPromotion(address token, uint256 amount, uint256 duration) external onlyOwner whenNotPaused {

401:     function topUpPromotion(uint256 amount) external onlyOwner {

422:     function setPromoDepletionDuration(uint256 duration) external onlyOwner {

448:     function beginFlush() external onlyOwner {

530:     function finalizePromotion(address leftoverRecipient) external onlyOwner {

558:     function abortFlush() external onlyOwner {

```

