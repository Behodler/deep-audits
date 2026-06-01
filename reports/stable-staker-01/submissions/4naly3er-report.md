# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 8 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 11 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 3 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 55 |
| [GAS-5](#GAS-5) | Use Custom Errors instead of Revert Strings to save Gas | 19 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 7 |
| [GAS-7](#GAS-7) | Stack variable used as a cheaper cache for a state variable is only used once | 1 |
| [GAS-8](#GAS-8) | State variables only set in the constructor should be declared `immutable` | 3 |
| [GAS-9](#GAS-9) | Functions guaranteed to revert when called by normal users can be marked `payable` | 8 |
| [GAS-10](#GAS-10) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 5 |
| [GAS-11](#GAS-11) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 4 |
| [GAS-13](#GAS-13) | Use != 0 instead of > 0 for unsigned integer comparison | 14 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (8)*:
```solidity
File: StableStaker.sol

230:         user.amount += received;

231:         pool.totalStaked += received;

325:             totalPrincipal += amt;

358:         info.amount += received;

359:         pool.totalStaked += received;

374:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

441:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```

```solidity
File: StableStakerMigrator.sol

50:             total += amounts[i];

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (11)*:
```solidity
File: StableStaker.sol

131:         require(address(_phUSD) != address(0), "StableStaker: zero phUSD");

139:         require(token != address(0), "StableStaker: zero token");

183:         if (address(old) != address(0)) {

190:         if (address(strategy) != address(0)) {

420:         if (address(strategy) == address(0)) {

474:         if (address(strategy) != address(0)) {

490:         if (address(strategy) == address(0)) {

522:         require(to != address(0), "StableStaker: zero recipient");

523:         uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;

```

```solidity
File: StableStakerMigrator.sol

34:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

35:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (3)*:
```solidity
File: StableStaker.sol

312:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: StableStakerMigrator.sol

49:         for (uint256 i = 0; i < amounts.length; i++) {

60:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (55)*:
```solidity
File: StableStaker.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/utils/Pausable.sol";

6: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

9: import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

10: import "flax-token/IFlax.sol";

11: import "pauser/interfaces/IPausable.sol";

12: import "reflax-yield-vault/interfaces/IYieldStrategy.sol";

62:         uint256 phusdPerSecond; // current emission rate (phUSD wei per second)

63:         uint256 accPhusdPerShare; // accumulated phUSD per staked unit, scaled by ACC_PRECISION

64:         uint256 lastRewardTime; // last time the pool accrued

65:         uint256 totalStaked; // total principal staked in this pool

70:         uint256 amount; // staked principal

71:         uint256 rewardDebt; // accounting baseline: amount * accPhusdPerShare / ACC_PRECISION at last settle

152:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

230:         user.amount += received;

231:         pool.totalStaked += received;

232:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

245:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

246:         user.amount -= amount;

247:         pool.totalStaked -= amount;

248:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

268:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

270:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

286:         poolInfo[token].totalStaked -= amount;

312:         for (uint256 i = 0; i < users.length; i++) {

319:             uint256 pending = (amt * pool.accPhusdPerShare) / ACC_PRECISION - info.rewardDebt;

322:             pool.totalStaked -= amt;

325:             totalPrincipal += amt;

358:         info.amount += received;

359:         pool.totalStaked += received;

360:         info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;

372:             uint256 elapsed = block.timestamp - pool.lastRewardTime;

373:             uint256 reward = elapsed * pool.phusdPerSecond;

374:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

377:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

396:         address[] memory out = new address[](end - start);

397:         for (uint256 i = start; i < end; i++) {

398:             out[i - start] = set.at(i);

438:         uint256 elapsed = block.timestamp - pool.lastRewardTime;

439:         uint256 reward = elapsed * pool.phusdPerSecond;

441:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

449:             uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

461:         return t.balanceOf(address(this)) - balanceBefore;

506:         return t.balanceOf(address(this)) - balanceBefore;

525:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```

```solidity
File: StableStakerMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import "./interfaces/IStableStaker.sol";

49:         for (uint256 i = 0; i < amounts.length; i++) {

50:             total += amounts[i];

60:         for (uint256 i = 0; i < users.length; i++) {

63:                 migratedCount++;

```

### <a name="GAS-5"></a>[GAS-5] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (19)*:
```solidity
File: StableStaker.sol

110:         require(msg.sender == pauser, "StableStaker: only pauser");

115:         require(msg.sender == migrator, "StableStaker: only migrator");

120:         require(_registeredTokens.contains(token), "StableStaker: unknown token");

131:         require(address(_phUSD) != address(0), "StableStaker: zero phUSD");

139:         require(token != address(0), "StableStaker: zero token");

140:         require(_registeredTokens.add(token), "StableStaker: token exists");

214:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

222:         require(amount > 0, "StableStaker: amount=0");

239:         require(amount > 0, "StableStaker: amount=0");

242:         require(user.amount >= amount, "StableStaker: insufficient stake");

269:         require(pending > 0, "StableStaker: nothing to claim");

283:         require(amount > 0, "StableStaker: nothing staked");

350:         require(amount > 0, "StableStaker: amount=0");

395:         require(start <= end, "StableStaker: bad range");

502:             revert("StableStaker: strategy underwater");

522:         require(to != address(0), "StableStaker: zero recipient");

525:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```

```solidity
File: StableStakerMigrator.sol

34:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

35:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (7)*:
```solidity
File: StableStaker.sol

196:             uint256 idleBalance = IERC20(token).balanceOf(address(this));

459:         uint256 balanceBefore = t.balanceOf(address(this));

461:         return t.balanceOf(address(this)) - balanceBefore;

498:             if (t.balanceOf(address(this)) >= amount) {

504:         uint256 balanceBefore = t.balanceOf(address(this));

506:         return t.balanceOf(address(this)) - balanceBefore;

524:         uint256 bal = IERC20(token).balanceOf(address(this));

```

### <a name="GAS-7"></a>[GAS-7] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (1)*:
```solidity
File: StableStaker.sol

165:         address old = pauser;

```

### <a name="GAS-8"></a>[GAS-8] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (3)*:
```solidity
File: StableStaker.sol

132:         phUSD = _phUSD;

```

```solidity
File: StableStakerMigrator.sol

36:         oldStaker = _oldStaker;

37:         newStaker = _newStaker;

```

### <a name="GAS-9"></a>[GAS-9] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (8)*:
```solidity
File: StableStaker.sol

138:     function addToken(address token) external onlyOwner {

150:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

158:     function setMigrator(address _migrator) external onlyOwner {

164:     function setPauser(address _pauser) external onlyOwner {

181:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

208:     function pause() external override onlyPauser {

521:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: StableStakerMigrator.sol

45:     function migrate(address token, address[] calldata users) external onlyOwner {

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

*Instances (5)*:
```solidity
File: StableStaker.sol

312:         for (uint256 i = 0; i < users.length; i++) {

397:         for (uint256 i = start; i < end; i++) {

```

```solidity
File: StableStakerMigrator.sol

49:         for (uint256 i = 0; i < amounts.length; i++) {

60:         for (uint256 i = 0; i < users.length; i++) {

63:                 migratedCount++;

```

### <a name="GAS-11"></a>[GAS-11] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: StableStaker.sol

46:     uint256 public constant ACC_PRECISION = 1e18;

49:     uint256 public constant SECONDS_PER_DAY = 86400;

```

### <a name="GAS-12"></a>[GAS-12] Increments/decrements can be unchecked in for-loops
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
File: StableStaker.sol

312:         for (uint256 i = 0; i < users.length; i++) {

397:         for (uint256 i = start; i < end; i++) {

```

```solidity
File: StableStakerMigrator.sol

49:         for (uint256 i = 0; i < amounts.length; i++) {

60:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-13"></a>[GAS-13] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (14)*:
```solidity
File: StableStaker.sol

197:             if (idleBalance > 0) {

222:         require(amount > 0, "StableStaker: amount=0");

239:         require(amount > 0, "StableStaker: amount=0");

253:         if (pending > 0) {

269:         require(pending > 0, "StableStaker: nothing to claim");

283:         require(amount > 0, "StableStaker: nothing staked");

326:             if (pending > 0) {

331:         if (totalPrincipal > 0) {

350:         require(amount > 0, "StableStaker: amount=0");

371:         if (block.timestamp > pool.lastRewardTime && pool.totalStaked > 0) {

440:         if (reward > 0) {

448:         if (user.amount > 0) {

450:             if (pending > 0) {

```

```solidity
File: StableStakerMigrator.sol

61:             if (amounts[i] > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 2 |
| [NC-3](#NC-3) | Critical Changes Should Use Two-step Procedure | 1 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 2 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 3 |
| [NC-6](#NC-6) | Events that mark critical parameter changes should contain both the old and the new value | 3 |
| [NC-7](#NC-7) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-8](#NC-8) | Functions should not be longer than 50 lines | 26 |
| [NC-9](#NC-9) | Lack of checks in setters | 2 |
| [NC-10](#NC-10) | Incomplete NatSpec: `@param` is missing on actually documented functions | 12 |
| [NC-11](#NC-11) | Incomplete NatSpec: `@return` is missing on actually documented functions | 1 |
| [NC-12](#NC-12) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 3 |
| [NC-13](#NC-13) | Consider using named mappings | 4 |
| [NC-14](#NC-14) | Owner can renounce while system is paused | 1 |
| [NC-15](#NC-15) | Adding a `return` statement when the function defines a named return variable, is redundant | 3 |
| [NC-16](#NC-16) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-17](#NC-17) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-18](#NC-18) | Event is missing `indexed` fields | 10 |
| [NC-19](#NC-19) | Variables need not be initialized to zero | 3 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: StableStaker.sol

166:         pauser = _pauser;

```

### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (2)*:
```solidity
File: StableStaker.sol

10: import "flax-token/IFlax.sol";

52:     IFlax public immutable phUSD;

```

### <a name="NC-3"></a>[NC-3] Critical Changes Should Use Two-step Procedure
The critical procedures should be two step process.

See similar findings in previous Code4rena contests for reference: <https://code4rena.com/reports/2022-06-illuminate/#2-critical-changes-should-use-two-step-procedure>

**Recommended Mitigation Steps**

Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: StableStaker.sol

181:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

```

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (2)*:
```solidity
File: StableStaker.sol

41: contract StableStaker is Ownable, Pausable, ReentrancyGuard, IPausable {

```

```solidity
File: StableStakerMigrator.sol

22: contract StableStakerMigrator is Ownable {

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (3)*:
```solidity
File: StableStaker.sol

222:         require(amount > 0, "StableStaker: amount=0");

239:         require(amount > 0, "StableStaker: amount=0");

350:         require(amount > 0, "StableStaker: amount=0");

```

### <a name="NC-6"></a>[NC-6] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (3)*:
```solidity
File: StableStaker.sol

158:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

164:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

181:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
             IYieldStrategy old = yieldStrategy[token];
             if (address(old) != address(0)) {
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

### <a name="NC-7"></a>[NC-7] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: StableStaker.sol

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
   external migrateOut
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
   external migrateOut
   external depositFor
   external pendingReward
   external getStakers
   external getStakersRange
   external stakerCount
   external getStakedTokens
   external withdrawDisabled
   external rescueERC20
   internal _updatePool
   internal _settle
   internal _pullToken
   internal _isUnderwater
   internal _routeDeposit
   internal _routeExit

```

### <a name="NC-8"></a>[NC-8] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (26)*:
```solidity
File: StableStaker.sol

138:     function addToken(address token) external onlyOwner {

150:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

158:     function setMigrator(address _migrator) external onlyOwner {

164:     function setPauser(address _pauser) external onlyOwner {

181:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

221:     function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

238:     function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

264:     function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

280:     function emergencyWithdraw(address token) external nonReentrant {

301:     function migrateOut(address token, address[] calldata users)

344:     function depositFor(address token, address user, uint256 amount)

368:     function pendingReward(address token, address account) external view returns (uint256) {

381:     function getStakers(address token) external view returns (address[] memory) {

389:     function getStakersRange(address token, uint256 start, uint256 end) external view returns (address[] memory) {

404:     function stakerCount(address token) external view returns (uint256) {

409:     function getStakedTokens() external view returns (address[] memory) {

418:     function withdrawDisabled(address token) external view returns (bool) {

447:     function _settle(address account, UserInfo storage user, PoolInfo storage pool) internal {

457:     function _pullToken(address token, address from, uint256 amount) internal returns (uint256) {

466:     function _isUnderwater(address token, IYieldStrategy strategy) internal view returns (bool) {

472:     function _routeDeposit(address token, uint256 amount) internal {

488:     function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {

521:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: StableStakerMigrator.sol

45:     function migrate(address token, address[] calldata users) external onlyOwner {

```

```solidity
File: interfaces/IStableStaker.sol

19:     function migrateOut(address token, address[] calldata users) external returns (uint256[] memory amounts);

28:     function depositFor(address token, address user, uint256 amount) external;

```

### <a name="NC-9"></a>[NC-9] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (2)*:
```solidity
File: StableStaker.sol

158:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

164:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

```

### <a name="NC-10"></a>[NC-10] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (12)*:
```solidity
File: StableStaker.sol

137:     /// @notice Register a new stable token as a reward pool.
         function addToken(address token) external onlyOwner {

145:     /**
          * @notice Set the daily phUSD emission budget for a token. Internally converted to a
          *         per-second rate (`amountPerDay / SECONDS_PER_DAY`, rounded down). The pool is
          *         settled at the existing rate first so the change never applies retroactively.
          */
         function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

157:     /// @notice Set the address authorized to perform permissioned migration.
         function setMigrator(address _migrator) external onlyOwner {

163:     /// @notice Set (or clear, with address(0)) the pauser address.
         function setPauser(address _pauser) external onlyOwner {

170:     /**
          * @notice Set (or clear, with address(0)) the yield strategy that custodies `token`'s principal.
          * @dev On set to a non-zero strategy: approves it for unlimited `token` and sweeps any idle balance
          *      already held by the contract into the new strategy (so subsequent withdrawals resolve against
          *      it). When clearing or replacing, the old strategy's allowance is reset to 0. Replacing an
          *      in-use strategy does NOT migrate funds out of the old one (see CLAUDE.md / story Concerns):
          *      drain the old strategy or replace only while `totalStaked == 0`.
          *
          *      Wiring prerequisite: the strategy owner must authorize this contract as a client
          *      (`strategy.setClient(address(this), true)`) before deposits will succeed.
          */
         function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

220:     /// @notice Stake `amount` of `token`. Any pending reward is minted to the caller first.
         function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

237:     /// @notice Withdraw `amount` of staked `token`. Any pending reward is minted to the caller.
         function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

263:     /// @notice Mint the caller's pending phUSD reward for `token` without touching principal.
         function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

275:     /**
          * @notice Escape hatch: withdraw the caller's full principal for `token`, forfeiting any
          *         pending reward. Works while paused and never touches reward accounting, so a
          *         broken mint path can never trap principal.
          */
         function emergencyWithdraw(address token) external nonReentrant {

296:     /**
          * @notice Permissioned batched exit (see {IStableStaker-migrateOut}). Settles and mints each
          *         user's pending reward, zeroes their position, and transfers the aggregate principal
          *         to the migrator. Callable while paused so a migration can proceed during an incident.
          */
         function migrateOut(address token, address[] calldata users)

339:     /**
          * @notice Permissioned deposit crediting `user` (see {IStableStaker-depositFor}). Pulls
          *         `amount` of `token` from the migrator. Callable while paused so a freshly deployed
          *         (and possibly paused) target can be seeded.
          */
         function depositFor(address token, address user, uint256 amount)

511:     /**
          * @notice Owner-only rescue of arbitrary ERC20s that have accumulated in the contract
          *         (wrong-token transfers, dust, faucet mistakes, idle buffer). Guarded so the owner
          *         cannot withdraw user principal: when a token has no strategy set, user principal
          *         is held idle in this contract and is reserved (= `poolInfo[token].totalStaked`);
          *         when a strategy is set, principal lives inside the strategy and the contract
          *         balance is purely buffer + dust, so the full balance is rescuable.
          * @dev Works while paused — owner rescue is most useful exactly when normal flow is halted.
          *      No `nonReentrant`: there is no state to corrupt after the trailing `safeTransfer`.
          */
         function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

### <a name="NC-11"></a>[NC-11] Incomplete NatSpec: `@return` is missing on actually documented functions
The following functions are missing `@return` NatSpec comments.

*Instances (1)*:
```solidity
File: StableStaker.sol

296:     /**
          * @notice Permissioned batched exit (see {IStableStaker-migrateOut}). Settles and mints each
          *         user's pending reward, zeroes their position, and transfers the aggregate principal
          *         to the migrator. Callable while paused so a migration can proceed during an incident.
          */
         function migrateOut(address token, address[] calldata users)
             external
             nonReentrant
             onlyMigrator
             poolExists(token)
             returns (uint256[] memory amounts)

```

### <a name="NC-12"></a>[NC-12] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (3)*:
```solidity
File: StableStaker.sol

110:         require(msg.sender == pauser, "StableStaker: only pauser");

115:         require(msg.sender == migrator, "StableStaker: only migrator");

214:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

```

### <a name="NC-13"></a>[NC-13] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (4)*:
```solidity
File: StableStaker.sol

75:     mapping(address => PoolInfo) public poolInfo;

78:     mapping(address => mapping(address => UserInfo)) public userInfo;

81:     mapping(address => EnumerableSet.AddressSet) private _stakers;

89:     mapping(address => IYieldStrategy) public yieldStrategy;

```

### <a name="NC-14"></a>[NC-14] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: StableStaker.sol

164:     function setPauser(address _pauser) external onlyOwner {

```

### <a name="NC-15"></a>[NC-15] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (3)*:
```solidity
File: StableStaker.sol

479:     /**
          * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
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
                     return amount;
                 }
                 revert("StableStaker: strategy underwater");
             }
             uint256 balanceBefore = t.balanceOf(address(this));
             strategy.withdraw(token, amount, address(this));
             return t.balanceOf(address(this)) - balanceBefore;

479:     /**
          * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
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

479:     /**
          * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
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
                     return amount;

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
File: StableStaker.sol

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
   EventDefinition.DepositedFor
   EventDefinition.BufferWithdrawn
   EventDefinition.ERC20Rescued
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
   FunctionDefinition.migrateOut
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
   StructDefinition.PoolInfo
   StructDefinition.UserInfo
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
   EventDefinition.DepositedFor
   EventDefinition.BufferWithdrawn
   EventDefinition.ERC20Rescued
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
   FunctionDefinition.migrateOut
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

### <a name="NC-17"></a>[NC-17] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: StableStaker.sol

49:     uint256 public constant SECONDS_PER_DAY = 86400;

```

### <a name="NC-18"></a>[NC-18] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (10)*:
```solidity
File: StableStaker.sol

94:     event RewardRateSet(address indexed token, uint256 phusdPerDay, uint256 phusdPerSecond);

98:     event Staked(address indexed token, address indexed user, uint256 amount);

99:     event Withdrawn(address indexed token, address indexed user, uint256 amount);

100:     event Claimed(address indexed token, address indexed user, uint256 reward);

101:     event EmergencyWithdrawn(address indexed token, address indexed user, uint256 amount);

102:     event MigratedOut(address indexed token, address indexed user, uint256 amount, uint256 reward);

103:     event DepositedFor(address indexed token, address indexed user, uint256 amount);

104:     event BufferWithdrawn(address indexed token, address indexed user, uint256 amount);

105:     event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

```

```solidity
File: StableStakerMigrator.sol

31:     event Migrated(address indexed token, uint256 userCount, uint256 totalPrincipal);

```

### <a name="NC-19"></a>[NC-19] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (3)*:
```solidity
File: StableStaker.sol

312:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: StableStakerMigrator.sol

49:         for (uint256 i = 0; i < amounts.length; i++) {

60:         for (uint256 i = 0; i < users.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 3 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 5 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-4](#L-4) | Division by zero not prevented | 2 |
| [L-5](#L-5) | External calls in an un-bounded `for-`loop may result in a DOS | 1 |
| [L-6](#L-6) | Owner can renounce while system is paused | 1 |
| [L-7](#L-7) | Possible rounding issue | 2 |
| [L-8](#L-8) | Loss of precision | 12 |
| [L-9](#L-9) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 2 |
| [L-10](#L-10) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-11](#L-11) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (3)*:
```solidity
File: StableStaker.sol

41: contract StableStaker is Ownable, Pausable, ReentrancyGuard, IPausable {

```

```solidity
File: StableStakerMigrator.sol

22: contract StableStakerMigrator is Ownable {

33:     constructor(IStableStaker _oldStaker, IStableStaker _newStaker, address initialOwner) Ownable(initialOwner) {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (5)*:
```solidity
File: StableStaker.sol

259:         IERC20(token).safeTransfer(msg.sender, payout);

290:         IERC20(token).safeTransfer(msg.sender, payout);

335:             IERC20(token).safeTransfer(msg.sender, payout);

460:         t.safeTransferFrom(from, address(this), amount);

526:         IERC20(token).safeTransfer(to, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: StableStaker.sol

166:         pauser = _pauser;

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (2)*:
```solidity
File: StableStaker.sol

374:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

441:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```

### <a name="L-5"></a>[L-5] External calls in an un-bounded `for-`loop may result in a DOS
Consider limiting the number of iterations in for-loops that make external calls

*Instances (1)*:
```solidity
File: StableStaker.sol

323:             _stakers[token].remove(u);

```

### <a name="L-6"></a>[L-6] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: StableStaker.sol

164:     function setPauser(address _pauser) external onlyOwner {

```

### <a name="L-7"></a>[L-7] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (2)*:
```solidity
File: StableStaker.sol

374:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

441:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```

### <a name="L-8"></a>[L-8] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (12)*:
```solidity
File: StableStaker.sol

152:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

232:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

245:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

248:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

268:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

270:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

319:             uint256 pending = (amt * pool.accPhusdPerShare) / ACC_PRECISION - info.rewardDebt;

360:         info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;

374:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

377:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

441:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

449:             uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

```

### <a name="L-9"></a>[L-9] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (2)*:
```solidity
File: StableStaker.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: StableStakerMigrator.sol

2: pragma solidity ^0.8.20;

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

*Instances (2)*:
```solidity
File: StableStaker.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: StableStakerMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-11"></a>[L-11] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: StableStaker.sol

521:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 11 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: StableStaker.sol

460:         t.safeTransferFrom(from, address(this), amount);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (11)*:
```solidity
File: StableStaker.sol

41: contract StableStaker is Ownable, Pausable, ReentrancyGuard, IPausable {

130:     constructor(IFlax _phUSD, address initialOwner) Ownable(initialOwner) {

138:     function addToken(address token) external onlyOwner {

150:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

158:     function setMigrator(address _migrator) external onlyOwner {

164:     function setPauser(address _pauser) external onlyOwner {

181:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

521:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: StableStakerMigrator.sol

22: contract StableStakerMigrator is Ownable {

33:     constructor(IStableStaker _oldStaker, IStableStaker _newStaker, address initialOwner) Ownable(initialOwner) {

45:     function migrate(address token, address[] calldata users) external onlyOwner {

```

