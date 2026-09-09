# Static Analysis — stable-staker (run-13)

- **Project:** stable-staker
- **Scan type:** static (deterministic SAST), regression-scoped
- **Submodule HEAD:** `d95f4a6` (story-013 "surplus-funded re-injection top-up", M-01 haircut fix)
- **Prior audited commit:** `ffa4947` (run-12)
- **In-scope change:** `src/InPlaceMigrator.sol` (+77 LOC: `_reinjectWithTopup`, full-balance `forceApprove`, `Math` import). `StableStaker.sol` / `StableStakerMigrator.sol` are context.
- **Scan timestamp:** 2026-06-15
- **Tools:** Slither 0.11.3 · Aderyn 0.6.8 · Semgrep (p/smart-contracts, 50 rules) · solc 0.8.28
- **Raw outputs:** `slither-output.json`, `aderyn-report.json`, `semgrep-output.json` (this dir)

## Headline

**No new true-positive static finding lands on the story-013 top-up path.** The new
`_reinjectWithTopup` gross-up arithmetic (`Math.mulDiv(amt - credited, amt, credited)`), the
surplus-budget `require`, and the two-leg `depositFor` ordering were specifically inspected for
reentrancy, unchecked arithmetic, rounding, and external-call ordering. The tools surface only
reentrancy detectors that are **false positives** under the existing `nonReentrant` + CEI guards,
plus the usual style/QA noise.

- Slither: 56 raw results (28 unique after de-duplicating the 2x JSON repetition) → **0 actionable** on InPlaceMigrator after filtering.
- Aderyn: 88 detectors → 1 HIGH (reentrancy) on InPlaceMigrator → **false positive**; rest Low/QA.
- Semgrep: 93 findings, all INFO-level performance/style on the 4 in-scope files → **0 actionable**.

No arithmetic-soundness detector (`divide-before-multiply`, `incorrect-exp`, `weak-prng`,
`incorrect-equality`) fires inside `InPlaceMigrator.sol`. The only such hits are in
`lib/openzeppelin-contracts/.../Math.sol` (out of scope, the library's own `mulDiv`/`invMod`).

## Story-013 path — findings that touch the new code

| # | Source | Detector | Loc | Verdict |
|---|--------|----------|-----|---------|
| S-1 | Slither | reentrancy-no-eth | `migrateIn` L202-251 (helper `_reinjectWithTopup`) | **FALSE POSITIVE** — review |
| S-2 | Aderyn | Reentrancy: state change after external call (HIGH) | L165, L225, L226 | **FALSE POSITIVE** — review |
| S-3 | Slither | calls-loop | `_reinjectWithTopup` L262-294 (4 staker calls) | informational (by design) |
| S-4 | Slither | unused-return | `userInfo` tuple destructure L267/269/287; `EnumerableSet.add/remove` | noise (intentional) |
| S-5 | Slither | uninitialized-local | `total`/`count` L167/168/213/229 | noise (default-0 accumulators) |
| S-6 | Slither | timestamp | `claimTimedOut` L309-312 | KEEP-context (time-gated hatch, pre-existing) |
| S-7 | Aderyn | costly-ops-in-loop / loop-contains-require | L169, L230 | QA |
| S-8 | Aderyn | nonReentrant not first modifier | L164, L202 | QA (cosmetic ordering) |
| S-9 | Semgrep | use-custom-error / prefix-increment / state-read-in-loop | many | QA noise (all INFO) |

### S-1 / S-2 — reentrancy on the re-injection path (FALSE POSITIVE, but the load-bearing item)

Both tools flag the new top-up leg. They are wrong for the same structural reason and are
**corroborating** (raises our confidence that this is the one place to manually confirm, not that it
is exploitable).

- **Slither (reentrancy-no-eth):** reports that `parked[token][user]=0`, `delete migrationBegin`,
  and `totalParked -= amt` are "written after" the external `depositFor` calls, and names cross-
  function reentrancy reachability via `claimableAt`, `rescueERC20`, `parked`. This is an artifact of
  Slither inlining the extracted `_reinjectWithTopup` helper back into the loop: in the actual
  source those three effects execute at **L238-241, BEFORE** `_reinjectWithTopup` is invoked at
  **L247**. The loop is strict checks-effects-interactions.
- **Aderyn (HIGH):** L165 = `batchMigrate` then the migrateOut bookkeeping (`parked +=`,
  `totalParked +=`); L225/226 = `balanceOf` / `forceApprove` then the deposit loop. Same pattern —
  external read/approve precedes state writes that are themselves the intended effects.

Why these are not exploitable as reported:
1. `migrateOut`, `migrateIn`, and `claimTimedOut` are all `nonReentrant` — no cross-entry re-entry.
2. The external callees are the **immutable, trusted** `staker` (`depositFor`, `batchMigrate`,
   `userInfo`) plus the staked ERC-20's `balanceOf`/`forceApprove`. The staker is pinned at
   construction (comment block (D)); it is not an attacker-controlled target.
3. The in-loop CEI is correct: `parked`/`migrationBegin`/`totalParked`/set-membership are all
   zeroed/removed (L238-241) before the `depositFor` interaction (L247→helper). A re-entrant pass
   would see `parked == 0` and skip (no double-pay), exactly as the timeout hatch does.
4. The new top-up adds **no new untrusted external call** — both `depositFor` legs and `userInfo`
   reads target the same immutable staker. The surplus `require` reads `balanceOf`/`totalParked`
   after the principal leg, but the value can only be reduced by the staker pulling the scoped
   approval, which is the intended `depositFor` pull.

Residual manual-review note (NOT a static finding, handed to code-scanner/econ-scanner): the
`balanceOf(address(this)) - totalParked[token]` surplus accounting in `_reinjectWithTopup` (L281) and
the full-balance `forceApprove` (L225-226) are the two genuinely new invariants. Static tools can't
reason about whether the *cumulative* per-user top-ups can over-draw the surplus or whether the
grossed-up `mulDiv` can round a user above par at another's expense — that is an economic/rounding
question for Tier-2, not a SAST result. Flagged here so it is visible, not dropped.

### S-3 — calls-loop on `_reinjectWithTopup`

`userInfo`/`depositFor`/`balanceOf` invoked once per parked user inside the `migrateIn` loop. This is
inherent to per-user re-injection and is gas-bounded by the operator-chosen `[start,end)` slice
(designed for small batches per the contract docs). Informational; not a vulnerability.

### S-6 — timestamp on `claimTimedOut` (KEPT, not dropped)

`block.timestamp >= migrationBegin + migrationTimeout` gates the escape hatch. Per the suite policy
(time-driven protocol) timestamp findings are retained for downstream triage rather than filtered.
Pre-existing (not introduced by story-013); the `MIN_TIMEOUT`/`MAX_TIMEOUT` bounds (≥1d, ≤30d) make
miner timestamp nudging immaterial. Low/context.

## Context-contract notes (StableStaker.sol — unchanged, surfaced for completeness)

- `reentrancy-no-eth` / `reentrancy-events` on `setYieldStrategy` (L219-271) via `_routeExit` →
  `relinquishPrincipal`/`withdraw` then `deposit` — pre-existing, tied to the empty-pool-gated rewire
  (ledger context, not new in run-13).
- `timestamp` on `_updatePool`, `pendingReward`, `_routeExit`, `finalizeAndReset` — load-bearing
  emission-accrual time logic; kept per policy, all pre-existing.

## Filtered as noise (whole-project)

Dropped per agent filter list and C4 known-invalid conventions:
`unused-return` (tuple destructures + EnumerableSet bool returns), `uninitialized-local`
(default-0 accumulators), `too-many-digits` / `incorrect-exp` / `divide-before-multiply` (all in
OZ `Math.sol`, out of scope), Semgrep `use-custom-error-not-require`, `use-prefix-increment-not-postfix`,
`state-variable-read-in-a-loop`, `use-short-revert-string`, `non-payable-constructor`,
`use-ownable2step`, `array-length-outside-loop`, Aderyn `PUSH0`, `Unspecific Solidity Pragma`,
`Centralization Risk` (owner-trusted by Law 3), `Modifier Invoked Only Once`,
`nonReentrant is Not the First Modifier`, `Costly operations inside loop`,
`Address State Variable Set Without Checks` (constructor zero-checks already present).

## Tool corroboration summary

| Detector class | Slither | Aderyn | Semgrep | Net verdict |
|---|---|---|---|---|
| Reentrancy on migrateIn/_reinjectWithTopup | reentrancy-no-eth | HIGH reentrancy | — | corroborated **false positive** (nonReentrant + CEI + immutable trusted staker) |
| New top-up arithmetic soundness | clean | clean | clean | no static signal; deferred to econ/rounding review |
| Style/QA | unused-return, uninit-local | PUSH0, pragma, centralization | 93 perf/style | all filtered |

**Bottom line for the orchestrator:** static analysis adds **no new High/Medium** on the story-013
change. The single thing worth a human glance — the surplus-budget + gross-up math in
`_reinjectWithTopup` — is invisible to SAST and has been parked as an explicit manual-review note
above (Law 1: visible channel, not a dropped log).
