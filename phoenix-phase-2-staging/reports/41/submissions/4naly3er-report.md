# 4naly3er report: phoenix-phase-2-staging run 41 (script audit, entry point `unipooler-cutover`)

> **Provenance.** Generated 2026-10-18 by `tools/4naly3er` (`yarn analyze <audits>/phoenix-phase-2-staging/work/ <scope>`).
> - **basePath**: the writable `work/` clone at `e75ee0776efcf20918b7db71d717eafb61bbd1a6` (same commit as `src/`). All 4 scope
>   files were checked with `cmp` and are byte-identical to `src/`.
> - **Import resolution**: `work/remappings.txt` was confirmed identical to a fresh `forge remappings`. The upstream repo
>   declares remappings only in `foundry.toml`.
> - **Read-only rule**: nothing was written under `src/`.
> - **Scope**: the first-party in-script closure of `unipooler-cutover` (`closure-manifest.json` → `solidity`: the script,
>   the verifier and the core helper) plus `src/periphery/UniswapHelper.sol`, the site of L-04. The nested
>   `lib/yield-claim-nft` sources (escrow, hook, BalancerPoolerV2) sit under `lib/` and are not in this project's scope;
>   they are covered by the yield-claim-nft audit.
>
> **Run status.** Each file was run as its own one-line scope, sequentially. **4 of 4 files analysed, exit 0, 0 `Cannot compile AST`.**
>
> **Category totals (sum of per-file category rows):** H 1 · M 2 · L 21 · NC 43 · Gas 37.

| # | File | Result | H | M | L | NC | Gas |
|---|---|---|--:|--:|--:|--:|--:|
| 01 | `script/DeployMainnetUniPoolerCutover.s.sol` | analysed | 0 | 1 | 6 | 16 | 14 |
| 02 | `script/VerifyUniPoolerCutover.s.sol` | analysed | 0 | 0 | 3 | 6 | 6 |
| 03 | `script/helpers/UniPoolerCutoverCore.sol` | analysed | 0 | 0 | 6 | 13 | 10 |
| 04 | `src/periphery/UniswapHelper.sol` | analysed | 1 | 1 | 6 | 8 | 7 |

## Triage of the automated output

**No 4naly3er item rises to a finding.** Every High and Medium hit was examined:

- **H `get_dy_underlying()` is not a flash-loan-resistant price** (`UniswapHelper.sol` L559/L576). `UniswapHelper.sol` is
  unchanged since run 40 (`git diff a4f9f3c e75ee07` is empty for this file), and run 40 triaged this hit: it is used only in
  the view quote paths, never as a settlement price, and every swap is bounded by the caller's `minOut`. False positive,
  carried unchanged.
- **M "Contracts are vulnerable to fee-on-transfer accounting-related issues"** (`UniswapHelper.sol`). The helper moves only
  sUSDS, USDS, phUSD, USDC, DOLA and USDe, none of which charges a transfer fee. FoT is a known-invalid class.
- **M "`block.number` means different things on different L2s"** (`DeployMainnetUniPoolerCutover.s.sol` L477, a progress-file
  serialisation). Mainnet-only operator script. Not applicable.

**Low hits on the cutover files:**
- `approve()` / deprecated-approve / unsafe-ERC20 (`DeployMainnetUniPoolerCutover.s.sol` L522): the preview-only test mint,
  approving a known token in a pranked simulation. No mainnet path.
- Division by zero / rounding (`UniPoolerCutoverCore.sol` L587, the BPT pro-rata share): `supply` is the live BPT supply, which
  is non-zero while the old pooler holds BPT. The other division-by-zero hits match `console.log` string lines (false positives).
- "Signature use at deadlines should be allowed" (`UniPoolerCutoverCore.sol` L421/L423): a deliberate strictly-future
  `seedDeadline` bound; no signature involved.
- "Sweeping may break accounting" (`UniPoolerCutoverCore.sol` L680/L690, `rescueERC20`): sUSDS and USDS are single-address
  tokens. The real defect on these lines, the amount being baked in forge's local pass, is reported as **Q-01** (`pps41q1`).
- SafeCast (L396-399): step-number digit formatting for a log label, bounded `< 100`.
- `PUSH0` (verifier, helper): mainnet-only.

None of these overlaps the root causes of L-01..L-04 or Q-01..Q-03 beyond the Q-01 note above, and none shows an exploit
path. The remaining items are NC or gas on one-shot operator scripts.

---

# Raw per-file outputs (unchanged)

# Part 01: `script/DeployMainnetUniPoolerCutover.s.sol`




## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 4 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 3 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 2 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 1 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 3 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 55 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 36 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 11 |
| [GAS-9](#GAS-9) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 3 |
| [GAS-10](#GAS-10) | Using `private` rather than `public` for constants, saves gas | 23 |
| [GAS-11](#GAS-11) | Splitting require() statements that use && saves gas | 3 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 2 |
| [GAS-13](#GAS-13) | Use != 0 instead of > 0 for unsigned integer comparison | 7 |
| [GAS-14](#GAS-14) | `internal` functions not called by the contract should be removed | 2 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (4)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

256:             residual += _reportEscrowResidual(escrow, BPT, "BPT");

257:             residual += _reportEscrowResidual(escrow, SUSDS, "sUSDS");

258:             residual += _reportEscrowResidual(escrow, PHUSD, "phUSD");

259:             residual += _reportEscrowResidual(escrow, USDS, "USDS");

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (3)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

255:         if (escrow != address(0)) {

460:         if (completed && np != address(0) && np.code.length > 0 && d == np) {

502:         string memory entry = vm.serializeBool(k, "deployed", addr != address(0));

```

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (2)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

339:     bool public isPreview;

340:     bool public cutoverRanThisRun;

```

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

237:         for (uint256 i = 0; i < ps.length; i++) {

```

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (3)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

371:         _endOwnerSession(isPreview);

380:             _previewEndToEnd(_result);

386:         _writeProgress(_result);

```

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (55)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

4: import "@forge-std/Script.sol";

5: import "@forge-std/StdCheats.sol";

6: import "@forge-std/console.sol";

7: import {UniPoolerV2} from "@yield-claim-nft/dispatchers/UniPoolerV2.sol";

18: } from "./helpers/UniPoolerCutoverCore.sol";

84:     string public constant ADDRESS_BOOK = "server/deployments/mainnet-addresses.ts";

85:     string public constant PROGRESS_FILE = "server/deployments/progress.unipooler-cutover.1.json";

92:     address public constant OLD_POOLER = 0x7f6874332c4629429d70D15f685A8230323F11F1; // BalancerPooler (V2, index 4)

93:     address public constant MINT_DEBT_HOOK = 0x4A26ad83306a2F17155799fDD9449f77eb3F8bD7; // BalancerPoolerMintDebtHook

94:     address public constant NFT_MINTER = 0x39Af088408e815844c567037C157B31d48d2E10F; // NFTMinter (V2)

95:     address public constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // UniswapV2Router (Router02)

96:     address public constant BALANCER_ROUTER = 0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd; // BalancerRouter (V3)

97:     address public constant BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9; // BalancerVault (V3)

98:     address public constant BPT = 0x642BB6860b4776CC10b26B8f361Fd139E7f0db04; // BalancerPool (phUSD/sUSDS)

102:     address public constant MULTI_POOLER = 0xd1E5774159381915f5579dFd68507E2614f67b51; // authorized pooler #2

105:     address public constant UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Router02.factory()

106:     address public constant POOLER_7702_EOA = 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F; // authorized pooler #3

107:     address public constant POOLER_EOA = 0x630966B668b321Cc6441754f96519a55F72Cd476; // authorized pooler #4

137:         uint256 start = at + bytes(needle).length;

138:         require(src.length >= start + 42, string.concat("address book: truncated entry for ", key));

140:         for (uint256 i; i < 42; i++) {

141:             lit[i] = src[start + i];

149:             string.concat("address book: mainnet-addresses.ts ", key, " != the cutover script's constant")

237:         for (uint256 i = 0; i < ps.length; i++) {

256:             residual += _reportEscrowResidual(escrow, BPT, "BPT");

257:             residual += _reportEscrowResidual(escrow, SUSDS, "sUSDS");

258:             residual += _reportEscrowResidual(escrow, PHUSD, "phUSD");

259:             residual += _reportEscrowResidual(escrow, USDS, "USDS");

260:             if (residual == 0) console.log("OK: escrow holds 0 BPT / sUSDS / phUSD / USDS.");

271:                 " (a third-party donation, or a cutover step that did not land - check the receipts):"

293:                 "  WARNING: OWNER holds BPT. It is NOT part of the cutover (F-02-052); exit it separately if wanted."

317:         uint256 minPhusdOut = (phusdOut * (CUTOVER_MAX_BPS - POOL_PREVIEW_TOLERANCE_BPS)) / CUTOVER_MAX_BPS;

318:         uint256 minLP = (expectedLP * (CUTOVER_MAX_BPS - POOL_PREVIEW_TOLERANCE_BPS)) / CUTOVER_MAX_BPS;

324:         lpGained = ICutoverUniV2Pair(pair).balanceOf(newPooler) - lpBefore;

326:         console.log("  quotePool-floored pool() simulated OK; sUSDS in:", sIn);

350:         console.log("  MAINNET INDEX-4 CUTOVER BalancerPoolerV2 -> UniPoolerV2 (story 103)");

352:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

362:         console.log("Preflight OK: constants == mainnet-addresses.ts and == the old pooler's live wiring.");

377:         console.log("OK: post-cutover wiring and drained balances asserted.");

382:                 "PREVIEW: nothing broadcast, progress file NOT written (preview CREATE addresses are fork-local)."

406:             "MIN_SUSDS_OUT_WEI and MIN_PHUSD_OUT_WEI must both be set and non-zero: eval \"$(node scripts/quote-balancer-exit-min-amounts.js 10)\""

419:         require(tokens.length == 2, "pool not two-token");

429:         p.seedDeadline = block.timestamp + SEED_DEADLINE_OFFSET;

453:             console.log("No progress file - fresh cutover.");

462:             console.log("Nothing to do - no transaction sent. Run `npm run unipooler-cutover:verify`.");

466:             "Progress file server/deployments/progress.unipooler-cutover.1.json exists but the cutover is not live on chain - it is POISONED (forge writes it in its local pass). Resume from broadcast receipts, not the progress file, and rename it to progress.unipooler-cutover.1.POISONED.<ts>.bak"

512:         require(isPreview, "preview-only E2E outside preview");

514:         console.log("--- PREVIEW E2E: test mint at index 4 + quotePool-floored pool() ---");

554:         console.log("  unsynced pair donation at step 2 - sUSDS:", r.pairDonationSUSDS);

555:         console.log("  unsynced pair donation at step 2 - phUSD:", r.pairDonationPhUSD);

556:         console.log("  BPT old pooler -> escrow:", r.bptWithdrawn);

558:         console.log("  pair seeded - sUSDS:", r.sUSDSSeeded);

559:         console.log("  pair seeded - phUSD:", r.phUSDSeeded);

561:         console.log("  sUSDS rescued old -> UniPoolerV2:", r.sUSDSRescued);

562:         console.log("  USDS parked old -> escrow -> wrapped:", r.usdsRescued);

```

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (36)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

171:         require(old.pool() == BPT, "preflight: old pooler pool() != BalancerPool");

172:         require(old.vault() == BALANCER_VAULT, "preflight: old pooler vault() != BalancerVault");

173:         require(old.sUSDS() == SUSDS, "preflight: old pooler sUSDS() != SUSDS");

174:         require(old.primeToken() == USDS, "preflight: old pooler primeToken() != USDS");

175:         require(ICutoverMintDebtHook(MINT_DEBT_HOOK).phUSD() == PHUSD, "preflight: hook phUSD() != PhUSD");

176:         require(ICutoverUniV2Router(UNIV2_ROUTER).factory() == UNIV2_FACTORY, "preflight: Router02.factory()");

177:         require(BALANCER_ROUTER.code.length > 0, "preflight: no code at BalancerRouter");

212:         require(newPooler.code.length > 0, "verify: UniPooler has no code");

214:         require(d == newPooler, "verify: configs(4).dispatcher != UniPooler");

215:         require(!disabled, "verify: index 4 disabled");

220:         require(address(np.hook()) == MINT_DEBT_HOOK, "verify: UniPooler.hook() != BalancerPoolerMintDebtHook");

221:         require(np.owner() == OWNER, "verify: UniPooler owner != OWNER");

222:         require(_minterOf(newPooler) == NFT_MINTER, "verify: UniPooler minter != NFTMinter");

223:         require(np.pair() == pair, "verify: UniPooler.pair() != PhusdSusdsPair");

227:         require(np.sUSDS() == SUSDS && np.phUSD() == PHUSD, "verify: UniPooler tokens");

228:         require(np.router() == UNIV2_ROUTER, "verify: UniPooler router");

231:         require(np.psm() == old.psm(), "verify: psm not copied");

232:         require(np.maxTout() == old.maxTout(), "verify: maxTout not copied");

233:         require(np.batchMinter() == old.batchMinter(), "verify: batchMinter not copied");

234:         require(np.batchDonationSize() == old.batchDonationSize(), "verify: batchDonationSize not copied");

235:         require(np.nudgeStreamer() == old.nudgeStreamer(), "verify: nudgeStreamer not copied");

238:             require(np.poolerAuthVersion(ps[i]) == np.authVersion(), "verify: pooler not authorized on UniPooler");

240:         require(old.paused(), "verify: old pooler not paused");

241:         require(_minterOf(OLD_POOLER) == OWNER, "verify: old pooler minter != OWNER");

252:         require(ICutoverERC20(BPT).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds BPT");

253:         require(ICutoverERC20(SUSDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds sUSDS");

254:         require(ICutoverERC20(USDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds USDS (parked USDS not moved)");

319:         require(minPhusdOut > 0 && minLP > 0, "verify: quotePool floors are zero");

325:         require(lpGained >= minLP, "verify: pool() minted less LP than its quotePool floor");

352:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

419:         require(tokens.length == 2, "pool not two-token");

422:             require(tokens[1] == PHUSD, "pool tokens mismatch");

425:             require(tokens[0] == PHUSD && tokens[1] == SUSDS, "pool tokens mismatch");

512:         require(isPreview, "preview-only E2E outside preview");

525:         require(ICutoverERC20(SUSDS).balanceOf(r.newPooler) > sBefore, "preview: test mint did not wrap on UniPoolerV2");

526:         require(ICutoverMintDebtHook(MINT_DEBT_HOOK).mintDebt() > debtBefore, "preview: test mint accrued no debt");

```

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (11)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

252:         require(ICutoverERC20(BPT).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds BPT");

253:         require(ICutoverERC20(SUSDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds sUSDS");

254:         require(ICutoverERC20(USDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds USDS (parked USDS not moved)");

265:         uint256 b = ICutoverERC20(token).balanceOf(escrow);

289:         b = ICutoverERC20(BPT).balanceOf(OWNER);

311:         uint256 sIn = ICutoverERC20(SUSDS).balanceOf(newPooler);

321:         uint256 lpBefore = ICutoverUniV2Pair(pair).balanceOf(newPooler);

324:         lpGained = ICutoverUniV2Pair(pair).balanceOf(newPooler) - lpBefore;

518:         uint256 sBefore = ICutoverERC20(SUSDS).balanceOf(r.newPooler);

525:         require(ICutoverERC20(SUSDS).balanceOf(r.newPooler) > sBefore, "preview: test mint did not wrap on UniPoolerV2");

528:         console.log("  UniPoolerV2 sUSDS after mint:", ICutoverERC20(SUSDS).balanceOf(r.newPooler));

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

*Instances (3)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

140:         for (uint256 i; i < 42; i++) {

237:         for (uint256 i = 0; i < ps.length; i++) {

514:         console.log("--- PREVIEW E2E: test mint at index 4 + quotePool-floored pool() ---");

```

### <a name="GAS-10"></a>[GAS-10] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (23)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

81:     uint256 public constant CHAIN_ID = 1;

82:     string public constant NETWORK_NAME = "mainnet";

84:     string public constant ADDRESS_BOOK = "server/deployments/mainnet-addresses.ts";

85:     string public constant PROGRESS_FILE = "server/deployments/progress.unipooler-cutover.1.json";

89:     address public constant OWNER = 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6;

92:     address public constant OLD_POOLER = 0x7f6874332c4629429d70D15f685A8230323F11F1; // BalancerPooler (V2, index 4)

93:     address public constant MINT_DEBT_HOOK = 0x4A26ad83306a2F17155799fDD9449f77eb3F8bD7; // BalancerPoolerMintDebtHook

94:     address public constant NFT_MINTER = 0x39Af088408e815844c567037C157B31d48d2E10F; // NFTMinter (V2)

95:     address public constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // UniswapV2Router (Router02)

96:     address public constant BALANCER_ROUTER = 0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd; // BalancerRouter (V3)

97:     address public constant BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9; // BalancerVault (V3)

98:     address public constant BPT = 0x642BB6860b4776CC10b26B8f361Fd139E7f0db04; // BalancerPool (phUSD/sUSDS)

99:     address public constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

100:     address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

101:     address public constant PHUSD = 0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605;

102:     address public constant MULTI_POOLER = 0xd1E5774159381915f5579dFd68507E2614f67b51; // authorized pooler #2

105:     address public constant UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Router02.factory()

106:     address public constant POOLER_7702_EOA = 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F; // authorized pooler #3

107:     address public constant POOLER_EOA = 0x630966B668b321Cc6441754f96519a55F72Cd476; // authorized pooler #4

109:     uint256 public constant DISPATCHER_INDEX = 4;

112:     uint256 public constant EXIT_TOLERANCE_BPS = 50;

114:     uint256 public constant SEED_DEADLINE_OFFSET = 1 hours;

116:     uint256 public constant POOL_PREVIEW_TOLERANCE_BPS = 50;

```

### <a name="GAS-11"></a>[GAS-11] Splitting require() statements that use && saves gas

*Instances (3)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

227:         require(np.sUSDS() == SUSDS && np.phUSD() == PHUSD, "verify: UniPooler tokens");

319:         require(minPhusdOut > 0 && minLP > 0, "verify: quotePool floors are zero");

425:             require(tokens[0] == PHUSD && tokens[1] == SUSDS, "pool tokens mismatch");

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
File: script/DeployMainnetUniPoolerCutover.s.sol

140:         for (uint256 i; i < 42; i++) {

237:         for (uint256 i = 0; i < ps.length; i++) {

```

### <a name="GAS-13"></a>[GAS-13] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (7)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

177:         require(BALANCER_ROUTER.code.length > 0, "preflight: no code at BalancerRouter");

193:         exists = bytes(json).length > 0;

212:         require(newPooler.code.length > 0, "verify: UniPooler has no code");

291:         if (b > 0) {

319:         require(minPhusdOut > 0 && minLP > 0, "verify: quotePool floors are zero");

405:             minS > 0 && minP > 0,

460:         if (completed && np != address(0) && np.code.length > 0 && d == np) {

```

### <a name="GAS-14"></a>[GAS-14] `internal` functions not called by the contract should be removed
If the functions are required by an interface, the contract should inherit from that interface and use the `override` keyword

*Instances (2)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

202:     function _progressUint(string memory json, string memory key) internal view returns (uint256) {

299:     function _reservesSP(address pair) internal view returns (uint256 rS, uint256 rP) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Array indices should be referenced via `enum`s rather than via numeric literals | 11 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 12 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 33 |
| [NC-4](#NC-4) | Delete rogue `console.log` imports | 1 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 5 |
| [NC-6](#NC-6) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-7](#NC-7) | Functions should not be longer than 50 lines | 28 |
| [NC-8](#NC-8) | Change int to int256 | 5 |
| [NC-9](#NC-9) | Interfaces should be defined in separate files from their usage | 1 |
| [NC-10](#NC-10) | Lines are too long | 1 |
| [NC-11](#NC-11) | NatSpec is completely non-existent on functions that should have them | 4 |
| [NC-12](#NC-12) | `address`s shouldn't be hard-coded | 15 |
| [NC-13](#NC-13) | Adding a `return` statement when the function defines a named return variable, is redundant | 1 |
| [NC-14](#NC-14) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-15](#NC-15) | Constants should be defined rather than using magic numbers | 1 |
| [NC-16](#NC-16) | Variables need not be initialized to zero | 1 |
### <a name="NC-1"></a>[NC-1] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (11)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

122:         ps[0] = OWNER;

123:         ps[1] = MULTI_POOLER;

124:         ps[2] = POOLER_7702_EOA;

125:         ps[3] = POOLER_EOA;

421:         if (tokens[0] == SUSDS) {

422:             require(tokens[1] == PHUSD, "pool tokens mismatch");

423:             (p.minAmountsOut[0], p.minAmountsOut[1]) = (minS, minP);

425:             require(tokens[0] == PHUSD && tokens[1] == SUSDS, "pool tokens mismatch");

426:             (p.minAmountsOut[0], p.minAmountsOut[1]) = (minP, minS);

540:         console.log("  minAmountsOut[0] (pool order):", p.minAmountsOut[0]);

541:         console.log("  minAmountsOut[1] (pool order):", p.minAmountsOut[1]);

```

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (12)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

138:         require(src.length >= start + 42, string.concat("address book: truncated entry for ", key));

140:         for (uint256 i; i < 42; i++) {

215:         require(!disabled, "verify: index 4 disabled");

313:             deal(SUSDS, newPooler, 100e18);

314:             sIn = 100e18;

350:         console.log("  MAINNET INDEX-4 CUTOVER BalancerPoolerV2 -> UniPoolerV2 (story 103)");

406:             "MIN_SUSDS_OUT_WEI and MIN_PHUSD_OUT_WEI must both be set and non-zero: eval \"$(node scripts/quote-balancer-exit-min-amounts.js 10)\""

419:         require(tokens.length == 2, "pool not two-token");

461:             console.log("Progress file is completed and its UniPooler is live at index 4:", np);

514:         console.log("--- PREVIEW E2E: test mint at index 4 + quotePool-floored pool() ---");

554:         console.log("  unsynced pair donation at step 2 - sUSDS:", r.pairDonationSUSDS);

555:         console.log("  unsynced pair donation at step 2 - phUSD:", r.pairDonationPhUSD);

```

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (33)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

135:         if (at == type(uint256).max) return address(0);

198:         if (!vm.keyExistsJson(json, key)) return address(0);

212:         require(newPooler.code.length > 0, "verify: UniPooler has no code");

214:         require(d == newPooler, "verify: configs(4).dispatcher != UniPooler");

215:         require(!disabled, "verify: index 4 disabled");

217:             ICutoverMintDebtHook(MINT_DEBT_HOOK).dispatcher() == newPooler, "verify: hook.dispatcher() != UniPooler"

220:         require(address(np.hook()) == MINT_DEBT_HOOK, "verify: UniPooler.hook() != BalancerPoolerMintDebtHook");

221:         require(np.owner() == OWNER, "verify: UniPooler owner != OWNER");

222:         require(_minterOf(newPooler) == NFT_MINTER, "verify: UniPooler minter != NFTMinter");

223:         require(np.pair() == pair, "verify: UniPooler.pair() != PhusdSusdsPair");

225:             pair == ICutoverUniV2Factory(UNIV2_FACTORY).getPair(SUSDS, PHUSD), "verify: pair is not the canonical pair"

227:         require(np.sUSDS() == SUSDS && np.phUSD() == PHUSD, "verify: UniPooler tokens");

228:         require(np.router() == UNIV2_ROUTER, "verify: UniPooler router");

231:         require(np.psm() == old.psm(), "verify: psm not copied");

232:         require(np.maxTout() == old.maxTout(), "verify: maxTout not copied");

233:         require(np.batchMinter() == old.batchMinter(), "verify: batchMinter not copied");

234:         require(np.batchDonationSize() == old.batchDonationSize(), "verify: batchDonationSize not copied");

235:         require(np.nudgeStreamer() == old.nudgeStreamer(), "verify: nudgeStreamer not copied");

238:             require(np.poolerAuthVersion(ps[i]) == np.authVersion(), "verify: pooler not authorized on UniPooler");

240:         require(old.paused(), "verify: old pooler not paused");

241:         require(_minterOf(OLD_POOLER) == OWNER, "verify: old pooler minter != OWNER");

252:         require(ICutoverERC20(BPT).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds BPT");

253:         require(ICutoverERC20(SUSDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds sUSDS");

254:         require(ICutoverERC20(USDS).balanceOf(OLD_POOLER) == 0, "verify: old pooler holds USDS (parked USDS not moved)");

260:             if (residual == 0) console.log("OK: escrow holds 0 BPT / sUSDS / phUSD / USDS.");

266:         if (b == 0) return 0;

293:                 "  WARNING: OWNER holds BPT. It is NOT part of the cutover (F-02-052); exit it separately if wanted."

319:         require(minPhusdOut > 0 && minLP > 0, "verify: quotePool floors are zero");

325:         require(lpGained >= minLP, "verify: pool() minted less LP than its quotePool floor");

359:         if (_alreadyCompleted()) return;

437:         if (preview) vm.startPrank(OWNER);

442:         if (preview) vm.stopPrank();

462:             console.log("Nothing to do - no transaction sent. Run `npm run unipooler-cutover:verify`.");

```

### <a name="NC-4"></a>[NC-4] Delete rogue `console.log` imports
These shouldn't be deployed in production

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

6: import "@forge-std/console.sol";

```

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (5)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

138:         require(src.length >= start + 42, string.concat("address book: truncated entry for ", key));

147:         require(

204:         require(vm.keyExistsJson(json, k), string.concat("progress file: missing cutover.", key));

422:             require(tokens[1] == PHUSD, "pool tokens mismatch");

425:             require(tokens[0] == PHUSD && tokens[1] == SUSDS, "pool tokens mismatch");

```

### <a name="NC-6"></a>[NC-6] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

1: 
   Current order:
   public poolers
   internal _bookAddress
   internal _requireBook
   internal _preflightAddresses
   internal _progressFile
   internal _readProgress
   internal _progressAddress
   internal _progressUint
   internal _checkWiring
   internal _checkDrained
   private _reportEscrowResidual
   internal _minterOf
   internal _reportOwnerBpt
   internal _reservesSP
   internal _simulateQuotedPool
   internal _previewModeFromEnv
   external result
   external run
   internal _exitModeFromEnv
   internal _minAmountsFromEnv
   internal _buildParams
   internal _beginOwnerSession
   internal _endOwnerSession
   internal _alreadyCompleted
   internal _writeProgress
   internal _serializeEntry
   internal _previewEndToEnd
   internal _logParams
   internal _logResult
   external mint
   
   Suggested order:
   external result
   external run
   external mint
   public poolers
   internal _bookAddress
   internal _requireBook
   internal _preflightAddresses
   internal _progressFile
   internal _readProgress
   internal _progressAddress
   internal _progressUint
   internal _checkWiring
   internal _checkDrained
   internal _minterOf
   internal _reportOwnerBpt
   internal _reservesSP
   internal _simulateQuotedPool
   internal _previewModeFromEnv
   internal _exitModeFromEnv
   internal _minAmountsFromEnv
   internal _buildParams
   internal _beginOwnerSession
   internal _endOwnerSession
   internal _alreadyCompleted
   internal _writeProgress
   internal _serializeEntry
   internal _previewEndToEnd
   internal _logParams
   internal _logResult
   private _reportEscrowResidual

```

### <a name="NC-7"></a>[NC-7] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (28)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

120:     function poolers() public pure returns (address[] memory ps) {

132:     function _bookAddress(string memory book, string memory key) internal pure returns (address) {

146:     function _requireBook(string memory book, string memory key, address expected) internal pure {

183:     function _progressFile() internal view virtual returns (string memory) {

187:     function _readProgress() internal view returns (bool exists, string memory json) {

196:     function _progressAddress(string memory json, string memory name) internal view returns (address) {

202:     function _progressUint(string memory json, string memory key) internal view returns (uint256) {

211:     function _checkWiring(address newPooler, address pair) internal view {

251:     function _checkDrained(address escrow) internal view returns (uint256 residual) {

264:     function _reportEscrowResidual(address escrow, address token, string memory name) private view returns (uint256) {

283:     function _minterOf(address dispatcher) internal view returns (address) {

288:     function _reportOwnerBpt() internal view returns (uint256 b) {

299:     function _reservesSP(address pair) internal view returns (uint256 rS, uint256 rP) {

308:     function _simulateQuotedPool(address newPooler) internal returns (uint256 lpGained) {

333:     function _previewModeFromEnv() internal view virtual returns (bool) {

344:     function result() external view returns (CutoverResult memory) {

392:     function _exitModeFromEnv() internal view virtual returns (ExitMode) {

397:     function _minAmountsFromEnv() internal view virtual returns (uint256 minSUSDS, uint256 minPhUSD) {

402:     function _buildParams() internal view returns (CutoverParams memory p) {

436:     function _beginOwnerSession(bool preview) internal virtual {

441:     function _endOwnerSession(bool preview) internal virtual {

450:     function _alreadyCompleted() internal view returns (bool) {

470:     function _writeProgress(CutoverResult memory r) internal {

499:     function _serializeEntry(string memory name, address addr) internal returns (string memory contractsJson) {

511:     function _previewEndToEnd(CutoverResult memory r) internal {

535:     function _logParams(CutoverParams memory p) internal pure {

546:     function _logResult(CutoverResult memory r) internal pure {

569:     function mint(uint256 index, address recipient) external returns (bool);

```

### <a name="NC-8"></a>[NC-8] Change int to int256
Throughout the code base, some variables are declared as `int`. To favor explicitness, consider changing all instances of `int` to `int256`

*Instances (5)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

514:         console.log("--- PREVIEW E2E: test mint at index 4 + quotePool-floored pool() ---");

525:         require(ICutoverERC20(SUSDS).balanceOf(r.newPooler) > sBefore, "preview: test mint did not wrap on UniPoolerV2");

526:         require(ICutoverMintDebtHook(MINT_DEBT_HOOK).mintDebt() > debtBefore, "preview: test mint accrued no debt");

527:         console.log("  test mint dispatched via UniPoolerV2; price paid:", price);

529:         console.log("  hook mint debt after mint:", ICutoverMintDebtHook(MINT_DEBT_HOOK).mintDebt());

```

### <a name="NC-9"></a>[NC-9] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

568: interface IPreviewMinter {

```

### <a name="NC-10"></a>[NC-10] Lines are too long
Usually lines in source code are limited to [80](https://softwareengineering.stackexchange.com/questions/148677/why-is-80-characters-the-standard-limit-for-code-width) characters. Today's screens are much larger so it's reasonable to stretch this in some cases. Since the files will most likely reside in GitHub, and GitHub starts using a scroll bar in all cases when the length is over [164](https://github.com/aizatto/character-length) characters, the lines below should be split when they reach that length

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

466:             "Progress file server/deployments/progress.unipooler-cutover.1.json exists but the cutover is not live on chain - it is POISONED (forge writes it in its local pass). Resume from broadcast receipts, not the progress file, and rename it to progress.unipooler-cutover.1.POISONED.<ts>.bak"

```

### <a name="NC-11"></a>[NC-11] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (4)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

348:     function run() external {

348:     function run() external {

569:     function mint(uint256 index, address recipient) external returns (bool);

569:     function mint(uint256 index, address recipient) external returns (bool);

```

### <a name="NC-12"></a>[NC-12] `address`s shouldn't be hard-coded
It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (15)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

89:     address public constant OWNER = 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6;

92:     address public constant OLD_POOLER = 0x7f6874332c4629429d70D15f685A8230323F11F1; // BalancerPooler (V2, index 4)

93:     address public constant MINT_DEBT_HOOK = 0x4A26ad83306a2F17155799fDD9449f77eb3F8bD7; // BalancerPoolerMintDebtHook

94:     address public constant NFT_MINTER = 0x39Af088408e815844c567037C157B31d48d2E10F; // NFTMinter (V2)

95:     address public constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // UniswapV2Router (Router02)

96:     address public constant BALANCER_ROUTER = 0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd; // BalancerRouter (V3)

97:     address public constant BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9; // BalancerVault (V3)

98:     address public constant BPT = 0x642BB6860b4776CC10b26B8f361Fd139E7f0db04; // BalancerPool (phUSD/sUSDS)

99:     address public constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

100:     address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

101:     address public constant PHUSD = 0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605;

102:     address public constant MULTI_POOLER = 0xd1E5774159381915f5579dFd68507E2614f67b51; // authorized pooler #2

105:     address public constant UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Router02.factory()

106:     address public constant POOLER_7702_EOA = 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F; // authorized pooler #3

107:     address public constant POOLER_EOA = 0x630966B668b321Cc6441754f96519a55F72Cd476; // authorized pooler #4

```

### <a name="NC-13"></a>[NC-13] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

187:     function _readProgress() internal view returns (bool exists, string memory json) {
             try vm.readFile(_progressFile()) returns (string memory j) {
                 json = j;
             } catch {
                 return (false, "");

```

### <a name="NC-14"></a>[NC-14] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

1: 
   Current order:
   VariableDeclaration.CHAIN_ID
   VariableDeclaration.NETWORK_NAME
   VariableDeclaration.ADDRESS_BOOK
   VariableDeclaration.PROGRESS_FILE
   VariableDeclaration.OWNER
   VariableDeclaration.OLD_POOLER
   VariableDeclaration.MINT_DEBT_HOOK
   VariableDeclaration.NFT_MINTER
   VariableDeclaration.UNIV2_ROUTER
   VariableDeclaration.BALANCER_ROUTER
   VariableDeclaration.BALANCER_VAULT
   VariableDeclaration.BPT
   VariableDeclaration.SUSDS
   VariableDeclaration.USDS
   VariableDeclaration.PHUSD
   VariableDeclaration.MULTI_POOLER
   VariableDeclaration.UNIV2_FACTORY
   VariableDeclaration.POOLER_7702_EOA
   VariableDeclaration.POOLER_EOA
   VariableDeclaration.DISPATCHER_INDEX
   VariableDeclaration.EXIT_TOLERANCE_BPS
   VariableDeclaration.SEED_DEADLINE_OFFSET
   VariableDeclaration.POOL_PREVIEW_TOLERANCE_BPS
   FunctionDefinition.poolers
   FunctionDefinition._bookAddress
   FunctionDefinition._requireBook
   FunctionDefinition._preflightAddresses
   FunctionDefinition._progressFile
   FunctionDefinition._readProgress
   FunctionDefinition._progressAddress
   FunctionDefinition._progressUint
   FunctionDefinition._checkWiring
   FunctionDefinition._checkDrained
   FunctionDefinition._reportEscrowResidual
   VariableDeclaration.DISPATCHER_MINTER_SLOT
   FunctionDefinition._minterOf
   FunctionDefinition._reportOwnerBpt
   FunctionDefinition._reservesSP
   FunctionDefinition._simulateQuotedPool
   FunctionDefinition._previewModeFromEnv
   VariableDeclaration.isPreview
   VariableDeclaration.cutoverRanThisRun
   VariableDeclaration.exitModeUsed
   VariableDeclaration._result
   FunctionDefinition.result
   FunctionDefinition.run
   FunctionDefinition._exitModeFromEnv
   FunctionDefinition._minAmountsFromEnv
   FunctionDefinition._buildParams
   FunctionDefinition._beginOwnerSession
   FunctionDefinition._endOwnerSession
   FunctionDefinition._alreadyCompleted
   FunctionDefinition._writeProgress
   FunctionDefinition._serializeEntry
   FunctionDefinition._previewEndToEnd
   FunctionDefinition._logParams
   FunctionDefinition._logResult
   FunctionDefinition.mint
   
   Suggested order:
   VariableDeclaration.CHAIN_ID
   VariableDeclaration.NETWORK_NAME
   VariableDeclaration.ADDRESS_BOOK
   VariableDeclaration.PROGRESS_FILE
   VariableDeclaration.OWNER
   VariableDeclaration.OLD_POOLER
   VariableDeclaration.MINT_DEBT_HOOK
   VariableDeclaration.NFT_MINTER
   VariableDeclaration.UNIV2_ROUTER
   VariableDeclaration.BALANCER_ROUTER
   VariableDeclaration.BALANCER_VAULT
   VariableDeclaration.BPT
   VariableDeclaration.SUSDS
   VariableDeclaration.USDS
   VariableDeclaration.PHUSD
   VariableDeclaration.MULTI_POOLER
   VariableDeclaration.UNIV2_FACTORY
   VariableDeclaration.POOLER_7702_EOA
   VariableDeclaration.POOLER_EOA
   VariableDeclaration.DISPATCHER_INDEX
   VariableDeclaration.EXIT_TOLERANCE_BPS
   VariableDeclaration.SEED_DEADLINE_OFFSET
   VariableDeclaration.POOL_PREVIEW_TOLERANCE_BPS
   VariableDeclaration.DISPATCHER_MINTER_SLOT
   VariableDeclaration.isPreview
   VariableDeclaration.cutoverRanThisRun
   VariableDeclaration.exitModeUsed
   VariableDeclaration._result
   FunctionDefinition.poolers
   FunctionDefinition._bookAddress
   FunctionDefinition._requireBook
   FunctionDefinition._preflightAddresses
   FunctionDefinition._progressFile
   FunctionDefinition._readProgress
   FunctionDefinition._progressAddress
   FunctionDefinition._progressUint
   FunctionDefinition._checkWiring
   FunctionDefinition._checkDrained
   FunctionDefinition._reportEscrowResidual
   FunctionDefinition._minterOf
   FunctionDefinition._reportOwnerBpt
   FunctionDefinition._reservesSP
   FunctionDefinition._simulateQuotedPool
   FunctionDefinition._previewModeFromEnv
   FunctionDefinition.result
   FunctionDefinition.run
   FunctionDefinition._exitModeFromEnv
   FunctionDefinition._minAmountsFromEnv
   FunctionDefinition._buildParams
   FunctionDefinition._beginOwnerSession
   FunctionDefinition._endOwnerSession
   FunctionDefinition._alreadyCompleted
   FunctionDefinition._writeProgress
   FunctionDefinition._serializeEntry
   FunctionDefinition._previewEndToEnd
   FunctionDefinition._logParams
   FunctionDefinition._logResult
   FunctionDefinition.mint

```

### <a name="NC-15"></a>[NC-15] Constants should be defined rather than using magic numbers

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

139:         bytes memory lit = new bytes(42);

```

### <a name="NC-16"></a>[NC-16] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

237:         for (uint256 i = 0; i < ps.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 1 |
| [L-2](#L-2) | Deprecated approve() function | 1 |
| [L-3](#L-3) | Division by zero not prevented | 1 |
| [L-4](#L-4) | Prevent accidentally burning tokens | 4 |
| [L-5](#L-5) | Loss of precision | 3 |
| [L-6](#L-6) | Unsafe ERC20 operation(s) | 1 |
### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

522:         ICutoverERC20(prime).approve(NFT_MINTER, price);

```

### <a name="L-2"></a>[L-2] Deprecated approve() function
Due to the inheritance of ERC20's approve function, there's a vulnerability to the ERC20 approve and double spend front running attack. Briefly, an authorized spender could spend both allowances by front running an allowance-changing transaction. Consider implementing OpenZeppelin's `.safeApprove()` function to help mitigate this.

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

522:         ICutoverERC20(prime).approve(NFT_MINTER, price);

```

### <a name="L-3"></a>[L-3] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

260:             if (residual == 0) console.log("OK: escrow holds 0 BPT / sUSDS / phUSD / USDS.");

```

### <a name="L-4"></a>[L-4] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (4)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

222:         require(_minterOf(newPooler) == NFT_MINTER, "verify: UniPooler minter != NFTMinter");

222:         require(_minterOf(newPooler) == NFT_MINTER, "verify: UniPooler minter != NFTMinter");

241:         require(_minterOf(OLD_POOLER) == OWNER, "verify: old pooler minter != OWNER");

241:         require(_minterOf(OLD_POOLER) == OWNER, "verify: old pooler minter != OWNER");

```

### <a name="L-5"></a>[L-5] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (3)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

260:             if (residual == 0) console.log("OK: escrow holds 0 BPT / sUSDS / phUSD / USDS.");

317:         uint256 minPhusdOut = (phusdOut * (CUTOVER_MAX_BPS - POOL_PREVIEW_TOLERANCE_BPS)) / CUTOVER_MAX_BPS;

318:         uint256 minLP = (expectedLP * (CUTOVER_MAX_BPS - POOL_PREVIEW_TOLERANCE_BPS)) / CUTOVER_MAX_BPS;

```

### <a name="L-6"></a>[L-6] Unsafe ERC20 operation(s)

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

522:         ICutoverERC20(prime).approve(NFT_MINTER, price);

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | `block.number` means different things on different L2s | 1 |
### <a name="M-1"></a>[M-1] `block.number` means different things on different L2s
On Optimism, `block.number` is the L2 block number, but on Arbitrum, it's the L1 block number, and `ArbSys(address(100)).arbBlockNumber()` must be used. Furthermore, L2 block numbers often occur much more frequently than L1 block numbers (any may even occur on a per-transaction basis), so using block numbers for timing results in inconsistencies, especially when voting is involved across multiple chains. As of version 4.9, OpenZeppelin has [modified](https://blog.openzeppelin.com/introducing-openzeppelin-contracts-v4.9#governor) their governor code to use a clock rather than block numbers, to avoid these sorts of issues, but this still requires that the project [implement](https://docs.openzeppelin.com/contracts/4.x/governance#token_2) a [clock](https://eips.ethereum.org/EIPS/eip-6372) for each L2.

*Instances (1)*:
```solidity
File: script/DeployMainnetUniPoolerCutover.s.sol

477:         vm.serializeString("s103.cutover", "cutoverBlock", vm.toString(block.number));

```


# Part 02: `script/VerifyUniPoolerCutover.s.sol`




## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | Use assembly to check for `address(0)` | 3 |
| [GAS-2](#GAS-2) | For Operations that will not overflow, you could use unchecked | 15 |
| [GAS-3](#GAS-3) | Use Custom Errors instead of Revert Strings to save Gas | 5 |
| [GAS-4](#GAS-4) | Avoid contract existence checks by using low level calls | 1 |
| [GAS-5](#GAS-5) | Splitting require() statements that use && saves gas | 1 |
| [GAS-6](#GAS-6) | Use != 0 instead of > 0 for unsigned integer comparison | 1 |
### <a name="GAS-1"></a>[GAS-1] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (3)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

54:             np != address(0) && pair != address(0) && escrow != address(0), "verify: progress file missing addresses"

63:         if (bookNp != address(0)) require(bookNp == np, "verify: mainnet-addresses.ts UniPooler != progress file");

64:         if (bookPair != address(0)) {

```

### <a name="GAS-2"></a>[GAS-2] For Operations that will not overflow, you could use unchecked

*Instances (15)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

4: import "@forge-std/console.sol";

5: import {UniPoolerCutoverMainnetBase} from "./DeployMainnetUniPoolerCutover.s.sol";

6: import {ICutoverUniV2Pair} from "./helpers/UniPoolerCutoverCore.sol";

37:         console.log("  VERIFY index-4 UniPoolerV2 cutover - MAINNET (story 103)");

39:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

43:             exists, "verify: no progress file server/deployments/progress.unipooler-cutover.1.json - broadcast first"

63:         if (bookNp != address(0)) require(bookNp == np, "verify: mainnet-addresses.ts UniPooler != progress file");

65:             require(bookPair == pair, "verify: mainnet-addresses.ts PhusdSusdsPair != progress file");

68:             _bookAddress(book, "BalancerPooler") == OLD_POOLER, "verify: mainnet-addresses.ts BalancerPooler changed"

72:         console.log("OK: configs(4).dispatcher, hook.dispatcher(), UniPooler hook/owner/minter/pair/config, poolers.");

80:         console.log("OK: old pooler paused, minter OWNER, 0 sUSDS / 0 BPT / 0 USDS (escrow residuals reported above).");

91:         console.log("  pair reserves sUSDS / seeded:", rS, seedS);

92:         console.log("  pair reserves phUSD / seeded:", rP, seedP);

99:                 "WARNING: pair reserves != seeded amounts (VERIFY_ALLOW_RESERVE_DRIFT=true: pool()/swaps since)."

104:             "verify: pair reserves != seeded amounts (set VERIFY_ALLOW_RESERVE_DRIFT=true only if pool()/swaps ran since the cutover)"

```

### <a name="GAS-3"></a>[GAS-3] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (5)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

39:         require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");

45:         require(vm.parseJsonUint(json, ".chainId") == CHAIN_ID, "verify: progress chainId != 1");

63:         if (bookNp != address(0)) require(bookNp == np, "verify: mainnet-addresses.ts UniPooler != progress file");

65:             require(bookPair == pair, "verify: mainnet-addresses.ts PhusdSusdsPair != progress file");

76:         require(lp > 0 && lp >= _progressUint(json, "liquidity"), "verify: UniPooler does not hold the seeded LP");

```

### <a name="GAS-4"></a>[GAS-4] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

75:         uint256 lp = ICutoverUniV2Pair(pair).balanceOf(np);

```

### <a name="GAS-5"></a>[GAS-5] Splitting require() statements that use && saves gas

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

76:         require(lp > 0 && lp >= _progressUint(json, "liquidity"), "verify: UniPooler does not hold the seeded LP");

```

### <a name="GAS-6"></a>[GAS-6] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

76:         require(lp > 0 && lp >= _progressUint(json, "liquidity"), "verify: UniPooler does not hold the seeded LP");

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | `constant`s should be defined rather than using magic numbers | 1 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 12 |
| [NC-3](#NC-3) | Delete rogue `console.log` imports | 1 |
| [NC-4](#NC-4) | Functions should not be longer than 50 lines | 1 |
| [NC-5](#NC-5) | NatSpec is completely non-existent on functions that should have them | 1 |
| [NC-6](#NC-6) | Some require descriptions are not clear | 1 |
### <a name="NC-1"></a>[NC-1] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

37:         console.log("  VERIFY index-4 UniPoolerV2 cutover - MAINNET (story 103)");

```

### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (12)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

37:         console.log("  VERIFY index-4 UniPoolerV2 cutover - MAINNET (story 103)");

43:             exists, "verify: no progress file server/deployments/progress.unipooler-cutover.1.json - broadcast first"

45:         require(vm.parseJsonUint(json, ".chainId") == CHAIN_ID, "verify: progress chainId != 1");

48:             "verify: progress deploymentStatus != completed"

54:             np != address(0) && pair != address(0) && escrow != address(0), "verify: progress file missing addresses"

63:         if (bookNp != address(0)) require(bookNp == np, "verify: mainnet-addresses.ts UniPooler != progress file");

65:             require(bookPair == pair, "verify: mainnet-addresses.ts PhusdSusdsPair != progress file");

68:             _bookAddress(book, "BalancerPooler") == OLD_POOLER, "verify: mainnet-addresses.ts BalancerPooler changed"

76:         require(lp > 0 && lp >= _progressUint(json, "liquidity"), "verify: UniPooler does not hold the seeded LP");

84:         console.log("VERIFY PASSED");

99:                 "WARNING: pair reserves != seeded amounts (VERIFY_ALLOW_RESERVE_DRIFT=true: pool()/swaps since)."

104:             "verify: pair reserves != seeded amounts (set VERIFY_ALLOW_RESERVE_DRIFT=true only if pool()/swaps ran since the cutover)"

```

### <a name="NC-3"></a>[NC-3] Delete rogue `console.log` imports
These shouldn't be deployed in production

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

4: import "@forge-std/console.sol";

```

### <a name="NC-4"></a>[NC-4] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

87:     function _checkReserves(string memory json, address pair) internal view {

```

### <a name="NC-5"></a>[NC-5] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

35:     function run() external {

```

### <a name="NC-6"></a>[NC-6] Some require descriptions are not clear
1. It does not comply with the general require error description model of the project (Either all of them should be debugged in this way, or all of them should be explained with a string not exceeding 32 bytes.)
2. For debug dapps like Tenderly, these debug messages are important, this allows the user to see the reasons for revert practically.

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

76:         require(lp > 0 && lp >= _progressUint(json, "liquidity"), "verify: UniPooler does not hold the seeded LP");

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Division by zero not prevented | 1 |
| [L-2](#L-2) | Loss of precision | 1 |
| [L-3](#L-3) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
### <a name="L-1"></a>[L-1] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

91:         console.log("  pair reserves sUSDS / seeded:", rS, seedS);

```

### <a name="L-2"></a>[L-2] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

80:         console.log("OK: old pooler paused, minter OWNER, 0 sUSDS / 0 BPT / 0 USDS (escrow residuals reported above).");

```

### <a name="L-3"></a>[L-3] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: script/VerifyUniPoolerCutover.s.sol

2: pragma solidity ^0.8.20;

```


# Part 03: `script/helpers/UniPoolerCutoverCore.sol`




## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | Use assembly to check for `address(0)` | 10 |
| [GAS-2](#GAS-2) | Cache array length outside of loop | 5 |
| [GAS-3](#GAS-3) | For Operations that will not overflow, you could use unchecked | 44 |
| [GAS-4](#GAS-4) | Use Custom Errors instead of Revert Strings to save Gas | 37 |
| [GAS-5](#GAS-5) | Avoid contract existence checks by using low level calls | 25 |
| [GAS-6](#GAS-6) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 5 |
| [GAS-7](#GAS-7) | Splitting require() statements that use && saves gas | 6 |
| [GAS-8](#GAS-8) | Increments/decrements can be unchecked in for-loops | 5 |
| [GAS-9](#GAS-9) | Use != 0 instead of > 0 for unsigned integer comparison | 12 |
| [GAS-10](#GAS-10) | `internal` functions not called by the contract should be removed | 1 |
### <a name="GAS-1"></a>[GAS-1] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (10)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

411:         require(p.owner != address(0), "UniPoolerCutoverCore: zero owner");

415:         require(p.balancerRouter != address(0), "UniPoolerCutoverCore: zero balancer router");

431:             require(p.poolers[i] != address(0), "UniPoolerCutoverCore: zero pooler");

449:             l.sUSDS != address(0) && l.usds != address(0) && l.phUSD != address(0) && l.bPool != address(0)

450:                 && l.bVault != address(0) && l.factory != address(0),

450:                 && l.bVault != address(0) && l.factory != address(0),

470:         if (pair == address(0)) {

473:         require(pair != address(0), "UniPoolerCutoverCore: no pair");

628:         if (psm_ != address(0)) np.setPSM(psm_);

637:         if (streamer != address(0)) np.setNudgeStreamer(streamer);

```

### <a name="GAS-2"></a>[GAS-2] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (5)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

430:         for (uint256 i = 0; i < p.poolers.length; i++) {

462:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

586:         for (uint256 i = 0; i < raw.length; i++) {

632:         for (uint256 i = 0; i < p.poolers.length; i++) {

645:         for (uint256 i = 0; i < p.poolers.length; i++) {

```

### <a name="GAS-3"></a>[GAS-3] For Operations that will not overflow, you could use unchecked

*Instances (44)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

4: import {UniPoolerV2} from "@yield-claim-nft/dispatchers/UniPoolerV2.sol";

5: import {IDispatchHook} from "@yield-claim-nft/interfaces/IDispatchHook.sol";

6: import {UniPoolerCutoverEscrow} from "@yield-claim-nft/migration/UniPoolerCutoverEscrow.sol";

223:     uint256 internal constant CUTOVER_STEP_DEPLOY_ESCROW = 31; // "3b"

234:         "UniPoolerCutoverCore: old pooler pool() != escrow.bpt() - setPool repointed the old pooler; withdrawBPT would strand the token in the escrow (L-27)";

246:         address owner; // the sender of every call; owns old pooler, hook and NFT minter; escrow operator

247:         address oldPooler; // BalancerPoolerV2 at the index

248:         address mintDebtHook; // BalancerPoolerMintDebtHook

249:         address nftMinter; // NFTMinterV2

250:         uint256 dispatcherIndex; // 4

251:         address uniV2Router; // Router02; its factory() creates/locates the pair

252:         address balancerRouter; // Balancer V3 Router (not exposed by BalancerPoolerV2); the escrow's v3Router

253:         address[] poolers; // the poolers to re-authorize on UniPoolerV2 (must be revoked on old)

255:         uint256[] minAmountsOut; // Balancer pool-token order; every entry > 0

256:         uint256 exitToleranceBps; // max gap of minAmountsOut below the live proportional share

281:         uint256 pairDonationSUSDS; // unsynced sUSDS on the empty pair at step 2 (skimmed to newPooler by the escrow)

282:         uint256 pairDonationPhUSD; // unsynced phUSD on the empty pair at step 2

283:         uint256 ownerBptAtStart; // reported only: owner BPT is out of scope (F-02-052)

284:         uint256 bptWithdrawn; // old pooler -> escrow in step 4

285:         uint256 bptExited; // the escrow's whole BPT balance, exited in step 5

286:         uint256 sUSDSSeeded; // pair sUSDS reserve after the seed (== the escrow's whole sUSDS)

287:         uint256 phUSDSeeded; // pair phUSD reserve after the seed (== the escrow's whole phUSD)

288:         uint256 liquidity; // LP minted to newPooler by the seed

289:         uint256 sUSDSRescued; // old pooler -> newPooler in step 11

290:         uint256 usdsRescued; // old pooler -> escrow in step 11, then wrapped

291:         uint256 usdsWrappedShares; // sUSDS shares the escrow's wrapUsds credited to newPooler

396:             b[0] = bytes1(uint8(48 + step / 10));

397:             b[1] = bytes1(uint8(48 + (step % 10)));

399:             b[0] = bytes1(uint8(48 + step));

423:             p.seedDeadline <= block.timestamp + CUTOVER_MAX_SEED_DEADLINE_WINDOW,

430:         for (uint256 i = 0; i < p.poolers.length; i++) {

456:         require(tokens.length == 2, "UniPoolerCutoverCore: pool not two-token");

462:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

527:                 ICutoverERC20(livePool).balanceOf(escrow) - escrowBefore == bal,

555:             ICutoverUniV2Pair(l.pair).balanceOf(l.newPooler) - lpBefore == liquidity,

586:         for (uint256 i = 0; i < raw.length; i++) {

587:             uint256 share = (raw[i] * bptIn) / supply;

590:                 p.minAmountsOut[i] >= (share * (CUTOVER_MAX_BPS - p.exitToleranceBps)) / CUTOVER_MAX_BPS,

632:         for (uint256 i = 0; i < p.poolers.length; i++) {

645:         for (uint256 i = 0; i < p.poolers.length; i++) {

682:                 ICutoverERC20(l.sUSDS).balanceOf(l.newPooler) - npBefore == sUSDSRescued,

692:             require(escrowUsdsAfterRescue - escrowUsdsBefore == usdsRescued, "UniPoolerCutoverCore: USDS rescue short");

696:                 wrappedShares > 0 && ICutoverERC20(l.sUSDS).balanceOf(l.newPooler) - npBefore == wrappedShares,

702:                 escrowUsdsAfterRescue - ICutoverERC20(l.usds).balanceOf(l.escrow) >= usdsRescued,

```

### <a name="GAS-4"></a>[GAS-4] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (37)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

411:         require(p.owner != address(0), "UniPoolerCutoverCore: zero owner");

412:         require(old.owner() == p.owner, "UniPoolerCutoverCore: owner does not own old pooler");

413:         require(hook.owner() == p.owner, "UniPoolerCutoverCore: owner does not own hook");

414:         require(ICutoverNFTMinter(p.nftMinter).owner() == p.owner, "UniPoolerCutoverCore: owner does not own minter");

415:         require(p.balancerRouter != address(0), "UniPoolerCutoverCore: zero balancer router");

417:         require(p.exitToleranceBps <= CUTOVER_MAX_TOLERANCE_BPS, "UniPoolerCutoverCore: tolerance too wide");

421:         require(p.seedDeadline > block.timestamp, "UniPoolerCutoverCore: seed deadline not in future");

428:         require(p.poolers.length > 0, "UniPoolerCutoverCore: no poolers");

431:             require(p.poolers[i] != address(0), "UniPoolerCutoverCore: zero pooler");

432:             require(old.poolerAuthVersion(p.poolers[i]) != av, "UniPoolerCutoverCore: pooler still authorized");

437:         require(d == p.oldPooler, "UniPoolerCutoverCore: index not on old pooler");

438:         require(hook.dispatcher() == p.oldPooler, "UniPoolerCutoverCore: hook not on old pooler");

439:         require(old.hook() == p.mintDebtHook, "UniPoolerCutoverCore: old pooler hook mismatch");

456:         require(tokens.length == 2, "UniPoolerCutoverCore: pool not two-token");

461:         require(p.minAmountsOut.length == tokens.length, "UniPoolerCutoverCore: minAmountsOut length");

463:             require(p.minAmountsOut[i] > 0, "UniPoolerCutoverCore: zero minAmountOut");

473:         require(pair != address(0), "UniPoolerCutoverCore: no pair");

480:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

488:         require(np.pair() == l.pair && np.owner() == p.owner, "UniPoolerCutoverCore: deploy mismatch");

511:         require(bal > 0, "UniPoolerCutoverCore: old pooler holds no BPT");

531:         require(ICutoverERC20(livePool).balanceOf(oldPooler) == 0, "UniPoolerCutoverCore: BPT left on old pooler");

548:         require(bptWithdrawn > 0 && bptIn >= bptWithdrawn, "UniPoolerCutoverCore: escrow holds no BPT");

553:         require(liquidity > 0, "UniPoolerCutoverCore: no LP minted");

563:         require(sSeeded > 0 && pSeeded > 0, "UniPoolerCutoverCore: empty seed");

566:         require(sSeeded >= minS && pSeeded >= minP, "UniPoolerCutoverCore: seed below exit floors");

585:         require(supply > 0, "UniPoolerCutoverCore: zero BPT supply");

588:             require(p.minAmountsOut[i] <= share, "UniPoolerCutoverCore: minAmountOut above share");

598:         require(ok && data.length >= 32, "UniPoolerCutoverCore: totalSupply");

605:         require(ICutoverMintDebtHook(p.mintDebtHook).mintDebt() == 0, "UniPoolerCutoverCore: mintDebt not zero");

646:             require(np.poolerAuthVersion(p.poolers[i]) == av, "UniPoolerCutoverCore: pooler not authorized");

656:         require(d2 == l.newPooler, "UniPoolerCutoverCore: dispatcher not replaced");

692:             require(escrowUsdsAfterRescue - escrowUsdsBefore == usdsRescued, "UniPoolerCutoverCore: USDS rescue short");

718:         require(old.paused(), "UniPoolerCutoverCore: old pooler not paused");

728:         require(d == l.newPooler, "UniPoolerCutoverCore: index not on new pooler");

729:         require(ICutoverMintDebtHook(p.mintDebtHook).dispatcher() == l.newPooler, "UniPoolerCutoverCore: hook");

730:         require(ICutoverERC20(l.bPool).balanceOf(p.oldPooler) == 0, "UniPoolerCutoverCore: BPT remains");

735:         require(ICutoverBalancerPooler(p.oldPooler).paused(), "UniPoolerCutoverCore: old pooler live");

```

### <a name="GAS-5"></a>[GAS-5] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (25)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

369:         o.bpt = ICutoverERC20(l.bPool).balanceOf(p.owner);

370:         o.sUSDS = ICutoverERC20(l.sUSDS).balanceOf(p.owner);

371:         o.phUSD = ICutoverERC20(l.phUSD).balanceOf(p.owner);

372:         o.usds = ICutoverERC20(l.usds).balanceOf(p.owner);

481:         donS = ICutoverERC20(l.sUSDS).balanceOf(l.pair);

482:         donP = ICutoverERC20(l.phUSD).balanceOf(l.pair);

522:         bal = ICutoverERC20(livePool).balanceOf(oldPooler);

524:             uint256 escrowBefore = ICutoverERC20(livePool).balanceOf(escrow);

527:                 ICutoverERC20(livePool).balanceOf(escrow) - escrowBefore == bal,

531:         require(ICutoverERC20(livePool).balanceOf(oldPooler) == 0, "UniPoolerCutoverCore: BPT left on old pooler");

547:         bptIn = ICutoverERC20(l.bPool).balanceOf(l.escrow);

551:         uint256 lpBefore = ICutoverUniV2Pair(l.pair).balanceOf(l.newPooler);

555:             ICutoverUniV2Pair(l.pair).balanceOf(l.newPooler) - lpBefore == liquidity,

677:         sUSDSRescued = ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler);

679:             uint256 npBefore = ICutoverERC20(l.sUSDS).balanceOf(l.newPooler);

682:                 ICutoverERC20(l.sUSDS).balanceOf(l.newPooler) - npBefore == sUSDSRescued,

687:         usdsRescued = ICutoverERC20(l.usds).balanceOf(p.oldPooler);

689:             uint256 escrowUsdsBefore = ICutoverERC20(l.usds).balanceOf(l.escrow);

691:             uint256 escrowUsdsAfterRescue = ICutoverERC20(l.usds).balanceOf(l.escrow);

693:             uint256 npBefore = ICutoverERC20(l.sUSDS).balanceOf(l.newPooler);

696:                 wrappedShares > 0 && ICutoverERC20(l.sUSDS).balanceOf(l.newPooler) - npBefore == wrappedShares,

702:                 escrowUsdsAfterRescue - ICutoverERC20(l.usds).balanceOf(l.escrow) >= usdsRescued,

708:             ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler) == 0 && ICutoverERC20(l.usds).balanceOf(p.oldPooler) == 0,

730:         require(ICutoverERC20(l.bPool).balanceOf(p.oldPooler) == 0, "UniPoolerCutoverCore: BPT remains");

732:             ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler) == 0 && ICutoverERC20(l.usds).balanceOf(p.oldPooler) == 0,

```

### <a name="GAS-6"></a>[GAS-6] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
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

430:         for (uint256 i = 0; i < p.poolers.length; i++) {

462:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

586:         for (uint256 i = 0; i < raw.length; i++) {

632:         for (uint256 i = 0; i < p.poolers.length; i++) {

645:         for (uint256 i = 0; i < p.poolers.length; i++) {

```

### <a name="GAS-7"></a>[GAS-7] Splitting require() statements that use && saves gas

*Instances (6)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

480:         require(r0 == 0 && r1 == 0, "UniPoolerCutoverCore: pair reserves not empty");

488:         require(np.pair() == l.pair && np.owner() == p.owner, "UniPoolerCutoverCore: deploy mismatch");

548:         require(bptWithdrawn > 0 && bptIn >= bptWithdrawn, "UniPoolerCutoverCore: escrow holds no BPT");

563:         require(sSeeded > 0 && pSeeded > 0, "UniPoolerCutoverCore: empty seed");

566:         require(sSeeded >= minS && pSeeded >= minP, "UniPoolerCutoverCore: seed below exit floors");

598:         require(ok && data.length >= 32, "UniPoolerCutoverCore: totalSupply");

```

### <a name="GAS-8"></a>[GAS-8] Increments/decrements can be unchecked in for-loops
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

430:         for (uint256 i = 0; i < p.poolers.length; i++) {

462:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

586:         for (uint256 i = 0; i < raw.length; i++) {

632:         for (uint256 i = 0; i < p.poolers.length; i++) {

645:         for (uint256 i = 0; i < p.poolers.length; i++) {

```

### <a name="GAS-9"></a>[GAS-9] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (12)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

255:         uint256[] minAmountsOut; // Balancer pool-token order; every entry > 0

428:         require(p.poolers.length > 0, "UniPoolerCutoverCore: no poolers");

463:             require(p.minAmountsOut[i] > 0, "UniPoolerCutoverCore: zero minAmountOut");

511:         require(bal > 0, "UniPoolerCutoverCore: old pooler holds no BPT");

523:         if (bal > 0) {

548:         require(bptWithdrawn > 0 && bptIn >= bptWithdrawn, "UniPoolerCutoverCore: escrow holds no BPT");

553:         require(liquidity > 0, "UniPoolerCutoverCore: no LP minted");

563:         require(sSeeded > 0 && pSeeded > 0, "UniPoolerCutoverCore: empty seed");

585:         require(supply > 0, "UniPoolerCutoverCore: zero BPT supply");

678:         if (sUSDSRescued > 0) {

688:         if (usdsRescued > 0) {

696:                 wrappedShares > 0 && ICutoverERC20(l.sUSDS).balanceOf(l.newPooler) - npBefore == wrappedShares,

```

### <a name="GAS-10"></a>[GAS-10] `internal` functions not called by the contract should be removed
If the functions are required by an interface, the contract should inherit from that interface and use the `override` keyword

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

307:     function _runCutover(CutoverParams memory p) internal returns (CutoverResult memory r) {

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 1 |
| [NC-2](#NC-2) | Array indices should be referenced via `enum`s rather than via numeric literals | 5 |
| [NC-3](#NC-3) | `constant`s should be defined rather than using magic numbers | 6 |
| [NC-4](#NC-4) | Control structures do not follow the Solidity Style Guide | 4 |
| [NC-5](#NC-5) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-6](#NC-6) | Functions should not be longer than 50 lines | 51 |
| [NC-7](#NC-7) | Interfaces should be defined in separate files from their usage | 9 |
| [NC-8](#NC-8) | Lack of checks in setters | 2 |
| [NC-9](#NC-9) | Missing Event for critical parameters change | 2 |
| [NC-10](#NC-10) | NatSpec is completely non-existent on functions that should have them | 12 |
| [NC-11](#NC-11) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-12](#NC-12) | Constants should be defined rather than using magic numbers | 3 |
| [NC-13](#NC-13) | Variables need not be initialized to zero | 5 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

597:         (bool ok, bytes memory data) = token.staticcall(abi.encodeWithSignature("totalSupply()"));

```

### <a name="NC-2"></a>[NC-2] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (5)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

396:             b[0] = bytes1(uint8(48 + step / 10));

397:             b[1] = bytes1(uint8(48 + (step % 10)));

399:             b[0] = bytes1(uint8(48 + step));

458:             (tokens[0] == l.sUSDS && tokens[1] == l.phUSD) || (tokens[0] == l.phUSD && tokens[1] == l.sUSDS),

575:             tokens[0] == l.sUSDS ? (p.minAmountsOut[0], p.minAmountsOut[1]) : (p.minAmountsOut[1], p.minAmountsOut[0]);

```

### <a name="NC-3"></a>[NC-3] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (6)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

394:         bytes memory b = new bytes(step >= 10 ? 2 : 1);

395:         if (step >= 10) {

396:             b[0] = bytes1(uint8(48 + step / 10));

397:             b[1] = bytes1(uint8(48 + (step % 10)));

456:         require(tokens.length == 2, "UniPoolerCutoverCore: pool not two-token");

598:         require(ok && data.length >= 32, "UniPoolerCutoverCore: totalSupply");

```

### <a name="NC-4"></a>[NC-4] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (4)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

393:         if (step == CUTOVER_STEP_DEPLOY_ESCROW) return "3b";

628:         if (psm_ != address(0)) np.setPSM(psm_);

637:         if (streamer != address(0)) np.setNudgeStreamer(streamer);

717:         if (!old.paused()) old.pause();

```

### <a name="NC-5"></a>[NC-5] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

1: 
   Current order:
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
   external balanceOf
   external approve
   external operator
   external newPooler
   external oldPooler
   external v3Router
   external bpt
   external usds
   external sUSDS
   external phUSD
   external pair
   external uniRouter
   external exitAndSeed
   external wrapUsds
   internal _runCutover
   internal _afterCutoverStep
   private _afterStep
   internal _ownerBalances
   internal _requireOwnerNotCredited
   internal _stepName
   internal _step0Preconditions
   internal _step1CreatePair
   internal _step2EnsurePairEmpty
   internal _step3DeployPooler
   internal _step3bDeployEscrow
   internal _step4FundEscrow
   internal _fundEscrow
   internal _step5ExitAndSeed
   internal _minsByToken
   internal _checkMinAmountsOut
   private _totalSupply
   internal _step7PullDebt
   internal _step8RepointHook
   internal _step9ConfigurePooler
   internal _step10ReplaceDispatcher
   internal _step11MoveBalances
   internal _step12RetireOld
   internal _assertRetired
   
   Suggested order:
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
   external balanceOf
   external approve
   external operator
   external newPooler
   external oldPooler
   external v3Router
   external bpt
   external usds
   external sUSDS
   external phUSD
   external pair
   external uniRouter
   external exitAndSeed
   external wrapUsds
   internal _runCutover
   internal _afterCutoverStep
   internal _ownerBalances
   internal _requireOwnerNotCredited
   internal _stepName
   internal _step0Preconditions
   internal _step1CreatePair
   internal _step2EnsurePairEmpty
   internal _step3DeployPooler
   internal _step3bDeployEscrow
   internal _step4FundEscrow
   internal _fundEscrow
   internal _step5ExitAndSeed
   internal _minsByToken
   internal _checkMinAmountsOut
   internal _step7PullDebt
   internal _step8RepointHook
   internal _step9ConfigurePooler
   internal _step10ReplaceDispatcher
   internal _step11MoveBalances
   internal _step12RetireOld
   internal _assertRetired
   private _afterStep
   private _totalSupply

```

### <a name="NC-6"></a>[NC-6] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (51)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

121:     function primeToken() external view returns (address);

126:     function authVersion() external view returns (uint256);

127:     function poolerAuthVersion(address pooler) external view returns (uint256);

129:     function maxTout() external view returns (uint256);

130:     function batchMinter() external view returns (address);

131:     function nudgeStreamer() external view returns (address);

132:     function batchDonationSize() external view returns (uint256);

133:     function withdrawBPT(address recipient, uint256 amount) external;

134:     function rescueERC20(address token, address to, uint256 amount) external;

142:     function dispatcher() external view returns (address);

144:     function mintDebt() external view returns (uint256);

146:     function setDispatcher(address newDispatcher) external;

156:     function replaceDispatcher(uint256 index, address newDispatcher) external;

160:     function factory() external view returns (address);

174:     function getPair(address tokenA, address tokenB) external view returns (address pair);

175:     function createPair(address tokenA, address tokenB) external returns (address pair);

179:     function token0() external view returns (address);

180:     function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

181:     function balanceOf(address account) external view returns (uint256);

185:     function balanceOf(address account) external view returns (uint256);

186:     function approve(address spender, uint256 amount) external returns (bool);

193:     function operator() external view returns (address);

194:     function newPooler() external view returns (address);

195:     function oldPooler() external view returns (address);

196:     function v3Router() external view returns (address);

202:     function uniRouter() external view returns (address);

203:     function exitAndSeed(uint8 mode, uint256[] calldata minAmountsOut, uint256 deadline)

206:     function wrapUsds() external returns (uint256 shares);

307:     function _runCutover(CutoverParams memory p) internal returns (CutoverResult memory r) {

357:     function _afterCutoverStep(uint256 step, CutoverParams memory p, CutoverLive memory l) internal virtual {}

359:     function _afterStep(uint256 step, CutoverParams memory p, CutoverLive memory l, OwnerBalances memory o) private {

364:     function _ownerBalances(CutoverParams memory p, CutoverLive memory l)

392:     function _stepName(uint256 step) internal pure returns (string memory) {

407:     function _step0Preconditions(CutoverParams memory p) internal view returns (CutoverLive memory l) {

468:     function _step1CreatePair(CutoverLive memory l) internal returns (address pair) {

478:     function _step2EnsurePairEmpty(CutoverLive memory l) internal view returns (uint256 donS, uint256 donP) {

486:     function _step3DeployPooler(CutoverParams memory p, CutoverLive memory l) internal returns (address) {

493:     function _step3bDeployEscrow(CutoverParams memory p, CutoverLive memory l) internal returns (address e) {

509:     function _step4FundEscrow(CutoverParams memory p, CutoverLive memory l) internal returns (uint256 bal) {

519:     function _fundEscrow(address oldPooler, address escrow) internal returns (uint256 bal) {

543:     function _step5ExitAndSeed(CutoverParams memory p, CutoverLive memory l, uint256 bptWithdrawn)

572:     function _minsByToken(CutoverParams memory p, CutoverLive memory l) internal view returns (uint256, uint256) {

582:     function _checkMinAmountsOut(CutoverParams memory p, CutoverLive memory l, uint256 bptIn) internal view {

596:     function _totalSupply(address token) private view returns (uint256 s) {

603:     function _step7PullDebt(CutoverParams memory p) internal {

609:     function _step8RepointHook(CutoverParams memory p, CutoverLive memory l) internal {

621:     function _step9ConfigurePooler(CutoverParams memory p, CutoverLive memory l) internal {

651:     function _step10ReplaceDispatcher(CutoverParams memory p, CutoverLive memory l) internal {

671:     function _step11MoveBalances(CutoverParams memory p, CutoverLive memory l)

714:     function _step12RetireOld(CutoverParams memory p) internal {

726:     function _assertRetired(CutoverParams memory p, CutoverLive memory l) internal view {

```

### <a name="NC-7"></a>[NC-7] Interfaces should be defined in separate files from their usage
The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (9)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

98: interface IBalancerV3VaultViews {

118: interface ICutoverBalancerPooler {

140: interface ICutoverMintDebtHook {

150: interface ICutoverNFTMinter {

159: interface ICutoverUniV2Router {

173: interface ICutoverUniV2Factory {

178: interface ICutoverUniV2Pair {

184: interface ICutoverERC20 {

192: interface ICutoverEscrow {

```

### <a name="NC-8"></a>[NC-8] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

135:     function setMinter(address minter_) external;

146:     function setDispatcher(address newDispatcher) external;

```

### <a name="NC-9"></a>[NC-9] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

135:     function setMinter(address minter_) external;

146:     function setDispatcher(address newDispatcher) external;

```

### <a name="NC-10"></a>[NC-10] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (12)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

133:     function withdrawBPT(address recipient, uint256 amount) external;

134:     function rescueERC20(address token, address to, uint256 amount) external;

135:     function setMinter(address minter_) external;

136:     function pause() external;

145:     function pull() external;

146:     function setDispatcher(address newDispatcher) external;

156:     function replaceDispatcher(uint256 index, address newDispatcher) external;

161:     function addLiquidity(

175:     function createPair(address tokenA, address tokenB) external returns (address pair);

186:     function approve(address spender, uint256 amount) external returns (bool);

203:     function exitAndSeed(uint8 mode, uint256[] calldata minAmountsOut, uint256 deadline)

206:     function wrapUsds() external returns (uint256 shares);

```

### <a name="NC-11"></a>[NC-11] Contract does not follow the Solidity style guide's suggested layout ordering
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
   FunctionDefinition.balanceOf
   FunctionDefinition.approve
   FunctionDefinition.operator
   FunctionDefinition.newPooler
   FunctionDefinition.oldPooler
   FunctionDefinition.v3Router
   FunctionDefinition.bpt
   FunctionDefinition.usds
   FunctionDefinition.sUSDS
   FunctionDefinition.phUSD
   FunctionDefinition.pair
   FunctionDefinition.uniRouter
   FunctionDefinition.exitAndSeed
   FunctionDefinition.wrapUsds
   VariableDeclaration.CUTOVER_MAX_BPS
   VariableDeclaration.CUTOVER_MAX_TOLERANCE_BPS
   VariableDeclaration.CUTOVER_MAX_SEED_DEADLINE_WINDOW
   VariableDeclaration.CUTOVER_STEP_PRECONDITIONS
   VariableDeclaration.CUTOVER_STEP_CREATE_PAIR
   VariableDeclaration.CUTOVER_STEP_PAIR_EMPTY
   VariableDeclaration.CUTOVER_STEP_DEPLOY_POOLER
   VariableDeclaration.CUTOVER_STEP_DEPLOY_ESCROW
   VariableDeclaration.CUTOVER_STEP_FUND_ESCROW
   VariableDeclaration.CUTOVER_STEP_EXIT_AND_SEED
   VariableDeclaration.CUTOVER_STEP_PULL_DEBT
   VariableDeclaration.CUTOVER_STEP_REPOINT_HOOK
   VariableDeclaration.CUTOVER_STEP_CONFIGURE
   VariableDeclaration.CUTOVER_STEP_REPLACE_DISPATCHER
   VariableDeclaration.CUTOVER_STEP_MOVE_BALANCES
   VariableDeclaration.CUTOVER_STEP_RETIRE_OLD
   VariableDeclaration.CUTOVER_BPT_GUARD_MESSAGE
   EnumDefinition.ExitMode
   StructDefinition.CutoverParams
   StructDefinition.CutoverLive
   StructDefinition.CutoverResult
   StructDefinition.OwnerBalances
   FunctionDefinition._runCutover
   FunctionDefinition._afterCutoverStep
   FunctionDefinition._afterStep
   FunctionDefinition._ownerBalances
   FunctionDefinition._requireOwnerNotCredited
   FunctionDefinition._stepName
   FunctionDefinition._step0Preconditions
   FunctionDefinition._step1CreatePair
   FunctionDefinition._step2EnsurePairEmpty
   FunctionDefinition._step3DeployPooler
   FunctionDefinition._step3bDeployEscrow
   FunctionDefinition._step4FundEscrow
   FunctionDefinition._fundEscrow
   FunctionDefinition._step5ExitAndSeed
   FunctionDefinition._minsByToken
   FunctionDefinition._checkMinAmountsOut
   FunctionDefinition._totalSupply
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
   VariableDeclaration.CUTOVER_STEP_PRECONDITIONS
   VariableDeclaration.CUTOVER_STEP_CREATE_PAIR
   VariableDeclaration.CUTOVER_STEP_PAIR_EMPTY
   VariableDeclaration.CUTOVER_STEP_DEPLOY_POOLER
   VariableDeclaration.CUTOVER_STEP_DEPLOY_ESCROW
   VariableDeclaration.CUTOVER_STEP_FUND_ESCROW
   VariableDeclaration.CUTOVER_STEP_EXIT_AND_SEED
   VariableDeclaration.CUTOVER_STEP_PULL_DEBT
   VariableDeclaration.CUTOVER_STEP_REPOINT_HOOK
   VariableDeclaration.CUTOVER_STEP_CONFIGURE
   VariableDeclaration.CUTOVER_STEP_REPLACE_DISPATCHER
   VariableDeclaration.CUTOVER_STEP_MOVE_BALANCES
   VariableDeclaration.CUTOVER_STEP_RETIRE_OLD
   VariableDeclaration.CUTOVER_BPT_GUARD_MESSAGE
   EnumDefinition.ExitMode
   StructDefinition.TokenInfo
   StructDefinition.CutoverParams
   StructDefinition.CutoverLive
   StructDefinition.CutoverResult
   StructDefinition.OwnerBalances
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
   FunctionDefinition.balanceOf
   FunctionDefinition.approve
   FunctionDefinition.operator
   FunctionDefinition.newPooler
   FunctionDefinition.oldPooler
   FunctionDefinition.v3Router
   FunctionDefinition.bpt
   FunctionDefinition.usds
   FunctionDefinition.sUSDS
   FunctionDefinition.phUSD
   FunctionDefinition.pair
   FunctionDefinition.uniRouter
   FunctionDefinition.exitAndSeed
   FunctionDefinition.wrapUsds
   FunctionDefinition._runCutover
   FunctionDefinition._afterCutoverStep
   FunctionDefinition._afterStep
   FunctionDefinition._ownerBalances
   FunctionDefinition._requireOwnerNotCredited
   FunctionDefinition._stepName
   FunctionDefinition._step0Preconditions
   FunctionDefinition._step1CreatePair
   FunctionDefinition._step2EnsurePairEmpty
   FunctionDefinition._step3DeployPooler
   FunctionDefinition._step3bDeployEscrow
   FunctionDefinition._step4FundEscrow
   FunctionDefinition._fundEscrow
   FunctionDefinition._step5ExitAndSeed
   FunctionDefinition._minsByToken
   FunctionDefinition._checkMinAmountsOut
   FunctionDefinition._totalSupply
   FunctionDefinition._step7PullDebt
   FunctionDefinition._step8RepointHook
   FunctionDefinition._step9ConfigurePooler
   FunctionDefinition._step10ReplaceDispatcher
   FunctionDefinition._step11MoveBalances
   FunctionDefinition._step12RetireOld
   FunctionDefinition._assertRetired

```

### <a name="NC-12"></a>[NC-12] Constants should be defined rather than using magic numbers

*Instances (3)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

396:             b[0] = bytes1(uint8(48 + step / 10));

397:             b[1] = bytes1(uint8(48 + (step % 10)));

399:             b[0] = bytes1(uint8(48 + step));

```

### <a name="NC-13"></a>[NC-13] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (5)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

430:         for (uint256 i = 0; i < p.poolers.length; i++) {

462:         for (uint256 i = 0; i < p.minAmountsOut.length; i++) {

586:         for (uint256 i = 0; i < raw.length; i++) {

632:         for (uint256 i = 0; i < p.poolers.length; i++) {

645:         for (uint256 i = 0; i < p.poolers.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Division by zero not prevented | 1 |
| [L-2](#L-2) | Signature use at deadlines should be allowed | 2 |
| [L-3](#L-3) | Possible rounding issue | 1 |
| [L-4](#L-4) | Loss of precision | 1 |
| [L-5](#L-5) | Sweeping may break accounting if tokens with multiple addresses are used | 3 |
| [L-6](#L-6) | Consider using OpenZeppelin's SafeCast library to prevent unexpected overflows when downcasting | 6 |
### <a name="L-1"></a>[L-1] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

587:             uint256 share = (raw[i] * bptIn) / supply;

```

### <a name="L-2"></a>[L-2] Signature use at deadlines should be allowed
According to [EIP-2612](https://github.com/ethereum/EIPs/blob/71dc97318013bf2ac572ab63fab530ac9ef419ca/EIPS/eip-2612.md?plain=1#L58), signatures used on exactly the deadline timestamp are supposed to be allowed. While the signature may or may not be used for the exact EIP-2612 use case (transfer approvals), for consistency's sake, all deadlines should follow this semantic. If the timestamp is an expiration rather than a deadline, consider whether it makes more sense to include the expiration timestamp as a valid timestamp, as is done for deadlines.

*Instances (2)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

421:         require(p.seedDeadline > block.timestamp, "UniPoolerCutoverCore: seed deadline not in future");

423:             p.seedDeadline <= block.timestamp + CUTOVER_MAX_SEED_DEADLINE_WINDOW,

```

### <a name="L-3"></a>[L-3] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

587:             uint256 share = (raw[i] * bptIn) / supply;

```

### <a name="L-4"></a>[L-4] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (1)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

590:                 p.minAmountsOut[i] >= (share * (CUTOVER_MAX_BPS - p.exitToleranceBps)) / CUTOVER_MAX_BPS,

```

### <a name="L-5"></a>[L-5] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (3)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

134:     function rescueERC20(address token, address to, uint256 amount) external;

680:             old.rescueERC20(l.sUSDS, l.newPooler, sUSDSRescued);

690:             old.rescueERC20(l.usds, l.escrow, usdsRescued);

```

### <a name="L-6"></a>[L-6] Consider using OpenZeppelin's SafeCast library to prevent unexpected overflows when downcasting
Downcasting from `uint256`/`int256` in Solidity does not revert on overflow. This can result in undesired exploitation or bugs, since developers usually assume that overflows raise errors. [OpenZeppelin's SafeCast library](https://docs.openzeppelin.com/contracts/3.x/api/utils#SafeCast) restores this intuition by reverting the transaction when such an operation overflows. Using this library eliminates an entire class of bugs, so it's recommended to use it always. Some exceptions are acceptable like with the classic `uint256(uint160(address(variable)))`

*Instances (6)*:
```solidity
File: script/helpers/UniPoolerCutoverCore.sol

396:             b[0] = bytes1(uint8(48 + step / 10));

396:             b[0] = bytes1(uint8(48 + step / 10));

397:             b[1] = bytes1(uint8(48 + (step % 10)));

397:             b[1] = bytes1(uint8(48 + (step % 10)));

399:             b[0] = bytes1(uint8(48 + step));

399:             b[0] = bytes1(uint8(48 + step));

```


# Part 04: `src/periphery/UniswapHelper.sol`




## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | Use assembly to check for `address(0)` | 10 |
| [GAS-2](#GAS-2) | State variables should be cached in stack variables rather than re-reading them from storage | 38 |
| [GAS-3](#GAS-3) | For Operations that will not overflow, you could use unchecked | 21 |
| [GAS-4](#GAS-4) | State variables only set in the constructor should be declared `immutable` | 14 |
| [GAS-5](#GAS-5) | Using `private` rather than `public` for constants, saves gas | 1 |
| [GAS-6](#GAS-6) | Use != 0 instead of > 0 for unsigned integer comparison | 2 |
| [GAS-7](#GAS-7) | WETH address definition can be use directly | 1 |
### <a name="GAS-1"></a>[GAS-1] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (10)*:
```solidity
File: src/periphery/UniswapHelper.sol

155:             phUSD_ == address(0) || sUSDS_ == address(0) || USDS_ == address(0) || USDC_ == address(0)

156:                 || DOLA_ == address(0) || USDe_ == address(0) || WETH_ == address(0) || skyPSM_ == address(0)

157:                 || v2Router_ == address(0) || v3SwapRouter_ == address(0) || v3Quoter_ == address(0)

158:                 || curveDolaPool_ == address(0) || curveUsdePool_ == address(0)

281:         if (recipient == address(0)) revert ZeroAddress();

308:         if (recipient == address(0)) revert ZeroAddress();

340:         if (recipient == address(0)) revert ZeroAddress();

359:         if (recipient == address(0)) revert ZeroAddress();

421:         if (recipient == address(0)) revert ZeroAddress();

430:         if (p == address(0)) revert PairNotFound();

```

### <a name="GAS-2"></a>[GAS-2] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (38)*:
```solidity
File: src/periphery/UniswapHelper.sol

214:         uint256 usdc = _v3Swap(WETH, USDC, msg.value, deadline);

216:         phusdOut = _swapSusdsForPhusd(_toSusds(USDC, usdc), recipient, deadline);

241:         emit Swapped(msg.sender, phUSD, tokenOut, phusdIn, amountOut, recipient);

262:             IWETH(WETH).withdraw(ethOut);

266:         emit Swapped(msg.sender, phUSD, ETH, phusdIn, ethOut, recipient);

289:         if (susdsDesired > susdsUsed) IERC20(sUSDS).safeTransfer(recipient, susdsDesired - susdsUsed);

290:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

291:         emit LiquidityAdded(msg.sender, sUSDS, lp, susdsUsed, phusdUsed, liquidity, recipient);

322:         if (shares > sharesUsed) usdsRefunded = IERC4626(sUSDS).redeem(shares - sharesUsed, recipient, address(this));

323:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

325:         emit LiquidityAdded(msg.sender, USDS, lp, usdsUsed, phusdUsed, liquidity, recipient);

391:         return _quoteSusdsToPhusd(_quoteToSusds(USDC, usdc));

399:         return usdc == 0 ? 0 : _quoteV3(USDC, WETH, usdc);

413:         uint256 tout = ISkyPSM(skyPSM).tout();

440:             usdc = ICurveMetaPool(curveDolaPool).exchange_underlying(CURVE_META_DOLA, CURVE_META_USDC, amount, 0);

443:             usdc = ICurveStableSwapNG(curveUsdePool).exchange(CURVE_NG_USDE, CURVE_NG_USDC, amount, 0);

447:         uint256 usds = ISkyPSM(skyPSM).sellGem(address(this), usdc);

455:         uint256 usds = IERC4626(sUSDS).redeem(shares, address(this), address(this));

462:             amountOut = ICurveMetaPool(curveDolaPool).exchange_underlying(CURVE_META_USDC, CURVE_META_DOLA, usdc, 0);

464:             IERC20(USDC).forceApprove(curveUsdePool, usdc);

465:             amountOut = ICurveStableSwapNG(curveUsdePool).exchange(CURVE_NG_USDC, CURVE_NG_USDE, usdc, 0);

477:             spent = ISkyPSM(skyPSM).buyGem(usdcTo, gemAmt);

478:             IERC20(USDS).forceApprove(skyPSM, 0);

478:             IERC20(USDS).forceApprove(skyPSM, 0);

480:         if (usds > spent) IERC20(USDS).safeTransfer(dustTo, usds - spent);

485:         shares = IERC4626(sUSDS).deposit(usds, address(this));

501:         uint256[] memory amounts = IUniswapV2RouterPeriphery(v2Router)

508:         return IUniswapV3SwapRouter(v3SwapRouter)

545:         IERC20(phUSD).forceApprove(v2Router, phusdDesired);

546:         (susdsUsed, phusdUsed, liquidity) = IUniswapV2RouterPeriphery(v2Router)

547:             .addLiquidity(sUSDS, phUSD, susdsDesired, phusdDesired, susdsMin, phusdMin, recipient, deadline);

547:             .addLiquidity(sUSDS, phUSD, susdsDesired, phusdDesired, susdsMin, phusdMin, recipient, deadline);

548:         IERC20(sUSDS).forceApprove(v2Router, 0);

548:         IERC20(sUSDS).forceApprove(v2Router, 0);

549:         IERC20(phUSD).forceApprove(v2Router, 0);

549:         IERC20(phUSD).forceApprove(v2Router, 0);

565:         usds -= (usds * ISkyPSM(skyPSM).tin()) / WAD;

566:         return IERC4626(sUSDS).previewDeposit(usds);

```

### <a name="GAS-3"></a>[GAS-3] For Operations that will not overflow, you could use unchecked

*Instances (21)*:
```solidity
File: src/periphery/UniswapHelper.sol

4: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

7: import {ISkyPSM} from "@yield-claim-nft/interfaces/ISkyPSM.sol";

8: import {IUniswapV2Factory} from "@yield-claim-nft/interfaces/uniswap/IUniswapV2Factory.sol";

9: import {IUniswapV2RouterPeriphery} from "./interfaces/IUniswapV2RouterPeriphery.sol";

10: import {IUniswapV3SwapRouter} from "./interfaces/IUniswapV3SwapRouter.sol";

11: import {IQuoterV2} from "./interfaces/IQuoterV2.sol";

12: import {ICurveMetaPool} from "./interfaces/ICurveMetaPool.sol";

13: import {ICurveStableSwapNG} from "./interfaces/ICurveStableSwapNG.sol";

14: import {IWETH} from "./interfaces/IWETH.sol";

15: import {IUniswapV2PairBurn} from "./interfaces/IUniswapV2PairBurn.sol";

289:         if (susdsDesired > susdsUsed) IERC20(sUSDS).safeTransfer(recipient, susdsDesired - susdsUsed);

290:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

322:         if (shares > sharesUsed) usdsRefunded = IERC4626(sUSDS).redeem(shares - sharesUsed, recipient, address(this));

323:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

324:         usdsUsed = usdsDesired - usdsRefunded;

414:         gemAmt = ((usdsBudget + 1) * WAD - 1) / (conv * (WAD + tout));

480:         if (usds > spent) IERC20(USDS).safeTransfer(dustTo, usds - spent);

564:         uint256 usds = usdc * ISkyPSM(skyPSM).to18ConversionFactor();

565:         usds -= (usds * ISkyPSM(skyPSM).tin()) / WAD;

```

### <a name="GAS-4"></a>[GAS-4] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (14)*:
```solidity
File: src/periphery/UniswapHelper.sol

165:         phUSD = phUSD_;

166:         sUSDS = sUSDS_;

167:         USDS = USDS_;

168:         USDC = USDC_;

169:         DOLA = DOLA_;

170:         USDe = USDe_;

171:         WETH = WETH_;

172:         skyPSM = skyPSM_;

173:         v2Router = v2Router_;

174:         v3SwapRouter = v3SwapRouter_;

175:         v3Quoter = v3Quoter_;

176:         curveDolaPool = curveDolaPool_;

177:         curveUsdePool = curveUsdePool_;

178:         v3Fee = v3Fee_;

```

### <a name="GAS-5"></a>[GAS-5] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (1)*:
```solidity
File: src/periphery/UniswapHelper.sol

51:     address public constant ETH = address(0);

```

### <a name="GAS-6"></a>[GAS-6] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (2)*:
```solidity
File: src/periphery/UniswapHelper.sol

261:         if (ethOut > 0) {

475:         if (gemAmt > 0) {

```

### <a name="GAS-7"></a>[GAS-7] WETH address definition can be use directly
WETH is a wrap Ether contract with a specific address in the Ethereum network, giving the option to define it may cause false recognition, it is healthier to define it directly.

    Advantages of defining a specific contract directly:
    
    It saves gas,
    Prevents incorrect argument definition,
    Prevents execution on a different chain and re-signature issues,
    WETH Address : 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

*Instances (1)*:
```solidity
File: src/periphery/UniswapHelper.sol

69:     address public immutable WETH;

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Array indices should be referenced via `enum`s rather than via numeric literals | 5 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 44 |
| [NC-3](#NC-3) | Functions should not be longer than 50 lines | 27 |
| [NC-4](#NC-4) | Incomplete NatSpec: `@param` is missing on actually documented functions | 10 |
| [NC-5](#NC-5) | Incomplete NatSpec: `@return` is missing on actually documented functions | 5 |
| [NC-6](#NC-6) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 1 |
| [NC-7](#NC-7) | Adding a `return` statement when the function defines a named return variable, is redundant | 11 |
| [NC-8](#NC-8) | Take advantage of Custom Error's return value property | 12 |
### <a name="NC-1"></a>[NC-1] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (5)*:
```solidity
File: src/periphery/UniswapHelper.sol

503:         return amounts[1];

583:         return IUniswapV2RouterPeriphery(v2Router).getAmountsOut(shares, _path(sUSDS, phUSD))[1];

588:         return IUniswapV2RouterPeriphery(v2Router).getAmountsOut(phusdIn, _path(phUSD, sUSDS))[1];

603:         p[0] = a;

604:         p[1] = b;

```

### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (44)*:
```solidity
File: src/periphery/UniswapHelper.sol

129:         if (block.timestamp > deadline) revert Expired(deadline, block.timestamp);

154:         if (

160:         if (

183:         if (msg.sender != WETH) revert ETHNotAccepted(msg.sender);

196:         if (!_isStable(tokenIn)) revert UnsupportedToken(tokenIn);

200:         if (phusdOut < minPhusdOut) revert InsufficientOutput(phusdOut, minPhusdOut);

217:         if (phusdOut < minPhusdOut) revert InsufficientOutput(phusdOut, minPhusdOut);

231:         if (!_isStable(tokenOut)) revert UnsupportedToken(tokenOut);

240:         if (amountOut < minOut) revert InsufficientOutput(amountOut, minOut);

259:         if (ethOut < minEthOut) revert InsufficientOutput(ethOut, minEthOut);

264:             if (!ok) revert ETHTransferFailed();

281:         if (recipient == address(0)) revert ZeroAddress();

289:         if (susdsDesired > susdsUsed) IERC20(sUSDS).safeTransfer(recipient, susdsDesired - susdsUsed);

290:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

308:         if (recipient == address(0)) revert ZeroAddress();

322:         if (shares > sharesUsed) usdsRefunded = IERC4626(sUSDS).redeem(shares - sharesUsed, recipient, address(this));

323:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

340:         if (recipient == address(0)) revert ZeroAddress();

341:         if (liquidity == 0) revert ZeroAmount();

344:         if (susdsOut < susdsMin) revert InsufficientOutput(susdsOut, susdsMin);

345:         if (phusdOut < phusdMin) revert InsufficientOutput(phusdOut, phusdMin);

359:         if (recipient == address(0)) revert ZeroAddress();

360:         if (liquidity == 0) revert ZeroAmount();

364:         if (phusdOut < phusdMin) revert InsufficientOutput(phusdOut, phusdMin);

367:         if (usdsOut < usdsMin) revert InsufficientOutput(usdsOut, usdsMin);

376:         if (!_isStable(tokenIn)) revert UnsupportedToken(tokenIn);

382:         if (!_isStable(tokenOut)) revert UnsupportedToken(tokenOut);

420:         if (amountIn == 0) revert ZeroAmount();

421:         if (recipient == address(0)) revert ZeroAddress();

430:         if (p == address(0)) revert PairNotFound();

435:         if (token == sUSDS) return amount;

436:         if (token == USDS) return _depositUsds(amount);

453:         if (token == USDS) return IERC4626(sUSDS).redeem(shares, recipient, address(this));

456:         if (token == USDC) return _usdsToUsdc(usds, recipient, recipient);

459:         if (usdc == 0) return 0;

480:         if (usds > spent) IERC20(USDS).safeTransfer(dustTo, usds - spent);

555:         if (token == sUSDS) return amount;

556:         if (token == USDS) return IERC4626(sUSDS).previewDeposit(amount);

570:         if (token == sUSDS) return shares;

572:         if (token == USDS) return usds;

574:         if (token == USDC || usdc == 0) return usdc;

582:         if (shares == 0) return 0;

587:         if (phusdIn == 0) return 0;

592:         if (amountIn == 0) return 0;

```

### <a name="NC-3"></a>[NC-3] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (27)*:
```solidity
File: src/periphery/UniswapHelper.sol

190:     function swapToPhUSD(address tokenIn, uint256 amountIn, uint256 minPhusdOut, address recipient, uint256 deadline)

206:     function swapETHToPhUSD(uint256 minPhusdOut, address recipient, uint256 deadline)

225:     function swapFromPhUSD(address tokenOut, uint256 phusdIn, uint256 minOut, address recipient, uint256 deadline)

247:     function swapPhUSDToETH(uint256 phusdIn, uint256 minEthOut, address payable recipient, uint256 deadline)

375:     function quoteToPhUSD(address tokenIn, uint256 amountIn) external view returns (uint256 phusdOut) {

381:     function quoteFromPhUSD(address tokenOut, uint256 phusdIn) external view returns (uint256 amountOut) {

389:     function quoteETHToPhUSD(uint256 ethIn) external returns (uint256 phusdOut) {

397:     function quotePhUSDToETH(uint256 phusdIn) external returns (uint256 ethOut) {

411:     function psmGemForUsds(uint256 usdsBudget) public view returns (uint256 gemAmt) {

419:     function _checkSwapArgs(uint256 amountIn, address recipient) internal pure {

424:     function _isStable(address token) internal view returns (bool) {

428:     function _requirePair() internal view returns (address p) {

434:     function _toSusds(address token, uint256 amount) internal returns (uint256 shares) {

452:     function _fromSusds(address token, uint256 shares, address recipient) internal returns (uint256 amountOut) {

472:     function _usdsToUsdc(uint256 usds, address usdcTo, address dustTo) internal returns (uint256 gemAmt) {

483:     function _depositUsds(uint256 usds) internal returns (uint256 shares) {

488:     function _swapSusdsForPhusd(uint256 shares, address to, uint256 deadline) internal returns (uint256) {

492:     function _swapPhusdForSusds(uint256 phusdIn, address to, uint256 deadline) internal returns (uint256) {

496:     function _v2Swap(address tokenIn, address tokenOut, uint256 amountIn, address to, uint256 deadline)

506:     function _v3Swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 deadline) internal returns (uint256) {

525:     function _burnLiquidity(address lp, uint256 liquidity, address to)

554:     function _quoteToSusds(address token, uint256 amount) internal view returns (uint256) {

569:     function _quoteFromSusds(address token, uint256 shares) internal view returns (uint256) {

581:     function _quoteSusdsToPhusd(uint256 shares) internal view returns (uint256) {

586:     function _quotePhusdToSusds(uint256 phusdIn) internal view returns (uint256) {

591:     function _quoteV3(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 amountOut) {

601:     function _path(address a, address b) internal pure returns (address[] memory p) {

```

### <a name="NC-4"></a>[NC-4] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (10)*:
```solidity
File: src/periphery/UniswapHelper.sol

188:     /// @notice Swap `amountIn` of `tokenIn` (DOLA, USDC, USDe, USDS or sUSDS) for phUSD.
         /// @return phusdOut phUSD delivered to `recipient`.
         function swapToPhUSD(address tokenIn, uint256 amountIn, uint256 minPhusdOut, address recipient, uint256 deadline)

204:     /// @notice Swap the attached ETH for phUSD (WETH -> V3 -> USDC -> PSM -> USDS -> sUSDS -> V2).
         /// @return phusdOut phUSD delivered to `recipient`.
         function swapETHToPhUSD(uint256 minPhusdOut, address recipient, uint256 deadline)

221:     /// @notice Swap `phusdIn` phUSD for `tokenOut` (DOLA, USDC, USDe, USDS or sUSDS).
         /// @dev    For USDC-based outputs, any USDS left over by the floored PSM `buyGem` is refunded to
         ///         `recipient` on top of `amountOut`.
         /// @return amountOut `tokenOut` delivered to `recipient`.
         function swapFromPhUSD(address tokenOut, uint256 phusdIn, uint256 minOut, address recipient, uint256 deadline)

244:     /// @notice Swap `phusdIn` phUSD for native ETH (V2 -> sUSDS -> USDS -> PSM -> USDC -> V3 -> WETH).
         /// @dev    USDS dust from the floored PSM `buyGem` is refunded to `recipient`.
         /// @return ethOut ETH sent to `recipient`.
         function swapPhUSDToETH(uint256 phusdIn, uint256 minEthOut, address payable recipient, uint256 deadline)

271:     /// @notice Two-sided add of sUSDS + phUSD. LP goes to `recipient`; unused sUSDS/phUSD is refunded
         ///         to `recipient`. The mins are enforced by Router02 against the optimal amounts.
         function addLiquiditySUSDS(
             uint256 susdsDesired,
             uint256 phusdDesired,
             uint256 susdsMin,
             uint256 phusdMin,
             address recipient,
             uint256 deadline

294:     /// @notice Two-sided add of USDS + phUSD: the USDS is wrapped to sUSDS in the same transaction.
         ///         The USDS minimum is converted to a share minimum with `previewDeposit` (flooring).
         ///         Unused sUSDS is redeemed back to USDS; it and unused phUSD are refunded to `recipient`.
         /// @return usdsUsed  USDS consumed (`usdsDesired` minus the USDS refunded).
         /// @return phusdUsed phUSD consumed.
         /// @return liquidity LP minted to `recipient`.
         function addLiquidityUSDS(
             uint256 usdsDesired,
             uint256 phusdDesired,
             uint256 usdsMin,
             uint256 phusdMin,
             address recipient,
             uint256 deadline

328:     /// @notice Remove `liquidity` LP for sUSDS + phUSD, both to `recipient`.
         /// @dev    Burns directly against the factory-resolved pair (exactly what Router02's
         ///         `removeLiquidity` does internally) rather than calling Router02: the vendored anvil
         ///         Router02 artifact (`script/uniswap-artifacts/`) has no `removeLiquidity`, so this keeps
         ///         plain removal one transaction on anvil as well as mainnet.
         function removeLiquiditySUSDS(
             uint256 liquidity,
             uint256 susdsMin,
             uint256 phusdMin,
             address recipient,
             uint256 deadline

349:     /// @notice Remove `liquidity` LP and unwrap the sUSDS side to USDS, in one transaction. Both
         ///         USDS and phUSD go to `recipient`. Burns directly against the pair (see
         ///         `removeLiquiditySUSDS`).
         function removeLiquidityUSDS(
             uint256 liquidity,
             uint256 usdsMin,
             uint256 phusdMin,
             address recipient,
             uint256 deadline

386:     /// @notice Expected phUSD out for `ethIn` ETH.
         /// @dev    NOT view: QuoterV2 cannot be static-called. Intended for `eth_call` /
         ///         `simulateContract` only — never send it as a transaction.
         function quoteETHToPhUSD(uint256 ethIn) external returns (uint256 phusdOut) {

394:     /// @notice Expected ETH out for `phusdIn` phUSD.
         /// @dev    NOT view: QuoterV2 cannot be static-called. Intended for `eth_call` /
         ///         `simulateContract` only — never send it as a transaction.
         function quotePhUSDToETH(uint256 phusdIn) external returns (uint256 ethOut) {

```

### <a name="NC-5"></a>[NC-5] Incomplete NatSpec: `@return` is missing on actually documented functions
The following functions are missing `@return` NatSpec comments.

*Instances (5)*:
```solidity
File: src/periphery/UniswapHelper.sol

271:     /// @notice Two-sided add of sUSDS + phUSD. LP goes to `recipient`; unused sUSDS/phUSD is refunded
         ///         to `recipient`. The mins are enforced by Router02 against the optimal amounts.
         function addLiquiditySUSDS(
             uint256 susdsDesired,
             uint256 phusdDesired,
             uint256 susdsMin,
             uint256 phusdMin,
             address recipient,
             uint256 deadline
         ) external checkDeadline(deadline) returns (uint256 susdsUsed, uint256 phusdUsed, uint256 liquidity) {

328:     /// @notice Remove `liquidity` LP for sUSDS + phUSD, both to `recipient`.
         /// @dev    Burns directly against the factory-resolved pair (exactly what Router02's
         ///         `removeLiquidity` does internally) rather than calling Router02: the vendored anvil
         ///         Router02 artifact (`script/uniswap-artifacts/`) has no `removeLiquidity`, so this keeps
         ///         plain removal one transaction on anvil as well as mainnet.
         function removeLiquiditySUSDS(
             uint256 liquidity,
             uint256 susdsMin,
             uint256 phusdMin,
             address recipient,
             uint256 deadline
         ) external checkDeadline(deadline) returns (uint256 susdsOut, uint256 phusdOut) {

349:     /// @notice Remove `liquidity` LP and unwrap the sUSDS side to USDS, in one transaction. Both
         ///         USDS and phUSD go to `recipient`. Burns directly against the pair (see
         ///         `removeLiquiditySUSDS`).
         function removeLiquidityUSDS(
             uint256 liquidity,
             uint256 usdsMin,
             uint256 phusdMin,
             address recipient,
             uint256 deadline
         ) external checkDeadline(deadline) returns (uint256 usdsOut, uint256 phusdOut) {

386:     /// @notice Expected phUSD out for `ethIn` ETH.
         /// @dev    NOT view: QuoterV2 cannot be static-called. Intended for `eth_call` /
         ///         `simulateContract` only — never send it as a transaction.
         function quoteETHToPhUSD(uint256 ethIn) external returns (uint256 phusdOut) {

394:     /// @notice Expected ETH out for `phusdIn` phUSD.
         /// @dev    NOT view: QuoterV2 cannot be static-called. Intended for `eth_call` /
         ///         `simulateContract` only — never send it as a transaction.
         function quotePhUSDToETH(uint256 phusdIn) external returns (uint256 ethOut) {

```

### <a name="NC-6"></a>[NC-6] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (1)*:
```solidity
File: src/periphery/UniswapHelper.sol

183:         if (msg.sender != WETH) revert ETHNotAccepted(msg.sender);

```

### <a name="NC-7"></a>[NC-7] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (11)*:
```solidity
File: src/periphery/UniswapHelper.sol

374:     /// @notice Expected phUSD out for `amountIn` of `tokenIn` (DOLA, USDC, USDe, USDS or sUSDS).
         function quoteToPhUSD(address tokenIn, uint256 amountIn) external view returns (uint256 phusdOut) {
             if (!_isStable(tokenIn)) revert UnsupportedToken(tokenIn);
             return _quoteSusdsToPhusd(_quoteToSusds(tokenIn, amountIn));

380:     /// @notice Expected `tokenOut` (DOLA, USDC, USDe, USDS or sUSDS) out for `phusdIn` phUSD.
         function quoteFromPhUSD(address tokenOut, uint256 phusdIn) external view returns (uint256 amountOut) {
             if (!_isStable(tokenOut)) revert UnsupportedToken(tokenOut);
             return _quoteFromSusds(tokenOut, _quotePhusdToSusds(phusdIn));

386:     /// @notice Expected phUSD out for `ethIn` ETH.
         /// @dev    NOT view: QuoterV2 cannot be static-called. Intended for `eth_call` /
         ///         `simulateContract` only — never send it as a transaction.
         function quoteETHToPhUSD(uint256 ethIn) external returns (uint256 phusdOut) {
             uint256 usdc = _quoteV3(WETH, USDC, ethIn);
             return _quoteSusdsToPhusd(_quoteToSusds(USDC, usdc));

394:     /// @notice Expected ETH out for `phusdIn` phUSD.
         /// @dev    NOT view: QuoterV2 cannot be static-called. Intended for `eth_call` /
         ///         `simulateContract` only — never send it as a transaction.
         function quotePhUSDToETH(uint256 phusdIn) external returns (uint256 ethOut) {
             uint256 usdc = _quoteFromSusds(USDC, _quotePhusdToSusds(phusdIn));
             return usdc == 0 ? 0 : _quoteV3(USDC, WETH, usdc);

433:     /// @dev Converts `amount` of a supported stable held by this contract into sUSDS held by this contract.
         function _toSusds(address token, uint256 amount) internal returns (uint256 shares) {
             if (token == sUSDS) return amount;
             if (token == USDS) return _depositUsds(amount);
             uint256 usdc = amount;
             if (token == DOLA) {
                 IERC20(DOLA).forceApprove(curveDolaPool, amount);
                 usdc = ICurveMetaPool(curveDolaPool).exchange_underlying(CURVE_META_DOLA, CURVE_META_USDC, amount, 0);
             } else if (token == USDe) {
                 IERC20(USDe).forceApprove(curveUsdePool, amount);
                 usdc = ICurveStableSwapNG(curveUsdePool).exchange(CURVE_NG_USDE, CURVE_NG_USDC, amount, 0);
             }
             // token is now USDC
             IERC20(USDC).forceApprove(skyPSM, usdc);
             uint256 usds = ISkyPSM(skyPSM).sellGem(address(this), usdc);
             return _depositUsds(usds);

433:     /// @dev Converts `amount` of a supported stable held by this contract into sUSDS held by this contract.
         function _toSusds(address token, uint256 amount) internal returns (uint256 shares) {
             if (token == sUSDS) return amount;

433:     /// @dev Converts `amount` of a supported stable held by this contract into sUSDS held by this contract.
         function _toSusds(address token, uint256 amount) internal returns (uint256 shares) {
             if (token == sUSDS) return amount;
             if (token == USDS) return _depositUsds(amount);

451:     /// @dev Converts `shares` sUSDS held by this contract into `token`, delivered to `recipient`.
         function _fromSusds(address token, uint256 shares, address recipient) internal returns (uint256 amountOut) {
             if (token == USDS) return IERC4626(sUSDS).redeem(shares, recipient, address(this));

451:     /// @dev Converts `shares` sUSDS held by this contract into `token`, delivered to `recipient`.
         function _fromSusds(address token, uint256 shares, address recipient) internal returns (uint256 amountOut) {
             if (token == USDS) return IERC4626(sUSDS).redeem(shares, recipient, address(this));
     
             uint256 usds = IERC4626(sUSDS).redeem(shares, address(this), address(this));
             if (token == USDC) return _usdsToUsdc(usds, recipient, recipient);

451:     /// @dev Converts `shares` sUSDS held by this contract into `token`, delivered to `recipient`.
         function _fromSusds(address token, uint256 shares, address recipient) internal returns (uint256 amountOut) {
             if (token == USDS) return IERC4626(sUSDS).redeem(shares, recipient, address(this));
     
             uint256 usds = IERC4626(sUSDS).redeem(shares, address(this), address(this));
             if (token == USDC) return _usdsToUsdc(usds, recipient, recipient);
     
             uint256 usdc = _usdsToUsdc(usds, address(this), recipient);
             if (usdc == 0) return 0;

591:     function _quoteV3(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 amountOut) {
             if (amountIn == 0) return 0;

```

### <a name="NC-8"></a>[NC-8] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (12)*:
```solidity
File: src/periphery/UniswapHelper.sol

159:         ) revert ZeroAddress();

163:         ) revert CurveCoinMismatch();

264:             if (!ok) revert ETHTransferFailed();

281:         if (recipient == address(0)) revert ZeroAddress();

308:         if (recipient == address(0)) revert ZeroAddress();

340:         if (recipient == address(0)) revert ZeroAddress();

341:         if (liquidity == 0) revert ZeroAmount();

359:         if (recipient == address(0)) revert ZeroAddress();

360:         if (liquidity == 0) revert ZeroAmount();

420:         if (amountIn == 0) revert ZeroAmount();

421:         if (recipient == address(0)) revert ZeroAddress();

430:         if (p == address(0)) revert PairNotFound();

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Some tokens may revert when zero value transfers are made | 14 |
| [L-2](#L-2) | Division by zero not prevented | 1 |
| [L-3](#L-3) | External call recipient may consume all transaction gas | 1 |
| [L-4](#L-4) | Prevent accidentally burning tokens | 2 |
| [L-5](#L-5) | Loss of precision | 2 |
| [L-6](#L-6) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
### <a name="L-1"></a>[L-1] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (14)*:
```solidity
File: src/periphery/UniswapHelper.sol

197:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

232:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdIn);

253:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdIn);

283:         IERC20(sUSDS).safeTransferFrom(msg.sender, address(this), susdsDesired);

284:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdDesired);

289:         if (susdsDesired > susdsUsed) IERC20(sUSDS).safeTransfer(recipient, susdsDesired - susdsUsed);

290:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

310:         IERC20(USDS).safeTransferFrom(msg.sender, address(this), usdsDesired);

311:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdDesired);

323:         if (phusdDesired > phusdUsed) IERC20(phUSD).safeTransfer(recipient, phusdDesired - phusdUsed);

368:         IERC20(phUSD).safeTransfer(recipient, phusdOut);

467:         IERC20(token).safeTransfer(recipient, amountOut);

480:         if (usds > spent) IERC20(USDS).safeTransfer(dustTo, usds - spent);

529:         IERC20(lp).safeTransferFrom(msg.sender, lp, liquidity);

```

### <a name="L-2"></a>[L-2] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: src/periphery/UniswapHelper.sol

414:         gemAmt = ((usdsBudget + 1) * WAD - 1) / (conv * (WAD + tout));

```

### <a name="L-3"></a>[L-3] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (1)*:
```solidity
File: src/periphery/UniswapHelper.sol

263:             (bool ok,) = recipient.call{value: ethOut}("");

```

### <a name="L-4"></a>[L-4] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (2)*:
```solidity
File: src/periphery/UniswapHelper.sol

343:         (susdsOut, phusdOut) = _burnLiquidity(lp, liquidity, recipient);

363:         (shares, phusdOut) = _burnLiquidity(lp, liquidity, address(this));

```

### <a name="L-5"></a>[L-5] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (2)*:
```solidity
File: src/periphery/UniswapHelper.sol

414:         gemAmt = ((usdsBudget + 1) * WAD - 1) / (conv * (WAD + tout));

565:         usds -= (usds * ISkyPSM(skyPSM).tin()) / WAD;

```

### <a name="L-6"></a>[L-6] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: src/periphery/UniswapHelper.sol

2: pragma solidity ^0.8.20;

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 7 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (7)*:
```solidity
File: src/periphery/UniswapHelper.sol

197:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

232:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdIn);

253:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdIn);

283:         IERC20(sUSDS).safeTransferFrom(msg.sender, address(this), susdsDesired);

284:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdDesired);

310:         IERC20(USDS).safeTransferFrom(msg.sender, address(this), usdsDesired);

311:         IERC20(phUSD).safeTransferFrom(msg.sender, address(this), phusdDesired);

```


## High Issues


| |Issue|Instances|
|-|:-|:-:|
| [H-1](#H-1) | `get_dy_underlying()` is not a flash-loan-resistant price | 2 |
### <a name="H-1"></a>[H-1] `get_dy_underlying()` is not a flash-loan-resistant price

#### Impact:
`get_dy_underlying()` calculates the price based on the contract's underlying reserves, which can be manipulated by sandwiching the call with a flash loan. Therefore, using its output as a price oracle is not safe and will lead to loss of funds. Use a Chainlink oracle instead.

*Instances (2)*:
```solidity
File: src/periphery/UniswapHelper.sol

559:             usdc = ICurveMetaPool(curveDolaPool).get_dy_underlying(CURVE_META_DOLA, CURVE_META_USDC, amount);

576:             return ICurveMetaPool(curveDolaPool).get_dy_underlying(CURVE_META_USDC, CURVE_META_DOLA, usdc);

```

