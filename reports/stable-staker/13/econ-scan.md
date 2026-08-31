# Economic Scan — stable-staker story-013 (InPlaceMigrator surplus-funded top-up)

- **Project:** stable-staker
- **Submodule HEAD:** `d95f4a6` (story-013 "Add surplus-funded re-injection top-up (M-01 haircut fix)")
- **Diff baseline:** `ffa4947` (story-012)
- **Scan type:** economic / protocol-wide (Tier 2), regression mode
- **Scope:** `src/InPlaceMigrator.sol`; context `StableStaker.sol` (`depositFor`→`_routeDeposit`), reflax-yield-vault concrete strategies
- **Lineage under audit:** ss9m7/M-07 (969722dc) → ss12m1/M-01 (970d7307) → story-013 fix
- **Timestamp:** 2026-06-15

---

## THE CENTRAL QUESTION — answered

**Does story-013 close ss12m1, or is it an incomplete fix that repeats the M-07 mistake?**

**Verdict: story-013 CLOSES ss12m1 (the value-loss). Mark ss12m1 (970d7307) FIXED.**
The new failure mode is a **revert** (availability), not a silent under-credit (loss). The
profiler's LOCAL-003 convexity hypothesis — that real AMM slippage would break the linear gross-up
— is **REFUTED against the actual in-scope strategy math**. Details below.

### Why LOCAL-003 (convexity) does NOT apply to any in-scope strategy

The gross-up `topup = mulDiv(amt - credited, amt, credited)` is exact iff the strategy's
**credited-principal ratio** `credited/amt` is constant in deposit size. I verified the credited
principal (the value `depositFor`→`_routeDeposit` actually books) for every strategy class the
in-place migration can re-wire:

1. **`ERC4626MarketYieldStrategy`** (the literal M-07 lineage strategy — buys vault shares on an AMM):
   `_creditedPrincipal(amount) = amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS`
   (`ERC4626MarketYieldStrategy.sol:106-108`). This is a **fixed linear haircut by a constant
   `slippageToleranceBps`**, NOT a depth-dependent AMM curve. The actual convex AMM execution
   slippage is absorbed into the *shares received* / surplus (the `minOut` floor and the
   "gap surfaces as protocol yield" comment at :131-134), and **never enters the booked
   `creditedPrincipal`**. So `credited/amt` is constant → the linear gross-up is on-curve.
   This is precisely where M-07 lived (NAV-rate guard vs execution slippage), and story-013 is
   immune because it grosses up against the **same booked-credit ratio** the strategy itself uses,
   not against a NAV rate that execution can diverge from.

2. **`ERC4626YieldStrategy`** (direct deposit): `creditedPrincipal = vault.convertToAssets(
   vault.deposit(amount))` (`ERC4626YieldStrategy.sol:107-115`). Ratio = `(1 - entryFee)` minus
   ERC4626 share-rounding — proportional/constant in `amount` for any standard or entry-fee vault
   (e.g. Tokemak Autopool). Not convex in the credited principal.

3. **Idle / no-strategy / par**: `credited == amt`, no top-up taken. Trivially exact.

**Quantitative confirmation (constant-ratio market strategy, the worst lineage case):**

| amt | slip | credited | topup | finalCredited | par gap | `finalCredited >= amt-amt/1000` |
|---|---|---|---|---|---|---|
| 1,000e6 | 0.5% | 995.000e6 | 5.025e6 | 999.999999e6 | 1 wei (0.0001%) | PASS (10 bps headroom) |
| 1,000e6 | 2%   | 980.000e6 | 20.41e6 | 999.999999e6 | 1 wei | PASS |
| 1,000e6 | 10%  | 900.000e6 | 111.1e6 | 999.999999e6 | 1 wei | PASS |
| 1,000e6 | 50%  | 500.000e6 | 1,000e6 | 1,000.000e6  | 0 | PASS |
| 1,000e6 | 90%  | 100.000e6 | 9,000e6 | 1,000.000e6  | 0 | PASS |

At every realistic slippage the residual is **≤1 wei** vs a **10 bps (0.1%) tolerance** — i.e.
the assert has 50–1000× headroom. Direct-ERC4626 entry-fee modelling (0–50 bps fee, share prices
1.0–1.3 assets/share): worst par gap **0.02 bps**, zero assert failures.

**How much convexity would it take to break the assert?** Even a fully hypothetical EXTRA marginal
haircut applied ONLY to the top-up leg would need **~500 bps** of additional slippage on the
~2%-sized top-up to push the par gap past 10 bps. No in-scope strategy has *any* marginal
convexity in the booked credited principal, so this is unreachable. The 0.1% backstop is correctly
sized.

**Conclusion on failure mode (b):** silent under-credit / overshoot does **not** occur for any
realistic in-scope configuration. The user is no longer under-credited. ss12m1's value leak is
genuinely closed; rounding is down-only (mulDiv floors → never over-credits user beyond `amt`).

---

## FINDINGS

### ECON-13-001 — Underfunded `migrateIn` reverts the whole batch; cross-slice surplus drain can strand later users (operator footgun, availability)

- **Type:** availability / operational-footgun (DoS-on-misconfiguration)
- **Severity hypothesis:** **Low** (footgun with a self-service backstop), with a **Medium**
  argument only if the runbook does not document the surplus precondition (see severity note).
- **Contract / function:** `src/InPlaceMigrator.sol` — `migrateIn` / `_reinjectWithTopup`
- **Lines:** :280-283 (surplus `require`), :292 (par-restored `require`)
- **Lineage:** subsumes profiler LOCAL-001 + LOCAL-002.

**Mechanism.** The top-up is funded from `surplus = balanceOf(this) - totalParked[token]` — tokens
the operator must **pre-fund** into the migrator before `migrateIn`. Nothing in the contract
creates or reserves this surplus. Two coupled consequences:

1. **Zero/insufficient surplus → whole-batch revert (LOCAL-001).** With a haircutting strategy and
   no pre-funded surplus, the very first haircut user trips
   `require(topup <= balanceOf - totalParked, "top-up surplus exhausted")` and, because `migrateIn`
   is atomic, the **entire slice reverts** — no user re-injected. A competent, non-malicious
   operator who calls `migrateIn` expecting it to "just work" (as it did pre-story-013 for par/idle
   strategies) is surprised by a revert because they did not pre-stage surplus. That surprise ⇒
   footgun ⇒ in scope (Law 3).

2. **Greedy cross-slice drain (LOCAL-002).** The surplus budget is shared across the batch and
   re-checked against *live* balance each iteration; top-ups are its only consumer (each principal
   `depositFor` pulls `amt` and is matched by an equal `totalParked` decrement). Within one tx the
   outcome is all-or-nothing. But across **separate paginated `migrateIn` calls**, an earlier slice
   legitimately consumes surplus and succeeds, and a later slice can then revert on
   "surplus exhausted" if the operator sized surplus for the aggregate but it was drained greedily.
   There is no global reservation of surplus against the *remaining* parked haircut — only the
   running `balance - totalParked` check.

**Economic impact / affected parties.** No principal is lost — the revert is atomic and parked
balances remain intact. Affected users are merely **temporarily stranded** (cannot be re-injected)
until the operator pre-funds/sweeps-back surplus and retries, OR until `migrationTimeout` elapses
and each user self-rescues principal via the permissionless `claimTimedOut` (which returns
principal directly, bypassing the strategy and the top-up entirely). The custody window is
intended to be short (minutes-to-hours per the contract NatSpec), so the practical blast radius is
"migration stalls, operator re-funds and retries."

**Why not Medium/High.** No external attacker, no value loss, no permissionless griefing vector
(top-up is `onlyOwner` + `nonReentrant`, helper is `private`). The `claimTimedOut` backstop
guarantees eventual principal recovery even if the operator never funds surplus. This is the
classic Law-3 *non-obvious owner footgun*, not a fund-loss bug.

**Severity note for severity-classifier / story-faithfulness.** Escalate to **Medium** ONLY if
story-013 / the migration runbook fails to document (a) the surplus pre-funding precondition and
(b) that under-funding reverts the batch rather than degrading gracefully. If the story documents
the precondition, Low is correct. Route to story-faithfulness to confirm the precondition is
stated. (Recommended mitigation: a pre-flight view that sums the projected aggregate top-up for a
slice and lets the operator verify surplus before calling; and/or reserving surplus per-slice.)

**Confidence:** high (mechanism is verified directly from source; backstop is verified).

---

### ECON-13-002 — `rescueERC20` can sweep in-flight top-up surplus between `migrateOut` and `migrateIn` (operational coupling, footgun)

- **Type:** operational-coupling / footgun
- **Severity hypothesis:** **Low** (informational/operational; folds into ECON-13-001's funding hazard)
- **Contract / function:** `src/InPlaceMigrator.sol` — `rescueERC20` (:337-341) vs `_reinjectWithTopup` budget (:280-283)
- **Lineage:** profiler LOCAL-004.

**Mechanism.** The top-up budget and the `rescueERC20`-sweepable surplus are the **same**
`balance - totalParked` quantity. There is no escrow/earmark separating "surplus reserved for
in-flight top-ups" from "stray donated surplus to rescue." An operator who sweeps surplus via
`rescueERC20` after pre-funding but before completing `migrateIn` removes the top-up budget and
bricks par-restoration (→ ECON-13-001 revert). This is operator-self-inflicted (Law 3 footgun),
not a malicious-owner vector — `rescueERC20` still cannot touch parked principal (fenced below the
`totalParked` floor), so no user loses principal; the consequence is only a migration stall plus
the `claimTimedOut` backstop. Donation to inflate surplus is benign (does not enter `totalParked`,
so both the surplus check and the `finalCredited` invariant behave correctly).

**Confidence:** high. Recommend documenting "do not `rescueERC20` mid-migration" in the runbook.

---

## NON-FINDINGS (examined and cleared)

- **LOCAL-003 convexity (the headline M-07-repeat hypothesis): CLEARED.** No in-scope strategy has
  a depth-dependent credited-principal curve; the gross-up is on-curve and restores par to ≤1 wei.
  The convex AMM execution slippage is real but lands in shares/surplus, not in booked principal.
  ss12m1 is genuinely fixed, not papered over. This is the most important conclusion of the scan.
- **Over-credit / surplus over-consumption (failure mode b):** `mulDiv` floors → top-up is, if
  anything, 1 wei short of par; never over-credits the user beyond `amt`. Surplus is consumed by at
  most the grossed-up shortfall per user; no path over-draws.
- **Reentrancy via the second `depositFor` → strategy callback:** CEI is committed before the call
  (`parked=0`, set-removed, `totalParked` decremented), `migrateIn` is `nonReentrant`, helper is
  `private`. No re-enterable migrator state. (Strategy-side reentrancy is out of this contract's scope.)
- **Approval widening to `balanceOf(this)` (:225-226):** bounded by CEI + immutable `staker`
  target; `forceApprove` overwrites (no dangling allowance); staker pulls only principal + top-ups
  ≤ balance. No new economic surface.
- **Immutable-target drain vector:** explicitly closed by design (D) — re-injection can only credit
  the original user in the one pinned staker.

---

## REGRESSION DISPOSITION (for ledger / sanitizer)

| Finding | fp | Disposition |
|---|---|---|
| ss12m1 / M-01 re-injection haircut | 970d7307 | **FIXED** by story-013 (value loss closed; verified quantitatively against real strategy math). Propose `/ledger` flip to `fixed`. |
| ss9m7 / M-07 rate-vs-execution | 969722dc | Remains as-is (prior disposition); story-013 does NOT reintroduce it — the gross-up uses the booked-credit ratio, not a NAV rate, so execution slippage cannot bypass it. |
| ECON-13-001 (LOCAL-001+002) underfunded-batch revert / cross-slice drain | new | **NEW Low** (footgun); Medium only if runbook omits the surplus precondition — route to story-faithfulness. |
| ECON-13-002 (LOCAL-004) rescue-vs-topup coupling | new | **NEW Low** (operational coupling). |

**Bottom line:** ss12m1 should be marked **FIXED**, not "incomplete-fix." The story-013 fix does
NOT repeat the M-07 mistake. The only residual exposure is an availability/footgun class
(pre-funding surplus), backstopped by `claimTimedOut` — no fund loss, no attacker.
