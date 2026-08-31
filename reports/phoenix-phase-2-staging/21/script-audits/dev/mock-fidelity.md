# Mock fidelity — is `DeployMocks` a good trial run?

**Scope of the question.** Perfect mainnet fidelity is not the bar and is not expected. The bar is:
*does each mock let the key aspects be rehearsed, and what class of real bug could reach mainnet
unseen because the mock cannot express it?* Every mock is graded on **rehearsal gap**, not realism.

**Headline verdict.** The mock/real partition is well chosen. Of the ~73 contracts the script
deploys, **every Phoenix contract under audit is REAL and unmodified** — 39 first-party contracts
straight from the submodule pins, plus 9 canonical third-party contracts (WETH9 + Uniswap V2)
deployed from real creation bytecode. What is faked is exclusively the **external** surface:
tokens, ERC4626 yield vaults, the Balancer V3 stack, the Sky PSM, the Curve USDe route. That is
the right place to draw the line, and 13 of the 19 mocks are genuinely adequate.

The risk is concentrated in **three** places, and in each the simplification is not "less detail"
but **structural impossibility** — the mainnet failure mode cannot be represented at all, so no
amount of local testing can find it.

**Rehearsal-gap grades:** 🔴 structural blind spot · 🟠 real gap, bounded · 🟢 adequate

---

## Ranked: the three gaps most likely to let a real bug reach mainnet unseen

### 🔴 1. `MockMarketAMMAdapter` — the AMM price is *derived from* vault NAV, so decoupling is impossible

`src/mocks/MockMarketAMMAdapter.sol` (99 LOC). Stands in for `CurveAMMAdapter` over the Curve
Router NG USDe↔crvUSD↔sUSDe route. It is the most *fidelity-conscious* mock in the set — it routes
through the real `MockSUSDe` vault so share pricing tracks the vault at any share price, and it
skims a configurable per-leg haircut (10 bps) to simulate LP capture. Deposit leg at `:75-82`,
withdraw leg at `:83-90`, `minAmountOut` honoured at `:96`.

**What it cannot express.** `ERC4626MarketYieldStrategy` computes every slippage floor *from the
vault*: `minOut = vault.convertToShares(creditedPrincipal)` on deposit (`:139`),
`idealUnderlying = vault.convertToAssets(sharesToSell)` on withdraw (`:167, :224, :275`). The mock
then produces its output *from that same vault*, minus a constant. **The reference price and the
realized price are the same number by construction.** On mainnet they are two independent things:
Curve's USDe↔sUSDe route price versus sUSDe's internal NAV. During Ethena redemption stress sUSDe
has historically traded at a discount to NAV far exceeding the configured 30 bps tolerance.

Compounding it: **price impact is completely independent of trade size** (`:79`, `:88`). A 1-USDe
swap and a 6,000,000-USDe swap both lose exactly 10 bps. The single most size-sensitive path in the
protocol — the aggregate exit at `ERC4626MarketYieldStrategy.sol:262-281`, which deliberately
collapses N client positions into **one** `ammAdapter.swap(totalShares, …)` — is rehearsed at the
same 10 bps as a dust trade. Also absent: route failure (paused pool, insufficient liquidity,
oracle failure), MEV/sandwich (nothing can move the price between the reference read and the swap,
so `slippageToleranceBps`'s entire reason for existing is un-exercised), and leg asymmetry — the
deploy script's own comment at `DeployMocks.s.sol:449-455` records measured exit-leg losses of
**5–32 bps**, i.e. the observed worst case **already exceeds** the 30 bps tolerance it configures.

**Bug class hidden:** total deposit/withdrawal brick on the USDe strategy — every call reverting on
its `minOut` check — plus underwater principal, under exactly the market stress the tolerance
exists to survive. This is the most permissive-vs-reality mock in the set.

### 🔴 2. `MockAutoDOLA` / `MockAutoUSDC` — cannot express the Tokemak `previewRedeem` brick, the withdrawal queue, or any fee

`src/mocks/MockAutoDOLA.sol` (125 LOC), deployed **twice**: as autoDOLA over `MockDola`
(`DeployMocks.s.sol:390`) and, reusing the same contract, as autoUSDC over the 6-decimal USDC mock
(`:409`). Plain OZ ERC4626; `totalAssets()` = raw balance (`:31-33`); yield simulated by donating
assets without minting shares.

**The prior claim is confirmed, and there is more.** No deposit or withdrawal fee. No withdrawal
queue or destination-vault liquidity. No `maxRedeem`/`maxWithdraw` limiting. And critically,
**`previewRedeem` is OZ's — a pure, non-reverting, exact view, un-overridden.**

That last point is the one that matters, because it is the exact behaviour that already bricked
this project's yield-strategy-swap suite (ledger **YS-01**). Real Tokemak Autopools *mutate state
inside* `previewRedeem` and revert `StateChangeDuringStaticCall` when invoked in a static frame.
The fix landed in `_acquireShares` only — `ERC4626YieldStrategy.sol:112-115` now uses
`convertToAssets`, with an in-source comment naming Tokemak explicitly. **But the passthrough is
still live twenty lines earlier:**

```solidity
function previewRedeem(uint256 shares) external view returns (uint256 assets) {
    return vault.previewRedeem(shares);          // ERC4626YieldStrategy.sol:83-85
}
function previewDeposit(uint256 assets) external view returns (uint256 shares) {
    return vault.previewDeposit(assets);          // ERC4626YieldStrategy.sol:73-75
}
```

Because the wrapper is declared `view`, Solidity emits a **STATICCALL** — so on mainnet
`ERC4626YieldStrategy.previewRedeem(...)` against a real Autopool reverts, always, for every
caller. With `MockAutoDOLA` behind it, it returns a clean number, always. This corroborates the
ledger note that the YS-01 guard is **one-directional with residual paths surviving**. There is no
first-party on-chain caller today, so the blast radius is UI/keeper reads — but the mock guarantees
the local rig reports green forever.

Two further gaps of the same family:
- **No `maxRedeem` check before redeem.** `_disposeShares` computes `convertToShares(amount)`, caps
  to `balanceOf`, and calls `vault.redeem` (`ERC4626YieldStrategy.sol:128-135`). Against a real
  Autopool whose liquid reserve is below the request, that reverts and user withdrawals brick.
  Locally impossible.
- **The mock is MORE PERMISSIVE than reality in the exact line the code was hardened for.** OZ's
  `deposit()` computes `shares = previewDeposit(assets)` *before* calling `_deposit`;
  `MockAutoDOLA._deposit` then calls `_updateYield()` (`:41`) which mints fresh assets into the
  vault *before* `super._deposit` mints the shares (`:44`). The depositor is priced at the stale
  pre-accrual share price, so `convertToAssets(sharesReceived) > amount` — meaning
  `creditedPrincipal` at `ERC4626YieldStrategy.sol:115` **can exceed the amount actually
  deposited**, which is the precise opposite of that line's stated intent. Any local invariant
  asserting "principal is never over-credited" passes **vacuously** and would fail against a
  fee-charging vault.

**Bug class hidden:** yield-strategy view brick, withdrawal brick, and inverted principal-accounting
assertions.

### 🔴 3. `MockBalancerVault` + `MockBalancerRouter` (jointly) — no settle accounting, no invariant, and a quote identical to the realized output

`src/mocks/MockBalancerRouter.sol` is **22 lines**; the entire body sums the inputs:

```solidity
function queryAddLiquidityUnbalanced(address, uint256[] memory exactAmountsIn, address, bytes memory)
    external pure returns (uint256 bptAmountOut)
{ for (uint256 i = 0; i < exactAmountsIn.length; i++) { bptAmountOut += exactAmountsIn[i]; } }
```

The quote is **dimensionally wrong** — it returns a sUSDS token amount as a BPT amount. No rate
provider, no weights, no BPT price, no swap fee, no price impact on an unbalanced add.
`MockBalancerVault` (168 LOC) mints BPT at a flat 1:1 on the sum of inputs (`:96-107`).

Consequences, all confirmed:
- **`minBPT` can never bind.** `getIdealBPT` (`BalancerPoolerV2.sol:405-419`) passes
  `[sUSDSAmount, 0]` and gets back `sUSDSAmount`; `addLiquidity` independently returns the same
  `totalIn`. The `minBptAmountOut` revert at `MockBalancerVault.sol:106` is **unreachable in
  practice**, single-sided-add value loss is exactly **zero**, and the off-chain floor computation
  in `scripts/compute-min-bpt-poolerv2.js` is untestable. The pooler's sole MEV/slippage protection
  is structurally un-rehearsed.
- **`settle()` is a pure no-op that echoes its argument** (`MockBalancerVault.sol:120-123`). This is
  the single largest omission. Balancer V3's defining integration hazard is its transient
  debt/credit accounting — if the caller does not settle exactly, `unlock()` reverts
  `BalanceNotSettled`. **That error is structurally unreachable in this mock**, so the hardest part
  of a V3 integration, and the most common way a V3 integration bricks in production, gets zero
  rehearsal.
- **`addLiquidity` never verifies the tokens arrived** (`:99-102` reads only `params.maxAmountsIn`).
  A pooler that forgot its `safeTransfer` would still mint BPT locally.
- **The query can run in any frame.** The mock's query is `pure`; the real Balancer V3 router query
  only executes inside an `eth_call` — the project knows this (`script/InvokePoolBalancerPoolerV2.s.sol:15-17`
  calls it "the only frame Balancer V3 lets that query run in"). Any future first-party code that
  calls `getIdealBPT()` on-chain would work perfectly locally and revert on every mainnet tx.
- **The query can never revert.** The old sUSDS→waUSDC route died precisely because the real query
  reverted `MaxImbalanceRatioExceeded()` on an unseeded pool (`BalancerPoolerV2.sol:23-29`).
  Unreachable here.
- `unlock` is a bare `msg.sender.call(data)` with no reentrancy guard (`:73-80`); the real vault is
  `nonReentrant`.

**Bug class hidden:** Balancer V3 settle/debt brick, unbounded single-sided-add value loss, and an
uncalibrated or wrong-units MEV floor.

---

## The remaining sixteen

| Mock | LOC | Stands in for | Gap | Grade |
|---|---|---|---|---|
| `MockDola` | 31 | DOLA (18dp) | Unrestricted mint; real DOLA has operator-gated mint. Behaviourally identical for every path Phoenix exercises. | 🟢 |
| `MockUSDe` | 31 | Ethena USDe (18dp) | No proxy/minter role, no EIP-2612. Nothing first-party calls `permit` (verified: zero hits across `lib/*/src`). | 🟢 |
| `MockUSDS` | 31 | Sky USDS (18dp) | No `wards` auth, no permit. Pooler handling is `forceApprove` + `transferFrom` only. | 🟢 |
| `MockRewardToken` | 43 | **USDC (6dp)** | **No blocklist, no pause**, no permit, no proxy. The 6-dp decimals — the load-bearing part — are correct. | 🟠 |
| `MockWBTC` | 32 | WBTC (8dp) | No blocklist/pause. 8 decimals correct; the deploy even prices the dispatcher at `100 * 10**8`. | 🟢 |
| `MockEYE` / `MockSCX` / `MockFlax` | 35 ea | EYE / SCX / FLX + `IBurnable` | Unrestricted mint makes the burn-to-pause circuit breaker trivially armable and its cost meaningless. The burn *surface* matches what `Pauser.sol:61` / `BurnerV2.sol:37` call. Since story-070 these are swap targets on real seeded UniV2 pools, not burn targets. | 🟢 |
| `MockKendu` | 29 | Kendu Inu | Deliberately fee-free by fiat — see 🟠 note below. | 🟠 |
| `MockPhUSD` | 80 | phUSD (`FlaxToken`) | **Burn semantics diverge** — see 🟠 note below. | 🟠 |
| `MockSUSDS` | 44 | Sky sUSDS | Discrete `addYield` vs the real `chi`/`drip` accumulator. `BalancerPoolerV2` only calls `deposit`/`asset`/`balanceOf`, to which that difference is invisible. Correctly seeded 10,000 USDS to avoid the empty-vault inflation edge. | 🟢 |
| `MockSUSDe` | 44 | Ethena sUSDe | **No 7-day cooldown** — see 🟠 note below. | 🟠 |
| `MockBalancerPool` | 38 | phUSD/sUSDS BPT | No rate provider, no `getRate()`, no recovery mode. `BalancerPoolerV2` touches it only as an `IERC20`. | 🟢 |
| `MockSkyPSM` | 73 | Sky `UsdsPsmWrapper` | **The best mock in the set.** `buyGem` mirrors `DssLitePsm._buyGem` exactly, and the pooler's inverse math at `BalancerPoolerV2.sol:322/:331` round-trips against it. Reserve exhaustion IS modelled (`:64-67`), and every omitted failure mode (pause, ceiling, fee spike) lands in the same place — a revert inside `try/catch` → `DonationSkipped`, which the mock can already produce two ways. | 🟢 |
| `MockERC4626Wrapper` | 69 | waUSDC | **Dead scaffolding** — see 🟠 note below. | 🟠 |
| `MockBalancerVault.swap` / `setSwapRate` | — | Balancer V3 swap | Dead code: zero `swap(` hits in `BalancerPoolerV2.sol`. Story-034 replaced the route with the Sky PSM. | 🟠 |

### 🟠 `MockPhUSD` — the burn-path divergence

|  | mock | real `FlaxToken` |
|---|---|---|
| `burn(holder, amount)` | requires **minter authorization**, ignores allowance (`MockPhUSD.sol:57-61`) | **spends the `holder → msg.sender` ERC20 allowance**, no minter check (`FlaxToken.sol:77-83`) |
| initial `mintVersion` | `1` (`:25`) | `0` (`FlaxToken.sol:34`) |

Any Phoenix contract calling `phUSD.burn(holder, amount)` will succeed locally on its minter
authorization and **revert `ERC20InsufficientAllowance` on mainnet** unless it holds an explicit
allowance — and the mirror-image is also true. The one first-party contract that does this,
`PromotionUniV2_Eth.sol:452`, gets it right via an infinite self-allowance in its constructor
(`:218`) — but `PromotionUniV2_Eth` is **not deployed by DeployMocks**, so that correctness is the
author having read the real token, not a local-testing result. **The next dispatcher that burns
phUSD will not get it for free, and the local rig will bless it.** Also note real phUSD is already
deployed with a live `mintVersion` and an existing minter set; the port must not assume a fresh token.

### 🟠 `MockRewardToken` (USDC) — no blocklist

USDC is pushed to *user-controlled* addresses in several places: the `NudgeStreamer` settle →
`BatchNFTMinter`, Uniboost prime-token flows, PhlimboEA reward payouts, NudgeRatchet. A blocklisted
recipient makes those transfers revert on mainnet and never locally. Notably the PSM donation path
is *already* insulated (`try this._psmDonate{} catch`); the streamer-settle and Phlimbo/Uniboost
payout paths are **not**. Real-world rarity keeps this below the top three.

### 🟠 `MockKendu` — fee-free by fiat, and the probe is circular

`MockKendu`'s NatSpec (`:10-14`) states it deliberately has no transfer fee *because* `NudgeStreamer`
and `BatchNFTMinterMultiToken` assume `transfer(x)` delivers exactly `x`. The deploy script's
fee-on-transfer probe at `DeployMocks.s.sol:1661` therefore **cannot fail** — the mock guarantees
the assert it is meant to test. This was verified empirically: `test_FIND1_D` in
`test/AuditDevNudgeStreamerFoT.t.sol` shows the divergence vanishes entirely at `feeBps == 0`.
Kendu Inu is a memecoin; **verify the real token's transfer is fee-free on-chain before
`setNudgeTokenWhitelist`.** The mock cannot tell you. See finding **DEV-01** for what breaks if it
is not — the consequence is worse than the in-source comment ("the stream would run dry mid-window")
suggests.

### 🟠 `MockSUSDe` — cooldown-immunity is architectural, not accidental

Real sUSDe's `redeem`/`withdraw` **revert** whenever `cooldownDuration > 0` (which it currently is),
forcing `cooldownShares()` then `unstake()` after 7 days. The mock has no cooldown. This turns out
not to matter — every vault call in `ERC4626MarketYieldStrategy` (lines 73, 78, 139, 160-161, 167,
171, 192, 214, 224, 228, 231, 262, 270, 275, 277, 281, 333) is `balanceOf` / `convertToAssets` /
`convertToShares` / `safeIncreaseAllowance`. There is **no `vault.deposit` and no `vault.redeem`
anywhere** in the market strategy; it reaches sUSDe exclusively through `ammAdapter.swap`. That is
exactly the right architecture for a cooldown-gated vault.

**Carry this into the port as a standing constraint:** the immunity holds *only* because the market
strategy is the one wired to sUSDe. If the plain `ERC4626YieldStrategy` (which *does* call
`vault.redeem` at `:135, :165, :194, :241, :254`) is ever pointed at real sUSDe, every withdrawal
bricks — and the local rig would show it working perfectly.

### 🟠 `MockERC4626Wrapper` + `MockBalancerVault.swap` — dead scaffolding

The sUSDS→waUSDC route these serve was removed in story-034 ("structurally dead",
`BalancerPoolerV2.sol:23-29`). The wrapper has no first-party consumers, yet it is still deployed,
still pre-funded with **1,000,000 mock USDC** (`DeployMocks.s.sol:686`), and still exported to the
UI as `WaUSDC`. Its `mintShares` is unauthenticated and its `redeem` enforces no allowance, so that
1M is freely drainable on the local chain — harmless on anvil, but it is 69 lines plus a funding
step of pure noise in the address book. **Delete rather than port**, together with
`MockBalancerVault.swap`/`setSwapRate`.

---

## The `Mock` prefix strip — nothing downstream marks a mock as a mock

`server/extract-addresses.js:107`:

```js
const displayName = name.startsWith('Mock') ? name.slice(4) : name;
```

**Empirically confirmed on the live run:** `local.json`, `addresses.ts`, `local-addresses.ts` and
the `:3001` API contain **zero** keys beginning with `Mock`. All 57 served entries look like real
contract names. `MockPhUSD` → `PhUSD`, `MockKendu` → `Kendu`, `MockAutoDOLA` → `AutoDOLA`.

It hits **17 names**. Three mocks bypass it entirely because they are tracked under an
already-stripped key — `MockUSDe` as `"USDe"` (`:327`), `MockSUSDe` as `"SUSDe"` (`:333`),
`MockMarketAMMAdapter` as `"USDeAMMAdapter"` (`:446`). Functionally harmless today, but it means the
file carries **two conventions for the same job**.

**The real defect is the missing collision guard.** The strip runs *before* the
`DROPPED_CONTRACT_NAMES` check (`:110`), the UniV2-backing drop (`:116`), the V1-NFT drop (`:122`)
and the `V2`→base rename (`:137-141`); the final write at `:144` is an unguarded assignment with no
duplicate detection. No collision exists today (verified across all 99 track keys), but:

- a contract tracked as `"MockNFTMinterV2"` would become `NFTMinterV2` → hit the V2 rename → be
  written to key **`NFTMinter`**, silently clobbering the real one;
- a contract tracked as `"MockNFTMigrator"` would become `NFTMigrator` and be **silently dropped**;
- any future genuine contract whose name legitimately begins with `Mock` gets mangled.

Because the mainnet key set is hand-maintained and must mirror the generated interface exactly, a
silent overwrite there points the UI at the wrong contract with no error. **Add a duplicate-key
assertion at `:144`.**

---

## Bottom line for the user's question

**Yes, the mocking behaviour is reasonable as a trial run** — the partition (fake the external
world, run the real Phoenix code) is correct, the address pipeline is deterministic and works, and
13 of 19 mocks are adequate for what they stand in for. Two of them (`MockSkyPSM`,
`MockMarketAMMAdapter`) are unusually thoughtful.

**But the local chain is structurally incapable of rehearsing three things**, and all three are
*price/liquidity* behaviours at external boundaries:

1. AMM-price ↔ vault-NAV divergence and size-dependent slippage (USDe strategy).
2. Tokemak Autopool `previewRedeem` semantics and withdrawal-queue limits (DOLA/USDC strategies).
3. Balancer V3 settle accounting and single-sided-add value loss (index-4 pooler).

Note the pattern: **the local rig is a good functional and wiring rehearsal, and a null economic
rehearsal.** Every mock that models *price* is a constant-function stub. Treat a green `dev` run as
evidence that the graph is wired correctly and the ABIs line up — never as evidence that a swap,
a quote, a slippage floor, or a redemption will behave. For those, the mainnet-fork `PREVIEW_MODE`
run is the only surface available. The deploy ladder is anvil → mainnet by design (Sepolia retired
by owner decision, 2026-07-29 — not a gap and not a finding), so that fork run and the script's own
pre/post-condition asserts are the intended safety net rather than a substitute for a missing rung.
