# C4 Severity Classification — stable-staker run-12

- **Project:** stable-staker
- **Run:** stable-staker-12 (REGRESSION)
- **Submodule HEAD:** `ffa494783f585bcd2ce1ff60dd756345717287f1` — `[story-012] Add InPlaceMigrator`
- **New contract under test:** `src/InPlaceMigrator.sol` (+316 LOC)
- **Input:** 5 sanitized canonical findings (DEDUP-12-001..005), all passed as `new`, 0 suppressed.
- **Severity criteria:** project `CLAUDE.md` C4 definitions (High / Medium / QA-Low) + three-law hierarchy.
- **Precedent anchor:** ledger M-07 `969722dc` (rate-vs-execution deposit slippage) was classified **Medium** when it manifested on `setYieldStrategy`'s in-place swap. DEDUP-12-001 is the same economic vector relocated to `InPlaceMigrator.migrateIn → depositFor`. Classified consistently below.
- **Timestamp:** 2026-06-15

---

## CLASS-12-001 — DEDUP-12-001 — Re-injection haircut: silent per-user principal loss

```json
{
  "classifiedFinding": {
    "id": "CLASS-12-001",
    "originalId": "DEDUP-12-001",
    "fingerprint": "src/InPlaceMigrator.sol:migrateIn:yield-principal-accounting-skew-deposit-leg",
    "severity": "medium",
    "c4Label": "M-01",
    "plausibility": "n/a (Medium)",
    "faithfulness": true,
    "footgun": true,
    "regression": false,
    "relatedTo": ["969722dc", "dab5a656"],
    "requiresPoC": true,
    "pocStatus": "PROVEN-PoC (Tier-3 invariant, workspace/stable-staker/test/poc/InPlaceMigratorConservation.t.sol)",
    "classification": {
      "assetImpact": "Per-user principal loss of (amt - credited). migrateIn zeroes parked/totalParked by the requested amt (InPlaceMigrator.sol:215-217) while depositFor credits only _routeDeposit's haircut return (StableStaker.sol:630-634). The gap is irrecoverable: no residual parked, no event, no revert. PoC: 8e6 USDC lost on 400e6 re-injection @ 200bps; fuzzed 1-500bps all break; loss scales linearly with slippage and pool size.",
      "attackPath": [
        "1. Operator runs the in-place flow (initiateMigration -> batchMigrate parks principal in migrator).",
        "2. Operator resets pool and wires a haircutting (market/AMM/fee'd-ERC4626) strategy via setYieldStrategy on the empty pool.",
        "3. Operator calls migrateIn: it zeroes parked[user] by full amt and calls depositFor(token, user, amt).",
        "4. depositFor pulls full amt but _routeDeposit returns credited < amt (strategy haircut); user.amount += credited.",
        "5. Each re-injected user is permanently short amt - credited; totalParked is driven to 0 despite the shortfall."
      ],
      "likelihood": "medium - no external attacker needed (not theft); requires the operator to wire a haircutting re-injection strategy. Idle/direct/par/1:1-ERC4626 targets produce zero loss. The M-07 lineage establishes that AMM/market strategies are a real deployment class for this protocol.",
      "assumptions": "The new in-place strategy is a haircutting (market/AMM/fee'd-ERC4626) target; at least one parked user is re-injected.",
      "externalRequirements": "Operator choice of a slippage/fee-bearing re-injection strategy."
    },
    "justification": "Genuine per-user principal loss, PoC-proven on the project's real contracts (the green suite only passed because its mock ran at par). This is NOT direct unconditional theft executable by any external attacker, so it does not meet the C4 High bar of 'assets lost directly or via a valid attack path without hypotheticals': the loss is gated on a stated assumption (operator wires a haircutting strategy) plus an external requirement (that strategy class). That precondition is exactly the C4 Medium clause 'value leak with stated assumptions and external requirements'. It is also strictly above QA: a real bounded principal loss, not state-handling or style. The M-07 precedent (969722dc, same rate-vs-execution deposit-slippage vector, Medium when PoC'd on a real AMM strategy on setYieldStrategy) controls; story-012 re-expresses that vector through the new migrateIn door after the empty-pool gate closed the setYieldStrategy door, so Medium is the consistent and principled landing. Flagged faithfulness:true (breaks the migrator's stated AC-1 'crediting each user the exact principal parked for them', InPlaceMigrator.sol:168) and footgun:true (silent; operator reaching for a 'safe rewire' tool onto a haircutting target is surprised, non-obvious Law-3). High would over-state (requires the operator's strategy choice = hypothetical); Low would under-state (real proven principal loss)."
  }
}
```

**High vs Medium vs Low — explicit argument:**
- **Not High.** C4 High requires assets lost directly, or via a valid attack path *without hypotheticals*. Here the loss only materializes if the operator wires a haircutting re-injection strategy — direct/idle/par/1:1-ERC4626 targets preserve principal exactly (PoC 0bps control is clean). That conditional is the textbook "stated assumptions + external requirements" qualifier, which C4 routes to Medium, not High. There is no external-attacker path and no unconditional drain.
- **Not Low/QA.** It is a real, bounded, PoC-proven per-user principal loss with no residual to reclaim and no event — not state-handling, not a spec comment, not pure centralization. Downgrading to Low would understate a proven asset loss.
- **Medium, consistent with M-07.** Same economic vector (rate/requested-vs-execution deposit slippage), same Medium-grade precondition (haircutting strategy realistically wired), same per-user principal-leak harm. Landed **M-01** in this run's report.

---

## CLASS-12-002 — DEDUP-12-002 — Poison/zero-credit user reverts the whole `migrateIn` slice

```json
{
  "classifiedFinding": {
    "id": "CLASS-12-002",
    "originalId": "DEDUP-12-002",
    "fingerprint": "src/InPlaceMigrator.sol:migrateIn:nonatomic-per-user-deposit-loop-dos",
    "severity": "low",
    "c4Label": "L-01 (QA bundle)",
    "plausibility": "n/a (Low)",
    "faithfulness": false,
    "footgun": true,
    "regression": false,
    "crossRef": ["59eebbf8", "eae10d60", "8d5ceff2"],
    "requiresPoC": false,
    "pocStatus": "CONFIRMED-by-read + Tier-3 covers it (test_zeroCreditUser_revertsWholeSlice_thenClaimTimedOutRescues)",
    "classification": {
      "assetImpact": "No principal loss. A single parked user whose amt haircuts to zero credit reverts the whole migrateIn slice via story-011's require(credited>0) (StableStaker.sol:632) in the non-atomic loop (InPlaceMigrator.sol:207-224). Migration availability/completeness only; every parked user recovers full principal via claimTimedOut (InPlaceMigrator.sol:239-256).",
      "attackPath": [
        "1. Same haircutting-strategy precondition as DEDUP-12-001, plus a dust-sized parked position.",
        "2. The dust position rounds to zero credit on the new strategy; its depositFor reverts.",
        "3. The all-or-nothing loop has no per-user try/catch, so the entire migrateIn slice reverts.",
        "4. Operator must re-page around the poison user; that user stays parked until claimTimedOut returns principal."
      ],
      "likelihood": "low - requires both the haircutting-strategy precondition AND a position dust-small enough to round to zero credit. No attacker incentive (self-harming at most).",
      "assumptions": "Haircutting re-injection strategy (conjoined to DEDUP-12-001) plus a parked position that rounds to zero credit.",
      "externalRequirements": "Same haircutting strategy as DEDUP-12-001."
    },
    "justification": "Availability/completeness of an onlyOwner operational function, with principal always recoverable via the timeout hatch (proven in the PoC). C4 Medium's 'function/availability impacted' clause is reachable in principle, but the impact is a re-pageable operator inconvenience with a guaranteed principal-recovery hatch and double-gated preconditions (haircut AND zero-credit dust), so it lands Low rather than Medium. It is conjoined to DEDUP-12-001's precondition (do not keep one and drop the other inconsistently). Bundle into the QA report as L-01; the migrator's non-atomic loop (no per-user try/catch) is the root cause, distinct from 59eebbf8's unbounded-gas DoS and from the correctly-fixed eae10d60 guard (this is a downstream consequence of that guard existing, not a regression)."
  }
}
```

---

## CLASS-12-003 — DEDUP-12-003 — Underwater-migration operator footgun

```json
{
  "classifiedFinding": {
    "id": "CLASS-12-003",
    "originalId": "DEDUP-12-003",
    "fingerprint": "src/InPlaceMigrator.sol:initiateMigration:underwater-flow-realizes-socialized-haircut",
    "severity": "low",
    "c4Label": "L-02 (QA bundle)",
    "plausibility": "n/a (Low)",
    "faithfulness": false,
    "footgun": true,
    "regression": false,
    "crossRef": ["69c7666e"],
    "requiresPoC": false,
    "pocStatus": "CONFIRMED-by-read (behaviour is intended/faithful; the tool-choice surprise is the footgun)",
    "classification": {
      "assetImpact": "The underwater delta p_i*(1 - R/P) is realized and socialized once, faithfully to the documented min(R,P)/P terminal-migration socialization (StableStaker.sol:527-528). The loss itself is INTENDED design (story-003/004), not a bug. The footgun is that initiateMigration is not blocked on an impaired strategy and gives no migrator-side signal, so an operator reaching for a 'safe rewire' tool silently crystallizes a live loss.",
      "attackPath": [
        "1. Old strategy is underwater (realizable R < principal P).",
        "2. Operator runs initiateMigration expecting a loss-neutral dependency swap.",
        "3. The terminal-migration leg realizes R and credits each user p_i*min(R,P)/P = p_i*R/P.",
        "4. The underwater delta is socialized once, correctly but silently, with no migrator-side warning."
      ],
      "likelihood": "low - requires the operator to run the in-place flow on a below-par strategy; non-malicious operator following safe-config guidance avoids it.",
      "assumptions": "Operator runs initiateMigration on an underwater (R<P) old strategy.",
      "externalRequirements": "None beyond operator tool-choice."
    },
    "justification": "Pure Law-3 non-obvious operator footgun: the socialization arithmetic is faithful and correct (no new value bug), but a competent non-malicious operator would be surprised that the in-place 'rewire' tool crystallizes a loss on live users. Per CLAUDE.md, a non-obvious footgun is in scope as an operational hazard, classified by impact — here the impact is intended-and-correct socialization, so the only deliverable is safe-config guidance (check withdrawDisabled/_isUnderwater before running the flow; route impaired strategies through the cross-staker terminal path instead). Low/QA. Not suppressed by KI#6 (that is _routeExit buffer-at-par FCFS; this is the distinct terminal-migration min(R,P)/P path on a different entry point)."
  }
}
```

---

## CLASS-12-004 — DEDUP-12-004 — Revived-pool permissionless-stake window (refuted exploit)

```json
{
  "classifiedFinding": {
    "id": "CLASS-12-004",
    "originalId": "DEDUP-12-004",
    "fingerprint": "src/StableStaker.sol:finalizeAndReset:revived-pool-permissionless-stake-window-emission-dilution",
    "severity": "qa",
    "c4Label": "L-03 (QA bundle)",
    "plausibility": "n/a (QA/Low)",
    "faithfulness": false,
    "footgun": true,
    "regression": false,
    "crossRef": ["ss9l1", "ss10l1"],
    "requiresPoC": false,
    "pocStatus": "REFUTED as exploit (no first-depositor inflation; MasterChef accumulator, not share-price)",
    "classification": {
      "assetImpact": "None to principal. After finalizeAndReset the empty pool is Active and stake is permissionless before migrateIn runs; an interloper can stake first. Reward accounting is a MasterChef accumulator (accPhusdPerShare/rewardDebt), not a totalAssets-derived share price, so there is no first-depositor inflation and each parked user's depositFor credits their own amt to their own userInfo. Only effect: emission-share dilution (standard MasterChef TVL dilution), which is in-motion/unmatured yield, not principal.",
      "attackPath": [
        "1. Operator runs finalizeAndReset; pool returns to Active with permissionless stake.",
        "2. Operator has not pause-wrapped the out->reset->rewire->in session.",
        "3. An interloper stakes into the transiently-empty revived pool before migrateIn.",
        "4. Effect: dilutes future phUSD emission share only; no principal is reachable, no inflation skim."
      ],
      "likelihood": "n/a - the theft/inflation vector is refuted; residual is a benign emission-dilution window.",
      "assumptions": "Operator does not pause-wrap the revival session.",
      "externalRequirements": "None."
    },
    "justification": "Theft/inflation/rate-manipulation vectors were independently refuted by both Tier-2 agents: there is no share price to inflate (MasterChef accumulator), parked principal is unreachable by outsiders, and migrateIn credits each user their own pinned amt. The only residual is emission-share dilution of unmatured/in-motion yield, which per the special-case rule is capped at Medium even when real — and here it is merely the normal, intended consequence of more TVL, not a leak. That makes it a QA/Low operational note (recommend pause-wrapping the out->reset->rewire->in session). Kept in a visible channel per Law 1 (refuted-exploit dispositions are documented, never silently dropped). Adjacent to ss9l1 / ss10l1 on the same revival surface; flag to qa-bundler for a single 'revival-window pause-wrap' recommendation."
  }
}
```

---

## CLASS-12-005 — DEDUP-12-005 — Near-`MIN_TIMEOUT` multi-batch self-exit

```json
{
  "classifiedFinding": {
    "id": "CLASS-12-005",
    "originalId": "DEDUP-12-005",
    "fingerprint": "src/InPlaceMigrator.sol:claimTimedOut:short-timeout-multibatch-partial-refill",
    "severity": "low",
    "c4Label": "L-04 (QA bundle)",
    "plausibility": "n/a (Low)",
    "faithfulness": false,
    "footgun": true,
    "regression": false,
    "requiresPoC": false,
    "pocStatus": "CONFIRMED-by-read (emission-cap integrity + no profitable force-timeout separately refuted)",
    "classification": {
      "assetImpact": "No value lost. If migrationTimeout is sized near MIN_TIMEOUT (1 day) and a multi-batch rewire stalls past it, parked users can claimTimedOut mid-migration (taking full principal and self-exiting); the later migrateIn slice then skips them (amt==0 -> continue, InPlaceMigrator.sol:210), leaving a partially-refilled pool. Migration completeness only; every user keeps their principal.",
      "attackPath": [
        "1. Operator deploys with migrationTimeout near MIN_TIMEOUT and runs a many-batch job (which the docs explicitly scope OUT, InPlaceMigrator.sol:54-55).",
        "2. The rewire stalls past the timeout.",
        "3. Parked users claimTimedOut, recovering full principal and leaving the set.",
        "4. The later migrateIn slice skips the self-exited users; the pool is left partially refilled."
      ],
      "likelihood": "low - requires a near-MIN timeout AND a many-batch/long-running job that violates the contract's own documented single-session scope.",
      "assumptions": "migrationTimeout set near MIN_TIMEOUT and a multi-batch job that stalls.",
      "externalRequirements": "None beyond operator config."
    },
    "justification": "Law-3 timeout-sizing operator footgun with no fund loss — users who self-exit recover full principal; only migration completeness is affected. The emission-cap integrity and the absence of any profitable force-timeout incentive were separately refuted, leaving completeness as the sole residual. Non-obvious enough to surface (a competent operator running a many-batch job with a near-MIN timeout would be surprised by mid-flight self-exits), but the deliverable is pure safe-config guidance: size migrationTimeout comfortably above the full out->reset->in duration (the 7-day default is sound). Low/QA."
  }
}
```

---

## Summary

| Label | Canonical ID | Severity | Plausibility | PoC required | PoC status | Faithfulness | Footgun |
|---|---|---|---|---|---|---|---|
| **M-01** | DEDUP-12-001 (re-injection haircut) | **Medium** | n/a | **Yes** | PROVEN-PoC (have it) | yes (AC-1 break) | yes (silent) |
| **L-01** | DEDUP-12-002 (poison-user batch revert) | Low | n/a | No | Tier-3 covers it | no | yes |
| **L-02** | DEDUP-12-003 (underwater-migration footgun) | Low | n/a | No | confirmed-by-read | no | yes |
| **L-03** | DEDUP-12-004 (revived-pool window, refuted) | QA/Low | n/a | No | refuted exploit | no | yes |
| **L-04** | DEDUP-12-005 (near-MIN_TIMEOUT self-exit) | Low | n/a | No | confirmed-by-read | no | yes |

- **Findings classified:** 5 (all passed sanitizer as `new`).
- **High:** 0. **Medium:** 1 (M-01). **Low/QA:** 4 (L-01..L-04, → single QA bundle).
- **PoC required for submission:** only M-01 (DEDUP-12-001), and it already has a PROVEN Tier-3 PoC. No Highs, so no plausibility sub-category is in play.
- **Faithfulness routing (Law 2):** DEDUP-12-001 is tagged `faithfulness: true` (breaks the migrator's stated "credit each user the exact principal parked" intent). It carries real principal-loss impact, so per Law 1 it keeps its honest **Medium** in the main report as M-01 AND should be surfaced in the spec-conformance report (e.g. F-XX) as a story-012 deviation — not buried in QA.
- **Footgun routing (Law 3):** L-02, L-03, L-04 are non-obvious owner footguns classified by impact (all Low — no fund loss / intended-and-correct socialization / completeness-only) with safe-config guidance. L-03's exploit angle is refuted; kept visibly as Low/QA.

### Precedent-consistency note (the anchor)
DEDUP-12-001 is landed **Medium**, identical to ledger M-07 (`969722dc`). The vector is the same rate-vs-execution deposit-slippage value-leak; the empty-pool gate that retired M-07 on `setYieldStrategy` is structurally re-opened by story-012's sanctioned in-place `migrateIn` door, and the same per-user principal shortfall returns on the re-injection deposit leg. It is bounded by the new strategy's slippage/fee and conditional on the operator wiring a haircutting strategy (par/idle/direct targets ⇒ no loss). That conditionality is precisely C4's "value leak with stated assumptions and external requirements" Medium clause — not unconditional High (which would require a hypothesis-free attacker path) and not QA (it is a proven principal loss, not state-handling). No principled reason to deviate from the M-07 Medium precedent was found.

### Human-attention flag (carried from sanitizer)
The four `acknowledged` Mediums (`969722dc`/`dab5a656`/`dbdc3ac9` + the M-01 family) carry a *proposed-fixed @125f585* that rests on the empty-pool gate forbidding in-place swaps. Before confirming `/ledger fixed 969722dc`, the human should weigh that **M-01 (DEDUP-12-001) re-expresses the M-07 economic vector through the new in-place door** — the gate closes the `setYieldStrategy` path but not the new `migrateIn` path. Do not auto-flip those to `fixed`.
