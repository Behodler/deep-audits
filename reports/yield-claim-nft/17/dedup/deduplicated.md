# Deduplicated Candidate List — PromotionUniV2_Eth.sol (yield-claim-nft run-17)

- **Project:** yield-claim-nft
- **Target:** `src/dispatchers/PromotionUniV2_Eth.sol` (story-044, NEW dispatcher, 401 LOC)
- **Submodule HEAD:** `8dd8963`
- **Deduplicator:** consolidating STATIC-001..005, pattern #1..7, code-scan (L-1/NOTE-2/3/4), ECON-001..005, F-01-044/F-02-044, Tier-3 invariants (all HELD).
- **Date:** 2026-07-18

## Method note

The scanners converge hard on three root issues plus a QA-hardening cluster. Nothing security-relevant is dropped: every raw item is either (a) consolidated into a candidate below with its `originalIds` preserved, (b) kept visible as a QA item, (c) kept visible as **DEDUP-001 project-suppressed** with a reconciliation pointer, or (d) reconciled to an **open ledger label** (L-06 / L-09). One borderline Law-3 call is additionally logged in the visible `manual-review.json` park. Tier-3 produced no new findings — it *corroborated* the Low classifications under real-fork fuzzing.

### One deliberate divergence from the task's grouping (documented)

The task lumped "whole-balance ETH sweep **+** `amountMin=0` addLiquidity" as ONE candidate. On inspection these are **two distinct root causes** and are split accordingly:

- The **whole-balance ETH sweep + open `receive()`** (→ **CANDIDATE-1**) is a *value-misattribution / donation accounting* footgun. It is protocol-**positive** (stray/donated ETH routes into protocol-owned LP), non-theft, and has no market-extraction (MEV) component. Root = "stray ETH folded into next pool."
- The **`amountMin=0` addLiquidity + unforced slippage floors + spot-ratio pooling** (→ **CANDIDATE-2**) is the *keeper-quoted-floor sandwich / MEV* class that **extends open ledger L-06**. Root = "public `pool()` tx sandwichable up to keeper quote slack."

They share the *same code region* (`_legB` / `addLiquidity`) but different root causes, different attack economics, and different mitigations — so per the "keep both when root causes differ" rule they are kept separate. Pattern #3 maps to CANDIDATE-1; patterns #1 and #2 map to CANDIDATE-2. ECON-001 (MEV) is therefore kept separate from ECON-002 (sweep), as the task's fallback option anticipated.

`STATIC-005` (addLiquidity ignored `amountA`/`amountB` = dust) is filed in the **QA cluster** as its by-design home (QA-e); it corroborates the excess-side refund behavior referenced by both CANDIDATE-1 and CANDIDATE-2 but is not itself a second copy of either. (The task listed STATIC-005 in both buckets — this resolves that ambiguity to the QA bucket.)

---

## Consolidated candidates

### CANDIDATE-1 — Whole-balance ETH sweep + open `receive()` folds stray/donated ETH into the next pool's promotion buy
- **canonicalTitle:** Leg-B swaps the entire contract ETH balance (not just the leg's swap output); open `receive()` lets any third-party ETH be swept into the next authorized `pool()` at that keeper's floors.
- **contract:function:line:** `PromotionUniV2_Eth._legB` L342-345 (`ethBal = address(this).balance` → `swapExactETHForTokens{value: ethBal}`); `receive()` L400
- **mergedSourceRefs:** F-01-044 (faithfulness, Law-3 footgun) · ECON-002 (econ, protocol-positive misallocation) · code-scan **L-1** (CONFIRMED behavior) · pattern **#3** (SELFDESTRUCT-FORCE-ETH / stuck-ETH) · corroborated by Tier-3 **INV-3** (no stranded ETH) + **INV-4** (ETH bounded by donations, routes to LP only) — both HELD
- **preliminarySeverity:** **Low / QA** (Law-3 footgun; faithfulness verdict "intended-but-under-specified"; benign under normal operation, surprising only under external-ETH conditions). No theft, no DoS, no profitable attacker (donor subsidizes their own victim's buy).
- **status:** **NEW**
- **notes:** Accidental-send variant overlaps C4 known-invalid ("user input mistake"); the deliberate-donation variant benefits the protocol. Keep as QA transparency + owner note (`rescueETH` L393 recovers, but a pooler can front-run it). Recommend a code comment that the full-balance sweep is intentional so a future maintainer does not "fix" it into a leak.

### CANDIDATE-2 — `pool()` MEV/sandwich exposure: unforced (zero-allowed) slippage floors + `amountMin=0` addLiquidity + spot-ratio pooling
- **canonicalTitle:** All five slippage params are caller-supplied and none is forced non-zero on-chain; `addLiquidity` passes `amountAMin=amountBMin=0`; every router/vault call uses a `block.timestamp` (never-expiring) deadline. A public `pool()` tx is sandwichable up to the slack the keeper leaves in its quotes.
- **contract:function:line:** `PromotionUniV2_Eth.pool` L277-307; `addLiquidity(...,0,0,...)` L299-301; `_legB` swap floors L337-345; deadline args L300/L338/L344; post-check `require(liquidity >= minLP)` L302
- **mergedSourceRefs:** ECON-001 (MEV, LOW, extends L-06) · pattern **#1** (MISSING-SLIPPAGE) · pattern **#2** (FLASH-LOAN-PRICE / spot-ratio addLiquidity) · code-scan **NOTE-2** (deferred to econ) · **STATIC-002** (deadline == `block.timestamp`, MEV facet) · faithfulness "deliberate design choices" (amountMin=0 documented intentional)
- **preliminarySeverity:** **Low** (settled by precedent — same authorized-pooler + keeper-quoted-floor + post-call `minLP` control model that kept L-06 at Low; the new ETH leg adds *more legs of the same class*, not a new class; PSM `sellGem` is fixed-rate, no market slippage). `minLP` jointly guards both LP sides (bounded by the scarcer side). Residual risk = keeper laziness/bug passing `0` floors — operational, no permissionless trigger.
- **status:** **RECONCILES-TO-L-06** (open, Low). Do not mint a new label; do not re-escalate settled precedent absent a concrete new vector (none found).
- **notes:** Non-blocking defense-in-depth suggestion: force `minLP > 0` and/or non-zero `amountAMin/BMin` so a zero-floor keeper call cannot silently ship. The `block.timestamp`-deadline sub-issue is Low/QA on its own and is *also* listed as QA-a below (same underlying arg, two lenses — MEV facet here, standalone QA hardening there).

### CANDIDATE-3 — Unwired mint-debt hook fail-open: `dispatch` silently accrues zero phUSD debt (no `hookTypeId` guard)
- **canonicalTitle:** The dispatcher reuses the Uniboost `_dispatch → hook.onDispatch(GROSS amount)` path with no `hookTypeId` verification; `hook` defaults to a no-op `DefaultDispatchHook`. If the owner never wires the mint-debt hook, NFTs mint while zero phUSD mint-debt accrues (unbacked-phUSD fail-open).
- **contract:function:line:** `PromotionUniV2_Eth._dispatch` (L255-262) → base `ATokenDispatcherV2.dispatch` → `hook.onDispatch(...)`; no `hookTypeId`/`keccak256` guard in this file
- **mergedSourceRefs:** F-02-044 (faithfulness) · ECON-003 (econ, L-09 recurrence) · code-scan **NOTE-4** (carried, not new) · pattern **#5** (CENTRALIZATION-ADMIN / hook fail-open, L-09/Q-08 carryover)
- **preliminarySeverity:** **Low** (config footgun; the hook *call* is faithful — gross amount passed, test-verified — the gap is the missing "is the real hook wired?" verification)
- **status:** **RECONCILES-TO-L-09** (open). Fourth dispatcher to carry the class (Uniboost L-09; BalancerPoolerV2; NudgeRatchet* gate it). Surface-for-triage, **do not auto-collapse into Q-08**, do **not** re-file as new (consistent with run-13 L-09 memory note and prior L-09 triage).

---

## Suppressed — kept VISIBLE (not merged into any active candidate)

### SUPPRESSED-DEDUP-001 — phUSD gross-amount mint-debt vs donation split (external-backing)
- **contract:function:line:** `_dispatch` L255-262 (donates `amount*split/100` USDC to `batchMinter`) + base `hook.onDispatch(GROSS amount)` + `UniboostMintDebtHook.onDispatch` (`ratio ≤ 50`)
- **mergedSourceRefs:** code-scan **NOTE-3** · pattern **#4** (MINT-ON-DEMAND-OVERMINT) · ECON "Non-findings verified" backing note
- **assessment:** Direction is **over-backing, not under-mint** — the split relocates *where* backing is pooled; it does not create unbacked phUSD (same convention as Uniboost/BalancerPoolerV2, no new deviation). This is the **DEDUP-001 external-backing class, project-SUPPRESSED** for yield-claim-nft (backing handled externally; NFTs have no redemption leg).
- **disposition:** **Kept visible as suppressed** — routed to sanitizer for DEDUP-001 reconciliation. **NOT** merged into an active finding and **NOT** proposed as new. Re-emit only if a *new* unbacked-mint path appears (none here). The one open cross-contract assumption (that `batchMinter` does not itself double-accrue debt on the donated USDC) is owned by the BalancerPooler wiring, not this contract.

---

## QA hardening cluster (consolidated; individually listed) — all NEW, QA/Low

Grouped root theme: defensive-hardening on the new dispatcher's external-call surface. Consolidated for triage but each kept individually addressable.

| ID | Item | contract:function:line | Source refs | Severity | Disposition |
|----|------|------------------------|-------------|----------|-------------|
| QA-a | `block.timestamp` swap/LP deadlines provide no effective expiry | `_legB` L338/L344; `addLiquidity` L300 | ECON-005 · STATIC-002 | QA/info | Real protection is per-leg floors + `minLP`; also the deadline facet of CANDIDATE-2. Informational. |
| QA-b | Unchecked router return values on ETH swap path (Leg B) | `_legB` L337, L343-345 | STATIC-001 (slither+aderyn) | QA/Low | Value-loss bounded by `minEthOut`/`minPromoOut` floors; code reads `address(this).balance` instead of `amounts[]`. Confirm floors are the sole slippage guard. |
| QA-c | Unchecked Balancer V3 `settle` return in `unlockCallback` | `unlockCallback` L375-376 | STATIC-004 (slither) | QA/info | Balancer `unlock` reverts if transient debt unsettled; `settle(sUSDS, sharesIn)` uses exact transferred amount → shortfall reverts whole `pool()`. Code-scan trace #7 CLEARED. Informational. |
| QA-d | `nonReentrant` is not the first modifier on `pool()` | `pool` L277-282 (order: `onlyAuthorizedPooler`, `whenNotPaused`, `nonReentrant`) | STATIC-003 (aderyn) | QA | Preceding modifiers only read state (no external calls) → practical risk minimal; best-practice hardening note. |
| QA-e | `addLiquidity` return `amountA`/`amountB` ignored → residual dust | `pool` L299-301 | STATIC-005 (slither) · pattern #7 | QA | **By-design & documented** (NatSpec L292-294: "residual dust accrues for next pool()"); recoverable via `rescueERC20`. Corroborates the excess-side-refund behavior in CANDIDATE-1/2. Retained only to confirm documented dust. |
| QA-f | `setMaxTin` uncapped (sole Leg-A PSM guard) | `setMaxTin` L208-211; consumed `_legA` L315 | ECON-004 · pattern #5 (setter surface) | QA (Law-3) | **Borderline** — pattern-matcher flags owner footgun; econ-scanner suppresses under Law-3 (name/NatSpec make the fee-ceiling consequence obvious; PSM `sellGem` is fixed-rate → bounded to accepted fee, not open-ended drain). Kept visible here AND logged to `manual-review.json` so triage explicitly confirms the `maxTin` default (1e16 = 1%) stays tight. |

---

## Reviewed and CLEARED (non-findings — recorded so they are not re-raised)

- **pattern #6 — REENTRANCY-ERC777** on arbitrary `promotionToken` transfer hooks: affirmatively cleared by code-scan trace #6 and econ "Reentrancy" non-finding (shared OZ `nonReentrant` on `pool`/`dispatch`; `unlockCallback` hard-gated to `BALANCER_VAULT` and only reachable inside the guarded `pool()` frame; no profitable reentry target). Tier-3 reentrancy behavior corroborated (INV-1b no dangling approvals HELD). **Resolved non-finding, not a park.**
- **Faithfulness deliberate-design confirmations** (F-scan §"Deliberate design choices"): `amountMin=0` (documented), `block.timestamp` deadline (same-block atomic under auth+nonReentrant), PSM no per-tx floor (only `maxTin`), gross-amount mint-debt while donation skimmed, `pool()` does not invoke the dispatch hook — all confirmed conformant to story-044. Not findings.
- **STATIC "FILTERED" tool noise:** gas/style Semgrep (173 items), 11× centralization (Law-3 owner-trusted), `missing-zero-check` on `setBatchMinter` (by-design disable), `unused-state` WAD, pragma/PUSH0/literal QA, spurious `timestamp` on `minLP` comparison, `too-many-digits` in OZ `lib/`. Genuine tool-noise / OOS root cause — outright-removal category (b), logged with reasons in `static-findings.md`.
- **Non-target pre-existing first-party flags** (`BalancerPoolerV2`, `MultiPooler`, `NFTMinterV2` slither hits): outside the story-044 changed set; carried in static report for context only, route to a cold full-scope scan if desired. Not this run's candidates.
- **Tier-3:** all 7 invariants HELD (no new findings); corroborates the Low classifications, does not introduce candidates.

---

## Set-aside ledger (Law 1 — nothing dropped to /dev/null)

| Raw item | Disposition | Where it is now visible |
|----------|-------------|-------------------------|
| STATIC-001..005 | consolidated | CANDIDATE-2 (STATIC-002) + QA-a..e |
| pattern #1,#2 | consolidated | CANDIDATE-2 |
| pattern #3 | consolidated | CANDIDATE-1 |
| pattern #4 | suppressed-visible | SUPPRESSED-DEDUP-001 |
| pattern #5 | consolidated | CANDIDATE-3 + QA-f |
| pattern #6,#7 | cleared / QA | "Reviewed and CLEARED" + QA-e |
| code-scan L-1 | consolidated | CANDIDATE-1 |
| code-scan NOTE-2 | consolidated | CANDIDATE-2 |
| code-scan NOTE-3 | suppressed-visible | SUPPRESSED-DEDUP-001 |
| code-scan NOTE-4 | consolidated | CANDIDATE-3 |
| ECON-001 | reconciled | CANDIDATE-2 → L-06 |
| ECON-002 | consolidated | CANDIDATE-1 |
| ECON-003 | reconciled | CANDIDATE-3 → L-09 |
| ECON-004 | QA + parked | QA-f + `manual-review.json` |
| ECON-005 | QA | QA-a |
| F-01-044 | consolidated | CANDIDATE-1 |
| F-02-044 | reconciled | CANDIDATE-3 → L-09 |
| Tier-3 INV-1..4 | corroboration | supports CANDIDATE-1 severity |

**Nothing was silently dropped.** The single borderline suppression (ECON-004 `setMaxTin`, Law-3) is additionally written to the visible `manual-review.json` park with reason + confidence.

## Output summary (for downstream sanitizer → severity-classifier)

| Candidate | Title (short) | Location | Prelim severity | NEW / RECONCILES |
|-----------|---------------|----------|-----------------|------------------|
| CANDIDATE-1 | Whole-balance ETH sweep + open `receive()` | `_legB` L342-345 / `receive()` L400 | Low / QA | **NEW** |
| CANDIDATE-2 | `pool()` MEV: unforced floors + `amountMin=0` + spot-ratio + ts-deadline | `pool` L277-307 / L299-301 | Low | **RECONCILES-TO-L-06** |
| CANDIDATE-3 | Unwired mint-debt hook fail-open (no `hookTypeId` guard) | `_dispatch` → `hook.onDispatch` | Low | **RECONCILES-TO-L-09** |
| SUPPRESSED-DEDUP-001 | phUSD gross-backing / donation split | `_dispatch` L255-262 | — (suppressed) | project-SUPPRESSED (visible) |
| QA-a..f | Deadline / unchecked-returns / modifier-order / dust / setMaxTin | various | QA/Low | **NEW** (QA cluster) |
