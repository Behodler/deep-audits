# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | For Operations that will not overflow, you could use unchecked | 13 |
| [GAS-2](#GAS-2) | Avoid contract existence checks by using low level calls | 4 |
| [GAS-3](#GAS-3) | Functions guaranteed to revert when called by normal users can be marked `payable` | 5 |
### <a name="GAS-1"></a>[GAS-1] For Operations that will not overflow, you could use unchecked

*Instances (13)*:
```solidity
File: src/Antimatter.sol

4: import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

5: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

9: import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

10: import {IFlax} from "@phUSD/IFlax.sol";

11: import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";

232:         uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;

239:         emit Annihilated(stable, from, recipient, amount, stableAmount, amount + mintedForStable);

254:         uint256 scale = 10 ** (18 - decimals);

255:         uint256 stableAmount = amount / scale;

256:         if (stableAmount * scale != amount) revert AmountNotRepresentable(amount, decimals);

```

### <a name="GAS-2"></a>[GAS-2] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (4)*:
```solidity
File: src/Antimatter.sol

219:         uint256 stableBefore = IERC20(stable).balanceOf(address(this));

220:         uint256 phUSDBefore = _phUSD.balanceOf(address(this));

230:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

232:         uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;

```

### <a name="GAS-3"></a>[GAS-3] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (5)*:
```solidity
File: src/Antimatter.sol

124:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

136:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

151:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

179:     function mint(address to, uint256 amount) external onlyApprovedMinters {

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | `constant`s should be defined rather than using magic numbers | 2 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 21 |
| [NC-3](#NC-3) | Consider disabling `renounceOwnership()` | 1 |
| [NC-4](#NC-4) | Functions should not be longer than 50 lines | 11 |
| [NC-5](#NC-5) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-6](#NC-6) | Take advantage of Custom Error's return value property | 14 |
| [NC-7](#NC-7) | Constants should be defined rather than using magic numbers | 1 |
### <a name="NC-1"></a>[NC-1] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (2)*:
```solidity
File: src/Antimatter.sol

252:         if (decimals > 18) revert UnsupportedDecimals(decimals);

254:         uint256 scale = 10 ** (18 - decimals);

```

### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (21)*:
```solidity
File: src/Antimatter.sol

10: import {IFlax} from "@phUSD/IFlax.sol";

101:     IFlax public phUSD;

125:         if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();

137:         if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();

138:         IFlax _phUSD = phUSD;

139:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

152:         if (minter == address(0)) revert ApprovedMinterZeroAddress();

154:         if (changed) emit ApprovedMinterSet(minter, approved);

202:         if (amount == 0) revert ZeroAmount();

203:         if (recipient == address(0)) revert RecipientZeroAddress();

205:         IFlax _phUSD = phUSD;

206:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

208:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

214:         if (from != msg.sender) _spendAllowance(from, msg.sender, amount);

230:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

233:         if (mintedForStable == 0) revert PhUSDNotReceived();

248:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

251:         if (yieldStrategy == address(0)) revert StablecoinNotRegistered(stable);

252:         if (decimals > 18) revert UnsupportedDecimals(decimals);

256:         if (stableAmount * scale != amount) revert AmountNotRepresentable(amount, decimals);

264:         if (to == address(0)) revert RecipientZeroAddress();

```

### <a name="NC-3"></a>[NC-3] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

21: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

```

### <a name="NC-4"></a>[NC-4] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (11)*:
```solidity
File: src/Antimatter.sol

124:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

136:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

151:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

159:     function isApprovedMinter(address minter) external view returns (bool) {

164:     function approvedMinterCount() external view returns (uint256) {

169:     function approvedMinterAt(uint256 index) external view returns (address) {

174:     function approvedMinters() external view returns (address[] memory) {

179:     function mint(address to, uint256 amount) external onlyApprovedMinters {

201:     function annihilateFrom(address stable, address from, address recipient, uint256 amount) external nonReentrant {

246:     function toStableAmount(address stable, uint256 amount) public view returns (uint256) {

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

### <a name="NC-5"></a>[NC-5] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/Antimatter.sol

113:         if (msg.sender != owner() && !_approvedMinters.contains(msg.sender)) {

214:         if (from != msg.sender) _spendAllowance(from, msg.sender, amount);

```

### <a name="NC-6"></a>[NC-6] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (14)*:
```solidity
File: src/Antimatter.sol

125:         if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();

128:             revert PhUSDMinterMismatch(minter.phUSD(), address(newPhUSD));

137:         if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();

139:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

141:             revert PhUSDMinterMismatch(newMinter.phUSD(), address(_phUSD));

152:         if (minter == address(0)) revert ApprovedMinterZeroAddress();

202:         if (amount == 0) revert ZeroAmount();

203:         if (recipient == address(0)) revert RecipientZeroAddress();

206:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

208:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

230:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

233:         if (mintedForStable == 0) revert PhUSDNotReceived();

248:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

264:         if (to == address(0)) revert RecipientZeroAddress();

```

### <a name="NC-7"></a>[NC-7] Constants should be defined rather than using magic numbers

*Instances (1)*:
```solidity
File: src/Antimatter.sol

254:         uint256 scale = 10 ** (18 - decimals);

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 1 |
| [L-2](#L-2) | Division by zero not prevented | 1 |
| [L-3](#L-3) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
| [L-4](#L-4) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

21: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

```

### <a name="L-2"></a>[L-2] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

255:         uint256 stableAmount = amount / scale;

```

### <a name="L-3"></a>[L-3] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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
File: src/Antimatter.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-4"></a>[L-4] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

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
File: src/Antimatter.sol

21: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

119:     constructor(address initialOwner) ERC20("Antimatter", "AM") Ownable(initialOwner) {}

124:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

136:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

151:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

