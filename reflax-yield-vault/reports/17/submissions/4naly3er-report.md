<!-- 4naly3er automated QA/gas report — attachment to qa-report.md (run reflax-yield-vault-17) -->
# 4naly3er automated report — reflax-yield-vault @ `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9`

**Generated:** 2026-09-01 · **Tool:** `tools/4naly3er` (`yarn analyze`, solc 0.8.27 bindings)

**Command (run from `/home/justin/code/audits/tools/4naly3er`):**

```bash
yarn analyze /home/justin/code/audits/workspace/reflax-yield-vault \
             <scope>.txt \
             https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9
```

Argument 3 is a **scope list**, not a remappings file. `basePath` is the repo root so that
`remappings.txt` resolves; the run used the `workspace/` clone (at the same commit `cdd0743`,
tracked tree clean) because the `pauser/=lib/mutable/pauser/src/` remapping lives only in
`foundry.toml` and had to be added to `remappings.txt` — a write `lib/` does not permit.
`remappings.txt` was restored afterwards.

**Scope: all 7 in-scope files were submitted and compiled.** 6 produced instances and appear
below; `src/AMMAdapters/ICurveRouterNG.sol` compiled with zero instances (a bare interface).
File names such as `src/contracts/FraxlendPair.sol` and `lib/TokenTransferrer.sol` that appear
in the prose below are 4naly3er's own boilerplate examples, **not** files from this repo.

**Known cosmetic defect in the tool's output:** the `[Link to code]` URLs below are missing the
`/` between the commit SHA and the file path (`…f2f47d6d9src/…`). Read the `File:` header above
each snippet as the authoritative path.

Triage of every item against the 16 filed findings is in `qa-report.md`
(§ *Automated analysis — 4naly3er*). Nothing here was suppressed.

---

# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 8 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 23 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 1 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 4 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 3 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 98 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 56 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 14 |
| [GAS-9](#GAS-9) | Stack variable used as a cheaper cache for a state variable is only used once | 3 |
| [GAS-10](#GAS-10) | State variables only set in the constructor should be declared `immutable` | 5 |
| [GAS-11](#GAS-11) | Functions guaranteed to revert when called by normal users can be marked `payable` | 12 |
| [GAS-12](#GAS-12) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 6 |
| [GAS-13](#GAS-13) | Using `private` rather than `public` for constants, saves gas | 4 |
| [GAS-14](#GAS-14) | Use of `this` instead of marking as `public` an `external` function | 2 |
| [GAS-15](#GAS-15) | Increments/decrements can be unchecked in for-loops | 5 |
| [GAS-16](#GAS-16) | Use != 0 instead of > 0 for unsigned integer comparison | 19 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (8)*:
```solidity
File: src/AYieldStrategy.sol

744:         clientBalances[token][recipient] += creditedPrincipal;

745:         totalDeposited[token] += creditedPrincipal;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

409:             totalShares += shares;

412:             totalBufferShares += shares;

440:             totalSetAside += buf;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

288:             totalShares += shares;

291:             totalBufferShares += shares;

319:             totalSetAside += buf;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (23)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

49:         require(_router != address(0), "CurveAMMAdapter: router cannot be zero");

69:         require(tokenIn != address(0), "CurveAMMAdapter: tokenIn cannot be zero");

70:         require(tokenOut != address(0), "CurveAMMAdapter: tokenOut cannot be zero");

76:             if (path[i] != address(0)) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

251:         require(_owner != address(0), "AYieldStrategy: owner cannot be zero address");

252:         require(_underlyingToken != address(0), "AYieldStrategy: underlying token cannot be zero address");

266:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

310:         require(withdrawer != address(0), "AYieldStrategy: withdrawer cannot be zero address");

336:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

353:         require(_recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

418:         require(token != address(0), "AYieldStrategy: token cannot be zero address");

419:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

468:         require(token != address(0), "AYieldStrategy: token cannot be zero address");

469:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

735:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

768:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

64:         require(_erc4626Vault != address(0), "ERC4626MarketYieldStrategy: vault cannot be zero address");

65:         require(_ammAdapter != address(0), "ERC4626MarketYieldStrategy: AMM adapter cannot be zero address");

369:         require(setAsideBufferRecipient != address(0), "AYieldStrategy: setAsideBufferRecipient not set");

398:             require(client != address(0), "ERC4626MarketYieldStrategy: client cannot be zero address");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

46:         require(_erc4626Vault != address(0), "ERC4626YieldStrategy: vault cannot be zero address");

247:         require(setAsideBufferRecipient != address(0), "AYieldStrategy: setAsideBufferRecipient not set");

277:             require(client != address(0), "ERC4626YieldStrategy: client cannot be zero address");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

32:     mapping(address => bool) public authorizedWithdrawers;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (4)*:
```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

396:         for (uint256 i = 0; i < clients.length; i++) {

436:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

275:         for (uint256 i = 0; i < clients.length; i++) {

315:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (3)*:
```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

252:         uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);

309:             uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);

359:         underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (98)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

4: import "./IAMMAdapter.sol";

5: import "./ICurveRouterNG.sol";

6: import "@openzeppelin/contracts/access/Ownable.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

25:         address[11] path; // Interleaved token/pool addresses for Curve Router NG

26:         uint256[5][5] swapParams; // Per-hop [i, j, swap_type, pool_type, n_coins]

27:         address[5] pools; // Optional base pools for meta-swaps

28:         bool configured; // Distinguishes "unset" from "all zeros"

75:         for (uint256 i = 0; i < 11; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

4: import "./interfaces/IYieldStrategy.sol";

5: import "pauser/interfaces/IPausable.sol";

6: import "@openzeppelin/contracts/access/Ownable.sol";

7: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

9: import "@openzeppelin/contracts/utils/Pausable.sol";

10: import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

67:         None, // No withdrawal initiated

68:         Initiated, // Withdrawal initiated, in 6-hour waiting period

69:         Executable, // Past waiting period, within 72-hour execution window

70:         Expired // Past execution window, state reset needed

75:         uint256 initiatedAt; // Timestamp when withdrawal was initiated

76:         WithdrawalStatus status; // Current status of the withdrawal

77:         uint256 balance; // Cached balance at initiation time

84:     uint256 public constant WAITING_PERIOD = 6 hours; // Phase 1 duration

85:     uint256 public constant EXECUTION_WINDOW = 72 hours; // Phase 2 duration

86:     uint256 public constant TOTAL_DURATION = WAITING_PERIOD + EXECUTION_WINDOW; // 78 hours total

269:             _authorizedClients.add(client); // idempotent — no duplicates possible

435:             uint256 executableAt = state.initiatedAt + WAITING_PERIOD;

549:         return (totalValue * principal) / totalDeposited[token];

712:         clientBalances[token][balanceHolder] -= amount;

713:         totalDeposited[token] -= amount;

744:         clientBalances[token][recipient] += creditedPrincipal;

745:         totalDeposited[token] += creditedPrincipal;

781:         clientBalances[token][balanceHolder] -= amount;

782:         totalDeposited[token] -= amount;

834:             if (currentTime >= state.initiatedAt + WAITING_PERIOD) {

835:                 if (currentTime <= state.initiatedAt + TOTAL_DURATION) {

842:             if (currentTime > state.initiatedAt + TOTAL_DURATION) {

867:         uint256 executableAt = currentTime + WAITING_PERIOD;

907:             digits++;

908:             temp /= 10;

912:             digits -= 1;

913:             buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));

914:             value /= 10;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

4: import "../AYieldStrategy.sol";

5: import "../AMMAdapters/IAMMAdapter.sol";

6: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

7: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

8: import "@openzeppelin/contracts/utils/math/Math.sol";

9: import "@openzeppelin/contracts/interfaces/IERC4626.sol";

108:         return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

134:         return idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

170:         uint256 denominator = MAX_BPS - slippageToleranceBps;

176:         grossToRequest = Math.ceilDiv(netWanted * MAX_BPS, denominator);

246:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

294:             return; // Nothing to withdraw

298:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

303:             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

313:             totalDeposited[token] -= clientStoredBalance;

340:         uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

346:         uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;

354:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

396:         for (uint256 i = 0; i < clients.length; i++) {

403:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

405:                 surplus = total - principal;

408:             uint256 shares = vault.convertToShares(surplus); // per-client floor (protocol-favoring)

409:             totalShares += shares;

410:             shares = shares * setAsideBufferSize[client] / 100; // reuse slot: now buffer shares (0–100)

412:             totalBufferShares += shares;

436:         for (uint256 i = 0; i < clients.length; i++) {

438:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

440:             totalSetAside += buf;

444:         toRecipient = underlyingReceived - totalSetAside; // dust (rounding) favors recipient

446:         return toRecipient; // RETURN VALUE REDUCED by totalSetAside

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

4: import "../AYieldStrategy.sol";

5: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import "@openzeppelin/contracts/interfaces/IERC4626.sol";

186:             return; // Nothing to withdraw

190:         uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

198:             totalDeposited[token] -= clientStoredBalance;

224:         uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

230:         uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;

241:             underlyingReceived = vault.redeem(totalShares, recipient, address(this)); // SINGLE redeem

251:         underlyingReceived = vault.redeem(totalShares, address(this), address(this)); // SINGLE redeem

275:         for (uint256 i = 0; i < clients.length; i++) {

282:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

284:                 surplus = total - principal;

287:             uint256 shares = vault.convertToShares(surplus); // per-client floor (protocol-favoring)

288:             totalShares += shares;

289:             shares = shares * setAsideBufferSize[client] / 100; // reuse slot: now buffer shares (0–100)

291:             totalBufferShares += shares;

315:         for (uint256 i = 0; i < clients.length; i++) {

317:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

319:             totalSetAside += buf;

323:         toRecipient = underlyingReceived - totalSetAside; // dust (rounding) favors recipient

325:         return toRecipient; // RETURN VALUE REDUCED by totalSetAside

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (56)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

49:         require(_router != address(0), "CurveAMMAdapter: router cannot be zero");

69:         require(tokenIn != address(0), "CurveAMMAdapter: tokenIn cannot be zero");

70:         require(tokenOut != address(0), "CurveAMMAdapter: tokenOut cannot be zero");

71:         require(path[0] == tokenIn, "CurveAMMAdapter: path[0] must equal tokenIn");

80:         require(lastToken == tokenOut, "CurveAMMAdapter: path must end at tokenOut");

126:         require(r.configured, "CurveAMMAdapter: route not configured");

128:         require(routes[tokenOut][tokenIn].configured, "CurveAMMAdapter: reverse direction not configured");

129:         require(amountIn > 0, "CurveAMMAdapter: amountIn must be > 0");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

219:         require(_authorizedClients.contains(msg.sender), "AYieldStrategy: unauthorized, only authorized clients");

228:         require(authorizedWithdrawers[msg.sender], "AYieldStrategy: unauthorized, only authorized withdrawers");

237:         require(msg.sender == _pauser, "AYieldStrategy: caller is not the pauser");

251:         require(_owner != address(0), "AYieldStrategy: owner cannot be zero address");

252:         require(_underlyingToken != address(0), "AYieldStrategy: underlying token cannot be zero address");

266:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

310:         require(withdrawer != address(0), "AYieldStrategy: withdrawer cannot be zero address");

336:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

337:         require(bufferPercent <= 100, "AYieldStrategy: buffer percent exceeds 100");

353:         require(_recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

393:         require(msg.sender == owner() || msg.sender == _pauser, "AYieldStrategy: caller is not the owner or pauser");

403:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

418:         require(token != address(0), "AYieldStrategy: token cannot be zero address");

419:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

468:         require(token != address(0), "AYieldStrategy: token cannot be zero address");

469:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

524:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

537:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

578:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

701:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

702:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

709:         require(amount > 0, "AYieldStrategy: no principal to relinquish");

733:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

734:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

735:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

766:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

767:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

768:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

860:         require(balance > 0, "AYieldStrategy: no balance to withdraw");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

64:         require(_erc4626Vault != address(0), "ERC4626MarketYieldStrategy: vault cannot be zero address");

65:         require(_ammAdapter != address(0), "ERC4626MarketYieldStrategy: AMM adapter cannot be zero address");

90:         require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");

168:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

224:         require(sharesReceived > 0, "ERC4626MarketYieldStrategy: no shares received");

271:         require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

288:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

289:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

337:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

369:         require(setAsideBufferRecipient != address(0), "AYieldStrategy: setAsideBufferRecipient not set");

398:             require(client != address(0), "ERC4626MarketYieldStrategy: client cannot be zero address");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

46:         require(_erc4626Vault != address(0), "ERC4626YieldStrategy: vault cannot be zero address");

108:         require(sharesReceived > 0, "ERC4626YieldStrategy: no shares received");

150:         require(totalShares > 0, "ERC4626YieldStrategy: no shares to withdraw");

180:         require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");

181:         require(amount > 0, "ERC4626YieldStrategy: amount must be greater than zero");

221:         require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");

247:         require(setAsideBufferRecipient != address(0), "AYieldStrategy: setAsideBufferRecipient not set");

277:             require(client != address(0), "ERC4626YieldStrategy: client cannot be zero address");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (14)*:
```solidity
File: src/AYieldStrategy.sol

859:         uint256 balance = this.balanceOf(token, client);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

74:         return vault.balanceOf(address(this));

79:         return vault.convertToAssets(vault.balanceOf(address(this)));

129:         uint256 availableShares = vault.balanceOf(address(this));

239:         uint256 availableShares = vault.balanceOf(address(this));

270:         uint256 totalShares = vault.balanceOf(address(this));

292:         uint256 totalShares = vault.balanceOf(address(this));

340:         uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

57:         return vault.balanceOf(address(this));

62:         return vault.convertToAssets(vault.balanceOf(address(this)));

129:         uint256 availableShares = vault.balanceOf(address(this));

149:         uint256 totalShares = vault.balanceOf(address(this));

184:         uint256 totalShares = vault.balanceOf(address(this));

224:         uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-9"></a>[GAS-9] Stack variable used as a cheaper cache for a state variable is only used once
If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (3)*:
```solidity
File: src/AYieldStrategy.sol

354:         address old = setAsideBufferRecipient;

365:         address oldPauser = _pauser;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

91:         uint256 oldBps = slippageToleranceBps;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="GAS-10"></a>[GAS-10] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (5)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

50:         router = ICurveRouterNG(_router);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

254:         underlyingToken = IERC20(_underlyingToken);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

66:         vault = IERC4626(_erc4626Vault);

67:         ammAdapter = IAMMAdapter(_ammAdapter);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

47:         vault = IERC4626(_erc4626Vault);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-11"></a>[GAS-11] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (12)*:
```solidity
File: src/AYieldStrategy.sol

265:     function setClient(address client, bool _auth) external override onlyOwner {

309:     function setWithdrawer(address withdrawer, bool _auth) external onlyOwner {

335:     function setSetAsideBuffer(address client, uint256 bufferPercent) external override onlyOwner {

352:     function setSetAsideBufferRecipient(address _recipient) external onlyOwner {

364:     function setPauser(address newPauser) external onlyOwner {

384:     function pause() external override onlyPauser {

402:     function emergencyWithdraw(uint256 amount) external override onlyOwner {

417:     function totalWithdrawal(address token, address client) external override onlyOwner nonReentrant whenNotPaused {

677:     function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {

682:     function relinquishPrincipal(address token, uint256 amount) external override onlyAuthorizedClient nonReentrant {

687:     function relinquishPrincipalAsOwner(address client, uint256 amount) external override onlyOwner nonReentrant {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

89:     function setSlippageTolerance(uint256 _bps) external onlyOwner {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

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
File: src/AMMAdapters/CurveAMMAdapter.sol

75:         for (uint256 i = 0; i < 11; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

907:             digits++;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

396:         for (uint256 i = 0; i < clients.length; i++) {

436:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

275:         for (uint256 i = 0; i < clients.length; i++) {

315:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-13"></a>[GAS-13] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (4)*:
```solidity
File: src/AYieldStrategy.sol

84:     uint256 public constant WAITING_PERIOD = 6 hours; // Phase 1 duration

85:     uint256 public constant EXECUTION_WINDOW = 72 hours; // Phase 2 duration

86:     uint256 public constant TOTAL_DURATION = WAITING_PERIOD + EXECUTION_WINDOW; // 78 hours total

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

41:     uint256 public constant MAX_BPS = 10000;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="GAS-14"></a>[GAS-14] Use of `this` instead of marking as `public` an `external` function
Using `this.` is like making an expensive external call. Consider marking the called function as public

*Saves around 2000 gas per instance*

*Instances (2)*:
```solidity
File: src/AYieldStrategy.sol

594:         return this.principalOf(token, account);

859:         uint256 balance = this.balanceOf(token, client);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

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

*Instances (5)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

75:         for (uint256 i = 0; i < 11; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

396:         for (uint256 i = 0; i < clients.length; i++) {

436:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

275:         for (uint256 i = 0; i < clients.length; i++) {

315:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="GAS-16"></a>[GAS-16] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (19)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

129:         require(amountIn > 0, "CurveAMMAdapter: amountIn must be > 0");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

403:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

702:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

709:         require(amount > 0, "AYieldStrategy: no principal to relinquish");

734:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

767:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

860:         require(balance > 0, "AYieldStrategy: no balance to withdraw");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

224:         require(sharesReceived > 0, "ERC4626MarketYieldStrategy: no shares received");

271:         require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

289:         require(amount > 0, "ERC4626MarketYieldStrategy: amount must be greater than zero");

300:         if (sharesToSell > 0) {

443:         if (totalSetAside > 0) underlyingToken.safeTransfer(setAsideBufferRecipient, totalSetAside);

445:         if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

108:         require(sharesReceived > 0, "ERC4626YieldStrategy: no shares received");

150:         require(totalShares > 0, "ERC4626YieldStrategy: no shares to withdraw");

181:         require(amount > 0, "ERC4626YieldStrategy: amount must be greater than zero");

192:         if (sharesToWithdraw > 0) {

322:         if (totalSetAside > 0) underlyingToken.safeTransfer(setAsideBufferRecipient, totalSetAside);

324:         if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-2](#NC-2) | Array indices should be referenced via `enum`s rather than via numeric literals | 1 |
| [NC-3](#NC-3) | Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked` | 1 |
| [NC-4](#NC-4) | `constant`s should be defined rather than using magic numbers | 7 |
| [NC-5](#NC-5) | Control structures do not follow the Solidity Style Guide | 16 |
| [NC-6](#NC-6) | Consider disabling `renounceOwnership()` | 2 |
| [NC-7](#NC-7) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 23 |
| [NC-8](#NC-8) | Event missing indexed field | 1 |
| [NC-9](#NC-9) | Events that mark critical parameter changes should contain both the old and the new value | 7 |
| [NC-10](#NC-10) | Function ordering does not follow the Solidity style guide | 4 |
| [NC-11](#NC-11) | Functions should not be longer than 50 lines | 79 |
| [NC-12](#NC-12) | Lack of checks in setters | 1 |
| [NC-13](#NC-13) | Incomplete NatSpec: `@return` is missing on actually documented functions | 1 |
| [NC-14](#NC-14) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 4 |
| [NC-15](#NC-15) | Consider using named mappings | 6 |
| [NC-16](#NC-16) | Owner can renounce while system is paused | 1 |
| [NC-17](#NC-17) | Adding a `return` statement when the function defines a named return variable, is redundant | 17 |
| [NC-18](#NC-18) | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| [NC-19](#NC-19) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-20](#NC-20) | Internal and private variables and functions names should begin with an underscore | 3 |
| [NC-21](#NC-21) | Event is missing `indexed` fields | 9 |
| [NC-22](#NC-22) | `public` functions not called by the contract should be declared `external` instead | 1 |
| [NC-23](#NC-23) | Variables need not be initialized to zero | 5 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

368:         emit PauserSet(oldPauser, newPauser);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-2"></a>[NC-2] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (1)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

71:         require(path[0] == tokenIn, "CurveAMMAdapter: path[0] must equal tokenIn");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

### <a name="NC-3"></a>[NC-3] Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked`
Solidity version 0.8.4 introduces `bytes.concat()` (vs `abi.encodePacked(<bytes>,<bytes>)`)

Solidity version 0.8.12 introduces `string.concat()` (vs `abi.encodePacked(<str>,<str>), which catches concatenation errors (in the event of a `bytes` data mixed in the concatenation)`)

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

438:                     abi.encodePacked(

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-4"></a>[NC-4] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (7)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

75:         for (uint256 i = 0; i < 11; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

337:         require(bufferPercent <= 100, "AYieldStrategy: buffer percent exceeds 100");

908:             temp /= 10;

913:             buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));

914:             value /= 10;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

410:             shares = shares * setAsideBufferSize[client] / 100; // reuse slot: now buffer shares (0–100)

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

289:             shares = shares * setAsideBufferSize[client] / 100; // reuse slot: now buffer shares (0–100)

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="NC-5"></a>[NC-5] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (16)*:
```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

339:         if (td == 0) return 0;

344:         if (totalShares == 0) return 0;

402:                 if (principal == 0) continue;

404:                 if (total <= principal) continue;

437:             if (bufferShares[i] == 0) continue;

439:             if (buf == 0) continue;

443:         if (totalSetAside > 0) underlyingToken.safeTransfer(setAsideBufferRecipient, totalSetAside);

445:         if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

223:         if (td == 0) return 0;

228:         if (totalShares == 0) return 0;

281:                 if (principal == 0) continue;

283:                 if (total <= principal) continue;

316:             if (bufferShares[i] == 0) continue;

318:             if (buf == 0) continue;

322:         if (totalSetAside > 0) underlyingToken.safeTransfer(setAsideBufferRecipient, totalSetAside);

324:         if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="NC-6"></a>[NC-6] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (2)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

20: contract CurveAMMAdapter is IAMMAdapter, Ownable {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

18: abstract contract AYieldStrategy is IYieldStrategy, IPausable, Ownable, ReentrancyGuard, Pausable {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-7"></a>[NC-7] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (23)*:
```solidity
File: src/AYieldStrategy.sol

266:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

336:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

353:         require(_recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

403:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

418:         require(token != address(0), "AYieldStrategy: token cannot be zero address");

419:         require(client != address(0), "AYieldStrategy: client cannot be zero address");

468:         require(token != address(0), "AYieldStrategy: token cannot be zero address");

469:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

524:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

537:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

578:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

701:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

702:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

733:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

734:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

735:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

766:         require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

767:         require(amount > 0, "AYieldStrategy: amount must be greater than zero");

768:         require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

288:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

337:         require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

180:         require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");

221:         require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="NC-8"></a>[NC-8] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (1)*:
```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

50:     event SlippageToleranceSet(uint256 oldBps, uint256 newBps);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="NC-9"></a>[NC-9] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (7)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

62:     function setRoute(
            address tokenIn,
            address tokenOut,
            address[11] calldata path,
            uint256[5][5] calldata swapParams,
            address[5] calldata pools
        ) external onlyOwner {
            require(tokenIn != address(0), "CurveAMMAdapter: tokenIn cannot be zero");
            require(tokenOut != address(0), "CurveAMMAdapter: tokenOut cannot be zero");
            require(path[0] == tokenIn, "CurveAMMAdapter: path[0] must equal tokenIn");
    
            // Find the last non-zero entry in path and confirm it equals tokenOut
            address lastToken;
            for (uint256 i = 0; i < 11; i++) {
                if (path[i] != address(0)) {
                    lastToken = path[i];
                }
            }
            require(lastToken == tokenOut, "CurveAMMAdapter: path must end at tokenOut");
    
            Route storage r = routes[tokenIn][tokenOut];
            r.path = path;
            r.swapParams = swapParams;
            r.pools = pools;
            r.configured = true;
    
            emit RouteSet(tokenIn, tokenOut);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

265:     function setClient(address client, bool _auth) external override onlyOwner {
             require(client != address(0), "AYieldStrategy: client cannot be zero address");
     
             if (_auth) {
                 _authorizedClients.add(client); // idempotent — no duplicates possible
             } else {
                 _authorizedClients.remove(client);
             }
     
             emit ClientAuthorizationSet(client, _auth);

309:     function setWithdrawer(address withdrawer, bool _auth) external onlyOwner {
             require(withdrawer != address(0), "AYieldStrategy: withdrawer cannot be zero address");
     
             authorizedWithdrawers[withdrawer] = _auth;
     
             emit WithdrawerAuthorizationSet(withdrawer, _auth);

335:     function setSetAsideBuffer(address client, uint256 bufferPercent) external override onlyOwner {
             require(client != address(0), "AYieldStrategy: client cannot be zero address");
             require(bufferPercent <= 100, "AYieldStrategy: buffer percent exceeds 100");
             uint256 old = setAsideBufferSize[client];
             setAsideBufferSize[client] = bufferPercent;
             emit SetAsideBufferSet(client, old, bufferPercent);

352:     function setSetAsideBufferRecipient(address _recipient) external onlyOwner {
             require(_recipient != address(0), "AYieldStrategy: recipient cannot be zero address");
             address old = setAsideBufferRecipient;
             setAsideBufferRecipient = _recipient;
             emit SetAsideBufferRecipientSet(old, _recipient);

364:     function setPauser(address newPauser) external onlyOwner {
             address oldPauser = _pauser;
             _pauser = newPauser;
     
             emit PauserSet(oldPauser, newPauser);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

89:     function setSlippageTolerance(uint256 _bps) external onlyOwner {
            require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
            uint256 oldBps = slippageToleranceBps;
            slippageToleranceBps = _bps;
            emit SlippageToleranceSet(oldBps, _bps);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="NC-10"></a>[NC-10] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (4)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

1: 
   Current order:
   external setRoute
   external getRoute
   public isPairFullyConfigured
   external swap
   
   Suggested order:
   external setRoute
   external getRoute
   external swap
   public isPairFullyConfigured

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

1: 
   Current order:
   external setClient
   external authorizedClients
   external getAuthorizedClients
   external authorizedClientCount
   external setWithdrawer
   external setSetAsideBuffer
   external setSetAsideBufferRecipient
   external setPauser
   external pauser
   external pause
   external unpause
   external emergencyWithdraw
   external totalWithdrawal
   external skimSurplus
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   external underlying
   external principalOf
   external totalBalanceOf
   external previewExitFor
   external balanceOf
   external getTotalDeposited
   external getTotalShares
   external deposit
   external withdraw
   external depositAsOwner
   external withdrawAsOwner
   external relinquishPrincipal
   external relinquishPrincipalAsOwner
   internal _relinquishInternal
   internal _depositInternal
   internal _withdrawInternal
   internal _positionValue
   internal _acquireShares
   internal _disposeShares
   internal _updateWithdrawalStatus
   internal _initiateWithdrawal
   internal _executeWithdrawal
   internal _uint256ToString
   
   Suggested order:
   external setClient
   external authorizedClients
   external getAuthorizedClients
   external authorizedClientCount
   external setWithdrawer
   external setSetAsideBuffer
   external setSetAsideBufferRecipient
   external setPauser
   external pauser
   external pause
   external unpause
   external emergencyWithdraw
   external totalWithdrawal
   external skimSurplus
   external underlying
   external principalOf
   external totalBalanceOf
   external previewExitFor
   external balanceOf
   external getTotalDeposited
   external getTotalShares
   external deposit
   external withdraw
   external depositAsOwner
   external withdrawAsOwner
   external relinquishPrincipal
   external relinquishPrincipalAsOwner
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   internal _relinquishInternal
   internal _depositInternal
   internal _withdrawInternal
   internal _positionValue
   internal _acquireShares
   internal _disposeShares
   internal _updateWithdrawalStatus
   internal _initiateWithdrawal
   internal _executeWithdrawal
   internal _uint256ToString

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

1: 
   Current order:
   external getTotalShares
   internal _positionValue
   external setSlippageTolerance
   internal _creditedPrincipal
   internal _exitFloor
   external previewExitFor
   internal _acquireShares
   internal _disposeShares
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   private _accrueSurplusShares
   private _distributeBuffer
   
   Suggested order:
   external getTotalShares
   external setSlippageTolerance
   external previewExitFor
   internal _positionValue
   internal _creditedPrincipal
   internal _exitFloor
   internal _acquireShares
   internal _disposeShares
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   private _accrueSurplusShares
   private _distributeBuffer

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

1: 
   Current order:
   external getTotalShares
   internal _positionValue
   external previewDeposit
   external previewRedeem
   internal _acquireShares
   internal _disposeShares
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   private _accrueSurplusShares
   private _distributeBuffer
   
   Suggested order:
   external getTotalShares
   external previewDeposit
   external previewRedeem
   internal _positionValue
   internal _acquireShares
   internal _disposeShares
   internal _emergencyWithdraw
   internal _totalWithdraw
   internal _skimSurplus
   private _accrueSurplusShares
   private _distributeBuffer

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="NC-11"></a>[NC-11] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (79)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

100:     function getRoute(address tokenIn, address tokenOut)

115:     function isPairFullyConfigured(address tokenA, address tokenB) public view returns (bool) {

120:     function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AMMAdapters/IAMMAdapter.sol

20:     function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/IAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

265:     function setClient(address client, bool _auth) external override onlyOwner {

283:     function authorizedClients(address client) external view returns (bool) {

291:     function getAuthorizedClients() external view override returns (address[] memory) {

299:     function authorizedClientCount() external view returns (uint256) {

309:     function setWithdrawer(address withdrawer, bool _auth) external onlyOwner {

335:     function setSetAsideBuffer(address client, uint256 bufferPercent) external override onlyOwner {

352:     function setSetAsideBufferRecipient(address _recipient) external onlyOwner {

364:     function setPauser(address newPauser) external onlyOwner {

376:     function pauser() external view override returns (address) {

402:     function emergencyWithdraw(uint256 amount) external override onlyOwner {

417:     function totalWithdrawal(address token, address client) external override onlyOwner nonReentrant whenNotPaused {

461:     function skimSurplus(address token, address recipient)

480:     function _emergencyWithdraw(uint256 amount) internal virtual;

489:     function _totalWithdraw(address token, address client, uint256 amount) internal virtual;

502:     function _skimSurplus(address token, address[] memory clients, address recipient)

513:     function underlying() external view returns (address) {

523:     function principalOf(address token, address account) external view override returns (uint256) {

536:     function totalBalanceOf(address token, address account) external view override returns (uint256) {

571:     function previewExitFor(address token, address account, uint256 netWanted)

593:     function balanceOf(address token, address account) external view override returns (uint256) {

602:     function getTotalDeposited(address token) external view returns (uint256) {

612:     function getTotalShares() external view virtual returns (uint256);

624:     function deposit(address token, uint256 amount, address recipient)

642:     function withdraw(address token, uint256 amount, address recipient)

660:     function depositAsOwner(address token, uint256 amount, address client)

677:     function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {

682:     function relinquishPrincipal(address token, uint256 amount) external override onlyAuthorizedClient nonReentrant {

687:     function relinquishPrincipalAsOwner(address client, uint256 amount) external override onlyOwner nonReentrant {

700:     function _relinquishInternal(address token, address balanceHolder, uint256 amount) internal {

729:     function _depositInternal(address token, uint256 amount, address recipient, address depositor)

765:     function _withdrawInternal(address token, uint256 amount, address recipient, address balanceHolder) internal {

796:     function _positionValue() internal view virtual returns (uint256);

809:     function _acquireShares(uint256 amount, address depositor)

823:     function _disposeShares(uint256 amount, address recipient) internal virtual returns (uint256 sharesDisposed);

832:     function _updateWithdrawalStatus(WithdrawalState storage state, uint256 currentTime) internal {

855:     function _initiateWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)

879:     function _executeWithdrawal(address token, address client, WithdrawalState storage state, uint256 currentTime)

900:     function _uint256ToString(uint256 value) internal pure returns (string memory) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

73:     function getTotalShares() external view override returns (uint256) {

78:     function _positionValue() internal view override returns (uint256) {

89:     function setSlippageTolerance(uint256 _bps) external onlyOwner {

107:     function _creditedPrincipal(uint256 amount) internal view returns (uint256) {

127:     function _exitFloor(uint256 amount) internal view returns (uint256) {

162:     function previewExitFor(address token, address account, uint256 netWanted)

201:     function _acquireShares(uint256 amount, address depositor)

236:     function _disposeShares(uint256 amount, address recipient) internal override returns (uint256 sharesDisposed) {

269:     function _emergencyWithdraw(uint256 amount) internal override {

287:     function _totalWithdraw(address token, address client, uint256 amount) internal override {

332:     function _skimSurplus(address token, address[] memory clients, address recipient)

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

56:     function getTotalShares() external view override returns (uint256) {

61:     function _positionValue() internal view override returns (uint256) {

73:     function previewDeposit(uint256 assets) external view returns (uint256 shares) {

83:     function previewRedeem(uint256 shares) external view returns (uint256 assets) {

98:     function _acquireShares(uint256 amount, address depositor)

126:     function _disposeShares(uint256 amount, address recipient) internal override returns (uint256 sharesDisposed) {

148:     function _emergencyWithdraw(uint256 amount) internal override {

179:     function _totalWithdraw(address token, address client, uint256 amount) internal override {

216:     function _skimSurplus(address token, address[] memory clients, address recipient)

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

```solidity
File: src/interfaces/IYieldStrategy.sol

24:     function deposit(address token, uint256 amount, address recipient) external returns (uint256 creditedPrincipal);

32:     function withdraw(address token, uint256 amount, address recipient) external;

79:     function previewExitFor(address token, address account, uint256 netWanted)

91:     function relinquishPrincipal(address token, uint256 amount) external;

96:     function relinquishPrincipalAsOwner(address client, uint256 amount) external;

108:     function balanceOf(address token, address account) external view returns (uint256);

118:     function principalOf(address token, address account) external view returns (uint256);

130:     function totalBalanceOf(address token, address account) external view returns (uint256);

138:     function setClient(address client, bool _auth) external;

145:     function emergencyWithdraw(uint256 amount) external;

155:     function totalWithdrawal(address token, address client) external;

171:     function skimSurplus(address token, address recipient) external returns (uint256 underlyingReceived);

177:     function getAuthorizedClients() external view returns (address[] memory);

184:     function setSetAsideBuffer(address client, uint256 bufferPercent) external;

189:     function setAsideBufferSize(address client) external view returns (uint256);

196:     function setSetAsideBufferRecipient(address _recipient) external;

202:     function setAsideBufferRecipient() external view returns (address);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/interfaces/IYieldStrategy.sol)

### <a name="NC-12"></a>[NC-12] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

364:     function setPauser(address newPauser) external onlyOwner {
             address oldPauser = _pauser;
             _pauser = newPauser;
     
             emit PauserSet(oldPauser, newPauser);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-13"></a>[NC-13] Incomplete NatSpec: `@return` is missing on actually documented functions
The following functions are missing `@return` NatSpec comments.

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

653:      * @notice Owner-only deposit on behalf of a client, bypassing client authorization
          * @param token The token address (must be underlying token)
          * @param amount The amount of underlying tokens to deposit
          * @param client The client address whose balance will be credited
          * @dev Does NOT have whenNotPaused — owner should be able to act in emergencies.
          *      Tokens are transferred from msg.sender (the owner).
          */
         function depositAsOwner(address token, uint256 amount, address client)
             external
             onlyOwner
             nonReentrant
             returns (uint256 creditedPrincipal)
         {
             return _depositInternal(token, amount, client, msg.sender);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-14"></a>[NC-14] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (4)*:
```solidity
File: src/AYieldStrategy.sol

219:         require(_authorizedClients.contains(msg.sender), "AYieldStrategy: unauthorized, only authorized clients");

228:         require(authorizedWithdrawers[msg.sender], "AYieldStrategy: unauthorized, only authorized withdrawers");

237:         require(msg.sender == _pauser, "AYieldStrategy: caller is not the pauser");

393:         require(msg.sender == owner() || msg.sender == _pauser, "AYieldStrategy: caller is not the owner or pauser");

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-15"></a>[NC-15] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (6)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

35:     mapping(address => mapping(address => Route)) private routes;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

32:     mapping(address => bool) public authorizedWithdrawers;

45:     mapping(address => mapping(address => uint256)) internal clientBalances;

49:     mapping(address => uint256) internal totalDeposited;

57:     mapping(address => uint256) public setAsideBufferSize;

81:     mapping(address => mapping(address => WithdrawalState)) public withdrawalStates;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-16"></a>[NC-16] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

364:     function setPauser(address newPauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-17"></a>[NC-17] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (17)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

91:     /**
         * @notice View a configured route (useful for off-chain verification)
         * @param tokenIn The swap input token
         * @param tokenOut The swap output token
         * @return path The stored 11-slot route array
         * @return swapParams The stored 5x5 swap params matrix
         * @return pools The stored 5-slot base pools array
         * @return configured True if this direction has been configured
         */
        function getRoute(address tokenIn, address tokenOut)
            external
            view
            returns (address[11] memory path, uint256[5][5] memory swapParams, address[5] memory pools, bool configured)
        {
            Route storage r = routes[tokenIn][tokenOut];
            return (r.path, r.swapParams, r.pools, r.configured);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

448:      * @notice Skim the FULL available surplus of EVERY currently-authorized client to one recipient,
          *         in a single underlying redeem/swap. Always all-or-nothing (fairness).
          * @param token The token address to skim
          * @param recipient The address that will receive all skimmed proceeds
          * @return underlyingReceived The actual underlying token amount delivered to `recipient`
          *         (the real redeem/swap result), so callers can bubble it up without re-deriving it.
          *         This can differ from the sum of the per-client `surplus` amounts emitted in
          *         `SurplusSkimmed` events (snapshot surplus, vault-asset terms) due to slippage/rounding.
          * @dev Only authorized withdrawers can call this function. The strategy owns the client set, so
          *      no client list is supplied by the caller — this structurally closes the duplicate-driven
          *      over-skim vector (audit M-01). Snapshot semantics; principal accounting untouched.
          *      An empty client set is a no-op (no revert, returns 0) so keepers/schedulers never fail spuriously.
          */
         function skimSurplus(address token, address recipient)
             external
             onlyAuthorizedWithdrawer
             nonReentrant
             whenNotPaused
             returns (uint256 underlyingReceived)
         {
             require(token != address(0), "AYieldStrategy: token cannot be zero address");
             require(recipient != address(0), "AYieldStrategy: recipient cannot be zero address");
             return _skimSurplus(token, _authorizedClients.values(), recipient);

617:      * @notice Deposit underlying tokens, acquiring backing shares via the concrete strategy's hook
          * @param token The token address (must be underlying token)
          * @param amount The amount of underlying tokens to deposit
          * @param recipient The address that will own the deposited tokens (for accounting)
          * @return creditedPrincipal The principal booked against `recipient` (see IYieldStrategy.deposit)
          * @dev Only authorized clients. Share acquisition is delegated to `_depositInternal`.
          */
         function deposit(address token, uint256 amount, address recipient)
             external
             override
             onlyAuthorizedClient
             nonReentrant
             whenNotPaused
             returns (uint256 creditedPrincipal)
         {
             return _depositInternal(token, amount, recipient, msg.sender);

653:      * @notice Owner-only deposit on behalf of a client, bypassing client authorization
          * @param token The token address (must be underlying token)
          * @param amount The amount of underlying tokens to deposit
          * @param client The client address whose balance will be credited
          * @dev Does NOT have whenNotPaused — owner should be able to act in emergencies.
          *      Tokens are transferred from msg.sender (the owner).
          */
         function depositAsOwner(address token, uint256 amount, address client)
             external
             onlyOwner
             nonReentrant
             returns (uint256 creditedPrincipal)
         {
             return _depositInternal(token, amount, client, msg.sender);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

140:      * @notice Exit preview for the market strategy: grosses `netWanted` up through the exit haircut
          *         and reports the guaranteed floor for the resulting request.
          * @param token The token address (must be underlying token)
          * @param account The account whose principal the exit would be debited from
          * @param netWanted The net underlying the caller needs to end up holding
          * @return grossToRequest `ceil(netWanted * MAX_BPS / (MAX_BPS - slippageToleranceBps))`, capped
          *         to the account's available principal exactly as `_withdrawInternal` caps it. Rounded
          *         UP so the gross-up never quotes short of `netWanted` by a rounding unit.
          * @return netGuaranteed The swap floor for `grossToRequest` (see `_exitFloor`). Falls BELOW
          *         `netWanted` when a cap binds — the account's principal, or the shares the strategy
          *         actually holds — which is the honest report that the position cannot cover the ask.
          * @dev ⚠️ `netGuaranteed` IS A FLOOR, NOT AN EXPECTATION. The AMM pays anywhere at or above it
          *      and the gap can be large in EITHER direction. Consumers MUST measure the real balance
          *      delta across `withdraw`; see the full warning on `IYieldStrategy.previewExitFor`.
          *
          *      DIVISION-BY-ZERO GUARD (mandatory): `setSlippageTolerance` permits exactly `MAX_BPS`, at
          *      which the algebraic inverse would divide by zero and panic (`Panic(0x12)`). At that
          *      setting the strategy genuinely guarantees NOTHING — `minOut` is 0, so any output is
          *      acceptable — and the honest quote is `(0, 0)`. Returning it, rather than panicking, lets
          *      a caller distinguish "this strategy can guarantee no output" from a low-level failure
          *      and handle it as the operational alarm it is.
          */
         function previewExitFor(address token, address account, uint256 netWanted)
             external
             view
             override
             returns (uint256 grossToRequest, uint256 netGuaranteed)
         {
             require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");
     
             uint256 denominator = MAX_BPS - slippageToleranceBps;
             if (denominator == 0) {
                 // 100% slippage tolerance: minOut is always 0, so no request carries any guarantee.
                 return (0, 0);
             }

321:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never sell beyond the protocol's surplus.
             uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;
             require(
                 totalShares <= vault.convertToShares(aggregateSurplus),
                 "ERC4626MarketYieldStrategy: skim exceeds aggregate surplus"
             );
             // minOut is computed on the full `totalShares`: the whole surplus is sold in ONE swap; only the
             // distribution of the proceeds changes when buffers are set, so slippage behavior is unchanged.
             uint256 idealUnderlying = vault.convertToAssets(totalShares);
             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
             IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);
             // SINGLE swap — output lands in address(this). Return value is the ACTUAL underlying received,
             // net of AMM price/slippage, and so will generally differ from the SurplusSkimmed snapshot sum
             // (vault-asset terms) — see CLAUDE.md.
             underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);
     
             // FAST PATH — no buffers configured (the default): forward the whole swap output to `recipient`.
             if (totalBufferShares == 0) {
                 underlyingToken.safeTransfer(recipient, underlyingReceived);
                 return underlyingReceived;
             }
     
             // LOUD GUARD — buffers are configured but no recipient has been set: revert instead of silently
             // sending to address(0) or falling back to per-client distribution.
             require(setAsideBufferRecipient != address(0), "AYieldStrategy: setAsideBufferRecipient not set");
     
             // BUFFERED PATH — send the aggregate set-aside to setAsideBufferRecipient in a single transfer;
             // the remainder goes to `recipient`. Principal tracking intentionally untouched.
             return _distributeBuffer(clients, bufferShares, underlyingReceived, totalShares, recipient);

321:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

321:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never sell beyond the protocol's surplus.

321:      * @notice Skim the full available surplus of every authorized client in a SINGLE AMM swap
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE ammAdapter.swap with minOut computed on the aggregate.
          *      Principal accounting is left untouched. The aggregate-surplus require (audit M-01
          *      mitigation) replaces the old silent clamp: it fails LOUDLY rather than over-selling.
          *      The EnumerableSet of clients already guarantees distinctness, so this require is
          *      defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626MarketYieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never sell beyond the protocol's surplus.
             uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;
             require(
                 totalShares <= vault.convertToShares(aggregateSurplus),
                 "ERC4626MarketYieldStrategy: skim exceeds aggregate surplus"
             );
             // minOut is computed on the full `totalShares`: the whole surplus is sold in ONE swap; only the
             // distribution of the proceeds changes when buffers are set, so slippage behavior is unchanged.
             uint256 idealUnderlying = vault.convertToAssets(totalShares);
             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
             IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);
             // SINGLE swap — output lands in address(this). Return value is the ACTUAL underlying received,
             // net of AMM price/slippage, and so will generally differ from the SurplusSkimmed snapshot sum
             // (vault-asset terms) — see CLAUDE.md.
             underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);
     
             // FAST PATH — no buffers configured (the default): forward the whole swap output to `recipient`.
             if (totalBufferShares == 0) {
                 underlyingToken.safeTransfer(recipient, underlyingReceived);
                 return underlyingReceived;
             }

417:      * @notice Distribute actual swap proceeds: aggregate set-aside buffer to setAsideBufferRecipient,
          *         remainder to skim recipient.
          * @param clients The client set (parallel to bufferShares)
          * @param bufferShares Per-client buffer shares (indexed by loop position)
          * @param underlyingReceived The actual underlying received from the single swap
          * @param totalShares The aggregate shares sold in the swap
          * @param recipient The address that receives the remainder (the skim caller's recipient)
          * @return toRecipient The amount delivered to `recipient` (reduced by total set-aside)
          * @dev All set-aside from all clients is summed into a SINGLE transfer to setAsideBufferRecipient.
          *      Factored out to keep the caller within the EVM stack-depth limit.
          */
         function _distributeBuffer(
             address[] memory clients,
             uint256[] memory bufferShares,
             uint256 underlyingReceived,
             uint256 totalShares,
             address recipient
         ) private returns (uint256 toRecipient) {
             uint256 totalSetAside;
             for (uint256 i = 0; i < clients.length; i++) {
                 if (bufferShares[i] == 0) continue;
                 uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional
                 if (buf == 0) continue;
                 totalSetAside += buf;
             }
             // Single aggregate transfer to the global set-aside buffer recipient
             if (totalSetAside > 0) underlyingToken.safeTransfer(setAsideBufferRecipient, totalSetAside);
             toRecipient = underlyingReceived - totalSetAside; // dust (rounding) favors recipient
             if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);
             return toRecipient; // RETURN VALUE REDUCED by totalSetAside

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

67:     /**
         * @notice Preview the shares that would be received for a deposit of `assets`
         * @param assets The amount of underlying tokens to preview depositing
         * @return shares The estimated vault shares that would be received
         * @dev Delegates directly to the underlying ERC4626 vault's previewDeposit.
         */
        function previewDeposit(uint256 assets) external view returns (uint256 shares) {
            return vault.previewDeposit(assets);

77:     /**
         * @notice Preview the underlying assets that would be received for redeeming `shares`
         * @param shares The number of vault shares to preview redeeming
         * @return assets The estimated underlying tokens that would be received
         * @dev Delegates directly to the underlying ERC4626 vault's previewRedeem.
         */
        function previewRedeem(uint256 shares) external view returns (uint256 assets) {
            return vault.previewRedeem(shares);

206:      * @notice Skim the full available surplus of every authorized client in a SINGLE redeem
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE vault.redeem. Principal accounting is left untouched.
          *      The aggregate-surplus require (audit M-01 mitigation) replaces the old silent clamp:
          *      it fails LOUDLY rather than over-redeeming. The EnumerableSet of clients already
          *      guarantees distinctness, so this require is defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never redeem beyond the protocol's surplus.
             uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;
             require(
                 totalShares <= vault.convertToShares(aggregateSurplus),
                 "ERC4626YieldStrategy: skim exceeds aggregate surplus"
             );
     
             // FAST PATH — no buffers configured (the default): behave exactly as before, a single redeem
             // straight to `recipient`. Return the ACTUAL underlying delivered (real redeem result) so the
             // caller can bubble it up. May differ from the SurplusSkimmed snapshot sum (rounding/fees) —
             // see CLAUDE.md.
             if (totalBufferShares == 0) {
                 underlyingReceived = vault.redeem(totalShares, recipient, address(this)); // SINGLE redeem
                 return underlyingReceived;
             }
     
             // LOUD GUARD — buffers are configured but no recipient has been set: revert instead of silently
             // sending to address(0) or falling back to per-client distribution.
             require(setAsideBufferRecipient != address(0), "AYieldStrategy: setAsideBufferRecipient not set");
     
             // BUFFERED PATH — redeem to self, then send the aggregate set-aside to setAsideBufferRecipient
             // in a single transfer; the remainder goes to `recipient`. Principal untouched.
             underlyingReceived = vault.redeem(totalShares, address(this), address(this)); // SINGLE redeem
             return _distributeBuffer(clients, bufferShares, underlyingReceived, totalShares, recipient);

206:      * @notice Skim the full available surplus of every authorized client in a SINGLE redeem
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE vault.redeem. Principal accounting is left untouched.
          *      The aggregate-surplus require (audit M-01 mitigation) replaces the old silent clamp:
          *      it fails LOUDLY rather than over-redeeming. The EnumerableSet of clients already
          *      guarantees distinctness, so this require is defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot

206:      * @notice Skim the full available surplus of every authorized client in a SINGLE redeem
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE vault.redeem. Principal accounting is left untouched.
          *      The aggregate-surplus require (audit M-01 mitigation) replaces the old silent clamp:
          *      it fails LOUDLY rather than over-redeeming. The EnumerableSet of clients already
          *      guarantees distinctness, so this require is defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never redeem beyond the protocol's surplus.

206:      * @notice Skim the full available surplus of every authorized client in a SINGLE redeem
          * @param token The token address (must be underlying token)
          * @param clients The client addresses (the strategy's authorized set) whose surplus is skimmed
          * @param recipient The address that will receive all skimmed proceeds
          * @dev Snapshots total value once, sums per-client FLOORED shares (protocol-favoring rounding),
          *      and performs a SINGLE vault.redeem. Principal accounting is left untouched.
          *      The aggregate-surplus require (audit M-01 mitigation) replaces the old silent clamp:
          *      it fails LOUDLY rather than over-redeeming. The EnumerableSet of clients already
          *      guarantees distinctness, so this require is defense-in-depth.
          */
         function _skimSurplus(address token, address[] memory clients, address recipient)
             internal
             override
             returns (uint256 underlyingReceived)
         {
             require(token == address(underlyingToken), "ERC4626YieldStrategy: only underlying token supported");
             uint256 td = totalDeposited[token];
             if (td == 0) return 0;
             uint256 totalValue = vault.convertToAssets(vault.balanceOf(address(this))); // snapshot
             uint256[] memory bufferShares = new uint256[](clients.length);
             (uint256 totalShares, uint256 totalBufferShares) =
                 _accrueSurplusShares(token, clients, recipient, totalValue, bufferShares);
             if (totalShares == 0) return 0;
             // Loud aggregate-surplus ceiling (audit M-01): never redeem beyond the protocol's surplus.
             uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;
             require(
                 totalShares <= vault.convertToShares(aggregateSurplus),
                 "ERC4626YieldStrategy: skim exceeds aggregate surplus"
             );
     
             // FAST PATH — no buffers configured (the default): behave exactly as before, a single redeem
             // straight to `recipient`. Return the ACTUAL underlying delivered (real redeem result) so the
             // caller can bubble it up. May differ from the SurplusSkimmed snapshot sum (rounding/fees) —
             // see CLAUDE.md.
             if (totalBufferShares == 0) {
                 underlyingReceived = vault.redeem(totalShares, recipient, address(this)); // SINGLE redeem
                 return underlyingReceived;

296:      * @notice Distribute actual redeem proceeds: aggregate set-aside buffer to setAsideBufferRecipient,
          *         remainder to skim recipient.
          * @param clients The client set (parallel to bufferShares)
          * @param bufferShares Per-client buffer shares (indexed by loop position)
          * @param underlyingReceived The actual underlying received from the single redeem
          * @param totalShares The aggregate shares redeemed
          * @param recipient The address that receives the remainder (the skim caller's recipient)
          * @return toRecipient The amount delivered to `recipient` (reduced by total set-aside)
          * @dev All set-aside from all clients is summed into a SINGLE transfer to setAsideBufferRecipient.
          *      Factored out to keep the caller within the EVM stack-depth limit.
          */
         function _distributeBuffer(
             address[] memory clients,
             uint256[] memory bufferShares,
             uint256 underlyingReceived,
             uint256 totalShares,
             address recipient
         ) private returns (uint256 toRecipient) {
             uint256 totalSetAside;
             for (uint256 i = 0; i < clients.length; i++) {
                 if (bufferShares[i] == 0) continue;
                 uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional
                 if (buf == 0) continue;
                 totalSetAside += buf;
             }
             // Single aggregate transfer to the global set-aside buffer recipient
             if (totalSetAside > 0) underlyingToken.safeTransfer(setAsideBufferRecipient, totalSetAside);
             toRecipient = underlyingReceived - totalSetAside; // dust (rounding) favors recipient
             if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);
             return toRecipient; // RETURN VALUE REDUCED by totalSetAside

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

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
File: src/AMMAdapters/CurveAMMAdapter.sol

1: 
   Current order:
   UsingForDirective.IERC20
   StructDefinition.Route
   VariableDeclaration.router
   VariableDeclaration.routes
   EventDefinition.RouteSet
   EventDefinition.Swapped
   FunctionDefinition.constructor
   FunctionDefinition.setRoute
   FunctionDefinition.getRoute
   FunctionDefinition.isPairFullyConfigured
   FunctionDefinition.swap
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.router
   VariableDeclaration.routes
   StructDefinition.Route
   EventDefinition.RouteSet
   EventDefinition.Swapped
   FunctionDefinition.constructor
   FunctionDefinition.setRoute
   FunctionDefinition.getRoute
   FunctionDefinition.isPairFullyConfigured
   FunctionDefinition.swap

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

1: 
   Current order:
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration._pauser
   VariableDeclaration._authorizedClients
   VariableDeclaration.authorizedWithdrawers
   VariableDeclaration.underlyingToken
   VariableDeclaration.clientBalances
   VariableDeclaration.totalDeposited
   VariableDeclaration.setAsideBufferSize
   VariableDeclaration.setAsideBufferRecipient
   EnumDefinition.WithdrawalStatus
   StructDefinition.WithdrawalState
   VariableDeclaration.withdrawalStates
   VariableDeclaration.WAITING_PERIOD
   VariableDeclaration.EXECUTION_WINDOW
   VariableDeclaration.TOTAL_DURATION
   EventDefinition.ClientAuthorizationSet
   EventDefinition.WithdrawerAuthorizationSet
   EventDefinition.SetAsideBufferSet
   EventDefinition.SetAsideBufferRecipientSet
   EventDefinition.SurplusSkimmed
   EventDefinition.PrincipalRelinquished
   EventDefinition.Deposited
   EventDefinition.Withdrawn
   EventDefinition.EmergencyWithdraw
   EventDefinition.PauserSet
   EventDefinition.WithdrawalInitiated
   EventDefinition.WithdrawalExecuted
   ModifierDefinition.onlyAuthorizedClient
   ModifierDefinition.onlyAuthorizedWithdrawer
   ModifierDefinition.onlyPauser
   FunctionDefinition.constructor
   FunctionDefinition.setClient
   FunctionDefinition.authorizedClients
   FunctionDefinition.getAuthorizedClients
   FunctionDefinition.authorizedClientCount
   FunctionDefinition.setWithdrawer
   FunctionDefinition.setSetAsideBuffer
   FunctionDefinition.setSetAsideBufferRecipient
   FunctionDefinition.setPauser
   FunctionDefinition.pauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.totalWithdrawal
   FunctionDefinition.skimSurplus
   FunctionDefinition._emergencyWithdraw
   FunctionDefinition._totalWithdraw
   FunctionDefinition._skimSurplus
   FunctionDefinition.underlying
   FunctionDefinition.principalOf
   FunctionDefinition.totalBalanceOf
   FunctionDefinition.previewExitFor
   FunctionDefinition.balanceOf
   FunctionDefinition.getTotalDeposited
   FunctionDefinition.getTotalShares
   FunctionDefinition.deposit
   FunctionDefinition.withdraw
   FunctionDefinition.depositAsOwner
   FunctionDefinition.withdrawAsOwner
   FunctionDefinition.relinquishPrincipal
   FunctionDefinition.relinquishPrincipalAsOwner
   FunctionDefinition._relinquishInternal
   FunctionDefinition._depositInternal
   FunctionDefinition._withdrawInternal
   FunctionDefinition._positionValue
   FunctionDefinition._acquireShares
   FunctionDefinition._disposeShares
   FunctionDefinition._updateWithdrawalStatus
   FunctionDefinition._initiateWithdrawal
   FunctionDefinition._executeWithdrawal
   FunctionDefinition._uint256ToString
   
   Suggested order:
   UsingForDirective.EnumerableSet.AddressSet
   VariableDeclaration._pauser
   VariableDeclaration._authorizedClients
   VariableDeclaration.authorizedWithdrawers
   VariableDeclaration.underlyingToken
   VariableDeclaration.clientBalances
   VariableDeclaration.totalDeposited
   VariableDeclaration.setAsideBufferSize
   VariableDeclaration.setAsideBufferRecipient
   VariableDeclaration.withdrawalStates
   VariableDeclaration.WAITING_PERIOD
   VariableDeclaration.EXECUTION_WINDOW
   VariableDeclaration.TOTAL_DURATION
   EnumDefinition.WithdrawalStatus
   StructDefinition.WithdrawalState
   EventDefinition.ClientAuthorizationSet
   EventDefinition.WithdrawerAuthorizationSet
   EventDefinition.SetAsideBufferSet
   EventDefinition.SetAsideBufferRecipientSet
   EventDefinition.SurplusSkimmed
   EventDefinition.PrincipalRelinquished
   EventDefinition.Deposited
   EventDefinition.Withdrawn
   EventDefinition.EmergencyWithdraw
   EventDefinition.PauserSet
   EventDefinition.WithdrawalInitiated
   EventDefinition.WithdrawalExecuted
   ModifierDefinition.onlyAuthorizedClient
   ModifierDefinition.onlyAuthorizedWithdrawer
   ModifierDefinition.onlyPauser
   FunctionDefinition.constructor
   FunctionDefinition.setClient
   FunctionDefinition.authorizedClients
   FunctionDefinition.getAuthorizedClients
   FunctionDefinition.authorizedClientCount
   FunctionDefinition.setWithdrawer
   FunctionDefinition.setSetAsideBuffer
   FunctionDefinition.setSetAsideBufferRecipient
   FunctionDefinition.setPauser
   FunctionDefinition.pauser
   FunctionDefinition.pause
   FunctionDefinition.unpause
   FunctionDefinition.emergencyWithdraw
   FunctionDefinition.totalWithdrawal
   FunctionDefinition.skimSurplus
   FunctionDefinition._emergencyWithdraw
   FunctionDefinition._totalWithdraw
   FunctionDefinition._skimSurplus
   FunctionDefinition.underlying
   FunctionDefinition.principalOf
   FunctionDefinition.totalBalanceOf
   FunctionDefinition.previewExitFor
   FunctionDefinition.balanceOf
   FunctionDefinition.getTotalDeposited
   FunctionDefinition.getTotalShares
   FunctionDefinition.deposit
   FunctionDefinition.withdraw
   FunctionDefinition.depositAsOwner
   FunctionDefinition.withdrawAsOwner
   FunctionDefinition.relinquishPrincipal
   FunctionDefinition.relinquishPrincipalAsOwner
   FunctionDefinition._relinquishInternal
   FunctionDefinition._depositInternal
   FunctionDefinition._withdrawInternal
   FunctionDefinition._positionValue
   FunctionDefinition._acquireShares
   FunctionDefinition._disposeShares
   FunctionDefinition._updateWithdrawalStatus
   FunctionDefinition._initiateWithdrawal
   FunctionDefinition._executeWithdrawal
   FunctionDefinition._uint256ToString

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-19"></a>[NC-19] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

41:     uint256 public constant MAX_BPS = 10000;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="NC-20"></a>[NC-20] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (3)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

35:     mapping(address => mapping(address => Route)) private routes;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

45:     mapping(address => mapping(address => uint256)) internal clientBalances;

49:     mapping(address => uint256) internal totalDeposited;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="NC-21"></a>[NC-21] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (9)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

41:     event Swapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

95:     event ClientAuthorizationSet(address indexed client, bool authorized);

102:     event WithdrawerAuthorizationSet(address indexed withdrawer, bool authorized);

110:     event SetAsideBufferSet(address indexed client, uint256 oldPercent, uint256 newPercent);

139:     event PrincipalRelinquished(address indexed token, address indexed client, uint256 amount, uint256 newPrincipal);

182:     event EmergencyWithdraw(address indexed owner, uint256 amount);

199:     event WithdrawalInitiated(

210:     event WithdrawalExecuted(address indexed token, address indexed client, uint256 amount, uint256 executedAt);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

50:     event SlippageToleranceSet(uint256 oldBps, uint256 newBps);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="NC-22"></a>[NC-22] `public` functions not called by the contract should be declared `external` instead

*Instances (1)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

115:     function isPairFullyConfigured(address tokenA, address tokenB) public view returns (bool) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

### <a name="NC-23"></a>[NC-23] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (5)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

75:         for (uint256 i = 0; i < 11; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

396:         for (uint256 i = 0; i < clients.length; i++) {

436:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

275:         for (uint256 i = 0; i < clients.length; i++) {

315:         for (uint256 i = 0; i < clients.length; i++) {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 1 |
| [L-2](#L-2) | Use a 2-step ownership transfer pattern | 2 |
| [L-3](#L-3) | Some tokens may revert when zero value transfers are made | 2 |
| [L-4](#L-4) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-5](#L-5) | `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 2 |
| [L-6](#L-6) | Division by zero not prevented | 7 |
| [L-7](#L-7) | Owner can renounce while system is paused | 1 |
| [L-8](#L-8) | Possible rounding issue | 7 |
| [L-9](#L-9) | Loss of precision | 12 |
| [L-10](#L-10) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 3 |
| [L-11](#L-11) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-12](#L-12) | File allows a version of solidity that is susceptible to an assembly optimizer bug | 3 |
| [L-13](#L-13) | Unsafe ERC20 operation(s) | 1 |
### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (1)*:
```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

50:         IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="L-2"></a>[L-2] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

20: contract CurveAMMAdapter is IAMMAdapter, Ownable {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

18: abstract contract AYieldStrategy is IYieldStrategy, IPausable, Ownable, ReentrancyGuard, Pausable {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="L-3"></a>[L-3] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (2)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

132:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

277:         IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="L-4"></a>[L-4] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

368:         emit PauserSet(oldPauser, newPauser);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="L-5"></a>[L-5] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (2)*:
```solidity
File: src/AYieldStrategy.sol

439:                         "AYieldStrategy: withdrawal still in waiting period, executable at timestamp: ",

440:                         _uint256ToString(executableAt)

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="L-6"></a>[L-6] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (7)*:
```solidity
File: src/AYieldStrategy.sol

549:         return (totalValue * principal) / totalDeposited[token];

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

298:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

403:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

438:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

190:         uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

282:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

317:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="L-7"></a>[L-7] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

364:     function setPauser(address newPauser) external onlyOwner {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="L-8"></a>[L-8] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (7)*:
```solidity
File: src/AYieldStrategy.sol

549:         return (totalValue * principal) / totalDeposited[token];

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

298:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

403:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

438:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

190:         uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

282:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

317:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="L-9"></a>[L-9] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (12)*:
```solidity
File: src/AYieldStrategy.sol

549:         return (totalValue * principal) / totalDeposited[token];

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

108:         return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

134:         return idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

246:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

298:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

303:             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

354:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

403:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

438:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

190:         uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

282:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

317:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="L-10"></a>[L-10] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (3)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="L-11"></a>[L-11] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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
File: src/AMMAdapters/CurveAMMAdapter.sol

6: import "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

6: import "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

### <a name="L-12"></a>[L-12] File allows a version of solidity that is susceptible to an assembly optimizer bug
In solidity versions 0.8.13 and 0.8.14, there is an [optimizer bug](https://github.com/ethereum/solidity-blog/blob/499ab8abc19391be7b7b34f88953a067029a5b45/_posts/2022-06-15-inline-assembly-memory-side-effects-bug.md) where, if the use of a variable is in a separate `assembly` block from the block in which it was stored, the `mstore` operation is optimized out, leading to uninitialized memory. The code currently does not have such a pattern of execution, but it does use `mstore`s in `assembly` blocks, so it is a risk for future changes. The affected solidity versions should be avoided if at all possible.

*Instances (3)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

2: pragma solidity ^0.8.13;

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)

### <a name="L-13"></a>[L-13] Unsafe ERC20 operation(s)

*Instances (1)*:
```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

50:         IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626YieldStrategy.sol)


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 15 |
| [M-3](#M-3) | `increaseAllowance/decreaseAllowance` won't work on mainnet for USDT | 4 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

132:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (15)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

20: contract CurveAMMAdapter is IAMMAdapter, Ownable {

48:     constructor(address _owner, address _router) Ownable(_owner) {

68:     ) external onlyOwner {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AMMAdapters/CurveAMMAdapter.sol)

```solidity
File: src/AYieldStrategy.sol

18: abstract contract AYieldStrategy is IYieldStrategy, IPausable, Ownable, ReentrancyGuard, Pausable {

250:     constructor(address _owner, address _underlyingToken) Ownable(_owner) {

265:     function setClient(address client, bool _auth) external override onlyOwner {

309:     function setWithdrawer(address withdrawer, bool _auth) external onlyOwner {

335:     function setSetAsideBuffer(address client, uint256 bufferPercent) external override onlyOwner {

352:     function setSetAsideBufferRecipient(address _recipient) external onlyOwner {

364:     function setPauser(address newPauser) external onlyOwner {

402:     function emergencyWithdraw(uint256 amount) external override onlyOwner {

417:     function totalWithdrawal(address token, address client) external override onlyOwner nonReentrant whenNotPaused {

677:     function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {

687:     function relinquishPrincipalAsOwner(address client, uint256 amount) external override onlyOwner nonReentrant {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/AYieldStrategy.sol)

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

89:     function setSlippageTolerance(uint256 _bps) external onlyOwner {

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

### <a name="M-3"></a>[M-3] `increaseAllowance/decreaseAllowance` won't work on mainnet for USDT
On mainnet, the mitigation to be compatible with `increaseAllowance/decreaseAllowance` isn't applied: https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7#code, meaning it reverts on setting a non-zero & non-max allowance, unless the allowance is already zero.

*Instances (4)*:
```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

220:         underlyingToken.safeIncreaseAllowance(address(ammAdapter), amount);

249:         IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);

306:             IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);

355:         IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);

```
[Link to code](https://github.com/Behodler/reflax-yield-vault/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol)

