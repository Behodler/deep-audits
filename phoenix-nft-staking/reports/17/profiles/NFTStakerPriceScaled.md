# Contract Profile: NFTStakerPriceScaled

- **Contract:** `src/NFTStakerPriceScaled.sol`
- **Submodule:** `lib/phoenix-nft-staking/` @ HEAD `eee9d3a301bc0a2f9ff5557dd6b9875262152e95` (story-017)
- **Solidity:** `^0.8.20` (line 2) — checked arithmetic baseline
- **Inheritance:** `Ownable, Pausable, ReentrancyGuard, ERC1155Holder, IPausable` (line 54)
- **Scope note:** This is a HAND-MAINTAINED standalone copy of `src/NFTStaker.sol`. Per the contract's own NatSpec (lines 32-38) the ONLY intended deltas vs the audited `NFTStaker` are: the contract name, the `priceScale` immutable + its constructor guard/assignment, and the single `latestPrice = latestPrice * priceScale;` multiply in `_recomputeSchedule` (line 435). Profiling treats those as the delta surface; everything else is assumed mirror-identical to the audited original (not independently re-verified here — flagged as a maintenance-coupling trust assumption).

---

## 1. Public / External Interface

### State-mutating functions

| Function | Signature | Access | Modifiers | Purpose |
|---|---|---|---|---|
| `setPauser` | `setPauser(address newPauser)` | owner | — | Sets the address allowed to pause/unpause (lines 243-246). No zero-check. |
| `pause` | `pause()` | pauser | — | Pauses via OZ `_pause()` (lines 248-250). |
| `unpause` | `unpause()` | pauser | — | Unpauses via OZ `_unpause()` (lines 252-254). |
| `setDispatcherHook` | `setDispatcherHook(IBalancerPoolerMintDebtHook newHook)` | owner | — | Rotates the dispatcher hook supplying phUSD via `pull()`. No empty-pool guard (live op). No recompute. (lines 260-263) |
| `setStakedId` | `setStakedId(uint256 newId)` | owner | — | Changes the staked ERC1155 id; reverts unless `totalStaked == 0` (lines 265-269). |
| `setDispatcherIndex` | `setDispatcherIndex(uint256 newIndex)` | owner | — | Sets `nftMinter.configs` index; `totalStaked == 0` gated; recomputes (lines 275-280). |
| `setNFTMinter` | `setNFTMinter(INFTSupply newMinter)` | owner | — | Swaps minter ref; `totalStaked == 0` gated; non-zero; recomputes (lines 285-291). |
| `setTargetAPY` | `setTargetAPY(uint256 newAPY)` | owner | — | Sets APY (`<= MAX_TARGET_APY`); `_updatePool()` settles OLD rate first, then recompute (lines 298-304). `0` allowed (pause-by-policy). |
| `topUp` | `topUp(uint256 amount)` | owner | — | Pulls `amount` phUSD in (non-zero), `_updatePool()`, recompute; does NOT `_syncBudget` (lines 312-318). |
| `pullAndRefresh` | `pullAndRefresh()` | owner | — | Manual `_syncBudget()` (lines 321-323). |
| `stake` | `stake(uint256 amount)` | anyone | `nonReentrant whenNotPaused` | Deposit ERC1155 units; head `_syncBudget`, pay pending, mutate, tail recompute (lines 470-495). |
| `unstake` | `unstake(uint256 amount)` | anyone | `nonReentrant whenNotPaused` | Withdraw units; pay pending; tail recompute (lines 497-516). |
| `claim` | `claim()` | anyone | `nonReentrant whenNotPaused` | Pay pending rewards only; no tail recompute (lines 518-527). |
| `emergencyWithdraw` | `emergencyWithdraw()` | anyone | `nonReentrant` | Escape hatch: full principal out, forfeits pending; NO `_syncBudget`/`_updatePool`; callable while paused (lines 577-600). |

### Internal functions
- `_syncBudget()` (333-346): `_updatePool` then `pull()` (if hook set) then recompute; emits `Pulled` on positive inflow.
- `_updatePool()` (354-370): settles accrual to `min(now, windowEnd)`, clamps to `rewardBudget`, bakes into `accRewardPerShare`.
- `_recomputeSchedule()` (420-464): the analysis target — see §3.
- `_safePay(uint256)` (548-560): transfers reward, decrements `committedDebt`/`rewardBudget`; reverts on balance shortfall.

### View functions

| Function | Signature | Purpose |
|---|---|---|
| `pendingReward` | `pendingReward(address account) returns (uint256)` | Forward-simulated unpaid reward for `account` (lines 606-617). |
| `currentRewardRate` | `currentRewardRate() returns (uint256)` | `rewardRate`, or 0 if `now >= windowEnd` (lines 621-624). |
| `totalDebt` | `totalDebt() returns (uint256)` | `committedDebt` + in-flight accrual (lines 633-642). |
| `totalBudget` | `totalBudget() returns (uint256)` | balance + pending `mintDebt` (lines 646-649). |
| `runwaySeconds` | `runwaySeconds() returns (uint256)` | `(balance + mintDebt) / rewardRate`, 0 if rate 0 (lines 655-659). |
| public getters | auto | `stakedToken`, `rewardToken`, `priceScale`, `stakedId`, `dispatcherHook`, `pauser`, `nftMinter`, `dispatcherIndex`, `targetAPY`, `windowEnd`, `rewardRate`, `rewardBudget`, `committedDebt`, `lastRewardTime`, `totalStaked`, `accRewardPerShare`, `users`, constants. |

---

## 2. State Variables

### Constants (lines 62-79)
- `ACC_PRECISION = 1e18`
- `SECONDS_PER_YEAR = 365 days`
- `APY_PRECISION = 1e18`
- `MAX_TARGET_APY = 50 * 1e16` (0.5e18 = 50%)

### Immutable config (lines 85-94)
- `IERC1155 stakedToken` — ERC1155 collection.
- `IERC20 rewardToken` — phUSD.
- **`uint256 priceScale` (line 94) — THE DELTA.**
  - **Immutable:** yes (`public immutable`).
  - **Set in constructor:** yes, line 236 (`priceScale = _priceScale;`).
  - **Validated:** yes — `require(_priceScale != 0, "NFTStaker: zero price scale")` at line 230. Only a **non-zero** check; NO upper bound is enforced. Intended values: `1` (18dp→18dp, reproduces `NFTStaker`) or `1e12` (6dp USDC→18dp phUSD) per lines 88-93.

### Mutable owner-controlled config (lines 100-126)
- `uint256 stakedId` (102) — active ERC1155 id; changeable only when `totalStaked == 0`.
- `IBalancerPoolerMintDebtHook dispatcherHook` (105) — set post-deploy; may be zero (treated as pure-recompute mode).
- `address pauser` (108).
- `INFTSupply nftMinter` (114) — supply/config reads.
- `uint256 dispatcherIndex` (119) — index into `nftMinter.configs`.
- `uint256 targetAPY` (126) — 1e18-scaled, bounded by `MAX_TARGET_APY`.

### Schedule state (lines 134-155)
- `uint256 windowEnd` (134) — derived depletion timestamp.
- `uint256 rewardRate` (140) — per-second phUSD emissions.
- `uint256 rewardBudget` (146) — `V - committedDebt` at last recompute.
- `uint256 committedDebt` (155) — baked-but-unpaid emissions; backbone of the solvency invariant.

### Accrual state (lines 161-170)
- `uint256 lastRewardTime`, `uint256 totalStaked`, `uint256 accRewardPerShare`.
- `struct UserInfo { uint256 amount; uint256 rewardDebt; }`; `mapping(address => UserInfo) users`.

---

## 3. `_recomputeSchedule` Analysis

### Full body (verbatim, lines 420-464)

```solidity
function _recomputeSchedule() internal {
    (, uint256 price, uint256 growthBasisPoints,) = nftMinter.configs(dispatcherIndex);

    uint256 latestPrice;
    if (price == 0) {
        latestPrice = 0;
    } else if (growthBasisPoints == 0) {
        latestPrice = price;
    } else {
        uint256 r = APY_PRECISION + growthBasisPoints * 1e14;
        latestPrice = price.mulDiv(APY_PRECISION, r);
    }

    // Normalize the dispatcher price (prime-token decimals) into reward-token (phUSD) units.
    // priceScale == 1 reproduces the original NFTStaker exactly; 1e12 for a 6dp USDC-priced dispatcher.
    latestPrice = latestPrice * priceScale;

    // M-03: size the rate against the staked subset, not the aggregate
    // notional of all minted NFTs. Bare multiplication is exact and
    // cheaper than a mulDiv; the bound argument lives in the NatSpec.
    uint256 S = (totalStaked == 0 || latestPrice == 0) ? 0 : totalStaked * latestPrice;

    uint256 V = rewardToken.balanceOf(address(this));
    if (address(dispatcherHook) != address(0)) {
        V += dispatcherHook.mintDebt();
    }

    // Strip already-committed accrual from V before sizing the next
    // budget. This is the M-01 fix: re-using V here over-promised by
    // the amount `_updatePool` had just moved into `accRewardPerShare`,
    // DoSing late claimers via `_safePay` shortfalls. Clamp at zero to
    // keep recompute non-reverting if hook misbehaviour ever drives V
    // below committedDebt (principal escape via emergencyWithdraw).
    uint256 budget = V > committedDebt ? V - committedDebt : 0;

    uint256 F = S.mulDiv(targetAPY, APY_PRECISION);
    uint256 newRate = (F == 0) ? 0 : F / SECONDS_PER_YEAR;
    uint256 runway = (newRate == 0) ? 0 : budget / newRate;

    rewardRate = newRate;
    rewardBudget = budget;
    windowEnd = block.timestamp + runway;

    emit ScheduleRecomputed(S, budget, newRate, windowEnd);
}
```

### Where / how `priceScale` enters

1. **Raw price read** (line 421): `(, price, growthBasisPoints,) = nftMinter.configs(dispatcherIndex)`. All `uint256` (per `INFTSupply.configs`, lines 34-37 of `INFTSupply.sol`); `price` is the NEXT mint price in **prime-token decimals** (e.g. 6dp for USDC).
2. **Most-recent-price recovery** (lines 423-431):
   - `price == 0` → `latestPrice = 0`.
   - `growthBasisPoints == 0` → `latestPrice = price` (no geometric scaling).
   - else: `r = 1e18 + growthBasisPoints * 1e14` (i.e. `1 + growthBasisPoints/10_000` in 1e18 fp), and `latestPrice = price.mulDiv(1e18, r)` — **floor division** (OZ `Math.mulDiv`). This is the only `mulDiv` on the price path.
3. **THE DELTA — decimal normalization** (line 435): `latestPrice = latestPrice * priceScale;`
   - Plain checked `uint256 * uint256` multiply (NOT `mulDiv`, no rounding — exact).
   - Applied AFTER the `mulDiv(1e18, r)` floor, so it scales the already-floored most-recent price into phUSD (18dp) units.
   - With `priceScale == 1` this is a no-op and the contract reproduces `NFTStaker` exactly.

### Multiplication / division order & rounding (floor) sites
1. `latestPrice = price.mulDiv(1e18, r)` (430) — **floor** (only when `growthBasisPoints != 0`).
2. `latestPrice * priceScale` (435) — exact multiply, no rounding.
3. `S = totalStaked * latestPrice` (440) — exact multiply, no rounding.
4. `F = S.mulDiv(targetAPY, 1e18)` (455) — **floor**.
5. `newRate = F / SECONDS_PER_YEAR` (456) — **floor**.
6. `runway = budget / newRate` (457) — **floor**.

Every rounding site floors, each shaving at most ~1 wei in the **protocol's favour** (under-promise on rate/runway). This is the intended conservative-for-protocol direction; the NatSpec (lines 413-419) explicitly forbids flipping any site to ceiling. `priceScale` being applied as an exact multiply does not introduce a new rounding bias.

### Overflow surface

All arithmetic is `^0.8.20` checked (reverts on overflow); `Math.mulDiv` is full-precision-intermediate (no intermediate cast overflow on the `mulDiv` sites themselves). The exposed surfaces are the **bare multiplies** at lines 435 and 440, plus the `growthBasisPoints * 1e14` at 429.

Max plausible magnitudes (NatSpec bound argument, lines 407-411):
- `latestPrice` before scaling: wei-scaled mint price, ~`1e21` typical, conservatively bounded well under ~`1e24`.
- `priceScale`: intended `1e12` (max sane value); no upper bound enforced in constructor.
- **`latestPrice * priceScale` (435):** `~1e21..1e24 * 1e12 = ~1e33..1e36`. `2^256 ≈ 1.16e77`. Comfortably safe for intended scales.
- `totalStaked`: bounded by realistic ERC1155 supply, NatSpec assumes `<= 1e6`.
- **`S = totalStaked * latestPrice` (440):** `~1e6 * 1e36 = ~1e42`, still << `2^256`.
- `F = S.mulDiv(targetAPY, 1e18)`: `targetAPY <= 0.5e18`, `mulDiv` handles 512-bit intermediate; `F ~ 1e42 * 0.5 = ~5e41`, fine.

**Overflow assessment:** No realistic overflow for intended `priceScale` (1 or 1e12) and realistic supply/price. Note the bound argument is the *original* NatSpec's; the `priceScale` multiply pushes the effective `latestPrice` magnitude up by `priceScale`. Because `priceScale` has **no constructor upper bound** (only `!= 0`), the overflow safety rests entirely on operator discipline supplying a sane scale. An absurd `priceScale` (e.g. `>~1e40`) combined with a large price/supply could in principle drive line 435 or 440 to revert — but that is a checked revert (DoS of recompute / griefing the deployment), not silent wraparound, and is an obvious owner misconfiguration (Law 3 — set at deploy time, immutable, instantly observable). This is noted as a trust assumption rather than a local finding. The intended decimal-correctness (`priceScale = 10**(rewardDecimals - priceDecimals)`) must be supplied correctly: a wrong scale silently mis-sizes the emission rate (decimal-mismatch class, the very failure this contract exists to fix in the other direction) — this is a config-correctness trust boundary for downstream/interaction analysis, not a contract-local bug.

---

## 4. Key Invariants the Contract Relies On

1. **Solvency (always): `balance == rewardBudget + committedDebt`.** Maintained across `_updatePool` (rewardBudget→committedDebt move, line 365-366), `_safePay` (decrements both sides by `amount`, lines 552-557), `_recomputeSchedule` (resizes `rewardBudget = V - committedDebt`, line 453+460), `topUp` (balance and rewardBudget rise equally), `emergencyWithdraw` (forfeit moved committedDebt→rewardBudget, lines 595-596). `priceScale` does not touch this accounting — it only affects `S`/`rewardRate`/`runway`, i.e. the *speed* of emission, never the budget ledger. So the solvency invariant is structurally insensitive to the delta.
2. **Single active token id per staker.** Only `stakedId` is staked; mutable only while `totalStaked == 0` (line 266). No per-id mapping → no cross-id leakage.
3. **Emission stops cleanly at `windowEnd`.** `_updatePool` caps `end = min(now, windowEnd)` (line 360) and clamps `reward` to `rewardBudget` (line 363). `priceScale` enlarges `rewardRate`, which shortens `runway = budget / newRate` (line 457) so `windowEnd` lands sooner — the clamp still holds; budget can never be over-drawn.
4. **Floor rounding is conservative-for-protocol.** All six rounding sites (§3) floor, under-promising rate and runway. `priceScale` is an exact multiply and preserves this bias.
5. **APY-as-floor for latest minter / no participation multiplier (M-03).** `S = totalStaked * latestPrice` sizes the rate against the staked subset; `priceScale` scales `latestPrice` uniformly so per-NFT APY semantics are unchanged (only the decimal basis is corrected). The latest minter earns exactly `targetAPY`; earlier minters earn more.
6. **`rewardRate` depends only on on-chain state, not inflow cadence.** `R = S * A / SECONDS_PER_YEAR`; `priceScale` is immutable so repeated pulls/top-ups with unchanged `totalStaked`/price/`A` leave `R` fixed (APY-stability invariant) — the delta does not break it.
7. **Principal never trapped.** `emergencyWithdraw` skips `_syncBudget`/`_updatePool`/recompute and is paused-callable; it never reads `priceScale`, so even a recompute-breaking scale cannot strand principal.

---

## 5. Constructor (lines 218-237)

```solidity
constructor(
    IERC1155 _stakedToken,
    uint256 _stakedId,
    IERC20 _rewardToken,
    address _initialOwner,
    INFTSupply _nftMinter,
    uint256 _dispatcherIndex,
    uint256 _priceScale
) Ownable(_initialOwner) {
    require(address(_stakedToken) != address(0), "NFTStaker: zero staked token");
    require(address(_rewardToken) != address(0), "NFTStaker: zero reward token");
    require(address(_nftMinter) != address(0), "NFTStaker: zero nft minter");
    require(_priceScale != 0, "NFTStaker: zero price scale");
    stakedToken = _stakedToken;
    stakedId = _stakedId;
    rewardToken = _rewardToken;
    nftMinter = _nftMinter;
    dispatcherIndex = _dispatcherIndex;
    priceScale = _priceScale;
}
```

- **Parameters:** `_stakedToken`, `_stakedId`, `_rewardToken`, `_initialOwner`, `_nftMinter`, `_dispatcherIndex`, `_priceScale`.
- **`priceScale` supply/validation:** passed as `_priceScale` (line 225), guarded by `require(_priceScale != 0, ...)` (line 230), assigned to the immutable at line 236. **Only a non-zero check** — no upper-bound, no decimal-consistency check (the contract cannot know the prime/reward decimals to verify `priceScale == 10**(rewardDecimals - priceDecimals)`).
- **Not validated:** `_stakedId` (any), `_dispatcherIndex` (any — could index a non-existent/disabled config; recompute would read garbage/revert at use, not construction), `_initialOwner` (OZ `Ownable` reverts on zero), `priceScale` upper bound, decimal-correctness.
- **Not set in constructor (post-deploy setters):** `dispatcherHook`, `pauser`, `targetAPY` (defaults 0 → emissions off until set). The pool is inert until the owner configures hook/pauser/APY.

---

## Verified Properties Summary

- **Solidity:** `^0.8.20`, checked arithmetic — `verified`.
- **No unbounded loops:** no loops anywhere in the contract — `verified`.
- **Reentrancy guards:** `stake`, `unstake`, `claim`, `emergencyWithdraw` all `nonReentrant` — `verified`. (External calls: ERC1155 transfers, ERC20 transfers, `dispatcherHook.pull()`.)
- **Access control:** owner setters and pauser functions guarded — `verified`. `setPauser` has no zero-address check (`likely`-minor, not a local finding — owner-set, observable).
- **Initializer protection:** N/A (immutable constructor pattern, not upgradeable).
- **`priceScale` validation:** non-zero only; **no upper bound, no decimal-consistency check** — `verified` (as a footgun/trust boundary, not a local exploit).
- **Overflow on the delta multiply (line 435) / `S` (line 440):** safe for intended `priceScale ∈ {1, 1e12}` and realistic supply/price; checked-revert (not silent wrap) on absurd config — `verified`.

## Trust Assumptions (defer to interaction/econ analysis)
1. **Maintenance coupling:** mirror-fidelity to the audited `NFTStaker` for all non-delta code is assumed, not re-verified here (NatSpec lines 32-38).
2. **`priceScale` decimal-correctness:** operator must supply `10**(rewardDecimals - priceDecimals)`. A wrong scale silently mis-sizes emissions (over- or under-paying APY). Config-correctness boundary.
3. **`nftMinter.configs(dispatcherIndex)`** returns a sane `(price, growthBasisPoints)` for a real/enabled dispatcher (untrusted-sibling read).
4. **`dispatcherHook.pull()` / `mintDebt()`** behave (sibling `yield-claim-nft` boundary) — interaction-level concern (reentrancy guarded locally).
5. **`rewardToken` is well-behaved phUSD** (no fee-on-transfer / no hooks) — standard project assumption.
