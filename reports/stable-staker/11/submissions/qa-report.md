# QA Report for stable-staker (run 11, regression)

**Scope commit**: `c3ec65b` (`c3ec65bf0115e9bcc0a75f705a1c8cb57b32ce94`)
**Mode**: Regression scan over range `125f585..c3ec65b` (story-011 `depositFor` zero-credit guard)
**Repo**: [Behodler/stable-staker](https://github.com/Behodler/stable-staker)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (new this run) | 0 |
| QA / Non-Critical (new this run) | 0 |
| Centralization (new this run) | 0 |
| **New this run** | **0** |
| Carryover (open / unresolved, prior runs) | 9 |

**This run produced ZERO new QA findings.** The entire `125f585..c3ec65b` range is a single,
one-line in-scope change — `[story-011]` added the missing `depositFor` zero-credit guard
`require(credited > 0)` at `StableStaker.sol:632` (the symmetric counterpart to the pre-existing
`stake` guard at L301). Three independent agents (story-faithfulness, code-scanner, poc-validator)
confirmed the fix is **faithful, complete, and safe** — it introduces no new reachable behaviour and
no surviving phantom-creation path, so no new Low/QA/Centralization items arise from it. The
faithfulness verdict is recorded in the spec-conformance report; no new `F-XX` was raised.

The new guard **proposes-fixed** two prior Low/QA-tier ledger entries that key on exactly this gap
(`eae10d60` and the escalated Medium `8d5ceff2`); those are tracked via `/ledger` proposals, not
re-reported here.

## Automated QA / Gas Report (4naly3er) — carried, not re-run

4naly3er was **not re-run** this run. The only code delta from the prior scope (`125f585`) is the
single story-011 `require(credited > 0)` guard line; the contract surface 4naly3er analyzes is
otherwise byte-identical to run-10. The canonical automated gas/NC baseline therefore **carries
forward** from the prior run:

[`reports/stable-staker/10/submissions/4naly3er-report.md`](../../10/submissions/4naly3er-report.md)

(That report covers `lib/stable-staker/src` — `StableStaker.sol`, `StableStakerMigrator.sol`,
`interfaces/IStableStaker.sol` — with 13 gas optimizations plus non-critical detectors. A single
added `require` does not change any of those instance counts in a way that affects triage.) The
appendix is noted as carried rather than regenerated to avoid spurious churn on an unchanged surface.

---

## Carryover — Open / Unresolved Low, QA, and Info Findings from Prior Runs

The following ledger entries are Low/QA/Info-tier, were **not** touched by the `125f585..c3ec65b`
range, and remain open or otherwise unresolved. They are listed here for completeness and continued
visibility (one line each); see the linked prior-run reports and the ledger for full detail. None
were re-discovered this run.

| Ledger ID | Title | Status | One-line |
|-----------|-------|--------|----------|
| `0790a76a` | `rescueERC20` can sweep the buffer backing underwater withdrawals | open (Low) | Owner rescue path can drain the idle buffer that backs underwater par-withdraws. |
| `59eebbf8` | Unbounded per-user external-call loop in `batchMigrate` / `StableStakerMigrator.migrate` | open (Low) | Migration loop is unbounded by staker count; large pools risk gas-bounded batch DoS. |
| `7b071779` | Unused return value of `EnumerableSet.add`/`remove` | open (Info) | Set-mutation return values are discarded; hygiene / silent no-op risk. |
| `4f143a95` | Migration credit asymmetry: `batchMigrate` books below principal vs `userMigrate` | open (Low, F-01) | Operator-batched users credited below principal through a haircutting destination; self-exit keeps full value. Law-2 deviation — see spec-conformance F-01. |
| `a56f8778` | `withdrawDisabled` view over-reports after story-002 buffer path | open (Low, F-02) | Public view returns raw `_isUnderwater`, over-reporting `disabled` where a buffer-covered withdraw would succeed. Law-2 deviation — see spec-conformance F-02. |
| `d47619d2` | `phUSDPerDay` sub-86400-wei/day budget floors `phusdPerSecond` to 0 | open (Low, L-01) | Owner setting `amountPerDay < 86400` silently emits zero rewards with no revert. Owner-config footgun. |
| `796f775f` | `initiateMigration` writes state after external `strategy.withdraw` (CEI ordering) | open (Info, L-03) | Reentrancy-CEI ordering hygiene; guard- and trust-mitigated, no exploit demonstrated. |
| `ss9l1` | `finalizeAndReset` revives pool without resetting `phusdPerSecond` / re-wiring `yieldStrategy` | open (Low) | A revived pool resumes on stale emission rate / strategy reference; revival over-emission footgun. |
| `ss10l1` (`787e9fac`) | Dust-stake grief of the new empty-pool gate | submitted-qa (Low) | Permissionless 1-wei stake flips the story-010 gate, forcing a full terminal-migration cycle to rewire a strategy. |
| `ss10q1` (`b197e829`) | Stale NatSpec + structurally-dead drain branch / underwater guard under the story-010 gate | submitted-qa (Low / QA) | In-source NatSpec contradicts the empty-pool gate; dead drain branch + underwater guard. Doc facet = spec-conformance F-01 (run-10). |

### Carryover items carrying a `proposedStatus: fixed`

The following Low/QA-tier entry was **resolved-in-code by this run's story-011 change** and now
carries a `proposedStatus: fixed` pending human `/ledger` confirmation. It is listed here for
visibility but is **not** an open carryover:

| Ledger ID | Title | Status | Proposed |
|-----------|-------|--------|----------|
| `eae10d60` | `depositFor` missing `require(credited > 0)` guard | submitted-qa | **propose-fixed @ `c3ec65b`** (story-011) — `/ledger stable-staker fixed eae10d60 --commit c3ec65b` |

> Note: `ss9f3` (CLAUDE.md terminal-migration doc-lag) is a Law-2/spec item carrying
> `proposedStatus: fixed @ 125f585` from run-10; it is tracked in this run's spec-conformance
> report (F-03), not in this QA bundle.

> Note: this run also leaves several prior Mediums open or propose-fixed (e.g. `0dca43f3` M-05
> acknowledged-deferred; `dab5a656` / `dbdc3ac9` / `969722dc` / `3d61c955` propose-fixed @ `125f585`;
> `8d5ceff2` propose-fixed @ `c3ec65b` this run). Those are tracked as individual carryover stubs
> under `submissions/carryover/`, not in this QA bundle.
