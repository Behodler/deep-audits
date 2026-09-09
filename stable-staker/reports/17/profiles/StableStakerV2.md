# Contract Profile — src/StableStakerV2.sol

- Project: `stable-staker` | Run 17 (REGRESSION) | baseline `fa06de5` → HEAD `96d39ed`
- Source (READ-ONLY): `/home/justin/code/audits/lib/stable-staker/src/StableStakerV2.sol` (1220 LOC)
- Solidity: `^0.8.20` (checked arithmetic; no `unchecked`, no assembly in this file)
- Inheritance: `Ownable, Pausable, ReentrancyGuard, IPausable, IStableStaker`
- Story: `[story-025]` (commits `f0649e8` → `96d39ed`)
- Diff this run: `src/StableStakerV2.sol` +308, `src/interfaces/IAntimatter.sol` ±36,
  nested `lib/reflax-yield-vault` `0110ce4` → `cdd0743`.

---

## 1. Nested dependency pins actually read

| Dep | Pin used for this profile | Note |
|---|---|---|
| `lib/reflax-yield-vault` | `cdd0743` (nested pin == vault-RM run-17 pin) | `previewExitFor` read at this commit |
| `lib/antimatter` | `a5570ce` `[story-004] … add lib/pauser to foundry.lock` | **NEWER than the audits-repo top-level `lib/antimatter` HEAD `3a96fb7`** |
| `lib/openzeppelin-contracts` | `5fd1781` (v4.8.0-1122) | |
| `lib/pauser` | `545928d` | |

⚠ Toolchain note for the orchestrator: the audits repo's own `lib/antimatter` submodule
(`3a96fb7`, antimatter story-003) is **behind** the pin stable-staker actually compiles against
(`a5570ce`, antimatter story-004 — which adds the Phoenix pauser and makes `annihilate`
`whenNotPaused`). Any cross-repo claim about Antimatter for this run must read the *nested* pin.

---

## 2. State variables and their invariants

### Constants (`src/StableStakerV2.sol:48-81`)
| Name | Value | Note |
|---|---|---|
| `ACC_PRECISION` | `1e18` | MasterChef fixed point; dust always rounds DOWN |
| `SECONDS_PER_DAY` | `86400` | |
| `STAKER_VERSION` | `2` | V1 instance does not expose it |
| `EXIT_ROUNDING_ALLOWANCE` | `2` | **NEW** — absolute, raw `token` units |
| `EXIT_ROUNDING_ALLOWANCE_BPS` | `1` | **NEW** — 1 bp, proportional |
| `MAX_BPS` (private) | `10_000` | **NEW** |

### Mutable / immutable state
| Name | Line | Type | Writers | Invariant |
|---|---|---|---|---|
| `antimatter` | 84 | `IAntimatter immutable` | ctor | — |
| `pauser` | 87 | `address` | `setPauser` (owner) | |
| `migrator` | 90 | `address` | `setMigrator` (owner) | |
| **`claimEnabled`** | **100** | **`bool`** | **`setClaimEnabled` (owner)** | **FALSE on deployment; gates `claim` ONLY** |
| `poolInfo[token]` | 117 | `PoolInfo` | `_updatePool`, stake/withdraw/autoAnnihilate/_exitPosition/depositFor/finalizeAndReset/emergencyWithdraw | `totalStaked == Σ userInfo[*].amount` — held by every writer moving both in the same statement pair |
| `userInfo[token][user]` | 120 | `UserInfo{amount, rewardDebt}` | same set | `rewardDebt == amount * accAntimatterPerShare / ACC_PRECISION` after every mutation |
| `_stakers[token]` | 123 | `EnumerableSet` (private) | add on stake/depositFor; remove when `amount == 0` | `length()==0 ⟺ totalStaked==0` is the precondition `finalizeAndReset:904-905` asserts |
| `unclaimedReward[t][u]` | 130 | mapping | `_settle`, `withdraw`, `claim` (zeroed), `autoAnnihilate:548` (**overwritten, not `+=`**), `emergencyWithdraw` (zeroed), `_exitPosition` (zeroed) | settled-but-unminted backlog |
| `_registeredTokens` | 133 | `EnumerableSet` | `addToken` | |
| `yieldStrategy[token]` | 138 | `IYieldStrategy` | `setYieldStrategy` (owner, empty-pool only), cleared in `initiateMigration:748` | when set, `totalStaked` must track `strategy.principalOf(token,address(this))` |
| `poolState[token]` | 155 | `Active`/`Migrating` | `initiateMigration:753`, `finalizeAndReset:908` | |
| `migrationInfo[token]` | 169 | `{realized R, principalSnapshot P}` | `initiateMigration:769`, cleared `finalizeAndReset:906` | `R ≤ P` enforced at `:765-767` |

### Accounting identities maintained
1. **Emission cap** (header `:28-36`): the only writer of `accAntimatterPerShare` is
   `_updatePool:1073`, folding in exactly `elapsed * antimatterPerSecond`; Σ pending ≤ that,
   independent of stake churn. `autoAnnihilate` re-uses the *identical* settle arithmetic
   (`:538-539` vs `claim:442-446`), so the cap survives the new path.
2. **Principal conservation**: `pool.totalStaked` and `user.amount` are always debited by the
   *same* figure in the same block of statements (`autoAnnihilate:565-566` debits `gross` to both).
3. **Migration conservation** (`:754-770`, `_exitPosition:822-852`): `credit_i = p_i·min(R,P)/P`,
   floor-divided, so `Σ credit_i ≤ R`.

---

## 3. External / public entry points and access control

| Function | Line | Gates | Moves principal | Mints AM |
|---|---|---|---|---|
| `addToken` | 252 | `onlyOwner` | no | no |
| `antimatterPerDay` | 264 | `onlyOwner`, `poolExists` | no | no |
| `setMigrator` | 272 | `onlyOwner` | no | no |
| **`setClaimEnabled`** | **279** | **`onlyOwner`** | no | no |
| `setPauser` | 285 | `onlyOwner` | no | no |
| `setYieldStrategy` | 306 | `onlyOwner`, `poolExists`, `Active`, **`totalStaked==0`**, `!underwater(old)` | yes (strategy↔strategy) | no |
| `pause` | 364 | `onlyPauser` | no | no |
| `unpause` | 369 | owner OR pauser | no | no |
| `stake` | 378 | `nonReentrant whenNotPaused poolExists`, `Active` | in | no |
| `withdraw` | 400 | `nonReentrant whenNotPaused poolExists`, `Active`, underwater guard | out | no |
| `claim` | 439 | `nonReentrant whenNotPaused poolExists`, **`claimEnabled`** | no | **yes → caller** |
| **`autoAnnihilate`** | **516** | **`nonReentrant whenNotPaused poolExists`, `Active`, `autoAnnihilateAvailable`, underwater guard** | **out** | **yes → `address(this)` + caller** |
| `emergencyWithdraw` | 620 | `nonReentrant`, `Active`. **NO `whenNotPaused`** | out (no underwater guard) | no |
| `initiateMigration` | 692 | `nonReentrant onlyMigrator poolExists`, `Active` | strategy → this | no |
| `batchMigrate` | 790 | `nonReentrant onlyMigrator poolExists`, `Migrating` | out → migrator | yes (via `_exitPosition`) |
| `userMigrate` | 864 | `nonReentrant`, `Migrating`. **NO `whenNotPaused`** | out → caller | yes (via `_exitPosition`) |
| `finalizeAndReset` | 902 | `onlyOwner poolExists`, `Migrating`, empty pool. **NO `whenNotPaused`** | no | no |
| `depositFor` | 925 | `nonReentrant onlyMigrator poolExists`, `Active`. **NO `whenNotPaused`** | in | no |
| `rescueERC20` | 1212 | `onlyOwner`. **NO `whenNotPaused`, NO `nonReentrant`** | out → owner-chosen | no |
| views | 960-1071 | — | — | — |

Modifiers defined locally: `onlyPauser:223`, `onlyMigrator:228`, `poolExists:233`.

---

## 4. ENUMERATION 1 — every path that moves value out, and what bounds it

### 4a. `token` (stablecoin) leaves the contract

| # | Path | Line | Bound |
|---|---|---|---|
| V1 | `withdraw` → `safeTransfer(msg.sender, payout)` | 424 | `require(user.amount >= amount)` `:406`; `payout` = measured `_routeExit` delta; **reverts if strategy underwater and buffer < amount** (`_routeExit:1186-1195`) |
| V2 | `emergencyWithdraw` → `safeTransfer(msg.sender, payout)` | 635 | caller's full `user.amount` only; underwater guard OFF, so it accepts the haircut |
| V3 | **`autoAnnihilate` → `forceApprove(antimatter, netUsed)` then `antimatter.annihilate` pulls `netUsed`** | 600-601 | `netUsed = min(received, netWanted)`; `netWanted ≤ user.amount` by the cap at `:543-544`; approval reset to 0 at `:602` |
| V4 | **`autoAnnihilate` → `safeTransfer(msg.sender, surplus)` (NEW)** | 609 | `surplus = received - netUsed` `:591`; caller was debited `gross ≥` this |
| V5 | `userMigrate` → `safeTransfer(msg.sender, credit)` | 872 | `credit = amt·min(R,P)/P`, floor-divided |
| V6 | `batchMigrate` → `safeTransfer(msg.sender /*migrator*/, total)` | 810 | Σ of the same snapshot credits; `onlyMigrator` |
| V7 | `initiateMigration` → `_routeExit(token, P, false)` | 712 | pulls INTO this contract (no external egress), then `require(...principalOf == 0, "incomplete exit")` `:739-742` |
| V8 | `setYieldStrategy` → `_routeExit(token, staked, false)` then `strategy.deposit(idleBalance)` | 336, 353 | `onlyOwner` + `totalStaked == 0` precondition, so `staked` is 0 in practice; the `idleBalance` sweep moves the **whole** contract balance (incl. buffer) into the new strategy |
| V9 | `rescueERC20` → `safeTransfer(to, amount)` | 1218 | `bal >= reserved + amount` where `reserved = totalStaked` **only when no strategy is set**; with a strategy set `reserved == 0`, so the entire idle buffer is owner-rescuable (`:1214-1216`) |

### 4b. Antimatter is minted (value creation, not egress)

| # | Path | Line | Gated by `claimEnabled`? |
|---|---|---|---|
| M1 | `claim` → `antimatter.mint(msg.sender, owed)` | 447 | **YES** (`require(claimEnabled)` `:440`) |
| M2 | **`autoAnnihilate` → `antimatter.mint(address(this), annihilatable)`** | 599 | **NO** — immediately burned by `annihilate` |
| M3 | **`autoAnnihilate` → `antimatter.mint(msg.sender, excess)`** | 605 | **NO** — raw AM to the caller's wallet |
| M4 | `_exitPosition` → `antimatter.mint(account, owed)` | 849 | **NO** — deliberate, per the comment at `:845-847` |

`_settle:1099` and `withdraw:417-419` only *book* to `unclaimedReward`; they never call Antimatter,
so a revoked minter role cannot brick principal paths.

---

## 5. ENUMERATION 2 — the exit-shortfall floor and its rounding allowance (verbatim)

Quote sizing, `src/StableStakerV2.sol:551-560`:

```solidity
{
    // Size the exit against the strategy's haircut, then cap the GROSS — never the net —
    // at the caller's own principal, or the debit below underflows for the caller
    // annihilating their whole position. `netFloor` is pro-rated when our cap bites,
    // because the quote was issued for the uncapped request.
    (uint256 grossQuote, uint256 netQuote) = _previewExit(token, netWanted);
    require(netWanted == 0 || grossQuote > 0, "StableStaker: exit unavailable");
    gross = grossQuote > user.amount ? user.amount : grossQuote;
    netFloor = grossQuote == 0 ? 0 : (netQuote * gross) / grossQuote;
}
```

Floor check, `src/StableStakerV2.sol:576-592`:

```solidity
if (gross > 0) {
    uint256 received = _routeExit(token, gross, true);
    uint256 allowance = EXIT_ROUNDING_ALLOWANCE + (netFloor * EXIT_ROUNDING_ALLOWANCE_BPS) / MAX_BPS;
    uint256 floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0;
    require(received > 0 && received >= floorWithAllowance, "StableStaker: exit shortfall");
    netUsed = received < netWanted ? received : netWanted;
    surplus = received - netUsed;
}
```

Constants, `src/StableStakerV2.sol:70` and `:78`:

```solidity
uint256 public constant EXIT_ROUNDING_ALLOWANCE = 2;
uint256 public constant EXIT_ROUNDING_ALLOWANCE_BPS = 1;
```

### Arithmetic, stated exactly

- `allowance = 2 + floor(netFloor / 10_000)` (1 bp, floor-divided → **0 for any `netFloor < 10_000`
  raw units**; for 6-decimal USDC that means the proportional leg contributes nothing below
  0.01 USDC and the whole allowance is the flat `2`).
- `floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0` — saturating, so a small
  `netFloor` collapses the check to `received > 0`.
- Effective tolerance: the call passes on any `received ≥ netFloor·(1 − 1e-4) − 2`.
- Pro-ration `netFloor = netQuote·gross/grossQuote` (`:559`) is a **linear** rescale of a quote that
  was issued for the uncapped `grossQuote`; the strategy's own `_exitFloor(gross)` is
  `convertToAssets(convertToShares(gross))·(1−slip)/MAX_BPS`, which is only approximately linear
  (two extra floors). The 2-unit flat allowance is what absorbs that mismatch too.
- Rounding direction: every division here floors (`:544`, `:548`, `:559`, `:567`, `:587`), i.e. in
  the protocol's favour, except the pro-ration at `:559` which floors `netFloor` and therefore
  *loosens* the check by up to 1 unit.

### What the floor actually protects (important for downstream)

The NatSpec at `:580-586` claims the floor stops an under-delivery "quietly drawing the difference
from the shared idle buffer". **That is already structurally impossible** because of `:590`:
`netUsed = min(received, netWanted)` — the annihilation can never consume more stable than the exit
actually delivered, so no shortfall can reach the buffer regardless of the floor. The floor's real
function is the one described at `:75-77`: to stop a **lying/manipulated preview** from shrinking
`netUsed` and thereby *widening* the `excess` raw-AM mint path (M3) around a closed `claim` gate.
Downstream should reason about it as an anti-`claimEnabled`-bypass control, not a buffer control.

---

## 6. ENUMERATION 3 — what `claimEnabled` gates, and what it does NOT

Declaration `:100`, setter `:279-283`, the single consumer `:440`:

```solidity
function claim(address token) external nonReentrant whenNotPaused poolExists(token) {
    require(claimEnabled, "StableStaker: claim disabled");
```

`grep` confirms `claimEnabled` is read at exactly one site. It therefore gates **only** `claim`.

**Remains fully open while `claimEnabled == false`:**

| Open path | Line | Consequence |
|---|---|---|
| `autoAnnihilate` excess mint (M3) | 605 | Raw Antimatter to the caller's wallet — the documented loophole (`:471-474`). Any user whose reward has outrun their principal, or whose principal is 0, receives the *entire* `owed` as raw AM |
| `_exitPosition` migration mint (M4) | 849 | Deliberately ungated (`:845-847`) so a closed gate cannot brick migration |
| `autoAnnihilate` self-mint (M2) | 599 | Transient; burned in the same call |
| All principal egress V1/V2/V4/V5/V6 | 424, 635, 609, 872, 810 | Unaffected — `claimEnabled` is not a principal gate |
| `stake`, `depositFor` | 378, 925 | Unaffected |

**Zero-principal corner:** a caller with `user.amount == 0` but a non-zero `unclaimedReward`
backlog gets `principalAsAntimatter = 0` `:540` → `capped = 0` → `netWanted = 0`,
`excessBase = owed`. The `require` at `:546` passes on `excessBase > 0`, `gross = 0`, and the whole
backlog is minted raw at `:605`. So `autoAnnihilate` is a **complete functional substitute for the
disabled `claim`** for anyone holding no stake — with the extra requirements that the pool be
`Active` (`:517`) and `autoAnnihilateAvailable` (`:521`), which `claim` does not require. The
contract's own NatSpec acknowledges this at `:471-474` ("a knowing, documented loophole").

Also note the asymmetry: `claim` has *no* `PoolState.Active` gate (`:437`, deliberate), whereas
`autoAnnihilate` does (`:517`). So on a `Migrating` pool with `claimEnabled == false`, neither
reward path is open and the backlog is only reachable through the migration exit.

---

## 7. ENUMERATION 4 — `autoAnnihilate`: access control, call sequence, state writes

**Signature** `:516`:
`function autoAnnihilate(address token, uint256 minPhUSDOut) external nonReentrant whenNotPaused poolExists(token)`

**Who can call it:** anyone. No `onlyOwner`/`onlyMigrator`/allowlist. It acts strictly on
`msg.sender`'s own `userInfo` and `unclaimedReward` — there is no `for`/`onBehalfOf` parameter, so
it cannot be driven against a third party.

**Preconditions:** not paused (this contract's pauser); `poolExists(token)`;
`poolState[token] == Active` `:517`; `autoAnnihilateAvailable(token)` `:521`;
`netWanted > 0 || excessBase > 0` `:546`; `netWanted == 0 || grossQuote > 0` `:557`;
`IERC20Metadata(token).decimals() <= 18` (`_antimatterScale:1123-1127`, live read, fails closed).

**Call sequence (in order):**

1. `autoAnnihilateAvailable(token)` `:521` → **staticcall** `antimatter.toStableAmount(token, 1e18)`
   `:1052-1053`; then, if a strategy is set and `strategy.principalOf(token, address(this)) != 0`
   `:1058`, **staticcall** `strategy.previewExitFor(token, address(this), 1)` `:1061-1062`,
   requiring `returndata.length == 64` and `grossQuote > 0` `:1063-1067`.
2. `IERC20Metadata(token).decimals()` `:1124`.
3. `_updatePool(token)` `:533` (internal, no external call).
4. `_previewExit(token, netWanted)` `:556` → `strategy.previewExitFor(token, address(this), netWanted)`
   (`:1173`), or `(netWanted, netWanted)` when no strategy is set (`:1171`).
5. **All state effects** (below) — CEI is respected up to this point.
6. `_routeExit(token, gross, true)` `:579`:
   - underwater branch: `strategy.totalBalanceOf` + `strategy.principalOf` (`_isUnderwater:1133`),
     then `token.balanceOf(this)`, then **`strategy.relinquishPrincipal(token, gross)`** and
     return `gross` — **the whole gross is paid from the shared idle buffer** (`:1186-1195`);
   - normal branch: `token.balanceOf(this)`, `strategy.withdraw(token, gross, address(this))`,
     `token.balanceOf(this)` → measured delta (`:1196-1198`).
7. `antimatter.mint(address(this), annihilatable)` `:599`.
8. `token.forceApprove(address(antimatter), netUsed)` `:600`.
9. `antimatter.annihilate(token, msg.sender, annihilatable, minPhUSDOut)` `:601` — burns this
   contract's own AM, pulls `netUsed` `token`, mints phUSD to `msg.sender`.
10. `token.forceApprove(address(antimatter), 0)` `:602`.
11. `antimatter.mint(msg.sender, excess)` `:605` (if `excess > 0`).
12. `token.safeTransfer(msg.sender, surplus)` `:609` (if `surplus > 0`).
13. `emit AutoAnnihilated(token, msg.sender, annihilatable, gross, excess)` `:611`.

**Every state write it performs (all in this contract):**

| Write | Line | Value |
|---|---|---|
| `poolInfo[token].accAntimatterPerShare`, `.lastRewardTime` | 533 → 1073 | via `_updatePool` |
| `unclaimedReward[token][msg.sender]` | 548 | **assigned** `capped - netWanted*scale` (the sub-unit remainder). Note: this *overwrites*, correctly draining the backlog |
| `userInfo[token][msg.sender].amount` | 565 | `-= gross` |
| `poolInfo[token].totalStaked` | 566 | `-= gross` |
| `userInfo[token][msg.sender].rewardDebt` | 567 | re-based to `amount * accAntimatterPerShare / ACC_PRECISION` |
| `_stakers[token]` | 569 | `.remove(msg.sender)` when `amount == 0` |
| `token` allowance to `antimatter` | 600, 602 | set to `netUsed`, then reset to 0 |

No write occurs after step 5 other than the allowance and the external contracts' own state, so
CEI holds; `nonReentrant` additionally covers the untrusted `antimatter` and `strategy` callbacks.

---

## 8. `previewExitFor` semantics at `lib/reflax-yield-vault@cdd0743` — LOAD-BEARING

Two implementations exist and they have **materially different guarantees**.

### 8a. Direct / full-credit strategies — `AYieldStrategy.previewExitFor` (base)

`lib/reflax-yield-vault/src/AYieldStrategy.sol:571-583`:

```solidity
uint256 availablePrincipal = clientBalances[token][account];
grossToRequest = netWanted > availablePrincipal ? availablePrincipal : netWanted;
netGuaranteed = grossToRequest;
```

This is the **capped identity**: `netGuaranteed == grossToRequest == min(netWanted, principal)`.
Inherited unchanged by `ERC4626YieldStrategy` (the strategy actually wired for the stable pools).

But the realised exit is `ERC4626YieldStrategy._disposeShares`
(`src/concreteYieldStrategies/ERC4626YieldStrategy.sol:126-138`):

```solidity
uint256 sharesToRedeem = vault.convertToShares(amount);
uint256 availableShares = vault.balanceOf(address(this));
if (sharesToRedeem > availableShares) { sharesToRedeem = availableShares; }
vault.redeem(sharesToRedeem, recipient, address(this));
```

Two independent round-downs — `convertToShares` floors, then the vault's `redeem` floors the assets
back — so at any non-integral share price the delivery is `amount - 1` (or a couple more units on
an awkward price).

**Therefore, for direct strategies `netGuaranteed` is an UPPER bound / exact-equality claim that the
real exit systematically cannot meet — it is NOT a lower bound.** It over-states by O(1) raw units,
scaling with the share price rather than with the amount. This is exactly the defect
`EXIT_ROUNDING_ALLOWANCE` was added to paper over (commits `7112756` "Red: autoAnnihilate reverts
against the real ERC4626 strategy" → `9346933` "Give the exit shortfall floor a rounding allowance").
Without the allowance every `autoAnnihilate` against a yielded real ERC4626 vault reverts
`"StableStaker: exit shortfall"`.

### 8b. Market strategy — `ERC4626MarketYieldStrategy.previewExitFor`

`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:162-187`:

```solidity
uint256 denominator = MAX_BPS - slippageToleranceBps;
if (denominator == 0) { return (0, 0); }        // 100% tolerance ⇒ guarantees nothing
grossToRequest = Math.ceilDiv(netWanted * MAX_BPS, denominator);
uint256 availablePrincipal = clientBalances[token][account];
if (grossToRequest > availablePrincipal) { grossToRequest = availablePrincipal; }
netGuaranteed = _exitFloor(grossToRequest);
```

with `_exitFloor` (`:127-135`):

```solidity
uint256 sharesToSell = vault.convertToShares(amount);
uint256 availableShares = vault.balanceOf(address(this));
if (sharesToSell > availableShares) { sharesToSell = availableShares; }
uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
return idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
```

`_disposeShares` (`:236-257`) computes its swap `minOut` with **byte-identical arithmetic**, so
within a single transaction `netGuaranteed` is a **genuine, AMM-enforced lower bound** on delivery
for the exact `grossToRequest` quoted. Conditions under which it nonetheless mis-states:

- **Over-states (delivery can fall below it) when the vault charges a withdrawal/exit fee** — both
  legs are built on `convertToAssets`, the fee-free ideal conversion (story 049 deliberately avoids
  `previewRedeem` because Tokemak-Autopool vaults mutate state inside it and trap under
  STATICCALL). Documented at `IYieldStrategy.sol` reason 3 and `ERC4626MarketYieldStrategy.sol:121-125`.
  In `autoAnnihilate` this is contained only because `minOut` in `_disposeShares` is derived the
  same way — the *swap* is still floored, but the AMM output then has a fee taken off it.
- **Under-states when a cap binds** — `grossToRequest` capped to `clientBalances`, or `sharesToSell`
  capped to held shares, both push `netGuaranteed` **below** `netWanted`. That is the honest
  "the position cannot cover the ask" answer, not an error.
- **Over-states because it reads live vault + AMM state** and is manipulable within a block
  (`IYieldStrategy.sol` reason 2). In `autoAnnihilate` preview and execution are the same
  transaction with no intervening external call, so this reduces to same-block manipulation of the
  *vault* by the caller before entry.
- **Delivery routinely EXCEEDS it** — the AMM pays anywhere at or above `minOut`
  (`IYieldStrategy.sol` reason 1). This is why `autoAnnihilate` has the `surplus` leg at `:591`/`:609`.
- **`(0, 0)` is a valid answer** meaning "guarantees nothing at all": empty position, unknown
  account, or `slippageToleranceBps == MAX_BPS`. `autoAnnihilateAvailable:1063-1067` uses exactly
  this to refuse.

### 8c. Net semantics as consumed by V2

| Wired strategy | `netGuaranteed` is | V2's `netFloor` check is |
|---|---|---|
| none (idle) | exact (`netWanted`) | trivially satisfied — `_routeExit` returns `amount` |
| `ERC4626YieldStrategy` (direct) | **an upper bound** (over-states by O(1) units) | only passes *because* of the 2-unit + 1 bp allowance |
| `ERC4626MarketYieldStrategy` | a true lower bound modulo vault fees | real, and the 1 bp allowance is far below any realistic `slippageToleranceBps` |
| underwater + buffer covers | not consulted — `_routeExit:1186-1195` returns `gross` verbatim | `received == gross ≥ netFloor` always passes |

---

## 9. ABI / selector reconciliation — `IAntimatter.sol` vs the real Antimatter

`src/interfaces/IAntimatter.sol` gained `annihilate` and `toStableAmount` this run. Checked against
`lib/antimatter@a5570ce` (the pin stable-staker compiles against):

| Declared in `IAntimatter.sol` | Real `Antimatter.sol` | Match |
|---|---|---|
| `mint(address,uint256)` `:19` | `:216 function mint(address to, uint256 amount) external onlyApprovedMinters` | ✅ |
| `annihilate(address,address,uint256,uint256)` `:34` | `:253 function annihilate(address stable, address recipient, uint256 amount, uint256 minPhUSDOut)` (`nonReentrant`, `whenNotPaused` at `:255`) | ✅ |
| `toStableAmount(address,uint256) view returns (uint256)` `:46` | `:314 function toStableAmount(address stable, uint256 amount) public view returns (uint256)` | ✅ |

**No signature or selector mismatch.** Parameter order and types are identical in all three cases.

Two ABI-adjacent notes for downstream:

- `IYieldStrategy` is **not** locally re-declared — it is imported from the real dependency
  (`src/StableStakerV2.sol:13`, remapping `reflax-yield-vault/=lib/reflax-yield-vault/src/`), so
  `previewExitFor`'s selector cannot drift; a mismatch would be a compile error.
  `autoAnnihilateAvailable` nonetheless hand-encodes it via `abi.encodeCall(IYieldStrategy.previewExitFor, …)`
  and validates `previewData.length != 64` `:1063` — type-safe encoding, defensive decode.
- `annihilate` is `whenNotPaused` against **Antimatter's own** Phoenix pauser, which StableStaker
  does not control (interface NatSpec `:29-30`, real contract `:255`). A cross-contract liveness
  coupling, not a local finding: while Antimatter is paused, `autoAnnihilate` reverts for every
  caller with `netWanted > 0`, and the operational answer is `setClaimEnabled(true)`.

---

## 10. Verified local properties

| Property | Result | Evidence |
|---|---|---|
| Checked arithmetic | **verified** — `^0.8.20`, no `unchecked`, no assembly | file-wide grep |
| Unbounded loops | **verified** — the only loop is `batchMigrate:802` over a **caller-supplied, `onlyMigrator`** array; `getStakersRange:995` is paged; `finalizeAndReset` asserts `length()==0` rather than iterating (`:904`) | `:802`, `:995`, `:904` |
| Reentrancy guards | `nonReentrant` on stake, withdraw, claim, **autoAnnihilate**, emergencyWithdraw, initiateMigration, batchMigrate, userMigrate, depositFor. **Absent** on `rescueERC20:1212` (trailing transfer, owner-only, no post-state) and on all owner setters | per-function |
| CEI in the new code | **verified** for `autoAnnihilate` — all storage writes at `:548-570` precede every interaction from `:579` | `:562-611` |
| Access control on state-changers | **verified** — every principal-moving/config function carries `onlyOwner`, `onlyMigrator`, `onlyPauser`, or acts only on `msg.sender` | table §3 |
| Initializer protection | **n/a** — non-upgradeable, constructor-based | |
| Weak randomness | **verified absent** — no `block.prevrandao`/`blockhash`/`difficulty`; `block.timestamp` is used only for emission accrual (`_updatePool:1084-1093`, `finalizeAndReset:907`), never for a value-bearing draw | |
| Storage layout / collision | **n/a** — no proxy, no delegatecall | |
| Precision loss / rounding | **likely-safe** — all divisions floor in the protocol's favour except the `netFloor` pro-ration at `:559` which loosens the check by ≤1 unit; see §5 | |
| Live `decimals()` read | **by design, fails closed** (`_antimatterScale:1123-1127`) — a token whose `decimals()` reverts makes `autoAnnihilate` (and only it) revert | |
| Inbound callback surface | **none** — no ERC721/1155/777 hooks; no `_safeMint`/`safeTransferFrom`; the only inbound-callable surfaces are the untrusted `antimatter` and `strategy` externals, all `nonReentrant`-covered | |
| Assembly | **none** — the two low-level `staticcall`s at `:1052` and `:1061` use `abi.encodeCall` + `abi.decode` with a length check, not raw assembly | |

## 11. Trust boundaries

| Counterparty | Trust level | Notes |
|---|---|---|
| `antimatter` (immutable) | trusted-ish, **liveness-coupled** | `mint` gated by its own approved-minter whitelist; `annihilate` gated by *its* pauser, which this contract does not control. Reentrancy-relevant: `annihilate` is `nonReentrant` on its side and V2's side |
| `yieldStrategy[token]` | **semi-trusted, owner-set** | `previewExitFor` is explicitly **advisory** — the vault docs say it MUST be measured, and V2 does measure (`:579`, `:589`). `withdraw`/`relinquishPrincipal`/`totalBalanceOf`/`principalOf` are all believed |
| The underlying ERC4626 vault + AMM adapter (two hops away) | **untrusted for pricing** | governs the real delivery; fee-charging vaults break the `_exitFloor` premise |
| `token` (pool stablecoin) | semi-trusted | standard ERC20 assumed; `_pullToken:1109` and `_routeExit:1196-1198` measure balance deltas, so fee-on-transfer degrades gracefully rather than corrupting accounting. `decimals()` must not revert and must be ≤18 |
| `migrator` | trusted, owner-set | drives `initiateMigration`/`batchMigrate`/`depositFor` |
| `owner` | trusted (Law 3) | `setClaimEnabled`, `setYieldStrategy`, `rescueERC20`, `finalizeAndReset` |
| `pauser` | trusted, owner-set | pause; owner-or-pauser unpause |
| phUSD stable minter (reached through Antimatter) | **new coupling** | the pool token must ALSO be a registered stablecoin there — see `autoAnnihilateAvailable:1051` NatSpec. Registration is now part of the pool-registration runbook |

## 12. Observations handed to interaction analysis (NOT adjudicated here)

1. **Underwater + buffer-covers branch of `_routeExit` (`:1186-1195`) pays `gross`, not `netWanted`.**
   `autoAnnihilate` passes `guardUnderwater = true`, but that branch does not revert when the idle
   buffer covers the request — it returns `gross` verbatim and calls `relinquishPrincipal(gross)`.
   With a market strategy `gross = ceil(netWanted/(1−slip)) > netWanted`, so the caller is paid the
   full grossed-up figure out of the **shared** buffer and pockets `surplus = gross − netWanted` at
   `:609`, having incurred no actual AMM haircut. Books stay conservative (`user.amount` was debited
   `gross`), but the buffer drains at the grossed-up rate — a rate `withdraw` never applies, since
   `withdraw` requests exactly `amount`. Needs econ/interaction review.
2. **The floor's stated purpose does not match its effect** (§5) — `netUsed = min(received, netWanted)`
   already makes the buffer unreachable. The floor is only an anti-`claimEnabled`-bypass control.
3. **`autoAnnihilate` is a complete `claim` substitute for a zero-principal caller** (§6).
4. **`autoAnnihilateAvailable` probes with `netWanted = 1`** (`:1061`) but the real call uses the
   caller's full `netWanted`; a strategy can answer `grossQuote > 0` for 1 unit and `(0, …)` or a
   deeply-capped quote for the real amount. `:557` catches `grossQuote == 0`, but a *capped* quote
   silently shrinks `gross` below what the caller needs and diverts the remainder into the raw-AM
   `excess` path at `:605`.
5. **`netFloor` pro-ration is linear over a non-linear floor** (`:559`); the 2-unit allowance is the
   only thing absorbing the mismatch, and it does not scale with `gross`.
6. **Antimatter pin skew** (§1) — the audits repo's `lib/antimatter` is behind the nested pin.

---

## 13. Supporting context (shallow — trust boundaries only, not deep-profiled)

All four files are **unchanged this run** (`git diff fa06de5 96d39ed` touches neither).

- `src/CrossVersionMigrator.sol` (242 LOC) — `onlyOwner` `initiateMigration:147` / `migrate:161`;
  version-probes the staker via `_versionOf:200`. Does **not** reference `claim`, `autoAnnihilate`,
  `claimEnabled`, or `previewExitFor`. Interacts with V2 only through
  `initiateMigration` / `batchMigrate` / `depositFor`, all `onlyMigrator`.
- `src/InPlaceMigrator.sol` (384 LOC) — `onlyOwner` `migrateOut:165` / `migrateIn:203`, plus the
  permissionless self-only `claimTimedOut:307` (its "claim" is the parked-principal hatch, entirely
  unrelated to `StableStakerV2.claim`). Same three V2 entry points; no new coupling to story-025.
- `src/versions/v1/StableStakerV1.sol` (854 LOC, hash-pinned via `src/versions/v1/FROZEN.sha256`) —
  `claim:377` has **no `claimEnabled` gate** and no `autoAnnihilate`. The frozen V1 is therefore
  unaffected by the teaching phase: a user still holding a V1 position claims raw Antimatter…
  no — raw **FlaxToken** (V1's reward token, remapped `flax-token/=src/versions/v1/vendor/`), which
  is a different asset. No cross-version interaction with the new gate.
- `src/interfaces/IStableStakerV1.sol`, `src/interfaces/IStableStaker.sol`,
  `src/interfaces/IStableStakerMigratable.sol` — declaration only.

Consequence for interaction analysis: **story-025's surface is entirely contained in
`StableStakerV2.sol` plus the two nested dependencies.** No migrator path can reach
`autoAnnihilate` or observe `claimEnabled`.
