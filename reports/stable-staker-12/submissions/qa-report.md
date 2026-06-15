# QA Report for stable-staker (run-12)

- **Project:** stable-staker
- **Run:** stable-staker-12 (REGRESSION)
- **Submodule HEAD:** `ffa494783f585bcd2ce1ff60dd756345717287f1` — `[story-012] Add InPlaceMigrator`
- **New contract under test:** `src/InPlaceMigrator.sol` (+316 LOC)
- **Date:** 2026-06-15

This report bundles all Low / QA findings for run-12. The single Medium of this run
(`M-01`, the re-injection haircut principal loss, `ss12m1`) is submitted separately.
L-02, L-03 and L-04 are framed as **Law-3 non-obvious owner footguns** — in scope as
operational hazards with safe-config guidance, not "reckless admin" noise. Their primary
deliverable is operator guidance, not a code fix.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 |
| Centralization | 0 |
| **Total** | **4** |

| Label | ID | Title | Footgun | Principal at risk |
|-------|----|-------|---------|-------------------|
| L-01 | `ss12l1` | Poison/zero-credit user reverts the whole `migrateIn` slice | yes | No (recoverable) |
| L-02 | `ss12l2` | Underwater-migration operator footgun (faithful socialization, no migrator signal) | yes | No (intended socialization) |
| L-03 | `ss12l3` | Revived-pool permissionless-stake window before `migrateIn` | yes | No (theft refuted) |
| L-04 | `ss12l4` | Near-`MIN_TIMEOUT` multi-batch self-exit leaves a partially-refilled pool | yes | No (completeness only) |

An automated 4naly3er gas/QA report for the new `InPlaceMigrator.sol` is attached as
**Appendix A**, clearly separated from the manual findings above.

---

## Low Risk Findings

### [L-01] Poison/zero-credit user reverts the whole `migrateIn` slice <!-- id: ss12l1 -->

**Location**: [`InPlaceMigrator.sol#L207-L224`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L207-L224) (non-atomic per-user loop), [`InPlaceMigrator.sol#L223`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L223) (`staker.depositFor`), [`StableStaker.sol#L632`](../../../lib/stable-staker/src/StableStaker.sol#L632) (`require(credited > 0)` — story-011 guard)

**Description**: `migrateIn` re-injects parked users in a single all-or-nothing loop with no
per-user `try/catch` isolation. If any one parked user's `amt` haircuts to **zero credit** on
the newly-wired strategy (a dust-sized position on a sufficiently lossy market/AMM/fee'd-ERC4626
target), the story-011 guard `require(credited > 0, "StableStaker: nothing credited")` at
`StableStaker.sol:632` reverts that user's `depositFor`, and because the loop is non-atomic the
**entire `migrateIn` slice reverts**. The operator must then re-page the batch around the poison
user. This shares the same haircutting-strategy precondition as `M-01` (`ss12m1`) and is
conjoined to it — on a par/idle/direct/1:1-ERC4626 re-injection target the condition cannot arise.

**Impact**: Migration **availability / completeness only — no principal loss**. Every parked
user (including the poison user) always recovers their full principal via the timeout hatch
`claimTimedOut` ([`InPlaceMigrator.sol#L239-L256`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L239-L256)). This was **CONFIRMED** by Tier-3 Scenario 3
(`test_zeroCreditUser_revertsWholeSlice_thenClaimTimedOutRescues`): the slice reverts, then
`claimTimedOut` returns full principal. There is no attacker incentive (self-harming at most),
and it is double-gated (haircut strategy AND a zero-rounding dust position), so it lands Low
rather than Medium despite touching the C4 "function/availability impacted" clause. The root
cause (non-atomic loop) is distinct from the correctly-fixed `eae10d60` guard and from the
unbounded-gas DoS class — this is a downstream consequence of that guard existing, not a regression.

**Recommendation**: Isolate per-user re-injection so one zero-credit user cannot poison the whole
slice, and surface the skipped users for a follow-up pass. For example:

```solidity
// crediting a user that rounds to zero on the new strategy should not block the others
try staker.depositFor(token, user, amt) {
    // success: state already zeroed under CEI above
} catch {
    // restore parked state for this user and record for a later page / timeout claim
    parked[token][user] = amt;
    totalParked[token] += amt;
    _parkedUsers[token].add(user);
    emit MigrateInSkipped(token, user, amt);
    continue;
}
```

If a code change is undesired, document the operational requirement: only run `migrateIn` on a
par-preserving re-injection strategy (which also closes `M-01`), or pre-screen dust positions out
of the slice before paging.

---

### [L-02] Underwater-migration operator footgun: in-place flow silently crystallizes the socialized haircut <!-- id: ss12l2 -->

**Location**: [`InPlaceMigrator.sol#L153`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L153) (`parked[...] += amt`, where `amt = p_i·min(R,P)/P`), [`StableStaker.sol#L527-L528`](../../../lib/stable-staker/src/StableStaker.sol#L527-L528) (`_exitPosition` caps credit at `p_i·R/P` when `R < P`)

**Description**: `initiateMigration` is deliberately **not** blocked when the old strategy is
underwater (realizable `R` < principal `P`). The socialization arithmetic itself is faithful and
correct: the terminal-migration leg credits each user `p_i·min(R,P)/P = p_i·R/P`, realizing and
socializing the underwater delta `p_i·(1 − R/P)` exactly once, as documented for story-003/004.
The **footgun** (Law 3) is that an operator reaching for the in-place "rewire" tool — which is
framed as a loss-neutral dependency swap — gets no migrator-side signal that the underlying
strategy is impaired, and so silently crystallizes a live, real loss onto users.

**Impact**: The realized loss is **intended-and-correct socialization, not a new value bug** — so
there is no asset-loss finding here beyond what the staker already documents. The hazard is purely
the non-obvious tool-choice surprise: a competent, non-malicious operator would not expect a
"safe rewire" to bake in an impairment. Classified Low/QA by impact (intended socialization, no
incremental loss). Not suppressed by KI#6 — that covers the distinct `_routeExit` buffer-at-par
FCFS path; this is the separate terminal-migration `min(R,P)/P` path on a different entry point.

**Recommendation (safe-config guidance)**: Only run the in-place flow on an **at/above-par**
strategy. Before calling `initiateMigration`, check the old strategy's `withdrawDisabled` /
`_isUnderwater` state; if the strategy is impaired, route it through the cross-staker
`StableStakerMigrator` terminal path instead of the in-place rewire. Optionally add a defensive
revert (or explicit `force` parameter) in `initiateMigration` so an underwater strategy cannot be
migrated in place without an acknowledged override:

```solidity
require(!staker.isUnderwater(token) || forceUnderwater, "InPlaceMigrator: strategy underwater");
```

---

### [L-03] Revived-pool permissionless-stake window before `migrateIn` <!-- id: ss12l3 -->

**Location**: [`StableStaker.sol#L593-L604`](../../../lib/stable-staker/src/StableStaker.sol#L593-L604) (`finalizeAndReset` → `Active`), [`StableStaker.sol#L289-L307`](../../../lib/stable-staker/src/StableStaker.sol#L289-L307) (`stake`, permissionless, `whenNotPaused`, requires `Active`), [`InPlaceMigrator.sol#L183`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L183) (`migrateIn` is `onlyOwner`)

**Description**: After `finalizeAndReset` returns a fully-drained pool to `Active`, `stake` is
permissionless again before the operator runs `migrateIn`. A third party can therefore stake into
the transiently-empty revived pool during the out → reset → rewire → in session. **The theft /
first-depositor-inflation / sandwich vectors were independently REFUTED** by both Tier-2 agents:
reward accounting is a MasterChef accumulator (`accPhusdPerShare` / `rewardDebt`), **not** a
`totalAssets`-derived share price, so there is no inflatable share price; parked principal is
unreachable by outsiders; and each parked user's `depositFor` credits *their own* `amt` to *their
own* `userInfo`. The only residual effect is ordinary MasterChef **emission-share dilution** of
in-motion / unmatured yield from the interloper's added TVL.

**Impact**: **No principal theft, no inflation skim.** The sole residual is emission-share
dilution — and that is the normal, intended consequence of more TVL, not a leak. Reported as a
Low/QA operational note per Law 1 (refuted-exploit dispositions are kept in a visible channel,
never silently dropped). This shares the revival surface with the prior `ss9l1` / `ss10l1` notes;
treat it as the single "revival-window pause-wrap" recommendation.

**Recommendation**: Wrap the entire out → reset → rewire → in session in `pause()` / `unpause()`.
Both `finalizeAndReset` and `depositFor` run while paused, so pausing the pool across the window
closes the permissionless-stake gap without blocking the migration itself, eliminating the
interloper dilution window entirely.

---

### [L-04] Near-`MIN_TIMEOUT` multi-batch self-exit leaves a partially-refilled pool <!-- id: ss12l4 -->

**Location**: [`InPlaceMigrator.sol#L242-L245`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L242-L245) (`claimTimedOut` time-gate), [`InPlaceMigrator.sol#L210-L213`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L210-L213) (`migrateIn` skips self-exited users via `amt == 0 → continue` at L212), [`InPlaceMigrator.sol#L54-L55`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L54-L55) (docs explicitly scope multi-batch / long-running jobs OUT)

**Description**: If the operator deploys with `migrationTimeout` sized near `MIN_TIMEOUT` (1 day)
and then runs a many-batch / long-running rewire that stalls past the timeout, parked users can
call `claimTimedOut` **mid-migration**, taking their full principal and self-exiting. The later
`migrateIn` slice then skips those users (`amt == 0 → continue` at `InPlaceMigrator.sol:212`),
leaving a partially-refilled pool. This scenario is precisely the multi-batch, multi-day mode the
contract's own NatSpec at `InPlaceMigrator.sol:54-55` explicitly scopes OUT (the tool is built for
a small staker set in a single short-window session). The emission-cap integrity and the absence
of any profitable force-timeout incentive were separately refuted, leaving completeness as the
sole residual — making this a Law-3 timeout-sizing footgun, not a loss vector.

**Impact**: **No value lost** — self-exiting users recover full principal; only migration
**completeness** is affected (the pool ends partially refilled and the operator must reconcile the
self-exited set). A competent operator running a many-batch job with a near-`MIN_TIMEOUT` would be
surprised by mid-flight self-exits, which makes it a non-obvious footgun worth surfacing, but the
deliverable is pure safe-config guidance.

**Recommendation (safe-config guidance)**: Size `migrationTimeout` comfortably above the expected
full out → reset → in duration so users cannot self-exit before the session completes; the
documented 7-day default is sound for the intended single-session use. If multi-batch / multi-day
migrations are genuinely needed, use the `StableStakerMigrator` cross-staker path that the docs
designate for that mode rather than the in-place tool.

---

## Centralization Risks

No centralization-specific findings were identified for this run. `InPlaceMigrator` exposes only
`onlyOwner` operational entry points (`initiateMigration`, `migrateIn`) plus a permissionless
user-recovery hatch (`claimTimedOut`); the owner-privilege surface is consistent with the existing
trusted-owner model and the relevant owner hazards are captured as the Law-3 footguns L-02 / L-04
above rather than as standalone centralization items.

---

# Appendix A — Automated QA / Gas Report (4naly3er)

The following is the unedited output of **4naly3er** run against the new
`src/InPlaceMigrator.sol` (the only contract added by story-012), generated from the writable
workspace clone at HEAD `ffa4947`. It is the standard C4-style automated bot baseline and is
provided as-is; it has **not** been triaged into the manual findings above. The full markdown is
also available as a sibling file: [`4naly3er-report.md`](./4naly3er-report.md).

The automated report surfaced, for `InPlaceMigrator.sol`:

- **12 gas-optimization classes** (GAS-1..GAS-12) — pure style/gas, not promoted.
- **5 Non-Critical classes** (NC-1..NC-5: disable `renounceOwnership`, function length,
  named mappings, unindexed event fields, redundant zero-init) — informational only.
- **6 Low classes** (L-1..L-6: 2-step ownership transfer, zero-value transfer reverts,
  external calls in an unbounded `for`-loop / DoS, `PUSH0` chain portability,
  `Ownable2Step`, sweep-accounting on multi-address tokens).
- **1 "Medium" class** (M-1: "Centralization Risk for trusted owners", 6 instances) — this is
  4naly3er's standard boilerplate flag for every `onlyOwner` function. Under this project's
  Law-3 trusted-owner model it is deterministic noise, not a finding, and is **not** promoted.

None of these automated items are bundled into the manual Low findings above. The unbounded-loop
DoS class (L-3) and the owner-privilege class (M-1) were already analyzed manually during the
scan and dispositioned (the per-user loop is operator-paginated / off-chain batched, and the
owner surface is the trusted model captured as the Law-3 footguns L-02 / L-04); the remaining
NC/Low/gas items are style-grade and discouraged from a C4 QA bundle. See the sibling file for the
full per-instance listing.
