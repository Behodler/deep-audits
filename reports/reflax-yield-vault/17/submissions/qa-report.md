# QA Report — reflax-yield-vault (run reflax-yield-vault-17)

- **Project**: reflax-yield-vault · **Branch**: `master` · **Commit**: `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` `[story-050] previewExitFor on IYieldStrategy`
- **Baseline**: `0110ce44e1b9da0944595765eb0ae12affc50d7e` (`branchBaselines.master`, run-16) · regression scan, diff additive (`+171` lines over 4 `src/` files)
- **Repo**: https://github.com/Behodler/reflax-yield-vault

## Summary

| | New this run | Open carryover |
|---|---|---|
| High | **0** | 0 |
| Medium | **0** | 0 |
| Low | **12** (`L-18`–`L-29`) | 26 |
| QA / Informational | **3 QA** (`QA-10`–`QA-12`) + **1 Info** (`INFO-01`) | 10 |
| Centralization | 0 | 1 (`C-01`) |
| Faithfulness (Law 2) | 4 channels (`F-17-01`–`F-17-04`) — see `spec-conformance.md` | 6 |

**0 suppressed · 0 regressions · all 16 findings NEW.** No status change is proposed this run and none was written.

**The aggregate risk is the headline, not any single label.** `WATCH-17-03` — a `stable-staker` submodule bump to a
story-050 commit — escalates **five** findings (`L-18`, `L-19`, `L-20`, `L-21`, `L-22`) to Medium **simultaneously**,
and coincides with the existing Medium re-evaluation gates on `F-03` / `52f9b84a54ec9a65` and `F-16-003` /
`c705bd94ec78fd23`. That is a single event converting a clean Low run into a five-Medium run **with no scanner
signal in between**. Handle it in one pass.

### The classification axis, stated once

`previewExitFor` has **zero consumers** at every sibling repo's current top-level HEAD — verified **three times
independently and untruncated** (dedup, symbolic pass, severity audit; `antimatter 0, phlimbo-ea 0,
phoenix-nft-staking 0, phoenix-phase-2-staging 0, stable-staker 0, stable-yield-accumulator 0, yield-claim-nft 0,
reflax-yield-vault 32`). Every finding was tested against one question: **does the harm land on the live execution
path today, or does it require a consumer of the new view?** View-only harm ⇒ Low with a *named escalation trigger*
rather than a hedged label; execution-path harm judged on its own merits. This is **not** the C4 "speculation on
future code" invalid category — that requires an *undemonstrated* root cause, and every root cause here is
demonstrated in code with a passing PoC. Only the consumer is future.

**Every Low in this run is backed by a measurement or a source read rather than an unasked question.** Four of the
five questions the classification left open were closed by the severity audit (on-chain measurement at block
25878009, a mainnet broadcast read, and two source reads); the fifth (`MR-17-04`) is a registration task.

---

## Low Risk Findings

### [L-18] Base `previewExitFor`'s `netGuaranteed` is a ceiling, not a floor, when the share-balance cap binds <!-- id: ryv17l18 -->

**Fingerprint:** `5351fd4d3f8cf3cf93a002233d55d7cde970b1422aeaa42eb9a99deb19f37630` · **Law 2:** also `F-17-01`

**Location:** [`src/AYieldStrategy.sol#L571-L583`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/AYieldStrategy.sol#L571-L583) — `previewExitFor`, reached in production through `ERC4626YieldStrategy`

**Description:** The base default computes `grossToRequest = min(netWanted, clientBalances[token][account])` and sets `netGuaranteed = grossToRequest` — it quotes **booked principal** and does not model the vault share balance at all. On a below-par position the published "guarantee" is therefore a **ceiling** on what can be delivered rather than a floor beneath it.

**Impact:** The direct strategy's published exit floor over-states deliverable underlying by the full vault deficit: **`1000e18` quoted, `500e18` delivered** after a 50% drawdown, on a function whose NatSpec uses the word "guarantees". `withdraw()` then debits the full requested amount at `AYieldStrategy.sol:781-783`. No revert, no event.

**Why Low.** No consumer exists. `StableStakerV2._isUnderwater` **strictly dominates** the cap-binding condition on the armed `withdraw()` path — 696 M-state exhaustive integer search over the live semantics (210 M cap-binding states, 0 counterexamples), 150 k fuzz + a 105-case grid against the real contracts in the real two-client topology, with live vacuity tripwires (one fired and caught a vacuous first harness). **This is not a Halmos proof — the symbolic tier returned 0 `[PASS]` / 7 `[TIMEOUT]`. Never write "symbolically verified".**

> **⚠ The dominance is contingent and the contingency is unguarded (`MR-17-05`).** It rests on two invariants — `p ≤ D` (`AYieldStrategy.sol:48`, `totalDeposited == Σ clientBalances`) and `a ≤ p` (`:772-776`, the withdraw amount capped to available principal). **Neither is pinned by any test.** A future change breaking either re-arms this at **Medium with no scanner signal**. `DominanceRun17Grounding.t.sol` is the runnable regression guard and **should be kept**.

**Escalation trigger:** (a) `WATCH-17-03`; **or** (b) either dominance invariant ceasing to hold. Either ⇒ **Medium**.

**Recommendation:** Model the share balance in the base preview as the market override's `_exitFloor` does, or strike "guarantees" from the NatSpec. **NON-COLLAPSE, load-bearing:** a fix that merely copies `_exitFloor` into the base closes this finding and **spreads `L-20` to the direct strategy**. Fix them together.

**PoC:** `poc-run17-econ-exit-preview.t.sol::testE2_SingleClientQuoteIsFalseByTheFullDeficit` (PASS)

---

### [L-19] Both exit previews are built on the fee-free `convertToAssets`, so the published guarantee is breached on every exit from a fee-charging vault <!-- id: ryv17l19 -->

**Fingerprint:** `302656e234435430ebec32c9924e8626c03f6ab765bf0174729e8228d2322458` · **Law 2:** also `F-17-02`

**Location:** [`src/AYieldStrategy.sol#L571-L583`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/AYieldStrategy.sol#L571-L583) + [`ERC4626MarketYieldStrategy.sol#L127-L137`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L127-L137) `_exitFloor` (`convertToAssets` at `:133`)

**Description:** Both previews derive `netGuaranteed` from `vault.convertToAssets`. EIP-4626 requires `previewRedeem` to express redemption fees and `convertToAssets` to ignore them, so the quote systematically over-states what `redeem()` delivers. `ERC4626YieldStrategy` **already exposes** the fee-aware quote at `:83-85`; story-050 criterion 10 deliberately forbade `previewExitFor` from using it, so the contract now ships **two exit previews that disagree by the vault's exit fee, with the newer one carrying the word "guarantees"**.

**Impact:** The census fires on **203 of 203** executed direct exits. Measured on chain rather than assumed — **block 25878009**, against each deployed strategy's own `vault()`:

| Autopool | `convertToAssets` | `previewRedeem` | Divergence |
|---|---|---|---|
| autoDOLA `0x79eB84B5…` (DOLA) | `1000000014462599280` | `999952721565253485` | `47292897345795` → **0.004729%** |
| autoUSD `0xa7569A44…` (USDC) | `999999` | `999946` | `53` → **0.005300%** |

Divergence is **non-zero on both live Autopools and in the harmful direction** (`convertToAssets` over-states what `redeem` delivers). At **~0.5 bps** on a quote no code reads, that is far below the Medium value-leak limb; the finding rests at Low on its **spec-deviation** weight.

> **⚠ Escalation trigger CORRECTED — the original would manufacture a false Medium.** The classifier wrote *"any non-zero divergence ⇒ Medium immediately"*. Divergence **is** already non-zero (0.0047% / 0.0053%), so as written that trigger is mechanically satisfied at the next triage and would produce a Medium on 0.5 bps. **Replaced with a magnitude threshold:** divergence on a wired Autopool **≥ 10 bps**, or any step change in Tokemak's fee parameters ⇒ re-weigh to Medium.

**`F-16-003`'s gate is TRIPPED this run and now ADJUDICATED.** `ECON-A`'s stale Low is **not** inherited; the re-weigh lands on Low **with a measurement behind it**. A tripped gate left un-adjudicated is how a stale Low survives another run.

**Recommendation:** Read a fee-aware quote (`previewRedeem`, or subtract the measured delta). **`F-01-050`'s proposed remedy — cap by `_positionValue()` — does not work:** `assertEq(posValue, net)` passes because `_positionValue` is built on the same fee-blind conversion (`ERC4626YieldStrategy.sol:61-63`), so it is **numerically identical to the number it was meant to correct**.

**Re-file disclosure:** `ECON-A` / `c50c08f9ee587c02…` (Low, open) and `F-16-003` / `c705bd94ec78fd23…` (faithfulness, open) — same primitive (fee-blind `convertToAssets`), **different function, different claim, different consequence**: `ECON-A` is deposit-side crediting on `_acquireShares`; this is an exit-side **published delivery guarantee** on a function that did not exist at `ECON-A`'s commit. Filed as a new entry **cross-linked** to both, **not merged** into `ECON-A`. Both are `open`, not `acknowledged` — neither carries suppression authority in any case. Adjacent open: `L-11` / `abd28a2f46c12893`, `L-09` / `c6ec246f7e58dd29`.

**PoC:** `RealisticExitPreviewPoc.t.sol::testPoc_INV1_direct_exitFeeBreachesFloor` (PASS); `poc-run17-pattern-match.t.sol::testPM3_DirectPreviewOverQuotesOnExitFeeVault` (PASS)

---

### [L-20] Per-account `netGuaranteed` is floored against the GLOBAL share balance, so N clients are each quoted a floor only one can be paid <!-- id: ryv17l20 -->

**Fingerprint:** `6f57473e6b01a4d9428a6e60d99558c7331741a2dcb28c46cea527f72ccf7030`

**Location:** [`ERC4626MarketYieldStrategy.sol#L127-L186`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L127-L186) `_exitFloor` (`:130`); same shape in the base at `AYieldStrategy.sol:583`

**Description:** `grossToRequest` is capped **per account** (against `clientBalances`) but `netGuaranteed` is floored against the strategy's **global** vault share balance. The shared, unreserved position is quoted in full to every client independently.

**Impact:** PoC: two `980.1e18` floors against a `1000e18` position (Σ = **1.96×**); the second client receives `20e18` — 2.0% of its quote — and is debited its **full** `990e18` via the protocol-favouring write-down at `AYieldStrategy.sol:781-783`. Three-client run: Σ `netGuaranteed` `30,000e18` vs realizable `26,730e18` (**+12.2%**), and **not** an artifact of the mock's redemption throttle (`v2_shortfallUnthrottled` 387 direct / 108 market).

**What is filed vs what is suppressed.** Filed: the **over-issued guarantee** — a view that legitimises an FCFS drain by telling each client it will be paid. Suppressed: the standalone client-vs-client **value transfer**, under the minter-cushion memo (`PhusdStableMinter` has no strategy-withdraw path and cannot race). **No per-client cap is recommended** — the commingled cap is by design. Scope accepted exactly as dedup framed it and **not widened**.

> **Reopen trigger `WATCH-17-E2` (`MR-17-06`):** **any** future story giving `PhusdStableMinter` a strategy-exit path kills the suppression premise and makes this a **live Medium immediately**. Because the trigger lives in *another repo's stories*, **no scanner in this project will fire on it.** This must survive triage.

**Recommendation:** Apportion the shared cap pro-rata, or state in the NatSpec that the floor is **non-exclusive** and holds only for the first exiter in a block.

**Re-file disclosure:** `M-03` / `3c8331040bba6a7b…` (Medium, **`merged`** into `M-02`), whose merge note explicitly says *"Fingerprint retained so a future standalone recurrence can still be matched."* Same shape, **different primitive**: `M-03`'s deficit is AMM slippage bounded by `slippageToleranceBps × tradeSize` with a `minOut` revert; the direct leg here is an **unbounded vault drawdown** and `vault.redeem` carries **no `minOut` at all**. **`M-03` stays `merged`** — human-set, untouched. `M-01-run12` / `fdda8f53151ab76e` (`false-positive`) is **not** re-escalated and **not** cited as support.

**PoC:** `testH5_TwoClientsQuotedTheSameShares`, `testE1_FirstComeFirstServedAcrossClients`, `testPoc_INV2_direct_aggregateQuotesExceedCapacity` (all PASS)

---

### [L-21] `netGuaranteed > 0` is a false green: three independent reasons `withdraw` is not executable <!-- id: ryv17l21 -->

**Fingerprint:** `833f7f6c728a8ac47cedeaf1b6d3a3aa7676e00c532d15c2ad6c47160e639bf0`

**Location:** [`ERC4626MarketYieldStrategy.sol#L162-L186`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L162-L186) `previewExitFor`; `ERC4626YieldStrategy.sol:126-138` `_disposeShares` under the inherited base preview

**Impact:** The **entire** `withdraw` / `withdrawAsOwner` / `totalWithdrawal` path of the market strategy is bricked for **every** client while the condition holds (`_disposeShares` is the single shared exit hook) — while the new preview reports green. `INV-3` is the **dominant** failure mode on both strategies (`v3_nonZeroQuoteRevert` 127 direct / 90 market). Before `cdd0743` there was no pre-flight signal and a consumer had to try-and-revert; now there is one, documented with the word "guarantees", and **it is always green in exactly the state where the call is guaranteed to fail**.

**Instances — enumerated because each needs a DIFFERENT code change. A fix landing only one is an INCOMPLETE FIX, not a fix:**

| # | Mechanism | Sub-remedy | Severity disposition |
|---|---|---|---|
| **(a)** | **AMM price blindness (market).** `IAMMAdapter` has one member, a non-view `swap`; `CurveAMMAdapter` exposes no quote. `_exitFloor` is **provably invariant to AMM price**, and `_disposeShares` passes that same number as `minOut` (`:246`), so the router reverts. | Add a **size-aware** quote member to `IAMMAdapter` (wrap `ICurveRouterNG.get_dy`) and return `netGuaranteed = 0` when the live route cannot clear `minOut` | The revert is a `minOut` slippage guard **doing its job** — refusing to sell into a 10% discount is correct. Transient, self-clearing, owner lever exists. **Not Medium.** |
| **(b)** | **Vault redemption throttle (direct).** Zero occurrences of `maxRedeem`/`maxWithdraw` in first-party `src/`; `_disposeShares` calls `vault.redeem` unconditionally. `r_redeemThrottleBind` 127/66. | Consult `maxRedeem`/`maxWithdraw` in both the preview and `_disposeShares` | The genuine Medium candidate — not a guard functioning but an **unhandled external precondition**. **MEASURED NEGATIVE** on live state (below). |
| **(c)** | **Finite AMM depth (market).** The depth-blind floor breaches `minOut` at an **unmoved mid-price**: gross `19,800e18`, quoted `19,602e18`, AMM would pay `14,882.7e18`. | The (a) quote member, **provided it is size-aware** (`get_dy(amountIn)`, not a mid-price) | Same as (a). |

**Trigger (b) measured at block 25878009 — NEGATIVE:**

| Wired strategy | Vault | `balanceOf` | `maxRedeem` | Binds? |
|---|---|---|---|---|
| `YieldStrategyDola 0x1760E053…` | Tokemak autoDOLA `0x79eB84B5…` | `13357.32e18` | `13357.32e18` | **No — 100.0000%** |
| `YieldStrategyUSDC 0xaFDf8DeA…` | Tokemak autoUSD `0xa7569A44…` | `15062.70e18` | `15062.70e18` | **No — 100.0000%** |

Both Autopools `paused() == false`; each strategy's `vault()` confirmed to be exactly the Autopool measured.

> **⚠ CORRECTION — a false-remedy claim has been struck.** An earlier draft said *"bricked normal path, two working escape hatches — not a permanent freeze"*. **That is false.** Verified at `AYieldStrategy.sol:695-716`, `relinquishPrincipal` writes down `clientBalances` and `totalDeposited` and **moves zero assets** — no `transfer`, no `redeem`, no `swap`. It is **claim abandonment**, weaker even than the suite's *ejector-seat* category, which at least moves funds. **The correct statement is: while the condition holds, no path returns underlying to the client.** Low is earned by **transience/self-clearing, the owner's `slippageToleranceBps` lever, and the measured non-binding throttle** — not by remedies that do not exist.

**Escalation trigger:** (a) `WATCH-17-03` — a consumer gating a user-facing withdraw on `netGuaranteed > 0` ⇒ **Medium**; **or** (b) evidence the throttle binds for a **sustained** period on the deployed Autopools ⇒ **Medium** on the availability limb **with no consumer needed**.

> **CRITICAL DE-CONFLICTION — must not be lost at triage.** `M-02` / `d7f6c2dfd580776d…` (Medium, **`false-positive`**) must **NOT** be inherited. Same code, **different claim**: `M-02` is *value extraction by a sandwicher*, refuted on concentrated-liquidity pool topology; this is *liveness*, on a surface that did not exist at `M-02`'s commit. **The refutation is about profitability, not about the quote's blindness.** A triage pass that pattern-matches the two would **suppress a live finding**. (The econ pass independently **re-refuted** the value-extraction reading this run — `testEconRefute_DonationDoesNotInflateTheQuote`, PASS, ~1 wei drift across an 11× share-price swing — which *confirms* `M-02`'s triage and leaves the liveness claim untouched.) `L-12` / `6e771a84e82df3c1` is adjacent context, not a duplicate.

**Re-file disclosure:** stable-staker `M-07` (`ss9m7`) / `969722dc9eedb961…` (Medium, `acknowledged`) — different repo, different function, and its disposition is an **operational prohibition on an owner action**. This is the same blindness on a **permissionless, integrator-facing view**, a larger blast radius **no operator discipline reaches, because the consumer is not the operator**. A **foreign-ledger** status carries **no suppression authority** here; none was applied.

**Test-suite blindness (attribution corrected):** no market test previews and then withdraws at a rate that breaches `minOut` — `testPreviewExitForRoundTripAtUnfavorableRateClearsFloor` deliberately picks 0.995 against a 1% tolerance. **This run's own Tier-3 controls** — `testControl_repoMockVault_cannotExpressAnExitFee` and `testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn` (both PASS) — prove the sponsor's fixtures cannot express the failure. **These are audit-authored tests, not the sponsor's:** `git grep testControl_ cdd0743` returns **zero hits**.

---

### [L-22] The quoted floor is not honoured across a real quote→execute gap <!-- id: ryv17l22 -->

**Fingerprint:** `7a66fe7d5a963abdce52855b617f42bfe70f77c7fd72b0ac4bd75783fc49b963`

**Location:** [`ERC4626MarketYieldStrategy.sol#L245-L246`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L245-L246) (inline `minOut`) vs `_exitFloor:127-135`; same shape on `ERC4626YieldStrategy._disposeShares:126-138`

**Description:** `_disposeShares` **re-derives `minOut` inline from live state** rather than honouring the floor `previewExitFor` quoted. `_exitFloor` and the inline recomputation are the **same expression by convention across three copies** (`:127-135`, `:245-246`, `t.sol:44-52` — pattern `D-5`), an equality **nothing enforces**.

**Impact:** Silent **~99% under-delivery**: `19,602e18` quoted at T1; **`181.9e18` delivered at T2 — 0.93% of the guarantee, with no revert, no event, no signal.** `v1d_floorBreachesDeferred` 35 direct / 1 market. **This is the most severe shape in the run.**

**What stops it being Medium — three things, all contingent:**
1. **Nobody sees the quote.** Zero consumers; the divergence is unobserved and unrelied-on today.
2. **The delivery shortfall itself is already owner-accepted.** "Debited for the requested amount regardless of what was received" is `AYieldStrategy.sol:781-783` by explicit design (*"shortfall accrues as yield"*), and the FCFS-at-par socialization it implements is stable-staker `69c7666eee33698e…` — **`wont-fix`, "intended design, confirmed by protocol owner"**. What is **new** at `cdd0743` is only that the protocol now *publishes a number under the word "guarantees"* that this accepted design will not honour.
3. **The PoC's two-exit-capable-client premise does not hold in the deployed wiring — now CONFIRMED, not assumed.** In the live `ResumeStableStakerMigration` broadcast (chain 1) each strategy receives `setClient(…, true)` for exactly two addresses — `PhusdStableMinter` (`0x435B0A18…`) and `StableStaker` (`0xbce8ABC0…`) — and **only `StableStaker` receives `setWithdrawer(true)`**. One exit-capable client. The gap still opens on a price move alone; the demonstrated 99% magnitude does not.

**Why it is nonetheless not QA:** the floor's atomic correctness is an **unenforced convention**. It holds atomically (256,000 forge + 209,901 medusa calls, no counterexample) and **evaporates the moment the gap is real** — which is the only mode in which a STATICCALL preview is useful.

**Distinctness is load-bearing.** Different harm from `L-21` (silent vs revert), different root cause (the quote is not a snapshot), and **different mitigation** — the floor must become **enforceable** as a caller-supplied `minOut` passed into `withdraw`, which `L-21`'s AMM-quote fix does not deliver. **Filing it under `L-21` would let the wrong fix close it.** It also fires on the **direct** strategy, which `L-21`(a) does not touch at all.

**Escalation trigger:** any consumer that **persists a `netGuaranteed` across blocks** — an off-chain keeper, or a two-phase `totalWithdrawal` flow ⇒ **Medium**. `WATCH-17-03`.

**Recommendation:** Pass the quoted `netGuaranteed` into `withdraw` as a caller-supplied `minOut` and revert if execution cannot meet it, instead of recomputing. Landing `L-29` first converts the silent failures into loud ones as an interim mitigation.

**Disclosure:** stable-staker `M-01` / `2b9a89d29c34df41…` (Medium, `wont-fix`) is **adjacent, not a duplicate** — its reasoning (*"nothing in stable-staker can fix it"*) carries **no authority over reflax code**, where the fix **is** a code change. **Fingerprint correction confirmed:** `2b9a89d2…` is the par-exit front-run entry, **not** `69c7666e…` (the older FCFS-at-par entry). Memory `stable-staker-run15-notes` cites the wrong one — repair owed, outside this lane.

**PoC:** `RealisticExitPreviewPoc.t.sol::testPoc_INV1_market_floorBreachesAcrossQuoteExecuteGap` (PASS)

---

### [L-23] One-directional write-down: the market strategy pays out over-delivery from the commingled position <!-- id: ryv17l23 -->

**Fingerprint:** `e6088a0ec55e90e820900c87b5fb34f243d62a745570d3b3580016113687b62d`

**Location:** [`src/AYieldStrategy.sol#L778-L783`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/AYieldStrategy.sol#L778-L783) `_withdrawInternal`, as composed with `ERC4626MarketYieldStrategy._disposeShares`

**Description:** The NatSpec at `:757-763` documents that *"principal is decremented by the REQUESTED (capped) amount … Any shortfall stays as protocol-owned yield"*. Confirmed at source: `clientBalances[token][balanceHolder] -= amount` at `:781-783` is **unconditional on `sharesDisposed`**. The contract books the **downside** as protocol yield but **pays out the upside** to the exiter. The asymmetry is **undocumented** and **repeatable** — exit whenever the AMM bids above NAV.

**Impact:** At a 5% premium to NAV: principal debited `10,101.0e18`, underlying delivered `10,575.1e18` — **+474e18 paid out of the commingled position**. `v4_overDelivery` 13 market / 0 direct. **This is the only finding in the run whose harm needs no consumer of `previewExitFor`** — it is on the live execution path at HEAD. Ledger conservation `Σ clientBalances == totalDeposited` **holds** (0 skews in 256,000 calls × 2 strategies), **which is precisely why no accounting invariant catches it: the skew is in value, not in the books.**

**The deciding fact is now RESOLVED — V1 is wired, so Low is correct on evidence, not merely by the conservative rule.** The "flagged for human review" flag is **closed**:

| Evidence | Source |
|---|---|
| `StableStaker: 0xbce8ABC09BaEDCabE93419bF875f6186e182079A` | `phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:146` |
| `CREATE` recorded as `contractName: "StableStaker"`, ctor args `[PhUSD, owner]` | `broadcast/ResumeStableStakerMigration.s.sol/1/run-latest.json` (chain 1, 2026-06-10) |
| That two-arg shape is **V1's** `constructor(IFlax _phUSD, address)` | `stable-staker/src/versions/v1/StableStakerV1.sol:202` |
| **V2's** ctor is `constructor(IAntimatter, address)` — not what was deployed | `stable-staker/src/StableStakerV2.sol:194` |
| `grep '"contractName": "StableStakerV2"' broadcast/` → **zero hits, all chains** | `phoenix-phase-2-staging` @ `1d8a3a7` |

Under **V1** the over-delivery moves protocol-owned minter cushion to protocol users — misallocation, not economic loss; the minter cannot redeem, so no user is diluted ⇒ **Low**. Under **V2** the premise is **VOID**: V2 emits Antimatter, redeemable into **unbacked** phUSD, so draining the cushion is **real dilution** ⇒ **Medium**.

> **⚠ Do not let this read as settled. This Low has a short shelf-life by design:** `StableStakerV2` is the evergreen, actively-developed contract and V1 is slated for retirement (owner, 2026-08-29). **The protocol's own roadmap is the escalation trigger.**

**Escalation trigger (hard, no further evidence needed):** (1) **any** `StableStakerV2` deployment wired as a client of a reflax strategy ⇒ **Medium immediately**; (2) `PhusdStableMinter` gaining `setWithdrawer(true)` or any strategy-exit path ⇒ **Medium**.

**Suppression correctly NOT applied:** the minter-cushion memo declares the commingled cap by design in the **deficit** direction (minters cannot redeem ⇒ cushion, not counterparty). This is the **surplus** direction; the memo's premise does not reach it. **Recall beats tidiness (Law 1).**

**`MR-17-03` must retain an owner:** the V2 unbacked-phUSD dilution leg is **live** and is **not** silently suppressed — it is routed to the cross-project unbacked-phUSD channel (`yield-claim-nft` `DEDUP-001` / `antimatter` run-01). **Routed, not dropped.**

**Recommendation:** Make the write-down symmetric — debit the value actually delivered, or cap the payout at the NAV-implied amount and retain the premium as protocol yield, consistent with how the deficit direction is already handled.

**Adjacent, do not collapse:** `QA-09` / `86409a56b6fc3c8b` (open, orphaned vault value) — same commingled-residual accounting, **opposite direction**.

**PoC:** `RealisticExitPreviewPoc.t.sol::testPoc_INV4_market_overDelivery` (PASS)

---

### [L-24] `previewExitFor` returns `(0,0)` for five operationally unrelated states — owner footgun (Law 3) <!-- id: ryv17l24 -->

**Fingerprint:** `6476515055d847ff05e8c09fb453145611c34f43926827d8c37cd0c3f9be35ce`

**Location:** [`ERC4626MarketYieldStrategy.sol#L162-L186`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L162-L186) + base `AYieldStrategy.sol:571-583`; setter at `:89-94`

**Description:** Four states return **bit-identical `(0,0)`**: (a) unknown account, (b) zero `netWanted` on a funded account, (c) drained account, and (d) — the footgun — `slippageToleranceBps == MAX_BPS` on an account with a **live `990e18` principal** (`assertGt(principalOf(...), 0)` passes). `setSlippageTolerance` permits **exactly** `MAX_BPS` (`require(_bps <= MAX_BPS)`). A funded client therefore signals **indistinguishably from an account that never existed**. Feeding `grossToRequest == 0` back into `withdraw` **reverts** rather than no-op'ing. A **fifth**, worse state: post-`emergencyWithdraw`, `shares == 0` with principal booked ⇒ positive gross, so the `(0,0)` sentinel does **not** fire, `netGuaranteed 0`, then a zero-size swap → `L-25`.

**Law-3 test applied:** *would a competent, non-malicious owner be surprised that raising slippage tolerance makes a funded client indistinguishable from an unknown one to every integrator?* **Yes ⇒ footgun ⇒ report.** There is **no malicious-owner leg in this finding at all**, and the reckless-admin invalid category does **not** apply — the *stated* consequence (a looser `minOut`) is obvious; **this** consequence is not documented and is not derivable from the setter's own signature.

**Aggravating and decisive:** the NatSpec at `:155-160` claims the `(0,0)` return *"lets a caller distinguish 'this strategy can guarantee no output' from a low-level failure and handle it as the operational alarm it is."* The contract does not deliver that distinction — so this is a defect **against the design's own stated purpose**. A falsely-exhaustive doc comment **raises** the finding rather than disposing of it.

**Escalation trigger:** a consumer treating `(0,0)` as "not a client" (skip / de-register / write off) while principal is live ⇒ **Medium** (state corruption in the consumer, not just a bad quote).

**Safe-config guidance (also carried under `L-01`):** `require(_bps <= 1000)` in the setter; never deploy at the zero default; pause deposits before temporarily raising tolerance; add `require(creditedPrincipal > 0)` in `_depositInternal`; monitor `previewExitFor(token, <known-funded client>, 1)` as a **`MAX_BPS` canary** — a `(0,0)` from a client with non-zero `principalOf` is unambiguously the `MAX_BPS` state.

**Ownership:** `L-01` / `6460e35331dff5c2` owns the setter's *boundaries* and the deposit-side blast radius, **not** the alarm ambiguity. The split is along **ownership**, not along the boundary.

**PoC:** `poc-run17-preview-exit.t.sol::testH4_ZeroZeroIsFourDifferentStates` (PASS)

---

### [L-25] `_disposeShares` passes an unguarded zero into the AMM adapter; production reverts on the zero-size swap while the test mock accepts it <!-- id: ryv17l25 -->

**Fingerprint:** `10f4bd34e9cf4efb3a9b83fd999cac118376b1c3e5e77a3175017d5574a30ce4`

**Location (fingerprint basis):** `ERC4626MarketYieldStrategy._disposeShares` — **the originating defect**. Mechanism sites: [`CurveAMMAdapter.sol#L129`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/AMMAdapters/CurveAMMAdapter.sol#L129) (the reverting `require`) and `test/mocks/MockAMMAdapter.sol` (no guard).

> **Filing note.** The *reverting* line is `CurveAMMAdapter.sol:129` — `require(amountIn > 0, …)` — but **that `require` is correct defensive code and must not be "fixed"**. The originating defect is `_disposeShares` passing an unguarded zero into it, which is also where the fix lands. Fingerprinting this on `CurveAMMAdapter.swap` would encode the defect as living in the adapter's correct guard.

**Description:** `MockAMMAdapter` has no `amountIn > 0` guard and **every** market test — including all 13 new preview tests — runs against the mock. Two reachable paths to `amountIn == 0`: (1) `vault.balanceOf(strategy) == 0` with principal still booked (post-`emergencyWithdraw`, or after another client drains the position per `L-20`); (2) `convertToShares(gross) == 0` for a dust exit once share price exceeds one underlying unit (probe at ~4× share price: `netWanted 1 → gross 2 → shares 0`).

**Impact:** The normal exit path (`withdraw` / `withdrawAsOwner`) reverts for the affected client while principal stays booked; `totalWithdrawal` silently no-ops at `:294`. **The test-fidelity half is the more important half:** the mock is more permissive than production on **exactly the edge story-050 steers callers into**, which is why a 13-test green suite proves nothing here.

> **⚠ CORRECTION — the same false-remedy claim as `L-21` has been struck.** Remedy enumeration *was* run (`withdraw`/`withdrawAsOwner` revert; `totalWithdrawal` no-ops at `:294`; `relinquishPrincipal` `:682` and `relinquishPrincipalAsOwner` `:687` both succeed with no external call) and the enumeration is accurate — but characterising those calls as **"two working escape hatches"** is false. `relinquishPrincipal` (`AYieldStrategy.sol:695-716`) writes down `clientBalances`/`totalDeposited` and **moves zero assets**; it is **claim abandonment**, not an escape hatch. **Correct statement: while the condition holds, no path returns underlying to the client.**

**Escalation trigger:** either write-down path being removed or owner-gated (in particular `relinquishPrincipal` ceasing to be client-callable) removes even the claim-abandonment exit ⇒ **Medium**.

**Recommendation:** Add `if (sharesToSell == 0) return 0;` in `ERC4626MarketYieldStrategy._disposeShares`, **and** add the `amountIn > 0` guard to `MockAMMAdapter` so the suite tests the production precondition. **Do not change `CurveAMMAdapter.sol:129`.**

**Attribution:** corroborated by **this run's own** Tier-3 control `testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn` (PASS) — an **audit-authored** test, **not** the sponsor's (`git grep testControl_ cdd0743` → zero hits).

**Disclosure:** `L-13` / `1456259d8ac60c11…` (Low, open) — identical share-flooring root cause, **different function and different fix** (`L-13` wants revert-or-skip in `_totalWithdraw`). **Fixing one leaves the other live.** Disclose, do **not** collapse.

---

### [L-26] `netWanted * MAX_BPS` panics on `type(uint256).max` in the market override while the base answers it <!-- id: ryv17l26 -->

**Fingerprint:** `63fa9e3e62bf03f014363100d906d27d3c1539bf71553fed872b940173f39129`

**Location:** `ERC4626MarketYieldStrategy.sol` `previewExitFor` — the `Math.ceilDiv(netWanted * MAX_BPS, denominator)` gross-up at **line 176** *(citation drift corrected: dedup and the classifier both cite `:174`, which at `cdd0743` is the closing brace of the `denominator == 0` guard; function, expression and mechanism are correct)*

**Description:** The gross-up is evaluated **before** the principal cap, so the multiplication overflows. The two implementations of **one interface member diverge on the standard "give me everything" sentinel**: direct at `type(uint256).max` returns the capped principal (`1000e18`, no revert); market reverts a bare `Panic(0x11)`.

**Impact:** A consumer switching between the two strategies behind one `IYieldStrategy` interface cannot write one code path. Asserted boundary: `netWanted > 11579208923731619542357098500868790785326998466564056403945758400791312963` reverts; the boundary value itself returns the capped principal. Aggravating: story-050 criterion 9 explicitly demanded a **neighbouring** division edge be *distinguishable from a bare `Panic(0x12)`* — this ships a bare `Panic(0x11)` on a **more** plausible input.

**Why Low and not QA:** `type(uint256).max` is the **idiomatic max-withdrawal sentinel**, not an absurd input; interface-member divergence on it is a spec defect. Borderline ⇒ **do not downgrade**.

**Escalation trigger:** none realistic — no asset path. Stays Low even under `WATCH-17-03`.

**Recommendation:** One line — `Math.min(netWanted, availablePrincipal)` before the gross-up, matching the base's cap-first ordering.

**PoC:** `poc-run17-pattern-match.t.sol::testPM1_MaxNetWantedOverflowsMarketButNotDirect` (PASS)

---

### [L-27] story-025's mandated safeguard is structurally incapable of firing (cross-repo: `StableStakerV2._routeExit`) <!-- id: ryv17l27 -->

**Fingerprint:** `d9bd595066efb97084c227327fcffcae9405ddb58e41ce4fc93c4af298a4b666` · **Law 2:** `F-17-04` · **Full write-up: [`spec-conformance.md`](spec-conformance.md)**

**Location:** `stable-staker` `src/StableStakerV2.sol:876-895` `_routeExit` (observed at stable-staker HEAD `fa06de5`)

**Cross-repo filing.** The defect is **entirely in `StableStakerV2._routeExit`**; reflax's `previewExitFor` is not wrong here and `relinquishPrincipal` behaves exactly as documented. It is fingerprinted on `StableStakerV2._routeExit` and carried as a **cross-repo integration entry** following the existing `F-03` / `52f9b84a54ec9a65` precedent. This is **not** the "OOS parent/forked contract" heading — `stable-staker` is a **registered, first-party, separately-audited** project in this suite; cross-repo is a **routing** question, never an invalidity one.

**Summary:** the `guardUnderwater` branch returns the **full requested `amount`** from idle and calls `relinquishPrincipal` (a pure write-down that moves **zero assets**), so `received == needed` **by construction** and the mandated `StableStaker:` revert **can never fire**. story-025's acceptance test passes trivially against a full-credit mock and is **unsatisfiable** against a real below-par strategy — **a green checklist here is a false negative.** Downstream: the buffer is thin by construction (10% of skim proceeds); one large staker's whole-position `autoAnnihilate` empties it, after which **every other staker's `withdraw()` is bricked**.

**Economic rule applied:** buffer depletion itself is **opportunity cost** under the externally-derived-yield rule and is **explicitly not filed as a value leak**. Only the **availability** leg is filed.

**Escalation trigger (conjunction of all three) ⇒ Medium:** (1) `stable-staker` bumps `lib/reflax-yield-vault` to a story-050 commit **and** lands `autoAnnihilate`; (2) `autoAnnihilate` sources through `_routeExit(…, guardUnderwater = true)`; (3) the wired strategy can go below par (**true today**).

**Gates:** rides `F-03` / `52f9b84a54ec9a65` and feeds `QA-09` / `86409a56b6fc3c8b`. **Not a duplicate of either.** Handle both in the same pass as `WATCH-17-03`. **Story state (Law 2):** story-025 sits in the `incomplete` folder.

---

### [L-28] `_totalWithdraw` silently early-returns on `totalShares == 0 || totalDeposited == 0`, burning the two-phase window <!-- id: ryv17l28 -->

**Fingerprint:** `38c9b2bae75ff87f66e09a6ed8710dd750057a00b1e8454016da8f6eafc19135`

**Location:** [`ERC4626YieldStrategy.sol#L185`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L185) **and** `ERC4626MarketYieldStrategy.sol:293` — `if (totalShares == 0 || totalDeposited[token] == 0) { return; }`

**Description:** The request is swallowed rather than reverted. Because `_executeWithdrawal` resets the two-phase state **before** dispatching (`AYieldStrategy.sol:879-892`), the **6h waiting period is consumed by a no-op that moves nothing** while principal stays booked — and the caller is told nothing.

**Impact:** A wasted 6h `WAITING_PERIOD` per attempt with no signal. This is what lifts it above a bare Slither `incorrect-equality` hit: the consequence is **traced**, not just detected.

**The Medium hinge was asked and answered — NEGATIVE, so Low is correct.** *"If the consumed window cannot be re-initiated, an owner migration is permanently blocked ⇒ Medium."* **It can be re-initiated.** `_executeWithdrawal` resets `status = None`, `initiatedAt = 0`, `balance = 0` **before** calling `_totalWithdraw`, so when the no-op fires the state is already back to `None`. `totalWithdrawal` re-entered on the next call routes to `_initiateWithdrawal` (`:855`), whose only gate is `require(balance > 0)` — and `balanceOf → principalOf → clientBalances` (`:593-595`), which the no-op left **untouched**. Principal booked ⇒ `balance > 0` ⇒ **re-initiation succeeds**. `_updateWithdrawalStatus` also expires stale windows to `Expired`, which `totalWithdrawal` treats identically to `None`. **No permanent block exists; the Medium leg is closed.**

**Recommendation:** Revert with an explicit reason (or emit a distinguishing event) instead of returning silently, so a burned window is visibly a burned window rather than an apparently-successful migration.

**Ledger caveat, resolved at upsert:** `L-13` / `1456259d8ac60c11…` is the **market** `_totalWithdraw` **share-flooring** instance (`sharesToSell` floors to 0). This is the **zero-shares / zero-deposits guard** at the top of the same function, on **both** contracts — different condition, different fix, different `rootCauseClass`, different fingerprint. **Confirmed: `L-13` does not cover the zero-state guard at either site**, and the direct-strategy site is unambiguously new either way. One entry covers both sites; **`L-13` is untouched**.

---

### [L-29] The direct strategy discards `vault.redeem`'s return <!-- id: ryv17l29 -->

**Fingerprint:** `704404968a8fe23ea7107e812e20f7dfb56e2a2f0047e4e323f736b7c01edb7d`

**Location:** [`ERC4626YieldStrategy.sol#L135`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L135) `_disposeShares` — `vault.redeem(sharesToRedeem, recipient, address(this));`

**Description:** The return is discarded. `previewExitFor`'s NatSpec mandates **in capitals** that consumers MUST measure the actual balance delta across `withdraw`; **the strategy's own exit does not**, and `vault.redeem` carries **no `minOut`**.

**Impact:** This is the **mechanical enabler** of `L-18` and `L-19` — exactly why the direct-strategy failures are **silent under-delivery rather than reverts**. Capturing the return and comparing it to the quoted floor **converts `L-18` and `L-19` from silent to loud in one line**. It is the missing tripwire, not a style nit.

**Severity note (corrected):** the classification rated this Low *"because of leverage, not impact"*. **Fix leverage is not a severity criterion.** It is **Low on its own footing**: live path, no `minOut` on `vault.redeem`, and it is the mechanism that makes `L-18`/`L-19` silent. The "land it first" advice stands as **sequencing**, not as severity basis.

**Escalation trigger:** none standalone — it is a **mitigation multiplier**. Its value is that it **caps** the escalation of `L-18`/`L-19` if landed before `WATCH-17-03`.

**Recommendation:** Capture the return of `vault.redeem` and compare it against the quoted floor, reverting or emitting on a breach. **Recommend landing this first.**

**Distinct from** `QA-06` / `8019f1c9c6de5e43` (EnumerableSet returns) and `L-06` / `0f534a726502d274` (skim return semantics) — different call sites.

---

## QA / Informational Findings

### [QA-10] `ceilDiv` gross-up compensates the bps leg but not the share round-trip <!-- id: ryv17q10 -->

**Fingerprint:** `e868f28953a9723aba15cff38772f2fe3cf4f42b7d84a9067a520cba9eef1b3c` · **Law 2:** `F-17-03`

> **Channel note:** this entry's substance lives in [`spec-conformance.md`](spec-conformance.md), **not here**. It is a deviation from story-050's stated behaviour, and under Law 2 a story deviation is never buried in the QA/gas bundle even when its security impact is nil. It is listed here only so the QA reader knows it exists.

`netGuaranteed` can land **1 wei** below `netWanted` (bound `⌈A/S⌉ + 2` raw base units; 256-run fuzz, no counterexample). **Known-benign** under `ROUNDING-DIRECTION`: `ceilDiv` rounds the *request* up (protocol-favouring), the double floor rounds the *quote* down — **no user-favouring leg, no repeatable round-trip profit**. `DIVISION-PRECISION` refuted. **Process signal: two consecutive stories (043, 050) have each claimed a provable property the ERC4626 double round-down does not deliver** — cf. `F-01` / `ec9191e420d54444` (deposit side; **disclose, do not collapse**).

### [QA-11] Market `previewExitFor` override is sealed against subclassing <!-- id: ryv17q11 -->

**Fingerprint:** `b5b58717f3b11d73aa4b07d4a70528c50db842ae2beecb992413c56d7251fb90`

**Location:** `ERC4626MarketYieldStrategy.sol:162-166` — declared `external view override` where the deliberate base at `AYieldStrategy.sol:571-577` is `external view virtual override`.

Every other overridable hook (`_disposeShares`, `_positionValue`, `getTotalShares`) stays reachable; this one is the exception — in a repo with a demonstrated forked-variant habit (`NFTStakerPriceScaled`, `StableStakerV1/V2`) and **five defects (`L-18`…`L-22`) a subclass would want to patch**. **One-word fix:** add `virtual`.

**The "unused view functions" invalid category does NOT apply** — the claim is not "a view is unused", it is that the **override is sealed**, which would be equally true of a heavily-used function.

**Escalation trigger:** a forked variant actually needing to patch `previewExitFor` and being unable to ⇒ **Low**.

### [QA-12] Raw `approve` with unchecked boolean return in the `ERC4626YieldStrategy` constructor <!-- id: ryv17q12 -->

**Fingerprint:** `1b33361313ce59d2b75a89418792ec5fdaae524760709872f139cc15678a4dcb`

**Location:** [`ERC4626YieldStrategy.sol#L50`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L50) — `IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);`

USDT's `approve` returns no data, so a `bool`-decoding call **reverts at deployment**. Failure is **deploy-time and loud — nothing deploys.**

**Two invalid categories tested; neither applies.** (1) *Approve race / `safeApprove` front-running* covers the ERC20 allowance double-spend across an `approve(x) → approve(y)` transition. This is a **one-shot constructor approve** with the strategy's own configured vault as spender — no race, no front-run, no allowance transition, and the code runs at deployment so there is no transaction to front-run. (2) *Non-standard/weird ERC-20 (except USDT)* — **USDT is the explicit carve-out and USDT is the token that trips this**, so the carve-out **is the basis, not a suppression**.

**Law 3 correctly not invoked:** the failure is loud and pre-deployment, so it fails the surprise test. **QA is the right severity.** Kept for the one-line `SafeERC20.forceApprove` fix on the **only unguarded ERC20 call in `src/`**; `CFG-01` / `0c12a2cfaf4b026a` (open) is evidence the wired-vault configuration **has already been wrong once**.

### [INFO-01] Adding `previewExitFor` to `IYieldStrategy` breaks four implementers at the next submodule bump <!-- id: ryv17i1 -->

**Fingerprint:** `25d53af10717317809fbda48c15a4b242bb9a45193b58bc1ab23c6a6efc45b26`

**Location:** `src/interfaces/IYieldStrategy.sol:79`

Four `IYieldStrategy` implementers resolve the interface through a **remapping to the live reflax submodule** — no repo vendors its own copy — so all four fail to compile at the next bump: `stable-staker/test/Migration.t.sol:924`, `stable-staker/test/mocks/MockYieldStrategy.sol:26`, `stable-yield-accumulator/test/StableYieldAccumulator.t.sol:112` and `:215`. **All four are in `test/`: a build break in test suites, not a runtime break.** `phoenix-phase-2-staging` has zero **code** implementers (its only hit is a markdown plan document); `antimatter`'s mock declares no interface inheritance.

**Not "speculation on future code"** — the rule's operative words are *without a demonstrated root cause*. The declaration exists today, the implementers exist today at their own HEADs, and the consequence is mechanically determined. Only the **date** is future.

> **`MR-17-04` — escalation trigger, named not hedged.** story-faithfulness `WATCH-17-01` claims **six** implementers; two are in **unregistered** repos and outside this run's evidence base. One matters disproportionately: `deployment-staging/src/mocks/MockYieldStrategy.sol:12` is cited in **`src/`, not `test/`**, which would escalate a test-only break to a **deployable-contract** break ⇒ **Low or Medium**. The enumeration **does not assert it exists**. **Register `deployment-staging` or confirm it is dead before the next reflax bump.**

**This finding carries the run's load-bearing fact:** zero consumers of `previewExitFor`, verified three times independently and untruncated. **`WATCH-17-03` escalates `L-18`…`L-22` at once.**

---

## Addendum to an existing open entry — `L-17` / `CFG-01` (`0c12a2cfaf4b026a`)

**Not a new fingerprint.** Recorded as an **extension of the existing open Low**, per Law 1 (recall over tidiness) and sized honestly rather than inflated. Measured on mainnet at **block 25878009**:

| `addresses.json` `"1"` entry | Recorded value | On-chain reality |
|---|---|---|
| `autoDOLA` | `0x0538C8bAc84E95A9dF8aC10Aad17DbE81b9E36ee` | **`"vaDAI Pool"` / `vaDAI`** — `asset()` **reverts**; not an ERC4626. Real autoDOLA is `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d` — **already `L-17`** |
| `MainRewarder` | `0x79dD22579112d8a5F7347c5976bC7b9812C2D4EA` | **zero code — no contract at this address at all** — **NEW, and strictly worse** than a wrong-but-live address: a deploy fed from this file targets nothing |
| `DOLA` | `0x8653773670…` | ✅ "Dola USD Stablecoin" |
| `TOKE` | `0x2e9d637882…` | ✅ "Tokemak" |
| `autoUSD` | *absent* | Wired and live (`0xa7569A44…`) despite story-049 targeting it |

**Severity: Low — an addendum, NOT a new Medium.** **Nothing on chain is misconfigured:** the live strategies point at the **correct** Autopools (verified via each strategy's own `vault()`). The harm is confined to a **deploy-input artifact** and would surface loudly.

---

## Parked for human review — `manual-review.json` (8 entries, visible channel)

**Nothing here was dropped.** Law 1 forbids burying a plausibly-security-relevant item in a log nobody reads. Full text with `reason`, `originalId` and `confidence` per entry: [`../manual-review.json`](../manual-review.json).

| id | Parked item | Why it is here, not filed |
|---|---|---|
| `MR-17-01` | `vault.asset() == underlyingToken` is never checked in either concrete constructor; `_exitFloor` adds a 3rd and 4th call site inheriting the assumption (zero `asset()` occurrences in `src/`) | The code scan declined to file it because the failure mode is "obvious" (nothing works). **Dedup disagrees on that premise:** a vault whose `asset()` differs only in **decimals** mis-scales every `convertTo*` **silently**, which passes the Law-3 surprise test and would make it an in-scope footgun. Not confident enough to overrule the scanning agent; too security-relevant to drop. **Human call.** |
| `MR-17-02` | `WATCH-17-E3` — `StableStakerV2.setYieldStrategy`'s idle sweep (`:294-298`) has no `require(credited > 0)` while `stake` (`:333`) and `depositFor` (`:713`) do | Cross-repo: belongs to stable-staker; no reflax finding owns it. |
| `MR-17-03` | The **V2 unbacked-phUSD dilution leg** of `L-23` — the minter-cushion suppression premise is **VOID** for V2 | **Live**, but owned by the cross-project unbacked-phUSD channel (`yield-claim-nft DEDUP-001` / `antimatter` run-01). **Routed so it is not lost between ledgers. Must retain an owner.** |
| `MR-17-04` | Register `deployment-staging` (or confirm it is dead) before the next reflax submodule bump | A `src/`, not `test/`, implementer would turn `INFO-01` into a **production-path** build break. The repo is not registered, so the claim is unverifiable from this run's evidence base. |
| `MR-17-05` | The dominance downgrade of `L-18`/`L-20` is **contingent** on `p ≤ D` (`AYieldStrategy.sol:48`) and `a ≤ p` (`:772-776`), and **no test pins either** | Negative controls T2/T3 both fail immediately when either premise is dropped, so this is a property of the code, not of the integers. A future unpaired write to `clientBalances`/`totalDeposited`, or an exit path reaching `_disposeShares` without the principal cap, **re-arms both findings at Medium with no scanner signal**. **`DominanceRun17Grounding.t.sol` is the runnable regression guard and should be kept.** |
| `MR-17-06` | `WATCH-17-E2` — `L-20`'s suppression rests entirely on `PhusdStableMinter` having **no strategy-exit path** | If any future story gives it one, the premise dies and `L-20` becomes a **live Medium immediately**. A suppression condition with an expiry, parked so the expiry is visible. |
| `MR-17-07` | `WATCH-17-02` — story-050 sits in `auto-complete` with *"machine approval — not human-reviewed"*, both Execute and Review run `--inline-delegation` with self-declared *"Independence: reduced"* | `L-18` and `QA-10` are **both inside the blind spot review declared out of its own reach**. Revised acceptance criteria would move the Law-2 baseline under several findings. |
| `MR-17-08` | Ledger recall gap | **CLOSED by this upsert** — `lastRun` is now `reflax-yield-vault-17` @ `cdd0743` and all 16 run-17 shapes are ledgered, so they reconcile by fingerprint on run-18. |

---

## Open carryover from prior audits — 38 entries, copied in full

**No open entry is dropped from view.** Each still-open (and untriaged) entry from a prior audit is carried as a **verbatim copy** of its originating report section, pruned to the still-live set, one file per originating audit. **These are full copies, never pointer stubs.**

| Originating audit | File | Entries retained |
|---|---|---|
| 05 | [`carryover/qa-report-05.md`](carryover/qa-report-05.md) | `L-01`, `C-01` |
| 07 | [`carryover/qa-report-07.md`](carryover/qa-report-07.md) | `L-03`, `L-04`, `L-05`, `L-06`, `L-07` (4 sections; the run-07 `L-05` section covers ledger `L-05` **and** `L-06`) |
| 11 | [`carryover/qa-report-11.md`](carryover/qa-report-11.md) | `L-01-run11`…`L-07-run11`, `L-08`, `L-09`, `L-11`, `L-12`, `QA-01` |
| 12 | [`carryover/qa-report-12.md`](carryover/qa-report-12.md) | `L-13`, `QA-02`…`QA-08` |
| 12 | [`carryover/spec-conformance-12.md`](carryover/spec-conformance-12.md) | `F-01`, `F-02` |
| 14 | [`carryover/qa-report-14.md`](carryover/qa-report-14.md) | `QA-09` |
| 14 | [`carryover/spec-conformance-14.md`](carryover/spec-conformance-14.md) | `F-03` |
| 15 | [`carryover/qa-report-15.md`](carryover/qa-report-15.md) | `L-14`, `L-15` |
| 15 | [`carryover/spec-conformance-15.md`](carryover/spec-conformance-15.md) | `F-04`, `F-05` |
| 16 | [`carryover/qa-report-16.md`](carryover/qa-report-16.md) | `ECON-A` (`L-16`), `CFG-01` (`L-17`) |
| 16 | [`carryover/spec-conformance-16.md`](carryover/spec-conformance-16.md) | `F-16-003` |

**Two entries gain recorded extensions rather than new fingerprints:**
- **`L-01` / `6460e35331dff5c2`** — *blast-radius extension*. `L-01` already owns **both** boundaries of `setSlippageTolerance` (title: *"setter missing sane cap"*; `run08Note` expands to the deposit-side haircut). story-050 adds a **third dependent surface**: at `MAX_BPS`, `previewExitFor` returns an alarm indistinguishable from three benign states. The alarm-ambiguity itself is **not** owned by `L-01` and is filed separately as **`L-24`** — the split is along **ownership**, not along the boundary.
- **`L-01-run11` / `3ab43381ffaf861f`** — *site extension*. The same CEI violation in `_totalWithdraw` on both contracts (`ERC4626MarketYieldStrategy.sol:309-313`, `ERC4626YieldStrategy.sol:194-198`). **Exploitability REFUTED on mechanism**: no third party can obtain control mid-withdraw (only outbound calls are `ammAdapter.swap → router.exchange`, both value legs are hookless ERC20s, zero ERC777/721/1155 in `src/`, `nonReentrant` on all 8 value-moving entry points). **CONDITIONAL — reopen if a hook-bearing token or a callback-capable adapter is introduced.** The window is real; no actor can read it.

**Not carried over** (already human-triaged disposals, 11): `M-02`, `M-04`, `M-02-run11`, `M-01-run12`, `H-02`, `L-10` (`false-positive` ×6); `L-02` (`wont-fix`); `M-03` (`merged`); `H-01`, `H-03` (`downgraded-to-centralization`); `M-01` (`fixed`).

---

## Suppression-authority statement

- **Known-issues suppression is UNAVAILABLE for this project and was exercised nowhere.** `registered-projects.json` records `knownIssuesCount: 0`, `knownIssues: []`, **`knownIssuesSource: null`**, `knownIssuesExtractedAt: 2026-01-23` — **seven months stale** against `cdd0743`, with a null source pointer even though the declared sources (`lib/reflax-yield-vault/CLAUDE.md`, `docs/`) exist. **An empty cache is not evidence that no known issues exist; it is evidence that none were extracted.** No finding in this run was suppressed on those grounds. **Re-extraction is owed to project-manager before run-18** and has been recorded as an owed gap in the registry (`knownIssuesReExtractionOwed`). Same class as `phstaging-known-issues-cache-unfalsifiable` and `phlimbo-ea-known-issues-unfalsifiable`.
- **In-source NatSpec carries no suppression authority** and was used in the **opposite** direction — as aggravating in `L-18`, `L-19`, `L-22`, `L-23`, `L-24`, `L-29`.
- **Foreign-ledger statuses carry no authority here** — stable-staker `M-07` (`acknowledged`) and `M-01` (`wont-fix`) were correctly declined as suppressions for `L-21` and `L-22`.
- **No finding in this run rests on a malicious-owner premise.** Verified across all 16.
- **The Halmos results are evidence in neither direction:** 0 `[PASS]`, 7 `[TIMEOUT]`, 2 intended `[FAIL]` (a negative control and a vacuity tripwire). No `[TIMEOUT]` row is cited as support anywhere.

## Triage

Triage with `/ledger reflax-yield-vault`. **`WATCH-17-03`, `WATCH-17-E2`, `MR-17-03`, `MR-17-04` and `MR-17-05` must survive triage** — each is a trigger that no scanner in this project will fire on.

---

## Automated analysis — 4naly3er

*Appended after the human-authored findings. This section is machine-derived baseline coverage,
**not** a source of new labels: nothing below was filed as an `L-XX` / `QA-XX` / `C-XX`.*

**Coverage gap closed.** 4naly3er was **not** run during this run's static-analysis tier — Slither,
Aderyn and Semgrep were. It has now been run and its full output attached as
[`4naly3er-report.md`](./4naly3er-report.md) alongside this bundle.

### Provenance

| | |
|---|---|
| Tool | `tools/4naly3er` — `yarn analyze` (solc 0.8.27 bindings) |
| `basePath` | repo root (so `remappings.txt` resolves) — the `workspace/reflax-yield-vault` clone at `cdd0743`, tracked tree clean |
| arg 3 | a **scope list** (7 paths), **not** a remappings file |
| `githubLink` | `…/blob/cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` |
| Result | completed; `report.md` produced |

The run against `lib/reflax-yield-vault` **failed** — `pauser/interfaces/IPausable.sol import not
found`, then a solc binding crash. The `pauser/=lib/mutable/pauser/src/` remapping exists only in
`foundry.toml`, which 4naly3er does not read; it reads `remappings.txt` at `basePath`, which carries
only `@openzeppelin=`. Since `lib/` is read-only, the run was redone from the `workspace/` clone at
the same commit with that one line appended to `remappings.txt`, and the file was restored after.
**No symlink workaround was attempted** — that approach is known-broken.

### Files actually parsed — 7 of 7 in scope

| File | Instances |
|---|---|
| `src/AYieldStrategy.sol` | yes |
| `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` | yes |
| `src/concreteYieldStrategies/ERC4626YieldStrategy.sol` | yes |
| `src/AMMAdapters/CurveAMMAdapter.sol` | yes |
| `src/interfaces/IYieldStrategy.sol` | yes |
| `src/AMMAdapters/IAMMAdapter.sol` | yes |
| `src/AMMAdapters/ICurveRouterNG.sol` | **compiled, zero instances** (bare interface) |

All 7 were submitted and compiled — the scope echo in the tool's own output lists all seven, and the
compile that crashed on the missing import proves the import graph was genuinely resolved on the
successful run. `ICurveRouterNG.sol` yielding nothing is a real empty result for a declaration-only
interface, **not** an unparsed file. This is an exit-0 with **6 files producing findings**, not an
exit-0 over zero parsed files.

### Items raised

**3 Medium · 13 Low · 23 Non-Critical · 16 Gas** (263 total instances). Every one is a generic
detector class; none is a bespoke finding.

### Cross-check against the 16 filed findings

**Overlaps — already filed, do not double-count:**

| 4naly3er | Filed as | Note |
|---|---|---|
| `L-1` `approve()` may revert if current approval non-zero — `ERC4626YieldStrategy.sol:50` | **`QA-12`** | Same line. Ctor approve runs from a zero allowance, so the revert leg is inapplicable; `QA-12`'s unchecked-boolean-return leg is the live one. |
| `L-13` Unsafe ERC20 operation — `ERC4626YieldStrategy.sol:50` | **`QA-12`** | Identical instance to `L-1`; one defect counted twice by the tool. |
| `L-8` / `L-9` rounding & precision loss on the `* (MAX_BPS - slippageToleranceBps) / MAX_BPS` and share-ratio divisions | **`QA-10`**, and the mechanism under `L-19`/`L-20`/`L-22` | `QA-10` is the sharper statement: the `ceilDiv` gross-up compensates the bps leg but not the share round-trip. |
| `L-3` zero-value transfer revert — `CurveAMMAdapter.sol:132` | adjacent to **`L-25`** | `L-25` is the stronger and correct framing: the zero *swap* reverts at `CurveAMMAdapter.sol:129` before any transfer, and the test mock hides it. Not a separate entry. |
| `M-2` Centralization Risk for trusted owners (15 instances) | — | **Law 3 suppression, stated not hidden.** All 15 are plain `onlyOwner` setters/constructors with obvious consequences; the owner is trusted for knowing actions. The *non-obvious* owner footguns in this codebase are filed at honest severity as `L-24` (`setSlippageTolerance` → `previewExitFor` returning `(0,0)`) and the `L-17`/`CFG-01` addendum — neither of which 4naly3er detects. No `C-XX` is warranted from this list. |

**Dismissed — false positives against this code / this OZ version:**

- `M-1` fee-on-transfer (`CurveAMMAdapter.sol:132`) — C4 known-invalid unless FoT is explicitly in scope; it is not.
- `M-3` `increaseAllowance` fails on USDT (4 instances) — **verified false at this dependency version.** `lib/openzeppelin-contracts` is **v5.4.0**, whose `safeIncreaseAllowance` routes through `forceApprove`, which retries with an intervening `approve(spender, 0)` on failure. USDT is handled. (Checked deliberately, because CLAUDE.md carves USDT *out* of the weird-ERC20 invalid list.)
- `L-6` division by zero (7 instances) — every divisor is guarded upstream: `AYieldStrategy.sol:549` behind the `totalDeposited[token] == 0` early return at `:540`; `ERC4626MarketYieldStrategy.sol:298` / `ERC4626YieldStrategy.sol:190` behind the very guard `L-28` reports; `:438` / `:317` behind `if (bufferShares[i] == 0) continue`, which cannot be reached with `totalShares == 0`.
- `L-4` missing `address(0)` check — points at an `emit` line (`AYieldStrategy.sol:368`), a detector misfire.
- `L-5` `abi.encodePacked` with dynamic types — the strings are concatenated into a **revert message**, never hashed.
- `L-2` / `L-11` `Ownable2Step`, `L-7` renounce-while-paused, `NC-6` / `NC-16` `renounceOwnership` — owner-trust class (Law 3), and a deployment-topology choice rather than a defect.
- `L-10` `PUSH0` and `L-12` 0.8.13/0.8.14 assembly-optimizer bug — pragma-floor classes on `^0.8.13`. The project builds and deploys on mainnet at a pinned modern solc; no L2 target is in scope.

**Genuinely new — nothing.** No 4naly3er item raises a defect that none of the 16 filed findings
covers, once the false positives above are removed. Every remaining item is Gas (16 classes) or
Non-Critical style (23 classes: function length, ordering, magic numbers, named mappings, missing
`indexed`, NatSpec `@return`), which C4 discourages and this bundle deliberately does not carry.
**No new entry is proposed and none was filed.**

### Suppression posture for this section

- **Semgrep's Solidity coverage is lint-only.** It ships **no** Solidity *security* ruleset, so a
  clean Semgrep result in this run's static tier is not evidence of absence of security defects.
  4naly3er was added precisely to give the Low/QA tier a real C4-style bot baseline.
- **The project's known-issues cache is empty with `knownIssuesAuthority: NONE`** (`knownIssuesCount: 0`,
  `knownIssuesSource: null`, extracted 2026-01-23 — seven months stale against `cdd0743`).
  **Nothing in this bundle, automated or human-authored, was suppressed on known-issues grounds.**
  The dismissals above are dismissals on the merits, each with its stated reason, not suppressions.
