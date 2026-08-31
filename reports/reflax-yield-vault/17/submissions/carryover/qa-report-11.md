> **Carryover QA report — audit 11** (cut down from `reports/reflax-yield-vault/11/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 17): **L-01, L-02, L-03, L-04, L-05, L-06, L-07, L-08, L-09, L-11, L-12, QA-01**.
> Removed as no longer live / carried elsewhere: L-10 (ledger `L-10` / `90f3fa166e20ff25` — **false-positive**); L-13 of run-11 (`slippageToleranceBps` zero-default) — **never a distinct ledger entry**, folded into `L-01` / `6460e35331dff5c2`, which owns the default-0 leg.
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping** (originating report label → ledger entry):
> - `L-01` → ledger `L-01-run11` / `3ab43381ffaf861f`
> - `L-02` → ledger `L-02-run11` / `f880bc2ef5c2d789`
> - `L-03` → ledger `L-03-run11` / `c97b6a933c8e79ed`
> - `L-04` → ledger `L-04-run11` / `46ab675c76e9f7d7`
> - `L-05` → ledger `L-05-run11` / `adc461fade9f71ab`
> - `L-06` → ledger `L-06-run11` / `f9194462b90747b5`
> - `L-07` → ledger `L-07-run11` / `1177778f2c874782`
> - `L-08` → ledger `L-08` / `207c375222eaaafb`
> - `L-09` → ledger `L-09` / `c6ec246f7e58dd29`
> - `L-11` → ledger `L-11` / `abd28a2f46c12893`
> - `L-12` → ledger `L-12` / `6e771a84e82df3c1`
> - `QA-01` → ledger `QA-01` / `4e98bf1620203701`

*The text below is a verbatim copy of the retained sections of the original report.*

---

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

### [QA-01] `abi.encodePacked` in revert message — false-positive automated tool warning, no hash collision surface <!-- id: ryv11qa1 -->

**Location**: [`src/AYieldStrategy.sol#L340`](src/AYieldStrategy.sol#L340)

**Description**: The `keccak256(abi.encodePacked(...))` at line 340 constructs a human-readable revert message string by concatenating a literal text prefix with a timestamp converted to a decimal string. The standard Slither/Aderyn warning about `abi.encodePacked` with dynamic arguments concerns cases where the hash result is used for access control, entity identity, or state gating. Here the output is passed directly to `revert()` as a display string and is never stored or compared. Two different timestamps that happen to produce the same packed encoding would affect only the human-readable error text, not any state or access control logic.

**Impact**: None. This is a false-positive from automated scanners. No hash collision attack surface exists.

**Recommendation**: No code change required. If the automated tool warning is a CI concern, the pattern can be refactored to use `string.concat` for clarity:

```solidity
revert(string.concat("AYieldStrategy: withdrawal not executable until ", _uint256ToString(executableAt)));
```

---
