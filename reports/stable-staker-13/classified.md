# Severity Classification — stable-staker run-13 (story-013, `InPlaceMigrator._reinjectWithTopup`)

- **Submodule HEAD:** `d95f4a6` (story-013 "surplus-funded re-injection top-up / M-01 haircut fix")
- **Input:** `reports/stable-staker-13/sanitized.md` (DEDUP-13-001..004, all survivors)
- **Mode:** regression
- **Timestamp:** 2026-06-15
- **Classifier:** severity-classifier (C4 criteria + three-law hierarchy)

## Headline

This run produced **NO High and NO Medium** findings and **NO faithfulness (F-XX)** deviations. The run headline is the `ss12m1` (M-01 haircut) → `fixed` regression confirmation, handled separately by finding-manager. All four surviving findings are operational-hardening residue of that very fix and classify to **Low / QA**. Per CLAUDE.md, non-critical findings are discouraged and overstatement is rejected — these are reported at honest, conservative severity.

---

## Final severity table

| ID | Label | C4 Severity | Routing | Faithfulness | Footgun | Regression | One-line basis |
|---|---|---|---|---|---|---|---|
| DEDUP-13-001 | L-01 | **Low** | QA bundle (footgun) | no | yes | no | Atomic revert + permissionless `claimTimedOut` self-recovery → migration deferred, not DoS'd; no value loss. Medium hook declined. |
| DEDUP-13-002 | L-02 | **Low** | QA bundle (footgun) | no | yes | no | Non-obvious `rescueERC20`↔top-up-budget coupling stalls migration; principal floor intact, `claimTimedOut` backstop. |
| DEDUP-13-003 | L-03 | **Low/QA** | QA bundle | no | no | no | Integer-truncation revert on small principals; availability edge-case, no loss. |
| DEDUP-13-004 | L-04 | **QA / info** | QA bundle | no | no | no | Code-vs-comment contradiction on dangling allowance; bounded by immutable trusted `staker`, no value at risk. |

**Counts:** High 0 · Medium 0 · Low 3 · QA/info 1 · Faithfulness (F-XX) 0 · Regression 0.

---

## Per-finding classification

### DEDUP-13-001 — Underfunded `migrateIn` batch revert + greedy cross-slice surplus drain → **Low (footgun)**

```json
{
  "classifiedFinding": {
    "id": "CLASS-13-001",
    "originalId": "DEDUP-13-001",
    "label": "L-01",
    "severity": "low",
    "plausibility": "n/a (availability/footgun, no theft path)",
    "regression": false,
    "faithfulness": false,
    "footgun": true,
    "classification": {
      "assetImpact": "None. Failure mode is an atomic revert of the migrateIn batch — no silent under-credit, no principal loss. Parked principal stays escrowed under totalParked and is recoverable.",
      "attackPath": [
        "Not an attack. Operator runs documented migrateOut -> reset -> migrateIn runbook.",
        "A migrateIn slice routes through a haircutting strategy; gross-up topup = mulDiv(amt-credited, amt, credited) (:276).",
        "require(topup <= balanceOf - totalParked) (:280-281) fails because operator did not separately pre-fund the grossed-up surplus.",
        "Whole batch reverts atomically (greedy earlier slices can also exhaust shared surplus, stranding later paginated slices).",
        "Recovery: operator pre-funds surplus and re-runs; OR each user calls permissionless self-scoped claimTimedOut (:306) to recover parked principal."
      ],
      "likelihood": "Medium operationally — non-obvious surplus pre-funding step invisible at the call site; competent operator following the runbook would be surprised. But strictly recoverable.",
      "assumptions": "Strategy applies a haircut on credited principal; operator did not perform the undocumented gross-up pre-funding step.",
      "externalRequirements": "Owner/migrator operating the path (onlyOwner + nonReentrant + private helper); no permissionless griefing vector."
    },
    "mediumHookAssessment": "CONDITIONAL-MEDIUM DECLINED. C4 Medium requires protocol function/availability to be impacted in a way not recoverable through normal means. Here the migration leg is RETRYABLE, not bricked: (a) the failure is an atomic revert with zero value leak, and (b) claimTimedOut is permissionless and self-scoped, so every user can recover parked principal independent of the operator. The migration is DEFERRED until the operator pre-funds the grossed-up surplus, not permanently DoS'd. This is a recoverable operator-runbook gap (operational hazard), which is honestly a Low footgun, not a Medium availability impairment. Escalating would overstate.",
    "subPoints": "Folds CODE-002: the surplus require subtracts balanceOf - totalParked (:281), underflowing to panic 0x11 instead of a readable revert when surplus is exhausted — masks the under-funding root cause. Error-quality QA sub-point on the same path; does not change severity.",
    "justification": "Non-obvious surplus pre-funding requirement that a non-malicious owner would be surprised by => in-scope footgun (Law 3). No asset risk, full recoverability via claimTimedOut => Low, routed to QA bundle with safe-config guidance: document the gross-up pre-funding precondition and reserve per-slice surplus before paginating."
  }
}
```

### DEDUP-13-002 — `rescueERC20` vs top-up budget coupling bricks par-restoration → **Low (footgun)**

```json
{
  "classifiedFinding": {
    "id": "CLASS-13-002",
    "originalId": "DEDUP-13-002",
    "label": "L-02",
    "severity": "low",
    "plausibility": "n/a (footgun)",
    "regression": false,
    "faithfulness": false,
    "footgun": true,
    "classification": {
      "assetImpact": "None. Principal floor (totalParked) intact and advertised as untouchable; only an in-progress migration stalls. claimTimedOut backstops user recovery.",
      "attackPath": [
        "Owner pre-funds surplus for an in-progress migration.",
        "Owner sweeps 'stray' balance via rescueERC20 (:337-339) as routine housekeeping.",
        "rescueERC20 and the _reinjectWithTopup surplus budget (:280-281) draw from the SAME unescrowed balanceOf - totalParked quantity.",
        "The sweep silently removes the in-flight top-up budget -> next migrateIn slice triggers the DEDUP-13-001 revert.",
        "Recovery: re-fund surplus and re-run, or users self-exit via claimTimedOut."
      ],
      "likelihood": "Low-Medium — requires owner to sweep mid-migration; non-obvious that a sweep fenced above the principal floor can brick a migration.",
      "assumptions": "Migration in flight; owner performs a reasonable rescueERC20 housekeeping sweep before the batch completes.",
      "externalRequirements": "onlyOwner action; non-malicious owner unaware of the inter-function coupling."
    },
    "justification": "Non-obvious inter-function coupling (rescueERC20 <-> top-up surplus) that a competent non-malicious owner would be surprised by => Law-3 operational hazard. No principal loss, recoverable => Low. Not a malicious-owner vector (suppressed) — kept value is the surprising coupling. Safe-config guidance: escrow the in-flight top-up surplus or gate rescueERC20 while a migration is open."
  }
}
```

### DEDUP-13-003 — Small-principal top-up truncation reverts `migrateIn` → **Low/QA**

```json
{
  "classifiedFinding": {
    "id": "CLASS-13-003",
    "originalId": "DEDUP-13-003",
    "label": "L-03",
    "severity": "low",
    "plausibility": "n/a (implementation-quality / availability)",
    "regression": false,
    "faithfulness": false,
    "footgun": false,
    "classification": {
      "assetImpact": "None. Integer-truncation causes an atomic revert on small-principal slices; no value moves.",
      "attackPath": [
        "CODE-001: when shortfall grosses up to topup == 0 (mulDiv floors, :276), depositFor(token, user, 0) hits require(amount > 0) and reverts the atomic batch; the if (credited < amt) predicate (:273) is misaligned with depositFor's >0 precondition, so control never reaches the finalCredited backstop (:288-292).",
        "CODE-004: for amt < 1000 raw units, amt/1000 == 0, so require(finalCredited >= amt - amt/1000) (:292) collapses to zero-tolerance exact-par; gross-up rounds DOWN so finalCredited is a few wei short -> revert. The advertised 0.1% slack evaporates below amt = 1000 units."
      ],
      "likelihood": "Low — only bites on sub-1000-unit principals (dust migrations).",
      "assumptions": "A migrateIn slice carries a principal small enough that the gross-up truncates to zero or below the (vanishing) slack floor.",
      "externalRequirements": "None — pure arithmetic on the migration path."
    },
    "justification": "Implementation-quality / availability arithmetic defect, not an owner action and not a theft path. Distinct from KI#2 (which blesses silent reward dust round-DOWN; this is a REVERT on the migration path). No value loss => Low/QA. Fix: align the >0 / truncation predicates and use a tolerance floor that does not collapse below amt=1000."
  }
}
```

### DEDUP-13-004 — Dangling `forceApprove(staker, balanceOf)` contradicts comment → **QA / info**

```json
{
  "classifiedFinding": {
    "id": "CLASS-13-004",
    "originalId": "DEDUP-13-004",
    "label": "L-04",
    "severity": "qa",
    "plausibility": "n/a (documentation/hygiene)",
    "regression": false,
    "faithfulness": false,
    "footgun": false,
    "classification": {
      "assetImpact": "None. Residual allowance balanceOf - (total + Sigma topup) granted to staker, but staker is immutable and trusted; next migrateIn overwrites (no monotonic accumulation).",
      "attackPath": [
        "NatSpec at :190-192 claims forceApprove is set to the EXACT slice total and 'never left dangling ... nothing lingers'.",
        "Code at :225-226 approves balanceOf(address(this)), which exceeds total + Sigma topup.",
        "A residual allowance lingers to staker after the batch — the comment's invariant is false as written.",
        "Bounded: staker immutable + trusted => no value at risk; no exploit."
      ],
      "likelihood": "n/a — no exploit; pure code-vs-comment contradiction.",
      "assumptions": "staker remains the immutable trusted address (true by construction).",
      "externalRequirements": "None."
    },
    "justification": "Verifiable documentation/hygiene defect surfaced under Law-1 recall-beats-tidiness (visible QA channel, not dropped). Not a faithfulness F-XX deviation — it is a code-vs-in-code-comment mismatch, not a deviation from a [story-NNN] stated behaviour. Bounded by the immutable trusted staker => no security impact => QA/info. Fix: forceApprove(staker, total + projectedTopups) or a trailing forceApprove(staker, 0)."
  }
}
```

---

## Routing summary

- **QA bundle (qa-bundler):** L-01, L-02 (footgun operational hazards), L-03 (arithmetic), L-04 (hygiene/info). No standalone H/M submissions.
- **Spec-conformance (F-XX):** none — no story deviation. story-013's stated intent (close the haircut, restore par within 1 wei, revert atomically on zero surplus) is faithfully met and verified fixed.
- **Faithfulness flag:** false on all four.
- **Human-review flags:** none — DEDUP-13-001's conditional-Medium hook is resolved (declined) with explicit reasoning above; not borderline-uncertain.

## Severity-discipline note

All four findings are residue of the story-013 top-up fix on its own path. Every new failure mode is an atomic revert (no silent under-credit), so none reopens the value-loss axis that `ss12m1` (M-01) closes — `ss12m1` correctly stays `fixed`. Holding these at Low/QA (rather than escalating DEDUP-13-001 to Medium) preserves report credibility: the fix is correct on value-loss; these are operational-hardening follow-ups, honestly weighted.
