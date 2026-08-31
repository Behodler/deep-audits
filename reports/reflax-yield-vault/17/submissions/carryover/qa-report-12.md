> **Carryover QA report — audit 12** (cut down from `reports/reflax-yield-vault/12/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 17): **L-13, QA-02, QA-03, QA-04, QA-05, QA-06, QA-07, QA-08**.
> Removed as no longer live / carried elsewhere: C-01 (originating audit is **05**); F-01 and F-02 (faithfulness — carried in `spec-conformance-12.md`, Law-2 channel, never the QA bundle).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping** (originating report label → ledger entry):
> - `L-13` → ledger `L-13` / `1456259d8ac60c11`
> - `QA-02` → `70162a2a21764970`
> - `QA-03` → `e0e87eb205a9d4ec`
> - `QA-04` → `0ec32aa0ff1debcc`
> - `QA-05` → `459f4309e68542d7`
> - `QA-06` → `8019f1c9c6de5e43`
> - `QA-07` → `438a03b31ba6c923`
> - `QA-08` → `3060583f87f190ed`

*The text below is a verbatim copy of the retained sections of the original report.*

---

### [L-13] `_totalWithdraw` records a migration as executed even when `sharesToSell` floors to 0 for a tiny-balance client — principal left on the books, nothing moved <!-- id: ryv12l13 -->

**Location**: [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435`](../../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L404-L435) — `_totalWithdraw` (+ base `AYieldStrategy._executeWithdrawal`)

**Description**: `_executeWithdrawal` resets the two-phase `WithdrawalState` and emits `WithdrawalExecuted` **before** calling `_totalWithdraw` (correct CEI). But `_totalWithdraw` only zeroes `clientBalances` and decrements `totalDeposited` **inside `if (sharesToSell > 0)`**. For a client whose live balance is a tiny fraction of `totalDeposited`, `sharesToSell` can floor to 0; the function then returns having moved nothing and left the principal on the books, yet the state machine has already been reset and the migration recorded as executed.

**Impact**: No fund loss — the un-migrated client retains full principal. The hazard is operational: the owner may believe a migration completed when nothing actually moved. State-handling / incorrect-as-to-operational-intent only. (Distinct from the run-11 false-positive H-02: the shared cached-vs-live-read facet is *not* re-raised here; the false-migration-complete root cause is novel and benign.)

**Recommendation**: Either revert / flag when `sharesToSell` floors to 0 while non-zero principal remains, or explicitly document that a sub-threshold balance is a no-op migration.

---

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
