# phlimbo-ea-05 — Regression Summary (Baseline Advance)

**Date:** 2026-06-08
**Mode:** Regression — upstream catch-up (+1 commit). No scanning; ledger baseline advance only.

## What was asked

Confirm that the findings from the `phlimbo-ea-04` cold scan still apply at the current
upstream HEAD, and advance the ledger baseline accordingly. The determinative analysis
(git lineage + diff scope + in-scope byte-identity) was performed up front; this run does
**not** re-derive findings.

## Commit lineage

| | Commit | Note |
|---|---|---|
| Previously audited (`phlimbo-ea-04`) | `1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301` | was 1 commit behind upstream |
| New baseline (`phlimbo-ea-05`) | `6cb0bc0c2c26982a09d9dba2a01a9819bf65190c` | **= `origin/master`** (now caught up) |

`1b1a32c` is a direct ancestor of `6cb0bc0`; exactly **one** intervening commit.

## Diff scope of the intervening commit

The single commit `6cb0bc0` — *"Vendor immutable deps as plain source to fix recursive
submodule update"* — adds ≈12,781 insertions but touches **only out-of-scope paths**:

- vendored nested-dependency source under `lib/immutable/flax-token-v2/`
- vendored nested-dependency source under `lib/immutable/reflax-yield-vault/`
- `.claude/` helper scripts

Nothing under `src/` changes.

## Byte-identity proof (in-scope)

All in-scope files are byte-identical between `1b1a32c` and `6cb0bc0`, confirmed by matching
git blob hashes:

- `src/Phlimbo.sol` — blob `0370b7b6e505aa3ad537b4b773356b84ce710025` at both commits (sole in-scope contract)
- `src/interfaces/IPhlimbo.sol` — IDENTICAL
- `src/IFlax.sol` — IDENTICAL

## Verdict

Because no in-scope code changed, every `phlimbo-ea-04` ledger finding still applies verbatim
(same functions, line numbers, severities). **0 fixed, 0 regressions, 0 new findings possible**
from this commit. Clean upstream catch-up with no in-scope drift.

### Findings carried forward unchanged (25 unique)

- **Medium (3):** M-03 (phUSD mint-authority bricks claim/stake/withdraw), M-04 (Linear-Depletion
  exponential decay), M-05 (pause→pauseWithdraw→unpause phUSD over-mint)
- **Centralization (4):** C-01 (setDepletionDuration flash-drain), C-02 (emergencyTransfer +
  setPauser(0) permanent lock), C-03 (uncapped desiredAPY mint pressure), C-04 (pause/unpause
  sandwich selective yield denial; dual-listed as L-05)
- **Low (18):** L-01 … L-16 (note L-05 is the dual-listing of C-04; the 18-bucket count reflects
  the post-04 severity downgrades of ledger M-01 and M-02 into the Low bucket)
- **Faithfulness (1):** F-01 (emergencyTransfer breaks story-008 HIGH-5 safe-pauseWithdraw-exit
  promise)

## Ledger edits applied

- `lastAuditedCommit` → `6cb0bc0c2c26982a09d9dba2a01a9819bf65190c`
- `lastRun` → `phlimbo-ea-05`
- `updatedAt` → `2026-06-08T00:00:00Z`
- Appended `runHistory` entry for `phlimbo-ea-05` (mode: regression upstream catch-up; delta all-zero)
- Appended note to `tally.note`

No individual finding `status`, `severity`, or per-entry `lastSeenRun` was changed — there was
no fresh re-derivation, only a baseline advance.
