# Economic Scan — PromotionUniV2_Eth.sol (story-044, HEAD 8dd8963)

- **Project:** yield-claim-nft (run-17)
- **Scan type:** economic (Tier 2, protocol-wide)
- **Target:** `src/dispatchers/PromotionUniV2_Eth.sol`
- **Context:** base `ATokenDispatcherV2.sol`, `IUniswapV2Router02.sol`
- **Profile consumed:** `reports/yield-claim-nft/17/profiles/PromotionUniV2_Eth.profile.md`
- **Precedent applied:** ledger `L-06` (Uniboost/Balancer LP-add MEV, LOW), `L-09` (unwired-hook fail-open, LOW), `M-04` (fixed), DEDUP-001 (external-backing, SUPPRESSED)

## Verdict up front

The Tier-1 "top economic risk" (MISSING-SLIPPAGE / spot-ratio pooling) is **Low**, not Medium.
The authorization gate + keeper-quoted floors + post-call `minLP` backstop are the exact same
control model that kept `L-06` at Low, and the new ETH leg does **not** introduce a materially
new profitable vector. Value conservation holds (all USDC → protocol-owned LP + recoverable
on-contract dust; no egress to an unauthorized party). No High/Medium surfaced. Findings below
are Low/QA, several are recurrences of already-ledgered items.

---

## ECON-001 — pool() MEV/sandwich exposure via unforced (zero-allowed) slippage floors + `amountMin=0` addLiquidity  —  **LOW**

- **Location:** `pool()` L277-307, `_legA` L313-326, `_legB` L332-346, `addLiquidity(...,0,0,...)` L299-301
- **Type:** missing-slippage / MEV
- **Root cause:** All five slippage parameters (`minPhusdOut`, `minEthOut`, `minPromoOut`, `minLP`)
  are caller-supplied and **none is forced non-zero on-chain**; `addLiquidity` is called with
  `amountAMin = amountBMin = 0`. `pool()` is a public transaction, so a sandwicher can move any of
  the four swap legs (USDC→ETH, ETH→promotion, Leg-A Balancer sUSDS→phUSD) or donate to the target
  pair before the LP-add, extracting value up to the slack the pooler leaves in its quotes.
- **Why it is NOT Medium (precedent + control model):**
  1. `pool()` is gated `onlyAuthorizedPooler + whenNotPaused + nonReentrant` (L279-281). Only an
     owner-authorized keeper triggers it; there is no unprivileged path to force a zero-floor call.
  2. The design's stated protection is keeper-quoted floors on every leg plus a **post-call
     `require(liquidity >= minLP)`** (L302). `minLP` is the on-chain backstop that specifically
     defends the `amountMin=0` LP-add: in UniV2, minted LP = `min(amtA·supply/resA, amtB·supply/resB)`,
     so a reserve-skew (donation-to-pair or front-run) that would degrade the add reduces `liquidity`
     and trips `minLP` → revert. Excess on the over-supplied side is **refunded** by the router and
     accrues as on-contract dust (protocol-retained), not lost to the pair.
  3. This is the identical control model as ledger **L-06**, which was triaged **Low** precisely
     because "the pooler is authorized and quotes floors." Per the task's explicit instruction, do
     not re-escalate settled precedent without a concrete new vector.
  4. The new ETH leg adds two more sandwich surfaces but each carries its **own** floor
     (`minEthOut`, `minPromoOut`); it is *more legs of the same keeper-quoted class*, not a new
     class. The PSM `sellGem` step (L315-317) is a fixed-rate conversion with no market slippage —
     the `tin() <= maxTin` ceiling (L315) is its only variable, and it is bounded.
- **Residual (honest) risk:** correctness depends on the keeper passing tight, freshly-quoted
  values. A keeper that passes `0` (laziness/bug) exposes the full sandwich band. That is an
  operational/keeper-quality concern, not a protocol-level exploit with a permissionless trigger.
- **Economic impact:** bounded by keeper quote slack; worst case a lazy keeper loses swap/LP slack
  on a single `pool()` batch (retained USDC only, never user funds — dispatch already happened).
- **Affected parties:** protocol treasury (LP value), only under keeper misquote.
- **Confidence:** high. **Severity: LOW** (matches L-06; do not escalate).
- **Recommendation (non-blocking):** consider forcing `minLP > 0` and/or non-zero `amountAMin/BMin`
  as a cheap defense-in-depth so a zero-floor keeper call cannot silently ship. Optional.

---

## ECON-002 — `_legB` whole-balance ETH sweep + open `receive()` (donation folds into promotion buy)  —  **LOW / QA**

- **Location:** `_legB` L342-345 (`ethBal = address(this).balance` then `swapExactETHForTokens{value: ethBal}`), open `receive()` L400
- **Type:** value-misallocation / griefing surface
- **Root cause:** `_legB` swaps the **entire** contract ETH balance, not just the output of this
  call's USDC→ETH swap. `receive()` is open (L400), so any third party can pre-fund ETH; it is
  folded into the promotion buy of whichever authorized pooler calls `pool()` next.
- **Direction of value flow — protocol-POSITIVE, not a leak:**
  - Donated ETH → extra promotion tokens (owned by the dispatcher) → `addLiquidity` uses full
    `promoBal`; the excess promotion side is **refunded** by the router and retained as dust for the
    next `pool()`. The donated value ends up as protocol-owned LP/dust. The **donor** loses their
    ETH; the protocol gains it.
  - No DoS: extra ETH only *raises* promotion-out, so `minPromoOut` (a floor) is more easily met,
    never violated; `minLP` is limited by the phUSD side, unaffected by excess promotion.
  - No profitable attack: an attacker who donates ETH to pump the ETH→promotion pool is **funding
    their own victim's buy with their own ETH** — they subsidize the pump they'd need to sandwich.
    Fails the profitability test; no rational attacker.
- **Economic impact:** none adverse to protocol; a griefer can only *donate* value. Residual ETH
  never strands (UniV2 `swapExactETHForTokens` consumes the full `{value:}`; leftover only ever
  arises from external donation, recoverable via `rescueETH` L393).
- **Affected parties:** only a self-harming donor.
- **Confidence:** high. **Severity: LOW / QA** (informational value-conservation note).
- **Note:** worth a code comment that the full-balance sweep is intentional and protocol-positive,
  so a future maintainer does not "fix" it into a leak.

---

## ECON-003 — Unwired-hook fail-open: zero mint-debt / unbacked phUSD (L-09 class recurrence)  —  **LOW (already ledgered)**

- **Location:** base `dispatch` L118-126 → `hook.onDispatch(...)`; `hook` defaults to no-op
  `DefaultDispatchHook` (base ctor L51); no `hookTypeId` guard in this dispatcher (profile §9).
- **Root cause:** identical to ledger **L-09** (and the `M-04` class): if the owner never calls
  `setHook(mintDebtHook)`, `dispatch` accrues **zero** mint-debt on the gross USDC while phUSD is
  still minted upstream → unbacked phUSD. `_dispatch` here uses the same gross-amount hook
  convention (profile §3), so the backing correctness rides entirely on the hook being wired, with
  no on-chain `hookTypeId()` verification to reject a wrong/absent hook.
- **Assessment:** this is **not a new finding** — it is the L-09 fail-open class reborn on a third
  dispatcher (as the profile flags). Consistent with the run-13 memory note, surface it as a
  recurrence for triage; do **not** auto-collapse into Q-08 and do **not** re-file as new. `M-04`
  is marked fixed at the hook level, but this dispatcher carries no type-guard, so the operational
  footgun persists exactly as L-09 describes.
- **Confidence:** high. **Severity: LOW** (reconciles to open L-09).

---

## ECON-004 — `setMaxTin` uncapped: removes the sole Leg-A PSM protection (owner footgun)  —  **QA / LOW**

- **Location:** `setMaxTin` L208-211 (no upper bound); consumed at `_legA` L315.
- **Root cause:** `setMaxTin` accepts any value; `maxTin` (default `1e16` = 1%) is the **only**
  guard on Leg-A step 1 (`ISkyPSM.sellGem`, which has no per-tx min-out). Raising it high accepts a
  larger PSM `tin` fee.
- **Law-3 framing:** the setter is explicitly named `setMaxTin` with NatSpec "ceiling on the PSM
  `tin` (sell fee)" (L72, L207). A competent non-malicious owner raising it is **not surprised** the
  fee ceiling rises — the consequence is obvious from the name/docs. Additionally, PSM `sellGem` is a
  **fixed-rate** USDC→USDS conversion (no market slippage), so the exposure is bounded to the
  accepted fee, not an open-ended drain. Per Law 3 this is a trusted-owner obvious-config, not a
  reportable footgun.
- **Confidence:** high. **Severity: QA** (keep `maxTin` tight; informational only). Do not escalate.

---

## ECON-005 — `block.timestamp` swap/LP deadlines provide no effective expiry  —  **QA / informational**

- **Location:** `_legB` L338, L344; `addLiquidity` L300 — all pass `block.timestamp`.
- **Root cause:** `block.timestamp` is evaluated at execution, so the deadline is always satisfied;
  a `pool()` tx could sit in the mempool and execute later than the keeper intended.
- **Assessment:** the real price protection is the per-leg min-out floors + `minLP`; a stale tx
  that executes after an adverse move simply reverts on a floor. With an authorized-keeper trigger
  and non-zero floors, residual risk is negligible. Informational.
- **Confidence:** high. **Severity: QA / informational.**

---

## Non-findings verified (assurance)

- **Value conservation HOLDS:** `amountIn` USDC → `halfA` (Leg A → phUSD) + `halfB` (Leg B →
  ETH → promotion); `addLiquidity` deploys full phUSD/promotion balances, refunds the excess side as
  on-contract dust (swept into the next `pool()` or `rescueERC20`'d). LP accrues on the dispatcher
  as protocol-owned liquidity (sole withdrawal path `rescueERC20` L387). No path routes retained
  USDC/LP to an unauthorized party. Odd-wei split (`halfB = amountIn - halfA`, L286-287) is exact.
- **phUSD backing / donation split:** mint-debt accrues on GROSS USDC while `donationSplit%` is
  forwarded to `batchMinter` (L255-262) — the established DEDUP-001 external-backing convention
  (same as Uniboost/BalancerPoolerV2). **No new deviation** from that model; DEDUP-001 itself not
  re-filed (project-SUPPRESSED).
- **Approvals:** every `forceApprove(spender, x)` is reset to `0` after use (PSM L318, both
  router legs L340/L303-304). No lingering allowance.
- **Reentrancy:** `pool()` and `dispatch` share OZ `nonReentrant`; `unlockCallback` is hard-gated
  to `BALANCER_VAULT` and only reachable inside the guarded `pool()` frame. No re-entry into
  unguarded owner mutators from swap/receive callbacks.
- **Spot-ratio / first-deposit / donation-to-pair on the UniV2 pair:** defended by `minLP` (LP
  quantity floor) with excess refunded as retained dust; manipulation forces a revert (griefing, no
  profit), not a protocol loss. Folded into ECON-001.

---

## Ranked summary

| # | Finding | Severity | New? | Basis |
|---|---|---|---|---|
| ECON-001 | pool() MEV via unforced floors + amountMin=0 addLiquidity | **LOW** | extends L-06 | authorized pooler + keeper floors + minLP backstop; ETH leg = same class, more legs |
| ECON-002 | Whole-balance ETH sweep + open receive() | **LOW/QA** | new (benign) | protocol-positive misallocation; no theft, no DoS, no profitable attack |
| ECON-003 | Unwired-hook fail-open → unbacked phUSD | **LOW** | recurrence of L-09 | no hookTypeId guard; reconciles to open L-09 |
| ECON-004 | setMaxTin uncapped | **QA** | new | Law-3 obvious owner config; PSM fixed-rate bounds it |
| ECON-005 | block.timestamp deadlines | **QA/info** | new | floors are the real protection |

**No High or Medium findings.** The headline slippage/MEV risk is correctly Low under the L-06
precedent; the genuinely new ETH surface is protocol-positive rather than extractive.
