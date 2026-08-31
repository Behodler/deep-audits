# Story-Faithfulness Scan — PromotionUniV2_Eth.sol (story-044)

- **Project:** yield-claim-nft
- **Scan type:** story-faithfulness (Law 2, Law 1 override)
- **Scanned:** 2026-07-18
- **Scope:** `src/dispatchers/PromotionUniV2_Eth.sol` (401 LOC, story-044) — single new dispatcher
- **Mode:** full (new contract, no prior ledger entry for this contract)
- **Prior faithfulness carryover on project:** F-01-043 (open)

## Story source of truth (in priority order)

1. `[story-044]` commit `8952534` body (dispatcher):
   > "Add PromotionUniV2_Eth (ATokenDispatcherV2): USDC prime, 50/50 pool() split — Leg A
   > USDC->USDS(PSM sellGem)->sUSDS(ERC4626)->phUSD (Balancer V3 swap), Leg B USDC->ETH->promotion
   > (UniV2) — then addLiquidity into the phUSD/promotion pair. Donation split + pooler-auth + setPool
   > machinery from Uniboost; unlock/swap/settle/sendTo + USDS->sUSDS wrap from BalancerPoolerV2.
   > Plus rescueETH + receive()."
2. `[story-044]` commit `8dd8963` body (fork tests) + `test/PromotionUniV2_Eth.t.sol` (acceptance criteria).
3. Contract NatSpec (lines 16-37, 250-254, 268-346, 392-400) — the design spec for this repo (no `docs/` dir exists; project `CLAUDE.md` is generic-only).

No standalone design doc exists for story-044; the commit bodies + NatSpec + fork test are the authoritative intent.

## Acceptance criteria → conformance

| # | Criterion (source) | Code | Verdict |
|---|---|---|---|
| 1 | USDC prime token | `primeToken()`→USDC (L147) | FAITHFUL |
| 2 | 50/50 `pool()` split | `halfA=amountIn/2; halfB=amountIn-halfA` (L286-287), odd wei→Leg B | FAITHFUL |
| 3 | Leg A: USDC→USDS(PSM sellGem)→sUSDS(ERC4626)→phUSD(Balancer V3) | `_legA` L313-326 exact | FAITHFUL |
| 4 | Leg B: USDC→ETH→promotion (UniV2) | `_legB` L332-346 — **whole-balance ETH sweep** | NUANCE → F-01-044 |
| 5 | addLiquidity into phUSD/promotion pair, LP accrues on dispatcher, pulled via rescueERC20 | L295-306 (full balances), `rescueERC20` L387 | FAITHFUL |
| 6 | Donation split + pooler-auth + setPool from Uniboost | `_dispatch` L255, `onlyAuthorizedPooler` L125, `_setPool` L179 | FAITHFUL |
| 7 | unlock/swap/settle/sendTo + USDS→sUSDS wrap from BalancerPoolerV2 | `unlockCallback` pay→swap→settle→sendTo L365-377 | FAITHFUL |
| 8 | rescueETH + receive() | L393-400 | FAITHFUL |
| 9 | Gross-amount mint-debt via hook (NatSpec L252-254) | base calls `hook.onDispatch(minter, GROSS amount)`; **no hookTypeId guard, no-op default** | FAIL-OPEN → F-02-044 (reconciles L-09) |

The implementation is **highly faithful** to story-044. Every leg, the split, the LP-ownership model, the donation/pooler/setPool machinery, and the Balancer callback order match the story verbatim. Two nuances below.

---

## Findings

### F-01-044 — `_legB` swaps the entire contract ETH balance, not the leg's swap output (spec-conformance nuance / Law-3 footgun)

- **type:** faithfulness · **securityEscalation:** false · **lawImpacted:** 2 (with Law-3 footgun triage)
- **severity:** Low
- **contract:** `src/dispatchers/PromotionUniV2_Eth.sol` · **function:** `_legB` · **line:** 342 (L332-346)
- **specText:** story-044 (commit `8952534`): "Leg B USDC->ETH->promotion (UniV2)"; NatSpec L29-30: "Leg B → promotion: USDC →(UniV2 `swapExactTokensForETH`)→ native ETH →(UniV2 `swapExactETHForTokens`)→ promotion token."; `receive()` NatSpec L399: "Accepts native ETH from the `swapExactTokensForETH` unwrap in Leg B."
- **specSource:** git commit `8952534` body + contract NatSpec
- **actualBehavior:** After `swapExactTokensForETH(usdcAmount, ...)` unwraps the leg's USDC into ETH, `_legB` reads `ethBal = address(this).balance` (L342) and swaps the **entire** contract ETH balance into promotion — not the `amounts[1]` output the swap just returned.
- **deviation:** The story's per-leg reading ("the ETH from *this leg's* USDC") is met only under the normal single-call case where the contract holds no other ETH. Because `receive()` (L400) is open and unguarded, any ETH pre-deposited (third-party donation, coinbase transfer, or ETH stranded by a prior partial/failed Leg B and not yet `rescueETH`'d) is folded into the *next* pooler's promotion buy at that caller's `minPromoOut`/`minLP` floors.
- **Law-3 footgun triage:** A competent, non-malicious owner/pooler would be *surprised* that a stranger's ETH donation is swept into their `pool()` at their off-chain-quoted floors → non-obvious consequence → footgun, in scope. Impact is **bounded and non-theft**: the extra ETH buys extra promotion that flows into protocol-owned LP (value routes to the pool, is not extracted); `minPromoOut` is a floor that extra input cannot breach, and imbalanced `addLiquidity` refunds the excess promotion side (dust retained). No revert/DoS path found. The design *intends* a sweep-to-zero — the test asserts `address(dispatcher).balance == 0` post-`pool()` (`test_pool_endToEnd_...` L388, "no ETH stranded") and `rescueETH` NatSpec (L392) documents "native ETH left by a failed/partial Leg B" — so the whole-balance read is a deliberate, tested choice, not an accidental bug. Kept **Low**: the value-accounting/griefing angle is the econ-scanner's to weigh (profile §12 risk #1); this note records only the faithfulness verdict: **intended-but-under-specified**, benign under normal operation, footgun-surprising under external-ETH conditions.
- **confidence:** high

### F-02-044 — Unwired mint-debt hook silently accrues zero phUSD debt (fail-open) — reconciles to ledger **L-09** (open)

- **type:** faithfulness (invariant-adjacent) · **securityEscalation:** false · **lawImpacted:** 2
- **severity:** Low (dedup to L-09; do **not** re-file as new H/M)
- **contract:** `src/dispatchers/PromotionUniV2_Eth.sol` · **path:** `_dispatch`→base `dispatch`→`hook.onDispatch(...)`
- **specText:** NatSpec L252-254: "The base then calls `hook.onDispatch(minter, amount)` with the GROSS amount, so mint-debt accrues on the full dispatched USDC regardless of the donation."
- **specSource:** contract NatSpec (story-044) + ledger L-09 title ("Uniboost has no hookTypeId guard: an unwired/wrong dispatch hook silently accrues zero phUSD debt (M-04 fail-open class reborn on a third dispatcher)")
- **actualBehavior:** `PromotionUniV2_Eth` reuses the Uniboost `_dispatch`→`hook.onDispatch` path with **no `hookTypeId` guard** (profile §8/§9; grep-confirmed no `keccak256`/`hookTypeId` in this file). `hook` defaults to a no-op `DefaultDispatchHook`. Unless the owner calls `setHook(mintDebtHook)`, `dispatch` retains/forwards USDC and the minter mints NFTs while accruing **zero** mint-debt — the story's stated intent (mint-debt accrues on gross USDC) is silently violated.
- **deviation & reconciliation:** The hook **call** itself is faithful — gross amount is passed (verified by `test_dispatch_invokesHookWithGrossAmount` L352-367). The gap is the *fail-open* (no requirement/verification that the real hook is wired), which is the **same class already tracked as L-09** (open) — this dispatcher is the **fourth** to carry it (Uniboost L-09; BalancerPoolerV2; NudgeRatchet* gate it, these do not). Per prior triage (L-09 "surface-for-triage, not auto-Q08"; run-13 L-09 note), this is surfaced, not escalated, and **reconciles to L-09** rather than minting a new finding. Owner-config footgun (forgetting `setHook`); non-obvious → in scope, but already ledgered.
- **confidence:** high

---

## Law-1 override check (story-unsafe?)

No **story-unsafe** escalation. Story-044's design — authorized-pooler-only `pool()`, caller-supplied slippage floors (`minPhusdOut/minEthOut/minPromoOut/minLP`) + `maxTin` ceiling, protocol-owned LP, gross-amount mint-debt via hook — is not inherently exploitable when the hook is wired and floors are tight. There is **no faithful-but-exploitable** story instruction: the whole-balance sweep (F-01-044) is bounded/non-theft, and the hook fail-open (F-02-044) is a config footgun, not a story-mandated exploit.

## Deliberate design choices confirmed FAITHFUL (not findings — Law 3)

- **`addLiquidity(..., 0, 0, ...)` amountMin = 0** (L300): explicitly documented (NatSpec L292-294) as intentional — "slippage is bounded by the leg floors and the final `minLP` check." The router refunds the excess side; residual dust retained. Conformant.
- **`block.timestamp` deadline** on all router calls (L300, L338, L344): standard same-block atomic execution inside an `onlyAuthorizedPooler` + `nonReentrant` frame; no cross-block MEV window. Not a story deviation.
- **PSM has no per-tx slippage floor, only `maxTin` ceiling** (L315): documented (NatSpec L314). Conformant. (`setMaxTin` has no upper bound — owner footgun tracked at profile §12 #5, code/econ lens, not faithfulness.)
- **Gross-amount mint-debt while `donationSplit%` is skimmed to `batchMinter`**: NatSpec-documented, same convention as Uniboost/BalancerPoolerV2. Any cross-contract double-counting of the donated USDC is an interaction/econ concern on the inherited convention, not a new story-044 faithfulness deviation.
- **`pool()` does not invoke the dispatch hook** (`test_pool_doesNotInvokeHook` L448): intended — `pool()` converts already-retained USDC, no mint occurs. Conformant.

## storiesChecked

`["story-044"]`
