# 4naly3er report: phoenix-phase-2-staging run 39 (script audit, entry point `dev`)

> **Provenance.** Generated 2026-10-03 by `tools/4naly3er` (`yarn analyze <audits>/phoenix-phase-2-staging/work/ <scope>`),
> basePath = the writable `work/` clone at `dfbf2f97643688aacee2f6f32281288e83cb0cac`, whose analysed files are
> byte-identical to `src/` (checked with `cmp`). `work/remappings.txt` (from `forge remappings`) supplies import
> resolution, because the upstream repo declares remappings only in `foundry.toml`.
>
> **Coverage (read before relying on this).** Scope is the first-party Solidity in the `dev` closure:
>
> | File | Result |
> |---|---|
> | `script/helpers/UniPoolerCutoverCore.sol` (location of L-01) | analysed, 0 AST failures |
> | `script/helpers/UniswapV2Deployer.sol` | analysed, 0 AST failures |
> | `script/DeployMocks.s.sol` (location of Q-01, Q-02) | **NOT analysed**: solc-js `DeclarationError: Identifier already declared` (`IYieldStrategy`, reached through both the `reflax-yield-vault/` and `vault/interfaces/` remappings, which 4naly3er does not canonicalise the way forge does). Same gap as run 30. Silence on this file is a tool limitation, not a clean result. |
>
> Each analysed file was run as its own scope, because a joint run fails on the DeployMocks compile error. The two
> raw outputs follow unchanged. **Triage:** no item rises to a finding. The Low hits on the core are approve()
> patterns on known tokens (sUSDS, phUSD, BPT, USDS), a BPT pro-rata division whose divisor is the live pool supply,
> and seed/exit tolerance arithmetic. The Medium hit on UniswapV2Deployer is the tool's "library function isn't
> internal" pattern matched against interface declarations, a false positive. All the rest are NC or gas items on one-shot operator scripts.

---

# Part 1: `script/helpers/UniPoolerCutoverCore.sol`

# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | Use assembly to check for `address(0)` | 12 |
| [GAS-2](#GAS-2) | Cache array length outside of loop | 5 |
| [GAS-3](#GAS-3) | Use calldata instead of memory for function arguments that do not get mutated | 3 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 30 |
| [GAS-5](#GAS-5) | Use Custom Errors instead of Revert Strings to save Gas | 37 |
| [GAS-6](#GAS-6) | Avoid contract existence checks by using low level calls | 18 |
| [GAS-7](#GAS-7) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 5 |
| [GAS-8](#GAS-8) | Splitting require() statements that use && saves gas | 8 |
| [GAS-9](#GAS-9) | Increments/decrements can be unchecked in for-loops | 5 |
| [GAS-10](#GAS-10) | Use != 0 instead of > 0 for unsigned integer comparison | 13 |
| [GAS-11](#GAS-11) | `internal` functions not called by the contract should be removed | 1 |
### <a name="GAS-1"></a>[GAS-1] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (12)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

268:         require(p.owner != address(0), "UniPoolerCutoverCore: zero owner");

290:             require(p.poolers[i] != address(0), "UniPoolerCutoverCore: zero pooler");

308:             l.sUSDS != address(0) && l.usds != address(0) && l.phUSD != address(0) && l.bPool != address(0)

308:             l.sUSDS != address(0) && l.usds != address(0) && l.phUSD != address(0) && l.bPool != address(0)

309:                 && l.bVault != address(0) && l.factory != address(0),

309:                 && l.bVault != address(0) && l.factory != address(0),

329:         if (pair == address(0)) {

332:         require(pair != address(0), "UniPoolerCutoverCore: no pair");

467:         if (psm_ != address(0)) np.setPSM(psm_);

476:         if (streamer != address(0)) np.setNudgeStreamer(streamer);

514:             bool donationLive = np.batchDonationSize() > 0 && np.batchMinter() != address(0) && np.psm() != address(0);

514:             bool donationLive = np.batchDonationSize() > 0 && np.batchMinter() != address(0) && np.psm() != address(0);

```

### <a name="GAS-2"></a>[GAS-2] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (5)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

289:         for (uint256 i = 0; i < p.poolers.length; i++) {

321:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

400:         for (uint256 i = 0; i < raw.length; i++) {

471:         for (uint256 i = 0; i < p.poolers.length; i++) {

484:         for (uint256 i = 0; i < p.poolers.length; i++) {

```

### <a name="GAS-3"></a>[GAS-3] Use calldata instead of memory for function arguments that do not get mutated
When a function with a `memory` array is called externally, the `abi.decode()` step has to use a for-loop to copy each index of the `calldata` to the `memory` index. Each iteration of this for-loop costs at least 60 gas (i.e. `60 * <mem_array>.length`). Using `calldata` directly bypasses this loop. 

If the array is passed to an `internal` function which passes the array to another internal function where the array is modified and therefore `memory` is used in the `external` call, it's still more gas-efficient to use `calldata` when the `external` function uses modifiers, since the modifiers may prevent the internal functions from being called. Structs have the same overhead as an array of length one. 

 *Saves 60 gas per instance*

*Instances (3)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

69:         uint256[] memory minAmountsOut,

71:         bytes memory userData

74:     function removeLiquidityRecovery(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut)

```

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (30)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

4: import {UniPoolerV2} from "@yield-claim-nft/dispatchers/UniPoolerV2.sol";

5: import {IDispatchHook} from "@yield-claim-nft/interfaces/IDispatchHook.sol";

194:         address owner; // the sender of every call; owns old pooler, hook and NFT minter

195:         address oldPooler; // BalancerPoolerV2 at the index

196:         address mintDebtHook; // BalancerPoolerMintDebtHook

197:         address nftMinter; // NFTMinterV2

198:         uint256 dispatcherIndex; // 4

199:         address uniV2Router; // Router02; its factory() creates/locates the pair

200:         address balancerRouter; // Balancer V3 Router (not exposed by BalancerPoolerV2)

201:         address[] poolers; // the poolers to re-authorize on UniPoolerV2 (must be revoked on old)

203:         uint256[] minAmountsOut; // Balancer pool-token order; every entry > 0

204:         uint256 exitToleranceBps; // max gap of minAmountsOut below the live proportional share

205:         uint256 seedToleranceBps; // addLiquidity amountAMin/amountBMin below the recovered amounts

228:         uint256 bptWithdrawn; // from the old pooler in step 4

229:         uint256 bptExited; // the owner's whole BPT balance in step 5

235:         bool usdsWrapped; // parked USDS wrapped into sUSDS for the new pooler (donation disabled)

282:             p.seedDeadline <= block.timestamp + CUTOVER_MAX_SEED_DEADLINE_WINDOW,

289:         for (uint256 i = 0; i < p.poolers.length; i++) {

315:         require(tokens.length == 2, "UniPoolerCutoverCore: pool not two-token");

321:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

389:         sOut = ICutoverERC20(l.sUSDS).balanceOf(p.owner) - sBefore;

390:         pOut = ICutoverERC20(l.phUSD).balanceOf(p.owner) - pBefore;

400:         for (uint256 i = 0; i < raw.length; i++) {

401:             uint256 share = (raw[i] * bptIn) / supply;

404:                 p.minAmountsOut[i] >= (share * (CUTOVER_MAX_BPS - p.exitToleranceBps)) / CUTOVER_MAX_BPS,

421:         uint256 sMin = (sAmt * (CUTOVER_MAX_BPS - p.seedToleranceBps)) / CUTOVER_MAX_BPS;

422:         uint256 pMin = (pAmt * (CUTOVER_MAX_BPS - p.seedToleranceBps)) / CUTOVER_MAX_BPS;

471:         for (uint256 i = 0; i < p.poolers.length; i++) {

484:         for (uint256 i = 0; i < p.poolers.length; i++) {

523:                     ICutoverERC20(l.usds).balanceOf(p.owner) - ownerBefore == usdsRescued,

```

### <a name="GAS-5"></a>[GAS-5] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (37)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

268:         require(p.owner != address(0), "UniPoolerCutoverCore: zero owner");

269:         require(old.owner() == p.owner, "UniPoolerCutoverCore: owner does not own old pooler");

270:         require(hook.owner() == p.owner, "UniPoolerCutoverCore: owner does not own hook");

271:         require(ICutoverNFTMinter(p.nftMinter).owner() == p.owner, "UniPoolerCutoverCore: owner does not own minter");

280:         require(p.seedDeadline > block.timestamp, "UniPoolerCutoverCore: seed deadline not in future");

287:         require(p.poolers.length > 0, "UniPoolerCutoverCore: no poolers");

290:             require(p.poolers[i] != address(0), "UniPoolerCutoverCore: zero pooler");

291:             require(old.poolerAuthVersion(p.poolers[i]) != av, "UniPoolerCutoverCore: pooler still authorized");

296:         require(d == p.oldPooler, "UniPoolerCutoverCore: index not on old pooler");

297:         require(hook.dispatcher() == p.oldPooler, "UniPoolerCutoverCore: hook not on old pooler");

298:         require(old.hook() == p.mintDebtHook, "UniPoolerCutoverCore: old pooler hook mismatch");

315:         require(tokens.length == 2, "UniPoolerCutoverCore: pool not two-token");

320:         require(p.minAmountsOut.length == tokens.length, "UniPoolerCutoverCore: minAmountsOut length");

322:             require(p.minAmountsOut[i] > 0, "UniPoolerCutoverCore: zero minAmountOut");

332:         require(pair != address(0), "UniPoolerCutoverCore: no pair");

339:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

344:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

354:         require(np.pair() == l.pair && np.owner() == p.owner, "UniPoolerCutoverCore: deploy mismatch");

364:         require(ICutoverERC20(l.bPool).balanceOf(p.oldPooler) == 0, "UniPoolerCutoverCore: BPT left on old pooler");

374:         require(bptIn > 0, "UniPoolerCutoverCore: owner holds no BPT");

388:         require(ICutoverERC20(l.bPool).balanceOf(p.owner) == 0, "UniPoolerCutoverCore: owner BPT not fully exited");

391:         require(sOut > 0 && pOut > 0, "UniPoolerCutoverCore: exit returned nothing");

399:         require(supply > 0, "UniPoolerCutoverCore: zero BPT supply");

402:             require(p.minAmountsOut[i] <= share, "UniPoolerCutoverCore: minAmountOut above share");

412:         require(ok && data.length >= 32, "UniPoolerCutoverCore: totalSupply");

423:         require(sMin > 0 && pMin > 0, "UniPoolerCutoverCore: zero seed minimum");

432:         require(a == sAmt && b == pAmt, "UniPoolerCutoverCore: seed not exact");

433:         require(liquidity > 0, "UniPoolerCutoverCore: no LP minted");

434:         require(ICutoverUniV2Pair(l.pair).balanceOf(l.newPooler) == liquidity, "UniPoolerCutoverCore: LP not on pooler");

438:         require((s0 ? r0 : r1) == sAmt && (s0 ? r1 : r0) == pAmt, "UniPoolerCutoverCore: reserves != seeded amounts");

444:         require(ICutoverMintDebtHook(p.mintDebtHook).mintDebt() == 0, "UniPoolerCutoverCore: mintDebt not zero");

485:             require(np.poolerAuthVersion(p.poolers[i]) == av, "UniPoolerCutoverCore: pooler not authorized");

495:         require(d2 == l.newPooler, "UniPoolerCutoverCore: dispatcher not replaced");

543:         require(old.paused(), "UniPoolerCutoverCore: old pooler not paused");

549:         require(d == l.newPooler, "UniPoolerCutoverCore: index not on new pooler");

550:         require(ICutoverMintDebtHook(p.mintDebtHook).dispatcher() == l.newPooler, "UniPoolerCutoverCore: hook");

559:         require(ICutoverBalancerPooler(p.oldPooler).paused(), "UniPoolerCutoverCore: old pooler live");

```

### <a name="GAS-6"></a>[GAS-6] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (18)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

340:         if (ICutoverERC20(l.sUSDS).balanceOf(l.pair) > 0 || ICutoverERC20(l.phUSD).balanceOf(l.pair) > 0) {

346:             ICutoverERC20(l.sUSDS).balanceOf(l.pair) == 0 && ICutoverERC20(l.phUSD).balanceOf(l.pair) == 0,

360:         bal = ICutoverERC20(l.bPool).balanceOf(p.oldPooler);

364:         require(ICutoverERC20(l.bPool).balanceOf(p.oldPooler) == 0, "UniPoolerCutoverCore: BPT left on old pooler");

373:         bptIn = ICutoverERC20(l.bPool).balanceOf(p.owner);

377:         uint256 sBefore = ICutoverERC20(l.sUSDS).balanceOf(p.owner);

378:         uint256 pBefore = ICutoverERC20(l.phUSD).balanceOf(p.owner);

388:         require(ICutoverERC20(l.bPool).balanceOf(p.owner) == 0, "UniPoolerCutoverCore: owner BPT not fully exited");

389:         sOut = ICutoverERC20(l.sUSDS).balanceOf(p.owner) - sBefore;

390:         pOut = ICutoverERC20(l.phUSD).balanceOf(p.owner) - pBefore;

434:         require(ICutoverUniV2Pair(l.pair).balanceOf(l.newPooler) == liquidity, "UniPoolerCutoverCore: LP not on pooler");

508:         sUSDSRescued = ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler);

511:         usdsRescued = ICutoverERC20(l.usds).balanceOf(p.oldPooler);

520:                 uint256 ownerBefore = ICutoverERC20(l.usds).balanceOf(p.owner);

523:                     ICutoverERC20(l.usds).balanceOf(p.owner) - ownerBefore == usdsRescued,

533:             ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler) == 0 && ICutoverERC20(l.usds).balanceOf(p.oldPooler) == 0,

552:             ICutoverERC20(l.bPool).balanceOf(p.oldPooler) == 0 && ICutoverERC20(l.bPool).balanceOf(p.owner) == 0,

556:             ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler) == 0 && ICutoverERC20(l.usds).balanceOf(p.oldPooler) == 0,

```

### <a name="GAS-7"></a>[GAS-7] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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
File: script/helpers/UniPoolerCutoverCore.sol

289:         for (uint256 i = 0; i < p.poolers.length; i++) {

321:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

400:         for (uint256 i = 0; i < raw.length; i++) {

471:         for (uint256 i = 0; i < p.poolers.length; i++) {

484:         for (uint256 i = 0; i < p.poolers.length; i++) {

```

### <a name="GAS-8"></a>[GAS-8] Splitting require() statements that use && saves gas

*Instances (8)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

339:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

344:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

354:         require(np.pair() == l.pair && np.owner() == p.owner, "UniPoolerCutoverCore: deploy mismatch");

391:         require(sOut > 0 && pOut > 0, "UniPoolerCutoverCore: exit returned nothing");

412:         require(ok && data.length >= 32, "UniPoolerCutoverCore: totalSupply");

423:         require(sMin > 0 && pMin > 0, "UniPoolerCutoverCore: zero seed minimum");

432:         require(a == sAmt && b == pAmt, "UniPoolerCutoverCore: seed not exact");

438:         require((s0 ? r0 : r1) == sAmt && (s0 ? r1 : r0) == pAmt, "UniPoolerCutoverCore: reserves != seeded amounts");

```

### <a name="GAS-9"></a>[GAS-9] Increments/decrements can be unchecked in for-loops
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

*Instances (5)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

289:         for (uint256 i = 0; i < p.poolers.length; i++) {

321:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

400:         for (uint256 i = 0; i < raw.length; i++) {

471:         for (uint256 i = 0; i < p.poolers.length; i++) {

484:         for (uint256 i = 0; i < p.poolers.length; i++) {

```

### <a name="GAS-10"></a>[GAS-10] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (13)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

203:         uint256[] minAmountsOut; // Balancer pool-token order; every entry > 0

287:         require(p.poolers.length > 0, "UniPoolerCutoverCore: no poolers");

322:             require(p.minAmountsOut[i] > 0, "UniPoolerCutoverCore: zero minAmountOut");

340:         if (ICutoverERC20(l.sUSDS).balanceOf(l.pair) > 0 || ICutoverERC20(l.phUSD).balanceOf(l.pair) > 0) {

361:         if (bal > 0) {

374:         require(bptIn > 0, "UniPoolerCutoverCore: owner holds no BPT");

391:         require(sOut > 0 && pOut > 0, "UniPoolerCutoverCore: exit returned nothing");

399:         require(supply > 0, "UniPoolerCutoverCore: zero BPT supply");

423:         require(sMin > 0 && pMin > 0, "UniPoolerCutoverCore: zero seed minimum");

433:         require(liquidity > 0, "UniPoolerCutoverCore: no LP minted");

509:         if (sUSDSRescued > 0) old.rescueERC20(l.sUSDS, l.newPooler, sUSDSRescued);

512:         if (usdsRescued > 0) {

514:             bool donationLive = np.batchDonationSize() > 0 && np.batchMinter() != address(0) && np.psm() != address(0);

```

### <a name="GAS-11"></a>[GAS-11] `internal` functions not called by the contract should be removed
If the functions are required by an interface, the contract should inherit from that interface and use the `override` keyword

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

242:     function _runCutover(CutoverParams memory p) internal returns (CutoverResult memory r) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 1 |
| [NC-2](#NC-2) | Array indices should be referenced via `enum`s rather than via numeric literals | 1 |
| [NC-3](#NC-3) | `constant`s should be defined rather than using magic numbers | 2 |
| [NC-4](#NC-4) | Control structures do not follow the Solidity Style Guide | 4 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 2 |
| [NC-6](#NC-6) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-7](#NC-7) | Functions should not be longer than 50 lines | 40 |
| [NC-8](#NC-8) | Interfaces should be defined in separate files from their usage | 10 |
| [NC-9](#NC-9) | Lack of checks in setters | 2 |
| [NC-10](#NC-10) | Missing Event for critical parameters change | 2 |
| [NC-11](#NC-11) | NatSpec is completely non-existent on functions that should have them | 14 |
| [NC-12](#NC-12) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-13](#NC-13) | Variables need not be initialized to zero | 5 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

411:         (bool ok, bytes memory data) = token.staticcall(abi.encodeWithSignature("totalSupply()"));

```

### <a name="NC-2"></a>[NC-2] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

317:             (tokens[0] == l.sUSDS && tokens[1] == l.phUSD) || (tokens[0] == l.phUSD && tokens[1] == l.sUSDS),

```

### <a name="NC-3"></a>[NC-3] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

315:         require(tokens.length == 2, "UniPoolerCutoverCore: pool not two-token");

412:         require(ok && data.length >= 32, "UniPoolerCutoverCore: totalSupply");

```

### <a name="NC-4"></a>[NC-4] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (4)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

467:         if (psm_ != address(0)) np.setPSM(psm_);

476:         if (streamer != address(0)) np.setNudgeStreamer(streamer);

509:         if (sUSDSRescued > 0) old.rescueERC20(l.sUSDS, l.newPooler, sUSDSRescued);

542:         if (!old.paused()) old.pause();

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

339:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

344:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

```

### <a name="NC-6"></a>[NC-6] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

1: 
   Current order:
   external removeLiquidityProportional
   external removeLiquidityRecovery
   external getPoolTokenInfo
   external owner
   external sUSDS
   external primeToken
   external pool
   external vault
   external hook
   external paused
   external authVersion
   external poolerAuthVersion
   external psm
   external maxTout
   external batchMinter
   external nudgeStreamer
   external batchDonationSize
   external withdrawBPT
   external rescueERC20
   external setMinter
   external pause
   external owner
   external dispatcher
   external phUSD
   external mintDebt
   external pull
   external setDispatcher
   external owner
   external configs
   external replaceDispatcher
   external factory
   external addLiquidity
   external getPair
   external createPair
   external token0
   external getReserves
   external balanceOf
   external skim
   external balanceOf
   external approve
   external deposit
   internal _runCutover
   internal _step0Preconditions
   internal _step1CreatePair
   internal _step2EnsurePairEmpty
   internal _step3DeployPooler
   internal _step4WithdrawBPT
   internal _step5ExitBalancer
   internal _checkMinAmountsOut
   private _totalSupply
   internal _step6SeedPair
   internal _step7PullDebt
   internal _step8RepointHook
   internal _step9ConfigurePooler
   internal _step10ReplaceDispatcher
   internal _step11MoveBalances
   internal _step12RetireOld
   internal _assertRetired
   
   Suggested order:
   external removeLiquidityProportional
   external removeLiquidityRecovery
   external getPoolTokenInfo
   external owner
   external sUSDS
   external primeToken
   external pool
   external vault
   external hook
   external paused
   external authVersion
   external poolerAuthVersion
   external psm
   external maxTout
   external batchMinter
   external nudgeStreamer
   external batchDonationSize
   external withdrawBPT
   external rescueERC20
   external setMinter
   external pause
   external owner
   external dispatcher
   external phUSD
   external mintDebt
   external pull
   external setDispatcher
   external owner
   external configs
   external replaceDispatcher
   external factory
   external addLiquidity
   external getPair
   external createPair
   external token0
   external getReserves
   external balanceOf
   external skim
   external balanceOf
   external approve
   external deposit
   internal _runCutover
   internal _step0Preconditions
   internal _step1CreatePair
   internal _step2EnsurePairEmpty
   internal _step3DeployPooler
   internal _step4WithdrawBPT
   internal _step5ExitBalancer
   internal _checkMinAmountsOut
   internal _step6SeedPair
   internal _step7PullDebt
   internal _step8RepointHook
   internal _step9ConfigurePooler
   internal _step10ReplaceDispatcher
   internal _step11MoveBalances
   internal _step12RetireOld
   internal _assertRetired
   private _totalSupply

```

### <a name="NC-7"></a>[NC-7] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (40)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

74:     function removeLiquidityRecovery(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut)

104:     function primeToken() external view returns (address);

109:     function authVersion() external view returns (uint256);

110:     function poolerAuthVersion(address pooler) external view returns (uint256);

112:     function maxTout() external view returns (uint256);

113:     function batchMinter() external view returns (address);

114:     function nudgeStreamer() external view returns (address);

115:     function batchDonationSize() external view returns (uint256);

116:     function withdrawBPT(address recipient, uint256 amount) external;

117:     function rescueERC20(address token, address to, uint256 amount) external;

125:     function dispatcher() external view returns (address);

127:     function mintDebt() external view returns (uint256);

129:     function setDispatcher(address newDispatcher) external;

139:     function replaceDispatcher(uint256 index, address newDispatcher) external;

143:     function factory() external view returns (address);

157:     function getPair(address tokenA, address tokenB) external view returns (address pair);

158:     function createPair(address tokenA, address tokenB) external returns (address pair);

162:     function token0() external view returns (address);

163:     function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

164:     function balanceOf(address account) external view returns (uint256);

169:     function balanceOf(address account) external view returns (uint256);

170:     function approve(address spender, uint256 amount) external returns (bool);

174:     function deposit(uint256 assets, address receiver) external returns (uint256 shares);

242:     function _runCutover(CutoverParams memory p) internal returns (CutoverResult memory r) {

264:     function _step0Preconditions(CutoverParams memory p) internal view returns (CutoverLive memory l) {

327:     function _step1CreatePair(CutoverLive memory l) internal returns (address pair) {

336:     function _step2EnsurePairEmpty(CutoverParams memory p, CutoverLive memory l) internal {

352:     function _step3DeployPooler(CutoverParams memory p, CutoverLive memory l) internal returns (address) {

359:     function _step4WithdrawBPT(CutoverParams memory p, CutoverLive memory l) internal returns (uint256 bal) {

369:     function _step5ExitBalancer(CutoverParams memory p, CutoverLive memory l)

396:     function _checkMinAmountsOut(CutoverParams memory p, CutoverLive memory l, uint256 bptIn) internal view {

410:     function _totalSupply(address token) private view returns (uint256 s) {

417:     function _step6SeedPair(CutoverParams memory p, CutoverLive memory l, uint256 sAmt, uint256 pAmt)

442:     function _step7PullDebt(CutoverParams memory p) internal {

448:     function _step8RepointHook(CutoverParams memory p, CutoverLive memory l) internal {

460:     function _step9ConfigurePooler(CutoverParams memory p, CutoverLive memory l) internal {

490:     function _step10ReplaceDispatcher(CutoverParams memory p, CutoverLive memory l) internal {

502:     function _step11MoveBalances(CutoverParams memory p, CutoverLive memory l)

539:     function _step12RetireOld(CutoverParams memory p) internal {

547:     function _assertRetired(CutoverParams memory p, CutoverLive memory l) internal view {

```

### <a name="NC-8"></a>[NC-8] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (10)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

65: interface IBalancerV3RouterExit {

81: interface IBalancerV3VaultViews {

101: interface ICutoverBalancerPooler {

123: interface ICutoverMintDebtHook {

133: interface ICutoverNFTMinter {

142: interface ICutoverUniV2Router {

156: interface ICutoverUniV2Factory {

161: interface ICutoverUniV2Pair {

168: interface ICutoverERC20 {

173: interface ICutoverERC4626 {

```

### <a name="NC-9"></a>[NC-9] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

118:     function setMinter(address minter_) external;

129:     function setDispatcher(address newDispatcher) external;

```

### <a name="NC-10"></a>[NC-10] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

118:     function setMinter(address minter_) external;

129:     function setDispatcher(address newDispatcher) external;

```

### <a name="NC-11"></a>[NC-11] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (14)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

66:     function removeLiquidityProportional(

74:     function removeLiquidityRecovery(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut)

116:     function withdrawBPT(address recipient, uint256 amount) external;

117:     function rescueERC20(address token, address to, uint256 amount) external;

118:     function setMinter(address minter_) external;

119:     function pause() external;

128:     function pull() external;

129:     function setDispatcher(address newDispatcher) external;

139:     function replaceDispatcher(uint256 index, address newDispatcher) external;

144:     function addLiquidity(

158:     function createPair(address tokenA, address tokenB) external returns (address pair);

165:     function skim(address to) external;

170:     function approve(address spender, uint256 amount) external returns (bool);

174:     function deposit(uint256 assets, address receiver) external returns (uint256 shares);

```

### <a name="NC-12"></a>[NC-12] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

1: 
   Current order:
   FunctionDefinition.removeLiquidityProportional
   FunctionDefinition.removeLiquidityRecovery
   StructDefinition.TokenInfo
   FunctionDefinition.getPoolTokenInfo
   FunctionDefinition.owner
   FunctionDefinition.sUSDS
   FunctionDefinition.primeToken
   FunctionDefinition.pool
   FunctionDefinition.vault
   FunctionDefinition.hook
   FunctionDefinition.paused
   FunctionDefinition.authVersion
   FunctionDefinition.poolerAuthVersion
   FunctionDefinition.psm
   FunctionDefinition.maxTout
   FunctionDefinition.batchMinter
   FunctionDefinition.nudgeStreamer
   FunctionDefinition.batchDonationSize
   FunctionDefinition.withdrawBPT
   FunctionDefinition.rescueERC20
   FunctionDefinition.setMinter
   FunctionDefinition.pause
   FunctionDefinition.owner
   FunctionDefinition.dispatcher
   FunctionDefinition.phUSD
   FunctionDefinition.mintDebt
   FunctionDefinition.pull
   FunctionDefinition.setDispatcher
   FunctionDefinition.owner
   FunctionDefinition.configs
   FunctionDefinition.replaceDispatcher
   FunctionDefinition.factory
   FunctionDefinition.addLiquidity
   FunctionDefinition.getPair
   FunctionDefinition.createPair
   FunctionDefinition.token0
   FunctionDefinition.getReserves
   FunctionDefinition.balanceOf
   FunctionDefinition.skim
   FunctionDefinition.balanceOf
   FunctionDefinition.approve
   FunctionDefinition.deposit
   VariableDeclaration.CUTOVER_MAX_BPS
   VariableDeclaration.CUTOVER_MAX_TOLERANCE_BPS
   VariableDeclaration.CUTOVER_MAX_SEED_DEADLINE_WINDOW
   EnumDefinition.ExitMode
   StructDefinition.CutoverParams
   StructDefinition.CutoverLive
   StructDefinition.CutoverResult
   FunctionDefinition._runCutover
   FunctionDefinition._step0Preconditions
   FunctionDefinition._step1CreatePair
   FunctionDefinition._step2EnsurePairEmpty
   FunctionDefinition._step3DeployPooler
   FunctionDefinition._step4WithdrawBPT
   FunctionDefinition._step5ExitBalancer
   FunctionDefinition._checkMinAmountsOut
   FunctionDefinition._totalSupply
   FunctionDefinition._step6SeedPair
   FunctionDefinition._step7PullDebt
   FunctionDefinition._step8RepointHook
   FunctionDefinition._step9ConfigurePooler
   FunctionDefinition._step10ReplaceDispatcher
   FunctionDefinition._step11MoveBalances
   FunctionDefinition._step12RetireOld
   FunctionDefinition._assertRetired
   
   Suggested order:
   VariableDeclaration.CUTOVER_MAX_BPS
   VariableDeclaration.CUTOVER_MAX_TOLERANCE_BPS
   VariableDeclaration.CUTOVER_MAX_SEED_DEADLINE_WINDOW
   EnumDefinition.ExitMode
   StructDefinition.TokenInfo
   StructDefinition.CutoverParams
   StructDefinition.CutoverLive
   StructDefinition.CutoverResult
   FunctionDefinition.removeLiquidityProportional
   FunctionDefinition.removeLiquidityRecovery
   FunctionDefinition.getPoolTokenInfo
   FunctionDefinition.owner
   FunctionDefinition.sUSDS
   FunctionDefinition.primeToken
   FunctionDefinition.pool
   FunctionDefinition.vault
   FunctionDefinition.hook
   FunctionDefinition.paused
   FunctionDefinition.authVersion
   FunctionDefinition.poolerAuthVersion
   FunctionDefinition.psm
   FunctionDefinition.maxTout
   FunctionDefinition.batchMinter
   FunctionDefinition.nudgeStreamer
   FunctionDefinition.batchDonationSize
   FunctionDefinition.withdrawBPT
   FunctionDefinition.rescueERC20
   FunctionDefinition.setMinter
   FunctionDefinition.pause
   FunctionDefinition.owner
   FunctionDefinition.dispatcher
   FunctionDefinition.phUSD
   FunctionDefinition.mintDebt
   FunctionDefinition.pull
   FunctionDefinition.setDispatcher
   FunctionDefinition.owner
   FunctionDefinition.configs
   FunctionDefinition.replaceDispatcher
   FunctionDefinition.factory
   FunctionDefinition.addLiquidity
   FunctionDefinition.getPair
   FunctionDefinition.createPair
   FunctionDefinition.token0
   FunctionDefinition.getReserves
   FunctionDefinition.balanceOf
   FunctionDefinition.skim
   FunctionDefinition.balanceOf
   FunctionDefinition.approve
   FunctionDefinition.deposit
   FunctionDefinition._runCutover
   FunctionDefinition._step0Preconditions
   FunctionDefinition._step1CreatePair
   FunctionDefinition._step2EnsurePairEmpty
   FunctionDefinition._step3DeployPooler
   FunctionDefinition._step4WithdrawBPT
   FunctionDefinition._step5ExitBalancer
   FunctionDefinition._checkMinAmountsOut
   FunctionDefinition._totalSupply
   FunctionDefinition._step6SeedPair
   FunctionDefinition._step7PullDebt
   FunctionDefinition._step8RepointHook
   FunctionDefinition._step9ConfigurePooler
   FunctionDefinition._step10ReplaceDispatcher
   FunctionDefinition._step11MoveBalances
   FunctionDefinition._step12RetireOld
   FunctionDefinition._assertRetired

```

### <a name="NC-13"></a>[NC-13] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (5)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

289:         for (uint256 i = 0; i < p.poolers.length; i++) {

321:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

400:         for (uint256 i = 0; i < raw.length; i++) {

471:         for (uint256 i = 0; i < p.poolers.length; i++) {

484:         for (uint256 i = 0; i < p.poolers.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 4 |
| [L-2](#L-2) | Deprecated approve() function | 4 |
| [L-3](#L-3) | Division by zero not prevented | 1 |
| [L-4](#L-4) | Signature use at deadlines should be allowed | 2 |
| [L-5](#L-5) | Possible rounding issue | 1 |
| [L-6](#L-6) | Loss of precision | 3 |
| [L-7](#L-7) | Sweeping may break accounting if tokens with multiple addresses are used | 4 |
| [L-8](#L-8) | Unsafe ERC20 operation(s) | 4 |
### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (4)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

380:         ICutoverERC20(l.bPool).approve(p.balancerRouter, bptIn);

425:         ICutoverERC20(l.sUSDS).approve(p.uniV2Router, sAmt);

426:         ICutoverERC20(l.phUSD).approve(p.uniV2Router, pAmt);

526:                 ICutoverERC20(l.usds).approve(l.sUSDS, usdsRescued);

```

### <a name="L-2"></a>[L-2] Deprecated approve() function
Due to the inheritance of ERC20's approve function, there's a vulnerability to the ERC20 approve and double spend front running attack. Briefly, an authorized spender could spend both allowances by front running an allowance-changing transaction. Consider implementing OpenZeppelin's `.safeApprove()` function to help mitigate this.

*Instances (4)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

380:         ICutoverERC20(l.bPool).approve(p.balancerRouter, bptIn);

425:         ICutoverERC20(l.sUSDS).approve(p.uniV2Router, sAmt);

426:         ICutoverERC20(l.phUSD).approve(p.uniV2Router, pAmt);

526:                 ICutoverERC20(l.usds).approve(l.sUSDS, usdsRescued);

```

### <a name="L-3"></a>[L-3] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

401:             uint256 share = (raw[i] * bptIn) / supply;

```

### <a name="L-4"></a>[L-4] Signature use at deadlines should be allowed
According to [EIP-2612](https://github.com/ethereum/EIPs/blob/71dc97318013bf2ac572ab63fab530ac9ef419ca/EIPS/eip-2612.md?plain=1#L58), signatures used on exactly the deadline timestamp are supposed to be allowed. While the signature may or may not be used for the exact EIP-2612 use case (transfer approvals), for consistency's sake, all deadlines should follow this semantic. If the timestamp is an expiration rather than a deadline, consider whether it makes more sense to include the expiration timestamp as a valid timestamp, as is done for deadlines.

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

280:         require(p.seedDeadline > block.timestamp, "UniPoolerCutoverCore: seed deadline not in future");

282:             p.seedDeadline <= block.timestamp + CUTOVER_MAX_SEED_DEADLINE_WINDOW,

```

### <a name="L-5"></a>[L-5] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

401:             uint256 share = (raw[i] * bptIn) / supply;

```

### <a name="L-6"></a>[L-6] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (3)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

404:                 p.minAmountsOut[i] >= (share * (CUTOVER_MAX_BPS - p.exitToleranceBps)) / CUTOVER_MAX_BPS,

421:         uint256 sMin = (sAmt * (CUTOVER_MAX_BPS - p.seedToleranceBps)) / CUTOVER_MAX_BPS;

422:         uint256 pMin = (pAmt * (CUTOVER_MAX_BPS - p.seedToleranceBps)) / CUTOVER_MAX_BPS;

```

### <a name="L-7"></a>[L-7] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (4)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

117:     function rescueERC20(address token, address to, uint256 amount) external;

509:         if (sUSDSRescued > 0) old.rescueERC20(l.sUSDS, l.newPooler, sUSDSRescued);

517:                 old.rescueERC20(l.usds, l.newPooler, usdsRescued);

521:                 old.rescueERC20(l.usds, p.owner, usdsRescued);

```

### <a name="L-8"></a>[L-8] Unsafe ERC20 operation(s)

*Instances (4)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

380:         ICutoverERC20(l.bPool).approve(p.balancerRouter, bptIn);

425:         ICutoverERC20(l.sUSDS).approve(p.uniV2Router, sAmt);

426:         ICutoverERC20(l.phUSD).approve(p.uniV2Router, pAmt);

526:                 ICutoverERC20(l.usds).approve(l.sUSDS, usdsRescued);

```



---

# Part 2: `script/helpers/UniswapV2Deployer.sol`

# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | For Operations that will not overflow, you could use unchecked | 4 |
| [GAS-2](#GAS-2) | `internal` functions not called by the contract should be removed | 1 |
### <a name="GAS-1"></a>[GAS-1] For Operations that will not overflow, you could use unchecked

*Instances (4)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

4: import {Vm} from "@forge-std/Vm.sol";

62:         weth9 = vm.deployCode("script/uniswap-artifacts/WETH9.json");

63:         address factoryAddr = vm.deployCode("script/uniswap-artifacts/UniswapV2Factory.json", abi.encode(feeToSetter));

65:             vm.deployCode("script/uniswap-artifacts/UniswapV2Router02.json", abi.encode(factoryAddr, weth9));

```

### <a name="GAS-2"></a>[GAS-2] `internal` functions not called by the contract should be removed
If the functions are required by an interface, the contract should inherit from that interface and use the `override` keyword

*Instances (1)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

58:     function deploy(address feeToSetter)

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Constants should be in CONSTANT_CASE | 1 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 3 |
| [NC-3](#NC-3) | Functions should not be longer than 50 lines | 6 |
| [NC-4](#NC-4) | Interfaces should be defined in separate files from their usage | 3 |
| [NC-5](#NC-5) | NatSpec is completely non-existent on functions that should have them | 5 |
| [NC-6](#NC-6) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-7](#NC-7) | Internal and private variables and functions names should begin with an underscore | 1 |
### <a name="NC-1"></a>[NC-1] Constants should be in CONSTANT_CASE
For `constant` variable names, each word should use all capital letters, with underscores separating each word (CONSTANT_CASE)

*Instances (1)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

55:     Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

```

### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (3)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

62:         weth9 = vm.deployCode("script/uniswap-artifacts/WETH9.json");

63:         address factoryAddr = vm.deployCode("script/uniswap-artifacts/UniswapV2Factory.json", abi.encode(feeToSetter));

65:             vm.deployCode("script/uniswap-artifacts/UniswapV2Router02.json", abi.encode(factoryAddr, weth9));

```

### <a name="NC-3"></a>[NC-3] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (6)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

8:     function createPair(address tokenA, address tokenB) external returns (address pair);

9:     function getPair(address tokenA, address tokenB) external view returns (address pair);

10:     function feeToSetter() external view returns (address);

15:     function factory() external view returns (address);

41:     function approve(address spender, uint256 amount) external returns (bool);

42:     function balanceOf(address account) external view returns (uint256);

```

### <a name="NC-4"></a>[NC-4] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (3)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

7: interface IUniswapV2FactoryLike {

14: interface IUniswapV2RouterLike {

39: interface IWETH9Like {

```

### <a name="NC-5"></a>[NC-5] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (5)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

8:     function createPair(address tokenA, address tokenB) external returns (address pair);

18:     function addLiquidity(

29:     function swapExactTokensForTokens(

40:     function deposit() external payable;

41:     function approve(address spender, uint256 amount) external returns (bool);

```

### <a name="NC-6"></a>[NC-6] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

1: 
   Current order:
   FunctionDefinition.createPair
   FunctionDefinition.getPair
   FunctionDefinition.feeToSetter
   FunctionDefinition.factory
   FunctionDefinition.WETH
   FunctionDefinition.addLiquidity
   FunctionDefinition.swapExactTokensForTokens
   FunctionDefinition.deposit
   FunctionDefinition.approve
   FunctionDefinition.balanceOf
   VariableDeclaration.vm
   FunctionDefinition.deploy
   
   Suggested order:
   VariableDeclaration.vm
   FunctionDefinition.createPair
   FunctionDefinition.getPair
   FunctionDefinition.feeToSetter
   FunctionDefinition.factory
   FunctionDefinition.WETH
   FunctionDefinition.addLiquidity
   FunctionDefinition.swapExactTokensForTokens
   FunctionDefinition.deposit
   FunctionDefinition.approve
   FunctionDefinition.balanceOf
   FunctionDefinition.deploy

```

### <a name="NC-7"></a>[NC-7] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (1)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

58:     function deploy(address feeToSetter)

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Library function isn't `internal` or `private` | 10 |
### <a name="M-1"></a>[M-1] Library function isn't `internal` or `private`
In a library, using an external or public visibility means that we won't be going through the library with a DELEGATECALL but with a CALL. This changes the context and should be done carefully.

*Instances (10)*:
```solidity
File: script/helpers/UniswapV2Deployer.sol

8:     function createPair(address tokenA, address tokenB) external returns (address pair);

9:     function getPair(address tokenA, address tokenB) external view returns (address pair);

10:     function feeToSetter() external view returns (address);

15:     function factory() external view returns (address);

16:     function WETH() external view returns (address);

18:     function addLiquidity(

29:     function swapExactTokensForTokens(

40:     function deposit() external payable;

41:     function approve(address spender, uint256 amount) external returns (bool);

42:     function balanceOf(address account) external view returns (uint256);

```

