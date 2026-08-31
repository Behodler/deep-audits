# QA Report — reflax-yield-vault (Run 12)

Commit: `2306719d8f992b31f00ba228cbca9f8768447197` · Cold `--full` re-scan (crash-recovery) of the same commit as run-11.

## Summary

| Severity | Count |
|---|---|
| Low Risk (new) | 1 |
| QA / Info (new) | 7 |
| Centralization (carried over) | 1 |
| Still-open Lows from prior runs (carryover) | 4 |
| **Total open items** | **13** |

> **Scope note.** The two Law-2 faithfulness findings from this run (F-01 provable-solvency
> invariant overstatement, F-02 `IYieldStrategy` NatSpec staleness) are **not** in this bundle;
> they are routed to the separate `spec-conformance.md` report. The lone Medium candidate
> `M-01-run12` (realizable-solvency value leak) was PoC-tested at this commit and **collapsed
> into the acknowledged M-02** (its owner-bounded operational residual survives here as
> **QA-08**). Neither appears as a QA item.

---

## Low Risk Findings

### [L-13] `_totalWithdraw` records a migration as executed even when `sharesToSell` floors to 0 for a tiny-balance client — principal left on the books, nothing moved <!-- id: ryv12l13 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435`](../../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435) — `_totalWithdraw` (+ base `AYieldStrategy._executeWithdrawal`)

**Description**: `_executeWithdrawal` resets the two-phase `WithdrawalState` and emits `WithdrawalExecuted` **before** calling `_totalWithdraw` (correct CEI). But `_totalWithdraw` only zeroes `clientBalances` and decrements `totalDeposited` **inside `if (sharesToSell > 0)`**. For a client whose live balance is a tiny fraction of `totalDeposited`, `sharesToSell` can floor to 0; the function then returns having moved nothing and left the principal on the books, yet the state machine has already been reset and the migration recorded as executed.

**Impact**: No fund loss — the un-migrated client retains full principal. The hazard is operational: the owner may believe a migration completed when nothing actually moved. State-handling / incorrect-as-to-operational-intent only. (Distinct from the run-11 false-positive H-02: the shared cached-vs-live-read facet is *not* re-raised here; the false-migration-complete root cause is novel and benign.)

**Recommendation**: Either revert / flag when `sharesToSell` floors to 0 while non-zero principal remains, or explicitly document that a sub-threshold balance is a no-op migration.

---

## QA / Informational Findings

### [QA-02] `block.timestamp` drives the two-phase withdrawal window (24h waiting / 48h execution) — load-bearing and intended; miner drift negligible <!-- id: ryv12qa2 -->

**Location**: [`src/AYieldStrategy.sol#L441`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L441) — `_updateWithdrawalStatus`

**Description**: `_updateWithdrawalStatus` uses `block.timestamp` for the two-phase window comparisons (`>= initiatedAt + WAITING_PERIOD`, `<= initiatedAt + TOTAL_DURATION`, `> initiatedAt + TOTAL_DURATION`). The 24h/48h windows dwarf any plausible validator timestamp drift (~12s), so the window cannot be straddled.

**Impact**: None. The timestamp logic is intended and load-bearing; drift is negligible against a 24h/48h window. Retained as a visible informational note per the static stage's Law-1 policy for a time-driven protocol.

**Recommendation**: No action required.

---

### [QA-03] Unit-mismatch owner footgun: `setAsideBufferSize` is PERCENT (0–100) while `slippageToleranceBps` is BPS (0–10000) <!-- id: ryv12qa3 -->

**Location**: [`src/AYieldStrategy.sol#L253-L259`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L253-L259) — `setSetAsideBuffer` / `setSlippageTolerance`

**Description**: Two owner-set parameters use different unit conventions: `setAsideBufferSize` is a percent (0–100) while `slippageToleranceBps` is bps (0–10000). An owner passing `50` expecting 0.5% (or vice versa) would misconfigure a setter. Both are owner-gated and documented, but the inconsistency is a latent, non-obvious footgun (Law-3 in-scope: a competent non-malicious owner could be surprised).

**Impact**: No direct asset/availability impact; an owner conflating the two unit conventions would misconfigure a setter.

**Recommendation (safe-config)**: Standardize on one unit convention, or clearly document the percent-vs-bps difference at each setter.

---

### [QA-04] `totalWithdrawal` carries `whenNotPaused` — a Global-Pauser pause blocks the two-phase migration until unpause (emergencyWithdraw remains as fallback) <!-- id: ryv12qa4 -->

**Location**: [`src/AYieldStrategy.sol#L319`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L319) — `totalWithdrawal`

**Description**: `totalWithdrawal` is `whenNotPaused`, so a Global-Pauser pause blocks even the legitimate two-phase migration until unpause. `emergencyWithdraw` (no pause gate) remains available to the owner as the unblocked fallback to the same funds, so this is a degraded-availability note, not a lockup.

**Impact**: None. Degraded availability of the migration path during an active pause; funds are never trapped because `emergencyWithdraw` is the unblocked owner fallback, so it does not reach the Medium availability bar.

**Recommendation**: Accept as documented design, or note the `emergencyWithdraw` fallback explicitly in operator docs.

---

### [QA-05] `CurveAMMAdapter` has no rescue/sweep function — accidentally-sent tokens or under-consume dust are stranded <!-- id: ryv12qa5 -->

**Location**: [`src/AMMAdapters/CurveAMMAdapter.sol#L120-L141`](../../../../lib/reflax-yield-vault/src/AMMAdapters/CurveAMMAdapter.sol#L120-L141) — `swap` / contract-wide

**Description**: `CurveAMMAdapter` has no `onlyOwner` sweep/rescue function. Router output is sent to `msg.sender` (not the adapter), so the stateless adapter retains nothing in the happy path; this is only an edge concern for accidentally-sent tokens or router under-consume dust, which would be permanently stranded.

**Impact**: Negligible, given the stateless design; no security impact.

**Recommendation**: Consider an `onlyOwner` rescue for stranded tokens, or accept as negligible.

---

### [QA-06] `setClient` ignores the bool return of `EnumerableSet.add/remove` — idempotent re-adds / removal of a non-member silently succeed <!-- id: ryv12qa6 -->

**Location**: [`src/AYieldStrategy.sol#L187-L189`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L187-L189) — `setClient`

**Description**: `setClient` ignores the bool return of `EnumerableSet.add`/`remove`, so an idempotent re-add or a removal of a non-member silently emits success; the caller cannot distinguish a no-op from an effective change. (Two corroborated Slither + Aderyn unused-return flags on the same setter.)

**Impact**: None — set membership stays correct; event/return-fidelity only.

**Recommendation**: Check the bool return and revert or emit a distinct event on a no-op, or document the idempotent semantics.

---

### [QA-07] Integration caveat: `skimSurplus` return value (post-swap underlying delivered) can diverge from the sum of `SurplusSkimmed.amount` events (pre-swap vault-asset snapshot) <!-- id: ryv12qa7 -->

**Location**: [`src/interfaces/IYieldStrategy.sol`](../../../../lib/reflax-yield-vault/src/interfaces/IYieldStrategy.sol) + [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L432-L521`](../../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L432-L521) — `skimSurplus` / `_skimSurplus`

**Description**: `skimSurplus` returns the post-swap underlying actually delivered, while `SurplusSkimmed` events carry the pre-swap snapshot in vault-asset terms; these can diverge by the AMM execution gap. A downstream consumer (e.g. `stableYieldAccumulator`) that assumes equality of the return value and the summed event amount would mis-account. Distinct facet from the open ledger Lows L-06 (return-value path-dependence: fast vs buffered) and L-05 (event under-represents beneficiaries); cross-referenced rather than folded into those dormant entries (Law-1 recall).

**Impact**: None on this contract; an integration accounting hazard for a downstream consumer that wrongly assumes `return == event sum`. Documented in NatSpec.

**Recommendation**: Document that the `skimSurplus` return value (post-swap delivered) and `SurplusSkimmed` event amount (pre-swap snapshot) are not equal; downstream integrators must reconcile on the return value.

---

### [QA-08] World-C skim-de-buffering owner footgun: routinely running `skimSurplus` strips the protective over-collateralization buffer for zero upside, removing the depeg cushion <!-- id: ryv12qa8 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L457-L521`](../../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L457-L521) — `_skimSurplus` / `skimSurplus`

**Description**: `skimSurplus` harvests the vault-rate surplus, which **includes** the deposit-time slippage-haircut over-collateralization buffer (`held·p − D`) that absorbs an sUSDe AMM discount. Running `skimSurplus` routinely — e.g. as a scheduled keeper/operator hygiene action — strips this buffer for **no protocol upside** (the surplus is owner/client-directed yield that is not at risk if left in place) while removing the cushion ahead of a possible sUSDe depeg. This is the honest QA-level residual of the collapsed `M-01-run12` Medium: under a beyond-tolerance discount (World-C) every protocol withdrawal path **reverts** rather than realizing a shortfall, so the realized loss does **not** reach depositors. The loss materializes only via the owner's own `emergencyWithdraw` + OTC force-sale of the restricted shares at the discounted rate — Law-3 owner-bounded, not a depositor-reachable Medium. Confirmed by the collapse PoC's World-C test and an independent adversarial validator.

**Impact**: No depositor-reachable asset or availability impact: under a beyond-tolerance discount all protocol withdrawal paths revert rather than realize the shortfall. The realized loss is reachable only through the owner's own `emergencyWithdraw` + OTC force-sale — an owner-bounded operational hazard. Same vault-rate-vs-AMM-rate root cause as the acknowledged M-02; the depositor-reaching escalation was disproved by the `M-01-run12` PoC collapse.

**Likelihood**: Non-obvious operator/keeper footgun (Law-3 in-scope): an operator routinely skimming for surplus hygiene would not expect to be eroding the protocol's depeg cushion for zero upside.

**Safe-config guidance**:
- Do **not** run `skimSurplus` as a routine/scheduled hygiene action.
- Skim only against a realized, durable surplus, and **retain a protocol-favoring buffer at skim time** so de-buffering cannot strip the discount cushion ahead of a depeg.
- Treat `emergencyWithdraw` + OTC sale of restricted shares under a live discount as the genuine loss locus and gate it accordingly.

**Recommendation**: Either retain a protocol-favoring buffer at skim time, or document operationally that `skimSurplus` should not be run routinely while a depeg risk exists. No on-chain mitigation is strictly owed beyond the M-02 acknowledgement; this is surfaced so the operational hazard is not lost. Folds under the existing acknowledged M-02 + C-01 owner-power envelope.

---

## Centralization Risks

### [C-01] Centralization / owner-power bundle (carried over — still open) <!-- id: ryv5c1 -->

**Status**: open · **First seen**: reflax-yield-vault-05 · **Still present as of**: reflax-yield-vault-12
**Original report**: [`reports/reflax-yield-vault/05/submissions/qa-report.md`](../../05/submissions/qa-report.md)
**Locations**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` + `src/AYieldStrategy.sol` — `setRoute`, `setSlippageTolerance`, `depositAsOwner`, `withdrawAsOwner`, `emergencyWithdraw`, `setClient` (authorized-client set), `setSetAsideBuffer` (per-client buffer), single-recipient skim, two-phase `totalWithdrawal`.

**Description (carried over, not re-analyzed)**: The strategy concentrates broad configuration and fund-movement power in a single owner across the setters and privileged entry points listed above. This bundle documents the aggregate owner-power surface; specific setter-design defects within the envelope are tracked as their own extending Lows (**L-03**, **L-04**, **L-07**) and the run-11 sub-elements folded here (`emergencyWithdraw` accounting desync, `withdrawAsOwner` timelock bypass — acknowledged by-design, `setSlippageTolerance` accepting `MAX_BPS`). The bot's automated centralization flag (4naly3er **M-2**, 5 instances — see appendix) maps entirely into this envelope.

**Recommendation**: Per the original report — narrow owner power where feasible (sane bounds on setters, multi-sig/timelock on fund-movement entry points). No new analysis this run; carried so the reader sees all open centralization surface. Triage with `/ledger reflax-yield-vault`.

---

## Carryover — Still-Open Lows From Prior Runs

These were reported in prior runs and remain **open** (not fixed, not triaged). They were re-flagged this run; full write-ups live in the linked carryover stubs. Triage with `/ledger reflax-yield-vault`.

| Label | Title | First seen | Stub | Original report |
|---|---|---|---|---|
| L-01 `<!-- id: ryv5l1 -->` | `slippageToleranceBps` default-0 plus setter missing sane cap | run-05 | [stub](carryover/L-01-CARRYOVER.md) | [run-05 qa-report](../../05/submissions/qa-report.md) |
| L-07 `<!-- id: ryv7l7 -->` | `setRoute` accepts `tokenIn == tokenOut` / zero-gap segments — relies on off-chain verification | run-07 | [stub](carryover/L-07-CARRYOVER.md) | [run-07 L-07.json](../../07/findings/low/L-07.json) |
| L-01-run11 `<!-- id: ryv11l1 -->` | CEI violation in `_withdrawInternal`/`_depositInternal` — latent reentrancy exposure | run-11 | [stub](carryover/L-01-run11-CARRYOVER.md) | [run-11 L-01.json](../../11/findings/low/L-01-cei-violation-withdraw-internal.json) |
| L-04-run11 `<!-- id: ryv11l4 -->` | `nonReentrant` is not the first modifier across 6 entry points (defense-in-depth) | run-11 | [stub](carryover/L-04-run11-CARRYOVER.md) | [run-11 L-04.json](../../11/findings/low/L-04-nonreentrant-modifier-ordering.json) |

> Other prior-run Lows (e.g. L-03/L-04/L-05/L-06 from run-07, L-02..L-13 from run-11) remain in
> the ledger at their last-recorded status and were **not** re-flagged this same-commit run; they
> are not reproduced here. The authoritative list is the ledger (`/ledger reflax-yield-vault`).

---

## Appendix — Automated SAST / Gas Report (4naly3er)

> Generated by [4naly3er](https://github.com/Picodes/4naly3er) against the two in-scope contracts:
> - `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
> - `src/AMMAdapters/CurveAMMAdapter.sol`
>
> Full machine-generated output: [`4naly3er-report.md`](4naly3er-report.md)

The automated scan surfaced **no Low/NC/Medium item that is not already covered** by a manual finding, a carryover, the C-01 envelope, or the project's known-invalid list:

| Bot ID | Bot issue | Disposition |
|---|---|---|
| M-1 (2×) | Fee-on-transfer accounting | Known-invalid (FoT tokens out of scope; route is USDe/sUSDe). |
| M-2 (5×) | Centralization risk for trusted owners | Folded into **C-01**. |
| M-3 (4×) | `increaseAllowance` won't work for USDT | Known-invalid for this route (USDe/sUSDe, not USDT); allowance-hygiene angle already tracked as run-11 L-02. |
| L-1 / L-7 (1× each) | Use `Ownable2Step` | Already captured as run-11 L-08 (Ownable2Step) in the ledger. |
| L-2..L-6, L-8 | Zero-value-transfer revert, div-by-zero, rounding/precision, PUSH0/`0.8.20+` chain compat, assembly-optimizer-bug version | Standard bot noise; no demonstrated H/M path. |
| NC-1..NC-18 | Style / NatSpec / naming / ordering | Non-critical; C4 discourages — not bundled. |

Gas optimizations identified (15 categories; full instance lists in the attached report):

| ID | Issue | Instances |
|---|---|---|
| GAS-1 | `a = a + b` cheaper than `a += b` for state vars | 5 |
| GAS-2 | Use assembly to check for `address(0)` | 10 |
| GAS-3 | Cache array length outside loops | 2 |
| GAS-4 | Cache state variables read multiple times | 4 |
| GAS-5 | Use `unchecked` for operations that cannot overflow | 42 |
| GAS-6 | Custom errors instead of revert strings | 26 |
| GAS-7 | Avoid contract-existence checks with low-level calls | 6 |
| GAS-8 | Stack cache for a state var used only once | 1 |
| GAS-9 | Constructor-only state vars should be `immutable` | 4 |
| GAS-10 | Restricted functions can be marked `payable` | 2 |
| GAS-11 | `++i` cheaper than `i++` | 3 |
| GAS-12 | `private` constants cheaper than `public` | 1 |
| GAS-13 | `this.fn()` call; mark function `public` | 1 |
| GAS-14 | Loop increments can be `unchecked` | 3 |
| GAS-15 | `!= 0` instead of `> 0` for unsigned | 8 |

The most actionable gas items are **GAS-6** (26 revert strings → custom errors, also reduces deployment cost) and **GAS-9** (4 constructor-only state variables → `immutable`). These are optimization recommendations only; none represent security vulnerabilities.
