# Spec-Conformance Report — reflax-yield-vault

**Run:** reflax-yield-vault-15
**Audited commit:** `ad12cb1` (baseline `2f6774d`)
**Stories checked:** `story-047` (global setAsideBufferRecipient), `story-048` (creditedPrincipal fix, preview functions, withdrawal retiming)
**Channel:** Law-2 (Faithfulness to stories). This report is intentionally **separate from the QA/gas bundle** — these are story/spec deviations and conformance verification records, not gas or style noise.

---

## Scope and conventions

This report collects the run's **faithfulness findings** (`F-XX`) and the **CONFORMS verification records** that justify not raising findings. Per the Three-Law hierarchy, a faithfulness deviation that *also* carries asset/value/availability impact additionally receives an H/M (or Low) label; this run, both deviations are documentation-only — their behaviour legs live in the new Lows **L-14** and **L-15** (QA bundle, operational-footgun section).

**Headline: both stories are FAITHFUL on behaviour.** The deviations below are stale-documentation conflicts the stories left behind, plus an annotation to the standing F-03 cross-protocol constraint.

| ID | Subject | Verdict / Status | Origin | Severity-on-this-channel |
|----|---------|------------------|--------|--------------------------|
| **F-04** | Stale story-042 per-client-reserve NatSpec on `setAsideBufferSize` contradicts story-047 behaviour | DEVIATES · open | **NEW (this run)** | QA (doc fix; behaviour leg = **L-15**) |
| **F-05** | Three doc sources still claim 24h/48h withdrawal timings vs story-048's 6h/72h code | DEVIATES · open | **NEW (this run)** | QA (doc fix; behaviour/monitoring leg = **L-14**) |
| **F-03** | Cross-protocol integration assumption for stable-staker M-05 wiring of `relinquishPrincipal` | open · **ANNOTATED this run** | carryover (first seen run-14) | Faithfulness — Medium re-eval gate now armed (live callsite) |
| FAITH-15-001 | story-047 implementation conformance | CONFORMS | verification record | none |
| FAITH-15-002 | story-048 implementation conformance | CONFORMS | verification record | none |
| FAITH-15-005 | Law-1 unsafe-story check on the 24h→6h retiming | CONFORMS (not unsafe) | verification record | none — rationale capping L-14 at Low |
| FAITH-15-006 | Law-1/Law-3 check on global buffer redirect | CONFORMS (footgun retained) | verification record | folds into **L-15** |
| F-01 / F-02 | run-12 faithfulness carryovers | open — **not re-triggered this run** (no diff lines touch them) | ledger | unchanged; see ledger |

---

## F-04 — Stale story-042 per-client-reserve NatSpec contradicts story-047 behaviour (NEW)

**Status:** open · **Origin:** new (reflax-yield-vault-15) · **Story:** `story-047` (commit `933620d`)
**Location:** `src/AYieldStrategy.sol#L51-L53` (`setAsideBufferSize` NatSpec) and `src/interfaces/IYieldStrategy.sol#L130-L132`
**Fingerprint:** `6711114c…` (`sha256(src/AYieldStrategy.sol:setAsideBufferSize-natspec:stale-story042-per-client-reserve-doc)`, empty `entryPoint`)
**Cross-reference:** **L-15** carries the behaviour leg (multi-client cross-subsidy footgun these stale docs set up). qa-bundler emits **ONE combined doc-fix item** with L-15's NatSpec leg, not two.

### What the story says (intent)

> story-047: "rework `_distributeBuffer()` to single aggregate transfer to recipient" — *redirect all set-aside buffers to single address*.

### What the stale docs still say

> `AYieldStrategy.sol:51-53`: "this percentage of the client's own realized surplus is **returned to the client** instead of going to `recipient`, giving the client a reserve to absorb below-par dips"
> `IYieldStrategy.sol:130-132`: "percentage of the client's realized surplus is **returned to the client** (a reserve against …)"

### Actual behavior at this commit

Since story-047, the set-aside is **never** returned to the client; it is summed across all clients and sent in one transfer to the global `setAsideBufferRecipient` (`ERC4626YieldStrategy.sol:323`, `ERC4626MarketYieldStrategy.sol:368`). The stale `setAsideBufferSize` NatSpec directly contradicts the (correct) new NatSpec on `setAsideBufferRecipient` three lines below it — **conflicting spec sources inside the same file**. An integrator reading the `setAsideBufferSize` docs would wrongly conclude their contract receives its own buffer back.

### Recommendation

Update `AYieldStrategy.sol:51-53` and `IYieldStrategy.sol:130-132` to state the percentage is routed to `setAsideBufferRecipient` (protocol-level yield routing, not a client reserve).

---

## F-05 — Three documentation sources still claim 24h/48h against the story-048 6h/72h code (NEW)

**Status:** open · **Origin:** new (reflax-yield-vault-15) · **Story:** `story-048` (commit `ad12cb1`)
**Location:** `src/AYieldStrategy.sol#L414` and `src/interfaces/IYieldStrategy.sol#L101` (`totalWithdrawal` NatSpec); `registered-projects.json` → reflax-yield-vault designDecision #5
**Fingerprint:** `15597805…` (`sha256(src/AYieldStrategy.sol:totalWithdrawal-natspec:stale-24h48h-timing-doc)`, empty `entryPoint`)
**Cross-reference:** **L-14** carries the behaviour/monitoring substance (announced-vs-executed drift + 4x-shrunk reaction window). QA-02's title and C-01's narrative were text-refreshed in the ledger; the registry update is a **project-manager action item** (`action-items.json` ACTION-15-001 / DISC-15-003).

### What the story says (intent)

> story-048: "change WAITING_PERIOD from 24h to 6h, EXECUTION_WINDOW from 48h to 72h, update TOTAL_DURATION comment from 72h to 78h"

### What the stale docs still say

> `AYieldStrategy.sol:414` / `IYieldStrategy.sol:101`: "Phase 1: Initiates **24-hour** waiting period. Phase 2: Executes withdrawal within **48-hour** window."
> registry designDecision #5: "Two-phase emergency withdrawal (totalWithdrawal) with **24h** waiting period and **48h** execution window inherited from AYieldStrategy"

### Actual behavior at this commit

Constants are **6 hours / 72 hours** (`AYieldStrategy.sol:84-86`, source-verified; Tier-3 window-boundary tests confirm the constants and inclusivity are implemented correctly). Three documentation sources contradict the code; anyone relying on the documented 24h community-reaction window (monitoring, off-chain alerting SLAs) would size their response time **4x too generously**.

### Recommendation

Update `AYieldStrategy.sol:414` and `IYieldStrategy.sol:101` to 6h/72h (78h total); project-manager updates registry designDecision #5; refresh any user-facing docs citing a 24h reaction window.

---

## F-03 — Cross-protocol integration assumption for stable-staker M-05 wiring (carryover, ANNOTATED)

**Status:** open · **Origin:** carryover (first seen reflax-yield-vault-14) · **Fingerprint:** `52f9b84a…`
**Original report:** [`reports/reflax-yield-vault-14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json`](../../reflax-yield-vault-14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json)

### Annotation this run (FAITH-15-007)

F-03's recorded premise — *"no callsite at this commit"* — is now **STALE on the consumer side**: `lib/stable-staker/src/StableStaker.sol:786` (`_routeExit` underwater path) now calls `strategy.relinquishPrincipal(token, amount)` immediately before the caller pays the user from the on-contract buffer. story-047 is a **different leg** of the same M-05 program (it funds the consumer-side buffer with skimmed surplus); it does not add, modify, or exercise any `relinquishPrincipal` callsite in reflax, so it neither satisfies nor violates F-03's invariant.

**Disposition:** F-03 stays **open**; the ledger entry was annotated with the live callsite and a cross-project re-check trigger. **The Medium re-evaluation gate fires in the next stable-staker regression run**, where the wiring must be checked against the pay-out-then-relinquish / no-double-credit invariant — together with the DEDUP-15-005 buffer-inflow attribution question and FAITH-15-006's rescue-footgun note (StableStaker's owner rescue treats idle balance as fully rescuable, `StableStaker.sol:797-805`, and would unknowingly drain the underwater-exit reserve story-047 funds).

---

## Conformance verification records (no findings)

### FAITH-15-001 — story-047 implementation: CONFORMS

All criteria verified at `ad12cb1`: `setAsideBufferRecipient` storage (`AYieldStrategy.sol:62`); `SetAsideBufferRecipientSet` event (`:116-121`); zero-address-validated `onlyOwner` setter (`:352-357`); `IYieldStrategy` declarations (`:141-153`); `_distributeBuffer` reworked to a single aggregate transfer (`ERC4626YieldStrategy.sol:323` / `ERC4626MarketYieldStrategy.sol:368`); loud revert guard when `totalBufferShares > 0` and recipient unset (`ERC4626YieldStrategy.sol:245-248` / `ERC4626MarketYieldStrategy.sol:291-294`); both concretes structurally identical; zero-buffer back-compat preserved (unbuffered fast path returns before the guard).

### FAITH-15-002 — story-048 implementation: CONFORMS

All criteria verified at `ad12cb1`: `creditedPrincipal = vault.previewRedeem(sharesReceived)` (`ERC4626YieldStrategy.sol:113`); `previewDeposit` (`:73`) / `previewRedeem` (`:83`) delegating to vault; `WAITING_PERIOD = 6 hours` / `EXECUTION_WINDOW = 72 hours` / "78 hours total" comment (`AYieldStrategy.sol:84-86`); enum comments updated. `ERC4626MarketYieldStrategy._acquireShares` was deliberately not in story scope (it already credits a conservative slippage-haircut value, never the raw nominal amount). Residual `previewRedeem(previewDeposit(x)) <= x` vault-property question is **not** a faithfulness issue — it rides manual-review **DEDUP-15-006**, gated on the ERC4626YieldStrategy scope decision (DISC-15-004).

### FAITH-15-005 — Law-1 unsafe-story check on the 24h→6h retiming: CONFORMS (not unsafe)

Assessed and **not** escalated: zero-delay owner exfiltration already exists via `emergencyWithdraw` (no timelock, works while paused — standing C-01), so the `totalWithdrawal` waiting period was never the binding rug protection; 6h vs 24h changes the marginal protection of a path dominated by a 0h path. The story is explicit and deliberate. Kept visible as **the rationale capping L-14 at Low**; the disclosure obligation (docs/monitoring) is F-05 + the QA-02/C-01 text refreshes.

### FAITH-15-006 — Law-1/Law-3 check on the global buffer redirect: CONFORMS (footgun retained at Low)

Not an unsafe story: redirected funds are realized **surplus only** (principal accounting untouched), the redirect is explicit and loudly documented on the recipient side, and story-047 removes the old front-run-the-skim self-benefit incentive; legitimate under the intended one-client-per-strategy deployment. The retained Law-3 multi-client footgun is the **same hazard as L-15** and folds into it as independent corroboration (no parallel label). Its cross-protocol StableStaker-rescue note rides the DEDUP-15-005 next-stable-staker-run trigger.

---

## Triage

F-04 and F-05 are `open` doc deviations; fix is a single combined NatSpec pass plus the registry update (project-manager, `action-items.json`). F-03 remains `open` with its Medium re-evaluation gate now **armed** by the live `StableStaker.sol:786` callsite — it fires in the **next stable-staker regression run**. F-01/F-02 remain open in the ledger, un-triggered this run. Triage with `/ledger reflax-yield-vault`.
