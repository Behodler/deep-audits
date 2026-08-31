# Deduplicated Findings — stable-staker run-13 (story-013, `InPlaceMigrator._reinjectWithTopup`)

- **Submodule HEAD:** `d95f4a6` (story-013 "Add surplus-funded re-injection top-up (M-01 haircut fix)")
- **Diff baseline:** `ffa4947` (story-012)
- **Mode:** regression; all candidates Low/QA — no High/Medium this run
- **Inputs:** code-scan (CODE-001..005), econ-scan (ECON-13-001/002), faithfulness (no F-XX), static-analysis (FP only), profile (LOCAL-001..005)
- **Timestamp:** 2026-06-15

## Summary

7 raw candidates → **4 consolidated findings** (1 footgun + 3 QA-grade). Two consolidations on shared root cause; one informational note absorbed; one finding kept as a tiny standalone QA. All findings are availability / implementation-quality flavoured on the new `migrateIn` top-up path; none re-introduce the silent under-credit that story-013 fixes (ss12m1 confirmed value-loss-closed by econ-scan, marked FIXED — not in this dedup set).

---

## DEDUP-13-001 — Underfunded `migrateIn` reverts the whole batch; greedy cross-slice surplus drain strands later paginated slices

- **Proposed label:** L-01 (footgun)
- **Severity hypothesis:** **Low** (Law-3 non-obvious owner footgun; `claimTimedOut` backstop guarantees principal recovery). Econ-scan flags a conditional Medium argument ONLY if the story-013 runbook fails to document the surplus pre-funding precondition — route that decision to story-faithfulness / severity-classifier. Faithfulness produced no F-XX, so the precondition-documentation question is open.
- **Root-cause class:** `surplus-underfunding-batch-revert / no-cross-slice-reservation`
- **Contract:function:** `src/InPlaceMigrator.sol` — `migrateIn` / `_reinjectWithTopup` (:280-283 surplus require, :292 par require)
- **Consolidates:** ECON-13-001 (primary, most complete analysis) + CODE-005 (greedy cross-batch surplus consumption — same root: shared budget, no reservation) + profiler LOCAL-001 + LOCAL-002.
- **Also absorbs (error-quality facet):** CODE-002 — the surplus `require`'s `balanceOf - totalParked` subtraction underflows to a panic (0x11) instead of the intended `"top-up surplus exhausted"` string. This is the *same* underfunded-surplus path; folded in as a sub-point (operator sees an arithmetic panic, masking the real under-funding root cause). Fix: saturating-sub before the compare.
- **Mechanism:** Top-up is funded from `surplus = balanceOf(this) - totalParked[token]`, which the operator must pre-fund; nothing in the contract creates/reserves it. Zero/insufficient surplus trips the per-user require and reverts the whole atomic slice (no user re-injected). Across separate paginated `migrateIn` calls there is no global reservation of surplus against the remaining parked haircut, so an earlier slice can greedily drain surplus and strand a later slice.
- **Why not Medium/High:** atomic revert (no principal loss), `onlyOwner` + `nonReentrant` + `private` helper (no permissionless griefing), and `claimTimedOut` (permissionless, self-scoped) guarantees eventual principal recovery.
- **Candidate ledger-match (flag, do NOT suppress — sanitizer's call):** sibling-adjacent to **ss12l1 (`bda951d9`, open, `nonatomic-per-user-deposit-loop-dos`)** — both are whole-batch `migrateIn` reverts on the same loop, but DISTINCT trigger/root cause (ss12l1 = `require(credited>0)` zero-credit poison user; this = surplus underfunding / mulDiv-fed top-up). Same DoS *symptom*, different root cause → keep separate per "same vuln type, different root cause" rule. Also operationally coupled to DEDUP-13-002 (sweep removes the same budget).

## DEDUP-13-002 — `rescueERC20` and the top-up budget are the same `balance - totalParked`; sweeping mid-migration bricks par-restoration

- **Proposed label:** L-02 (footgun)
- **Severity hypothesis:** **Low** (operational coupling; folds into DEDUP-13-001's funding hazard; `rescueERC20` cannot touch parked principal, so no user loses principal — only a migration stall + `claimTimedOut` backstop).
- **Root-cause class:** `rescue-vs-topup-budget-coupling`
- **Contract:function:** `src/InPlaceMigrator.sol` — `rescueERC20` (:337-341) vs `_reinjectWithTopup` budget (:280-283)
- **Consolidates:** ECON-13-002 + profiler LOCAL-004.
- **Kept distinct from DEDUP-13-001:** shares the `balance - totalParked` quantity but a *separate* root cause (no escrow/earmark of in-flight surplus) and a *separate* mitigation (earmark/lock surplus, or runbook "do not `rescueERC20` mid-migration"). Per the keep-both rule (different root cause + separate mitigation).
- **Mechanism:** No escrow separates "surplus reserved for in-flight top-ups" from "stray sweepable surplus." An operator who sweeps via `rescueERC20` after pre-funding but before completing `migrateIn` removes the top-up budget and triggers the DEDUP-13-001 revert. Donation to inflate surplus is benign (does not enter `totalParked`).
- **Candidate ledger-match (flag, do NOT suppress):** thematically near **`0790a76a` (open Low, "rescueERC20 can sweep the buffer backing underwater withdrawals", `StableStaker.sol:rescueERC20`)** — same *pattern* (rescueERC20 sweeps an unescrowed in-flight reserve) but DIFFERENT contract (InPlaceMigrator vs StableStaker), different reserve (top-up surplus vs underwater buffer), different fingerprint. Pattern-duplicate across contracts but distinct root location → keep separate; sanitizer to confirm.

## DEDUP-13-003 — Small-principal top-up truncation reverts `migrateIn` (mulDiv → 0 top-up AND `amt/1000` → 0 tolerance)

- **Proposed label:** L-03 (QA)
- **Severity hypothesis:** **Low / QA** (dust/edge availability DoS; atomic revert, no loss; triggerability depends on token decimals / haircut granularity — most fragile for sub-unit-decimal tokens and `amt < 1000` raw-unit positions).
- **Root-cause class:** `small-principal-topup-truncation-reverts-batch`
- **Contract:function:** `src/InPlaceMigrator.sol` — `_reinjectWithTopup` (:276/:284 gross-up→`depositFor(0)`; :292 zero-tolerance par require)
- **Consolidates:** CODE-001 + CODE-004 — SAME root cause (integer truncation on a small principal). Two compounding facets:
  1. **CODE-001:** when the shortfall grosses up to `topup == 0` (`mulDiv` floors while `credited < amt`), the second `staker.depositFor(token, user, 0)` hits `require(amount > 0, "StableStaker: amount=0")` and reverts the whole atomic batch. The `if (credited < amt)` predicate and `depositFor`'s `> 0` precondition are misaligned; control never reaches the `finalCredited` backstop that would have accepted `credited` as-is. Fix: guard the top-up with `if (topup > 0)`.
  2. **CODE-004:** for `amt < 1000` raw units, `amt/1000 == 0`, so `finalCredited >= amt - amt/1000` collapses to exact-par with zero tolerance; since the gross-up rounds DOWN, `finalCredited` is generically a few wei short → revert. The "0.1% slack" guarantee silently evaporates below `amt = 1000` units. Fix: absolute residual floor, or document/require `amt >= 1000` units.
- **Compounding:** small-`amt` haircut users are simultaneously most likely to gross up to a 0 top-up (CODE-001) and to fail the zero-tolerance assert (CODE-004) — same population, same root, both fail-modes are batch-atomic reverts (never silent under-credit; ss12m1 stays fixed).
- **Candidate ledger-match (flag):** another sibling DoS trigger on the `migrateIn` loop alongside ss12l1 (`bda951d9`) and DEDUP-13-001 — distinct root cause (truncation arithmetic vs zero-credit guard vs surplus underfunding). Keep separate.

## DEDUP-13-004 — Widened `forceApprove(staker, balanceOf(this))` leaves a dangling allowance, contradicting the in-code comment

- **Proposed label:** L-04 (QA / hygiene)
- **Severity hypothesis:** **Low / QA** (lingering allowance; bounded by immutable, trusted `staker` target — NOT an exploit under owner-trust Law 3; the kept value is the code-comment contradiction, not a security vector).
- **Root-cause class:** `dangling-allowance-comment-mismatch`
- **Contract:function:** `src/InPlaceMigrator.sol` — `migrateIn` approval step (:225-227)
- **Standalone:** CODE-003 — distinct root cause and distinct mitigation from all others (approval hygiene, not a revert path); kept on its own per the keep-both rule.
- **Mechanism:** Approval widened from `forceApprove(staker, total)` to `forceApprove(staker, balanceOf(this))`. The loop only pulls `total + Σtopup ≤ balance`, so the residual allowance `balanceOf - (total + Σtopup)` remains granted to `staker` after the batch. Each subsequent `migrateIn` `forceApprove`s afresh (overwrites — no monotonic accumulation), but the in-code comment claiming "no dangling allowance" is inaccurate: `forceApprove` overwrites on the *next* call but does not zero the residual at batch end. Bounded because `staker` is `immutable` and trusted. Fix: approve exactly `total + projectedTopups`, or `forceApprove(staker, 0)` after the loop.
- **Candidate ledger-match:** none.

---

## Filtered / folded (with reasoning)

| Raw candidate | Disposition | Reason |
|---|---|---|
| ECON-13-001 | → DEDUP-13-001 (primary) | Most complete analysis; preserved as the lead. |
| CODE-005 | folded into DEDUP-13-001 | Same root as ECON-13-001 (shared surplus budget, no per-slice reservation); explicitly self-described as non-standalone (overlaps LOCAL-002). |
| CODE-002 | folded into DEDUP-13-001 (sub-point) | Error-quality facet of the *same* underfunded-surplus path (the `balanceOf - totalParked` underflow IS the insufficient-surplus condition). Not worth a standalone QA — it is the revert-message quality of DEDUP-13-001. |
| ECON-13-002 | → DEDUP-13-002 | Distinct root cause (budget-coupling) + distinct mitigation; kept. |
| CODE-001 | → DEDUP-13-003 (facet 1) | Same root cause as CODE-004 (small-principal truncation). |
| CODE-004 | → DEDUP-13-003 (facet 2) | Same root cause as CODE-001; explicitly cross-referenced as compounding. |
| CODE-003 | → DEDUP-13-004 | Distinct root cause + mitigation; standalone QA hygiene. |
| static-analysis | dropped | False positives only (per scan); no findings. |
| faithfulness | n/a | No F-XX produced; note the open question for DEDUP-13-001 (does story-013 document the surplus precondition?). |

## Candidate ledger-matches (flagged for sanitizer — NOT suppressed here)

| Consolidated | Ledger entry | Relationship | Action |
|---|---|---|---|
| DEDUP-13-001 | ss12l1 `bda951d9` (open Low) | Sibling DoS on same `migrateIn` loop; DISTINCT root cause (surplus underfunding vs `require(credited>0)` zero-credit). | Keep separate; sanitizer to confirm no fingerprint collision (distinct rootCauseClass). |
| DEDUP-13-002 | `0790a76a` (open Low) | Pattern-duplicate (`rescueERC20` sweeps unescrowed in-flight reserve) across DIFFERENT contracts (InPlaceMigrator vs StableStaker) / reserves. | Keep separate; flag the pattern parallel. |
| DEDUP-13-003 | ss12l1 `bda951d9` (open Low) | Sibling DoS trigger on same loop; DISTINCT root cause (truncation arithmetic). | Keep separate. |
| DEDUP-13-004 | — | No match. | — |

**Note on ss12m1 (`970d7307`):** econ-scan verified story-013 CLOSES the value-loss (re-injection haircut) and proposes flipping it to `fixed`. That disposition is upstream of this dedup pass and not a candidate-suppression here.
