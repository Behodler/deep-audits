# Contract Profile: StableYieldAccumulator

- **Contract:** `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol`
- **Interface:** `lib/stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol`
- **Submodule HEAD:** 71abe3e
- **Solidity:** `^0.8.20` (checked arithmetic outside any `unchecked` block; no `unchecked` / no assembly present)
- **Inheritance:** `Ownable`, `Pausable`, `ReentrancyGuard` (all OZ v4.8.0-743), plus implements `IPausable` and `IStableYieldAccumulator`
- **Profiled in isolation** — dependency contracts (`vault`, `phlimbo-ea`, `pauser`, `yield-claim-nft`) read only at the interface level as trust boundaries.

---

## 1. Purpose & Role

StableYieldAccumulator (SYA) is the consolidation hop in the Phoenix stable-yield path. Multiple yield
strategies each accrue surplus (yield) in their own stablecoin (USDC 6dp, DOLA/USDS 18dp, etc.). Rather
than forcing Phlimbo/Limbo stakers to manage N reward tokens, SYA lets a permissionless external actor
("claimer") atomically:

1. Pay a single `rewardToken` (e.g. USDC) into the system, and
2. Receive, in exchange, the batched surplus skimmed out of every registered yield strategy.

The claimer's incentive is a `discountRate` (bps) — they pay slightly less than the 18-decimal-normalized
value of the yield they collect, pocketing the spread as compensation for gas + conversion risk. The
`rewardToken` they pay is forwarded to Phlimbo (`collectReward`) for distribution to stakers, optionally
splitting a `nudgeSplit` percentage to a `nudge` address first. Claims are gated by burning exactly one
ERC1155 NFT from the `nftMinter`. There are **no oracles / AMMs**: cross-stable values use owner-set
`normalizedExchangeRate` (default 1:1), adjustable only for permanent depegs.

SYA itself is mostly a **router/registry**; it holds no long-lived user balances. Value passes through it
in a single `claim()` transaction (claimer -> SYA -> nudge + Phlimbo for the payment leg; strategies ->
claimer for the yield leg).

---

## 2. State Variables (with meaning / invariant)

| Var | Type | Line | Meaning / invariant |
|---|---|---|---|
| `pauser` | `address` | 70 | Authorized pauser. Starts `address(0)` (no pauser until owner sets). Satisfies `IPausable.pauser()`. |
| `rewardToken` | `address` | 76 | Single stablecoin claimers pay with; forwarded to Phlimbo. Must be set before `claim`/`approvePhlimbo`. |
| `yieldStrategies` | `address[]` | 82 | Registry of strategy addresses iterated in claim / yield calc. Owner-managed; expected small. |
| `tokenConfigs` | `mapping(address=>TokenConfig)` | 88 | Per-token `{uint8 decimals (<=18), uint256 normalizedExchangeRate (18dp), bool paused}`. Drives decimal normalization + per-token pause. |
| `discountRate` | `uint256` | 94 | Claim discount in bps, `<= 10000`. Claimer pays `yield*(10000-rate)/10000`. |
| `phlimbo` | `address` | 100 | Reward recipient (Phlimbo). Must be non-zero for `claim`. |
| `nudge` | `address` | 106 | Auxiliary recipient of `nudgeSplit`% of each payment. May be `address(0)` only while `nudgeSplit == 0`. |
| `nudgeSplit` | `uint256` | 112 | Percent `[0,100]` of payment routed to `nudge`. |
| `isRegisteredStrategy` | `mapping(address=>bool)` | 118 | O(1) membership mirror of `yieldStrategies`. INVARIANT: in sync with array. |
| `strategyTokens` | `mapping(address=>address)` | 124 | strategy -> underlying token. Set on add, `delete`d on remove. |
| `nftMinter` | `address` | 134 | ERC1155 + INFTMinter used as claim gate. SYA must be an authorized burner on it. |

**TokenConfig** struct (`IStableYieldAccumulator.sol:20`): `{ uint8 decimals; uint256 normalizedExchangeRate; bool paused; }`.

---

## 3. External / Public Functions

### Owner-gated (`onlyOwner`)
| Fn | Line | State mutated | Value flow | Notes |
|---|---|---|---|---|
| `setPauser(addr)` | 190 | `pauser` | none | may set `address(0)` to disable pausing |
| `addYieldStrategy(strategy,token)` | 227 | `yieldStrategies`,`isRegisteredStrategy`,`strategyTokens` | none | reverts on zero addr / dup. **Does NOT require a TokenConfig to exist** for `token`. |
| `removeYieldStrategy(strategy)` | 243 | same three | none | swap-and-pop O(n) loop; `delete strategyTokens` |
| `setTokenConfig(token,decimals,rate)` | 280 | `tokenConfigs[token].decimals/.normalizedExchangeRate` | none | `decimals<=18`; **does not touch `.paused`**; rate is unbounded (no upper check) |
| `pauseToken(token)` / `unpauseToken(token)` | 293 / 302 | `tokenConfigs[token].paused` | none | per-token claim gate |
| `setDiscountRate(rate)` | 324 | `discountRate` | none | `rate<=10000` |
| `setPhlimbo(addr)` | 348 | `phlimbo` | none | non-zero required |
| `setRewardToken(addr)` | 360 | `rewardToken` | none | non-zero required; **no TokenConfig requirement** for the reward token |
| `approvePhlimbo(amount)` | 369 | external allowance | `forceApprove` on rewardToken | needs phlimbo + rewardToken set |
| `setNudgeAddress(addr)` | 385 | `nudge` | none | accepts `address(0)` |
| `setNudgeSplit(split)` | 396 | `nudgeSplit` | none | `split<=100` |
| `setNFTMinter(addr)` | 414 | `nftMinter` | none | **accepts `address(0)`** (no zero check) |

### Pause control
| Fn | Line | Access | Notes |
|---|---|---|---|
| `pause()` | 204 | `onlyPauser` | `_pause()` |
| `unpause()` | 212 | owner OR pauser | Behodler3 redundancy pattern |

### Permissionless
| Fn | Line | Access | State mutated | Value flow |
|---|---|---|---|---|
| `claim(nftIndex,minRewardTokenSupplied,exemptStrategies[])` | 443 | `whenNotPaused` + `nonReentrant`; NFT-gated | burns NFT (external), no SYA storage change | claimer ERC20 in -> SYA -> `nudge`+Phlimbo; strategy surplus -> claimer |
| `calculateClaimAmount(exemptStrategies[])` | 651 | view | none | preview of payment (mirrors claim) |
| `getYield(strategy)` | 723 | view | none | native-decimal estimate for one strategy |
| `getTotalYield()` | 738 | view | none | 18dp-normalized estimate across all |
| `getYieldStrategies()` | 265 | view | none | returns array |
| `getTokenConfig(token)` | 312 | view | none | |
| `getDiscountRate()` | 336 | view | none | |
| `canClaim(caller)` | 700 | view | none | iterates `1..nftMinter.nextIndex()` checking balances |

### Internal helpers
- `_validateAndBurnNFT(caller,index)` (531): requires `nftMinter != 0` and `index > 0`; if `balanceOf(caller,index)>0` burns 1, else reverts `NoValidNFT`.
- `_getYieldForStrategy` (552), `_getNormalizedYieldForStrategy` (572): aggregate `totalBalanceOf - principalOf` over `getAuthorizedClients()`.
- `_normalizeAmount` (586) / `_denormalizeAmount` (617): decimal + exchange-rate conversion (see invariants).

---

## 4. Key Local Invariants

| # | Invariant | Status | Evidence / caveat |
|---|---|---|---|
| I1 | `isRegisteredStrategy[s]` true iff `s` in `yieldStrategies`; `strategyTokens[s]` set iff registered. | VERIFIED | add (232-234) and remove (250-257) keep all three in sync; remove `delete`s token. |
| I2 | No duplicate strategy in registry. | VERIFIED | `StrategyAlreadyRegistered` guard (230). |
| I3 | `discountRate <= 10000`; `nudgeSplit <= 100`; configured `decimals <= 18`. | VERIFIED | bounds checks at 325, 397, 282. |
| I4 | Payment split is conservative: `nudgeAmount + phlimboAmount == actualPayment` exactly. | VERIFIED | `phlimboAmount = actualPayment - nudgeAmount` (513) — subtraction-derived, no double-rounding. |
| I5 | A malformed `exemptStrategies` input reverts BEFORE the NFT is burned (NFT not consumed). | VERIFIED | validation loop 453-455 precedes `_validateAndBurnNFT` 458. |
| I6 | `claim` reverts if it would pay zero (`totalNormalizedYield == 0 => ZeroAmount`). | VERIFIED | 494. |
| I7 | If `nudgeSplit > 0` then `nudge != address(0)` at claim time, else `NudgeNotConfigured`. | VERIFIED | 506. Note: not enforced at config time (setters allow the inconsistent state); only enforced inside `claim`. |
| I8 | Reentrancy: external calls in `claim` cannot re-enter `claim`. | VERIFIED (guard present) | `nonReentrant` (447). Cross-function/cross-contract reentrancy is an INTERACTION concern (deferred). |
| I9 | Normalization round-trip: `_denormalizeAmount(_normalizeAmount(x))` ≈ x. | ASSUMED / lossy | For `decimals<18`, normalize multiplies (exact) then denormalize divides (floors) — round-trip floors. Exchange-rate path multiplies/divides by `exchangeRate` and can lose precision. Direction of loss seeds econ-scanner (see §6). |
| I10 | Decimal config consistency: `tokenConfigs[token].decimals` actually equals the ERC20's `decimals()`. | ASSUMED | SYA never reads on-chain `decimals()`; trusts owner-set value. Mismatch => systematic over/under-payment. |
| I11 | `rewardToken` has a TokenConfig matching its real decimals. | ASSUMED / NOT enforced | `setRewardToken` (360) does not require a config. With no config, `_denormalizeAmount` returns the 18dp amount unscaled (591/622 early-return), so a 6dp reward token would be mis-scaled by 1e12 unless a config is set. Sequencing dependency — flag for interaction/econ review. |
| I12 | `_normalizeAmount`/`_denormalizeAmount` early-return treats "no config" as 18dp & 1:1. | VERIFIED behavior | 591-593 / 622-624: `decimals==0 && exchangeRate==0`. Note a token deliberately at 0 decimals with 0 rate is indistinguishable from unconfigured. |
| I13 | Strategies whose token is unconfigured/paused are skipped in claim & calc. | VERIFIED | `token==address(0)` continue + `paused` continue (467-469, 662-663). |
| I14 | SYA holds no residual rewardToken after a normal claim. | VERIFIED for the modeled path | full `actualPayment` is split to nudge + Phlimbo (515-520). Holds only if `IPhlimbo.collectReward` pulls exactly `phlimboAmount` via the allowance set by `approvePhlimbo` (cross-contract; deferred). |

---

## 5. External Interface Abstractions (trust boundaries)

> Dependency contracts were NOT analyzed. The `vault` and `yield-claim-nft` interface copies are not
> checked out inside the SYA submodule (`lib/.../lib/vault` and `lib/.../lib/yield-claim-nft` contain only
> a `.git` pointer); behavior below is taken from import signatures + the nearest available interface copies.

### 5a. IYieldStrategy (each registered `strategy`) — UNTRUSTED-but-owner-allowlisted
Called in `claim` (484) and views (554-562).
- `skimSurplus(address token, address recipient) returns (uint256)` — **batch-withdraws the surplus of ALL authorized clients to `recipient` and returns underlying delivered.** Assumed: pulls strategy surplus to the claimer, leaves principal untouched, returns actual amount.
- `getAuthorizedClients() returns (address[])`, `totalBalanceOf(token,client)`, `principalOf(token,client)` — used only for view estimates.
- **Interface-version note (trust boundary, not a finding):** the only IYieldStrategy copy available in this repo (`lib/reflax-yield-vault/.../IYieldStrategy.sol:93`) declares `skimSurplus` with **no return value**, whereas SYA consumes a `uint256` return. SYA therefore links against a *different* `vault` IYieldStrategy (not checked out). Downstream scanners must use the `vault` submodule's actual `skimSurplus` signature; confirm it returns the delivered underlying.
- Trust: owner adds strategies, but `skimSurplus` is an external call to a registry-listed contract that controls (a) how much it sends the claimer and (b) whether it reverts (handled via `exemptStrategies` routing). The view-estimate (`_getYieldForStrategy`) is explicitly documented as an ESTIMATE that may diverge from delivered `skimSurplus` — slippage covered by `minRewardTokenSupplied`.

### 5b. IPhlimbo (`phlimbo`) — SEMI-TRUSTED (protocol contract)
- `collectReward(uint256 amount)` (called 519): assumed to pull `amount` of `rewardToken` from SYA via the allowance set by `approvePhlimbo`. SYA must maintain sufficient allowance or `claim` reverts. No return checked.

### 5c. INFTMinter / IERC1155 (`nftMinter`) — TRUSTED (protocol gate)
- `IERC1155.balanceOf(caller, index)` (535, 707) and `INFTMinter.burn(caller, index, 1)` (536): SYA must be an `authorizedBurner`. `nextIndex()` (705) bounds `canClaim`'s loop.
- Trust: a misbehaving minter could revert burns (DoS on claims) or mis-report balances. `setNFTMinter` allows `address(0)`; in that state `_validateAndBurnNFT` reverts (`"NFT minter not configured"`) so claims are simply disabled, not exploitable locally.

### 5d. IERC20 `rewardToken` — SEMI-TRUSTED (assumed standard stablecoin)
- `safeTransferFrom` (509), `safeTransfer` (516), `forceApprove` (373) via SafeERC20.
- Assumed standard ERC20: no fee-on-transfer, no rebasing, no ERC777-style hooks. (Project known-issues exclude weird ERC20s except USDT; USDT-style no-return-bool is handled by SafeERC20.)

### 5e. IPausable (`pauser`) — owner-set role
SYA *implements* IPausable for the Global Pauser. The Pauser would call `pause()`/`unpause()`. `unpause()` also callable by owner (redundancy).

---

## 6. Attack-Surface Notes (seeds for interaction / econ scanners)

1. **Value-moving function:** only `claim()` (443) moves tokens at runtime. It is `nonReentrant` + `whenNotPaused`, but performs multiple external calls: NFT burn (536), per-strategy `skimSurplus` to the claimer (484), then `transferFrom` claimer (509), `transfer` to nudge (516), `collectReward` to Phlimbo (519). Cross-contract reentrancy via any of these callees is an INTERACTION concern — flagged, not adjudicated here.

2. **Ordering of the yield leg vs payment leg:** `skimSurplus` (yield to claimer) executes in the loop at 484 **before** payment is pulled from the claimer at 509. The view estimate is computed pre-skim but actual delivery is the skim return value. The accounting `totalNormalizedYield` is built from the *actual* `underlyingReceived` (489) — good — but a strategy that delivers underlying then lets the claimer escape paying (e.g. via a callback during a later transfer) is the reentrancy surface to examine. `nonReentrant` blocks re-entry into `claim` itself.

3. **Decimal / rounding sites (econ-scanner):**
   - `_normalizeAmount` (586): multiply-up for `decimals<18` (exact); for `decimals>18` divides (floors, but `decimals<=18` is enforced on config so this branch is dead for configured tokens — reachable only for the unconfigured-token early return which bypasses it).
   - `_denormalizeAmount` (617): exchange-rate division then decimal down-scaling — **floors**, so `actualPayment` rounds DOWN in the claimer's favor (claimer pays slightly less). Combined with `discountRate`, examine whether dust accumulation or rounding lets a claimer extract yield while paying 0 (`actualPayment` could floor to 0 for tiny yields with high decimals/discount). `ZeroAmount` guards only `totalNormalizedYield==0`, NOT `actualPayment==0` — if `actualPayment` floors to 0, `safeTransferFrom` of 0 succeeds and claimer still receives skimmed yield. **High-value seed for econ-scanner.**
   - `claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000` (497): multiply-before-divide, fine.

4. **`rewardToken` config sequencing (I11):** if `rewardToken` has 6 decimals but no TokenConfig is set, `_denormalizeAmount` early-returns the 18dp value (no down-scale), making `actualPayment` ~1e12x too large — claimer drastically overpays / `transferFrom` likely reverts on balance. Conversely a config must be set. This is an owner-config invariant, but worth confirming deploy scripts set it; surface to interaction review.

5. **Exchange-rate is owner-controlled, unbounded above (`setTokenConfig` 280):** no upper bound on `normalizedExchangeRate`. An over-high rate inflates `totalNormalizedYield`, making claimers overpay (value to Phlimbo) — centralization/QA, not a direct steal. A near-zero (but non-zero) rate could let claimers underpay. Owner-trust boundary.

6. **DoS via strategy in claim loop:** a registered strategy whose `skimSurplus` reverts would brick `claim()` for everyone; mitigated by the `exemptStrategies` escape hatch (claimer routes around it) plus owner `removeYieldStrategy` / `pauseToken`. Loop bounds = registry size (owner-controlled, expected small) — no unbounded-loop local finding, but note `canClaim` (700) loops `1..nextIndex()` over an externally-controlled `nftMinter.nextIndex()` (view-only, off-chain bot helper — gas DoS only on eth_call).

7. **NFT gate economics:** exactly 1 NFT burned per claim regardless of total yield claimed. Whether 1 NFT's mint cost is commensurate with claimable yield (and whether a claimer can mint/burn cheaply to drain all strategy surplus at the discount) is an econ/interaction question spanning the NFTMinter — deferred.

8. **`setNFTMinter` / `setNudgeAddress` accept `address(0)`:** zero nftMinter disables claims (safe-fail). Zero nudge with nudgeSplit>0 reverts claims (I7). Neither is locally exploitable.

---

## 7. Verified-Properties Summary

- `noUnboundedLoops`: **likely** — all loops bound by owner-controlled registry size or `exemptStrategies` length; `canClaim` view loops over `nftMinter.nextIndex()` (off-chain only).
- `checkedArithmetic`: **verified** (0.8.20, no `unchecked`, no assembly).
- `reentrancyGuarded`: `["claim"]` (only state-mutating external-call fn).
- `accessControlled`: owner — all setters + strategy/token mgmt; pauser — `pause`; owner|pauser — `unpause`.
- `initializerProtected`: **n/a** — non-upgradeable, constructor-based `Ownable(msg.sender)`.
- `pauseMechanism`: present (`whenNotPaused` on `claim`; per-token pause flags).

## 8. Complexity
- LOC ~749; external/public fns 21 (3 permissionless incl. views excluded count: `claim` is the sole permissionless mutator); external call targets 4 dependency interfaces + ERC20/ERC1155; state vars 11.
