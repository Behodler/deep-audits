# QA Report — reflax-yield-vault (Run 11)

## Summary

| Severity | Count |
|---|---|
| Low Risk | 13 |
| QA / Info | 1 |
| **Total** | **14** |

---

## Low Risk Findings

### [L-01] CEI violation in `_withdrawInternal` — state updates occur after two external calls, latent reentrancy exposure <!-- id: ryv11l1 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L338-L375`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L338-L375)

**Description**: `_withdrawInternal` performs two external calls before updating state: `ammAdapter.swap()` (line 364) and `underlyingToken.safeTransfer(recipient, ...)` (line 367) both precede the `clientBalances` decrement (line 371) and `totalDeposited` decrement (line 372). The Checks-Effects-Interactions pattern requires state writes to precede external calls. The current `nonReentrant` modifier on all public entry points prevents immediate exploitation, but the ordering is structurally wrong and constitutes a latent vulnerability.

**Impact**: Currently non-exploitable because every public caller (`deposit`, `withdraw`, `withdrawAsOwner`, `totalWithdrawal`, `skimSurplus`) carries `nonReentrant`. Latent risk escalates to a double-withdrawal exploit if a new entry point is added without the guard, or if the vault or underlying token uses ERC-777 transfer hooks.

**Recommendation**: Move the `clientBalances` and `totalDeposited` decrements above the external calls.

```solidity
// Before external calls:
clientBalances[token][balanceHolder] -= amount;
totalDeposited[token] -= amount;

// Then:
uint256 underlyingReceived = ammAdapter.swap(...);
underlyingToken.safeTransfer(recipient, underlyingReceived);
```

---

### [L-02] `safeIncreaseAllowance` accumulates residual approvals across failed swaps <!-- id: ryv11l2 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L315-L472`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L315-L472) — `_depositInternal`, `_withdrawInternal`, `_totalWithdraw`, `_skimSurplus`

**Description**: Every AMM swap path calls `safeIncreaseAllowance` unconditionally before invoking the adapter. Because `safeIncreaseAllowance` is additive, a partial-revert scenario — where the approval is granted but the swap reverts before the adapter calls `safeTransferFrom` — leaves residual allowance in the ERC-20 slot. Subsequent swap calls stack further on top of this residual. No post-swap `forceApprove(..., 0)` reset is performed.

**Impact**: Under the current `CurveAMMAdapter` (atomic revert semantics) exploitability is near-zero. Under a future `IAMMAdapter` substitution with partial-consumption semantics, accumulated allowances could allow the adapter to pull more than the strategy currently intends for any single swap.

**Recommendation**: After each swap, reset the allowance to zero via `IERC20(token).forceApprove(address(ammAdapter), 0)`, or replace `safeIncreaseAllowance` with `forceApprove(address(ammAdapter), exactAmount)` immediately before each call.

---

### [L-03] `emergencyWithdraw` missing `nonReentrant` — inconsistent with all other state-changing entry points <!-- id: ryv11l3 -->

**Location**: [`src/AYieldStrategy.sol#L304`](src/AYieldStrategy.sol#L304)

**Description**: `AYieldStrategy.emergencyWithdraw` is decorated with `onlyOwner` but not `nonReentrant`. Every other state-changing external entry point in the contract carries `nonReentrant`. The asymmetry means that if the vault token implements ERC-777 `tokensReceived` hooks, the owner's receiver contract receives control mid-transfer with the reentrancy mutex not held.

**Impact**: Low probability for the intended sUSDe vault deployment (standard ERC-20). Escalates to a concrete double-transfer risk for any future vault integration that uses transfer callbacks.

**Recommendation**: Add `nonReentrant` to `emergencyWithdraw`:

```solidity
function emergencyWithdraw(uint256 amount) external override onlyOwner nonReentrant {
```

---

### [L-04] `nonReentrant` is not the first modifier on 6 functions — earlier modifiers execute before the reentrancy lock is acquired <!-- id: ryv11l4 -->

**Location**:
- [`src/AYieldStrategy.sol`](src/AYieldStrategy.sol) — lines 319, 366
- [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol) — lines 229, 248, 265, 279

**Description**: Solidity applies modifiers in declaration order. In the affected functions, `onlyOwner`, `whenNotPaused`, and `onlyAuthorizedClient` all appear before `nonReentrant` in the modifier list. These earlier modifiers execute — and complete — before the reentrancy mutex is set. A future modifier that makes an external call, if inserted before `nonReentrant`, would execute without the guard active.

**Impact**: No current security impact; the existing early modifiers are read-only checks with no external calls. Purely structural, but the practice sets a precedent that could become exploitable if modifier ordering is not re-evaluated when new modifiers are added.

**Recommendation**: Place `nonReentrant` first in every modifier list where it appears.

```solidity
// Current (problematic ordering):
function deposit(...) external nonReentrant onlyAuthorizedClient whenNotPaused { ... }

// Recommended:
function deposit(...) external nonReentrant onlyAuthorizedClient whenNotPaused { ... }
// (nonReentrant already first — verify all 6 sites)
```

---

### [L-05] Constructor `_owner` parameter shadows `Ownable._owner` state variable across three contracts <!-- id: ryv11l5 -->

**Location**:
- [`src/AMMAdapters/CurveAMMAdapter.sol#L48`](src/AMMAdapters/CurveAMMAdapter.sol#L48)
- [`src/AYieldStrategy.sol#L172`](src/AYieldStrategy.sol#L172) (constructor body)
- [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L97`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L97)

**Description**: All three constructors declare a local parameter named `_owner`, which shadows the inherited `Ownable._owner` state variable. The constructors immediately forward `_owner` to the `Ownable` initializer so there is no current bug. However, any future constructor logic that reads `_owner` expecting the state variable would silently read the parameter instead.

**Impact**: No current security impact. Code-quality finding to prevent future confusion during maintenance.

**Recommendation**: Rename the constructor parameter to avoid the shadow, e.g. `initialOwner` or `ownerAddress`.

```solidity
constructor(address initialOwner, ...) Ownable(initialOwner) { ... }
```

---

### [L-06] `WithdrawalExecuted` event emits the Phase-1 cached balance, not the actual transferred amount <!-- id: ryv11l6 -->

**Location**: [`src/AYieldStrategy.sol#L501`](src/AYieldStrategy.sol#L501) — `_executeWithdrawal`

**Description**: `WithdrawalExecuted` emits `withdrawAmount = state.balance`, which is the balance snapshot captured at Phase-1 initiation. `ERC4626MarketYieldStrategy._totalWithdraw` (the concrete implementation) operates on the live `clientStoredBalance` at Phase-2 execution time. When client balances grow between Phase-1 and Phase-2 (e.g. via inter-phase deposits), the event records a smaller amount than was actually transferred.

**Impact**: Off-chain monitoring systems, indexers, and accounting tools receive systematically incorrect withdrawal amounts. The misleading event also compresses the observability of the H-02 bug — observers watching `WithdrawalExecuted` cannot detect inter-phase balance enlargement from events alone.

**Recommendation**: Propagate the actual transferred amount back from the concrete `_totalWithdraw` implementation and emit it in the event, rather than the cached `state.balance`.

---

### [L-07] `withdrawAsOwner` debits a client's principal but the emitted event omits the client field <!-- id: ryv11l7 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L279`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L279) — `withdrawAsOwner`

**Description**: `withdrawAsOwner(client, recipient, amount)` debits `clientBalances[token][client]` and routes underlying tokens to `recipient`. The emitted `Withdrawn` event records `msg.sender` (the owner) and `recipient` but does not include `client` as a field. In a multi-client deployment, automated monitoring cannot determine which client's balance was debited without additional storage reads.

**Impact**: A forced extraction from a client leaves that client's balance inconsistently reduced with no on-chain event signal identifying the debited account. Compliance and off-chain reconciliation are impaired.

**Recommendation**: Add `client` as an indexed field to the `Withdrawn` event, or emit a dedicated `WithdrawnAsOwner(address indexed client, address indexed recipient, uint256 amount)` event.

```solidity
event WithdrawnAsOwner(address indexed client, address indexed recipient, uint256 amount);

emit WithdrawnAsOwner(client, recipient, amount);
```

---

### [L-08] `Ownable` used instead of `Ownable2Step` — ownership transfer is irreversible if the new address is incorrect <!-- id: ryv11l8 -->

**Location**:
- [`src/AMMAdapters/CurveAMMAdapter.sol#L20`](src/AMMAdapters/CurveAMMAdapter.sol#L20)
- [`src/AYieldStrategy.sol#L20`](src/AYieldStrategy.sol#L20)

**Description**: Both contracts import OpenZeppelin `Ownable` rather than `Ownable2Step`. A single-step ownership transfer via `transferOwnership(newOwner)` takes effect immediately. If `newOwner` is a mistyped address, a contract lacking the expected interface, or a compromised address, the transfer cannot be reversed and all `onlyOwner` functions become permanently inaccessible or under adversarial control.

**Impact**: Low severity operational risk. Not an active exploit but a one-time human error can permanently brick privileged functions or hand them to an attacker.

**Recommendation**: Replace `Ownable` with `Ownable2Step` from OpenZeppelin. The two-step pattern requires the new owner to accept the transfer, preventing accidental loss.

```solidity
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract AYieldStrategy is Ownable2Step, ... { ... }
```

---

### [L-09] Dual `convertToAssets` calls in `_skimSurplus` — intra-transaction rate drift can produce a spurious revert <!-- id: ryv11l9 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L449-L487`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L449-L487) — `_skimSurplus`

**Description**: `_skimSurplus` calls `vault.convertToAssets` twice within the same transaction: once near the top to snapshot `totalValue` (line 457) and again near the bottom to compute the swap `minOut` floor from `totalShares` (line 472). For ERC-4626 vaults that update their exchange rate mid-transaction (e.g. via an accrual trigger), the second call can return a higher rate than the first. When that happens, `minOut` exceeds the actual swap output and the transaction reverts.

**Impact**: Temporary denial-of-service on `skimSurplus` — no fund loss; a retry on the next block succeeds. Narrow sub-case of the M-02 vault oracle risk.

**Recommendation**: Cache the `convertToAssets` result from the first call and reuse it for the `minOut` calculation, eliminating the intra-transaction rate divergence.

```solidity
uint256 rateSnapshot = vault.convertToAssets(1e18); // single snapshot
uint256 totalValue = (rateSnapshot * vault.balanceOf(address(this))) / 1e18;
// ...
uint256 idealUnderlying = (rateSnapshot * totalShares) / 1e18;
```

---

### [L-10] `setRoute` weak input validation — degenerate all-zero path arrays may pass without registering a usable route <!-- id: ryv11l10 -->

**Location**: [`src/AMMAdapters/CurveAMMAdapter.sol#L74`](src/AMMAdapters/CurveAMMAdapter.sol#L74) — `setRoute`

**Description**: The local variable `lastToken` in `setRoute` is only assigned inside the loop body when a non-zero path entry is encountered. An all-zero 11-slot `path` array would leave `lastToken` as `address(0)`. The existing `require(lastToken == tokenOut)` then reverts because `tokenOut != address(0)`, so no route is stored. While the final guard is effective, there is no explicit validation that at least one non-zero path segment was provided, leaving the input validation to an implicit downstream revert rather than an intentional guard.

**Impact**: No practical impact: the implicit revert prevents a degenerate route from being registered. Defense-in-depth concern only.

**Recommendation**: Add an explicit check after the loop:

```solidity
require(lastToken != address(0), "CurveAMMAdapter: empty path");
require(lastToken == tokenOut, "CurveAMMAdapter: path must end at tokenOut");
```

---

### [L-11] `totalBalanceOf` and `principalOf` use different data sources — vault price decline produces negative implied yield for integrators <!-- id: ryv11l11 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L129-L156`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L129-L156) — `totalBalanceOf` / `principalOf`

**Description**: `totalBalanceOf` derives a value from the live vault price (`vault.convertToAssets`), making it sensitive to vault exchange-rate movements. `principalOf` returns the static `clientBalances` accounting value. After a vault price decline, `totalBalanceOf(client) < principalOf(client)`. Any integrating contract that treats `totalBalanceOf - principalOf` as a yield signal receives a negative (underflowing in unchecked arithmetic) or misleading result.

**Impact**: No fund loss within the strategy itself. Elevated risk for downstream protocols that assume `totalBalanceOf >= principalOf` as a protocol invariant. Arithmetic underflow or incorrect branching is possible in integrating contracts.

**Recommendation**: Document the asymmetry explicitly in NatDoc. Consider providing a `yieldOf(client)` view that internally handles the `totalBalanceOf < principalOf` case and returns zero rather than a negative value.

```solidity
/// @notice Returns accrued yield; returns 0 if vault value has declined below principal.
function yieldOf(address token, address client) external view returns (uint256) {
    uint256 total = totalBalanceOf(token, client);
    uint256 principal = principalOf(token, client);
    return total > principal ? total - principal : 0;
}
```

---

### [L-12] `CurveAMMAdapter.swap` does not independently verify `amountOut >= minAmountOut` after the router returns <!-- id: ryv11l12 -->

**Location**: [`src/AMMAdapters/CurveAMMAdapter.sol#L120-L141`](src/AMMAdapters/CurveAMMAdapter.sol#L120-L141) — `swap`

**Description**: After `router.exchange` returns `amountOut`, the adapter does not perform a `require(amountOut >= minAmountOut)` check. Slippage floor enforcement is delegated entirely to the Curve Router NG's internal `_min_dy` mechanism. A future redeployment pointing at a misconfigured, buggy, or upgraded router address could return a below-floor value and the adapter would silently accept it, propagating it back to the strategy.

**Impact**: Low in practice: the router is immutable and battle-tested. Risk materialises only under incorrect router configuration on future redeployments.

**Recommendation**: Add a post-exchange sanity check:

```solidity
uint256 amountOut = router.exchange(...);
require(amountOut >= minAmountOut, "CurveAMMAdapter: insufficient output");
return amountOut;
```

---

### [L-13] `slippageToleranceBps` zero-default makes withdrawals revert until configured <!-- id: ryv11l13 -->

**Location**:
- [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L357-L358`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L357-L358) — `_withdrawInternal`
- [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L419-L420`](src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L419-L420) — `_totalWithdraw`

**Description**: `slippageToleranceBps` is not initialised in the constructor, so it defaults to `0`. In both `_withdrawInternal` (L357-358) and `_totalWithdraw` (L419-420), the slippage floor is computed as `minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS`. With `slippageToleranceBps == 0` this reduces to `minOut = idealUnderlying * (MAX_BPS - 0) / MAX_BPS = idealUnderlying` — the swap is required to return 100% of the vault's ideal rate. Any real Curve pool discount makes the AMM swap return slightly less than ideal, so the swap reverts and the withdrawal fails.

**Impact**: A freshly deployed strategy that has already accepted deposits cannot process withdrawals until the owner calls `setSlippageTolerance` with a non-zero value. This is a deploy-ordering footgun, not an attack — the owner sets the parameter once and withdrawals function normally thereafter. No fund loss.

**Recommendation**: Require a non-zero `_initialSlippageBps` in the constructor, or guard `_withdrawInternal` and `_totalWithdraw` to require `slippageToleranceBps > 0` before computing `minOut`.

```solidity
// Option A — enforce at construction:
require(_initialSlippageBps > 0, "ERC4626MarketYieldStrategy: zero slippage tolerance");
slippageToleranceBps = _initialSlippageBps;

// Option B — guard at withdrawal:
require(slippageToleranceBps > 0, "ERC4626MarketYieldStrategy: slippage tolerance not set");
```

**Note**: This was originally raised at Medium (M-01) combined with the `MAX_BPS` owner-config trap. On review, the `MAX_BPS` half moved to the C-01 centralization report and this deploy-ordering half is the residual Low.

---

## QA / Info Findings

### [QA-01] `abi.encodePacked` in revert message — false-positive automated tool warning, no hash collision surface <!-- id: ryv11qa1 -->

**Location**: [`src/AYieldStrategy.sol#L340`](src/AYieldStrategy.sol#L340)

**Description**: The `keccak256(abi.encodePacked(...))` at line 340 constructs a human-readable revert message string by concatenating a literal text prefix with a timestamp converted to a decimal string. The standard Slither/Aderyn warning about `abi.encodePacked` with dynamic arguments concerns cases where the hash result is used for access control, entity identity, or state gating. Here the output is passed directly to `revert()` as a display string and is never stored or compared. Two different timestamps that happen to produce the same packed encoding would affect only the human-readable error text, not any state or access control logic.

**Impact**: None. This is a false-positive from automated scanners. No hash collision attack surface exists.

**Recommendation**: No code change required. If the automated tool warning is a CI concern, the pattern can be refactored to use `string.concat` for clarity:

```solidity
revert(string.concat("AYieldStrategy: withdrawal not executable until ", _uint256ToString(executableAt)));
```

---

## Appendix — Automated SAST Report (4naly3er)

> Generated by [4naly3er](https://github.com/Picodes/4naly3er) against the in-scope contracts:
> - `src/AYieldStrategy.sol`
> - `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
> - `src/AMMAdapters/CurveAMMAdapter.sol`
>
> Full machine-generated output: [`4naly3er-report.md`](4naly3er-report.md)

The automated scan produced no Low or NC findings that are not already covered by the manual findings above. The following gas optimization categories were identified:

| ID | Issue | Instances |
|---|---|---|
| GAS-1 | `a = a + b` more gas-efficient than `a += b` for state variables | 5 |
| GAS-2 | Use assembly to check for `address(0)` | 18 |
| GAS-3 | `bool` storage incurs overhead; use `uint256(1)`/`uint256(2)` | 1 |
| GAS-4 | Cache array length outside loops | 2 |
| GAS-5 | Cache state variables read multiple times within a function | 4 |
| GAS-6 | Use `unchecked` for operations that cannot overflow | 70 |
| GAS-7 | Use custom errors instead of revert strings | 41 |
| GAS-8 | Avoid contract existence checks with low-level calls (pre-0.8.10) | 7 |
| GAS-9 | Stack variable cached for a state variable used only once | 2 |
| GAS-10 | State variables set only in constructor should be `immutable` | 4 |
| GAS-11 | `onlyOwner` / restricted functions can be marked `payable` | 9 |
| GAS-12 | Use `++i` / `--i` instead of post-increment/decrement | 4 |
| GAS-13 | `private` constants save gas vs `public` | 4 |
| GAS-14 | `this.fn()` call; mark function `public` instead | 2 |
| GAS-15 | Loop increments can be `unchecked` | 3 |
| GAS-16 | Use `!= 0` instead of `> 0` for unsigned integers | 10 |

The most actionable gas item for this codebase is **GAS-7** (41 revert strings → custom errors), which would also reduce deployment cost meaningfully at 41 instances. **GAS-10** (4 constructor-only state variables should be `immutable`) is similarly high-value. These are optimization recommendations only; none represent security vulnerabilities.
