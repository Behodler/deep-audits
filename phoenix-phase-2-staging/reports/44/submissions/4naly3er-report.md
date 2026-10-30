# 4naly3er automated report: phoenix-phase-2-staging run 44 (script audit, src 669cbc1)

Unreviewed bot output. Nothing below has been triaged, and none of it is a pipeline finding unless the QA report says so.

- **Invocation:** `yarn analyze <audit-root>/phoenix-phase-2-staging/work/ <scope>`. `work/` is at 669cbc11a41b1bd677ac422391532bb79199b9a6, and the six in-scope files are byte-identical to `src/`. `work/remappings.txt` was generated with `forge remappings`.
- **Analysed (antimatter-pool closure):** `script/CutoverAntimatterPoolMainnet.s.sol`, `script/VerifyAntimatterPoolCutover.s.sol`, `src/periphery/AntimatterPoolSeeder.sol`. All 3 compiled, with 0 AST failures.
- **NOT analysed (sya-harvester closure), a coverage gap:** `script/DeploySyaHarvesterMainnet.s.sol`, `script/VerifySyaHarvester.s.sol`, `script/helpers/ClaimUnblockState.sol`. solc-js fails with error 9553, `Invalid implicit conversion from contract IStableYieldAccumulator to contract IStableYieldAccumulator` at DeploySyaHarvesterMainnet.s.sol:426. Two copies of `IStableYieldAccumulator` resolve through different remapping paths. forge's context remappings handle this; 4naly3er's single global remapping table does not. The bot baseline for these files is therefore absent, and only the manual sya-harvester findings in `qa-report.md` cover them.

---

# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | Use assembly to check for `address(0)` | 18 |
| [GAS-2](#GAS-2) | Using bools for storage incurs overhead | 4 |
| [GAS-3](#GAS-3) | State variables should be cached in stack variables rather than re-reading them from storage | 27 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 86 |
| [GAS-5](#GAS-5) | Use Custom Errors instead of Revert Strings to save Gas | 40 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 25 |
| [GAS-7](#GAS-7) | State variables only set in the constructor should be declared `immutable` | 7 |
| [GAS-8](#GAS-8) | Functions guaranteed to revert when called by normal users can be marked `payable` | 1 |
| [GAS-9](#GAS-9) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 2 |
| [GAS-10](#GAS-10) | Using `private` rather than `public` for constants, saves gas | 9 |
| [GAS-11](#GAS-11) | Splitting require() statements that use && saves gas | 4 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 2 |
| [GAS-13](#GAS-13) | Use != 0 instead of > 0 for unsigned integer comparison | 13 |
### <a name="GAS-1"></a>[GAS-1] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (18)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

162:         if (amPair != address(0)) require(IERC20(amPair).balanceOf(a) == 0, "end state: seeder holds AM/sUSDS LP");

188:         require(a != address(0), string.concat("address book: key missing or zero in mainnet-addresses.ts: ", key));

262:         if (existing != address(0)) {

264:                 p.seeder != address(0) && p.seeder.code.length > 0 && IERC20(existing).balanceOf(OWNER) > 0,

275:         if (p.seeder != address(0)) {

418:         require(amSusdsPair != address(0), "Step 9: AM/sUSDS pair not created");

466:         if (p.amPair != address(0)) {

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

49:         require(seederAddr != address(0), "verify: no AntimatterPoolSeeder address - broadcast first");

50:         require(pairAddr != address(0), "verify: no AntimatterSusdsPair address - broadcast first");

89:         if (fromProgress != address(0) && fromBook != address(0)) {

95:         return fromBook != address(0) ? fromBook : fromProgress;

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

105:             phUSD_ == address(0) || sUSDS_ == address(0) || antimatter_ == address(0) || uniV2Router_ == address(0)

106:                 || phusdSusdsPair_ == address(0) || lpSource_ == address(0)

110:         if (factory_ == address(0)) revert ZeroAddress();

159:         if (lpRecipient == address(0)) revert ZeroAddress();

179:         if (amPair == address(0)) {

205:         if (to == address(0)) revert ZeroAddress();

269:         s[4] = amPair == address(0) ? 0 : IERC20(amPair).balanceOf(address(this));

```

### <a name="GAS-2"></a>[GAS-2] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (4)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

233:     bool public deployedThisRun;

234:     bool public seededThisRun;

235:     bool public rescuedThisRun;

239:     bool internal isPreview;

```

### <a name="GAS-3"></a>[GAS-3] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (27)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

291:             console.log("  deployed:", address(seeder));

293:         _checkSeeder(seeder, c);

334:             if (lpToken.allowance(OWNER, address(seeder)) >= p.lpAmount) {

338:                 lpToken.approve(address(seeder), p.lpAmount);

344:             if (am.isApprovedMinter(address(seeder))) {

348:                 am.setApprovedMinter(address(seeder), true);

351:             require(am.isApprovedMinter(address(seeder)), "Step 6: seeder is not an approved AM minter (silent no-op?)");

406:         if (am.isApprovedMinter(address(seeder))) {

408:             am.setApprovedMinter(address(seeder), false);

413:         require(!am.isApprovedMinter(address(seeder)), "Step 8: seeder AM minter role NOT revoked");

424:         (uint112 r0, uint112 r1,) = IAmCutoverPair(amSusdsPair).getReserves();

426:         _requireSeederEmpty(seeder, c, amSusdsPair);

426:         _requireSeederEmpty(seeder, c, amSusdsPair);

427:         p.amPair = amSusdsPair;

428:         console.log("  AntimatterSusdsPair:", amSusdsPair);

429:         console.log("  AntimatterPoolSeeder:", address(seeder));

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

166:         IERC20(phusdSusdsPair).safeTransferFrom(msg.sender, phusdSusdsPair, lpAmount);

167:         (uint256 amount0, uint256 amount1) = IUniswapV2PairBurn(phusdSusdsPair).burn(address(this));

180:             amPair = IUniswapV2FactoryCreate(factory).createPair(antimatter, sUSDS);

241:         IERC20(sUSDS).forceApprove(router, susdsDesired);

243:         (amUsed, susdsUsed, liquidity) = IUniswapV2Router02(router)

244:             .addLiquidity(antimatter, sUSDS, amAmount, susdsDesired, amAmount, 0, lpRecipient, deadline);

244:             .addLiquidity(antimatter, sUSDS, amAmount, susdsDesired, amAmount, 0, lpRecipient, deadline);

246:         IERC20(antimatter).forceApprove(router, 0);

246:         IERC20(antimatter).forceApprove(router, 0);

247:         IERC20(sUSDS).forceApprove(router, 0);

247:         IERC20(sUSDS).forceApprove(router, 0);

```

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (86)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

4: import "@forge-std/Script.sol";

5: import "@forge-std/console.sol";

6: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

7: import {AntimatterPoolSeeder} from "../src/periphery/AntimatterPoolSeeder.sol";

73:     string public constant ADDRESS_BOOK = "server/deployments/mainnet-addresses.ts";

74:     string public constant PROGRESS_FILE = "server/deployments/progress.antimatter-pool.1.json";

133:             "preflight: PhusdSusdsPair is not the factory's canonical phUSD/sUSDS pair"

161:         require(IERC20(c.phusdSusdsPair).balanceOf(a) == 0, "end state: seeder holds phUSD/sUSDS LP");

162:         if (amPair != address(0)) require(IERC20(amPair).balanceOf(a) == 0, "end state: seeder holds AM/sUSDS LP");

177:         uint256 start = at + bytes(needle).length;

178:         require(src.length >= start + 42, string.concat("address book: truncated entry for ", key));

180:         for (uint256 i; i < 42; i++) {

181:             lit[i] = src[start + i];

188:         require(a != address(0), string.concat("address book: key missing or zero in mainnet-addresses.ts: ", key));

243:         console.log("  CUTOVER Antimatter/sUSDS pool - MAINNET (story 122, Script B)");

245:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

253:         console.log("Preflight OK: canonical phUSD/sUSDS pair; OWNER owns UniPoolerV2 and Antimatter");

259:         console.log("\n=== Step 0: AM/sUSDS pair precondition ===");

265:                 "Step 0: the AM/sUSDS pair ALREADY EXISTS and this cutover did not create it - ABORT (griefing risk R1, story 113). Do not seed into a pair someone else created; investigate first."

278:                 "Progress file names an AntimatterPoolSeeder with NO CODE - recorded in forge's local pass but never landed. Delete server/deployments/progress.antimatter-pool.1.json and re-run preview."

283:             require(!seedDone, "Step 1: pair seeded but no seeder recorded - STOP");

302:             require(p.lpAmount > 0, "Step 2: lpForBps(1_000) is zero - UniPoolerV2 holds no LP");

303:             require(p.lpAmount == p.poolerLpBefore * CUTOVER_BPS / BPS, "Step 2: lpForBps sizing mismatch");

307:         console.log("  UniPoolerV2 phUSD/sUSDS LP before:", p.poolerLpBefore);

309:         console.log("  phUSD/sUSDS LP total supply:      ", IAmCutoverPair(c.phusdSusdsPair).totalSupply());

315:             if (lpToken.balanceOf(OWNER) >= p.ownerLpBefore + p.lpAmount) {

316:                 console.log("  OWNER already holds the slice - skipped (resume)");

324:                     lpToken.balanceOf(c.uniPooler) == poolerAtRescue - p.lpAmount,

330:             require(lpToken.balanceOf(OWNER) >= p.ownerLpBefore + p.lpAmount, "Step 4: OWNER does not hold the slice");

335:                 console.log("  allowance already covers the slice - skipped");

345:                 console.log("  already an approved minter - skipped");

351:             require(am.isApprovedMinter(address(seeder)), "Step 6: seeder is not an approved AM minter (silent no-op?)");

354:             console.log("\n=== Steps 3 + 7: floors + seed ===");

362:             uint256 ownerAmLpBefore = 0; // the pair does not exist yet (step 0)

364:             (p.amMinted, p.liquidity) = seeder.seed(p.lpAmount, minP, minS, OWNER, block.timestamp + SEED_DEADLINE);

376:                 p.phusdSupplyBefore - p.phusdSupplyAfter == p.amMinted,

380:                 p.amSupplyAfter - p.amSupplyBefore == p.amMinted,

386:                     p.poolerLpAfter == p.poolerLpBefore - p.lpAmount,

391:                 IERC20(pairNow).balanceOf(OWNER) == ownerAmLpBefore + p.liquidity && p.liquidity > 0,

392:                 "end state: OWNER does not hold the AM/sUSDS LP"

397:             console.log("  AM/sUSDS LP to OWNER:     ", p.liquidity);

416:         console.log("\n=== Step 9: pair read-back ===");

418:         require(amSusdsPair != address(0), "Step 9: AM/sUSDS pair not created");

423:         require(IERC20(amSusdsPair).balanceOf(OWNER) > 0, "Step 9: OWNER holds no AM/sUSDS LP");

425:         require(r0 > 0 && r1 > 0, "Step 9: AM/sUSDS reserves are zero");

430:         console.log("  seeder empty, not a minter; OWNER holds the AM/sUSDS LP");

440:         uint256 expP = IERC20(c.phUSD).balanceOf(c.phusdSusdsPair) * lp / supply;

441:         uint256 expS = IERC20(c.sUSDS).balanceOf(c.phusdSusdsPair) * lp / supply;

442:         minP = expP * (BPS - FLOOR_TOLERANCE_BPS) / BPS;

443:         minS = expS * (BPS - FLOOR_TOLERANCE_BPS) / BPS;

452:         txCount++;

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

4: import "@forge-std/console.sol";

5: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import {AntimatterPoolSeeder} from "../src/periphery/AntimatterPoolSeeder.sol";

12: } from "./CutoverAntimatterPoolMainnet.s.sol";

39:         console.log("  VERIFY Antimatter/sUSDS cutover - MAINNET (story 122, Script B)");

41:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

49:         require(seederAddr != address(0), "verify: no AntimatterPoolSeeder address - broadcast first");

50:         require(pairAddr != address(0), "verify: no AntimatterSusdsPair address - broadcast first");

62:             "verify: seeder is STILL an approved Antimatter minter - revoke it"

65:         require(r0 > 0 && r1 > 0, "verify: AM/sUSDS reserves are zero");

67:         require(ownerLp > 0, "verify: OWNER holds no AM/sUSDS LP");

70:         console.log("         seeder owner/immutables, empty, not an AM minter; canonical pair; OWNER holds LP");

74:             require(p.phusdSupplyBefore - p.phusdSupplyAfter == p.amMinted, "verify: record: phUSD burned != AM minted");

75:             require(p.amSupplyAfter - p.amSupplyBefore == p.amMinted, "verify: record: AM supply rise != AM minted");

79:             console.log("           AM/sUSDS LP minted to OWNER", p.liquidity);

80:             console.log("           UniPoolerV2 LP before / after", p.poolerLpBefore, p.poolerLpAfter);

82:             console.log("  drift: current OWNER AM/sUSDS LP", ownerLp);

84:             console.log("NOTE: no seed record in the progress file (address-book-only verification).");

92:                 string.concat("verify: progress file and mainnet-addresses.ts disagree on ", key)

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

7: import {IUniswapV2Router02} from "@yield-claim-nft/interfaces/uniswap/IUniswapV2Router02.sol";

8: import {IUniswapV2Pair} from "@yield-claim-nft/interfaces/uniswap/IUniswapV2Pair.sol";

9: import {IPhusdBurnable} from "@yield-claim-nft/interfaces/IPhusdBurnable.sol";

10: import {IUniswapV2FactoryCreate} from "./interfaces/IUniswapV2FactoryCreate.sol";

11: import {IUniswapV2PairBurn} from "./interfaces/IUniswapV2PairBurn.sol";

12: import {IUniswapV2PairMint} from "./interfaces/IUniswapV2PairMint.sol";

13: import {IAntimatterMintable} from "./interfaces/IAntimatterMintable.sol";

133:         return IERC20(phusdSusdsPair).balanceOf(lpSource) * bps / BPS_DENOMINATOR;

190:         if (susdsOut > susdsPaired) IERC20(sUSDS).safeTransfer(lpRecipient, susdsOut - susdsPaired);

223:         if (r0 == 0 && r1 == 0) return false; // empty pair: the router add sets the ratio

228:             return true; // one-sided dust, no LP: the direct mint sets the ratio and absorbs the dust

230:         uint256 susdsRequired = amAmount * rSusds / rAm;

276:         for (uint256 i; i < 5; ++i) {

```

### <a name="GAS-5"></a>[GAS-5] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (40)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

135:         require(IAmCutoverPooler(c.uniPooler).owner() == OWNER, "preflight: UniPoolerV2 owner != OWNER");

136:         require(IAmCutoverAntimatter(c.antimatter).owner() == OWNER, "preflight: Antimatter owner != OWNER");

144:         require(address(s).code.length > 0, "verify: AntimatterPoolSeeder has no code");

145:         require(s.owner() == OWNER, "verify: seeder owner != OWNER");

146:         require(s.phUSD() == c.phUSD, "verify: seeder phUSD mismatch");

147:         require(s.sUSDS() == c.sUSDS, "verify: seeder sUSDS mismatch");

148:         require(s.antimatter() == c.antimatter, "verify: seeder antimatter mismatch");

149:         require(s.router() == c.router, "verify: seeder router mismatch");

150:         require(s.factory() == c.factory, "verify: seeder factory mismatch");

151:         require(s.phusdSusdsPair() == c.phusdSusdsPair, "verify: seeder phusdSusdsPair mismatch");

152:         require(s.lpSource() == c.uniPooler, "verify: seeder lpSource != UniPoolerV2");

158:         require(IERC20(c.phUSD).balanceOf(a) == 0, "end state: seeder holds phUSD");

159:         require(IERC20(c.antimatter).balanceOf(a) == 0, "end state: seeder holds Antimatter");

160:         require(IERC20(c.sUSDS).balanceOf(a) == 0, "end state: seeder holds sUSDS");

161:         require(IERC20(c.phusdSusdsPair).balanceOf(a) == 0, "end state: seeder holds phUSD/sUSDS LP");

162:         if (amPair != address(0)) require(IERC20(amPair).balanceOf(a) == 0, "end state: seeder holds AM/sUSDS LP");

245:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

283:             require(!seedDone, "Step 1: pair seeded but no seeder recorded - STOP");

302:             require(p.lpAmount > 0, "Step 2: lpForBps(1_000) is zero - UniPoolerV2 holds no LP");

303:             require(p.lpAmount == p.poolerLpBefore * CUTOVER_BPS / BPS, "Step 2: lpForBps sizing mismatch");

319:                 require(poolerAtRescue >= p.lpAmount, "Step 4: UniPoolerV2 holds less LP than the slice");

330:             require(lpToken.balanceOf(OWNER) >= p.ownerLpBefore + p.lpAmount, "Step 4: OWNER does not hold the slice");

351:             require(am.isApprovedMinter(address(seeder)), "Step 6: seeder is not an approved AM minter (silent no-op?)");

374:             require(p.amMinted > 0, "end state: seed minted no Antimatter");

383:             require(p.amReserve == p.amMinted, "end state: pair AM reserve != AM minted (not fully consumed)");

413:         require(!am.isApprovedMinter(address(seeder)), "Step 8: seeder AM minter role NOT revoked");

418:         require(amSusdsPair != address(0), "Step 9: AM/sUSDS pair not created");

423:         require(IERC20(amSusdsPair).balanceOf(OWNER) > 0, "Step 9: OWNER holds no AM/sUSDS LP");

425:         require(r0 > 0 && r1 > 0, "Step 9: AM/sUSDS reserves are zero");

444:         require(minP > 0 && minS > 0, "Step 3: zero unwrap floor");

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

41:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

49:         require(seederAddr != address(0), "verify: no AntimatterPoolSeeder address - broadcast first");

50:         require(pairAddr != address(0), "verify: no AntimatterSusdsPair address - broadcast first");

58:         require(seeder.amSusdsPair() == pairAddr, "verify: seeder.amSusdsPair() != AntimatterSusdsPair");

65:         require(r0 > 0 && r1 > 0, "verify: AM/sUSDS reserves are zero");

67:         require(ownerLp > 0, "verify: OWNER holds no AM/sUSDS LP");

73:             require(p.lpAmount > 0 && p.amMinted > 0, "verify: progress seed record is empty");

74:             require(p.phusdSupplyBefore - p.phusdSupplyAfter == p.amMinted, "verify: record: phUSD burned != AM minted");

75:             require(p.amSupplyAfter - p.amSupplyBefore == p.amMinted, "verify: record: AM supply rise != AM minted");

76:             require(p.amReserve == p.amMinted, "verify: record: pair AM reserve at seed != AM minted");

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (25)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

158:         require(IERC20(c.phUSD).balanceOf(a) == 0, "end state: seeder holds phUSD");

159:         require(IERC20(c.antimatter).balanceOf(a) == 0, "end state: seeder holds Antimatter");

160:         require(IERC20(c.sUSDS).balanceOf(a) == 0, "end state: seeder holds sUSDS");

161:         require(IERC20(c.phusdSusdsPair).balanceOf(a) == 0, "end state: seeder holds phUSD/sUSDS LP");

162:         if (amPair != address(0)) require(IERC20(amPair).balanceOf(a) == 0, "end state: seeder holds AM/sUSDS LP");

264:                 p.seeder != address(0) && p.seeder.code.length > 0 && IERC20(existing).balanceOf(OWNER) > 0,

299:             p.poolerLpBefore = lpToken.balanceOf(c.uniPooler);

300:             p.ownerLpBefore = lpToken.balanceOf(OWNER);

315:             if (lpToken.balanceOf(OWNER) >= p.ownerLpBefore + p.lpAmount) {

318:                 uint256 poolerAtRescue = lpToken.balanceOf(c.uniPooler);

324:                     lpToken.balanceOf(c.uniPooler) == poolerAtRescue - p.lpAmount,

327:                 p.poolerLpAfter = lpToken.balanceOf(c.uniPooler);

330:             require(lpToken.balanceOf(OWNER) >= p.ownerLpBefore + p.lpAmount, "Step 4: OWNER does not hold the slice");

361:             if (!rescuedThisRun) p.poolerLpAfter = lpToken.balanceOf(c.uniPooler);

391:                 IERC20(pairNow).balanceOf(OWNER) == ownerAmLpBefore + p.liquidity && p.liquidity > 0,

423:         require(IERC20(amSusdsPair).balanceOf(OWNER) > 0, "Step 9: OWNER holds no AM/sUSDS LP");

440:         uint256 expP = IERC20(c.phUSD).balanceOf(c.phusdSusdsPair) * lp / supply;

441:         uint256 expS = IERC20(c.sUSDS).balanceOf(c.phusdSusdsPair) * lp / supply;

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

66:         uint256 ownerLp = IERC20(pairAddr).balanceOf(OWNER);

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

133:         return IERC20(phusdSusdsPair).balanceOf(lpSource) * bps / BPS_DENOMINATOR;

265:         s[0] = IERC20(phUSD).balanceOf(address(this));

266:         s[1] = IERC20(antimatter).balanceOf(address(this));

267:         s[2] = IERC20(sUSDS).balanceOf(address(this));

268:         s[3] = IERC20(phusdSusdsPair).balanceOf(address(this));

269:         s[4] = amPair == address(0) ? 0 : IERC20(amPair).balanceOf(address(this));

```

### <a name="GAS-7"></a>[GAS-7] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (7)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

115:         phUSD = phUSD_;

116:         sUSDS = sUSDS_;

117:         antimatter = antimatter_;

118:         router = uniV2Router_;

119:         factory = factory_;

120:         phusdSusdsPair = phusdSusdsPair_;

121:         lpSource = lpSource_;

```

### <a name="GAS-8"></a>[GAS-8] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (1)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

204:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

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

*Instances (2)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

180:         for (uint256 i; i < 42; i++) {

452:         txCount++;

```

### <a name="GAS-10"></a>[GAS-10] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (9)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

70:     uint256 public constant CHAIN_ID = 1;

71:     string public constant NETWORK_NAME = "mainnet";

72:     address public constant OWNER = 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6;

73:     string public constant ADDRESS_BOOK = "server/deployments/mainnet-addresses.ts";

74:     string public constant PROGRESS_FILE = "server/deployments/progress.antimatter-pool.1.json";

77:     uint256 public constant CUTOVER_BPS = 1_000;

78:     uint256 public constant BPS = 10_000;

80:     uint256 public constant FLOOR_TOLERANCE_BPS = 10;

81:     uint256 public constant SEED_DEADLINE = 1 hours;

```

### <a name="GAS-11"></a>[GAS-11] Splitting require() statements that use && saves gas

*Instances (4)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

425:         require(r0 > 0 && r1 > 0, "Step 9: AM/sUSDS reserves are zero");

444:         require(minP > 0 && minS > 0, "Step 3: zero unwrap floor");

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

65:         require(r0 > 0 && r1 > 0, "verify: AM/sUSDS reserves are zero");

73:             require(p.lpAmount > 0 && p.amMinted > 0, "verify: progress seed record is empty");

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

*Instances (2)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

180:         for (uint256 i; i < 42; i++) {

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

276:         for (uint256 i; i < 5; ++i) {

```

### <a name="GAS-13"></a>[GAS-13] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (13)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

140:         require(a.code.length > 0, string.concat("preflight: no code at ", name));

144:         require(address(s).code.length > 0, "verify: AntimatterPoolSeeder has no code");

264:                 p.seeder != address(0) && p.seeder.code.length > 0 && IERC20(existing).balanceOf(OWNER) > 0,

277:                 p.seeder.code.length > 0,

302:             require(p.lpAmount > 0, "Step 2: lpForBps(1_000) is zero - UniPoolerV2 holds no LP");

374:             require(p.amMinted > 0, "end state: seed minted no Antimatter");

391:                 IERC20(pairNow).balanceOf(OWNER) == ownerAmLpBefore + p.liquidity && p.liquidity > 0,

423:         require(IERC20(amSusdsPair).balanceOf(OWNER) > 0, "Step 9: OWNER holds no AM/sUSDS LP");

425:         require(r0 > 0 && r1 > 0, "Step 9: AM/sUSDS reserves are zero");

444:         require(minP > 0 && minS > 0, "Step 3: zero unwrap floor");

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

65:         require(r0 > 0 && r1 > 0, "verify: AM/sUSDS reserves are zero");

67:         require(ownerLp > 0, "verify: OWNER holds no AM/sUSDS LP");

73:             require(p.lpAmount > 0 && p.amMinted > 0, "verify: progress seed record is empty");

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Array indices should be referenced via `enum`s rather than via numeric literals | 5 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 25 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 49 |
| [NC-4](#NC-4) | Delete rogue `console.log` imports | 2 |
| [NC-5](#NC-5) | Consider disabling `renounceOwnership()` | 1 |
| [NC-6](#NC-6) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 3 |
| [NC-7](#NC-7) | Function ordering does not follow the Solidity style guide | 2 |
| [NC-8](#NC-8) | Functions should not be longer than 50 lines | 32 |
| [NC-9](#NC-9) | Change int to int256 | 1 |
| [NC-10](#NC-10) | Interfaces should be defined in separate files from their usage | 5 |
| [NC-11](#NC-11) | Lack of checks in setters | 1 |
| [NC-12](#NC-12) | Lines are too long | 2 |
| [NC-13](#NC-13) | Missing Event for critical parameters change | 1 |
| [NC-14](#NC-14) | NatSpec is completely non-existent on functions that should have them | 6 |
| [NC-15](#NC-15) | Incomplete NatSpec: `@param` is missing on actually documented functions | 1 |
| [NC-16](#NC-16) | `address`s shouldn't be hard-coded | 1 |
| [NC-17](#NC-17) | Adding a `return` statement when the function defines a named return variable, is redundant | 4 |
| [NC-18](#NC-18) | Take advantage of Custom Error's return value property | 6 |
| [NC-19](#NC-19) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-20](#NC-20) | Internal and private variables and functions names should begin with an underscore | 1 |
| [NC-21](#NC-21) | Event is missing `indexed` fields | 2 |
| [NC-22](#NC-22) | Constants should be defined rather than using magic numbers | 1 |
| [NC-23](#NC-23) | Variables need not be initialized to zero | 1 |
### <a name="NC-1"></a>[NC-1] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (5)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

265:         s[0] = IERC20(phUSD).balanceOf(address(this));

266:         s[1] = IERC20(antimatter).balanceOf(address(this));

267:         s[2] = IERC20(sUSDS).balanceOf(address(this));

268:         s[3] = IERC20(phusdSusdsPair).balanceOf(address(this));

269:         s[4] = amPair == address(0) ? 0 : IERC20(amPair).balanceOf(address(this));

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (25)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

178:         require(src.length >= start + 42, string.concat("address book: truncated entry for ", key));

180:         for (uint256 i; i < 42; i++) {

243:         console.log("  CUTOVER Antimatter/sUSDS pool - MAINNET (story 122, Script B)");

265:                 "Step 0: the AM/sUSDS pair ALREADY EXISTS and this cutover did not create it - ABORT (griefing risk R1, story 113). Do not seed into a pair someone else created; investigate first."

296:         console.log("\n=== Step 2: LP slice ===");

302:             require(p.lpAmount > 0, "Step 2: lpForBps(1_000) is zero - UniPoolerV2 holds no LP");

303:             require(p.lpAmount == p.poolerLpBefore * CUTOVER_BPS / BPS, "Step 2: lpForBps sizing mismatch");

314:             console.log("\n=== Step 4: UniPoolerV2.rescueERC20(PhusdSusdsPair, OWNER, lp) ===");

319:                 require(poolerAtRescue >= p.lpAmount, "Step 4: UniPoolerV2 holds less LP than the slice");

325:                     "Step 4: UniPoolerV2 LP did not fall by exactly the slice"

330:             require(lpToken.balanceOf(OWNER) >= p.ownerLpBefore + p.lpAmount, "Step 4: OWNER does not hold the slice");

333:             console.log("\n=== Step 5: approve seeder ===");

343:             console.log("\n=== Step 6: Antimatter.setApprovedMinter(seeder, true) ===");

351:             require(am.isApprovedMinter(address(seeder)), "Step 6: seeder is not an approved AM minter (silent no-op?)");

354:             console.log("\n=== Steps 3 + 7: floors + seed ===");

405:         console.log("\n=== Step 8: Antimatter.setApprovedMinter(seeder, false) (always) ===");

413:         require(!am.isApprovedMinter(address(seeder)), "Step 8: seeder AM minter role NOT revoked");

416:         console.log("\n=== Step 9: pair read-back ===");

418:         require(amSusdsPair != address(0), "Step 9: AM/sUSDS pair not created");

421:             "Step 9: seeder.amSusdsPair() != factory.getPair(AM, sUSDS)"

423:         require(IERC20(amSusdsPair).balanceOf(OWNER) > 0, "Step 9: OWNER holds no AM/sUSDS LP");

425:         require(r0 > 0 && r1 > 0, "Step 9: AM/sUSDS reserves are zero");

444:         require(minP > 0 && minS > 0, "Step 3: zero unwrap floor");

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

39:         console.log("  VERIFY Antimatter/sUSDS cutover - MAINNET (story 122, Script B)");

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

276:         for (uint256 i; i < 5; ++i) {

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (49)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

144:         require(address(s).code.length > 0, "verify: AntimatterPoolSeeder has no code");

145:         require(s.owner() == OWNER, "verify: seeder owner != OWNER");

146:         require(s.phUSD() == c.phUSD, "verify: seeder phUSD mismatch");

147:         require(s.sUSDS() == c.sUSDS, "verify: seeder sUSDS mismatch");

148:         require(s.antimatter() == c.antimatter, "verify: seeder antimatter mismatch");

149:         require(s.router() == c.router, "verify: seeder router mismatch");

150:         require(s.factory() == c.factory, "verify: seeder factory mismatch");

151:         require(s.phusdSusdsPair() == c.phusdSusdsPair, "verify: seeder phusdSusdsPair mismatch");

152:         require(s.lpSource() == c.uniPooler, "verify: seeder lpSource != UniPoolerV2");

162:         if (amPair != address(0)) require(IERC20(amPair).balanceOf(a) == 0, "end state: seeder holds AM/sUSDS LP");

175:         if (at == type(uint256).max) return address(0);

204:         if (bytes(json).length == 0) return p;

216:         if (vm.keyExistsJson(json, ".cutover.seeded")) p.seeded = vm.parseJsonBool(json, ".cutover.seeded");

361:             if (!rescuedThisRun) p.poolerLpAfter = lpToken.balanceOf(c.uniPooler);

450:         if (isPreview) vm.startPrank(OWNER);

456:         if (isPreview) vm.stopPrank();

461:         if (isPreview) return;

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

39:         console.log("  VERIFY Antimatter/sUSDS cutover - MAINNET (story 122, Script B)");

49:         require(seederAddr != address(0), "verify: no AntimatterPoolSeeder address - broadcast first");

50:         require(pairAddr != address(0), "verify: no AntimatterSusdsPair address - broadcast first");

56:             "verify: AntimatterSusdsPair != factory.getPair(AM, sUSDS)"

58:         require(seeder.amSusdsPair() == pairAddr, "verify: seeder.amSusdsPair() != AntimatterSusdsPair");

62:             "verify: seeder is STILL an approved Antimatter minter - revoke it"

65:         require(r0 > 0 && r1 > 0, "verify: AM/sUSDS reserves are zero");

67:         require(ownerLp > 0, "verify: OWNER holds no AM/sUSDS LP");

73:             require(p.lpAmount > 0 && p.amMinted > 0, "verify: progress seed record is empty");

74:             require(p.phusdSupplyBefore - p.phusdSupplyAfter == p.amMinted, "verify: record: phUSD burned != AM minted");

75:             require(p.amSupplyAfter - p.amSupplyBefore == p.amMinted, "verify: record: AM supply rise != AM minted");

76:             require(p.amReserve == p.amMinted, "verify: record: pair AM reserve at seed != AM minted");

81:             console.log("  drift: current pair AM reserve", _amReserve(pairAddr, c.antimatter));

82:             console.log("  drift: current OWNER AM/sUSDS LP", ownerLp);

84:             console.log("NOTE: no seed record in the progress file (address-book-only verification).");

92:                 string.concat("verify: progress file and mainnet-addresses.ts disagree on ", key)

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

104:         if (

110:         if (factory_ == address(0)) revert ZeroAddress();

113:         if (canonical != phusdSusdsPair_) revert PairMismatch(canonical, phusdSusdsPair_);

132:         if (bps > BPS_DENOMINATOR) revert InvalidBps(bps);

158:         if (lpAmount == 0) revert ZeroAmount();

159:         if (lpRecipient == address(0)) revert ZeroAddress();

160:         if (block.timestamp > deadline) revert Expired(deadline, block.timestamp);

169:         if (phusdOut < minPhUSD) revert InsufficientPhUSD(phusdOut, minPhUSD);

170:         if (susdsOut < minSUSDS) revert InsufficientSUSDS(susdsOut, minSUSDS);

171:         if (phusdOut == 0) revert ZeroAmount();

190:         if (susdsOut > susdsPaired) IERC20(sUSDS).safeTransfer(lpRecipient, susdsOut - susdsPaired);

205:         if (to == address(0)) revert ZeroAddress();

223:         if (r0 == 0 && r1 == 0) return false; // empty pair: the router add sets the ratio

227:             if (supply != 0) revert OneSidedPair(rAm, rSusds, supply);

245:         if (amUsed != amAmount) revert AntimatterNotFullyConsumed(amAmount, susdsUsed, susdsDesired);

277:             if (before[i] != afterwards[i]) revert ResidualBalance(tokens[i], before[i], afterwards[i]);

```

### <a name="NC-4"></a>[NC-4] Delete rogue `console.log` imports
These shouldn't be deployed in production

*Instances (2)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

5: import "@forge-std/console.sol";

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

4: import "@forge-std/console.sol";

```

### <a name="NC-5"></a>[NC-5] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

50: contract AntimatterPoolSeeder is Ownable {

```

### <a name="NC-6"></a>[NC-6] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (3)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

140:         require(a.code.length > 0, string.concat("preflight: no code at ", name));

178:         require(src.length >= start + 42, string.concat("address book: truncated entry for ", key));

188:         require(a != address(0), string.concat("address book: key missing or zero in mainnet-addresses.ts: ", key));

```

### <a name="NC-7"></a>[NC-7] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (2)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

1: 
   Current order:
   external rescueERC20
   external owner
   external setApprovedMinter
   external isApprovedMinter
   external owner
   external factory
   external getPair
   external getReserves
   external token0
   external totalSupply
   public expectedConfig
   internal _preflight
   internal _code
   internal _checkSeeder
   internal _requireSeederEmpty
   internal _amReserve
   internal _bookAddress
   internal _requireBook
   internal _progressFile
   internal _readProgress
   external run
   internal _floors
   internal _begin
   internal _end
   internal _writeProgress
   internal _previewModeFromEnv
   
   Suggested order:
   external rescueERC20
   external owner
   external setApprovedMinter
   external isApprovedMinter
   external owner
   external factory
   external getPair
   external getReserves
   external token0
   external totalSupply
   external run
   public expectedConfig
   internal _preflight
   internal _code
   internal _checkSeeder
   internal _requireSeederEmpty
   internal _amReserve
   internal _bookAddress
   internal _requireBook
   internal _progressFile
   internal _readProgress
   internal _floors
   internal _begin
   internal _end
   internal _writeProgress
   internal _previewModeFromEnv

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

1: 
   Current order:
   external lpForBps
   public amSusdsPair
   external seed
   external rescueERC20
   internal _requireFullConsumption
   internal _addLiquidity
   internal _mintDirect
   internal _snapshot
   internal _requireUnchanged
   
   Suggested order:
   external lpForBps
   external seed
   external rescueERC20
   public amSusdsPair
   internal _requireFullConsumption
   internal _addLiquidity
   internal _mintDirect
   internal _snapshot
   internal _requireUnchanged

```

### <a name="NC-8"></a>[NC-8] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (32)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

10:     function rescueERC20(address token, address to, uint256 amount) external;

15:     function setApprovedMinter(address minter, bool approved) external;

16:     function isApprovedMinter(address minter) external view returns (bool);

21:     function factory() external view returns (address);

25:     function getPair(address tokenA, address tokenB) external view returns (address);

29:     function getReserves() external view returns (uint112, uint112, uint32);

30:     function token0() external view returns (address);

31:     function totalSupply() external view returns (uint256);

112:     function expectedConfig() public view returns (Config memory c) {

123:     function _preflight(Config memory c) internal view {

139:     function _code(address a, string memory name) internal view {

143:     function _checkSeeder(AntimatterPoolSeeder s, Config memory c) internal view {

156:     function _requireSeederEmpty(AntimatterPoolSeeder s, Config memory c, address amPair) internal view {

165:     function _amReserve(address amPair, address antimatter) internal view returns (uint256) {

172:     function _bookAddress(string memory book, string memory key) internal pure returns (address) {

186:     function _requireBook(string memory book, string memory key) internal pure returns (address a) {

193:     function _progressFile() internal view virtual returns (string memory) {

197:     function _readProgress() internal view returns (Progress memory p) {

438:     function _floors(Config memory c, uint256 lp) internal view returns (uint256 minP, uint256 minS) {

460:     function _writeProgress(Progress memory p, string memory status) internal {

499:     function _previewModeFromEnv() internal view virtual returns (bool) {

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

88:     function _pick(address fromProgress, address fromBook, string memory key) internal pure returns (address) {

99:     function _bookKey(string memory key) internal view virtual returns (address) {

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

131:     function lpForBps(uint256 bps) external view returns (uint256) {

137:     function amSusdsPair() public view returns (address) {

153:     function seed(uint256 lpAmount, uint256 minPhUSD, uint256 minSUSDS, address lpRecipient, uint256 deadline)

204:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

217:     function _requireFullConsumption(address amPair, uint256 amAmount, uint256 susdsAvailable)

236:     function _addLiquidity(uint256 amAmount, uint256 susdsDesired, address lpRecipient, uint256 deadline)

253:     function _mintDirect(address amPair, uint256 amAmount, uint256 susdsAmount, address lpRecipient)

264:     function _snapshot(address amPair) internal view returns (uint256[5] memory s) {

274:     function _requireUnchanged(uint256[5] memory before, uint256[5] memory afterwards) internal view {

```

### <a name="NC-9"></a>[NC-9] Change int to int256
Throughout the code base, some variables are declared as `int`. To favor explicitness, consider changing all instances of `int` to `int256`

*Instances (1)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

228:             return true; // one-sided dust, no LP: the direct mint sets the ratio and absorbs the dust

```

### <a name="NC-10"></a>[NC-10] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (5)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

9: interface IAmCutoverPooler {

14: interface IAmCutoverAntimatter {

20: interface IAmCutoverRouter {

24: interface IAmCutoverFactory {

28: interface IAmCutoverPair {

```

### <a name="NC-11"></a>[NC-11] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

15:     function setApprovedMinter(address minter, bool approved) external;

```

### <a name="NC-12"></a>[NC-12] Lines are too long
Usually lines in source code are limited to [80](https://softwareengineering.stackexchange.com/questions/148677/why-is-80-characters-the-standard-limit-for-code-width) characters. Today's screens are much larger so it's reasonable to stretch this in some cases. Since the files will most likely reside in GitHub, and GitHub starts using a scroll bar in all cases when the length is over [164](https://github.com/aizatto/character-length) characters, the lines below should be split when they reach that length

*Instances (2)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

265:                 "Step 0: the AM/sUSDS pair ALREADY EXISTS and this cutover did not create it - ABORT (griefing risk R1, story 113). Do not seed into a pair someone else created; investigate first."

278:                 "Progress file names an AntimatterPoolSeeder with NO CODE - recorded in forge's local pass but never landed. Delete server/deployments/progress.antimatter-pool.1.json and re-run preview."

```

### <a name="NC-13"></a>[NC-13] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

15:     function setApprovedMinter(address minter, bool approved) external;

```

### <a name="NC-14"></a>[NC-14] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (6)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

10:     function rescueERC20(address token, address to, uint256 amount) external;

10:     function rescueERC20(address token, address to, uint256 amount) external;

15:     function setApprovedMinter(address minter, bool approved) external;

15:     function setApprovedMinter(address minter, bool approved) external;

241:     function run() external {

241:     function run() external {

```

### <a name="NC-15"></a>[NC-15] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (1)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

203:     /// @notice Sends `amount` of `token` held by this contract to `to`. Owner only.
         function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

### <a name="NC-16"></a>[NC-16] `address`s shouldn't be hard-coded
It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

72:     address public constant OWNER = 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6;

```

### <a name="NC-17"></a>[NC-17] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (4)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

197:     function _readProgress() internal view returns (Progress memory p) {
             string memory json;
             try vm.readFile(_progressFile()) returns (string memory j) {
                 json = j;
             } catch {
                 return p;
             }
             if (bytes(json).length == 0) return p;

197:     function _readProgress() internal view returns (Progress memory p) {
             string memory json;
             try vm.readFile(_progressFile()) returns (string memory j) {
                 json = j;
             } catch {
                 return p;

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

212:     /// @dev Router02 would otherwise fall back to pairing LESS than all of the Antimatter (and then
         ///      revert on `amountAMin`); this check surfaces that case with the numbers attached.
         ///      Mirrors `UniswapV2Library.quote`.
         /// @return direct True when exactly one reserve is zero (and the pair has no LP supply), so the
         ///         router cannot be used and `seed` must mint into the pair directly.
         function _requireFullConsumption(address amPair, uint256 amAmount, uint256 susdsAvailable)
             internal
             view
             returns (bool direct)
         {
             (uint112 r0, uint112 r1,) = IUniswapV2Pair(amPair).getReserves();
             if (r0 == 0 && r1 == 0) return false; // empty pair: the router add sets the ratio

212:     /// @dev Router02 would otherwise fall back to pairing LESS than all of the Antimatter (and then
         ///      revert on `amountAMin`); this check surfaces that case with the numbers attached.
         ///      Mirrors `UniswapV2Library.quote`.
         /// @return direct True when exactly one reserve is zero (and the pair has no LP supply), so the
         ///         router cannot be used and `seed` must mint into the pair directly.
         function _requireFullConsumption(address amPair, uint256 amAmount, uint256 susdsAvailable)
             internal
             view
             returns (bool direct)
         {
             (uint112 r0, uint112 r1,) = IUniswapV2Pair(amPair).getReserves();
             if (r0 == 0 && r1 == 0) return false; // empty pair: the router add sets the ratio
             (uint256 rAm, uint256 rSusds) = antimatter < sUSDS ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
             if (rAm == 0 || rSusds == 0) {
                 uint256 supply = IUniswapV2Pair(amPair).totalSupply();
                 if (supply != 0) revert OneSidedPair(rAm, rSusds, supply);
                 return true; // one-sided dust, no LP: the direct mint sets the ratio and absorbs the dust

```

### <a name="NC-18"></a>[NC-18] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (6)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

107:         ) revert ZeroAddress();

110:         if (factory_ == address(0)) revert ZeroAddress();

158:         if (lpAmount == 0) revert ZeroAmount();

159:         if (lpRecipient == address(0)) revert ZeroAddress();

171:         if (phusdOut == 0) revert ZeroAmount();

205:         if (to == address(0)) revert ZeroAddress();

```

### <a name="NC-19"></a>[NC-19] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

1: 
   Current order:
   FunctionDefinition.rescueERC20
   FunctionDefinition.owner
   FunctionDefinition.setApprovedMinter
   FunctionDefinition.isApprovedMinter
   FunctionDefinition.owner
   FunctionDefinition.factory
   FunctionDefinition.getPair
   FunctionDefinition.getReserves
   FunctionDefinition.token0
   FunctionDefinition.totalSupply
   VariableDeclaration.CHAIN_ID
   VariableDeclaration.NETWORK_NAME
   VariableDeclaration.OWNER
   VariableDeclaration.ADDRESS_BOOK
   VariableDeclaration.PROGRESS_FILE
   VariableDeclaration.CUTOVER_BPS
   VariableDeclaration.BPS
   VariableDeclaration.FLOOR_TOLERANCE_BPS
   VariableDeclaration.SEED_DEADLINE
   StructDefinition.Config
   StructDefinition.Progress
   FunctionDefinition.expectedConfig
   FunctionDefinition._preflight
   FunctionDefinition._code
   FunctionDefinition._checkSeeder
   FunctionDefinition._requireSeederEmpty
   FunctionDefinition._amReserve
   FunctionDefinition._bookAddress
   FunctionDefinition._requireBook
   FunctionDefinition._progressFile
   FunctionDefinition._readProgress
   VariableDeclaration.seeder
   VariableDeclaration.amSusdsPair
   VariableDeclaration.deployedThisRun
   VariableDeclaration.seededThisRun
   VariableDeclaration.rescuedThisRun
   VariableDeclaration.txCount
   VariableDeclaration.progress
   VariableDeclaration.isPreview
   FunctionDefinition.run
   FunctionDefinition._floors
   FunctionDefinition._begin
   FunctionDefinition._end
   FunctionDefinition._writeProgress
   FunctionDefinition._previewModeFromEnv
   
   Suggested order:
   VariableDeclaration.CHAIN_ID
   VariableDeclaration.NETWORK_NAME
   VariableDeclaration.OWNER
   VariableDeclaration.ADDRESS_BOOK
   VariableDeclaration.PROGRESS_FILE
   VariableDeclaration.CUTOVER_BPS
   VariableDeclaration.BPS
   VariableDeclaration.FLOOR_TOLERANCE_BPS
   VariableDeclaration.SEED_DEADLINE
   VariableDeclaration.seeder
   VariableDeclaration.amSusdsPair
   VariableDeclaration.deployedThisRun
   VariableDeclaration.seededThisRun
   VariableDeclaration.rescuedThisRun
   VariableDeclaration.txCount
   VariableDeclaration.progress
   VariableDeclaration.isPreview
   StructDefinition.Config
   StructDefinition.Progress
   FunctionDefinition.rescueERC20
   FunctionDefinition.owner
   FunctionDefinition.setApprovedMinter
   FunctionDefinition.isApprovedMinter
   FunctionDefinition.owner
   FunctionDefinition.factory
   FunctionDefinition.getPair
   FunctionDefinition.getReserves
   FunctionDefinition.token0
   FunctionDefinition.totalSupply
   FunctionDefinition.expectedConfig
   FunctionDefinition._preflight
   FunctionDefinition._code
   FunctionDefinition._checkSeeder
   FunctionDefinition._requireSeederEmpty
   FunctionDefinition._amReserve
   FunctionDefinition._bookAddress
   FunctionDefinition._requireBook
   FunctionDefinition._progressFile
   FunctionDefinition._readProgress
   FunctionDefinition.run
   FunctionDefinition._floors
   FunctionDefinition._begin
   FunctionDefinition._end
   FunctionDefinition._writeProgress
   FunctionDefinition._previewModeFromEnv

```

### <a name="NC-20"></a>[NC-20] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

239:     bool internal isPreview;

```

### <a name="NC-21"></a>[NC-21] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (2)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

84:     event Seeded(

93:     event Rescued(address indexed token, address indexed to, uint256 amount);

```

### <a name="NC-22"></a>[NC-22] Constants should be defined rather than using magic numbers

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

179:         bytes memory lit = new bytes(42);

```

### <a name="NC-23"></a>[NC-23] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

362:             uint256 ownerAmLpBefore = 0; // the pair does not exist yet (step 0)

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 1 |
| [L-2](#L-2) | Use a 2-step ownership transfer pattern | 1 |
| [L-3](#L-3) | Some tokens may revert when zero value transfers are made | 5 |
| [L-4](#L-4) | Deprecated approve() function | 1 |
| [L-5](#L-5) | Division by zero not prevented | 4 |
| [L-6](#L-6) | Prevent accidentally burning tokens | 1 |
| [L-7](#L-7) | Possible rounding issue | 2 |
| [L-8](#L-8) | Loss of precision | 4 |
| [L-9](#L-9) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 2 |
| [L-10](#L-10) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
| [L-11](#L-11) | Sweeping may break accounting if tokens with multiple addresses are used | 4 |
| [L-12](#L-12) | Unsafe ERC20 operation(s) | 1 |
### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

338:                 lpToken.approve(address(seeder), p.lpAmount);

```

### <a name="L-2"></a>[L-2] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

50: contract AntimatterPoolSeeder is Ownable {

```

### <a name="L-3"></a>[L-3] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (5)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

166:         IERC20(phusdSusdsPair).safeTransferFrom(msg.sender, phusdSusdsPair, lpAmount);

190:         if (susdsOut > susdsPaired) IERC20(sUSDS).safeTransfer(lpRecipient, susdsOut - susdsPaired);

206:         IERC20(token).safeTransfer(to, amount);

257:         IERC20(antimatter).safeTransfer(amPair, amAmount);

258:         IERC20(sUSDS).safeTransfer(amPair, susdsAmount);

```

### <a name="L-4"></a>[L-4] Deprecated approve() function
Due to the inheritance of ERC20's approve function, there's a vulnerability to the ERC20 approve and double spend front running attack. Briefly, an authorized spender could spend both allowances by front running an allowance-changing transaction. Consider implementing OpenZeppelin's `.safeApprove()` function to help mitigate this.

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

338:                 lpToken.approve(address(seeder), p.lpAmount);

```

### <a name="L-5"></a>[L-5] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (4)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

440:         uint256 expP = IERC20(c.phUSD).balanceOf(c.phusdSusdsPair) * lp / supply;

441:         uint256 expS = IERC20(c.sUSDS).balanceOf(c.phusdSusdsPair) * lp / supply;

```

```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

80:             console.log("           UniPoolerV2 LP before / after", p.poolerLpBefore, p.poolerLpAfter);

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

230:         uint256 susdsRequired = amAmount * rSusds / rAm;

```

### <a name="L-6"></a>[L-6] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (1)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

186:             (susdsPaired, liquidity) = _mintDirect(amPair, phusdOut, susdsOut, lpRecipient);

```

### <a name="L-7"></a>[L-7] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (2)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

440:         uint256 expP = IERC20(c.phUSD).balanceOf(c.phusdSusdsPair) * lp / supply;

441:         uint256 expS = IERC20(c.sUSDS).balanceOf(c.phusdSusdsPair) * lp / supply;

```

### <a name="L-8"></a>[L-8] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (4)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

303:             require(p.lpAmount == p.poolerLpBefore * CUTOVER_BPS / BPS, "Step 2: lpForBps sizing mismatch");

442:         minP = expP * (BPS - FLOOR_TOLERANCE_BPS) / BPS;

443:         minS = expS * (BPS - FLOOR_TOLERANCE_BPS) / BPS;

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

133:         return IERC20(phusdSusdsPair).balanceOf(lpSource) * bps / BPS_DENOMINATOR;

```

### <a name="L-9"></a>[L-9] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (2)*:
```solidity
File: script/VerifyAntimatterPoolCutover.s.sol

2: pragma solidity ^0.8.20;

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

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

*Instances (1)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

### <a name="L-11"></a>[L-11] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (4)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

10:     function rescueERC20(address token, address to, uint256 amount) external;

314:             console.log("\n=== Step 4: UniPoolerV2.rescueERC20(PhusdSusdsPair, OWNER, lp) ===");

321:                 IAmCutoverPooler(c.uniPooler).rescueERC20(c.phusdSusdsPair, OWNER, p.lpAmount);

```

```solidity
File: src/periphery/AntimatterPoolSeeder.sol

204:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

### <a name="L-12"></a>[L-12] Unsafe ERC20 operation(s)

*Instances (1)*:
```solidity
File: script/CutoverAntimatterPoolMainnet.s.sol

338:                 lpToken.approve(address(seeder), p.lpAmount);

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 3 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (3)*:
```solidity
File: src/periphery/AntimatterPoolSeeder.sol

50: contract AntimatterPoolSeeder is Ownable {

103:     ) Ownable(owner_) {

204:     function rescueERC20(address token, address to, uint256 amount) external onlyOwner {

```

