# Tier-3 Invariant Testing — reflax-yield-vault run-17

- **Project**: reflax-yield-vault · **Commit**: `cdd0743` `[story-050] GREEN: previewExitFor on IYieldStrategy, base default + market override`
- **Date**: 2026-08-31
- **Engines**: Foundry invariant runner `forge 1.5.1-stable` + **Medusa 1.5.1** (property mode). Echidna not used (Medusa available).
- **Artifacts (raw, on disk)**: `reports/reflax-yield-vault/17/tier3/`
  - `forge-invariant-realistic.txt` — the 1024×250 Foundry campaign
  - `forge-poc-counterexamples.txt` — 8 deterministic numbered counterexamples/controls
  - `forge-census-reached-states.txt` — reached-state census (anti-vacuity)
  - `medusa-market.txt`, `medusa-direct.txt` — Medusa property runs
  - `commit.txt`, `toolchain.txt`
- **New audit artifacts in the workspace** (nothing pre-existing was modified — `git status` shows **0** modified files, 35 untracked, all 31 prior artifacts intact):
  - `workspace/reflax-yield-vault/test/invariant/mocks/RealisticERC4626Vault.sol`
  - `workspace/reflax-yield-vault/test/invariant/mocks/FiniteDepthAMMAdapter.sol`
  - `workspace/reflax-yield-vault/test/invariant/RealisticExitPreviewHandler.sol`
  - `workspace/reflax-yield-vault/test/invariant/RealisticExitPreview.t.sol`
  - `workspace/reflax-yield-vault/test/invariant/RealisticExitPreviewPoc.t.sol`
  - `workspace/reflax-yield-vault/test/invariant/MedusaRealisticExit.sol`
  - `workspace/reflax-yield-vault/medusa-realistic-{Market,Direct}.json`

> **These are AUDIT artifacts.** None of them is a project file and none may ever be cited as a finding location.

---

## 0. Honesty framing

Every "HOLDS" below means **no counterexample was found in the stated number of sequences/calls** — absence of evidence, not proof. Only the VIOLATED rows are conclusive. The two HOLDS rows are the ones worth handing to the symbolic-analyzer for an actual proof.

---

## 1. What was built, and why the existing tests could not see it

The run-17 pattern pass established that story-050's 13 preview tests rest on fixtures strictly more permissive than production. Three replacement doubles close the named gaps:

| Gap | Repo fixture | Replacement |
|---|---|---|
| **D-3** exit-leg fee | `MockERC4626Vault`'s only fee knob is deposit-side; `redeem` pays `_convertToAssetsInternal` exactly | `RealisticERC4626Vault.exitFeeBps` charged inside `redeem`/`withdraw` and reflected in `previewRedeem`/`previewWithdraw`, while `convertToShares`/`convertToAssets` stay **fee-blind** exactly as EIP-4626 mandates |
| **D-4** redemption throttle | `maxRedeem`/`maxWithdraw` return the whole balance unconditionally | `redeemCapBps` (per-holder) ∧ `illiquidBps` (vault free liquidity); `redeem`/`withdraw` **enforce** the cap with an OZ-style `ExceededMaxRedeem` revert |
| below par | — | `simulateLoss` drops NAV; the census reaches 198/203 exits below par on the direct rig |
| **D-2** AMM depth | `amountOut = amountIn * rate / 1e18` — infinite depth, size-independent price | `FiniteDepthAMMAdapter`: constant-product `x·dx/(y+dx)` with a pool fee, output **concave** in size |
| **D-1 / CODE-04** | `MockAMMAdapter` has no `amountIn > 0` guard | `require(amountIn > 0)` — production parity with `src/AMMAdapters/CurveAMMAdapter.sol:129` |
| **D-5** self-referential oracle | `_exitFloor`/`_grossUp` test helpers re-implement the production expression | **No mirror is used anywhere.** Every assertion compares the quote to the **measured balance delta** of an actually-executed `withdraw` |

Share price is seeded non-trivially (1.23), three clients carry non-zero principal before fuzzing begins, and the vault starts with a 1% exit fee, a 60% redemption throttle and a 10% illiquid sleeve.

### Control: the repo's own fixtures make two of these invariants unfalsifiable

`testControl_repoMockVault_cannotExpressAnExitFee` (PASS) — with `MockERC4626Vault.setFeeBps(500)`:

```
repo mock feeBps    : 500
netGuaranteed       : 1000000000000000000000
delivered           : 1000000000000000000000   <-- exactly equal; the 5% fee is invisible on exit
repo mock maxRedeem : 8550000000000000000000   == full share balance
```

`testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn` (PASS) — a `990,000e18` exit clears `minOut` at an **unmoved price**, and `MockAMMAdapter.swap(token, vault, 0, 0)` returns `0` where `CurveAMMAdapter.sol:129` reverts.

So under the repo's fixtures INV-1 and INV-3 **cannot fail by construction** — the green suite is not evidence.

---

## 2. Results

Foundry campaign: `FOUNDRY_INVARIANT_RUNS=1024 FOUNDRY_INVARIANT_DEPTH=250 FOUNDRY_INVARIANT_FAIL_ON_REVERT=false FOUNDRY_FUZZ_SEED=0x11 forge test --match-contract "RealisticExitPreviewTest" --match-test "invariant_" -vv`
→ **1024 runs × 250 depth = 256,000 calls per invariant**, per strategy.

Medusa: `medusa fuzz --config medusa-realistic-{Market,Direct}.json` → **209,901 calls (Market)** and **209,999 calls (Direct)**, `callSequenceLength: 60`, 4 workers.

| # | Invariant | Direct (`ERC4626YieldStrategy`) | Market (`ERC4626MarketYieldStrategy`) |
|---|---|---|---|
| **1** | `netGuaranteed` is a floor — *atomic* quote→exit | **VIOLATED** (forge + medusa) | **HOLDS** — 256,000 forge calls / 209,901 medusa calls, no counterexample |
| **1b** | `netGuaranteed` is a floor — *across a real quote→execute gap* | **VIOLATED** | **VIOLATED** |
| **2** | Σ concurrent `netGuaranteed` ≤ realizable capacity | **VIOLATED** | **VIOLATED** |
| **2b** | …≤ capacity even ignoring the per-call throttle | **VIOLATED** | **VIOLATED** |
| **3** | `netGuaranteed > 0` ⟹ `withdraw` does not revert — atomic | **VIOLATED** | **VIOLATED** |
| **3b** | …across a quote→execute gap | **VIOLATED** | **VIOLATED** |
| **4** | Ledger conservation `Σ clientBalances == totalDeposited` | **HOLDS** — 256,000 calls, 0 skews | **HOLDS** — 0 skews |
| **4** | No client receives more than it was debited | **HOLDS** — 256,000 forge calls / 209,999 medusa calls | **VIOLATED** |

Both engines agree on every row. Medusa summary lines: Market `2 passed, 5 failed`; Direct `2 passed, 5 failed`.

### 2.1 Why INV-1 holds atomically on the market override but not across a gap

`ERC4626MarketYieldStrategy._disposeShares` recomputes `minOut` inline (`:245-246`) with the **same expression** `_exitFloor` uses (`:127-135`). In one transaction the two are numerically identical, so the swap either delivers ≥ the quoted floor or reverts — INV-1 is satisfied *by construction*, and INV-3 absorbs all the failure instead. That equality is a **convention across three copies of the expression** (D-5), not an enforced link, and it evaporates the moment the quote and the execution are separated: the floor is recomputed from live state at execution, so it is not a floor at all — it is a re-quote.

This is the finding the run's brief asked for: **the market override's floor guarantee fails once the gap is real**, which is the only mode in which a STATICCALL preview is useful.

---

## 3. Counterexamples (deterministic, `forge test --match-contract RealisticExitPreviewPoc -vv`, 8/8 PASS)

**INV-1, direct, atomic — the exit fee breaches the floor**
`testPoc_INV1_direct_exitFeeBreachesFloor`
```
grossToRequest: 1000e18
netGuaranteed : 1000e18
delivered     :  990e18      <-- 1% exit fee; base default returns grossToRequest as the guarantee
```
The base `previewExitFor` sets `netGuaranteed = grossToRequest` on the premise that "a direct exit deducts nothing" (`AYieldStrategy.sol:561`). A spec-conformant fee-charging ERC4626 falsifies that premise, and `_disposeShares` passes **no `minOut`** to `vault.redeem`, so nothing catches it.

**INV-3, direct — a throttled vault turns a green quote into a revert**
`testPoc_INV3_direct_redeemThrottleBricksQuotedExit`
```
grossToRequest           : 5000e18
netGuaranteed            : 5000e18      (non-zero => green light)
vault.maxRedeem(strategy): 1000e18      => withdraw reverts ExceededMaxRedeem
```
Neither `previewExitFor` nor `_disposeShares` consults `maxRedeem`/`maxWithdraw`. Note this is exactly the vault class the market strategy exists to accommodate (sUSDe cooldown, Tokemak autopool), so the direct strategy meeting one is not hypothetical.

**INV-2, direct, multi-client — aggregate over-quote**
`testPoc_INV2_direct_aggregateQuotesExceedCapacity` (3 × 10,000e18, then −10% NAV, 1% exit fee)
```
sum(netGuaranteed)                                : 30,000e18
realizable capacity (whole position, fee-adjusted): 26,730e18
```
Each quote is individually "valid"; concurrently they promise 12.2% more than the position can pay. First-mover takes the full quote, the last client absorbs the whole shortfall.

**INV-3, market — finite depth alone bricks a quoted exit**
`testPoc_INV3_market_finiteDepthBricksQuotedExit`
```
grossToRequest        : 19,800e18
netGuaranteed         : 19,602e18
AMM would actually pay: 14,882.7e18   => swap reverts on minOut
```
The floor is built on `convertToAssets` — a depth-blind, fee-blind NAV read. On a real pool a large request breaches `minOut` at an unmoved mid-price. `MockAMMAdapter`'s infinite depth is precisely what hides this.

**INV-1b, market — the quoted floor is not honoured after a gap**
`testPoc_INV1_market_floorBreachesAcrossQuoteExecuteGap`
```
netGuaranteed quoted at T1  : 19,602e18
shares still held at T2     :      364.0e18
shares the quoted gross needs: 39,600e18
delivered at T2             :      181.9e18   <-- 0.93% of the guarantee
```
Sequence: two clients funded → consumer STATICCALLs the preview → vault halves in value (arbitrage repegs) → the *other* client exits first → the consumer executes. `_exitFloor`'s share-balance cap did not bind at quote time and does at execution, so `minOut` silently collapses with it and the swap succeeds far below the quoted floor. **No revert, no event, no signal** — the consumer that trusted `netGuaranteed` eats a 99% shortfall.

**INV-4, market — over-delivery**
`testPoc_INV4_market_overDelivery` (market bids the share at a 5% premium to NAV)
```
principal debited   : 10,101.0e18
underlying delivered: 10,575.1e18
```
`_withdrawInternal`'s stated protocol-favouring rule ("principal is decremented by the REQUESTED amount … any shortfall stays as protocol-owned yield") is one-directional: it books the downside but pays out the upside. The 474e18 surplus is paid from the commingled position rather than booked as yield, i.e. from the other clients' backing.

---

## 4. Anti-vacuity — reached-state census

Foundry reverts handler state between invariant runs, so per-run reachability is asserted in `afterInvariant()` (`VACUOUS SEQUENCE: no exit executed in this run`) and the campaign-wide census is produced by `testCensus_ReachedStates` — one deterministic 1,500-action sequence per strategy that **aborts the run** (assert) if any guarded state was never written. Both PASS, i.e. every tripwire fired.

| Counter | Direct | Market |
|---|---|---|
| `r_deposits` | 174 | 62 |
| `r_exitsExecuted` | **203** | **62** |
| `r_exitReverts` | 175 | 113 |
| `r_zeroQuotes` | 206 | 413 |
| `r_belowParExits` | **198** | **23** |
| `r_exitFeeCharged` | **203** | **62** |
| `r_principalCapBind` | **86** | **88** |
| `r_shareCapBind` | 62 | 44 |
| `r_redeemThrottleBind` | **127** | **66** |
| `r_ammDepthBind` (>0.5% impact) | n/a | **110** |
| `r_deferredExits` (quote→execute gap) | **35** | **13** |
| `v1_floorBreaches` | 168 | 0 |
| `v1d_floorBreachesDeferred` | 35 | 1 |
| `v2_shortfall` / `v2_shortfallUnthrottled` | 391 / 387 | 108 / 108 |
| `v3_nonZeroQuoteRevert` | 127 | 90 |
| `v3d_deferredRevert` | 48 | 22 |
| `v4_overDelivery` | 0 | 13 |
| `v4_ledgerSkew` | 0 | 0 |
| final `positionValue` / `recordedPrincipal` | 25,535e18 / 36,996e18 (below par) | 0 / 0 |

Asserted tripwires (all satisfied on both strategies): ≥1 exit executed, ≥1 exit under a non-zero exit fee, ≥1 below-par exit, ≥1 principal-cap bind, ≥1 redemption-throttle bind, ≥1 deferred (quote-then-execute) exit.

**No result in this report is vacuous.** The two HOLDS rows sit on campaigns whose census shows 62–203 executed exits, 23–198 of them below par, all of them under a live exit fee.

---

## 5. Reading guide for triage

- **The direct-strategy INV-1 breach is not new in kind** — it is the known "base default returns the capped identity" issue, now bounded: it fires on **every** exit from a fee-charging vault (168 atomic + 35 deferred = **all 203** executed exits in the census), with no revert and no signal.
- **The market-override INV-1b breach is new.** The pattern pass could not decide whether the override's floor survives real exit fees and finite depth. It survives *atomically* (256k calls, no counterexample) and **fails across a quote→execute gap** — which is the only consumption pattern a STATICCALL preview has. Any consumer that quotes in one call and settles in another is unprotected.
- **INV-3 is the dominant failure mode on both strategies** and it is a *false green*: `netGuaranteed > 0` is documented as the honest report that the exit is quotable, and it does not imply the exit is executable. Three independent causes reproduce it: vault redemption throttle (direct), finite AMM depth (market), and share-balance cap drift (both).
- **INV-2 fails even against throttle-free capacity** (`v2_shortfallUnthrottled` 387 direct / 108 market), so it cannot be dismissed as an artifact of the mock's throttle.
- **INV-4 splits cleanly**: ledger conservation holds everywhere (0 skews in 256k calls × 2), and the value-side protocol-favouring rule holds on the direct strategy but **fails on the market strategy** whenever the AMM bids above NAV.
- Candidates to hand to the **symbolic-analyzer** for an actual proof rather than a clean fuzz: market INV-1 atomic (is `_exitFloor` ≡ the inline `minOut` at `:245-246` for all inputs, including the rounding?), and direct INV-4 over-delivery.
