# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit `balancer-lp-migrator` (run 43)

**Project**: `phoenix-phase-2-staging`  ·  **Run**: `phoenix-phase-2-staging-43`
**Commit**: `8765278bebfffc46fed96996ea17df9cfa879fad` (`8765278`), branch `master`
**Entry point**: `balancer-lp-migrator`  ·  **Fork block**: 26,303,097
**Story**: story-121, `~/code/product-owner/stories/phStaging2/auto-complete/balancer-lp-migrator/121-balancer-lp-migrator.md` (state: `auto-complete`, which is final)

## Faithfulness findings

**None.** This run raises no `F-xx` finding. `BalancerLPMigrator.migrate()` implements story-121 as written. In particular, it reverts with `ZeroMinimum()` when any of the four minimum amounts is zero (`src/periphery/BalancerLPMigrator.sol` L232), as Technical Details step 1 requires.

## Unsafe-story-rationale cross-reference (Law 1 over Law 2)

- Story-121's safety rationale claims more protection than the rule gives. The story says: *"Require `bptAmount > 0`, `to != address(0)`, `deadline >= block.timestamp`, and **all four** min amounts `> 0` (Configuration Safety: no zero slippage floors)."* A 1-wei floor passes this check and gives no protection against a sandwich of the Router02 add. See **L-01** (`pps43l1`, fingerprint `357565f8…`) in `qa-report.md` / `findings/low/balancer-lp-migrator__L-01.json`. That finding carries the recommendation to amend the story and NatSpec, and to require the phlimbo-ui modal to derive floors from `previewMigrate`.
