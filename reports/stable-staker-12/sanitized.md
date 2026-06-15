# Sanitized + Reconciled Finding Set — stable-staker run-12

- **Project:** stable-staker
- **Run:** stable-staker-12 (REGRESSION)
- **Submodule HEAD:** `ffa494783f585bcd2ce1ff60dd756345717287f1` — `[story-012] Add InPlaceMigrator`
- **Baseline `lastAuditedCommit`:** `c3ec65bf0115e9bcc0a75f705a1c8cb57b32ce94` (run-11)
- **New contract under test:** `src/InPlaceMigrator.sol` (+316 LOC)
- **Known-issues source:** `lib/stable-staker/CLAUDE.md` (9 KIs + 7 design decisions, per registered-projects.json)
- **Ledger:** `reports/ledgers/stable-staker.json` (21 entries)
- **Fingerprint scheme:** `sha256(contract:function:rootCauseClass[:entryPoint])`. InPlaceMigrator
  is a NEW entry point: `contract:function` keys on `src/InPlaceMigrator.sol:migrateIn`, so these
  findings reconcile per-entry-point and cannot collide with prior `StableStaker.*` findings.
- **Timestamp:** 2026-06-15

---

## TASK 1 + 2 — Known-issue suppression + ledger reconciliation, per finding

### DEDUP-12-001 — Re-injection haircut: `migrateIn` zeroes parked by requested `amt`, `depositFor` credits the strategy haircut return → silent per-user principal loss

- **Verdict: KEEP. New ledger entry. NOT a regression of `969722dc` (M-07), NOT a duplicate of refuted `b806f400`.**
- **Proposed fingerprint preimage:**
  `src/InPlaceMigrator.sol:migrateIn:yield-principal-accounting-skew-deposit-leg`
  - `contract` = `src/InPlaceMigrator.sol`, `function` = `migrateIn`, `rootCauseClass` =
    `yield-principal-accounting-skew-deposit-leg` (re-injection haircut), `entryPoint` = `null`
    (this is a contract-scan finding, not a `/audit-script` finding — the migrator IS the contract,
    so no script-entry-point discriminator).
- **`relatedTo` / lineage cross-references (record on the new entry):**
  - `relatedTo: 969722dc` (M-07) — same *root-cause class* (rate/requested-vs-execution/credited
    deposit slippage), relocated from `StableStaker.setYieldStrategy` (in-place swap leg) to
    `InPlaceMigrator.migrateIn` (re-injection deposit leg). M-07's empty-pool gate "fixed" it by
    FORBIDDING in-place swaps; story-012 RE-ENABLES in-place migration through a different door and
    the slippage residual reappears on the deposit leg.
  - `relatedTo: dab5a656` (M-01) — sibling "discarded deposit-credit / stale principal accounting"
    skew on `setYieldStrategy`'s idle-sweep; same family, distinct location/function.
  - `crossRef: b806f400` (ss10f-econ001, **false-positive**) — superficially "the depositFor
    re-entry side haircut," but `b806f400` was REFUTED as an *inter-migrant batch-ordering credit
    asymmetry* (credit is a pre-swap pure function of input; identical-principal migrants get
    identical credit). DEDUP-12-001 is a DIFFERENT mechanism: the migrator zeroes `parked`/
    `totalParked` by the **requested** `amt` (L215-217) while `depositFor` records only `credited <
    amt` (L631-637), so the lost `amt − credited` is irrecoverable with no residual parked and no
    event. **`b806f400`'s refutation does NOT cover this — do NOT auto-suppress under it.**
- **Known-issue check (each candidate, explicitly):**
  - **KI#5** ("Exits forward the ACTUAL received amount … sub-amount differences remain
    protocol-owned yield/loss") — DOES NOT APPLY. KI#5 governs the **exit** direction (a *surplus*
    the protocol keeps). DEDUP-12-001 is a **deposit-leg user LOSS** direction: the user's parked
    principal is zeroed by `amt` but only `credited` lands in their `userInfo`; the gap is a user
    deficit, not protocol-owned surplus. The deduplicator already flagged this exact distinction.
    **Not suppressed by KI#5.**
  - **KI#6** (underwater buffer FCFS at par, `69c7666e` wont-fix) — DOES NOT APPLY. Per memory, KI#6
    is `_routeExit`-scoped FCFS socialization and must NOT be used to bless a new vector. This is a
    deposit-leg per-user loss, not a withdraw-path FCFS socialization. **Not suppressed.**
  - **KI#7 / empty-pool-gate design decision** ("replacing an in-use strategy does not auto-migrate;
    replace only while `totalStaked==0`") — DOES NOT APPLY as a suppression. The empty-pool gate is
    exactly what `migrateIn` works *within* (it re-injects into a revived empty pool), so the gate is
    satisfied, not violated. The gate closed M-07 by forbidding in-place swaps; story-012 provides a
    sanctioned in-place migration path, and the slippage residual rides the re-injection deposit. The
    gate does not bless deposit-leg principal loss. **Not suppressed.**
- **Ledger fingerprint reconciliation (the critical one):**
  - **This is a NEW ledger entry (distinct fingerprint), NOT a reappearance of `969722dc`.** The
    fingerprint differs on `contract:function` (`InPlaceMigrator.migrateIn` vs
    `StableStaker.setYieldStrategy`) and on `rootCauseClass` (deposit-leg accounting skew vs
    setYieldStrategy rate-vs-execution-residual). No fingerprint match against any ledger entry.
  - **REGRESSION vs NEW verdict — this is a NEW finding, *flagged with regression-flavoured lineage*,
    not a mechanical ledger regression.** A mechanical regression requires the *same fingerprint* of a
    `fixed` entry reappearing. `969722dc` is **`acknowledged`** (with a *proposed*-fixed @125f585
    pending human confirmation), not `fixed`, and the fingerprint differs — so it does not satisfy the
    `regressionOf` rule. BUT the *protection* that retired M-07 (the empty-pool gate forbidding
    in-place swaps) is logically circumvented by story-012's new in-place migration door, and the
    same economic harm (slippage shortfall on a haircutting strategy) returns. **Recommend: classify
    `origin: "new"`, set `relatedTo: ["969722dc","dab5a656"]`, and FLAG PROMINENTLY in the report as a
    "mitigation-circumvention / vector-revival" — the empty-pool gate's premise ('no in-place swap on
    a live pool') is structurally re-opened by a different mechanism.** This is the highest-signal
    finding of the run and must not be diluted by the lineage framing.
  - **Do NOT set `regressionOf`** (no `fixed` same-fingerprint ancestor). Use `relatedTo` for the
    lineage instead — this keeps the ledger's regression semantics honest while still surfacing the
    circumvention story to the human.
- **Severity (carried for severity-classifier):** precondition-bound Medium (→High if a market/AMM
  re-injection strategy is realistically wired in place with large principal; →Low/informational if
  only par/above-par strategies are ever wired). Proof: Tier-3 invariant PROVEN-PoC (8e6 lost on
  400e6 @ 200 bps; fuzzed 1–500 bps; 0 bps par-preserving case clean). **High-severity caution rule
  applies — keep, do not remove; let severity-classifier + human fix the label against deployment
  intent (memory: M-07 AMM-execution-slippage lineage, no-in-place-swap operational rule).**

### DEDUP-12-002 — Poison/zero-credit user reverts the whole `migrateIn` slice (story-011 `require(credited>0)` interaction); migration-availability DoS, principal recoverable via timeout

- **Verdict: KEEP. New ledger entry. NOT a duplicate of `59eebbf8` (unbounded loop) nor of
  `eae10d60` (depositFor missing guard, fixed).**
- **Proposed fingerprint preimage:**
  `src/InPlaceMigrator.sol:migrateIn:nonatomic-per-user-deposit-loop-dos`
  - `rootCauseClass` = `nonatomic-per-user-deposit-loop-dos` (no per-user try/catch; one revert
    reverts the whole slice). `entryPoint` = `null`.
- **Duplicate checks (Task 3, explicit):**
  - **`59eebbf8`** ("Unbounded per-user external-call loop in batchMigrate + StableStakerMigrator.
    migrate") — NOT a duplicate. `59eebbf8` is keyed on `StableStaker.batchMigrate` and is a *gas/
    unbounded-iteration* DoS (too many users in one call). DEDUP-12-002 is keyed on
    `InPlaceMigrator.migrateIn` and is an *atomicity* DoS (one poison user with zero-credit reverts
    the whole slice via the `require(credited>0)` guard), independent of slice length. Distinct
    contract:function AND distinct rootCauseClass → distinct fingerprint. The migrator IS paginated
    (operator-batched), so the unbounded-loop concern (`59eebbf8`) does not even recur here — the
    deduplicator correctly dropped SA-005/006 gas noise. **Keep separate; cross-ref `59eebbf8`.**
  - **`eae10d60`** ("depositFor missing require(credited>0) guard", **fixed** @ c3ec65b / story-011) —
    NOT a duplicate, and importantly the *opposite* relationship: DEDUP-12-002 is a *consequence of
    the eae10d60 fix existing*. story-011 ADDED `require(credited>0)` at StableStaker.sol:632
    precisely to stop phantom zero-credit stakers; that guard now means a zero-credit re-injection
    *reverts* instead of silently inserting a phantom. The new contract `InPlaceMigrator.migrateIn`
    calls `depositFor` in an all-or-nothing loop, so the guard's revert propagates to the whole
    slice. The root cause is the migrator's non-atomic loop, NOT the (correctly-fixed) guard.
    **`eae10d60` is `fixed`, not reappearing — no regression; DEDUP-12-002 is a new interaction
    finding on the new contract. Cross-ref `eae10d60` + `8d5ceff2` (ss10m1) for the guard lineage.**
  - **`ss10m1` (`8d5ceff2`, fixed)** — NOT a duplicate. ss10m1 was the *phantom-staker-bricks-
    finalizeAndReset* escalation of the missing guard, fixed by story-011. DEDUP-12-002 is the
    inverse-side effect of the guard now existing. Distinct.
- **Ledger reconciliation:** no fingerprint match → `origin: "new"`.
- **Conjoined-precondition flag (carry to severity-classifier):** DEDUP-12-002 collapses together
  with DEDUP-12-001 on a par-preserving target (both require a haircutting re-injection strategy).
  Do not suppress one while keeping the other inconsistently. Severity hint Low–Medium (availability
  only; principal recoverable via `claimTimedOut`). Keep.

### DEDUP-12-003 — Underwater-migration operator footgun (faithful `min(R,P)/P` socialization realized via the in-place flow)

- **Verdict: KEEP as Low operational hazard (Law-3 non-obvious footgun). Partially touches KI#6 but
  NOT suppressed by it.**
- **Proposed fingerprint preimage:**
  `src/InPlaceMigrator.sol:initiateMigration:underwater-flow-realizes-socialized-haircut`
  - `rootCauseClass` = `underwater-flow-realizes-socialized-haircut`. `entryPoint` = `null`.
- **Known-issue check:**
  - The *socialization itself* (`p_i·min(R,P)/P` when `R<P`) is intended/faithful (story-003/004,
    documented in CLAUDE.md terminal-migration section) — that behaviour is NOT a finding and is
    correctly NOT reported as a bug. What IS kept is the **tool-choice surprise**: an operator
    reaching for an in-place "rewire" tool, expecting loss-neutral behaviour, silently realizes the
    underwater delta with no migrator-side signal. Per CLAUDE.md Law-3, a *non-obvious* footgun is in
    scope. The competent non-malicious owner would be surprised → keep.
  - **KI#6 / `69c7666e`** does NOT bless this — KI#6 is `_routeExit` buffer-at-par FCFS; this is the
    terminal-migration `min(R,P)/P` pro-rata socialization (a *different*, intended path) surfaced as
    an operator footgun on a different entry point. Cross-ref `69c7666e` (distinct).
- **Ledger reconciliation:** no fingerprint match → `origin: "new"`. Severity hint Low (safe-config
  guidance: check `withdrawDisabled`/`_isUnderwater` before running the in-place flow). Keep.

### DEDUP-12-004 — Revived-pool permissionless-stake window before `migrateIn` (REFUTED as theft; Low/QA pause-wrap note)

- **Verdict: KEEP as Low/QA operational note. Related to `ss9l1` and `ss10l1` (same revival-runbook
  surface) but DISTINCT root cause — flag as related, do not merge or suppress.**
- **Proposed fingerprint preimage:**
  `src/StableStaker.sol:finalizeAndReset:revived-pool-permissionless-stake-window`
  - NOTE: this finding's *primary surface* is `StableStaker.finalizeAndReset` → `Active` +
    permissionless `stake`, with the migrator's `onlyOwner migrateIn` as the timing counterpart.
    `rootCauseClass` = `revived-pool-permissionless-stake-window-emission-dilution`. `entryPoint` =
    `null`.
- **Duplicate checks (Task 3, explicit):**
  - **`ss9l1`** (finalizeAndReset revival stale-emission-rate footgun, **open** Low) — NOT a
    duplicate. `ss9l1` is "revived pool resumes on stale `phusdPerSecond`/strategy settings."
    DEDUP-12-004 is "the revived pool is permissionlessly stakeable before `migrateIn`, diluting
    emission share." Same `finalizeAndReset` revival surface, DIFFERENT root cause (stale-config vs
    interloper-stake-window). Distinct rootCauseClass → distinct fingerprint. **Keep separate;
    cross-ref `ss9l1`.**
  - **`ss10l1`** (`787e9fac`, dust-stake grief of the empty-pool gate, **submitted-qa** Low) — NOT a
    duplicate but VERY adjacent: ss10l1 is "a 1-wei stake between finalizeAndReset and setYieldStrategy
    flips the gate, forcing a re-migration." DEDUP-12-004 is "a stake between finalizeAndReset and
    migrateIn dilutes emissions." Both are permissionless-stake-window-on-revived-pool footguns with
    the **same recommended mitigation (pause-wrap the out→reset→rewire→in session)**. They are
    distinct root causes (gate-grief vs emission-dilution) but the human should consider bundling them
    in the QA report under one "revival-window pause-wrap" recommendation. **Keep separate; cross-ref
    `ss10l1` (and `ss9l1`); flag the bundling opportunity to qa-bundler.**
- **Ledger reconciliation:** no fingerprint match → `origin: "new"`. REFUTED as an exploit (no
  first-depositor inflation — MasterChef accumulator, not share-price); surfaced as Low/QA. Keep
  (Law 1: refuted-exploit dispositions stay in a visible channel, not dropped silently).

### DEDUP-12-005 — Near-`MIN_TIMEOUT` multi-batch self-exit leaves a partially-refilled pool

- **Verdict: KEEP as Low operational hazard (timeout-sizing footgun). NOT suppressed; NOT a
  duplicate.**
- **Proposed fingerprint preimage:**
  `src/InPlaceMigrator.sol:claimTimedOut:short-timeout-multibatch-partial-refill`
  - `rootCauseClass` = `short-timeout-multibatch-partial-refill`. `entryPoint` = `null`.
- **Known-issue check:** none apply. The contract docs (InPlaceMigrator.sol:54-55) scope OUT
  many-batch/long-running jobs, but that scoping is a *recommendation*, not a documented known issue,
  and the footgun is exactly that a near-`MIN_TIMEOUT` config + a stalled multi-batch job violates the
  documented single-session assumption silently. Non-obvious owner footgun → in scope (Law 3). Keep.
- **Ledger reconciliation:** no fingerprint match → `origin: "new"`. Severity hint Low (size
  `migrationTimeout` above the full out→reset→in duration; 7-day default is sound). Keep.

---

## Suppressed / dropped this run (audit trail)

| Item | Disposition | Reason |
|---|---|---|
| (reentrancy cluster) CODE-12-04 / SA-001 / SA-003 / PM-12-MR-01 | DROPPED (already by deduplicator) | Refuted: strict CEI under dual `nonReentrant`, immutable trusted staker, in-scope non-ERC777 tokens. Sound. |
| SA-008 (`StableStakerMigrator.migrate` event-ordering) | DROPPED (already by deduplicator) | Pre-existing context contract, trusted stakers, not a story-012 change. OOS-context. |
| SA-009 (missing zero-addr checks on StableStaker owner setters) | DROPPED (already by deduplicator) | Law-3 *obvious* owner misconfig (the migrator's own constructor guards staker+timeout). Not a non-obvious footgun. |
| SA-005/006, PM-12-MR-04, 89 Semgrep, OZ Math FPs | DROPPED (already by deduplicator) | Deterministic tool noise / gas-style; no security impact under the three-law hierarchy. |
| `b806f400` (ss10f-econ001) as a suppressor of DEDUP-12-001 | NOT APPLIED | `b806f400` is a `false-positive` for a DIFFERENT mechanism (inter-migrant batch-ordering credit asymmetry, refuted). DEDUP-12-001's deposit-leg principal-loss mechanism is not covered by that refutation. Recorded so DEDUP-12-001 is NOT auto-suppressed. |

**No DEDUP-12-00X finding was suppressed by a known issue or by the ledger.** All 5 pass through as
`new`. (Per the CRITICAL RULE "when in doubt, keep" and the High-severity caution rule, the
precondition-bound DEDUP-12-001 in particular is kept for human/severity-classifier resolution.)

---

## TASK 4 — Carryover obligations (re-eval state; NO status auto-flips)

The InPlaceMigrator change (story-012) is a NEW-contract addition. It does **not** touch
`StableStaker.setYieldStrategy`, `_routeExit`, `emergencyWithdraw`, or `relinquishPrincipal`
internals. Therefore the pre-existing entries below are **NOT re-verified by this scoped change** and
must carry over UNCHANGED for human `/ledger` triage. Each gets a thin carryover stub (finding-manager
→ CARRYOVER STUBS) EXCEPT entries already triaged by the human (`acknowledged`/`wont-fix`/`fixed`/
`false-positive` get no stub; `open`/`submitted`/`submitted-qa` get a stub).

### F-03 / SA-007 re-eval prompt (`StableStaker.sol:786` relinquishPrincipal)

- **State:** SA-007 was carried by the deduplicator as a **non-finding ledger note** (pre-existing
  context code, gated by `totalStaked==0`, NOT introduced by story-012). It is the line memory flags
  as the live **F-03 integration gate** (stable-staker M-05 ↔ reflax-yield-vault pending
  `relinquishPrincipal` story).
- **Reconciliation:** The InPlaceMigrator change does NOT affect `relinquishPrincipal`'s status.
  `relinquishPrincipal` already LANDED (story-007, consumed by `_routeExit`/withdraw); the residual
  F-03 obligation is whether `emergencyWithdraw` has been made pro-rata (the `M-05` `0dca43f3`
  dependency). story-012 does not touch `emergencyWithdraw`. **Carry SA-007 to finding-manager as the
  F-03 ledger re-eval prompt; NOT a run-12 finding. No status change.**

### The 5 acknowledged/triaged Mediums with proposed-fixed @125f585 (pending human confirmation)

| Ledger entry | Authoritative status | Proposed | Affected by story-012? | Action |
|---|---|---|---|---|
| `3d61c955` (M-01, underwater-migration bricked) | `acknowledged` | proposed `fixed` @ f5f6039 (recheck LIKELY-FIXED) | No | Carry UNCHANGED. Proposal still PENDING human `/ledger`. No stub (acknowledged). |
| `dab5a656` (M-01, idle-pool adoption discards credited) | `acknowledged` | proposed `fixed` @ 125f585 (empty-pool gate) | No | Carry UNCHANGED. Proposal PENDING. No stub (acknowledged). **Note: DEDUP-12-001 is the deposit-leg sibling of this family — cross-ref via `relatedTo`.** |
| `dbdc3ac9` (M-06, underwater-swap re-arms withdraw) | `acknowledged` | proposed `fixed` @ 125f585 (empty-pool gate subsumes) | No | Carry UNCHANGED. Proposal PENDING. No stub (acknowledged). |
| `969722dc` (M-07, rate-vs-execution residual) | `acknowledged` | proposed `fixed` @ 125f585 (empty-pool gate) | **Indirectly — see below** | Carry UNCHANGED. Proposal PENDING. No stub (acknowledged). **DEDUP-12-001 is the cross-referenced revival of this vector via the new in-place door — `relatedTo`.** |
| `678e6fa2` (M-02, missing !active guard) | `fixed` (story-006) | — (realized) | No | No action; already `fixed`. No stub. |

- **CRITICAL human-attention flag:** the four `acknowledged` Mediums above all carry a
  *proposed-fixed @125f585* that rests on the **empty-pool gate forbidding in-place strategy swaps**.
  story-012's `InPlaceMigrator` introduces a **sanctioned in-place migration path** that operates
  *within* the empty-pool gate (revive → re-inject). The human, before confirming `/ledger fixed
  969722dc` (and the dab5a656/dbdc3ac9 group), should consider that the *economic vector* M-07
  described (slippage shortfall on a haircutting strategy during an in-place strategy change) is
  **re-expressed by DEDUP-12-001 on the re-injection deposit leg**. The empty-pool-gate "fix" closes
  the `setYieldStrategy` door but not the new `migrateIn` door. **This is the key cross-cutting
  observation of run-12 and must reach the human triage queue (do NOT auto-flip any of these to
  `fixed`).**

### M-05 (`0dca43f3`, emergencyWithdraw FCFS-at-par)

- **State:** `acknowledged`, fix DEFERRED-then-unblocked (reflax `relinquishPrincipal` landed; but
  `emergencyWithdraw` itself is still non-pro-rata). `lastSeenRun` stable-staker-10.
- **Reconciliation:** story-012 does NOT touch `emergencyWithdraw`. Status UNCHANGED, STILL-LIVE / fix
  unblocked-but-unapplied. **Carry UNCHANGED for human `/ledger`. No stub (acknowledged).** Re-check
  obligation persists: has `emergencyWithdraw` been made pro-rata now that `relinquishPrincipal` is
  available? (Unchanged at ffa4947.)

### Other open/submitted carryover entries (stubs owed → finding-manager)

These are `open` / `submitted` / `submitted-qa` (not human-triaged-closed), unrelated to story-012,
and must each get a thin **carryover stub** so they don't silently vanish from `submissions/`:

| Entry | Status | Stub owed |
|---|---|---|
| `0790a76a` (rescueERC20 sweeps buffer, Low) | open | YES |
| `59eebbf8` (unbounded loop, Low) | open | YES (cross-ref DEDUP-12-002 as the distinct migrator-atomicity sibling) |
| `7b071779` (unused EnumerableSet return, info) | open | YES (info) |
| `b5218ab2` (sequential migrateOut AMM haircut, Medium) | submitted | YES (note: CONFIRMED-CLOSED at f5f6039; carry as historical submitted) |
| `4f143a95` (F-01 migration-credit asymmetry, Low) | open | YES |
| `a56f8778` (F-02 withdrawDisabled over-reports, Low) | open | YES |
| `d47619d2` (L-01 phUSDPerDay floor, Low) | open | YES |
| `796f775f` (L-03 initiateMigration CEI, info) | open | YES (info) |
| `ss9l1` (finalizeAndReset revival stale-rate, Low) | open | YES (cross-ref DEDUP-12-004) |
| `ss9f3` (CLAUDE.md doc-lag, Low) | open | proposed-fixed @125f585 PENDING; carry, stub YES |
| `ss10l1` (dust-stake grief of empty-pool gate, Low) | submitted-qa | YES (cross-ref DEDUP-12-004) |
| `ss10q1` (stale NatSpec / dead branch, Low) | submitted-qa | YES |

(No stub for human-closed entries: `69c7666e` wont-fix, `35e9be8d` wont-fix, `e4567dc3` wont-fix,
`dc361b7d` fixed, `eae10d60` fixed, `8d5ceff2` fixed, `b806f400` false-positive, `ss10i1` info-refuted,
and the four acknowledged Mediums above.)

---

## Summary

| Canonical ID | Verdict | origin | Proposed fingerprint preimage | Severity hint |
|---|---|---|---|---|
| DEDUP-12-001 | **KEEP** (flag as M-07 vector-revival) | **new** | `src/InPlaceMigrator.sol:migrateIn:yield-principal-accounting-skew-deposit-leg` | Medium (→High/→Low precondition-bound) |
| DEDUP-12-002 | **KEEP** (conjoined to 001) | new | `src/InPlaceMigrator.sol:migrateIn:nonatomic-per-user-deposit-loop-dos` | Low–Medium |
| DEDUP-12-003 | **KEEP** (Law-3 footgun) | new | `src/InPlaceMigrator.sol:initiateMigration:underwater-flow-realizes-socialized-haircut` | Low |
| DEDUP-12-004 | **KEEP** (Low/QA; refuted-exploit) | new | `src/StableStaker.sol:finalizeAndReset:revived-pool-permissionless-stake-window-emission-dilution` | Low/QA |
| DEDUP-12-005 | **KEEP** (Law-3 footgun) | new | `src/InPlaceMigrator.sol:claimTimedOut:short-timeout-multibatch-partial-refill` | Low |

- **Input findings:** 5 canonical (DEDUP-12-001..005)
- **Suppressed by known issue:** 0
- **Suppressed by ledger (acknowledged/wont-fix/false-positive match):** 0
- **Still-open (same-fingerprint open match):** 0
- **Regressions (same-fingerprint `fixed` reappearance):** 0
- **Passed as `new`:** 5 (all five proceed to classification/reporting)
- **Flagged for human:** DEDUP-12-001 (severity precondition-bound + the M-07/empty-pool-gate
  vector-revival cross-cut); the four acknowledged Mediums' proposed-fixed @125f585 confirmations
  should weigh that DEDUP-12-001 re-expresses the M-07 economic vector through the new in-place door.
- **Carryover obligations:** SA-007/F-03 re-eval prompt + M-05 re-check prompt (no stubs, acknowledged);
  carryover stubs owed for 12 open/submitted entries (listed above). NO status auto-flipped.
