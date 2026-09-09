# Deduplication — reflax-yield-vault run-17 @ `cdd0743`

- **Project**: reflax-yield-vault · **Commit**: `cdd0743` `[story-050] previewExitFor on IYieldStrategy`
- **Ledger**: `reports/reflax-yield-vault/ledger.json` — 49 entries (38 open, 1 fixed, 1 wont-fix, 6 false-positive, 2 downgraded-to-centralization, 1 merged), `lastRun: reflax-yield-vault-16` @ `0110ce44`
- **Date**: 2026-08-31
- **Inputs**: `story-faithfulness.md` (F-01-050, F-02-050), `code-scan.md` (CODE-01…07), `econ-scan.md` (ECON-17-01/02, ECON-003/004/005), `pattern-match.md` (PM-1…PM-6), `static-analysis.md` (SA-001…021), `invariant-testing.md` (INV-1/1b/2/2b/3/3b/4), `symbolic-analysis.md`, `contract-profiles.md`
- **Parked channel**: `reports/reflax-yield-vault/17/manual-review.json` — **8 entries** (Law 1: nothing plausibly-security-relevant left this run invisibly)
- **Ledger NOT modified** (finding-manager's lane). The ledger's own recall gap stands: `lastRun` is still `-16`, so no run-17 shape can reconcile by fingerprint until finding-manager runs.

**Result: 16 findings** (from 38 candidate inputs) + 4 folds into existing open ledger entries + 15 outright removals (12 ledger/OOS duplicates, 3 tool noise) + 8 parked.

---

## 0. Consolidation axis (stated, because it drives every merge below)

Nine of the run's candidates are the same sentence — *"`netGuaranteed` does not mean what the NatSpec
says it means"* — but they split cleanly on **how the consumer is harmed**, which is also the axis on
which the **mitigations differ**:

| Harm | Findings | Consumer sees |
|---|---|---|
| **Silent under-delivery** — no revert, no event, no signal | DEDUP-17-01, -02, -03, -05, -06 | a green quote and a short balance |
| **False green → guaranteed revert** (liveness) | DEDUP-17-04, -08 | a green quote and a bricked call |

Merging across that axis would let a fix for one harm read as a fix for the other. Within each harm,
findings are merged **only** where one mitigation closes all instances; where three mechanisms need
three code changes they are carried as **enumerated instances inside one finding**, each with its own
PoC and its own sub-remedy, so a partial fix is visibly partial rather than silently complete.

---

## 1. Findings

### DEDUP-17-01 — the base default's `netGuaranteed` is a ceiling, not a floor, when the share-balance cap binds (direct strategy)

- **Merged inputs**: `F-01-050` (FAITH-001, story-faithfulness) + `ECON-17-01` §1.1 single-client leg (`testE2_SingleClientQuoteIsFalseByTheFullDeficit`)
- **Proposed severity (carried forward)**: **Low today · potential-Medium on wiring** (story pass), catalogued pattern severity HIGH
- **Contract/function**: `src/AYieldStrategy.sol:571-583` `previewExitFor`, as reached through `src/concreteYieldStrategies/ERC4626YieldStrategy.sol`
- **Evidence**: story-faithfulness probe (quote `1000e18`, delivered `500e18` after a 50% vault loss); `workspace/reflax-yield-vault/test/poc-run17-econ-exit-preview.t.sol::testE2_SingleClientQuoteIsFalseByTheFullDeficit` (PASS)
- **Pattern**: `YIELD-PRINCIPAL-ACCOUNTING-SKEW` (HIGH) — `vulnerableWhen` bullet 2 matches verbatim
- **Ledger relation**: none — new fingerprint surface (`previewExitFor` did not exist at `0110ce44`).
- **Merge rationale**: `testE2` is the econ pass independently reproducing the story pass's probe against the same contract, same function, same mechanism. Same `contract:function:rootCauseClass` ⇒ Phase-1 duplicate; econ itself says *"recorded here as independent confirmation, not as a new finding"*.

> **NON-COLLAPSE (directive, honoured).** DEDUP-17-01 must **not** absorb DEDUP-17-03 (CODE-01). This
> finding is *the base default not modelling the share cap at all*; DEDUP-17-03 is *the market override
> modelling it correctly and still being wrong across clients*. **A fix that copies `_exitFloor` into
> the base closes this finding and SPREADS DEDUP-17-03 to the direct strategy.**

> **Downgrade basis, and its limits.** `symbolic-analysis.md` §9 confirms `StableStakerV2._isUnderwater`
> strictly dominates the cap-binding condition (696 M-state exhaustive integer search, 210 M cap-binding
> states, 0 counterexamples; 150 k fuzz + 105-case grid against the real contracts in the real two-client
> topology; **not** a Halmos proof — the symbolic tier returned **0 `[PASS]`**). Cite that basis, never
> "symbolically verified". The dominance is **contingent** on `p ≤ D` (`AYieldStrategy.sol:48`) and
> `a ≤ p` (`:772-776`), neither pinned by any test → parked as `MR-17-05`.

---

### DEDUP-17-02 — both previews are built on the fee-free `convertToAssets`, so the published "guarantee" is breached on every exit from a fee-charging vault

- **Merged inputs**: `ECON-004` (econ, "ECON-A surface extension") + `INV-1` direct/atomic violation (Tier-3) + `PM-F-01-050` probe `testPM3_DirectPreviewOverQuotesOnExitFeeVault` + `CODE-07`'s `_exitFloor` call-site half (the fee leg only)
- **Proposed severity (carried forward)**: **Low** — with the **F-16-003 Medium re-evaluation gate live and TRIPPED this run**
- **Contract/function**: `src/AYieldStrategy.sol:571-583` `previewExitFor` + `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:127-137` `_exitFloor`
- **Evidence**:
  - `workspace/reflax-yield-vault/test/invariant/RealisticExitPreviewPoc.t.sol::testPoc_INV1_direct_exitFeeBreachesFloor` (PASS) — quoted `1000e18`, delivered `990e18` at a 1% exit fee; census shows it fires on **203 of 203** executed direct exits (168 atomic + 35 deferred).
  - `workspace/reflax-yield-vault/test/poc-run17-pattern-match.t.sol::testPM3_DirectPreviewOverQuotesOnExitFeeVault` (PASS) — at a 5% redeem fee: `netGuaranteed 1000e18`, `previewRedeem 950e18`, `_positionValue 1000e18`, delivered `950e18`.
- **Load-bearing addition kept from the pattern pass**: `assertEq(posValue, net)` passes, so **F-01-050's own proposed stronger remedy (`cap by _positionValue()`) is numerically identical to the number it was meant to correct** — `_positionValue()` is built on the same fee-blind conversion (`ERC4626YieldStrategy.sol:61-63`). Any fix must read a **fee-aware** quote. `ERC4626YieldStrategy` already exposes one (`previewRedeem`, `:83-85`) and story-050 criterion 10 deliberately forbade `previewExitFor` from using it, so the contract now ships **two exit previews that disagree by the vault's exit fee, with the newer one carrying the word "guarantees"**.

> **RE-FILE DISCLOSURE — ledger `ECON-A` / `c50c08f9ee587c02e38e089dd7aa2ee3ae64a9623bb1e6f1d138154b21fc7887` (Low, `open`) and `F-16-003` / `c705bd94ec78fd233ec72a1599f746cfe051b4357aaf5851fb041abd41d55d98` (faithfulness, `open`).**
>
> `ECON-A`: *"ERC4626YieldStrategy credits principal via fee-blind convertToAssets, persistently over-stating redeemable NAV."* Its `severityScaling` field, verbatim:
>
> > "Magnitude-bound to the EXTERNAL vault fee/curve config, NOT this contract. Over-credit scales LINEARLY with vault exit fee (PoC: 1% fee -> 10e18 over-credit on 1000e18). A future strategy wired to a non-trivial-exit-fee vault makes this SAME code path a MEDIUM. Retain the F-03 StableStaker:786 integration gate with 'magnitude = external vault fee config' annotation (severity-auditor carry-forward)."
>
> `F-16-003`'s live gate, quoted verbatim from `reports/reflax-yield-vault/16/submissions/spec-conformance.md:65`:
>
> > "the gate must re-weigh severity against the *actual* vault wired at the integration point, not inherit ECON-A's stale Low."
>
> **Re-file basis.** Same primitive (fee-blind `convertToAssets`), **different function, different claim, different consequence**: `ECON-A` is a *deposit-side crediting* over-statement on `_acquireShares`; this is an *exit-side published delivery guarantee* on a function that did not exist at `ECON-A`'s commit. `previewExitFor` mints a **fresh fingerprint dedup cannot catch**, so this is disclosed rather than silently filed and rather than silently suppressed. **Run-17 trips `F-16-003`'s gate**: the deployed wiring is Tokemak `autoDOLA`/`autoUSD` (run-16), and a spec-conformant exit fee costs the full fee percentage of the "guarantee" on **every** exit, not sub-bps at the credit. **Recommendation to finding-manager: file as a new entry cross-linked to `ECON-A` and `F-16-003` (do NOT merge into `ECON-A`, whose fingerprint is `_acquireShares`), and do NOT inherit `ECON-A`'s stale Low without the gate's re-weigh.** Adjacent open entries: `L-11` `abd28a2f46c1…`, `L-09` `c6ec246f7e58…`.

> **Kept separate from DEDUP-17-01 deliberately.** Same line of code, different root cause (fee-blindness vs. not modelling the share cap), different ledger relation, and different fixes — DEDUP-17-01's share-aware cap does not close this, as `testPM3` proves.

---

### DEDUP-17-03 — `netGuaranteed` is floored against the GLOBAL share balance while `grossToRequest` is capped per account, so N clients are each quoted a floor only one can be paid

- **Merged inputs**: `CODE-01` (market override) + `ECON-17-01`/`ECON-002` multi-client leg (base default, N× over-issue) + `INV-2` and `INV-2b` violations on **both** strategies
- **Proposed severity (carried forward)**: **Low today · potential-Medium on wiring**
- **Contract/function**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:127-186` `_exitFloor`/`previewExitFor`; `src/AYieldStrategy.sol:571-583` `previewExitFor` (base)
- **Evidence**:
  - `poc-run17-preview-exit.t.sol::testH5_TwoClientsQuotedTheSameShares` (PASS) — market: two `980.1e18` floors against a `1000e18` position (Σ = 1.96×); user2 receives `20e18` (2.0% of quote) and is debited its full `990e18` via the protocol-favouring write-down at `AYieldStrategy.sol:781-783`.
  - `poc-run17-econ-exit-preview.t.sol::testE1_FirstComeFirstServedAcrossClients` (PASS) — direct: Σ floors = 2× position; clientB receives `0` and is debited in full.
  - `test/invariant/RealisticExitPreviewPoc.t.sol::testPoc_INV2_direct_aggregateQuotesExceedCapacity` (PASS) — 3 clients, Σ `netGuaranteed` `30,000e18` vs realizable `26,730e18` (+12.2%). Census: `v2_shortfall` 391 direct / 108 market, and `v2_shortfallUnthrottled` 387/108 — **so it is not an artifact of the mock's redemption throttle.**
- **Merge rationale**: `CODE-01`, `ECON-002` and `INV-2/2b` are one root cause — *a per-account quote floored against a shared, unreserved global resource* — on two contracts. One mitigation (apportion the cap pro-rata, or state in the NatSpec that the floor is **non-exclusive**) closes all three. Instances: market `_exitFloor:130`, base `previewExitFor:583`.
- **Suppression scope, stated so it is not over-read**: the *standalone client-vs-client value-transfer* framing is **suppressed** under the minter-cushion memo — `MigrateStableStakerMainnet.s.sol:496`/`:595` wire `PhusdStableMinter` **and** `StableStaker` to the same strategy, the minter has no strategy-withdraw path and so cannot race, and no per-client cap is recommended. **What survives and is filed is the over-issued *guarantee*** (a view function that legitimises an FCFS drain by telling each client it will be paid), not a user-vs-user loss. **Reopen trigger (WATCH-17-E2):** if any future story gives `PhusdStableMinter` a strategy-exit path, the suppression premise dies and this becomes a live Medium immediately.

> **NON-COLLAPSE (directive, honoured).** Not merged into DEDUP-17-01. See the note there.

> **RE-FILE DISCLOSURE — ledger `M-03` / `3c8331040bba6a7b62e136e08e6bb36f4c992ca6186b5dd21913e7e981b96434` (Medium, `merged` into `M-02`).** Title: *"Requested-not-received decrement socialises slippage, causing last-withdrawer shortfall."* Its merge note, verbatim:
>
> > "No standalone loss primitive; amplifies M-02's slippage leak by concentrating the share-backing deficit onto the last withdrawer via the requested-not-received decrement. Confirmed by poc-validation.md counterfactual (fair deposits + adverse withdrawals only -> no concentrated shortfall). **Fingerprint retained so a future standalone recurrence can still be matched.**"
>
> **Re-file basis:** same *shape*, **different primitive**. `M-03` is on `ERC4626MarketYieldStrategy._withdrawInternal` with an **AMM-slippage** deficit bounded at `slippageToleranceBps × tradeSize` and a `minOut` revert beyond it. The direct-strategy leg here is on `ERC4626YieldStrategy`, the deficit source is an **unbounded vault drawdown**, and `vault.redeem` carries **no `minOut` at all** — no bound, no revert. `M-03` invites exactly this match. **`M-03` stays `merged`**; this is filed on the new `previewExitFor` surface, not as a re-open of `M-03`.

> **`M-01-run12` / `fdda8f53151a…` (`false-positive`, realizable-solvency collapse) is NOT re-escalated.** Its subject is vault-rate-vs-AMM-rate divergence on the market strategy; this finding is the vault position falling below booked principal, with no AMM in the path on the direct leg. Distinct root cause; the hard-guard (memory `reflax-yield-vault-realizable-solvency-collapse`) is honoured and `M-01-run12` is not cited as support.

---

### DEDUP-17-04 — `netGuaranteed > 0` is a false green: it does not imply `withdraw` is executable, on either strategy, for three independent reasons

- **Merged inputs**: `CODE-02` (AMM price blindness, market) + `PM-2` (vault redemption throttle, direct) + `INV-3` and `INV-3b` violations on both strategies + `INV-3` market finite-depth counterexample
- **Proposed severity (carried forward)**: **Low today · potential-Medium on wiring**
- **Contract/function**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:162-186` `previewExitFor`; `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:126-138` `_disposeShares` under the inherited base preview
- **Instances — enumerated, because each needs a DIFFERENT code change. A fix landing only one of these is an INCOMPLETE FIX, not a fix:**

  | # | Mechanism | Evidence | Sub-remedy |
  |---|---|---|---|
  | (a) | **AMM price blindness (market).** `IAMMAdapter` has exactly one member, a non-view `swap` (`IAMMAdapter.sol:11-23`); `CurveAMMAdapter` exposes no quote. `_exitFloor` is a pure function of vault state and is **provably invariant to AMM price**; `_disposeShares` passes that same number as `minOut` (`:246`) and `ICurveRouterNG.exchange` enforces it, so the call **reverts**. | `poc-run17-preview-exit.t.sol::testH2_QuoteIsInvariantToAMMPrice` (bit-identical quote across a 99% depeg) and `::testH2_HealthyQuoteThenWithdrawReverts` (quote `netGuaranteed 900e18` ≥ `netWanted`, `withdraw` reverts in the same block at a 10% discount / 1% tolerance) — both PASS | add a quote member to `IAMMAdapter` (wrap `ICurveRouterNG.get_dy`) and return `netGuaranteed = 0` when the live route cannot clear `minOut` |
  | (b) | **Vault redemption throttle (direct).** Zero occurrences of `maxRedeem`/`maxWithdraw` in first-party `src/`; `_disposeShares` calls `vault.redeem` unconditionally. | `poc-run17-pattern-match.t.sol::testPM2_DirectPreviewGreenWhileWithdrawGuaranteedToRevert` (PASS) — quoted `900e18` guaranteed, `maxRedeem` `10e18`, `withdraw` reverts; and `RealisticExitPreviewPoc.t.sol::testPoc_INV3_direct_redeemThrottleBricksQuotedExit` (PASS) — `5000e18` quoted, `maxRedeem` `1000e18`, `ExceededMaxRedeem`. Census `r_redeemThrottleBind` 127 direct / 66 market | consult `maxRedeem`/`maxWithdraw` in both the preview and `_disposeShares` |
  | (c) | **Finite AMM depth (market).** The floor is built on a depth-blind `convertToAssets`, so a large request breaches `minOut` at an *unmoved mid-price*. | `RealisticExitPreviewPoc.t.sol::testPoc_INV3_market_finiteDepthBricksQuotedExit` (PASS) — gross `19,800e18`, quoted `19,602e18`, AMM would pay `14,882.7e18` ⇒ revert. Census `r_ammDepthBind` (>0.5% impact) 110 | the (a) quote member also covers this, *provided* it is size-aware (`get_dy(amountIn)`, not a mid-price) |

- **Blast radius (from CODE-02, retained)**: the **entire** `withdraw` / `withdrawAsOwner` / `totalWithdrawal` path of the market strategy is bricked for **every** client while the condition holds — `_disposeShares` is the single shared exit hook. **Liveness, not fund loss**: it clears when the pool re-prices, and `relinquishPrincipal` (`AYieldStrategy.sol:682`, client-callable) / `relinquishPrincipalAsOwner` (`:687`) always write principal down without an external call. No "no remedy exists" claim is made.
- **What story-050 makes worse**: before `cdd0743` there was no pre-flight signal and a consumer had to try-and-revert. Now there is one, it is documented with the word "guarantees", and it is **always green in exactly the state where the call is guaranteed to fail**. `INV-3` is the **dominant** failure mode on both strategies (census `v3_nonZeroQuoteRevert` 127 direct / 90 market; `v3d_deferredRevert` 48/22).
- **Test-suite blindness**: no market test previews and then withdraws at a rate that breaches `minOut` — `testPreviewExitForRoundTripAtUnfavorableRateClearsFloor` deliberately picks 0.995 against a 1% tolerance. The repo's own control tests prove the fixtures cannot express the failure: `testControl_repoMockVault_cannotExpressAnExitFee` and `testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn` (both PASS).

> **CRITICAL DE-CONFLICTION (directive, honoured) — ledger `M-02` / `d7f6c2dfd580776dd3193942b89806b893ac95ff56a752a5e5bd7c501cb41416` (Medium, `false-positive`) must NOT be inherited.**
>
> `M-02` title: *"NAV-anchored minOut is execution-price-blind, enabling sandwich value leak."* Its `triageNote` closes, verbatim:
>
> > "2026-06-09: Rejected as false-positive. The use of convertToShares/convertToAssets is intentional — the design allows in-block swaps without MEV fear precisely because the AMM pool is concentrated liquidity. A small slippage tolerance covers 99% of deposit/withdrawal scenarios. The NAV reference is not exploitably skewed in this pool topology. **No valid attack path.**"
>
> | | `M-02` (`false-positive`) | DEDUP-17-04 |
> |---|---|---|
> | Claim | NAV-anchored `minOut` lets a sandwicher **extract value** | NAV-anchored floor makes the **new preview report green while `withdraw` is guaranteed to revert** |
> | Harm | value leak | liveness / false pre-flight signal |
> | Refuted by | concentrated-liquidity pool, no valid sandwich | **not addressed** — the refutation is about *profitability*, not about the quote's *blindness* |
> | Surface | `_disposeShares` (pre-existing) | `previewExitFor` (new at `cdd0743`) |
>
> **Same code, different claim.** A triage pass that pattern-matches this onto `M-02` and inherits `false-positive` would suppress a live finding. The econ pass independently **REFUTED** the value-extraction reading again this run (`testEconRefute_DonationDoesNotInflateTheQuote`, PASS: ~1 wei drift across an 11× share-price swing, and the direction favours honesty), which *confirms* `M-02`'s triage and leaves the liveness claim untouched. Ledger `L-12` / `6e771a84e82d…` (open, *"CurveAMMAdapter.swap does not independently verify amountOut >= minAmountOut"*) is adjacent context, **not** a duplicate.

> **RE-FILE DISCLOSURE — stable-staker `M-07` (`ss9m7`) / `969722dc9eedb9615…` (Medium, `acknowledged`)** — the closest sibling anywhere in the suite. Title: *"setYieldStrategy underwater guard is rate-based, bypassed by AMM execution slippage (incomplete fix of M-06)."* `triageNote`, verbatim:
>
> > "Owner-acknowledged 2026-06-09: real Medium footgun confirmed, won't-fix in code. Disposition: in-place setYieldStrategy on an AMM/execution-priced market yield strategy with staked users is prohibited operationally — a full terminal migration … must be used instead… Handled by operator caution / phStaging script discipline, not a code change."
>
> **Re-file basis:** `969722dc…` is on a **different repo and a different function** (`StableStakerV2.setYieldStrategy`'s rate-based guard), and its disposition is an **operational prohibition on an owner action**. DEDUP-17-04 is the same blindness on a **permissionless, integrator-facing view that now publishes the blind number under the word "guarantees"** — a strictly larger blast radius that no operator discipline reaches, because the consumer is not the operator. `acknowledged` on `969722dc…` therefore carries **no suppression authority** here. Disclosed rather than silently re-filed.

---

### DEDUP-17-05 — the quoted floor is not honoured across a real quote→execute gap: `minOut` is re-derived from live state at execution, so the guarantee silently collapses with it

- **Merged inputs**: `INV-1b` violations on **both** strategies (Tier-3), corroborated by pattern-match divergence **D-5** (self-referential test oracle / triplicate floor expression)
- **Proposed severity (carried forward)**: **Low today · potential-Medium on wiring** (Tier-3 flags it as *"the finding this run's brief asked for"*)
- **Contract/function**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` — `_exitFloor:127-135` vs the inline `minOut` recomputation at `:245-246`; same shape on `ERC4626YieldStrategy._disposeShares:126-138`
- **Evidence**: `test/invariant/RealisticExitPreviewPoc.t.sol::testPoc_INV1_market_floorBreachesAcrossQuoteExecuteGap` (PASS):

```
netGuaranteed quoted at T1   : 19,602e18
shares still held at T2      :      364.0e18
shares the quoted gross needs: 39,600e18
delivered at T2              :      181.9e18     <-- 0.93% of the guarantee
```

  Sequence: two clients funded → consumer STATICCALLs the preview → vault halves in value → the *other* client exits first → the consumer executes. **No revert, no event, no signal.** Census `v1d_floorBreachesDeferred` 35 direct / 1 market over `r_deferredExits` 35/13.

- **DELIBERATE DECISION (directive): this is a DISTINCT finding, not DEDUP-17-04 and not DEDUP-17-03.** Justification:
  1. **Different harm.** DEDUP-17-04 is a false green that **reverts**. This is a false green that **silently under-delivers 99%**. They sit on opposite sides of the §0 axis.
  2. **Different root cause.** DEDUP-17-04 (a) is *"the quote cannot see the AMM"*. This is *"the quote is not a snapshot — `_disposeShares` re-derives `minOut` inline from live state, so a floor quoted at T1 is silently replaced by a lower floor at T2."* The market override's floor holds **atomically** (INV-1 market: 256,000 forge + 209,901 medusa calls, no counterexample) precisely because `_exitFloor` and the inline `minOut` are the **same expression by convention across three copies** (`:127-135`, `:245-246`, `t.sol:44-52` — pattern D-5), an equality nothing enforces. It **evaporates the moment the gap is real**, which is the only mode in which a STATICCALL preview is useful.
  3. **Different mitigation, and this is decisive.** DEDUP-17-04's fix (add an AMM quote member) does **not** close this — a quote-time AMM read still gets re-derived at execution. This one needs the floor to become **enforceable**: pass the quoted `netGuaranteed` into `withdraw` as a caller-supplied `minOut` and revert if execution cannot meet it, rather than recomputing. Filing it under DEDUP-17-04 would let the wrong fix close it.
  4. It also fires on the **direct** strategy (35 deferred breaches), which DEDUP-17-04 (a) does not touch at all.
- **Pattern**: no home in DB v1.1 — feeds the two new-pattern candidates `PREVIEW-EXECUTION-DIVERGENCE` and `MIRRORED-INVARIANT-DRIFT`.

> **DISCLOSURE — stable-staker `M-01` / `2b9a89d29c34df41aee609d0b5f2c6ae82c1e509877261424c2c20f317fbb0c3` (Medium, `wont-fix`), *"Par-exit front-run on the migration cushion."* `triageReason`, verbatim:**
>
> > "OWNER DECISION 2026-08-29, recorded in the owner's own terms. The finding is VALID — this is explicitly NOT a rejection on the merits and NOT a severity downgrade. It is closed wont-fix because the mitigation is OPERATIONAL rather than a code change, and is OUT OF SCOPE FOR THIS REPO: the pause() -> initiateMigration() -> unpause() sequence belongs in the deployment script that performs the migration, which lives in phoenix-phase-2-staging. Nothing in stable-staker can fix it."
>
> **FINGERPRINT VERIFICATION (asked for explicitly). The pattern pass's correction is CORRECT; the memory note is WRONG.** Read directly from `reports/stable-staker/ledger.json` this run:
> - `2b9a89d29c34df41…` = **"Par-exit front-run on the migration cushion: story-020 turns the FCFS underwater buffer into a value transfer from the remaining cohort"** — Medium, `wont-fix`, mitigation OPERATIONAL. ✅ This is the par-exit front-run entry.
> - `69c7666eee33698e…` = **"Underwater withdraw buffer is FCFS at par, socializing strategy loss onto slow stakers"** — Medium, `wont-fix`, *"Intended design (confirmed by protocol owner)"*. This is the **older, different** entry.
>
> Memory `stable-staker-run15-notes` cites `69c7666e…` for the par-exit front-run; that citation is **incorrect** and should be repaired. **Relation to DEDUP-17-05: ADJACENT, NOT A DUPLICATE.** `2b9a89d2…` is a *stable-staker buffer-ordering* value transfer between stakers; DEDUP-17-05 is a *reflax* quote→execute gap in which the strategy's own floor is silently re-derived. Its `wont-fix` reasoning ("nothing in stable-staker can fix it") carries **no authority over reflax code**, where the fix *is* a code change. Not suppressed.

---

### DEDUP-17-06 — the protocol-favouring write-down is one-directional: the market strategy pays out over-delivery from the commingled position

- **Merged inputs**: `INV-4` violation, market strategy (Tier-3). No other pass raised it.
- **Proposed severity (carried forward)**: **Low** (Tier-3 filed no severity; carried at Low pending severity-classifier — **flagged for second opinion**, see below)
- **Contract/function**: `src/AYieldStrategy.sol:778-783` `_withdrawInternal` as composed with `ERC4626MarketYieldStrategy._disposeShares`
- **Evidence**: `test/invariant/RealisticExitPreviewPoc.t.sol::testPoc_INV4_market_overDelivery` (PASS), market bidding the share at a 5% premium to NAV:

```
principal debited   : 10,101.0e18
underlying delivered: 10,575.1e18     <-- +474e18 paid from the commingled position
```

  Census `v4_overDelivery` 13 market / **0 direct**. Ledger conservation `Σ clientBalances == totalDeposited` **HOLDS** (0 skews in 256,000 calls × 2 strategies) — the skew is in *value*, not in the books.
- **Rationale for keeping**: `_withdrawInternal`'s documented rule (`:757-760`) is *"principal is decremented by the REQUESTED (capped) amount … Any shortfall stays as protocol-owned yield"* — it books the **downside** as protocol yield but **pays out the upside** to the exiter. That asymmetry is not documented anywhere and is repeatable (exit whenever the AMM bids above NAV).
- **Suppression NOT applied, and why**: the minter-cushion memo declares the commingled share cap by design *in the **deficit** direction* (minters cannot redeem, so they are a cushion rather than a racing counterparty). This is the **surplus** direction — an exiting client extracting more than it was debited, out of backing the cushion supplies. The memo's premise does not reach it. **Routed to severity-classifier / severity-auditor for adjudication rather than suppressed** (Law 1: recall beats tidiness).
- **Ledger relation**: adjacent to `QA-09` / `86409a56b6fc…` (open, orphaned vault value) — same commingled-residual accounting, different direction. Disclose; do not collapse.

---

### DEDUP-17-07 — `previewExitFor` returns `(0,0)` for four operationally unrelated states, and `grossToRequest` fed back into `withdraw` reverts instead of no-op'ing

- **Merged inputs**: `CODE-03` (the `(0,0)`-overloading half). **The owner-footgun half is FOLDED, not filed — see §2.1.**
- **Proposed severity (carried forward)**: **Low** (QA-adjacent)
- **Contract/function**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:162-186` `previewExitFor` (+ base `src/AYieldStrategy.sol:571-583`)
- **Evidence**: `poc-run17-preview-exit.t.sol::testH4_ZeroZeroIsFourDifferentStates` (PASS). Four states return bit-identical `(0,0)`: (a) unknown account, (b) zero `netWanted` on a fully-funded account, (c) drained account, (d) `slippageToleranceBps == MAX_BPS` on a fully-funded account (`assertGt(principalOf(...), 0)` passes — state (d) has a live `990e18` principal and is indistinguishable from an account that never existed). Feeding `grossToRequest == 0` back in reverts `"AYieldStrategy: amount must be greater than zero"` (`AYieldStrategy.sol:767`).
- **Fifth state, worse, and the NatSpec presents it as the *honest* signal** (`:150-153`): after `emergencyWithdraw`, `shares = 0` while principal stays booked ⇒ `gross 1010e18` (positive, so the `(0,0)` sentinel does **not** fire), `netGuaranteed 0`, and `_disposeShares` then calls `ammAdapter.swap(vault, underlying, 0, 0)` — which reverts on the production adapter. That leg is **DEDUP-17-08**.
- **Ledger relation**: none — the `(0,0)`-overloading API-contract defect is new with `previewExitFor` and has no catalogued pattern. **`L-01` does NOT cover it** (see §2.1).

---

### DEDUP-17-08 — the test AMM adapter is more permissive than production on exactly the edge story-050 steers callers into; `_disposeShares` bricks on a zero-size swap

- **Merged inputs**: `CODE-04` (both mechanisms) + Tier-3 divergence **D-1** (adopted as production parity in the realistic rig)
- **Proposed severity (carried forward)**: **Low**
- **Contract/function**: `src/AMMAdapters/CurveAMMAdapter.sol:129` `swap` vs `test/mocks/MockAMMAdapter.sol:63`; consumed by `ERC4626MarketYieldStrategy._disposeShares`
- **Evidence**: `require(amountIn > 0, "CurveAMMAdapter: amountIn must be > 0")` at `CurveAMMAdapter.sol:129`; `MockAMMAdapter` has no such guard and **every** market test — including all 13 new preview tests — runs against the mock. Two reachable paths to `amountIn == 0`: (1) `vault.balanceOf(strategy) == 0` with principal still booked (after `emergencyWithdraw`, or after another client drains the position per DEDUP-17-03); (2) `convertToShares(gross) == 0` for a dust exit once the share price exceeds one underlying unit (probe at ~4× share price: `netWanted 1 → gross 2 → shares 0`). Confirmed independently by the Tier-3 control `testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn` (PASS).
- **Remedy enumeration was RUN, not asserted** (carried forward verbatim in substance): `withdraw`/`withdrawAsOwner` revert; `totalWithdrawal` silently no-ops at `:294`; `relinquishPrincipal` (`:682`) and `relinquishPrincipalAsOwner` (`:687`) both succeed with no external call. **Stranded principal is recoverable by either the client or the owner — this is a bricked normal path with two working escape hatches, not a permanent freeze.** No "no remedy exists" claim.
- **Corroboration**: **SA-008** — see DEDUP-17-15, which is the same missing measurement on the direct leg.

> **DISCLOSURE — ledger `L-13` / `1456259d8ac60c118795b770323769ed2bf565c67dee884a6d814daded7bbc4e` (Low, `open`).** Title: *"`_totalWithdraw` state-inconsistency: migration recorded as executed even when `sharesToSell` floors to 0 for a tiny-balance client (principal left on books, nothing moved)."*
>
> **Disclose, do NOT collapse.** Identical share-flooring root cause, **different function and different fix**: `L-13` wants a revert-or-skip in `_totalWithdraw`; DEDUP-17-08 wants `if (sharesToSell == 0) return 0;` in `_disposeShares` **plus** the `amountIn > 0` guard added to `MockAMMAdapter` so the suite tests the production precondition. Fixing one leaves the other live.

---

### DEDUP-17-09 — `netWanted * MAX_BPS` is evaluated before the principal cap, so the market override panics on the idiomatic `type(uint256).max` request while the base default answers it

- **Merged inputs**: `PM-1` (pattern pass, `INCORRECT-OPERATOR` boundary instance). Sole source.
- **Proposed severity (carried forward)**: **QA / Low**
- **Contract/function**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:174` `previewExitFor`
- **Evidence**: `poc-run17-pattern-match.t.sol::testPM1_MaxNetWantedOverflowsMarketButNotDirect` (PASS) — direct at `uint256.max` returns the capped principal (`1000e18`, no revert); market reverts `Panic(0x11)`. Exact asserted boundary: `netWanted > 11579208923731619542357098500868790785326998466564056403945758400791312963`; `boundary` returns the capped principal, `boundary + 1` reverts.
- **Why it survives dedup as more than an absurd input**: the two implementations of one interface member **diverge on the standard "give me everything" sentinel**, and story-050 criterion 9 explicitly demanded a neighbouring division edge be *"distinguishable from a bare `Panic(0x12)`"* — this one ships a bare `Panic(0x11)` on a much more plausible input. One-line fix: `Math.min(netWanted, availablePrincipal)` before the gross-up.
- **Ledger relation**: none.

---

### DEDUP-17-10 — the `ceilDiv` gross-up compensates the bps leg but not the share round-trip, so `netGuaranteed` can land below `netWanted`

- **Merged inputs**: `F-02-050` (FAITH-002) + code-scan **H-3** (explicitly *"CONFIRMED but BOUNDED to dust; subsumed by F-02-050, not filed separately"*)
- **Proposed severity (carried forward)**: **QA / informational**
- **Contract/function**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:162-183` `previewExitFor` (line 174)
- **Evidence**: story-pass probe — 200 consecutive `netWanted` values at a non-dividing share price with an explicit assertion that no cap binds; worst observed shortfall **1 wei**, reproduced at near-unity and ~3× share prices. Analytic bound from H-3: `netWanted − netGuaranteed ≤ ⌈A/S⌉ + 2` raw base units, confirmed by `testFuzz_H3_ShortfallIsBoundedByAssetsPerShare` (256 runs, PASS, no counterexample).
- **Merge rationale**: H-3 is the same claim on the same function; the code scan itself declined to re-file it (*"Filing it again here would be a duplicate on a fresh fingerprint"*). Phase-2 consolidation; H-3 contributes the tight bound.
- **Pattern**: `ROUNDING-DIRECTION` classifies it **known-benign** — `notVulnerableWhen` bullet 1 holds (`ceilDiv` rounds the *request* up = protocol-favouring; the double floor rounds the *quote* down). No user-favouring leg, no repeatable round-trip profit. `DIVISION-PRECISION` refuted (mul-before-div throughout). **Confirms QA is the right severity.**

> **DISCLOSURE — ledger `F-01` / `ec9191e420d544443d4625c9b2150cf725b06328b41eb4c58e0ff2572bb5ee04` (faithfulness, `open`).** Title: *"story-043 'provable solvency invariant' overstated: ERC4626 double round-down means `convertToAssets(convertToShares(creditedPrincipal))` can be a few wei below `creditedPrincipal`."*
>
> **Disclose, do NOT collapse.** Same arithmetic and the same *overstated-story* shape, but `F-01` is the **deposit** side (`_depositInternal`/`_creditedPrincipal`) and DEDUP-17-10 is the **exit** side (`previewExitFor`), on a function that did not exist at `F-01`'s commit. **Process signal worth surfacing to the report writer: two consecutive stories (043, 050) have each claimed a provable property that the ERC4626 double round-down does not deliver.**

---

### DEDUP-17-11 — the market `previewExitFor` override is sealed against subclassing (`override` without `virtual`)

- **Merged inputs**: `CODE-05`. Sole source.
- **Proposed severity (carried forward)**: **QA**
- **Contract/function**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:162-166`
- **Evidence**: the market declaration is `external view override` where the deliberate base at `AYieldStrategy.sol:571-577` is `external view virtual override`. Every other overridable hook on the contract (`_disposeShares`, `_positionValue`, `getTotalShares`) remains reachable; this one is the exception.
- **Why it is not filtered as style**: DEDUP-17-01 through -05 are all defects a subclass would want to patch, and the repo has an established pattern of shipping forked variants (`NFTStakerPriceScaled`, `StableStakerV1/V2`). One-word fix.
- **Ledger relation**: none.

---

### DEDUP-17-12 — adding `previewExitFor` to `IYieldStrategy` breaks four non-`AYieldStrategy` implementers at the next submodule bump, and one claimed production-path implementer is unverifiable

- **Merged inputs**: `CODE-06` (which itself **corrects** story-faithfulness `WATCH-17-01`)
- **Proposed severity (carried forward)**: **Informational**
- **Contract/function**: `src/interfaces/IYieldStrategy.sol:79`
- **Evidence** (enumeration actually run, untruncated, over every registered top-level submodule at its own HEAD, excluding nested `lib/**`):

```
stable-staker/test/Migration.t.sol:924:contract UnderRealizingStrategy is IYieldStrategy {
stable-staker/test/mocks/MockYieldStrategy.sol:26:contract MockYieldStrategy is IYieldStrategy {
stable-yield-accumulator/test/StableYieldAccumulator.t.sol:112:contract MockYieldStrategy is IYieldStrategy {
stable-yield-accumulator/test/StableYieldAccumulator.t.sol:215:contract MockRevertingYieldStrategy is IYieldStrategy {
```

  All four resolve `IYieldStrategy` through a **remapping to the live reflax submodule** — no repo vendors its own copy — so all four fail to compile (*"Contract … should be marked as abstract"*) at the next bump. **Build break in test suites, not a runtime break.** `phoenix-phase-2-staging` has zero implementers; `antimatter/test/mocks/MockYieldStrategy.sol:9` declares no interface inheritance and is unaffected.
- **Correction carried**: story-faithfulness `WATCH-17-01` lists **six** implementers. Two — `phusd-stable-minter/test/PhusdStableMinter.t.sol:66` and `deployment-staging/src/mocks/MockYieldStrategy.sol:12` — are in **unregistered repos** and are outside this run's evidence base. The second matters disproportionately: its citation places it in **`src/`, not `test/`**, which would escalate a test-only break to a **deployable-contract** break. The enumeration **does not assert it exists**; it flags the claim as currently unverifiable. **Actionable item parked as `MR-17-04`** (register `deployment-staging` or confirm it is dead before the next reflax bump).
- **Zero consumers, verified twice independently**: `grep -rn "previewExitFor" lib/` returns hits only under `reflax-yield-vault/` (33: 3 in `src/`, 30 in this repo's own tests), and the symbolic pass re-derived the same per-submodule counts (`antimatter 0 … reflax 32`). **This is the single fact keeping DEDUP-17-01 through -05 at Low today**; `WATCH-17-03` (escalate at the `stable-staker` submodule bump) is the correct trigger.

---

### DEDUP-17-13 — story-025's mandated "measure the delta and revert" safeguard is structurally incapable of firing on a below-par strategy

- **Merged inputs**: `ECON-17-02` / `ECON-001`. Sole source; no duplicate anywhere in the run.
- **Proposed severity (carried forward)**: **Low today, with a dated Medium escalation trigger**
- **Contract/function**: `src/AYieldStrategy.sol:571-583` `previewExitFor`, cross-referenced to `stable-staker/src/StableStakerV2.sol:876-895` `_routeExit` (story-025, state folder `incomplete`)
- **Evidence** (code-quoted derivation; no PoC possible — the consumer has not landed): `_routeExit`'s `guardUnderwater` branch returns the **full requested `amount`** from StableStaker's own idle balance and calls `relinquishPrincipal` (a pure write-down, `AYieldStrategy.sol:700-716`, *"vault shares are deliberately untouched"*). Therefore `received == needed` **by construction**, the mandated `StableStaker:` revert **can never fire**, and story-025's acceptance test (*"assert the idle buffer is untouched … in the lying-preview scenario"*) passes trivially against a full-credit mock and is **unsatisfiable** against a real below-par strategy. A green checklist here is a false negative.
- **Harm is availability, not value leak.** Buffer depletion itself is **opportunity cost** under the externally-derived-yield rule and is explicitly **not** filed as a leak. The filed harm: the buffer is thin by construction (`setSetAsideBuffer(address(stableStaker), 10)` = 10% of skim proceeds, `MigrateStableStakerMainnet.s.sol:597`); one large staker's whole-position `autoAnnihilate` empties it, after which `_routeExit` takes `revert("StableStaker: strategy underwater")` and **every other staker's `withdraw()` is bricked** until the position recovers or the owner refunds.
- **Escalation trigger (conjunction of all three)**: (1) `stable-staker` bumps `lib/reflax-yield-vault` to a story-050 commit **and** lands `autoAnnihilate`; (2) `autoAnnihilate` sources through `_routeExit(..., guardUnderwater = true)`; (3) the wired strategy can go below par (true for both Tokemak-Autopool direct strategies and the USDe market strategy).
- **Channel**: `spec-conformance.md` (cross-protocol integration, `F-03` precedent) — **not** the QA bundle.
- **Ledger relation**: rides the existing next-stable-staker-run gate on `F-03` / `52f9b84a54ec…` (open) — *"caller MUST pay-out/write-off principal to its end user BEFORE calling `relinquishPrincipal`…"* — and feeds `QA-09` / `86409a56b6fc…` (open, orphaned value), because each buffer-path call leaves reflax-side residual share value backing nothing. **Handle both gates together at the next stable-staker run.** Not a duplicate of either: `F-03` is about double-counting across the call, this is about the consumer's own safeguard being inert.
- **C4 known-invalid check applied**: "speculation on future code" — honoured by capping at Low with a dated trigger rather than filing a speculative Medium. Story-025's spec **already mandates** the two obvious recommendations, so the naive "consumer trusts `netGuaranteed`, buffer eats the difference" finding is **not** filed.

---

### DEDUP-17-14 — `_totalWithdraw` silently early-returns on `totalShares == 0 || totalDeposited == 0`, swallowing the request instead of reverting

- **Merged inputs**: `SA-001` (direct, `ERC4626YieldStrategy.sol:185`) + `SA-002` (market, `ERC4626MarketYieldStrategy.sol:293`) — Slither `incorrect-equality`, confidence high, both tools' highest-value non-duplicate hit after SA-008
- **Proposed severity (carried forward)**: **Low** (static pass filed both as "Medium-potential")
- **Evidence**: `if (totalShares == 0 || totalDeposited[token] == 0) { return; }` at both sites. Consequence traced by the code scan's remedy enumeration: the two-phase `totalWithdrawal` window is **consumed** by the silent no-op while principal stays booked.
- **Merge rationale**: identical code, identical root cause, two contracts. Phase-2 consolidation; instances enumerated.
- **Ledger relation**: **DISCLOSE, do not collapse** — `L-13` / `1456259d8ac6…` (Low, `open`) is the *market* `_totalWithdraw` **share-flooring** instance (`sharesToSell` floors to 0). DEDUP-17-14 is the **zero-shares / zero-deposits guard** at the top of the same function, on **both** contracts. Adjacent, same function on one of the two contracts, different condition and different fix. Flagged for finding-manager to confirm whether the `L-13` fingerprint already covers the market site.

---

### DEDUP-17-15 — the direct strategy discards `vault.redeem`'s return, so its own exit never measures the delta its NatSpec obliges consumers to measure

- **Merged inputs**: `SA-008` (Slither + Aderyn `unused-return`, confidence high) — **the delta-relevant SAST finding**
- **Proposed severity (carried forward)**: **Low** (static pass: "Medium-potential")
- **Contract/function**: `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:135` `_disposeShares`

```solidity
vault.redeem(sharesToRedeem, recipient, address(this));   // return value discarded
```

- **Why it survives as a finding rather than tool noise**: this is the **mechanical enabler** of DEDUP-17-01 and DEDUP-17-02. `previewExitFor`'s NatSpec mandates *in capitals* that consumers MUST measure the actual balance delta across `withdraw`; the strategy's own direct exit does not, and `vault.redeem` carries **no `minOut`**, which is exactly why the direct-strategy failures are **silent under-delivery with no revert** rather than a revert. Capturing the return and comparing it to the quoted floor would convert DEDUP-17-01/-02 from silent to loud with a one-line change — this is not a style nit, it is the missing tripwire.
- **Corroborated by**: pattern-match `CODE-04` note; Tier-3 `INV-1` direct violations (all 203 census exits).
- **Ledger relation**: none. Distinct from `QA-06` / `8019f1c9c6de…` (EnumerableSet returns) and from `L-06` / `0f534a726502…` (skim return semantics), which are different call sites.

---

### DEDUP-17-16 — raw `approve` with an unchecked boolean return in the `ERC4626YieldStrategy` constructor

- **Merged inputs**: `SA-009` (Slither `unchecked-transfer` + Aderyn `Unsafe ERC20 Operation`, same line, confidence high)
- **Proposed severity (carried forward)**: **QA**
- **Contract/function**: `src/concreteYieldStrategies/ERC4626YieldStrategy.sol:50` `constructor` — `IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);`
- **Why not filtered under the weird-ERC20 known-invalid**: the C4 known-invalid list carves out **USDT explicitly**, and USDT's `approve` returns no data, so a `bool`-decoding call reverts. The failure mode is deploy-time and loud (nothing deploys), which is why this is **QA and not a footgun** — it fails the Law-3 surprise test. Kept because it is a one-line `SafeERC20.forceApprove` fix on the only unguarded ERC20 call in `src/`, and because `CFG-01` / `0c12a2cfaf4b…` (open) shows the wired-vault configuration has already been wrong once.
- **Ledger relation**: none exact.

---

## 2. Folds — recorded against an existing open ledger entry, NOT filed as new

### 2.1 `CODE-03` owner-footgun half / `ECON-003` → **ledger `L-01` / `6460e35331dff5c220d596a134d4f71e1ce0c53b6bfd3b0b5f48edf97307b286` (Low, `open`)**

**Directive asked: confirm the fold or split it back out. → THE FOLD IS CORRECT. The pattern pass's objection is wrong on the ledger text.**

`pattern-match.md` argues *"Ledger `L-01` … is the **lower** boundary of the same setter. CODE-03's footgun is the **upper** boundary and is not covered by `L-01`'s fingerprint."* That is contradicted by `L-01`'s own record:

- **Title, verbatim:** *"slippageToleranceBps default-0 plus **setter missing sane cap** (missing validation)"* — the missing cap **is** the upper boundary.
- **`run08Note`, verbatim:**
  > "the deposit-side haircut magnitude is bounded ONLY by the still-missing `slippageToleranceBps` upper cap, so an owner setting a loose tolerance now haircuts depositors' credited principal as well as swap `minOut`. Recommendation (expanded): enforce a hard sane upper cap on `slippageToleranceBps` (e.g. a few hundred bps) in `setSlippageTolerance`…"

`L-01` therefore already owns **both** boundaries **and** the deposit-side-crediting blast radius that `_creditedPrincipal → 0` at `MAX_BPS` is the limit case of. **Fold confirmed.** Recorded as an **`L-01` blast-radius extension**, with story-050 adding a **third dependent surface**: `previewExitFor` returns an alarm indistinguishable from three benign states. No new entry.

**What `L-01` does NOT own** is that alarm-ambiguity itself — which is why the `(0,0)`-overloading half is filed separately as **DEDUP-17-07**. The split is along ownership, not along the boundary.

Safe-config guidance to carry into the QA bundle under `L-01`: `require(_bps <= 1000)` in the setter; never deploy at the zero default; pause deposits before temporarily raising tolerance; add `require(creditedPrincipal > 0)` in `_depositInternal`; monitor `previewExitFor(token, <known-funded client>, 1)` as a `MAX_BPS` canary (a `(0,0)` from a client with non-zero `principalOf` is unambiguously the `MAX_BPS` state).

Pattern note retained: `INCORRECT-OPERATOR` `vulnerableWhen` bullet 2 matches (`require(_bps <= MAX_BPS)` lets the exact boundary through); `CENTRALIZATION-ADMIN` matches the `onlyOwner` signature but **adds nothing** and is not carried.

### 2.2 `SA-003` + `SA-004` → **ledger `L-01-run11` / `3ab43381ffaf…` (Low, `open`)**

`L-01-run11`: *"CEI violation in `_withdrawInternal`: state updates occur after two external calls."* SA-003/SA-004 are the **sibling site** — the same CEI violation in `_totalWithdraw` on both contracts (`ERC4626MarketYieldStrategy.sol:309-313`, `ERC4626YieldStrategy.sol:194-198`), with Slither naming `previewExitFor` among the cross-function readers of the stale `clientBalances`/`totalDeposited`.

**Recorded as a site extension of `L-01-run11`, not filed as new**, because **exploitability is refuted**: `PM-3` (`REENTRANCY-READONLY`) is **REFUTED on mechanism** — no third party can obtain control mid-withdraw (only outbound calls are `ammAdapter.swap → router.exchange`, both value legs are hookless ERC20s, zero ERC777/721/1155 in `src/`, `nonReentrant` on all 8 value-moving entry points), and the code scan reached the same verdict independently, adding that the over-quote a mid-flight read *would* produce **is already DEDUP-17-03** by another route. **`PM-3` is CONDITIONAL — reopen if a hook-bearing token or a callback-capable adapter is introduced.** The window is real; no actor can read it.

### 2.3 `ECON-004` → filed as **DEDUP-17-02**, not folded

The econ pass proposed *"fold into `ECON-A`, do not re-file."* **Overruled, with reasons, in DEDUP-17-02**: different function, different claim, fresh fingerprint, and `F-16-003`'s live gate explicitly instructs the reader **not** to inherit `ECON-A`'s stale Low. Folding it would be the exact suppression that gate exists to prevent. Cross-linked to `ECON-A` rather than merged into it.

### 2.4 `ECON-17-01` V2 unbacked-phUSD dilution leg → **routed to the cross-project unbacked-phUSD channel**

The minter-cushion suppression's *value* premise does not survive StableStaker V2 (V2 emits Antimatter, redeemable into **unbacked** phUSD, so the minter's constituency bears real dilution, not opportunity cost). That leg is **live** but belongs to `yield-claim-nft` `DEDUP-001` / `antimatter` run-01, not to a new reflax finding. **Routed, not dropped** — parked as `MR-17-03` so it has an owner.

---

## 3. Removed outright (traceable)

### 3.1 Exact/near duplicates of existing ledger entries — 11 SAST findings

| Input | Ledger owner | Status | Basis |
|---|---|---|---|
| `SA-005` (uninit `lastToken` in `setRoute`) | `L-10` / `90f3fa166e20…` **and** `L-07` / `1a4e3e8f13bd…` | `false-positive` / `open` | `L-10` is verbatim this detector hit and is already triaged `false-positive`; the "interior zero gaps" half is verbatim `L-07`'s open title. Both legs owned. |
| `SA-010`, `SA-011` (EnumerableSet add/remove returns) | `QA-06` / `8019f1c9c6de…` | `open` | `QA-06`: *"setClient ignores the bool return of EnumerableSet.add/remove"* — exact same two lines. |
| `SA-012`, `SA-013` (`calls-loop` in `_accrueSurplusShares`) | `L-02` / `81ee07506e42…` | **`wont-fix`** | `L-02`: *"skimSurplus unbounded iteration over owner-grown authorized-client set (no pagination)"* — same call stack, human-disposed. |
| `SA-015` (`timestamp`, 6h/72h window) | `QA-02` / `70162a2a2176…` | `open` | `QA-02` is verbatim this, including the "load-bearing" framing the static pass used to justify keeping it. |
| `SA-016` (Aderyn High, `abi.encodePacked` collision) | `QA-01` / `4e98bf162020…` | `open` | `QA-01`: *"used only for revert"* — already disposed as the same likely-false-positive. Aderyn's sole High does not survive as a run-17 finding. |
| `SA-017` (`nonReentrant` not first modifier, 8 sites) | `L-04-run11` / `46ab675c76e9…` | `open` | Exact. |
| `SA-018`, `SA-019`, `SA-020` (constructor param shadowing ×3) | `L-05-run11` / `adc461fade9f…` | `open` | `L-05-run11`: *"Constructor `_owner` shadowing across three contracts"* — the same three sites. |

### 3.2 Out of scope — 1

`SA-021` (`erc20-public-burn`, `src/mocks/MockERC20.sol:26`) — `src/mocks/` is denylisted in this project's `outOfScope`. Recorded by the static pass for transparency and **not** suppressed on known-issues grounds (`knownIssuesCount` is 0 this run and the cache carries no suppression authority). Removed as OOS, not as noise.

### 3.3 Tool noise — 3

| Input | Reason |
|---|---|
| `SA-006`, `SA-007` (`uninitialized-local` `totalSetAside` accumulator, both `_distributeBuffer`) | Implicit zero-init of a loop accumulator; conventionally benign, no security or spec impact, no exploit path. The static pass itself said "flagged for review, conventionally benign". |
| `SA-014` (`reentrancy-events`, `Swapped` emitted after `router.exchange`) | Event-ordering informational with `nonReentrant` on every value-moving entry point and reentrancy cleared on mechanism (§2.2). No security or spec impact. |

### 3.4 Refutations — recorded, not findings, not parked

Each was **disproved with evidence**, so none is a Law-1 "set aside" case:

- `ECON-005` — preview manipulation **REFUTED** by PoC (`testEconRefute_DonationDoesNotInflateTheQuote`, PASS: ~1 wei drift across an 11× share-price donation; direction favours honesty; the only real lever, `vault.balanceOf(strategy)`, is `onlyAuthorizedClient`/`onlyOwner`; and an inflated quote converts to a revert, so the attacker buys a failed transaction with an unrecoverable donation).
- `PM-3` `REENTRANCY-READONLY` — **REFUTED on mechanism** (conditional; see §2.2).
- `PM-4` `FLASH-LOAN-PRICE` — **REFUTED**; already adjudicated in-project as `M-02-run11` / `c7329862eb0e…` (`false-positive`).
- `PM-5` `ERC4626-INFLATION` / `FIRST-DEPOSITOR-ATTACK` — **REFUTED**, structurally impossible (zero `totalSupply`/`_mint(` in first-party `src/`; the strategies issue no shares).
- `PM-6` — 19 patterns checked with zero code signatures.
- `code-scan` not-filed set: permissionless `CurveAMMAdapter.swap` (pulls from and pays to `msg.sender` only), residual strategy→adapter allowance (unexploitable for the same reason), `setRoute` validation gaps (obvious-failure owner action, fails the Law-3 surprise test — and already owned by `L-07`).
- `Linear-Depletion` class — **REFUTED as a mechanism** (0 hits for all nine emission-engine identifiers in `src/`; no ~63% constant anywhere in run-17). **Do not import the class fingerprint.** Confirmed only at the *parent* family level (a documented model the implementation does not follow), which is descriptive, not a finding.
- The **Halmos results are not evidence in either direction**: 0 `[PASS]`, 7 `[TIMEOUT]`, 2 intended `[FAIL]` (a negative control and a vacuity tripwire). No `[TIMEOUT]` row is cited anywhere above as support.

---

## 4. Parked visibly — `manual-review.json` (8 entries)

Nothing below was dropped. Summary; the file carries `reason`, `originalId` and `confidence` per entry.

| id | Parked item | Reason |
|---|---|---|
| `MR-17-01` | `CODE-07` — `vault.asset() == underlyingToken` never checked (zero `asset()` occurrences in `src/`); `_exitFloor` adds a 3rd and 4th call site inheriting the assumption | The code scan declined to file it on the grounds that the failure mode is obvious ("nothing works"). **Dedup disagrees on that premise**: a vault whose `asset()` differs in *decimals* mis-scales every `convertTo*` **silently**, which would pass the Law-3 surprise test. Not confident enough to file over the scanning agent's judgement; too security-relevant to drop. Human call. |
| `MR-17-02` | `WATCH-17-E3` — `StableStakerV2.setYieldStrategy`'s idle sweep (`:294-298`) has no `require(credited > 0)` while `stake` (`:333`) and `depositFor` (`:713`) do; at `MAX_BPS` it sweeps the entire shared underwater-withdrawal buffer in for zero booked principal | Cross-repo: belongs to stable-staker, no reflax finding owns it. The empty-pool gate (`:258`) limits instantaneous exposure but the buffer is gone for everyone who stakes after. |
| `MR-17-03` | `ECON-17-01` V2 unbacked-phUSD **dilution** leg — minter-cushion suppression premise is VOID for V2 | Live, but owned by the cross-project unbacked-phUSD channel (`yield-claim-nft DEDUP-001` / `antimatter` run-01), not by a reflax entry. Routed so it is not lost between ledgers. |
| `MR-17-04` | Register `deployment-staging` (or confirm it is dead) before the next reflax submodule bump | `WATCH-17-01` cites `deployment-staging/src/mocks/MockYieldStrategy.sol:12` — a **`src/`, not `test/`** implementer, i.e. a production-path build break. The repo is not registered in `lib/`, so the claim is unverifiable from this run's evidence base. Actionable item with no owner. |
| `MR-17-05` | Symbolic §6.1/§6.2 — the dominance downgrade of DEDUP-17-01/-03 is **contingent** on `p ≤ D` (`AYieldStrategy.sol:48`) and `a ≤ p` (`:772-776`), and **no test pins either** | Negative controls T2/T3 both fail immediately when either premise is dropped, so this is a property of the code, not the integers. A future unpaired write to `clientBalances`/`totalDeposited`, or an exit path reaching `_disposeShares` without the principal cap, **re-arms both findings at Medium with no scanner signal**. `DominanceRun17Grounding.t.sol` is a runnable regression test and should be kept. Regression tripwire, not a finding today. |
| `MR-17-06` | `WATCH-17-E2` reopen trigger — the minter-cushion suppression on DEDUP-17-03 rests entirely on `PhusdStableMinter` having **no strategy-exit path** | If any future story gives it one, the premise dies and DEDUP-17-03 becomes a live Medium immediately. Suppression condition with an expiry, parked so the expiry is visible. |
| `MR-17-07` | `WATCH-17-02` — `story-050` sits in `auto-complete` with the trailer *"Approved by: story-batch workflow (machine approval — not human-reviewed)"*, both Execute and Review run `--inline-delegation` with self-declared *"Independence: reduced"* | DEDUP-17-01 and DEDUP-17-10 are **both inside the blind spot that review declared out of its own reach**. The acceptance criteria may still be revised, which would move the Law-2 baseline under several findings here. |
| `MR-17-08` | Ledger recall gap — `lastRun` is still `reflax-yield-vault-16` @ `0110ce44`; **no run-17 shape is ledgered**, so none can reconcile by fingerprint on the next run until finding-manager writes | Surfaced by the pattern pass, out of dedup's lane. Compounded by the **fingerprint-drift risk** flagged throughout: `previewExitFor` is a new function, so every re-file relation in §1 mints a fresh hash that dedup cannot catch automatically next run. |

---

## 5. Cross-cutting notes for the report writer

1. **Cite the symbolic basis exactly.** The Low ratings on DEDUP-17-01/-03 rest on a 696 M-state exhaustive integer search of the live semantics (210 M cap-binding states, 0 counterexamples), 4 M random samples at 2^90 magnitudes, and 150 k fuzz runs plus a 105-case grid against the real contracts in the real two-client topology — **all with live vacuity tripwires, one of which fired and caught a vacuous first harness**. It is **not** a Halmos proof. Never write "symbolically verified".
2. **The green suite is not evidence.** Two Tier-3 control tests prove the repo's own fixtures make `INV-1` and `INV-3` unfalsifiable by construction: `MockERC4626Vault`'s fee knob is deposit-only (a 5% fee is invisible on exit) and `MockAMMAdapter` has infinite depth and accepts a zero-size swap. 5 of the 13 new market preview tests assert against a **self-referential oracle** (`_exitFloor`/`_grossUp` test helpers are a third copy of a production expression), 3 execute on a frictionless AMM, and the single executing direct test is the one that inverts against the vault class this strategy is actually aimed at.
3. **Both Tier-3 engines agree on every row** (forge 1024×250 = 256,000 calls/invariant/strategy; Medusa 209,901 Market / 209,999 Direct, `2 passed 5 failed` each). Only the VIOLATED rows are conclusive; the two HOLDS rows are absence of evidence over campaigns whose census shows 62–203 executed exits, 23–198 of them below par, all under a live exit fee.
4. **Zero consumers is the load-bearing fact** keeping DEDUP-17-01 through -05 at Low. It was verified twice independently, untruncated. `WATCH-17-03` — the `stable-staker` submodule bump — is the single trigger that escalates five findings at once, and it coincides with `F-03`'s and `F-16-003`'s existing Medium re-evaluation gates. **Handle all of them in one pass.**
5. **Memory repair owed** (outside dedup's lane): `stable-staker-run15-notes` cites `69c7666e…` for the par-exit front-run; the correct fingerprint is `2b9a89d29c34df41…`. Verified against `reports/stable-staker/ledger.json` this run (§DEDUP-17-05).
