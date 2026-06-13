# QA Report for stable-staker (run 10, regression)

**Scope commit**: `125f585` (`125f585c95c3ff9fcf9deda6f5c8ea4da307ac77`)
**Mode**: Regression scan over range `93b7ce6..125f585` (story-010 empty-pool gate landing)
**Repo**: [Behodler/stable-staker](https://github.com/Behodler/stable-staker)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| QA / Non-Critical | 1 |
| Centralization | 0 |
| **New this run** | **2** |
| Carryover (open, prior runs) | 9 |

This run covers the landing of story-010's empty-pool gate on `setYieldStrategy`
(`require(poolInfo[token].totalStaked == 0)`, StableStaker.sol:228). The new Low and QA
items below both key on that gate. An automated 4naly3er gas/NC report is attached as an
appendix.

---

## Low Risk Findings

### [L-01] 1-wei dust stake griefs the new empty-pool gate, forcing a full terminal-migration cycle to rewire a strategy <!-- id: ss10l1 -->

**Location**: [StableStaker.sol#L228](https://github.com/Behodler/stable-staker/blob/125f585c95c3ff9fcf9deda6f5c8ea4da307ac77/src/StableStaker.sol#L228) (`setYieldStrategy`)

**Description**: story-010 made strategy (un)wiring an empty-pool-only operation by adding
`require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty")`. Because staking is
permissionless, any address can deposit **1 wei** of `token` to make the pool non-empty, which
blocks a strategy rotation or first adoption. To clear the griefing stake, the operator cannot
simply have the dust withdrawn — the pool must be driven through the full terminal-migration
cycle (`initiateMigration` → `batchMigrate`/`userMigrate` → `finalizeAndReset`) before
`setYieldStrategy` will pass again.

The hazard is the **cost asymmetry**: an attacker spends 1 wei (plus gas) to impose a complete
migration cycle on the operator. This is the one new item that directly intersects the
story-010 gate, so it is surfaced as a visible operational footgun rather than suppressed
(the consequence is non-obvious enough that a competent, non-malicious operator would be
surprised by it — Law 3 footgun boundary).

**Documented mitigation**: A pause-wrapped runbook already neutralizes the grief. `stake` is
`whenNotPaused`, while the gate functions (`setYieldStrategy` / `finalizeAndReset`) are
pause-tolerant, so an operator who pauses the token before opening the rotation window cannot
have a dust stake inserted into the window. The residual exposure is the un-paused case.

**Recommendation**: Keep the pause-before-rotate step explicit in the operator runbook. If a
permissionless, no-pause rotation path is ever desired, consider gating against a small minimum
stake / sweeping sub-threshold dust during finalize, or allowing the owner to evacuate a
known-griefing dust position without a full migration cycle.

**Relationship to ledger**: Overlaps the *revival-runbook* surface of ledgered `ss9l1`
(`finalizeAndReset` revives a pool without resetting `phusdPerSecond` / re-wiring the strategy),
but is a **distinct root cause** keyed on the new story-010 gate line. Bundled here alongside
`ss9l1` as the same runbook chapter — do **not** merge fingerprints.

---

## QA / Non-Critical Findings

### [QA-01] Stale NatSpec and structurally-dead code left behind by the story-010 empty-pool gate <!-- id: ss10q1 -->

**Location**:
- [StableStaker.sol#L204-L217](https://github.com/Behodler/stable-staker/blob/125f585c95c3ff9fcf9deda6f5c8ea4da307ac77/src/StableStaker.sol#L204-L217) (`setYieldStrategy` NatSpec)
- [StableStaker.sol#L238](https://github.com/Behodler/stable-staker/blob/125f585c95c3ff9fcf9deda6f5c8ea4da307ac77/src/StableStaker.sol#L238) (underwater guard) and [#L247-L250](https://github.com/Behodler/stable-staker/blob/125f585c95c3ff9fcf9deda6f5c8ea4da307ac77/src/StableStaker.sol#L247-L250) (drain branch)
- [StableStaker.sol#L580-L583](https://github.com/Behodler/stable-staker/blob/125f585c95c3ff9fcf9deda6f5c8ea4da307ac77/src/StableStaker.sol#L580-L583) (`finalizeAndReset` NatSpec)

**Description**: Commit `125f585` changed the behavior of `setYieldStrategy` (the new
`totalStaked == 0` gate) but left the surrounding documentation and code paths un-pruned, so the
in-source surface now contradicts itself. Two facets, one root cause:

**(a) Stale NatSpec.**
- The `setYieldStrategy` doc block (L204-217) still describes the **old in-place drain**: it
  states the whole position "moves YS1->YS2 in this single call, with no per-user migration."
  The empty-pool gate now *forbids* exactly that flow — a non-empty pool can no longer be rewired
  in place at all.
- The `finalizeAndReset` doc block (L580-583) still credits **story-008's underwater guard** as
  the thing that forbids an in-place underwater swap. The empty-pool gate is now the
  stronger and earlier forbidder (it blocks any non-empty swap, underwater or not), so the
  attribution is outdated.

**(b) Structurally-dead code.** Under the gate, `setYieldStrategy` can only proceed when
`totalStaked == 0`. Consequently:
- the story-008 underwater guard at L238 (`require(!_isUnderwater(...))`), and
- the `staked > 0` drain branch at L247-250 (`if (staked > 0) { _routeExit(...); }`)

are now **unreachable for conforming strategies** (the gate forces `totalStaked == 0`, and a
conforming strategy holds `principalOf` in lockstep with `totalStaked`, so `staked` is always 0
here). This is dead code / a refactor hazard on a contract whose comments are explicitly written
for a future operator.

**Impact**: None to funds or availability — this is a documentation-currency and maintenance
hazard. It is reported because the contradiction is *commit-internal* (the same commit changed
behavior but not its own docs/code), and the affected comments are operator-facing.

**Recommendation**: Update the `setYieldStrategy` and `finalizeAndReset` NatSpec to describe the
empty-pool gate as the governing invariant; remove or explicitly assert-only the now-unreachable
underwater guard and drain branch (e.g. replace the `if (staked > 0)` drain with an
`assert(staked == 0)` documenting the gate's guarantee), so the source reflects the post-story-010
contract.

**Relationship to ledger**: Distinct from ledgered `ss9f3` (the CLAUDE.md terminal-migration
doc-lag, which the `125f585` doc rework appears to resolve at the CLAUDE.md surface). QA-01 is the
**in-source Solidity** surface, which that rework did not touch. Facet (a) is also covered by
this run's **F-01** (faithfulness) as a Law-2 doc deviation and appears in the dedicated
spec-conformance report; it is included here for the in-source code/maintenance angle only.

---

## Informational / Out-of-Scope Note

**DEDUP-004 — residual-principal wedge (profile O-2).** The empty-pool gate makes residual
strategy-principal recovery structurally unreachable *only if* a strategy ever desyncs to
`principalOf > 0` while `totalStaked == 0`. This is **refuted as a live finding** at HEAD: it
requires a **non-conforming** yield strategy, and all conforming reflax strategies
(`ERC4626YieldStrategy`, `ERC4626MarketYieldStrategy`, shared `AYieldStrategy` base) maintain the
`principalOf` ↔ `totalStaked` lockstep on every conforming path (corroborated by the story-007
`relinquishPrincipal` lockstep fix, ledger `dc361b7d`). The only trigger lives in a
non-conforming strategy whose root cause is out-of-scope (OOS parent/forked contract, Law 3
trusted owner). It is **not dropped** — it is parked in manual-review and routed to Tier-3 as an
invariant candidate (`assert principalOf == 0 whenever totalStaked == 0`), to re-escalate if a
conforming-strategy desync path is ever found.

---

## Carryover — Open Findings from Prior Runs

The following ledger entries are unchanged by the `93b7ce6..125f585` range and remain open;
they were not re-discovered in this run and are listed here for completeness only (see prior run
reports and the ledger for full detail):

| Ledger ID | Summary | Severity / Status |
|-----------|---------|-------------------|
| `0790a76a` | `rescueERC20` vs strategy buffer interaction | Low / open |
| `59eebbf8` | Unbounded `batchMigrate` loop | Low / open |
| `4f143a95` | Migration credit asymmetry (batch-vs-self) | Low / open |
| `a56f8778` | `withdrawDisabled` over-reports | Low / open |
| `d47619d2` | `phUSDPerDay` floors to 0 | Low / open |
| `ss9l1` | `finalizeAndReset` revival footgun (stale emission / re-wire) | Low / open |
| `7b071779` | Unused `EnumerableSet` return value | Info / open |
| `796f775f` | `initiateMigration` CEI ordering | Info / open |
| `ss9f3` | CLAUDE.md terminal-migration doc-lag (re-check resolution at `125f585`) | Low / open |

> Note: this run also produced two Medium findings (DEDUP-001 phantom-staker brick;
> DEDUP-002 depositFor re-entry non-uniform AMM haircut) submitted individually outside this
> QA bundle, and F-01 (faithfulness) routed to the spec-conformance report.

---

## Appendix — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated report was generated with **4naly3er** over
`lib/stable-staker/src` (`StableStaker.sol`, `StableStakerMigrator.sol`, `interfaces/IStableStaker.sol`)
at commit `125f585`. The full output (13 gas optimizations + non-critical detectors with
instance counts and source locations) is attached as:

[`4naly3er-report.md`](./4naly3er-report.md)

These automated gas/NC items are provided as a baseline and are not individually triaged in the
manual sections above.
