# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 4 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 1 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 2 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 25 |
| [GAS-5](#GAS-5) | Use Custom Errors instead of Revert Strings to save Gas | 4 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 1 |
| [GAS-7](#GAS-7) | State variables only set in the constructor should be declared `immutable` | 2 |
| [GAS-8](#GAS-8) | Functions guaranteed to revert when called by normal users can be marked `payable` | 4 |
| [GAS-9](#GAS-9) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 6 |
| [GAS-10](#GAS-10) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-11](#GAS-11) | Increments/decrements can be unchecked in for-loops | 4 |
| [GAS-12](#GAS-12) | Use != 0 instead of > 0 for unsigned integer comparison | 3 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (4)*:
```solidity
File: src/InPlaceMigrator.sol

153:                 parked[token][users[i]] += amt;

156:                 totalParked[token] += amt;

157:                 total += amt;

198:             total += parked[token][user];

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (1)*:
```solidity
File: src/InPlaceMigrator.sol

111:         require(address(_staker) != address(0), "InPlaceMigrator: zero staker");

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (2)*:
```solidity
File: src/InPlaceMigrator.sol

150:         for (uint256 i = 0; i < users.length; i++) {

303:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (25)*:
```solidity
File: src/InPlaceMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

5: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

8: import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

9: import "./interfaces/IStableStaker.sol";

150:         for (uint256 i = 0; i < users.length; i++) {

153:                 parked[token][users[i]] += amt;

156:                 totalParked[token] += amt;

157:                 total += amt;

158:                 count++;

192:         uint256 sliceLen = end - start;

195:         for (uint256 i = 0; i < sliceLen; i++) {

196:             address user = set.at(start + i);

198:             total += parked[token][user];

207:         for (uint256 i = 0; i < sliceLen; i++) {

217:             totalParked[token] -= amt;

219:             count++;

243:             block.timestamp >= migrationBegin[token][msg.sender] + migrationTimeout,

250:         totalParked[token] -= amount;

271:         uint256 surplus = IERC20(token).balanceOf(address(this)) - totalParked[token];

302:         users = new address[](end - start);

303:         for (uint256 i = 0; i < users.length; i++) {

304:             users[i] = set.at(start + i);

314:         return begin + migrationTimeout;

```

### <a name="GAS-5"></a>[GAS-5] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (4)*:
```solidity
File: src/InPlaceMigrator.sol

111:         require(address(_staker) != address(0), "InPlaceMigrator: zero staker");

189:         require(start <= end, "InPlaceMigrator: bad range");

241:         require(amount > 0, "InPlaceMigrator: nothing parked");

272:         require(amount <= surplus, "InPlaceMigrator: cannot touch parked principal");

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (1)*:
```solidity
File: src/InPlaceMigrator.sol

271:         uint256 surplus = IERC20(token).balanceOf(address(this)) - totalParked[token];

```

### <a name="GAS-7"></a>[GAS-7] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (2)*:
```solidity
File: src/InPlaceMigrator.sol

118:         staker = _staker;

119:         migrationTimeout = _migrationTimeout;

```

### <a name="GAS-8"></a>[GAS-8] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (4)*:
```solidity
File: src/InPlaceMigrator.sol

130:     function initiateMigration(address token) external onlyOwner {

145:     function migrateOut(address token, address[] calldata users) external onlyOwner nonReentrant {

183:     function migrateIn(address token, uint256 start, uint256 end) external onlyOwner nonReentrant {

270:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

### <a name="GAS-9"></a>[GAS-9] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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
File: src/InPlaceMigrator.sol

150:         for (uint256 i = 0; i < users.length; i++) {

158:                 count++;

195:         for (uint256 i = 0; i < sliceLen; i++) {

207:         for (uint256 i = 0; i < sliceLen; i++) {

219:             count++;

303:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-10"></a>[GAS-10] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: src/InPlaceMigrator.sol

90:     uint256 public constant MIN_TIMEOUT = 1 days;

94:     uint256 public constant MAX_TIMEOUT = 30 days;

```

### <a name="GAS-11"></a>[GAS-11] Increments/decrements can be unchecked in for-loops
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
File: src/InPlaceMigrator.sol

150:         for (uint256 i = 0; i < users.length; i++) {

195:         for (uint256 i = 0; i < sliceLen; i++) {

207:         for (uint256 i = 0; i < sliceLen; i++) {

303:         for (uint256 i = 0; i < users.length; i++) {

```

### <a name="GAS-12"></a>[GAS-12] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (3)*:
```solidity
File: src/InPlaceMigrator.sol

152:             if (amt > 0) {

202:         if (total > 0) {

241:         require(amount > 0, "InPlaceMigrator: nothing parked");

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Consider disabling `renounceOwnership()` | 1 |
| [NC-2](#NC-2) | Functions should not be longer than 50 lines | 8 |
| [NC-3](#NC-3) | Consider using named mappings | 4 |
| [NC-4](#NC-4) | Event is missing `indexed` fields | 3 |
| [NC-5](#NC-5) | Variables need not be initialized to zero | 4 |
### <a name="NC-1"></a>[NC-1] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/InPlaceMigrator.sol

58: contract InPlaceMigrator is Ownable, ReentrancyGuard {

```

### <a name="NC-2"></a>[NC-2] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (8)*:
```solidity
File: src/InPlaceMigrator.sol

130:     function initiateMigration(address token) external onlyOwner {

145:     function migrateOut(address token, address[] calldata users) external onlyOwner nonReentrant {

183:     function migrateIn(address token, uint256 start, uint256 end) external onlyOwner nonReentrant {

239:     function claimTimedOut(address token) external nonReentrant {

270:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

279:     function parkedUserCount(address token) external view returns (uint256) {

289:     function parkedUsersRange(address token, uint256 start, uint256 end)

309:     function claimableAt(address token, address user) external view returns (uint256) {

```

### <a name="NC-3"></a>[NC-3] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (4)*:
```solidity
File: src/InPlaceMigrator.sol

77:     mapping(address => mapping(address => uint256)) public parked;

80:     mapping(address => mapping(address => uint256)) public migrationBegin;

83:     mapping(address => EnumerableSet.AddressSet) private _parkedUsers;

86:     mapping(address => uint256) public totalParked;

```

### <a name="NC-4"></a>[NC-4] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (3)*:
```solidity
File: src/InPlaceMigrator.sol

97:     event MigratedOut(address indexed token, uint256 userCount, uint256 totalPrincipal);

100:     event MigratedIn(address indexed token, uint256 userCount, uint256 totalPrincipal);

103:     event TimedOutClaim(address indexed token, address indexed user, uint256 amount);

```

### <a name="NC-5"></a>[NC-5] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (4)*:
```solidity
File: src/InPlaceMigrator.sol

150:         for (uint256 i = 0; i < users.length; i++) {

195:         for (uint256 i = 0; i < sliceLen; i++) {

207:         for (uint256 i = 0; i < sliceLen; i++) {

303:         for (uint256 i = 0; i < users.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 2 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 2 |
| [L-3](#L-3) | External calls in an un-bounded `for-`loop may result in a DOS | 2 |
| [L-4](#L-4) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
| [L-5](#L-5) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
| [L-6](#L-6) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: src/InPlaceMigrator.sol

58: contract InPlaceMigrator is Ownable, ReentrancyGuard {

110:     constructor(IStableStaker _staker, uint256 _migrationTimeout, address initialOwner) Ownable(initialOwner) {

```

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (2)*:
```solidity
File: src/InPlaceMigrator.sol

254:         IERC20(token).safeTransfer(msg.sender, amount);

273:         IERC20(token).safeTransfer(to, amount);

```

### <a name="L-3"></a>[L-3] External calls in an un-bounded `for-`loop may result in a DOS
Consider limiting the number of iterations in for-loops that make external calls

*Instances (2)*:
```solidity
File: src/InPlaceMigrator.sol

155:                 _parkedUsers[token].add(users[i]);

218:             _parkedUsers[token].remove(user);

```

### <a name="L-4"></a>[L-4] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: src/InPlaceMigrator.sol

2: pragma solidity ^0.8.20;

```

### <a name="L-5"></a>[L-5] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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

*Instances (1)*:
```solidity
File: src/InPlaceMigrator.sol

4: import "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-6"></a>[L-6] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: src/InPlaceMigrator.sol

270:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 6 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (6)*:
```solidity
File: src/InPlaceMigrator.sol

58: contract InPlaceMigrator is Ownable, ReentrancyGuard {

110:     constructor(IStableStaker _staker, uint256 _migrationTimeout, address initialOwner) Ownable(initialOwner) {

130:     function initiateMigration(address token) external onlyOwner {

145:     function migrateOut(address token, address[] calldata users) external onlyOwner nonReentrant {

183:     function migrateIn(address token, uint256 start, uint256 end) external onlyOwner nonReentrant {

270:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

