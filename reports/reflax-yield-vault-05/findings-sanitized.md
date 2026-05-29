# Sanitized Findings — reflax-yield-vault (reflax-yield-vault)

Stage: known-issue / design-decision / system-assumption reconciliation + C4 known-invalid filtering. Input: `findings-deduped.md` (DD-01..DD-06). Ledger: NONE (cold scan) — every survivor is `origin: new`.

## Authoritative reference set (registered-projects.json → reflax-yield-vault)

`knownIssuesCount: 0`. Reconciliation runs against:

**Design decisions (DD):**
- DD#1 — Market-based ERC4626 interaction via AMM swap rather than direct vault deposit/withdraw.
- DD#2 — Principal decremented by REQUESTED amount on withdraw, not RECEIVED (any shortfall accrues to protocol).
- DD#3 — Bidirectional route invariant (both A->B and B->A required).
- DD#4 — Slippage tolerance in bps, applied to expected output at swap time.
- DD#5 — Two-phase emergency withdrawal (24h wait / 48h execute) inherited from AYieldStrategy.

**System assumptions (SA):**
- SA#1 — Deployment scripts correctly populate routes from AMMRoutes.json.
- SA#2 — Curve Router NG at 0x16C6521Dff6baB339122a0FE25a9116693265353 trusted.
- SA#3 — ERC4626 vault share price monotonically non-decreasing (or losses acceptable to clients).
- SA#4 — Underlying tokens standard ERC20, no transfer hooks / fee-on-transfer.
- SA#5 — Vault owner acts in best interest of protocol and clients.

**C4 known-invalid / OOS enforced:** reckless admin mistakes; weird/fee-on-transfer ERC20; user input mistakes/phishing; root cause in OOS parent/forked contracts.

---

## Per-finding disposition

### DD-01 — over-skim under duplicate `clients[]` → KEEP
No DD/SA covers it. vs DD#2: opposite-sign, different-function defect (DD#2 accepts protocol *gaining* the withdraw gap; DD-01 produces shortfall *against* clients via per-occurrence accumulation at :476 ceilinged only by total held shares :481). vs SA#5/"reckless admin": rejected as disqualifier — accidental duplicate is a plausible operational slip, harm lands on *other* clients, fix is contract-side. Trusted gate is a likelihood/HM-vs-QA factor, not a validity bar. Dual formal confirmation preserved.

### DD-03 — socialized slippage / last-withdrawer insolvency → KEEP (pivotal call)
DD#2 covers the MECHANISM (debit by requested) but its stated consequence is "accrues to protocol" / "protocol-owned yield" (:333-334) — protocol *benefits*. DD-03 demonstrates the opposite: shares sold at worse pool price but principal debited at fair-NAV requested amount → shared-pool backing erodes faster than ledger → last withdrawer hits the `sharesToSell > availableShares` cap (:316-318) and recovers less than fully-debited principal. The harm is socialised onto *other clients*, the opposite beneficiary from what DD#2 asserts. vs SA#3 ("losses acceptable to clients"): scopes exogenous vault-NAV losses on a client's own position, not cross-client conversion of one client's slippage into another's principal shortfall. Not covered → KEEP. Kept separate from DD-02 (distinct mechanism + fix). Closest call — surface to human reviewer.

### DD-02 — NAV-anchored minOut execution-price-blind → KEEP
DD#4 documents that a bps tolerance exists/applied to "expected output"; it does NOT assert the floor is execution-price aware. Defect: "expected output" computed from vault NAV (`convertToAssets`), blind to a skewed Curve pool, sandwich extracts full bps. SA#2 (router correctness) ≠ MEV immunity. No-deadline sub-point uncovered, stays as amplifier. PM-01 flash-loan framing already dismissed (non-atomic sUSDe NAV).

### DD-04 — slippage default-0 / setter permits MAX_BPS → SPLIT: KEEP missing-validation only
Default `0` (:40, no initializer): KEEP — uninitialized-state contract defect, no admin chose it. Settable to MAX_BPS: owner *actually* setting 100% = reckless-admin/SA#5 (invalid, NOTED not the finding); the in-scope defect is `setSlippageTolerance` (:190-195) checking only `_bps <= MAX_BPS` with no sane upper cap. KEEP as config/validation defect (missing nonzero default + missing sane cap). Impact must NOT be stated as "owner maliciously sets 100%." Likely QA/Low.

### DD-05 — zero-addr batch revert + unbounded array → KEEP (QA/Low)
In-loop `require(client != address(0))` at :470 reverts whole batch (inconsistent with `continue` for `principal==0`/`surplus==0`). No DD/SA covers batch-revert robustness. SA#5 tempers severity only.

### DD-06 — centralization bundle → KEEP as QA/Centralization
Maps to SA#5 + DD#5; INV-2 (principal never redirected) verified. Substantially covered by SA#5/DD#5 — correct C4 disposition is bundle as centralization note, not drop, not escalate on owner-power alone.

---

## Already-dropped at dedup — confirmed correct
- PM-04 swap return-value trust — invalid per SA#4 + C4 weird-token rule.
- S1–S5 reentrancy — OZ nonReentrant; SA#2 + SA#4 close residual.
- ERC4626 first-depositor/inflation — N/A (no self-minted shares).
- AYieldStrategy.sol:263 abi.encodePacked (Aderyn high) — root cause in OOS parent.
- Tool noise (Semgrep×64, Aderyn A4–A8, Slither S11/S12).

---

## Summary
- Input: 6 — Removed: 0 — Passed to severity-classifier: 6 (all `origin: new`).
- DD-04 narrative tightened to missing-validation; DD-06 confirmed QA/Centralization.

**Flagged for classifier/human attention:**
- DD-03 — KEEP rests on "accrues to protocol" not covering cross-client socialization / last-withdrawer insolvency.
- DD-01 — HM-vs-QA boundary; `onlyAuthorizedWithdrawer` gate is likelihood-only.
- DD-04 — state impact as missing validation, never "owner maliciously sets 100%."
