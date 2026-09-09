# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 8 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 12 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 3 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 61 |
| [GAS-5](#GAS-5) | Use Custom Errors instead of Revert Strings to save Gas | 29 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 7 |
| [GAS-7](#GAS-7) | Stack variable used as a cheaper cache for a state variable is only used once | 1 |
| [GAS-8](#GAS-8) | State variables only set in the constructor should be declared `immutable` | 3 |
| [GAS-9](#GAS-9) | Functions guaranteed to revert when called by normal users can be marked `payable` | 10 |
| [GAS-10](#GAS-10) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 5 |
| [GAS-11](#GAS-11) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 4 |
| [GAS-13](#GAS-13) | Use != 0 instead of > 0 for unsigned integer comparison | 17 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (8)*:
```solidity
File: StableStaker.sol

269:         user.amount += credited;

270:         pool.totalStaked += credited;

462:             total += credit;

550:         info.amount += credited;

551:         pool.totalStaked += credited;

568:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

641:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```

```solidity
File: StableStakerMigrator.sol

66:             total += amounts[i];

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (12)*:
```solidity
File: StableStaker.sol

148:         require(address(_phUSD) != address(0), "StableStaker: zero phUSD");

156:         require(token != address(0), "StableStaker: zero token");

206:         if (address(old) != address(0)) {

225:         if (address(strategy) != address(0)) {

411:             address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0,

418:             IERC20(token).forceApprove(address(strategy), 0);

615:             return false;

677:             return amount; // idle hold: full credit

694:             return amount;

727:         uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;

```

```solidity
File: StableStakerMigrator.sol

37:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

38:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (3)*:
```solidity
File: StableStaker.sol

458:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: StableStakerMigrator.sol

65:         for (uint256 i = 0; i < amounts.length; i++) {

76:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (61)*:
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

98:         bool active; // terminal once true

99:         uint256 realized; // R: token realized into this contract by the full strategy exit

100:         uint256 principalSnapshot; // P: poolInfo[token].totalStaked captured at initiateMigration

169:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

269:         user.amount += credited;

270:         pool.totalStaked += credited;

271:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

287:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

288:         user.amount -= amount;

289:         pool.totalStaked -= amount;

290:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

310:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

312:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

331:         poolInfo[token].totalStaked -= amount;

458:         for (uint256 i = 0; i < users.length; i++) {

462:             total += credit;

485:         uint256 S = mig.realized < P ? mig.realized : P; // min(R, P): caps credits at par

486:         credit = (amt * S) / P;

490:         uint256 pending = (amt * pool.accPhusdPerShare) / ACC_PRECISION - info.rewardDebt;

494:         pool.totalStaked -= amt;

550:         info.amount += credited;

551:         pool.totalStaked += credited;

552:         info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;

566:             uint256 elapsed = block.timestamp - pool.lastRewardTime;

567:             uint256 reward = elapsed * pool.phusdPerSecond;

568:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

571:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

590:         address[] memory out = new address[](end - start);

591:         for (uint256 i = start; i < end; i++) {

592:             out[i - start] = set.at(i);

638:         uint256 elapsed = block.timestamp - pool.lastRewardTime;

639:         uint256 reward = elapsed * pool.phusdPerSecond;

641:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

649:             uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

661:         return t.balanceOf(address(this)) - balanceBefore;

677:             return amount; // idle hold: full credit

710:         return t.balanceOf(address(this)) - balanceBefore;

729:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```

```solidity
File: StableStakerMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import "./interfaces/IStableStaker.sol";

65:         for (uint256 i = 0; i < amounts.length; i++) {

66:             total += amounts[i];

76:         for (uint256 i = 0; i < users.length; i++) {

79:                 migratedCount++;

```

### <a name="GAS-5"></a>[GAS-5] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (29)*:
```solidity
File: StableStaker.sol

127:         require(msg.sender == pauser, "StableStaker: only pauser");

132:         require(msg.sender == migrator, "StableStaker: only migrator");

137:         require(_registeredTokens.contains(token), "StableStaker: unknown token");

148:         require(address(_phUSD) != address(0), "StableStaker: zero phUSD");

156:         require(token != address(0), "StableStaker: zero token");

157:         require(_registeredTokens.add(token), "StableStaker: token exists");

203:         require(!migrationInfo[token].active, "StableStaker: migrating");

249:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

257:         require(amount > 0, "StableStaker: amount=0");

260:         require(!migrationInfo[token].active, "StableStaker: migrating");

268:         require(credited > 0, "StableStaker: nothing credited");

278:         require(amount > 0, "StableStaker: amount=0");

281:         require(!migrationInfo[token].active, "StableStaker: migrating");

284:         require(user.amount >= amount, "StableStaker: insufficient stake");

311:         require(pending > 0, "StableStaker: nothing to claim");

325:         require(!migrationInfo[token].active, "StableStaker: migrating");

328:         require(amount > 0, "StableStaker: nothing staked");

388:         require(!migrationInfo[token].active, "StableStaker: already migrating");

454:         require(migrationInfo[token].active, "StableStaker: not migrating");

514:         require(migrationInfo[token].active, "StableStaker: not migrating");

515:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

540:         require(amount > 0, "StableStaker: amount=0");

542:         require(!migrationInfo[token].active, "StableStaker: migrating");

589:         require(start <= end, "StableStaker: bad range");

706:             revert("StableStaker: strategy underwater");

726:         require(to != address(0), "StableStaker: zero recipient");

729:         require(bal >= reserved + amount, "StableStaker: would touch user principal");

```

```solidity
File: StableStakerMigrator.sol

37:         require(address(_oldStaker) != address(0), "Migrator: zero old staker");

38:         require(address(_newStaker) != address(0), "Migrator: zero new staker");

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (7)*:
```solidity
File: StableStaker.sol

231:             uint256 idleBalance = IERC20(token).balanceOf(address(this));

659:         uint256 balanceBefore = t.balanceOf(address(this));

661:         return t.balanceOf(address(this)) - balanceBefore;

701:             if (t.balanceOf(address(this)) >= amount) {

708:         uint256 balanceBefore = t.balanceOf(address(this));

710:         return t.balanceOf(address(this)) - balanceBefore;

728:         uint256 bal = IERC20(token).balanceOf(address(this));

```

### <a name="GAS-7"></a>[GAS-7] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (1)*:
```solidity
File: StableStaker.sol

182:         address old = pauser;

```

### <a name="GAS-8"></a>[GAS-8] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (3)*:
```solidity
File: StableStaker.sol

149:         phUSD = _phUSD;

```

```solidity
File: StableStakerMigrator.sol

39:         oldStaker = _oldStaker;

40:         newStaker = _newStaker;

```

### <a name="GAS-9"></a>[GAS-9] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (10)*:
```solidity
File: StableStaker.sol

155:     function addToken(address token) external onlyOwner {

167:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

175:     function setMigrator(address _migrator) external onlyOwner {

181:     function setPauser(address _pauser) external onlyOwner {

202:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

243:     function pause() external override onlyPauser {

387:     function initiateMigration(address token) external nonReentrant onlyMigrator poolExists(token) {

725:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: StableStakerMigrator.sol

51:     function initiateMigration(address token) external onlyOwner {

61:     function migrate(address token, address[] calldata users) external onlyOwner {

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

458:         for (uint256 i = 0; i < users.length; i++) {

591:         for (uint256 i = start; i < end; i++) {

```

```solidity
File: StableStakerMigrator.sol

65:         for (uint256 i = 0; i < amounts.length; i++) {

76:         for (uint256 i = 0; i < users.length; i++) {

79:                 migratedCount++;

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

458:         for (uint256 i = 0; i < users.length; i++) {

591:         for (uint256 i = start; i < end; i++) {

```

```solidity
File: StableStakerMigrator.sol

65:         for (uint256 i = 0; i < amounts.length; i++) {

76:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-13"></a>[GAS-13] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (17)*:
```solidity
File: StableStaker.sol

215:             if (staked > 0) {

232:             if (idleBalance > 0) {

257:         require(amount > 0, "StableStaker: amount=0");

268:         require(credited > 0, "StableStaker: nothing credited");

278:         require(amount > 0, "StableStaker: amount=0");

295:         if (pending > 0) {

311:         require(pending > 0, "StableStaker: nothing to claim");

328:         require(amount > 0, "StableStaker: nothing staked");

464:         if (total > 0) {

497:         if (pending > 0) {

515:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

540:         require(amount > 0, "StableStaker: amount=0");

565:         if (!migrationInfo[token].active && block.timestamp > pool.lastRewardTime && pool.totalStaked > 0) {

640:         if (reward > 0) {

648:         if (user.amount > 0) {

650:             if (pending > 0) {

```

```solidity
File: StableStakerMigrator.sol

77:             if (amounts[i] > 0) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 2 |
| [NC-3](#NC-3) | Critical Changes Should Use Two-step Procedure | 1 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 2 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 12 |
| [NC-6](#NC-6) | Events that mark critical parameter changes should contain both the old and the new value | 3 |
| [NC-7](#NC-7) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-8](#NC-8) | Functions should not be longer than 50 lines | 31 |
| [NC-9](#NC-9) | Lack of checks in setters | 2 |
| [NC-10](#NC-10) | Incomplete NatSpec: `@param` is missing on actually documented functions | 11 |
| [NC-11](#NC-11) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 4 |
| [NC-12](#NC-12) | Consider using named mappings | 5 |
| [NC-13](#NC-13) | Owner can renounce while system is paused | 1 |
| [NC-14](#NC-14) | Adding a `return` statement when the function defines a named return variable, is redundant | 5 |
| [NC-15](#NC-15) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-16](#NC-16) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-17](#NC-17) | Event is missing `indexed` fields | 12 |
| [NC-18](#NC-18) | Variables need not be initialized to zero | 3 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: StableStaker.sol

183:         pauser = _pauser;

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

202:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

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

25: contract StableStakerMigrator is Ownable {

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (12)*:
```solidity
File: StableStaker.sol

203:         require(!migrationInfo[token].active, "StableStaker: migrating");

257:         require(amount > 0, "StableStaker: amount=0");

260:         require(!migrationInfo[token].active, "StableStaker: migrating");

278:         require(amount > 0, "StableStaker: amount=0");

281:         require(!migrationInfo[token].active, "StableStaker: migrating");

325:         require(!migrationInfo[token].active, "StableStaker: migrating");

328:         require(amount > 0, "StableStaker: nothing staked");

454:         require(migrationInfo[token].active, "StableStaker: not migrating");

514:         require(migrationInfo[token].active, "StableStaker: not migrating");

515:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

541:         // Frozen on the migrating (old) staker: a deposit would change `P`. See TERMINAL MIGRATION.

542:         require(!migrationInfo[token].active, "StableStaker: migrating");

```

### <a name="NC-6"></a>[NC-6] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (3)*:
```solidity
File: StableStaker.sol

175:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

181:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

202:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
             require(!migrationInfo[token].active, "StableStaker: migrating");
     
             IYieldStrategy old = yieldStrategy[token];
             if (address(old) != address(0)) {
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
   external initiateMigration
   external batchMigrate
   internal _exitPosition
   external userMigrate
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

### <a name="NC-8"></a>[NC-8] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (31)*:
```solidity
File: StableStaker.sol

155:     function addToken(address token) external onlyOwner {

167:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

175:     function setMigrator(address _migrator) external onlyOwner {

181:     function setPauser(address _pauser) external onlyOwner {

202:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

256:     function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

277:     function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

306:     function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

322:     function emergencyWithdraw(address token) external nonReentrant {

387:     function initiateMigration(address token) external nonReentrant onlyMigrator poolExists(token) {

447:     function batchMigrate(address token, address[] calldata users)

477:     function _exitPosition(address token, address account) internal returns (uint256 credit) {

513:     function userMigrate(address token) external nonReentrant {

534:     function depositFor(address token, address user, uint256 amount)

562:     function pendingReward(address token, address account) external view returns (uint256) {

575:     function getStakers(address token) external view returns (address[] memory) {

583:     function getStakersRange(address token, uint256 start, uint256 end) external view returns (address[] memory) {

598:     function stakerCount(address token) external view returns (uint256) {

603:     function getStakedTokens() external view returns (address[] memory) {

612:     function withdrawDisabled(address token) external view returns (bool) {

647:     function _settle(address account, UserInfo storage user, PoolInfo storage pool) internal {

657:     function _pullToken(address token, address from, uint256 amount) internal returns (uint256) {

666:     function _isUnderwater(address token, IYieldStrategy strategy) internal view returns (bool) {

674:     function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {

691:     function _routeExit(address token, uint256 amount, bool guardUnderwater) internal returns (uint256 payout) {

725:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: StableStakerMigrator.sol

51:     function initiateMigration(address token) external onlyOwner {

61:     function migrate(address token, address[] calldata users) external onlyOwner {

```

```solidity
File: interfaces/IStableStaker.sol

18:     function initiateMigration(address token) external;

33:     function batchMigrate(address token, address[] calldata users) external returns (uint256[] memory amounts);

42:     function depositFor(address token, address user, uint256 amount) external;

```

### <a name="NC-9"></a>[NC-9] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (2)*:
```solidity
File: StableStaker.sol

175:     function setMigrator(address _migrator) external onlyOwner {
             migrator = _migrator;
             emit MigratorSet(_migrator);

181:     function setPauser(address _pauser) external onlyOwner {
             address old = pauser;
             pauser = _pauser;
             emit PauserUpdated(old, _pauser);

```

### <a name="NC-10"></a>[NC-10] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (11)*:
```solidity
File: StableStaker.sol

154:     /// @notice Register a new stable token as a reward pool.
         function addToken(address token) external onlyOwner {

163:      * @notice Set the daily phUSD emission budget for a token. Internally converted to a
          *         per-second rate (`amountPerDay / SECONDS_PER_DAY`, rounded down). The pool is
          *         settled at the existing rate first so the change never applies retroactively.
          */
         function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

174:     /// @notice Set the address authorized to perform permissioned migration.
         function setMigrator(address _migrator) external onlyOwner {

180:     /// @notice Set (or clear, with address(0)) the pauser address.
         function setPauser(address _pauser) external onlyOwner {

188:      * @notice Set (or clear, with address(0)) the yield strategy that custodies `token`'s principal.
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

255:     /// @notice Stake `amount` of `token`. Any pending reward is minted to the caller first.
         function stake(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

276:     /// @notice Withdraw `amount` of staked `token`. Any pending reward is minted to the caller.
         function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused poolExists(token) {

305:     /// @notice Mint the caller's pending phUSD reward for `token` without touching principal.
         function claim(address token) external nonReentrant whenNotPaused poolExists(token) {

318:      * @notice Escape hatch: withdraw the caller's full principal for `token`, forfeiting any
          *         pending reward. Works while paused and never touches reward accounting, so a
          *         broken mint path can never trap principal.
          */
         function emergencyWithdraw(address token) external nonReentrant {

527:      * @notice Permissioned deposit crediting `user` (see {IStableStaker-depositFor}). Pulls
          *         `amount` of `token` from the migrator. Callable while paused so a freshly deployed
          *         (and possibly paused) target can be seeded.
          * @dev On a token under terminal migration this is the OLD staker and is blocked (would change the
          *      `P` snapshot). The migrator's redeposit target is the NEW (healthy) staker, where this
          *      guard does not trip.
          */
         function depositFor(address token, address user, uint256 amount)
             external
             nonReentrant

716:      * @notice Owner-only rescue of arbitrary ERC20s that have accumulated in the contract
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

### <a name="NC-11"></a>[NC-11] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (4)*:
```solidity
File: StableStaker.sol

127:         require(msg.sender == pauser, "StableStaker: only pauser");

132:         require(msg.sender == migrator, "StableStaker: only migrator");

249:         require(msg.sender == owner() || msg.sender == pauser, "StableStaker: only owner or pauser");

515:         require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

```

### <a name="NC-12"></a>[NC-12] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (5)*:
```solidity
File: StableStaker.sol

75:     mapping(address => PoolInfo) public poolInfo;

78:     mapping(address => mapping(address => UserInfo)) public userInfo;

81:     mapping(address => EnumerableSet.AddressSet) private _stakers;

89:     mapping(address => IYieldStrategy) public yieldStrategy;

104:     mapping(address => MigrationInfo) public migrationInfo;

```

### <a name="NC-13"></a>[NC-13] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: StableStaker.sol

181:     function setPauser(address _pauser) external onlyOwner {

```

### <a name="NC-14"></a>[NC-14] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (5)*:
```solidity
File: StableStaker.sol

471:      * @dev Shared terminal-migration exit for one user: mints their frozen pending phUSD, computes the
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

670:     /// @dev If a strategy is set for `token`, deposit `amount` into it under this contract's
         ///      account and return the principal the strategy actually booked (the market strategy
         ///      haircuts this below `amount`; direct strategies return `amount`). When no strategy is
         ///      set the tokens sit idle in this contract, so the full `amount` is credited.
         function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {
             IYieldStrategy strategy = yieldStrategy[token];
             if (address(strategy) == address(0)) {
                 return amount; // idle hold: full credit
             }
             return strategy.deposit(token, amount, address(this));

683:      * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
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

683:      * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
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

683:      * @dev If a strategy is set for `token`, redeem `amount` of principal from it to this contract
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

### <a name="NC-15"></a>[NC-15] Contract does not follow the Solidity style guide's suggested layout ordering
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
   VariableDeclaration.migrationInfo
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

### <a name="NC-16"></a>[NC-16] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: StableStaker.sol

49:     uint256 public constant SECONDS_PER_DAY = 86400;

```

### <a name="NC-17"></a>[NC-17] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (12)*:
```solidity
File: StableStaker.sol

109:     event RewardRateSet(address indexed token, uint256 phusdPerDay, uint256 phusdPerSecond);

113:     event Staked(address indexed token, address indexed user, uint256 amount);

114:     event Withdrawn(address indexed token, address indexed user, uint256 amount);

115:     event Claimed(address indexed token, address indexed user, uint256 reward);

116:     event EmergencyWithdrawn(address indexed token, address indexed user, uint256 amount);

117:     event MigratedOut(address indexed token, address indexed user, uint256 amount, uint256 reward);

118:     event MigrationInitiated(address indexed token, uint256 realized, uint256 principalSnapshot);

119:     event UserMigrated(address indexed token, address indexed user, uint256 credit);

120:     event DepositedFor(address indexed token, address indexed user, uint256 amount);

121:     event BufferWithdrawn(address indexed token, address indexed user, uint256 amount);

122:     event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

```

```solidity
File: StableStakerMigrator.sol

34:     event Migrated(address indexed token, uint256 userCount, uint256 totalPrincipal);

```

### <a name="NC-18"></a>[NC-18] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (3)*:
```solidity
File: StableStaker.sol

458:         for (uint256 i = 0; i < users.length; i++) {

```

```solidity
File: StableStakerMigrator.sol

65:         for (uint256 i = 0; i < amounts.length; i++) {

76:         for (uint256 i = 0; i < users.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 3 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 6 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-4](#L-4) | Division by zero not prevented | 3 |
| [L-5](#L-5) | Owner can renounce while system is paused | 1 |
| [L-6](#L-6) | Possible rounding issue | 2 |
| [L-7](#L-7) | Loss of precision | 12 |
| [L-8](#L-8) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 2 |
| [L-9](#L-9) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-10](#L-10) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (3)*:
```solidity
File: StableStaker.sol

41: contract StableStaker is Ownable, Pausable, ReentrancyGuard, IPausable {

```

```solidity
File: StableStakerMigrator.sol

25: contract StableStakerMigrator is Ownable {

36:     constructor(IStableStaker _oldStaker, IStableStaker _newStaker, address initialOwner) Ownable(initialOwner) {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (6)*:
```solidity
File: StableStaker.sol

301:         IERC20(token).safeTransfer(msg.sender, payout);

335:         IERC20(token).safeTransfer(msg.sender, payout);

466:             IERC20(token).safeTransfer(msg.sender, total);

521:         emit UserMigrated(token, msg.sender, credit);

661:         return t.balanceOf(address(this)) - balanceBefore;

731:         emit ERC20Rescued(token, to, amount);

```

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: StableStaker.sol

183:         pauser = _pauser;

```

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (3)*:
```solidity
File: StableStaker.sol

486:         credit = (amt * S) / P;

568:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

641:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```

### <a name="L-5"></a>[L-5] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: StableStaker.sol

181:     function setPauser(address _pauser) external onlyOwner {

```

### <a name="L-6"></a>[L-6] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (2)*:
```solidity
File: StableStaker.sol

568:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

641:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

```

### <a name="L-7"></a>[L-7] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (12)*:
```solidity
File: StableStaker.sol

169:         uint256 perSecond = amountPerDay / SECONDS_PER_DAY;

271:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

287:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

290:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

310:         uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

312:         user.rewardDebt = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION;

490:         uint256 pending = (amt * pool.accPhusdPerShare) / ACC_PRECISION - info.rewardDebt;

552:         info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;

568:             acc += (reward * ACC_PRECISION) / pool.totalStaked;

571:         return (user.amount * acc) / ACC_PRECISION - user.rewardDebt;

641:             pool.accPhusdPerShare += (reward * ACC_PRECISION) / pool.totalStaked;

649:             uint256 pending = (user.amount * pool.accPhusdPerShare) / ACC_PRECISION - user.rewardDebt;

```

### <a name="L-8"></a>[L-8] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
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
File: StableStaker.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: StableStakerMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-10"></a>[L-10] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: StableStaker.sol

725:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 12 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: StableStaker.sol

661:         return t.balanceOf(address(this)) - balanceBefore;

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (12)*:
```solidity
File: StableStaker.sol

41: contract StableStaker is Ownable, Pausable, ReentrancyGuard, IPausable {

147:     constructor(IFlax _phUSD, address initialOwner) Ownable(initialOwner) {

155:     function addToken(address token) external onlyOwner {

167:     function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {

175:     function setMigrator(address _migrator) external onlyOwner {

181:     function setPauser(address _pauser) external onlyOwner {

202:     function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {

725:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

```solidity
File: StableStakerMigrator.sol

25: contract StableStakerMigrator is Ownable {

36:     constructor(IStableStaker _oldStaker, IStableStaker _newStaker, address initialOwner) Ownable(initialOwner) {

51:     function initiateMigration(address token) external onlyOwner {

61:     function migrate(address token, address[] calldata users) external onlyOwner {

```

