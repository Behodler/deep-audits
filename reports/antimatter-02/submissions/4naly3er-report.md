# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 1 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 11 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 1 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 1 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 174 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 43 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 3 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 46 |
| [GAS-9](#GAS-9) | State variables only set in the constructor should be declared `immutable` | 1 |
| [GAS-10](#GAS-10) | Functions guaranteed to revert when called by normal users can be marked `payable` | 5 |
| [GAS-11](#GAS-11) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 1 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 1 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (1)*:
```solidity
File: test/mocks/MockYieldStrategy.sol

16:         principal[token][recipient] += amount;

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (11)*:
```solidity
File: src/Antimatter.sol

143:         if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();

145:         if (address(minter) != address(0) && minter.phUSD() != address(newPhUSD)) {

155:         if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();

157:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

170:         if (minter == address(0)) revert ApprovedMinterZeroAddress();

223:         if (recipient == address(0)) revert RecipientZeroAddress();

226:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

228:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

282:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

285:         if (yieldStrategy == address(0)) revert StablecoinNotRegistered(stable);

307:         if (to == address(0)) revert RecipientZeroAddress();

```

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (1)*:
```solidity
File: test/mocks/ReentrantStable.sol

11:     bool public armed;

```

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (1)*:
```solidity
File: test/Annihilation.t.sol

419:         for (uint256 i = 0; i < signatures.length; i++) {

```

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (174)*:
```solidity
File: test/Annihilation.t.sol

45:         minter.approveYS(address(usdc), address(strategy));

45:         minter.approveYS(address(usdc), address(strategy));

46:         minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);

47:         minter.approveYS(address(dola), address(strategy));

47:         minter.approveYS(address(dola), address(strategy));

49:         vm.startPrank(owner);

50:         antimatter.setPhUSD(IFlax(address(phUSD)));

51:         antimatter.setPhUSDMinter(minter);

71:         vm.prank(user);

72:         antimatter.annihilate(address(usdc), user, 100 ether);

72:         antimatter.annihilate(address(usdc), user, 100 ether);

74:         assertEq(antimatter.balanceOf(user), 0, "antimatter burned");

76:         assertEq(usdc.balanceOf(user), 0, "stable taken");

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

78:         assertEq(phUSD.balanceOf(user), 200 ether, "gamma radiation");

80:         assertEq(phUSD.balanceOf(address(antimatter)), 0, "nothing trapped");

87:         vm.prank(user);

88:         antimatter.annihilate(address(dola), user, 100 ether);

88:         antimatter.annihilate(address(dola), user, 100 ether);

90:         assertEq(dola.balanceOf(user), 0);

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

92:         assertEq(phUSD.balanceOf(user), 200 ether);

99:         vm.prank(user);

100:         antimatter.annihilate(address(usdc), recipient, 100 ether);

102:         assertEq(phUSD.balanceOf(recipient), 200 ether);

103:         assertEq(phUSD.balanceOf(user), 0);

110:         _fund(user, 100 ether, usdc, 100e6);

112:         vm.prank(user);

113:         antimatter.annihilate(address(usdc), user, 100 ether);

113:         antimatter.annihilate(address(usdc), user, 100 ether);

115:         assertEq(phUSD.balanceOf(user), 195 ether, "100 AM + 95 from the stable");

122:         emit Antimatter.Annihilated(address(usdc), user, recipient, 100 ether, 100e6, 200 ether);

122:         emit Antimatter.Annihilated(address(usdc), user, recipient, 100 ether, 100e6, 200 ether);

123:         vm.prank(user);

124:         antimatter.annihilate(address(usdc), recipient, 100 ether);

124:         antimatter.annihilate(address(usdc), recipient, 100 ether);

135:         vm.prank(user);

138:         vm.prank(spender);

139:         vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, spender, 0, 100 ether));

140:         antimatter.annihilate(address(usdc), recipient, 100 ether);

142:         assertEq(antimatter.balanceOf(user), 100 ether, "holder's antimatter untouched");

143:         assertEq(usdc.balanceOf(user), 100e6, "holder's stablecoin untouched");

144:         assertEq(usdc.allowance(user, address(antimatter)), type(uint256).max, "holder's approval untouched");

145:         assertEq(antimatter.allowance(user, spender), type(uint256).max, "allowance never spent");

145:         assertEq(antimatter.allowance(user, spender), type(uint256).max, "allowance never spent");

152:         _fund(recipient, 0, usdc, 500e6);

154:         vm.prank(user);

155:         antimatter.annihilate(address(usdc), recipient, 100 ether);

155:         antimatter.annihilate(address(usdc), recipient, 100 ether);

157:         assertEq(usdc.balanceOf(user), 0, "caller's stable debited");

158:         assertEq(usdc.balanceOf(recipient), 500e6, "recipient's stable untouched");

159:         assertEq(phUSD.balanceOf(recipient), 200 ether, "recipient still receives the phUSD");

168:         vm.prank(user);

170:         antimatter.annihilate(address(rogue), user, 100 ether);

176:         antimatter.annihilate(address(usdc), user, 0);

181:         vm.prank(user);

183:         antimatter.annihilate(address(usdc), address(0), 100 ether);

191:         vm.prank(user);

193:         antimatter.annihilate(address(usdc), user, 1 ether + 1);

193:         antimatter.annihilate(address(usdc), user, 1 ether + 1);

198:         vm.prank(owner);

203:         fresh.annihilate(address(usdc), user, 1 ether);

211:         fresh.annihilate(address(usdc), user, 1 ether);

220:         vm.prank(user);

222:             abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 10 ether, 100 ether)

224:         antimatter.annihilate(address(usdc), user, 100 ether);

224:         antimatter.annihilate(address(usdc), user, 100 ether);

226:         assertEq(antimatter.balanceOf(user), 10 ether);

227:         assertEq(usdc.balanceOf(user), 100e6);

233:         _fund(user, 100 ether, usdc, 10e6);

233:         _fund(user, 100 ether, usdc, 10e6);

235:         vm.prank(user);

239:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

241:         assertEq(usdc.balanceOf(user), 10e6);

251:         vm.prank(user);

253:         antimatter.annihilate(address(usdc), user, 100 ether);

253:         antimatter.annihilate(address(usdc), user, 100 ether);

255:         assertEq(antimatter.balanceOf(user), 100 ether);

256:         assertEq(usdc.balanceOf(user), 100e6);

257:         assertEq(usdc.balanceOf(address(antimatter)), 0, "no stable stranded");

266:         vm.prank(user);

268:         antimatter.annihilate(address(usdc), user, 100 ether);

268:         antimatter.annihilate(address(usdc), user, 100 ether);

270:         assertEq(antimatter.balanceOf(user), 100 ether);

278:         usdc.mint(user, 100e6);

281:         vm.prank(user);

285:         antimatter.annihilate(address(usdc), user, 100 ether);

287:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

289:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

302:             abi.encodeWithSelector(PhusdStableMinter.calculateMintAmount.selector, address(usdc), uint256(100e6)),

306:         vm.prank(user);

308:         antimatter.annihilate(address(usdc), user, 100 ether);

308:         antimatter.annihilate(address(usdc), user, 100 ether);

311:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

312:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

322:             abi.encodeWithSelector(PhusdStableMinter.calculateMintAmount.selector, address(usdc), uint256(100e6)),

326:         vm.prank(user);

328:         antimatter.annihilate(address(usdc), user, 100 ether);

328:         antimatter.annihilate(address(usdc), user, 100 ether);

334:         _fund(user, 100 ether, usdc, 100e6);

336:         vm.prank(user);

338:         antimatter.annihilate(address(usdc), user, 100 ether);

338:         antimatter.annihilate(address(usdc), user, 100 ether);

340:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

341:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

348:         minter.approveYS(address(evil), address(strategy));

352:         evil.mint(user, 100 ether);

353:         vm.prank(user);

355:         evil.arm(antimatter, user);

355:         evil.arm(antimatter, user);

357:         vm.prank(user);

359:         antimatter.annihilate(address(evil), user, 100 ether);

366:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));

390:         emit Antimatter.PhUSDMinterSet(address(minter), address(minter));

392:         antimatter.setPhUSDMinter(minter);

420:             vm.prank(user);

421:             (bool ok,) = address(antimatter).call(abi.encodeWithSignature(signatures[i], user, 1 ether));

425:         assertEq(antimatter.balanceOf(user), 100 ether, "nothing burned");

433:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));

443:         assertEq(usdc.balanceOf(recipient), 42e6);

444:         assertEq(usdc.balanceOf(address(antimatter)), 0);

469:         minter.approveYS(address(liar), address(strategy));

481:         minter.approveYS(address(liar), address(strategy));

492:         assertEq(antimatter.toStableAmount(address(usdc), 100 ether), 100e6);

501:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(usdc), uint8(6), uint256(300))

503:         antimatter.toStableAmount(address(usdc), 100 ether);

510:         vm.expectRevert(abi.encodeWithSelector(Antimatter.DecimalsUnavailable.selector, address(usdc)));

511:         antimatter.toStableAmount(address(usdc), 100 ether);

518:         vm.expectRevert(abi.encodeWithSelector(Antimatter.DecimalsUnavailable.selector, address(usdc)));

519:         antimatter.toStableAmount(address(usdc), 100 ether);

526:         vm.expectRevert(abi.encodeWithSelector(Antimatter.DecimalsUnavailable.selector, address(usdc)));

527:         antimatter.toStableAmount(address(usdc), 100 ether);

552:         minter.approveYS(address(fat), address(strategy));

564:         minter.approveYS(address(liar), address(strategy));

568:         vm.prank(user);

572:         antimatter.annihilate(address(liar), user, 100 ether);

574:         assertEq(antimatter.balanceOf(user), 100 ether, "no antimatter burned");

575:         assertEq(liar.balanceOf(user), 100 ether, "no stable moved");

577:         assertEq(phUSD.balanceOf(user), 0, "no phUSD minted");

```

```solidity
File: test/Antimatter.t.sol

31:         antimatter.mint(stranger, 100 ether);

38:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, stranger));

39:         antimatter.mint(stranger, 1 ether);

44:         antimatter.mint(owner, 10 ether);

45:         vm.prank(owner);

47:         assertEq(antimatter.balanceOf(owner), 6 ether);

48:         assertEq(antimatter.balanceOf(stranger), 4 ether);

66:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

91:         antimatter.setApprovedMinter(minter, true);

93:         assertTrue(antimatter.isApprovedMinter(minter));

95:         assertEq(antimatter.approvedMinterAt(0), minter);

98:         assertEq(all[0], minter);

108:         emit Antimatter.ApprovedMinterSet(minter, false);

109:         antimatter.setApprovedMinter(minter, false);

112:         assertFalse(antimatter.isApprovedMinter(minter));

113:         assertTrue(antimatter.isApprovedMinter(minter2));

115:         assertEq(antimatter.approvedMinterAt(0), minter2);

121:         antimatter.setApprovedMinter(minter, true);

129:         antimatter.setApprovedMinter(minter, false);

130:         antimatter.setApprovedMinter(minter, true);

133:         assertTrue(antimatter.isApprovedMinter(minter));

136:         vm.prank(minter);

138:         assertEq(antimatter.balanceOf(stranger), 1 ether);

149:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

158:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

159:         antimatter.setApprovedMinter(minter, false);

174:         vm.prank(minter);

176:         assertEq(antimatter.balanceOf(stranger), 5 ether);

181:         vm.prank(owner);

183:         assertEq(antimatter.balanceOf(stranger), 5 ether);

188:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, stranger));

189:         antimatter.mint(stranger, 1 ether);

195:         antimatter.setApprovedMinter(minter, false);

198:         vm.prank(minter);

199:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, minter));

```

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (43)*:
```solidity
File: src/Antimatter.sol

4: import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

5: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

8: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

9: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

10: import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

11: import {IFlax} from "@phUSD/IFlax.sol";

12: import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";

256:         uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;

263:         emit Annihilated(stable, msg.sender, recipient, amount, stableAmount, amount + mintedForStable);

297:         uint256 scale = 10 ** (18 - decimals);

298:         uint256 stableAmount = amount / scale;

299:         if (stableAmount * scale != amount) revert AmountNotRepresentable(amount, decimals);

```

```solidity
File: test/Annihilation.t.sol

4: import {Test} from "@forge-std/Test.sol";

5: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

9: import {FlaxToken} from "@phUSD/FlaxToken.sol";

10: import {IFlax} from "@phUSD/IFlax.sol";

11: import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";

12: import {Antimatter} from "../src/Antimatter.sol";

13: import {MockStable} from "./mocks/MockStable.sol";

14: import {MockYieldStrategy} from "./mocks/MockYieldStrategy.sol";

15: import {ReentrantStable} from "./mocks/ReentrantStable.sol";

22:     MockStable internal usdc; // 6 decimals

23:     MockStable internal dola; // 18 decimals

109:         minter.updateExchangeRate(address(usdc), 95e16); // 0.95 phUSD per USDC

115:         assertEq(phUSD.balanceOf(user), 195 ether, "100 AM + 95 from the stable");

192:         vm.expectRevert(abi.encodeWithSelector(Antimatter.AmountNotRepresentable.selector, 1 ether + 1, uint8(6)));

193:         antimatter.annihilate(address(usdc), user, 1 ether + 1);

419:         for (uint256 i = 0; i < signatures.length; i++) {

```

```solidity
File: test/Antimatter.t.sol

4: import {Test} from "@forge-std/Test.sol";

5: import {Antimatter} from "../src/Antimatter.sol";

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

7: import {IFlax} from "@phUSD/IFlax.sol";

```

```solidity
File: test/mocks/MockStable.sol

4: import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

```

```solidity
File: test/mocks/MockYieldStrategy.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

16:         principal[token][recipient] += amount;

```

```solidity
File: test/mocks/ReentrantStable.sol

4: import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

5: import {Antimatter} from "../../src/Antimatter.sol";

```

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (3)*:
```solidity
File: test/Annihilation.t.sol

252:         vm.expectRevert("phUSD: caller is not authorized to mint");

267:         vm.expectRevert("Contract is paused");

524:         vm.mockCallRevert(address(usdc), abi.encodeWithSignature("decimals()"), "no decimals");

```

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (46)*:
```solidity
File: src/Antimatter.sol

243:         uint256 stableBefore = IERC20(stable).balanceOf(address(this));

244:         uint256 phUSDBefore = _phUSD.balanceOf(address(this));

254:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

256:         uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;

```

```solidity
File: test/Annihilation.t.sol

74:         assertEq(antimatter.balanceOf(user), 0, "antimatter burned");

76:         assertEq(usdc.balanceOf(user), 0, "stable taken");

78:         assertEq(phUSD.balanceOf(user), 200 ether, "gamma radiation");

79:         assertEq(usdc.balanceOf(address(antimatter)), 0, "nothing trapped");

80:         assertEq(phUSD.balanceOf(address(antimatter)), 0, "nothing trapped");

90:         assertEq(dola.balanceOf(user), 0);

92:         assertEq(phUSD.balanceOf(user), 200 ether);

102:         assertEq(phUSD.balanceOf(recipient), 200 ether);

103:         assertEq(phUSD.balanceOf(user), 0);

115:         assertEq(phUSD.balanceOf(user), 195 ether, "100 AM + 95 from the stable");

142:         assertEq(antimatter.balanceOf(user), 100 ether, "holder's antimatter untouched");

143:         assertEq(usdc.balanceOf(user), 100e6, "holder's stablecoin untouched");

157:         assertEq(usdc.balanceOf(user), 0, "caller's stable debited");

158:         assertEq(usdc.balanceOf(recipient), 500e6, "recipient's stable untouched");

159:         assertEq(phUSD.balanceOf(recipient), 200 ether, "recipient still receives the phUSD");

226:         assertEq(antimatter.balanceOf(user), 10 ether);

227:         assertEq(usdc.balanceOf(user), 100e6);

239:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

241:         assertEq(usdc.balanceOf(user), 10e6);

255:         assertEq(antimatter.balanceOf(user), 100 ether);

256:         assertEq(usdc.balanceOf(user), 100e6);

257:         assertEq(usdc.balanceOf(address(antimatter)), 0, "no stable stranded");

270:         assertEq(antimatter.balanceOf(user), 100 ether);

271:         assertEq(usdc.balanceOf(address(antimatter)), 0, "no stable stranded");

287:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

289:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

311:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

312:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

340:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

341:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

425:         assertEq(antimatter.balanceOf(user), 100 ether, "nothing burned");

443:         assertEq(usdc.balanceOf(recipient), 42e6);

444:         assertEq(usdc.balanceOf(address(antimatter)), 0);

574:         assertEq(antimatter.balanceOf(user), 100 ether, "no antimatter burned");

575:         assertEq(liar.balanceOf(user), 100 ether, "no stable moved");

577:         assertEq(phUSD.balanceOf(user), 0, "no phUSD minted");

```

```solidity
File: test/Antimatter.t.sol

32:         assertEq(antimatter.balanceOf(stranger), 100 ether);

47:         assertEq(antimatter.balanceOf(owner), 6 ether);

48:         assertEq(antimatter.balanceOf(stranger), 4 ether);

138:         assertEq(antimatter.balanceOf(stranger), 1 ether);

176:         assertEq(antimatter.balanceOf(stranger), 5 ether);

183:         assertEq(antimatter.balanceOf(stranger), 5 ether);

```

### <a name="GAS-9"></a>[GAS-9] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (1)*:
```solidity
File: test/mocks/MockStable.sol

11:         _decimals = decimals_;

```

### <a name="GAS-10"></a>[GAS-10] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (5)*:
```solidity
File: src/Antimatter.sol

142:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

154:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

169:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

197:     function mint(address to, uint256 amount) external onlyApprovedMinters {

306:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

### <a name="GAS-11"></a>[GAS-11] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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

*Instances (1)*:
```solidity
File: test/Annihilation.t.sol

419:         for (uint256 i = 0; i < signatures.length; i++) {

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

*Instances (1)*:
```solidity
File: test/Annihilation.t.sol

419:         for (uint256 i = 0; i < signatures.length; i++) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 35 |
| [NC-2](#NC-2) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-3](#NC-3) | Array indices should be referenced via `enum`s rather than via numeric literals | 1 |
| [NC-4](#NC-4) | `constant`s should be defined rather than using magic numbers | 126 |
| [NC-5](#NC-5) | Control structures do not follow the Solidity Style Guide | 31 |
| [NC-6](#NC-6) | Consider disabling `renounceOwnership()` | 1 |
| [NC-7](#NC-7) | Draft Dependencies | 1 |
| [NC-8](#NC-8) | Events that mark critical parameter changes should contain both the old and the new value | 3 |
| [NC-9](#NC-9) | Function ordering does not follow the Solidity style guide | 3 |
| [NC-10](#NC-10) | Functions should not be longer than 50 lines | 60 |
| [NC-11](#NC-11) | Lack of checks in setters | 11 |
| [NC-12](#NC-12) | Missing Event for critical parameters change | 10 |
| [NC-13](#NC-13) | NatSpec is completely non-existent on functions that should have them | 37 |
| [NC-14](#NC-14) | Incomplete NatSpec: `@param` is missing on actually documented functions | 4 |
| [NC-15](#NC-15) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 1 |
| [NC-16](#NC-16) | Consider using named mappings | 1 |
| [NC-17](#NC-17) | Take advantage of Custom Error's return value property | 33 |
| [NC-18](#NC-18) | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| [NC-19](#NC-19) | Internal and private variables and functions names should begin with an underscore | 15 |
| [NC-20](#NC-20) | Event is missing `indexed` fields | 2 |
| [NC-21](#NC-21) | Constants should be defined rather than using magic numbers | 8 |
| [NC-22](#NC-22) | `public` functions not called by the contract should be declared `external` instead | 68 |
| [NC-23](#NC-23) | Variables need not be initialized to zero | 1 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (35)*:
```solidity
File: test/Annihilation.t.sol

139:         vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, spender, 0, 100 ether));

169:         vm.expectRevert(abi.encodeWithSelector(Antimatter.StablecoinNotRegistered.selector, address(rogue)));

192:         vm.expectRevert(abi.encodeWithSelector(Antimatter.AmountNotRepresentable.selector, 1 ether + 1, uint8(6)));

222:             abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 10 ether, 100 ether)

283:             abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(antimatter), 0, 100e6)

302:             abi.encodeWithSelector(PhusdStableMinter.calculateMintAmount.selector, address(usdc), uint256(100e6)),

307:         vm.expectRevert(abi.encodeWithSelector(Antimatter.PhUSDAmountMismatch.selector, 200 ether, 100 ether));

322:             abi.encodeWithSelector(PhusdStableMinter.calculateMintAmount.selector, address(usdc), uint256(100e6)),

327:         vm.expectRevert(abi.encodeWithSelector(Antimatter.PhUSDAmountMismatch.selector, 50 ether, 100 ether));

366:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));

383:             abi.encodeWithSelector(Antimatter.PhUSDMinterMismatch.selector, address(otherPhUSD), address(phUSD))

400:             abi.encodeWithSelector(Antimatter.PhUSDMinterMismatch.selector, address(phUSD), address(otherPhUSD))

421:             (bool ok,) = address(antimatter).call(abi.encodeWithSignature(signatures[i], user, 1 ether));

433:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));

472:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(liar), uint8(6), uint256(18))

484:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(liar), uint8(18), uint256(6))

491:         vm.mockCall(address(usdc), abi.encodeWithSignature("decimals()"), abi.encode(uint256(6)));

498:         vm.mockCall(address(usdc), abi.encodeWithSignature("decimals()"), abi.encode(uint256(300)));

501:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(usdc), uint8(6), uint256(300))

508:         vm.mockCall(address(usdc), abi.encodeWithSignature("decimals()"), bytes(""));

510:         vm.expectRevert(abi.encodeWithSelector(Antimatter.DecimalsUnavailable.selector, address(usdc)));

516:         vm.mockCall(address(usdc), abi.encodeWithSignature("decimals()"), hex"0006");

518:         vm.expectRevert(abi.encodeWithSelector(Antimatter.DecimalsUnavailable.selector, address(usdc)));

524:         vm.mockCallRevert(address(usdc), abi.encodeWithSignature("decimals()"), "no decimals");

526:         vm.expectRevert(abi.encodeWithSelector(Antimatter.DecimalsUnavailable.selector, address(usdc)));

536:         vm.expectRevert(abi.encodeWithSelector(Antimatter.DecimalsUnavailable.selector, ghost));

544:         vm.expectRevert(abi.encodeWithSelector(Antimatter.StablecoinNotRegistered.selector, address(stranger)));

554:         vm.expectRevert(abi.encodeWithSelector(Antimatter.UnsupportedDecimals.selector, uint8(24)));

570:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(liar), uint8(6), uint256(18))

```

```solidity
File: test/Antimatter.t.sol

38:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, stranger));

66:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

149:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

158:         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

188:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, stranger));

199:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, minter));

```

### <a name="NC-2"></a>[NC-2] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: test/mocks/ReentrantStable.sol

17:         attacker = attacker_;

```

### <a name="NC-3"></a>[NC-3] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (1)*:
```solidity
File: test/Antimatter.t.sol

98:         assertEq(all[0], minter);

```

### <a name="NC-4"></a>[NC-4] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (126)*:
```solidity
File: src/Antimatter.sol

286:         if (decimals > 18) revert UnsupportedDecimals(decimals);

293:         if (!ok || data.length != 32) revert DecimalsUnavailable(stable);

297:         uint256 scale = 10 ** (18 - decimals);

```

```solidity
File: test/Annihilation.t.sol

34:         usdc = new MockStable("USD Coin", "USDC", 6);

35:         dola = new MockStable("Dola", "DOLA", 18);

44:         minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);

46:         minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);

69:         _fund(user, 100 ether, usdc, 100e6);

72:         antimatter.annihilate(address(usdc), user, 100 ether);

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

78:         assertEq(phUSD.balanceOf(user), 200 ether, "gamma radiation");

85:         _fund(user, 100 ether, dola, 100 ether);

88:         antimatter.annihilate(address(dola), user, 100 ether);

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

92:         assertEq(phUSD.balanceOf(user), 200 ether);

97:         _fund(user, 100 ether, usdc, 100e6);

100:         antimatter.annihilate(address(usdc), recipient, 100 ether);

102:         assertEq(phUSD.balanceOf(recipient), 200 ether);

109:         minter.updateExchangeRate(address(usdc), 95e16); // 0.95 phUSD per USDC

110:         _fund(user, 100 ether, usdc, 100e6);

113:         antimatter.annihilate(address(usdc), user, 100 ether);

115:         assertEq(phUSD.balanceOf(user), 195 ether, "100 AM + 95 from the stable");

119:         _fund(user, 100 ether, usdc, 100e6);

122:         emit Antimatter.Annihilated(address(usdc), user, recipient, 100 ether, 100e6, 200 ether);

124:         antimatter.annihilate(address(usdc), recipient, 100 ether);

134:         _fund(user, 100 ether, usdc, 100e6);

139:         vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, spender, 0, 100 ether));

140:         antimatter.annihilate(address(usdc), recipient, 100 ether);

142:         assertEq(antimatter.balanceOf(user), 100 ether, "holder's antimatter untouched");

143:         assertEq(usdc.balanceOf(user), 100e6, "holder's stablecoin untouched");

151:         _fund(user, 100 ether, usdc, 100e6);

152:         _fund(recipient, 0, usdc, 500e6);

155:         antimatter.annihilate(address(usdc), recipient, 100 ether);

158:         assertEq(usdc.balanceOf(recipient), 500e6, "recipient's stable untouched");

159:         assertEq(phUSD.balanceOf(recipient), 200 ether, "recipient still receives the phUSD");

165:         MockStable rogue = new MockStable("Rogue", "RGE", 6);

166:         _fund(user, 100 ether, rogue, 100e6);

170:         antimatter.annihilate(address(rogue), user, 100 ether);

180:         _fund(user, 100 ether, usdc, 100e6);

183:         antimatter.annihilate(address(usdc), address(0), 100 ether);

189:         _fund(user, 100 ether, usdc, 100e6);

218:         _fund(user, 10 ether, usdc, 100e6);

222:             abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 10 ether, 100 ether)

224:         antimatter.annihilate(address(usdc), user, 100 ether);

226:         assertEq(antimatter.balanceOf(user), 10 ether);

227:         assertEq(usdc.balanceOf(user), 100e6);

233:         _fund(user, 100 ether, usdc, 10e6);

237:         antimatter.annihilate(address(usdc), user, 100 ether);

239:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

240:         assertEq(antimatter.totalSupply(), 100 ether);

241:         assertEq(usdc.balanceOf(user), 10e6);

248:         _fund(user, 100 ether, usdc, 100e6);

253:         antimatter.annihilate(address(usdc), user, 100 ether);

255:         assertEq(antimatter.balanceOf(user), 100 ether);

256:         assertEq(usdc.balanceOf(user), 100e6);

262:         _fund(user, 100 ether, usdc, 100e6);

268:         antimatter.annihilate(address(usdc), user, 100 ether);

270:         assertEq(antimatter.balanceOf(user), 100 ether);

277:         antimatter.mint(user, 100 ether);

278:         usdc.mint(user, 100e6);

283:             abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(antimatter), 0, 100e6)

285:         antimatter.annihilate(address(usdc), user, 100 ether);

287:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

288:         assertEq(antimatter.totalSupply(), 100 ether);

289:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

297:         _fund(user, 100 ether, usdc, 100e6);

307:         vm.expectRevert(abi.encodeWithSelector(Antimatter.PhUSDAmountMismatch.selector, 200 ether, 100 ether));

308:         antimatter.annihilate(address(usdc), user, 100 ether);

311:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

312:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

318:         _fund(user, 100 ether, usdc, 100e6);

327:         vm.expectRevert(abi.encodeWithSelector(Antimatter.PhUSDAmountMismatch.selector, 50 ether, 100 ether));

328:         antimatter.annihilate(address(usdc), user, 100 ether);

334:         _fund(user, 100 ether, usdc, 100e6);

338:         antimatter.annihilate(address(usdc), user, 100 ether);

340:         assertEq(antimatter.balanceOf(user), 100 ether, "burn rolled back");

341:         assertEq(usdc.balanceOf(user), 100e6, "stable untouched");

347:         minter.registerStablecoin(address(evil), address(strategy), 1e18, 18);

351:         antimatter.mint(user, 100 ether);

352:         evil.mint(user, 100 ether);

359:         antimatter.annihilate(address(evil), user, 100 ether);

411:         _fund(user, 100 ether, usdc, 100e6);

425:         assertEq(antimatter.balanceOf(user), 100 ether, "nothing burned");

426:         assertEq(antimatter.totalSupply(), 100 ether);

438:         usdc.mint(address(antimatter), 42e6);

441:         antimatter.rescueERC20(IERC20(address(usdc)), recipient, 42e6);

443:         assertEq(usdc.balanceOf(recipient), 42e6);

457:         assertEq(antimatter.toStableAmount(address(usdc), 100 ether), 100e6);

462:         assertEq(antimatter.toStableAmount(address(dola), 100 ether), 100 ether);

467:         MockStable liar = new MockStable("Liar", "LIAR", 18);

468:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 6);

474:         antimatter.toStableAmount(address(liar), 100 ether);

479:         MockStable liar = new MockStable("Liar", "LIAR", 6);

480:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 18);

486:         antimatter.toStableAmount(address(liar), 100 ether);

492:         assertEq(antimatter.toStableAmount(address(usdc), 100 ether), 100e6);

503:         antimatter.toStableAmount(address(usdc), 100 ether);

511:         antimatter.toStableAmount(address(usdc), 100 ether);

519:         antimatter.toStableAmount(address(usdc), 100 ether);

527:         antimatter.toStableAmount(address(usdc), 100 ether);

534:         minter.registerStablecoin(ghost, address(strategy), 1e18, 6);

537:         antimatter.toStableAmount(ghost, 100 ether);

542:         MockStable stranger = new MockStable("Stranger", "STR", 18);

545:         antimatter.toStableAmount(address(stranger), 100 ether);

550:         MockStable fat = new MockStable("Fat", "FAT", 24);

551:         minter.registerStablecoin(address(fat), address(strategy), 1e18, 24);

555:         antimatter.toStableAmount(address(fat), 100 ether);

562:         MockStable liar = new MockStable("Liar", "LIAR", 18);

563:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 6);

566:         _fund(user, 100 ether, liar, 100 ether);

572:         antimatter.annihilate(address(liar), user, 100 ether);

574:         assertEq(antimatter.balanceOf(user), 100 ether, "no antimatter burned");

575:         assertEq(liar.balanceOf(user), 100 ether, "no stable moved");

```

```solidity
File: test/Antimatter.t.sol

21:         assertEq(antimatter.decimals(), 18);

31:         antimatter.mint(stranger, 100 ether);

32:         assertEq(antimatter.balanceOf(stranger), 100 ether);

33:         assertEq(antimatter.totalSupply(), 100 ether);

44:         antimatter.mint(owner, 10 ether);

46:         antimatter.transfer(stranger, 4 ether);

47:         assertEq(antimatter.balanceOf(owner), 6 ether);

48:         assertEq(antimatter.balanceOf(stranger), 4 ether);

105:         assertEq(antimatter.approvedMinterCount(), 2);

175:         antimatter.mint(stranger, 5 ether);

176:         assertEq(antimatter.balanceOf(stranger), 5 ether);

182:         antimatter.mint(stranger, 5 ether);

183:         assertEq(antimatter.balanceOf(stranger), 5 ether);

```

### <a name="NC-5"></a>[NC-5] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (31)*:
```solidity
File: src/Antimatter.sol

11: import {IFlax} from "@phUSD/IFlax.sol";

119:     IFlax public phUSD;

143:         if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();

155:         if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();

156:         IFlax _phUSD = phUSD;

157:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

170:         if (minter == address(0)) revert ApprovedMinterZeroAddress();

172:         if (changed) emit ApprovedMinterSet(minter, approved);

222:         if (amount == 0) revert ZeroAmount();

223:         if (recipient == address(0)) revert RecipientZeroAddress();

225:         IFlax _phUSD = phUSD;

226:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

228:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

235:         if (expectedForStable == 0) revert PhUSDNotReceived();

254:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

257:         if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, mintedForStable);

282:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

285:         if (yieldStrategy == address(0)) revert StablecoinNotRegistered(stable);

286:         if (decimals > 18) revert UnsupportedDecimals(decimals);

293:         if (!ok || data.length != 32) revert DecimalsUnavailable(stable);

295:         if (actualDecimals != decimals) revert DecimalsMismatch(stable, decimals, actualDecimals);

299:         if (stableAmount * scale != amount) revert AmountNotRepresentable(amount, decimals);

307:         if (to == address(0)) revert RecipientZeroAddress();

```

```solidity
File: test/Annihilation.t.sol

10: import {IFlax} from "@phUSD/IFlax.sol";

50:         antimatter.setPhUSD(IFlax(address(phUSD)));

199:         fresh.setPhUSD(IFlax(address(phUSD)));

402:         antimatter.setPhUSD(IFlax(address(otherPhUSD)));

```

```solidity
File: test/Antimatter.t.sol

7: import {IFlax} from "@phUSD/IFlax.sol";

60:         antimatter.setPhUSD(IFlax(phUSD));

67:         antimatter.setPhUSD(IFlax(address(0xDECAF)));

73:         antimatter.setPhUSD(IFlax(address(0)));

```

### <a name="NC-6"></a>[NC-6] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

22: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

```

### <a name="NC-7"></a>[NC-7] Draft Dependencies
Draft contracts have not received adequate security auditing or are liable to change with future developments.

*Instances (1)*:
```solidity
File: test/Annihilation.t.sol

6: import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

```

### <a name="NC-8"></a>[NC-8] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (3)*:
```solidity
File: src/Antimatter.sol

142:     function setPhUSD(IFlax newPhUSD) external onlyOwner {
             if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();
             PhusdStableMinter minter = phUSDMinter;
             if (address(minter) != address(0) && minter.phUSD() != address(newPhUSD)) {
                 revert PhUSDMinterMismatch(minter.phUSD(), address(newPhUSD));
             }
             emit PhUSDSet(address(phUSD), address(newPhUSD));

154:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {
             if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();
             IFlax _phUSD = phUSD;
             if (address(_phUSD) == address(0)) revert PhUSDNotSet();
             if (newMinter.phUSD() != address(_phUSD)) {
                 revert PhUSDMinterMismatch(newMinter.phUSD(), address(_phUSD));
             }
             emit PhUSDMinterSet(address(phUSDMinter), address(newMinter));

169:     function setApprovedMinter(address minter, bool approved) external onlyOwner {
             if (minter == address(0)) revert ApprovedMinterZeroAddress();
             bool changed = approved ? _approvedMinters.add(minter) : _approvedMinters.remove(minter);
             if (changed) emit ApprovedMinterSet(minter, approved);

```

### <a name="NC-9"></a>[NC-9] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (3)*:
```solidity
File: src/Antimatter.sol

1: 
   Current order:
   external setPhUSD
   external setPhUSDMinter
   external setApprovedMinter
   external isApprovedMinter
   external approvedMinterCount
   external approvedMinterAt
   external approvedMinters
   external mint
   external annihilate
   public toStableAmount
   external rescueERC20
   
   Suggested order:
   external setPhUSD
   external setPhUSDMinter
   external setApprovedMinter
   external isApprovedMinter
   external approvedMinterCount
   external approvedMinterAt
   external approvedMinters
   external mint
   external annihilate
   external rescueERC20
   public toStableAmount

```

```solidity
File: test/Annihilation.t.sol

1: 
   Current order:
   public setUp
   internal _fund
   public test_annihilateSixDecimalStable
   public test_annihilateEighteenDecimalStable
   public test_annihilateToOtherRecipient
   public test_annihilateHonoursMinterExchangeRate
   public test_annihilateEmitsEvent
   public test_antimatterAllowanceGrantsNoPowerOverHolder
   public test_stableIsPulledFromCallerNotRecipient
   public test_unregisteredStableReverts
   public test_zeroAmountReverts
   public test_zeroRecipientReverts
   public test_amountFinerThanStablePrecisionReverts
   public test_annihilateRevertsWhenMinterUnset
   public test_annihilateRevertsWhenPhUSDUnset
   public test_insufficientAntimatterLeavesNothingHalfSettled
   public test_insufficientStableLeavesNothingHalfSettled
   public test_revokedPhUSDMintRightsRollsEverythingBack
   public test_pausedMinterRollsEverythingBack
   public test_annihilateWithoutStableApprovalRevertsAndBurnsNothing
   public test_shortPhUSDMintReverts
   public test_overPhUSDMintReverts
   public test_zeroExchangeRateReverts
   public test_reentrantStableIsBlocked
   public test_setPhUSDMinterOnlyOwner
   public test_setPhUSDMinterRejectsZero
   public test_setPhUSDMinterRejectsMismatchedPhUSD
   public test_setPhUSDMinterEmitsEvent
   public test_setPhUSDRejectedWhileMinterDisagrees
   public test_noPublicBurnEntryPoints
   public test_rescueERC20OnlyOwner
   public test_rescueERC20ReturnsTrappedTokens
   public test_rescueERC20RejectsZeroRecipient
   public test_toStableAmountAcceptsCorrectlyRegisteredSixDecimals
   public test_toStableAmountAcceptsCorrectlyRegisteredEighteenDecimals
   public test_toStableAmountRevertsWhenRegisteredDecimalsUnderstated
   public test_toStableAmountRevertsWhenRegisteredDecimalsOverstated
   public test_toStableAmountAcceptsUint256ReturningToken
   public test_toStableAmountRevertsOnDecimalsAboveUint8Range
   public test_toStableAmountRevertsOnEmptyDecimalsReturnData
   public test_toStableAmountRevertsOnShortDecimalsReturnData
   public test_toStableAmountRevertsWhenDecimalsCallReverts
   public test_toStableAmountRevertsOnCodelessStable
   public test_unregisteredStableStillWinsOverDecimalsCheck
   public test_unsupportedDecimalsStillWinsOverDecimalsCheck
   public test_understatedDecimalsExploitIsClosedEndToEnd
   
   Suggested order:
   public setUp
   public test_annihilateSixDecimalStable
   public test_annihilateEighteenDecimalStable
   public test_annihilateToOtherRecipient
   public test_annihilateHonoursMinterExchangeRate
   public test_annihilateEmitsEvent
   public test_antimatterAllowanceGrantsNoPowerOverHolder
   public test_stableIsPulledFromCallerNotRecipient
   public test_unregisteredStableReverts
   public test_zeroAmountReverts
   public test_zeroRecipientReverts
   public test_amountFinerThanStablePrecisionReverts
   public test_annihilateRevertsWhenMinterUnset
   public test_annihilateRevertsWhenPhUSDUnset
   public test_insufficientAntimatterLeavesNothingHalfSettled
   public test_insufficientStableLeavesNothingHalfSettled
   public test_revokedPhUSDMintRightsRollsEverythingBack
   public test_pausedMinterRollsEverythingBack
   public test_annihilateWithoutStableApprovalRevertsAndBurnsNothing
   public test_shortPhUSDMintReverts
   public test_overPhUSDMintReverts
   public test_zeroExchangeRateReverts
   public test_reentrantStableIsBlocked
   public test_setPhUSDMinterOnlyOwner
   public test_setPhUSDMinterRejectsZero
   public test_setPhUSDMinterRejectsMismatchedPhUSD
   public test_setPhUSDMinterEmitsEvent
   public test_setPhUSDRejectedWhileMinterDisagrees
   public test_noPublicBurnEntryPoints
   public test_rescueERC20OnlyOwner
   public test_rescueERC20ReturnsTrappedTokens
   public test_rescueERC20RejectsZeroRecipient
   public test_toStableAmountAcceptsCorrectlyRegisteredSixDecimals
   public test_toStableAmountAcceptsCorrectlyRegisteredEighteenDecimals
   public test_toStableAmountRevertsWhenRegisteredDecimalsUnderstated
   public test_toStableAmountRevertsWhenRegisteredDecimalsOverstated
   public test_toStableAmountAcceptsUint256ReturningToken
   public test_toStableAmountRevertsOnDecimalsAboveUint8Range
   public test_toStableAmountRevertsOnEmptyDecimalsReturnData
   public test_toStableAmountRevertsOnShortDecimalsReturnData
   public test_toStableAmountRevertsWhenDecimalsCallReverts
   public test_toStableAmountRevertsOnCodelessStable
   public test_unregisteredStableStillWinsOverDecimalsCheck
   public test_unsupportedDecimalsStillWinsOverDecimalsCheck
   public test_understatedDecimalsExploitIsClosedEndToEnd
   internal _fund

```

```solidity
File: test/mocks/MockStable.sol

1: 
   Current order:
   public decimals
   external mint
   
   Suggested order:
   external mint
   public decimals

```

### <a name="NC-10"></a>[NC-10] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (60)*:
```solidity
File: src/Antimatter.sol

142:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

154:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

169:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

177:     function isApprovedMinter(address minter) external view returns (bool) {

182:     function approvedMinterCount() external view returns (uint256) {

187:     function approvedMinterAt(uint256 index) external view returns (address) {

192:     function approvedMinters() external view returns (address[] memory) {

197:     function mint(address to, uint256 amount) external onlyApprovedMinters {

221:     function annihilate(address stable, address recipient, uint256 amount) external nonReentrant {

280:     function toStableAmount(address stable, uint256 amount) public view returns (uint256) {

306:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

```solidity
File: test/Annihilation.t.sol

57:     function _fund(address who, uint256 antimatterAmount, MockStable stable, uint256 stableAmount) internal {

68:     function test_annihilateSixDecimalStable() public {

84:     function test_annihilateEighteenDecimalStable() public {

96:     function test_annihilateToOtherRecipient() public {

108:     function test_annihilateHonoursMinterExchangeRate() public {

133:     function test_antimatterAllowanceGrantsNoPowerOverHolder() public {

150:     function test_stableIsPulledFromCallerNotRecipient() public {

164:     function test_unregisteredStableReverts() public {

188:     function test_amountFinerThanStablePrecisionReverts() public {

196:     function test_annihilateRevertsWhenMinterUnset() public {

206:     function test_annihilateRevertsWhenPhUSDUnset() public {

217:     function test_insufficientAntimatterLeavesNothingHalfSettled() public {

232:     function test_insufficientStableLeavesNothingHalfSettled() public {

247:     function test_revokedPhUSDMintRightsRollsEverythingBack() public {

261:     function test_pausedMinterRollsEverythingBack() public {

275:     function test_annihilateWithoutStableApprovalRevertsAndBurnsNothing() public {

370:     function test_setPhUSDMinterRejectsZero() public {

377:     function test_setPhUSDMinterRejectsMismatchedPhUSD() public {

396:     function test_setPhUSDRejectedWhileMinterDisagrees() public {

437:     function test_rescueERC20ReturnsTrappedTokens() public {

447:     function test_rescueERC20RejectsZeroRecipient() public {

456:     function test_toStableAmountAcceptsCorrectlyRegisteredSixDecimals() public view {

461:     function test_toStableAmountAcceptsCorrectlyRegisteredEighteenDecimals() public view {

466:     function test_toStableAmountRevertsWhenRegisteredDecimalsUnderstated() public {

478:     function test_toStableAmountRevertsWhenRegisteredDecimalsOverstated() public {

490:     function test_toStableAmountAcceptsUint256ReturningToken() public {

497:     function test_toStableAmountRevertsOnDecimalsAboveUint8Range() public {

507:     function test_toStableAmountRevertsOnEmptyDecimalsReturnData() public {

515:     function test_toStableAmountRevertsOnShortDecimalsReturnData() public {

523:     function test_toStableAmountRevertsWhenDecimalsCallReverts() public {

531:     function test_toStableAmountRevertsOnCodelessStable() public {

541:     function test_unregisteredStableStillWinsOverDecimalsCheck() public {

549:     function test_unsupportedDecimalsStillWinsOverDecimalsCheck() public {

561:     function test_understatedDecimalsExploitIsClosedEndToEnd() public {

```

```solidity
File: test/Antimatter.t.sol

51:     function test_phUSDDefaultsToZeroAddress() public view {

70:     function test_cannotSetPhUSDToZeroAddress() public {

81:     function test_approvedMintersStartsEmpty() public view {

118:     function test_setApprovedMinterIsIdempotent() public {

126:     function test_canReapproveAfterUnapproving() public {

141:     function test_unapprovingUnknownMinterIsNoop() public {

147:     function test_strangerCannotApproveMinter() public {

153:     function test_strangerCannotUnapproveMinter() public {

179:     function test_ownerCanStillMintWithoutBeingInTheSet() public {

```

```solidity
File: test/mocks/MockStable.sol

14:     function decimals() public view override returns (uint8) {

18:     function mint(address to, uint256 amount) external {

```

```solidity
File: test/mocks/MockYieldStrategy.sol

14:     function deposit(address token, uint256 amount, address recipient) external {

```

```solidity
File: test/mocks/ReentrantStable.sol

15:     function arm(Antimatter antimatter_, address attacker_) external {

21:     function mint(address to, uint256 amount) external {

25:     function _update(address from, address to, uint256 value) internal override {

```

### <a name="NC-11"></a>[NC-11] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (11)*:
```solidity
File: test/Annihilation.t.sol

30:     function setUp() public {
            phUSD = new FlaxToken();
            minter = new PhusdStableMinter(address(phUSD));
            strategy = new MockYieldStrategy();
            usdc = new MockStable("USD Coin", "USDC", 6);
            dola = new MockStable("Dola", "DOLA", 18);
    
            antimatter = new Antimatter(owner);
    
            // phUSD authorises both the stable minter and antimatter to mint.
            phUSD.setMinter(address(minter), true);
            phUSD.setMinter(address(antimatter), true);
    
            // Register the stables 1:1 against the mock strategy and let the minter pull them.
            minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);
            minter.approveYS(address(usdc), address(strategy));
            minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);
            minter.approveYS(address(dola), address(strategy));
    
            vm.startPrank(owner);
            antimatter.setPhUSD(IFlax(address(phUSD)));
            antimatter.setPhUSDMinter(minter);
            vm.stopPrank();

196:     function test_annihilateRevertsWhenMinterUnset() public {
             Antimatter fresh = new Antimatter(owner);
             vm.prank(owner);
             fresh.setPhUSD(IFlax(address(phUSD)));
     
             vm.prank(user);
             vm.expectRevert(Antimatter.PhUSDMinterNotSet.selector);
             fresh.annihilate(address(usdc), user, 1 ether);

206:     function test_annihilateRevertsWhenPhUSDUnset() public {
             Antimatter fresh = new Antimatter(owner);
     
             vm.prank(user);
             vm.expectRevert(Antimatter.PhUSDNotSet.selector);
             fresh.annihilate(address(usdc), user, 1 ether);

364:     function test_setPhUSDMinterOnlyOwner() public {
             vm.prank(user);
             vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
             antimatter.setPhUSDMinter(minter);

370:     function test_setPhUSDMinterRejectsZero() public {
             vm.prank(owner);
             vm.expectRevert(Antimatter.PhUSDMinterZeroAddress.selector);
             antimatter.setPhUSDMinter(PhusdStableMinter(address(0)));

377:     function test_setPhUSDMinterRejectsMismatchedPhUSD() public {
             FlaxToken otherPhUSD = new FlaxToken();
             PhusdStableMinter otherMinter = new PhusdStableMinter(address(otherPhUSD));
     
             vm.prank(owner);
             vm.expectRevert(
                 abi.encodeWithSelector(Antimatter.PhUSDMinterMismatch.selector, address(otherPhUSD), address(phUSD))
             );
             antimatter.setPhUSDMinter(otherMinter);

388:     function test_setPhUSDMinterEmitsEvent() public {
             vm.expectEmit(true, true, false, false, address(antimatter));
             emit Antimatter.PhUSDMinterSet(address(minter), address(minter));
             vm.prank(owner);
             antimatter.setPhUSDMinter(minter);

396:     function test_setPhUSDRejectedWhileMinterDisagrees() public {
             FlaxToken otherPhUSD = new FlaxToken();
             vm.prank(owner);
             vm.expectRevert(
                 abi.encodeWithSelector(Antimatter.PhUSDMinterMismatch.selector, address(phUSD), address(otherPhUSD))
             );
             antimatter.setPhUSD(IFlax(address(otherPhUSD)));

```

```solidity
File: test/Antimatter.t.sol

14:     function setUp() public {
            antimatter = new Antimatter(owner);

118:     function test_setApprovedMinterIsIdempotent() public {
             vm.startPrank(owner);
             antimatter.setApprovedMinter(minter, true);
             antimatter.setApprovedMinter(minter, true);
             vm.stopPrank();
             assertEq(antimatter.approvedMinterCount(), 1);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

19:     function setClient(address, bool) external {}

```

### <a name="NC-12"></a>[NC-12] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (10)*:
```solidity
File: test/Annihilation.t.sol

30:     function setUp() public {
            phUSD = new FlaxToken();
            minter = new PhusdStableMinter(address(phUSD));
            strategy = new MockYieldStrategy();
            usdc = new MockStable("USD Coin", "USDC", 6);
            dola = new MockStable("Dola", "DOLA", 18);
    
            antimatter = new Antimatter(owner);
    
            // phUSD authorises both the stable minter and antimatter to mint.
            phUSD.setMinter(address(minter), true);
            phUSD.setMinter(address(antimatter), true);
    
            // Register the stables 1:1 against the mock strategy and let the minter pull them.
            minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);
            minter.approveYS(address(usdc), address(strategy));
            minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);
            minter.approveYS(address(dola), address(strategy));
    
            vm.startPrank(owner);
            antimatter.setPhUSD(IFlax(address(phUSD)));
            antimatter.setPhUSDMinter(minter);
            vm.stopPrank();

196:     function test_annihilateRevertsWhenMinterUnset() public {
             Antimatter fresh = new Antimatter(owner);
             vm.prank(owner);
             fresh.setPhUSD(IFlax(address(phUSD)));
     
             vm.prank(user);
             vm.expectRevert(Antimatter.PhUSDMinterNotSet.selector);
             fresh.annihilate(address(usdc), user, 1 ether);

206:     function test_annihilateRevertsWhenPhUSDUnset() public {
             Antimatter fresh = new Antimatter(owner);
     
             vm.prank(user);
             vm.expectRevert(Antimatter.PhUSDNotSet.selector);
             fresh.annihilate(address(usdc), user, 1 ether);

364:     function test_setPhUSDMinterOnlyOwner() public {
             vm.prank(user);
             vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
             antimatter.setPhUSDMinter(minter);

370:     function test_setPhUSDMinterRejectsZero() public {
             vm.prank(owner);
             vm.expectRevert(Antimatter.PhUSDMinterZeroAddress.selector);
             antimatter.setPhUSDMinter(PhusdStableMinter(address(0)));

377:     function test_setPhUSDMinterRejectsMismatchedPhUSD() public {
             FlaxToken otherPhUSD = new FlaxToken();
             PhusdStableMinter otherMinter = new PhusdStableMinter(address(otherPhUSD));
     
             vm.prank(owner);
             vm.expectRevert(
                 abi.encodeWithSelector(Antimatter.PhUSDMinterMismatch.selector, address(otherPhUSD), address(phUSD))
             );
             antimatter.setPhUSDMinter(otherMinter);

396:     function test_setPhUSDRejectedWhileMinterDisagrees() public {
             FlaxToken otherPhUSD = new FlaxToken();
             vm.prank(owner);
             vm.expectRevert(
                 abi.encodeWithSelector(Antimatter.PhUSDMinterMismatch.selector, address(phUSD), address(otherPhUSD))
             );
             antimatter.setPhUSD(IFlax(address(otherPhUSD)));

```

```solidity
File: test/Antimatter.t.sol

14:     function setUp() public {
            antimatter = new Antimatter(owner);

118:     function test_setApprovedMinterIsIdempotent() public {
             vm.startPrank(owner);
             antimatter.setApprovedMinter(minter, true);
             antimatter.setApprovedMinter(minter, true);
             vm.stopPrank();
             assertEq(antimatter.approvedMinterCount(), 1);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

19:     function setClient(address, bool) external {}

```

### <a name="NC-13"></a>[NC-13] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (37)*:
```solidity
File: test/Annihilation.t.sol

30:     function setUp() public {

118:     function test_annihilateEmitsEvent() public {

164:     function test_unregisteredStableReverts() public {

173:     function test_zeroAmountReverts() public {

179:     function test_zeroRecipientReverts() public {

196:     function test_annihilateRevertsWhenMinterUnset() public {

206:     function test_annihilateRevertsWhenPhUSDUnset() public {

364:     function test_setPhUSDMinterOnlyOwner() public {

370:     function test_setPhUSDMinterRejectsZero() public {

388:     function test_setPhUSDMinterEmitsEvent() public {

431:     function test_rescueERC20OnlyOwner() public {

437:     function test_rescueERC20ReturnsTrappedTokens() public {

447:     function test_rescueERC20RejectsZeroRecipient() public {

```

```solidity
File: test/Antimatter.t.sol

14:     function setUp() public {

29:     function test_ownerCanMint() public {

36:     function test_strangerCannotMint() public {

42:     function test_transfer() public {

55:     function test_ownerCanSetPhUSD() public {

64:     function test_strangerCannotSetPhUSD() public {

70:     function test_cannotSetPhUSDToZeroAddress() public {

87:     function test_ownerCanApproveMinter() public {

101:     function test_ownerCanUnapproveMinter() public {

118:     function test_setApprovedMinterIsIdempotent() public {

126:     function test_canReapproveAfterUnapproving() public {

141:     function test_unapprovingUnknownMinterIsNoop() public {

147:     function test_strangerCannotApproveMinter() public {

153:     function test_strangerCannotUnapproveMinter() public {

162:     function test_cannotApproveZeroAddress() public {

170:     function test_approvedMinterCanMint() public {

179:     function test_ownerCanStillMintWithoutBeingInTheSet() public {

186:     function test_unapprovedCannotMint() public {

192:     function test_removedMinterCannotMint() public {

```

```solidity
File: test/mocks/MockStable.sol

18:     function mint(address to, uint256 amount) external {

```

```solidity
File: test/mocks/MockYieldStrategy.sol

14:     function deposit(address token, uint256 amount, address recipient) external {

19:     function setClient(address, bool) external {}

```

```solidity
File: test/mocks/ReentrantStable.sol

15:     function arm(Antimatter antimatter_, address attacker_) external {

21:     function mint(address to, uint256 amount) external {

```

### <a name="NC-14"></a>[NC-14] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (4)*:
```solidity
File: src/Antimatter.sol

139:     /// @notice Set the phUSD token address. Restricted to the owner.
         /// @dev Refuses any address the already-configured stable minter does not mint, so the two
         ///      can never drift apart.
         function setPhUSD(IFlax newPhUSD) external onlyOwner {

152:     /// @notice Set the phUSD stable minter. Restricted to the owner.
         /// @dev Requires {phUSD} to be set first, and requires the minter to mint that same phUSD.
         function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

196:     /// @notice Mint new tokens. Restricted to the owner and approved minters.
         function mint(address to, uint256 amount) external onlyApprovedMinters {

303:     /// @notice Send `amount` of `token` held by this contract to `to`. Restricted to the owner.
         /// @dev A backstop only. {annihilate} settles whole or not at all, so nothing should ever
         ///      accumulate here; this exists so that an unforeseen bug cannot strand funds forever.
         function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

### <a name="NC-15"></a>[NC-15] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

131:         if (msg.sender != owner() && !_approvedMinters.contains(msg.sender)) {

```

### <a name="NC-16"></a>[NC-16] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (1)*:
```solidity
File: test/mocks/MockYieldStrategy.sol

12:     mapping(address => mapping(address => uint256)) public principal;

```

### <a name="NC-17"></a>[NC-17] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (33)*:
```solidity
File: src/Antimatter.sol

143:         if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();

146:             revert PhUSDMinterMismatch(minter.phUSD(), address(newPhUSD));

155:         if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();

157:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

159:             revert PhUSDMinterMismatch(newMinter.phUSD(), address(_phUSD));

170:         if (minter == address(0)) revert ApprovedMinterZeroAddress();

222:         if (amount == 0) revert ZeroAmount();

223:         if (recipient == address(0)) revert RecipientZeroAddress();

226:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

228:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

235:         if (expectedForStable == 0) revert PhUSDNotReceived();

254:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

282:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

307:         if (to == address(0)) revert RecipientZeroAddress();

```

```solidity
File: test/Annihilation.t.sol

164:     function test_unregisteredStableReverts() public {

173:     function test_zeroAmountReverts() public {

179:     function test_zeroRecipientReverts() public {

188:     function test_amountFinerThanStablePrecisionReverts() public {

196:     function test_annihilateRevertsWhenMinterUnset() public {

206:     function test_annihilateRevertsWhenPhUSDUnset() public {

236:         vm.expectRevert();

275:     function test_annihilateWithoutStableApprovalRevertsAndBurnsNothing() public {

296:     function test_shortPhUSDMintReverts() public {

317:     function test_overPhUSDMintReverts() public {

332:     function test_zeroExchangeRateReverts() public {

466:     function test_toStableAmountRevertsWhenRegisteredDecimalsUnderstated() public {

478:     function test_toStableAmountRevertsWhenRegisteredDecimalsOverstated() public {

497:     function test_toStableAmountRevertsOnDecimalsAboveUint8Range() public {

507:     function test_toStableAmountRevertsOnEmptyDecimalsReturnData() public {

515:     function test_toStableAmountRevertsOnShortDecimalsReturnData() public {

523:     function test_toStableAmountRevertsWhenDecimalsCallReverts() public {

524:         vm.mockCallRevert(address(usdc), abi.encodeWithSignature("decimals()"), "no decimals");

531:     function test_toStableAmountRevertsOnCodelessStable() public {

```

### <a name="NC-18"></a>[NC-18] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (2)*:
```solidity
File: src/Antimatter.sol

1: 
   Current order:
   UsingForDirective.EnumerableSet.AddressSet
   UsingForDirective.IERC20
   ErrorDefinition.PhUSDZeroAddress
   ErrorDefinition.ApprovedMinterZeroAddress
   ErrorDefinition.NotApprovedMinter
   ErrorDefinition.PhUSDMinterZeroAddress
   ErrorDefinition.PhUSDMinterMismatch
   ErrorDefinition.PhUSDNotSet
   ErrorDefinition.PhUSDMinterNotSet
   ErrorDefinition.ZeroAmount
   ErrorDefinition.RecipientZeroAddress
   ErrorDefinition.StablecoinNotRegistered
   ErrorDefinition.UnsupportedDecimals
   ErrorDefinition.DecimalsMismatch
   ErrorDefinition.DecimalsUnavailable
   ErrorDefinition.AmountNotRepresentable
   ErrorDefinition.StableNotDeposited
   ErrorDefinition.PhUSDNotReceived
   ErrorDefinition.PhUSDAmountMismatch
   EventDefinition.PhUSDSet
   EventDefinition.ApprovedMinterSet
   EventDefinition.PhUSDMinterSet
   EventDefinition.Annihilated
   EventDefinition.ERC20Rescued
   VariableDeclaration.phUSD
   VariableDeclaration.phUSDMinter
   VariableDeclaration._approvedMinters
   ModifierDefinition.onlyApprovedMinters
   FunctionDefinition.constructor
   FunctionDefinition.setPhUSD
   FunctionDefinition.setPhUSDMinter
   FunctionDefinition.setApprovedMinter
   FunctionDefinition.isApprovedMinter
   FunctionDefinition.approvedMinterCount
   FunctionDefinition.approvedMinterAt
   FunctionDefinition.approvedMinters
   FunctionDefinition.mint
   FunctionDefinition.annihilate
   FunctionDefinition.toStableAmount
   FunctionDefinition.rescueERC20
   
   Suggested order:
   UsingForDirective.EnumerableSet.AddressSet
   UsingForDirective.IERC20
   VariableDeclaration.phUSD
   VariableDeclaration.phUSDMinter
   VariableDeclaration._approvedMinters
   ErrorDefinition.PhUSDZeroAddress
   ErrorDefinition.ApprovedMinterZeroAddress
   ErrorDefinition.NotApprovedMinter
   ErrorDefinition.PhUSDMinterZeroAddress
   ErrorDefinition.PhUSDMinterMismatch
   ErrorDefinition.PhUSDNotSet
   ErrorDefinition.PhUSDMinterNotSet
   ErrorDefinition.ZeroAmount
   ErrorDefinition.RecipientZeroAddress
   ErrorDefinition.StablecoinNotRegistered
   ErrorDefinition.UnsupportedDecimals
   ErrorDefinition.DecimalsMismatch
   ErrorDefinition.DecimalsUnavailable
   ErrorDefinition.AmountNotRepresentable
   ErrorDefinition.StableNotDeposited
   ErrorDefinition.PhUSDNotReceived
   ErrorDefinition.PhUSDAmountMismatch
   EventDefinition.PhUSDSet
   EventDefinition.ApprovedMinterSet
   EventDefinition.PhUSDMinterSet
   EventDefinition.Annihilated
   EventDefinition.ERC20Rescued
   ModifierDefinition.onlyApprovedMinters
   FunctionDefinition.constructor
   FunctionDefinition.setPhUSD
   FunctionDefinition.setPhUSDMinter
   FunctionDefinition.setApprovedMinter
   FunctionDefinition.isApprovedMinter
   FunctionDefinition.approvedMinterCount
   FunctionDefinition.approvedMinterAt
   FunctionDefinition.approvedMinters
   FunctionDefinition.mint
   FunctionDefinition.annihilate
   FunctionDefinition.toStableAmount
   FunctionDefinition.rescueERC20

```

```solidity
File: test/Antimatter.t.sol

1: 
   Current order:
   VariableDeclaration.antimatter
   VariableDeclaration.owner
   VariableDeclaration.stranger
   FunctionDefinition.setUp
   FunctionDefinition.test_metadata
   FunctionDefinition.test_ownerIsInitialOwner
   FunctionDefinition.test_ownerCanMint
   FunctionDefinition.test_strangerCannotMint
   FunctionDefinition.test_transfer
   FunctionDefinition.test_phUSDDefaultsToZeroAddress
   FunctionDefinition.test_ownerCanSetPhUSD
   FunctionDefinition.test_strangerCannotSetPhUSD
   FunctionDefinition.test_cannotSetPhUSDToZeroAddress
   VariableDeclaration.minter
   VariableDeclaration.minter2
   FunctionDefinition.test_approvedMintersStartsEmpty
   FunctionDefinition.test_ownerCanApproveMinter
   FunctionDefinition.test_ownerCanUnapproveMinter
   FunctionDefinition.test_setApprovedMinterIsIdempotent
   FunctionDefinition.test_canReapproveAfterUnapproving
   FunctionDefinition.test_unapprovingUnknownMinterIsNoop
   FunctionDefinition.test_strangerCannotApproveMinter
   FunctionDefinition.test_strangerCannotUnapproveMinter
   FunctionDefinition.test_cannotApproveZeroAddress
   FunctionDefinition.test_approvedMinterCanMint
   FunctionDefinition.test_ownerCanStillMintWithoutBeingInTheSet
   FunctionDefinition.test_unapprovedCannotMint
   FunctionDefinition.test_removedMinterCannotMint
   
   Suggested order:
   VariableDeclaration.antimatter
   VariableDeclaration.owner
   VariableDeclaration.stranger
   VariableDeclaration.minter
   VariableDeclaration.minter2
   FunctionDefinition.setUp
   FunctionDefinition.test_metadata
   FunctionDefinition.test_ownerIsInitialOwner
   FunctionDefinition.test_ownerCanMint
   FunctionDefinition.test_strangerCannotMint
   FunctionDefinition.test_transfer
   FunctionDefinition.test_phUSDDefaultsToZeroAddress
   FunctionDefinition.test_ownerCanSetPhUSD
   FunctionDefinition.test_strangerCannotSetPhUSD
   FunctionDefinition.test_cannotSetPhUSDToZeroAddress
   FunctionDefinition.test_approvedMintersStartsEmpty
   FunctionDefinition.test_ownerCanApproveMinter
   FunctionDefinition.test_ownerCanUnapproveMinter
   FunctionDefinition.test_setApprovedMinterIsIdempotent
   FunctionDefinition.test_canReapproveAfterUnapproving
   FunctionDefinition.test_unapprovingUnknownMinterIsNoop
   FunctionDefinition.test_strangerCannotApproveMinter
   FunctionDefinition.test_strangerCannotUnapproveMinter
   FunctionDefinition.test_cannotApproveZeroAddress
   FunctionDefinition.test_approvedMinterCanMint
   FunctionDefinition.test_ownerCanStillMintWithoutBeingInTheSet
   FunctionDefinition.test_unapprovedCannotMint
   FunctionDefinition.test_removedMinterCannotMint

```

### <a name="NC-19"></a>[NC-19] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (15)*:
```solidity
File: test/Annihilation.t.sol

18:     Antimatter internal antimatter;

19:     FlaxToken internal phUSD;

20:     PhusdStableMinter internal minter;

21:     MockYieldStrategy internal strategy;

22:     MockStable internal usdc; // 6 decimals

23:     MockStable internal dola; // 18 decimals

25:     address internal owner = address(0xA11CE);

26:     address internal user = address(0xB0B);

27:     address internal spender = address(0xC0FFEE);

28:     address internal recipient = address(0xD00D);

```

```solidity
File: test/Antimatter.t.sol

10:     Antimatter internal antimatter;

11:     address internal owner = address(0xA11CE);

12:     address internal stranger = address(0xB0B);

78:     address internal minter = address(0x111);

79:     address internal minter2 = address(0x222);

```

### <a name="NC-20"></a>[NC-20] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (2)*:
```solidity
File: src/Antimatter.sol

94:     event ApprovedMinterSet(address indexed minter, bool approved);

116:     event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

```

### <a name="NC-21"></a>[NC-21] Constants should be defined rather than using magic numbers

*Instances (8)*:
```solidity
File: src/Antimatter.sol

297:         uint256 scale = 10 ** (18 - decimals);

```

```solidity
File: test/Annihilation.t.sol

303:             abi.encode(uint256(200 ether))

323:             abi.encode(uint256(50 ether))

472:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(liar), uint8(6), uint256(18))

498:         vm.mockCall(address(usdc), abi.encodeWithSignature("decimals()"), abi.encode(uint256(300)));

501:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(usdc), uint8(6), uint256(300))

554:         vm.expectRevert(abi.encodeWithSelector(Antimatter.UnsupportedDecimals.selector, uint8(24)));

570:             abi.encodeWithSelector(Antimatter.DecimalsMismatch.selector, address(liar), uint8(6), uint256(18))

```

### <a name="NC-22"></a>[NC-22] `public` functions not called by the contract should be declared `external` instead

*Instances (68)*:
```solidity
File: test/Annihilation.t.sol

30:     function setUp() public {

68:     function test_annihilateSixDecimalStable() public {

84:     function test_annihilateEighteenDecimalStable() public {

96:     function test_annihilateToOtherRecipient() public {

108:     function test_annihilateHonoursMinterExchangeRate() public {

118:     function test_annihilateEmitsEvent() public {

133:     function test_antimatterAllowanceGrantsNoPowerOverHolder() public {

150:     function test_stableIsPulledFromCallerNotRecipient() public {

164:     function test_unregisteredStableReverts() public {

173:     function test_zeroAmountReverts() public {

179:     function test_zeroRecipientReverts() public {

188:     function test_amountFinerThanStablePrecisionReverts() public {

196:     function test_annihilateRevertsWhenMinterUnset() public {

206:     function test_annihilateRevertsWhenPhUSDUnset() public {

217:     function test_insufficientAntimatterLeavesNothingHalfSettled() public {

232:     function test_insufficientStableLeavesNothingHalfSettled() public {

247:     function test_revokedPhUSDMintRightsRollsEverythingBack() public {

261:     function test_pausedMinterRollsEverythingBack() public {

275:     function test_annihilateWithoutStableApprovalRevertsAndBurnsNothing() public {

296:     function test_shortPhUSDMintReverts() public {

317:     function test_overPhUSDMintReverts() public {

332:     function test_zeroExchangeRateReverts() public {

345:     function test_reentrantStableIsBlocked() public {

364:     function test_setPhUSDMinterOnlyOwner() public {

370:     function test_setPhUSDMinterRejectsZero() public {

377:     function test_setPhUSDMinterRejectsMismatchedPhUSD() public {

388:     function test_setPhUSDMinterEmitsEvent() public {

396:     function test_setPhUSDRejectedWhileMinterDisagrees() public {

410:     function test_noPublicBurnEntryPoints() public {

431:     function test_rescueERC20OnlyOwner() public {

437:     function test_rescueERC20ReturnsTrappedTokens() public {

447:     function test_rescueERC20RejectsZeroRecipient() public {

456:     function test_toStableAmountAcceptsCorrectlyRegisteredSixDecimals() public view {

461:     function test_toStableAmountAcceptsCorrectlyRegisteredEighteenDecimals() public view {

466:     function test_toStableAmountRevertsWhenRegisteredDecimalsUnderstated() public {

478:     function test_toStableAmountRevertsWhenRegisteredDecimalsOverstated() public {

490:     function test_toStableAmountAcceptsUint256ReturningToken() public {

497:     function test_toStableAmountRevertsOnDecimalsAboveUint8Range() public {

507:     function test_toStableAmountRevertsOnEmptyDecimalsReturnData() public {

515:     function test_toStableAmountRevertsOnShortDecimalsReturnData() public {

523:     function test_toStableAmountRevertsWhenDecimalsCallReverts() public {

531:     function test_toStableAmountRevertsOnCodelessStable() public {

541:     function test_unregisteredStableStillWinsOverDecimalsCheck() public {

549:     function test_unsupportedDecimalsStillWinsOverDecimalsCheck() public {

561:     function test_understatedDecimalsExploitIsClosedEndToEnd() public {

```

```solidity
File: test/Antimatter.t.sol

14:     function setUp() public {

18:     function test_metadata() public view {

25:     function test_ownerIsInitialOwner() public view {

29:     function test_ownerCanMint() public {

36:     function test_strangerCannotMint() public {

42:     function test_transfer() public {

51:     function test_phUSDDefaultsToZeroAddress() public view {

55:     function test_ownerCanSetPhUSD() public {

64:     function test_strangerCannotSetPhUSD() public {

70:     function test_cannotSetPhUSDToZeroAddress() public {

81:     function test_approvedMintersStartsEmpty() public view {

87:     function test_ownerCanApproveMinter() public {

101:     function test_ownerCanUnapproveMinter() public {

118:     function test_setApprovedMinterIsIdempotent() public {

126:     function test_canReapproveAfterUnapproving() public {

141:     function test_unapprovingUnknownMinterIsNoop() public {

147:     function test_strangerCannotApproveMinter() public {

153:     function test_strangerCannotUnapproveMinter() public {

162:     function test_cannotApproveZeroAddress() public {

170:     function test_approvedMinterCanMint() public {

179:     function test_ownerCanStillMintWithoutBeingInTheSet() public {

186:     function test_unapprovedCannotMint() public {

192:     function test_removedMinterCannotMint() public {

```

### <a name="NC-23"></a>[NC-23] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (1)*:
```solidity
File: test/Annihilation.t.sol

419:         for (uint256 i = 0; i < signatures.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 3 |
| [L-2](#L-2) | Use a 2-step ownership transfer pattern | 1 |
| [L-3](#L-3) | Some tokens may revert when zero value transfers are made | 4 |
| [L-4](#L-4) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-5](#L-5) | `decimals()` is not a part of the ERC-20 standard | 1 |
| [L-6](#L-6) | Deprecated approve() function | 3 |
| [L-7](#L-7) | Division by zero not prevented | 1 |
| [L-8](#L-8) | Empty Function Body - Consider commenting why | 1 |
| [L-9](#L-9) | External call recipient may consume all transaction gas | 1 |
| [L-10](#L-10) | Prevent accidentally burning tokens | 96 |
| [L-11](#L-11) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 6 |
| [L-12](#L-12) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 3 |
| [L-13](#L-13) | Sweeping may break accounting if tokens with multiple addresses are used | 7 |
| [L-14](#L-14) | `symbol()` is not a part of the ERC-20 standard | 1 |
| [L-15](#L-15) | Unsafe ERC20 operation(s) | 4 |
### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (3)*:
```solidity
File: test/Annihilation.t.sol

62:         stable.approve(address(antimatter), type(uint256).max);

136:         antimatter.approve(spender, type(uint256).max);

354:         evil.approve(address(antimatter), type(uint256).max);

```

### <a name="L-2"></a>[L-2] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

22: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

```

### <a name="L-3"></a>[L-3] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (4)*:
```solidity
File: src/Antimatter.sol

246:         IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);

261:         IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);

308:         token.safeTransfer(to, amount);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

15:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

```

### <a name="L-4"></a>[L-4] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: test/mocks/ReentrantStable.sol

17:         attacker = attacker_;

```

### <a name="L-5"></a>[L-5] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (1)*:
```solidity
File: test/Antimatter.t.sol

21:         assertEq(antimatter.decimals(), 18);

```

### <a name="L-6"></a>[L-6] Deprecated approve() function
Due to the inheritance of ERC20's approve function, there's a vulnerability to the ERC20 approve and double spend front running attack. Briefly, an authorized spender could spend both allowances by front running an allowance-changing transaction. Consider implementing OpenZeppelin's `.safeApprove()` function to help mitigate this.

*Instances (3)*:
```solidity
File: test/Annihilation.t.sol

62:         stable.approve(address(antimatter), type(uint256).max);

136:         antimatter.approve(spender, type(uint256).max);

354:         evil.approve(address(antimatter), type(uint256).max);

```

### <a name="L-7"></a>[L-7] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

298:         uint256 stableAmount = amount / scale;

```

### <a name="L-8"></a>[L-8] Empty Function Body - Consider commenting why

*Instances (1)*:
```solidity
File: test/mocks/MockYieldStrategy.sol

19:     function setClient(address, bool) external {}

```

### <a name="L-9"></a>[L-9] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (1)*:
```solidity
File: test/Annihilation.t.sol

421:             (bool ok,) = address(antimatter).call(abi.encodeWithSignature(signatures[i], user, 1 ether));

```

### <a name="L-10"></a>[L-10] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (96)*:
```solidity
File: src/Antimatter.sol

145:         if (address(minter) != address(0) && minter.phUSD() != address(newPhUSD)) {

146:             revert PhUSDMinterMismatch(minter.phUSD(), address(newPhUSD));

171:         bool changed = approved ? _approvedMinters.add(minter) : _approvedMinters.remove(minter);

172:         if (changed) emit ApprovedMinterSet(minter, approved);

178:         return _approvedMinters.contains(minter);

198:         _mint(to, amount);

228:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

234:         uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);

239:         _burn(msg.sender, amount);

247:         IERC20(stable).forceApprove(address(minter), stableAmount);

247:         IERC20(stable).forceApprove(address(minter), stableAmount);

251:         minter.mint(stable, stableAmount);

253:         IERC20(stable).forceApprove(address(minter), 0);

253:         IERC20(stable).forceApprove(address(minter), 0);

257:         if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, mintedForStable);

261:         IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);

263:         emit Annihilated(stable, msg.sender, recipient, amount, stableAmount, amount + mintedForStable);

282:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

284:         (address yieldStrategy,, uint8 decimals,,,,) = minter.stablecoinConfigs(stable);

```

```solidity
File: test/Annihilation.t.sol

40:         phUSD.setMinter(address(minter), true);

40:         phUSD.setMinter(address(minter), true);

44:         minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);

45:         minter.approveYS(address(usdc), address(strategy));

46:         minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);

47:         minter.approveYS(address(dola), address(strategy));

51:         antimatter.setPhUSDMinter(minter);

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

109:         minter.updateExchangeRate(address(usdc), 95e16); // 0.95 phUSD per USDC

263:         minter.setPauser(address(this));

264:         minter.pause();

300:         vm.mockCall(

301:             address(minter),

320:         vm.mockCall(

321:             address(minter),

333:         minter.updateExchangeRate(address(usdc), 0);

347:         minter.registerStablecoin(address(evil), address(strategy), 1e18, 18);

348:         minter.approveYS(address(evil), address(strategy));

367:         antimatter.setPhUSDMinter(minter);

390:         emit Antimatter.PhUSDMinterSet(address(minter), address(minter));

390:         emit Antimatter.PhUSDMinterSet(address(minter), address(minter));

392:         antimatter.setPhUSDMinter(minter);

468:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 6);

469:         minter.approveYS(address(liar), address(strategy));

480:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 18);

481:         minter.approveYS(address(liar), address(strategy));

534:         minter.registerStablecoin(ghost, address(strategy), 1e18, 6);

551:         minter.registerStablecoin(address(fat), address(strategy), 1e18, 24);

552:         minter.approveYS(address(fat), address(strategy));

563:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 6);

564:         minter.approveYS(address(liar), address(strategy));

576:         assertEq(strategy.principal(address(liar), address(minter)), 0, "nothing deposited");

576:         assertEq(strategy.principal(address(liar), address(minter)), 0, "nothing deposited");

576:         assertEq(strategy.principal(address(liar), address(minter)), 0, "nothing deposited");

```

```solidity
File: test/Antimatter.t.sol

84:         assertFalse(antimatter.isApprovedMinter(minter));

84:         assertFalse(antimatter.isApprovedMinter(minter));

89:         emit Antimatter.ApprovedMinterSet(minter, true);

91:         antimatter.setApprovedMinter(minter, true);

93:         assertTrue(antimatter.isApprovedMinter(minter));

93:         assertTrue(antimatter.isApprovedMinter(minter));

95:         assertEq(antimatter.approvedMinterAt(0), minter);

98:         assertEq(all[0], minter);

103:         antimatter.setApprovedMinter(minter, true);

104:         antimatter.setApprovedMinter(minter2, true);

108:         emit Antimatter.ApprovedMinterSet(minter, false);

109:         antimatter.setApprovedMinter(minter, false);

112:         assertFalse(antimatter.isApprovedMinter(minter));

112:         assertFalse(antimatter.isApprovedMinter(minter));

113:         assertTrue(antimatter.isApprovedMinter(minter2));

113:         assertTrue(antimatter.isApprovedMinter(minter2));

115:         assertEq(antimatter.approvedMinterAt(0), minter2);

120:         antimatter.setApprovedMinter(minter, true);

121:         antimatter.setApprovedMinter(minter, true);

128:         antimatter.setApprovedMinter(minter, true);

129:         antimatter.setApprovedMinter(minter, false);

130:         antimatter.setApprovedMinter(minter, true);

133:         assertTrue(antimatter.isApprovedMinter(minter));

133:         assertTrue(antimatter.isApprovedMinter(minter));

136:         vm.prank(minter);

143:         antimatter.setApprovedMinter(minter, false);

150:         antimatter.setApprovedMinter(minter, true);

155:         antimatter.setApprovedMinter(minter, true);

159:         antimatter.setApprovedMinter(minter, false);

172:         antimatter.setApprovedMinter(minter, true);

174:         vm.prank(minter);

194:         antimatter.setApprovedMinter(minter, true);

195:         antimatter.setApprovedMinter(minter, false);

198:         vm.prank(minter);

199:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, minter));

199:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, minter));

```

```solidity
File: test/mocks/MockStable.sol

19:         _mint(to, amount);

```

```solidity
File: test/mocks/ReentrantStable.sol

22:         _mint(to, amount);

```

### <a name="L-11"></a>[L-11] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (6)*:
```solidity
File: src/Antimatter.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/Annihilation.t.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/Antimatter.t.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/mocks/MockStable.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/mocks/ReentrantStable.sol

2: pragma solidity ^0.8.27;

```

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

*Instances (3)*:
```solidity
File: src/Antimatter.sol

8: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: test/Annihilation.t.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: test/Antimatter.t.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-13"></a>[L-13] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (7)*:
```solidity
File: src/Antimatter.sol

306:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

```solidity
File: test/Annihilation.t.sol

431:     function test_rescueERC20OnlyOwner() public {

434:         antimatter.rescueERC20(IERC20(address(usdc)), recipient, 1e6);

437:     function test_rescueERC20ReturnsTrappedTokens() public {

441:         antimatter.rescueERC20(IERC20(address(usdc)), recipient, 42e6);

447:     function test_rescueERC20RejectsZeroRecipient() public {

450:         antimatter.rescueERC20(IERC20(address(usdc)), address(0), 1);

```

### <a name="L-14"></a>[L-14] `symbol()` is not a part of the ERC-20 standard
The `symbol()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (1)*:
```solidity
File: test/Antimatter.t.sol

20:         assertEq(antimatter.symbol(), "AM");

```

### <a name="L-15"></a>[L-15] Unsafe ERC20 operation(s)

*Instances (4)*:
```solidity
File: test/Annihilation.t.sol

62:         stable.approve(address(antimatter), type(uint256).max);

136:         antimatter.approve(spender, type(uint256).max);

354:         evil.approve(address(antimatter), type(uint256).max);

```

```solidity
File: test/Antimatter.t.sol

46:         antimatter.transfer(stranger, 4 ether);

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 2 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 6 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (2)*:
```solidity
File: src/Antimatter.sol

246:         IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

15:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

```

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (6)*:
```solidity
File: src/Antimatter.sol

22: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

137:     constructor(address initialOwner) ERC20("Antimatter", "AM") Ownable(initialOwner) {}

142:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

154:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

169:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

306:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

