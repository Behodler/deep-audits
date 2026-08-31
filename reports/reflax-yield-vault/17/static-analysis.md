# Static Analysis — reflax-yield-vault run 17

- **Commit:** `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9`
- **Analysed from:** `/home/justin/code/audits/workspace/reflax-yield-vault` (writable clone). Tracked tree already at `cdd0743` with **zero modified tracked files**, so no checkout was needed; the 28 untracked PoC/test artifacts were preserved. `lib/` was never touched.
- **Tools:** Slither 0.11.3, Aderyn 0.6.8, Semgrep 1.163.0. 4naly3er not run this pass.
- **Known-issues suppression:** NONE APPLIED. `knownIssuesCount` is 0 for this project; the cache carries no suppression authority this run.

## Scope coverage assertion (7/7 per tool)

In-scope set (7 files) and what each tool actually parsed:

| File | Slither | Aderyn | Semgrep |
|---|---|---|---|
| `src/AYieldStrategy.sol` | yes | yes | yes |
| `src/interfaces/IYieldStrategy.sol` | yes | yes | yes |
| `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` | yes | yes | yes |
| `src/concreteYieldStrategies/ERC4626YieldStrategy.sol` | yes | yes | yes |
| `src/AMMAdapters/CurveAMMAdapter.sol` | yes | yes | yes |
| `src/AMMAdapters/IAMMAdapter.sol` | yes | yes | yes |
| `src/AMMAdapters/ICurveRouterNG.sol` | yes | yes | yes |

**All three tools covered 7 of 7.** Evidence, not assumption:

- **Slither** — coverage proven by a second run with `--print contract-summary` (`slither-coverage.txt`), which listed all seven in-scope contracts by name among 31 analysed. The guard from prior runs was honoured: the filter is anchored to `reflax-yield-vault/lib/`, **not** the bare `lib/` that previously matched the absolute path of every first-party file and produced a false 0-result.
- **Aderyn** — `files_details` in `aderyn-report.json` enumerates exactly 8 files: the 7 in-scope plus `src/mocks/MockERC20.sol`.
- **Semgrep** — "Targets scanned: 8, Parsed lines: ~100.0%", the same 8 files.

`test/` was not analysed by any tool (default invocations skip it). `test/` is denylisted in this project's `outOfScope`, so that is acceptable — **but it means tests were not cleared, merely not examined.**

### Semgrep coverage caveat (honest reporting)
Semgrep exited 0 and produced 138 findings, of which **137 are INFO-severity style/gas noise** (`use-short-revert-string` x58, `use-custom-error-not-require` x58, prefix-increment, loop arithmetic, etc.) and exactly **1 is ERROR** — and that one is in an out-of-scope mock. Semgrep has no usable Solidity *security* ruleset here; `p/smart-contracts` is a lint pack. Its exit-0 is **not** a clean bill of health and no security conclusion should be drawn from it. Its built-in ignore list also silently skips `vendor/` directories (`--no-git-ignore` does not lift this); no `vendor/` dir exists in this repo, so nothing was lost that way this run.

## Commands run

```bash
# Slither (from repo root, filter anchored to the project's OWN nested lib)
cd workspace/reflax-yield-vault && slither . \
  --json reports/reflax-yield-vault/17/slither-output.json \
  --filter-paths "reflax-yield-vault/lib/|/test/|/src/mocks/|/Legacy/" \
  --exclude naming-convention,solc-version,pragma,assembly
# exit 255 (normal when findings exist); "analyzed (31 contracts with 96 detectors), 16 result(s) found"

# Slither coverage proof
slither . --print contract-summary --filter-paths "reflax-yield-vault/lib/|/test/|/src/mocks/|/Legacy/"   # exit 0

# Aderyn
cd workspace/reflax-yield-vault && aderyn . --output reports/reflax-yield-vault/17/aderyn-report.json
# exit 0; "Ingesting 8 compiled files [solc : v0.8.30]"; 88 detectors

# Semgrep
cd workspace/reflax-yield-vault && semgrep --config p/smart-contracts --json \
  --output reports/reflax-yield-vault/17/semgrep-output.json src/
# exit 0; 50 rules on 8 files; 138 findings
```

## Results per tool

| Tool | Exit | Analysed | Raw | Kept after filtering |
|---|---|---|---|---|
| Slither 0.11.3 | 255 (findings present) | 31 contracts, 7/7 in scope | 16 | 15 |
| Aderyn 0.6.8 | 0 | 8 files, 7/7 in scope | 1 high + 14 low categories | 6 |
| Semgrep 1.163.0 | 0 | 8 files, 7/7 in scope | 138 (137 INFO) | 1 (out-of-scope mock) |

Slither raw by detector: `unused-return` x4, `uninitialized-local` x3, `reentrancy-no-eth` x2, `incorrect-equality` x2, `calls-loop` x2, `timestamp` x1, `reentrancy-events` x1, `missing-zero-check` x1.

## Filtering applied

Dropped per the standard C4 noise denylist: `missing-zero-check` (AYieldStrategy.sol:366 `setPauser`), and Aderyn's `Centralization Risk` (14 — Law 3, owner is trusted), `Literal Instead of Constant` (15), `Unspecific Solidity Pragma` (8), `PUSH0 Opcode` (8), `Large Numeric Literal`, `State Variable Could Be Immutable`, `Modifier Invoked Only Once` (2), `Public Function Not Used Internally`; plus Semgrep's 137 INFO style rules.

**`timestamp` was deliberately KEPT** (SA-015): this protocol family is time-driven and the 6h/72h withdrawal window boundaries are load-bearing, not informational.

## Delta targeting — story-050 `previewExitFor`

**No detector in any of the three tools raised a direct finding on either implementation** — neither the base at `AYieldStrategy.sol:571-583` nor the override at `ERC4626MarketYieldStrategy.sol:162-186`. The only detector contact is indirect: SA-003 and SA-004 name `previewExitFor` among the cross-function readers of state that is written *after* an external call.

This is **detector silence, not a clean bill.** The classes the targeting note asked about are largely outside these tools' reach:

- **Floor/ceil division and rounding** — the override grosses up with `Math.ceilDiv(netWanted * MAX_BPS, denominator)` (line 176) and then floors again inside `_exitFloor` (line 134, `idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS`). Slither's `divide-before-multiply` did not fire; the mixed ceil-then-floor round-trip needs manual or symbolic review.
- **Division-by-zero** — handled explicitly: `setSlippageTolerance` permits exactly `MAX_BPS`, and the override guards `denominator == 0` by returning `(0, 0)` rather than panicking (lines 170-174). Note `_exitFloor` recomputes the same subtraction without its own guard, but is only reached after that guard.
- **Divergence between the two implementations** — the base is the capped identity (`netGuaranteed == grossToRequest`, no haircut); the override grosses up, caps to `clientBalances`, then reports `_exitFloor(grossToRequest)`. Both `require` the underlying-token check. The base is `virtual override`; the override is `override` only, so no further specialisation is possible below the market strategy.
- **External-call assumptions** — `_exitFloor` reads live `vault.convertToShares` / `vault.balanceOf` / `vault.convertToAssets`, which the NatSpec itself flags as within-block manipulable and fee-blind (`convertToAssets` over-quotes on a fee-charging vault). Detectors do not model this.
- **Unused return values** — SA-008 is the closest live hit: `_disposeShares` discards `vault.redeem`'s return, i.e. the strategy's own direct exit never measures the real balance delta that `previewExitFor`'s NatSpec obliges consumers to measure.

## Normalized findings

21 findings; full structured form in `static-analysis-findings.json`.

### Medium-potential

**SA-001** [`incorrect-equality`, slither, confidence high] — `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:185` (`_totalWithdraw`)

```solidity
if (totalShares == 0 || totalDeposited[token] == 0) { return; }
```

Dangerous strict equality: silent early-return on zero shares/deposits swallows the total-withdrawal request rather than reverting.

**SA-002** [`incorrect-equality`, slither, confidence high] — `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:293` (`_totalWithdraw`)

```solidity
if (totalShares == 0 || totalDeposited[token] == 0) { return; }
```

Same silent-return strict equality as SA-001 on the market strategy.

**SA-003** [`reentrancy-no-eth`, slither, confidence medium] — `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:309` (`_totalWithdraw`)

```solidity
uint256 underlyingReceived = ammAdapter.swap(...); clientBalances[token][client] = 0; totalDeposited[token] -= clientStoredBalance;
```

State written AFTER the external AMM swap. Slither names previewExitFor among the cross-function readers of the stale clientBalances/totalDeposited — DELTA-RELEVANT: a reentrant view during the swap window quotes against un-zeroed principal.

**SA-004** [`reentrancy-no-eth`, slither, confidence medium] — `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:194` (`_totalWithdraw`)

```solidity
uint256 assetsReceived = vault.redeem(...); clientBalances[token][client] = 0; totalDeposited[token] -= clientStoredBalance;
```

Same pattern via vault.redeem; cross-function readers include AYieldStrategy.previewExitFor (base impl).

**SA-005** [`uninitialized-local`, slither, confidence medium] — `src/AMMAdapters/CurveAMMAdapter.sol:74` (`setRoute`)

```solidity
address lastToken; for (uint256 i = 0; i < 11; i++) { if (path[i] != address(0)) { lastToken = path[i]; } }
```

lastToken defaults to address(0); an all-zero path leaves it zero and the require only passes if tokenOut is also zero (already guarded), so likely benign — but the scan of the whole 11-slot array also accepts a path with interior zero gaps.

**SA-006** [`uninitialized-local`, slither, confidence medium] — `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:314` (`_distributeBuffer`)

```solidity
uint256 totalSetAside;
```

Accumulator relies on implicit zero-init; flagged for review, conventionally benign.

**SA-007** [`uninitialized-local`, slither, confidence medium] — `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:435` (`_distributeBuffer`)

```solidity
uint256 totalSetAside;
```

Twin of SA-006 on the market strategy.

**SA-008** [`unused-return`, slither,aderyn, confidence high] — `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:135` (`_disposeShares`)

```solidity
vault.redeem(sharesToRedeem, recipient, address(this));
```

Return value of vault.redeem (assets actually delivered) is discarded — the exit path never measures the real delta. DELTA-RELEVANT: this is precisely the 'measure the actual balance delta across withdraw' obligation that previewExitFor's NatSpec places on consumers, unmet inside the strategy's own direct exit.

**SA-009** [`unchecked-transfer`, slither,aderyn, confidence high] — `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:50` (`constructor`)

```solidity
IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);
```

Raw approve with unchecked boolean return in the constructor; non-standard tokens that return false would silently leave the strategy unapproved. Aderyn independently flags the same line as an Unsafe ERC20 Operation.

### Low-potential

**SA-010** [`unused-return`, slither,aderyn, confidence high] — `src/AYieldStrategy.sol:269` (`setClient`)

```solidity
_authorizedClients.add(client);
```

EnumerableSet.add return ignored — a redundant add is indistinguishable from a fresh one; no revert on no-op.

**SA-011** [`unused-return`, slither,aderyn, confidence high] — `src/AYieldStrategy.sol:271` (`setClient`)

```solidity
_authorizedClients.remove(client);
```

EnumerableSet.remove return ignored — removing a non-member silently succeeds.

**SA-012** [`calls-loop`, slither,aderyn, confidence medium] — `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:408` (`_accrueSurplusShares`)

```solidity
shares = vault.convertToShares(surplus);
```

External vault call inside a loop reached from skimSurplus; a single reverting/expensive token grows unbounded gas and can DoS the whole skim. Aderyn separately flags a require/revert inside the same loop at line 396.

**SA-013** [`calls-loop`, slither,aderyn, confidence medium] — `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:287` (`_accrueSurplusShares`)

```solidity
shares = vault.convertToShares(surplus);
```

Twin of SA-012; Aderyn's loop-revert instance is at line 275.

**SA-014** [`reentrancy-events`, slither, confidence medium] — `src/AMMAdapters/CurveAMMAdapter.sol:140` (`swap`)

```solidity
amountOut = router.exchange(...); emit Swapped(tokenIn, tokenOut, amountIn, amountOut);
```

Swapped event emitted after the external router call; off-chain consumers can observe out-of-order events under reentrancy.

**SA-015** [`timestamp`, slither, confidence medium] — `src/AYieldStrategy.sol:832` (`_updateWithdrawalStatus`)

```solidity
currentTime >= state.initiatedAt + WAITING_PERIOD; currentTime <= state.initiatedAt + TOTAL_DURATION; currentTime > state.initiatedAt + TOTAL_DURATION
```

block.timestamp governs the 6h waiting period and 72h execution window of the two-phase total withdrawal. KEPT DELIBERATELY: this protocol family is time-driven, so the window boundaries are load-bearing, not informational.

**SA-016** [`abi-encodePacked-collision`, aderyn, confidence low] — `src/AYieldStrategy.sol:438` (`_checkWithdrawalState`)

```solidity
revert(string(abi.encodePacked("AYieldStrategy: withdrawal still in waiting period, executable at timestamp: ", _uint256ToString(executableAt))))
```

Aderyn's sole High. LIKELY FALSE POSITIVE: the detector fires on abi.encodePacked with dynamic types, but the result is cast to string for a revert message and never reaches keccak256, so no collision surface exists. Recorded, not suppressed — dedup/severity to dispose.

**SA-017** [`modifier-order`, aderyn, confidence medium] — `src/AYieldStrategy.sol:417` (`multiple`)

```solidity
nonReentrant applied after other modifiers
```

8 instances (lines 417, 464, 628, 646, 663, 677, 682, 687). Preceding modifiers execute outside the reentrancy guard; if any makes an external call the guard does not cover it.

**SA-018** [`shadowing-local`, aderyn, confidence medium] — `src/AMMAdapters/CurveAMMAdapter.sol:48` (`constructor`)

Constructor parameter shadows a state variable.

**SA-019** [`shadowing-local`, aderyn, confidence medium] — `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:61` (`constructor`)

Constructor parameter shadows a state variable.

**SA-020** [`shadowing-local`, aderyn, confidence medium] — `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:43` (`constructor`)

Constructor parameter shadows a state variable.

**SA-021** [`erc20-public-burn`, semgrep, confidence high] — `src/mocks/MockERC20.sol:26` (`burn`)

Anyone can burn other accounts' tokens. OUT OF SCOPE (src/mocks/ is denylisted); recorded for transparency, NOT suppressed on known-issues grounds.

## Raw tool output

### Slither (stdout)

```
'forge clean' running (wd: /home/justin/code/audits/workspace/reflax-yield-vault)
'forge config --json' running
'forge build --build-info --deny never --skip ./test/** ./script/** --force' running (wd: /home/justin/code/audits/workspace/reflax-yield-vault)

ERC4626MarketYieldStrategy._totalWithdraw(address,address,uint256) (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#287-318) uses a dangerous strict equality:
	- totalShares == 0 || totalDeposited[token] == 0 (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#293)
ERC4626YieldStrategy._totalWithdraw(address,address,uint256) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#179-203) uses a dangerous strict equality:
	- totalShares == 0 || totalDeposited[token] == 0 (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#185)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities

Reentrancy in ERC4626MarketYieldStrategy._totalWithdraw(address,address,uint256) (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#287-318):
	External calls:
	- underlyingReceived = ammAdapter.swap(address(vault),address(underlyingToken),sharesToSell,minOut) (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#309)
	State variables written after the call(s):
	- clientBalances[token][client] = 0 (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#312)
	AYieldStrategy.clientBalances (src/AYieldStrategy.sol#45) can be used in cross function reentrancies:
	- ERC4626MarketYieldStrategy.previewExitFor(address,address,uint256) (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#162-186)
	- AYieldStrategy.principalOf(address,address) (src/AYieldStrategy.sol#523-526)
	- AYieldStrategy.totalBalanceOf(address,address) (src/AYieldStrategy.sol#536-550)
	- totalDeposited[token] -= clientStoredBalance (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#313)
	AYieldStrategy.totalDeposited (src/AYieldStrategy.sol#49) can be used in cross function reentrancies:
	- AYieldStrategy.getTotalDeposited(address) (src/AYieldStrategy.sol#602-604)
	- AYieldStrategy.totalBalanceOf(address,address) (src/AYieldStrategy.sol#536-550)
Reentrancy in ERC4626YieldStrategy._totalWithdraw(address,address,uint256) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#179-203):
	External calls:
	- assetsReceived = vault.redeem(sharesToWithdraw,address(this),address(this)) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#194)
	State variables written after the call(s):
	- clientBalances[token][client] = 0 (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#197)
	AYieldStrategy.clientBalances (src/AYieldStrategy.sol#45) can be used in cross function reentrancies:
	- AYieldStrategy.previewExitFor(address,address,uint256) (src/AYieldStrategy.sol#571-583)
	- AYieldStrategy.principalOf(address,address) (src/AYieldStrategy.sol#523-526)
	- AYieldStrategy.totalBalanceOf(address,address) (src/AYieldStrategy.sol#536-550)
	- totalDeposited[token] -= clientStoredBalance (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#198)
	AYieldStrategy.totalDeposited (src/AYieldStrategy.sol#49) can be used in cross function reentrancies:
	- AYieldStrategy.getTotalDeposited(address) (src/AYieldStrategy.sol#602-604)
	- AYieldStrategy.totalBalanceOf(address,address) (src/AYieldStrategy.sol#536-550)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-1

ERC4626MarketYieldStrategy._distributeBuffer(address[],uint256[],uint256,uint256,address).totalSetAside (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#435) is a local variable never initialized
ERC4626YieldStrategy._distributeBuffer(address[],uint256[],uint256,uint256,address).totalSetAside (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#314) is a local variable never initialized
CurveAMMAdapter.setRoute(address,address,address[11],uint256[5][5],address[5]).lastToken (src/AMMAdapters/CurveAMMAdapter.sol#74) is a local variable never initialized
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-local-variables

AYieldStrategy.setClient(address,bool) (src/AYieldStrategy.sol#265-275) ignores return value by _authorizedClients.add(client) (src/AYieldStrategy.sol#269)
AYieldStrategy.setClient(address,bool) (src/AYieldStrategy.sol#265-275) ignores return value by _authorizedClients.remove(client) (src/AYieldStrategy.sol#271)
ERC4626YieldStrategy.constructor(address,address,address) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#43-51) ignores return value by IERC20(_underlyingToken).approve(_erc4626Vault,type()(uint256).max) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#50)
ERC4626YieldStrategy._disposeShares(uint256,address) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#126-138) ignores return value by vault.redeem(sharesToRedeem,recipient,address(this)) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#135)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return

AYieldStrategy.setPauser(address).newPauser (src/AYieldStrategy.sol#364) lacks a zero-check on :
		- _pauser = newPauser (src/AYieldStrategy.sol#366)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#missing-zero-address-validation

ERC4626MarketYieldStrategy._accrueSurplusShares(address,address[],address,uint256,uint256[]) (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#388-414) has external calls inside a loop: shares = vault.convertToShares(surplus) (src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#408)
	Calls stack containing the loop:
		AYieldStrategy.skimSurplus(address,address)
		ERC4626MarketYieldStrategy._skimSurplus(address,address[],address)
ERC4626YieldStrategy._accrueSurplusShares(address,address[],address,uint256,uint256[]) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#267-293) has external calls inside a loop: shares = vault.convertToShares(surplus) (src/concreteYieldStrategies/ERC4626YieldStrategy.sol#287)
	Calls stack containing the loop:
		AYieldStrategy.skimSurplus(address,address)
		ERC4626YieldStrategy._skimSurplus(address,address[],address)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation/#calls-inside-a-loop

Reentrancy in CurveAMMAdapter.swap(address,address,uint256,uint256) (src/AMMAdapters/CurveAMMAdapter.sol#120-141):
	External calls:
	- amountOut = router.exchange(r.path,r.swapParams,amountIn,minAmountOut,r.pools,msg.sender) (src/AMMAdapters/CurveAMMAdapter.sol#138)
	Event emitted after the call(s):
	- Swapped(tokenIn,tokenOut,amountIn,amountOut) (src/AMMAdapters/CurveAMMAdapter.sol#140)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3

AYieldStrategy._updateWithdrawalStatus(AYieldStrategy.WithdrawalState,uint256) (src/AYieldStrategy.sol#832-846) uses timestamp for comparisons
	Dangerous comparisons:
	- currentTime >= state.initiatedAt + WAITING_PERIOD (src/AYieldStrategy.sol#834)
	- currentTime <= state.initiatedAt + TOTAL_DURATION (src/AYieldStrategy.sol#835)
	- currentTime > state.initiatedAt + TOTAL_DURATION (src/AYieldStrategy.sol#842)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp
. analyzed (31 contracts with 96 detectors), 16 result(s) found
```

### Slither coverage (contract-summary, contract names)

```
+ Contract AYieldStrategy
+ Contract Arrays
+ Contract Comparators
+ Contract Context
+ Contract CurveAMMAdapter
+ Contract ERC20
+ Contract ERC4626MarketYieldStrategy
+ Contract ERC4626YieldStrategy
+ Contract EnumerableSet
+ Contract IAMMAdapter
+ Contract ICurveRouterNG
+ Contract IERC1155Errors
+ Contract IERC1363
+ Contract IERC165
+ Contract IERC20
+ Contract IERC20Errors
+ Contract IERC20Metadata
+ Contract IERC4626
+ Contract IERC721Errors
+ Contract IPausable
+ Contract IYieldStrategy
+ Contract Math
+ Contract MockERC20
+ Contract Ownable
+ Contract Panic
+ Contract Pausable
+ Contract ReentrancyGuard
+ Contract SafeCast
+ Contract SafeERC20
+ Contract SlotDerivation
+ Contract StorageSlot
```

### Aderyn (stdout tail)

```
Remappings - [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "pauser/=lib/mutable/pauser/src/",
    "erc4626-tests/=lib/openzeppelin-contracts/lib/erc4626-tests/",
    "forge-std/=lib/forge-std/src/",
    "halmos-cheatcodes/=lib/openzeppelin-contracts/lib/halmos-cheatcodes/src/",
    "mutable/=lib/mutable/pauser/src/",
    "openzeppelin-contracts/=lib/openzeppelin-contracts/",
]
EVM version - prague
------------------------------------------------------------------
# Source Scope
------------------------------------------------------------------
Include Filepaths Containing - No specific criteria.
Exclude Filepaths Containing - No specific criteria.
Auto Excluding - No Files.
------------------------------------------------------------------
# Compiling Abstract Syntax Trees
------------------------------------------------------------------
Ingesting 8 compiled files [solc : v0.8.30]
------------------------------------------------------------------
# Scanning Contracts
------------------------------------------------------------------
Running 88 detectors
Detectors run, printing report.
Report printed to /home/justin/code/audits/reports/reflax-yield-vault/17/aderyn-report.json

🪶 Aderyn spotted all it could. Stay secure.
If our little bird helped you out, give it a perch with a GitHub Star ⭐
https://github.com/Cyfrin/aderyn
```

### Aderyn issue categories

```
HIGH:
  `abi.encodePacked()` Hash Collision [1]
LOW:
  Centralization Risk [14]
  Large Numeric Literal [1]
  Literal Instead of Constant [15]
  Local Variable Shadows State Variable [3]
  Modifier Invoked Only Once [2]
  `nonReentrant` is Not the First Modifier [8]
  PUSH0 Opcode [8]
  Loop Contains `require`/`revert` [2]
  Address State Variable Set Without Checks [1]
  State Variable Could Be Immutable [1]
  Unchecked Return [4]
  Unsafe ERC20 Operation [1]
  Unspecific Solidity Pragma [8]
  Public Function Not Used Internally [1]
```

### Semgrep (stdout tail)

```
  Scanning 8 files tracked by git with 50 Code rules:
  Scanning 8 files with 50 solidity rules.
                
                
┌──────────────┐
│ Scan Summary │
└──────────────┘
✅ Scan completed successfully.
 • Findings: 138 (138 blocking)
 • Rules run: 50
 • Targets scanned: 8
 • Parsed lines: ~100.0%
 • Scan was limited to files tracked by git
 • For a detailed list of skipped files and lines, run semgrep with the --verbose flag
Ran 50 rules on 8 files: 138 findings.

A new version of Semgrep is available. See https://semgrep.dev/docs/upgrading

📢 Too many findings? Try Semgrep Pro for more powerful queries and less noise.
   See https://sg.run/false-positives.
```

### Semgrep rule tally

```
     58 use-short-revert-string
     58 use-custom-error-not-require
      6 use-prefix-increment-not-postfix
      5 unnecessary-checked-arithmetic-in-loop
      4 non-payable-constructor
      4 array-length-outside-loop
      2 use-ownable2step
      1 erc20-public-burn
```
