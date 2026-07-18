# Sanitized + Ledger-Reconciled Finding Set — yield-claim-nft run-17

- **Project:** yield-claim-nft
- **Target:** `src/dispatchers/PromotionUniV2_Eth.sol` (story-044, NEW dispatcher)
- **Submodule HEAD:** `8dd8963`
- **Ledger:** `reports/ledgers/yield-claim-nft.json` (30 entries; `lastAuditedCommit` f46a5cb, `lastRun` yield-claim-nft-16)
- **Known issues:** 7 (from `registered-projects.json → yield-claim-nft.knownIssues`)
- **Agent:** sanitizer
- **Date:** 2026-07-18

Input from deduplicator: 3 active candidates + 1 project-suppressed pointer + a 6-item QA cluster (a..f). Nothing was silently dropped — every suppression is recorded and kept VISIBLE (Law 1: recall beats report-tidiness).

---

## Known-issue reference (7)

| KI | Text (paraphrase) | Type |
|----|-------------------|------|
| KI-1 | Owner-driven attacks OOS (owner picks which tokens to list via dispatchers) | owner-driven |
| KI-2 | Dodgy/malicious tokens OOS (owner controls dispatcher registration + token selection) | dodgy-token |
| KI-3 | FoT handling uses balance-before/after (documented design) | FoT pattern |
| KI-4 | Owner-trust for registering dispatchers, **setting prices**, pausing, emergency withdraw | owner-trust |
| KI-5 | Pauser-trust (designated pauser can pause/unpause) | pauser-trust |
| KI-6 | Price growth via basis points may compound to very large values (documented design) | price-growth |
| KI-7 | Previous-audit findings (reports/yield-claim-nft-02/) fixed in stories 24-28 | prior-audit |

---

## 1. KNOWN-ISSUE FILTERING (per candidate)

### CANDIDATE-1 — whole-balance ETH sweep + open `receive()` — **NO KI MATCH → passes**
- **Checked against KI-1/KI-2 (owner-driven / dodgy tokens):** NOT a match. The trigger is *third-party ETH* arriving at an open `receive()`, then swept by the next authorized `pool()`. There is no owner action and no token-selection decision in the root cause; the owner cannot be the adversary here (the donor subsidizes their own victim's buy). This is a value-misattribution/donation-accounting **footgun**, not an owner-driven attack.
- **Checked against KI-3 (FoT balance-before/after):** NOT a match. KI-3 blesses the *token* accounting pattern for fee-on-transfer ERC-20s. CANDIDATE-1 is about **ETH** balance handling folding stray/donated ETH into the next promotion buy — a different asset, a different mechanism, and not the FoT convention KI-3 sanctions. Superficial "reads whole balance" resemblance only; the FoT KI does not cover this.
- **Verdict:** **NOT suppressed.** Non-obvious Law-3 footgun (a competent, non-malicious owner would be surprised that any third party's stray ETH folds into the next pool at that keeper's floors, and that a pooler can front-run `rescueETH`). First ETH-handling dispatcher, so no prior ledger entry. → **NEW.**

### CANDIDATE-2 — `pool()` MEV/sandwich — **NO KI MATCH → passes to ledger reconciliation (§2)**
- No KI covers MEV/keeper-floor slippage. KI-4 owner-trust does not apply (the residual is *keeper laziness passing 0 floors*, an operational hazard, not a blessed owner action). → reconciled to L-06 below.

### CANDIDATE-3 — unwired mint-debt hook fail-open — **NO KI MATCH → passes to ledger reconciliation (§2)**
- Not covered by any KI. It is NOT the DEDUP-001 external-backing suppression (that is the over-backing/donation-split facet; this is a missing on-chain guard). → reconciled to L-09 below.

### QA cluster — known-issue pass

| QA | Item | KI check | Verdict |
|----|------|----------|---------|
| QA-a | `block.timestamp` deadlines (no expiry) | none | NEW QA (info); also MEV facet of CANDIDATE-2 |
| QA-b | Unchecked router return on ETH swap (Leg B) | none | NEW QA/Low |
| QA-c | Unchecked Balancer `settle` return in `unlockCallback` | none | NEW QA/info |
| QA-d | `nonReentrant` not first modifier on `pool()` | none | reconciles to open **Q-05** (§2) |
| QA-e | `addLiquidity` dust ignored (by-design, NatSpec-documented) | none | NEW QA (documented dust) |
| QA-f | `setMaxTin` uncapped (sole Leg-A PSM guard) | **KI-4 (owner-trust, setting prices)** | **SUPPRESSED-KI-4 (visible)** — see below |

#### QA-f — setMaxTin uncapped → SUPPRESSED under KI-4 (Law-3 obvious), kept VISIBLE
- **Does it fall under owner-trust KI (Law-3 obvious)? YES.** `setMaxTin` sets the maximum PSM `tin` (fee) — a **price/fee-setting** owner action, squarely inside KI-4 ("owner trust assumptions for … setting prices"). Applying the Law-3 test *"would a competent, non-malicious owner be surprised by this consequence?"*: **No.** The function name and NatSpec make the raised-fee-ceiling consequence obvious, and PSM `sellGem` is fixed-rate, so exposure is bounded to the *accepted* tin fee — not an open-ended drain. Obvious consequence ⇒ trusted ⇒ suppress.
- **Contrast with CANDIDATE-1 (deliberately NOT over-suppressed):** CANDIDATE-1's ETH-folding consequence is *non-obvious* (surprise ⇒ footgun ⇒ keep). QA-f's fee-ceiling consequence is *obvious* (no surprise ⇒ trusted ⇒ suppress). The line between them is the Law-3 surprise test, applied honestly in both directions.
- **Kept VISIBLE (Law 1):** suppression recorded here + the deduplicator's `manual-review.json` park is carried forward. The park's action item stands: **triage should explicitly confirm the deployed `maxTin` default (1e16 = 1%) stays tight** — the suppression is of the *no-hard-cap-in-code* finding, not a blessing of an arbitrarily high runtime value.

---

## 2. LEDGER RECONCILIATION

Reconciliation follows this ledger's established **instance-reuse convention** (see L-02 / L-05 / L-06 `instanceNote`s): the *same root-cause class* recurring on a *new dispatcher* reuses the open label's fingerprint as an instance — no duplicate label minted, `lastSeenRun` bumped, carryover stub written. The `entryPoint` discriminator is `null` for all of these (contract-scan findings), so no cross-entry-point collision applies.

### CANDIDATE-2 → **carryover-of-L-06** (open, Low)
- **L-06** (`342075df…`, open, Low): "`pool()`/`unlockCallback` single-sided LP-add relies solely on off-chain keeper min floors with no on-chain price reference (MEV sandwich)." First seen run-10 on BalancerPoolerV2; already carries a run-13 Uniboost instance and run-14/run-16 re-observations.
- **Same root-cause class? YES.** CANDIDATE-2 is the identical authorized-pooler + keeper-quoted-floor + post-call `minLP` control model, now extended to the **new ETH swap leg** (`swapExactETHForTokens` floors + `amountAMin=amountBMin=0` addLiquidity + `block.timestamp` deadline). Precedent settled it at Low; the ETH leg adds *more legs of the same class*, not a new class. PSM `sellGem` is fixed-rate (no market slippage).
- **Disposition:** **RECONCILES-TO-L-06** — reuse L-06 fingerprint as a PromotionUniV2_Eth instance, **no new label**, bump `lastSeenRun` → yield-claim-nft-17, write carryover stub. Do NOT re-escalate settled precedent (no new vector found).
- **Disclosure (re-file rule):** this is the same MEV-sandwich class as L-06, now on a **new contract (`PromotionUniV2_Eth`) and a new asset leg (ETH)** — the fingerprint reuse is a deliberate instance link, not a silent collision. Non-blocking defense-in-depth suggestion carried from dedup: force `minLP > 0` and/or non-zero `amountAMin/BMin` so a zero-floor keeper call cannot silently ship.

### CANDIDATE-3 → **carryover-of-L-09** (open, Low)
- **L-09** (`563df2e6…`, open, Low): "no `hookTypeId` guard: unwired/wrong dispatch hook silently accrues zero phUSD debt (M-04 fail-open class reborn)." First seen run-13 on Uniboost.
- **Same root-cause class? YES.** PromotionUniV2_Eth reuses the base `ATokenDispatcherV2._dispatch → hook.onDispatch(GROSS)` path with **no `hookTypeId`/`keccak256` guard** (source-confirmed: the file declares no such literal at all); ctor defaults `hook` to the no-op `DefaultDispatchHook`. Forget `setHook` ⇒ NFTs mint while zero phUSD debt accrues. This is the **fourth dispatcher** to carry the fail-open class (M-04 NudgeRatchet = fixed w/ guard; Q-08 BalancerPoolerV2 = wont-fix; L-09 Uniboost = open; now PromotionUniV2_Eth).
- **Disposition:** **RECONCILES-TO-L-09** — reuse L-09 fingerprint as a PromotionUniV2_Eth instance, **no new label**, bump `lastSeenRun` → yield-claim-nft-17, write carryover stub. Surface-for-triage; keep OPEN.
- **Guardrails (explicit):**
  - **Do NOT auto-collapse into Q-08** (`96c60b72…`, wont-fix, BalancerPoolerV2). Q-08's owner acceptance covers only the LIVE BalancerPoolerV2 — a distinct contract/fingerprint — not this newly-in-scope dispatcher (consistent with how L-09 itself is kept distinct from Q-08).
  - **Do NOT re-file as a new label** (consistent with run-13 L-09 memory note and prior L-09 triage).

### QA-d → **carryover-of-Q-05** (open, QA) — proposed instance
- **Q-05** (`13fe448d…`, open, QA): "`nonReentrant` is not the first modifier on `pool()` (defense-in-depth)," BalancerPoolerV2. QA-d is byte-identical class on `PromotionUniV2_Eth.pool` (order: `onlyAuthorizedPooler`, `whenNotPaused`, `nonReentrant`; preceding modifiers only read state).
- **Disposition:** **RECONCILES-TO-Q-05** as a PromotionUniV2_Eth instance — reuse Q-05 fingerprint, **no new label**, bump `lastSeenRun` → yield-claim-nft-17. This is a de-dup-against-ledger, not a suppression (item stays visible in the QA bundle). Flagged as a sanitizer proposal for finding-manager to confirm (task pre-blessed only C-1/2/3; this is the same instance-reuse convention applied to a QA item to avoid a duplicate label).

### SUPPRESSED-DEDUP-001 → **suppressed (DEDUP-001), kept VISIBLE**
- **DEDUP-001** (`070fdf42…`, status `suppressed`): the phUSD external-backing class (owner-trust KI-1/KI-4 + out-of-scope external backing model). This run's facet — `_dispatch` donation-split + base `hook.onDispatch(GROSS)` + `UniboostMintDebtHook` (ratio ≤ 50) — is direction **over-backing, not under-mint** (relocates *where* backing is pooled; no unbacked phUSD; NFTs have no redemption leg). Same convention as Uniboost/BalancerPoolerV2, no new deviation.
- **Disposition:** **SUPPRESSED-DEDUP-001** — reuse DEDUP-001 fingerprint, status stays `suppressed`, bump `lastSeenRun` → yield-claim-nft-17. **No carryover stub** (hard-suppressed). Re-emit ONLY if a *new unbacked-mint path* appears (none here). Kept visible in this report and routed to finding-manager for ledger bookkeeping so the suppression boundary stays auditable.
- **Q-11 separation (memory note honored):** Q-11 (`205afcf0…`, the narrower in-contract `require(bal>=amount)` tripwire on NudgeRatchetDelayRelease) must stay SEPARATE from DEDUP-001. No Q-11-class in-contract-tripwire finding appears in this run's PromotionUniV2_Eth candidate set, so the separation is not at risk this run — the DEDUP-001 umbrella here covers ONLY the external-backing/over-backing facet, nothing narrower.

### M-04 literal-drift watch — **UNAFFECTED (confirmed)**
- M-04 (`c91bef81…`, fixed) carries an ACTIVE literal-drift `regressionWatch` over `watchedLiterals` = { NudgeRatchet.sol:31, NudgeRatchetMintDebtHook.sol:31, NudgeRatchetDelayRelease.sol:52 }.
- **Source-confirmed:** `PromotionUniV2_Eth.sol` declares **NO** `keccak256`/`hookTypeId`/`HOOK_TYPE_ID`/`EXPECTED_HOOK` literal. There is therefore **nothing to add** to the watched-literal set. The watch is **UNAFFECTED** this run (no new literal, no drift trip, no regression).
- Consistency check: the *absence* of any guard literal is precisely what makes CANDIDATE-3 the **L-09 fail-open class** (guard absent) rather than the **M-04 literal-drift class** (guard present, literals could diverge). CANDIDATE-3 correctly routes to L-09, not M-04.

---

## 3. FINAL SANITIZED / RECONCILED DISPOSITION

| Item | Final disposition | Reason | Fresh label? |
|------|-------------------|--------|--------------|
| **CANDIDATE-1** | **NEW** (passes) | Non-obvious Law-3 footgun; no KI match (not owner-driven KI-1/2, not FoT KI-3); first ETH-handling dispatcher, no prior ledger entry | **YES — assign at classification** |
| **CANDIDATE-2** | **carryover-of-L-06** (open, Low) | Same off-chain-floor MEV-sandwich class extended to the ETH leg; precedent-settled Low | No — reuse L-06, bump lastSeenRun→17, carryover stub |
| **CANDIDATE-3** | **carryover-of-L-09** (open, Low) | 4th dispatcher with the no-`hookTypeId`-guard fail-open class; do NOT collapse into Q-08 | No — reuse L-09, bump lastSeenRun→17, carryover stub |
| **SUPPRESSED-DEDUP-001** | **suppressed-DEDUP (visible)** | External-backing/over-backing class, project-suppressed; NFTs no redemption leg | No — reuse DEDUP-001, bump lastSeenRun→17, **no stub** |
| **QA-a** | **NEW QA** (info) | `block.timestamp` deadline; no KI; also MEV facet of L-06 | YES (QA bundle) |
| **QA-b** | **NEW QA/Low** | Unchecked router return on ETH swap; no KI; bounded by floors | YES (QA bundle) |
| **QA-c** | **NEW QA** (info) | Unchecked Balancer `settle` return; no KI; `unlock` reverts on unsettled debt | YES (QA bundle) |
| **QA-d** | **carryover-of-Q-05** (open, QA) | Same `nonReentrant`-not-first modifier-order class as open Q-05 | No — reuse Q-05, bump lastSeenRun→17 (proposal for finding-manager) |
| **QA-e** | **NEW QA** (low-value) | `addLiquidity` dust ignored — by-design, NatSpec-documented, recoverable | YES (QA bundle) — retained to confirm documented dust |
| **QA-f** | **SUPPRESSED-KI-4 (visible)** | `setMaxTin` = price/fee-setting owner action; Law-3 **obvious** consequence, PSM fixed-rate bounds exposure | No — suppressed; carry `manual-review.json` park (confirm 1e16 default stays tight) |

### Suppression audit trail (Law 1 — nothing silently dropped)
- **QA-f** → suppressed under **KI-4** (owner-trust / setting-prices, Law-3 obvious). Confidence: high on the KI match; **visible** with an explicit human confirmation ask on the deployed `maxTin` default.
- **SUPPRESSED-DEDUP-001** → suppressed under the established **DEDUP-001** external-backing umbrella (KI-1/KI-4 + OOS external backing). Confidence: high. **Visible**; re-emit trigger = any new unbacked-mint path.

### Counts (sanitizationReport)
- inputActiveCandidates: 3 (C-1/2/3) + 6 QA (a–f) + 1 suppressed pointer = 10 items
- **passed as NEW → classifier:** 1 (CANDIDATE-1)
- **carryover to open ledger labels:** 3 (CANDIDATE-2→L-06, CANDIDATE-3→L-09, QA-d→Q-05)
- **suppressed (kept visible):** 2 (SUPPRESSED-DEDUP-001, QA-f→KI-4)
- **new QA (fresh labels → QA bundle):** 4 (QA-a, QA-b, QA-c, QA-e)
- **flaggedForReview:** 1 (QA-f `maxTin` default confirmation, carried in manual-review.json)
- regressions: 0 · fix-pending live: 0

### Ledger bookkeeping handed to finding-manager
- Bump `lastSeenRun` → yield-claim-nft-17 on: **L-06, L-09, Q-05, DEDUP-001**.
- Carryover stubs (open, not re-reported): **L-06, L-09, Q-05**. No stub for DEDUP-001 (hard-suppressed).
- Only **CANDIDATE-1** proceeds to severity-classifier for a fresh label; QA-a/b/c/e proceed to the QA bundle for fresh Q-labels.
- M-04 literal-drift `watchedLiterals` set: **unchanged** (PromotionUniV2_Eth adds no literal).
