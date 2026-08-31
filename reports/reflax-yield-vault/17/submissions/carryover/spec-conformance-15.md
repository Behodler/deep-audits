> **Carryover spec-conformance report — audit 15** (cut down from `reports/reflax-yield-vault/15/submissions/spec-conformance.md`).
> Retained below (still open / untriaged as of audit 17): **F-04, F-05**.
> Removed as carried elsewhere: the F-03 section (run-14 carryover — carried under audit **14**).
> Labels are the originals. Law-2 faithfulness entries are carried in this channel, **never** folded into the QA bundle.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping**:
> - `F-04` → `6711114c7f9d6211`
> - `F-05` → `1559780543e8b9ba`

*The text below is a verbatim copy of the retained sections of the original report.*

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
