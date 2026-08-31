# Spec Conformance (Law 2) — stable-staker run-14

**Moved.** This file was the story-faithfulness agent's working draft. The compiled,
validator-corrected Law-2 report is the single authoritative copy and lives at:

> **[`submissions/spec-conformance.md`](submissions/spec-conformance.md)**

That is the path the QA bundle's pointer table (`submissions/qa-report.md`) references for
`L-01`–`L-04`. No content is retained here — do not treat this stub as a second version.

Substantive corrections applied during consolidation (so the draft's superseded claims are not
re-used):

- The draft judged `CrossVersionMigrator`'s `if (amounts[i] > 0)` zero-credit skip **CONFORMANT**.
  It is not; it is now filed as **L-01** (dust poison — the guard tests the source-side credit while
  the revert fires on the destination-side credit).
- The draft's haircut finding described only the **below-par** revert path
  (`StableStaker: nothing credited`). There are **two** kill paths; the realistic above-par
  production wiring dies earlier inside the strategy with
  `ERC4626YieldStrategy: no shares received`. Both are recorded in **L-01**.
- Draft `F-01` → **L-04**, draft `F-02` → **L-03**, draft `F-05` → **L-02**. Draft `F-03` and `F-04`
  were verification passes with no deviation and are retained under
  *"Claims that were tested and HELD"*.
