# Spec-Conformance Report (Law 2 — Faithfulness)

- **Project:** stable-staker
- **Run:** stable-staker-10 (regression mode)
- **Range audited:** `93b7ce6..125f585`
- **Submodule HEAD:** `125f585c95c3ff9fcf9deda6f5c8ea4da307ac77`
- **Date:** 2026-06-09

This report covers Law-2 faithfulness findings (story / spec deviations) for this run.
Findings here carry no asset/value/availability impact of their own; where a deviation
*also* has security impact it additionally carries an H/M label and a standalone report
(none this run — the security escalation M-01 / phantom-staker-brick is its own report,
not a faithfulness item).

---

## Positive faithfulness result — story-010 empty-pool gate is FAITHFULLY implemented and SAFE

Run-09's CLAUDE.md rewrite (commit `125f585`) introduced **story-010**, whose acceptance
criterion (commit body / `lib/stable-staker/CLAUDE.md`) reads:

> **`setYieldStrategy` reverts (`"StableStaker: pool not empty"`) unless `totalStaked == 0`** —
> strategy (un)wiring is an empty-pool-only operation.

This is delivered **exactly** by the require at `src/StableStaker.sol:228`:

```solidity
require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");
```

- **Faithfulness: PASS.** The runtime gate matches the stated acceptance criterion verbatim
  (same revert string, same predicate). Strategy (un)wiring is now an empty-pool-only
  operation, and the documented terminal-migration runbook
  (`initiateMigration → batchMigrate/userMigrate → finalizeAndReset → setYieldStrategy`) is
  the only path to rewire a live pool.
- **Law-1 safety of the intended design: SAFE.** The gate only *removes reachable behaviour*
  (in-place principal movement on a non-empty pool); it introduces no new reachable state.
  It structurally subsumes the in-place-swap root cause shared by M-01 (`dab5a656`,
  first-adoption sweep), M-06 (`dbdc3ac9`, underwater swap) and M-07 (`969722dc`,
  AMM-execution swap) — profile G-5, verified.
- **The gate does NOT itself introduce the phantom-brick.** The permanent-brick of
  `finalizeAndReset` (this run's Medium **M-01 / DEDUP-001**, `8d5ceff2…`) is a **pre-existing
  `depositFor` gap** (missing `require(credited > 0)` allowing a zero-credit phantom staker
  into `_stakers`), not a consequence of the story-010 gate. The gate is faithful and safe;
  the brick is tracked separately as a security finding.

---

## F-01 (QA, Law-2 doc deviation) — Stale in-source NatSpec contradicts the story-010 gate within the same commit

- **Severity:** QA (informational documentation deviation)
- **Status:** submitted-qa
- **Contract:** `src/StableStaker.sol`
- **Functions:** `setYieldStrategy` (NatSpec L204-217), `finalizeAndReset` (NatSpec L580-583)
- **Story:** story-010 (commit `125f585`)
- **Root cause class:** stale-natspec / doc-lie (docs describe behaviour the code no longer has)
- **Cross-reference:** **QA-01** (`ss10q1`, DEDUP-003) in `qa-report.md` — same root cause; QA-01
  is the dead-code facet (the structurally-unreachable drain branch / underwater guard), F-01 is
  the documentation facet. Same fingerprint family.

### Summary

Commit `125f585` rewrote the project `CLAUDE.md` to the hard empty-pool gate, but the **in-source
Solidity NatSpec was not updated in the same commit**, creating an *internal contradiction*: the
documentation describes behaviour the code can no longer exhibit.

### Acceptance criterion (story-010, commit `125f585` body / `CLAUDE.md`)

> **`setYieldStrategy` reverts (`"StableStaker: pool not empty"`) unless `totalStaked == 0`.**

Under this gate, `setYieldStrategy` can only proceed when `totalStaked == 0`, so:

1. **`setYieldStrategy` NatSpec (L204-217) is structurally dead.** It still claims:

   > "The whole position therefore moves YS1->YS2 in this single call, with no per-user migration."

   This is unreachable. With the gate at L228 requiring `totalStaked == 0`, there is never a
   "whole position" to move in-place — the `staked > 0` drain branch at L248 (`_routeExit(token,
   staked, false)`) can never execute, so no `YS1->YS2` in-call position move occurs. The doc
   describes the exact behaviour the gate was added to forbid.

2. **`finalizeAndReset` NatSpec (L580-583) credits the wrong forbidder.** It still states:

   > "An IMPAIRED / underwater strategy reaches this path ONLY via {initiateMigration} … NEVER via
   > an in-place {setYieldStrategy} swap, which **story 008's underwater guard forbids**."

   As of story-010, **the empty-pool gate (L228) is the stronger, earlier-firing forbidder** — it
   rejects *any* in-place swap on a live pool, underwater or not, before story-008's
   `!_isUnderwater(old)` rate guard at L238 is ever reached. The NatSpec credits a subordinate,
   now-redundant guard as the controlling one.

### Impact

**None — no security, value, or availability impact.** The *runtime* gate is correct and
**strictly more restrictive** than what the stale comments describe. This is a pure documentation
deviation (doc-lie): a future operator/auditor reading the NatSpec would be told a code path exists
(in-place whole-position migration) that the code structurally prevents, and would be pointed at
the wrong guard as the controlling safety mechanism. The hazard is maintenance/comprehension only,
on a contract whose comments are explicitly written for a future operator.

### Recommendation

Update the in-source NatSpec to describe the implemented story-010 behaviour:

- `setYieldStrategy` (L204-217): replace the "whole position moves YS1->YS2 in this single call"
  language with the empty-pool-only contract and the terminal-migration runbook required to rewire
  a live pool.
- `finalizeAndReset` (L580-583): name the **empty-pool gate** (`require(totalStaked == 0)`, L228)
  as the controlling in-place-swap forbidder; the story-008 underwater rate guard is now
  redundant-but-harmless and should be described as such.

`lib/` is read-only — this is **reported, not fixed**.
