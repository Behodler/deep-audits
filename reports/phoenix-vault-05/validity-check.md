# Validity Check — phoenix-vault-05

Screened the submission-effective set (M-01, M-02 [with folded-in M-03], L-01, L-02, C-01) against the C4 known-invalid patterns. Source verified against `lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (`_skimSurplusBatch` L462-L488, `_withdrawInternal` L302-L339). All root causes sit in this in-scope contract — no OOS parent/forked-contract dependency.

## Verdict summary

| Finding | Severity | Verdict | Pattern(s) screened |
|---|---|---|---|
| M-01 | Medium | VALID | reckless-admin-mistake (does NOT apply) |
| M-02 | Medium | VALID | speculation-on-future-code (does NOT apply); sandwich/MEV scope OK |
| L-01 | QA/Low | VALID-WITH-CAVEAT | reckless-admin-mistake (framing-dependent) |
| L-02 | QA/Low | VALID | self-inflicted-trusted (correctly QA, not HM) |
| C-01 | QA/Centralization | VALID | centralization-only-as-HM (correctly filed as QA) |

No finding is INVALID. Two carry caveats that must be preserved in the final wording.

---

## M-01 — over-skim via duplicate `clients[]` — VALID (Medium)

This is the critical validity call. The screened pattern is **reckless admin mistake** (a C4 always-invalid category): the trigger is a trusted `onlyAuthorizedWithdrawer` passing a duplicate array.

The "reckless admin" exclusion does NOT apply here, for three independent reasons, all of which I confirmed against the source:

1. **Harm lands on third parties, not the caller.** The over-skim sells shares backing OTHER clients' principal (`totalShares` ceilinged only at `availableShares`, L481 — the strategy's whole balance, which backs everyone's `principal + surplus`). The PoC shows client B left 20,000 below a 100,000 principal when the operator skims `[A,A,B,B]`. C4's reckless-admin exclusion covers an admin harming the protocol/themselves through their own carelessness; it does not cover a contract defect that converts a benign-looking operator input into a silent loss for unrelated depositors. The trusted role is the trigger, not the victim.

2. **The defect is contract-side and the input is plausibly accidental — not malicious.** A malicious admin already has `emergencyWithdraw`/owner powers (see C-01), so framing this as "admin could grief" would be redundant and invalid. The point is the opposite: a non-malicious operator running an off-chain keeper script that emits a duplicate (re-run appends, paginated list overlap, same client under two labels) causes loss with no on-chain guard and no revert to signal it. The contract is missing a dedup / aggregate-surplus ceiling that should structurally prevent selling into principal regardless of array contents. Root cause is the absent invariant at L476/L481, not operator recklessness.

3. **It is a genuine, demonstrated present-state loss.** Dual-confirmed: Halmos exact-2x counterexample for `[A,A]`/`[A,A,B,B]` with `[A,B]` proven safe; Foundry+Medusa invariant break; deterministic PoC with a concrete arithmetic shortfall (held backing 240,000 → 160,000 vs 200,000 principal; B recovers 80,000 of 100,000). Loss is shown as an arithmetic deficit, not merely a revert.

**Severity is correctly capped at Medium, not overstated to High.** The trusted-role trigger and absence of an external attacker are a likelihood discount that keeps it below the C4 High bar (no unprivileged direct theft), which the report states explicitly. This is the right call — submitting it as High would be the overstatement risk, and the report avoids it.

Caveat to preserve: the report's own "HM-vs-QA boundary flagged" note is honest and should stay. A judge could argue QA on the grounds that the trigger requires an operator error. The rebuttal (third-party harm + silent contract-side loss + coded PoC) is sound and is exactly what distinguishes this from the invalid bucket. The Medium label is defensible; keep the third-party-harm framing front and center in the submission (it already is, L53-L57).

Not flagged for any other pattern: not a token-behavior issue, not approve-race, not user-phishing, not OOS, not speculation, not a bare tool finding.

---

## M-02 — NAV-anchored minOut execution-price-blind (+ folded-in M-03) — VALID (Medium)

Two patterns screened: **speculation on future code** and whether an MEV-sandwich finding is in scope.

**Speculation on future code — does NOT apply.** The specific scrutiny item asked me to confirm the forward-looking "deployment over a manipulable vault → High" note is framed as context, not as the basis of the Medium. Confirmed: L52-L53 explicitly label it "a deployment constraint on future routes, not a claim about the present sUSDe route," and the severity rationale (L48-L51) rests the Medium entirely on the present sUSDe deployment. The CURRENT Medium does NOT depend on the future-vault escalation — it would stand even if that paragraph were deleted. So this is not "speculation on future code without a demonstrated current root cause"; the current root cause is demonstrated.

**The current Medium rests on a demonstrated present-state leak.** Confirmed against source: `minOut` is derived from `vault.convertToAssets/convertToShares` (sUSDe NAV) at L321-L322 and L482-L483, never observes the Curve pool, and `CurveAMMAdapter` forwards it verbatim. PoC 1 shows a non-tautological leak: swap clears the NAV floor (995,000 ≥ floor) yet delivers below fair value (995,000 < 1,000,000), leak ≈ bps × tradeSize ≈ 5,000. The mock adapter genuinely enforces `amountOut >= minAmountOut`, so the contract's own floor logic is the component under test — the mock does not fake the vulnerability.

**MEV-sandwich scope.** A sandwich/value-leak finding with an external-MEV requirement and stated assumptions (public mempool, profitably-skewable pool) is a standard C4 Medium, not an excluded category. The report correctly dismisses the flash-loan/atomic-NAV-manipulation framing (sUSDe `totalAssets` is not same-tx movable, L49), which is what keeps it honestly at Medium rather than an overstated High. Good discipline.

**Folded-in M-03 (requested-not-received amplification) — VALID as a sub-impact, correctly not standalone.** The report frames it as "a worst-case impact concentration of M-02, not an independent bug" (L71) and states it "has no standalone loss primitive." This is the right framing and avoids the trap of double-counting a documented design decision (decrement-by-requested, source L333-L336) as its own bug. The validator counterfactual (fair deposits → even slippage distribution → no concentration) substantiates the dependency. Because it is presented as an amplifier of the demonstrated M-02 leak and not as a free-standing finding, there is no "speculation" or "design-choice-as-bug" invalidity. VALID as folded.

Not flagged for token-behavior, approve-race, user-mistake, admin-mistake, or OOS.

---

## L-01 — slippageToleranceBps default-0 + missing cap — VALID-WITH-CAVEAT (QA/Low)

Pattern screened: **reckless admin mistake**. Part (b) ("owner sets bps = MAX_BPS ⇒ minOut == 0") is, on its face, a reckless-admin narrative — which would be invalid IF that were the stated impact.

The report pre-empts this correctly: L28 of findings-classified states "'owner sets 100%' is an excluded reckless-admin narrative and NOT the stated impact." The stated impact is pure **missing input validation** (no sane upper cap on the setter; no initializer so default-0 makes swaps revert until configured). Missing-validation framed as QA/Low is a legitimate quality finding, not an HM claim, so it does not trip the reckless-admin exclusion.

Caveat: this VALID verdict is conditional on the submission keeping the missing-validation framing and NOT asserting any loss/impact that depends on the owner deliberately setting a pathological tolerance. If the QA bundle text drifts into "a malicious/careless owner sets 100% slippage and funds are lost," that portion becomes invalid. As written/classified it is fine. Confirm the qa-bundler preserves the framing.

---

## L-02 — whole-batch revert on single zero-address entry — VALID (QA/Low)

Confirmed against source: `require(client != address(0))` at L470 sits inside the loop and reverts the entire batch, inconsistent with the graceful `continue` used for `principal==0` (L472) and `surplus==0` (L475). Plus an unbounded caller-supplied array.

Screened patterns: this is self-inflicted by the trusted caller with no third-party harm and no asset loss — correctly classified QA/Low, not pushed to HM. That is the right call; presenting a trusted-caller-only DoS/revert-grief as Medium would be the overstatement risk, which the report avoids. No invalid pattern applies (it is a robustness/consistency QA item, exactly the kind C4 expects bundled in QA). VALID as QA/Low.

---

## C-01 — centralization / owner-power bundle — VALID (QA/Centralization)

Pattern screened: **centralization-only issue framed as HM** (a C4 invalidity when overstated).

Confirmed correctly filed as QA/Centralization, NOT overstated to HM. The bundle (`setRoute`, `setSlippageTolerance`, `depositAsOwner`, `withdrawAsOwner`, `emergencyWithdraw`, skim recipient, two-phase `totalWithdrawal`) is designed/authorized behavior. Critically, the report notes the withdrawer redirects yield only — never principal (INV-2 verified) — and that the timelock is sound and not bypassable. There is no privilege-escalation claim (the one route by which an admin finding could legitimately become valid HM), and the report does not make one. Filing it as a Centralization/QA bundle is exactly the correct treatment per C4. Not overstated. VALID.

---

## Cross-cutting checks

- **Out-of-scope root cause:** All findings root-cause inside `ERC4626MarketYieldStrategy.sol` (in scope). M-02 touches `CurveAMMAdapter` but only as a verbatim forwarder; the defect is the strategy's NAV-anchored floor, not adapter logic. No finding's root cause is in an OOS parent/forked contract.
- **Token-behavior exclusions (non-standard ERC-20, fee-on-transfer, USDT quirk, CryptoPunks):** none of the findings rely on weird-token behavior. The sUSDe NAV mechanics M-02 leans on are intrinsic to the in-scope ERC4626 integration, not a non-standard-token assumption.
- **Approve race / safeApprove front-running:** not present. The `safeIncreaseAllowance` calls (L325, L484) are not the subject of any finding.
- **Bare automated-tool findings:** none. Each Medium carries a coded PoC plus (M-01) Halmos/Medusa corroboration; the Lows are reasoned QA, not raw scanner output.

## Bottom line

No finding should be removed as C4-invalid. M-01 clears the reckless-admin bar (third-party harm, accidental trigger, contract-side fix, demonstrated loss) and is a genuine Medium. M-02's Medium rests on a demonstrated present-state leak with the future-vault escalation correctly quarantined as context. L-01 is valid only while it stays framed as missing-validation — preserve that framing through the QA bundle. L-02 and C-01 are correctly de-rated to QA.
