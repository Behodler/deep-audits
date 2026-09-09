# Contract Profiles — reflax-yield-vault @ `cdd0743` (run 17)

Commit under audit: `cdd0743` `[story-050] GREEN: previewExitFor on IYieldStrategy, base default + market override`
Baseline: `0110ce4` `[story-049] YS-01: credit principal via convertToAssets (Autopool STATICCALL fix)`
Intermediate: `a438ce0` `[story-050] RED: exit-preview tests for IYieldStrategy.previewExitFor`

Diff shape: **506 insertions / 13 deletions across 7 files. 336 of the added lines are tests.** Source-side, story-050 adds exactly three things: an interface declaration (`IYieldStrategy.previewExitFor`, ~50 lines of which ~44 are NatSpec), a base default implementation in `AYieldStrategy` (11 lines of code), and a market override + `_exitFloor` helper in `ERC4626MarketYieldStrategy` (~30 lines of code). The `ERC4626YieldStrategy.sol` (+5/-3) and `ERC4626MarketYieldStrategy.sol` `require(...)` reflows are **`forge fmt` only — zero behavioural change**; likewise the whole `test/VaultWithdrawer.t.sol` diff (+12/-8) is `forge fmt` line-wrapping of two `assertApproxEqAbs` and one `assertGt` call. Treat `VaultWithdrawer.t.sol` as unchanged.

---

## 1. `src/interfaces/IYieldStrategy.sol` (CHANGED, +50, NEW IN SCOPE)

**Type:** pure interface. No state, no logic, no access control.

### The added declaration — exact signature for cross-repo consumers

```solidity
function previewExitFor(address token, address account, uint256 netWanted)
    external
    view
    returns (uint256 grossToRequest, uint256 netGuaranteed);
```

- **Selector:** `previewExitFor(address,address,uint256)`
- **Units:** all three of `netWanted`, `grossToRequest`, `netGuaranteed` are denominated in **underlying-token base units** (`underlyingToken.decimals()`), *not* vault shares and *not* a normalised 18-dec figure. No decimal conversion happens anywhere in the implementation; a 6-decimal underlying (USDC) and an 18-decimal underlying (DOLA/BOLD) both pass through unscaled. A cross-repo consumer must supply `netWanted` in the strategy's own underlying decimals.
- **`token`** must equal `address(underlyingToken)` or the call **reverts** with the string `"AYieldStrategy: only underlying token supported"` — in **both** implementations (the market override reuses the base's `AYieldStrategy:` prefix even though it lives in `ERC4626MarketYieldStrategy`).
- **`account`** is the *balance holder* whose `clientBalances[token][account]` is debited — i.e. the client contract in the `withdraw()` path (where `recipient == balanceHolder`) or the `client` argument in `withdrawAsOwner(client, recipient, amount)`. It is **not** the end user.
- **Statefulness:** `view`, and genuinely STATICCALL-safe by construction (both impls touch only `convertToShares` / `convertToAssets` / `balanceOf`, never `previewRedeem`/`previewWithdraw` — the story-049 Tokemak-Autopool `StateChangeDuringStaticCall` trap). Pinned by two tests.

### Interface-level trust boundary note (ABI drift)

`previewExitFor` is a **new member of `IYieldStrategy`**, which is a *breaking* change for any contract in the wider tree that `is IYieldStrategy` without inheriting `AYieldStrategy` (mocks, alternative strategies, test doubles). A grep across the whole `lib/` tree at top-level HEADs finds **zero** occurrences of `previewExitFor` outside this repo — every sibling copy of `IYieldStrategy.sol` (`stable-staker`, `stable-yield-accumulator`, `phlimbo-ea`, `antimatter`, `phoenix-phase-2-staging`, and their nested pins) predates story-050 and lacks the function. Consequence: **as of `cdd0743` this API has no consumer, in this repo or any sibling.** It is a forward-declared surface.

---

## 2. `src/AYieldStrategy.sol` (CHANGED, +33, NEW IN SCOPE)

**Type:** `abstract contract AYieldStrategy is IYieldStrategy, IPausable, Ownable, ReentrancyGuard, Pausable`
**Inheritance chain:** `Ownable`, `ReentrancyGuard`, `Pausable`, `IPausable`, `IYieldStrategy`. Solidity `^0.8.13` (checked arithmetic throughout; no `unchecked` blocks, no assembly).
**Concrete descendants in this repo:** exactly two — `ERC4626YieldStrategy`, `ERC4626MarketYieldStrategy`.

### State variables and the invariants they imply

| Variable | Type | Visibility | Mutators | Invariant implied |
|---|---|---|---|---|
| `_pauser` | `address` | private | `setPauser` (onlyOwner) | sole `pause()` authority; `unpause()` also allows `owner()` |
| `_authorizedClients` | `EnumerableSet.AddressSet` | private | `setClient` (onlyOwner) | **distinctness guaranteed** — this is the structural fix for prior M-01 (duplicate-driven over-skim). `skimSurplus` reads `.values()` itself; no caller-supplied list. |
| `authorizedWithdrawers` | `mapping(address=>bool)` | public | `setWithdrawer` (onlyOwner) | gate on `skimSurplus` |
| `underlyingToken` | `IERC20` | public immutable | ctor only | **single-token strategy.** Every accounting path `require`s `token == address(underlyingToken)`, so the outer `token` key of `clientBalances` is effectively a constant. |
| `clientBalances[token][account]` | nested mapping | internal | `_depositInternal` (+), `_withdrawInternal` (−), `_relinquishInternal` (−), `_totalWithdraw` (→0) | booked **principal**, not value |
| `totalDeposited[token]` | mapping | internal | same four | **`totalDeposited[token] == Σ clientBalances[token][*]`** — preserved by every mutator (each writes both sides by the same delta). Verified: no path writes one without the other. |
| `setAsideBufferSize[client]` | mapping | public | `setSetAsideBuffer` (onlyOwner, `<=100`) | percent, 0–100 |
| `setAsideBufferRecipient` | `address` | public | `setSetAsideBufferRecipient` (onlyOwner, non-zero) | must be set before any skim with `totalBufferShares > 0`, else loud revert |
| `withdrawalStates[token][client]` | mapping→struct | public | `totalWithdrawal` two-phase | `WAITING_PERIOD = 6h`, `EXECUTION_WINDOW = 72h`, `TOTAL_DURATION = 78h` |

**Solvency invariant is NOT enforced on-chain.** Nothing requires `_positionValue() >= totalDeposited[token]`. The position may sit below par (vault loss, AMM depeg) and every accounting read still reports full principal. This matters for §5 below.

### External/public function inventory with access control

| Function | Access | Mutates | External calls | Reentrancy | Pausable |
|---|---|---|---|---|---|
| `deposit(token,amount,recipient)` | `onlyAuthorizedClient` | clientBalances, totalDeposited | via `_acquireShares` | `nonReentrant` | `whenNotPaused` |
| `withdraw(token,amount,recipient)` | `onlyAuthorizedClient` | clientBalances, totalDeposited | via `_disposeShares` | `nonReentrant` | `whenNotPaused` |
| `depositAsOwner(token,amount,client)` | `onlyOwner` | same | same | `nonReentrant` | **no** `whenNotPaused` (deliberate) |
| `withdrawAsOwner(client,recipient,amount)` | `onlyOwner` | same | same | `nonReentrant` | **no** `whenNotPaused` (deliberate) |
| `relinquishPrincipal(token,amount)` | `onlyAuthorizedClient` | clientBalances, totalDeposited | **none** (pure write-down) | `nonReentrant` | no |
| `relinquishPrincipalAsOwner(client,amount)` | `onlyOwner` | same | none | `nonReentrant` | no |
| `skimSurplus(token,recipient)` | `onlyAuthorizedWithdrawer` | none (principal untouched) | vault + AMM via `_skimSurplus` | `nonReentrant` | `whenNotPaused` |
| `emergencyWithdraw(amount)` | `onlyOwner` | (concrete) | vault/share transfer | **no guard** | no |
| `totalWithdrawal(token,client)` | `onlyOwner` | withdrawalStates, then clientBalances→0 | vault/AMM | `nonReentrant` | `whenNotPaused` |
| `setClient` / `setWithdrawer` / `setPauser` / `setSetAsideBuffer` / `setSetAsideBufferRecipient` | `onlyOwner` | config | none | — | — |
| `pause()` | `onlyPauser` | paused | — | — | — |
| `unpause()` | owner **or** pauser | paused | — | — | — |
| `principalOf` / `totalBalanceOf` / `balanceOf` / `getTotalDeposited` / `getTotalShares` / `underlying` / `authorizedClients` / `getAuthorizedClients` / `authorizedClientCount` / `pauser` | none (view) | — | `_positionValue()` (vault) for `totalBalanceOf` | — | — |
| **`previewExitFor` (NEW)** | **none (view, `virtual`)** | — | **none** (reads storage only) | — | — |

### THE STORY-050 SURFACE — base default implementation (verbatim, `src/AYieldStrategy.sol:571-583`)

```solidity
function previewExitFor(address token, address account, uint256 netWanted)
    external
    view
    virtual
    override
    returns (uint256 grossToRequest, uint256 netGuaranteed)
{
    require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

    uint256 availablePrincipal = clientBalances[token][account];
    grossToRequest = netWanted > availablePrincipal ? availablePrincipal : netWanted;
    netGuaranteed = grossToRequest;
}
```

**What it returns for a non-overriding strategy (i.e. `ERC4626YieldStrategy`, which deliberately does not override):** the **capped identity**. `grossToRequest = min(netWanted, clientBalances[token][account])`, and `netGuaranteed` is set *equal to it*. It reads **only** `clientBalances`. It makes **no call to the vault at all** — not `convertToShares`, not `convertToAssets`, not `balanceOf`.

**Is that optimistic, conservative, or a revert? — OPTIMISTIC, and unconditionally so.** It asserts that a direct strategy delivers principal 1:1 on exit. It cannot know that, because it never looks at the position. Three independent ways the real exit under-delivers relative to this "guarantee":

1. **The share-balance cap is not replicated.** `ERC4626YieldStrategy._disposeShares` does
   ```solidity
   uint256 sharesToRedeem = vault.convertToShares(amount);
   uint256 availableShares = vault.balanceOf(address(this));
   if (sharesToRedeem > availableShares) sharesToRedeem = availableShares;   // <-- cap
   vault.redeem(sharesToRedeem, recipient, address(this));
   ```
   When the position is **below par** (`convertToAssets(heldShares) < totalDeposited`), `convertToShares(principal) > heldShares` and this cap binds — the caller receives the value of the shares actually held, materially less than `amount`. The base default has **no equivalent cap** and still quotes `netGuaranteed = principal`. Note that the market override *does* replicate this cap (via `_exitFloor`) and the market test-suite *explicitly* pins the case (`testPreviewExitForShareBalanceCapBinds`, asserting `netGuaranteed < principal` after `simulateLoss`). The direct strategy has neither the cap nor the test. **This is the sharpest asymmetry in the change.**
2. **`convertToShares` rounds down.** Even at par, `redeem(convertToShares(amount))` returns `<= amount`, generically 1 wei short (and more on a high-share-price vault with a low-decimal underlying).
3. **Exit / withdrawal fees.** `redeem` delivers `previewRedeem(shares)`, which on a fee-charging ERC4626 is strictly below `convertToAssets(shares)`. The base default never even reaches `convertToAssets`, so it is *more* fee-blind than the market override, whose NatSpec at least documents the over-quote.

**No revert path** other than the wrong-token `require`. `(0, 0)` is returned for an unknown account, a zero-principal account, and `netWanted == 0` alike — the three are indistinguishable to the caller, and `grossToRequest == 0` fed back into `withdraw()` reverts with `"AYieldStrategy: amount must be greater than zero"`.

### Verified local properties — `AYieldStrategy`

| Property | Status |
|---|---|
| Checked arithmetic (0.8.13, no `unchecked`, no assembly) | **verified** |
| No unbounded loops on user-controlled input | **verified** for the changed surface; `skimSurplus`/`_accrueSurplusShares` iterate the **owner-controlled** `_authorizedClients` set (bounded by owner policy, not by an attacker) — pre-existing, unchanged |
| `previewExitFor` is side-effect free / STATICCALL-safe | **verified** (storage reads only) |
| `previewExitFor` has no access control | **verified** — by design; discloses another account's booked principal, which `principalOf` already discloses publicly. No new information leak. |
| `totalDeposited == Σ clientBalances` | **verified** across all four mutators |
| Reentrancy guards on all value-moving entry points | **verified** except `emergencyWithdraw` (onlyOwner, pre-existing) |
| Initializer protection | **n/a** — not upgradeable, constructor-only |
| Weak randomness | **verified absent** |
| `previewExitFor` overridability | base is `virtual`; **`ERC4626MarketYieldStrategy`'s override is `override` WITHOUT `virtual`** — the market preview is sealed against any future subclass. QA-grade observation. |

---

## 3. `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (CHANGED, +83)

**Type:** `contract ERC4626MarketYieldStrategy is AYieldStrategy`. Buys/sells the ERC4626 *share token* on an AMM instead of using `deposit`/`redeem` — for vaults with exit restrictions (sUSDe 7-day cooldown etc.).

### Additional state

| Variable | Type | Mutator | Notes |
|---|---|---|---|
| `vault` | `IERC4626` immutable | ctor | share token traded on the AMM |
| `ammAdapter` | `IAMMAdapter` immutable | ctor | |
| `slippageToleranceBps` | `uint256` public | `setSlippageTolerance` (onlyOwner, `<= MAX_BPS`) | **`MAX_BPS` (10000) is an accepted value** |
| `MAX_BPS` | `uint256` constant = 10000 | — | |

**Unit assumption:** the strategy treats `vault.convertToShares(underlyingAmount)` and `vault.convertToAssets(shareAmount)` as the only decimal bridge, and passes share amounts straight to `ammAdapter.swap` as `amountIn`. It therefore assumes the ERC4626 vault's `asset()` **is** `underlyingToken` and that the AMM route is `underlyingToken <-> address(vault)`. Nothing on-chain checks `vault.asset() == underlyingToken` — a constructor-time footgun (pre-existing).

### THE STORY-050 SURFACE — market override (verbatim, `:162-186`) + helper (`:129-137`)

```solidity
function _exitFloor(uint256 amount) internal view returns (uint256) {
    uint256 sharesToSell = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));
    if (sharesToSell > availableShares) {
        sharesToSell = availableShares;
    }
    uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
    return idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
}

function previewExitFor(address token, address account, uint256 netWanted)
    external view override returns (uint256 grossToRequest, uint256 netGuaranteed)
{
    require(token == address(underlyingToken), "AYieldStrategy: only underlying token supported");

    uint256 denominator = MAX_BPS - slippageToleranceBps;
    if (denominator == 0) {
        // 100% slippage tolerance: minOut is always 0, so no request carries any guarantee.
        return (0, 0);
    }

    grossToRequest = Math.ceilDiv(netWanted * MAX_BPS, denominator);

    uint256 availablePrincipal = clientBalances[token][account];
    if (grossToRequest > availablePrincipal) {
        grossToRequest = availablePrincipal;
    }

    netGuaranteed = _exitFloor(grossToRequest);
}
```

### Does the market preview model the same path the real exit takes?

Compare `_exitFloor` against the real exit, `_disposeShares` (`:238-257`):

```solidity
function _disposeShares(uint256 amount, address recipient) internal override returns (uint256 sharesDisposed) {
    uint256 sharesToSell = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));
    if (sharesToSell > availableShares) { sharesToSell = availableShares; }
    uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
    uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;   // == _exitFloor(amount)
    IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);
    uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);
    underlyingToken.safeTransfer(recipient, underlyingReceived);
    sharesDisposed = sharesToSell;
}
```

**`_exitFloor(amount)` is an exact, line-for-line replica of `_disposeShares`'s `minOut` computation.** That much is faithful — the quote and the swap floor cannot drift. But *`minOut` is not the exit*. The preview models:

- ✅ the ERC4626 leg's **share round-trip** (`convertToShares` → cap → `convertToAssets`)
- ✅ the strategy's own **global share-balance cap**
- ✅ the **bps haircut** that becomes `minOut`
- ✅ the base's **per-account principal cap**
- ❌ the **Curve AMM leg itself.** `_exitFloor` never calls the adapter, never reads a pool, never reads a reserve. `IAMMAdapter` exposes **no quote view at all** (`swap` is the only member, and it is non-view). So the AMM's actual price, depth, pool fee and the Curve Router's own multi-hop losses are entirely outside the model. The preview is *"whatever the AMM does, I will refuse below this line"* — a **refusal threshold**, not a delivery estimate.
- ❌ **ERC4626 exit/withdraw fees**, by deliberate design (`convertToAssets` is the fee-free ideal conversion; `previewRedeem` is banned by story-049's Autopool STATICCALL constraint). On a fee-charging vault the floor over-quotes — the NatSpec admits this in terms.
- ❌ **the failure mode.** If the AMM's real rate for `vault → underlying` is worse than `(MAX_BPS - bps)/MAX_BPS` of NAV, `_disposeShares` does not under-deliver — **`ammAdapter.swap` reverts on `minOut` and the whole `withdraw` reverts.** The preview returns a perfectly healthy `netGuaranteed` in exactly that state, because it never looked at the AMM. A consumer reading the preview as a liquidity/health signal gets a false green immediately before a brick.

### Round-trip algebra

With `d = MAX_BPS - bps`, `gross = ceil(net * 10000 / d)`, and (uncapped, fee-free) `_exitFloor(gross) = floor(convertToAssets(convertToShares(gross)) * d / 10000)`.
The `ceilDiv` supplies at most **one unit** of slack against the final floor division. But the share round-trip `convertToAssets(convertToShares(x))` **also floors twice** and can lose up to roughly one share-price worth of underlying. When share price ≫ 1 underlying unit (an appreciated vault, or a 6-decimal underlying against an 18-decimal share), that loss exceeds the ceil slack and **`netGuaranteed < netWanted` with no cap binding**. Every test asserting `assertGe(netGuaranteed, netWanted)` runs against a 1:1 mock vault, so this is **not pinned**.

### External calls / trust boundaries (market)

| Target | Methods | Trust | Notes |
|---|---|---|---|
| `vault` (IERC4626, immutable) | `convertToShares`, `convertToAssets`, `balanceOf`, `transfer`/`approve` (as ERC20) | **semi-trusted** | assumed non-rebasing, monotonically non-decreasing share price, `asset() == underlyingToken` (unchecked). Story-049: `previewRedeem`/`previewWithdraw` are **forbidden** on all read paths (Tokemak Autopool `StateChangeDuringStaticCall`). `convertToAssets`/`convertToShares` assumed pure/static-safe — this is the *only* thing standing between `previewExitFor` and a non-view revert. |
| `ammAdapter` (IAMMAdapter, immutable) | `swap` only | **semi-trusted** (owner-deployed) | non-`view`; **exposes no quote function**, which is the structural reason `netGuaranteed` cannot be an expectation |
| `underlyingToken` | `safeTransfer`, `safeTransferFrom`, `safeIncreaseAllowance` | **semi-trusted** | standard ERC20 assumed; fee-on-transfer explicitly out of scope per C4 known-invalids |
| `setAsideBufferRecipient`, `recipient`, `owner()` | token receipt | untrusted addresses, but no callback surface (plain ERC20 transfers, no hooks) | |

**Inbound-callback surface:** none. No `_safeMint`, no ERC721/1155 receive hooks, no ERC777 in any path.

---

## 4. `src/concreteYieldStrategies/ERC4626YieldStrategy.sol` (CHANGED, +5/-3 — `forge fmt` ONLY)

**Type:** `contract ERC4626YieldStrategy is AYieldStrategy`. Direct `vault.deposit` / `vault.redeem`; shares held by the strategy; unlimited constructor-time approval of the vault over the underlying.

**No source-behaviour change in this run.** Its relevance to story-050 is that it **inherits the base default `previewExitFor` unchanged** — a deliberate decision documented in its test file:

> `// ERC4626YieldStrategy deliberately supplies NO override of previewExitFor: its _disposeShares`
> `// applies no bps haircut and no minOut, so AYieldStrategy's capped-identity default is already`
> `// the correct answer.`

The claim "already the correct answer" holds only for a par-or-better, fee-free, non-rounding vault. See §2 for the three ways it does not. This is the strategy wired (per run-16) to **Tokemak `autoDOLA` / `autoUSD`** — precisely the fee-and-rounding-bearing, Autopool-style vault the story-049 workaround exists for.

### Additional state / functions

| Item | Notes |
|---|---|
| `vault` (`IERC4626` immutable) | ctor; ctor also does `approve(vault, type(uint256).max)` on the underlying |
| `previewDeposit(uint256)` / `previewRedeem(uint256)` | thin public passthroughs to the vault. **`previewRedeem` here is a STATICCALL-hostile wrapper on an Autopool vault** — and `previewExitFor` correctly does not use it. A consumer that reaches for `strategy.previewRedeem` instead of `previewExitFor` re-enters exactly the story-049 trap. |
| `_acquireShares` | credits `convertToAssets(sharesReceived)` — the story-049 fix, conservative |
| `_disposeShares` | `convertToShares` → global share cap → `vault.redeem(shares, recipient, this)`. **No `minOut`, no revert on shortfall.** Under-delivery is silent. |
| `_emergencyWithdraw`, `_totalWithdraw`, `_skimSurplus`, `_accrueSurplusShares`, `_distributeBuffer` | unchanged; mirror the market versions with `redeem` in place of `swap` |

**Value-reducing steps between `previewExitFor`'s `netGuaranteed` and what the caller actually holds (direct strategy):**
1. `convertToShares(amount)` floors → shares slightly short of the ask.
2. `min(shares, vault.balanceOf(strategy))` — the **uncapped-in-preview** global share cap.
3. `vault.redeem` applies the vault's real rate + any exit fee (`previewRedeem <= convertToAssets`).
4. Nothing checks the result. `_withdrawInternal` then debits the **requested** `amount`, not the received amount — so the shortfall is booked against the client as if delivered ("protocol-favouring write-down", explicitly documented and intentional).

**Same list for the market strategy:** (1)–(2) as above, plus (3') `convertToAssets(shares)` floors, (4') `minOut = ideal * (10000-bps)/10000` floors, (5') the **Curve swap** delivers anywhere in `[minOut, ∞)` — or reverts, (6') `safeTransfer` to recipient, (7') same protocol-favouring write-down of the full requested `amount`.

---

## 5. AMM adapters — interface abstraction only (UNCHANGED)

### `src/AMMAdapters/IAMMAdapter.sol`
Single member: `swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut)`. **Non-view. No quote/preview member exists.** This absence is load-bearing for story-050: it is why `netGuaranteed` is structurally incapable of being an expectation.

### `src/AMMAdapters/ICurveRouterNG.sol`
Mirrors Curve Router NG `exchange(address[11] _route, uint256[5][5] _swap_params, uint256 _amount, uint256 _expected, address[5] _pools, address _receiver) payable returns (uint256)`. Up to 5 hops. `_expected` is the slippage floor.

### `src/AMMAdapters/CurveAMMAdapter.sol`
`is IAMMAdapter, Ownable`. State: `router` (immutable `ICurveRouterNG`), `routes[tokenIn][tokenOut] => Route{path[11], swapParams[5][5], pools[5], configured}` (private).
- `setRoute(...)` — **onlyOwner**; validates `path[0] == tokenIn` and last non-zero entry `== tokenOut`. Does **not** validate hop indices, pool addresses, or `swapParams` semantics — an owner footgun by construction (Curve encoding is verified off-chain).
- `getRoute(...)`, `isPairFullyConfigured(a,b)` — views.
- `swap(...)` — **permissionless** (any caller), `requires` both directions configured + `amountIn > 0`, pulls `tokenIn` from `msg.sender`, `forceApprove`s the router for exactly `amountIn`, calls `router.exchange(..., _receiver = msg.sender)`. **No reentrancy guard, no pause.** It is a stateless pass-through: it holds no balances between calls and grants no allowance beyond the one it is about to consume, so permissionlessness is not itself a vector — but note the adapter is **shared** and any caller can drive route usage.
- Trust: `router` is the Curve Router NG (semi-trusted, immutable); `routes` are owner-authored (trusted-but-footgun).

---

## 6. Test suites read as EVIDENCE OF INTENT

`test/VaultWithdrawer.t.sol` — **formatting only**, pins nothing new.

### `test/unit/ERC4626MarketYieldStrategy.t.sol` (+226) — behaviours PINNED
1. `testPreviewExitForGrossesUpForHaircut` — gross is the ceil-rounded inverse; `netGuaranteed == _exitFloor(gross)`; `netGuaranteed >= netWanted`.
2. `testPreviewExitForZeroSlippageIsIdentity` — bps=0 collapses to identity.
3. `testPreviewExitForAtFivePercentTolerance` — exact `ceil(net*10000/9500)`.
4. `testPreviewExitForAtMaxBpsReturnsZeroWithoutPanic` — `(0,0)`, not `Panic(0x12)`.
5. `testPreviewExitForCapsToAccountPrincipal` — per-account cap; over-request quoted short, not padded.
6. `testPreviewExitForUnknownAccountReturnsZero`, `testPreviewExitForZeroNetWanted` — `(0,0)`, no revert.
7. `testPreviewExitForRevertsForWrongToken`.
8. `testPreviewExitForRoundTripDeliversAtLeastFloor` — real `withdraw`, `delivered >= netGuaranteed` **and** `>= netWanted`.
9. `testPreviewExitForRoundTripAtUnfavorableRateClearsFloor` — AMM at 0.995 (inside a 1% tolerance): floor holds, `delivered < grossToRequest`.
10. `testPreviewExitForFavorableAMMExceedsQuote` — AMM at 1.02: `delivered > netGuaranteed`, i.e. the quote is explicitly *not* an expectation.
11. `testPreviewExitForShareBalanceCapBinds` — after `simulateLoss(totalAssets/2)`, `netGuaranteed == _exitFloor(principal) < principal`. **The author knows the underwater case exists.**
12. `testPreviewExitForSurvivesStaticcall`.

### `test/unit/ERC4626YieldStrategy.t.sol` (+110) — behaviours PINNED
1. `testPreviewExitForIsIdentityOnDirectStrategy` — `gross == net == netGuaranteed`.
2. `testPreviewExitForCapsToAccountPrincipal`, `testPreviewExitForCapIsPerAccountNotGlobal`.
3. `testPreviewExitForUnknownAccountReturnsZero`, `testPreviewExitForRevertsForWrongToken`.
4. `testPreviewExitForRoundTripDeliversAtLeastFloor` — **at par, on a healthy mock vault only**.
5. `testPreviewExitFor_StateChangingPreviewRedeemVault_SurvivesStaticcall` — against `MockStateChangingPreviewVault`, with a control assertion that the vault's own `previewRedeem` really does trap. Genuinely strong story-049 regression cover.

### Behaviours the tests do NOT pin — the gaps that matter

| Un-pinned behaviour | Why it matters |
|---|---|
| **Direct strategy, underwater position.** There is no `ERC4626YieldStrategy` analogue of `testPreviewExitForShareBalanceCapBinds`. No test calls `simulateLoss` and then `previewExitFor` on the direct strategy. | The market path's identical case is tested and *fails the identity*; the direct path asserts the identity holds and is never tested below par. Direct highest-value hypothesis. |
| **Any vault charging an exit/withdrawal fee**, on either strategy. All mocks are fee-free. | Both previews are built on the fee-free `convertToAssets` by design; the over-quote is documented but never measured. |
| **Non-1:1 / high share price with the gross-up.** The `assertGe(netGuaranteed, netWanted)` assertions all run at (or near) 1:1. `simulateYield` is used only in the STATICCALL test, which asserts the *identity*, not the inequality. | The double-floor in `convertToAssets(convertToShares(x))` can exceed the `ceilDiv` slack. A consumer's `require(netGuaranteed >= netWanted)` would revert. |
| **Low-decimal underlying (USDC, 6dp).** Every test uses `e18` amounts and an 18-decimal mock. | Rounding losses that are dust at 18dp are material at 6dp. |
| **AMM rate *outside* tolerance.** Test 9 deliberately picks 0.995 against a 1% tolerance so the swap succeeds. **No test previews, then withdraws, at a rate that breaches `minOut`.** | The real failure mode of a healthy-looking quote is a `withdraw` **revert**, and it is completely untested. |
| **Preview → state change → withdraw (staleness).** Every round-trip test previews and withdraws atomically. | `vault.balanceOf(strategy)` is *global*: another client's `withdraw`, an `emergencyWithdraw`, a `skimSurplus`, or a vault-rate move between the two calls invalidates the quote. Nothing reserves the quoted amount. |
| **Multi-client contention on the share-balance cap.** `testPreviewExitForCapIsPerAccountNotGlobal` pins the *principal* cap as per-account, but the *share* cap in `_exitFloor` is global and untested with two clients. | Two clients previewing in the same block are each quoted against the whole share balance. |
| **`grossToRequest == 0` fed to `withdraw`.** No test does it. | It reverts `"amount must be greater than zero"` — a naive consumer loop bricks on a drained account. |
| **`netWanted` overflow.** `netWanted * MAX_BPS` panics above `2^256/10000`. Untested; practically unreachable. | Completeness only. |
| **Any actual consumer.** No integration test, in this repo or any sibling, calls `previewExitFor` from a client contract. | The whole API is unexercised in situ. |

---

## 7. Complexity summary

| File | LOC | Ext/pub fns | External calls | State vars |
|---|---|---|---|---|
| `AYieldStrategy.sol` | 918 | 26 | via hooks only | 8 (+3 constants) |
| `ERC4626MarketYieldStrategy.sol` | 448 | 4 own (+inherited) | vault ×6 sites, ammAdapter ×3, token transfers | 3 (+1 constant) |
| `ERC4626YieldStrategy.sol` | 327 | 4 own (+inherited) | vault ×~10, token transfers | 1 |
| `CurveAMMAdapter.sol` | 142 | 4 | router ×1, token ×2 | 2 |
| `IAMMAdapter.sol` / `ICurveRouterNG.sol` / `IYieldStrategy.sol` | 23 / 35 / 203 | interfaces | — | — |

---

## 8. Ranked hypotheses for the interaction scanners

Local-only. Exploitability across contracts is deliberately NOT adjudicated here.

**H-1 — Base default `previewExitFor` guarantees principal 1:1 without ever reading the position (`AYieldStrategy.sol:571`).**
`netGuaranteed = grossToRequest = min(netWanted, clientBalances[token][account])`, computed from storage alone. `ERC4626YieldStrategy._disposeShares` caps redemption at `vault.balanceOf(this)`; below par that cap binds and delivery falls short, silently, while `_withdrawInternal` still debits the full requested amount. The market strategy replicates the cap in `_exitFloor` **and has a test proving it changes the answer** (`testPreviewExitForShareBalanceCapBinds`); the base has neither. A consumer that sizes an obligation off `netGuaranteed` on a below-par direct strategy (the Tokemak `autoDOLA`/`autoUSD` wiring from run-16) is short by exactly the shortfall. Chase: (a) does any planned sibling consumer treat `netGuaranteed` as settlement? (b) is the shortfall socialised to the next withdrawer (first-come-first-served drain)? Note run-16 L-16 already flagged fee-blind NAV over-statement on `ERC4626YieldStrategy` — check whether H-1 is the same root cause reborn on a new function (fresh fingerprint, must be disclosed, not silently re-filed).

**H-2 — A healthy `netGuaranteed` immediately before a guaranteed `withdraw` revert (market strategy).**
`_exitFloor` never touches the AMM (`IAMMAdapter` has no quote member). When the Curve price of `vault → underlying` sits below `(MAX_BPS - bps)/MAX_BPS` of vault NAV — a share-token discount, a thin pool, a sandwich — `_disposeShares` does not under-deliver, it **reverts on `minOut`**. The preview reports full health throughout. The preview is a *refusal threshold*, not a liquidity signal, and nothing in the return values distinguishes the two. Untested (test 9 deliberately stays inside tolerance). Chase: any sibling using the preview as a solvency/health gate, or any keeper flow that would wedge.

**H-3 — `netGuaranteed < netWanted` with no cap binding, from the share round-trip double-floor (market strategy).**
`ceilDiv` buys one unit of slack; `convertToAssets(convertToShares(gross))` floors twice and can lose ~one share-price worth of underlying. Material when share price ≫ 1 underlying unit, or on a 6-decimal underlying. Every `assertGe(netGuaranteed, netWanted)` runs at 1:1, so the invariant the tests claim is unproven off-par. A consumer's `require(netGuaranteed >= netWanted)` reverts; a consumer without one is short. Cheap to settle with a fuzz/Halmos pass over share price and decimals.

**H-4 — `(0, 0)` is overloaded across four distinguishable states, and feeding `grossToRequest` back into `withdraw` reverts.**
`(0,0)` means, indistinguishably: unknown account, zero principal, `netWanted == 0`, or (market) `slippageToleranceBps == MAX_BPS` — the last being an operational alarm the NatSpec itself calls out. `withdraw(token, 0, recipient)` reverts `"AYieldStrategy: amount must be greater than zero"`. A consumer that previews-then-withdraws unconditionally bricks on a drained account. Consumer-side footgun; severity depends entirely on the sibling call sites.

**H-5 — The quote reserves nothing; `vault.balanceOf(strategy)` is global and shared.**
Two clients previewing in the same block are each quoted against the *whole* share balance. Any interleaved `withdraw`, `skimSurplus`, `emergencyWithdraw`, `totalWithdrawal` or vault-rate move between preview and withdraw invalidates it. Every round-trip test is atomic. Not a local finding; hand to the interaction scanner with the multi-client contention question.

**H-6 — ABI drift / forward-declared API with zero consumers.**
`previewExitFor` exists in no sibling repo at top-level HEAD (`stable-staker`, `stable-yield-accumulator`, `phlimbo-ea`, `antimatter`, `phoenix-phase-2-staging` all carry pre-050 `IYieldStrategy` copies). Two consequences: (a) the whole surface is unexercised in situ, so the consumer-contract obligations the NatSpec spells out at length are currently unenforced by anything; (b) adding a member to `IYieldStrategy` breaks any non-`AYieldStrategy` implementer of the interface on the next sibling submodule bump. Per the nested-pin rule, only top-level `lib/<sibling>` HEADs were read; nested `lib/**/lib/**` copies are stale by construction and were not treated as evidence.

**H-7 (QA) — `ERC4626MarketYieldStrategy.previewExitFor` is `override` without `virtual`.**
The base declares it `virtual`; the market override seals it. No subclass of the market strategy can correct the preview. Contrast the deliberate `virtual` on the base.

**H-8 (QA / owner footgun) — `setSlippageTolerance(MAX_BPS)` is permitted and degrades the whole strategy silently.**
At `MAX_BPS`, `_creditedPrincipal` books **zero** principal on every deposit and `_disposeShares` accepts any swap output. `previewExitFor` returning `(0,0)` is the only visible signal, and it is indistinguishable from an empty account (H-4). Non-obvious consequence of an owner-settable value ⇒ footgun, in scope under Law 3.

**H-9 (informational) — `vault.asset() == underlyingToken` is never checked** in either concrete constructor, while `convertToShares`/`convertToAssets` are used as the sole decimal bridge. Pre-existing, unchanged this run; noted because story-050 adds a third and fourth call site that inherits the assumption.
