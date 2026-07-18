# C4 Severity Classification — yield-claim-nft run-17

- **Project:** yield-claim-nft
- **Target:** `src/dispatchers/PromotionUniV2_Eth.sol` (story-044, NEW ETH-leg dispatcher)
- **Submodule HEAD:** `8dd8963`
- **Agent:** severity-classifier
- **Date:** 2026-07-18
- **Pass type:** Low/QA classification pass — **NO High/Medium candidates.**
- **Inputs:** `sanitized/sanitized-findings.md`, `scans/econ-scan.md`, `scans/code-scan.md`, `ledgers/yield-claim-nft.json`
- **Next free labels:** highest open L = **L-12** → new **L-13**; highest open Q = **Q-11** → new **Q-12**.

Verdict: 1 new Low (L-13), 4 new QA (Q-12..Q-15), 2 carryover Lows confirmed (L-06, L-09). No finding meets the C4 High (direct theft/loss) or Medium (protocol-function / conditional value-leak) bar. Value conservation holds across the new ETH leg (Tier-3 all invariants HELD; INV-4 confirmed donated ETH can never reach a third party).

---

## Classified table

| Label | Origin | C4 Severity | Plausibility | Justification (impact → C4 criterion) |
|-------|--------|-------------|--------------|----------------------------------------|
| **L-13** | CANDIDATE-1 (NEW) | **Low** | plausible (footgun) | Whole-balance ETH sweep + open `receive()`: a non-obvious Law-3 footgun with a real state-handling/value-misattribution consequence (stray ETH folds into the *next* pooler's buy at that keeper's floors; a pooler can front-run `rescueETH`). No value at risk — donated ETH routes only into protocol-owned LP (Tier-3 INV-4: never reaches a third party); the sole loser is a self-harming donor. Not direct theft/loss (not High), not a protocol-function/value-leak-with-conditions (not Medium), above pure informational because the surprising ETH-balance handling + rescue-timing hazard is a demonstrated operational hazard → **Low (incorrect/surprising state handling + in-scope footgun).** Cross-ref **F-01-044** (faithfulness record for story-044). |
| **L-06** | CANDIDATE-2 (carryover) | **Low** (confirmed) | plausible | `pool()`/`unlockCallback` MEV-sandwich via unforced (zero-allowed) floors + `amountAMin=amountBMin=0` addLiquidity. **Confirmed Low still correct:** the ETH leg adds two more sandwich surfaces but each carries its **own** floor (`minEthOut`, `minPromoOut`), and the post-call `require(liquidity>=minLP)` backstops the LP add; authorized-keeper gate means no unprivileged zero-floor trigger. More legs of the same keeper-quoted class, not a new class — same control model that settled L-06 at Low. Worst case = lazy-keeper slack on retained protocol funds; not user assets, not a permissionless exploit → stays **Low.** Do not re-escalate settled precedent. Reuse fingerprint `342075df…`; no new label. |
| **L-09** | CANDIDATE-3 (carryover) | **Low** (confirmed) | plausible (footgun) | Unwired/wrong dispatch hook (no `hookTypeId` guard; ctor defaults `hook` = no-op `DefaultDispatchHook`) silently accrues zero phUSD mint-debt — 4th dispatcher to carry the M-04 fail-open class. **Confirmed Low:** owner-config footgun, recoverable, no theft; reconciles to open L-09, kept DISTINCT from wont-fix Q-08 (BalancerPoolerV2) and NOT re-filed. Reuse fingerprint `563df2e6…`; no new label. |
| **Q-12** | QA-a (NEW) | **QA** | — | `block.timestamp` swap/LP deadlines give no effective expiry (always satisfied at execution). Informational hardening — the real price protection is the per-leg min-out floors + `minLP`; a stale tx reverts on a floor. No asset/availability impact. Facet of L-06. |
| **Q-13** | QA-b (NEW) | **QA** | — | Unchecked UniV2 router swap return values on the ETH legs. Bounded by the on-chain min-out floors (`minEthOut`/`minPromoOut`) + `minLP`; a shortfall trips a floor and reverts. Robustness/hardening only, no value leak → QA. |
| **Q-14** | QA-c (NEW) | **QA** | — | Unchecked Balancer `settle` return in `unlockCallback`. Safe by construction: Balancer V3 `unlock` reverts if transient debt is not fully settled, so a shortfall reverts the whole `pool()`. Informational only → QA. |
| **Q-15** | QA-e (NEW) | **QA** | — | `addLiquidity` residual dust ignored — by-design, NatSpec-documented, and recoverable (swept into the next `pool()` or via `rescueERC20`). No loss; documented-dust hardening note → QA. |

### Not classified here (already dispositioned upstream — listed for auditability, Law 1)
| Item | Disposition | Why not classified |
|------|-------------|--------------------|
| QA-d | carryover-of-**Q-05** (open, QA) | Same `nonReentrant`-not-first modifier-order class; reuse Q-05 fingerprint, **do NOT relabel.** |
| QA-f | **SUPPRESSED-KI-4** (visible) | `setMaxTin` = price/fee-setting owner action, Law-3 *obvious* consequence, PSM fixed-rate bounds exposure; suppressed, **do NOT label.** |
| SUPPRESSED-DEDUP-001 | suppressed (visible) | External-backing/over-backing facet; project-suppressed umbrella `070fdf42…`, no new unbacked-mint path. |

---

## Detailed classification — L-13 (CANDIDATE-1)

```json
{
  "classifiedFinding": {
    "id": "CLASS-17-001",
    "originalId": "CANDIDATE-1 / ECON-002 / code-scan L-1",
    "label": "L-13",
    "severity": "low",
    "plausibility": "plausible",
    "footgun": true,
    "faithfulness": false,
    "crossRef": "F-01-044 (story-044 faithfulness record)",
    "regression": false,
    "contract": "src/dispatchers/PromotionUniV2_Eth.sol",
    "function": "_legB / receive",
    "classification": {
      "assetImpact": "None adverse to protocol or third parties. Donated/stray ETH is irreversibly converted to promotionToken and added to protocol-owned phUSD/promotion LP (withdrawable only via owner rescueERC20). Tier-3 INV-4 confirmed the value can NEVER route to a third party. The only party who can lose value is a self-harming donor who voluntarily sends ETH to an open receive().",
      "attackPath": [
        "1. _legB reads ethBal = address(this).balance and swaps the ENTIRE contract ETH balance (not just this call's USDC->ETH output) via swapExactETHForTokens{value: ethBal}.",
        "2. Open receive() (L400) lets any third party pre-fund ETH onto the contract.",
        "3. On the NEXT authorized pool(), that stray ETH folds into whichever pooler calls next, buying promotion tokens at that keeper's floors and mis-attributing the donation to them.",
        "4. Net: donor loses ETH; protocol gains LP. No theft, no third-party profit, no DoS (extra ETH only raises promotion-out, easing minPromoOut; uint112 reserve overflow needs infeasible >uint112 donation)."
      ],
      "likelihood": "low - requires a voluntary ETH donation to an open receive(); no rational attacker (donating ETH to pump the pool funds the victim's own buy with the attacker's ETH, failing the profitability test).",
      "assumptions": "Whole-balance sweep is intentional/protocol-positive (per ECON-002); pool() is onlyAuthorizedPooler + whenNotPaused + nonReentrant.",
      "externalRequirements": "A third party must pre-fund ETH via receive() before a pool() call; a pooler may front-run rescueETH."
    },
    "severityRationale": "NOT High: no direct or indirect theft/loss — value is conserved into protocol-owned LP (INV-4). NOT Medium: no protocol-function/availability impact and no conditional value-leak away from the protocol (the flow is protocol-POSITIVE). ABOVE QA: a competent non-malicious owner would be surprised that (a) any third party's stray ETH folds into the next pool at that keeper's floors and (b) a pooler can front-run rescueETH and mis-attribute a donation — a non-obvious Law-3 footgun with a demonstrated state-handling/value-misattribution consequence and safe-config guidance. => Low (incorrect/surprising state handling + in-scope operational hazard), consistent with the ledger's other non-obvious footgun Lows (L-10/L-11/L-12).",
    "safeConfigGuidance": "Sweep stray ETH (rescueETH, L393) before authorizing a pool() if it must not enter LP; document that the whole-balance sweep is intentional so a future maintainer does not 'fix' it into a leak.",
    "justification": "Non-theft value-misattribution footgun on the first ETH-handling dispatcher; concrete surprising behavior, zero protocol/third-party value at risk. Honest Low, not QA."
  }
}
```

### Low-vs-QA judgement (recorded honestly, per task)
The finding sits on the Low/QA boundary. It is classified **Low, not QA**, because:
- It has a **demonstrated non-obvious consequence** (stray ETH folds into the next pooler's buy at that keeper's floors; `rescueETH` is front-runnable), passing the Law-3 surprise test → in-scope operational hazard, not mere information.
- The ledger's established convention classifies analogous non-obvious owner/operational footguns (L-10 deploy-config, L-11 batch-floor staleness, L-12 pause-custody gap) at **Low**, not QA. L-13 is the same family.

It is **not** pushed above Low because value is fully conserved to the protocol (Tier-3 INV-4), there is no third-party profit, no DoS, and no user assets are ever at risk — the accidental-send variant is additionally C4 known-invalid ("user input mistake"), which caps the reportable substance to the footgun/state-handling framing.

---

## Ledger bookkeeping (handed to finding-manager)
- **New label L-13** (Low, footgun, `firstSeenRun=yield-claim-nft-17`, cross-ref F-01-044) — CANDIDATE-1.
- **New QA labels Q-12, Q-13, Q-14, Q-15** (all `qa`, `firstSeenRun=yield-claim-nft-17`) — QA-a/b/c/e respectively → QA bundle.
- **Carryover (no new label):** L-06 (reuse `342075df…`), L-09 (reuse `563df2e6…`), Q-05 (reuse `13fe448d…`) — bump `lastSeenRun` → yield-claim-nft-17; severities UNCHANGED (all confirmed correct).
- **Suppressed (visible, no label change):** DEDUP-001 (`070fdf42…`, no stub), QA-f/KI-4.
- Counts: new-classified = 5 (1 Low + 4 QA); carryover-confirmed = 3 (L-06, L-09, Q-05); regressions = 0; H/M = 0.
