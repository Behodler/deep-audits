# Code Scan (Tier 2, interaction) — reflax-yield-vault @ `cdd0743` (run 17)

- **Project**: reflax-yield-vault · **Commit**: `cdd0743` `[story-050] GREEN: previewExitFor on IYieldStrategy…`
- **Scan type**: `code` (implementation bugs, interaction level)
- **Scan date**: 2026-08-31
- **Contracts scanned**: 7 (4 changed: `AYieldStrategy.sol`, `interfaces/IYieldStrategy.sol`, `concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, `concreteYieldStrategies/ERC4626YieldStrategy.sol`; 3 unchanged: `AMMAdapters/{CurveAMMAdapter,IAMMAdapter,ICurveRouterNG}.sol`)
- **Known-issues suppression**: UNAVAILABLE this run (cache empty, count 0). Nothing was suppressed on those grounds.
- **Inputs consumed, not re-derived**: `contract-profiles.md` (Tier 1) and `story-faithfulness.md` (F-01-050, F-02-050) for this run.

All PoCs live at `/home/justin/code/audits/workspace/reflax-yield-vault/test/poc-run17-preview-exit.t.sol`
(6 tests, all passing). Run with:

```
forge test --match-path test/poc-run17-preview-exit.t.sol -vv --skip 'test/poc-run17-econ-exit-preview.t.sol'
```

(the `--skip` avoids a concurrently-authored econ-scan file that does not compile; it is not mine and
was left untouched.)

---

## Hypothesis verdict table

| # | Hypothesis | Verdict | Evidence |
|---|---|---|---|
| H-2 | Healthy quote immediately before a guaranteed `withdraw` revert | **CONFIRMED** | `testH2_HealthyQuoteThenWithdrawReverts`, `testH2_QuoteIsInvariantToAMMPrice` → CODE-02 |
| H-3 | `netGuaranteed < netWanted` with no cap binding | **CONFIRMED but BOUNDED to dust** — subsumed by F-02-050, not filed separately | analytic bound + 256-run fuzz, §H-3 below |
| H-4 | `(0,0)` overloaded; preview→withdraw loop bricks | **CONFIRMED**, and a *fifth* ambiguity found | `testH4_ZeroZeroIsFourDifferentStates` → CODE-03 |
| H-5 | Quote reserves nothing; `vault.balanceOf` is global and shared across clients | **CONFIRMED** | `testH5_TwoClientsQuotedTheSameShares` → CODE-01 |
| H-6 | New interface member breaks non-`AYieldStrategy` implementers | **CONFIRMED**, with a **correction** to the story-faithfulness enumeration | full grep enumeration → CODE-06 |
| H-7 | Market override sealed (`override` without `virtual`) | **CONFIRMED** | `ERC4626MarketYieldStrategy.sol:162-166` → CODE-05 |
| H-9 | `vault.asset() == underlyingToken` never checked | **CONFIRMED** | zero `asset()` occurrences in `src/` → CODE-07 |

---

## CODE-01 — `netGuaranteed` is floored against the GLOBAL share balance, so every client is quoted a floor only one of them can be paid

- **id**: `CODE-001` · **type**: `cross-contract-state-consistency` (shared-state / no-reservation quote)
- **severity**: **Low today · potential-Medium on wiring** (same escalation shape as F-01-050)
- **contract**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
- **function**: `previewExitFor` / `_exitFloor` · **line** 130 · **lineStart** 127 · **lineEnd** 186
- **confidence**: **high** (PoC, passing)

### The code

`previewExitFor` caps `grossToRequest` **per account**, then hands that gross to `_exitFloor`, whose
own cap is **global**:

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:127-135
function _exitFloor(uint256 amount) internal view returns (uint256) {
    uint256 sharesToSell = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));   // <-- GLOBAL, all clients
    if (sharesToSell > availableShares) {
        sharesToSell = availableShares;
    }
    uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
    return idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
}
```

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:178-183
uint256 availablePrincipal = clientBalances[token][account];   // per-account
if (grossToRequest > availablePrincipal) {
    grossToRequest = availablePrincipal;
}

netGuaranteed = _exitFloor(grossToRequest);                     // global
```

Tier 1 flagged the *per-account principal* cap as correctly per-account
(`testPreviewExitForCapIsPerAccountNotGlobal` pins it). The **share** cap is the opposite and is
untested with two clients. The two caps therefore mix two different accounting universes in one
return value.

`clientBalances` accounting makes this trivially reachable: `_depositInternal`
(`src/AYieldStrategy.sol:730-747`) books each client independently, and nothing on any path
associates specific vault shares with a specific client. The condition needed is simply
`_positionValue() < totalDeposited[token]` — the below-par state the profile records as **not
enforced on-chain** ("Nothing requires `_positionValue() >= totalDeposited[token]`").

### PoC — `testH5_TwoClientsQuotedTheSameShares` (PASS)

Two clients deposit 1000e18 each (990e18 principal each after the 1% deposit haircut), then a 50%
vault loss:

```
whole position value : 1000000000000000000000
netGuaranteed user1  :  980100000000000000000
netGuaranteed user2  :  980100000000000000000
sum of the two floors: 1960200000000000000000   <-- 1.96x the whole position
user2 actually received: 20000000000000000000
user2 was quoted       : 980100000000000000000
```

`user2` receives **2.0%** of the floor it was quoted, and — via the protocol-favouring write-down at
`src/AYieldStrategy.sol:781-783` — has its **full 990e18 principal debited anyway**:

```solidity
// src/AYieldStrategy.sol:778-783
uint256 sharesDisposed = _disposeShares(amount, recipient);

// Decrement by the REQUESTED (capped) amount, not what was received — shortfall accrues as yield.
clientBalances[token][balanceHolder] -= amount;
totalDeposited[token] -= amount;
```

### Why this is not F-01-050

F-01-050 is *"the base default never models the share cap at all"* (direct strategy). CODE-01 is
*"the market override does model it, correctly, and it is still wrong across clients."* The market
strategy is the one the story treats as the honest implementation, and its own test
`testPreviewExitForShareBalanceCapBinds` — the test that proves the author knew about the underwater
case — runs with a **single** client and therefore cannot see this. Fixing F-01-050 by copying
`_exitFloor` into the base would propagate CODE-01 to the direct strategy too.

### Attack vector / impact

First-come-first-served drain of a below-par position is a pre-existing property of `withdraw`.
What story-050 adds is a **view function that legitimises it**: a consumer that reads `netGuaranteed`
as an exclusive claim (which is what the word "guarantees" in the interface NatSpec means) will size
an obligation it cannot honour. Two clients previewing in the same block both pass their own
`require(netGuaranteed >= needed)`; the second to land is short by up to 100% of the deficit. No
attacker privileges are required — ordinary interleaved withdrawals suffice, and MEV ordering makes
the race trivially winnable.

**Low today** because the enumeration below shows zero consumers exist (see CODE-06). Escalate to
**Medium** at the `stable-staker` submodule bump, on the same trigger as F-01-050 (WATCH-17-03).

### Recommended mitigation

Either (a) apportion the share cap: floor `netGuaranteed` at
`_positionValue() * clientBalances[token][account] / totalDeposited[token]` — the pro-rata figure
`principalOf`'s sibling `totalBalanceOf` already computes (`src/AYieldStrategy.sol:540-549`) — or
(b) state in the interface NatSpec that `netGuaranteed` is **non-exclusive** and holds only if the
caller is the sole exiter in the block. (a) makes the guarantee true under contention; (b) is honest
and free.

---

## CODE-02 — the exit preview is provably invariant to AMM price, so it reports full health immediately before a `withdraw` that is guaranteed to revert

- **id**: `CODE-002` · **type**: `availability / DoS` (false-green pre-flight signal)
- **severity**: **Low today · potential-Medium on wiring**
- **contract**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
- **function**: `previewExitFor` · **line** 186 · **lineStart** 162 · **lineEnd** 186
- **confidence**: **high** (PoC, passing)

### The structural cause

`IAMMAdapter` has exactly one member, and it is not a view:

```solidity
// src/AMMAdapters/IAMMAdapter.sol:11-23
interface IAMMAdapter {
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
        external
        returns (uint256 amountOut);
}
```

`CurveAMMAdapter` adds `getRoute` and `isPairFullyConfigured` (`:100`, `:115`) but **no quote** —
neither exposes `ICurveRouterNG.get_dy` or any price read. So `_exitFloor` cannot consult the AMM
even in principle, and the value it returns is a pure function of vault state. `_disposeShares`
passes that same number as `minOut`:

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:246-251
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;   // == _exitFloor(amount)
IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);
uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);
```

and `ICurveRouterNG.exchange`'s `_expected` argument enforces it, so the swap **reverts** rather than
under-delivering. The preview is therefore a *refusal threshold*, and nothing in its two return values
tells the caller whether the threshold is currently satisfiable.

### PoC — `testH2_QuoteIsInvariantToAMMPrice` (PASS)

Deposit 1000e18, quote `netWanted = 900e18`, then depeg the share token 99% on the AMM
(`setExchangeRate(vault → underlying, 0.01e18)`) and re-quote:

```solidity
assertEq(netAt1, netAtDepeg, "netGuaranteed does not move when the AMM collapses 99%");
```

Passes. The quote is bit-identical across a 99% price collapse.

### PoC — `testH2_HealthyQuoteThenWithdrawReverts` (PASS)

At a 1% tolerance, with the share token trading at 0.90 (10% discount, ten times the tolerance):

```
booked principal: 990000000000000000000
grossToRequest  : 909090909090909090910
netGuaranteed   : 900000000000000000000     <-- asserted assertGe(net, 900e18): covers netWanted IN FULL
```

and in the same block, with no intervening state change:

```solidity
vm.prank(client);
vm.expectRevert("MockAMMAdapter: insufficient output amount");
strategy.withdraw(address(underlyingToken), gross, user1);
```

### Availability / DoS assessment (the question asked)

- **Blast radius**: the *entire* `withdraw` and `withdrawAsOwner` path of the market strategy is
  bricked for **every** client for as long as the AMM rate sits below `(MAX_BPS − bps)/MAX_BPS` of
  vault NAV. `_disposeShares` is the single shared exit hook, so this is not per-account.
  `totalWithdrawal` → `_totalWithdraw` (`:287-317`) uses the same `minOut` construction at `:303` and
  bricks identically.
- **Trigger**: no privilege needed. A share-token discount on a thin Curve pool, a sandwich around
  the exit, or an sUSDe/USDe-style depeg all suffice. At the default 1% tolerance (`setUp`) the
  window is narrow.
- **Persistence**: temporary — it clears when the pool re-prices, and the owner can widen
  `slippageToleranceBps` (which is itself the CODE-03/H-8 footgun). `relinquishPrincipal`
  (`src/AYieldStrategy.sol:682`) can always write principal down without touching the AMM. So this is
  a **liveness** problem, not a permanent freeze — do not read it as fund loss.
- **What story-050 makes worse**: before this change there was no pre-flight signal at all, and a
  consumer had to try-and-revert. Now there *is* a signal, it is documented with the word
  "guarantees", and it is **always green** in precisely the state where the call is guaranteed to
  fail. A keeper or router that gates on `netGuaranteed > 0` will wedge in a retry loop, and an
  operator reading the preview during an incident will conclude the position is healthy.

The market test suite cannot catch this: `testPreviewExitForRoundTripAtUnfavorableRateClearsFloor`
deliberately picks 0.995 against a 1% tolerance so the swap succeeds. **No test previews and then
withdraws at a rate that breaches `minOut`.**

### Recommended mitigation

Add a quote member to `IAMMAdapter` (`CurveAMMAdapter` can wrap `ICurveRouterNG.get_dy`, which the
router already exposes) and have `previewExitFor` return `netGuaranteed = 0` — or a distinct third
return / custom error — when the live route cannot clear `minOut`. If that is too large a change,
the interface NatSpec must stop implying liquidity: state explicitly that `netGuaranteed > 0` is
**not** evidence that `withdraw` will succeed, and that the real failure mode of an unhealthy market
is a revert, not under-delivery.

---

## CODE-03 — `(0,0)` collapses four states, `(gross>0, 0)` is a fifth trap, and the returned `grossToRequest` bricks `withdraw` in both

- **id**: `CODE-003` · **type**: `call-sequence / API contract` (+ owner footgun, Law 3)
- **severity**: **Low** (QA-adjacent; the footgun half is an operational hazard)
- **contract**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (+ `src/AYieldStrategy.sol:571-583`)
- **function**: `previewExitFor` · **line** 172 · **lineStart** 162 · **lineEnd** 186
- **confidence**: **high** (PoC, passing)

### PoC — `testH4_ZeroZeroIsFourDifferentStates` (PASS)

Four operationally unrelated states return **bit-identical** `(0, 0)`:

| State | How reached | Meaning |
|---|---|---|
| (a) unknown account | `previewExitFor(token, 0xBAD, 100e18)` | account was never a client |
| (b) zero request | `previewExitFor(token, user1, 0)` on a **fully-funded** account | caller asked for nothing |
| (c) drained account | after `withdraw` of the whole principal | client is empty |
| (d) `slippageToleranceBps == MAX_BPS` | `setSlippageTolerance(MAX_BPS)` on a **fully-funded** account | the strategy can guarantee nothing |

```solidity
assertEq(acc, 0, "all four states return exactly (0,0)");                       // acc = OR of all 8 returns
assertGt(strategy.principalOf(address(underlyingToken), user2), 0, "state (d) has live principal");
```

Both assertions pass — state (d) has a live, fully-funded 990e18 principal and is indistinguishable
from an account that never existed. And feeding the returned gross straight back:

```solidity
vm.prank(client);
vm.expectRevert("AYieldStrategy: amount must be greater than zero");
strategy.withdraw(address(underlyingToken), g3, user1);
```

— the guard at `src/AYieldStrategy.sol:767`:

```solidity
require(amount > 0, "AYieldStrategy: amount must be greater than zero");
```

So a consumer implementing the documented `preview → withdraw(grossToRequest)` loop reverts, rather
than no-op'ing, on a drained account. The `(0,0)` return is the only "soft failure" the API offers
and it is not soft.

### The fifth state the NatSpec presents as the *honest* signal — and it is worse

The market NatSpec (`:150-153`) tells the reader that a below-capacity position reports honestly by
dropping `netGuaranteed` while keeping `grossToRequest` positive. Probe (run in workspace, deleted):
owner calls `emergencyWithdraw` to move the whole position out; principal stays booked:

```
shares left  : 0
principal    : 990000000000000000000000
gross quoted : 1010101010101010101011      <-- POSITIVE, so the (0,0) sentinel does NOT fire
netGuaranteed: 0
convertToShares(gross) capped to balanceOf: 0
```

`_disposeShares` then calls `ammAdapter.swap(vault, underlying, 0, 0)`. On the production adapter
that reverts:

```solidity
// src/AMMAdapters/CurveAMMAdapter.sol:129
require(amountIn > 0, "CurveAMMAdapter: amountIn must be > 0");
```

See CODE-04 for why no test sees this.

### Owner footgun (Law 3 — in scope, non-obvious consequence)

`setSlippageTolerance` accepts exactly `MAX_BPS`:

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:89-92
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
```

At that setting `_creditedPrincipal` (`:107-109`) books **zero** principal on every deposit —
`amount * (10000 - 10000) / 10000 == 0` — so deposits are silently swallowed, and `_disposeShares`
accepts any swap output at `minOut = 0`. The **only** on-chain signal is `previewExitFor` returning
`(0,0)`, which the same preview also returns for an empty account. A competent, non-malicious owner
setting "maximum tolerance" to unblock a stuck withdrawal during an incident would be surprised that
the same knob zeroes deposit crediting and erases the distinguishability of the alarm. That is the
footgun test: **surprise ⇒ report**. Not filed as "a malicious owner could…", and no such vector is
claimed.

### Recommended mitigation

Distinguish the states cheaply — either a third return value / status enum, or a custom error for
the wrong-account and MAX_BPS cases while keeping `(0,0)` for the genuinely-zero request. At minimum,
document that a consumer **must** skip `withdraw` when `grossToRequest == 0`, and that
`grossToRequest > 0 && netGuaranteed == 0` also means "do not call". For the footgun: `require(_bps <
MAX_BPS)`, or emit a distinct alarm event at the boundary.

---

## CODE-04 — the test AMM adapter is more permissive than the production one on exactly the edge story-050 steers callers into

- **id**: `CODE-004` · **type**: `test-fidelity / cross-contract precondition`
- **severity**: **Low**
- **contract**: `src/AMMAdapters/CurveAMMAdapter.sol` (vs `test/mocks/MockAMMAdapter.sol`)
- **function**: `swap` · **line** 129
- **confidence**: **high** (code, deterministic)

`CurveAMMAdapter.swap` rejects a zero-size swap at `src/AMMAdapters/CurveAMMAdapter.sol:129`
(`require(amountIn > 0, "CurveAMMAdapter: amountIn must be > 0");`). `MockAMMAdapter.swap` has no
such guard — its only `require` is the `minAmountOut` check at
`test/mocks/MockAMMAdapter.sol:63`. **Every** market-strategy test, including all 13 new
`previewExitFor` tests, runs against the mock. The divergence is therefore invisible to the suite.

`_disposeShares` reaches `amountIn == 0` two ways, both reachable and both newly surfaced by the
preview:

1. **`vault.balanceOf(strategy) == 0` with principal still booked** — after `emergencyWithdraw`, or
   after another client drains the position (CODE-01). Proven in the probe above: gross quoted
   1010e18, shares 0.
2. **`convertToShares(gross) == 0` for a dust exit once the share price exceeds one underlying unit.**
   Probe at a ~4x share price (`testDust`, workspace):

   ```
   assetsPerShare(1): 4
   netWanted: 1   gross: 2   shares: 0   netGuaranteed: 0
   netWanted: 2   gross: 3   shares: 0   netGuaranteed: 0
   netWanted: 3   gross: 4   shares: 1   netGuaranteed: 3
   ```

   A caller who ignores `netGuaranteed == 0` and requests `gross = 2` reverts on mainnet and succeeds
   in every test.

### Remedy enumeration (run, not asserted)

I enumerated every path that can reduce `clientBalances` without routing through `_disposeShares`:

| Path | Behaviour when `vault.balanceOf(strategy) == 0` | Remedy? |
|---|---|---|
| `withdraw` / `withdrawAsOwner` → `_withdrawInternal` → `_disposeShares` | reverts at `CurveAMMAdapter.sol:129` | **No** |
| `totalWithdrawal` → `_totalWithdraw` | early-returns at `ERC4626MarketYieldStrategy.sol:294` (`return; // Nothing to withdraw`), leaving principal booked and consuming the two-phase window | **No** (silent no-op) |
| `relinquishPrincipal` (`AYieldStrategy.sol:682`, `onlyAuthorizedClient`) → `_relinquishInternal` (`:700-716`) — pure write-down, **no external call** | succeeds | **Yes** |
| `relinquishPrincipalAsOwner` (`AYieldStrategy.sol:687`, `onlyOwner`) | succeeds | **Yes** |

So the stranded principal is **recoverable** by either the client or the owner. This is a bricked
*normal* path with two working escape hatches, not a permanent freeze — hence Low, not Medium. I make
no "no remedy exists" claim.

### Recommended mitigation

Give `_disposeShares` an early `if (sharesToSell == 0) return 0;` (matching `_totalWithdraw`'s own
`if (sharesToSell > 0)` guard at `:300`), and add the `amountIn > 0` guard to `MockAMMAdapter` so the
suite tests the production precondition.

---

## CODE-05 (QA) — the market `previewExitFor` override is sealed against subclassing

- **id**: `CODE-005` · **type**: `QA / extensibility` · **severity**: **QA**
- **contract**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` · **lineStart** 162 · **lineEnd** 166

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:162-166
function previewExitFor(address token, address account, uint256 netWanted)
    external
    view
    override                       // <-- no `virtual`
    returns (uint256 grossToRequest, uint256 netGuaranteed)
```

versus the deliberate base:

```solidity
// src/AYieldStrategy.sol:571-577
function previewExitFor(address token, address account, uint256 netWanted)
    external
    view
    virtual
    override
    returns (uint256 grossToRequest, uint256 netGuaranteed)
```

**CONFIRMED.** No subclass of `ERC4626MarketYieldStrategy` can correct the preview — which matters
given CODE-01 and CODE-02 are both defects a subclass would want to patch, and given the repo's
established pattern of shipping forked variants (`NFTStakerPriceScaled`, `StableStakerV1/V2`). Every
other overridable hook on this contract (`_disposeShares`, `_positionValue`, `getTotalShares`) is
reachable; this one is the exception. One-word fix: add `virtual`.

---

## CODE-06 (informational) — implementer enumeration for the `IYieldStrategy` breaking change, with a correction to `story-faithfulness.md`

- **id**: `CODE-006` · **type**: `ABI drift` · **severity**: **informational**
- **contract**: `src/interfaces/IYieldStrategy.sol` · **line** 79

Adding a member to an interface breaks every contract that declares `is IYieldStrategy` without
inheriting `AYieldStrategy`. **Enumeration I actually ran** (full output, not truncated), over every
registered top-level submodule at its own HEAD, excluding nested `lib/**` (stale by construction):

```
$ cd lib && grep -rn --include=*.sol -E "is[[:space:]]+IYieldStrategy" . | grep -v "/lib/"
stable-staker/test/Migration.t.sol:924:contract UnderRealizingStrategy is IYieldStrategy {
stable-staker/test/mocks/MockYieldStrategy.sol:26:contract MockYieldStrategy is IYieldStrategy {
stable-yield-accumulator/test/StableYieldAccumulator.t.sol:112:contract MockYieldStrategy is IYieldStrategy {
stable-yield-accumulator/test/StableYieldAccumulator.t.sol:215:contract MockRevertingYieldStrategy is IYieldStrategy {
```

Submodule HEADs at scan time: `antimatter@3a96fb7`, `phlimbo-ea@f279c62`,
`phoenix-nft-staking@9611312`, `phoenix-phase-2-staging@1d8a3a7`, `reflax-yield-vault@cdd0743`,
`stable-staker@fa06de5`, `stable-yield-accumulator@6eab35c`, `yield-claim-nft@d4cc563`.

**What concretely breaks, and when.** All four resolve `IYieldStrategy` through a **remapping to the
live reflax submodule**, not a vendored copy:

```
stable-staker/test/mocks/MockYieldStrategy.sol:6:  import "reflax-yield-vault/interfaces/IYieldStrategy.sol";
stable-staker/test/Migration.t.sol:11:             import "reflax-yield-vault/interfaces/IYieldStrategy.sol";
stable-yield-accumulator/test/StableYieldAccumulator.t.sol:7: import "vault/interfaces/IYieldStrategy.sol";
```

A `find . -name IYieldStrategy.sol | grep -v /lib/` returns only `reflax-yield-vault/src/interfaces/`
plus three `out/` build artifacts — **no repo vendors its own copy**. So the moment `stable-staker`
or `stable-yield-accumulator` bumps its `lib/reflax-yield-vault` pin past `cdd0743`, those four
contracts fail to compile with *"Contract … should be marked as abstract"* — a **build break in the
test suite, not a runtime break**, since all four are test doubles. `phoenix-phase-2-staging` has
zero implementers (its `IYieldStrategy` hits are all `setYieldStrategy(...)` call sites, which are
unaffected). `antimatter/test/mocks/MockYieldStrategy.sol:9` declares `contract MockYieldStrategy {`
with **no** interface inheritance — unaffected.

**Correction to `story-faithfulness.md` WATCH-17-01.** That note lists **six** implementers, two of
which I could not verify: `phusd-stable-minter/test/PhusdStableMinter.t.sol:66` and
`deployment-staging/src/mocks/MockYieldStrategy.sol:12`. Neither repo is registered in `lib/`, so
neither is inside this run's evidence base. The second one matters disproportionately if the citation
is right — it sits in **`src/`, not `test/`**, i.e. a production-path implementer, which would turn a
test-only build break into a deployable-contract break. **Recommend registering
`deployment-staging` (or confirming it is dead) before the next reflax bump.** I am not asserting it
exists; I am flagging that the claim is currently unverifiable from `lib/`.

**Zero consumers, verified.** `grep -rn --include=*.sol "previewExitFor" lib/` returns hits **only**
under `reflax-yield-vault/` (33 hits: 3 in `src/`, 30 in this repo's own tests) — full output was
inspected, not head-truncated. This is what keeps CODE-01, CODE-02 and F-01-050 at Low today.

---

## CODE-07 (informational) — `vault.asset() == underlyingToken` is never checked, and story-050 adds two more call sites that inherit the assumption

- **id**: `CODE-007` · **type**: `unchecked constructor invariant` · **severity**: **informational**
- **contract**: both concretes · **line**: `ERC4626MarketYieldStrategy.sol:63-70`, `ERC4626YieldStrategy.sol:43`

```
$ grep -rn "asset()" src/
(no output — ZERO occurrences of asset() anywhere in src/)
```

Both constructors validate only non-zero-ness:

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:63-70
constructor(address _owner, address _underlyingToken, address _erc4626Vault, address _ammAdapter)
    AYieldStrategy(_owner, _underlyingToken)
{
    require(_erc4626Vault != address(0), "ERC4626MarketYieldStrategy: vault cannot be zero address");
    require(_ammAdapter != address(0), "ERC4626MarketYieldStrategy: AMM adapter cannot be zero address");
    vault = IERC4626(_erc4626Vault);
    ammAdapter = IAMMAdapter(_ammAdapter);
}
```

`convertToShares`/`convertToAssets` are the sole decimal bridge between `underlyingToken` and vault
shares, so a vault whose `asset()` is a different token silently mis-scales every conversion.
Pre-existing and unchanged; recorded because `_exitFloor` (`:128`, `:132`) adds a **third and fourth**
call site inheriting the assumption, and because those two sit on a function whose whole purpose is
to be quoted to an external consumer. A one-line `require(IERC4626(_erc4626Vault).asset() ==
_underlyingToken)` in both constructors closes it permanently. Not filed as a finding: it is an
owner-deployment-time check with an obvious failure mode (nothing works), so it fails the footgun
surprise test.

---

## H-3 — verdict: CONFIRMED but bounded to dust. NOT filed separately; subsumed by F-02-050.

The question asked was whether `netGuaranteed < netWanted` is reachable with **no cap binding**,
purely from the double-floor exceeding the `ceilDiv` slack, and to **bound** it. It is reachable, and
the bound is tight.

**Analytic bound.** With `S = vault.totalSupply()`, `A = vault.totalAssets()`, `d = MAX_BPS − bps`,
`M = MAX_BPS`, and `g = ceilDiv(net·M, d) ≥ net·M/d`:

- `shares = ⌊g·S/A⌋ > g·S/A − 1`
- `back  = ⌊shares·A/S⌋ > (g·S/A − 1)·A/S − 1 = g − A/S − 1`
- `netGuaranteed = ⌊back·d/M⌋ > (g − A/S − 1)·d/M − 1 ≥ net − (A/S + 1)·d/M − 1`
- since `d/M ≤ 1`: **`netWanted − netGuaranteed ≤ ⌈A/S⌉ + 2`** raw underlying base units.

`A/S` is the assets-per-share ratio in raw units. Under the ERC4626 convention that share decimals
track asset decimals it is the share price, ~1–10 for any realistic vault, so the worst-case
shortfall is **≤ ~12 raw base units** — 1.2e-17 tokens at 18 decimals, ~$0.000012 at USDC's 6. It
gets *smaller*, not larger, when share decimals exceed asset decimals (the 6-dec-underlying case
Tier 1 worried about): there `A/S ≈ 1e-12 < 1`.

**Empirical confirmation.** `testFuzz_H3_ShortfallIsBoundedByAssetsPerShare` (256 runs, PASS) sweeps
`simulateYield` across 0–40M and `netWanted` across 1e18–500,000e18, `vm.assume`s that **neither**
the principal cap nor the share cap binds, and asserts
`assertLe(netWanted - net, assetsPerShare + 2)`. No counterexample.

**Verdict: not a security finding.** It is a real deviation from the property the story claims and the
tests appear to prove, which is exactly what F-02-050 already records at QA severity. Filing it again
here would be a duplicate on a fresh fingerprint.

---

## AMM adapters — scan of the unchanged code for anything the changed code newly depends on

The changed code newly depends on `IAMMAdapter` in exactly one way: `_exitFloor` needs a quote and
the interface does not have one (CODE-02). Everything else I checked and **cleared**:

| Checked | Verdict |
|---|---|
| `CurveAMMAdapter.swap` is **permissionless** (`:120`, no `onlyOwner`, no guard) | **Not a vector.** It pulls `tokenIn` from `msg.sender` (`:132`) and sets `_receiver = msg.sender` (`:138`). An arbitrary caller can only spend and receive its own tokens. |
| Residual allowance from `safeIncreaseAllowance(ammAdapter, sharesToSell)` (`:249`) accumulating across failed exits | **Not exploitable through the adapter.** Even a non-zero standing strategy→adapter allowance cannot be drained, because `swap` transfers `from: msg.sender`, never from an arbitrary address. A *different* contract holding an allowance would be a vector; this one is not. Housekeeping only. |
| `forceApprove(router, amountIn)` (`:135`) leaving router allowance | Router consumes exactly `amountIn`; `forceApprove` resets first. Clean. |
| `amountOut` is the **router's self-reported** return (`:138`), and `_disposeShares` transfers that number out of the strategy's own balance (`ERC4626MarketYieldStrategy.sol:252`) | Semi-trusted immutable router; an over-report would dip into idle strategy balance or revert. No idle balance is held on the happy path. Noted, not filed. |
| Reentrancy across the A→B→A boundary: `strategy.withdraw` → `ammAdapter.swap` → `router.exchange` → back into the strategy | **Cleared.** `withdraw`/`deposit`/`skimSurplus`/`totalWithdrawal` all carry `nonReentrant` (`AYieldStrategy.sol:642-648` et al.). The adapter holds no state between calls and grants no callback. Neither token leg has a hook: no ERC777, no ERC721/1155 `_safeMint` or receive hook anywhere in `src/` (confirmed by Tier 1 and re-checked). |
| **Read-only reentrancy** on `previewExitFor` | **Cleared as a mechanism, superseded by CODE-01/CODE-02 as an outcome.** `previewExitFor` *is* an external view a downstream integrator would consume as an oracle, and it *is* readable mid-flight — but it never depends on any transiently-inconsistent state of *this* contract: `clientBalances` and `vault.balanceOf` are both settled at every point where an external call is in flight (`_withdrawInternal` disposes shares **before** the debit at `:781`, so a mid-`_disposeShares` read sees pre-debit principal and post-disposal shares — an over-quote, which is exactly CODE-01's failure, reached by a different route). Filing it separately would be a duplicate. |
| `setRoute` (`:62-89`) validating only `path[0]` and the last non-zero entry, not hop indices or pool addresses | Pre-existing owner footgun with an **obvious** failure mode (a wrong route reverts or swaps at a visibly absurd rate). Fails the surprise test; not filed. Unchanged this run. |
| `ICurveRouterNG.exchange`'s `_expected` genuinely enforcing `minOut` | Yes — this is what makes CODE-02's failure mode a revert rather than under-delivery. |

---

## Reentrancy-class checklist (mandatory walk)

| Class | Cleared? | Why |
|---|---|---|
| Classic single-fn | **Cleared** | `nonReentrant` on every value-moving entry point (`AYieldStrategy.sol:642-648`, `662-665`, `677`, `682`, `687`); `emergencyWithdraw` is `onlyOwner` and pre-existing (Tier 1) |
| Cross-contract (A→B→A) | **Cleared** | only outbound callee is `ammAdapter` → `router`, neither of which calls back; guards hold across the whole chain |
| Cross-function (sibling sharing state) | **Cleared** | OZ `ReentrancyGuard` is **contract-wide**, not per-function, so the whole `deposit`/`withdraw`/`skim`/`totalWithdrawal` sibling set shares one lock |
| **Read-only** | **Cleared as a mechanism** | see the AMM table row above — no transient-inconsistency window; the over-quote it would produce is already CODE-01 |
| ERC721 `onERC721Received` | **Cleared** | no `_safeMint`/`safeTransferFrom` of any NFT anywhere in `src/` |
| ERC1155 receive hooks | **Cleared** | no ERC1155 in `src/` |
| ERC777 `tokensReceived`/`tokensToSend` | **Cleared** | value token is a plain ERC20 handled via `SafeERC20`; weird-ERC20 support is a C4 known-invalid and no hook-bearing token is in scope |

No row left unresolved.

---

## Explicitly NOT re-filed (already captured upstream)

- **F-01-050** — base default over-quotes on the direct strategy when the share cap binds. CODE-01 is
  the *different* defect on the strategy that does model the cap; the two must not be collapsed, and
  a fix that copies `_exitFloor` into the base resolves F-01 while spreading CODE-01.
- **F-02-050** — `ceilDiv`/double-floor dust. See the H-3 section for the bound; not re-filed.
- Tier-1 local findings (arithmetic, guards, per-function access control, `totalDeposited == Σ
  clientBalances`) — all deferred to `contract-profiles.md` as required.
- **run-16 L-16** (fee-blind NAV over-statement on `ERC4626YieldStrategy`) shares a root cause with
  F-01-050, not with anything filed here. Disclosed so the next reader does not treat CODE-01 as its
  re-file.

---

## Machine-readable summary

```json
{
  "project": "reflax-yield-vault",
  "scanTimestamp": "2026-08-31T00:00:00Z",
  "scanType": "code",
  "commit": "cdd0743",
  "contractsScanned": 7,
  "findings": [
    {
      "id": "CODE-001",
      "type": "cross-contract-state-consistency",
      "severity": "potential-medium",
      "severityToday": "low",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 130, "lineStart": 127, "lineEnd": 186,
      "description": "netGuaranteed is floored against the GLOBAL vault.balanceOf(strategy) while grossToRequest is capped per-account, so N clients are each quoted a floor only one can be paid. Nothing reserves the quoted shares.",
      "codeSnippet": "uint256 availableShares = vault.balanceOf(address(this));\nif (sharesToSell > availableShares) { sharesToSell = availableShares; }",
      "attackVector": "Two clients on a below-par position each preview a 980.1e18 floor against a 1000e18 position; the first to withdraw takes it, the second receives 20e18 (2% of quote) and still has its full 990e18 principal debited by the protocol-favouring write-down at AYieldStrategy.sol:781.",
      "poc": "workspace/reflax-yield-vault/test/poc-run17-preview-exit.t.sol::testH5_TwoClientsQuotedTheSameShares",
      "confidence": "high"
    },
    {
      "id": "CODE-002",
      "type": "availability",
      "severity": "potential-medium",
      "severityToday": "low",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 186, "lineStart": 162, "lineEnd": 186,
      "description": "IAMMAdapter exposes no quote member, so _exitFloor is a pure function of vault state and the preview is provably invariant to AMM price. It reports a full-health netGuaranteed in exactly the state where withdraw is guaranteed to revert on minOut.",
      "codeSnippet": "uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;\nuint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);",
      "attackVector": "Share token trading 10% below NAV at a 1% tolerance: preview returns grossToRequest 909.09e18 / netGuaranteed 900e18, and withdraw(gross) reverts in the same block. The whole market-strategy exit path (withdraw, withdrawAsOwner, totalWithdrawal) is bricked for all clients until the pool re-prices; relinquishPrincipal remains available.",
      "poc": "workspace/reflax-yield-vault/test/poc-run17-preview-exit.t.sol::testH2_HealthyQuoteThenWithdrawReverts, ::testH2_QuoteIsInvariantToAMMPrice",
      "confidence": "high"
    },
    {
      "id": "CODE-003",
      "type": "call-sequence",
      "severity": "low",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 172, "lineStart": 162, "lineEnd": 186,
      "description": "(0,0) is returned indistinguishably for unknown account / zero netWanted / drained account / slippageToleranceBps == MAX_BPS on a fully-funded account; feeding grossToRequest back into withdraw reverts at AYieldStrategy.sol:767. A fifth state (gross>0, net==0), which the NatSpec presents as the honest signal, also bricks withdraw on the production adapter. Includes the setSlippageTolerance(MAX_BPS) owner footgun, whose only signal is that same (0,0).",
      "codeSnippet": "uint256 denominator = MAX_BPS - slippageToleranceBps;\nif (denominator == 0) { return (0, 0); }",
      "attackVector": "Consumer-side: a documented preview-then-withdraw loop reverts rather than no-ops on a drained account. Operator-side: an owner setting MAX_BPS tolerance to unblock an exit silently zeroes deposit crediting (_creditedPrincipal returns 0) and erases the only alarm signal.",
      "poc": "workspace/reflax-yield-vault/test/poc-run17-preview-exit.t.sol::testH4_ZeroZeroIsFourDifferentStates",
      "confidence": "high"
    },
    {
      "id": "CODE-004",
      "type": "test-fidelity",
      "severity": "low",
      "contract": "src/AMMAdapters/CurveAMMAdapter.sol",
      "function": "swap",
      "line": 129,
      "description": "CurveAMMAdapter reverts on amountIn == 0; MockAMMAdapter (used by every market-strategy test, including all 13 new preview tests) does not. _disposeShares reaches amountIn == 0 when vault.balanceOf(strategy) == 0 with principal booked, and when convertToShares(gross) == 0 for a dust exit at a share price above one underlying unit.",
      "codeSnippet": "require(amountIn > 0, \"CurveAMMAdapter: amountIn must be > 0\");",
      "attackVector": "Normal withdraw path bricks on mainnet in a state every test reports as healthy. Remedy enumeration run: relinquishPrincipal (AYieldStrategy.sol:682) and relinquishPrincipalAsOwner (:687) both clear the principal without an external call; totalWithdrawal silently no-ops at ERC4626MarketYieldStrategy.sol:294. Not a permanent freeze.",
      "confidence": "high"
    },
    {
      "id": "CODE-005",
      "type": "qa-extensibility",
      "severity": "qa",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 165, "lineStart": 162, "lineEnd": 166,
      "description": "Market override is declared `override` without `virtual`, sealing the preview against any subclass, while the base at AYieldStrategy.sol:574 is deliberately `virtual`. Every other overridable hook on this contract remains reachable.",
      "codeSnippet": "external\nview\noverride\nreturns (uint256 grossToRequest, uint256 netGuaranteed)",
      "confidence": "high"
    },
    {
      "id": "CODE-006",
      "type": "abi-drift",
      "severity": "informational",
      "contract": "src/interfaces/IYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 79,
      "description": "Four non-AYieldStrategy implementers exist across registered lib/ submodules at their own HEADs, all in test/, all resolving IYieldStrategy through a remapping to the live reflax copy (no repo vendors its own). All four fail to compile at the next submodule bump. Corrects story-faithfulness WATCH-17-01, which lists six: phusd-stable-minter and deployment-staging are not registered in lib/ and could not be verified; the latter's citation places it in src/, which would escalate a test-only break to a production-path break.",
      "attackVector": "Build break at the consumer's submodule bump, not a runtime vector.",
      "confidence": "high"
    },
    {
      "id": "CODE-007",
      "type": "unchecked-invariant",
      "severity": "informational",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "constructor",
      "line": 63, "lineStart": 63, "lineEnd": 70,
      "description": "vault.asset() == underlyingToken is never checked in either concrete constructor (zero occurrences of asset() in src/), while convertToShares/convertToAssets are the sole decimal bridge. story-050's _exitFloor adds a third and fourth call site inheriting the assumption.",
      "confidence": "high"
    }
  ],
  "hypothesisVerdicts": {
    "H-2": "CONFIRMED -> CODE-002",
    "H-3": "CONFIRMED but bounded to ceil(A/S)+2 raw units (analytic + 256-run fuzz); subsumed by F-02-050, not filed",
    "H-4": "CONFIRMED -> CODE-003 (plus a fifth state)",
    "H-5": "CONFIRMED -> CODE-001",
    "H-6": "CONFIRMED -> CODE-006 (with a correction to WATCH-17-01)",
    "H-7": "CONFIRMED -> CODE-005",
    "H-9": "CONFIRMED -> CODE-007"
  },
  "notFiled": {
    "readOnlyReentrancy": "cleared as a mechanism; the over-quote it would produce is already CODE-001",
    "permissionlessCurveAdapterSwap": "cleared - pulls from and pays to msg.sender only",
    "residualStrategyToAdapterAllowance": "cleared - unexploitable because swap transfers from msg.sender, never an arbitrary address",
    "setRouteValidationGaps": "obvious-failure owner action, fails the Law-3 surprise test"
  }
}
```
