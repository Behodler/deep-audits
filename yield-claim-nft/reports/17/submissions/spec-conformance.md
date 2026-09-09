# Spec-Conformance Report (Law 2 — Story Faithfulness) — yield-claim-nft run-17

- **Project:** yield-claim-nft
- **Submodule HEAD:** `8dd8963`
- **Run:** yield-claim-nft-17
- **Date:** 2026-07-18
- **Scope this run:** `src/dispatchers/PromotionUniV2_Eth.sol` (story-044, new ETH-leg dispatcher)
- **Stories checked:** `story-044`
- **Overall verdict:** **HIGHLY FAITHFUL.** Every acceptance criterion of story-044 — USDC prime, 50/50 `pool()` split, Leg A (USDC→USDS→sUSDS→phUSD), Leg B (USDC→ETH→promotion), addLiquidity into the phUSD/promotion pair, the Uniboost donation/pooler-auth/setPool machinery, the BalancerPoolerV2 unlock/swap/settle/sendTo callback order, and `rescueETH`/`receive()` — matches the story verbatim. One under-specification nuance is recorded below (F-01-044, Low). No Law-1 story-unsafe escalation.

This report is **separate from the QA/gas bundle by design**: faithfulness is a Law-2 concern (does the code do what its story says?), not gas/style noise. Where a faithfulness record also has a security/operational twin, that twin is carried at honest severity in the QA report and cross-referenced here.

---

## F-01-044 — `_legB` sweeps the entire contract ETH balance, not the leg's own swap output

- **Type:** faithfulness (spec-conformance nuance) · **Law impacted:** 2 (with a Law-3 footgun angle)
- **Severity:** Low · **Security escalation:** none
- **Location:** `src/dispatchers/PromotionUniV2_Eth.sol#L332-L346` (`_legB`, the whole-balance read is at L342)
- **Cross-reference:** **L-13** (QA report) — the security/operational twin of this faithfulness record
- **Fingerprint:** `3e638eb9…`

### Story intent (source of truth)

Story-044 specifies Leg B at the per-leg granularity of "the ETH produced by *this leg's* USDC":

- `[story-044]` commit `8952534` body:
  > "Leg B USDC->ETH->promotion (UniV2) — then addLiquidity into the phUSD/promotion pair."
- Contract NatSpec (L29-30):
  > "Leg B → promotion: USDC →(UniV2 `swapExactTokensForETH`)→ native ETH →(UniV2 `swapExactETHForTokens`)→ promotion token."
- `receive()` NatSpec (L399):
  > "Accepts native ETH from the `swapExactTokensForETH` unwrap in Leg B."

The fork-test acceptance criteria (`[story-044]` commit `8dd8963`, `test/PromotionUniV2_Eth.t.sol`) additionally assert the dispatcher holds **no** stranded ETH after a `pool()` — `assert(address(dispatcher).balance == 0)` in `test_pool_endToEnd_…` ("no ETH stranded") — and `rescueETH` NatSpec (L392) documents recovery of "native ETH left by a failed/partial Leg B."

### Actual code behavior

After `swapExactTokensForETH(usdcAmount, …)` unwraps the leg's USDC into ETH, `_legB` does **not** swap the `amounts[1]` output the router just returned. Instead it reads

```
ethBal = address(this).balance;   // L342
```

and swaps the **entire contract ETH balance** into promotion via `swapExactETHForTokens{value: ethBal}`.

### Deviation

The story's per-leg reading is satisfied only in the normal single-call case where the contract holds no other ETH. Because `receive()` (L400) is open and unguarded, any ETH already on the contract — a third-party donation, a coinbase transfer, or ETH stranded by a prior partial/failed Leg B not yet `rescueETH`'d — is folded into the *next* pooler's promotion buy at that caller's `minPromoOut`/`minLP` floors. The whole-balance semantics ("sweep whatever ETH is here") versus the story's leg-output semantics ("swap the ETH this leg produced") is **under-specified**: both readings are consistent with the prose, and the code implements the former.

### Disposition

**Intended-but-under-specified, Low.** The sweep-to-zero is a *deliberate, tested* choice, not an accidental bug — the acceptance test asserts a zero post-`pool()` balance and `rescueETH` exists precisely to recover ETH left by a failed/partial leg. It is benign under normal single-call operation and footgun-surprising only under external-ETH conditions. The security/operational angle (stray ETH mis-attributed to the next pooler; `rescueETH` is front-runnable) is carried at **Low as L-13** in the QA report; this record captures only the Law-2 verdict: **highly faithful, with a whole-balance-vs-leg-output under-specification.**

**Recommendation (documentation, not a code change):** state explicitly in the NatSpec that the Leg B sweep is whole-balance-by-design so a future maintainer does not "fix" it into a leak, and `rescueETH` any stray ETH before authorizing a `pool()` if it must not enter LP.

---

## F-02-044 — Unwired mint-debt hook (fail-open) — reconciles to open ledger **L-09** (no separate write-up)

The faithfulness scan surfaced a second nuance: `PromotionUniV2_Eth` reuses the Uniboost `_dispatch`→`hook.onDispatch(minter, GROSS amount)` path with **no `hookTypeId` guard** and a no-op `DefaultDispatchHook` default, so unless the owner calls `setHook(mintDebtHook)` the minter mints NFTs while accruing zero phUSD mint-debt — silently violating NatSpec L252-254.

This is **not a new faithfulness finding.** The hook *call* itself is faithful (the gross amount is passed, verified by `test_dispatch_invokesHookWithGrossAmount`); the gap is the *fail-open* wiring, which is the exact M-04 fail-open class **already tracked as open ledger finding L-09**. `PromotionUniV2_Eth` is the fourth dispatcher to carry this class. Per established triage (L-09: "surface-for-triage, not auto-Q08"), it **reconciles to L-09** and is not re-filed. See the L-09 carryover stub and the QA report.

---

## Law-1 override check — clearance

**No story-unsafe escalation this run.** Story-044's design (authorized-pooler-only `pool()`, caller-supplied slippage floors `minPhusdOut`/`minEthOut`/`minPromoOut`/`minLP` plus a `maxTin` ceiling, protocol-owned LP, gross-amount mint-debt via hook) is not faithful-but-exploitable. Tier-3 invariant **INV-4** confirmed the Leg B ETH sweep is bounded and non-theft — swept value routes only into protocol-owned LP and can never reach a third party — so there is no story instruction whose own intended behavior introduces an exploit. Law 1 clears.

---

## Carryover — prior open faithfulness finding

- **F-01-043** (open, informational) — *"story-043 intentionally decouples phUSD-debt-realisation (at dispatch) from USDC-release (later), opening an admin-rate-controlled under-funded-sink window."*
  - **Contract/function:** `src/dispatchers/NudgeRatchetDelayRelease.sol` (`_dispatch` / `release`)
  - **First seen:** yield-claim-nft-15 · **Still open as of:** yield-claim-nft-17
  - **Original report:** [reports/yield-claim-nft/15/submissions/spec-conformance.md](../../15/submissions/spec-conformance.md)
  - **Fingerprint:** `6753c76b…`

  Carried forward here so the prior-run faithfulness record is not lost between runs. Not re-analyzed this run (story-043 contract out of this run's story-044 scope). See the original report for the full write-up; triage via `/ledger yield-claim-nft`.
