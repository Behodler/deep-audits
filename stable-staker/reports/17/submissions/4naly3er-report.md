# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 21 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 27 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 1 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 7 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 6 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 183 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 85 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 19 |
| [GAS-9](#GAS-9) | Stack variable used as a cheaper cache for a state variable is only used once | 2 |
| [GAS-10](#GAS-10) | State variables only set in the constructor should be declared `immutable` | 7 |
| [GAS-11](#GAS-11) | Functions guaranteed to revert when called by normal users can be marked `payable` | 29 |
| [GAS-12](#GAS-12) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 15 |
| [GAS-13](#GAS-13) | Using `private` rather than `public` for constants, saves gas | 9 |
| [GAS-14](#GAS-14) | Splitting require() statements that use && saves gas | 1 |
| [GAS-15](#GAS-15) | Increments/decrements can be unchecked in for-loops | 11 |
| [GAS-16](#GAS-16) | Use != 0 instead of > 0 for unsigned integer comparison | 48 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (21)*:
```solidity
File: src/CrossVersionMigrator.sol

166:             total += amounts[i];

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

173:                 parked[token][users[i]] += amt;

176:                 totalParked[token] += amt;

177:                 total += amt;

218:             total += parked[token][user];

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

391:         user.amount += credited;

392:         pool.totalStaked += credited;

419:             unclaimedReward[token][msg.sender] += pending;

806:             total += credit;

943:         info.amount += credited;

944:         pool.totalStaked += credited;

980:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

1091:             pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

1103:                 unclaimedReward[token][account] += pending;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

340:         user.amount += credited;

341:         pool.totalStaked += credited;

542:             total += credit;

671:         info.amount += credited;

672:         pool.totalStaked += credited;

689:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

762:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (27)*:
```solidity
File: src/CrossVersionMigrator.sol

126:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

127:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

131:         require(address(_staker) != address(0), "InPlaceMigrator: zero staker");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

245:         require(address(_antimatter) != address(0), "StableStaker: zero antimatter");

253:         require(token != address(0), "StableStaker: zero token");

318:         if (address(old) != address(0)) {

345:         if (address(strategy) != address(0)) {

721:         uint256 booked = address(strategy) == address(0) ? 0 : strategy.principalOf(token, address(this));

740:             address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0,

747:             IERC20(token).forceApprove(address(strategy), 0);

1029:         return _isUnderwater(token, strategy);

1059:             return true;

1143:         }

1175:         return strategy.previewExitFor(token, address(this), netWanted);

1183:         IERC20 t = IERC20(token);

1214:         uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;

1215:         uint256 bal = IERC20(token).balanceOf(address(this));

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

203:         require(address(_phUSD) != address(0), "StableStaker: zero phUSD");

211:         require(token != address(0), "StableStaker: zero token");

269:         if (address(old) != address(0)) {

296:         if (address(strategy) != address(0)) {

487:             address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0,

494:             IERC20(token).forceApprove(address(strategy), 0);

736:             return false;

798:             return amount; // idle hold: full credit

815:             return amount;

848:         uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (1)*:
```solidity
File: src/StableStakerV2.sol

100:     bool public claimEnabled;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (7)*:
```solidity
File: src/CrossVersionMigrator.sol

165:         for (uint256 i = 0; i < amounts.length; i++) {

176:         for (uint256 i = 0; i < users.length; i++) {

237:         for (uint256 i = 0; i < tokens.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

170:         for (uint256 i = 0; i < users.length; i++) {

371:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

802:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

538:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (6)*:
```solidity
File: src/CrossVersionMigrator.sol

150:         require(!probed || destMigrator == address(this), "Migrator: destination not wired");

175:         uint256 migratedCount;

184:             token, migratedCount, total, versionOf(address(oldStaker)), versionOf(address(newStaker))

186:     }

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/StableStakerV2.sol

604:         if (excess > 0) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

77:         emit MinterSet(minter, canMint, mintVersion);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (183)*:
```solidity
File: src/CrossVersionMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import "./interfaces/IStableStakerMigratable.sol";

165:         for (uint256 i = 0; i < amounts.length; i++) {

166:             total += amounts[i];

176:         for (uint256 i = 0; i < users.length; i++) {

179:                 migratedCount++;

237:         for (uint256 i = 0; i < tokens.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

8: import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

9: import "@openzeppelin/contracts/utils/math/Math.sol";

10: import "./interfaces/IStableStaker.sol";

170:         for (uint256 i = 0; i < users.length; i++) {

173:                 parked[token][users[i]] += amt;

176:                 totalParked[token] += amt;

177:                 total += amt;

178:                 count++;

212:         uint256 sliceLen = end - start;

215:         for (uint256 i = 0; i < sliceLen; i++) {

216:             address user = set.at(start + i);

218:             total += parked[token][user];

231:         for (uint256 i = 0; i < sliceLen; i++) {

241:             totalParked[token] -= amt;

243:             count++;

269:         staker.depositFor(token, user, amt); // funded from parked principal (as today)

271:         uint256 credited = amountAfter - amountBefore; // > 0: depositFor reverts on zero credit

277:             topup = Math.mulDiv(amt - credited, amt, credited);

282:                 topup <= IERC20(token).balanceOf(address(this)) - totalParked[token],

283:                 "InPlaceMigrator: top-up surplus exhausted"

285:             staker.depositFor(token, user, topup); // funded from migrator surplus balance

289:         uint256 finalCredited = finalAmount - amountBefore;

293:         require(finalCredited >= amt - amt / 1000, "InPlaceMigrator: par not restored");

311:             block.timestamp >= migrationBegin[token][msg.sender] + migrationTimeout,

318:         totalParked[token] -= amount;

339:         uint256 surplus = IERC20(token).balanceOf(address(this)) - totalParked[token];

370:         users = new address[](end - start);

371:         for (uint256 i = 0; i < users.length; i++) {

372:             users[i] = set.at(start + i);

382:         return begin + migrationTimeout;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/Pausable.sol";

6: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

9: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

10: import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

11: import "./interfaces/IAntimatter.sol";

12: import "pauser/interfaces/IPausable.sol";

13: import "reflax-yield-vault/interfaces/IYieldStrategy.sol";

14: import "./interfaces/IStableStaker.sol";

104:         uint256 antimatterPerSecond; // current emission rate (Antimatter wei per second)

105:         uint256 accAntimatterPerShare; // accumulated Antimatter per staked unit, scaled by ACC_PRECISION

106:         uint256 lastRewardTime; // last time the pool accrued

107:         uint256 totalStaked; // total principal staked in this pool

112:         uint256 amount; // staked principal

113:         uint256 rewardDebt; // accounting baseline: amount * accAntimatterPerShare / ACC_PRECISION at last settle

164:         uint256 realized; // R: token realized into this contract by the full strategy exit

165:         uint256 principalSnapshot; // P: poolInfo[token].totalStaked captured at initiateMigration

266:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

391:         user.amount += credited;

392:         pool.totalStaked += credited;

393:         user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

410:         uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;

411:         user.amount -= amount;

412:         pool.totalStaked -= amount;

413:         user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

419:             unclaimedReward[token][msg.sender] += pending;

444:         uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;

445:         uint256 owed = unclaimedReward[token][msg.sender] + pending;

448:         user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

525:         uint256 netWanted; // the stable half the annihilation needs, in `token` decimals

526:         uint256 gross; // the principal the caller gives up to obtain it

527:         uint256 netFloor; // the least the exit may deliver before this call is a shortfall

528:         uint256 excessBase; // reward that outran the principal outright; minted to the caller

539:                     + ((user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt);

540:                 uint256 principalAsAntimatter = user.amount * scale;

544:                 netWanted = capped / scale;

545:                 excessBase = owed - capped;

548:                 unclaimedReward[token][msg.sender] = capped - netWanted * scale;

559:                 netFloor = grossQuote == 0 ? 0 : (netQuote * gross) / grossQuote;

565:             user.amount -= gross;

566:             pool.totalStaked -= gross;

567:             user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

587:             uint256 allowance = EXIT_ROUNDING_ALLOWANCE + (netFloor * EXIT_ROUNDING_ALLOWANCE_BPS) / MAX_BPS;

588:             uint256 floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0;

591:             surplus = received - netUsed;

593:         uint256 annihilatable = netUsed * scale;

596:         uint256 excess = excessBase + (netWanted - netUsed) * scale;

631:         poolInfo[token].totalStaked -= amount;

802:         for (uint256 i = 0; i < users.length; i++) {

806:             total += credit;

830:         uint256 S = mig.realized < P ? mig.realized : P; // min(R, P): caps credits at par

831:         credit = (amt * S) / P;

835:         uint256 pending = (amt * pool.accAntimatterPerShare) / ACC_PRECISION - info.rewardDebt;

837:         uint256 owed = unclaimedReward[token][account] + pending;

842:         pool.totalStaked -= amt;

943:         info.amount += credited;

944:         pool.totalStaked += credited;

945:         info.rewardDebt = (info.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

969:         return unclaimedReward[token][account] + _pendingReward(token, account);

978:             uint256 elapsed = block.timestamp - pool.lastRewardTime;

979:             uint256 reward = elapsed * pool.antimatterPerSecond;

980:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

983:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

1002:         address[] memory out = new address[](end - start);

1003:         for (uint256 i = start; i < end; i++) {

1004:             out[i - start] = set.at(i);

1088:         uint256 elapsed = block.timestamp - pool.lastRewardTime;

1089:         uint256 reward = elapsed * pool.antimatterPerSecond;

1091:             pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

1101:             uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;

1103:                 unclaimedReward[token][account] += pending;

1113:         return t.balanceOf(address(this)) - balanceBefore;

1126:         return 10 ** (18 - dec);

1142:             return amount; // idle hold: full credit

1197:         return t.balanceOf(address(this)) - balanceBefore;

1216:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/interfaces/IStableStaker.sol

4: import "./IStableStakerMigratable.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/interfaces/IStableStaker.sol)

```solidity
File: src/versions/v1/IStableStakerV1.sol

4: import "flax-token/IFlax.sol";

5: import "reflax-yield-vault/interfaces/IYieldStrategy.sol";

6: import "../../interfaces/IStableStakerMigratable.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/IStableStakerV1.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/Pausable.sol";

6: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

10: import "flax-token/IFlax.sol";

11: import "pauser/interfaces/IPausable.sol";

12: import "reflax-yield-vault/interfaces/IYieldStrategy.sol";

100:         uint256 phusdPerSecond; // current emission rate (phUSD wei per second)

101:         uint256 accPhusdPerShare; // accumulated phUSD per staked unit, scaled by ACC_PRECISION

102:         uint256 lastRewardTime; // last time the pool accrued

103:         uint256 totalStaked; // total principal staked in this pool

108:         uint256 amount; // staked principal

109:         uint256 rewardDebt; // accounting baseline: amount * accPhusdPerShare / ACC_PRECISION at last settle

153:         uint256 realized; // R: token realized into this contract by the full strategy exit

154:         uint256 principalSnapshot; // P: poolInfo[token].totalStaked captured at initiateMigration

224:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

340:         user.amount += credited;

341:         pool.totalStaked += credited;

342:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

358:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

359:         user.amount -= amount;

360:         pool.totalStaked -= amount;

361:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

381:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

383:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

402:         poolInfo[token].totalStaked -= amount;

538:         for (uint256 i = 0; i < users.length; i++) {

542:             total += credit;

565:         uint256 S = mig.realized < P ? mig.realized : P; // min(R, P): caps credits at par

566:         credit = (amt * S) / P;

570:         uint256 pending = (amt * pool.accPhusdPerShare) / ACC_PRECISION - info.rewardDebt;

574:         pool.totalStaked -= amt;

671:         info.amount += credited;

672:         pool.totalStaked += credited;

673:         info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;

687:             uint256 elapsed = block.timestamp - pool.lastRewardTime;

688:             uint256 reward = elapsed * pool.phusdPerSecond;

689:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

692:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

711:         address[] memory out = new address[](end - start);

712:         for (uint256 i = start; i < end; i++) {

713:             out[i - start] = set.at(i);

759:         uint256 elapsed = block.timestamp - pool.lastRewardTime;

760:         uint256 reward = elapsed * pool.phusdPerSecond;

762:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

770:             uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

782:         return t.balanceOf(address(this)) - balanceBefore;

798:             return amount; // idle hold: full credit

831:         return t.balanceOf(address(this)) - balanceBefore;

850:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

31: import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

32: import "@openzeppelin/contracts/access/Ownable.sol";

33: import "./IFlax.sol";

116:         mintVersion++;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

```solidity
File: src/versions/v1/vendor/IFlax.sol

31: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

32: import "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/IFlax.sol)

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (85)*:
```solidity
File: src/CrossVersionMigrator.sol

126:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

127:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

128:         require(address(_oldStaker) != address(_newStaker), "Migrator: aliased stakers");

148:         require(_isRegisteredOn(address(newStaker), token), "Migrator: destination token not registered");

150:         require(!probed || destMigrator == address(this), "Migrator: destination not wired");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

131:         require(address(_staker) != address(0), "InPlaceMigrator: zero staker");

209:         require(start <= end, "InPlaceMigrator: bad range");

293:         require(finalCredited >= amt - amt / 1000, "InPlaceMigrator: par not restored");

309:         require(amount > 0, "InPlaceMigrator: nothing parked");

340:         require(amount <= surplus, "InPlaceMigrator: cannot touch parked principal");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

224:         require(msg.sender == pauser, "StableStaker: only pauser");

229:         require(msg.sender == migrator, "StableStaker: only migrator");

234:         require(_registeredTokens.contains(token), "StableStaker: unknown token");

245:         require(address(_antimatter) != address(0), "StableStaker: zero antimatter");

253:         require(token != address(0), "StableStaker: zero token");

254:         require(_registeredTokens.add(token), "StableStaker: token exists");

307:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

315:         require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");

325:             require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");

370:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

379:         require(amount > 0, "StableStaker: amount=0");

382:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

390:         require(credited > 0, "StableStaker: nothing credited");

401:         require(amount > 0, "StableStaker: amount=0");

404:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

407:         require(user.amount >= amount, "StableStaker: insufficient stake");

440:         require(claimEnabled, "StableStaker: claim disabled");

446:         require(owed > 0, "StableStaker: nothing to claim");

517:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

521:         require(autoAnnihilateAvailable(token), "StableStaker: token not annihilatable");

546:                 require(netWanted > 0 || excessBase > 0, "StableStaker: nothing to annihilate");

557:                 require(netWanted == 0 || grossQuote > 0, "StableStaker: exit unavailable");

589:             require(received > 0 && received >= floorWithAllowance, "StableStaker: exit shortfall");

623:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

626:         require(amount > 0, "StableStaker: nothing staked");

693:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

798:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

865:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

866:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

903:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

904:         require(_stakers[token].length() == 0, "StableStaker: stakers remain");

905:         require(poolInfo[token].totalStaked == 0, "StableStaker: principal remains");

932:         require(amount > 0, "StableStaker: amount=0");

934:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

942:         require(credited > 0, "StableStaker: nothing credited");

1001:         require(start <= end, "StableStaker: bad range");

1125:         require(dec <= 18, "StableStaker: unsupported decimals");

1193:             revert("StableStaker: strategy underwater");

1213:         require(to != address(0), "StableStaker: zero recipient");

1216:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

182:         require(msg.sender == pauser, "StableStaker: only pauser");

187:         require(msg.sender == migrator, "StableStaker: only migrator");

192:         require(_registeredTokens.contains(token), "StableStaker: unknown token");

203:         require(address(_phUSD) != address(0), "StableStaker: zero phUSD");

211:         require(token != address(0), "StableStaker: zero token");

212:         require(_registeredTokens.add(token), "StableStaker: token exists");

258:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

266:         require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");

276:             require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");

320:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

328:         require(amount > 0, "StableStaker: amount=0");

331:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

339:         require(credited > 0, "StableStaker: nothing credited");

349:         require(amount > 0, "StableStaker: amount=0");

352:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

355:         require(user.amount >= amount, "StableStaker: insufficient stake");

382:         require(pending > 0, "StableStaker: nothing to claim");

396:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

399:         require(amount > 0, "StableStaker: nothing staked");

464:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

534:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

594:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

595:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

632:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

633:         require(_stakers[token].length() == 0, "StableStaker: stakers remain");

634:         require(poolInfo[token].totalStaked == 0, "StableStaker: principal remains");

660:         require(amount > 0, "StableStaker: amount=0");

662:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

670:         require(credited > 0, "StableStaker: nothing credited");

710:         require(start <= end, "StableStaker: bad range");

827:             revert("StableStaker: strategy underwater");

847:         require(to != address(0), "StableStaker: zero recipient");

850:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

89:         require(minterInfo.canMint, "phUSD: caller is not authorized to mint");

92:         require(minterInfo.mintVersion == mintVersion, "phUSD: minter version is outdated");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (19)*:
```solidity
File: src/InPlaceMigrator.sol

226:         if (IERC20(token).balanceOf(address(this)) > 0) {

227:             IERC20(token).forceApprove(address(staker), IERC20(token).balanceOf(address(this)));

282:                 topup <= IERC20(token).balanceOf(address(this)) - totalParked[token],

339:         uint256 surplus = IERC20(token).balanceOf(address(this)) - totalParked[token];

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

351:             uint256 idleBalance = IERC20(token).balanceOf(address(this));

764:         uint256 R = IERC20(token).balanceOf(address(this));

1111:         uint256 balanceBefore = t.balanceOf(address(this));

1113:         return t.balanceOf(address(this)) - balanceBefore;

1188:             if (t.balanceOf(address(this)) >= amount) {

1195:         uint256 balanceBefore = t.balanceOf(address(this));

1197:         return t.balanceOf(address(this)) - balanceBefore;

1215:         uint256 bal = IERC20(token).balanceOf(address(this));

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

302:             uint256 idleBalance = IERC20(token).balanceOf(address(this));

780:         uint256 balanceBefore = t.balanceOf(address(this));

782:         return t.balanceOf(address(this)) - balanceBefore;

822:             if (t.balanceOf(address(this)) >= amount) {

829:         uint256 balanceBefore = t.balanceOf(address(this));

831:         return t.balanceOf(address(this)) - balanceBefore;

849:         uint256 bal = IERC20(token).balanceOf(address(this));

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="GAS-9"></a>[GAS-9] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

286:         address old = pauser;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

237:         address old = pauser;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="GAS-10"></a>[GAS-10] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (7)*:
```solidity
File: src/CrossVersionMigrator.sol

130:         newStaker = _newStaker;

131:     }

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

138:         staker = _staker;

139:         migrationTimeout = _migrationTimeout;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

246:         antimatter = _antimatter;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

204:         phUSD = _phUSD;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

61:         mintVersion = 0;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="GAS-11"></a>[GAS-11] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (29)*:
```solidity
File: src/CrossVersionMigrator.sol

147:     function initiateMigration(address token) external onlyOwner {

161:     function migrate(address token, address[] calldata users) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

150:     function initiateMigration(address token) external onlyOwner {

165:     function migrateOut(address token, address[] calldata users) external onlyOwner nonReentrant {

203:     function migrateIn(address token, uint256 start, uint256 end) external onlyOwner nonReentrant {

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

252:     function addToken(address token) external onlyOwner {

264:     function antimatterPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

272:     function setMigrator(address _migrator) external onlyOwner {

279:     function setClaimEnabled(bool enabled) external onlyOwner {

285:     function setPauser(address _pauser) external onlyOwner {

306:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

364:     function pause() external override onlyPauser {

692:     function initiateMigration(address token) external override nonReentrant onlyMigrator poolExists(token) {

902:     function finalizeAndReset(address token) external onlyOwner poolExists(token) {

1212:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

210:     function addToken(address token) external onlyOwner {

222:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

230:     function setMigrator(address _migrator) external onlyOwner {

236:     function setPauser(address _pauser) external onlyOwner {

257:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

314:     function pause() external override onlyPauser {

463:     function initiateMigration(address token) external nonReentrant onlyMigrator poolExists(token) {

631:     function finalizeAndReset(address token) external onlyOwner poolExists(token) {

846:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

71:     function setMinter(address minter, bool canMint) external override onlyOwner {

115:     function revokeAllMintPrivileges() external override onlyOwner {

164:     function transferOwnership(address newOwner) public override(Ownable, IFlax) onlyOwner {

171:     function renounceOwnership() public override(Ownable, IFlax) onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

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

*Instances (15)*:
```solidity
File: src/CrossVersionMigrator.sol

165:         for (uint256 i = 0; i < amounts.length; i++) {

176:         for (uint256 i = 0; i < users.length; i++) {

179:                 migratedCount++;

237:         for (uint256 i = 0; i < tokens.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

170:         for (uint256 i = 0; i < users.length; i++) {

178:                 count++;

215:         for (uint256 i = 0; i < sliceLen; i++) {

231:         for (uint256 i = 0; i < sliceLen; i++) {

243:             count++;

371:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

802:         for (uint256 i = 0; i < users.length; i++) {

1003:         for (uint256 i = start; i < end; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

538:         for (uint256 i = 0; i < users.length; i++) {

712:         for (uint256 i = start; i < end; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

116:         mintVersion++;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="GAS-13"></a>[GAS-13] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (9)*:
```solidity
File: src/InPlaceMigrator.sol

92:     uint256 public constant MIN_TIMEOUT = 1 days;

96:     uint256 public constant MAX_TIMEOUT = 30 days;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

48:     uint256 public constant ACC_PRECISION = 1e18;

51:     uint256 public constant SECONDS_PER_DAY = 86400;

58:     uint256 public constant STAKER_VERSION = 2;

70:     uint256 public constant EXIT_ROUNDING_ALLOWANCE = 2;

78:     uint256 public constant EXIT_ROUNDING_ALLOWANCE_BPS = 1;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

84:     uint256 public constant ACC_PRECISION = 1e18;

87:     uint256 public constant SECONDS_PER_DAY = 86400;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="GAS-14"></a>[GAS-14] Splitting require() statements that use && saves gas

*Instances (1)*:
```solidity
File: src/StableStakerV2.sol

589:             require(received > 0 && received >= floorWithAllowance, "StableStaker: exit shortfall");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

### <a name="GAS-15"></a>[GAS-15] Increments/decrements can be unchecked in for-loops
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
File: src/CrossVersionMigrator.sol

165:         for (uint256 i = 0; i < amounts.length; i++) {

176:         for (uint256 i = 0; i < users.length; i++) {

237:         for (uint256 i = 0; i < tokens.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

170:         for (uint256 i = 0; i < users.length; i++) {

215:         for (uint256 i = 0; i < sliceLen; i++) {

231:         for (uint256 i = 0; i < sliceLen; i++) {

371:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

802:         for (uint256 i = 0; i < users.length; i++) {

1003:         for (uint256 i = start; i < end; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

538:         for (uint256 i = 0; i < users.length; i++) {

712:         for (uint256 i = start; i < end; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="GAS-16"></a>[GAS-16] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (48)*:
```solidity
File: src/CrossVersionMigrator.sol

177:             if (amounts[i] > 0) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

172:             if (amt > 0) {

226:         if (IERC20(token).balanceOf(address(this)) > 0) {

271:         uint256 credited = amountAfter - amountBefore; // > 0: depositFor reverts on zero credit

309:         require(amount > 0, "InPlaceMigrator: nothing parked");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

335:             if (staked > 0) {

352:             if (idleBalance > 0) {

379:         require(amount > 0, "StableStaker: amount=0");

390:         require(credited > 0, "StableStaker: nothing credited");

401:         require(amount > 0, "StableStaker: amount=0");

418:         if (pending > 0) {

446:         require(owed > 0, "StableStaker: nothing to claim");

546:                 require(netWanted > 0 || excessBase > 0, "StableStaker: nothing to annihilate");

557:                 require(netWanted == 0 || grossQuote > 0, "StableStaker: exit unavailable");

576:         if (gross > 0) {

589:             require(received > 0 && received >= floorWithAllowance, "StableStaker: exit shortfall");

598:         if (annihilatable > 0) {

604:         if (excess > 0) {

607:         if (surplus > 0) {

626:         require(amount > 0, "StableStaker: nothing staked");

731:         if (booked > 0) {

808:         if (total > 0) {

848:         if (owed > 0) {

866:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

932:         require(amount > 0, "StableStaker: amount=0");

942:         require(credited > 0, "StableStaker: nothing credited");

977:         if (poolState[token] == PoolState.Active && block.timestamp > pool.lastRewardTime && pool.totalStaked > 0) {

1067:         return grossQuote > 0;

1090:         if (reward > 0) {

1100:         if (user.amount > 0) {

1102:             if (pending > 0) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

286:             if (staked > 0) {

303:             if (idleBalance > 0) {

328:         require(amount > 0, "StableStaker: amount=0");

339:         require(credited > 0, "StableStaker: nothing credited");

349:         require(amount > 0, "StableStaker: amount=0");

366:         if (pending > 0) {

382:         require(pending > 0, "StableStaker: nothing to claim");

399:         require(amount > 0, "StableStaker: nothing staked");

544:         if (total > 0) {

577:         if (pending > 0) {

595:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

660:         require(amount > 0, "StableStaker: amount=0");

670:         require(credited > 0, "StableStaker: nothing credited");

686:         if (poolState[token] == PoolState.Active && block.timestamp > pool.lastRewardTime && pool.totalStaked > 0) {

761:         if (reward > 0) {

769:         if (user.amount > 0) {

771:             if (pending > 0) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 3 |
| [NC-2](#NC-2) | Missing checks for `address(0)` when assigning values to address state variables | 2 |
| [NC-3](#NC-3) | `constant`s should be defined rather than using magic numbers | 8 |
| [NC-4](#NC-4) | Control structures do not follow the Solidity Style Guide | 9 |
| [NC-5](#NC-5) | Critical Changes Should Use Two-step Procedure | 2 |
| [NC-6](#NC-6) | Consider disabling `renounceOwnership()` | 5 |
| [NC-7](#NC-7) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 33 |
| [NC-8](#NC-8) | Event missing indexed field | 2 |
| [NC-9](#NC-9) | Events that mark critical parameter changes should contain both the old and the new value | 9 |
| [NC-10](#NC-10) | Function ordering does not follow the Solidity style guide | 3 |
| [NC-11](#NC-11) | Functions should not be longer than 50 lines | 125 |
| [NC-12](#NC-12) | Lack of checks in setters | 6 |
| [NC-13](#NC-13) | Incomplete NatSpec: `@param` is missing on actually documented functions | 24 |
| [NC-14](#NC-14) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 8 |
| [NC-15](#NC-15) | Constant state variables defined more than once | 4 |
| [NC-16](#NC-16) | Consider using named mappings | 18 |
| [NC-17](#NC-17) | Owner can renounce while system is paused | 2 |
| [NC-18](#NC-18) | Adding a `return` statement when the function defines a named return variable, is redundant | 16 |
| [NC-19](#NC-19) | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| [NC-20](#NC-20) | Use Underscores for Number Literals (add an underscore every 3 digits) | 3 |
| [NC-21](#NC-21) | Event is missing `indexed` fields | 44 |
| [NC-22](#NC-22) | Constants should be defined rather than using magic numbers | 1 |
| [NC-23](#NC-23) | Variables need not be initialized to zero | 10 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (3)*:
```solidity
File: src/CrossVersionMigrator.sol

201:         (bool ok, bytes memory data) = staker.staticcall(abi.encodeWithSignature("STAKER_VERSION()"));

217:         (bool ok, bytes memory data) = staker.staticcall(abi.encodeWithSignature("migrator()"));

234:         (bool ok, bytes memory data) = staker.staticcall(abi.encodeWithSignature("getStakedTokens()"));

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

### <a name="NC-2"></a>[NC-2] Missing checks for `address(0)` when assigning values to address state variables

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

287:         pauser = _pauser;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

238:         pauser = _pauser;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-3"></a>[NC-3] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (8)*:
```solidity
File: src/CrossVersionMigrator.sol

202:         if (!ok || data.length < 32) return 1;

218:         if (!ok || data.length < 32) return (address(0), false);

235:         if (!ok || data.length < 64) return true;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

293:         require(finalCredited >= amt - amt / 1000, "InPlaceMigrator: par not restored");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

1054:         if (!ok || data.length != 32) {

1063:         if (!previewOk || previewData.length != 64) {

1125:         require(dec <= 18, "StableStaker: unsupported decimals");

1126:         return 10 ** (18 - dec);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

### <a name="NC-4"></a>[NC-4] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (9)*:
```solidity
File: src/CrossVersionMigrator.sol

202:         if (!ok || data.length < 32) return 1;

218:         if (!ok || data.length < 32) return (address(0), false);

235:         if (!ok || data.length < 64) return true;

238:             if (tokens[i] == token) return true;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/versions/v1/IStableStakerV1.sol

4: import "flax-token/IFlax.sol";

185:     function phUSD() external view returns (IFlax);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/IStableStakerV1.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

10: import "flax-token/IFlax.sol";

90:     IFlax public immutable phUSD;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

33: import "./IFlax.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="NC-5"></a>[NC-5] Critical Changes Should Use Two-step Procedure
The critical procedures should be two step process.

See similar findings in previous Code4rena contests for reference: <https://code4rena.com/reports/2022-06-illuminate/#2-critical-changes-should-use-two-step-procedure>

**Recommended Mitigation Steps**

Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

306:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

257:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-6"></a>[NC-6] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (5)*:
```solidity
File: src/CrossVersionMigrator.sol

101: contract CrossVersionMigrator is Ownable {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

60: contract InPlaceMigrator is Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

43: contract StableStakerV2 is Ownable, Pausable, ReentrancyGuard, IPausable, IStableStaker {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

79: contract StableStakerV1 is Ownable, Pausable, ReentrancyGuard, IPausable {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

45: contract FlaxToken is ERC20, Ownable, IFlax {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="NC-7"></a>[NC-7] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (33)*:
```solidity
File: src/StableStakerV2.sol

307:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

379:         require(amount > 0, "StableStaker: amount=0");

382:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

390:         require(credited > 0, "StableStaker: nothing credited");

401:         require(amount > 0, "StableStaker: amount=0");

404:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

517:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

623:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

626:         require(amount > 0, "StableStaker: nothing staked");

693:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

798:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

866:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

868:         // Effects (mint pending, zero position, remove from set) happen inside _exitPosition; the

904:         require(_stakers[token].length() == 0, "StableStaker: stakers remain");

933:         // Frozen on the migrating (old) staker: a deposit would change `P`. See TERMINAL MIGRATION.

935:         PoolInfo storage pool = poolInfo[token];

944:         pool.totalStaked += credited;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

258:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

328:         require(amount > 0, "StableStaker: amount=0");

331:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

339:         require(credited > 0, "StableStaker: nothing credited");

349:         require(amount > 0, "StableStaker: amount=0");

352:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

396:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

399:         require(amount > 0, "StableStaker: nothing staked");

464:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

534:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

594:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

595:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

632:         require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");

661:         // Frozen on the migrating (old) staker: a deposit would change `P`. See TERMINAL MIGRATION.

662:         require(poolState[token] == PoolState.Active, "StableStaker: pool not active");

670:         require(credited > 0, "StableStaker: nothing credited");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-8"></a>[NC-8] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

189:     event ClaimEnabledSet(bool enabled);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/vendor/IFlax.sol

71:     event MintPrivilegesRevoked(uint256 newMintVersion);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/IFlax.sol)

### <a name="NC-9"></a>[NC-9] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (9)*:
```solidity
File: src/StableStakerV2.sol

272:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

279:     function setClaimEnabled(bool enabled) external onlyOwner {
             claimEnabled = enabled;
             emit ClaimEnabledSet(enabled);

285:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

306:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
             require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
             // Strategy (un)wiring is an EMPTY-POOL-only operation. Once a pool holds staked principal,
             // moving that principal in place desyncs `totalStaked` from `strategy.principalOf` whenever
             // the deposit/exit haircuts (market/AMM strategies). That is the shared root cause of
             // ss6m1/M-01 (first-adoption sweep), M-06 (underwater swap) and M-07 (AMM-execution swap):
             // no guard compares `totalStaked` against strategy principal, so the desync is silent.
             // Principal may only move through the realize-once-and-socialize terminal-migration path:
             //   initiateMigration -> batchMigrate/userMigrate -> finalizeAndReset (pool now empty) -> setYieldStrategy
             require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");
     
             IYieldStrategy old = yieldStrategy[token];
             if (address(old) != address(0)) {
                 // M-06: refuse to swap an underwater strategy in place. Swapping while below par
                 // silently lifts the underwater-withdraw block and FCFS-concentrates the realized
                 // loss on the last withdrawer. An impaired strategy must instead be wound down via
                 // initiateMigration -> batchMigrate -> finalizeAndReset, which socializes the loss
                 // proportionally via the (R,P) snapshot. At/above par swaps are unaffected. An empty
                 // old strategy (principalOf == 0) is not underwater, so first-adoption/idle swaps pass.
                 require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");
     
                 // Drain the full client position out of the old strategy into this contract so the new
                 // strategy (or idle hold) can re-custody it. Best-effort: caps at recoverable principal,
                 // underwater guard OFF — same realization path as initiateMigration. Above-par yield is
                 // left behind in the old strategy as protocol-owned value (StableStaker owes users
                 // principal only). `_routeExit` reads yieldStrategy[token], which is still `old` here.
                 // Skip when there is no principal to realize: the strategy's withdraw reverts on a
                 // zero amount, so a drain at totalStaked == 0 must be a no-op (first-adoption / idle).
                 uint256 staked = poolInfo[token].totalStaked;
                 if (staked > 0) {
                     _routeExit(token, staked, false);
                 }
     
                 // Revoke the old strategy's spending allowance.
                 IERC20(token).forceApprove(address(old), 0);
             }
     
             yieldStrategy[token] = strategy;
     
             if (address(strategy) != address(0)) {
                 // Approve the new strategy to pull this token for deposits.
                 IERC20(token).forceApprove(address(strategy), type(uint256).max);
     
                 // Sweep any idle balance already sitting in the contract into the new strategy so that
                 // accounting is consistent immediately (at first adoption this equals staked principal).
                 uint256 idleBalance = IERC20(token).balanceOf(address(this));
                 if (idleBalance > 0) {
                     uint256 credited = strategy.deposit(token, idleBalance, address(this));
                     emit ProtocolPrincipalSwept(token, address(strategy), idleBalance, credited);
                 }
             }
     
             emit YieldStrategySet(token, address(old), address(strategy));

306:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
             require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
             // Strategy (un)wiring is an EMPTY-POOL-only operation. Once a pool holds staked principal,
             // moving that principal in place desyncs `totalStaked` from `strategy.principalOf` whenever
             // the deposit/exit haircuts (market/AMM strategies). That is the shared root cause of
             // ss6m1/M-01 (first-adoption sweep), M-06 (underwater swap) and M-07 (AMM-execution swap):
             // no guard compares `totalStaked` against strategy principal, so the desync is silent.
             // Principal may only move through the realize-once-and-socialize terminal-migration path:
             //   initiateMigration -> batchMigrate/userMigrate -> finalizeAndReset (pool now empty) -> setYieldStrategy
             require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");
     
             IYieldStrategy old = yieldStrategy[token];
             if (address(old) != address(0)) {
                 // M-06: refuse to swap an underwater strategy in place. Swapping while below par
                 // silently lifts the underwater-withdraw block and FCFS-concentrates the realized
                 // loss on the last withdrawer. An impaired strategy must instead be wound down via
                 // initiateMigration -> batchMigrate -> finalizeAndReset, which socializes the loss
                 // proportionally via the (R,P) snapshot. At/above par swaps are unaffected. An empty
                 // old strategy (principalOf == 0) is not underwater, so first-adoption/idle swaps pass.
                 require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");
     
                 // Drain the full client position out of the old strategy into this contract so the new
                 // strategy (or idle hold) can re-custody it. Best-effort: caps at recoverable principal,
                 // underwater guard OFF — same realization path as initiateMigration. Above-par yield is
                 // left behind in the old strategy as protocol-owned value (StableStaker owes users
                 // principal only). `_routeExit` reads yieldStrategy[token], which is still `old` here.
                 // Skip when there is no principal to realize: the strategy's withdraw reverts on a
                 // zero amount, so a drain at totalStaked == 0 must be a no-op (first-adoption / idle).
                 uint256 staked = poolInfo[token].totalStaked;
                 if (staked > 0) {
                     _routeExit(token, staked, false);
                 }
     
                 // Revoke the old strategy's spending allowance.
                 IERC20(token).forceApprove(address(old), 0);
             }
     
             yieldStrategy[token] = strategy;
     
             if (address(strategy) != address(0)) {
                 // Approve the new strategy to pull this token for deposits.
                 IERC20(token).forceApprove(address(strategy), type(uint256).max);
     
                 // Sweep any idle balance already sitting in the contract into the new strategy so that
                 // accounting is consistent immediately (at first adoption this equals staked principal).
                 uint256 idleBalance = IERC20(token).balanceOf(address(this));
                 if (idleBalance > 0) {
                     uint256 credited = strategy.deposit(token, idleBalance, address(this));
                     emit ProtocolPrincipalSwept(token, address(strategy), idleBalance, credited);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

230:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

236:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

257:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
             require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
             // Strategy (un)wiring is an EMPTY-POOL-only operation. Once a pool holds staked principal,
             // moving that principal in place desyncs `totalStaked` from `strategy.principalOf` whenever
             // the deposit/exit haircuts (market/AMM strategies). That is the shared root cause of
             // ss6m1/M-01 (first-adoption sweep), M-06 (underwater swap) and M-07 (AMM-execution swap):
             // no guard compares `totalStaked` against strategy principal, so the desync is silent.
             // Principal may only move through the realize-once-and-socialize terminal-migration path:
             //   initiateMigration -> batchMigrate/userMigrate -> finalizeAndReset (pool now empty) -> setYieldStrategy
             require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");
     
             IYieldStrategy old = yieldStrategy[token];
             if (address(old) != address(0)) {
                 // M-06: refuse to swap an underwater strategy in place. Swapping while below par
                 // silently lifts the underwater-withdraw block and FCFS-concentrates the realized
                 // loss on the last withdrawer. An impaired strategy must instead be wound down via
                 // initiateMigration -> batchMigrate -> finalizeAndReset, which socializes the loss
                 // proportionally via the (R,P) snapshot. At/above par swaps are unaffected. An empty
                 // old strategy (principalOf == 0) is not underwater, so first-adoption/idle swaps pass.
                 require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");
     
                 // Drain the full client position out of the old strategy into this contract so the new
                 // strategy (or idle hold) can re-custody it. Best-effort: caps at recoverable principal,
                 // underwater guard OFF — same realization path as initiateMigration. Above-par yield is
                 // left behind in the old strategy as protocol-owned value (StableStaker owes users
                 // principal only). `_routeExit` reads yieldStrategy[token], which is still `old` here.
                 // Skip when there is no principal to realize: the strategy's withdraw reverts on a
                 // zero amount, so a drain at totalStaked == 0 must be a no-op (first-adoption / idle).
                 uint256 staked = poolInfo[token].totalStaked;
                 if (staked > 0) {
                     _routeExit(token, staked, false);
                 }
     
                 // Revoke the old strategy's spending allowance.
                 IERC20(token).forceApprove(address(old), 0);
             }
     
             yieldStrategy[token] = strategy;
     
             if (address(strategy) != address(0)) {
                 // Approve the new strategy to pull this token for deposits.
                 IERC20(token).forceApprove(address(strategy), type(uint256).max);
     
                 // Sweep any idle balance already sitting in the contract into the new strategy so that
                 // accounting is consistent immediately (at first adoption this equals staked principal).
                 uint256 idleBalance = IERC20(token).balanceOf(address(this));
                 if (idleBalance > 0) {
                     strategy.deposit(token, idleBalance, address(this));
                 }
             }
     
             emit YieldStrategySet(token, address(old), address(strategy));

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

71:     function setMinter(address minter, bool canMint) external override onlyOwner {
            _authorizedMinters[minter] = MinterInfo({
                canMint: canMint,
                mintVersion: mintVersion
            });
            
            emit MinterSet(minter, canMint, mintVersion);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="NC-10"></a>[NC-10] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (3)*:
```solidity
File: src/InPlaceMigrator.sol

1: 
   Current order:
   external initiateMigration
   external migrateOut
   external migrateIn
   private _reinjectWithTopup
   external claimTimedOut
   external rescueERC20
   external parkedUserCount
   external parkedUsersRange
   external claimableAt
   
   Suggested order:
   external initiateMigration
   external migrateOut
   external migrateIn
   external claimTimedOut
   external rescueERC20
   external parkedUserCount
   external parkedUsersRange
   external claimableAt
   private _reinjectWithTopup

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

1: 
   Current order:
   external addToken
   external antimatterPerDay
   external setMigrator
   external setClaimEnabled
   external setPauser
   external setYieldStrategy
   external pause
   external unpause
   external stake
   external withdraw
   external claim
   external autoAnnihilate
   external emergencyWithdraw
   external initiateMigration
   external batchMigrate
   internal _exitPosition
   external userMigrate
   external finalizeAndReset
   external depositFor
   external pendingReward
   external claimableReward
   internal _pendingReward
   external getStakers
   external getStakersRange
   external stakerCount
   external getStakedTokens
   external withdrawDisabled
   public autoAnnihilateAvailable
   internal _updatePool
   internal _settle
   internal _pullToken
   internal _antimatterScale
   internal _isUnderwater
   internal _routeDeposit
   internal _previewExit
   internal _routeExit
   external rescueERC20
   
   Suggested order:
   external addToken
   external antimatterPerDay
   external setMigrator
   external setClaimEnabled
   external setPauser
   external setYieldStrategy
   external pause
   external unpause
   external stake
   external withdraw
   external claim
   external autoAnnihilate
   external emergencyWithdraw
   external initiateMigration
   external batchMigrate
   external userMigrate
   external finalizeAndReset
   external depositFor
   external pendingReward
   external claimableReward
   external getStakers
   external getStakersRange
   external stakerCount
   external getStakedTokens
   external withdrawDisabled
   external rescueERC20
   public autoAnnihilateAvailable
   internal _exitPosition
   internal _pendingReward
   internal _updatePool
   internal _settle
   internal _pullToken
   internal _antimatterScale
   internal _isUnderwater
   internal _routeDeposit
   internal _previewExit
   internal _routeExit

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

1: 
   Current order:
   external addToken
   external phUSDPerDay
   external setMigrator
   external setPauser
   external setYieldStrategy
   external pause
   external unpause
   external stake
   external withdraw
   external claim
   external emergencyWithdraw
   external initiateMigration
   external batchMigrate
   internal _exitPosition
   external userMigrate
   external finalizeAndReset
   external depositFor
   external pendingReward
   external getStakers
   external getStakersRange
   external stakerCount
   external getStakedTokens
   external withdrawDisabled
   internal _updatePool
   internal _settle
   internal _pullToken
   internal _isUnderwater
   internal _routeDeposit
   internal _routeExit
   external rescueERC20
   
   Suggested order:
   external addToken
   external phUSDPerDay
   external setMigrator
   external setPauser
   external setYieldStrategy
   external pause
   external unpause
   external stake
   external withdraw
   external claim
   external emergencyWithdraw
   external initiateMigration
   external batchMigrate
   external userMigrate
   external finalizeAndReset
   external depositFor
   external pendingReward
   external getStakers
   external getStakersRange
   external stakerCount
   external getStakedTokens
   external withdrawDisabled
   external rescueERC20
   internal _exitPosition
   internal _updatePool
   internal _settle
   internal _pullToken
   internal _isUnderwater
   internal _routeDeposit
   internal _routeExit

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-11"></a>[NC-11] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (125)*:
```solidity
File: src/CrossVersionMigrator.sol

147:     function initiateMigration(address token) external onlyOwner {

161:     function migrate(address token, address[] calldata users) external onlyOwner {

196:     function versionOf(address staker) public view returns (uint256) {

200:     function _versionOf(address staker) internal view returns (uint256) {

216:     function _migratorOf(address staker) internal view returns (address destMigrator, bool probed) {

233:     function _isRegisteredOn(address staker, address token) internal view returns (bool) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

150:     function initiateMigration(address token) external onlyOwner {

165:     function migrateOut(address token, address[] calldata users) external onlyOwner nonReentrant {

203:     function migrateIn(address token, uint256 start, uint256 end) external onlyOwner nonReentrant {

263:     function _reinjectWithTopup(address token, address user, uint256 amt) private {

307:     function claimTimedOut(address token) external nonReentrant {

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

347:     function parkedUserCount(address token) external view returns (uint256) {

357:     function parkedUsersRange(address token, uint256 start, uint256 end)

377:     function claimableAt(address token, address user) external view returns (uint256) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

252:     function addToken(address token) external onlyOwner {

264:     function antimatterPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

272:     function setMigrator(address _migrator) external onlyOwner {

279:     function setClaimEnabled(bool enabled) external onlyOwner {

285:     function setPauser(address _pauser) external onlyOwner {

306:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

378:     function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

400:     function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

439:     function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

516:     function autoAnnihilate(address token, uint256 minPhUSDOut) external nonReentrant whenNotPaused poolExists(token) {

620:     function emergencyWithdraw(address token) external nonReentrant {

692:     function initiateMigration(address token) external override nonReentrant onlyMigrator poolExists(token) {

790:     function batchMigrate(address token, address[] calldata users)

822:     function _exitPosition(address token, address account) internal returns (uint256 credit) {

864:     function userMigrate(address token) external nonReentrant {

902:     function finalizeAndReset(address token) external onlyOwner poolExists(token) {

925:     function depositFor(address token, address user, uint256 amount)

960:     function pendingReward(address token, address account) external view returns (uint256) {

968:     function claimableReward(address token, address account) external view returns (uint256) {

974:     function _pendingReward(address token, address account) internal view returns (uint256) {

987:     function getStakers(address token) external view returns (address[] memory) {

995:     function getStakersRange(address token, uint256 start, uint256 end) external view returns (address[] memory) {

1010:     function stakerCount(address token) external view returns (uint256) {

1015:     function getStakedTokens() external view returns (address[] memory) {

1024:     function withdrawDisabled(address token) external view returns (bool) {

1051:     function autoAnnihilateAvailable(address token) public view returns (bool) {

1099:     function _settle(address token, address account, UserInfo storage user, PoolInfo storage pool) internal {

1109:     function _pullToken(address token, address from, uint256 amount) internal returns (uint256) {

1123:     function _antimatterScale(address token) internal view returns (uint256) {

1131:     function _isUnderwater(address token, IYieldStrategy strategy) internal view returns (bool) {

1139:     function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {

1166:     function _previewExit(address token, uint256 netWanted)

1178:     function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {

1212:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/interfaces/IAntimatter.sol

19:     function mint(address to, uint256 amount) external;

36:     function annihilate(address stable, address recipient, uint256 amount, uint256 minPhUSDOut) external;

46:     function toStableAmount(address stable, uint256 amount) external view returns (uint256);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/interfaces/IAntimatter.sol)

```solidity
File: src/interfaces/IStableStaker.sol

36:     function userInfo(address token, address user) external view returns (uint256 amount, uint256 rewardDebt);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/interfaces/IStableStaker.sol)

```solidity
File: src/interfaces/IStableStakerMigratable.sol

43:     function initiateMigration(address token) external;

58:     function batchMigrate(address token, address[] calldata users) external returns (uint256[] memory amounts);

67:     function depositFor(address token, address user, uint256 amount) external;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/interfaces/IStableStakerMigratable.sol)

```solidity
File: src/versions/v1/IStableStakerV1.sol

88:     function phUSDPerDay(address token, uint256 amountPerDay) external;

97:     function setYieldStrategy(address token, IYieldStrategy strategy) external;

100:     function finalizeAndReset(address token) external;

103:     function rescueERC20(address token, address to, uint256 amount) external;

119:     function pauser() external view returns (address);

124:     function stake(address token, uint256 amount) external;

127:     function withdraw(address token, uint256 amount) external;

133:     function emergencyWithdraw(address token) external;

141:     function pendingReward(address token, address account) external view returns (uint256);

144:     function getStakers(address token) external view returns (address[] memory);

147:     function getStakersRange(address token, uint256 start, uint256 end) external view returns (address[] memory);

150:     function stakerCount(address token) external view returns (uint256);

153:     function getStakedTokens() external view returns (address[] memory);

156:     function withdrawDisabled(address token) external view returns (bool);

169:     function userInfo(address token, address user) external view returns (uint256 amount, uint256 rewardDebt);

173:     function poolState(address token) external view returns (uint8);

176:     function migrationInfo(address token) external view returns (uint256 realized, uint256 principalSnapshot);

179:     function yieldStrategy(address token) external view returns (IYieldStrategy);

182:     function migrator() external view returns (address);

188:     function ACC_PRECISION() external view returns (uint256);

191:     function SECONDS_PER_DAY() external view returns (uint256);

199:     function transferOwnership(address newOwner) external;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/IStableStakerV1.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

210:     function addToken(address token) external onlyOwner {

222:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

230:     function setMigrator(address _migrator) external onlyOwner {

236:     function setPauser(address _pauser) external onlyOwner {

257:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

327:     function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

348:     function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

377:     function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

393:     function emergencyWithdraw(address token) external nonReentrant {

463:     function initiateMigration(address token) external nonReentrant onlyMigrator poolExists(token) {

527:     function batchMigrate(address token, address[] calldata users)

557:     function _exitPosition(address token, address account) internal returns (uint256 credit) {

593:     function userMigrate(address token) external nonReentrant {

631:     function finalizeAndReset(address token) external onlyOwner poolExists(token) {

654:     function depositFor(address token, address user, uint256 amount)

683:     function pendingReward(address token, address account) external view returns (uint256) {

696:     function getStakers(address token) external view returns (address[] memory) {

704:     function getStakersRange(address token, uint256 start, uint256 end) external view returns (address[] memory) {

719:     function stakerCount(address token) external view returns (uint256) {

724:     function getStakedTokens() external view returns (address[] memory) {

733:     function withdrawDisabled(address token) external view returns (bool) {

768:     function _settle(address account, UserInfo storage user, PoolInfo storage pool) internal {

778:     function _pullToken(address token, address from, uint256 amount) internal returns (uint256) {

787:     function _isUnderwater(address token, IYieldStrategy strategy) internal view returns (bool) {

795:     function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {

812:     function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {

846:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

71:     function setMinter(address minter, bool canMint) external override onlyOwner {

85:     function mint(address recipient, uint256 amount) external override {

104:     function burn(address holder, uint256 amount) external override {

115:     function revokeAllMintPrivileges() external override onlyOwner {

127:     function authorizedMinters(address minter) external view override returns (MinterInfo memory info) {

136:     function name() public view override(ERC20, IFlax) returns (string memory) {

143:     function symbol() public view override(ERC20, IFlax) returns (string memory) {

150:     function decimals() public view override(ERC20, IFlax) returns (uint8) {

157:     function owner() public view override(Ownable, IFlax) returns (address) {

164:     function transferOwnership(address newOwner) public override(Ownable, IFlax) onlyOwner {

171:     function renounceOwnership() public override(Ownable, IFlax) onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

```solidity
File: src/versions/v1/vendor/IFlax.sol

79:     function name() external view returns (string memory);

85:     function symbol() external view returns (string memory);

91:     function decimals() external view returns (uint8);

97:     function mintVersion() external view returns (uint256);

104:     function authorizedMinters(address minter) external view returns (MinterInfo memory info);

121:     function setMinter(address minter, bool canMint) external;

130:     function mint(address recipient, uint256 amount) external;

139:     function burn(address holder, uint256 amount) external;

155:     function transferOwnership(address newOwner) external;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/IFlax.sol)

### <a name="NC-12"></a>[NC-12] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (6)*:
```solidity
File: src/StableStakerV2.sol

272:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

279:     function setClaimEnabled(bool enabled) external onlyOwner {
             claimEnabled = enabled;
             emit ClaimEnabledSet(enabled);

285:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

230:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

236:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

71:     function setMinter(address minter, bool canMint) external override onlyOwner {
            _authorizedMinters[minter] = MinterInfo({
                canMint: canMint,
                mintVersion: mintVersion
            });
            
            emit MinterSet(minter, canMint, mintVersion);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="NC-13"></a>[NC-13] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (24)*:
```solidity
File: src/StableStakerV2.sol

251:     /// @notice Register a new stable token as a reward pool.
         function addToken(address token) external onlyOwner {

260:      * @notice Set the daily Antimatter emission budget for a token. Internally converted to a
          *         per-second rate (`amountPerDay / SECONDS_PER_DAY`, rounded down). The pool is
          *         settled at the existing rate first so the change never applies retroactively.
          */
         function antimatterPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

271:     /// @notice Set the address authorized to perform permissioned migration.
         function setMigrator(address _migrator) external onlyOwner {

277:     /// @notice Open or close {claim}. Closed on deployment; see {claimEnabled}.
         /// @dev One transaction, no redeploy — which is the whole reason the teaching phase is a flag.
         function setClaimEnabled(bool enabled) external onlyOwner {

284:     /// @notice Set (or clear, with address(0)) the pauser address.
         function setPauser(address _pauser) external onlyOwner {

292:      * @notice Set (or clear, with address(0)) the yield strategy that custodies `token`'s principal.
          * @dev On set to a non-zero strategy: approves it for unlimited `token` and sweeps any idle balance
          *      already held by the contract into the new strategy (so subsequent withdrawals resolve against
          *      it). When clearing or replacing, the old strategy is best-effort drained (its full client
          *      position is withdrawn into this contract via the same realization path as
          *      {initiateMigration}, underwater guard OFF) and its allowance is reset to 0; the recovered
          *      idle balance is then re-custodied into the new strategy by the idle sweep. The whole
          *      position therefore moves YS1->YS2 in this single call, with no per-user migration.
          *      Above-par yield is left behind in the decoupled old strategy as protocol-owned value
          *      (StableStaker credits users principal only). Blocked during a terminal migration.
          *
          *      Wiring prerequisite: the strategy owner must authorize this contract as a client
          *      (`strategy.setClient(address(this), true)`) before deposits will succeed.
          */
         function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

376:     /// @notice Stake `amount` of `token`. Any pending reward is booked to {unclaimedReward} first;
         ///         nothing is minted here. Claim it with {claim}.
         function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

398:     /// @notice Withdraw `amount` of staked `token`. Any pending reward is booked to {unclaimedReward}
         ///         rather than minted, so principal handling never depends on Antimatter being mintable.
         function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

428:     /// @notice Mint the caller's Antimatter reward for `token` without touching principal: the
         ///         settled-but-unminted {unclaimedReward} backlog plus anything freshly pending.
         ///         {claimableReward} reads the figure it pays.
         /// @dev CLOSED BY DEFAULT since story 025 — see {claimEnabled}. It is no longer the only
         ///      user-facing path that mints: {autoAnnihilate} mints too (to this contract, and to the
         ///      caller for any excess over their principal), and it is the path users are steered to while
         ///      this one is shut.
         ///
         ///      Succeeds for a caller with no position but a non-zero backlog (someone who fully withdrew
         ///      and has not claimed yet). Still `whenNotPaused`, so a pause withholds the backlog too.
         ///      Deliberately has no `PoolState.Active` gate: it moves no principal.
         function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

616:      * @notice Escape hatch: withdraw the caller's full principal for `token`, forfeiting ALL reward —
          *         the live pending AND the settled-but-unminted {unclaimedReward} backlog. Works while
          *         paused and never mints, so a broken mint path can never trap principal.
          */
         function emergencyWithdraw(address token) external nonReentrant {
             // Frozen once terminal migration is engaged: the escape hatch becomes {userMigrate}, which

918:      * @notice Permissioned deposit crediting `user` (see {IStableStaker-depositFor}). Pulls
          *         `amount` of `token` from the migrator. Callable while paused so a freshly deployed
          *         (and possibly paused) target can be seeded.
          * @dev On a token under terminal migration this is the OLD staker and is blocked (would change the
          *      `P` snapshot). The migrator's redeposit target is the NEW (healthy) staker, where this
          *      guard does not trip.
          */
         function depositFor(address token, address user, uint256 amount)
             external
             override
             nonReentrant
             onlyMigrator

1204:      *         (wrong-token transfers, dust, faucet mistakes, idle buffer). Guarded so the owner
           *         cannot withdraw user principal: when a token has no strategy set, user principal
           *         is held idle in this contract and is reserved (= `poolInfo[token].totalStaked`);
           *         when a strategy is set, principal lives inside the strategy and the contract
           *         balance is purely buffer + dust, so the full balance is rescuable.
           * @dev Works while paused — owner rescue is most useful exactly when normal flow is halted.
           *      No `nonReentrant`: there is no state to corrupt after the trailing `safeTransfer`.
           */
          function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
              require(to != address(0), "StableStaker: zero recipient");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

209:     /// @notice Register a new stable token as a reward pool.
         function addToken(address token) external onlyOwner {

218:      * @notice Set the daily phUSD emission budget for a token. Internally converted to a
          *         per-second rate (`amountPerDay / SECONDS_PER_DAY`, rounded down). The pool is
          *         settled at the existing rate first so the change never applies retroactively.
          */
         function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

229:     /// @notice Set the address authorized to perform permissioned migration.
         function setMigrator(address _migrator) external onlyOwner {

235:     /// @notice Set (or clear, with address(0)) the pauser address.
         function setPauser(address _pauser) external onlyOwner {

243:      * @notice Set (or clear, with address(0)) the yield strategy that custodies `token`'s principal.
          * @dev On set to a non-zero strategy: approves it for unlimited `token` and sweeps any idle balance
          *      already held by the contract into the new strategy (so subsequent withdrawals resolve against
          *      it). When clearing or replacing, the old strategy is best-effort drained (its full client
          *      position is withdrawn into this contract via the same realization path as
          *      {initiateMigration}, underwater guard OFF) and its allowance is reset to 0; the recovered
          *      idle balance is then re-custodied into the new strategy by the idle sweep. The whole
          *      position therefore moves YS1->YS2 in this single call, with no per-user migration.
          *      Above-par yield is left behind in the decoupled old strategy as protocol-owned value
          *      (StableStaker credits users principal only). Blocked during a terminal migration.
          *
          *      Wiring prerequisite: the strategy owner must authorize this contract as a client
          *      (`strategy.setClient(address(this), true)`) before deposits will succeed.
          */
         function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

326:     /// @notice Stake `amount` of `token`. Any pending reward is minted to the caller first.
         function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

347:     /// @notice Withdraw `amount` of staked `token`. Any pending reward is minted to the caller.
         function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

376:     /// @notice Mint the caller's pending phUSD reward for `token` without touching principal.
         function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

389:      * @notice Escape hatch: withdraw the caller's full principal for `token`, forfeiting any
          *         pending reward. Works while paused and never touches reward accounting, so a
          *         broken mint path can never trap principal.
          */
         function emergencyWithdraw(address token) external nonReentrant {

647:      * @notice Permissioned deposit crediting `user` (see {IStableStaker-depositFor}). Pulls
          *         `amount` of `token` from the migrator. Callable while paused so a freshly deployed
          *         (and possibly paused) target can be seeded.
          * @dev On a token under terminal migration this is the OLD staker and is blocked (would change the
          *      `P` snapshot). The migrator's redeposit target is the NEW (healthy) staker, where this
          *      guard does not trip.
          */
         function depositFor(address token, address user, uint256 amount)
             external
             nonReentrant

837:      * @notice Owner-only rescue of arbitrary ERC20s that have accumulated in the contract
          *         (wrong-token transfers, dust, faucet mistakes, idle buffer). Guarded so the owner
          *         cannot withdraw user principal: when a token has no strategy set, user principal
          *         is held idle in this contract and is reserved (= `poolInfo[token].totalStaked`);
          *         when a strategy is set, principal lives inside the strategy and the contract
          *         balance is purely buffer + dust, so the full balance is rescuable.
          * @dev Works while paused — owner rescue is most useful exactly when normal flow is halted.
          *      No `nonReentrant`: there is no state to corrupt after the trailing `safeTransfer`.
          */
         function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
             require(to != address(0), "StableStaker: zero recipient");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

162:      * @dev Transfers ownership of the contract
          */
         function transferOwnership(address newOwner) public override(Ownable, IFlax) onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="NC-14"></a>[NC-14] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (8)*:
```solidity
File: src/StableStakerV2.sol

224:         require(msg.sender == pauser, "StableStaker: only pauser");

229:         require(msg.sender == migrator, "StableStaker: only migrator");

370:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

866:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

182:         require(msg.sender == pauser, "StableStaker: only pauser");

187:         require(msg.sender == migrator, "StableStaker: only migrator");

320:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

595:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-15"></a>[NC-15] Constant state variables defined more than once
Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (4)*:
```solidity
File: src/StableStakerV2.sol

48:     uint256 public constant ACC_PRECISION = 1e18;

51:     uint256 public constant SECONDS_PER_DAY = 86400;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

84:     uint256 public constant ACC_PRECISION = 1e18;

87:     uint256 public constant SECONDS_PER_DAY = 86400;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-16"></a>[NC-16] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (18)*:
```solidity
File: src/InPlaceMigrator.sol

79:     mapping(address => mapping(address => uint256)) public parked;

82:     mapping(address => mapping(address => uint256)) public migrationBegin;

85:     mapping(address => EnumerableSet.AddressSet) private _parkedUsers;

88:     mapping(address => uint256) public totalParked;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

117:     mapping(address => PoolInfo) public poolInfo;

120:     mapping(address => mapping(address => UserInfo)) public override userInfo;

123:     mapping(address => EnumerableSet.AddressSet) private _stakers;

130:     mapping(address => mapping(address => uint256)) public unclaimedReward;

138:     mapping(address => IYieldStrategy) public yieldStrategy;

155:     mapping(address => PoolState) public poolState;

169:     mapping(address => MigrationInfo) public migrationInfo;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

113:     mapping(address => PoolInfo) public poolInfo;

116:     mapping(address => mapping(address => UserInfo)) public userInfo;

119:     mapping(address => EnumerableSet.AddressSet) private _stakers;

127:     mapping(address => IYieldStrategy) public yieldStrategy;

144:     mapping(address => PoolState) public poolState;

158:     mapping(address => MigrationInfo) public migrationInfo;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

53:     mapping(address => MinterInfo) private _authorizedMinters;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="NC-17"></a>[NC-17] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

285:     function setPauser(address _pauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

236:     function setPauser(address _pauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-18"></a>[NC-18] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (16)*:
```solidity
File: src/CrossVersionMigrator.sol

207:      * @dev Probes `migrator()` on `staker` without widening `IStableStakerMigratable` — the same
          *      shape as {_versionOf}. Public on both V1 (`StableStakerV1.sol`) and V2.
          * @return destMigrator The address the staker currently recognises as its migrator. Meaningless
          *         unless `probed` is true.
          * @return probed True when the getter answered. FALSE MUST NOT BE READ AS A NEGATIVE ANSWER:
          *         `address(0)` from a failed probe compares unequal to `address(this)` and would
          *         hard-revert an unrecognised-but-valid destination, which is precisely the
          *         version-agnosticism section (A) protects. The caller gates on `probed` first.
          */
         function _migratorOf(address staker) internal view returns (address destMigrator, bool probed) {
             (bool ok, bytes memory data) = staker.staticcall(abi.encodeWithSignature("migrator()"));
             if (!ok || data.length < 32) return (address(0), false);
             return (abi.decode(data, (address)), true);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/StableStakerV2.sol

815:      * @dev Shared terminal-migration exit for one user: mints their frozen pending Antimatter PLUS any
          *      {unclaimedReward} backlog (terminal exit settles everything owed), computes the
          *      snapshot credit `p_i·min(R,P)/P`, zeroes their position and removes them from the staker set.
          *      Returns the credit (0 for an empty position). Used by both {batchMigrate} and {userMigrate},
          *      so a self-migrated user and a batch-migrated user with equal principal get identical credit.
          *      Does NOT transfer the credit — the caller forwards it (CEI).
          */
         function _exitPosition(address token, address account) internal returns (uint256 credit) {
             UserInfo storage info = userInfo[token][account];
             uint256 amt = info.amount;
             if (amt == 0) {
                 return 0;
             }
             MigrationInfo storage mig = migrationInfo[token];
             uint256 P = mig.principalSnapshot;

1136:     ///      account and return the principal the strategy actually booked (the market strategy
          ///      haircuts this below `amount`; direct strategies return `amount`). When no strategy is
          ///      set the tokens sit idle in this contract, so the full `amount` is credited.
          function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {
              IYieldStrategy strategy = yieldStrategy[token];
              if (address(strategy) == address(0)) {
                  return amount; // idle hold: full credit
              }
              return strategy.deposit(token, amount, address(this));
          }
      
          /**
           * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract

1136:     ///      account and return the principal the strategy actually booked (the market strategy
          ///      haircuts this below `amount`; direct strategies return `amount`). When no strategy is
          ///      set the tokens sit idle in this contract, so the full `amount` is credited.
          function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {
              IYieldStrategy strategy = yieldStrategy[token];
              if (address(strategy) == address(0)) {
                  return amount; // idle hold: full credit
              }
              return strategy.deposit(token, amount, address(this));

1157:      * @dev Size a strategy exit: the GROSS that must be requested to net `netWanted`, and the floor
           *      that gross is guaranteed to deliver. With no strategy set the principal is already idle in
           *      this contract, so gross == net == `netWanted` and nothing is haircut.
           *
           *      ⚠️ `netGuaranteed` is a FLOOR, not an expectation and not a settlement figure. It reads
           *      live vault and AMM state (manipulable within a block) and is built on the fee-free
           *      `convertToAssets` (vault-RM 049), so it can over-quote in two independent ways. Callers
           *      MUST measure the real balance delta across the exit — see {autoAnnihilate}.
           */
          function _previewExit(address token, uint256 netWanted)
              internal
              view
              returns (uint256 grossToRequest, uint256 netGuaranteed)
          {
              IYieldStrategy strategy = yieldStrategy[token];
              if (address(strategy) == address(0)) {
                  return (netWanted, netWanted);
              }
              return strategy.previewExitFor(token, address(this), netWanted);
          }
      
          function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {

1157:      * @dev Size a strategy exit: the GROSS that must be requested to net `netWanted`, and the floor
           *      that gross is guaranteed to deliver. With no strategy set the principal is already idle in
           *      this contract, so gross == net == `netWanted` and nothing is haircut.
           *
           *      ⚠️ `netGuaranteed` is a FLOOR, not an expectation and not a settlement figure. It reads
           *      live vault and AMM state (manipulable within a block) and is built on the fee-free
           *      `convertToAssets` (vault-RM 049), so it can over-quote in two independent ways. Callers
           *      MUST measure the real balance delta across the exit — see {autoAnnihilate}.
           */
          function _previewExit(address token, uint256 netWanted)
              internal
              view
              returns (uint256 grossToRequest, uint256 netGuaranteed)
          {
              IYieldStrategy strategy = yieldStrategy[token];
              if (address(strategy) == address(0)) {
                  return (netWanted, netWanted);
              }
              return strategy.previewExitFor(token, address(this), netWanted);

1178:     function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
              IYieldStrategy strategy = yieldStrategy[token];
              if (address(strategy) == address(0)) {
                  return amount;
              }
              IERC20 t = IERC20(token);
              if (guardUnderwater && _isUnderwater(token, strategy)) {
                  // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
                  // Caller forwards the returned amount via safeTransfer, so we just signal
                  // "use the buffer" by returning `amount` without touching the strategy.
                  if (t.balanceOf(address(this)) >= amount) {
                      emit BufferWithdrawn(token, msg.sender, amount);
                      strategy.relinquishPrincipal(token, amount);
                      return amount;
                  }
                  revert("StableStaker: strategy underwater");
              }
              uint256 balanceBefore = t.balanceOf(address(this));
              strategy.withdraw(token, amount, address(this));
              return t.balanceOf(address(this)) - balanceBefore;
          }
      
          // ============================== OWNER RESCUE ==============================

1178:     function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
              IYieldStrategy strategy = yieldStrategy[token];
              if (address(strategy) == address(0)) {
                  return amount;
              }
              IERC20 t = IERC20(token);
              if (guardUnderwater && _isUnderwater(token, strategy)) {

1178:     function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
              IYieldStrategy strategy = yieldStrategy[token];
              if (address(strategy) == address(0)) {
                  return amount;
              }
              IERC20 t = IERC20(token);
              if (guardUnderwater && _isUnderwater(token, strategy)) {
                  // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
                  // Caller forwards the returned amount via safeTransfer, so we just signal
                  // "use the buffer" by returning `amount` without touching the strategy.
                  if (t.balanceOf(address(this)) >= amount) {
                      emit BufferWithdrawn(token, msg.sender, amount);
                      strategy.relinquishPrincipal(token, amount);
                      return amount;
                  }
                  revert("StableStaker: strategy underwater");
              }
              uint256 balanceBefore = t.balanceOf(address(this));

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

551:      * @dev Shared terminal-migration exit for one user: mints their frozen pending phUSD, computes the
          *      snapshot credit `p_i·min(R,P)/P`, zeroes their position and removes them from the staker set.
          *      Returns the credit (0 for an empty position). Used by both {batchMigrate} and {userMigrate},
          *      so a self-migrated user and a batch-migrated user with equal principal get identical credit.
          *      Does NOT transfer the credit — the caller forwards it (CEI).
          */
         function _exitPosition(address token, address account) internal returns (uint256 credit) {
             UserInfo storage info = userInfo[token][account];
             uint256 amt = info.amount;
             if (amt == 0) {
                 return 0;
             }
             MigrationInfo storage mig = migrationInfo[token];

791:     /// @dev If a strategy is set for `token`, deposit `amount` into it under this contract's
         ///      account and return the principal the strategy actually booked (the market strategy
         ///      haircuts this below `amount`; direct strategies return `amount`). When no strategy is
         ///      set the tokens sit idle in this contract, so the full `amount` is credited.
         function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {
             IYieldStrategy strategy = yieldStrategy[token];
             if (address(strategy) == address(0)) {
                 return amount; // idle hold: full credit
             }
             return strategy.deposit(token, amount, address(this));
         }

791:     /// @dev If a strategy is set for `token`, deposit `amount` into it under this contract's
         ///      account and return the principal the strategy actually booked (the market strategy
         ///      haircuts this below `amount`; direct strategies return `amount`). When no strategy is
         ///      set the tokens sit idle in this contract, so the full `amount` is credited.
         function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {
             IYieldStrategy strategy = yieldStrategy[token];
             if (address(strategy) == address(0)) {
                 return amount; // idle hold: full credit
             }
             return strategy.deposit(token, amount, address(this));

804:      * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
          *      and return the ACTUAL amount received (balance delta) for forwarding to the user/migrator.
          *      Internal principal accounting is decremented by the requested `amount` by the caller, not
          *      the received amount; sub-amount differences remain protocol-owned yield/loss. When no
          *      strategy is set, returns `amount` unchanged (the tokens already sit in the contract).
          * @param guardUnderwater When true (the non-migrating `withdraw` path), reverts if the strategy
          *      is below par. The escape hatch and migration pass false so they always succeed.
          */
         function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
             IYieldStrategy strategy = yieldStrategy[token];
             if (address(strategy) == address(0)) {
                 return amount;
             }
             IERC20 t = IERC20(token);
             if (guardUnderwater && _isUnderwater(token, strategy)) {
                 // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
                 // Caller forwards the returned amount via safeTransfer, so we just signal
                 // "use the buffer" by returning `amount` without touching the strategy.
                 if (t.balanceOf(address(this)) >= amount) {
                     emit BufferWithdrawn(token, msg.sender, amount);
                     strategy.relinquishPrincipal(token, amount);
                     return amount;
                 }
                 revert("StableStaker: strategy underwater");
             }
             uint256 balanceBefore = t.balanceOf(address(this));
             strategy.withdraw(token, amount, address(this));
             return t.balanceOf(address(this)) - balanceBefore;
         }

804:      * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
          *      and return the ACTUAL amount received (balance delta) for forwarding to the user/migrator.
          *      Internal principal accounting is decremented by the requested `amount` by the caller, not
          *      the received amount; sub-amount differences remain protocol-owned yield/loss. When no
          *      strategy is set, returns `amount` unchanged (the tokens already sit in the contract).
          * @param guardUnderwater When true (the non-migrating `withdraw` path), reverts if the strategy
          *      is below par. The escape hatch and migration pass false so they always succeed.
          */
         function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
             IYieldStrategy strategy = yieldStrategy[token];
             if (address(strategy) == address(0)) {
                 return amount;
             }
             IERC20 t = IERC20(token);

804:      * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
          *      and return the ACTUAL amount received (balance delta) for forwarding to the user/migrator.
          *      Internal principal accounting is decremented by the requested `amount` by the caller, not
          *      the received amount; sub-amount differences remain protocol-owned yield/loss. When no
          *      strategy is set, returns `amount` unchanged (the tokens already sit in the contract).
          * @param guardUnderwater When true (the non-migrating `withdraw` path), reverts if the strategy
          *      is below par. The escape hatch and migration pass false so they always succeed.
          */
         function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {
             IYieldStrategy strategy = yieldStrategy[token];
             if (address(strategy) == address(0)) {
                 return amount;
             }
             IERC20 t = IERC20(token);
             if (guardUnderwater && _isUnderwater(token, strategy)) {
                 // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
                 // Caller forwards the returned amount via safeTransfer, so we just signal
                 // "use the buffer" by returning `amount` without touching the strategy.
                 if (t.balanceOf(address(this)) >= amount) {
                     emit BufferWithdrawn(token, msg.sender, amount);
                     strategy.relinquishPrincipal(token, amount);
                     return amount;
                 }
                 revert("StableStaker: strategy underwater");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

123:      * @dev Returns minter information for a given address
          * @param minter The address to check
          * @return info The MinterInfo struct containing permission and version
          */
         function authorizedMinters(address minter) external view override returns (MinterInfo memory info) {
             return _authorizedMinters[minter];

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="NC-19"></a>[NC-19] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

1: 
   Current order:
   UsingForDirective.IERC20
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration.ACC_PRECISION
   VariableDeclaration.SECONDS_PER_DAY
   VariableDeclaration.STAKER_VERSION
   VariableDeclaration.EXIT_ROUNDING_ALLOWANCE
   VariableDeclaration.EXIT_ROUNDING_ALLOWANCE_BPS
   VariableDeclaration.MAX_BPS
   VariableDeclaration.antimatter
   VariableDeclaration.pauser
   VariableDeclaration.migrator
   VariableDeclaration.claimEnabled
   StructDefinition.PoolInfo
   StructDefinition.UserInfo
   VariableDeclaration.poolInfo
   VariableDeclaration.userInfo
   VariableDeclaration._stakers
   VariableDeclaration.unclaimedReward
   VariableDeclaration._registeredTokens
   VariableDeclaration.yieldStrategy
   EnumDefinition.PoolState
   VariableDeclaration.poolState
   StructDefinition.MigrationInfo
   VariableDeclaration.migrationInfo
   EventDefinition.TokenAdded
   EventDefinition.RewardRateSet
   EventDefinition.MigratorSet
   EventDefinition.PauserUpdated
   EventDefinition.YieldStrategySet
   EventDefinition.Staked
   EventDefinition.Withdrawn
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.MigratedOut
   EventDefinition.MigrationInitiated
   EventDefinition.UserMigrated
   EventDefinition.DepositedFor
   EventDefinition.BufferWithdrawn
   EventDefinition.ERC20Rescued
   EventDefinition.PoolReset
   EventDefinition.ClaimEnabledSet
   EventDefinition.AutoAnnihilated
   EventDefinition.PrincipalDivergence
   EventDefinition.ProtocolPrincipalSwept
   ModifierDefinition.onlyPauser
   ModifierDefinition.onlyMigrator
   ModifierDefinition.poolExists
   FunctionDefinition.constructor
   FunctionDefinition.addToken
   FunctionDefinition.antimatterPerDay
   FunctionDefinition.setMigrator
   FunctionDefinition.setClaimEnabled
   FunctionDefinition.setPauser
   FunctionDefinition.setYieldStrategy
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition.autoAnnihilate
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.initiateMigration
   FunctionDefinition.batchMigrate
   FunctionDefinition._exitPosition
   FunctionDefinition.userMigrate
   FunctionDefinition.finalizeAndReset
   FunctionDefinition.depositFor
   FunctionDefinition.pendingReward
   FunctionDefinition.claimableReward
   FunctionDefinition._pendingReward
   FunctionDefinition.getStakers
   FunctionDefinition.getStakersRange
   FunctionDefinition.stakerCount
   FunctionDefinition.getStakedTokens
   FunctionDefinition.withdrawDisabled
   FunctionDefinition.autoAnnihilateAvailable
   FunctionDefinition._updatePool
   FunctionDefinition._settle
   FunctionDefinition._pullToken
   FunctionDefinition._antimatterScale
   FunctionDefinition._isUnderwater
   FunctionDefinition._routeDeposit
   FunctionDefinition._previewExit
   FunctionDefinition._routeExit
   FunctionDefinition.rescueERC20
   
   Suggested order:
   UsingForDirective.IERC20
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration.ACC_PRECISION
   VariableDeclaration.SECONDS_PER_DAY
   VariableDeclaration.STAKER_VERSION
   VariableDeclaration.EXIT_ROUNDING_ALLOWANCE
   VariableDeclaration.EXIT_ROUNDING_ALLOWANCE_BPS
   VariableDeclaration.MAX_BPS
   VariableDeclaration.antimatter
   VariableDeclaration.pauser
   VariableDeclaration.migrator
   VariableDeclaration.claimEnabled
   VariableDeclaration.poolInfo
   VariableDeclaration.userInfo
   VariableDeclaration._stakers
   VariableDeclaration.unclaimedReward
   VariableDeclaration._registeredTokens
   VariableDeclaration.yieldStrategy
   VariableDeclaration.poolState
   VariableDeclaration.migrationInfo
   EnumDefinition.PoolState
   StructDefinition.PoolInfo
   StructDefinition.UserInfo
   StructDefinition.MigrationInfo
   EventDefinition.TokenAdded
   EventDefinition.RewardRateSet
   EventDefinition.MigratorSet
   EventDefinition.PauserUpdated
   EventDefinition.YieldStrategySet
   EventDefinition.Staked
   EventDefinition.Withdrawn
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.MigratedOut
   EventDefinition.MigrationInitiated
   EventDefinition.UserMigrated
   EventDefinition.DepositedFor
   EventDefinition.BufferWithdrawn
   EventDefinition.ERC20Rescued
   EventDefinition.PoolReset
   EventDefinition.ClaimEnabledSet
   EventDefinition.AutoAnnihilated
   EventDefinition.PrincipalDivergence
   EventDefinition.ProtocolPrincipalSwept
   ModifierDefinition.onlyPauser
   ModifierDefinition.onlyMigrator
   ModifierDefinition.poolExists
   FunctionDefinition.constructor
   FunctionDefinition.addToken
   FunctionDefinition.antimatterPerDay
   FunctionDefinition.setMigrator
   FunctionDefinition.setClaimEnabled
   FunctionDefinition.setPauser
   FunctionDefinition.setYieldStrategy
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition.autoAnnihilate
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.initiateMigration
   FunctionDefinition.batchMigrate
   FunctionDefinition._exitPosition
   FunctionDefinition.userMigrate
   FunctionDefinition.finalizeAndReset
   FunctionDefinition.depositFor
   FunctionDefinition.pendingReward
   FunctionDefinition.claimableReward
   FunctionDefinition._pendingReward
   FunctionDefinition.getStakers
   FunctionDefinition.getStakersRange
   FunctionDefinition.stakerCount
   FunctionDefinition.getStakedTokens
   FunctionDefinition.withdrawDisabled
   FunctionDefinition.autoAnnihilateAvailable
   FunctionDefinition._updatePool
   FunctionDefinition._settle
   FunctionDefinition._pullToken
   FunctionDefinition._antimatterScale
   FunctionDefinition._isUnderwater
   FunctionDefinition._routeDeposit
   FunctionDefinition._previewExit
   FunctionDefinition._routeExit
   FunctionDefinition.rescueERC20

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

1: 
   Current order:
   UsingForDirective.IERC20
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration.ACC_PRECISION
   VariableDeclaration.SECONDS_PER_DAY
   VariableDeclaration.phUSD
   VariableDeclaration.pauser
   VariableDeclaration.migrator
   StructDefinition.PoolInfo
   StructDefinition.UserInfo
   VariableDeclaration.poolInfo
   VariableDeclaration.userInfo
   VariableDeclaration._stakers
   VariableDeclaration._registeredTokens
   VariableDeclaration.yieldStrategy
   EnumDefinition.PoolState
   VariableDeclaration.poolState
   StructDefinition.MigrationInfo
   VariableDeclaration.migrationInfo
   EventDefinition.TokenAdded
   EventDefinition.RewardRateSet
   EventDefinition.MigratorSet
   EventDefinition.PauserUpdated
   EventDefinition.YieldStrategySet
   EventDefinition.Staked
   EventDefinition.Withdrawn
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.MigratedOut
   EventDefinition.MigrationInitiated
   EventDefinition.UserMigrated
   EventDefinition.DepositedFor
   EventDefinition.BufferWithdrawn
   EventDefinition.ERC20Rescued
   EventDefinition.PoolReset
   ModifierDefinition.onlyPauser
   ModifierDefinition.onlyMigrator
   ModifierDefinition.poolExists
   FunctionDefinition.constructor
   FunctionDefinition.addToken
   FunctionDefinition.phUSDPerDay
   FunctionDefinition.setMigrator
   FunctionDefinition.setPauser
   FunctionDefinition.setYieldStrategy
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.initiateMigration
   FunctionDefinition.batchMigrate
   FunctionDefinition._exitPosition
   FunctionDefinition.userMigrate
   FunctionDefinition.finalizeAndReset
   FunctionDefinition.depositFor
   FunctionDefinition.pendingReward
   FunctionDefinition.getStakers
   FunctionDefinition.getStakersRange
   FunctionDefinition.stakerCount
   FunctionDefinition.getStakedTokens
   FunctionDefinition.withdrawDisabled
   FunctionDefinition._updatePool
   FunctionDefinition._settle
   FunctionDefinition._pullToken
   FunctionDefinition._isUnderwater
   FunctionDefinition._routeDeposit
   FunctionDefinition._routeExit
   FunctionDefinition.rescueERC20
   
   Suggested order:
   UsingForDirective.IERC20
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration.ACC_PRECISION
   VariableDeclaration.SECONDS_PER_DAY
   VariableDeclaration.phUSD
   VariableDeclaration.pauser
   VariableDeclaration.migrator
   VariableDeclaration.poolInfo
   VariableDeclaration.userInfo
   VariableDeclaration._stakers
   VariableDeclaration._registeredTokens
   VariableDeclaration.yieldStrategy
   VariableDeclaration.poolState
   VariableDeclaration.migrationInfo
   EnumDefinition.PoolState
   StructDefinition.PoolInfo
   StructDefinition.UserInfo
   StructDefinition.MigrationInfo
   EventDefinition.TokenAdded
   EventDefinition.RewardRateSet
   EventDefinition.MigratorSet
   EventDefinition.PauserUpdated
   EventDefinition.YieldStrategySet
   EventDefinition.Staked
   EventDefinition.Withdrawn
   EventDefinition.Claimed
   EventDefinition.EmergencyWithdrawn
   EventDefinition.MigratedOut
   EventDefinition.MigrationInitiated
   EventDefinition.UserMigrated
   EventDefinition.DepositedFor
   EventDefinition.BufferWithdrawn
   EventDefinition.ERC20Rescued
   EventDefinition.PoolReset
   ModifierDefinition.onlyPauser
   ModifierDefinition.onlyMigrator
   ModifierDefinition.poolExists
   FunctionDefinition.constructor
   FunctionDefinition.addToken
   FunctionDefinition.phUSDPerDay
   FunctionDefinition.setMigrator
   FunctionDefinition.setPauser
   FunctionDefinition.setYieldStrategy
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.stake
   FunctionDefinition.withdraw
   FunctionDefinition.claim
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.initiateMigration
   FunctionDefinition.batchMigrate
   FunctionDefinition._exitPosition
   FunctionDefinition.userMigrate
   FunctionDefinition.finalizeAndReset
   FunctionDefinition.depositFor
   FunctionDefinition.pendingReward
   FunctionDefinition.getStakers
   FunctionDefinition.getStakersRange
   FunctionDefinition.stakerCount
   FunctionDefinition.getStakedTokens
   FunctionDefinition.withdrawDisabled
   FunctionDefinition._updatePool
   FunctionDefinition._settle
   FunctionDefinition._pullToken
   FunctionDefinition._isUnderwater
   FunctionDefinition._routeDeposit
   FunctionDefinition._routeExit
   FunctionDefinition.rescueERC20

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-20"></a>[NC-20] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (3)*:
```solidity
File: src/InPlaceMigrator.sol

293:         require(finalCredited >= amt - amt / 1000, "InPlaceMigrator: par not restored");

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

51:     uint256 public constant SECONDS_PER_DAY = 86400;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

87:     uint256 public constant SECONDS_PER_DAY = 86400;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="NC-21"></a>[NC-21] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (44)*:
```solidity
File: src/CrossVersionMigrator.sol

119:     event MigratedAcrossVersions(

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

99:     event MigratedOut(address indexed token, uint256 userCount, uint256 totalPrincipal);

102:     event MigratedIn(address indexed token, uint256 userCount, uint256 totalPrincipal);

105:     event TimedOutClaim(address indexed token, address indexed user, uint256 amount);

116:     event ReinjectedWithTopup(

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

174:     event RewardRateSet(address indexed token, uint256 antimatterAmountPerDay, uint256 antimatterPerSecond);

178:     event Staked(address indexed token, address indexed user, uint256 amount);

179:     event Withdrawn(address indexed token, address indexed user, uint256 amount);

180:     event Claimed(address indexed token, address indexed user, uint256 reward);

181:     event EmergencyWithdrawn(address indexed token, address indexed user, uint256 amount);

182:     event MigratedOut(address indexed token, address indexed user, uint256 amount, uint256 reward);

183:     event MigrationInitiated(address indexed token, uint256 realized, uint256 principalSnapshot);

184:     event UserMigrated(address indexed token, address indexed user, uint256 credit);

185:     event DepositedFor(address indexed token, address indexed user, uint256 amount);

186:     event BufferWithdrawn(address indexed token, address indexed user, uint256 amount);

187:     event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

189:     event ClaimEnabledSet(bool enabled);

198:     event AutoAnnihilated(

212:     event PrincipalDivergence(address indexed token, uint256 claimed, uint256 booked, uint256 relinquished);

219:     event ProtocolPrincipalSwept(address indexed token, address indexed strategy, uint256 amount, uint256 credited);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/IStableStakerV1.sol

66:     event RewardRateSet(address indexed token, uint256 phusdPerDay, uint256 phusdPerSecond);

70:     event Staked(address indexed token, address indexed user, uint256 amount);

71:     event Withdrawn(address indexed token, address indexed user, uint256 amount);

72:     event Claimed(address indexed token, address indexed user, uint256 reward);

73:     event EmergencyWithdrawn(address indexed token, address indexed user, uint256 amount);

74:     event MigratedOut(address indexed token, address indexed user, uint256 amount, uint256 reward);

75:     event MigrationInitiated(address indexed token, uint256 realized, uint256 principalSnapshot);

76:     event UserMigrated(address indexed token, address indexed user, uint256 credit);

77:     event DepositedFor(address indexed token, address indexed user, uint256 amount);

78:     event BufferWithdrawn(address indexed token, address indexed user, uint256 amount);

79:     event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/IStableStakerV1.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

163:     event RewardRateSet(address indexed token, uint256 phusdPerDay, uint256 phusdPerSecond);

167:     event Staked(address indexed token, address indexed user, uint256 amount);

168:     event Withdrawn(address indexed token, address indexed user, uint256 amount);

169:     event Claimed(address indexed token, address indexed user, uint256 reward);

170:     event EmergencyWithdrawn(address indexed token, address indexed user, uint256 amount);

171:     event MigratedOut(address indexed token, address indexed user, uint256 amount, uint256 reward);

172:     event MigrationInitiated(address indexed token, uint256 realized, uint256 principalSnapshot);

173:     event UserMigrated(address indexed token, address indexed user, uint256 credit);

174:     event DepositedFor(address indexed token, address indexed user, uint256 amount);

175:     event BufferWithdrawn(address indexed token, address indexed user, uint256 amount);

176:     event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/IFlax.sol

65:     event MinterSet(address indexed minter, bool canMint, uint256 mintVersion);

71:     event MintPrivilegesRevoked(uint256 newMintVersion);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/IFlax.sol)

### <a name="NC-22"></a>[NC-22] Constants should be defined rather than using magic numbers

*Instances (1)*:
```solidity
File: src/StableStakerV2.sol

1126:         return 10 ** (18 - dec);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

### <a name="NC-23"></a>[NC-23] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (10)*:
```solidity
File: src/CrossVersionMigrator.sol

165:         for (uint256 i = 0; i < amounts.length; i++) {

176:         for (uint256 i = 0; i < users.length; i++) {

237:         for (uint256 i = 0; i < tokens.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

170:         for (uint256 i = 0; i < users.length; i++) {

215:         for (uint256 i = 0; i < sliceLen; i++) {

231:         for (uint256 i = 0; i < sliceLen; i++) {

273:         uint256 topup = 0;

371:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

802:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

538:         for (uint256 i = 0; i < users.length; i++) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 6 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 15 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 2 |
| [L-4](#L-4) | `decimals()` is not a part of the ERC-20 standard | 2 |
| [L-5](#L-5) | Division by zero not prevented | 8 |
| [L-6](#L-6) | External calls in an un-bounded `for-`loop may result in a DOS | 2 |
| [L-7](#L-7) | Prevent accidentally burning tokens | 7 |
| [L-8](#L-8) | Owner can renounce while system is paused | 2 |
| [L-9](#L-9) | Possible rounding issue | 4 |
| [L-10](#L-10) | Loss of precision | 27 |
| [L-11](#L-11) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 5 |
| [L-12](#L-12) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 10 |
| [L-13](#L-13) | File allows a version of solidity that is susceptible to an assembly optimizer bug | 1 |
| [L-14](#L-14) | Sweeping may break accounting if tokens with multiple addresses are used | 4 |
| [L-15](#L-15) | `symbol()` is not a part of the ERC-20 standard | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (6)*:
```solidity
File: src/CrossVersionMigrator.sol

101: contract CrossVersionMigrator is Ownable {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

60: contract InPlaceMigrator is Ownable, ReentrancyGuard {

130:     constructor(IStableStaker _staker, uint256 _migrationTimeout, address initialOwner) Ownable(initialOwner) {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

43: contract StableStakerV2 is Ownable, Pausable, ReentrancyGuard, IPausable, IStableStaker {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

79: contract StableStakerV1 is Ownable, Pausable, ReentrancyGuard, IPausable {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

45: contract FlaxToken is ERC20, Ownable, IFlax {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (15)*:
```solidity
File: src/InPlaceMigrator.sol

322:         IERC20(token).safeTransfer(msg.sender, amount);

341:         IERC20(token).safeTransfer(to, amount);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

424:         IERC20(token).safeTransfer(msg.sender, payout);

609:             IERC20(token).safeTransfer(msg.sender, surplus);

635:         IERC20(token).safeTransfer(msg.sender, payout);

815:      * @dev Shared terminal-migration exit for one user: mints their frozen pending Antimatter PLUS any

872:         emit UserMigrated(token, msg.sender, credit);

1113:         return t.balanceOf(address(this)) - balanceBefore;

1221: 

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

372:         IERC20(token).safeTransfer(msg.sender, payout);

406:         IERC20(token).safeTransfer(msg.sender, payout);

546:             IERC20(token).safeTransfer(msg.sender, total);

601:         emit UserMigrated(token, msg.sender, credit);

782:         return t.balanceOf(address(this)) - balanceBefore;

852:         emit ERC20Rescued(token, to, amount);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

287:         pauser = _pauser;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

238:         pauser = _pauser;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="L-4"></a>[L-4] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

1124:         uint8 dec = IERC20Metadata(token).decimals();

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

151:         return super.decimals();

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="L-5"></a>[L-5] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (8)*:
```solidity
File: src/StableStakerV2.sol

544:                 netWanted = capped / scale;

559:                 netFloor = grossQuote == 0 ? 0 : (netQuote * gross) / grossQuote;

831:         credit = (amt * S) / P;

980:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

1091:             pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

566:         credit = (amt * S) / P;

689:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

762:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="L-6"></a>[L-6] External calls in an un-bounded `for-`loop may result in a DOS
Consider limiting the number of iterations in for-loops that make external calls

*Instances (2)*:
```solidity
File: src/InPlaceMigrator.sol

175:                 _parkedUsers[token].add(users[i]);

242:             _parkedUsers[token].remove(user);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

### <a name="L-7"></a>[L-7] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (7)*:
```solidity
File: src/versions/v1/vendor/FlaxToken.sol

72:         _authorizedMinters[minter] = MinterInfo({

77:         emit MinterSet(minter, canMint, mintVersion);

89:         require(minterInfo.canMint, "phUSD: caller is not authorized to mint");

92:         require(minterInfo.mintVersion == mintVersion, "phUSD: minter version is outdated");

95:         _mint(recipient, amount);

109:         _burn(holder, amount);

117:         emit MintPrivilegesRevoked(mintVersion);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="L-8"></a>[L-8] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

285:     function setPauser(address _pauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

236:     function setPauser(address _pauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="L-9"></a>[L-9] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (4)*:
```solidity
File: src/StableStakerV2.sol

980:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

1091:             pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

689:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

762:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="L-10"></a>[L-10] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (27)*:
```solidity
File: src/StableStakerV2.sol

266:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

393:         user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

410:         uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;

413:         user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

444:         uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;

448:         user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

539:                     + ((user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt);

567:             user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

587:             uint256 allowance = EXIT_ROUNDING_ALLOWANCE + (netFloor * EXIT_ROUNDING_ALLOWANCE_BPS) / MAX_BPS;

835:         uint256 pending = (amt * pool.accAntimatterPerShare) / ACC_PRECISION - info.rewardDebt;

945:         info.rewardDebt = (info.amount * pool.accAntimatterPerShare) / ACC_PRECISION;

980:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

983:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

1091:             pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

1101:             uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

224:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

342:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

358:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

361:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

381:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

383:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

570:         uint256 pending = (amt * pool.accPhusdPerShare) / ACC_PRECISION - info.rewardDebt;

673:         info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;

689:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

692:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

762:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

770:             uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="L-11"></a>[L-11] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (5)*:
```solidity
File: src/CrossVersionMigrator.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="L-12"></a>[L-12] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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
File: src/CrossVersionMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/IStableStakerV1.sol

199:     function transferOwnership(address newOwner) external;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/IStableStakerV1.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

32: import "@openzeppelin/contracts/access/Ownable.sol";

164:     function transferOwnership(address newOwner) public override(Ownable, IFlax) onlyOwner {

165:         super.transferOwnership(newOwner);

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

```solidity
File: src/versions/v1/vendor/IFlax.sol

32: import "@openzeppelin/contracts/access/Ownable.sol";

155:     function transferOwnership(address newOwner) external;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/IFlax.sol)

### <a name="L-13"></a>[L-13] File allows a version of solidity that is susceptible to an assembly optimizer bug
In solidity versions 0.8.13 and 0.8.14, there is an [optimizer bug](https://github.com/ethereum/solidity-blog/blob/499ab8abc19391be7b7b34f88953a067029a5b45/_posts/2022-06-15-inline-assembly-memory-side-effects-bug.md) where, if the use of a variable is in a separate `assembly` block from the block in which it was stored, the `mstore` operation is optimized out, leading to uninitialized memory. The code currently does not have such a pattern of execution, but it does use `mstore`s in `assembly` blocks, so it is a risk for future changes. The affected solidity versions should be avoided if at all possible.

*Instances (1)*:
```solidity
File: src/versions/v1/vendor/FlaxToken.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

### <a name="L-14"></a>[L-14] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (4)*:
```solidity
File: src/InPlaceMigrator.sol

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

1212:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/IStableStakerV1.sol

103:     function rescueERC20(address token, address to, uint256 amount) external;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/IStableStakerV1.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

846:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="L-15"></a>[L-15] `symbol()` is not a part of the ERC-20 standard
The `symbol()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (1)*:
```solidity
File: src/versions/v1/vendor/FlaxToken.sol

144:         return super.symbol();

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 2 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 36 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (2)*:
```solidity
File: src/StableStakerV2.sol

1113:         return t.balanceOf(address(this)) - balanceBefore;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

782:         return t.balanceOf(address(this)) - balanceBefore;

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (36)*:
```solidity
File: src/CrossVersionMigrator.sol

101: contract CrossVersionMigrator is Ownable {

124:         Ownable(initialOwner)

147:     function initiateMigration(address token) external onlyOwner {

161:     function migrate(address token, address[] calldata users) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/CrossVersionMigrator.sol)

```solidity
File: src/InPlaceMigrator.sol

60: contract InPlaceMigrator is Ownable, ReentrancyGuard {

130:     constructor(IStableStaker _staker, uint256 _migrationTimeout, address initialOwner) Ownable(initialOwner) {

150:     function initiateMigration(address token) external onlyOwner {

165:     function migrateOut(address token, address[] calldata users) external onlyOwner nonReentrant {

203:     function migrateIn(address token, uint256 start, uint256 end) external onlyOwner nonReentrant {

338:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/InPlaceMigrator.sol)

```solidity
File: src/StableStakerV2.sol

43: contract StableStakerV2 is Ownable, Pausable, ReentrancyGuard, IPausable, IStableStaker {

244:     constructor(IAntimatter _antimatter, address initialOwner) Ownable(initialOwner) {

252:     function addToken(address token) external onlyOwner {

264:     function antimatterPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

272:     function setMigrator(address _migrator) external onlyOwner {

279:     function setClaimEnabled(bool enabled) external onlyOwner {

285:     function setPauser(address _pauser) external onlyOwner {

306:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

902:     function finalizeAndReset(address token) external onlyOwner poolExists(token) {

1212:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/StableStakerV2.sol)

```solidity
File: src/versions/v1/StableStakerV1.sol

79: contract StableStakerV1 is Ownable, Pausable, ReentrancyGuard, IPausable {

202:     constructor(IFlax _phUSD, address initialOwner) Ownable(initialOwner) {

210:     function addToken(address token) external onlyOwner {

222:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

230:     function setMigrator(address _migrator) external onlyOwner {

236:     function setPauser(address _pauser) external onlyOwner {

257:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

631:     function finalizeAndReset(address token) external onlyOwner poolExists(token) {

846:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/StableStakerV1.sol)

```solidity
File: src/versions/v1/vendor/FlaxToken.sol

45: contract FlaxToken is ERC20, Ownable, IFlax {

60:     constructor() ERC20("Phoenix USD", "phUSD") Ownable(msg.sender) {

71:     function setMinter(address minter, bool canMint) external override onlyOwner {

115:     function revokeAllMintPrivileges() external override onlyOwner {

157:     function owner() public view override(Ownable, IFlax) returns (address) {

164:     function transferOwnership(address newOwner) public override(Ownable, IFlax) onlyOwner {

171:     function renounceOwnership() public override(Ownable, IFlax) onlyOwner {

```
[Link to code](https://github.com/Behodler/stable-stakersrc/versions/v1/vendor/FlaxToken.sol)

