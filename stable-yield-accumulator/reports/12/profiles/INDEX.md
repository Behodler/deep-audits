# Contract Profiles — stable-yield-accumulator-12

Submodule HEAD: `71abe3e088559cb5d9c10e8475dc67e7cc57fac9`
Profiled: 2026-06-07

| Contract | Scope | Profile |
|---|---|---|
| `src/StableYieldAccumulator.sol` | IN-SCOPE (primary) | [StableYieldAccumulator.profile.json](./StableYieldAccumulator.profile.json) |

---

## StableYieldAccumulator

**Purpose.** Permissionless, NFT-gated yield-consolidation hub. The owner registers a dynamic
set of `IYieldStrategy` adapters, each mapped to one underlying stablecoin. An external
"claimer" calls `claim()`: for every non-exempt, non-paused registered strategy the contract
calls `skimSurplus(token, claimer)` — delivering that strategy's batched multi-client surplus
(yield) directly to the claimer — and then charges the claimer a single `rewardToken` payment
equal to the discounted, decimal-normalized sum of the skimmed yield. The payment is split
between an optional `nudge` recipient and `phlimbo` (which **pulls** its share via
`collectReward`). Exactly **one** ERC1155 NFT (index-addressed) is burned per claim. No
oracles/AMMs — cross-token value is reconciled via owner-set `decimals` + a 1:1-by-default
`normalizedExchangeRate`; the discount is the economic incentive for claimers.

**Inheritance.** `Ownable, Pausable, ReentrancyGuard, IPausable, IStableYieldAccumulator`
(Solidity `^0.8.20`, no assembly, no `unchecked`).

### Access-control map

| Role | Can call |
|---|---|
| **owner** | `setPauser`, `addYieldStrategy`, `removeYieldStrategy`, `setTokenConfig`, `pauseToken`, `unpauseToken`, `setDiscountRate`, `setPhlimbo`, `setRewardToken`, `approvePhlimbo`, `setNudgeAddress`, `setNudgeSplit`, `setNFTMinter`, `unpause` |
| **pauser** | `pause`, `unpause` |
| **anyone (NFT-gated)** | `claim` (burns 1 NFT) |
| **anyone (open)** | all views: `calculateClaimAmount`, `getYield`, `getTotalYield`, `canClaim`, `getYieldStrategies`, `getTokenConfig`, `getDiscountRate`, + auto getters |

### The one sensitive entrypoint — `claim(nftIndex, minRewardTokenSupplied, exemptStrategies[])`

`whenNotPaused` + `nonReentrant`. Ordering:
1. validate every `exemptStrategies` entry is registered (revert before NFT burn)
2. burn 1 NFT at `nftIndex` (external `INFTMinter.burn`)
3. **skim loop** — `skimSurplus(token, claimer)` per non-exempt/non-paused strategy; yield is delivered to the claimer **here**
4. price: `claimerPayment = Σnormalize(received) * (10000 - discountRate)/10000`; `actualPayment = denormalize(claimerPayment, rewardToken)`
5. slippage: revert `InsufficientYield` if `actualPayment < minRewardTokenSupplied`
6. nudge-config check: revert `NudgeNotConfigured` if `nudgeSplit>0 && nudge==0`
7. pull payment from claimer; split → `nudge` (transfer) + `phlimbo` (pull via `collectReward`)

> Note the **skims-then-pays** order (yield delivered before payment is pulled) — atomic via
> `nonReentrant`, but it contradicts the NatSpec which claims pay-then-skim (ledger **L-03**).

### Key invariants identified (checkable)

- **REGISTRY-SYNC** — `isRegisteredStrategy[s] ⇔ s ∈ yieldStrategies[] ⇔ strategyTokens[s] != 0`.
- **SPLIT-CONSERVATION** — `nudgeAmount + phlimboAmount == actualPayment` exactly (phlimbo via subtraction).
- **NO-RESIDUAL** — a successful claim leaves SYA holding no `rewardToken` (in == out), assuming a non-fee token and `collectReward` pulling exactly `phlimboAmount`.
- **NFT-COST** — exactly 1 NFT burned per *successful* claim; any revert burns nothing.
- **PAYMENT-FORMULA** / **DECIMAL-ROUNDTRIP** — `denormalize(normalize(x,t),t) <= x`; the sub-1-ulp floor is the L-01 zero-payment surface.
- **PAUSE-GATING** — claim blocked while paused; per-token paused strategies are *skipped* (M-02), not reverted.
- **Bounds** — `discountRate <= 10000`; configured `decimals <= 18`; `nudgeSplit ∈ [0,100]`.

### Verified properties

- **Checked arithmetic**: verified (0.8.20, no `unchecked`/assembly).
- **Reentrancy**: `claim` is `nonReentrant`; it is the only function with untrusted external calls.
- **Access control**: all registry/config/funding setters `onlyOwner`; `pause` `onlyPauser`; `unpause` owner-or-pauser.
- **Unbounded loops**: NOT fully clean — `claim`/`calculateClaimAmount` nest a loop over caller-supplied `exemptStrategies[]` (no length/dedup bound → caller self-grief only); `canClaim` (view) loops to `nftMinter.nextIndex()`.

### Parked for the scanners (recall over tidiness — none suppressed)

| ID | Concern | Defer to |
|---|---|---|
| PARK-01 | **Decimal/reward-token-config footgun**: unconfigured non-18-dec `rewardToken`/strategy token mis-prices claims by `10**(18-decimals)`. | econ + deployment wiring |
| PARK-02 | **Skims-then-pays + L-01**: yield delivered before payment; discounted+denormalized `actualPayment` can floor to 0 (free yield). | econ; ledger L-01/L-03 |
| PARK-03 | **Nudge misconfig bricks claims**: `setNudgeSplit(>0)` doesn't require `nudge != 0` → all claims revert until fixed. | severity-classifier |
| PARK-04 | **Phlimbo standing allowance**: `collectReward` pull; allowance depletion bricks claim. | interaction; ledger L-02 |
| PARK-05 | **Owner authority**: unbounded `normalizedExchangeRate`, 100%-discount allowed. | C-01 centralization (do NOT re-escalate per KI #4/#5) |
| PARK-06 | **Preview vs actual divergence**: previews use snapshot estimate; `claim` uses `skimSurplus` post-swap result. MEV surface. | interaction/econ |
| PARK-07 | **exemptStrategies** no dedup; NFT burned before skim loop (atomic — escape hatch for M-04). | interaction |
| PARK-08 | **`rate==0` semantics** = "no rate adjustment" (1:1), not "zero value". | QA note |

### External dependency surface (all OOS siblings — trust boundaries only)

- **`IYieldStrategy`** (vault adapters) — `skimSurplus` (delivers yield to claimer, return is authoritative for pricing), `getAuthorizedClients/totalBalanceOf/principalOf` (snapshot estimate). SYA must be an authorized withdrawer. Reverting strategy is routable via `exemptStrategies` (M-04).
- **`IPhlimbo`** (PhlimboEA/V2) — `collectReward` **pulls** the phlimbo share (needs standing allowance). PhlimboEA V1 has a known rate-recompute window-reset bug (OOS).
- **`INFTMinter`/`IERC1155`** (yield-claim-nft) — `balanceOf`/`burn` claim gate; SYA must be an authorized burner.
- **`IERC20 rewardToken`** — `safeTransferFrom/safeTransfer/forceApprove` (USDT-compatible). Assumes standard (no fee-on-transfer/rebasing).

### Ledger context (open, not re-raised here)

`L-01` zero-payment floor · `L-02` phlimbo allowance depletion · `L-03` NatSpec pay-then-skim vs code · `C-01` owner config centralization. Reconciled by sanitizer/ledger, not by this profile.
