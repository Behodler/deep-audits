# stable-staker — run-11 summary

- **Mode:** regression `/full-audit` (baseline-advancing; NOT a baseline-preserving `/recheck`)
- **Scanned HEAD:** `c3ec65bf0115e9bcc0a75f705a1c8cb57b32ce94`
- **Range:** `125f585..c3ec65b`
- **Prior baseline:** `lastAuditedCommit=125f585c`, `lastRun=stable-staker-10`
- **Date:** 2026-06-09

## In-scope change

A single in-scope change: **[story-011] depositFor zero-credit guard** — `require(credited > 0)`
added at `StableStaker.sol:632`. This is the symmetric counterpart to the pre-existing
`stake` guard at `L301`; both `_stakers.add` sites are now guarded.

## Verification verdict

Three independent agents reviewed the change:

- **story-faithfulness** — story-011 faithfully and completely implements the intended guard.
- **code-scanner** — no new bug introduced; no surviving phantom-creation path; both add-sites guarded.
- **poc-validator** — the original repro `test/PoC_DEDUP001_PhantomStakerBrick.t.sol` now reverts at
  setup (phantom can no longer be created); the new proof-of-fix
  `test/PoC_story011_DepositForZeroCreditReverts.t.sol` passes.

Combined verdict: story-011 is a **FAITHFUL, COMPLETE, SAFE** fix.

## New findings

**0 new findings of any severity.**

## Ledger reconciliation (propose-don't-auto-flip)

| Fingerprint | Id | Sev | Authoritative status | Recheck | Proposed |
|---|---|---|---|---|---|
| `8d5ceff2…` | ss10m1 / M-01 | Medium | acknowledged | LIKELY-FIXED | fixed @ `c3ec65b` |
| `eae10d60…` | — | Low | submitted-qa | LIKELY-FIXED | fixed @ `c3ec65b` |

Both are closed by `story-011`'s `require(credited > 0)` at `StableStaker.sol:632`:

- **ss10m1 (M-01)** — phantom zero-credit staker permanently bricks `finalizeAndReset`. The new
  guard blocks the `depositFor` phantom-creation path, so a zero-position staker can no longer be
  stranded in `_stakers` and `finalizeAndReset`'s `require(stakerCount==0)` can no longer be wedged.
- **eae10d60** — `depositFor` missing `require(credited > 0)`; the literal change story-011 implements.

Neither status was hard-overwritten. Per the propose-don't-auto-flip convention used by prior runs,
each carries `proposedStatus: fixed` plus a `/ledger … fixed … --commit c3ec65b` command for human
confirmation. Recheck fields (`lastRecheckedCommit`/`lastRecheckedAt`/`recheckResult`) and a bumped
`lastSeenRun=stable-staker-11` were recorded on both entries.

## Untouched prior proposals

The 5 pre-existing `proposedStatus:fixed` entries from run-10 and earlier were left **unchanged**
(not re-verified by this scoped change, still pending human `/ledger` confirmation):

- `dab5a656` (M-01), `dbdc3ac9` (M-06), `969722dc` (M-07), `ss9f3` (F-03 doc-lag) — proposed fixed @ `125f585`
- `3d61c955` (M-01, ss-01) — proposed fixed @ `f5f6039`

## Baseline advanced

- `lastAuditedCommit` → `c3ec65bf0115e9bcc0a75f705a1c8cb57b32ce94`
- `lastRun` → `stable-staker-11`

Authoritative human-set statuses (wont-fix / acknowledged / fixed) were not auto-changed except via
the `proposedStatus` mechanism above.
