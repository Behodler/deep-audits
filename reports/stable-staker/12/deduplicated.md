# Deduplicated Canonical Findings — stable-staker run-12

- **Project:** stable-staker
- **Submodule HEAD:** `ffa494783f585bcd2ce1ff60dd756345717287f1` — `[story-012] Add InPlaceMigrator`
- **New contract under test:** `src/InPlaceMigrator.sol` (+316 LOC)
- **Phase:** deduplication / consolidation (post Tier-1/2/3, pre-sanitizer)
- **Inputs consolidated:** code-scan (CODE-12-01..04), econ-scan (ECON-12-01..04),
  faithfulness (F-12-001..003), pattern-matches (PM-12-01, PM-12-02, PM-12-MR-01..04),
  static-analysis (SA-001..009), profile (SURFACE-1..6)
- **Tier-3 evidence:** invariant test PROVED DEDUP-12-001 — 8e6 lost on a 400e6 re-injection at
  200 bps deposit slippage; fuzzed 1–500 bps all show `info.amount < parked` with `totalParked`
  zeroed; the par-preserving (0 bps) case is clean.
- **Timestamp:** 2026-06-15

---

## Method

`InPlaceMigrator` holds no economic math of its own; it orchestrates the already-audited
`StableStaker` terminal-migration surface. Six agents converged on the **same small set of root
causes**, almost all gated on one shared precondition: *does the new in-place re-injection strategy
haircut the deposit?* Consolidation is therefore mostly root-cause grouping (Phase 2) plus dropping
the refuted reentrancy cluster and the deterministic tool noise (Phase 4).

The two live findings (DEDUP-12-001, DEDUP-12-002) share that single precondition; the three Low
footguns are independent. SA-007 is carried as a **non-finding ledger note**, not a run-12 finding.

---

## Canonical findings

### DEDUP-12-001 — Re-injection haircut: `migrateIn` zeroes parked principal by the *requested* amount while `depositFor` credits the strategy's *haircut* return; silent per-user principal loss

- **Canonical ID:** DEDUP-12-001
- **Merged source-tags:** CODE-12-01 = ECON-12-01 = F-12-001 = PM-12-01 = SURFACE-1
  (+ SA-001's deposit-leg accounting concern, the M-07 relocation noted across all three Tier-2 outputs)
- **Root-cause class:** YIELD-PRINCIPAL-ACCOUNTING-SKEW relocated to the deposit (re-injection) leg
  — the M-07 rate-vs-execution-slippage residual the story-010 empty-pool gate was built to keep off
  live pools, reintroduced on the way back in.
- **Location:**
  - `src/InPlaceMigrator.sol:215-217` (state zeroed/decremented by the **requested** `amt`)
  - `src/InPlaceMigrator.sol:223` (`staker.depositFor(token, user, amt)`)
  - `src/StableStaker.sol:630-634` (`received = _pullToken(...)`; `credited = _routeDeposit(...)`; `info.amount += credited`)
  - `src/StableStaker.sol:757-762` (`_routeDeposit` returns `strategy.deposit(...)`; doc `:753-756` "market strategy haircuts below `amount`")
- **One-line statement:** `migrateIn` zeroes `parked`/`totalParked` by the full requested `amt`, but
  `depositFor` credits only `_routeDeposit`'s return; on a haircutting (market/AMM/fee'd-ERC4626)
  re-injection strategy `credited < amt`, so each re-injected user silently loses `amt - credited`
  with no event, no revert, no residual `parked` to reclaim.
- **Proof status:** **PROVEN-PoC** (Tier-3 invariant: 8e6 lost on 400e6 @ 200 bps; fuzzed 1–500 bps
  reproduce; 0 bps par-preserving mock is clean — the existing suite cannot catch it).
- **Condition / precondition:** the new strategy wired by `setYieldStrategy` between `migrateOut` and
  `migrateIn` is a **haircutting** market/AMM/fee'd-ERC4626 strategy. If only par-preserving
  direct/idle/1:1-ERC4626 strategies are ever wired in place, this collapses to informational.
- **Harm / law:** per-user principal loss (NOT socialized across the pool); Law-1 value loss with a
  secondary Law-3 footgun layer (operator picking the "safe rewire" tool onto a haircutting target is
  surprised). Faithfulness break of AC-1 "crediting each user the exact principal parked for them"
  (`InPlaceMigrator.sol:168-169`).
- **Preliminary severity hint:** **Medium**, conditional on the deployed re-injection strategy class.
  Escalates toward **High** if a market/AMM strategy can realistically be the in-place target and the
  re-injected principal is large; drops to **Low/informational** if the operator only ever wires a
  par/above-par strategy in place. Severity-classifier + sanitizer must fix this against the intended
  strategy and against the documented "sub-amount differences remain protocol-owned" rule (which
  covers the *exit*-leg surplus direction, NOT this deposit-leg user-loss direction).
- **Preserved detail:** CODE-12-01 and ECON-12-01 carry the most complete mechanism + quantification;
  F-12-001 carries the Law-1-override / AC-1 spec-break framing; the Tier-3 invariant is the proof.

---

### DEDUP-12-002 — Poison/zero-credit user reverts the whole `migrateIn` slice (story-011 `require(credited>0)` interaction); migration-availability DoS, principal recoverable via timeout

- **Canonical ID:** DEDUP-12-002
- **Merged source-tags:** CODE-12-02 = F-12-003 = SA-002 = SURFACE-2 (PM-12-02 ordering half is the
  *separate* safe-fail item, see "Refuted/folded" below)
- **Root-cause class:** non-atomic per-user external call in an all-or-nothing loop (no per-user try/catch)
- **Location:**
  - `src/InPlaceMigrator.sol:207-224` (per-user loop, no isolation)
  - `src/InPlaceMigrator.sol:223` (`staker.depositFor`, reverts bubble up)
  - `src/StableStaker.sol:632` (`require(credited > 0, "StableStaker: nothing credited")` — story-011 guard)
- **One-line statement:** if any single parked user's `amt` haircuts to zero credit on the new
  strategy (dust + haircut), that user's `depositFor` reverts and the entire `migrateIn` slice
  reverts; the operator must re-page around the poison user, who stays parked until `claimTimedOut`
  (`InPlaceMigrator.sol:239-256`) returns their principal.
- **Proof status:** **CONFIRMED-by-read** (mechanism verified end-to-end; likelihood depends on a
  genuinely high-slippage strategy producing zero credit on a dust position — needs the same
  haircutting strategy as DEDUP-12-001).
- **Condition / precondition:** same haircutting-strategy precondition as DEDUP-12-001, plus a
  dust-sized parked position that rounds to zero credit. Tightly coupled: if the re-injection target
  is par-preserving, both DEDUP-12-001 and DEDUP-12-002 collapse.
- **Harm / law:** availability of the migration only; **no permanent principal loss** (claimTimedOut
  recovers). Law-1 (availability) + Law-3 (footgun).
- **Preliminary severity hint:** **Low–Medium** (availability of a migration function under a
  realistic dust/haircut condition; no theft, principal always recoverable). Lean Low unless the
  intended strategy is shown to produce zero-credit on plausible positions.
- **Preserved detail:** CODE-12-02 carries the fullest mechanism + the `claimTimedOut` recovery proof.

---

### DEDUP-12-003 — Underwater-migration operator footgun: running the in-place "rewire" flow on an impaired (R<P) strategy silently realizes the socialized haircut

- **Canonical ID:** DEDUP-12-003
- **Merged source-tags:** ECON-12-02 = F-12-002 (+ SURFACE-3 underwater-balance discussion)
- **Root-cause class:** non-obvious operator footgun (Law 3) over faithful `min(R,P)/P` socialization
- **Location:**
  - `src/InPlaceMigrator.sol:153` (`parked[...] += amt`, where `amt = p_i·min(R,P)/P`)
  - `src/StableStaker.sol:527-528` (`_exitPosition` caps credit at `p_i·R/P` when `R<P`)
- **One-line statement:** `initiateMigration` is deliberately not blocked on an underwater strategy;
  running the in-place flow (framed as a "safe dependency swap") on an impaired pool realizes and
  socializes the underwater delta `p_i·(1 − R/P)` once, faithfully to the staker's documented
  socialization, but with no migrator-side signal — surprising an operator who reached for the tool
  expecting loss-neutral behaviour.
- **Proof status:** **CONFIRMED-by-read** (faithful to story-003/004 socialization; the *behaviour*
  is intended, the *tool-choice surprise* is the footgun).
- **Condition / precondition:** operator runs `initiateMigration` on a below-par (`R<P`) old strategy.
- **Harm / law:** the loss itself is intended and correctly socialized (not a new bug); Law-3
  operational hazard only. Compounds with DEDUP-12-001 if the new strategy *also* haircuts (two
  sequential haircuts), but that second haircut is DEDUP-12-001, not a new finding.
- **Preliminary severity hint:** **Low** (operational hazard / safe-config guidance: only run the
  in-place flow on an at/above-par strategy; check `withdrawDisabled`/`_isUnderwater` first).
- **Preserved detail:** F-12-002 carries the AC-1 "made-whole" framing; ECON-12-02 carries the
  "no double-haircut / no arbitrage on a par target" refutation and the compounding note.

---

### DEDUP-12-004 — Revived-pool permissionless-stake window before `migrateIn` (first-depositor / interloper): no principal theft

- **Canonical ID:** DEDUP-12-004
- **Merged source-tags:** CODE-12-03 = ECON-12-03 = SURFACE-6 = PM-12-MR-02 (first-depositor)
  (+ PM-12-MR-03 sandwich, folded here as no-new-surface)
- **Root-cause class:** single-operator-session assumption unenforced on-chain (interleaving on the transiently-empty revived pool)
- **Location:**
  - `src/StableStaker.sol:593-604` (`finalizeAndReset` → `Active`)
  - `src/StableStaker.sol:289-307` (`stake` permissionless, `whenNotPaused`, requires `Active`)
  - `src/InPlaceMigrator.sol:183` (`migrateIn` is `onlyOwner`)
- **One-line statement:** after `finalizeAndReset` the empty pool is `Active` and `stake` is
  permissionless again before the operator runs `migrateIn`; an interloper can stake first, but
  reward accounting is a MasterChef accumulator (not a `totalAssets`-derived share price), so there
  is no first-depositor inflation and each parked user's `depositFor` credits *their own* `amt` to
  *their own* `userInfo` — the only effect is emission-share dilution, not principal theft.
- **Proof status:** **REFUTED** (as an exploit; both Tier-2 agents independently disproved
  inflation, rate-manipulation, and sandwich-of-re-injection vectors).
- **Condition / precondition:** operator does not pause-wrap the out→reset→rewire→in session.
- **Harm / law:** emission-rate dilution only; Law-3 footgun-flavored.
- **Preliminary severity hint:** **Low/QA** operational note — recommend wrapping the whole
  out→reset→rewire→in session in pause/unpause (both `finalizeAndReset` and `depositFor` run while
  paused) to close the permissionless-stake window.
- **Preserved detail:** ECON-12-03 carries the three-vector refutation; CODE-12-03 the MasterChef-vs-ERC4626 reasoning.

---

### DEDUP-12-005 — Near-`MIN_TIMEOUT` multi-batch self-exit: short `migrationTimeout` on a multi-batch job leaves a partially-refilled pool

- **Canonical ID:** DEDUP-12-005
- **Merged source-tags:** ECON-12-04 = SURFACE-4 (+ SA-004 timestamp-dependence lead)
- **Root-cause class:** operator footgun (Law 3) — timeout sized below the multi-batch migration duration
- **Location:**
  - `src/InPlaceMigrator.sol:242-245` (`claimTimedOut` time-gate)
  - `src/InPlaceMigrator.sol:210` (`migrateIn` skips `amt==0` self-exited users)
- **One-line statement:** if the operator deploys with `migrationTimeout` near `MIN_TIMEOUT` (1 day)
  and the rewire stalls past it, parked users can `claimTimedOut` mid-migration; the later
  `migrateIn` slice then skips them (`amt==0 → continue`), leaving a partially-refilled pool — no
  value lost (users took principal and self-exited), only migration completeness.
- **Proof status:** **CONFIRMED-by-read** (emission-cap integrity and no profitable force-timeout
  incentive were separately REFUTED; this completeness footgun is the only residual).
- **Condition / precondition:** `migrationTimeout` set near `MIN_TIMEOUT` AND a many-batch /
  long-running job (which the contract docs explicitly scope OUT, `InPlaceMigrator.sol:54-55`).
- **Harm / law:** migration completeness only; Law-3 operational hazard.
- **Preliminary severity hint:** **Low** — size `migrationTimeout` comfortably above the expected
  full out→reset→in duration (the doc's 7-day default is sound for the intended single session).
- **Preserved detail:** ECON-12-04 carries the emission-cap-preserved + no-double-count proof and the incentive analysis.

---

## Refuted / folded / dropped (with reason)

| Source-tag(s) | Disposition | Reason |
|---|---|---|
| CODE-12-04, SA-001, SA-003, PM-12-MR-01 | **DROPPED** (refuted) | Cross-contract reentrancy / CEI: strict effects-before-interaction under dual `nonReentrant`, immutable trusted staker, in-scope tokens not ERC777. Sound; not a finding. (`rescueERC20` missing guard is fenced below `totalParked` — acceptable.) |
| CODE-12-02b, PM-12-02 (ordering half) | **FOLDED → noted** | Early `migrateIn` before `finalizeAndReset` reverts cleanly (`poolState != Active`) — benign safe-fail, minor Law-3 footgun (no friendlier revert). Not a vulnerability; subordinate operational note, not a standalone finding. |
| PM-12-MR-03 | **FOLDED → DEDUP-12-001** | Sandwich/missing-slippage on the rewire: the migrator performs no swap; the slippage exposure lives in the strategy and is already the deposit-leg haircut of DEDUP-12-001. `migrateIn` is `onlyOwner` and atomic, so no insertion between `_pullToken` and `strategy.deposit`. |
| PM-12-MR-04 | **DROPPED** (no-match) | UNSAFE-DOWNCAST / DIVISION-PRECISION: the migrator has no casts and no division; the only division is the audited multiply-before-divide `_exitPosition`. No new surface. |
| SA-005, SA-006 | **DROPPED** (tool noise) | `nonReentrant`-not-first-modifier (harmless — `onlyOwner` makes no external call) and costly-storage-in-loop (operator-paginated, off-chain batched). Style/gas, no security impact. |
| SA-008 | **DROPPED** (OOS context) | `StableStakerMigrator.migrate` event-ordering reentrancy: pre-existing context contract, trusted stakers, not a story-012 change. |
| SA-009 | **DROPPED** (Law-3 obvious) | Missing zero-address checks on StableStaker owner setters: obvious owner misconfig, not a non-obvious footgun. The migrator's own constructor *does* guard the staker address + timeout bounds. |
| All 89 Semgrep, OZ `Math.sol` FPs, `missing-inheritance`, EnumerableSet `unused-return`, `uninitialized-local`, PUSH0/pragma/centralization | **DROPPED** (deterministic noise) | Already filtered by the static pass (189 raw → 9 normalized); none survive the three-law hierarchy. |

## Carryover note (NOT a run-12 finding)

- **SA-007** — `StableStaker.sol:786` (`relinquishPrincipal` inside `setYieldStrategy`): **pre-existing
  context code**, gated by `totalStaked == 0`, not introduced by story-012. This is the line flagged
  in ledger memory as the live **F-03 integration gate** (stable-staker M-05 ↔ reflax-yield-vault
  pending `relinquishPrincipal` story). **Carry to ledger reconciliation as a re-eval prompt for the
  sanitizer/finding-manager, NOT as a new run-12 finding.**

---

## Summary table

| Canonical ID | One-line title | Merged tags | Location | Proof | Severity hint |
|---|---|---|---|---|---|
| DEDUP-12-001 | Re-injection haircut → silent per-user principal loss | CODE-12-01 / ECON-12-01 / F-12-001 / PM-12-01 / SURFACE-1 | InPlaceMigrator.sol:215-223; StableStaker.sol:630-634 | **PROVEN-PoC** | **Medium** (→High if market target / large; →Low if par-only) |
| DEDUP-12-002 | Poison zero-credit user reverts whole `migrateIn` slice | CODE-12-02 / F-12-003 / SA-002 / SURFACE-2 | InPlaceMigrator.sol:207-224; StableStaker.sol:632 | CONFIRMED-by-read | **Low–Medium** (availability; principal recoverable) |
| DEDUP-12-003 | Underwater-migration operator footgun (faithful socialization) | ECON-12-02 / F-12-002 / SURFACE-3 | InPlaceMigrator.sol:153; StableStaker.sol:527-528 | CONFIRMED-by-read | **Low** (operational hazard) |
| DEDUP-12-004 | Revived-pool permissionless-stake window — no theft | CODE-12-03 / ECON-12-03 / SURFACE-6 / PM-12-MR-02 | StableStaker.sol:593-604, 289-307; InPlaceMigrator.sol:183 | **REFUTED** | **Low/QA** (pause-wrap recommendation) |
| DEDUP-12-005 | Near-`MIN_TIMEOUT` multi-batch self-exit | ECON-12-04 / SURFACE-4 / SA-004 | InPlaceMigrator.sol:242-245, 210 | CONFIRMED-by-read | **Low** (timeout-sizing guidance) |
| — (reentrancy) | Cross-contract reentrancy / CEI | CODE-12-04 / SA-001 / SA-003 / PM-12-MR-01 | InPlaceMigrator.sol:215-223 | **REFUTED — DROPPED** | none |
| — (carryover) | StableStaker.sol:786 relinquishPrincipal | SA-007 | StableStaker.sol:786 | pre-existing context | ledger F-03 re-eval, not a finding |

## Counts

- Input items across 6 scans: ~22 tagged items (CODE x4, ECON x4, F x3, PM x2 + 4 MR, SA x9, SURFACE x6) plus 89 Semgrep + OZ FPs.
- **Canonical findings out: 5** (1 PROVEN-PoC live, 1 availability, 3 Low footguns; one of the five is itself a refuted-exploit Low/QA note).
- Dropped as refuted: 1 cluster (reentrancy/CEI).
- Dropped as noise / OOS / Law-3-obvious: SA-005/006/008/009, PM-12-MR-04, all Semgrep + OZ FPs.
- Folded: CODE-12-02b/PM-12-02-ordering (safe-fail note), PM-12-MR-03 (→001).
- Carryover note: SA-007 (ledger F-03 re-eval).

## Flags for human / downstream review

- **DEDUP-12-001 severity is precondition-bound.** The Medium↔High↔Low spread hinges on the actual
  re-injection strategy class the operator intends to wire in place. Sanitizer + severity-classifier
  must resolve this against the deployment intent (memory: M-07 AMM-execution-slippage lineage,
  setYieldStrategy empty-pool-gate notes) before a label is fixed. The PoC proves the mechanism; it
  does not prove the operator will wire a haircutting strategy.
- **DEDUP-12-002 is conjoined to DEDUP-12-001's precondition** — do not let the sanitizer drop one
  while keeping the other inconsistently; they collapse together on a par-preserving target.
- **SA-007 / StableStaker.sol:786** must reach the finding-manager as the F-03 ledger re-eval prompt
  even though it is excluded from the run-12 finding set.
