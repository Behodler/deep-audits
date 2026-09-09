<!--
ID: ss9m7
C4 Submission Metadata
Title: [M-07] setYieldStrategy underwater guard is rate-based, bypassed by AMM execution slippage (incomplete fix of M-06)
Severity: Medium
Contract: src/StableStaker.sol
Function: setYieldStrategy
Fingerprint: 969722dc9eedb961b93d1b10bdfc61af5d6a457c6dac717a6deb2730b7990689
Root Cause Class: rate-vs-execution-residual
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L230
Cross-refs: incomplete-fix of M-06 (dbdc3ac9, acknowledged, story-008 a7e2f78); related M-01 (dab5a656, same end-state, distinct path); comparable M-05 (0dca43f3)
PoC File: workspace/stable-staker/test/PoC_A1_RateVsExecutionResidual.t.sol
-->

# [M-07] `setYieldStrategy` underwater guard is rate-based, bypassed by AMM execution slippage (incomplete fix of M-06)

**Severity:** Medium

**Contract:** `src/StableStaker.sol` — `setYieldStrategy`

**Root cause link:** [`src/StableStaker.sol#L230`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L230)

## Finding description and impact

### Summary

story-008 (`a7e2f78`) added an underwater guard to `setYieldStrategy` to fix M-06 (`dbdc3ac9`): swapping an impaired strategy in place silently re-armed the underwater-withdraw protection and concentrated the realized loss FCFS on the last withdrawer. The guard added is:

```solidity
require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");
```

The fix is incomplete. The guard is **rate-based** (it reads the strategy's NAV/accounting rate), but the actual drain it stands in front of is **execution-based** (it sells the strategy's shares through an AMM). For the production `ERC4626MarketYieldStrategy`, a strategy that is at or above par **by NAV** — so the guard passes — can realize **strictly less than principal** on the real AMM swap. The realized shortfall is never booked into `poolInfo.totalStaked`, and `withdrawDisabled` stays `false`. The exact M-06 impact class (a real `totalStaked`-vs-principal shortfall with the protection silently lifted, landing FCFS on the last withdrawer) therefore survives the story-008 fix.

### Vulnerability details

**The guard is a pure rate check.** `_isUnderwater` at [`src/StableStaker.sol#L740-L742`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L740-L742) compares two accounting reads:

```solidity
function _isUnderwater(address token, IYieldStrategy strategy) internal view returns (bool) {
    return strategy.totalBalanceOf(token, address(this)) < strategy.principalOf(token, address(this));
}
```

For `ERC4626MarketYieldStrategy`, `totalBalanceOf` resolves to `_positionValue()`, which is a pure NAV read with **no AMM execution** ([`ERC4626MarketYieldStrategy.sol#L77-L79`](https://github.com/Behodler/stable-staker/blob/master/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L77-L79)):

```solidity
function _positionValue() internal view override returns (uint256) {
    return vault.convertToAssets(vault.balanceOf(address(this)));
}
```

**The drain is execution-priced.** With the guard passed, `setYieldStrategy` drains the full position at [`src/StableStaker.sol#L239-L242`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L239-L242), routing through `_routeExit(token, staked, false)` — underwater guard turned **OFF**:

```solidity
uint256 staked = poolInfo[token].totalStaked;
if (staked > 0) {
    _routeExit(token, staked, false);
}
```

`_routeExit` ([`src/StableStaker.sol#L765-L785`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L765-L785)) calls `strategy.withdraw`, which for the market strategy runs `_disposeShares` ([`ERC4626MarketYieldStrategy.sol#L158-L180`](https://github.com/Behodler/stable-staker/blob/master/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L158-L180)). That function **sells the vault shares through the AMM at execution price**, floored only by `slippageToleranceBps`:

```solidity
uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
...
uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);
```

So the guard reads `convertToAssets` (NAV) while the drain settles at the AMM's market price. A market-priced restricted vault (the exact case `ERC4626MarketYieldStrategy` exists for — e.g. sUSDe, where market price diverges from redeem NAV) can be **at or above par by NAV** yet realize less than principal when the shares are actually sold, as long as the realized price stays within `slippageToleranceBps` so the strategy's own `minOut` floor passes.

**The shortfall is never booked, and the protection is erased.** The realized proceeds are redeposited into the new strategy, but the `deposit` return is **discarded** at [`src/StableStaker.sol#L256-L259`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L256-L259):

```solidity
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    strategy.deposit(token, idleBalance, address(this)); // return value ignored
}
```

`poolInfo.totalStaked` is never reconciled to what was actually realized and re-custodied. The post-swap state is therefore:

- `poolInfo.totalStaked` = full (unchanged), but
- the new strategy's `principalOf` = strictly **less** than `totalStaked` — a real, realized shortfall, while
- the new strategy reads "at par" by NAV, so `withdrawDisabled(token)` flips from `true` (protective, while the old strategy was on the books) to `false` (open).

This is exactly the M-06 desync: phantom full backing, real shortfall, protection silently lifted. The shortfall lands FCFS on whichever staker withdraws last — the late withdrawer's request caps to the strategy's remaining principal and is paid out short, even though `withdraw` reported the strategy as healthy and let everyone in.

### Impact

A routine, non-malicious owner `setYieldStrategy` swap on a NAV-par-but-execution-lossy market strategy:

1. passes the just-shipped story-008 underwater guard,
2. realizes a slippage-bounded principal shortfall that is **never** booked into `totalStaked`, and
3. silently lifts the underwater-withdraw protection (`withdrawDisabled` → `false`),

converting a previously *guarded* state into a *realized, non-recoverable, FCFS-concentrated* principal loss on the last withdrawer. This is the M-06 impact class surviving the M-06 fix.

This is a Law-3 **footgun**, not malicious-owner noise. A competent, non-malicious owner who just received the M-06 fix would reasonably believe the new guard makes any *non-underwater* in-place swap safe — exactly what the guard's comment and story-008 represent. The surprise is that "non-underwater by NAV" does not imply "safe to swap" for an AMM-priced strategy; the owner unknowingly realizes and socializes (FCFS) a user principal loss. Surprise ⇒ footgun ⇒ in scope.

### Why Medium (not High, not Low)

- **Below High:** no external attacker — the trigger is `onlyOwner`, and per-swap loss is bounded by `slippageToleranceBps`. There is no unbounded or attacker-amplified drain.
- **Above QA:** the loss is **realized** user principal (non-recoverable), and it **defeats a just-shipped safety guard**, re-opening a closed Medium's impact. This is "value leak with stated assumptions and external requirements" — squarely C4 Medium.

### Known-issue adjudication

This is **not** covered by the project's documented known issues:

- **KI#6** (underwater withdraw reverts; `emergencyWithdraw` / migration accept the haircut) does not bless this. KI#6 is about a strategy that *is* below par by the protocol's own underwater test and about exits that *opt into* a haircut. Here the strategy is NAV-**par** (so KI#6's own test says "not underwater"), the loss is **realized** by a routine config call, and the protection is **erased** rather than deferred — the opposite of KI#6.
- **KI#7** (replacing an in-use strategy doesn't auto-migrate; "drain it first or replace only while `totalStaked == 0`") is **superseded for the not-underwater case** by story-008's guard. story-008 deliberately enables in-place swaps of non-underwater strategies and represents them as safe — the guard's comment states "At/above par swaps are unaffected." M-07 lives precisely in the gap that guard claims to cover but does not: a strategy that is at/above par *by the guard's own rate test* yet lossy on execution.

## Proof of Concept

The PoC is built on the **real production** `ERC4626MarketYieldStrategy` and exercises its real `_disposeShares` AMM path. The only mocks are the external ERC4626 vault and the AMM adapter, modelled faithfully on the strategy's own test mocks: the vault is at par by `convertToAssets` (so the rate-based guard sees "healthy"), and the AMM sells shares at 99.5% of NAV — below par on execution but **inside** the 1% `slippageToleranceBps`, so the strategy's own `minOut` floor passes and the swap settles. This is the market-price/redeem-NAV divergence the strategy was built for, not an artificial mock contradiction.

PoC file: `workspace/stable-staker/test/PoC_A1_RateVsExecutionResidual.t.sol`

### Key excerpt

```solidity
// AMM sells shares at 99.5% of NAV: below par on execution, inside the 1% slippage floor.
// convertToAssets stays 1:1, so the rate-based guard sees "healthy".
amm.setShareToUnderlyingBps(9_950);
amm2.setShareToUnderlyingBps(9_950);

staker.setYieldStrategy(address(usdc), IYieldStrategy(address(marketStrategy)));
amm.setUnderlyingToShareBps(10_000);
amm2.setUnderlyingToShareBps(10_000);
_stake(alice, 100 ether);
_stake(bob, 100 ether);

uint256 stakedTotal = _totalStaked(); // 198 ether (conservative deposit credit; not a bug)

// GUARD CHECK: rate says HEALTHY / above par.
//   totalBalanceOf (convertToAssets) == 200, booked principal == 198  ->  _isUnderwater == FALSE.
assertGe(marketStrategy.totalBalanceOf(address(usdc), address(staker)), stakedTotal);
assertFalse(staker.withdrawDisabled(address(usdc)));

// THE SWAP: allowed by the guard, but the drain sells the shares through the AMM below par.
staker.setYieldStrategy(address(usdc), IYieldStrategy(address(newStrategy)));

// THE DESYNC: totalStaked never rewritten, new strategy booked strictly less.
uint256 newPrincipal = newStrategy.principalOf(address(usdc), address(staker));
assertEq(_totalStaked(), stakedTotal);              // phantom full backing
assertLt(newPrincipal, stakedTotal);                // real, realized shortfall
assertFalse(staker.withdrawDisabled(address(usdc))); // protection SILENTLY LIFTED
```

A second test demonstrates the downstream harm: Alice (first out) is paid near-full while Bob (last out) is paid strictly less — the loss is concentrated FCFS, not socialized.

### Forge invocation and observed output

```
$ cd workspace/stable-staker
$ forge test --match-contract A1RateVsExecutionResidualTest -vv

Ran 2 tests for test/PoC_A1_RateVsExecutionResidual.t.sol:A1RateVsExecutionResidualTest
[PASS] test_A1_atParByRate_executionLossy_bypassesM06Guard()
  totalStaked after both stakes (credited principal): 198000000000000000000
  rate-based totalBalanceOf (convertToAssets):         200000000000000000000
  booked principalOf                         :         198000000000000000000
  totalStaked (unchanged)        :                     198000000000000000000
  new strategy principal (booked) :                    195039900000000000000
  REALIZED shortfall (totalStaked - newPrincipal):       2960100000000000000
[PASS] test_A1_downstreamHarm_lastWithdrawerShorted()
  Alice paid (first out):                               98505000000000000000
  Bob   paid (last out) :                               95559700500000000000
  FCFS spread (Alice - Bob):                             2945299500000000000

Suite result: ok. 2 passed; 0 failed; 0 skipped
```

Result: a ~2.96e18 realized shortfall on a 198e18 position (~1.5%, with `slippageToleranceBps = 100`), spread FCFS so the first withdrawer (Alice) is paid ~98.5e18 and the last withdrawer (Bob) only ~95.56e18.

### Confirming this is the genuine post-fix residual

The predecessor PoC `PoC_B_SetStrategyUnderwaterSwapFootgun.t.sol` (which demonstrated the original M-06 with a *rate-underwater* strategy) now **reverts at the story-008 guard** before reaching its own assertion:

```
[FAIL: StableStaker: old strategy underwater]
  test_B_swapWhileUnderwater_erasesProtection_concentratesLossOnLateStaker()
```

This proves story-008 fixes only the rate-underwater case, while M-07 — the execution-priced residual — is a distinct, still-live finding.

**Reproduction caveat (not part of the finding):** three sibling PoCs `PoC_M02_*`, `PoC_M03_*`, `PoC_M04_*` are bit-rotted against the story-009 `MigrationInfo` 2-tuple and must be moved aside for the suite to compile when running the M-07 tests in isolation. This is a test-harness bit-rot issue, not part of this finding.

## Recommended mitigation steps

Make the guard and the booking **execution-aware** rather than rate-based. Two options, in order of preference:

1. **Reconcile `totalStaked` to the realized drain (M-06's owner-preferred mitigation).** Capture the `_routeExit` return (what the old strategy actually realized) and the new-strategy `deposit` return (what was actually re-custodied), and write `poolInfo.totalStaked` down to the credited post-deposit amount. Concretely, at [`src/StableStaker.sol#L256-L259`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L256-L259) stop discarding the `deposit` return:

   ```solidity
   uint256 idleBalance = IERC20(token).balanceOf(address(this));
   if (idleBalance > 0) {
       uint256 credited = strategy.deposit(token, idleBalance, address(this));
       poolInfo[token].totalStaked = credited; // book the REALIZED, re-custodied principal
   }
   ```

   This keeps `totalStaked` in lockstep with `principalOf` after the swap, so `withdrawDisabled` reflects the true post-swap solvency and no phantom backing survives. (Per-user `userInfo.amount` would still need a haircut policy if equal treatment is desired; if it cannot be socialized inline, the swap should be refused for AMM-priced strategies — see option 2.)

2. **Force AMM-priced wind-downs through terminal migration.** For strategies whose realization is execution-priced, do not permit an in-place `setYieldStrategy` swap at all; require the wind-down to go through `initiateMigration` → `batchMigrate`/`userMigrate` → `finalizeAndReset`, which realizes once and socializes any shortfall **pro-rata** via the immutable `(R, P)` snapshot (the same path M-01's fix established) instead of concentrating it FCFS on the last withdrawer.

Note that fixing M-06's rate-underwater case alone (story-008) does **not** close this: the guard and the drain disagree about price, so a rate-based guard can never bound an execution-priced loss.
