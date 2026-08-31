# Contract Profiles — reflax-yield-vault (reflax-yield-vault)

Profile timestamp: 2026-05-25
Pragma: `^0.8.13` (no solc pin in foundry.toml; checked arithmetic by compiler default)
Scope: local single-contract analysis + interface abstraction. Cross-contract exploitability, oracle/AMM manipulation, and economic impact are deferred to interaction/econ scanners.

Intended-design facts (NOT to be flagged as bugs):
- Principal is decremented by the REQUESTED amount, not the RECEIVED amount (shortfall accrues as protocol-owned yield).
- AMM routes are bidirectional-by-invariant (both directions must be configured before either is usable).
- Curve Router NG `0x16C6521Dff6baB339122a0FE25a9116693265353` is trusted.
- Standard ERC20 tokens assumed (no fee-on-transfer / rebasing / weird tokens).

Inheritance (context, out of scope): `ERC4626MarketYieldStrategy → AYieldStrategy → {IYieldStrategy, IPausable, Ownable, ReentrancyGuard, Pausable}`.

---

## 1. ERC4626MarketYieldStrategy.sol

### Purpose / role
Yield-strategy adapter that gains ERC4626 vault-share exposure by BUYING shares on an AMM at deposit and SELLING them at withdrawal, rather than calling `vault.deposit()/redeem()`. Designed to wrap vaults with withdrawal restrictions (e.g. sUSDe 7-day cooldown). Principal accounting and proportional-yield distribution mirror `ERC4626YieldStrategy`, but settlement is via `IAMMAdapter.swap`. Concrete implementation of the abstract `AYieldStrategy` virtual hooks.

### State variables & invariants
| Variable | Type | Mutability | Notes / invariant |
|---|---|---|---|
| `underlyingToken` | `IERC20` immutable | set in ctor (non-zero) | the only accepted `token`; every entrypoint requires `token == address(underlyingToken)` |
| `vault` | `IERC4626` immutable | set in ctor (non-zero) | external ERC4626 whose shares are traded; pricing oracle via `convertToShares/convertToAssets` |
| `ammAdapter` | `IAMMAdapter` immutable | set in ctor (non-zero) | settlement venue |
| `slippageToleranceBps` | `uint256` | owner-set via `setSlippageTolerance` | bounded `<= MAX_BPS` (10000). NOTE: default is `0` until owner sets it → `minOut == idealShares/idealUnderlying` (zero slippage tolerance), which makes swaps revert under any real-world price impact. See LOCAL-002. |
| `MAX_BPS` | constant 10000 | — | |
| `clientBalances[token][account]` | mapping | `private` | principal ledger; sum over accounts == `totalDeposited[token]` (maintained by paired ±amount updates) |
| `totalDeposited[token]` | mapping | `private` | aggregate principal; used as denominator for proportional value |

Accounting invariants that hold locally:
- INV-1: `totalDeposited[token] == Σ clientBalances[token][*]` — every mutation updates both sides by the same `amount` (deposit `+amount/+amount`; withdraw `-amount/-amount`; `_totalWithdraw` `-clientStoredBalance` and zeroing the client; `_skimSurplus*` touches neither). Holds.
- INV-2: principal is monotone w.r.t. explicit deposit/withdraw only; surplus skims never change principal (verified — `_skimSurplus` / `_skimSurplusBatch` leave both mappings untouched).
- INV-3: `slippageToleranceBps <= MAX_BPS` enforced at setter, so `(MAX_BPS - slippageToleranceBps)` never underflows.

### External / public functions
| Function | Visibility | Access control | Reentrancy | Pausable | State changes | External calls |
|---|---|---|---|---|---|---|
| `underlying()` | external view | none | — | — | none | none |
| `principalOf(token,account)` | external view | none | — | — | none | none |
| `totalBalanceOf(token,account)` | external view | none | — | — | none | `vault.balanceOf`, `vault.convertToAssets` |
| `balanceOf(token,account)` | external view | none | — | — | none | self-call `this.principalOf` |
| `getTotalDeposited(token)` | external view | none | — | — | none | none |
| `getTotalShares()` | external view | none | — | — | none | `vault.balanceOf` |
| `setSlippageTolerance(bps)` | external | `onlyOwner` | no | no | `slippageToleranceBps` | none |
| `deposit(token,amount,recipient)` | external | `onlyAuthorizedClient` | `nonReentrant` | `whenNotPaused` | `clientBalances`,`totalDeposited` | `underlyingToken.transferFrom`, `vault.convertToShares`, `underlyingToken.safeIncreaseAllowance`, `ammAdapter.swap` |
| `withdraw(token,amount,recipient)` | external | `onlyAuthorizedClient` | `nonReentrant` | `whenNotPaused` | `clientBalances`,`totalDeposited` | `vault.convertToShares/convertToAssets`, `vault.balanceOf`, `IERC20(vault).safeIncreaseAllowance`, `ammAdapter.swap`, `underlyingToken.transfer` |
| `depositAsOwner(token,amount,client)` | external | `onlyOwner` | `nonReentrant` | NO whenNotPaused (intentional) | same as deposit | same as deposit |
| `withdrawAsOwner(client,recipient,amount)` | external | `onlyOwner` | `nonReentrant` | NO whenNotPaused (intentional) | same as withdraw | same as withdraw |
| inherited `skimSurplus / skimSurplusBatch` | external | `onlyAuthorizedWithdrawer` | `nonReentrant` | `whenNotPaused` | none (principal) | vault pricing + `ammAdapter.swap` + transfer |
| inherited `totalWithdrawal` | external | `onlyOwner` | `nonReentrant` | `whenNotPaused` | withdrawalStates, then `_totalWithdraw` mutates balances | as `_totalWithdraw` |
| inherited `emergencyWithdraw` | external | `onlyOwner` | NO nonReentrant | no | none | `IERC20(vault).safeTransfer(owner)` |
| inherited `setClient/setWithdrawer/setPauser` | external | `onlyOwner` | — | — | auth mappings / pauser | none |
| inherited `pause` | external | `onlyPauser` | — | — | paused | none |
| inherited `unpause` | external | owner OR pauser | — | — | paused | none |

### Internal settlement hooks
- `_depositInternal` — pulls underlying from `depositor`, computes `idealShares = vault.convertToShares(amount)`, `minOut = idealShares*(MAX_BPS-bps)/MAX_BPS`, approves adapter, `swap(underlying→vault, amount, minOut)`, requires `sharesReceived>0`, then credits principal `+amount`. NOTE: minOut is computed in SHARES but the adapter returns the actual token bought (vault shares) — units consistent.
- `_withdrawInternal` — caps `amount` to client principal; `sharesToSell = convertToShares(amount)` capped to held shares; `minOut = convertToAssets(sharesToSell)*(...)/MAX_BPS`; approves & `swap(vault→underlying)`; transfers RECEIVED to recipient; decrements principal by REQUESTED `amount` (intended). Note: when `sharesToSell` is capped to `availableShares`, principal is still decremented by full requested `amount` — intended (protocol-favoring), reconciled by INV-1 since both mappings drop by the same `amount`.
- `_emergencyWithdraw(amount)` — transfers raw vault SHARES (not underlying) to `owner()`, capped to held shares. Bypasses AMM and pause. No principal update (owner is trusted to redistribute).
- `_totalWithdraw(token,client,amount)` — proportional `sharesToSell = totalShares*clientStoredBalance/totalDeposited`; swaps to underlying; zeroes client principal and subtracts `clientStoredBalance` from total; sends proceeds to `owner()`. The `amount` arg (cached balance from Phase-1) is effectively unused for share sizing — sizing is recomputed live from current `clientStoredBalance`.
- `_skimSurplus(token,client,amount,recipient)` — `surplus = totalBalanceOf - principal`; requires `amount<=surplus`; sells `convertToShares(amount)` shares (capped); transfers proceeds to recipient; principal untouched.
- `_skimSurplusBatch(token,clients[],recipient)` — snapshots `totalValue` once, loops clients summing per-client FLOORED `convertToShares(surplus)`, single aggregate swap, proceeds to recipient; principal untouched.

### Asset flows
- Deposit: client → `transferFrom` underlying into strategy → approve adapter → adapter pulls underlying, swaps on Curve, router sends vault shares back to strategy. Strategy holds shares; principal credited.
- Withdraw: strategy approves adapter for shares → adapter pulls shares, swaps → router sends underlying back to strategy → strategy transfers underlying to recipient.
- Skim/total/emergency: variations sending proceeds (or raw shares for emergency) to recipient/owner.

### Verified local properties
- `noUnboundedLoops`: **violated (bounded-by-caller)** — `_skimSurplusBatch` loops over caller-supplied `clients[]` with no max bound (LOCAL-001). All other loops are fixed (none) or in OOS parent.
- `checkedArithmetic`: **verified** (0.8.x, no `unchecked` blocks, no assembly).
- `reentrancyGuarded`: deposit, withdraw, depositAsOwner, withdrawAsOwner, skimSurplus, skimSurplusBatch, totalWithdrawal = guarded. `emergencyWithdraw` is **NOT** `nonReentrant` (parent) — only transfers shares to owner, low local risk but noted.
- `accessControlled`: setSlippageTolerance/depositAsOwner/withdrawAsOwner = onlyOwner; deposit/withdraw = onlyAuthorizedClient; skim* = onlyAuthorizedWithdrawer. Verified.
- `initializerProtected`: N/A — not upgradeable, immutables set in constructor.
- Precision/rounding: all `*(MAX_BPS-bps)/MAX_BPS` and proportional `total*principal/td` divisions floor → favor protocol (consistent with intended rounding policy). `totalBalanceOf` and `_totalWithdraw` divide by `totalDeposited` after multiply (mul-before-div, good). No div-before-mul precision-loss patterns found.

### Trust assumptions
- `vault.convertToShares/convertToAssets` are honest, monotone, non-manipulable pricing oracles used to derive `minOut` (slippage protection). If the vault price can be manipulated in the same tx as the swap, `minOut` protection degrades — **defer to interaction/econ scanner**.
- `ammAdapter.swap` returns the true received amount and the router enforces `minOut`. Local code relies on the return value for `underlyingReceived` accounting.
- Owner is trusted (emergency share extraction, depositAsOwner/withdrawAsOwner bypass pause, totalWithdrawal). Centralization is acknowledged design.
- Underlying & vault are standard ERC20 (no fee-on-transfer / rebasing). Rebasing vaults explicitly unsupported.

### Interface abstraction (for downstream)
- External entrypoints that move value: `deposit`, `withdraw`, `depositAsOwner`, `withdrawAsOwner`, `skimSurplus`, `skimSurplusBatch`, `totalWithdrawal`, `emergencyWithdraw`.
- All value-moving non-owner paths gated by `authorizedClients` / `authorizedWithdrawers` (set by owner). No anonymous public mutators except view functions.
- Untrusted external surface: the AMM adapter (delegated trust) and the ERC4626 vault pricing. No raw `call`/`delegatecall`; no native ETH handling.
- Events: `Deposited`, `Withdrawn`, `SlippageToleranceSet`, plus inherited `SurplusSkimmed`, `WithdrawalInitiated/Executed`, `EmergencyWithdraw`.

### Local findings
- **LOCAL-001 (local-medium, gas-griefing/DoS):** `_skimSurplusBatch` iterates an unbounded caller-supplied `clients[]`. Caller is `onlyAuthorizedWithdrawer` (trusted), so impact is self-inflicted gas/block-limit DoS rather than an external attack. Recommend a max-length cap. Severity deferred to classifier.
- **LOCAL-002 (local-low, config/availability):** `slippageToleranceBps` defaults to `0`. Until the owner calls `setSlippageTolerance`, every deposit/withdraw/skim computes `minOut == ideal` (0% tolerance), so any nonzero AMM price impact makes `swap` revert — strategy is non-functional until configured. Deployment-ordering concern; flag for the deploy-script / interaction review. Not a vuln per se.
- **OBSERVATION (not a finding):** `_emergencyWithdraw` lacks `nonReentrant`, but it only transfers vault shares to the trusted `owner()` and updates no internal accounting; no local reentrancy lever.
- **OBSERVATION:** `withdraw`/`_withdrawInternal` decrements principal by requested `amount` even when `sharesToSell` was capped to `availableShares` (received underlying may be less) — INTENDED per design note; surfaced only so downstream does not re-flag it.

### Complexity
LOC ~489; external/public functions ~13 (own) + inherited; external calls per value path: 3-5; immutable state vars 3 + 1 mutable config + 2 mappings.

---

## 2. CurveAMMAdapter.sol

### Purpose / role
`IAMMAdapter` implementation that routes swaps through Curve Router NG. Stores one admin-configured `Route` per ordered `(tokenIn, tokenOut)` pair (Curve route encoding is non-trivial and verified off-chain). Enforces a bidirectional-configuration invariant: a swap reverts unless BOTH directions of the pair are configured, preventing a half-wired adapter from being used by a round-trip strategy.

### State variables & invariants
| Variable | Type | Mutability | Notes |
|---|---|---|---|
| `router` | `ICurveRouterNG` immutable | ctor, non-zero | trusted Curve Router NG |
| `routes[tokenIn][tokenOut]` | mapping → `Route` | owner-set via `setRoute` | `Route{ address[11] path; uint256[5][5] swapParams; address[5] pools; bool configured; }` |

Invariants:
- INV-A: For a stored route, `path[0] == tokenIn` and the last non-zero entry of `path == tokenOut` (validated in `setRoute`).
- INV-B (bidirectional): `swap` requires both `routes[tokenIn][tokenOut].configured` AND `routes[tokenOut][tokenIn].configured` — intended.
- `configured` flag distinguishes "unset" from "all-zero" route.

### External / public functions
| Function | Visibility | Access control | State changes | External calls |
|---|---|---|---|---|
| constructor | — | sets `Ownable(_owner)` | `router` | none |
| `setRoute(tokenIn,tokenOut,path,swapParams,pools)` | external | `onlyOwner` | `routes[tokenIn][tokenOut]` | none |
| `getRoute(tokenIn,tokenOut)` | external view | none | none | none |
| `isPairFullyConfigured(a,b)` | public view | none | none | none |
| `swap(tokenIn,tokenOut,amountIn,minAmountOut)` | external | **none** (any caller) | none persistent | `IERC20(tokenIn).transferFrom(msg.sender)`, `IERC20(tokenIn).forceApprove(router)`, `router.exchange(...)`, output sent to `msg.sender` |

### Asset flows
`swap`: pull `amountIn` of `tokenIn` from `msg.sender` → `forceApprove(router, amountIn)` (reset-then-set) → `router.exchange(path, swapParams, amountIn, minAmountOut, pools, receiver=msg.sender)`. Router delivers `tokenOut` directly to the caller. Adapter is pass-through; holds no funds across calls in the happy path.

### Verified local properties
- `noUnboundedLoops`: **verified** — only loop is the fixed 11-iteration `path` scan in `setRoute`.
- `checkedArithmetic`: **verified** (no arithmetic beyond loop index; 0.8.x).
- `reentrancyGuarded`: **no guard** on `swap`, but `swap` keeps no per-call balance accounting and forwards output to caller; the trusted router is the only external callee in-line. Local reentrancy risk is low; cross-contract reentrancy (e.g. a malicious tokenIn/tokenOut with hooks) is **deferred** — though tokens are assumed standard ERC20 per scope.
- `accessControlled`: `setRoute` is `onlyOwner` (verified). `swap` is intentionally permissionless — see LOCAL-003.
- Approval hygiene: `forceApprove(router, amountIn)` resets allowance each call; no lingering approval (good).

### Trust assumptions
- Curve Router NG at the pinned address is trusted to (a) honor `minAmountOut`, (b) deliver output to `_receiver`, (c) return the true output amount. Slippage protection lives entirely in the router via `_expected = minAmountOut`.
- Owner is trusted to set CORRECT routes (right pool coin indices `i/j`, swap_type, pool_type). A wrong route is an admin-misconfiguration risk, not a code bug.
- `swap` trusts the caller to pass a sane `minAmountOut`; the adapter itself computes no slippage bound (the strategy does). A direct external caller passing `minAmountOut=0` only harms themselves.

### Local findings
- **LOCAL-003 (informational/local-low):** `swap` is permissionless (no `onlyAuthorizedClient`/owner gate). This is by design for a generic adapter (output goes to `msg.sender`, the adapter holds no user funds between calls and grants no standing approvals). An arbitrary caller can route their own tokens through configured pairs; they cannot drain the adapter or other users. Surfaced so downstream understands the adapter is an open utility, not an access-controlled vault component.
- **OBSERVATION (not a finding):** `setRoute` validates `path[0]==tokenIn` and last-non-zero==`tokenOut`, but does NOT validate `swapParams`/`pools` correctness or that the route actually transacts `tokenIn→tokenOut` on-chain. Route correctness is an off-chain/admin responsibility (acknowledged in NatSpec). Not flagged.
- **OBSERVATION:** No `payable`/ETH handling despite `router.exchange` being `payable`; adapter never forwards value, so ETH-leg routes are unsupported — consistent with ERC20-only scope.

### Interface abstraction (for downstream)
- `swap(tokenIn, tokenOut, amountIn, minAmountOut) -> amountOut`: pulls `amountIn` from caller, requires both directions configured + `amountIn>0`, output delivered to caller by router, returns router's reported `amountOut`. Reverts: route not configured / reverse not configured / `amountIn==0` / token transfer failure / router revert (incl. `minAmountOut` not met).
- Trust boundary: delegates all swap math + slippage enforcement to the trusted Curve Router NG. Downstream may treat `swap` as: "atomically converts `amountIn` tokenIn into `>= minAmountOut` tokenOut delivered to caller, or reverts."

### Complexity
LOC ~142; 1 mutating admin fn, 1 swap fn, 2 views; 1 external protocol dependency (router).

---

## 3. IAMMAdapter.sol (interface)

Single method `swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut)`. Generic AMM abstraction consumed by `ERC4626MarketYieldStrategy`. No state, no implementation. Trust contract: implementer must enforce `minAmountOut` and return the true received amount. Abstraction for downstream: the strategy treats any `IAMMAdapter` as a slippage-bounded atomic swap primitive.

## 4. ICurveRouterNG.sol (interface)

Minimal mirror of Curve Router NG's Vyper `exchange(address[11] _route, uint256[5][5] _swap_params, uint256 _amount, uint256 _expected, address[5] _pools, address _receiver) payable returns (uint256)`. Up to 5 hops; `_route` interleaves token/pool addresses padded to 11 slots. `_expected` is the slippage floor. No state; trust boundary is the pinned router address. Abstraction for downstream: external trusted multi-hop swap with output to `_receiver` and `>= _expected` guarantee.

---

## Cross-cutting summary for downstream scanners

Highest-value review targets (interaction / econ):
1. **Vault pricing as slippage oracle** — `minOut` for every swap is derived from `vault.convertToShares/convertToAssets`. If ERC4626 share price is manipulable atomically (donation/inflation, or a vault that lets price move within a tx), the `minOut` guard can be set loose and value extracted via the AMM leg. The adapter itself adds no independent bound. Investigate whether the swap and the price read can diverge.
2. **AMM slippage / sandwich on every value path** — deposit, withdraw, skim, totalWithdraw all settle through Curve. With `slippageToleranceBps` mis-set (or default 0) or set too loose, MEV/sandwich exposure varies. Confirm the bps governs real protection given step 1.
3. **Share accounting vs. AMM execution divergence** — principal is decremented by REQUESTED amount (intended) and shares-sold can be capped to held shares; over many withdrawals/skims the held-share pool vs. tracked principal can drift. Check that `totalBalanceOf` (proportional) cannot be gamed to under-report another client's principal or to over-skim aggregate surplus in `_skimSurplusBatch` (snapshot-once semantics + floored per-client shares).
4. **Permissionless adapter `swap`** — confirm no strategy ever leaves standing token approvals or transient balances in `CurveAMMAdapter` that a third-party `swap` caller could capture (happy path: none, approvals reset each call, no inter-call balance).
5. **Owner power** — `emergencyWithdraw` (raw shares to owner, no pause/guard), `depositAsOwner`/`withdrawAsOwner` (bypass pause), `totalWithdrawal` proceeds to owner. Centralization acknowledged; econ scanner should confirm two-phase `totalWithdrawal` timelock is the only rug mitigation and that emergency paths are appropriately scoped.

Local findings to carry forward (severity TBD by classifier):
- LOCAL-001: unbounded `clients[]` loop in `_skimSurplusBatch` (trusted caller; DoS-of-self) — local-medium.
- LOCAL-002: `slippageToleranceBps` default 0 → swaps revert until configured (availability) — local-low.
- LOCAL-003: permissionless `CurveAMMAdapter.swap` (by design; informational) — local-low.

Verified properties downstream may treat as axioms:
- Checked arithmetic throughout; no assembly; no `unchecked`.
- INV-1 `totalDeposited == Σ clientBalances` maintained by paired updates.
- Surplus skims never mutate principal (INV-2).
- `slippageToleranceBps <= MAX_BPS` (no underflow in `MAX_BPS - bps`).
- Bidirectional route invariant enforced before any swap (INV-B).
- Adapter `swap` resets router allowance each call (no lingering approval).
