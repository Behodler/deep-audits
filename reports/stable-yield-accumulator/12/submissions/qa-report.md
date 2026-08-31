# QA Report — stable-yield-accumulator (run 12)

**Project:** stable-yield-accumulator
**Scope:** `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol` (+ `src/interfaces/IStableYieldAccumulator.sol`)
**Audited commit:** `71abe3e088559cb5d9c10e8475dc67e7cc57fac9`
**Run:** stable-yield-accumulator-12

This report bundles all QA-tier findings for the run: Low Risk, QA/Informational, and the project's
Centralization surface. The Medium finding (**M-01**, fail-open unconfigured-token zero-payment
drain) is submitted individually with a PoC, and the spec/faithfulness deviation (**F-01**, claim()
NatSpec payment-destination drift) is routed to the dedicated spec-conformance report — neither is
duplicated here. Three Low findings carried over from prior runs are still open and are listed (with
pointers to their carryover stubs) so they are not lost between runs. An automated QA/gas baseline
produced by **4naly3er** is attached as Appendix A.

## Summary

| Severity | Count | Labels |
|----------|:-----:|--------|
| Low Risk | 3 | L-04, L-05, L-06 |
| QA / Informational | 2 | QA-01, QA-02 |
| Centralization | 1 | C-01 |
| Carryover (still open) | 3 | L-01, L-02, L-03 |
| **Total (new this run)** | **6** | |

---

## Low Risk Findings

### [L-04] `setNudgeSplit(>0)` does not require `nudge != address(0)` — enabling the split before wiring the recipient bricks every yielding claim <!-- id: sya12l4 -->

**Location:** [StableYieldAccumulator.sol#L396-L402](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L396-L402) (`setNudgeSplit`); symmetric setter [`setNudgeAddress` #L385-L389](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L385-L389); read-side revert at [`claim` #L506](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L506)

**Description:** `setNudgeSplit` validates only `_split > 100` (`InvalidNudgeSplit`) and never checks
`nudge != address(0)`. The coupling invariant — *a non-zero split requires a configured nudge
recipient* — is enforced **only on the read side**, in `claim()` at L506
(`if (nudgeSplit > 0 && nudge == address(0)) revert NudgeNotConfigured()`). The contract therefore
permits entering the inconsistent `(nudgeSplit > 0, nudge == address(0))` state on the write side.
The natural configuration order (enable the split, then wire the recipient), or later clearing the
address via `setNudgeAddress(0)` while a split is active, lands in exactly this state. The L506
revert itself is **intended and documented** (story-023, `IStableYieldAccumulator` L276-279) — the
gap is purely that the setter does not enforce the invariant the claim path relies on.

**Impact:** No value loss. Availability only: while the inconsistent state holds, every yielding
`claim()` runs the skim loop and NFT-balance check then reverts `NudgeNotConfigured` at L506
atomically — no NFT is consumed and no funds move. Because the permissionless `claim()` is the
contract's sole purpose, yielding claims are fully bricked until the owner sets a valid nudge address
or returns the split to `0`. This is a non-obvious, owner-self-inflicted, immediately
owner-recoverable config-ordering footgun (Law 3), hence Low.

**Recommendation:** Enforce the invariant on the write side so the inconsistent state is
unreachable:

```solidity
// setNudgeSplit
if (_split > 0 && nudge == address(0)) revert NudgeNotConfigured();
// setNudgeAddress: reject clearing to address(0) while a split is active (or auto-zero the split)
if (_nudge == address(0) && nudgeSplit > 0) revert NudgeNotConfigured();
```

This makes the L506 claim-time check defensive rather than load-bearing. Safe config order today:
set the nudge **address** first, then enable the split; to disable, zero the split before clearing
the address.

---

### [L-05] `claim`/preview gas scales with (strategies × authorized-clients); above the discount-vs-gas threshold permissionless consolidation stalls <!-- id: sya12l5 -->

**Location:** [StableYieldAccumulator.sol#L552-L564](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L552-L564) (`_getYieldForStrategy`, clients loop at [#L556](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L556)); strategy loop in [`claim` #L464](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L464); nested in [`calculateClaimAmount` #L659](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L659) / [`getTotalYield` #L740](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L740)

**Description:** `claim()` loops every registered strategy (L464), calling `skimSurplus` once each.
The preview functions additionally nest `_getYieldForStrategy`'s `clients[]` loop (L556, over
`strategy.getAuthorizedClients()`) inside the strategy loop. As the strategy count and the
per-strategy authorized-client count grow, the gas to claim — and to fetch the quote that sizes
`minRewardTokenSupplied` — rises; once total gas exceeds `discount × pending-yield`, no rational
claimer claims. **This is not a permissionless DoS:** both growable dimensions are privileged —
`addYieldStrategy` is `onlyOwner`, and `IYieldStrategy.setClient` (which grows the per-strategy
client set) is strategy-owner-gated. The econ-scanner corrected the static/pattern "anyone
depositing grows the set" premise; no external party can force the stall. The root cause is SYA's own
loop over strategies/clients (in scope), so the "external strategy behavior OOS" known issue (#7)
does not cover it.

**Impact:** No value loss. Operational impairment only: above the gas-vs-incentive threshold the
permissionless consolidation stops being profitable, so strategy surplus accrues unconsolidated and
phlimbo stops receiving rewards. Preview (`calculateClaimAmount`/`getTotalYield`) can also revert on
gas for an oversized client set, denying claimers the quote they use to size
`minRewardTokenSupplied` (a claimer can still claim with `min = 0`). Self-correcting: the owner can
raise the discount or prune strategies; `exemptStrategies` (story-024) lets a claimer route around a
single pathological strategy (but not aggregate cardinality). Low.

**Recommendation:** Document a safe-config bound on (strategy count × typical client count) versus
the chosen discount, and keep the discount tunable to track gas. Consider pagination / a batched
claim over a strategy subrange. Point owner guidance at testing `claim` gas against the live
strategy/client cardinality before relying on permissionless consolidation.

---

### [L-06] Preview (snapshot estimate) diverges from charged amount (actual skim) with no payment ceiling; `getTotalYield` ignores per-token pause <!-- id: sya12l6 -->

**Location:** [StableYieldAccumulator.sol#L501](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L501) (`minRewardTokenSupplied` floor in `claim`); preview block [`calculateClaimAmount` #L651-L688](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L651-L688); [`getTotalYield` #L738](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L738); skim source [`claim` #L484](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L484)

**Description:** The previews (`calculateClaimAmount`, `getYield`, `getTotalYield`) price off the
snapshot estimate `_getYieldForStrategy = Σ(totalBalanceOf − principalOf)` over
`getAuthorizedClients()`, while `claim()` prices off `skimSurplus`'s post-redeem/post-swap
`underlyingReceived` (L484). This two-source design is **faithful/documented** (story-025;
`_getYieldForStrategy` NatSpec L542-547). Two SYA-side issues fold here:

- **(a) No payment ceiling.** `minRewardTokenSupplied` (L501) is a **floor only** — there is no
  maximum-payment guard. When the documented preview-vs-actual divergence makes actual > preview, a
  claimer who pre-approved exactly the quote has `claim()` revert on `safeTransferFrom` (claimer-side
  self-DoS; NFT preserved, gas wasted).
- **(b) View inconsistency.** `getTotalYield` (L738) does **not** skip
  `tokenConfigs[token].paused`, whereas `claim()`/`calculateClaimAmount()` do, so the global view
  over-reports relative to the actually-claimable set, mis-sizing integrator/bot quotes.

**Impact:** No protocol value loss and no third-party griefing. A claimer's payment always tracks the
yield they actually receive (`payment = (1 − discount) × value-of-delivered-yield` under correct
config), so an attacker who inflates the victim's `actualPayment` by donating surplus also gifts the
victim `discount × donation` — the econ-scanner concluded **no profitable sandwich exists**. Impact
is claimer-side UX/self-DoS plus unreliable bot quoting from the `getTotalYield` paused omission.
Low. (The strategy-side magnitude of the divergence roots in the OOS strategy adapter, KI#7, and is
scoped out; only the SYA-side slice is reported.)

**Recommendation:** Add an optional `maxRewardTokenSupplied` ceiling to `claim()` (symmetric to the
floor) so claimers can bound overpay; make `getTotalYield` skip paused tokens for consistency with
`claim()`/`calculateClaimAmount()`; document that `calculateClaimAmount` is an estimate and that
integrators should buffer approvals.

---

## QA / Informational Findings

### [QA-01] Permissionless first-claimer captures the entire accumulated discount in one shot; `minRewardTokenSupplied` defaults to 0 <!-- id: sya12qa1 -->

**Location:** [StableYieldAccumulator.sol#L484-L501](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L484-L501) (discount applied at [#L497](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L497))

**Description:** `claim()` skims all non-exempt strategies' surplus and applies the discount to the
whole sum in a single permissionless call (L497). Accumulated yield is a growing pot, so the first
valid-NFT caller captures the full discount on it. This **is** the designed
decentralized-conversion incentive (registry `designDecisions[0]`: "Discount rate incentivizes
external claimers to pay gas costs for conversion"). The pattern-matcher's "nudge winner-take-all"
signature is a red herring — the nudge pays a *proportional* share to an *owner-set* recipient
(L512). The only in-scope residual worth surfacing is that `minRewardTokenSupplied` defaults to `0`,
which disables the per-claim floor.

**Impact:** None beyond the budgeted incentive. The protocol pays exactly `discount × yield`
regardless of *who* claims, so there is no protocol value leak. Losers of the claim race revert with
`ZeroAmount` (NFT preserved, gas wasted) — ordinary MEV friction; the first claim empties the pot so
no sandwich exists. A careless/bot claimer passing `min = 0` accepts any amount, including the
dust/zero-payment edge (cross-ref **L-01**), harming only their own economics. Kept visible per
Law 1 rather than silently dropped as by-design.

**Recommendation:** None required for security. Optionally document the MEV/race expectation for
integrators and recommend claim bots always pass a non-zero `minRewardTokenSupplied` derived from
`calculateClaimAmount` (with a buffer) to avoid the dust/zero-payment edge.

---

### [QA-02] `nonReentrant` is not the first modifier on `claim()` <!-- id: sya12qa2 -->

**Location:** [StableYieldAccumulator.sol#L447](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L447) (`claim` modifier list)

**Description:** `claim()` declares `whenNotPaused nonReentrant` (L447), so `whenNotPaused` executes
before the reentrancy guard engages. `whenNotPaused` is a pure storage read of the `paused` flag with
no external call and no state change, so the ordering opens no reentrancy window and is harmless in
context. Flagged by a single static source (aderyn); likely a contextual false-positive, kept
visible as a one-line QA item (Law 1 recall over tidiness).

**Impact:** None. No exploit path exists.

**Recommendation:** Optionally reorder to `nonReentrant whenNotPaused` for defensive consistency. No
functional impact.

---

## Centralization Risks

### [C-01] Owner configuration authority — unbounded exchange rate and up-to-100% discount (centralization-by-design) <!-- id: sya11c1 -->

**Location:**
- [`setTokenConfig` #L280-L287](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L280-L287) — sets per-token `decimals` and `normalizedExchangeRate` (**unbounded**)
- [`setDiscountRate` #L324-L330](../../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L324-L330) — `discountRate` may be set up to `10000` bps (**100%**)
- single-step `Ownable` owner role across the setter surface

**Description:** This is a **documented centralization residual** (open ledger **C-01**,
fingerprint `a8ca46a1…`, first surfaced run 11), reproduced here for completeness — it is **not**
re-raised as a High. The owner alone controls the conversion economics: `normalizedExchangeRate` is
unbounded in `setTokenConfig` (L280-287) and `discountRate` may be set to `10000` bps = 100% in
`setDiscountRate` (L325). Both are **designed owner levers** — the exchange rate exists to handle a
permanent depeg, and a 100% discount is a valid claim-incentive extreme. A malicious owner could use
them to set claimer payment to zero, but per the audit's owner-trust law (Law 3) the owner is assumed
non-malicious for **knowing** actions, and this "owner drains" High framing is explicitly suppressed
under known issues #4/#5 (dedup record `SUPPRESS-001`; do not re-escalate).

What *is* in scope, and reported separately, are the **non-obvious** owner footguns that need no
malice — a single forgotten or mis-ordered setter that unknowingly enables an exploit or bricks the
core function:

- **Forgotten `setTokenConfig` on a sub-18-decimal strategy/reward token** — the fail-open
  `(decimals==0, rate==0) ⇒ 18-dec 1:1` default silently breaks value conservation. Reported in full
  as **M-01** (submitted individually with PoC).
- **`setNudgeSplit(>0)` before wiring the nudge recipient** — bricks every yielding claim. Reported
  as **L-04** above.

**Impact:** No additional impact beyond the cross-referenced findings; the privilege model itself is
intended and accepted. The residual risk is operational — an owner key compromise, or an unaware
operator triggering one of the non-obvious footguns above.

**Recommendation:** Manage the owner key behind a multisig; consider a timelock and/or
`Ownable2Step` so integrators can observe privileged changes. Adopt the targeted in-code guards from
the individual findings (a required `TokenConfig` link for M-01; a write-side nudge invariant for
L-04), which convert the most damaging footguns into clean reverts. Optionally document sane
operating bounds for `normalizedExchangeRate` and `discountRate` in a runbook.

---

## Carryover (still open)

Three Low findings from prior runs were re-confirmed live at HEAD `71abe3e` this run and remain
**open** (not fixed, not triaged). They are summarized below with one line each and a pointer to
their carryover stubs; see the original run-11 report for full description, impact, attack path, PoC,
and recommendation. Triage with `/ledger stable-yield-accumulator`.

- **[L-01]** `claim()` charges 0 payment while delivering skimmed yield (post-denormalize floor not
  re-guarded). Dust-only standalone (<1 ulp/claim, unprofitable) — **do not re-escalate** — but this
  is the exact mechanism **M-01 weaponizes ~1e12×** via a decimal misconfig; the proper fix (revert
  if `actualPayment == 0` for non-zero delivered yield) hardens both. Stub:
  [`carryover/L-01-CARRYOVER.md`](./carryover/L-01-CARRYOVER.md) · issueId `sya11l1`
- **[L-02]** Phlimbo standing-allowance depletion bricks permissionless `claim()` until the owner
  re-approves (availability only, owner-recoverable, no value loss). Stub:
  [`carryover/L-02-CARRYOVER.md`](./carryover/L-02-CARRYOVER.md) · issueId `sya11l2`
- **[L-03]** `claim()` NatSpec says pay-then-skim; code skims-then-pays (doc/impl mismatch). Extended
  this run by **F-01** (claim() NatSpec also documents a direct claimer→phlimbo transfer vs the
  story-023 nudge-split routing); the faithfulness facet is routed to `submissions/spec-conformance.md`,
  not duplicated here. Stub: [`carryover/L-03-CARRYOVER.md`](./carryover/L-03-CARRYOVER.md) ·
  issueId `sya11l3`

---

## Appendix A — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated analyzer **4naly3er** was run against the in-scope contract
(`src/StableYieldAccumulator.sol`) at the audited commit, using the buildable workspace copy. Its
full markdown output is attached alongside this report and archived under the run's static dir:

**[`4naly3er-report.md`](./4naly3er-report.md)** (also at `reports/stable-yield-accumulator/12/static/4naly3er-report.md`)

Headline counts from that run: **13** Gas-optimization classes, **17** Non-Critical classes, **7**
Low-issue classes, and **2** Medium-band classes. The two Medium-band bot findings are reconciled as
follows:

- **M-1 (fee-on-transfer accounting):** a standard automated flag. Fee-on-transfer / non-standard
  tokens are a documented known-invalid category for this project (no FoT token is in scope), so it
  is not promoted to a manual finding.
- **M-2 (centralization risk for trusted owners, 15 instances):** the same privilege surface
  manually adjudicated above as **C-01**; the bot flag corroborates it.

Among the bot Lows, **L-4 "Division by zero not prevented"** and the slippage/`address(0)` checks
relate to the payment-floor and config-validation behaviour analysed manually in **M-01 / L-01 /
L-04 / L-06**, and **L-1 / L-7 "2-step ownership"** corroborate the `Ownable2Step` recommendation in
**C-01**. The remaining output is automated baseline (style, gas, NatSpec, magic numbers, event
old/new values, etc.) and is retained verbatim in the appendix for completeness rather than re-listed
here.
