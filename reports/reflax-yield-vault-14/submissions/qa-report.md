# QA Report — reflax-yield-vault (run reflax-yield-vault-14)

**Scope:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, `src/AMMAdapters/CurveAMMAdapter.sol`, `src/AYieldStrategy.sol`
**Baseline → HEAD:** `2306719` → `2f6774d` (story-045 `relinquishPrincipal` primitive + story-046 deposit/withdraw hoist)
**Mode:** regression scan reconciled against `reports/ledgers/reflax-yield-vault.json`

This document bundles every open Low-severity and Centralization finding for the project into a single QA report, per C4 convention. The headline item this run is **QA-09** (orphaned-value-after-last-relinquish), a non-obvious operational footgun newly surfaced by the `relinquishPrincipal` primitive. All other Low/QA items are open carryovers from prior runs, reconciled by the ledger this run (`lastSeenRun` bumped only — no status changes, no regressions). The automated 4naly3er gas/QA baseline is attached as an appendix (`4naly3er-report.md`).

Out of this bundle by design:
- **L-02** (unbounded skim loop) — triaged **wont-fix** (author: never more than ~3 clients).
- **L-10** (setRoute uninitialized `lastToken`) — triaged **false-positive** (CODE-004 refutation: the loop always runs and `path[0]==tokenIn` is required non-zero, so `lastToken` is always assigned before use).
- **F-01 / F-02 / F-03** (faithfulness / spec deviations) — routed to the dedicated **spec-conformance** report (Law 2), not the QA bundle.
- **M-01-run12** (realizable-solvency) — **false-positive**, collapsed into acknowledged M-02; its honest QA residual is retained here as QA-08.

---

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 18 |
| Centralization | 1 |
| QA / Informational | 9 |
| **Total** | **28** |

### Low Risk

| ID | Title |
|----|-------|
| [L-01](#l-01-slippagetolerancebps-default-0-and-no-sane-upper-cap) | `slippageToleranceBps` default-0 and no sane upper cap |
| [L-03](#l-03-no-aggregate-cap-on-per-client-set-aside-buffers) | No aggregate cap on per-client set-aside buffers |
| [L-04](#l-04-set-aside-buffer-persists-after-deauthorization) | `setAsideBufferSize` persists after deauthorization and silently resurrects |
| [L-05](#l-05-surplusskimmed-under-represents-buffered-path-beneficiaries) | `SurplusSkimmed` under-represents buffered-path beneficiaries |
| [L-06](#l-06-skimsurplus-return-value-semantics-are-path-dependent) | `skimSurplus` return-value semantics are path-dependent |
| [L-07](#l-07-setroute-endpoint-only-validation) | `setRoute` endpoint-only validation (accepts `tokenIn==tokenOut`, internal zero-gap segments) |
| [L-08](#l-08-single-step-ownership-transfer-ownable-vs-ownable2step) | Single-step ownership transfer (`Ownable` vs `Ownable2Step`) |
| [L-09](#l-09-erc4626-rate-read-twice-in-a-tx-can-revert-for-time-weighted-vaults) | ERC4626 rate read twice in a tx can revert for time-weighted vaults |
| [L-11](#l-11-totalbalanceof-and-principalof-use-inconsistent-data-sources) | `totalBalanceOf` / `principalOf` use inconsistent data sources |
| [L-12](#l-12-curveammadapterswap-does-not-re-verify-amountout--minamountout) | `CurveAMMAdapter.swap` does not re-verify `amountOut >= minAmountOut` |
| [L-13](#l-13-_totalwithdraw-marks-migration-complete-on-floor-to-zero-shares) | `_totalWithdraw` marks migration complete on floor-to-zero shares |
| [L-01-run11](#l-01-run11-cei-violation-in-_withdrawinternal) | CEI violation in `_withdrawInternal` / `_totalWithdraw` |
| [L-02-run11](#l-02-run11-residual-allowance-accumulation-on-partial-revert) | Residual AMM allowance accumulation on partial revert |
| [L-03-run11](#l-03-run11-emergencywithdraw-lacks-nonreentrant) | `emergencyWithdraw` lacks `nonReentrant` |
| [L-04-run11](#l-04-run11-nonreentrant-not-first-modifier) | `nonReentrant` not the first modifier across entry points |
| [L-05-run11](#l-05-run11-constructor-_owner-shadowing) | Constructor `_owner` shadowing across three contracts |
| [L-06-run11](#l-06-run11-withdrawalexecuted-emits-stale-phase-1-amount) | `WithdrawalExecuted` emits the stale Phase-1 cached amount |
| [L-07-run11](#l-07-run11-withdrawasowner-event-omits-drained-client) | `withdrawAsOwner` event omits the drained client identity |

### Centralization

| ID | Title |
|----|-------|
| [C-01](#c-01-centralization--owner-power-bundle) | Centralization / owner-power bundle |

### QA / Informational

| ID | Title |
|----|-------|
| [QA-09](#qa-09-orphaned-vault-value-after-the-last-relinquishprincipal-new-this-run) | **Orphaned vault value after the last `relinquishPrincipal` (NEW this run)** |
| [QA-01](#qa-01-abiencodepacked-with-dynamic-types-in-revert-message-hashing) | `abi.encodePacked` with dynamic types in revert-message hashing |
| [QA-02](#qa-02-blocktimestamp-drives-the-two-phase-withdrawal-window) | `block.timestamp` drives the two-phase withdrawal window |
| [QA-03](#qa-03-unit-mismatch-percent-buffer-vs-bps-slippage) | Unit mismatch: percent buffer vs. bps slippage |
| [QA-04](#qa-04-whennotpaused-blocks-totalwithdrawal) | `whenNotPaused` blocks `totalWithdrawal` |
| [QA-05](#qa-05-curveammadapter-has-no-rescuesweep) | `CurveAMMAdapter` has no rescue/sweep |
| [QA-06](#qa-06-setclient-ignores-enumerableset-return-value) | `setClient` ignores `EnumerableSet` return value |
| [QA-07](#qa-07-skimsurplus-return-value-can-diverge-from-summed-events) | `skimSurplus` return value can diverge from summed events |
| [QA-08](#qa-08-skim-de-buffering-strips-the-depeg-cushion-owner-footgun) | Skim de-buffering strips the depeg cushion (owner footgun) |

---

## Low Risk Findings

### [QA-09] Orphaned vault value after the last `relinquishPrincipal` (NEW this run) <!-- id: ryv14qa9 -->

> Promoted to the top of the bundle as the only genuinely new operational hazard this run. Tracked in the ledger under the `QA-`/footgun series; severity is Low (operational-sequencing footgun, no insolvency).

**Location:** [`src/AYieldStrategy.sol#L507-L521`](../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L507-L521) — `relinquishPrincipal` / `_relinquishInternal` (residual) and `totalBalanceOf`
**Story:** story-045 (`relinquishPrincipal` primitive), story-046 (deposit/withdraw hoist)
**Classification:** Law-3 non-obvious owner/integrator footgun (in scope as an operational hazard). Value-conservation holds.

**Mechanism.** `relinquishPrincipal` decrements `totalDeposited` (and the caller's `clientBalances`) **without disposing the backing vault shares**. This share-untouched write-down is intended per the `IYieldStrategy` NatSpec (L34-41): on a later recovery the orphaned value is re-attributed to yield. The hazard arises at one edge the NatSpec does not contemplate — driving the **last** remaining principal to zero:

1. The last authorized client calls `relinquishPrincipal` repeatedly (or the owner calls the `…AsOwner` variant) until `clientBalances` and `totalDeposited` reach `0` while `getTotalShares() > 0` (the shares are deliberately left in place).
2. The residual vault value is now **un-attributable and frozen**: `_skimSurplus` early-returns whenever `totalDeposited == 0`, so no skim can distribute it. The value sits idle.
3. The instant fresh principal re-enters, that single depositor's `totalBalanceOf = totalValue * principal / totalDeposited` momentarily inflates to reflect the **entire** residual position (the new principal is briefly the sole denominator).
4. A subsequent `skimSurplus` then delivers the **full residual** to that recipient.

**Impact.** Mis-attribution / sequencing hazard: residual yield value that belonged to the protocol's books is captured in full by whoever deposits first after a complete relinquish-to-zero. Crucially:

- **No value creation.** The Tier-3 value-conservation invariant holds across a 128k-call fuzz over both in-scope concrete strategies. This is an internal redistribution inside the protocol's own books — **not** insolvency, **not** a leak across the protocol boundary.
- **The beneficiary is protocol-owned.** `setClient` is `onlyOwner`; the recipient/next-depositor is an owner-curated client, never an external attacker. There is no third-party theft primitive here.

**The non-obvious footgun (Law 3).** The owner is trusted for *knowing* actions, but this consequence is *unknowing*. Apply the surprise test: a competent, non-malicious integrator who sequences a relinquish-to-zero while live residual shares remain would be **surprised** that (a) the residual silently freezes and (b) it is then handed in full to the first re-depositor rather than remaining attributed where they expect. Surprise ⇒ footgun ⇒ in scope. This is filed as an operational hazard with safe-config guidance, **not** as a "malicious owner could…" vector (which would be suppressed under Law 3). Per Law 1 it is parked visibly here rather than dropped, even though value-conservation holds.

**Documentation check.** NOT blessed. The `IYieldStrategy` NatSpec (L34-41) blesses the share-untouched write-down and the value-to-yield re-attribution "on recovery," but it presumes a *surviving recovery path* (a remaining client). It does not document the `totalDeposited == 0`-with-live-shares orphan, nor the re-capture-on-redeposit edge. No `designDecision` (including #2, requested-not-received, which is a withdraw-path rule) and no `systemAssumption` covers it; `knownIssuesCount = 0`.

**Recommendation.** Any one of the following closes the hazard:

1. **Dispose proportionally on relinquish** — redeem/burn the vault shares proportional to the principal being relinquished, so shares and `totalDeposited` move together and no residual is orphaned. *(Preferred — removes the edge entirely.)*
2. **Block or sweep the terminal case** — when a relinquish would drive `totalDeposited` to `0` while `getTotalShares() > 0`, either revert the final full relinquish or require an explicit owner sweep that attributes the residual to a protocol sink before zeroing.
3. **Document the sequencing rule** — if neither code path is adopted, document the residual-attribution rule explicitly: never relinquish-to-zero while live residual shares remain, and define who the residual belongs to on re-entry.

---

The remaining Low findings below are **open carryovers** reconciled against the ledger this run (`lastSeenRun` bumped to `reflax-yield-vault-14`, status unchanged). Each is stated briefly with its location and recommendation; the full carryover stubs for the items re-flagged by this run's scanners live under `reports/reflax-yield-vault-14/submissions/carryover/` (`L-01-run11`, `L-07`, `L-13`), and the originating finding records are linked per entry.

### [L-01] `slippageToleranceBps` default-0 and no sane upper cap <!-- id: ryv14l1 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L190-L195`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195) — `setSlippageTolerance`
**Source:** `reports/reflax-yield-vault-05/submissions/qa-report.md` (open since run-05)

`setSlippageTolerance` accepts any value with no upper bound and defaults to `0`. The default-0 is a fail-closed deploy footgun (zero tolerance can strand swaps), and the missing ceiling lets an owner set an unreasonably loose tolerance. The blast radius widened in story-043: the conservative-crediting haircut `creditedPrincipal = amount * (MAX_BPS - slippageToleranceBps)/MAX_BPS` now also binds depositor credited principal to this uncapped value. **Recommendation:** enforce a hard sane upper cap (e.g. a few hundred bps) and a non-zero default in the setter; document the deposit-side haircut in the design registry.

### [L-03] No aggregate cap on per-client set-aside buffers <!-- id: ryv14l3 -->

**Location:** [`AYieldStrategy.sol#L253-L259`](../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L253-L259) — `setSetAsideBuffer`
**Source:** `reports/reflax-yield-vault-07/findings/low/L-03.json` · extends C-01

Per-client buffer percentages have no aggregate cap, so the total set-aside can reach 100% of `underlyingReceived`, silently reducing the recipient's take to zero with no revert. **Recommendation:** enforce `Σ bufferShares ≤ 100%` (or a configured ceiling) in the setter.

### [L-04] `setAsideBufferSize` persists after deauthorization and silently resurrects <!-- id: ryv14l4 -->

**Location:** [`AYieldStrategy.sol#L183-L259`](../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L183-L259) — `setClient` / `setSetAsideBuffer`
**Source:** `reports/reflax-yield-vault-07/findings/low/L-04.json` · extends C-01

A client's `setAsideBufferSize` is not cleared on deauthorization, so re-authorizing the same address silently resurrects the old buffer value. **Recommendation:** zero the buffer on `setClient(..., false)`, or require it to be re-set on re-auth.

### [L-05] `SurplusSkimmed` under-represents buffered-path beneficiaries <!-- id: ryv14l5 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L484-L519`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L484-L519) — `_accrueSurplusShares` / `_distributeBuffer`
**Source:** `reports/reflax-yield-vault-07/findings/low/L-05.json`

No event records the per-client buffer redirection on the buffered path, so off-chain accounting cannot reconstruct who received the set-aside. **Recommendation:** emit a per-client buffer-distribution event.

### [L-06] `skimSurplus` return-value semantics are path-dependent <!-- id: ryv14l6 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L432-L521`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L432-L521) — `_skimSurplus` / `_distributeBuffer`
**Source:** `reports/reflax-yield-vault-07/findings/low/L-06.json`

The fast path returns the raw swap output while the buffered path returns the recipient receipt; the NatSpec does not disambiguate, inviting integrator confusion. **Recommendation:** document the path-dependence or normalize the return value.

### [L-07] `setRoute` endpoint-only validation <!-- id: ryv14l7 -->

**Location:** [`CurveAMMAdapter.sol#L62-L89`](../../../lib/reflax-yield-vault/src/AMMAdapters/CurveAMMAdapter.sol#L62-L89) — `setRoute`
**Source:** `reports/reflax-yield-vault-07/findings/low/L-07.json` · extends C-01 · carryover stub: `carryover/L-07-CARRYOVER.md`

`setRoute` validates only the endpoints; it accepts `tokenIn == tokenOut` and paths with internal zero-gap segments, and does not validate `swapParams` coin indices, the `pools` array, or reverse-route inverse-consistency on-chain — relying entirely on off-chain verification. **Recommendation:** add on-chain structural validation of the route (reject `tokenIn==tokenOut`, validate intermediate segments and `swapParams`). *(The bundled `lastToken` uninitialized-local sub-flag is a separate false positive, tracked as L-10, not reopened.)*

### [L-08] Single-step ownership transfer (`Ownable` vs `Ownable2Step`) <!-- id: ryv14l8 -->

**Location:** [`CurveAMMAdapter.sol`](../../../lib/reflax-yield-vault/src/AMMAdapters/CurveAMMAdapter.sol), [`AYieldStrategy.sol`](../../../lib/reflax-yield-vault/src/AYieldStrategy.sol) — `transferOwnership`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-08-ownable-single-step-ownership-transfer.json`

All three contracts use single-step `Ownable`, so an ownership transfer to an incorrect address is irreversible. **Recommendation:** adopt `Ownable2Step`.

### [L-09] ERC4626 rate read twice in a tx can revert for time-weighted vaults <!-- id: ryv14l9 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L449-L487`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L449-L487) — `_skimSurplus`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-09-skim-surplus-stale-converttoassets-dos.json`

Two consecutive `convertToAssets` calls in the same transaction may return different rates for a time-weighted/rate-smoothing vault, causing a revert (skim DoS). Re-observed this run as the intra-tx rate-drift facet of the M-02 NAV cluster (acknowledged, bounded). **Recommendation:** snapshot the rate once per call and reuse it.

### [L-11] `totalBalanceOf` and `principalOf` use inconsistent data sources <!-- id: ryv14l11 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L129-L156`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L129-L156) — `totalBalanceOf` / `principalOf`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-11-total-balance-of-principal-of-inconsistent-sources.json`

`totalBalanceOf` reads live vault price while `principalOf` reads static accounting value; the paired views can return negative yield to downstream integrators. Re-observed as the paired-view facet of the M-02 NAV cluster (acknowledged). **Recommendation:** document the view-source asymmetry or derive both from a consistent basis.

### [L-12] `CurveAMMAdapter.swap` does not re-verify `amountOut >= minAmountOut` <!-- id: ryv14l12 -->

**Location:** [`CurveAMMAdapter.sol#L120-L141`](../../../lib/reflax-yield-vault/src/AMMAdapters/CurveAMMAdapter.sol#L120-L141) — `swap`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-12-curve-amm-adapter-missing-amountout-check.json`

The adapter delegates the slippage-floor enforcement entirely to Curve Router NG and does not independently assert `amountOut >= minAmountOut` after the router returns. **Recommendation:** add a defensive post-swap floor check.

### [L-13] `_totalWithdraw` marks migration complete on floor-to-zero shares <!-- id: ryv14l13 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L404-L435`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435) — `_totalWithdraw`
**Source:** `reports/reflax-yield-vault-12/findings/low/L-13-total-withdraw-false-migration-complete.json` · carryover stub: `carryover/L-13-CARRYOVER.md`

For a tiny-balance client whose `sharesToSell` floors to `0`, the migration is recorded as executed even though principal is left on the books and nothing moved. Benign exact-zero guard, not attacker-griefable, no value duplication. **Recommendation:** treat a zero-share snapshot as a no-op (skip the "executed" bookkeeping) or revert.

### [L-01-run11] CEI violation in `_withdrawInternal` / `_totalWithdraw` <!-- id: ryv14l14 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L338-L375`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L338-L375) — `_withdrawInternal` (twin: `_totalWithdraw`)
**Source:** `reports/reflax-yield-vault-11/findings/low/L-01-cei-violation-withdraw-internal.json` · carryover stub: `carryover/L-01-run11-CARRYOVER.md`

State is written after two external calls (swap + transfer), so safety relies entirely on `nonReentrant` being preserved on every caller. Benign under the non-hooked-ERC20 trust model (mutex present, no attacker callback), retained as a documented latent assumption. **Recommendation:** reorder to checks-effects-interactions so correctness does not hinge solely on the guard.

### [L-02-run11] Residual AMM allowance accumulation on partial revert <!-- id: ryv14l15 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L315-L472`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L315-L472) — `_depositInternal` / `_withdrawInternal` / `_totalWithdraw` / `_skimSurplus`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-02-safe-increase-allowance-residual-accumulation.json`

`safeIncreaseAllowance` is called before every AMM swap without resetting to zero afterward; residual approvals can accumulate under partial-revert conditions. **Recommendation:** reset the adapter allowance to zero after each swap, or use exact-amount approvals.

### [L-03-run11] `emergencyWithdraw` lacks `nonReentrant` <!-- id: ryv14l16 -->

**Location:** [`AYieldStrategy.sol#L304`](../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L304) — `emergencyWithdraw`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-03-emergency-withdraw-no-reentrancy-guard.json`

`emergencyWithdraw` is the only state-changing entry point without a `nonReentrant` guard, inconsistent with the rest of the surface; latent risk if the vault token implements transfer callbacks. **Recommendation:** add `nonReentrant` for consistency and defense-in-depth.

### [L-04-run11] `nonReentrant` not the first modifier across entry points <!-- id: ryv14l17 -->

**Location:** `AYieldStrategy.sol#L319,L366` and [`ERC4626MarketYieldStrategy.sol#L229-L279`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L229-L279) — multiple
**Source:** `reports/reflax-yield-vault-11/findings/low/L-04-nonreentrant-modifier-ordering.json`

Across six functions `nonReentrant` is not declared first; modifiers preceding it execute with the mutex not yet locked. Defense-in-depth only this run (every preceding modifier is a no-external-call auth check). **Recommendation:** place `nonReentrant` first in each modifier list.

### [L-05-run11] Constructor `_owner` shadowing across three contracts <!-- id: ryv14l18 -->

**Location:** [`CurveAMMAdapter.sol`](../../../lib/reflax-yield-vault/src/AMMAdapters/CurveAMMAdapter.sol), [`AYieldStrategy.sol`](../../../lib/reflax-yield-vault/src/AYieldStrategy.sol), [`ERC4626MarketYieldStrategy.sol`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol) — `constructor`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-05-constructor-owner-shadowing.json`

The constructor parameter `_owner` shadows the inherited `Ownable._owner` state variable in all three contracts. **Recommendation:** rename the parameter (e.g. `owner_`) to remove the shadow.

### [L-06-run11] `WithdrawalExecuted` emits the stale Phase-1 amount <!-- id: ryv14l19 -->

**Location:** [`AYieldStrategy.sol#L501`](../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L501) — `_executeWithdrawal`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-06-withdrawal-executed-event-stale-amount.json`

The event emits the Phase-1 cached balance rather than the amount actually transferred in Phase-2, producing misleading on-chain records. **Recommendation:** emit the realized transfer amount.

### [L-07-run11] `withdrawAsOwner` event omits the drained client <!-- id: ryv14l20 -->

**Location:** [`ERC4626MarketYieldStrategy.sol#L279`](../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L279) — `withdrawAsOwner`
**Source:** `reports/reflax-yield-vault-11/findings/low/L-07-withdraw-as-owner-missing-client-event-field.json`

`withdrawAsOwner` debits a client's principal while sending tokens to an arbitrary recipient, but no event field records *which* client was drained, hampering off-chain attribution. **Recommendation:** add the debited-client address to the emitted event.

---

## Centralization Risks

### [C-01] Centralization / owner-power bundle <!-- id: ryv14c1 -->

**Location:** `ERC4626MarketYieldStrategy.sol` + `AYieldStrategy.sol` + `CurveAMMAdapter.sol` — multiple privileged setters and withdrawal paths
**Source:** `reports/reflax-yield-vault-05/submissions/qa-report.md` (open since run-05) · extended by L-03, L-04, L-07

This finding aggregates the project's owner-power surface. Under the project's self-owned trust model the owner is trusted for knowing actions (Law 3), so this is documented as a centralization property rather than an exploit; the entries below are the specific privileged levers integrators and depositors should be aware of.

**Privileged surface:**
- `setRoute` — owner defines the AMM swap path with only off-chain validation (see L-07).
- `setSlippageTolerance` — uncapped; can zero or loosen the swap floor and the deposit-side credited-principal haircut (see L-01).
- `setClient` / authorized-client `EnumerableSet` — owner curates the entire beneficiary set; surplus and skim beneficiaries are owner-chosen.
- `setSetAsideBuffer` — per-client buffer percentages with no aggregate cap (see L-03) and stale-on-re-auth persistence (see L-04).
- `depositAsOwner` / `withdrawAsOwner` — `withdrawAsOwner` debits client principal and bypasses the 24-hour `totalWithdrawal` timelock (run-11 H-03, downgraded to centralization: the owner already holds `totalWithdrawal` + `emergencyWithdraw` escape hatches to the same funds, so the timelock is cosmetic by design in an owner-trusted model).
- `emergencyWithdraw` — transfers vault shares to the owner; the accounting desync vs `clientBalances`/`totalDeposited` is a by-design migration pattern but a latent hardening note under partial-emergency-then-continue (run-11 H-01, downgraded to centralization).
- Two-phase `totalWithdrawal` — owner-initiated migration primitive.

**Impact.** Depositors and integrators rely on the owner not misconfiguring these levers; several have non-obvious consequences captured as the related Lows above. There is no third-party theft path — the concern is the breadth of the owner-power envelope.

**Recommendation.** Document the trust model explicitly for integrators; add the missing setter bounds called out in L-01 and L-03; consider a timelock/multisig over the highest-impact setters (`setRoute`, `setClient`, `setSlippageTolerance`) and over `withdrawAsOwner` to make the 24-hour migration timelock substantive rather than cosmetic.

---

## QA / Informational

> QA-09 (orphaned-value-after-last-relinquish) is documented as a full section under **Low Risk** above, as the headline new item. The remaining QA items are open carryovers, reconciled this run with no status change.

### [QA-01] `abi.encodePacked` with dynamic types in revert-message hashing <!-- id: ryv14qa1 -->

**Location:** `AYieldStrategy.sol#L340` — *Source: `reports/reflax-yield-vault-11/findings/qa/QA-01-abi-encodepacked-revert-message.json`*
`abi.encodePacked()` with dynamic-type arguments is passed to `keccak256`, but only for revert-message formatting — no collision attack surface. Informational; prefer `string.concat` / `abi.encode` if the value is ever consumed beyond a message.

### [QA-02] `block.timestamp` drives the two-phase withdrawal window <!-- id: ryv14qa2 -->

**Location:** `AYieldStrategy.sol#L441` — *Source: `reports/reflax-yield-vault-12/findings/qa/QA-02-block-timestamp-two-phase-window.json`*
`block.timestamp` gates the 24h waiting / 48h execution window. Load-bearing and intended; miner drift is negligible at this granularity. Informational.

### [QA-03] Unit mismatch: percent buffer vs. bps slippage <!-- id: ryv14qa3 -->

**Location:** `AYieldStrategy.sol#L253-L259` — *Source: `reports/reflax-yield-vault-12/findings/qa/QA-03-unit-mismatch-percent-vs-bps.json`*
`setAsideBufferSize` is a percent (0-100) while `slippageToleranceBps` is bps (0-10000). The inconsistent units are an owner footgun. **Recommendation:** standardize on bps, or add explicit NatSpec/range checks per setter.

### [QA-04] `whenNotPaused` blocks `totalWithdrawal` <!-- id: ryv14qa4 -->

**Location:** `AYieldStrategy.sol#L319` — *Source: `reports/reflax-yield-vault-12/findings/qa/QA-04-whennotpaused-blocks-totalwithdrawal.json`*
`totalWithdrawal` carries `whenNotPaused`, so a Global-Pauser pause blocks the two-phase migration until unpause (`emergencyWithdraw` remains as fallback). Informational; confirm this interaction is intended in the pause runbook.

### [QA-05] `CurveAMMAdapter` has no rescue/sweep <!-- id: ryv14qa5 -->

**Location:** `CurveAMMAdapter.sol#L120-L141` — *Source: `reports/reflax-yield-vault-12/findings/qa/QA-05-curveammadapter-no-rescue-sweep.json`*
The adapter has no rescue/sweep function, so accidentally-sent tokens or under-consume dust are stranded. **Recommendation:** add an owner-gated `rescueTokens`.

### [QA-06] `setClient` ignores `EnumerableSet` return value <!-- id: ryv14qa6 -->

**Location:** `AYieldStrategy.sol#L187-L189` — *Source: `reports/reflax-yield-vault-12/findings/qa/QA-06-setclient-ignores-enumerableset-return.json`*
`setClient` ignores the `bool` returned by `EnumerableSet.add/remove`, so idempotent re-adds or removal of a non-member silently succeed. **Recommendation:** check the return value and revert/emit on a no-op if exactness matters.

### [QA-07] `skimSurplus` return value can diverge from summed events <!-- id: ryv14qa7 -->

**Location:** `ERC4626MarketYieldStrategy.sol#L432-L521` — *Source: `reports/reflax-yield-vault-12/findings/qa/QA-07-skimsurplus-return-vs-event-divergence.json`*
The `skimSurplus` return (post-swap underlying delivered) can diverge from the sum of `SurplusSkimmed.amount` events (pre-swap vault-asset snapshot). Integration caveat; cross-references L-05/L-06. **Recommendation:** document the snapshot-vs-delivered distinction.

### [QA-08] Skim de-buffering strips the depeg cushion (owner footgun) <!-- id: ryv14qa8 -->

**Location:** `ERC4626MarketYieldStrategy.sol#L457-L521` — *Source: `reports/reflax-yield-vault-12/findings/qa/QA-08-skim-debuffer-world-c-owner-footgun.json`*
Routinely running `skimSurplus` strips the protective vault-rate over-collateralization buffer for zero upside, removing the depeg cushion ahead of a possible sUSDe discount. Law-3 owner-bounded operational hazard (the residual of the collapsed M-01-run12 Medium; under a beyond-tolerance discount all protocol withdrawal paths revert and loss only reaches funds via the owner's own `emergencyWithdraw` + OTC sale). **Recommendation:** do not routinely skim while depeg risk exists; retain a protocol-favoring buffer at skim time.

---

## Appendix: 4naly3er Automated Report

The canonical C4-style automated QA/gas report (4naly3er) was generated over the three in-scope contracts and is attached alongside this document:

- **`reports/reflax-yield-vault-14/submissions/4naly3er-report.md`**

It covers `ERC4626MarketYieldStrategy.sol`, `CurveAMMAdapter.sol`, and `AYieldStrategy.sol`, and reports **16 Gas-optimization categories**, **23 Non-Critical categories**, **11 Low categories**, and **1 Medium category** of automated findings. The automated Low/NC items overlap several manual findings above and should be read as the bot-report baseline, not as independently triaged findings:

- 4naly3er **L-1 / L-10** (2-step ownership / `Ownable2Step`) corroborate manual **L-08**.
- 4naly3er **L-4 / NC-3** (`abi.encodePacked` to a hash function) corroborate manual **QA-01**.
- 4naly3er **L-3 / NC-1** (missing `address(0)` checks) and **NC-12** (lack of checks in setters) sit alongside manual **L-01 / L-03**.
- 4naly3er **L-5 / L-7 / L-8** (division-by-zero, rounding, precision loss) are the automated view of the ERC4626 rate-read class captured in **L-09 / L-11**.
- 4naly3er **NC-9** (events should carry old+new values) and **NC-8 / NC-21** (missing indexed fields) align with the event-quality manual Lows **L-05 / L-06-run11 / L-07-run11**.

The automated Medium category (`L-9` PUSH0 / chain-compatibility class) is a deployment-target note, not a protocol exploit, and is left to the bot report. No automated finding surfaced a High/Medium protocol exploit beyond what the manual pipeline already adjudicated.

*Tooling note:* 4naly3er was run from `tools/4naly3er` against a writable mirror of the in-scope `src/` tree (with `@openzeppelin/` and `pauser/` remappings supplied) because `lib/` is strictly read-only and the project resolves the `pauser/` remapping via `foundry.toml` rather than `remappings.txt`. The mirror symlinks the upstream sources unchanged; no source file was modified.
