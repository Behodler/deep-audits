# Pattern-Matcher Report — phoenix-vault (reflax-yield-vault)

- Project: phoenix-vault (maps to `lib/reflax-yield-vault`)
- Scan type: pattern-matching (historical vulnerability pattern DB)
- Patterns checked: 22
- Scan timestamp: 2026-05-25
- In-scope files:
  - `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
  - `src/AMMAdapters/CurveAMMAdapter.sol`
  - `src/AMMAdapters/IAMMAdapter.sol`
  - `src/AMMAdapters/ICurveRouterNG.sol`
  - Context: `src/AYieldStrategy.sol`, `src/interfaces/IYieldStrategy.sol`

All findings below are **potential** pattern matches for downstream manual verification (code-scanner / econ-scanner). Pattern matching surfaces candidates; it does not confirm exploitability.

---

## Findings (medium/high confidence)

### PM-01 — MISSING-SLIPPAGE / FLASH-LOAN-PRICE: minOut anchored to vault NAV, not market price
- Pattern IDs: `MISSING-SLIPPAGE` (defi, HIGH), `FLASH-LOAN-PRICE` (flash-loan, HIGH)
- Confidence: **high**
- Severity: potential-high
- Locations:
  - `ERC4626MarketYieldStrategy.sol:276-283` (deposit minOut)
  - `ERC4626MarketYieldStrategy.sol:321-328` (withdraw minOut)
  - `ERC4626MarketYieldStrategy.sol:383-390` (_totalWithdraw minOut)
  - `ERC4626MarketYieldStrategy.sol:435-442` (_skimSurplus minOut)
  - `ERC4626MarketYieldStrategy.sol:482-485` (_skimSurplusBatch minOut)
- Why it matches: Every swap computes its slippage floor from the external vault's own
  `convertToShares` / `convertToAssets` rate, then applies a fixed `slippageToleranceBps`
  haircut. `minOut` therefore tracks the vault's reported NAV, which is independent of the
  *AMM execution price*. A sandwich attacker who skews the Curve pool moves the price the
  swap actually executes at; the NAV-derived `minOut` does not reflect that skew, so the
  floor can be satisfied while the strategy still trades at a manipulated rate (classic
  spot-price-used-for-critical-decision, no TWAP). `convertToShares`/`convertToAssets` is
  effectively an oracle whose value is being compared against a manipulable venue.
- Matched signatures: `swap(`, `minOut`/`minAmountOut`, `convertToShares(`, `convertToAssets(`, `balanceOf(address(this))`
- Missing mitigations: no independent oracle/TWAP cross-check of the realized swap price; minOut floor and the price reference come from the same/related source.
- Note for triage: this is the strongest candidate. Whether it rises to HM depends on whether `slippageToleranceBps` is configured tightly and on how the vault NAV relates to the pool — hand to econ-scanner.

### PM-02 — MISSING-SLIPPAGE: default slippageToleranceBps is 0 (uninitialized) → swaps revert / unbounded if maxed
- Pattern ID: `MISSING-SLIPPAGE` (defi, HIGH); also `INCORRECT-OPERATOR` boundary check
- Confidence: **medium**
- Severity: potential-medium
- Locations: `ERC4626MarketYieldStrategy.sol:40` (state, no initializer), `:190-195` (`setSlippageTolerance`), `:277/322/384/436/483` (minOut formula)
- Why it matches: `slippageToleranceBps` has no constructor default, so it is `0` until the
  owner calls `setSlippageTolerance`. With bps = 0, `minOut == idealShares/idealUnderlying`
  (exact NAV), which will revert on any normal AMM spread/fee — a DoS until configured. At
  the other extreme `setSlippageTolerance` allows up to `MAX_BPS` (10000 = 100%), which sets
  `minOut = 0`, fully disabling slippage protection (`vulnerableWhen: amountOutMin = 0`). The
  bound check is `_bps <= MAX_BPS`, permitting the 100% (no-protection) value.
- Missing mitigations: no sane upper cap below 100%; no nonzero default.
- Note: classic missing-slippage edge once misconfigured; centralization-flavored (owner sets it).

### PM-03 — NO-DEADLINE: swaps pass no transaction deadline to Curve Router
- Pattern ID: `MISSING-SLIPPAGE` (deadline sub-condition), related MEV
- Confidence: **high**
- Severity: potential-medium
- Locations:
  - `ICurveRouterNG.sol:27-34` — `exchange(...)` interface has **no** deadline parameter
  - `CurveAMMAdapter.sol:138` — `router.exchange(r.path, r.swapParams, amountIn, minAmountOut, r.pools, msg.sender)`
  - All `ammAdapter.swap(...)` call sites in `ERC4626MarketYieldStrategy.sol`
- Why it matches: Pattern `MISSING-SLIPPAGE` flags `vulnerableWhen: No deadline parameter`.
  Neither `IAMMAdapter.swap` nor the Curve Router NG `exchange` binding accepts a deadline,
  so a pending swap tx can be held by validators/mempool and executed later at a stale price,
  bounded only by the (NAV-anchored, see PM-01) `minOut`. Combined with PM-01 this widens the
  MEV window.
- Missing mitigations: no `deadline`/`block.timestamp` check anywhere in the swap path.

### PM-04 — RETURN-VALUE / EXTERNAL-CALL-TRUST: AMM swap return value trusted, vault is fully external
- Pattern ID: `RETURN-VALUE-IGNORE` (code-quality, MEDIUM) — adapted to external-call-trust
- Confidence: **medium**
- Severity: potential-medium
- Locations:
  - `ERC4626MarketYieldStrategy.sol:283-284` deposit: `sharesReceived` used only for `> 0` check; not verified against tokens actually received by the strategy.
  - `ERC4626MarketYieldStrategy.sol:328-331` withdraw: `underlyingReceived` (the swap's return value) is the amount transferred to the recipient — but the router sends output to `msg.sender` (the strategy) and the code trusts the returned number equals the delivered balance.
  - `CurveAMMAdapter.sol:138` returns `router.exchange(...)` verbatim as `amountOut`.
- Why it matches: The strategy relies on the AMM adapter / Curve Router return value as
  ground truth for accounting and for the amount it forwards to recipients, with no
  balance-delta verification (`balanceBefore`/`balanceAfter`). If the router under-reports or
  a non-standard/fee-bearing path is used, accounting diverges. The vault (`convertTo*`,
  `balanceOf`) and the router are entirely external, untrusted-rate sources.
- Missing mitigations: no measured balance-delta around the swap; trusts external return value.
- Note: project declares fee-on-transfer / weird-ERC20 out of scope, which tempers this — but the trusted-return-value shape is real. Flag for code-scanner.

### PM-05 — DIVISION-PRECISION / ROUNDING: convertToShares→convertToAssets round-trip and floored per-client shares
- Pattern ID: `DIVISION-PRECISION` (arithmetic, MEDIUM)
- Confidence: **medium**
- Severity: potential-low
- Locations:
  - `ERC4626MarketYieldStrategy.sol:151` `(totalValue * principal) / totalDeposited[token]`
  - `ERC4626MarketYieldStrategy.sol:277/322/384/436/483` `ideal * (MAX_BPS - bps) / MAX_BPS`
  - `ERC4626MarketYieldStrategy.sol:379` `(totalShares * clientStoredBalance) / totalDeposited[token]`
  - `ERC4626MarketYieldStrategy.sol:473-476` per-client `convertToAssets`→`convertToShares` re-conversion then summed (floor each iteration)
- Why it matches: Multiple multiply-then-divide proportional calcs plus a double conversion
  (assets→shares→assets implied) where each `convertTo*` floors. The batch path
  (`_skimSurplusBatch`) sums per-client floored shares, accumulating rounding dust. The
  contract documents "all rounding favors the protocol," so this is likely intentional and
  bounded to dust — low severity, but matches the precision-loss signature.
- Missing mitigations: per-client flooring in a loop rather than a single aggregate conversion (minor precision drift, protocol-favoring).

### PM-06 — DOS-UNBOUNDED-LOOP: caller-supplied clients[] iterated in skimSurplusBatch
- Pattern ID: `DOS-UNBOUNDED-LOOP` (dos, MEDIUM)
- Confidence: **medium**
- Severity: potential-low
- Locations:
  - `ERC4626MarketYieldStrategy.sol:468-478` `for (uint256 i = 0; i < clients.length; i++)`
  - entrypoint `AYieldStrategy.sol:310-320` `skimSurplusBatch(...)`
- Why it matches: Loop bound is `clients.length`, a caller-supplied calldata array, fitting
  `for (... i < array.length`. No pagination or max-length cap.
- Why low/likely-invalid: gated by `onlyAuthorizedWithdrawer` (trusted role) and array is a
  call parameter, not unbounded protocol state — the caller controls and pays for its own
  list size. Pattern matches structurally but the access control + caller-bounded array make
  a genuine DoS implausible. Recorded for completeness; expect sanitizer/code-scanner to drop.

---

## Patterns checked and NOT matched (suppressions)

- `ERC4626-INFLATION` / `FIRST-DEPOSITOR-ATTACK`: **Not applicable.** This strategy does not
  mint its own ERC4626 shares (`shares = assets * totalSupply()/totalAssets()` signature
  absent). It tracks `clientBalances` principal in raw underlying units and buys *external*
  vault shares on an AMM. No internal share minting, no first-depositor exchange-rate seam.
  Proportional accounting `(totalValue * principal)/totalDeposited` is principal-weighted, not
  share-minting. Donation-inflation of the external vault is the external vault's concern (OOS).
- `ORACLE-STALE` / `ORACLE-ROUNDID`: no Chainlink / `latestRoundData()` / `AggregatorV3Interface` usage.
- `REENTRANCY-ERC777`: `deposit`/`withdraw`/`skim`/`totalWithdrawal` all carry `nonReentrant`
  (OZ ReentrancyGuard via `AYieldStrategy`). State updates in `_withdrawInternal` occur after
  the external swap+transfer (`clientBalances -= amount` at :335) but the guard mitigates the
  classic reentrancy; flagged here only as context, not a standalone finding.
- `SIGNATURE-REPLAY` / `PERMIT-FRONTRUN` / `CROSS-CHAIN-REPLAY`: no `ecrecover`/`permit`/
  `lzReceive`/`ccipReceive`/`block.chainid` in scope.
- `FRONTRUN-APPROVE`: adapter uses `forceApprove` (reset-then-set) and strategy uses
  `safeIncreaseAllowance`; documented known-issue/QA per project rules anyway.
- `UNPROTECTED-INIT` / `STORAGE-COLLISION`: no proxy/initializer pattern; constructors only,
  immutables for token/vault/adapter/router.
- `UNSAFE-DOWNCAST`: no `uintNN(` narrowing casts in scope.
- `SELFDESTRUCT-FORCE-ETH`: no `address(this).balance` / `msg.value` logic. Note: Curve
  `exchange` is `payable` but the adapter never forwards ETH — benign.
- `CENTRALIZATION-ADMIN`: `onlyOwner` controls routes (`setRoute`), slippage, client/withdrawer
  auth, emergency/total withdrawal. Per C4 rules this is Low/QA unless it enables a rug; the
  two-phase `totalWithdrawal` timelock (24h+48h window) is the mitigating control. Tracked as
  QA context, not an HM pattern match.
- `DOUBLE-VOTING` / `TIMELOCK-BYPASS`: no governance/voting; the only timelock
  (`totalWithdrawal`) has a single execute path with state reset before the external call.
